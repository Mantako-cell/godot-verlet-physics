#=============================================================================
# VerletTerrain2D - Interactive 2D Deformable Terrain & Fluid Basin
# Part of VerletDynamics for Godot 4.x
# Features: Real-time 2.5D heightfield wave propagation, permanent plastic
# soil cratering, bidirectional fluid buoyancy, dynamic collision regeneration,
# and procedural multi-layer rendering.
#=============================================================================
@tool
class_name VerletTerrain2D
extends Node2D

signal terrain_impact(world_pos: Vector2, strength: float)
signal object_submerged(body: Node2D, depth: float)

enum TerrainMode {
	DEFORMABLE_EARTH, # Compaction, cratering from impacts, excavate/mound sculpting
	FLUID_BASIN       # Shallow-water wave propagation with buoyancy and fluid drag
}

# --- Dimensions & Resolution ---
@export_group("Dimensions")
@export var mode: TerrainMode = TerrainMode.DEFORMABLE_EARTH:
	set(val):
		mode = val
		_apply_mode_defaults()
		queue_redraw()

@export_range(100.0, 3000.0, 10.0) var terrain_width: float = 1160.0:
	set(val):
		terrain_width = maxf(val, 50.0)
		_rebuild_columns()

@export_range(16, 256, 4) var column_count: int = 80:
	set(val):
		column_count = clampi(val, 16, 256)
		_rebuild_columns()

@export_range(20.0, 600.0, 10.0) var basin_depth: float = 140.0:
	set(val):
		basin_depth = maxf(val, 20.0)
		_update_collision_polygon()
		queue_redraw()

# --- Physics Dynamics ---
@export_group("Physics Dynamics")
@export_range(0.001, 0.2, 0.001) var wave_tension: float = 0.035
@export_range(0.8, 0.999, 0.002) var damping: float = 0.965
@export_range(0.0, 0.5, 0.005) var elasticity: float = 0.005 # Baseline return force (0 for permanent soil)
@export_range(0.1, 5.0, 0.1) var crater_sensitivity: float = 1.2
@export_range(0.0, 60.0, 1.0) var buoyancy_force: float = 28.0
@export_range(0.0, 1.0, 0.05) var fluid_viscous_drag: float = 0.12

# --- Collisions ---
@export_group("Collisions")
@export var collision_enabled: bool = true:
	set(val):
		collision_enabled = val
		if is_instance_valid(_collider):
			_collider.disabled = not collision_enabled

@export_flags_2d_physics var collision_layer: int = 1
@export_flags_2d_physics var collision_mask: int = 1

# --- Visual Styling ---
@export_group("Styling")
@export var surface_color: Color = Color(0.35, 0.78, 0.35, 1.0) # Grass green or wave crest cyan
@export var body_top_color: Color = Color(0.44, 0.32, 0.22, 1.0) # Soil or water surface
@export var body_bottom_color: Color = Color(0.18, 0.14, 0.10, 1.0) # Bedrock or deep water
@export var surface_line_thickness: float = 4.0

# --- State Arrays ---
var pos_y: PackedFloat32Array = PackedFloat32Array()
var prev_y: PackedFloat32Array = PackedFloat32Array()

# Internal collision structures
var _static_body: StaticBody2D = null
var _collider: CollisionPolygon2D = null
var _collision_dirty: bool = false
var _dirty_cooldown: float = 0.0


func _ready() -> void:
	_setup_collision()
	_rebuild_columns()
	_apply_mode_defaults()


func _setup_collision() -> void:
	_static_body = get_node_or_null("TerrainStaticBody") as StaticBody2D
	if not _static_body:
		_static_body = StaticBody2D.new()
		_static_body.name = "TerrainStaticBody"
		add_child(_static_body)

	_collider = _static_body.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if not _collider:
		_collider = CollisionPolygon2D.new()
		_collider.name = "CollisionPolygon2D"
		_static_body.add_child(_collider)

	_static_body.collision_layer = collision_layer
	_static_body.collision_mask = collision_mask


func _apply_mode_defaults() -> void:
	if mode == TerrainMode.DEFORMABLE_EARTH:
		wave_tension = 0.012
		damping = 0.88
		elasticity = 0.001 # Retains craters permanently
		collision_enabled = true
		surface_color = Color(0.35, 0.78, 0.35, 1.0)
		body_top_color = Color(0.44, 0.32, 0.22, 1.0)
		body_bottom_color = Color(0.18, 0.14, 0.10, 1.0)
	elif mode == TerrainMode.FLUID_BASIN:
		wave_tension = 0.045
		damping = 0.982
		elasticity = 0.08 # Spring ripples oscillate back to baseline
		collision_enabled = false # Submerges into fluid with buoyant Archimedes forces
		surface_color = Color(0.65, 0.92, 1.0, 0.95)
		body_top_color = Color(0.20, 0.55, 0.88, 0.75)
		body_bottom_color = Color(0.08, 0.22, 0.45, 0.92)


func _rebuild_columns() -> void:
	pos_y.resize(column_count)
	prev_y.resize(column_count)
	for i in range(column_count):
		pos_y[i] = 0.0
		prev_y[i] = 0.0
	_collision_dirty = true
	_update_collision_polygon()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if pos_y.size() != column_count:
		_rebuild_columns()
		return

	_step_wave_solver()

	# In-game body interactions
	if not Engine.is_editor_hint():
		_interact_with_physics_bodies(delta)

	# Update collision polygon when modified
	_dirty_cooldown += delta
	if _collision_dirty and _dirty_cooldown >= 0.033: # Max ~30 collision updates/sec
		_dirty_cooldown = 0.0
		_collision_dirty = false
		_update_collision_polygon()

	queue_redraw()


func _step_wave_solver() -> void:
	var n = column_count
	var dx = terrain_width / float(max(1, n - 1))
	var max_disp = basin_depth * 0.75

	for i in range(n):
		var curr = pos_y[i]
		var prev = prev_y[i]
		var vel = (curr - prev) * damping

		# Restoring equilibrium force
		var force = -curr * elasticity

		# Neighbor coupling (Laplacian tension)
		var left_diff = (pos_y[i - 1] - curr) if i > 0 else 0.0
		var right_diff = (pos_y[i + 1] - curr) if i < n - 1 else 0.0
		force += (left_diff + right_diff) * wave_tension

		var next_y = clampf(curr + vel + force, -max_disp, max_disp)
		prev_y[i] = curr
		pos_y[i] = next_y


func _interact_with_physics_bodies(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	var origin_x = global_position.x
	var surface_y = global_position.y
	var dx = terrain_width / float(max(1, column_count - 1))

	# Scan RigidBody2D nodes across groups and tree hierarchy
	var bodies: Array[RigidBody2D] = []
	for b in get_tree().get_nodes_in_group("physics_bodies_2d"):
		if b is RigidBody2D and is_instance_valid(b) and not bodies.has(b):
			bodies.append(b)
	for b in get_tree().get_nodes_in_group("physics_balls_2d"):
		if b is RigidBody2D and is_instance_valid(b) and not bodies.has(b):
			bodies.append(b)

	if get_parent() != null:
		for child in get_parent().get_children():
			if child is RigidBody2D and not bodies.has(child):
				bodies.append(child)

	var root_scene = get_tree().current_scene
	if root_scene != null and root_scene != get_parent():
		for child in root_scene.get_children():
			if child is RigidBody2D and not bodies.has(child):
				bodies.append(child)

	for body in bodies:
		_process_body_coupling(body, origin_x, surface_y, dx, delta)

	# Coupling with Verlet dynamic nodes (Ragdoll joints, Softbody perimeter, Rope ends)
	for node in get_tree().get_nodes_in_group("verlet_physics_2d"):
		if node == self or not is_instance_valid(node):
			continue
		if node is VerletRope2D or node is VerletSoftBody2D or node is VerletRagdoll2D:
			for p in node.particles:
				var local_px = p.position.x - origin_x
				if local_px >= 0.0 and local_px <= terrain_width:
					var col = clampi(int(local_px / dx), 0, column_count - 1)
					var col_y = surface_y + pos_y[col]
					if p.position.y > col_y - p.radius and p.position.y < col_y + basin_depth:
						var pen = (p.position.y + p.radius) - col_y
						if pen > 0.0:
							if mode == TerrainMode.DEFORMABLE_EARTH:
								# Measure speed before clamping
								var speed = (p.position - p.prev_position).length() / maxf(delta, 0.001)
								# Push particle back above soil surface
								p.position.y = col_y - p.radius
								p.prev_position.y = p.position.y
								if speed > 60.0:
									var indent_depth = clampf(speed * 0.035 * crater_sensitivity, 2.5, 24.0)
									indent(p.position.x, indent_depth, 26.0)
									terrain_impact.emit(Vector2(p.position.x, col_y), speed)
							elif mode == TerrainMode.FLUID_BASIN:
								var immersion = clampf(pen / 35.0, 0.0, 1.0)
								# Buoyant upward acceleration force
								var up_force = Vector2.UP * (buoyancy_force * 700.0 * immersion)
								p.apply_force(up_force)
								# Viscous water drag
								var vel = p.get_velocity(delta)
								p.set_velocity(vel * (1.0 - fluid_viscous_drag * immersion * 0.5), delta)
								if abs(vel.y) > 30.0:
									splash(p.position.x, clampf(vel.y * 0.04, -12.0, 12.0), 32.0)


func _process_body_coupling(body: RigidBody2D, origin_x: float, surface_y: float, dx: float, delta: float) -> void:
	var b_pos = body.global_position
	var rel_x = b_pos.x - origin_x

	if rel_x < 0.0 or rel_x > terrain_width:
		return

	var col = clampi(int(rel_x / dx), 0, column_count - 1)
	var local_surf_y = surface_y + pos_y[col]
	var dist_below = b_pos.y - local_surf_y

	if dist_below > -35.0 and dist_below < basin_depth:
		if mode == TerrainMode.FLUID_BASIN:
			# Fluid immersion & buoyancy
			var body_radius = 20.0
			var immersion_ratio = clampf((dist_below + body_radius) / (body_radius * 2.0), 0.0, 1.0)
			if immersion_ratio > 0.02:
				# Impart upward buoyant acceleration (Archimedes principle)
				var buoyant_accel = Vector2.UP * (buoyancy_force * 35.0 * immersion_ratio)
				body.apply_central_force(buoyant_accel * body.mass)

				# Viscous fluid drag (dampens linear and angular velocity)
				var drag_factor = clampf(fluid_viscous_drag * delta * 60.0 * immersion_ratio, 0.0, 0.9)
				body.linear_velocity = body.linear_velocity.lerp(Vector2.ZERO, drag_factor)
				body.angular_velocity *= (1.0 - drag_factor * 0.5)

				# Emit waves proportional to vertical velocity and body mass
				var vy = body.linear_velocity.y
				if abs(vy) > 15.0:
					var splash_mag = clampf((vy / 120.0) * sqrt(body.mass) * 16.0, -22.0, 22.0)
					splash(b_pos.x, splash_mag, clampf(25.0 * sqrt(body.mass), 20.0, 60.0))
					terrain_impact.emit(b_pos, abs(vy))
				object_submerged.emit(body, dist_below)

		elif mode == TerrainMode.DEFORMABLE_EARTH:
			# Kinetic impact cratering scaled by velocity and mass
			var vy = body.linear_velocity.y
			if vy > 45.0:
				var mass_mult = clampf(sqrt(body.mass), 0.7, 3.5)
				var crater_amount = clampf((vy / 140.0) * crater_sensitivity * 10.0 * mass_mult, 3.5, 60.0)
				var crater_radius = clampf(28.0 * mass_mult, 20.0, 65.0)
				indent(b_pos.x, crater_amount, crater_radius)
				terrain_impact.emit(b_pos, vy)
				# Absorb impact energy into soil
				body.linear_velocity.y *= 0.3


func _update_collision_polygon() -> void:
	if not is_instance_valid(_collider):
		return

	if not collision_enabled:
		_collider.polygon = PackedVector2Array()
		return

	var n = column_count
	var dx = terrain_width / float(max(1, n - 1))
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(n + 2)

	var max_surf = basin_depth - 6.0
	var min_surf = -basin_depth * 0.75

	# Surface points along heightfield safely clamped above basin floor
	for i in range(n):
		pts[i] = Vector2(i * dx, clampf(pos_y[i], min_surf, max_surf))

	# Bottom perimeter anchors
	pts[n] = Vector2(terrain_width, basin_depth)
	pts[n + 1] = Vector2(0.0, basin_depth)

	_collider.polygon = pts


# =============================================================================
# Procedural 2D Rendering
# =============================================================================

func _draw() -> void:
	if pos_y.size() != column_count:
		return

	var n = column_count
	var dx = terrain_width / float(max(1, n - 1))
	var max_surf = basin_depth - 8.0
	var min_surf = -basin_depth * 0.75

	# 1. Subsurface Body Polygon
	var poly_pts: PackedVector2Array = PackedVector2Array()
	poly_pts.resize(n + 2)
	for i in range(n):
		poly_pts[i] = Vector2(i * dx, clampf(pos_y[i], min_surf, max_surf))
	poly_pts[n] = Vector2(terrain_width, basin_depth)
	poly_pts[n + 1] = Vector2(0.0, basin_depth)

	# Solid polygon fill
	draw_colored_polygon(poly_pts, body_top_color)

	# Subsurface bedrock / deep basin bottom stratum
	var bedrock_rect = Rect2(0.0, basin_depth - 22.0, terrain_width, 22.0)
	draw_rect(bedrock_rect, body_bottom_color)

	# 2. Surface Contour Outline
	var surf_pts: PackedVector2Array = PackedVector2Array()
	surf_pts.resize(n)
	for i in range(n):
		surf_pts[i] = Vector2(i * dx, clampf(pos_y[i], min_surf, max_surf))

	# Anti-aliased surface line
	for i in range(n - 1):
		draw_line(surf_pts[i], surf_pts[i + 1], surface_color, surface_line_thickness, true)

	# 3. Stylized Surface Highlights
	if mode == TerrainMode.FLUID_BASIN:
		# Draw glittering water surface specular dots
		for i in range(1, n - 1, 3):
			var crest_pos = surf_pts[i] + Vector2(0, 1.5)
			draw_circle(crest_pos, 2.0, Color(1.0, 1.0, 1.0, 0.75))
		# Foam caps on high wave peaks
		for i in range(1, n - 1):
			if pos_y[i] < -4.0:
				var p1 = surf_pts[i - 1]
				var p2 = surf_pts[i + 1]
				draw_line(p1, p2, Color(1.0, 1.0, 1.0, 0.85), surface_line_thickness * 0.8, true)
	elif mode == TerrainMode.DEFORMABLE_EARTH:
		# Draw grass blade tufts along top edge
		for i in range(2, n - 2, 4):
			var p = surf_pts[i]
			draw_line(p, p + Vector2(-2, -5), surface_color * 1.15, 1.8, true)
			draw_line(p, p + Vector2(2, -6), surface_color * 1.25, 1.8, true)
		# Subsurface sediment specks
		for s in range(12):
			var px = (float(s * 97 % 1100)) + 30.0
			var col_idx = clampi(int(px / dx), 0, n - 1)
			var py = minf(pos_y[col_idx] + 25.0 + float((s * 53) % int(maxf(basin_depth - 40.0, 10.0))), basin_depth - 5.0)
			draw_circle(Vector2(px, py), 2.2, Color(0.12, 0.09, 0.06, 0.55))


# =============================================================================
# Public Interactive API
# =============================================================================

## Indents terrain creating a depression or crater at world_x
func indent(world_x: float, depth: float, radius: float = 35.0) -> void:
	_apply_gaussian_displacement(world_x, depth, radius, true)


## Raises terrain creating a hill or mound at world_x
func raise_mound(world_x: float, height: float, radius: float = 35.0) -> void:
	_apply_gaussian_displacement(world_x, -height, radius, true)


## Produces an elastic splash or wave pulse radiating from world_x
func splash(world_x: float, force: float, radius: float = 40.0) -> void:
	_apply_gaussian_displacement(world_x, force, radius, false)


func _apply_gaussian_displacement(world_x: float, amount: float, radius: float, is_plastic: bool) -> void:
	var local_x = world_x - global_position.x
	var n = column_count
	var dx = terrain_width / float(max(1, n - 1))
	var center_col = int(round(local_x / dx))
	var col_radius = max(1, int(radius / dx))
	var max_indent = basin_depth - 15.0
	var max_height = - (basin_depth * 0.7)

	for offset in range(-col_radius, col_radius + 1):
		var c = center_col + offset
		if c >= 0 and c < n:
			var dist = abs(offset * dx)
			var weight = exp(- (dist * dist) / (2.0 * (radius * 0.5) * (radius * 0.5)))
			var disp = amount * weight

			pos_y[c] = clampf(pos_y[c] + disp, max_height, max_indent)
			if is_plastic:
				# Move previous position as well so velocity stays zero (permanent displacement)
				prev_y[c] = pos_y[c]
			else:
				# Give velocity momentum for dynamic waves
				prev_y[c] -= disp * 0.35

	_collision_dirty = true


## Smooths out terrain craters back toward baseline
func smooth_terrain() -> void:
	for i in range(column_count):
		pos_y[i] *= 0.5
		prev_y[i] = pos_y[i]
	_collision_dirty = true
	_update_collision_polygon()


## Completely levels terrain surface to flat baseline
func reset_surface() -> void:
	for i in range(column_count):
		pos_y[i] = 0.0
		prev_y[i] = 0.0
	_collision_dirty = true
	_update_collision_polygon()

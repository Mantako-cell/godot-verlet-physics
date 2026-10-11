#=============================================================================
# VerletSoftBody2D - 2D Deformable Squishy Jelly & Slime for Godot 4.x
# Features: Internal radial cross-struts, volume preservation, elastic bounce,
# 2D world collision, and smooth polygon drawing with shine.
#=============================================================================
@tool
class_name VerletSoftBody2D
extends Node2D

signal body_impact(point: Vector2, normal: Vector2, force: float)

@export_group("Dimensions & Mass")
@export_range(10.0, 300.0, 5.0) var radius: float = 40.0:
	set(val):
		radius = maxf(val, 5.0)
		if Engine.is_editor_hint():
			_rebuild_body()

@export_range(6, 32, 1) var point_count: int = 12:
	set(val):
		point_count = clampi(val, 6, 32)
		if Engine.is_editor_hint():
			_rebuild_body()

@export_range(0.1, 20.0, 0.1) var total_mass: float = 1.5

@export_group("Jelly Dynamics")
@export var gravity: Vector2 = Vector2(0.0, 980.0)
@export_range(0.85, 0.999, 0.001) var damping: float = 0.985
@export_range(0.1, 1.0, 0.02) var elasticity_stiffness: float = 0.85
@export_range(0.1, 1.0, 0.02) var internal_spoke_stiffness: float = 0.75
@export_range(2, 25, 1) var solver_iterations: int = 10

@export_group("Collisions")
@export var collision_enabled: bool = true
@export_range(1.0, 20.0, 0.5) var particle_radius: float = 4.0
@export_flags_2d_physics var collision_mask: int = 1
@export_range(0.0, 1.0, 0.05) var bounce_factor: float = 0.65
@export_range(0.0, 1.0, 0.05) var surface_friction: float = 0.25

@export_group("Visuals")
@export var body_color: Color = Color(0.2, 0.85, 0.45, 0.9): # Bright Emerald Jelly
	set(val):
		body_color = val
		queue_redraw()

@export var outline_color: Color = Color(0.1, 0.6, 0.3):
	set(val):
		outline_color = val
		queue_redraw()

@export var outline_width: float = 3.0:
	set(val):
		outline_width = val
		queue_redraw()

var particles: Array[VerletParticle2D] = []
var constraints: Array[VerletConstraint2D] = []
var center_particle: VerletParticle2D = null
var _collision_query: PhysicsRayQueryParameters2D = null


func _ready() -> void:
	_rebuild_body()


func _safe_xform() -> Transform2D:
	return global_transform if is_inside_tree() else transform


func _safe_pos() -> Vector2:
	return global_position if is_inside_tree() else position


func _rebuild_body() -> void:
	particles.clear()
	constraints.clear()

	var cur_pos = _safe_pos()
	var p_mass = total_mass / float(point_count + 1)

	# 1. Center particle
	center_particle = VerletParticle2D.new(cur_pos, p_mass, particle_radius)
	particles.append(center_particle)

	# 2. Perimeter particles
	var perimeter_particles: Array[VerletParticle2D] = []
	for i in range(point_count):
		var angle = (float(i) / float(point_count)) * TAU
		var offset = Vector2(cos(angle), sin(angle)) * radius
		var p = VerletParticle2D.new(cur_pos + offset, p_mass, particle_radius)
		particles.append(p)
		perimeter_particles.append(p)

	# 3. Perimeter ring constraints
	var seg_len = (2.0 * radius * sin(PI / float(point_count)))
	for i in range(point_count):
		var p_cur = perimeter_particles[i]
		var p_next = perimeter_particles[(i + 1) % point_count]
		var c = VerletConstraint2D.new(p_cur, p_next, seg_len, elasticity_stiffness)
		constraints.append(c)

	# 4. Radial spokes from center to perimeter
	for i in range(point_count):
		var p_rim = perimeter_particles[i]
		var c = VerletConstraint2D.new(center_particle, p_rim, radius, internal_spoke_stiffness)
		constraints.append(c)

	# 5. Cross-diameter struts for volume preservation
	var half = point_count / 2
	for i in range(half):
		var p_a = perimeter_particles[i]
		var p_b = perimeter_particles[(i + half) % point_count]
		var c = VerletConstraint2D.new(p_a, p_b, radius * 2.0, internal_spoke_stiffness * 0.9)
		constraints.append(c)

	queue_redraw()


func _physics_process(delta: float) -> void:
	if particles.is_empty():
		return

	# 1. Gravity
	var g_force = gravity * (total_mass / float(particles.size()))
	for p in particles:
		p.apply_force(g_force)

	# 2. Integrate
	for p in particles:
		p.integrate(delta, damping)

	# 3. Solve constraints
	for iter in range(solver_iterations):
		for c in constraints:
			c.solve()

	# 4. Collisions
	if collision_enabled and is_inside_tree():
		var space_state = get_world_2d().direct_space_state
		if space_state:
			_solve_collisions_2d(space_state)

	queue_redraw()


func _solve_collisions_2d(space_state: PhysicsDirectSpaceState2D) -> void:
	if _collision_query == null:
		_collision_query = PhysicsRayQueryParameters2D.new()
		_collision_query.collision_mask = collision_mask

	# Check perimeter particles
	for i in range(1, particles.size()):
		var p = particles[i]
		var move_delta: Vector2 = p.position - p.prev_position
		var cast_target: Vector2 = p.position + (move_delta.normalized() * particle_radius)

		_collision_query.from = p.prev_position
		_collision_query.to = cast_target
		var hit = space_state.intersect_ray(_collision_query)
		if not hit.is_empty():
			var hit_pos: Vector2 = hit.position
			var hit_norm: Vector2 = hit.normal

			p.position = hit_pos + (hit_norm * (particle_radius + 0.1))

			var vel: Vector2 = p.position - p.prev_position
			var norm_vel: Vector2 = hit_norm * vel.dot(hit_norm)
			var tang_vel: Vector2 = vel - norm_vel

			p.prev_position = p.position - (tang_vel * (1.0 - surface_friction) - norm_vel * bounce_factor)
			if vel.length_squared() > 100.0:
				body_impact.emit(hit_pos, hit_norm, vel.length())


func _draw() -> void:
	if particles.size() < 4:
		return

	var inv_xform: Transform2D = _safe_xform().affine_inverse()

	var poly_pts: PackedVector2Array = PackedVector2Array()
	for i in range(1, particles.size()):
		poly_pts.append(inv_xform * particles[i].position)

	# Draw filled body
	if poly_pts.size() >= 3:
		draw_colored_polygon(poly_pts, body_color)

		# Draw outline
		var closed_pts = poly_pts.duplicate()
		closed_pts.append(poly_pts[0])
		draw_polyline(closed_pts, outline_color, outline_width, true)

		# Draw cute gloss highlight on top-left
		if is_instance_valid(center_particle):
			var local_center = inv_xform * center_particle.position
			var shine_pos = local_center + Vector2(-radius * 0.3, -radius * 0.3)
			draw_circle(shine_pos, radius * 0.22, Color(1, 1, 1, 0.45))


func apply_impulse(impulse: Vector2) -> void:
	for p in particles:
		p.apply_impulse(impulse / float(particles.size()))

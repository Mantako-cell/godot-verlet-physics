#=============================================================================
# VerletCloth3D - 3D Tearable & Interactive Verlet Cloth Simulation for Godot 4.x
# Features: Structural, shear, and bending constraints, aerodynamic wind lift,
# continuous collision against 3D colliders, procedural smooth-shaded mesh,
# and runtime cutting/tearing.
#=============================================================================
@tool
class_name VerletCloth3D
extends Node3D

signal cloth_torn(x: int, y: int)

enum PinPreset {
	TOP_EDGE,
	TOP_TWO_CORNERS,
	FOUR_CORNERS,
	LEFT_EDGE,
	NONE,
	CUSTOM
}

# --- Cloth Dimensions ---
@export_group("Grid & Dimensions")
@export var resolution: Vector2i = Vector2i(12, 12):
	set(val):
		resolution = Vector2i(clampi(val.x, 2, 40), clampi(val.y, 2, 40))
		if Engine.is_editor_hint():
			_rebuild_cloth()

@export var cloth_size: Vector2 = Vector2(2.5, 2.5):
	set(val):
		cloth_size = Vector2(maxf(val.x, 0.1), maxf(val.y, 0.1))
		if Engine.is_editor_hint():
			_rebuild_cloth()

# --- Anchors & Pinning ---
@export_group("Pinning")
@export var pin_preset: PinPreset = PinPreset.TOP_EDGE:
	set(val):
		pin_preset = val
		_apply_pins()

@export var attach_corner_a: NodePath:
	set(val):
		attach_corner_a = val
		_cache_anchors()

@export var attach_corner_b: NodePath:
	set(val):
		attach_corner_b = val
		_cache_anchors()

# --- Physics Dynamics ---
@export_group("Dynamics")
@export var gravity: Vector3 = Vector3(0.0, -9.8, 0.0)
@export_range(0.8, 0.999, 0.001) var damping: float = 0.985
@export_range(0.1, 1.0, 0.05) var structural_stiffness: float = 0.95
@export_range(0.0, 1.0, 0.05) var shear_stiffness: float = 0.6
@export var enable_bending_constraints: bool = false
@export_range(0.0, 1.0, 0.05) var bending_stiffness: float = 0.25
@export_range(1, 25, 1) var solver_iterations: int = 6
@export_range(0.005, 1.0, 0.005) var particle_mass: float = 0.04

# --- Wind & Aerodynamics ---
@export_group("Aerodynamics")
@export var wind_vector: Vector3 = Vector3.ZERO
@export_range(0.0, 2.0, 0.05) var wind_turbulence: float = 0.5
@export_range(0.0, 2.0, 0.05) var aerodynamic_lift: float = 0.8

# --- Collisions ---
@export_group("Collisions")
@export var collision_enabled: bool = true
@export_range(0.01, 0.3, 0.005) var collision_radius: float = 0.03
@export_flags_3d_physics var collision_mask: int = 1
@export_range(0.0, 1.0, 0.05) var friction: float = 0.4

# --- Visuals & Materials ---
@export_group("Rendering")
@export var material: StandardMaterial3D:
	set(val):
		material = val
		if is_instance_valid(_mesh_instance):
			_mesh_instance.material_override = material

@export var double_sided_lighting: bool = true

# Internal Runtime Data
var particles: Array[Array] = [] # 2D array: particles[x][y] of VerletParticle3D
var structural_constraints: Array[VerletConstraint3D] = []
var shear_constraints: Array[VerletConstraint3D] = []
var bending_constraints: Array[VerletConstraint3D] = []

var _node_a_cache: Node3D = null
var _node_b_cache: Node3D = null

var _mesh_instance: MeshInstance3D = null
var _dynamic_mesh: ArrayMesh = null
var _time_acc: float = 0.0

var _cached_uvs: PackedVector2Array = PackedVector2Array()
var _cached_indices: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_cache_anchors()
	_setup_mesh()
	_rebuild_cloth()


func _cache_anchors() -> void:
	_node_a_cache = get_node_or_null(attach_corner_a) as Node3D if not attach_corner_a.is_empty() else null
	_node_b_cache = get_node_or_null(attach_corner_b) as Node3D if not attach_corner_b.is_empty() else null


func _setup_mesh() -> void:
	if not is_instance_valid(_mesh_instance):
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "__verlet_cloth_mesh__"
		_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		_dynamic_mesh = ArrayMesh.new()
		_mesh_instance.mesh = _dynamic_mesh

		if material:
			_mesh_instance.material_override = material
		else:
			var def_mat = StandardMaterial3D.new()
			def_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			def_mat.albedo_color = Color(0.2, 0.5, 0.95) # Royal Blue Cloth
			def_mat.roughness = 0.6
			_mesh_instance.material_override = def_mat

		add_child(_mesh_instance)


func _safe_xform() -> Transform3D:
	return global_transform if is_inside_tree() else transform


func _safe_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func _rebuild_cloth() -> void:
	particles.clear()
	structural_constraints.clear()
	shear_constraints.clear()
	bending_constraints.clear()

	var w_particles = resolution.x
	var h_particles = resolution.y
	var step_x = cloth_size.x / float(w_particles - 1)
	var step_y = cloth_size.y / float(h_particles - 1)

	var current_xform = _safe_xform()

	# Initialize 2D grid of particles
	for x in range(w_particles):
		var column: Array[VerletParticle3D] = []
		for y in range(h_particles):
			var local_offset = Vector3(
				(float(x) / float(w_particles - 1) - 0.5) * cloth_size.x,
				-float(y) * step_y,
				0.0
			)
			var world_pos = current_xform * local_offset
			var p = VerletParticle3D.new(world_pos, particle_mass, collision_radius)
			column.append(p)
		particles.append(column)

	# 1. Structural constraints (horizontal and vertical neighbors)
	for x in range(w_particles):
		for y in range(h_particles):
			# Horizontal link
			if x < w_particles - 1:
				var c_h = VerletConstraint3D.new(particles[x][y], particles[x + 1][y], step_x, structural_stiffness)
				structural_constraints.append(c_h)
			# Vertical link
			if y < h_particles - 1:
				var c_v = VerletConstraint3D.new(particles[x][y], particles[x][y + 1], step_y, structural_stiffness)
				structural_constraints.append(c_v)

	# 2. Shear constraints (diagonals)
	var diag_len = sqrt(step_x * step_x + step_y * step_y)
	for x in range(w_particles - 1):
		for y in range(h_particles - 1):
			var c_d1 = VerletConstraint3D.new(particles[x][y], particles[x + 1][y + 1], diag_len, shear_stiffness)
			var c_d2 = VerletConstraint3D.new(particles[x + 1][y], particles[x][y + 1], diag_len, shear_stiffness)
			shear_constraints.append(c_d1)
			shear_constraints.append(c_d2)

	# 3. Bending / Flexion constraints (skip 1 neighbor to resist severe creases)
	if enable_bending_constraints:
		for x in range(w_particles):
			for y in range(h_particles):
				if x < w_particles - 2:
					var c_bx = VerletConstraint3D.new(particles[x][y], particles[x + 2][y], step_x * 2.0, bending_stiffness)
					bending_constraints.append(c_bx)
				if y < h_particles - 2:
					var c_by = VerletConstraint3D.new(particles[x][y], particles[x][y + 2], step_y * 2.0, bending_stiffness)
					bending_constraints.append(c_by)

	_apply_pins()


func _apply_pins() -> void:
	if particles.is_empty():
		return

	var w = resolution.x
	var h = resolution.y

	# Reset all pins
	for x in range(w):
		for y in range(h):
			particles[x][y].unpin()

	match pin_preset:
		PinPreset.TOP_EDGE:
			for x in range(w):
				particles[x][0].pin_to_world(particles[x][0].position)

		PinPreset.TOP_TWO_CORNERS:
			if is_instance_valid(_node_a_cache):
				particles[0][0].pin_to_node(_node_a_cache)
			else:
				particles[0][0].pin_to_world(particles[0][0].position)

			if is_instance_valid(_node_b_cache):
				particles[w - 1][0].pin_to_node(_node_b_cache)
			else:
				particles[w - 1][0].pin_to_world(particles[w - 1][0].position)

		PinPreset.FOUR_CORNERS:
			particles[0][0].pin_to_world(particles[0][0].position)
			particles[w - 1][0].pin_to_world(particles[w - 1][0].position)
			particles[0][h - 1].pin_to_world(particles[0][h - 1].position)
			particles[w - 1][h - 1].pin_to_world(particles[w - 1][h - 1].position)

		PinPreset.LEFT_EDGE:
			for y in range(h):
				particles[0][y].pin_to_world(particles[0][y].position)

		PinPreset.NONE:
			pass
		PinPreset.CUSTOM:
			pass


func _physics_process(delta: float) -> void:
	if particles.is_empty():
		return

	_time_acc += delta
	var w = resolution.x
	var h = resolution.y

	# 1. Sync pinned particles
	for x in range(w):
		for y in range(h):
			if particles[x][y].is_pinned:
				particles[x][y].sync_pin()

	# 2. Accumulate Gravity
	var gravity_force: Vector3 = gravity * particle_mass
	for x in range(w):
		for y in range(h):
			var p: VerletParticle3D = particles[x][y]
			if not p.is_pinned:
				p.apply_force(gravity_force)

	# 3. Aerodynamic Wind Forces (Aerodynamic Normal Lift & Drag)
	if wind_vector.length_squared() > 0.001:
		var cur_pos = _safe_pos()
		var turbulence = Vector3(
			sin(_time_acc * 4.2 + cur_pos.x),
			cos(_time_acc * 3.1 + cur_pos.y),
			sin(_time_acc * 5.0 + cur_pos.z)
		) * wind_turbulence
		var current_wind = wind_vector + (turbulence * wind_vector.length())

		for x in range(w - 1):
			for y in range(h - 1):
				var p00: VerletParticle3D = particles[x][y]
				var p10: VerletParticle3D = particles[x + 1][y]
				var p01: VerletParticle3D = particles[x][y + 1]

				# Face normal of triangle
				var edge1: Vector3 = p10.position - p00.position
				var edge2: Vector3 = p01.position - p00.position
				var face_normal: Vector3 = edge1.cross(edge2)
				var area: float = face_normal.length() * 0.5
				if area > 0.00001:
					face_normal = face_normal / (area * 2.0)
					var wind_dot: float = current_wind.dot(face_normal)
					var aero_force: Vector3 = face_normal * (wind_dot * area * aerodynamic_lift * 10.0)
					var third_force: Vector3 = aero_force / 3.0

					if not p00.is_pinned: p00.apply_force(third_force)
					if not p10.is_pinned: p10.apply_force(third_force)
					if not p01.is_pinned: p01.apply_force(third_force)

	# 4. Integrate Verlet Kinematics
	for x in range(w):
		for y in range(h):
			particles[x][y].integrate(delta, damping)

	# 5. Solve Constraints
	for iter in range(solver_iterations):
		for c in structural_constraints:
			c.solve()
		for c in shear_constraints:
			c.solve()
		if enable_bending_constraints:
			for c in bending_constraints:
				c.solve()

	# 6. Continuous World Collisions
	if collision_enabled and is_inside_tree():
		var space_state = get_world_3d().direct_space_state
		if space_state:
			_solve_cloth_collisions(space_state)

	# 7. Render dynamic mesh
	_update_cloth_mesh()


func _solve_cloth_collisions(space_state: PhysicsDirectSpaceState3D) -> void:
	var w = resolution.x
	var h = resolution.y

	for x in range(w):
		for y in range(h):
			var p: VerletParticle3D = particles[x][y]
			if p.is_pinned or not p.active:
				continue

			var move_delta: Vector3 = p.position - p.prev_position
			var move_dist: float = move_delta.length()
			var cast_target: Vector3 = p.position
			if move_dist > 0.0001:
				cast_target += (move_delta / move_dist) * collision_radius
			else:
				cast_target += Vector3.DOWN * collision_radius

			var excludes: Array[RID] = []
			if is_instance_valid(_node_a_cache) and _node_a_cache is CollisionObject3D:
				excludes.append((_node_a_cache as CollisionObject3D).get_rid())
			if is_instance_valid(_node_b_cache) and _node_b_cache is CollisionObject3D:
				excludes.append((_node_b_cache as CollisionObject3D).get_rid())

			var query = PhysicsRayQueryParameters3D.create(p.prev_position, cast_target, collision_mask, excludes)
			var hit = space_state.intersect_ray(query)
			if not hit.is_empty():
				var hit_pos: Vector3 = hit.position
				var hit_norm: Vector3 = hit.normal

				p.position = hit_pos + (hit_norm * (collision_radius + 0.001))

				# Friction
				var vel: Vector3 = p.position - p.prev_position
				var normal_vel: Vector3 = hit_norm * vel.dot(hit_norm)
				var tangent_vel: Vector3 = vel - normal_vel
				p.prev_position = p.position - (tangent_vel * (1.0 - friction))


func _rebuild_cloth_indices_and_uvs() -> void:
	var w = resolution.x
	var h = resolution.y
	var total_verts: int = w * h

	_cached_uvs.resize(total_verts)
	for x in range(w):
		for y in range(h):
			var idx: int = y * w + x
			_cached_uvs[idx] = Vector2(float(x) / float(w - 1), float(y) / float(h - 1))

	_cached_indices.clear()
	for x in range(w - 1):
		for y in range(h - 1):
			var i00 = y * w + x
			var i10 = y * w + (x + 1)
			var i01 = (y + 1) * w + x
			var i11 = (y + 1) * w + (x + 1)

			# Tri 1: i00, i10, i01
			_cached_indices.append(i00)
			_cached_indices.append(i10)
			_cached_indices.append(i01)

			# Tri 2: i10, i11, i01
			_cached_indices.append(i10)
			_cached_indices.append(i11)
			_cached_indices.append(i01)


func _update_cloth_mesh() -> void:
	if not is_instance_valid(_mesh_instance) or not is_instance_valid(_dynamic_mesh):
		return

	var w = resolution.x
	var h = resolution.y
	var total_verts: int = w * h

	if _cached_indices.is_empty() or _cached_uvs.size() != total_verts:
		_rebuild_cloth_indices_and_uvs()

	var verts: PackedVector3Array = PackedVector3Array()
	verts.resize(total_verts)
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(total_verts)

	var inv_xform = _safe_xform().affine_inverse()

	# Populate vertices
	for x in range(w):
		for y in range(h):
			var idx: int = y * w + x
			verts[idx] = inv_xform * particles[x][y].position
			normals[idx] = Vector3.ZERO

	# Fast triangle-based normal calculation
	var num_indices: int = _cached_indices.size()
	var i: int = 0
	while i < num_indices:
		var i0 = _cached_indices[i]
		var i1 = _cached_indices[i + 1]
		var i2 = _cached_indices[i + 2]
		i += 3

		var v0 = verts[i0]
		var v1 = verts[i1]
		var v2 = verts[i2]
		var fn = (v1 - v0).cross(v2 - v0)
		normals[i0] += fn
		normals[i1] += fn
		normals[i2] += fn

	# Normalize accumulated normals
	for idx in range(total_verts):
		if normals[idx].length_squared() > 0.0001:
			normals[idx] = normals[idx].normalized()
		else:
			normals[idx] = Vector3.FORWARD

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = _cached_uvs
	arrays[Mesh.ARRAY_INDEX] = _cached_indices

	_dynamic_mesh.clear_surfaces()
	_dynamic_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)



# =============================================================================
# Public Gameplay API
# =============================================================================

func tear_at(coord_x: int, coord_y: int) -> void:
	if coord_x < 0 or coord_x >= resolution.x or coord_y < 0 or coord_y >= resolution.y:
		return

	var target_p = particles[coord_x][coord_y]

	# Deactivate connected constraints
	for c in structural_constraints:
		if c.p1 == target_p or c.p2 == target_p:
			c.is_active = false
	for c in shear_constraints:
		if c.p1 == target_p or c.p2 == target_p:
			c.is_active = false
	for c in bending_constraints:
		if c.p1 == target_p or c.p2 == target_p:
			c.is_active = false

	_cached_indices.clear()
	cloth_torn.emit(coord_x, coord_y)


func apply_wind_gust(gust: Vector3) -> void:
	wind_vector += gust


func apply_impulse_at(x: int, y: int, impulse: Vector3) -> void:
	if x >= 0 and x < resolution.x and y >= 0 and y < resolution.y:
		particles[x][y].apply_impulse(impulse)

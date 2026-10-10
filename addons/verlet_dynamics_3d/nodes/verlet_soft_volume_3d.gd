#=============================================================================
# VerletSoftVolume3D - Deformable 3D Soft Body Volume / Jelly for Godot 4.x
# Features: Lattice structure with internal diagonal cross-bracing,
# shape-restoration elasticity, dynamic squashing & bouncing on surfaces.
#=============================================================================
@tool
class_name VerletSoftVolume3D
extends Node3D

signal volume_impact(point: Vector3, normal: Vector3, force: float)

# --- Dimensions & Mass ---
@export_group("Volume Dimensions")
@export var size: Vector3 = Vector3(1.0, 1.0, 1.0):
	set(val):
		size = Vector3(maxf(val.x, 0.2), maxf(val.y, 0.2), maxf(val.z, 0.2))
		if Engine.is_editor_hint():
			_rebuild_volume()

@export_range(0.05, 5.0, 0.05) var total_mass: float = 1.0

# --- Elasticity & Soft Body Dynamics ---
@export_group("Soft Body Dynamics")
@export var gravity: Vector3 = Vector3(0.0, -9.8, 0.0)
@export_range(0.85, 0.999, 0.001) var damping: float = 0.985
@export_range(0.05, 1.0, 0.02) var elasticity_stiffness: float = 0.85
@export_range(0.05, 1.0, 0.02) var internal_brace_stiffness: float = 0.7
@export_range(2, 30, 1) var solver_iterations: int = 10

# --- Collisions ---
@export_group("Collisions")
@export var collision_enabled: bool = true
@export_range(0.01, 0.5, 0.01) var particle_radius: float = 0.1
@export_flags_3d_physics var collision_mask: int = 1
@export_range(0.0, 1.0, 0.05) var bounce_factor: float = 0.6
@export_range(0.0, 1.0, 0.05) var friction: float = 0.3

# --- Visuals ---
@export_group("Visuals")
@export var material: StandardMaterial3D:
	set(val):
		material = val
		if is_instance_valid(_mesh_instance):
			_mesh_instance.material_override = material

# Particles (8 corner vertices of a deformable cube lattice + center particle)
var particles: Array[VerletParticle3D] = []
var constraints: Array[VerletConstraint3D] = []

var _mesh_instance: MeshInstance3D = null
var _dynamic_mesh: ArrayMesh = null


func _ready() -> void:
	_setup_mesh()
	_rebuild_volume()


func _setup_mesh() -> void:
	if not is_instance_valid(_mesh_instance):
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "__verlet_soft_mesh__"
		_dynamic_mesh = ArrayMesh.new()
		_mesh_instance.mesh = _dynamic_mesh

		if material:
			_mesh_instance.material_override = material
		else:
			var jelly_mat = StandardMaterial3D.new()
			jelly_mat.albedo_color = Color(0.9, 0.2, 0.4, 0.9) # Translucent Ruby Jelly
			jelly_mat.roughness = 0.2
			jelly_mat.metallic = 0.1
			jelly_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_mesh_instance.material_override = jelly_mat

		add_child(_mesh_instance)


func _safe_xform() -> Transform3D:
	return global_transform if is_inside_tree() else transform


func _rebuild_volume() -> void:
	particles.clear()
	constraints.clear()

	var hs = size * 0.5
	var p_mass = total_mass / 8.0
	var current_xform = _safe_xform()

	# 8 corners of the cube in local space
	var corner_offsets = [
		Vector3(-hs.x, -hs.y, -hs.z), # 0
		Vector3( hs.x, -hs.y, -hs.z), # 1
		Vector3( hs.x,  hs.y, -hs.z), # 2
		Vector3(-hs.x,  hs.y, -hs.z), # 3
		Vector3(-hs.x, -hs.y,  hs.z), # 4
		Vector3( hs.x, -hs.y,  hs.z), # 5
		Vector3( hs.x,  hs.y,  hs.z), # 6
		Vector3(-hs.x,  hs.y,  hs.z)  # 7
	]

	for offset in corner_offsets:
		var world_pos = current_xform * offset
		var p = VerletParticle3D.new(world_pos, p_mass, particle_radius)
		particles.append(p)

	# Edge connections (12 edges of a cube)
	var edges = [
		[0, 1], [1, 2], [2, 3], [3, 0], # Back face
		[4, 5], [5, 6], [6, 7], [7, 4], # Front face
		[0, 4], [1, 5], [2, 6], [3, 7]  # Connecting pillars
	]

	for e in edges:
		var c = VerletConstraint3D.new(particles[e[0]], particles[e[1]], -1.0, elasticity_stiffness)
		constraints.append(c)

	# Face diagonal cross-braces (2 per face = 12 constraints)
	var face_diags = [
		[0, 2], [1, 3], # Back
		[4, 6], [5, 7], # Front
		[0, 5], [1, 4], # Bottom
		[3, 6], [2, 7], # Top
		[0, 7], [3, 4], # Left
		[1, 6], [2, 5]  # Right
	]

	for fd in face_diags:
		var c = VerletConstraint3D.new(particles[fd[0]], particles[fd[1]], -1.0, internal_brace_stiffness)
		constraints.append(c)

	# Internal 3D body diagonals (4 corner-to-opposite-corner struts for volume preservation)
	var body_diags = [
		[0, 6], [1, 7], [2, 4], [3, 5]
	]

	for bd in body_diags:
		var c = VerletConstraint3D.new(particles[bd[0]], particles[bd[1]], -1.0, internal_brace_stiffness * 1.1)
		constraints.append(c)


func _physics_process(delta: float) -> void:
	if particles.is_empty():
		return

	# 1. Accumulate gravity
	var g_force: Vector3 = gravity * (total_mass / float(particles.size()))
	for p in particles:
		p.apply_force(g_force)

	# 2. Verlet integrate
	for p in particles:
		p.integrate(delta, damping)

	# 3. Solve distance & volume constraints
	for iter in range(solver_iterations):
		for c in constraints:
			c.solve()

	# 4. Collisions
	if collision_enabled and is_inside_tree():
		var space_state = get_world_3d().direct_space_state
		if space_state:
			_solve_volume_collisions(space_state)

	# 5. Render deformed volume mesh
	_update_volume_mesh()


func _solve_volume_collisions(space_state: PhysicsDirectSpaceState3D) -> void:
	for p in particles:
		var move_delta: Vector3 = p.position - p.prev_position
		var cast_target: Vector3 = p.position + (move_delta.normalized() * particle_radius)

		var query = PhysicsRayQueryParameters3D.create(p.prev_position, cast_target, collision_mask)
		var hit = space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.position
			var hit_norm: Vector3 = hit.normal

			p.position = hit_pos + (hit_norm * (particle_radius + 0.001))

			var vel: Vector3 = p.position - p.prev_position
			var norm_vel: Vector3 = hit_norm * vel.dot(hit_norm)
			var tang_vel: Vector3 = vel - norm_vel

			# Elastic bounce
			p.prev_position = p.position - (tang_vel * (1.0 - friction) - norm_vel * bounce_factor)
			volume_impact.emit(hit_pos, hit_norm, vel.length())


func _update_volume_mesh() -> void:
	if not is_instance_valid(_mesh_instance) or not is_instance_valid(_dynamic_mesh):
		return
	if particles.size() < 8:
		return

	var inv_xform = _safe_xform().affine_inverse()
	var local_pts: Array[Vector3] = []
	for p in particles:
		local_pts.append(inv_xform * p.position)

	# 6 quads (12 triangles) of the deformed cube
	# Face vertex definitions: [p0, p1, p2, p3]
	var faces = [
		[3, 2, 1, 0], # Back (-Z)
		[4, 5, 6, 7], # Front (+Z)
		[0, 1, 5, 4], # Bottom (-Y)
		[7, 6, 2, 3], # Top (+Y)
		[0, 4, 7, 3], # Left (-X)
		[5, 1, 2, 6]  # Right (+X)
	]

	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	var vert_counter: int = 0
	for f in faces:
		var v0 = local_pts[f[0]]
		var v1 = local_pts[f[1]]
		var v2 = local_pts[f[2]]
		var v3 = local_pts[f[3]]

		var fn = (v1 - v0).cross(v2 - v0).normalized()

		verts.append(v0); normals.append(fn); uvs.append(Vector2(0, 0))
		verts.append(v1); normals.append(fn); uvs.append(Vector2(1, 0))
		verts.append(v2); normals.append(fn); uvs.append(Vector2(1, 1))
		verts.append(v3); normals.append(fn); uvs.append(Vector2(0, 1))

		indices.append(vert_counter + 0)
		indices.append(vert_counter + 1)
		indices.append(vert_counter + 2)

		indices.append(vert_counter + 0)
		indices.append(vert_counter + 2)
		indices.append(vert_counter + 3)

		vert_counter += 4

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	_dynamic_mesh.clear_surfaces()
	_dynamic_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func apply_impulse(impulse: Vector3) -> void:
	for p in particles:
		p.apply_impulse(impulse / float(particles.size()))

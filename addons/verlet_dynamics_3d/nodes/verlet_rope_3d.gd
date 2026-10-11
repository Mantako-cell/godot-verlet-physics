#=============================================================================
# VerletRope3D - Interactive 3D Verlet Rope, Cable & Chain for Godot 4.x
# Features: Continuous collision detection, 2-way RigidBody3D coupling,
# breakable tension, procedural tube & chain rendering, wind & slack control.
#=============================================================================
@tool
class_name VerletRope3D
extends Node3D

signal rope_snapped(segment_index: int)
signal particle_collided(index: int, point: Vector3, normal: Vector3)

enum RenderMode {
	TUBE_MESH,
	CHAIN_LINKS,
	DEBUG_LINE,
	NONE
}

# --- Rope Geometry ---
@export_group("Geometry")
@export_range(0.2, 50.0, 0.1) var length: float = 4.0:
	set(val):
		length = maxf(val, 0.1)
		if Engine.is_editor_hint():
			_rebuild_rope()

@export_range(2, 100, 1) var segment_count: int = 16:
	set(val):
		segment_count = clampi(val, 2, 128)
		if Engine.is_editor_hint():
			_rebuild_rope()

@export_range(0.5, 3.0, 0.05) var slack_ratio: float = 1.0:
	set(val):
		slack_ratio = clampf(val, 0.5, 5.0)
		if Engine.is_editor_hint():
			_rebuild_rope()

@export var auto_length_from_targets: bool = false

# --- Anchors & Attachments ---
@export_group("Anchors")
@export var pin_start: bool = true:
	set(val):
		pin_start = val
		_update_pins()

@export var attach_start_to: NodePath:
	set(val):
		attach_start_to = val
		_cache_anchor_nodes()
		_update_pins()

@export var start_pin_offset: Vector3 = Vector3.ZERO:
	set(val):
		start_pin_offset = val
		_update_pins()

@export var pin_end: bool = true:
	set(val):
		pin_end = val
		_update_pins()

@export var attach_end_to: NodePath:
	set(val):
		attach_end_to = val
		_cache_anchor_nodes()
		_update_pins()

@export var end_pin_offset: Vector3 = Vector3.ZERO:
	set(val):
		end_pin_offset = val
		_update_pins()

@export var apply_forces_to_rigidbodies: bool = true
@export_range(0.1, 10.0, 0.1) var rigidbody_force_multiplier: float = 1.0

# --- Physics Dynamics ---
@export_group("Dynamics")
@export var gravity: Vector3 = Vector3(0.0, -9.8, 0.0)
@export_range(0.8, 0.999, 0.001) var damping: float = 0.985
@export_range(0.1, 1.0, 0.01) var stiffness: float = 0.95
@export_range(1, 30, 1) var solver_iterations: int = 8
@export_range(0.01, 10.0, 0.05) var particle_mass: float = 0.2

# --- Snapping & Breaking ---
@export_group("Breaking")
@export var breakable: bool = false
@export_range(10.0, 5000.0, 10.0) var break_tension_threshold: float = 600.0

# --- Collisions ---
@export_group("Collisions")
@export var collision_enabled: bool = true
@export_range(0.005, 0.5, 0.005) var collision_radius: float = 0.04
@export_flags_3d_physics var collision_mask: int = 1
@export_range(0.0, 1.0, 0.05) var surface_friction: float = 0.4
@export_range(0.0, 1.0, 0.05) var surface_bounce: float = 0.05

# --- Wind & Environment ---
@export_group("Wind")
@export var wind_vector: Vector3 = Vector3.ZERO
@export_range(0.0, 2.0, 0.05) var wind_turbulence: float = 0.3

# --- Visuals & Rendering ---
@export_group("Rendering")
@export var render_mode: RenderMode = RenderMode.TUBE_MESH:
	set(val):
		render_mode = val
		_setup_renderers()

@export_range(0.005, 0.5, 0.005) var rope_radius: float = 0.035:
	set(val):
		rope_radius = maxf(val, 0.002)

@export_range(3, 32, 1) var radial_segments: int = 8
@export var material: StandardMaterial3D:
	set(val):
		material = val
		if is_instance_valid(_mesh_instance):
			_mesh_instance.material_override = material
		if is_instance_valid(_multimesh_instance):
			_multimesh_instance.material_override = material

@export var chain_link_mesh: Mesh:
	set(val):
		chain_link_mesh = val
		if is_instance_valid(_multimesh_instance) and is_instance_valid(_multimesh_instance.multimesh):
			_multimesh_instance.multimesh.mesh = chain_link_mesh

@export var chain_link_scale: Vector3 = Vector3(0.12, 0.12, 0.12)
@export var chain_alternate_rotation: bool = true
@export var visualize_tension: bool = false
@export var snap_particles_enabled: bool = true

# Internal runtime state
var particles: Array[VerletParticle3D] = []
var constraints: Array[VerletConstraint3D] = []
var _start_node_cache: Node3D = null
var _end_node_cache: Node3D = null
var _start_rigidbody: RigidBody3D = null
var _end_rigidbody: RigidBody3D = null

var _mesh_instance: MeshInstance3D = null
var _multimesh_instance: MultiMeshInstance3D = null
var _immediate_mesh_instance: MeshInstance3D = null
var _dynamic_mesh: ArrayMesh = null

var _time_accumulator: float = 0.0
var _is_initialized: bool = false
var _cached_tube_indices: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_cache_anchor_nodes()
	_rebuild_rope()
	_setup_renderers()
	_is_initialized = true


func _cache_anchor_nodes() -> void:
	_start_node_cache = get_node_or_null(attach_start_to) as Node3D if not attach_start_to.is_empty() else null
	_end_node_cache = get_node_or_null(attach_end_to) as Node3D if not attach_end_to.is_empty() else null
	_start_rigidbody = _start_node_cache as RigidBody3D
	_end_rigidbody = _end_node_cache as RigidBody3D


func _setup_renderers() -> void:
	# Clear old renderers if any
	for child in get_children():
		if child.name.begins_with("__verlet_render_"):
			child.queue_free()

	_mesh_instance = null
	_multimesh_instance = null
	_immediate_mesh_instance = null
	_dynamic_mesh = null

	match render_mode:
		RenderMode.TUBE_MESH:
			_mesh_instance = MeshInstance3D.new()
			_mesh_instance.name = "__verlet_render_tube__"
			_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_dynamic_mesh = ArrayMesh.new()
			_mesh_instance.mesh = _dynamic_mesh
			if material:
				_mesh_instance.material_override = material
			else:
				var def_mat = StandardMaterial3D.new()
				def_mat.albedo_color = Color(0.85, 0.65, 0.45) # Natural rope hemp color
				def_mat.roughness = 0.8
				_mesh_instance.material_override = def_mat
			add_child(_mesh_instance)

		RenderMode.CHAIN_LINKS:
			_multimesh_instance = MultiMeshInstance3D.new()
			_multimesh_instance.name = "__verlet_render_chain__"
			var mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.instance_count = max(1, segment_count)
			if chain_link_mesh:
				mm.mesh = chain_link_mesh
			else:
				var torus = TorusMesh.new()
				torus.inner_radius = 0.03
				torus.outer_radius = 0.07
				torus.rings = 12
				torus.ring_segments = 6
				mm.mesh = torus
			_multimesh_instance.multimesh = mm
			if material:
				_multimesh_instance.material_override = material
			else:
				var steel_mat = StandardMaterial3D.new()
				steel_mat.metallic = 0.85
				steel_mat.roughness = 0.25
				steel_mat.albedo_color = Color(0.7, 0.72, 0.75)
				_multimesh_instance.material_override = steel_mat
			add_child(_multimesh_instance)

		RenderMode.DEBUG_LINE:
			_immediate_mesh_instance = MeshInstance3D.new()
			_immediate_mesh_instance.name = "__verlet_render_debug__"
			_immediate_mesh_instance.mesh = ImmediateMesh.new()
			var line_mat = StandardMaterial3D.new()
			line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			line_mat.albedo_color = Color(0.2, 1.0, 0.3)
			_immediate_mesh_instance.material_override = line_mat
			add_child(_immediate_mesh_instance)


func _safe_xform() -> Transform3D:
	return global_transform if is_inside_tree() else transform


func _safe_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func _rebuild_rope() -> void:
	particles.clear()
	constraints.clear()
	_cached_tube_indices.clear()

	var current_xform: Transform3D = _safe_xform()
	var start_pos: Vector3 = _safe_pos()
	if is_instance_valid(_start_node_cache):
		var target_xform = _start_node_cache.global_transform if _start_node_cache.is_inside_tree() else _start_node_cache.transform
		start_pos = target_xform * start_pin_offset

	var end_pos: Vector3 = start_pos + (-current_xform.basis.y * length)
	if is_instance_valid(_end_node_cache):
		var target_xform = _end_node_cache.global_transform if _end_node_cache.is_inside_tree() else _end_node_cache.transform
		end_pos = target_xform * end_pin_offset
	elif not is_instance_valid(_start_node_cache):
		# Default hanging down in local space
		end_pos = _safe_pos() + Vector3(0.0, -length, 0.0)

	var straight_dist: float = start_pos.distance_to(end_pos)
	var active_length: float = length
	if auto_length_from_targets and straight_dist > 0.001:
		active_length = straight_dist * slack_ratio
	else:
		active_length = maxf(length * slack_ratio, straight_dist)

	var num_particles: int = segment_count + 1
	var rest_segment_len: float = active_length / float(segment_count)

	# Generate particles along initial catenary/arc
	for i in range(num_particles):
		var t: float = float(i) / float(segment_count)
		# Interpolate with slight catenary sag
		var linear_pos: Vector3 = start_pos.lerp(end_pos, t)
		var sag_factor: float = sin(t * PI) * (active_length - straight_dist) * 0.5
		var sag_vector: Vector3 = Vector3.DOWN * sag_factor
		var p_pos: Vector3 = linear_pos + sag_vector

		var particle = VerletParticle3D.new(p_pos, particle_mass, collision_radius)
		particles.append(particle)

	# Setup constraints
	for i in range(segment_count):
		var constraint = VerletConstraint3D.new(particles[i], particles[i + 1], rest_segment_len, stiffness)
		constraint.can_break = breakable
		constraint.break_tension_limit = break_tension_threshold
		constraints.append(constraint)

	_update_pins()


func _update_pins() -> void:
	if particles.is_empty():
		return

	# Start particle pin
	if pin_start:
		if is_instance_valid(_start_node_cache):
			particles[0].pin_to_node(_start_node_cache, start_pin_offset)
		else:
			particles[0].pin_to_world(_safe_pos() + start_pin_offset)
	else:
		particles[0].unpin()

	# End particle pin
	var last_idx: int = particles.size() - 1
	if pin_end:
		if is_instance_valid(_end_node_cache):
			particles[last_idx].pin_to_node(_end_node_cache, end_pin_offset)
		else:
			var default_end: Vector3 = _safe_pos() + Vector3(0.0, -length, 0.0) + end_pin_offset
			particles[last_idx].pin_to_world(default_end)
	else:
		particles[last_idx].unpin()


func _physics_process(delta: float) -> void:
	if particles.is_empty():
		return

	_time_accumulator += delta

	# In editor, keep pins synced so user can drag nodes and see rope react
	if Engine.is_editor_hint():
		_cache_anchor_nodes()
		_update_pins()

	# 1. Sync pinned particles to anchors
	for p in particles:
		if p.is_pinned:
			p.sync_pin()

	# 2. Accumulate forces (Gravity & Wind)
	var dynamic_wind: Vector3 = wind_vector
	if wind_vector.length_squared() > 0.001 and wind_turbulence > 0.0:
		var turbulence_noise = Vector3(
			sin(_time_accumulator * 3.7 + global_position.x),
			cos(_time_accumulator * 2.9 + global_position.y),
			sin(_time_accumulator * 4.1 + global_position.z)
		) * wind_turbulence
		dynamic_wind += turbulence_noise * wind_vector.length()

	var total_force: Vector3 = (gravity * particle_mass) + dynamic_wind

	for p in particles:
		if not p.is_pinned:
			p.apply_force(total_force)

	# 3. Verlet Integration step
	for p in particles:
		p.integrate(delta, damping)

	# 4. Solve Constraints (Iterative Relaxation)
	for iter in range(solver_iterations):
		for c_idx in range(constraints.size()):
			var c = constraints[c_idx]
			if c.is_active:
				var snapped: bool = c.solve()
				if snapped:
					rope_snapped.emit(c_idx)
					_spawn_snap_fx((c.p1.position + c.p2.position) * 0.5)

	# 5. Continuous World Collisions (Ray/Sphere queries)
	if collision_enabled and is_inside_tree():
		var space_state = get_world_3d().direct_space_state
		if space_state:
			_solve_collisions(space_state)

	# 6. Bidirectional RigidBody3D Coupling
	if apply_forces_to_rigidbodies:
		_apply_rigidbody_coupling()

	# 7. Update Visual Representation
	_update_visuals()


func _solve_collisions(space_state: PhysicsDirectSpaceState3D) -> void:
	for idx in range(particles.size()):
		var p = particles[idx]
		if p.is_pinned or not p.active:
			continue

		var move_delta: Vector3 = p.position - p.prev_position
		var move_dist: float = move_delta.length()
		var cast_target: Vector3 = p.position
		if move_dist > 0.0001:
			cast_target += (move_delta / move_dist) * collision_radius
		else:
			cast_target += Vector3.DOWN * collision_radius

		# Exclude attached bodies so rope doesn't collide with its own anchor
		var excludes: Array[RID] = []
		if is_instance_valid(_start_rigidbody):
			excludes.append(_start_rigidbody.get_rid())
		if is_instance_valid(_end_rigidbody):
			excludes.append(_end_rigidbody.get_rid())

		var query = PhysicsRayQueryParameters3D.create(p.prev_position, cast_target, collision_mask, excludes)

		var hit = space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.position
			var hit_norm: Vector3 = hit.normal

			# Push particle outside surface
			p.position = hit_pos + (hit_norm * (collision_radius + 0.001))

			# Apply friction to tangential velocity and bounce along normal
			var vel: Vector3 = (p.position - p.prev_position)
			var normal_vel: Vector3 = hit_norm * vel.dot(hit_norm)
			var tangent_vel: Vector3 = vel - normal_vel

			var new_vel: Vector3 = (tangent_vel * (1.0 - surface_friction)) - (normal_vel * surface_bounce)
			p.prev_position = p.position - new_vel

			particle_collided.emit(idx, hit_pos, hit_norm)


func _apply_rigidbody_coupling() -> void:
	if particles.size() < 2:
		return

	# Tension acting on start rigidbody
	if is_instance_valid(_start_rigidbody) and pin_start:
		var p0 = particles[0]
		var p1 = particles[1]
		var tension_dir: Vector3 = (p1.position - p0.position).normalized()
		var tension_force: Vector3 = tension_dir * constraints[0].current_tension * rigidbody_force_multiplier
		var rel_vel: Vector3 = _start_rigidbody.linear_velocity
		var damp_force: Vector3 = tension_dir * (rel_vel.dot(tension_dir) * 10.0)
		_start_rigidbody.apply_force(tension_force - damp_force, p0.position - _start_rigidbody.global_position)

	# Tension acting on end rigidbody
	var last_idx: int = particles.size() - 1
	if is_instance_valid(_end_rigidbody) and pin_end:
		var p_end = particles[last_idx]
		var p_prev = particles[last_idx - 1]
		var tension_dir: Vector3 = (p_prev.position - p_end.position).normalized()
		var tension_force: Vector3 = tension_dir * constraints[constraints.size() - 1].current_tension * rigidbody_force_multiplier
		var rel_vel: Vector3 = _end_rigidbody.linear_velocity
		var damp_force: Vector3 = tension_dir * (rel_vel.dot(tension_dir) * 10.0)
		_end_rigidbody.apply_force(tension_force - damp_force, p_end.position - _end_rigidbody.global_position)


func _update_visuals() -> void:
	match render_mode:
		RenderMode.TUBE_MESH:
			_render_tube_mesh()
		RenderMode.CHAIN_LINKS:
			_render_chain_links()
		RenderMode.DEBUG_LINE:
			_render_debug_lines()
		RenderMode.NONE:
			pass


func _render_tube_mesh() -> void:
	if not is_instance_valid(_mesh_instance) or not is_instance_valid(_dynamic_mesh):
		return
	if particles.size() < 2:
		return

	var rings: int = particles.size()
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	var local_to_global_xform_inv: Transform3D = _safe_xform().affine_inverse()

	# Build local positions
	var pts: Array[Vector3] = []
	for p in particles:
		pts.append(local_to_global_xform_inv * p.position)

	# Compute curve coordinate frames with parallel transport to prevent twist
	var tangents: Array[Vector3] = []
	for i in range(rings):
		var t_vec: Vector3 = Vector3.UP
		if i == 0:
			t_vec = (pts[1] - pts[0]).normalized()
		elif i == rings - 1:
			t_vec = (pts[rings - 1] - pts[rings - 2]).normalized()
		else:
			t_vec = ((pts[i + 1] - pts[i]) + (pts[i] - pts[i - 1])).normalized()
		if t_vec.length_squared() < 0.001:
			t_vec = Vector3.UP
		tangents.append(t_vec)

	# Initial perpendicular frame vector
	var initial_t: Vector3 = tangents[0]
	var initial_n: Vector3 = Vector3.UP.cross(initial_t)
	if initial_n.length_squared() < 0.001:
		initial_n = Vector3.RIGHT.cross(initial_t)
	initial_n = initial_n.normalized()

	var cur_n: Vector3 = initial_n
	var cur_b: Vector3 = initial_t.cross(cur_n).normalized()

	var frames_n: Array[Vector3] = [cur_n]
	var frames_b: Array[Vector3] = [cur_b]

	for i in range(1, rings):
		var prev_t = tangents[i - 1]
		var new_t = tangents[i]
		var rot_axis = prev_t.cross(new_t)
		if rot_axis.length_squared() > 0.0001:
			var rot_angle = prev_t.angle_to(new_t)
			var quat = Quaternion(rot_axis.normalized(), rot_angle)
			cur_n = (quat * cur_n).normalized()
		cur_b = new_t.cross(cur_n).normalized()
		frames_n.append(cur_n)
		frames_b.append(cur_b)

	if _cached_tube_indices.is_empty():
		_rebuild_tube_indices()

	var total_verts: int = rings * radial_segments
	verts.resize(total_verts)
	normals.resize(total_verts)
	uvs.resize(total_verts)
	var colors: PackedColorArray = PackedColorArray()
	if visualize_tension:
		colors.resize(total_verts)

	var v_idx: int = 0
	# Generate cylinder rings
	for r in range(rings):
		var center = pts[r]
		var n_vec = frames_n[r]
		var b_vec = frames_b[r]
		var v_coord: float = float(r) / float(rings - 1)

		var ring_color = Color.WHITE
		if visualize_tension:
			var tension_ratio: float = 0.0
			if not constraints.is_empty():
				var c_idx = mini(r, constraints.size() - 1)
				tension_ratio = clampf(constraints[c_idx].current_tension / maxf(break_tension_threshold, 1.0), 0.0, 1.0)
			if tension_ratio > 0.5:
				ring_color = Color(1.0, 0.85, 0.1).lerp(Color(1.0, 0.15, 0.1), (tension_ratio - 0.5) * 2.0)
			else:
				ring_color = Color(0.15, 0.9, 0.45).lerp(Color(1.0, 0.85, 0.1), tension_ratio * 2.0)

		for s in range(radial_segments):
			var theta: float = (float(s) / float(radial_segments)) * TAU
			var cos_t = cos(theta)
			var sin_t = sin(theta)
			var circle_dir = (n_vec * cos_t + b_vec * sin_t).normalized()
			var vert_pos = center + (circle_dir * rope_radius)

			verts[v_idx] = vert_pos
			normals[v_idx] = circle_dir
			uvs[v_idx] = Vector2(float(s) / float(radial_segments), v_coord * (length / (rope_radius * 2.0)))
			if visualize_tension:
				colors[v_idx] = ring_color
			v_idx += 1

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if visualize_tension:
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = _cached_tube_indices

	_dynamic_mesh.clear_surfaces()
	if verts.size() > 0 and _cached_tube_indices.size() > 0:
		_dynamic_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _rebuild_tube_indices() -> void:
	var rings: int = particles.size()
	_cached_tube_indices.clear()
	for r in range(rings - 1):
		# If a constraint between r and r+1 was broken, don't generate mesh connection!
		if r < constraints.size() and not constraints[r].is_active:
			continue

		for s in range(radial_segments):
			var next_s = (s + 1) % radial_segments
			var cur_row = r * radial_segments
			var next_row = (r + 1) * radial_segments

			var i0 = cur_row + s
			var i1 = next_row + s
			var i2 = next_row + next_s
			var i3 = cur_row + next_s

			# Triangle 1
			_cached_tube_indices.append(i0)
			_cached_tube_indices.append(i1)
			_cached_tube_indices.append(i2)

			# Triangle 2
			_cached_tube_indices.append(i0)
			_cached_tube_indices.append(i2)
			_cached_tube_indices.append(i3)



func _render_chain_links() -> void:
	if not is_instance_valid(_multimesh_instance) or not is_instance_valid(_multimesh_instance.multimesh):
		return
	var mm: MultiMesh = _multimesh_instance.multimesh
	var count: int = min(segment_count, mm.instance_count)

	var inv_xform: Transform3D = _safe_xform().affine_inverse()

	for i in range(count):
		if i >= constraints.size() or not constraints[i].is_active:
			# Hide broken link by scaling to 0
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			continue

		var p1 = inv_xform * particles[i].position
		var p2 = inv_xform * particles[i + 1].position
		var center = (p1 + p2) * 0.5
		var seg_dir = (p2 - p1).normalized()
		if seg_dir.length_squared() < 0.001:
			seg_dir = Vector3.UP

		var up = Vector3.UP
		if abs(seg_dir.dot(up)) > 0.95:
			up = Vector3.RIGHT

		var link_basis = Basis.looking_at(seg_dir, up)
		if chain_alternate_rotation and (i % 2 == 1):
			link_basis = link_basis.rotated(seg_dir, PI * 0.5)

		link_basis = link_basis.scaled(chain_link_scale)
		mm.set_instance_transform(i, Transform3D(link_basis, center))


func _render_debug_lines() -> void:
	if not is_instance_valid(_immediate_mesh_instance):
		return
	var imm: ImmediateMesh = _immediate_mesh_instance.mesh as ImmediateMesh
	if imm == null:
		return

	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)

	var inv_xform: Transform3D = _safe_xform().affine_inverse()

	for i in range(constraints.size()):
		if not constraints[i].is_active:
			continue
		var p1 = inv_xform * particles[i].position
		var p2 = inv_xform * particles[i + 1].position
		imm.surface_add_vertex(p1)
		imm.surface_add_vertex(p2)

	imm.surface_end()


# =============================================================================
# Public Gameplay API
# =============================================================================

func cut_at(segment_index: int) -> void:
	if segment_index >= 0 and segment_index < constraints.size():
		var c = constraints[segment_index]
		if c.is_active:
			c.is_active = false
			rope_snapped.emit(segment_index)
			_spawn_snap_fx((c.p1.position + c.p2.position) * 0.5)


func winch(delta_length: float) -> void:
	if constraints.is_empty():
		return
	var delta_per_seg: float = delta_length / float(constraints.size())
	for c in constraints:
		c.rest_length = clampf(c.rest_length + delta_per_seg, 0.05, 50.0)
	length = clampf(length + delta_length, 0.1, 500.0)


func _spawn_snap_fx(pos: Vector3) -> void:
	if not snap_particles_enabled or not is_inside_tree():
		return
	var p = CPUParticles3D.new()
	p.name = "SnapSparks"
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.5
	p.amount = 24
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.08
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, -9.8, 0)
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.color = Color(1.0, 0.75, 0.25)

	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	p.mesh = mesh

	var parent_node = get_parent() if get_parent() else self
	parent_node.add_child(p)
	p.global_position = pos

	get_tree().create_timer(0.7).timeout.connect(p.queue_free)


func apply_impulse_to_particle(particle_index: int, impulse: Vector3) -> void:
	if particle_index >= 0 and particle_index < particles.size():
		particles[particle_index].apply_impulse(impulse)


func apply_radial_impulse(epicenter: Vector3, max_radius: float, force: float) -> void:
	for p in particles:
		var dist: float = p.position.distance_to(epicenter)
		if dist < max_radius and dist > 0.001:
			var factor: float = 1.0 - (dist / max_radius)
			var dir: Vector3 = (p.position - epicenter).normalized()
			p.apply_impulse(dir * force * factor)


func get_particle_positions() -> PackedVector3Array:
	var result = PackedVector3Array()
	for p in particles:
		result.append(p.position)
	return result


func get_total_tension() -> float:
	var total: float = 0.0
	for c in constraints:
		if c.is_active:
			total += c.current_tension
	return total


func reset_rope() -> void:
	_rebuild_rope()

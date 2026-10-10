#=============================================================================
# VerletRope2D - Interactive 2D Verlet Rope, Cable, Chain & Whip for Godot 4.x
# Features: Continuous 2D world collision, bidirectional RigidBody2D coupling,
# tension stress visualization, winching, snapping, and procedural drawing.
#=============================================================================
@tool
class_name VerletRope2D
extends Node2D

signal rope_snapped(segment_index: int)
signal particle_collided(index: int, point: Vector2, normal: Vector2)

enum RenderMode2D {
	SMOOTH_LINE,
	CHAIN_LINKS,
	DEBUG_POINTS
}

# --- Rope Geometry ---
@export_group("Geometry")
@export_range(10.0, 3000.0, 5.0) var length: float = 200.0:
	set(val):
		length = maxf(val, 5.0)
		if Engine.is_editor_hint():
			_rebuild_rope()

@export_range(2, 80, 1) var segment_count: int = 14:
	set(val):
		segment_count = clampi(val, 2, 100)
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
		_cache_anchors()
		_update_pins()

@export var start_pin_offset: Vector2 = Vector2.ZERO:
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
		_cache_anchors()
		_update_pins()

@export var end_pin_offset: Vector2 = Vector2.ZERO:
	set(val):
		end_pin_offset = val
		_update_pins()

@export var apply_forces_to_rigidbodies: bool = true
@export_range(0.1, 10.0, 0.1) var rigidbody_force_multiplier: float = 1.0

# --- Physics Dynamics ---
@export_group("Dynamics")
@export var gravity: Vector2 = Vector2(0.0, 980.0)
@export_range(0.8, 0.999, 0.001) var damping: float = 0.985
@export_range(0.1, 1.0, 0.01) var stiffness: float = 0.95
@export_range(1, 30, 1) var solver_iterations: int = 12
@export_range(0.01, 10.0, 0.05) var particle_mass: float = 0.2

# --- Snapping & Breaking ---
@export_group("Breaking")
@export var breakable: bool = false
@export_range(10.0, 5000.0, 10.0) var break_tension_threshold: float = 600.0
@export var snap_particles_enabled: bool = true

# --- Collisions ---
@export_group("Collisions")
@export var collision_enabled: bool = true
@export_range(1.0, 50.0, 0.5) var collision_radius: float = 4.0
@export_flags_2d_physics var collision_mask: int = 1
@export_range(0.0, 1.0, 0.05) var surface_friction: float = 0.3
@export_range(0.0, 1.0, 0.05) var surface_bounce: float = 0.1

# --- Wind & Environment ---
@export_group("Wind")
@export var wind_vector: Vector2 = Vector2.ZERO
@export_range(0.0, 2.0, 0.05) var wind_turbulence: float = 0.3

# --- Visuals & Rendering ---
@export_group("Rendering")
@export var render_mode: RenderMode2D = RenderMode2D.SMOOTH_LINE:
	set(val):
		render_mode = val
		queue_redraw()

@export_range(1.0, 50.0, 0.5) var rope_width: float = 5.0:
	set(val):
		rope_width = maxf(val, 0.5)
		queue_redraw()

@export var rope_color: Color = Color(0.82, 0.65, 0.45): # Hemp rope color
	set(val):
		rope_color = val
		queue_redraw()

@export var rope_texture: Texture2D:
	set(val):
		rope_texture = val
		queue_redraw()

@export var visualize_tension: bool = false:
	set(val):
		visualize_tension = val
		queue_redraw()

# Internal State
var particles: Array[VerletParticle2D] = []
var constraints: Array[VerletConstraint2D] = []

var _start_node_cache: Node2D = null
var _end_node_cache: Node2D = null
var _start_rigidbody: RigidBody2D = null
var _end_rigidbody: RigidBody2D = null

var _time_acc: float = 0.0


func _ready() -> void:
	_cache_anchors()
	_rebuild_rope()


func _safe_xform() -> Transform2D:
	return global_transform if is_inside_tree() else transform


func _safe_pos() -> Vector2:
	return global_position if is_inside_tree() else position


func _cache_anchors() -> void:
	_start_node_cache = get_node_or_null(attach_start_to) as Node2D if not attach_start_to.is_empty() else null
	_end_node_cache = get_node_or_null(attach_end_to) as Node2D if not attach_end_to.is_empty() else null
	_start_rigidbody = _start_node_cache as RigidBody2D
	_end_rigidbody = _end_node_cache as RigidBody2D


func _rebuild_rope() -> void:
	particles.clear()
	constraints.clear()

	var start_pos: Vector2 = _safe_pos()
	if is_instance_valid(_start_node_cache):
		var target_xform = _start_node_cache.global_transform if _start_node_cache.is_inside_tree() else _start_node_cache.transform
		start_pos = target_xform * start_pin_offset

	var end_pos: Vector2 = start_pos + Vector2(0.0, length)
	if is_instance_valid(_end_node_cache):
		var target_xform = _end_node_cache.global_transform if _end_node_cache.is_inside_tree() else _end_node_cache.transform
		end_pos = target_xform * end_pin_offset
	elif not is_instance_valid(_start_node_cache):
		end_pos = _safe_pos() + Vector2(0.0, length)

	var straight_dist: float = start_pos.distance_to(end_pos)
	var active_length: float = length
	if auto_length_from_targets and straight_dist > 0.001:
		active_length = straight_dist * slack_ratio
	else:
		active_length = maxf(length * slack_ratio, straight_dist)

	var num_particles: int = segment_count + 1
	var rest_segment_len: float = active_length / float(segment_count)

	# Generate particles along curve
	for i in range(num_particles):
		var t: float = float(i) / float(segment_count)
		var linear_pos: Vector2 = start_pos.lerp(end_pos, t)
		var sag_factor: float = sin(t * PI) * (active_length - straight_dist) * 0.5
		var p_pos: Vector2 = linear_pos + Vector2(0.0, sag_factor)

		var p = VerletParticle2D.new(p_pos, particle_mass, collision_radius)
		particles.append(p)

	# Setup constraints
	for i in range(segment_count):
		var c = VerletConstraint2D.new(particles[i], particles[i + 1], rest_segment_len, stiffness)
		c.can_break = breakable
		c.break_tension_limit = break_tension_threshold
		constraints.append(c)

	_update_pins()
	queue_redraw()


func _update_pins() -> void:
	if particles.is_empty():
		return

	# Start pin
	if pin_start:
		if is_instance_valid(_start_node_cache):
			particles[0].pin_to_node(_start_node_cache, start_pin_offset)
		else:
			particles[0].pin_to_world(_safe_pos() + start_pin_offset)
	else:
		particles[0].unpin()

	# End pin
	var last_idx: int = particles.size() - 1
	if pin_end:
		if is_instance_valid(_end_node_cache):
			particles[last_idx].pin_to_node(_end_node_cache, end_pin_offset)
		else:
			var default_end = _safe_pos() + Vector2(0.0, length) + end_pin_offset
			particles[last_idx].pin_to_world(default_end)
	else:
		particles[last_idx].unpin()


func _physics_process(delta: float) -> void:
	if particles.is_empty():
		return

	_time_acc += delta

	if Engine.is_editor_hint():
		_cache_anchors()
		_update_pins()

	# 1. Sync pinned particles
	for p in particles:
		if p.is_pinned:
			p.sync_pin()

	# 2. Accumulate Gravity + Wind
	var cur_wind: Vector2 = wind_vector
	if wind_vector.length_squared() > 0.001 and wind_turbulence > 0.0:
		var noise = sin(_time_acc * 3.5 + _safe_pos().x * 0.05) * wind_turbulence
		cur_wind += Vector2(noise, noise * 0.5) * wind_vector.length()

	var total_force: Vector2 = (gravity * particle_mass) + cur_wind
	for p in particles:
		if not p.is_pinned:
			p.apply_force(total_force)

	# 3. Integrate
	for p in particles:
		p.integrate(delta, damping)

	# 4. Solve constraints
	for iter in range(solver_iterations):
		for c_idx in range(constraints.size()):
			var c = constraints[c_idx]
			if c.is_active:
				var snapped: bool = c.solve()
				if snapped:
					rope_snapped.emit(c_idx)
					_spawn_snap_fx((c.p1.position + c.p2.position) * 0.5)

	# 5. 2D World Collisions
	if collision_enabled and is_inside_tree():
		var space_state = get_world_2d().direct_space_state
		if space_state:
			_solve_collisions_2d(space_state)

	# 6. Bidirectional RigidBody2D Coupling
	if apply_forces_to_rigidbodies:
		_apply_rigidbody_coupling_2d()

	queue_redraw()


func _solve_collisions_2d(space_state: PhysicsDirectSpaceState2D) -> void:
	for idx in range(particles.size()):
		var p = particles[idx]
		if p.is_pinned or not p.active:
			continue

		var move_delta: Vector2 = p.position - p.prev_position
		var move_dist: float = move_delta.length()
		var cast_target: Vector2 = p.position
		if move_dist > 0.001:
			cast_target += (move_delta / move_dist) * collision_radius
		else:
			cast_target += Vector2.DOWN * collision_radius

		var excludes: Array[RID] = []
		if is_instance_valid(_start_rigidbody):
			excludes.append(_start_rigidbody.get_rid())
		if is_instance_valid(_end_rigidbody):
			excludes.append(_end_rigidbody.get_rid())

		var query = PhysicsRayQueryParameters2D.create(p.prev_position, cast_target, collision_mask, excludes)
		var hit = space_state.intersect_ray(query)

		if not hit.is_empty():
			var hit_pos: Vector2 = hit.position
			var hit_norm: Vector2 = hit.normal

			p.position = hit_pos + (hit_norm * (collision_radius + 0.1))

			var vel: Vector2 = p.position - p.prev_position
			var normal_vel: Vector2 = hit_norm * vel.dot(hit_norm)
			var tangent_vel: Vector2 = vel - normal_vel

			var new_vel: Vector2 = (tangent_vel * (1.0 - surface_friction)) - (normal_vel * surface_bounce)
			p.prev_position = p.position - new_vel

			particle_collided.emit(idx, hit_pos, hit_norm)


func _apply_rigidbody_coupling_2d() -> void:
	if particles.size() < 2:
		return

	if is_instance_valid(_start_rigidbody) and pin_start:
		var p0 = particles[0]
		var p1 = particles[1]
		var tension_dir: Vector2 = (p1.position - p0.position).normalized()
		var tension_force: Vector2 = tension_dir * constraints[0].current_tension * rigidbody_force_multiplier
		_start_rigidbody.apply_force(tension_force, p0.position - _start_rigidbody.global_position)

	var last_idx: int = particles.size() - 1
	if is_instance_valid(_end_rigidbody) and pin_end:
		var p_end = particles[last_idx]
		var p_prev = particles[last_idx - 1]
		var tension_dir: Vector2 = (p_prev.position - p_end.position).normalized()
		var tension_force: Vector2 = tension_dir * constraints[constraints.size() - 1].current_tension * rigidbody_force_multiplier
		_end_rigidbody.apply_force(tension_force, p_end.position - _end_rigidbody.global_position)


func _draw() -> void:
	if particles.size() < 2:
		return

	var inv_xform: Transform2D = _safe_xform().affine_inverse()

	match render_mode:
		RenderMode2D.SMOOTH_LINE:
			_draw_smooth_line(inv_xform)
		RenderMode2D.CHAIN_LINKS:
			_draw_chain_links(inv_xform)
		RenderMode2D.DEBUG_POINTS:
			_draw_debug_points(inv_xform)


func _draw_smooth_line(inv_xform: Transform2D) -> void:
	for i in range(constraints.size()):
		var c = constraints[i]
		if not c.is_active:
			continue

		var p1 = inv_xform * c.p1.position
		var p2 = inv_xform * c.p2.position

		var col = rope_color
		if visualize_tension:
			var t_ratio = clampf(c.current_tension / maxf(break_tension_threshold, 1.0), 0.0, 1.0)
			if t_ratio > 0.5:
				col = Color(1.0, 0.85, 0.1).lerp(Color(1.0, 0.15, 0.1), (t_ratio - 0.5) * 2.0)
			else:
				col = Color(0.15, 0.9, 0.45).lerp(Color(1.0, 0.85, 0.1), t_ratio * 2.0)

		draw_line(p1, p2, col, rope_width, true)


func _draw_chain_links(inv_xform: Transform2D) -> void:
	for i in range(constraints.size()):
		var c = constraints[i]
		if not c.is_active:
			continue

		var p1 = inv_xform * c.p1.position
		var p2 = inv_xform * c.p2.position
		var mid = (p1 + p2) * 0.5
		var seg_dir = (p2 - p1).normalized()
		var seg_len = p1.distance_to(p2)

		var perp = Vector2(-seg_dir.y, seg_dir.x) * (rope_width * 0.5)
		var col = Color(0.75, 0.75, 0.8) if i % 2 == 0 else Color(0.55, 0.55, 0.6)

		# Draw pill capsule
		draw_line(mid - seg_dir * (seg_len * 0.4), mid + seg_dir * (seg_len * 0.4), col, rope_width, true)
		draw_circle(mid, rope_width * 0.25, Color.BLACK)


func _draw_debug_points(inv_xform: Transform2D) -> void:
	for p in particles:
		var local_p = inv_xform * p.position
		var col = Color.RED if p.is_pinned else Color.GREEN
		draw_circle(local_p, collision_radius, col)


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
			queue_redraw()


func winch(delta_length: float) -> void:
	if constraints.is_empty():
		return
	var delta_per_seg = delta_length / float(constraints.size())
	for c in constraints:
		c.rest_length = clampf(c.rest_length + delta_per_seg, 2.0, 1000.0)
	length = clampf(length + delta_length, 5.0, 10000.0)


func _spawn_snap_fx(pos: Vector2) -> void:
	if not snap_particles_enabled or not is_inside_tree():
		return
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.5
	p.amount = 20
	p.spread = 180.0
	p.gravity = Vector2(0, 980)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.color = Color(1.0, 0.8, 0.3)

	var parent_node = get_parent() if get_parent() else self
	parent_node.add_child(p)
	p.global_position = pos

	get_tree().create_timer(0.7).timeout.connect(p.queue_free)


func apply_impulse_to_particle(particle_index: int, impulse: Vector2) -> void:
	if particle_index >= 0 and particle_index < particles.size():
		particles[particle_index].apply_impulse(impulse)


func apply_radial_impulse(epicenter: Vector2, max_radius: float, force: float) -> void:
	for p in particles:
		var dist = p.position.distance_to(epicenter)
		if dist < max_radius and dist > 0.001:
			var factor = 1.0 - (dist / max_radius)
			var dir = (p.position - epicenter).normalized()
			p.apply_impulse(dir * force * factor)


func get_particle_positions() -> PackedVector2Array:
	var result = PackedVector2Array()
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

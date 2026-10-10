#=============================================================================
# VerletRagdoll2D - Articulated 2D Character Ragdoll Physics
# Part of VerletDynamics for Godot 4.x
# Features: 14-particle humanoid skeleton, volumetric cross-bracing,
# continuous 2D collisions, procedural capsule limb rendering, and rope coupling.
#=============================================================================
@tool
class_name VerletRagdoll2D
extends Node2D

signal ragdoll_collided(joint_name: String, point: Vector2, normal: Vector2)

# --- Geometry & Proportions ---
@export_group("Ragdoll Proportions")
@export_range(0.3, 3.0, 0.05) var character_scale: float = 1.0:
	set(val):
		character_scale = clampf(val, 0.2, 5.0)
		if Engine.is_editor_hint():
			_rebuild_ragdoll()
			queue_redraw()

@export_range(4.0, 24.0, 1.0) var limb_thickness: float = 8.0:
	set(val):
		limb_thickness = val
		queue_redraw()

@export_range(6.0, 30.0, 1.0) var head_radius: float = 14.0:
	set(val):
		head_radius = val
		queue_redraw()

# --- Physics Dynamics ---
@export_group("Dynamics")
@export var gravity: Vector2 = Vector2(0.0, 980.0)
@export_range(0.8, 0.999, 0.001) var damping: float = 0.985
@export_range(0.5, 1.0, 0.01) var skeleton_stiffness: float = 0.98
@export_range(1, 20, 1) var solver_iterations: int = 8
@export_range(0.05, 10.0, 0.05) var total_mass: float = 2.0

# --- Collisions ---
@export_group("Collisions")
@export var collision_enabled: bool = true
@export_flags_2d_physics var collision_mask: int = 1
@export_range(0.0, 1.0, 0.05) var surface_friction: float = 0.45
@export_range(0.0, 1.0, 0.05) var surface_bounce: float = 0.15

# --- Visual Styling ---
@export_group("Styling")
@export var skin_color: Color = Color(0.96, 0.80, 0.70)
@export var shirt_color: Color = Color(0.22, 0.52, 0.88)
@export var pants_color: Color = Color(0.18, 0.22, 0.32)
@export var shoe_color: Color = Color(0.12, 0.12, 0.14)
@export var outline_color: Color = Color(0.08, 0.08, 0.10)
@export var draw_face: bool = true

# --- Skeletal Particles ---
var particles: Array[VerletParticle2D] = []
var constraints: Array[VerletConstraint2D] = []
var joint_map: Dictionary = {} # String name -> VerletParticle2D

# Joint particle indices
var p_head: VerletParticle2D
var p_neck: VerletParticle2D
var p_torso: VerletParticle2D
var p_pelvis: VerletParticle2D
var p_l_shoulder: VerletParticle2D
var p_l_elbow: VerletParticle2D
var p_l_hand: VerletParticle2D
var p_r_shoulder: VerletParticle2D
var p_r_elbow: VerletParticle2D
var p_r_hand: VerletParticle2D
var p_l_hip: VerletParticle2D
var p_l_knee: VerletParticle2D
var p_l_foot: VerletParticle2D
var p_r_hip: VerletParticle2D
var p_r_knee: VerletParticle2D
var p_r_foot: VerletParticle2D


func _ready() -> void:
	_rebuild_ragdoll()


func _safe_pos() -> Vector2:
	return global_position if is_inside_tree() else position


func _rebuild_ragdoll() -> void:
	particles.clear()
	constraints.clear()
	joint_map.clear()

	var s = character_scale
	var origin = _safe_pos()

	# Create particles with anthropometric local offsets
	var particle_mass = total_mass / 16.0

	p_head = _create_joint("head", origin + Vector2(0, -48 * s), particle_mass * 1.5, head_radius * s)
	p_neck = _create_joint("neck", origin + Vector2(0, -32 * s), particle_mass, 6.0 * s)
	p_torso = _create_joint("torso", origin + Vector2(0, -14 * s), particle_mass * 2.0, 10.0 * s)
	p_pelvis = _create_joint("pelvis", origin + Vector2(0, 8 * s), particle_mass * 2.0, 10.0 * s)

	# Left Arm
	p_l_shoulder = _create_joint("left_shoulder", origin + Vector2(-16 * s, -30 * s), particle_mass, 5.0 * s)
	p_l_elbow = _create_joint("left_elbow", origin + Vector2(-30 * s, -14 * s), particle_mass, 4.5 * s)
	p_l_hand = _create_joint("left_hand", origin + Vector2(-42 * s, 0 * s), particle_mass * 0.8, 5.0 * s)

	# Right Arm
	p_r_shoulder = _create_joint("right_shoulder", origin + Vector2(16 * s, -30 * s), particle_mass, 5.0 * s)
	p_r_elbow = _create_joint("right_elbow", origin + Vector2(30 * s, -14 * s), particle_mass, 4.5 * s)
	p_r_hand = _create_joint("right_hand", origin + Vector2(42 * s, 0 * s), particle_mass * 0.8, 5.0 * s)

	# Left Leg
	p_l_hip = _create_joint("left_hip", origin + Vector2(-12 * s, 12 * s), particle_mass, 6.0 * s)
	p_l_knee = _create_joint("left_knee", origin + Vector2(-14 * s, 36 * s), particle_mass, 5.5 * s)
	p_l_foot = _create_joint("left_foot", origin + Vector2(-16 * s, 62 * s), particle_mass * 0.8, 6.0 * s)

	# Right Leg
	p_r_hip = _create_joint("right_hip", origin + Vector2(12 * s, 12 * s), particle_mass, 6.0 * s)
	p_r_knee = _create_joint("right_knee", origin + Vector2(14 * s, 36 * s), particle_mass, 5.5 * s)
	p_r_foot = _create_joint("right_foot", origin + Vector2(16 * s, 62 * s), particle_mass * 0.8, 6.0 * s)

	# --- 1. Primary Bone Distance Constraints ---
	_link(p_head, p_neck, skeleton_stiffness)
	_link(p_neck, p_torso, skeleton_stiffness)
	_link(p_torso, p_pelvis, skeleton_stiffness)

	# Shoulders / Collarbone
	_link(p_neck, p_l_shoulder, skeleton_stiffness)
	_link(p_neck, p_r_shoulder, skeleton_stiffness)
	_link(p_l_shoulder, p_torso, skeleton_stiffness)
	_link(p_r_shoulder, p_torso, skeleton_stiffness)

	# Left Arm
	_link(p_l_shoulder, p_l_elbow, skeleton_stiffness)
	_link(p_l_elbow, p_l_hand, skeleton_stiffness)

	# Right Arm
	_link(p_r_shoulder, p_r_elbow, skeleton_stiffness)
	_link(p_r_elbow, p_r_hand, skeleton_stiffness)

	# Pelvis / Hips
	_link(p_pelvis, p_l_hip, skeleton_stiffness)
	_link(p_pelvis, p_r_hip, skeleton_stiffness)
	_link(p_l_hip, p_r_hip, skeleton_stiffness)

	# Left Leg
	_link(p_l_hip, p_l_knee, skeleton_stiffness)
	_link(p_l_knee, p_l_foot, skeleton_stiffness)

	# Right Leg
	_link(p_r_hip, p_r_knee, skeleton_stiffness)
	_link(p_r_knee, p_r_foot, skeleton_stiffness)

	# --- 2. Structural Cross-Bracing (Torso & Head Anti-Collapse) ---
	_link(p_head, p_torso, skeleton_stiffness * 0.9)
	_link(p_l_shoulder, p_r_shoulder, skeleton_stiffness)
	_link(p_l_shoulder, p_pelvis, skeleton_stiffness * 0.85)
	_link(p_r_shoulder, p_pelvis, skeleton_stiffness * 0.85)
	_link(p_neck, p_pelvis, skeleton_stiffness * 0.9)
	_link(p_l_shoulder, p_r_hip, skeleton_stiffness * 0.8)
	_link(p_r_shoulder, p_l_hip, skeleton_stiffness * 0.8)

	# --- 3. Joint Limiter Cross-Struts (Anti-Inversion for Elbows & Knees) ---
	# Shoulder-to-Hand and Hip-to-Foot braces limit extreme hyper-extension
	_link(p_l_shoulder, p_l_hand, skeleton_stiffness * 0.4)
	_link(p_r_shoulder, p_r_hand, skeleton_stiffness * 0.4)
	_link(p_l_hip, p_l_foot, skeleton_stiffness * 0.4)
	_link(p_r_hip, p_r_foot, skeleton_stiffness * 0.4)


func _create_joint(p_name: String, p_world_pos: Vector2, p_mass: float, p_radius: float) -> VerletParticle2D:
	var p = VerletParticle2D.new(p_world_pos, p_mass, p_radius)
	particles.append(p)
	joint_map[p_name] = p
	return p


func _link(a: VerletParticle2D, b: VerletParticle2D, stiffness_val: float) -> VerletConstraint2D:
	var c = VerletConstraint2D.new(a, b, -1.0, stiffness_val)
	constraints.append(c)
	return c


func _physics_process(delta: float) -> void:
	if particles.is_empty():
		return

	# 1. Sync pinned particles
	for p in particles:
		if p.is_pinned:
			p.sync_pin()

	# 2. Accumulate Gravity
	var gravity_acc = gravity
	for p in particles:
		if not p.is_pinned:
			p.apply_force(gravity_acc * p.mass)

	# 3. Verlet Integration
	for p in particles:
		p.integrate(delta, damping)

	# 4. Constraint Solving
	for iter in range(solver_iterations):
		for c in constraints:
			c.solve()

	# 5. Continuous 2D Collisions
	if collision_enabled and is_inside_tree():
		var space_state = get_world_2d().direct_space_state
		if space_state:
			_solve_ragdoll_collisions(space_state)

	queue_redraw()


func _solve_ragdoll_collisions(space_state: PhysicsDirectSpaceState2D) -> void:
	for joint_name in joint_map:
		var p: VerletParticle2D = joint_map[joint_name]
		if p.is_pinned or not p.active:
			continue

		var move_delta: Vector2 = p.position - p.prev_position
		var move_dist: float = move_delta.length()
		var cast_target: Vector2 = p.position
		if move_dist > 0.0001:
			cast_target += (move_delta / move_dist) * p.radius
		else:
			cast_target += Vector2.DOWN * p.radius

		var query = PhysicsRayQueryParameters2D.create(p.prev_position, cast_target, collision_mask)
		var hit = space_state.intersect_ray(query)

		if not hit.is_empty():
			var hit_pos: Vector2 = hit.position
			var hit_norm: Vector2 = hit.normal

			# Push particle outside surface
			p.position = hit_pos + (hit_norm * (p.radius + 0.5))

			# Apply surface friction and bounce
			var vel: Vector2 = p.position - p.prev_position
			var normal_vel: Vector2 = hit_norm * vel.dot(hit_norm)
			var tangent_vel: Vector2 = vel - normal_vel

			var new_vel: Vector2 = (tangent_vel * (1.0 - surface_friction)) - (normal_vel * surface_bounce)
			p.prev_position = p.position - new_vel

			ragdoll_collided.emit(joint_name, hit_pos, hit_norm)


# =============================================================================
# Procedural 2D Character Rendering
# =============================================================================

func _draw() -> void:
	if particles.is_empty():
		return

	var inv_xform = global_transform.affine_inverse() if is_inside_tree() else Transform2D.IDENTITY

	# Helper to get local coordinate of joint
	var to_loc = func(p: VerletParticle2D) -> Vector2:
		return inv_xform * p.position

	var s = character_scale
	var thick = limb_thickness * s

	# 1. Legs (Behind torso)
	# Left Leg
	_draw_capsule_bone(to_loc.call(p_l_hip), to_loc.call(p_l_knee), pants_color, thick)
	_draw_capsule_bone(to_loc.call(p_l_knee), to_loc.call(p_l_foot), pants_color * 0.9, thick * 0.85)
	draw_circle(to_loc.call(p_l_foot), thick * 0.65, shoe_color)

	# Right Leg
	_draw_capsule_bone(to_loc.call(p_r_hip), to_loc.call(p_r_knee), pants_color, thick)
	_draw_capsule_bone(to_loc.call(p_r_knee), to_loc.call(p_r_foot), pants_color * 0.9, thick * 0.85)
	draw_circle(to_loc.call(p_r_foot), thick * 0.65, shoe_color)

	# 2. Pelvis / Hips
	_draw_capsule_bone(to_loc.call(p_l_hip), to_loc.call(p_r_hip), pants_color, thick * 1.1)

	# 3. Torso / Shirt
	_draw_capsule_bone(to_loc.call(p_torso), to_loc.call(p_pelvis), shirt_color * 0.9, thick * 1.4)
	_draw_capsule_bone(to_loc.call(p_neck), to_loc.call(p_torso), shirt_color, thick * 1.5)
	_draw_capsule_bone(to_loc.call(p_l_shoulder), to_loc.call(p_r_shoulder), shirt_color, thick * 1.2)

	# 4. Arms
	# Left Arm
	_draw_capsule_bone(to_loc.call(p_l_shoulder), to_loc.call(p_l_elbow), shirt_color * 0.95, thick * 0.9)
	_draw_capsule_bone(to_loc.call(p_l_elbow), to_loc.call(p_l_hand), skin_color, thick * 0.75)
	draw_circle(to_loc.call(p_l_hand), thick * 0.55, skin_color)

	# Right Arm
	_draw_capsule_bone(to_loc.call(p_r_shoulder), to_loc.call(p_r_elbow), shirt_color * 0.95, thick * 0.9)
	_draw_capsule_bone(to_loc.call(p_r_elbow), to_loc.call(p_r_hand), skin_color, thick * 0.75)
	draw_circle(to_loc.call(p_r_hand), thick * 0.55, skin_color)

	# 5. Neck & Head
	var head_loc = to_loc.call(p_head)
	var neck_loc = to_loc.call(p_neck)
	_draw_capsule_bone(neck_loc, head_loc, skin_color, thick * 0.8)

	var h_rad = head_radius * s
	# Head outline
	draw_circle(head_loc, h_rad + 1.5, outline_color)
	# Head face
	draw_circle(head_loc, h_rad, skin_color)

	# Stylized Eyes / Visor
	if draw_face:
		var head_dir = (head_loc - neck_loc).normalized()
		var perp = Vector2(-head_dir.y, head_dir.x)
		var eye_center = head_loc + head_dir * (h_rad * 0.15)
		var eye_l = eye_center - perp * (h_rad * 0.35)
		var eye_r = eye_center + perp * (h_rad * 0.35)
		draw_circle(eye_l, h_rad * 0.18, outline_color)
		draw_circle(eye_r, h_rad * 0.18, outline_color)
		# Specular eye gleam
		draw_circle(eye_l + Vector2(-1, -1), h_rad * 0.08, Color.WHITE)
		draw_circle(eye_r + Vector2(-1, -1), h_rad * 0.08, Color.WHITE)


func _draw_capsule_bone(p1: Vector2, p2: Vector2, col: Color, thick: float) -> void:
	# Subtle outline
	draw_line(p1, p2, outline_color, thick + 2.0, true)
	draw_circle(p1, (thick + 2.0) * 0.5, outline_color)
	draw_circle(p2, (thick + 2.0) * 0.5, outline_color)

	# Filled bone
	draw_line(p1, p2, col, thick, true)
	draw_circle(p1, thick * 0.5, col)
	draw_circle(p2, thick * 0.5, col)


# =============================================================================
# Public Gameplay API
# =============================================================================

func apply_impulse(impulse: Vector2) -> void:
	for p in particles:
		if not p.is_pinned:
			p.apply_impulse(impulse)


func apply_impulse_to_joint(joint_name: String, impulse: Vector2) -> void:
	if joint_map.has(joint_name):
		var p: VerletParticle2D = joint_map[joint_name]
		if not p.is_pinned:
			p.apply_impulse(impulse)


func pin_joint_to_world(joint_name: String, world_pos: Vector2) -> void:
	if joint_map.has(joint_name):
		joint_map[joint_name].pin_to_world(world_pos)


func pin_joint_to_node(joint_name: String, target_node: Node2D, offset: Vector2 = Vector2.ZERO) -> void:
	if joint_map.has(joint_name):
		joint_map[joint_name].pin_to_node(target_node, offset)


func unpin_joint(joint_name: String) -> void:
	if joint_map.has(joint_name):
		joint_map[joint_name].unpin()


func get_joint_position(joint_name: String) -> Vector2:
	if joint_map.has(joint_name):
		return joint_map[joint_name].position
	return global_position


func get_closest_particle(world_pos: Vector2, max_dist: float = 60.0) -> VerletParticle2D:
	var closest: VerletParticle2D = null
	var min_d: float = max_dist
	for p in particles:
		var d = p.position.distance_to(world_pos)
		if d < min_d:
			min_d = d
			closest = p
	return closest

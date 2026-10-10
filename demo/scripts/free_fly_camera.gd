#=============================================================================
# FreeFlyCamera - 3D Camera with Physics Particle Interaction & Grapple Gun
# Features: Real-time particle grabber, laser cutting beam, grappling hook
# with winch reeling, and procedural audio feedback.
#=============================================================================
class_name FreeFlyCamera
extends Camera3D

const VerletAudioSynth = preload("verlet_audio_synth.gd")

@export var move_speed: float = 12.0
@export var boost_speed: float = 28.0
@export var mouse_sensitivity: float = 0.003

var _grabbed_particle: VerletParticle3D = null
var _grabbed_distance: float = 5.0
var _yaw: float = 0.0
var _pitch: float = -0.3

var _grapple_rope: VerletRope3D = null
var _grapple_anchor_pos: Vector3 = Vector3.ZERO

signal interaction_hint_updated(text: String)


func _ready() -> void:
	var rot = rotation
	_yaw = rot.y
	_pitch = rot.x


func _input(event: InputEvent) -> void:
	# Camera Look (Right Mouse Button Drag)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.4, 1.4)
		rotation = Vector3(_pitch, _yaw, 0.0)

	# Left Click: Grab Particle
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_grab_particle(event.position)
			else:
				_release_grabbed_particle()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_try_cut_under_cursor(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and is_instance_valid(_grapple_rope):
			# Winch in (pull)
			_grapple_rope.winch(-0.4)
			var dir = (_grapple_anchor_pos - global_position).normalized()
			global_position += dir * 0.8
			interaction_hint_updated.emit("Winching IN (Rope Length: %0.1f m)" % _grapple_rope.length)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and is_instance_valid(_grapple_rope):
			# Winch out (slacken)
			_grapple_rope.winch(+0.4)
			interaction_hint_updated.emit("Winching OUT (Rope Length: %0.1f m)" % _grapple_rope.length)

	# Keyboard Shortcuts
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_toggle_grappling_hook()
		elif event.keycode == KEY_C:
			_try_cut_under_cursor(get_viewport().get_mouse_position())


func _process(delta: float) -> void:
	# WASD Navigation
	var input_vec = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_vec += -transform.basis.z
	if Input.is_key_pressed(KEY_S): input_vec += transform.basis.z
	if Input.is_key_pressed(KEY_A): input_vec += -transform.basis.x
	if Input.is_key_pressed(KEY_D): input_vec += transform.basis.x
	if Input.is_key_pressed(KEY_E): input_vec += Vector3.UP
	if Input.is_key_pressed(KEY_Q): input_vec += Vector3.DOWN

	var speed = boost_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	if input_vec.length_squared() > 0.01:
		global_position += input_vec.normalized() * speed * delta

	# Pull particle with cursor
	if _grabbed_particle != null:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = project_ray_origin(mouse_pos)
		var ray_dir = project_ray_normal(mouse_pos)
		var target_pos = ray_origin + (ray_dir * _grabbed_distance)

		var pull_delta = target_pos - _grabbed_particle.position
		_grabbed_particle.position = target_pos
		_grabbed_particle.prev_position = target_pos - (pull_delta * 0.2)

	# Keep Grappling Hook attached to camera
	if is_instance_valid(_grapple_rope):
		if not _grapple_rope.particles.is_empty():
			var hook_hand_pos = global_position + (-transform.basis.y * 0.3) + (transform.basis.x * 0.2)
			_grapple_rope.particles[0].pin_to_world(hook_hand_pos)

			# Constrain camera to rope distance if taut
			var dist = global_position.distance_to(_grapple_anchor_pos)
			if dist > _grapple_rope.length:
				var pull_dir = (_grapple_anchor_pos - global_position).normalized()
				global_position = _grapple_anchor_pos - (pull_dir * _grapple_rope.length)


func _toggle_grappling_hook() -> void:
	if is_instance_valid(_grapple_rope):
		_grapple_rope.queue_free()
		_grapple_rope = null
		VerletAudioSynth.play_sound(get_tree(), "cut")
		interaction_hint_updated.emit("Grapple Disengaged")
		return

	# Fire grapple raycast into world
	var screen_center = get_viewport().size * 0.5
	var ray_origin = project_ray_origin(screen_center)
	var ray_dir = project_ray_normal(screen_center)

	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 50.0)
	var hit = space_state.intersect_ray(query)

	if not hit.is_empty():
		_grapple_anchor_pos = hit.position
		var start_pos = global_position + (-transform.basis.y * 0.3)
		var rope_len = maxf(start_pos.distance_to(_grapple_anchor_pos), 0.5)

		var rope = VerletRope3D.new()
		rope.name = "ActiveGrappleRope"
		rope.length = rope_len
		rope.segment_count = 14
		rope.rope_radius = 0.02
		rope.stiffness = 0.98
		rope.damping = 0.99
		rope.pin_start = true
		rope.pin_end = true
		rope.visualize_tension = true
		rope.add_to_group("verlet_physics")

		var rope_mat = StandardMaterial3D.new()
		rope_mat.vertex_color_use_as_albedo = true
		rope_mat.albedo_color = Color(0.9, 0.8, 0.3)
		rope.material = rope_mat

		get_tree().current_scene.add_child(rope)
		rope.global_position = start_pos
		rope._ready()

		if rope.particles.size() > 1:
			rope.particles[0].pin_to_world(start_pos)
			rope.particles[rope.particles.size() - 1].pin_to_world(_grapple_anchor_pos)

		_grapple_rope = rope
		VerletAudioSynth.play_sound(get_tree(), "grapple")
		interaction_hint_updated.emit("Grapple Lodged! [Scroll Up/Down: Winch | 'G': Detach]")
	else:
		interaction_hint_updated.emit("Grapple Missed (No surface in range)")


func _try_grab_particle(mouse_pos: Vector2) -> void:
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_dir = project_ray_normal(mouse_pos)

	var closest_p: VerletParticle3D = null
	var min_dist: float = 0.5

	var nodes = get_tree().get_nodes_in_group("verlet_physics")
	for node in nodes:
		if node is VerletRope3D:
			for p in node.particles:
				var to_p = p.position - ray_origin
				var proj = to_p.dot(ray_dir)
				if proj > 0.5:
					var closest_on_ray = ray_origin + (ray_dir * proj)
					var d = p.position.distance_to(closest_on_ray)
					if d < min_dist:
						min_dist = d
						closest_p = p
						_grabbed_distance = proj
		elif node is VerletCloth3D:
			var w = node.resolution.x
			var h = node.resolution.y
			for x in range(w):
				for y in range(h):
					var p = node.particles[x][y]
					var to_p = p.position - ray_origin
					var proj = to_p.dot(ray_dir)
					if proj > 0.5:
						var closest_on_ray = ray_origin + (ray_dir * proj)
						var d = p.position.distance_to(closest_on_ray)
						if d < min_dist:
							min_dist = d
							closest_p = p
							_grabbed_distance = proj
		elif node is VerletSoftVolume3D:
			for p in node.particles:
				var to_p = p.position - ray_origin
				var proj = to_p.dot(ray_dir)
				if proj > 0.5:
					var closest_on_ray = ray_origin + (ray_dir * proj)
					var d = p.position.distance_to(closest_on_ray)
					if d < min_dist:
						min_dist = d
						closest_p = p
						_grabbed_distance = proj

	if closest_p:
		_grabbed_particle = closest_p
		interaction_hint_updated.emit("Holding Particle (Drag to stretch)")


func _release_grabbed_particle() -> void:
	if _grabbed_particle:
		_grabbed_particle = null
		interaction_hint_updated.emit("Ready")


func _try_cut_under_cursor(mouse_pos: Vector2) -> void:
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_dir = project_ray_normal(mouse_pos)

	var nodes = get_tree().get_nodes_in_group("verlet_physics")
	for node in nodes:
		if node is VerletRope3D:
			for i in range(node.constraints.size()):
				var c = node.constraints[i]
				if not c.is_active: continue
				var mid = (c.p1.position + c.p2.position) * 0.5
				var to_mid = mid - ray_origin
				var proj = to_mid.dot(ray_dir)
				if proj > 0.5:
					var pt_on_ray = ray_origin + (ray_dir * proj)
					if mid.distance_to(pt_on_ray) < 0.4:
						node.cut_at(i)
						VerletAudioSynth.play_sound(get_tree(), "cut")
						interaction_hint_updated.emit("Sliced rope segment %d!" % i)
						return
		elif node is VerletCloth3D:
			var w = node.resolution.x
			var h = node.resolution.y
			for x in range(w):
				for y in range(h):
					var p = node.particles[x][y]
					var to_p = p.position - ray_origin
					var proj = to_p.dot(ray_dir)
					if proj > 0.5:
						var pt_on_ray = ray_origin + (ray_dir * proj)
						if p.position.distance_to(pt_on_ray) < 0.35:
							node.tear_at(x, y)
							VerletAudioSynth.play_sound(get_tree(), "cut")
							interaction_hint_updated.emit("Torn cloth at (%d, %d)!" % [x, y])
							return

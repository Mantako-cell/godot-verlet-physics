#=============================================================================
# FreeFlyCamera - 3D Camera with Physics Particle Interaction (Grab & Cut)
#=============================================================================
class_name FreeFlyCamera
extends Camera3D

@export var move_speed: float = 12.0
@export var boost_speed: float = 28.0
@export var mouse_sensitivity: float = 0.003

var _grabbed_particle: VerletParticle3D = null
var _grabbed_distance: float = 5.0
var _yaw: float = 0.0
var _pitch: float = -0.3

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


func _process(delta: float) -> void:
	# WASD Navigation
	var input_vec = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_vec += -transform.basis.z
	if Input.is_key_pressed(KEY_S): input_vec += transform.basis.z
	if Input.is_key_pressed(KEY_A): input_vec += -transform.basis.x
	if Input.is_key_pressed(KEY_D): input_vec += transform.basis.x
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE): input_vec += Vector3.UP
	if Input.is_key_pressed(KEY_Q): input_vec += Vector3.DOWN

	var speed = boost_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	if input_vec.length_squared() > 0.01:
		global_position += input_vec.normalized() * speed * delta

	# Update grabbed particle position to follow cursor in 3D
	if _grabbed_particle != null:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = project_ray_origin(mouse_pos)
		var ray_dir = project_ray_normal(mouse_pos)
		var target_pos = ray_origin + (ray_dir * _grabbed_distance)

		# Pull particle towards target
		var pull_delta = target_pos - _grabbed_particle.position
		_grabbed_particle.position = target_pos
		_grabbed_particle.prev_position = target_pos - (pull_delta * 0.2)


func _try_grab_particle(mouse_pos: Vector2) -> void:
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_dir = project_ray_normal(mouse_pos)

	var closest_p: VerletParticle3D = null
	var min_dist: float = 0.5 # grab radius threshold

	# Find closest particle to the ray in all Verlet objects
	var ropes = get_tree().get_nodes_in_group("verlet_physics")
	for node in ropes:
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

	if closest_p:
		_grabbed_particle = closest_p
		interaction_hint_updated.emit("Holding Particle (Drag with mouse)")


func _release_grabbed_particle() -> void:
	if _grabbed_particle:
		_grabbed_particle = null
		interaction_hint_updated.emit("Ready")


func _try_cut_under_cursor(mouse_pos: Vector2) -> void:
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_dir = project_ray_normal(mouse_pos)

	var ropes = get_tree().get_nodes_in_group("verlet_physics")
	for node in ropes:
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
						interaction_hint_updated.emit("Cut rope at segment %d!" % i)
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
						if p.position.distance_to(pt_on_ray) < 0.3:
							node.tear_at(x, y)
							interaction_hint_updated.emit("Torn cloth at (%d, %d)!" % [x, y])
							return

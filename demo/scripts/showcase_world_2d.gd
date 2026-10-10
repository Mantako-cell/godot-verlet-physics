#=============================================================================
# ShowcaseWorld2D - Controller for Verlet Dynamics 2D Interactive Playground
# Features: Real-time 2D mouse grabber, laser cutting, 2D ball spawner,
# wind toggle, tension heatmap, and scene switching between 2D and 3D.
#=============================================================================
extends Node2D

const VerletAudioSynth = preload("verlet_audio_synth.gd")
const VerletRagdoll2DClass = preload("res://addons/verlet_dynamics_3d/nodes/verlet_ragdoll_2d.gd")

@onready var fps_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/FPSLabel
@onready var particles_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/ParticlesLabel
@onready var constraints_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/ConstraintsLabel
@onready var status_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/StatusLabel

@onready var wind_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/WindButton
@onready var tension_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/TensionButton
@onready var spawn_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/SpawnButton
@onready var ragdoll_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/RagdollButton
@onready var reset_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/ResetButton
@onready var switch_3d_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/Switch3DButton

var _grabbed_particle: VerletParticle2D = null
var wind_active: bool = true
var tension_heatmap_active: bool = false
var _ball_count: int = 0
var _ragdoll_count: int = 0


func _ready() -> void:
	if is_instance_valid(wind_btn): wind_btn.pressed.connect(_toggle_wind)
	if is_instance_valid(tension_btn): tension_btn.pressed.connect(_toggle_tension_heatmap)
	if is_instance_valid(spawn_btn): spawn_btn.pressed.connect(_spawn_physics_ball_2d)
	if is_instance_valid(ragdoll_btn): ragdoll_btn.pressed.connect(_spawn_ragdoll_2d)
	if is_instance_valid(reset_btn): reset_btn.pressed.connect(_reset_scene)
	if is_instance_valid(switch_3d_btn): switch_3d_btn.pressed.connect(_switch_to_3d)

	_update_wind_state()



func _unhandled_input(event: InputEvent) -> void:
	# Left Click: Grab Particle
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_grab_particle_2d(event.position)
			else:
				_release_grabbed_particle_2d()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_try_cut_under_cursor_2d(event.position)

	# Keyboard
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_reset_scene()
			KEY_B, KEY_SPACE:
				_spawn_physics_ball_2d()
			KEY_Z:
				_spawn_ragdoll_2d()
			KEY_W:
				_toggle_wind()
			KEY_T:
				_toggle_tension_heatmap()
			KEY_C:
				_try_cut_under_cursor_2d(get_viewport().get_mouse_position())
			KEY_3:
				_switch_to_3d()


func _process(_delta: float) -> void:
	# Drag particle to follow cursor
	if _grabbed_particle != null:
		var mouse_pos = get_viewport().get_mouse_position()
		_grabbed_particle.position = mouse_pos
		_grabbed_particle.prev_position = mouse_pos

	# Telemetry
	if is_instance_valid(fps_label):
		fps_label.text = "FPS: %d (%0.2f ms)" % [Engine.get_frames_per_second(), 1000.0 / max(1.0, float(Engine.get_frames_per_second()))]

	var total_p: int = 0
	var total_c: int = 0
	for node in get_tree().get_nodes_in_group("verlet_physics_2d"):
		if node is VerletRope2D:
			total_p += node.particles.size()
			total_c += node.constraints.size()
		elif node is VerletCloth2D:
			total_p += node.resolution.x * node.resolution.y
			total_c += node.structural_constraints.size() + node.shear_constraints.size()
		elif node is VerletSoftBody2D:
			total_p += node.particles.size()
			total_c += node.constraints.size()
		elif node is VerletRagdoll2DClass:
			total_p += node.particles.size()
			total_c += node.constraints.size()

	if is_instance_valid(particles_label):
		particles_label.text = "Simulated 2D Particles: %d" % total_p
	if is_instance_valid(constraints_label):
		constraints_label.text = "Active 2D Constraints: %d" % total_c


func _try_grab_particle_2d(click_pos: Vector2) -> void:
	var closest_p: VerletParticle2D = null
	var min_dist: float = 30.0 # grab distance threshold in pixels

	for node in get_tree().get_nodes_in_group("verlet_physics_2d"):
		if node is VerletRope2D or node is VerletSoftBody2D or node is VerletRagdoll2DClass:
			for p in node.particles:
				var d = p.position.distance_to(click_pos)
				if d < min_dist:
					min_dist = d
					closest_p = p
		elif node is VerletCloth2D:
			var w = node.resolution.x
			var h = node.resolution.y
			for x in range(w):
				for y in range(h):
					var p = node.particles[x][y]
					var d = p.position.distance_to(click_pos)
					if d < min_dist:
						min_dist = d
						closest_p = p

	if closest_p:
		_grabbed_particle = closest_p
		_set_status("Holding 2D Particle (Drag with mouse)")



func _release_grabbed_particle_2d() -> void:
	if _grabbed_particle:
		_grabbed_particle = null
		_set_status("Ready")


func _try_cut_under_cursor_2d(cursor_pos: Vector2) -> void:
	for node in get_tree().get_nodes_in_group("verlet_physics_2d"):
		if node is VerletRope2D:
			for i in range(node.constraints.size()):
				var c = node.constraints[i]
				if not c.is_active: continue
				var mid = (c.p1.position + c.p2.position) * 0.5
				if mid.distance_to(cursor_pos) < 25.0:
					node.cut_at(i)
					VerletAudioSynth.play_sound(get_tree(), "cut")
					_set_status("Cut 2D rope at segment %d!" % i)
					return
		elif node is VerletCloth2D:
			var w = node.resolution.x
			var h = node.resolution.y
			for x in range(w):
				for y in range(h):
					var p = node.particles[x][y]
					if p.position.distance_to(cursor_pos) < 20.0:
						node.tear_at(x, y)
						VerletAudioSynth.play_sound(get_tree(), "cut")
						_set_status("Torn 2D banner at (%d, %d)!" % [x, y])
						return


func _toggle_wind() -> void:
	wind_active = not wind_active
	_update_wind_state()


func _update_wind_state() -> void:
	var wind_vec = Vector2(450.0, 50.0) if wind_active else Vector2.ZERO
	for node in get_tree().get_nodes_in_group("verlet_physics_2d"):
		if node is VerletCloth2D:
			node.wind_vector = wind_vec
		elif node is VerletRope2D:
			node.wind_vector = wind_vec * 0.4

	if is_instance_valid(wind_btn):
		wind_btn.text = "Wind: %s" % ("ON [450 px/s]" if wind_active else "OFF")


func _toggle_tension_heatmap() -> void:
	tension_heatmap_active = not tension_heatmap_active
	for node in get_tree().get_nodes_in_group("verlet_physics_2d"):
		if node is VerletRope2D:
			node.visualize_tension = tension_heatmap_active

	if is_instance_valid(tension_btn):
		tension_btn.text = "Tension: %s" % ("ON" if tension_heatmap_active else "OFF")
	_set_status("2D Tension Heatmap %s" % ("ENABLED" if tension_heatmap_active else "DISABLED"))


func _spawn_physics_ball_2d() -> void:
	_ball_count += 1
	var body = RigidBody2D.new()
	body.name = "DynamicBall2D_%d" % _ball_count
	body.mass = 2.0

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	body.add_child(shape)

	# Visual indicator
	var poly = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var a = (float(i) / 16.0) * TAU
		pts.append(Vector2(cos(a), sin(a)) * 18.0)
	poly.polygon = pts
	poly.color = Color(randf_range(0.3, 1.0), randf_range(0.3, 1.0), randf_range(0.3, 1.0))
	body.add_child(poly)

	var mouse_pos = get_viewport().get_mouse_position()
	body.position = mouse_pos
	body.linear_velocity = Vector2(randf_range(-100, 100), 50.0)

	add_child(body)
	VerletAudioSynth.play_sound(get_tree(), "thud", -4.0)
	_set_status("Dropped 2D Physics Ball #%d!" % _ball_count)


func _spawn_ragdoll_2d() -> void:
	_ragdoll_count += 1
	var ragdoll = VerletRagdoll2DClass.new()
	ragdoll.name = "DynamicRagdoll2D_%d" % _ragdoll_count
	ragdoll.character_scale = randf_range(0.85, 1.2)

	# Varied stylized outfit color schemes
	var r = randf()
	if r < 0.33:
		ragdoll.shirt_color = Color(0.9, 0.3, 0.25)
		ragdoll.pants_color = Color(0.15, 0.2, 0.3)
	elif r < 0.66:
		ragdoll.shirt_color = Color(0.2, 0.75, 0.45)
		ragdoll.pants_color = Color(0.25, 0.25, 0.28)
	else:
		ragdoll.shirt_color = Color(0.95, 0.7, 0.15)
		ragdoll.pants_color = Color(0.4, 0.2, 0.15)

	var mouse_pos = get_viewport().get_mouse_position()
	ragdoll.position = mouse_pos
	ragdoll.add_to_group("verlet_physics_2d")
	add_child(ragdoll)

	# Impart playful initial velocity & spin
	var tumble_vel = Vector2(randf_range(-140.0, 140.0), randf_range(-80.0, 20.0))
	ragdoll.apply_velocity(tumble_vel)

	VerletAudioSynth.play_sound(get_tree(), "thud", -2.0)
	_set_status("Dropped 2D Ragdoll #%d at (%d, %d)!" % [_ragdoll_count, int(mouse_pos.x), int(mouse_pos.y)])


func _switch_to_3d() -> void:
	get_tree().change_scene_to_file("res://demo/scenes/showcase_world.tscn")


func _reset_scene() -> void:
	VerletAudioSynth.play_sound(get_tree(), "cut")
	get_tree().reload_current_scene()


func _set_status(txt: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = "Interaction: " + txt

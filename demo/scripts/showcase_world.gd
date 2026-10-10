#=============================================================================
# ShowcaseWorld - Controller for Verlet Dynamics 3D Interactive Playground
#=============================================================================
extends Node3D

@onready var camera: Camera3D = $FreeFlyCamera
@onready var fps_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/FPSLabel
@onready var particles_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/ParticlesLabel
@onready var constraints_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/ConstraintsLabel
@onready var status_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/StatusLabel
@onready var wind_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/WindButton
@onready var spawn_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/SpawnButton
@onready var reset_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/ResetButton

@export var wind_active: bool = true
var _ball_count: int = 0


func _ready() -> void:
	if is_instance_valid(wind_btn):
		wind_btn.pressed.connect(_toggle_wind)
	if is_instance_valid(spawn_btn):
		spawn_btn.pressed.connect(_spawn_physics_ball)
	if is_instance_valid(reset_btn):
		reset_btn.pressed.connect(_reset_scene)

	if is_instance_valid(camera):
		camera.interaction_hint_updated.connect(_on_hint_updated)

	_update_wind_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_reset_scene()
			KEY_B, KEY_SPACE:
				_spawn_physics_ball()
			KEY_W:
				_toggle_wind()


func _process(_delta: float) -> void:
	# Update HUD telemetry
	if is_instance_valid(fps_label):
		fps_label.text = "FPS: %d (%0.2f ms)" % [Engine.get_frames_per_second(), 1000.0 / max(1.0, float(Engine.get_frames_per_second()))]

	var total_p: int = 0
	var total_c: int = 0
	for node in get_tree().get_nodes_in_group("verlet_physics"):
		if node is VerletRope3D:
			total_p += node.particles.size()
			total_c += node.constraints.size()
		elif node is VerletCloth3D:
			total_p += node.resolution.x * node.resolution.y
			total_c += node.structural_constraints.size() + node.shear_constraints.size()
		elif node is VerletSoftVolume3D:
			total_p += node.particles.size()
			total_c += node.constraints.size()

	if is_instance_valid(particles_label):
		particles_label.text = "Simulated Particles: %d" % total_p
	if is_instance_valid(constraints_label):
		constraints_label.text = "Active Constraints: %d" % total_c


func _toggle_wind() -> void:
	wind_active = not wind_active
	_update_wind_state()


func _update_wind_state() -> void:
	var wind_vec = Vector3(6.0, 1.2, 0.0) if wind_active else Vector3.ZERO
	for node in get_tree().get_nodes_in_group("verlet_physics"):
		if node is VerletCloth3D:
			node.wind_vector = wind_vec
		elif node is VerletRope3D:
			node.wind_vector = wind_vec * 0.5

	if is_instance_valid(wind_btn):
		wind_btn.text = "Wind: %s" % ("ON [6.0 m/s]" if wind_active else "OFF")


func _spawn_physics_ball() -> void:
	_ball_count += 1
	var body = RigidBody3D.new()
	body.name = "DynamicBall_%d" % _ball_count
	body.mass = 2.5

	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	body.add_child(shape)

	var mesh_inst = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.35
	sphere_mesh.height = 0.7
	mesh_inst.mesh = sphere_mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(randf_range(0.2, 1.0), randf_range(0.3, 1.0), randf_range(0.2, 1.0))
	mat.metallic = 0.6
	mat.roughness = 0.2
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	# Spawn slightly above the camera view or above the cloth/bridge
	var cam_pos = camera.global_position if is_instance_valid(camera) else Vector3(0, 10, 0)
	var cam_forward = -camera.global_transform.basis.z if is_instance_valid(camera) else Vector3.FORWARD
	body.position = cam_pos + (cam_forward * 4.0) + Vector3.UP * 1.5
	body.linear_velocity = (cam_forward * 10.0) + Vector3.UP * 2.0

	add_child(body)
	_on_hint_updated("Fired Physics Sphere #%d!" % _ball_count)


func _reset_scene() -> void:
	get_tree().reload_current_scene()


func _on_hint_updated(text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = "Interaction: " + text

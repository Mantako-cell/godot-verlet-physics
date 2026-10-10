#=============================================================================
# ShowcaseWorld - Controller for Verlet Dynamics 3D Interactive Playground
# Features: Real-time telemetry, tension heatmap toggle, wind modes,
# dynamic physics ball projectile spawner, and procedural audio.
#=============================================================================
extends Node3D

const VerletAudioSynth = preload("verlet_audio_synth.gd")

@onready var camera: Camera3D = $FreeFlyCamera
@onready var fps_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/FPSLabel
@onready var particles_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/ParticlesLabel
@onready var constraints_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/ConstraintsLabel
@onready var status_label: Label = $HUD/MarginContainer/VBoxContainer/PanelStats/VBox/StatusLabel
@onready var wind_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/WindButton
@onready var tension_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/TensionButton
@onready var grapple_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/GrappleButton
@onready var spawn_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/SpawnButton
@onready var reset_btn: Button = $HUD/MarginContainer/VBoxContainer/HBoxButtons/ResetButton
@onready var quality_btn: Button = get_node_or_null("HUD/MarginContainer/VBoxContainer/HBoxButtons/QualityButton")
@onready var switch_2d_btn: Button = get_node_or_null("HUD/MarginContainer/VBoxContainer/HBoxButtons/Switch2DButton")
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D

enum WindMode {
	DIRECTIONAL,
	WHIRLWIND_VORTEX,
	OFF
}

var current_wind_mode: WindMode = WindMode.DIRECTIONAL
var tension_heatmap_active: bool = false
var igpu_mode: bool = true
var _ball_count: int = 0


func _ready() -> void:
	if is_instance_valid(wind_btn):
		wind_btn.pressed.connect(_cycle_wind_mode)
	if is_instance_valid(tension_btn):
		tension_btn.pressed.connect(_toggle_tension_heatmap)
	if is_instance_valid(grapple_btn):
		grapple_btn.pressed.connect(_trigger_grapple)
	if is_instance_valid(spawn_btn):
		spawn_btn.pressed.connect(_spawn_physics_ball)
	if is_instance_valid(reset_btn):
		reset_btn.pressed.connect(_reset_scene)
	if is_instance_valid(quality_btn):
		quality_btn.pressed.connect(_toggle_quality_mode)
	if is_instance_valid(switch_2d_btn):
		switch_2d_btn.pressed.connect(_switch_to_2d)

	if is_instance_valid(camera) and camera.has_signal("interaction_hint_updated"):
		camera.connect("interaction_hint_updated", _on_hint_updated)

	_apply_wind_mode()
	_apply_quality_profile()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_reset_scene()
			KEY_B, KEY_SPACE:
				_spawn_physics_ball()
			KEY_W:
				_cycle_wind_mode()
			KEY_T:
				_toggle_tension_heatmap()
			KEY_P:
				_toggle_quality_mode()
			KEY_2:
				_switch_to_2d()


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


func _cycle_wind_mode() -> void:
	match current_wind_mode:
		WindMode.DIRECTIONAL:
			current_wind_mode = WindMode.WHIRLWIND_VORTEX
		WindMode.WHIRLWIND_VORTEX:
			current_wind_mode = WindMode.OFF
		WindMode.OFF:
			current_wind_mode = WindMode.DIRECTIONAL

	_apply_wind_mode()


func _apply_wind_mode() -> void:
	var wind_area = get_node_or_null("Station_Whirlwind/TornadoArea") as VerletWindArea3D

	match current_wind_mode:
		WindMode.DIRECTIONAL:
			if is_instance_valid(wind_btn):
				wind_btn.text = "Wind: GALE (6 m/s)"
			for node in get_tree().get_nodes_in_group("verlet_physics"):
				if node is VerletCloth3D:
					node.wind_vector = Vector3(6.0, 1.2, 0.0)
				elif node is VerletRope3D:
					node.wind_vector = Vector3(3.0, 0.6, 0.0)
			if is_instance_valid(wind_area):
				wind_area.wind_strength = 0.0

		WindMode.WHIRLWIND_VORTEX:
			if is_instance_valid(wind_btn):
				wind_btn.text = "Wind: TORNADO VORTEX"
			for node in get_tree().get_nodes_in_group("verlet_physics"):
				if node is VerletCloth3D:
					node.wind_vector = Vector3(1.5, 2.0, 1.5)
				elif node is VerletRope3D:
					node.wind_vector = Vector3.ZERO
			if is_instance_valid(wind_area):
				wind_area.wind_strength = 18.0
				wind_area.wind_type = VerletWindArea3D.WindType.VORTEX_SWIRL

		WindMode.OFF:
			if is_instance_valid(wind_btn):
				wind_btn.text = "Wind: OFF"
			for node in get_tree().get_nodes_in_group("verlet_physics"):
				if node is VerletCloth3D:
					node.wind_vector = Vector3.ZERO
				elif node is VerletRope3D:
					node.wind_vector = Vector3.ZERO
			if is_instance_valid(wind_area):
				wind_area.wind_strength = 0.0


func _toggle_tension_heatmap() -> void:
	tension_heatmap_active = not tension_heatmap_active
	for node in get_tree().get_nodes_in_group("verlet_physics"):
		if node is VerletRope3D:
			node.visualize_tension = tension_heatmap_active
			if is_instance_valid(node._mesh_instance) and node._mesh_instance.material_override is StandardMaterial3D:
				(node._mesh_instance.material_override as StandardMaterial3D).vertex_color_use_as_albedo = tension_heatmap_active

	if is_instance_valid(tension_btn):
		tension_btn.text = "Tension Heatmap: %s" % ("ON" if tension_heatmap_active else "OFF")
	_on_hint_updated("Tension Stress Heatmap %s" % ("ENABLED (Green->Red)" if tension_heatmap_active else "DISABLED"))


func _trigger_grapple() -> void:
	if is_instance_valid(camera) and camera.has_method("_toggle_grappling_hook"):
		camera.call("_toggle_grappling_hook")


func _spawn_physics_ball() -> void:
	_ball_count += 1
	var body = RigidBody3D.new()
	body.name = "DynamicBall_%d" % _ball_count
	body.mass = 3.0

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
	mat.metallic = 0.75
	mat.roughness = 0.2
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var cam_pos = camera.global_position if is_instance_valid(camera) else Vector3(0, 10, 0)
	var cam_forward = -camera.global_transform.basis.z if is_instance_valid(camera) else Vector3.FORWARD
	body.position = cam_pos + (cam_forward * 3.5) + Vector3.UP * 0.8
	body.linear_velocity = (cam_forward * 12.0) + Vector3.UP * 2.0

	add_child(body)
	VerletAudioSynth.play_sound(get_tree(), "thud", -4.0)
	_on_hint_updated("Launched Physics Ball #%d!" % _ball_count)


func _reset_scene() -> void:
	VerletAudioSynth.play_sound(get_tree(), "cut")
	get_tree().reload_current_scene()


func _on_hint_updated(text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = "Interaction: " + text


func _switch_to_2d() -> void:
	get_tree().change_scene_to_file("res://demo/scenes/showcase_world_2d.tscn")


func _toggle_quality_mode() -> void:
	igpu_mode = not igpu_mode
	_apply_quality_profile()


func _apply_quality_profile() -> void:
	if is_instance_valid(world_env) and world_env.environment:
		world_env.environment.glow_enabled = not igpu_mode

	if is_instance_valid(sun_light):
		sun_light.shadow_enabled = not igpu_mode

	# Adjust solver iterations across all Verlet nodes
	var target_iters = 6 if igpu_mode else 12
	for node in get_tree().get_nodes_in_group("verlet_physics"):
		if "solver_iterations" in node:
			node.solver_iterations = target_iters

	if is_instance_valid(quality_btn):
		quality_btn.text = "Profile: iGPU / Fast (P)" if igpu_mode else "Profile: High / dGPU (P)"

	_on_hint_updated("Switched to %s mode!" % ("iGPU High-FPS" if igpu_mode else "High Fidelity"))


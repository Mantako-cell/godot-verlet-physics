#=============================================================================
# VerletDynamics3D - Editor Plugin Registration
# Part of VerletDynamics3D for Godot 4.x
#=============================================================================
@tool
extends EditorPlugin

const PLUGIN_NAME = "VerletDynamics3D"

func _enter_tree() -> void:
	var rope_icon = load("res://addons/verlet_dynamics_3d/icons/icon_rope.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_rope.svg") else null
	var cloth_icon = load("res://addons/verlet_dynamics_3d/icons/icon_cloth.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_cloth.svg") else null
	var soft_icon = load("res://addons/verlet_dynamics_3d/icons/icon_softbody.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_softbody.svg") else null
	var wind_icon = load("res://addons/verlet_dynamics_3d/icons/icon_wind.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_wind.svg") else null

	# Register Custom Node Types
	add_custom_type(
		"VerletRope3D",
		"Node3D",
		preload("res://addons/verlet_dynamics_3d/nodes/verlet_rope_3d.gd"),
		rope_icon
	)

	add_custom_type(
		"VerletCloth3D",
		"Node3D",
		preload("res://addons/verlet_dynamics_3d/nodes/verlet_cloth_3d.gd"),
		cloth_icon
	)

	add_custom_type(
		"VerletSoftVolume3D",
		"Node3D",
		preload("res://addons/verlet_dynamics_3d/nodes/verlet_soft_volume_3d.gd"),
		soft_icon
	)

	add_custom_type(
		"VerletWindArea3D",
		"Area3D",
		preload("res://addons/verlet_dynamics_3d/nodes/verlet_wind_area_3d.gd"),
		wind_icon
	)

	print("[%s] Plugin enabled successfully in Godot Editor." % PLUGIN_NAME)


func _exit_tree() -> void:
	remove_custom_type("VerletRope3D")
	remove_custom_type("VerletCloth3D")
	remove_custom_type("VerletSoftVolume3D")
	remove_custom_type("VerletWindArea3D")

	print("[%s] Plugin disabled." % PLUGIN_NAME)

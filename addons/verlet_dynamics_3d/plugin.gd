#=============================================================================
# VerletDynamics - Editor Plugin Registration (2D & 3D Physics Suite)
# Part of VerletDynamics for Godot 4.x
#=============================================================================
@tool
extends EditorPlugin

const PLUGIN_NAME = "VerletDynamics"

func _enter_tree() -> void:
	# Load 3D Icons
	var rope_icon_3d = load("res://addons/verlet_dynamics_3d/icons/icon_rope.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_rope.svg") else null
	var cloth_icon_3d = load("res://addons/verlet_dynamics_3d/icons/icon_cloth.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_cloth.svg") else null
	var soft_icon_3d = load("res://addons/verlet_dynamics_3d/icons/icon_softbody.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_softbody.svg") else null
	var wind_icon_3d = load("res://addons/verlet_dynamics_3d/icons/icon_wind.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_wind.svg") else null

	# Load 2D Icons
	var rope_icon_2d = load("res://addons/verlet_dynamics_3d/icons/icon_rope_2d.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_rope_2d.svg") else null
	var cloth_icon_2d = load("res://addons/verlet_dynamics_3d/icons/icon_cloth_2d.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_cloth_2d.svg") else null
	var soft_icon_2d = load("res://addons/verlet_dynamics_3d/icons/icon_softbody_2d.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_softbody_2d.svg") else null
	var wind_icon_2d = load("res://addons/verlet_dynamics_3d/icons/icon_wind_2d.svg") if ResourceLoader.exists("res://addons/verlet_dynamics_3d/icons/icon_wind_2d.svg") else null

	# --- 3D Custom Nodes ---
	add_custom_type("VerletRope3D", "Node3D", preload("res://addons/verlet_dynamics_3d/nodes/verlet_rope_3d.gd"), rope_icon_3d)
	add_custom_type("VerletCloth3D", "Node3D", preload("res://addons/verlet_dynamics_3d/nodes/verlet_cloth_3d.gd"), cloth_icon_3d)
	add_custom_type("VerletSoftVolume3D", "Node3D", preload("res://addons/verlet_dynamics_3d/nodes/verlet_soft_volume_3d.gd"), soft_icon_3d)
	add_custom_type("VerletWindArea3D", "Area3D", preload("res://addons/verlet_dynamics_3d/nodes/verlet_wind_area_3d.gd"), wind_icon_3d)

	# --- 2D Custom Nodes ---
	add_custom_type("VerletRope2D", "Node2D", preload("res://addons/verlet_dynamics_3d/nodes/verlet_rope_2d.gd"), rope_icon_2d)
	add_custom_type("VerletCloth2D", "Node2D", preload("res://addons/verlet_dynamics_3d/nodes/verlet_cloth_2d.gd"), cloth_icon_2d)
	add_custom_type("VerletSoftBody2D", "Node2D", preload("res://addons/verlet_dynamics_3d/nodes/verlet_soft_body_2d.gd"), soft_icon_2d)
	add_custom_type("VerletWindArea2D", "Area2D", preload("res://addons/verlet_dynamics_3d/nodes/verlet_wind_area_2d.gd"), wind_icon_2d)

	print("[%s] 2D & 3D Physics Suite enabled successfully in Godot Editor." % PLUGIN_NAME)


func _exit_tree() -> void:
	remove_custom_type("VerletRope3D")
	remove_custom_type("VerletCloth3D")
	remove_custom_type("VerletSoftVolume3D")
	remove_custom_type("VerletWindArea3D")

	remove_custom_type("VerletRope2D")
	remove_custom_type("VerletCloth2D")
	remove_custom_type("VerletSoftBody2D")
	remove_custom_type("VerletWindArea2D")

	print("[%s] Plugin disabled." % PLUGIN_NAME)

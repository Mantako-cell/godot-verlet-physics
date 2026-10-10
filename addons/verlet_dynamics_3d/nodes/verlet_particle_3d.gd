#=============================================================================
# VerletParticle3D - Core Particle for Verlet Dynamics Engine
# Part of VerletDynamics3D for Godot 4.x
#=============================================================================
class_name VerletParticle3D
extends RefCounted

var position: Vector3 = Vector3.ZERO
var prev_position: Vector3 = Vector3.ZERO
var acceleration: Vector3 = Vector3.ZERO
var mass: float = 1.0
var inv_mass: float = 1.0

var is_pinned: bool = false
var pin_node: Node3D = null
var pin_offset: Vector3 = Vector3.ZERO
var pin_world_pos: Vector3 = Vector3.ZERO

var radius: float = 0.05
var active: bool = true


func _init(p_pos: Vector3 = Vector3.ZERO, p_mass: float = 1.0, p_radius: float = 0.05) -> void:
	position = p_pos
	prev_position = p_pos
	set_mass(p_mass)
	radius = p_radius


func set_mass(p_mass: float) -> void:
	mass = maxf(p_mass, 0.0001)
	inv_mass = 1.0 / mass if not is_pinned else 0.0


func pin_to_world(p_world_pos: Vector3) -> void:
	is_pinned = true
	pin_node = null
	pin_world_pos = p_world_pos
	position = p_world_pos
	prev_position = p_world_pos
	inv_mass = 0.0


func pin_to_node(p_node: Node3D, p_local_offset: Vector3 = Vector3.ZERO) -> void:
	is_pinned = true
	pin_node = p_node
	pin_offset = p_local_offset
	if is_instance_valid(p_node):
		var target_pos: Vector3 = p_node.global_transform * pin_offset
		position = target_pos
		prev_position = target_pos
	inv_mass = 0.0


func unpin(p_inherit_velocity: Vector3 = Vector3.ZERO) -> void:
	is_pinned = false
	pin_node = null
	inv_mass = 1.0 / mass
	prev_position = position - p_inherit_velocity


func sync_pin() -> void:
	if not is_pinned:
		return
	if is_instance_valid(pin_node):
		var target_pos: Vector3 = pin_node.global_transform * pin_offset
		prev_position = position
		position = target_pos
	else:
		position = pin_world_pos
		prev_position = pin_world_pos


func apply_force(force: Vector3) -> void:
	if is_pinned or not active:
		return
	acceleration += force * inv_mass


func apply_impulse(impulse: Vector3) -> void:
	if is_pinned or not active:
		return
	prev_position -= impulse * inv_mass


func integrate(delta: float, damping: float) -> void:
	if is_pinned or not active:
		return
	var temp: Vector3 = position
	var velocity: Vector3 = (position - prev_position) * damping
	position += velocity + acceleration * (delta * delta)
	prev_position = temp
	acceleration = Vector3.ZERO


func get_velocity(delta: float) -> Vector3:
	if delta <= 0.00001:
		return Vector3.ZERO
	return (position - prev_position) / delta


func set_velocity(vel: Vector3, delta: float) -> void:
	prev_position = position - (vel * delta)

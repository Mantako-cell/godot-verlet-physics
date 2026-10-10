#=============================================================================
# VerletParticle2D - Core 2D Particle for Verlet Dynamics Engine
# Part of VerletDynamics for Godot 4.x
#=============================================================================
class_name VerletParticle2D
extends RefCounted

var position: Vector2 = Vector2.ZERO
var prev_position: Vector2 = Vector2.ZERO
var acceleration: Vector2 = Vector2.ZERO
var mass: float = 1.0
var inv_mass: float = 1.0

var is_pinned: bool = false
var pin_node: Node2D = null
var pin_offset: Vector2 = Vector2.ZERO
var pin_world_pos: Vector2 = Vector2.ZERO

var radius: float = 4.0
var active: bool = true


func _init(p_pos: Vector2 = Vector2.ZERO, p_mass: float = 1.0, p_radius: float = 4.0) -> void:
	position = p_pos
	prev_position = p_pos
	set_mass(p_mass)
	radius = p_radius


func set_mass(p_mass: float) -> void:
	mass = maxf(p_mass, 0.0001)
	inv_mass = 1.0 / mass if not is_pinned else 0.0


func pin_to_world(p_world_pos: Vector2) -> void:
	is_pinned = true
	pin_node = null
	pin_world_pos = p_world_pos
	position = p_world_pos
	prev_position = p_world_pos
	inv_mass = 0.0


func pin_to_node(p_node: Node2D, p_local_offset: Vector2 = Vector2.ZERO) -> void:
	is_pinned = true
	pin_node = p_node
	pin_offset = p_local_offset
	if is_instance_valid(p_node):
		var target_pos: Vector2 = p_node.global_transform * pin_offset
		position = target_pos
		prev_position = target_pos
	inv_mass = 0.0


func unpin(p_inherit_velocity: Vector2 = Vector2.ZERO) -> void:
	is_pinned = false
	pin_node = null
	inv_mass = 1.0 / mass
	prev_position = position - p_inherit_velocity


func sync_pin() -> void:
	if not is_pinned:
		return
	if is_instance_valid(pin_node):
		var target_pos: Vector2 = pin_node.global_transform * pin_offset
		prev_position = position
		position = target_pos
	else:
		position = pin_world_pos
		prev_position = pin_world_pos


func apply_force(force: Vector2) -> void:
	if is_pinned or not active:
		return
	acceleration += force * inv_mass


func apply_impulse(impulse: Vector2) -> void:
	if is_pinned or not active:
		return
	prev_position -= impulse * inv_mass


func integrate(delta: float, damping: float) -> void:
	if is_pinned or not active:
		return
	var temp: Vector2 = position
	var velocity: Vector2 = (position - prev_position) * damping
	position += velocity + acceleration * (delta * delta)
	prev_position = temp
	acceleration = Vector2.ZERO


func get_velocity(delta: float) -> Vector2:
	if delta <= 0.00001:
		return Vector2.ZERO
	return (position - prev_position) / delta


func set_velocity(vel: Vector2, delta: float) -> void:
	prev_position = position - (vel * delta)

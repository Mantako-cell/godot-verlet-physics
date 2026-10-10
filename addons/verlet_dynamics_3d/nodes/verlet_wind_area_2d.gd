#=============================================================================
# VerletWindArea2D - 2D Directional & Radial Wind Source / Fan for Godot 4.x
# Features: Directional wind, localized gusts, and radial shockwaves on 2D Verlet objects.
#=============================================================================
@tool
class_name VerletWindArea2D
extends Area2D

enum WindType2D {
	DIRECTIONAL,
	RADIAL_OUTWARD
}

@export var wind_type: WindType2D = WindType2D.DIRECTIONAL
@export var wind_strength: float = 400.0
@export var wind_direction: Vector2 = Vector2.RIGHT
@export var gustiness: float = 0.5
@export var gust_frequency: float = 2.5
@export var radius: float = 250.0

var _time_acc: float = 0.0


func _process(delta: float) -> void:
	_time_acc += delta


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var gust: float = 1.0 + sin(_time_acc * gust_frequency) * gustiness
	var current_power: float = wind_strength * gust

	var nodes = get_tree().get_nodes_in_group("verlet_physics_2d")
	for node in nodes:
		if node is VerletRope2D:
			_apply_to_rope(node, current_power)
		elif node is VerletCloth2D:
			_apply_to_cloth(node, current_power)


func _get_wind_vector_at(target_pos: Vector2, power: float) -> Vector2:
	var cur_pos = global_position if is_inside_tree() else position
	var delta = target_pos - cur_pos
	var dist = delta.length()
	if dist >= radius or dist < 0.001:
		return Vector2.ZERO

	var falloff = 1.0 - (dist / radius)
	var dir = Vector2.ZERO

	match wind_type:
		WindType2D.DIRECTIONAL:
			var rot = global_rotation if is_inside_tree() else rotation
			dir = wind_direction.rotated(rot).normalized()
		WindType2D.RADIAL_OUTWARD:
			dir = delta / dist

	return dir * power * falloff


func _apply_to_rope(rope: VerletRope2D, power: float) -> void:
	for p in rope.particles:
		var force = _get_wind_vector_at(p.position, power)
		if force != Vector2.ZERO:
			p.apply_force(force)


func _apply_to_cloth(cloth: VerletCloth2D, power: float) -> void:
	var w = cloth.resolution.x
	var h = cloth.resolution.y
	for x in range(w):
		for y in range(h):
			var p = cloth.particles[x][y]
			var force = _get_wind_vector_at(p.position, power)
			if force != Vector2.ZERO:
				p.apply_force(force)

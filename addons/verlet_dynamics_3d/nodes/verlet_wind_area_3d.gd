#=============================================================================
# VerletWindArea3D - Localized Wind Source & Fan Volume for Godot 4.x
# Features: Directional wind, localized turbulence, vortex swirl,
# dynamic gust impulses applied to Verlet ropes and cloth within its influence.
#=============================================================================
@tool
class_name VerletWindArea3D
extends Area3D

enum WindType {
	DIRECTIONAL,
	RADIAL_OUTWARD,
	VORTEX_SWIRL
}

@export var wind_type: WindType = WindType.DIRECTIONAL
@export var wind_strength: float = 12.0
@export var wind_direction: Vector3 = Vector3.FORWARD
@export var gustiness: float = 0.6
@export var gust_frequency: float = 2.5
@export var radius: float = 8.0

var _time_acc: float = 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Connect area signals if collision shapes are present
		area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_time_acc += delta


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Calculate current gust multiplier
	var gust: float = 1.0 + (sin(_time_acc * gust_frequency) * 0.5 + sin(_time_acc * gust_frequency * 2.3) * 0.3) * gustiness
	var current_wind_power = wind_strength * gust

	# Scan tree or nearby Verlet objects
	var nodes = get_tree().get_nodes_in_group("verlet_physics")
	for node in nodes:
		if node is VerletRope3D:
			_apply_to_rope(node, current_wind_power)
		elif node is VerletCloth3D:
			_apply_to_cloth(node, current_wind_power)


func _get_wind_vector_at(target_pos: Vector3, power: float) -> Vector3:
	var cur_pos: Vector3 = global_position if is_inside_tree() else position
	var delta: Vector3 = target_pos - cur_pos
	var dist: float = delta.length()
	if dist >= radius or dist < 0.001:
		return Vector3.ZERO

	var falloff: float = 1.0 - (dist / radius)
	var dir: Vector3 = Vector3.ZERO

	match wind_type:
		WindType.DIRECTIONAL:
			var base_basis = global_transform.basis if is_inside_tree() else transform.basis
			dir = (base_basis * wind_direction).normalized()
		WindType.RADIAL_OUTWARD:
			dir = delta / dist
		WindType.VORTEX_SWIRL:
			var tangent = Vector3(-delta.z, 0.0, delta.x).normalized()
			dir = (tangent * 0.85 + Vector3.UP * 0.35).normalized()

	return dir * power * falloff


func _apply_to_rope(rope: VerletRope3D, power: float) -> void:
	for p in rope.particles:
		var force = _get_wind_vector_at(p.position, power)
		if force != Vector3.ZERO:
			p.apply_force(force)


func _apply_to_cloth(cloth: VerletCloth3D, power: float) -> void:
	var w = cloth.resolution.x
	var h = cloth.resolution.y
	for x in range(w):
		for y in range(h):
			var p = cloth.particles[x][y]
			var force = _get_wind_vector_at(p.position, power)
			if force != Vector3.ZERO:
				p.apply_force(force)


func _on_area_entered(_area: Area3D) -> void:
	pass

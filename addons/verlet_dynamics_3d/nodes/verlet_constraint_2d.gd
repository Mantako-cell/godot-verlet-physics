#=============================================================================
# VerletConstraint2D - Distance constraint between two 2D particles
# Part of VerletDynamics for Godot 4.x
#=============================================================================
class_name VerletConstraint2D
extends RefCounted

var p1: VerletParticle2D
var p2: VerletParticle2D
var rest_length: float = 20.0
var stiffness: float = 1.0 # 0.0 to 1.0
var is_active: bool = true
var can_break: bool = false
var break_tension_limit: float = 1000.0

var current_tension: float = 0.0
var current_elongation: float = 0.0


func _init(
	particle_a: VerletParticle2D,
	particle_b: VerletParticle2D,
	custom_length: float = -1.0,
	p_stiffness: float = 1.0
) -> void:
	p1 = particle_a
	p2 = particle_b
	stiffness = clampf(p_stiffness, 0.01, 1.0)
	if custom_length > 0.0:
		rest_length = custom_length
	else:
		rest_length = maxf(particle_a.position.distance_to(particle_b.position), 0.001)


func solve() -> bool:
	if not is_active:
		return false

	var delta: Vector2 = p1.position - p2.position
	var current_distance: float = delta.length()
	if current_distance < 0.00001:
		return false

	var diff: float = current_distance - rest_length

	# Compute elongation and tension (scaled for 2D pixel space)
	current_elongation = diff
	current_tension = absf(diff) * stiffness * 2000.0

	# Check snapping
	if can_break and current_tension > break_tension_limit:
		is_active = false
		return true

	var total_inv_mass: float = p1.inv_mass + p2.inv_mass
	if total_inv_mass <= 0.000001:
		return false

	var factor: float = (diff / current_distance) * (stiffness / total_inv_mass)
	var corr: Vector2 = delta * factor

	if not p1.is_pinned:
		p1.position -= corr * p1.inv_mass
	if not p2.is_pinned:
		p2.position += corr * p2.inv_mass

	return false

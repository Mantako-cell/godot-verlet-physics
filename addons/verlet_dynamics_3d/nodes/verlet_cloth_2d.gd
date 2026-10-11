#=============================================================================
# VerletCloth2D - 2D Hanging Banner, Flag, Curtain & Net for Godot 4.x
# Features: 2D particle grid, structural and shear constraints, wind flutter,
# continuous 2D collision, runtime tearing, and procedural polygon drawing.
#=============================================================================
@tool
class_name VerletCloth2D
extends Node2D

signal cloth_torn(x: int, y: int)

enum PinPreset2D {
	TOP_EDGE,
	TOP_TWO_CORNERS,
	FOUR_CORNERS,
	LEFT_EDGE,
	NONE
}

@export_group("Grid & Dimensions")
@export var resolution: Vector2i = Vector2i(8, 8):
	set(val):
		resolution = Vector2i(clampi(val.x, 2, 32), clampi(val.y, 2, 32))
		if Engine.is_editor_hint():
			_rebuild_cloth()

@export var cloth_size: Vector2 = Vector2(160.0, 160.0):
	set(val):
		cloth_size = Vector2(maxf(val.x, 10.0), maxf(val.y, 10.0))
		if Engine.is_editor_hint():
			_rebuild_cloth()

@export_group("Pinning")
@export var pin_preset: PinPreset2D = PinPreset2D.TOP_EDGE:
	set(val):
		pin_preset = val
		_apply_pins()

@export var attach_corner_a: NodePath:
	set(val):
		attach_corner_a = val
		_cache_anchors()

@export var attach_corner_b: NodePath:
	set(val):
		attach_corner_b = val
		_cache_anchors()

@export_group("Dynamics")
@export var gravity: Vector2 = Vector2(0.0, 980.0)
@export_range(0.8, 0.999, 0.001) var damping: float = 0.985
@export_range(0.1, 1.0, 0.05) var structural_stiffness: float = 0.95
@export_range(0.0, 1.0, 0.05) var shear_stiffness: float = 0.5
@export_range(1, 20, 1) var solver_iterations: int = 8
@export_range(0.01, 5.0, 0.05) var particle_mass: float = 0.1

@export_group("Wind")
@export var wind_vector: Vector2 = Vector2.ZERO
@export_range(0.0, 2.0, 0.05) var wind_turbulence: float = 0.4

@export_group("Visuals")
@export var cloth_color: Color = Color(0.25, 0.6, 0.95):
	set(val):
		cloth_color = val
		queue_redraw()

@export var outline_color: Color = Color(0.15, 0.4, 0.75):
	set(val):
		outline_color = val
		queue_redraw()

var particles: Array[Array] = []
var structural_constraints: Array[VerletConstraint2D] = []
var shear_constraints: Array[VerletConstraint2D] = []

var _node_a_cache: Node2D = null
var _node_b_cache: Node2D = null
var _time_acc: float = 0.0


func _ready() -> void:
	_cache_anchors()
	_rebuild_cloth()


func _safe_xform() -> Transform2D:
	return global_transform if is_inside_tree() else transform


func _safe_pos() -> Vector2:
	return global_position if is_inside_tree() else position


func _cache_anchors() -> void:
	_node_a_cache = get_node_or_null(attach_corner_a) as Node2D if not attach_corner_a.is_empty() else null
	_node_b_cache = get_node_or_null(attach_corner_b) as Node2D if not attach_corner_b.is_empty() else null


func _rebuild_cloth() -> void:
	particles.clear()
	structural_constraints.clear()
	shear_constraints.clear()

	var w = resolution.x
	var h = resolution.y
	var step_x = cloth_size.x / float(w - 1)
	var step_y = cloth_size.y / float(h - 1)

	var cur_pos = _safe_pos()

	for x in range(w):
		var col: Array[VerletParticle2D] = []
		for y in range(h):
			var local_offset = Vector2(
				(float(x) / float(w - 1) - 0.5) * cloth_size.x,
				float(y) * step_y
			)
			var p = VerletParticle2D.new(cur_pos + local_offset, particle_mass, 3.0)
			col.append(p)
		particles.append(col)

	# 1. Structural constraints
	for x in range(w):
		for y in range(h):
			if x < w - 1:
				var ch = VerletConstraint2D.new(particles[x][y], particles[x + 1][y], step_x, structural_stiffness)
				structural_constraints.append(ch)
			if y < h - 1:
				var cv = VerletConstraint2D.new(particles[x][y], particles[x][y + 1], step_y, structural_stiffness)
				structural_constraints.append(cv)

	# 2. Shear constraints
	var diag_len = sqrt(step_x * step_x + step_y * step_y)
	for x in range(w - 1):
		for y in range(h - 1):
			var cd1 = VerletConstraint2D.new(particles[x][y], particles[x + 1][y + 1], diag_len, shear_stiffness)
			var cd2 = VerletConstraint2D.new(particles[x + 1][y], particles[x][y + 1], diag_len, shear_stiffness)
			shear_constraints.append(cd1)
			shear_constraints.append(cd2)

	_apply_pins()
	queue_redraw()


func _apply_pins() -> void:
	if particles.is_empty():
		return

	var w = resolution.x
	var h = resolution.y

	for x in range(w):
		for y in range(h):
			particles[x][y].unpin()

	match pin_preset:
		PinPreset2D.TOP_EDGE:
			for x in range(w):
				particles[x][0].pin_to_world(particles[x][0].position)
		PinPreset2D.TOP_TWO_CORNERS:
			if is_instance_valid(_node_a_cache):
				particles[0][0].pin_to_node(_node_a_cache)
			else:
				particles[0][0].pin_to_world(particles[0][0].position)

			if is_instance_valid(_node_b_cache):
				particles[w - 1][0].pin_to_node(_node_b_cache)
			else:
				particles[w - 1][0].pin_to_world(particles[w - 1][0].position)
		PinPreset2D.FOUR_CORNERS:
			particles[0][0].pin_to_world(particles[0][0].position)
			particles[w - 1][0].pin_to_world(particles[w - 1][0].position)
			particles[0][h - 1].pin_to_world(particles[0][h - 1].position)
			particles[w - 1][h - 1].pin_to_world(particles[w - 1][h - 1].position)
		PinPreset2D.LEFT_EDGE:
			for y in range(h):
				particles[0][y].pin_to_world(particles[0][y].position)
		PinPreset2D.NONE:
			pass


func _physics_process(delta: float) -> void:
	if particles.is_empty():
		return

	_time_acc += delta
	var w = resolution.x
	var h = resolution.y

	for x in range(w):
		for y in range(h):
			if particles[x][y].is_pinned:
				particles[x][y].sync_pin()

	var dynamic_wind = wind_vector
	if wind_vector.length_squared() > 0.001 and wind_turbulence > 0.0:
		var noise = sin(_time_acc * 4.0 + _safe_pos().x * 0.05) * wind_turbulence
		dynamic_wind += Vector2(noise, noise * 0.4) * wind_vector.length()

	var total_force = (gravity * particle_mass) + dynamic_wind
	for x in range(w):
		for y in range(h):
			var p = particles[x][y]
			if not p.is_pinned:
				p.apply_force(total_force)
			p.integrate(delta, damping)

	for iter in range(solver_iterations):
		for c in structural_constraints:
			c.solve()
		for c in shear_constraints:
			c.solve()

	queue_redraw()


func _draw() -> void:
	if particles.is_empty():
		return

	var inv_xform = _safe_xform().affine_inverse()
	var w = resolution.x
	var h = resolution.y

	# 1. Batch cloth quad triangles in a single GPU call
	var pts: PackedVector2Array = PackedVector2Array()
	for y in range(h):
		for x in range(w):
			pts.append(inv_xform * particles[x][y].position)

	var indices: PackedInt32Array = PackedInt32Array()
	for y in range(h - 1):
		for x in range(w - 1):
			if not particles[x][y].active or not particles[x + 1][y].active or not particles[x + 1][y + 1].active or not particles[x][y + 1].active:
				continue
			var i00 = y * w + x
			var i10 = y * w + (x + 1)
			var i11 = (y + 1) * w + (x + 1)
			var i01 = (y + 1) * w + x
			indices.append(i00)
			indices.append(i10)
			indices.append(i11)
			indices.append(i00)
			indices.append(i11)
			indices.append(i01)

	if indices.size() > 0:
		var colors = PackedColorArray([cloth_color])
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, pts, colors)

	# 2. Batch grid weave lines in a single GPU draw call
	var line_pts: PackedVector2Array = PackedVector2Array()
	for c in structural_constraints:
		if c.is_active:
			line_pts.append(inv_xform * c.p1.position)
			line_pts.append(inv_xform * c.p2.position)
	if line_pts.size() >= 2:
		draw_multiline(line_pts, outline_color, 1.2)


func tear_at(coord_x: int, coord_y: int) -> void:
	if coord_x < 0 or coord_x >= resolution.x or coord_y < 0 or coord_y >= resolution.y:
		return
	var target_p = particles[coord_x][coord_y]
	target_p.active = false
	for c in structural_constraints:
		if c.p1 == target_p or c.p2 == target_p:
			c.is_active = false
	for c in shear_constraints:
		if c.p1 == target_p or c.p2 == target_p:
			c.is_active = false
	cloth_torn.emit(coord_x, coord_y)
	queue_redraw()

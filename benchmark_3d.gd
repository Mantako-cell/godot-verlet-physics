extends SceneTree

func _init() -> void:
	print("=== BENCHMARKING BENDING CONSTRAINTS ===")
	var cloth = VerletCloth3D.new()
	cloth.resolution = Vector2i(8, 8)
	cloth.cloth_size = Vector2(3.0, 2.5)
	cloth.pin_preset = VerletCloth3D.PinPreset.TOP_EDGE
	cloth.wind_vector = Vector3(6.0, 1.0, 0.0)
	cloth.solver_iterations = 6
	cloth.collision_enabled = false
	cloth._ready()

	var frames = 100
	var t0 = Time.get_ticks_usec()
	for i in range(frames):
		cloth._physics_process(1.0 / 60.0)
	var t_with_bending = (Time.get_ticks_usec() - t0) / (frames * 1000.0)

	cloth.bending_constraints.clear()
	t0 = Time.get_ticks_usec()
	for i in range(frames):
		cloth._physics_process(1.0 / 60.0)
	var t_without_bending = (Time.get_ticks_usec() - t0) / (frames * 1000.0)

	print("With bending:    %0.3f ms/tick" % t_with_bending)
	print("Without bending: %0.3f ms/tick" % t_without_bending)
	quit()

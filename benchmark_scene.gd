extends SceneTree

func _collect_nodes(node: Node, list: Array) -> void:
	if node.is_in_group("verlet_physics"):
		list.append(node)
	for child in node.get_children():
		_collect_nodes(child, list)

func _init() -> void:
	print("=== PROFILING ENTIRE SHOWCASE SCENE ===")
	var scene = load("res://demo/scenes/showcase_world.tscn").instantiate()
	root.add_child(scene)

	var list: Array = []
	_collect_nodes(scene, list)
	print("Found %d active Verlet physics nodes in scene." % list.size())

	for n in list:
		if n.has_method("_ready"):
			n._ready()

	# Simulate 120 frames of the full scene
	var frames = 120
	var t0 = Time.get_ticks_usec()
	for f in range(frames):
		for node in list:
			node._physics_process(1.0 / 60.0)
	var total_time_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var avg_step_ms = total_time_ms / float(frames)

	print("Total time for %d physics steps: %0.2f ms" % [frames, total_time_ms])
	print("Average physics time per frame:  %0.2f ms" % avg_step_ms)
	print("Maximum theoretical physics FPS: %0.1f FPS" % (1000.0 / max(0.001, avg_step_ms)))

	for n in list:
		t0 = Time.get_ticks_usec()
		for f in range(30):
			n._physics_process(1.0 / 60.0)
		var n_ms = (Time.get_ticks_usec() - t0) / 30000.0
		print("  - Node [%s]: %0.3f ms/tick" % [n.name, n_ms])

	quit()

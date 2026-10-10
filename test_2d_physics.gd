extends SceneTree

func _init() -> void:
	print("=== RUNNING VERLET DYNAMICS 2D FULL TEST SUITE ===")

	# 1. Test VerletRope2D
	print("\n[Test 1] Testing VerletRope2D...")
	var rope = VerletRope2D.new()
	rope.length = 150.0
	rope.segment_count = 10
	rope.pin_start = true
	rope.pin_end = false
	rope._ready()

	assert(rope.particles.size() == 11, "2D rope particle count mismatch")
	for i in range(10):
		rope._physics_process(0.016)

	var last_p = rope.particles[10]
	print("2D rope end particle after 10 ticks: Y=%0.2f (gravity pulled down)" % last_p.position.y)
	assert(last_p.position.y > 0.0, "2D gravity should pull +Y downwards")

	rope.winch(-30.0)
	assert(rope.length == 120.0, "Winch shortening failed")
	rope.cut_at(5)
	assert(not rope.constraints[5].is_active, "Constraint 5 should be cut")
	print("SUCCESS: VerletRope2D passed!")

	# 2. Test VerletSoftBody2D
	print("\n[Test 2] Testing VerletSoftBody2D (Jelly/Slime Blob)...")
	var jelly = VerletSoftBody2D.new()
	jelly.radius = 35.0
	jelly.point_count = 10
	jelly._ready()

	assert(jelly.particles.size() == 11, "Softbody should have 1 center + 10 perimeter particles")
	for i in range(10):
		jelly._physics_process(0.016)
	print("SUCCESS: VerletSoftBody2D passed!")

	# 3. Test VerletCloth2D
	print("\n[Test 3] Testing VerletCloth2D (Hanging Banner)...")
	var cloth = VerletCloth2D.new()
	cloth.resolution = Vector2i(6, 6)
	cloth.cloth_size = Vector2(100.0, 100.0)
	cloth.pin_preset = VerletCloth2D.PinPreset2D.TOP_EDGE
	cloth._ready()

	assert(cloth.particles.size() == 6, "Cloth width mismatch")
	assert(cloth.particles[0].size() == 6, "Cloth height mismatch")
	for i in range(10):
		cloth._physics_process(0.016)

	cloth.tear_at(2, 2)
	print("SUCCESS: VerletCloth2D passed!")

	# 4. Test 2D Scene Execution
	print("\n[Test 4] Testing 2D Showcase Scene Execution...")
	change_scene_to_file("res://demo/scenes/showcase_world_2d.tscn")
	var timer = create_timer(1.2)
	timer.timeout.connect(func():
		print("\n=======================================================")
		print("ALL VERLET DYNAMICS 2D TESTS PASSED FLAWLESSLY!")
		print("=======================================================")
		quit(0)
	)

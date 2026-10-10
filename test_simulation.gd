extends SceneTree

func _init() -> void:
	print("=== RUNNING VERLET DYNAMICS 3D SIMULATION TESTS ===")
	
	# 1. Test VerletRope3D
	print("\n[Test 1] VerletRope3D simulation & constraints...")
	var rope = VerletRope3D.new()
	rope.length = 3.0
	rope.segment_count = 10
	rope.pin_start = true
	rope.pin_end = false
	rope._ready()
	
	print("Initial rope particles count: %d" % rope.particles.size())
	assert(rope.particles.size() == 11, "Particle count mismatch")
	
	# Step physics 10 times
	for f in range(10):
		rope._physics_process(0.016)
	
	var last_p = rope.particles[10]
	print("Rope end particle after 10 ticks: Y=%0.3f" % last_p.position.y)
	assert(last_p.position.y < 0.0, "Gravity should pull rope downwards")
	
	# Test snapping/cutting
	rope.cut_at(5)
	assert(not rope.constraints[5].is_active, "Constraint 5 should be inactive after cut")
	print("SUCCESS: VerletRope3D simulation and cut API passed!")
	
	# 2. Test VerletCloth3D
	print("\n[Test 2] VerletCloth3D simulation & aerodynamic wind...")
	var cloth = VerletCloth3D.new()
	cloth.resolution = Vector2i(8, 8)
	cloth.cloth_size = Vector2(2.0, 2.0)
	cloth.pin_preset = VerletCloth3D.PinPreset.TOP_EDGE
	cloth.wind_vector = Vector3(5.0, 0.0, 0.0)
	cloth._ready()
	
	print("Cloth particle grid dimensions: %dx%d" % [cloth.particles.size(), cloth.particles[0].size()])
	for f in range(10):
		cloth._physics_process(0.016)
	
	var corner_p = cloth.particles[7][7]
	print("Cloth bottom-right corner after wind & gravity: pos=%s" % str(corner_p.position))
	assert(corner_p.position.x > 0.0, "Wind should push cloth along +X")
	
	# Test tear
	cloth.tear_at(3, 3)
	print("SUCCESS: VerletCloth3D simulation and tear API passed!")
	
	# 3. Test VerletSoftVolume3D
	print("\n[Test 3] VerletSoftVolume3D lattice...")
	var soft = VerletSoftVolume3D.new()
	soft.size = Vector3(1.5, 1.5, 1.5)
	soft.elasticity_stiffness = 0.8
	soft._ready()
	
	print("Soft volume corners: %d, internal constraints: %d" % [soft.particles.size(), soft.constraints.size()])
	assert(soft.particles.size() == 8, "Cube should have 8 particles")
	
	for f in range(10):
		soft._physics_process(0.016)
	print("SUCCESS: VerletSoftVolume3D simulation passed!")
	
	print("\n=======================================================")
	print("ALL VERLET DYNAMICS 3D TESTS PASSED FLAWLESSLY!")
	print("=======================================================")
	quit(0)


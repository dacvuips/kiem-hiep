extends Node

func _ready() -> void:
	var f := FileAccess.open("res://test_result.txt", FileAccess.WRITE)
	f.store_line("--- TESTING: NO RANGED SKILLS WHEN NEAR PLAYER ---")
	MonsterData._ensure()
	
	var world := Node2D.new()
	add_child(world)
	
	var dummy := CharacterBody2D.new()
	dummy.name = "DummyPlayer"
	dummy.position = Vector2(0, 0)
	dummy.add_to_group("player")
	world.add_child(dummy)
	
	# Spawn monster at logic (0, 200), series = 3 (Hỏa)
	var mon: VltkMonster = VltkMonster.spawn(world, 588, 80, VltkMath.to_world(Vector2(0, 200)), true, 3)
	mon.target = dummy
	
	var distant_ranged_casts := 0
	var close_ranged_casts := 0
	var melee_casts := 0
	var walk_frames := 0
	var illegal_distant_melee := 0
	
	for frame in range(800):
		mon._physics_process(1.0 / 60.0)
		if mon._state == VltkMonster.State.WALK and mon.velocity != Vector2.ZERO:
			mon.global_position += mon.velocity * (1.0 / 60.0)
			
		var here := VltkMath.to_logic(mon.global_position)
		var there := VltkMath.to_logic(dummy.global_position)
		var dist := here.distance_to(there)
		
		if mon._state == VltkMonster.State.WALK:
			walk_frames += 1
		elif mon._state == VltkMonster.State.ATTACK:
			if mon._active_slot in [0, 2]:
				if dist > 85.0:
					distant_ranged_casts += 1
				else:
					close_ranged_casts += 1
			else:
				melee_casts += 1
				if dist > 75.0:
					illegal_distant_melee += 1
					
		if frame % 100 == 0:
			f.store_line("Frame %3d: dist=%.1f state=%d action=%s slot=%d" % [frame, dist, mon._state, mon._action, mon._active_slot])
	
	f.store_line("Simulation Results:")
	f.store_line("- Distant ranged casts (> 85px): %d" % distant_ranged_casts)
	f.store_line("- Walk frames (closing distance): %d" % walk_frames)
	f.store_line("- Melee casts (close range <= 75px): %d" % melee_casts)
	f.store_line("- Close ranged casts (<= 85px): %d" % close_ranged_casts)
	f.store_line("- Illegal distant melee: %d" % illegal_distant_melee)
	
	assert(distant_ranged_casts > 0, "Must cast ranged when at distance")
	assert(melee_casts > 0, "Must cast melee when close")
	assert(close_ranged_casts == 0, "MUST NEVER CAST RANGED WHEN CLOSE TO PLAYER!")
	assert(illegal_distant_melee == 0, "Must never cast melee from distance")
	
	f.store_line("--- TEST PASSED: ZERO RANGED CASTS WHEN CLOSE TO PLAYER! ---")
	f.close()
	get_tree().quit(0)

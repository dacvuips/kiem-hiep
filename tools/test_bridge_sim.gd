extends SceneTree

func _init() -> void:
	print(">>> RUNNING GODOT HEADLESS SIMULATION ON MAP 2 BRIDGE <<<")
	call_deferred("_run")

func _run() -> void:
	var r = get_root()
	var world := VltkWorld.new()
	world.map_dir = "res://world/maps/map_2"
	r.add_child(world)
	
	# Create dummy player
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.add_to_group("player")
	r.add_child(player)
	
	world.setup_main_map()
	
	# Give it a few frames to load chunks
	for i in 10:
		await process_frame
	
	var map: VltkMap = world.map
	if map == null:
		print("ERROR: map is null!")
		quit(1)
		return
	
	print("Map loaded. chunk_mode =", map.chunk_mode)
	
	# Test coordinates:
	# Bridge starts around x=76810, y=58009
	# Bridge ends around x=77571, y=58413
	# Let's test prepare_around bridge center
	var bridge_mid := Vector2(77150, 58200)
	map.prepare_around(bridge_mid)
	
	for i in 10:
		await process_frame
	
	print("Chunks in memory: ", map._chunks.keys())
	print("Obs in memory: ", map._obs.keys())
	
	# Let's check is_blocked along a line of points across the bridge
	# From left cliff (76750, 57950) to right cliff (77650, 58400)
	print("\n--- Testing points along bridge ---")
	
	# Let's test a sequence of points
	var p_start := Vector2(76800, 57980) # Left approach
	var p_end   := Vector2(77650, 58400) # Right approach
	
	# Let's test a grid of points on the bridge to see where walkable cells are
	print("\n--- Checking walkable cells across X from 76800 to 77650 ---")
	var blocked_ranges := []
	for x in range(76800, 77660, 20):
		var walkable_ys := []
		for y in range(57900, 58500, 10):
			var pt := Vector2(x, y)
			if not map.is_blocked(pt):
				walkable_ys.append(y)
		if walkable_ys.is_empty():
			print("CRITICAL: at X = %d, NO walkable Y found!" % x)
			blocked_ranges.append(x)
		else:
			print("X = %d: walkable Y from %d to %d (span %d px, %d points)" % [x, walkable_ys[0], walkable_ys[-1], walkable_ys[-1] - walkable_ys[0], walkable_ys.size()])
	
	if blocked_ranges.is_empty():
		print("\nSUCCESS: Walkable path exists across all X slices of the bridge!")
	else:
		print("\nFAIL: Blocked X slices: ", blocked_ranges)
	
	# Now let's test slide_velocity simulation
	print("\n--- Testing slide_velocity from left to right ---")
	var curr := Vector2(76810, 58010)
	# Find nearest open point to start
	for y in range(57900, 58100, 5):
		if not map.is_blocked(Vector2(76810, y)):
			curr = Vector2(76810, y)
			break
	
	print("Starting slide_velocity walk at: ", curr)
	var steps := 0
	var max_steps := 2000
	var target := Vector2(77650, 58400)
	var stuck := false
	
	while curr.distance_to(target) > 30 and steps < max_steps:
		steps += 1
		# Direction towards target or along bridge
		var dir := (target - curr).normalized()
		var vel := dir * 250.0 # 250 px/s speed
		var dt := 0.016
		var nxt_vel := VltkWorld.slide_velocity(curr, vel, dt, false, false)
		if nxt_vel.length() < 1.0:
			# Stuck! Try slight angle variations
			var moved := false
			for angle_deg in [-30, 30, -45, 45, -60, 60]:
				var alt_dir := dir.rotated(deg_to_rad(angle_deg))
				var alt_vel := VltkWorld.slide_velocity(curr, alt_dir * 250.0, dt, false, false)
				if alt_vel.length() > 1.0:
					curr += alt_vel * dt
					moved = true
					break
			if not moved:
				print("STUCK at step %d! Position: %s, cell: %s" % [steps, curr, map.world_to_cell(curr)])
				stuck = true
				break
		else:
			curr += nxt_vel * dt
	
	if not stuck:
		print("Successfully reached right cliff: ", curr, " in ", steps, " steps!")
	
	quit(0 if not stuck else 1)

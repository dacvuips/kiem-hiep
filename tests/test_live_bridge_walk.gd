extends Node

func _ready() -> void:
	print("==================================================")
	print(">>> TEST DI CHUYEN THUC TE QUA CAU HOA SON <<<")
	print("==================================================")
	call_deferred("_run_sim")

func _run_sim() -> void:
	var world := VltkWorld.new()
	world.map_dir = "res://world/maps/map_2"
	add_child(world)
	
	var player_scene: PackedScene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	
	world.setup_main_map()
	if world.map:
		world.map.focus = player
	
	# Start on West side of bridge
	var west_start := Vector2(76700, 57950)
	var east_target := Vector2(77800, 58550)
	player.global_position = west_start - Vector2(0, VltkWorld.FEET_OFFSET)
	world.map.prepare_around(west_start)
	
	for i in 30:
		await get_tree().process_frame
	
	var cur_feet_start: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
	print("Vi tri bat dau bo Tay: ", cur_feet_start)
	print("Muc tieu bo Dong: ", east_target)
	print("Bat dau player.walk_to_feet...")
	
	var ok: bool = bool(player.walk_to_feet(east_target))
	print("player.walk_to_feet tra ve: ", ok)
	
	var stuck_frames := 0
	var last_pos := Vector2.ZERO
	var total_frames := 0
	var max_frames := 600
	var reached := false
	
	while total_frames < max_frames:
		total_frames += 1
		await get_tree().process_frame
		var cur_feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
		if cur_feet.distance_to(last_pos) < 0.5:
			stuck_frames += 1
		else:
			stuck_frames = 0
		last_pos = cur_feet
		
		if cur_feet.distance_to(east_target) < 60.0:
			print("SUCCESS: Nhan vat da qua cau thanh cong toi bo Dong tai frame %d! Vi tri: %s" % [total_frames, str(cur_feet)])
			reached = true
			break
			
		if stuck_frames > 60:
			var cell: Vector2i = world.map.grid.world_to_cell(cur_feet)
			var val: int = world.map.grid._value(cell)
			print("STUCK tai frame %d! Vi tri feet: %s (cell: %s, val: 0x%02x, blocked: %s)" % [total_frames, str(cur_feet), str(cell), val, str((val>>4)!=0)])
			
			# Check 8 directions around stuck position
			print("  Cac o xung quanh:")
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var c2: Vector2i = cell + Vector2i(dx, dy)
					var v2: int = world.map.grid._value(c2)
					print("    offset (%d,%d) -> cell %s: val=0x%02x (blocked=%s)" % [dx, dy, str(c2), v2, str((v2>>4)!=0)])
			break
			
	if not reached and stuck_frames <= 60:
		var cur_feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
		print("Timeout tai frame %d! Vi tri: %s" % [total_frames, str(cur_feet)])
		
	get_tree().quit(0 if reached else 1)

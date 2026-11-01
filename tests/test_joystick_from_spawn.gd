extends Node

func _ready() -> void:
	print("==================================================")
	print(">>> TEST: KÉO JOYSTICK TỪ NƠI THẢ PLAYER TỚI CẦU")
	print("==================================================")
	call_deferred("_run_test")

func _run_test() -> void:
	var world := VltkWorld.new()
	world.map_dir = "res://world/maps/map_2"
	add_child(world)
	
	var player_scene: PackedScene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	
	world.setup_main_map()
	if world.map:
		world.map.focus = player
	
	for i in 25:
		await get_tree().process_frame
	
	var spawn_feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
	print("Nơi thả player (feet): ", spawn_feet, " (tọa độ hiển thị: %d/%d)" % [int(spawn_feet.x / 256.0), int(spawn_feet.y / 256.0)])
	print("is_blocked tại nơi thả: ", world.map.is_blocked(spawn_feet))
	
	# Đích đến là cầu gỗ Hoa Sơn (77450, 58300)
	var bridge_target := Vector2(77450.0, 58300.0)
	print("Đích đến cầu gỗ: ", bridge_target, " (tọa độ hiển thị: %d/%d)" % [int(bridge_target.x / 256.0), int(bridge_target.y / 256.0)])
	
	# Mô phỏng kéo Joystick theo hướng từ player tới cầu
	# Mỗi khi gặp chướng ngại vật, người chơi sẽ cố hướng cần theo hướng di chuyển được
	var cur_pos := spawn_feet
	var frames_stuck := 0
	var total_frames := 0
	var max_frames := 1200
	
	print("\n>>> Bắt đầu kéo Joystick liên tục theo hướng về phía cầu...")
	while cur_pos.distance_to(bridge_target) > 50.0 and total_frames < max_frames:
		total_frames += 1
		await get_tree().process_frame
		
		# Hướng từ player tới cầu
		var dir := (bridge_target - cur_pos).normalized()
		var desired_vel := dir * 250.0
		
		# VltkWorld.slide_velocity
		var actual_vel: Vector2 = VltkWorld.slide_velocity(cur_pos, desired_vel, 1.0 / 60.0)
		
		# Nếu bị chặn hoàn toàn theo hướng thẳng (actual_vel == ZERO hoặc quá bé)
		if actual_vel.length() < 5.0:
			# Thử các góc lách (như người chơi lách cần joystick sang trái/phải 45 độ, 90 độ)
			var found_dodge := false
			for angle_deg in [30, -30, 45, -45, 60, -60, 90, -90]:
				var alt_dir := dir.rotated(deg_to_rad(angle_deg))
				var alt_vel := VltkWorld.slide_velocity(cur_pos, alt_dir * 250.0, 1.0 / 60.0)
				if alt_vel.length() > 50.0:
					actual_vel = alt_vel
					found_dodge = true
					break
			if not found_dodge:
				frames_stuck += 1
				if frames_stuck % 30 == 1:
					print("  [CẢN TRỞ] Bị kẹt tại: ", cur_pos, " (cell %d,%d)" % [int(cur_pos.x / 32), int(cur_pos.y / 16)])
					_inspect_cell_around(world, cur_pos)
				if frames_stuck > 90:
					print("  ==> KẸT CỨNG HOÀN TOÀN TẠI: ", cur_pos, " sau %d frames!" % total_frames)
					break
			else:
				frames_stuck = 0
		else:
			frames_stuck = 0
		
		cur_pos += actual_vel * (1.0 / 60.0)
		player.global_position = cur_pos - Vector2(0, VltkWorld.FEET_OFFSET)
		world.map.prepare_around(cur_pos)
		
		if total_frames % 120 == 0:
			print("  Frame %d: Đang tại %s (cách đích %.1fpx)" % [total_frames, str(cur_pos), cur_pos.distance_to(bridge_target)])

	if cur_pos.distance_to(bridge_target) <= 50.0:
		print("\n>>> THÀNH CÔNG: Đã kéo Joystick từ nơi thả tới cầu gỗ! Tọa độ: ", cur_pos)
	else:
		print("\n>>> THẤT BẠI: Không thể tới cầu gỗ, dừng tại: ", cur_pos)
	
	print("==================================================")
	get_tree().quit(0 if cur_pos.distance_to(bridge_target) <= 50.0 else 1)

func _inspect_cell_around(world: VltkWorld, pos: Vector2) -> void:
	var gx := int(pos.x / 32.0)
	var gy := int(pos.y / 16.0)
	print("  Lưới ô quanh (gx=%d, gy=%d):" % [gx, gy])
	for dy in range(-2, 3):
		var line := "   "
		for dx in range(-3, 4):
			var test_p := Vector2((gx + dx) * 32.0 + 16.0, (gy + dy) * 16.0 + 8.0)
			var bl: bool = world.map.is_blocked(test_p)
			line += " X " if bl else " . "
		print(line)

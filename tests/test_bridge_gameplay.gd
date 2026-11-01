extends Node

func _ready() -> void:
	print("==================================================")
	print(">>> KIỂM THỬ THỰC TẾ: DI CHUYỂN QUA CẦU GỖ HOA SƠN")
	print("==================================================")
	call_deferred("_run_test")

func _run_test() -> void:
	var world := VltkWorld.new()
	world.map_dir = "res://world/maps/map_2"
	add_child(world)
	
	# Load player
	var player_scene: PackedScene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	
	world.setup_main_map()
	if world.map:
		world.map.focus = player
	
	# Wait for chunks to load
	player.global_position = Vector2(77450, 58298)
	world.map.prepare_around(Vector2(77450, 58298))
	for i in 25:
		await get_tree().process_frame
	
	# TEST 1: Check blocked status along multiple exit points
	var test_points = [
		Vector2(76780, 57980), # left cliff
		Vector2(77000, 58100), # piece 1
		Vector2(77207, 58202), # user stuck screenshot position!
		Vector2(77350, 58290), # piece 2
		Vector2(77450, 58345),
		Vector2(77500, 58375),
		Vector2(77530, 58395),
		Vector2(77560, 58415),
		Vector2(77580, 58435),
		Vector2(77620, 58450)  # mountain grass!
	]
	print("\n[TEST 1] Kiểm tra va chạm (is_blocked) dọc toàn tuyến cầu gỗ:")
	var all_clear := true
	for pt in test_points:
		var bl := world.map.is_blocked(pt)
		print("  pt: ", pt, " -> is_blocked = ", bl)
		if bl:
			all_clear = false
	print("  => Kết quả: ", "PASS (Thông suốt)" if all_clear else "FAIL")
	
	# TEST 2: Walk from user stuck position (77207, 58202) across bridge to right cliff
	var stuck_pos := Vector2(77207, 58202)
	var end_pos := Vector2(77650, 58450)
	player.global_position = stuck_pos
	world.map.prepare_around(stuck_pos)
	for i in 10:
		await get_tree().process_frame
	
	print("\n[TEST 2] Tự động đi bộ (walk_to_feet) từ đúng vị trí kẹt trong ảnh (302/227) sang mỏm núi...")
	var started: bool = bool(player.walk_to_feet(end_pos))
	print("  walk_to_feet started? ", started)
	var reached := false
	for frame in range(250):
		await get_tree().process_frame
		var cur_feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
		if cur_feet.distance_to(end_pos) < 40.0:
			print("  SUCCESS: Đã bước qua khỏi mép cầu sang mỏm núi! Tọa độ: ", cur_feet, " sau %d frames" % frame)
			reached = true
			break
	if not reached:
		var cur_feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
		print("  FAIL: Kẹt tại: ", cur_feet, " is_blocked=", world.map.is_blocked(cur_feet))
	
	# TEST 3: Full run from left cliff (76780, 57980) to right cliff (77650, 58450)
	print("\n[TEST 3] Chạy toàn tuyến từ đỉnh núi trái sang đỉnh núi phải...")
	var left_start := Vector2(76780, 57980)
	player.global_position = left_start - Vector2(0, VltkWorld.FEET_OFFSET)
	world.map.prepare_around(left_start)
	for i in 20:
		await get_tree().process_frame
	
	var full_started: bool = bool(player.walk_to_feet(end_pos))
	print("  walk_to_feet toàn tuyến started? ", full_started)
	var full_reached := false
	for frame in range(450):
		await get_tree().process_frame
		var cur_feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
		if cur_feet.distance_to(end_pos) < 40.0:
			print("  SUCCESS: Đã chạy toàn bộ cầu từ núi bên này sang núi bên kia! Tọa độ: ", cur_feet, " sau %d frames" % frame)
			full_reached = true
			break
	if not full_reached:
		var cur_feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
		print("  FAIL: Kẹt toàn tuyến tại: ", cur_feet)
	
	# TEST 4: Joystick run across bridge exit onto grass
	print("\n[TEST 4] Mô phỏng chạy cần điều khiển (Joystick slide_velocity) qua mép cầu sang mỏm cỏ...")
	player.global_position = Vector2(77520, 58390) - Vector2(0, VltkWorld.FEET_OFFSET)
	var joy_dir := Vector2(1.0, 0.5).normalized()
	var joy_passed := false
	for frame in range(50):
		await get_tree().process_frame
		var cur_feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
		var desired_vel := joy_dir * 250.0
		var actual_vel: Vector2 = VltkWorld.slide_velocity(cur_feet, desired_vel, 1.0 / 60.0)
		player.global_position += actual_vel * (1.0 / 60.0)
		var new_feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
		if new_feet.x >= 77630.0:
			joy_passed = true
			print("  SUCCESS: Joystick đã đưa nhân vật qua khỏi mép cầu sang bãi cỏ: ", new_feet, " tại frame %d" % frame)
			break
	
	print("\n==================================================")
	if all_clear and reached and full_reached and joy_passed:
		print(">>> TẤT CẢ KIỂM THỬ THỰC TẾ TRONG GODOT ENGINE ĐỀU PASS 100%!")
	else:
		print(">>> CÓ BƯỚC CHƯA ĐẠT!")
	print("==================================================")
	get_tree().quit(0 if (all_clear and reached and full_reached and joy_passed) else 1)

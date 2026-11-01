extends Node

# Kiểm thử toàn diện 9 tuyến đường trên minimap Hoa Sơn (map_2)
# Mỗi tuyến đường gồm các waypoint chính. Test sử dụng thuật toán tìm đường và mô phỏng
# di chuyển slide_velocity trong runtime thực tế của Godot Engine.

const MAP_DIR := "res://world/maps/map_2"

const ROUTES := [
	{
		"name": "Tuyến 1: Spawn -> Ngã ba Nam -> Ngã ba Tây",
		"start": Vector2(77400, 60500),
		"waypoints": [Vector2(76900, 60500), Vector2(75900, 60600)]
	},
	{
		"name": "Tuyến 2: Ngã ba Tây -> Đường rừng Tây -> Bình nguyên Tây Bắc",
		"start": Vector2(75900, 60600),
		"waypoints": [Vector2(74800, 60500), Vector2(74800, 59500), Vector2(74800, 58500), Vector2(75400, 57900)]
	},
	{
		"name": "Tuyến 3: Ngã ba Tây -> Khe núi trung tâm -> Bình nguyên Tây Bắc",
		"start": Vector2(75900, 60600),
		"waypoints": [
			Vector2(76000, 59000),
			Vector2(75980, 58850),
			Vector2(75950, 58710),
			Vector2(75880, 58580),
			Vector2(75800, 58400),
			Vector2(75800, 58000)
		]
	},
	{
		"name": "Tuyến 4: Bình nguyên Tây Bắc -> Đầu cầu bờ Tây",
		"start": Vector2(75800, 58000),
		"waypoints": [Vector2(76800, 58000), Vector2(77450, 58100)]
	},
	{
		"name": "Tuyến 5: Spawn (Quảng trường Nam) -> Đầu cầu bờ Tây (Trục thẳng Bắc-Nam)",
		"start": Vector2(77400, 60500),
		"waypoints": [Vector2(77450, 59500), Vector2(77450, 58100)]
	},
	{
		"name": "Tuyến 6: Toàn bộ sàn Cầu gỗ Hoa Sơn (Bờ Tây -> Bờ Đông)",
		"start": Vector2(77450, 58100),
		"waypoints": [Vector2(77800, 58200), Vector2(78200, 58400), Vector2(78400, 58500)]
	},
	{
		"name": "Tuyến 7: Đầu cầu bờ Đông -> Thác nước hoa đào",
		"start": Vector2(78400, 58500),
		"waypoints": [Vector2(78700, 58550), Vector2(79000, 58600)]
	},
	{
		"name": "Tuyến 8: Thác nước hoa đào -> Đường núi Đông Nam",
		"start": Vector2(79000, 58600),
		"waypoints": [
			Vector2(78800, 58660),
			Vector2(78800, 58900),
			Vector2(78800, 59300),
			Vector2(79000, 59500),
			Vector2(79400, 60200)
		]
	},
	{
		"name": "Tuyến 9: Đầu cầu bờ Đông -> Mỏm đá ngắm cảnh Đông Bắc",
		"start": Vector2(78400, 58500),
		"waypoints": [Vector2(78600, 58200), Vector2(78900, 58000)]
	}
]

func _ready() -> void:
	print("======================================================================")
	print(">>> BẮT ĐẦU KIỂM THỬ RUNTIME: TOÀN BỘ 9 TUYẾN ĐƯỜNG MINIMAP HOA SƠN <<<")
	print("======================================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var world := VltkWorld.new()
	world.map_dir = MAP_DIR
	add_child(world)
	
	var focus_dummy := Node2D.new()
	add_child(focus_dummy)
	
	world.setup_main_map()
	if world.map:
		world.map.focus = focus_dummy
	
	# Đợi map nạp chunk cơ bản
	for i in 20:
		await get_tree().process_frame

	var all_pass := true
	var total_routes := ROUTES.size()
	var passed_count := 0

	for route_idx in range(total_routes):
		var r_data: Dictionary = ROUTES[route_idx]
		var r_name: String = r_data["name"]
		var curr_pos: Vector2 = r_data["start"]
		var waypoints: Array = r_data["waypoints"]
		
		print("\n[%d/%d] Đang kiểm tra: %s" % [route_idx + 1, total_routes, r_name])
		focus_dummy.global_position = curr_pos
		world.map.prepare_around(curr_pos)
		
		# Kiểm tra điểm xuất phát
		if world.map.is_blocked(curr_pos):
			print("  [FAIL] Điểm xuất phát %s bị chặn!" % str(curr_pos))
			all_pass = false
			continue

		var route_ok := true
		for wp_idx in range(waypoints.size()):
			var target_wp: Vector2 = waypoints[wp_idx]
			world.map.prepare_around(target_wp)
			
			if world.map.is_blocked(target_wp):
				print("  [FAIL] Waypoint %d (%s) bị chặn!" % [wp_idx + 1, str(target_wp)])
				route_ok = false
				break
			
			# Mô phỏng di chuyển thực tế từ curr_pos tới target_wp
			var moved_ok := await _simulate_walk(world, focus_dummy, curr_pos, target_wp)
			if not moved_ok:
				print("  [FAIL] Bị nghẽn khi di chuyển từ %s tới Waypoint %d (%s)" % [str(curr_pos), wp_idx + 1, str(target_wp)])
				route_ok = false
				break
			
			curr_pos = target_wp
		
		if route_ok:
			passed_count += 1
			print("  -> PASS: %s hoàn toàn thông thoáng!" % r_name)
		else:
			all_pass = false

	focus_dummy.queue_free()
	world.queue_free()
	
	print("\n======================================================================")
	print("KẾT QUẢ KIỂM THỬ: %d/%d tuyến đường minimap PASS 100%%!" % [passed_count, total_routes])
	print("======================================================================")
	get_tree().quit(0 if all_pass else 1)

func _simulate_walk(world: VltkWorld, focus_node: Node2D, start_pt: Vector2, end_pt: Vector2) -> bool:
	var pos := start_pt
	var delta := 1.0 / 60.0
	var speed := 300.0
	var max_steps := 600
	var steps := 0
	var stuck_count := 0
	
	while pos.distance_to(end_pt) > 40.0 and steps < max_steps:
		steps += 1
		if steps % 10 == 0:
			await get_tree().process_frame
			focus_node.global_position = pos
			world.map.prepare_around(pos)
		
		var dir := (end_pt - pos).normalized()
		var vel := dir * speed
		var actual_vel: Vector2 = VltkWorld.slide_velocity(pos, vel, delta)
		
		# Nếu bị chặn theo hướng thẳng, thử lách 30..60 độ
		if actual_vel.length() < 10.0:
			var dodged := false
			for angle_deg in [30, -30, 45, -45, 60, -60]:
				var alt_dir := dir.rotated(deg_to_rad(angle_deg))
				var alt_vel := VltkWorld.slide_velocity(pos, alt_dir * speed, delta)
				if alt_vel.length() > 50.0:
					actual_vel = alt_vel
					dodged = true
					break
			if not dodged:
				stuck_count += 1
				if stuck_count > 60:
					return false
			else:
				stuck_count = 0
		else:
			stuck_count = 0
		
		pos += actual_vel * delta
	
	focus_node.global_position = pos
	return pos.distance_to(end_pt) <= 50.0

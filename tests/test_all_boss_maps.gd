extends Node

func _ready() -> void:
	print("--- TEST TOÀN BỘ 21 BẢN ĐỒ TAB BOSS ---")
	var boss_list: Array[Dictionary] = [
		{"name": "Huyền Giác Đại Sư", "id": 740, "map_id": 320},
		{"name": "Cổ Bách", "id": 566, "map_id": 123},
		{"name": "Đường Bất Nhiễm", "id": 741, "map_id": 319},
		{"name": "Bạch Doanh Doanh", "id": 742, "map_id": 224},
		{"name": "Lam Y Y", "id": 582, "map_id": 75},
		{"name": "Thanh Tuyệt Sư Thái", "id": 743, "map_id": 321},
		{"name": "Hà Linh Phiêu", "id": 568, "map_id": 322},
		{"name": "Chung Linh Tú", "id": 567, "map_id": 93},
		{"name": "Yên Hiểu Trái", "id": 744, "map_id": 337},
		{"name": "Mạnh Thương Lương", "id": 583, "map_id": 225},
		{"name": "Hắc Nhan Ngô", "id": 745, "map_id": 226},
		{"name": "Gia Luật Tị Ly", "id": 563, "map_id": 227},
		{"name": "Hoàn Nhan Tuyết Y", "id": 564, "map_id": 340},
		{"name": "Đoan Mộc Duệ", "id": 565, "map_id": 124},
		{"name": "Đạo Thanh Chân Nhân", "id": 562, "map_id": 321},
		{"name": "Tôn Tự Nam", "id": 746, "map_id": 322},
		{"name": "Tuyền Cơ Tử", "id": 747, "map_id": 340},
		{"name": "Diệu Như", "id": 513, "map_id": 162},
		{"name": "Liễu Thanh Thanh", "id": 523, "map_id": 11},
		{"name": "Trương Tông Chính", "id": 511, "map_id": 9},
		{"name": "Độc Cô Cầu Kiếm", "id": 1038, "map_id": 480}
	]

	var fail_count: int = 0
	for b: Dictionary in boss_list:
		var mid: int = int(b["map_id"])
		var mdir: String = "res://world/maps/map_%d" % mid
		if not DirAccess.dir_exists_absolute(mdir):
			print("FAIL: Boss [%s] Map %d không tồn tại thư mục!" % [b["name"], mid])
			fail_count += 1
			continue
		var grid: MapGrid = MapGrid.load_from(mdir)
		if grid == null:
			print("FAIL: Boss [%s] Map %d không nạp được MapGrid!" % [b["name"], mid])
			fail_count += 1
			continue
		var center: Vector2 = grid.default_center()
		var boss_pos: Vector2 = grid.open_spawn_near(center)
		var player_pos: Vector2 = grid.open_spawn_near(center + Vector2(0, 320.0))
		if player_pos == Vector2.ZERO:
			player_pos = grid.open_spawn_near(center + Vector2(-1600.0, -1000.0))
			if player_pos == Vector2.ZERO:
				player_pos = grid.open_spawn_near(center)

		var c_boss: Vector2i = grid.world_to_cell(boss_pos)
		var c_player: Vector2i = grid.world_to_cell(player_pos)
		var boss_solid: bool = (grid._value(c_boss) >> 4) != 0
		var player_solid: bool = (grid._value(c_player) >> 4) != 0

		if boss_pos == Vector2.ZERO or boss_solid or player_pos == Vector2.ZERO or player_solid:
			print("FAIL: Boss [%s] Map %d: boss_pos=%s (solid=%s), player_pos=%s (solid=%s)" % [
				b["name"], mid, str(boss_pos), str(boss_solid), str(player_pos), str(player_solid)
			])
			fail_count += 1
		else:
			var b_disp := "%d/%d" % [int(boss_pos.x / 256.0), int(boss_pos.y / 256.0)]
			var p_disp := "%d/%d" % [int(player_pos.x / 256.0), int(player_pos.y / 256.0)]
			print("OK: Boss [%s] Map %d: Boss=(%s) Player=(%s)" % [b["name"], mid, b_disp, p_disp])

	print("--- KẾT QUẢ: %d lỗi ---" % fail_count)
	get_tree().quit(fail_count)

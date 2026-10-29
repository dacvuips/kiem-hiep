extends Node

const BOSS_LIST := [
	{"name": "Huyền Giác Đại Sư", "id": 740, "map_id": 320},
	{"name": "Cổ Bách", "id": 566, "map_id": 123},
	{"name": "Đường Bất Nhiễm", "id": 741, "map_id": 319},
	{"name": "Bạch Doanh Doanh", "id": 742, "map_id": 224},
	{"name": "Lam Y Y", "id": 582, "map_id": 75},
	{"name": "Thanh Tiếu Sư Thái", "id": 743, "map_id": 321},
	{"name": "Hà Linh Phiêu", "id": 568, "map_id": 322},
	{"name": "Chung Linh Tú", "id": 567, "map_id": 93},
	{"name": "Yên Hiểu Trái", "id": 744, "map_id": 337},
	{"name": "Mạnh Thương Lương", "id": 583, "map_id": 225},
	{"name": "Hà Nhân Ngã", "id": 745, "map_id": 226},
	{"name": "Gia Luật Tị Ly", "id": 563, "map_id": 227},
	{"name": "Hoàn Nhan Tuyết Y", "id": 564, "map_id": 340},
	{"name": "Đoan Mộc Duệ", "id": 565, "map_id": 124},
	{"name": "Đạo Thanh Chân Nhân", "id": 562, "map_id": 321},
	{"name": "Sơn Tư Nam", "id": 746, "map_id": 322},
	{"name": "Tuyền Cơ Tử", "id": 747, "map_id": 340},
	{"name": "Diệu Như", "id": 513, "map_id": 162},
	{"name": "Liễu Thanh Thanh", "id": 523, "map_id": 11},
	{"name": "Trương Tông Chính", "id": 511, "map_id": 9},
	{"name": "Độc Cô Cầu Kiếm", "id": 1038, "map_id": 480}
]

func _ready() -> void:
	print("=== KIỂM TRA ĐƯỜNG ĐI (PATHFINDING) TỪ VỊ TRÍ SPAWN ĐẾN BOSS TRÊN 21 MAP ===")
	var total_tested: int = 0
	var trapped_spawns: int = 0

	for b: Dictionary in BOSS_LIST:
		var mid: int = int(b["map_id"])
		var mdir: String = "res://world/maps/map_%d" % mid
		var grid: MapGrid = MapGrid.load_from(mdir)
		if grid == null:
			continue

		var center: Vector2 = grid.default_center()
		var boss_pos: Vector2 = grid.open_spawn_near(center)
		if boss_pos == Vector2.ZERO:
			boss_pos = center

		var map_file := "%s/map.json" % mdir
		var fa := FileAccess.open(map_file, FileAccess.READ)
		var mdata: Dictionary = JSON.parse_string(fa.get_as_text())
		var rect: Array = mdata.get("rect", [0, 0, 1, 1])
		var span_x: float = (float(rect[2]) - float(rect[0]) + 1.0) * 512.0
		var span_y: float = (float(rect[3]) - float(rect[1]) + 1.0) * 512.0
		var dx := clampf(span_x * 0.38, 1500.0, 2200.0)
		var dy := clampf(span_y * 0.38, 1000.0, 1600.0)

		# Các vị trí spawn có thể xảy ra:
		# 1. Server spawn (center + (0, 320))
		# 2. 4 corners trong vltk_world
		var test_targets: Array[Dictionary] = [
			{"name": "Server Spawn", "pos": grid.open_spawn_near(center + Vector2(0, 320.0))},
			{"name": "Server Fallback", "pos": grid.open_spawn_near(center + Vector2(-1600.0, -1000.0))},
			{"name": "Corner NW", "pos": grid.open_spawn_near(center + Vector2(-dx, -dy))},
			{"name": "Corner NE", "pos": grid.open_spawn_near(center + Vector2(dx, -dy))},
			{"name": "Corner SW", "pos": grid.open_spawn_near(center + Vector2(-dx, dy))},
			{"name": "Corner SE", "pos": grid.open_spawn_near(center + Vector2(dx, dy))},
		]

		var cb: Vector2i = grid.world_to_cell(boss_pos)

		for t in test_targets:
			var p_pos: Vector2 = t["pos"]
			if p_pos == Vector2.ZERO:
				continue
			var cp: Vector2i = grid.world_to_cell(p_pos)
			var solid: bool = (grid._value(cp) >> 4) != 0
			if solid:
				print("BỊ KẸT (SOLID): Boss [%s] Map %d tại %s (%s, solid=true)" % [b["name"], mid, t["name"], p_pos])
				trapped_spawns += 1
				continue

			# Flood fill từ cp xem đi được bao nhiêu ô
			var visited := {}
			var queue: Array[Vector2i] = [cp]
			visited[cp] = true
			var can_reach_boss: bool = false

			while not queue.is_empty() and visited.size() < 1000:
				var curr: Vector2i = queue.pop_front()
				if curr == cb or curr.distance_squared_to(cb) <= 4:
					can_reach_boss = true
					break
				for n in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
						  Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var next_c: Vector2i = curr + n
					if visited.has(next_c):
						continue
					if (grid._value(next_c) >> 4) == 0:
						visited[next_c] = true
						queue.append(next_c)

			total_tested += 1
			if visited.size() < 30 and not can_reach_boss:
				print("BỊ KẸT TRONG HỐ NHỎ: Boss [%s] Map %d tại %s (pos=%s, chỉ đi được %d ô!)" % [
					b["name"], mid, t["name"], p_pos, visited.size()
				])
				trapped_spawns += 1
			elif not can_reach_boss:
				print("KHÔNG THẤY ĐƯỜNG TỚI BOSS: Boss [%s] Map %d tại %s (pos=%s, flood_size=%d)" % [
					b["name"], mid, t["name"], p_pos, visited.size()
				])
			else:
				# Thành công
				pass

	print("=== HOÀN TẤT KIỂM TRA: Đã test %d điểm spawn, Bị kẹt: %d điểm ===" % [total_tested, trapped_spawns])
	get_tree().quit(trapped_spawns)

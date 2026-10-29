extends Node

const BOSS_LIST := [
	{"name": "Huyền Giác Đại Sư", "id": 740, "res": "boss003", "series": "Kim", "series_idx": 0, "sect": "Thiếu Lâm", "level": 95, "map_id": 320, "map_name": "Chân Núi Trường Bạch", "type": "gold"},
	{"name": "Cổ Bách", "id": 566, "res": "boss018", "series": "Kim", "series_idx": 0, "sect": "Thiên Vương", "level": 95, "map_id": 123, "map_name": "Lão Hổ Động", "type": "gold"},
	{"name": "Đường Bất Nhiễm", "id": 741, "res": "boss019", "series": "Mộc", "series_idx": 1, "sect": "Đường Môn", "level": 95, "map_id": 319, "map_name": "Lâm Du Quan", "type": "gold"},
	{"name": "Bạch Doanh Doanh", "id": 742, "res": "boss007", "series": "Mộc", "series_idx": 1, "sect": "Đường Môn", "level": 95, "map_id": 224, "map_name": "Sa Mạc Địa Biểu", "type": "gold"},
	{"name": "Lam Y Y", "id": 582, "res": "boss008", "series": "Mộc", "series_idx": 1, "sect": "Ngũ Độc", "level": 95, "map_id": 75, "map_name": "Xi Vưu Động", "type": "gold"},
	{"name": "Thanh Tiếu Sư Thái", "id": 743, "res": "boss004", "series": "Thủy", "series_idx": 2, "sect": "Nga Mi", "level": 95, "map_id": 321, "map_name": "Trường Bạch Sơn Nam", "type": "gold"},
	{"name": "Hà Linh Phiêu", "id": 568, "res": "boss002", "series": "Thủy", "series_idx": 2, "sect": "Nga Mi", "level": 95, "map_id": 322, "map_name": "Trường Bạch Sơn Bắc", "type": "gold"},
	{"name": "Chung Linh Tú", "id": 567, "res": "boss005", "series": "Thủy", "series_idx": 2, "sect": "Thúy Yên", "level": 95, "map_id": 93, "map_name": "Tiến Cúc Động", "type": "gold"},
	{"name": "Yên Hiểu Trái", "id": 744, "res": "boss023", "series": "Thủy", "series_idx": 2, "sect": "Thúy Yên", "level": 95, "map_id": 337, "map_name": "Thuyền Phong Lăng Độ", "type": "gold"},
	{"name": "Mạnh Thương Lương", "id": 583, "res": "boss012", "series": "Hỏa", "series_idx": 3, "sect": "Cái Bang", "level": 95, "map_id": 225, "map_name": "Sa Mạc Sơn Động 1", "type": "gold"},
	{"name": "Hà Nhân Ngã", "id": 745, "res": "boss013", "series": "Hỏa", "series_idx": 3, "sect": "Cái Bang", "level": 95, "map_id": 226, "map_name": "Sa Mạc Sơn Động 2", "type": "gold"},
	{"name": "Gia Luật Tị Ly", "id": 563, "res": "boss011", "series": "Hỏa", "series_idx": 3, "sect": "Thiên Nhẫn", "level": 95, "map_id": 227, "map_name": "Sa Mạc Sơn Động 3", "type": "gold"},
	{"name": "Hoàn Nhan Tuyết Y", "id": 564, "res": "boss014", "series": "Hỏa", "series_idx": 3, "sect": "Thiên Nhẫn", "level": 95, "map_id": 340, "map_name": "Mạc Cao Quật", "type": "gold"},
	{"name": "Đoan Mộc Duệ", "id": 565, "res": "boss015", "series": "Hỏa", "series_idx": 3, "sect": "Thiên Nhẫn", "level": 95, "map_id": 124, "map_name": "Hiên Viên Động", "type": "gold"},
	{"name": "Đạo Thanh Chân Nhân", "id": 562, "res": "boss001", "series": "Thổ", "series_idx": 4, "sect": "Võ Đang", "level": 95, "map_id": 321, "map_name": "Trường Bạch Sơn Nam", "type": "gold"},
	{"name": "Sơn Tư Nam", "id": 746, "res": "boss022", "series": "Thổ", "series_idx": 4, "sect": "Côn Lôn", "level": 95, "map_id": 322, "map_name": "Trường Bạch Sơn Bắc", "type": "gold"},
	{"name": "Tuyền Cơ Tử", "id": 747, "res": "boss017", "series": "Thổ", "series_idx": 4, "sect": "Côn Lôn", "level": 95, "map_id": 340, "map_name": "Mạc Cao Quật", "type": "gold"},
	{"name": "Diệu Như", "id": 513, "res": "enemy056", "series": "Thủy", "series_idx": 2, "sect": "Nga Mi", "level": 100, "map_id": 162, "map_name": "Đại Lý Phủ", "type": "small_gold"},
	{"name": "Liễu Thanh Thanh", "id": 523, "res": "enemy173", "series": "Mộc", "series_idx": 1, "sect": "Thúy Yên", "level": 100, "map_id": 11, "map_name": "Thành Đô", "type": "small_gold"},
	{"name": "Trương Tông Chính", "id": 511, "res": "enemy003", "series": "Thổ", "series_idx": 4, "sect": "Côn Lôn", "level": 100, "map_id": 9, "map_name": "Trường Giang Đầu Nguồn", "type": "small_gold"},
	{"name": "Độc Cô Cầu Kiếm", "id": 1038, "res": "boss015", "series": "Kim", "series_idx": 0, "sect": "Vượt Ải", "level": 100, "map_id": 480, "map_name": "Thách Thức Ải 28", "type": "challenge"}
]

func _ready() -> void:
	print("=== KIỂM TRA CORNER SPAWN & VỊ TRÍ BOSS TRÊN TẤT CẢ 21 MAP BOSS ===")
	var errors: int = 0

	for b: Dictionary in BOSS_LIST:
		var mid: int = int(b["map_id"])
		var mdir: String = "res://world/maps/map_%d" % mid
		var grid: MapGrid = MapGrid.load_from(mdir)
		if grid == null:
			print("ERR: Map %d không load được MapGrid!" % mid)
			errors += 1
			continue

		var center: Vector2 = grid.default_center()
		var boss_pos: Vector2 = grid.open_spawn_near(center)
		if boss_pos == Vector2.ZERO:
			boss_pos = center

		# Kiểm tra boss_pos có bị solid không
		var cb: Vector2i = grid.world_to_cell(boss_pos)
		var b_solid: bool = (grid._value(cb) >> 4) != 0

		# Giả lập get_corner_spawn_positions như vltk_world.gd
		var map_file := "%s/map.json" % mdir
		var fa := FileAccess.open(map_file, FileAccess.READ)
		var mdata: Dictionary = JSON.parse_string(fa.get_as_text())
		var rect: Array = mdata.get("rect", [0, 0, 1, 1])
		var span_x: float = (float(rect[2]) - float(rect[0]) + 1.0) * 512.0
		var span_y: float = (float(rect[3]) - float(rect[1]) + 1.0) * 512.0
		var dx := clampf(span_x * 0.38, 1500.0, 2200.0)
		var dy := clampf(span_y * 0.38, 1000.0, 1600.0)

		var corner_offsets: Array[Vector2] = [
			Vector2(-dx, -dy),
			Vector2(dx, -dy),
			Vector2(-dx, dy),
			Vector2(dx, dy),
		]

		var valid_corners: Array[Vector2] = []
		for off in corner_offsets:
			var target := center + off
			var pos: Vector2 = grid.open_spawn_near(target)
			if pos != Vector2.ZERO and pos.distance_to(center) >= 500.0:
				var cp: Vector2i = grid.world_to_cell(pos)
				var is_solid: bool = (grid._value(cp) >> 4) != 0
				if not is_solid:
					valid_corners.append(pos)

		var b_disp := "%d/%d" % [int(boss_pos.x / 256.0), int(boss_pos.y / 256.0)]
		if b_solid:
			print("FAIL: Boss [%s] Map %d: Boss đứng trong vật cản! Pos=%s (disp %s)" % [b["name"], mid, boss_pos, b_disp])
			errors += 1
		elif valid_corners.is_empty():
			# Thử fallback
			var fb := grid.open_spawn_near(center + Vector2(0, 320.0))
			if fb == Vector2.ZERO:
				fb = grid.open_spawn_near(center + Vector2(-1600.0, -1000.0))
			print("WARN: Boss [%s] Map %d: Không tìm thấy corner nào! Fallback=%s" % [b["name"], mid, fb])
		else:
			print("OK: Boss [%s] Map %d: Boss=(%s, solid=%s), Valid corners=%d/4" % [
				b["name"], mid, b_disp, b_solid, valid_corners.size()
			])

	print("=== HOÀN TẤT: %d lỗi ===" % errors)
	get_tree().quit(errors)

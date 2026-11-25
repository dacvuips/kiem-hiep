extends SceneTree

func _init() -> void:
	print("==================================================")
	print(">>> KIỂM TRA ĐIỂM XUẤT HIỆN MẬT ĐẠO NHA MÔN (MAP 79)")
	print("==================================================")
	var ok := _test_spawn()
	if ok:
		print("==================================================")
		print(">>> KIỂM TRA THÀNH CÔNG: TỌA ĐỘ CHÍNH XÁC 209/196!")
		print("==================================================")
		quit(0)
	else:
		push_error("Kiểm tra thất bại!")
		quit(1)

func _test_spawn() -> bool:
	var map_dir := "res://world/maps/map_79"

	# 1. Kiểm tra MapCatalog
	var cat_entry := MapCatalog.get_by_id(79)
	if cat_entry.is_empty():
		push_error("Không tìm thấy map 79 trong MapCatalog")
		return false
	print("1. MapCatalog entry: ", cat_entry.get("name"))
	print("   arena_center = ", cat_entry.get("arena_center"))
	print("   start = ", cat_entry.get("start"))

	var ac: Array = cat_entry.get("arena_center", [])
	if ac.size() < 2 or int(ac[0]) != 53632 or int(ac[1]) != 50304:
		push_error("MapCatalog arena_center không đúng [53632, 50304]")
		return false

	# 2. Kiểm tra map.json
	var grid := MapGrid.load_from(map_dir)
	if grid == null:
		push_error("Không thể tải MapGrid từ %s" % map_dir)
		return false

	var def_c: Vector2 = grid.default_center()
	print("2. MapGrid default_center = ", def_c)
	if int(def_c.x) != 53632 or int(def_c.y) != 50304:
		push_error("default_center không khớp (53632, 50304)")
		return false

	# 3. Tính điểm spawn thông thoáng
	var spawn_pos: Vector2 = grid.open_spawn_near(def_c)
	var coord_x: int = floori(spawn_pos.x / 256.0)
	var coord_y: int = floori(spawn_pos.y / 256.0)
	print("3. Điểm spawn thực tế = ", spawn_pos)
	print("   Tọa độ hiển thị trên MiniMap = %d/%d" % [coord_x, coord_y])

	if coord_x != 209 or coord_y != 196:
		push_error("Tọa độ spawn không đúng 209/196! Thực tế: %d/%d" % [coord_x, coord_y])
		return false

	# 4. Kiểm tra ô đó có bị chặn không
	var cell: Vector2i = grid.world_to_cell(spawn_pos)
	var val: int = grid._value(cell)
	var blocked: bool = (val >> 4) != 0
	print("4. Cell: %s, Cell value: %d, Bị chặn: %s" % [str(cell), val, str(blocked)])
	if blocked:
		push_error("Điểm spawn bị chặn vật cản!")
		return false

	return true

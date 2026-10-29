extends Node

func _ready() -> void:
	print("==================================================")
	print(">>> BẮT ĐẦU KIỂM THỬ THỰC TẾ BẢN ĐỒ HOA SƠN (MAP 2)")
	print("==================================================")
	var ok: bool = await _run_all_tests()
	if ok:
		print("==================================================")
		print(">>> TẤT CẢ KIỂM THỬ THỰC TẾ ĐỀU PASS 100%!")
		print("==================================================")
		get_tree().quit(0)
	else:
		push_error("Kiểm thử thất bại!")
		get_tree().quit(1)

func _run_all_tests() -> bool:
	var map_dir: String = "res://world/maps/map_2"

	# 1. Kiểm tra các file thiết yếu của map 2
	print("[1/6] Kiểm tra tệp tin bản đồ map_2...")
	var required_files: Array[String] = [
		"map.json",
		"chunks/4_3.json.gz",
		"spawns.json.gz",
		"nav_graph.bin",
		"minimap.jpg",
		"minimap_npc.jpg",
		"manifest.json",
		"atlas/atlas.json"
	]
	for rf: String in required_files:
		var p: String = map_dir.path_join(rf)
		if not FileAccess.file_exists(p):
			push_error("Thiếu file: %s" % p)
			return false
	print("  -> PASS: Đầy đủ tất cả 8 tệp tin cốt lõi.")

	# 2. Kiểm tra map_catalog.json
	print("[2/6] Kiểm tra danh mục MapCatalog...")
	var cat_path: String = "res://data/maps/map_catalog.json"
	if not FileAccess.file_exists(cat_path):
		push_error("Không tìm thấy map_catalog.json")
		return false
	var cat_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(cat_path))
	if not (cat_raw is Dictionary and (cat_raw as Dictionary).has("maps")):
		push_error("map_catalog.json sai định dạng")
		return false
	var found_entry: Dictionary = {}
	for m: Variant in (cat_raw as Dictionary)["maps"]:
		var md: Dictionary = m as Dictionary
		if int(md.get("id", 0)) == 2:
			found_entry = md
			break
	if found_entry.is_empty():
		push_error("Không tìm thấy map id 2 trong catalog")
		return false
	var cat_ac: Array = found_entry.get("arena_center", [])
	if cat_ac.size() < 2 or int(cat_ac[0]) != 77400 or int(cat_ac[1]) != 60500:
		push_error("Catalog arena_center sai: %s (kỳ vọng [77400, 60500])" % str(cat_ac))
		return false
	print("  -> PASS: MapCatalog Hoa Sơn có arena_center = [77400, 60500] (302/236).")

	# 3. Kiểm tra nạp MapGrid & Tọa độ xuất hiện (Spawn)
	print("[3/6] Kiểm tra nạp MapGrid & điểm spawn thực tế...")
	var grid: MapGrid = MapGrid.load_from(map_dir)
	if grid == null:
		push_error("Không thể load MapGrid từ %s" % map_dir)
		return false
	
	var default_c: Vector2 = grid.default_center()
	print("  -> default_center = Vector2(%d, %d)" % [int(default_c.x), int(default_c.y)])
	if int(default_c.x) != 77400 or int(default_c.y) != 60500:
		push_error("default_center sai: %s" % str(default_c))
		return false

	var spawn_pos: Vector2 = grid.open_spawn_near(default_c)
	var disp_x: int = int(spawn_pos.x / 256.0)
	var disp_y: int = int(spawn_pos.y / 256.0)
	print("  -> open_spawn_near(%s) = %s -> Tọa độ hiển thị: %d/%d" % [str(default_c), str(spawn_pos), disp_x, disp_y])
	
	if disp_x != 302 or disp_y != 236:
		push_error("Điểm spawn không đúng 302/236! Thực tế: %d/%d" % [disp_x, disp_y])
		return false

	var cell: Vector2i = grid.world_to_cell(spawn_pos)
	var val: int = grid._value(cell)
	if (val >> 4) != 0:
		push_error("Điểm spawn nằm trong vật cản! Giá trị cell: %d" % val)
		return false
	print("  -> PASS: Điểm xuất hiện %d/%d là mặt đất thông thoáng (cell value = %d)." % [disp_x, disp_y, val])

	# 4. Kiểm tra khả năng di chuyển tự do xung quanh điểm xuất hiện
	print("[4/6] Kiểm tra khả năng di chuyển 8 hướng từ điểm xuất hiện...")
	var dirs: Array[Vector2] = [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)
	]
	var open_dirs: int = 0
	for d: Vector2 in dirs:
		var target: Vector2 = spawn_pos + d * 64.0
		var c_target: Vector2i = grid.world_to_cell(target)
		if (grid._value(c_target) >> 4) == 0:
			open_dirs += 1
	print("  -> 8 hướng quanh điểm spawn có %d/8 hướng hoàn toàn thông thoáng." % open_dirs)
	if open_dirs < 6:
		push_error("Xung quanh điểm spawn bị bao vây bởi vật cản!")
		return false

	# Kiểm tra hốc bẫy cũ tại 302/232 (77376, 59456) đã được đóng kín
	var old_trap_cell: Vector2i = grid.world_to_cell(Vector2(77376, 59456))
	var old_trap_val: int = grid._value(old_trap_cell)
	if (old_trap_val >> 4) == 0:
		push_error("Hốc bẫy cũ tại 302/232 vẫn chưa được vá kín!")
		return false
	print("  -> PASS: Hốc bẫy kẹt đá cũ tại 302/232 đã bịt kín (cell value = %d)." % old_trap_val)

	# 5. Kiểm tra StageData Ải 2
	print("[5/6] Kiểm tra StageData stage_02.tres (Vượt Ải)...")
	var stage_res: Variant = load("res://stages/stage_02/stage_02.tres")
	if stage_res == null:
		push_error("Không load được stage_02.tres")
		return false
	var st: StageData = stage_res as StageData
	if st.vltk_map_id != 2:
		push_error("stage_02.tres vltk_map_id != 2")
		return false
	if int(st.arena_center.x) != 77400 or int(st.arena_center.y) != 60500:
		push_error("stage_02.tres arena_center != (77400, 60500), thực tế: %s" % str(st.arena_center))
		return false
	print("  -> PASS: stage_02.tres khớp chính xác vltk_map_id=2 và arena_center=(77400, 60500).")

	# 6. Mô phỏng di chuyển thực tế với VltkWorld & slide_velocity
	print("[6/6] Mô phỏng di chuyển thực tế (Gameplay Movement Simulation)...")
	var world := VltkWorld.new()
	world.map_dir = map_dir
	add_child(world)
	world.setup_stage(st)
	
	# Đợi map nạp chunk
	await get_tree().process_frame
	await get_tree().process_frame

	var test_feet: Vector2 = spawn_pos
	var speed: float = 200.0
	var delta: float = 0.05 # 50ms
	
	for move_dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var vel: Vector2 = move_dir * speed
		var slide: Vector2 = VltkWorld.slide_velocity(test_feet, vel, delta)
		if slide.length_squared() < 1.0:
			push_error("Nhân vật bị chặn không thể di chuyển theo hướng: %s" % str(move_dir))
			world.queue_free()
			return false
		test_feet += slide * delta

	var end_disp_x: int = int(test_feet.x / 256.0)
	var end_disp_y: int = int(test_feet.y / 256.0)
	print("  -> Di chuyển thử nghiệm thành công 4 hướng. Vị trí cuối: %s (Tọa độ: %d/%d)" % [str(test_feet), end_disp_x, end_disp_y])
	print("  -> PASS: Nhân vật di chuyển mượt mà trên nền đất, không bị kẹt hay khựng lại.")

	world.queue_free()
	return true

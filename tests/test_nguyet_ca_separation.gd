extends SceneTree

func _init() -> void:
	print("--- KIỂM TRA PHÂN TÁCH BẢN ĐỒ NGUYỆT CA ĐẢO (VƯỢT ẢI - LUYỆN vs SƠN TRANG) ---")

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		var gm_script = load("res://systems/game_manager.gd")
		gm = gm_script.new()
		root.add_child(gm)

	# 1. Giả lập vào Nguyệt Ca Đảo từ Vượt Ải -> Luyện (MapCatalog cấp 12x)
	var luyen_entry: Dictionary = {
		"id": 1041,
		"name": "Nguyệt Ca Đảo (12x)",
		"kind": "Field",
		"level": 120,
		"monster_count": 521,
		"dir": "res://world/maps/map_1041"
	}
	gm.field_map = luyen_entry

	assert(gm.is_manor_mode() == false, "Vào từ Vượt Ải - Luyện thì is_manor_mode() PHẢI là false")
	assert(luyen_entry.get("manor", false) == false, "Vượt Ải - Luyện không được kích hoạt manor")
	print("  [PASS] Vượt Ải - Luyện (Nguyệt Ca Đảo 12x): is_manor_mode = false (Không kích hoạt công trình / NPC Sơn Trang)")

	# 2. Giả lập vào Nguyệt Ca Đảo từ nút Sơn Trang (CharacterHub)
	var son_trang_entry: Dictionary = {
		"id": 1041,
		"name": "Nguyệt Ca Đảo",
		"title": "Nguyệt Ca Đảo",
		"kind": "Field",
		"dir": "res://world/maps/map_1041",
		"start": [90, 91],
		"arena_center": [46464, 46976],
		"no_monsters": true,
		"manor": true,
		"monster_count": 0,
		"monsters": []
	}
	gm.field_map = son_trang_entry

	assert(gm.is_manor_mode() == true, "Vào từ nút Sơn Trang thì is_manor_mode() PHẢI là true")
	assert(son_trang_entry.get("manor", false) == true, "Nút Sơn Trang kích hoạt manor = true")
	print("  [PASS] Sơn Trang (Manor): is_manor_mode = true (Kích hoạt đầy đủ công trình, NPC và tính năng Sơn Trang)")

	print("--- TẤT CẢ KIỂM TRA ĐỀU CHÍNH XÁC (100%) ---")
	quit(0)

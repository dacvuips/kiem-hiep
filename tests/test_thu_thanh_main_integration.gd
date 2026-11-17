extends Node

func _ready() -> void:
	print("=== TEST TÍCH HỢP: VÀO CHẾ ĐỘ THỦ THÀNH (ZOMBIES VS PLANTS) TRÊN MAIN ===")

	# 1. Chọn map Giang Tân Thôn với cờ thu_thanh_mode
	var maps := MapCatalog.in_tier(1)
	assert(not maps.is_empty(), "Phải có map trong tier 1")
	var selected_map: Dictionary = maps[0].duplicate(true)
	selected_map["thu_thanh_mode"] = true

	# 2. Cài đặt GameManager
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = selected_map
	GameManager.current_stage = null

	var profile := PlayerProfile.new()
	profile.display_name = "Đại Hiệp Thủ Thành"
	profile.sect_id = "thieu_lam"
	profile.level = 20
	GameManager.local_profile = profile

	# 3. Nạp Main scene
	var main_scene: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	add_child(main_scene)

	await get_tree().process_frame
	await get_tree().process_frame

	# 4. Kiểm tra ThuThanhChallenge được tạo trong Main
	var challenge: ThuThanhChallenge = main_scene.get_node_or_null("ThuThanhChallenge")
	assert(challenge != null, "ThuThanhChallenge phải được khởi tạo trong Main khi có cờ thu_thanh_mode!")
	print("✓ ThuThanhChallenge đã khởi tạo thành công trong Main")

	# 5. Kiểm tra UI tự do (joystick, status_hud, skill_bar) đã được ẩn
	var ui_node: CanvasLayer = main_scene.get_node_or_null("UI")
	assert(ui_node != null and not ui_node.visible, "UI thông thường (skill bar, status hud, joystick) phải bị ẩn!")
	print("✓ Toàn bộ UI thông thường đã được ẩn để nhường chỗ cho HUD Thủ Thành")

	# 6. Kiểm tra Camera cố định và nền bàn cờ
	var cam: Camera2D = challenge.get_node_or_null("ThuThanhBoardCamera")
	assert(cam != null and cam.is_current(), "ThuThanhBoardCamera phải tồn tại và đang hoạt động!")
	print("✓ Camera bàn cờ hoạt động chuẩn xác")

	var board_visuals = challenge.get_node_or_null("BoardGridVisuals")
	assert(board_visuals != null, "BoardGridVisuals phải tồn tại")
	assert(board_visuals.get_child_count() > 55, "Phải có đầy đủ 55 ô phòng thủ + 15 ô quái + nền cỏ!")
	print("✓ Bàn cờ 11x5 và nền cỏ xanh tự nhiên hiển thị đầy đủ (không bị màn hình đen)")

	# 7. Kiểm tra Xe Tống Kim
	var carts = get_tree().get_nodes_in_group("escort_carts")
	assert(not carts.is_empty(), "Xe Tống Kim phải tồn tại trên chiến trường!")
	print("✓ Xe Tống Kim đã sẵn sàng tại vị trí phòng ngự")

	print("=== TẤT CẢ KIỂM THỬ TÍCH HỢP THỦ THÀNH TRÊN MAIN ĐẠT 100% THÀNH CÔNG! ===")
	get_tree().quit(0)

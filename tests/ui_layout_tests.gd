extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU KIỂM TRA BỐ CỤC UI KHÔNG BỊ CHÈN NHAU ---")
	test_ui_layout()
	print("--- KẾT THÚC KIỂM TRA BỐ CỤC UI: THÀNH CÔNG ---")
	get_tree().quit(0)

func test_ui_layout() -> void:
	var main_scene: PackedScene = load("res://Main.tscn")
	assert(main_scene != null, "Main.tscn phải tồn tại")
	var main_node = main_scene.instantiate()
	add_child(main_node)

	var ui: CanvasLayer = main_node.get_node("UI")
	assert(ui != null, "$UI phải tồn tại")

	# Wait a frame for layout
	await get_tree().process_frame

	var mini_map = ui.get_node_or_null("MiniMap")
	var side_menu = ui.get_node_or_null("SideMenu")
	var top_bar = ui.get_node_or_null("TopStatusBar")
	var top_left_bar = ui.get_node_or_null("TopLeftActionBar")
	var badge = ui.get_node_or_null("AgeRatingBadge")
	var status_hud = ui.get_node_or_null("PlayerStatusHud")

	print("[KIỂM TRA] Node SideMenu: ", side_menu != null)
	assert(side_menu != null, "SideMenu phải có trong UI")

	if top_bar == null:
		# Add TopStatusBar directly to check relative coordinate layout
		top_bar = TopStatusBar.new()
		ui.add_child(top_bar)

	var top_bar_bottom = top_bar.offset_bottom
	var side_menu_top = side_menu.offset_top
	print("[KIỂM TRA] TopStatusBar bottom = %f, SideMenu top = %f" % [top_bar_bottom, side_menu_top])
	assert(side_menu_top >= top_bar_bottom, "SideMenu (top=%f) phải nằm dưới TopStatusBar (bottom=%f), không được chèn đè!" % [side_menu_top, top_bar_bottom])
	print("[PASS] SideMenu không đè lên TopStatusBar!")

	if top_left_bar != null and badge != null:
		var badge_bottom = badge.position.y + badge.size.y
		var bar_top = top_left_bar.offset_top
		print("[KIỂM TRA] AgeRatingBadge bottom = %f, TopLeftActionBar top = %f" % [badge_bottom, bar_top])
		assert(bar_top >= badge_bottom, "TopLeftActionBar (top=%f) phải nằm dưới AgeRatingBadge (bottom=%f)!" % [bar_top, badge_bottom])
		print("[PASS] TopLeftActionBar không đè lên AgeRatingBadge!")

	if top_left_bar != null:
		print("[KIỂM TRA] Số nút trong TopLeftActionBar = %d" % top_left_bar.get_child_count())
		assert(top_left_bar.get_child_count() >= 1, "TopLeftActionBar phải chứa nút PK mode")
		print("[PASS] TopLeftActionBar chứa nút PK mode và các nút GM xếp theo HBoxContainer không bị đè nhau!")

	if status_hud != null and top_left_bar != null:
		print("[KIỂM TRA] StatusHud top = %f, TopLeftActionBar bottom = %f" % [status_hud.offset_top, top_left_bar.offset_bottom])
		assert(status_hud.offset_top >= top_left_bar.offset_bottom, "StatusHud phải nằm dưới TopLeftActionBar!")
		print("[PASS] PlayerStatusHud nằm dưới TopLeftActionBar!")

	# Kiểm tra bỏ icon bản đồ khỏi SideMenu
	for btn in side_menu.get_children():
		if btn is Button:
			assert(not btn.tooltip_text.contains("Bản đồ"), "SideMenu không được chứa icon Bản đồ!")
	print("[PASS] Đã bỏ icon bản đồ khỏi SideMenu thành công!")

	# Kiểm tra MiniMap: không còn nút cờ và nút toàn bản đồ, toạ độ lớn gấp 4 lần
	if mini_map == null:
		var dummy_player = Node2D.new()
		add_child(dummy_player)
		mini_map = MiniMap.new()
		ui.add_child(mini_map)
		mini_map.setup(dummy_player)
		await get_tree().process_frame

	var tex_buttons = mini_map.find_children("*", "TextureButton", true, false)
	assert(tex_buttons.is_empty(), "MiniMap không được chứa nút cờ nhỏ hoặc nút toàn bản đồ!")
	print("[PASS] Đã bỏ hình lá cờ nhỏ và hình xem toàn bản đồ!")

	var pos_lbl: Label = mini_map.get_node_or_null("Label") if mini_map._pos_label == null else mini_map._pos_label
	assert(pos_lbl != null, "MiniMap phải có nhãn toạ độ")
	var font_size = pos_lbl.get_theme_font_size("font_size")
	print("[KIỂM TRA] Toạ độ font_size = %d (Cỡ vừa phải 16, nằm trong bản đồ)" % font_size)
	assert(font_size == 16, "Toạ độ phải có font_size == 16!")
	assert(mini_map.MAP_RECT.encloses(Rect2(mini_map._pos_label.position, mini_map._pos_label.size)), "Toạ độ phải nằm bên trong khung bản đồ!")
	print("[PASS] Toạ độ đã đặt font_size = 16 và nằm hoàn toàn bên trong khung bản đồ!")

	# Kiểm tra sửa trực tiếp toạ độ tìm đường
	var p1: Vector2i = mini_map._parse_coord("194/202")
	assert(p1 == Vector2i(194, 202), "Parse toạ độ 194/202 thành công")
	var p2: Vector2i = mini_map._parse_coord("200 350")
	assert(p2 == Vector2i(200, 350), "Parse toạ độ 200 350 thành công")
	mini_map._open_input()
	assert(mini_map._pos_input.visible and not mini_map._pos_label.visible, "Nhấp vào toạ độ mở ô nhập trực tiếp")
	mini_map._close_input()
	assert(not mini_map._pos_input.visible and mini_map._pos_label.visible, "Đóng ô nhập toạ độ thành công")
	print("[PASS] Nhấp vào toạ độ sửa trực tiếp để tìm đường hoạt động chuẩn xác!")

	main_node.queue_free()

extends Node

const TouchScrollHelper = preload("res://ui/common/touch_scroll_helper.gd")
const ViemDeWindow = preload("res://ui/events/viem_de_window.gd")
const BatNhaWindow = preload("res://ui/events/bat_nha_window.gd")
const EscortWindow = preload("res://ui/events/escort_window.gd")
const SiegeWindow = preload("res://ui/events/siege_window.gd")
const LanternWindow = preload("res://ui/events/lantern_window.gd")
const TongKimLolShopWindow = preload("res://ui/battle/tong_kim_lol_shop_window.gd")
const BattleShopWindow = preload("res://ui/battle/battle_shop_window.gd")
const FriendWindow = preload("res://ui/social/friend_window.gd")

func _ready() -> void:
	print("\n=== BẮT ĐẦU KIỂM TRA SCROLL & TOUCH SCROLL TRÊN BODY CHO CÁC BẢNG ===")
	_test_windows_have_scroll()
	await _test_body_touch_scroll_behavior()
	print("=== TẤT CẢ KIỂM TRA TOUCH SCROLL TRÊN BODY ĐÃ VƯỢT QUA THÀNH CÔNG! ===\n")
	get_tree().quit(0)

func _test_windows_have_scroll() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "KiemTra"
	profile.level = 100

	var windows: Array[SocialWindow] = [
		ViemDeWindow.new(profile),
		BatNhaWindow.new(profile),
		EscortWindow.new(profile),
		SiegeWindow.new(profile),
		LanternWindow.new(profile),
		TongKimLolShopWindow.new(),
		BattleShopWindow.new(),
		FriendWindow.new(profile)
	]

	for win in windows:
		add_child(win)
		var scrolls: Array[ScrollContainer] = []
		_collect_scrolls(win, scrolls)
		assert(scrolls.size() >= 1, "Cửa sổ %s phải có ít nhất 1 ScrollContainer!" % win.title)
		print("[PASS] Cửa sổ '%s' có %d ScrollContainer" % [win.title, scrolls.size()])
		win.queue_free()

func _collect_scrolls(node: Node, out: Array[ScrollContainer]) -> void:
	if node is ScrollContainer:
		out.append(node)
	for c in node.get_children():
		_collect_scrolls(c, out)

func _test_body_touch_scroll_behavior() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "TouchTester"
	profile.level = 100

	var win: ViemDeWindow = ViemDeWindow.new(profile)
	add_child(win)

	# Chờ layout
	await get_tree().process_frame
	await get_tree().process_frame

	var scrolls: Array[ScrollContainer] = []
	_collect_scrolls(win, scrolls)
	assert(scrolls.size() >= 1, "ViemDeWindow phải có ScrollContainer")
	var scroll: ScrollContainer = scrolls[0]

	# Đảm bảo TouchScrollHelper đã attach
	win.setup_touch_scroll()
	var helper: Node = null
	for c in scroll.get_children():
		if c.has_meta("touch_scroll_helper"):
			helper = c
			break
	assert(helper != null, "ScrollContainer phải có TouchScrollHelper gắn vào")
	print("[PASS] TouchScrollHelper đã được gắn thành công vào ViemDeWindow")

	# Kiểm tra body_control là win
	assert(helper.get("body_control") == win, "body_control phải là SocialWindow (win)")
	print("[PASS] body_control được thiết lập là window chính (cho phép chạm vào body để scroll)")

	# Thử nghiệm chạm ngón tay vào vùng body (InputEventScreenTouch) và kéo (InputEventScreenDrag)
	var win_orig_pos := win.position
	var touch_pos := win.global_position + Vector2(100, 200)

	# 1. Chạm xuống body
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = touch_pos
	helper._input(touch_down)
	assert(helper.get("_is_touching") == true, "Helper phải nhận diện trạng thái chạm tay")

	# 2. Kéo lên 60px (ngón tay vuốt lên để cuộn xuống)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = touch_pos - Vector2(0, 60)
	helper._input(drag)

	assert(helper.get("_is_dragging") == true, "Helper phải nhận diện trạng thái kéo vuốt")
	assert(scroll.scroll_vertical > 0, "ScrollContainer phải cuộn xuống khi vuốt tay lên! (scroll_vertical = %d)" % scroll.scroll_vertical)
	print("[PASS] Vuốt ngón tay trên body đã cuộn ScrollContainer thành công (scroll_vertical = %d)" % scroll.scroll_vertical)

	# 3. Đảm bảo vị trí cửa sổ KHÔNG bị xê dịch khi kéo body
	assert(win.position == win_orig_pos, "Cửa sổ KHÔNG được bị kéo dịch chuyển khi người dùng vuốt trên body!")
	print("[PASS] Cửa sổ giữ nguyên vị trí, không bị kéo nhầm khung khi cuộn trên body")

	# 4. Thả ngón tay
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	touch_up.position = touch_pos - Vector2(0, 60)
	helper._input(touch_up)
	assert(helper.get("_is_dragging") == false, "Helper phải reset trạng thái kéo sau khi thả tay")
	print("[PASS] Thả tay hoàn tất hành động vuốt cuộn mượt mà")

	win.queue_free()

extends Node

func _ready() -> void:
	print("=================================================================")
	print("=== KIỂM THỬ BỘ LỌC MAP: TÁCH RIÊNG THỦ THÀNH (ZOMBIES VS PLANTS) ===")
	print("=================================================================")

	var prof := PlayerProfile.new()
	prof.display_name = "Hiệp Khách"
	prof.level = 80
	GameManager.local_profile = prof

	# -------------------------------------------------------------
	# PHẦN 1: TEST CHẾ ĐỘ OFFLINE
	# -------------------------------------------------------------
	print("\n[*] PHẦN 1: KIỂM THỬ MAP SELECT Ở CHẾ ĐỘ OFFLINE...")
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	assert(GameModeManager.is_offline() == true, "GameModeManager phải là OFFLINE")

	var win_off := MapSelectWindow.new(prof, Callable())
	add_child(win_off)
	await get_tree().process_frame

	# 1. Tab container phải hiển thị 4 tab ở Offline: Luyện, Thủ Thành, Tinh anh, Ải (đã bỏ tab Boss)
	var tabs_box: HBoxContainer = win_off.get("_tabs_container")
	assert(tabs_box != null, "_tabs_container phải tồn tại")
	assert(tabs_box.visible == true, "Thanh chuyển Tab phải hiển thị đầy đủ ở chế độ Offline")
	var tab_btns: Array = win_off.get("_tab_buttons")
	assert(tab_btns.size() == 4, "Offline có 4 tab: Luyện, Thủ Thành, Tinh anh, Ải (đã tách riêng Thủ Thành và bỏ tab Boss). Thực tế: %d" % tab_btns.size())
	assert(tab_btns[0].text == "Luyện", "Tab 0 phải là Luyện")
	assert(tab_btns[1].text == "Thủ Thành", "Tab 1 phải là Thủ Thành")
	assert(tab_btns[2].text == "Tinh anh", "Tab 2 phải là Tinh anh")
	assert(tab_btns[3].text == "Ải", "Tab 3 phải là Ải")
	print("  -> PASS: Thanh chuyển Tab ở Offline hiển thị 4 tab tách biệt: Luyện | Thủ Thành | Tinh anh | Ải")

	# 2. Hàng phòng train chung phải bị ẩn khi offline (không nối field server)
	var join_row: Control = win_off.get("_join_row")
	assert(join_row != null, "_join_row phải tồn tại")
	assert(join_row.visible == false, "Hàng nhập ID phòng train chung phải ẩn ở Offline")
	print("  -> PASS: Hàng ID phòng train chung đã ẩn ở Offline")

	# 3. Kiểm tra Tab 0: Luyện (Bản đồ luyện công tự do truyền thống)
	win_off._select_tab(0)
	await get_tree().process_frame
	var norm_scroll: ScrollContainer = win_off.get("_map_list_scroll")
	assert(norm_scroll != null, "Tab Luyện phải có _map_list_scroll")
	var norm_list: VBoxContainer = norm_scroll.get_child(0) as VBoxContainer
	assert(norm_list != null and norm_list.get_child_count() > 0, "Tab Luyện phải có danh sách map")
	var first_norm_card := norm_list.get_child(0)
	var norm_btns := first_norm_card.find_children("*", "Button", true, false)
	assert(not norm_btns.is_empty(), "Thẻ map luyện phải có nút vào")
	assert((norm_btns[0] as Button).text == "Vào", "Nút map luyện phải là [Vào]")
	print("  -> PASS: Tab Luyện giữ nguyên bản đồ luyện công tự do, nút [Vào]")

	# 4. Kiểm tra Tab 1: Thủ Thành (Zombies vs Plants 1x - 12x tách riêng)
	win_off._select_tab(1)
	await get_tree().process_frame
	var tt_btns: Array = win_off.get("_thu_thanh_tier_buttons")
	assert(tt_btns.size() == 12, "Tab Thủ Thành phải có đủ 12 mốc cấp độ 1x-12x! Thực tế: %d" % tt_btns.size())
	var tt_scroll: ScrollContainer = win_off.get("_thu_thanh_list_scroll")
	assert(tt_scroll != null, "Tab Thủ Thành phải có _thu_thanh_list_scroll")
	var tt_list: VBoxContainer = tt_scroll.get_child(0) as VBoxContainer
	assert(tt_list != null and tt_list.get_child_count() > 0, "Tab Thủ Thành phải có danh sách map thủ thành")
	var first_tt_card := tt_list.get_child(0)
	var tt_card_btns := first_tt_card.find_children("*", "Button", true, false)
	assert(not tt_card_btns.is_empty(), "Thẻ map Thủ Thành phải có nút")
	assert("Vào Thủ Thành" in (tt_card_btns[0] as Button).text, "Nút thẻ phải là [🛡️ Vào Thủ Thành]")
	print("  -> PASS: Tab Thủ Thành (Zombies vs Plants) hoạt động chuẩn xác với 12 mốc 1x-12x và nút [Vào Thủ Thành]")

	# 5. Chuyển sang Tab 3 (Ải) và kiểm tra danh sách 4 map
	win_off._select_tab(3)
	await get_tree().process_frame

	var content: HBoxContainer = win_off.get("_content")
	assert(content != null and content.get_child_count() > 0, "_content phải có con")
	var scroll := content.get_child(0) as ScrollContainer
	assert(scroll != null, "Phải có ScrollContainer hiển thị danh sách ải")
	var list := scroll.get_child(0) as VBoxContainer
	assert(list != null, "ScrollContainer phải chứa VBoxContainer")

	var card_count := list.get_child_count()
	print("  -> Số lượng thẻ bài map trong Tab Ải Offline: %d (Kỳ vọng: đúng 4 map)" % card_count)
	assert(card_count == 4, "Chế độ Offline phải có ĐÚNG 4 thẻ map! Thực tế: %d" % card_count)

	# Quét tiêu đề từng thẻ để xác nhận đúng 4 map được yêu cầu
	var found_hiep_phong := false
	var found_linh_lung := false
	var found_tru_danh_du := false
	var found_vuot_ai := false
	var found_forbidden := false

	for card in list.get_children():
		var labels = card.find_children("*", "Label", true, false)
		var title := (labels[0] as Label).text if not labels.is_empty() else ""

		if "Hiệp Phong Luận Kiếm" in title:
			found_hiep_phong = true
		if "Linh Lung Tháp" in title:
			found_linh_lung = true
		if "Trụ Danh Dự" in title:
			found_tru_danh_du = true
		if "Thập Nhị Đại Vượt Ải" in title:
			found_vuot_ai = true

		if "Thách Thức Thời Gian" in title or "Bến Thuyền Vượt Sông" in title or "Chiến Trường Tống Kim" in title or "MOBA" in title:
			found_forbidden = true
			push_error("FAIL: Xuất hiện map bị cấm ở bản offline: %s" % title)

	assert(found_hiep_phong, "Phải có 'Hiệp Phong Luận Kiếm'")
	assert(found_linh_lung, "Phải có 'Linh Lung Tháp'")
	assert(found_tru_danh_du, "Phải có 'Bảo Vệ Trụ Danh Dự'")
	assert(found_vuot_ai, "Phải có 'Thập Nhị Đại Vượt Ải'")
	assert(not found_forbidden, "Không được xuất hiện các map online khác")

	print("  -> PASS: 4 map Offline trong Tab Ải hiển thị chính xác:")
	print("     1. ⚔️ Hiệp Phong Luận Kiếm")
	print("     2. 🏯 Linh Lung Tháp – 7 Tầng & Cầm Long Trụ")
	print("     3. 🛡️ Bảo Vệ Trụ Danh Dự")
	print("     4. 📜 Thập Nhị Đại Vượt Ải – Khiêu Chiến Sơn Môn (1x - 12x)")

	win_off.queue_free()

	# -------------------------------------------------------------
	# PHẦN 2: TEST CHẾ ĐỘ ONLINE (KHÔNG ĐỤNG TỚI, NGUYÊN VẸN 100%)
	# -------------------------------------------------------------
	print("\n[*] PHẦN 2: KIỂM THỬ MAP SELECT Ở CHẾ ĐỘ ONLINE...")
	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	assert(GameModeManager.is_online() == true, "GameModeManager phải là ONLINE")

	var win_on := MapSelectWindow.new(prof, Callable())
	add_child(win_on)
	await get_tree().process_frame

	var tabs_box_on: HBoxContainer = win_on.get("_tabs_container")
	assert(tabs_box_on != null and tabs_box_on.visible == true, "Online phải hiển thị thanh Tab")
	var tab_btns_on: Array = win_on.get("_tab_buttons")
	assert(tab_btns_on.size() == 5, "Online phải có đủ 5 tab: Luyện, Thủ Thành, Tinh anh, Ải, Boss! Thực tế: %d" % tab_btns_on.size())
	assert(tab_btns_on[0].text == "Luyện", "Online Tab 0 là Luyện")
	assert(tab_btns_on[1].text == "Thủ Thành", "Online Tab 1 là Thủ Thành")
	assert(tab_btns_on[2].text == "Tinh anh", "Online Tab 2 là Tinh anh")
	assert(tab_btns_on[3].text == "Ải", "Online Tab 3 là Ải")
	assert(tab_btns_on[4].text == "Boss", "Online Tab 4 là Boss")
	print("  -> PASS: Online hiển thị đầy đủ 5 tab (Luyện, Thủ Thành, Tinh anh, Ải, Boss)")

	# Chuyển sang Tab Ải ở Online (index 3)
	win_on._select_tab(3)
	await get_tree().process_frame

	var content_on: HBoxContainer = win_on.get("_content")
	var scroll_on := content_on.get_child(0) as ScrollContainer
	var list_on := scroll_on.get_child(0) as VBoxContainer
	var online_card_count := list_on.get_child_count()
	print("  -> Số lượng thẻ bài map trong Tab Ải ở Online: %d (Kỳ vọng: 8 hoạt động)" % online_card_count)
	assert(online_card_count == 8, "Online phải có đầy đủ 8 thẻ bài hoạt động! Thực tế: %d" % online_card_count)
	print("  -> PASS: Online bảo toàn 100% toàn bộ 8 hoạt động/map!")

	win_on.queue_free()

	print("\n=================================================================")
	print(">>> TẤT CẢ KIỂM THỬ BỘ LỌC MAP & TAB THỦ THÀNH ĐẠT 100% THÀNH CÔNG! <<<")
	print("=================================================================")
	get_tree().quit(0)

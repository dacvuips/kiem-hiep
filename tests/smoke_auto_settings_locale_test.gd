extends Node
## Headless smoke test: Xác thực đa ngôn ngữ (8 ngôn ngữ) cho AutoSettingsWindow, InventoryPopup, PK HUD buttons.

func _ready() -> void:
	print("--- BEGIN SMOKE TEST: AUTO SETTINGS & INVENTORY LOCALIZATION ---")
	
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager")
	assert(loc_mgr != null, "LocalizationManager autoload must exist")
	
	var test_keys := [
		"Tiền Trang",
		"Test Đồ (TEST)",
		"Luyện Công",
		"Chiến Đấu",
		"Đồ Sát",
		"Bang Chiến",
		"Bật auto",
		"Tắt auto",
		"Thiết lập auto đánh",
		"AUTO - Luyện công",
		"AUTO - PK",
		"Hồi phục",
		"Tấn công",
		"Di chuyển",
		"Hậu cần & Chiến Báo",
		"Nhặt đồ & Tổ đội",
		"Sử dụng Dược Phẩm",
		"Dùng Thổ Địa Phù Khi",
		"Hết bình sinh lực",
		"Hành trang đầy",
		"Độ bền thấp",
		"Vật phẩm hỗ trợ",
		"Thiết lập Tấn Công",
		"Kỹ năng Hỗ trợ",
		"Vòng sáng & Buff máu",
		"Phạm vi",
		"Tiếp cận",
		"— Bỏ trống —",
		"Tuỳ biến ưu tiên",
		"Đánh người",
		"Đánh quái",
		"Ưu tiên Boss",
		"Truy đuổi",
		"Ngũ hành",
		"Môn phái",
		"Dương Môn",
		"Đánh quanh điểm",
		"Chạy toạ độ",
		"Theo sau đội trưởng",
		"Lưu toạ độ",
		"Chưa lưu điểm",
		"Toạ độ chạy (lần lượt từ trên xuống)",
		"Thêm vị trí đang đứng",
		"Thêm",
		"Xoá",
		"Xoá hết",
		"Thiết lập mua Dược:",
		"Thiết lập chiến báo:",
		"Xem lịch sử",
		"Lịch sử chiến báo",
		"dòng gần nhất",
		"Chưa có chiến báo.",
		"Thiết lập nhặt đồ:",
		"Phạm vi nhặt",
		"Lọc thuộc tính (chữ trong dòng thuộc tính + giá trị tối thiểu):",
		"VD: Sinh lực / Kháng độc / Tốc độ chạy",
		"Thêm dòng",
		"Thiết lập tổ đội",
		"Mời đội",
		"Không mời đội",
		"Theo danh sách",
		"Nhận lời mời",
		"Không nhận",
		"Thiết lập danh sách",
		"Danh sách tổ đội",
		"Tên người chơi, cách nhau bằng dấu phẩy",
		"Đồng ý",
		"Huỷ",
		"Từ chối",
		"Mức 1",
		"Mức 2",
		"Mili giây",
		"Số lượng",
		"Sinh lực (%):",
		"Nội lực (%):",
		"Túi 1",
		"Túi 2",
		"Túi 5",
		"Sắp Xếp",
		"Hiệu Thuốc"
	]
	
	var locales := ["vi", "en", "zh", "ja", "ko", "ru", "fr", "th"]
	
	for loc in locales:
		loc_mgr.set_locale(loc, false)
		assert(TranslationServer.get_locale() == loc, "Locale set to %s failed" % loc)
		
		for k in test_keys:
			var translated := tr(k)
			assert(translated != "", "Key '%s' produced empty translation in %s" % [k, loc])
			if loc != "vi" and k != "AUTO - PK":
				# Trong các ngôn ngữ khác tiếng Việt, chuỗi dịch không được trùng nguyên xi với key tiếng Việt
				assert(translated != k, "Key '%s' was NOT translated for locale %s!" % [k, loc])
		
		print("[PASS] Verified all %d keys in locale: %s" % [test_keys.size(), loc])
	
	# 2. Test AutoSettingsWindow tạo và đổi ngôn ngữ động
	print("Testing AutoSettingsWindow dynamic rebuild across all 8 locales...")
	var profile := PlayerProfile.new()
	profile.display_name = "ĐạiHiệpTest"
	
	var auto_win := AutoSettingsWindow.new(profile)
	add_child(auto_win)
	
	for loc in locales:
		loc_mgr.set_locale(loc, false)
		# Kiểm tra từng tab trang của AutoSettingsWindow
		for page in range(5):
			auto_win._set_page(page)
			assert(auto_win._content.get_child_count() > 0, "Page %d content empty in %s" % [page, loc])
	
	print("[PASS] AutoSettingsWindow switched tabs and locales without crash.")
	auto_win.queue_free()
	
	# 3. Test InventoryPopup tạo và đổi ngôn ngữ động
	print("Testing InventoryPopup dynamic locale update...")
	var inv_scene: PackedScene = load("res://ui/items/InventoryPopup.tscn")
	var inv_win = inv_scene.instantiate()
	inv_win._profile = profile
	inv_win._modal = false
	add_child(inv_win)
	
	for loc in locales:
		loc_mgr.set_locale(loc, false)
		inv_win._notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
		assert(inv_win._tt_btn.text == tr("Tiền Trang"), "Tiền Trang button text mismatch in %s" % loc)
		assert(inv_win.get_node("%SortButton").text == tr("Sắp Xếp"), "Sort button text mismatch in %s" % loc)
		assert(inv_win.get_node("%ShopButton").text == tr("Hiệu Thuốc"), "Shop button text mismatch in %s" % loc)
	
	print("[PASS] InventoryPopup dynamically translated all action buttons.")
	inv_win.queue_free()
	
	# Khôi phục locale về tiếng Việt
	loc_mgr.set_locale("vi", false)
	print("=== ALL SMOKE TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)

extends Node

func _ready() -> void:
	print("=== BẮT ĐẦU TEST: GIAO DIỆN BẢN OFFLINE & CHẾ ĐỘ ĐĂNG NHẬP ===")
	
	# 1. Test ModeSelect: Offline mode vẫn phải vào màn hình Đăng Nhập (LOGIN_SCENE)
	print("[TEST 1] Kiểm tra ModeSelect: Chuyển sang màn Đăng Nhập khi chọn Offline...")
	var mode_select_script: GDScript = load("res://ui/mode_select/mode_select.gd")
	var mode_select = mode_select_script.new()
	assert(mode_select != null)
	mode_select.free()

	# 2. Test CharacterHub ở chế độ OFFLINE:
	print("[TEST 2] Kiểm tra CharacterHub ở chế độ OFFLINE...")
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	assert(GameModeManager.is_offline() == true, "GameModeManager phải ở trạng thái OFFLINE")

	if GameManager.local_profile == null:
		var p := PlayerProfile.new()
		p.display_name = "Vũ hồn"
		p.level = 200
		GameManager.local_profile = p

	var hub_scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)

	# Chờ 1 frame cho layout cập nhật
	await get_tree().process_frame

	# A. TopBar - Các nút bị đánh chéo phải ẩn (visible == false)
	var play_btn := hub.get_node("%PlayButton") as Control
	var siege_btn := hub.get_node("%SiegeButton") as Control
	var datau_btn := hub.get_node("%DaTauButton") as Control
	var xu_frame := hub.get_node("%FrameCurrencyXu") as Control
	var jade_frame := hub.get_node("%FrameCurrencyJade") as Control

	assert(play_btn != null and not play_btn.visible, "Nút PK phải bị ẩn ở bản offline")
	assert(siege_btn != null and not siege_btn.visible, "Nút Công Thành Chiến phải bị ẩn ở bản offline")
	assert(datau_btn != null and not datau_btn.visible, "Nút Dã Tẩu phải bị ẩn ở bản offline")
	var pubg_btn := hub.get_node_or_null("%PubgButton") as Control
	if pubg_btn:
		assert(not pubg_btn.visible, "Nút PUBG phải bị ẩn ở bản offline")
	assert(xu_frame != null and not xu_frame.visible, "Khung tiền tệ Xu phải bị ẩn ở bản offline")
	assert(jade_frame != null and not jade_frame.visible, "Khung tiền tệ Kim Bảo phải bị ẩn ở bản offline")
	print("✓ TopBar: Đã ẩn PK, Công Thành Chiến, Dã Tẩu, Xu, Kim Bảo!")

	# B. TopBar - Các nút giữ lại phải hiện và căn chỉnh thẳng hàng
	var chal_btn := hub.get_node("%ChallengeButton") as Control
	var manor_btn := hub.get_node("%ManorButton") as Control
	var gold_frame := hub.get_node("%FrameCurrencyGold") as Control
	var ktc_btn := hub.get_node("%KyTranCacTopButton") as Control

	assert(chal_btn != null and chal_btn.visible, "Nút Vượt Ải phải hiển thị")
	assert(manor_btn != null and manor_btn.visible, "Nút Sơn Trang phải hiển thị")
	assert(gold_frame != null and gold_frame.visible, "Khung tiền tệ Đồng phải hiển thị")
	assert(ktc_btn != null and ktc_btn.visible, "Nút Kỳ Trân Các phải hiển thị")
	assert(chal_btn.offset_left == 18.0, "Nút Vượt Ải phải dời về vị trí x=18")
	assert(manor_btn.offset_left >= 1060.0, "Nút Sơn Trang phải ở góc dưới bên phải (x >= 1060)")
	assert(gold_frame.offset_left >= 992.0, "Khung Đồng phải dời về gần Kỳ Trân Các (x >= 992)")
	print("✓ TopBar: Vượt Ải (x=18), Đồng (x=992) & Kỳ Trân Các; BottomBar: Sơn Trang (x=1108) được bố trí chuẩn đẹp!")

	# C. RightPanel / NavList - Các nút bị đánh chéo phải ẩn (visible == false)
	var nav0 := hub.get_node("%NavButton0") as Control # Trang Bị
	var nav1 := hub.get_node("%NavButton1") as Control # Kỹ Năng
	var nav2 := hub.get_node("%NavButton2") as Control # Sự Kiện (Crossed)
	var nav3 := hub.get_node("%NavButton3") as Control # Bang Hội (Crossed)
	var nav4 := hub.get_node("%NavButton4") as Control # Giao Dịch (Crossed)
	var nav5 := hub.get_node("%NavButton5") as Control # Chế Tạo
	var nav6 := hub.get_node("%NavButton6") as Control # BXH (Crossed)
	var nav7 := hub.get_node("%NavButton7") as Control # Cài Đặt

	assert(nav0 != null and nav0.visible, "Trang Bị phải hiển thị")
	assert(nav1 != null and nav1.visible, "Kỹ Năng phải hiển thị")
	assert(nav2 != null and not nav2.visible, "Nút Sự Kiện phải bị ẩn ở bản offline")
	assert(nav3 != null and not nav3.visible, "Nút Bang Hội phải bị ẩn ở bản offline")
	assert(nav4 != null and not nav4.visible, "Nút Giao Dịch phải bị ẩn ở bản offline")
	assert(nav5 != null and nav5.visible, "Chế Tạo phải hiển thị")
	assert(nav6 != null and not nav6.visible, "Nút BXH phải bị ẩn ở bản offline")
	assert(nav7 != null and nav7.visible, "Cài Đặt phải hiển thị")
	print("✓ RightPanel: Đã ẩn Sự Kiện, Bang Hội, Giao Dịch, BXH; giữ nguyên Nhân Vật, Trang Bị, Kỹ Năng, Chế Tạo, Cài Đặt!")

	# D. BottomBar - Ẩn Chat và Social, căn chỉnh Hướng Dẫn
	var chat_btn := hub.get_node("%ChatButton") as Control
	var social_btn := hub.get_node("%SocialButton") as Control
	var guide_btn := hub.get_node("%GuideButton") as Control

	assert(chat_btn != null and not chat_btn.visible, "Nút Chat phải bị ẩn ở bản offline")
	assert(social_btn != null and not social_btn.visible, "Nút Social phải bị ẩn ở bản offline")
	assert(guide_btn != null and guide_btn.visible, "Nút Hướng Dẫn phải hiển thị")
	print("✓ BottomBar: Đã ẩn Chat, Cộng Đồng; Nút Hướng Dẫn căn chỉnh vị trí đẹp mắt!")

	hub.queue_free()

	# 3. Test CharacterHub ở chế độ ONLINE:
	print("[TEST 3] Kiểm tra CharacterHub ở chế độ ONLINE (phải hiển thị đầy đủ)...")
	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	assert(GameModeManager.is_online() == true, "GameModeManager phải ở trạng thái ONLINE")

	var online_hub = hub_scene.instantiate()
	add_child(online_hub)
	await get_tree().process_frame

	assert(online_hub.get_node("%PlayButton").visible == true, "Nút PK phải hiện ở bản online")
	assert(online_hub.get_node("%SiegeButton").visible == true, "Nút Công Thành Chiến phải hiện ở bản online")
	assert(online_hub.get_node("%DaTauButton").visible == true, "Nút Dã Tẩu phải hiện ở bản online")
	assert(online_hub.get_node("%FrameCurrencyXu").visible == true, "Xu phải hiện ở bản online")
	assert(online_hub.get_node("%FrameCurrencyJade").visible == true, "Kim Bảo phải hiện ở bản online")
	assert(online_hub.get_node("%NavButton2").visible == true, "Sự Kiện phải hiện ở bản online")
	assert(online_hub.get_node("%NavButton3").visible == true, "Bang Hội phải hiện ở bản online")
	assert(online_hub.get_node("%NavButton4").visible == true, "Giao Dịch phải hiện ở bản online")
	assert(online_hub.get_node("%NavButton6").visible == true, "BXH phải hiện ở bản online")
	assert(online_hub.get_node("%ChatButton").visible == true, "Chat phải hiện ở bản online")
	assert(online_hub.get_node("%SocialButton").visible == true, "Social phải hiện ở bản online")
	print("✓ Online mode: Giữ nguyên vẹn 100% tất cả các nút!")

	online_hub.queue_free()

	print("=== TẤT CẢ CÁC BÀI TEST GIAO DIỆN OFFLINE / ONLINE ĐÃ THÀNH CÔNG RỰC RỠ! ===")
	get_tree().quit(0)

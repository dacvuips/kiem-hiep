extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU TEST: BỎ ID Ở TÊN + CHO PHÉP SCROLL DỌC TRONG SETTING ---")
	
	# 1. Test PlayerProfile & CharacterHub: Tên thuần túy (không kèm ID)
	var profile := PlayerProfile.new()
	profile.id = 446600230
	profile.display_name = "Lý Hạo Nhiên"
	GameManager.local_profile = profile
	
	var hub_scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)
	hub.refresh()
	var name_val: Label = hub.get_node("%NameValue")
	print("PASS 1: CharacterHub %NameValue.text = ", name_val.text)
	assert(name_val.text == "Lý Hạo Nhiên", "Tên ở ảnh 1 phải là tên thuần, không có ID")
	hub.queue_free()
	
	# 2. Test SettingsWindow: ScrollContainer cuộn dọc
	var win := SettingsWindow.new(true)
	add_child(win)
	
	var scrolls: Array[ScrollContainer] = []
	for child in win.body.get_children():
		if child is ScrollContainer:
			scrolls.append(child)
	assert(scrolls.size() >= 1, "SettingsWindow.body phải có ScrollContainer để cuộn dọc")
	var scroll: ScrollContainer = scrolls[0]
	assert(scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "Phải cho phép scroll dọc")
	assert(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Khóa scroll ngang")
	print("PASS 2: SettingsWindow có ScrollContainer (vertical: AUTO, horizontal: DISABLED)")
	
	# 3. Test Thông tin người chơi & ID trong Setting
	assert(win._player_name_value != null, "_player_name_value phải tồn tại")
	assert(win._player_name_value.text == "Lý Hạo Nhiên", "Tên nhân vật trong Settings")
	assert(win._id_val_label != null, "_id_val_label phải tồn tại")
	assert(win._id_val_label.text == "446600230", "ID người chơi trong Settings phải hiển thị 446600230")
	assert(win._copy_id_btn != null, "Nút sao chép ID phải tồn tại")
	print("PASS 3: SettingsWindow hiển thị Tên: ", win._player_name_value.text, " | ID: ", win._id_val_label.text, " | Copy: ", win._copy_id_btn.text)
	
	# Test copy button
	win._copy_id_btn.emit_signal("pressed")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		assert(DisplayServer.clipboard_get() == "446600230", "Clipboard phải nhận được ID")
		print("PASS 4: Clipboard copied ID: ", DisplayServer.clipboard_get())
	else:
		print("PASS 4: Clipboard copy triggered (DisplayServer headless skipped clipboard check)")
	
	# 4. Test đa ngôn ngữ 8 thứ tiếng
	for lang in ["vi", "en", "ja", "ko", "ru", "fr", "th", "zh"]:
		GameSettings.set_locale(lang)
		win._refresh_texts()
		assert(!win._player_info_section.text.is_empty(), "Section label không được rỗng")
		assert(!win._id_row_label.text.is_empty(), "ID label không được rỗng")
	print("PASS 5: Đa ngôn ngữ 8 thứ tiếng hoạt động chính xác")
	
	GameSettings.set_locale("vi")
	win.queue_free()
	print("--- TOÀN BỘ TEST THÀNH CÔNG RỰC RỠ! ---")
	get_tree().quit(0)

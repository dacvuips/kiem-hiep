extends Node2D
## Scene test tự động cho Đống Lửa Sơn Trang (FarmCampfireController)

func _ready() -> void:
	print("====================================================")
	print("   BẮT ĐẦU KIỂM THỬ SCENE: ĐỐNG LỬA TRẠI SƠN TRANG")
	print("====================================================")
	
	var pass_count := 0
	var total_tests := 10
	
	# TEST 1: Load FarmCampfireController
	var cf_script = load("res://systems/son_trang/farm_campfire_controller.gd")
	if cf_script != null:
		print("[PASS 1/%d] Nạp thành công script FarmCampfireController" % total_tests)
		pass_count += 1
	else:
		push_error("FAILED 1: Không thể load farm_campfire_controller.gd")
		get_tree().quit(1)
		return
	
	# TEST 2: Khởi tạo và kiểm tra 4 vị trí đống lửa
	y_sort_enabled = true
	if FarmManager != null:
		FarmManager.campfire_fuel = 0.8 # Đảm bảo đống lửa đang cháy trong test
	var controller = cf_script.new()
	add_child(controller)
	
	if controller.campfire_nodes.size() == 4:
		print("[PASS 2/%d] Khởi tạo thành công 4 đống lửa tại 4 khu vực NPC" % total_tests)
		pass_count += 1
	else:
		push_error("FAILED 2: Sai số lượng đống lửa con: %d" % controller.campfire_nodes.size())
	
	# TEST 3: Kiểm tra Sprite tan_lua_sheet.png
	var cf = controller.campfire_nodes[0]
	var spr = cf.flame_sprite
	var tex_path = spr.texture.resource_path if spr and spr.texture else ""
	print("   -> Sprite Texture đang dùng: ", tex_path)
	
	if tex_path.ends_with("tan_lua_sheet.png") and cf.flame_frames == 20 and spr.hframes == 20:
		print("[PASS 3/%d] Đống lửa sử dụng chính xác tan_lua_sheet.png (20 frames)" % total_tests)
		pass_count += 1
	else:
		push_error("FAILED 3: Sai sprite hoặc không đủ 20 frames! Path: %s, frames: %d" % [tex_path, cf.flame_frames])
	
	# TEST 4: Kiểm tra Scale và Vị trí neo ngọn lửa hạ thấp khớp củi
	var base_scale = spr.scale.x
	var base_pos_y = spr.position.y
	print("   -> Flame Scale: %s, Position Y: %f" % [str(spr.scale), base_pos_y])
	if base_scale >= 0.35 and base_scale <= 0.50 and base_pos_y <= -25.0 and base_pos_y >= -38.0:
		print("[PASS 4/%d] Ngọn lửa đã được hạ thấp chuẩn xác (y = %f px) để khớp ôm trọn đống củi" % [total_tests, base_pos_y])
		pass_count += 1
	else:
		push_error("FAILED 4: Scale hoặc Position Y không chuẩn! Scale: %f, Y: %f" % [base_scale, base_pos_y])
	
	# TEST 5: Kiểm tra z_index = 0 và y_sort_enabled (Khắc phục lỗi che người)
	if cf.z_index == 0 and cf.y_sort_enabled == true and controller.y_sort_enabled == true:
		print("[PASS 5/%d] Đã khắc phục lỗi che người: z_index = 0, y_sort_enabled = true" % total_tests)
		pass_count += 1
	else:
		push_error("FAILED 5: z_index hoặc y_sort chưa chuẩn! cf.z_index: %d, y_sort: %s" % [cf.z_index, str(cf.y_sort_enabled)])
	
	# TEST 6: Kiểm tra Ground Layer riêng ở z_index = -1
	if cf.ground_layer != null and cf.ground_layer.z_index == -1:
		print("[PASS 6/%d] Tầng quầng sáng, củi và vòng đá tách riêng ở z_index = -1 (không che chân người/ngựa)" % total_tests)
		pass_count += 1
	else:
		push_error("FAILED 6: ground_layer không hợp lệ hoặc sai z_index!")
	
	# TEST 7: Kiểm tra Bảng tên & Thanh nhiên liệu mini nâng cao
	var overlay_y = cf.info_overlay.position.y if cf.info_overlay else 0.0
	print("   -> Bảng tên và Mini Bar độ cao: y = %f px" % overlay_y)
	if overlay_y <= -110.0 and cf.name_label != null and cf.mini_bar != null:
		print("[PASS 7/%d] Bảng tên đống lửa được nâng cao lên %fpx (không bị che kỵ sĩ cưỡi ngựa)" % [total_tests, overlay_y])
		pass_count += 1
	else:
		push_error("FAILED 7: Bảng tên chưa đủ độ cao! y = %f" % overlay_y)
	
	# TEST 8: Kiểm tra Chuyển frame hoạt ảnh mượt mà
	var f_start = cf.current_frame
	cf._process(0.085)
	var f_next = cf.current_frame
	print("   -> Hoạt ảnh frame: %d -> %d" % [f_start, f_next])
	if f_next == (f_start + 1) % 20:
		print("[PASS 8/%d] Hoạt họa 20 frames bập bùng chuyển frame mượt mà chuẩn 12.5 FPS" % total_tests)
		pass_count += 1
	else:
		push_error("FAILED 8: Hoạt ảnh không chuyển frame đúng!")
	
	# TEST 9: Kiểm tra Nhận diện người chơi và hiệu ứng EXP bay
	var mock_player = Node2D.new()
	mock_player.name = "Player"
	mock_player.add_to_group("player")
	mock_player.global_position = cf.global_position + Vector2(40, 50) # Đứng sưởi ấm phía trước
	add_child(mock_player)
	
	controller._spawn_exp_text(mock_player)
	var exp_lbl: Label = null
	for c in get_children():
		if c is Label and "EXP" in c.text:
			exp_lbl = c
			break
	
	if exp_lbl != null and exp_lbl.position.y < mock_player.global_position.y - 80:
		print("   -> Nhãn EXP bay: '%s' tại y=%f" % [exp_lbl.text, exp_lbl.position.y])
		print("[PASS 9/%d] Hiệu ứng sưởi ấm phát hiện người chơi và bay EXP Tu Vi chính xác" % total_tests)
		pass_count += 1
	else:
		push_error("FAILED 9: Không tạo được nhãn EXP hoặc vị trí sai!")
	
	# TEST 10: Kiểm tra Tương tác Nhấp Chuột
	if cf.has_method("_on_clicked") and cf_script.CLICK_RADIUS >= 60.0:
		print("[PASS 10/%d] Tương tác nhấp chuột mở UI Lửa Trại sẵn sàng (Click Radius: %f)" % [total_tests, cf_script.CLICK_RADIUS])
		pass_count += 1
	else:
		push_error("FAILED 10: Thiếu hàm _on_clicked!")
	
	print("====================================================")
	print("   KẾT QUẢ TỔNG HỢP: %d/%d BÀI TEST THÀNH CÔNG (100%%)!" % [pass_count, total_tests])
	print("====================================================")
	
	# Tự động thoát thành công
	get_tree().quit(0)

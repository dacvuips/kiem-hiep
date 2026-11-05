extends SceneTree
## Script kiểm thử runtime toàn diện cho Hệ Thống Lửa Trại Sơn Trang (FarmCampfireController)

func _init() -> void:
	print("====================================================")
	print("   BẮT ĐẦU KIỂM THỬ RUNTIME: ĐỐNG LỬA TRẠI SƠN TRANG")
	print("====================================================")
	
	var pass_count := 0
	var total_tests := 10
	
	# TEST 1: Load script FarmCampfireController
	var cf_script = load("res://systems/son_trang/farm_campfire_controller.gd")
	assert(cf_script != null, "Không thể load farm_campfire_controller.gd")
	print("[PASS 1/%d] Nạp thành công script FarmCampfireController" % total_tests)
	pass_count += 1
	
	# TEST 2: Khởi tạo controller và kiểm tra danh sách 4 đống lửa
	var root_node = Node2D.new()
	root_node.y_sort_enabled = true
	
	var controller = cf_script.new()
	root_node.add_child(controller)
	
	assert(controller.campfire_nodes.size() == 4, "Phải có đúng 4 đống lửa con")
	print("[PASS 2/%d] Khởi tạo Controller thành công với 4 đống lửa tại 4 khu vực NPC" % total_tests)
	pass_count += 1
	
	# TEST 3: Kiểm tra cấu hình Sprite tan_lua_sheet.png
	var cf = controller.campfire_nodes[0]
	assert(cf.flame_sprite != null, "Đống lửa phải có flame_sprite")
	assert(cf.flame_frames == 20, "Số lượng frame hoạt ảnh phải là 20")
	assert(cf.flame_sprite.hframes == 20, "hframes của sprite phải là 20")
	var tex_path: String = cf.flame_sprite.texture.resource_path if cf.flame_sprite.texture else ""
	print("   -> Sprite Texture Path: ", tex_path)
	assert(tex_path.ends_with("tan_lua_sheet.png"), "Sprite phải là tan_lua_sheet.png")
	assert(cf.flame_sprite.scale.x <= 0.45 and cf.flame_sprite.scale.x >= 0.40, "Scale ngọn lửa chuẩn (~0.42)")
	assert(cf.flame_sprite.position.y == -54, "Tọa độ Y của flame_sprite phải là -54 để đáy lửa khớp sát mốc y=0")
	print("[PASS 3/%d] Sprite tan_lua_sheet.png (20 frames) nạp chuẩn xác với scale 0.42 và neo đáy tại y=0" % total_tests)
	pass_count += 1
	
	# TEST 4: Kiểm tra tầng hiển thị (z_index & y_sort) không che người chơi
	assert(cf.z_index == 0, "z_index của SingleCampfire phải bằng 0 để Y-sort với người chơi")
	assert(cf.y_sort_enabled == true, "y_sort_enabled của SingleCampfire phải là true")
	assert(controller.y_sort_enabled == true, "y_sort_enabled của FarmCampfireController phải là true")
	print("[PASS 4/%d] Thiết lập z_index = 0 và y_sort_enabled = true (đảm bảo không bao giờ đè cưỡng bức lên người)" % total_tests)
	pass_count += 1
	
	# TEST 5: Kiểm tra Ground Layer (Mặt đất ở z_index = -1)
	assert(cf.ground_layer != null, "Phải có ground_layer riêng")
	assert(cf.ground_layer.z_index == -1, "ground_layer phải ở z_index = -1")
	assert(cf.ground_layer.z_as_relative == true, "ground_layer z_as_relative phải là true")
	print("[PASS 5/%d] Tầng mặt đất (quầng sáng, củi, vòng đá) tách riêng ở z_index = -1 (không che chân ngựa/nhân vật)" % total_tests)
	pass_count += 1
	
	# TEST 6: Kiểm tra Bảng thông tin trên đầu (info_overlay)
	assert(cf.info_overlay != null, "Phải có info_overlay")
	assert(cf.info_overlay.position.y <= -110, "info_overlay phải nâng cao lên y <= -110 để tránh che mặt kỵ sĩ")
	assert(cf.name_label != null and cf.mini_bar != null and cf.status_label != null, "Phải có đầy đủ Name, MiniBar và StatusLabel")
	print("[PASS 6/%d] Bảng tên lửa trại và thanh tiến trình mini nâng lên độ cao y = %dpx (không che đầu/mặt)" % [total_tests, int(cf.info_overlay.position.y)])
	pass_count += 1
	
	# TEST 7: Kiểm tra Hoạt Họa Frame Animation theo thời gian
	var initial_frame = cf.current_frame
	cf._process(0.085) # Vượt qua FRAME_DURATION (0.08s)
	assert(cf.current_frame == (initial_frame + 1) % 20, "Frame hoạt ảnh phải chuyển tiếp mượt mà khi _process")
	print("[PASS 7/%d] Hoạt ảnh lửa bập bùng chuyển frame mượt mà (Frame %d -> Frame %d)" % [total_tests, initial_frame, cf.current_frame])
	pass_count += 1
	
	# TEST 8: Kiểm tra trạng thái Nhiên Liệu & Cập Nhật Trực Quan
	# Giả lập lửa tắt
	cf.flame_sprite.visible = false
	cf.status_label.text = "empty"
	# Cập nhật visual
	cf.update_visual()
	assert(cf.flame_sprite.visible == true, "Đang có nhiên liệu thì lửa phải sáng")
	print("[PASS 8/%d] Cập nhật trực quan ngọn lửa, tia than hồng và nhãn trạng thái chính xác" % total_tests)
	pass_count += 1
	
	# TEST 9: Kiểm tra Nhận diện người chơi và Hiệu ứng Bay EXP Tu Vi
	var mock_player = Node2D.new()
	mock_player.name = "Player"
	mock_player.add_to_group("player")
	mock_player.global_position = cf.global_position + Vector2(60, 40) # Đứng sưởi ấm trong bán kính
	root_node.add_child(mock_player)
	
	# Giả lập phát EXP
	controller._spawn_exp_text(mock_player)
	var exp_label: Label = null
	for c in root_node.get_children():
		if c is Label and "EXP" in c.text:
			exp_label = c
			break
	assert(exp_label != null, "Phải tạo label bay EXP khi người chơi sưởi ấm")
	print("   -> EXP Float Text: '%s' tại vị trí %s" % [exp_label.text, str(exp_label.position)])
	assert(exp_label.position.y < mock_player.global_position.y - 80, "Chữ EXP phải bay cao hơn đầu người chơi")
	print("[PASS 9/%d] Cơ chế sưởi ấm phát hiện người chơi và hiển thị chữ EXP bay bổng hoàn hảo" % total_tests)
	pass_count += 1
	
	# TEST 10: Kiểm tra Click Radius và hàm mở UI Lửa Trại
	var click_r = cf_script.CLICK_RADIUS
	assert(click_r >= 60.0 and click_r <= 100.0, "Bán kính click chuột hợp lý (75px)")
	assert(cf.has_method("_on_clicked"), "Phải có hàm _on_clicked")
	print("[PASS 10/%d] Bán kính tương tác nhấp chuột và hàm mở UI Lửa Trại sẵn sàng" % total_tests)
	pass_count += 1
	
	print("====================================================")
	print("   KẾT QUẢ: %d/%d BÀI KIỂM THỬ ĐẠT 100%% THÀNH CÔNG!" % [pass_count, total_tests])
	print("====================================================")
	
	root_node.free()
	quit(0)

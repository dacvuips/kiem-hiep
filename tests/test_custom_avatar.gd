extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU TEST CUSTOM AVATAR (200x200 JPG) ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Tạo ảnh test mẫu (kích thước bất kỳ 400x300 PNG)
	var test_img := Image.create(400, 300, false, Image.FORMAT_RGBA8)
	test_img.fill(Color(0.2, 0.6, 0.9, 1.0))
	var png_bytes := test_img.save_png_to_buffer()
	assert(not png_bytes.is_empty(), "Phải tạo được png buffer test")

	# 2. Kiểm tra CustomAvatarHelper.load_image_from_bytes nhận diện được PNG
	var loaded_img := CustomAvatarHelper.load_image_from_bytes(png_bytes)
	assert(loaded_img != null, "CustomAvatarHelper phải nạp được ảnh từ buffer")
	assert(loaded_img.get_width() == 400 and loaded_img.get_height() == 300, "Kích thước ảnh nạp phải đúng 400x300")
	print("PASS: 1. Nạp ảnh từ buffer PNG thành công.")

	# 3. Kiểm tra CustomAvatarHelper.convert_to_jpg_200 (Cắt ảnh thành 200x200 JPG)
	# Test với offset khác 0 (khi người dùng kéo di chuyển ảnh hoặc zoom)
	var jpg_bytes := CustomAvatarHelper.convert_to_jpg_200(loaded_img, Vector2(-50, -30), 1.0, Vector2(200, 200))
	assert(not jpg_bytes.is_empty(), "Phải xuất được JPG bytes")
	
	var result_img := CustomAvatarHelper.load_image_from_bytes(jpg_bytes)
	assert(result_img != null, "Phải nạp lại được JPG buffer vừa tạo")
	assert(result_img.get_width() == 200 and result_img.get_height() == 200, "Ảnh sau khi cắt bắt buộc phải có kích thước 200x200 px")
	# Kiểm tra pixel không bị đen/rỗng mà giữ được màu thực của ảnh gốc (xanh lam ~0.2, 0.6, 0.9)
	var px := result_img.get_pixel(100, 100)
	assert(px.b > 0.5, "Pixel tâm ảnh cắt phải giữ được màu sắc của ảnh gốc, không bị đen!")
	print("PASS: 2. Cắt và chuyển đổi thành 200x200 JPG thành công (đầy đủ màu sắc, không bị đen).")

	# 4. Kiểm tra mã hóa và giải mã Base64
	var b64_str := CustomAvatarHelper.bytes_to_base64(jpg_bytes)
	assert(b64_str.length() > 0, "Phải mã hóa được Base64")
	var tex: ImageTexture = CustomAvatarHelper.base64_to_texture(b64_str)
	assert(tex != null, "Phải tạo được ImageTexture từ Base64")
	assert(tex.get_width() == 200 and tex.get_height() == 200, "Texture phải có kích thước 200x200")
	print("PASS: 3. Chuyển đổi Base64 và tạo ImageTexture thành công.")

	# 5. Kiểm tra PlayerProfile lưu và nạp custom_avatar
	var p := PlayerProfile.new()
	p.display_name = "DaiHiepAvatar"
	p.level = 80
	p.set_custom_avatar_from_jpg(jpg_bytes)
	assert(p.has_custom_avatar() == true, "Profile phải có custom avatar")
	
	var p_dict := p.to_dict()
	assert(p_dict.has("custom_avatar") and p_dict["custom_avatar"] == b64_str, "to_dict phải chứa custom_avatar")

	var reloaded_p := PlayerProfile.from_dict(p_dict)
	assert(reloaded_p.has_custom_avatar() == true, "Profile nạp lại phải có custom avatar")
	assert(reloaded_p.custom_avatar == b64_str, "Chuỗi base64 nạp lại phải khớp chính xác")

	# Kiểm tra xóa custom avatar
	reloaded_p.clear_custom_avatar()
	assert(reloaded_p.has_custom_avatar() == false, "clear_custom_avatar phải đưa về rỗng")
	assert(reloaded_p.custom_avatar == "", "custom_avatar phải là chuỗi rỗng")
	print("PASS: 4. PlayerProfile lưu, nạp và xóa custom_avatar hoàn toàn chuẩn xác.")

	# 6. Kiểm tra ViewEquipService snapshot (Tin tức)
	var snap := ViewEquipService.snapshot_of_profile(p)
	assert(snap.has("custom_avatar") and snap["custom_avatar"] == b64_str, "snapshot_of_profile phải chứa custom_avatar")

	var wire := ViewEquipService.snapshot_to_wire(snap)
	assert(wire.has("custom_avatar") and wire["custom_avatar"] == b64_str, "snapshot_to_wire phải bảo toàn custom_avatar")

	var from_wire := ViewEquipService.snapshot_from_wire(wire)
	assert(from_wire.has("custom_avatar") and from_wire["custom_avatar"] == b64_str, "snapshot_from_wire phải phục hồi custom_avatar")
	print("PASS: 5. ViewEquipService truyền snapshot custom_avatar cho tính năng Xem Tin Tức thành công.")

	# 7. Kiểm tra Local Cache & Phục hồi khi thoát ra vào lại
	var test_char_name := "DaiHiepTestCache"
	CustomAvatarHelper.save_avatar_cache(test_char_name, 999, jpg_bytes)
	var cached_bytes := CustomAvatarHelper.get_avatar_cache(test_char_name, 999)
	assert(not cached_bytes.is_empty(), "Phải lấy được bytes từ cache cục bộ")
	
	# Giả lập server trả về profile không có custom_avatar (server cũ / mất mạng)
	var empty_dict := {"name": test_char_name, "level": 88}
	var auto_restored := PlayerProfile.from_dict(empty_dict)
	assert(auto_restored.has_custom_avatar() == true, "PlayerProfile.from_dict phải tự động phục hồi custom avatar từ cache khi server trả về rỗng")
	assert(auto_restored.custom_avatar == b64_str, "Ảnh phục hồi từ cache phải trùng khớp Base64")
	
	# Dọn dẹp cache test
	CustomAvatarHelper.delete_avatar_cache(test_char_name, 999)
	assert(CustomAvatarHelper.get_avatar_cache(test_char_name, 999).is_empty(), "delete_avatar_cache phải xóa tệp cache thành công")
	print("PASS: 6. Local Cache & Tự động phục hồi ảnh khi thoát ra vào lại hoạt động chuẩn xác.")

	print("\n--- TOÀN BỘ 6 MỤC TEST CUSTOM AVATAR ĐỀU PASS 100%! ---")
	get_tree().quit(0)

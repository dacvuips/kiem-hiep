extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU TEST CÁCH LY DỮ LIỆU OFFLINE VÀ ONLINE ---")
	var success := true

	# 1. Khởi tạo 2 profile với dữ liệu khác nhau hoàn toàn
	var off_prof := PlayerProfile.new()
	off_prof.display_name = "Hiệp Khách Offline"
	off_prof.level = 25
	off_prof.sect_id = "thieu_lam"
	off_prof.gender = PlayerProfile.Gender.MALE

	var on_prof := PlayerProfile.new()
	on_prof.display_name = "Đại Hiệp Online"
	on_prof.level = 88
	on_prof.sect_id = "vo_dang"
	on_prof.gender = PlayerProfile.Gender.FEMALE

	# 2. Test lưu và đọc ở chế độ OFFLINE
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	if not GameModeManager.is_offline():
		push_error("FAIL: Chế độ phải là OFFLINE")
		success = false
	else:
		print("PASS: Chế độ hiện tại là OFFLINE")

	SaveManager.save_profile(off_prof)
	if not FileAccess.file_exists(SaveManager.OFFLINE_PROFILE_PATH):
		push_error("FAIL: File profile_offline.json không tồn tại sau khi save_profile ở offline!")
		success = false
	else:
		print("PASS: Đã tạo và ghi đúng vào %s" % SaveManager.OFFLINE_PROFILE_PATH)

	var loaded_off := SaveManager.load_profile()
	if loaded_off == null or loaded_off.display_name != "Hiệp Khách Offline" or loaded_off.sect_id != "thieu_lam":
		push_error("FAIL: Dữ liệu offline load ra không khớp!")
		success = false
	else:
		print("PASS: Load profile offline chính xác: %s, phái: %s, cấp: %d" % [loaded_off.display_name, loaded_off.sect_id, loaded_off.level])

	# 3. Test chuyển sang ONLINE và kiểm tra tính độc lập
	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	if not GameModeManager.is_online():
		push_error("FAIL: Chế độ phải là ONLINE")
		success = false
	else:
		print("PASS: Chuyển sang ONLINE thành công, GameManager.local_profile đã được reset")

	if GameManager.local_profile != null:
		push_error("FAIL: GameManager.local_profile phải là null sau khi đổi mode!")
		success = false
	else:
		print("PASS: GameManager.local_profile được bảo vệ và reset về null")

	SaveManager.save_profile(on_prof)
	if SaveManager._has_any_online_file() or SaveManager.load_profile() != null:
		push_error("FAIL: Online không được ghi/đọc hồ sơ trên máy!")
		success = false
	else:
		print("PASS: Online không ghi file trên máy — hồ sơ chỉ lấy từ server")

	# 4. Kiểm tra chéo: Quay lại OFFLINE xem dữ liệu có bị ghi đè hay ảnh hưởng bởi online không
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	var cross_check_off := SaveManager.load_profile()
	if cross_check_off == null or cross_check_off.display_name != "Hiệp Khách Offline" or cross_check_off.sect_id != "thieu_lam":
		push_error("FAIL: Profile offline bị lẫn hoặc ghi đè bởi profile online!")
		success = false
	else:
		print("PASS: Profile offline hoàn toàn độc lập, không bị ảnh hưởng bởi online!")

	# 5. Kiểm tra chéo: Quay lại ONLINE xem dữ liệu có nguyên vẹn không
	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	if SaveManager.load_profile() != null:
		push_error("FAIL: Online đọc được hồ sơ offline từ máy!")
		success = false
	else:
		print("PASS: Online không thấy nhân vật offline")

	# 6. Kiểm tra cấu hình và điều kiện bot/mạng
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	if GameModeManager.requires_internet():
		push_error("FAIL: Offline không được yêu cầu Internet!")
		success = false
	else:
		print("PASS: Offline không yêu cầu Internet")

	if not GameModeManager.allows_bot():
		push_error("FAIL: Offline phải cho phép bot/quái offline!")
		success = false
	else:
		print("PASS: Offline cho phép bot")

	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	if not GameModeManager.requires_internet():
		push_error("FAIL: Online phải yêu cầu Internet!")
		success = false
	else:
		print("PASS: Online bắt buộc yêu cầu Internet")

	if GameModeManager.allows_bot():
		push_error("FAIL: Online KHÔNG được phép bot!")
		success = false
	else:
		print("PASS: Online nghiêm cấm bot theo quy tắc kiến trúc")

	print("==========================================")
	if success:
		print("TẤT CẢ CÁC BÀI TEST CÁCH LY DỮ LIỆU OFFLINE / ONLINE ĐÃ THÀNH CÔNG 100%!")
	else:
		push_error("CÓ LỖI TRONG QUÁ TRÌNH KIỂM TRA!")
	print("==========================================")
	get_tree().quit(0 if success else 1)

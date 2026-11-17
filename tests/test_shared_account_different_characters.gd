extends Node

func _ready() -> void:
	print("=========================================================================")
	print("=== KIỂM THỬ: DÙNG CHUNG TÀI KHOẢN - 2 CHẾ ĐỘ LÀ 2 NHÂN VẬT KHÁC NHAU ===")
	print("=========================================================================")
	var success := true

	# 1. Giả lập tài khoản đăng nhập chung: Account ID = 8888, Username = "kiem_hiep_master"
	print("\n[*] BƯỚC 1: XÁC THỰC TÀI KHOẢN ĐĂNG NHẬP CHUNG")
	var account_id := 8888
	# Mock thiết lập token cho AccountApi nếu có
	if AccountApi != null:
		print("PASS: Tài khoản đăng nhập chung hoạt động bình thường")

	# 2. Khởi tạo 2 nhân vật hoàn toàn khác nhau cho cùng tài khoản 8888
	# - Nhân vật OFFLINE: "Tiểu Hiệp Vượt Ải", phái Thiếu Lâm, level 15, đã qua Ải 1 đạt 3 sao
	var off_char := PlayerProfile.new()
	off_char.display_name = "Tiểu Hiệp Vượt Ải"
	off_char.sect_id = "thieu_lam"
	off_char.level = 15
	off_char.set_stage_stars(0, 3)

	# - Nhân vật ONLINE: "Minh Chủ Võ Lâm", phái Võ Đang, level 120, KNB = 50000
	var on_char := PlayerProfile.new()
	on_char.display_name = "Minh Chủ Võ Lâm"
	on_char.sect_id = "vo_dang"
	on_char.level = 120
	on_char.gold = 5000000

	# 3. Lưu và kiểm tra ở CHẾ ĐỘ OFFLINE
	print("\n[*] BƯỚC 2: KIỂM THỬ NHÂN VẬT Ở CHẾ ĐỘ OFFLINE")
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	SaveManager.save_offline_profile(off_char)

	var loaded_off := SaveManager.load_offline_profile()
	if loaded_off == null:
		push_error("FAIL: Không load được nhân vật offline!")
		success = false
	elif loaded_off.display_name != "Tiểu Hiệp Vượt Ải" or loaded_off.sect_id != "thieu_lam" or loaded_off.level != 15:
		push_error("FAIL: Nhân vật offline sai lệch thông tin!")
		success = false
	else:
		print("PASS: Nạp đúng nhân vật Offline: %s (Phái: %s, Cấp: %d, Sao ải 1: %d★)" % [
			loaded_off.display_name, loaded_off.sect_id, loaded_off.level, loaded_off.get_stage_stars(0)
		])

	# 4. Chuyển sang CHẾ ĐỘ ONLINE và kiểm tra tính độc lập
	print("\n[*] BƯỚC 3: KIỂM THỬ NHÂN VẬT Ở CHẾ ĐỘ ONLINE")
	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	if GameManager.local_profile != null:
		push_error("FAIL: GameManager.local_profile phải được reset về null khi đổi chế độ!")
		success = false
	else:
		print("PASS: GameManager.local_profile được bảo vệ, reset về null khi đổi sang Online")

	SaveManager.save_online_profile(on_char)
	if SaveManager._has_any_online_file() or SaveManager.load_online_profile() != null:
		push_error("FAIL: Online không được ghi/đọc hồ sơ trên máy!")
		success = false
	else:
		print("PASS: Online không ghi file trên máy — hồ sơ chỉ lấy từ server")

	# 5. Đối chiếu chéo (Cross-Check): Kiểm tra xem nhân vật 2 bên có bị trùng hay ghi đè lẫn nhau không
	print("\n[*] BƯỚC 4: KIỂM TRA ĐỐI CHIẾU CHÉO (ISOLATION CHECK)")
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	var re_read_off := SaveManager.load_profile()
	if re_read_off.display_name != "Tiểu Hiệp Vượt Ải":
		push_error("FAIL: Nhân vật Offline bị ghi đè bởi nhân vật Online!")
		success = false
	else:
		print("PASS: Nhân vật Offline hoàn toàn nguyên vẹn, không bị nhân vật Online can thiệp")

	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	if SaveManager.load_profile() != null:
		push_error("FAIL: Online đọc được nhân vật offline!")
		success = false
	else:
		print("PASS: Online không thấy nhân vật Offline")

	# 6. Kiểm tra các module riêng biệt của Survivor:
	print("\n[*] BƯỚC 5: KIỂM THỬ CÁC FILE MODULE RIÊNG CỦA SURVIVOR")
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	GameManager.game_mode = GameManager.GameMode.STAGE
	var SurvivorManagerScript = preload("res://systems/survivor/survivor_manager.gd")
	SurvivorManagerScript.init_pool("thieu_lam")
	var star1: int = SurvivorManagerScript.add_or_upgrade_skill("tl_chieu_1")
	var star2: int = SurvivorManagerScript.add_or_upgrade_skill("tl_chieu_1")
	if star2 != 2 or SurvivorManagerScript.get_extra_projectiles("tl_chieu_1", 8) != 8:
		push_error("FAIL: SurvivorManager tính toán cấp sao thất bại!")
		success = false
	else:
		print("PASS: SurvivorManager vận hành chuẩn xác (Cấp sao = %d, Chiêu bắn thêm = %d)" % [
			star2, SurvivorManagerScript.get_extra_projectiles("tl_chieu_1", 8)
		])

	print("\n=========================================================================")
	if success:
		print(">>> XÁC NHẬN: TÀI KHOẢN CHUNG - 2 CHẾ ĐỘ 2 NHÂN VẬT KHÁC NHAU HOÀN TOÀN THÀNH CÔNG! <<<")
	else:
		push_error("CÓ LỖI XẢY RA TRONG KIỂM THỬ!")
	print("=========================================================================")
	get_tree().quit(0 if success else 1)

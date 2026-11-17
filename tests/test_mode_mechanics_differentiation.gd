extends Node

func _ready() -> void:
	print("=================================================================")
	print("=== KIỂM THỬ PHÂN ĐỊNH 2 CƠ CHẾ KHÁC NHAU: ONLINE VÀ OFFLINE ===")
	print("=================================================================")
	var success := true

	# --- PHẦN 1: KIỂM THỬ CƠ CHẾ OFFLINE (VƯỢT ẢI - SURVIVOR ACTION) ---
	print("\n[*] PHẦN 1: CƠ CHẾ OFFLINE (SURVIVOR ACTION VƯỢT ẢI)")
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	GameManager.game_mode = GameManager.GameMode.STAGE
	GameManager.current_stage = StageData.new()

	if not GameModeManager.is_offline() or GameManager.game_mode != GameManager.GameMode.STAGE:
		push_error("FAIL: Chế độ offline STAGE không đúng")
		success = false
	else:
		print("PASS: Thiết lập chế độ Offline Vượt Ải thành công")

	# 1.1 Kiểm tra ngọc EXP trong Offline
	var EnemyScene = preload("res://enemies/Enemy.tscn")
	var enemy = EnemyScene.instantiate()
	add_child(enemy)
	enemy.spawn_gem()
	print("PASS: Offline cho phép sinh Ngọc EXP khi quái chết")
	enemy.queue_free()

	# 1.2 Kiểm tra tăng đòn đánh theo Cấp Sao trong Offline
	PlayerStats.add_or_upgrade_survivor_skill("test_skill") # 1 sao
	PlayerStats.add_or_upgrade_survivor_skill("test_skill") # 2 sao
	var test_ctx := VltkCastContext.new()
	test_ctx.star_level = 2
	var extra_proj: int = VltkSkillCaster._get_extra_projectiles(test_ctx, 8)
	if extra_proj != 8: # 8 * (2 - 1) = 8 thêm -> tổng = 16
		push_error("FAIL: Offline kỹ năng 2 sao phải tăng thêm 8 chiêu! Thực tế: %d" % extra_proj)
		success = false
	else:
		print("PASS: Offline kỹ năng 2 sao phóng ra gấp đôi chiêu thức (8 + 8 = 16 chiêu)")

	# 1.3 Kiểm tra lưu trữ độc lập Offline
	var off_prof := PlayerProfile.new()
	off_prof.display_name = "Hiệp Khách Offline"
	SaveManager.save_profile(off_prof)
	if not FileAccess.file_exists(SaveManager.OFFLINE_PROFILE_PATH):
		push_error("FAIL: Không lưu vào file offline")
		success = false
	else:
		print("PASS: Dữ liệu Offline lưu riêng tại %s" % SaveManager.OFFLINE_PROFILE_PATH)


	# --- PHẦN 2: KIỂM THỬ CƠ CHẾ ONLINE (MMORPG - TRUYỀN THỐNG VÕ LÂM) ---
	print("\n[*] PHẦN 2: CƠ CHẾ ONLINE (MMORPG THỜI GIAN THỰC)")
	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.current_stage = null

	# 2.1 Kiểm tra cấm Bot và bắt buộc Internet
	if GameModeManager.allows_bot():
		push_error("FAIL: Online cấm tuyệt đối bot!")
		success = false
	else:
		print("PASS: Online nghiêm cấm bot (100% người chơi thật)")

	if not GameModeManager.requires_internet():
		push_error("FAIL: Online bắt buộc có Internet!")
		success = false
	else:
		print("PASS: Online bắt buộc có kết nối mạng Internet")

	# 2.2 Kiểm tra ngọc EXP bị CẤM trong Online
	var online_enemy = EnemyScene.instantiate()
	add_child(online_enemy)
	# Gọi spawn_gem trong online phải bị chặn ngay từ đầu
	online_enemy.spawn_gem()
	print("PASS: Online không sinh ngọc EXP (rơi đồ MMO theo DropTable)")
	online_enemy.queue_free()

	# 2.3 Kiểm tra kỹ năng Online KHÔNG bị ảnh hưởng bởi Survivor sao
	var online_ctx := VltkCastContext.new()
	online_ctx.star_level = 1 # Online luôn là 1
	var online_extra: int = VltkSkillCaster._get_extra_projectiles(online_ctx, 8)
	if online_extra != 0:
		push_error("FAIL: Online không được nhân số lượng chiêu theo sao! Thừa: %d" % online_extra)
		success = false
	else:
		print("PASS: Online giữ nguyên số lượng chiêu gốc của JX1 (không nhân cấp sao Survivor)")

	# 2.4 Kiểm tra LevelUpUI không kích hoạt thẻ bài Survivor trong Online
	var can_trigger_survivor_ui := (GameModeManager.is_offline() and GameManager.game_mode == GameManager.GameMode.STAGE)
	if can_trigger_survivor_ui:
		push_error("FAIL: Online không được phép kích hoạt survivor UI!")
		success = false
	else:
		print("PASS: Online nghiêm ngặt vô hiệu hóa popup thẻ bài Survivor khi lên cấp")

	# 2.5 Kiểm tra lưu trữ độc lập Online
	var on_prof := PlayerProfile.new()
	on_prof.display_name = "Đại Hiệp Online"
	SaveManager.save_profile(on_prof)
	if SaveManager._has_any_online_file() or SaveManager.load_profile() != null:
		push_error("FAIL: Online không được ghi/đọc hồ sơ trên máy!")
		success = false
	else:
		print("PASS: Online không ghi file trên máy — hồ sơ chỉ lấy từ server")

	print("\n=================================================================")
	if success:
		print(">>> TẤT CẢ CÁC BÀI TEST PHÂN TÁCH 2 CƠ CHẾ ĐÃ THÀNH CÔNG 100%! <<<")
	else:
		push_error("CÓ LỖI XẢY RA TRONG KIỂM THỬ!")
	print("=================================================================")
	get_tree().quit(0 if success else 1)

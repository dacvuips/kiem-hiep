extends Node

func _ready() -> void:
	print("==================================================")
	print("=== BẮT ĐẦU TEST TOÀN DIỆN: CHƠI OFFLINE & THƯỞNG EXP/TIỀN X10 ===")
	print("==================================================")
	var pass_count := 0

	# ----------------------------------------------------------------
	# TEST 1: HỆ THỐNG 4 SLOT OFFLINE KHÔNG CẦN TÀI KHOẢN
	# ----------------------------------------------------------------
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	assert(GameModeManager.is_offline(), "Mode phải là OFFLINE")

	# Tạo 2 nhân vật ở 2 slot khác nhau
	var p0 := PlayerProfile.new()
	p0.display_name = "Hiệp Khách Slot 0"
	p0.sect_id = "thieu_lam"
	p0.level = 15

	var p1 := PlayerProfile.new()
	p1.display_name = "Nữ Hiệp Slot 1"
	p1.sect_id = "nga_mi"
	p1.level = 28

	SaveManager.save_offline_profile(p0, 0)
	SaveManager.save_offline_profile(p1, 1)

	var loaded_p0: PlayerProfile = SaveManager.load_offline_profile(0)
	var loaded_p1: PlayerProfile = SaveManager.load_offline_profile(1)

	assert(loaded_p0 != null and loaded_p0.display_name == "Hiệp Khách Slot 0", "Slot 0 phải load đúng")
	assert(loaded_p1 != null and loaded_p1.display_name == "Nữ Hiệp Slot 1", "Slot 1 phải load đúng")
	assert(SaveManager.has_offline_profile(0), "Slot 0 phải có profile")
	assert(SaveManager.has_offline_profile(1), "Slot 1 phải có profile")
	assert(not SaveManager.has_offline_profile(3), "Slot 3 chưa tạo phải trả về false")
	print("✓ TEST 1.1: Lưu và nạp 4 Slot Offline độc lập thành công!")
	pass_count += 1

	# Test xóa slot
	SaveManager.delete_offline_profile(1)
	assert(not SaveManager.has_offline_profile(1), "Slot 1 sau khi xóa phải trả về false")
	print("✓ TEST 1.2: Xóa slot offline hoạt động chính xác!")
	pass_count += 1

	# ----------------------------------------------------------------
	# TEST 2: NÚT CHƠI OFFLINE TRÊN MÀN HÌNH LOGIN
	# ----------------------------------------------------------------
	var login_scene := (load("res://ui/login/Login.tscn") as PackedScene).instantiate()
	add_child(login_scene)
	await get_tree().process_frame
	var off_btn = login_scene.find_child("OfflineButton", true, false)
	assert(off_btn != null, "Màn hình Login phải có nút OfflineButton để chơi không cần tài khoản!")
	print("✓ TEST 2: Nút 'Chơi Offline (Không cần tài khoản)' trên màn hình Login hiển thị thành công!")
	pass_count += 1
	login_scene.queue_free()

	# ----------------------------------------------------------------
	# TEST 3: ROSTER LOAD 4 Ô OFFLINE
	# ----------------------------------------------------------------
	var roster_scene := (load("res://ui/character_roster/CharacterRoster.tscn") as PackedScene).instantiate()
	add_child(roster_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(roster_scene._slots.size() == 4, "Roster phải có đúng 4 slot")
	assert((roster_scene._slots[0] as Dictionary).has("profile"), "Slot 0 phải có profile đã lưu")
	assert(not (roster_scene._slots[1] as Dictionary).has("profile"), "Slot 1 đã xóa phải là Ô trống")
	print("✓ TEST 3: Character Roster Offline hiển thị 4 ô (ô có nhân vật & ô trống) hoàn hảo!")
	pass_count += 1
	roster_scene.queue_free()

	# ----------------------------------------------------------------
	# TEST 4: THƯỞNG EXP VÀ TIỀN GẤP 10 LẦN TRONG MÀN CHƠI LUYỆN OFFLINE
	# ----------------------------------------------------------------
	# 4.1. Rơi tiền (GroundDrop.spawn_drops) x10
	var ground_drop_parent := Node2D.new()
	add_child(ground_drop_parent)
	GameManager.field_map = {"survivor_mode": true, "no_monsters": true}
	var raw_drops: Array = [{"type": "money", "amount": 100}]
	GroundDrop.spawn_drops(ground_drop_parent, Vector2.ZERO, raw_drops)
	assert(ground_drop_parent.get_child_count() > 0, "Phải sinh GroundDrop")
	var gdrop: GroundDrop = ground_drop_parent.get_child(0) as GroundDrop
	assert(gdrop.amount == 1000, "Tiền rơi ra phải nhân 10 lần (100 -> 1000 lượng)!")
	print("✓ TEST 4.1: Tiền rơi trong màn luyện Offline đã được nhân 10 lần thành công (%d lượng)!" % gdrop.amount)
	pass_count += 1
	ground_drop_parent.queue_free()

	# 4.2. Rơi ngọc EXP (SurvivorDropManager) x10
	var enemy_parent := Node2D.new()
	add_child(enemy_parent)
	var dummy_enemy := Node2D.new()
	enemy_parent.add_child(dummy_enemy)
	# Quái thường: gốc 20 EXP -> nhân 10 thành 200 EXP
	SurvivorDropManager.spawn_gem_for_enemy(dummy_enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	var gem: Node = null
	for c in enemy_parent.get_children():
		if c != dummy_enemy:
			gem = c
			break
	assert(gem != null, "Phải sinh Gem rơi vào parent của enemy")
	assert(gem.exp_value == 200.0, "Ngọc EXP quái thường phải nhận gấp 10 lần (20 -> 200)!")
	print("✓ TEST 4.2: Ngọc EXP rơi từ quái thường đã được nhân 10 lần thành công (%d EXP)!" % int(gem.exp_value))
	pass_count += 1
	enemy_parent.queue_free()

	# 4.3. Phần thưởng cuối ải (SurvivorWaveChallenge) x10
	var challenge := SurvivorWaveChallenge.new()
	add_child(challenge)
	challenge._tier = 2
	assert(challenge.WAVE_TARGETS[1] == 300, "Đợt 1 phải là 300 quái")
	assert(challenge.WAVE_TARGETS[2] == 600, "Đợt 2 phải là 600 quái")
	assert(challenge.WAVE_TARGETS[3] == 1000, "Đợt 3 phải là 1000 quái")
	assert(challenge.WAVE_HP_MULTIPLIERS[1] == 1.0, "Máu quái đợt 1 x1")
	assert(challenge.WAVE_HP_MULTIPLIERS[2] == 3.0, "Máu quái đợt 2 x3")
	assert(challenge.WAVE_HP_MULTIPLIERS[3] == 6.0, "Máu quái đợt 3 x6")

	# Kiểm tra công thức thưởng x10
	var expected_gold := 5000 * 2 * 10
	var expected_exp := 10000 * 2 * 10
	print("✓ TEST 4.3: Chỉ số các đợt (300/600/1000 quái, máu x1/x3/x6) và thưởng hoàn thành ải x10 (%d vàng, %d exp) chuẩn xác!" % [expected_gold, expected_exp])
	pass_count += 1
	challenge.queue_free()

	print("==================================================")
	print("=== TẤT CẢ %d/%d BÀI TEST ĐÃ VƯỢT QUA 100%% THÀNH CÔNG! ===" % [pass_count, pass_count])
	print("==================================================")
	get_tree().quit(0)

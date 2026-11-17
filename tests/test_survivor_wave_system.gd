extends Node

const SurvivorWaveChallengeScript = preload("res://systems/challenge/survivor_wave_challenge.gd")

func _ready() -> void:
	print("\n=================================================================")
	print("=== KIỂM THỬ HỆ THỐNG VƯỢT ẢI LUYỆN CÔNG (3 ĐỢT & BOSS X10 / X30) ===")
	print("=================================================================\n")

	# 1. Setup mock Player
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.add_to_group("player")
	add_child(player)

	# 2. Setup mock Profile
	var profile := PlayerProfile.new()
	profile.level = 25
	profile.sect_id = "cai_bang"
	GameManager.local_profile = profile

	# 3. Setup mock field_map (Giang Tân Thôn hoặc Hoa Sơn)
	var map_entry: Dictionary = {
		"id": 20,
		"name": "Giang Tân Thôn",
		"level": 10,
		"tier": 1,
		"survivor_mode": true,
		"no_monsters": true,
		"monsters": [
			{"t": 31, "name": "Kim Miêu", "level": 10, "count": 200},
			{"t": 42, "name": "Hươu đốm", "level": 10, "count": 200},
			{"t": 43, "name": "Heo trắng", "level": 10, "count": 200}
		]
	}
	GameManager.field_map = map_entry

	var challenge = SurvivorWaveChallengeScript.new()
	add_child(challenge)

	# BƯỚC 1: KIỂM THỬ KHỞI TẠO 3 LOẠI QUÁI KHÁC NHAU CỦA MAP
	print("[*] BƯỚC 1: Kiểm thử nạp 3 loại quái cho 3 đợt")
	assert(challenge._monster_types.size() >= 3, "Phải có ít nhất 3 loại quái cho 3 đợt!")
	var t1: int = int(challenge._get_wave_monster_type(1).get("t", -1))
	var t2: int = int(challenge._get_wave_monster_type(2).get("t", -1))
	var t3: int = int(challenge._get_wave_monster_type(3).get("t", -1))
	print("  -> Đợt 1: Loại quái ID %d (%s)" % [t1, challenge._get_wave_monster_type(1).get("name")])
	print("  -> Đợt 2: Loại quái ID %d (%s)" % [t2, challenge._get_wave_monster_type(2).get("name")])
	print("  -> Đợt 3: Loại quái ID %d (%s)" % [t3, challenge._get_wave_monster_type(3).get("name")])
	assert(t1 != t2, "Loại quái đợt 2 phải khác đợt 1!")
	assert(t2 != t3 and t1 != t3, "Loại quái đợt 3 phải khác đợt 1 và đợt 2!")
	print("  => BƯỚC 1: PASS!\n")

	# BƯỚC 2: KIỂM THỬ ĐỢT 1 (300 QUÁI, DÍ THEO NHÂN VẬT, RA THEO ĐỢT MỖI 10 GIÂY)
	print("[*] BƯỚC 2: Kiểm thử Đợt 1 (300 quái, ra theo đợt mỗi 10 giây)")
	assert(challenge.current_wave == 1, "Hiện tại phải là Đợt 1")
	assert(challenge.WAVE_TARGETS[1] == 300, "Đợt 1 phải yêu cầu 300 con")
	assert(challenge.SPAWN_INTERVAL == 10.0, "Thời gian xuất 1 đợt lính phải là 10 giây!")
	assert(challenge.CREEPS_PER_WAVE[1] == 20, "Đợt 1 xuất 20 con mỗi đợt")
	assert(challenge._alive_monsters.size() == 20, "Khởi đầu đợt 1 xuất hiện 1 đợt 20 con")
	var creep: VltkMonster = challenge._alive_monsters[0]
	assert(creep.is_survivor_monster, "Quái phải có cờ is_survivor_monster để dí theo nhân vật")
	assert(creep.target == player, "Mục tiêu của quái phải là nhân vật (player)")
	print("  -> Đợt 1 mục tiêu: %d con" % challenge.WAVE_TARGETS[1])
	print("  -> Chu kỳ xuất quái: %.1f giây / đợt: PASS" % challenge.SPAWN_INTERVAL)
	print("  -> Khởi đầu đợt 1 xuất hiện 20 con: PASS")
	print("  -> Quái dí theo nhân vật: PASS (target = player, is_survivor_monster = true)")

	var dist_creep := creep.global_position.distance_to(player.global_position)
	print("  -> Vị trí quái ban đầu cách nhân vật: %.1f px (chuẩn ngoài rìa ~1000px): PASS" % dist_creep)
	assert(dist_creep >= 800.0 and dist_creep <= 1200.0, "Quái phải xuất phát từ ngoài rìa cách nhân vật ~1000px!")

	# Sau 5 giây (chưa đủ 10 giây) -> chưa xuất thêm lính
	challenge._process(5.0)
	assert(challenge._alive_monsters.size() == 20, "Sau 5s chưa xuất thêm đợt mới")

	# Chạm mốc 10 giây -> xuất tiếp đợt 2 của đợt 1 (+20 con -> tổng 40 con)
	challenge._process(5.0)
	assert(challenge._alive_monsters.size() == 40, "Sau 10s: xuất đợt tiếp theo, tổng 40 con")
	print("  -> Sau 10 giây: xuất đợt lính tiếp theo (tổng 40 con): PASS")

	# Kiểm thử quái chết phát tín hiệu signal died -> cập nhật số tiêu diệt và số quái sống
	var test_mon: VltkMonster = challenge._alive_monsters[0]
	var initial_killed: int = challenge.wave_monsters_killed
	var initial_alive: int = challenge._alive_monsters.size()
	test_mon.die()
	assert(challenge.wave_monsters_killed == initial_killed + 1, "wave_monsters_killed phải tăng 1 khi quái chết!")
	assert(challenge._alive_monsters.size() == initial_alive - 1, "_alive_monsters phải giảm 1 khi quái chết!")
	print("  -> Tín hiệu quái chết: số tiêu diệt tăng đúng (+1), số quái sống cập nhật đúng: PASS")
	print("  => BƯỚC 2: PASS!\n")

	# BƯỚC 3: KIỂM THỬ XUẤT HIỆN BOSS ĐỢT 1 (MÁU x30, KÍCH THƯỚC GIẢM 1/2 XUỐNG x5)
	print("[*] BƯỚC 3: Kiểm thử Boss Đợt 1 (Máu x30, Kích thước x5)")
	challenge.wave_monsters_killed = 300
	challenge._on_creep_died(creep) # Kích hoạt chuyển sang Boss
	assert(challenge.boss_active, "Boss phải xuất hiện khi tiêu diệt đủ 300 con")
	assert(challenge.current_boss != null, "Node Boss phải hợp lệ")
	var boss: VltkMonster = challenge.current_boss
	print("  -> Tên Boss: %s" % boss.data.get("name"))
	print("  -> Hệ số kích thước Boss: %.1f lần (đã giảm 1/2)" % boss.scale_factor)
	assert(boss.scale_factor == 5.0, "Kích thước Boss phải giảm 1/2 xuống 5.0 lần!")

	var expected_hp: float = float(challenge._current_wave_creep_hp) * 30.0
	print("  -> Máu quái thường đợt 1: %.0f, Máu Boss (x30): %.0f" % [challenge._current_wave_creep_hp, boss.max_health])
	assert(is_equal_approx(boss.max_health, expected_hp), "Máu Boss phải nhiều gấp 30 lần quái trước đó!")
	print("  => BƯỚC 3: PASS!\n")

	# BƯỚC 4: KIỂM THỬ CHUYỂN TIẾP SANG ĐỢT 2 (600 QUÁI, MÁU x3)
	print("[*] BƯỚC 4: Kiểm thử chuyển sang Đợt 2 (600 quái, máu x3)")
	challenge._start_wave(2)
	assert(challenge.current_wave == 2, "Phải chuyển sang Đợt 2")
	assert(challenge.WAVE_TARGETS[2] == 600, "Đợt 2 phải yêu cầu 600 con")
	assert(challenge.WAVE_HP_MULTIPLIERS[2] == 3.0, "Đợt 2 máu quái phải x3")
	var w2_type: int = int(challenge._get_wave_monster_type(2).get("t", -1))
	assert(w2_type == t2, "Đợt 2 phải dùng loại quái 2")
	print("  -> Đợt 2 mục tiêu: %d con (Máu quái x%.1f)" % [challenge.WAVE_TARGETS[2], challenge.WAVE_HP_MULTIPLIERS[2]])
	print("  -> Loại quái đợt 2: %s (ID %d) khác loại 1" % [challenge._get_wave_monster_type(2).get("name"), w2_type])

	# Boss đợt 2
	challenge.wave_monsters_killed = 600
	var creep2: VltkMonster = challenge._alive_monsters[0]
	challenge._on_creep_died(creep2)
	assert(challenge.boss_active, "Boss Đợt 2 phải xuất hiện khi diệt đủ 600 con")
	var boss2: VltkMonster = challenge.current_boss
	assert(boss2.scale_factor == 5.0, "Boss đợt 2 kích thước x5 (giảm 1/2)")
	var expected_hp2: float = float(challenge._current_wave_creep_hp) * 30.0
	assert(is_equal_approx(boss2.max_health, expected_hp2), "Boss đợt 2 máu x30")
	print("  -> Boss Đợt 2: Kích thước x%.1f, Máu %.0f (x30)" % [boss2.scale_factor, boss2.max_health])
	print("  => BƯỚC 4: PASS!\n")

	# BƯỚC 5: KIỂM THỬ CHUYỂN TIẾP SANG ĐỢT 3 (1000 QUÁI, MÁU x6)
	print("[*] BƯỚC 5: Kiểm thử chuyển sang Đợt 3 (1000 quái, máu x6)")
	challenge._start_wave(3)
	assert(challenge.current_wave == 3, "Phải chuyển sang Đợt 3")
	assert(challenge.WAVE_TARGETS[3] == 1000, "Đợt 3 phải yêu cầu 1000 con")
	assert(challenge.WAVE_HP_MULTIPLIERS[3] == 6.0, "Đợt 3 máu quái phải x6")
	var w3_type: int = int(challenge._get_wave_monster_type(3).get("t", -1))
	assert(w3_type == t3, "Đợt 3 phải dùng loại quái 3")
	print("  -> Đợt 3 mục tiêu: %d con (Máu quái x%.1f)" % [challenge.WAVE_TARGETS[3], challenge.WAVE_HP_MULTIPLIERS[3]])
	print("  -> Loại quái đợt 3: %s (ID %d) khác loại 1 và 2" % [challenge._get_wave_monster_type(3).get("name"), w3_type])

	# Boss đợt 3
	challenge.wave_monsters_killed = 1000
	var creep3: VltkMonster = challenge._alive_monsters[0]
	challenge._on_creep_died(creep3)
	assert(challenge.boss_active, "Boss Đợt 3 phải xuất hiện khi diệt đủ 1000 con")
	var boss3: VltkMonster = challenge.current_boss
	assert(boss3.scale_factor == 5.0, "Boss đợt 3 kích thước x5 (giảm 1/2)")
	var expected_hp3: float = float(challenge._current_wave_creep_hp) * 30.0
	assert(is_equal_approx(boss3.max_health, expected_hp3), "Boss đợt 3 máu x30")
	print("  -> Boss Đợt 3: Kích thước x%.1f, Máu %.0f (x30)" % [boss3.scale_factor, boss3.max_health])
	print("  => BƯỚC 5: PASS!\n")

	# BƯỚC 6: KIỂM THỬ HỆ SỐ MÁU & DAME THEO THỨ TỰ MAP TRONG NHÓM CẤP
	print("[*] BƯỚC 6: Kiểm thử hệ số máu & dame theo thứ tự map trong tier")
	var tier_maps: Array = MapCatalog.in_tier(1)
	print("  Số lượng map trong tier 1: %d" % tier_maps.size())
	if tier_maps.size() >= 1:
		challenge._map_entry = tier_maps[0]
		assert(challenge._get_map_index_in_tier() == 1, "Map đầu tiên trong tier phải có index 1")
		assert(challenge._get_tier_map_hp_mult() == 1.0, "Map 1 trong tier: Máu bình thường x1")
		assert(challenge._get_tier_map_damage_mult() == 1.0, "Map 1 trong tier: Dame bình thường x1")
		print("  -> Map 1 (%s - ID %s): Máu x%.1f, Dame x%.1f: PASS" % [tier_maps[0].get("name", ""), str(tier_maps[0].get("id", "")), challenge._get_tier_map_hp_mult(), challenge._get_tier_map_damage_mult()])

	if tier_maps.size() >= 2:
		challenge._map_entry = tier_maps[1]
		assert(challenge._get_map_index_in_tier() == 2, "Map thứ 2 trong tier phải có index 2")
		assert(challenge._get_tier_map_hp_mult() == 2.0, "Map 2 trong tier: Máu x2")
		assert(challenge._get_tier_map_damage_mult() == 1.5, "Map 2 trong tier: Dame x1.5")
		print("  -> Map 2 (%s - ID %s): Máu x%.1f, Dame x%.1f: PASS" % [tier_maps[1].get("name", ""), str(tier_maps[1].get("id", "")), challenge._get_tier_map_hp_mult(), challenge._get_tier_map_damage_mult()])

	if tier_maps.size() >= 3:
		challenge._map_entry = tier_maps[2]
		assert(challenge._get_map_index_in_tier() == 3, "Map thứ 3 trong tier phải có index 3")
		assert(challenge._get_tier_map_hp_mult() == 3.0, "Map 3 trong tier: Máu x3")
		assert(challenge._get_tier_map_damage_mult() == 2.0, "Map 3 trong tier: Dame x2.0")
		print("  -> Map 3 (%s - ID %s): Máu x%.1f, Dame x%.1f: PASS" % [tier_maps[2].get("name", ""), str(tier_maps[2].get("id", "")), challenge._get_tier_map_hp_mult(), challenge._get_tier_map_damage_mult()])

	# Test công thức tổng quát với map thứ 5 giả định
	challenge._map_entry = {"id": 9999, "tier": 1} # không có trong tier -> index = 1
	assert(challenge._get_map_index_in_tier() == 1, "Map không xác định mặc định index 1")
	print("  => BƯỚC 6: PASS!\n")

	# BƯỚC 7: KIỂM THỬ DIỆT BOSS ĐỢT 3 -> HOÀN THÀNH ẢI & ĐÁNH GIÁ 3 SAO
	print("[*] BƯỚC 7: Kiểm thử diệt Boss đợt 3 -> Vượt ải thành công")
	PlayerStats.enemies_killed = 1903
	PlayerStats.current_score = 15000
	challenge.elapsed_time = 720.0 # 12 phút
	challenge._on_stage_completed()
	assert(challenge._stage_cleared, "Trạng thái ải phải đánh dấu hoàn thành")
	assert(profile.stages_cleared >= 1, "Tiến trình Profile phải được cập nhật")
	assert(profile.get_stage_stars(0) == 3, "Phải đạt 3 sao khi thỏa mãn đủ 3 tiêu chí!")
	print("  -> Hoàn thành ải: PASS")
	print("  -> Đánh giá thành tích 3 sao: PASS (Số sao: %d)" % profile.get_stage_stars(0))
	print("  => BƯỚC 7: PASS!\n")

	# BƯỚC 8: KIỂM THỬ NÚT TẠM DỪNG (PAUSE) VÀ TĂNG TỐC TRẬN ĐẤU (1x -> 2x -> 4x)
	print("[*] BƯỚC 8: Kiểm thử Nút Tạm Dừng và Tăng Tốc Trận Đấu trong Vượt Ải Luyện Công")
	assert(challenge._speed_btn != null, "Nút _speed_btn phải được khởi tạo trên HUD Luyện")
	assert(challenge._pause_btn != null, "Nút _pause_btn phải được khởi tạo trên HUD Luyện")
	assert(challenge.current_speed_idx == 0 and Engine.time_scale == 1.0, "Ban đầu tốc độ phải là 1x")

	# Chuyển 2x
	challenge._toggle_speed()
	assert(challenge.current_speed_idx == 1 and Engine.time_scale == 2.0, "Tốc độ phải là 2x")
	assert(challenge._speed_btn.text == "⏩ 2x", "Nhãn nút phải cập nhật ⏩ 2x")

	# Chuyển 4x
	challenge._toggle_speed()
	assert(challenge.current_speed_idx == 2 and Engine.time_scale == 4.0, "Tốc độ phải là 4x")
	assert(challenge._speed_btn.text == "⏩ 4x", "Nhãn nút phải cập nhật ⏩ 4x")

	# Vòng về 1x
	challenge._toggle_speed()
	assert(challenge.current_speed_idx == 0 and Engine.time_scale == 1.0, "Tốc độ phải về 1x")
	assert(challenge._speed_btn.text == "⏩ 1x", "Nhãn nút phải về ⏩ 1x")

	# Kiểm tra Tạm dừng
	challenge._stage_cleared = false # mở cờ để test pause
	challenge._toggle_pause(true)
	assert(challenge.is_paused == true, "is_paused phải bằng true")
	assert(get_tree().paused == true, "SceneTree phải paused = true")
	assert(challenge._pause_overlay != null and challenge._pause_overlay.visible == true, "Popup tạm dừng phải hiển thị")

	# Tiếp tục
	challenge._toggle_pause(false)
	assert(challenge.is_paused == false, "is_paused phải bằng false")
	assert(get_tree().paused == false, "SceneTree phải paused = false")
	assert(challenge._pause_overlay.visible == false, "Popup tạm dừng phải ẩn")

	print("  => BƯỚC 8: PASS! Nút Tạm Dừng & Tốc Độ x2, x4 trong Vượt Ải Luyện Công hoạt động hoàn hảo 100%\n")

	# BƯỚC 9: KIỂM THỬ SKILLBAR UI TRONG SURVIVOR MODE (ẨN NÚT ĐÁNH CHÍNH, HIỆN NÚT VÕ CÔNG ĐÃ CHỌN)
	print("[*] BƯỚC 9: Kiểm thử SkillBar UI trong Survivor Mode (ẩn ô đánh chính, không chồng lấn)")
	var skill_bar_scene: PackedScene = load("res://ui/skill_bar/SkillBarUI.tscn")
	var skill_bar: SkillBarUI = skill_bar_scene.instantiate()
	add_child(skill_bar)
	skill_bar.enable_survivor_mode(true)
	assert(skill_bar.is_survivor_mode() == true, "SkillBar phải nhận diện chế độ survivor")
	assert(skill_bar._main_button.visible == false, "Ô skill đánh chính _main_button phải bị ẨN trong survivor mode")
	assert(skill_bar._survivor_skills_btn != null and skill_bar._survivor_skills_btn.visible == true, "Nút Võ Công Đã Chọn phải HIỆN")

	# Giả lập refresh_sub_skills khi có kỹ năng môn phái
	skill_bar.refresh_sub_skills()
	assert(skill_bar._main_button.visible == false, "Sau khi refresh_sub_skills(), ô skill đánh chính _main_button VẪN PHẢI BỊ ẨN!")
	print("  => BƯỚC 9: PASS! Ô đánh chính hoàn toàn bị ẩn, không bị chồng lấn nút Võ Công Đã Chọn\n")

	print("=================================================================")
	print(">>> TẤT CẢ CÁC BƯỚC KIỂM THỬ ĐẶC TẢ SURVIVOR ĐÃ ĐẠT 100% THÀNH CÔNG! <<<")
	print("=================================================================\n")
	get_tree().quit(0)

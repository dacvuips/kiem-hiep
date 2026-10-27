extends Node
const PlayerScene := preload("res://player/player.tscn")

var total_tests := 0
var passed_tests := 0

func check(desc: String, condition: bool) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("[PASS] %s" % desc)
	else:
		push_error("[FAIL] %s" % desc)
		print("[FAIL] %s" % desc)

func _ready() -> void:
	print("--- BẮT ĐẦU KIỂM TRA HỆ THỐNG TIÊU HAO NỘI LỰC (MANA) ---")
	test_skill_mana_cost()
	test_free_mana_stage_rules()
	test_player_mana_stats_and_regen()
	test_skill_cast_mana_deduction()
	test_potion_mana_restore()

	print("--- KẾT THÚC KIỂM TRA: %d/%d test passed ---" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL MANA TESTS PASSED!")
	else:
		push_error("SOME TESTS FAILED!")

func test_skill_mana_cost() -> void:
	print("\n--- Test 1: get_mana_cost_at_level của SkillDefinition ---")
	var basic: SkillDefinition = SectRegistry.basic_attack_for({})
	check("Đòn đánh thường cận chiến tiêu hao 0 mana", basic.get_mana_cost_at_level(1) == 0)

	var cb_sect := SectRegistry.get_by_id("cai_bang")
	check("Load được môn phái Cái Bang", cb_sect != null)
	if cb_sect:
		# Tìm 1 skill có tiêu hao nội lực
		var skill_with_cost: SkillDefinition = null
		for s in cb_sect.skills:
			if s.get_mana_cost_at_level(1) > 0:
				skill_with_cost = s
				break
		check("Tìm thấy kỹ năng Cái Bang có tiêu hao nội lực", skill_with_cost != null)
		if skill_with_cost:
			var cost_1 := skill_with_cost.get_mana_cost_at_level(1)
			var cost_max := skill_with_cost.get_mana_cost_at_level(skill_with_cost.max_level)
			print("Skill: %s (cấp 1 cost: %d, cấp max cost: %d)" % [skill_with_cost.skill_name, cost_1, cost_max])
			check("Mana cost cấp 1 > 0", cost_1 > 0)
			check("Mana cost cấp max >= cấp 1", cost_max >= cost_1)

func test_free_mana_stage_rules() -> void:
	print("\n--- Test 2: Quy tắc is_free_mana_stage của GameManager ---")
	var mock_player = PlayerScene.instantiate()
	mock_player.pk_mode = 0

	# 1. Ải Luyện (Map luyện công)
	GameManager.field_map = {"id": 121, "name": "Long Môn Trấn", "level": 10}
	check("Ải Luyện (pk_mode = 0) là MIỄN PHÍ mana", GameManager.is_free_mana_stage(mock_player) == true)

	# 2. Ải Luyện nhưng bật PK Đồ Sát (pk_mode = 1)
	mock_player.pk_mode = 1
	check("Ải Luyện nhưng bật F9 Đồ Sát (pk_mode = 1) BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)
	mock_player.pk_mode = 0

	# 3. Tinh Anh (Tab Tinh Anh 1-5 sao)
	GameManager.field_map = {"id": 121, "name": "Long Môn Trấn", "hell": {"tier": 10, "stars": 3}}
	check("Tinh Anh (pk_mode = 0) là MIỄN PHÍ mana", GameManager.is_free_mana_stage(mock_player) == true)

	# 4. Tinh Anh bật PK Đồ Sát (pk_mode = 1)
	mock_player.pk_mode = 1
	check("Tinh Anh bật F9 Đồ Sát (pk_mode = 1) BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)
	mock_player.pk_mode = 0

	# 5. Tab Boss (Boss Hoàng Kim / Tiểu Hoàng Kim)
	GameManager.field_map = {"id": 121, "name": "Long Môn Trấn", "boss": {"id": 1, "name": "Cổ Bách"}}
	check("Tab Boss BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)

	# 6. Tab Ải - Thách Thức Thời Gian
	GameManager.field_map = {"id": 480, "name": "Thách Thức Thời Gian", "challenge": true}
	check("Thách Thức Thời Gian BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)

	# 7. Tab Ải - Phong Lăng Độ
	GameManager.field_map = {"id": 200, "name": "Phong Lăng Độ", "phong_lang_do": true}
	check("Phong Lăng Độ BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)

	# 8. Tab Ải - Chiến Trường Tống Kim
	GameManager.field_map = {"id": 378, "name": "Tống Kim", "battle": {"id": "1"}}
	check("Chiến Trường Tống Kim BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)

	# 9. PK Đấu trường / Lôi Đài
	GameManager.field_map = {"id": 397, "name": "Đấu trường PK", "pk": {"mode": 1}}
	check("Đấu trường PK BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)

	# 10. PK Loạn Đả (Brawl)
	GameManager.field_map = {"id": 320, "name": "Loạn Đả", "brawl": true}
	check("PK Loạn Đả BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)

	# 11. Tống Kim LOL
	GameManager.field_map = {"id": 500, "name": "Tống Kim LOL", "tong_kim_lol": true}
	check("Tống Kim LOL BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)

	# 12. Vượt Ải Stage (12 bàn - current_stage != null)
	GameManager.field_map = {}
	GameManager.current_stage = StageData.new()
	check("Vượt Ải Stage (current_stage) BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)
	GameManager.current_stage = null

	# 13. Màn chơi khác (field_map rỗng)
	GameManager.field_map = {}
	check("Màn chơi ngoài Luyện và Tinh Anh BẮT BUỘC tốn mana", GameManager.is_free_mana_stage(mock_player) == false)

	# Reset
	GameManager.field_map = {}
	mock_player.queue_free()

func test_player_mana_stats_and_regen() -> void:
	print("\n--- Test 3: Thuộc tính mana, restore_mana và hồi mana khi ngồi ---")
	var profile := PlayerProfile.new()
	profile.display_name = "KiemHiepTest"
	profile.energy = 50
	profile.level = 20
	GameManager.local_profile = profile

	var p = PlayerScene.instantiate()
	add_child(p)
	p.combat_stats = profile.get_combat_stats()
	p.max_mana = float(p.combat_stats.max_mana)
	p.mana = p.max_mana

	check("Player max_mana > 0", p.max_mana > 0)
	check("Player mana khởi tạo = max_mana", p.mana == p.max_mana)

	p.mana -= 50
	check("Player mana giảm sau khi trừ", p.mana == p.max_mana - 50)

	p.restore_mana(30)
	check("Player restore_mana hồi đúng lượng", p.mana == p.max_mana - 20)

	p.restore_mana(100)
	check("Player restore_mana không vượt quá max_mana", p.mana == p.max_mana)

	# Test ngồi thiền hồi mana
	p.mana = 10.0
	p.toggle_sit()
	check("Player đang ngồi thiền", p.is_sitting() == true)
	p._tick_sit(10.0 / 18.0) # 1 SIT_TICK
	check("Player hồi mana khi ngồi thiền", p.mana > 10.0)
	p._stand_up()
	check("Player đã đứng dậy", p.is_sitting() == false)

	p.queue_free()

func test_skill_cast_mana_deduction() -> void:
	print("\n--- Test 4: Trừ mana khi thi triển skill ---")
	var profile := PlayerProfile.new()
	profile.sect_id = "cai_bang"
	GameManager.local_profile = profile

	var p = PlayerScene.instantiate()
	add_child(p)
	p.combat_stats = profile.get_combat_stats()
	p.max_mana = 200.0
	p.mana = 200.0
	p.pk_mode = 0

	var controller := SectSkillController.new()
	var cb_sect := SectRegistry.get_by_id("cai_bang")
	controller.setup(cb_sect)
	p.add_child(controller)

	# Tìm skill có mana cost
	var skill_test: SkillDefinition = null
	for s in cb_sect.skills:
		if s.get_mana_cost_at_level(1) > 0 and s.category == SkillDefinition.SkillCategory.ACTIVE and not s.is_aura:
			skill_test = s
			break

	check("Có skill test Cái Bang", skill_test != null)
	if skill_test:
		var cost := skill_test.get_mana_cost_at_level(1)
		var dummy_target := Node2D.new()
		dummy_target.add_to_group("enemies")

		# Case A: Ải Luyện -> KHÔNG trừ mana
		GameManager.field_map = {"id": 121, "name": "Long Môn Trấn", "level": 10}
		p.mana = 100.0
		var cast_ok_normal = controller._try_cast(skill_test, p, dummy_target)
		check("Thi triển thành công ở Ải Luyện", cast_ok_normal)
		check("Ải Luyện KHÔNG bị trừ mana (mana vẫn nguyên 100)", p.mana == 100.0)

		# Reset cooldown để test tiếp
		controller._cooldowns.clear()

		# Case B: Tinh Anh -> KHÔNG trừ mana
		GameManager.field_map = {"id": 121, "name": "Long Môn Trấn", "hell": {"tier": 10, "stars": 3}}
		p.mana = 100.0
		var cast_ok_hell = controller._try_cast(skill_test, p, dummy_target)
		check("Thi triển thành công ở Tinh Anh", cast_ok_hell)
		check("Tinh Anh KHÔNG bị trừ mana (mana vẫn nguyên 100)", p.mana == 100.0)

		controller._cooldowns.clear()

		# Case C: Tab Boss -> BỊ TRỪ MANA!
		GameManager.field_map = {"id": 121, "name": "Long Môn Trấn", "boss": {"id": 1, "name": "Cổ Bách"}}
		p.mana = 100.0
		var cast_ok_boss = controller._try_cast(skill_test, p, dummy_target)
		check("Thi triển thành công ở Boss", cast_ok_boss)
		check("Ở Boss BỊ TRỪ MANA đúng bằng mana_cost (%d -> %d)" % [cost, int(p.mana)], p.mana == 100.0 - cost)

		controller._cooldowns.clear()

		# Case D: Ở Boss khi KHÔNG ĐỦ MANA -> Không cho cast!
		p.mana = float(cost - 1)
		var cast_fail_mana = controller._try_cast(skill_test, p, dummy_target)
		check("Không đủ mana ở Boss -> Thi triển thất bại", cast_fail_mana == false)
		check("Mana không bị trừ âm", p.mana == float(cost - 1))

		controller._cooldowns.clear()

		# Case E: Ải Luyện nhưng bật Đồ Sát (pk_mode = 1) -> BỊ TRỪ MANA!
		GameManager.field_map = {"id": 121, "name": "Long Môn Trấn", "level": 10}
		p.pk_mode = 1
		p.mana = 100.0
		var cast_ok_pk = controller._try_cast(skill_test, p, dummy_target)
		check("Bật PK Đồ Sát ở Ải Luyện: BỊ TRỪ MANA", p.mana == 100.0 - cost)

		controller._cooldowns.clear()

		# Case F: Chế độ Vượt Ải Stage (current_stage != null) -> BỊ TRỪ MANA!
		GameManager.field_map = {}
		GameManager.current_stage = StageData.new()
		p.pk_mode = 0
		p.mana = 100.0
		var cast_ok_stage = controller._try_cast(skill_test, p, dummy_target)
		check("Chế độ Vượt Ải Stage: BỊ TRỪ MANA", p.mana == 100.0 - cost)
		GameManager.current_stage = null

		dummy_target.queue_free()

	GameManager.field_map = {}
	p.queue_free()

func test_potion_mana_restore() -> void:
	print("\n--- Test 5: PotionEffect hồi phục mana từ thuốc ---")
	var p = PlayerScene.instantiate()
	add_child(p)
	p.max_mana = 300.0
	p.mana = 50.0

	var pe := PotionEffect.of(p)
	check("Tạo PotionEffect thành công", pe != null)

	# Giả lập thuốc Hồi Thiên Đan: hồi 10 mana mỗi 10 frame, tổng 50 frame (5 nhịp) = 50 mana
	pe.add_mana(10.0, 50)
	check("PotionEffect đang active", pe.is_active())

	# Giả lập chạy 1 nhịp (10 frame / 18 FPS)
	pe._process(10.0 / 18.0)
	check("Player được hồi mana qua PotionEffect (mana > 50)", p.mana > 50.0)

	p.queue_free()

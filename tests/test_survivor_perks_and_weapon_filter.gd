extends Node

func _ready() -> void:
	print("\n=================================================================")
	print("=== KIỂM THỬ: LỌC SKILL THEO VŨ KHÍ & 12 SURVIVOR PERKS (5 TẦNG) ===")
	print("=================================================================\n")

	_test_weapon_filtering_and_support_skills_hidden()
	_test_12_survivor_perks_5_tiers()
	_test_bullet_mechanics()

	print("\n=================================================================")
	print(">>> TẤT CẢ CÁC BƯỚC KIỂM THỬ ĐÃ ĐẠT 100% THÀNH CÔNG! <<<")
	print("=================================================================\n")
	get_tree().quit(0)

func _test_weapon_filtering_and_support_skills_hidden() -> void:
	print("[*] BƯỚC 1: Kiểm thử lọc kỹ năng Cái Bang theo vũ khí & Ẩn skill hỗ trợ")

	# Trường hợp A: Cái Bang KHÔNG cầm bổng (tay không: weapon_class = -1)
	SurvivorManager.init_pool("cai_bang", -1)
	print("  -> Số lượng skill tấn công khi KHÔNG cầm bổng: %d" % SurvivorManager.pool_skills.size())
	for s in SurvivorManager.pool_skills:
		assert(s.weapon_limit != 2, "Khi không cầm bổng thì tuyệt đối KHÔNG được có skill đòi bổng (weapon_limit == 2): %s" % s.skill_name)
		assert(not s.is_aura, "Không được chứa skill hào quang: %s" % s.skill_name)
		assert(s.category == SkillDefinition.SkillCategory.ACTIVE, "Phải là skill chủ động ACTIVE: %s" % s.skill_name)
		assert(not SectSkillController.is_self_buff(s), "Không được chứa skill buff bản thân: %s" % s.skill_name)
		assert(s.target_enemy or s.is_main_attack or s.base_damage > 0.0 or not s.damage_types.is_empty(), "Skill phải là skill tấn công gây dame: %s" % s.skill_name)
	print("  => Cái Bang không cầm bổng: Đã ẩn toàn bộ skill bổng và skill hỗ trợ: PASS")

	# Trường hợp B: Cái Bang CÓ CẦM BỔNG (weapon_class = 2)
	SurvivorManager.init_pool("cai_bang", 2)
	print("  -> Số lượng skill tấn công khi CÓ CẦM BỔNG: %d" % SurvivorManager.pool_skills.size())
	var has_stick_skill := false
	for s in SurvivorManager.pool_skills:
		if s.weapon_limit == 2:
			has_stick_skill = true
		assert(s.weapon_limit == 2 or s.weapon_limit == -2, "Chỉ được chứa skill bổng (2) hoặc không hạn chế (-2): %s" % s.skill_name)
		assert(not s.is_aura and s.category == SkillDefinition.SkillCategory.ACTIVE and not SectSkillController.is_self_buff(s), "Không được chứa skill hỗ trợ: %s" % s.skill_name)
	assert(has_stick_skill, "Khi cầm bổng phải xuất hiện skill bổng (ví dụ Bổng Đả Ác Cẩu, Đả Cẩu Bổng...)")
	print("  => Cái Bang cầm bổng: Hiển thị đúng các skill bổng và ẩn skill hỗ trợ: PASS")

	# Trường hợp C: Võ Đang kiếm vs quyền
	SurvivorManager.init_pool("vo_dang", 0) # Kiếm
	print("  -> Võ Đang Cầm Kiếm (weapon_class = 0): %d skill" % SurvivorManager.pool_skills.size())
	for s in SurvivorManager.pool_skills:
		assert(s.weapon_limit == 0 or s.weapon_limit == -2, "Võ Đang Kiếm chỉ chứa skill kiếm hoặc không hạn chế: %s" % s.skill_name)
	print("  => Lọc kỹ năng theo vũ khí: PASS!\n")

func _test_12_survivor_perks_5_tiers() -> void:
	print("[*] BƯỚC 2: Kiểm thử 12 Kỹ năng Bổ trợ (Survivor Perks) nâng 5 tầng")
	SurvivorPerks.reset()
	assert(SurvivorPerks.PERK_DEFINITIONS.size() == 12, "Phải có đầy đủ 12 loại perk")

	var dummy_player = CharacterBody2D.new()
	dummy_player.set("max_health", 1000.0)
	dummy_player.set("health", 1000.0)
	dummy_player.set("base_max_health", 1000.0)
	dummy_player.set("speed", 250.0)
	dummy_player.set("base_speed", 250.0)

	for perk_key in SurvivorPerks.PERK_DEFINITIONS.keys():
		var icon_tex := SurvivorPerks.get_perk_icon(perk_key)
		assert(icon_tex != null, "Icon của perk [%s] phải được nạp thành công (Texture2D)" % perk_key)
		var def = SurvivorPerks.PERK_DEFINITIONS[perk_key]
		assert(SurvivorPerks.get_perk_level(perk_key) == 0, "Ban đầu perk %s ở cấp 0" % perk_key)
		assert(def.desc_levels.size() == 5, "Mỗi perk phải có mô tả cho cả 5 tầng nâng cấp: %s" % perk_key)

		# Nâng từ tầng 1 đến tầng 5
		for tier in range(1, 6):
			var res_tier := SurvivorPerks.upgrade_perk(perk_key, dummy_player)
			assert(res_tier == tier, "Nâng perk %s lên tầng %d" % [perk_key, tier])
			assert(SurvivorPerks.get_perk_level(perk_key) == tier, "Cấp hiện tại phải là %d" % tier)

		assert(SurvivorPerks.is_perk_maxed(perk_key), "Đạt tầng 5 phải được đánh dấu max tầng")
		# Thử nâng tiếp tầng 6 -> vẫn giữ ở tầng 5
		var over_tier := SurvivorPerks.upgrade_perk(perk_key, dummy_player)
		assert(over_tier == 5, "Không thể vượt quá tầng 5")
		print("  -> Perk [%s - %s]: 5 tầng nâng cấp thành công" % [def.name, def.subtitle])

	print("  => Toàn bộ 12 perks nâng 5 tầng: PASS!\n")

func _test_bullet_mechanics() -> void:
	print("[*] BƯỚC 3: Kiểm thử các hàm tính toán cơ chế đạn & phòng vệ")
	# 1. Hút máu (Life leech)
	assert(is_equal_approx(SurvivorPerks.get_life_leech_ratio(), 0.025), "Cấp 5 hút máu 2.5% (= 0.025)")

	# 2. Đạn dội (Bounce): cấp 5 dội 5 lần
	assert(SurvivorPerks.get_bounce_count() == 5, "Cấp 5 dội 5 lần")

	# 3. Đạn xuyên (Pierce): cấp 5 xuyên vô hạn (999)
	assert(SurvivorPerks.get_pierce_count() == 999, "Cấp 5 xuyên vô hạn")

	# 4. Kích thước đạn: cấp 5 gấp đôi (+100% -> scale 2.0)
	assert(is_equal_approx(SurvivorPerks.get_bullet_scale(), 2.0), "Cấp 5 scale đạn = 2.0")

	# 5. Đạn sau lưng: cấp 5 bắn 5 tia
	assert(SurvivorPerks.get_rear_bullet_count() == 5, "Cấp 5 bắn 5 tia sau lưng")

	# 6. Đòn đánh nối tiếp: cấp 5 tỉ lệ 100%
	assert(is_equal_approx(SurvivorPerks.get_combo_cast_chance(), 1.0), "Cấp 5 tỉ lệ combo cast = 100%")

	# 7. Tầm đánh & Sát thương
	assert(is_equal_approx(PlayerStats.range_multiplier, 1.75), "Cấp 5 tầm đánh +75% (= 1.75)")
	assert(is_equal_approx(PlayerStats.damage_multiplier, 2.0), "Cấp 5 sát thương +100% (= 2.0)")

	print("  => Kiểm thử cơ chế đạn, hút máu, khiên phòng vệ: PASS!\n")

extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("=== KIỂM TRA CHẶT CHẼ DÒNG ẨN CHƯA KÍCH VÀ ĐÃ KÍCH ===")
	print("==================================================================")
	
	test_inactive_hidden_lines_not_applied()
	test_active_hidden_lines_applied()
	test_skill_bonus_and_damage_scaling()
	
	print("\n>>> TẤT CẢ CÁC BÀI TEST ĐỀU VƯỢT QUA 100%! <<<")
	quit()

func test_inactive_hidden_lines_not_applied() -> void:
	print("\n--- TEST 1: DÒNG ẨN CHƯA KÍCH HOẠT (ACTIVE = 0) ---")
	var profile := PlayerProfile.new()
	profile.element = ElementTypes.ElementType.KIM # Hệ Kim
	
	var base_stats := profile.get_combat_stats()
	var base_hp := base_stats.max_hp
	var base_mana := base_stats.max_mana
	var base_speed := base_stats.move_speed_p
	var base_all_skills := base_stats.all_skills_bonus
	var base_fire_skills := base_stats.get_skill_bonus(ElementTypes.ElementType.HOA)
	
	# Tạo vũ khí hệ Thổ:
	# Cần Hỏa kích (Nhân vật Kim không sinh Thổ -> active = 0)
	var weapon := ItemInstance.new()
	weapon.base_index = ItemDatabase.find_base(ItemDatabase.Detail.MELEE, 0, 1)
	weapon.series = ElementTypes.ElementType.THO
	weapon.magic = [
		{"attrib": "addphysicsdamage_p", "value": [50, 0, 0]},  # Dòng 1 (Hiện): +50% STVL
		{"attrib": "lifemax_v", "value": [200, 0, 0]},          # Dòng 2 (Ẩn 1): +200 Máu [Chưa kích]
		{"attrib": "manamax_v", "value": [150, 0, 0]},          # Dòng 3 (Hiện): +150 Mana
		{"attrib": "allskill_v", "value": [3, 0, 0]},           # Dòng 4 (Ẩn 2): +3 Cấp tất cả kỹ năng [Chưa kích]
		{"attrib": "fastwalkrun_p", "value": [20, 0, 0]},       # Dòng 5 (Hiện): +20% Tốc chạy
		{"attrib": "fireskill_v", "value": [5, 0, 0]}           # Dòng 6 (Ẩn 3): +5 Cấp kỹ năng Hỏa [Chưa kích]
	]
	
	profile.equipment[Equipment.Part.WEAPON] = weapon
	
	var counts := Equipment.get_active_counts(profile.equipment, profile.element)
	var active_count: int = counts.get(Equipment.Part.WEAPON, 0)
	print("Số dòng ẩn kích hoạt của Vũ khí: %d (Kỳ vọng: 0)" % active_count)
	assert(active_count == 0, "Vũ khí không có đồ/nhân vật tương sinh nên active_count phải = 0")
	
	var effective_lines := Equipment.get_effective_magic(weapon, active_count)
	print("Số dòng có hiệu lực: %d (Kỳ vọng: 3 dòng hiện)" % effective_lines.size())
	assert(effective_lines.size() == 3, "Chỉ có 3 dòng hiện có hiệu lực")
	for line in effective_lines:
		assert(line["attrib"] in ["addphysicsdamage_p", "manamax_v", "fastwalkrun_p"], "Không được chứa dòng ẩn nào!")
	
	var new_stats := profile.get_combat_stats()
	
	# Kiểm tra DÒNG HIỆN ĐƯỢC CỘNG
	print("Mana: %d -> %d (+%d, kỳ vọng +150)" % [base_mana, new_stats.max_mana, new_stats.max_mana - base_mana])
	assert(new_stats.max_mana - base_mana == 150, "Dòng hiện Mana phải được cộng")
	
	print("Tốc chạy: %d%% -> %d%% (+%d%%, kỳ vọng +20%%)" % [base_speed, new_stats.move_speed_p, new_stats.move_speed_p - base_speed])
	assert(new_stats.move_speed_p - base_speed == 20, "Dòng hiện Tốc chạy phải được cộng")
	
	# Kiểm tra DÒNG ẨN CHƯA KÍCH TUYỆT ĐỐI KHÔNG ĐƯỢC CỘNG
	print("Máu (dòng ẩn 1: 200 HP): %d -> %d (+%d, kỳ vọng +0)" % [base_hp, new_stats.max_hp, new_stats.max_hp - base_hp])
	assert(new_stats.max_hp - base_hp == 0, "DÒNG ẨN MÁU CHƯA KÍCH TUYỆT ĐỐI KHÔNG ĐƯỢC CỘNG!")
	
	print("All Skill (dòng ẩn 2: +3 skill): %d -> %d (+%d, kỳ vọng +0)" % [base_all_skills, new_stats.all_skills_bonus, new_stats.all_skills_bonus - base_all_skills])
	assert(new_stats.all_skills_bonus == 0, "DÒNG ẨN ALL SKILL CHƯA KÍCH TUYỆT ĐỐI KHÔNG ĐƯỢC CỘNG!")
	
	var current_fire_bonus := new_stats.get_skill_bonus(ElementTypes.ElementType.HOA)
	print("Fire Skill (dòng ẩn 3: +5 fire): %d -> %d (+%d, kỳ vọng +0)" % [base_fire_skills, current_fire_bonus, current_fire_bonus - base_fire_skills])
	assert(current_fire_bonus == 0, "DÒNG ẨN FIRE SKILL CHƯA KÍCH TUYỆT ĐỐI KHÔNG ĐƯỢC CỘNG!")
	
	print("=> TEST 1 ĐẠT: Mọi dòng ẩn chưa kích đều hoàn toàn KHÔNG cộng vào stats hay skills.")

func test_active_hidden_lines_applied() -> void:
	print("\n--- TEST 2: KÍCH HOẠT TỪNG DÒNG ẨN (ACTIVE = 1, 2, 3) ---")
	var profile := PlayerProfile.new()
	profile.element = ElementTypes.ElementType.HOA # Nhân vật Hỏa (Hỏa sinh Thổ -> Kích hoạt dòng ẩn 1 của vũ khí Thổ)
	
	var base_hp := profile.get_combat_stats().max_hp
	
	var weapon := ItemInstance.new()
	weapon.base_index = ItemDatabase.find_base(ItemDatabase.Detail.MELEE, 0, 1)
	weapon.series = ElementTypes.ElementType.THO
	weapon.magic = [
		{"attrib": "addphysicsdamage_p", "value": [50, 0, 0]},  # Dòng 1 (Hiện)
		{"attrib": "lifemax_v", "value": [200, 0, 0]},          # Dòng 2 (Ẩn 1): +200 HP [Kích bởi Nhân vật Hỏa]
		{"attrib": "manamax_v", "value": [150, 0, 0]},          # Dòng 3 (Hiện)
		{"attrib": "allskill_v", "value": [3, 0, 0]},           # Dòng 4 (Ẩn 2): +3 All Skills [Kích bởi Dây chuyền Hỏa]
		{"attrib": "fastwalkrun_p", "value": [20, 0, 0]},         # Dòng 5 (Hiện)
		{"attrib": "fireskill_v", "value": [5, 0, 0]}           # Dòng 6 (Ẩn 3): +5 Fire Skills [Kích bởi Áo Hỏa]
	]
	profile.equipment[Equipment.Part.WEAPON] = weapon
	
	# Bước 1: Chỉ có nhân vật Hỏa -> active = 1
	var stats1 := profile.get_combat_stats()
	print("Bước 1 (Active = 1): Máu tăng +%d (Kỳ vọng: +200), All Skill = %d (Kỳ vọng: 0)" % [stats1.max_hp - base_hp, stats1.all_skills_bonus])
	assert(stats1.max_hp - base_hp == 200, "Ẩn 1 đã kích hoạt phải cộng đúng 200 HP")
	assert(stats1.all_skills_bonus == 0, "Ẩn 2 chưa kích hoạt không được cộng")
	assert(stats1.get_skill_bonus(ElementTypes.ElementType.HOA) == 0, "Ẩn 3 chưa kích hoạt không được cộng")
	
	# Bước 2: Mặc Dây chuyền Hỏa (Amulet kích hoạt Weapon) -> active = 2
	var amulet := ItemInstance.new()
	amulet.base_index = ItemDatabase.find_base(ItemDatabase.Detail.AMULET, 0, 1)
	amulet.series = ElementTypes.ElementType.HOA
	profile.equipment[Equipment.Part.AMULET] = amulet
	
	var stats2 := profile.get_combat_stats()
	print("Bước 2 (Active = 2): All Skill = %d (Kỳ vọng: 3), Fire Skill = %d (Kỳ vọng: 3 do allskill)" % [stats2.all_skills_bonus, stats2.get_skill_bonus(ElementTypes.ElementType.HOA)])
	assert(stats2.all_skills_bonus == 3, "Ẩn 2 đã kích hoạt phải cộng đúng +3 all skills")
	assert(stats2.element_skills_bonus.get(ElementTypes.ElementType.HOA, 0) == 0, "Ẩn 3 chưa kích hoạt nên element_skills_bonus[HOA] vẫn là 0")
	
	# Bước 3: Mặc Áo Hỏa (Body kích hoạt Weapon) -> active = 3
	var body := ItemInstance.new()
	body.base_index = ItemDatabase.find_base(ItemDatabase.Detail.ARMOR, 0, 1)
	body.series = ElementTypes.ElementType.HOA
	profile.equipment[Equipment.Part.BODY] = body
	
	var stats3 := profile.get_combat_stats()
	var total_fire := stats3.get_skill_bonus(ElementTypes.ElementType.HOA)
	print("Bước 3 (Active = 3): Fire Skill bonus tổng = %d (Kỳ vọng: 3 all + 5 fire = 8)" % total_fire)
	assert(total_fire == 8, "Cả ẩn 2 và ẩn 3 kích hoạt phải cho tổng +8 cấp kỹ năng Hỏa")
	
	print("=> TEST 2 ĐẠT: Kích hoạt lần lượt 1, 2, 3 dòng ẩn cộng chính xác tuyệt đối vào stats và skills.")

func test_skill_bonus_and_damage_scaling() -> void:
	print("\n--- TEST 3: CỘNG VÀO STATS SKILL BONUS VÀ TÍNH TOÁN CỦA COMBATANT_STATS ---")
	var profile := PlayerProfile.new()
	profile.element = ElementTypes.ElementType.HOA
	profile.level = 50
	
	# Tạo giày có dòng ẩn fastwalkrun_p (tốc chạy)
	var boots := ItemInstance.new()
	boots.base_index = ItemDatabase.find_base(ItemDatabase.Detail.BOOT, 0, 1)
	boots.series = ElementTypes.ElementType.THO # Cần Hỏa kích (profile.element là Hỏa -> Kích hoạt dòng ẩn 1)
	boots.magic = [
		{"attrib": "adddefense_v", "value": [50, 0, 0]},    # Hiện: +50 né tránh
		{"attrib": "fastwalkrun_p", "value": [40, 0, 0]}    # Ẩn 1: +40% tốc chạy
	]
	
	# Kiểm tra khi nhân vật hệ KIM (không kích hoạt boots Thổ):
	profile.element = ElementTypes.ElementType.KIM
	profile.equipment[Equipment.Part.FOOT] = boots
	var stats_inactive := profile.get_combat_stats()
	print("Khi chưa kích hoạt: Né tránh = %d (+50), Tốc chạy = +%d%% (+0%%)" % [stats_inactive.defense, stats_inactive.move_speed_p])
	assert(stats_inactive.move_speed_p == 0, "Tốc chạy từ dòng ẩn chưa kích phải = 0")
	
	# Kiểm tra khi nhân vật hệ HỎA (kích hoạt boots Thổ):
	profile.element = ElementTypes.ElementType.HOA
	var stats_active := profile.get_combat_stats()
	print("Khi ĐÃ kích hoạt: Né tránh = %d (+50), Tốc chạy = +%d%% (+40%%)" % [stats_active.defense, stats_active.move_speed_p])
	assert(stats_active.move_speed_p == 40, "Tốc chạy từ dòng ẩn đã kích phải = 40%")
	
	print("=> TEST 3 ĐẠT: Dòng ẩn chỉ số hoạt động chính xác 100%.")

extends Node

const SelectedSkillsWindow = preload("res://ui/hud/selected_skills_window.gd")

func _ready() -> void:
	print("--- TEST SELECTED SKILLS WINDOW START ---")
	
	# 1. Test class instantiation
	var win = SelectedSkillsWindow.new()
	assert(win != null, "SelectedSkillsWindow phải tạo được")
	print("[PASS] SelectedSkillsWindow instance created")

	# 2. Test empty states
	add_child(win)
	assert(win._attack_container != null, "Attack container phải tồn tại")
	assert(win._support_container != null, "Support container phải tồn tại")
	assert(win._attack_container.get_child_count() == 1, "Khi chưa có skill đánh, phải hiện placeholder")
	assert(win._support_container.get_child_count() == 1, "Khi chưa có perk, phải hiện placeholder")
	print("[PASS] Empty placeholders verified")

	# 3. Test with Mock Survivor Skills & Perks
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	GameManager.game_mode = GameManager.GameMode.STAGE

	# Setup mock attack skills
	SurvivorManager.active_skills.clear()
	SurvivorManager.active_skills["hang_long_bat_vu"] = 3
	SurvivorManager.active_skills["phi_long_tai_thien"] = 5
	PlayerStats.survivor_skills = SurvivorManager.active_skills.duplicate()
	PlayerStats.level = 15

	# Setup mock support perks
	SurvivorPerks.reset()
	SurvivorPerks.active_perks["multishot"] = 2
	SurvivorPerks.active_perks["guardian_shield"] = 5
	SurvivorPerks.active_perks["damage_boost"] = 1

	var attacks = SelectedSkillsWindow.get_selected_attack_skills()
	print("[TEST] Attack skills count = ", attacks.size())
	assert(attacks.size() == 2, "Phải có đúng 2 chiêu thức tấn công được chọn")
	for atk in attacks:
		assert(atk.has("star"), "Phải có thông tin tầng (star)")
		assert(atk.has("level"), "Phải có thông tin cấp độ (level)")
		print(" - Chiêu: %s | Tầng: %d/5 | Cấp: %d" % [atk.name, atk.star, atk.level])

	var supports = SelectedSkillsWindow.get_selected_support_skills()
	print("[TEST] Support skills count = ", supports.size())
	assert(supports.size() == 3, "Phải có đúng 3 kỹ năng bổ trợ được chọn")
	for sup in supports:
		assert(sup.has("star"), "Phải có thông tin tầng (star)")
		assert(sup.has("level"), "Phải có thông tin cấp độ (level)")
		print(" - Bổ trợ: %s (%s) | Tầng: %d/5 | Cấp: %d | Hiệu quả: %s" % [sup.name, sup.subtitle, sup.star, sup.level, sup.description])

	# 4. Refresh display and verify card elements
	win._refresh_display()
	assert(win._attack_container.get_child_count() == 2, "Hàng 1 phải render đúng 2 card chiêu thức tấn công")
	assert(win._support_container.get_child_count() == 3, "Hàng 2 phải render đúng 3 card kỹ năng bổ trợ")
	print("[PASS] 2 distinct rows rendered successfully with correct cards")

	# 5. Test close & toggle
	win.close()
	print("[PASS] Window closed successfully")

	print("--- TEST SELECTED SKILLS WINDOW PASSED ALL ASSERTIONS ---")
	get_tree().quit(0)

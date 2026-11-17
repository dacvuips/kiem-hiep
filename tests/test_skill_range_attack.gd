extends Node

func _ready() -> void:
	print("=================================================================")
	print("=== TEST: CHỈ ĐÁNH QUÁI KHI QUÁI ĐI VÀO TRONG VÒNG TẦM SKILL ===")
	print("=================================================================")

	_test_range_detection_and_no_attack_when_outside()
	_test_range_multiplier_expansion_on_levelup()

	print("\n=================================================================")
	print(">>> TẤT CẢ CÁC BÀI TEST TẦM ĐÁNH VÀ LEVELUP RANGE ĐÃ THÀNH CÔNG 100%! <<<")
	print("=================================================================")
	get_tree().quit(0)

func _test_range_detection_and_no_attack_when_outside() -> void:
	print("\n[*] TEST 1: Quái ở ngoài vòng -> không đánh; Quái đi vào vòng -> đánh")

	GameManager.game_mode = GameManager.GameMode.STAGE
	GameManager.field_map = {"survivor_mode": true}
	PlayerStats.range_multiplier = 1.0

	var player_scene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	player.global_position = Vector2(500, 500)

	var test_skill = SkillDefinition.new()
	test_skill.id = "test_fire_slash"
	test_skill.skill_name = "Thử Nghiệm Đao Pháp"
	test_skill.target_enemy = true
	test_skill.vltk_attack_radius = 200
	test_skill.cooldown = 0.5
	test_skill.category = SkillDefinition.SkillCategory.ACTIVE

	player.skill_controller.sect = SectDefinition.new()
	player.skill_controller.sect.skills.append(test_skill)
	SurvivorManager.active_skills = {test_skill.id: 1}
	PlayerStats.survivor_skills = {test_skill.id: 1}

	var base_radius: float = player.get_skill_radius(test_skill)
	assert(base_radius == 200.0, "Base radius phải là 200.0, thực tế: %f" % base_radius)
	print("  -> Base skill radius: %f: PASS" % base_radius)

	# Tạo quái vật ở vị trí (500 + 350, 500) -> Khoảng cách logic: 350px > 200px (ở NGOÀI vòng)
	var enemy = CharacterBody2D.new()
	enemy.add_to_group("enemies")
	enemy.global_position = Vector2(850, 500)
	add_child(enemy)

	# 1. Kiểm tra get_nearest_enemy với tầm 200
	var nearest_enemy = player.get_nearest_enemy(base_radius)
	assert(nearest_enemy == null, "Quái ở cự ly 350px phải nằm NGOÀI tầm 200px (nearest_enemy phải là null)!")
	print("  -> Quái cách 350px (ngoài vòng 200px): get_nearest_enemy trả về null: PASS")

	# 2. Kiểm tra SurvivorCombatAgent: tick nhưng không được ra chiêu vì quái chưa vào vòng
	var agent = player.get_node_or_null("SurvivorCombatAgent")
	if agent == null:
		var combat_agent_script = load("res://systems/survivor/survivor_combat_agent.gd")
		agent = combat_agent_script.new()
		agent.name = "SurvivorCombatAgent"
		player.add_child(agent)

	player.skill_controller._cooldowns[test_skill.id] = 0.0

	var state := {"cast_count": 0}
	player.skill_controller.skill_cast.connect(func(_id): state["cast_count"] += 1)

	agent._tick_survivor_skills(0.1)
	assert(state["cast_count"] == 0, "Quái ngoài vòng: SurvivorCombatAgent tuyệt đối KHÔNG được thi triển skill!")
	print("  -> SurvivorCombatAgent không tấn công quái khi quái ở ngoài vòng: PASS")

	# 3. Quái đi vào trong vòng tầm đánh (500 + 150, 500) -> Khoảng cách 150px <= 200px
	enemy.global_position = Vector2(650, 500)
	nearest_enemy = player.get_nearest_enemy(base_radius)
	assert(nearest_enemy == enemy, "Quái cách 150px phải nằm TRONG tầm 200px!")
	print("  -> Quái đi vào cự ly 150px (trong vòng 200px): get_nearest_enemy phát hiện quái: PASS")

	# 4. SurvivorCombatAgent tick: phát hiện quái trong vòng và tấn công!
	player.skill_controller._cooldowns[test_skill.id] = 0.0
	agent._tick_survivor_skills(0.1)
	assert(state["cast_count"] > 0, "Quái đã vào vòng tầm đánh: SurvivorCombatAgent phải ra chiêu tấn công!")
	print("  -> SurvivorCombatAgent lập tức tấn công khi quái đi vào vòng: PASS")

	enemy.free()
	player.free()

func _test_range_multiplier_expansion_on_levelup() -> void:
	print("\n[*] TEST 2: Nâng cấp tăng range khi levelup -> vòng tầm mở rộng và đánh được quái xa hơn")

	GameManager.game_mode = GameManager.GameMode.STAGE
	GameManager.field_map = {"survivor_mode": true}
	PlayerStats.range_multiplier = 1.0

	var player_scene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	player.global_position = Vector2(500, 500)

	var test_skill = SkillDefinition.new()
	test_skill.id = "sword_ki"
	test_skill.target_enemy = true
	test_skill.vltk_attack_radius = 200
	test_skill.cooldown = 0.5
	test_skill.category = SkillDefinition.SkillCategory.ACTIVE
	player.skill_controller.sect = SectDefinition.new()
	player.skill_controller.sect.skills.append(test_skill)
	SurvivorManager.active_skills = {test_skill.id: 1}
	PlayerStats.survivor_skills = {test_skill.id: 1}

	# Quái ở cự ly 250px (Vector2(750, 500)) -> Với tầm gốc 200px: nằm ngoài tầm
	var enemy = CharacterBody2D.new()
	enemy.add_to_group("enemies")
	enemy.global_position = Vector2(750, 500)
	add_child(enemy)

	assert(player.get_nearest_enemy(player.get_skill_radius(test_skill)) == null, "Với range_multiplier = 1.0 (200px), quái ở 250px nằm ngoài tầm!")
	print("  -> Khi chưa nâng cấp tầm (radius = 200px): quái ở 250px không trong tầm: PASS")

	# Mô phỏng levelup nhận nâng cấp tăng range: +50% range
	PlayerStats.range_multiplier = 1.5
	var upgraded_radius: float = player.get_skill_radius(test_skill)
	assert(upgraded_radius == 300.0, "Radius sau khi tăng range phải là 300.0, thực tế: %f" % upgraded_radius)
	print("  -> Sau khi level up tăng range (+50%): bán kính skill tăng lên 300px: PASS")

	# Bây giờ quái ở 250px phải nằm TRONG tầm đánh mới!
	var target_now = player.get_nearest_enemy(upgraded_radius)
	assert(target_now == enemy, "Quái ở 250px bây giờ đã nằm TRONG vòng tầm đánh 300px!")
	print("  -> Quái ở 250px lập tức lọt vào trong vòng tầm đánh mới và bị phát hiện: PASS")

	# SurvivorCombatAgent cũng nhận diện được quái ở 250px sau khi tăng range
	var agent = player.get_node_or_null("SurvivorCombatAgent")
	if agent == null:
		var combat_agent_script = load("res://systems/survivor/survivor_combat_agent.gd")
		agent = combat_agent_script.new()
		agent.name = "SurvivorCombatAgent"
		player.add_child(agent)

	player.skill_controller._cooldowns[test_skill.id] = 0.0

	var state := {"cast_count": 0}
	player.skill_controller.skill_cast.connect(func(_id): state["cast_count"] += 1)
	agent._tick_survivor_skills(0.1)
	assert(state["cast_count"] > 0, "Quái ở 250px: sau khi tăng range (300px) đã bị SurvivorCombatAgent tấn công!")
	print("  -> SurvivorCombatAgent tấn công quái ở tầm xa hơn theo đúng range mới: PASS")

	enemy.free()
	player.free()
	PlayerStats.range_multiplier = 1.0

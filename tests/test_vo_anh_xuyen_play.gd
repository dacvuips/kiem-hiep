extends Node2D

func _ready() -> void:
	print("=== RUNNING VO ANH XUYEN DAMAGE & POISON TEST ===")
	GameManager.game_mode = GameManager.GameMode.STAGE

	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.16, 0.18)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

	var player_scene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	player.position = Vector2(300, 480)
	add_child(player)

	var enemy_scene = load("res://enemies/Enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.position = Vector2(580, 350)
	add_child(enemy)
	enemy.max_health = 500000.0
	enemy.health = 500000.0
	if enemy.combat_stats:
		enemy.combat_stats.max_health = 500000
		enemy.combat_stats.current_health = 500000

	# Monitor enemy health changes
	var last_hp: float = enemy.health
	var damage_log = []

	# Setup player stats (high damage like high-level Tangmen)
	if player.combat_stats:
		player.combat_stats.unarmed_min_damage = 500
		player.combat_stats.unarmed_max_damage = 800
		player.combat_stats.attack_rating = 5000
		player.combat_stats.deadly_strike_enhance_p = 72

	var sect: SectDefinition = load("res://systems/sect/data/duong_mon.tres")
	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "duong_mon_vo_anh_xuyen":
			skill = s
			break

	for i in range(5):
		await get_tree().process_frame

	var stats: ResolvedSkillStats = player.skill_controller._resolve_stats(skill, player)
	print("Resolved stats: damage=%f, poison_tick=%d, extra=%s, poison_time=%d, poison_interval=%d" % [
		stats.damage, stats.poison_tick_damage, stats.extra_damage_ranges, stats.poison_time_frames, stats.poison_interval_frames
	])

	VltkSkillRunner.execute(player, enemy, stats, skill, 20)

	for frame in range(120):
		await get_tree().process_frame
		if enemy.health < last_hp:
			var diff = last_hp - enemy.health
			damage_log.append({"frame": frame, "damage": diff, "hp_left": enemy.health})
			print("Frame %d: Enemy TOOK DAMAGE: -%f (HP left: %f)" % [frame, diff, enemy.health])
			last_hp = enemy.health

	print("=== TOTAL DAMAGE HITS: %d ===" % damage_log.size())
	for hit in damage_log:
		print("  Hit at frame %d: -%.1f" % [hit["frame"], hit["damage"]])

	get_tree().quit(0)

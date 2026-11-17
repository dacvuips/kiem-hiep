extends Node

func _ready() -> void:
	print("=== BẮT ĐẦU TEST: VÀO VƯỢT ẢI -> LUYỆN (SURVIVOR MODE) ===")

	# 1. Giả lập người chơi chọn map Ba Lăng Huyện trong tab Luyện
	var maps := MapCatalog.in_tier(1)
	assert(not maps.is_empty(), "Phải có map trong tier 1")
	var selected_map: Dictionary = maps[0].duplicate(true)
	selected_map["survivor_mode"] = true
	selected_map["no_monsters"] = true

	# 2. Cài đặt GameManager như khi CharacterHub._start_game() xử lý
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = selected_map
	GameManager.current_stage = null

	var profile := PlayerProfile.new()
	profile.display_name = "Hiệp Khách Test"
	profile.sect_id = "vo_dang"
	profile.level = 10
	GameManager.local_profile = profile

	# 3. Nạp Main scene
	var main_scene: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	add_child(main_scene)

	await get_tree().process_frame
	await get_tree().process_frame

	# 4. Kiểm tra SurvivorWaveChallenge đã được tạo trong Main
	var challenge: SurvivorWaveChallenge = main_scene.get_node_or_null("SurvivorWaveChallenge")
	assert(challenge != null, "SurvivorWaveChallenge phải được thêm vào Main!")
	print("✓ SurvivorWaveChallenge đã khởi tạo thành công trong Main")

	# 5. Kiểm tra VltkWorld đã load map và không bị null
	assert(VltkWorld.current != null, "VltkWorld.current phải tồn tại")
	assert(VltkWorld.current.map != null, "VltkWorld map phải được khởi tạo (không bị màn hình đen)")
	print("✓ VltkWorld map đã được setup thành công: map_dir = %s" % VltkWorld.current.map_dir)

	# 6. Kiểm tra Player và TopStatusBar
	var player: Node2D = get_tree().get_first_node_in_group("player")
	assert(player != null, "Player phải tồn tại")
	var top_bar = main_scene.get_node_or_null("UI/TopStatusBar")
	print("✓ TopStatusBar: %s" % ("Đã tạo" if top_bar != null else "Chưa tạo"))

	# 7. Kiểm tra LevelUpUi hiển thị chọn skill ban đầu
	var level_up_ui = main_scene.get_node_or_null("LevelUpUi")
	if level_up_ui == null:
		level_up_ui = main_scene.get_node_or_null("UI/LevelUpUI")
	assert(level_up_ui != null, "LevelUpUi phải tồn tại")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(level_up_ui.visible, "LevelUpUi phải hiển thị ngay khi vào màn chơi để chọn skill khởi đầu!")
	var choices = level_up_ui.find_child("ChoicesContainer", true, false)
	assert(choices != null and choices.get_child_count() > 0, "Bảng chọn phải có các thẻ kỹ năng khởi đầu!")
	print("✓ LevelUpUI: Đã hiển thị bảng chọn kỹ năng khởi đầu (%d lựa chọn)" % choices.get_child_count())

	# 8. Kiểm tra HUD của Survivor hiển thị đợt 1 / 300 quái
	assert(challenge.current_wave == 1, "Đợt hiện tại phải là 1")
	assert(SurvivorWaveChallenge.WAVE_TARGETS[1] == 300, "Mục tiêu đợt 1 là 300")
	print("✓ Đợt 1: Mục tiêu %d quái, quái xuất hiện: %d" % [SurvivorWaveChallenge.WAVE_TARGETS[1], challenge.wave_monsters_spawned])

	print("=== TẤT CẢ TEST VÀO VƯỢT ẢI -> LUYỆN ĐÃ ĐẠT 100% THÀNH CÔNG! ===")
	get_tree().quit(0)

extends Node

func _ready() -> void:
	print("=== BẮT ĐẦU TEST: VÀO VƯỢT ẢI -> LUYỆN Ở CHẾ ĐỘ ONLINE ===")

	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	assert(GameModeManager.is_online() == true, "Phải đang ở chế độ ONLINE")

	var prof := PlayerProfile.new()
	prof.display_name = "DaiHiepOnline"
	prof.level = 50
	prof.sect_id = "vo_dang"
	GameManager.local_profile = prof

	var maps := MapCatalog.in_tier(1)
	assert(not maps.is_empty(), "Phải có map trong tier 1")
	var target_map: Dictionary = maps[0]
	print("Target map: id=%s, name=%s, level=%s" % [str(target_map.get("id")), str(target_map.get("name")), str(target_map.get("level"))])

	var played_entry: Dictionary = {}
	var win := MapSelectWindow.new(prof, func(entry: Dictionary) -> void:
		print(">> Callback _on_play đã được gọi với entry:", entry.get("name", ""))
		played_entry.merge(entry, true)
	)
	add_child(win)
	await get_tree().process_frame

	print("Calling win._enter_field...")
	win._enter_field(target_map)
	await get_tree().process_frame

	print("played_entry is:", played_entry.get("name", ""))
	assert(not played_entry.is_empty(), "Phải nhận được map entry khi vào map")
	assert(not played_entry.get("survivor_mode", false), "ONLINE vào map Luyện TUYỆT ĐỐI không được có survivor_mode")
	assert(not played_entry.get("no_monsters", false), "ONLINE vào map Luyện TUYỆT ĐỐI không được có no_monsters")
	print("✓ PASS Test 1: Entry nhận được là map dã ngoại (id=%d, name=%s), không dính survivor_mode/no_monsters" % [
		int(played_entry["id"]), str(played_entry.get("name", ""))
	])

	# Test 2: Đưa map entry vào Main scene, đảm bảo không sinh SurvivorWaveChallenge
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = played_entry
	GameManager.current_stage = null

	var main_scene: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	add_child(main_scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var survivor_challenge: Node = main_scene.get_node_or_null("SurvivorWaveChallenge")
	assert(survivor_challenge == null, "Ở chế độ ONLINE dã ngoại không được tồn tại SurvivorWaveChallenge!")
	print("✓ PASS Test 2: Không có SurvivorWaveChallenge trong Main scene")

	var level_up_ui: Node = main_scene.get_node_or_null("LevelUpUi")
	if level_up_ui == null:
		level_up_ui = main_scene.get_node_or_null("UI/LevelUpUI")
	if level_up_ui != null:
		assert(not level_up_ui.visible, "LevelUpUI không được hiển thị chọn 3 skill survivor khi vào map dã ngoại!")
		print("✓ PASS Test 3: LevelUpUI không bị ép hiển thị lúc đầu game")

	print("\n=== TẤT CẢ TEST VÀO VƯỢT ẢI -> LUYỆN ONLINE ĐẠT 100% THÀNH CÔNG! ===")
	get_tree().quit(0)

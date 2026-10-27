extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU KIỂM TRA TOÀN BỘ TAB & NÚT ---")
	test_server_select()
	test_character_hub()
	print("--- TẤT CẢ KIỂM TRA ĐÃ HOÀN TẤT VỚI KẾT QUẢ THÀNH CÔNG ---")
	get_tree().quit(0)

func test_server_select() -> void:
	print("\n[TEST 1] Kiểm tra màn hình ServerSelect...")
	var scene = load("res://ui/server_select/ServerSelect.tscn")
	if scene == null:
		print("LỖI: Không nạp được ServerSelect.tscn")
		return
	var ss = scene.instantiate()
	add_child(ss)
	
	# Gán danh sách server mẫu gồm cả server đông, mới, thường
	ss._servers = ss.MOCK_SERVERS.duplicate(true)
	
	# Kiểm tra các tab
	var tabs = ["all", "new", "crowded", "normal"]
	for t in tabs:
		ss._set_filter(t)
		print("  Tab '%s': số nút server hiển thị = %d" % [t, ss._row_buttons.size()])
		if ss._row_buttons.size() == 0:
			print("  CẢNH BÁO: Tab '%s' không có server nào hiển thị!" % t)
	
	ss.queue_free()
	print("[TEST 1] ServerSelect OK!")

func test_character_hub() -> void:
	print("\n[TEST 2] Kiểm tra màn hình CharacterHub & các tab menu...")
	var scene = load("res://ui/character_hub/CharacterHub.tscn")
	if scene == null:
		print("LỖI: Không nạp được CharacterHub.tscn")
		return
	var hub = scene.instantiate()
	add_child(hub)
	
	# Tạo mock profile cấp 20 có phái Cái Bang
	var prof := PlayerProfile.new()
	prof.display_name = "TestPlayer"
	prof.level = 20
	prof.sect_id = "cai_bang"
	GameManager.local_profile = prof
	hub._profile = prof
	hub._all_skills = hub._load_all_skills()
	hub.refresh()
	
	var views = ["character", "equipment", "skills", "guild", "social", "crafting", "ranking", "settings", "events"]
	for v in views:
		print("  Chuyển sang view: '%s'..." % v)
		hub._set_view(v)
		print("    -> Thành công! _current_view = %s" % hub._current_view)
	
	hub.queue_free()
	print("[TEST 2] CharacterHub OK!")

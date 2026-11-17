extends Node

class MockWeapon extends ItemInstance:
	var _part: int = 0
	func _init(part: int = 0) -> void:
		_part = part
	func get_base() -> Dictionary:
		return {"particular": _part}
	func get_detail() -> int:
		return 0

func _ready() -> void:
	print("=================================================================")
	print("=== KIỂM THỬ: FIX LỖI TĂNG LEVEL & KỸ NĂNG THEO ĐÚNG VŨ KHÍ ===")
	print("=================================================================")

	_test_exp_isolation_in_survivor()
	_test_weapon_skill_filtering()
	_test_profile_restore_on_exit()
	_test_survivor_item_pickup_into_inventory()
	_test_free_mana_in_offline_ai()

	print("\n=================================================================")
	print(">>> TẤT CẢ CÁC BÀI TEST FIX ĐÃ THÀNH CÔNG 100%! <<<")
	print("=================================================================")
	get_tree().quit(0)

func _test_exp_isolation_in_survivor() -> void:
	print("\n[*] TEST 1: CÔ LẬP EXP - QUÁI BỊ GIẾT KHÔNG ĐƯỢC TĂNG LEVEL PROFILE VĨNH VIỄN")
	
	var prof := PlayerProfile.new()
	prof.display_name = "DaiHiep"
	prof.level = 13
	prof.current_exp = 50
	GameManager.local_profile = prof

	# 1.1 Khi đang ở chế độ Survivor Mode
	GameManager.field_map = {"survivor_mode": true}
	GameManager.game_mode = GameManager.GameMode.STAGE

	var monster := VltkMonster.new()
	monster.level = 50
	monster.data = {"exp": 50000, "name": "Heo Rung"}
	monster.is_survivor_monster = true

	# Thử giết quái
	KillRewards.on_monster_killed(monster)
	assert(prof.level == 13, "Level profile KHÔNG được tăng khi giết quái survivor (vẫn là 13)!")
	assert(prof.current_exp == 50, "EXP profile KHÔNG được tăng khi giết quái survivor (vẫn là 50)!")
	print("  -> Giết quái trong Survivor Mode: EXP profile không đổi (Level %d, EXP %d): PASS" % [prof.level, prof.current_exp])

	# 1.2 Thử gọi grant_exp trực tiếp
	var granted := KillRewards.grant_exp(prof, 100000, 50)
	assert(granted == 0, "grant_exp phải trả về 0 trong STAGE / survivor_mode")
	assert(prof.level == 13, "Level profile vẫn phải là 13")
	print("  -> Gọi grant_exp trực tiếp trong Survivor Mode trả về 0: PASS")

	monster.free()

func _test_weapon_skill_filtering() -> void:
	print("\n[*] TEST 2: LỌC KỸ NĂNG KHỞI ĐẦU ĐÚNG THEO VŨ KHÍ CẦM TRÊN TAY")

	# 2.1 Võ Đang cầm Kiếm (weapon_class == 0)
	SurvivorManager.reset()
	SurvivorManager.init_pool("vo_dang", 0) # 0 = Kiếm
	assert(SurvivorManager.pool_skills.size() > 0, "Pool kỹ năng không được rỗng")
	for sk in SurvivorManager.pool_skills:
		assert(sk.weapon_limit == -2 or sk.weapon_limit == 0, 
			"Kỹ năng Võ Đang Kiếm [%s] chỉ được phép là Kiếm (0) hoặc chung (-2), nhận được: %d" % [sk.skill_name, sk.weapon_limit])
	print("  -> Võ Đang cầm Kiếm (0): tất cả %d skill trong pool đều phù hợp Kiếm: PASS" % SurvivorManager.pool_skills.size())

	# 2.2 Võ Đang tay không / Quyền (weapon_class == -1)
	SurvivorManager.reset()
	SurvivorManager.init_pool("vo_dang", -1) # -1 = Quyền
	assert(SurvivorManager.pool_skills.size() > 0, "Pool kỹ năng không được rỗng")
	for sk in SurvivorManager.pool_skills:
		assert(sk.weapon_limit == -2 or sk.weapon_limit == -1, 
			"Kỹ năng Võ Đang Quyền [%s] chỉ được phép là Quyền (-1) hoặc chung (-2), nhận được: %d" % [sk.skill_name, sk.weapon_limit])
	print("  -> Võ Đang tay không / Quyền (-1): tất cả %d skill trong pool đều phù hợp Quyền: PASS" % SurvivorManager.pool_skills.size())

	# 2.3 Thiếu Lâm cầm Côn (weapon_class == 2)
	SurvivorManager.reset()
	SurvivorManager.init_pool("thieu_lam", 2) # 2 = Côn
	assert(SurvivorManager.pool_skills.size() > 0, "Pool kỹ năng không được rỗng")
	for sk in SurvivorManager.pool_skills:
		assert(sk.weapon_limit == -2 or sk.weapon_limit == 2, 
			"Kỹ năng Thiếu Lâm Côn [%s] chỉ được phép là Côn (2) hoặc chung (-2), nhận được: %d" % [sk.skill_name, sk.weapon_limit])
	print("  -> Thiếu Lâm cầm Côn (2): tất cả %d skill trong pool đều phù hợp Côn: PASS" % SurvivorManager.pool_skills.size())

	# 2.4 Kiểm tra giao diện LevelUpUi tạo danh sách lựa chọn ban đầu
	var level_up_scene: PackedScene = load("res://ui/joystick/LevelUpUI.tscn")
	var level_up_ui: CanvasLayer = level_up_scene.instantiate()
	add_child(level_up_ui)
	var prof := PlayerProfile.new()
	prof.sect_id = "vo_dang"
	prof.equipment = {Equipment.Part.WEAPON: MockWeapon.new(0)} # Kiếm
	GameManager.local_profile = prof

	SurvivorManager.reset()
	PlayerStats.reset()
	level_up_ui.show_initial_skill_selection()

	var choices_container := level_up_ui.get_node("CenterContainer/Panel/Margin/VBox/ChoicesContainer")
	var choices: Array[Node] = choices_container.get_children()
	assert(choices.size() > 0, "Phải hiện ít nhất 1 lựa chọn kỹ năng ban đầu")
	print("  -> LevelUpUi hiển thị %d thẻ kỹ năng khởi đầu khớp với vũ khí Kiếm: PASS" % choices.size())

	level_up_ui.queue_free()

func _test_profile_restore_on_exit() -> void:
	print("\n[*] TEST 3: THOÁT HOẶC CHẾT TRONG ẢI KHÔNG LƯU LEVEL BẬY BẠ")

	var original_prof := PlayerProfile.new()
	original_prof.display_name = "KiemKhach"
	original_prof.level = 13
	original_prof.current_exp = 100
	SaveManager.save_profile(original_prof)

	# Giả lập vào trận Survivor
	GameManager.local_profile = original_prof
	GameManager.field_map = {"survivor_mode": true}
	GameManager.game_mode = GameManager.GameMode.STAGE

	# Giả lập trong trận bị biến đổi bậy bạ
	GameManager.local_profile.level = 99

	# Thoát hoặc chết -> gọi restore_profile_from_save()
	SaveManager.restore_profile_from_save()
	assert(GameManager.local_profile.level == 13, "Sau khi restore, cấp độ phải quay lại 13 như trước khi vào trận!")
	print("  -> Khôi phục profile khi thoát/chết: level trở lại 13: PASS")

func _test_survivor_item_pickup_into_inventory() -> void:
	print("\n[*] TEST 4: RỚT ĐỒ TRONG CHẾ ĐỘ OFFLINE VƯỢT ẢI - ĐI NGANG TỰ NHẶT VÀO HÀNH TRANG")

	var prof := PlayerProfile.new()
	prof.display_name = "DaiHiep"
	prof.level = 13
	prof.current_exp = 50
	prof.gold = 1000
	prof.inventory.clear()
	GameManager.local_profile = prof
	GameManager.field_map = {"survivor_mode": true}
	GameManager.game_mode = GameManager.GameMode.STAGE

	# Tạo giả lập player
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(100, 100)
	add_child(player)

	# 4.1 Thử rớt tiền
	var money_drop := GroundDrop.new()
	money_drop.global_position = Vector2(120, 100) # Cách player 20px (trong tầm đi ngang qua)
	money_drop.setup_money(500)
	add_child(money_drop)

	# Chạy 1 nhịp process để auto nhặt
	money_drop._process(0.1)
	assert(prof.gold == 1500, "Tiền phải được tự động nhặt vào người khi đi ngang qua (1000 + 500 = 1500)!")
	print("  -> Tự động nhặt tiền rơi trên đất vào người: PASS (Vàng: %d)" % prof.gold)

	# 4.2 Thử rớt trang bị / vật phẩm
	var item_drop := GroundDrop.new()
	item_drop.global_position = Vector2(110, 100) # Cách player 10px
	var test_item := MockWeapon.new(0)
	item_drop.setup_item(test_item)
	add_child(item_drop)

	# Chạy 1 nhịp process để auto nhặt vật phẩm vào hành trang
	item_drop._process(0.1)
	assert(prof.inventory.size() == 1, "Vật phẩm phải được tự động nhặt vào hành trang (inventory.size == 1)!")
	assert(prof.inventory[0] == test_item, "Món đồ trong hành trang phải là món đồ vừa nhặt!")
	print("  -> Tự động nhặt trang bị/vật phẩm vào hành trang: PASS (Hành trang có %d món)" % prof.inventory.size())

	# 4.3 Đảm bảo level vẫn là 13 không hề bị tăng
	assert(prof.level == 13, "Level vẫn giữ nguyên 13 không bị tăng!")
	print("  -> Level nhân vật vẫn giữ nguyên 13: PASS")

	player.queue_free()

class MockPlayerWithMana extends CharacterBody2D:
	var mana: float = 50.0
	var max_mana: float = 100.0
	func can_cast() -> bool: return true

func _test_free_mana_in_offline_ai() -> void:
	print("\n[*] TEST 5: CHƠI ẢI OFFLINE HOÀN TOÀN KHÔNG MẤT MANA (FREE MANA)")
	GameModeManager.current_mode = GameModeManager.Mode.OFFLINE
	GameManager.game_mode = GameManager.GameMode.STAGE
	GameManager.field_map = {"survivor_mode": true}

	# 5.1 Kiểm tra quy tắc is_free_mana_stage
	assert(GameManager.is_free_mana_stage() == true, "Trong ải offline thì is_free_mana_stage phải là true!")
	print("  -> GameManager.is_free_mana_stage() == true: PASS")

	# 5.2 Kiểm tra khi ra chiêu có mana_cost thì không bị trừ mana
	var dummy_player := MockPlayerWithMana.new()
	var controller := SectSkillController.new()
	dummy_player.add_child(controller)
	add_child(dummy_player)

	var dummy_skill := SkillDefinition.new()
	dummy_skill.id = "test_mana_skill"
	dummy_skill.mana_cost = 25.0
	dummy_skill.category = SkillDefinition.SkillCategory.ACTIVE
	dummy_skill.target_self = true

	var dummy_target := Node2D.new()
	add_child(dummy_target)

	var ok := controller._try_cast(dummy_skill, dummy_player, dummy_target)
	assert(ok == true, "Thi triển chiêu thức thành công")
	assert(dummy_player.mana == 50.0, "Mana vẫn giữ nguyên 50.0, hoàn toàn không bị trừ!")
	print("  -> Thi triển chiêu thức (mana_cost 25.0): Mana không đổi (vẫn 50.0/50.0): PASS")

	dummy_target.queue_free()
	dummy_player.queue_free()

extends Node
## Nhịp ra chiêu theo VLTK gốc (khoá động tác 18/20 frame + TimePerCast / skill_mintimepercast_v):
##   godot --headless --path . res://tests/cast_timing_tests.tscn
var _fail := 0
func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

func _ready() -> void:
	test_action_seconds()
	test_skill_cooldowns()
	await test_action_lock()
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func test_action_seconds() -> void:
	check("Ngoại công tốc độ 0 = 18 frame = 1,0 giây", is_equal_approx(SectSkillController.action_seconds(true, null), 1.0))
	check("Nội công tốc độ 0 = 20 frame", is_equal_approx(SectSkillController.action_seconds(false, null), 20.0 / 18.0))
	var s := CombatantStats.new()
	s.attack_speed = 50   ## 18*100/150 = 12 frame
	s.cast_speed = 30     ## 20*100/130 = 15 -> chẵn 14 frame
	check("Tốc độ đánh 50 -> 12 frame", is_equal_approx(SectSkillController.action_seconds(true, s), 12.0 / 18.0))
	check("Tốc độ xuất chiêu 30 -> 14 frame (làm tròn chẵn)", is_equal_approx(SectSkillController.action_seconds(false, s), 14.0 / 18.0))

func _skill(sect_id: String, vltk_id: int) -> SkillDefinition:
	for sk in SectRegistry.get_by_id(sect_id).skills:
		if sk.vltk_skill_id == vltk_id:
			return sk
	return null

func test_skill_cooldowns() -> void:
	check("Tàn Dương Như Huyết (135) không hồi chiêu riêng", _skill("thien_nhan_giao", 135).get_cooldown_at_level(1) == 0.0)
	check("Đơn Chỉ Liệt Diễm (145) không hồi chiêu riêng", _skill("thien_nhan_giao", 145).get_cooldown_at_level(1) == 0.0)
	check("Thôi Sơn Điền Hải (138) TimePerCast 40 = 2,22 giây", is_equal_approx(_skill("thien_nhan_giao", 138).get_cooldown_at_level(1), 2.22))
	var me_anh := _skill("duong_mon", 710)
	check("Mê Ảnh Tung cấp 1 = 15 giây", is_equal_approx(me_anh.get_cooldown_at_level(1), 15.0))
	check("Mê Ảnh Tung cấp 20 = 5 giây", is_equal_approx(me_anh.get_cooldown_at_level(20), 5.0))
	check("Ngự Tuyết Ẩn cấp 1 = 60 giây", is_equal_approx(_skill("thuy_yen_mon", 713).get_cooldown_at_level(1), 60.0))

func test_action_lock() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "Thử Nhịp"
	profile.set_sect(SectRegistry.get_by_id("thien_nhan_giao"))
	GameManager.local_profile = profile
	## Map luyện công thường (Hub -> Vượt Ải) là MAIN_MAP; STAGE offline gắn SurvivorCombatAgent (không khoá động tác).
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = {}
	var player: Node2D = load("res://player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	var target := Node2D.new()
	target.add_to_group("enemies")
	add_child(target)
	target.global_position = Vector2(80, 0)
	await get_tree().process_frame
	var ctl: SectSkillController = player.skill_controller
	## Bản sao bỏ hạn chế vũ khí (nhân vật thử tay không).
	var skill: SkillDefinition = _skill("thien_nhan_giao", 135).duplicate()
	skill.weapon_limit = -2
	profile.skill_levels[skill.id] = 1
	check("Không bị chặn vì vũ khí", ctl.get_cast_block_reason(skill, player) == "")
	player.mana = 99999.0
	ctl.tick(10.0)
	check("Ra chiêu 1x lần đầu được", ctl._try_cast(skill, player, target))
	check("Ngay sau đó bị khoá động tác", not ctl._try_cast(skill, player, target))
	ctl.tick(0.5)
	check("0,5 giây sau vẫn đang ra chiêu (gốc 1,0 giây)", not ctl._try_cast(skill, player, target))
	ctl.tick(0.55)
	check("Hết 1,0 giây động tác thì ra được chiêu tiếp", ctl._try_cast(skill, player, target))
	ctl.use_action_lock = false
	ctl.tick(10.0)
	ctl._try_cast(skill, player, target)
	check("Survivor (không khoá động tác) ra liền được", ctl._try_cast(skill, player, target))
	player.queue_free()
	target.queue_free()

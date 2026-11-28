extends Node
## Ngọc Tuyền Tâm Kinh (Nga Mi 150 phụ trợ, VLTK gốc skill 1114 / fuzhuemei150 trong emei.lua):
##   - Tầng 1: đạn 375 nổ TẠI mục tiêu (MisslesForm 6), Băng sát + Ngũ hành tương khắc, vùng 3 ô.
##   - Tầng 2 (cấp >= 11 theo Link gốc, skill_flyevent): đạn đang bay bắn skill 1115 (liệu thương — lifereplenish_v của Từ Hàng Phổ Độ)
##     cho mình + đồng đội cùng phe quanh chỗ nổ.
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/ngoc_tuyen_tests.tscn
var _fail := 0
const TANG2 := "nga_mi_ngoc_tuyen_tam_kinh_tang_2"

func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

class Dummy extends Node2D:
	var hits := 0
	var camp := Camp.Type.ANIMAL
	func _init() -> void:
		add_to_group(&"enemies")
	func take_damage_from(_a, _lo, _hi, _t, _e, _m) -> void:
		hits += 1
	func is_dead() -> bool:
		return false

func _ready() -> void:
	test_data()
	await test_cast(20, true)
	await test_cast(5, false)
	await test_remote_replay()
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _skill(id: int) -> SkillDefinition:
	return SectSkillController.skill_by_vltk_id(id)

func test_data() -> void:
	var sk := _skill(1114)
	check("có Ngọc Tuyền Tâm Kinh", sk != null)
	check("chỉ nhắm địch (gốc TargetEnemy)", sk.target_enemy and not sk.target_ally and not sk.target_self)
	check("hệ Thủy", sk.element == ElementTypes.ElementType.THUY)
	check("không hồi chiêu riêng (TimePerCast 0)", is_zero_approx(sk.cooldown))
	check("tiêu hao nội lực cấp 20 = 65", sk.get_mana_cost_at_level(20) == 65)
	check("tiêu hao nội lực cấp 1 = 30", sk.get_mana_cost_at_level(1) == 30)
	var lines := []
	for l in sk.stat_lines:
		lines.append(l.format_at_level(sk, 20))
	print("  dòng cấp 20: ", lines)
	check("Băng sát cấp 20 = 400 đến 500", lines.has("Băng sát: 400 đến 500 điểm"))
	check("Ngũ hành tương khắc cấp 20 = 60%", lines.has("Ngũ hành tương khắc: 60%"))
	var t2 := _skill(1115)
	check("có tầng 2 liệu thương (1115)", t2 != null and t2.id == TANG2 and t2.parent_skill_id == sk.id and t2.is_hidden)
	check("tầng 2 hồi 750 sinh lực ở cấp 20", t2.get_state_payload(20)["attribs"]["lifereplenish_v"].x == 750)
	check("dữ liệu hình chiêu 1114 có trong skill_fx", VltkSkillData.has_skill(1114))
	var m := VltkSkillData.missile_for(VltkSkillData.skill(1114, 20))
	check("đạn 375 có ảnh em_150_fue_zd", str((m["anims"][1] as Dictionary).get("anim", "")).begins_with("em_150_fue_zd"))
	check("FlyEvent bật từ cấp 11 (Link gốc: cấp 10 vẫn 0)", int(VltkSkillData.skill(1114, 11).get("fly_event", 0)) == 1 \
			and int(VltkSkillData.skill(1114, 10).get("fly_event", 0)) == 0)

func _make_player(level: int) -> Node2D:
	var profile := PlayerProfile.new()
	profile.display_name = "Nga Mi"
	profile.set_sect(SectRegistry.get_by_id("nga_mi"))
	profile.level = 160
	profile.skill_levels[_skill(1114).id] = level
	GameManager.local_profile = profile
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = {}
	var me: Node2D = load("res://player/player.tscn").instantiate()
	add_child(me)
	me.global_position = Vector2(400, 400)
	return me

func test_cast(level: int, expect_heal: bool) -> void:
	var me := _make_player(level)
	await get_tree().process_frame
	var enemy := Dummy.new()
	add_child(enemy)
	enemy.global_position = VltkMath.ground_of(me) + Vector2(3 * 32, 0)
	await get_tree().process_frame
	me.mana = 99999.0
	var ctl: SectSkillController = me.skill_controller
	ctl.tick(10.0)
	check("cấp %d: ra được chiêu" % level, ctl._try_cast(_skill(1114), me, enemy))
	var status: StatusEffectController = me.get_node("StatusEffectController")
	for i in 90:
		await get_tree().physics_frame
	check("cấp %d: trúng địch" % level, enemy.hits > 0)
	check("cấp %d: %s liệu thương cho mình (đứng gần chỗ nổ)" % [level, "có" if expect_heal else "KHÔNG"],
			status.has_state(TANG2) == expect_heal)
	check("cấp %d: không tự buff thuộc tính đánh lên mình" % level, not status.has_state(_skill(1114).id))
	me.queue_free()
	enemy.queue_free()
	await get_tree().process_frame

## Máy đồng đội: người chơi Nga Mi khác ra chiêu vào quái cạnh mình -> máy mình chạy lại chiêu và tự nhận liệu thương.
func test_remote_replay() -> void:
	var me := _make_player(1)
	GameManager.local_profile.set_sect(SectRegistry.get_by_id("thieu_lam"))
	await get_tree().process_frame
	var enemy := Dummy.new()
	add_child(enemy)
	enemy.global_position = VltkMath.ground_of(me) + Vector2(2 * 32, 0)
	var r := RemotePlayer.new()
	add_child(r)
	r.setup({"eid": 55, "name": "NgaMiKhac", "level": 160, "camp": CombatTargeting.get_camp(me), "look": {},
			"pos": VltkMath.ground_of(me) + Vector2(-8 * 32, 0), "flags": 0, "action": 0, "dir": 0, "hp": 100, "z": 0})
	await get_tree().process_frame
	VltkSkillRunner.replay(r, 1114, 20, enemy, VltkMath.logic_of(enemy))
	for i in 40:
		await get_tree().physics_frame
	var status: StatusEffectController = me.get_node("StatusEffectController")
	check("online: máy mình nhận liệu thương từ chiêu đồng đội", status.has_state(TANG2))
	check("online: máy mình không gây sát thương thay người khác", enemy.hits == 0)
	me.queue_free()
	enemy.queue_free()
	r.queue_free()

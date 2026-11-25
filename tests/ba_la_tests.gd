extends Node
## Ba La Tâm Kinh (Nga Mi thất truyền 180, VLTK gốc skill 1224 / em_adskill trong advancedskill.lua):
##   autoattackskill = {1234*256 + cấp (1->20), -1, 3*18*256 + tỉ lệ (10%->30%)}
##   -> ra đòn có tỉ lệ thi triển Từ Hàng Phổ Độ 1234 cùng cấp (lifereplenish_v cihang_pudu 275->750), giãn cách 3 giây.
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/ba_la_tests.tscn
var _fail := 0
const BA_LA := "nga_mi_ba_la_tam_kinh"
const HEAL := "nga_mi_ba_la_tu_hang_pho_do"

func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

class Dummy extends Node2D:
	var camp := Camp.Type.ANIMAL
	func _init() -> void:
		add_to_group(&"enemies")
	func take_damage_from(_a, _lo, _hi, _t, _e, _m) -> void:
		pass
	func is_dead() -> bool:
		return false

func _ready() -> void:
	test_data()
	await test_trigger()
	await test_not_learned()
	await test_remote()
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _sk(id: String) -> SkillDefinition:
	for s: SkillDefinition in SectRegistry.get_by_id("nga_mi").skills:
		if s.id == id:
			return s
	return null

func test_data() -> void:
	var ba_la := _sk(BA_LA)
	var heal := _sk(HEAL)
	check("có Ba La Tâm Kinh", ba_la != null)
	check("có skill con Từ Hàng Phổ Độ 1234", heal != null and heal.vltk_skill_id == 1234 and heal.is_hidden \
			and heal.parent_skill_id == BA_LA)
	check("tra 1234 ra skill con", SectSkillController.skill_by_vltk_id(1234) == heal)
	var v1 := ba_la.get_attrib("autoattackskill", 1)
	var v20 := ba_la.get_attrib("autoattackskill", 20)
	check("cấp 1: kích 1234 cấp 1, 10%, 54 frame", v1.x == 1234 * 256 + 1 and v1.z == 54 * 256 + 10)
	check("cấp 20: kích 1234 cấp 20, 30%, 54 frame", v20.x == 1234 * 256 + 20 and v20.z == 54 * 256 + 30)
	check("hồi 275 ở cấp 1", heal.get_state_payload(1)["attribs"]["lifereplenish_v"].x == 275)
	check("hồi 750 ở cấp 20", heal.get_state_payload(20)["attribs"]["lifereplenish_v"].x == 750)
	check("có vùng đồng đội 5 ô", SectSkillController.has_ally_area(heal) and heal.vltk_damage_range == 5)
	var lines := []
	for l in ba_la.stat_lines:
		lines.append(l.format_at_level(ba_la, 20))
	print("  Ba La cấp 20: ", lines)
	check("không còn dòng bịa (2000 điểm / ngũ hành tương khắc)", not str(lines).contains("2000") and not str(lines).contains("tương khắc"))
	check("tỉ lệ cấp 20 = 30%", lines.has("Tỷ lệ thi triển Từ Hàng Phổ Độ: 30%"))
	var hl := []
	for l in heal.stat_lines:
		hl.append(l.format_at_level(heal, 20))
	print("  tầng 2 cấp 20: ", hl)
	check("dữ liệu hình 1234 có đạn (như 93)", int(VltkSkillData.skill(1234, 1).get("child", 0)) == 5 \
			and int(VltkSkillData.skill(1234, 1).get("form", 0)) == 7)

func _make_player(ba_la_level: int) -> Node2D:
	var profile := PlayerProfile.new()
	profile.display_name = "Nga Mi"
	profile.set_sect(SectRegistry.get_by_id("nga_mi"))
	profile.level = 180
	if ba_la_level > 0:
		profile.skill_levels[BA_LA] = ba_la_level
	GameManager.local_profile = profile
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = {}
	var me: Node2D = load("res://player/player.tscn").instantiate()
	add_child(me)
	me.global_position = Vector2(400, 400)
	return me

func test_trigger() -> void:
	var me := _make_player(20)
	await get_tree().process_frame
	var enemy := Dummy.new()
	add_child(enemy)
	enemy.global_position = me.global_position + Vector2(64, 0)
	var ctl: SectSkillController = me.skill_controller
	var status: StatusEffectController = me.get_node("StatusEffectController")
	var hits := 0
	me.mana = 100.0  ## dưới mức tối đa (setter kẹp theo nội lực tối đa)
	var mana_before := float(me.mana)
	for i in 200:
		ctl.trigger_auto_attack_skills(me, enemy, {})
		hits += 1
		if status.has_state(HEAL):
			break
	check("ra đòn -> có lúc bung Từ Hàng Phổ Độ hồi máu cho mình (sau %d đòn)" % hits, status.has_state(HEAL))
	## Gốc KNpc::AttackSkill gọi thẳng KSkill::Cast (không qua KNpc::Cost như DoSkill) -> KHÔNG trừ nội lực.
	check("bung Từ Hàng Phổ Độ không tốn nội lực (%.0f -> %.0f)" % [mana_before, float(me.mana)], float(me.mana) >= mana_before)
	check("giãn cách 3 giây sau khi kích",is_equal_approx(float(ctl._auto_attack_cooldowns.get(BA_LA, 0.0)), 3.0))
	var anims := {}
	for i in 3:
		await get_tree().physics_frame
		for n in _all(self):
			if n is VltkEffect and n.visible and n._anim != null and not (n._anim as Dictionary).is_empty():
				anims[str((n._anim as Dictionary).get("key", n._anim.get("file", n.name)))] = true
		for n in _all(self):
			if n is VltkMissile:
				anims["missile"] = true
	print("  hình đang vẽ: ", anims.keys())
	check("có đạn Từ Hàng Phổ Độ bung tại chỗ (cột nước hồi máu)", anims.has("missile"))
	me.queue_free()
	enemy.queue_free()
	await get_tree().process_frame

func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out

func test_not_learned() -> void:
	var me := _make_player(0)
	await get_tree().process_frame
	var enemy := Dummy.new()
	add_child(enemy)
	var ctl: SectSkillController = me.skill_controller
	for i in 200:
		ctl.trigger_auto_attack_skills(me, enemy, {})
	check("chưa học Ba La -> không bung", not me.get_node("StatusEffectController").has_state(HEAL))
	me.queue_free()
	enemy.queue_free()
	await get_tree().process_frame

## Máy đồng đội: nhận S_CAST 1234 (CAST_SUPPORT) từ người chơi Nga Mi đứng gần -> tự nhận hồi máu.
func test_remote() -> void:
	var me := _make_player(0)
	await get_tree().process_frame
	var r := RemotePlayer.new()
	add_child(r)
	r.setup({"eid": 56, "name": "NgaMiKhac", "level": 180, "camp": CombatTargeting.get_camp(me), "look": {},
			"pos": VltkMath.ground_of(me) + Vector2(-4 * 32, 0), "flags": 0, "action": 0, "dir": 0, "hp": 100, "z": 0})
	await get_tree().process_frame
	var ok := SectSkillController.receive_ally_support(me, r, _sk(HEAL), 20, false)
	check("online: đồng đội đứng gần nhận hồi máu Ba La", ok and me.get_node("StatusEffectController").has_state(HEAL))
	me.queue_free()
	r.queue_free()

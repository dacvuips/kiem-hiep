extends Node
## Sâm La Độc Hải (Ngũ Độc thất truyền 180, VLTK gốc skill 1222 / wu_adskill trong advancedskill.lua):
##   autoattackskill = {1232*256 + cấp (1->20), -1, 1*18*256 + tỉ lệ (20%->60%)}
##   -> đòn trúng có tỉ lệ thi triển Hồn Ảnh Tùng Sanh 1232 cùng cấp lên mục tiêu, giãn cách 1 giây.
##   1232 (wudu.lua daowudu150_2): đạn 357 đầu lâu nổ, ngoại công, độc sát 1->12/nhịp, ngũ hành tương khắc 40->80%.
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/sam_la_tests.tscn
var _fail := 0
const SAM_LA := "ngu_doc_sam_la_doc_hai"

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
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _sk(id: String) -> SkillDefinition:
	for s: SkillDefinition in SectRegistry.get_by_id("ngu_doc_giao").skills:
		if s.id == id:
			return s
	return null

func test_data() -> void:
	var sam_la := _sk(SAM_LA)
	check("có Sâm La Độc Hải", sam_la != null)
	var v1 := sam_la.get_attrib("autoattackskill", 1)
	var v20 := sam_la.get_attrib("autoattackskill", 20)
	check("cấp 1: kích 1232 cấp 1, 20%, 18 frame", v1.x == 1232 * 256 + 1 and v1.z == 18 * 256 + 20)
	check("cấp 20: kích 1232 cấp 20, 60%, 18 frame", v20.x == 1232 * 256 + 20 and v20.z == 18 * 256 + 60)
	check("Sâm La không tự mang damage (thuộc Hồn Ảnh)", not sam_la.has_attrib("poisondamage_v") and not sam_la.has_attrib("seriesdamage_p"))
	var lines := []
	for l in sam_la.stat_lines:
		lines.append(l.format_at_level(sam_la, 20))
	print("  Sâm La cấp 20: ", lines)
	check("tỉ lệ cấp 20 = 60%", lines.has("Tỷ lệ kích hoạt Hồn Ảnh: 60%"))
	var s1232 := VltkSkillData.skill(1232, 20)
	check("dữ liệu hình 1232 có đạn đầu lâu 357", int(s1232.get("child", 0)) == 357 and int(s1232.get("target_enemy", 0)) == 1)
	check("1222 bị động: không tự bắn skill con", int(VltkSkillData.skill(1222, 1).get("child", 0)) == 0)
	var hon_anh := SectSkillController.hon_anh_tung_sanh_def()
	check("Hồn Ảnh độc 1 ở cấp 1, 12 ở cấp 20", hon_anh.get_attrib("poisondamage_v", 1).x == 1 and hon_anh.get_attrib("poisondamage_v", 20).x == 12)
	check("Hồn Ảnh tương khắc 40% -> 80%", hon_anh.get_attrib("seriesdamage_p", 1).x == 40 and hon_anh.get_attrib("seriesdamage_p", 20).x == 80)
	check("Hồn Ảnh là ngoại công", hon_anh.is_physical())

func _make_player(level: int) -> Node2D:
	var profile := PlayerProfile.new()
	profile.display_name = "Ngu Doc"
	profile.set_sect(SectRegistry.get_by_id("ngu_doc_giao"))
	profile.level = 180
	if level > 0:
		profile.skill_levels[SAM_LA] = level
	GameManager.local_profile = profile
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = {}
	var me: Node2D = load("res://player/player.tscn").instantiate()
	add_child(me)
	me.global_position = Vector2(400, 400)
	return me

func _missiles() -> Array:
	var out := []
	for n in _all(self):
		if n is VltkMissile:
			out.append(n)
	return out

func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out

func test_trigger() -> void:
	var me := _make_player(20)
	await get_tree().process_frame
	var enemy := Dummy.new()
	add_child(enemy)
	enemy.global_position = me.global_position + Vector2(96, 0)
	var ctl: SectSkillController = me.skill_controller
	var tries := 0
	for i in 200:
		tries += 1
		ctl.trigger_auto_attack_skills(me, enemy, {})
		if float(ctl._auto_attack_cooldowns.get(SAM_LA, 0.0)) > 0.0:
			break
	check("đòn trúng -> có lúc kích Hồn Ảnh (sau %d đòn)" % tries, float(ctl._auto_attack_cooldowns.get(SAM_LA, 0.0)) > 0.0)
	check("giãn cách 1 giây", is_equal_approx(float(ctl._auto_attack_cooldowns.get(SAM_LA, 0.0)), 1.0))
	await get_tree().physics_frame
	var ms := _missiles()
	check("có đạn đầu lâu Hồn Ảnh (%d)" % ms.size(), not ms.is_empty())
	var st := ctl._resolve_stats(SectSkillController.hon_anh_tung_sanh_def(), me, 20)
	print("  Hồn Ảnh cấp 20: độc/nhịp=", st.poison_tick_damage, " khắc=", st.five_elements_damage_p, " hệ=", st.extra_damage_ranges)
	check("đòn Hồn Ảnh tính tương khắc 80%", st.five_elements_damage_p == 80)
	## Trong giãn cách không kích thêm.
	var n_before := _missiles().size()
	for i in 50:
		ctl.trigger_auto_attack_skills(me, enemy, {})
	check("trong 1 giây không kích lại", _missiles().size() <= n_before)
	me.queue_free()
	enemy.queue_free()
	await get_tree().process_frame

func test_not_learned() -> void:
	var me := _make_player(0)
	await get_tree().process_frame
	var enemy := Dummy.new()
	add_child(enemy)
	var ctl: SectSkillController = me.skill_controller
	for i in 200:
		ctl.trigger_auto_attack_skills(me, enemy, {})
	await get_tree().physics_frame
	check("chưa học Sâm La -> không kích", _missiles().is_empty())
	me.queue_free()
	enemy.queue_free()
	await get_tree().process_frame

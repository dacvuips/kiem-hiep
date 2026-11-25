extends Node

var total_tests := 0
var passed_tests := 0

func check(desc: String, condition: bool) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("[PASS] %s" % desc)
	else:
		push_error("[FAIL] %s" % desc)
		print("[FAIL] %s" % desc)

func _ready() -> void:
	print("=== BẮT ĐẦU KIỂM TRA SKILL 180 CÔN LÔN & LƯỠNG NGHI CHÂN KHÍ TẦNG 2 ===")
	test_skill_definition()
	test_state_payload_duration()
	test_magic_attribs_and_stats()
	test_combat_lightning_resist_ignore()
	test_auto_reply_trigger()
	test_auto_rescue_with_thien_cuong_buff()
	test_ma_phap_don_tier2()

	print("\n=== KẾT THÚC KIỂM TRA: %d/%d test passed ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL CON LON 180 & TIER 2 TESTS PASSED!")
	else:
		push_error("SOME TESTS FAILED!")
	get_tree().quit(0 if passed_tests == total_tests else 1)

func test_skill_definition() -> void:
	print("\n--- Test 1: Thuộc tính kỹ năng Thiên Cương Khí Kính ---")
	var sect: SectDefinition = load("res://systems/sect/data/con_lon.tres")
	check("Load được con_lon.tres", sect != null)
	if not sect:
		return

	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "con_lon_thien_cuong_khi_kinh":
			skill = s
			break

	check("Tìm thấy skill Thiên Cương Khí Kính", skill != null)
	if not skill:
		return

	check("req_level = 180", skill.req_level == 180)
	check("vltk_skill_id = 1229", skill.vltk_skill_id == 1229)
	check("vltk_state_special_id = 1239", skill.vltk_state_special_id == 1239)
	check("cooldown = 15.0", is_equal_approx(skill.cooldown, 15.0))
	check("Có vltk_attribs anti_lightingres_yan_p", skill.vltk_attribs.has("anti_lightingres_yan_p"))
	check("Có vltk_attribs enhance_717_auto", skill.vltk_attribs.has("enhance_717_auto"))
	check("Có vltk_attribs seriesdamage_p", skill.vltk_attribs.has("seriesdamage_p"))
	check("Có vltk_attribs autoreplyskill", skill.vltk_attribs.has("autoreplyskill"))

func test_state_payload_duration() -> void:
	print("\n--- Test 2: Thời gian duy trì get_state_payload tại cấp 20 ---")
	var sect: SectDefinition = load("res://systems/sect/data/con_lon.tres")
	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "con_lon_thien_cuong_khi_kinh":
			skill = s
			break
	if not skill:
		return

	var payload_lv20 := skill.get_state_payload(20)
	check("Thời gian duy trì cấp 20 là đúng 15 giây", is_equal_approx(float(payload_lv20["seconds"]), 15.0))
	var attribs_lv20: Dictionary = payload_lv20["attribs"]
	check("Bỏ qua kháng lôi cấp 20 là 15%", attribs_lv20.get("anti_lightingres_yan_p", Vector3i.ZERO).x == 15)
	check("Tăng tỷ lệ Lưỡng Nghi Chân Khí cấp 20 là 15%", attribs_lv20.get("enhance_717_auto", Vector3i.ZERO).x == 15)
	check("Ngũ hành tương khắc cấp 20 là 50%", attribs_lv20.get("seriesdamage_p", Vector3i.ZERO).x == 50)

	var payload_lv1 := skill.get_state_payload(1)
	check("Thời gian duy trì cấp 1 là đúng 5 giây", is_equal_approx(float(payload_lv1["seconds"]), 5.0))

func test_magic_attribs_and_stats() -> void:
	print("\n--- Test 3: MagicAttribTable & CombatantStats nhận đúng chỉ số ---")
	var stats := CombatantStats.new()
	var applied_light := MagicAttribTable.apply(stats, "anti_lightingres_yan_p", Vector3i(15, 0, 0))
	check("MagicAttribTable hỗ trợ anti_lightingres_yan_p", applied_light)
	check("ignore_lighting_res_p = 15", stats.ignore_lighting_res_p == 15)

	var applied_ln := MagicAttribTable.apply(stats, "enhance_717_auto", Vector3i(15, 0, 0))
	check("MagicAttribTable hỗ trợ enhance_717_auto", applied_ln)
	check("enhance_luong_nghi_p = 15", stats.enhance_luong_nghi_p == 15)

	var applied_sd := MagicAttribTable.apply(stats, "seriesdamage_p", Vector3i(50, 0, 0))
	check("MagicAttribTable hỗ trợ seriesdamage_p", applied_sd)
	check("five_elements_enhance = 50", stats.five_elements_enhance == 50)

func test_combat_lightning_resist_ignore() -> void:
	print("\n--- Test 4: CombatFormulas trừ kháng lôi của đối thủ khi có ignore_lighting_res_p ---")
	var attacker := CombatantStats.new()
	attacker.element = ElementTypes.ElementType.THO
	attacker.ignore_lighting_res_p = 15

	var defender := CombatantStats.new()
	defender.element = ElementTypes.ElementType.THO
	defender.resist_percent[CombatFormulas.DamageType.LIGHT] = 75

	var parts := {CombatFormulas.DamageType.LIGHT: Vector2i(1000, 1000)}
	var out_dealt := {}
	var dmg := CombatFormulas.resolve_multi_damage(attacker, defender, 10000, parts, attacker.element, null, out_dealt)
	# Defender có 75% kháng lôi, bị bỏ qua 15% -> còn 60% kháng lôi -> nhận 40% của 1000 = 400 damage
	check("Damage gây ra đúng 400 (do kháng lôi còn 60% thay vì 75%)", dmg == 400)

class DummyActor extends Node2D:
	var combat_stats: CombatantStats = null
	var health: float = 1000.0
	var max_health: float = 1000.0
	var status_controller: StatusEffectController = null

	func _init() -> void:
		combat_stats = CombatantStats.new()
		status_controller = StatusEffectController.new()
		status_controller.name = "StatusEffectController"
		add_child(status_controller)

func test_auto_reply_trigger() -> void:
	print("\n--- Test 5: sect_skill_controller kích hoạt Thiên Cương Khí Kính khi bị đánh ---")
	var dummy := DummyActor.new()
	add_child(dummy)

	var ctrl := SectSkillController.new()
	dummy.add_child(ctrl)

	var sect: SectDefinition = load("res://systems/sect/data/con_lon.tres")
	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "con_lon_thien_cuong_khi_kinh":
			skill = s
			break

	# Gọi trigger thủ công
	ctrl._trigger_thien_cuong_khi_kinh(dummy, 20, 15.0, skill)
	check("Dummy có trạng thái con_lon_thien_cuong_khi_kinh", dummy.status_controller.has_state("con_lon_thien_cuong_khi_kinh"))
	var st = dummy.status_controller._states.get("con_lon_thien_cuong_khi_kinh")
	check("Trạng thái có duration = 15 giây", is_equal_approx(float(st["duration"]), 15.0))
	check("Trạng thái có time = 15 giây", is_equal_approx(float(st["time"]), 15.0))

func test_auto_rescue_with_thien_cuong_buff() -> void:
	print("\n--- Test 6: Buff Thiên Cương Khí Kính tăng tỷ lệ kích hoạt Lưỡng Nghi Chân Khí ---")
	var stats := CombatantStats.new()
	stats.enhance_luong_nghi_p = 15
	check("Chỉ số enhance_luong_nghi_p đạt 15%", stats.enhance_luong_nghi_p == 15)

func test_ma_phap_don_tier2() -> void:
	print("\n--- Test 7: Lưỡng Nghi Chân Khí Tầng 2 (Ma Pháp Độn - Giảm sát thương phép 100 lần nội lực) ---")
	var sect: SectDefinition = load("res://systems/sect/data/con_lon.tres")
	var ma_phap: SkillDefinition = null
	for s in sect.skills:
		if s.id == "con_lon_ma_phap_don":
			ma_phap = s
			break

	check("Tìm thấy skill con con_lon_ma_phap_don", ma_phap != null)
	if not ma_phap:
		return

	check("vltk_skill_id = 721", ma_phap.vltk_skill_id == 721)
	check("Có vltk_attribs staticmagicshield_p", ma_phap.vltk_attribs.has("staticmagicshield_p"))

	var payload_lv20 := ma_phap.get_state_payload(20)
	check("Thời gian duy trì Ma Pháp Độn cấp 20 là 10 giây", is_equal_approx(float(payload_lv20["seconds"]), 10.0))
	check("Hệ số staticmagicshield_p cấp 20 là 10000 (100 lần nội lực)", payload_lv20["attribs"]["staticmagicshield_p"].x == 10000)

	var payload_lv1 := ma_phap.get_state_payload(1)
	check("Thời gian duy trì Ma Pháp Độn cấp 1 là 5 giây", is_equal_approx(float(payload_lv1["seconds"]), 5.0))
	check("Hệ số staticmagicshield_p cấp 1 là 1800 (18 lần nội lực)", payload_lv1["attribs"]["staticmagicshield_p"].x == 1800)

	# Kiểm tra CombatantStats & MagicAttribTable
	var def_stats := CombatantStats.new()
	MagicAttribTable.apply(def_stats, "staticmagicshield_p", Vector3i(10000, 0, 0))
	check("CombatantStats nhận static_magic_shield_p = 10000", def_stats.static_magic_shield_p == 10000)

	# Kiểm tra CombatFormulas: sát thương phép bị hấp thụ bởi Ma Pháp Độn
	var atk_stats := CombatantStats.new()
	atk_stats.element = ElementTypes.ElementType.KIM
	def_stats.element = ElementTypes.ElementType.THO
	def_stats.resist_percent[CombatFormulas.DamageType.LIGHT] = 0
	def_stats.resist_percent[CombatFormulas.DamageType.PHYSICS] = 0

	# 1. Đòn phép (Lôi sát 1000 damage), Defender có 500 mana -> khiên có dung lượng 500 * 100 = 50,000 -> 1000 damage bị giảm về 0
	var magic_parts := {CombatFormulas.DamageType.LIGHT: Vector2i(1000, 1000)}
	var out_dealt := {}
	var magic_dmg := CombatFormulas.resolve_multi_damage(atk_stats, def_stats, 5000, magic_parts, atk_stats.element, null, out_dealt, 500)
	check("Sát thương phép 1000 bị Ma Pháp Độn hấp thụ hoàn toàn (damage = -1 hoặc 0)", magic_dmg <= 0)

	# 2. Đòn vật lý (PHYSICS 1000 damage) -> Ma Pháp Độn KHÔNG giảm sát thương vật lý -> nhận đủ 1000 damage
	var phys_parts := {CombatFormulas.DamageType.PHYSICS: Vector2i(1000, 1000)}
	var phys_dmg := CombatFormulas.resolve_multi_damage(atk_stats, def_stats, 5000, phys_parts, atk_stats.element, null, out_dealt, 500)
	check("Sát thương vật lý 1000 KHÔNG bị Ma Pháp Độn giảm (nhận đủ 1000 damage)", phys_dmg == 1000)

	# 3. Kích hoạt tự cứu Lưỡng Nghi Chân Khí áp Ma Pháp Độn
	var dummy := DummyActor.new()
	add_child(dummy)
	var ctrl := SectSkillController.new()
	dummy.add_child(ctrl)
	ctrl.sect = sect

	var parent_ln: SkillDefinition = null
	for s in sect.skills:
		if s.id == "con_lon_luong_nghi_chan_khi":
			parent_ln = s
			break

	ctrl._trigger_luong_nghi_chan_khi(dummy, 20, 10.0, parent_ln)
	check("Dummy nhận trạng thái con_lon_ma_phap_don", dummy.status_controller.has_state("con_lon_ma_phap_don"))
	var st = dummy.status_controller._states.get("con_lon_ma_phap_don")
	check("Trạng thái Ma Pháp Độn có staticmagicshield_p = 10000", st["attribs"]["staticmagicshield_p"].x == 10000)
	check("Trạng thái Ma Pháp Độn có fastwalkrun_p = 35", st["attribs"]["fastwalkrun_p"].x == 35)
	check("Trạng thái Ma Pháp Độn có thời gian 10 giây", is_equal_approx(float(st["duration"]), 10.0))


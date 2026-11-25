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
	print("=== BẮT ĐẦU KIỂM TRA SKILL 180 ĐƯỜNG MÔN (HẤP TINH TRẬN) ===")
	test_skill_definition()
	test_hotbar_assignment_forbidden()
	test_magic_attribs_and_stats()
	test_damage_absorption()
	test_auto_rescue_trigger()

	print("\n=== KẾT THÚC KIỂM TRA: %d/%d test passed ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL DUONG MON 180 TESTS PASSED!")
	else:
		push_error("SOME TESTS FAILED!")
	get_tree().quit(0 if passed_tests == total_tests else 1)

func test_skill_definition() -> void:
	print("\n--- Test 1: Thuộc tính kỹ năng Hấp Tinh Trận ---")
	var sect: SectDefinition = load("res://systems/sect/data/duong_mon.tres")
	check("Load được duong_mon.tres", sect != null)
	if not sect:
		return

	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "duong_mon_hap_tinh_tran":
			skill = s
			break

	check("Tìm thấy skill Hấp Tinh Trận", skill != null)
	if not skill:
		return

	check("Skill là Bị động (category = PASSIVE)", skill.category == SkillDefinition.SkillCategory.PASSIVE)
	check("is_active = false", skill.is_active == false)
	check("is_hotbar = false", skill.is_hotbar == false)
	check("school_text là Bị động", "Bị động" in skill.school_text)
	check("req_level = 180", skill.req_level == 180)
	check("vltk_skill_id = 1223", skill.vltk_skill_id == 1223)
	check("Có vltk_attribs autorescueskill", skill.vltk_attribs.has("autorescueskill"))
	check("Có vltk_attribs seriesdamage_p", skill.vltk_attribs.has("seriesdamage_p"))

func test_hotbar_assignment_forbidden() -> void:
	print("\n--- Test 2: Không cho phép kéo vào thanh Hotbar ---")
	var sect: SectDefinition = load("res://systems/sect/data/duong_mon.tres")
	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "duong_mon_hap_tinh_tran":
			skill = s
			break

	if skill:
		check("can_assign_to_hotbar() trả về FALSE", skill.can_assign_to_hotbar() == false)

func test_magic_attribs_and_stats() -> void:
	print("\n--- Test 3: MagicAttribTable & CombatantStats ánh xạ đúng chỉ số ---")
	var stats := CombatantStats.new()
	var applied_sd := MagicAttribTable.apply(stats, "seriesdamage_p", Vector3i(50, 0, 0))
	check("MagicAttribTable hỗ trợ seriesdamage_p", applied_sd)
	check("five_elements_enhance tăng lên 50", stats.five_elements_enhance == 50)

	var applied_absorb := MagicAttribTable.apply(stats, "damage_absorb_p", Vector3i(100, 0, 0))
	check("MagicAttribTable hỗ trợ damage_absorb_p", applied_absorb)
	check("damage_absorb_p nhận đúng 100%", stats.damage_absorb_p == 100)

	var applied_sorb := MagicAttribTable.apply(stats, "sorbdamage_p", Vector3i(100, 0, 0))
	check("MagicAttribTable hỗ trợ sorbdamage_p", applied_sorb)

class TestDummyEntity extends Node2D:
	var combat_stats: CombatantStats = null
	var health: float = 100.0
	var max_health: float = 1000.0
	var mana: float = 500.0
	var skill_controller: SectSkillController = null

func test_damage_absorption() -> void:
	print("\n--- Test 4: Hóa giải / Ngăn chặn 100% sát thương trong HitResolver ---")
	var dummy := TestDummyEntity.new()
	add_child(dummy)
	dummy.combat_stats = CombatantStats.new()
	dummy.combat_stats.defense = 0

	var attacker_stats := CombatantStats.new()
	attacker_stats.attack_rating = 99999

	var mods := CombatFormulas.HitModifiers.new()
	mods.use_attack_rating = false

	# Khi chưa có khiên hóa giải -> nhận sát thương bình thường
	var normal_dmg := HitResolver.receive(dummy, dummy.combat_stats, 1000, attacker_stats, 500, 500, CombatFormulas.DamageType.PHYSICS, ElementTypes.ElementType.KIM, mods)
	check("Chưa có khiên: nhận sát thương > 0", normal_dmg > 0)

	# Khi có damage_absorb_p = 100
	dummy.combat_stats.damage_absorb_p = 100
	var blocked_dmg := HitResolver.receive(dummy, dummy.combat_stats, 1000, attacker_stats, 500, 500, CombatFormulas.DamageType.PHYSICS, ElementTypes.ElementType.KIM, mods)
	check("damage_absorb_p = 100: sát thương bị chặn 100% (bằng 0)", blocked_dmg == 0)

	# Khi có trạng thái duong_mon_hoa_giai_sat_thuong trên StatusEffectController
	dummy.combat_stats.damage_absorb_p = 0
	var status_ctrl := StatusEffectController.new()
	status_ctrl.name = "StatusEffectController"
	dummy.add_child(status_ctrl)
	status_ctrl.apply_state("duong_mon_hoa_giai_sat_thuong", {"damage_absorb_p": Vector3i(100, 0, 0)}, 5.0)

	var state_blocked_dmg := HitResolver.receive(dummy, dummy.combat_stats, 1000, attacker_stats, 500, 500, CombatFormulas.DamageType.PHYSICS, ElementTypes.ElementType.KIM, mods)
	check("Trạng thái duong_mon_hoa_giai_sat_thuong: chặn 100% sát thương (bằng 0)", state_blocked_dmg == 0)

	dummy.queue_free()

func test_auto_rescue_trigger() -> void:
	print("\n--- Test 5: Logic kích hoạt tự cứu khi máu dưới 25% ---")
	var dummy := TestDummyEntity.new()
	add_child(dummy)
	dummy.combat_stats = CombatantStats.new()

	var status_ctrl := StatusEffectController.new()
	status_ctrl.name = "StatusEffectController"
	dummy.add_child(status_ctrl)

	var controller := SectSkillController.new()
	dummy.add_child(controller)
	dummy.skill_controller = controller

	# Tạo Mock Profile học Đường Môn Hấp Tinh Trận cấp 20
	var prof := PlayerProfile.new()
	prof.current_sect = "duong_mon"
	prof.skill_levels["duong_mon_hap_tinh_tran"] = 20
	controller.setup_profile(prof)

	var skill_def := controller._find_sect_skill("duong_mon_hap_tinh_tran")
	check("Controller tìm thấy skill_def Hấp Tinh Trận", skill_def != null)
	check("Kỹ năng Hấp Tinh Trận usable", controller.is_skill_usable(skill_def))

	# Ép kích hoạt tự cứu nhiều lần (seed ngẫu nhiên để pass rate)
	var triggered := false
	for i in range(100):
		controller._auto_reply_cooldowns.clear()
		controller.trigger_auto_rescue_skills(dummy)
		if status_ctrl.has_state("duong_mon_hoa_giai_sat_thuong"):
			triggered = true
			break

	check("Hấp Tinh Trận kích hoạt thành công trạng thái Hóa Giải Sát Thương", triggered)
	check("Hồi chiêu (cooldown) được thiết lập là 10 giây", is_equal_approx(controller._auto_reply_cooldowns.get("duong_mon_hap_tinh_tran", 0.0), 10.0))

	dummy.queue_free()

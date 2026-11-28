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
	print("=== BẮT ĐẦU KIỂM TRA SKILL 180 THIÊN VƯƠNG (CHINH CHIẾN BÁT PHƯƠNG) ===")
	test_skill_definition()
	test_hotbar_assignment_forbidden()
	test_magic_attribs_and_stats()
	test_cleanse_and_immunity()
	test_missile_dodge()
	test_auto_reply_trigger()

	print("\n=== KẾT THÚC KIỂM TRA: %d/%d test passed ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL THIEN VUONG 180 TESTS PASSED!")
	else:
		push_error("SOME TESTS FAILED!")
	get_tree().quit(0 if passed_tests == total_tests else 1)

func test_skill_definition() -> void:
	print("\n--- Test 1: Thuộc tính kỹ năng Chinh Chiến Bát Phương ---")
	var sect: SectDefinition = load("res://systems/sect/data/thien_vuong_bang.tres")
	check("Load được thien_vuong_bang.tres", sect != null)
	if not sect:
		return

	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "thien_vuong_chinh_chien_bat_phuong":
			skill = s
			break

	check("Tìm thấy skill Chinh Chiến Bát Phương", skill != null)
	if not skill:
		return

	check("Skill là Bị động (category = PASSIVE)", skill.category == SkillDefinition.SkillCategory.PASSIVE)
	check("is_active = false", skill.is_active == false)
	check("is_hotbar = false", skill.is_hotbar == false)
	check("school_text là Bị động", "Bị động" in skill.school_text)
	check("req_level = 180", skill.req_level == 180)
	check("vltk_skill_id = 1221", skill.vltk_skill_id == 1221)
	check("Có vltk_attribs autoreplyskill", skill.vltk_attribs.has("autoreplyskill"))
	check("Có vltk_attribs seriesdamage_p", skill.vltk_attribs.has("seriesdamage_p"))
	check("Có vltk_attribs missle_missrate", skill.vltk_attribs.has("missle_missrate"))
	check("Có vltk_attribs ignorenegativestate_p", skill.vltk_attribs.has("ignorenegativestate_p"))

func test_hotbar_assignment_forbidden() -> void:
	print("\n--- Test 2: Không cho phép kéo vào thanh Hotbar ---")
	var sect: SectDefinition = load("res://systems/sect/data/thien_vuong_bang.tres")
	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "thien_vuong_chinh_chien_bat_phuong":
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

	var applied_missle := MagicAttribTable.apply(stats, "missle_missrate", Vector3i(80, 0, 0))
	check("MagicAttribTable hỗ trợ missle_missrate", applied_missle)
	check("missile_miss_rate nhận đúng 80%", stats.missile_miss_rate == 80)

	var applied_ignore := MagicAttribTable.apply(stats, "ignorenegativestate_p", Vector3i(100, 0, 0))
	check("MagicAttribTable hỗ trợ ignorenegativestate_p", applied_ignore)
	check("ignore_negative_state_p nhận đúng 100%", stats.ignore_negative_state_p == 100)

class TestDummyEntity extends Node2D:
	var combat_stats: CombatantStats = null

func test_cleanse_and_immunity() -> void:
	print("\n--- Test 4: Hóa giải và Miễn nhiễm trạng thái tiêu cực ---")
	var dummy := TestDummyEntity.new()
	add_child(dummy)
	var controller := StatusEffectController.new()
	controller.name = "StatusEffectController"
	dummy.add_child(controller)

	# 1. Thêm các hiệu ứng xấu: freeze, stun, poison, debuff
	controller.apply_effect(StatusEffect.new("freeze", 5.0, 0.0, 1.0, 0.5))
	controller.apply_effect(StatusEffect.new("stun", 3.0))
	controller.apply_effect(StatusEffect.new("poison", 10.0, 50.0, 1.0))
	controller.apply_state("debuff_test", {"physicsres_p": Vector3i(-20, 0, 0)}, 5.0, {"name": "Bùa giảm thủ", "is_debuff": true, "state_id": 10})

	check("Trước khi giải: dính freeze", controller.has_effect("freeze"))
	check("Trước khi giải: dính stun", controller.has_effect("stun"))
	check("Trước khi giải: dính poison", controller.has_effect("poison"))
	check("Trước khi giải: dính debuff_test", controller.has_state("debuff_test"))

	# 2. Hóa giải bằng cleanse_negative_effects()
	controller.cleanse_negative_effects()
	check("Sau khi giải: hết freeze", not controller.has_effect("freeze"))
	check("Sau khi giải: hết stun", not controller.has_effect("stun"))
	check("Sau khi giải: hết poison", not controller.has_effect("poison"))
	check("Sau khi giải: hết debuff_test", not controller.has_state("debuff_test"))

	# 3. Gán miễn dịch trạng thái tiêu cực
	var cstats := CombatantStats.new()
	cstats.ignore_negative_state_p = 100
	dummy.combat_stats = cstats

	controller.apply_effect(StatusEffect.new("freeze", 5.0, 0.0, 1.0, 0.5))
	controller.apply_effect(StatusEffect.new("stun", 3.0))
	controller.apply_state("debuff_test2", {"physicsres_p": Vector3i(-20, 0, 0)}, 5.0, {"name": "Bùa", "is_debuff": true, "state_id": 11})
	check("Khi miễn dịch: không bị dính freeze mới", not controller.has_effect("freeze"))
	check("Khi miễn dịch: không bị dính stun mới", not controller.has_effect("stun"))
	check("Khi miễn dịch: không bị dính debuff mới", not controller.has_state("debuff_test2"))

	dummy.queue_free()

func test_missile_dodge() -> void:
	print("\n--- Test 5: Né tránh phi đạn (missile_miss_rate) ---")
	var defender_node := TestDummyEntity.new()
	add_child(defender_node)
	var defender_stats := CombatantStats.new()
	defender_stats.max_hp = 1000
	defender_stats.missile_miss_rate = 100  # 100% né phi đạn
	defender_node.combat_stats = defender_stats

	var attacker_stats := CombatantStats.new()
	attacker_stats.attack_rating = 10000

	# Đòn phi đạn (is_melee = false)
	var mods := CombatFormulas.HitModifiers.new()
	mods.is_melee = false
	mods.use_attack_rating = false  # bỏ qua AR roll để test trực tiếp missile miss rate

	var dmg := HitResolver.receive(defender_node, defender_stats, 1000, attacker_stats, 100, 100, CombatFormulas.DamageType.PHYSICS, ElementTypes.ElementType.KIM, mods)
	check("Đòn phi đạn bị né 100% (HitResolver.MISSED)", dmg == HitResolver.MISSED)

	# Đòn cận chiến (is_melee = true) -> không bị né bởi missile_miss_rate
	mods.is_melee = true
	var melee_dmg := HitResolver.receive(defender_node, defender_stats, 1000, attacker_stats, 100, 100, CombatFormulas.DamageType.PHYSICS, ElementTypes.ElementType.KIM, mods)
	check("Đòn cận chiến KHÔNG bị né bởi missile_miss_rate", melee_dmg > 0)

	defender_node.queue_free()

func test_auto_reply_trigger() -> void:
	print("\n--- Test 6: Tự động kích hoạt Du Long Chân Khí khi nhận sát thương ---")
	var player_dummy := TestDummyEntity.new()
	add_child(player_dummy)
	var status := StatusEffectController.new()
	status.name = "StatusEffectController"
	player_dummy.add_child(status)

	var controller := SectSkillController.new()
	controller.name = "SectSkillController"
	player_dummy.add_child(controller)

	var sect: SectDefinition = load("res://systems/sect/data/thien_vuong_bang.tres")
	controller.setup(sect)

	# Tạo profile học skill Chinh Chiến Bát Phương cấp 20
	var prof := PlayerProfile.new()
	prof.sect_id = "thien_vuong_bang"
	prof.skill_levels["thien_vuong_chinh_chien_bat_phuong"] = 20
	GameManager.local_profile = prof

	var skill_def := controller._find_sect_skill("thien_vuong_chinh_chien_bat_phuong")
	check("Tìm thấy skill môn phái", skill_def != null)
	check("Skill usable", controller.is_skill_usable(skill_def))

	# Giả lập kích hoạt trực tiếp trigger_du_long_chan_khi
	controller._trigger_du_long_chan_khi(player_dummy, 20, 3.0, skill_def)

	check("Sau khi kích hoạt: có trạng thái thien_vuong_dulong_chan_khi", status.has_state("thien_vuong_dulong_chan_khi"))
	var state_info = status._states.get("thien_vuong_dulong_chan_khi")
	check("State có thuộc tính missle_missrate", state_info != null and state_info["attribs"].has("missle_missrate"))
	check("State có thuộc tính ignorenegativestate_p", state_info != null and state_info["attribs"].has("ignorenegativestate_p"))

	player_dummy.queue_free()

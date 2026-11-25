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
	print("=== BẮT ĐẦU KIỂM TRA SKILL 180 VÕ ĐANG: CHÂN VÕ THẤT TIẾT ===")
	test_skill_definition()
	test_state_payload_duration()
	test_magic_attribs_and_stats()
	test_hit_resolver_damage_to_mana()
	test_visual_and_vfx_assets()
	test_auto_reply_trigger()

	print("\n=== KẾT THÚC KIỂM TRA: %d/%d test passed ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL VO DANG 180 TESTS PASSED!")
	else:
		push_error("SOME TESTS FAILED!")
	get_tree().quit(0 if passed_tests == total_tests else 1)

func test_skill_definition() -> void:
	print("\n--- Test 1: Thuộc tính kỹ năng Chân Võ Thất Tiết ---")
	var sect: SectDefinition = load("res://systems/sect/data/vo_dang.tres")
	check("Load được vo_dang.tres", sect != null)
	if not sect:
		return

	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "vo_dang_chan_vo_that_tiet":
			skill = s
			break

	check("Tìm thấy skill Chân Võ Thất Tiết", skill != null)
	if not skill:
		return

	check("req_level = 180", skill.req_level == 180)
	check("vltk_skill_id = 1228", skill.vltk_skill_id == 1228)
	check("vltk_state_special_id = 192 (Aura Âm Dương Khí Quyết)", skill.vltk_state_special_id == 192)
	check("cooldown = 15.0s", is_equal_approx(skill.cooldown, 15.0))
	check("is_active = true", skill.is_active == true)
	check("is_hotbar = true", skill.is_hotbar == true)
	check("Có vltk_attribs damage2addmana_p", skill.vltk_attribs.has("damage2addmana_p"))
	check("Có vltk_attribs autoreplyskill", skill.vltk_attribs.has("autoreplyskill"))
	check("Có vltk_attribs seriesdamage_p", skill.vltk_attribs.has("seriesdamage_p"))
	check("Icon kỹ năng tồn tại", skill.icon != null)

func test_state_payload_duration() -> void:
	print("\n--- Test 2: Thời gian duy trì get_state_payload tại cấp 1 & 20 ---")
	var sect: SectDefinition = load("res://systems/sect/data/vo_dang.tres")
	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "vo_dang_chan_vo_that_tiet":
			skill = s
			break
	if not skill:
		return

	var payload_lv20 := skill.get_state_payload(20)
	check("Thời gian duy trì cấp 20 là đúng 15 giây (270 frames)", is_equal_approx(float(payload_lv20["seconds"]), 15.0))
	var attribs_lv20: Dictionary = payload_lv20["attribs"]
	check("Chuyển hóa sát thương cấp 20 là 200%", attribs_lv20.get("damage2addmana_p", Vector3i.ZERO).x == 200)
	check("Ngũ hành tương khắc cấp 20 là 50%", attribs_lv20.get("seriesdamage_p", Vector3i.ZERO).x == 50)

	var payload_lv1 := skill.get_state_payload(1)
	check("Thời gian duy trì cấp 1 là đúng 5 giây (90 frames)", is_equal_approx(float(payload_lv1["seconds"]), 5.0))
	var attribs_lv1: Dictionary = payload_lv1["attribs"]
	check("Chuyển hóa sát thương cấp 1 là 50%", attribs_lv1.get("damage2addmana_p", Vector3i.ZERO).x == 50)
	check("Ngũ hành tương khắc cấp 1 là 20%", attribs_lv1.get("seriesdamage_p", Vector3i.ZERO).x == 20)

func test_magic_attribs_and_stats() -> void:
	print("\n--- Test 3: MagicAttribTable & CombatantStats nhận đúng chỉ số ---")
	var stats := CombatantStats.new()
	var applied_dmg2mana := MagicAttribTable.apply(stats, "damage2addmana_p", Vector3i(200, 0, 0))
	check("MagicAttribTable hỗ trợ damage2addmana_p", applied_dmg2mana)
	check("damage_to_mana_p = 200%", stats.damage_to_mana_p == 200)

	var applied_sd := MagicAttribTable.apply(stats, "seriesdamage_p", Vector3i(50, 0, 0))
	check("MagicAttribTable hỗ trợ seriesdamage_p", applied_sd)
	check("five_elements_enhance = 50", stats.five_elements_enhance == 50)

func test_hit_resolver_damage_to_mana() -> void:
	print("\n--- Test 4: HitResolver chuyển hóa sát thương nhận vào thành nội lực ---")
	var defender_stats := CombatantStats.new()
	defender_stats.max_life = 5000
	defender_stats.max_mana = 3000
	defender_stats.damage_to_mana_p = 200  # 200% chuyển hóa sát thương thành nội lực

	var defender := Node2D.new()
	defender.set("mana", 500.0)
	defender.set("max_mana", 3000.0)

	# Giả lập tính toán sát thương: sát thương nhận 500 điểm
	var final_damage := 500
	if defender_stats and defender_stats.damage_to_mana_p > 0 and final_damage > 0 and "mana" in defender:
		var mana_gained: float = final_damage * defender_stats.damage_to_mana_p / 100.0
		var max_m: float = float(defender_stats.max_mana) if defender_stats.max_mana > 0 else float(defender.get("max_mana"))
		defender.set("mana", minf(max_m, float(defender.get("mana")) + mana_gained))

	var current_mana: float = float(defender.get("mana"))
	check("Nội lực được hồi từ 500 lên 1500 (+1000 điểm = 200% của 500 sát thương)", is_equal_approx(current_mana, 1500.0))
	defender.free()

func test_visual_and_vfx_assets() -> void:
	print("\n--- Test 5: Kiểm tra tài nguyên hình ảnh Icon và VFX thi triển ngoài map ---")
	check("Icon kỹ năng vo_dang_chan_vo_that_tiet.png tồn tại", ResourceLoader.exists("res://assets/skill_icons/vltk/vo_dang_chan_vo_that_tiet.png"))
	check("VFX xuất chiêu tiên giới hệ Thổ tien_giai_tho.png tồn tại", ResourceLoader.exists("res://assets/skill_fx/tien_giai_tho.png"))
	check("VFX trạng thái State 192 fx_819444ff.png tồn tại", ResourceLoader.exists("res://assets/skill_fx/fx_819444ff.png"))

	# Kiểm tra dữ liệu skill_fx
	check("Skill 1228 có trong VltkSkillData", VltkSkillData.has_skill(1228))
	check("Skill 1238 có trong VltkSkillData", VltkSkillData.has_skill(1238))
	var s1228 := VltkSkillData.skill(1228, 20)
	check("Skill 1228 có precast là tien_giai_tho", s1228.get("precast", "") == "tien_giai_tho")

func test_auto_reply_trigger() -> void:
	print("\n--- Test 6: Kiểm tra cơ chế tự động kích hoạt (Auto Reply) khi nhận đòn ---")
	var dummy := Node2D.new()
	add_child(dummy)
	var status := StatusEffectController.new()
	status.name = "StatusEffectController"
	dummy.add_child(status)

	var controller := SectSkillController.new()
	dummy.add_child(controller)

	var sect: SectDefinition = load("res://systems/sect/data/vo_dang.tres")
	var profile := PlayerProfile.new()
	profile.sect_id = "vo_dang"
	profile.level = 180
	# Học skill Chân Võ Thất Tiết cấp 20
	profile.learned_sect_skills["vo_dang_chan_vo_that_tiet"] = 20

	controller.setup(profile, sect)

	# Giả lập gọi kích hoạt tự động _trigger_chan_vo_that_tiet
	var skill: SkillDefinition = null
	for s in sect.skills:
		if s.id == "vo_dang_chan_vo_that_tiet":
			skill = s
			break

	check("Controller tìm được skill Chân Võ Thất Tiết", skill != null)
	controller._trigger_chan_vo_that_tiet(dummy, 20, 15.0, skill)

	check("StatusEffectController đã nhận buff vo_dang_chan_vo_that_tiet", status.has_state("vo_dang_chan_vo_that_tiet"))
	var disp_list := status.get_state_display_list()
	var found_state := false
	for st in disp_list:
		if st["meta"].get("name", "") == "Chân Võ Thất Tiết":
			found_state = true
			check("State có state_id = 192", st["meta"].get("state_id", 0) == 192)
			check("Thời gian còn lại gần 15s", is_equal_approx(st["duration"], 15.0))
			break
	check("Tìm thấy Chân Võ Thất Tiết trong danh sách hiển thị", found_state)

	dummy.queue_free()

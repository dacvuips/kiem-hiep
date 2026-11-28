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
	print("--- BẮT ĐẦU KIỂM TRA SKILL 120 VŨ HỒN (TRUNG VŨ LƯU PHONG) ---")
	test_skill_definition()
	test_healing_formula()
	await test_mechanics()

	print("--- KẾT THÚC KIỂM TRA: %d/%d test passed ---" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL VU HON 120 TESTS PASSED!")

func test_skill_definition() -> void:
	print("\n--- Test 1: Kiểm tra định nghĩa Resource Vũ Hồn ---")
	var sect: SectDefinition = SectRegistry.get_by_id("vu_hon")
	check("Tìm thấy môn phái vu_hon", sect != null)
	if sect == null:
		return

	var skill_1984: SkillDefinition = null
	var skill_1982: SkillDefinition = null
	for s in sect.skills:
		if s.id == "vu_hon_trung_vu_luu_phong":
			skill_1984 = s
		elif s.id == "vu_hon_vu_muc_di_thu":
			skill_1982 = s

	check("Có skill vu_hon_trung_vu_luu_phong (ID 1984)", skill_1984 != null)
	check("Có skill vu_hon_vu_muc_di_thu (ID 1982)", skill_1982 != null)
	if skill_1984:
		check("ReqLevel Trung Vũ Lưu Phong là 120", skill_1984.req_level == 120)
		check("Trung Vũ Lưu Phong có 2 stat lines", skill_1984.stat_lines.size() >= 2)
		if skill_1984.stat_lines.size() >= 2:
			var heal_line: SkillStatLine = skill_1984.stat_lines[0]
			check("Stat line 1 là hồi sinh lực", heal_line.label.contains("hồi") and heal_line.suffix.contains("sinh lực"))
			check("Stat line 1 hồi 51% ở max level (20)", int(round(heal_line.value_at_max_level)) == 51)

func test_healing_formula() -> void:
	print("\n--- Test 2: Kiểm tra công thức hồi máu theo cấp độ ---")
	# Công thức:
	# lvl 1: 30%
	# lvl 20: 30 + 19 * 30 / 27 = 51.11% -> floor = 51%
	# lvl 21: 30 + 20 * 30 / 27 = 52.22% -> floor = 52%
	var calc_pct := func(lvl: int) -> int:
		var pct: float = 30.0
		if lvl <= 28:
			pct = 30.0 + float(lvl - 1) * (60.0 - 30.0) / 27.0
		elif lvl <= 34:
			pct = 60.0 + float(lvl - 28) * (70.0 - 60.0) / 6.0
		else:
			pct = 70.0 + float(lvl - 34) * (71.0 - 70.0) / 1.0
		return int(floor(pct))

	check("Cấp 1 hồi 30%", calc_pct.call(1) == 30)
	check("Cấp 10 hồi 40%", calc_pct.call(10) == 40)
	check("Cấp 20 hồi đúng 51%", calc_pct.call(20) == 51)
	check("Cấp 21 hồi đúng 52%", calc_pct.call(21) == 52)
	check("Cấp 28 hồi đúng 60%", calc_pct.call(28) == 60)

func test_mechanics() -> void:
	print("\n--- Test 3: Kiểm tra cơ chế kích hoạt khi buff kết thúc ---")
	var dummy := CharacterBody2D.new()
	dummy.name = "TestPlayer"
	var status := StatusEffectController.new()
	status.name = "StatusEffectController"
	dummy.add_child(status)

	var skill_ctrl := SectSkillController.new()
	skill_ctrl.name = "SectSkillController"
	var sect: SectDefinition = SectRegistry.get_by_id("vu_hon")
	skill_ctrl.setup(sect)
	dummy.add_child(skill_ctrl)
	add_child(dummy)

	dummy.set("max_health", 10000.0)
	dummy.set("health", 1000.0)

	var expired_detected := false
	status.state_expired.connect(func(source_id: String, _meta: Dictionary):
		if source_id == "vu_hon_vu_muc_di_thu":
			expired_detected = true
			skill_ctrl.on_state_expired(dummy, source_id, _meta)
	)

	# Áp buff Vũ Mục Di Thư với thời gian ngắn 0.05s
	status.apply_state("vu_hon_vu_muc_di_thu", {"lock_life": Vector3i(100, 0, 0)}, 0.05, {"name": "Vũ Mục Di Thư"})
	check("Trạng thái Vũ Mục Di Thư được áp", status.has_state("vu_hon_vu_muc_di_thu"))

	# Chờ buff hết hạn
	await get_tree().create_timer(0.1).timeout
	check("Trạng thái hết hạn đã được bắt", expired_detected)
	check("Trạng thái không còn tồn tại sau khi hết hạn", not status.has_state("vu_hon_vu_muc_di_thu"))

	dummy.queue_free()

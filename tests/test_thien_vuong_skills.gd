extends Node
## Kiểm tra toàn diện kỹ năng Thiên Vương Bang:
## 1. Hệ Ngũ Hành: Phải là hệ Kim (0), không có chữ '(hệ Hỏa)' trong tên kỹ năng.
## 2. Tiêu hao sinh lực: Kỹ năng chủ động tiêu hao Sinh lực (HP), KHÔNG tiêu hao Nội lực (Mana).
## 3. Điều kiện thi triển: Khi máu <= tiêu hao thì không đủ sinh lực xuất chiêu; khi đủ máu thì trừ máu chính xác.
## 4. Kỹ năng 8x/90 Truy Phong Quyết (325): Có child 408 (Form 2 SPREAD, 3 tia đạn chùy bay 3 hướng), 3 đòn liên tiếp.

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
	print("--- BẮT ĐẦU KIỂM TRA SKILL THIÊN VƯƠNG BANG ---")
	test_sect_and_elements()
	test_life_cost_data()
	test_cast_health_deduction()
	test_truy_phong_quyet_3_directions()

	print("--- KẾT THÚC KIỂM TRA: %d/%d test passed ---" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL THIEN VUONG TESTS PASSED!")
	else:
		push_error("SOME TESTS FAILED!")

func test_sect_and_elements() -> void:
	print("\n--- Test 1: Môn phái Thiên Vương Bang và Hệ Ngũ Hành ---")
	var sect: SectDefinition = load("res://systems/sect/data/thien_vuong_bang.tres")
	check("Load được thien_vuong_bang.tres", sect != null)
	if not sect:
		return

	var all_kim := true
	var no_hoa_text := true
	for s in sect.skills:
		if s.element != ElementTypes.ElementType.KIM:
			all_kim = false
			print("Skill %s sai hệ: %d (mong đợi KIM = 0)" % [s.skill_name, s.element])
		if "(hệ Hỏa)" in s.skill_name or "hệ hỏa" in s.skill_name.to_lower():
			no_hoa_text = false
			print("Skill %s còn chứa chữ hệ Hỏa" % s.skill_name)

	check("Tất cả skill Thiên Vương đều thuộc hệ Kim (element = 0)", all_kim)
	check("Không có skill nào bị dán nhãn nhầm '(hệ Hỏa)'", no_hoa_text)

func test_life_cost_data() -> void:
	print("\n--- Test 2: Dòng tiêu hao sinh lực của kỹ năng Thiên Vương ---")
	var sect: SectDefinition = load("res://systems/sect/data/thien_vuong_bang.tres")
	if not sect:
		return

	# Các kỹ năng chủ động tiêu hao sinh lực mẫu
	var samples := [
		{"id": "thien_vuong_zhanlong_jue", "name": "Trảm Long Quyết", "c1": 2, "c20": 6},
		{"id": "thien_vuong_huifeng_luoyan", "name": "Hồi Phong Lạc Nhạn", "c1": 4, "c20": 10},
		{"id": "thien_vuong_duanhun_ci", "name": "Đoạn Hồn Thích", "c1": 10, "c20": 20},
		{"id": "thien_vuong_xuezhan_bafang", "name": "Huyết Chiến Bát Phương", "c1": 11, "c20": 45},
		{"id": "thien_vuong_potian_zhan", "name": "Phá Thiên Trảm", "c1": 15, "c20": 30},
		{"id": "thien_vuong_zhuifeng_jue", "name": "Truy Phong Quyết", "c1": 10, "c20": 30},
		{"id": "thien_vuong_chuitianwang150", "name": "Tung Hoành Bát Hoang", "c1": 12, "c20": 36},
	]

	for sample in samples:
		var found: SkillDefinition = null
		for s in sect.skills:
			if s.id == sample["id"]:
				found = s
				break
		check("Tìm thấy skill %s" % sample["name"], found != null)
		if found:
			var lcost_1 := found.get_life_cost_at_level(1)
			var lcost_20 := found.get_life_cost_at_level(20)
			var mcost_1 := found.get_mana_cost_at_level(1)
			check("%s tiêu hao sinh lực cấp 1 = %d (thực tế: %d)" % [sample["name"], sample["c1"], lcost_1], lcost_1 == sample["c1"])
			check("%s tiêu hao sinh lực cấp 20 = %d (thực tế: %d)" % [sample["name"], sample["c20"], lcost_20], lcost_20 == sample["c20"])
			check("%s KHÔNG tiêu hao nội lực (mana_cost = 0)" % sample["name"], mcost_1 == 0)

func test_cast_health_deduction() -> void:
	print("\n--- Test 3: Trừ sinh lực khi thi triển kỹ năng Thiên Vương ---")
	var profile := PlayerProfile.new()
	profile.sect_id = "thien_vuong_bang"
	GameManager.local_profile = profile

	var sect: SectDefinition = load("res://systems/sect/data/thien_vuong_bang.tres")
	var skill_test: SkillDefinition = null
	for s in sect.skills:
		if s.id == "thien_vuong_zhanlong_jue":
			skill_test = s
			break
	check("Có skill test Trảm Long Quyết", skill_test != null)
	if not skill_test:
		return

	var controller := SectSkillController.new()
	controller.setup(sect)

	# Giả lập Caster với health và mana
	var dummy_caster := Node2D.new()
	dummy_caster.set_script(load("res://tests/mock_caster.gd") if ResourceLoader.exists("res://tests/mock_caster.gd") else null)
	dummy_caster.set("health", 100.0)
	dummy_caster.set("max_health", 100.0)
	dummy_caster.set("mana", 50.0)
	dummy_caster.set("max_mana", 50.0)
	dummy_caster.add_to_group("player")

	var dummy_target := Node2D.new()
	dummy_target.add_to_group("enemies")

	var cost := skill_test.get_life_cost_at_level(1)
	check("Trảm Long Quyết tiêu hao sinh lực = 2", cost == 2)

	# Case 1: Đủ máu -> Ra chiêu thành công, máu bị trừ đúng 2 điểm, mana giữ nguyên 50
	dummy_caster.set("health", 100.0)
	dummy_caster.set("mana", 50.0)
	var cast_ok = controller.cast_skill(skill_test, dummy_caster, dummy_target)
	check("Thi triển thành công khi đủ sinh lực", cast_ok)
	check("Sinh lực bị trừ đúng 2 điểm (còn 98)", is_equal_approx(float(dummy_caster.get("health")), 98.0))
	check("Nội lực giữ nguyên 50 (không bị trừ)", is_equal_approx(float(dummy_caster.get("mana")), 50.0))

	# Case 2: Máu không đủ (health <= cost) -> Ra chiêu thất bại, không bị trừ máu
	dummy_caster.set("health", 2.0)
	var cast_fail = controller.cast_skill(skill_test, dummy_caster, dummy_target)
	check("Thi triển thất bại khi máu <= cost (không cho tự sát)", not cast_fail)
	check("Máu vẫn giữ nguyên 2", is_equal_approx(float(dummy_caster.get("health")), 2.0))

	dummy_caster.free()
	dummy_target.free()
	controller.free()

func test_truy_phong_quyet_3_directions() -> void:
	print("\n--- Test 4: Truy Phong Quyết (Chùy 90) đánh ra 3 hướng ---")
	var skills_fx_file := FileAccess.open("res://data/skill_fx/skills.json", FileAccess.READ)
	check("Mở được data/skill_fx/skills.json", skills_fx_file != null)
	if not skills_fx_file:
		return

	var skills_json: Dictionary = JSON.parse_string(skills_fx_file.get_as_text())
	skills_fx_file.close()

	check("Có dữ liệu skill 325 (Truy Phong Quyết)", skills_json.has("325"))
	var s325: Dictionary = skills_json.get("325", {})
	check("Skill 325 có child = 408", int(s325.get("child", 0)) == 408)
	check("Skill 325 có child_num = 3 (3 đòn liên tiếp)", int(s325.get("child_num", 0)) == 3)
	check("Skill 325 form = 12 (Melee_ManyAttack)", int(s325.get("form", 0)) == 12)

	check("Có dữ liệu child skill 408", skills_json.has("408"))
	var s408: Dictionary = skills_json.get("408", {})
	check("Child skill 408 form = 2 (SPREAD - hình nan quạt / tỏa các hướng)", int(s408.get("form", 0)) == 2)
	check("Child skill 408 child_num = 3 (BẮN RA 3 TIA / 3 HƯỚNG)", int(s408.get("child_num", 0)) == 3)
	check("Child skill 408 base = 1 (Sinh đạn trực tiếp từ BaseSkill)", int(s408.get("base", 0)) == 1)
	check("Child skill 408 child = 141 (Missile 141 Truy Phong Quyết)", int(s408.get("child", 0)) == 141)

	# Kiểm tra missile 141
	var msl_file := FileAccess.open("res://data/skill_fx/missiles.json", FileAccess.READ)
	if msl_file:
		var msl_json: Dictionary = JSON.parse_string(msl_file.get_as_text())
		msl_file.close()
		check("Missile 141 tồn tại trong missiles.json", msl_json.has("141"))
		var m141: Dictionary = msl_json.get("141", {})
		check("Missile 141 tên đúng 'Truy Phong Quyết'", m141.get("name", "").strip_edges() == "Truy Phong Quyết")

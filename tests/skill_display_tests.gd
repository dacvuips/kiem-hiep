extends Node
## Popup skill khớp nguồn gốc VLTK: chữ nội/ngoại công theo IsPhysical, số dòng chỉ số theo mốc lua (level_points).
## Số liệu gốc kiểm bằng tools/audit_skill_display.py; ở đây chốt vài mẫu để không hồi quy.

var _passes := 0
var _fails := 0

func _ready() -> void:
	print("\n--- TEST HIỂN THỊ SKILL ---")
	var con_lon := _sect("con_lon")
	var cuong_loi := _skill(con_lon, "Cuồng Lôi Chấn Địa")
	check("Cuồng Lôi Chấn Địa ghi Nội công (IsPhysical=0)", cuong_loi != null and "(Nội công)" in cuong_loi.school_text \
		and not cuong_loi.is_physical())

	## Thiên Lôi Chấn Nhạc skill_cost_v gốc = {1,48},{15,72},{20,115},{23,166},{26,192}
	var thien_loi := _skill(con_lon, "Thiên Lôi Chấn Nhạc")
	check("Thiên Lôi Chấn Nhạc: tiêu hao cấp 2 = 49 (gốc)", thien_loi != null and thien_loi.get_mana_cost_at_level(2) == 49)
	check("Thiên Lôi Chấn Nhạc: tiêu hao cấp 20 = 115 (gốc, không phải mốc cấp 26)",
		thien_loi != null and thien_loi.get_mana_cost_at_level(20) == 115)
	check("Thiên Lôi Chấn Nhạc: cấp cộng thêm 23 = 166", thien_loi != null and thien_loi.get_mana_cost_at_level(23) == 166)
	var text := ""
	if thien_loi != null:
		for l in thien_loi.stat_lines:
			text += l.format_at_level(thien_loi, 20) + "\n"
	check("Popup Thiên Lôi Chấn Nhạc cấp 20 ghi 'Tiêu hao nội lực: 115'", "Tiêu hao nội lực: 115" in text)

	## Ngũ Độc theo bản 15 phái: Đoạn Cân Hủ Cốt allres_p = {1,-1},{20,-15}
	var doan_can := _skill(_sect("ngu_doc_giao"), "Đoạn Cân Hủ Cốt")
	var line: SkillStatLine = null
	if doan_can != null:
		for l in doan_can.stat_lines:
			if l.label == "Kháng tất cả":
				line = l
	check("Đoạn Cân Hủ Cốt: Kháng tất cả cấp 20 = -15", line != null and doan_can.stat_line_range(line, 20).x == -15)

	## Dòng chưa có mốc lua vẫn nội suy thẳng như cũ
	var plain := SkillStatLine.new()
	plain.value_at_level_1 = 10
	plain.value_at_max_level = 29
	var dummy := SkillDefinition.new()
	dummy.max_level = 20
	check("Dòng không có mốc lua: nội suy thẳng", dummy.stat_line_range(plain, 20).x == 29 and dummy.stat_line_range(plain, 1).x == 10)

	print("RESULT %d/%d" % [_passes, _passes + _fails])
	get_tree().quit(0 if _fails == 0 else 1)

func _sect(id: String) -> SectDefinition:
	return load("res://systems/sect/data/%s.tres" % id) as SectDefinition

func _skill(sect: SectDefinition, name_prefix: String) -> SkillDefinition:
	if sect == null:
		return null
	for s in sect.skills:
		if s.skill_name.begins_with(name_prefix):
			return s
	return null

func check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("PASS ", name)
	else:
		_fails += 1
		print("FAIL ", name)

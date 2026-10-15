extends Node
## Kiểm thử GIA NHẬP MÔN PHÁI: nhân vật mới là Vô Môn Phái (chỉ đánh thường), đủ cấp 10 mới chọn 1 phái của hệ đã chọn lúc tạo;
## bảng chọn phái hiện toàn bộ skill (đủ cấp sáng, chưa đủ tối); server chỉ nhận gia nhập 1 lần. Chạy:
##   godot --headless --path . res://tests/sect_join_tests.tscn

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame

func press(root: Node, text: String) -> bool:
	for b in root.get_tree().root.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b.disabled and b.is_visible_in_tree():
			(b as Button).pressed.emit()
			return true
	return false

func _ready() -> void:
	test_new_character()
	test_join_rules()
	test_server_guard()
	await test_choice_window()
	print("RESULT %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func test_new_character() -> void:
	var p := PlayerProfile.new()
	p.choose_element(ElementTypes.ElementType.HOA)
	check("Tạo nhân vật: Vô Môn Phái", not p.has_sect() and p.sect_name == PlayerProfile.NO_SECT_NAME, p.sect_id)
	check("Tạo nhân vật: giữ hệ đã chọn", p.get_element() == ElementTypes.ElementType.HOA)
	check("Tạo nhân vật: chỉ số khởi điểm theo hệ", [p.strength, p.dexterity, p.vitality, p.energy] == PlayerProfile.START_STATS[ElementTypes.ElementType.HOA])
	check("Tạo nhân vật: phe Tân thủ", p.get_current_camp() == Camp.Type.BEGIN)
	check("Cấp 1 chưa hỏi chọn phái", not p.needs_sect())
	var back := PlayerProfile.from_dict(p.to_dict())
	check("Lưu / nạp lại giữ hệ + Vô Môn Phái", not back.has_sect() and back.get_element() == ElementTypes.ElementType.HOA)
	## Không có phái: vẫn đánh thường, không có skill phái.
	var prev := GameManager.local_profile
	GameManager.local_profile = p
	var ctrl := SectSkillController.new()
	ctrl.setup(null)
	var main := ctrl.get_main_skill()
	check("Vô Môn Phái: nút chính = đánh thường", main != null and main.is_basic_attack, main)
	check("Vô Môn Phái: không có skill phụ", ctrl.get_sub_skills().all(func(s: SkillDefinition) -> bool: return s == null))
	ctrl.free()
	GameManager.local_profile = prev

func test_join_rules() -> void:
	var p := PlayerProfile.new()
	p.choose_element(ElementTypes.ElementType.MOC)
	var moc := SectRegistry.get_by_element(ElementTypes.ElementType.MOC)
	var kim := SectRegistry.get_by_element(ElementTypes.ElementType.KIM)
	check("Cấp 9: chưa vào phái được", not p.join_sect(moc[0]))
	p.level = PlayerProfile.NEWBIE_LEVEL
	check("Cấp 10: hỏi chọn phái", p.needs_sect())
	check("Không vào được phái khác hệ", not p.join_sect(kim[0]))
	check("Vào phái đúng hệ", p.join_sect(moc[0]) and p.sect_id == moc[0].id and p.sect_name == moc[0].sect_name)
	check("Đã có phái: không hỏi nữa", not p.needs_sect())
	check("Đã có phái: không đổi phái được", moc.size() < 2 or not p.join_sect(moc[1]))
	check("Vào phái: phe theo phái", p.get_current_camp() == Camp.default_for_sect(moc[0]))

func test_server_guard() -> void:
	var moc := SectRegistry.get_by_element(ElementTypes.ElementType.MOC)
	var kim := SectRegistry.get_by_element(ElementTypes.ElementType.KIM)
	var s := PlayerProfile.new()
	s.choose_element(ElementTypes.ElementType.MOC)
	s.server_seen = 1
	## Cấp thấp: server không nhận phái game gửi.
	var c := s.to_dict()
	c["sect_id"] = moc[0].id
	var m := ProfileGuard.merge(s.to_dict(), c)
	check("Server: cấp 1 gửi phái -> bỏ", str(m.get("sect_id", "")) == "", m.get("sect_id"))
	## Đủ cấp, đúng hệ: nhận.
	s.level = PlayerProfile.NEWBIE_LEVEL
	c = s.to_dict()
	c["sect_id"] = moc[0].id
	c["sect_name"] = "Tên giả"
	m = ProfileGuard.merge(s.to_dict(), c)
	check("Server: cấp 10 vào phái đúng hệ -> nhận", str(m.get("sect_id", "")) == moc[0].id and str(m.get("sect_name", "")) == moc[0].sect_name, [m.get("sect_id"), m.get("sect_name")])
	## Khác hệ / đổi hệ: bỏ.
	c = s.to_dict()
	c["sect_id"] = kim[0].id
	c["element"] = ElementTypes.ElementType.KIM
	m = ProfileGuard.merge(s.to_dict(), c)
	check("Server: phái khác hệ -> bỏ", str(m.get("sect_id", "")) == "" and int(m.get("element", -1)) == ElementTypes.ElementType.MOC, [m.get("sect_id"), m.get("element")])
	## Đã có phái: không đổi được.
	if moc.size() >= 2:
		s.set_sect(moc[0])
		c = s.to_dict()
		c["sect_id"] = moc[1].id
		m = ProfileGuard.merge(s.to_dict(), c)
		check("Server: đã có phái -> không đổi", str(m.get("sect_id", "")) == moc[0].id, m.get("sect_id"))
	## Tạo nhân vật kèm sẵn phái (game cũ / gian lận): về Vô Môn Phái, giữ hệ.
	var cheat := PlayerProfile.new()
	cheat.set_sect(moc[0])
	var fresh := PlayerProfile.from_dict(ProfileGuard.sanitize_new(cheat.to_dict()))
	check("Server: tạo nhân vật kèm phái -> Vô Môn Phái", not fresh.has_sect() and fresh.get_element() == ElementTypes.ElementType.MOC, fresh.sect_id)
	check("Server: Vô Môn Phái vẫn có trần sát thương đánh thường", ProfileGuard.max_hit(fresh) >= ProfileGuard.MIN_CAP)

func test_choice_window() -> void:
	var p := PlayerProfile.new()
	p.display_name = "SectTester"
	p.choose_element(ElementTypes.ElementType.THO)
	p.level = PlayerProfile.NEWBIE_LEVEL
	var win := SectChoiceWindow.open(self, p)
	await frames()
	var sects := SectRegistry.get_by_element(ElementTypes.ElementType.THO)
	for sect in sects:
		check("Bảng chọn phái: có nút gia nhập %s" % sect.sect_name,
			win.find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text == "Gia nhập %s" % sect.sect_name))
	## Ô skill = VBox có tooltip "Tên\n..." — đếm đủ skill hiện được của các phái, sáng / tối đúng theo cấp.
	var want := 0
	var want_locked := 0
	for sect in sects:
		for s in sect.skills:
			if not s.is_hidden and not s.is_basic_attack:
				want += 1
				if s.req_level > p.level:
					want_locked += 1
	var tiles := win.find_children("*", "VBoxContainer", true, false).filter(func(n: Control) -> bool: return n.tooltip_text.contains("\n"))
	var locked := tiles.filter(func(n: Control) -> bool: return n.modulate == SectChoiceWindow.LOCKED_TINT)
	check("Bảng chọn phái: hiện toàn bộ skill", tiles.size() == want, [tiles.size(), want])
	check("Bảng chọn phái: skill chưa đủ cấp tối màu", locked.size() == want_locked and want_locked > 0, [locked.size(), want_locked])
	check("Bảng chọn phái: skill đủ cấp sáng", tiles.size() - locked.size() == want - want_locked and want - want_locked > 0)
	var got: Array = []
	win.chosen.connect(func(s: SectDefinition) -> void: got.append(s))
	check("Bấm gia nhập -> hỏi xác nhận", press(self, "Gia nhập %s" % sects[0].sect_name))
	await frames()
	check("Đồng ý -> vào phái", press(self, "Đồng ý"))
	await frames()
	check("Đã vào phái đã chọn", p.sect_id == sects[0].id and got.size() == 1, p.sect_id)

extends SocialWindow
class_name SectChoiceWindow
## Bảng gia nhập môn phái — SectPrompt mở khi nhân vật Vô Môn Phái đạt PlayerProfile.NEWBIE_LEVEL. Mỗi phái của hệ đã chọn lúc tạo
## nhân vật là 1 cột: tên + chính/tà + TOÀN BỘ skill của phái; skill đủ cấp học (req_level <= cấp hiện tại) sáng, chưa đủ thì tối
## như nút bị khoá. Chọn phái (hỏi xác nhận vì không đổi được). BẮT BUỘC: không có "Để sau" / ✕, nền phía sau bị che — chọn xong
## mới chơi được (nhân vật mới vào game đã ở cấp 10, StarterKit).

signal chosen(sect: SectDefinition)

const GRID_COLUMNS := 4
const TILE_WIDTH := 84.0
const ICON_SIZE := 40.0
const LOCKED_TINT := Color(0.38, 0.38, 0.38, 0.8)

var _profile: PlayerProfile
var _done := false
var _status: Label

static func open(host: Node, profile: PlayerProfile) -> SectChoiceWindow:
	var win := SocialWindow.present(host, SectChoiceWindow.new(profile), &"sect_choice") as SectChoiceWindow
	## Che màn chơi phía sau (chặn bấm ra ngoài) cho tới khi chọn xong phái.
	var layer := win.get_parent()
	if layer is CanvasLayer and layer.get_node_or_null("SectBlocker") == null:
		var dim := GameUi.dim_rect()
		dim.name = "SectBlocker"
		layer.add_child(dim)
		layer.move_child(dim, 0)
	return win

func _init(profile: PlayerProfile = null) -> void:
	var element: ElementTypes.ElementType = profile.get_element() if profile else ElementTypes.ElementType.KIM
	super._init("Gia Nhập Môn Phái",
		"Đại hiệp đã đạt cấp %d. Hãy chọn 1 môn phái hệ %s — đã gia nhập thì KHÔNG thể đổi phái.\nSkill sáng = đủ cấp học ngay, tối = cần lên cấp."
		% [profile.level if profile else PlayerProfile.NEWBIE_LEVEL, ElementTypes.ELEMENT_NAME.get(element, "")], 420.0)
	_profile = profile
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	body.add_child(cards)
	for sect in SectRegistry.get_by_element(element):
		cards.add_child(_card(sect))
	close_button.visible = false   ## bắt buộc chọn phái: không đóng được
	## Lý do không vào được phái (ở Hub không có nhân vật để báo -> hiện ngay trên bảng).
	_status = SocialUi.label("", SocialUi.WARN, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_status.visible = false
	body.add_child(_status)

func _card(sect: SectDefinition) -> PanelContainer:
	var color: Color = ElementTypes.ELEMENT_COLOR.get(sect.element, SocialUi.TEXT)
	var sec := SocialUi.section("", color)
	var panel: PanelContainer = sec[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = sec[1]
	v.add_child(SocialUi.label(sect.sect_name, color.lightened(0.3), 18, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(SocialUi.label(SectEnums.alignment_to_string(sect.alignment), SocialUi.MUTED, 12, HORIZONTAL_ALIGNMENT_CENTER))
	var skills := sect.skills.filter(func(s: SkillDefinition) -> bool: return not s.is_hidden and not s.is_basic_attack)
	skills.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool: return a.req_level < b.req_level)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(GRID_COLUMNS * (TILE_WIDTH + 4), 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	v.add_child(scroll)
	for skill in skills:
		grid.add_child(_skill_tile(skill))
	## Phái chỉ nhận 1 giới (Nga Mi / Thúy Yên chỉ nhận nữ, Thiếu Lâm chỉ nhận nam — detu*.lua gốc GetSex): khoá nút, ghi rõ.
	if _profile != null and not _profile.gender_fits(sect):
		var only := SocialUi.stone_button("Chỉ nhận đệ tử %s" % ("nữ" if sect.required_gender == PlayerProfile.Gender.FEMALE else "nam"))
		only.disabled = true
		v.add_child(only)
		panel.modulate = LOCKED_TINT.lightened(0.4)
		return panel
	var b := SocialUi.stone_button("Gia nhập %s" % sect.sect_name)
	b.pressed.connect(func() -> void:
		SocialWindow.confirm(get_parent(), "Xác nhận gia nhập",
			"Gia nhập %s?\nSau khi gia nhập sẽ KHÔNG thể đổi môn phái." % sect.sect_name,
			func() -> void: _choose(sect)))
	v.add_child(b)
	return panel

## 1 ô skill: icon + tên + "Cấp N". Chưa đủ cấp học thì tối màu (giống nút bị khoá) + tooltip cấp cần.
func _skill_tile(skill: SkillDefinition) -> Control:
	var learnable := _profile != null and _profile.level >= skill.req_level
	var tile := VBoxContainer.new()
	tile.custom_minimum_size = Vector2(TILE_WIDTH, 0)
	tile.add_theme_constant_override("separation", 1)
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.tooltip_text = "%s\n%s" % [skill.skill_name, "Đủ cấp học" if learnable else "Cần đạt cấp %d" % skill.req_level]
	var icon := TextureRect.new()
	icon.texture = skill.icon
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	var name_label := SocialUi.label(skill.skill_name, SocialUi.TEXT, 11, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_label)
	var lv := SocialUi.label("Cấp %d" % skill.req_level, SocialUi.MUTED, 10, HORIZONTAL_ALIGNMENT_CENTER)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(lv)
	if not learnable:
		tile.modulate = LOCKED_TINT
	return tile

func _choose(sect: SectDefinition) -> void:
	if _done or _profile == null:
		return
	if not _profile.join_sect(sect):
		var why := "Đã gia nhập môn phái rồi." if _profile.has_sect() \
			else ("%s chỉ nhận đệ tử %s." % [sect.sect_name, "nam" if sect.required_gender == 0 else "nữ"]) \
			if not _profile.gender_fits(sect) \
			else "Chưa thể gia nhập môn phái: cần đạt cấp %d (hiện cấp %d)." % [PlayerProfile.NEWBIE_LEVEL, _profile.level]
		_status.text = why
		_status.visible = true
		return
	_done = true
	chosen.emit(sect)
	close_requested.emit()

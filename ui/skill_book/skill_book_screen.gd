extends CanvasLayer
class_name SkillBookScreen
## Bảng "Kĩ năng" kiểu VLTK mobile, 3 cột (bố cục trong SkillBookScreen.tscn):
##   - Trái: lưới skill môn phái (5 cột) — dưới mỗi ảnh là cấp đã học hoặc "Chưa học"; điểm kỹ năng ở cuối.
##   - Giữa: chi tiết skill đang chọn — tên, ảnh, mô tả, lưu phái, đẳng cấp hiện thời (xanh) + kế tiếp (đỏ), nút học.
##   - Phải: khung "Tùy chỉnh kỹ năng" (Không mục tiêu / Đánh theo hướng trước mặt / Chạm nhả) + thanh kỹ năng (ô chính
##     + 8 ô/trang, xếp như cụm nút trong trận); kéo skill đã học từ lưới thả vào để gắn,
##     kéo giữa 2 ô để đổi chỗ, kéo ô ra ngoài để gỡ (PlayerProfile.main_skill_id / hotbar_skill_ids).
## Quy tắc học: chưa đủ cấp / hết điểm / tối đa -> nút khoá + ghi lý do; skill luyện (practice_only, 90/120/150)
## chỉ lĩnh hội cấp 1 miễn phí. Bản debug có nút "Nâng cấp (TEST)".

const SCENE_PATH := "res://ui/skill_book/SkillBookScreen.tscn"

## Khung/nút/thẻ lấy từ GameUi (đặt Theme Type Variation trong .tscn); ở đây chỉ còn màu ngữ nghĩa của nội dung.
const COLOR_GOLD := GameUi.GOLD
const COLOR_STAT := Color(0.94, 0.94, 0.9)
const COLOR_CURRENT_LEVEL := Color(0.35, 0.95, 0.4)
const COLOR_NEXT := Color(0.95, 0.25, 0.22)
const COLOR_WARNING := GameUi.LABEL_RED
const COLOR_LINKED_SKILL := Color(0.45, 0.85, 0.4)
const COLOR_NOT_LEARNED := Color(0.75, 0.75, 0.7)

const SLOT_SIZE := Vector2(64, 82)
const ICON_SIZE := 48.0
## Cột phải xếp Y HỆT cụm nút skill trong trận (SkillBarUI.tscn): tâm tính từ góc dưới-phải + đường kính, thu nhỏ
## WHEEL_SCALE cho vừa %Wheel. Sửa vị trí trong SkillBarUI.tscn thì cập nhật bảng này cho khớp.
const WHEEL_SCALE := 0.56   ## vừa cả hàng nút tiện ích (Ngồi / Nhảy / Ngựa) ở đáy trái
const WHEEL_MAIN := [Vector2(-71, -146), 108.0]
const WHEEL_SUBS := [Vector2(-168, -47), Vector2(-241, -115), Vector2(-188, -199), Vector2(-126, -264),
		Vector2(-156, -342), Vector2(-41, -322), Vector2(-34, -228), Vector2(-241, -282)]
const WHEEL_SUB_SIZE := 64.0
const WHEEL_PAGES := [Vector2(-264, -44), Vector2(-60, -44)]
const WHEEL_PAGE_SIZE := Vector2(78, 46)
## 1 vòng tròn nhỏ "thi triển liên tục" (PlayerProfile.loop_skill_ids) — cùng vị trí với 2 ô trong SkillBarUI.tscn.
const LOOP_BASE := SkillBarUI.LOOP_SLOT_BASE
const WHEEL_LOOPS := [Vector2(-241, -51)]
const WHEEL_LOOP_SIZE := 44.0
## Nút tiện ích trên thanh skill (chỉ sắp xếp vị trí / ẩn / cỡ, không gắn kỹ năng): [khoá bố cục, ảnh thanh công cụ, tâm, cỡ, tên].
## Mã ô âm (TOOL_BASE - i) để không lẫn với ô skill (0..7), ô chính (MAIN_SLOT), ô liên tục (>= LOOP_BASE).
const TOOL_BASE := -50
const WHEEL_TOOLS := [["sit", "sit", Vector2(-445, -38), 52.0, "Ngồi"], ["jump", "jump", Vector2(-269, -209), 56.0, "Nhảy"],
	["horse", "horse", Vector2(-315, -44), 64.0, "Ngựa"]]
var _wheel_page_buttons: Array[Button] = []
var _wheel_swap: Button
## Sắp xếp vị trí các nút: bật thì KÉO 1 nút để dời chỗ (lưu vào PlayerProfile.skill_layout, cụm nút trong trận đổi theo); tắt thì kéo để gắn/gỡ kỹ năng.
var _arranging := false
## Sắp xếp: ô đang chọn (bấm không kéo) để thêm / ẩn / đổi cỡ — NO_DRAG = chưa chọn.
var _selected_slot := NO_DRAG
var _press_pos := Vector2.ZERO
var _slot_label: Label
var _slot_toggle: Button
var _slot_size_label: Label
var _arrange_button: Button
var _wheel_default_center: Dictionary = {}   ## slot -> tâm mặc định (toạ độ trong %Wheel, đã nhân WHEEL_SCALE)
var _arrange_drag_slot := NO_DRAG
const MAIN_SLOT := SkillBarUI.MAIN_SLOT
const FROM_BOOK := SkillBarUI.FROM_BOOK

var _profile: PlayerProfile
## Lưới chỉ hiện skill KHÔNG ẩn; _all_skills gồm cả skill ẩn (skill con nhúng vào chi tiết skill cha, tính hỗ trợ).
var _skills: Array[SkillDefinition] = []
var _all_skills: Array[SkillDefinition] = []
var _on_closed: Callable
var _selected: SkillDefinition
var _slots: Dictionary = {}  ## skill_id -> Button ô lưới
var _wheel_slots: Dictionary = {}  ## slot (MAIN_SLOT / 0-3) -> Control
var _dragged_wheel_slot: int = NO_DRAG
const NO_DRAG := -100
var _toast: Label
var _toast_tween: Tween

## `skills` = TOÀN BỘ sect.skills. Tham số cuối giữ cho tương thích (bảng giờ có sẵn ô gắn thanh kỹ năng).
static func open(parent: Node, profile: PlayerProfile, skills: Array[SkillDefinition], on_closed: Callable,
		_allow_drag_to_skill_bar: bool = false) -> void:
	var screen: SkillBookScreen = load(SCENE_PATH).instantiate()
	screen._profile = profile
	screen._all_skills = skills
	## Đánh thường không hiện trong bảng: nút chính trống tự dùng đòn đánh thường hợp vũ khí (SectSkillController.get_default_main_skill).
	screen._skills = skills.filter(func(s: SkillDefinition) -> bool: return not s.is_hidden and not s.is_basic_attack)
	screen._on_closed = on_closed
	parent.add_child(screen)

func _ready() -> void:
	add_to_group(UiPopups.GROUP)   ## đang mở thì lăn chuột không zoom camera
	## Vẫn bấm được khi main.gd tạm dừng game lúc mở bảng trong trận.
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameUi.apply()
	(%Dim as ColorRect).color = GameUi.DIM
	%CloseButton.pressed.connect(_on_close_pressed)
	%TestButton.pressed.connect(func() -> void:
		if _selected and _profile.debug_raise_skill(_selected.id):
			_after_skill_changed())
	%LearnButton.pressed.connect(_on_learn_pressed)
	_bind_setting(%NoTargetCheck, "no_target")
	_bind_setting(%FaceDirectionCheck, "face_direction")
	_bind_setting(%TapReleaseCheck, "tap_release")
	_build_grid()
	_build_wheel()
	_refresh()
	_select(_skills[0] if not _skills.is_empty() else null)

## Ô tick "Tùy chỉnh kỹ năng" <-> PlayerProfile.skill_settings (lưu ngay). Trong trận, đóng bảng thì thanh skill
## áp lại (chạm nhả) — xem SkillBarUI.refresh_sub_skills / Player.get_cast_target.
func _bind_setting(check: CheckBox, key: String) -> void:
	## Ô tick mặc định của Godot gần như không thấy trên nền tối -> vẽ ô vuông viền vàng (bật thì có lõi vàng).
	check.add_theme_icon_override("unchecked", _make_check_icon(false))
	check.add_theme_icon_override("checked", _make_check_icon(true))
	check.button_pressed = _profile.get_skill_setting(key)
	check.toggled.connect(func(on: bool) -> void:
		_profile.skill_settings[key] = on
		SaveManager.save_profile(_profile))

static func _make_check_icon(checked: bool) -> Texture2D:
	const SIZE := 20
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(GameUi.BG_INNER)
	var border := GameUi.BORDER_ACTIVE
	for i in SIZE:
		for t in 2:
			img.set_pixel(i, t, border); img.set_pixel(i, SIZE - 1 - t, border)
			img.set_pixel(t, i, border); img.set_pixel(SIZE - 1 - t, i, border)
	if checked:
		img.fill_rect(Rect2i(5, 5, SIZE - 10, SIZE - 10), GameUi.GOLD)
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- lưới skill (trái)

func _build_grid() -> void:
	var grid: GridContainer = %Grid
	for skill in _skills:
		var b := Button.new()
		b.custom_minimum_size = SLOT_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.pressed.connect(_select.bind(skill))
		b.set_drag_forwarding(_get_grid_drag_data.bind(skill, b), Callable(), Callable())
		var frame := Panel.new()
		frame.name = "Frame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.position = Vector2((SLOT_SIZE.x - ICON_SIZE) * 0.5 - 3, 0)
		frame.size = Vector2(ICON_SIZE + 6, ICON_SIZE + 6)
		b.add_child(frame)
		var icon := TextureRect.new()
		icon.texture = skill.icon
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = frame.position + Vector2(3, 3)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		b.add_child(icon)
		var label := Label.new()
		label.name = "LevelLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, ICON_SIZE + 8)
		label.size = Vector2(SLOT_SIZE.x, 20)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		b.add_child(label)
		b.tooltip_text = skill.skill_name
		grid.add_child(b)
		_slots[skill.id] = b

func _refresh() -> void:
	(%PointsLabel as Label).text = "Điểm kỹ năng: %d" % _profile.skill_points
	for skill in _skills:
		var b: Button = _slots[skill.id]
		var lv := _profile.get_skill_level(skill.id)
		var label: Label = b.get_node("LevelLabel")
		label.text = str(lv) if lv > 0 else "Chưa"
		label.add_theme_color_override("font_color", COLOR_STAT if lv > 0 else COLOR_NOT_LEARNED)
		## Khung ảnh ô skill: đang chọn = viền vàng GameUi, đã học = viền xanh lục, chưa học = viền xám.
		var selected := _selected != null and _selected.id == skill.id
		var border: Color = GameUi.BORDER_ACTIVE if selected else (GameUi.SECTION_ACCENT if lv > 0 else GameUi.BORDER)
		(b.get_node("Frame") as Panel).add_theme_stylebox_override("panel",
				GameUi.box(GameUi.BG_INNER, border, 4, 3 if selected else 2, 0))
	_refresh_wheel()

# ---------------------------------------------------------------- chi tiết (giữa)

func _select(skill: SkillDefinition) -> void:
	_selected = skill
	_refresh()
	var stat_box: VBoxContainer = %StatBox
	for c in stat_box.get_children():
		c.queue_free()
	if skill == null:
		(%SkillName as Label).text = "Chưa có kỹ năng"
		%LearnButton.visible = false
		%TestButton.visible = false
		return
	var learned := _profile.get_skill_level(skill.id)
	(%SkillName as Label).text = skill.skill_name
	(%SkillIcon as TextureRect).texture = skill.icon
	(%SkillDesc as Label).text = skill.description
	(%SkillSchool as Label).text = skill.school_text
	%StatScroll.scroll_vertical = 0

	_add_line(stat_box, "Đẳng cấp hiện thời: %d" % learned, COLOR_CURRENT_LEVEL, 16)
	if skill.req_level > 1:
		_add_line(stat_box, "Yêu cầu cấp nhân vật: %d" % skill.req_level,
				COLOR_STAT if _profile.level >= skill.req_level else COLOR_WARNING)
	## Hạn chế vũ khí / cưỡi ngựa — đúng chữ GameSetting.ini gốc.
	var weapon_text := skill.get_weapon_limit_bbcode()
	if weapon_text != "":
		var rich := RichTextLabel.new()
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.add_theme_font_size_override("normal_font_size", 15)
		rich.text = "[center]%s[/center]" % weapon_text
		stat_box.add_child(rich)
	if skill.horse_limit == 1:
		_add_line(stat_box, "Trong lúc cưỡi ngựa không thể thi triển", COLOR_WARNING)
	elif skill.horse_limit == 2:
		_add_line(stat_box, "Chỉ thi triển được khi cưỡi ngựa", COLOR_WARNING)
	var support := skill.get_support_percent_from_other_skills(_all_skills, _profile)
	if support > 0.0:
		_add_line(stat_box, "Hỗ trợ từ các kỹ năng khác: %d%%" % int(support), COLOR_STAT)
	if skill.practice_only:
		_add_line(stat_box, "Kỹ năng cao cấp: lĩnh hội khi đủ cấp, tăng cấp bằng luyện tập", COLOR_WARNING, 14)
	if skill.is_aura:
		_add_line(stat_box, "Hào quang: gắn lên thanh kỹ năng, bấm để bật/tắt (chỉ 1 hào quang cùng lúc) — %s" % (
				"ĐANG BẬT" if _profile.active_aura_id == skill.id else "đang tắt"), COLOR_GOLD, 14)
	if learned > 0:
		for line in _build_stat_lines(skill, learned):
			_add_line(stat_box, line, COLOR_STAT)
		_append_child_skills(stat_box, skill, learned, COLOR_STAT)
	if learned < skill.max_level:
		_add_line(stat_box, "Đẳng cấp kế tiếp", COLOR_NEXT, 16)
		for line in _build_stat_lines(skill, learned + 1):
			_add_line(stat_box, line, COLOR_NEXT)
		_append_child_skills(stat_box, skill, learned + 1, COLOR_NEXT)
	_update_buttons(skill, learned)

## Nút học: khoá + ghi rõ lý do khi chưa đủ cấp / hết điểm / tối đa; skill luyện chỉ lĩnh hội cấp 1.
func _update_buttons(skill: SkillDefinition, learned: int) -> void:
	var b: Button = %LearnButton
	b.visible = true
	b.disabled = true
	if learned >= skill.max_level:
		b.text = "Đã đạt cấp tối đa"
	elif skill.practice_only and learned > 0:
		b.text = "Tăng cấp bằng luyện tập"
	elif _profile.level < skill.req_level:
		b.text = "Cần đạt cấp %d" % skill.req_level
	elif skill.practice_only:
		b.text = "Lĩnh hội (cấp 1)"
		b.disabled = false
	elif _profile.skill_points <= 0:
		b.text = "Hết điểm kỹ năng"
	else:
		b.text = "Học / Nâng cấp (+1)"
		b.disabled = false
	%TestButton.visible = OS.is_debug_build() and learned < skill.max_level

func _on_learn_pressed() -> void:
	if _selected == null:
		return
	var ok := _profile.learn_practice_skill(_selected.id) if _selected.practice_only \
			else _profile.learn_skill(_selected.id)
	if ok:
		_after_skill_changed()

func _after_skill_changed() -> void:
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	_select(_selected)

func _add_line(box: VBoxContainer, text: String, color: Color, font_size: int = 15) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	box.add_child(label)

## Skill con (parent_skill_id == skill.id) nhúng ngay trong chi tiết skill cha, dạng "Tăng N: <tên>" như VLTK gốc;
## dùng cấp của skill cha.
func _append_child_skills(box: VBoxContainer, parent_skill: SkillDefinition, at_level: int, color: Color) -> void:
	var index := 2
	for candidate in _all_skills:
		if candidate.parent_skill_id != parent_skill.id:
			continue
		_add_line(box, "Tăng %d: %s" % [index, candidate.skill_name], COLOR_LINKED_SKILL)
		for line in _build_stat_lines(candidate, clampi(at_level, 1, candidate.max_level)):
			_add_line(box, line, color)
		index += 1

## Dòng số liệu tại 1 cấp: ưu tiên stat_lines (số liệu thật VLTK); skill nội tại dùng bonus bị động; thiếu dữ liệu
## thì vài dòng ước lượng để chi tiết không trống.
func _build_stat_lines(skill: SkillDefinition, at_level: int) -> Array[String]:
	var lines: Array[String] = []
	if skill.category == SkillDefinition.SkillCategory.PASSIVE and skill.stat_lines.is_empty():
		if skill.passive_attack_bonus > 0.0:
			lines.append("Công kích +%d điểm" % int(skill.passive_attack_bonus * at_level))
		if skill.passive_defense_bonus > 0.0:
			lines.append("Phòng ngự +%d điểm" % int(skill.passive_defense_bonus * at_level))
		if skill.passive_max_hp_bonus > 0.0:
			lines.append("Sinh lực +%d điểm" % int(skill.passive_max_hp_bonus * at_level))
		return lines
	if not skill.stat_lines.is_empty():
		for stat_line in skill.stat_lines:
			lines.append(stat_line.format_at_level(skill, at_level))
		return lines
	lines.append("Tiêu hao nội lực: %d" % int(skill.mana_cost))
	lines.append("Phạm vi hiệu quả: %d" % int(skill.range))
	lines.append("%s sát: %d điểm/lần" % [ElementTypes.ELEMENT_NAME.get(skill.element, "?"),
			int(skill.get_damage_at_level(at_level))])
	return lines

# ---------------------------------------------------------------- thanh kỹ năng (phải)

static func _is_tool(slot: int) -> bool:
	return slot <= TOOL_BASE and slot > TOOL_BASE - WHEEL_TOOLS.size()

func _layout_key(slot: int) -> String:
	if _is_tool(slot):
		return str(WHEEL_TOOLS[TOOL_BASE - slot][0])
	if slot == MAIN_SLOT:
		return "main"
	if slot >= LOOP_BASE:
		return "loop%d" % (slot - LOOP_BASE)
	return "s%d" % slot

func _build_wheel() -> void:
	var wheel: Control = %Wheel
	var origin := wheel.custom_minimum_size - Vector2(4, 4)  ## góc dưới-phải của vùng xếp ô
	var defs: Array = [[MAIN_SLOT, WHEEL_MAIN[0], WHEEL_MAIN[1], "Chính"]]
	for i in WHEEL_SUBS.size():
		defs.append([i, WHEEL_SUBS[i], WHEEL_SUB_SIZE, str(i + 1) if i < 4 else ""])
	for i in WHEEL_LOOPS.size():
		defs.append([LOOP_BASE + i, WHEEL_LOOPS[i], WHEEL_LOOP_SIZE, ""])
	for i in WHEEL_TOOLS.size():
		defs.append([TOOL_BASE - i, WHEEL_TOOLS[i][2], WHEEL_TOOLS[i][3], ""])
	for d in defs:
		var slot: int = d[0]
		var default_center: Vector2 = origin + (d[1] as Vector2) * WHEEL_SCALE
		_wheel_default_center[slot] = default_center
		var center := default_center + _profile.get_layout_offset(_layout_key(slot)) * WHEEL_SCALE
		var holder := _make_wheel_slot(wheel, slot, center, float(d[2]) * WHEEL_SCALE, str(d[3]))
		holder.gui_input.connect(_on_wheel_slot_input.bind(slot))
		_wheel_slots[slot] = holder
	## Đổi nhóm kỹ năng 1 <-> 2: 1 nút ⇄ sát góc dưới phải (giống thanh skill trong trận), ghi trang đang dùng.
	_wheel_swap = Button.new()
	_wheel_swap.focus_mode = Control.FOCUS_NONE
	_wheel_swap.tooltip_text = "Đổi nhóm kỹ năng 1 <-> 2"
	_wheel_swap.theme_type_variation = GameUi.BUTTON
	_wheel_swap.add_theme_font_size_override("font_size", 16)
	_wheel_swap.size = Vector2(48, 36)
	_wheel_swap.position = origin - _wheel_swap.size
	_wheel_swap.pressed.connect(func() -> void:
		_profile.hotbar_page = 1 - _profile.hotbar_page
		_save_hotbar())
	wheel.add_child(_wheel_swap)
	## Công cụ sắp xếp vị trí nút.
	_arrange_button = GameUi.button("Sắp xếp", GameUi.TAB)   ## đang bật = pressed
	_arrange_button.tooltip_text = "Sắp xếp vị trí: bật rồi KÉO các nút để đổi chỗ (cụm nút trong trận đổi theo)"
	_arrange_button.position = Vector2(2, 2)
	_arrange_button.custom_minimum_size = Vector2(92, 26)
	_arrange_button.toggled.connect(_set_arranging)
	wheel.add_child(_arrange_button)
	var reset := GameUi.button("Mặc định")
	reset.tooltip_text = "Đưa mọi nút về vị trí ban đầu"
	reset.position = Vector2(2, 32)
	reset.custom_minimum_size = Vector2(92, 26)
	reset.pressed.connect(_reset_layout)
	wheel.add_child(reset)
	## Ô đang chọn (bật "Sắp xếp" rồi bấm 1 ô): thêm / ẩn ô, chỉnh cỡ ô — hàng nút thay chỗ dòng hướng dẫn phía trên khung.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_label = GameUi.label("", GameUi.MUTED, 13)
	row.add_child(_slot_label)
	_slot_toggle = GameUi.button("Ẩn ô")
	_slot_toggle.custom_minimum_size = Vector2(76, 28)
	_slot_toggle.pressed.connect(_toggle_selected_slot)
	row.add_child(_slot_toggle)
	var minus := GameUi.button("−")
	minus.custom_minimum_size = Vector2(28, 28)
	minus.pressed.connect(_resize_selected_slot.bind(-0.1))
	row.add_child(minus)
	_slot_size_label = GameUi.label("", GameUi.TEXT, 13, HORIZONTAL_ALIGNMENT_CENTER)
	_slot_size_label.custom_minimum_size = Vector2(40, 28)
	row.add_child(_slot_size_label)
	var plus := GameUi.button("+")
	plus.custom_minimum_size = Vector2(28, 28)
	plus.pressed.connect(_resize_selected_slot.bind(0.1))
	row.add_child(plus)
	var box := wheel.get_parent()
	box.add_child(row)
	box.move_child(row, wheel.get_index())
	_slot_controls = [row]
	_refresh_slot_controls()

var _slot_controls: Array = []

func _set_arranging(on: bool) -> void:
	_arranging = on
	_selected_slot = NO_DRAG
	_refresh_slot_controls()
	for slot in _wheel_slots:
		(_wheel_slots[slot] as Control).mouse_default_cursor_shape = Control.CURSOR_MOVE if on else Control.CURSOR_ARROW
	_show_toast("Kéo để dời nút · bấm 1 nút để thêm / ẩn / đổi cỡ — tắt \"Sắp xếp\" để gắn kỹ năng" if on else "Đã lưu vị trí các nút")

func _reset_layout() -> void:
	_profile.skill_layout.clear()
	_profile.skill_slots.clear()
	for slot in _wheel_slots:
		var holder: Control = _wheel_slots[slot]
		holder.position = _wheel_default_center[slot] - holder.size * 0.5
	SaveManager.save_profile(_profile)
	_apply_slot_looks()
	_show_toast("Đã đưa các nút về vị trí mặc định")

## Kéo nút để dời chỗ (chỉ khi đang bật "Sắp xếp vị trí"): giữ trong khung %Wheel, thả ra thì lưu độ dời theo toạ độ HUD.
func _on_wheel_slot_input(event: InputEvent, slot: int) -> void:
	if not _arranging:
		return
	var holder: Control = _wheel_slots[slot]
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_arrange_drag_slot = slot
			_press_pos = holder.position
			holder.move_to_front()
		elif _arrange_drag_slot == slot:
			_arrange_drag_slot = NO_DRAG
			if holder.position.distance_to(_press_pos) < 4.0:   ## bấm không kéo = chọn ô
				_selected_slot = slot
				_refresh_slot_controls()
			else:
				var center := holder.position + holder.size * 0.5
				_profile.set_layout_offset(_layout_key(slot), (center - _wheel_default_center[slot]) / WHEEL_SCALE)
				SaveManager.save_profile(_profile)
				_update_hud_layout()
		holder.accept_event()
	elif event is InputEventMouseMotion and _arrange_drag_slot == slot:
		var wheel: Control = %Wheel
		var limit := wheel.size if wheel.size.x > 1.0 else wheel.custom_minimum_size
		holder.position = (holder.position + event.relative).clamp(Vector2.ZERO, (limit - holder.size).max(Vector2.ZERO))
		holder.accept_event()

## Chỉ số hotbar của ô đầu trang đang chọn.
func _page_start() -> int:
	return _profile.hotbar_page * PlayerProfile.HOTBAR_SLOTS_PER_PAGE

func _make_wheel_slot(parent: Control, slot: int, center: Vector2, diameter: float, key: String) -> Control:
	var holder := Panel.new()
	holder.position = center - Vector2(diameter, diameter) * 0.5
	holder.size = Vector2(diameter, diameter)
	holder.set_drag_forwarding(_get_wheel_drag_data.bind(slot), _can_drop_wheel.bind(slot), _drop_wheel.bind(slot))
	parent.add_child(holder)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.material = SkillButton.make_circle_mask_material()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(3, 3)
	icon.size = Vector2(diameter - 6, diameter - 6)
	holder.add_child(icon)
	var plus := Label.new()
	plus.name = "Plus"
	plus.text = "+"
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.size = holder.size
	plus.add_theme_font_size_override("font_size", 26 if diameter > 45.0 else 18)
	if slot >= LOOP_BASE:
		plus.text = "∞"  ## ô thi triển liên tục còn trống
	holder.add_child(plus)
	var key_label := Label.new()
	key_label.text = key
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.position = Vector2(diameter - 18, diameter - 18)
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", COLOR_GOLD)
	key_label.add_theme_color_override("font_outline_color", Color.BLACK)
	key_label.add_theme_constant_override("outline_size", 4)
	if slot == MAIN_SLOT:
		key_label.position = Vector2(diameter * 0.5 - 18, diameter - 6)
	holder.add_child(key_label)
	return holder

## Đòn chính đang gắn: main_skill_id, trống thì đánh thường hợp vũ khí đang cầm (bàn tay / phi đao).
func _main_skill() -> SkillDefinition:
	var found := _find_skill(_profile.main_skill_id)
	if found and not found.is_basic_attack:
		return found
	return SectRegistry.basic_attack_for(_profile.equipment)

func _wheel_skill(slot: int) -> SkillDefinition:
	if _is_tool(slot):
		return null
	if slot == MAIN_SLOT:
		return _main_skill()
	if slot >= LOOP_BASE:
		var loop_index := slot - LOOP_BASE
		return _find_skill(_profile.loop_skill_ids[loop_index]) if loop_index < _profile.loop_skill_ids.size() else null
	var index := _page_start() + slot
	return _find_skill(_profile.hotbar_skill_ids[index]) if index < _profile.hotbar_skill_ids.size() else null

func _refresh_wheel() -> void:
	for p in _wheel_page_buttons.size():
		_wheel_page_buttons[p].set_pressed_no_signal(p == _profile.hotbar_page)
	if _wheel_swap:
		_wheel_swap.text = "⇄ %d" % (_profile.hotbar_page + 1)
	for slot in _wheel_slots:
		var holder: Panel = _wheel_slots[slot]
		if _is_tool(slot):   ## nút tiện ích: ảnh thanh công cụ gốc, không gắn kỹ năng
			var tool: Array = WHEEL_TOOLS[TOOL_BASE - slot]
			holder.add_theme_stylebox_override("panel", SkillButton.make_round_style(holder.size.x, Color(0.08, 0.08, 0.07)))
			var frames := SideMenu._frames(str(tool[1]))
			var icon := holder.get_node("Icon") as TextureRect
			## Nút Nhảy là ô tròn cắt icon như nút skill (SkillBarUI._style_jump_button); Ngồi / Ngựa giữ ảnh tròn gốc.
			icon.material = SkillButton.make_circle_mask_material() if str(tool[0]) == "jump" else null
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if str(tool[0]) == "horse" else CanvasItem.TEXTURE_FILTER_NEAREST
			icon.texture = frames[0] if not frames.is_empty() else null
			(holder.get_node("Plus") as Label).visible = false
			holder.tooltip_text = "%s — bật \"Sắp xếp\" để dời / ẩn / đổi cỡ" % str(tool[4])
			continue
		var skill := _wheel_skill(slot)
		var bg: Color = ElementTypes.ELEMENT_COLOR.get(skill.element, Color.GRAY).darkened(0.5) if skill \
				else Color(0.12, 0.13, 0.12)
		holder.add_theme_stylebox_override("panel", SkillButton.make_round_style(holder.size.x, bg))
		(holder.get_node("Icon") as TextureRect).texture = skill.icon if skill else null
		(holder.get_node("Plus") as Label).visible = skill == null
		holder.tooltip_text = skill.skill_name if skill else \
				("Ô thi triển liên tục — kỹ năng gắn vào đây tự ra chiêu mỗi khi hồi xong" if slot >= LOOP_BASE \
				else "Ô trống — kéo kỹ năng vào đây")

## Ô tắt hiện mờ, cỡ ô theo PlayerProfile.skill_slots (scale quanh tâm).
func _apply_slot_looks() -> void:
	for slot in _wheel_slots:
		var holder: Control = _wheel_slots[slot]
		var key := _layout_key(slot)
		var k := _profile.get_skill_slot_size(key)
		holder.pivot_offset = holder.size * 0.5
		holder.scale = Vector2(k, k)
		holder.modulate.a = 1.0 if slot == MAIN_SLOT or _profile.is_skill_slot_on(key) else 0.3
		if _selected_slot == slot:
			holder.modulate = Color(1.25, 1.15, 0.7, holder.modulate.a)
		else:
			holder.modulate = Color(1, 1, 1, holder.modulate.a)

func _refresh_slot_controls() -> void:
	var on := _arranging and _selected_slot != NO_DRAG
	for c in _slot_controls:
		(c as Control).visible = _arranging
	var hint := (%Wheel as Control).get_parent().get_node_or_null("BarTitle") as Control
	if hint:
		hint.visible = not _arranging
	if _slot_label:
		_slot_label.text = ("Ô: %s" % _slot_name(_selected_slot)) if on else "Bấm 1 ô để chỉnh"
		_slot_toggle.disabled = not on or _selected_slot == MAIN_SLOT
		var key := _layout_key(_selected_slot) if on else ""
		_slot_toggle.text = "Ẩn ô" if not on or _profile.is_skill_slot_on(key) else "Thêm ô"
		_slot_size_label.text = "%d%%" % roundi(_profile.get_skill_slot_size(key) * 100.0) if on else "—"
	_apply_slot_looks()

func _slot_name(slot: int) -> String:
	if _is_tool(slot):
		return str(WHEEL_TOOLS[TOOL_BASE - slot][4])
	if slot == MAIN_SLOT:
		return "Chính"
	if slot >= LOOP_BASE:
		return "Liên tục"
	return str(slot + 1)

func _toggle_selected_slot() -> void:
	if _selected_slot == NO_DRAG or _selected_slot == MAIN_SLOT:
		return
	var key := _layout_key(_selected_slot)
	_profile.set_skill_slot_on(key, not _profile.is_skill_slot_on(key))
	SaveManager.save_profile(_profile)
	_refresh_slot_controls()
	_update_hud_layout()

func _resize_selected_slot(step: float) -> void:
	if _selected_slot == NO_DRAG:
		return
	var key := _layout_key(_selected_slot)
	_profile.set_skill_slot_size(key, _profile.get_skill_slot_size(key) + step)
	SaveManager.save_profile(_profile)
	_refresh_slot_controls()
	_update_hud_layout()

## Cụm nút skill trong trận đổi theo ngay (trận vẫn chạy khi mở bảng).
func _update_hud_layout() -> void:
	for bar in get_tree().get_nodes_in_group(SkillBarUI.GROUP):
		(bar as SkillBarUI).apply_layout()

func _find_skill(skill_id: String) -> SkillDefinition:
	if skill_id == "":
		return null
	for s in _all_skills:
		if s.id == skill_id:
			return s
	return null

func _get_grid_drag_data(_pos: Vector2, skill: SkillDefinition, source: Control) -> Variant:
	if not skill.can_assign_to_hotbar():
		_show_toast("Kỹ năng nội tại không thi triển được — không gắn vào thanh kỹ năng")
		return null
	if not SectSkillController.DEBUG_UNLOCK_ALL_SKILLS and _profile.get_skill_level(skill.id) <= 0:
		_show_toast("Chưa học kỹ năng này — học ít nhất 1 cấp để gắn")
		return null
	source.set_drag_preview(SkillBarUI.make_drag_preview(skill))
	return SkillBarUI.make_drag_data(skill.id, FROM_BOOK)

func _get_wheel_drag_data(_pos: Vector2, slot: int) -> Variant:
	if _arranging or _is_tool(slot):
		return null   ## đang sắp xếp vị trí: kéo là dời nút, không phải kéo kỹ năng
	var skill := _wheel_skill(slot)
	if skill == null or (slot == MAIN_SLOT and _profile.main_skill_id == ""):
		return null  ## đòn chính mặc định không gỡ được
	_dragged_wheel_slot = slot
	(_wheel_slots[slot] as Control).set_drag_preview(SkillBarUI.make_drag_preview(skill))
	return SkillBarUI.make_drag_data(skill.id, slot)

func _can_drop_wheel(_pos: Vector2, data: Variant, slot: int) -> bool:
	return not _arranging and not _is_tool(slot) and data is Dictionary and data.get("type") == SkillBarUI.DRAG_TYPE

## Thả lên 1 ô = gắn; kéo giữa 2 ô = đổi chỗ (như cụm nút skill trong trận).
func _drop_wheel(_pos: Vector2, data: Variant, slot: int) -> void:
	var skill_id: String = data["skill_id"]
	var from_slot: int = data["from_slot"]
	if from_slot == slot:
		return
	var previous := _wheel_skill(slot)
	_assign(slot, skill_id)
	if from_slot != FROM_BOOK and previous and previous.id != skill_id:
		_assign(from_slot, previous.id)
	_save_hotbar()

func _assign(slot: int, skill_id: String) -> void:
	if slot >= LOOP_BASE:
		_profile.set_loop_slot(slot - LOOP_BASE, skill_id)
	elif slot == MAIN_SLOT:
		_profile.set_main_skill(skill_id)
	else:
		_profile.set_hotbar_slot(_page_start() + slot, skill_id)

## Kéo ô thả ra ngoài (không trúng ô nào) = gỡ: ô phụ thành trống, ô chính về đòn chính mặc định.
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	if _dragged_wheel_slot != NO_DRAG and not get_viewport().gui_is_drag_successful():
		if _dragged_wheel_slot >= LOOP_BASE:
			_profile.set_loop_slot(_dragged_wheel_slot - LOOP_BASE, "")
		elif _dragged_wheel_slot == MAIN_SLOT:
			_profile.set_main_skill("")
		else:
			_profile.hotbar_skill_ids[_page_start() + _dragged_wheel_slot] = ""
		_save_hotbar()
	_dragged_wheel_slot = NO_DRAG

func _save_hotbar() -> void:
	SaveManager.save_profile(_profile)
	_refresh_wheel()

# ---------------------------------------------------------------- khác

func _show_toast(message: String) -> void:
	if _toast == null:
		_toast = Label.new()
		_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast.offset_top = 30
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.add_theme_font_size_override("font_size", 16)
		_toast.add_theme_color_override("font_color", GameUi.GOLD)
		## Label không nhận biến thể PanelContainer → dựng hộp báo lỗi bằng đúng màu của GameUi.BANNER_BAD.
		_toast.add_theme_stylebox_override("normal", GameUi.box(GameUi.BAD_BG, GameUi.BAD_BORDER, 8, 1, 12))
		add_child(_toast)
	_toast.text = message
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)

func _on_close_pressed() -> void:
	_on_closed.call()
	queue_free()

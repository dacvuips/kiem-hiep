extends SocialWindow
class_name SkillBookView
## Bảng "Kỹ Năng" dạng ngang 3 cột hoàn chỉnh hiển thị trong Character Hub.
## Bố cục chuẩn VLTK mobile:
##   - Cột 1 (Trái): Lưới kỹ năng môn phái (5 cột), điểm kỹ năng — KÉO THẢ ĐỂ GẮN.
##   - Cột 2 (Giữa): Chi tiết kỹ năng đang chọn, icon to có thể kéo thả, thuộc tính hiện tại & kế tiếp, nút Học / Nâng cấp.
##   - Cột 3 (Phải): Tùy chỉnh (Không mục tiêu / Đánh theo hướng trước mặt / Chạm nhả) + Bố cục phím trong trận:
##       * Cụm bánh xe Wheel mô phỏng nút chiến đấu trong trận kèm công cụ Sắp xếp dời nút.
##       * Kéo thả kỹ năng đã học trực tiếp vào các nút trên Wheel để gắn, đổi chỗ, kéo ra ngoài để gỡ.

signal skill_changed

const COLOR_GOLD := GameUi.GOLD
const COLOR_STAT := Color(0.94, 0.94, 0.9)
const COLOR_CURRENT_LEVEL := Color(0.35, 0.95, 0.4)
const COLOR_NEXT := Color(0.95, 0.25, 0.22)
const COLOR_WARNING := GameUi.LABEL_RED
const COLOR_LINKED_SKILL := Color(0.45, 0.85, 0.4)
const COLOR_NOT_LEARNED := Color(0.75, 0.75, 0.7)

const SLOT_SIZE := Vector2(52, 70)
const ICON_SIZE := 42.0

const WHEEL_SCALE := 0.52
const WHEEL_MAIN := [Vector2(-71, -146), 108.0]
const WHEEL_SUBS := [Vector2(-168, -47), Vector2(-241, -115), Vector2(-188, -199), Vector2(-126, -264),
		Vector2(-156, -342), Vector2(-41, -322), Vector2(-34, -228), Vector2(-241, -282)]
const WHEEL_SUB_SIZE := 64.0
const LOOP_BASE := SkillBarUI.LOOP_SLOT_BASE
const WHEEL_LOOPS := [Vector2(-241, -51)]
const WHEEL_LOOP_SIZE := 44.0
const TOOL_BASE := -50
const WHEEL_TOOLS := [["sit", "sit", Vector2(-383, -38), 52.0, "Ngồi"], ["jump", "jump", Vector2(-269, -209), 56.0, "Nhảy"],
		["horse", "horse", Vector2(-315, -44), 64.0, "Ngựa"]]

const MAIN_SLOT := SkillBarUI.MAIN_SLOT
const FROM_BOOK := SkillBarUI.FROM_BOOK
const NO_DRAG := -100

var _profile: PlayerProfile
var _skills: Array[SkillDefinition] = []
var _all_skills: Array[SkillDefinition] = []
var _selected: SkillDefinition

# Cột 1: Lưới kỹ năng
var _points_label: Label
var _slots: Dictionary = {}

# Cột 2: Chi tiết
var _skill_name_label: Label
var _skill_school_label: Label
var _skill_icon: TextureRect
var _skill_icon_frame: PanelContainer
var _skill_desc: Label
var _stat_scroll: ScrollContainer
var _stat_box: VBoxContainer
var _learn_button: Button
var _test_button: Button

# Cột 3: Tùy chỉnh kỹ năng & Bố cục phím trong trận
var _wheel: Control
var _wheel_swap: Button
var _wheel_slots: Dictionary = {}
var _wheel_default_center: Dictionary = {}

var _dragged_source_slot: int = NO_DRAG

# Sắp xếp nút Wheel
var _arranging := false
var _selected_slot := NO_DRAG
var _press_pos := Vector2.ZERO
var _slot_label: Label
var _slot_toggle: Button
var _slot_size_label: Label
var _arrange_button: Button
var _slot_controls: Array = []
var _arrange_drag_slot := NO_DRAG

var _toast: Label
var _toast_tween: Tween

func _init(profile: PlayerProfile, skills: Array[SkillDefinition]) -> void:
	super._init("Kỹ Năng", "", 990.0)
	set_docked(true, true)
	clip_contents = true
	_profile = profile
	if _profile == null and GameManager.local_profile != null:
		_profile = GameManager.local_profile
	_all_skills = skills
	_skills = skills.filter(func(s: SkillDefinition) -> bool: return not s.is_hidden and not s.is_basic_attack)
	# Bố cục ngang 3 cột chính trong body
	var body_row := HBoxContainer.new()
	body_row.name = "BodyRow"
	body_row.add_theme_constant_override("separation", 8)
	body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(body_row)

	_build_col_skills(body_row)
	_build_col_detail(body_row)
	_build_col_right(body_row)

	_refresh()
	if not _skills.is_empty():
		_select(_skills[0])


# ==============================================================================
# CỘT 1: LƯỚI KỸ NĂNG MÔN PHÁI (TRÁI)
# ==============================================================================
func _build_col_skills(parent: HBoxContainer) -> void:
	var col := PanelContainer.new()
	col.name = "ColSkills"
	col.custom_minimum_size = Vector2(296, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_stylebox_override("panel", WuxiaStyle.create_inner_card(6))
	parent.add_child(col)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box)

	# Header hàng trên: Tab tiêu đề + Điểm kỹ năng
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 6)
	box.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "Võ Công Môn Phái"
	title_lbl.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	title_lbl.add_theme_font_size_override("font_size", 15)
	top_bar.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_points_label = Label.new()
	_points_label.text = "Điểm kỹ năng: 0"
	_points_label.add_theme_color_override("font_color", COLOR_GOLD)
	_points_label.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(_points_label)

	# Hướng dẫn kéo thả
	var tip_lbl := Label.new()
	tip_lbl.text = "Kéo kỹ năng thả vào ô bên phải để gắn"
	tip_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.72))
	tip_lbl.add_theme_font_size_override("font_size", 12)
	box.add_child(tip_lbl)

	# Vùng cuộn lưới kỹ năng 5 cột
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.add_child(grid)

	for skill in _skills:
		var b := Button.new()
		b.custom_minimum_size = SLOT_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_select.bind(skill))
		# Cho phép kéo thả trực tiếp từ ô lưới kỹ năng
		b.set_meta("draggable", true)
		b.set_drag_forwarding(_get_grid_drag_data.bind(skill, b), Callable(), Callable())

		var frame := Panel.new()
		frame.name = "Frame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(frame)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2((SLOT_SIZE.x - ICON_SIZE) * 0.5, 3)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.texture = skill.icon
		b.add_child(icon)

		var label := Label.new()
		label.name = "LevelLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, ICON_SIZE + 4)
		label.size = Vector2(SLOT_SIZE.x, 20)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		b.add_child(label)

		b.tooltip_text = "%s (Kéo để gắn vào ô)" % skill.skill_name
		grid.add_child(b)
		_slots[skill.id] = b

# ==============================================================================
# CỘT 2: CHI TIẾT KỸ NĂNG & NÂNG CẤP (GIỮA)
# ==============================================================================
func _build_col_detail(parent: HBoxContainer) -> void:
	var col := PanelContainer.new()
	col.name = "ColDetail"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_stylebox_override("panel", WuxiaStyle.create_inner_card(8))
	parent.add_child(col)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box)

	# Thanh tiêu đề tên chiêu
	var name_bar := PanelContainer.new()
	name_bar.add_theme_stylebox_override("panel", WuxiaStyle.create_header_bar(6))
	box.add_child(name_bar)

	_skill_name_label = Label.new()
	_skill_name_label.text = "Chọn 1 kỹ năng"
	_skill_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_name_label.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	_skill_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_skill_name_label.add_theme_constant_override("outline_size", 4)
	_skill_name_label.add_theme_font_size_override("font_size", 18)
	name_bar.add_child(_skill_name_label)

	# Hàng trên: Icon to + Môn phái + Mô tả
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	box.add_child(head_row)

	_skill_icon_frame = PanelContainer.new()
	_skill_icon_frame.custom_minimum_size = Vector2(64, 64)
	_skill_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skill_icon_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skill_icon_frame.tooltip_text = "Kéo icon kỹ năng này thả vào ô để gắn"
	# Cho phép kéo trực tiếp từ khung Icon to ở Cột 2
	_skill_icon_frame.set_meta("draggable", true)
	_skill_icon_frame.set_drag_forwarding(_get_detail_drag_data.bind(_skill_icon_frame), Callable(), Callable())

	var icon_box := StyleBoxFlat.new()
	icon_box.bg_color = Color(0.06, 0.08, 0.07, 1)
	icon_box.set_border_width_all(2)
	icon_box.border_color = Color(0.3, 0.55, 0.4, 1)
	icon_box.set_corner_radius_all(8)
	_skill_icon_frame.add_theme_stylebox_override("panel", icon_box)
	head_row.add_child(_skill_icon_frame)

	_skill_icon = TextureRect.new()
	_skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skill_icon_frame.add_child(_skill_icon)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.alignment = BoxContainer.ALIGNMENT_CENTER
	info_col.add_theme_constant_override("separation", 4)
	head_row.add_child(info_col)

	_skill_school_label = Label.new()
	_skill_school_label.custom_minimum_size = Vector2(220, 0)
	_skill_school_label.add_theme_color_override("font_color", Color(0.4, 0.88, 0.45))
	_skill_school_label.add_theme_font_size_override("font_size", 14)
	_skill_school_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_skill_school_label)

	_skill_desc = Label.new()
	_skill_desc.custom_minimum_size = Vector2(220, 0)
	_skill_desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.86))
	_skill_desc.add_theme_font_size_override("font_size", 13)
	_skill_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_skill_desc)

	# Danh sách chỉ số cuộn
	_stat_scroll = ScrollContainer.new()
	_stat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_stat_scroll.custom_minimum_size = Vector2(0, 100)
	_stat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_stat_scroll)

	_stat_box = VBoxContainer.new()
	_stat_box.add_theme_constant_override("separation", 3)
	_stat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_scroll.add_child(_stat_box)

	# Hàng nút nâng cấp
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(btn_row)

	_learn_button = SocialUi.stone_button("Học / Nâng cấp (+1)")
	_learn_button.custom_minimum_size = Vector2(130, 32)
	_learn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_learn_button.pressed.connect(_on_learn_pressed)
	btn_row.add_child(_learn_button)

	if AccountApi.is_gm():
		_test_button = GameUi.button("Nâng cấp (TEST)")
		_test_button.custom_minimum_size = Vector2(100, 32)
		_test_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_test_button.pressed.connect(func() -> void:
			if _selected and _profile.debug_raise_skill(_selected.id):
				_after_skill_changed())
		btn_row.add_child(_test_button)

# ==============================================================================
# CỘT 3: TÙY CHỈNH & BỐ CỤC PHÍM TRONG TRẬN (PHẢI)
# ==============================================================================
func _build_col_right(parent: HBoxContainer) -> void:
	var col := PanelContainer.new()
	col.name = "ColRight"
	col.custom_minimum_size = Vector2(340, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_stylebox_override("panel", WuxiaStyle.create_inner_card(6))
	parent.add_child(col)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box)

	# 1. Tùy chỉnh kỹ năng
	var sec_title := Label.new()
	sec_title.text = "Tùy chỉnh kỹ năng"
	sec_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sec_title.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	sec_title.add_theme_font_size_override("font_size", 14)
	box.add_child(sec_title)

	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 2)
	box.add_child(settings_box)

	_bind_setting(settings_box, "Tự ra chiêu khi không mục tiêu", "no_target",
			"Không có quái gần vẫn ra chiêu, bắn về phía trước mặt")
	_bind_setting(settings_box, "Đánh theo hướng trước mặt", "face_direction",
			"Luôn ra chiêu theo hướng nhân vật đang quay, không tự nhắm quái gần nhất")
	_bind_setting(settings_box, "Chạm nhả chiêu thức", "tap_release",
			"Nút skill ra chiêu khi nhả tay (tắt: ra chiêu ngay lúc chạm)")

	# Phân cách nhẹ
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	box.add_child(sep)

	# 2. Cụm bánh xe kỹ năng (Wheel) mô phỏng trong trận & sắp xếp vị trí
	var wheel_title_row := HBoxContainer.new()
	wheel_title_row.add_theme_constant_override("separation", 4)
	box.add_child(wheel_title_row)

	var wheel_title := Label.new()
	wheel_title.text = "Bố cục phím trong trận (Kéo thả)"
	wheel_title.tooltip_text = "Kéo kỹ năng vào nút để gắn · Kéo ra ngoài để gỡ"
	wheel_title.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	wheel_title.add_theme_font_size_override("font_size", 13)
	wheel_title_row.add_child(wheel_title)

	var w_spacer := Control.new()
	w_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wheel_title_row.add_child(w_spacer)

	# Thanh sắp xếp ô (hiển thị khi bật sắp xếp)
	var arrange_row := HBoxContainer.new()
	arrange_row.add_theme_constant_override("separation", 3)
	arrange_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_label = GameUi.label("", GameUi.MUTED, 11)
	arrange_row.add_child(_slot_label)
	_slot_toggle = GameUi.button("Ẩn ô")
	_slot_toggle.custom_minimum_size = Vector2(58, 22)
	_slot_toggle.pressed.connect(_toggle_selected_slot)
	arrange_row.add_child(_slot_toggle)
	var minus := GameUi.button("−")
	minus.custom_minimum_size = Vector2(24, 22)
	minus.pressed.connect(_resize_selected_slot.bind(-0.1))
	arrange_row.add_child(minus)
	_slot_size_label = GameUi.label("", GameUi.TEXT, 11, HORIZONTAL_ALIGNMENT_CENTER)
	_slot_size_label.custom_minimum_size = Vector2(32, 22)
	arrange_row.add_child(_slot_size_label)
	var plus := GameUi.button("+")
	plus.custom_minimum_size = Vector2(24, 22)
	plus.pressed.connect(_resize_selected_slot.bind(0.1))
	arrange_row.add_child(plus)
	box.add_child(arrange_row)
	_slot_controls = [arrange_row]

	# Vùng Wheel xếp phím
	_wheel = Control.new()
	_wheel.name = "Wheel"
	_wheel.custom_minimum_size = Vector2(324, 270)
	_wheel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wheel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_wheel)

	_build_wheel()
	_refresh_slot_controls()

# ==============================================================================
# LOGIC BÁNH XE KỸ NĂNG (WHEEL)
# ==============================================================================
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
	var origin := _wheel.custom_minimum_size - Vector2(4, 4)
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
		var holder := _make_wheel_slot(_wheel, slot, center, float(d[2]) * WHEEL_SCALE, str(d[3]))
		holder.gui_input.connect(_on_wheel_slot_input.bind(slot))
		_wheel_slots[slot] = holder

	# Nút đổi nhóm 1 <-> 2
	_wheel_swap = Button.new()
	_wheel_swap.focus_mode = Control.FOCUS_NONE
	_wheel_swap.tooltip_text = "Đổi nhóm kỹ năng 1 <-> 2"
	_wheel_swap.theme_type_variation = GameUi.BUTTON
	_wheel_swap.add_theme_font_size_override("font_size", 12)
	_wheel_swap.size = Vector2(42, 28)
	_wheel_swap.position = origin - _wheel_swap.size
	_wheel_swap.pressed.connect(func() -> void:
		_profile.hotbar_page = 1 - _profile.hotbar_page
		_save_hotbar())
	_wheel.add_child(_wheel_swap)

	# Nút bật sắp xếp
	_arrange_button = GameUi.button("Sắp xếp", GameUi.TAB)
	_arrange_button.tooltip_text = "Sắp xếp vị trí: bật rồi KÉO các nút để đổi chỗ"
	_arrange_button.position = Vector2(2, 2)
	_arrange_button.custom_minimum_size = Vector2(74, 22)
	_arrange_button.toggled.connect(_set_arranging)
	_wheel.add_child(_arrange_button)

	var reset := GameUi.button("Mặc định")
	reset.tooltip_text = "Đưa mọi nút về vị trí ban đầu"
	reset.position = Vector2(2, 26)
	reset.custom_minimum_size = Vector2(74, 22)
	reset.pressed.connect(_reset_layout)
	_wheel.add_child(reset)

func _make_wheel_slot(parent: Control, slot: int, center: Vector2, diameter: float, key: String) -> Control:
	var holder := Panel.new()
	holder.position = center - Vector2(diameter, diameter) * 0.5
	holder.size = Vector2(diameter, diameter)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	# Cho phép kéo thả vào các ô trên Wheel
	holder.set_meta("draggable", true)
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
	plus.add_theme_font_size_override("font_size", 20 if diameter > 45.0 else 14)
	if slot >= LOOP_BASE:
		plus.text = "∞"
	holder.add_child(plus)

	var key_label := Label.new()
	key_label.text = key
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.position = Vector2(diameter - 16, diameter - 16)
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", COLOR_GOLD)
	key_label.add_theme_color_override("font_outline_color", Color.BLACK)
	key_label.add_theme_constant_override("outline_size", 3)
	if slot == MAIN_SLOT:
		key_label.position = Vector2(diameter * 0.5 - 16, diameter - 6)
	holder.add_child(key_label)
	return holder

func _set_arranging(on: bool) -> void:
	_arranging = on
	_selected_slot = NO_DRAG
	_refresh_slot_controls()
	_apply_slot_looks()
	for slot in _wheel_slots:
		(_wheel_slots[slot] as Control).mouse_default_cursor_shape = Control.CURSOR_MOVE if on else Control.CURSOR_ARROW
	_show_toast("Kéo để dời nút · bấm 1 nút để thêm / ẩn / đổi cỡ" if on else "Đã lưu vị trí các nút")

func _reset_layout() -> void:
	_profile.skill_layout.clear()
	_profile.skill_slots.clear()
	for slot in _wheel_slots:
		var holder: Control = _wheel_slots[slot]
		holder.position = _wheel_default_center[slot] - holder.size * 0.5
	SaveManager.save_profile(_profile)
	_apply_slot_looks()
	_update_hud_layout()
	_show_toast("Đã đưa các nút về vị trí mặc định")

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
			if holder.position.distance_to(_press_pos) < 4.0:
				_selected_slot = slot
				_refresh_slot_controls()
			else:
				var center := holder.position + holder.size * 0.5
				_profile.set_layout_offset(_layout_key(slot), (center - _wheel_default_center[slot]) / WHEEL_SCALE)
				SaveManager.save_profile(_profile)
				_update_hud_layout()
		holder.accept_event()
	elif event is InputEventMouseMotion and _arrange_drag_slot == slot:
		var limit := _wheel.size if _wheel.size.x > 1.0 else _wheel.custom_minimum_size
		holder.position = (holder.position + event.relative).clamp(Vector2.ZERO, (limit - holder.size).max(Vector2.ZERO))
		holder.accept_event()

func _apply_slot_looks() -> void:
	for slot in _wheel_slots:
		var holder: Control = _wheel_slots[slot]
		var key := _layout_key(slot)
		var k := _profile.get_skill_slot_size(key)
		holder.pivot_offset = holder.size * 0.5
		holder.scale = Vector2(k, k)
		var is_on: bool = (slot == MAIN_SLOT or _profile.is_skill_slot_on(key))
		holder.visible = is_on or _arranging
		holder.modulate.a = 1.0 if is_on else 0.35
		if _selected_slot == slot:
			holder.modulate = Color(1.25, 1.15, 0.7, holder.modulate.a)
		else:
			holder.modulate = Color(1, 1, 1, holder.modulate.a)

func _refresh_slot_controls() -> void:
	var on := _arranging and _selected_slot != NO_DRAG
	for c in _slot_controls:
		(c as Control).visible = _arranging
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

func _update_hud_layout() -> void:
	for bar in get_tree().get_nodes_in_group(SkillBarUI.GROUP):
		(bar as SkillBarUI).apply_layout()

func _page_start() -> int:
	return _profile.hotbar_page * 4 # 4 ô mỗi trang trên cụm Wheel

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
	if _wheel_swap:
		_wheel_swap.text = "⇄ %d" % (_profile.hotbar_page + 1)
	_apply_slot_looks()
	for slot in _wheel_slots:
		var holder: Panel = _wheel_slots[slot]
		if _is_tool(slot):
			var tool: Array = WHEEL_TOOLS[TOOL_BASE - slot]
			holder.add_theme_stylebox_override("panel", SkillButton.make_round_style(holder.size.x, Color(0.08, 0.08, 0.07)))
			var frames := SideMenu._frames(str(tool[1]))
			var icon := holder.get_node("Icon") as TextureRect
			icon.material = SkillButton.make_circle_mask_material() if str(tool[0]) == "jump" else null
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
				("Ô thi triển liên tục — tự ra chiêu khi hồi" if slot >= LOOP_BASE else "Ô trống — kéo kỹ năng vào đây")

# ==============================================================================
# HỆ THỐNG KÉO THẢ TOÀN DIỆN (DRAG & DROP)
# ==============================================================================

# 1. Kéo từ Lưới Kỹ Năng (Cột 1)
func _get_grid_drag_data(_pos: Vector2, skill: SkillDefinition, source: Control) -> Variant:
	if not skill.can_assign_to_hotbar():
		_show_toast("Kỹ năng bị động — không thể gắn vào thanh kỹ năng")
		return null
	_dragged_source_slot = FROM_BOOK
	source.set_drag_preview(SkillBarUI.make_drag_preview(skill))
	return SkillBarUI.make_drag_data(skill.id, FROM_BOOK)

# 2. Kéo từ Khung Icon To (Cột 2)
func _get_detail_drag_data(_pos: Vector2, source: Control) -> Variant:
	if _selected == null:
		return null
	if not _selected.can_assign_to_hotbar():
		_show_toast("Kỹ năng bị động — không thể gắn vào thanh kỹ năng")
		return null
	_dragged_source_slot = FROM_BOOK
	source.set_drag_preview(SkillBarUI.make_drag_preview(_selected))
	return SkillBarUI.make_drag_data(_selected.id, FROM_BOOK)

# 3. Kéo từ Ô Wheel
func _get_wheel_drag_data(_pos: Vector2, slot: int) -> Variant:
	if _arranging or _is_tool(slot):
		return null
	var skill := _wheel_skill(slot)
	if skill == null or (slot == MAIN_SLOT and _profile.main_skill_id == ""):
		return null
	_dragged_source_slot = slot
	(_wheel_slots[slot] as Control).set_drag_preview(SkillBarUI.make_drag_preview(skill))
	return SkillBarUI.make_drag_data(skill.id, slot)

# 4. Thả vào Ô Wheel
func _can_drop_wheel(_pos: Vector2, data: Variant, slot: int) -> bool:
	if _arranging or _is_tool(slot):
		return false
	if slot != MAIN_SLOT and not _profile.is_skill_slot_on(_layout_key(slot)):
		return false
	return data is Dictionary and data.get("type") == SkillBarUI.DRAG_TYPE

func _drop_wheel(_pos: Vector2, data: Variant, slot: int) -> void:
	var skill_id: String = data.get("skill_id", "")
	var from_slot: int = data.get("from_slot", FROM_BOOK)
	if skill_id == "" or from_slot == slot:
		return
	var previous := _wheel_skill(slot)
	_assign(slot, skill_id)
	if from_slot != FROM_BOOK and previous and previous.id != skill_id:
		_assign(from_slot, previous.id)
	_dragged_source_slot = NO_DRAG
	_save_hotbar()

func _assign(slot: int, skill_id: String) -> void:
	if slot >= LOOP_BASE:
		_profile.set_loop_slot(slot - LOOP_BASE, skill_id)
	elif slot == MAIN_SLOT:
		_profile.set_main_skill(skill_id)
	else:
		_profile.set_hotbar_slot(_page_start() + slot, skill_id)

# 5. Kéo ô thả ra ngoài (không trúng đích) -> Tự động gỡ kỹ năng khỏi ô
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	if _dragged_source_slot != NO_DRAG and not get_viewport().gui_is_drag_successful():
		if _dragged_source_slot == MAIN_SLOT:
			_profile.set_main_skill("")
			_show_toast("Đã gỡ đòn chính")
		elif _dragged_source_slot >= LOOP_BASE:
			_profile.set_loop_slot(_dragged_source_slot - LOOP_BASE, "")
			_show_toast("Đã gỡ ô liên tục")
		elif _dragged_source_slot >= 0:
			_assign(_dragged_source_slot, "")
			_show_toast("Đã gỡ kỹ năng khỏi ô")
		_save_hotbar()
	_dragged_source_slot = NO_DRAG

func _save_hotbar() -> void:
	SaveManager.save_profile(_profile)
	_refresh_wheel()
	skill_changed.emit()

# ==============================================================================
# TÙY CHỈNH & CHI TIẾT
# ==============================================================================
func _bind_setting(parent: VBoxContainer, label_text: String, key: String, tip: String = "") -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.tooltip_text = tip
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_icon_override("unchecked", _make_check_icon(false))
	check.add_theme_icon_override("checked", _make_check_icon(true))
	check.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	check.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.75))
	check.add_theme_font_size_override("font_size", 12)
	check.button_pressed = _profile.get_skill_setting(key) if _profile != null else false
	check.toggled.connect(func(on: bool) -> void:
		if _profile != null:
			_profile.skill_settings[key] = on
			SaveManager.save_profile(_profile)
			skill_changed.emit()
	)
	parent.add_child(check)

static func _make_check_icon(checked: bool) -> Texture2D:
	const SIZE := 18
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(GameUi.BG_INNER)
	var border := GameUi.BORDER_ACTIVE
	for i in SIZE:
		for t in 2:
			img.set_pixel(i, t, border); img.set_pixel(i, SIZE - 1 - t, border)
			img.set_pixel(t, i, border); img.set_pixel(SIZE - 1 - t, i, border)
	if checked:
		img.fill_rect(Rect2i(4, 4, SIZE - 8, SIZE - 8), GameUi.GOLD)
	return ImageTexture.create_from_image(img)

func _select(skill: SkillDefinition) -> void:
	_selected = skill
	_refresh()
	for c in _stat_box.get_children():
		c.queue_free()

	if skill == null:
		_skill_name_label.text = "Chưa có kỹ năng"
		_skill_icon.texture = null
		_skill_school_label.text = ""
		_skill_desc.text = ""
		_learn_button.visible = false
		if _test_button:
			_test_button.visible = false
		return

	if _profile == null and GameManager.local_profile != null:
		_profile = GameManager.local_profile

	var learned := _profile.get_skill_level(skill.id) if _profile != null else 0
	_skill_name_label.text = skill.skill_name
	_skill_icon.texture = skill.icon
	_skill_desc.text = skill.description
	_skill_school_label.text = skill.school_text
	_stat_scroll.scroll_vertical = 0

	_add_line(_stat_box, "Đẳng cấp hiện thời: %d/%d" % [learned, skill.max_level], COLOR_CURRENT_LEVEL, 15)
	if skill.req_level > 1:
		var has_level := _profile != null and _profile.level >= skill.req_level
		_add_line(_stat_box, "Yêu cầu cấp độ nhân vật: %d" % skill.req_level,
				COLOR_STAT if has_level else COLOR_WARNING, 13)

	var weapon_text := skill.get_weapon_limit_bbcode()
	if weapon_text != "":
		var rich := RichTextLabel.new()
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.add_theme_font_size_override("normal_font_size", 13)
		rich.text = "[center]%s[/center]" % weapon_text
		_stat_box.add_child(rich)

	if skill.horse_limit == 1:
		_add_line(_stat_box, "Trong lúc cưỡi ngựa không thể thi triển", COLOR_WARNING, 13)
	elif skill.horse_limit == 2:
		_add_line(_stat_box, "Chỉ thi triển được khi cưỡi ngựa", COLOR_WARNING, 13)

	var support := skill.get_support_percent_from_other_skills(_all_skills, _profile)
	if support > 0.0:
		_add_line(_stat_box, "Hỗ trợ từ các kỹ năng khác: %d%%" % int(support), COLOR_STAT, 13)

	if skill.practice_only:
		_add_line(_stat_box, "Kỹ năng cao cấp: tăng cấp bằng luyện tập", COLOR_WARNING, 13)

	if skill.is_aura:
		_add_line(_stat_box, "Hào quang: %s" % ("Đang bật" if _profile.active_aura_id == skill.id else "Đang tắt"), COLOR_GOLD, 13)

	if learned > 0:
		for line in _build_stat_lines(skill, learned):
			_add_line(_stat_box, line, COLOR_STAT, 13)
		_append_child_skills(_stat_box, skill, learned, COLOR_STAT)

	if learned < skill.max_level:
		_add_line(_stat_box, "--- Đẳng cấp kế tiếp ---", COLOR_NEXT, 14)
		for line in _build_stat_lines(skill, learned + 1):
			_add_line(_stat_box, line, COLOR_NEXT, 13)
		_append_child_skills(_stat_box, skill, learned + 1, COLOR_NEXT)

	_update_buttons(skill, learned)

func _update_buttons(skill: SkillDefinition, learned: int) -> void:
	_learn_button.visible = true
	_learn_button.disabled = true
	if learned >= skill.max_level:
		_learn_button.text = "Đã đạt cấp tối đa"
	elif skill.practice_only and learned > 0:
		_learn_button.text = "Tăng cấp bằng luyện tập"
	elif _profile.level < skill.req_level:
		_learn_button.text = "Cần đạt cấp %d" % skill.req_level
	elif skill.practice_only:
		_learn_button.text = "Lĩnh hội (cấp 1)"
		_learn_button.disabled = false
	elif _profile.skill_points <= 0:
		_learn_button.text = "Hết điểm kỹ năng"
	else:
		_learn_button.text = "Học / Nâng cấp (+1)"
		_learn_button.disabled = false

	if _test_button:
		_test_button.visible = AccountApi.is_gm() and learned < skill.max_level

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
	_refresh()
	_select(_selected)
	skill_changed.emit()

func _refresh() -> void:
	if _profile == null and GameManager.local_profile != null:
		_profile = GameManager.local_profile

	if _points_label:
		_points_label.text = "Điểm kỹ năng: %d" % (_profile.skill_points if _profile != null else 0)

	for skill in _skills:
		if not _slots.has(skill.id):
			continue
		var b: Button = _slots[skill.id]
		var lv := _profile.get_skill_level(skill.id) if _profile != null else 0
		var label: Label = b.get_node_or_null("LevelLabel")
		if label:
			label.text = str(lv) if lv > 0 else "Chưa"
			label.add_theme_color_override("font_color", COLOR_STAT if lv > 0 else COLOR_NOT_LEARNED)

		var selected := _selected != null and _selected.id == skill.id
		var border: Color = GameUi.BORDER_ACTIVE if selected else (GameUi.SECTION_ACCENT if lv > 0 else GameUi.BORDER)
		var frame: Panel = b.get_node_or_null("Frame")
		if frame:
			frame.add_theme_stylebox_override("panel", GameUi.box(GameUi.BG_INNER, border, 4, 3 if selected else 2, 0))

	_refresh_wheel()

func _add_line(box: VBoxContainer, text: String, color: Color, font_size: int = 13) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	box.add_child(label)

func _append_child_skills(box: VBoxContainer, parent_skill: SkillDefinition, at_level: int, color: Color) -> void:
	var index := 2
	for candidate in _all_skills:
		if candidate.parent_skill_id != parent_skill.id:
			continue
		_add_line(box, "Tăng %d: %s" % [index, candidate.skill_name], COLOR_LINKED_SKILL, 13)
		for line in _build_stat_lines(candidate, clampi(at_level, 1, candidate.max_level)):
			_add_line(box, line, color, 12)
		index += 1

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

func _find_skill(skill_id: String) -> SkillDefinition:
	if skill_id == "":
		return null
	for s in _all_skills:
		if s.id == skill_id:
			return s
	return null

func _show_toast(message: String) -> void:
	if _toast == null:
		_toast = Label.new()
		_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast.offset_top = 20
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.add_theme_font_size_override("font_size", 14)
		_toast.add_theme_color_override("font_color", GameUi.GOLD)
		_toast.add_theme_stylebox_override("normal", GameUi.box(GameUi.BAD_BG, GameUi.BAD_BORDER, 6, 1, 10))
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
	

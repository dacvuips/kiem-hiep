class_name SelectedSkillsWindow
extends CanvasLayer
## CỬA SỔ HIỂN THỊ CÁC KỸ NĂNG & BÍ KÍP ĐÃ CHỌN
##
## Thiết kế theo đúng đặc tả:
## - Hàng 1: Kỹ năng đánh đã được chọn, hiển thị tầng (sao: 1-5) và cấp độ của skill.
## - Hàng 2: Kỹ năng bổ trợ (perks / hỗ trợ) đã được chọn, hiển thị tầng (1-5) và cấp độ / hiệu ứng.
## - Hỗ trợ phím tắt V hoặc nút bấm trên HUD để bật/tắt (toggle).

static var instance: CanvasLayer = null

const WINDOW_WIDTH := 820.0
const WINDOW_HEIGHT := 520.0
const CARD_WIDTH := 142.0
const CARD_HEIGHT := 160.0

var _was_paused: bool = false
var _attack_container: HBoxContainer
var _support_container: HBoxContainer
var _attack_count_lbl: Label
var _support_count_lbl: Label

static func open_window(parent: Node = null) -> CanvasLayer:
	if instance != null and is_instance_valid(instance):
		if instance.has_method("_refresh_display"):
			instance._refresh_display()
		return instance

	var p := parent
	if p == null:
		var tree := Engine.get_main_loop() as SceneTree
		p = tree.current_scene if tree else null

	if p == null:
		return null

	var script_res: GDScript = load("res://ui/hud/selected_skills_window.gd")
	var win: CanvasLayer = script_res.new()
	p.add_child(win)
	return win

static func close_window() -> void:
	if instance != null and is_instance_valid(instance):
		instance.close()

static func toggle_window(parent: Node = null) -> void:
	if instance != null and is_instance_valid(instance):
		close_window()
	else:
		open_window(parent)

func _init() -> void:
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self

func _ready() -> void:
	if GameModeManager.is_offline():
		_was_paused = get_tree().paused
		get_tree().paused = true

	_build_ui()
	_refresh_display()

	if PlayerStats != null and PlayerStats.has_signal("survivor_skills_changed"):
		PlayerStats.survivor_skills_changed.connect(_on_skills_changed)

func _exit_tree() -> void:
	if instance == self:
		instance = null
	if GameModeManager.is_offline() and not _was_paused:
		get_tree().paused = false

func close() -> void:
	if GameModeManager.is_offline() and not _was_paused:
		get_tree().paused = false
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V or event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func _on_skills_changed(_skills: Dictionary) -> void:
	_refresh_display()

func _build_ui() -> void:
	# 1. Dim background
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close()
	)
	add_child(dim)

	# 2. Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# 3. Main Window Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(WINDOW_WIDTH, WINDOW_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var p_st := StyleBoxFlat.new()
	p_st.bg_color = Color(0.06, 0.08, 0.10, 0.96)
	p_st.border_color = Color(0.90, 0.75, 0.28)
	p_st.set_border_width_all(2)
	p_st.set_corner_radius_all(12)
	p_st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", p_st)
	center.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# 4. Header (Title + Subtitle + Close Button)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	main_vbox.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	var title_lbl := Label.new()
	title_lbl.text = "⚔️ VÕ CÔNG & BÍ KÍP ĐÃ CHỌN"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_box.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Tổng hợp danh sách các chiêu thức tấn công và kỹ năng bổ trợ đã kích hoạt trong trận"
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.80))
	title_box.add_child(sub_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(34, 34)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cb_st := StyleBoxFlat.new()
	cb_st.bg_color = Color(0.18, 0.20, 0.22, 0.85)
	cb_st.border_color = Color(0.6, 0.6, 0.6)
	cb_st.set_border_width_all(1)
	cb_st.set_corner_radius_all(17)
	close_btn.add_theme_stylebox_override("normal", cb_st)
	var cb_hov := cb_st.duplicate() as StyleBoxFlat
	cb_hov.bg_color = Color(0.85, 0.25, 0.25, 0.95)
	cb_hov.border_color = Color(1.0, 0.5, 0.5)
	close_btn.add_theme_stylebox_override("hover", cb_hov)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95))
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var sep1 := HSeparator.new()
	sep1.modulate = Color(0.9, 0.75, 0.28, 0.5)
	main_vbox.add_child(sep1)

	# -------------------------------------------------------------
	# 5. HÀNG 1: CHIÊU THỨC TẤN CÔNG (SKILL ĐÁNH)
	# -------------------------------------------------------------
	var row1_header := HBoxContainer.new()
	row1_header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(row1_header)

	var r1_title := Label.new()
	r1_title.text = "⚔️ CHIÊU THỨC TẤN CÔNG ĐÃ CHỌN"
	r1_title.add_theme_font_size_override("font_size", 14)
	r1_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	r1_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	r1_title.add_theme_constant_override("outline_size", 2)
	row1_header.add_child(r1_title)

	_attack_count_lbl = Label.new()
	_attack_count_lbl.text = "(0 kỹ năng)"
	_attack_count_lbl.add_theme_font_size_override("font_size", 12)
	_attack_count_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	row1_header.add_child(_attack_count_lbl)

	var r1_note := Label.new()
	r1_note.text = "— Chiêu thức môn phái chủ động xuất chiêu gây sát thương"
	r1_note.add_theme_font_size_override("font_size", 11)
	r1_note.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	row1_header.add_child(r1_note)

	var row1_scroll := ScrollContainer.new()
	row1_scroll.custom_minimum_size = Vector2(WINDOW_WIDTH - 32, 168)
	row1_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	row1_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(row1_scroll)

	_attack_container = HBoxContainer.new()
	_attack_container.add_theme_constant_override("separation", 10)
	_attack_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row1_scroll.add_child(_attack_container)

	var sep2 := HSeparator.new()
	sep2.modulate = Color(0.4, 0.6, 0.8, 0.4)
	main_vbox.add_child(sep2)

	# -------------------------------------------------------------
	# 6. HÀNG 2: KỸ NĂNG BỔ TRỢ (PERKS / HỖ TRỢ / BÍ KÍP)
	# -------------------------------------------------------------
	var row2_header := HBoxContainer.new()
	row2_header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(row2_header)

	var r2_title := Label.new()
	r2_title.text = "🛡️ KỸ NĂNG BỔ TRỢ ĐÃ CHỌN"
	r2_title.add_theme_font_size_override("font_size", 14)
	r2_title.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	r2_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	r2_title.add_theme_constant_override("outline_size", 2)
	row2_header.add_child(r2_title)

	_support_count_lbl = Label.new()
	_support_count_lbl.text = "(0 kỹ năng)"
	_support_count_lbl.add_theme_font_size_override("font_size", 12)
	_support_count_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	row2_header.add_child(_support_count_lbl)

	var r2_note := Label.new()
	r2_note.text = "— Bí kíp nội công, hiệu ứng tăng đạn, xuyên giáp, hộ thân"
	r2_note.add_theme_font_size_override("font_size", 11)
	r2_note.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	row2_header.add_child(r2_note)

	var row2_scroll := ScrollContainer.new()
	row2_scroll.custom_minimum_size = Vector2(WINDOW_WIDTH - 32, 168)
	row2_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	row2_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(row2_scroll)

	_support_container = HBoxContainer.new()
	_support_container.add_theme_constant_override("separation", 10)
	_support_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row2_scroll.add_child(_support_container)

	# 7. Footer
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(footer)

	var foot_lbl := Label.new()
	foot_lbl.text = "[ Nhấn phím V hoặc ESC để đóng bảng võ công ]"
	foot_lbl.add_theme_font_size_override("font_size", 11)
	foot_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.70))
	footer.add_child(foot_lbl)

func _refresh_display() -> void:
	if _attack_container == null or _support_container == null:
		return

	# Xóa nội dung cũ
	for child in _attack_container.get_children():
		_attack_container.remove_child(child)
		child.queue_free()
	for child in _support_container.get_children():
		_support_container.remove_child(child)
		child.queue_free()

	var attack_skills := get_selected_attack_skills()
	var support_skills := get_selected_support_skills()

	_attack_count_lbl.text = "(%d kỹ năng)" % attack_skills.size()
	_support_count_lbl.text = "(%d kỹ năng)" % support_skills.size()

	# 1. Điền hàng 1: Chiêu thức tấn công
	if attack_skills.is_empty():
		_attack_container.add_child(_create_empty_placeholder("⚔️ Chưa có chiêu thức tấn công nào được chọn.\n(Khi lên cấp hoặc mở đầu trận, hãy chọn các chiêu thức võ công môn phái)"))
	else:
		for item in attack_skills:
			_attack_container.add_child(_create_attack_skill_card(item))

	# 2. Điền hàng 2: Kỹ năng bổ trợ
	if support_skills.is_empty():
		_support_container.add_child(_create_empty_placeholder("🛡️ Chưa có kỹ năng bổ trợ nào được chọn.\n(Khi lên cấp hoặc vượt ải, hãy chọn các bí kíp bổ trợ đạn, hộ thể hoặc tăng sát thương)"))
	else:
		for item in support_skills:
			_support_container.add_child(_create_support_skill_card(item))

func _create_empty_placeholder(text: String) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(WINDOW_WIDTH - 64, 150)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65))
	box.add_child(lbl)
	return box

# -----------------------------------------------------------------
# THẺ KỸ NĂNG TẤN CÔNG (HÀNG 1)
# -----------------------------------------------------------------
func _create_attack_skill_card(data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var star: int = int(data.get("star", 1))
	var level: int = int(data.get("level", 1))
	var border_col: Color = _get_tier_color(star)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.10, 0.12, 0.95)
	st.border_color = border_col
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Icon Box
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(48, 48)
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ib_st := StyleBoxFlat.new()
	ib_st.bg_color = Color(0.04, 0.05, 0.06, 0.9)
	ib_st.border_color = border_col.darkened(0.2)
	ib_st.set_border_width_all(1)
	ib_st.set_corner_radius_all(6)
	icon_box.add_theme_stylebox_override("panel", ib_st)
	vbox.add_child(icon_box)

	var tex: Texture2D = data.get("icon", null)
	if tex != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = tex
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_box.add_child(icon_rect)
	else:
		var glyph := Label.new()
		glyph.text = "⚔"
		glyph.add_theme_font_size_override("font_size", 22)
		glyph.add_theme_color_override("font_color", border_col)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_box.add_child(glyph)

	# Tên Skill
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "Chiêu Thức"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.custom_minimum_size = Vector2(CARD_WIDTH - 16, 32)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(name_lbl)

	# Huy hiệu Tầng & Cấp
	var badge_box := HBoxContainer.new()
	badge_box.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_box.add_theme_constant_override("separation", 6)
	vbox.add_child(badge_box)

	var star_lbl := Label.new()
	star_lbl.text = "⭐ Tầng %d/5" % star
	star_lbl.add_theme_font_size_override("font_size", 11)
	star_lbl.add_theme_color_override("font_color", border_col)
	star_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	star_lbl.add_theme_constant_override("outline_size", 2)
	badge_box.add_child(star_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "Cấp %d" % level
	lvl_lbl.add_theme_font_size_override("font_size", 11)
	lvl_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.60))
	lvl_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lvl_lbl.add_theme_constant_override("outline_size", 2)
	badge_box.add_child(lvl_lbl)

	# Subtitle / Ghi chú số tia phóng ra theo sao
	var sub_lbl := Label.new()
	sub_lbl.text = "Phóng %d đợt chiêu" % star
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.80))
	vbox.add_child(sub_lbl)

	# Tooltip chi tiết
	var tooltip_lines: Array[String] = [
		"【%s】" % data.get("name", ""),
		"• Phân loại: Chiêu thức tấn công môn phái",
		"• Tầng võ học: %d / 5 sao (Số lượng chiêu x%d)" % [star, star],
		"• Cấp độ uy lực: Cấp %d" % level
	]
	var desc: String = str(data.get("description", "")).strip_edges()
	if desc != "":
		tooltip_lines.append("• Mô tả: %s" % desc)
	card.tooltip_text = "\n".join(tooltip_lines)

	return card

# -----------------------------------------------------------------
# THẺ KỸ NĂNG BỔ TRỢ (HÀNG 2)
# -----------------------------------------------------------------
func _create_support_skill_card(data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var star: int = int(data.get("star", 1))
	var level: int = int(data.get("level", 1))
	var border_col: Color = _get_tier_color(star)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.10, 0.12, 0.95)
	st.border_color = border_col
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Icon Box
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(48, 48)
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ib_st := StyleBoxFlat.new()
	ib_st.bg_color = Color(0.04, 0.05, 0.06, 0.9)
	ib_st.border_color = border_col.darkened(0.2)
	ib_st.set_border_width_all(1)
	ib_st.set_corner_radius_all(6)
	icon_box.add_theme_stylebox_override("panel", ib_st)
	vbox.add_child(icon_box)

	var tex: Texture2D = data.get("icon", null)
	if tex != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = tex
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_box.add_child(icon_rect)
	else:
		var glyph := Label.new()
		glyph.text = "🛡"
		glyph.add_theme_font_size_override("font_size", 22)
		glyph.add_theme_color_override("font_color", border_col)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_box.add_child(glyph)

	# Tên Bổ Trợ
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", "Bổ Trợ"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.custom_minimum_size = Vector2(CARD_WIDTH - 16, 32)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(name_lbl)

	# Huy hiệu Tầng & Cấp
	var badge_box := HBoxContainer.new()
	badge_box.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_box.add_theme_constant_override("separation", 6)
	vbox.add_child(badge_box)

	var star_lbl := Label.new()
	star_lbl.text = "Tầng %d/5" % star
	star_lbl.add_theme_font_size_override("font_size", 11)
	star_lbl.add_theme_color_override("font_color", border_col)
	star_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	star_lbl.add_theme_constant_override("outline_size", 2)
	badge_box.add_child(star_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "Cấp %d" % level
	lvl_lbl.add_theme_font_size_override("font_size", 11)
	lvl_lbl.add_theme_color_override("font_color", Color(0.40, 0.88, 1.0))
	lvl_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lvl_lbl.add_theme_constant_override("outline_size", 2)
	badge_box.add_child(lvl_lbl)

	# Subtitle / Hiệu ứng tóm tắt
	var sub_lbl := Label.new()
	var sub_txt: String = str(data.get("subtitle", ""))
	if sub_txt == "":
		sub_txt = str(data.get("description", ""))
	sub_lbl.text = sub_txt
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub_lbl.custom_minimum_size = Vector2(CARD_WIDTH - 16, 16)
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.80))
	vbox.add_child(sub_lbl)

	# Tooltip chi tiết
	var tooltip_lines: Array[String] = [
		"【%s】" % data.get("name", ""),
		"• Phân loại: Kỹ năng Bổ trợ & Nội công",
		"• Tầng hiệu lực: Tầng %d / 5" % star,
		"• Cấp độ: Cấp %d" % level
	]
	var desc: String = str(data.get("description", "")).strip_edges()
	if desc != "":
		tooltip_lines.append("• Hiệu quả: %s" % desc)
	card.tooltip_text = "\n".join(tooltip_lines)

	return card

func _get_tier_color(star: int) -> Color:
	if star >= 5:
		return Color(1.0, 0.85, 0.25) # Hoàng Kim
	elif star >= 3:
		return Color(0.85, 0.45, 1.0) # Huyền Thoại Tím
	else:
		return Color(0.35, 0.75, 1.0) # Tinh Anh Lam

# -----------------------------------------------------------------
# DATA RESOLUTION (TRUY XUẤT DỮ LIỆU SKILL & PERKS)
# -----------------------------------------------------------------
static func get_selected_attack_skills() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# 1. Chế độ Survivor (Ưu tiên SurvivorManager hoặc PlayerStats)
	var is_survivor: bool = false
	if GameModeManager != null and GameModeManager.is_offline():
		if GameManager != null and (GameManager.game_mode == GameManager.GameMode.STAGE or (GameManager.field_map != null and bool(GameManager.field_map.get("survivor_mode", false)))):
			is_survivor = true
	var s_dict: Dictionary = {}
	if is_survivor:
		if SurvivorManager != null and not SurvivorManager.active_skills.is_empty():
			s_dict = SurvivorManager.active_skills
		elif PlayerStats != null and not PlayerStats.survivor_skills.is_empty():
			s_dict = PlayerStats.survivor_skills

	if not s_dict.is_empty():
		for skill_id in s_dict.keys():
			var star: int = int(s_dict[skill_id])
			if star <= 0:
				continue
			var sk := _find_skill(str(skill_id))
			var sk_name: String = sk.skill_name if sk else str(skill_id)
			var sk_icon: Texture2D = sk.icon if sk else null
			var sk_desc: String = sk.description if sk else ""
			var sk_elem: int = int(sk.element) if sk and "element" in sk else 0

			# Công thức tính cấp chiến đấu trong Survivor
			var combat_lvl := star * 4
			if PlayerStats != null and PlayerStats.level > 1:
				combat_lvl += int((PlayerStats.level - 1) / 2)

			results.append({
				"id": str(skill_id),
				"name": sk_name,
				"icon": sk_icon,
				"star": star,
				"level": combat_lvl,
				"element": sk_elem,
				"description": sk_desc
			})
		return results

	# 2. Fallback cho chế độ thường / MMORPG
	var prof := GameManager.local_profile
	if prof != null:
		var ids_to_check: Array[String] = []
		if prof.main_skill_id != "" and not ids_to_check.has(prof.main_skill_id):
			ids_to_check.append(prof.main_skill_id)
		for hid in prof.hotbar_skill_ids:
			if hid != "" and not ids_to_check.has(hid):
				ids_to_check.append(hid)

		for sid in ids_to_check:
			var sk := _find_skill(sid)
			if sk == null or sk.is_aura or sk.is_passive:
				continue
			var lvl: int = prof.get_skill_level(sid)
			if lvl <= 0 and not sk.is_basic_attack and not sk.is_main_attack:
				continue
			var effective_lvl: int = maxi(1, lvl)
			var calc_star: int = mini(5, int((effective_lvl - 1) / 4) + 1)
			results.append({
				"id": sid,
				"name": sk.skill_name,
				"icon": sk.icon,
				"star": calc_star,
				"level": effective_lvl,
				"element": int(sk.element) if "element" in sk else 0,
				"description": sk.description
			})

	return results

static func get_selected_support_skills() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# 1. Chế độ Survivor: Lấy từ SurvivorPerks.active_perks
	if SurvivorPerks != null and not SurvivorPerks.active_perks.is_empty():
		for perk_id in SurvivorPerks.active_perks.keys():
			var lvl: int = int(SurvivorPerks.active_perks[perk_id])
			if lvl <= 0:
				continue
			var def: Dictionary = SurvivorPerks.PERK_DEFINITIONS.get(str(perk_id), {})
			var p_name: String = str(def.get("name", perk_id))
			var p_sub: String = str(def.get("subtitle", ""))
			var p_icon: Texture2D = SurvivorPerks.get_perk_icon(str(perk_id))
			var desc_levels: Array = def.get("desc_levels", [])
			var p_desc: String = desc_levels[lvl - 1] if (lvl - 1 >= 0 and lvl - 1 < desc_levels.size()) else ""

			results.append({
				"id": str(perk_id),
				"name": p_name,
				"subtitle": p_sub,
				"icon": p_icon,
				"star": lvl,
				"level": lvl,
				"description": p_desc
			})

	if not results.is_empty():
		return results

	# 2. Fallback cho chế độ thường / MMORPG: Lấy các skill bị động/tâm pháp/hào quang đã học
	var prof := GameManager.local_profile
	if prof != null:
		var sect := SectRegistry.get_by_id(prof.sect_id)
		if sect != null:
			for sk in sect.skills:
				if sk == null:
					continue
				var lvl: int = prof.get_skill_level(sk.id)
				if lvl > 0 and (sk.is_aura or sk.is_passive or SectSkillController.is_self_buff(sk)):
					var calc_star: int = mini(5, int((lvl - 1) / 4) + 1)
					results.append({
						"id": sk.id,
						"name": sk.skill_name,
						"subtitle": "Bí kíp môn phái",
						"icon": sk.icon,
						"star": calc_star,
						"level": lvl,
						"description": sk.description
					})

	return results

static func _find_skill(skill_id: String) -> SkillDefinition:
	if SurvivorManager != null and not SurvivorManager.pool_skills.is_empty():
		for s in SurvivorManager.pool_skills:
			if s != null and s.id == skill_id:
				return s

	for sect in SectRegistry.load_all():
		for s in sect.skills:
			if s != null and s.id == skill_id:
				return s

	return null

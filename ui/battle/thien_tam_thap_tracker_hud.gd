extends CanvasLayer
class_name ThienTamThapTrackerHud

## THANH TIẾN TRÌNH & HUD "HIỆP PHONG LUẬN KIẾM"
## Timeline dọc bên trái (nền trong suốt) tương tự Bảo Vệ Trụ Danh Dự,
## kèm thanh trạng thái trên đỉnh hiển thị thông tin ải hiện tại, số ải đã vượt, đồng hồ và nút tăng tốc.

signal speed_changed(multiplier: float)
signal leaderboard_requested
signal exit_requested

var current_wave: int = 1
var total_waves: int = 744
var stages_cleared: int = 0
var best_stage_record: int = 0
var next_wave_timer: float = 45.0
var alive_monsters_count: int = 0
var all_waves_data: Array = []

var current_speed_idx: int = 0
const SPEED_STEPS := [1.0, 1.5, 2.0, 3.0]
const SPEED_LABELS := ["⏩ 1x", "⏩ 1.5x", "⏩ 2x", "⏩ 3x"]
const SPEED_COLORS := [
	Color(0.85, 0.85, 0.9),
	Color(0.3, 0.9, 1.0),
	Color(1.0, 0.85, 0.25),
	Color(1.0, 0.35, 0.25)
]

const SERIES_NAMES := ["Kim", "Mộc", "Thủy", "Hỏa", "Thổ"]
const SERIES_COLORS := [
	Color(1.0, 0.85, 0.3),
	Color(0.3, 0.9, 0.3),
	Color(0.3, 0.7, 1.0),
	Color(1.0, 0.35, 0.25),
	Color(0.85, 0.65, 0.4)
]

var _wave_label: Label = null
var _cleared_label: Label = null
var _timer_label: Label = null
var _monsters_count_label: Label = null
var _speed_btn: Button = null
var _exit_btn: Button = null
var _current_info_label: Label = null
var _tracker_container: VBoxContainer = null
var _best_record_label: Label = null

static func _bold_font() -> Font:
	return GameUi.game_font_bold()

func _ready() -> void:
	layer = 10
	_build_hud()

func setup(p_waves_data: Array, p_best_record: int) -> void:
	all_waves_data = p_waves_data
	total_waves = all_waves_data.size() if not all_waves_data.is_empty() else 744
	best_stage_record = p_best_record
	_update_tracker()
	_refresh_display()

func update_status(p_wave: int, p_cleared: int, p_timer: float, p_alive_count: int) -> void:
	current_wave = p_wave
	stages_cleared = p_cleared
	next_wave_timer = p_timer
	alive_monsters_count = p_alive_count
	if stages_cleared > best_stage_record:
		best_stage_record = stages_cleared
	_refresh_display()

func refresh_tracker() -> void:
	_update_tracker()

func _toggle_speed() -> void:
	current_speed_idx = (current_speed_idx + 1) % SPEED_STEPS.size()
	_update_speed_button()
	speed_changed.emit(SPEED_STEPS[current_speed_idx])

func _update_speed_button() -> void:
	if _speed_btn != null:
		_speed_btn.text = SPEED_LABELS[current_speed_idx]
		_speed_btn.add_theme_color_override("font_color", SPEED_COLORS[current_speed_idx])
		_speed_btn.tooltip_text = "Tốc độ trận đấu: %s (Bấm để tăng tốc 1x -> 1.5x -> 2x -> 3x)" % SPEED_LABELS[current_speed_idx]

func _refresh_display() -> void:
	if _wave_label != null:
		_wave_label.text = "ẢI: %d/%d" % [current_wave, total_waves]
	if _cleared_label != null:
		_cleared_label.text = "🏆 Vượt: %d ải" % stages_cleared
	if _timer_label != null:
		_timer_label.text = "⏱ %.1fs" % maxf(0.0, next_wave_timer)
	if _monsters_count_label != null:
		_monsters_count_label.text = "👾 Còn: %d" % alive_monsters_count

	if _best_record_label != null:
		_best_record_label.text = "Kỷ lục đã vượt: %d ải" % best_stage_record

	if _current_info_label != null and current_wave - 1 < all_waves_data.size():
		var curr_info: Dictionary = all_waves_data[current_wave - 1]
		var is_boss: bool = curr_info.get("is_boss_wave", false)
		var s_idx: int = int(curr_info.get("series", 0)) % 5
		var s_name: String = SERIES_NAMES[s_idx]
		if is_boss:
			var b_data: Dictionary = curr_info.get("boss", {})
			_current_info_label.text = "👑 ĐẠI BOSS: %s (Lv %d · Hệ %s) — Máu x10 · Đồ rớt x5" % [
				str(b_data.get("name", "Đại Boss")),
				int(curr_info.get("level", 1)),
				s_name
			]
			_current_info_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			_current_info_label.text = "⚔️ Đợt Quái: %s (Lv %d · Hệ %s) — Máu x2 · Rớt x3 · EXP x2" % [
				str(curr_info.get("monster_name", "Quái")),
				int(curr_info.get("level", 1)),
				s_name
			]
			_current_info_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# -------------------------------------------------------------------------
	# 1. BẢNG THÔNG TIN ẢI HIỆN TẠI (TRÊN CÙNG GIỮA MÀN HÌNH)
	# -------------------------------------------------------------------------
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.custom_minimum_size = Vector2(520, 0)
	top_panel.offset_left = -260.0
	top_panel.offset_right = 260.0
	top_panel.offset_top = 48.0
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.04, 0.06, 0.1, 0.65)
	top_style.border_color = Color(0.85, 0.7, 0.25, 0.7)
	top_style.border_width_left = 1
	top_style.border_width_right = 1
	top_style.border_width_top = 1
	top_style.border_width_bottom = 1
	top_style.set_corner_radius_all(6)
	top_style.content_margin_left = 12
	top_style.content_margin_right = 12
	top_style.content_margin_top = 6
	top_style.content_margin_bottom = 6
	top_panel.add_theme_stylebox_override("panel", top_style)
	root.add_child(top_panel)

	var top_v := VBoxContainer.new()
	top_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_v.add_theme_constant_override("separation", 4)
	top_panel.add_child(top_v)

	# Hàng 1: ẢI + ĐÃ VƯỢT + ĐỒNG HỒ + QUÁI CÒN + NÚT TĂNG TỐC + RỜI ẢI
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	top_v.add_child(row1)

	_wave_label = Label.new()
	_wave_label.text = "ẢI: 1/744"
	_wave_label.add_theme_font_override("font", _bold_font())
	_wave_label.add_theme_font_size_override("font_size", 14)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_wave_label.add_theme_constant_override("outline_size", 3)
	row1.add_child(_wave_label)

	_cleared_label = Label.new()
	_cleared_label.text = "🏆 Vượt: 0 ải"
	_cleared_label.add_theme_font_override("font", _bold_font())
	_cleared_label.add_theme_font_size_override("font_size", 13)
	_cleared_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	_cleared_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_cleared_label.add_theme_constant_override("outline_size", 3)
	row1.add_child(_cleared_label)

	_timer_label = Label.new()
	_timer_label.text = "⏱ 45.0s"
	_timer_label.add_theme_font_override("font", _bold_font())
	_timer_label.add_theme_font_size_override("font_size", 13)
	_timer_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer_label.add_theme_constant_override("outline_size", 3)
	row1.add_child(_timer_label)

	_monsters_count_label = Label.new()
	_monsters_count_label.text = "👾 Còn: 0"
	_monsters_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_monsters_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_monsters_count_label.add_theme_font_override("font", _bold_font())
	_monsters_count_label.add_theme_font_size_override("font_size", 13)
	_monsters_count_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	_monsters_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_monsters_count_label.add_theme_constant_override("outline_size", 3)
	row1.add_child(_monsters_count_label)

	_speed_btn = Button.new()
	_speed_btn.text = "⏩ 1x"
	_speed_btn.custom_minimum_size = Vector2(58, 26)
	_speed_btn.add_theme_font_override("font", _bold_font())
	_speed_btn.add_theme_font_size_override("font_size", 12)
	_speed_btn.focus_mode = Control.FOCUS_NONE
	_speed_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_speed_btn.tooltip_text = "Tốc độ trận đấu: ⏩ 1x (Bấm để tăng tốc 1x -> 1.5x -> 2x -> 3x)"

	var s_style := StyleBoxFlat.new()
	s_style.bg_color = Color(0.12, 0.15, 0.2, 0.9)
	s_style.border_color = Color(0.35, 0.75, 0.95, 0.8)
	s_style.border_width_left = 1
	s_style.border_width_right = 1
	s_style.border_width_top = 1
	s_style.border_width_bottom = 1
	s_style.set_corner_radius_all(4)
	s_style.content_margin_left = 4
	s_style.content_margin_right = 4
	s_style.content_margin_top = 2
	s_style.content_margin_bottom = 2
	_speed_btn.add_theme_stylebox_override("normal", s_style)

	var s_hover := s_style.duplicate() as StyleBoxFlat
	s_hover.bg_color = Color(0.18, 0.24, 0.32, 0.95)
	s_hover.border_color = Color(0.5, 0.9, 1.0, 1.0)
	_speed_btn.add_theme_stylebox_override("hover", s_hover)

	var s_press := s_style.duplicate() as StyleBoxFlat
	s_press.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	_speed_btn.add_theme_stylebox_override("pressed", s_press)

	_speed_btn.add_theme_color_override("font_color", SPEED_COLORS[0])
	_speed_btn.pressed.connect(_toggle_speed)
	row1.add_child(_speed_btn)

	var lb_btn := Button.new()
	lb_btn.text = "🏆 BXH"
	lb_btn.custom_minimum_size = Vector2(62, 26)
	lb_btn.add_theme_font_override("font", _bold_font())
	lb_btn.add_theme_font_size_override("font_size", 12)
	lb_btn.focus_mode = Control.FOCUS_NONE
	lb_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lb_btn.tooltip_text = "Xem Bảng Xếp Hạng Hiệp Phong Luận Kiếm"
	var lb_style := StyleBoxFlat.new()
	lb_style.bg_color = Color(0.18, 0.15, 0.08, 0.9)
	lb_style.border_color = Color(0.9, 0.75, 0.3, 0.9)
	lb_style.border_width_left = 1
	lb_style.border_width_right = 1
	lb_style.border_width_top = 1
	lb_style.border_width_bottom = 1
	lb_style.set_corner_radius_all(4)
	lb_style.content_margin_left = 4
	lb_style.content_margin_right = 4
	lb_style.content_margin_top = 2
	lb_style.content_margin_bottom = 2
	lb_btn.add_theme_stylebox_override("normal", lb_style)
	lb_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	lb_btn.pressed.connect(func() -> void: leaderboard_requested.emit())
	row1.add_child(lb_btn)

	_exit_btn = Button.new()
	_exit_btn.text = "🚪 Rời Ải"
	_exit_btn.custom_minimum_size = Vector2(75, 26)
	_exit_btn.add_theme_font_override("font", _bold_font())
	_exit_btn.add_theme_font_size_override("font_size", 12)
	_exit_btn.focus_mode = Control.FOCUS_NONE
	_exit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var exit_style := StyleBoxFlat.new()
	exit_style.bg_color = Color(0.2, 0.1, 0.1, 0.9)
	exit_style.border_color = Color(0.9, 0.35, 0.35, 0.9)
	exit_style.border_width_left = 1
	exit_style.border_width_right = 1
	exit_style.border_width_top = 1
	exit_style.border_width_bottom = 1
	exit_style.set_corner_radius_all(4)
	exit_style.content_margin_left = 6
	exit_style.content_margin_right = 6
	exit_style.content_margin_top = 2
	exit_style.content_margin_bottom = 2
	_exit_btn.add_theme_stylebox_override("normal", exit_style)
	_exit_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	_exit_btn.pressed.connect(func() -> void: exit_requested.emit())
	row1.add_child(_exit_btn)

	# Hàng 2: CHI TIẾT ĐỢT QUÁI / BOSS HIỆN TẠI
	_current_info_label = Label.new()
	_current_info_label.text = "⚔️ Đang khởi động ải khiêu chiến..."
	_current_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_info_label.add_theme_font_override("font", _bold_font())
	_current_info_label.add_theme_font_size_override("font_size", 12)
	_current_info_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_current_info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_current_info_label.add_theme_constant_override("outline_size", 3)
	top_v.add_child(_current_info_label)

	# -------------------------------------------------------------------------
	# 2. KHUNG TIMELINE DỌC BÊN TRÁI (NỀN TRONG SUỐT)
	# -------------------------------------------------------------------------
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(290, 0)
	left_panel.position = Vector2(16, 138)
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.04, 0.06, 0.1, 0.45)
	left_style.border_color = Color(0.85, 0.7, 0.25, 0.5)
	left_style.border_width_left = 1
	left_style.border_width_right = 1
	left_style.border_width_top = 1
	left_style.border_width_bottom = 1
	left_style.corner_radius_top_left = 6
	left_style.corner_radius_top_right = 6
	left_style.corner_radius_bottom_left = 6
	left_style.corner_radius_bottom_right = 6
	left_style.content_margin_left = 10
	left_style.content_margin_right = 10
	left_style.content_margin_top = 8
	left_style.content_margin_bottom = 8
	left_panel.add_theme_stylebox_override("panel", left_style)
	root.add_child(left_panel)

	var left_v := VBoxContainer.new()
	left_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_v.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_v)

	var title_lbl := Label.new()
	title_lbl.text = "⚔️ HIỆP PHONG LUẬN KIẾM"
	title_lbl.add_theme_font_override("font", _bold_font())
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 3)
	left_v.add_child(title_lbl)

	_best_record_label = Label.new()
	_best_record_label.text = "Kỷ lục đã vượt: 0 ải"
	_best_record_label.add_theme_font_override("font", _bold_font())
	_best_record_label.add_theme_font_size_override("font_size", 11)
	_best_record_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.6))
	_best_record_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_best_record_label.add_theme_constant_override("outline_size", 3)
	left_v.add_child(_best_record_label)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.25)
	left_v.add_child(sep)

	var timeline_title := Label.new()
	timeline_title.text = "TIẾN TRÌNH 5 ẢI KẾ TIẾP:"
	timeline_title.add_theme_font_override("font", _bold_font())
	timeline_title.add_theme_font_size_override("font_size", 11)
	timeline_title.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	timeline_title.add_theme_color_override("font_outline_color", Color.BLACK)
	timeline_title.add_theme_constant_override("outline_size", 3)
	left_v.add_child(timeline_title)

	_tracker_container = VBoxContainer.new()
	_tracker_container.add_theme_constant_override("separation", 4)
	left_v.add_child(_tracker_container)

	var sep2 := HSeparator.new()
	sep2.modulate = Color(1, 1, 1, 0.25)
	left_v.add_child(sep2)

	var rule_note := Label.new()
	rule_note.text = "• Quái thường: Máu x2 · Rớt x3 · EXP x2\n• Mỗi 10 ải có 1 Boss: Máu x10 · Rớt x5"
	rule_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_note.add_theme_font_override("font", _bold_font())
	rule_note.add_theme_font_size_override("font_size", 10)
	rule_note.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.85))
	rule_note.add_theme_color_override("font_outline_color", Color.BLACK)
	rule_note.add_theme_constant_override("outline_size", 2)
	left_v.add_child(rule_note)

	_update_tracker()

func _update_tracker() -> void:
	if _tracker_container == null or all_waves_data.is_empty():
		return

	for c in _tracker_container.get_children():
		c.queue_free()

	# Xếp DỌC 5 tiến trình: current_wave -> current_wave + 4
	for i in range(5):
		var target_wave_num := current_wave + i
		if target_wave_num > total_waves:
			break

		var w_idx := target_wave_num - 1
		if w_idx >= all_waves_data.size():
			break

		var w_info: Dictionary = all_waves_data[w_idx]
		var is_boss: bool = w_info.get("is_boss_wave", false)
		var s_idx: int = int(w_info.get("series", 0)) % 5
		var s_name: String = SERIES_NAMES[s_idx]

		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()

		if i == 0:
			# Ải hiện tại: viền vàng rực, nền xanh mờ nhẹ
			card_style.bg_color = Color(0.15, 0.2, 0.3, 0.45)
			card_style.border_color = Color(1.0, 0.85, 0.25, 0.85)
			card_style.border_width_left = 2
			card_style.border_width_right = 1
			card_style.border_width_top = 1
			card_style.border_width_bottom = 1
		else:
			# Các ải sau: nền bán trong suốt
			card_style.bg_color = Color(0.05, 0.08, 0.12, 0.25)
			card_style.border_color = Color(0.3, 0.4, 0.5, 0.3)
			card_style.border_width_left = 1
			card_style.border_width_right = 1
			card_style.border_width_top = 1
			card_style.border_width_bottom = 1

		card_style.corner_radius_top_left = 4
		card_style.corner_radius_top_right = 4
		card_style.corner_radius_bottom_left = 4
		card_style.corner_radius_bottom_right = 4
		card_style.content_margin_left = 8
		card_style.content_margin_right = 8
		card_style.content_margin_top = 3
		card_style.content_margin_bottom = 3
		card.add_theme_stylebox_override("panel", card_style)
		_tracker_container.add_child(card)

		var card_h := HBoxContainer.new()
		card_h.add_theme_constant_override("separation", 6)
		card.add_child(card_h)

		# Chấm trạng thái: Boss = ĐỎ RỰC 🔴 👑, Hiện tại = VÀNG 🟡 ⚔, Kế tiếp = TRẮNG ⚪
		var dot_label := Label.new()
		if is_boss:
			dot_label.text = "🔴 👑"
		elif i == 0:
			dot_label.text = "🟡 ⚔"
		else:
			dot_label.text = "⚪"
		dot_label.add_theme_font_override("font", _bold_font())
		dot_label.add_theme_font_size_override("font_size", 12)
		card_h.add_child(dot_label)

		var wave_title := Label.new()
		wave_title.text = "Ải %d [%s]" % [target_wave_num, s_name]
		wave_title.add_theme_font_override("font", _bold_font())
		wave_title.add_theme_font_size_override("font_size", 12)
		wave_title.add_theme_color_override("font_outline_color", Color.BLACK)
		wave_title.add_theme_constant_override("outline_size", 3)
		if is_boss:
			wave_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		elif i == 0:
			wave_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			wave_title.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		card_h.add_child(wave_title)

		var foe_label := Label.new()
		foe_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		foe_label.add_theme_font_override("font", _bold_font())
		foe_label.add_theme_font_size_override("font_size", 12)
		foe_label.add_theme_color_override("font_outline_color", Color.BLACK)
		foe_label.add_theme_constant_override("outline_size", 3)

		if is_boss:
			var b_data: Dictionary = w_info.get("boss", {})
			foe_label.text = "👑 " + str(b_data.get("name", "Đại Boss"))
			foe_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			foe_label.text = "%s (Lv %d)" % [str(w_info.get("monster_name", "Quái")), int(w_info.get("level", 1))]
			foe_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.65))
		card_h.add_child(foe_label)

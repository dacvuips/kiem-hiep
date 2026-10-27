extends CanvasLayer
class_name HonorDefenseTrackerHud

## THANH TIẾN TRÌNH & HUD "BẢO VỆ TRỤ DANH DỰ" (TIMELINE DỌC BÊN TRÁI — NỀN TRONG SUỐT)
## Bố trí dọc theo mép trái màn hình, nền trong suốt không che thanh máu nhân vật hay các nút thao tác.
## Hiển thị 5 tiến trình (5 đợt) tiếp theo kèm chấm trạng thái, tên quái, tên boss (màu đỏ + icon).

signal open_shop_requested
signal speed_changed(multiplier: float)

var current_wave: int = 1
var total_waves: int = 200
var next_wave_timer: float = 20.0
var pillar_current_hp: float = 2000000.0
var pillar_max_hp: float = 2000000.0
var defense_points: int = 0
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

var _wave_label: Label = null
var _timer_label: Label = null
var _pillar_hp_bar: ProgressBar = null
var _pillar_hp_label: Label = null
var _points_label: Label = null
var _speed_btn: Button = null
var _tracker_container: VBoxContainer = null
var _buff_label: Label = null

static func _bold_font() -> Font:
	return GameUi.game_font_bold()

func _ready() -> void:
	layer = 10 # Nằm ở lớp HUD (dưới các modal / cửa sổ popup như Auto, Túi đồ, Kỹ năng có layer 50+)
	_build_hud()

func setup(p_waves_data: Array) -> void:
	all_waves_data = p_waves_data
	total_waves = all_waves_data.size() if not all_waves_data.is_empty() else 200
	_update_tracker()

func update_status(p_wave: int, p_timer: float, p_pillar_hp: float, p_pillar_max: float, p_points: int) -> void:
	current_wave = p_wave
	next_wave_timer = p_timer
	pillar_current_hp = p_pillar_hp
	pillar_max_hp = p_pillar_max
	defense_points = p_points
	_refresh_display()

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
	if _timer_label != null:
		_timer_label.text = "⏱ %.1fs" % maxf(0.0, next_wave_timer)
	if _points_label != null:
		_points_label.text = "🪙 %d" % defense_points

	if _pillar_hp_bar != null:
		_pillar_hp_bar.max_value = pillar_max_hp
		_pillar_hp_bar.value = pillar_current_hp
		var ratio := pillar_current_hp / maxf(1.0, pillar_max_hp)
		if _pillar_hp_label != null:
			_pillar_hp_label.text = "Máu Trụ: %d%% (%s)" % [int(ratio * 100.0), _format_hp(pillar_current_hp)]
		
		var fill_style: StyleBoxFlat = _pillar_hp_bar.get_theme_stylebox("fill")
		if fill_style:
			if ratio > 0.5:
				fill_style.bg_color = Color(0.2, 0.85, 0.3, 0.9)
			elif ratio > 0.25:
				fill_style.bg_color = Color(0.95, 0.75, 0.1, 0.9)
			else:
				fill_style.bg_color = Color(0.95, 0.2, 0.2, 0.9)

func _format_hp(val: float) -> String:
	if val >= 1000000.0:
		return "%.1fM" % (val / 1000000.0)
	elif val >= 1000.0:
		return "%.0fk" % (val / 1000.0)
	return str(int(val))

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# -------------------------------------------------------------------------
	# 1. CỤM THỦ TRỤ: TÁCH RIÊNG ĐẶT DƯỚI THANH MÁU & MANA CỦA PLAYER (GIỮA MÀN HÌNH)
	# -------------------------------------------------------------------------
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.custom_minimum_size = Vector2(460, 0)
	top_panel.offset_left = -230.0
	top_panel.offset_right = 230.0
	top_panel.offset_top = 48.0 # Ngay bên dưới TopStatusBar (thanh máu/mana người chơi kết thúc ở y~45)
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.04, 0.06, 0.1, 0.55)
	top_style.border_color = Color(0.85, 0.7, 0.25, 0.6)
	top_style.border_width_left = 1
	top_style.border_width_right = 1
	top_style.border_width_top = 1
	top_style.border_width_bottom = 1
	top_style.set_corner_radius_all(6)
	top_style.content_margin_left = 10
	top_style.content_margin_right = 10
	top_style.content_margin_top = 5
	top_style.content_margin_bottom = 5
	top_panel.add_theme_stylebox_override("panel", top_style)
	root.add_child(top_panel)

	var top_v := VBoxContainer.new()
	top_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_v.add_theme_constant_override("separation", 4)
	top_panel.add_child(top_v)

	# Hàng 1: ẢI + ĐỒNG HỒ + ĐIỂM + NÚT TĂNG TỐC + NÚT MUA BOSS
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	top_v.add_child(row1)

	_wave_label = Label.new()
	_wave_label.text = "ẢI: 1/200"
	_wave_label.add_theme_font_override("font", _bold_font())
	_wave_label.add_theme_font_size_override("font_size", 14)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_wave_label.add_theme_constant_override("outline_size", 3)
	row1.add_child(_wave_label)

	_timer_label = Label.new()
	_timer_label.text = "⏱ 20.0s"
	_timer_label.add_theme_font_override("font", _bold_font())
	_timer_label.add_theme_font_size_override("font_size", 13)
	_timer_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer_label.add_theme_constant_override("outline_size", 3)
	row1.add_child(_timer_label)

	_points_label = Label.new()
	_points_label.text = "🪙 200"
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_points_label.add_theme_font_override("font", _bold_font())
	_points_label.add_theme_font_size_override("font_size", 13)
	_points_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_points_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_points_label.add_theme_constant_override("outline_size", 3)
	row1.add_child(_points_label)

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

	var buy_btn := Button.new()
	buy_btn.text = "🛡️ Mua Boss"
	buy_btn.custom_minimum_size = Vector2(95, 26)
	buy_btn.add_theme_font_override("font", _bold_font())
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.14, 0.08, 0.9)
	btn_style.border_color = Color(0.9, 0.75, 0.3, 0.9)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.set_corner_radius_all(4)
	btn_style.content_margin_left = 6
	btn_style.content_margin_right = 6
	btn_style.content_margin_top = 2
	btn_style.content_margin_bottom = 2
	buy_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.28, 0.22, 0.12, 0.95)
	btn_hover.border_color = Color(1.0, 0.88, 0.45, 1.0)
	buy_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_press := btn_style.duplicate() as StyleBoxFlat
	btn_press.bg_color = Color(0.12, 0.09, 0.05, 0.95)
	buy_btn.add_theme_stylebox_override("pressed", btn_press)
	buy_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	buy_btn.pressed.connect(func() -> void: open_shop_requested.emit())
	row1.add_child(buy_btn)

	# Hàng 2: THANH MÁU LONG TRỤ
	var hp_v := VBoxContainer.new()
	hp_v.add_theme_constant_override("separation", 0)
	top_v.add_child(hp_v)

	_pillar_hp_bar = ProgressBar.new()
	_pillar_hp_bar.min_value = 0.0
	_pillar_hp_bar.max_value = pillar_max_hp
	_pillar_hp_bar.value = pillar_current_hp
	_pillar_hp_bar.show_percentage = false
	_pillar_hp_bar.custom_minimum_size = Vector2(0, 16)

	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	style_bg.border_color = Color(0.85, 0.7, 0.25, 0.5)
	style_bg.border_width_left = 1
	style_bg.border_width_right = 1
	style_bg.border_width_top = 1
	style_bg.border_width_bottom = 1
	style_bg.set_corner_radius_all(4)
	_pillar_hp_bar.add_theme_stylebox_override("background", style_bg)

	var style_fill := StyleBoxFlat.new()
	style_fill.bg_color = Color(0.2, 0.85, 0.3, 0.95)
	style_fill.set_corner_radius_all(3)
	_pillar_hp_bar.add_theme_stylebox_override("fill", style_fill)
	hp_v.add_child(_pillar_hp_bar)

	_pillar_hp_label = Label.new()
	_pillar_hp_label.text = "Máu Trụ: 100% (2.0M)"
	_pillar_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pillar_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pillar_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pillar_hp_label.add_theme_font_override("font", _bold_font())
	_pillar_hp_label.add_theme_font_size_override("font_size", 11)
	_pillar_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_pillar_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_pillar_hp_label.add_theme_constant_override("outline_size", 3)
	_pillar_hp_bar.add_child(_pillar_hp_label)

	# -------------------------------------------------------------------------
	# 2. KHUNG TIẾN TRÌNH & BUFF (DỌC BÊN TRÁI MÀN HÌNH)
	# -------------------------------------------------------------------------
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
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

	_buff_label = Label.new()
	_buff_label.text = "✨ Đang tải hiệu ứng buff..."
	_buff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buff_label.add_theme_font_override("font", _bold_font())
	_buff_label.add_theme_font_size_override("font_size", 11)
	_buff_label.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0))
	_buff_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_buff_label.add_theme_constant_override("outline_size", 3)
	left_v.add_child(_buff_label)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.25)
	left_v.add_child(sep)

	var timeline_title := Label.new()
	timeline_title.text = "TIẾN TRÌNH 5 ĐỢT KẾ TIẾP:"
	timeline_title.add_theme_font_override("font", _bold_font())
	timeline_title.add_theme_font_size_override("font_size", 11)
	timeline_title.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	timeline_title.add_theme_color_override("font_outline_color", Color.BLACK)
	timeline_title.add_theme_constant_override("outline_size", 3)
	left_v.add_child(timeline_title)

	_tracker_container = VBoxContainer.new()
	_tracker_container.add_theme_constant_override("separation", 4)
	left_v.add_child(_tracker_container)

	_update_tracker()

func _update_tracker() -> void:
	if _tracker_container == null or all_waves_data.is_empty():
		return

	for c in _tracker_container.get_children():
		c.queue_free()

	# Xếp DỌC 5 tiến trình tiếp theo: current_wave -> current_wave + 4
	for i in range(5):
		var target_wave_num := current_wave + i
		if target_wave_num > total_waves:
			break

		var w_idx := target_wave_num - 1
		if w_idx >= all_waves_data.size():
			break

		var w_info: Dictionary = all_waves_data[w_idx]
		var is_boss: bool = w_info.get("is_boss_wave", false)

		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		
		if i == 0:
			# Đợt hiện tại: nền xanh mờ nhẹ, viền vàng
			card_style.bg_color = Color(0.15, 0.2, 0.3, 0.45)
			card_style.border_color = Color(1.0, 0.85, 0.25, 0.85)
			card_style.border_width_left = 2
			card_style.border_width_right = 1
			card_style.border_width_top = 1
			card_style.border_width_bottom = 1
		else:
			# Đợt sau: hoàn toàn trong suốt hoặc mờ 20%
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

		# Chấm trạng thái: Boss = ĐỎ RỰC, Hiện tại = VÀNG, Sau = TRẮNG
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
		wave_title.text = "Đợt %d [%s]" % [target_wave_num, str(w_info.get("element_name", ""))]
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

		# Tên quái / Tên Boss: Boss màu ĐỎ RỰC + Icon
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

	# Cập nhật thông tin buff hiện tại
	if current_wave - 1 < all_waves_data.size():
		var curr_info: Dictionary = all_waves_data[current_wave - 1]
		var b_info: Dictionary = curr_info.get("buff", {})
		if _buff_label != null:
			_buff_label.text = "✨ Buff [%s - %s]: %s" % [
				str(b_info.get("sect", "")),
				str(b_info.get("name", "")),
				str(b_info.get("desc", ""))
			]

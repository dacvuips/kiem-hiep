class_name VirtualKeyboardBar
extends CanvasLayer
## Thanh hiển thị giá trị đang nhập trên bàn phím điện thoại di động (Android / iOS).
##
## Chỉ hiển thị khi bàn phím ảo của điện thoại thực sự mở lên (virtual_keyboard_get_height > 0).
## Tự động bám sát ngay trên đỉnh bàn phím, giúp người chơi thấy rõ mình đang gõ gì
## khi bàn phím che 1/2 màn hình bên dưới. Khi bàn phím đóng, thanh tự động ẩn.

const BAR_HEIGHT := 42.0

var _target_input: Control = null
var _debug_simulated_kb_height: float = 0.0

# UI Controls
var _root_container: Control
var _panel: PanelContainer
var _preview_label: Label
var _btn_clear: Button
var _btn_done: Button

func _init() -> void:
	layer = 125
	name = "VirtualKeyboardBar"
	_build_ui()
	_set_bar_visible(false)

func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_viewport_focus_changed)

func _process(_delta: float) -> void:
	# Kiểm tra chiều cao bàn phím ảo
	var kb_h_px := 0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		kb_h_px = DisplayServer.virtual_keyboard_get_height()
	if _debug_simulated_kb_height > 0.0:
		kb_h_px = int(_debug_simulated_kb_height)

	# CHỈ hiển thị khi có ô nhập VÀ bàn phím điện thoại đang mở (kb_h_px > 0)
	var has_valid_input := (_target_input != null and is_instance_valid(_target_input))
	if not has_valid_input or kb_h_px <= 0:
		if _panel.visible:
			_set_bar_visible(false)
		return

	# Hiển thị và cập nhật vị trí bám đỉnh bàn phím
	if not _panel.visible:
		_set_bar_visible(true)

	_update_position(kb_h_px)
	_sync_text_from_target()

func _build_ui() -> void:
	_root_container = Control.new()
	_root_container.name = "RootContainer"
	_root_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_container)

	_panel = PanelContainer.new()
	_panel.name = "BarPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(0, BAR_HEIGHT)

	# Style thanh bar đơn giản, rõ nét
	var style_panel := StyleBoxFlat.new()
	style_panel.bg_color = Color(0.08, 0.09, 0.10, 0.95)
	style_panel.border_color = Color(0.96, 0.78, 0.25, 0.90) # Viền vàng kim
	style_panel.border_width_top = 2
	style_panel.border_width_bottom = 0
	style_panel.border_width_left = 0
	style_panel.border_width_right = 0
	style_panel.corner_radius_top_left = 6
	style_panel.corner_radius_top_right = 6
	_panel.add_theme_stylebox_override("panel", style_panel)
	_root_container.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	# Label icon
	var icon_label := Label.new()
	icon_label.text = "⌨"
	icon_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.25))
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)

	# Khung hiển thị text đang gõ
	var text_box := PanelContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_FILL
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.03, 0.04, 0.04, 0.9)
	style_box.border_color = Color(0.3, 0.3, 0.28, 0.8)
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	style_box.content_margin_left = 8
	style_box.content_margin_right = 8
	text_box.add_theme_stylebox_override("panel", style_box)
	hbox.add_child(text_box)

	_preview_label = Label.new()
	_preview_label.name = "PreviewLabel"
	_preview_label.clip_text = true
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.95))
	_preview_label.add_theme_font_size_override("font_size", 15)
	text_box.add_child(_preview_label)

	# Nút Xoá nhanh [ ✕ ]
	_btn_clear = Button.new()
	_btn_clear.name = "ClearButton"
	_btn_clear.text = "✕"
	_btn_clear.tooltip_text = "Xoá"
	_btn_clear.focus_mode = Control.FOCUS_NONE
	_btn_clear.custom_minimum_size = Vector2(32, 28)
	_apply_button_style(_btn_clear, Color(0.20, 0.08, 0.08), Color(0.55, 0.25, 0.25), Color(0.95, 0.6, 0.6))
	_btn_clear.pressed.connect(_on_clear_pressed)
	hbox.add_child(_btn_clear)

	# Nút Hoàn tất [ ✓ Xong ]
	_btn_done = Button.new()
	_btn_done.name = "DoneButton"
	_btn_done.text = "✓ Xong"
	_btn_done.focus_mode = Control.FOCUS_NONE
	_btn_done.custom_minimum_size = Vector2(60, 28)
	_apply_done_style(_btn_done)
	_btn_done.pressed.connect(_on_done_pressed)
	hbox.add_child(_btn_done)

func _apply_button_style(btn: Button, bg: Color, border: Color, font_color: Color) -> void:
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_font_size_override("font_size", 13)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

func _apply_done_style(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color(0.18, 0.14, 0.07))
	btn.add_theme_font_size_override("font_size", 13)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.82, 0.38) # Nền vàng
	style.border_color = Color(1.0, 0.92, 0.6)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

func _on_viewport_focus_changed(control: Control) -> void:
	if control is LineEdit or control is TextEdit:
		_target_input = control
	else:
		if not _is_child_of_bar(control):
			_target_input = null
			_set_bar_visible(false)

func _is_child_of_bar(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	var cur: Node = control
	while cur != null:
		if cur == self or cur == _panel:
			return true
		cur = cur.get_parent()
	return false

func _sync_text_from_target() -> void:
	if _target_input == null or not is_instance_valid(_target_input):
		return

	var text_val := ""
	var is_secret := false
	var placeholder := ""

	if _target_input is LineEdit:
		var le: LineEdit = _target_input
		text_val = le.text
		is_secret = le.secret
		placeholder = le.placeholder_text
	elif _target_input is TextEdit:
		var te: TextEdit = _target_input
		text_val = te.text
		placeholder = te.placeholder_text

	_btn_clear.visible = (text_val.length() > 0)

	if text_val.is_empty():
		_preview_label.text = placeholder if placeholder != "" else "Đang nhập..."
		_preview_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	else:
		_preview_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.95))
		if is_secret:
			_preview_label.text = "●".repeat(text_val.length())
		else:
			_preview_label.text = text_val

func _update_position(kb_h_px: int) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size := vp.get_visible_rect().size
	var win_size := DisplayServer.window_get_size()
	if vp_size.x <= 0 or vp_size.y <= 0 or win_size.y <= 0:
		return

	var ratio := float(kb_h_px) / float(win_size.y)
	var canvas_kb_h := ratio * vp_size.y
	var target_y := vp_size.y - canvas_kb_h - BAR_HEIGHT

	_panel.size = Vector2(vp_size.x, BAR_HEIGHT)
	_panel.position = Vector2(0, target_y)

func _set_bar_visible(is_vis: bool) -> void:
	if _panel != null:
		_panel.visible = is_vis

func _on_clear_pressed() -> void:
	if _target_input == null or not is_instance_valid(_target_input):
		return
	if _target_input is LineEdit:
		var le: LineEdit = _target_input
		le.text = ""
		le.caret_column = 0
		le.text_changed.emit("")
	elif _target_input is TextEdit:
		var te: TextEdit = _target_input
		te.text = ""
		te.text_changed.emit()
	_sync_text_from_target()

func _on_done_pressed() -> void:
	if _target_input != null and is_instance_valid(_target_input):
		var current_input: Control = _target_input
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
		if current_input.is_inside_tree() and current_input.has_focus():
			current_input.release_focus()
		if current_input is LineEdit:
			var le: LineEdit = current_input
			le.text_submitted.emit(le.text)
	_target_input = null
	_set_bar_visible(false)

func set_simulated_keyboard_height(h: float) -> void:
	_debug_simulated_kb_height = h

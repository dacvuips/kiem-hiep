extends CanvasLayer
class_name PkModeMenu

## MENU LỰA CHỌN CHẾ ĐỘ PK (Võ Lâm Truyền Kỳ)
## Hiển thị danh sách các chế độ PK để người chơi lựa chọn trực tiếp:
## 0: Luyện Công (Hòa bình)
## 1: Chiến Đấu (Phe: Chính / Tà / Trung Lập)
## 2: Đồ Sát (Tên đỏ, PK tự do)
## 3: Bang Chiến (Chiến đấu Bang hội)

const LAYER := 58
const WIDTH := 310.0

static var current: PkModeMenu = null

var _panel: PanelContainer
var _current_mode: int = 0
var _on_select_cb: Callable
var _get_cooldown_cb: Callable
var _peace_desc_lbl: Label = null
var _peace_btn: Button = null

static func is_open() -> bool:
	return current != null and is_instance_valid(current) and not current.is_queued_for_deletion()

static func close() -> void:
	if is_open():
		current.queue_free()
	current = null

static func open(parent: Node, current_mode: int, on_select: Callable, origin: Control = null, get_cooldown: Callable = Callable()) -> PkModeMenu:
	close()
	var m := PkModeMenu.new()
	m._current_mode = current_mode
	m._on_select_cb = on_select
	m._get_cooldown_cb = get_cooldown
	parent.add_child(m)
	m._build(origin)
	current = m
	return m

func _process(_delta: float) -> void:
	_update_peace_cooldown_ui()

func _update_peace_cooldown_ui() -> void:
	if _peace_desc_lbl == null or not is_instance_valid(_peace_desc_lbl):
		return
	if _current_mode == 0:
		return
	var cd: float = 0.0
	if _get_cooldown_cb != null and not _get_cooldown_cb.is_null():
		cd = float(_get_cooldown_cb.call())
	if cd > 0.0:
		_peace_desc_lbl.text = "⏳ Thời gian chờ chuyển về Bình thường: %d giây..." % ceili(cd)
		_peace_desc_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
	else:
		_peace_desc_lbl.text = "Không tấn công người khác, chỉ tự vệ."
		_peace_desc_lbl.add_theme_color_override("font_color", GameUi.TEXT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_F9:
			close()
			if is_inside_tree() and get_viewport():
				get_viewport().set_input_as_handled()

func _build(origin: Control) -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Lớp nền trong suốt bắt click ra ngoài để đóng menu
	var back := Control.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close()
	)
	add_child(back)

	_panel = PanelContainer.new()
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.05, 0.04, 0.96)
	panel_sb.border_color = Color(0.83, 0.68, 0.21, 1.0)
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(8)
	panel_sb.shadow_color = Color(0, 0, 0, 0.6)
	panel_sb.shadow_size = 8
	panel_sb.content_margin_left = 12
	panel_sb.content_margin_top = 10
	panel_sb.content_margin_right = 12
	panel_sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", panel_sb)
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(root_vbox)

	# Header: Tiêu đề + Nút đóng ✕
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 1)
	header.add_child(title_vbox)

	var title_lbl := Label.new()
	title_lbl.text = tr("CHẾ ĐỘ CHIẾN ĐẤU (PK)")
	title_lbl.add_theme_color_override("font_color", GameUi.GOLD)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_constant_override("outline_size", 2)
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = tr("Chọn trạng thái PK (Phím tắt: F9)")
	sub_lbl.add_theme_color_override("font_color", GameUi.MUTED)
	sub_lbl.add_theme_font_size_override("font_size", 11)
	title_vbox.add_child(sub_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var divider := HSeparator.new()
	root_vbox.add_child(divider)

	var lp := GameManager.local_profile
	var has_guild: bool = lp != null and not lp.guild.is_empty()

	var options: Array[Dictionary] = [
		{
			"mode": 0,
			"icon": "🛡️",
			"name": "Luyện Công (Hòa bình)",
			"desc": "Không tấn công người khác, chỉ tự vệ.",
			"color": Color(0.35, 0.85, 0.45),
			"enabled": true
		},
		{
			"mode": 1,
			"icon": "⚔️",
			"name": "Chiến Đấu Phe",
			"desc": "Tấn công người chơi khác phe có bật chiến đấu.",
			"color": Color(1.0, 0.65, 0.2),
			"enabled": true
		},
		{
			"mode": 2,
			"icon": "💀",
			"name": "Đồ Sát (Tên Đỏ)",
			"desc": "Tên đỏ rực! Có thể tấn công mọi người ngoài đội.",
			"color": Color(1.0, 0.25, 0.25),
			"enabled": true
		},
		{
			"mode": 3,
			"icon": "🚩",
			"name": "Bang Chiến",
			"desc": "Chiến đấu vì Bang Hội." if has_guild else "Yêu cầu đã gia nhập Bang Hội.",
			"color": Color(0.75, 0.3, 0.95),
			"enabled": has_guild
		}
	]

	for opt in options:
		var mode_id: int = opt["mode"]
		var is_selected: bool = (mode_id == _current_mode)
		var btn := _build_option_button(opt, is_selected)
		root_vbox.add_child(btn)

	_panel.reset_size()
	call_deferred("_position_panel", origin)

func _build_option_button(opt: Dictionary, is_selected: bool) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(WIDTH - 24, 46)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if opt["enabled"] else Control.CURSOR_FORBIDDEN
	btn.disabled = not opt["enabled"]

	var color: Color = opt["color"]

	var normal_sb := StyleBoxFlat.new()
	normal_sb.set_corner_radius_all(6)
	normal_sb.content_margin_left = 8
	normal_sb.content_margin_top = 4
	normal_sb.content_margin_right = 8
	normal_sb.content_margin_bottom = 4

	if is_selected:
		normal_sb.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.95)
		normal_sb.border_color = GameUi.GOLD
		normal_sb.set_border_width_all(2)
		normal_sb.shadow_color = Color(color.r, color.g, color.b, 0.35)
		normal_sb.shadow_size = 4
	else:
		normal_sb.bg_color = Color(0.10, 0.09, 0.08, 0.88)
		normal_sb.border_color = Color(0.3, 0.28, 0.24, 0.8)
		normal_sb.set_border_width_all(1)

	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 0.98)
	hover_sb.border_color = color
	hover_sb.set_border_width_all(2)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	btn.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = opt["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.custom_minimum_size = Vector2(28, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	name_lbl.text = tr(opt["name"])
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", GameUi.GOLD if is_selected else (color if opt["enabled"] else Color.GRAY))
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	text_vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = tr(opt["desc"])
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", GameUi.TEXT if opt["enabled"] else Color(0.5, 0.5, 0.5))
	text_vbox.add_child(desc_lbl)

	if is_selected:
		var check_lbl := Label.new()
		check_lbl.text = "✓ " + tr("Đang chọn")
		check_lbl.add_theme_font_size_override("font_size", 10)
		check_lbl.add_theme_color_override("font_color", GameUi.GOLD)
		check_lbl.add_theme_constant_override("outline_size", 1)
		check_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		hbox.add_child(check_lbl)

	var mode_id: int = opt["mode"]
	if mode_id == 0:
		_peace_desc_lbl = desc_lbl
		_peace_btn = btn
		_update_peace_cooldown_ui()

	btn.pressed.connect(func() -> void:
		if mode_id == 0 and _current_mode != 0:
			var cd: float = 0.0
			if _get_cooldown_cb != null and not _get_cooldown_cb.is_null():
				cd = float(_get_cooldown_cb.call())
			if cd > 0.0:
				var player := get_tree().get_first_node_in_group("player")
				if player and player.has_method("notify"):
					player.notify("⏳ Chưa thể chuyển về [BÌNH THƯỜNG / LUYỆN CÔNG]! Cần chờ thêm %d giây." % ceili(cd))
				_update_peace_cooldown_ui()
				return
		if not _on_select_cb.is_null():
			_on_select_cb.call(mode_id)
		close()
	)
	return btn

func _position_panel(origin: Control) -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var vp_rect := _panel.get_viewport_rect()
	var view := vp_rect.size
	var panel_size := _panel.size
	if panel_size.x <= 0 or panel_size.y <= 0:
		panel_size = _panel.get_combined_minimum_size()

	if origin != null and is_instance_valid(origin) and origin.is_inside_tree():
		var og_rect := origin.get_global_rect()
		var target_x: float
		if og_rect.position.x > view.x * 0.5:
			# Bên phải màn hình -> căn lề phải bảng theo nút
			target_x = og_rect.end.x - panel_size.x
		else:
			# Bên trái màn hình -> căn lề trái bảng theo nút
			target_x = og_rect.position.x
		var target_y: float
		if og_rect.position.y > view.y * 0.5:
			# Nửa dưới màn hình -> mở hướng lên trên nút
			target_y = og_rect.position.y - panel_size.y - 6.0
		else:
			# Nửa trên màn hình -> mở hướng xuống dưới nút
			target_y = og_rect.end.y + 6.0
		_panel.position = Vector2(
			clampf(target_x, 8.0, view.x - panel_size.x - 8.0),
			clampf(target_y, 8.0, view.y - panel_size.y - 8.0)
		)
	else:
		# Mặc định giữa trên màn hình
		_panel.position = Vector2(
			roundf((view.x - panel_size.x) * 0.5),
			60.0
		)

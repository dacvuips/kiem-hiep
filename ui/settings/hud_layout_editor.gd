extends CanvasLayer
class_name HudLayoutEditor
## Trình kéo & thả trực quan bố cục giao diện (HUD Layout Editor) trực tiếp trên màn hình game.
## Hiển thị khung bao quanh từng thành phần UI (với nền màu xanh và viền sáng rõ), cho phép kéo thả từng nút skill đánh độc lập và lưu cấu hình vào máy.

signal finished()

var _host: Node
var _boxes: Dictionary = {}
var _overlay: Control
var _top_panel: PanelContainer
var _dragged_id: String = ""
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO
var _backup_data: Dictionary = {}

static func open(host: Node) -> HudLayoutEditor:
	var ed := HudLayoutEditor.new(host)
	host.add_child(ed)
	return ed

func _init(host: Node = null) -> void:
	_host = host
	layer = 120  ## Nằm trên hầu hết các layer UI thông thường

func _ready() -> void:
	_backup_state()
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	HudLayout.add_listener(_refresh_box_rects)

func _exit_tree() -> void:
	HudLayout.remove_listener(_refresh_box_rects)

func _backup_state() -> void:
	for id in HudLayout.ELEMENTS:
		_backup_data[id] = HudLayout.get_element(id).duplicate()

func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Bảng điều khiển đỉnh màn hình
	_build_top_bar()

	# Khung đại diện cho từng phần tử HUD (nền màu xanh)
	for id in HudLayout.ELEMENTS:
		_create_element_box(id)

	_refresh_box_rects.call_deferred()

func _build_top_bar() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_top_panel.offset_left = -400
	_top_panel.offset_right = 400
	_top_panel.offset_top = 10
	_top_panel.offset_bottom = 62
	_top_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.14, 0.09, 0.96) # Nền màu xanh wuxia
	style.border_color = Color(0.28, 0.92, 0.55, 0.9) # Viền xanh sáng
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.6)
	_top_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(hbox)
	_top_panel.add_child(margin)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_lbl := Label.new()
	title_lbl.text = "🎨 TÙY CHỈNH GIAO DIỆN (KÉO THẢ TỪNG NÚT SKILL ĐỘC LẬP)"
	title_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	title_lbl.add_theme_font_size_override("font_size", 13)
	var tip_lbl := Label.new()
	tip_lbl.text = "Kéo từng nút ô xanh để chỉnh vị trí · Nút kỹ năng di chuyển riêng biệt từng nút · Lưu máy"
	tip_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88))
	tip_lbl.add_theme_font_size_override("font_size", 11)
	title_box.add_child(title_lbl)
	title_box.add_child(tip_lbl)
	hbox.add_child(title_box)

	var btn_reset := SocialUi.stone_button("↺ Mặc Định")
	btn_reset.custom_minimum_size = Vector2(90, 32)
	btn_reset.pressed.connect(_on_reset_all)
	hbox.add_child(btn_reset)

	var btn_cancel := SocialUi.stone_button("✕ Hủy")
	btn_cancel.custom_minimum_size = Vector2(70, 32)
	btn_cancel.pressed.connect(_on_cancel)
	hbox.add_child(btn_cancel)

	var btn_save := SocialUi.stone_button("✓ Hoàn Tất")
	btn_save.custom_minimum_size = Vector2(100, 32)
	btn_save.pressed.connect(_on_finish_save)
	hbox.add_child(btn_save)

	_overlay.add_child(_top_panel)

func _create_element_box(id: String) -> void:
	var info: Dictionary = HudLayout.ELEMENTS.get(id, {})
	var is_skill := id.begins_with("skill_")
	var box := Panel.new()
	box.name = "Box_" + id
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.mouse_default_cursor_shape = Control.CURSOR_MOVE

	# Nền màu xanh nổi bật theo yêu cầu người dùng
	var style := StyleBoxFlat.new()
	if is_skill:
		# Các nút skill đánh: nền xanh lá/ngọc đậm với viền xanh ngọc rực rỡ
		style.bg_color = Color(0.06, 0.44, 0.25, 0.52)
		style.border_color = Color(0.22, 0.98, 0.58, 0.95)
		style.set_border_width_all(2)
		style.set_corner_radius_all(32) # Bo tròn khớp nút skill
	else:
		# Các khung HUD khác: nền xanh lam ngọc wuxia
		style.bg_color = Color(0.04, 0.30, 0.22, 0.40)
		style.border_color = Color(0.25, 0.85, 0.65, 0.85)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)

	box.add_theme_stylebox_override("panel", style)

	# Nhãn tên nhỏ trên từng ô
	var label_pill := PanelContainer.new()
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0.02, 0.16, 0.09, 0.90)
	pill_style.border_color = Color(0.2, 0.75, 0.45, 0.8)
	pill_style.set_border_width_all(1)
	pill_style.set_corner_radius_all(4)
	pill_style.content_margin_left = 4
	pill_style.content_margin_right = 4
	pill_style.content_margin_top = 1
	pill_style.content_margin_bottom = 1
	label_pill.add_theme_stylebox_override("panel", pill_style)
	label_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_text: String = info.get("title", id)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 10 if is_skill else 11)
	lbl.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	label_pill.add_child(lbl)
	box.add_child(label_pill)

	# Thanh kéo kích thước nhanh cho minimap và chat_box
	if id == "minimap":
		var scale_row := HBoxContainer.new()
		scale_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		scale_row.offset_top = -24
		scale_row.offset_bottom = -2
		scale_row.offset_left = 4
		scale_row.offset_right = -4
		var s_lbl := Label.new()
		s_lbl.text = "Cỡ:"
		s_lbl.add_theme_font_size_override("font_size", 10)
		scale_row.add_child(s_lbl)
		var slider := HSlider.new()
		slider.min_value = 0.75
		slider.max_value = 1.5
		slider.step = 0.05
		slider.value = float(HudLayout.get_element("minimap").get("scale", 1.0))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v: float) -> void:
			HudLayout.set_element_scale("minimap", v))
		scale_row.add_child(slider)
		box.add_child(scale_row)
	elif id == "chat_box":
		var width_row := HBoxContainer.new()
		width_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		width_row.offset_top = -24
		width_row.offset_bottom = -2
		width_row.offset_left = 4
		width_row.offset_right = -4
		var w_lbl := Label.new()
		w_lbl.text = "Rộng:"
		w_lbl.add_theme_font_size_override("font_size", 10)
		width_row.add_child(w_lbl)
		var slider := HSlider.new()
		slider.min_value = 300.0
		slider.max_value = 700.0
		slider.step = 10.0
		slider.value = float(HudLayout.get_element("chat_box").get("width", 400.0))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v: float) -> void:
			HudLayout.set_element_property("chat_box", "width", v))
		width_row.add_child(slider)
		box.add_child(width_row)

	box.gui_input.connect(_on_box_gui_input.bind(id))
	_overlay.add_child(box)
	_boxes[id] = box

func _on_box_gui_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragged_id = id
				_drag_start_mouse = mb.global_position
				var cur_elem: Dictionary = HudLayout.get_element(id)
				_drag_start_offset = Vector2(float(cur_elem.get("offset_x", 0.0)), float(cur_elem.get("offset_y", 0.0)))
			else:
				_dragged_id = ""
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_dragged_id = id
			_drag_start_mouse = st.position
			var cur_elem: Dictionary = HudLayout.get_element(id)
			_drag_start_offset = Vector2(float(cur_elem.get("offset_x", 0.0)), float(cur_elem.get("offset_y", 0.0)))
		else:
			_dragged_id = ""
	elif event is InputEventMouseMotion and _dragged_id == id:
		var mm := event as InputEventMouseMotion
		var delta: Vector2 = mm.global_position - _drag_start_mouse
		var new_offset: Vector2 = _drag_start_offset + delta
		var info: Dictionary = HudLayout.ELEMENTS.get(id, {})
		var rx: float = float(info.get("range_x", 500.0))
		var ry: float = float(info.get("range_y", 300.0))
		new_offset.x = clampf(new_offset.x, -rx, rx)
		new_offset.y = clampf(new_offset.y, -ry, ry)
		HudLayout.set_element_offset(id, new_offset)
	elif event is InputEventScreenDrag and _dragged_id == id:
		var sd := event as InputEventScreenDrag
		var delta: Vector2 = sd.position - _drag_start_mouse
		var new_offset: Vector2 = _drag_start_offset + delta
		var info: Dictionary = HudLayout.ELEMENTS.get(id, {})
		var rx: float = float(info.get("range_x", 500.0))
		var ry: float = float(info.get("range_y", 300.0))
		new_offset.x = clampf(new_offset.x, -rx, rx)
		new_offset.y = clampf(new_offset.y, -ry, ry)
		HudLayout.set_element_offset(id, new_offset)

func _refresh_box_rects() -> void:
	for id in _boxes:
		var box: Panel = _boxes[id]
		var rect := _calc_element_screen_rect(id)
		if rect.size.x > 0 and rect.size.y > 0:
			box.visible = true
			box.position = rect.position
			box.size = rect.size
			if id.begins_with("skill_"):
				var sb: StyleBoxFlat = box.get_theme_stylebox("panel") as StyleBoxFlat
				if sb != null:
					sb.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.5))
		else:
			box.visible = false

func _calc_element_screen_rect(id: String) -> Rect2:
	var vp_size := get_viewport().get_visible_rect().size
	var elem_data := HudLayout.get_element(id)
	var sc := float(elem_data.get("scale", 1.0))
	var ox := float(elem_data.get("offset_x", 0.0))
	var oy := float(elem_data.get("offset_y", 0.0))

	# Ưu tiên lấy trực tiếp từ node trên UI nếu có
	var live_node := _find_live_node(id)
	if live_node != null and is_instance_valid(live_node) and live_node.is_inside_tree():
		var g_rect: Rect2 = live_node.get_global_rect()
		if g_rect.size.x > 10 and g_rect.size.y > 10:
			return g_rect

	# Tính toán dự phòng theo toạ độ lý thuyết
	match id:
		"skill_main":
			var sz := Vector2(108, 108) * sc
			return Rect2(Vector2(vp_size.x - 125.0 + ox, vp_size.y - 200.0 + oy), sz)
		"skill_s0":
			var sz := Vector2(64, 64) * sc
			return Rect2(Vector2(vp_size.x - 200.0 + ox, vp_size.y - 79.0 + oy), sz)
		"skill_s1":
			var sz := Vector2(64, 64) * sc
			return Rect2(Vector2(vp_size.x - 273.0 + ox, vp_size.y - 147.0 + oy), sz)
		"skill_s2":
			var sz := Vector2(64, 64) * sc
			return Rect2(Vector2(vp_size.x - 220.0 + ox, vp_size.y - 231.0 + oy), sz)
		"skill_s3":
			var sz := Vector2(64, 64) * sc
			return Rect2(Vector2(vp_size.x - 147.0 + ox, vp_size.y - 280.0 + oy), sz)
		"skill_s4":
			var sz := Vector2(64, 64) * sc
			return Rect2(Vector2(vp_size.x - 70.0 + ox, vp_size.y - 300.0 + oy), sz)
		"skill_s5":
			var sz := Vector2(64, 64) * sc
			return Rect2(Vector2(vp_size.x - 340.0 + ox, vp_size.y - 180.0 + oy), sz)
		"skill_s6":
			var sz := Vector2(64, 64) * sc
			return Rect2(Vector2(vp_size.x - 290.0 + ox, vp_size.y - 260.0 + oy), sz)
		"skill_s7":
			var sz := Vector2(64, 64) * sc
			return Rect2(Vector2(vp_size.x - 200.0 + ox, vp_size.y - 310.0 + oy), sz)
		"skill_loop0":
			var sz := Vector2(44, 44) * sc
			return Rect2(Vector2(vp_size.x - 263.0 + ox, vp_size.y - 73.0 + oy), sz)
		"skill_jump":
			var sz := Vector2(56, 56) * sc
			return Rect2(Vector2(vp_size.x - 297.0 + ox, vp_size.y - 237.0 + oy), sz)
		"skill_horse":
			var sz := Vector2(64, 64) * sc
			return Rect2(Vector2(vp_size.x - 347.0 + ox, vp_size.y - 76.0 + oy), sz)
		"skill_sit":
			var sz := Vector2(52, 52) * sc
			return Rect2(Vector2(vp_size.x - 409.0 + ox, vp_size.y - 64.0 + oy), sz)
		"top_bar":
			var w := 491.0 * 1.2 * sc
			var h := 38.0 * sc
			return Rect2(Vector2((vp_size.x - w) * 0.5 + ox, 2.0 + oy), Vector2(w, h))
		"minimap":
			var sz := Vector2(140.0, 140.0) * sc
			return Rect2(Vector2(vp_size.x - sz.x - 8.0 + ox, 8.0 + oy), sz)
		"chat_box":
			var w := float(elem_data.get("width", 400.0)) * sc
			var h := 120.0 * sc
			return Rect2(Vector2(vp_size.x * 0.5 - w + ox, vp_size.y - h - 8.0 + oy), Vector2(w, h))
		"quick_items":
			var w := (4.0 * 56.0 + 3.0 * 10.0) * sc
			var h := 56.0 * sc
			return Rect2(Vector2(vp_size.x - 14.0 - w + ox, vp_size.y - 384.0 - h + oy), Vector2(w, h))
		"side_menu":
			var w := (4.0 * 46.0 + 3.0 * 6.0) * sc
			var h := 46.0 * sc
			return Rect2(Vector2(vp_size.x - 170.0 - w + ox, 56.0 + oy), Vector2(w, h))
		"auto_button":
			var sz := Vector2(52.0, 52.0) * sc
			return Rect2(Vector2(vp_size.x - 60.0 + ox, 155.0 + oy), sz)
		"auto_gear":
			var sz := Vector2(52.0, 52.0) * sc
			return Rect2(Vector2(vp_size.x - 118.0 + ox, 155.0 + oy), sz)
		"pk_mode":
			var sz := Vector2(115.0, 32.0) * sc
			return Rect2(Vector2(12.0 + ox, 62.0 + oy), sz)
		"bottom_bar":
			var w := (3.0 * 46.0 + 2.0 * 6.0) * sc
			var h := 46.0 * sc
			return Rect2(Vector2(vp_size.x - 415.0 - w + ox, vp_size.y - 58.0 + oy), Vector2(w, h))
		"joystick":
			var sz := Vector2(200.0, 200.0) * sc
			return Rect2(Vector2(40.0 + ox, vp_size.y - 250.0 + oy), sz)
		"exit_button":
			var sz := Vector2(46.0, 46.0) * sc
			return Rect2(Vector2(vp_size.x - 200.0 + ox, 8.0 + oy), sz)
	return Rect2(Vector2.ZERO, Vector2.ZERO)

func _find_live_node(id: String) -> Control:
	var root := _host.get_node_or_null("UI") if _host.has_node("UI") else _host
	if root == null:
		return null
	var bar := root.get_node_or_null("SkillBarUI") as SkillBarUI
	if id.begins_with("skill_"):
		if bar == null:
			return null
		match id:
			"skill_main":
				return bar.get_node_or_null("%MainButton") as Control
			"skill_s0":
				return bar.get_node_or_null("%Sub1") as Control
			"skill_s1":
				return bar.get_node_or_null("%Sub2") as Control
			"skill_s2":
				return bar.get_node_or_null("%Sub3") as Control
			"skill_s3":
				return bar.get_node_or_null("%Sub4") as Control
			"skill_s4":
				return bar.get_node_or_null("%Sub5") as Control
			"skill_s5":
				return bar.get_node_or_null("%Sub6") as Control
			"skill_s6":
				return bar.get_node_or_null("%Sub7") as Control
			"skill_s7":
				return bar.get_node_or_null("%Sub8") as Control
			"skill_loop0":
				return bar.get_node_or_null("%Loop1") as Control
			"skill_jump":
				return bar.get_node_or_null("%JumpButton") as Control
			"skill_horse":
				return bar.get_node_or_null("%HorseButton") as Control
			"skill_sit":
				return bar.get_node_or_null("%SitButton") as Control
	match id:
		"top_bar":
			for c in root.get_children():
				if c is TopStatusBar:
					return c
		"minimap":
			return root.get_node_or_null("MiniMap") as Control
		"chat_box":
			return root.get_node_or_null("ChatBox") as Control
		"quick_items":
			for c in root.get_children():
				if c is QuickItemBar:
					return c
		"side_menu":
			return root.get_node_or_null("SideMenu") as Control
		"auto_button":
			if bar != null:
				return bar.get_node_or_null("%AutoButton") as Control
		"auto_gear":
			if bar != null:
				return bar.get_node_or_null("AutoGearButton") as Control
		"pk_mode":
			var top_left := root.get_node_or_null("TopLeftActionBar") as Control
			if top_left != null:
				var badge := top_left.get_node_or_null("PkModeBadge") as Control
				return badge if badge != null else top_left
		"bottom_bar":
			return root.get_node_or_null("BottomActionBar") as Control
		"joystick":
			return root.get_node_or_null("VirtualJoystick") as Control
		"exit_button":
			return root.get_node_or_null("ExitButton") as Control
	return null

func _on_viewport_resized() -> void:
	_refresh_box_rects()

func _on_reset_all() -> void:
	HudLayout.reset_all()
	_refresh_box_rects()

func _on_cancel() -> void:
	for id in _backup_data:
		HudLayout.set_element_offset(id, Vector2(_backup_data[id].get("offset_x", 0.0), _backup_data[id].get("offset_y", 0.0)))
		HudLayout.set_element_scale(id, float(_backup_data[id].get("scale", 1.0)))
		if _backup_data[id].has("width"):
			HudLayout.set_element_property(id, "width", _backup_data[id]["width"])
	finished.emit()
	queue_free()

func _on_finish_save() -> void:
	finished.emit()
	queue_free()

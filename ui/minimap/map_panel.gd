extends CanvasLayer
class_name MapPanel
## BẢNG BẢN ĐỒ LỚN — mở khi bấm nút "bản đồ" trên mini map. Bố cục theo mẫu: tiêu đề + nút đóng, cột trái tìm tên NPC/địa điểm,
## phần đầu hiện tên map + vị trí + "Đang đi tới X/Y" + ô nhập X, Y + nút ✓ (đi) + nút ◎ (về chỗ nhân vật), giữa là bản đồ.
##   - Bấm lên bản đồ = CẮM CỜ ĐỎ và nhân vật tự đi tới đó; chấm vàng nối từ nhân vật tới lá cờ là lộ trình còn lại.
##   - Kéo để dời bản đồ, lăn chuột để phóng/thu. Chấm vàng to có viền = nhân vật.
##   - Danh sách trái đọc từ data/map/places.json: [{"name": "Tiệm tạp hoá", "x": 201, "y": 195}, ...] (toạ độ hiển thị X/Y).
## Dùng MiniMap để đi (walk_to_feet) nên thông báo/đích đồng bộ với mini map nhỏ.

const PLACES_PATH := "res://data/map/places.json"
const MARGIN := 28.0
const LEFT_WIDTH := 240.0
const ZOOM_MIN_FACTOR := 1.0         ## nhỏ nhất = vừa khít ảnh vào khung
const ZOOM_MAX := 3.0
const ZOOM_STEP := 1.18
const START_ZOOM := 1.0
const DRAG_THRESHOLD := 6.0
const ROUTE_DOT_GAP := 16.0
const GOLD := Color(0.93, 0.78, 0.35)
const PANEL_BG := Color(0.07, 0.055, 0.04, 0.97)
const FIELD_BG := Color(0.13, 0.11, 0.09, 1.0)

var _mini: MiniMap
var _player: Node2D
var _tex: Texture2D
var _zoom := START_ZOOM
var _center_img := Vector2.ZERO       ## điểm ảnh nằm giữa khung xem
var _places: Array = []
var _drag_start := Vector2.ZERO
var _dragging := false
var _press_pos := Vector2.ZERO
var _pressed := false

var _view: Control
var _pos_label: Label
var _goto_label: Label
var _x_input: LineEdit
var _y_input: LineEdit
var _list: VBoxContainer
var _search: LineEdit
var _toast: Label
var _toast_time := 0.0

func setup(mini: MiniMap, player: Node2D) -> void:
	_mini = mini
	_player = player
	_tex = mini.get_map_texture()
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_places()
	_build()
	_center_on_player()

func _load_places() -> void:
	if FileAccess.file_exists(PLACES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES_PATH))
		if parsed is Array:
			_places = parsed

# ---------------------------------------------------------------- dựng giao diện

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = MARGIN
	panel.offset_top = MARGIN
	panel.offset_right = -MARGIN
	panel.offset_bottom = -MARGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.42, 0.22)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	## --- tiêu đề + đóng
	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title := Label.new()
	title.text = "Bản đồ"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(44, 36)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(queue_free)
	title_row.add_child(close)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	## --- cột trái: tìm NPC / địa điểm
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_search = LineEdit.new()
	_search.placeholder_text = "Tìm tên NPC / địa điểm"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _fill_list())
	left.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_fill_list()

	## --- bên phải: đầu bảng + bản đồ
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	right.add_child(head)
	var names := VBoxContainer.new()
	head.add_child(names)
	var map_name := Label.new()
	map_name.text = _mini.get_title() if _mini.get_title() != "" else "Bản đồ"
	map_name.add_theme_font_size_override("font_size", 26)
	map_name.add_theme_color_override("font_color", Color(1.0, 0.93, 0.35))
	names.add_child(map_name)
	_pos_label = Label.new()
	_pos_label.add_theme_font_size_override("font_size", 18)
	names.add_child(_pos_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_goto_label = Label.new()
	_goto_label.add_theme_font_size_override("font_size", 18)
	_goto_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	_goto_label.visible = false
	head.add_child(_goto_label)
	_x_input = _make_coord_input("X")
	head.add_child(_x_input)
	_y_input = _make_coord_input("Y")
	head.add_child(_y_input)
	var go := Button.new()
	go.text = "✓"
	go.custom_minimum_size = Vector2(48, 44)
	go.focus_mode = Control.FOCUS_NONE
	go.tooltip_text = "Đi tới toạ độ X/Y"
	go.pressed.connect(_on_go_pressed)
	head.add_child(go)
	var locate := Button.new()
	locate.text = "◎"
	locate.custom_minimum_size = Vector2(48, 44)
	locate.focus_mode = Control.FOCUS_NONE
	locate.tooltip_text = "Về chỗ nhân vật"
	locate.pressed.connect(_center_on_player)
	head.add_child(locate)

	_view = Control.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_view_input)
	right.add_child(_view)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.position = Vector2(0, 0)
	_view.add_child(_toast)

func _make_coord_input(hint: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = hint
	le.custom_minimum_size = Vector2(96, 44)
	le.max_length = 5
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.add_theme_font_size_override("font_size", 20)
	le.text_submitted.connect(func(_t: String) -> void: _on_go_pressed())
	return le

func _fill_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower()
	var shown := 0
	for place in _places:
		var pname := str(place.get("name", ""))
		if q != "" and not pname.to_lower().contains(q):
			continue
		var b := Button.new()
		b.text = pname
		b.custom_minimum_size = Vector2(0, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_walk_to_coord.bind(Vector2i(int(place.get("x", 0)), int(place.get("y", 0)))))
		_list.add_child(b)
		shown += 1
	if shown == 0:
		var hint := Label.new()
		hint.text = "Chưa có địa điểm nào." if _places.is_empty() else "Không tìm thấy."
		hint.add_theme_color_override("font_color", Color(0.6, 0.57, 0.5))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(hint)
		if _places.is_empty():
			var how := Label.new()
			how.text = "Thêm vào data/map/places.json:\n{\"name\": \"Tên\", \"x\": 201, \"y\": 195}"
			how.add_theme_font_size_override("font_size", 12)
			how.add_theme_color_override("font_color", Color(0.5, 0.47, 0.42))
			how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_list.add_child(how)

# ---------------------------------------------------------------- đi

func _walk_to_coord(c: Vector2i) -> void:
	_walk_to_feet(_mini.coord_to_feet(c))

func _walk_to_feet(feet: Vector2) -> void:
	var msg := _mini.walk_to_feet(feet)
	if msg != "":
		_show_toast(msg)

func _on_go_pressed() -> void:
	if not _x_input.text.is_valid_int() or not _y_input.text.is_valid_int():
		_show_toast("Nhập đủ X và Y (số nguyên)")
		return
	_walk_to_coord(Vector2i(int(_x_input.text), int(_y_input.text)))

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_time = 2.5

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return
	var c := _mini.feet_to_coord(_mini.player_feet())
	_pos_label.text = "Vị trí: %d/%d" % [c.x, c.y]
	if _mini.has_destination() and _player.is_moving_to_target():
		var d := _mini.feet_to_coord(_mini.destination_feet())
		_goto_label.text = "Đang đi tới %d/%d" % [d.x, d.y]
		_goto_label.visible = true
	else:
		_goto_label.visible = false
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.visible = false
	_view.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- bản đồ

func _fit_zoom() -> float:
	if _tex == null:
		return 1.0
	var vs := _view.size
	return maxf(minf(vs.x / float(_tex.get_width()), vs.y / float(_tex.get_height())), 0.05)

func _center_on_player() -> void:
	_zoom = clampf(START_ZOOM, _fit_zoom() * ZOOM_MIN_FACTOR, ZOOM_MAX)
	_center_img = _mini.world_to_image(_mini.player_feet())

func _clamp_center() -> void:
	if _tex == null:
		return
	var half := _view.size / (2.0 * _zoom)
	var tex_size := Vector2(_tex.get_size())
	_center_img.x = clampf(_center_img.x, minf(half.x, tex_size.x * 0.5), maxf(tex_size.x - half.x, tex_size.x * 0.5))
	_center_img.y = clampf(_center_img.y, minf(half.y, tex_size.y * 0.5), maxf(tex_size.y - half.y, tex_size.y * 0.5))

func _img_to_view(p: Vector2) -> Vector2:
	return (p - _center_img) * _zoom + _view.size * 0.5

func _view_to_img(p: Vector2) -> Vector2:
	return (p - _view.size * 0.5) / _zoom + _center_img

func _world_to_view(w: Vector2) -> Vector2:
	return _img_to_view(_mini.world_to_image(w))

func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_press_pos = event.position
				_drag_start = event.position
			else:
				if _pressed and not _dragging:
					_walk_to_feet(_mini.image_to_world(_view_to_img(event.position)))   ## bấm (không kéo) = cắm cờ + đi
				_pressed = false
				_dragging = false
	elif event is InputEventMouseMotion and _pressed:
		if not _dragging and event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			_center_img -= (event.position - _drag_start) / _zoom
			_drag_start = event.position
			_clamp_center()

func _zoom_at(at: Vector2, factor: float) -> void:
	var before := _view_to_img(at)
	_zoom = clampf(_zoom * factor, _fit_zoom() * ZOOM_MIN_FACTOR, ZOOM_MAX)
	## Giữ điểm dưới con trỏ đứng yên khi phóng.
	_center_img += before - _view_to_img(at)
	_clamp_center()

func _draw_view() -> void:
	_clamp_center()
	if _tex != null:
		var tl := _img_to_view(Vector2.ZERO)
		_view.draw_texture_rect(_tex, Rect2(tl, Vector2(_tex.get_size()) * _zoom), false)
	else:
		_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0.1, 0.12, 0.09))
	## Ô vuông màn chơi (nếu đang ở chế độ Vượt Ải).
	if VltkWorld.has_arena():
		var r := VltkWorld.current.arena_rect
		var a := _world_to_view(r.position)
		var b := _world_to_view(r.end)
		_view.draw_rect(Rect2(a, b - a), Color(GOLD, 0.9), false, 2.0)
	## Địa điểm trong danh sách.
	for place in _places:
		var pp := _world_to_view(_mini.coord_to_feet(Vector2i(int(place.get("x", 0)), int(place.get("y", 0)))))
		if Rect2(Vector2.ZERO, _view.size).has_point(pp):
			_view.draw_circle(pp, 5.0, Color(1.0, 0.6, 0.15))
			_view.draw_string(ThemeDB.fallback_font, pp + Vector2(8, 5), str(place.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.8))
	var me := _world_to_view(_mini.player_feet())
	## Lộ trình còn lại: chấm vàng từ nhân vật theo các điểm tới lá cờ.
	if _mini.has_destination() and _player.is_moving_to_target():
		var pts: PackedVector2Array = [me]
		for w in _player.get_route_feet():
			pts.append(_world_to_view(w))
		_draw_dotted(pts)
		_draw_flag(_world_to_view(_mini.destination_feet()))
	## Nhân vật.
	_view.draw_circle(me, 10.0, Color(0, 0, 0, 0.55))
	_view.draw_circle(me, 8.0, Color(1.0, 0.85, 0.0))
	_view.draw_arc(me, 12.0, 0.0, TAU, 28, Color(1, 1, 1, 0.8), 1.5)

## Chấm tròn đều nhau dọc đường gấp khúc (khoảng cách tính theo pixel màn hình).
func _draw_dotted(pts: PackedVector2Array) -> void:
	var carry := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var dir := (b - a) / length
		var d := ROUTE_DOT_GAP - carry
		while d <= length:
			_view.draw_circle(a + dir * d, 3.2, Color(1.0, 0.85, 0.1))
			d += ROUTE_DOT_GAP
		carry = length - (d - ROUTE_DOT_GAP)
		if carry < 0.0:
			carry = 0.0

## Cờ đỏ cắm tại đích: cột trắng + lá cờ tam giác đỏ, chân cột đúng điểm đích.
func _draw_flag(base: Vector2) -> void:
	var top := base + Vector2(0, -30)
	_view.draw_line(base, top, Color(0.95, 0.95, 0.95), 3.0)
	_view.draw_colored_polygon(PackedVector2Array([top, top + Vector2(22, 7), top + Vector2(0, 14)]), Color(0.9, 0.12, 0.1))
	_view.draw_circle(base, 3.0, Color(1, 1, 1, 0.9))

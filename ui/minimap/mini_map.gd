extends Control
class_name MiniMap
## Khung MINI MAP góc phải trên, dựng theo UiMiniMapSmall.ini của VLTK gốc (khung 130x145: tên map ở trên, vùng bản đồ
## 129x128, hàng dưới là toạ độ + các nút 14x14 lấy từ spr gốc), phóng to UI_SCALE lần cho dễ nhìn.
##   - Ảnh bản đồ là ảnh mini map gốc của map chính (world/minimap/minimap.jpg — tools/import_vltk_minimap.py), đã có sẵn
##     chấm vàng + tên địa điểm; cuộn theo nhân vật, chấm VÀNG ở giữa = người chơi.
##   - Hệ toạ độ như game gốc (UiMiniMap::UpdateSceneTimeInfo): X/Y = pixel map / 256 (hiển thị "194/202").
##   - Bấm vào dòng toạ độ (hoặc nút cờ) để NHẬP toạ độ "X/Y" rồi Enter -> nhân vật tự đi tới đó (đường vòng vật cản, trong ô
##     màn chơi). Bấm lên bản đồ cũng tự đi tới chỗ đó.
##   - Nút đổi mức phóng, nút "bản đồ thế giới" = xem toàn bộ map (hiện luôn ô vuông màn chơi viền vàng).

const BASE_SIZE := Vector2(130, 145)
const MAP_RECT := Rect2(1, 1, 129, 128)
const NAME_BAR_HEIGHT := 17.0
const POS_BAR := Rect2(0, 129, 130, 14)
const UI_SCALE := 1.5
const SCREEN_MARGIN := 8.0
const COORD_UNIT := 256.0               ## 1 đơn vị toạ độ hiển thị = 256 pixel map (gốc: logic/32/8)
const ZOOMS := [0.75, 1.0, 1.5, 2.5]
const META_PATH := "res://world/minimap/minimap.json"
const BTN_DIR := "res://ui/minimap/"
const ROUTE_DOT_GAP := 7.0           ## khoảng cách giữa các chấm lộ trình (pixel khung mini map)
const GREEN := Color(0.0, 1.0, 0.0)
const GOLD := Color(0.95, 0.78, 0.3)

var _tex: Texture2D
var _origin := Vector2.ZERO          ## pixel map của góc trên-trái ảnh
var _img_scale := 16.0               ## 1 pixel ảnh = _img_scale pixel map
var _zoom_index := 1
var _show_world := false
var _title := ""
var _dest := Vector2.ZERO            ## đích đang tự đi tới (pixel map, chân)
var _has_dest := false
var _notice := ""
var _notice_time := 0.0

var _player: Node2D
var _view: Control
var _pos_label: Label
var _pos_input: LineEdit
var _notice_label: Label

func setup(player: Node2D) -> void:
	_player = player
	_load_assets()
	custom_minimum_size = BASE_SIZE
	size = BASE_SIZE
	scale = Vector2.ONE * UI_SCALE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_viewport().size_changed.connect(_place)
	_place()

## Đặt sát góc phải-trên màn hình (scale làm kích thước thật = BASE_SIZE * UI_SCALE).
func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	position = Vector2(vp.x - BASE_SIZE.x * UI_SCALE - SCREEN_MARGIN, SCREEN_MARGIN)

func _load_assets() -> void:
	if FileAccess.file_exists(META_PATH):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if meta is Dictionary:
			_title = str(meta.get("title", ""))
	## Ảnh + toạ độ lấy từ chính map chính: map.json["minimap"] do tool map xuất (file, px_per_region, min_x, min_y).
	var world := VltkWorld.current
	if world == null or world.map == null:
		return
	var info: Variant = world.map.data.get("minimap")
	if info is Dictionary:
		_tex = world.map.get_minimap_texture()
		_origin = Vector2(float(info["min_x"]), float(info["min_y"])) * 512.0
		_img_scale = 512.0 / float(info["px_per_region"])   ## 1 pixel ảnh = (512 / px_per_region) pixel map

func _build() -> void:
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = BASE_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.045, 0.03, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.55, 0.42, 0.22)
	frame.add_theme_stylebox_override("panel", sb)
	add_child(frame)

	_view = Control.new()
	_view.position = MAP_RECT.position
	_view.size = MAP_RECT.size
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_view_input)
	add_child(_view)

	## Dải tên map (NameShadow trong ini gốc: nền nâu sẫm trong suốt) + tên màu xanh lá.
	var bar := ColorRect.new()
	bar.color = Color(38 / 255.0, 25 / 255.0, 13 / 255.0, 120 / 255.0)
	bar.position = Vector2.ZERO
	bar.size = Vector2(BASE_SIZE.x, NAME_BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var name_label := _make_label(_title if _title != "" else "Bản đồ")
	name_label.position = Vector2(2, 1)
	name_label.size = Vector2(BASE_SIZE.x - 4, 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)

	## Hàng dưới: toạ độ (bấm để nhập) + nút.
	var pos_bg := ColorRect.new()
	pos_bg.color = Color(0.08, 0.06, 0.04, 0.95)
	pos_bg.position = POS_BAR.position
	pos_bg.size = POS_BAR.size
	pos_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pos_bg)
	_pos_label = _make_label("")
	_pos_label.position = Vector2(2, 129)
	_pos_label.size = Vector2(70, 14)
	_pos_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_pos_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_pos_label.tooltip_text = "Nhấp chuột để nhập toạ độ và tự đi tới đó"
	_pos_label.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_input())
	add_child(_pos_label)

	_pos_input = LineEdit.new()
	_pos_input.position = Vector2(1, 129)
	_pos_input.size = Vector2(72, 14)
	_pos_input.add_theme_font_size_override("font_size", 10)
	_pos_input.add_theme_color_override("font_color", GREEN)
	_pos_input.add_theme_color_override("caret_color", GREEN)
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0.55)
	empty.content_margin_left = 2
	empty.content_margin_top = 0
	empty.content_margin_bottom = 0
	_pos_input.add_theme_stylebox_override("normal", empty)
	_pos_input.add_theme_stylebox_override("focus", empty)
	_pos_input.placeholder_text = "X/Y"
	_pos_input.max_length = 12
	_pos_input.visible = false
	_pos_input.text_submitted.connect(_on_input_submitted)
	_pos_input.focus_exited.connect(func() -> void: _close_input())
	add_child(_pos_input)

	## Nút gốc 14x14 (Up/Down/Over = frame 0/1/2): cờ = nhập toạ độ, switch = đổi mức phóng, thế giới = toàn bản đồ.
	_add_button("flag", 73, "Nhập toạ độ để tự đi", _open_input)
	_add_button("switch", 87, "Mở bản đồ lớn", _open_map_panel)
	_add_button("world", 101, "Xem toàn bộ bản đồ", _toggle_world)

	_notice_label = _make_label("")
	_notice_label.position = Vector2(2, 20)
	_notice_label.size = Vector2(126, 22)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.visible = false
	add_child(_notice_label)

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", GREEN)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _add_button(key: String, x: float, tip: String, on_press: Callable) -> void:
	var b := TextureButton.new()
	b.position = Vector2(x, 129)
	b.size = Vector2(14, 14)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = _btn_tex(key, 0)
	b.texture_pressed = _btn_tex(key, 1)
	b.texture_hover = _btn_tex(key, 2)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	add_child(b)

func _btn_tex(key: String, frame: int) -> Texture2D:
	var path := "%sbtn_%s_%d.png" % [BTN_DIR, key, frame]
	return load(path) if ResourceLoader.exists(path) else null

# ---------------------------------------------------------------- toạ độ

func _feet() -> Vector2:
	return _player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)

func _to_coord(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / COORD_UNIT), floori(world.y / COORD_UNIT))

func _coord_to_world(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * COORD_UNIT

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var c := _to_coord(_feet())
	var coord_text := "%d/%d" % [c.x, c.y]
	if _pos_label.text != coord_text:
		_pos_label.text = coord_text
	if _has_dest and not _player.is_moving_to_target():
		_has_dest = false
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0:
			_notice_label.visible = false
	_redraw_time -= delta
	if _redraw_time <= 0.0:   ## vẽ lại mini map ~20 lần/giây, không cần mỗi khung hình
		_redraw_time = 0.05
		_view.queue_redraw()

var _redraw_time := 0.0

func _open_input() -> void:
	_pos_input.text = _pos_label.text
	_pos_input.visible = true
	_pos_label.visible = false
	_pos_input.grab_focus()
	_pos_input.select_all()

func _close_input() -> void:
	_pos_input.visible = false
	_pos_label.visible = true

func _on_input_submitted(text: String) -> void:
	var parsed := _parse_coord(text)
	_close_input()
	_pos_input.release_focus()
	if parsed.x < 0:
		_show_notice("Toạ độ không hợp lệ. Nhập dạng 194/202")
		return
	_walk_to(_coord_to_world(Vector2i(parsed.x, parsed.y)))

## "194/202", "194 202", "194,202" -> (x, y); (-1, -1) nếu sai.
func _parse_coord(text: String) -> Vector2i:
	var parts := text.strip_edges().replace(",", " ").replace("/", " ").replace(";", " ").split(" ", false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))

func _walk_to(target_feet: Vector2) -> void:
	var msg := walk_to_feet(target_feet)
	if msg != "":
		_show_notice(msg)

## Tự đi tới điểm CHÂN `target_feet` (kéo vào trong ô màn chơi nếu có). Trả về thông báo cho người chơi ("" = ổn).
## Dùng chung cho mini map nhỏ và bảng bản đồ lớn (MapPanel).
func walk_to_feet(target_feet: Vector2) -> String:
	var msg := ""
	var inside := VltkWorld.clamp_to_arena(target_feet)
	if inside != target_feet:
		msg = "Ngoài khu màn chơi — đi tới mép gần nhất"
	if not _player.walk_to_feet(inside):
		return "Không có đường tới đó"
	if VltkWorld.last_path_partial:
		msg = "Có vật cản (sông/tường) chắn đường — đi tới điểm gần nhất"
	## Đích hiển thị = điểm CUỐI của lộ trình (nơi nhân vật thật sự sẽ dừng): đích bị nhà/sông chắn thì khác toạ độ đã nhập,
	## ghi rõ toạ độ thực để người chơi không tưởng toạ độ bị sai.
	var route: PackedVector2Array = _player.get_route_feet()
	_dest = route[route.size() - 1] if not route.is_empty() else inside
	_has_dest = true
	var wanted := _to_coord(inside)
	var actual := _to_coord(_dest)
	if absi(wanted.x - actual.x) + absi(wanted.y - actual.y) > 0:
		msg = "Đích bị chắn — đi tới %d/%d (gần %d/%d nhất)" % [actual.x, actual.y, wanted.x, wanted.y]
	return msg

func has_destination() -> bool:
	return _has_dest

func destination_feet() -> Vector2:
	return _dest

func get_map_texture() -> Texture2D:
	return _tex

func get_title() -> String:
	return _title

## Pixel ảnh mini map <-> pixel map (cùng hệ toạ độ với phần vẽ mini map nhỏ).
func world_to_image(world: Vector2) -> Vector2:
	return (world - _origin) / _img_scale

func image_to_world(p: Vector2) -> Vector2:
	return p * _img_scale + _origin

func feet_to_coord(feet: Vector2) -> Vector2i:
	return _to_coord(feet)

func coord_to_feet(c: Vector2i) -> Vector2:
	return _coord_to_world(c)

func player_feet() -> Vector2:
	return _feet()

func _open_map_panel() -> void:
	if get_tree().root.has_node("MapPanel"):
		return
	var panel := MapPanel.new()
	panel.name = "MapPanel"
	get_tree().root.add_child(panel)
	panel.setup(self, _player)

func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_label.visible = true
	_notice_time = 2.5

# ---------------------------------------------------------------- bản đồ

func _zoom() -> float:
	if _show_world and _tex != null:
		return minf(MAP_RECT.size.x / float(_tex.get_width()), MAP_RECT.size.y / float(_tex.get_height()))
	return ZOOMS[_zoom_index]

func _cycle_zoom() -> void:
	_show_world = false
	_zoom_index = (_zoom_index + 1) % ZOOMS.size()

func _toggle_world() -> void:
	_show_world = not _show_world

## Góc trên-trái của vùng ảnh đang xem (pixel ảnh): giữa là nhân vật, kẹp trong ảnh.
func _src_origin(zoom: float) -> Vector2:
	var view_img := MAP_RECT.size / zoom
	if _tex == null:
		return Vector2.ZERO
	var tex_size := Vector2(_tex.get_size())
	if _show_world or view_img.x >= tex_size.x:
		return (tex_size - view_img) * 0.5 if view_img.x >= tex_size.x else Vector2.ZERO
	var centre := (_feet() - _origin) / _img_scale
	return Vector2(
		clampf(centre.x - view_img.x * 0.5, 0.0, tex_size.x - view_img.x),
		clampf(centre.y - view_img.y * 0.5, 0.0, tex_size.y - view_img.y))

func _world_to_view(world: Vector2, zoom: float, src: Vector2) -> Vector2:
	return ((world - _origin) / _img_scale - src) * zoom

func _view_to_world(point: Vector2, zoom: float, src: Vector2) -> Vector2:
	return (point / zoom + src) * _img_scale + _origin

func _draw_view() -> void:
	var zoom := _zoom()
	var src := _src_origin(zoom)
	if _tex != null:
		var view_img := MAP_RECT.size / zoom
		var tex_size := Vector2(_tex.get_size())
		var draw_size := Vector2(minf(view_img.x, tex_size.x), minf(view_img.y, tex_size.y))
		## src có thể ÂM (ảnh nhỏ hơn khung, được căn giữa): khi đó ảnh phải vẽ lùi vào đúng phần âm đó, nếu không chấm/đích lệch khỏi ảnh.
		var pad := Vector2(maxf(-src.x, 0.0), maxf(-src.y, 0.0)) * zoom
		_view.draw_texture_rect_region(_tex, Rect2(pad, draw_size * zoom), Rect2(Vector2(maxf(src.x, 0.0), maxf(src.y, 0.0)), draw_size))
	else:
		_view.draw_rect(Rect2(Vector2.ZERO, MAP_RECT.size), Color(0.12, 0.14, 0.1))
	## Ô vuông màn chơi.
	if VltkWorld.has_arena():
		var r := VltkWorld.current.arena_rect
		var a := _world_to_view(r.position, zoom, src)
		var b := _world_to_view(r.end, zoom, src)
		_view.draw_rect(Rect2(a, b - a), Color(GOLD, 0.9), false, 1.0)
	## Đích đang đi tới.
	if _has_dest and _player != null and is_instance_valid(_player) and _player.is_moving_to_target():
		## Lộ trình còn lại: chấm vàng từ nhân vật theo các điểm tới đích, rồi cờ đỏ nhỏ ở đích.
		var pts: PackedVector2Array = [_world_to_view(_feet(), zoom, src)]
		for w in _player.get_route_feet():
			pts.append(_world_to_view(w, zoom, src))
		var carry := 0.0
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var length := a.distance_to(b)
			if length < 0.01:
				continue
			var dir := (b - a) / length
			var dist := ROUTE_DOT_GAP - carry
			while dist <= length:
				_view.draw_circle(a + dir * dist, 1.3, Color(1.0, 0.9, 0.15))
				dist += ROUTE_DOT_GAP
			carry = maxf(length - (dist - ROUTE_DOT_GAP), 0.0)
		var d := _world_to_view(_dest, zoom, src)
		_view.draw_line(d, d + Vector2(0, -9), Color(0.95, 0.95, 0.95), 1.2)
		_view.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -9), d + Vector2(6, -7), d + Vector2(0, -4)]), Color(0.9, 0.12, 0.1))
	## Người chơi = chấm VÀNG.
	if _player != null and is_instance_valid(_player):
		var p := _world_to_view(_feet(), zoom, src)
		_view.draw_circle(p, 3.6, Color.BLACK)
		_view.draw_circle(p, 2.6, Color(1.0, 0.86, 0.0))

func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var zoom := _zoom()
		_walk_to(_view_to_world(event.position, zoom, _src_origin(zoom)))
		accept_event()

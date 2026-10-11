extends Control
class_name ServerSelectScreen
## Màn Chọn Máy Chủ (sau Đăng Nhập). Bố cục theo mockup 1672x941; mọi thành phần là node trong Stage (kéo thả trong editor,
## Stage tự co theo cửa sổ). Danh sách máy chủ lấy từ server tài khoản (AccountApi.servers(), admin quản lý trên web Admin).
##   Chưa đăng nhập thì quay về màn Đăng Nhập. Góc phải trên: tên tài khoản. Nút Quay lại (góc trái dưới) = đăng xuất về màn Đăng Nhập.
##   - Cột trái lọc: Tất cả / Máy chủ mới / Đông vui / Miền Bắc / Miền Trung / Miền Nam.
##   - Máy chủ "Bảo trì" không vào được. Máy chủ đã chọn lưu vào user://login.cfg (mục server) để lần sau chọn sẵn.

const LOGIN_SCENE := "res://ui/login/Login.tscn"
const CFG_PATH := "user://login.cfg"
const NEXT_SCENE := "res://ui/character_roster/CharacterRoster.tscn"
const FADE := 0.35
const ROW_HEIGHT := 40.6

const FILTERS := [
	{"label": "Tất cả", "key": "all"}, {"label": "Máy chủ mới", "key": "new"}, {"label": "Đông vui", "key": "crowded"},
	{"label": "Miền Bắc", "key": "north"}, {"label": "Miền Trung", "key": "central"}, {"label": "Miền Nam", "key": "south"},
]
const STATUS := {
	"normal": {"text": "Bình thường", "color": Color(0.35, 0.95, 0.4)},
	"crowded": {"text": "Đông", "color": Color(0.95, 0.25, 0.22)},
	"maintenance": {"text": "Bảo trì", "color": Color(1.0, 0.85, 0.2)},
}
const GOLD := Color(0.93, 0.78, 0.4)
const TEXT := Color(0.93, 0.88, 0.78)

## Máy chủ đang chọn (id). Màn sau (Tạo nhân vật / game) đọc được từ đây.
static var selected_server_id := 1

@onready var _rows: VBoxContainer = %Rows
@onready var _filter_box: VBoxContainer = %Filters
@onready var _enter: TextureButton = %EnterButton
@onready var _message: Label = %Message
@onready var _account_label: Label = %AccountLabel
@onready var _back: TextureButton = %BackButton

var _servers: Array = []
var _filter := "all"
var _tween: Tween
var _row_buttons: Array[Button] = []
var _loading := false
var _filter_buttons: Array[Button] = []

func _ready() -> void:
	if not AccountApi.is_logged_in():
		get_tree().change_scene_to_file.call_deferred(LOGIN_SCENE)
		return
	_account_label.text = "Tài khoản: " + AccountApi.username()
	_back.pressed.connect(_on_back_pressed)
	_back.mouse_entered.connect(func() -> void: _back.pivot_offset = _back.size * 0.5; create_tween().tween_property(_back, "scale", Vector2.ONE * 1.05, 0.1))
	_back.mouse_exited.connect(func() -> void: create_tween().tween_property(_back, "scale", Vector2.ONE, 0.1))
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		selected_server_id = int(cfg.get_value("server", "id", selected_server_id))
	_build_filters()
	_enter.pressed.connect(_on_enter_pressed)
	_enter.mouse_entered.connect(_hover.bind(true))
	_enter.mouse_exited.connect(_hover.bind(false))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)
	_fetch_servers()

func _hover(on: bool) -> void:
	_enter.pivot_offset = _enter.size * 0.5
	create_tween().tween_property(_enter, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.1)

func _fetch_servers() -> void:
	if _loading:
		return
	_loading = true
	_servers = []
	_refresh_rows()
	var r: Dictionary = await AccountApi.servers()
	_loading = false
	if r.ok and r.data is Dictionary:
		_servers = r.data.get("servers", [])
	elif r.code == "unauthorized" or r.code == "banned":
		AccountScreen.next_login_message = r.message
		get_tree().change_scene_to_file(LOGIN_SCENE)
		return
	else:
		_toast(r.message + " — bấm Vào game để thử lại")
	_refresh_rows()

## Quay lại màn Đăng Nhập: đăng xuất luôn (nếu không, "Ghi nhớ đăng nhập" sẽ tự đưa vào lại màn này).
func _on_back_pressed() -> void:
	_back.disabled = true
	_enter.disabled = true
	await AccountApi.logout()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(get_tree().change_scene_to_file.bind(LOGIN_SCENE))

# ---------------------------------------------------------------- lọc

func _build_filters() -> void:
	for f in FILTERS:
		var b := Button.new()
		b.text = f["label"]
		b.custom_minimum_size = Vector2(148, 50)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_set_filter.bind(f["key"]))
		_filter_box.add_child(b)
		_filter_buttons.append(b)
	_style_filters()

func _set_filter(key: String) -> void:
	_filter = key
	_style_filters()
	_refresh_rows()

func _style_filters() -> void:
	for i in _filter_buttons.size():
		var on: bool = FILTERS[i]["key"] == _filter
		var b := _filter_buttons[i]
		var normal := _box(Color(0.5, 0.08, 0.06, 0.95) if on else Color(0.07, 0.055, 0.045, 0.92), GOLD if on else Color(0.45, 0.36, 0.2), 2 if on else 1)
		var hover := _box(Color(0.35, 0.1, 0.07, 0.95), GOLD, 2)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("focus", normal)
		b.add_theme_color_override("font_color", Color(1, 0.95, 0.85) if on else Color(0.85, 0.78, 0.65))

func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(width)
	s.border_color = border
	s.set_corner_radius_all(3)
	return s

func _matches(s: Dictionary) -> bool:
	match _filter:
		"new": return bool(s.get("is_new", false))
		"crowded": return str(s.get("status", "")) == "crowded"
		"north", "central", "south": return str(s.get("region", "")) == _filter
	return true

# ---------------------------------------------------------------- danh sách

func _refresh_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_row_buttons.clear()
	var shown := 0
	for s in _servers:
		if not _matches(s):
			continue
		_rows.add_child(_make_row(s))
		shown += 1
	if shown == 0:
		var l := Label.new()
		l.text = "Đang tải danh sách máy chủ…" if _loading else "Không có máy chủ nào"
		l.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
		l.add_theme_font_size_override("font_size", 18)
		l.custom_minimum_size = Vector2(550, 60)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rows.add_child(l)

func _make_row(s: Dictionary) -> Button:
	var id := int(s.get("id", 0))
	var selected := id == selected_server_id
	var b := Button.new()
	b.custom_minimum_size = Vector2(550, ROW_HEIGHT - 2.0)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := _box(Color(0.08, 0.065, 0.055, 0.85), GOLD if selected else Color(0.28, 0.22, 0.15), 2 if selected else 1)
	var hover := _box(Color(0.14, 0.1, 0.07, 0.9), GOLD, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.pressed.connect(_select.bind(id))
	b.set_meta("server_id", id)
	## Nhãn "Mới" (nền đỏ) bên trái.
	if bool(s.get("is_new", false)):
		var badge := Label.new()
		badge.text = "Mới"
		badge.position = Vector2(2, 3)
		badge.size = Vector2(36, 32)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 15)
		badge.add_theme_color_override("font_color", Color(1, 0.93, 0.8))
		badge.add_theme_stylebox_override("normal", _box(Color(0.7, 0.1, 0.08), Color(0.9, 0.35, 0.3), 1))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	b.add_child(_icon_swords())
	b.add_child(_label(str(s.get("name", "?")), 96, 200, TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var st: Dictionary = STATUS.get(str(s.get("status", "normal")), STATUS["normal"])
	b.add_child(_dot(st["color"]))
	b.add_child(_label(st["text"], 290, 150, st["color"], HORIZONTAL_ALIGNMENT_LEFT))
	var chars := int(s.get("characters", 0))
	b.add_child(_label(str(chars) if chars > 0 else "–", 440, 108, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_row_buttons.append(b)
	return b

func _label(text: String, x: float, w: float, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(x, 0)
	l.size = Vector2(w, ROW_HEIGHT - 2.0)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _dot(color: Color) -> Panel:
	var p := Panel.new()
	p.position = Vector2(262, 10)
	p.size = Vector2(18, 18)
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(9)
	s.set_border_width_all(1)
	s.border_color = color.darkened(0.5)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Biểu tượng 2 thanh kiếm chéo (vẽ tay, bản gốc không có ảnh rời).
func _icon_swords() -> Control:
	var c := _SwordsIcon.new()
	c.position = Vector2(62, 8)
	c.size = Vector2(22, 22)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

class _SwordsIcon extends Control:
	func _draw() -> void:
		var col := Color(0.8, 0.78, 0.72)
		draw_line(Vector2(3, 3), Vector2(19, 19), col, 2.2)
		draw_line(Vector2(19, 3), Vector2(3, 19), col, 2.2)
		draw_line(Vector2(2, 8), Vector2(8, 2), col, 2.2)
		draw_line(Vector2(20, 8), Vector2(14, 2), col, 2.2)

func _select(id: int) -> void:
	selected_server_id = id
	_refresh_rows()

# ---------------------------------------------------------------- vào game

func _on_enter_pressed() -> void:
	if _servers.is_empty():
		_fetch_servers()
		return
	var server := {}
	for s in _servers:
		if int(s.get("id", 0)) == selected_server_id:
			server = s
	if server.is_empty():
		_toast("Hãy chọn một máy chủ")
		return
	if str(server.get("status", "")) == "maintenance":
		_toast("Máy chủ %s đang bảo trì, vui lòng chọn máy chủ khác" % server.get("name", ""))
		return
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("server", "id", selected_server_id)
	cfg.save(CFG_PATH)
	_enter.disabled = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(get_tree().change_scene_to_file.bind(NEXT_SCENE))

func _toast(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(2.0)
	_tween.tween_property(_message, "modulate:a", 0.0, 0.4)

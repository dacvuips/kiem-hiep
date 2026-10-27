extends Control
class_name ServerSelectScreen

const TouchScrollHelperScript = preload("res://ui/common/touch_scroll_helper.gd")
## Màn Chọn Máy Chủ (sau Đăng Nhập). Bố cục chuẩn theo mockup 1280x720:
## Khung ngọc viền vàng, 4 danh mục bên trái, danh sách server bo tròn bên phải,
## chú thích trạng thái (Mượt, Đông, Đầy, Bảo trì) và nút "Vào Game" phát sáng.

const LOGIN_SCENE := "res://ui/login/Login.tscn"
const CFG_PATH := "user://login.cfg"
const NEXT_SCENE := "res://ui/character_roster/CharacterRoster.tscn"
const FADE := 0.35
const ROW_HEIGHT := 48.0

const FILTERS := [
	{"label": "Tất Cả", "key": "all"},
	{"label": "Server Mới", "key": "new"},
	{"label": "Server Đề Cử", "key": "crowded"},
	{"label": "Server Thường", "key": "normal"},
]

const STATUS := {
	"normal": {"text": "Mượt", "color": Color(0.18, 0.95, 0.38)},
	"smooth": {"text": "Mượt", "color": Color(0.18, 0.95, 0.38)},
	"crowded": {"text": "Đông", "color": Color(0.98, 0.82, 0.15)},
	"full": {"text": "Đầy", "color": Color(0.95, 0.22, 0.22)},
	"maintenance": {"text": "Bảo trì", "color": Color(0.65, 0.68, 0.72)},
}

const MOCK_SERVERS := [
	{"id": 1, "name": "S1 - Sơn Hà", "status": "crowded", "is_new": true, "characters": 1},
	{"id": 2, "name": "S2 - Thái Sơn", "status": "normal", "is_new": true, "characters": 0},
	{"id": 3, "name": "S3 - Trường Giang", "status": "normal", "is_new": false, "characters": 0},
	{"id": 4, "name": "S4 - Kim Lăng", "status": "full", "is_new": false, "characters": 2},
	{"id": 5, "name": "S5 - Hoa Sơn", "status": "maintenance", "is_new": false, "characters": 0},
]

const GOLD := Color(0.98, 0.86, 0.52)
const GOLD_BORDER := Color(0.96, 0.82, 0.45)
const TEXT_COLOR := Color(0.96, 0.96, 0.96)

## Máy chủ đang chọn (id). Màn sau (Tạo nhân vật / game) đọc được từ đây.
static var selected_server_id := 1
## Bản ghi máy chủ đã chọn (host, port, ws_url...) — NetClient dùng để kết nối game server.
static var selected_server: Dictionary = {}

@onready var _rows: VBoxContainer = %Rows
@onready var _filter_box: VBoxContainer = %Filters
@onready var _enter: TextureButton = %EnterButton
@onready var _message: Label = %Message
@onready var _account_label: Label = %AccountLabel
@onready var _back: Button = %BackButton

var _servers: Array = []
var _filter := "all"
var _tween: Tween
var _row_buttons: Array[Button] = []
var _loading := false
var _filter_buttons: Array[Button] = []

func _ready() -> void:
	if not AccountApi.is_logged_in():
		if OS.has_feature("editor") or OS.is_debug_build():
			_account_label.text = "Tài khoản: Khách (Thử nghiệm)"
			_servers = MOCK_SERVERS.duplicate(true)
		else:
			get_tree().change_scene_to_file.call_deferred(LOGIN_SCENE)
			return
	else:
		_account_label.text = "Tài khoản: " + AccountApi.username()

	_back.pressed.connect(_on_back_pressed)
	_back.mouse_entered.connect(func() -> void:
		_back.pivot_offset = _back.size * 0.5
		create_tween().tween_property(_back, "scale", Vector2.ONE * 1.05, 0.1)
	)
	_back.mouse_exited.connect(func() -> void:
		create_tween().tween_property(_back, "scale", Vector2.ONE, 0.1)
	)

	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		selected_server_id = int(cfg.get_value("server", "id", selected_server_id))

	_build_filters()
	var scroll_rows := get_node_or_null("Stage/ScrollRows") as ScrollContainer
	if scroll_rows:
		TouchScrollHelperScript.attach(scroll_rows, scroll_rows)
	_enter.pressed.connect(_on_enter_pressed)
	_enter.mouse_entered.connect(_hover.bind(true))
	_enter.mouse_exited.connect(_hover.bind(false))
	_enter.button_down.connect(_set_enter_pressed.bind(true))
	_enter.button_up.connect(_set_enter_pressed.bind(false))

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)

	if AccountApi.is_logged_in():
		_fetch_servers()
		if AccountApi.has_signal("session_invalidated"):
			AccountApi.session_invalidated.connect(_on_session_invalidated)
	else:
		_refresh_rows()

var _session_poll_timer := 0.0
const SESSION_POLL_INTERVAL := 5.0

func _process(delta: float) -> void:
	if not AccountApi.is_logged_in() or _loading:
		return
	_session_poll_timer += delta
	if _session_poll_timer >= SESSION_POLL_INTERVAL:
		_session_poll_timer = 0.0
		_poll_session()

func _poll_session() -> void:
	var chk: Dictionary = await AccountApi.check_session()
	if not is_inside_tree():
		return
	if not chk.ok and chk.code in ["logged_in_elsewhere", "unauthorized", "banned"]:
		_on_session_invalidated(chk.message)

func _on_session_invalidated(reason: String) -> void:
	AccountScreen.next_login_message = reason if reason != "" else "Tài khoản vừa đăng nhập ở thiết bị khác"
	get_tree().change_scene_to_file(LOGIN_SCENE)

func _hover(on: bool) -> void:
	_enter.pivot_offset = _enter.size * 0.5
	create_tween().tween_property(_enter, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.1)
	if _enter.material is ShaderMaterial:
		(_enter.material as ShaderMaterial).set_shader_parameter("hover_boost", 0.4 if on else 0.0)

func _set_enter_pressed(down: bool) -> void:
	if _enter.material is ShaderMaterial:
		(_enter.material as ShaderMaterial).set_shader_parameter("is_pressed", 1.0 if down else 0.0)

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
	elif r.code in ["unauthorized", "banned", "logged_in_elsewhere"]:
		AccountScreen.next_login_message = r.message
		get_tree().change_scene_to_file(LOGIN_SCENE)
		return
	else:
		_servers = MOCK_SERVERS.duplicate(true)
		_toast(r.message + " — tải danh sách tạm")
	_refresh_rows()

## Quay lại màn Đăng Nhập: đăng xuất luôn
func _on_back_pressed() -> void:
	_back.disabled = true
	_enter.disabled = true
	if _enter.material is ShaderMaterial:
		(_enter.material as ShaderMaterial).set_shader_parameter("is_disabled", 1.0)
	if AccountApi.is_logged_in():
		await AccountApi.logout()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(get_tree().change_scene_to_file.bind(LOGIN_SCENE))

# ---------------------------------------------------------------- Lọc danh mục

func _build_filters() -> void:
	for c in _filter_box.get_children():
		c.queue_free()
	_filter_buttons.clear()

	for f in FILTERS:
		var b := Button.new()
		b.text = f["label"]
		b.custom_minimum_size = Vector2(140, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 16)
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
		if on:
			var normal := StyleBoxFlat.new()
			normal.bg_color = Color(0.85, 0.52, 0.08, 0.85)
			normal.set_border_width_all(2)
			normal.border_color = GOLD_BORDER
			normal.set_corner_radius_all(10)
			normal.shadow_color = Color(0.9, 0.6, 0.1, 0.4)
			normal.shadow_size = 4

			var hover := StyleBoxFlat.new()
			hover.bg_color = Color(0.95, 0.6, 0.12, 0.9)
			hover.set_border_width_all(2)
			hover.border_color = Color(1.0, 0.92, 0.65)
			hover.set_corner_radius_all(10)

			b.add_theme_stylebox_override("normal", normal)
			b.add_theme_stylebox_override("hover", hover)
			b.add_theme_stylebox_override("pressed", hover)
			b.add_theme_stylebox_override("focus", normal)
			b.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			var normal := StyleBoxFlat.new()
			normal.bg_color = Color(0.06, 0.16, 0.18, 0.55)
			normal.set_border_width_all(1)
			normal.border_color = Color(0.25, 0.42, 0.45, 0.6)
			normal.set_corner_radius_all(10)

			var hover := StyleBoxFlat.new()
			hover.bg_color = Color(0.1, 0.24, 0.26, 0.7)
			hover.set_border_width_all(1)
			hover.border_color = GOLD_BORDER
			hover.set_corner_radius_all(10)

			b.add_theme_stylebox_override("normal", normal)
			b.add_theme_stylebox_override("hover", hover)
			b.add_theme_stylebox_override("pressed", hover)
			b.add_theme_stylebox_override("focus", normal)
			b.add_theme_color_override("font_color", Color(0.78, 0.88, 0.86))

func _matches(s: Dictionary) -> bool:
	match _filter:
		"new":
			return bool(s.get("is_new", false))
		"crowded":
			return str(s.get("status", "")) == "crowded" or bool(s.get("is_recommended", false))
		"normal":
			return str(s.get("status", "")) == "normal" or str(s.get("status", "")) == "smooth"
	return true

# ---------------------------------------------------------------- Danh sách Server

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
		l.text = "Đang tải danh sách server…" if _loading else "Không có server nào"
		l.add_theme_color_override("font_color", Color(0.6, 0.7, 0.68))
		l.add_theme_font_size_override("font_size", 16)
		l.custom_minimum_size = Vector2(440, 60)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rows.add_child(l)

func _make_row(s: Dictionary) -> Button:
	var id := int(s.get("id", 0))
	var selected := id == selected_server_id
	var b := Button.new()
	b.custom_minimum_size = Vector2(440, ROW_HEIGHT)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.28, 0.3, 0.65) if selected else Color(0.06, 0.16, 0.18, 0.45)
	normal.set_border_width_all(2 if selected else 1)
	normal.border_color = GOLD_BORDER if selected else Color(0.2, 0.38, 0.4, 0.5)
	normal.set_corner_radius_all(10)
	if selected:
		normal.shadow_color = Color(0.96, 0.82, 0.45, 0.35)
		normal.shadow_size = 4

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.1, 0.24, 0.26, 0.6)
	hover.set_border_width_all(1)
	hover.border_color = GOLD_BORDER
	hover.set_corner_radius_all(10)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.pressed.connect(_select.bind(id))
	b.set_meta("server_id", id)

	var st_key := str(s.get("status", "normal"))
	var st: Dictionary = STATUS.get(st_key, STATUS["normal"])

	# Chấm tròn trạng thái bên trái
	var dot := Panel.new()
	dot.position = Vector2(16, 17)
	dot.size = Vector2(14, 14)
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = st["color"]
	dot_style.set_corner_radius_all(7)
	dot_style.set_border_width_all(1)
	dot_style.border_color = Color(1, 1, 1, 0.6)
	dot.add_theme_stylebox_override("panel", dot_style)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(dot)

	# Tên máy chủ (vd: S1 - Sơn Hà)
	var lbl := Label.new()
	lbl.text = str(s.get("name", "Máy chủ"))
	lbl.position = Vector2(40, 0)
	lbl.size = Vector2(250, ROW_HEIGHT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lbl)

	# Bên phải: Huy hiệu [Mới] hoặc nhãn trạng thái (Đông, Đầy, ...)
	if bool(s.get("is_new", false)):
		var badge := Label.new()
		badge.text = "Mới"
		badge.position = Vector2(360, 11)
		badge.size = Vector2(56, 26)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color(1, 1, 1))

		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.88, 0.16, 0.16, 0.95)
		bs.set_border_width_all(1)
		bs.border_color = Color(1.0, 0.5, 0.5, 0.8)
		bs.set_corner_radius_all(12)
		badge.add_theme_stylebox_override("normal", bs)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	else:
		var st_lbl := Label.new()
		st_lbl.text = st["text"]
		st_lbl.position = Vector2(330, 0)
		st_lbl.size = Vector2(90, ROW_HEIGHT)
		st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		st_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		st_lbl.add_theme_font_size_override("font_size", 14)
		st_lbl.add_theme_color_override("font_color", st["color"])
		st_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(st_lbl)

	_row_buttons.append(b)
	return b

func _select(id: int) -> void:
	selected_server_id = id
	_refresh_rows()

# ---------------------------------------------------------------- Vào game

func _on_enter_pressed() -> void:
	if _servers.is_empty():
		_fetch_servers()
		return
	var server := {}
	for s in _servers:
		if int(s.get("id", 0)) == selected_server_id:
			server = s
			break
	if server.is_empty():
		_toast("Hãy chọn một máy chủ")
		return
	if str(server.get("status", "")) == "maintenance":
		_toast("Máy chủ %s đang bảo trì, vui lòng chọn máy chủ khác" % server.get("name", ""))
		return

	# Kiểm tra xác thực phiên đăng nhập trước khi cho phép vào bên trong
	if AccountApi.is_logged_in():
		_enter.disabled = true
		var chk: Dictionary = await AccountApi.check_session()
		if not is_inside_tree():
			return
		if not chk.ok:
			_enter.disabled = false
			AccountScreen.next_login_message = chk.message if chk.message != "" else "Tài khoản vừa đăng nhập ở thiết bị khác"
			get_tree().change_scene_to_file(LOGIN_SCENE)
			return

	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("server", "id", selected_server_id)
	cfg.save(CFG_PATH)
	selected_server = server
	_enter.disabled = true
	if _enter.material is ShaderMaterial:
		(_enter.material as ShaderMaterial).set_shader_parameter("is_disabled", 1.0)

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

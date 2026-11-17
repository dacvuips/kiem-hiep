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
	{"label": "Đồ Xanh", "key": "doxanh"},
	{"label": "Đồ Tím", "key": "dotim"},
	{"label": "Siêu Nhân", "key": "sieunhan"},
]

const STATUS := {
	"normal": {"text": "Mượt", "color": Color(0.18, 0.95, 0.38)},
	"smooth": {"text": "Mượt", "color": Color(0.18, 0.95, 0.38)},
	"crowded": {"text": "Đông", "color": Color(0.98, 0.82, 0.15)},
	"full": {"text": "Đầy", "color": Color(0.95, 0.22, 0.22)},
	"maintenance": {"text": "Bảo trì", "color": Color(0.65, 0.68, 0.72)},
}

const MOCK_SERVERS := [
	{"id": 1, "name": "Tuyết Sơn (Đồ Xanh)", "status": "normal", "is_new": true, "characters": 0, "type": "doxanh"},
	{"id": 2, "name": "Hoa Sơn (Đồ Tím)", "status": "crowded", "is_new": false, "characters": 0, "type": "dotim"},
	{"id": 3, "name": "Thái Sơn (Siêu Nhân)", "status": "normal", "is_new": false, "characters": 0, "type": "sieunhan"},
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
var _has_error := false
var _error_message := ""
var _retry_countdown := 0.0
const RETRY_INTERVAL := 5.0
var _retry_label: Label = null
var _refresh_btn: Button = null
var _filter_buttons: Array[Button] = []

func _get_account_api() -> Node:
	return get_node_or_null("/root/AccountApi")

func _ready() -> void:
	var music_mgr: Node = get_node_or_null("/root/MusicManager")
	if music_mgr:
		if music_mgr.has_method("play_title_music"):
			music_mgr.play_title_music()
		elif music_mgr.has_method("play"):
			music_mgr.play("music001.mp3")
	_update_account_label()

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

	# Nút làm mới danh sách máy chủ
	_setup_refresh_button()

	_update_locale_texts()
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		loc_mgr.locale_changed.connect(func(_l: String) -> void:
			_update_locale_texts()
			_build_filters()
			_refresh_rows()
		)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)

	_update_enter_button_state()

	var api := _get_account_api()
	if api != null and api.is_logged_in():
		_fetch_servers()
		if api.has_signal("session_invalidated"):
			api.session_invalidated.connect(_on_session_invalidated)
	else:
		_fetch_servers()

func _setup_refresh_button() -> void:
	var stage := get_node_or_null("Stage")
	if stage == null:
		return
	_refresh_btn = Button.new()
	_refresh_btn.text = "🔄 " + tr("Làm mới")
	_refresh_btn.position = Vector2(856, 92)
	_refresh_btn.custom_minimum_size = Vector2(96, 30)
	_refresh_btn.focus_mode = Control.FOCUS_NONE
	_refresh_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_refresh_btn.add_theme_font_size_override("font_size", 12)
	_refresh_btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.22, 0.25, 0.8)
	st.set_border_width_all(1)
	st.border_color = Color(0.85, 0.72, 0.45, 0.6)
	st.set_corner_radius_all(6)
	_refresh_btn.add_theme_stylebox_override("normal", st)

	var st_h := st.duplicate() as StyleBoxFlat
	st_h.bg_color = Color(0.14, 0.35, 0.38, 0.95)
	st_h.border_color = GOLD_BORDER
	_refresh_btn.add_theme_stylebox_override("hover", st_h)
	_refresh_btn.add_theme_stylebox_override("pressed", st_h)
	_refresh_btn.pressed.connect(func() -> void:
		_retry_countdown = RETRY_INTERVAL
		_fetch_servers()
	)
	stage.add_child(_refresh_btn)

func _update_account_label() -> void:
	if not is_instance_valid(_account_label):
		return
	var api := _get_account_api()
	if api == null or not api.is_logged_in():
		if OS.has_feature("editor") or OS.is_debug_build():
			_account_label.text = tr("Tài khoản: Khách (Thử nghiệm)")
		else:
			get_tree().change_scene_to_file.call_deferred(LOGIN_SCENE)
			return
	else:
		_account_label.text = tr("Tài khoản: ") + api.username()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_inside_tree() and is_node_ready():
			_update_locale_texts()
			_build_filters()
			_refresh_rows()

func _update_locale_texts() -> void:
	if not is_inside_tree() or not is_node_ready():
		return
	_update_account_label()
	var title_lbl: Label = get_node_or_null("Stage/Title")
	if title_lbl:
		title_lbl.text = tr("Chọn Server")
	var l_green: Label = get_node_or_null("Stage/Legend/LegGreen/Lbl")
	if l_green:
		l_green.text = tr("Mượt")
	var l_yellow: Label = get_node_or_null("Stage/Legend/LegYellow/Lbl")
	if l_yellow:
		l_yellow.text = tr("Đông")
	var l_red: Label = get_node_or_null("Stage/Legend/LegRed/Lbl")
	if l_red:
		l_red.text = tr("Đầy")
	var l_gray: Label = get_node_or_null("Stage/Legend/LegGray/Lbl")
	if l_gray:
		l_gray.text = tr("Bảo trì")
	var enter_lbl: Label = get_node_or_null("Stage/EnterButton/EnterLabel")
	if enter_lbl:
		enter_lbl.text = tr("Vào Game")
	if _back:
		_back.text = tr("Đổi tài khoản")

var _session_poll_timer := 0.0
const SESSION_POLL_INTERVAL := 5.0

func _process(delta: float) -> void:
	if _has_error and not _loading:
		_retry_countdown -= delta
		if is_instance_valid(_retry_label):
			_retry_label.text = tr("Tự động thử lại sau %d giây…") % max(1, int(ceil(_retry_countdown)))
		if _retry_countdown <= 0.0:
			_retry_countdown = RETRY_INTERVAL
			_fetch_servers()
		return

	var api := _get_account_api()
	if api == null or not api.is_logged_in() or _loading:
		return
	_session_poll_timer += delta
	if _session_poll_timer >= SESSION_POLL_INTERVAL:
		_session_poll_timer = 0.0
		_poll_session()

func _poll_session() -> void:
	var api := _get_account_api()
	if api == null or not api.has_method("check_session"):
		return
	var chk: Dictionary = await api.check_session()
	if not is_inside_tree():
		return
	if not chk.ok and chk.code in ["logged_in_elsewhere", "unauthorized", "banned"]:
		_on_session_invalidated(chk.message)

func _on_session_invalidated(reason: String) -> void:
	AccountScreen.next_login_message = reason if reason != "" else "Tài khoản vừa đăng nhập ở thiết bị khác"
	get_tree().change_scene_to_file(LOGIN_SCENE)

func _hover(on: bool) -> void:
	if _enter.disabled:
		return
	_enter.pivot_offset = _enter.size * 0.5
	create_tween().tween_property(_enter, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.1)
	if _enter.material is ShaderMaterial:
		(_enter.material as ShaderMaterial).set_shader_parameter("hover_boost", 0.4 if on else 0.0)

func _set_enter_pressed(down: bool) -> void:
	if _enter.material is ShaderMaterial:
		(_enter.material as ShaderMaterial).set_shader_parameter("is_pressed", 1.0 if down else 0.0)

func _update_enter_button_state() -> void:
	if not is_instance_valid(_enter):
		return
	var can_enter := not _loading and not _has_error and not _servers.is_empty()
	_enter.disabled = not can_enter
	if _enter.material is ShaderMaterial:
		(_enter.material as ShaderMaterial).set_shader_parameter("is_disabled", 0.0 if can_enter else 1.0)

func _fetch_servers() -> void:
	if _loading:
		return
	_loading = true
	_retry_countdown = RETRY_INTERVAL
	_update_enter_button_state()
	_refresh_rows()

	var api := _get_account_api()
	var r: Dictionary = await api.servers() if api != null else {"ok": false, "code": "no_api", "message": "Không thể kết nối đến máy chủ"}
	_loading = false

	if r.ok and r.data is Dictionary:
		_has_error = false
		_error_message = ""
		_servers = r.data.get("servers", [])
		for s_item in _servers:
			if s_item is Dictionary:
				var nm: String = str(s_item.get("name", ""))
				var nm_lower := nm.to_lower()
				if "tong kim" in nm_lower or "tống kim" in nm_lower or "tongkim" in nm_lower:
					s_item["name"] = "Tuyết Sơn"
		if not _servers.is_empty():
			var found := false
			for s in _servers:
				if int(s.get("id", 0)) == selected_server_id:
					found = true
					break
			if not found:
				selected_server_id = int(_servers[0].get("id", 1))
	elif r.code in ["unauthorized", "banned", "logged_in_elsewhere"]:
		AccountScreen.next_login_message = r.message
		get_tree().change_scene_to_file.call_deferred(LOGIN_SCENE)
		return
	else:
		# Mất kết nối / không tải được server: KHÔNG mockup, giữ danh sách rỗng và chờ refresh
		_servers = []
		_has_error = true
		_error_message = r.message if str(r.get("message", "")) != "" else tr("Máy chủ không phản hồi, vui lòng thử lại")
		_toast(_error_message)

	_update_enter_button_state()
	_refresh_rows()

## Quay lại màn Đăng Nhập: đăng xuất luôn
func _on_back_pressed() -> void:
	_back.disabled = true
	_enter.disabled = true
	if _enter.material is ShaderMaterial:
		(_enter.material as ShaderMaterial).set_shader_parameter("is_disabled", 1.0)
	var api := _get_account_api()
	if api != null and api.is_logged_in():
		await api.logout()
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
		b.text = tr(f["label"])
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
		var f_key: String = FILTERS[i]["key"]
		var on: bool = (f_key == _filter) \
			or (f_key == "doxanh" and _filter == "new") \
			or (f_key == "dotim" and _filter == "crowded") \
			or (f_key == "sieunhan" and _filter == "normal")
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
	var s_type := str(s.get("type", "")).to_lower()
	var s_name := str(s.get("name", "")).to_lower()
	match _filter:
		"doxanh", "new":
			if s_type == "dotim" or s_type == "sieunhan" or "tím" in s_name or "siêu nhân" in s_name or "sieu nhan" in s_name:
				return false
			if s_type == "doxanh" or "xanh" in s_name or bool(s.get("is_new", false)) or "tuyết sơn" in s_name:
				return true
			return _servers.size() == 1
		"dotim", "crowded":
			if s_type == "doxanh" or s_type == "sieunhan" or "xanh" in s_name or "siêu nhân" in s_name or "sieu nhan" in s_name:
				return false
			if s_type == "dotim" or "tím" in s_name or "tim" in s_name:
				return true
			if str(s.get("status", "")) == "crowded" or bool(s.get("is_recommended", false)):
				return true
			return false
		"sieunhan", "normal":
			if s_type == "doxanh" or s_type == "dotim" or "xanh" in s_name or "tím" in s_name:
				return false
			if s_type == "sieunhan" or "siêu nhân" in s_name or "sieu nhan" in s_name or "sn" in s_name:
				return true
			return str(s.get("status", "")) in ["normal", "smooth", "crowded"]
	return true

# ---------------------------------------------------------------- Danh sách Server

func _refresh_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_row_buttons.clear()
	_retry_label = null

	if _loading:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(440, 200)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 10)

		var l := Label.new()
		l.text = tr("⏳ Đang kết nối máy chủ…")
		l.add_theme_color_override("font_color", GOLD)
		l.add_theme_font_size_override("font_size", 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)

		var sub := Label.new()
		sub.text = tr("Vui lòng chờ trong giây lát")
		sub.add_theme_color_override("font_color", Color(0.7, 0.82, 0.8))
		sub.add_theme_font_size_override("font_size", 14)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)

		_rows.add_child(box)
		return

	if _has_error:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(440, 220)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 10)

		var icon_lbl := Label.new()
		icon_lbl.text = "⚠️"
		icon_lbl.add_theme_font_size_override("font_size", 26)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(icon_lbl)

		var msg_lbl := Label.new()
		msg_lbl.text = _error_message
		msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg_lbl.custom_minimum_size = Vector2(400, 0)
		msg_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		msg_lbl.add_theme_font_size_override("font_size", 15)
		msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(msg_lbl)

		_retry_label = Label.new()
		_retry_label.text = tr("Tự động thử lại sau %d giây…") % max(1, int(ceil(_retry_countdown)))
		_retry_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		_retry_label.add_theme_font_size_override("font_size", 13)
		_retry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_retry_label)

		var btn_retry := Button.new()
		btn_retry.text = tr("🔄 Thử Lại Ngay")
		btn_retry.custom_minimum_size = Vector2(160, 38)
		btn_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_retry.focus_mode = Control.FOCUS_NONE
		btn_retry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn_retry.add_theme_font_size_override("font_size", 14)

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.18, 0.4, 0.35, 0.85)
		btn_style.set_border_width_all(1)
		btn_style.border_color = GOLD_BORDER
		btn_style.set_corner_radius_all(8)
		btn_retry.add_theme_stylebox_override("normal", btn_style)

		var btn_hover := btn_style.duplicate() as StyleBoxFlat
		btn_hover.bg_color = Color(0.24, 0.52, 0.46, 0.95)
		btn_hover.border_color = Color(1.0, 0.95, 0.7)
		btn_retry.add_theme_stylebox_override("hover", btn_hover)
		btn_retry.add_theme_stylebox_override("pressed", btn_hover)
		btn_retry.pressed.connect(func() -> void:
			_retry_countdown = RETRY_INTERVAL
			_fetch_servers()
		)
		box.add_child(btn_retry)

		_rows.add_child(box)
		return

	var shown := 0
	for s in _servers:
		if not _matches(s):
			continue
		_rows.add_child(_make_row(s))
		shown += 1
	if shown == 0:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(440, 160)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 10)

		var l := Label.new()
		l.text = tr("Không có máy chủ nào phù hợp bộ lọc")
		l.add_theme_color_override("font_color", Color(0.6, 0.7, 0.68))
		l.add_theme_font_size_override("font_size", 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)

		var btn_ref := Button.new()
		btn_ref.text = tr("🔄 Tải lại")
		btn_ref.custom_minimum_size = Vector2(120, 32)
		btn_ref.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_ref.focus_mode = Control.FOCUS_NONE
		btn_ref.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn_ref.pressed.connect(func() -> void: _fetch_servers())
		box.add_child(btn_ref)

		_rows.add_child(box)

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

	# Tên máy chủ (vd: S1 - Tuyết Sơn)
	var lbl := Label.new()
	var s_name := str(s.get("name", "Máy chủ"))
	var s_lower := s_name.to_lower()
	if "tong kim" in s_lower or "tống kim" in s_lower or "tongkim" in s_lower:
		s_name = "Tuyết Sơn"
	lbl.text = s_name
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
		badge.text = tr("Mới")
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
		st_lbl.text = tr(st["text"])
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
	if _servers.is_empty() or _has_error or _loading:
		_toast(tr("Chưa kết nối được máy chủ, vui lòng đợi…"))
		_fetch_servers()
		return
	var server := {}
	for s in _servers:
		if int(s.get("id", 0)) == selected_server_id:
			server = s
			break
	if server.is_empty():
		_toast(tr("Hãy chọn một máy chủ"))
		return
	if str(server.get("status", "")) == "maintenance":
		_toast(tr("Máy chủ %s đang bảo trì, vui lòng chọn máy chủ khác") % server.get("name", ""))
		return

	# Kiểm tra xác thực phiên đăng nhập trước khi cho phép vào bên trong
	var api := _get_account_api()
	if api != null and api.is_logged_in() and api.has_method("check_session"):
		_enter.disabled = true
		var chk: Dictionary = await api.check_session()
		if not is_inside_tree():
			return
		if not chk.ok:
			_enter.disabled = false
			AccountScreen.next_login_message = chk.message if chk.message != "" else tr("Tài khoản vừa đăng nhập ở thiết bị khác")
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

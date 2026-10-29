extends Control
class_name AccountScreen
## Phần chung của các màn tài khoản (Đăng nhập, Tạo tài khoản, Quên mật khẩu): hiện dần khi mở, mờ dần khi chuyển màn,
## dòng thông báo, phóng to nút khi rê chuột, khóa nút trong lúc chờ server, nút Hiện/Ẩn mật khẩu.
## Mọi thành phần vẫn là node trong scene (Stage toạ độ mockup 1672x941) để kéo thả chỉnh trong editor.

const LOGIN_SCENE := "res://ui/login/Login.tscn"
const REGISTER_SCENE := "res://ui/account/Register.tscn"
const FORGOT_SCENE := "res://ui/account/ForgotPassword.tscn"
const AFTER_LOGIN_SCENE := "res://ui/server_select/ServerSelect.tscn"
const MODE_SELECT_SCENE := "res://ui/mode_select/ModeSelect.tscn"
const FADE := 0.35

const MIN_USERNAME := 3
const MAX_USERNAME := 20
const MIN_PASSWORD := 6
const MAX_PASSWORD := 64

const EYE_OPEN: Texture2D = preload("res://ui/login/icon_eye.png")
static var _eye_closed_tex: Texture2D

static func _get_eye_closed() -> Texture2D:
	if _eye_closed_tex:
		return _eye_closed_tex
	if ResourceLoader.exists("res://ui/login/icon_eye_closed.png"):
		var res = load("res://ui/login/icon_eye_closed.png")
		if res is Texture2D:
			_eye_closed_tex = res
			return _eye_closed_tex
	var img := Image.load_from_file("res://ui/login/icon_eye_closed.png")
	if img and not img.is_empty():
		_eye_closed_tex = ImageTexture.create_from_image(img)
		return _eye_closed_tex
	return EYE_OPEN

## Chuyển dữ liệu sang màn Đăng nhập khi quay về (VD đặt lại mật khẩu xong: điền sẵn tên + báo thành công).
static var next_login_username := ""
static var next_login_message := ""

var _toast_tween: Tween
var _busy := false

## Gọi trong _ready() của màn con.
func _setup_screen() -> void:
	MusicManager.play_title_music()
	_reload_input_icons()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)

func _reload_input_icons() -> void:
	var user_tex: ImageTexture
	var lock_tex: ImageTexture

	var get_user_tex := func() -> ImageTexture:
		if not user_tex:
			var img := Image.load_from_file("res://ui/login/icon_user.png")
			if img and not img.is_empty():
				user_tex = ImageTexture.create_from_image(img)
		return user_tex

	var get_lock_tex := func() -> ImageTexture:
		if not lock_tex:
			var img := Image.load_from_file("res://ui/login/icon_lock.png")
			if img and not img.is_empty():
				lock_tex = ImageTexture.create_from_image(img)
		return lock_tex

	for node in find_children("*", "TextureRect", true, false):
		var tr := node as TextureRect
		if tr == null:
			continue
		var n := tr.name.to_lower()
		var p := tr.texture.resource_path if tr.texture else ""
		if "user" in n or "email" in n or "icon_user" in p:
			var t: ImageTexture = get_user_tex.call()
			if t:
				tr.texture = t
		elif "lock" in n or "icon_lock" in p:
			var t: ImageTexture = get_lock_tex.call()
			if t:
				tr.texture = t

func _go(scene: String) -> void:
	set_process_input(false)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(func() -> void:
		var err := get_tree().change_scene_to_file(scene)
		if err != OK:
			push_error("Lỗi chuyển cảnh sang %s: mã lỗi %d" % [scene, err])
			set_process_input(true)
			modulate.a = 1.0
			if has_node("%Message"):
				var msg = get_node("%Message")
				if msg is Label:
					_toast(msg, "Lỗi chuyển cảnh (mã %d)" % err, 4.0)
	)

func _bind_hover(b: BaseButton) -> void:
	b.mouse_entered.connect(_hover.bind(b, true))
	b.mouse_exited.connect(_hover.bind(b, false))

func _hover(b: Control, on: bool) -> void:
	b.pivot_offset = b.size * 0.5
	create_tween().tween_property(b, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.1)

## Nút Hiện/Ẩn cho ô mật khẩu (có thể dùng 1 nút cho nhiều ô).
func _bind_eye(eye: Button, fields: Array[LineEdit]) -> void:
	var update_visual := func() -> void:
		var is_revealed: bool = not fields[0].secret if fields.size() > 0 else false
		if eye.icon != null:
			eye.text = ""
			eye.icon = _get_eye_closed() if is_revealed else EYE_OPEN
		else:
			eye.text = "Ẩn" if is_revealed else "Hiện"

	update_visual.call()
	eye.pressed.connect(func() -> void:
		var next_secret := not fields[0].secret
		for f in fields:
			f.secret = next_secret
		update_visual.call()
	)

## Khóa/mở các nút trong lúc chờ server, tránh bấm 2 lần.
func _set_busy(on: bool, buttons: Array) -> void:
	_busy = on
	for b: BaseButton in buttons:
		b.disabled = on
		b.modulate.a = 0.6 if on else 1.0

func _toast(label: Label, text: String, seconds := 2.6) -> void:
	label.text = tr(text)
	label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(label, "modulate:a", 0.0, 0.4)

## Kiểm tra xem có đang chạy trên thiết bị cảm ứng / điện thoại (kể cả Web di động) hay không.
static func is_touch_or_mobile() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		var js_check = JavaScriptBridge.eval(
			"('ontouchstart' in window || navigator.maxTouchPoints > 0) && /Android|iPhone|iPad|iPod|webOS|BlackBerry/i.test(navigator.userAgent)"
		)
		if js_check != null and bool(js_check):
			return true
	return false

static var _active_web_input: LineEdit = null
static var _web_cb_ref = null

## Thiết lập hỗ trợ nhập liệu mượt mà trên Web Mobile qua hộp thoại Native
static func setup_mobile_web_input(line_edit: LineEdit, title: String) -> void:
	if not OS.has_feature("web"):
		return
	if not is_touch_or_mobile():
		return
	if line_edit == null:
		return

	_ensure_web_callback()

	line_edit.focus_entered.connect(func() -> void:
		_trigger_web_input(line_edit, title)
	)
	line_edit.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			_trigger_web_input(line_edit, title)
	)

static func _trigger_web_input(line_edit: LineEdit, title: String) -> void:
	if line_edit == null or not is_instance_valid(line_edit):
		return
	_active_web_input = line_edit
	var is_pwd: bool = line_edit.secret
	var cur_val: String = line_edit.text
	var js: String = "if(window.openMobileInput){window.openMobileInput(%s, %s, %s);}" % [
		JSON.stringify(title),
		JSON.stringify(cur_val),
		"true" if is_pwd else "false"
	]
	JavaScriptBridge.eval(js)

static func _ensure_web_callback() -> void:
	if not OS.has_feature("web") or _web_cb_ref != null:
		return
	_web_cb_ref = JavaScriptBridge.create_callback(_on_web_input_received)
	var win = JavaScriptBridge.get_interface("window")
	if win:
		win.__mobileInputCallback = _web_cb_ref

static func _on_web_input_received(args: Array) -> void:
	if args.size() > 0 and _active_web_input != null and is_instance_valid(_active_web_input):
		var text_val: String = str(args[0])
		_active_web_input.text = text_val
		_active_web_input.text_changed.emit(text_val)
		_active_web_input.release_focus()
	_active_web_input = null

## Nhả focus (tắt bàn phím ảo) khi người dùng chạm vào vùng trống ngoài ô nhập
func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit:
			focused.release_focus()

## Kiểm tra phía client cho nhanh (server vẫn kiểm tra lại). Trả về câu lỗi, rỗng = hợp lệ.
static func check_username(u: String) -> String:
	if u.length() < MIN_USERNAME or u.length() > MAX_USERNAME:
		return "Tên tài khoản dài %d–%d ký tự" % [MIN_USERNAME, MAX_USERNAME]
	var re := RegEx.create_from_string("^[a-z0-9_]+$")
	if re.search(u.to_lower()) == null:
		return "Tên tài khoản chỉ gồm chữ không dấu, số và dấu _"
	return ""

static func check_email(e: String) -> String:
	var re := RegEx.create_from_string("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
	if e.length() > 254 or re.search(e) == null:
		return "Email không hợp lệ"
	return ""

static func check_new_password(p: String, confirm: String, user: String) -> String:
	if p.length() < MIN_PASSWORD or p.length() > MAX_PASSWORD:
		return "Mật khẩu dài %d–%d ký tự" % [MIN_PASSWORD, MAX_PASSWORD]
	if user != "" and p.to_lower().contains(user.to_lower()):
		return "Mật khẩu không được chứa tên tài khoản"
	if p != confirm:
		return "Nhập lại mật khẩu không khớp"
	return ""

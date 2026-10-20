extends Control
class_name AccountScreen
## Phần chung của các màn tài khoản (Đăng nhập, Tạo tài khoản, Quên mật khẩu): hiện dần khi mở, mờ dần khi chuyển màn,
## dòng thông báo, phóng to nút khi rê chuột, khóa nút trong lúc chờ server, nút Hiện/Ẩn mật khẩu.
## Mọi thành phần vẫn là node trong scene (Stage toạ độ mockup 1672x941) để kéo thả chỉnh trong editor.

const LOGIN_SCENE := "res://ui/login/Login.tscn"
const REGISTER_SCENE := "res://ui/account/Register.tscn"
const FORGOT_SCENE := "res://ui/account/ForgotPassword.tscn"
const AFTER_LOGIN_SCENE := "res://ui/server_select/ServerSelect.tscn"
const FADE := 0.35

const MIN_USERNAME := 3
const MAX_USERNAME := 20
const MIN_PASSWORD := 6
const MAX_PASSWORD := 64

## Chuyển dữ liệu sang màn Đăng nhập khi quay về (VD đặt lại mật khẩu xong: điền sẵn tên + báo thành công).
static var next_login_username := ""
static var next_login_message := ""

var _toast_tween: Tween
var _busy := false

## Gọi trong _ready() của màn con.
func _setup_screen() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)

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
	eye.pressed.connect(func() -> void:
		var show := fields[0].secret
		for f in fields:
			f.secret = not show
		eye.text = "Ẩn" if show else "Hiện")

## Khóa/mở các nút trong lúc chờ server, tránh bấm 2 lần.
func _set_busy(on: bool, buttons: Array) -> void:
	_busy = on
	for b: BaseButton in buttons:
		b.disabled = on
		b.modulate.a = 0.6 if on else 1.0

func _toast(label: Label, text: String, seconds := 2.6) -> void:
	label.text = text
	label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(label, "modulate:a", 0.0, 0.4)

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

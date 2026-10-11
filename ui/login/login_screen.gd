extends Control
class_name LoginScreen
## Màn Đăng Nhập (dựng theo mockup 1672x941: nền chiến trường Tống–Kim, logo, khung rồng, ô tài khoản/mật khẩu, nút Đăng nhập,
## đăng nhập mạng xã hội, Tạo tài khoản mới). Mọi thành phần là node trong Stage (toạ độ mockup, Stage tự co theo cửa sổ — script
## stage_fit.gd, chạy cả trong editor) nên kéo thả chỉnh vị trí/cỡ trực tiếp trong editor.
##
## CHƯA CÓ máy chủ tài khoản: đăng nhập hiện chỉ kiểm tra không để trống rồi chuyển sang màn tạo/chọn nhân vật; "Ghi nhớ đăng nhập" chỉ
## lưu TÊN tài khoản (không lưu mật khẩu) vào user://login.cfg. Khi có backend, thay _on_login_pressed().

const NEXT_SCENE := "res://ui/server_select/ServerSelect.tscn"
const CFG_PATH := "user://login.cfg"
const MIN_NAME := 3
const MIN_PASSWORD := 4
const FADE := 0.35

@onready var _user: LineEdit = %UserInput
@onready var _password: LineEdit = %PasswordInput
@onready var _eye: Button = %EyeButton
@onready var _remember: CheckBox = %RememberCheck
@onready var _forgot: Button = %ForgotButton
@onready var _login: TextureButton = %LoginButton
@onready var _create: TextureButton = %CreateAccountButton
@onready var _social: Array[TextureButton] = [%GoogleButton, %AppleButton, %FacebookButton, %GuestButton]
@onready var _message: Label = %Message

var _tween: Tween

func _ready() -> void:
	_login.pressed.connect(_on_login_pressed)
	_user.text_submitted.connect(func(_t: String) -> void: _password.grab_focus())
	_password.text_submitted.connect(func(_t: String) -> void: _on_login_pressed())
	_eye.pressed.connect(func() -> void:
		_password.secret = not _password.secret
		_eye.text = "Hiện" if _password.secret else "Ẩn")
	_forgot.pressed.connect(_toast.bind("Chức năng quên mật khẩu đang phát triển"))
	_create.pressed.connect(_toast.bind("Chức năng tạo tài khoản đang phát triển"))
	for b in _social:
		b.pressed.connect(_toast.bind("Đăng nhập này đang phát triển"))
	for b: TextureButton in [_login, _create] + _social:
		b.mouse_entered.connect(_hover.bind(b, true))
		b.mouse_exited.connect(_hover.bind(b, false))
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		_user.text = str(cfg.get_value("login", "name", ""))
		_remember.button_pressed = bool(cfg.get_value("login", "remember", true))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)

func _hover(b: TextureButton, on: bool) -> void:
	b.pivot_offset = b.size * 0.5
	create_tween().tween_property(b, "scale", Vector2.ONE * (1.05 if on else 1.0), 0.1)

func _on_login_pressed() -> void:
	var name_text := _user.text.strip_edges()
	if name_text.length() < MIN_NAME:
		_toast("Tên tài khoản cần ít nhất %d ký tự" % MIN_NAME)
		_user.grab_focus()
		return
	if _password.text.length() < MIN_PASSWORD:
		_toast("Mật khẩu cần ít nhất %d ký tự" % MIN_PASSWORD)
		_password.grab_focus()
		return
	var cfg := ConfigFile.new()
	cfg.set_value("login", "remember", _remember.button_pressed)
	cfg.set_value("login", "name", name_text if _remember.button_pressed else "")
	cfg.save(CFG_PATH)
	_login.disabled = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(get_tree().change_scene_to_file.bind(NEXT_SCENE))

func _toast(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(1.8)
	_tween.tween_property(_message, "modulate:a", 0.0, 0.4)

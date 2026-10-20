extends AccountScreen
class_name LoginScreen
## Màn Đăng Nhập (dựng theo mockup 1672x941: nền chiến trường Tống–Kim, logo, khung rồng, ô tài khoản/mật khẩu, nút Đăng nhập,
## đăng nhập Google, Tạo tài khoản mới). Mọi thành phần là node trong Stage (toạ độ mockup, Stage tự co theo cửa sổ — script
## stage_fit.gd, chạy cả trong editor) nên kéo thả chỉnh vị trí/cỡ trực tiếp trong editor.
##
## Đăng nhập qua server tài khoản (AccountApi). "Ghi nhớ đăng nhập": giữ phiên trên máy (KHÔNG lưu mật khẩu), lần sau mở game
## tự đăng nhập lại. Tên tài khoản gần nhất lưu ở user://login.cfg để điền sẵn.
## Google: mở trình duyệt của máy để đăng nhập, game chờ server báo xong (bấm lại nút Google để hủy chờ).
## Apple / Facebook / Khách tạm ẩn.

const CFG_PATH := "user://login.cfg"
const PolicyDialog = preload("res://ui/policy/policy_dialog.gd")

@onready var _user: LineEdit = %UserInput
@onready var _password: LineEdit = %PasswordInput
@onready var _eye: Button = %EyeButton
@onready var _remember: CheckBox = %RememberCheck
@onready var _forgot: Button = %ForgotButton
@onready var _login: TextureButton = %LoginButton
@onready var _create: BaseButton = %CreateAccountButton
@onready var _register_link: BaseButton = get_node_or_null("%RegisterLink")
@onready var _google: TextureButton = %GoogleButton
@onready var _facebook: TextureButton = get_node_or_null("%FacebookButton")
@onready var _apple: TextureButton = get_node_or_null("%AppleButton")
@onready var _message: Label = %Message

func _ready() -> void:
	_setup_screen()
	_login.pressed.connect(_on_login_pressed)
	_user.text_submitted.connect(func(_t: String) -> void: _password.grab_focus())
	_password.text_submitted.connect(func(_t: String) -> void: _on_login_pressed())
	_bind_eye(_eye, [_password])
	_forgot.pressed.connect(func() -> void:
		AccountScreen.next_login_username = _user.text.strip_edges().to_lower()
		_go(FORGOT_SCENE))
	_create.pressed.connect(_go.bind(REGISTER_SCENE))
	if _register_link:
		_register_link.pressed.connect(_go.bind(REGISTER_SCENE))
	_google.pressed.connect(_on_google_pressed)
	if _facebook:
		_facebook.pressed.connect(func() -> void:
			_toast(_message, "Đăng nhập Facebook đang phát triển"))
	if _apple:
		_apple.pressed.connect(func() -> void:
			_toast(_message, "Đăng nhập Apple đang phát triển"))
	for b: BaseButton in [_login, _create, _register_link, _forgot, _google, _facebook, _apple]:
		if b:
			b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
			_bind_hover(b)

	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		_user.text = str(cfg.get_value("login", "name", ""))
		_remember.button_pressed = bool(cfg.get_value("login", "remember", true))
	if AccountScreen.next_login_username != "":
		_user.text = AccountScreen.next_login_username
		AccountScreen.next_login_username = ""
	if AccountScreen.next_login_message != "":
		_toast(_message, AccountScreen.next_login_message, 4.0)
		AccountScreen.next_login_message = ""
	if not OS.has_feature("mobile"):
		(_password if _user.text != "" else _user).grab_focus()

	for arg in OS.get_cmdline_args():
		if arg == "--test-login-policy":
			_test_capture_policy.call_deferred()
			break

	# Hiển thị bảng điều khoản dịch vụ nếu chưa chấp nhận
	if not PolicyDialog.is_accepted():
		var dlg := PolicyDialog.show_if_needed(self)
		if dlg:
			dlg.accepted_done.connect(func() -> void:
				if AccountApi.has_saved_session():
					_resume()
				elif not OS.has_feature("mobile"):
					(_password if _user.text != "" else _user).grab_focus()
			)
			return

	if AccountApi.is_logged_in():
		## Quay lại màn này khi đang đăng nhập (VD bấm "Đổi tài khoản") = đăng xuất phiên cũ.
		AccountApi.logout()
	elif AccountApi.has_saved_session():
		_resume()

func _test_capture_policy() -> void:
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/d6888eb9-bf62-47ed-a3a2-f742759dfa21/login_with_policy.png")
		print("LOGIN_WITH_POLICY_SUCCESS")
	get_tree().quit()

## Tự đăng nhập lại bằng phiên đã ghi nhớ.
func _resume() -> void:
	if _user.text == "":
		_user.text = AccountApi.saved_username()
	_set_busy(true, [_login, _create, _google])
	_toast(_message, "Đang đăng nhập lại…", 30.0)
	var r: Dictionary = await AccountApi.resume()
	_set_busy(false, [_login, _create, _google])
	if r.ok:
		_go(AFTER_LOGIN_SCENE)
	elif r.code == "network":
		_toast(_message, r.message)
	else:
		_toast(_message, "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại")

var _google_waiting := false

func _on_google_pressed() -> void:
	if _google_waiting:
		AccountApi.cancel_google()
		return
	if _busy:
		return
	_google_waiting = true
	_set_busy(true, [_login, _create])
	_toast(_message, "Đang chờ đăng nhập Google trên trình duyệt… (bấm Google lần nữa để hủy)", 300.0)
	var r: Dictionary = await AccountApi.google_login()
	_google_waiting = false
	_set_busy(false, [_login, _create])
	if not r.ok:
		_toast(_message, r.message, 4.0)
		return
	var cfg := ConfigFile.new()
	cfg.set_value("login", "remember", true)
	cfg.set_value("login", "name", AccountApi.username())
	cfg.save(CFG_PATH)
	_go(AFTER_LOGIN_SCENE)

func _on_login_pressed() -> void:
	if _busy:
		return
	var name_text := _user.text.strip_edges().to_lower()
	if name_text.length() < MIN_USERNAME:
		_toast(_message, "Tên tài khoản cần ít nhất %d ký tự" % MIN_USERNAME)
		_user.grab_focus()
		return
	if _password.text.is_empty():
		_toast(_message, "Hãy nhập mật khẩu")
		_password.grab_focus()
		return
	_set_busy(true, [_login, _create, _google])
	_toast(_message, "Đang đăng nhập…", 30.0)
	var r: Dictionary = await AccountApi.login(name_text, _password.text, _remember.button_pressed)
	_set_busy(false, [_login, _create, _google])
	if not r.ok:
		_toast(_message, r.message, 4.0 if r.code == "banned" else 2.6)
		if r.code == "wrong_login":
			_password.grab_focus()
			_password.select_all()
		return
	_password.text = ""
	var cfg := ConfigFile.new()
	cfg.set_value("login", "remember", _remember.button_pressed)
	cfg.set_value("login", "name", name_text if _remember.button_pressed else "")
	cfg.save(CFG_PATH)
	_go(AFTER_LOGIN_SCENE)

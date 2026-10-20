extends AccountScreen
## Màn Quên Mật Khẩu, 2 bước trong cùng 1 màn:
##   1. StepRequest: tên tài khoản + email -> server gửi mã 6 số về email (luôn báo "đã gửi" dù tên/email sai, chống dò tài khoản).
##   2. StepReset: mã + mật khẩu mới (2 lần) -> đổi xong quay về Đăng nhập, điền sẵn tên. Mọi máy đang đăng nhập bị đăng xuất.
## "Gửi lại" có thời gian chờ để tránh spam mail; server cũng giới hạn số lần.

const RESEND_COOLDOWN := 60

@onready var _step_request: Control = %StepRequest
@onready var _step_reset: Control = %StepReset
@onready var _user: LineEdit = %UserInput
@onready var _email: LineEdit = %EmailInput
@onready var _send: Button = %SendButton
@onready var _have_code: Button = %HaveCodeButton
@onready var _desc: Label = %Desc
@onready var _code: LineEdit = %CodeInput
@onready var _password: LineEdit = %NewPasswordInput
@onready var _password2: LineEdit = %NewPasswordConfirmInput
@onready var _eye: Button = %EyeButton
@onready var _reset: Button = %ResetButton
@onready var _resend: Button = %ResendButton
@onready var _back: Button = %BackButton
@onready var _message: Label = %Message

var _cooldown_left := 0
var _cooldown_timer: Timer

func _ready() -> void:
	_setup_screen()
	_bind_eye(_eye, [_password, _password2])
	for b: Button in [_send, _reset, _resend, _have_code, _back]:
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		_bind_hover(b)
	_send.pressed.connect(_on_send_pressed)
	_reset.pressed.connect(_on_reset_pressed)
	_resend.pressed.connect(_on_send_pressed)
	_have_code.pressed.connect(_on_have_code_pressed)
	_back.pressed.connect(_on_back_pressed)
	_user.text_submitted.connect(func(_t: String) -> void: _email.grab_focus())
	_email.text_submitted.connect(func(_t: String) -> void: _on_send_pressed())
	_code.text_changed.connect(_on_code_changed)
	_code.text_submitted.connect(func(_t: String) -> void: _password.grab_focus())
	_password.text_submitted.connect(func(_t: String) -> void: _password2.grab_focus())
	_password2.text_submitted.connect(func(_t: String) -> void: _on_reset_pressed())
	_cooldown_timer = Timer.new()
	_cooldown_timer.wait_time = 1.0
	_cooldown_timer.timeout.connect(_tick_cooldown)
	add_child(_cooldown_timer)
	_user.text = AccountScreen.next_login_username
	if not OS.has_feature("mobile"):
		(_email if _user.text != "" else _user).grab_focus()

func _show_step(reset: bool) -> void:
	_step_request.visible = not reset
	_step_reset.visible = reset
	if not OS.has_feature("mobile"):
		if reset:
			_code.grab_focus()
		else:
			_user.grab_focus()

# ---------------------------------------------------------------- bước 1

func _on_send_pressed() -> void:
	if _busy or _cooldown_left > 0:
		return
	var user := _user.text.strip_edges().to_lower()
	var email := _email.text.strip_edges()
	var err := check_username(user)
	if err != "":
		_show_step(false)
		_invalid(_user, err)
		return
	err = check_email(email)
	if err != "":
		_show_step(false)
		_invalid(_email, err)
		return
	_set_busy(true, [_send, _resend, _back])
	_toast(_message, "Đang gửi mã…", 30.0)
	var r: Dictionary = await AccountApi.forgot_password(user, email)
	_set_busy(false, [_send, _resend, _back])
	if not r.ok:
		_toast(_message, r.message)
		return
	var minutes := maxi(1, int(r.data.get("expires_in", 600)) / 60) if r.data is Dictionary else 10
	_desc.text = "Nếu tên và email khớp, mã 6 số đã được gửi về %s. Mã có hiệu lực %d phút." % [_mask_email(email), minutes]
	_toast(_message, "Đã gửi mã, hãy kiểm tra email (cả mục Thư rác)")
	_start_cooldown()
	_show_step(true)

func _on_have_code_pressed() -> void:
	var err := check_username(_user.text.strip_edges())
	if err != "":
		_invalid(_user, "Nhập tên tài khoản trước khi nhập mã")
		return
	_show_step(true)

## ab***@gmail.com — để người chơi biết mã gửi tới đâu mà không lộ hết email trên màn hình.
func _mask_email(email: String) -> String:
	var at := email.find("@")
	if at <= 0:
		return email
	var local := email.substr(0, at)
	return local.substr(0, mini(2, local.length())) + "***" + email.substr(at)

func _start_cooldown() -> void:
	_cooldown_left = RESEND_COOLDOWN
	_resend.disabled = true
	_tick_cooldown_label()
	_cooldown_timer.start()

func _tick_cooldown() -> void:
	_cooldown_left -= 1
	if _cooldown_left <= 0:
		_cooldown_timer.stop()
		_resend.disabled = false
	_tick_cooldown_label()

func _tick_cooldown_label() -> void:
	_resend.text = "Gửi lại mã sau %ds" % _cooldown_left if _cooldown_left > 0 else "Chưa nhận được mã? Gửi lại"

# ---------------------------------------------------------------- bước 2

## Chỉ cho nhập số (dán cả "123 456" cũng được).
func _on_code_changed(text: String) -> void:
	var digits := ""
	for c in text:
		if c >= "0" and c <= "9":
			digits += c
	if digits != text:
		var caret := _code.caret_column
		_code.text = digits.substr(0, 6)
		_code.caret_column = mini(caret, _code.text.length())
	if _code.text.length() == 6:
		_password.grab_focus()

func _on_reset_pressed() -> void:
	if _busy:
		return
	var user := _user.text.strip_edges().to_lower()
	if _code.text.length() != 6:
		_invalid(_code, "Mã xác nhận gồm 6 chữ số")
		return
	var err := check_new_password(_password.text, _password2.text, user)
	if err != "":
		_invalid(_password if not err.begins_with("Nhập lại") else _password2, err)
		return
	_set_busy(true, [_reset, _resend, _back])
	_toast(_message, "Đang đổi mật khẩu…", 30.0)
	var r: Dictionary = await AccountApi.reset_password(user, _code.text, _password.text)
	_set_busy(false, [_reset, _resend, _back])
	if _cooldown_left > 0:
		_resend.disabled = true
	if not r.ok:
		match r.code:
			"bad_code": _invalid(_code, "Mã không đúng hoặc đã hết hạn. Sai 5 lần phải gửi lại mã mới")
			"bad_password", "password_is_username": _invalid(_password, r.message)
			_: _toast(_message, r.message)
		return
	AccountScreen.next_login_username = user
	AccountScreen.next_login_message = "Đổi mật khẩu thành công, hãy đăng nhập lại"
	_go(LOGIN_SCENE)

func _on_back_pressed() -> void:
	if _step_reset.visible:
		_show_step(false)
		return
	_go(LOGIN_SCENE)

func _invalid(field: LineEdit, text: String) -> void:
	_toast(_message, text)
	field.grab_focus()
	field.select_all()

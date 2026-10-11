extends AccountScreen
## Màn Tạo Tài Khoản: tên, email (nhập 2 lần cho khỏi gõ nhầm — email là cách duy nhất lấy lại mật khẩu), mật khẩu (2 lần).
## Không cần mã xác nhận: tạo xong là đăng nhập luôn (ghi nhớ đăng nhập) rồi sang màn Chọn Máy Chủ.

@onready var _user: LineEdit = %UserInput
@onready var _email: LineEdit = %EmailInput
@onready var _email2: LineEdit = %EmailConfirmInput
@onready var _password: LineEdit = %PasswordInput
@onready var _password2: LineEdit = %PasswordConfirmInput
@onready var _eye: Button = %EyeButton
@onready var _create: TextureButton = %CreateButton
@onready var _back: Button = %BackButton
@onready var _message: Label = %Message

func _ready() -> void:
	_setup_screen()
	_bind_eye(_eye, [_password, _password2])
	_bind_hover(_create)
	_create.pressed.connect(_on_create_pressed)
	_back.pressed.connect(_go.bind(LOGIN_SCENE))
	## Enter ở mỗi ô nhảy sang ô kế tiếp, ô cuối thì tạo tài khoản.
	var order: Array[LineEdit] = [_user, _email, _email2, _password, _password2]
	for i in order.size() - 1:
		order[i].text_submitted.connect(func(_t: String) -> void: order[i + 1].grab_focus())
	_password2.text_submitted.connect(func(_t: String) -> void: _on_create_pressed())
	_user.grab_focus()

func _on_create_pressed() -> void:
	if _busy:
		return
	var user := _user.text.strip_edges().to_lower()
	var email := _email.text.strip_edges()
	var err := check_username(user)
	if err != "":
		_invalid(_user, err)
		return
	err = check_email(email)
	if err != "":
		_invalid(_email, err)
		return
	if email.to_lower() != _email2.text.strip_edges().to_lower():
		_invalid(_email2, "Nhập lại email không khớp")
		return
	err = check_new_password(_password.text, _password2.text, user)
	if err != "":
		_invalid(_password if not err.begins_with("Nhập lại") else _password2, err)
		return

	_set_busy(true, [_create, _back])
	_toast(_message, "Đang tạo tài khoản…", 30.0)
	var r: Dictionary = await AccountApi.register(user, email, _password.text)
	_set_busy(false, [_create, _back])
	if not r.ok:
		match r.code:
			"username_taken", "bad_username": _invalid(_user, r.message)
			"bad_email": _invalid(_email, r.message)
			"bad_password", "password_is_username": _invalid(_password, r.message)
			_: _toast(_message, r.message)
		return
	_toast(_message, "Tạo tài khoản thành công!")
	_go(AFTER_LOGIN_SCENE)

func _invalid(field: LineEdit, text: String) -> void:
	_toast(_message, text)
	field.grab_focus()
	field.select_all()

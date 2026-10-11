extends AccountScreen
class_name AccountDialog
## Hộp thoại Tài Khoản trong game (mở từ nút Tài khoản / Cài Đặt): xem tên + email, đổi mật khẩu (hoặc đặt mật khẩu cho
## tài khoản chỉ đăng nhập Google), liên kết Google, đăng xuất.
## Đổi mật khẩu thành công: server đăng xuất mọi máy khác, máy này giữ đăng nhập (nhận phiên mới).
## Mở bằng AccountDialog.open(self) — tự đặt trên 1 CanvasLayer cao để nằm trên mọi UI khác.

const SCENE := preload("res://ui/account/AccountDialog.tscn")
const LAYER := 90
const LAYER_NAME := "AccountDialogLayer"

@onready var _dim: ColorRect = %Dim
@onready var _close: Button = %CloseButton
@onready var _info: Label = %Info
@onready var _section: Label = %PasswordSection
@onready var _old: LineEdit = %OldPasswordInput
@onready var _new: LineEdit = %NewPasswordInput
@onready var _new2: LineEdit = %NewPasswordConfirmInput
@onready var _eye: Button = %EyeButton
@onready var _change: TextureButton = %ChangeButton
@onready var _logout: Button = %LogoutButton
@onready var _link_google: Button = %LinkGoogleButton
@onready var _message: Label = %Message

static func open(from: Node) -> AccountDialog:
	var root := from.get_tree().root
	var existing_layer := root.get_node_or_null(LAYER_NAME)
	if existing_layer != null and is_instance_valid(existing_layer):
		var existing_dlg := existing_layer.get_node_or_null("AccountDialog") as AccountDialog
		if existing_dlg != null:
			return existing_dlg
		existing_layer.queue_free()
	var layer := CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = LAYER
	var dlg: AccountDialog = SCENE.instantiate()
	layer.add_child(dlg)
	root.add_child(layer)
	if from != root and not from.tree_exiting.is_connected(layer.queue_free):
		from.tree_exiting.connect(layer.queue_free)
	return dlg

func _ready() -> void:
	_setup_screen()
	_bind_eye(_eye, [_old, _new, _new2])
	_bind_hover(_change)
	_close.pressed.connect(_close_dialog)
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_dialog())
	_change.pressed.connect(_on_change_pressed)
	_logout.pressed.connect(_on_logout_pressed)
	_link_google.pressed.connect(_on_link_google_pressed)
	_old.text_submitted.connect(func(_t: String) -> void: _new.grab_focus())
	_new.text_submitted.connect(func(_t: String) -> void: _new2.grab_focus())
	_new2.text_submitted.connect(func(_t: String) -> void: _on_change_pressed())
	_refresh_info()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_dialog()

func _refresh_info() -> void:
	if not AccountApi.is_logged_in():
		_info.text = "Chưa đăng nhập tài khoản"
		for c: Control in [_section, _old, _new, _new2, _eye, _change, _link_google]:
			c.visible = false
		_logout.text = "Đăng nhập"
		return
	var acc := AccountApi.account
	_info.text = "Tài khoản: %s\nEmail: %s" % [acc.get("username", ""), acc.get("email", "")]
	for c: Control in [_section, _new, _new2, _eye, _change]:
		c.visible = true
	## Tài khoản chỉ đăng nhập Google (chưa đặt mật khẩu) thì không hỏi mật khẩu hiện tại.
	_old.visible = bool(acc.get("has_password", true))
	_link_google.visible = not bool(acc.get("google_linked", false))
	_logout.text = "Đăng xuất"

func _on_change_pressed() -> void:
	if _busy:
		return
	if _old.visible and _old.text.is_empty():
		_invalid(_old, "Hãy nhập mật khẩu hiện tại")
		return
	var err := check_new_password(_new.text, _new2.text, AccountApi.username())
	if err != "":
		_invalid(_new if not err.begins_with("Nhập lại") else _new2, err)
		return
	if _old.visible and _new.text == _old.text:
		_invalid(_new, "Mật khẩu mới phải khác mật khẩu hiện tại")
		return
	_set_busy(true, [_change, _logout, _close])
	_toast(_message, "Đang đổi mật khẩu…", 30.0)
	var r: Dictionary = await AccountApi.change_password(_old.text, _new.text)
	_set_busy(false, [_change, _logout, _close])
	if not r.ok:
		match r.code:
			"wrong_password": _invalid(_old, r.message)
			"bad_password", "password_is_username": _invalid(_new, r.message)
			"unauthorized", "banned": _back_to_login(r.message)
			_: _toast(_message, r.message)
		return
	for f: LineEdit in [_old, _new, _new2]:
		f.text = ""
	_refresh_info()
	_toast(_message, "Đã đổi mật khẩu. Các máy khác đã bị đăng xuất", 4.0)

var _google_waiting := false

func _on_link_google_pressed() -> void:
	if _google_waiting:
		AccountApi.cancel_google()
		return
	if _busy:
		return
	_google_waiting = true
	_set_busy(true, [_change, _logout, _close])
	_link_google.text = "Đang chờ trình duyệt… (bấm để hủy)"
	_toast(_message, "Đăng nhập Google trên trình duyệt để liên kết", 300.0)
	var r: Dictionary = await AccountApi.google_login(true)
	_google_waiting = false
	_set_busy(false, [_change, _logout, _close])
	_link_google.text = "Liên kết tài khoản Google"
	_refresh_info()
	_toast(_message, "Đã liên kết Google — lần sau có thể đăng nhập bằng Google" if r.ok else r.message, 4.0)

func _on_logout_pressed() -> void:
	if _busy:
		return
	_set_busy(true, [_change, _logout, _close])
	if AccountApi.is_logged_in():
		await AccountApi.logout()
	_back_to_login("")

func _back_to_login(message: String) -> void:
	AccountScreen.next_login_message = message
	get_tree().change_scene_to_file(LOGIN_SCENE)
	get_parent().queue_free()

func _close_dialog() -> void:
	if _busy:
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(get_parent().queue_free)

func _invalid(field: LineEdit, text: String) -> void:
	_toast(_message, text)
	field.grab_focus()
	field.select_all()

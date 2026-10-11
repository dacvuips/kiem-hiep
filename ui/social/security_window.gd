extends SocialWindow
class_name SecurityWindow
## KHOÁ BẢO VỆ / MẬT MÃ — đặt, đổi, xoá mật mã và bật/mở khoá. Mật mã nhập bằng BÀN PHÍM SỐ (KeypadWindow). Khoá này canh giữ RƯƠNG CHỨA ĐỒ,
## bày bán, giao dịch, gửi/rút tiền, vứt đồ. Luật: SecurityLock (đúng KPlayer::SetLockState/CheckSavePw gốc).

var _profile: PlayerProfile
var _state: PanelContainer
var _msg: PanelContainer
var _btn_set: Button
var _btn_change: Button
var _btn_clear: Button
var _btn_lock: Button

static func open(host: Node, profile: PlayerProfile) -> SecurityWindow:
	return SocialWindow.present(host, SecurityWindow.new(profile), &"security") as SecurityWindow

func _init(profile: PlayerProfile = null) -> void:
	super._init("Mật Mã Bảo Vệ", "Khoá rương và đồ đạc bằng mật mã số", 440.0)
	_profile = profile
	if _profile == null:
		return
	_state = SocialUi.banner("", true)
	body.add_child(_state)

	var info := SocialUi.info_box("✦ Khi đang khoá sẽ bị chặn:")
	for line in ["Mở rương chứa đồ: cất / lấy đồ, mở thêm rương", "Gửi / rút tiền trong rương", "Mở bày bán, mở giao dịch, mua đồ bày bán", "Mua – bán đồ với NPC", "Vứt đồ xuống đất"]:
		info[1].add_child(SocialUi.label("•  " + line, SocialUi.TEXT, 13))
	body.add_child(info[0])

	var sec := SocialUi.section("🔑 Mật mã (1 – %d chữ số)" % SecurityLock.MAX_PASSWORD_LENGTH)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_btn_set = SocialUi.stone_button("Đặt mật mã")
	_btn_change = SocialUi.stone_button("Đổi mật mã")
	_btn_clear = SocialUi.stone_button("Xoá mật mã")
	for b in [_btn_set, _btn_change, _btn_clear]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	sec[1].add_child(row)
	body.add_child(sec[0])

	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)
	var buttons := add_button_row()
	_btn_lock = SocialUi.stone_button("Khoá")
	_btn_lock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := SocialUi.stone_button("Đóng")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_btn_lock)
	buttons.add_child(close)

	_btn_set.pressed.connect(_on_set)
	_btn_change.pressed.connect(_on_change)
	_btn_clear.pressed.connect(_on_clear)
	_btn_lock.pressed.connect(_on_toggle_lock)
	close.pressed.connect(func() -> void: close_requested.emit())
	_refresh()

func _host() -> Node:
	return get_tree().current_scene

func _result(err: String, ok_text: String) -> void:
	SocialUi.set_banner(_msg, err if err != "" else ok_text, err == "")
	_msg.visible = true
	_refresh()
	SaveManager.save_profile(_profile)

## Hỏi mật mã mới 2 lần (nhập lại cho khớp) rồi đặt.
func _ask_new(old_code: String) -> void:
	KeypadWindow.ask(_host(), "Nhập mật mã mới", "Nhập mật mã mới (chỉ gồm chữ số).", func(first: String) -> void:
		KeypadWindow.ask(_host(), "Nhập lại mật mã", "Nhập lại mật mã mới để xác nhận.", func(second: String) -> void:
			if first != second:
				_result("Hai lần nhập không giống nhau.", "")
			else:
				_result(SecurityLock.set_password(_profile, first, old_code), "Thay đổi mật mã bảo vệ thành công — đã khoá.")))

func _on_set() -> void:
	_ask_new("")

func _on_change() -> void:
	KeypadWindow.ask(_host(), "Mật mã cũ", "Nhập mật mã hiện tại.", func(old_code: String) -> void:
		if SecurityLock.unlock_check(_profile, old_code):
			_ask_new(old_code)
		else:
			_result("Mật mã cũ không chính xác!", ""))

func _on_clear() -> void:
	KeypadWindow.ask(_host(), "Xoá mật mã", "Nhập mật mã hiện tại để xoá.", func(code: String) -> void:
		_result(SecurityLock.clear_password(_profile, code), "Đã xoá mật mã bảo vệ."))

func _on_toggle_lock() -> void:
	if SecurityLock.is_locked(_profile):
		KeypadWindow.ask(_host(), "Mở khoá", "Nhập mật mã để mở khoá.", func(code: String) -> void:
			_result(SecurityLock.unlock(_profile, code), "Đã mở khoá bảo vệ."))
	else:
		_result(SecurityLock.lock(_profile), "Đã bật khoá bảo vệ.")

func _refresh() -> void:
	var has_pw := SecurityLock.has_password(_profile)
	var locked := SecurityLock.is_locked(_profile)
	if not has_pw:
		SocialUi.set_banner(_state, "Chưa đặt mật mã bảo vệ", false)
	elif locked:
		SocialUi.set_banner(_state, "🔒 Khoá bảo vệ đang BẬT", true)
	else:
		SocialUi.set_banner(_state, "🔓 Khoá bảo vệ đang TẮT", false)
	_btn_set.disabled = has_pw
	_btn_change.disabled = not has_pw
	_btn_clear.disabled = not has_pw
	_btn_lock.disabled = not has_pw
	_btn_lock.text = "Mở khoá" if locked else "Khoá"

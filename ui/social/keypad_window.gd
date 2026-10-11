extends SocialWindow
class_name KeypadWindow
## BÀN PHÍM SỐ nhập mật mã (như ô "bàn phím số" của VLTK gốc): các phím 0-9 xếp NGẪU NHIÊN mỗi lần mở (chống nhìn lén/ghi phím), nút "Đính chính"
## xoá ký tự cuối, ô hiển thị che bằng dấu ●, "xác nhận" / "hủy bỏ". Mật mã tối đa SecurityLock.MAX_PASSWORD_LENGTH chữ số.

var _digits := ""
var _display: Label
var _on_ok: Callable
var _hint: Label
var _msg: Label

## Mở hộp nhập mật mã. on_ok(code: String) được gọi khi bấm xác nhận (mật mã không rỗng).
static func ask(host: Node, window_title: String, hint: String, on_ok: Callable) -> KeypadWindow:
	var win := KeypadWindow.new(window_title, hint, on_ok)
	SocialWindow.present(host, win, &"")
	return win

func _init(window_title: String = "", hint: String = "", on_ok: Callable = Callable()) -> void:
	super._init(window_title, "", 360.0)
	_on_ok = on_ok
	_hint = SocialUi.label(hint, SocialUi.TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_hint)
	var disp_panel := PanelContainer.new()
	disp_panel.add_theme_stylebox_override("panel", SocialUi.box(Color(0.02, 0.03, 0.03), SocialUi.BORDER, 6, 1, 8))
	_display = SocialUi.label("", SocialUi.GOLD, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_display.custom_minimum_size = Vector2(0, 30)
	disp_panel.add_child(_display)
	body.add_child(disp_panel)
	_msg = SocialUi.label("", SocialUi.LABEL_RED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_msg)

	## Lưới 3 cột: 9 chữ số ngẫu nhiên + hàng cuối [Đính chính][chữ số còn lại][Xoá hết].
	var order := ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	order.shuffle()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for i in 9:
		grid.add_child(_digit_button(order[i]))
	var back := SocialUi.stone_button("Đính chính", Vector2(0, 46))
	back.pressed.connect(func() -> void:
		_digits = _digits.left(_digits.length() - 1)
		_update())
	grid.add_child(back)
	grid.add_child(_digit_button(order[9]))
	var clear := SocialUi.stone_button("Xoá hết", Vector2(0, 46))
	clear.pressed.connect(func() -> void:
		_digits = ""
		_update())
	grid.add_child(clear)

	var row := add_button_row()
	var ok := SocialUi.stone_button("xác nhận")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cancel := SocialUi.stone_button("hủy bỏ")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	row.add_child(cancel)
	ok.pressed.connect(_submit)
	cancel.pressed.connect(func() -> void: close_requested.emit())
	_update()

func _digit_button(d: String) -> Button:
	var b := SocialUi.stone_button(d, Vector2(0, 46))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void:
		if _digits.length() < SecurityLock.MAX_PASSWORD_LENGTH:
			_digits += d
		_update())
	return b

func _update() -> void:
	_display.text = "●".repeat(_digits.length()) if not _digits.is_empty() else "—"
	_msg.text = ""

func _submit() -> void:
	if _digits.is_empty():
		_msg.text = "Hãy nhập mật mã."
		return
	var code := _digits
	close_requested.emit()
	if _on_ok.is_valid():
		_on_ok.call(code)

## Tiện ích cho kiểm thử: nhập chuỗi số rồi xác nhận (không qua chuột).
func type_and_submit(code: String) -> void:
	_digits = code
	_submit()

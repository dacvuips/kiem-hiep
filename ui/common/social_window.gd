extends DraggableWindow
class_name SocialWindow
## Cửa sổ xã hội theo ảnh mẫu: khung tối bo góc viền mảnh, tiêu đề vàng + phụ đề xám ở giữa, nút ✕ góc phải, kéo được bằng chỗ trống.
## Nội dung đặt vào `body` (VBoxContainer). Đóng: phát `close_requested` (người gọi tự queue_free khung / CanvasLayer cha).

var subtitle_label: Label

func _init(window_title: String = "", sub: String = "", min_width := 420.0) -> void:
	super._init(window_title, true)             ## frameless: không vẽ thanh tiêu đề mặc định, ta tự vẽ
	custom_minimum_size.x = min_width
	add_theme_stylebox_override("panel", SocialUi.window_style())
	close_button.text = "✕"
	close_button.flat = true
	close_button.add_theme_color_override("font_color", SocialUi.SUBTITLE)
	close_button.add_theme_color_override("font_hover_color", SocialUi.LABEL_RED)
	close_button.offset_left = -40
	close_button.offset_top = 6
	close_button.offset_right = -8
	close_button.offset_bottom = 36
	body.add_child(SocialUi.title(window_title))
	subtitle_label = SocialUi.subtitle(sub)
	subtitle_label.visible = sub != ""
	body.add_child(subtitle_label)
	body.add_child(SocialUi.divider())

func set_subtitle(text: String) -> void:
	subtitle_label.text = text
	subtitle_label.visible = text != ""

## Hàng nút "đá" xếp đều ở đáy khung — trả về HBox để người gọi add_child từng nút.
func add_button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	return row

## Đưa cửa sổ lên màn hình: bọc trong CanvasLayer (DraggableWindow đổi `layer` để nổi lên trên) gắn vào `host`. Mỗi loại cửa sổ (`kind`)
## chỉ mở 1 cái — mở lại thì đưa cái đang mở lên trên và trả về nó.
var kind: StringName = &""

static func present(host: Node, win: SocialWindow, window_kind: StringName = &"") -> SocialWindow:
	if window_kind != &"":
		for w in host.get_tree().get_nodes_in_group("social_windows"):
			if w is SocialWindow and w.kind == window_kind and is_instance_valid(w):
				(w as SocialWindow).bring_to_front()
				win.queue_free()
				return w
	win.kind = window_kind
	win.add_to_group("social_windows")
	var layer := CanvasLayer.new()
	layer.layer = DraggableWindow.WINDOW_LAYER + 1
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(win)
	host.add_child(layer)
	win.close_requested.connect(func() -> void: layer.queue_free())
	return win

## Hộp nhập 1 dòng chữ (đặt giá, nhập số tiền, mật khẩu...). on_ok(text) được gọi khi bấm Đồng ý.
static func prompt(host: Node, window_title: String, hint: String, on_ok: Callable, default_text := "", secret := false) -> void:
	var win := SocialWindow.new(window_title, "", 340.0)
	var edit := SocialUi.line_edit(hint, secret)
	edit.text = default_text
	win.body.add_child(edit)
	var row := win.add_button_row()
	var ok := SocialUi.stone_button("Đồng ý")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cancel := SocialUi.stone_button("Huỷ")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	row.add_child(cancel)
	var layer := present(host, win, &"")
	var submit := func() -> void:
		var text := edit.text
		win.close_requested.emit()
		on_ok.call(text)
	ok.pressed.connect(submit)
	edit.text_submitted.connect(func(_t: String) -> void: submit.call())
	cancel.pressed.connect(func() -> void: win.close_requested.emit())
	edit.call_deferred("grab_focus")

## Hộp hỏi Có/Không.
static func confirm(host: Node, window_title: String, question: String, on_yes: Callable) -> void:
	var win := SocialWindow.new(window_title, "", 360.0)
	var l := SocialUi.label(question, SocialUi.TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win.body.add_child(l)
	var row := win.add_button_row()
	var yes := SocialUi.stone_button("Đồng ý")
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var no := SocialUi.stone_button("Huỷ")
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
	row.add_child(no)
	present(host, win, &"")
	yes.pressed.connect(func() -> void:
		win.close_requested.emit()
		on_yes.call())
	no.pressed.connect(func() -> void: win.close_requested.emit())

extends Control

class_name ChatInputStrip

## DẢI Ô NHẬP CHAT gốc = [InputBack] của \Ui\Ui3\UiPlayerBar.ini (ảnh / toạ độ xem WebHudBar):
##   ô vuông ảnh kênh ([ChannelBtn] — ảnh MenuImage của kênh, bấm = kênh kế tiếp) + ô gõ ([InputEdit]) + [Face] biểu cảm + [SendBtn].
##   Kênh Riêng: ô tên người nhận nằm TRONG dải, bên trái ô gõ (TO_W px), có vạch ngăn.
## Dùng chung bản web (WebHudBar dựng) và bản mobile (ChatBox tự dựng); dải luôn đặt NGOÀI khung chat, ngay dưới (ChatBox.dock_input_strip).
## Ô gõ / ô kênh / ô tên người nhận là của ChatBox (take_web_inputs) — mọi logic gửi / chat mật / chèn đồ giữ nguyên.

## Bề ngang ô tên người nhận (px, trước khi thu phóng) + khoảng ngăn với ô gõ.
const TO_W := 128.0
const TO_SEP := 6.0
const TO_COLOR := Color8(252, 151, 255)   ## màu kênh Riêng gốc (MSNRoom TextColorUnknown)
const FONT := 15

var _chat: ChatBox
var _channel_btn: Button
var _input_holder: Control
var _to_holder: Control
var _input_rect := Rect2()   ## chỗ ô gõ khi không có ô tên người nhận

static func _r(r: Rect2) -> Rect2:
	return WebHudBar._r(r)

func _init() -> void:
	name = "ChatInputStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var o := _r(WebHudBar.INPUT_BACK).position
	size = _r(WebHudBar.INPUT_BACK).size
	## [InputBack] Trans=1: ảnh có sẵn độ trong (lòng ô gõ đen mờ).
	_art(load(WebHudBar.ART_DIR + "input_back_0.png"), Rect2(Vector2.ZERO, size))

	## [ChannelBtn]: ảnh nút kênh gốc (ChatBox.channel_icon) vừa khít ô vuông của ảnh nền; bấm = kênh kế tiếp.
	_channel_btn = Button.new()
	_channel_btn.flat = true
	_channel_btn.expand_icon = true
	_channel_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_channel_btn.focus_mode = Control.FOCUS_NONE
	_channel_btn.position = _r(WebHudBar.CHANNEL_SOCKET).position - o
	_channel_btn.size = _r(WebHudBar.CHANNEL_SOCKET).size
	_channel_btn.add_theme_font_size_override("font_size", 14)
	_channel_btn.add_theme_color_override("font_color", WebHudBar.CHANNEL_COLOR)
	_channel_btn.add_theme_color_override("font_hover_color", WebHudBar.CHANNEL_OVER)
	_channel_btn.add_theme_color_override("font_pressed_color", WebHudBar.CHANNEL_SEL)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_channel_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_channel_btn.pressed.connect(func() -> void:
		if _chat_ok():
			_chat.cycle_send_channel())
	add_child(_channel_btn)

	_input_holder = Control.new()
	var ir := _r(WebHudBar.INPUT_EDIT)
	_input_holder.position = ir.position - o - Vector2(2, 6)
	_input_holder.size = ir.size + Vector2(4, 12)
	_input_rect = Rect2(_input_holder.position, _input_holder.size)
	add_child(_input_holder)
	_to_holder = Control.new()
	_to_holder.position = _input_rect.position
	_to_holder.size = Vector2(TO_W, _input_rect.size.y)
	_to_holder.visible = false
	add_child(_to_holder)
	var sep := ColorRect.new()   ## vạch ngăn tên người nhận | ô gõ
	sep.color = Color(0.85, 0.75, 0.45, 0.45)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.position = Vector2(TO_W + TO_SEP * 0.5 - 1.0, 5.0)
	sep.size = Vector2(1.0, _input_rect.size.y - 10.0)
	_to_holder.add_child(sep)

	## [Face] biểu cảm — game chưa có bảng biểu cảm: chỉ hiện ảnh gốc.
	var face := TextureRect.new()
	face.texture = load(WebHudBar.ART_DIR + "face_0.png")
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.position = _r(WebHudBar.FACE_BTN).position - o
	face.size = _r(WebHudBar.FACE_BTN).size
	face.tooltip_text = "Biểu cảm"
	add_child(face)

	## [SendBtn] Up=0 Down=1 Over=2.
	var send := TextureButton.new()
	send.texture_normal = load(WebHudBar.ART_DIR + "send_0.png")
	send.texture_pressed = load(WebHudBar.ART_DIR + "send_1.png")
	send.texture_hover = load(WebHudBar.ART_DIR + "send_2.png")
	send.ignore_texture_size = true
	send.stretch_mode = TextureButton.STRETCH_SCALE
	send.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	send.position = _r(WebHudBar.SEND_BTN).position - o
	send.size = _r(WebHudBar.SEND_BTN).size
	send.focus_mode = Control.FOCUS_NONE
	send.tooltip_text = "Gửi (Enter)"
	send.pressed.connect(func() -> void:
		if _chat_ok():
			_chat.send_now())
	add_child(send)

func _art(tex: Texture2D, rect: Rect2) -> void:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _chat_ok() -> bool:
	return _chat != null and is_instance_valid(_chat)

## Lấy ô gõ / ô kênh / ô tên người nhận của khung chat vào dải. false nếu khung đã bị lấy rồi.
func attach(chat: ChatBox) -> bool:
	var parts := chat.take_web_inputs()
	if parts.is_empty():
		return false
	_chat = chat
	(parts["channel"] as Control).visible = false   ## kênh đổi bằng ô ảnh kênh; ô chọn chỉ còn giữ đồng bộ
	_input_holder.add_child(parts["channel"])
	var input: LineEdit = parts["input"]
	_style_edit(input, WebHudBar.INPUT_COLOR, "")
	_input_holder.add_child(input)
	var to: LineEdit = parts["to"]
	_style_edit(to, TO_COLOR, "Tên người nhận")
	to.visible = true
	_to_holder.add_child(to)
	return true

static func _style_edit(e: LineEdit, color: Color, placeholder: String) -> void:
	e.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	e.flat = true
	for st in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	e.add_theme_color_override("font_color", color)
	e.add_theme_font_size_override("font_size", FONT)
	e.placeholder_text = placeholder

## Kênh Riêng: ô tên người nhận chiếm phần trái ô gõ (TO_W), ô gõ dồn sang phải; kênh khác: ô gõ đủ bề ngang.
func _layout_to(private: bool) -> void:
	if _to_holder.visible == private:
		return
	_to_holder.visible = private
	var shift := TO_W + TO_SEP if private else 0.0
	_input_holder.position = _input_rect.position + Vector2(shift, 0)
	_input_holder.size = _input_rect.size - Vector2(shift, 0)

func _process(_delta: float) -> void:
	if not _chat_ok():
		return
	var ch := _chat.send_channel()
	_layout_to(ch == ChatServer.PRIVATE)
	var ic := ChatBox.channel_icon(str(ch))   ## gốc: [ChannelBtn] hiện ảnh nhúng MenuImage của kênh (KUiPlayerBar::SetCurrentChannel)
	if _channel_btn.icon != ic:
		_channel_btn.icon = ic
	_channel_btn.text = "" if ic != null else ChatServer.CHANNEL_NAMES[ch].substr(0, 1)
	_channel_btn.tooltip_text = "Kênh: %s — bấm để đổi" % ChatServer.CHANNEL_NAMES[ch]

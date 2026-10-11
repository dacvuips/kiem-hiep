extends PanelContainer
class_name ChatBox
## Khung CHAT online (góc trái giữa màn hình): kênh Gần / Thế giới / Tổ đội / Bang hội / Riêng.
## Tin gửi qua game server (ChatServer kiểm tra cấm chat, tốc độ, độ dài). Bấm "Chat" để thu gọn / mở (điện thoại).
## Đang gõ thì phím không điều khiển nhân vật (Player._typing()).

const MAX_LINES := 80
const COLORS := [Color(0.93, 0.93, 0.9), Color(1.0, 0.82, 0.35), Color(0.45, 0.85, 1.0), Color(0.5, 0.95, 0.5), Color(1.0, 0.6, 0.85)]

var _log: RichTextLabel
var _channel: OptionButton
var _to: LineEdit
var _input: LineEdit
var _body: VBoxContainer
var _toggle: Button
var _lines := 0

static func create() -> ChatBox:
	return ChatBox.new()

func _init() -> void:
	add_theme_stylebox_override("panel", SocialUi.box(Color(0.04, 0.035, 0.03, 0.62), Color(0.55, 0.45, 0.25, 0.7), 6, 1, 6))
	custom_minimum_size = Vector2(400, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var head := HBoxContainer.new()
	_toggle = SocialUi.small_button("Chat ▾")
	_toggle.pressed.connect(_on_toggle)
	head.add_child(_toggle)
	head.add_child(SocialUi.label("Enter để gửi", SocialUi.MUTED, 12))
	root.add_child(head)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	root.add_child(_body)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.custom_minimum_size = Vector2(390, 150)
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(_log)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_channel = OptionButton.new()
	for i in ChatServer.CHANNEL_NAMES.size():
		_channel.add_item(ChatServer.CHANNEL_NAMES[i], i)
	_channel.focus_mode = Control.FOCUS_NONE
	_channel.item_selected.connect(func(idx: int) -> void: _to.visible = idx == ChatServer.PRIVATE)
	row.add_child(_channel)
	_to = SocialUi.line_edit("Tên người nhận")
	_to.custom_minimum_size = Vector2(110, 0)
	_to.visible = false
	row.add_child(_to)
	_input = SocialUi.line_edit("Nhập tin nhắn…")
	_input.max_length = ChatServer.MAX_LEN
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t: String) -> void: _send())
	row.add_child(_input)
	var send := SocialUi.small_button("Gửi")
	send.pressed.connect(_send)
	row.add_child(send)
	_body.add_child(row)
	NetClient.chat_received.connect(_on_chat)
	NetClient.server_notice.connect(func(text: String) -> void: add_line("[color=#b8b0a0]%s[/color]" % _esc(text)))

func _on_toggle() -> void:
	_body.visible = not _body.visible
	_toggle.text = "Chat ▾" if _body.visible else "Chat ▸"

func _send() -> void:
	var text := _input.text.strip_edges()
	if text.is_empty():
		_input.release_focus()
		return
	var ch := _channel.get_selected_id()
	if ch == ChatServer.PRIVATE and _to.text.strip_edges().is_empty():
		add_line("[color=#e88]Hãy nhập tên người nhận.[/color]")
		return
	NetClient.send_chat(ch, _to.text.strip_edges(), text)
	_input.text = ""
	_input.release_focus()   ## gửi xong trả phím về cho nhân vật

func _on_chat(channel: int, _from_eid: int, from_name: String, to_name: String, text: String) -> void:
	var color: Color = COLORS[clampi(channel, 0, COLORS.size() - 1)]
	var who := _esc(from_name)
	if channel == ChatServer.PRIVATE:
		who = "%s → %s" % [who, _esc(to_name)]
	add_line("[color=#%s][%s] %s:[/color] %s" % [color.to_html(false), ChatServer.CHANNEL_NAMES[channel], who, _esc(text)])

func add_line(bbcode: String) -> void:
	if _lines >= MAX_LINES:
		_log.remove_paragraph(0)
	else:
		_lines += 1
	_log.append_text(bbcode + "\n")

## Chặn người chơi chèn mã định dạng vào tin nhắn.
static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

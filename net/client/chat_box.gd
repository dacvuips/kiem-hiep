extends PanelContainer
class_name ChatBox
## Khung CHAT online (giữa, sát đáy màn hình): kênh Gần / Thế giới / Tổ đội / Bang hội / Riêng.
## Tin gửi qua game server (ChatServer kiểm tra cấm chat, tốc độ, độ dài). Bấm "Chat" để thu gọn / mở (điện thoại).
## Đang gõ thì phím không điều khiển nhân vật (Player._typing()).

const MAX_LINES := 80
const VISIBLE_STEPS := [3, 10, 20]   ## số dòng thấy được; nút ▲ đổi lần lượt 3 -> 10 -> 20 -> 3
const FONT_SIZE := 13
const COLORS := [Color(0.93, 0.93, 0.9), Color(1.0, 0.82, 0.35), Color(0.45, 0.85, 1.0), Color(0.5, 0.95, 0.5), Color(1.0, 0.6, 0.85)]

var _log: RichTextLabel
var _channel: OptionButton
var _to: LineEdit
var _input: LineEdit
var _body: VBoxContainer
var _toggle: Button
var _lines := 0
var _size_btn: Button
var _step := 0

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
	_size_btn = SocialUi.small_button("▲")
	_size_btn.tooltip_text = "Hiện thêm dòng chat"
	_size_btn.pressed.connect(_on_size)
	head.add_child(_size_btn)
	head.add_child(SocialUi.label("Enter để gửi", SocialUi.MUTED, 12))
	root.add_child(head)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	root.add_child(_body)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.custom_minimum_size = Vector2(390, 0)
	_log.add_theme_font_size_override("normal_font_size", FONT_SIZE)
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

func _ready() -> void:
	_fit_height()

## Chiều cao khung chữ theo font thật (chỉ đọc được theme khi đã vào cây cảnh).
func _fit_height() -> void:
	var lines: int = VISIBLE_STEPS[_step]
	var line_h := _log.get_theme_font("normal_font").get_height(FONT_SIZE) + _log.get_theme_constant("line_separation")
	var pad := _log.get_theme_stylebox("normal").get_minimum_size().y
	_log.custom_minimum_size.y = ceilf(line_h * lines + pad)
	_shrink_to_fit.call_deferred()
	var last := _step == VISIBLE_STEPS.size() - 1
	_size_btn.text = "▼" if last else "▲"
	_size_btn.tooltip_text = "Thu khung chat về %d dòng" % VISIBLE_STEPS[0] if last else "Hiện %d dòng chat" % VISIBLE_STEPS[_step + 1]

## Thu nhỏ lại được: kéo mép trên về sát đáy, Godot tự nới lên đúng chiều cao tối thiểu (grow_vertical = BEGIN).
func _shrink_to_fit() -> void:
	offset_top = offset_bottom

func _on_size() -> void:
	_step = (_step + 1) % VISIBLE_STEPS.size()
	_body.visible = true
	_toggle.text = "Chat ▾"
	_fit_height()

## "Tán gẫu" từ menu người chơi: chuyển sang kênh Riêng, điền tên người nhận, đưa con trỏ vào ô nhập.
func open_whisper(to_name: String) -> void:
	_body.visible = true
	_toggle.text = "Chat ▾"
	_channel.select(ChatServer.PRIVATE)
	_to.visible = true
	_to.text = to_name
	_input.grab_focus()

func _on_toggle() -> void:
	_body.visible = not _body.visible
	_toggle.text = "Chat ▾" if _body.visible else "Chat ▸"
	_shrink_to_fit.call_deferred()

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
	## Sổ đen: bỏ tin nhắn (kênh lẫn nhắn riêng) của người bị chặn — như gốc, chỉ lọc ở máy mình.
	var p := GameManager.local_profile
	if p and p.blacklist.has(from_name) and from_name != p.display_name:
		return
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

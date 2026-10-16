extends CanvasLayer
class_name ChatPanel
## KHUNG TÁN GẪU LỚN trượt ra từ mép TRÁI màn hình (mở từ nút "Tán gẫu" ở Chợ Giao Thương — xem món hàng, và các nơi khác cần chat
## đầy đủ): tab kênh (Tất cả / Gần / Thế giới / Tổ đội / Bang hội / Riêng), lịch sử tin, ô người nhận (kênh Riêng), ô nhập + Gửi.
## Tin gửi qua game server như khung chat nhỏ (ChatBox — cùng luật ChatServer: cấm chat, tốc độ, độ dài; server gửi lại cả tin của mình).
## Lịch sử tin dùng chung (static, tối đa MAX_HISTORY) — NetSocial bắt đầu ghi từ lúc nối server nên mở khung lúc nào cũng thấy tin gần đây.
## Offline: chỉ kênh Gần, tin chỉ hiện ở máy mình.

const WIDTH := 440.0
const SLIDE_SECONDS := 0.22
const MAX_HISTORY := 200
const FONT_SIZE := 14
const ALL := -1
const COLORS := [Color(0.93, 0.93, 0.9), Color(1.0, 0.82, 0.35), Color(0.45, 0.85, 1.0), Color(0.5, 0.95, 0.5), Color(1.0, 0.6, 0.85)]

## Lịch sử: [{channel, from, to, text}] — mới nhất ở cuối.
static var history: Array = []
static var _listening := false
static var _open_panel: ChatPanel = null

var _panel: PanelContainer
var _log: RichTextLabel
var _input: LineEdit
var _to: LineEdit
var _tabs: Array[Button] = []
var _view := ALL                   ## tab đang xem (ALL = mọi kênh)
var _send_channel := ChatServer.NEAR

## Bắt đầu ghi lịch sử tin từ server (gọi 1 lần khi có kết nối — NetSocial._ready). Gọi lại không sao.
static func ensure_listening() -> void:
	if _listening:
		return
	_listening = true
	NetClient.chat_received.connect(func(channel: int, _eid: int, from_name: String, to_name: String, text: String) -> void:
		_push(channel, from_name, to_name, text))

static func _push(channel: int, from_name: String, to_name: String, text: String) -> void:
	var p := GameManager.local_profile
	if p and p.blacklist.has(from_name) and from_name != p.display_name:
		return   ## sổ đen: chỉ lọc ở máy mình (như ChatBox)
	history.append({"channel": channel, "from": from_name, "to": to_name, "text": text})
	if history.size() > MAX_HISTORY:
		history = history.slice(history.size() - MAX_HISTORY)
	if _open_panel != null and is_instance_valid(_open_panel):
		_open_panel._render()

## Mở khung (1 khung / lúc; đang mở thì chỉ đổi kênh). channel = kênh gửi mặc định; to = người nhận khi kênh Riêng.
static func open(host: Node, channel := ChatServer.NEAR, to := "") -> ChatPanel:
	ensure_listening()
	var panel: ChatPanel = _open_panel if _open_panel != null and is_instance_valid(_open_panel) else null
	if panel == null:
		panel = ChatPanel.new()
		host.get_tree().root.add_child(panel)
	panel.set_channel(channel, to)
	return panel

func _ready() -> void:
	layer = 60
	_open_panel = self
	var dim := ColorRect.new()   ## bấm ra ngoài khung = đóng
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", GameUi.box(Color(0.05, 0.045, 0.035, 0.96), Color(0.6, 0.5, 0.28, 0.9), 0, 1, 12))
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -WIDTH
	_panel.offset_right = 0.0
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	var head := HBoxContainer.new()
	var title := GameUi.label("Tán gẫu", GameUi.GOLD, 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := SocialUi.small_button("✕")
	x.tooltip_text = "Đóng"
	x.pressed.connect(close)
	head.add_child(x)
	box.add_child(head)

	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	box.add_child(tabs)
	var names := ["Tất cả"] + Array(ChatServer.CHANNEL_NAMES)
	for i in names.size():
		var b := GameUi.button(str(names[i]), GameUi.TAB)
		b.custom_minimum_size = Vector2(0, 32)
		b.pressed.connect(_on_tab.bind(i - 1))
		tabs.add_child(b)
		_tabs.append(b)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_log.add_theme_stylebox_override("normal", GameUi.box(Color(0, 0, 0, 0.35), Color(0.3, 0.26, 0.18, 0.8), 6, 1, 8))
	box.add_child(_log)

	_to = SocialUi.line_edit("Tên người nhận")
	_to.max_length = 32
	box.add_child(_to)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_input = SocialUi.line_edit("Nhập tin nhắn…")
	_input.max_length = ChatServer.MAX_LEN
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t: String) -> void: _send())
	row.add_child(_input)
	var send := SocialUi.stone_button("Gửi", Vector2(80, 38))
	send.pressed.connect(_send)
	row.add_child(send)
	var hint := GameUi.label("" if NetClient.is_in_world() else "Chơi một mình: chỉ kênh Gần, tin chỉ hiện trên máy bạn.", SocialUi.MUTED, 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.visible = hint.text != ""
	box.add_child(hint)

	create_tween().tween_property(_panel, "offset_left", 0.0, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(_panel, "offset_right", WIDTH, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_render()

func _exit_tree() -> void:
	if _open_panel == self:
		_open_panel = null

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

## Chọn kênh gửi (+ người nhận khi kênh Riêng) và chuyển sang tab kênh đó.
func set_channel(channel: int, to := "") -> void:
	_send_channel = clampi(channel, 0, ChatServer.CHANNEL_NAMES.size() - 1)
	if not is_node_ready():
		await ready
	if _send_channel == ChatServer.PRIVATE and to != "":
		_to.text = to
	_on_tab(_send_channel)
	_input.grab_focus.call_deferred()

## Tab ALL = xem mọi kênh (gửi bằng kênh đang chọn trước đó); tab kênh = xem + gửi kênh đó.
func _on_tab(view: int) -> void:
	_view = view
	if view != ALL:
		_send_channel = view
	for i in _tabs.size():
		GameUi.set_active(_tabs[i], i - 1 == view)
	_to.visible = _send_channel == ChatServer.PRIVATE
	_input.placeholder_text = "Nhập tin nhắn (%s)…" % ChatServer.CHANNEL_NAMES[_send_channel]
	_render()

func _render() -> void:
	if _log == null:
		return
	var lines: PackedStringArray = []
	for m in history:
		var ch := int(m.channel)
		if _view != ALL and ch != _view:
			continue
		var color: Color = COLORS[clampi(ch, 0, COLORS.size() - 1)]
		var who := _esc(str(m.from))
		if ch == ChatServer.PRIVATE:
			who = "%s → %s" % [who, _esc(str(m.to))]
		lines.append("[color=#%s][%s] %s:[/color] %s" % [color.to_html(false), ChatServer.CHANNEL_NAMES[ch], who, _esc(str(m.text))])
	_log.text = "\n".join(lines) if not lines.is_empty() else "[color=#888]Chưa có tin nhắn.[/color]"

func _send() -> void:
	var text := _input.text.strip_edges()
	if text.is_empty():
		return
	var ch := _send_channel
	var to := _to.text.strip_edges()
	if ch == ChatServer.PRIVATE and to.is_empty():
		_note("Hãy nhập tên người nhận.")
		return
	if NetClient.is_in_world():
		NetClient.send_chat(ch, to, text)   ## server gửi lại (cả tin của mình) -> vào lịch sử qua ensure_listening
	elif ch == ChatServer.NEAR:
		var p := GameManager.local_profile
		_push(ch, p.display_name if p else "Bạn", "", text)
	else:
		_note("Kênh %s chỉ dùng khi chơi trên máy chủ." % ChatServer.CHANNEL_NAMES[ch])
		return
	_input.text = ""

func _note(text: String) -> void:
	_log.append_text("\n[color=#e88]%s[/color]" % _esc(text))

func close() -> void:
	var t := create_tween()
	t.tween_property(_panel, "offset_left", -WIDTH, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_panel, "offset_right", 0.0, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

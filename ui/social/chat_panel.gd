extends CanvasLayer
class_name ChatPanel
const ItemChatHelper = preload("res://systems/items/item_chat_helper.gd")
const MapChatHelper = preload("res://systems/map_chat_helper.gd")
## KHUNG TÁN GẪU LỚN trượt ra từ mép TRÁI màn hình (dài từ lề dưới cho tới lề trên):
## Các kênh: Thế giới, Bang hội, Mật (bỏ kênh Gần).
## Giao diện phong cách VLTK theo ảnh tham khảo: Tab kênh dạng pill, thanh thông báo ghim,
## dòng chat phân màu theo kênh, ô gửi & người nhận kênh Mật.

const WIDTH := 860.0
const SLIDE_SECONDS := 0.22
const MAX_HISTORY := 200
const FONT_SIZE := 15

const CHANNELS: Array[int] = [ChatServer.WORLD, ChatServer.GUILD, ChatServer.PRIVATE]
const CHANNEL_NAMES_MAP := {
	ChatServer.WORLD: "Thế giới",
	ChatServer.GUILD: "Bang hội",
	ChatServer.PRIVATE: "Mật",
	ChatServer.NEAR: "Gần",
}
const CHANNEL_COLORS := {
	ChatServer.WORLD: Color(1.0, 0.82, 0.35),   # Gold / Vàng hoàng kim
	ChatServer.GUILD: Color(0.48, 0.95, 0.52),   # Green / Xanh ngọc bang hội
	ChatServer.PRIVATE: Color(1.0, 0.58, 0.88), # Pink / Hồng tím tin mật
	ChatServer.NEAR: Color(0.9, 0.9, 0.9),
}

## Lịch sử: [{channel, from, to, text, time}] — mới nhất ở cuối.
static var history: Array = []
static var _listening := false
static var _open_panel: ChatPanel = null

var _dim: ColorRect
var _panel: PanelContainer
var _log: RichTextLabel
var _input: LineEdit
var _to: LineEdit
var _to_row: HBoxContainer
var _tabs: Dictionary = {}         # channel_int -> Button
var _current_channel: int = ChatServer.WORLD
var _style_tab_active: StyleBoxFlat
var _style_tab_normal: StyleBoxFlat
var _style_tab_hover: StyleBoxFlat
var _attached_items: Dictionary = {} # "[Tên Món]" -> "{item:BASE64}"

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
		return   ## sổ đen: chỉ lọc ở máy mình
	var t := Time.get_time_dict_from_system()
	var time_str := "%02d:%02d" % [t.hour, t.minute]
	history.append({"channel": channel, "from": from_name, "to": to_name, "text": text, "time": time_str})
	if history.size() > MAX_HISTORY:
		history = history.slice(history.size() - MAX_HISTORY)
	if _open_panel != null and is_instance_valid(_open_panel):
		_open_panel._render()

## Mở khung (1 khung / lúc; đang mở thì chỉ đổi kênh).
static func open(host: Node, channel := ChatServer.WORLD, to := "") -> ChatPanel:
	ensure_listening()
	var panel: ChatPanel = _open_panel if _open_panel != null and is_instance_valid(_open_panel) else null
	if panel == null:
		panel = ChatPanel.new()
		var tree := host.get_tree()
		if tree and tree.root:
			tree.root.add_child.call_deferred(panel)
	panel.set_channel(channel, to)
	return panel

## Bật / tắt khung chat (gọi từ nút chat icon kế bên nút TEST)
static func toggle(host: Node, channel := ChatServer.WORLD, to := "") -> void:
	if _open_panel != null and is_instance_valid(_open_panel):
		_open_panel.close()
	else:
		open(host, channel, to)

func _ready() -> void:
	layer = 60
	_open_panel = self

	# Nền tối mờ click ra ngoài để đóng
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.35)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(_dim)

	# Panel trượt dài toàn màn hình từ lề dưới đến lề trên
	_panel = PanelContainer.new()
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.07, 0.08, 0.97)
	panel_sb.border_width_right = 2
	panel_sb.border_color = Color(0.72, 0.58, 0.28, 0.9)
	panel_sb.shadow_color = Color(0, 0, 0, 0.6)
	panel_sb.shadow_size = 14
	panel_sb.content_margin_left = 14.0
	panel_sb.content_margin_right = 14.0
	panel_sb.content_margin_top = 12.0
	panel_sb.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", panel_sb)

	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0
	_panel.offset_left = -WIDTH
	_panel.offset_right = 0.0
	add_child(_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)

	# --- 1. HEADER: Tabs kênh VLTK (Thế giới, Bang hội, Mật) + Nút Đóng ---
	_setup_tab_styles()
	var head_bar := HBoxContainer.new()
	head_bar.add_theme_constant_override("separation", 6)
	main_vbox.add_child(head_bar)

	var tabs_container := HBoxContainer.new()
	tabs_container.add_theme_constant_override("separation", 6)
	tabs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_bar.add_child(tabs_container)

	for ch in CHANNELS:
		var tab_name: String = CHANNEL_NAMES_MAP.get(ch, "Kênh")
		var b := Button.new()
		b.text = tr(tab_name)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(110, 34)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void: _on_tab(ch))
		tabs_container.add_child(b)
		_tabs[ch] = b

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.tooltip_text = tr("Đóng tán gẫu")
	var close_sb := _make_pill_style(Color(0.18, 0.08, 0.08, 0.9), Color(0.65, 0.25, 0.25, 0.8), 8)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
	close_btn.pressed.connect(close)
	head_bar.add_child(close_btn)

	# --- 2. THANH GHIM / THÔNG BÁO QUẢN TRỊ (như ảnh mẫu) ---
	var notice_box := PanelContainer.new()
	var notice_sb := StyleBoxFlat.new()
	notice_sb.bg_color = Color(0.12, 0.11, 0.09, 0.85)
	notice_sb.border_width_left = 1
	notice_sb.border_width_top = 1
	notice_sb.border_width_right = 1
	notice_sb.border_width_bottom = 1
	notice_sb.border_color = Color(0.55, 0.45, 0.22, 0.7)
	notice_sb.corner_radius_top_left = 6
	notice_sb.corner_radius_top_right = 6
	notice_sb.corner_radius_bottom_right = 6
	notice_sb.corner_radius_bottom_left = 6
	notice_sb.content_margin_left = 8.0
	notice_sb.content_margin_right = 8.0
	notice_sb.content_margin_top = 5.0
	notice_sb.content_margin_bottom = 5.0
	notice_box.add_theme_stylebox_override("panel", notice_sb)
	main_vbox.add_child(notice_box)

	var notice_lbl := RichTextLabel.new()
	notice_lbl.bbcode_enabled = true
	notice_lbl.fit_content = true
	notice_lbl.scroll_active = false
	notice_lbl.text = "[color=#FFD54F]%s:[/color] [color=#DDD4C0]%s[/color]" % [tr("📌 Quản trị"), tr("Chào mừng hiệp khách! Tán gẫu văn minh, hảo hữu bốn phương tụ hội.")]
	notice_lbl.add_theme_font_size_override("normal_font_size", 12)
	notice_box.add_child(notice_lbl)

	# --- 3. KHUNG HIỂN THỊ TIN NHẮN (RichTextLabel) ---
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_log.meta_clicked.connect(_on_meta_clicked)
	var log_sb := StyleBoxFlat.new()
	log_sb.bg_color = Color(0.03, 0.04, 0.05, 0.75)
	log_sb.border_width_left = 1
	log_sb.border_width_top = 1
	log_sb.border_width_right = 1
	log_sb.border_width_bottom = 1
	log_sb.border_color = Color(0.28, 0.32, 0.32, 0.6)
	log_sb.corner_radius_top_left = 6
	log_sb.corner_radius_top_right = 6
	log_sb.corner_radius_bottom_right = 6
	log_sb.corner_radius_bottom_left = 6
	log_sb.content_margin_left = 10.0
	log_sb.content_margin_right = 10.0
	log_sb.content_margin_top = 8.0
	log_sb.content_margin_bottom = 8.0
	_log.add_theme_stylebox_override("normal", log_sb)
	main_vbox.add_child(_log)

	# --- 4. HÀNG NGƯỜI NHẬN (chỉ hiện khi kênh Mật) ---
	_to_row = HBoxContainer.new()
	_to_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_to_row)

	var to_lbl := Label.new()
	to_lbl.text = tr("Gửi đến:")
	to_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.9))
	to_lbl.add_theme_font_size_override("font_size", 13)
	_to_row.add_child(to_lbl)

	_to = LineEdit.new()
	_to.placeholder_text = tr("Nhập tên nhân vật nhận...")
	_to.max_length = 32
	_to.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(_to)
	_to_row.add_child(_to)
	_to_row.visible = false

	# --- 5. HÀNG NHẬP TIN NHẮN (Emoji + LineEdit + Nút Gửi) ---
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(input_row)

	var emoji_btn := Button.new()
	emoji_btn.text = "😊"
	emoji_btn.tooltip_text = tr("Biểu cảm nhanh")
	emoji_btn.focus_mode = Control.FOCUS_NONE
	emoji_btn.custom_minimum_size = Vector2(38, 38)
	var emo_sb := _make_pill_style(Color(0.12, 0.16, 0.18, 0.9), Color(0.72, 0.58, 0.28, 0.8), 6)
	emoji_btn.add_theme_stylebox_override("normal", emo_sb)
	emoji_btn.pressed.connect(_on_emoji_pressed)
	input_row.add_child(emoji_btn)

	var map_btn := Button.new()
	map_btn.text = "🗺️"
	map_btn.tooltip_text = tr("Chia sẻ ID phòng / bản đồ hiện tại vào khung chat")
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.custom_minimum_size = Vector2(38, 38)
	var map_sb := _make_pill_style(Color(0.12, 0.16, 0.18, 0.9), Color(0.28, 0.65, 0.82, 0.8), 6)
	map_btn.add_theme_stylebox_override("normal", map_sb)
	map_btn.pressed.connect(_on_map_share_pressed)
	input_row.add_child(map_btn)

	_input = LineEdit.new()
	_input.placeholder_text = tr("Nhập nội dung tán gẫu... (Enter để gửi)")
	_input.max_length = ChatServer.MAX_LEN
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 38)
	_style_line_edit(_input)
	_input.text_submitted.connect(func(_t: String) -> void: _send())
	input_row.add_child(_input)

	var send_btn := Button.new()
	send_btn.text = tr("Gửi")
	send_btn.focus_mode = Control.FOCUS_NONE
	send_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	send_btn.custom_minimum_size = Vector2(72, 38)
	var send_sb := _make_pill_style(Color(0.85, 0.65, 0.2, 1.0), Color(1.0, 0.88, 0.5, 1.0), 6)
	var send_hover_sb := _make_pill_style(Color(0.95, 0.75, 0.25, 1.0), Color(1.0, 0.95, 0.7, 1.0), 6)
	send_btn.add_theme_stylebox_override("normal", send_sb)
	send_btn.add_theme_stylebox_override("hover", send_hover_sb)
	send_btn.add_theme_stylebox_override("pressed", send_hover_sb)
	send_btn.add_theme_color_override("font_color", Color(0.12, 0.1, 0.05))
	send_btn.add_theme_font_size_override("font_size", 14)
	send_btn.pressed.connect(_send)
	input_row.add_child(send_btn)

	# Khởi tạo tin mẫu phong phú nếu chưa có lịch sử
	if history.is_empty():
		_push(ChatServer.WORLD, tr("Lệnh Hồ Xung"), "", tr("Hôm nay ai cùng ta tỉ thí kiếm pháp tại Hoa Sơn?"))
		_push(ChatServer.WORLD, tr("Tiểu Long Nữ"), "", tr("Cổ Mộ phái chiêu mộ đệ tử, hoan nghênh chư vị đồng đạo."))
		var demo_sword := ItemGenerator.generate_gold(0) if ItemDatabase.get_gold(0).size() > 0 else null
		if demo_sword:
			_push(ChatServer.WORLD, tr("Độc Cô Cầu Bại"), "", tr("Cần nhượng lại bảo kiếm %s cho cao thủ hữu duyên!") % ItemChatHelper.create_token(demo_sword))
		_push(ChatServer.GUILD, tr("Bang Chủ"), "", tr("Tối nay 20h anh em tập hợp đánh Boss bang nhé!"))

	# Hiệu ứng trượt ra mượt mà từ mép trái màn hình
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, "offset_left", 0.0, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "offset_right", WIDTH, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_on_tab(_current_channel)

func _setup_tab_styles() -> void:
	# Active: Pill màu vàng hoàng kim với chữ đen đậm
	_style_tab_active = _make_pill_style(Color(0.92, 0.72, 0.25, 1.0), Color(1.0, 0.88, 0.55, 1.0), 14)
	# Normal: Pill nền tối viền xám tro
	_style_tab_normal = _make_pill_style(Color(0.12, 0.15, 0.17, 0.9), Color(0.35, 0.42, 0.42, 0.7), 14)
	# Hover: Pill sáng nhẹ
	_style_tab_hover = _make_pill_style(Color(0.18, 0.24, 0.27, 0.95), Color(0.65, 0.72, 0.72, 0.9), 14)

func _make_pill_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb

func _style_line_edit(le: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.11, 0.95)
	sb.border_color = Color(0.35, 0.4, 0.4, 0.8)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	le.add_theme_stylebox_override("normal", sb)

	var sb_focus := sb.duplicate() as StyleBoxFlat
	sb_focus.border_color = Color(0.9, 0.75, 0.35, 1.0)
	le.add_theme_stylebox_override("focus", sb_focus)

func _exit_tree() -> void:
	if _open_panel == self:
		_open_panel = null

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

## Chọn kênh gửi (+ người nhận khi kênh Mật/Riêng) và chuyển sang tab kênh đó.
func set_channel(channel: int, to := "") -> void:
	_current_channel = channel
	if not is_node_ready():
		await ready
	if _to != null and to != "":
		_to.text = to
	_on_tab(channel)
	if _input != null:
		_input.grab_focus.call_deferred()

## Chuyển tab kênh chat
func _on_tab(channel: int) -> void:
	_current_channel = channel
	for ch_key in _tabs:
		var btn: Button = _tabs[ch_key]
		var is_active: bool = (int(ch_key) == channel)
		if is_active:
			btn.add_theme_stylebox_override("normal", _style_tab_active)
			btn.add_theme_stylebox_override("hover", _style_tab_active)
			btn.add_theme_stylebox_override("pressed", _style_tab_active)
			btn.add_theme_color_override("font_color", Color(0.12, 0.1, 0.05))
		else:
			btn.add_theme_stylebox_override("normal", _style_tab_normal)
			btn.add_theme_stylebox_override("hover", _style_tab_hover)
			btn.add_theme_stylebox_override("pressed", _style_tab_hover)
			btn.add_theme_color_override("font_color", Color(0.82, 0.84, 0.8))

	if _to_row != null:
		_to_row.visible = (channel == ChatServer.PRIVATE)

	var ch_name: String = CHANNEL_NAMES_MAP.get(channel, "kênh")
	if _input != null:
		_input.placeholder_text = "%s %s... (Enter %s)" % [tr("Tán gẫu"), tr(ch_name), tr("để gửi")]

	_render()

## Vẽ danh sách tin nhắn theo kênh đang chọn
func _render() -> void:
	if _log == null:
		return
	var lines: PackedStringArray = []
	for m in history:
		var ch := int(m.get("channel", ChatServer.WORLD))
		# Lọc theo kênh hiện tại
		if ch != _current_channel and _current_channel != ChatServer.NEAR:
			# Ngoại lệ: kênh Mật chỉ hiện tin Mật, Bang chỉ hiện Bang, Thế giới chỉ hiện Thế giới
			continue

		var color: Color = CHANNEL_COLORS.get(ch, Color.WHITE)
		var ch_label: String = tr(CHANNEL_NAMES_MAP.get(ch, "Kênh"))
		var time_str: String = str(m.get("time", "12:00"))
		var who := _esc(str(m.get("from", "Đại Hiệp")))

		var header_part := ""
		if ch == ChatServer.PRIVATE:
			var to_str := _esc(str(m.get("to", "")))
			header_part = "[color=#%s][%s][/color] [color=#F48FB1]%s → %s:[/color]" % [color.to_html(false), ch_label, who, to_str]
		else:
			header_part = "[color=#%s][%s][/color] [color=#FFE082]%s:[/color]" % [color.to_html(false), ch_label, who]

		var body_bbcode := ItemChatHelper.format_chat_bbcode(str(m.get("text", "")))
		body_bbcode = MapChatHelper.format_chat_map_bbcode(body_bbcode)
		lines.append("[color=#757D84]%s[/color] %s [color=#ECEFF1]%s[/color]" % [time_str, header_part, body_bbcode])

	if lines.is_empty():
		var ch_name: String = tr(CHANNEL_NAMES_MAP.get(_current_channel, "này"))
		_log.text = "\n[center][color=#606870]— %s %s —[/color][/center]" % [tr("Chưa có tin nhắn trong kênh"), ch_name]
	else:
		_log.text = "\n".join(lines)

## Gắn liên kết vật phẩm vào ô gõ tin nhắn
func insert_item(item: ItemInstance) -> void:
	if item == null:
		return
	var item_name := str(item.get_base().get("name", "Vật phẩm"))
	var tag := "[%s]" % item_name
	var token := ItemChatHelper.create_token(item)
	_attached_items[tag] = token
	insert_text(tag)

## Chèn chuỗi văn bản (link map, tag...) vào ô gõ tin nhắn
func insert_text(text_to_insert: String) -> void:
	if not is_node_ready():
		await ready

	if _input != null:
		var cur := _input.text.strip_edges()
		if cur.is_empty():
			_input.text = text_to_insert + " "
		else:
			_input.text = cur + " " + text_to_insert + " "
		_input.grab_focus()
		_input.caret_column = _input.text.length()

## Khi người dùng nhấp vào link trong khung chat
func _on_meta_clicked(meta: Variant) -> void:
	var meta_str := str(meta)
	if meta_str.begins_with("item:"):
		var raw_data := meta_str.substr(5)
		var item := ItemChatHelper.decode_item(raw_data)
		if item != null:
			ItemDetailPopup.open(get_tree().root, ItemText.build(item, GameManager.local_profile, -1, -1, false), [], item)
	elif meta_str.begins_with("map:"):
		var map_id := meta_str.substr(4)
		MapChatHelper.confirm_and_teleport(map_id, self)

func _send() -> void:
	if _input == null:
		return
	var text := _input.text.strip_edges()
	if text.is_empty():
		return
	var ch := _current_channel
	var to := _to.text.strip_edges() if _to != null else ""
	if ch == ChatServer.PRIVATE and to.is_empty():
		_note(tr("Hãy nhập tên người nhận trong kênh Mật."))
		return

	# Thay thế các tag [Tên Món] đã gắn bằng token {item:BASE64}
	for tag in _attached_items:
		if text.contains(tag):
			text = text.replace(tag, _attached_items[tag])
	_attached_items.clear()

	if NetClient.is_in_world():
		NetClient.send_chat(ch, to, text)
	else:
		# Chơi offline / Hub: thêm vào lịch sử để kiểm tra giao diện và lưu trữ
		var p := GameManager.local_profile
		_push(ch, p.display_name if p else "Đại Hiệp", to, text)

	_input.text = ""

func _note(text: String) -> void:
	if _log != null:
		_log.append_text("\n[color=#FF7043]⚠ %s[/color]" % _esc(text))

func _on_emoji_pressed() -> void:
	if _input == null:
		return
	var emojis := ["(^-^)", "(≧◡≦)", "(>_<)", "[Võ Lâm]", "[PK]", "[Hảo Hữu]"]
	var pick: String = emojis[randi() % emojis.size()]
	_input.text += (" " if not _input.text.is_empty() and not _input.text.ends_with(" ") else "") + pick
	_input.grab_focus()
	_input.caret_column = _input.text.length()

func _on_map_share_pressed() -> void:
	MapChatHelper.share_current_room_to_chat(self)

func close() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_panel, "offset_left", -WIDTH, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_panel, "offset_right", 0.0, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_dim, "color:a", 0.0, SLIDE_SECONDS)
	t.chain().tween_callback(queue_free)

static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

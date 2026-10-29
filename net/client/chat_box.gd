extends PanelContainer

class_name ChatBox

const ItemChatHelper = preload("res://systems/items/item_chat_helper.gd")
const MapChatHelper = preload("res://systems/map_chat_helper.gd")

## Khung CHAT online (giữa, sát đáy màn hình): không có ô chọn kênh — tin gửi luôn vào kênh Gần; "Tán gẫu" từ menu người chơi

## (open_whisper) mới chuyển sang nhắn Riêng cho 1 tin (hiện ô tên người nhận). Tin nhận về vẫn hiện đủ mọi kênh.

## Tin gửi qua game server (ChatServer kiểm tra cấm chat, tốc độ, độ dài). Vào game khung THU GỌN (ẩn phần tin); bấm "Chat" để

## mở / thu gọn — hàng nhập (kênh mặc định "Gần") luôn hiện. Chơi offline (map luyện công): vẫn có khung, tin kênh Gần chỉ hiện ở máy mình.

## Đang gõ thì phím không điều khiển nhân vật (Player._typing()).

const MAX_LINES := 80

const VISIBLE_STEPS := [3, 10, 20]   ## số dòng thấy được; nút ▲ đổi lần lượt 3 -> 10 -> 20 -> 3

const FONT_SIZE := 13

const COLORS := [Color(0.93, 0.93, 0.9), Color(1.0, 0.82, 0.35), Color(0.45, 0.85, 1.0), Color(0.5, 0.95, 0.5), Color(1.0, 0.6, 0.85)]

enum Tab { ALL, SYSTEM }

var _log: RichTextLabel

var _channel := ChatServer.NEAR

var _to: LineEdit

var _input: LineEdit

var _body: VBoxContainer

var _toggle: Button

var _lines := 0

var _size_btn: Button

var _step := 0

var _current_tab: Tab = Tab.ALL

var _tab_all: Button

var _tab_sys: Button

var _messages: Array[Dictionary] = []
var _attached_items: Dictionary = {} # "[Tên Món]" -> "{item:BASE64}"

static var current: ChatBox = null

static func create() -> ChatBox:

	return ChatBox.new()

## Gửi thông báo hệ thống vào khung chat

static func push_system(bbcode: String) -> void:

	if current != null and is_instance_valid(current):

		current.add_line(bbcode, true)

		current._body.visible = true

		current._toggle.text = "Chat ▾"

		current._shrink_to_fit.call_deferred()

## Gửi thông báo nhận kinh nghiệm khi diệt quái vào khung chat

static func push_exp(monster_name: String, exp_amount: int) -> void:

	if exp_amount <= 0:

		return

	var nm := monster_name.strip_edges()

	if nm.is_empty():

		nm = "Quái"

	var text := "[color=#ffaa00][Hệ thống][/color] Đánh bại [color=#ffff77]%s[/color], nhận được [color=#55ff55]+%s[/color] kinh nghiệm." % [

		nm,

		InventoryPopup.format_money(exp_amount)

	]

	push_system(text)

## Đặt khung chat vào giữa đáy màn chơi (node "UI" của Main).

static func attach(ui: Node) -> ChatBox:

	var box := ChatBox.create()

	current = box

	box.name = "ChatBox"

	ui.add_child(box)

	box.apply_hud_layout()

	return box

func apply_hud_layout() -> void:

	anchor_left = 0.5

	anchor_right = 0.5

	anchor_top = 1.0

	anchor_bottom = 1.0

	grow_horizontal = Control.GROW_DIRECTION_BOTH

	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var d := HudLayout.get_element("chat_box")

	var w: float = float(d.get("width", 400.0))

	var sc: float = float(d.get("scale", 1.0))

	var ox: float = float(d.get("offset_x", 0.0))

	var oy: float = float(d.get("offset_y", 0.0))

	custom_minimum_size = Vector2(w, 0)

	size.x = w

	offset_left = -w + ox

	offset_right = 0.0 + ox

	offset_top = -8.0 + oy

	offset_bottom = -8.0 + oy

	scale = Vector2.ONE * sc

func _notification(what: int) -> void:

	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:

		HudLayout.remove_listener(apply_hud_layout)

		if current == self:

			current = null

func _init() -> void:

	current = self

	HudLayout.add_listener(apply_hud_layout)

	add_theme_stylebox_override("panel", SocialUi.box(Color(0.04, 0.035, 0.03, 0.62), Color(0.55, 0.45, 0.25, 0.7), 6, 1, 6))

	custom_minimum_size = Vector2(400, 0)

	var root := VBoxContainer.new()

	root.add_theme_constant_override("separation", 4)

	add_child(root)

	var head := HBoxContainer.new()

	_toggle = SocialUi.small_button("Chat ▸")

	_toggle.pressed.connect(_on_toggle)

	head.add_child(_toggle)

	_size_btn = SocialUi.small_button("▲")

	_size_btn.tooltip_text = "Hiện thêm dòng chat"

	_size_btn.pressed.connect(_on_size)

	head.add_child(_size_btn)

	_tab_all = SocialUi.small_button("Tất cả")

	_tab_all.add_theme_font_size_override("font_size", 12)

	_tab_all.tooltip_text = "Xem tất cả tin nhắn và hệ thống"

	_tab_all.pressed.connect(func() -> void: _set_tab(Tab.ALL))

	head.add_child(_tab_all)

	_tab_sys = SocialUi.small_button("Hệ thống")

	_tab_sys.add_theme_font_size_override("font_size", 12)

	_tab_sys.tooltip_text = "Chỉ xem thông báo hệ thống và kinh nghiệm"

	_tab_sys.pressed.connect(func() -> void: _set_tab(Tab.SYSTEM))

	head.add_child(_tab_sys)

	_update_tab_buttons()

	head.add_child(SocialUi.label("Enter để gửi", SocialUi.MUTED, 12))

	root.add_child(head)

	_body = VBoxContainer.new()

	_body.add_theme_constant_override("separation", 4)

	_body.visible = false   ## mặc định THU GỌN: chỉ hàng đầu + hàng nhập; bấm "Chat ▸" / ▲ để xem tin

	root.add_child(_body)

	_log = RichTextLabel.new()

	_log.bbcode_enabled = true

	_log.scroll_following = true

	_log.fit_content = false

	_log.custom_minimum_size = Vector2(390, 0)

	_log.add_theme_font_size_override("normal_font_size", FONT_SIZE)

	_log.mouse_filter = Control.MOUSE_FILTER_PASS

	_log.meta_clicked.connect(_on_meta_clicked)

	_body.add_child(_log)

	var row := HBoxContainer.new()

	row.add_theme_constant_override("separation", 4)

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

	root.add_child(row)   ## hàng nhập nằm ngoài phần thu gọn -> luôn hiện

	NetClient.chat_received.connect(_on_chat)

	NetClient.server_notice.connect(func(text: String) -> void: add_line("[color=#b8b0a0]%s[/color]" % _esc(text), true))

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

	_channel = ChatServer.PRIVATE

	_to.visible = true

	_to.text = to_name

	_input.grab_focus()

func _on_toggle() -> void:

	_body.visible = not _body.visible

	_toggle.text = "Chat ▾" if _body.visible else "Chat ▸"

	_shrink_to_fit.call_deferred()

func _set_tab(tab: Tab) -> void:

	if _current_tab == tab and _body.visible:

		return

	_current_tab = tab

	_update_tab_buttons()

	if not _body.visible:

		_body.visible = true

		_toggle.text = "Chat ▾"

		_shrink_to_fit.call_deferred()

	_rebuild_log()

func _update_tab_buttons() -> void:

	if _tab_all == null or _tab_sys == null:

		return

	if _current_tab == Tab.ALL:

		_tab_all.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))

		_tab_sys.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))

	else:

		_tab_all.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))

		_tab_sys.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))

func _rebuild_log() -> void:

	if _log == null:

		return

	_log.text = ""

	_lines = 0

	for m in _messages:

		var is_sys: bool = bool(m.get("is_system", false))

		var show := (_current_tab == Tab.ALL) or (_current_tab == Tab.SYSTEM and is_sys)

		if show:

			if _lines >= MAX_LINES:

				_log.remove_paragraph(0)

			else:

				_lines += 1

			_log.append_text(str(m.get("text", "")) + "\n")

func _handle_slash_command(cmd: String) -> bool:

	var parts := cmd.strip_edges().split(" ", false)

	if parts.is_empty():

		return false

	var keyword := parts[0].to_lower()

	var p := GameManager.local_profile

	if keyword == "/knb":

		if not GmManager.is_gm() and not OS.is_debug_build():

			push_system("[color=#ff4444][Hệ thống][/color] Lệnh này chỉ dành cho GM (Quản trị viên).")

			return true

		var amount := 1000

		if parts.size() > 1 and parts[1].is_valid_int():

			amount = clampi(int(parts[1]), 1, 100_000_000)

		if p:

			p.jade += amount

			SaveManager.save_profile(p)

			GmManager.log_action("CMD_KNB", p.display_name, "+%d KNB" % amount)

			if NetClient.is_in_world():

				NetClient.send_profile(p.to_dict())

		if NetClient.is_in_world():

			NetClient.send_chat(ChatServer.NEAR, "", cmd)

		push_system("[color=#ffaa00][GM][/color] Đã nhận [color=#55ff55]+%s[/color] KNB (Kim Nguyên Bảo)." % InventoryPopup.format_money(amount))

		return true

	if keyword == "/xu":

		if not GmManager.is_gm() and not OS.is_debug_build():

			push_system("[color=#ff4444][Hệ thống][/color] Lệnh này chỉ dành cho GM (Quản trị viên).")

			return true

		var amount := 1000

		if parts.size() > 1 and parts[1].is_valid_int():

			amount = clampi(int(parts[1]), 1, 100_000_000)

		if p:

			p.xu += amount

			SaveManager.save_profile(p)

			GmManager.log_action("CMD_XU", p.display_name, "+%d Xu" % amount)

			if NetClient.is_in_world():

				NetClient.send_profile(p.to_dict())

		if NetClient.is_in_world():

			NetClient.send_chat(ChatServer.NEAR, "", cmd)

		push_system("[color=#ffaa00][GM][/color] Đã nhận [color=#55ff55]+%s[/color] Tiền Xu." % InventoryPopup.format_money(amount))

		return true

	if keyword in ["/ttl", "/tienthaolo"]:

		if not GmManager.is_gm() and not OS.is_debug_build():

			push_system("[color=#ff4444][Hệ thống][/color] Lệnh này chỉ dành cho GM (Quản trị viên).")

			return true

		if p:

			var ttl_1h := ItemGenerator.generate_misc("6_1_71")

			var ttl_8h := ItemGenerator.generate_misc("6_1_1181")

			var ttl_hoan := ItemGenerator.generate_misc("6_1_113")

			var knb_item := ItemGenerator.generate_misc("6_1_1877")

			var added := 0

			if ttl_1h and p.add_item(ttl_1h): added += 1

			if ttl_8h and p.add_item(ttl_8h): added += 1

			if ttl_hoan and p.add_item(ttl_hoan): added += 1

			if knb_item and p.add_item(knb_item): added += 1

			SaveManager.save_profile(p)

			if NetClient.is_in_world():

				NetClient.send_chat(ChatServer.NEAR, "", cmd)

				NetClient.send_profile(p.to_dict())

			if added > 0:

				push_system("[color=#ffaa00][Hệ thống][/color] Đã thêm %d vật phẩm (Tiên Thảo Lộ 1h, 8h, Hoàn, Kim Nguyên Bảo) vào hành trang." % added)

			else:

				push_system("[color=#ff5555][Hệ thống][/color] Hành trang đã đầy, không thể nhận thêm vật phẩm.")

		return true

	if keyword == "/help":

		push_system("[color=#ffaa00][Hệ thống][/color] Lệnh có sẵn: [color=#ffff77]/knb [số][/color] (tạo KNB), [color=#ffff77]/ttl[/color] (tạo bình Tiên Thảo Lộ & KNB).")

		return true

	return false

func _send() -> void:

	var text := _input.text.strip_edges()

	if text.is_empty():

		_input.release_focus()

		return

	if text.begins_with("/"):

		if _handle_slash_command(text):

			_input.text = ""

			_input.release_focus()

			return

	var ch := _channel

	if ch == ChatServer.PRIVATE and _to.text.strip_edges().is_empty():

		add_line("[color=#e88]Hãy nhập tên người nhận.[/color]", true)

		return

	# Thay thế tag [Tên Món] bằng token {item:BASE64}
	for tag in _attached_items:
		if text.contains(tag):
			text = text.replace(tag, _attached_items[tag])
	_attached_items.clear()

	if NetClient.is_in_world():

		NetClient.send_chat(ch, _to.text.strip_edges(), text)

	elif ch == ChatServer.NEAR:   ## offline: không có ai khác, chỉ hiện ở máy mình

		var p := GameManager.local_profile

		_on_chat(ch, 0, p.display_name if p else "Bạn", "", text)

	else:

		add_line("[color=#e88]Kênh %s chỉ dùng khi chơi trên máy chủ.[/color]" % ChatServer.CHANNEL_NAMES[ch], true)

	_input.text = ""

	_input.release_focus()   ## gửi xong trả phím về cho nhân vật

	if ch == ChatServer.PRIVATE:   ## nhắn riêng xong quay về kênh Gần

		_channel = ChatServer.NEAR

		_to.visible = false

		_to.text = ""

func _on_chat(channel: int, from_eid: int, from_name: String, to_name: String, text: String) -> void:

	## Sổ đen: bỏ tin nhắn (kênh lẫn nhắn riêng) của người bị chặn — như gốc, chỉ lọc ở máy mình.

	var p := GameManager.local_profile

	if p and p.blacklist.has(from_name) and from_name != p.display_name:

		return

	var color: Color = COLORS[clampi(channel, 0, COLORS.size() - 1)]

	var who := _esc(from_name)

	if channel == ChatServer.PRIVATE:

		who = "%s → %s" % [who, _esc(to_name)]

	var body_bbcode := ItemChatHelper.format_chat_bbcode(text)
	body_bbcode = MapChatHelper.format_chat_map_bbcode(body_bbcode)
	add_line("[color=#%s][%s] %s:[/color] %s" % [color.to_html(false), ChatServer.CHANNEL_NAMES[channel], who, body_bbcode], false)

	if channel == ChatServer.NEAR:

		var clean_text := ItemChatHelper.clean_item_tags_for_plain_text(text)
		ChatBubble.show_on(_speaker_node(from_eid), from_name, clean_text)

## Gắn liên kết vật phẩm vào ô gõ tin nhắn của ChatBox
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
	if _input != null:
		var cur := _input.text.strip_edges()
		if cur.is_empty():
			_input.text = text_to_insert + " "
		else:
			_input.text = cur + " " + text_to_insert + " "
		_input.grab_focus()
		_input.caret_column = _input.text.length()

## Khi người dùng bấm vào link trong ChatBox
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

## Nhân vật đang nói: chính mình (eid của mình / offline eid 0) hoặc người chơi khác đang thấy.

func _speaker_node(eid: int) -> Node2D:

	if eid == 0 or eid == NetClient.my_eid:

		return get_tree().get_first_node_in_group("player") as Node2D

	return NetWorldSync.current.remote_of(eid) if NetWorldSync.current else null

func add_line(bbcode: String, is_system := false) -> void:

	_messages.append({"text": bbcode, "is_system": is_system})

	if _messages.size() > MAX_LINES:

		_messages.pop_front()

	var show := (_current_tab == Tab.ALL) or (_current_tab == Tab.SYSTEM and is_system)

	if show:

		if _lines >= MAX_LINES:

			_log.remove_paragraph(0)

		else:

			_lines += 1

		_log.append_text(bbcode + "\n")

## Chặn người chơi chèn mã định dạng vào tin nhắn.

static func _esc(s: String) -> String:

	return s.replace("[", "[lb]")


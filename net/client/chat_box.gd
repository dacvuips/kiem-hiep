extends PanelContainer

class_name ChatBox

const ItemChatHelper = preload("res://systems/items/item_chat_helper.gd")
const MapChatHelper = preload("res://systems/map_chat_helper.gd")

## Khung CHAT online (giữa, sát đáy màn hình): ô chọn kênh gửi (Gần / Tổ đội / Môn phái / Bang hội / Thế giới / Riêng) trước ô nhập,
## ô chọn bộ lọc xem (Tất cả / Hệ thống / từng kênh) ở hàng đầu. "Tán gẫu" từ menu người chơi (open_whisper) chọn sẵn kênh Riêng.
## Kinh nghiệm hạ quái KHÔNG ghi vào chat: hiện "+số EXP" nổi trên mép phải khung chat (push_exp).

## Tin gửi qua game server (ChatServer kiểm tra cấm chat, tốc độ, độ dài). Vào game khung THU GỌN (ẩn phần tin); bấm "Chat" để

## mở / thu gọn — hàng nhập (kênh mặc định "Gần") luôn hiện. Chơi offline (map luyện công): vẫn có khung, tin kênh Gần chỉ hiện ở máy mình.

## Đang gõ thì phím không điều khiển nhân vật (Player._typing()).

const MAX_LINES := 80

const VISIBLE_STEPS := [3, 10, 20]   ## số dòng thấy được; nút ▲ đổi lần lượt 3 -> 10 -> 20 -> 3

const FONT_SIZE := 13

const COLORS := [Color(0.93, 0.93, 0.9), Color(1.0, 0.82, 0.35), Color(0.45, 0.85, 1.0), Color(0.5, 0.95, 0.5), Color(1.0, 0.6, 0.85), Color(1.0, 0.62, 0.3)]

enum Tab { ALL, SYSTEM, CHANNEL }

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

var _messages: Array[Dictionary] = []
var _attached_items: Dictionary = {} # "[Tên Món]" -> "{item:BASE64}"
## Chữ "Đang treo máy..." vàng, nhấp nháy + chạy dấu chấm, nằm trên mép khung chat 5px khi Auto bật.
const AFK_GAP := 5.0
var _afk_label: Label
var _afk_time := 0.0
## Chữ "+EXP" nổi: tối đa EXP_ROWS nhãn dùng lại (không tạo / xoá node mỗi lần hạ quái).
const EXP_ROWS := 3
const EXP_LIFE := 3.0
const EXP_RISE := 18.0      ## px bay lên trong suốt EXP_LIFE
const EXP_ROW_GAP := 2.0
var _exp_pool: Array[Label] = []
var _exp_rows: Array[Dictionary] = []   ## [{label, age}] — cũ nhất ở đầu
## Kênh gửi (ô chọn ở hàng nhập) và bộ lọc xem (ô chọn ở hàng đầu) — dạng select như khung chat gốc, không bày hàng nút.
const SEND_CHANNELS: Array[int] = [ChatServer.NEAR, ChatServer.TEAM, ChatServer.FACTION, ChatServer.GUILD, ChatServer.WORLD, ChatServer.PRIVATE]
var _channel_pick: OptionButton
var _view_pick: OptionButton
var _view_channel := -1   ## Tab.CHANNEL: chỉ xem kênh này

static var current: ChatBox = null
## Tin nhắn riêng phát sinh khi chưa có khung chat (VD chat mật trong phòng chờ PUBG ở Hub) — đổ vào khi khung chat dựng xong.
static var _pending_lines: Array[String] = []

## Lưu 1 tin nhắn riêng (kênh "Riêng") vào khung chat chính, kể cả khi khung chat chưa có mặt.
static func push_private(from_name: String, to_name: String, text: String) -> void:
	var color: Color = COLORS[ChatServer.PRIVATE]
	var line := "[color=#%s][%s] %s → %s:[/color] %s" % [color.to_html(false), ChatServer.CHANNEL_NAMES[ChatServer.PRIVATE], _esc(from_name), _esc(to_name), _esc(text)]
	if current != null and is_instance_valid(current) and current._log != null:
		current.add_line(line, false, ChatServer.PRIVATE)
	else:
		_pending_lines.append(line)
		if _pending_lines.size() > MAX_LINES:
			_pending_lines.pop_front()

static func create() -> ChatBox:

	return ChatBox.new()

## Gửi thông báo hệ thống vào khung chat

static func push_system(bbcode: String) -> void:

	if current != null and is_instance_valid(current):

		current.add_line(bbcode, true)

		current._body.visible = true

		current._toggle.text = "Chat ▾"

		current._shrink_to_fit.call_deferred()

## Nhận kinh nghiệm khi diệt quái: KHÔNG ghi vào khung chat — hiện chữ "+số EXP" nổi phía trên mép phải khung chat,
## bay lên rồi mờ dần trong EXP_LIFE giây, chồng tối đa EXP_ROWS dòng (dòng mới nhất ở dưới cùng).

static func push_exp(_monster_name: String, exp_amount: int) -> void:

	if exp_amount <= 0:

		return

	if current != null and is_instance_valid(current):

		current._show_exp(exp_amount)

## Đặt khung chat vào giữa đáy màn chơi (node "UI" của Main).

static func attach(ui: Node) -> ChatBox:

	var box := ChatBox.create()

	current = box

	box.name = "ChatBox"

	ui.add_child(box)

	box.apply_hud_layout()

	return box

const CHAT_SHIFT_X := 80.0
## Khoảng cách từ mép phải khung chat tới cụm nút tiện ích bên phải (Nhân vật / Hành trang… và Giao dịch / Ngồi / Đội / PK).
const ICONS_GAP := 10.0

func apply_hud_layout() -> void:
	## Đợi Main xếp xong cụm nút tiện ích (cùng lượt HudLayout báo đổi) rồi mới canh theo.
	_apply_hud_layout_now.call_deferred()

## Mép trái (toạ độ màn) của cụm nút tiện ích bên phải; NAN nếu chưa có (VD màn không có các cụm đó).
func _icons_left_x() -> float:
	var parent := get_parent()
	if parent == null:
		return NAN
	var x := INF
	for n in ["SideMenu", "BottomActionBar"]:
		var c := parent.get_node_or_null(n) as Control
		if c != null and c.is_visible_in_tree():
			x = minf(x, c.get_global_rect().position.x)
	return x if x < INF else NAN

func _apply_hud_layout_now() -> void:
	if not is_inside_tree():
		return
	var d := HudLayout.get_element("chat_box")

	var w: float = float(d.get("width", 400.0))

	var sc: float = float(d.get("scale", 1.0))

	var ox: float = float(d.get("offset_x", 0.0))

	var oy: float = float(d.get("offset_y", 0.0))

	custom_minimum_size = Vector2(w, 0)

	size.x = w

	anchor_top = 1.0

	anchor_bottom = 1.0

	grow_vertical = Control.GROW_DIRECTION_BEGIN

	scale = Vector2.ONE * sc

	var icons_x := _icons_left_x()

	if not is_nan(icons_x):
		## Mặc định: mép phải khung chat cách cụm nút tiện ích ICONS_GAP px (neo phải -> đổi cỡ màn vẫn giữ khoảng).
		anchor_left = 1.0
		anchor_right = 1.0
		grow_horizontal = Control.GROW_DIRECTION_BEGIN
		var right := icons_x - get_viewport_rect().size.x - ICONS_GAP + ox
		## Phóng quanh góc trên-trái: kích thước gốc w, sau khi phóng mép phải đúng `right`.
		offset_left = right - w * sc
		offset_right = offset_left + w
	else:
		anchor_left = 0.5
		anchor_right = 0.5
		grow_horizontal = Control.GROW_DIRECTION_BOTH
		## Lùi sang trái CHAT_SHIFT_X px so với giữa màn để không đè cụm nút tiện ích bên phải.
		offset_left = -w - CHAT_SHIFT_X + ox
		offset_right = -CHAT_SHIFT_X + ox

	offset_top = -8.0 + oy

	offset_bottom = -8.0 + oy

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

	## Bộ lọc xem: Tất cả / Hệ thống / từng kênh — 1 ô chọn (item id: -2 tất cả, -1 hệ thống, >= 0 kênh).
	_view_pick = _make_pick()
	_view_pick.tooltip_text = "Chọn loại tin muốn xem"
	_view_pick.add_item("Tất cả", 1000)
	_view_pick.add_item("Hệ thống", 1001)
	for ch in SEND_CHANNELS:
		_view_pick.add_item(ChatServer.CHANNEL_NAMES[ch], ch)
	_view_pick.item_selected.connect(func(idx: int) -> void:
		var id := _view_pick.get_item_id(idx)
		if id == 1000:
			_set_tab(Tab.ALL)
		elif id == 1001:
			_set_tab(Tab.SYSTEM)
		else:
			_set_channel_view(id))
	head.add_child(_view_pick)

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

	## Kênh gửi (tần số): Gần / Tổ đội / Môn phái / Bang hội / Thế giới / Riêng — ô chọn ngay trước ô nhập.
	_channel_pick = _make_pick()
	_channel_pick.tooltip_text = "Chọn kênh gửi tin"
	for ch in SEND_CHANNELS:
		_channel_pick.add_item(ChatServer.CHANNEL_NAMES[ch], ch)
	_channel_pick.item_selected.connect(func(idx: int) -> void: _set_send_channel(_channel_pick.get_item_id(idx)))
	row.add_child(_channel_pick)

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
	_build_afk_label.call_deferred()
	for line in _pending_lines:
		add_line(line, false, ChatServer.PRIVATE)
	_pending_lines.clear()

## Nhãn treo máy gắn vào cha của khung chat (không nằm trong PanelContainer để khỏi bị ép bố cục).
func _build_afk_label() -> void:
	if _afk_label != null or get_parent() == null:
		return
	_afk_label = Label.new()
	_afk_label.name = "AfkLabel"
	_afk_label.text = "Đang treo máy..."
	_afk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_afk_label.add_theme_font_size_override("font_size", 26)
	_afk_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	_afk_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0))
	_afk_label.add_theme_constant_override("outline_size", 6)
	_afk_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_afk_label.add_theme_constant_override("shadow_offset_x", 2)
	_afk_label.add_theme_constant_override("shadow_offset_y", 2)
	_afk_label.visible = false
	get_parent().add_child(_afk_label)
	tree_exiting.connect(func() -> void:
		if is_instance_valid(_afk_label):
			_afk_label.queue_free())

## Hiện 1 dòng "+số EXP": lấy nhãn rảnh trong pool (hoặc dòng cũ nhất khi đã đủ EXP_ROWS dòng) đưa xuống cuối.
func _show_exp(amount: int) -> void:
	var host := get_parent()
	if host == null:
		return
	var lbl: Label
	if _exp_rows.size() >= EXP_ROWS:
		lbl = _exp_rows.pop_front()["label"]
	elif not _exp_pool.is_empty():
		lbl = _exp_pool.pop_back()
	else:
		lbl = Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45))
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.12, 0.0))
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		lbl.add_theme_constant_override("shadow_offset_x", 2)
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		host.add_child(lbl)
		tree_exiting.connect(func() -> void:
			if is_instance_valid(lbl):
				lbl.queue_free())
	lbl.text = "+%s EXP" % InventoryPopup.format_money(amount)
	lbl.size = lbl.get_combined_minimum_size()
	lbl.visible = true
	_exp_rows.append({"label": lbl, "age": 0.0})
	_update_exp(0.0)

## Xếp các dòng "+EXP": dòng mới nhất sát mép trên khung chat (bên phải, ngang chữ "Đang treo máy"), dòng cũ hơn đẩy lên trên;
## mỗi dòng bay lên EXP_RISE px và mờ dần trong giây cuối của EXP_LIFE.
func _update_exp(delta: float) -> void:
	if _exp_rows.is_empty():
		return
	var r := get_global_rect()
	var base_y := r.position.y - AFK_GAP
	var anchor_x := r.end.x
	for i in range(_exp_rows.size() - 1, -1, -1):
		var row: Dictionary = _exp_rows[i]
		row.age += delta
		var lbl: Label = row.label
		if row.age >= EXP_LIFE or not is_instance_valid(lbl):
			_exp_rows.remove_at(i)
			if is_instance_valid(lbl):
				lbl.visible = false
				_exp_pool.append(lbl)
	var y := base_y
	for i in range(_exp_rows.size() - 1, -1, -1):
		var row: Dictionary = _exp_rows[i]
		var lbl: Label = row.label
		var t: float = row.age / EXP_LIFE
		var sz := lbl.size
		y -= sz.y
		lbl.global_position = Vector2(anchor_x - sz.x * 0.5, y - EXP_RISE * t)
		lbl.modulate.a = clampf((EXP_LIFE - row.age) / 1.0, 0.0, 1.0) * clampf(row.age / 0.15 + 0.3, 0.0, 1.0)
		y -= EXP_ROW_GAP

func _process(delta: float) -> void:
	_update_exp(delta)
	if _afk_label == null or not is_instance_valid(_afk_label):
		return
	var p := get_tree().get_first_node_in_group("player")
	var on: bool = visible and p != null and bool(p.get("is_auto_mode"))
	if _afk_label.visible != on:
		_afk_label.visible = on
		_afk_time = 0.0
	if not on:
		return
	_afk_time += delta
	## Dấu chấm chạy 0 -> 3 (mỗi 0.4s) + nhấp nháy sáng/tối + nhún nhẹ lên xuống.
	var dots := int(_afk_time / 0.4) % 4
	_afk_label.text = "Đang treo máy" + ".".repeat(dots) + " ".repeat(3 - dots)
	_afk_label.modulate.a = 0.65 + 0.35 * (0.5 + 0.5 * sin(_afk_time * 4.0))
	var bob := -1.5 * (1.0 + sin(_afk_time * 3.0))   ## chỉ nhún lên, luôn cách khung chat ≥ 5px
	var r := get_global_rect()
	var sz := _afk_label.get_combined_minimum_size()
	_afk_label.size = sz
	_afk_label.global_position = Vector2(r.position.x, r.position.y - AFK_GAP - sz.y + bob)

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

	_set_send_channel(ChatServer.PRIVATE)

	_to.text = to_name

	_input.grab_focus()

## Ô chọn (OptionButton) cùng kiểu nút chung của game (GameUi), cỡ chữ nhỏ cho hàng chat.
func _make_pick() -> OptionButton:
	GameUi.apply()
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.theme_type_variation = GameUi.BUTTON
	o.add_theme_font_size_override("font_size", 12)
	o.fit_to_longest_item = true
	return o

## Đổi kênh gửi: kênh Riêng mới hiện ô tên người nhận.
func _set_send_channel(ch: int) -> void:
	_channel = ch
	_to.visible = ch == ChatServer.PRIVATE
	if _channel_pick != null:
		var idx := _channel_pick.get_item_index(ch)
		if idx >= 0 and _channel_pick.selected != idx:
			_channel_pick.select(idx)

## Bộ lọc xem chỉ 1 kênh.
func _set_channel_view(ch: int) -> void:
	_view_channel = ch
	_current_tab = Tab.CHANNEL
	_show_body()
	_rebuild_log()

func _show_body() -> void:
	if not _body.visible:
		_body.visible = true
		_toggle.text = "Chat ▾"
		_shrink_to_fit.call_deferred()

## Tin có hiện theo bộ lọc đang chọn không.
func _passes(m: Dictionary) -> bool:
	match _current_tab:
		Tab.SYSTEM:
			return bool(m.get("is_system", false))
		Tab.CHANNEL:
			return int(m.get("channel", -1)) == _view_channel
	return true

func _on_toggle() -> void:

	_body.visible = not _body.visible

	_toggle.text = "Chat ▾" if _body.visible else "Chat ▸"

	_shrink_to_fit.call_deferred()

func _set_tab(tab: Tab) -> void:

	if _current_tab == tab and _body.visible:

		return

	_current_tab = tab

	if _view_pick != null:
		var idx := _view_pick.get_item_index(1000 if tab == Tab.ALL else 1001)
		if tab != Tab.CHANNEL and idx >= 0 and _view_pick.selected != idx:
			_view_pick.select(idx)

	_show_body()

	_rebuild_log()

func _rebuild_log() -> void:

	if _log == null:

		return

	_log.text = ""

	_lines = 0

	for m in _messages:

		if _passes(m):

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

	if keyword in ["/lead", "/lanhdao"]:

		if not GmManager.is_gm() and not OS.is_debug_build():

			push_system("[color=#ff4444][Hệ thống][/color] Lệnh này chỉ dành cho GM (Quản trị viên).")

			return true

		if p:

			if parts.size() > 1:

				var arg_str := parts[1].strip_edges()

				if arg_str.begins_with("+") or arg_str.begins_with("-"):

					var delta := int(arg_str)

					GmManager.add_player_lead_level(p, delta)

				else:

					var target_lead := int(arg_str)

					GmManager.set_player_lead_level(p, target_lead)

			else:

				GmManager.add_player_lead_level(p, 5)

			push_system("[color=#ffaa00][GM][/color] Cấp tài lãnh đạo hiện tại: [color=#55ff55]%d[/color] (Tối đa đội: %d người)." % [
				p.lead_level, SocialRules.team_size(p.lead_level)
			])

		return true

	if keyword in ["/leadexp", "/lanhdaoexp"]:

		if not GmManager.is_gm() and not OS.is_debug_build():

			push_system("[color=#ff4444][Hệ thống][/color] Lệnh này chỉ dành cho GM (Quản trị viên).")

			return true

		if p:

			var exp_add := 5000

			if parts.size() > 1 and parts[1].is_valid_int():

				exp_add = maxi(1, int(parts[1]))

			var gained := GmManager.add_player_lead_exp(p, exp_add)

			push_system("[color=#ffaa00][GM][/color] Đã nhận [color=#55ff55]+%s[/color] exp tài lãnh đạo (Lên %d cấp, hiện cấp: %d)." % [
				InventoryPopup.format_money(exp_add), gained, p.lead_level
			])

		return true

	if keyword == "/help":

		push_system("[color=#ffaa00][Hệ thống][/color] Lệnh có sẵn: [color=#ffff77]/knb [số][/color] (KNB), [color=#ffff77]/xu [số][/color] (Xu), [color=#ffff77]/ttl[/color] (Tiên Thảo Lộ), [color=#ffff77]/lead [cấp|+số][/color] (Tài lãnh đạo), [color=#ffff77]/leadexp [exp][/color] (Exp lãnh đạo).")

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

	_input.release_focus()   ## gửi xong trả phím về cho nhân vật (giữ nguyên kênh đang chọn, như khung chat gốc)

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
	add_line("[color=#%s][%s] %s:[/color] %s" % [color.to_html(false), ChatServer.CHANNEL_NAMES[channel], who, body_bbcode], false, channel)

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

## `channel`: kênh chat của tin (-1 = không thuộc kênh nào, VD thông báo hệ thống) — dùng cho bộ lọc xem theo kênh.
func add_line(bbcode: String, is_system := false, channel := -1) -> void:

	var m := {"text": bbcode, "is_system": is_system, "channel": channel}

	_messages.append(m)

	if _messages.size() > MAX_LINES:

		_messages.pop_front()

	if _passes(m):

		if _lines >= MAX_LINES:

			_log.remove_paragraph(0)

		else:

			_lines += 1

		_log.append_text(bbcode + "\n")

## Chặn người chơi chèn mã định dạng vào tin nhắn.

static func _esc(s: String) -> String:

	return s.replace("[", "[lb]")


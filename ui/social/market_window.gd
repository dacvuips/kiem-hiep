extends SocialWindow
class_name MarketWindow
## CHỢ GIAO THƯƠNG — 3 tab:
##   [Giao Thương] hàng mọi người đang treo, lọc theo Loại / Hệ / Cấp / Thuộc Tính / Tiền / tên; bấm món xem chi tiết + Mua.
##   [Của Tôi]     món mình đang treo (Hủy treo / Nhận lại khi hết hạn) + hành trang: chạm món để định giá bán (lượng hoặc KNB).
##   [Giao Dịch]   nhập ID nhân vật để mời giao dịch (bên kia nhận hộp hỏi đồng ý, đồng ý thì mở cửa sổ giao dịch như thường)
##                 + danh sách người chơi quanh đây.
## Luật chợ: MarketBook. Online hỏi MarketServer (C_MARKET / S_MARKET), chơi một mình hỏi OfflineMarket — cùng định dạng trả lời.

const ICON_GOLD := "res://assets/items/icons/tongqian.png"
const ICON_JADE := "res://assets/items/icons/obj_item_cardg.png"   ## Kim Nguyên Bảo
const ELEMENT_NAMES := ["Kim", "Mộc", "Thủy", "Hỏa", "Thổ"]
const CARD_SIZE := Vector2(380, 66)

enum Tab { MARKET, MINE, TRADE }

var _hub: SocialHub
var _profile: PlayerProfile
var _tab: int = Tab.MARKET
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _msg: PanelContainer
var _money: Label
## Giao Thương
var _f_cat: OptionButton
var _f_series: OptionButton
var _f_level: OptionButton
var _f_attrib: OptionButton
var _f_cur: OptionButton
var _f_name: LineEdit
var _grid: GridContainer
## Của Tôi
var _mine_box: VBoxContainer
var _slots: Label
var _bag_view: ItemRoomView
var _bag_tabs: Array[Button] = []
var _mine: Array = []
var _now := 0
## Giao Dịch
var _id_edit: LineEdit
var _near_box: VBoxContainer
var _items: Dictionary = {}      ## id listing -> ItemInstance (đọc từ listing.item)

static func open(host: Node, profile: PlayerProfile) -> MarketWindow:
	return SocialWindow.present(host, MarketWindow.new(SocialHub.of(profile)), &"market") as MarketWindow

func _init(hub: SocialHub = null) -> void:
	super._init("Chợ Giao Thương", "", 860.0)
	_hub = hub
	if _hub == null:
		return
	_profile = _hub.profile
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for t in [["Giao Thương", Tab.MARKET], ["Của Tôi", Tab.MINE], ["Giao Dịch", Tab.TRADE]]:
		var b := GameUi.button(str(t[0]), GameUi.TAB)
		b.custom_minimum_size = Vector2(170, 36)
		b.pressed.connect(_show_tab.bind(int(t[1])))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	_money = SocialUi.label("", SocialUi.GOLD, 13)
	tabs.add_child(_money)
	_pages = [_build_market(), _build_mine(), _build_trade()]
	for p in _pages:
		body.add_child(p)
	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)
	NetClient.market_received.connect(_on_market)
	NetClient.profile_received.connect(_on_profile)
	_hub.notice.connect(_on_notice)
	_show_tab(Tab.MARKET)

func _exit_tree() -> void:
	if NetClient.market_received.is_connected(_on_market):
		NetClient.market_received.disconnect(_on_market)
	if NetClient.profile_received.is_connected(_on_profile):
		NetClient.profile_received.disconnect(_on_profile)
	if _hub != null and _hub.notice.is_connected(_on_notice):
		_hub.notice.disconnect(_on_notice)

func _host() -> Node:
	return get_tree().current_scene

func _say(text: String, good: bool) -> void:
	SocialUi.set_banner(_msg, text, good)
	_msg.visible = text != ""

func _show_tab(t: int) -> void:
	_tab = t
	for i in _pages.size():
		_pages[i].visible = i == t
		GameUi.set_active(_tab_buttons[i], i == t)
	_msg.visible = false
	_refresh_money()
	match t:
		Tab.MARKET:
			_search()
		Tab.MINE:
			_request("mine")
			_refresh_bag()
		Tab.TRADE:
			_refresh_nearby()

func _refresh_money() -> void:
	_money.text = "Lượng: %s   ·   KNB: %s" % [InventoryPopup.format_money(_profile.gold), InventoryPopup.format_money(_profile.jade)]

## Gửi thao tác chợ: online lên server (trả lời về _on_market qua NetClient), offline hỏi OfflineMarket ngay.
func _request(op: String, args := {}) -> void:
	if NetClient.is_in_world():
		NetClient.send_market(op, args)
	else:
		_on_market(OfflineMarket.handle(_profile, op, args))

func _on_market(d: Dictionary) -> void:
	_now = int(d.get("now", _now))
	match str(d.get("op", "")):
		"list":
			_fill_market(d.get("items", []))
		"mine":
			_mine = d.get("items", [])
			_fill_mine()
		"done":
			_say(str(d.get("msg", "")), bool(d.get("ok", false)))
			_refresh_money()
			if bool(d.get("ok", false)):
				if _tab == Tab.MARKET:
					_search()
				elif _tab == Tab.MINE:
					_request("mine")
					_refresh_bag()

## Online: hồ sơ chuẩn từ server (sau mua / treo / huỷ) đã chép vào _profile -> vẽ lại tiền + hành trang.
func _on_profile(_data: Dictionary) -> void:
	call_deferred("_after_profile")

func _after_profile() -> void:
	if not is_inside_tree():
		return
	_refresh_money()
	if _tab == Tab.MINE:
		_refresh_bag()

func _on_notice(_t: String, _g: bool) -> void:
	if is_inside_tree() and _tab == Tab.MINE and not NetClient.is_in_world():
		_request("mine")   ## khách giả vừa mua hàng mình treo
		_refresh_money()

func _item_of(l: Dictionary) -> ItemInstance:
	var id := str(l.get("id", ""))
	if not _items.has(id):
		var d: Variant = l.get("item", {})
		_items[id] = ItemInstance.from_dict(d) if d is Dictionary and not (d as Dictionary).is_empty() else null
	return _items[id]

# ================================================================ Giao Thương

func _build_market() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	_f_cat = _option(row, "Loại", MarketBook.CATEGORIES.map(func(c: Array) -> String: return str(c[1])))
	_f_series = _option(row, "Hệ", ["Toàn bộ"] + ELEMENT_NAMES)
	var levels := ["Toàn bộ"]
	for i in range(1, 11):
		levels.append("Cấp %d" % i)
	_f_level = _option(row, "Cấp", levels)
	_f_attrib = _option(row, "Thuộc Tính", ["Toàn bộ"] + MarketBook.attrib_options().keys())
	_f_cur = _option(row, "Tiền", ["Toàn bộ", "Lượng", "KNB"])
	_f_name = SocialUi.line_edit("Tên vật phẩm")
	_f_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_f_name.text_submitted.connect(func(_t: String) -> void: _search())
	row.add_child(_f_name)
	var find := SocialUi.stone_button("Tìm", Vector2(76, 36))
	find.pressed.connect(_search)
	row.add_child(find)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 420)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	page.add_child(scroll)
	return page

## Ô chọn của bộ lọc: mục đầu hiện tên bộ lọc ("Loại", "Hệ"...) khi đang chọn "Toàn bộ".
func _option(parent: Control, label: String, entries: Array) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(108 if label != "Thuộc Tính" else 130, 36)
	o.fit_to_longest_item = false
	o.clip_text = true
	for i in entries.size():
		o.add_item(label if i == 0 else str(entries[i]), i)
	## Mục đầu: trên nút hiện tên bộ lọc, trong danh sách xổ xuống hiện "Toàn bộ".
	o.get_popup().about_to_popup.connect(func() -> void: o.set_item_text(0, str(entries[0])))
	o.get_popup().popup_hide.connect(func() -> void: o.set_item_text(0, label))
	o.item_selected.connect(func(_i: int) -> void: _search())
	parent.add_child(o)
	return o

func _filter() -> Dictionary:
	return {
		"cat": str(MarketBook.CATEGORIES[maxi(0, _f_cat.selected)][0]),
		"series": _f_series.selected - 1,
		"level": maxi(0, _f_level.selected),
		"attrib": "" if _f_attrib.selected <= 0 else _f_attrib.get_item_text(_f_attrib.selected),
		"cur": _f_cur.selected - 1,
		"name": _f_name.text.strip_edges(),
	}

func _search() -> void:
	_request("list", {"filter": _filter()})

func _fill_market(list: Array) -> void:
	for c in _grid.get_children():
		c.queue_free()
	_items.clear()
	if list.is_empty():
		_grid.add_child(SocialUi.label("Không có vật phẩm phù hợp.", SocialUi.MUTED, 14))
		return
	for l in list:
		var item := _item_of(l)
		if item == null:
			continue
		var card := _card(item, l, true)
		card.pressed.connect(_inspect.bind(l))
		_grid.add_child(card)

## Thẻ 1 món: ô ảnh, tên (màu phẩm chất), giá (icon lượng / KNB), mũi tên ›.
func _card(item: ItemInstance, l: Dictionary, arrow: bool) -> Button:
	var b := GameUi.button("", GameUi.BUTTON)
	b.custom_minimum_size = CARD_SIZE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(_icon_box(item, 52))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var name_l := SocialUi.label(_short_name(item), Color.html(ItemText.name_color_of(item)), 15)
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	v.add_child(_price_row(int(l.get("price", 0)), int(l.get("cur", 0))))
	if arrow:
		var a := SocialUi.label("›", SocialUi.TEXT, 26)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(a)
	return b

static func _short_name(item: ItemInstance) -> String:
	var n := str(item.get_base().get("name", "?"))
	return "%s x%d" % [n, item.count] if item.is_misc() and item.count > 1 else n

func _icon_box(item: ItemInstance, size: float) -> Control:
	var box := GameUi.panel(GameUi.PANEL)
	box.custom_minimum_size = Vector2(size, size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := TextureRect.new()
	icon.texture = item.get_icon(true) if item else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(size - 14, size - 14)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	return box

func _price_row(price: int, cur: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = load(ICON_JADE if cur == MarketBook.CUR_JADE else ICON_GOLD)
	icon.custom_minimum_size = Vector2(22, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon)
	var color := SocialUi.LABEL_BLUE if cur == MarketBook.CUR_JADE else SocialUi.GOLD
	var t := SocialUi.label(MarketBook.price_text(price, cur), color, 14)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	return h

## Chi tiết món + giá bán + người bán, nút Mua (trừ hàng của chính mình).
func _inspect(l: Dictionary) -> void:
	var item := _item_of(l)
	if item == null:
		return
	var cur := int(l.get("cur", 0))
	var head := "[center][color=#f5d061]Giá bán: %s[/color]\n[color=#9fa39f]Người bán: %s · còn %s[/color][/center]\n" % [
		MarketBook.price_text(int(l.get("price", 0)), cur), str(l.get("seller", "?")),
		MarketBook.remaining_text(int(l.get("until", 0)), _now)]
	var actions := []
	if not _is_mine(l):
		actions.append(["Mua", func() -> void: _confirm_buy(l, item)])
	ItemDetailPopup.open(_host(), head + ItemText.build(item, _profile, -1, -1, false), actions, item)

func _is_mine(l: Dictionary) -> bool:
	var sid := int(l.get("sid", 0))
	if NetClient.is_in_world():
		return sid == SaveManager.online_character_id
	return sid == OfflineMarket.SELF_SID

func _confirm_buy(l: Dictionary, item: ItemInstance) -> void:
	var cur := int(l.get("cur", 0))
	SocialWindow.confirm(_host(), "Mua vật phẩm", "Mua %s với giá %s?" % [_short_name(item), MarketBook.price_text(int(l.get("price", 0)), cur)],
		func() -> void: _request("buy", {"id": str(l.get("id", ""))}))

# ================================================================ Của Tôi

func _build_mine() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	var left := SocialUi.section()
	left[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	var title := SocialUi.label("Vật phẩm đang treo", SocialUi.LABEL_GREEN, 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_slots = SocialUi.label("", SocialUi.LABEL_RED, 13)
	head.add_child(_slots)
	left[1].add_child(head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 400)
	_mine_box = VBoxContainer.new()
	_mine_box.add_theme_constant_override("separation", 6)
	_mine_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_mine_box)
	left[1].add_child(scroll)
	page.add_child(left[0])

	var right := SocialUi.info_box("Hành trang")
	var tabs := HBoxContainer.new()
	right[1].add_child(tabs)
	for i in PlayerProfile.OPEN_BAGS:
		var b := GameUi.button("Túi %d" % (i + 1), GameUi.TAB)
		b.pressed.connect(func() -> void:
			_bag_view.bag = i
			_refresh_bag())
		tabs.add_child(b)
		_bag_tabs.append(b)
	var bag_scroll := ScrollContainer.new()
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_scroll.custom_minimum_size = Vector2(PlayerProfile.ROOM_WIDTH * 20 + 8, 318)
	_bag_view = ItemRoomView.new()
	_bag_view.cell = 20
	_bag_view.item_pressed.connect(_on_bag_item)
	bag_scroll.add_child(_bag_view)
	right[1].add_child(bag_scroll)
	right[1].add_child(SocialUi.label("Chạm vật phẩm để định giá bán", SocialUi.TEXT, 13, HORIZONTAL_ALIGNMENT_CENTER))
	right[1].add_child(SocialUi.label("Hệ thống sẽ thu thuế tự động %d%% khi bán thành công" % MarketBook.TAX_PERCENT,
		SocialUi.LABEL_GREEN, 12, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(right[0])
	return page

func _refresh_bag() -> void:
	for i in _bag_tabs.size():
		GameUi.set_active(_bag_tabs[i], i == _bag_view.bag)
	_bag_view.setup(_profile)

func _fill_mine() -> void:
	for c in _mine_box.get_children():
		c.queue_free()
	_items.clear()
	_slots.text = "Slot %d/%d" % [_mine.size(), MarketBook.MAX_SLOTS]
	if _mine.is_empty():
		_mine_box.add_child(SocialUi.label("Chưa treo món nào — chạm vật phẩm trong hành trang để định giá bán.", SocialUi.MUTED, 13))
		return
	for l in _mine:
		var item := _item_of(l)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var panel := GameUi.panel(GameUi.PANEL)
		panel.add_child(row)
		row.add_child(_icon_box(item, 48))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var nm := _short_name(item) if item else str(l.get("name", "?"))
		var name_l := SocialUi.label(nm, Color.html(ItemText.name_color_of(item)) if item else SocialUi.TEXT, 14)
		name_l.clip_text = true
		v.add_child(name_l)
		v.add_child(_price_row(int(l.get("price", 0)), int(l.get("cur", 0))))
		row.add_child(v)
		var sold := str(l.get("state", "")) == MarketBook.STATE_SOLD
		var live := MarketBook.is_live(l, _now)
		var right := VBoxContainer.new()
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		var left_t := "Đã bán" if sold else MarketBook.remaining_text(int(l.get("until", 0)), _now)
		right.add_child(SocialUi.label(left_t, SocialUi.LABEL_GREEN if sold else (SocialUi.MUTED if live else SocialUi.LABEL_RED), 12,
			HORIZONTAL_ALIGNMENT_RIGHT))
		if not sold:
			var btn := SocialUi.small_button("Hủy treo" if live else "Nhận lại")
			btn.custom_minimum_size = Vector2(92, 30)
			btn.pressed.connect(func() -> void: _request("cancel", {"id": str(l.get("id", ""))}))
			right.add_child(btn)
		row.add_child(right)
		_mine_box.add_child(panel)

## Chạm món trong hành trang: hộp định giá (số tiền + chọn Lượng / KNB) rồi treo bán.
func _on_bag_item(item: ItemInstance) -> void:
	if SecurityLock.is_item_locked(item) or item.lock_state == ItemInstance.LOCK_CHARACTER:
		_say("Món đồ đang bị khoá, không treo bán được.", false)
		return
	var win := SocialWindow.new("Định giá bán", _short_name(item), 380.0)
	var cur := [MarketBook.CUR_GOLD]
	var cur_row := HBoxContainer.new()
	cur_row.add_theme_constant_override("separation", 8)
	var gold_b := GameUi.button("Lượng", GameUi.TAB)
	var jade_b := GameUi.button("KNB", GameUi.TAB)
	for b in [gold_b, jade_b]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cur_row.add_child(b)
	win.body.add_child(cur_row)
	var edit := SocialUi.line_edit("Giá bán")
	win.body.add_child(edit)
	var preview := SocialUi.label("", SocialUi.GOLD, 14, HORIZONTAL_ALIGNMENT_CENTER)
	win.body.add_child(preview)
	var update := func() -> void:
		GameUi.set_active(gold_b, cur[0] == MarketBook.CUR_GOLD)
		GameUi.set_active(jade_b, cur[0] == MarketBook.CUR_JADE)
		var v := int(edit.text) if edit.text.strip_edges().is_valid_int() else 0
		preview.text = MarketBook.price_text(v, cur[0]) if v > 0 else ("Nhập số lượng (1 vạn = 10000)" if cur[0] == MarketBook.CUR_GOLD else "Nhập số KNB")
	gold_b.pressed.connect(func() -> void:
		cur[0] = MarketBook.CUR_GOLD
		update.call())
	jade_b.pressed.connect(func() -> void:
		cur[0] = MarketBook.CUR_JADE
		update.call())
	edit.text_changed.connect(func(_t: String) -> void: update.call())
	var row := win.add_button_row()
	var ok := SocialUi.stone_button("Treo bán")
	var cancel := SocialUi.stone_button("Huỷ")
	for b in [ok, cancel]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	SocialWindow.present(_host(), win, &"")
	var submit := func() -> void:
		var price := int(edit.text) if edit.text.strip_edges().is_valid_int() else 0
		win.close_requested.emit()
		_request("sell", {"uid": item.uid, "price": price, "cur": cur[0]})
	ok.pressed.connect(submit)
	edit.text_submitted.connect(func(_t: String) -> void: submit.call())
	cancel.pressed.connect(func() -> void: win.close_requested.emit())
	update.call()
	edit.call_deferred("grab_focus")

# ================================================================ Giao Dịch

func _build_trade() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	var box := SocialUi.info_box("Giao dịch theo ID")
	var my_id := SaveManager.online_character_id if NetClient.is_in_world() else 0
	box[1].add_child(SocialUi.kv("ID của bạn:", str(my_id) if my_id > 0 else "— (chơi một mình: dùng ID người chơi bên dưới)",
		SocialUi.LABEL_BLUE, SocialUi.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_id_edit = SocialUi.line_edit("Nhập ID người cần giao dịch")
	_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_edit.text_submitted.connect(func(_t: String) -> void: _trade_by_id())
	row.add_child(_id_edit)
	var send := SocialUi.stone_button("Mời giao dịch", Vector2(150, 38))
	send.pressed.connect(_trade_by_id)
	row.add_child(send)
	box[1].add_child(row)
	var hint := SocialUi.label("Bên kia sẽ nhận hộp hỏi có đồng ý giao dịch không — đồng ý thì cửa sổ giao dịch mở ra như bình thường.",
		SocialUi.SUBTITLE, 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box[1].add_child(hint)
	page.add_child(box[0])
	var near := SocialUi.section("Người chơi quanh đây")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 280)
	_near_box = VBoxContainer.new()
	_near_box.add_theme_constant_override("separation", 6)
	_near_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_near_box)
	near[1].add_child(scroll)
	page.add_child(near[0])
	return page

func _trade_by_id() -> void:
	var text := _id_edit.text.strip_edges()
	if not text.is_valid_int():
		_say("Hãy nhập ID là số.", false)
		return
	var err := _hub.start_trade_by_id(int(text))
	if err == "online":
		_say("Đã gửi lời mời giao dịch tới ID %s — chờ đối phương đồng ý." % text, true)
		return
	if err != "":
		_say(err, false)
		return
	_say("", true)
	TradeWindow.open(_host(), _hub)

func _refresh_nearby() -> void:
	for c in _near_box.get_children():
		c.queue_free()
	var players := SocialDirectory.players(_profile)
	if players.is_empty():
		_near_box.add_child(SocialUi.label("Không có ai ở gần.", SocialUi.MUTED, 13))
	for m in players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := SocialUi.label(m.name, Camp.get_color(m.camp), 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var state := "Cấp %d · %s" % [m.level, m.sect_name]
		if not NetClient.is_in_world():
			state = "ID %d · " % m.id + state
		if m.stall_open:
			state += " · đang bày bán"
		elif m.trade_open:
			state += " · mở giao dịch"
		row.add_child(SocialUi.label(state, SocialUi.SUBTITLE, 12))
		var eq := SocialUi.small_button("Xem trang bị")
		eq.pressed.connect(func() -> void: _view_equip(m))
		row.add_child(eq)
		if m.stall_open:
			var v := SocialUi.small_button("Xem quầy")
			v.pressed.connect(func() -> void: StallBrowseWindow.open(_host(), _hub, m))
			row.add_child(v)
		else:
			var t := SocialUi.small_button("Giao dịch")
			t.disabled = not m.trade_open
			t.pressed.connect(func() -> void: _trade_near(m))
			row.add_child(t)
		_near_box.add_child(row)

func _view_equip(m: MockPlayer) -> void:
	var err := []
	if ViewEquipWindow.open_for(_host(), _profile, m, err) == null:
		_say(str(err[0]), false)

func _trade_near(m: MockPlayer) -> void:
	var err := _hub.start_trade(m)
	if err == "online":
		_say("Đã gửi lời mời giao dịch tới %s — chờ đồng ý." % m.name, true)
		return
	if err != "":
		_say(err, false)
		return
	TradeWindow.open(_host(), _hub)

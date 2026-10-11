extends SocialWindow
class_name TradeWindow
## GIAO DỊCH — bố cục như màn "GIAO DỊCH" của VLTK gốc: trái-trên là phần đối phương đưa ("Giao Dịch" + số lượng + dòng "Chờ đối phương đặt mật
## khoá"), trái-dưới là "Vật phẩm đặt vào" của bạn, phải là "Vật phẩm của tôi" (hành trang); hàng nút [Đồng ý ■] (khoá phần của mình)
## [Xác nhận ■] (chốt giao dịch — bên bấm sau chờ 5 giây) [Huỷ bỏ]. Luật: TradeSession (KPlayer::TradeDecision gốc).

var _hub: SocialHub
var _session: TradeSession
var _profile: PlayerProfile
var _mine_view: ItemRoomView
var _theirs_view: ItemRoomView
var _bag_view: ItemRoomView
var _bag := 0
var _their_money: Button
var _my_money: Button
var _bag_money: Label
var _status: Label
var _comment: Label
var _msg: PanelContainer
var _lock_btn: Button
var _ok_btn: Button
var _cancel_btn: Button
var _lock_light: ColorRect
var _ok_light: ColorRect
var _their_light: ColorRect
var _cell := 26
var _finished := false

static func open(host: Node, hub: SocialHub) -> TradeWindow:
	return SocialWindow.present(host, TradeWindow.new(hub), &"trade") as TradeWindow

func _init(hub: SocialHub = null) -> void:
	super._init("Giao Dịch", "", 900.0)
	_hub = hub
	if _hub == null or _hub.trade == null:
		return
	_session = _hub.trade
	_profile = _hub.profile
	var partner_name := _session.partner().party.party_name()
	set_subtitle("Đang giao dịch với %s" % partner_name)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)

	## ---- Cột trái: đối phương (trên) + phần của mình (dưới)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	var theirs := SocialUi.section(partner_name, SocialUi.SECTION_ACCENT, SocialUi.SECTION_BG)
	_theirs_view = ItemRoomView.new()
	_theirs_view.cell = _cell
	_theirs_view.interactive = false
	theirs[1].add_child(_theirs_view)
	_their_money = _money_bar()
	_their_money.disabled = true
	theirs[1].add_child(_their_money)
	_status = SocialUi.label("", SocialUi.WARN, 13, HORIZONTAL_ALIGNMENT_CENTER)
	theirs[1].add_child(_status)
	_comment = SocialUi.label("", SocialUi.SUBTITLE, 12, HORIZONTAL_ALIGNMENT_CENTER)
	_comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	theirs[1].add_child(_comment)
	left.add_child(theirs[0])

	var mine := SocialUi.section("Vật phẩm đặt vào", SocialUi.LABEL_BLUE, SocialUi.INFO_BG)
	_mine_view = ItemRoomView.new()
	_mine_view.cell = _cell
	mine[1].add_child(_mine_view)
	_my_money = _money_bar()
	mine[1].add_child(_my_money)
	left.add_child(mine[0])

	## ---- Cột phải: hành trang của tôi
	var bag := SocialUi.section("Vật phẩm của tôi — bấm hoặc kéo món vào ô đặt", SocialUi.GOLD, SocialUi.SECTION_BG)
	var tabs := HBoxContainer.new()
	bag[1].add_child(tabs)
	for i in PlayerProfile.OPEN_BAGS:
		var b := SocialUi.small_button("Túi %d" % (i + 1))
		b.pressed.connect(func() -> void:
			_bag = i
			_refresh())
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PlayerProfile.ROOM_WIDTH * 21 + 8, 400)
	_bag_view = ItemRoomView.new()
	_bag_view.cell = 21
	scroll.add_child(_bag_view)
	bag[1].add_child(scroll)
	_bag_money = SocialUi.label("", SocialUi.GOLD, 14, HORIZONTAL_ALIGNMENT_CENTER)
	bag[1].add_child(_bag_money)
	cols.add_child(bag[0])

	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)

	## ---- Hàng nút: Đồng ý ■ | Xác nhận ■ | Huỷ bỏ
	var buttons := add_button_row()
	_lock_btn = SocialUi.stone_button("Đồng ý")
	_ok_btn = SocialUi.stone_button("Xác nhận")
	_cancel_btn = SocialUi.stone_button("Huỷ bỏ")
	_lock_light = SocialUi.indicator(false)
	_ok_light = SocialUi.indicator(false)
	_their_light = SocialUi.indicator(false)
	for pair in [[_lock_btn, _lock_light], [_ok_btn, _ok_light]]:
		var box := HBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 6)
		pair[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(pair[0])
		box.add_child(pair[1])
		buttons.add_child(box)
	_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_cancel_btn)
	var partner_box := HBoxContainer.new()
	partner_box.add_theme_constant_override("separation", 6)
	partner_box.add_child(SocialUi.label("Đối phương:", SocialUi.SUBTITLE, 12))
	partner_box.add_child(_their_light)
	buttons.add_child(partner_box)

	var mine_side := _session.local()
	_bag_view.item_pressed.connect(func(item: ItemInstance) -> void: _say(_session.offer_item(mine_side, item)))
	_mine_view.item_pressed.connect(func(item: ItemInstance) -> void: _say(_session.take_back(mine_side, item)))
	_bag_view.transfer_handler = func(item: ItemInstance, from: Object, _to: Object, _x: int, _y: int, _b: int) -> bool:
		return from == mine_side.room and _session.take_back(mine_side, item) == ""
	_mine_view.transfer_handler = func(item: ItemInstance, from: Object, _to: Object, _x: int, _y: int, _b: int) -> bool:
		return from == _profile and _session.offer_item(mine_side, item) == ""
	_my_money.pressed.connect(_on_money)
	_lock_btn.pressed.connect(func() -> void: _say(_session.lock(mine_side)))
	_ok_btn.pressed.connect(func() -> void: _say(_session.confirm(mine_side)))
	_cancel_btn.pressed.connect(_on_cancel)
	_session.changed.connect(_refresh)
	_session.finished.connect(_on_finished)
	_refresh()

## Thanh tiền kiểu ô dài "N lượng" (bấm ở phần của mình để nhập số tiền).
func _money_bar() -> Button:
	var b := SocialUi.small_button("0 lượng")
	b.add_theme_color_override("font_color", SocialUi.LABEL_GREEN)
	b.add_theme_color_override("font_disabled_color", SocialUi.LABEL_GREEN)
	b.custom_minimum_size = Vector2(0, 28)
	return b

func _on_money() -> void:
	if _session.local().locked:
		_say("Bạn đã khoá giao dịch, không sửa được nữa.")
		return
	SocialWindow.prompt(get_tree().current_scene, "Số tiền đưa", "Số lượng (0 – %d)" % _profile.gold, func(text: String) -> void:
		set_money_text(text), str(_session.local().money))

func set_money_text(text: String) -> void:
	var t := text.strip_edges()
	_say(_session.set_money(_session.local(), int(t) if t.is_valid_int() else 0))

func _process(delta: float) -> void:
	if _session == null or _finished:
		return
	## Trong cảnh chơi, SocialTicker đã đẩy nhịp; ở màn khác (Hub) cửa sổ tự đẩy.
	if get_tree().get_nodes_in_group("social_ticker").is_empty():
		_session.tick(delta)
	_update_wait()

func _update_wait() -> void:
	var mine := _session.local()
	var theirs := _session.partner()
	if theirs.ok and not mine.ok:
		var left := TradeSession.OK_DELAY_MS - (_session.now_ms - theirs.ok_at_ms)
		_status.text = "Đối phương đã xác nhận" + (" — chờ %d giây để bấm Xác nhận" % int(ceil(left / 1000.0)) if left > 0 else " — bạn có thể bấm Xác nhận")
	elif mine.ok and not theirs.ok:
		_status.text = "Chờ đối phương xác nhận…"

func _say(err: String) -> void:
	if err == "":
		_msg.visible = false
	else:
		SocialUi.set_banner(_msg, err, false)
		_msg.visible = true

func _refresh() -> void:
	if _finished:
		return
	var mine := _session.local()
	var theirs := _session.partner()
	_mine_view.setup(mine.room, _profile)
	_theirs_view.setup(theirs.room, _profile)
	_bag_view.bag = _bag
	_bag_view.setup(_profile)
	_my_money.text = "%s lượng" % InventoryPopup.format_money(mine.money)
	_their_money.text = "%s lượng" % InventoryPopup.format_money(theirs.money)
	_bag_money.text = "%s lượng" % InventoryPopup.format_money(_profile.gold)
	if not theirs.locked:
		_status.text = "Chờ đối phương đặt mật khoá"
	elif not mine.locked:
		_status.text = "Đối phương đã khoá — hãy xem lại rồi bấm Đồng ý"
	elif not theirs.ok and not mine.ok:
		_status.text = "Cả hai đã khoá — bấm Xác nhận để chốt"
	_comment.text = _session.mock_ai.comment if _session.mock_ai else ""
	SocialUi.set_indicator(_lock_light, mine.locked)
	SocialUi.set_indicator(_ok_light, mine.ok)
	SocialUi.set_indicator(_their_light, theirs.locked)
	_lock_btn.disabled = mine.locked
	_ok_btn.disabled = not (mine.locked and theirs.locked) or mine.ok
	_my_money.disabled = mine.locked

func _on_cancel() -> void:
	if _session.active:
		_session.cancel("Bạn đã huỷ giao dịch.")
	else:
		close_requested.emit()

func _on_finished(success: bool, message: String) -> void:
	_finished = true
	SocialUi.set_banner(_msg, message, success)
	_msg.visible = true
	for b in [_lock_btn, _ok_btn, _my_money]:
		b.disabled = true
	_cancel_btn.text = "Đóng"
	_cancel_btn.disabled = false
	SaveManager.save_profile(_profile)

extends SocialWindow
class_name StallWindow
## BÀY BÁN (người bán) — bấm món trong hành trang để đặt giá (món khoá không đặt được), viết lời rao, mở/dọn quầy; hoặc "Mở giao dịch"
## để người khác xin giao dịch trực tiếp. Khách giả mua theo giá (StallService.simulate_customers) và báo ở nhật ký.

var _hub: SocialHub
var _profile: PlayerProfile
var _bag_view: ItemRoomView
var _bag := 0
var _bag_tabs: Array[Button] = []
var _goods_box: VBoxContainer
var _log_box: VBoxContainer
var _state: PanelContainer
var _title_edit: LineEdit
var _msg: PanelContainer
var _stall_btn: Button
var _trade_btn: Button

static func open(host: Node, hub: SocialHub) -> StallWindow:
	return SocialWindow.present(host, StallWindow.new(hub), &"stall") as StallWindow

func _init(hub: SocialHub = null) -> void:
	super._init("Bày Bán", "Đặt giá cho đồ muốn bán, rồi mở quầy để người khác mua", 760.0)
	_hub = hub
	if _hub == null:
		return
	_profile = _hub.profile
	_state = SocialUi.banner("", false)
	body.add_child(_state)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	body.add_child(cols)

	var left := SocialUi.info_box("🎒 Hành trang — bấm món để đặt giá")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left[1].add_child(tabs)
	for i in PlayerProfile.OPEN_BAGS:
		var b := GameUi.button("Túi %d" % (i + 1), GameUi.TAB)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_bag = i
			_refresh())
		tabs.add_child(b)
		_bag_tabs.append(b)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PlayerProfile.ROOM_WIDTH * 37 + 10, 390)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bag_view = ItemRoomView.new()
	_bag_view.cell = 37
	scroll.add_child(_bag_view)
	left[1].add_child(scroll)
	cols.add_child(left[0])

	var right := SocialUi.section("🏷 Hàng trên quầy")
	right[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goods_box = VBoxContainer.new()
	_goods_box.add_theme_constant_override("separation", 4)
	right[1].add_child(_goods_box)
	right[1].add_child(SocialUi.divider())
	right[1].add_child(SocialUi.label("Nhật ký bán hàng", SocialUi.LABEL_GREEN, 13))
	_log_box = VBoxContainer.new()
	right[1].add_child(_log_box)
	cols.add_child(right[0])

	var title_row := SocialUi.kv("Lời rao:", "", SocialUi.LABEL_RED)
	_title_edit = SocialUi.line_edit("Ví dụ: Bán đồ giá mềm, ai cần ghé xem")
	_title_edit.text = _profile.stall_title
	_title_edit.max_length = 40
	_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.remove_child(title_row.get_child(1))
	title_row.add_child(_title_edit)
	body.add_child(title_row)

	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)
	var buttons := add_button_row()
	_stall_btn = SocialUi.stone_button("Mở quầy")
	_trade_btn = SocialUi.stone_button("Mở giao dịch")
	var lock_btn := SocialUi.stone_button("🔑 Khoá bảo vệ")
	var close := SocialUi.stone_button("Đóng")
	for b in [_stall_btn, _trade_btn, lock_btn, close]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	_bag_view.item_pressed.connect(_on_item)
	_stall_btn.pressed.connect(_on_stall)
	_trade_btn.pressed.connect(_on_trade)
	lock_btn.pressed.connect(func() -> void: SecurityWindow.open(get_tree().current_scene, _profile))
	close.pressed.connect(func() -> void: close_requested.emit())
	_hub.notice.connect(_on_notice)
	_refresh()

func _on_notice(_t: String, _g: bool) -> void:
	if is_inside_tree():
		_refresh()

func _exit_tree() -> void:
	if _hub != null and _hub.notice.is_connected(_on_notice):
		_hub.notice.disconnect(_on_notice)

func _say(err: String, ok_text := "") -> void:
	if err == "" and ok_text == "":
		_msg.visible = false
		return
	SocialUi.set_banner(_msg, err if err != "" else ok_text, err == "")
	_msg.visible = true

func _on_item(item: ItemInstance) -> void:
	if SecurityLock.is_item_locked(item):
		_say("Món đồ đang bị khoá, không đặt giá được. (%s)" % SecurityLock.describe_item_lock(item))
		return
	SocialWindow.prompt(get_tree().current_scene, "Đặt giá bán", "Giá (lượng, tối đa 2 tỷ), 0 = bỏ khỏi quầy", func(text: String) -> void:
		var price := clampi(int(text.strip_edges()) if text.strip_edges().is_valid_int() else -1, -1, 2_000_000_000)
		_say(StallService.set_price(_profile, item, price), "Đã đặt giá %d lượng." % price if price > 0 else "Đã bỏ món khỏi quầy.")
		_refresh(), str(item.trade_price) if item.trade_price > 0 else "", false, 2_000_000_000)

func _on_stall() -> void:
	if _profile.stall_open:
		StallService.close_stall(_profile)
		_say("", "Đã dọn quầy.")
		if NetClient.is_in_world():
			NetClient.send_stall(SocialServer.STALL_CLOSE)
	else:
		_profile.stall_title = _title_edit.text
		var err := StallService.open_stall(_profile, _title_edit.text, _is_riding())
		_say(err, "Quầy đã mở — chờ khách ghé xem.")
		if err == "" and NetClient.is_in_world():
			## Gửi giá vừa đặt cho server trước (cùng kênh tin cậy, đúng thứ tự) rồi mới mở quầy.
			SaveManager.save_profile(_profile)
			await SaveManager.flush_online()
			NetClient.send_stall(SocialServer.STALL_OPEN, _title_edit.text)
	SaveManager.save_profile(_profile)
	_refresh()

## Trạng thái cưỡi ngựa THẬT của nhân vật đang chơi (avatar có ngựa) — không dùng cờ lưu profile.riding (mặc định bật dù chưa có ngựa).
## Ở màn không có nhân vật (Hub) coi như không cưỡi.
func _is_riding() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.has_method("is_riding") and player.is_riding()

func _on_trade() -> void:
	if _profile.trade_open:
		StallService.close_trade(_profile)
		_say("", "Đã tắt mở giao dịch.")
		if NetClient.is_in_world():
			NetClient.send_stall(SocialServer.TRADE_CLOSE)
	else:
		var err := StallService.open_trade(_profile)
		_say(err, "Đã mở giao dịch — người khác có thể xin giao dịch với bạn.")
		if err == "" and NetClient.is_in_world():
			NetClient.send_stall(SocialServer.TRADE_OPEN)
	_refresh()

func _refresh() -> void:
	_bag_view.bag = _bag
	for i in _bag_tabs.size():
		GameUi.set_active(_bag_tabs[i], i == _bag)
	_bag_view.setup(_profile)
	if _profile.stall_open:
		SocialUi.set_banner(_state, "🏷 Quầy đang MỞ: \"%s\"" % _profile.stall_title, true)
	elif _profile.trade_open:
		SocialUi.set_banner(_state, "🤝 Đang MỞ GIAO DỊCH", true)
	else:
		SocialUi.set_banner(_state, "Quầy đang đóng", false)
	_stall_btn.text = "Dọn quầy" if _profile.stall_open else "Mở quầy"
	_trade_btn.text = "Tắt mở giao dịch" if _profile.trade_open else "Mở giao dịch"
	for c in _goods_box.get_children():
		c.queue_free()
	var goods := StallService.priced_items(_profile)
	if goods.is_empty():
		_goods_box.add_child(SocialUi.label("Chưa có món nào đặt giá.", SocialUi.MUTED, 13))
	for it in goods:
		var row := HBoxContainer.new()
		var name_l := SocialUi.label(it.get_display_name(), it.get_quality_color(), 13)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(SocialUi.label("%s lượng" % InventoryPopup.format_money(it.trade_price), SocialUi.GOLD, 13))
		var rm := SocialUi.small_button("Gỡ")
		rm.pressed.connect(func() -> void:
			StallService.set_price(_profile, it, 0)
			_refresh())
		row.add_child(rm)
		_goods_box.add_child(row)
	for c in _log_box.get_children():
		c.queue_free()
	for line in _hub.stall_log.slice(maxi(0, _hub.stall_log.size() - 6)):
		_log_box.add_child(SocialUi.label("• " + line, SocialUi.TEXT, 12))

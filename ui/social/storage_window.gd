extends SocialWindow
class_name StorageWindow
## RƯƠNG CHỨA ĐỒ — theo màn "Rương chứa đồ" của VLTK gốc: lưới rương ở bên trái, hàng nút [Mở khoá] [Mật mã] [Mở rộng], dòng tiền trong rương và
## [Rút tiền] [Đóng]; thêm bên phải là hành trang để kéo thả đồ qua lại. Rương đang KHOÁ BẢO VỆ thì lưới bị che và mọi thao tác bị chặn
## (mở khoá bằng bàn phím số). Luật: StorageService + SecurityLock.

var _profile: PlayerProfile
var _bag_view: ItemRoomView
var _box_view: ItemRoomView
var _bag_tabs: HBoxContainer
var _box_tabs: HBoxContainer
var _bag := 0
var _box := 0
var _store_row: HBoxContainer
var _bag_gold_row: HBoxContainer
var _msg: PanelContainer
var _lock_cover: PanelContainer
var _lock_btn: Button
var _expand_btn: Button
var _cell := 22

static func open(host: Node, profile: PlayerProfile) -> StorageWindow:
	return SocialWindow.present(host, StorageWindow.new(profile), &"storage") as StorageWindow

func _init(profile: PlayerProfile = null) -> void:
	super._init("Rương Chứa Đồ", "Kéo thả đồ giữa rương và hành trang — gửi tiền an toàn", 800.0)
	_profile = profile
	if _profile == null:
		return
	_cell = clampi(int((DisplayServer.window_get_size().y - 360.0) / PlayerProfile.ROOM_HEIGHT), 16, 28)

	var grids := HBoxContainer.new()
	grids.add_theme_constant_override("separation", 14)
	body.add_child(grids)

	## ---- Rương (bên trái)
	var chest := SocialUi.section("🧰 Rương chứa đồ", SocialUi.SECTION_ACCENT, SocialUi.SECTION_BG)
	_box_tabs = HBoxContainer.new()
	chest[1].add_child(_box_tabs)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(_profile.storage.ROOM_WIDTH * _cell + 8, _profile.storage.ROOM_HEIGHT * _cell + 8)
	var box_scroll := ScrollContainer.new()
	box_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box_view = ItemRoomView.new()
	_box_view.cell = _cell
	box_scroll.add_child(_box_view)
	stack.add_child(box_scroll)
	## Tấm che khi rương đang khoá
	_lock_cover = PanelContainer.new()
	_lock_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lock_cover.add_theme_stylebox_override("panel", SocialUi.box(Color(0.02, 0.025, 0.025, 0.98), SocialUi.BAD_BORDER, 6, 1, 12))
	var cover_text := SocialUi.label("🔒\nRương đang bị khoá bảo vệ\nbấm [Mở khoá] và nhập mật mã", SocialUi.LABEL_RED, 15, HORIZONTAL_ALIGNMENT_CENTER)
	cover_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lock_cover.add_child(cover_text)
	stack.add_child(_lock_cover)
	chest[1].add_child(stack)
	## Hàng nút dưới lưới rương: Mở khoá | Mật mã | Mở rộng (như ảnh gốc)
	var under := HBoxContainer.new()
	under.add_theme_constant_override("separation", 6)
	_lock_btn = SocialUi.small_button("Mở khoá")
	var pw_btn := SocialUi.small_button("Mật mã")
	_expand_btn = SocialUi.small_button("Mở rộng")
	for b in [_lock_btn, pw_btn, _expand_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		under.add_child(b)
	chest[1].add_child(under)
	## Tiền trong rương
	_store_row = SocialUi.kv("🪙 Tiền trong rương:", "", SocialUi.LABEL_GREEN, SocialUi.GOLD)
	chest[1].add_child(_store_row)
	var money_btns := HBoxContainer.new()
	money_btns.add_theme_constant_override("separation", 6)
	var dep := SocialUi.small_button("Gửi tiền")
	var wd := SocialUi.small_button("Rút tiền")
	for b in [dep, wd]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		money_btns.add_child(b)
	chest[1].add_child(money_btns)
	grids.add_child(chest[0])

	## ---- Hành trang (bên phải)
	var bag := SocialUi.section("🎒 Hành trang", SocialUi.LABEL_BLUE, SocialUi.INFO_BG)
	_bag_tabs = HBoxContainer.new()
	bag[1].add_child(_bag_tabs)
	var bag_scroll := ScrollContainer.new()
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_scroll.custom_minimum_size = Vector2(PlayerProfile.ROOM_WIDTH * _cell + 8, PlayerProfile.ROOM_HEIGHT * _cell + 8)
	_bag_view = ItemRoomView.new()
	_bag_view.cell = _cell
	bag_scroll.add_child(_bag_view)
	bag[1].add_child(bag_scroll)
	_bag_gold_row = SocialUi.kv("🪙 Tiền hành trang:", "", SocialUi.LABEL_BLUE, SocialUi.GOLD)
	bag[1].add_child(_bag_gold_row)
	grids.add_child(bag[0])

	## Kéo thả hai chiều
	var handler := func(item: ItemInstance, from: Object, to: Object, x: int, y: int, bag_index: int) -> bool:
		return StorageService.transfer(_profile, item, from, to, x, y, bag_index)
	_bag_view.transfer_handler = handler
	_box_view.transfer_handler = handler
	_bag_view.changed.connect(_refresh)
	_box_view.changed.connect(_refresh)
	_bag_view.item_pressed.connect(func(item: ItemInstance) -> void: _show_item(item, true))
	_box_view.item_pressed.connect(func(item: ItemInstance) -> void: _show_item(item, false))
	_lock_btn.pressed.connect(_on_lock_button)
	pw_btn.pressed.connect(func() -> void: SecurityWindow.open(get_tree().current_scene, _profile))
	_expand_btn.pressed.connect(_on_expand)
	dep.pressed.connect(func() -> void: _ask_money(true))
	wd.pressed.connect(func() -> void: _ask_money(false))

	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)
	var buttons := add_button_row()
	var close := SocialUi.stone_button("Đóng")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(close)
	close.pressed.connect(func() -> void: close_requested.emit())
	_refresh()

func _say(err: String, ok_text: String) -> void:
	SocialUi.set_banner(_msg, err if err != "" else ok_text, err == "")
	_msg.visible = true

func _tab_row(row: HBoxContainer, count: int, current: int, label_prefix: String, on_pick: Callable) -> void:
	for c in row.get_children():
		c.queue_free()
	for i in count:
		var b := SocialUi.small_button("%s %d" % [label_prefix, i + 1])
		b.disabled = i == current
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)

func _refresh() -> void:
	var locked := SecurityLock.is_locked(_profile)
	_bag = clampi(_bag, 0, PlayerProfile.OPEN_BAGS - 1)
	_box = clampi(_box, 0, StorageService.box_count(_profile) - 1)
	_tab_row(_bag_tabs, PlayerProfile.OPEN_BAGS, _bag, "Túi", func(i: int) -> void:
		_bag = i
		_refresh())
	_tab_row(_box_tabs, StorageService.box_count(_profile), _box, "Rương", func(i: int) -> void:
		_box = i
		_refresh())
	_bag_view.bag = _bag
	_bag_view.setup(_profile)
	_box_view.bag = _box
	_box_view.setup(_profile.storage, _profile)
	## Nút khoá: chưa có mật mã → "Đặt khoá"; có mật mã & đang khoá → "Mở khoá"; đang mở → "Khoá".
	if not SecurityLock.has_password(_profile):
		_lock_btn.text = "Đặt khoá"
	else:
		_lock_btn.text = "Mở khoá" if locked else "Khoá"
	_lock_cover.visible = locked
	SocialUi.set_kv(_store_row, "%s lượng" % InventoryPopup.format_money(_profile.storage_gold), SocialUi.GOLD)
	SocialUi.set_kv(_bag_gold_row, "%s lượng" % InventoryPopup.format_money(_profile.gold), SocialUi.GOLD)
	_expand_btn.disabled = _profile.storage_extra >= StorageService.MAX_EXTRA_BOXES
	_expand_btn.text = "Đã mở hết" if _expand_btn.disabled else "Mở rộng"
	SaveManager.save_profile(_profile)

func _on_lock_button() -> void:
	if not SecurityLock.has_password(_profile):
		SecurityWindow.open(get_tree().current_scene, _profile)
	elif SecurityLock.is_locked(_profile):
		KeypadWindow.ask(get_tree().current_scene, "Mở khoá rương", "Nhập mật mã để mở khoá rương.", func(code: String) -> void:
			_say(SecurityLock.unlock(_profile, code), "Đã mở khoá rương.")
			_refresh())
	else:
		_say(SecurityLock.lock(_profile), "Đã khoá rương.")
		_refresh()

func _show_item(item: ItemInstance, from_bag: bool) -> void:
	var actions := []
	if from_bag:
		actions.append(["Cất vào rương", func() -> void:
			_say(StorageService.store_item(_profile, item, _box), "Đã cất %s vào rương." % item.get_display_name())
			_refresh()])
	else:
		actions.append(["Lấy ra hành trang", func() -> void:
			_say(StorageService.take_item(_profile, item), "Đã lấy %s ra hành trang." % item.get_display_name())
			_refresh()])
	ItemDetailPopup.open(get_tree().current_scene, ItemText.build(item, _profile, -1, -1, false), actions, item)

func _on_expand() -> void:
	var cost := StorageService.extra_box_cost(_profile)
	SocialWindow.confirm(get_tree().current_scene, "Mở rộng rương", "Mở thêm 1 rương (6 × 10 ô) với giá %s lượng?" % InventoryPopup.format_money(cost), func() -> void:
		_say(StorageService.buy_extra_box(_profile), "Đã mở thêm một rương.")
		_refresh())

## Gửi/rút tiền: hộp nhập số tiền (bị chặn nếu rương đang khoá).
func _ask_money(deposit: bool) -> void:
	SocialWindow.prompt(get_tree().current_scene, "Gửi tiền" if deposit else "Rút tiền", "Số tiền (lượng)", func(text: String) -> void:
		submit_money(deposit, text))

func submit_money(deposit: bool, text: String) -> void:
	var t := text.strip_edges()
	var amount := int(t) if t.is_valid_int() else 0
	var err := StorageService.deposit_gold(_profile, amount) if deposit else StorageService.withdraw_gold(_profile, amount)
	_say(err, "Đã %s %d lượng." % ["gửi" if deposit else "rút", amount])
	_refresh()

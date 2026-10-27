extends SocialWindow
class_name StorageWindow
## RƯƠNG CHỨA ĐỒ — theo màn "Rương chứa đồ" của VLTK gốc: cửa sổ RIÊNG chỉ có lưới rương, hàng nút [Mở khoá] [Mật mã] [Mở rộng], dòng
## tiền trong rương và [Gửi tiền] [Rút tiền]. Hành trang là khung Hành trang thường (InventoryPopup) mở song song bên phải, được ghép
## (link_partner) để kéo thả đồ qua lại. Rương đang KHOÁ BẢO VỆ thì lưới bị che và mọi thao tác bị chặn (mở khoá bằng bàn phím số).
## Luật: StorageService + SecurityLock.

var _profile: PlayerProfile
var _box_view: ItemRoomView
var _box_tabs: HBoxContainer
var _box := 0
var _store_row: HBoxContainer
var _msg: PanelContainer
var _lock_cover: PanelContainer
var _lock_btn: Button
var _expand_btn: Button
var _cell := 22
## Khung Hành trang đang ghép; _own_inventory = do rương mở ra (đóng rương thì đóng theo).
var _inventory: InventoryPopup
var _own_inventory := false

static func open(host: Node, profile: PlayerProfile) -> StorageWindow:
	var win := SocialWindow.present(host, StorageWindow.new(profile), &"storage") as StorageWindow
	return win

func _ready() -> void:
	super._ready()
	if _is_in_character_hub():
		set_draggable(false)
		await get_tree().process_frame
		position = Vector2(560.0, 68.0)
		size = Vector2(280.0, 585.0)

func _init(profile: PlayerProfile = null) -> void:
	super._init("Rương Chứa Đồ", "", 280.0)
	_profile = profile
	if _profile == null:
		return
	_cell = 37
	custom_minimum_size = Vector2(280.0, 585.0)

	var chest := SocialUi.section("", SocialUi.SECTION_ACCENT, SocialUi.SECTION_BG)
	_box_tabs = HBoxContainer.new()
	_box_tabs.add_theme_constant_override("separation", 4)
	chest[1].add_child(_box_tabs)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(_profile.storage.ROOM_WIDTH * _cell + 8, _profile.storage.ROOM_HEIGHT * _cell + 8)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box_scroll := ScrollContainer.new()
	box_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box_view = ItemRoomView.new()
	_box_view.cell = _cell
	box_scroll.add_child(_box_view)
	stack.add_child(box_scroll)
	## Tấm che khi rương đang khoá
	_lock_cover = GameUi.panel(GameUi.BANNER_BAD)
	_lock_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cover_text := SocialUi.label(GameUi.ICON_LOCK + "\nRương đang bị khoá bảo vệ\nbấm [Mở khoá] và nhập mật mã", SocialUi.LABEL_RED, 15, HORIZONTAL_ALIGNMENT_CENTER)
	cover_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_store_row = SocialUi.kv(GameUi.ICON_GOLD + " Tiền trong rương:", "", SocialUi.LABEL_GREEN, SocialUi.GOLD)
	chest[1].add_child(_store_row)
	var money_btns := HBoxContainer.new()
	money_btns.add_theme_constant_override("separation", 6)
	var dep := SocialUi.small_button("Gửi tiền")
	var wd := SocialUi.small_button("Rút tiền")
	for b in [dep, wd]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		money_btns.add_child(b)
	chest[1].add_child(money_btns)
	body.add_child(chest[0])

	## Kéo thả hai chiều: lưới rương nhận món từ hành trang; hành trang nhận món từ rương qua link_partner (open_inventory).
	_box_view.transfer_handler = _transfer
	_box_view.changed.connect(_refresh)
	_box_view.item_pressed.connect(_show_item)
	_lock_btn.pressed.connect(_on_lock_button)
	pw_btn.pressed.connect(func() -> void: SecurityWindow.open(get_host(), _profile))
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
	close_requested.connect(_release_inventory)
	_refresh()

## Mở (hoặc dùng lại khung đang mở) khung Hành trang thường và ghép với rương.
func open_inventory() -> void:
	if _profile == null:
		return
	if not is_instance_valid(_inventory):
		_inventory = InventoryPopup.find_open(get_tree())
		_own_inventory = _inventory == null
		if _own_inventory:
			var host_target: Node = get_host()
			if get_parent() != null and get_parent().get_parent() != null:
				host_target = get_parent().get_parent()
			_inventory = InventoryPopup.open(host_target, _profile, Callable(), false)
		_inventory.link_partner(_transfer, func(item: ItemInstance) -> Array:
			return ["Cất vào rương", func() -> void:
				_say(StorageService.store_item(_profile, item, _box), "Đã cất %s vào rương." % item.get_display_name())
				_refresh()])
		_inventory.profile_changed.connect(_refresh)
		_inventory.tree_exiting.connect(_on_inventory_closed)
		_place_side_by_side()
	## Nổi ngang cửa sổ rương (khung chi tiết món mở từ hành trang không bị rương che).
	_inventory.layer = DraggableWindow.WINDOW_LAYER + 1

func _release_inventory() -> void:
	if not is_instance_valid(_inventory):
		return
	_inventory.profile_changed.disconnect(_refresh)
	_inventory.tree_exiting.disconnect(_on_inventory_closed)
	_inventory.unlink_partner()
	if _own_inventory:
		_inventory.queue_free()
	_inventory = null

func _on_inventory_closed() -> void:
	_inventory = null

## Rương bên trái, Hành trang bên phải, cả cụm canh giữa màn hình (chờ 2 frame để cả hai khung tự canh giữa xong).
func _place_side_by_side() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_inventory) or not is_inside_tree():
		return
	var inv_frame := _inventory.frame()
	var screen := get_viewport_rect().size
	var gap := 8.0
	var left := maxf(0.0, (screen.x - (size.x + gap + inv_frame.size.x)) * 0.5)
	position = Vector2(left, maxf(0.0, (screen.y - size.y) * 0.5))
	inv_frame.position = Vector2(minf(left + size.x + gap, maxf(0.0, screen.x - inv_frame.size.x)), maxf(0.0, (screen.y - inv_frame.size.y) * 0.5))

func _transfer(item: ItemInstance, from: Object, to: Object, x: int, y: int, bag_index: int) -> bool:
	return StorageService.transfer(_profile, item, from, to, x, y, bag_index)

func _say(err: String, ok_text: String) -> void:
	SocialUi.set_banner(_msg, err if err != "" else ok_text, err == "")
	_msg.visible = true

func _tab_row(row: HBoxContainer, count: int, current: int, label_prefix: String, on_pick: Callable) -> void:
	for c in row.get_children():
		c.queue_free()
	var unlocked := StorageService.box_count(_profile)
	for i in count:
		var is_unlocked := i < unlocked
		var has_items := _has_items_in_bag(i)
		var text := "%s %d" % [label_prefix, i + 1]
		if not is_unlocked:
			text = "🔒 %s %d" % [label_prefix, i + 1]
			if has_items:
				text = "🔒 %s %d (Có đồ)" % [label_prefix, i + 1]
		var b := GameUi.button(text, GameUi.TAB)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 10 if has_items else 11)
		if not is_unlocked:
			if has_items:
				b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
			else:
				b.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0.8))
			b.pressed.connect(func() -> void:
				var cost := StorageService.extra_box_cost(_profile)
				SocialWindow.confirm(get_tree().current_scene, "Mở khóa %s %d" % [label_prefix, i + 1],
					"Rương này đang bị khóa%s. Mở khóa rương với giá %s lượng để sử dụng và lấy đồ?" % [
						" (đang chứa vật phẩm ký gửi hoàn trả)" if has_items else "",
						InventoryPopup.format_money(cost)
					],
					func() -> void:
						_say(StorageService.buy_extra_box(_profile), "Đã mở khóa %s %d thành công!" % [label_prefix, i + 1])
						_refresh()
				)
			)
		else:
			GameUi.set_active(b, i == current)
			b.pressed.connect(on_pick.bind(i))
		row.add_child(b)

func _has_items_in_bag(bag_idx: int) -> bool:
	if _profile == null or _profile.storage == null:
		return false
	for it in _profile.storage.inventory:
		if it != null and it.room_bag == bag_idx:
			return true
	return false

func _refresh() -> void:
	var locked := SecurityLock.is_locked(_profile)
	_box = clampi(_box, 0, StorageService.box_count(_profile) - 1)
	var total_tabs := 1 + StorageService.MAX_EXTRA_BOXES
	_tab_row(_box_tabs, total_tabs, _box, "Rương", func(i: int) -> void:
		_box = i
		_refresh())
	_box_view.bag = _box
	_box_view.setup(_profile.storage, _profile)
	## Nút khoá: chưa có mật mã → "Đặt khoá"; có mật mã & đang khoá → "Mở khoá"; đang mở → "Khoá".
	if not SecurityLock.has_password(_profile):
		_lock_btn.text = "Đặt khoá"
	else:
		_lock_btn.text = "Mở khoá" if locked else "Khoá"
	_lock_cover.visible = locked
	SocialUi.set_kv(_store_row, "%s lượng" % InventoryPopup.format_money(_profile.storage_gold), SocialUi.GOLD)
	_expand_btn.disabled = _profile.storage_extra >= StorageService.MAX_EXTRA_BOXES
	_expand_btn.text = "Đã mở hết" if _expand_btn.disabled else "Mở rộng"
	if is_instance_valid(_inventory):
		_inventory.refresh()
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

func _show_item(item: ItemInstance) -> void:
	var actions := [["Lấy ra hành trang", func() -> void:
		_say(StorageService.take_item(_profile, item), "Đã lấy %s ra hành trang." % item.get_display_name())
		_refresh()]]
	ItemDetailPopup.open(get_tree().current_scene, ItemText.build(item, _profile, -1, -1, false), actions, item)

func _on_expand() -> void:
	var cost := StorageService.extra_box_cost(_profile)
	SocialWindow.confirm(get_tree().current_scene, "Mở rộng rương", "Mở thêm 1 rương (6 × %d ô) với giá %s lượng?" % [_profile.storage.ROOM_HEIGHT, InventoryPopup.format_money(cost)], func() -> void:
		_say(StorageService.buy_extra_box(_profile), "Đã mở thêm một rương.")
		_refresh())

## Gửi/rút tiền: hộp nhập số tiền (bị chặn nếu rương đang khoá, tối đa 2 tỷ lượng).
func _ask_money(deposit: bool) -> void:
	var max_amt: int = mini(_profile.gold, 2000000000) if deposit else mini(_profile.storage_gold, 2000000000)
	SocialWindow.prompt(get_tree().current_scene, "Gửi tiền" if deposit else "Rút tiền", "Số tiền (tối đa %s lượng)" % InventoryPopup.format_money(max_amt), func(text: String) -> void:
		submit_money(deposit, text), "", false, 2000000000)

func submit_money(deposit: bool, text: String) -> void:
	var t := text.strip_edges()
	var amount := clampi(int(t) if t.is_valid_int() else 0, 0, 2000000000)
	var err := StorageService.deposit_gold(_profile, amount) if deposit else StorageService.withdraw_gold(_profile, amount)
	_say(err, "Đã %s %d lượng." % ["gửi" if deposit else "rút", amount])
	_refresh()

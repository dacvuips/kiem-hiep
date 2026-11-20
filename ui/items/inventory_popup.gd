extends CanvasLayer
class_name InventoryPopup

const TouchScrollHelperScript = preload("res://ui/common/touch_scroll_helper.gd")
## Khung "Hành trang" kiểu VLTK: LƯỚI Ô 6 × 10 (ItemRoomView) — mỗi món là 1 khối chiếm số ô rộng × cao riêng, kéo thả để
## đổi chỗ; dải Lượng/Xu/KNB (CurrencyStrip) ngay dưới lưới, nút "Sắp xếp". Bấm 1 món -> khung chi tiết (ItemDetailPopup) với nút Trang bị / Vứt bỏ.
## Kéo thanh tiêu đề để di chuyển khung. Bố cục nằm trong InventoryPopup.tscn, khung/nút/màu lấy từ GameUi; script dựng lưới + đổ dữ liệu.
## Mọi thay đổi ghi vào PlayerProfile + lưu save, rồi gọi `on_changed` để màn gọi vẽ lại ô trang bị/chỉ số.

const SCENE_PATH := "res://ui/items/InventoryPopup.tscn"
var _profile: PlayerProfile
var _on_changed: Callable
var _modal: bool = true
var _room: ItemRoomView
var _bag: int = 0
var _dragging: bool = false
## Cửa sổ đi kèm (Rương chứa đồ) — xem link_partner().
var _partner_action: Callable
var _crafting_win: CompoundWindow = null
var _style_tab_active: StyleBox = null
var _style_tab_normal: StyleBox = null
var _tt_btn: Button = null
var _quick_sell_mode: bool = false
## Chế độ Sửa (nút "Sửa" cạnh "Bán"): bấm trang bị nào thì thợ rèn sửa món đó (RepairActions).
var _repair_mode: bool = false
var _repair_btn: Button

## Phát sau mỗi thay đổi hành trang (để cửa sổ đi kèm như Rương vẽ lại).
signal profile_changed

const GROUP := "inventory_popups"

## Tìm khung Hành trang đang mở (nếu có).
static func find_open(tree: SceneTree) -> InventoryPopup:
	for n in tree.get_nodes_in_group(GROUP):
		if n is InventoryPopup and is_instance_valid(n) and not n.is_queued_for_deletion():
			return n
	return null

## `modal` = true: có nền tối, bấm ra ngoài là đóng (màn Hub). false: không nền tối, khung nổi tự do để mở cùng
## lúc với khung Nhân vật (map đánh quái).
static func open(parent: Node, profile: PlayerProfile, on_changed: Callable, modal: bool = true) -> InventoryPopup:
	var popup: InventoryPopup = load(SCENE_PATH).instantiate()
	popup._profile = profile
	popup._on_changed = on_changed
	popup._modal = modal
	parent.add_child(popup)
	return popup

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	GameUi.apply()
	var gm: Node = get_node_or_null("/root/GmManager")
	if gm != null and gm.has_signal("profile_modified"):
		gm.profile_modified.connect(_on_external_profile_changed)
	if SaveManager != null and SaveManager.has_signal("profile_changed"):
		SaveManager.profile_changed.connect(_on_external_profile_changed)
	var dim: ColorRect = %Dim
	dim.color = GameUi.DIM
	dim.visible = _modal
	(%Message as Label).add_theme_color_override("font_color", GameUi.WARN)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	%CloseButton.pressed.connect(queue_free)
	%TitleBar.gui_input.connect(_on_title_input)
	%SortButton.text = tr(%SortButton.text)
	%SortButton.pressed.connect(_on_sort_pressed)

	## Nút Bán nhanh
	if has_node("%SellButton"):
		%SellButton.text = tr(%SellButton.text)
		%SellButton.tooltip_text = tr("Bật/Tắt chế độ bán nhanh: Nhấp vào món đồ để bán ngay.")
		%SellButton.pressed.connect(_toggle_quick_sell_mode)
		_repair_btn = RepairActions.make_button(%SellButton)
		_repair_btn.pressed.connect(func() -> void: _set_repair_mode(not _repair_mode))

	## Hiệu thuốc
	if has_node("%ShopButton"):
		%ShopButton.text = tr(%ShopButton.text)
		%ShopButton.pressed.connect(func() -> void:
			PotionShopWindow.open(_get_host(), func() -> void:
				if is_instance_valid(self):
					_refresh()
			, _profile))
	else:
		var shop := GameUi.button("Hiệu thuốc")
		shop.custom_minimum_size = (%SortButton as Control).custom_minimum_size
		shop.pressed.connect(func() -> void: PotionShopWindow.open(_get_host(), func() -> void:
			if is_instance_valid(self):
				_refresh()
		, _profile))
		(%SortButton as Control).add_sibling(shop)

	## Nút mở Tiền Trang (Nạp / Đổi Tiền Xu & KNB)
	_tt_btn = GameUi.button(tr("Tiền Trang"))
	_tt_btn.custom_minimum_size = (%SortButton as Control).custom_minimum_size
	_tt_btn.pressed.connect(func() -> void:
		TienTrangWindow.open(_get_host(), func() -> void:
			if is_instance_valid(self):
				_refresh()
		, _profile)
	)
	(%SortButton as Control).add_sibling(_tt_btn)

	## Lượng / Xu / KNB nằm TRONG khung, ngay dưới lưới ô (offline chỉ hiện Lượng). Nút "+" mở Tiền Trang / Kỳ Trân Các.
	var money_row := MarginContainer.new()
	money_row.add_theme_constant_override("margin_left", 4)
	money_row.add_theme_constant_override("margin_top", 6)
	money_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_row.add_child(CurrencyStrip.new(func() -> PlayerProfile: return _profile, func() -> void:
		if is_instance_valid(self):
			_refresh()))
	($Frame/Root/Body as Control).add_sibling(money_row)

	## Phong cách tab giống CharacterHub
	if %BagTabs.get_child_count() > 1:
		_style_tab_active = %BagTabs.get_child(0).get_theme_stylebox("normal")
		_style_tab_normal = %BagTabs.get_child(1).get_theme_stylebox("normal")

	var group := ButtonGroup.new()
	var bags := %BagTabs.get_children()
	for i in bags.size():
		var tab: Button = bags[i]
		tab.button_group = group
		tab.pressed.connect(_select_bag.bind(i))
		## Kéo 1 món thả lên tab = chuyển món sang túi đó.
		tab.set_drag_forwarding(Callable(), _can_drop_on_tab.bind(i), _drop_on_tab.bind(i))

	if has_node("%Grid"):
		(%Grid as Control).visible = false

	_room = ItemRoomView.new()
	_room.cell = 37
	_room.item_pressed.connect(_on_item_pressed)
	_room.item_right_clicked.connect(_on_item_right_clicked)
	_room.changed.connect(_commit)

	if has_node("%InvScroll"):
		%InvScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		%InvScroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		%InvScroll.add_child(_room)
		TouchScrollHelperScript.attach(%InvScroll, $Frame/Root/Body as Control)
	else:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(PlayerProfile.ROOM_WIDTH, PlayerProfile.ROOM_HEIGHT) * _room.cell
		scroll.add_child(_room)
		$Frame/Root/Body/GridFrame.add_child(scroll)
		TouchScrollHelperScript.attach(scroll, $Frame/Root/Body as Control)

	if has_node("%TestRow"):
		var is_gm := AccountApi.is_gm()
		%TestRow.visible = is_gm
		if not is_gm:
			%TestRow.queue_free()
		else:
			if has_node("%TestAddButton"):
				%TestAddButton.pressed.connect(_on_test_items_pressed)
			if has_node("%TestCreateButton"):
				%TestCreateButton.text = tr(%TestCreateButton.text)
				%TestCreateButton.pressed.connect(func() -> void: ItemCreatorPopup.open(self, _profile, _commit))
			if has_node("%TestMaskButton"):
				%TestMaskButton.pressed.connect(_on_test_mask_pressed)
			if has_node("%TestMantleButton"):
				%TestMantleButton.pressed.connect(_on_test_mantle_pressed)

	_room.setup(_profile)
	_refresh()
	## Hub (modal): giữa màn hình. Map đánh quái (không modal): bám mép PHẢI, chừa bên trái cho bảng Nhân vật
	## (sau 1 frame để container tính xong kích thước).
	await get_tree().process_frame
	var frame: Control = %Frame
	frame.size = frame.get_combined_minimum_size()
	var screen := frame.get_viewport_rect().size
	if _modal:
		frame.position = (screen - frame.size) * 0.5
	else:
		frame.position = Vector2(maxf(0.0, screen.x - frame.size.x - 4.0), maxf(0.0, (screen.y - frame.size.y) * 0.5)).round()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if has_node("%SortButton"):
			%SortButton.text = tr("Sắp Xếp")
		if has_node("%SellButton"):
			%SellButton.text = tr("Đang Bán") if _quick_sell_mode else tr("Bán")
		if has_node("%ShopButton"):
			%ShopButton.text = tr("Hiệu Thuốc")
		if is_instance_valid(_tt_btn):
			_tt_btn.text = tr("Tiền Trang")
		if has_node("%BagTabs"):
			var bags := %BagTabs.get_children()
			for i in bags.size():
				bags[i].text = tr("Túi %d" % [i + 1])
		var title_lbl := get_node_or_null("Frame/Root/TitleBar/TitleRow/Title") as Label
		if title_lbl:
			title_lbl.text = tr("Hành trang")

func _get_host() -> Node:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree != null else null

func _open_crafting() -> void:
	_crafting_win = CompoundWindow.open(_get_host(), _profile, func() -> void:
		if is_instance_valid(self):
			_refresh())
	if is_instance_valid(_crafting_win):
		_crafting_win.slots_changed.connect(func() -> void:
			if is_instance_valid(self):
				_refresh())
		_crafting_win.tree_exiting.connect(func() -> void:
			_crafting_win = null
			if is_instance_valid(self):
				_refresh())

## Ghép với cửa sổ khác (Rương chứa đồ): `handler(item, from, to, x, y, bag) -> bool` cho phép kéo món từ lưới của cửa sổ đó thả vào
## hành trang; `item_action(item) -> Array` trả thêm 1 nút [nhãn, Callable] trong khung chi tiết món (vd. "Cất vào rương"), [] = không thêm.
func link_partner(handler: Callable, item_action: Callable) -> void:
	_room.transfer_handler = handler
	_partner_action = item_action

func unlink_partner() -> void:
	_room.transfer_handler = Callable()
	_partner_action = Callable()

func _on_external_profile_changed(p: PlayerProfile) -> void:
	if not is_instance_valid(self):
		return
	if p == null or p == _profile or (GameManager != null and p == GameManager.local_profile):
		if GameManager != null and GameManager.local_profile != null and _profile == null:
			_profile = GameManager.local_profile
		refresh()

func refresh() -> void:
	_refresh()

func frame() -> Control:
	return %Frame

func _select_bag(bag: int) -> void:
	_bag = bag
	_refresh()

func _can_drop_on_tab(_at: Vector2, data: Variant, bag: int) -> bool:
	return data is Dictionary and data.get("type") == ItemRoomView.DRAG_TYPE and bag < PlayerProfile.OPEN_BAGS 			and (data["item"] as ItemInstance).room_bag != bag

func _drop_on_tab(_at: Vector2, data: Variant, bag: int) -> void:
	if _profile.move_to_bag(data["item"], bag):
		_show_message("")
		_commit()
	else:
		_show_message("Túi %d đã đầy chỗ cho món này" % (bag + 1))

func _refresh() -> void:
	var bags := %BagTabs.get_children()
	for i in bags.size():
		var tab: Button = bags[i]
		tab.disabled = i >= PlayerProfile.OPEN_BAGS
		tab.tooltip_text = "Chưa mở" if tab.disabled else ""
		tab.set_pressed_no_signal(i == _bag)
		if _style_tab_active and _style_tab_normal and not tab.disabled:
			tab.add_theme_stylebox_override("normal", _style_tab_active if i == _bag else _style_tab_normal)
	_room.bag = _bag
	if is_instance_valid(_crafting_win) and _crafting_win.visible:
		_room.slotted_counts = _crafting_win.get_used_counts()
	else:
		_room.slotted_counts = {}
	_room.rebuild()
	if has_node("%GoldValue"):
		(%GoldValue as Label).text = format_money(_profile.gold) + " Lượng"
	if has_node("%XuValue"):
		(%XuValue as Label).text = format_money(_profile.xu) + " Xu"
	if has_node("%JadeValue"):
		(%JadeValue as Label).text = format_money(_profile.jade)

## Kiểu VLTK: 9985010 -> "998 vạn 5010".
static func format_money(value: int) -> String:
	@warning_ignore("integer_division")
	var van := value / 10000
	var rest := value % 10000
	if van <= 0:
		return str(rest)
	return "%d vạn %d" % [van, rest] if rest > 0 else "%d vạn" % van

func _on_item_right_clicked(item: ItemInstance) -> void:
	if item == null or _profile == null:
		return
	ItemDetailPopup.close_all(get_tree())

	# 1. Nếu có mở rương chứa đồ (StorageWindow) -> Cất vào rương ngay
	var storage_win: StorageWindow = null
	for w in get_tree().get_nodes_in_group("social_windows"):
		if w is StorageWindow and is_instance_valid(w):
			storage_win = w
			break
	if storage_win != null:
		var blocked := SecurityLock.check(_profile, SecurityLock.A_STORAGE)
		if blocked != "":
			_show_message(blocked, true)
			return
		var err := StorageService.store_item(_profile, item, storage_win._box)
		if err != "":
			_show_message(err, true)
		else:
			_show_message("Đã cất %s vào rương." % item.get_display_name())
			_commit()
			storage_win._refresh()
		return

	# 2. Nếu rương chứa đồ không mở:
	var index := _profile.inventory.find(item)
	if index < 0:
		return

	# 2a. Nếu là trang bị (vũ khí, áo, nón, đai, giày, phi phong, trang sức...) -> Mặc vào người ngay
	if not item.is_misc():
		_equip(index)
		return

	# 2b. Nếu là vật phẩm có thể dùng (thuốc, phù, rương báu, hộp quà, bí kíp, đan dược...) -> Dùng ngay
	if ItemConsumer.is_usable(item):
		_use(index)
		return

func _on_item_pressed(item: ItemInstance) -> void:
	var index := _profile.inventory.find(item)
	if index < 0:
		return
	if _repair_mode:
		RepairActions.click(_profile, item, self, _commit, _show_message)
		return
	if _quick_sell_mode:
		_sell(index)
		return
	var actions := []
	if not item.is_misc():
		actions.append(["Trang bị", _equip.bind(index)])
		actions.append_array(RepairActions.for_item(_profile, item, _commit, _show_message))
	elif ItemConsumer.is_usable(item):
		var use_label := ItemConsumer.get_action_label(item)
		if use_label != "":
			actions.append([use_label, _use.bind(index)])

	# Thêm các nút tính năng đặc biệt của Lệnh bài / Tín vật sự kiện / Nguyên liệu ép đồ
	var special_acts := ItemConsumer.get_special_actions(item, _get_host(), _profile, Callable(), _commit)
	for sa in special_acts:
		actions.append(sa)

	if item.can_sell():
		var label := "Bán (%s Lượng)" % format_money(item.get_sale_price())
		actions.append([label, _sell.bind(index)])

	if PubgManager.discard_block_reason(item, PubgManager.is_pubg_active()) == "":
		actions.append(["Vứt bỏ", _drop.bind(index)])   ## đồ Hoàng Kim: chỉ có nút Vứt bỏ trong trận PUBG

	if PotionEffect.usable(item) or ItemConsumer.is_town_portal(item):
		for i in _profile.quick_items.size():
			actions.append(["Gắn vào ô %d" % (i + 1), _set_quick_slot.bind(item.misc_id, i)])
	if _partner_action.is_valid():
		var extra: Array = _partner_action.call(item)
		if not extra.is_empty():
			actions.push_front(extra)
	if is_instance_valid(_crafting_win) and _crafting_win.visible:
		actions.insert(0, ["Đặt vào chế tạo", func() -> void: _crafting_win._put(item)])
	ItemDetailPopup.open(self, ItemText.build(item, _profile, -1, -1, false), actions, item)

## "Bán": đổi vật phẩm lấy Lượng theo công thức VLTK gốc (price / 4). Đồ quý (hoàng kim, đồ tím) hỏi xác nhận trước.
func _sell(index: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	var item: ItemInstance = _profile.inventory[index]
	var blocked := SecurityLock.check(_profile, SecurityLock.A_NPC_SELL)
	if blocked == "" and SecurityLock.is_item_locked(item):
		blocked = "Món đồ đang bị khoá, không thể bán."
	if blocked == "" and item.lock_sell:
		blocked = "Vật phẩm khoá, không thể bán cho cửa hàng."
	if blocked != "":
		_show_message(blocked)
		return
	if not item.can_sell():
		_show_message("Vật phẩm này không thể bán.")
		return

	var sale_price := item.get_sale_price()
	var item_name := item.get_display_name()

	if item.is_gold() or item.is_purple():
		_confirm_sell(index, item_name, sale_price)
		return

	_execute_sell(index, item_name, sale_price)

func _confirm_sell(index: int, item_name: String, sale_price: int) -> void:
	var item: ItemInstance = _profile.inventory[index]
	confirm_sell(self, item, sale_price, func() -> void: _execute_sell(index, item_name, sale_price))

## Hộp xác nhận bán đồ quý (dùng chung Hành trang + Hub): khung SocialWindow chuẩn, ảnh món + tên màu phẩm chất + giá vàng nổi bật.
## on_yes chỉ gọi khi bấm "Bán"; ✕ / "Huỷ" là bỏ.
static func confirm_sell(host: Node, item: ItemInstance, sale_price: int, on_yes: Callable) -> void:
	var win := SocialWindow.new("Xác nhận bán", "", 340.0)
	var center := CenterContainer.new()
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 12)
	center.add_child(card)
	var slot := GameUi.panel(GameUi.PANEL)
	slot.custom_minimum_size = Vector2(56, 56)
	var tex := item.get_icon(true)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		slot.add_child(icon)
	card.add_child(slot)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	var name_l := GameUi.label(item.get_display_name(), item.get_quality_color(), 15)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size.x = 200
	info.add_child(name_l)
	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 6)
	price_row.add_child(GameUi.label("Giá bán:", GameUi.MUTED, 13))
	price_row.add_child(GameUi.label("%s Lượng" % format_money(sale_price), GameUi.GOLD, 15))
	info.add_child(price_row)
	card.add_child(info)
	win.body.add_child(center)
	var q := GameUi.label("Bán món này cho NPC? Không thể lấy lại.", GameUi.SUBTITLE, 13, HORIZONTAL_ALIGNMENT_CENTER)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win.body.add_child(q)
	var row := win.add_button_row()
	var sell := GameUi.button("Bán", GameUi.PRIMARY)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cancel := GameUi.button("Huỷ", GameUi.BUTTON)
	cancel.custom_minimum_size.y = GameUi.PRIMARY_HEIGHT
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sell)
	row.add_child(cancel)
	SocialWindow.present(host, win, &"confirm_sell")
	sell.pressed.connect(func() -> void:
		win.close_requested.emit()
		on_yes.call()
	)
	cancel.pressed.connect(func() -> void: win.close_requested.emit())

func _execute_sell(index: int, item_name: String, sale_price: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	_profile.inventory.remove_at(index)
	_profile.gold += sale_price
	if SfxManager != null and VltkSound != null:
		SfxManager.play_ui(VltkSound.ui(VltkSound.UI_ITEM))
	_show_message("Đã bán %s nhận được %s Lượng." % [item_name, format_money(sale_price)])
	_commit()

func _toggle_quick_sell_mode() -> void:
	_set_quick_sell_mode(not _quick_sell_mode)

func _set_repair_mode(enabled: bool) -> void:
	_repair_mode = enabled
	RepairActions.set_button_active(_repair_btn, enabled)
	if enabled:
		if _quick_sell_mode:
			_set_quick_sell_mode(false)
		_show_message(RepairActions.mode_hint(_profile))
	else:
		_show_message("Đã tắt chế độ Sửa.")

func _set_quick_sell_mode(enabled: bool) -> void:
	if enabled and _repair_mode:
		_set_repair_mode(false)
	_quick_sell_mode = enabled
	_update_sell_button_visual()
	if _quick_sell_mode:
		_show_message("Chế độ Bán: Nhấp chuột vào món đồ để bán nhanh (Bấm nút Bán để tắt).")
	else:
		_show_message("Đã tắt chế độ Bán.")

func _update_sell_button_visual() -> void:
	if not has_node("%SellButton"):
		return
	var btn := %SellButton as Button
	if _quick_sell_mode:
		btn.text = tr("Đang Bán")
		var active_style := StyleBoxFlat.new()
		active_style.bg_color = Color(0.65, 0.14, 0.08, 0.95)
		active_style.border_color = Color(1.0, 0.55, 0.25, 1.0)
		active_style.set_border_width_all(1)
		active_style.set_corner_radius_all(6)
		active_style.shadow_color = Color(0.95, 0.25, 0.1, 0.6)
		active_style.shadow_size = 4
		btn.add_theme_stylebox_override("normal", active_style)
		btn.add_theme_stylebox_override("hover", active_style)
		btn.add_theme_stylebox_override("pressed", active_style)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	else:
		btn.text = tr("Bán")
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")
		btn.remove_theme_color_override("font_color")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			if _quick_sell_mode:
				_set_quick_sell_mode(false)
				get_viewport().set_input_as_handled()
				return
			if _repair_mode:
				_set_repair_mode(false)
				get_viewport().set_input_as_handled()
				return
			queue_free()
			get_viewport().set_input_as_handled()

func _open_viem_de_chest(index: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	var item: ItemInstance = _profile.inventory[index]
	if item.count > 1:
		item.count -= 1
	else:
		_profile.inventory.remove_at(index)

	var gained_exp := randi_range(1500000, 3500000)
	var gained_gold := randi_range(150000, 350000)
	_profile.add_exp(gained_exp)
	_profile.gold += gained_gold

	var frags := randi_range(1, 3)
	for i in frags:
		var frag_it := ItemGenerator.generate_misc("6_1_1685")
		if frag_it != null:
			_profile.add_item(frag_it)

	var tt_ids := ["4_238_1", "4_239_1", "4_240_1"]
	var tt_pick: String = tt_ids.pick_random()
	var tt_it := ItemGenerator.generate_misc(tt_pick)
	var tt_name := "Thủy Tinh"
	if tt_it != null:
		tt_name = tt_it.get_name()
		_profile.add_item(tt_it)

	var w_script: GDScript = load("res://ui/events/viem_de_window.gd")
	if w_script != null:
		var rec: Dictionary = w_script._get_records_for(_profile)
		rec["chests"] = maxi(0, int(rec.get("chests", 0)) - 1)
		rec["totem_fragments"] = int(rec.get("totem_fragments", 0)) + frags
		w_script._save_records_for(rec, _profile)

	_show_message("Mở [Viêm Đế Bí Bảo] thành công!\n+ %s EXP\n+ %s Lượng\n+ %d Mảnh Đồ Đằng Viêm Đế\n+ 1 %s" % [
		format_money(gained_exp),
		format_money(gained_gold),
		frags,
		tt_name
	])
	_commit()

func _craft_viem_de_totem(_index: int) -> void:
	if _profile == null:
		return
	var res: Dictionary = ViemDeWindow.craft_totem_quick(_profile)
	_show_message(str(res.get("message", "")))
	_commit()
	_refresh()

## "Dùng" vật phẩm: hỗ trợ dùng rương báu, lễ hộp, thuốc lắc, bí kíp, lệnh bài, đan dược...
func _use(index: int) -> void:
	if _profile == null or index >= _profile.inventory.size():
		return
	var player := get_tree().get_first_node_in_group("player")
	var item := _profile.inventory[index]
	var res := ItemConsumer.use_item(_profile, item, player, _get_host())
	if res.get("exit_to_hub", false):
		queue_free()
		return
	if res.has("message") and str(res["message"]) != "":
		_show_message(str(res["message"]), not res.get("ok", false))
	if res.get("ok", false):
		_commit()

func _set_quick_slot(misc_id: String, slot: int) -> void:
	_profile.quick_items[slot] = misc_id
	_show_message("Đã gắn %s vào ô thuốc %d" % [str(ItemDatabase.get_misc(misc_id).get("name", "")), slot + 1])
	_commit()
	for bar in get_tree().get_nodes_in_group(QuickItemBar.GROUP):
		(bar as QuickItemBar).refresh()

func _equip(index: int) -> void:
	var err := _profile.equip_from_inventory(index)
	_show_message(err)
	if err == "":
		_commit()

## "Vứt bỏ": trong trận thì món đồ RƠI XUỐNG ĐẤT ngay dưới chân nhân vật (nhấp vào để nhặt lại); ở ngoài trận (Hub, không có
## nhân vật trên bản đồ) thì không có chỗ rơi nên bỏ hẳn.
func _drop(index: int) -> void:
	if index >= _profile.inventory.size():
		return
	var item := _profile.inventory[index]
	var blocked := SecurityLock.check(_profile, SecurityLock.A_DROP_ITEM)
	if blocked == "" and SecurityLock.is_item_locked(item):
		blocked = "Món đồ đang bị khoá, không vứt được."
	if blocked == "" and item.lock_drop:
		blocked = "Vật phẩm khoá, không thể vứt ra đất."
	if blocked == "":
		blocked = PubgManager.discard_block_reason(item, PubgManager.is_pubg_active())
	if blocked != "":
		_show_message(blocked)
		return
	_profile.inventory.remove_at(index)
	if NetClient.is_in_world():
		## Online: server đặt món xuống đất (mọi người ở gần đều thấy).
		GroundDrop.mark_discarded(item.ensure_uid())
		NetClient.send_discard(item.uid)
		_show_message("Đã vứt %s xuống đất" % item.get_display_name())
		_commit()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var parent: Node = VltkWorld.entity_parent()
		if parent == null:
			parent = player.get_parent()
		var feet := player.global_position + Vector2(0, 30)
		GroundDrop.spawn_drops(parent, feet + Vector2(randf_range(-14, 14), 6), [{"type": "item", "item": item, "discarded": true}])
		_show_message("Đã vứt %s xuống đất" % item.get_display_name())
	else:
		_show_message("")
	_commit()

## Sắp xếp: theo loại đồ (vũ khí, áo, mũ...), hoàng kim trước, cấp cao trước, rồi xếp lại từ đầu lưới.
func _on_sort_pressed() -> void:
	_profile.sort_inventory()
	_commit()

func _on_test_items_pressed() -> void:
	for i in 10:
		_profile.add_item(ItemGenerator.random_equipment(_profile.level))
	_show_message("Đã thêm 10 trang bị ngẫu nhiên")
	_commit()

func _on_test_mask_pressed() -> void:
	if _profile == null:
		return
	var added := 0
	for p in 5:
		var mask_item := ItemGenerator.generate(ItemDatabase.Detail.MASK, p, 1, int(_profile.get_element()), [5, 5, 5, 5, 5, 5])
		if mask_item and _profile.add_item(mask_item):
			added += 1
	_show_message("Đã thêm %d Mặt Nạ vào hành trang!" % added)
	_commit()

func _on_test_mantle_pressed() -> void:
	if _profile == null:
		return
	var added := 0
	for lv in [1, 3, 5, 6, 7]:
		var mantle_item := ItemGenerator.generate(ItemDatabase.Detail.MANTLE, 0, lv, int(_profile.get_element()), [6, 6, 6, 6, 6, 6])
		if mantle_item and _profile.add_item(mantle_item):
			added += 1
	_show_message("Đã thêm %d Phi Phong vào hành trang!" % added)
	_commit()

func _show_message(text: String, is_error: bool = false) -> void:
	var msg := %Message as Label
	if msg:
		msg.text = text
		if not is_error:
			var lower := text.to_lower()
			for kw in ["cảnh giới", "không thể", "thất bại", "chưa đủ", "không đủ", "đã đầy", "chưa mở", "không chính xác", "đã tối đa", "lỗi"]:
				if kw in lower:
					is_error = true
					break
		if is_error:
			msg.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
		else:
			msg.add_theme_color_override("font_color", Color(1, 0.75, 0.35, 1))

func _commit() -> void:
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	_refresh()
	profile_changed.emit()
	if _on_changed.is_valid():
		_on_changed.call()

## Kéo thanh tiêu đề để di chuyển khung (giữ trong màn hình).
func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var frame: Control = %Frame
		var screen := frame.get_viewport_rect().size
		frame.position = (frame.position + event.relative).clamp(Vector2.ZERO, (screen - frame.size).max(Vector2.ZERO))

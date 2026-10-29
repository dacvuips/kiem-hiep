extends CanvasLayer
class_name InventoryPopup

const TouchScrollHelperScript = preload("res://ui/common/touch_scroll_helper.gd")
## Khung "Hành trang" kiểu VLTK: LƯỚI Ô 6 × 10 (ItemRoomView) — mỗi món là 1 khối chiếm số ô rộng × cao riêng, kéo thả để
## đổi chỗ; tiền ở dưới, nút "Sắp xếp". Bấm 1 món -> khung chi tiết (ItemDetailPopup) với nút Trang bị / Vứt bỏ.
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
	GmManager.profile_modified.connect(func(p: PlayerProfile) -> void:
		if p == null or p == _profile or p == GameManager.local_profile:
			refresh()
	)
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

	# Gắn sự kiện click cho các nút cộng trong thanh tiền tệ
	for frame_path in ["Frame/Root/BottomMoneyBar/FrameGold", "Frame/Root/BottomMoneyBar/FrameXu", "Frame/Root/BottomMoneyBar/FrameJade"]:
		var f := get_node_or_null(frame_path)
		if f:
			var plus: Control = f.get_node_or_null("PlusBtn")
			if plus:
				plus.mouse_filter = Control.MOUSE_FILTER_STOP
				plus.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				plus.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
						TienTrangWindow.open(_get_host(), func() -> void:
							if is_instance_valid(self):
								_refresh()
						, _profile)
				)

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
	## Đặt giữa màn hình (sau 1 frame để container tính xong kích thước).
	await get_tree().process_frame
	var frame: Control = %Frame
	frame.size = frame.get_combined_minimum_size()
	frame.position = (frame.get_viewport_rect().size - frame.size) * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if has_node("%SortButton"):
			%SortButton.text = tr("Sắp Xếp")
		if has_node("%ShopButton"):
			%ShopButton.text = tr("Hiệu Thuốc")
		if is_instance_valid(_tt_btn):
			_tt_btn.text = tr("Tiền Trang")
		if has_node("%TestCreateButton"):
			%TestCreateButton.text = tr("Test Đồ (TEST)")
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

func _on_item_pressed(item: ItemInstance) -> void:
	var index := _profile.inventory.find(item)
	if index < 0:
		return
	var actions := []
	if not item.is_misc():
		actions.append(["Trang bị", _equip.bind(index)])
	else:
		var use_label := ItemConsumer.get_action_label(item)
		actions.append([use_label, _use.bind(index)])
	actions.append(["Vứt bỏ", _drop.bind(index)])

	if item.misc_id in ["4_238_1", "4_239_1", "4_240_1", "4_353_1"]:
		actions.append(["Tiệm Ép Đồ", func() -> void: CompoundWindow.open(_get_host(), _profile, Callable())])
	elif item.misc_id in ["6_1_2805", "6_1_1685", "6_1_1606"]:
		actions.append(["Tiệm Đổi Viêm Đế", func() -> void: ViemDeWindow.open_reward_shop(_get_host(), _profile)])

	if PotionEffect.usable(item):
		for i in _profile.quick_items.size():
			actions.append(["Gắn vào ô %d" % (i + 1), _set_quick_slot.bind(item.misc_id, i)])
	if item.can_sell():
		var label := "Bán (%s Lượng)" % format_money(item.get_sale_price())
		actions.insert(1, [label, _sell.bind(index)])
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
	var popup := ConfirmationDialog.new()
	popup.title = "Xác nhận bán"
	popup.dialog_text = "Bạn có chắc muốn bán [%s] với giá %s Lượng không?" % [item_name, format_money(sale_price)]
	popup.ok_button_text = "Bán"
	popup.cancel_button_text = "Hủy"
	add_child(popup)
	popup.confirmed.connect(func() -> void:
		_execute_sell(index, item_name, sale_price)
		popup.queue_free()
	)
	popup.canceled.connect(func() -> void:
		popup.queue_free()
	)
	popup.popup_centered()

func _execute_sell(index: int, item_name: String, sale_price: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	_profile.inventory.remove_at(index)
	_profile.gold += sale_price
	_show_message("Đã bán %s nhận được %s Lượng." % [item_name, format_money(sale_price)])
	_commit()

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
	if blocked != "":
		_show_message(blocked)
		return
	_profile.inventory.remove_at(index)
	if NetClient.is_in_world():
		## Online: server đặt món xuống đất (mọi người ở gần đều thấy).
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
		GroundDrop.spawn_drops(parent, feet + Vector2(randf_range(-14, 14), 6), [{"type": "item", "item": item}])
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

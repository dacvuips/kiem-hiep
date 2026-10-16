extends CanvasLayer
class_name InventoryPopup
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
	## Khung/nút/tab lấy từ GameUi (theme_type_variation trong .tscn); chỉ màu mang nghĩa đặt ở đây theo bảng màu chung.
	GameUi.apply()
	var dim: ColorRect = %Dim
	dim.color = GameUi.DIM
	dim.visible = _modal
	(%GoldValue as Label).add_theme_color_override("font_color", GameUi.GOLD)
	(%JadeValue as Label).add_theme_color_override("font_color", GameUi.GOLD)
	$Frame/Root/Bottom/Money/GoldRow/GoldLine/GoldName.add_theme_color_override("font_color", GameUi.TEXT)
	$Frame/Root/Bottom/Money/JadeRow/JadeLine/JadeName.add_theme_color_override("font_color", GameUi.LABEL_GREEN)
	(%Message as Label).add_theme_color_override("font_color", GameUi.WARN)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	%CloseButton.pressed.connect(queue_free)
	%TitleBar.gui_input.connect(_on_title_input)
	%SortButton.pressed.connect(_on_sort_pressed)
	## Hiệu thuốc: bán mọi loại thuốc (PotionShopWindow) — mua xong vẽ lại túi.
	var shop := GameUi.button("Hiệu thuốc")
	shop.custom_minimum_size = (%SortButton as Control).custom_minimum_size
	shop.pressed.connect(func() -> void: PotionShopWindow.open(get_tree().current_scene, func() -> void:
		if is_instance_valid(self):
			_refresh()))
	(%SortButton as Control).add_sibling(shop)
	## Chế tạo: Sát thủ giản, Huyền Tinh, đồ tím (CompoundWindow) — xong vẽ lại túi.
	var craft := GameUi.button("Chế tạo")
	craft.custom_minimum_size = (%SortButton as Control).custom_minimum_size
	craft.pressed.connect(func() -> void: CompoundWindow.open(get_tree().current_scene, _profile, func() -> void:
		if is_instance_valid(self):
			_refresh()))
	shop.add_sibling(craft)

	## Lưới ô kiểu VLTK thay cho lưới 6x6 + cột "Túi 1..6" cũ (1 hành trang duy nhất 6 x 10 ô).
	var group := ButtonGroup.new()
	var bags := %BagTabs.get_children()
	for i in bags.size():
		var tab: Button = bags[i]
		tab.button_group = group
		tab.pressed.connect(_select_bag.bind(i))
		## Kéo 1 món thả lên tab = chuyển món sang túi đó.
		tab.set_drag_forwarding(Callable(), _can_drop_on_tab.bind(i), _drop_on_tab.bind(i))
	var old_grid: Control = %Grid
	old_grid.visible = false
	_room = ItemRoomView.new()
	## Cỡ ô co theo chiều cao màn hình để 20 hàng + khung vừa cửa sổ (720p -> ~26px, đúng cỡ ô VLTK gốc).
	var screen_h := get_viewport().get_visible_rect().size.y
	_room.cell = clampi(int((screen_h - 260.0) / PlayerProfile.ROOM_HEIGHT), 20, 44)
	_room.item_pressed.connect(_on_item_pressed)
	_room.changed.connect(_commit)
	## Khung cao đúng ROOM_HEIGHT hàng; món tràn ra ngoài (save cũ) nằm ở các hàng thêm, kéo cuộn xuống để thấy.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PlayerProfile.ROOM_WIDTH, PlayerProfile.ROOM_HEIGHT) * _room.cell
	scroll.add_child(_room)
	old_grid.get_parent().add_child(scroll)

	%TestRow.visible = OS.is_debug_build()
	%TestAddButton.pressed.connect(_on_test_items_pressed)
	%TestCreateButton.pressed.connect(func() -> void: ItemCreatorPopup.open(self, _profile, _commit))

	_room.setup(_profile)
	_refresh()
	## Đặt giữa màn hình (sau 1 frame để container tính xong kích thước).
	await get_tree().process_frame
	var frame: Control = %Frame
	frame.size = frame.get_combined_minimum_size()
	frame.position = (frame.get_viewport_rect().size - frame.size) * 0.5

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
	_room.bag = _bag
	_room.rebuild()
	(%GoldValue as Label).text = format_money(_profile.gold) + " lượng"
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
	var actions := [
		["Trang bị", _equip.bind(index)],
		["Vứt bỏ", _drop.bind(index)],
	]
	if PotionEffect.usable(item):
		actions[0] = ["Dùng", _use.bind(index)]
		## 4 ô thuốc nhanh trên màn chơi (QuickItemBar): gắn loại thuốc này vào 1 ô.
		for i in _profile.quick_items.size():
			actions.append(["Gắn vào ô %d" % (i + 1), _set_quick_slot.bind(item.misc_id, i)])
	if _partner_action.is_valid():
		var extra: Array = _partner_action.call(item)
		if not extra.is_empty():
			actions.push_front(extra)
	ItemDetailPopup.open(self, ItemText.build(item, _profile, -1, -1, false), actions, item)

## "Dùng" thuốc / đan: chỉ trong trận (có nhân vật trên bản đồ) — PotionEffect.consume.
func _use(index: int) -> void:
	if index >= _profile.inventory.size():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_show_message("Chỉ dùng được thuốc khi đang ở trên bản đồ.")
		return
	var item := _profile.inventory[index]
	var blocked := PotionEffect.block_reason(item)
	if blocked != "":
		_show_message(blocked)
		return
	if not PotionEffect.consume(_profile, player, item):
		return
	_show_message("Đã dùng %s" % item.get_display_name())
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
	_show_message("")
	_commit()

func _show_message(text: String) -> void:
	(%Message as Label).text = text

func _commit() -> void:
	SaveManager.save_profile(_profile)
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

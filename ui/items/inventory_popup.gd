extends CanvasLayer
class_name InventoryPopup
## Khung "Hành trang" kiểu VLTK: LƯỚI Ô 6 × 10 (ItemRoomView) — mỗi món là 1 khối chiếm số ô rộng × cao riêng, kéo thả để
## đổi chỗ; tiền ở dưới, nút "Sắp xếp" / "Bày bán". Bấm 1 món -> khung chi tiết (ItemDetailPopup) với nút Trang bị / Vứt bỏ.
## Kéo thanh tiêu đề để di chuyển khung. Bố cục/màu nằm trong InventoryPopup.tscn; script dựng lưới + đổ dữ liệu.
## Mọi thay đổi ghi vào PlayerProfile + lưu save, rồi gọi `on_changed` để màn gọi vẽ lại ô trang bị/chỉ số.

const SCENE_PATH := "res://ui/items/InventoryPopup.tscn"
var _profile: PlayerProfile
var _on_changed: Callable
var _modal: bool = true
var _room: ItemRoomView
var _bag: int = 0
var _dragging: bool = false

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
	var dim: ColorRect = %Dim
	dim.visible = _modal
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	%CloseButton.pressed.connect(queue_free)
	%TitleBar.gui_input.connect(_on_title_input)
	%SortButton.pressed.connect(_on_sort_pressed)
	%SellButton.pressed.connect(func() -> void: _show_message("Bày bán: đang phát triển"))

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
	_room.cell = clampi(int((screen_h - 190.0) / PlayerProfile.ROOM_HEIGHT), 22, 44)
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
	## Khoá món đồ (không bán/giao dịch/vứt được) — mở khoá phải chờ 3 ngày; và đặt giá để bày bán.
	SecurityLock.refresh_item(item)
	match item.lock_state:
		ItemInstance.LOCK_NORMAL:
			actions.append(["Khoá món", func() -> void: _lock_item(item)])
		ItemInstance.LOCK_LOCKED:
			actions.append(["Mở khoá (chờ 3 ngày)", func() -> void: _unlock_item(item)])
		_:
			actions.append([SecurityLock.describe_item_lock(item), func() -> void: pass])
	actions.append(["Đặt giá bán", func() -> void: _set_price(item)])
	ItemDetailPopup.open(self, ItemText.build(item, _profile, -1, -1, false), actions, item)

func _equip(index: int) -> void:
	var err := _profile.equip_from_inventory(index)
	_show_message(err)
	if err == "":
		_commit()

## "Vứt bỏ": trong trận thì món đồ RƠI XUỐNG ĐẤT ngay dưới chân nhân vật (nhấp vào để nhặt lại); ở ngoài trận (Hub, không có
## nhân vật trên bản đồ) thì không có chỗ rơi nên bỏ hẳn.
func _lock_item(item: ItemInstance) -> void:
	_show_message("Đã khoá món đồ." if SecurityLock.lock_item(item) else "Không khoá được món đồ này.")
	_commit()

func _unlock_item(item: ItemInstance) -> void:
	_show_message("Bắt đầu chờ mở khoá: còn %s." % SecurityLock.describe_item_lock(item) if SecurityLock.request_unlock(item) else "Không mở khoá được.")
	_commit()

func _set_price(item: ItemInstance) -> void:
	SocialWindow.prompt(self, "Đặt giá bán", "Giá (lượng), 0 = không bán", func(text: String) -> void:
		var price := int(text.strip_edges()) if text.strip_edges().is_valid_int() else -1
		var err := StallService.set_price(_profile, item, price)
		_show_message(err if err != "" else ("Đã đặt giá %d lượng — mở quầy ở Giao lưu để bán." % price if price > 0 else "Đã bỏ giá bán."))
		_commit(), str(item.trade_price) if item.trade_price > 0 else "")

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

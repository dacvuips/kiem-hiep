extends CanvasLayer
class_name InventoryPopup
## Khung "Hành trang" kiểu VLTK mobile: lưới 6x6 ô có ẢNH vật phẩm, cột "Túi 1..6" bên phải, tiền ở dưới, nút
## "Sắp xếp" / "Bày bán". Bấm 1 món -> khung chi tiết (ItemDetailPopup) với nút Trang bị / Vứt bỏ. Kéo thanh tiêu đề
## để di chuyển khung. Bố cục/màu nằm trong InventoryPopup.tscn; script chỉ dựng lưới ô + đổ dữ liệu.
## Mọi thay đổi ghi vào PlayerProfile + lưu save, rồi gọi `on_changed` để màn gọi vẽ lại ô trang bị/chỉ số.

const SCENE_PATH := "res://ui/items/InventoryPopup.tscn"
const SLOTS_PER_BAG := 36
const SLOT_SIZE := Vector2(54, 54)

var _profile: PlayerProfile
var _on_changed: Callable
var _modal: bool = true
var _bag: int = 0
var _slots: Array[ItemSlotButton] = []
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

	var group := ButtonGroup.new()
	var bags := %BagTabs.get_children()
	for i in bags.size():
		var tab: Button = bags[i]
		tab.button_group = group
		tab.pressed.connect(_select_bag.bind(i))

	%TestRow.visible = OS.is_debug_build()
	%TestAddButton.pressed.connect(_on_test_items_pressed)
	%TestCreateButton.pressed.connect(func() -> void: ItemCreatorPopup.open(self, _profile, _commit))

	_build_slots()
	_refresh()
	## Đặt giữa màn hình (sau 1 frame để container tính xong kích thước).
	await get_tree().process_frame
	var frame: Control = %Frame
	frame.size = frame.get_combined_minimum_size()
	frame.position = (frame.get_viewport_rect().size - frame.size) * 0.5

func _build_slots() -> void:
	var grid: GridContainer = %Grid
	for i in SLOTS_PER_BAG:
		var b := ItemSlotButton.new()
		b.small_icons = true
		b.custom_minimum_size = SLOT_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 10)
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, _slot_style(state))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(b)
		_slots.append(b)

static func _slot_style(state: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.08, 0.07) if state != "disabled" else Color(0.05, 0.045, 0.04)
	s.border_color = {"hover": Color(0.85, 0.7, 0.35), "pressed": Color(1, 0.85, 0.45)}.get(state, Color(0.26, 0.21, 0.13))
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(3)
	return s

## Số túi đang mở theo sức chứa hành trang (60 ô = Túi 1 đủ 36 + Túi 2 có 24); túi chưa mở bị khoá.
func _open_bags() -> int:
	return ceili(float(PlayerProfile.INVENTORY_CAPACITY) / SLOTS_PER_BAG)

func _select_bag(bag: int) -> void:
	_bag = bag
	_refresh()

func _refresh() -> void:
	var bags := %BagTabs.get_children()
	for i in bags.size():
		var tab: Button = bags[i]
		tab.disabled = i >= _open_bags()
		tab.tooltip_text = "Chưa mở" if tab.disabled else ""
		tab.set_pressed_no_signal(i == _bag)
	var ctx := Equipment.get_requirement_context(_profile)
	for i in SLOTS_PER_BAG:
		var index := _bag * SLOTS_PER_BAG + i
		var slot := _slots[i]
		var usable_slot := index < PlayerProfile.INVENTORY_CAPACITY
		slot.disabled = not usable_slot
		var item: ItemInstance = _profile.inventory[index] if index < _profile.inventory.size() else null
		if item:
			slot.show_item(item, ItemText.build(item, _profile), "", Equipment.can_use(item, _profile, ctx))
		else:
			slot.show_item(null, "", "" if usable_slot else "Ô chưa mở")
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

func _on_slot_pressed(slot: int) -> void:
	var index := _bag * SLOTS_PER_BAG + slot
	if index >= _profile.inventory.size():
		return
	var item := _profile.inventory[index]
	ItemDetailPopup.open(self, ItemText.build(item, _profile, -1, -1, false), [
		["Trang bị", _equip.bind(index)],
		["Vứt bỏ", _drop.bind(index)],
	], item)

func _equip(index: int) -> void:
	var err := _profile.equip_from_inventory(index)
	_show_message(err)
	if err == "":
		_commit()

func _drop(index: int) -> void:
	if index < _profile.inventory.size():
		_profile.inventory.remove_at(index)
		_show_message("")
		_commit()

## Sắp xếp: theo loại đồ (vũ khí, áo, mũ...), hoàng kim trước, cấp cao trước.
func _on_sort_pressed() -> void:
	_profile.inventory.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		if a.get_detail() != b.get_detail():
			return a.get_detail() < b.get_detail()
		if a.is_gold() != b.is_gold():
			return a.is_gold()
		return a.get_level() > b.get_level())
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

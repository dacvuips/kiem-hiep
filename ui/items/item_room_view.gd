extends Control
class_name ItemRoomView
## LƯỚI HÀNH TRANG kiểu VLTK: ROOM_WIDTH × ROOM_HEIGHT ô (PlayerProfile), mỗi món là 1 khối chiếm số ô rộng × cao riêng của nó
## (ItemInstance.get_size), ảnh vật phẩm phóng vừa khung, nền xanh (đỏ khi chưa đủ yêu cầu dùng). Bấm món -> signal
## item_pressed; KÉO món sang chỗ trống để đổi vị trí (ô đích tô xanh nếu vừa chỗ, đỏ nếu không) -> signal changed.
## Dữ liệu nằm hết ở PlayerProfile (inventory + room_x/room_y của từng món); view chỉ vẽ + chuyển thao tác.

signal item_pressed(item: ItemInstance)
signal changed

## Cỡ 1 ô (pixel) — cửa sổ hành trang đặt lại theo chiều cao màn hình trước khi setup().
var cell: int = 44
const DRAG_TYPE := "bag_item"
const CELL_BG := Color(0.05, 0.05, 0.045, 0.95)
const GRID_LINE := Color(0.3, 0.26, 0.17, 0.9)
const ITEM_BG := Color(0.04, 0.22, 0.13, 0.92)
const HOVER_OK := Color(0.2, 0.9, 0.35, 0.35)
const HOVER_BAD := Color(0.95, 0.2, 0.2, 0.35)
## Hàng nằm ngoài ROOM_HEIGHT (món từ save cũ tràn ra) — tô đỏ để biết đó là chỗ "thừa"; kéo vào ô trống hoặc vứt bớt.
const OVERFLOW_BG := Color(0.28, 0.04, 0.04, 0.9)

## Nguồn đồ: PlayerProfile (hành trang) HOẶC ItemContainer (rương, phòng giao dịch...) — cùng bộ hàm inventory / ROOM_WIDTH / ROOM_HEIGHT /
## get_room_height / can_place / move_item nên vẽ được cả hai.
var profile: Object
## Hồ sơ người chơi để tính yêu cầu dùng đồ/mô tả (khi nguồn là rương thì vẫn dùng hồ sơ của mình).
var context_profile: PlayerProfile
## Nếu đặt: kéo món TỪ NGUỒN KHÁC thả vào đây thì gọi handler(item, from_source, to_source, x, y, bag) -> bool để chuyển (rương <-> hành trang).
var transfer_handler: Callable
## false = chỉ xem (lưới đối phương trong giao dịch): không kéo/không thả, bấm vẫn phát item_pressed.
var interactive := true
## Túi đang hiển thị (0 = Túi 1).
var bag: int = 0
var _hover := Rect2i()
var _hover_ok: bool = false
var _show_hover: bool = false
var _overlay: Control   ## lớp phủ nằm trên cùng, vẽ ô đích khi kéo

func setup(p: Object, ctx_profile: PlayerProfile = null) -> void:
	profile = p
	context_profile = ctx_profile if ctx_profile != null else (p as PlayerProfile)
	rebuild()

## Dựng lại toàn bộ khối vật phẩm theo PlayerProfile.inventory.
func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if profile == null:
		return
	custom_minimum_size = Vector2(profile.ROOM_WIDTH, profile.get_room_height(bag)) * cell
	var ctx := Equipment.get_requirement_context(context_profile) if context_profile != null else {}
	for item in profile.inventory:
		if item.room_bag == bag:
			add_child(_make_widget(item, ctx))
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	queue_redraw()

func _make_widget(item: ItemInstance, ctx: Dictionary) -> ItemSlotButton:
	var cells := item.get_size()
	var b := ItemSlotButton.new()
	b.icon_max_scale = 2.0
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(item.room_x, item.room_y) * cell
	b.size = Vector2(cells) * cell
	b.custom_minimum_size = b.size
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 10)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = ITEM_BG.lightened(0.08) if state == "hover" else ITEM_BG
		style.border_color = Color(0.85, 0.7, 0.35) if state == "hover" else Color(0.1, 0.35, 0.22)
		style.set_border_width_all(1)
		style.set_content_margin_all(2)
		b.add_theme_stylebox_override(state, style)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	## Viền báo: xanh dương = món đang khoá, vàng = món đã đặt giá bán.
	if SecurityLock.is_item_locked(item) or item.trade_price > 0:
		var edge := Color(0.45, 0.65, 0.95) if SecurityLock.is_item_locked(item) else Color(0.96, 0.78, 0.25)
		for state in ["normal", "hover", "pressed", "disabled"]:
			(b.get_theme_stylebox(state) as StyleBoxFlat).border_color = edge
			(b.get_theme_stylebox(state) as StyleBoxFlat).set_border_width_all(2)
	b.show_item(item, ItemText.build(item, context_profile), "", Equipment.can_use(item, context_profile, ctx) if context_profile != null else true)
	b.pressed.connect(func() -> void: item_pressed.emit(item))
	if interactive:
		b.set_drag_forwarding(_drag_data.bind(item, b), _can_drop_forward.bind(b), _drop_forward.bind(b))
	return b

# ---------------------------------------------------------------- vẽ lưới

func _draw() -> void:
	if profile == null:
		return
	var rows: int = profile.get_room_height(bag)
	var width: int = profile.ROOM_WIDTH
	draw_rect(Rect2(Vector2.ZERO, Vector2(width, rows) * cell), CELL_BG)
	if rows > profile.ROOM_HEIGHT:
		draw_rect(Rect2(0, profile.ROOM_HEIGHT * cell, width * cell, (rows - profile.ROOM_HEIGHT) * cell), OVERFLOW_BG)
	for x in width + 1:
		draw_line(Vector2(x * cell, 0), Vector2(x * cell, rows * cell), GRID_LINE)
	for y in rows + 1:
		draw_line(Vector2(0, y * cell), Vector2(width * cell, y * cell), GRID_LINE)

## Ô đích khi đang kéo — vẽ ĐÈ lên các khối món để thấy rõ chỗ thả.
func _draw_overlay() -> void:
	if _show_hover:
		_overlay.draw_rect(Rect2(Vector2(_hover.position) * cell, Vector2(_hover.size) * cell), HOVER_OK if _hover_ok else HOVER_BAD)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_show_hover = false
		if _overlay != null:
			_overlay.queue_redraw()

# ---------------------------------------------------------------- kéo thả

func _drag_data(at_position: Vector2, item: ItemInstance, widget: Control) -> Variant:
	var preview := Control.new()
	var icon := item.get_icon(false)
	if icon != null:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size = widget.size
		tex.position = -at_position  ## con trỏ giữ nguyên chỗ đang cầm trên món
		tex.modulate.a = 0.85
		preview.add_child(tex)
	else:
		var box := ColorRect.new()
		box.color = Color(ITEM_BG, 0.85)
		box.size = widget.size
		box.position = -at_position
		preview.add_child(box)
	widget.set_drag_preview(preview)
	return {"type": DRAG_TYPE, "item": item, "source": profile, "grab": Vector2i((at_position / cell).floor())}

func _can_drop_forward(at_position: Vector2, data: Variant, widget: Control) -> bool:
	return _can_drop_data(at_position + widget.position, data)

func _drop_forward(at_position: Vector2, data: Variant, widget: Control) -> void:
	_drop_data(at_position + widget.position, data)

func _target_cell(at_position: Vector2, data: Dictionary) -> Vector2i:
	return Vector2i((at_position / cell).floor()) - Vector2i(data["grab"])

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not interactive or not (data is Dictionary and data.get("type") == DRAG_TYPE) or profile == null:
		return false
	var from_other: bool = data.get("source") != null and data.get("source") != profile
	if from_other and not transfer_handler.is_valid():
		return false
	var item: ItemInstance = data["item"]
	var at_cell := _target_cell(at_position, data)
	_hover = Rect2i(at_cell, item.get_size())
	_hover_ok = profile.can_place(item, at_cell.x, at_cell.y, bag, profile.get_room_height(bag))
	_show_hover = true
	if _overlay != null:
		_overlay.queue_redraw()
	return _hover_ok

func _drop_data(at_position: Vector2, data: Variant) -> void:
	_show_hover = false
	var item: ItemInstance = data["item"]
	var at_cell := _target_cell(at_position, data)
	var from_other: bool = data.get("source") != null and data.get("source") != profile
	if from_other:
		if transfer_handler.call(item, data["source"], profile, at_cell.x, at_cell.y, bag):
			changed.emit()
	elif profile.move_item(item, at_cell.x, at_cell.y, bag):
		changed.emit()
	if _overlay != null:
		_overlay.queue_redraw()

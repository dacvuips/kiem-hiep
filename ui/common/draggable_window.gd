extends PanelContainer
class_name DraggableWindow
## Khung cửa sổ dùng chung (Hành trang, Nhân vật...): thanh tiêu đề để KÉO DI CHUYỂN khung, nút X để
## đóng. Nội dung đặt vào `body`. Khung luôn bị giới hạn trong màn hình.
##
## Bấm vào khung nào thì khung đó nổi lên trên (đổi `layer` của CanvasLayer cha giữa WINDOW_LAYER và
## WINDOW_LAYER + 1) — vẫn nằm dưới popup chi tiết món (61) / tạo đồ (62) để popup con không bị che.

signal close_requested

const WINDOW_LAYER := 55
const GROUP := "draggable_windows"

var title: String = ""
var body: VBoxContainer
var bar: PanelContainer
var is_docked: bool = false
var _draggable_explicit: bool = true
var draggable: bool:
	get:
		if not _draggable_explicit:
			return false
		if is_docked:
			return false
		return true
	set(v):
		_draggable_explicit = v

var _dragging: bool = false
var _frameless: bool = false
## Nút X (chế độ frameless: nằm đè góc trên phải — màn gọi có thể dời offset cho khớp ảnh khung).
var close_button: Button
var _title_label: Label

## `frameless` = true: KHÔNG vẽ khung/thanh tiêu đề (nội dung tự có ảnh khung riêng, VD bảng Nhân vật) —
## kéo bằng cách nắm vào chỗ trống bất kỳ trên nội dung, nút X nhỏ nằm đè góc trên phải.
func _init(window_title: String = "", frameless: bool = false) -> void:
	title = window_title
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_PASS

	if frameless:
		_frameless = true
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		root.add_child(body)
		var overlay := Control.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)
		var corner_close := _make_close_button()
		close_button = corner_close
		corner_close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		corner_close.offset_left = -36
		corner_close.offset_top = 4
		corner_close.offset_right = -4
		corner_close.offset_bottom = 34
		overlay.add_child(corner_close)
		return

	GameUi.style(self, GameUi.WINDOW)

	## Thanh tiêu đề = vùng kéo.
	bar = GameUi.panel(GameUi.TITLE_BAR)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE if draggable else Control.CURSOR_ARROW
	bar.gui_input.connect(_on_bar_input)
	root.add_child(bar)
	var bar_row := HBoxContainer.new()
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bar_row)
	_title_label = GameUi.title(title)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(_title_label)
	close_button = _make_close_button()
	bar_row.add_child(close_button)
	root.add_child(body)

func _make_close_button() -> Button:
	var close := GameUi.close_button()
	close.pressed.connect(func() -> void: close_requested.emit())
	return close

func set_draggable(can_drag: bool) -> void:
	draggable = can_drag
	if not draggable:
		_dragging = false
		if bar:
			bar.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _is_in_character_hub() -> bool:
	if find_parent("CharacterHub") != null:
		return true
	var p := get_parent()
	while p != null:
		if p.name == "CharacterHub" or p.is_in_group("character_hub"):
			return true
		p = p.get_parent()
	if get_tree() and get_tree().current_scene != null:
		var cs := get_tree().current_scene
		if cs.name == "CharacterHub" or cs.is_in_group("character_hub"):
			return true
	return false

func _enter_tree() -> void:
	if is_docked:
		set_draggable(false)

func _ready() -> void:
	add_to_group(GROUP)
	if is_docked:
		set_draggable(false)
	## Đặt giữa màn hình (lệch theo số khung đang mở để 2 khung không chồng khít nhau).
	await get_tree().process_frame
	if not is_inside_tree() or is_docked:
		return
	## Dùng kích thước tối thiểu của nội dung — `size` có thể chưa được container cập nhật ở frame đầu.
	size = get_combined_minimum_size()
	var open_floating := 0
	for w in get_tree().get_nodes_in_group(GROUP):
		if w is DraggableWindow and is_instance_valid(w) and w.is_inside_tree() and w.visible and not w.is_docked and w != self:
			open_floating += 1
	var offset := Vector2(24, 24) * open_floating
	position = ((get_viewport_rect().size - size) * 0.5 + offset).round()
	_clamp_to_screen()
	bring_to_front()

func _gui_input(event: InputEvent) -> void:
	if not draggable:
		if event is InputEventMouseButton and event.pressed:
			bring_to_front()
		return
	if _frameless:
		## Không có thanh tiêu đề: chuột rơi xuống chỗ trống của nội dung (Label/ảnh nền) thì kéo khung.
		_on_bar_input(event)
	elif event is InputEventMouseButton and event.pressed:
		bring_to_front()

func _on_bar_input(event: InputEvent) -> void:
	if not draggable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			bring_to_front()
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
		_clamp_to_screen()

func bring_to_front() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	for w in get_tree().get_nodes_in_group(GROUP):
		var layer_node := (w as Node).get_parent() as CanvasLayer
		if layer_node:
			layer_node.layer = WINDOW_LAYER
	var own := get_parent() as CanvasLayer
	if own:
		own.layer = WINDOW_LAYER + 1

func _clamp_to_screen() -> void:
	var screen := get_viewport_rect().size
	if size.x >= screen.x:
		position.x = 0.0
	else:
		position.x = clampf(position.x, 0.0, screen.x - size.x)
	if size.y >= screen.y:
		position.y = 0.0
	else:
		position.y = clampf(position.y, 0.0, screen.y - size.y)

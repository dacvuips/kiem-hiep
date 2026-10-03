extends PanelContainer
class_name DraggableWindow
## Khung cửa sổ dùng chung (Hành trang, Nhân vật...): thanh tiêu đề để KÉO DI CHUYỂN khung, nút X để
## đóng. Nội dung đặt vào `body`. Khung luôn bị giới hạn trong màn hình.
##
## Bấm vào khung nào thì khung đó nổi lên trên (đổi `layer` của CanvasLayer cha giữa WINDOW_LAYER và
## WINDOW_LAYER + 1) — vẫn nằm dưới popup chi tiết món (61) / tạo đồ (62) để popup con không bị che.

signal close_requested

const GOLD := Color(0.83, 0.68, 0.21)
const WINDOW_LAYER := 55
const GROUP := "draggable_windows"

var title: String = ""
var body: VBoxContainer

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

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.06, 1.0)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	## Thanh tiêu đề = vùng kéo.
	var bar := PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.16, 0.13, 0.06, 1.0)
	bar_style.set_corner_radius_all(4)
	bar_style.set_content_margin_all(4)
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(_on_bar_input)
	root.add_child(bar)
	var bar_row := HBoxContainer.new()
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bar_row)
	_title_label = Label.new()
	_title_label.text = title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", GOLD)
	bar_row.add_child(_title_label)
	var close := _make_close_button()
	close.custom_minimum_size = Vector2(32, 0)
	bar_row.add_child(close)
	root.add_child(body)

func _make_close_button() -> Button:
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: close_requested.emit())
	return close

func _ready() -> void:
	add_to_group(GROUP)
	## Đặt giữa màn hình (lệch theo số khung đang mở để 2 khung không chồng khít nhau).
	await get_tree().process_frame
	if not is_inside_tree():
		return
	## Dùng kích thước tối thiểu của nội dung — `size` có thể chưa được container cập nhật ở frame đầu.
	size = get_combined_minimum_size()
	var offset := Vector2(28, 28) * (get_tree().get_nodes_in_group(GROUP).size() - 1)
	position = (get_viewport_rect().size - size) * 0.5 + offset
	_clamp_to_screen()
	bring_to_front()

func _gui_input(event: InputEvent) -> void:
	if _frameless:
		## Không có thanh tiêu đề: chuột rơi xuống chỗ trống của nội dung (Label/ảnh nền) thì kéo khung.
		_on_bar_input(event)
	elif event is InputEventMouseButton and event.pressed:
		bring_to_front()

func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			bring_to_front()
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
		_clamp_to_screen()

func bring_to_front() -> void:
	for w in get_tree().get_nodes_in_group(GROUP):
		var layer_node := (w as Node).get_parent() as CanvasLayer
		if layer_node:
			layer_node.layer = WINDOW_LAYER
	var own := get_parent() as CanvasLayer
	if own:
		own.layer = WINDOW_LAYER + 1

func _clamp_to_screen() -> void:
	var screen := get_viewport_rect().size
	position = position.clamp(Vector2.ZERO, (screen - size).max(Vector2.ZERO))

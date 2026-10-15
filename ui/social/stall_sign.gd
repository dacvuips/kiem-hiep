extends PanelContainer
class_name StallSign
## Biển TÊN QUẦY trên đầu người đang bày bán (Player của mình + RemotePlayer). Bấm vào biển = phát `clicked` (người khác: mở quầy xem hàng,
## của mình: mở bảng Bày bán). Bấm trúng biển thì giao diện ăn cú bấm, nhân vật không chạy tới chỗ bấm. Ẩn khi tên quầy rỗng.

signal clicked

const WIDTH := 170.0

var _label: Label

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", SocialUi.box(Color(0.10, 0.07, 0.03, 0.88), SocialUi.GOLD.darkened(0.25), 4, 1, 3))
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", SocialUi.GOLD)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit())

## Đặt biển ngay trên dòng tên (y = toạ độ đỉnh dòng tên, gốc = node nhân vật).
func place_above(name_top_y: float) -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	reset_size()
	position = Vector2(-WIDTH * 0.5, name_top_y - size.y - 2.0)

var title := ""

func set_title(new_title: String) -> void:
	visible = new_title != ""
	if new_title == title:
		return
	title = new_title
	_label.text = "🏷 " + title if title != "" else ""
	tooltip_text = title

extends Node2D
class_name NamePlate
## Bảng tên trên đầu quái / NPC (như VLTK gốc): chấm tròn MÀU HỆ NGŨ HÀNH + tên, nằm ngay trên thanh máu.
## Màu chấm = ElementTypes.ELEMENT_COLOR (cùng màu hệ dùng ở mọi nơi khác trong game). Gốc node = giữa, ngay trên thanh máu
## (đặt bằng place_above()). Chỉ vẽ lại khi đổi tên/hệ -> rẻ cho mobile.

const FONT_SIZE := 13
const ORB_RADIUS := 6.0
const GAP := 5.0
const NAME_COLOR := Color(0.96, 0.95, 0.88)
const BOSS_NAME_COLOR := Color(0.45, 0.72, 1.0)   ## boss xanh: tên màu xanh dương
const OUTLINE_SIZE := 3

var _text := ""
var _color := Color.WHITE
var _name_color := NAME_COLOR

func setup(display_name: String, element: ElementTypes.ElementType, boss: bool = false) -> void:
	_text = display_name
	_name_color = BOSS_NAME_COLOR if boss else NAME_COLOR
	_color = ElementTypes.ELEMENT_COLOR.get(element, Color.WHITE)
	z_index = 5
	queue_redraw()

## Đặt ngay trên thanh máu `bar` (HealthBar: thanh cao từ y-13 đến y-7 quanh gốc của nó).
func place_above(bar: Node2D) -> void:
	position = bar.position + Vector2(0, -17.0)

func _draw() -> void:
	if _text == "":
		return
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var total := ORB_RADIUS * 2.0 + GAP + text_size.x
	var left := -total * 0.5
	var orb_center := Vector2(left + ORB_RADIUS, -text_size.y * 0.5 + 1.0)
	## Chấm tròn: viền tối + màu hệ + đốm sáng nhỏ cho có khối.
	draw_circle(orb_center, ORB_RADIUS + 1.2, Color(0, 0, 0, 0.85))
	draw_circle(orb_center, ORB_RADIUS, _color.lightened(0.15))
	draw_arc(orb_center, ORB_RADIUS - 0.8, 0.0, TAU, 20, _color.darkened(0.25), 1.6)
	draw_circle(orb_center + Vector2(-1.6, -1.8), ORB_RADIUS * 0.35, Color(1, 1, 1, 0.55))
	var pos := Vector2(left + ORB_RADIUS * 2.0 + GAP, 0.0)
	draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, Color(0, 0, 0, 0.9))
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _name_color)

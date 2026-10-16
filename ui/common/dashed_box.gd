extends PanelContainer
class_name DashedBox
## Khung có VIỀN NÉT ĐỨT (StyleBox của Godot không có viền đứt — vẽ bằng draw_dashed_line). Nội dung là con của khung như PanelContainer.
## Dùng cho phần ghi chú phụ (VD "Nội dung rao" của món treo ở Chợ Giao Thương trong khung xem chi tiết).

var color := Color(0.75, 0.62, 0.35, 0.85)
var dash := 6.0
var width := 1.0
var padding := 10.0

static func create(child: Control, border_color := Color(0.75, 0.62, 0.35, 0.85)) -> DashedBox:
	var b := DashedBox.new()
	b.color = border_color
	b.add_child(child)
	return b

func _ready() -> void:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding * 0.8
	s.content_margin_bottom = padding * 0.8
	add_theme_stylebox_override("panel", s)
	resized.connect(queue_redraw)

func _draw() -> void:
	var r := Rect2(Vector2.ONE * width * 0.5, size - Vector2.ONE * width)
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	for seg in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
		draw_dashed_line(seg[0], seg[1], color, width, dash)

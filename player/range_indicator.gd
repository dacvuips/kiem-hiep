extends Node2D

@export var color: Color = Color(1, 1, 1, 0.25)
var radius: float = 150.0

func set_radius(value: float) -> void:
	if is_equal_approx(radius, value):
		return  ## được gọi mỗi frame — chỉ vẽ lại khi tầm đổi
	radius = value
	queue_redraw()

## Tầm đánh tính theo logic VLTK (dọc nhân đôi) -> trên màn hình là elip: ngang = radius, dọc = radius / 2.
## Tâm đặt ở chân nhân vật (avatar lệch xuống so với gốc node).
const FEET_OFFSET := Vector2(0, 30)

func _draw() -> void:
	var points := PackedVector2Array()
	for i in 65:
		var a := TAU * i / 64.0
		points.append(FEET_OFFSET + Vector2(cos(a) * radius, sin(a) * radius * 0.5))
	draw_polyline(points, color, 1.5, true)

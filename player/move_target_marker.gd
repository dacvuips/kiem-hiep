extends Node2D
class_name MoveTargetMarker
## Dấu điểm đến khi bấm bản đồ để chạy tới: vòng elip nhấp nháy co giãn nhẹ dưới đất.

const COLOR := Color(1.0, 0.9, 0.35)
var _t: float = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_t = fmod(_t + delta * 2.5, TAU)
	queue_redraw()

func _draw() -> void:
	var r := 10.0 + 2.5 * sin(_t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))  ## elip = vòng tròn nằm trên mặt đất xéo
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(COLOR, 0.9), 2.0)
	draw_arc(Vector2.ZERO, r * 0.45, 0.0, TAU, 16, Color(COLOR, 0.5), 1.5)

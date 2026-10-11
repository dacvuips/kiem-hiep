extends Node2D
class_name TargetRing
## VÒNG ĐỎ XOAY dưới chân mục tiêu đang được người chơi chọn đánh (bấm vào quái / người chơi khác).
## Gốc của chủ (quái, người) nằm ở CHÂN nên vòng vẽ ngay tại gốc; nằm dưới thân (z -1) nhưng trên nền map.

const RADIUS := Vector2(30.0, 11.0)   ## elip (góc nhìn xéo)
const ARCS := 3
const SPIN_SPEED := 2.4               ## radian/giây
const COLOR_RING := Color(1.0, 0.15, 0.1, 0.45)
const COLOR_ARC := Color(1.0, 0.2, 0.12, 0.95)

var _angle := 0.0

func _ready() -> void:
	z_index = -1

func _process(delta: float) -> void:
	_angle = fmod(_angle + SPIN_SPEED * delta, TAU)
	queue_redraw()

func _ellipse(a0: float, a1: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / float(steps))
		pts.append(Vector2(cos(a) * RADIUS.x, sin(a) * RADIUS.y))
	return pts

func _draw() -> void:
	draw_polyline(_ellipse(0.0, TAU, 40), COLOR_RING, 1.5)
	var span := TAU / float(ARCS) * 0.55
	for i in ARCS:
		var start := _angle + TAU * float(i) / float(ARCS)
		draw_polyline(_ellipse(start, start + span, 12), COLOR_ARC, 3.0)

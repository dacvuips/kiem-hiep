extends Node2D
class_name StunRing
## Vòng tròn quay trên đầu mục tiêu đang bị CHOÁNG (stun_p / Lôi sát) — người/quái/NPC đứng yên tại chỗ trong lúc choáng.
## Tự tạo/xoá bởi StatusEffectController; độ cao lấy theo thanh máu của chủ nếu có (giống StateVisuals).

const RADIUS := Vector2(20.0, 7.0)   ## elip (góc nhìn xéo)
const DOTS := 6
const SPIN_SPEED := 3.2              ## vòng/giây * 2π /… (radian/giây)
const COLOR_DOT := Color(1.0, 0.92, 0.3)
const COLOR_RING := Color(1.0, 0.85, 0.2, 0.55)
const DEFAULT_HEAD_OFFSET := -64.0

var _angle := 0.0

func _ready() -> void:
	z_index = 20
	position = Vector2(0.0, _head_offset())

func _process(delta: float) -> void:
	_angle = fmod(_angle + SPIN_SPEED * delta, TAU)
	queue_redraw()

func _head_offset() -> float:
	var owner_node := get_parent()
	var bar: Node = owner_node.get_node_or_null("HealthBar") if owner_node else null
	if bar is Node2D or bar is Control:
		return bar.position.y - 12.0
	return DEFAULT_HEAD_OFFSET

func _draw() -> void:
	## Vòng elip mờ + các chấm sáng chạy quanh (chấm phía sau mờ hơn để có chiều sâu).
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a) * RADIUS.x, sin(a) * RADIUS.y))
	draw_polyline(pts, COLOR_RING, 2.0)
	for i in DOTS:
		var a := _angle + TAU * float(i) / float(DOTS)
		var p := Vector2(cos(a) * RADIUS.x, sin(a) * RADIUS.y)
		var depth := 0.55 + 0.45 * (sin(a) * 0.5 + 0.5)   ## sin > 0 = phía trước
		draw_circle(p, 3.2, Color(0, 0, 0, 0.5 * depth))
		draw_circle(p, 2.4, Color(COLOR_DOT, depth))

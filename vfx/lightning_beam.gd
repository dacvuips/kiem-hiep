extends Node2D
class_name LightningBeam
## VFX generic: vẽ 1 tia sáng nối 2 điểm world-space rồi tự fade và release qua ObjectPool.
## Dùng chung cho MỌI hiệu ứng "tia nối" (không chỉ sét) — chỉ cần đổi màu/texture của Line2D
## khi setup() để tái dùng cho hiệu ứng khác (dây xích, tia hút máu...).

const LIFETIME := 0.18

@onready var _line: Line2D = $Line2D

var _time_left: float = 0.0

## from/to là world-space position — Line2D vẽ theo local nên phải trừ đi global_position
## của chính node này (đặt tại from lúc spawn).
func setup(from: Vector2, to: Vector2, color: Color = Color(0.6, 0.85, 1.0, 1.0)) -> void:
	global_position = from
	_line.clear_points()
	_line.add_point(Vector2.ZERO)
	_line.add_point(to - from)
	_line.default_color = color
	_line.modulate.a = 1.0
	_time_left = LIFETIME

func _on_pool_acquire() -> void:
	_time_left = LIFETIME

func _process(delta: float) -> void:
	_time_left -= delta
	_line.modulate.a = clamp(_time_left / LIFETIME, 0.0, 1.0)
	if _time_left <= 0.0:
		ObjectPool.release(self)

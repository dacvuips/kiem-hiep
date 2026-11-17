extends Node2D
class_name ArenaBorder
## Đường viền / hào quang sáng ở rìa ô vuông giới hạn màn chơi PUBG

var _size: Vector2 = Vector2.ZERO
var _color: Color = Color(1.0, 0.85, 0.3, 0.9)

func setup(p_size: Vector2, p_color: Color) -> void:
	for c in get_children():
		c.queue_free()
	_size = p_size
	_color = p_color
	var is_pubg: bool = GameManager != null and (GameManager.field_map.get("pubg", false) or GameManager.field_map.get("is_pubg", false))
	if is_pubg:
		visible = true
		queue_redraw()
	else:
		visible = false

func _draw() -> void:
	if not visible or _size == Vector2.ZERO:
		return
	var half := _size * 0.5
	var rect := Rect2(-half, _size)
	# Vẽ đường viền sáng phát quang giới hạn vùng chơi (140x80 region)
	draw_rect(rect, Color(_color.r, _color.g, _color.b, 0.25), false, 12.0)
	draw_rect(rect, Color(_color.r, _color.g, _color.b, 0.6), false, 6.0)
	draw_rect(rect, Color(1.0, 1.0, 0.8, 0.95), false, 2.0)



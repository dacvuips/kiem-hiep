extends Node2D
class_name ArenaBorder
## Hào quang sáng ở rìa ô vuông màn chơi (xem arena_border.gdshader). Gốc node = TÂM ô vuông; vẽ bằng 1 ColorRect + shader,
## không có node/sprite nào khác -> rẻ cho mobile.

const SHADER := preload("res://world/arena_border.gdshader")
const GLOW_WIDTH := 150.0

func setup(size: Vector2, color: Color) -> void:
	for c in get_children():
		c.queue_free()
	var rect := ColorRect.new()
	var full := size + Vector2.ONE * GLOW_WIDTH * 2.0
	rect.size = full
	rect.position = -full * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("half_size", size * 0.5)
	mat.set_shader_parameter("rect_size", full)
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow_width", GLOW_WIDTH)
	rect.material = mat
	add_child(rect)
	z_index = 20

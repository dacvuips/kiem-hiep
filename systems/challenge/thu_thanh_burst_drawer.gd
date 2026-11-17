extends Node2D

var ring_radius: float = 75.0
var ring_color: Color = Color(1.0, 0.8, 0.2, 0.8)

func _draw() -> void:
	# Vòng tròn sóng xung kích nổ ngoài
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, ring_color, 4.0)
	# Hào quang nổ ở tâm
	draw_circle(Vector2.ZERO, ring_radius * 0.45, Color(ring_color.r, ring_color.g, ring_color.b, 0.35))

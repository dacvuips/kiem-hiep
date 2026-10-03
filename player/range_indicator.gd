extends Node2D

@export var color: Color = Color(1, 1, 1, 0.25)
var radius: float = 150.0

func set_radius(value: float) -> void:
	radius = value
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, 1.5)

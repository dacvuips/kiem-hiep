extends Node2D
## Demo player: a coloured dot with a Camera2D that follows it.
## Replace this with your real character. Keep its origin at the character's FEET:
## the node position is the line used to depth-sort it against houses and trees.

func _ready() -> void:
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true       # the camera glides after the player instead of jumping with every step
	cam.position_smoothing_speed = 8.0
	add_child(cam)


func _draw() -> void:
	draw_circle(Vector2(0, -10), 9.0, Color(0.3, 0.9, 0.5))
	draw_circle(Vector2.ZERO, 3.0, Color.BLACK)

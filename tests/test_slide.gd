
extends Node
func _ready():
    var b = CharacterBody2D.new()
    add_child(b)
    b.velocity = Vector2(100, 100)
    print('Before:', b.position)
    b.move_and_slide()
    print('After move_and_slide (dt default):', b.position)
    get_tree().quit(0)

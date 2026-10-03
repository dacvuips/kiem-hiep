extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	sprite.animation_finished.connect(func(): ObjectPool.release(self))

func _on_pool_acquire() -> void:
	sprite.play("explode")

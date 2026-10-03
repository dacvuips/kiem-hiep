extends Node2D
class_name CustomImpactVisual
## VFX generic dùng chung cho MỌI hiệu ứng va chạm có SpriteFrames tùy biến (sprite sheet
## AI-gen riêng cho 1 combo Fusion) — khác HitExplosion (animation cố định, hard-code trong
## scene). setup() đổi animation runtime rồi tự release khi chạy xong, không cần 1 scene .tscn
## riêng cho mỗi combo mới.

@onready var _sprite: AnimatedSprite2D = $Sprite

func setup(frames: SpriteFrames, world_position: Vector2, animation_name: String = "default") -> void:
	global_position = world_position
	_sprite.sprite_frames = frames
	_sprite.play(animation_name)

func _on_pool_acquire() -> void:
	if not _sprite.animation_finished.is_connected(_on_finished):
		_sprite.animation_finished.connect(_on_finished)

func _on_finished() -> void:
	ObjectPool.release(self)

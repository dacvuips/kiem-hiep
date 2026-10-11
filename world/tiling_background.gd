extends Node2D
## Nền lát gạch VÔ HẠN: 1 Sprite2D lặp ảnh nền (texture_repeat) phủ đúng vùng camera đang nhìn thấy — tính cả zoom camera
## (khung màn hình / zoom) — và dời theo camera theo BỘI SỐ cỡ ô, nên hoa văn đứng yên trong thế giới, không trượt/giật.
## Thay cho ParallaxBackground cũ (chỉ lặp theo kích thước màn hình gốc nên zoom ra là hết nền).

@export var texture: Texture2D
## Phần dư thêm ra mỗi phía (số ô) để không lộ mép khi camera dịch giữa 2 lần cập nhật.
@export var margin_tiles: int = 2

var _sprite: Sprite2D

func _ready() -> void:
	z_index = -100
	z_as_relative = false
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_sprite)
	_update_region()

func _process(_delta: float) -> void:
	_update_region()

func _update_region() -> void:
	if texture == null:
		return
	var tile := Vector2(texture.get_size())
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera else Vector2.ZERO
	var zoom := camera.zoom if camera else Vector2.ONE
	var visible_size := get_viewport().get_visible_rect().size / zoom
	var tiles := ((visible_size / tile).ceil() + Vector2.ONE * float(margin_tiles * 2))
	var region_size := tiles * tile
	if _sprite.region_rect.size != region_size:
		_sprite.region_rect = Rect2(Vector2.ZERO, region_size)
	_sprite.global_position = ((center - region_size * 0.5) / tile).floor() * tile

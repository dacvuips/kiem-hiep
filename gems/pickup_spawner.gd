extends Node

const PickupScene := preload("res://gems/Pickup.tscn")

## Danh sách vật phẩm có thể tự spawn ngẫu nhiên trên map (không liên quan tới quái chết)
@export var pickups: Array[PickupData] = []

## Khoảng thời gian giữa 2 lần spawn ngẫu nhiên (giây)
@export var spawn_interval: float = 15.0

## Khoảng cách spawn tính từ viền camera/viewport
@export var spawn_margin: float = 50.0

var time_since_last_spawn: float = 0.0

func _process(delta: float) -> void:
	if pickups.is_empty():
		return

	time_since_last_spawn += delta
	if time_since_last_spawn >= spawn_interval:
		time_since_last_spawn = 0.0
		spawn_random_pickup()

func spawn_random_pickup() -> void:
	var data: PickupData = pickups[randi() % pickups.size()]
	var pickup := PickupScene.instantiate()
	get_parent().add_child(pickup)
	pickup.global_position = get_random_position_on_screen()
	pickup.setup(data)

func get_random_position_on_screen() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := camera.global_position if camera else Vector2.ZERO

	var half_width := viewport_size.x / 2.0 - spawn_margin
	var half_height := viewport_size.y / 2.0 - spawn_margin

	return center + Vector2(randf_range(-half_width, half_width), randf_range(-half_height, half_height))

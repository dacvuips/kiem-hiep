extends Node2D

## Danh sách scene vật cản có thể spawn ngẫu nhiên (cây, đá, gốc cây...)
@export var obstacle_scenes: Array[PackedScene] = []

## Kích thước mỗi ô lưới (chunk), tính bằng pixel
@export var chunk_size: float = 500.0

## Số vật cản trung bình mỗi chunk
@export var obstacles_per_chunk: int = 3

## Bán kính (tính theo số chunk) quanh player luôn được lấp đầy vật cản
@export var load_radius: int = 2

## Bán kính (tính theo số chunk) mà quá xa sẽ bị dọn dẹp
@export var unload_radius: int = 4

var player: Node2D
var loaded_chunks: Dictionary = {}  # Vector2i chunk_coord -> Array[Node]
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	rng.randomize()

func _process(_delta: float) -> void:
	if player == null or obstacle_scenes.is_empty():
		return

	var player_chunk := get_chunk_coord(player.global_position)
	load_chunks_around(player_chunk)
	unload_far_chunks(player_chunk)

func get_chunk_coord(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / chunk_size), floori(world_position.y / chunk_size))

func load_chunks_around(center: Vector2i) -> void:
	for x in range(center.x - load_radius, center.x + load_radius + 1):
		for y in range(center.y - load_radius, center.y + load_radius + 1):
			var coord := Vector2i(x, y)
			if not loaded_chunks.has(coord):
				spawn_chunk(coord)

func spawn_chunk(coord: Vector2i) -> void:
	## Seed cố định theo tọa độ chunk — đảm bảo cùng 1 chunk luôn sinh ra cùng
	## bố cục vật cản mỗi lần quay lại, thay vì random khác nhau mỗi lần load.
	rng.seed = hash(coord)

	var obstacles: Array[Node] = []
	var chunk_origin := Vector2(coord.x * chunk_size, coord.y * chunk_size)

	for i in range(obstacles_per_chunk):
		var scene: PackedScene = obstacle_scenes[rng.randi() % obstacle_scenes.size()]
		var obstacle := scene.instantiate()
		get_parent().add_child(obstacle)
		obstacle.global_position = chunk_origin + Vector2(rng.randf_range(0, chunk_size), rng.randf_range(0, chunk_size))
		obstacles.append(obstacle)

	loaded_chunks[coord] = obstacles

func unload_far_chunks(center: Vector2i) -> void:
	var to_remove: Array[Vector2i] = []
	for coord: Vector2i in loaded_chunks.keys():
		var distance: int = max(abs(coord.x - center.x), abs(coord.y - center.y))
		if distance > unload_radius:
			to_remove.append(coord)

	for coord in to_remove:
		for obstacle: Node in loaded_chunks[coord]:
			obstacle.queue_free()
		loaded_chunks.erase(coord)

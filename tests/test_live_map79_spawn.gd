extends Node

func _ready() -> void:
	print("==================================================")
	print(">>> BẮT ĐẦU TEST TOÀN DIỆN VLTKWORLD VỚI MAP 79")
	print("==================================================")

	# 1. Setup GameManager
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = MapCatalog.get_by_id(79)
	print("Field map: ", GameManager.field_map.get("name"))
	print("Field map arena_center: ", GameManager.field_map.get("arena_center"))
	print("Field map start: ", GameManager.field_map.get("start"))

	# 2. Tạo Node Root
	var root := Node2D.new()
	add_child(root)

	# 3. Tạo Player
	var player_scene: PackedScene = load("res://player/player.tscn")
	var player: Node2D = null
	if player_scene != null:
		player = player_scene.instantiate()
		player.name = "Player"
		player.add_to_group("player")
		root.add_child(player)
	else:
		player = Node2D.new()
		player.name = "Player"
		player.add_to_group("player")
		root.add_child(player)
	player.global_position = Vector2(1000, 1000) # Vị trí cũ ngẫu nhiên

	# 4. Tạo VltkWorld
	var world := VltkWorld.new()
	world.name = "World"
	world.map_dir = "res://world/maps/map_79"
	root.add_child(world)

	# 5. Gọi setup_main_map
	world.setup_main_map()

	print("\n--- KẾT QUẢ SAU SETUP_MAIN_MAP ---")
	print("Player global_position = ", player.global_position)
	var feet_pos := player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
	print("Player feet_pos = ", feet_pos)
	var coord_x := int(floori(feet_pos.x / 256.0))
	var coord_y := int(floori(feet_pos.y / 256.0))
	print("Tọa độ MiniMap = %d/%d" % [coord_x, coord_y])

	# 6. Kiểm tra bị chặn
	var feet_blocked := world._blocked_at(feet_pos)
	print("world._blocked_at(feet_pos) = ", feet_blocked)

	var map_blocked := world.map.is_blocked(feet_pos)
	print("world.map.is_blocked(feet_pos) = ", map_blocked)

	# 7. Kiểm tra tìm đường từ player feet
	var dest_pos := feet_pos + Vector2(64, 0)
	var path: PackedVector2Array = world.map.find_path(feet_pos, dest_pos)
	print("Path length từ feet_pos sang feet_pos + (64, 0): ", path.size())

	# 8. Thử 8 hướng
	var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	var walkable_dirs := 0
	for d: Vector2 in dirs:
		var target: Vector2 = feet_pos + d * 50.0
		if not world._blocked_at(target):
			walkable_dirs += 1
	print("Số hướng đi được (50px): %d/8" % walkable_dirs)

	# 9. Kiểm tra xem có nằm trong vùng hiển thị của map không
	var rx := int(floori(feet_pos.x / 512.0))
	var ry := int(floori(feet_pos.y / 512.0))
	print("Region chứa player: (%d, %d)" % [rx, ry])
	var reg_doc = world.map.region_doc(rx, ry)
	print("Region doc exists: ", reg_doc != null and not reg_doc.is_empty())

	if walkable_dirs == 0 or feet_blocked:
		push_error("NGƯỜI CHƠI BỊ KẸT!")
		get_tree().quit(1)
	else:
		print("NGƯỜI CHƠI HOÀN TOÀN TỰ DO DI CHUYỂN!")
		get_tree().quit(0)

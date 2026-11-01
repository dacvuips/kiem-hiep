extends Node

func _ready() -> void:
	var grid := MapGrid.load_from("res://world/maps/map_2")
	if grid == null:
		print("MapGrid LOAD FAILED!")
		get_tree().quit(1)
		return
	print("MapGrid loaded successfully!")
	print("Origin: ", grid.origin, " Cols: ", grid.cols, " Rows: ", grid.rows)
	print("Regions count in grid: ", grid._regions.size())

	var test_pts = [
		Vector2(76780, 57980), # West cliff
		Vector2(77000, 58100), # Bridge West entrance
		Vector2(77207, 58202), # Mid bridge 1
		Vector2(77350, 58290), # Mid bridge 2
		Vector2(77450, 58345), # Mid bridge 3
		Vector2(77500, 58375), # Bridge slope
		Vector2(77631, 58416)  # East grass
	]

	var all_pass := true
	for p in test_pts:
		var in_b = grid.in_bounds(p)
		var bl = grid.is_blocked(p)
		var cell: Vector2i = grid.world_to_cell(p)
		var val = grid._value(cell)
		print("Pos %s (cell %s) -> in_bounds: %s, is_blocked: %s, val: 0x%02x" % [str(p), str(cell), str(in_b), str(bl), val])
		if not in_b or bl:
			all_pass = false

	print("SERVER MAPGRID CHECK RESULT: ", "ALL PASS" if all_pass else "STILL BLOCKED ON SERVER!")
	get_tree().quit(0 if all_pass else 1)

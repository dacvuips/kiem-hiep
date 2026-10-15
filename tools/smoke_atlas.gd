extends Node
## Kiểm tra nhanh (tạm): dựng SortedMap trên map chính dạng atlas, đứng giữa khu chơi vài khung hình rồi in số vùng/node đã dựng.

func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var player := Node2D.new()
	add_child(player)
	var cam := Camera2D.new()
	player.add_child(cam)
	var map := VltkWorld.SortedMap.new()
	map.map_dir = OS.get_environment("SMOKE_MAP") if OS.get_environment("SMOKE_MAP") != "" else "res://world/maps/map_321"
	map.focus = player
	map.bake_ground = OS.get_environment("SMOKE_BAKE") != "0"
	add_child(map)
	await get_tree().process_frame
	print("ground_mode=", map.ground_mode, " regions=", map.data["regions"].size(), " atlas pages=", map._atlas_tex.size(), " items=", map._atlas_items.size())
	var rect: Array = map.data["rect"]
	var center := Vector2((float(rect[0]) + float(rect[2]) + 1.0) * 256.0, (float(rect[1]) + float(rect[3]) + 1.0) * 256.0)
	player.global_position = center
	map.warm_up(center, 2)
	for i in 60:
		await get_tree().process_frame
	var layers := 0
	var covers := map._g_covers.get_child_count()
	for n in map._g_base.get_children():
		layers += 1
	var ok := layers > 0
	var sorted_ok := true
	var last := -INF
	for c in map._g_covers.get_children():
		var k := float(c.get_meta("k"))
		if k < last:
			sorted_ok = false
		last = k
	print("loaded regions=", map._tiles.size(), " ground layers=", layers, " covers=", covers, " covers sorted=", sorted_ok, " objects regions=", map._objects.size())
	for i in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://smoke_atlas.png")
		print("screenshot ", ProjectSettings.globalize_path("user://smoke_atlas.png"))
	var worst := 0.0
	var total := 0.0
	var frames := 300
	var t_prev := Time.get_ticks_usec()
	for i in frames:
		player.global_position += Vector2(14, 5)        # walk across the map: regions load / unload on the way
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		var dt := float(t - t_prev) / 1000.0
		t_prev = t
		worst = maxf(worst, dt)
		total += dt
	print("walk: avg frame ", snappedf(total / frames, 0.01), " ms, worst ", snappedf(worst, 0.1), " ms, draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), ", objects ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " nodes, vram ", snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1), " MB, tex mem ", snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1), " MB")
	var t0 := Time.get_ticks_usec()
	for i in 200:
		await get_tree().process_frame
	print("steady: avg frame ", snappedf(float(Time.get_ticks_usec() - t0) / 200000.0, 0.01), " ms (200 frames standing still)")
	print("RESULT ", "OK" if ok and sorted_ok else "FAIL")
	get_tree().quit()

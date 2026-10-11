extends Node
## Kiểm tra nhanh (tạm): VltkMap tải map qua mạng (base_url) vào user://vltk_cache, rồi lần chạy sau dùng lại bản đã lưu.
## SMOKE_URL=http://127.0.0.1:8000/map_xxxx/  godot --path . res://tools/smoke_remote.tscn

func _ready() -> void:
	await get_tree().process_frame
	var player := Node2D.new()
	add_child(player)
	player.add_child(Camera2D.new())
	var map := VltkMap.new()
	map.base_url = OS.get_environment("SMOKE_URL")
	map.cache_root = "user://smoke_cache"
	map.focus = player
	add_child(map)
	var t0 := Time.get_ticks_msec()
	while map.data.is_empty() and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	if map.data.is_empty():
		print("RESULT FAIL map.json not loaded")
		get_tree().quit()
		return
	var rect: Array = map.data["rect"]
	player.global_position = Vector2((float(rect[0]) + float(rect[2]) + 1.0) * 256.0, (float(rect[1]) + float(rect[3]) + 1.0) * 256.0)
	var downloads_before := map._local_manifest.size()
	t0 = Time.get_ticks_msec()
	var last := 0
	while map._tiles.size() < 20 and Time.get_ticks_msec() - t0 < 40000:
		await get_tree().process_frame
		if Time.get_ticks_msec() - last > 2000:
			last = Time.get_ticks_msec()
			print("  t=", last - t0, "ms files=", map._local_manifest.size(), " regions=", map._tiles.size(), " loading=", map._loading.size(), " queue=", map._queue.size(), " active=", map._active)
	print("9+ regions after ", Time.get_ticks_msec() - t0, " ms, files=", map._local_manifest.size())
	for i in 30:
		await get_tree().process_frame
	print("ground_mode=", map.ground_mode, " offline=", map._offline, " regions shown=", map._tiles.size(), " files in local manifest=", map._local_manifest.size(),
		" (before moving: ", downloads_before, ") active downloads=", map._active, " covers=", map._g_covers.get_child_count())
	print("debug: loading=", map._loading.size(), " queue=", map._queue.size(), " queued=", map._queued.size(), " active=", map._active, " want=", map._want.size(), " queued sample=", map._queued.keys().slice(0, 4))
	var shown := 0
	for k in map._want.keys():
		var v: Vector2i = map._want[k]
		var info := map._region_info(v.x, v.y)
		var jr := "regions/%d_%d.json" % [v.x, v.y]
		if shown < 8:
			print("  want ", k, " info=", info, " tiles=", map._tiles.has(k), " objects=", map._objects.has(k), " json_on_disk=", FileAccess.file_exists(map._local_path(jr)), " valid=", map._valid(jr), " manifest=", map._manifest.has(jr))
			shown += 1
	print("RESULT ", "OK" if map._tiles.size() >= 9 else "FAIL")
	get_tree().quit()

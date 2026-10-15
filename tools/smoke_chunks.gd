extends Node
## Kiểm tra nhanh (tạm): map chia khối (map.json "format": "chunks") và map 1-file-1-vùng kiểu cũ, cùng một VltkMap.gd.
## SMOKE_MAP = thư mục map (res://...). In số vùng đã dựng, vật cản client == server (MapGrid), tìm đường, thời gian khung hình khi đi.

## SortedMap đo thời gian các bước của map chia khối (để tìm khung hình bị giật).
class TimedMap extends VltkWorld.SortedMap:
	var slow: Array = []
	func _update_nav(c: Vector2i) -> void:
		var t := Time.get_ticks_usec()
		super._update_nav(c)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		if ms > 20.0:
			slow.append("nav %.0f" % ms)
	func _drop_far_chunks(c: Vector2i) -> void:
		var t := Time.get_ticks_usec()
		super._drop_far_chunks(c)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		if ms > 20.0:
			slow.append("drop %.0f" % ms)
	func _collect_chunks() -> void:
		var t := Time.get_ticks_usec()
		super._collect_chunks()
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		if ms > 20.0:
			slow.append("collect %.0f" % ms)
	func _chunk_regions(c: Vector2i) -> Dictionary:
		var k := "%d,%d" % [c.x, c.y]
		var had := _chunks.has(k)
		var t := Time.get_ticks_usec()
		var r := super._chunk_regions(c)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		if not had and ms > 20.0:
			slow.append("sync-load %s %.0f" % [k, ms])
		return r


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var dir := OS.get_environment("SMOKE_MAP") if OS.get_environment("SMOKE_MAP") != "" else "res://world/maps/map_321"
	var t0 := Time.get_ticks_msec()
	var player := Node2D.new()
	add_child(player)
	var cam := Camera2D.new()
	player.add_child(cam)
	var map := TimedMap.new()
	map.map_dir = dir
	map.focus = player
	add_child(map)
	await get_tree().process_frame
	print("map ", dir, " chunk_mode=", map.chunk_mode, " npcs=", map.npcs.size(), " load ", Time.get_ticks_msec() - t0, " ms")
	var start := Vector2.ZERO
	if map.data.has("start"):
		start = (Vector2(float(map.data["start"][0]), float(map.data["start"][1])) + Vector2(0.5, 0.5)) * 512.0
	else:
		var rect: Array = map.data["rect"]
		start = Vector2((float(rect[0]) + float(rect[2]) + 1.0) * 256.0, (float(rect[1]) + float(rect[3]) + 1.0) * 256.0)
	var t1 := Time.get_ticks_msec()
	map.prepare_around(start)
	print("prepare_around ", Time.get_ticks_msec() - t1, " ms, grid region ", map.grid.region)
	player.global_position = start
	map.warm_up(start, 2)
	for i in 60:
		await get_tree().process_frame
	print("loaded regions=", map._tiles.size(), " objects regions=", map._objects.size(), " chunks in memory=", map._chunks.size())

	## vật cản: client (VltkMap) == server (MapGrid) == lưới tìm đường
	var tg := Time.get_ticks_msec()
	var mg := MapGrid.load_from(dir)
	print("server MapGrid.load_from ", Time.get_ticks_msec() - tg, " ms")
	var same := 0
	var diff := 0
	var blocked := 0
	var grid_bad := 0
	for i in 4000:
		var p := start + Vector2(randf_range(-2500, 2500), randf_range(-2500, 2500))
		var a := map.is_blocked(p)
		var b := mg.is_blocked(p)
		if a == b:
			same += 1
		else:
			diff += 1
		if a:
			blocked += 1
		var c := map.world_to_cell(p)
		if map.grid.is_in_boundsv(c) and map.grid.is_point_solid(c) != a:
			grid_bad += 1
	print("obstacles: client==server ", same, " differ ", diff, " (blocked ", blocked, "), grid mismatch ", grid_bad, ", server npcs ", mg.data.get("npcs", []).size())

	## tìm đường từ ô trống gần điểm xuất phát tới 12 điểm quanh đó (300..1500 px)
	var pa := mg.free_near(start)
	var found := 0
	for i in 12:
		var ang := TAU * i / 12.0
		var pb := mg.free_near(pa + Vector2(cos(ang), sin(ang) * 0.5) * (300.0 + 100.0 * i))
		if map.find_path(pa, pb).size() >= 2:
			found += 1
	print("paths found ", found, "/12 from ", pa)

	## đi xuyên qua nhiều khối: đo khung hình
	var worst := 0.0
	var total := 0.0
	var step := float(OS.get_environment("SMOKE_STEP")) if OS.get_environment("SMOKE_STEP") != "" else 0.0
	var frames := int(OS.get_environment("SMOKE_FRAMES")) if OS.get_environment("SMOKE_FRAMES") != "" else 400
	var t_prev := Time.get_ticks_usec()
	var spikes := 0
	for i in frames:
		if step > 0.0:                      ## đi thẳng với tốc độ đều (px / khung) như nhân vật thật
			player.global_position = start + Vector2(step * i, step * i * 0.35)
		else:
			player.global_position = start + Vector2(sin(i * 0.02) * float(OS.get_environment("SMOKE_WALK") if OS.get_environment("SMOKE_WALK") != "" else "3000"), i * 4.0)
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		var dt := float(t - t_prev) / 1000.0
		t_prev = t
		worst = maxf(worst, dt)
		total += dt
		if dt > 50.0:
			spikes += 1
	print("frames over 50 ms: ", spikes, "  slow steps: ", map.slow)
	print("walk ", frames * 40, " px: avg frame ", snappedf(total / frames, 0.01), " ms, worst ", snappedf(worst, 0.1), " ms, chunks in memory ", map._chunks.size(), ", loaded regions ", map._tiles.size(), ", nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var ok := map._tiles.size() > 0 and diff == 0 and grid_bad == 0 and found > 0
	print("RESULT ", "OK" if ok else "FAIL")
	get_tree().quit()

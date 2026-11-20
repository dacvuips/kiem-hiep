extends Node
## Bộ nhớ ẢNH của map khi đi xa (VltkWorld.SortedMap._prune_textures) trên map THẬT Tống Kim 1:
## đi xuyên nhiều khối map -> cache ảnh không phình mãi, ảnh của vùng đã đi xa được bỏ, vùng đang hiện không mất hình.
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/map_texture_cache_tests.tscn

var MAP_DIR := OS.get_environment("MAP_CACHE_DIR") if OS.has_environment("MAP_CACHE_DIR") else "res://world/maps/map_tongkim1"
const STEP_PX := 24.0          ## mỗi khung hình đi chừng này px (~ chạy ngựa nhanh)
const WALK_REGIONS := 120      ## đi 120 vùng = 61.440 px (~4 khối map)

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name, "  ", detail)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func _ready() -> void:
	VltkWorld.net_monsters = true   ## không sinh quái thật (chỉ đo ảnh map)
	await get_tree().process_frame
	await run()
	print("RESULT %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(1 if _fail > 0 else 0)

## Sprite đang hiện của map mà mất ảnh (texture null).
func _blank_sprites(map: Node) -> int:
	var n := 0
	for root in [map.objects_root, map.above_root]:
		if root == null:
			continue
		for holder in root.get_children():
			for ch in holder.get_children():
				if ch is Sprite2D and (ch as Sprite2D).texture == null:
					n += 1
	return n

func _settle(map: Node, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func run() -> void:
	var player := Node2D.new()
	add_child(player)
	var cam := Camera2D.new()
	player.add_child(cam)
	var map := VltkWorld.SortedMap.new()
	map.map_dir = MAP_DIR
	map.focus = player
	map.prune_grace = 1.0
	map.lookahead_enabled = false
	var start := Vector2.ZERO
	add_child(map)
	await get_tree().process_frame
	check("Nạp map %s dạng chia khối" % MAP_DIR, map.chunk_mode and not map.data.is_empty())
	var s: Array = map.data.get("start", [300, 1000])
	start = (Vector2(float(s[0]), float(s[1])) + Vector2(0.5, 0.5)) * 512.0
	player.position = start
	await _settle(map, 120)
	var at_start: int = map.texture_cache_size()
	var objects_start: int = map.objects_root.get_child_count()
	print("    lúc đứng ở điểm xuất phát: %d ảnh trong cache, %d vật thể" % [at_start, objects_start])
	check("Có vật thể (cây / nhà) hiện quanh điểm xuất phát", objects_start > 0, objects_start)

	## Đi qua lại theo chiều ngang TRONG phạm vi map (map nhỏ thì dội lại ở mép). Cứ 4 giây cache được dọn 1 lần (PRUNE_INTERVAL).
	var rect: Array = map.data.get("rect", [0, 0, 100000, 100000])
	var min_x := (float(rect[0]) + 0.5) * 512.0
	var max_x := (float(rect[2]) + 0.5) * 512.0
	var dir_x := 1.0
	var peak := at_start
	var samples: Array = []
	var ever := {}   ## mọi ảnh khác nhau từng nằm trong cache trên đường đi
	var steps := int(WALK_REGIONS * 512.0 / STEP_PX)
	var t0 := Time.get_ticks_msec()
	for i in steps:
		player.position.x += STEP_PX * dir_x
		if player.position.x >= max_x:
			dir_x = -1.0
		elif player.position.x <= min_x:
			dir_x = 1.0
		await get_tree().process_frame
		var n: int = map.texture_cache_size()
		peak = maxi(peak, n)
		if i % 200 == 0:
			samples.append(n)
		if i % 20 == 0:
			for k in map._tex_cache:
				ever[str(k).get_file()] = true
	var walk_sec := (Time.get_ticks_msec() - t0) / 1000.0
	print("    đi %d vùng trong %.0f giây: cache ảnh theo thời gian %s, cao nhất %d" % [WALK_REGIONS, walk_sec, samples, peak])
	## Đứng lại cho các vùng quanh chỗ mới nạp xong + qua 2 lượt dọn.
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 10000:
		await get_tree().process_frame
	var at_end: int = map.texture_cache_size()
	var live := {}
	for key in map._region_paths:
		if map._objects.has(key) or map._tiles.has(key):
			for p in map._region_paths[key]:
				live[str(p).get_file()] = true
	print("    đứng lại 10 giây: %d ảnh trong cache, vùng đang hiện cần %d ảnh khác nhau" % [at_end, live.size()])
	check("Cache ảnh không giữ ảnh của vùng đã đi xa (cuối <= ảnh vùng đang hiện + atlas + 20%)", at_end <= int(live.size() * 1.2) + 8,
		[at_end, live.size()])
	var uniq := {}
	for k in map._tex_cache:
		uniq[str(k).get_file()] = true
	print("    trên đường đi đã nạp tổng cộng %d ảnh khác nhau" % ever.size())
	## Map nhỏ (ít ảnh khác nhau) thì cả map gần như luôn nằm trong tầm nhìn: chỉ đòi không vượt tổng số ảnh của map.
	## Chỉ so mức phình khi map có nhiều ảnh hơn hẳn khung nhìn (map nhỏ: gần như cả map luôn trong tầm nhìn).
	if ever.size() > live.size() * 2 + 20:
		check("Cache không phình theo quãng đường (cuối < 1/2 tổng ảnh đã nạp)", at_end * 2 < ever.size(), [at_end, ever.size(), peak, at_start])
	else:
		check("Map nhỏ: cache không vượt tổng số ảnh đã nạp", at_end <= ever.size() + 8, [at_end, ever.size()])
	check("Vùng đang hiện không bị mất hình (không sprite nào trống ảnh)", _blank_sprites(map) == 0, _blank_sprites(map))

	## Quay lại điểm xuất phát: ảnh đã bỏ được nạp lại đúng, không mất hình.
	player.position = start
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 6000:
		await get_tree().process_frame
	check("Quay lại chỗ cũ: nạp lại ảnh đủ, không sprite nào trống", _blank_sprites(map) == 0 and map.objects_root.get_child_count() > 0,
		[_blank_sprites(map), map.objects_root.get_child_count()])

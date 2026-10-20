extends Node2D
## Map exported by the VLTK map editor (Godot 4).
## 1. Copy the exported folder into your project (e.g. res://maps/map_xxxx/).
## 2. Add a Node2D to a scene, attach this script, set `map_dir` (and `focus`, e.g. the player).
## 3. Add your characters as children of `objects_root` so they are depth-sorted with buildings and trees
##    (they can walk behind houses). `ground_root` holds the ground, `above_root` roof-like objects.
## map.json "ground_mode": "tiles" = baked 512x512 pictures (tiles/X_Y.webp), "atlas" = ground cells drawn from atlas/atlas_N.png + loose cover sprites.
## map.json "format": "chunks" (big maps) = the regions are packed in chunks/CX_CY.json.gz (32x32 regions each), loaded in the
## background around `focus`; the path-finding `grid` then covers only `nav_radius_regions` around the focus and follows it.
class_name VltkMap

signal region_loaded(rx: int, ry: int)
## NPC / monster nodes appear when their region is loaded: `data` is the entry of map.json (t, lv, series, role, wander, respawn, speed, uid, name_vi, script ...)
signal npc_spawned(node: Node2D, data: Dictionary)
signal monster_killed(node: Node2D)
signal monster_respawned(node: Node2D)

@export_dir var map_dir: String = "res://maps/map"
@export var focus: Node2D
@export var load_radius_regions: int = 2
## "" = the exported folder is inside the project (res://). Otherwise the http(s) address of the exported folder, e.g. "https://cdn.example.com/maps/map_ab12cd34/":
## every file is then downloaded ONCE into `cache_root` (user://, survives closing the game) and re-downloaded only when manifest.json says it changed.
@export var base_url: String = ""
## Atlas ground only: true = when a region loads, its ground is composed ONCE into a single texture (same cost per frame as the baked tiles,
## memory freed with the region); false = every ground cell is drawn from the atlas each frame (slower on weak phones).
@export var bake_ground: bool = true
@export var cache_root: String = "user://vltk_cache"
## Chunk maps: the path-finding grid covers this many regions on each side of the focus (rebuilt when the focus has moved half of it).
@export var nav_radius_regions: int = 10

var data: Dictionary
var tile_ext: String
var tile_px: int
var cell := Vector2(32, 16)
var grid: AStarGrid2D
var traps := {}                 # Vector2i(cell) -> trap id
var npcs: Array = []            # [{t,x,y,name,...}] client NPCs, absolute map pixels

var ground_root := Node2D.new()
var ground_mode := "tiles"       # "tiles" = baked 512x512 pictures, "atlas" = ground cells drawn from a shared atlas + loose cover sprites
var _g_base := Node2D.new()      # ground tiles / atlas layers
var _g_covers := Node2D.new()    # covers, kept sorted by (order, layer, y) like the game does
var _g_flat := Node2D.new()      # flat objects lying on the ground (layer 0)
var _atlas_tex: Array = []
var _atlas_items: Array = []
var _atlas_img: Array = []            # the atlas pages as Images (for composing a region's ground)
var _bake_pad := [0, 0, 0, 0]         # left, top, right, bottom: ground pictures hang this far outside their 512x512 region
var objects_root := Node2D.new()
var above_root := Node2D.new()

var _tiles := {}                # "x,y" -> Sprite2D
var _objects := {}              # "x,y" -> Array[Node]
var _tex_cache := {}

# ---- downloaded files (only used when base_url is set)
signal _file_done(rel: String, ok: bool)
const MAX_DOWNLOADS := 6
var _cache_dir := ""
var _manifest := {}            # rel -> [size, crc32] as published by the server (manifest.json)
var _local_manifest := {}      # rel -> [size, crc32] of the copy that is stored on disk
var _offline := false          # manifest could not be fetched: use whatever is cached
var _queue: Array = []
var _queued := {}
var _active := 0
var _loading := {}             # regions whose files are being downloaded
var _want := {}
var _manifest_dirty := false

## Behaviour of the NPCs / monsters placed in the editor:
##   role "npc"     stands still (dialog NPC)
##   role "monster" patrols around its home inside `wander` px, call kill_npc() when it dies: it returns after `respawn` seconds
##   role "critter" wanders (birds, mice ...)
var _actors: Array = []
var _dead_until := {}            # uid -> time (s) when a killed monster is back; kept while its region is unloaded
var _rng := RandomNumberGenerator.new()

# ---- chunk maps (map.json "format": "chunks")
var chunk_mode := false
var chunk_size := 32
var _chunk_have := {}            # "cx,cy" -> true: chunk files of the map
var _chunks := {}                # "cx,cy" -> {"x,y": region doc} chunks in memory
var _chunk_jobs := {}            # "cx,cy" -> WorkerThreadPool task reading that chunk
var _chunk_ready := {}           # "cx,cy" -> parsed chunk, handed over by the worker threads
var _chunk_mutex := Mutex.new()
var _obs := {}                   # "x,y" -> PackedByteArray(512) obstacle values of the regions in memory (index cx * 32 + cy); empty = all free
var _nav_center := Vector2i(1 << 30, 1 << 30)
var _nav_dirty := true
var _region_idx := {}            # one-file-per-region maps: Vector2i -> [rx, ry, has_ground, has_objects]
var _npcs_by_region := {}        # one-file-per-region maps: "x,y" -> NPC entries


func _ready() -> void:
	ground_root.name = "Ground"
	ground_root.z_index = -100
	objects_root.name = "Objects"
	objects_root.y_sort_enabled = true
	above_root.name = "Above"
	above_root.z_index = 100
	above_root.y_sort_enabled = true
	_g_base.name = "GroundBase"
	_g_covers.name = "GroundCovers"
	_g_flat.name = "GroundFlat"
	ground_root.add_child(_g_base)
	ground_root.add_child(_g_covers)
	ground_root.add_child(_g_flat)
	add_child(ground_root)
	add_child(objects_root)
	add_child(above_root)
	load_map(map_dir)


func load_map(dir: String) -> void:
	map_dir = dir
	var text := ""
	if base_url != "":
		text = await _remote_boot()
	else:
		var f := FileAccess.open(dir.path_join("map.json"), FileAccess.READ)
		if f == null:
			push_error("VltkMap: cannot open %s/map.json" % dir)
			return
		text = f.get_as_text()
	if text == "":
		return
	var parsed: Dictionary = JSON.parse_string(text)     ## `data` is assigned LAST: _process starts loading regions as soon as it is not empty
	tile_ext = parsed["tile_ext"]
	tile_px = int(parsed["tile_px"])
	npcs = parsed.get("npcs", [])
	ground_mode = str(parsed.get("ground_mode", "tiles"))
	chunk_mode = str(parsed.get("format", "")) == "chunks"
	if chunk_mode:
		chunk_size = int(parsed.get("chunk", 32))
		for k in parsed.get("chunks", {}):
			_chunk_have[str(k)] = true
	if base_url != "":
		var boot: Array = []
		if chunk_mode:
			boot.append(str(parsed.get("spawns", "spawns.json.gz")))
		if ground_mode == "atlas":
			boot.append(str(parsed["atlas"]))
		if parsed.get("minimap") != null:
			boot.append(str(parsed["minimap"]["file"]))
			boot.append(str(parsed["minimap"]["file_npc"]))
		await _ensure_files(boot)
		if ground_mode == "atlas":                 # atlas.json tells which pages to fetch
			var af := FileAccess.open(_p(str(parsed["atlas"])), FileAccess.READ)
			if af:
				var pages: Array = []
				for pg in JSON.parse_string(af.get_as_text())["pages"]:
					pages.append("atlas/" + str(pg))
				await _ensure_files(pages)
	if chunk_mode:                                  # every NPC / monster of the map (for all_spawns, minimap, quests)
		var sp = _read_gz_json(_p(str(parsed.get("spawns", "spawns.json.gz"))))
		npcs = sp if sp is Array else []
	data = parsed
	if ground_mode == "atlas":
		_load_atlas()
	_build_grid()
	if focus == null:
		if chunk_mode:
			push_warning("VltkMap: chunk map without `focus` - set a focus node, the whole map is never loaded at once")
			return
		for r in data["regions"]:
			_request_region(int(r[0]), int(r[1]))


## Local path of a file of the exported map: inside the project, or in the download cache.
func _p(rel: String) -> String:
	return _cache_dir.path_join(rel) if base_url != "" else map_dir.path_join(rel)


# ---------------------------------------------------------------- regions (one file each, or packed in chunks)
func _read_gz_json(path: String) -> Variant:
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.is_empty():
		return null
	return JSON.parse_string(raw.decompress_dynamic(1 << 30, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())


func chunk_of(rx: int, ry: int) -> Vector2i:
	return Vector2i(floori(float(rx) / chunk_size), floori(float(ry) / chunk_size))


func _chunk_rel(c: Vector2i) -> String:
	return "chunks/%d_%d.json.gz" % [c.x, c.y]


## Read + unzip + parse a chunk and unpack its obstacles (runs on a worker thread, or inline).
func _parse_chunk(path: String) -> Dictionary:
	var d = _read_gz_json(path)
	if not (d is Dictionary and d.has("r")):
		return {}
	var regs: Dictionary = d["r"]
	var fills := {}
	for rk in regs:
		var doc: Dictionary = regs[rk]
		var ob := PackedByteArray()
		if doc.has("ob"):                    # RLE [value, count, ...] -> 512 bytes, built from pre-filled slices
			var runs: Array = doc["ob"]
			var j := 0
			while j + 1 < runs.size():
				var v := int(runs[j]) & 0xff
				if not fills.has(v):
					var f := PackedByteArray()
					f.resize(512)
					f.fill(v)
					fills[v] = f
				ob.append_array((fills[v] as PackedByteArray).slice(0, int(runs[j + 1])))
				j += 2
			ob.resize(512)
		doc["_ob"] = ob
	return regs


func _chunk_task(k: String, path: String) -> void:
	var regs := _parse_chunk(path)
	_chunk_mutex.lock()
	_chunk_ready[k] = regs
	_chunk_mutex.unlock()


## Start reading a chunk in the background (nothing happens when it is in memory / already loading / not in the map).
func _prefetch_chunk(c: Vector2i) -> void:
	var k := "%d,%d" % [c.x, c.y]
	if _chunks.has(k) or _chunk_jobs.has(k) or not _chunk_have.has(k):
		return
	if base_url != "" and not _valid(_chunk_rel(c)):
		_ensure_files([_chunk_rel(c)])             # downloads in the background, read on a later tick
		return
	_chunk_jobs[k] = WorkerThreadPool.add_task(_chunk_task.bind(k, _p(_chunk_rel(c))))


func _collect_chunks() -> void:
	_chunk_mutex.lock()
	var ready := _chunk_ready
	_chunk_ready = {}
	_chunk_mutex.unlock()
	for k in ready:
		if _chunk_jobs.has(k):
			WorkerThreadPool.wait_for_task_completion(_chunk_jobs[k])
			_chunk_jobs.erase(k)
		_install_chunk(k, ready[k])


func _install_chunk(k: String, regs: Dictionary) -> void:
	if _chunks.has(k):
		return
	_chunks[k] = regs
	for rk in regs:
		_obs[rk] = regs[rk].get("_ob", PackedByteArray())
	_nav_dirty = true


## Regions of a chunk ({"x,y": doc}); a chunk that is not in memory yet is read now (blocking).
func _chunk_regions(c: Vector2i) -> Dictionary:
	var k := "%d,%d" % [c.x, c.y]
	if _chunks.has(k):
		return _chunks[k]
	if not _chunk_have.has(k):
		return {}
	if _chunk_jobs.has(k):
		WorkerThreadPool.wait_for_task_completion(_chunk_jobs[k])
	_collect_chunks()
	if not _chunks.has(k):
		_install_chunk(k, _parse_chunk(_p(_chunk_rel(c))))
	return _chunks.get(k, {})


## Forget the chunks far from chunk `c` (keeps the 5x5 around it).
func _drop_far_chunks(c: Vector2i) -> void:
	for k in _chunks.keys():
		var p: PackedStringArray = str(k).split(",")
		if absi(int(p[0]) - c.x) <= 2 and absi(int(p[1]) - c.y) <= 2:
			continue
		for rk in _chunks[k]:
			_obs.erase(rk)
		_chunks.erase(k)


## Keep the chunks around the focus region `c` coming in (background threads) and the path-finding grid around it.
func stream_tick(c: Vector2i) -> void:
	if not chunk_mode or data.is_empty():
		return
	_collect_chunks()
	var cc := chunk_of(c.x, c.y)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_prefetch_chunk(cc + Vector2i(dx, dy))
	_update_nav(c)
	if Engine.get_process_frames() % 120 == 0:
		_drop_far_chunks(cc)


## Make the area around a world point usable right now (chunks read, path-finding grid there): before placing a player.
func prepare_around(world_pos: Vector2) -> void:
	if not chunk_mode:
		return
	var c := world_to_region(world_pos)
	_nav_dirty = true
	_update_nav(c)


## [rx, ry, has_ground, has_objects] of a region, [] when the map has no such region.
func region_info(v: Vector2i) -> Array:
	if chunk_mode:
		var regs := _chunk_regions(chunk_of(v.x, v.y))
		var d = regs.get("%d,%d" % [v.x, v.y])
		if d == null:
			return []
		return [v.x, v.y, 1 if (d as Dictionary).has("g") else 0, 1]
	if _region_idx.is_empty():
		for r in data.get("regions", []):
			_region_idx[Vector2i(int(r[0]), int(r[1]))] = r
	return _region_idx.get(v, [])


## Ground cells / covers / objects of a region: its regions/X_Y.json, or its entry in the chunk file.
func region_doc(rx: int, ry: int) -> Dictionary:
	if chunk_mode:
		return _chunk_regions(chunk_of(rx, ry)).get("%d,%d" % [rx, ry], {})
	var f := FileAccess.open(_p("regions/%d_%d.json" % [rx, ry]), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## NPC / monster entries that stand in a region.
func region_npcs(rx: int, ry: int) -> Array:
	if chunk_mode:
		return region_doc(rx, ry).get("npcs", [])
	if not _npcs_by_region.has("_built"):
		_npcs_by_region["_built"] = []
		for n in npcs:
			var k := "%d,%d" % [int(n["rx"]), int(n["ry"])]
			if not _npcs_by_region.has(k):
				_npcs_by_region[k] = []
			_npcs_by_region[k].append(n)
	return _npcs_by_region.get("%d,%d" % [rx, ry], [])


## Which NPC entries the base map spawns itself (a game can take some over, e.g. real monsters).
func _spawn_filter(_n: Dictionary) -> bool:
	return true


## Ground drawn straight from the atlas: one canvas item per region, a single draw call per atlas page batch.
class GroundLayer extends Node2D:
	var tex: Array = []
	var items: Array = []
	var cells := PackedInt32Array()
	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var i := 0
		while i < cells.size():
			var it: Array = items[cells[i + 2]]
			var w := float(it[3])
			var h := float(it[4])
			draw_texture_rect_region(tex[int(it[0])], Rect2(cells[i] * 32 + float(it[5]), cells[i + 1] * 32 + float(it[6]), w, h),
					Rect2(float(it[1]), float(it[2]), w, h))
			i += 3


func _load_atlas() -> void:
	var f := FileAccess.open(_p(str(data["atlas"])), FileAccess.READ)
	if f == null:
		push_error("VltkMap: atlas missing: %s" % data["atlas"])
		return
	var a: Dictionary = JSON.parse_string(f.get_as_text())
	_atlas_items = a["items"]
	_atlas_tex.clear()
	for p in a["pages"]:
		_atlas_tex.append(_load_tex(_p("atlas/" + str(p))))
	_atlas_img.clear()
	for t in _atlas_tex:
		var im: Image = t.get_image() if t != null else null
		if im != null:
			if im.is_compressed():
				im.decompress()
			if im.get_format() != Image.FORMAT_RGBA8:
				im.convert(Image.FORMAT_RGBA8)
		_atlas_img.append(im)
	var pad := [0, 0, 0, 0]
	for it in _atlas_items:
		pad[0] = maxi(pad[0], -int(it[5]))
		pad[1] = maxi(pad[1], -int(it[6]))
		pad[2] = maxi(pad[2], int(it[5]) + int(it[3]) - 32)
		pad[3] = maxi(pad[3], int(it[6]) + int(it[4]) - 32)
	for i in 4:
		_bake_pad[i] = mini(pad[i], 128)


## Compose the ground cells of one region into a texture (+ the margin the pictures hang over the region border).
func _bake_ground(cells: Array) -> Texture2D:
	var img := Image.create(512 + int(_bake_pad[0]) + int(_bake_pad[2]), 512 + int(_bake_pad[1]) + int(_bake_pad[3]), false, Image.FORMAT_RGBA8)
	var i := 0
	while i + 2 < cells.size():
		var it: Array = _atlas_items[int(cells[i + 2])]
		var src: Image = _atlas_img[int(it[0])]
		if src != null:
			img.blend_rect(src, Rect2i(int(it[1]), int(it[2]), int(it[3]), int(it[4])),
					Vector2i(int(cells[i]) * 32 + int(it[5]) + int(_bake_pad[0]), int(cells[i + 1]) * 32 + int(it[6]) + int(_bake_pad[1])))
		i += 3
	return ImageTexture.create_from_image(img)


## Insert a cover so that _g_covers stays ordered by its sort key (binary search).
func _insert_cover(node: Sprite2D, key: int) -> void:
	node.set_meta("k", key)
	var lo := 0
	var hi := _g_covers.get_child_count()
	while lo < hi:
		var mid := (lo + hi) / 2
		if int(_g_covers.get_child(mid).get_meta("k")) <= key:
			lo = mid + 1
		else:
			hi = mid
	_g_covers.add_child(node)
	_g_covers.move_child(node, lo)


func _process(_dt: float) -> void:
	_update_actors(_dt)
	if focus == null or data.is_empty():
		return
	var c := world_to_region(focus.global_position - global_position)
	stream_tick(c)
	var want := {}
	_want = want
	for ry in range(c.y - load_radius_regions, c.y + load_radius_regions + 1):
		for rx in range(c.x - load_radius_regions, c.x + load_radius_regions + 1):
			want["%d,%d" % [rx, ry]] = Vector2i(rx, ry)
	for k in _tiles.keys():
		if not want.has(k):
			_hide_region(k)
	for k in want:
		if not _tiles.has(k) and not _objects.has(k):
			_request_region(want[k].x, want[k].y)


func world_to_region(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 512.0), floori(p.y / 512.0))


func _region_info(rx: int, ry: int) -> Array:
	return region_info(Vector2i(rx, ry))


func _load_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		if path.begins_with("user://"):            # downloaded file: not an imported resource, read the picture directly
			var im: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
			_tex_cache[path] = ImageTexture.create_from_image(im) if im != null else null
		else:
			_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


# ---------------------------------------------------------------- downloading (base_url)
func _local_path(rel: String) -> String:
	return _cache_dir.path_join(rel)


func _valid(rel: String) -> bool:
	if not FileAccess.file_exists(_local_path(rel)):
		return false
	if _offline or not _manifest.has(rel):
		return true
	return _local_manifest.get(rel, []) == _manifest[rel]


func _remote_boot() -> String:
	_cache_dir = cache_root.path_join(base_url.md5_text())
	DirAccess.make_dir_recursive_absolute(_cache_dir)
	var lf := FileAccess.open(_cache_dir.path_join("local.json"), FileAccess.READ)
	if lf:
		var d = JSON.parse_string(lf.get_as_text())
		if d is Dictionary:
			_local_manifest = d
	var mtext := await _http_text("manifest.json")
	if mtext == "":
		_offline = true
		push_warning("VltkMap: manifest.json not reachable - using the cached files")
	else:
		_manifest = JSON.parse_string(mtext)["files"]
	await _ensure_files(["map.json"])
	var mf := FileAccess.open(_local_path("map.json"), FileAccess.READ)
	return mf.get_as_text() if mf else ""


func _http_text(rel: String) -> String:
	var req := HTTPRequest.new()
	add_child(req)
	if req.request(base_url.path_join(rel) + "?v=%d" % Time.get_ticks_msec()) != OK:
		req.queue_free()
		return ""
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return ""
	return (res[3] as PackedByteArray).get_string_from_utf8()


## Make sure every file is on disk (downloads the missing / changed ones). Returns false if any download failed.
func _ensure_files(rels: Array) -> bool:
	if base_url == "":
		return true
	var need: Array = []
	for r in rels:
		if not _valid(str(r)) and not need.has(str(r)):
			need.append(str(r))
	if need.is_empty():
		return true
	for r in need:
		_enqueue(r)
	var left := need.size()
	var all_ok := true
	while left > 0:
		var res: Array = await _file_done
		if need.has(res[0]):
			left -= 1
			if not res[1]:
				all_ok = false
	return all_ok


func _enqueue(rel: String) -> void:
	if _queued.has(rel):
		return
	_queued[rel] = true
	_queue.append(rel)
	_pump()


func _pump() -> void:
	while _active < MAX_DOWNLOADS and not _queue.is_empty():
		var rel: String = _queue.pop_front()
		var path := _local_path(rel)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var req := HTTPRequest.new()
		req.download_file = path + ".part"
		add_child(req)
		req.request_completed.connect(_on_downloaded.bind(rel, req))
		if req.request(base_url.path_join(rel)) != OK:
			req.queue_free()
			_queued.erase(rel)
			_file_done.emit(rel, false)
			continue
		_active += 1


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, rel: String, req: HTTPRequest) -> void:
	_active -= 1
	var path := _local_path(rel)
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200
	if ok:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		DirAccess.rename_absolute(path + ".part", path)
		_local_manifest[rel] = _manifest.get(rel, [])
		_manifest_dirty = true
	elif FileAccess.file_exists(path + ".part"):
		DirAccess.remove_absolute(path + ".part")
	req.queue_free()
	_queued.erase(rel)
	_file_done.emit(rel, ok)
	_pump()
	if _active == 0 and _queue.is_empty() and _manifest_dirty:
		_manifest_dirty = false
		var f := FileAccess.open(_cache_dir.path_join("local.json"), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(_local_manifest))


## Show a region: with base_url first download everything it needs (its json, pictures of its objects, covers, NPCs), then build it.
func _request_region(rx: int, ry: int) -> void:
	if base_url == "":
		_show_region(rx, ry)
		return
	var key := "%d,%d" % [rx, ry]
	if _loading.has(key):
		return
	if chunk_mode and not _valid(_chunk_rel(chunk_of(rx, ry))):
		_loading[key] = true
		await _ensure_files([_chunk_rel(chunk_of(rx, ry))])
		_loading.erase(key)
	var info := _region_info(rx, ry)
	if info.is_empty():
		return
	_loading[key] = true
	var files: Array = []
	if ground_mode == "tiles" and int(info[2]) == 1:
		files.append("tiles/%d_%d.%s" % [rx, ry, tile_ext])
	if int(info[3]) == 1:
		if not chunk_mode:
			await _ensure_files(["regions/%d_%d.json" % [rx, ry]])
		var doc := region_doc(rx, ry)
		for o in doc.get("objects", []):
			files.append(str(o["img"]))
		for c in doc.get("covers", []):
			files.append(str(c[0]))
	for n in region_npcs(rx, ry):
		if n.has("img"):
			files.append(str(n["img"]))
	await _ensure_files(files)
	_loading.erase(key)
	if not _tiles.has(key) and not _objects.has(key) and (focus == null or _want.has(key)):
		_show_region(rx, ry)


func _show_region(rx: int, ry: int, info: Array = []) -> void:
	var key := "%d,%d" % [rx, ry]
	if info.is_empty():
		info = _region_info(rx, ry)
	if info.is_empty():
		return
	var made: Array = []
	if ground_mode == "tiles" and int(info[2]) == 1:
		var tex := _load_tex(_p("tiles/%d_%d.%s" % [rx, ry, tile_ext]))
		if tex:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.scale = Vector2.ONE * (512.0 / tile_px)
			s.position = Vector2(rx * 512, ry * 512)
			_g_base.add_child(s)
			_tiles[key] = s
	if int(info[3]) == 1:
		var doc := region_doc(rx, ry)
		if not doc.is_empty():
			if ground_mode == "atlas":
				if doc.has("g") and bake_ground and not _atlas_img.is_empty() and _atlas_img[0] != null:
					var gs := Sprite2D.new()
					gs.texture = _bake_ground(doc["g"])
					gs.centered = false
					gs.position = Vector2(rx * 512 - int(_bake_pad[0]), ry * 512 - int(_bake_pad[1]))
					_g_base.add_child(gs)
					_tiles[key] = gs
				elif doc.has("g") and not _atlas_tex.is_empty():
					var gl := GroundLayer.new()
					gl.tex = _atlas_tex
					gl.items = _atlas_items
					for v in doc["g"]:                       # JSON numbers are floats
						gl.cells.append(int(v))
					gl.position = Vector2(rx * 512, ry * 512)
					_g_base.add_child(gl)
					_tiles[key] = gl
				for c in doc.get("covers", []):
					var ctex := _load_tex(_p(str(c[0])))
					if ctex == null:
						continue
					var cs := Sprite2D.new()
					cs.texture = ctex
					cs.centered = false
					cs.position = Vector2(float(c[1]), float(c[2]))
					_insert_cover(cs, int(c[3]) * 1000000000000 + (int(c[4]) + 1000) * 1000000000 + int(c[5]))
					made.append(cs)
			for o in doc.get("objects", []):
				var tex := _load_tex(_p(str(o["img"])))
				if tex == null:
					continue
				var holder := Node2D.new()
				var sp := Sprite2D.new()
				sp.texture = tex
				sp.centered = false
				var layer: int = int(o["l"])
				# the holder sits on the object's sort line; the sprite hangs off it
				holder.position = Vector2(o["x"], o["sy"])
				var oy := float(o["y"]) - float(o["sy"])
				if layer == 0:
					holder.position = Vector2(o["x"], o["y"])
					oy = 0.0
				if o.has("m"):      # LINE / TREE objects are sheared pictures: the matrix maps the bitmap onto the iso wall
					var m: Array = o["m"]
					sp.transform = Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(0, oy))
				else:
					sp.position = Vector2(0, oy)
				holder.add_child(sp)
				if layer == 0:
					_g_flat.add_child(holder)
				elif layer == 2:
					above_root.add_child(holder)
				else:
					objects_root.add_child(holder)
				made.append(holder)
	_spawn_npcs(rx, ry, made)
	_objects[key] = made
	region_loaded.emit(rx, ry)


## NPCs / monsters of the region: their picture (depth-sorted with houses) and a name label.
func _spawn_npcs(rx: int, ry: int, made: Array) -> void:
	for n in region_npcs(rx, ry):
		if not _spawn_filter(n):
			continue
		var tex: Texture2D = null
		if n.has("img"):
			tex = _load_tex(_p(str(n["img"])))
		var holder := Node2D.new()
		holder.name = "Npc_%s" % str(n.get("name_vi", n.get("name", "")))
		holder.position = Vector2(float(n["px"]), float(n["py"]))
		var sp := Sprite2D.new()
		if tex != null:
			sp.texture = tex
			sp.centered = false
			sp.position = Vector2(float(n["ix"]) - holder.position.x, float(n["iy"]) - holder.position.y)
		else:                                    # no picture for this template (humanoid / missing sprite): a marker, the logic still works
			var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
			img.fill(Color(1.0, 0.3, 0.3, 0.9) if str(n.get("role", "npc")) == "monster" else Color(0.4, 1.0, 0.5, 0.9))
			sp.texture = ImageTexture.create_from_image(img)
			sp.position = Vector2(-12, -24)
			sp.centered = false
		holder.add_child(sp)
		var label := Label.new()
		label.text = str(n.get("name_vi", n.get("name", "")))
		label.add_theme_font_size_override("font_size", 12)
		label.position = Vector2(-label.text.length() * 3.0, sp.position.y - 14.0)
		holder.add_child(label)
		objects_root.add_child(holder)
		made.append(holder)
		var uid := str(n.get("uid", ""))
		holder.set_meta("uid", uid)
		holder.set_meta("role", str(n.get("role", "npc")))
		holder.set_meta("npc", n)
		holder.add_to_group(str(n.get("role", "npc")))          # "npc" | "monster" | "critter": get_tree().get_nodes_in_group("monster")
		holder.add_to_group("npc_actor")
		_actors.append({"holder": holder, "uid": uid, "role": str(n.get("role", "npc")), "home": holder.position,
				"wander": float(n.get("wander", 0)), "speed": float(n.get("speed", 8)) * 10.0, "respawn": float(n.get("respawn", 0)),
				"target": holder.position, "wait": _rng.randf_range(0.3, 3.0)})
		if _dead_until.has(uid) and Time.get_ticks_msec() / 1000.0 < float(_dead_until[uid]):
			holder.visible = false
		npc_spawned.emit(holder, n)


func _update_actors(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_actors = _actors.filter(func(a): return is_instance_valid(a["holder"]) and not a["holder"].is_queued_for_deletion())
	for a in _actors:
		var h: Node2D = a["holder"]
		var uid: String = a["uid"]
		if _dead_until.has(uid):
			if now < float(_dead_until[uid]):
				continue                                   # still dead
			_dead_until.erase(uid)                         # back at its home position
			h.position = a["home"]
			a["target"] = a["home"]
			h.visible = true
			monster_respawned.emit(h)
		if a["role"] == "npc" or float(a["wander"]) <= 0.0:
			continue                                       # NPCs stay where they were placed
		if float(a["wait"]) > 0.0:
			a["wait"] = float(a["wait"]) - delta
			continue
		var to: Vector2 = a["target"] - h.position
		var step: float = float(a["speed"]) * delta
		if to.length() <= step:
			h.position = a["target"]
			a["wait"] = _rng.randf_range(1.0, 4.0)
			a["target"] = _pick_target(a)
		else:
			var next := h.position + to.normalized() * step
			if a["role"] == "monster" and is_blocked(next):
				a["target"] = _pick_target(a)
				a["wait"] = 0.5
			else:
				h.position = next


func _pick_target(a: Dictionary) -> Vector2:
	var ang := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * float(a["wander"])
	var p: Vector2 = a["home"] + Vector2(cos(ang) * r, sin(ang) * r * 0.5)   # circle in the scene = ellipse on screen
	if a["role"] == "monster" and is_blocked(p):
		return a["home"]
	return p


## Call when a monster dies (its HP reached 0): it disappears and comes back at its home after `respawn` seconds.
func kill_npc(holder: Node2D) -> void:
	if not holder.has_meta("uid"):
		return
	var respawn := 0.0
	for a in _actors:
		if a["holder"] == holder:
			respawn = float(a["respawn"])
	holder.visible = false
	_dead_until[holder.get_meta("uid")] = Time.get_ticks_msec() / 1000.0 + (respawn if respawn > 0.0 else 1.0e12)
	monster_killed.emit(holder)


## Alive monster closest to a world point (within radius px), or null.
func monster_at(world_pos: Vector2, radius: float = 40.0) -> Node2D:
	var best: Node2D = null
	var bd := radius
	for a in _actors:
		var h: Node2D = a["holder"]
		if a["role"] != "monster" or not h.visible:
			continue
		var d := h.global_position.distance_to(world_pos)
		if d < bd:
			bd = d
			best = h
	return best


## Alive monsters that are currently spawned (their regions are loaded).
func get_monsters() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for a in _actors:
		var h: Node2D = a["holder"]
		if a["role"] == "monster" and h.visible:
			out.append(h)
	return out


## Alive monsters within `radius` px of a world point, closest first.
func monsters_near(world_pos: Vector2, radius: float) -> Array[Node2D]:
	var found: Array = []
	for h in get_monsters():
		var d := h.global_position.distance_to(world_pos)
		if d <= radius:
			found.append([d, h])
	found.sort_custom(func(x, y): return x[0] < y[0])
	var out: Array[Node2D] = []
	for f in found:
		out.append(f[1])
	return out


func nearest_monster(world_pos: Vector2, radius: float = 400.0) -> Node2D:
	var l := monsters_near(world_pos, radius)
	return l[0] if not l.is_empty() else null


## map.json entry of a spawned NPC / monster node: {t, lv, series, role, wander, respawn, speed, uid, name_vi, script ...}
func npc_data(node: Node2D) -> Dictionary:
	return node.get_meta("npc", {}) if node and node.has_meta("npc") else {}


## Every monster / NPC placed in the whole map (also in regions that are not loaded): for minimap, quests, AI that needs the full list.
func all_spawns(role: String = "") -> Array:
	var out: Array = []
	for n in npcs:
		if role == "" or str(n.get("role", "npc")) == role:
			out.append(n)
	return out


func _hide_region(key: String) -> void:
	if _tiles.has(key):
		_tiles[key].queue_free()
		_tiles.erase(key)
	if _objects.has(key):
		for n in _objects[key]:
			n.queue_free()
		_objects.erase(key)


func _build_grid() -> void:
	traps.clear()
	for t in data.get("traps", []):        # [region_x, region_y, cell_x, cell_y, count, id, script]
		for i in int(t[4]):
			traps[Vector2i(int(t[0]) * 16 + int(t[2]) + i, int(t[1]) * 32 + int(t[3]))] = int(t[5])
	if chunk_mode:                          # the grid follows the focus (_update_nav), the whole map would not fit in memory
		grid = AStarGrid2D.new()
		grid.cell_size = cell
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.region = Rect2i(0, 0, 1, 1)
		grid.update()
		return
	var minx: int = int(data["min_x"])
	var miny: int = int(data["min_y"])
	var cols: int = (int(data["max_x"]) - minx + 1) * 16
	var rows: int = (int(data["max_y"]) - miny + 1) * 32
	grid = AStarGrid2D.new()
	grid.region = Rect2i(minx * 16, miny * 32, cols, rows)
	grid.cell_size = cell
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	# a cell is blocked when its obstacle type (high nibble) is not 0.
	# value = (type << 4) | kind ; kind 1 normal, 2 fly-over, 3 jump-over, 4 jump+fly
	for key in data["obstacle"]:
		var p: PackedStringArray = key.split(",")
		var ox: int = int(p[0]) * 16
		var oy: int = int(p[1]) * 32
		var arr: Array = data["obstacle"][key]
		for cx in 16:
			for cy in 32:
				if (int(arr[cx * 32 + cy]) >> 4) != 0:
					grid.set_point_solid(Vector2i(ox + cx, oy + cy), true)


## Chunk maps: path-finding grid of the (2 * nav_radius_regions + 1)^2 regions around region `c`; the same AStarGrid2D object
## is reused (code holding `grid` keeps working). Rebuilt when the focus moved half the radius or new chunks came in.
func _update_nav(c: Vector2i) -> void:
	if not chunk_mode:
		return
	var half := maxi(1, nav_radius_regions / 2)
	if not _nav_dirty and absi(c.x - _nav_center.x) <= half and absi(c.y - _nav_center.y) <= half:
		return
	_nav_dirty = false
	_nav_center = c
	var r := nav_radius_regions
	grid.region = Rect2i((c.x - r) * 16, (c.y - r) * 32, (2 * r + 1) * 16, (2 * r + 1) * 32)
	grid.update()
	for ry in range(c.y - r, c.y + r + 1):
		for rx in range(c.x - r, c.x + r + 1):
			var regs := _chunk_regions(chunk_of(rx, ry))
			var d = regs.get("%d,%d" % [rx, ry])
			if d == null:                  # no region there: nobody walks in
				grid.fill_solid_region(Rect2i(rx * 16, ry * 32, 16, 32), true)
				continue
			var runs: Array = (d as Dictionary).get("ob", [])
			var i := 0
			var j := 0
			while j + 1 < runs.size():
				var n := int(runs[j + 1])
				if (int(runs[j]) >> 4) != 0:
					for q in range(i, mini(i + n, 512)):
						grid.set_point_solid(Vector2i(rx * 16 + q / 32, ry * 32 + q % 32), true)
				i += n
				j += 2
	_nav_dirty = false


func get_minimap_texture() -> Texture2D:
	var m = data.get("minimap")
	if m == null:
		return null
	return _load_tex(_p(str(m["file"])))


## NPCs of this map as [{name, kind, template, world: Vector2, mini: Vector2}] (mini = pixel on minimap.jpg).
func minimap_npcs() -> Array:
	var out := []
	if data.get("minimap") == null:
		return out
	for n in npcs:
		var w := Vector2(float(n["px"]), float(n["py"]))
		out.append({"name": str(n.get("name_vi", n.get("name", ""))), "kind": int(n.get("kind", 0)), "template": int(n.get("t", 0)),
				"world": w, "mini": world_to_minimap(w)})
	return out


## Position of a world point (absolute map pixels) on minimap.jpg, in minimap pixels.
func world_to_minimap(p: Vector2) -> Vector2:
	var m = data["minimap"]
	var k := float(m["px_per_region"]) / 512.0
	return Vector2(p.x - float(m["min_x"]) * 512.0, p.y - float(m["min_y"]) * 512.0) * k


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell.x), floori(p.y / cell.y))


func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * cell + cell * 0.5


## Smart path: A* over the obstacle grid, then straightened ("string pulling") so the character walks in straight lines
## instead of a zig-zag along cell centres. Starts exactly where the character stands, ends exactly where you clicked.
## A blocked or out-of-grid target goes to the nearest walkable cell. Returns an empty array when nothing is reachable.
func find_path(from_world: Vector2, to_world: Vector2, smooth: bool = true) -> PackedVector2Array:
	var a = _nearest_free(world_to_cell(from_world), 6)
	var b = _nearest_free(world_to_cell(to_world), 12)
	if a == null or b == null:
		return PackedVector2Array()
	var ids: Array[Vector2i] = grid.get_id_path(a, b)
	if ids.is_empty():
		return PackedVector2Array()
	var pts := PackedVector2Array()
	pts.append(from_world)
	for i in range(1, ids.size()):
		pts.append(cell_to_world(ids[i]))
	if world_to_cell(to_world) == b:
		if pts.size() == 1:
			pts.append(to_world)
		else:
			pts[pts.size() - 1] = to_world
	return _pull_string(pts) if smooth else pts


func _nearest_free(c: Vector2i, max_ring: int) -> Variant:
	if grid.is_in_boundsv(c) and not grid.is_point_solid(c):
		return c
	for ring in range(1, max_ring + 1):
		var best = null
		var bd := INF
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var cc := c + Vector2i(dx, dy)
				if grid.is_in_boundsv(cc) and not grid.is_point_solid(cc):
					var d := float(dx * dx + dy * dy)
					if d < bd:
						bd = d
						best = cc
		if best != null:
			return best
	return null


## true when a straight walk from p to q stays on walkable cells with a little room on both sides
func segment_clear(p: Vector2, q: Vector2) -> bool:
	var seg_len := Vector2(q.x - p.x, (q.y - p.y) * 2.0).length()     # the scene is 2x taller than the screen: measure in scene units
	var n := maxi(1, ceili(seg_len / 6.0))
	for i in n + 1:
		var w := p.lerp(q, float(i) / float(n))
		if is_blocked(w) or is_blocked(w + Vector2(-5, 0)) or is_blocked(w + Vector2(5, 0)) or is_blocked(w + Vector2(0, -2.5)) or is_blocked(w + Vector2(0, 2.5)):
			return false
	return true


func _pull_string(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not segment_clear(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


## Move `pos` along `path` by `dist` scene units (speed * delta). Returns [new_pos, remaining_path, direction].
## Distances are measured in scene units (y counts double), so walking up/down is as fast as walking sideways.
func walk_step(pos: Vector2, path: PackedVector2Array, dist: float) -> Array:
	var dir := Vector2.ZERO
	while dist > 0.0 and path.size() > 0:
		var d := Vector2(path[0].x - pos.x, (path[0].y - pos.y) * 2.0)
		var step_len := d.length()
		if step_len <= dist:
			pos = path[0]
			path.remove_at(0)
			dist -= step_len
		else:
			pos += Vector2(d.x, d.y * 0.5) * (dist / step_len)
			dist = 0.0
		if step_len > 0.001:
			dir = d / step_len
	return [pos, path, dir]


func is_blocked(world_pos: Vector2) -> bool:
	var c := world_to_cell(world_pos)
	if chunk_mode:                          # any loaded region, also outside the path-finding window
		var rx := floori(c.x / 16.0)
		var ry := floori(c.y / 32.0)
		var ob = _obs.get("%d,%d" % [rx, ry])
		if ob == null:
			return true                     # not loaded / outside the map
		if (ob as PackedByteArray).is_empty():
			return false
		return ((ob as PackedByteArray)[(c.x - rx * 16) * 32 + (c.y - ry * 32)] >> 4) != 0
	return grid.is_in_boundsv(c) and grid.is_point_solid(c)


## Ô nhảy qua được (sông suối / hào nước / tường thấp: kind 3/4 hoặc không bị chặn).
func is_jumpable(world_pos: Vector2) -> bool:
	var c := world_to_cell(world_pos)
	if chunk_mode:
		var rx := floori(c.x / 16.0)
		var ry := floori(c.y / 32.0)
		var ob = _obs.get("%d,%d" % [rx, ry])
		if ob == null:
			return false
		if (ob as PackedByteArray).is_empty():
			return true
		var val: int = (ob as PackedByteArray)[(c.x - rx * 16) * 32 + (c.y - ry * 32)]
		return (val >> 4) == 0 or (val & 0x0f) in [3, 4]
	return grid.is_in_boundsv(c) and not grid.is_point_solid(c)


func trap_at(world_pos: Vector2) -> int:
	return int(traps.get(world_to_cell(world_pos), 0))

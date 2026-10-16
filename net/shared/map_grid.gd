class_name MapGrid
extends RefCounted
## Lưới vật cản của map đọc thẳng từ map.json — KHÔNG nạp ảnh nào, dùng được trên game server headless.
## Map chia khối (map.json "format": "chunks"): vật cản đọc từ chunks/*.json.gz, danh sách quái/NPC từ spawns.json.gz
## (gán vào data["npcs"] như map cũ để game_server dùng y hệt).
## Cùng quy ước với VltkMap: ô 32x16 px, ô bị chặn khi (giá trị >> 4) != 0; kind (4 bit thấp) 3/4 = nhảy qua được.

const CELL := Vector2(32, 16)
const REGION := 512

var data: Dictionary = {}
var origin := Vector2i.ZERO        ## ô đầu tiên (toạ độ ô)
var cols := 0
var rows := 0
var _cells := PackedByteArray()    ## giá trị gốc từng ô (0 = đi được)
var _map_dir := ""
var _regions := {}                 ## map chia khối: Vector2i(rx, ry) -> PackedByteArray(512) giá trị ô của vùng (chỉ số cx * 32 + cy)

static func load_from(map_dir: String) -> MapGrid:
	var path := map_dir.path_join("map.json")
	if not FileAccess.file_exists(path):
		push_error("MapGrid: không thấy " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("MapGrid: map.json hỏng")
		return null
	var g := MapGrid.new()
	g.data = parsed
	g._map_dir = map_dir
	if str(parsed.get("format", "")) == "chunks":
		var sp: Variant = _read_gz_json(map_dir.path_join(str(parsed.get("spawns", "spawns.json.gz"))))
		g.data["npcs"] = sp if sp is Array else []
	g._build()
	return g

static func _read_gz_json(path: String) -> Variant:
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.is_empty():
		return null
	return JSON.parse_string(raw.decompress_dynamic(1 << 30, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())

func _build() -> void:
	var minx := int(data["min_x"])
	var miny := int(data["min_y"])
	origin = Vector2i(minx * 16, miny * 32)
	cols = (int(data["max_x"]) - minx + 1) * 16
	rows = (int(data["max_y"]) - miny + 1) * 32
	if str(data.get("format", "")) == "chunks":
		_build_chunks()             ## map lớn: không cấp cả lưới cols * rows (hàng trăm triệu ô) mà giữ từng vùng
		return
	_cells.resize(cols * rows)
	for key in data["obstacle"]:
		var p: PackedStringArray = str(key).split(",")
		var ox := int(p[0]) * 16 - origin.x
		var oy := int(p[1]) * 32 - origin.y
		var arr: Array = data["obstacle"][key]
		for cx in 16:
			for cy in 32:
				var v := int(arr[cx * 32 + cy])
				if v != 0:
					_cells[(oy + cy) * cols + ox + cx] = v & 0xff

## Map chia khối: vật cản từng vùng giải nén từ RLE [giá trị, số ô, ...] bằng các mảng byte cắt sẵn (nhanh, không lặp từng ô).
func _build_chunks() -> void:
	var fills := {}
	for key in data.get("chunks", {}):
		var p: PackedStringArray = str(key).split(",")
		var doc: Variant = _read_gz_json(_map_dir.path_join("chunks/%s_%s.json.gz" % [p[0], p[1]]))
		if not (doc is Dictionary and doc.has("r")):
			push_error("MapGrid: khối %s hỏng / thiếu" % key)
			continue
		var regs: Dictionary = doc["r"]
		for rk in regs:
			var rp: PackedStringArray = str(rk).split(",")
			var runs: Array = (regs[rk] as Dictionary).get("ob", [])
			var arr := PackedByteArray()
			var j := 0
			while j + 1 < runs.size():
				var v := int(runs[j]) & 0xff
				if not fills.has(v):
					var f := PackedByteArray()
					f.resize(512)
					f.fill(v)
					fills[v] = f
				arr.append_array((fills[v] as PackedByteArray).slice(0, int(runs[j + 1])))
				j += 2
			arr.resize(512)
			_regions[Vector2i(int(rp[0]), int(rp[1]))] = arr

func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL.x), floori(p.y / CELL.y))

func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL + CELL * 0.5

func _value(c: Vector2i) -> int:
	if not _regions.is_empty():
		var rx := floori(c.x / 16.0)
		var ry := floori(c.y / 32.0)
		var arr: Variant = _regions.get(Vector2i(rx, ry))
		if arr == null:
			return 0xff   ## ngoài map = chặn
		return (arr as PackedByteArray)[(c.x - rx * 16) * 32 + (c.y - ry * 32)]
	var x := c.x - origin.x
	var y := c.y - origin.y
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return 0xff   ## ngoài map = chặn
	return _cells[y * cols + x]

func is_blocked(world: Vector2) -> bool:
	return (_value(world_to_cell(world)) >> 4) != 0

## Ô nhảy qua được (vật cản thấp: kind 3/4).
func is_jumpable(world: Vector2) -> bool:
	var v := _value(world_to_cell(world))
	return (v >> 4) == 0 or (v & 0x0f) in [3, 4]

func in_bounds(world: Vector2) -> bool:
	var c := world_to_cell(world) - origin
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

## Điểm xuất phát mặc định: giữa vùng có nền gần tâm map (giống VltkWorld._default_center).
func default_center() -> Vector2:
	if data.has("start"):
		return (Vector2(float(data["start"][0]), float(data["start"][1])) + Vector2(0.5, 0.5)) * REGION
	var rect: Array = data.get("rect", [0, 0, 1, 1])
	var center := Vector2((float(rect[0]) + float(rect[2]) + 1.0) * 0.5, (float(rect[1]) + float(rect[3]) + 1.0) * 0.5) * REGION
	var best := center
	var best_d := INF
	for r in data["regions"]:
		if int(r[2]) != 1:
			continue
		var c := Vector2(int(r[0]) + 0.5, int(r[1]) + 0.5) * REGION
		var d := c.distance_squared_to(center)
		if d < best_d:
			best_d = d
			best = c
	return best

## Ô trống gần `point` (5x5 ô quanh đều đi được) — chỗ đặt nhân vật / quái.
func free_near(point: Vector2, max_radius := 80) -> Vector2:
	var start := world_to_cell(point)
	for radius in max_radius:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := start + Vector2i(dx, dy)
				if _clear_around(c):
					return cell_to_world(c)
	return point

## Chỗ xuất hiện "thông thoáng" gần `point`: ô trống (cả 5x5 ô quanh đều trống) mà từ đó đi được ra một vùng rộng — tránh đặt nhân vật
## vào "ốc đảo" bị vật cản bao kín (VD khối đá giữa map Đại Lý phủ: ô trống gần tâm nhất chỉ thông ra ~1.500 ô).
func open_spawn_near(point: Vector2) -> Vector2:
	var c := MapGrid.find_open_cell(world_to_cell(point), func(cell: Vector2i) -> bool: return (_value(cell) >> 4) == 0)
	return cell_to_world(c) if c != Vector2i(-1, -1) else free_near(point)

## Đứng ở `point` có đi ra được vùng rộng không (false = kẹt trong "ốc đảo" bị vật cản bao kín).
func is_open_area(point: Vector2) -> bool:
	var c := world_to_cell(point)
	var is_free := func(cell: Vector2i) -> bool: return (_value(cell) >> 4) == 0
	return is_free.call(c) and MapGrid._flood(c, is_free, {}) >= OPEN_AREA_CELLS

## Số ô đi được tối thiểu để coi là vùng thông thoáng (loang tới đủ chừng này thì dừng — chi phí giới hạn).
const OPEN_AREA_CELLS := 6000
const OPEN_MAX_POCKETS := 40

## Dùng chung server (MapGrid) và game (VltkMap): duyệt xoắn ốc quanh `start`, mỗi ô trống 5x5 chưa thuộc vùng đã loang thì loang (4 hướng)
## đếm số ô đi tới được; vùng đầu tiên đủ OPEN_AREA_CELLS thì nhận, không có thì lấy vùng rộng nhất đã thử. (-1, -1) nếu không có ô nào.
static func find_open_cell(start: Vector2i, is_free: Callable, max_radius := 120) -> Vector2i:
	var visited := {}
	var best := Vector2i(-1, -1)
	var best_n := -1
	var pockets := 0
	for radius in max_radius:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := start + Vector2i(dx, dy)
				if visited.has(c) or not _clear5(c, is_free):
					continue
				var n := _flood(c, is_free, visited)
				if n >= OPEN_AREA_CELLS:
					return c
				if n > best_n:
					best_n = n
					best = c
				pockets += 1
				if pockets >= OPEN_MAX_POCKETS:
					return best
	return best

static func _clear5(c: Vector2i, is_free: Callable) -> bool:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if not is_free.call(c + Vector2i(dx, dy)):
				return false
	return true

static func _flood(start: Vector2i, is_free: Callable, visited: Dictionary) -> int:
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var n := 0
	while not queue.is_empty() and n < OPEN_AREA_CELLS:
		var cur: Vector2i = queue.pop_back()
		n += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb := cur + d
			if not visited.has(nb) and is_free.call(nb):
				visited[nb] = true
				queue.append(nb)
	return n

func _clear_around(c: Vector2i) -> bool:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if (_value(c + Vector2i(dx, dy)) >> 4) != 0:
				return false
	return true

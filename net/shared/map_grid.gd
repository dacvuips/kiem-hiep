class_name MapGrid
extends RefCounted
## Lưới vật cản của map đọc thẳng từ map.json — KHÔNG nạp ảnh nào, dùng được trên game server headless.
## Cùng quy ước với VltkMap: ô 32x16 px, ô bị chặn khi (giá trị >> 4) != 0; kind (4 bit thấp) 3/4 = nhảy qua được.

const CELL := Vector2(32, 16)
const REGION := 512

var data: Dictionary = {}
var origin := Vector2i.ZERO        ## ô đầu tiên (toạ độ ô)
var cols := 0
var rows := 0
var _cells := PackedByteArray()    ## giá trị gốc từng ô (0 = đi được)

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
	g._build()
	return g

func _build() -> void:
	var minx := int(data["min_x"])
	var miny := int(data["min_y"])
	origin = Vector2i(minx * 16, miny * 32)
	cols = (int(data["max_x"]) - minx + 1) * 16
	rows = (int(data["max_y"]) - miny + 1) * 32
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

func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL.x), floori(p.y / CELL.y))

func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL + CELL * 0.5

func _value(c: Vector2i) -> int:
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

func _clear_around(c: Vector2i) -> bool:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if (_value(c + Vector2i(dx, dy)) >> 4) != 0:
				return false
	return true

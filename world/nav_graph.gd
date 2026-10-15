extends RefCounted
class_name NavGraph
## Tìm đường TẦNG THÔ trên toàn map chia khối (đồ thị do tools/build_nav_graph.py dựng: world/main_map/nav_graph.bin).
## Mỗi nút = 1 "mảng đất liền" trong 1 vùng 512x512 px, cạnh = 2 mảng ở 2 vùng kề nhau đi thông qua mép vùng. A* trên đồ thị tìm được
## đường vòng khắp map (vòng xa, đi ngược...) — VltkWorld.find_path dùng A* ô lưới quanh nhân vật để đi lần lượt qua các nút này.
## Dựng AStar2D (~200 nghìn nút) ở LUỒNG PHỤ ngay khi vào map; chưa dựng xong thì is_ready() = false (tìm đường chỉ trong lưới gần).

const FILE := "nav_graph.bin"
const REGION_COLS := 16
const REGION_ROWS := 32

var _astar := AStar2D.new()
var _cells := PackedInt32Array()          ## ô đại diện (toạ độ ô map) của từng nút: x, y xen kẽ
var _by_region := {}                      ## Vector2i vùng -> PackedInt32Array id nút
var _cell := Vector2(32, 16)
var _built := false
var _thread: Thread

## Nạp + dựng ở luồng phụ. null nếu map không có file đồ thị (map nhỏ không chia khối: lưới A* đã phủ cả map).
static func load_for(map_dir: String, cell: Vector2) -> NavGraph:
	var path := map_dir.path_join(FILE)
	if not FileAccess.file_exists(path):
		return null
	var g := NavGraph.new()
	g._cell = cell
	g._thread = Thread.new()
	g._thread.start(g._build.bind(path))
	return g

func is_ready() -> bool:
	if _thread != null and not _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
	return _built and _thread == null

func _build(path: String) -> void:
	var raw := FileAccess.get_file_as_bytes(path).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if raw.size() < 16 or raw.slice(0, 4).get_string_from_ascii() != "NAVG":
		push_warning("NavGraph: file hỏng %s" % path)
		return
	var n := raw.decode_u32(8)
	var m := raw.decode_u32(12)
	var nodes := raw.slice(16, 16 + n * 4).to_int32_array()
	var edges := raw.slice(16 + n * 4, 16 + n * 4 + m * 8).to_int32_array()
	_astar.reserve_space(n)
	_cells.resize(n * 2)
	for i in n:
		var v := nodes[i]
		var rx := v & 0x3ff
		var ry := (v >> 10) & 0x7ff
		var cx := rx * REGION_COLS + ((v >> 21) & 0xf)
		var cy := ry * REGION_ROWS + ((v >> 25) & 0x1f)
		_cells[i * 2] = cx
		_cells[i * 2 + 1] = cy
		_astar.add_point(i, (Vector2(cx, cy) + Vector2(0.5, 0.5)) * _cell)
		var key := Vector2i(rx, ry)
		var list: PackedInt32Array = _by_region.get(key, PackedInt32Array())
		list.append(i)
		_by_region[key] = list
	for j in m:
		_astar.connect_points(edges[j * 2], edges[j * 2 + 1])
	_built = true

## Ô đại diện (toạ độ ô map) của nút `id`.
func node_cell(id: int) -> Vector2i:
	return Vector2i(_cells[id * 2], _cells[id * 2 + 1])

func node_position(id: int) -> Vector2:
	return _astar.get_point_position(id)

## Nút của mảng đất chứa ô `cell`. `region_free` = các ô (Vector2i) đi tới được từ `cell` trong cùng vùng (loang trên lưới gần); rỗng = không
## biết (vùng ngoài lưới gần) -> lấy nút gần nhất trong vùng / quanh vùng.
func node_at(cell: Vector2i, region_free: Dictionary = {}) -> int:
	var r := Vector2i(floori(float(cell.x) / REGION_COLS), floori(float(cell.y) / REGION_ROWS))
	var ids: PackedInt32Array = _by_region.get(r, PackedInt32Array())
	if not region_free.is_empty():
		for id in ids:
			if region_free.has(node_cell(id)):
				return id
	var p := (Vector2(cell) + Vector2(0.5, 0.5)) * _cell
	if not ids.is_empty():
		var best := -1
		var best_d := INF
		for id in ids:
			var d := _astar.get_point_position(id).distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = id
		return best
	return _astar.get_closest_point(p)

## Lộ trình thô: id các nút từ `a` tới `b`. Không tới được (2 khu bị chia cắt) thì tới nút gần `b` nhất có thể.
func route(a: int, b: int) -> PackedInt64Array:
	if a < 0 or b < 0:
		return PackedInt64Array()
	return _astar.get_id_path(a, b, true)

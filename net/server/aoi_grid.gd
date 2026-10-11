class_name AoiGrid
extends RefCounted
## Lưới tầm nhìn (Area Of Interest): chia map thành ô NetProto.AOI_CELL px. Mỗi người chơi chỉ nhận thực thể trong 3x3 ô
## quanh mình -> băng thông không tăng theo tổng số người trên map, chỉ theo mật độ quanh từng người.
## Sau này chia map cho nhiều server (chia vùng) cũng dùng lại lưới này cho dải biên.

var _cells: Dictionary = {}   ## Vector2i -> Dictionary(eid -> ServerEntity)

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / NetProto.AOI_CELL), floori(p.y / NetProto.AOI_CELL))

## Gọi sau khi entity.pos đổi (hoặc lần đầu thêm vào).
func update(e: ServerEntity) -> void:
	var c := cell_of(e.pos)
	if c == e.cell:
		return
	remove(e)
	e.cell = c
	if not _cells.has(c):
		_cells[c] = {}
	_cells[c][e.eid] = e

func remove(e: ServerEntity) -> void:
	if _cells.has(e.cell):
		var bucket: Dictionary = _cells[e.cell]
		bucket.erase(e.eid)
		if bucket.is_empty():
			_cells.erase(e.cell)
	e.cell = Vector2i(1 << 30, 1 << 30)

## Mọi thực thể trong 3x3 ô quanh `p`.
func around(p: Vector2) -> Array[ServerEntity]:
	var out: Array[ServerEntity] = []
	var c := cell_of(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var bucket: Dictionary = _cells.get(c + Vector2i(dx, dy), {})
			for e: ServerEntity in bucket.values():
				out.append(e)
	return out

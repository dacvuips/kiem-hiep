class_name AoiGrid
extends RefCounted
## Lưới tầm nhìn (Area Of Interest): chia map thành ô NetProto.AOI_CELL px. Mỗi người chơi chỉ nhận thực thể trong 3x3 ô
## quanh mình -> băng thông không tăng theo tổng số người trên map, chỉ theo mật độ quanh từng người.
## Sau này chia map cho nhiều server (chia vùng) cũng dùng lại lưới này cho dải biên.

var _cells: Dictionary = {}   ## Vector2i -> Dictionary(eid -> ServerEntity)
## Chỉ NGƯỜI CHƠI theo ô (cùng ô với _cells) — quái tìm mục tiêu (GameServer.nearest_player) duyệt vài người thay vì hàng trăm quái.
var _players: Dictionary = {} ## Vector2i -> Dictionary(eid -> ServerEntity)
## Biến động từ lượt gửi trước (GameServer._send_snapshots đọc rồi xoá): ô -> các thực thể vừa vào / eid vừa rời ô đó.
var entered: Dictionary = {}  ## Vector2i -> Array[ServerEntity]
var left: Dictionary = {}     ## Vector2i -> Array[int]

## `base` = vùng ô của phòng (ServerEntity.cell_base; 0 = map chính).
func cell_of(p: Vector2, base := Vector2i.ZERO) -> Vector2i:
	return Vector2i(floori(p.x / NetProto.AOI_CELL), floori(p.y / NetProto.AOI_CELL)) + base

## Gọi sau khi entity.pos đổi (hoặc lần đầu thêm vào).
func update(e: ServerEntity) -> void:
	var c := cell_of(e.pos, e.cell_base)
	if c == e.cell:
		return
	remove(e)
	e.cell = c
	if not _cells.has(c):
		_cells[c] = {}
	_cells[c][e.eid] = e
	if e.kind == NetProto.KIND_PLAYER:
		if not _players.has(c):
			_players[c] = {}
		_players[c][e.eid] = e
	if not entered.has(c):
		entered[c] = []
	entered[c].append(e)

func remove(e: ServerEntity) -> void:
	if _cells.has(e.cell):
		var bucket: Dictionary = _cells[e.cell]
		bucket.erase(e.eid)
		if bucket.is_empty():
			_cells.erase(e.cell)
		if e.kind == NetProto.KIND_PLAYER and _players.has(e.cell):
			var pb: Dictionary = _players[e.cell]
			pb.erase(e.eid)
			if pb.is_empty():
				_players.erase(e.cell)
		if not left.has(e.cell):
			left[e.cell] = []
		left[e.cell].append(e.eid)
	e.cell = Vector2i(1 << 30, 1 << 30)

## Chỉ người chơi trong 1 ô (eid -> ServerEntity); không được sửa dict trả về.
func player_bucket(c: Vector2i) -> Dictionary:
	return _players.get(c, _EMPTY)

## Các thực thể trong 1 ô (eid -> ServerEntity); không được sửa dict trả về.
func bucket(c: Vector2i) -> Dictionary:
	return _cells.get(c, _EMPTY)

const _EMPTY := {}
const _NONE := []

func entered_in(c: Vector2i) -> Array:
	return entered.get(c, _NONE)

func left_from(c: Vector2i) -> Array:
	return left.get(c, _NONE)

## Mọi thực thể trong 3x3 ô quanh `p` (trong vùng ô `base` của phòng).
func around(p: Vector2, base := Vector2i.ZERO) -> Array[ServerEntity]:
	var out: Array[ServerEntity] = []
	var c := cell_of(p, base)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var bucket: Dictionary = _cells.get(c + Vector2i(dx, dy), {})
			for e: ServerEntity in bucket.values():
				out.append(e)
	return out

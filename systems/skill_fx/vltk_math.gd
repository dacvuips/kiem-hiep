extends RefCounted
class_name VltkMath
## Hệ toạ độ / hướng / nhịp của VLTK gốc (KMath.h, KSubWorld, KRepresentShell2) dùng cho bộ máy chiêu skill_fx.
##
## - Toạ độ LOGIC (Mps): x = x màn hình, y = 2 × y màn hình (ViewPortCoordToSpaceCoord: nY = (nY + top + Z*887/1024)*2)
##   -> tốc độ đạn, tầm, ô va chạm đều tính trên toạ độ logic; đạn bay dọc trông chậm bằng nửa bay ngang như bản gốc.
## - Ô logic 32 × 32 (defLOGIC_CELL), 64 hướng (MaxMissleDir): 0 = xuống, 16 = trái, 32 = lên, 48 = phải (chiều kim
##   đồng hồ — g_GetNewDirIndex); g_DirCos/g_DirSin nhân 1024.
## - Logic chạy 18 nhịp/giây (GAME_FPS).

const MAX_DIR := 64
const CELL := 32
const FPS := 18.0
const TICK := 1.0 / FPS
## Độ cao Z (pixel logic) -> lệch lên trên màn hình: Z * 887 / 1024.
const Z_SCREEN := 887.0 / 1024.0

static var _cos: PackedInt32Array = _make_table(true)
static var _sin: PackedInt32Array = _make_table(false)

static func _make_table(is_cos: bool) -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(MAX_DIR)
	for d in MAX_DIR:
		var a := TAU * d / MAX_DIR
		## Hướng d: dx = -sin(a), dy = cos(a) (0 = xuống, 16 = trái...).
		t[d] = roundi((-sin(a) if is_cos else cos(a)) * 1024.0)
	return t

static func dir_cos(dir: int) -> int:
	return _cos[wrapi(dir, 0, MAX_DIR)]

static func dir_sin(dir: int) -> int:
	return _sin[wrapi(dir, 0, MAX_DIR)]

static func to_logic(world: Vector2) -> Vector2:
	return Vector2(world.x, world.y * 2.0)

static func to_world(logic: Vector2) -> Vector2:
	return Vector2(logic.x, logic.y * 0.5)

## Vị trí CHÂN của nhân vật (toạ độ gốc của NPC VLTK là điểm đứng) — node có get_ground_position() (Player: chân
## avatar) thì dùng, không thì global_position.
static func ground_of(node: Node2D) -> Vector2:
	return node.get_ground_position() if node.has_method("get_ground_position") else node.global_position

static func logic_of(node: Node2D) -> Vector2:
	return to_logic(ground_of(node))

## g_GetDirIndex: hướng 0..63 từ src tới des (toạ độ logic); -1 nếu trùng điểm.
static func dir_between(src: Vector2, des: Vector2) -> int:
	var d := des - src
	if d.is_zero_approx():
		return -1
	return wrapi(roundi(atan2(-d.x, d.y) / TAU * MAX_DIR), 0, MAX_DIR)

## Ô logic chứa điểm.
static func cell_of(logic: Vector2) -> Vector2i:
	return Vector2i(floori(logic.x / CELL), floori(logic.y / CELL))

## Hướng ảnh trong sprite có `spr_dirs` hướng (KMissleRes::Draw / KSkillSpecial::Draw: làm tròn tới hướng gần nhất).
static func image_dir(dir: int, spr_dirs: int) -> int:
	if spr_dirs <= 1:
		return 0
	var step := MAX_DIR / spr_dirs
	var d := dir / step
	if dir % step >= 32 / spr_dirs:
		d += 1
	return 0 if d >= spr_dirs else d

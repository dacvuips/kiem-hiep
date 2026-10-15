extends RefCounted
class_name Nation
## PHE TỐNG / KIM TRONG TRẬN Chiến trường Tống Kim (chọn lúc báo danh, BattleServer.nation_of) — nhân vật KHÔNG có phe
## Tống / Kim cố định. KHÁC Camp (màu tên Chính/Tà/Trung, đổi theo phái / bang / PK).

enum Type { NONE, SONG, JIN }

const NAMES := { Type.NONE: "Chưa chọn", Type.SONG: "Tống", Type.JIN: "Kim" }
const COLORS := { Type.NONE: Color(0.62, 0.64, 0.62), Type.SONG: Color(0.98, 0.62, 0.30), Type.JIN: Color(0.56, 0.78, 0.95) }

## Hai phe đối địch: cả 2 đã chọn phe và khác nhau (chưa chọn phe thì không tính).
static func is_hostile(a: int, b: int) -> bool:
	return is_valid_choice(a) and is_valid_choice(b) and a != b

## Tên hiện trên đầu nhân vật: đã chọn phe thì thêm "(Tống)" / "(Kim)" sát phía trước.
static func decorate_name(display_name: String, n: int) -> String:
	return "(%s)%s" % [get_nation_name(n), display_name] if is_valid_choice(n) else display_name

static func get_nation_name(n: int) -> String:
	return NAMES.get(n, "?")

static func get_color(n: int) -> Color:
	return COLORS.get(n, Color.WHITE)

static func is_valid_choice(n: int) -> bool:
	return n == Type.SONG or n == Type.JIN

extends RefCounted
class_name PkLobby
## Danh sách PHÒNG PK (popup PK): phòng chờ đánh + phòng đang đánh. Mỗi phòng có ID 6 số để tìm nhanh, có thể đặt mật khẩu.
## Hiện chạy cục bộ (chỉ có phòng của chính mình); online (bước sau) danh sách đến từ server — UI chỉ dùng các hàm dưới đây.
##
## Phòng: {id, mode, host, level, sect_id, sect_name, password, state ("waiting"|"fighting"), guest, created_ms}

const WAITING := "waiting"
const FIGHTING := "fighting"

static var _rooms: Array[Dictionary] = []

static func rooms(mode: PkRules.Mode, state: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in _rooms:
		if int(r["mode"]) == mode and str(r["state"]) == state:
			out.append(r)
	return out

static func find(room_id: String) -> Dictionary:
	for r in _rooms:
		if str(r["id"]) == room_id:
			return r
	return {}

## Mở phòng mới của `profile`; password "" = phòng không khoá.
static func create(profile: PlayerProfile, mode: PkRules.Mode, password: String) -> Dictionary:
	close_own(profile)
	var sect := SectRegistry.get_by_id(profile.sect_id)
	var room := {"id": _new_id(), "mode": mode, "host": profile.display_name, "level": profile.level,
		"sect_id": profile.sect_id, "sect_name": sect.sect_name if sect else "Vô môn phái", "password": password,
		"state": WAITING, "guest": "", "created_ms": Time.get_ticks_msec()}
	_rooms.append(room)
	return room

static func close(room_id: String) -> void:
	_rooms = _rooms.filter(func(r: Dictionary) -> bool: return str(r["id"]) != room_id)

## Đóng phòng mình đang mở (mỗi người 1 phòng).
static func close_own(profile: PlayerProfile) -> void:
	if profile:
		_rooms = _rooms.filter(func(r: Dictionary) -> bool: return str(r["host"]) != profile.display_name)

## Phòng chờ hợp với người tìm trận (không khoá, chênh cấp / cùng phái theo PkRules.can_match), không phải phòng của chính mình.
static func find_match(profile: PlayerProfile, mode: PkRules.Mode) -> Dictionary:
	for r in rooms(mode, WAITING):
		if str(r["host"]) == profile.display_name or str(r["password"]) != "":
			continue
		if PkRules.can_match(mode, profile.level, profile.sect_id, int(r["level"]), str(r["sect_id"])):
			return r
	return {}

static func set_fighting(room_id: String, guest: String) -> void:
	var r := find(room_id)
	if not r.is_empty():
		r["state"] = FIGHTING
		r["guest"] = guest

static func _new_id() -> String:
	var id := ""
	while id == "" or not find(id).is_empty():
		id = "%06d" % randi_range(100000, 999999)
	return id

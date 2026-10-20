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

## Mở phòng mới của `profile`; password "" = phòng không khoá; team_size 1..8 (mặc định 1).
static func create(profile: PlayerProfile, mode: PkRules.Mode, password: String, team_size: int = 1) -> Dictionary:
	close_own(profile)
	var sect := SectRegistry.get_by_id(profile.sect_id)
	var s_size := clampi(team_size, 1, 8) if mode == PkRules.Mode.THACH_DAU else 1
	var host_member := {
		"name": profile.display_name,
		"level": profile.level,
		"sect_id": profile.sect_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"ready": true,
		"is_host": true
	}
	var room := {"id": _new_id(), "mode": mode, "team_size": s_size, "host": profile.display_name, "level": profile.level,
		"sect_id": profile.sect_id, "sect_name": sect.sect_name if sect else "Vô môn phái", "password": password,
		"state": WAITING, "team_a": [host_member], "team_b": [], "guest": "", "created_ms": Time.get_ticks_msec()}
	_rooms.append(room)
	return room

## Vào slot của Đội A ("a") hoặc Đội B ("b").
static func join_team(room_id: String, profile: PlayerProfile, target_team: String) -> bool:
	var r := find(room_id)
	if r.is_empty() or r["state"] != WAITING:
		return false
	var team_size: int = int(r.get("team_size", 1))
	var key := "team_a" if target_team == "a" else "team_b"
	var other_key := "team_b" if target_team == "a" else "team_a"
	var list: Array = r.get(key, [])
	var other_list: Array = r.get(other_key, [])
	# Bỏ khỏi phe cũ nếu đang ở trong phòng
	r[other_key] = other_list.filter(func(m: Dictionary) -> bool: return str(m.get("name", "")) != profile.display_name)
	list = list.filter(func(m: Dictionary) -> bool: return str(m.get("name", "")) != profile.display_name)
	if list.size() >= team_size:
		return false
	var sect := SectRegistry.get_by_id(profile.sect_id)
	var member := {
		"name": profile.display_name,
		"level": profile.level,
		"sect_id": profile.sect_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"ready": str(r.get("host", "")) == profile.display_name,
		"is_host": str(r.get("host", "")) == profile.display_name
	}
	list.append(member)
	r[key] = list
	return true

## Bỏ người chơi khỏi phòng.
static func leave_room(room_id: String, player_name: String) -> void:
	var r := find(room_id)
	if r.is_empty():
		return
	if str(r.get("host", "")) == player_name:
		close(room_id)
		return
	for k in ["team_a", "team_b"]:
		var arr: Array = r.get(k, [])
		r[k] = arr.filter(func(m: Dictionary) -> bool: return str(m.get("name", "")) != player_name)

## Chủ phòng đá 1 người khỏi phòng.
static func kick_member(room_id: String, target_name: String) -> bool:
	var r := find(room_id)
	if r.is_empty():
		return false
	for k in ["team_a", "team_b"]:
		var arr: Array = r.get(k, [])
		r[k] = arr.filter(func(m: Dictionary) -> bool: return str(m.get("name", "")) != target_name)
	return true

## Chuyển trạng thái Sẵn sàng của thành viên.
static func toggle_ready(room_id: String, player_name: String) -> bool:
	var r := find(room_id)
	if r.is_empty():
		return false
	for k in ["team_a", "team_b"]:
		for m: Dictionary in r.get(k, []):
			if str(m.get("name", "")) == player_name:
				m["ready"] = not bool(m.get("ready", false))
				return bool(m["ready"])
	return false

## Thêm bot vào 1 phe (cho mục đích test offline).
static func add_bot(room_id: String, target_team: String, level: int = 90) -> bool:
	var r := find(room_id)
	if r.is_empty():
		return false
	var team_size: int = int(r.get("team_size", 1))
	var key := "team_a" if target_team == "a" else "team_b"
	var list: Array = r.get(key, [])
	if list.size() >= team_size:
		return false
	var bot := PkBotProfile.create(level)
	var sect := SectRegistry.get_by_id(bot.sect_id)
	list.append({
		"name": bot.display_name,
		"level": bot.level,
		"sect_id": bot.sect_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"ready": true,
		"is_host": false,
		"is_bot": true,
		"bot_data": bot.to_dict()
	})
	r[key] = list
	return true

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

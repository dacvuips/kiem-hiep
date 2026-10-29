extends RefCounted
class_name PkLobby

const PkStakeSession = preload("res://systems/pk/pk_stake_session.gd")
## Danh sách PHÒNG PK (popup PK): phòng chờ đánh + phòng đang đánh. Mỗi phòng có ID 6 số để tìm nhanh, có thể đặt mật khẩu.
## Hiện chạy cục bộ (chỉ có phòng của chính mình); online (bước sau) danh sách đến từ server — UI chỉ dùng các hàm dưới đây.
##
## Phòng: {id, mode, host, level, sect_id, sect_name, password, state ("waiting"|"fighting"), guest, created_ms}

const WAITING := "waiting"
const FIGHTING := "fighting"

static var _rooms: Array[Dictionary] = []

static func rooms(mode: int = -1, state: String = "") -> Array[Dictionary]:
	init_sample_rooms()
	var out: Array[Dictionary] = []
	for r in _rooms:
		if mode >= 0 and int(r.get("mode", -1)) != mode:
			continue
		if state != "" and str(r.get("state", "")) != state:
			continue
		out.append(r)
	return out

static func find(room_id: String) -> Dictionary:
	init_sample_rooms()
	for r in _rooms:
		if str(r["id"]) == room_id:
			return r
	return {}

## Tìm phòng của chính mình nếu đang mở.
static func find_own(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {}
	for r in _rooms:
		if str(r.get("host", "")) == profile.display_name:
			return r
	return {}

## Khởi tạo danh sách phòng mẫu ban đầu để sảnh luôn sôi động và có phòng để tìm/xem/đấu (chỉ cho Offline).
static func init_sample_rooms() -> void:
	if not _rooms.is_empty():
		return
	# Chế độ Online: Tuyệt đối KHÔNG sinh phòng mẫu chứa Bot
	if GameModeManager.is_online():
		return
	var samples: Array[Dictionary] = [
		{
			"id": "108392",
			"mode": PkRules.Mode.DAI_HOI,
			"team_size": 1,
			"host": "Độc Cô Tuyệt",
			"level": 92,
			"sect_id": "thieu_lam",
			"sect_name": "Thiếu Lâm",
			"password": "",
			"state": WAITING,
			"team_a": [{"name": "Độc Cô Tuyệt", "level": 92, "sect_id": "thieu_lam", "sect_name": "Thiếu Lâm", "ready": true, "is_host": true}],
			"team_b": [],
			"created_ms": Time.get_ticks_msec() - 120000
		},
		{
			"id": "249105",
			"mode": PkRules.Mode.LIEN_DAU,
			"team_size": 1,
			"host": "Lệnh Hồ Xung",
			"level": 89,
			"sect_id": "hoa_son",
			"sect_name": "Hoa Sơn",
			"password": "",
			"state": FIGHTING,
			"fighters": ["Lệnh Hồ Xung", "Điền Bá Quang"],
			"guest": "Điền Bá Quang",
			"created_ms": Time.get_ticks_msec() - 60000
		},
		{
			"id": "382716",
			"mode": PkRules.Mode.THACH_DAU,
			"team_size": 3,
			"host": "Tiêu Phong",
			"level": 95,
			"sect_id": "cai_bang",
			"sect_name": "Cái Bang",
			"password": "",
			"state": WAITING,
			"team_a": [
				{"name": "Tiêu Phong", "level": 95, "sect_id": "cai_bang", "sect_name": "Cái Bang", "ready": true, "is_host": true},
				{"name": "Hư Trúc", "level": 91, "sect_id": "thieu_lam", "sect_name": "Thiếu Lâm", "ready": true, "is_host": false}
			],
			"team_b": [],
			"created_ms": Time.get_ticks_msec() - 90000
		},
		{
			"id": "471928",
			"mode": PkRules.Mode.LON_XON,
			"team_size": 1,
			"brawl_type": "solo",
			"map_id": 319,
			"target_kills": 20,
			"host": "Quách Tĩnh",
			"level": 90,
			"sect_id": "cai_bang",
			"sect_name": "Cái Bang",
			"password": "",
			"state": WAITING,
			"solo_slots": [
				{"name": "Quách Tĩnh", "level": 90, "sect_id": "cai_bang", "sect_name": "Cái Bang", "ready": true, "is_host": true},
				{"name": "Hoàng Dung", "level": 88, "sect_id": "cai_bang", "sect_name": "Cái Bang", "ready": true, "is_bot": true},
				{"name": "Dương Quá", "level": 92, "sect_id": "co_mo", "sect_name": "Cổ Mộ", "ready": true, "is_bot": true}
			],
			"created_ms": Time.get_ticks_msec() - 150000
		},
		{
			"id": "519284",
			"mode": PkRules.Mode.TONG_KIM_LOL,
			"team_size": 5,
			"host": "Nhạc Phi",
			"level": 96,
			"sect_id": "thien_vuong",
			"sect_name": "Thiên Vương",
			"password": "",
			"state": WAITING,
			"team_a": [
				{"name": "Nhạc Phi", "level": 96, "sect_id": "thien_vuong", "sect_name": "Thiên Vương", "ready": true, "is_host": true},
				{"name": "Nhạc Vân", "level": 90, "sect_id": "thien_vuong", "sect_name": "Thiên Vương", "ready": true, "is_host": false}
			],
			"team_b": [
				{"name": "Ngột Truật", "level": 95, "sect_id": "thien_nhan", "sect_name": "Thiên Nhẫn", "ready": true, "is_host": false}
			],
			"created_ms": Time.get_ticks_msec() - 45000
		},
		{
			"id": "628391",
			"mode": PkRules.Mode.VAN_TIEU,
			"team_size": 5,
			"cart_tier_id": "bronze",
			"cart_name": "🛡️ Tiêu Xa Đồng (Trung Cấp)",
			"host": "Dương Thiết Tâm",
			"level": 85,
			"sect_id": "duong_mon",
			"sect_name": "Đường Môn",
			"password": "",
			"state": WAITING,
			"team_a": [
				{"name": "Dương Thiết Tâm", "level": 85, "sect_id": "duong_mon", "sect_name": "Đường Môn", "ready": true, "is_host": true, "role": "defender"}
			],
			"team_b": [
				{"name": "Hoàn Nhan Hồng Liệt", "level": 88, "sect_id": "thien_nhan", "sect_name": "Thiên Nhẫn", "ready": true, "is_host": false, "role": "bandit"}
			],
			"created_ms": Time.get_ticks_msec() - 30000
		}
	]
	_rooms.append_array(samples)

## Mở phòng mới của `profile`; password "" = phòng không khoá; team_size 1..8 (mặc định 1); extra thông tin mở rộng.
static func create(profile: PlayerProfile, mode: PkRules.Mode, password: String, team_size: int = 1, extra: Dictionary = {}) -> Dictionary:
	close_own(profile)
	var sect := SectRegistry.get_by_id(profile.sect_id)
	var s_size := 5 if mode == PkRules.Mode.VAN_TIEU else (clampi(team_size, 1, 5) if mode == PkRules.Mode.TONG_KIM_LOL else (clampi(team_size, 1, 8) if (mode == PkRules.Mode.THACH_DAU or mode == PkRules.Mode.LON_XON) else 1))
	var role: String = str(extra.get("role", "defender"))
	var host_member := {
		"name": profile.display_name,
		"level": profile.level,
		"sect_id": profile.sect_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"ready": true,
		"is_host": true,
		"role": role
	}
	var brawl_type: String = str(extra.get("brawl_type", "solo")) if mode == PkRules.Mode.LON_XON else ""
	var map_id: int = int(extra.get("map_id", 319))
	var target_kills: int = int(extra.get("target_kills", 20))
	var cart_tier_id: String = str(extra.get("cart_tier_id", "wood"))
	var cart_name: String = str(extra.get("cart_name", "📦 Tiêu Xa Gỗ (Sơ Cấp)"))
	var solo_slots: Array = [host_member] if brawl_type == "solo" else []
	var team_a: Array = []
	var team_b: Array = []
	if mode == PkRules.Mode.VAN_TIEU and role == "bandit":
		team_b.append(host_member)
	elif brawl_type != "solo":
		team_a.append(host_member)

	var stake_session: PkStakeSession = null
	if mode == PkRules.Mode.THACH_DAU:
		stake_session = PkStakeSession.new()
		stake_session.side_a.leader_name = profile.display_name

	var room := {
		"id": _new_id(),
		"mode": mode,
		"team_size": s_size,
		"brawl_type": brawl_type,
		"map_id": map_id,
		"target_kills": target_kills,
		"cart_tier_id": cart_tier_id,
		"cart_name": cart_name,
		"host": profile.display_name,
		"level": profile.level,
		"sect_id": profile.sect_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"password": password,
		"state": WAITING,
		"team_a": team_a,
		"team_b": team_b,
		"solo_slots": solo_slots,
		"guest": "",
		"stake": stake_session,
		"created_ms": Time.get_ticks_msec()
	}
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
	var stake: PkStakeSession = r.get("stake")
	if stake != null:
		if target_team == "b" and (stake.side_b.leader_name == "" or stake.side_b.is_bot):
			stake.side_b.leader_name = profile.display_name
			stake.side_b.is_bot = false
		elif target_team == "a" and stake.side_a.leader_name == "":
			stake.side_a.leader_name = profile.display_name
	return true

## Bỏ người chơi khỏi phòng.
static func leave_room(room_id: String, player_name: String) -> void:
	var r := find(room_id)
	if r.is_empty():
		return
	var stake: PkStakeSession = r.get("stake")
	if stake != null and GameManager.local_profile != null and GameManager.local_profile.display_name == player_name:
		stake.refund_all(GameManager.local_profile, "a")
		stake.refund_all(GameManager.local_profile, "b")
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
	# Chế độ Online: Tuyệt đối cấm tạo hoặc thêm Bot
	if not GameModeManager.can_add_bot():
		return false
	var r := find(room_id)
	if r.is_empty():
		return false
	var bot := PkBotProfile.create(level)
	var sect := SectRegistry.get_by_id(bot.sect_id)
	var bot_dict := {
		"name": bot.display_name,
		"level": bot.level,
		"sect_id": bot.sect_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"ready": true,
		"is_host": false,
		"is_bot": true,
		"bot_data": bot.to_dict()
	}
	if str(r.get("brawl_type", "")) == "solo":
		var solo_slots: Array = r.get("solo_slots", [])
		if solo_slots.size() >= 16:
			return false
		solo_slots.append(bot_dict)
		r["solo_slots"] = solo_slots
		return true

	var team_size: int = int(r.get("team_size", 1))
	var key := "team_a" if target_team == "a" else "team_b"
	var list: Array = r.get(key, [])
	if list.size() >= team_size:
		return false
	list.append(bot_dict)
	r[key] = list
	var stake: PkStakeSession = r.get("stake")
	if stake != null and target_team == "b" and stake.side_b.leader_name == "":
		stake.side_b.leader_name = bot.display_name
		stake.side_b.is_bot = true
	return true

static func close(room_id: String) -> void:
	var r := find(room_id)
	if not r.is_empty():
		var stake: PkStakeSession = r.get("stake")
		if stake != null and GameManager.local_profile != null:
			stake.refund_all(GameManager.local_profile, "a")
			stake.refund_all(GameManager.local_profile, "b")
	_rooms = _rooms.filter(func(item: Dictionary) -> bool: return str(item["id"]) != room_id)

## Đóng phòng mình đang mở (mỗi người 1 phòng).
static func close_own(profile: PlayerProfile) -> void:
	if profile:
		_rooms = _rooms.filter(func(r: Dictionary) -> bool: return str(r["host"]) != profile.display_name)

## Phòng chờ hợp với người tìm trận (không khoá, chênh cấp / cùng phái theo PkRules.can_match), không phải phòng của chính mình.
static func find_match(profile: PlayerProfile, mode: int = -1) -> Dictionary:
	var my_name := profile.display_name if profile else ""
	var my_lv := profile.level if profile else 90
	var my_sect := profile.sect_id if profile else ""
	for r in rooms(mode, WAITING):
		if str(r.get("host", "")) == my_name or str(r.get("password", "")) != "":
			continue
		var r_mode: int = int(r.get("mode", 0))
		var m_enum: PkRules.Mode = r_mode as PkRules.Mode
		if PkRules.can_match(m_enum, my_lv, my_sect, int(r.get("level", 1)), str(r.get("sect_id", ""))):
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

extends RefCounted
class_name TimeChallengeLobby

const TimeChallengeScript = preload("res://systems/challenge/time_challenge.gd")
## SẢNH PHÒNG CHỜ TỔ ĐỘI THÁCH THỨC THỜI GIAN (Vượt Ải 28 Ải — Độc Cô Quỷ Kiếm):
##   - Cho phép tạo phòng tổ đội tối đa 8 người chơi cùng vượt ải map 480.
##   - Thiết kế giống sảnh PK: Danh sách tất cả các phòng (đang chờ / đang đánh), tìm theo ID, lọc, đặt mật khẩu.
##   - Phòng chờ: Hiển thị 8 slot người chơi, quản lý sẵn sàng, thêm Bot trợ thủ hiệp khách khi thiếu người.
##   - Luật nghiêm ngặt: Tất cả thành viên trong phòng phải sẵn sàng thì chủ phòng mới có thể bắt đầu khiêu chiến.

const WAITING := "waiting"
const FIGHTING := "fighting"
const MAX_MEMBERS := 8

static var _rooms: Array[Dictionary] = []

static func rooms(state: String = "") -> Array[Dictionary]:
	init_sample_rooms()
	var out: Array[Dictionary] = []
	for r in _rooms:
		if state != "" and str(r.get("state", "")) != state:
			continue
		out.append(r)
	return out

static func find(room_id: String) -> Dictionary:
	init_sample_rooms()
	for r in _rooms:
		if str(r.get("id", "")) == room_id:
			return r
	return {}

static func find_own(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {}
	for r in _rooms:
		if str(r.get("host", "")) == profile.display_name:
			return r
		var members: Array = r.get("members", [])
		for m in members:
			if str(m.get("name", "")) == profile.display_name:
				return r
	return {}

## Khởi tạo danh sách phòng mẫu ban đầu để sảnh luôn sôi động (chỉ cho Offline).
static func init_sample_rooms() -> void:
	if not _rooms.is_empty():
		return
	# Chế độ Online: Tuyệt đối không sinh phòng mẫu chứa bot
	if GameModeManager.is_online():
		return
	var samples: Array[Dictionary] = [
		{
			"id": "719284",
			"host": "Độc Cô Cầu Bại",
			"level": 96,
			"sect_id": "hoa_son",
			"sect_name": "Hoa Sơn",
			"password": "",
			"state": WAITING,
			"max_members": MAX_MEMBERS,
			"members": [
				{"name": "Độc Cô Cầu Bại", "level": 96, "sect_id": "hoa_son", "sect_name": "Hoa Sơn", "ready": true, "is_host": true, "is_bot": false},
				{"name": "Phong Thanh Dương", "level": 94, "sect_id": "hoa_son", "sect_name": "Hoa Sơn", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Lệnh Hồ Xung", "level": 91, "sect_id": "hoa_son", "sect_name": "Hoa Sơn", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Nhạc Linh San", "level": 88, "sect_id": "hoa_son", "sect_name": "Hoa Sơn", "ready": false, "is_host": false, "is_bot": true}
			],
			"created_ms": Time.get_ticks_msec() - 120000
		},
		{
			"id": "832915",
			"host": "Tiêu Phong",
			"level": 98,
			"sect_id": "cai_bang",
			"sect_name": "Cái Bang",
			"password": "",
			"state": FIGHTING,
			"max_members": MAX_MEMBERS,
			"members": [
				{"name": "Tiêu Phong", "level": 98, "sect_id": "cai_bang", "sect_name": "Cái Bang", "ready": true, "is_host": true, "is_bot": false},
				{"name": "Hư Trúc", "level": 95, "sect_id": "thieu_lam", "sect_name": "Thiếu Lâm", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Đoàn Dự", "level": 93, "sect_id": "thien_nhan", "sect_name": "Thiên Nhẫn", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Hồng Thất Công", "level": 97, "sect_id": "cai_bang", "sect_name": "Cái Bang", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Quách Tĩnh", "level": 94, "sect_id": "cai_bang", "sect_name": "Cái Bang", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Hoàng Dung", "level": 90, "sect_id": "cai_bang", "sect_name": "Cái Bang", "ready": true, "is_host": false, "is_bot": true}
			],
			"created_ms": Time.get_ticks_msec() - 360000
		},
		{
			"id": "640182",
			"host": "Trương Tam Phong",
			"level": 99,
			"sect_id": "vo_dang",
			"sect_name": "Võ Đang",
			"password": "",
			"state": WAITING,
			"max_members": MAX_MEMBERS,
			"members": [
				{"name": "Trương Tam Phong", "level": 99, "sect_id": "vo_dang", "sect_name": "Võ Đang", "ready": true, "is_host": true, "is_bot": false},
				{"name": "Tống Viễn Kiều", "level": 92, "sect_id": "vo_dang", "sect_name": "Võ Đang", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Du Liên Châu", "level": 91, "sect_id": "vo_dang", "sect_name": "Võ Đang", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Trương Tùng Khê", "level": 90, "sect_id": "vo_dang", "sect_name": "Võ Đang", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Trương Thúy Sơn", "level": 89, "sect_id": "vo_dang", "sect_name": "Võ Đang", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Ân Lê Đình", "level": 88, "sect_id": "vo_dang", "sect_name": "Võ Đang", "ready": true, "is_host": false, "is_bot": true},
				{"name": "Mạc Thanh Cốc", "level": 87, "sect_id": "vo_dang", "sect_name": "Võ Đang", "ready": true, "is_host": false, "is_bot": true}
			],
			"created_ms": Time.get_ticks_msec() - 90000
		}
	]
	_rooms.append_array(samples)

static func create(profile: PlayerProfile, password: String = "", max_members: int = MAX_MEMBERS) -> Dictionary:
	close_own(profile)
	var sect := SectRegistry.get_by_id(profile.sect_id) if profile else null
	var sect_name := sect.sect_name if sect else "Vô môn phái"
	var host_member := {
		"name": profile.display_name if profile else "Hiệp Khách",
		"level": profile.level if profile else 90,
		"sect_id": profile.sect_id if profile else "",
		"sect_name": sect_name,
		"ready": true,
		"is_host": true,
		"is_bot": false
	}
	var room := {
		"id": _new_id(),
		"host": profile.display_name if profile else "Hiệp Khách",
		"level": profile.level if profile else 90,
		"sect_id": profile.sect_id if profile else "",
		"sect_name": sect_name,
		"password": password.strip_edges(),
		"state": WAITING,
		"max_members": clampi(max_members, 1, MAX_MEMBERS),
		"members": [host_member],
		"created_ms": Time.get_ticks_msec()
	}
	_rooms.append(room)
	return room

static func join(room_id: String, profile: PlayerProfile, password: String = "") -> Dictionary:
	if profile == null:
		return {"ok": false, "msg": "Chưa có nhân vật!"}
	var r := find(room_id)
	if r.is_empty():
		return {"ok": false, "msg": "Phòng không tồn tại hoặc đã bị hủy!"}
	if str(r.get("state", "")) != WAITING:
		return {"ok": false, "msg": "Phòng này đã bắt đầu khiêu chiến, không thể tham gia!"}
	var room_pw: String = str(r.get("password", "")).strip_edges()
	if room_pw != "" and room_pw != password.strip_edges():
		return {"ok": false, "msg": "Mật khẩu phòng không chính xác!"}
	var members: Array = r.get("members", [])
	var max_m: int = int(r.get("max_members", MAX_MEMBERS))
	for m in members:
		if str(m.get("name", "")) == profile.display_name:
			return {"ok": true, "msg": "Đã ở trong phòng!"}
	if members.size() >= max_m:
		return {"ok": false, "msg": "Phòng đã đủ %d/8 thành viên, không thể tham gia thêm!" % max_m}

	# Kiểm tra điều kiện tham gia vượt ải của người chơi
	var reason := TimeChallengeScript.check_entry(profile)
	if reason != "":
		return {"ok": false, "msg": reason}

	# Thoát khỏi các phòng cũ trước đó
	close_own(profile)

	var sect := SectRegistry.get_by_id(profile.sect_id)
	var member := {
		"name": profile.display_name,
		"level": profile.level,
		"sect_id": profile.sect_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"ready": false,
		"is_host": false,
		"is_bot": false
	}
	members.append(member)
	r["members"] = members
	return {"ok": true, "msg": "Gia nhập phòng thành công!"}

static func leave(room_id: String, profile: PlayerProfile) -> void:
	if profile == null:
		return
	var r := find(room_id)
	if r.is_empty():
		return
	if str(r.get("host", "")) == profile.display_name:
		close(room_id)
		return
	var members: Array = r.get("members", [])
	var new_mems: Array = []
	for m in members:
		if str(m.get("name", "")) != profile.display_name:
			new_mems.append(m)
	r["members"] = new_mems

static func kick(room_id: String, target_name: String, requester_profile: PlayerProfile) -> bool:
	var r := find(room_id)
	if r.is_empty() or requester_profile == null:
		return false
	if str(r.get("host", "")) != requester_profile.display_name:
		return false
	if target_name == requester_profile.display_name:
		return false
	var members: Array = r.get("members", [])
	var new_mems: Array = []
	for m in members:
		if str(m.get("name", "")) != target_name:
			new_mems.append(m)
	r["members"] = new_mems
	return true

static func toggle_ready(room_id: String, member_name: String) -> bool:
	var r := find(room_id)
	if r.is_empty():
		return false
	var members: Array = r.get("members", [])
	for m: Dictionary in members:
		if str(m.get("name", "")) == member_name:
			m["ready"] = not bool(m.get("ready", false))
			return bool(m["ready"])
	return false

static func is_all_ready(room: Dictionary) -> bool:
	if room.is_empty():
		return false
	var members: Array = room.get("members", [])
	if members.is_empty():
		return false
	for m in members:
		if not bool(m.get("ready", false)):
			return false
	return true

static func add_bot(room_id: String, level: int = 90) -> bool:
	if not GameModeManager.can_add_bot():
		return false
	var r := find(room_id)
	if r.is_empty() or str(r.get("state", "")) != WAITING:
		return false
	var members: Array = r.get("members", [])
	var max_m: int = int(r.get("max_members", MAX_MEMBERS))
	if members.size() >= max_m:
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
	members.append(bot_dict)
	r["members"] = members
	return true

## Điền đầy đủ 8 người bằng Bot hiệp khách (chỉ cho Offline)
static func fill_bots(room_id: String, level: int = 90) -> bool:
	if not GameModeManager.can_add_bot():
		return false
	var r := find(room_id)
	if r.is_empty() or str(r.get("state", "")) != WAITING:
		return false
	var members: Array = r.get("members", [])
	var max_m: int = int(r.get("max_members", MAX_MEMBERS))
	while members.size() < max_m:
		add_bot(room_id, level)
		members = r.get("members", [])
	return true

static func remove_bot(room_id: String, bot_name: String = "") -> bool:
	var r := find(room_id)
	if r.is_empty():
		return false
	var members: Array = r.get("members", [])
	for i in range(members.size() - 1, -1, -1):
		var m: Dictionary = members[i]
		if bool(m.get("is_bot", false)):
			if bot_name == "" or str(m.get("name", "")) == bot_name:
				members.remove_at(i)
				r["members"] = members
				return true
	return false

static func set_password(room_id: String, requester_profile: PlayerProfile, new_password: String) -> bool:
	var r := find(room_id)
	if r.is_empty() or requester_profile == null:
		return false
	if str(r.get("host", "")) != requester_profile.display_name:
		return false
	r["password"] = new_password.strip_edges()
	return true

static func close(room_id: String) -> void:
	_rooms = _rooms.filter(func(r: Dictionary) -> bool: return str(r["id"]) != room_id)

static func close_own(profile: PlayerProfile) -> void:
	if profile == null:
		return
	_rooms = _rooms.filter(func(r: Dictionary) -> bool: return str(r.get("host", "")) != profile.display_name)
	for r in _rooms:
		var members: Array = r.get("members", [])
		r["members"] = members.filter(func(m: Dictionary) -> bool: return str(m.get("name", "")) != profile.display_name)

static func set_fighting(room_id: String) -> void:
	var r := find(room_id)
	if not r.is_empty():
		r["state"] = FIGHTING

static func find_match(profile: PlayerProfile) -> Dictionary:
	var my_name := profile.display_name if profile else ""
	for r in rooms(WAITING):
		if str(r.get("host", "")) == my_name or str(r.get("password", "")) != "":
			continue
		var members: Array = r.get("members", [])
		var max_m: int = int(r.get("max_members", MAX_MEMBERS))
		if members.size() < max_m:
			return r
	return {}

static func _new_id() -> String:
	var id := ""
	while id == "" or not find(id).is_empty():
		id = "%06d" % randi_range(100000, 999999)
	return id

extends RefCounted
class_name ViemDeLobby
## SẢNH PHÒNG CHỜ TỔ ĐỘI VIÊM ĐẾ BẢO TÀNG (Kho Báu Viêm Đế Map 853):
##   - Cho phép tạo phòng tổ đội bên ngoài trước khi vào map tương tự chế độ PK.
##   - Hỗ trợ tối đa 4 người chơi / trợ thủ trong một tổ đội.
##   - Luật nghiêm ngặt: "Mọi người sẵn sàng hết chủ phòng mới được bấm vào chơi".
##   - Có thể thêm Bot Hiệp Khách trợ thủ để đi chung khi không đủ người chơi.

const WAITING := "waiting"
const FIGHTING := "fighting"
const MAX_MEMBERS := 4
const VIEM_DE_LENH_ID := "6_1_1617"
const VIEM_DE_LENH_NAME := "Viêm Đế Lệnh"
const VIEM_DE_LENH_PRICE_KNB := 2

## Kiểm tra số lượng Viêm Đế Lệnh trong hành trang
static func count_entry_item(profile: PlayerProfile) -> int:
	if profile == null:
		return 0
	var total := 0
	for it in profile.inventory:
		if it != null and (it.misc_id == VIEM_DE_LENH_ID or it.get_base().get("name", "") == VIEM_DE_LENH_NAME):
			total += maxi(it.count, 1)
	return total

static func has_entry_item(profile: PlayerProfile) -> bool:
	return count_entry_item(profile) > 0

## Trừ 1 Viêm Đế Lệnh từ hành trang khi tạo phòng / tham gia solo
static func consume_entry_item(profile: PlayerProfile) -> bool:
	if profile == null:
		return false
	for i in profile.inventory.size():
		var it: ItemInstance = profile.inventory[i]
		if it != null and (it.misc_id == VIEM_DE_LENH_ID or it.get_base().get("name", "") == VIEM_DE_LENH_NAME):
			if it.count > 1:
				it.count -= 1
			else:
				profile.inventory.remove_at(i)
			SaveManager.save_profile(profile)
			SaveManager.flush_online()
			return true
	return false

## Hoàn trả Viêm Đế Lệnh khi chủ phòng hủy/rời phòng chưa bắt đầu đánh
static func refund_entry_item(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var item: ItemInstance = ItemGenerator.generate_misc(VIEM_DE_LENH_ID)
	if item != null:
		profile.add_item(item)
		SaveManager.save_profile(profile)
		SaveManager.flush_online()

## Mua Viêm Đế Lệnh bằng Kim Nguyên Bảo (KNB) — giá 2 KNB / 1 lệnh
static func buy_entry_item(profile: PlayerProfile, amount: int = 1) -> Dictionary:
	if profile == null:
		return {"ok": false, "msg": "Chưa có hồ sơ nhân vật."}
	if amount <= 0:
		amount = 1
	var total_cost := VIEM_DE_LENH_PRICE_KNB * amount
	if profile.jade < total_cost:
		return {
			"ok": false,
			"msg": "Không đủ Kim Nguyên Bảo (KNB)! Cần %d KNB để mua %d Viêm Đế Lệnh (Hiện có: %d KNB)." % [total_cost, amount, profile.jade]
		}
	profile.jade -= total_cost
	for i in range(amount):
		var it: ItemInstance = ItemGenerator.generate_misc(VIEM_DE_LENH_ID)
		if it == null or not profile.add_item(it):
			profile.jade += (amount - i) * VIEM_DE_LENH_PRICE_KNB
			SaveManager.save_profile(profile)
			SaveManager.flush_online()
			return {"ok": false, "msg": "Hành trang đã đầy, không thể chứa thêm Viêm Đế Lệnh!"}
	SaveManager.save_profile(profile)
	SaveManager.flush_online()
	return {"ok": true, "msg": "Mua thành công %d Viêm Đế Lệnh (-%d KNB)!" % [amount, total_cost]}

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

static func init_sample_rooms() -> void:
	if not _rooms.is_empty():
		return
	if GameModeManager.is_online():
		return
	var samples: Array[Dictionary] = [
		{
			"id": "184029",
			"host": "Đoàn Dự",
			"route": "a",
			"double_exp": true,
			"password": "",
			"state": WAITING,
			"max_members": MAX_MEMBERS,
			"created_ms": Time.get_ticks_msec() - 120000,
			"members": [
				{"name": "Đoàn Dự", "level": 94, "sect_id": "thien_vuong", "sect_name": "Thiên Vương", "ready": true, "is_host": true, "is_bot": true},
				{"name": "Hư Trúc", "level": 92, "sect_id": "thieu_lam", "sect_name": "Thiếu Lâm", "ready": true, "is_host": false, "is_bot": true}
			]
		},
		{
			"id": "295810",
			"host": "Trương Vô Kỵ",
			"route": "b",
			"double_exp": false,
			"password": "",
			"state": WAITING,
			"max_members": MAX_MEMBERS,
			"created_ms": Time.get_ticks_msec() - 60000,
			"members": [
				{"name": "Trương Vô Kỵ", "level": 96, "sect_id": "vo_dang", "sect_name": "Võ Đang", "ready": true, "is_host": true, "is_bot": true}
			]
		}
	]
	_rooms.append_array(samples)

static func _new_id() -> String:
	return "%06d" % randi_range(100000, 999999)

static func create(profile: PlayerProfile, route: String = "a", double_exp: bool = true, password: String = "") -> Dictionary:
	if profile == null:
		return {}
	close_own(profile)
	var sect := SectRegistry.get_by_id(profile.sect_id)
	var host_member := {
		"name": profile.display_name,
		"level": profile.level,
		"sect_id": profile.sect_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"ready": true,
		"is_host": true,
		"is_bot": false
	}
	var room := {
		"id": _new_id(),
		"host": profile.display_name,
		"route": route,
		"double_exp": double_exp,
		"password": password.strip_edges(),
		"state": WAITING,
		"max_members": MAX_MEMBERS,
		"members": [host_member],
		"created_ms": Time.get_ticks_msec(),
		"host_paid": false
	}
	_rooms.insert(0, room)
	return room

static func set_password(room_id: String, host_profile: PlayerProfile, new_password: String) -> bool:
	var room := find(room_id)
	if room.is_empty():
		return false
	if host_profile != null and str(room.get("host", "")) != host_profile.display_name:
		return false
	room["password"] = new_password.strip_edges()
	return true

static func close_own(profile: PlayerProfile) -> void:
	if profile == null:
		return
	for i in range(_rooms.size() - 1, -1, -1):
		var r: Dictionary = _rooms[i]
		if str(r.get("host", "")) == profile.display_name:
			if str(r.get("state", "")) != FIGHTING and bool(r.get("host_paid", false)):
				refund_entry_item(profile)
			_rooms.remove_at(i)
		else:
			# Rời khỏi nếu chỉ là thành viên
			var members: Array = r.get("members", [])
			for j in range(members.size() - 1, -1, -1):
				if str(members[j].get("name", "")) == profile.display_name:
					members.remove_at(j)

static func join(room_id: String, profile: PlayerProfile, password: String = "") -> String:
	if profile == null:
		return "Hồ sơ người chơi không hợp lệ!"
	var room := find(room_id)
	if room.is_empty():
		return "Phòng không tồn tại hoặc đã bị giải tán!"
	if str(room.get("state", "")) == FIGHTING:
		return "Tổ đội này đã tiến vào Viêm Đế Bảo Tàng rồi!"
	var members: Array = room.get("members", [])
	if members.size() >= MAX_MEMBERS:
		return "Phòng tổ đội đã đủ %d người!" % MAX_MEMBERS
	var room_pw := str(room.get("password", "")).strip_edges()
	if room_pw != "" and room_pw != password.strip_edges():
		return "Mật khẩu phòng không chính xác!"

	# Kiểm tra xem đã có trong phòng chưa
	for m in members:
		if str(m.get("name", "")) == profile.display_name:
			return ""

	close_own(profile)
	var sect := SectRegistry.get_by_id(profile.sect_id)
	var new_m := {
		"name": profile.display_name,
		"level": profile.level,
		"sect_id": profile.sect_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"ready": false, # Mặc định thành viên mới vào là CHƯA sẵn sàng
		"is_host": false,
		"is_bot": false
	}
	members.append(new_m)
	return ""

static func leave(room_id: String, profile: PlayerProfile) -> void:
	if profile == null:
		return
	var room := find(room_id)
	if room.is_empty():
		return
	var is_host := (str(room.get("host", "")) == profile.display_name)
	var is_fighting := (str(room.get("state", "")) == FIGHTING)
	if is_host:
		# Chủ phòng rời phòng khi chưa bắt đầu chiến đấu -> hoàn trả Viêm Đế Lệnh nếu đã trả
		if not is_fighting and bool(room.get("host_paid", false)):
			refund_entry_item(profile)
		for i in range(_rooms.size() - 1, -1, -1):
			if str(_rooms[i].get("id", "")) == room_id:
				_rooms.remove_at(i)
				break
	else:
		var members: Array = room.get("members", [])
		for j in range(members.size() - 1, -1, -1):
			if str(members[j].get("name", "")) == profile.display_name:
				members.remove_at(j)
				break

static func toggle_ready(room_id: String, member_name: String) -> void:
	var room := find(room_id)
	if room.is_empty():
		return
	var members: Array = room.get("members", [])
	for m in members:
		if str(m.get("name", "")) == member_name:
			if bool(m.get("is_host", false)):
				m["ready"] = true # Chủ phòng luôn sẵn sàng
			else:
				m["ready"] = not bool(m.get("ready", false))
			break

static func add_bot(room_id: String) -> bool:
	if not GameModeManager.can_add_bot():
		return false
	var room := find(room_id)
	if room.is_empty():
		return false
	var members: Array = room.get("members", [])
	if members.size() >= MAX_MEMBERS:
		return false

	var bot_names := ["Dương Quá", "Tiểu Long Nữ", "Phong Thanh Dương", "Tạ Tốn", "Hoàng Dung", "Mộ Dung Phục", "Lệnh Hồ Xung", "Âu Dương Phong"]
	var used_names: Array[String] = []
	for m in members:
		used_names.append(str(m.get("name", "")))

	var chosen_name := ""
	for bname in bot_names:
		if not used_names.has(bname):
			chosen_name = bname
			break
	if chosen_name == "":
		chosen_name = "Hiệp Sĩ %d" % randi_range(100, 999)

	var sects := ["thien_vuong", "thieu_lam", "nga_my", "thuy_yen", "ngu_doc", "duong_mon", "cai_bang", "thien_nhan", "vo_dang", "con_lon"]
	var s_id: String = sects[randi() % sects.size()]
	var sect := SectRegistry.get_by_id(s_id)
	var bot_lvl := randi_range(90, 95)
	var bot_p: PlayerProfile = PkBotProfile.create(bot_lvl, s_id)
	bot_p.display_name = chosen_name

	var bot_member := {
		"name": chosen_name,
		"level": bot_lvl,
		"sect_id": s_id,
		"sect_name": sect.sect_name if sect else "Vô môn phái",
		"ready": true, # Bot hỗ trợ được thêm vào sẵn sàng trợ chiến
		"is_host": false,
		"is_bot": true,
		"bot_data": bot_p.to_dict()
	}
	members.append(bot_member)
	return true

static func kick(room_id: String, member_name: String, host_profile: PlayerProfile = null) -> bool:
	var room := find(room_id)
	if room.is_empty():
		return false
	if host_profile != null and str(room.get("host", "")) != host_profile.display_name:
		return false
	var members: Array = room.get("members", [])
	for i in range(members.size() - 1, -1, -1):
		if str(members[i].get("name", "")) == member_name and not bool(members[i].get("is_host", false)):
			members.remove_at(i)
			return true
	return false

## QUY TẮC QUAN TRỌNG: Tất cả thành viên trong phòng (trừ chủ phòng) đều phải có ready == true!
static func is_all_ready(room: Dictionary) -> bool:
	if room.is_empty():
		return false
	var members: Array = room.get("members", [])
	if members.is_empty():
		return false
	for m in members:
		if not bool(m.get("is_host", false)) and not bool(m.get("ready", false)):
			return false
	return true

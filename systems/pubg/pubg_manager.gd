class_name PubgManager
extends Node
## HỆ THỐNG ĐIỀU HÀNH CHẾ ĐỘ PUBG VÕ LÂM (BATTLE ROYALE)
## - Quản lý danh sách phòng (ID phòng, trạng thái, số người chơi, chế độ 1, 2, 3, 4 người)
## - Đồng đội 2-4 người xuất hiện chung 1 chỗ, không đánh được nhau, tên màu xanh dương
## - Bản đồ Tống Kim 1 (tongkim1), giới hạn ngẫu nhiên cố định 140x80 region
## - Vòng bo 10 phút co dần, hiển thị trên minimap, rút máu khi đứng ngoài bo
## - Cấu hình nhân vật Level 200, cộng điểm tiềm năng và kỹ năng trước khi vào game, nút lưu điểm
## - Quái rớt đồ Hoàng Kim Môn Phái 90%
## - Đồ chỉ phục vụ cho màn chơi, hết màn chơi tất cả đều mất

const SAVE_BUILD_PATH := "user://pubg_build.json"
const TONGKIM1_DIR := "res://world/maps/map_tongkim1"
const REGION_PX := 512.0
const ARENA_REGIONS_W := 140.0
const ARENA_REGIONS_H := 80.0

# Giới hạn map Tống Kim 1 trong map.json
const MAP_MIN_RX := 76
const MAP_MAX_RX := 654
const MAP_MIN_RY := 799
const MAP_MAX_RY := 1150

# Chu kỳ vòng bo (10 phút = 600 giây)
const CIRCLE_INTERVAL := 600.0
const CIRCLE_SHRINK_DURATION := 60.0 # Thời gian thu bo trong 60 giây

## Dữ liệu phòng
static var rooms: Array[Dictionary] = []
static var active_room: Dictionary = {}
static var active_bot_nodes: Array[Node] = []

## Lưu build Level 200
static var pubg_potential_stats: Dictionary = {}
static var pubg_skill_levels: Dictionary = {} # skill_id -> level
static var has_custom_build: bool = false

## Quản lý Session
static var is_active: bool = false
static var backup_profile_data: Dictionary = {}
static var current_squad_size: int = 1
static var current_squad_members: Array[Dictionary] = []

static func is_pubg_active() -> bool:
	if is_active:
		return true
	if GameManager != null and GameManager.field_map != null and (GameManager.field_map.get("pubg", false) == true or GameManager.field_map.get("is_pubg", false) == true):
		return true
	return false

## Vòng bo (Circles)
static var fixed_outer_boundary: Rect2 = Rect2() # Khung sáng cố định 140 region x 80 region
static var current_zone: Rect2 = Rect2() # Vòng bo hiện tại
static var next_safe_zone: Rect2 = Rect2() # Vòng bo tiếp theo sẽ co vào
static var circle_timer: float = CIRCLE_INTERVAL
static var is_shrinking: bool = false
static var shrink_progress: float = 0.0
static var circle_phase: int = 1
static var poison_damage_rate: float = 0.03 # 3% max HP / giây ở Phase 1

# Signal thông báo cho HUD / Minimap
static var circle_updated: Callable

## Khởi tạo danh sách phòng mặc định
static func init_default_rooms() -> void:
	if not rooms.is_empty():
		return
	rooms = [
		{
			"id": "PUBG-8012",
			"name": "Độc Cô Cầu Bại Solo",
			"mode": 1, # Solo
			"mode_name": "Đơn Đấu (Solo)",
			"status": "Sẵn Sàng",
			"status_text": "Sẵn Sàng",
			"players": 1,
			"players_count": 1,
			"max_players": 1,
			"leader": "HoaHiệp",
			"host": "HoaHiệp",
			"password": ""
		},
		{
			"id": "PUBG-5541",
			"name": "Song Kiếm Hợp Bích (Duo)",
			"mode": 2, # Duo
			"mode_name": "Song Đấu (Duo)",
			"status": "Đang Đợi",
			"status_text": "Đang Đợi",
			"players": 1,
			"players_count": 1,
			"max_players": 2,
			"leader": "LệnhHồXung",
			"host": "LệnhHồXung",
			"password": "123"
		},
		{
			"id": "PUBG-3392",
			"name": "Tam Anh Chiến Tống Kim (Trio)",
			"mode": 3, # Trio
			"mode_name": "Tam Đấu (Trio)",
			"status": "Đang Đợi",
			"status_text": "Đang Đợi",
			"players": 2,
			"players_count": 2,
			"max_players": 3,
			"leader": "QuáchTĩnh",
			"host": "QuáchTĩnh",
			"password": ""
		},
		{
			"id": "PUBG-1024",
			"name": "Tứ Hải Huynh Đệ (Squad 4)",
			"mode": 4, # Squad
			"mode_name": "Tổ Đội (Squad)",
			"status": "Đang Đợi",
			"status_text": "Đang Đợi",
			"players": 3,
			"players_count": 3,
			"max_players": 4,
			"leader": "DươngQuá",
			"host": "DươngQuá",
			"password": ""
		},
		{
			"id": "PUBG-9901",
			"name": "Trảm Tướng Đoạt Kỳ",
			"mode": 4, # Squad
			"mode_name": "Tổ Đội (Squad)",
			"status": "Đang Đấu",
			"status_text": "Đang Đấu",
			"players": 4,
			"players_count": 4,
			"max_players": 4,
			"bot_count": 46,
			"start_time": Time.get_unix_time_from_system() - 140.0, # Đang đấu được ~2 phút 20 giây (< 5 phút)
			"leader": "TiêuPhong",
			"host": "TiêuPhong",
			"password": ""
		},
		{
			"id": "PUBG-7711",
			"name": "Quyết Chiến Sa Trường (Trận Cũ)",
			"mode": 2, # Duo
			"mode_name": "Song Đấu (Duo)",
			"status": "Đang Đấu",
			"status_text": "Đang Đấu",
			"players": 2,
			"players_count": 2,
			"max_players": 2,
			"bot_count": 48,
			"start_time": Time.get_unix_time_from_system() - 380.0, # Đang đấu được > 6 phút (> 5 phút -> quá hạn vào)
			"leader": "MộDungPhục",
			"host": "MộDungPhục",
			"password": ""
		}
	]

static func refresh_rooms() -> Array[Dictionary]:
	init_default_rooms()
	# Cập nhật số người ngẫu nhiên để danh sách sinh động
	for r in rooms:
		if r["status"] == "waiting" or r["status"] == "Đang Đợi":
			if r["mode"] == 1:
				r["players_count"] = clampi(int(r.get("players_count", 1)) + randi_range(-1, 1), 1, 1)
				r["players"] = r["players_count"]
			else:
				var max_p: int = r["max_players"]
				r["players_count"] = clampi(int(r.get("players_count", 1)), 1, max_p)
				r["players"] = r["players_count"]
	return rooms

static func create_room(room_name: String, mode: int, host_name: String, password: String = "") -> Dictionary:
	init_default_rooms()
	var new_id := "PUBG-%04d" % randi_range(1000, 9999)
	var mode_name := ""
	match mode:
		1: mode_name = "Đơn Đấu (Solo)"
		2: mode_name = "Song Đấu (Duo)"
		3: mode_name = "Tam Đấu (Trio)"
		4: mode_name = "Tổ Đội (Squad)"
		_: mode_name = "Đơn Đấu (Solo)"
	
	var r := {
		"id": new_id,
		"name": room_name if room_name != "" else "Phòng của %s" % host_name,
		"mode": mode,
		"mode_name": mode_name,
		"status": "Đang Đợi",
		"status_text": "Đang Đợi",
		"players": 1,
		"players_count": 1,
		"max_players": mode if mode > 1 else 1,
		"leader": host_name,
		"host": host_name,
		"password": password
	}
	rooms.insert(0, r)
	active_room = r
	return r

## Người chơi rời phòng (hoặc kết thúc trận / mất kết nối / đóng game vật lý)
## Nếu phòng không còn ai (players <= 0) hoặc người rời là chủ phòng: TỰ ĐỘNG XÓA PHÒNG NGAY LẬP TỨC
static func leave_room(room_id: String, profile: PlayerProfile = null) -> void:
	if room_id == "":
		return
	var my_name: String = profile.display_name if (profile and "display_name" in profile) else ""
	if my_name == "" and GameManager and "local_profile" in GameManager and GameManager.local_profile:
		my_name = GameManager.local_profile.display_name

	for i in range(rooms.size() - 1, -1, -1):
		var r: Dictionary = rooms[i]
		if str(r.get("id", "")) == room_id:
			var cur_p: int = int(r.get("players", r.get("players_count", 1))) - 1
			r["players"] = cur_p
			r["players_count"] = cur_p
			var host_name: String = str(r.get("leader", r.get("host", "")))
			
			# Nếu hết người trong phòng (cur_p <= 0) HOẶC chủ phòng rời phòng: Tự động xóa phòng ngay lập tức
			if cur_p <= 0 or (my_name != "" and host_name == my_name):
				rooms.remove_at(i)
				print("[PUBG] Phòng %s đã tự động bị xóa (lý do: hết người chơi hoặc chủ phòng rời)." % room_id)
			else:
				# Nếu phòng đang trong trận đấu, giữ nguyên trạng thái Đang Đấu
				if str(r.get("status", "")) != "Đang Đấu":
					r["status"] = "Đang Đợi" if cur_p < int(r.get("max_players", 4)) else "Sẵn Sàng"
					r["status_text"] = r["status"]
			break

## Đóng toàn bộ phòng do profile sở hữu (dùng khi thoát game / dọn dẹp)
static func close_own(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var host_name: String = profile.display_name
	if host_name == "":
		return
	for i in range(rooms.size() - 1, -1, -1):
		var r: Dictionary = rooms[i]
		if str(r.get("leader", r.get("host", ""))) == host_name:
			var rid: String = str(r.get("id", ""))
			rooms.remove_at(i)
			print("[PUBG] Phòng %s của chủ phòng %s đã tự động bị xóa." % [rid, host_name])

## Xử lý khi đóng game vật lý (Alt+F4 / tắt cửa sổ / tắt tab web / kill process)
static func on_game_closing(profile: PlayerProfile = null) -> void:
	var prof: PlayerProfile = profile
	if prof == null and GameManager and "local_profile" in GameManager:
		prof = GameManager.local_profile

	if not active_room.is_empty():
		var rid: String = str(active_room.get("id", ""))
		leave_room(rid, prof)
		active_room = {}
	if is_active:
		end_match(prof)
	if prof != null:
		close_own(prof)

## ==============================================================================
## QUẢN LÝ BOT & THAY THẾ BOT BẰNG NGƯỜI THẬT KHI TÌM PHÒNG < 5 PHÚT
## ==============================================================================
static func register_bot(bot: Node) -> void:
	if bot != null and not active_bot_nodes.has(bot):
		active_bot_nodes.append(bot)

static func unregister_bot(bot: Node) -> void:
	active_bot_nodes.erase(bot)

## Tìm phòng đang thi đấu (Đang Đấu) có thời gian trôi qua < 5 phút (300 giây) và còn đủ BOT để thay thế
static func find_joinable_active_match(required_slots: int = 1, exclude_room_id: String = "") -> Dictionary:
	init_default_rooms()
	var now: float = Time.get_unix_time_from_system()
	for r in rooms:
		var rid: String = str(r.get("id", ""))
		if exclude_room_id != "" and rid == exclude_room_id:
			continue
		var st: String = str(r.get("status", ""))
		if st != "Đang Đấu":
			continue
		var start_t: float = float(r.get("start_time", 0.0))
		if start_t <= 0.0:
			continue
		var elapsed_sec: float = now - start_t
		# Điều kiện: Thời gian trận đấu dưới 5 phút (300 giây)
		if elapsed_sec >= 0.0 and elapsed_sec < 300.0:
			var bots: int = int(r.get("bot_count", 0))
			if bots >= required_slots:
				return r
	return {}

## Tự động xóa bot bất kỳ tương ứng với số người thật vào phòng
static func remove_random_bots(count: int, room: Dictionary = {}) -> int:
	var removed_count: int = 0
	# 1. Xóa các node bot thực tế trong game nếu có
	for _k in range(count):
		var valid_bots: Array[Node] = []
		for b in active_bot_nodes:
			if is_instance_valid(b):
				valid_bots.append(b)
		active_bot_nodes = valid_bots
		if not active_bot_nodes.is_empty():
			var rand_idx: int = randi() % active_bot_nodes.size()
			var victim: Node = active_bot_nodes[rand_idx]
			active_bot_nodes.remove_at(rand_idx)
			if is_instance_valid(victim):
				print("[PUBG] Đã tự động xóa BOT: %s" % victim.name)
				victim.queue_free()
				removed_count += 1
		else:
			removed_count += 1

	# 2. Cập nhật dữ liệu số bot của phòng
	if not room.is_empty():
		var cur_bots: int = int(room.get("bot_count", 50))
		room["bot_count"] = maxi(0, cur_bots - count)
		var cur_p: int = int(room.get("players", room.get("players_count", 1)))
		room["players"] = cur_p + count
		room["players_count"] = room["players"]

	return removed_count

## Cho người thật mới vào phòng đang đấu (< 5 phút) và tự động xóa số BOT tương ứng
static func backfill_player_into_match(target_room: Dictionary, real_player_count: int, profile: PlayerProfile) -> Dictionary:
	var elapsed_sec: int = int(Time.get_unix_time_from_system() - float(target_room.get("start_time", 0.0)))
	var min_val: int = elapsed_sec / 60
	var sec_val: int = elapsed_sec % 60
	print("[PUBG] Người thật (%s - %d người) được đưa vào phòng %s đang đấu (%02d:%02d < 5 phút)!" % [
		profile.display_name if profile else "HiệpKhách",
		real_player_count,
		target_room.get("id", ""),
		min_val, sec_val
	])

	# Tự động xóa BOT bất kỳ tương ứng với số người thật vào phòng
	remove_random_bots(real_player_count, target_room)

	# Bắt đầu trận đấu với phòng này
	var field_entry: Dictionary = start_match(profile, target_room)
	field_entry["is_backfill"] = true
	field_entry["backfill_elapsed_sec"] = elapsed_sec
	return field_entry

## Lưu trữ & Nạp điểm tiềm năng Level 200
static func save_build(stats: Dictionary, skills: Dictionary = {}) -> void:
	pubg_potential_stats = stats.duplicate(true)
	pubg_skill_levels = skills.duplicate(true)
	has_custom_build = true
	var f := FileAccess.open(SAVE_BUILD_PATH, FileAccess.WRITE)
	if f:
		var d := {
			"has_custom_build": true,
			"str": pubg_potential_stats.get("str", pubg_potential_stats.get("strength", 0)),
			"dex": pubg_potential_stats.get("dex", pubg_potential_stats.get("dexterity", 0)),
			"vit": pubg_potential_stats.get("vit", pubg_potential_stats.get("vitality", 0)),
			"eng": pubg_potential_stats.get("eng", pubg_potential_stats.get("energy", 0)),
			"stat_left": pubg_potential_stats.get("stat_left", 0)
		}
		f.store_string(JSON.stringify(d, "\t"))

static func load_build() -> void:
	pubg_potential_stats.clear()
	pubg_skill_levels.clear()
	has_custom_build = false
	if not FileAccess.file_exists(SAVE_BUILD_PATH):
		return
	var f := FileAccess.open(SAVE_BUILD_PATH, FileAccess.READ)
	if not f:
		return
	var json = JSON.parse_string(f.get_as_text())
	if json is Dictionary:
		var d: Dictionary = json
		if d.has("stats") and d["stats"] is Dictionary:
			pubg_potential_stats = d["stats"].duplicate(true)
			has_custom_build = bool(d.get("has_custom_build", true))
		elif d.has("str") or d.has("strength"):
			var s_val: int = int(d.get("str", d.get("strength", 0)))
			var dx_val: int = int(d.get("dex", d.get("dexterity", 0)))
			var v_val: int = int(d.get("vit", d.get("vitality", 0)))
			var e_val: int = int(d.get("eng", d.get("energy", 0)))
			pubg_potential_stats = {
				"str": s_val,
				"dex": dx_val,
				"vit": v_val,
				"eng": e_val,
				"stat_left": int(d.get("stat_left", 0))
			}
			if (s_val + dx_val + v_val + e_val) > 0 or d.get("has_custom_build", false) == true:
				has_custom_build = true

## Tính toán khung ngẫu nhiên 140 region x 80 region trên bản đồ Tống Kim 1
static func generate_random_arena_box() -> Rect2:
	var max_rx: int = MAP_MAX_RX - int(ARENA_REGIONS_W)
	var max_ry: int = MAP_MAX_RY - int(ARENA_REGIONS_H)
	var rx: int = randi_range(MAP_MIN_RX, max_rx)
	var ry: int = randi_range(MAP_MIN_RY, max_ry)

	var px_x: float = float(rx) * REGION_PX
	var px_y: float = float(ry) * REGION_PX
	var px_w: float = ARENA_REGIONS_W * REGION_PX # 71680.0 px
	var px_h: float = ARENA_REGIONS_H * REGION_PX # 40960.0 px

	return Rect2(px_x, px_y, px_w, px_h)

## Bắt đầu trận đấu PUBG
static func start_match(profile: PlayerProfile, room: Dictionary) -> Dictionary:
	is_active = true
	active_room = room
	current_squad_size = int(room.get("mode", 1))

	# Cập nhật trạng thái và thời gian bắt đầu phòng đấu
	room["status"] = "Đang Đấu"
	room["status_text"] = "Đang Đấu"
	if not room.has("start_time") or float(room.get("start_time", 0.0)) <= 0.0:
		room["start_time"] = Time.get_unix_time_from_system()
	if not room.has("bot_count"):
		var cur_real_p: int = int(room.get("players", room.get("players_count", 1)))
		room["bot_count"] = maxi(0, 50 - cur_real_p)

	# 1. Sao lưu toàn bộ trạng thái profile gốc (Hành trang, Trang bị, Level, Điểm tiềm năng/kỹ năng)
	backup_profile_data = profile.to_dict().duplicate(true)

	# 2. Thiết lập profile cho PUBG: Cấp 200
	profile.level = 200

	# 2.1. Điểm tiềm năng: Trở về ban đầu hết nếu chưa sét mặc định
	load_build()
	profile.apply_start_stats() # Trở về 4 chỉ số gốc ban đầu theo ngũ hành môn phái
	if has_custom_build and not pubg_potential_stats.is_empty():
		# Đã sét mặc định: cộng thêm các điểm tiềm năng đã lưu
		var add_str: int = int(pubg_potential_stats.get("str", pubg_potential_stats.get("strength", 0)))
		var add_dex: int = int(pubg_potential_stats.get("dex", pubg_potential_stats.get("dexterity", 0)))
		var add_vit: int = int(pubg_potential_stats.get("vit", pubg_potential_stats.get("vitality", 0)))
		var add_eng: int = int(pubg_potential_stats.get("eng", pubg_potential_stats.get("energy", 0)))
		profile.strength += add_str
		profile.dexterity += add_dex
		profile.vitality += add_vit
		profile.energy += add_eng
		profile.potential_points = int(pubg_potential_stats.get("stat_left", 0))
	else:
		# Chưa sét mặc định: Trở về ban đầu hết, 995 điểm tiềm năng đưa vào potential_points để tự do cộng
		profile.potential_points = 995

	# 2.2. Điểm kỹ năng: Trong chế độ PUBG, TOÀN BỘ KỸ NĂNG PHẢI MAX HẾT
	profile.skill_levels.clear()
	var sect: SectDefinition = SectRegistry.get_by_id(profile.sect_id) if (profile.sect_id != "" and SectRegistry) else null
	if sect != null and not sect.skills.is_empty():
		for sk in sect.skills:
			if sk != null and sk.id != "":
				var max_lv: int = sk.max_level if sk.max_level > 0 else 20
				profile.skill_levels[sk.id] = max_lv
	else:
		# Trường hợp chưa gia nhập phái hoặc test: max các chiêu thức hiện có
		for sk_id in profile.skill_levels.keys():
			profile.skill_levels[sk_id] = 20
	profile.skill_points = 0

	# Đảm bảo gán skill vào thanh hotbar nếu hotbar đang trống
	var has_hotbar := false
	for h_id in profile.hotbar_skill_ids:
		if h_id != "":
			has_hotbar = true
			break
	if not has_hotbar and sect != null:
		var slot_idx: int = 0
		for sk in sect.skills:
			if sk.can_assign_to_hotbar() and not sk.is_basic_attack:
				if slot_idx < profile.hotbar_skill_ids.size():
					profile.hotbar_skill_ids[slot_idx] = sk.id
					slot_idx += 1

	# Xóa sạch trang bị và hành trang hiện tại để vào game với trạng thái tay không (sinh tồn)
	profile.inventory.clear()
	profile.equipment.clear()
	if profile.has_method("recalc_stats"):
		profile.recalc_stats()

	# Cấp sẵn 50 bình Hồi Thiên Tái Tạo Đơn (1_8_0_4) và gắn vào ô thuốc 1 (slot 0)
	var potion := ItemGenerator.generate_misc("1_8_0_4", 0, 0, 1)
	if potion != null:
		potion.count = 50
		profile.add_item(potion)
	profile.quick_items = ["1_8_0_4", "", "", ""]
	if SaveManager != null and SaveManager.has_signal("profile_changed"):
		SaveManager.profile_changed.emit(profile)

	# 3. Tạo khung cố định 140 region x 80 region
	fixed_outer_boundary = generate_random_arena_box()
	current_zone = fixed_outer_boundary
	next_safe_zone = _generate_next_circle(current_zone, 0.5)
	circle_timer = CIRCLE_INTERVAL
	is_shrinking = false
	shrink_progress = 0.0
	circle_phase = 1
	poison_damage_rate = 0.03

	# 4. Tạo vị trí xuất hiện (Tất cả thành viên trong squad xuất hiện chung 1 chỗ)
	var spawn_pos: Vector2 = fixed_outer_boundary.position + Vector2(
		randf_range(fixed_outer_boundary.size.x * 0.2, fixed_outer_boundary.size.x * 0.8),
		randf_range(fixed_outer_boundary.size.y * 0.2, fixed_outer_boundary.size.y * 0.8)
	)

	# 5. Thiết lập danh sách đồng đội (Squad)
	current_squad_members.clear()
	var my_member := {
		"name": profile.display_name,
		"is_self": true,
		"color": Color(0.2, 0.65, 1.0), # Xanh dương
		"squad_id": 1,
		"pos": spawn_pos
	}
	current_squad_members.append(my_member)

	var bot_names := ["LýTầmHoan", "SởLưuHương", "LụcTiểuPhụng", "HoaMãnLâu"]
	for i in range(1, current_squad_size):
		var mate_name: String = bot_names[(i - 1) % bot_names.size()]
		var offset_pos := spawn_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		current_squad_members.append({
			"name": mate_name,
			"is_self": false,
			"color": Color(0.2, 0.65, 1.0), # Xanh dương
			"squad_id": 1,
			"pos": offset_pos
		})

	# 6. Cấu hình field_map cho GameManager
	var field_entry := {
		"id": 44,
		"name": "Chiến Trường Sinh Tồn (PUBG)",
		"title": "Chiến Trường Sinh Tồn (PUBG)",
		"kind": "Battlefield",
		"dir": TONGKIM1_DIR,
		"folder": TONGKIM1_DIR,
		"pubg": true,
		"is_pubg": true,
		"arena_box": fixed_outer_boundary,
		"arena_center": fixed_outer_boundary.get_center(),
		"arena_size": fixed_outer_boundary.size,
		"spawn_pos": spawn_pos,
		"start": [int(spawn_pos.x / REGION_PX), int(spawn_pos.y / REGION_PX)],
		"squad_size": current_squad_size,
		"room_id": room.get("id", "PUBG-101"),
		"no_monsters": false
	}

	return field_entry

## Sinh vòng bo an toàn nhỏ hơn bên trong vùng hiện tại
static func _generate_next_circle(parent_zone: Rect2, scale_factor: float) -> Rect2:
	var new_w := parent_zone.size.x * scale_factor
	var new_h := parent_zone.size.y * scale_factor
	var margin_x := parent_zone.size.x - new_w
	var margin_y := parent_zone.size.y - new_h
	var new_x := parent_zone.position.x + randf_range(0.0, margin_x)
	var new_y := parent_zone.position.y + randf_range(0.0, margin_y)
	return Rect2(new_x, new_y, new_w, new_h)

## Cập nhật vòng bo mỗi frame trong trận
static func update_circle(delta: float, player: Node) -> void:
	if not is_active:
		return

	if not is_shrinking:
		circle_timer -= delta
		if circle_timer <= 0.0:
			# Bắt đầu co bo
			is_shrinking = true
			shrink_progress = 0.0
	else:
		shrink_progress += delta / CIRCLE_SHRINK_DURATION
		if shrink_progress >= 1.0:
			shrink_progress = 1.0
			is_shrinking = false
			current_zone = next_safe_zone
			circle_phase += 1
			circle_timer = CIRCLE_INTERVAL # 10 phút tiếp theo
			poison_damage_rate += 0.02 # Rút máu đau hơn ở các vòng sau
			next_safe_zone = _generate_next_circle(current_zone, 0.5)
		else:
			# Co bo mượt mà
			var t := shrink_progress
			var cur_pos := current_zone.position.lerp(next_safe_zone.position, t)
			var cur_size := current_zone.size.lerp(next_safe_zone.size, t)
			current_zone = Rect2(cur_pos, cur_size)

	# Xử lý rút máu người chơi nếu đứng ngoài vòng bo
	if player != null and is_instance_valid(player) and "global_position" in player:
		var p_pos: Vector2 = player.global_position
		if not current_zone.has_point(p_pos):
			# Đứng ngoài vòng bo -> Bị độc khí rút máu từ từ tới chết
			var max_hp: float = 1000.0
			if "combat_stats" in player and player.combat_stats != null:
				max_hp = float(player.combat_stats.max_hp)
			var damage: float = max_hp * poison_damage_rate * delta
			if player.has_method("take_damage"):
				player.take_damage(damage)
			elif "health" in player:
				player.health -= damage

	if circle_updated.is_valid():
		circle_updated.call()

## Kết thúc trận đấu PUBG: Khôi phục lại toàn bộ dữ liệu gốc, xoá toàn bộ đồ nhặt được trong trận, rời phòng
static func end_match(profile: PlayerProfile = null) -> void:
	is_active = false
	active_bot_nodes.clear()
	var target_profile: PlayerProfile = profile
	if target_profile == null and GameManager and "local_profile" in GameManager:
		target_profile = GameManager.local_profile

	if not active_room.is_empty():
		var rid: String = str(active_room.get("id", ""))
		leave_room(rid, target_profile)
		active_room = {}

	if target_profile != null and not backup_profile_data.is_empty():
		var restored := PlayerProfile.from_dict(backup_profile_data)
		target_profile.copy_from(restored)
		if target_profile.has_signal("equipment_changed"):
			target_profile.equipment_changed.emit()
		if target_profile.has_method("recalc_stats"):
			target_profile.recalc_stats()
		if SaveManager != null and SaveManager.has_signal("profile_changed"):
			SaveManager.profile_changed.emit(target_profile)
		backup_profile_data.clear()

	if GameManager and "field_map" in GameManager and GameManager.field_map is Dictionary:
		if GameManager.field_map.get("pubg", false) or GameManager.field_map.get("is_pubg", false):
			GameManager.field_map = {}

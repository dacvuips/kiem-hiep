class_name PubgManager
extends Node
## HỆ THỐNG ĐIỀU HÀNH CHẾ ĐỘ PUBG VÕ LÂM (BATTLE ROYALE)
## - Quản lý danh sách phòng (ID phòng, trạng thái, số người chơi, chế độ 1, 2, 3, 4 người)
## - Đồng đội 2-4 người xuất hiện chung 1 chỗ, không đánh được nhau, tên màu xanh dương
## - Bản đồ Tống Kim 1 (tongkim1), giới hạn ngẫu nhiên cố định 140x80 region
## - Vòng bo 7 phút co dần, hiển thị trên minimap, rút máu khi đứng ngoài bo
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

## ==============================================================================
## VÒNG BO (hình tròn) — 5 lần co, lần cuối co về 1 CHẤM. Thuần dữ liệu + RNG có seed để server online tính y hệt.
##   Vòng 0 phủ kín khung chơi. Mỗi lần bo: chờ ZONE_WAIT_SECS[i] (đã hiện vòng kế tiếp) -> co trong ZONE_SHRINK_SECS[i].
##   Tâm vòng mới ngẫu nhiên, luôn nằm TRỌN trong vòng trước và trong khung chơi (vòng cuối bán kính 0 = 1 điểm).
##   Ngoài bo mất % máu tối đa mỗi giây, bo càng nhỏ mất càng nhiều. Hết mỗi lần co -> đổi thời tiết ngẫu nhiên (thời tiết Sơn Trang).
## ==============================================================================
const ZONE_COUNT := 5
## Thời gian từng lần bo (giây), phần tử i = lần bo thứ i+1: chờ (đã hiện vòng kế tiếp) rồi co.
##   Bo 1: 4 + 3 = 7 phút | Bo 2–3: 3,5 + 2,5 = 6 phút | Bo 4–5: 3 + 2 = 5 phút.
const ZONE_WAIT_SECS := [240.0, 210.0, 210.0, 180.0, 180.0]
const ZONE_SHRINK_SECS := [180.0, 150.0, 150.0, 120.0, 120.0]

## Thời gian chờ / co của lần bo thứ `i` (0..ZONE_COUNT-1, = zone_index lúc đang chờ/co lần đó).
static func zone_wait_sec(i: int) -> float:
	return ZONE_WAIT_SECS[clampi(i, 0, ZONE_COUNT - 1)]

static func zone_shrink_sec(i: int) -> float:
	return ZONE_SHRINK_SECS[clampi(i, 0, ZONE_COUNT - 1)]
## Bán kính từng vòng theo tỉ lệ vòng 0 (vòng 0 = nửa đường chéo khung chơi). Phần tử cuối = 0 -> 1 chấm.
const ZONE_RADIUS_FRAC := [1.0, 0.55, 0.30, 0.15, 0.06, 0.0]
## % máu tối đa mất mỗi giây khi đứng ngoài vòng thứ i (vòng càng nhỏ càng đau).
const ZONE_DPS_FRAC := [0.01, 0.015, 0.025, 0.04, 0.06, 0.10]
const ZONE_TICK_SEC := 1.0
## Mốc báo trước khi bo co (giây còn lại) -> sự kiện "warn_120" / "warn_60" + thoại audio/sfx/pubg/zone_warn_<giây>.mp3
const ZONE_WARN_SEC := [120, 60]
const WEATHER_COUNT := 6          ## FarmTimeSystem.Weather: SUNNY..WINDY

static var fixed_outer_boundary: Rect2 = Rect2() # Khung sáng cố định 140 region x 80 region
static var zone_center: Vector2 = Vector2.ZERO      ## vòng an toàn đang có (co mượt khi đang thu)
static var zone_radius: float = 0.0
static var zone_next_center: Vector2 = Vector2.ZERO ## vòng sắp co tới
static var zone_next_radius: float = 0.0
static var zone_index: int = 0                      ## số lần bo đã co xong (0..ZONE_COUNT)
static var zone_shrinking: bool = false
static var zone_timer: float = 240.0        ## giây còn lại của giai đoạn hiện tại (chờ / co)
static var zone_from_center: Vector2 = Vector2.ZERO
static var zone_from_radius: float = 0.0
static var zone_rng := RandomNumberGenerator.new()
static var zone_seed: int = 0
static var weather: int = 0                         ## FarmTimeSystem.Weather
static var _zone_tick_accum: float = 0.0
## Tương thích code cũ (minimap...): hình chữ nhật bao ngoài vòng hiện tại / vòng kế tiếp.
static var current_zone: Rect2 = Rect2()
static var next_safe_zone: Rect2 = Rect2()
static var circle_phase: int = 1

# Signal thông báo cho HUD / Minimap
static var circle_updated: Callable
## Sự kiện vòng bo cho HUD: "shrink_start" | "shrink_end" | "final".
static var zone_event: Callable

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

# ==============================================================================
# QUY TẮC PHÒNG & GHÉP TRẬN (thuần dữ liệu — server PUBG online sau này dùng lại y nguyên)
# ==============================================================================
const MATCH_PLAYERS := 50          ## quy mô 1 trận
const MATCH_SEARCH_SEC := 60.0     ## tối đa thời gian tìm trận, hết giờ vào với số người đã tìm được
const BACKFILL_MAX_SEC := 300.0    ## trận đã đấu dưới 5 phút còn nhận người thay bot
const STATUS_WAITING := "Đang Đợi"
const STATUS_FULL := "Sẵn Sàng"
const STATUS_SEARCHING := "Đang Tìm Trận"
const STATUS_PLAYING := "Đang Đấu"

## GIỜ MỞ: chỉ được tạo đội / vào đội / tìm trận trong khung giờ này mỗi ngày (giờ máy; online sẽ lấy giờ server).
## Trận đã bắt đầu thì đánh tiếp tới hết dù quá giờ đóng.
const OPEN_HOUR := 20
const OPEN_MINUTE := 0
const OPEN_DURATION_MIN := 120     ## 20:00 – 22:00
## Bỏ giới hạn giờ (test / máy dev): đặt biến môi trường KIEMHIEP_PUBG_ALWAYS_OPEN=1 hoặc gán true trong test.
static var schedule_bypass: bool = OS.get_environment("KIEMHIEP_PUBG_ALWAYS_OPEN") == "1"

static func _open_start_sec() -> int:
	return OPEN_HOUR * 3600 + OPEN_MINUTE * 60

## Giây hiện tại trong ngày theo giờ máy (0..86399).
static func now_sec_of_day() -> int:
	var t := Time.get_time_dict_from_system()
	return int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second)

## Thuần dữ liệu: giây `sec` trong ngày có nằm trong giờ mở không (khung giờ được phép vắt qua nửa đêm).
static func is_open_at(sec: int) -> bool:
	var d := posmod(sec - _open_start_sec(), 86400)
	return d < OPEN_DURATION_MIN * 60

static func secs_until_open(sec: int) -> int:
	return 0 if is_open_at(sec) else posmod(_open_start_sec() - sec, 86400)

static func secs_until_close(sec: int) -> int:
	if not is_open_at(sec):
		return 0
	return OPEN_DURATION_MIN * 60 - posmod(sec - _open_start_sec(), 86400)

static func is_gm() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var api = tree.root.get_node_or_null("AccountApi")
		if api != null and api.has_method("is_gm"):
			return api.is_gm()
	return false

static func is_open() -> bool:
	return schedule_bypass or is_gm() or is_open_at(now_sec_of_day())

static func schedule_text() -> String:
	var end := _open_start_sec() + OPEN_DURATION_MIN * 60
	return "%02d:%02d – %02d:%02d hằng ngày" % [OPEN_HOUR, OPEN_MINUTE, (end / 3600) % 24, (end / 60) % 60]

static func fmt_hms(secs: int) -> String:
	return "%02d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]

## Câu báo khi chưa tới giờ ("" = đang mở).
static func closed_reason() -> String:
	if is_open():
		return ""
	return "Chiến Trường Sinh Tồn chỉ mở %s.\nCòn %s nữa mới mở." % [schedule_text(), fmt_hms(secs_until_open(now_sec_of_day()))]

## KHU VỰC MÁY CHỦ: chỉ ghép trận / vào đội với người cùng máy chủ game.
## Phòng không ghi server_id (phòng mẫu offline) coi như thuộc mọi máy chủ.
static func same_server(room: Dictionary, server_id: int) -> bool:
	return server_id <= 0 or not room.has("server_id") or int(room.get("server_id", 0)) == server_id

## TỰ GHÉP ĐỘI (fill): đội chưa đủ người + bật tự ghép -> số chỗ trống sẽ được ghép người lạ khi vào trận.
static func fill_slots(room: Dictionary, members_count: int) -> int:
	if not bool(room.get("fill", false)):
		return 0
	return maxi(0, clampi(int(room.get("mode", 1)), 1, 4) - members_count)

## Số người tối đa 1 trận theo kiểu đội: luôn chia hết cho số người mỗi đội (Squad 4 -> 12 đội = 48 người).
static func match_capacity(mode: int) -> int:
	var m := clampi(mode, 1, 4)
	return (MATCH_PLAYERS / m) * m

## Đồ HOÀNG KIM chỉ được vứt bỏ trong trận PUBG (đồ trong trận vốn mất hết khi hết trận); ngoài PUBG thì giữ lại.
## Trả "" = được vứt, ngược lại là câu báo. Server online gọi với in_pubg = false (chưa có máy chủ PUBG online).
const GOLD_DISCARD_BLOCKED := "Đồ Hoàng Kim chỉ vứt bỏ được trong trận PUBG."
static func discard_block_reason(item: ItemInstance, in_pubg: bool) -> String:
	if item != null and item.is_gold() and not in_pubg:
		return GOLD_DISCARD_BLOCKED
	return ""

## Mã phòng PUBG-xxxx không trùng với phòng đang có.
static func new_room_id() -> String:
	init_default_rooms()
	for _i in range(200):
		var id := "PUBG-%04d" % randi_range(1000, 9999)
		if find_room(id).is_empty():
			return id
	return "PUBG-%d" % (Time.get_ticks_msec() % 100000)

static func find_room(room_id: String) -> Dictionary:
	var want := room_id.strip_edges().to_upper()
	for r in rooms:
		if str(r.get("id", "")).to_upper() == want:
			return r
	return {}

## Chuẩn hoá mã người chơi gõ: "pubg 1024", "PUBG_1024", "1024" -> "PUBG-1024".
static func normalize_room_code(raw: String) -> String:
	var s := raw.strip_edges().to_upper().replace(" ", "").replace("_", "-")
	if s == "":
		return ""
	return "PUBG-" + s.trim_prefix("PUBG").trim_prefix("-")

## Phòng còn nhận người vào phòng chờ không ("" = được, ngược lại là lý do từ chối).
static func join_block_reason(room: Dictionary, members_count: int, server_id: int = 0) -> String:
	if room.is_empty():
		return "not_found"
	if not same_server(room, server_id):
		return "other_server"
	var st := str(room.get("status", ""))
	if st == STATUS_PLAYING:
		return "playing"
	if st == STATUS_SEARCHING:
		return "searching"
	if members_count >= int(room.get("mode", 1)):
		return "full"
	return ""

## Trạng thái phòng chờ theo số thành viên (không đụng phòng đang tìm trận / đang đấu).
static func waiting_status(room: Dictionary, members_count: int) -> String:
	var st := str(room.get("status", ""))
	if st == STATUS_SEARCHING or st == STATUS_PLAYING:
		return st
	return STATUS_FULL if members_count >= int(room.get("mode", 1)) else STATUS_WAITING

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
static func find_joinable_active_match(required_slots: int = 1, exclude_room_id: String = "", server_id: int = 0) -> Dictionary:
	init_default_rooms()
	var now: float = Time.get_unix_time_from_system()
	for r in rooms:
		var rid: String = str(r.get("id", ""))
		if exclude_room_id != "" and rid == exclude_room_id:
			continue
		if not same_server(r, server_id):
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
	start_zone(fixed_outer_boundary, randi())

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

	# Đồng đội = thành viên phòng đội (gồm cả người lạ được tự ghép). Phòng không có danh sách thành viên
	# (gọi thẳng từ test / bản cũ) thì lấp đủ đội bằng tên mẫu.
	var mate_names: Array[String] = []
	if room.get("members", null) is Array:
		for m in room["members"]:
			if m is Dictionary and not bool(m.get("is_self", false)):
				mate_names.append(str(m.get("name", "")))
		current_squad_size = mate_names.size() + 1
	else:
		var bot_names := ["LýTầmHoan", "SởLưuHương", "LụcTiểuPhụng", "HoaMãnLâu"]
		for i in range(1, current_squad_size):
			mate_names.append(bot_names[(i - 1) % bot_names.size()])
	for mate_name in mate_names:
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
## Bắt đầu vòng bo cho 1 trận: vòng 0 phủ kín khung chơi, tính sẵn vòng 1 (hiện trên minimap ngay từ đầu).
static func start_zone(box: Rect2, seed_value: int) -> void:
	zone_seed = seed_value
	zone_rng.seed = seed_value
	zone_index = 0
	zone_shrinking = false
	zone_timer = zone_wait_sec(0)
	_zone_tick_accum = 0.0
	zone_center = box.get_center()
	zone_radius = box.size.length() * 0.5
	zone_from_center = zone_center
	zone_from_radius = zone_radius
	weather = zone_rng.randi_range(0, WEATHER_COUNT - 1)
	_plan_next_zone(box)
	_sync_zone_rects()

## Bán kính vòng thứ i (0..ZONE_COUNT) theo khung chơi.
static func zone_radius_for(i: int, box: Rect2) -> float:
	return box.size.length() * 0.5 * float(ZONE_RADIUS_FRAC[clampi(i, 0, ZONE_COUNT)])

## Tâm vòng mới: ngẫu nhiên đều trong đĩa bán kính (r_cũ - r_mới) quanh tâm cũ => vòng mới nằm trọn trong vòng cũ;
## đồng thời tâm phải nằm trong khung chơi (thử lại, không được thì kéo về điểm gần nhất hợp lệ).
static func pick_zone_center(prev_c: Vector2, prev_r: float, new_r: float, box: Rect2, rng: RandomNumberGenerator) -> Vector2:
	var slack := maxf(0.0, prev_r - new_r)
	var inner := box.grow(-minf(new_r, minf(box.size.x, box.size.y) * 0.45))   ## vòng mới cũng không lòi quá ra ngoài khung
	for _i in range(40):
		var ang := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * slack
		var c := prev_c + Vector2(cos(ang), sin(ang)) * dist
		if inner.has_point(c):
			return c
	var clamped := Vector2(clampf(prev_c.x, inner.position.x, inner.end.x), clampf(prev_c.y, inner.position.y, inner.end.y))
	var off := clamped - prev_c
	if off.length() > slack:
		clamped = prev_c + off.normalized() * slack
	return clamped

static func _plan_next_zone(box: Rect2) -> void:
	if zone_index >= ZONE_COUNT:
		zone_next_center = zone_center
		zone_next_radius = zone_radius
		return
	var new_r := zone_radius_for(zone_index + 1, box)
	zone_next_radius = new_r
	zone_next_center = pick_zone_center(zone_center, zone_radius, new_r, box, zone_rng)

static func _sync_zone_rects() -> void:
	current_zone = Rect2(zone_center - Vector2(zone_radius, zone_radius), Vector2(zone_radius, zone_radius) * 2.0)
	next_safe_zone = Rect2(zone_next_center - Vector2(zone_next_radius, zone_next_radius), Vector2(zone_next_radius, zone_next_radius) * 2.0)
	circle_phase = zone_index + 1

## Vòng bo co tiếp theo thời gian. Trả về sự kiện: "" | "shrink_start" | "shrink_end" (kèm đổi thời tiết) | "final".
static func tick_zone(delta: float) -> String:
	if zone_index >= ZONE_COUNT:
		return ""
	var ev := ""
	var before := zone_timer
	zone_timer -= delta
	if not zone_shrinking:
		# Báo trước khi bo bắt đầu thu hẹp (kèm thoại)
		for w in ZONE_WARN_SEC:
			if before > float(w) and zone_timer <= float(w):
				ev = "warn_%d" % w
		if zone_timer <= 0.0:
			zone_shrinking = true
			zone_timer = zone_shrink_sec(zone_index)
			zone_from_center = zone_center
			zone_from_radius = zone_radius
			ev = "shrink_start"
	else:
		var t := clampf(1.0 - zone_timer / zone_shrink_sec(zone_index), 0.0, 1.0)
		zone_center = zone_from_center.lerp(zone_next_center, t)
		zone_radius = lerpf(zone_from_radius, zone_next_radius, t)
		if zone_timer <= 0.0:
			zone_center = zone_next_center
			zone_radius = zone_next_radius
			zone_shrinking = false
			zone_index += 1
			zone_timer = zone_wait_sec(zone_index)
			weather = roll_weather(weather, zone_rng)
			_plan_next_zone(fixed_outer_boundary)
			ev = "final" if zone_index >= ZONE_COUNT else "shrink_end"
	_sync_zone_rects()
	return ev

## Thời tiết mới (khác thời tiết đang có) — bộ thời tiết của Sơn Trang (FarmTimeSystem.Weather).
static func roll_weather(cur: int, rng: RandomNumberGenerator) -> int:
	var w := rng.randi_range(0, WEATHER_COUNT - 2)
	return w + 1 if w >= cur else w

## Vùng an toàn = vòng tròn ∩ khung chơi: lúc đầu vòng ôm trọn khung nên mép bo CHÍNH LÀ đường sáng giới hạn màn chơi;
## co lại thì các góc khung bị cắt trước rồi mới thành vòng tròn.
static func zone_contains(p: Vector2) -> bool:
	if fixed_outer_boundary.has_area() and not fixed_outer_boundary.grow(0.5).has_point(p):
		return false
	return p.distance_to(zone_center) <= zone_radius

## % máu tối đa mất mỗi giây khi đứng ngoài bo lúc này (đang co thì tính theo vòng đang co tới).
static func zone_dps_frac() -> float:
	var i := zone_index + (1 if zone_shrinking else 0)
	return float(ZONE_DPS_FRAC[clampi(i, 0, ZONE_DPS_FRAC.size() - 1)])

## Cập nhật vòng bo mỗi frame trong trận + trừ máu ai đứng ngoài bo (mỗi ZONE_TICK_SEC giây, sát thương thật bỏ qua phòng thủ).
static func update_circle(delta: float, player: Node) -> void:
	if not is_active:
		return
	var ev := tick_zone(delta)
	if ev != "" and zone_event.is_valid():
		zone_event.call(ev)

	_zone_tick_accum += delta
	if _zone_tick_accum >= ZONE_TICK_SEC:
		_zone_tick_accum -= ZONE_TICK_SEC
		var targets: Array = [player]
		targets.append_array(active_bot_nodes)
		for t in targets:
			_apply_zone_damage(t)

	if circle_updated.is_valid():
		circle_updated.call()

## Máu mất mỗi giây của 1 nhân vật đứng ngoài bo (0 nếu đang trong bo).
static func zone_damage_for(max_hp: float, p: Vector2) -> float:
	if zone_contains(p):
		return 0.0
	return maxf(1.0, ceilf(max_hp * zone_dps_frac() * ZONE_TICK_SEC))

static func _apply_zone_damage(n: Variant) -> void:
	if n == null or not is_instance_valid(n) or not (n is Node2D):
		return
	var node := n as Node2D
	var max_hp: float = float(node.get("max_health")) if node.get("max_health") != null else 1000.0
	var dmg := zone_damage_for(max_hp, node.global_position + Vector2(0, 30))
	if dmg <= 0.0:
		return
	if node.has_method("take_status_damage"):
		node.take_status_damage(dmg, "pubg_zone")
	elif node.has_method("take_damage"):
		node.take_damage(dmg)

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

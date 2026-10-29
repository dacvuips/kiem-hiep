extends RefCounted
class_name PkRules
## Luật PK (nút "PK" ở Character Hub) — 3 chế độ:
##   - ĐẠI HỘI VÕ LÂM (missions/championship): đấu 1 chọi 1 với người CÙNG MÔN PHÁI (mỗi phái 1 cặp map hội trường/đấu trường
##     396..415), cấp >= 90 (npc/manager.lua: GetLevel() < 90 thì không cho vào), chuẩn bị 10 giây (MATCH_TIMER_1), trận 10 phút
##     (MATCH_TIMER_2); chỉ người của môn phái mới được tham gia (freshman_match/head.lua). Không thể đá đối thủ. Thắng +10, thua -2 điểm BXH.
##   - VÕ LÂM LIÊN ĐẤU (missions/leaguematch): đấu với mọi phái, cấp >= 80 (WLLS_LEVEL_JUNIOR; >= 120 là hạng cao cấp
##     WLLS_LEVEL_SENIOR), chuẩn bị 2 x 5 giây, trận 120 x 5 giây = 10 phút (WLLS_TIMER_FIGHT_*). Không thể đá đối thủ. Thắng +10, thua -2 điểm BXH.
##   - THÁCH ĐẤU: đấu trường tự do so tài võ nghệ giữa các hiệp khách, người thách đấu tạo phòng chờ hoặc vào phòng theo tên/ID.
##     Trong trận có nút "Từ chối đối thủ" để đá đối thủ ra và không bắt đầu trận. Không tính điểm xếp hạng võ lâm.
## Đấu trường: map 397 "Đấu Trường Liên Đấu Kiệt Xuất" (khối giữa, tools/export_pk_arena.py).
## Ghép đối thủ (thiết kế của game này): chênh lệch cấp <= MATCH_LEVEL_DIFF; tìm quá MATCH_WAIT_SEC giây không có người thì
## đấu với bot cùng cấp (PkBotProfile).

enum Mode {
	DAI_HOI = 0,
	LIEN_DAU = 1,
	THACH_DAU = 2,
	TONG_KIM_LOL = 3,
	LON_XON = 4,
	VAN_TIEU = 5,
}

const MODE_NAMES := {
	Mode.DAI_HOI: "Đại hội võ lâm",
	Mode.LIEN_DAU: "Võ lâm Liên đấu",
	Mode.THACH_DAU: "Thách đấu",
	Mode.TONG_KIM_LOL: "Tống Kim LOL",
	Mode.LON_XON: "Lộn xộn",
	Mode.VAN_TIEU: "Vận Tiêu (Long Môn Tiêu Cục)",
}
const MIN_LEVEL := {
	Mode.DAI_HOI: 90,
	Mode.LIEN_DAU: 80,
	Mode.THACH_DAU: 10,
	Mode.TONG_KIM_LOL: 10,
	Mode.LON_XON: 10,
	Mode.VAN_TIEU: 30,
}
const SENIOR_LEVEL := 120                ## Liên đấu: từ cấp này là hạng cao cấp
const PREPARE_SEC := 3.0
const FIGHT_SEC := 600.0
const MATCH_LEVEL_DIFF := 10
const MATCH_WAIT_SEC := 60.0
const LEAVE_AFTER_SEC := 8.0

const WIN_POINTS := 10
const LOSE_POINTS := 2

## Xử lý điểm PK khi giết người chơi / bot:
##   - Chỉ khi KHI CHẾT, thủ phạm ĐANG Ở TRẠNG THÁI ĐỒ SÁT (killer_pk_mode == 2) và nạn nhân không phải đồ sát: +1 điểm PK (tối đa 10).
##   - Nếu thủ phạm đã tắt đồ sát về Chiến Đấu (killer_pk_mode == 1) hoặc Luyện Công / Bình Thường (killer_pk_mode == 0),
##     dù nạn nhân chết do trúng độc rút hay đòn trước đó: KHÔNG bị cộng điểm PK.
static func handle_murder_kill(killer_profile: PlayerProfile, killer_pk_mode: int, victim_is_murder: bool = false) -> bool:
	if killer_profile == null:
		return false
	if killer_pk_mode == 2 and not victim_is_murder:
		killer_profile.pk_value = mini(10, killer_profile.pk_value + 1)
		return true
	return false

## Các thể thức thách đấu: 1vs1, 2vs2, ..., 8vs8
const TEAM_FORMATS := [1, 2, 3, 4, 5, 6, 7, 8]

static func format_name(team_size: int) -> String:
	var s := clampi(team_size, 1, 8)
	return "%dvs%d" % [s, s]

static func team_size_for(room: Dictionary) -> int:
	return clampi(int(room.get("team_size", 1)), 1, 8)

## Vị trí đứng của 2 đội (tối đa 8 người mỗi đội): Đội A bên trái, Đội B bên phải.
static func get_spawn_slots(arena_center: Vector2, team_size: int) -> Dictionary:
	var slots_a: Array[Vector2] = []
	var slots_b: Array[Vector2] = []
	var count := clampi(team_size, 1, 8)
	var spacing := 48.0
	for i in count:
		var y_off := (float(i) - float(count - 1) / 2.0) * spacing
		slots_a.append(arena_center + Vector2(-200.0, y_off))
		slots_b.append(arena_center + Vector2(200.0, y_off))
	return {"team_a": slots_a, "team_b": slots_b}

const ARENA_MAP_ID := 397
const ARENA_MAP_NAME := "Đấu Trường Liên Đấu Kiệt Xuất"
const ARENA_DIR := "res://world/maps/map_397"
## Tâm sàn đấu chính giữa của đấu trường (trung tâm sàn đấu có sàn gạch bằng phẳng, tránh rơi vào tường/vùng rìa kẹt rào)
const ARENA_CENTER := Vector2(53136.0, 54696.0)

const BRAWL_MAPS := [
	{
		"id": 319,
		"name": "Lâm Du Quan",
		"dir": "res://world/maps/map_319",
		"desc": "Map 8x - Cửa ải quan ải hiểm địa"
	},
	{
		"id": 320,
		"name": "Chân Núi Trường Bạch (9x)",
		"dir": "res://world/maps/map_320",
		"desc": "Map 9x - Vùng đồi tuyết hiểm trở"
	},
	{
		"id": 336,
		"name": "Phong Lăng Độ (12x)",
		"dir": "res://world/maps/map_336",
		"desc": "Map 12x - Bến đò giông bão"
	}
]

static func get_brawl_map_info(map_id: int) -> Dictionary:
	for m in BRAWL_MAPS:
		if int(m["id"]) == map_id:
			return m
	return BRAWL_MAPS[0]

## Lời giới thiệu ở popup PK (theo lời NPC gốc).
const MODE_INTRO := {
	Mode.DAI_HOI: "Võ Lâm Minh Chủ có lệnh: chỉ người của môn phái mới được tham gia Đại hội võ lâm. Đấu 1 chọi 1 với cao thủ cùng phái. Thắng +10, thua -2 điểm BXH.",
	Mode.LIEN_DAU: "Võ lâm Liên đấu: cao thủ mọi môn phái so tài 1 chọi 1, ai cũng có thể ghi danh. Thắng +10, thua -2 điểm BXH.",
	Mode.THACH_DAU: "Thách đấu võ nghệ: Đấu trường tự do tỷ thí võ nghệ giữa các hiệp khách. Chủ phòng có thể từ chối đối thủ trước khi bắt đầu. Không tính điểm xếp hạng.",
	Mode.LON_XON: "Đấu trường Lộn Xộn: Chế độ Loạn Đả tự do (16 người) và Đấu đội sinh tử (1vs1 đến 8vs8) trên các bản đồ 9x, 12x, Lâm Du Quan. Mỗi mạng hạ gục nhận 300 điểm, bị diệt trừ 100 điểm. Kết thúc trận quy đổi x30 điểm thành EXP thực tế!",
	Mode.TONG_KIM_LOL: "Ải Tống Kim LOL: Bảo vệ Tướng Soái, công phá 3 cổng, diệt lính và Boss Hoàng Kim theo phong cách đối kháng MOBA (1vs1 đến 5vs5).",
	Mode.VAN_TIEU: "Long Môn Tiêu Cục (Vận Tiêu Cá Nhân): Hộ tống tiêu xa xuyên suốt đại đô thành Biện Kinh vào Thứ Bảy & Chủ Nhật (Tối đa 3 lần/ngày). Chia làm 2 phe đối kháng: Phe Hộ Tiêu (Bảo vệ tiêu xa tới đích) và Phe Cướp Tiêu (Chặn đánh cướp tiêu đoạt bảo). Khi chết xem như thất bại nhưng không bị mất lượt.",
}

## Chế độ có cho phép chủ phòng từ chối/đá đối thủ ra không
static func can_kick(mode: Mode) -> bool:
	return mode == Mode.THACH_DAU or mode == Mode.TONG_KIM_LOL or mode == Mode.LON_XON or mode == Mode.VAN_TIEU

## Chế độ có tính điểm trên bảng xếp hạng không
static func has_rank_points(mode: Mode) -> bool:
	return mode != Mode.THACH_DAU and mode != Mode.TONG_KIM_LOL and mode != Mode.LON_XON and mode != Mode.VAN_TIEU

## Lý do không vào được chế độ này ("" = được).
static func check_entry(profile: PlayerProfile, mode: Mode) -> String:
	if profile == null:
		return "Chưa có nhân vật."
	if mode == Mode.DAI_HOI and not profile.has_sect():
		return "Chỉ người của môn phái mới được tham gia Đại hội võ lâm."
	if mode == Mode.VAN_TIEU:
		var esc_win: GDScript = load("res://ui/events/escort_window.gd")
		if not esc_win.is_escort_day():
			return "Vận tiêu chỉ mở vào Thứ Bảy và Chủ Nhật hàng tuần!"
		var runs: int = esc_win.get_runs_today(profile)
		if runs >= esc_win.RUNS_PER_DAY:
			return "Hôm nay đại hiệp đã hoàn thành đủ %d/3 chuyến tiêu rồi!" % esc_win.RUNS_PER_DAY
	var need := int(MIN_LEVEL.get(mode, 1))
	if profile.level < need:
		return "Cần đạt cấp %d mới được tham gia %s." % [need, MODE_NAMES.get(mode, "")]
	return ""

## 2 người có ghép được không: Đại hội võ lâm phải cùng phái; không chặn chênh lệch cấp.
static func can_match(mode: Mode, _level_a: int, sect_a: String, _level_b: int, sect_b: String) -> bool:
	if mode == Mode.DAI_HOI:
		return sect_a == sect_b
	return true

## Mục "map" đưa cho Character Hub (GameManager.field_map) để vào đấu trường. `pk` = {mode, room_id, opponent: hồ sơ bot (dict)}.
static func arena_entry(pk: Dictionary) -> Dictionary:
	var m := int(pk.get("mode", Mode.LIEN_DAU))
	if m == Mode.VAN_TIEU:
		var cart_dict: Dictionary = pk.get("cart", {})
		var role: String = str(pk.get("side", "defender"))
		var esc_script: GDScript = load("res://systems/challenge/escort_challenge.gd")
		var entry: Dictionary = esc_script.map_entry(cart_dict, role)
		entry["pk"] = pk
		entry["room"] = pk
		return entry
	if m == Mode.TONG_KIM_LOL:
		return {
			"id": TongKimLolRules.MAP_ID,
			"name": TongKimLolRules.MAP_NAME,
			"dir": TongKimLolRules.MAP_DIR,
			"level": 1,
			"tong_kim_lol": true,
			"pk": pk,
			"room": pk
		}
	if m == Mode.LON_XON:
		var map_id: int = int(pk.get("map_id", pk.get("action", {}).get("map_id", 319)))
		var map_info := get_brawl_map_info(map_id)
		return {
			"id": map_id,
			"name": map_info.get("name", "Lâm Du Quan"),
			"dir": map_info.get("dir", "res://world/maps/map_319"),
			"level": 1,
			"brawl": true,
			"pk": pk,
			"room": pk
		}
	return {"id": ARENA_MAP_ID, "name": ARENA_MAP_NAME, "dir": ARENA_DIR, "level": 1, "pk": pk, "arena_center": ARENA_CENTER}

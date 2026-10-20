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

enum Mode { DAI_HOI, LIEN_DAU, THACH_DAU }

const MODE_NAMES := {
	Mode.DAI_HOI: "Đại hội võ lâm",
	Mode.LIEN_DAU: "Võ lâm Liên đấu",
	Mode.THACH_DAU: "Thách đấu",
}
const MIN_LEVEL := {
	Mode.DAI_HOI: 90,
	Mode.LIEN_DAU: 80,
	Mode.THACH_DAU: 10,
}
const SENIOR_LEVEL := 120                ## Liên đấu: từ cấp này là hạng cao cấp
const PREPARE_SEC := 10.0
const FIGHT_SEC := 600.0
const MATCH_LEVEL_DIFF := 10
const MATCH_WAIT_SEC := 60.0
const LEAVE_AFTER_SEC := 8.0

const WIN_POINTS := 10
const LOSE_POINTS := 2

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

## Lời giới thiệu ở popup PK (theo lời NPC gốc).
const MODE_INTRO := {
	Mode.DAI_HOI: "Võ Lâm Minh Chủ có lệnh: chỉ người của môn phái mới được tham gia Đại hội võ lâm. Đấu 1 chọi 1 với cao thủ cùng phái. Thắng +10, thua -2 điểm BXH.",
	Mode.LIEN_DAU: "Võ lâm Liên đấu: cao thủ mọi môn phái so tài 1 chọi 1, ai cũng có thể ghi danh. Thắng +10, thua -2 điểm BXH.",
	Mode.THACH_DAU: "Thách đấu võ nghệ: Đấu trường tự do tỷ thí võ nghệ giữa các hiệp khách. Chủ phòng có thể từ chối đối thủ trước khi bắt đầu. Không tính điểm xếp hạng.",
}

## Chế độ có cho phép chủ phòng từ chối/đá đối thủ ra không
static func can_kick(mode: Mode) -> bool:
	return mode == Mode.THACH_DAU

## Chế độ có tính điểm trên bảng xếp hạng không
static func has_rank_points(mode: Mode) -> bool:
	return mode != Mode.THACH_DAU

## Lý do không vào được chế độ này ("" = được).
static func check_entry(profile: PlayerProfile, mode: Mode) -> String:
	if profile == null:
		return "Chưa có nhân vật."
	if mode == Mode.DAI_HOI and not profile.has_sect():
		return "Chỉ người của môn phái mới được tham gia Đại hội võ lâm."
	var need := int(MIN_LEVEL.get(mode, 1))
	if profile.level < need:
		return "Cần đạt cấp %d mới được tham gia %s." % [need, MODE_NAMES.get(mode, "")]
	return ""

## 2 người có ghép được không: chênh cấp <= MATCH_LEVEL_DIFF; Đại hội võ lâm phải cùng phái; Thách đấu tự do.
static func can_match(mode: Mode, level_a: int, sect_a: String, level_b: int, sect_b: String) -> bool:
	if mode == Mode.THACH_DAU:
		return true
	if absi(level_a - level_b) > MATCH_LEVEL_DIFF:
		return false
	return mode != Mode.DAI_HOI or sect_a == sect_b

## Mục "map" đưa cho Character Hub (GameManager.field_map) để vào đấu trường. `pk` = {mode, room_id, opponent: hồ sơ bot (dict)}.
static func arena_entry(pk: Dictionary) -> Dictionary:
	return {"id": ARENA_MAP_ID, "name": ARENA_MAP_NAME, "dir": ARENA_DIR, "level": 1, "pk": pk, "arena_center": ARENA_CENTER}

extends RefCounted
class_name PkRules
## Luật PK (nút "PK" ở Character Hub) — 2 chế độ lấy từ script gốc VLTK 15 phái:
##   - ĐẠI HỘI VÕ LÂM (missions/championship): đấu 1 chọi 1 với người CÙNG MÔN PHÁI (mỗi phái 1 cặp map hội trường/đấu trường
##     396..415), cấp >= 90 (npc/manager.lua: GetLevel() < 90 thì không cho vào), chuẩn bị 10 giây (MATCH_TIMER_1), trận 10 phút
##     (MATCH_TIMER_2); chỉ người của môn phái mới được tham gia (freshman_match/head.lua).
##   - VÕ LÂM LIÊN ĐẤU (missions/leaguematch): đấu với mọi phái, cấp >= 80 (WLLS_LEVEL_JUNIOR; >= 120 là hạng cao cấp
##     WLLS_LEVEL_SENIOR), chuẩn bị 2 x 5 giây, trận 120 x 5 giây = 10 phút (WLLS_TIMER_FIGHT_*).
## Đấu trường: map 397 "Đấu Trường Liên Đấu Kiệt Xuất" (khối giữa, tools/export_pk_arena.py).
## Ghép đối thủ (thiết kế của game này): chênh lệch cấp <= MATCH_LEVEL_DIFF; tìm quá MATCH_WAIT_SEC giây không có người thì
## đấu với bot cùng cấp (PkBotProfile).

enum Mode { DAI_HOI, LIEN_DAU }

const MODE_NAMES := {Mode.DAI_HOI: "Đại hội võ lâm", Mode.LIEN_DAU: "Võ lâm Liên đấu"}
const MIN_LEVEL := {Mode.DAI_HOI: 90, Mode.LIEN_DAU: 80}
const SENIOR_LEVEL := 120                ## Liên đấu: từ cấp này là hạng cao cấp
const PREPARE_SEC := 10.0
const FIGHT_SEC := 600.0
const MATCH_LEVEL_DIFF := 10
const MATCH_WAIT_SEC := 60.0
const LEAVE_AFTER_SEC := 8.0

const ARENA_MAP_ID := 397
const ARENA_MAP_NAME := "Đấu Trường Liên Đấu Kiệt Xuất"
const ARENA_DIR := "res://world/maps/map_397"

## Lời giới thiệu ở popup PK (theo lời NPC gốc).
const MODE_INTRO := {
	Mode.DAI_HOI: "Võ Lâm Minh Chủ có lệnh: chỉ người của môn phái mới được tham gia Đại hội võ lâm. Đấu 1 chọi 1 với cao thủ cùng phái.",
	Mode.LIEN_DAU: "Võ lâm Liên đấu: cao thủ mọi môn phái so tài 1 chọi 1, ai cũng có thể ghi danh.",
}

## Lý do không vào được chế độ này ("" = được).
static func check_entry(profile: PlayerProfile, mode: Mode) -> String:
	if profile == null:
		return "Chưa có nhân vật."
	if mode == Mode.DAI_HOI and not profile.has_sect():
		return "Chỉ người của môn phái mới được tham gia Đại hội võ lâm."
	var need := int(MIN_LEVEL[mode])
	if profile.level < need:
		return "Cần đạt cấp %d mới được tham gia %s." % [need, MODE_NAMES[mode]]
	return ""

## 2 người có ghép được không: chênh cấp <= MATCH_LEVEL_DIFF; Đại hội võ lâm phải cùng phái.
static func can_match(mode: Mode, level_a: int, sect_a: String, level_b: int, sect_b: String) -> bool:
	if absi(level_a - level_b) > MATCH_LEVEL_DIFF:
		return false
	return mode != Mode.DAI_HOI or sect_a == sect_b

## Mục "map" đưa cho Character Hub (GameManager.field_map) để vào đấu trường. `pk` = {mode, room_id, opponent: hồ sơ bot (dict)}.
static func arena_entry(pk: Dictionary) -> Dictionary:
	return {"id": ARENA_MAP_ID, "name": ARENA_MAP_NAME, "dir": ARENA_DIR, "level": 1, "pk": pk}

extends RefCounted
class_name TongKimLolRules
## Luật & Dữ liệu cấu hình cho Ải "Tống Kim LOL" (MOBA 1vs1 - 5vs5)
## Bản đồ: map 378 (Chiến trường Tống Kim kinh điển)
## Mục tiêu: Bảo vệ Tướng Soái 2 phe, diệt lính 3 đường, trảm Boss Hoàng Kim, công phá cổng thành.

const MAP_ID := 378
const MAP_NAME := "Chiến Trường Tống Kim"
const MAP_DIR := "res://world/maps/map_378"

## Thời gian trận đấu
const MATCH_DURATION_SEC := 2400.0   ## 40 phút tối đa, quá giờ xem như Hoà
const PREPARE_SEC := 10.0             ## 10 giây chuẩn bị
const WAVE_INTERVAL_SEC := 20.0       ## 20 giây xuất 1 đợt lính (3 tốp cho 3 cổng)
const CREEP_BUFF_INTERVAL_SEC := 300.0 ## Cứ 5 phút quái x2 máu và sát thương
const BOSS_INTERVAL_SEC := 600.0      ## Cứ 10 phút xuất 1 Boss Hoàng Kim (stats x20)

## Cấp độ trong trận (Cấp ảo, reset khi rời trận)
const MIN_MATCH_LEVEL := 1
const MAX_MATCH_LEVEL := 15
const INITIAL_POTENTIAL_POINTS := 100 ## Tặng 100 điểm tiềm năng khi mới vào trận
const MAX_HIGH_SKILL_INITIAL := 5     ## Skill 9x, 150, 180 chỉ cho cộng tối đa 5 điểm ban đầu

## Thưởng trong trận & Quy đổi
const CREEP_BASE_EXP := 100.0
const CREEP_BASE_GOLD := 25
const PLAYER_KILL_EXP_MULT := 20.0    ## Giết người chơi được x20 EXP quái
const PLAYER_KILL_GOLD_MULT := 20.0   ## Giết người chơi được x20 Vàng quái
const END_EXP_REWARD_MULT := 10.0     ## Kết thúc trận thưởng EXP thực = EXP kiếm được x 10

## Thể thức phòng chờ: 1vs1, 2vs2, 3vs3, 4vs4, 5vs5
const TEAM_SIZES := [1, 2, 3, 4, 5]

## Tọa độ cốt lõi trên Map 378 (dữ liệu từ data/battle/map_378.json)
const GENERAL_SONG_POS := Vector2(42624.0, 55088.0)
const GENERAL_JIN_POS := Vector2(50272.0, 51152.0)
const HOME_SONG_POS := Vector2(42450.0, 55100.0)
const HOME_JIN_POS := Vector2(50450.0, 51150.0)
const DOCTOR_SONG_POS := Vector2(42450.0, 55100.0)
const DOCTOR_JIN_POS := Vector2(50450.0, 51150.0)
const MAP_CENTER_POS := Vector2(46448.0, 53120.0)

## 3 Cổng của Phe Tống
const GATES_SONG := [
	Vector2(41728.0, 54640.0), ## Cổng Trên (Top)
	Vector2(43456.0, 54528.0), ## Cổng Giữa (Mid)
	Vector2(43104.0, 55680.0)  ## Cổng Dưới (Bot)
]

## 3 Cổng của Phe Kim
const GATES_JIN := [
	Vector2(49344.0, 50640.0), ## Cổng Trên (Top)
	Vector2(48896.0, 51920.0), ## Cổng Giữa (Mid)
	Vector2(51488.0, 51680.0)  ## Cổng Dưới (Bot)
]

## Số lượng quái đánh xa trấn thủ trước mỗi cổng ban đầu (giảm xuống 4 để tránh quá tải/lag giật)
const GATE_GUARDIAN_COUNT := 4

## Điểm mốc trên 3 đường từ cổng Tống tới cổng Kim (để lính hành quân)
const LANE_TOP_POINTS: Array[Vector2] = [
	Vector2(41728.0, 54640.0), ## Cổng Tống Top
	Vector2(44600.0, 52400.0),
	Vector2(47600.0, 51400.0),
	Vector2(49344.0, 50640.0)  ## Cổng Kim Top
]

const LANE_MID_POINTS: Array[Vector2] = [
	Vector2(43456.0, 54528.0), ## Cổng Tống Mid
	Vector2(46448.0, 53120.0), ## Trung tâm Map
	Vector2(48896.0, 51920.0)  ## Cổng Kim Mid
]

const LANE_BOT_POINTS: Array[Vector2] = [
	Vector2(43104.0, 55680.0), ## Cổng Tống Bot
	Vector2(46200.0, 55200.0),
	Vector2(49600.0, 53600.0),
	Vector2(51488.0, 51680.0)  ## Cổng Kim Bot
]

## Chỉ số cân bằng MOBA cho lính và Tướng Soái
const GENERAL_MAX_HP := 600000.0
const GUARDIAN_MAX_HP := 8000
const CREEP_MELEE_HP := 3500
const CREEP_RANGED_HP := 2200
const GENERAL_CAMP_RADIUS := 500.0                                    ## Bán kính giới hạn doanh trại Tướng không được rời khỏi

## Sát thương cân bằng MOBA
const CREEP_DAMAGE_MULT := 1.0                                        ## Sát thương lính thường (bộ binh & cung binh bằng nhau, vừa phải không quá lớn)
const GUARDIAN_DAMAGE_RATIO_TO_CREEP := 20.0                          ## Vệ binh canh cổng dame x20 lần lính
const GUARDIAN_DAMAGE_MULT := CREEP_DAMAGE_MULT * GUARDIAN_DAMAGE_RATIO_TO_CREEP ## 20.0
const GENERAL_DAMAGE_MULT := 10.0                                     ## Hệ số sát thương Tướng Soái (x8 boss_mult -> x80 dame cực lớn)

## Quy mô đợt lính: mỗi đợt 20 giây tăng 1 lính mỗi cổng, tối đa 10 lính / cổng
const MAX_MINIONS_PER_GATE := 10
const MAX_LANE_MINIONS_PER_SIDE := 120

static func minions_per_gate_for_wave(wave: int) -> int:
	return clampi(wave, 1, MAX_MINIONS_PER_GATE)

## Chỉ số Boss Hoàng Kim trong MOBA: Máu gấp 20 lần lính thường (3.500 * 20 = 70.000 HP), Sát thương gấp 3 lần quái thường
const GOLDEN_BOSS_HP_MULT := 20.0
const GOLDEN_BOSS_MAX_HP := int(CREEP_MELEE_HP * GOLDEN_BOSS_HP_MULT) ## 70.000 HP
const GOLDEN_BOSS_DAMAGE_MULT := 3.0                                  ## Dame gấp 3 lần quái thường

## Lấy lộ trình hành quân theo đường và phe
static func get_lane_waypoints(lane_idx: int, minion_side: String) -> Array[Vector2]:
	var base: Array[Vector2] = []
	match lane_idx:
		0:
			base = LANE_TOP_POINTS.duplicate()
		1:
			base = LANE_MID_POINTS.duplicate()
		2:
			base = LANE_BOT_POINTS.duplicate()
		_:
			base = LANE_MID_POINTS.duplicate()

	var wps: Array[Vector2] = []
	if minion_side == "song":
		wps = base
		wps.append(GENERAL_JIN_POS)
	else:
		wps = base
		wps.reverse()
		wps.append(GENERAL_SONG_POS)
	return wps

## Danh mục quái & boss mẫu
const CREEP_MELEE_TPL := 634    ## Lính giáo cận chiến
const CREEP_RANGED_TPL := 635   ## Cung thủ tầm xa
const BOSS_GOLD_SONG_IDS := [583, 744, 745] ## Boss Hoàng Kim phe Tống: Mạnh Thương Lương, Yên Hiểu Trái, Hà Nhân Ngã
const BOSS_GOLD_JIN_IDS := [563, 564, 565]  ## Boss Hoàng Kim phe Kim: Gia Luật Tị Ly, Hoàn Nhan Tuyết Y, Đoan Mộc Duệ
const BOSS_GOLD_IDS := [583, 744, 745, 563, 564, 565] ## Danh sách Boss Hoàng Kim đầy đủ

## Cửa hàng trong trận (mua bằng Vàng Tống Kim)
const SHOP_ITEMS := [
	{
		"id": "tk_phi_toc",
		"name": "Phi Tốc Đan",
		"desc": "Tăng 40% tốc độ chạy trong 20 giây",
		"price": 100,
		"icon": "res://assets/items/icons/obj-potion15.png",
		"type": "speed",
		"duration": 20.0,
		"value": 0.40
	},
	{
		"id": "tk_hoi_thien",
		"name": "Hồi Thiên Đan",
		"desc": "Hồi phục 1500 sinh lực ngay lập tức",
		"price": 60,
		"icon": "res://assets/items/icons/obj-potion02.png",
		"type": "heal_instant",
		"value": 1500
	},
	{
		"id": "tk_cuu_chuyen",
		"name": "Cửu Chuyển Hoàn Hồn Đan",
		"desc": "Hồi phục 5000 sinh lực ngay lập tức",
		"price": 180,
		"icon": "res://assets/items/icons/obj-potion03.png",
		"type": "heal_instant",
		"value": 5000
	},
	{
		"id": "tk_ngu_hoa",
		"name": "Ngũ Hoa Ngọc Lộ Hoàn",
		"desc": "Hồi 3000 sinh lực trong 10 giây",
		"price": 120,
		"icon": "res://assets/items/icons/obj-potion13.png",
		"type": "heal_hot",
		"duration": 10.0,
		"value": 3000
	},
	{
		"id": "tk_cuong_luc",
		"name": "Bùa Cuồng Lực",
		"desc": "Tăng 25% sát thương tấn công trong 30 giây",
		"price": 200,
		"icon": "res://assets/items/icons/chehuofu.png",
		"type": "damage_buff",
		"duration": 30.0,
		"value": 0.25
	},
	{
		"id": "tk_kim_cang",
		"name": "Bùa Kim Cang",
		"desc": "Giảm 25% sát thương nhận vào trong 30 giây",
		"price": 200,
		"icon": "res://assets/items/icons/chejinfu.png",
		"type": "armor_buff",
		"duration": 30.0,
		"value": 0.25
	}
]

## Bảng EXP cần để thăng cấp từ cấp 1 đến 15 trong trận
static func exp_to_next_level(lvl: int) -> float:
	var l := clampi(lvl, 1, MAX_MATCH_LEVEL)
	return float(300 + (l - 1) * 250)

## Kiểm tra skill có phải thuộc nhóm 9x, 150, 180 không
static func is_high_tier_skill(skill_def: SkillDefinition) -> bool:
	if skill_def == null:
		return false
	var req := skill_def.req_level
	return req == 90 or req == 120 or req == 150 or req == 180 or req >= 90

## Sinh entry map để nạp vào GameManager.field_map
static func make_field_entry(room_data: Dictionary) -> Dictionary:
	return {
		"id": MAP_ID,
		"name": "Tống Kim LOL",
		"dir": MAP_DIR,
		"tong_kim_lol": true,
		"room": room_data,
		"pk_online": bool(room_data.get("online", false))
	}

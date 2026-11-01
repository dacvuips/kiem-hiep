extends RefCounted
class_name CityWarRules
## Quy tắc & Cấu hình cho Công Thành Chiến (Thất Đại Thành Thị)
## Bao gồm: Danh sách 7 thành thị, Lôi Đài Oản Tù Xì (Kéo-Búa-Bao), Chiến trường 20 vs 20 trên Map 378.

const SAVE_PATH := "user://city_war_data.json"
const MAP_ID := 378
const MAP_DIR := "res://world/maps/map_378"

## Thời gian thi đấu
const NOTIFY_LEADER_TIME_SEC := 3600.0 ## Báo trước cho bang chủ 1 giờ để chọn đội hình
const RPS_CHOOSE_TIME_SEC := 1800.0    ## Thời gian 30 phút để các thành viên chọn Kéo / Búa / Bao
const MATCH_DURATION_SEC := 1200.0     ## Thời gian đánh chiến trường PK thật: 20 phút

## Số lượng thành viên tham chiến
const ROSTER_SIZE := 20 ## 20 thành viên mỗi bang

## Các lựa chọn Oản Tù Xì
enum RPSChoice {
	NONE = 0,
	ROCK = 1,     ## Búa ✊
	SCISSORS = 2, ## Kéo ✌️
	PAPER = 3     ## Bao ✋
}

static func rps_name(choice: int) -> String:
	match choice:
		RPSChoice.ROCK:
			return "Búa ✊"
		RPSChoice.SCISSORS:
			return "Kéo ✌️"
		RPSChoice.PAPER:
			return "Bao ✋"
		_:
			return "Chưa chọn (Thua) ❌"

## Kiểm tra thắng thua giữa 2 lựa chọn (1: A thắng, -1: B thắng, 0: Hòa)
static func compare_rps(a: int, b: int) -> int:
	if a == RPSChoice.NONE and b == RPSChoice.NONE:
		return 0
	if a == RPSChoice.NONE:
		return -1
	if b == RPSChoice.NONE:
		return 1
	if a == b:
		return 0
	if (a == RPSChoice.ROCK and b == RPSChoice.SCISSORS) or \
	   (a == RPSChoice.SCISSORS and b == RPSChoice.PAPER) or \
	   (a == RPSChoice.PAPER and b == RPSChoice.ROCK):
		return 1
	return -1

## Danh sách 7 Thành Thị
const CITIES: Array[Dictionary] = [
	{
		"id": "bien_kinh",
		"name": "Biện Kinh (Đô Thành)",
		"symbol": "🏯",
		"desc": "Kinh đô sầm uất bậc nhất trung nguyên, thương mại phát đạt.",
		"buff": "Tăng 15% Tấn Công Toàn Phái",
		"default_owner": "Thiên Long Bang",
		"default_master": "Long Bá Thiên",
		"tax_rate": 5
	},
	{
		"id": "lam_an",
		"name": "Lâm An (Hoàng Thành)",
		"symbol": "👑",
		"desc": "Cung thành uy nghiêm, tụ hội các bậc cao thủ giang hồ.",
		"buff": "Tăng 15% Sinh Lực & Nội Lực Tối Đa",
		"default_owner": "Hoàng Triều Bang",
		"default_master": "Triệu Vô Kỵ",
		"tax_rate": 8
	},
	{
		"id": "tuong_duong",
		"name": "Tương Dương (Chiến Địa)",
		"symbol": "🛡️",
		"desc": "Thành lũy kiên cố chống ngoại xâm, hiểm địa quân sự.",
		"buff": "Tăng 20% Phòng Thủ Toàn Thể",
		"default_owner": "Nghĩa Khởi Bang",
		"default_master": "Quách Tĩnh",
		"tax_rate": 5
	},
	{
		"id": "phuong_tuong",
		"name": "Phượng Tường (Quan Ải)",
		"symbol": "⚔️",
		"desc": "Cửa ngõ kết nối Tây Bắc, binh lực dồi dào.",
		"buff": "Tăng 10% Tốc Độ Di Chuyển & Đánh",
		"default_owner": "Bá Vương Bang",
		"default_master": "Hạng Vũ",
		"tax_rate": 6
	},
	{
		"id": "thanh_do",
		"name": "Thành Đô (Thiên Phủ)",
		"symbol": "🎋",
		"desc": "Miền đất phong phú vật sản, núi non bao bọc.",
		"buff": "Tăng 15% Kháng Tất Cả Ngũ Hành",
		"default_owner": "Thục Sơn Bang",
		"default_master": "Bạch Vân Phi",
		"tax_rate": 5
	},
	{
		"id": "dai_ly",
		"name": "Đại Lý (Nam Vực)",
		"symbol": "🌺",
		"desc": "Xứ sở phồn hoa Tây Nam, quê hương Đoàn gia võ học.",
		"buff": "Tăng 15% Hồi Phục Sinh Lực & Nội Lực",
		"default_owner": "Đoàn Thị Minh",
		"default_master": "Đoàn Chính Thuần",
		"tax_rate": 5
	},
	{
		"id": "duong_chau",
		"name": "Dương Châu (Thủy Trấn)",
		"symbol": "⛵",
		"desc": "Giao thương đường thủy nhộn nhịp, hoa lệ ven sông.",
		"buff": "Tăng 20% Điểm Kinh Nghiệm & Vàng Rơi",
		"default_owner": "Giang Nam Hội",
		"default_master": "Hàn Lâm Nhi",
		"tax_rate": 7
	}
]

## Long Trụ trên Map 378
const PILLAR_LEFT_POS := Vector2(44784.0, 53912.0)
const PILLAR_MID_POS := Vector2(46448.0, 53120.0)
const PILLAR_RIGHT_POS := Vector2(47856.0, 52984.0)

const PILLAR_MAX_HP := 150000.0

static func get_city_def(city_id: String) -> Dictionary:
	for c in CITIES:
		if c["id"] == city_id:
			return c
	return CITIES[0]

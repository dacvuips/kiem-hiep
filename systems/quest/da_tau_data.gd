extends RefCounted
class_name DaTauData
## Dữ liệu tĩnh cho hệ thống Dã Tẩu (TaskLink) — tham chiếu từ source 15 phái.
## Toàn bộ const, không có logic — chỉ là data layer.
##
## Nguồn: /home/jxser/server1/settings/task/tasklink_*.txt (WSL jxTP15phai)
## - tasklink_mainlink.txt  → TASK_TYPE_WEIGHTS
## - tasklink_findmaps.txt  → FINDMAPS_DATA (Type 4)
## - tasklink_upground.txt  → UPGROUND_DATA (Type 5)
## - tasklink_worldmaps.txt → WORLDMAPS_DATA + AWARD_MILESTONES (Type 6)

## ===== GIỚI HẠN NGÀY =====
const MAX_QUEST_PER_DAY := 50
const FREE_SKIP_PER_DAY := 1
const FREE_CANCEL_ITEM_ID := "ky_datau_huy"
const FREE_CANCEL_ITEM_NAME := "Lệnh Bài Hủy Dã Tẩu"
const INSTANT_COMPLETE_ITEM_ID := "ky_datau_hoanthanh"
const INSTANT_COMPLETE_ITEM_NAME := "Lệnh Bài Hoàn Thành Dã Tẩu"

## ===== 20 BẬC LEVEL LINK =====
## level_link_index (0-based) → cấp tối thiểu để vào bậc đó
const LEVEL_LINK_MIN: Array[int] = [
	1,   # LevelLink 1  (tân thủ)
	10,  # LevelLink 2
	20,  # LevelLink 3
	30,  # LevelLink 4
	40,  # LevelLink 5
	50,  # LevelLink 6
	55,  # LevelLink 7
	60,  # LevelLink 8
	65,  # LevelLink 9
	70,  # LevelLink 10
	75,  # LevelLink 11
	80,  # LevelLink 12
	85,  # LevelLink 13
	90,  # LevelLink 14
	95,  # LevelLink 15
	100, # LevelLink 16
	105, # LevelLink 17
	110, # LevelLink 18
	115, # LevelLink 19
	120, # LevelLink 20
]

## ===== TỈ LỆ CHỌN TYPE NHIỆM VỤ THEO LEVEL LINK =====
## Nguồn: tasklink_mainlink.txt
## Dòng: type | level1..level20
## type 1=Mua vật phẩm, 2=Tìm vật phẩm, 3=Xem vật phẩm,
##       4=Thu thập Địa đồ/Mật chí, 5=Nâng cấp chỉ số, 6=Sơn Hà Xã Tắc đồ
## Mỗi phần tử là mảng 20 số [level1, level2, ..., level20]
const TASK_TYPE_WEIGHTS: Dictionary = {
	1: [8000, 7000, 6000, 5000, 4000, 3000, 2000, 1000, 1000, 1000, 1000, 1000, 500, 0, 0, 0, 0, 0, 0, 0],
	2: [100, 500, 1000, 1500, 3000, 2000, 2000, 2500, 2500, 3000, 2000, 2000, 2000, 3000, 3000, 3000, 3000, 3500, 3500, 4000],
	3: [500, 1000, 1500, 2000, 2000, 2000, 2000, 3000, 3000, 3000, 2000, 2000, 3000, 3000, 3000, 2000, 2500, 3000, 3500, 4000],
	4: [3000, 4000, 4000, 5000, 6000, 5000, 5000, 6000, 6000, 6000, 6000, 6000, 7000, 7000, 8000, 6000, 7000, 7000, 8000, 7000],
	5: [2000, 3000, 2000, 2500, 3000, 3000, 3000, 3000, 3000, 3000, 3000, 3000, 3500, 3500, 4000, 5000, 5000, 5000, 5000, 5000],
	6: [1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000],
}

## ===== DỮ LIỆU MAP TÌM ĐỊA ĐỒ / MẬT CHÍ (TYPE 4) =====
## Nguồn: tasklink_findmaps.txt
## Cấu trúc mỗi entry:
##   task_id    → ID nhiệm vụ từ source (tham chiếu)
##   map_id     → ID map trong source 15 phái
##   map_name   → Tên map tiếng Việt
##   num        → Số cuộn cần thu thập (5–15 Địa đồ, 1–3 Mật chí)
##   map_type   → 1 = Địa đồ chí, 2 = Mật chí
##   task_value → Điểm thưởng khi hoàn thành
##   rates      → [rate_ll1, rate_ll2, ..., rate_ll20] (10000 = 100%)
##   godot_map_id → ID map tương ứng trong Godot (0 nếu chưa có, cần tạo)
##   level_link_active → danh sách LevelLink (1-based) có rate > 0
##
## LevelLink 1–2: Thành thị (Country maps) — Ba Lăng Huyện, Giang Tân Thôn
## LevelLink 3–5: Các map lv20–50 đã có trong Godot
## LevelLink 6–10: Map hang động mới cần tạo (10×6 region)
## LevelLink 11–20: Map cấp cao mới cần tạo (10×6 region)

const FINDMAPS_DATA: Array[Dictionary] = [
	{"task_id": 4002, "map_id": 11, "map_name": "Thành Đô", "num": 5, "map_type": 1, "task_value": 120000, "rates": [10000, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 11, "level_link_active": [1, 2]},
	{"task_id": 4003, "map_id": 37, "map_name": "Biện Kinh", "num": 5, "map_type": 1, "task_value": 120000, "rates": [10000, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 37, "level_link_active": [1, 2]},
	{"task_id": 4006, "map_id": 162, "map_name": "Đại Lý phủ", "num": 5, "map_type": 1, "task_value": 120000, "rates": [10000, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 162, "level_link_active": [1, 2]},
	{"task_id": 4007, "map_id": 176, "map_name": "Lâm An", "num": 5, "map_type": 1, "task_value": 120000, "rates": [10000, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 176, "level_link_active": [1, 2]},
	{"task_id": 4012, "map_id": 121, "map_name": "Long Môn Trấn", "num": 5, "map_type": 1, "task_value": 120000, "rates": [10000, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 121, "level_link_active": [1, 2]},
	{"task_id": 4013, "map_id": 53, "map_name": "Ba Lăng Huyện", "num": 5, "map_type": 1, "task_value": 120000, "rates": [10000, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 53, "level_link_active": [1, 2]},
	{"task_id": 4015, "map_id": 20, "map_name": "Giang Tân Thôn", "num": 5, "map_type": 1, "task_value": 120000, "rates": [10000, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 20, "level_link_active": [1, 2]},
	{"task_id": 4017, "map_id": 11, "map_name": "Thành Đô", "num": 1, "map_type": 2, "task_value": 500000, "rates": [500, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 11, "level_link_active": [1, 2]},
	{"task_id": 4018, "map_id": 37, "map_name": "Biện Kinh", "num": 1, "map_type": 2, "task_value": 500000, "rates": [500, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 37, "level_link_active": [1, 2]},
	{"task_id": 4021, "map_id": 162, "map_name": "Đại Lý phủ", "num": 1, "map_type": 2, "task_value": 500000, "rates": [500, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 162, "level_link_active": [1, 2]},
	{"task_id": 4022, "map_id": 176, "map_name": "Lâm An", "num": 1, "map_type": 2, "task_value": 500000, "rates": [500, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 176, "level_link_active": [1, 2]},
	{"task_id": 4027, "map_id": 121, "map_name": "Long Môn Trấn", "num": 1, "map_type": 2, "task_value": 500000, "rates": [500, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 121, "level_link_active": [1, 2]},
	{"task_id": 4028, "map_id": 53, "map_name": "Ba Lăng Huyện", "num": 1, "map_type": 2, "task_value": 500000, "rates": [500, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 53, "level_link_active": [1, 2]},
	{"task_id": 4030, "map_id": 20, "map_name": "Giang Tân Thôn", "num": 1, "map_type": 2, "task_value": 500000, "rates": [500, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 20, "level_link_active": [1, 2]},
	{"task_id": 4038, "map_id": 70, "map_name": "Vũ Lăng Sơn", "num": 8, "map_type": 1, "task_value": 300000, "rates": [5000, 6000, 9000, 8000, 8000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 70, "level_link_active": [1, 2, 3, 4, 5]},
	{"task_id": 4048, "map_id": 70, "map_name": "Vũ Lăng Sơn", "num": 2, "map_type": 2, "task_value": 1200000, "rates": [400, 450, 450, 500, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 70, "level_link_active": [1, 2, 3, 4, 5]},
	{"task_id": 4055, "map_id": 8, "map_name": "Tần Lăng Tầng 1", "num": 8, "map_type": 1, "task_value": 240000, "rates": [0, 0, 9000, 7000, 5000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 8, "level_link_active": [3, 4, 5]},
	{"task_id": 4062, "map_id": 90, "map_name": "Đông Phục Ngưu Sơn", "num": 8, "map_type": 1, "task_value": 400000, "rates": [0, 0, 9000, 7000, 5000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 90, "level_link_active": [3, 4, 5]},
	{"task_id": 4063, "map_id": 92, "map_name": "Thục Cương Sơn", "num": 8, "map_type": 1, "task_value": 400000, "rates": [0, 0, 9000, 7000, 5000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 92, "level_link_active": [3, 4, 5]},
	{"task_id": 4068, "map_id": 8, "map_name": "Tần Lăng Tầng 1", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 500, 600, 600, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 8, "level_link_active": [3, 4, 5]},
	{"task_id": 4075, "map_id": 90, "map_name": "Đông Phục Ngưu Sơn", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 500, 600, 600, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 90, "level_link_active": [3, 4, 5]},
	{"task_id": 4076, "map_id": 92, "map_name": "Thục Cương Sơn", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 500, 600, 600, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 92, "level_link_active": [3, 4, 5]},
	{"task_id": 4079, "map_id": 122, "map_name": "Hoàng Hà Nguyên Đầu", "num": 8, "map_type": 1, "task_value": 450000, "rates": [0, 0, 3000, 5000, 7000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 122, "level_link_active": [3, 4, 5]},
	{"task_id": 4088, "map_id": 41, "map_name": "Tây Phục Ngưu Sơn", "num": 8, "map_type": 1, "task_value": 450000, "rates": [0, 0, 3000, 5000, 7000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 41, "level_link_active": [3, 4, 5]},
	{"task_id": 4090, "map_id": 21, "map_name": "Thanh Thành sơn", "num": 8, "map_type": 1, "task_value": 450000, "rates": [0, 0, 3000, 5000, 7000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 21, "level_link_active": [3, 4, 5]},
	{"task_id": 4093, "map_id": 122, "map_name": "Hoàng Hà Nguyên Đầu", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 200, 300, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 122, "level_link_active": [3, 4, 5]},
	{"task_id": 4102, "map_id": 41, "map_name": "Tây Phục Ngưu Sơn", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 200, 300, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 41, "level_link_active": [3, 4, 5]},
	{"task_id": 4104, "map_id": 21, "map_name": "Thanh Thành sơn", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 200, 300, 400, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 21, "level_link_active": [3, 4, 5]},
	{"task_id": 4107, "map_id": 39, "map_name": "Thiết Tháp Tầng 2", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 39, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4109, "map_id": 40, "map_name": "Thiết Tháp Tầng 3", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 40, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4110, "map_id": 163, "map_name": "ác Bá Địa Đạo", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 163, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4111, "map_id": 38, "map_name": "Thiết Tháp Tầng 1", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 38, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4112, "map_id": 116, "map_name": "Tường Vân Động Tầng 1", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 116, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4113, "map_id": 165, "map_name": "Thiên Tầm Tháp Tầng 2", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 165, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4114, "map_id": 132, "map_name": "Băng Huyệt Mê Cung", "num": 10, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 132, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4115, "map_id": 42, "map_name": "Thiên Tâm Động", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 42, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4116, "map_id": 66, "map_name": "Đáy Động Đình Hồ tầng 1", "num": 10, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 66, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4117, "map_id": 194, "map_name": "Mê Cung Ngọc Hoa Động", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 194, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4118, "map_id": 164, "map_name": "Thiên Tầm Tháp Tầng 1", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 164, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4119, "map_id": 182, "map_name": "Mê Cung Nghiệt Long Động", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 182, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4120, "map_id": 24, "map_name": "Hưởng Thủy Động", "num": 10, "map_type": 1, "task_value": 350000, "rates": [0, 0, 0, 0, 0, 10000, 8000, 6000, 4000, 2000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 24, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4123, "map_id": 39, "map_name": "Thiết Tháp Tầng 2", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 39, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4125, "map_id": 40, "map_name": "Thiết Tháp Tầng 3", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 40, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4126, "map_id": 163, "map_name": "ác Bá Địa Đạo", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 163, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4127, "map_id": 38, "map_name": "Thiết Tháp Tầng 1", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 38, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4128, "map_id": 116, "map_name": "Tường Vân Động Tầng 1", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 116, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4129, "map_id": 165, "map_name": "Thiên Tầm Tháp Tầng 2", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 165, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4130, "map_id": 132, "map_name": "Băng Huyệt Mê Cung", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 132, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4131, "map_id": 42, "map_name": "Thiên Tâm Động", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 42, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4132, "map_id": 66, "map_name": "Đáy Động Đình Hồ tầng 1", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 66, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4133, "map_id": 194, "map_name": "Mê Cung Ngọc Hoa Động", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 194, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4134, "map_id": 164, "map_name": "Thiên Tầm Tháp Tầng 1", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 164, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4135, "map_id": 182, "map_name": "Mê Cung Nghiệt Long Động", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 182, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4136, "map_id": 24, "map_name": "Hưởng Thủy Động", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 250, 300, 350, 400, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 24, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4139, "map_id": 118, "map_name": "Tường Vân Động Tầng 3", "num": 10, "map_type": 1, "task_value": 400000, "rates": [0, 0, 0, 0, 0, 6000, 7000, 8000, 9000, 9000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 118, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4140, "map_id": 79, "map_name": "Mật Đạo Nha Môn Tương Dương", "num": 10, "map_type": 1, "task_value": 400000, "rates": [0, 0, 0, 0, 0, 6000, 7000, 8000, 9000, 9000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 79, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4141, "map_id": 119, "map_name": "Tường Vân Động Tầng 4", "num": 10, "map_type": 1, "task_value": 400000, "rates": [0, 0, 0, 0, 0, 6000, 7000, 8000, 9000, 9000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 119, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4142, "map_id": 117, "map_name": "Tường Vân Động Tầng 2", "num": 10, "map_type": 1, "task_value": 400000, "rates": [0, 0, 0, 0, 0, 6000, 7000, 8000, 9000, 9000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 117, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4143, "map_id": 166, "map_name": "Thiên Tầm Tháp tầng 3", "num": 10, "map_type": 1, "task_value": 400000, "rates": [0, 0, 0, 0, 0, 6000, 7000, 8000, 9000, 9000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 166, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4144, "map_id": 56, "map_name": "Hành Sơn", "num": 10, "map_type": 1, "task_value": 650000, "rates": [0, 0, 0, 0, 0, 6000, 7000, 8000, 9000, 9000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 56, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4145, "map_id": 196, "map_name": "Dương Giác Động", "num": 10, "map_type": 1, "task_value": 400000, "rates": [0, 0, 0, 0, 0, 6000, 7000, 8000, 9000, 9000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 196, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4146, "map_id": 114, "map_name": "108 La Hán Trận", "num": 10, "map_type": 1, "task_value": 400000, "rates": [0, 0, 0, 0, 0, 6000, 7000, 8000, 9000, 9000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 114, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4149, "map_id": 118, "map_name": "Tường Vân Động Tầng 3", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 300, 350, 400, 450, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 118, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4150, "map_id": 79, "map_name": "Mật Đạo Nha Môn Tương Dương", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 300, 350, 400, 450, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 79, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4151, "map_id": 119, "map_name": "Tường Vân Động Tầng 4", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 300, 350, 400, 450, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 119, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4152, "map_id": 117, "map_name": "Tường Vân Động Tầng 2", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 300, 350, 400, 450, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 117, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4153, "map_id": 166, "map_name": "Thiên Tầm Tháp tầng 3", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 300, 350, 400, 450, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 166, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4154, "map_id": 56, "map_name": "Hành Sơn", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 300, 350, 400, 450, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 56, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4155, "map_id": 196, "map_name": "Dương Giác Động", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 300, 350, 400, 450, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 196, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4156, "map_id": 114, "map_name": "108 La Hán Trận", "num": 2, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 300, 350, 400, 450, 450, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 114, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4158, "map_id": 94, "map_name": "Linh Cốc Động", "num": 12, "map_type": 1, "task_value": 900000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 94, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4159, "map_id": 120, "map_name": "Tường Vân Động Tầng 5", "num": 12, "map_type": 1, "task_value": 500000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 120, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4160, "map_id": 123, "map_name": "Lão Hổ Động", "num": 12, "map_type": 1, "task_value": 500000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 123, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4161, "map_id": 206, "map_name": "Tần Lăng Tầng 2", "num": 12, "map_type": 1, "task_value": 900000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 206, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4162, "map_id": 76, "map_name": "Sơn Bảo Động", "num": 12, "map_type": 1, "task_value": 900000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 76, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4163, "map_id": 72, "map_name": "Mê Cung Đại Tù Động", "num": 12, "map_type": 1, "task_value": 500000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 72, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4164, "map_id": 142, "map_name": "Dược Vương Động Tầng 2", "num": 12, "map_type": 1, "task_value": 500000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 142, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4165, "map_id": 169, "map_name": "Long Nhãn Động", "num": 12, "map_type": 1, "task_value": 500000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 169, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4166, "map_id": 9, "map_name": "Trường Gian Nguyên Đầu", "num": 12, "map_type": 1, "task_value": 500000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 9, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4167, "map_id": 55, "map_name": "Đào Hoa Nguyên", "num": 12, "map_type": 1, "task_value": 900000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 55, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4168, "map_id": 319, "map_name": "Lâm Du Quan", "num": 12, "map_type": 1, "task_value": 400000, "rates": [0, 0, 0, 0, 0, 2000, 3000, 4000, 5000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 319, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4170, "map_id": 94, "map_name": "Linh Cốc Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 94, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4171, "map_id": 120, "map_name": "Tường Vân Động Tầng 5", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 120, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4172, "map_id": 123, "map_name": "Lão Hổ Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 123, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4173, "map_id": 206, "map_name": "Tần Lăng Tầng 2", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 206, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4174, "map_id": 76, "map_name": "Sơn Bảo Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 76, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4175, "map_id": 72, "map_name": "Mê Cung Đại Tù Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 72, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4176, "map_id": 142, "map_name": "Dược Vương Động Tầng 2", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 142, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4177, "map_id": 169, "map_name": "Long Nhãn Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 169, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4178, "map_id": 9, "map_name": "Trường Gian Nguyên Đầu", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 9, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4179, "map_id": 55, "map_name": "Đào Hoa Nguyên", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 55, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4180, "map_id": 319, "map_name": "Lâm Du Quan", "num": 3, "map_type": 2, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "godot_map_id": 319, "level_link_active": [6, 7, 8, 9, 10]},
	{"task_id": 4183, "map_id": 207, "map_name": "Tần Lăng Tầng 3", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 207, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4184, "map_id": 143, "map_name": "Dược Vương Động Tầng 3", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 143, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4185, "map_id": 10, "map_name": "Nhạn Thạch Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 10, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4186, "map_id": 198, "map_name": "Thanh khê Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 198, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4187, "map_id": 200, "map_name": "Cổ Dương Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 200, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4188, "map_id": 201, "map_name": "Mê Cung Băng Hà Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 201, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4189, "map_id": 203, "map_name": "Vô Danh Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 203, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4190, "map_id": 205, "map_name": "Mê Cung Dương Trung Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 205, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4191, "map_id": 181, "map_name": "Mê Cung Lưỡng Thủy Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 181, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4192, "map_id": 199, "map_name": "Vũ Lăng Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 199, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4193, "map_id": 202, "map_name": "Mê Cung Phù Dung Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 202, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4194, "map_id": 204, "map_name": "Phi Thiên Động", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 204, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4195, "map_id": 224, "map_name": "Sa Mạc Địa Biểu", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 224, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4196, "map_id": 320, "map_name": "Chân Núi Trường Bạch", "num": 12, "map_type": 1, "task_value": 600000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10000, 9500, 9000, 8500, 8000, 0, 0, 0, 0, 0], "godot_map_id": 320, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4199, "map_id": 207, "map_name": "Tần Lăng Tầng 3", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 207, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4200, "map_id": 143, "map_name": "Dược Vương Động Tầng 3", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 143, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4201, "map_id": 10, "map_name": "Nhạn Thạch Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 10, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4202, "map_id": 198, "map_name": "Thanh khê Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 198, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4203, "map_id": 200, "map_name": "Cổ Dương Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 200, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4204, "map_id": 201, "map_name": "Mê Cung Băng Hà Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 201, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4205, "map_id": 203, "map_name": "Vô Danh Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 203, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4206, "map_id": 205, "map_name": "Mê Cung Dương Trung Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 205, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4207, "map_id": 181, "map_name": "Mê Cung Lưỡng Thủy Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 181, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4208, "map_id": 199, "map_name": "Vũ Lăng Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 199, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4209, "map_id": 202, "map_name": "Mê Cung Phù Dung Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 202, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4210, "map_id": 204, "map_name": "Phi Thiên Động", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 204, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4211, "map_id": 224, "map_name": "Sa Mạc Địa Biểu", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 224, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4212, "map_id": 320, "map_name": "Chân Núi Trường Bạch", "num": 3, "map_type": 2, "task_value": 2000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 600, 700, 800, 900, 0, 0, 0, 0, 0], "godot_map_id": 320, "level_link_active": [11, 12, 13, 14, 15]},
	{"task_id": 4214, "map_id": 124, "map_name": "Hiên Viên Động", "num": 8, "map_type": 1, "task_value": 1500000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000, 2500, 3000, 3500, 4000, 10000, 10000, 10000, 10000, 10000], "godot_map_id": 124, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4215, "map_id": 93, "map_name": "Tiến Cúc Động", "num": 15, "map_type": 1, "task_value": 1200000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000, 2500, 3000, 3500, 4000, 10000, 10000, 10000, 10000, 10000], "godot_map_id": 93, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4216, "map_id": 75, "map_name": "Xi Vưu Động", "num": 15, "map_type": 1, "task_value": 1200000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000, 2500, 3000, 3500, 4000, 10000, 10000, 10000, 10000, 10000], "godot_map_id": 75, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4217, "map_id": 144, "map_name": "Dược Vương Động Tầng 4", "num": 15, "map_type": 1, "task_value": 1200000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000, 2500, 3000, 3500, 4000, 10000, 10000, 10000, 10000, 10000], "godot_map_id": 144, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4218, "map_id": 225, "map_name": "Sa Mạc 1", "num": 15, "map_type": 1, "task_value": 800000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000, 2500, 3000, 3500, 4000, 10000, 10000, 10000, 10000, 10000], "godot_map_id": 225, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4219, "map_id": 226, "map_name": "Sa Mạc 2", "num": 15, "map_type": 1, "task_value": 800000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000, 2500, 3000, 3500, 4000, 10000, 10000, 10000, 10000, 10000], "godot_map_id": 226, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4220, "map_id": 227, "map_name": "Sa Mạc 3", "num": 15, "map_type": 1, "task_value": 800000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000, 2500, 3000, 3500, 4000, 10000, 10000, 10000, 10000, 10000], "godot_map_id": 227, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4221, "map_id": 321, "map_name": "Trường Bạch Sơn Nam 1", "num": 15, "map_type": 1, "task_value": 800000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000, 2500, 3000, 3500, 4000, 10000, 10000, 10000, 10000, 10000], "godot_map_id": 321, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4222, "map_id": 322, "map_name": "Trường Bạch Sơn Bắc 1", "num": 15, "map_type": 1, "task_value": 800000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2000, 2500, 3000, 3500, 4000, 10000, 10000, 10000, 10000, 10000], "godot_map_id": 322, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4223, "map_id": 124, "map_name": "Hiên Viên Động", "num": 3, "map_type": 2, "task_value": 2400000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 500, 600, 700, 800, 900], "godot_map_id": 124, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4224, "map_id": 93, "map_name": "Tiến Cúc Động", "num": 3, "map_type": 2, "task_value": 2400000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 500, 600, 700, 800, 900], "godot_map_id": 93, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4225, "map_id": 75, "map_name": "Xi Vưu Động", "num": 3, "map_type": 2, "task_value": 2400000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 500, 600, 700, 800, 900], "godot_map_id": 75, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4226, "map_id": 144, "map_name": "Dược Vương Động Tầng 4", "num": 3, "map_type": 2, "task_value": 2400000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 500, 600, 700, 800, 900], "godot_map_id": 144, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4227, "map_id": 225, "map_name": "Sa Mạc 1", "num": 3, "map_type": 2, "task_value": 2400000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 500, 600, 700, 800, 900], "godot_map_id": 225, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4228, "map_id": 226, "map_name": "Sa Mạc 2", "num": 3, "map_type": 2, "task_value": 2400000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 500, 600, 700, 800, 900], "godot_map_id": 226, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4229, "map_id": 227, "map_name": "Sa Mạc 3", "num": 3, "map_type": 2, "task_value": 2400000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 500, 600, 700, 800, 900], "godot_map_id": 227, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4230, "map_id": 321, "map_name": "Trường Bạch Sơn Nam 1", "num": 3, "map_type": 2, "task_value": 2400000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 500, 600, 700, 800, 900], "godot_map_id": 321, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
	{"task_id": 4231, "map_id": 322, "map_name": "Trường Bạch Sơn Bắc 1", "num": 3, "map_type": 2, "task_value": 2400000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300, 500, 600, 700, 800, 900], "godot_map_id": 322, "level_link_active": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]},
]

## ===== DROP RATE MẬT ĐỒ / ĐỊA ĐỒ CHÍ / MẬT CHÍ THEO MAP (SOURCE GỐC) =====
## Nguồn: settings/maplist.ini + settings/droprate/npcdroprate*.ini + goldennpc/*.ini (15 phái)
##        và script/global/droprate/droprate<N>x.lua (Server gốc):
##   diadochi (6_1_206 Thần bí đồ chí): droprate0x-1x = 1.5625% (1/16 * 25%), droprate2x-8x = 3.125% (1/16 * 50%),
##                                      npcdroprate90.ini (9x+) = 7.50% (75000/1000000)
##   matchi   (6_1_213 Thần Bí Lộ Chí): boss xanh nSel==8: <6x = 4.76% (1/21 mỗi lần rơi), 6x+ = 1.96% (1/51 mỗi lần rơi)
##   matdo    (6_1_196 Mật đồ thần bí): npcdroprate10 = 0.606% (2000/330000), npcdroprate20-90 = 0.20% (2000/1000000), 110+ = 0.175%
## map_id (source) → {diadochi: float, matchi: float, matdo: float}
const DROP_RATES: Dictionary = {
	8:   {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	9:   {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	10:  {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	11:  {"diadochi": 0.015625, "matchi": 0.0476, "matdo": 0.00606},
	20:  {"diadochi": 0.015625, "matchi": 0.0476, "matdo": 0.00606},
	21:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	24:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	37:  {"diadochi": 0.015625, "matchi": 0.0476, "matdo": 0.00606},
	38:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	39:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	40:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	41:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	42:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	53:  {"diadochi": 0.015625, "matchi": 0.0476, "matdo": 0.00606},
	55:  {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	56:  {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	66:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	70:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	72:  {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	75:  {"diadochi": 0.075,    "matchi": 0.0196, "matdo": 0.002},
	76:  {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	79:  {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	90:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	92:  {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	93:  {"diadochi": 0.075,    "matchi": 0.0196, "matdo": 0.002},
	94:  {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	114: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	116: {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	117: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	118: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	119: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	120: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	121: {"diadochi": 0.015625, "matchi": 0.0476, "matdo": 0.00606},
	122: {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	123: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	124: {"diadochi": 0.075,    "matchi": 0.0196, "matdo": 0.002},
	132: {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	142: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	143: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	144: {"diadochi": 0.075,    "matchi": 0.0196, "matdo": 0.002},
	162: {"diadochi": 0.015625, "matchi": 0.0476, "matdo": 0.00606},
	163: {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	164: {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	165: {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	166: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	169: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	176: {"diadochi": 0.015625, "matchi": 0.0476, "matdo": 0.00606},
	181: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	182: {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	194: {"diadochi": 0.03125,  "matchi": 0.0476, "matdo": 0.002},
	196: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	198: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	199: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	200: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	201: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	202: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	203: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	204: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	205: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	206: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	207: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	224: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	225: {"diadochi": 0.075,    "matchi": 0.0196, "matdo": 0.002},
	226: {"diadochi": 0.075,    "matchi": 0.0196, "matdo": 0.002},
	227: {"diadochi": 0.075,    "matchi": 0.0196, "matdo": 0.002},
	319: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	320: {"diadochi": 0.03125,  "matchi": 0.0196, "matdo": 0.002},
	321: {"diadochi": 0.075,    "matchi": 0.0196, "matdo": 0.002},
	322: {"diadochi": 0.075,    "matchi": 0.0196, "matdo": 0.002},
}

## ===== DỮ LIỆU NÂNG CẤP CHỈ SỐ (TYPE 5) =====
## ===== DỮ LIỆU TÍCH LŨY KINH NGHIỆM (TYPE 5) =====
## Nguồn: tasklink_upground.txt (NumericType 2: Trị kinh nghiệm cần tích lũy)
## NumericValue: Lượng EXP cần đánh quái / vượt ải để tích lũy
## TaskValue2: Điểm thưởng khi hoàn thành
const UPGROUND_DATA: Array[Dictionary] = [
	{"task_id": 5001, "numeric_type": 2, "need_value": 5000,     "reward_pts": 20000,    "rates": [10000, 9000, 8000, 7000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]},
	{"task_id": 5002, "numeric_type": 2, "need_value": 15000,    "reward_pts": 45000,    "rates": [3000, 3500, 5000, 5000, 5000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]},
	{"task_id": 5003, "numeric_type": 2, "need_value": 50000,    "reward_pts": 80000,    "rates": [100, 200, 3000, 3000, 3000, 10000, 9000, 8000, 7000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]},
	{"task_id": 5004, "numeric_type": 2, "need_value": 100000,   "reward_pts": 120000,   "rates": [0, 1, 500, 600, 700, 6000, 6000, 6000, 6000, 6000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]},
	{"task_id": 5005, "numeric_type": 2, "need_value": 200000,   "reward_pts": 160000,   "rates": [0, 0, 100, 120, 140, 3000, 3500, 4000, 4500, 5000, 10000, 9000, 8000, 7000, 6000, 0, 0, 0, 0, 0]},
	{"task_id": 5006, "numeric_type": 2, "need_value": 500000,   "reward_pts": 240000,   "rates": [0, 0, 1, 2, 3, 1000, 1200, 1400, 1600, 1800, 6000, 6000, 6000, 6000, 6000, 0, 0, 0, 0, 0]},
	{"task_id": 5007, "numeric_type": 2, "need_value": 1000000,  "reward_pts": 480000,   "rates": [0, 0, 0, 0, 0, 100, 120, 140, 160, 180, 3000, 3500, 4000, 4500, 5000, 10000, 9000, 8000, 7000, 6000]},
	{"task_id": 5008, "numeric_type": 2, "need_value": 2000000,  "reward_pts": 1200000,  "rates": [0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 1000, 1200, 1400, 1600, 1800, 6000, 6000, 6000, 6000, 6000]},
	{"task_id": 5009, "numeric_type": 2, "need_value": 5000000,  "reward_pts": 2800000,  "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 120, 140, 160, 180, 1000, 1200, 1400, 1600, 1800]},
	{"task_id": 5010, "numeric_type": 2, "need_value": 10000000, "reward_pts": 6000000,  "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 200, 300, 400, 500, 600]},
	{"task_id": 5011, "numeric_type": 2, "need_value": 20000000, "reward_pts": 16000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 150, 200, 250, 300]},
	{"task_id": 5012, "numeric_type": 2, "need_value": 50000000, "reward_pts": 30000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 50, 75, 100, 125, 150]},
]

## Tên chỉ số tương ứng với numeric_type (dùng để hiển thị UI)
const NUMERIC_TYPE_NAMES: Dictionary = {
	2: "Kinh nghiệm",
}

## ===== DỮ LIỆU SƠN HÀ XÃ TẮC ĐỒ (TYPE 6) =====
## Nguồn: tasklink_worldmaps.txt
## Num: Số mảnh Sơn Hà Xã Tắc cần; TaskValue2: điểm thưởng
## Trong Godot: vì không có mảnh SHXT riêng, dùng "điểm Dã Tẩu tích lũy" (da_tau_points)
## → Type 6 chuyển thành: Tích lũy X điểm Dã Tẩu (từ các nhiệm vụ trước)
const WORLDMAPS_DATA: Array[Dictionary] = [
	{"task_id": 6001, "num": 1,    "reward_pts": 15000,     "rates": [10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000,10000]},
	{"task_id": 6002, "num": 5,    "reward_pts": 45000,     "rates": [1000, 2000, 3000, 4000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 6000, 7000, 8000, 9000, 9000, 9000, 9000, 9000, 9000]},
	{"task_id": 6003, "num": 10,   "reward_pts": 80000,     "rates": [100, 150, 200, 300, 400, 500, 800, 1000, 1200, 1600, 3000, 3500, 4000, 4500, 5000, 6000, 6500, 7000, 7500, 8000]},
	{"task_id": 6004, "num": 20,   "reward_pts": 150000,    "rates": [5, 10, 20, 30, 50, 100, 200, 500, 800, 1000, 1500, 1800, 2100, 2400, 2700, 3000, 4000, 5000, 6000, 7000]},
	{"task_id": 6005, "num": 50,   "reward_pts": 350000,    "rates": [1, 5, 10, 20, 50, 100, 200, 300, 400, 500, 1000, 1200, 1400, 1600, 1800, 3000, 3500, 4000, 4500, 5000]},
	{"task_id": 6006, "num": 100,  "reward_pts": 1000000,   "rates": [0, 1, 3, 5, 10, 30, 50, 100, 15, 200, 300, 400, 500, 600, 800, 1000, 1200, 1400, 1600, 1800]},
	{"task_id": 6007, "num": 200,  "reward_pts": 2400000,   "rates": [0, 0, 1, 2, 3, 5, 10, 20, 30, 50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800]},
	{"task_id": 6008, "num": 500,  "reward_pts": 7500000,   "rates": [0, 0, 0, 1, 2, 3, 4, 5, 6, 10, 20, 30, 40, 50, 80, 100, 150, 200, 250, 300]},
	{"task_id": 6009, "num": 1000, "reward_pts": 16000000,  "rates": [0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 40, 50, 60, 70, 80]},
	{"task_id": 6010, "num": 2000, "reward_pts": 36000000,  "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 5, 8, 10, 15, 20]},
	{"task_id": 6011, "num": 5000, "reward_pts": 100000000, "rates": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5]},
]

## ===== MỐC TÍCH LŨY THEO TỔNG SỐ NHIỆM VỤ (CHUẨN VLTK 1) =====
## Mỗi mốc: sau khi tổng số nhiệm vụ đã hoàn thành (total_done) đạt ngưỡng → nhận thưởng thật vào hành trang
const MILESTONE_VERSION := 2

const AWARD_MILESTONES: Array[int] = [
	100, 300, 500, 1000, 2000, 3000, 4000, 6000, 8000
]

## Mô tả thưởng tại mỗi mốc (index tương ứng với AWARD_MILESTONES)
const MILESTONE_REWARDS_DESC: Array[String] = [
	"Tiên Thảo Lộ ×2 + Lượng ×50.000",
	"Lam Thủy Tinh ×1 + Tử Thủy Tinh ×1 + Lục Thủy Tinh ×1",
	"Võ Lâm Mật Tịch ×1 + Lượng ×100.000",
	"Tẩy Tủy Kinh ×1 + Võ Lâm Mật Tịch ×1",
	"Trang Bị Hoàng Kim Nhu Tình / Hiệp Cốt (Ngẫu nhiên) + Tinh Hồng Bảo Thạch ×2",
	"Trang Bị Hoàng Kim An Bang (Ngẫu nhiên) + Lượng ×500.000",
	"Trang Bị Hoàng Kim Định Quốc (Ngẫu nhiên)",
	"Ngựa Phi Vân ×1",
	"Trang Bị Hoàng Kim Môn Phái (HKMP) + Danh Vọng ×200",
]

## Cấu hình phần thưởng thực tế cho từng mốc (index tương ứng với AWARD_MILESTONES)
const MILESTONE_REWARDS: Array[Dictionary] = [
	{"misc": [{"id": "6_1_71", "qty": 2}], "gold": 50000},
	{"misc": [{"id": "4_238_1", "qty": 1}, {"id": "4_239_1", "qty": 1}, {"id": "4_240_1", "qty": 1}]},
	{"misc": [{"id": "6_1_26", "qty": 1}], "gold": 100000},
	{"misc": [{"id": "6_1_22", "qty": 1}, {"id": "6_1_26", "qty": 1}]},
	{"gold_pool": [185, 186, 187, 188, 189, 190, 191, 192], "misc": [{"id": "4_353_1", "qty": 2}]},
	{"gold_pool": [163, 164, 165, 166], "gold": 500000},
	{"gold_pool": [158, 159, 160, 161, 162]},
	{"horse": {"particular": 8, "level": 10}},
	{"hkmp": true, "prestige": 200},
]

## ===== BẢNG THƯỞNG EXP CHUẨN JX1 (datau.lua: EXP_REWARDS * MONEY_RATE) =====
const EXP_REWARDS: Array[Vector2i] = [
	Vector2i(2000, 4000),      # LevelLink 1 (level 1-9)
	Vector2i(6000, 12000),     # LevelLink 2 (level 10-19)
	Vector2i(10000, 16000),    # LevelLink 3 (level 20-29)
	Vector2i(16000, 24000),    # LevelLink 4 (level 30-39)
	Vector2i(24000, 30000),    # LevelLink 5 (level 40-49)
	Vector2i(40000, 80000),    # LevelLink 6 (level 50-59)
	Vector2i(100000, 140000),  # LevelLink 7 (level 60-69)
	Vector2i(180000, 240000),  # LevelLink 8 (level 70-79)
	Vector2i(600000, 1000000), # LevelLink 9 (level 80-89)
	Vector2i(1000000, 2000000),# LevelLink 10+ (level 90+)
]

## ===== TRẠNG THÁI MẶC ĐỊNH (dùng trong PlayerProfile) =====
const DEFAULT_STATE: Dictionary = {
	"current_quest": null,  # null | Dictionary {type, map_id, need_num, done_num, ...}
	"done_today": 0,        # Số nhiệm vụ đã hoàn thành hôm nay
	"last_reset_date": "",  # Ngày reset cuối (format "YYYY-MM-DD")
	"total_done": 0,        # Tổng nhiệm vụ đã làm (mọi thời gian)
	"da_tau_points": 0,     # Điểm tích lũy tổng (tính mốc thưởng)
	"skip_today": 0,        # Số lượt bỏ đã dùng hôm nay
	"claimed_milestones": [],# Mảng index mốc đã nhận thưởng
	"milestone_version": MILESTONE_VERSION, # Phiên bản bảng mốc (v2 = mốc theo tổng nhiệm vụ VLTK 1)
	"scroll_count": 0,      # Số cuộn đã nhặt cho quest hiện tại (Type 4)
	"da_tau_points_session": 0, # Điểm Dã Tẩu (mảnh SHXT) hiện có (dùng cho Type 6)
	"pending_options": [],      # 3 Lựa chọn phần thưởng (chọn 1 trong 3 chuẩn JX1)
}

## ===== NPC DIALOG =====
## Lời thoại Dã Tẩu theo từng trạng thái
const NPC_DIALOG: Dictionary = {
	"welcome":    "Lão phu là Dã Tẩu! Giang hồ có việc cần người giúp đỡ, huynh đệ có thể thử sức không?",
	"no_quest":   "Chúc mừng huynh đệ! Hôm nay đã hoàn thành %d nhiệm vụ. Ngày mai quay lại nhé!",
	"quest_doing":"Nhiệm vụ đang chờ: %s. Hãy cố lên!",
	"quest_done": "Xuất sắc! Huynh đệ đã hoàn thành nhiệm vụ. Lão phu xin cảm ơn!",
	"skip_ok":    "Nhiệm vụ này huynh đệ bỏ qua. Lần sau nhớ cố thêm!",
	"skip_no":    "Huynh đệ đã dùng hết lượt bỏ qua hôm nay rồi!",
	"cancel_free_item": "Huynh đệ đã dùng Lệnh Bài Hủy Dã Tẩu để hủy nhiệm vụ miễn phí. Chuỗi nhiệm vụ vẫn được giữ nguyên!",
	"cancel_reset":     "Huynh đệ đã hủy nhiệm vụ mà không có vật phẩm miễn hủy. Chuỗi nhiệm vụ hôm nay đã trở về #1 để làm lại từ đầu!",
	"max_today":  "Huynh đệ đã làm đủ %d nhiệm vụ hôm nay! Hãy nghỉ ngơi, ngày mai tiếp tục.",
}

## ===== HÀM TIỆN ÍCH (STATIC) =====

## Lấy LevelLink (1-based) dựa trên cấp nhân vật
static func get_level_link(char_level: int) -> int:
	var link := 1
	for i in range(LEVEL_LINK_MIN.size() - 1, -1, -1):
		if char_level >= LEVEL_LINK_MIN[i]:
			link = i + 1
			break
	return clampi(link, 1, 20)

## Lấy danh sách FINDMAPS_DATA phù hợp với LevelLink hiện tại (rate > 0)
static func get_findmaps_for_level_link(level_link: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in FINDMAPS_DATA:
		if level_link in entry["level_link_active"] and entry["rates"][level_link - 1] > 0:
			result.append(entry)
	return result

## Lấy drop rate Địa đồ chí (6_1_206) cho map_id (source ID)
static func get_diadochi_rate(map_id: int) -> float:
	if DROP_RATES.has(map_id):
		return DROP_RATES[map_id]["diadochi"]
	return 0.03125

## Lấy drop rate Mật chí / Địa chí (6_1_213) cho map_id (source ID)
static func get_matchi_rate(map_id: int) -> float:
	if DROP_RATES.has(map_id):
		return DROP_RATES[map_id]["matchi"]
	return 0.0196

const GOODS_DATA_PATH := "res://data/items/da_tau_goods.json"
static var _showgoods_data: Array[Dictionary] = []
static var _findgoods_data: Array[Dictionary] = []

static func _ensure_goods_loaded() -> void:
	if not _showgoods_data.is_empty() and not _findgoods_data.is_empty():
		return
	if not FileAccess.file_exists(GOODS_DATA_PATH):
		return
	var txt := FileAccess.get_file_as_string(GOODS_DATA_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		var raw_show: Array = parsed.get("showgoods", [])
		_showgoods_data.clear()
		for item in raw_show:
			if item is Dictionary:
				_showgoods_data.append(item)
		var raw_find: Array = parsed.get("findgoods", [])
		_findgoods_data.clear()
		for item in raw_find:
			if item is Dictionary:
				_findgoods_data.append(item)

static func get_findgoods_for_level_link(level_link: int) -> Array[Dictionary]:
	_ensure_goods_loaded()
	var ll_idx := clampi(level_link - 1, 0, 19)
	var result: Array[Dictionary] = []
	for entry in _findgoods_data:
		var rates: Array = entry.get("rates", [])
		if rates.size() > ll_idx and int(rates[ll_idx]) > 0:
			result.append(entry)
	return result

static func get_showgoods_for_level_link(level_link: int) -> Array[Dictionary]:
	_ensure_goods_loaded()
	var ll_idx := clampi(level_link - 1, 0, 19)
	var result: Array[Dictionary] = []
	for entry in _showgoods_data:
		var rates: Array = entry.get("rates", [])
		if rates.size() > ll_idx and int(rates[ll_idx]) > 0:
			result.append(entry)
	return result

## Lấy drop rate Mật đồ thần bí (6_1_196) cho map_id (source ID)
static func get_matdo_rate(map_id: int) -> float:
	if DROP_RATES.has(map_id):
		return DROP_RATES[map_id].get("matdo", 0.002)
	return 0.002

## Trọng số chọn loại nhiệm vụ theo LevelLink (trả về type_id đã random)
static func pick_quest_type(level_link: int, rng: RandomNumberGenerator) -> int:
	var ll_idx := clampi(level_link - 1, 0, 19)
	var total := 0
	for t in TASK_TYPE_WEIGHTS:
		total += TASK_TYPE_WEIGHTS[t][ll_idx]
	if total <= 0:
		return 1
	var roll := rng.randi_range(0, total - 1)
	var acc := 0
	for t in TASK_TYPE_WEIGHTS:
		acc += TASK_TYPE_WEIGHTS[t][ll_idx]
		if roll < acc:
			return t
	return 1

## Chọn entry từ mảng data theo TaskRate (column = level_link - 1)
static func pick_weighted(data_array: Array, level_link: int, rng: RandomNumberGenerator) -> Dictionary:
	var ll_idx := clampi(level_link - 1, 0, 19)
	var eligible: Array[Dictionary] = []
	var weights: Array[int] = []
	var total := 0
	for entry in data_array:
		var r: int = entry["rates"][ll_idx]
		if r > 0:
			eligible.append(entry)
			weights.append(r)
			total += r
	if eligible.is_empty():
		return {}
	var roll := rng.randi_range(0, total - 1)
	var acc := 0
	for i in eligible.size():
		acc += weights[i]
		if roll < acc:
			return eligible[i]
	return eligible[0]

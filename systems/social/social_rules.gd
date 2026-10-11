extends RefCounted
class_name SocialRules
## Luật xã hội VLTK gốc (tổ đội / bang hội / rương / giao dịch) đã nhập sẵn trong data/social/social_rules.json — xem
## tools/import_vltk_social_rules.py để biết số nào lấy từ file nào của VNG. Chỉ ĐỌC dữ liệu, không giữ trạng thái người chơi.

const PATH := "res://data/social/social_rules.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data

# ------------------------------------------------------------------ tổ đội
## Số người TỐI ĐA trong tổ đội (kể cả đội trưởng) theo cấp lãnh đạo của đội trưởng — KTeam::CalcCaptainPower gốc
## = m_cLeadExp.GetMemNumFromLevel(cấp lãnh đạo) (bảng [LevelUnionNum] của VNG).
static func team_size(lead_level: int) -> int:
	var table: Dictionary = data()["team"]["union_num_by_lead_level"]
	return int(table.get(str(clampi(lead_level, 0, 100)), 3))

## Số đồng đội TỐI ĐA đội trưởng đưa vào (không tính chính mình), bị chặn bởi MAX_TEAM_MEMBER = 7.
static func team_member_cap(lead_level: int) -> int:
	return mini(team_size(lead_level) - 1, int(data()["team"]["max_members_without_captain"]))

## Kinh nghiệm lãnh đạo cần để lên cấp `lead_level + 1` (level_lead_exp.txt gốc, cột 2). 0 nếu đã tối đa.
static func lead_exp_to_next(lead_level: int) -> int:
	var table: Dictionary = data()["team"]["lead_exp_to_next"]
	return int(table.get(str(lead_level + 1), 0))

static func max_lead_level() -> int:
	return int(data()["team"]["lead_exp_to_next"].size())

# ------------------------------------------------------------------ bang hội
static func tong() -> Dictionary:
	return data()["tong"]

## Cấp bang (1..10) -> {money, devote, member}.
static func tong_level_info(level: int) -> Dictionary:
	for row in tong()["levels"]:
		if int(row["level"]) == level:
			return row
	return {}

## Số thành viên tối đa của bang: bảng cấp bang, nhưng không quá TongMaxMemberCount của VNG.
static func tong_member_cap(level: int) -> int:
	var info := tong_level_info(level)
	var cap := int(tong()["max_member"])
	return mini(int(info.get("member", cap)), cap) if not info.is_empty() else cap

## Kinh nghiệm bang cần để lên cấp `level` (bảng [LevelExp] của Tong_Setting.ini VNG).
static func tong_exp_for_level(level: int) -> int:
	return int(tong()["level_exp"].get(str(level), 0))

# ------------------------------------------------------------------ rương / giao dịch
static func box() -> Dictionary:
	return data()["box"]

extends Resource
class_name SkillStatLine
## 1 dòng chỉ số hiển thị trong popup SkillBookScreen. Thiết kế linh hoạt vì mỗi skill VLTK dùng
## tổ hợp field số liệu khác nhau (physicsenhance_p, deadlystrike_p, poisondamage_v,
## seriesdamage_p...) — không cứng field riêng cho từng loại trong SkillDefinition.
##
## 2 kiểu dòng, phân biệt bằng is_range:
##  - is_range = false (VD "%", "Tiêu hao nội lực"): 1 SỐ, nội suy TUYẾN TÍNH theo cấp giữa
##    value_at_level_1 và value_at_max_level. VD "Ngũ Hành tương khắc: 20% → 80%".
##  - is_range = true (VD "Sát thương vật lý"): khoảng MIN-MAX ngẫu nhiên khi roll damage TẠI 1
##    CẤP CỤ THỂ (VLTK ghi "100 đến 100 điểm") — cả min lẫn max đều nội suy tuyến tính riêng theo
##    cấp (min_at_level_1→min_at_max_level, max_at_level_1→max_at_max_level), rồi hiển thị
##    "X đến Y điểm" ở đúng cấp đó. min==max là hợp lệ (skill không có độ ngẫu nhiên).

@export var label: String = ""
@export var is_range: bool = false

## Dùng khi is_range = false.
@export var value_at_level_1: float = 0.0
@export var value_at_max_level: float = 0.0

## Dùng khi is_range = true.
@export var min_at_level_1: float = 0.0
@export var max_at_level_1: float = 0.0
@export var min_at_max_level: float = 0.0
@export var max_at_max_level: float = 0.0

## Hậu tố hiển thị sau giá trị — "%" cho field kiểu _p, "" cho field kiểu _v (số nguyên thô).
@export var suffix: String = ""

## CHỈ DÙNG cho dòng "Tăng sát thương kỹ năng liên kết #N" (addskilldamageN gốc VLTK) — id của
## skill ĐÍCH được buff (khớp SkillDefinition.id của 1 skill KHÁC trong CÙNG môn phái). Rỗng = dòng
## thường/chưa xác định đích. Dùng bởi SkillDefinition.get_support_percent_from_other_skills() để
## quét NGƯỢC: skill nào đang có 1 stat_line trỏ đích = skill đang xem, cộng dồn % của nó lại —
## hiển thị thành dòng "Hỗ trợ từ các kỹ năng khác: X%" trong popup skill (xem ảnh mẫu VLTK gốc,
## SkillBookScreen._build_detail_popup). Đây là CHIỀU NGƯỢC của field này (skill A buff cho B thì
## khi xem B phải thấy "được A hỗ trợ X%").
@export var target_skill_id: String = ""

func format_at_level(skill: SkillDefinition, at_level: int) -> String:
	if is_range:
		var lo := skill.interpolate_at_level(min_at_level_1, min_at_max_level, at_level)
		var hi := skill.interpolate_at_level(max_at_level_1, max_at_max_level, at_level)
		return "%s: %d đến %d điểm" % [label, int(lo), int(hi)]
	var value := skill.interpolate_at_level(value_at_level_1, value_at_max_level, at_level)
	return "%s: %d%s" % [label, int(value), suffix]

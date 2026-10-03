extends RefCounted
class_name ElementTypes
## Hệ Ngũ Hành dùng xuyên suốt game (môn phái, skill, damage) — tách khỏi gem_system (đã gỡ bỏ)
## vì đây là khái niệm gameplay cốt lõi, không phải riêng của hệ thống gem cũ.

enum ElementType {
	KIM,
	MOC,
	THUY,
	HOA,
	THO,
}

static func element_to_string(element: ElementType) -> String:
	match element:
		ElementType.KIM: return "kim"
		ElementType.MOC: return "moc"
		ElementType.THUY: return "thuy"
		ElementType.HOA: return "hoa"
	return "tho"

static func string_to_element(value: String) -> ElementType:
	match value:
		"kim": return ElementType.KIM
		"moc": return ElementType.MOC
		"thuy": return ElementType.THUY
		"hoa": return ElementType.HOA
	return ElementType.THO

const ELEMENT_NAME := {
	ElementType.KIM: "Kim",
	ElementType.MOC: "Mộc",
	ElementType.THUY: "Thủy",
	ElementType.HOA: "Hỏa",
	ElementType.THO: "Thổ",
}

## Màu đại diện mỗi hệ — dùng cho placeholder (chưa có icon thật) ở màn Chọn Nhân Vật và bảng
## Kỹ Năng Võ Công, để UI vẫn phân biệt được trực quan theo hệ khi chưa có ảnh icon skill.
const ELEMENT_COLOR := {
	ElementType.KIM: Color(0.85, 0.85, 0.75),
	ElementType.MOC: Color(0.30, 0.65, 0.30),
	ElementType.THUY: Color(0.25, 0.45, 0.80),
	ElementType.HOA: Color(0.85, 0.25, 0.20),
	ElementType.THO: Color(0.60, 0.45, 0.25),
}

## Ngũ Hành TƯƠNG KHẮC — bên tấn công khắc bên bị đánh khi attacker == key và defender == value.
## NGUYÊN VĂN từ server VLTK gốc (KNpc.cpp:2600-2604, hàm CalcDamage — xem
## docs/vltk_player_stats_reference.md mục 11.5): Kim khắc Mộc, Thủy khắc Hỏa, Mộc khắc Thổ,
## Hỏa khắc Kim, Thổ khắc Thủy. Khi khớp cặp này, bên tấn công được giảm kháng của mục tiêu +
## cộng thêm damage tuyệt đối (xem CombatFormulas.apply_five_elements_clash).
const BEATS := {
	ElementType.KIM: ElementType.MOC,
	ElementType.THUY: ElementType.HOA,
	ElementType.MOC: ElementType.THO,
	ElementType.HOA: ElementType.KIM,
	ElementType.THO: ElementType.THUY,
}

## true nếu `attacker` khắc `defender` theo Ngũ Hành (tra ngược từ BEATS).
static func does_beat(attacker: ElementType, defender: ElementType) -> bool:
	return BEATS.get(attacker) == defender

## true nếu `defender` khắc lại `attacker` (chiều ngược lại — attacker bị khắc chế).
static func is_beaten_by(attacker: ElementType, defender: ElementType) -> bool:
	return BEATS.get(defender) == attacker

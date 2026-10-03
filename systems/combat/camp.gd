extends RefCounted
class_name Camp
## PHE (camp) của nhân vật — thể hiện bằng MÀU TÊN. Đồng đội = CÙNG MÀU (cùng phe), KHÔNG phải cùng môn
## phái: môn phái chỉ cho phe MẶC ĐỊNH (SectDefinition.default_camp), nhân vật có thể đổi phe (VD bật
## PK thành Sát thủ, vào sự kiện/bang chiến) nên cùng phái vẫn có lúc khác màu.
## Nguồn: enum NPCCAMP (GameDataDef.h), màu tên (KNpc.cpp phần vẽ tên), luật quan hệ
## KNpcSet::GenOneRelation — NGUYÊN VĂN gốc VLTK.

enum Type { BEGIN, JUSTICE, EVIL, BALANCE, FREE, ANIMAL, EVENT, AUDIENCE, TONGWAR }

const NAMES := {
	Type.BEGIN: "Tân thủ", Type.JUSTICE: "Chính phái", Type.EVIL: "Tà phái", Type.BALANCE: "Trung lập",
	Type.FREE: "Sát thủ", Type.ANIMAL: "Quái", Type.EVENT: "Sự kiện", Type.AUDIENCE: "Khán giả",
	Type.TONGWAR: "Bang chiến",
}
const COLORS := {
	Type.BEGIN: Color8(255, 255, 255), Type.JUSTICE: Color8(255, 168, 94), Type.EVIL: Color8(255, 146, 255),
	Type.BALANCE: Color8(85, 255, 145), Type.FREE: Color8(255, 0, 0), Type.ANIMAL: Color8(255, 255, 255),
	Type.EVENT: Color8(238, 18, 137), Type.AUDIENCE: Color8(255, 255, 255), Type.TONGWAR: Color8(104, 38, 174),
}

enum Relation { NONE, ALLY, ENEMY }

## Phe MẶC ĐỊNH theo môn phái — SectDefinition.alignment (khớp Camp= trong settings/faction/门派设定.ini
## gốc: C_JUSTICE/C_EVIL/C_BALANCE).
static func default_for_sect(sect: SectDefinition) -> int:
	if sect == null:
		return Type.BEGIN
	match sect.alignment:
		SectEnums.Alignment.CHINH_PHAI:
			return Type.JUSTICE
		SectEnums.Alignment.TA_PHAI:
			return Type.EVIL
	return Type.BALANCE

static func get_color(camp: int) -> Color:
	return COLORS.get(camp, Color.WHITE)

static func get_camp_name(camp: int) -> String:
	return NAMES.get(camp, "?")

## KNpcSet::GenOneRelation gốc — quan hệ giữa 2 phe. `both_players` = cả 2 là người chơi.
static func relation(camp_a: int, camp_b: int, both_players: bool) -> Relation:
	if camp_a == Type.EVENT or camp_b == Type.EVENT:
		return Relation.NONE
	if (camp_a == Type.BEGIN and camp_b == Type.ANIMAL) or (camp_a == Type.ANIMAL and camp_b == Type.BEGIN):
		return Relation.ENEMY
	if camp_a == Type.BEGIN or camp_b == Type.BEGIN:
		return Relation.ALLY  ## có tân thủ thì là đồng minh — mọi người giúp tân thủ
	if both_players and (camp_a == Type.FREE or camp_b == Type.FREE):
		return Relation.ENEMY  ## 1 người bật PK (Sát thủ, tên đỏ) là đánh nhau được
	if camp_a == camp_b:
		return Relation.ALLY   ## CÙNG MÀU = đồng đội
	return Relation.ENEMY

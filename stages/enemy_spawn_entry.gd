extends Resource
class_name EnemySpawnEntry
## Gắn 1 EnemyTierData (loại quái) vào 1 map CỤ THỂ, kèm hệ số NHÂN riêng cho map đó — cho phép
## CÙNG 1 loại quái (VD "Sói Rừng") xuất hiện ở nhiều map với độ mạnh khác nhau (map dễ: yếu hơn,
## map khó: mạnh hơn) mà KHÔNG cần tạo file EnemyTierData riêng cho từng map.
##
## Đây là thứ kéo vào field `enemy_tiers`/`boss_tier` của StageData (THAY vì kéo thẳng
## EnemyTierData như trước) — xem CombatantStats.from_enemy_tier() để biết công thức áp hệ số nhân.
##
## MẶC ĐỊNH mọi hệ số = 1.0 (không đổi gì) — nếu map không cần chỉnh riêng, chỉ cần gán `tier` và
## để nguyên các multiplier, quái sẽ có ĐÚNG chỉ số gốc trong EnemyTierData.

## Quái gốc (base stats) — 1 EnemyTierData có thể dùng lại ở nhiều StageData khác nhau.
@export var tier: EnemyTierData

@export_group("Hệ số nhân riêng cho map này (1.0 = giữ nguyên gốc)")
## Nhân vào Strength gốc — tăng để quái đánh đau hơn Ở MAP NÀY, không ảnh hưởng map khác dùng
## cùng `tier`.
@export var strength_multiplier: float = 1.0
## Nhân vào Dexterity gốc — tăng để quái đánh trúng player dễ hơn VÀ né đòn giỏi hơn Ở MAP NÀY.
@export var dexterity_multiplier: float = 1.0
## Nhân vào Vitality gốc — tăng để quái nhiều máu hơn Ở MAP NÀY.
@export var vitality_multiplier: float = 1.0
## Nhân vào Energy gốc — ít ý nghĩa với quái thường (xem ghi chú Energy trong EnemyTierData).
@export var energy_multiplier: float = 1.0
## Cộng THÊM vào level gốc — map khó hơn có thể cho quái cùng loại cao cấp hơn vài level.
@export var level_add: int = 0

## Thuộc tính magic THÊM riêng cho map này (cộng chồng lên EnemyTierData.extra_attribs) — VD map lửa
## cho quái thêm {"fireres_p": (20,0,0)}.
@export var extra_attribs: Dictionary[String, Vector3i] = {}

## Bản dựng combat của quái ở map này — CÙNG định dạng với player (CombatantBuild):
##   cấp = tier.level + level_add; chỉ số = (gốc + stat_growth_per_level × số cấp tăng) × hệ số map.
func to_build() -> CombatantBuild:
	var b := CombatantBuild.new()
	b.level = tier.level + level_add
	b.element = tier.element
	var growth := tier.stat_growth_per_level * maxi(level_add, 0)
	b.strength = int((tier.strength + growth.x) * strength_multiplier)
	b.dexterity = int((tier.dexterity + growth.y) * dexterity_multiplier)
	b.vitality = int((tier.vitality + growth.z) * vitality_multiplier)
	b.energy = int((tier.energy + growth.w) * energy_multiplier)
	b.sect_id = tier.sect_id
	for skill_id in tier.skill_levels:
		b.skill_levels[skill_id] = tier.skill_levels[skill_id]
	for attrib_name in tier.extra_attribs:
		b.extra_attribs[attrib_name] = tier.extra_attribs[attrib_name]
	for attrib_name in extra_attribs:
		b.extra_attribs[attrib_name] = b.extra_attribs.get(attrib_name, Vector3i.ZERO) + extra_attribs[attrib_name]
	return b

## Thời điểm/tần suất xuất hiện — RIÊNG CHO MAP NÀY (khác EnemyTierData.unlock_time/spawn_weight cũ,
## vốn dùng chung mọi map). Cùng 1 quái có thể xuất hiện sớm/muộn, nhiều/ít khác nhau tuỳ map.
@export var unlock_time: float = 0.0
## Thời điểm dừng spawn (giây). 0.0 = không khoá, quái spawn cho đến khi hết màn/boss ra.
@export var lock_time: float = 0.0
@export var spawn_weight: float = 10.0
@export var weight_change_per_second: float = 0.0

extends RefCounted
class_name StatusEffectFactory
## Factory tạo StatusEffect chuẩn theo effect_id — tập trung công thức duration/tick/damage
## 1 chỗ để 200+ gem "Hỏa Hóa", "Độc Tố", "Chảy Máu"... đều dùng chung logic nhất quán,
## chỉ khác nhau ở damage_per_hit/chance truyền vào từ SkillResolver.

const DEFAULT_TICK_RATE := {
	"burn": 0.5,
	"poison": 0.5,
	"bleed": 0.5,
}

const DEFAULT_DURATION := {
	"burn": 4.0,
	"freeze": 1.5,
	"shock": 2.0,
	"poison": 6.0,
	"bleed": 5.0,
	"slow": 2.0,
	"stun": 1.0,
}

static func create(effect_id: String, base_hit_damage: float, element: ElementTypes.ElementType, damage_ratio: float = 0.2, duration_override: float = -1.0, magnitude_override: float = -1.0) -> StatusEffect:
	var duration: float = duration_override if duration_override > 0.0 else DEFAULT_DURATION.get(effect_id, 3.0)
	var tick_rate: float = DEFAULT_TICK_RATE.get(effect_id, 1.0)
	var is_damage_over_time := effect_id in ["burn", "poison", "bleed"]
	var damage_per_tick := base_hit_damage * damage_ratio if is_damage_over_time else 0.0
	var magnitude := 0.0
	match effect_id:
		"slow":
			magnitude = 0.3
		"freeze":
			magnitude = 1.0  ## 1.0 = hoàn toàn đóng băng (không di chuyển)
	if magnitude_override >= 0.0:
		magnitude = magnitude_override

	var effect := StatusEffect.new(effect_id, duration, damage_per_tick, tick_rate, magnitude)
	effect.source_element = element
	effect.visual_effect_name = effect_id + "_vfx"
	return effect

extends RefCounted
class_name MagicAttribTable
## BẢNG DUY NHẤT "tên thuộc tính magic VLTK -> chỉ số nhân vật" — tương đương ProcessFunc của
## KNpcAttribModify.cpp gốc. MỌI nguồn cộng chỉ số đều đi qua đây: skill nội tại đã học, buff/bùa
## đang dính (StatusEffectController), thuộc tính thêm của quái (EnemyTierData.attribs), trang bị sau
## này... -> thêm 1 nguồn mới KHÔNG cần viết bảng riêng, chỉ cần đưa {tên: Vector3i} vào
## CombatantStats.build().
##
## Giá trị 1 thuộc tính = Vector3i(nValue[0], nValue[1], nValue[2]) như KMagicAttrib gốc (thường chỉ
## dùng [0]; [1] của thuộc tính trạng thái là thời gian hiệu lực — do StatusEffectController xử lý).
## Thuộc tính chưa có trong bảng bị bỏ qua (xem UNSUPPORTED để biết vì sao).

## Hằng số gốc GameDataDef.h — bonus Băng/Độc sát của NHÂN VẬT luôn mang thời gian cố định này
## (AddColdDamageV/AddPoisonDamageV gốc bỏ qua [1]/[2] của dữ liệu, gán hằng số).
const COLD_DAMAGE_TIME := 60
const POISON_DAMAGE_TIME := 60
const POISON_DAMAGE_INTERVAL := 10

## Chỉ số GỐC — phải áp TRƯỚC khi tính HP/Mana/AttackRating/Defense/Damage (CombatantStats.build pass 1).
const BASE_STAT_ATTRIBS := ["strength_v", "dexterity_v", "vitality_v", "energy_v"]

const _RESIST := {
	"fireres_p": CombatFormulas.DamageType.FIRE, "fireres_yan_p": CombatFormulas.DamageType.FIRE,
	"coldres_p": CombatFormulas.DamageType.COLD, "coldres_yan_p": CombatFormulas.DamageType.COLD,
	"poisonres_p": CombatFormulas.DamageType.POISON, "poisonres_yan_p": CombatFormulas.DamageType.POISON,
	"lightingres_p": CombatFormulas.DamageType.LIGHT, "lightingres_yan_p": CombatFormulas.DamageType.LIGHT,
	"physicsres_p": CombatFormulas.DamageType.PHYSICS, "physicsres_yan_p": CombatFormulas.DamageType.PHYSICS,
}
const _RESIST_MAX := {
	"fireresmax_p": CombatFormulas.DamageType.FIRE, "coldresmax_p": CombatFormulas.DamageType.COLD,
	"poisonresmax_p": CombatFormulas.DamageType.POISON, "lightingresmax_p": CombatFormulas.DamageType.LIGHT,
	"physicsresmax_p": CombatFormulas.DamageType.PHYSICS,
}
const _ARMOR := {
	"physicsarmor_v": CombatFormulas.DamageType.PHYSICS, "coldarmor_v": CombatFormulas.DamageType.COLD,
	"firearmor_v": CombatFormulas.DamageType.FIRE, "poisonarmor_v": CombatFormulas.DamageType.POISON,
	"lightingarmor_v": CombatFormulas.DamageType.LIGHT,
}
## "X sát ngoại công" (m_CurrentXDamage) / "X sát nội công" (m_CurrentXMagic).
const _OUTER_ELEMENT := {
	"addcolddamage_v": CombatFormulas.DamageType.COLD, "addfiredamage_v": CombatFormulas.DamageType.FIRE,
	"addlightingdamage_v": CombatFormulas.DamageType.LIGHT, "addpoisondamage_v": CombatFormulas.DamageType.POISON,
}
const _INNER_ELEMENT := {
	"addcoldmagic_v": CombatFormulas.DamageType.COLD, "addfiremagic_v": CombatFormulas.DamageType.FIRE,
	"addlightingmagic_v": CombatFormulas.DamageType.LIGHT, "addpoisonmagic_v": CombatFormulas.DamageType.POISON,
}
const _ALL_TYPES := [CombatFormulas.DamageType.FIRE, CombatFormulas.DamageType.COLD,
	CombatFormulas.DamageType.POISON, CombatFormulas.DamageType.LIGHT, CombatFormulas.DamageType.PHYSICS]

## Áp chỉ số GỐC (Sức mạnh/Thân pháp/Sinh khí/Nội công) — pass 1, trước công thức cốt lõi.
static func apply_base_stat(s: CombatantStats, attrib_name: String, v: Vector3i) -> void:
	match attrib_name:
		"strength_v": s.strength += v.x
		"dexterity_v": s.dexterity += v.x
		"vitality_v": s.vitality += v.x
		"energy_v": s.energy += v.x

## Áp 1 thuộc tính (pass 2, sau công thức cốt lõi). Trả về false nếu bảng chưa hỗ trợ tên này.
static func apply(s: CombatantStats, attrib_name: String, v: Vector3i) -> bool:
	if attrib_name in BASE_STAT_ATTRIBS:
		return true  ## đã áp ở pass 1
	if _RESIST.has(attrib_name):
		s.resist_percent[_RESIST[attrib_name]] = s.resist_percent.get(_RESIST[attrib_name], 0) + v.x
		return true
	if _RESIST_MAX.has(attrib_name):
		s.resist_percent_cap[_RESIST_MAX[attrib_name]] = s.resist_percent_cap.get(_RESIST_MAX[attrib_name], CombatFormulas.MAX_RESIST) + v.x
		return true
	if _ARMOR.has(attrib_name):
		s.flat_armor[_ARMOR[attrib_name]] = s.flat_armor.get(_ARMOR[attrib_name], 0) + v.x
		return true
	if _OUTER_ELEMENT.has(attrib_name):
		_add_element(s.outer_element_damage, _OUTER_ELEMENT[attrib_name], v.x)
		return true
	if _INNER_ELEMENT.has(attrib_name):
		_add_element(s.inner_element_damage, _INNER_ELEMENT[attrib_name], v.x)
		return true
	match attrib_name:
		"allres_p", "allres_yan_p":
			for t in _ALL_TYPES:
				s.resist_percent[t] = s.resist_percent.get(t, 0) + v.x
		"allresmax_p":
			for t in _ALL_TYPES:
				s.resist_percent_cap[t] = s.resist_percent_cap.get(t, CombatFormulas.MAX_RESIST) + v.x
		"lifemax_v", "lifemax_yan_v":
			s.max_hp += v.x
		"lifemax_p", "lifemax_yan_p":
			s.max_hp += s.base_max_hp * v.x / 100
		"manamax_v", "manamax_yan_v":
			s.max_mana += v.x
		"manamax_p", "manamax_yan_p":
			s.max_mana += s.base_max_mana * v.x / 100
		"attackrating_v", "attackratingenhance_v":
			s.attack_rating += v.x
		"attackrating_p", "attackratingenhance_p":
			s.attack_rating += s.base_attack_rating * v.x / 100
		"armordefense_v", "adddefense_v":
			s.defense += v.x
		"addphysicsdamage_v":
			s.add_physics_damage += v.x
		"addphysicsdamage_p":
			s.outer_physics_enhance_p += v.x
		"addphysicsmagic_v":
			s.add_physics_magic += v.x
		"deadlystrikeenhance_p":
			s.deadly_strike_enhance_p += v.x
		"coldenhance_p":
			s.cold_enhance_frames += v.x
		"poisonenhance_p":
			s.poison_enhance_p += v.x
		"lightingenhance_p":
			s.lighting_enhance_p += v.x
		"fireenhance_p":
			s.fire_enhance_p += v.x
		"freezetimereduce_p":
			s.freeze_time_reduce_p += v.x
		"poisontimereduce_p":
			s.poison_time_reduce_p += v.x
		"stuntimereduce_p":
			s.stun_time_reduce_p += v.x
		"fastwalkrun_p", "fastwalkrun_yan_p":
			s.move_speed_p += v.x
		"lifereplenish_v":
			s.life_replenish += v.x
		"lifereplenish_p":
			s.life_replenish_p += v.x
		"meleedamagereturn_p":
			s.melee_damage_return_p += v.x
		"meleedamagereturn_v":
			s.melee_damage_return += v.x
		"rangedamagereturn_p":
			s.range_damage_return_p += v.x
		"rangedamagereturn_v":
			s.range_damage_return += v.x
		"steallife_p", "steallifeenhance_p":
			s.steal_life_p += v.x
		"attackspeed_v", "attackspeed_yan_v":
			s.attack_speed += v.x
		"castspeed_v", "castspeed_yan_v":
			s.cast_speed += v.x
		"five_elements_enhance_v":
			s.five_elements_enhance += v.x
		"five_elements_resist_v":
			s.five_elements_resist += v.x
		"expenhance_p":
			s.exp_enhance_p += v.x
		"lucky_v":
			s.lucky_v += v.x
		_:
			return false
	return true

## AddColdDamageV/AddPoisonDamageV gốc: cộng [0] vào cả min lẫn max (thời gian là hằng số, xem trên).
static func _add_element(pool: Dictionary, damage_type: int, value: int) -> void:
	pool[damage_type] = pool.get(damage_type, Vector2i.ZERO) + Vector2i(value, value)

## Thuộc tính GỐC có nhưng bảng CHƯA áp (game chưa có hệ thống tương ứng) — ghi lại để khỏi tưởng
## là bị sót: nội lực/thể lực (game không dùng mana), khiên nội lực, hồi phục khi bị đánh, vật phẩm,
## ẩn thân, đổi phe, tự động thi triển skill khác (auto*skill), cộng cấp skill...
const UNSUPPORTED := ["mana_v", "manareplenish_v", "stamina_v", "staminamax_v", "staminamax_p",
	"staminareplenish_v", "stealmana_p", "stealmanaenhance_p", "stealstamina_p", "manashield_p",
	"staticmagicshield_p", "dynamicmagicshield_v", "fasthitrecover_v", "fasthitrecover_yan_v",
	"lifepotion_v", "manapotion_v", "hide", "changecamp_b", "allskill_v",
	"autoattackskill", "autodeathskill", "autoreplyskill", "autorescueskill", "ignoreskill_p",
	"returnskill_p", "fatallystrikeenhance_p", "fatallystrikeres_p", "burntimereduce_p", "visionradius_p"]

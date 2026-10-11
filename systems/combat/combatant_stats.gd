extends RefCounted
class_name CombatantStats
## Toàn bộ chỉ số combat của MỘT bên tham chiến — dùng CHUNG cho Player lẫn Enemy, đúng kiến trúc
## VLTK gốc (server gốc dùng chung 1 mảng Npc[] cho cả player và quái, xem KNpc.cpp — không tách
## 2 class riêng biệt như PlayerAttributes/EnemyAttributes). Thay thế hoàn toàn CharacterAttributes
## + PlayerDefenseStats cũ (đã xoá) — 2 file đó tính damage/defense áng chừng, không khớp VLTK.
##
## THIẾT KẾ CHO ONLINE: đây là snapshot số liệu THUẦN (không animation/scene node), tính deterministic
## từ input (from_profile/from_enemy_tier) — server tính 1 lần, gửi cho client hiển thị, không có
## state ẩn nào lệch giữa 2 phía. Roll ngẫu nhiên (miss/crit/damage range) nằm ở CombatFormulas,
## KHÔNG nằm ở đây — giữ CombatantStats thuần data để dễ serialize qua network sau này.
##
## NGUỒN CÔNG THỨC: docs/vltk_player_stats_reference.md mục 1, 2, 5, 6, 11 — mọi hệ số bên dưới
## trích dẫn NGUYÊN VĂN từ server VLTK gốc, không áng chừng (trừ những chỗ ghi rõ "KHÔNG có nguồn
## gốc" trong comment tương ứng).

## ---- 4 chỉ số gốc — người chơi cộng điểm tiềm năng vào đây (xem PlayerProfile) ----
var strength: int = 5
var dexterity: int = 5
var vitality: int = 5
var energy: int = 5

var level: int = 1
var female: bool = false
## Người chơi: kháng theo hệ = hệ_số × cấp / 100 (KLevelAdd::GetXxxResist gốc — cấp 1 ra 0%). Quái giữ nguyên hệ số.
var scale_resist_by_level: bool = false
var element: ElementTypes.ElementType = ElementTypes.ElementType.KIM

## ---- HP/Mana/Stamina tối đa — CHÍNH XÁC 100% VLTK, xem ELEMENT_LEVEL_ADD ----
var max_hp: int = 0
var max_mana: int = 0
var max_stamina: int = 0

## ---- AttackRating & Defense — CHÍNH XÁC 100% VLTK (KPlayer.cpp:7166,7171), chỉ phụ thuộc Dexterity ----
var attack_rating: int = 0
var defense: int = 0

## ---- Damage tay không gốc — CHÍNH XÁC 100% VLTK (KPlayer.cpp:7112-7118), chỉ phụ thuộc Strength.
## Vũ khí/skill CỘNG THÊM vào đây qua add_physics_damage (tương ứng m_CurrentAddPhysicsDamage gốc,
## xem docs mục 11.3) — không nhân vào min/max unarmed, mà CỘNG SAU khi đã roll base.
var unarmed_min_damage: int = 0
var unarmed_max_damage: int = 0
var add_physics_damage: int = 0  ## Bonus damage tuyệt đối từ skill/trang bị — reset mỗi lần resolve

## ---- % kháng theo loại damage (0 nếu chưa có hệ trang bị/passive tương ứng bù thêm) ----
## Key: CombatFormulas.DamageType. Value: % kháng (int, đã cộng base từ Ngũ Hành + bonus trang bị).
var resist_percent: Dictionary = {}       ## CombatFormulas.DamageType -> int
var resist_percent_cap: Dictionary = {}   ## CombatFormulas.DamageType -> int (*ResistMax riêng từng loại)
var flat_armor: Dictionary = {}           ## CombatFormulas.DamageType -> int (m_PhysicsArmor/...)

## Ngũ Hành tăng cường/kháng riêng cho cơ chế TƯƠNG KHẮC (m_CurrentFiveElementsEnhance/Resist gốc,
## xem docs mục 11.5+11.10 — nguồn gán giá trị gốc chưa xác định đầy đủ trong mã nguồn đã đọc,
## mặc định 0 cho tới khi game có hệ trang bị/passive cộng thêm 2 chỉ số này).
var five_elements_enhance: int = 0
var five_elements_resist: int = 0

## ---- Bonus damage của NHÂN VẬT cộng vào skill khi thi triển (KNpc::AppendSkillEffect gốc) — nguồn
## hiện tại: skill nội tại đã học (sau này cộng thêm trang bị). DamageType -> Vector2i(min, max).
## "X sát ngoại công" (m_CurrentColdDamage/m_CurrentFireDamage/...) — cộng vào MỌI skill ngoại công.
var outer_element_damage: Dictionary = {}
## "X sát nội công" (m_CurrentColdMagic/m_CurrentFireMagic/...) — cộng vào skill nội công CÓ hệ đó.
var inner_element_damage: Dictionary = {}
## "Sát thương vật lý - ngoại công %" (m_CurrentMeleeEnhance/RangeEnhance/HandEnhance) — cộng vào %
## tăng damage vật lý của skill ngoại công.
var outer_physics_enhance_p: int = 0
## "Tấn công chí mạng %" của nhân vật (m_CurrentDeadlyStrikeEnhanceP) — chỉ cộng cho skill ngoại công.
var deadly_strike_enhance_p: int = 0

## ---- Hiệu ứng trúng đòn (KNpc::AppendSkillEffect/ReceiveDamage gốc), đơn vị như VLTK:
var cold_enhance_frames: int = 0      ## m_CurrentColdEnhance — + frame làm chậm cho đòn Băng sát của MÌNH
var poison_enhance_p: int = 0         ## m_CurrentPoisonEnhance — - % nhịp rút máu độc MÌNH gây ra
var lighting_enhance_p: int = 0       ## m_CurrentLightEnhance — kéo damage Lôi tối thiểu lên gần tối đa
var fire_enhance_p: int = 0           ## m_CurrentFireEnhance (gốc dùng cho trạng thái thiêu đốt — chưa có)
var freeze_time_reduce_p: int = 0     ## khi BỊ trúng: - % thời gian bị làm chậm
var poison_time_reduce_p: int = 0     ## khi BỊ trúng: - % thời gian trúng độc
var stun_time_reduce_p: int = 0       ## khi BỊ trúng: - % thời gian choáng
var add_physics_magic: int = 0        ## m_CurrentAddPhysicsMagic — + damage vật lý cho skill NỘI công có physicsdamage_v

## ---- Chỉ số khác từ thuộc tính (MagicAttribTable) ----
var move_speed_p: int = 0             ## fastwalkrun_p — % tốc chạy
var life_replenish: int = 0           ## lifereplenish_v — máu hồi mỗi GAME_UPDATE_TIME (10 frame)
var life_replenish_p: int = 0         ## lifereplenish_p — % cộng thêm vào lượng hồi trên
var melee_damage_return_p: int = 0    ## phản % damage cận chiến về người đánh
var melee_damage_return: int = 0
var range_damage_return_p: int = 0    ## phản % damage tầm xa (đạn/skill bay) về người đánh
var range_damage_return: int = 0
var steal_life_p: int = 0             ## % damage vật lý gây ra hút thành máu
var attack_speed: int = 0             ## attackspeed_v / castspeed_v — gốc giảm số frame ra đòn (chưa áp)
var cast_speed: int = 0

## Giá trị TRƯỚC khi cộng thuộc tính — cho các thuộc tính % (lifemax_p = % của máu gốc, đúng
## m_LifeMax gốc; attackrating_p = % của m_AttackRating gốc).
var base_max_hp: int = 0
var base_max_mana: int = 0
var base_attack_rating: int = 0

## ==============================================================================================
## Bảng hệ số HP/Mana/Kháng cơ bản theo Ngũ Hành — NGUYÊN VĂN settings/npc/player/level_add.txt,
## xem docs/vltk_player_stats_reference.md mục 5. Đặt tại đây (không phải CombatFormulas) vì đây
## là DỮ LIỆU cấu hình theo hệ, không phải công thức — CombatFormulas chỉ chứa công thức thuần.
## ==============================================================================================
const ELEMENT_LEVEL_ADD := {
	ElementTypes.ElementType.KIM: {"life_per_level": 4, "life_per_vitality": 8, "mana_per_level": 1, "mana_per_energy": 1,
		"res": {"fire": -25, "cold": 0, "poison": 25, "lighting": 0, "physic": 0}},
	ElementTypes.ElementType.MOC: {"life_per_level": 3, "life_per_vitality": 5, "mana_per_level": 2, "mana_per_energy": 3,
		"res": {"fire": 0, "cold": 0, "poison": 0, "lighting": 25, "physic": -15}},
	ElementTypes.ElementType.THUY: {"life_per_level": 3, "life_per_vitality": 6, "mana_per_level": 2, "mana_per_energy": 3,
		"res": {"fire": 25, "cold": 0, "poison": 0, "lighting": -25, "physic": 0}},
	ElementTypes.ElementType.HOA: {"life_per_level": 3, "life_per_vitality": 7, "mana_per_level": 1, "mana_per_energy": 2,
		"res": {"fire": 0, "cold": -25, "poison": 0, "lighting": 0, "physic": 15}},
	ElementTypes.ElementType.THO: {"life_per_level": 1, "life_per_vitality": 3, "mana_per_level": 3, "mana_per_energy": 4,
		"res": {"fire": 0, "cold": 25, "poison": -25, "lighting": 0, "physic": 0}},
}

## Stamina — khởi điểm 100 (imaxstamina của NewPlayerIni, khớp ảnh nhân vật gốc cấp 1). level_add.txt gốc ghi
## StaminaPerVitality = 0 cho cả 5 hệ: cộng Sinh khí KHÔNG làm tăng thể lực.
const STAMINA_BASE := 100
const STAMINA_PER_VITALITY := 0
## Thể lực mỗi cấp (KLevelAdd::GetStaminaPerLevel gốc; cả 5 hệ cùng số): 100 + (cấp-1) x 9 nam / x 8 nữ — khớp 280 ở cấp 21, 370 ở cấp 31.
const STAMINA_PER_LEVEL_MALE := 9
const STAMINA_PER_LEVEL_FEMALE := 8

## ĐƯỜNG DỰNG CHỈ SỐ DUY NHẤT cho mọi bên tham chiến (player, quái, người chơi khác khi online):
##   1. Chỉ số gốc từ `build` (cấp, hệ, 4 chỉ số) + thuộc tính strength_v/... (pass 1)
##   2. Công thức cốt lõi VLTK (HP/Mana/AttackRating/Defense/Damage tay không/kháng theo hệ)
##   3. Mọi thuộc tính còn lại qua MagicAttribTable (pass 2), từ: thuộc tính cố định của bản dựng
##      (skill nội tại đã học, thuộc tính thêm của quái) + `state_sources` (buff/bùa đang dính, lấy
##      từ StatusEffectController.get_state_attrib_sources()).
## Deterministic: cùng input -> cùng kết quả, server/client tính giống nhau.
static func build(b: CombatantBuild, state_sources: Array[Dictionary] = []) -> CombatantStats:
	var s := CombatantStats.new()
	s.level = b.level
	s.female = b.female
	s.element = b.element
	s.scale_resist_by_level = b.sect_id != ""
	s.strength = b.strength
	s.dexterity = b.dexterity
	s.vitality = b.vitality
	s.energy = b.energy

	var sources := b.get_permanent_attrib_sources()
	sources.append_array(state_sources)
	for source in sources:
		for attrib_name in source:
			if attrib_name in MagicAttribTable.BASE_STAT_ATTRIBS:
				MagicAttribTable.apply_base_stat(s, attrib_name, source[attrib_name])

	s._apply_core_formulas()
	s._apply_weapon_damage(b.equipment)
	s.base_max_hp = s.max_hp
	s.base_max_mana = s.max_mana
	s.base_attack_rating = s.attack_rating

	for source in sources:
		for attrib_name in source:
			MagicAttribTable.apply(s, attrib_name, source[attrib_name])
	_apply_legacy_passive_bonus(s, b)
	return s

static func from_profile(profile: PlayerProfile, state_sources: Array[Dictionary] = []) -> CombatantStats:
	return build(profile.to_build(), state_sources)

## Quái = "1 player được cấu hình sẵn" — xem EnemySpawnEntry.to_build() (chỉ số gốc EnemyTierData +
## tăng trưởng theo cấp + hệ số map + thuộc tính thêm).
static func from_enemy_tier(entry: EnemySpawnEntry, state_sources: Array[Dictionary] = []) -> CombatantStats:
	return build(entry.to_build(), state_sources)

## Áp công thức HP/Mana/AttackRating/Defense/Damage — tách riêng khỏi from_profile() để dễ gọi lại
## khi Strength/Dexterity/Vitality/Energy đổi (VD cộng điểm tiềm năng) mà không cần dựng lại từ đầu.
func _apply_core_formulas() -> void:
	var coeff: Dictionary = ELEMENT_LEVEL_ADD[element]
	max_hp = int(coeff.life_per_level) * level + vitality * int(coeff.life_per_vitality)
	max_mana = int(coeff.mana_per_level) * level + energy * int(coeff.mana_per_energy)
	max_stamina = STAMINA_BASE + (level - 1) * (STAMINA_PER_LEVEL_FEMALE if female else STAMINA_PER_LEVEL_MALE) + vitality * STAMINA_PER_VITALITY

	attack_rating = CombatFormulas.calc_base_attack_rating(dexterity)
	defense = CombatFormulas.calc_base_defense(dexterity)
	unarmed_min_damage = CombatFormulas.calc_base_unarmed_damage(strength)
	unarmed_max_damage = unarmed_min_damage  ## VLTK gốc: min == max cho damage tay không (KPlayer.cpp:7112-7118)

	_init_resist_defaults()

## Damage vật lý gốc khi CẦM VŨ KHÍ — KPlayer::SetNpcPhysicsDamage gốc: damage vũ khí (Equipment.
## get_weapon_damage) + Sức mạnh/5 (cận chiến) hoặc Thân pháp/5 (ám khí). Tay không giữ Sức mạnh/5.
## Đây là "damage tay không/vũ khí" mà skill ngoại công nhân physicsenhance_p.
func _apply_weapon_damage(equipped: Dictionary) -> void:
	var weapon := Equipment.get_weapon_damage(equipped)
	match weapon["kind"]:
		"melee":
			unarmed_min_damage = weapon["min"] + strength / CombatFormulas.STRENGTH_SET_DAMAGE_VALUE
			unarmed_max_damage = weapon["max"] + strength / CombatFormulas.STRENGTH_SET_DAMAGE_VALUE
		"range":
			unarmed_min_damage = weapon["min"] + dexterity / DEXTERITY_SET_DAMAGE_VALUE
			unarmed_max_damage = weapon["max"] + dexterity / DEXTERITY_SET_DAMAGE_VALUE

const DEXTERITY_SET_DAMAGE_VALUE := 5  ## KPlayer.h gốc

func _init_resist_defaults() -> void:
	var coeff: Dictionary = ELEMENT_LEVEL_ADD.get(element, {})
	var res: Dictionary = coeff.get("res", {})
	var mult: int = level if scale_resist_by_level else 100
	resist_percent[CombatFormulas.DamageType.FIRE] = int(res.get("fire", 0)) * mult / 100
	resist_percent[CombatFormulas.DamageType.COLD] = int(res.get("cold", 0)) * mult / 100
	resist_percent[CombatFormulas.DamageType.POISON] = int(res.get("poison", 0)) * mult / 100
	resist_percent[CombatFormulas.DamageType.LIGHT] = int(res.get("lighting", 0)) * mult / 100
	resist_percent[CombatFormulas.DamageType.PHYSICS] = int(res.get("physic", 0)) * mult / 100
	resist_percent[CombatFormulas.DamageType.MAGIC] = 0
	for type in resist_percent.keys():
		resist_percent_cap[type] = CombatFormulas.MAX_RESIST
		flat_armor[type] = 0

## % kháng thực tế dùng khi tính damage — đã cap theo resist_percent_cap RIÊNG từng loại (khớp
## đúng logic switch(nType) trong CalcDamage gốc: mỗi loại damage có *ResistMax riêng, không dùng
## chung MAX_RESIST cho mọi loại ở bước này — MAX_RESIST chỉ áp SAU KHI cộng tương khắc Ngũ Hành).
func get_capped_resist(damage_type: CombatFormulas.DamageType) -> int:
	var value: int = resist_percent.get(damage_type, 0)
	var cap: int = resist_percent_cap.get(damage_type, CombatFormulas.MAX_RESIST)
	return mini(value, cap)

## Skill nội tại CHƯA có dữ liệu VLTK gốc (không ghép được Skills.txt) vẫn dùng passive_*_bonus nhập
## tay cũ — skill có vltk_attribs đã cộng qua MagicAttribTable trong build(), không cộng lặp ở đây.
static func _apply_legacy_passive_bonus(s: CombatantStats, b: CombatantBuild) -> void:
	var sect := SectRegistry.get_by_id(b.sect_id) if b.sect_id != "" else null
	if sect == null:
		return
	for skill in sect.skills:
		if skill.category != SkillDefinition.SkillCategory.PASSIVE or not skill.vltk_attribs.is_empty():
			continue
		var learned_level := int(b.skill_levels.get(skill.id, 0))
		if learned_level <= 0:
			continue
		s.attack_rating += int(skill.passive_attack_bonus * learned_level)
		s.defense += int(skill.passive_defense_bonus * learned_level)
		s.max_hp += int(skill.passive_max_hp_bonus * learned_level)

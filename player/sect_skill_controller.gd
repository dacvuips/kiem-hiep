extends Node
class_name SectSkillController
## Component gắn lên Player — thay thế SkillManager/GemManager/PartnerManager cũ của gem_system.
## Quản lý cooldown của 1 skill chính (is_main_attack, luôn dùng được) + 4 skill phụ của môn phái
## đã chọn (chỉ dùng được khi GameManager.local_profile đã học, xem PlayerProfile.learn_skill()).
## Không có mana/nội lực — chỉ cooldown giới hạn tần suất thi triển.

signal skill_cast(skill_id: String)

## true = bỏ qua yêu cầu "đã học" (mọi skill dùng/gắn được dù cấp 0) — CHỈ bật tạm khi cần test nhanh;
## bình thường dùng nút TEST ở Hub (DebugCheatPanel) để lên cấp/cộng điểm học skill thật.
const DEBUG_UNLOCK_ALL_SKILLS := false
## Bật true để ép cooldown mọi skill gần như bằng 0 (test nhanh) — false = dùng cooldown thật.
const DEBUG_NO_COOLDOWN := false
const DEBUG_COOLDOWN := 0.05
## Skill bắn đạn có dữ liệu chiêu VLTK gốc (data/skill_fx) chạy bằng bộ máy VltkSkillRunner (đội hình đạn, đường bay,
## va chạm, hiệu ứng như bản gốc); false = về đường cũ SectSkillCast (1 viên Projectile).
const USE_VLTK_SKILL_FX := true

var sect: SectDefinition
var _cooldowns: Dictionary = {}  ## skill_id (String) -> giây còn lại
var _cooldown_totals: Dictionary = {}  ## skill_id (String) -> cooldown gốc (để tính % cho UI)

func setup(sect_def: SectDefinition) -> void:
	sect = sect_def
	_cooldowns.clear()
	_cooldown_totals.clear()

func tick(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] = maxf(0.0, _cooldowns[id] - delta)

## 0.0 = sẵn sàng dùng, 1.0 = vừa thi triển — UI dùng để vẽ radial fill hồi chiêu.
func get_cooldown_ratio(skill_id: String) -> float:
	var total: float = _cooldown_totals.get(skill_id, 0.0)
	if total <= 0.0:
		return 0.0
	return clampf(_cooldowns.get(skill_id, 0.0) / total, 0.0, 1.0)

## Skill ở NÚT CHÍNH (cũng là skill Auto tự đánh): skill người chơi đã gắn (PlayerProfile.
## main_skill_id) nếu còn hợp lệ và dùng được, không thì đòn chính mặc định của phái.
func get_main_skill() -> SkillDefinition:
	if sect == null:
		return null
	if GameManager.local_profile:
		var custom := _find_skill(GameManager.local_profile.main_skill_id)
		if custom and is_skill_usable(custom):
			return custom
	return get_default_main_skill()

func get_default_main_skill() -> SkillDefinition:
	if sect == null:
		return null
	for skill in sect.skills:
		if skill.is_main_attack:
			return skill
	return null

## Đòn chính mặc định luôn dùng được (không cần học); skill khác phải học >= 1 cấp.
func is_skill_usable(skill: SkillDefinition) -> bool:
	return skill.is_main_attack or DEBUG_UNLOCK_ALL_SKILLS or GameManager.local_profile.get_skill_level(skill.id) > 0

## Luôn đủ PlayerProfile.HOTBAR_SLOT_COUNT phần tử theo đúng thứ tự ô người chơi đã gắn trong bảng
## Kỹ Năng Võ Công — phần tử null = ô trống (chưa gắn, hoặc skill đã gắn không còn hợp lệ). Chỉ số
## 0-3 dùng chung cho phím skill_1-4 và nút bấm trên SkillBarUI.
func get_sub_skills() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	result.resize(PlayerProfile.HOTBAR_SLOT_COUNT)
	if sect == null or GameManager.local_profile == null:
		return result
	var ids := GameManager.local_profile.hotbar_skill_ids
	for i in PlayerProfile.HOTBAR_SLOT_COUNT:
		result[i] = _find_skill(ids[i])
	return result

func _find_skill(skill_id: String) -> SkillDefinition:
	if skill_id == "":
		return null
	for skill in sect.skills:
		if skill.id == skill_id and skill.can_assign_to_hotbar():
			return skill
	return null

func try_cast_main(caster: Node2D, target: Node2D) -> bool:
	return _try_cast(get_main_skill(), caster, target)

func try_cast_skill(index: int, caster: Node2D, target: Node2D) -> bool:
	var subs := get_sub_skills()
	if index < 0 or index >= subs.size():
		return false
	var skill := subs[index]
	if skill == null or not is_skill_usable(skill):
		return false
	return _try_cast(skill, caster, target)

## Chế độ Auto: CHỈ tự động đánh skill ở nút chính (get_main_skill) — skill phụ vẫn phải người chơi tự
## bấm thủ công (phím skill_1-4), kể cả khi đang bật Auto. Tránh tự ý dùng hết cooldown skill phụ
## thay người chơi (VD skill phụ có hiệu ứng đặc biệt muốn để dành đúng lúc).
func try_cast_auto(caster: Node2D, target: Node2D) -> bool:
	return try_cast_main(caster, target)

## Buff hỗ trợ (skill trạng thái không nhắm địch, VD Thanh Phong phù) — tâm là người thi triển, không
## cần mục tiêu.
static func is_self_buff(skill: SkillDefinition) -> bool:
	return skill != null and skill.is_state_skill() and not skill.target_enemy

## Bùa xuất hiện NGAY tại mục tiêu / tại người thi triển (MisslesForm 6/7) — không bay, áp cả vùng luôn.
static func is_instant_curse(skill: SkillDefinition) -> bool:
	return skill != null and skill.is_state_skill() and skill.target_enemy \
			and skill.vltk_missle_form in [SkillDefinition.MF_AT_TARGET, SkillDefinition.MF_AT_FIRER]

static func state_meta(skill: SkillDefinition) -> Dictionary:
	return {"icon": skill.icon, "name": skill.skill_name, "is_debuff": skill.target_enemy}

func _try_cast(skill: SkillDefinition, caster: Node2D, target: Node2D) -> bool:
	if skill == null:
		return false
	var self_buff := is_self_buff(skill)
	if target == null and not self_buff and not skill.is_aura:
		return false
	if _cooldowns.get(skill.id, 0.0) > 0.0:
		return false
	## Đang choáng không ra chiêu được (mọi đường: phím, Auto, nút thanh skill).
	var status: StatusEffectController = caster.get_node_or_null("StatusEffectController")
	if status and status.is_stunned:
		return false
	## Hào quang: bấm để BẬT/TẮT (chỉ 1 hào quang cùng lúc), không bắn gì — chỉ số dựng lại ngay.
	if skill.is_aura:
		_toggle_aura(skill, caster)
		_cooldowns[skill.id] = AURA_TOGGLE_DELAY
		_cooldown_totals[skill.id] = AURA_TOGGLE_DELAY
		skill_cast.emit(skill.id)
		return true
	var stats := _resolve_stats(skill, caster)
	var cooldown := DEBUG_COOLDOWN if DEBUG_NO_COOLDOWN else stats.cooldown
	_cooldowns[skill.id] = cooldown
	_cooldown_totals[skill.id] = cooldown
	if self_buff:
		_play_vltk_precast(skill, caster)
		_cast_support_buff(skill, caster)
	elif is_instant_curse(skill):
		_play_vltk_precast(skill, caster)
		_cast_instant_curse(skill, caster, target)
	elif USE_VLTK_SKILL_FX and VltkSkillRunner.supports(skill, _learned_level(skill)):
		VltkSkillRunner.execute(caster, target, stats, skill, _learned_level(skill))
	else:
		SectSkillCast.execute(caster, target, stats, skill)
	skill_cast.emit(skill.id)
	return true

## Buff hỗ trợ: luôn áp lên người thi triển; skill có TargetAlly + vùng ảnh hưởng (VD Thanh Phong phù
## 3×3 ô) thì đồng đội trong vùng quanh người thi triển cũng được hưởng (CombatTargeting quyết định ai là
## đồng đội — hiện chưa có tổ đội nên chỉ có chính mình).
## Chống bấm bật/tắt hào quang liên tục.
const AURA_TOGGLE_DELAY := 0.5

func _toggle_aura(skill: SkillDefinition, caster: Node2D) -> void:
	var profile := GameManager.local_profile
	profile.active_aura_id = "" if profile.active_aura_id == skill.id else skill.id
	SaveManager.save_profile(profile)
	if caster.has_method("refresh_combat_stats"):
		caster.refresh_combat_stats()

func is_aura_active(skill: SkillDefinition) -> bool:
	return skill != null and skill.is_aura and GameManager.local_profile != null \
			and GameManager.local_profile.active_aura_id == skill.id

func _cast_support_buff(skill: SkillDefinition, caster: Node2D) -> void:
	var payload := skill.get_state_payload(_learned_level(skill))
	var targets: Array[Node2D] = [caster]
	var radius := skill.get_effect_radius_px()
	if skill.target_ally and radius > 0.0:
		targets = CombatTargeting.find_in_radius(caster, caster.global_position, radius, false, true)
		if not targets.has(caster):
			targets.append(caster)
	CombatTargeting.apply_state_to(targets, skill.id, payload, state_meta(skill))

## Bùa tại mục tiêu (MisslesForm 6) / tại người thi triển (7): áp NGAY cho mọi kẻ địch trong vùng quanh
## tâm (0 bán kính = chỉ mục tiêu đã chọn).
func _cast_instant_curse(skill: SkillDefinition, caster: Node2D, target: Node2D) -> void:
	var payload := skill.get_state_payload(_learned_level(skill))
	var center := target.global_position if skill.vltk_missle_form == SkillDefinition.MF_AT_TARGET else caster.global_position
	var radius := skill.get_effect_radius_px()
	## Mục tiêu ảo (điểm phía trước mặt) không phải nhân vật -> không áp trạng thái lên nó.
	var targets: Array[Node2D] = []
	if not target.has_meta("cast_point"):
		targets.append(target)
	if radius > 0.0:
		targets = CombatTargeting.find_in_radius(caster, center, radius, true, false)
	CombatTargeting.apply_state_to(targets, skill.id, payload, state_meta(skill))
	VfxManager.play(skill.vfx_hit_name, center)

## Ảnh xuất chiêu gốc (PreCastSpr) cho skill buff/bùa vẫn đi đường cũ — có dữ liệu skill_fx thì hiện trên người.
func _play_vltk_precast(skill: SkillDefinition, caster: Node2D) -> void:
	if USE_VLTK_SKILL_FX and skill.vltk_skill_id > 0:
		VltkSkillRunner.play_precast(caster, VltkSkillData.skill(skill.vltk_skill_id, _learned_level(skill)))

func _learned_level(skill: SkillDefinition) -> int:
	return maxi(1, GameManager.local_profile.get_skill_level(skill.id))

## Hiệu ứng trúng đòn — NGUYÊN VĂN KNpc::AppendSkillEffect gốc (giá trị skill đọc từ vltk_attribs):
##   Làm chậm  = colddamage_v[2] + m_CurrentColdEnhance (khi skill có Băng sát); có thêm "Băng sát" của
##               nhân vật (ngoại công: mọi skill ngoại công; nội công: skill có Băng sát) thì lấy
##               max(…, COLD_DAMAGE_TIME + ColdEnhance).
##   Trúng độc = poisondamage_v {damage, thời gian, nhịp}; nhịp × (100% - m_CurrentPoisonEnhance), ≥ 1;
##               rồi GỘP với "Độc sát" của nhân vật {damage, POISON_DAMAGE_TIME, POISON_DAMAGE_INTERVAL}
##               bằng MixPoisonDamage (ngoại công: mọi skill ngoại công; nội công: skill có Độc sát).
##   Choáng    = stun_p {% tỷ lệ, frame}.
func _resolve_hit_effects(stats: ResolvedSkillStats, skill: SkillDefinition, level: int,
		elements: Dictionary, is_physical: bool, attacker: CombatantStats) -> void:
	var cold_type := CombatFormulas.DamageType.COLD
	var poison_type := CombatFormulas.DamageType.POISON
	var freeze := 0
	if skill.has_attrib("colddamage_v"):
		freeze = skill.get_attrib("colddamage_v", level).y + attacker.cold_enhance_frames
		if not is_physical and attacker.inner_element_damage.has(cold_type):
			freeze = maxi(freeze, MagicAttribTable.COLD_DAMAGE_TIME + attacker.cold_enhance_frames)
	if is_physical and attacker.outer_element_damage.has(cold_type):
		freeze = maxi(freeze, MagicAttribTable.COLD_DAMAGE_TIME + attacker.cold_enhance_frames)
	stats.freeze_frames = freeze

	## Độc dạng {damage, thời gian, nhịp} như KMagicAttrib gốc — damage của skill đã nhân % hỗ trợ.
	var poison := Vector3i.ZERO
	if skill.has_attrib("poisondamage_v"):
		var raw := skill.get_attrib("poisondamage_v", level)
		var skill_poison: Vector2i = elements.get(poison_type, Vector2i(raw.x, raw.x))
		poison = Vector3i(skill_poison.x, raw.y, maxi(1, raw.z * (100 - attacker.poison_enhance_p) / 100))
		if not is_physical and attacker.inner_element_damage.has(poison_type):
			poison = _mix_poison(poison, _bonus_poison(attacker.inner_element_damage[poison_type]))
	if is_physical and attacker.outer_element_damage.has(poison_type):
		poison = _mix_poison(poison, _bonus_poison(attacker.outer_element_damage[poison_type]))
	if poison.x > 0 and poison.z > 0:
		## Sau khi gộp, lượng Độc sát của đòn = damage đã gộp (AppendSkillEffect ghi đè nValue[0]).
		elements[poison_type] = Vector2i(poison.x, poison.x)
		stats.poison_time_frames = poison.y
		stats.poison_interval_frames = poison.z

	var stun := skill.get_attrib("stun_p", level)
	stats.stun_chance_p = stun.x
	stats.stun_frames = stun.y

## "Độc sát" của nhân vật — AddPoisonDamageV/AddPoisonMagicV gốc: thời gian và nhịp là hằng số.
static func _bonus_poison(damage: Vector2i) -> Vector3i:
	return Vector3i(damage.x, MagicAttribTable.POISON_DAMAGE_TIME, MagicAttribTable.POISON_DAMAGE_INTERVAL)

## KNpcAttribModify::MixPoisonDamage gốc — gộp 2 nguồn độc {d, t, c}.
static func _mix_poison(dest: Vector3i, src: Vector3i) -> Vector3i:
	if dest.z == 0 or dest.x == 0:
		return src
	if src.z == 0 or src.x == 0:
		return dest
	var d1 := dest.x
	var t1 := dest.y
	var c1 := dest.z
	var d2 := src.x
	var t2 := src.y
	var c2 := src.z
	return Vector3i(((c1 + c2) * d1 / c1 + (c1 + c2) * d2 / c2) / 2,
			(t1 * d1 * c2 + t2 * d2 * c1) / (d1 * c2 + d2 * c1),
			(c1 + c2) / 2)

func _resolve_stats(skill: SkillDefinition, caster: Node2D) -> ResolvedSkillStats:
	var stats := ResolvedSkillStats.new()
	var profile := GameManager.local_profile
	var learned_level: int = maxi(1, profile.get_skill_level(skill.id))
	var real := skill.get_combat_damage_at_level(learned_level)
	var enhance_percent: float = real["physics_enhance"]
	var physics_flat: Vector2i = real["physics_flat"]
	var skill_elements: Dictionary = real["elements"]
	var add_damage_p := skill.get_support_percent_from_other_skills(sect.skills, profile)
	var is_physical := skill.is_physical()

	var combat_stats: CombatantStats = caster.combat_stats if "combat_stats" in caster else CombatantStats.new()
	## Damage tay không/vũ khí (m_PhysicsDamage gốc) — trung bình min/max vì `damage` của đòn là 1 số.
	var base_unarmed_damage := (combat_stats.unarmed_min_damage + combat_stats.unarmed_max_damage) / 2

	var physics_damage: float
	var has_real_damage := enhance_percent >= 0.0 or physics_flat != Vector2i.ZERO or not skill_elements.is_empty()
	if enhance_percent >= 0.0:
		var effective_p := enhance_percent + enhance_percent * add_damage_p / 100.0
		physics_damage = (base_unarmed_damage + combat_stats.add_physics_damage) * (100.0 + effective_p) / 100.0 				+ base_unarmed_damage * combat_stats.outer_physics_enhance_p / 100.0
	elif has_real_damage:
		physics_damage = (physics_flat.x + physics_flat.y) * 0.5 * (100.0 + add_damage_p) / 100.0
		if not is_physical and physics_flat != Vector2i.ZERO:
			physics_damage += combat_stats.add_physics_magic
	else:
		## Skill KHÔNG có dòng damage nào trong stat_lines (buff/bùa chú chưa có hệ hiệu ứng riêng) —
		## giữ số mô phỏng cũ để còn tác dụng khi thi triển.
		var fallback_enhance := skill.base_damage + skill.damage_growth_per_level * (learned_level - 1)
		physics_damage = base_unarmed_damage * (100.0 + fallback_enhance) / 100.0
	stats.damage = physics_damage * PlayerStats.damage_multiplier

	var elements := {}
	for damage_type in skill_elements:
		var v: Vector2i = skill_elements[damage_type]
		var lo := v.x + v.x * int(add_damage_p) / 100
		if damage_type == CombatFormulas.DamageType.LIGHT:
			## Lôi: m_CurrentLightEnhance kéo damage tối thiểu lên gần tối đa (AppendSkillEffect gốc).
			lo = v.x + (v.y - v.x) * combat_stats.lighting_enhance_p / 100
		elements[damage_type] = Vector2i(lo, v.y + v.y * int(add_damage_p) / 100)
		## Độc sát của nhân vật KHÔNG cộng thẳng — gốc gộp bằng MixPoisonDamage (_resolve_hit_effects).
		if not is_physical and damage_type != CombatFormulas.DamageType.POISON:
			elements[damage_type] += combat_stats.inner_element_damage.get(damage_type, Vector2i.ZERO)
	if is_physical:
		for damage_type in combat_stats.outer_element_damage:
			if damage_type != CombatFormulas.DamageType.POISON:
				elements[damage_type] = elements.get(damage_type, Vector2i.ZERO) + combat_stats.outer_element_damage[damage_type]
	_resolve_hit_effects(stats, skill, learned_level, elements, is_physical, combat_stats)
	stats.extra_damage_ranges = elements
	stats.main_damage_type = CombatFormulas.DamageType.PHYSICS
	var deadly_strike: int = real["deadly_strike"] + (combat_stats.deadly_strike_enhance_p if is_physical else 0)
	stats.crit_chance = clampf(deadly_strike / 100.0, 0.0, 1.0)
	stats.five_elements_damage_p = real["five_elements_damage_p"]
	## Bùa (nhắm địch, chỉ trạng thái — VD Mê Tung ảo ảnh): đạn không gây damage, trúng thì áp trạng thái.
	if skill.is_state_skill() and skill.target_enemy:
		var payload := skill.get_state_payload(learned_level)
		stats.is_state_only = true
		stats.state_source_id = skill.id
		stats.state_attribs = payload["attribs"]
		stats.state_seconds = payload["seconds"]
		stats.state_meta = state_meta(skill)
		stats.state_radius = skill.get_effect_radius_px()
		stats.damage = 0.0
		stats.extra_damage_ranges = {}
	stats.element = skill.element	
	stats.cooldown = skill.cooldown / PlayerStats.attack_speed_multiplier
	stats.projectile_speed = 350.0
	stats.vfx_hit_name = skill.vfx_hit_name
	stats.color = skill.color
	return stats

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
## Hồ sơ nhân vật của người thi triển — null = nhân vật của mình (GameManager.local_profile). Bot PK (PkBot) gán hồ sơ riêng
## để dùng chung bộ điều khiển skill: cấp skill, đòn chính, hào quang đọc từ hồ sơ này.
var owner_profile: PlayerProfile = null

func _profile() -> PlayerProfile:
	return owner_profile if owner_profile != null else GameManager.local_profile
var _cooldowns: Dictionary = {}  ## skill_id (String) -> giây còn lại
var _cooldown_totals: Dictionary = {}  ## skill_id (String) -> cooldown gốc (để tính % cho UI)
var _auto_attack_cooldowns: Dictionary = {}  ## skill_id (String) -> giãn cách kích hoạt tự động

func setup(sect_def: SectDefinition) -> void:
	sect = sect_def
	_cooldowns.clear()
	_cooldown_totals.clear()
	_auto_attack_cooldowns.clear()

func tick(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] = maxf(0.0, _cooldowns[id] - delta)
	for id in _auto_attack_cooldowns.keys():
		_auto_attack_cooldowns[id] = maxf(0.0, _auto_attack_cooldowns[id] - delta)

## 0.0 = sẵn sàng dùng, 1.0 = vừa thi triển — UI dùng để vẽ radial fill hồi chiêu.
func get_cooldown_ratio(skill_id: String) -> float:
	var total: float = _cooldown_totals.get(skill_id, 0.0)
	if total <= 0.0:
		return 0.0
	return clampf(_cooldowns.get(skill_id, 0.0) / total, 0.0, 1.0)

## Skill ở NÚT CHÍNH (cũng là skill Auto tự đánh): skill người chơi đã gắn (PlayerProfile.
## main_skill_id) nếu còn hợp lệ và dùng được, không thì ĐÁNH THƯỜNG hợp vũ khí đang cầm.
func get_main_skill() -> SkillDefinition:
	if sect != null and _profile():
		var custom := _find_skill(_profile().main_skill_id)
		if custom and is_skill_usable(custom) and not custom.is_basic_attack:
			return custom
	return get_default_main_skill()

## Nút chính trống: đánh thường — tay không / vũ khí cận chiến = bàn tay, phi tiêu / phi đao / tụ tiễn = phi đao.
## Vô Môn Phái (sect == null) cũng đánh thường được.
func get_default_main_skill() -> SkillDefinition:
	var profile := _profile()
	return SectRegistry.basic_attack_for(profile.equipment if profile else {})

## Đòn chính mặc định luôn dùng được (không cần học); skill khác phải học >= 1 cấp.
func is_skill_usable(skill: SkillDefinition) -> bool:
	return skill.is_main_attack or skill.is_basic_attack or DEBUG_UNLOCK_ALL_SKILLS or _profile().get_skill_level(skill.id) > 0

## Luôn đủ PlayerProfile.HOTBAR_SLOT_COUNT phần tử theo đúng thứ tự ô người chơi đã gắn trong bảng
## Kỹ Năng Võ Công — phần tử null = ô trống (chưa gắn, hoặc skill đã gắn không còn hợp lệ). Chỉ số
## 0-3 dùng chung cho phím skill_1-4 và nút bấm trên SkillBarUI.
## Skill đang gắn ở ô thi triển liên tục `index` (null = ô trống / chưa đủ điều kiện dùng).
func get_loop_skill(index: int) -> SkillDefinition:
	var profile := _profile()
	if sect == null or profile == null or index < 0 or index >= profile.loop_skill_ids.size():
		return null
	var skill := _find_skill(profile.loop_skill_ids[index])
	return skill if skill != null and is_skill_usable(skill) else null

## Ô liên tục đang bật (bấm vào ô để tạm dừng/tiếp tục — chỉ lưu trong phiên chơi).
var loop_enabled: Array[bool] = [true]

func get_sub_skills() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	result.resize(PlayerProfile.HOTBAR_SLOT_COUNT)
	if sect == null or _profile() == null:
		return result
	var ids := _profile().hotbar_skill_ids
	for i in PlayerProfile.HOTBAR_SLOT_COUNT:
		result[i] = _find_skill(ids[i])
	return result

func _find_skill(skill_id: String) -> SkillDefinition:
	if skill_id == "" or sect == null:
		return null
	for skill in sect.skills:
		if skill.id == skill_id and skill.can_assign_to_hotbar():
			return skill
	return null

## Skill của phái theo id (null nếu không có / không đặt lên thanh skill được).
func get_skill(skill_id: String) -> SkillDefinition:
	return _find_skill(skill_id)

func try_cast_main(caster: Node2D, target: Variant = null) -> bool:
	return _try_cast(get_main_skill(), caster, target)

func try_cast_skill(index: int, caster: Node2D, target: Variant = null) -> bool:
	var subs := get_sub_skills()
	if index < 0 or index >= subs.size():
		return false
	var skill := subs[index]
	if skill == null or not is_skill_usable(skill):
		return false
	return _try_cast(skill, caster, target)

## Ra chiêu skill ở ô thi triển liên tục (cùng điều kiện như bấm tay: hồi chiêu, vũ khí/ngựa, choáng...).
func try_cast_loop(skill: SkillDefinition, caster: Node2D, target: Variant = null) -> bool:
	return _try_cast(skill, caster, target)

## Buff hỗ trợ (skill chủ động không nhắm địch, VD Thanh Phong phù, Skill 180...) — tâm là người thi triển, không
## cần mục tiêu.
static func is_self_buff(skill: SkillDefinition) -> bool:
	return skill != null and not skill.target_enemy and not skill.is_aura

## Bùa xuất hiện NGAY tại mục tiêu / tại người thi triển (MisslesForm 6/7) — không bay, áp cả vùng luôn.
static func is_instant_curse(skill: SkillDefinition) -> bool:
	return skill != null and skill.is_state_skill() and skill.target_enemy \
			and skill.vltk_missle_form in [SkillDefinition.MF_AT_TARGET, SkillDefinition.MF_AT_FIRER]

static func state_meta(skill: SkillDefinition) -> Dictionary:
	return {"icon": skill.icon, "name": skill.skill_name, "is_debuff": skill.target_enemy,
			"state_id": skill.vltk_state_special_id}

## Lý do skill không thi triển được vì vũ khí đang cầm / ngựa ("" = được). Người thi triển không phải player thì bỏ qua.
func get_cast_block_reason(skill: SkillDefinition, caster: Node2D) -> String:
	var profile := _profile()
	if profile == null or not caster.has_method("is_riding"):
		return ""
	return skill.get_cast_block_reason(Equipment.get_weapon_class(profile.equipment), caster.is_riding())

func _try_cast(skill: SkillDefinition, caster: Node2D, target: Variant = null) -> bool:
	if skill == null:
		return false
	if target != null and (not is_instance_valid(target) or not (target is Node2D) or (target is Node and (target as Node).is_queued_for_deletion())):
		target = null
	var tgt_node: Node2D = target as Node2D
	var self_buff := is_self_buff(skill)
	## Hào quang LUÔN là bật/tắt (kể cả hào quang gây hại như Vô Hình Độc) — hiệu quả do nhịp hào quang lo, xem tick_aura.
	var toggle_aura := skill.is_aura
	if tgt_node == null and not self_buff and not toggle_aura:
		return false
	if _cooldowns.get(skill.id, 0.0) > 0.0:
		return false
	## Đang choáng không ra chiêu được (mọi đường: phím, Auto, nút thanh skill).
	var status: StatusEffectController = caster.get_node_or_null("StatusEffectController")
	if status and status.is_stunned:
		return false
	## Đang bay (nhảy / rơi sau khi bị đánh) không ra chiêu được — KNpc gốc chỉ cho DoJumpAttack riêng.
	if caster.has_method("can_cast") and not caster.can_cast():
		return false
	## Hạn chế vũ khí / cưỡi ngựa của skill (EqtLimit / HorseLimit gốc).
	var block := get_cast_block_reason(skill, caster)
	if block != "":
		if caster.has_method("notify"):
			caster.notify(block)
		return false
	## Hào quang: bấm để BẬT/TẮT (chỉ 1 hào quang cùng lúc), không bắn gì — chỉ số dựng lại ngay.
	if toggle_aura:
		var turning_on := _profile() == null or _profile().active_aura_id != skill.id
		if turning_on:
			var cost := skill.get_mana_cost_at_level(_learned_level(skill))
			if cost > 0 and not GameManager.is_free_mana_stage(caster):
				if "mana" in caster:
					if caster.mana < cost:
						if caster.has_method("notify"):
							caster.notify("Không đủ nội lực!")
						return false
					caster.mana -= cost
		_toggle_aura(skill, caster)
		if is_aura_active(skill) and USE_VLTK_SKILL_FX:
			VltkSkillRunner.play_support(caster, null, skill, _learned_level(skill))
			_net_cast(skill, caster, null, true)
		_cooldowns[skill.id] = AURA_TOGGLE_DELAY
		_cooldown_totals[skill.id] = AURA_TOGGLE_DELAY
		skill_cast.emit(skill.id)
		return true

	## Tiêu hao nội lực (chỉ ải Luyện và Tinh anh mới miễn phí nội lực; các ải khác và PK đều tiêu hao).
	var mana_cost := skill.get_mana_cost_at_level(_learned_level(skill))
	if mana_cost > 0 and not GameManager.is_free_mana_stage(caster):
		if "mana" in caster:
			if caster.mana < mana_cost:
				if caster.has_method("notify"):
					caster.notify("Không đủ nội lực!")
				return false
			caster.mana -= mana_cost

	var stats := _resolve_stats(skill, caster)
	var cooldown := DEBUG_COOLDOWN if DEBUG_NO_COOLDOWN else stats.cooldown
	_cooldowns[skill.id] = cooldown
	_cooldown_totals[skill.id] = cooldown
	if self_buff:
		_play_vltk_precast(skill, caster)
		_cast_support_buff(skill, caster)
		_net_cast(skill, caster, null, true)
	elif is_instant_curse(skill):
		_play_vltk_precast(skill, caster, tgt_node)
		_cast_instant_curse(skill, caster, tgt_node)
		_net_cast(skill, caster, tgt_node, true)
	elif USE_VLTK_SKILL_FX and VltkSkillRunner.supports(skill, _learned_level(skill)):
		VltkSkillRunner.execute(caster, tgt_node, stats, skill, _learned_level(skill))
		_net_cast(skill, caster, tgt_node, false)
	else:
		SectSkillCast.execute(caster, tgt_node, stats, skill)
	## Đánh trúng quái/người nào thì vòng đỏ hiện dưới chân đó (như khi bấm chọn).
	if caster.has_method("mark_cast_target"):
		caster.mark_cast_target(tgt_node)
	skill_cast.emit(skill.id)
	return true

## Online: báo server để máy người xung quanh VẼ lại chiêu này (chỉ nhân vật của mình, không phải quái / bot dùng chung bộ điều khiển).
func _net_cast(skill: SkillDefinition, caster: Node2D, target: Variant, support: bool) -> void:
	if skill.vltk_skill_id <= 0 or not caster.is_in_group("player") or not NetClient.is_in_world():
		return
	if target != null and (not is_instance_valid(target) or not (target is Node2D)):
		target = null
	var tgt_node := target as Node2D
	var aim_node: Node2D = tgt_node if tgt_node != null else caster
	var target_eid := 0
	if tgt_node != null and not tgt_node.has_meta("cast_point"):
		if tgt_node is RemotePlayer:
			target_eid = (tgt_node as RemotePlayer).eid
		elif "net_eid" in tgt_node:
			target_eid = int(tgt_node.net_eid)
	NetClient.send_cast(skill.vltk_skill_id, _learned_level(skill), NetProto.CAST_SUPPORT if support else 0,
		target_eid, VltkMath.ground_of(aim_node))

## Buff hỗ trợ: luôn áp lên người thi triển; skill có TargetAlly + vùng ảnh hưởng (VD Thanh Phong phù
## 3×3 ô) thì đồng đội trong vùng quanh người thi triển cũng được hưởng (CombatTargeting quyết định ai là
## đồng đội — hiện chưa có tổ đội nên chỉ có chính mình).
## Chống bấm bật/tắt hào quang liên tục.
const AURA_TOGGLE_DELAY := 0.5

func _toggle_aura(skill: SkillDefinition, caster: Node2D) -> void:
	var profile := _profile()
	profile.active_aura_id = "" if profile.active_aura_id == skill.id else skill.id
	SaveManager.save_profile(profile)
	if caster.has_method("refresh_combat_stats"):
		caster.refresh_combat_stats()

## NHỊP HÀO QUANG (KNpc::ProcessState gốc, dòng `if (m_ActiveAuraID)`): khi có hào quang đang bật, cứ mỗi GAME_UPDATE_TIME = 10 frame
## game thi triển skill CON của hào quang (ChildSkillId) ngay tại chỗ người chơi, ở cấp của hào quang — VD Vô Hình Độc -> đạn
## "vòng tròn gây sát thương" bán kính DmgRange quanh người, mỗi quái trong vòng dính độc. Hào quang không nhắm địch (Mộng Điệp,
## Phổ Độ Chúng Sinh...) thi triển cùng nhịp nhưng chỉ để vẽ (chỉ số của chúng đã tính khi bật, qua CombatantBuild).
const AURA_TICK := 10.0 / 18.0
const AURA_CASTS_PER_TICK := 1   ## 1 lần mỗi 10 frame theo đúng KNpc.cpp:871 gốc
var _aura_time: float = 0.0

func tick_aura(caster: Node2D, delta: float) -> void:
	var profile := _profile()
	if profile == null or profile.active_aura_id == "" or not USE_VLTK_SKILL_FX:
		_aura_time = 0.0
		return
	_aura_time += delta
	if _aura_time < AURA_TICK:
		return
	_aura_time = fmod(_aura_time, AURA_TICK)
	var skill := _find_skill(profile.active_aura_id)
	if skill == null or skill.vltk_skill_id <= 0:
		return
	var level := _learned_level(skill)
	var data := VltkSkillData.skill(skill.vltk_skill_id, level)
	var child := int(data.get("child", 0))
	if child <= 0 or not VltkSkillData.has_skill(child):
		return
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	if skill.target_enemy:
		ctx.stats = _resolve_stats(skill, caster)
		ctx.attacker_stats = caster.combat_stats if "combat_stats" in caster else null
	## Server THẬT (Coreserver.dll, KNpc::ProcessState @1000d070): mỗi 10 nhịp skill con của hào quang được thi triển HAI LẦN
	## (khối gửi đồng bộ cho client cũng gọi Cast, rồi khối thi triển chính gọi Cast lần nữa) — mã nguồn C++ chỉ có 1 lần.
	## Nên hào quang gây damage gấp đôi tần suất (đo trên server: số mất máu dày hơn rõ rệt).
	for _i in AURA_CASTS_PER_TICK:
		VltkSkillCaster.cast(ctx, child, level, ctx.launcher_logic(), null)

func is_aura_active(skill: SkillDefinition) -> bool:
	return skill != null and skill.is_aura and _profile() != null \
			and _profile().active_aura_id == skill.id

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

## Phần thi triển gốc của skill buff/bùa (vẫn áp hiệu quả bằng đường cũ): ảnh xuất chiêu + động tác + đạn/skill con
## chỉ để vẽ — xem VltkSkillRunner.play_support. `target` = mục tiêu của bùa (null với buff lên mình).
func _play_vltk_precast(skill: SkillDefinition, caster: Node2D, target: Node2D = null) -> void:
	if USE_VLTK_SKILL_FX and skill.vltk_skill_id > 0:
		VltkSkillRunner.play_support(caster, target, skill, _learned_level(skill))

func _learned_level(skill: SkillDefinition) -> int:
	var prof := _profile()
	var base_lvl := maxi(1, prof.get_skill_level(skill.id) if prof != null else 1)
	if PlayerStats.level > 1:
		base_lvl += int((PlayerStats.level - 1) / 2)
	var caster := get_parent()
	var c_stats: CombatantStats = caster.get("combat_stats") if caster else null
	if c_stats != null:
		base_lvl += c_stats.get_skill_bonus(int(skill.element) if "element" in skill else -1)
	return maxi(1, base_lvl)

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

	## Độc dạng {damage, thời gian, nhịp} như KMagicAttrib gốc (KNpc::AppendSkillEffect):
	##   - nValue[0]: damage mỗi nhịp rút độc
	##   - nValue[1]: thời gian dính độc (frame VLTK, 18/giây)
	##   - nValue[2]: nhịp rút độc (frame VLTK) — giảm theo poison_enhance_p của người đánh
	## Sau đó gộp với độc nội công/ngoại công của nhân vật bằng MixPoisonDamage gốc.
	var poison := Vector3i.ZERO
	if skill.has_attrib("poisondamage_v"):
		var raw := skill.get_attrib("poisondamage_v", level)
		var skill_poison: Vector2i = elements.get(poison_type, Vector2i(raw.x, raw.x))
		var tick_damage: int = skill_poison.x if skill_poison.x > 0 else raw.x
		var duration_frames: int = raw.y if raw.y > 0 else 60
		var interval_base: int = raw.z if raw.z > 0 else 10
		var interval_frames: int = maxi(1, interval_base * (100 - attacker.poison_enhance_p) / 100) if attacker.poison_enhance_p > 0 else interval_base
		poison = Vector3i(tick_damage, duration_frames, interval_frames)
		if not is_physical and attacker.inner_element_damage.has(poison_type):
			poison = _mix_poison(poison, _bonus_poison(attacker.inner_element_damage[poison_type]))
		elif is_physical and attacker.outer_element_damage.has(poison_type):
			poison = _mix_poison(poison, _bonus_poison(attacker.outer_element_damage[poison_type]))
	if poison.x > 0 and poison.z > 0:
		elements[poison_type] = Vector2i(poison.x, poison.x)
		stats.poison_tick_damage = poison.x
		stats.poison_time_frames = poison.y
		stats.poison_interval_frames = poison.z

	var stun := skill.get_attrib("stun_p", level)
	stats.stun_chance_p = stun.x
	stats.stun_frames = stun.y

	# Áp dụng hiệu ứng khống chế từ nâng cấp Level Up
	if PlayerStats.freeze_frames > 0:
		stats.freeze_frames = maxi(stats.freeze_frames, PlayerStats.freeze_frames)
	if PlayerStats.stun_chance_p > 0:
		stats.stun_chance_p = maxi(stats.stun_chance_p, PlayerStats.stun_chance_p)
		stats.stun_frames = maxi(stats.stun_frames, PlayerStats.stun_frames)
	if PlayerStats.poison_damage > 0:
		elements[poison_type] = elements.get(poison_type, Vector2i.ZERO) + Vector2i(PlayerStats.poison_damage, PlayerStats.poison_damage)
		stats.poison_tick_damage = maxi(stats.poison_tick_damage, PlayerStats.poison_damage)
		stats.poison_time_frames = maxi(stats.poison_time_frames, PlayerStats.poison_time_frames)
		stats.poison_interval_frames = mini(stats.poison_interval_frames if stats.poison_interval_frames > 0 else 18, 18)

## "Độc sát" của nhân vật — AddPoisonDamageV/AddPoisonMagicV gốc: thời gian và nhịp là hằng số.
static func _bonus_poison(damage: Vector2i) -> Vector3i:
	return Vector3i(damage.x, MagicAttribTable.POISON_DAMAGE_TIME, MagicAttribTable.POISON_DAMAGE_INTERVAL)

## KNpcAttribModify::MixPoisonDamage gốc — gộp 2 nguồn độc {d, t, c}.
## Chia nguyên CỐ Ý — đúng số học số nguyên của MixPoisonDamage gốc.
@warning_ignore("integer_division")
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

## Tính lực tay trái (damage của skill chính) và cờ use_ar cho nhân vật / profile.
## Nhận player_node nếu có, nếu null thì tự suy từ profile.
static func get_left_hand_info(profile: PlayerProfile, player_node: Node2D = null) -> Dictionary:
	var s: CombatantStats = (player_node.combat_stats if (player_node and "combat_stats" in player_node and player_node.combat_stats != null) else (profile.get_combat_stats() if profile else CombatantStats.new()))
	var left_damage := Vector2i(s.unarmed_min_damage, s.unarmed_max_damage)
	var left_uses_ar := true
	if profile == null and player_node == null:
		return {"damage": left_damage, "use_ar": left_uses_ar}

	var ctrl: SectSkillController = null
	var should_free := false
	if player_node != null and "skill_controller" in player_node and player_node.skill_controller != null:
		ctrl = player_node.skill_controller
	elif profile != null:
		ctrl = SectSkillController.new()
		ctrl.owner_profile = profile
		if not profile.sect_id.is_empty():
			ctrl.setup(SectRegistry.get_by_id(profile.sect_id))
		should_free = true

	if ctrl != null:
		var main_skill: SkillDefinition = ctrl.get_main_skill()
		if main_skill != null and not main_skill.is_basic_attack:
			left_damage = ctrl.get_echo_damage(main_skill, player_node)
			if main_skill.vltk_skill_id > 0:
				left_uses_ar = int(VltkSkillData.skill(main_skill.vltk_skill_id, 1).get("use_ar", 1)) != 0
		if should_free:
			ctrl.free()

	return {"damage": left_damage, "use_ar": left_uses_ar}

## "Lực tay trái/phải" của bảng nhân vật (KPlayer::GetEchoDamage gốc): khoảng damage của skill = vật lý (nhân % skill) + Băng/Hỏa/Lôi
## + ĐỘC TÍNH CẢ ĐỢT (damage × thời gian / nhịp) — không phải cú đánh đầu. Trả về Vector2i(min, max).
func get_echo_damage(skill: SkillDefinition, caster: Node2D = null) -> Vector2i:
	if skill == null:
		return Vector2i.ZERO
	var stats := _resolve_stats(skill, caster)
	var lo := stats.damage_min if stats.damage_min >= 0.0 else stats.damage
	var hi := stats.damage_max if stats.damage_max >= 0.0 else stats.damage
	var poison_type := CombatFormulas.DamageType.POISON
	for damage_type in stats.extra_damage_ranges:
		if damage_type == poison_type:
			continue
		var r: Vector2i = stats.extra_damage_ranges[damage_type]
		lo += r.x
		hi += r.y
	if stats.poison_tick_damage > 0 and stats.poison_interval_frames > 0:
		var total := stats.poison_tick_damage * stats.poison_time_frames / stats.poison_interval_frames
		lo += total
		hi += total
	return Vector2i(int(lo), int(hi))

func _resolve_stats(skill: SkillDefinition, caster: Node2D = null) -> ResolvedSkillStats:
	var stats := ResolvedSkillStats.new()
	var profile := _profile()
	var learned_level: int = _learned_level(skill)
	var real := skill.get_combat_damage_at_level(learned_level)
	var enhance_percent: float = real["physics_enhance"]
	var physics_flat: Vector2i = real["physics_flat"]
	var skill_elements: Dictionary = real["elements"]
	var sect_skills: Array[SkillDefinition] = []
	if sect:
		sect_skills = sect.skills
	elif profile and profile.sect_id != "":
		sect = SectRegistry.get_by_id(profile.sect_id)
		if sect:
			sect_skills = sect.skills
	var add_damage_p := skill.get_support_percent_from_other_skills(sect_skills, profile)
	var is_physical := skill.is_physical()

	var combat_stats: CombatantStats
	if caster != null and "combat_stats" in caster and caster.combat_stats != null:
		combat_stats = caster.combat_stats
	elif profile != null:
		combat_stats = profile.get_combat_stats()
	else:
		combat_stats = CombatantStats.new()
	## Damage tay không/vũ khí (m_PhysicsDamage gốc) — trung bình min/max vì `damage` của đòn là 1 số.
	var base_unarmed_damage := (combat_stats.unarmed_min_damage + combat_stats.unarmed_max_damage) / 2

	var physics_damage: float
	var has_real_damage := enhance_percent >= 0.0 or physics_flat != Vector2i.ZERO or not skill_elements.is_empty()
	if enhance_percent >= 0.0:
		var effective_p := enhance_percent + enhance_percent * add_damage_p / 100.0
		physics_damage = (base_unarmed_damage + combat_stats.add_physics_damage) * (100.0 + effective_p) / 100.0 \
				+ base_unarmed_damage * combat_stats.outer_physics_enhance_p / 100.0
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
	if enhance_percent >= 0.0:
		## AppendSkillEffect gốc: min và max nhân riêng (nMinDamage/nMaxDamage) rồi mỗi đòn roll trong khoảng.
		var effective := enhance_percent + enhance_percent * add_damage_p / 100.0
		var outer := combat_stats.outer_physics_enhance_p / 100.0
		stats.damage_min = ((combat_stats.unarmed_min_damage + combat_stats.add_physics_damage) * (100.0 + effective) / 100.0 \
				+ combat_stats.unarmed_min_damage * outer) * PlayerStats.damage_multiplier
		stats.damage_max = ((combat_stats.unarmed_max_damage + combat_stats.add_physics_damage) * (100.0 + effective) / 100.0 \
				+ combat_stats.unarmed_max_damage * outer) * PlayerStats.damage_multiplier
	elif physics_damage > 0.0:
		stats.damage_min = maxf(1.0, physics_damage * 0.85)
		stats.damage_max = maxf(stats.damage_min, physics_damage * 1.15)

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
	if PlayerStats.damage_multiplier != 1.0:
		for dt in elements.keys():
			var ev: Vector2i = elements[dt]
			elements[dt] = Vector2i(
				int(ev.x * PlayerStats.damage_multiplier),
				int(ev.y * PlayerStats.damage_multiplier)
			)
	_resolve_hit_effects(stats, skill, learned_level, elements, is_physical, combat_stats)
	stats.extra_damage_ranges = elements
	stats.main_damage_type = CombatFormulas.DamageType.PHYSICS
	var deadly_strike: int = real["deadly_strike"] + (combat_stats.deadly_strike_enhance_p if is_physical else 0)
	stats.crit_chance = clampf((deadly_strike / 100.0) + PlayerStats.crit_chance, 0.0, 1.0)
	stats.five_elements_damage_p = real["five_elements_damage_p"]
	if skill.has_attrib("ignoredefense_p"):
		stats.ignore_defense_percent = skill.get_attrib("ignoredefense_p", learned_level).x
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
	stats.range_multiplier = PlayerStats.range_multiplier
	stats.projectile_speed = 350.00
	stats.vfx_hit_name = skill.vfx_hit_name
	stats.color = skill.color
	return stats

## Kích hoạt kỹ năng tự động khi tấn công trúng mục tiêu (autoattackskill trong VLTK gốc, VD: Sâm La Độc Hải nổ đầu lâu).
func trigger_auto_attack_skills(caster: Node2D, target: Node2D, source_skill: Dictionary = {}) -> void:
	if caster == null or not is_instance_valid(caster) or not caster.is_inside_tree():
		return
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	if target is Node and (target as Node).is_queued_for_deletion():
		return
	## Tránh kích hoạt lặp vô hạn từ chính chiêu nổ đầu lâu / chiêu auto-attack
	if source_skill.get("is_auto_attack", false):
		return
	var src_child := int(source_skill.get("child", 0))
	var src_id := int(source_skill.get("id", 0))
	if src_child == 357 or src_id in [1232, 100357]:
		return

	## Sâm La Độc Hải (Ngũ Độc): tự động kích hoạt Hồn Ảnh Tùng Sanh (1232 - Missile 357 nổ đầu lâu)
	var sam_la := _find_skill("ngu_doc_sam_la_doc_hai")
	if sam_la != null and is_skill_usable(sam_la):
		var cd: float = _auto_attack_cooldowns.get("ngu_doc_sam_la_doc_hai", 0.0)
		if cd <= 0.0:
			var lvl := _learned_level(sam_la)
			var rate := 0.10 + 0.20 * clampf(float(lvl - 1) / 19.0, 0.0, 1.0)
			if randf() < rate:
				_auto_attack_cooldowns["ngu_doc_sam_la_doc_hai"] = 1.0  ## Giãn cách chuẩn 1 giây
				_cast_auto_attack_missile(caster, target, 1232, lvl, sam_la)

func _cast_auto_attack_missile(caster: Node2D, target: Node2D, child_skill_id: int, level: int, parent_skill: SkillDefinition) -> void:
	if not USE_VLTK_SKILL_FX or not VltkSkillData.has_skill(child_skill_id):
		return
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	ctx.stats = _resolve_stats(parent_skill, caster)
	ctx.attacker_stats = caster.combat_stats if "combat_stats" in caster else null
	if "cast_target_group" in caster:
		ctx.target_group = caster.cast_target_group
	var des := VltkMath.logic_of(target)
	VltkSkillCaster.cast(ctx, child_skill_id, level, des, target)
	if NetClient.is_in_world() and caster.is_in_group("player"):
		var target_eid := int(target.net_eid) if "net_eid" in target else 0
		NetClient.send_cast(child_skill_id, level, 0, target_eid, target.global_position)

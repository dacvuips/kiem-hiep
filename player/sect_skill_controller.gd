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
## Chiêu đánh vừa ra (m_ActiveSkillID gốc) + mốc thời gian (ms) — SkillPractice tính đòn trúng quái cho chiêu này.
var active_skill_id := ""
var active_skill_at := 0

func _profile() -> PlayerProfile:
	return owner_profile if owner_profile != null else GameManager.local_profile
var _cooldowns: Dictionary = {}  ## skill_id (String) -> giây còn lại
var _cooldown_totals: Dictionary = {}  ## skill_id (String) -> cooldown gốc (để tính % cho UI)
var _auto_attack_cooldowns: Dictionary = {}  ## skill_id (String) -> giãn cách kích hoạt tự động khi đánh
var _auto_reply_cooldowns: Dictionary = {}   ## skill_id (String) -> giãn cách kích hoạt tự động khi bị đánh

## ---- Khoá động tác (KNpc::DoAttack/DoMagic gốc) ----
## VLTK gốc KHÔNG có hồi chiêu cho đa số chiêu đánh: nhịp ra đòn = độ dài động tác, đang ra chiêu thì không ra chiêu khác.
## Ngoại công: AttackFrame = 18 (settings/npc/player/BaseValue.ini); nội công: CastFrame = 20 (KNpcSet không đọc CastFrame
## từ ini nên player giữ mặc định 20 của KNpc). Số frame = frame × 100 / (tốc độ + 100), làm tròn xuống số chẵn.
const BASE_ATTACK_FRAME := 18
const BASE_CAST_FRAME := 20
## false = mỗi skill hồi chiêu độc lập, không khoá động tác (chế độ Survivor ra mọi chiêu cùng lúc — có nhịp riêng).
var use_action_lock := true
var _action_lock: float = 0.0  ## giây còn lại của động tác đang diễn (riêng từng người thi triển)

## Độ dài động tác ra chiêu (giây) như KNpc gốc: ngoại công dùng attackspeed_v, nội công dùng castspeed_v.
static func action_seconds(physical: bool, stats: CombatantStats) -> float:
	var speed := 0
	if stats != null:
		speed = stats.attack_speed if physical else stats.cast_speed
	return action_seconds_at_speed(physical, speed)

## Như action_seconds nhưng nhận thẳng tốc độ (attackspeed_v nếu ngoại công, castspeed_v nếu nội công) — server dùng số đã lưu sẵn.
static func action_seconds_at_speed(physical: bool, speed: int) -> float:
	var base := BASE_ATTACK_FRAME if physical else BASE_CAST_FRAME
	var frames := base * 100 / maxi(1, speed + 100)
	frames -= frames % 2
	return SkillDefinition.frames_to_seconds(maxi(1, frames))

## Đang diễn động tác ra chiêu (chưa ra được chiêu đánh khác).
func is_action_locked() -> bool:
	return use_action_lock and _action_lock > 0.0

func setup(sect_def: SectDefinition) -> void:
	sect = sect_def
	_cooldowns.clear()
	_cooldown_totals.clear()
	_auto_attack_cooldowns.clear()
	_auto_reply_cooldowns.clear()
	_action_lock = 0.0

## Xoá mọi hồi chiêu + khoá động tác (đổi map / test).
func clear_cooldowns() -> void:
	_cooldowns.clear()
	_cooldown_totals.clear()
	_auto_attack_cooldowns.clear()
	_auto_reply_cooldowns.clear()
	_action_lock = 0.0

func tick(delta: float) -> void:
	_action_lock = maxf(0.0, _action_lock - delta)
	for id in _cooldowns.keys():
		_cooldowns[id] = maxf(0.0, _cooldowns[id] - delta)
	for id in _auto_attack_cooldowns.keys():
		_auto_attack_cooldowns[id] = maxf(0.0, _auto_attack_cooldowns[id] - delta)
	for id in _auto_reply_cooldowns.keys():
		_auto_reply_cooldowns[id] = maxf(0.0, _auto_reply_cooldowns[id] - delta)

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
	if GameModeManager.is_offline() and (GameManager.game_mode == GameManager.GameMode.STAGE or (GameManager.field_map != null and GameManager.field_map.get("survivor_mode", false) == true)):
		if PlayerStats.get_skill_star(skill.id) > 0:
			return true
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

## Kỹ năng có đang nằm trong ô thi triển liên tục và đang được bật hay không
func is_in_active_loop_slot(skill_id: String) -> bool:
	var profile := _profile()
	if profile == null or skill_id == "":
		return false
	for i in profile.loop_skill_ids.size():
		if profile.loop_skill_ids[i] == skill_id:
			if i < loop_enabled.size() and not loop_enabled[i]:
				return false
			return true
	return false

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

## Tìm kỹ năng bất kỳ trong môn phái theo id (kể cả bị động / không gắn hotbar).
func _find_sect_skill(skill_id: String) -> SkillDefinition:
	if skill_id == "" or sect == null:
		return null
	for skill in sect.skills:
		if skill.id == skill_id:
			return skill
	return null

## Skill của phái theo SkillId gốc VLTK (kể cả skill con ẩn) — null nếu không có.
func find_by_vltk_id(vltk_id: int) -> SkillDefinition:
	if vltk_id <= 0 or sect == null:
		return null
	for skill in sect.skills:
		if skill != null and skill.vltk_skill_id == vltk_id:
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
## cần mục tiêu. Kỹ năng lướt / tốc biến (vltk_missle_form == 13 hoặc cận chiến) không phải buff bản thân.
static func is_self_buff(skill: SkillDefinition) -> bool:
	if skill == null or skill.is_aura or skill.target_enemy:
		return false
	if skill.vltk_missle_form in [8, 11, 12, 13]:
		return false
	return true

## Bùa xuất hiện NGAY tại mục tiêu / tại người thi triển (MisslesForm 6/7) — không bay, áp cả vùng luôn.
static func is_instant_curse(skill: SkillDefinition) -> bool:
	return skill != null and skill.is_state_skill() and skill.target_enemy \
			and skill.vltk_missle_form in [SkillDefinition.MF_AT_TARGET, SkillDefinition.MF_AT_FIRER]

static func state_meta(skill: SkillDefinition) -> Dictionary:
	return {"icon": skill.icon, "name": skill.skill_name, "is_debuff": skill.target_enemy,
			"state_id": skill.vltk_state_special_id}

## Lý do skill không thi triển được vì vũ khí đang cầm / ngựa ("" = được). Người thi triển không phải player thì bỏ qua.
func get_cast_block_reason(skill: SkillDefinition, caster: Node2D) -> String:
	if skill != null and skill.id == "hoa_son_cuu_kiem_hop_nhat":
		return "Kỹ năng cần gắn vào ô thi triển liên tục để phát huy tác dụng!"
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
		if skill.vltk_missle_form == 13 and caster.has_method("_make_cast_point"):
			tgt_node = caster._make_cast_point(skill)
		else:
			return false
	if _cooldowns.get(skill.id, 0.0) > 0.0:
		return false
	## Đang diễn động tác chiêu trước (hoặc đang lao/đánh liên hoàn cận chiến) -> chưa ra chiêu đánh khác. Buff bản thân
	## và bật/tắt hào quang vẫn chạy nền như trước (không chờ, không khoá).
	if use_action_lock and not self_buff and not toggle_aura:
		if _action_lock > 0.0 or VltkSkillRunner.is_melee_busy(caster):
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
				if GmManager and GmManager.is_god_mode:
					pass
				elif "mana" in caster:
					if caster.mana < cost:
						if caster.has_method("notify"):
							caster.notify("Không đủ nội lực!")
						return false
					caster.mana -= cost
			var life_cost_aura := skill.get_life_cost_at_level(_learned_level(skill))
			if life_cost_aura > 0:
				if GmManager and GmManager.is_god_mode:
					pass
				elif "health" in caster:
					if caster.health <= life_cost_aura:
						if caster.has_method("notify"):
							caster.notify("Không đủ sinh lực!")
						return false
					caster.health = maxf(1.0, caster.health - life_cost_aura)
		_toggle_aura(skill, caster)
		if is_aura_active(skill) and USE_VLTK_SKILL_FX:
			VltkSkillRunner.play_support(caster, null, skill, _learned_level(skill))
			_net_cast(skill, caster, null, true)
		_cooldowns[skill.id] = AURA_TOGGLE_DELAY
		_cooldown_totals[skill.id] = AURA_TOGGLE_DELAY
		skill_cast.emit(skill.id)
		return true

	## Tiêu hao sinh lực: Thiên Vương Bang gốc tiêu hao sinh lực khi thi triển kỹ năng.
	var life_cost := skill.get_life_cost_at_level(_learned_level(skill))
	if life_cost > 0:
		if GmManager and GmManager.is_god_mode:
			pass
		elif "health" in caster:
			if caster.health <= life_cost:
				if caster.has_method("notify"):
					caster.notify("Không đủ sinh lực!")
				return false
			caster.health = maxf(1.0, caster.health - life_cost)

	## Tiêu hao nội lực: mọi bản đồ đều tiêu hao nội lực khi thi triển kỹ năng.
	var mana_cost := skill.get_mana_cost_at_level(_learned_level(skill))
	if mana_cost > 0 and not GameManager.is_free_mana_stage(caster):
		if GmManager and GmManager.is_god_mode:
			pass
		elif "mana" in caster:
			if caster.mana < mana_cost:
				if caster.has_method("notify"):
					caster.notify("Không đủ nội lực!")
				return false
			caster.mana -= mana_cost

	## KNpc::DoSkill gốc: thi triển võ công là hiện hình (`m_HideState.nTime = 0`) — trừ chính skill ẩn thân.
	if status and not skill.has_attrib("hide"):
		status.break_hide()

	var stats := _resolve_stats(skill, caster)
	var cooldown := DEBUG_COOLDOWN if DEBUG_NO_COOLDOWN else stats.cooldown
	_cooldowns[skill.id] = cooldown
	_cooldown_totals[skill.id] = cooldown
	if use_action_lock and not self_buff:
		_action_lock = stats.action_time
	if self_buff:
		_play_vltk_precast(skill, caster, null, stats)
		_cast_support_buff(skill, caster)
		_net_cast(skill, caster, null, true)
	elif is_instant_curse(skill):
		_play_vltk_precast(skill, caster, tgt_node, stats)
		_cast_instant_curse(skill, caster, tgt_node)
		_net_cast(skill, caster, tgt_node, true)
	elif USE_VLTK_SKILL_FX and VltkSkillRunner.supports(skill, _learned_level(skill)):
		VltkSkillRunner.execute(caster, tgt_node, stats, skill, _learned_level(skill))
		if (skill.target_self or skill.target_ally) and not skill.vltk_attribs.is_empty():
			_cast_support_buff(skill, caster)
		_net_cast(skill, caster, tgt_node, false)
	else:
		SectSkillCast.execute(caster, tgt_node, stats, skill)
	## Đánh trúng quái/người nào thì vòng đỏ hiện dưới chân đó (như khi bấm chọn).
	if caster.has_method("mark_cast_target"):
		caster.mark_cast_target(tgt_node)
	if not self_buff:
		active_skill_id = skill.id
		active_skill_at = Time.get_ticks_msec()
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
	if not skill.vltk_append_skill_ids.is_empty():
		## Hào quang tổng hợp (Bế Nguyệt Phất Trần): mỗi nhịp chạy từng hào quang con đã học như gốc.
		for part in skill.aura_parts(sect, level, _learned_level_of_part):
			_tick_one_aura(part["skill"], caster, int(part["level"]))
		return
	_tick_one_aura(skill, caster, level)

## Cấp hào quang con của hào quang tổng hợp: chưa học (cấp lưu 0) thì không chạy.
func _learned_level_of_part(s: SkillDefinition) -> int:
	var prof := _profile()
	if prof == null or prof.get_skill_level(s.id) <= 0:
		return 0
	return _learned_level(s)

## Hào quang bật của người khác có gồm `skill_id` không (chính nó hoặc 1 hào quang con của hào quang tổng hợp).
static func aura_covers(sect: SectDefinition, active_aura_id: String, skill_id: String) -> bool:
	if active_aura_id == "":
		return false
	if active_aura_id == skill_id:
		return true
	if sect == null:
		return false
	for s: SkillDefinition in sect.skills:
		if s.id == active_aura_id:
			for part in s.aura_parts(sect, s.max_level if s.max_level > 0 else 20):
				if (part["skill"] as SkillDefinition).id == skill_id:
					return true
			return false
	return false

func _tick_one_aura(skill: SkillDefinition, caster: Node2D, level: int) -> void:
	if skill == null or skill.vltk_skill_id <= 0 or level <= 0:
		return
	if not skill.target_enemy:
		_apply_aura_to_allies(skill, caster, level)
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

## Buff hỗ trợ như KSkill::Cast gốc: luôn áp lên người thi triển (TargetSelf); skill có TargetAlly + đạn vùng
## (IsRangeDmg, VD Thanh Phong phù 3 ô, Bất Động Minh Vương / Xuất Ứ Bất Nhiễm 10 ô) thì mọi đồng đội CÙNG PHE (cùng màu
## tên) đứng trong vùng ô vuông quanh người thi triển cũng nhận. Online: máy của đồng đội tự nhận qua receive_ally_support.
func _cast_support_buff(skill: SkillDefinition, caster: Node2D) -> void:
	# Kích nổ khí trường (CanDetonate) lập tức khi thi triển skill kích nổ (như Thần Quang Toàn Nhiễu)
	if skill.has_attrib("candetonate1") or skill.vltk_skill_id == 1384:
		var lvl := _learned_level(skill)
		var s := VltkSkillData.skill(skill.vltk_skill_id, lvl)
		var center := VltkMath.logic_of(caster)
		var radius: float = float(skill.vltk_attack_radius if skill.vltk_attack_radius > 0 else 600)
		var bonus_mult: float = 1.0
		if skill.has_attrib("candetonate1"):
			var v := skill.get_attrib("candetonate1", lvl)
			if v.z > 0:
				bonus_mult = float(v.z) / 100.0
		elif s.has("candetonate1"):
			var cd_arr: Array = s["candetonate1"]
			if cd_arr.size() >= 3:
				bonus_mult = float(cd_arr[2]) / 100.0
		if bonus_mult <= 0.0:
			bonus_mult = (100.0 + (lvl - 1) * (350.0 / 25.0)) / 100.0 if lvl <= 26 else (450.0 + (lvl - 26) * (110.0 / 6.0)) / 100.0
		VltkMissile.detonate_missiles(caster, [107264, 109568], center, radius, bonus_mult)

	var payload := skill.get_state_payload(_learned_level(skill))
	var targets: Array[Node2D] = [caster]
	if has_ally_area(skill):
		targets = CombatTargeting.find_in_cells(caster, VltkMath.ground_of(caster), ally_cells(skill), false, true)
		if not targets.has(caster):
			targets.append(caster)
	CombatTargeting.apply_state_to(targets, skill.id, payload, state_meta(skill))
	if has_ally_area(skill):
		for t in ally_fx_nodes(caster, skill):
			play_ally_hit_fx(t, skill, _learned_level(skill))

## Người cùng phe với `caster` trong vùng buff (gồm chính họ) để VẼ vòng va chạm — quét cả người chơi khác online
## ("other_players"; CombatTargeting.find_in_cells chỉ quét player/enemies vì chỉ số của họ do máy họ tự tính).
static func ally_fx_nodes(caster: Node2D, skill: SkillDefinition) -> Array[Node2D]:
	var out: Array[Node2D] = [caster]
	var center := VltkMath.ground_of(caster)
	var cells := ally_cells(skill)
	for group in [&"player", &"other_players"]:
		for n in caster.get_tree().get_nodes_in_group(group):
			if not (n is Node2D) or n == caster or out.has(n) or not is_instance_valid(n) or n.is_queued_for_deletion():
				continue
			if CombatTargeting.in_vltk_cells(center, n, cells) and CombatTargeting.get_relation(caster, n) == Camp.Relation.ALLY:
				out.append(n)
	return out

## KMissle::ProcessCollision gốc (máy người chơi): đạn của buff vùng chạm tới AI trong vùng thì vẽ hình va chạm của đạn
## (MS_DoCollision — AnimFile4 trong Missles.txt) ngay dưới chân người đó, VD Từ Hàng Phổ Độ -> đạn 5 -> vòng hồi sinh lực.
## ColFollowTarget = 1 thì hình đi theo người, 0 thì đứng tại chỗ. Mỗi người chỉ 1 hình cùng lúc (cùng skill).
static func play_ally_hit_fx(node: Node2D, skill: SkillDefinition, level: int) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree() or skill == null or skill.vltk_skill_id <= 0:
		return
	if not VltkSkillData.has_skill(skill.vltk_skill_id):
		return
	var m := VltkSkillData.missile_for(VltkSkillData.skill(skill.vltk_skill_id, level))
	var anims: Array = m.get("anims", [])
	var phase: Variant = anims[VltkSkillData.Phase.COLLISION] if anims.size() > VltkSkillData.Phase.COLLISION else null
	if not (phase is Dictionary):
		return
	var key := "_ally_fx_until_%d" % skill.vltk_skill_id
	var now := Time.get_ticks_msec()
	if int(node.get_meta(key, 0)) > now:
		return
	var follow: Node2D = node if int(m.get("col_follow", 0)) else null
	var fx := VltkEffect.spawn(node.get_parent(), phase, VltkMath.logic_of(node) - Vector2(0, 5), 0.0, 0, follow)
	if fx != null:
		node.set_meta(key, now + int(float(fx.end_tick) * VltkMath.TICK * 1000.0))

## ONLINE — người chơi khác (`caster`) vừa ra buff vùng: vẽ vòng va chạm dưới chân mọi người cùng phe với họ trong vùng
## (cả mình lẫn người khác), như máy client gốc tự vẽ khi đạn chạm. Chỉ số thì mỗi máy tự nhận qua receive_ally_support.
static func play_ally_hit_fx_around(caster: Node2D, skill: SkillDefinition, level: int) -> void:
	if caster == null or not is_instance_valid(caster) or not has_ally_area(skill) or skill.is_aura:
		return
	for t in ally_fx_nodes(caster, skill):
		play_ally_hit_fx(t, skill, level)


## Hệ số nới phạm vi buff / hào quang đồng đội theo phái (KHÔNG có trong gốc — cân bằng riêng): id skill bắt đầu bằng
## "<phái>_" -> cạnh vùng ô vuông DmgRange nhân hệ số này. Nga Mi x2 (hào quang 10 -> 20 ô, Phổ Độ Chúng Sinh 14 -> 28,
## Từ Hàng Phổ Độ 5 -> 10). Máy người thi triển và máy đồng đội (online) cùng đọc nên luôn khớp.
const SECT_ALLY_RANGE_SCALE := {"nga_mi": 2.0}

## Cạnh vùng ô vuông (ô bản đồ) buff / hào quang lên đồng đội của `skill`, đã nhân SECT_ALLY_RANGE_SCALE.
static func ally_cells(skill: SkillDefinition) -> int:
	if skill == null:
		return 0
	for sect_id: String in SECT_ALLY_RANGE_SCALE:
		if skill.id.begins_with(sect_id + "_"):
			return int(round(skill.vltk_damage_range * float(SECT_ALLY_RANGE_SCALE[sect_id])))
	return skill.vltk_damage_range

## Skill hỗ trợ có vùng ảnh hưởng lên đồng đội (TargetAlly + đạn IsRangeDmg có DmgRange).
static func has_ally_area(skill: SkillDefinition) -> bool:
	return skill != null and not skill.target_enemy and skill.target_ally \
			and skill.vltk_range_damage != 0 and skill.vltk_damage_range > 0

## Gói trạng thái hào quang hỗ trợ áp lên đồng đội mỗi nhịp: bỏ tham số skill_* (appendskill, tầm...) — chỉ chỉ số.
## Thời gian = thành phần [1] trong lua (thường 18 frame = 1 giây) nên rời vùng hoặc tắt hào quang là hết ngay sau đó.
static func aura_ally_payload(skill: SkillDefinition, level: int) -> Dictionary:
	var payload := skill.get_state_payload(level)
	var attribs := {}
	for k: String in payload["attribs"]:
		if not k.begins_with("skill_") and not k.begins_with("missle_"):
			attribs[k] = payload["attribs"][k]
	payload["attribs"] = attribs
	return payload

## Skill con của hào quang (VD Lưu Thủy 86 -> 206) mang CÙNG StateSpecialId (39 Lưu Thủy, 40 Mộng Điệp, 41 Phật Tâm Từ Hữu,
## 56 Phổ Độ Chúng Sinh, 45 La Hán Trận...) và áp trạng thái đó lên mọi người cùng phe trong vùng -> đồng đội cũng có hình dưới chân.
static func aura_ally_meta(skill: SkillDefinition) -> Dictionary:
	return state_meta(skill)


## HÀO QUANG HỖ TRỢ (Lưu Thủy, Mộng Điệp, Phật Tâm Từ Hữu, Thanh Âm Phạn Xướng, Phổ Độ Chúng Sinh, La Hán Trận, Thất Tinh
## Trận...): KNpc::ProcessState gốc mỗi 10 frame thi triển skill con -> đạn "Vòng tròn hỗ trợ đồng đội" (DmgRange 10 ô,
## Phổ Độ Chúng Sinh 14) áp thuộc tính hào quang lên mình + đồng đội cùng phe trong vùng. Bản thân đã có chỉ số hào quang
## qua CombatantBuild nên ở đây chỉ áp cho NGƯỜI KHÁC (khoá "aura:<id>": cùng hào quang từ nhiều người không cộng dồn —
## gốc cùng skill con thì thay thế).
func _apply_aura_to_allies(skill: SkillDefinition, caster: Node2D, level: int) -> void:
	if not has_ally_area(skill):
		return
	var allies := CombatTargeting.find_in_cells(caster, VltkMath.ground_of(caster), ally_cells(skill), false, true)
	allies.erase(caster)
	var payload := aura_ally_payload(skill, level)
	if allies.is_empty() or (payload["attribs"] as Dictionary).is_empty():
		return
	CombatTargeting.apply_state_to(allies, "aura:" + skill.id, payload, aura_ally_meta(skill))

## ONLINE — máy của MÌNH nhận buff đồng đội: người chơi khác (`caster`) vừa thi triển skill hỗ trợ vùng / đang bật hào quang
## hỗ trợ; mình cùng phe và đứng trong vùng ô quanh họ thì tự áp trạng thái (chỉ số nhân vật mỗi máy tự tính).
## `aura` = nhịp hào quang (bỏ qua nếu chính mình đang bật cùng hào quang — đã có qua CombatantBuild).
static func receive_ally_support(me: Node2D, caster: Node2D, skill: SkillDefinition, level: int, aura: bool) -> bool:
	if me == null or caster == null or not is_instance_valid(caster) or not has_ally_area(skill):
		return false
	if aura != skill.is_aura or me.get_node_or_null("StatusEffectController") == null:
		return false
	## Quan hệ NGƯỜI CHƠI – NGƯỜI CHƠI theo màu tên (Camp.relation, cả 2 là người chơi: 2 Sát thủ vẫn là địch); đang cừu sát thì thôi.
	if ("pk_enemy" in caster and caster.pk_enemy) or Camp.relation(CombatTargeting.get_camp(caster), CombatTargeting.get_camp(me), true) != Camp.Relation.ALLY:
		return false
	if not CombatTargeting.in_vltk_cells(VltkMath.ground_of(caster), me, ally_cells(skill)):
		return false
	var targets: Array[Node2D] = [me]
	if aura:
		var prof := GameManager.local_profile
		if prof != null and aura_covers(SectRegistry.get_by_id(prof.sect_id), prof.active_aura_id, skill.id):
			return false
		var payload := aura_ally_payload(skill, level)
		if (payload["attribs"] as Dictionary).is_empty():
			return false
		CombatTargeting.apply_state_to(targets, "aura:" + skill.id, payload, aura_ally_meta(skill))
	else:
		CombatTargeting.apply_state_to(targets, skill.id, skill.get_state_payload(level), state_meta(skill))
	return true

## Skill sự kiện HỖ TRỢ bắn ra từ đạn của chiêu đánh (KSkill::OnMissleEvent, ByMissle): VD Ngọc Tuyền Tâm Kinh cấp 11+
## -> FlyEvent 1115 (lifereplenish_v như Từ Hàng Phổ Độ) áp lên mình + đồng đội cùng phe trong vùng ô vuông quanh
## `center_logic` (vị trí đạn mẹ). Chạy trên MỌI máy (máy người khác chạy lại chiêu qua VltkSkillRunner.replay) và mỗi máy
## chỉ áp cho nhân vật nó tự tính chỉ số: người thi triển là người chơi khác thì chỉ xét nhân vật của mình.
static func apply_event_support(launcher: Node2D, vltk_id: int, level: int, center_logic: Vector2) -> void:
	var skill := skill_by_vltk_id(vltk_id)
	if skill == null or launcher == null or not is_instance_valid(launcher) or not launcher.is_inside_tree() \
			or not has_ally_area(skill):
		return
	var center := VltkMath.to_world(center_logic)
	var cells := ally_cells(skill)
	var targets: Array[Node2D] = []
	if launcher is RemotePlayer:
		var me := launcher.get_tree().get_first_node_in_group(&"player") as Node2D
		if me != null and CombatTargeting.in_vltk_cells(center, me, cells) and not ("pk_enemy" in launcher and launcher.pk_enemy) \
				and Camp.relation(CombatTargeting.get_camp(launcher), CombatTargeting.get_camp(me), true) == Camp.Relation.ALLY:
			targets.append(me)
	else:
		targets = CombatTargeting.find_in_cells(launcher, center, cells, false, true)
		if skill.target_self and not targets.has(launcher) and CombatTargeting.in_vltk_cells(center, launcher, cells):
			targets.append(launcher)
	var alive: Array[Node2D] = []
	for n in targets:
		if not (n.has_method("is_dead") and n.is_dead()):
			alive.append(n)
	if alive.is_empty():
		return
	CombatTargeting.apply_state_to(alive, skill.id, skill.get_state_payload(level), state_meta(skill))
	for t in alive:
		play_ally_hit_fx(t, skill, level)

## SkillDefinition theo số skill VLTK gốc, tra trong MỌI phái (buff của người chơi phái khác).
static var _skill_by_vltk: Dictionary = {}

static func skill_by_vltk_id(vltk_id: int) -> SkillDefinition:
	if _skill_by_vltk.is_empty():
		for sect in SectRegistry.load_all():
			for s: SkillDefinition in sect.skills:
				if s.vltk_skill_id > 0 and not _skill_by_vltk.has(s.vltk_skill_id):
					_skill_by_vltk[s.vltk_skill_id] = s
	return _skill_by_vltk.get(vltk_id)

## Id phái chứa `skill` ("" nếu không thấy) — để tìm hào quang con của hào quang tổng hợp ở máy người khác.
static func sect_id_of(skill: SkillDefinition) -> String:
	if skill == null:
		return ""
	for sect in SectRegistry.load_all():
		if sect.skills.has(skill):
			return sect.id
	return ""

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
func _play_vltk_precast(skill: SkillDefinition, caster: Node2D, target: Node2D = null, stats: ResolvedSkillStats = null) -> void:
	if USE_VLTK_SKILL_FX and skill.vltk_skill_id > 0:
		VltkSkillRunner.play_support(caster, target, skill, _learned_level(skill), stats)

func _learned_level(skill: SkillDefinition) -> int:
	var prof := _profile()
	var base_lvl := maxi(1, prof.get_skill_level(skill.id) if prof != null else 1)
	if GameModeManager.is_offline() and (GameManager.game_mode == GameManager.GameMode.STAGE or (GameManager.field_map != null and GameManager.field_map.get("survivor_mode", false) == true)):
		var star := PlayerStats.get_skill_star(skill.id)
		if star > 0:
			base_lvl = maxi(base_lvl, star * 4)
		if PlayerStats.level > 1:
			base_lvl += int((PlayerStats.level - 1) / 2)
	var caster := get_parent()
	var c_stats: CombatantStats = caster.get("combat_stats") if caster else null
	if c_stats != null:
		base_lvl += c_stats.get_skill_bonus(int(skill.element) if "element" in skill else -1, skill.vltk_skill_id)
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
		var ca := skill.get_attrib("colddamage_v", level)
		var skill_freeze := ca.z if ca.z > 0 else ca.y
		freeze = skill_freeze + attacker.cold_enhance_frames
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

## `level_override` > 0: tính ở cấp này thay vì cấp đã học (skill con bắn qua sự kiện dùng EventSkillLevel của skill cha).
func _resolve_stats(skill: SkillDefinition, caster: Node2D = null, level_override: int = 0) -> ResolvedSkillStats:
	var stats := ResolvedSkillStats.new()
	var profile := _profile()
	var learned_level: int = level_override if level_override > 0 else _learned_level(skill)
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
	var add_damage_p := skill.get_support_percent_from_other_skills(sect_skills, profile, _learned_level)
	var is_physical := skill.is_physical()

	var combat_stats: CombatantStats
	if caster != null and "combat_stats" in caster and caster.combat_stats != null:
		combat_stats = caster.combat_stats
	elif profile != null:
		combat_stats = profile.get_combat_stats()
	else:
		combat_stats = CombatantStats.new()
	## nAddDamageP gốc = GetAddSkillDamage + m_CurrentSkillEnhancePercent (+ m_CurrentManaToSkillEnhanceP khi nội lực đầy).
	add_damage_p += combat_stats.skill_enhance_p
	if combat_stats.mana_to_skill_enhance_p != 0 and caster != null and "mana" in caster \
			and combat_stats.max_mana > 0 and float(caster.mana) >= float(combat_stats.max_mana):
		add_damage_p += combat_stats.mana_to_skill_enhance_p
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
	if skill.has_attrib("attackrating_p"):
		stats.attack_rating_p = skill.get_attrib("attackrating_p", learned_level).x
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
	elif skill.vltk_state_special_id > 0:
		## Skill tấn công kèm trạng thái / hiệu ứng hình ảnh (VD: Kinh Đào Phách Ngạn lửa trên đầu, StateSpecialId 240 / 100240)
		var payload := skill.get_state_payload(learned_level)
		stats.is_state_only = false
		stats.state_source_id = skill.id
		stats.state_attribs = payload["attribs"]
		stats.state_seconds = payload["seconds"] if payload["seconds"] > 0.0 else 5.0
		stats.state_meta = state_meta(skill)
		stats.state_radius = skill.get_effect_radius_px()
	stats.element = skill.element	
	## Hồi chiêu riêng gốc (TimePerCast / skill_mintimepercast_v) không giảm theo tốc độ đánh; tốc độ đánh rút ngắn ĐỘNG TÁC.
	stats.cooldown = skill.get_cooldown_at_level(learned_level)
	stats.action_time = action_seconds(is_physical, combat_stats) / maxf(0.5, PlayerStats.attack_speed_multiplier)
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
	if src_child in [357, 100418, 100429] or src_id in [1232, 100357, 1368, 101421]:
		return

	_try_sam_la_doc_hai(caster, target)

	## Cửu Kiếm Hợp Nhất (Hoa Sơn 150): tự động kích hoạt Độc Cô Cửu Kiếm (1368 - phóng 9 thanh phi kiếm)
	## Chỉ áp dụng khi người chơi gắn skill ở ô thi triển liên tục (và đang bật); nếu không để ở slot liên tục thì không áp dụng.
	var cuu_kiem := _find_sect_skill("hoa_son_cuu_kiem_hop_nhat")
	if cuu_kiem != null and is_skill_usable(cuu_kiem):
		var in_loop := false
		if caster.is_in_group("player"):
			in_loop = is_in_active_loop_slot("hoa_son_cuu_kiem_hop_nhat")
		else:
			in_loop = true
		if in_loop:
			var cd_hs: float = _auto_attack_cooldowns.get("hoa_son_cuu_kiem_hop_nhat", 0.0)
			if cd_hs <= 0.0:
				var lvl_hs := _learned_level(cuu_kiem)
				# Tỉ lệ 10% (lv 1) -> 30% (lv 26) theo đúng statline SubResource_82
				var rate_hs := 0.10 + 0.20 * clampf(float(lvl_hs - 1) / 25.0, 0.0, 1.0)
				if randf() < rate_hs:
					_auto_attack_cooldowns["hoa_son_cuu_kiem_hop_nhat"] = 1.0  ## Giãn cách chuẩn 1 giây
					_cast_auto_attack_missile(caster, target, 1368, lvl_hs, cuu_kiem)

	_try_ba_la_tam_kinh(caster)

## Sâm La Độc Hải (Ngũ Độc thất truyền 180) — wu_adskill gốc (script/skill/advancedskill.lua):
##   autoattackskill = { 1232*256 + cấp (1->20), -1, 1*18*256 + tỉ lệ (20%->60%) }
## KNpc::ReceiveDamage gốc: mỗi đòn TRÚNG có tỉ lệ thi triển Hồn Ảnh Tùng Sanh 1232 CÙNG CẤP lên mục tiêu, xong 18 frame
## (1 giây) mới kích lại. 1232 (wudu.lua daowudu150_2) là skill đánh riêng: đạn 357 đầu lâu nổ tại mục tiêu, ngoại công,
## độc sát 1->12/nhịp (10 frame, 60 frame) + ngũ hành tương khắc 40%->80% — damage KHÔNG lấy từ Sâm La.
func _try_sam_la_doc_hai(caster: Node2D, target: Node2D) -> void:
	var sam_la := _find_sect_skill("ngu_doc_sam_la_doc_hai")
	if sam_la == null or not is_skill_usable(sam_la) or float(_auto_attack_cooldowns.get(sam_la.id, 0.0)) > 0.0:
		return
	var lvl := _learned_level(sam_la)
	var v := sam_la.get_attrib("autoattackskill", lvl)
	@warning_ignore("integer_division")
	var child_id := v.x / 256
	var child_lvl := maxi(1, v.x % 256)
	var rate := clampi(v.z % 256, 0, 100)
	@warning_ignore("integer_division")
	var interval := float(v.z / 256) / VltkMath.FPS
	if child_id <= 0 or randi() % 100 >= rate:
		return
	_auto_attack_cooldowns[sam_la.id] = interval
	_cast_auto_attack_missile(caster, target, child_id, child_lvl, hon_anh_tung_sanh_def())

static var _hon_anh_def: SkillDefinition

## Hồn Ảnh Tùng Sanh 1232 không có trong bảng phái (chỉ Sâm La kích) — dựng SkillDefinition theo Skills.txt + wudu.lua
## daowudu150_2 để _resolve_stats tính đúng AppendSkillEffect gốc (IsPhysical 1: cộng sát thương hệ ngoại công của trang bị,
## độc sát gộp MixPoisonDamage, hỗ trợ % sát thương kỹ năng).
static func hon_anh_tung_sanh_def() -> SkillDefinition:
	if _hon_anh_def == null:
		var d := SkillDefinition.new()
		d.id = "ngu_doc_hon_anh_tung_sanh"
		d.skill_name = "Hồn Ảnh Tùng Sanh"
		d.vltk_skill_id = 1232
		d.vltk_is_physical = 1
		d.element = ElementTypes.ElementType.MOC
		d.max_level = 20
		d.target_enemy = true
		d.vltk_attribs = {
			"seriesdamage_p": [PackedFloat32Array([1, 40, 0, 20, 80, 0, 21, 82, 0]), PackedFloat32Array(), PackedFloat32Array()],
			"poisondamage_v": [PackedFloat32Array([1, 1, 0, 20, 12, 0, 23, 15, 0]),
					PackedFloat32Array([1, 60, 0, 20, 60, 0]), PackedFloat32Array([1, 10, 0, 20, 10, 0])],
		}
		_hon_anh_def = d
	return _hon_anh_def

## Ba La Tâm Kinh (Nga Mi thất truyền 180) — em_adskill gốc (script/skill/advancedskill.lua):
##   autoattackskill = { 1234*256 + cấp (1->20), -1, 3*18*256 + tỉ lệ (10%->30%) }
## -> mỗi lần ra đòn có tỉ lệ thi triển Từ Hàng Phổ Độ 1234 CÙNG CẤP Ba La; kích hoạt xong 3*18 frame (3 giây) mới kích lại.
## 1234 giống Từ Hàng Phổ Độ 93 (bảng cihang_pudu, đạn 5, vùng 5 ô) nhưng MissleForm 7: bung tại chỗ người đánh,
## hồi sinh lực cho mình + đồng đội cùng phe quanh mình. Online: máy đồng đội tự nhận qua S_CAST (CAST_SUPPORT).
func _try_ba_la_tam_kinh(caster: Node2D) -> void:
	var ba_la := _find_sect_skill("nga_mi_ba_la_tam_kinh")
	if ba_la == null or not is_skill_usable(ba_la) or float(_auto_attack_cooldowns.get(ba_la.id, 0.0)) > 0.0:
		return
	var lvl := _learned_level(ba_la)
	var v := ba_la.get_attrib("autoattackskill", lvl)
	@warning_ignore("integer_division")
	var child_id := v.x / 256
	var child_lvl := maxi(1, v.x % 256)
	var rate := clampi(v.z % 256, 0, 100)
	@warning_ignore("integer_division")
	var interval := float(v.z / 256) / VltkMath.FPS
	if child_id <= 0 or randi() % 100 >= rate:
		return
	var heal := skill_by_vltk_id(child_id)
	if heal == null:
		return
	_auto_attack_cooldowns[ba_la.id] = interval
	cast_area_heal(caster, heal, child_lvl)
	if NetClient.is_in_world() and caster.is_in_group("player"):
		NetClient.send_cast(child_id, child_lvl, NetProto.CAST_SUPPORT, 0, caster.global_position)

## Buff vùng bung tại chỗ `caster` (không động tác, không hồi chiêu): áp trạng thái lên mình + đồng đội cùng phe trong
## vùng ô vuông, vẽ ảnh xuất chiêu + vòng va chạm dưới chân từng người (như máy client gốc khi đạn chạm).
static func cast_area_heal(caster: Node2D, skill: SkillDefinition, level: int) -> void:
	if caster == null or not is_instance_valid(caster) or not caster.is_inside_tree() or skill == null:
		return
	var targets: Array[Node2D] = [caster]
	if has_ally_area(skill):
		targets = CombatTargeting.find_in_cells(caster, VltkMath.ground_of(caster), ally_cells(skill), false, true)
		if not targets.has(caster):
			targets.append(caster)
	var alive: Array[Node2D] = []
	for n in targets:
		if not (n.has_method("is_dead") and n.is_dead()):
			alive.append(n)
	if alive.is_empty():
		return
	CombatTargeting.apply_state_to(alive, skill.id, skill.get_state_payload(level), state_meta(skill))
	if USE_VLTK_SKILL_FX and VltkSkillData.has_skill(skill.vltk_skill_id):
		## Ảnh xuất chiêu + tiếng + ĐẠN của skill (Từ Hàng Phổ Độ: đạn 5 — cột nước hồi máu là pha bay của đạn) bung tại chỗ,
		## chỉ để vẽ (ctx.stats = null, như máy đồng đội vẽ lại) — không động tác, không ngắt đòn đang ra.
		VltkSkillRunner.replay(caster, skill.vltk_skill_id, level, null, VltkMath.logic_of(caster))
		for t in ally_fx_nodes(caster, skill):
			play_ally_hit_fx(t, skill, level)

## `stats_skill`: skill dùng để tính đòn — skill con thật (VD Hồn Ảnh 1232) ở `level`, không phải skill bị động kích nó.
func _cast_auto_attack_missile(caster: Node2D, target: Node2D, child_skill_id: int, level: int, stats_skill: SkillDefinition) -> void:
	if not USE_VLTK_SKILL_FX or not VltkSkillData.has_skill(child_skill_id):
		return
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	ctx.stats = _resolve_stats(stats_skill, caster, level)
	ctx.attacker_stats = caster.combat_stats if "combat_stats" in caster else null
	if "cast_target_group" in caster:
		ctx.target_group = caster.cast_target_group
	var des := VltkMath.logic_of(target)
	VltkSkillCaster.cast(ctx, child_skill_id, level, des, target)
	if NetClient.is_in_world() and caster.is_in_group("player"):
		var target_eid := int(target.net_eid) if "net_eid" in target else 0
		NetClient.send_cast(child_skill_id, level, 0, target_eid, target.global_position)

## Kích hoạt kỹ năng tự động khi nhận sát thương / bị đánh trúng (autoreplyskill trong VLTK gốc).
func trigger_auto_reply_skills(victim: Node2D, attacker: Node2D = null) -> void:
	if victim == null or not is_instance_valid(victim) or not victim.is_inside_tree():
		return
	if victim is Node and (victim as Node).is_queued_for_deletion():
		return

	## Thiên Vương Bang: Chinh Chiến Bát Phương (thien_vuong_chinh_chien_bat_phuong)
	## Tự động xuất chiêu Du Long Chân Khí (Skill ID 1231): xóa hiệu ứng bất thường, né tránh phi đạn 80%, bỏ qua trạng thái 100%.
	var chinh_chien := _find_sect_skill("thien_vuong_chinh_chien_bat_phuong")
	if chinh_chien != null and is_skill_usable(chinh_chien):
		var cd: float = _auto_reply_cooldowns.get("thien_vuong_chinh_chien_bat_phuong", 0.0)
		if cd <= 0.0:
			var lvl := _learned_level(chinh_chien)
			var progress := clampf(float(lvl - 1) / 19.0, 0.0, 1.0)
			var chance := 0.01 + 0.02 * progress  ## Tỷ lệ kích hoạt: 1% ở lv 1 -> 3% ở lv 20
			if randf() < chance:
				var cd_duration := 30.0 - 20.0 * progress  ## Giãn cách: 30s ở lv 1 -> 10s ở lv 20
				_auto_reply_cooldowns["thien_vuong_chinh_chien_bat_phuong"] = cd_duration
				var buff_duration := 1.0 + 2.0 * progress  ## Thời gian duy trì: 1s ở lv 1 -> 3s ở lv 20
				_trigger_du_long_chan_khi(victim, lvl, buff_duration, chinh_chien)

	## Côn Lôn: Thiên Cương Khí Kính (con_lon_thien_cuong_khi_kinh)
	## Tự động kích hoạt Tiên Thiên Cương Khí (Skill ID 1239): bỏ qua kháng lôi 15%, tăng tỷ lệ Lưỡng Nghi Chân Khí 15%, ngũ hành tương khắc 50%, duy trì 15 giây.
	var thien_cuong := _find_sect_skill("con_lon_thien_cuong_khi_kinh")
	if thien_cuong != null and is_skill_usable(thien_cuong):
		var cd_tc: float = _auto_reply_cooldowns.get("con_lon_thien_cuong_khi_kinh", 0.0)
		if cd_tc <= 0.0:
			var lvl_tc := _learned_level(thien_cuong)
			var progress_tc := clampf(float(lvl_tc - 1) / 19.0, 0.0, 1.0)
			var chance_tc := 0.03 + 0.02 * progress_tc  ## Tỷ lệ kích hoạt: 3% ở lv 1 -> 5% ở lv 20
			if randf() < chance_tc:
				var cd_duration_tc := 30.0 - 15.0 * progress_tc  ## Giãn cách: 30s ở lv 1 -> 15s ở lv 20
				_auto_reply_cooldowns["con_lon_thien_cuong_khi_kinh"] = cd_duration_tc
				var buff_duration_tc := 5.0 + 10.0 * progress_tc  ## Thời gian duy trì: 5s ở lv 1 -> 15s ở lv 20
				_trigger_thien_cuong_khi_kinh(victim, lvl_tc, buff_duration_tc, thien_cuong)

	## Võ Đang: Chân Võ Thất Tiết (vo_dang_chan_vo_that_tiet)
	## Tự động kích hoạt Âm Dương Khí Quyết (Skill ID 1238 / State 192): chuyển hóa sát thương thành nội lực (50% lv1 -> 200% lv20), tăng ngũ hành tương khắc (20% -> 50%), duy trì 5s -> 15s.
	var chan_vo := _find_sect_skill("vo_dang_chan_vo_that_tiet")
	if chan_vo != null and is_skill_usable(chan_vo):
		var cd_cv: float = _auto_reply_cooldowns.get("vo_dang_chan_vo_that_tiet", 0.0)
		if cd_cv <= 0.0:
			var lvl_cv := _learned_level(chan_vo)
			var progress_cv := clampf(float(lvl_cv - 1) / 19.0, 0.0, 1.0)
			var chance_cv := 0.03 + 0.07 * progress_cv  ## Tỷ lệ kích hoạt: 3% ở lv 1 -> 10% ở lv 20
			if randf() < chance_cv:
				var cd_duration_cv := 30.0 - 10.0 * progress_cv  ## Giãn cách: 30s ở lv 1 -> 20s ở lv 20
				_auto_reply_cooldowns["vo_dang_chan_vo_that_tiet"] = cd_duration_cv
				var buff_duration_cv := 5.0 + 10.0 * progress_cv  ## Thời gian duy trì: 5s ở lv 1 -> 15s ở lv 20
				_trigger_chan_vo_that_tiet(victim, lvl_cv, buff_duration_cv, chan_vo)

	## Thiên Nhẫn: Liệt Hỏa Phần Thiên (thien_nhan_liet_hoa_phan_thien)
	## Tự động phản kích Hỏa sát và có tỷ lệ kích hoạt Ma Âm Phệ Phách (Skill ID 1236 / 723 / State 121) làm đối thủ hoảng loạn.
	var liet_hoa := _find_sect_skill("thien_nhan_liet_hoa_phan_thien")
	if liet_hoa != null and is_skill_usable(liet_hoa):
		var cd_lh: float = _auto_reply_cooldowns.get("thien_nhan_liet_hoa_phan_thien", 0.0)
		if cd_lh <= 0.0:
			var lvl_lh := _learned_level(liet_hoa)
			var progress_lh := clampf(float(lvl_lh - 1) / 19.0, 0.0, 1.0)
			var cd_duration_lh := 30.0 - 10.0 * progress_lh  ## Giãn cách phản kích: 30s ở lv 1 -> 20s ở lv 20
			_auto_reply_cooldowns["thien_nhan_liet_hoa_phan_thien"] = cd_duration_lh
			_trigger_liet_hoa_phan_thien(victim, attacker, lvl_lh, progress_lh, liet_hoa)

	## Thúy Yên: Huyền Băng Vô Tắc (advancedskill.lua cy_adskill) — bị đánh trúng có xác suất tự thi triển Dung Tuyết Vô Tung
	## (skill 1235) ẩn thân. Tỷ lệ / giãn cách đọc thẳng từ autoreplyskill gốc: 5% / 20 giây (cấp 1) -> 10% / 10 giây (cấp 19-20).
	var huyen_bang := _find_sect_skill(HideSkill.HUYEN_BANG_VO_TAC_ID)
	if huyen_bang != null and victim.is_in_group("player") and is_skill_usable(huyen_bang):
		if float(_auto_reply_cooldowns.get(huyen_bang.id, 0.0)) <= 0.0:
			var lvl_hb := _learned_level(huyen_bang)
			var reply := HideSkill.auto_reply(huyen_bang, lvl_hb)
			if randi() % 100 < int(reply["rate"]):
				_auto_reply_cooldowns[huyen_bang.id] = float(reply["wait"])
				_trigger_dung_tuyet_vo_tung(victim, lvl_hb, huyen_bang)

	## Vũ Hồn: Tận Trung Báo Quốc (vu_hon_tan_trung_bao_quoc - Skill ID 1986)
	## Bị đánh trúng có xác suất tự động thi triển Đấu Dũng Đương Tiên (Skill ID 1987) tăng tốc độ di chuyển và bốc lửa Tiên Giới Hỏa
	var tan_trung := _find_sect_skill("vu_hon_tan_trung_bao_quoc")
	if tan_trung != null and is_skill_usable(tan_trung):
		var cd_tt: float = _auto_reply_cooldowns.get("vu_hon_tan_trung_bao_quoc", 0.0)
		if cd_tt <= 0.0:
			var lvl_tt := _learned_level(tan_trung)
			var progress_tt := clampf(float(lvl_tt - 1) / 19.0, 0.0, 1.0)
			var chance_tt := 0.01 + 0.19 * progress_tt  ## 1% ở lv 1 -> 20% ở lv 20
			if randf() < chance_tt:
				var cd_duration_tt := 15.0  ## Giãn cách phản kích: 15 giây theo VLTK gốc
				_auto_reply_cooldowns["vu_hon_tan_trung_bao_quoc"] = cd_duration_tt
				_trigger_dau_dung_duong_tien(victim, lvl_tt, tan_trung)

## Dung Tuyết Vô Tung: ẩn thân (trạng thái mang "hide") + hình Tiên Giới Thủy; online báo server để nó đặt cờ ẩn thân.
func _trigger_dung_tuyet_vo_tung(victim: Node2D, level: int, parent_skill: SkillDefinition) -> void:
	var status: StatusEffectController = victim.get_node_or_null("StatusEffectController")
	if status == null:
		return
	var secs := HideSkill.dung_tuyet_seconds(level)
	var meta := {"name": "Dung Tuyết Vô Tung", "icon": parent_skill.icon if parent_skill else null, "is_debuff": false}
	status.apply_state("thuy_yen_dung_tuyet_vo_tung", {"hide": Vector3i(1, 0, 0)}, secs, meta)
	if VltkSkillData.has_skill(HideSkill.DUNG_TUYET_VO_TUNG):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(HideSkill.DUNG_TUYET_VO_TUNG, level))
	if NetClient.is_in_world():
		NetClient.send_cast(HideSkill.DUNG_TUYET_VO_TUNG, level, NetProto.CAST_SUPPORT, 0, victim.global_position)

func _trigger_dau_dung_duong_tien(victim: Node2D, level: int, parent_skill: SkillDefinition) -> void:
	var status: StatusEffectController = victim.get_node_or_null("StatusEffectController")
	if status == null:
		return
	var progress := clampf(float(level - 1) / 19.0, 0.0, 1.0)
	var speed_bonus := int(10.0 + 20.0 * progress)  ## Cấp 1 tăng 10% -> Cấp 20 tăng 30% tốc độ di chuyển
	var duration := 5.0 + 8.0 * progress  ## Cấp 1 duy trì 5s -> Cấp 20 duy trì 13s
	var attribs := {
		"fastwalkrun_p": Vector3i(speed_bonus, 0, 0),
	}
	var meta := {
		"name": "Đấu Dũng Đương Tiên",
		"icon": parent_skill.icon if parent_skill else null,
		"is_debuff": false,
		"state_id": 0
	}
	status.apply_state("vu_hon_dau_dung_duong_tien", attribs, duration, meta)

	## Phát hiệu ứng ngọn lửa Tiên Giới Hỏa bốc cháy quanh thân nhân vật
	if VltkSkillData.has_skill(1987):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1987, level))
	elif VltkSkillData.has_skill(1986):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1986, level))

	if NetClient.is_in_world() and victim.is_in_group("player"):
		NetClient.send_cast(1987, level, NetProto.CAST_SUPPORT, 0, victim.global_position)

func _trigger_liet_hoa_phan_thien(victim: Node2D, attacker: Node2D, level: int, progress: float, parent_skill: SkillDefinition) -> void:
	## 1. Hỏa sát phản kích (100 điểm ở lv 1 -> 500 điểm ở lv 20)
	var fire_dmg := int(100.0 + 400.0 * progress)
	if attacker != null and is_instance_valid(attacker) and attacker is Node2D:
		if attacker.has_method("take_damage"):
			attacker.take_damage(fire_dmg)
		elif attacker.has_method("take_damage_from"):
			var mods := CombatFormulas.HitModifiers.new()
			mods.attacker_node = victim
			mods.is_melee = true
			mods.use_attack_rating = false
			attacker.take_damage_from(victim, null, fire_dmg, fire_dmg, CombatFormulas.DamageType.FIRE, ElementTypes.ElementType.HOA, mods)

	## 2. Tỷ lệ kích hoạt Ma Âm Phệ Phách: 1% ở lv 1 -> 3% ở lv 20
	var chance := 0.01 + 0.02 * progress
	if randf() <= chance:
		## Hoạt ảnh xuất chiêu Tiên Giới Hỏa quanh người
		if VltkSkillData.has_skill(1226):
			VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1226, level))
		elif VltkSkillData.has_skill(1236):
			VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1236, level))

		## Thời gian hoảng loạn: 1s ở lv 1 -> 4s ở lv 20
		var confuse_duration := 1.0 + 3.0 * progress
		## Tỷ lệ trúng hiệu ứng: 35% ở lv 1 -> 85% ở lv 20 (miss rate 65% -> 15%)
		var hit_chance := 0.35 + 0.50 * progress
		var radius := 180.0
		var max_targets := 6

		var targets: Array[Node2D] = []
		var tree := victim.get_tree()
		if tree != null:
			var enemies := tree.get_nodes_in_group("enemies")
			for e in enemies:
				if e is Node2D and is_instance_valid(e) and not (e as Node).is_queued_for_deletion():
					if (e as Node2D).global_position.distance_to(victim.global_position) <= radius:
						targets.append(e as Node2D)
						if targets.size() >= max_targets:
							break

		for t in targets:
			if randf() <= hit_chance:
				var status: StatusEffectController = t.get_node_or_null("StatusEffectController")
				if status != null:
					var attribs := {
						"randmove": Vector3i(1, int(confuse_duration * 18), 0)
					}
					var meta := {
						"name": "Ma Âm Phệ Phách",
						"icon": parent_skill.icon if parent_skill else null,
						"is_debuff": true,
						"state_id": 121
					}
					status.apply_state("debuff_hoang_loan_121", attribs, confuse_duration, meta)

		## Đồng bộ mạng nếu đang online
		if NetClient.is_in_world() and victim.is_in_group("player"):
			NetClient.send_cast(1226, level, 0, 0, victim.global_position)

func _trigger_thien_cuong_khi_kinh(victim: Node2D, level: int, duration: float, parent_skill: SkillDefinition) -> void:
	var status: StatusEffectController = victim.get_node_or_null("StatusEffectController")
	if status != null:
		var progress := clampf(float(level - 1) / 19.0, 0.0, 1.0)
		var ignore_light := int(5.0 + 10.0 * progress)
		var enhance_luong_nghi := int(3.0 + 12.0 * progress)
		var series_dmg := int(20.0 + 30.0 * progress)
		var attribs := {
			"anti_lightingres_yan_p": Vector3i(ignore_light, 0, 0),
			"enhance_717_auto": Vector3i(enhance_luong_nghi, 0, 0),
			"seriesdamage_p": Vector3i(series_dmg, 0, 0),
		}
		var meta := {
			"name": "Thiên Cương Khí Kính",
			"icon": parent_skill.icon if parent_skill else null,
			"is_debuff": false,
			"state_id": 1239
		}
		status.apply_state("con_lon_thien_cuong_khi_kinh", attribs, duration, meta)

	## Hoạt ảnh Tiên Giới Thổ hoàng kim quanh người
	if VltkSkillData.has_skill(1239):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1239, level))
	elif VltkSkillData.has_skill(1229):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1229, level))

	## Đồng bộ mạng nếu đang online
	if NetClient.is_in_world() and victim.is_in_group("player"):
		NetClient.send_cast(1229, level, 0, 0, victim.global_position)

func _trigger_chan_vo_that_tiet(victim: Node2D, level: int, duration: float, parent_skill: SkillDefinition) -> void:
	var status: StatusEffectController = victim.get_node_or_null("StatusEffectController")
	if status != null:
		var progress := clampf(float(level - 1) / 19.0, 0.0, 1.0)
		var dmg_to_mana := int(50.0 + 150.0 * progress)
		var series_dmg := int(20.0 + 30.0 * progress)
		var attribs := {
			"damage2addmana_p": Vector3i(dmg_to_mana, int(duration * 18), 0),
			"seriesdamage_p": Vector3i(series_dmg, int(duration * 18), 0),
		}
		var meta := {
			"name": "Chân Võ Thất Tiết",
			"icon": parent_skill.icon if parent_skill else null,
			"is_debuff": false,
			"state_id": 192
		}
		status.apply_state("vo_dang_chan_vo_that_tiet", attribs, duration, meta)

	## Hoạt ảnh Tiên Giới Thổ hoàng kim quanh người (Skill 1238 / 1228)
	if VltkSkillData.has_skill(1238):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1238, level))
	elif VltkSkillData.has_skill(1228):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1228, level))

	## Đồng bộ mạng nếu đang online
	if NetClient.is_in_world() and victim.is_in_group("player"):
		NetClient.send_cast(1228, level, 0, 0, victim.global_position)

func _trigger_du_long_chan_khi(victim: Node2D, level: int, duration: float, parent_skill: SkillDefinition) -> void:
	var status: StatusEffectController = victim.get_node_or_null("StatusEffectController")
	if status != null:
		## 1. Xóa toàn bộ hiệu ứng xấu đang chịu (choáng, chậm, độc, debuff)
		status.cleanse_negative_effects()
		## 2. Áp trạng thái Du Long Chân Khí (né phi đạn 80%, miễn nhiễm trạng thái xấu 100%)
		var attribs := {
			"missle_missrate": Vector3i(80, 0, 0),
			"ignorenegativestate_p": Vector3i(100, 0, 0)
		}
		var meta := {
			"name": "Du Long Chân Khí",
			"icon": parent_skill.icon if parent_skill else null,
			"is_debuff": false,
			"state_id": 1231
		}
		status.apply_state("thien_vuong_dulong_chan_khi", attribs, duration, meta)

	## 3. Hoạt ảnh Tiên Giới Kim (vòng sáng tiên giới hoàng kim quanh người)
	if VltkSkillData.has_skill(1231):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1231, level))

	## 4. Đồng bộ mạng nếu đang online
	if NetClient.is_in_world() and victim.is_in_group("player"):
		NetClient.send_cast(1231, level, 0, 0, victim.global_position)

## Kích hoạt kỹ năng tự cứu khi máu yếu (autorescueskill trong VLTK gốc: Tử Hà Kiếm Khí, Lưỡng Nghi Chân Khí, Hấp Tinh Trận...)
func trigger_auto_rescue_skills(victim: Node2D) -> void:
	if victim == null or not is_instance_valid(victim) or not victim.is_inside_tree():
		return
	if victim is Node and (victim as Node).is_queued_for_deletion():
		return

	## Hoa Sơn: Tử Hà Kiếm Khí (hoa_son_tu_ha_kiem_khi)
	## Khi sinh lực thấp hơn 25%, có 25% tỉ lệ nhận được trạng thái Hồi phục sinh lực (ở cấp 20).
	## Mỗi nửa giây hồi phục 10000 điểm sinh lực, duy trì trong 4 giây. Thời gian hồi chiêu: 20 giây.
	var tu_ha := _find_sect_skill("hoa_son_tu_ha_kiem_khi")
	if tu_ha != null and is_skill_usable(tu_ha):
		var cd: float = _auto_reply_cooldowns.get("hoa_son_tu_ha_kiem_khi", 0.0)
		if cd <= 0.0:
			var lvl := _learned_level(tu_ha)
			var progress := clampf(float(lvl - 1) / 19.0, 0.0, 1.0)
			var chance := 0.05 + 0.20 * progress  ## Tỷ lệ: 5% ở lv 1 -> 25% ở lv 20
			if randf() < chance:
				var cd_duration := 20.0  ## Hồi chiêu: 20s
				_auto_reply_cooldowns["hoa_son_tu_ha_kiem_khi"] = cd_duration
				var heal_per_tick := int(1000.0 + 9000.0 * progress)  ## 1000 ở lv 1 -> 10000 ở lv 20
				var buff_duration := 4.0  ## Duy trì trong 4 giây
				_trigger_tu_ha_kiem_khi(victim, lvl, buff_duration, heal_per_tick, tu_ha)

	## Côn Lôn: Lưỡng Nghi Chân Khí (con_lon_luong_nghi_chan_khi)
	## Khi sinh lực thấp hơn 25%, có tỷ lệ tự động kích hoạt Ma Pháp Độn (tạo khiên tăng tốc và kháng đòn).
	var luong_nghi := _find_sect_skill("con_lon_luong_nghi_chan_khi")
	if luong_nghi != null and is_skill_usable(luong_nghi):
		var cd_ln: float = _auto_reply_cooldowns.get("con_lon_luong_nghi_chan_khi", 0.0)
		if cd_ln <= 0.0:
			var lvl_ln := _learned_level(luong_nghi)
			var progress_ln := clampf(float(lvl_ln - 1) / 19.0, 0.0, 1.0)
			var chance_ln := 0.01 + 0.19 * progress_ln  ## 1% ở lv 1 -> 20% ở lv 20
			if "combat_stats" in victim and victim.combat_stats != null:
				chance_ln += float(victim.combat_stats.enhance_luong_nghi_p) / 100.0  ## +3% -> +15% từ Thiên Cương Khí Kính
			if randf() < chance_ln:
				_auto_reply_cooldowns["con_lon_luong_nghi_chan_khi"] = 20.0  ## Hồi chiêu: 20s theo VLTK gốc
				var buff_duration_ln := 5.0 + 5.0 * progress_ln  ## Duy trì: 5s ở lv 1 -> 10s ở lv 20
				_trigger_luong_nghi_chan_khi(victim, lvl_ln, buff_duration_ln, luong_nghi)

	## Đường Môn: Hấp Tinh Trận (duong_mon_hap_tinh_tran)
	## Kỹ năng thất truyền 180 của phái Đường Môn. Khi sinh lực thấp hơn 25%, có tỷ lệ tự động
	## kích hoạt Hóa Giải Sát Thương (ngăn chặn 100% sát thương phải chịu trong 2s -> 5s).
	## Tỷ lệ: 5% ở lv 1 -> 20% ở lv 20. Giãn cách: 10 giây (180 frames).
	var hap_tinh := _find_sect_skill("duong_mon_hap_tinh_tran")
	if hap_tinh != null and is_skill_usable(hap_tinh):
		var cd_ht: float = _auto_reply_cooldowns.get("duong_mon_hap_tinh_tran", 0.0)
		if cd_ht <= 0.0:
			var lvl_ht := _learned_level(hap_tinh)
			var progress_ht := clampf(float(lvl_ht - 1) / 19.0, 0.0, 1.0)
			var chance_ht := 0.05 + 0.15 * progress_ht  ## 5% ở lv 1 -> 20% ở lv 20
			if randf() < chance_ht:
				var cd_duration_ht := 10.0  ## Giãn cách kích hoạt: 10 giây chuẩn VLTK (180 frames)
				_auto_reply_cooldowns["duong_mon_hap_tinh_tran"] = cd_duration_ht
				var buff_duration_ht := 2.0 + 3.0 * progress_ht  ## Duy trì: 2s ở lv 1 -> 5s ở lv 20
				_trigger_hap_tinh_tran(victim, lvl_ht, buff_duration_ht, hap_tinh)

func _trigger_luong_nghi_chan_khi(victim: Node2D, level: int, duration: float, parent_skill: SkillDefinition) -> void:
	var status: StatusEffectController = victim.get_node_or_null("StatusEffectController")
	if status != null:
		var progress := clampf(float(level - 1) / 19.0, 0.0, 1.0)
		var speed_bonus := int(5.0 + 30.0 * progress)
		var magic_shield_val := int(1800.0 + 8200.0 * progress)  ## 1800 (18 lần) -> 10000 (100 lần nội lực)
		var attribs := {
			"staticmagicshield_p": Vector3i(magic_shield_val, 0, 0),
			"fastwalkrun_p": Vector3i(speed_bonus, 0, 0),
		}
		var ma_phap_skill := _find_sect_skill("con_lon_ma_phap_don")
		var icon: Texture2D = ma_phap_skill.icon if (ma_phap_skill and ma_phap_skill.icon) else (parent_skill.icon if parent_skill else null)
		var meta := {
			"name": "Ma Pháp Độn",
			"icon": icon,
			"is_debuff": false,
			"state_id": 721
		}
		status.apply_state("con_lon_ma_phap_don", attribs, duration, meta)

	if VltkSkillData.has_skill(721):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(721, level))
	elif VltkSkillData.has_skill(717):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(717, level))

	if NetClient.is_in_world() and victim.is_in_group("player"):
		NetClient.send_cast(717, level, 0, 0, victim.global_position)

func _trigger_tu_ha_kiem_khi(victim: Node2D, level: int, duration: float, heal_per_half_sec: int, parent_skill: SkillDefinition) -> void:
	## 1. Hồi phục sinh lực mỗi nửa giây (8 ticks trong 4 giây)
	if victim.has_method("apply_hot"):
		var total_heal := float(heal_per_half_sec * 8)
		victim.apply_hot(total_heal, duration)
	elif victim.has_method("heal"):
		victim.heal(float(heal_per_half_sec))

	## 2. Áp icon trạng thái Hồi phục sinh lực trên StatusEffectController
	var status: StatusEffectController = victim.get_node_or_null("StatusEffectController")
	if status != null:
		var meta := {
			"name": "Hồi phục sinh lực",
			"icon": parent_skill.icon if parent_skill else null,
			"is_debuff": false,
			"state_id": 1366
		}
		status.apply_state("hoa_son_tu_ha_hoi_phuc", {}, duration, meta)

	## 3. Hoạt ảnh / FX kỹ năng nếu có (chiêu con 1366 hoặc precast)
	if VltkSkillData.has_skill(1366):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1366, level))

	## 4. Đồng bộ mạng nếu đang online
	if NetClient.is_in_world() and victim.is_in_group("player"):
		NetClient.send_cast(1366, level, 0, 0, victim.global_position)

func _trigger_hap_tinh_tran(victim: Node2D, level: int, duration: float, parent_skill: SkillDefinition) -> void:
	var status: StatusEffectController = victim.get_node_or_null("StatusEffectController")
	if status != null:
		var attribs := {
			"damage_absorb_p": Vector3i(100, 0, 0),
		}
		var meta := {
			"name": "Hóa Giải Sát Thương",
			"icon": parent_skill.icon if parent_skill else null,
			"is_debuff": false,
			"state_id": 1233
		}
		status.apply_state("duong_mon_hoa_giai_sat_thuong", attribs, duration, meta)

	## Hoạt ảnh Tiên Giới Mộc hoàng kim quanh người (Skill ID 1233 hoặc 1223)
	if VltkSkillData.has_skill(1233):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1233, level))
	elif VltkSkillData.has_skill(1223):
		VltkSkillRunner.play_precast(victim, VltkSkillData.skill(1223, level))

	## Đồng bộ mạng nếu đang online
	if NetClient.is_in_world() and victim.is_in_group("player"):
		NetClient.send_cast(1223, level, 0, 0, victim.global_position)

## Xử lý sự kiện khi một trạng thái (buff/debuff) kết thúc/hết hạn trên nhân vật
func on_state_expired(target: Node2D, source_id: String, _meta: Dictionary) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	if target.has_method("is_dead") and target.is_dead():
		return

	## Vũ Hồn: Khi trạng thái Vũ Mục Di Thư (vu_hon_vu_muc_di_thu - Skill ID 1982) kết thúc,
	## kích hoạt Trung Vũ Lưu Phong (vu_hon_trung_vu_luu_phong - Skill ID 1984, chiêu thức 1991):
	## Hồi % sinh lực tối đa và bốc cháy ngọn lửa môn phái hệ Hỏa (tien_giai_hoa) quanh thân nhân vật.
	if source_id == "vu_hon_vu_muc_di_thu":
		_trigger_trung_vu_luu_phong(target)

func _trigger_trung_vu_luu_phong(target: Node2D) -> void:
	var skill_trung_vu := _find_sect_skill("vu_hon_trung_vu_luu_phong")
	if skill_trung_vu == null or not is_skill_usable(skill_trung_vu):
		return
	var lvl := _learned_level(skill_trung_vu)
	if lvl <= 0:
		return

	## Công thức hồi % sinh lực tối đa từ source gốc VLTK (wuhuntang.lua - zhongwuliufengBUFF):
	## resume_life_p: {{1, 30}, {28, 60}, {34, 70}, {35, 71}}
	## Cấp 1 hồi 30%, Cấp 20 hồi đúng 51% (51.11%), Cấp 21 hồi 52% (52.22%)
	var heal_pct: float = 30.0
	if lvl <= 28:
		heal_pct = 30.0 + float(lvl - 1) * (60.0 - 30.0) / 27.0
	elif lvl <= 34:
		heal_pct = 60.0 + float(lvl - 28) * (70.0 - 60.0) / 6.0
	else:
		heal_pct = 70.0 + float(lvl - 34) * (71.0 - 70.0) / 1.0
	var heal_percent_int := int(floor(heal_pct))

	var max_hp: float = float(target.get("max_health")) if target.get("max_health") != null else 1000.0
	var heal_amount := floorf(max_hp * float(heal_percent_int) / 100.0)
	if target.has_method("heal") and heal_amount > 0.0:
		target.heal(heal_amount)

	## Phát hiệu ứng ngọn lửa môn phái (tiến giai hệ Hỏa - tien_giai_hoa) bốc cháy quanh thân nhân vật
	if VltkSkillData.has_skill(1991):
		VltkSkillRunner.play_precast(target, VltkSkillData.skill(1991, lvl))
	elif VltkSkillData.has_skill(1987):
		VltkSkillRunner.play_precast(target, VltkSkillData.skill(1987, lvl))

	## Đồng bộ mạng nếu đang online
	if NetClient.is_in_world() and target.is_in_group("player"):
		NetClient.send_cast(1991, lvl, NetProto.CAST_SUPPORT, 0, target.global_position)

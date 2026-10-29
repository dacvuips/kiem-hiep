extends RefCounted
class_name VltkSkillRunner
## Phép chia nguyên trong file này là CỐ Ý — chép đúng số học số nguyên của bản gốc C++ (g_DirCos, ô logic 32...).
@warning_ignore_start("integer_division")
## Cầu nối skill môn phái (SkillDefinition) -> bộ máy chiêu VLTK gốc (VltkSkillCaster). Thay cho SectSkillCast với
## skill có dữ liệu skill_fx (tools/import_vltk_skill_fx.py).
##
## Trình tự như KNpc::DoSkill gốc:
##   1. Ảnh xuất chiêu PreCastSpr hiện ngay trên người (KNpcRes::SetSpecialSpr), quay mặt về mục tiêu, diễn động tác
##      (ngoại công: đánh, nội công: thi triển).
##   2. Tới 60% động tác (ATTACKACTION_EFFECT_PERCENT) mới bắn đạn — nhắm vị trí mục tiêu LÚC ĐÓ.

const ATTACK_EFFECT_PERCENT := 0.6
## Hoạt ảnh xuất chiêu hỗ trợ: 1.0 = đúng chuẩn 100% nhịp gốc VLTK
const SUPPORT_ANIM_SPEED := 1.0

## SkillStyle 1 = CẬN CHIẾN (SKILL_SS_Melee) — MisslesForm của nó là eMeleeForm gốc (SkillDef.h, đếm tiếp sau 8 đội hình đạn).
const STYLE_MELEE := 1
const MELEE_BLUR_ATTACK := 8      ## Melee_AttackWithBlur: 1 đòn đánh nhanh
const MELEE_RUN_ATTACK := 11      ## Melee_RunAndAttack: CHẠY lao tới mục tiêu rồi đánh
const MELEE_MANY_ATTACK := 12     ## Melee_ManyAttack: nhiều đòn liên tiếp
const RUSH_STOP_DISTANCE := 42.0  ## chạy tới cách mục tiêu chừng này thì dừng để đánh
const MELEE_APPROACH_SECONDS := 2.0  ## tối đa chạy tới mục tiêu ngoài tầm trong chừng này giây
const TRAIL_CAST_TICKS := 3.0     ## đang chạy lao tới: cứ 3 nhịp thi triển skill con 1 lần (gốc: mỗi nhịp)

static func is_melee_supported(s: Dictionary) -> bool:
	return int(s.get("style", 0)) == STYLE_MELEE and int(s.get("form", 0)) in [MELEE_BLUR_ATTACK, MELEE_RUN_ATTACK, MELEE_MANY_ATTACK]

## Skill dùng được bộ máy mới: có SkillId gốc + dữ liệu skill_fx + là skill bắn đạn nhắm địch HOẶC cận chiến (đòn liên tiếp /
## chạy tới đánh).
static func supports(skill: SkillDefinition, level: int) -> bool:
	if skill == null or skill.vltk_skill_id <= 0 or not skill.target_enemy:
		return false
	var s := VltkSkillData.skill(skill.vltk_skill_id, level)
	if s.is_empty():
		return false
	return int(s["style"]) == VltkSkillCaster.STYLE_MISSILES or is_melee_supported(s)

static func execute(caster: Node2D, target: Node2D, stats: ResolvedSkillStats, skill: SkillDefinition, level: int) -> void:
	var s := VltkSkillData.skill(skill.vltk_skill_id, level)
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	ctx.stats = stats
	ctx.attacker_stats = caster.combat_stats if "combat_stats" in caster else null
	## Người thi triển không phải nhân vật của mình (VD bot PK đánh người chơi) tự khai nhóm mục tiêu.
	if "cast_target_group" in caster:
		ctx.target_group = caster.cast_target_group
	## Mục tiêu ảo (điểm phía trước mặt) chỉ dùng toạ độ — không bám theo.
	var aim_node: Node2D = null if target.has_meta("cast_point") else target
	var aim_point := VltkMath.logic_of(target)
	play_precast(caster, s)
	play_cast_sound(caster, skill.vltk_skill_id)
	if is_melee_supported(s):
		SfxManager.play_skill_cast(stats, caster.global_position)
		_run_melee(ctx, caster, aim_node.get_instance_id() if aim_node != null else 0, aim_point, level, s, skill.get_attack_radius_at_level(level))
		return
	var delay := 0.0
	if caster.has_method("begin_skill_action"):
		delay = caster.begin_skill_action(int(s.get("physical", 0)) == 1, target.global_position) * ATTACK_EFFECT_PERCENT
	SfxManager.play_skill_cast(stats, caster.global_position)
	## Lambda KHÔNG giữ node mục tiêu (quái có thể chết trong lúc chờ tới 60% động tác -> Godot báo "capture was freed"):
	## chỉ giữ ID đối tượng rồi tra lại lúc bắn.
	var aim_id: int = aim_node.get_instance_id() if aim_node != null else 0
	var fire := func() -> void:
		if not ctx.is_valid():
			return
		var des := aim_point
		var live_aim: Node2D = instance_from_id(aim_id) as Node2D if aim_id != 0 else null
		if live_aim != null and live_aim.is_inside_tree():
			des = VltkMath.logic_of(live_aim)
		else:
			live_aim = null
		VltkSkillCaster.cast(ctx, skill.vltk_skill_id, level, des, live_aim)
	if delay <= 0.0:
		fire.call()
	else:
		caster.get_tree().create_timer(delay, false).timeout.connect(fire)

## ---- Skill CẬN CHIẾN (KNpc::CastMeleeSkill / OnManyAttack / OnRunAttack gốc) ----
## Mục tiêu tra lại bằng ID mỗi bước (quái có thể chết giữa chừng) — không giữ node qua các lần chờ.
static func _melee_aim(target_id: int, fallback_logic: Vector2) -> Dictionary:
	var node: Node2D = instance_from_id(target_id) as Node2D if target_id != 0 else null
	if node != null and node.is_inside_tree():
		return {"node": node, "logic": VltkMath.logic_of(node)}
	return {"node": null, "logic": fallback_logic}

## Skill con (ChildSkillId — đòn đánh tầm gần, đạn "Công kích vật lý" 63...) thi triển ở cấp của skill cha, nhắm mục tiêu.
static func _melee_hit(ctx: VltkCastContext, s: Dictionary, level: int, aim: Dictionary) -> void:
	var child := int(s.get("child", 0))
	if child > 0 and ctx.is_valid():
		VltkSkillCaster.cast(ctx, child, level, aim["logic"], aim["node"])

## Mục tiêu NGOÀI tầm skill thì nhân vật chạy tới trước (như VLTK gốc: bấm đánh quái xa -> đi tới tầm rồi mới ra chiêu).
static func _melee_approach(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, attack_radius: float) -> Dictionary:
	var aim := _melee_aim(target_id, fallback_logic)
	if aim["node"] == null or attack_radius <= 0.0 or not caster.has_method("rush_toward"):
		return aim
	if VltkMath.logic_of(caster).distance_to(aim["logic"]) <= attack_radius:
		return aim
	caster.rush_toward(aim["node"], MELEE_APPROACH_SECONDS, maxf(attack_radius * 0.7, RUSH_STOP_DISTANCE))
	while ctx.is_valid() and caster.is_rushing():
		await caster.get_tree().create_timer(0.05, false).timeout
	return _melee_aim(target_id, aim["logic"])

static func _run_melee(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary, attack_radius: float) -> void:
	match int(s["form"]):
		MELEE_MANY_ATTACK:
			var near := await _melee_approach(ctx, caster, target_id, fallback_logic, attack_radius)
			if ctx.is_valid():
				await _melee_many(ctx, caster, target_id, near["logic"], level, s)
		MELEE_RUN_ATTACK:
			await _melee_run(ctx, caster, target_id, fallback_logic, level, s)
		_:
			var near_single := await _melee_approach(ctx, caster, target_id, fallback_logic, attack_radius)
			if ctx.is_valid():
				await _melee_single(ctx, caster, target_id, near_single["logic"], level, s)

## 1 đòn: diễn động tác đánh, tới 60% động tác thì trúng.
static func _melee_single(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary) -> void:
	var aim := _melee_aim(target_id, fallback_logic)
	var duration := 0.5
	if caster.has_method("begin_skill_action"):
		duration = caster.begin_skill_action(true, VltkMath.to_world(aim["logic"]))
	await caster.get_tree().create_timer(duration * ATTACK_EFFECT_PERCENT, false).timeout
	_melee_hit(ctx, s, level, _melee_aim(target_id, aim["logic"]))

## DoManyAttack/OnManyAttack: ChildSkillNum đòn liên tiếp; mỗi đòn dài GetMissleGenerateTime(i) nhịp, diễn động tác đánh rồi
## HẾT đòn mới thi triển skill con tại mục tiêu.
static func _melee_many(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary) -> void:
	var steps := maxi(1, int(s.get("child_num", 1)))
	var aim := _melee_aim(target_id, fallback_logic)
	for step in steps:
		if not ctx.is_valid():
			return
		var seconds := float(maxi(2, VltkSkillCaster.generate_time(s, step))) / VltkMath.FPS
		if caster.has_method("begin_skill_action"):
			caster.begin_skill_action(true, VltkMath.to_world(aim["logic"]), seconds)
		await caster.get_tree().create_timer(seconds, false).timeout
		if not ctx.is_valid():
			return
		aim = _melee_aim(target_id, aim["logic"])
		_melee_hit(ctx, s, level, aim)

## DoRunAttack/OnRunAttack: bước 0 = nhân vật CHẠY lao tới mục tiêu (tối đa GetMissleGenerateTime(0) nhịp), vừa chạy vừa
## thi triển skill con; bước 1 = đứng lại đánh, tới 60% động tác thì trúng.
static func _melee_run(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary) -> void:
	var aim := _melee_aim(target_id, fallback_logic)
	if aim["node"] != null and caster.has_method("rush_toward"):
		## Thời gian lao tối thiểu theo dữ liệu gốc (GetMissleGenerateTime(0) nhịp), kéo dài đủ để TỚI nơi nếu mục tiêu còn xa.
		var rush_seconds := float(maxi(2, VltkSkillCaster.generate_time(s, 0))) / VltkMath.FPS
		if caster.has_method("get_rush_speed"):
			var need := caster.global_position.distance_to((aim["node"] as Node2D).global_position) / maxf(caster.get_rush_speed(), 1.0)
			rush_seconds = clampf(maxf(rush_seconds, need + 0.15), rush_seconds, MELEE_APPROACH_SECONDS * 0.75)
		caster.rush_toward(aim["node"], rush_seconds, RUSH_STOP_DISTANCE)
		while ctx.is_valid() and caster.is_rushing():
			await caster.get_tree().create_timer(TRAIL_CAST_TICKS / VltkMath.FPS, false).timeout
			if ctx.is_valid() and caster.is_rushing():
				aim = _melee_aim(target_id, aim["logic"])
				_melee_hit(ctx, s, level, aim)
	if not ctx.is_valid():
		return
	await _melee_single(ctx, caster, target_id, aim["logic"], level, s)

## Skill HỖ TRỢ (buff, bùa, hào quang, hồi máu — không phải đạn nhắm địch): diễn đủ phần "thi triển" của KNpc::DoSkill gốc —
## ảnh xuất chiêu trên người, động tác thi triển, rồi ở 60% động tác thi triển tiếp đội hình đạn/skill con (MisslesForm
## 6 = tại mục tiêu, 7 = tại người dùng, ... ) CHỈ ĐỂ VẼ: không gây sát thương (ctx.stats = null).
## `target` null = tự nhắm vào mình (buff). Hình trạng thái gắn trên người do VltkStateSprite đảm nhiệm.
static func play_support(caster: Node2D, target: Node2D, skill: SkillDefinition, level: int) -> void:
	if skill == null or skill.vltk_skill_id <= 0 or not VltkSkillData.has_skill(skill.vltk_skill_id):
		return
	var s := VltkSkillData.skill(skill.vltk_skill_id, level)
	play_precast(caster, s, SUPPORT_ANIM_SPEED)
	var aim: Node2D = target if target != null and not target.has_meta("cast_point") else caster
	var delay := 0.0
	if caster.has_method("begin_skill_action"):
		delay = caster.begin_skill_action(false, aim.global_position) * ATTACK_EFFECT_PERCENT
	if int(s.get("style", 0)) != VltkSkillCaster.STYLE_MISSILES:
		return
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	ctx.stats = null
	var aim_id: int = aim.get_instance_id()  ## không bắt node trong lambda (có thể bị giải phóng lúc chờ)
	var fire := func() -> void:
		if not ctx.is_valid():
			return
		var live_aim: Node2D = instance_from_id(aim_id) as Node2D
		var des := VltkMath.logic_of(live_aim) if live_aim != null and live_aim.is_inside_tree() else ctx.launcher_logic()
		VltkSkillCaster.cast(ctx, skill.vltk_skill_id, level, des, null)
	if delay <= 0.0:
		fire.call()
	else:
		caster.get_tree().create_timer(delay, false).timeout.connect(fire)

## Online: VẼ LẠI chiêu người chơi khác vừa ra (S_CAST) — ảnh xuất chiêu, tiếng, đội hình đạn; ctx.stats = null nên không
## gây sát thương (máy người ra chiêu tính đòn thật). Skill cận chiến chỉ diễn 1 đòn skill con vào mục tiêu (không lao tới).
static func replay(caster: Node2D, vltk_skill_id: int, level: int, aim_node: Node2D, aim_logic: Vector2) -> void:
	if vltk_skill_id <= 0 or not VltkSkillData.has_skill(vltk_skill_id):
		return
	var s := VltkSkillData.skill(vltk_skill_id, level)
	play_precast(caster, s)
	play_cast_sound(caster, vltk_skill_id)
	var fire_id := vltk_skill_id
	if is_melee_supported(s):
		fire_id = int(s.get("child", 0))
	elif int(s.get("style", 0)) != VltkSkillCaster.STYLE_MISSILES:
		return
	if fire_id <= 0:
		return
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	ctx.stats = null
	var des := VltkMath.logic_of(aim_node) if aim_node != null else aim_logic
	VltkSkillCaster.cast(ctx, fire_id, level, des, aim_node)

## Tiếng ra chiêu gốc (KSkill::PlayPreCastSound: ManCastSnd / FMCastSnd theo giới tính người thi triển).
## Theo chuẩn VLTK gốc (KNpc::PlayPreCastSound: if (IsPlayer())): chỉ người chơi (Player/RemotePlayer/PKBot có avatar)
## mới phát tiếng hô hào nam/nữ. Quái vật / NPC dùng tiếng động tác quái riêng trong npc动作声音表 (VltkSound.npc), không
## la hét giọng người chơi. Skill không có tiếng gốc thì thôi (âm theo hệ của SfxManager.play_skill_cast vẫn chạy riêng).
static func play_cast_sound(caster: Node2D, vltk_skill_id: int) -> void:
	if caster == null or not ("avatar" in caster and caster.avatar != null):
		return
	var female: bool = caster.avatar.is_voice_female()
	var stream := VltkSound.skill_cast(vltk_skill_id, female)
	if stream != null:
		SfxManager.play(stream, caster.global_position)

## Ảnh PreCastSpr: chạy hết số frame 1 hướng trong (frame/hướng × nhịp_ms / 50) nhịp, bám theo người thi triển.
static func play_precast(caster: Node2D, s: Dictionary, speed: float = 1.0) -> void:
	var key := str(s.get("precast", ""))
	if key == "":
		return
	var anim := VltkSkillData.anim(key)
	if anim.is_empty():
		return
	var phase := {"anim": key, "frames": int(anim["frames"]), "dirs": int(anim["dirs"]),
			"interval": maxi(1, int(anim["interval"]) / 50)}
	var facing := 0
	if "avatar" in caster and caster.avatar:
		facing = int(caster.avatar.direction) * VltkMath.MAX_DIR / 8
	VltkEffect.spawn(caster.get_parent(), phase, VltkMath.logic_of(caster), 0.0, facing, caster, speed)

@warning_ignore_restore("integer_division")

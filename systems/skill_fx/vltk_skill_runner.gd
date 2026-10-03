extends RefCounted
class_name VltkSkillRunner
## Cầu nối skill môn phái (SkillDefinition) -> bộ máy chiêu VLTK gốc (VltkSkillCaster). Thay cho SectSkillCast với
## skill có dữ liệu skill_fx (tools/import_vltk_skill_fx.py).
##
## Trình tự như KNpc::DoSkill gốc:
##   1. Ảnh xuất chiêu PreCastSpr hiện ngay trên người (KNpcRes::SetSpecialSpr), quay mặt về mục tiêu, diễn động tác
##      (ngoại công: đánh, nội công: thi triển).
##   2. Tới 60% động tác (ATTACKACTION_EFFECT_PERCENT) mới bắn đạn — nhắm vị trí mục tiêu LÚC ĐÓ.

const ATTACK_EFFECT_PERCENT := 0.6

## Skill dùng được bộ máy mới: có SkillId gốc + dữ liệu skill_fx + là skill bắn đạn nhắm địch.
static func supports(skill: SkillDefinition, level: int) -> bool:
	if skill == null or skill.vltk_skill_id <= 0 or not skill.target_enemy:
		return false
	var s := VltkSkillData.skill(skill.vltk_skill_id, level)
	return not s.is_empty() and int(s["style"]) == VltkSkillCaster.STYLE_MISSILES

static func execute(caster: Node2D, target: Node2D, stats: ResolvedSkillStats, skill: SkillDefinition, level: int) -> void:
	var s := VltkSkillData.skill(skill.vltk_skill_id, level)
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	ctx.stats = stats
	ctx.attacker_stats = caster.combat_stats if "combat_stats" in caster else null
	## Mục tiêu ảo (điểm phía trước mặt) chỉ dùng toạ độ — không bám theo.
	var aim_node: Node2D = null if target.has_meta("cast_point") else target
	var aim_point := VltkMath.logic_of(target)
	play_precast(caster, s)
	var delay := 0.0
	if caster.has_method("begin_skill_action"):
		delay = caster.begin_skill_action(int(s.get("physical", 0)) == 1, target.global_position) * ATTACK_EFFECT_PERCENT
	SfxManager.play_skill_cast(stats, caster.global_position)
	var fire := func() -> void:
		if not ctx.is_valid():
			return
		var des := aim_point
		if aim_node != null and is_instance_valid(aim_node) and aim_node.is_inside_tree():
			des = VltkMath.logic_of(aim_node)
		else:
			aim_node = null
		VltkSkillCaster.cast(ctx, skill.vltk_skill_id, level, des, aim_node)
	if delay <= 0.0:
		fire.call()
	else:
		caster.get_tree().create_timer(delay, false).timeout.connect(fire)

## Ảnh PreCastSpr: chạy hết số frame 1 hướng trong (frame/hướng × nhịp_ms / 50) nhịp, bám theo người thi triển.
static func play_precast(caster: Node2D, s: Dictionary) -> void:
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
	VltkEffect.spawn(caster.get_parent(), phase, VltkMath.logic_of(caster), 0.0, facing, caster)

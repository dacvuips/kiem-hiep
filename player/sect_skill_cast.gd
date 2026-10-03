extends RefCounted
class_name SectSkillCast
## Thi triển 1 skill môn phái — tái dùng nguyên Projectile.setup_from_resolved() của gameplay
## hiện có (movement/pierce/chain/homing/on-hit-status/VFX/SFX đều nằm sẵn trong Projectile,
## không cần viết lại). Chỉ hỗ trợ delivery kiểu "bắn 1 viên bay tới mục tiêu" — đủ cho skill
## môn phái hiện tại; AOE tại chỗ để lại làm sau nếu cần.

const DEFAULT_SCENE := preload("res://projectiles/projectile.tscn")

static func execute(caster: Node2D, target: Node2D, stats: ResolvedSkillStats, skill: SkillDefinition) -> void:
	var scene: PackedScene = skill.projectile_scene if skill.projectile_scene else DEFAULT_SCENE
	var projectile: Projectile = ObjectPool.acquire(scene, caster.get_parent())
	projectile.global_position = caster.global_position
	var direction := (target.global_position - caster.global_position).normalized()
	## caster.combat_stats (CombatantStats CHÍNH XÁC 100% VLTK) — truyền vào để CombatFormulas
	## roll trúng/né đúng AttackRating của người thi triển skill, xem Projectile._deal_damage_to().
	var caster_stats: CombatantStats = caster.combat_stats if "combat_stats" in caster else null
	## Mục tiêu ảo (điểm phía trước mặt — "Không mục tiêu"/"Đánh theo hướng trước mặt"): chỉ lấy hướng, không đuổi theo.
	var real_target: Node2D = null if target.has_meta("cast_point") else target
	projectile.setup_from_resolved(direction, stats, real_target, caster_stats, caster)
	SfxManager.play_skill_cast(stats, caster.global_position)

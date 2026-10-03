extends RefCounted
class_name VltkCastContext
## Ngữ cảnh 1 lần thi triển chiêu VLTK — đi theo mọi đạn/skill con sinh ra từ lần thi triển đó (KMissleMagicAttribsData
## gốc: các đạn cùng 1 lần ra chiêu dùng chung 1 bộ thuộc tính sát thương).
##
## Chỉ giữ tham chiếu node + số liệu đã tính sẵn — không chứa logic riêng của skill (dùng chung được cho mọi người
## chơi / quái, sẵn cho online: server chỉ cần dựng lại context từ skill id + cấp + người thi triển).

var launcher: Node2D = null
## Nơi thả đạn/hiệu ứng (cùng cha với người thi triển để y-sort chung).
var world: Node = null
var stats: ResolvedSkillStats = null
var attacker_stats: CombatantStats = null
## Nhóm node bị đạn va chạm/gây sát thương (quái: "enemies").
var target_group: StringName = &"enemies"

func is_valid() -> bool:
	return launcher != null and is_instance_valid(launcher) and launcher.is_inside_tree()

func launcher_logic() -> Vector2:
	return VltkMath.logic_of(launcher)

func targets() -> Array[Node]:
	if launcher == null or not launcher.is_inside_tree():
		return []
	return launcher.get_tree().get_nodes_in_group(target_group)

## KMissle::ProcessDamage -> ReceiveDamage: mỗi lần trúng roll chí mạng riêng.
func deal_damage(target: Node) -> void:
	if stats == null or not is_instance_valid(target):
		return
	if target.has_method("take_damage_from"):
		var whole := int(stats.damage)
		var attacker := attacker_stats if attacker_stats else CombatantStats.new()
		var damage_type: CombatFormulas.DamageType = stats.main_damage_type if stats.main_damage_type >= 0 \
				else CombatFormulas.DamageType.PHYSICS
		target.take_damage_from(attacker, whole, whole, damage_type, stats.element, stats.make_hit_mods(launcher))
	elif target.has_method("take_damage"):
		target.take_damage(stats.damage)

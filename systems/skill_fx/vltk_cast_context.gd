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
var star_level: int = 1
## Hệ số khuếch đại sát thương bộc nổ (khi bị kích nổ bởi kỹ năng như Thần Quang Toàn Nhiễu)
var detonate_mult: float = 1.0

## Cache mảng mục tiêu theo từng physics frame (Zero-Allocation GC):
## Tránh gọi get_nodes_in_group() hàng nghìn lần mỗi giây khi có nhiều đạn bay cùng lúc.
static var _cached_frame: int = -1
static var _cached_group: StringName = &""
static var _cached_list: Array[Node] = []

func is_valid() -> bool:
	return launcher != null and is_instance_valid(launcher) and launcher.is_inside_tree()

func launcher_logic() -> Vector2:
	return VltkMath.logic_of(launcher)

func targets() -> Array[Node]:
	if launcher == null or not launcher.is_inside_tree():
		return []
	var f := Engine.get_physics_frames()
	if _cached_frame == f and _cached_group == target_group:
		return _cached_list
	_cached_frame = f
	_cached_group = target_group
	if target_group == &"moba_all":
		var list: Array[Node] = []
		list.append_array(launcher.get_tree().get_nodes_in_group(&"enemies"))
		list.append_array(launcher.get_tree().get_nodes_in_group(&"player"))
		_cached_list = list
	elif target_group == &"players_and_allies":
		var list: Array[Node] = []
		list.append_array(launcher.get_tree().get_nodes_in_group(&"player"))
		list.append_array(launcher.get_tree().get_nodes_in_group(&"allies"))
		_cached_list = list
	else:
		_cached_list = launcher.get_tree().get_nodes_in_group(target_group)
	return _cached_list

## KMissle::ProcessDamage -> ReceiveDamage: mỗi lần trúng roll chí mạng riêng.
func deal_damage(target: Node, skill: Dictionary = {}) -> void:
	if stats == null or not is_instance_valid(target):
		return
	var mult := maxf(1.0, detonate_mult)
	if target.has_method("take_damage_from"):
		var low := int((stats.damage_min if stats.damage_min >= 0.0 else stats.damage) * mult)
		var high := int((stats.damage_max if stats.damage_max >= 0.0 else stats.damage) * mult)
		var attacker := attacker_stats if attacker_stats else CombatantStats.new()
		var damage_type: CombatFormulas.DamageType = stats.main_damage_type if stats.main_damage_type >= 0 \
				else CombatFormulas.DamageType.PHYSICS
		var mods := stats.make_hit_mods(launcher)
		## IsUseAR / DoHurt của skill (Skills.txt). Skill không có dữ liệu (đòn tự dựng) giữ mặc định: tính trúng/trượt, luôn khựng.
		mods.use_attack_rating = int(skill.get("use_ar", 1)) != 0
		mods.do_hurt_p = int(skill.get("do_hurt", 100))
		target.take_damage_from(attacker, low, maxi(low, high), damage_type, stats.element, mods)
	elif target.has_method("take_damage"):
		var amount: float = stats.damage * mult
		if CombatFormulas.is_monster_hit(launcher, target):
			amount = CombatFormulas.scale_monster_damage(amount)
		target.take_damage(amount)

	if launcher != null and is_instance_valid(launcher) and launcher.has_method("on_hit_target"):
		launcher.on_hit_target(target, skill)

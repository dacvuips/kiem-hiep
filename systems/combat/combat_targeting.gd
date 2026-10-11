extends RefCounted
class_name CombatTargeting
## NƠI DUY NHẤT quyết định "ai là địch / ai là đồng đội" và quét mục tiêu trong phạm vi — dùng cho bùa,
## buff vùng, PK/tổ đội online. Skill không tự kiểm tra group/phe ở chỗ khác.
##
## Quan hệ theo PHE (= MÀU TÊN, Camp.Type), KHÔNG theo môn phái: cùng màu = đồng đội. Phe của 1 nhân vật
## là thuộc tính `camp` của node (Player lấy từ PlayerProfile.get_current_camp(), quái mặc định
## Camp.Type.ANIMAL). Luật: Camp.relation (= KNpcSet::GenOneRelation gốc) + luật PK giữa 2 người chơi.

const COMBATANT_GROUPS := ["player", "enemies"]

static func is_player(node: Node) -> bool:
	return node != null and node.is_in_group("player")

static func get_camp(node: Node) -> int:
	if node != null and "camp" in node:
		return int(node.camp)
	return Camp.Type.ANIMAL

## Quan hệ của `b` nhìn từ phía `a`. Giữa 2 người chơi khác phe: chỉ là ĐỊCH khi `a` đang bật PK
## (`pk_enabled`) hoặc thuộc phe Sát thủ — không thì trung lập (không đánh nhau), giống gốc chặn đánh khi
## chưa bật PK.
static func get_relation(a: Node, b: Node) -> Camp.Relation:
	if a == null or b == null:
		return Camp.Relation.NONE
	if a == b:
		return Camp.Relation.ALLY
	## Cừu sát online: đối thủ (RemotePlayer.pk_enemy) luôn là địch của mình và ngược lại.
	if ("pk_enemy" in b and b.pk_enemy) or ("pk_enemy" in a and a.pk_enemy):
		return Camp.Relation.ENEMY
	var both_players := is_player(a) and is_player(b)
	var rel := Camp.relation(get_camp(a), get_camp(b), both_players)
	if rel == Camp.Relation.ENEMY and both_players:
		var a_can_pk: bool = get_camp(a) == Camp.Type.FREE or ("pk_enabled" in a and a.pk_enabled)
		if not a_can_pk:
			return Camp.Relation.NONE
	return rel

static func is_hostile(a: Node, b: Node) -> bool:
	return get_relation(a, b) == Camp.Relation.ENEMY

## Đồng đội = cùng màu (và chính mình).
static func is_ally(a: Node, b: Node) -> bool:
	return get_relation(a, b) == Camp.Relation.ALLY

## Mọi nhân vật còn sống trong bán kính `radius` quanh `center`, lọc theo quan hệ với `relative_to`.
static func find_in_radius(relative_to: Node, center: Vector2, radius: float, enemies: bool, allies: bool) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if relative_to == null or not relative_to.is_inside_tree():
		return out
	var seen := {}
	for group in COMBATANT_GROUPS:
		for node in relative_to.get_tree().get_nodes_in_group(group):
			if not (node is Node2D) or seen.has(node) or not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			seen[node] = true
			if node.global_position.distance_to(center) > radius:
				continue
			var rel := get_relation(relative_to, node)
			if (enemies and rel == Camp.Relation.ENEMY) or (allies and rel == Camp.Relation.ALLY):
				out.append(node)
	return out

## Áp 1 gói trạng thái (buff/bùa) lên 1 nhóm nhân vật — ai có StatusEffectController thì nhận.
static func apply_state_to(targets: Array[Node2D], source_id: String, payload: Dictionary, meta: Dictionary) -> void:
	for node in targets:
		var status: StatusEffectController = node.get_node_or_null("StatusEffectController")
		if status:
			status.apply_state(source_id, payload["attribs"], payload["seconds"], meta)

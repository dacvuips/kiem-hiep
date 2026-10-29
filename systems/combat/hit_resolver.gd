extends RefCounted
class_name HitResolver
## NƠI DUY NHẤT xử lý "1 bên tham chiến nhận 1 đòn" — tương đương KNpc::ReceiveDamage gốc. Player,
## quái và (sau này) người chơi khác khi online đều gọi hàm này trong take_damage_from() của mình,
## chỉ tự lo phần trừ máu/hiện số — không ai tự viết lại logic trúng/né/kháng/hiệu ứng riêng.
##
## Thứ tự đúng gốc: roll trúng/né -> damage từng loại (giáp, kháng, tương khắc, chí mạng) -> hiệu ứng
## (chậm/độc/choáng) -> phản đòn về người đánh -> hút máu cho người đánh.

const MISSED := -1

## Trả về damage cuối cùng (>= 0), hoặc MISSED nếu trượt/không gây được damage. Đòn chỉ mang trạng thái
## (bùa) trả về 0 sau khi áp trạng thái.
static func receive(defender: Node, defender_stats: CombatantStats, defender_hp: int,
		attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: CombatFormulas.DamageType, attacker_element: ElementTypes.ElementType,
		mods: CombatFormulas.HitModifiers = null) -> int:
	var status: StatusEffectController = defender.get_node_or_null("StatusEffectController")
	if mods and mods.is_state_only:
		_apply_hit_state(defender, status, mods)
		return 0

	var ignore_def: int = attacker_stats.ignore_defense_p if attacker_stats else 0
	if mods and "ignore_defense_percent" in mods and mods.ignore_defense_percent > 0:
		ignore_def = maxi(ignore_def, mods.ignore_defense_percent)
	if (mods == null or mods.use_attack_rating) and not CombatFormulas.roll_hit(attacker_stats.attack_rating, defender_stats.defense, ignore_def):
		return MISSED

	if mods and is_player_like(defender) and is_player_like(mods.attacker_node):
		mods.is_pk = true
	var parts := mods.extra_damages.duplicate() if mods else {}
	var main_part: Vector2i = parts.get(damage_type, Vector2i.ZERO)
	parts[damage_type] = main_part + Vector2i(min_damage, max_damage)
	parts = CombatFormulas.apply_server_damage_scaling(parts, int(attacker_element))
	var dealt := {}
	var mana_absorbed_box := [0]
	var defender_mana := int(defender.mana) if (defender != null and "mana" in defender) else 0
	var final_damage := CombatFormulas.resolve_multi_damage(attacker_stats, defender_stats, defender_hp,
			parts, attacker_element, mods, dealt, defender_mana, mana_absorbed_box)
	## Trúng nhưng giáp / kháng nuốt hết sát thương: KNpc::CalcDamage gốc trả FALSE, ReceiveDamage vẫn coi là trúng (không hiện
	## "trượt") — chỉ không mất máu. "Trượt" chỉ khi CheckHitTarget roll trượt (ở trên).
	if final_damage < 0:
		return 0

	if mana_absorbed_box[0] > 0 and defender != null and "mana" in defender:
		defender.mana = maxf(0.0, defender.mana - mana_absorbed_box[0])

	if defender_stats and defender_stats.damage_to_mana_p > 0 and final_damage > 0 and defender != null and "mana" in defender:
		var mana_gained: float = final_damage * defender_stats.damage_to_mana_p / 100.0
		var max_m: float = float(defender_stats.max_mana)
		defender.mana = minf(max_m, defender.mana + mana_gained)

	if status:
		status.apply_vltk_hit(mods, dealt, defender_stats)
	if mods and mods.state_source_id != "":
		_apply_hit_state(defender, status, mods)
	_apply_return_and_steal(defender_stats, attacker_stats, final_damage, dealt, mods)
	return final_damage

## Nhân vật người chơi (mình / người khác online / bot PK) — dùng cho hệ số sát thương PK (CombatFormulas.PK_DAMAGE_RATE_PERCENT).
static func is_player_like(node: Node) -> bool:
	return node != null and is_instance_valid(node) and (node.is_in_group("player") or node.is_in_group("other_players") or node is PkBot)

## Trạng thái đạn mang theo (bùa): có bán kính thì áp cho MỌI kẻ địch của người bắn trong vùng quanh chỗ
## trúng (KMissle::ProcessCollision gốc quét vùng), không thì chỉ mục tiêu trúng.
static func _apply_hit_state(defender: Node, status: StatusEffectController, mods: CombatFormulas.HitModifiers) -> void:
	if mods.state_source_id == "":
		return
	var payload := {"attribs": mods.state_attribs, "seconds": mods.state_seconds}
	var attacker := mods.attacker_node
	if mods.state_radius > 0.0 and attacker != null and is_instance_valid(attacker) and defender is Node2D:
		var targets := CombatTargeting.find_in_radius(attacker, defender.global_position, mods.state_radius, true, false)
		CombatTargeting.apply_state_to(targets, mods.state_source_id, payload, mods.state_meta)
	elif status:
		status.apply_state(mods.state_source_id, mods.state_attribs, mods.state_seconds, mods.state_meta)

## Phản đòn (meleedamagereturn/rangedamagereturn của BÊN BỊ ĐÁNH) và hút máu (steallife của NGƯỜI
## ĐÁNH, chỉ trên phần damage vật lý — CalcDamage gốc chỉ truyền nStolen_Life cho damage_physics).
static func _apply_return_and_steal(defender_stats: CombatantStats, attacker_stats: CombatantStats,
		final_damage: int, dealt: Dictionary, mods: CombatFormulas.HitModifiers) -> void:
	if mods == null or mods.attacker_node == null or not is_instance_valid(mods.attacker_node):
		return
	var attacker := mods.attacker_node
	var returned := 0
	if mods.is_melee:
		returned = final_damage * defender_stats.melee_damage_return_p / 100 + defender_stats.melee_damage_return
	else:
		returned = final_damage * defender_stats.range_damage_return_p / 100 + defender_stats.range_damage_return
	if returned > 0 and attacker.has_method("take_status_damage"):
		attacker.take_status_damage(float(returned), "damage_return")
	var stolen: int = dealt.get(CombatFormulas.DamageType.PHYSICS, 0) * attacker_stats.steal_life_p / 100
	if stolen > 0 and attacker.has_method("heal"):
		attacker.heal(float(stolen))

class_name SurvivorCombatAgent
extends Node
## COMPONENT THI TRIỂN KỸ NĂNG TỰ ĐỘNG CHO CHẾ ĐỘ OFFLINE SURVIVOR
##
## Chỉ được tạo và gắn vào Player khi chơi Offline Vượt Ải (STAGE / survivor_mode).
## Hỗ trợ thi triển đồng thời / độc lập toàn bộ các kỹ năng đã học (2, 3... skill đánh).

var _player: CharacterBody2D
var _skill_controller: SectSkillController

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player and "skill_controller" in _player:
		_skill_controller = _player.skill_controller
		## Survivor ra mọi chiêu cùng lúc, mỗi chiêu hồi độc lập (tối thiểu 0.6s bên dưới) -> không khoá động tác kiểu VLTK.
		if _skill_controller != null:
			_skill_controller.use_action_lock = false

func _process(_delta: float) -> void:
	if not GameModeManager.is_offline() or (GameManager.game_mode != GameManager.GameMode.STAGE and not (GameManager.field_map != null and GameManager.field_map.get("survivor_mode", false) == true)):
		return
	if _player == null or _skill_controller == null:
		return
	if _player.get("_dead") or _player.get("_is_jumping"):
		return
	var status_ctrl = _player.get("status_controller")
	if status_ctrl and status_ctrl.is_stunned:
		return

	cast_all_ready_skills()

## Thi triển tất cả kỹ năng tấn công / hỗ trợ đã học theo số lượng skill đang có
func cast_all_ready_skills() -> void:
	if _player == null or _skill_controller == null:
		return
	var skills_dict: Dictionary = SurvivorManager.active_skills if not SurvivorManager.active_skills.is_empty() else PlayerStats.survivor_skills
	if skills_dict.is_empty():
		return

	var used_targets: Array[Node2D] = []
	var cast_any := false

	for s_id in skills_dict.keys():
		var skill := _resolve_skill(str(s_id))
		if skill == null:
			continue

		# 1. Hào quang (Aura): Bật duy trì
		if skill.is_aura:
			if not _skill_controller.is_aura_active(skill):
				_skill_controller._try_cast(skill, _player, null)
			continue

		# 2. Buff bản thân: Ra lại khi hết buff
		if SectSkillController.is_self_buff(skill):
			var status_ctrl = _player.get("status_controller")
			if status_ctrl and not status_ctrl.has_state(skill.id):
				_skill_controller._try_cast(skill, _player, null)
			continue

		# 3. Kỹ năng tấn công: Kiểm tra hồi chiêu độc lập từng skill
		if _skill_controller._cooldowns.get(skill.id, 0.0) > 0.0:
			continue

		var range_px: float = _player.get_skill_radius(skill) if _player.has_method("get_skill_radius") else 200.0
		var target := _find_target_for_skill(range_px, used_targets)
		if target == null:
			continue

		# Quay mặt về hướng mục tiêu của chiêu này
		if _player.has_method("update_facing"):
			_player.update_facing(target.global_position - _player.global_position)

		# Thi triển chiêu thức độc lập
		if _skill_controller._try_cast(skill, _player, target):
			used_targets.append(target)
			cast_any = true

			# Survivor Perk: Đòn đánh nối tiếp (Combo Cast)
			var combo_chance := SurvivorPerks.get_combo_cast_chance()
			if combo_chance > 0.0 and randf() < combo_chance:
				_schedule_combo_cast(skill, target)

			# Đảm bảo nhịp hồi chiêu độc lập hợp lý trong chế độ Survivor (tối thiểu 0.6s)
			var min_cd := 0.6 / maxf(0.1, PlayerStats.attack_speed_multiplier)
			if _skill_controller._cooldowns.get(skill.id, 0.0) < min_cd:
				_skill_controller._cooldowns[skill.id] = min_cd
				_skill_controller._cooldown_totals[skill.id] = min_cd

	if cast_any and _player.has_method("play_cast"):
		if not _player.get("is_casting") and not _player.get("is_attacking"):
			_player.play_cast()

func _schedule_combo_cast(skill: SkillDefinition, target: Node2D) -> void:
	await get_tree().create_timer(0.15).timeout
	if is_inside_tree() and _player and not _player.get("_dead") and _skill_controller:
		var valid_target := target if is_instance_valid(target) and not (target.has_method("is_dead") and target.is_dead()) else null
		_skill_controller._try_cast(skill, _player, valid_target)

func _resolve_skill(skill_id: String) -> SkillDefinition:
	var skill := _skill_controller.get_skill(skill_id)
	if skill != null:
		return skill
	if _skill_controller.sect != null:
		for s in _skill_controller.sect.skills:
			if s != null and s.id == skill_id:
				return s
	for sc in SectRegistry.load_all():
		for s in sc.skills:
			if s != null and s.id == skill_id:
				return s
	return null

func _find_target_for_skill(radius: float, exclude_targets: Array[Node2D]) -> Node2D:
	if _player == null or not is_instance_valid(_player):
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var enemies := tree.get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	var max_sq := radius * radius
	var p_pos := _player.global_position

	# Ưu tiên tìm quái trong tầm chưa bị chiêu trước nhắm vào
	var best_unused: Node2D = null
	var best_unused_sq: float = INF
	var best_any: Node2D = null
	var best_any_sq: float = INF

	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if "_state" in e and e._state == 4: # DEAD
			continue
		var d: Vector2 = e.global_position - p_pos
		var dist_sq := d.x * d.x + d.y * d.y * 4.0
		if dist_sq <= max_sq:
			if dist_sq < best_any_sq:
				best_any_sq = dist_sq
				best_any = e
			if not (e in exclude_targets) and dist_sq < best_unused_sq:
				best_unused_sq = dist_sq
				best_unused = e

	return best_unused if best_unused != null else best_any

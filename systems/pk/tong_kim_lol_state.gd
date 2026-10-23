extends RefCounted
class_name TongKimLolState
## Quản lý tiến trình trong trận Tống Kim LOL (Cấp 1-15, EXP, Vàng, Kỹ năng, Tiềm năng)

signal level_changed(new_level: int)
signal exp_changed(current_exp: float, exp_to_next: float)
signal gold_changed(new_gold: int)
signal skill_points_changed(points: int)

var match_level: int = 1
var current_match_exp: float = 0.0
var exp_to_next: float = 300.0
var total_exp_earned: float = 0.0

var match_gold: int = 100
var team_side: String = "song" ## "song" hoặc "jin"

var _saved_profile_dict: Dictionary = {}
var _active_buffs: Dictionary = {} ## buff_id -> time_left

static var current: TongKimLolState = null

static func instance() -> TongKimLolState:
	if current == null:
		current = TongKimLolState.new()
	return current

## Khởi tạo trạng thái khi bắt đầu bước vào trận Tống Kim LOL
func init_match(side: String) -> void:
	current = self
	team_side = side
	match_level = TongKimLolRules.MIN_MATCH_LEVEL
	current_match_exp = 0.0
	total_exp_earned = 0.0
	exp_to_next = TongKimLolRules.exp_to_next_level(match_level)
	match_gold = 100
	_active_buffs.clear()

	var profile := GameManager.local_profile
	if profile == null:
		return

	# Lưu snapshot hồ sơ nhân vật gốc trước khi vào trận
	_saved_profile_dict = profile.to_dict()

	# 1. Tặng 100 điểm tiềm năng
	profile.potential_points += TongKimLolRules.INITIAL_POTENTIAL_POINTS

	# 2. Reset điểm kỹ năng về 0
	profile.skill_points = 0

	# 3. Mở khóa full skill môn phái
	var sect := SectRegistry.get_by_id(profile.sect_id)
	if sect:
		for skill in sect.skills:
			var sid := skill.id
			if TongKimLolRules.is_high_tier_skill(skill):
				# Kỹ năng 9x, 150, 180 chỉ cho tối đa 5 điểm ban đầu
				var cur_lv: int = profile.skill_levels.get(sid, 0)
				profile.skill_levels[sid] = mini(cur_lv, TongKimLolRules.MAX_HIGH_SKILL_INITIAL)
			else:
				# Các kỹ năng cơ bản mở khóa tối thiểu cấp 1 để dùng được
				if not profile.skill_levels.has(sid) or profile.skill_levels[sid] <= 0:
					profile.skill_levels[sid] = 1

	_apply_name_tag()

## Thêm kinh nghiệm trong trận
func add_match_exp(amount: float) -> void:
	current_match_exp += amount
	total_exp_earned += amount
	while current_match_exp >= exp_to_next and match_level < TongKimLolRules.MAX_MATCH_LEVEL:
		current_match_exp -= exp_to_next
		_level_up()
	exp_changed.emit(current_match_exp, exp_to_next)

func _level_up() -> void:
	match_level += 1
	exp_to_next = TongKimLolRules.exp_to_next_level(match_level)

	var profile := GameManager.local_profile
	if profile:
		# Lên cấp trong trận: Nhận 1 điểm kỹ năng
		profile.skill_points += 1
		skill_points_changed.emit(profile.skill_points)

	_apply_name_tag()
	level_changed.emit(match_level)

## Thêm hoặc trừ vàng trong trận
func add_gold(amount: int) -> void:
	match_gold = maxi(0, match_gold + amount)
	gold_changed.emit(match_gold)

func spend_gold(amount: int) -> bool:
	if match_gold < amount:
		return false
	match_gold -= amount
	gold_changed.emit(match_gold)
	return true

## Cộng điểm kỹ năng trong trận (CHỈ cho phép cộng vào skill 9x, 150, 180)
func allocate_match_skill(skill: SkillDefinition) -> bool:
	var profile := GameManager.local_profile
	if profile == null or profile.skill_points <= 0 or skill == null:
		return false

	if not TongKimLolRules.is_high_tier_skill(skill):
		# Không phải skill 9x, 150, 180 -> không cho cộng
		return false

	var cur: int = profile.skill_levels.get(skill.id, 0)
	if cur >= skill.max_level:
		return false

	profile.skill_levels[skill.id] = cur + 1
	profile.skill_points -= 1
	skill_points_changed.emit(profile.skill_points)
	return true

## Cập nhật nhãn cấp độ [Cấp X] lên trên đầu người chơi
func _apply_name_tag() -> void:
	var player: Node = Engine.get_main_loop().root.get_tree().get_first_node_in_group("player") if Engine.get_main_loop() else null
	if player and player.has_method("set_match_level_tag"):
		player.set_match_level_tag(match_level, team_side)

## Áp dụng hiệu ứng từ cửa hàng trong trận
func apply_shop_item(item: Dictionary) -> bool:
	var cost: int = int(item.get("price", 0))
	if not spend_gold(cost):
		return false

	var type: String = str(item.get("type", ""))
	var player: Node = Engine.get_main_loop().root.get_tree().get_first_node_in_group("player") if Engine.get_main_loop() else null

	match type:
		"speed":
			# Tăng tốc chạy tạm thời
			_active_buffs["speed"] = float(item.get("duration", 20.0))
			if player and "status_controller" in player and player.status_controller and player.status_controller.has_method("apply_speed_buff"):
				player.status_controller.apply_speed_buff(float(item.get("value", 0.4)), float(item.get("duration", 20.0)))
			elif player and player.has_method("apply_speed_buff"):
				player.apply_speed_buff(float(item.get("value", 0.4)), float(item.get("duration", 20.0)))
		"heal_instant":
			if player and player.has_method("heal"):
				player.heal(float(item.get("value", 1500)))
		"heal_hot":
			if player and player.has_method("apply_hot"):
				player.apply_hot(float(item.get("value", 3000)), float(item.get("duration", 10.0)))
			elif player and player.has_method("heal"):
				player.heal(float(item.get("value", 3000)))
		"damage_buff":
			_active_buffs["damage"] = float(item.get("duration", 30.0))
			PlayerStats.damage_multiplier += float(item.get("value", 0.25))
		"armor_buff":
			_active_buffs["armor"] = float(item.get("duration", 30.0))

	return true

## Kết thúc trận đấu: Phục hồi hồ sơ và trao thưởng EXP x10
func finish_and_reward() -> int:
	var profile := GameManager.local_profile
	var real_exp_reward := int(total_exp_earned * TongKimLolRules.END_EXP_REWARD_MULT)

	if profile and not _saved_profile_dict.is_empty():
		# Khôi phục trạng thái điểm kỹ năng & tiềm năng gốc
		profile.potential_points = int(_saved_profile_dict.get("potential_points", profile.potential_points))
		profile.skill_points = int(_saved_profile_dict.get("skill_points", profile.skill_points))
		profile.skill_levels = (_saved_profile_dict.get("skill_levels", {}) as Dictionary).duplicate()

		# Trao thưởng EXP thực tế (x10 EXP trong trận)
		profile.add_exp(real_exp_reward)

	current = null
	return real_exp_reward

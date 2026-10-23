extends Node

signal leveled_up(new_level: int)
signal exp_changed(current_exp: float, exp_to_next_level: float)
signal upgrade_applied(upgrade: UpgradeData)
signal stats_reset
signal shield_changed(current: float, maximum: float)
signal rerolls_changed(remaining: int)

var level: int = 1
var current_exp: float = 0.0
var exp_to_next_level: float = 500.0  ## Mốc 1x: x5 (Cấp 1 cần 500.0)

## Gói 1: Chỉ số Kiếm Hiệp cơ bản
var damage_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var range_multiplier: float = 1.0
var extra_projectile_count: int = 0
var move_speed_multiplier: float = 1.0
var hp_regen_percent: float = 0.0          ## % HP hồi mỗi giây (0.015 = 1.5%/s)
var crit_chance: float = 0.0               ## Tỉ lệ bạo kích cộng thêm (0.10 = +10%)
var max_shield: float = 0.0                ## Khiên chân khí tối đa
var current_shield: float = 0.0            ## Khiên chân khí hiện tại
var shield_recharge_delay: float = 8.0     ## Thời gian không dính đòn để hồi khiên (giây)
var shield_timer: float = 0.0
var pickup_radius: float = 80.0            ## Bán kính hút ngọc (px)

## Gói 2: Hiệu ứng Ngũ Hành & On-hit
var freeze_frames: int = 0                 ## Số frame làm chậm mục tiêu (36 frame = 2 giây)
var stun_chance_p: int = 0                 ## % tỉ lệ gây choáng
var stun_frames: int = 0                   ## Số frame choáng
var poison_damage: int = 0                 ## Sát thương độc rút mỗi nhịp
var poison_time_frames: int = 0            ## Thời gian nhiễm độc
var explosion_on_kill_chance: float = 0.0  ## Tỉ lệ quái phát nổ khi chết
var explosion_damage_ratio: float = 0.6    ## Hệ số sát thương vụ nổ theo người chơi
var explosion_radius: float = 130.0        ## Bán kính vụ nổ (px)

## Gói 3: Tiện ích Roguelike
var rerolls_remaining: int = 2             ## Số lượt đổi bài trong trận

var applied_upgrade_ids: Array[String] = []

func add_exp(amount: float) -> void:
	current_exp += amount
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		level_up()
	exp_changed.emit(current_exp, exp_to_next_level)

func level_up() -> void:
	level += 1
	exp_to_next_level = calculate_exp_for_next_level()
	leveled_up.emit(level)

## Tính hệ số nhân exp theo mốc cấp: 1x -> x5, 2x -> x10, 3x -> x15, 4x -> x20...
static func get_tier_exp_multiplier(lvl: int) -> float:
	var tier := int((maxi(1, lvl) - 1) / 10) + 1
	return float(tier * 5)

## Lượng exp cần để lên cấp tiếp theo trong ải "Khiêu chiến sơn môn":
## Cấp 1x (1-10) nhân 5, 2x (11-20) nhân 10, 3x (21-30) nhân 15...
static func calculate_exp_for_level(lvl: int) -> float:
	var base := 100.0 + (maxi(1, lvl) - 1) * 20.0
	var mult := get_tier_exp_multiplier(lvl)
	return base * mult

func calculate_exp_for_next_level() -> float:
	return calculate_exp_for_level(level)

func apply_upgrade(upgrade: UpgradeData) -> void:
	applied_upgrade_ids.append(upgrade.id)
	match upgrade.stat_type:
		UpgradeData.StatType.DAMAGE:
			damage_multiplier += upgrade.value
		UpgradeData.StatType.ATTACK_SPEED:
			attack_speed_multiplier += upgrade.value
		UpgradeData.StatType.RANGE:
			range_multiplier += upgrade.value
		UpgradeData.StatType.MOVE_SPEED:
			move_speed_multiplier += upgrade.value
		UpgradeData.StatType.HP_REGEN:
			hp_regen_percent += upgrade.value
		UpgradeData.StatType.CRIT_CHANCE:
			crit_chance += upgrade.value
		UpgradeData.StatType.SHIELD:
			max_shield += upgrade.value
			current_shield = max_shield
			shield_changed.emit(current_shield, max_shield)
		UpgradeData.StatType.PICKUP_RADIUS:
			pickup_radius += upgrade.value
		UpgradeData.StatType.FREEZE_ON_HIT:
			freeze_frames = maxi(freeze_frames, int(upgrade.value))
		UpgradeData.StatType.STUN_ON_HIT:
			stun_chance_p = maxi(stun_chance_p, int(upgrade.value))
			stun_frames = maxi(stun_frames, 24)
		UpgradeData.StatType.POISON_ON_HIT:
			poison_damage += int(upgrade.value)
			poison_time_frames = maxi(poison_time_frames, 90)
		UpgradeData.StatType.EXPLODE_ON_KILL:
			explosion_on_kill_chance = clampf(explosion_on_kill_chance + upgrade.value, 0.0, 1.0)
		UpgradeData.StatType.EMERGENCY_HEAL:
			_apply_emergency_heal()
		UpgradeData.StatType.PROJECTILE_COUNT:
			# Đã bỏ chức năng tăng x2 lượng đạn khi lên cấp
			pass
	upgrade_applied.emit(upgrade)

func _apply_emergency_heal() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		if player.has_method("heal"):
			player.heal(player.max_health * 0.5)
		# Đẩy lùi quái vật xung quanh
		var enemies := tree.get_nodes_in_group("enemies")
		for e in enemies:
			if e != null and is_instance_valid(e) and e is Node2D:
				var dist: float = player.global_position.distance_to(e.global_position)
				if dist < 350.0 and dist > 0.0:
					var push_dir: Vector2 = (e.global_position - player.global_position).normalized()
					e.global_position += push_dir * minf(160.0, 350.0 - dist)
		if player.has_method("notify"):
			player.notify("★ Cứu Nguy Khẩn Cấp: Đã hồi phục 50% HP và đẩy lùi quái vật!")

## Reset toàn bộ chỉ số và nâng cấp tạm thời của màn chơi về mặc định ban đầu:
func reset() -> void:
	level = 1
	current_exp = 0.0
	exp_to_next_level = calculate_exp_for_level(1)
	damage_multiplier = 1.0
	attack_speed_multiplier = 1.0
	range_multiplier = 1.0
	extra_projectile_count = 0
	move_speed_multiplier = 1.0
	hp_regen_percent = 0.0
	crit_chance = 0.0
	max_shield = 0.0
	current_shield = 0.0
	shield_timer = 0.0
	pickup_radius = 80.0
	freeze_frames = 0
	stun_chance_p = 0
	stun_frames = 0
	poison_damage = 0
	poison_time_frames = 0
	explosion_on_kill_chance = 0.0
	explosion_damage_ratio = 0.6
	explosion_radius = 130.0
	rerolls_remaining = 2
	applied_upgrade_ids.clear()
	stats_reset.emit()
	exp_changed.emit(current_exp, exp_to_next_level)
	shield_changed.emit(current_shield, max_shield)
	rerolls_changed.emit(rerolls_remaining)

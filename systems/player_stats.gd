extends Node

signal leveled_up(new_level: int)
signal exp_changed(current_exp: float, exp_to_next_level: float)
signal upgrade_applied(upgrade: UpgradeData)

var level: int = 1
var current_exp: float = 0.0
var exp_to_next_level: float = 10.0

## Chỉ số cộng dồn từ các lần chọn nâng cấp — mọi nơi cần đọc damage/speed/... nên hỏi qua đây
var damage_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var range_multiplier: float = 1.0
var extra_projectile_count: int = 0

var applied_upgrade_ids: Array[String] = []

func add_exp(amount: float) -> void:
	current_exp += amount
	exp_changed.emit(current_exp, exp_to_next_level)
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		level_up()

func level_up() -> void:
	level += 1
	exp_to_next_level = calculate_exp_for_next_level()
	leveled_up.emit(level)

func calculate_exp_for_next_level() -> float:
	return 10.0 + (level - 1) * 5.0

func apply_upgrade(upgrade: UpgradeData) -> void:
	applied_upgrade_ids.append(upgrade.id)
	match upgrade.stat_type:
		UpgradeData.StatType.DAMAGE:
			damage_multiplier += upgrade.value
		UpgradeData.StatType.ATTACK_SPEED:
			attack_speed_multiplier += upgrade.value
		UpgradeData.StatType.RANGE:
			range_multiplier += upgrade.value
		UpgradeData.StatType.PROJECTILE_COUNT:
			extra_projectile_count += int(upgrade.value)
			damage_multiplier *= 0.9
	upgrade_applied.emit(upgrade)

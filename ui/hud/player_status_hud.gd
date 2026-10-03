extends Control
class_name PlayerStatusHud
## Khung trạng thái góc trên trái màn đánh quái (kiểu VLTK): tên + cấp, thanh Sinh lực, thanh Nội lực.
## Bố cục/màu chỉnh trong PlayerStatusHud.tscn; script chỉ đổ số liệu.
##
## Sinh lực cập nhật theo tín hiệu player.health_changed. Nội lực: game chưa tiêu hao nội lực (chiêu chỉ có hồi
## chiêu) nên luôn đầy = Nội lực tối đa theo chỉ số (cập nhật khi đổi trang bị/buff).

var _player: Node

func setup(player: Node) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	var profile := GameManager.local_profile
	(%NameLabel as Label).text = profile.display_name if profile else ""
	refresh()

func refresh() -> void:
	if is_instance_valid(_player):
		_on_health_changed(_player.health, _player.max_health)

## Mỗi lần máu đổi (kể cả khi dựng lại chỉ số sau lên cấp/đổi đồ) đọc lại luôn cấp + nội lực tối đa — rẻ.
func _on_health_changed(health: float, max_health: float) -> void:
	_set_bar(%HealthBar, %HealthValue, health, max_health)
	var profile := GameManager.local_profile
	(%LevelLabel as Label).text = "Cấp %d" % (profile.level if profile else 1)
	var max_mana: int = _player.combat_stats.max_mana if _player.combat_stats else 0
	_set_bar(%ManaBar, %ManaValue, max_mana, max_mana)

func _set_bar(bar: ProgressBar, label: Label, value: float, max_value: float) -> void:
	bar.max_value = maxf(max_value, 1.0)
	bar.value = clampf(value, 0.0, bar.max_value)
	label.text = "%d/%d" % [ceili(maxf(value, 0.0)), int(max_value)]

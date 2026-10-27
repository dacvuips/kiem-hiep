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
	if player.has_signal("mana_changed"):
		player.mana_changed.connect(_on_mana_changed)
	var profile := GameManager.local_profile
	(%NameLabel as Label).text = profile.display_name if profile else ""
	## Buff/bùa/hào quang của người chơi hiện ngay dưới thanh máu + nội lực (không còn hiện trên đầu nhân vật).
	var icons := StateIconBar.new()
	%ManaBar.get_parent().add_child(icons)
	icons.setup(player)
	## Tên/cấp/thanh máu/nội lực đã chuyển lên TopStatusBar (giữa trên màn hình, kiểu VLTK) — khung này chỉ còn hàng biểu tượng buff.
	%NameLabel.get_parent().visible = false
	%HealthBar.visible = false
	%ManaBar.visible = false
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	refresh()

func refresh() -> void:
	if is_instance_valid(_player):
		_on_health_changed(_player.health, _player.max_health)
		if "mana" in _player and "max_mana" in _player:
			_on_mana_changed(_player.mana, _player.max_mana)

## Mỗi lần máu đổi (kể cả khi dựng lại chỉ số sau lên cấp/đổi đồ) đọc lại luôn cấp + nội lực tối đa — rẻ.
func _on_health_changed(health: float, max_health: float) -> void:
	_set_bar(%HealthBar, %HealthValue, health, max_health)
	var profile := GameManager.local_profile
	(%LevelLabel as Label).text = "Cấp %d" % (profile.level if profile else 1)
	var max_mana: float = _player.max_mana if ("max_mana" in _player and _player.max_mana > 0.0) else (float(_player.combat_stats.max_mana) if _player.combat_stats else 0.0)
	var cur_mana: float = _player.mana if "mana" in _player else max_mana
	_set_bar(%ManaBar, %ManaValue, cur_mana, max_mana)

func _on_mana_changed(mana: float, max_mana: float) -> void:
	_set_bar(%ManaBar, %ManaValue, mana, max_mana)

func _set_bar(bar: ProgressBar, label: Label, value: float, max_value: float) -> void:
	bar.max_value = maxf(max_value, 1.0)
	bar.value = clampf(value, 0.0, bar.max_value)
	label.text = "%d/%d" % [ceili(maxf(value, 0.0)), int(max_value)]

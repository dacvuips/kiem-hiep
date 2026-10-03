extends Node2D

## Nếu true, màu thanh máu đổi theo % HP còn lại (xanh -> vàng -> đỏ) thay vì màu đỏ cố định
@export var use_gradient_color: bool = false

@onready var bar: ProgressBar = $Bar

var fill_style: StyleBoxFlat

func _ready() -> void:
	fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color.GREEN if use_gradient_color else Color.RED
	bar.add_theme_stylebox_override("fill", fill_style)

func set_max_health(value: float) -> void:
	bar.max_value = value
	bar.value = value
	_update_color()

func set_health(value: float) -> void:
	bar.value = value
	_update_color()

func _update_color() -> void:
	if not use_gradient_color or bar.max_value <= 0:
		return
	var ratio := bar.value / bar.max_value
	if ratio > 0.5:
		fill_style.bg_color = Color.GREEN.lerp(Color.YELLOW, (1.0 - ratio) * 2.0)
	else:
		fill_style.bg_color = Color.YELLOW.lerp(Color.RED, (0.5 - ratio) * 2.0)

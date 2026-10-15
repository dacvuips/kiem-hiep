extends Node2D

## Nếu true, màu thanh máu đổi theo % HP còn lại (xanh -> vàng -> đỏ) thay vì màu đỏ cố định
@export var use_gradient_color: bool = false
## > 0: đổi chiều rộng / chiều cao thanh (giữ tâm ngang và mép trên như HealthBar.tscn). 0 = giữ như scene.
@export var bar_width: float = 0.0
@export var bar_height: float = 0.0
## Bo tròn 2 đầu thanh (bán kính = nửa chiều cao).
@export var rounded: bool = false

@onready var bar: ProgressBar = $Bar

var fill_style: StyleBoxFlat

func _ready() -> void:
	fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color.GREEN if use_gradient_color else Color.RED
	if bar_width > 0.0:
		bar.offset_left = -bar_width * 0.5
		bar.offset_right = bar_width * 0.5
	if bar_height > 0.0:
		bar.offset_bottom = bar.offset_top + bar_height
	if rounded:
		var radius := int(ceilf((bar.offset_bottom - bar.offset_top) * 0.5))
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
		bg.set_corner_radius_all(radius)
		bar.add_theme_stylebox_override("background", bg)
		fill_style.set_corner_radius_all(radius)
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

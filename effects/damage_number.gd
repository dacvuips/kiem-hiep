extends Node2D

const FLOAT_DISTANCE = 1.0
const FLOAT_DURATION = 0.1

@onready var text: Label = $Text

func _ready() -> void:
	text.add_theme_color_override("font_color", Color.RED)
	text.add_theme_font_size_override("font_size", 20)
	text.add_theme_constant_override("outline_size", 6)
	text.add_theme_color_override("font_outline_color", Color.BLACK)

func _start_float() -> void:
	modulate.a = 1.0
	var target_y := position.y - FLOAT_DISTANCE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", target_y, FLOAT_DURATION).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, FLOAT_DURATION).set_delay(0.4)
	tween.chain().tween_callback(func(): ObjectPool.release(self))

func set_damage(amount: float) -> void:
	text.add_theme_color_override("font_color", Color.RED)
	text.text = str(int(amount))
	_start_float()

## Hiện "Miss" khi đòn tấn công bị né (CombatFormulas.roll_hit trả false) — VLTK gốc luôn có khả
## năng né đòn (AttackRating vs Defense), khác hẳn damage cố định-luôn-trúng của bản cũ.
func set_miss() -> void:
	text.add_theme_color_override("font_color", Color.WHITE)
	text.text = "Miss"
	_start_float()

extends Area2D
class_name ThuThanhCoin

## ĐỒNG XU RƠI TRÊN CHIẾN TRƯỜNG THỦ THÀNH (PLANTS VS ZOMBIES JX1)
## Xuất hiện khi quái bị hạ gục. Người chơi phải bấm / chạm trực tiếp để nhặt.

signal collected(amount: int)

var amount: int = 25
var target_ui_pos: Vector2 = Vector2(1150, 40)
var _is_collected: bool = false
var _lifetime: float = 15.0
var _blink_timer: float = 0.0

var _sprite: Sprite2D
var _glow: Sprite2D
var _lbl: Label

func setup(p_amount: int, p_target_ui_pos: Vector2 = Vector2(1150, 40)) -> void:
	amount = p_amount
	target_ui_pos = p_target_ui_pos

func _ready() -> void:
	add_to_group("thu_thanh_coins")
	z_index = 25
	collision_layer = 0
	collision_mask = 0
	input_pickable = true

	# Hitbox va chạm để click/chạm
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	col.shape = circle
	add_child(col)

	# Vòng sáng hào quang
	_glow = Sprite2D.new()
	var glow_path := "res://assets/ui/bo_icon_nhan_vat/tai_nguyen/ico_vang.png"
	if ResourceLoader.exists(glow_path):
		_glow.texture = load(glow_path)
	_glow.scale = Vector2(1.5, 1.5)
	_glow.modulate = Color(1.0, 0.9, 0.2, 0.5)
	add_child(_glow)

	# Sprite đồng xu vàng
	_sprite = Sprite2D.new()
	var coin_path := "res://assets/ui/bo_icon_nhan_vat/tai_nguyen/ico_vang.png"
	if ResourceLoader.exists(coin_path):
		_sprite.texture = load(coin_path)
	_sprite.scale = Vector2(1.1, 1.1)
	add_child(_sprite)

	# Nút bấm trong suốt để người chơi click/chạm cực nhạy trên mọi nền tảng
	var btn := Button.new()
	btn.flat = true
	btn.position = Vector2(-26, -26)
	btn.size = Vector2(52, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(collect)
	add_child(btn)

	# Nhãn số tiền rơi (+25 Xu)
	_lbl = Label.new()
	_lbl.text = "+%d" % amount
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.position = Vector2(-25, -30)
	_lbl.size = Vector2(50, 20)
	_lbl.add_theme_font_size_override("font_size", 13)
	_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl.add_theme_constant_override("outline_size", 3)
	add_child(_lbl)

	# Hiệu ứng nảy lên lúc rơi (Spawn bounce) tại chỗ quái chết
	var spawn_tw := create_tween()
	var base_pos := position
	position.y -= 22.0
	spawn_tw.tween_property(self, "position:y", base_pos.y, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Tự động bay vào túi của người chơi sau khi rơi nảy nhẹ, không cần phải nhấp chuột
	spawn_tw.tween_interval(0.25)
	spawn_tw.tween_callback(collect)

	# Hiệu ứng lấp lánh (pulsing)
	var pulse_tw := create_tween().set_loops()
	pulse_tw.tween_property(_glow, "scale", Vector2(1.8, 1.8), 0.5).set_trans(Tween.TRANS_SINE)
	pulse_tw.parallel().tween_property(_glow, "modulate:a", 0.7, 0.5)
	pulse_tw.tween_property(_glow, "scale", Vector2(1.3, 1.3), 0.5).set_trans(Tween.TRANS_SINE)
	pulse_tw.parallel().tween_property(_glow, "modulate:a", 0.35, 0.5)

	input_event.connect(_on_input_event)

func _process(delta: float) -> void:
	if _is_collected:
		return

	_lifetime -= delta
	# Nhấp nháy khi sắp biến mất (còn 3 giây)
	if _lifetime <= 3.0:
		_blink_timer += delta
		visible = fmod(_blink_timer * 6.0, 1.0) > 0.35
		if _lifetime <= 0.0:
			queue_free()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_collected:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		collect()
	elif event is InputEventScreenTouch and event.pressed:
		collect()

func collect() -> void:
	if _is_collected:
		return
	_is_collected = true
	collected.emit(amount)

	# Hiệu ứng bay về phía khung Xu trên Top Bar
	var dest: Vector2 = target_ui_pos
	var vp := get_viewport()
	if vp != null:
		dest = vp.get_canvas_transform().affine_inverse() * target_ui_pos

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", dest, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.4, 0.4), 0.45)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(queue_free)

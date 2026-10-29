extends CharacterBody2D
class_name HonorPillar

## TRỤ DANH DỰ (LONG TRỤ CÔNG THÀNH CHIẾN LÂM AN)
## Tâm điểm phòng thủ trong ải "Bảo Vệ Trụ Danh Dự".
## Quái địch từ 4 cổng sẽ tiến vào đánh Trụ này. Nếu Trụ sụp đổ (HP <= 0), màn chơi thất bại.

signal health_changed(current_hp: float, max_hp: float)
signal destroyed

const DamageNumberScene := preload("res://effects/damage_number.tscn")

@export var max_health: float = 50000.0
var health: float = 50000.0
var is_destroyed: bool = false
var camp: int = Camp.Type.BEGIN

var _vltk_sprite: MonsterSprite = null
var _name_plate: Label = null
var _hp_bar: ProgressBar = null
var _aura_fx: Node2D = null

func _ready() -> void:
	add_to_group("allies")
	add_to_group("targetable_by_enemies")
	add_to_group("honor_pillar")
	
	health = max_health
	_setup_collision()
	_setup_visual()
	_setup_hud()

func _setup_collision() -> void:
	collision_layer = 1 | 4  # World & Hurtbox
	collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 48.0
	col.shape = shape
	col.position = Vector2(0, -10)
	add_child(col)

func _setup_visual() -> void:
	# Sử dụng sprite quái 530 (Thủ Long trụ nguyên - enemy191)
	var data := MonsterData.monster(530)
	var res_id: String = data.get("res", "enemy191")
	if ResourceLoader.exists("res://systems/monster/monster_sprite.gd"):
		var sprite_script: GDScript = load("res://systems/monster/monster_sprite.gd")
		if sprite_script != null:
			_vltk_sprite = sprite_script.new()
			_vltk_sprite.position = Vector2(0, 0)
			add_child(_vltk_sprite)
			_vltk_sprite.set_resource(res_id)
			_vltk_sprite.set_pose("stand", 0, 0.0)

	# Vòng hào quang phòng thủ dưới chân trụ
	_aura_fx = Node2D.new()
	_aura_fx.name = "DefenseAura"
	add_child(_aura_fx)
	_aura_fx.draw.connect(func() -> void:
		_aura_fx.draw_arc(Vector2.ZERO, 60.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.4), 3.0)
		_aura_fx.draw_arc(Vector2.ZERO, 72.0, 0, TAU, 32, Color(0.2, 0.8, 1.0, 0.25), 2.0)
	)
	_aura_fx.queue_redraw()

func _setup_hud() -> void:
	# Bảng tên trụ
	_name_plate = Label.new()
	_name_plate.text = "★ TRUNG TÂM LONG TRỤ ★"
	_name_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_plate.add_theme_font_size_override("font_size", 16)
	_name_plate.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_name_plate.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_plate.add_theme_constant_override("outline_size", 4)
	_name_plate.position = Vector2(-150, -180)
	_name_plate.custom_minimum_size = Vector2(300, 24)
	add_child(_name_plate)

	# Thanh máu trên đầu trụ
	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = max_health
	_hp_bar.value = health
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(160, 10)
	_hp_bar.position = Vector2(-80, -152)

	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style_bg.corner_radius_top_left = 3
	style_bg.corner_radius_top_right = 3
	style_bg.corner_radius_bottom_left = 3
	style_bg.corner_radius_bottom_right = 3
	_hp_bar.add_theme_stylebox_override("background", style_bg)

	var style_fill := StyleBoxFlat.new()
	style_fill.bg_color = Color(0.2, 0.85, 0.3)
	style_fill.corner_radius_top_left = 3
	style_fill.corner_radius_top_right = 3
	style_fill.corner_radius_bottom_left = 3
	style_fill.corner_radius_bottom_right = 3
	_hp_bar.add_theme_stylebox_override("fill", style_fill)

	add_child(_hp_bar)

func is_dead() -> bool:
	return is_destroyed

func heal(amount: float) -> void:
	if is_destroyed:
		return
	health = minf(max_health, health + amount)
	_update_hp_bar()
	health_changed.emit(health, max_health)

func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: int = 0, attacker_element: int = 0, mods: Variant = null) -> void:
	if is_destroyed:
		return
	var raw_dmg := float(randi_range(min_damage, max_damage))
	if raw_dmg <= 0.0:
		raw_dmg = 50.0
	# Trụ có phòng ngự tự nhiên giảm 35% sát thương
	var final_dmg := maxi(1, int(raw_dmg * 0.65))
	take_damage(float(final_dmg))

func take_damage(amount: float) -> void:
	if is_destroyed:
		return
	health = maxf(0.0, health - amount)
	_show_damage_number(amount)
	_update_hp_bar()
	health_changed.emit(health, max_health)

	if health <= 0.0:
		_on_destroyed()

func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.value = health
	var ratio := health / max_health
	var fill_style: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill")
	if fill_style:
		if ratio > 0.5:
			fill_style.bg_color = Color(0.2, 0.85, 0.3)
		elif ratio > 0.25:
			fill_style.bg_color = Color(0.95, 0.75, 0.1)
		else:
			fill_style.bg_color = Color(0.9, 0.2, 0.2)

func _show_damage_number(amount: float) -> void:
	if DamageNumberScene and get_parent() != null:
		var dmg_num = DamageNumberScene.instantiate()
		if dmg_num:
			dmg_num.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-140, -100))
			get_parent().add_child(dmg_num)
			if dmg_num.has_method("set_damage"):
				dmg_num.set_damage(amount)

func _on_destroyed() -> void:
	is_destroyed = true
	# Chuyển hình ảnh sang trụ vỡ (Thủ Long trụ vỡ - enemy192)
	if _vltk_sprite != null:
		_vltk_sprite.set_resource("enemy192")
		_vltk_sprite.set_pose("stand", 0, 0.0)

	if _name_plate != null:
		_name_plate.text = "★ LONG TRỤ ĐÃ BỊ PHÁ HỦY ★"
		_name_plate.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2))

	destroyed.emit()

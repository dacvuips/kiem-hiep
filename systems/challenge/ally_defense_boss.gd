extends CharacterBody2D
class_name AllyDefenseBoss

## BOSS ĐỒNG MINH THỦ TRỤ
## Người chơi mua từ Shop Chiến Trường để hỗ trợ phòng thủ Trụ Danh Dự.
## Đứng canh giữ quanh bục trung tâm, tiêu diệt quái địch và thu hút hỏa lực cho Trụ.

signal died(ally: AllyDefenseBoss)

const DamageNumberScene := preload("res://effects/damage_number.tscn")

var boss_type: String = ""
var boss_name: String = ""
var level: int = 100
var max_health: float = 25000.0
var health: float = 25000.0
var camp: int = Camp.Type.BEGIN
var speed: float = 90.0
var is_ally_boss: bool = true
var is_support_boss: bool = true
var combat_stats: CombatantStats = CombatantStats.new()

var _target: Node2D = null
var _pillar: HonorPillar = null
var _attack_cooldown: float = 0.0
var _skill_timer: float = 0.0
var _sprite: MonsterSprite = null
var _hp_bar: ProgressBar = null
var _name_label: Label = null
var _is_dead: bool = false
var _action: String = "stand"
var _anim_time: float = 0.0

func _play_anim(act: String) -> void:
	if _action != act:
		_action = act
		_anim_time = 0.0

func _update_sprite(delta: float) -> void:
	if _sprite == null:
		return
	_anim_time += delta
	var progress := fposmod(_anim_time * 1.5, 1.0)
	var dir := 0
	if velocity.length_squared() > 1.0:
		dir = VltkMath.dir_between(Vector2.ZERO, VltkMath.to_logic(velocity))
	_sprite.set_pose(_action, dir, progress)

func _ready() -> void:
	add_to_group("allies")
	add_to_group("targetable_by_enemies")
	add_to_group("ally_boss")
	add_to_group("support_boss")
	_setup_collision()
	_setup_visual()
	_setup_ui()

func setup(p_type: String, p_name: String, p_lvl: int, p_hp: float, pillar: HonorPillar) -> void:
	boss_type = p_type
	boss_name = p_name
	level = p_lvl
	max_health = p_hp
	health = p_hp
	_pillar = pillar
	if combat_stats != null:
		combat_stats.attack_rating = level * 100 + 2000
		combat_stats.defense = level * 50 + 1000
	if _name_label != null:
		_name_label.text = "[Đồng Minh] " + boss_name

func _setup_collision() -> void:
	collision_layer = 1 | 4
	collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 32.0
	col.shape = shape
	add_child(col)

func _setup_visual() -> void:
	var res_id := "ani001"
	match boss_type:
		"tanker":
			res_id = "ani005"  # Thiên Vương Thiết Kỵ
		"healer":
			res_id = "ani002"  # Nga Mi Thánh Nữ
		"trapper":
			res_id = "ani004"  # Đường Môn
		"sword":
			res_id = "ani003"  # Võ Đang
		"beast":
			res_id = "ani001"  # Thần Thú

	if ResourceLoader.exists("res://systems/monster/monster_sprite.gd"):
		var sprite_script: GDScript = load("res://systems/monster/monster_sprite.gd")
		if sprite_script != null:
			_sprite = sprite_script.new()
			add_child(_sprite)
			_sprite.set_resource(res_id)
			_sprite.set_pose("stand", 0, 0.0)

func _setup_ui() -> void:
	_name_label = Label.new()
	_name_label.text = "[Đồng Minh] " + boss_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	# Tên hiển thị màu Xanh Ngọc nổi bật khác biệt hoàn toàn với quái
	_name_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.7))
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.position = Vector2(-100, -80)
	_name_label.custom_minimum_size = Vector2(200, 20)
	add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = max_health
	_hp_bar.value = health
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(90, 8)
	_hp_bar.position = Vector2(-45, -58)

	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_bg.corner_radius_top_left = 2
	style_bg.corner_radius_top_right = 2
	style_bg.corner_radius_bottom_left = 2
	style_bg.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("background", style_bg)

	var style_fill := StyleBoxFlat.new()
	style_fill.bg_color = Color(0.2, 0.85, 0.5)
	style_fill.corner_radius_top_left = 2
	style_fill.corner_radius_top_right = 2
	style_fill.corner_radius_bottom_left = 2
	style_fill.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", style_fill)

	add_child(_hp_bar)

func is_dead() -> bool:
	return _is_dead

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_attack_cooldown -= delta
	_skill_timer -= delta
	_update_sprite(delta)

	# Kỹ năng đặc biệt của Healer (Nga Mi): Hồi máu cho Trụ và đồng minh xung quanh mỗi 5 giây
	if boss_type == "healer" and _skill_timer <= 0.0:
		_skill_timer = 5.0
		if _pillar != null and is_instance_valid(_pillar) and not _pillar.is_dead():
			_pillar.heal(1500.0)  # Hồi 3% máu cho Trụ (50.000 HP)
			_show_heal_effect()

	# Tìm kiếm quái gần nhất quanh trụ để tấn công
	if _target == null or not is_instance_valid(_target) or (_target.has_method("is_dead") and _target.is_dead()):
		_target = _find_nearest_enemy()

	if _target != null and is_instance_valid(_target):
		var dist := global_position.distance_to(_target.global_position)
		if dist > 80.0:
			var dir := (_target.global_position - global_position).normalized()
			velocity = dir * speed
			move_and_slide()
			_play_anim("walk")
		else:
			velocity = Vector2.ZERO
			if _attack_cooldown <= 0.0:
				_perform_attack(_target)
	else:
		# Quay về canh giữ gần trụ nếu không có quái
		if _pillar != null and is_instance_valid(_pillar):
			var dist_pillar := global_position.distance_to(_pillar.global_position)
			if dist_pillar > 250.0:
				var dir := (_pillar.global_position - global_position).normalized()
				velocity = dir * speed
				move_and_slide()
				_play_anim("walk")
			else:
				velocity = Vector2.ZERO
				_play_anim("stand")

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist := 600.0
	for e in enemies:
		if is_instance_valid(e) and not (e.has_method("is_dead") and e.is_dead()):
			var d: float = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest

func _perform_attack(foe: Node2D) -> void:
	_attack_cooldown = 1.2
	_play_anim("attack1")

	# Dame cơ bản giảm 20 lần theo tỉ lệ máu và sức mạnh mới
	var base_dmg := float(level * 250 + 2000) / 20.0
	match boss_type:
		"tanker":
			base_dmg *= 1.2
		"sword":
			base_dmg *= 2.5 # Sát thương khủng
		"trapper":
			base_dmg *= 1.5
		"beast":
			base_dmg *= 3.0

	var mods := CombatFormulas.HitModifiers.new()
	mods.attacker_node = self
	var atk_stats := combat_stats if combat_stats != null else CombatantStats.new()
	if foe.has_method("take_damage_from"):
		foe.take_damage_from(atk_stats, int(base_dmg * 0.9), int(base_dmg * 1.1), 0, 0, mods)
	elif foe.has_method("take_damage"):
		foe.take_damage(base_dmg, self)

	# Bẫy làm chậm của Đường Môn
	if boss_type == "trapper" and foe.get("status_controller") != null:
		var sc = foe.get("status_controller")
		if sc.has_method("apply_effect") and ResourceLoader.exists("res://systems/effects/status_effect.gd"):
			var se: RefCounted = load("res://systems/effects/status_effect.gd").new("slow", 3.0, 0.0, 1.0, 0.5)
			sc.apply_effect(se)

func _show_heal_effect() -> void:
	if DamageNumberScene and get_parent() != null:
		var num = DamageNumberScene.instantiate()
		if num:
			num.global_position = global_position + Vector2(0, -60)
			get_parent().add_child(num)
			if num.has_method("set_damage"):
				num.set_damage(1500.0)
				num.modulate = Color(0.2, 1.0, 0.4)

func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: int = 0, attacker_element: int = 0, mods: Variant = null) -> void:
	if _is_dead:
		return
	var raw_dmg := float(randi_range(min_damage, max_damage))
	if raw_dmg <= 0.0:
		raw_dmg = 100.0
	take_damage(raw_dmg)

func take_damage(amount: float, _attacker: Node = null) -> void:
	if _is_dead:
		return
	if boss_type == "tanker":
		amount *= 0.5
	health = maxf(0.0, health - amount)
	if _hp_bar != null:
		_hp_bar.value = health

	if DamageNumberScene and get_parent() != null:
		var dmg_num = DamageNumberScene.instantiate()
		if dmg_num:
			dmg_num.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-60, -40))
			get_parent().add_child(dmg_num)
			if dmg_num.has_method("set_damage"):
				dmg_num.set_damage(amount)

	if health <= 0.0:
		_is_dead = true
		_play_anim("die")
		died.emit(self)
		var t := get_tree().create_timer(1.5)
		t.timeout.connect(queue_free)

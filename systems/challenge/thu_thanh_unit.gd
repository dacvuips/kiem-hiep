extends CharacterBody2D
class_name ThuThanhUnit

## HIỆP KHÁCH PHÒNG THỦ TRÊN Ô BÀN CỜ (PLANTS VS ZOMBIES JX1)
## Đứng tại ô (grid_row, grid_col), tự động tấn công quái theo làn và bảo vệ chiến tuyến.

signal died(unit: Node2D)

const DamageNumberScene := preload("res://effects/damage_number.tscn")
const ThuThanhProjectileScript := preload("res://systems/challenge/thu_thanh_projectile.gd")
const ThuThanhSkillData := preload("res://systems/challenge/thu_thanh_skill_data.gd")
const DEFENSE_BOUNDARY_X: float = 120.0 + 11.0 * 96.0  ## 1176.0: Lằn ranh vạch vàng phòng thủ (11 cột x 96px)

var skill_data: Dictionary = {}
var grid_row: int = 0
var grid_col: int = 0
var max_hp: float = 400.0
var current_hp: float = 400.0
var damage: float = 40.0
var attack_interval: float = 1.4
var unit_type: int = ThuThanhSkillData.UnitType.LINE_PROJECTILE
var is_active: bool = true
var skill_level: int = 1

var _attack_timer: float = 0.0
var _anim_timer: float = 0.0
var _bomb_timer: float = 1.5
var _is_exploding: bool = false

var _avatar_node: Node2D
var _sprite: Sprite2D
var _aura: Sprite2D
var _hp_bar: ProgressBar
var _name_lbl: Label

func setup(data: Dictionary, row: int, col: int) -> void:
	skill_data = data
	grid_row = row
	grid_col = col

	unit_type = int(data.get("type", ThuThanhSkillData.UnitType.LINE_PROJECTILE))
	max_hp = float(data.get("hp", 400.0))
	current_hp = max_hp
	damage = float(data.get("damage", 40.0))
	attack_interval = float(data.get("attack_speed", 1.4))

func set_skill_level(p_level: int) -> void:
	skill_level = maxi(1, p_level)
	var sid := str(skill_data.get("id", ""))
	var scaling: Dictionary = ThuThanhSkillData.get_skill_scaling(sid, skill_level)
	var base_dmg: float = float(skill_data.get("damage", 40.0))
	damage = base_dmg * float(scaling.get("damage_mult", 1.0))
	if _name_lbl != null:
		var sect_str := str(skill_data.get("sect", skill_data.get("name", "Hiệp Khách")))
		if unit_type == ThuThanhSkillData.UnitType.CHEST_UTILITY:
			_name_lbl.text = "Quân Nhu"
		elif scaling.get("is_max", false):
			_name_lbl.text = "%s (MAX Lv.%d)" % [sect_str, skill_level]
			_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		else:
			_name_lbl.text = "%s (Lv.%d)" % [sect_str, skill_level]

func _ready() -> void:
	# Hiệp khách nằm trên ô bàn cờ (-50) nhưng dưới các công trình trên cao
	z_as_relative = false
	z_index = -15

	add_to_group("allies")
	add_to_group("thu_thanh_units")
	collision_layer = 1
	collision_mask = 0

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48.0, 70.0)
	col.shape = rect
	col.position = Vector2(0, -20)
	add_child(col)

	_setup_visual()
	_setup_ui()

	# Nếu là Rương Quân Nhu: Hồi máu ngay cho Xe Tống Kim
	if unit_type == ThuThanhSkillData.UnitType.CHEST_UTILITY:
		_apply_chest_utility()

func _setup_visual() -> void:
	var tint: Color = skill_data.get("avatar", {}).get("color", Color(1.0, 0.9, 0.4, 0.7))

	# Khởi tạo CharacterAvatar chuẩn VLTK
	var av_data: Dictionary = skill_data.get("avatar", {})
	const CharacterAvatarScript = preload("res://systems/avatar/character_avatar.gd")
	if CharacterAvatarScript != null and unit_type != ThuThanhSkillData.UnitType.CHEST_UTILITY:
		_avatar_node = CharacterAvatarScript.new()
		_avatar_node.gender = str(av_data.get("gender", "male"))
		var h := int(av_data.get("helm", -1))
		var a := int(av_data.get("armor", -1))
		var w := int(av_data.get("weapon", -1))
		var horse := int(av_data.get("horse", -1)) if bool(av_data.get("riding", false)) else -1
		_avatar_node.helm_res = h
		_avatar_node.armor_res = a
		_avatar_node.weapon_res = w
		_avatar_node.horse_res = horse
		add_child(_avatar_node)
		if _avatar_node.has_method("set_appearance"):
			_avatar_node.set_appearance(h, a, w, horse)
		if _avatar_node.has_method("face"):
			_avatar_node.face(Vector2.RIGHT)  ## Luôn quay mặt sang phải về phía quân địch
		if _avatar_node.has_method("play"):
			_avatar_node.play("stand")
		if _avatar_node.has_signal("action_finished"):
			_avatar_node.action_finished.connect(func(act: String) -> void:
				if act == "attack" or act == "cast" or act == "attack1" or act == "attack2":
					if is_instance_valid(_avatar_node) and _avatar_node.has_method("play"):
						_avatar_node.play("stand")
			)
	else:
		# Visual với icon kỹ năng và khung rương/hiệp khách
		_sprite = Sprite2D.new()
		const ThuThanhSkillData := preload("res://systems/challenge/thu_thanh_skill_data.gd")
		_sprite.texture = ThuThanhSkillData.get_skill_icon_texture(skill_data)
		_sprite.scale = Vector2(0.8, 0.8)
		_sprite.position = Vector2(0, -25)
		_sprite.modulate = tint
		add_child(_sprite)

func _setup_ui() -> void:
	# Thanh máu nhỏ trên đầu
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.min_value = 0
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp
	_hp_bar.size = Vector2(44, 5)
	_hp_bar.position = Vector2(-22, -62)

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_sb.corner_radius_top_left = 2
	bg_sb.corner_radius_top_right = 2
	bg_sb.corner_radius_bottom_left = 2
	bg_sb.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("background", bg_sb)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.2, 0.85, 0.3)
	fill_sb.corner_radius_top_left = 2
	fill_sb.corner_radius_top_right = 2
	fill_sb.corner_radius_bottom_left = 2
	fill_sb.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", fill_sb)
	add_child(_hp_bar)

	# Nhãn môn phái / Hiệp Khách
	_name_lbl = Label.new()
	var sect_str := str(skill_data.get("sect", skill_data.get("name", "Hiệp Khách")))
	_name_lbl.text = ("Hiệp Khách " + sect_str) if unit_type != ThuThanhSkillData.UnitType.CHEST_UTILITY else "Quân Nhu"
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.size = Vector2(100, 16)
	_name_lbl.position = Vector2(-50, -78)
	_name_lbl.add_theme_font_size_override("font_size", 10)
	_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_lbl.add_theme_constant_override("outline_size", 2)
	add_child(_name_lbl)

func _process(delta: float) -> void:
	if not is_active:
		return

	# Hiệu ứng thở nhẹ của nhân vật
	_anim_timer += delta
	if _avatar_node == null and _sprite != null:
		_sprite.position.y = -25.0 + sin(_anim_timer * 3.0) * 1.5

	# Logic Bom Bộc Phá (Thiên Nhẫn)
	if unit_type == ThuThanhSkillData.UnitType.BOMB_INSTANT:
		_bomb_timer -= delta
		if _bomb_timer <= 0.0 and not _is_exploding:
			_explode_bomb()
		return

	# Logic hồi phục sinh lực (Nga Mi)
	if unit_type == ThuThanhSkillData.UnitType.HEAL_SUPPORT:
		_attack_timer += delta
		if _attack_timer >= attack_interval:
			_attack_timer = 0.0
			_heal_support_pulse()
		return

	# Logic tấn công tầm xa / cận chiến theo làn khi có quái trên hàng
	_attack_timer += delta
	if _attack_timer >= attack_interval:
		if _has_enemies_in_lane():
			_attack_timer = 0.0
			_perform_attack()

func _get_target_enemy_in_lane() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("thu_thanh_enemies")
	var best_enemy: Node2D = null
	var min_x: float = 99999.0
	for e in enemies:
		if not is_instance_valid(e) or (e.has_method("is_dead") and e.is_dead()):
			continue
		# Chỉ đánh quái khi quái đã bước qua lằn ranh màu vàng (vào trong 11 cột bàn cờ phòng thủ)
		if e.position.x > DEFENSE_BOUNDARY_X:
			continue
		if e.has_method("has_crossed_defense_line") and not e.has_crossed_defense_line():
			continue
		var e_row = e.get("lane_row") if "lane_row" in e else -1
		if e_row == grid_row and e.position.x >= position.x - 40.0:
			if e.position.x < min_x:
				min_x = e.position.x
				best_enemy = e
	return best_enemy

func _has_enemies_in_lane() -> bool:
	return _get_target_enemy_in_lane() != null

func _perform_attack() -> void:
	var target_enemy := _get_target_enemy_in_lane()
	if target_enemy == null:
		return

	# Hoạt ảnh tấn công
	if _avatar_node != null and _avatar_node.has_method("play"):
		_avatar_node.play("attack")

	# Tạo đạn bay theo làn hướng tới quái mục tiêu
	var proj_type := str(skill_data.get("projectile_type", "dragon"))
	var proj_speed := float(skill_data.get("projectile_speed", 520.0))
	var base_aoe := float(skill_data.get("aoe_radius", 75.0))
	var sid := str(skill_data.get("id", ""))
	var scaling: Dictionary = ThuThanhSkillData.get_skill_scaling(sid, skill_level)
	var aoe_r: float = base_aoe * float(scaling.get("aoe_mult", 1.0))

	# Nếu có bắn nhiều phát liên thanh hoặc thưởng đạn khi max skill
	var base_shots: int = int(skill_data.get("shots_per_attack", 1))
	var shots: int = base_shots + int(scaling.get("extra_shots", 0))
	for i in shots:
		if i == 0:
			_spawn_projectile(proj_type, proj_speed, target_enemy, aoe_r, 0)
		else:
			var shot_idx := i
			get_tree().create_timer(shot_idx * 0.12, false).timeout.connect(func() -> void:
				if is_instance_valid(self) and is_active:
					var re_target := _get_target_enemy_in_lane()
					_spawn_projectile(proj_type, proj_speed, re_target if re_target != null else target_enemy, aoe_r, shot_idx)
			)

func _spawn_projectile(proj_type: String, proj_speed: float, target_enemy: Node2D = null, aoe_r: float = 75.0, shot_idx: int = 0) -> void:
	var p_node := get_parent()
	if p_node == null:
		return
	var proj := ThuThanhProjectileScript.new()
	p_node.add_child(proj)
	var y_offset := -20.0
	if shot_idx > 0:
		# Độ lệch nhẹ vị trí xuất phát để đàn rồng/đạn bay thành chùm liên hoàn đẹp mắt
		var sign_val: float = -10.0 if shot_idx % 2 == 1 else 10.0
		var step_mult: float = float((shot_idx + 1) / 2)
		y_offset += sign_val * step_mult
	proj.position = position + Vector2(25, y_offset)
	proj.z_index = 20
	proj.setup(proj_type, damage, grid_row, proj_speed)
	if proj.has_method("set_target_and_aoe"):
		proj.set_target_and_aoe(target_enemy, aoe_r)

func _heal_support_pulse() -> void:
	# Hào quang hồi phục
	var heal_val := float(skill_data.get("heal_amount", 120.0))
	var units = get_tree().get_nodes_in_group("thu_thanh_units")
	for u in units:
		if is_instance_valid(u) and u != self and u.global_position.distance_to(global_position) <= 250.0:
			u.heal(heal_val)

	# Hồi máu cho Xe Tống Kim
	var carts = get_tree().get_nodes_in_group("escort_carts")
	for c in carts:
		if is_instance_valid(c) and c.has_method("repair"):
			c.repair(heal_val)

	# Hiệu ứng số hồi máu xanh lá
	if DamageNumberScene:
		var num = DamageNumberScene.instantiate()
		if num.has_method("setup"):
			num.setup(int(heal_val), global_position + Vector2(0, -45), Color(0.2, 1.0, 0.4))
		get_parent().add_child(num)

func _explode_bomb() -> void:
	_is_exploding = true
	is_active = false

	# Nổ thiêu rụi toàn bộ quái trong phạm vi
	var enemies = get_tree().get_nodes_in_group("thu_thanh_enemies")
	var blast_range: float = float(skill_data.get("range", 200.0))
	for e in enemies:
		if is_instance_valid(e) and not (e.has_method("is_dead") and e.is_dead()):
			# Chỉ gây sát thương quái đã bước qua lằn ranh phòng thủ
			if e.position.x > DEFENSE_BOUNDARY_X:
				continue
			if e.has_method("has_crossed_defense_line") and not e.has_crossed_defense_line():
				continue
			var dist = e.global_position.distance_to(global_position)
			var e_row = e.get("lane_row") if "lane_row" in e else -1
			# Quét cả quái trong làn và quái trong bán kính
			if e_row == grid_row or dist <= blast_range:
				if e.has_method("take_damage"):
					e.take_damage(damage, self)

	# Hiệu ứng nổ bộc phá
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tw.tween_property(self, "modulate", Color(2.0, 0.4, 0.1, 0.0), 0.25)
	tw.tween_callback(func() -> void:
		died.emit(self)
		queue_free()
	)

func _apply_chest_utility() -> void:
	# Tiếp tế cho Xe Tống Kim +500 HP ngay lập tức
	var carts = get_tree().get_nodes_in_group("escort_carts")
	for c in carts:
		if is_instance_valid(c) and c.has_method("repair"):
			c.repair(500.0)

func take_damage(amount: float, _attacker: Node = null) -> void:
	if not is_active:
		return
	current_hp -= amount
	_hp_bar.value = current_hp

	# Nhấp nháy đỏ khi bị thương
	modulate = Color(1.5, 0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)

	if current_hp <= 0:
		die()

func heal(amount: float) -> void:
	current_hp = minf(max_hp, current_hp + amount)
	_hp_bar.value = current_hp

func die() -> void:
	if not is_active:
		return
	is_active = false
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

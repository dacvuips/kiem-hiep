extends CharacterBody2D
class_name EscortCart
## Node Tiêu Xa (Mã Xa Hộ Tống) trên map thực địa Biện Kinh (map_37).
## Sử dụng sprite gốc VLTK enemy241 (VN Hộ Tống Nhiệm Vụ Mã Xa) qua MonsterSprite.

signal arrived
signal destroyed
signal hp_changed(current: int, maximum: int)
signal damaged_by(source: Node, amount: int)

const HealthBarScene := preload("res://ui/HealthBar.tscn")
const DamageNumberScene := preload("res://effects/damage_number.tscn")

@export var speed: float = 60.0

var display_name: String = "Tiêu Xa"
var cart_data: Dictionary = {}
var max_hp: int = 60000
var current_hp: int = 60000
var is_arrived: bool = false
var is_destroyed: bool = false

var waypoints: Array[Vector2] = []
var current_waypoint_idx: int = 0
var progress_percent: int = 0

var _sprite: MonsterSprite
var _hp_bar: Node
var _name_label: Label
var _anim_timer: float = 0.0
var _dir64: int = 0  ## Hướng 0..63 của VLTK (0 = xuống, 16 = trái, 32 = lên, 48 = phải)

var _sub_path: PackedVector2Array = PackedVector2Array()
var _sub_idx: int = 0
var _repath_timer: float = 0.0
var _stuck_timer: float = 0.0

func setup(data: Dictionary, path_waypoints: Array[Vector2], start_idx: int = 0, initial_progress: int = 0) -> void:
	cart_data = data
	display_name = str(data.get("cart_name", "Tiêu Xa"))
	waypoints = path_waypoints
	current_waypoint_idx = start_idx
	progress_percent = initial_progress
	
	max_hp = int(data.get("max_hp", data.get("hp", 60000)))
	current_hp = int(data.get("hp", max_hp))

func _ready() -> void:
	add_to_group("escort_carts")
	add_to_group("allies")
	input_pickable = true
	
	collision_layer = 1
	collision_mask = 32

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	shape.shape = circle
	add_child(shape)

	# Click Area để nhận diện click / chạm màn hình theo sau tiêu xa
	var click_area := Area2D.new()
	click_area.name = "ClickArea"
	var click_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(200.0, 140.0)
	click_shape.shape = rect_shape
	click_shape.position = Vector2(0.0, -60.0)
	click_area.add_child(click_shape)
	click_area.input_event.connect(_on_click_area_input_event)
	add_child(click_area)

	# Khởi tạo Sprite chuẩn VLTK (bộ hình enemy241: Mã Xa Hộ Tống kèm bóng xe)
	_sprite = MonsterSprite.new()
	_sprite.set_resource("enemy241")
	add_child(_sprite)
	_sprite.set_pose("stand", _dir64, 0.0)

	var cart_height: float = _sprite.get_height()
	if cart_height <= 0.0:
		cart_height = 120.0

	# Thanh máu
	if HealthBarScene:
		_hp_bar = HealthBarScene.instantiate()
		_hp_bar.position = Vector2(-36, -cart_height - 12.0)
		add_child(_hp_bar)
		_update_hp_bar()

	# Nhãn tên tiêu xa
	_name_label = Label.new()
	_name_label.text = "%s (%s)" % [
		display_name,
		str(cart_data.get("owner_name", "Đại Hiệp"))
	]
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.position = Vector2(-150, -cart_height - 36.0)
	_name_label.custom_minimum_size = Vector2(300, 20)
	add_child(_name_label)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_player_start_following()

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_player_start_following()

func _player_start_following() -> void:
	for n in get_tree().get_nodes_in_group("player"):
		var player := n as Node2D
		if player != null and is_instance_valid(player) and not player.is_queued_for_deletion():
			if player.has_method("start_follow"):
				player.start_follow(self)
			else:
				player.set("follow_target", self)
			break

func _replan_sub_path() -> void:
	if current_waypoint_idx >= waypoints.size():
		return
	var target := waypoints[current_waypoint_idx]
	var from_feet := global_position + Vector2(0.0, VltkWorld.FEET_OFFSET)
	var to_feet := target + Vector2(0.0, VltkWorld.FEET_OFFSET)
	var raw := VltkWorld.find_path(from_feet, to_feet, true)
	_sub_path.clear()
	for p in raw:
		_sub_path.append(p - Vector2(0.0, VltkWorld.FEET_OFFSET))
	_sub_idx = 0
	_repath_timer = 2.0

func _physics_process(delta: float) -> void:
	if is_arrived or is_destroyed:
		return

	if current_waypoint_idx >= waypoints.size():
		_on_arrived()
		return

	var target := waypoints[current_waypoint_idx]

	# Định kỳ tìm đường né vật cản qua A*
	_repath_timer -= delta
	if _sub_path.is_empty() or _repath_timer <= 0.0:
		_replan_sub_path()

	var move_target := target
	if not _sub_path.is_empty() and _sub_idx < _sub_path.size():
		var pt := _sub_path[_sub_idx]
		if global_position.distance_to(pt) <= 32.0:
			_sub_idx += 1
			if _sub_idx < _sub_path.size():
				pt = _sub_path[_sub_idx]
		move_target = pt

	if global_position.distance_to(target) <= 40.0:
		current_waypoint_idx += 1
		progress_percent = int((float(current_waypoint_idx) / float(maxi(waypoints.size(), 1))) * 100.0)
		if current_waypoint_idx >= waypoints.size():
			_on_arrived()
			return
		_replan_sub_path()
		move_target = waypoints[current_waypoint_idx]

	var move_vec := (move_target - global_position).normalized()
	velocity = move_vec * speed
	move_and_slide()

	# Chống kẹt vật thể khi va quẹt mép cây / rào
	if velocity.length_squared() > 1.0 and get_real_velocity().length_squared() < 4.0:
		_stuck_timer += delta
		if _stuck_timer >= 0.8:
			_stuck_timer = 0.0
			_sub_idx += 1
			if _sub_idx >= _sub_path.size():
				current_waypoint_idx = mini(current_waypoint_idx + 1, waypoints.size() - 1)
				_replan_sub_path()
	else:
		_stuck_timer = 0.0

	_update_animation(delta, move_vec)

func _update_animation(delta: float, dir_vec: Vector2) -> void:
	if _sprite == null:
		return

	_anim_timer += delta
	if dir_vec.length_squared() > 0.01:
		# Toạ độ logic VLTK: y màn hình = 2 * logic_y
		var angle := atan2(-dir_vec.x, dir_vec.y * 2.0)
		_dir64 = wrapi(roundi(angle / TAU * 64.0), 0, 64)
		var progress := fmod(_anim_timer / 1.056, 1.0)
		_sprite.set_pose("walk", _dir64, progress)
	else:
		var progress := fmod(_anim_timer / 1.44, 1.0)
		_sprite.set_pose("stand", _dir64, progress)

func take_damage(amount: float) -> void:
	take_damage_from(null, int(amount))

func take_damage_from(source: Variant, amount: int, max_damage: int = -1, is_crit := false, _hit_type := 0, _skill_name := "") -> void:
	if is_arrived or is_destroyed:
		return
	var dmg: int = amount
	if max_damage > amount:
		dmg = randi_range(amount, max_damage)
	dmg = maxi(1, dmg)
	current_hp = maxi(0, current_hp - dmg)
	
	_show_damage_number(dmg, is_crit)
	_update_hp_bar()
	hp_changed.emit(current_hp, max_hp)
	var src_node: Node = source as Node if source is Node else null
	damaged_by.emit(src_node, dmg)

	if current_hp <= 0:
		_on_destroyed()

func heal(amount: int) -> void:
	if is_arrived or is_destroyed:
		return
	current_hp = mini(max_hp, current_hp + amount)
	_update_hp_bar()
	hp_changed.emit(current_hp, max_hp)

func _show_damage_number(amount: int, is_crit: bool) -> void:
	if DamageNumberScene:
		var d = DamageNumberScene.instantiate()
		d.position = global_position + Vector2(randf_range(-15, 15), -40)
		if d.has_method("setup"):
			d.setup(amount, is_crit)
		get_parent().add_child(d)

func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	if _hp_bar.has_method("set_max_health"):
		_hp_bar.set_max_health(float(max_hp))
	if _hp_bar.has_method("set_health"):
		_hp_bar.set_health(float(current_hp))

func _on_arrived() -> void:
	if is_arrived:
		return
	is_arrived = true
	velocity = Vector2.ZERO
	progress_percent = 100
	if _sprite:
		_sprite.set_pose("stand", _dir64, 0.0)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.get("follow_target") == self:
		if player.has_method("stop_follow"):
			player.stop_follow()
	arrived.emit()

func _on_destroyed() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	velocity = Vector2.ZERO
	if _sprite:
		_sprite.set_pose("die", _dir64, 0.99)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.get("follow_target") == self:
		if player.has_method("stop_follow"):
			player.stop_follow()
	destroyed.emit()

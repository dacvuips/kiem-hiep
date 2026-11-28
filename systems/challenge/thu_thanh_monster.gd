extends CharacterBody2D
class_name ThuThanhMonster

## QUÁI VẬT TẤN CÔNG THEO LÀN TRONG THỦ THÀNH (PLANTS VS ZOMBIES JX1)
## Xuất hiện ở khu staging bên phải, bước đi từ phải sang trái, tấn công hiệp khách cản đường
## hoặc tấn công Xe Tống Kim nếu vượt qua hết chiến tuyến.

signal died(monster: ThuThanhMonster)

const DamageNumberScene := preload("res://effects/damage_number.tscn")
const ThuThanhCoinScript := preload("res://systems/challenge/thu_thanh_coin.gd")
const DEFENSE_BOUNDARY_X: float = 120.0 + 11.0 * 96.0  ## 1176.0: Lằn ranh vạch vàng phòng thủ bàn cờ ô vuông 96x96

var monster_name: String = "Sơn Tặc"
var level: int = 10
var max_hp: float = 200.0
var current_hp: float = 200.0
var base_speed: float = 45.0
var current_speed: float = 45.0
var attack_power: float = 25.0
var attack_interval: float = 1.0
var xu_drop_amount: int = 25

var lane_row: int = 0
var is_elite: bool = false
var is_boss: bool = false
var is_dead: bool = false

var _attack_timer: float = 0.0
var _anim_timer: float = 0.0
var _slow_timer: float = 0.0
var _slow_ratio: float = 0.0
var _poison_timer: float = 0.0
var _poison_dps: float = 0.0
var _poison_tick: float = 0.0
var _stun_timer: float = 0.0

var _current_target: Node2D = null

var _sprite: Node2D
var raw_data: Dictionary = {}
var _hp_bar: ProgressBar
var _name_lbl: Label
var _elite_aura: Sprite2D

func setup(data: Dictionary, row: int, p_is_elite: bool = false, p_is_boss: bool = false, wave_hp_mult: float = 1.0) -> void:
	raw_data = data
	lane_row = row
	is_elite = p_is_elite
	is_boss = p_is_boss

	monster_name = str(data.get("name", "Quái Vật"))
	level = int(data.get("level", 10))

	var hp_mult := 1.0
	if is_boss:
		hp_mult = 15.0
		base_speed = 35.0
		attack_power = 90.0
		xu_drop_amount = int(data.get("xu_drop", 200))
	elif is_elite:
		hp_mult = 2.5
		base_speed = 52.0
		attack_power = 45.0
		xu_drop_amount = int(data.get("xu_drop", 60))
	else:
		xu_drop_amount = int(data.get("xu_drop", 25))

	max_hp = float(data.get("hp", 150.0 + level * 15.0)) * hp_mult * wave_hp_mult
	current_hp = max_hp
	current_speed = base_speed

func _ready() -> void:
	# Quái vật nằm dưới các công trình của map (nhà cửa, cây cối, lều...)
	z_as_relative = false
	z_index = -20

	add_to_group("enemies")
	add_to_group("thu_thanh_enemies")
	collision_layer = 2
	collision_mask = 1

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0 if not is_boss else 45.0
	col.shape = circle
	col.position = Vector2(0, -25)
	add_child(col)

	_setup_visual()
	_setup_ui()

func _setup_visual() -> void:
	# Vòng sáng chân cho quái Tinh Anh hoặc Boss
	if is_boss or is_elite:
		_elite_aura = Sprite2D.new()
		var aura_icon := "res://assets/skill_icons/vltk/cai_bang_khang_long_huu_hoi.png"
		if ResourceLoader.exists(aura_icon):
			_elite_aura.texture = load(aura_icon)
		_elite_aura.scale = Vector2(0.8, 0.4) if not is_boss else Vector2(1.6, 0.8)
		_elite_aura.modulate = Color(1.0, 0.2, 0.2, 0.6) if is_boss else Color(0.9, 0.8, 0.2, 0.5)
		_elite_aura.position = Vector2(0, 5)
		add_child(_elite_aura)

	# Nạp MonsterSprite chuẩn VLTK (preloaded GDScript)
	const MonsterSpriteScript = preload("res://systems/monster/monster_sprite.gd")
	var ms: Node2D = null

	var res_id: String = str(raw_data.get("res", ""))
	if res_id == "":
		var t_id := int(raw_data.get("t", -1))
		if t_id > 0 and MonsterData != null:
			var m_info: Dictionary = MonsterData.monster(t_id)
			res_id = str(m_info.get("res", ""))

	if res_id == "" and MonsterData != null:
		# Tra cứu theo tên quái trong danh mục quái
		for m in MonsterData.all():
			if str(m.get("name", "")) == monster_name:
				res_id = str(m.get("res", ""))
				break

	if res_id == "":
		# Dự phòng theo đặc trưng tên hoặc cấp độ
		if "Heo" in monster_name:
			res_id = "ani018"
		elif "Nhím" in monster_name:
			res_id = "ani019"
		elif "Miêu" in monster_name or "Mèo" in monster_name:
			res_id = "ani049"
		elif "Hươu" in monster_name:
			res_id = "ani061"
		elif is_boss:
			res_id = "boss001"
		else:
			res_id = "enemy125"

	ms = MonsterSpriteScript.new()
	if ms.has_method("set_resource"):
		ms.set_resource(res_id)
		ms.set_pose("walk", 16, 0.0)  ## 16 = hướng sang trái (tiến về Xe Tống Kim)
	if is_boss:
		ms.scale = Vector2(1.5, 1.5)
	_sprite = ms
	add_child(_sprite)

func _setup_ui() -> void:
	var bar_w := 48.0 if not is_boss else 90.0
	var offset_y := -68.0 if not is_boss else -110.0

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.min_value = 0
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp
	_hp_bar.size = Vector2(bar_w, 5)
	_hp_bar.position = Vector2(-bar_w * 0.5, offset_y)

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	_hp_bar.add_theme_stylebox_override("background", bg_sb)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.95, 0.2, 0.2)
	_hp_bar.add_theme_stylebox_override("fill", fill_sb)
	add_child(_hp_bar)

	_name_lbl = Label.new()
	var prefix := "★ " if is_elite else ("👑 " if is_boss else "")
	_name_lbl.text = "%s%s (Lv.%d)" % [prefix, monster_name, level]
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.size = Vector2(120, 16)
	_name_lbl.position = Vector2(-60, offset_y - 18)
	_name_lbl.add_theme_font_size_override("font_size", 10 if not is_boss else 13)
	var title_col := Color(1.0, 0.3, 0.3) if is_boss else (Color(1.0, 0.85, 0.3) if is_elite else Color.WHITE)
	_name_lbl.add_theme_color_override("font_color", title_col)
	_name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_lbl.add_theme_constant_override("outline_size", 2)
	add_child(_name_lbl)

func _process(delta: float) -> void:
	if is_dead:
		return

	_update_status_effects(delta)

	if _stun_timer > 0.0:
		return  ## Bị choáng, đứng yên không làm gì

	# Cập nhật mục tiêu cản đường trước mặt
	_scan_targets_ahead()

	if _current_target != null and is_instance_valid(_current_target):
		# Đang gặp chướng ngại vật (hiệp khách hoặc Xe Tống Kim) -> Dừng lại và tấn công
		_attack_timer += delta
		if _sprite != null and _sprite.has_method("set_pose"):
			_sprite.set_pose("attack1", 16, fmod(_attack_timer / attack_interval, 1.0))
		if _attack_timer >= attack_interval:
			_attack_timer = 0.0
			_attack_current_target()
	else:
		# Đường thông thoáng -> Tiếp tục bước sang trái
		position.x -= current_speed * delta

		# Hoạt ảnh bước đi hướng sang trái
		_anim_timer += delta
		if _sprite != null and _sprite.has_method("set_pose"):
			_sprite.set_pose("walk", 16, fmod(_anim_timer * 1.5, 1.0))

func _scan_targets_ahead() -> void:
	# Kiểm tra Hiệp khách cùng làn đứng cản đường phía trước
	var units = get_tree().get_nodes_in_group("thu_thanh_units")
	var closest_unit: Node2D = null
	var min_dist: float = 9999.0

	for u in units:
		if not is_instance_valid(u) or (u.has_method("is_dead") and u.is_dead()):
			continue
		var u_row = u.get("grid_row") if "grid_row" in u else -1
		if u_row == lane_row and u.position.x <= position.x:
			var d = position.x - u.position.x
			if d <= 42.0 and d < min_dist:
				min_dist = d
				closest_unit = u

	_current_target = closest_unit

func _attack_current_target() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return

	# Hiệu ứng cắn / đánh
	var base_x = position.x
	var tw := create_tween()
	tw.tween_property(self, "position:x", base_x - 12.0, 0.1)
	tw.tween_property(self, "position:x", base_x, 0.1)

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_power, self)
	elif "current_hp" in _current_target:
		_current_target.current_hp -= attack_power
		if _current_target.current_hp <= 0 and _current_target.has_method("destroy"):
			_current_target.destroy()

func _update_status_effects(delta: float) -> void:
	# Làm chậm (Băng)
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			current_speed = base_speed
			modulate = Color.WHITE

	# Trúng độc (Mộc)
	if _poison_timer > 0.0:
		_poison_timer -= delta
		_poison_tick += delta
		if _poison_tick >= 0.5:
			_poison_tick = 0.0
			take_damage(_poison_dps * 0.5, null)
		if _poison_timer <= 0.0 and _slow_timer <= 0.0:
			modulate = Color.WHITE

	# Choáng định thân (Võ Đang)
	if _stun_timer > 0.0:
		_stun_timer -= delta

func has_crossed_defense_line() -> bool:
	return position.x <= DEFENSE_BOUNDARY_X

func apply_slow(ratio: float, duration: float) -> void:
	if not has_crossed_defense_line():
		return
	_slow_ratio = ratio
	_slow_timer = maxf(_slow_timer, duration)
	current_speed = base_speed * (1.0 - ratio)
	modulate = Color(0.5, 0.8, 1.2)

func apply_poison(dps: float, duration: float) -> void:
	if not has_crossed_defense_line():
		return
	_poison_dps = dps
	_poison_timer = maxf(_poison_timer, duration)
	modulate = Color(0.6, 1.2, 0.6)

func apply_stun(duration: float) -> void:
	if not has_crossed_defense_line():
		return
	_stun_timer = maxf(_stun_timer, duration)
	modulate = Color(1.3, 1.3, 0.4)

func take_damage(amount: float, _attacker: Node = null) -> void:
	if is_dead:
		return
	# Chỉ nhận sát thương khi quái đã bước qua lằn ranh màu vàng (trừ khi bị Xe Tống Kim càn quét)
	var is_cart := (_attacker != null and _attacker.is_in_group("escort_carts"))
	if not is_cart and not has_crossed_defense_line():
		return
	current_hp -= amount
	_hp_bar.value = current_hp

	# Hiệu ứng nhấp nháy đỏ
	var tw := create_tween()
	tw.tween_property(self, "modulate:v", 1.8, 0.08)
	tw.tween_property(self, "modulate:v", 1.0, 0.08)

	if current_hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	# Ngay lập tức gỡ khỏi nhóm quái để không làm nghẽn tiến trình chuyển đợt
	remove_from_group("thu_thanh_enemies")
	remove_from_group("enemies")
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	died.emit(self)

	# Hoạt ảnh chết
	if _sprite != null and _sprite.has_method("set_pose"):
		_sprite.set_pose("die", 16, 0.9)

	# 1. Rơi đồng Xu vàng tại vị trí tử trận (người chơi nhặt tay)
	if xu_drop_amount > 0 and ThuThanhCoinScript != null:
		var coin: ThuThanhCoin = ThuThanhCoinScript.new()
		coin.setup(xu_drop_amount)
		var p_node := get_parent()
		if p_node != null:
			p_node.add_child(coin)
			coin.position = position
			coin.z_index = 25
			if p_node.has_method("_on_coin_spawned"):
				p_node._on_coin_spawned(coin)
			elif p_node.has_method("_on_coin_collected"):
				coin.collected.connect(p_node._on_coin_collected)

	# 2. Vật phẩm trang bị / nguyên liệu tự động chuyển thẳng vào túi đồ (Section 9)
	_auto_award_items()

	# Hiệu ứng tan biến
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)

func _auto_award_items() -> void:
	# 15% cơ hội rơi vật phẩm cho quái thường, 40% cho tinh anh, 100% cho boss
	var drop_chance := 0.15
	if is_boss:
		drop_chance = 1.0
	elif is_elite:
		drop_chance = 0.4

	if randf() <= drop_chance:
		var gm = Engine.get_singleton("GameManager") if Engine.has_singleton("GameManager") else null
		if gm == null and Engine.get_main_loop() != null and "root" in Engine.get_main_loop() and Engine.get_main_loop().root != null and Engine.get_main_loop().root.has_node("GameManager"):
			gm = Engine.get_main_loop().root.get_node("GameManager")
		var profile: PlayerProfile = null
		if gm != null:
			if "current_profile" in gm:
				profile = gm.current_profile
			elif "local_profile" in gm:
				profile = gm.local_profile

		if profile != null:
			# EXP nhân vật KHÔNG cộng trong trận Thủ Thành (Zombies vs Plants),
			# mà chỉ nhận bằng phần thưởng tổng kết ở cuối trận đấu.
			pass

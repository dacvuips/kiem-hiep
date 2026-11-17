extends Area2D
class_name ThuThanhProjectile

## ĐẠN / CHIÊU THỨC BAY TRONG THỦ THÀNH (PLANTS VS ZOMBIES JX1)
## Sử dụng hình ảnh hiệu ứng chiêu thức thật của VLTK (Con Rồng Phi Long, Cây Bổng dí, Kiếm Khí, Lôi Điện...)
## khi nhân vật thi triển, bay bám đuổi mục tiêu và nổ lan (AoE Splash) hoành tráng.

const DamageNumberScene := preload("res://effects/damage_number.tscn")
const ThuThanhFxSpriteScript := preload("res://systems/challenge/thu_thanh_fx_sprite.gd")
const DEFENSE_BOUNDARY_X: float = 120.0 + 11.0 * 96.0  ## 1176.0: Lằn ranh vạch vàng phòng thủ (11 cột x 96px)

# BẢNG ÁNH XẠ HIỆU ỨNG CHIÊU THỨC VLTK CHUẨN XÁC THEO 13 MÔN PHÁI (197 KỸ NĂNG)
const FX_CONFIGS: Dictionary = {
	# Cái Bang Chưởng (Phi Long Tại Thiên, Kháng Long Hữu Hối...)
	"dragon": {
		"fly": "fx_a31b9f04",      ## Con Rồng lửa Phi Long Tại Thiên 16 hướng bay uốn lượn
		"hit": "fx_c33e96c2",      ## Lửa nổ rực sáng khi trúng đích
		"scale": Vector2(0.85, 0.85),
		"speed": 520.0
	},
	# Cái Bang Bổng (Đả Cẩu Bổng Pháp, Bổng Đả Ác Cẩu...)
	"dog_stick": {
		"fly": "fx_04e27976",      ## Cây Bổng Đả Ác Cẩu xoay tít dí theo quái
		"hit": "fx_b91ab706",      ## Bổng kình nổ tung khi trúng đích
		"scale": Vector2(0.9, 0.9),
		"speed": 540.0
	},
	# Thúy Yên (Băng Tâm Tiên Tử, Băng Tung Vô Ảnh, Phong Tuyết Băng Thiên...)
	"ice_flake": {
		"fly": "fx_390b84cc",      ## Băng Tâm Tiên Tử hoa tuyết băng phù bay vút
		"hit": "fx_ac3a8fba",      ## Băng hoa phát nổ tan vỡ
		"scale": Vector2(0.85, 0.85),
		"speed": 480.0
	},
	"ice": {
		"fly": "fx_c0c3ccda",      ## Băng Tung Vô Ảnh hoa tuyết băng tiễn sắc lạnh
		"hit": "fx_f613c20a",      ## Băng hoa vỡ vụn
		"scale": Vector2(0.85, 0.85),
		"speed": 460.0
	},
	# Nga Mi (Phiêu Tuyết Xuyên Vân, Kiếm Tâm Tĩnh Điển, Băng Vũ Lạc Tinh...)
	"water_sword": {
		"fly": "fx_5698379e",      ## Phiêu Tuyết Xuyên Vân kiếm khí thủy lưu lam sắc
		"hit": "fx_ac3a8fba",      ## Thủy ba phát nổ
		"scale": Vector2(0.85, 0.85),
		"speed": 500.0
	},
	# Thiếu Lâm (La Hán Trận, Hàng Long Bất Vũ, Thất Thương Quyền...)
	"buddha_palm": {
		"fly": "fx_c9ba5bf1",      ## Chưởng lực Phật Môn La Hán Trận vàng kim 16 hướng
		"hit": "fx_361b4525",      ## Phật quang nổ kim quang
		"scale": Vector2(0.85, 0.85),
		"speed": 500.0
	},
	# Võ Đang (Kiếm Phi Kinh Thiên, Nhân Kiếm Hợp Nhất, Thái Cực Kiếm Ý...)
	"sword_beam": {
		"fly": "fx_01744d1a",      ## Kiếm khí Thái Cực / Lam sắc 16 hướng xoay xé gió
		"hit": "fx_361b4525",      ## Kiếm hoa nổ tung
		"scale": Vector2(0.85, 0.85),
		"speed": 540.0
	},
	"taiji": {
		"fly": "fx_01744d1a",      ## Kiếm khí Thái Cực
		"hit": "fx_361b4525",
		"scale": Vector2(0.85, 0.85),
		"speed": 520.0
	},
	# Hoa Sơn (Độc Cô Cửu Kiếm, Bạch Hồng Quán Nhật, Phất Thiên Kiếm Lạc...)
	"sword_slash": {
		"fly": "fx_de28d30e",      ## Phất Thiên Kiếm Lạc kiếm kình sắc bén
		"hit": "fx_4d6a9696",      ## Kiếm hoa phát nổ
		"scale": Vector2(0.85, 0.85),
		"speed": 560.0
	},
	# Côn Lôn (Hô Phong Pháp, Cuồng Lôi Chấn Địa, Lôi Động Cửu Thiên...)
	"lightning": {
		"fly": "fx_f9c4889b",      ## Lôi Động Cửu Thiên lôi điện giáng giật
		"hit": "fx_51880782",      ## Điện quang nổ chớp
		"scale": Vector2(0.85, 0.85),
		"speed": 580.0
	},
	# Ngũ Độc (Đoạt Hồn Cổ, Độc Sa Chưởng, Âm Phong Thực Cốt...)
	"poison_skull": {
		"fly": "fx_40a1c4ff",      ## Độc Sa Chưởng luồng lục khí độc chưởng
		"hit": "fx_1fffed7e",      ## Khói độc phát nổ
		"scale": Vector2(0.75, 0.75),
		"speed": 460.0
	},
	"poison": {
		"fly": "fx_01ff9a99",      ## Thiên Cương Độc Thủ luồng lục khí
		"hit": "fx_1fffed7e",
		"scale": Vector2(0.7, 0.7),
		"speed": 450.0
	},
	# Đường Môn (Truy Tâm Tiễn, Đoạt Hồn Tiêu, Bão Vũ Lê Hoa...)
	"needle": {
		"fly": "fx_4543a8c4",      ## Bão Vũ Lê Hoa / Đoạt Hồn Tiêu phi tiêu liên hoàn
		"hit": "fx_b91ab706",      ## Ám khí găm nổ kình
		"scale": Vector2(0.9, 0.9),
		"speed": 620.0
	},
	"dart": {
		"fly": "fx_4543a8c4",
		"hit": "fx_b91ab706",
		"scale": Vector2(0.9, 0.9),
		"speed": 620.0
	},
	# Thiên Nhẫn (Tàn Dương Như Huyết, Liệt Hỏa Tình Thiên, Nhiếp Hồn Bộc Phá...)
	"fireball": {
		"fly": "gb_150_zhanggai_huo_acfa", ## Quả cầu lửa hỏa thiêu bộc phá
		"hit": "fx_c33e96c2",      ## Lửa bốc nổ dữ dội
		"scale": Vector2(0.85, 0.85),
		"speed": 520.0
	},
	"bomb": {
		"fly": "fx_0b42100e",      ## Liệt Hỏa Tình Thiên hỏa đạn
		"hit": "fx_c33e96c2",
		"scale": Vector2(0.85, 0.85),
		"speed": 500.0
	},
	"fire_bomb": {
		"fly": "gb_150_zhanggai_huo_acfa",
		"hit": "fx_c33e96c2",
		"scale": Vector2(0.85, 0.85),
		"speed": 520.0
	},
	# Thiên Vương (Trảm Long Quyết, Huyết Chiến Bát Phương...)
	"blade_wave": {
		"fly": "fx_ea408965",      ## Quyết Vân Kiếm Lạc / Đao kình kim sắc
		"hit": "fx_4d6a9696",      ## Đao khí phát nổ
		"scale": Vector2(0.85, 0.85),
		"speed": 520.0
	},
	# Tiêu Dao (Lạc Nhạn Bình Sa, Cao Sơn Lưu Thủy...)
	"sound_wave": {
		"fly": "fx_83b29cc4",      ## Cao Sơn Lưu Thủy cầm âm ba sóng âm xoay tròn
		"hit": "fx_27006703",      ## Sóng đàn phát tán
		"scale": Vector2(0.85, 0.85),
		"speed": 480.0
	},
	# Dương Gia Cung (Lưu Vân Tiễn, Tinh Lạc Tiễn...)
	"fire_arrow": {
		"fly": "fx_77ec007e",      ## Truy Tâm Tiễn / Cung hỏa tiễn xé gió
		"hit": "liuyunjian_shouji_0500",
		"scale": Vector2(0.85, 0.85),
		"speed": 600.0
	},
	# Dương Gia & Thiên Vương Thương (Dương Gia Thương Pháp, Đảo Hải Thương, Bôn Lang Thương...)
	"cleave": {
		"fly": "benlangqiang_665b", ## Bôn Lang Thương / Thương kình xé gió
		"hit": "cy_150_daocui_bz_a645",
		"scale": Vector2(0.85, 0.85),
		"speed": 520.0
	},
	"spear_slash": {
		"fly": "cy_150_daocui_zd_6b77",
		"hit": "cy_150_daocui_bz_a645",
		"scale": Vector2(0.85, 0.85),
		"speed": 520.0
	},
	# Hỗ trợ / Hồi máu (Từ Hàng Phổ Độ, Rương Tiếp Tế...)
	"heal": {
		"fly": "fx_3b41a4a0",      ## Phong Sương Toái Ảnh hoa sen tuyết
		"hit": "fx_ac3a8fba",      ## Hào quang Phật quang rạng ngời
		"scale": Vector2(0.75, 0.75),
		"speed": 480.0
	},
	"lotus_heal": {
		"fly": "fx_3b41a4a0",
		"hit": "fx_ac3a8fba",
		"scale": Vector2(0.75, 0.75),
		"speed": 480.0
	}
}

var direction: Vector2 = Vector2.RIGHT
var speed: float = 520.0
var damage: float = 40.0
var projectile_type: String = "dragon"
var target_row: int = 0
var max_x: float = 1400.0

var target_enemy: Node2D = null
var aoe_radius: float = 75.0
var is_exploded: bool = false

var slow_ratio: float = 0.0
var slow_duration: float = 0.0
var poison_dps: float = 0.0
var poison_duration: float = 0.0
var stun_chance: float = 0.0
var stun_duration: float = 0.0
var piercing: bool = false
var pierced_targets: Array[Node2D] = []

var _fx_sprite: Sprite2D
var _hit_anim_key: String = "fx_c33e96c2"
var _flight_timer: float = 0.0

func setup(p_type: String, p_damage: float, p_row: int, p_speed: float = 520.0) -> void:
	projectile_type = p_type
	damage = p_damage
	target_row = p_row
	speed = p_speed
	if is_node_ready():
		_setup_vltk_skill_fx()

func set_target_and_aoe(p_target: Node2D, p_aoe: float = 75.0) -> void:
	target_enemy = p_target
	aoe_radius = p_aoe

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   ## Layer quái

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	col.shape = circle
	add_child(col)

	_setup_vltk_skill_fx()

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _setup_vltk_skill_fx() -> void:
	if _fx_sprite != null and is_instance_valid(_fx_sprite):
		_fx_sprite.queue_free()
		_fx_sprite = null

	var cfg: Dictionary = FX_CONFIGS.get(projectile_type, FX_CONFIGS["dragon"])
	var fly_anim: String = str(cfg.get("fly", "fx_a31b9f04"))
	_hit_anim_key = str(cfg.get("hit", "fx_c33e96c2"))
	var fx_scale: Vector2 = cfg.get("scale", Vector2(0.85, 0.85))

	# Khởi tạo Sprite hoạt ảnh VLTK thật
	_fx_sprite = ThuThanhFxSpriteScript.new()
	add_child(_fx_sprite)
	_fx_sprite.scale = fx_scale
	var ok: bool = _fx_sprite.setup_fx(fly_anim, 48, true, 18.0)
	if not ok:
		# Fallback nếu thiếu file
		_fx_sprite.setup_fx("fx_a31b9f04", 48, true, 18.0)

	# Cấu hình hiệu ứng trạng thái theo loại chiêu thức chuẩn 13 môn phái
	match projectile_type:
		"buddha_palm":
			stun_chance = 0.35
			stun_duration = 1.2
		"dragon":
			piercing = true
		"dog_stick":
			stun_chance = 0.25
			stun_duration = 1.0
		"ice_flake", "ice":
			slow_ratio = 0.5
			slow_duration = 3.5
		"water_sword":
			slow_ratio = 0.35
			slow_duration = 2.5
		"poison_skull", "poison":
			poison_dps = 30.0
			poison_duration = 4.0
		"lightning":
			stun_chance = 0.35
			stun_duration = 1.2
		"sound_wave":
			slow_ratio = 0.4
			slow_duration = 2.5
		"sword_beam", "taiji":
			stun_chance = 0.3
			stun_duration = 1.0
		"sword_slash":
			piercing = true
		"blade_wave":
			aoe_radius = 85.0
		"fireball", "bomb", "fire_bomb":
			aoe_radius = 90.0
		"cleave", "spear_slash":
			aoe_radius = 80.0

func _process(delta: float) -> void:
	if is_exploded:
		return

	# Bay bám đuổi mục tiêu quái nếu còn sống
	if target_enemy != null and is_instance_valid(target_enemy) and not (target_enemy.has_method("is_dead") and target_enemy.is_dead()):
		if target_enemy.position.x > DEFENSE_BOUNDARY_X:
			target_enemy = null
		else:
			var target_pos: Vector2 = target_enemy.position + Vector2(0, -20)
			var to_target: Vector2 = target_pos - position
			var dist := to_target.length()
			if dist <= 28.0:
				_explode_splash(target_enemy)
				return
			direction = to_target.normalized()
			var move_step := direction * speed * delta
			# Hiệu ứng rồng lửa Phi Long Tại Thiên uốn lượn hình sin đặc trưng VLTK
			if projectile_type == "dragon":
				_flight_timer += delta
				var perp := Vector2(-direction.y, direction.x)
				move_step += perp * sin(_flight_timer * 15.0) * 80.0 * delta
			if _fx_sprite != null and is_instance_valid(_fx_sprite):
				_fx_sprite.set_motion_vector(direction)
			position += move_step
	if target_enemy == null or not is_instance_valid(target_enemy) or (target_enemy.has_method("is_dead") and target_enemy.is_dead()):
		# Nếu quái mục tiêu đã chết hoặc ở ngoài lằn ranh, tiếp tục bay thẳng sang phải
		var move_step := direction * speed * delta
		if projectile_type == "dragon":
			_flight_timer += delta
			var perp := Vector2(-direction.y, direction.x)
			move_step += perp * sin(_flight_timer * 15.0) * 80.0 * delta
		if _fx_sprite != null and is_instance_valid(_fx_sprite):
			_fx_sprite.set_motion_vector(direction)
		position += move_step

	if position.x > DEFENSE_BOUNDARY_X + 25.0 or position.x < -100.0 or position.y < -100.0 or position.y > 800.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	_check_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_check_hit(area.get_parent())

func _check_hit(target: Node) -> void:
	if is_exploded or target == null or not is_instance_valid(target):
		return
	var node2d := target as Node2D
	if node2d == null:
		return
	if not node2d.is_in_group("enemies") and not node2d.is_in_group("thu_thanh_enemies"):
		return
	if pierced_targets.has(node2d):
		return
	# Không gây sát thương quái khi quái chưa bước qua lằn ranh phòng thủ
	if node2d.position.x > DEFENSE_BOUNDARY_X:
		return
	if node2d.has_method("has_crossed_defense_line") and not node2d.has_crossed_defense_line():
		return

	_explode_splash(node2d)

## KÍCH HOẠT VỤ NỔ LAN DIỆN RỘNG (AOE SPLASH) VỚI HIỆU ỨNG NỔ VLTK THẬT
func _explode_splash(hit_target: Node2D) -> void:
	if is_exploded:
		return
	is_exploded = true

	var hit_center := position
	if hit_target != null and is_instance_valid(hit_target):
		hit_center = hit_target.position + Vector2(0, -20)

	# 1. Gây 100% sát thương lên quái trúng đích trực tiếp
	_apply_damage_and_effects_to(hit_target, damage, true)
	pierced_targets.append(hit_target)

	# 2. Quét và gây sát thương lan (75%) cho toàn bộ quái xung quanh trong bán kính aoe_radius
	var enemies = get_tree().get_nodes_in_group("thu_thanh_enemies")
	for e in enemies:
		if not is_instance_valid(e) or e == hit_target:
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if e.position.x > DEFENSE_BOUNDARY_X:
			continue
		if e.has_method("has_crossed_defense_line") and not e.has_crossed_defense_line():
			continue
		var e_pos: Vector2 = e.position + Vector2(0, -20)
		var dist := hit_center.distance_to(e_pos)
		if dist <= aoe_radius:
			_apply_damage_and_effects_to(e, damage * 0.75, false)

	# 3. Tạo hiệu ứng hoạt ảnh nổ VLTK thật (Hit Anim Sprite)
	_spawn_vltk_hit_fx(hit_center)

	# 4. Hủy đạn
	queue_free()

func _apply_damage_and_effects_to(node2d: Node2D, dmg_val: float, is_direct: bool) -> void:
	if node2d == null or not is_instance_valid(node2d):
		return

	if node2d.has_method("take_damage"):
		node2d.take_damage(dmg_val, self)
	elif "health" in node2d:
		node2d.health -= dmg_val
		if node2d.health <= 0 and node2d.has_method("die"):
			node2d.die()

	# Hiển thị số sát thương nhảy lên
	if DamageNumberScene:
		var dmg_node = DamageNumberScene.instantiate()
		var dmg_pos = node2d.position + Vector2(randf_range(-15, 15), -40)
		var dmg_col := Color(1.0, 0.4, 0.15)
		if projectile_type in ["ice_flake", "ice", "water_sword"]:
			dmg_col = Color(0.4, 0.85, 1.0)
		elif projectile_type in ["poison_skull", "poison"]:
			dmg_col = Color(0.3, 0.95, 0.3)
		elif projectile_type in ["lightning", "buddha_palm", "blade_wave"]:
			dmg_col = Color(1.0, 0.95, 0.3)
		elif projectile_type in ["sword_beam", "sword_slash", "taiji"]:
			dmg_col = Color(0.7, 0.85, 1.0)
		elif projectile_type in ["sound_wave"]:
			dmg_col = Color(0.9, 0.7, 1.0)

		if dmg_node.has_method("setup"):
			dmg_node.setup(int(dmg_val), dmg_pos, dmg_col)
		var parent_node := get_parent()
		if parent_node != null:
			parent_node.add_child(dmg_node)

	# Áp dụng hiệu ứng
	if slow_ratio > 0.0 and node2d.has_method("apply_slow"):
		node2d.apply_slow(slow_ratio, slow_duration)
	elif slow_ratio > 0.0 and "speed" in node2d:
		node2d.speed *= (1.0 - slow_ratio)

	if poison_dps > 0.0 and node2d.has_method("apply_poison"):
		node2d.apply_poison(poison_dps, poison_duration)

	if stun_chance > 0.0 and (is_direct or randf() <= stun_chance) and node2d.has_method("apply_stun"):
		node2d.apply_stun(stun_duration)

## TẠO HOẠT ẢNH NỔ VLTK THẬT KHI TRÚNG ĐÍCH
func _spawn_vltk_hit_fx(center_pos: Vector2) -> void:
	var p_node := get_parent()
	if p_node == null:
		return

	var hit_spr := ThuThanhFxSpriteScript.new()
	hit_spr.position = center_pos
	hit_spr.z_index = 24
	p_node.add_child(hit_spr)

	var ok: bool = hit_spr.setup_fx(_hit_anim_key, 0, false, 18.0)
	if not ok:
		hit_spr.setup_fx("fx_c33e96c2", 0, false, 18.0)

	# Vòng sóng xung kích hỗ trợ lan tỏa (AoE Ring)
	var burst := Node2D.new()
	burst.position = center_pos
	burst.z_index = 22
	p_node.add_child(burst)

	var drawer := Node2D.new()
	drawer.set_script(load("res://systems/challenge/thu_thanh_burst_drawer.gd") if ResourceLoader.exists("res://systems/challenge/thu_thanh_burst_drawer.gd") else null)
	burst.add_child(drawer)

	burst.scale = Vector2(0.2, 0.2)
	var tw := burst.create_tween().set_parallel(true)
	tw.tween_property(burst, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(burst, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(burst.queue_free)

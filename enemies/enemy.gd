extends CharacterBody2D

const DamageNumberScene := preload("res://effects/damage_number.tscn")
const GemScene := preload("res://gems/Gem.tscn")
const PickupScene := preload("res://gems/Pickup.tscn")

var speed: float = 60.0
var contact_damage: float = 10.0
var max_health: float = 30.0
var exp_drop: float = 1.0
var gem_texture: Texture2D
var possible_drops: Array[PickupData] = []
## Snapshot combat CHÍNH XÁC 100% VLTK (AttackRating/Defense/Damage/Ngũ Hành) — dựng từ
## EnemyTierData lúc setup(), dùng khi quái gây damage "thật" qua CombatFormulas (xem
## _on_hit_area_body_entered). Xem CombatantStats + CombatFormulas (systems/combat/).
var combat_stats: CombatantStats

var health: float
var target: Node2D
## Bản dựng combat (CombatantBuild) của con quái này — giữ lại để dựng lại chỉ số khi dính buff/bùa.
var _build: CombatantBuild
## Phe (Camp.Type) — quái mặc định Camp.Type.ANIMAL (địch của mọi người chơi), xem CombatTargeting.
var camp: int = Camp.Type.ANIMAL

## Hình VLTK (EnemyTierData.vltk_monster_id): thay AnimatedSprite bằng sprite quái gốc + bóng gốc, đi/đứng theo hướng di chuyển.
var _vltk_id: int = -1
var _name_plate: NamePlate
var _vltk_sprite: MonsterSprite
var _vltk_data: Dictionary = {}
## Sát thương đòn đánh [nhỏ nhất, lớn nhất] theo công thức gốc của quái VLTK (-1 = quái không có dữ liệu gốc -> contact_damage).
var _vltk_damage := Vector2i(-1, -1)
var _vltk_dir64: int = 0
var _vltk_time: float = 0.0
## Đòn đánh của hình VLTK: áp sát (ATTACK_RANGE) thì diễn động tác "đánh" rồi gây sát thương ở 60% động tác — như quái VLTK.
const ATTACK_RANGE := 55.0
const ATTACK_FIRE_PERCENT := 0.6
var _atk_time: float = -1.0      ## < 0 = không đang đánh
var _atk_len: float = 1.0        ## giây
var _atk_hit: bool = false
var _atk_cooldown: float = 0.0

@onready var health_bar := $HealthBar
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var status_controller: StatusEffectController = $StatusEffectController

func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	$HitArea.body_entered.connect(_on_hit_area_body_entered)
	sprite.play("walk")

## `entry` gắn EnemyTierData gốc + hệ số nhân/thời điểm RIÊNG cho map đang chơi — xem
## stages/enemy_spawn_entry.gd. Contact damage/speed/scale vẫn lấy nguyên từ `entry.tier` (chưa hỗ
## trợ nhân theo map cho các field gameplay-ngoài-combat này).
func setup(entry: EnemySpawnEntry) -> void:
	var tier := entry.tier
	_build = entry.to_build()
	camp = _build.camp
	status_controller.clear_all()
	_use_vltk_look(tier.vltk_monster_id, tier.scale_override)
	_build_name_plate(tier)
	combat_stats = CombatantStats.build(_build)
	_apply_vltk_stats()
	max_health = float(combat_stats.max_hp)  ## HP CHÍNH XÁC 100% VLTK, suy từ Vitality — xem CombatantStats
	contact_damage = tier.contact_damage
	speed = tier.speed
	exp_drop = tier.exp_drop
	gem_texture = tier.gem_texture
	possible_drops = tier.possible_drops

	health = max_health
	health_bar.set_max_health(max_health)
	sprite.scale = sprite.scale * tier.scale_override
	if not status_controller.stats_changed.is_connected(refresh_combat_stats):
		status_controller.stats_changed.connect(refresh_combat_stats)

## Dựng lại combat_stats khi buff/bùa trên quái thêm/hết hạn — CÙNG CombatantStats.build() với player
## (xem Player.refresh_combat_stats). Giữ nguyên % máu hiện tại.
func refresh_combat_stats() -> void:
	if _build == null:
		return
	var health_ratio := health / max_health if max_health > 0.0 else 1.0
	combat_stats = CombatantStats.build(_build, status_controller.get_state_attrib_sources())
	_apply_vltk_stats()
	max_health = float(combat_stats.max_hp)
	health = max_health * health_ratio
	health_bar.set_max_health(max_health)
	health_bar.set_health(health)

## Quái có hình VLTK (EnemyTierData.vltk_monster_id) dùng luôn máu / phòng thủ / chính xác / sát thương GỐC của quái đó
## theo cấp (MonsterData.stat_at_level) thay cho số suy từ 4 chỉ số. Cấp = cấp của tier + level_add của map.
func _apply_vltk_stats() -> void:
	_vltk_damage = Vector2i(-1, -1)
	if _vltk_data.is_empty() or not _vltk_data.has("stats"):
		return
	var level := _build.level
	combat_stats.max_hp = maxi(1, MonsterData.stat_at_level(_vltk_data, "life", level))
	combat_stats.defense = MonsterData.stat_at_level(_vltk_data, "defense", level)
	combat_stats.attack_rating = MonsterData.stat_at_level(_vltk_data, "attack_rating", level)
	for sk in _vltk_data.get("skills", []):
		if int(sk[0]) > 0:
			_vltk_damage = MonsterData.melee_damage(_vltk_data, level, int(sk[0]), int(sk[1]))
			break

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_bar.set_health(health)

## Bảng tên + chấm màu hệ trên thanh máu. Quái VLTK: tên + hệ (Series) lấy từ dữ liệu gốc; quái thường: tên tier + hệ của tier.
func _build_name_plate(tier: EnemyTierData) -> void:
	var display_name := str(_vltk_data.get("name", "")).strip_edges() if not _vltk_data.is_empty() else ""
	if display_name == "":
		display_name = tier.tier_name
	var element: ElementTypes.ElementType = _build.element
	if not _vltk_data.is_empty() and _vltk_data.has("series"):
		element = clampi(int(_vltk_data["series"]), 0, 4) as ElementTypes.ElementType
	if _name_plate == null:
		_name_plate = NamePlate.new()
		add_child(_name_plate)
	_name_plate.setup(display_name, element)
	_name_plate.place_above(health_bar)

## Đổi hình sang quái VLTK `monster_id`: ẩn AnimatedSprite + bóng cũ, vẽ MonsterSprite đặt ở chân (chỗ bóng cũ).
func _use_vltk_look(monster_id: int, scale_factor: float) -> void:
	if monster_id < 0:
		return
	_vltk_data = MonsterData.monster(monster_id)
	if _vltk_data.is_empty():
		return
	_vltk_id = monster_id
	sprite.visible = false
	var old_shadow := get_node_or_null("Shadow") as Node2D
	var feet_y := old_shadow.position.y if old_shadow else 29.0
	if old_shadow:
		old_shadow.visible = false
	_vltk_sprite = MonsterSprite.new()
	_vltk_sprite.position = Vector2(0, feet_y)
	_vltk_sprite.scale = Vector2.ONE * scale_factor
	add_child(_vltk_sprite)
	_vltk_sprite.set_resource(str(_vltk_data["res"]))
	_vltk_dir64 = randi() % VltkMath.MAX_DIR
	health_bar.position = Vector2(health_bar.position.x, feet_y - _vltk_sprite.get_height() * scale_factor - 10.0)
	_update_vltk_pose(Vector2.ZERO, 0.0)

## Hướng đi -> hướng 64 VLTK; vận tốc 0 thì đứng yên (động tác "stand") giữ hướng cũ.
func _update_vltk_pose(direction: Vector2, delta: float) -> void:
	if _vltk_sprite == null:
		return
	_vltk_time += delta * VltkMath.FPS
	var moving := direction != Vector2.ZERO
	if moving:
		var d := VltkMath.dir_between(Vector2.ZERO, VltkMath.to_logic(direction))
		if d >= 0:
			_vltk_dir64 = d
	var action := "walk" if moving else "stand"
	var length := float(MonsterData.action_frames(_vltk_data, action))
	_vltk_sprite.set_pose(action, _vltk_dir64, fmod(_vltk_time, length) / length)

func _physics_process(delta: float) -> void:
	## Player đã chết (queue_free()) — target vẫn còn tham chiếu cũ (không tự về null), truy cập
	## target.global_position lúc này sẽ lỗi vì object đã bị giải phóng. Dừng hẳn di chuyển thay
	## vì không còn ai để đuổi theo nữa.
	if GameManager.is_game_over or target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		_update_vltk_pose(Vector2.ZERO, delta)
		return
	if status_controller.is_stunned:
		_atk_time = -1.0
		velocity = Vector2.ZERO
		move_and_slide()
		_update_vltk_pose(Vector2.ZERO, delta)
		return
	if _vltk_sprite != null:
		_atk_cooldown = maxf(0.0, _atk_cooldown - delta)
		var to_player := target.global_position - global_position
		if _atk_time >= 0.0:
			_tick_vltk_attack(delta)
			return
		if _atk_cooldown <= 0.0 and to_player.length() <= ATTACK_RANGE:
			_begin_vltk_attack(to_player)
			return
	var direction := (target.global_position - global_position).normalized()
	var speed_bonus := 1.0 + (combat_stats.move_speed_p / 100.0 if combat_stats else 0.0)
	velocity = direction * speed * speed_bonus * status_controller.move_speed_multiplier
	velocity = VltkWorld.slide_velocity(global_position + Vector2(0, VltkWorld.FEET_OFFSET), velocity, delta)
	move_and_slide()

	if direction.x != 0:
		sprite.flip_h = direction.x < 0
	_update_vltk_pose(direction, delta)

func _begin_vltk_attack(to_player: Vector2) -> void:
	_atk_time = 0.0
	_atk_hit = false
	_play_vltk_sound("attack1")
	_atk_len = float(MonsterData.action_frames(_vltk_data, "attack1")) / VltkMath.FPS
	var d := VltkMath.dir_between(Vector2.ZERO, VltkMath.to_logic(to_player))
	if d >= 0:
		_vltk_dir64 = d
	velocity = Vector2.ZERO
	_vltk_sprite.set_pose("attack1", _vltk_dir64, 0.0)

func _tick_vltk_attack(delta: float) -> void:
	_atk_time += delta
	velocity = Vector2.ZERO
	move_and_slide()
	if not _atk_hit and _atk_time >= _atk_len * ATTACK_FIRE_PERCENT:
		_atk_hit = true
		if is_instance_valid(target) and global_position.distance_to(target.global_position) <= ATTACK_RANGE * 1.4:
			_deal_contact_damage(target)
	_vltk_sprite.set_pose("attack1", _vltk_dir64, clampf(_atk_time / _atk_len, 0.0, 1.0))
	if _atk_time >= _atk_len:
		_atk_time = -1.0
		_atk_cooldown = _atk_len * 0.5

func take_damage(amount: float) -> void:
	health -= amount
	health_bar.set_health(health)
	spawn_damage_number(amount)
	play_hit_punch()
	if health <= 0:
		die()

## Nhận 1 đòn tấn công THẬT qua pipeline CombatFormulas (CHÍNH XÁC 100% VLTK) — xem
## Player.take_damage_from() để biết chi tiết từng bước. Enemy dùng combat_stats.defense (từ
## EnemyTierData.defense, tương ứng DefenseParam trong Npcs.txt gốc) để roll né đòn của player.
## mods: phần phụ của đòn skill (damage hệ thêm như Độc sát/Băng sát, chí mạng, ngũ hành tương khắc)
## — null với đòn thường (VD quái va chạm), xem CombatFormulas.HitModifiers.
func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: CombatFormulas.DamageType = CombatFormulas.DamageType.PHYSICS,
		attacker_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM,
		mods: CombatFormulas.HitModifiers = null) -> void:
	if combat_stats == null:
		## setup() chưa gọi (không nên xảy ra trong gameplay thật) — fallback damage thẳng để
		## không im lặng bỏ qua đòn đánh.
		take_damage(float(max_damage))
		return

	var final_damage := HitResolver.receive(self, combat_stats, int(health), attacker_stats,
			min_damage, max_damage, damage_type, attacker_element, mods)
	if final_damage == HitResolver.MISSED:
		spawn_miss_number()
		return
	if final_damage == 0:
		return  ## đòn chỉ mang trạng thái (bùa)

	health -= final_damage
	health_bar.set_health(health)
	spawn_damage_number(final_damage)
	play_hit_punch()
	if health <= 0:
		die()

func spawn_miss_number() -> void:
	var spawn_position := global_position + Vector2(0, -20)
	ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), spawn_position, func(number): number.set_miss())

## Gọi bởi StatusEffectController khi 1 DOT effect (burn/poison/bleed) tick — tách riêng khỏi
## take_damage() thường để không spam hit-punch animation mỗi tick.
func take_status_damage(amount: float, _effect_id: String) -> void:
	health -= amount
	health_bar.set_health(health)
	spawn_damage_number(amount)
	if health <= 0:
		die()

## Tiếng quái VLTK theo động tác (bảng npc动作声音表): bị đánh / chết / đánh. Quái không có hình VLTK thì im lặng.
func _play_vltk_sound(action: String) -> void:
	if _vltk_data.is_empty():
		return
	var stream := VltkSound.npc(str(_vltk_data.get("res", "")), action)
	if stream != null:
		SfxManager.play(stream, global_position)

func play_hit_punch() -> void:
	_play_vltk_sound("hurt")
	var look: Node2D = _vltk_sprite if _vltk_sprite != null else sprite
	var base_scale := look.get_meta("base_scale", look.scale) as Vector2
	look.set_meta("base_scale", base_scale)
	look.scale = base_scale * (1.25 if _vltk_sprite != null else 1.6)
	var tween := create_tween()
	tween.tween_property(look, "scale", base_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func die() -> void:
	_play_vltk_sound("die")
	if _vltk_sprite != null:
		## Cảnh chết đúng hình quái VLTK (xác nằm lại rồi mờ dần) thay cho hiệu ứng nổ chung.
		MonsterCorpse.spawn(get_parent(), _vltk_id, _vltk_dir64, _vltk_sprite.global_position, _vltk_sprite.scale.x)
	else:
		VfxManager.play("enemy_death", global_position)
	spawn_gem()
	spawn_random_drops()
	queue_free()

func spawn_random_drops() -> void:
	if possible_drops.is_empty():
		return

	var drop_position := global_position
	## Mỗi item roll độc lập theo đúng % của nó, nhưng chỉ item ĐẦU TIÊN trúng
	## trong danh sách được rớt ra — đảm bảo tối đa 1 vật phẩm mỗi lần chết.
	## Sắp xếp possible_drops trong Editor theo thứ tự ưu tiên (hiếm/quý đặt trước)
	## nếu muốn item hiếm được ưu tiên kiểm tra trước.
	for data in possible_drops:
		if randf() <= data.drop_chance:
			ObjectPool.acquire_deferred(PickupScene, get_parent(), drop_position, func(pickup): pickup.setup(data))
			return

func spawn_gem() -> void:
	var gem_exp := exp_drop
	var gem_tex := gem_texture
	ObjectPool.acquire_deferred(GemScene, get_parent(), global_position, func(gem):
		gem.exp_value = gem_exp
		if gem_tex:
			gem.get_node("Sprite").texture = gem_tex
	)

func spawn_damage_number(amount: float) -> void:
	var spawn_position := global_position + Vector2(0, -20)
	ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), spawn_position, func(number): number.set_damage(amount))

func _on_hit_area_body_entered(body: Node) -> void:
	if _vltk_sprite != null:
		return  ## hình VLTK đánh bằng động tác đánh (xem _tick_vltk_attack), không sát thương lúc chạm
	_deal_contact_damage(body)

func _deal_contact_damage(body: Node) -> void:
	## Ưu tiên take_damage_from() (pipeline CombatFormulas đầy đủ — roll trúng/né, tương khắc Ngũ
	## Hành, % kháng) khi target hỗ trợ (Player). Fallback take_damage() cho các body khác (VD test
	## scene chưa có take_damage_from) để không phá vỡ tương thích.
	if body.has_method("take_damage_from") and combat_stats:
		var min_dmg := int(contact_damage)
		var max_dmg := min_dmg
		if _vltk_damage.x >= 0:
			min_dmg = _vltk_damage.x
			max_dmg = _vltk_damage.y
		## Va chạm = đòn cận chiến -> bên bị đánh phản melee damage return về quái này.
		var mods := CombatFormulas.HitModifiers.new()
		mods.attacker_node = self
		mods.is_melee = true
		body.take_damage_from(combat_stats, min_dmg, max_dmg, CombatFormulas.DamageType.PHYSICS, combat_stats.element, mods)
	elif body.has_method("take_damage"):
		body.take_damage(contact_damage)

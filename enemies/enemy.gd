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
	combat_stats = CombatantStats.build(_build)
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
	max_health = float(combat_stats.max_hp)
	health = max_health * health_ratio
	health_bar.set_max_health(max_health)
	health_bar.set_health(health)

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_bar.set_health(health)

func _physics_process(_delta: float) -> void:
	## Player đã chết (queue_free()) — target vẫn còn tham chiếu cũ (không tự về null), truy cập
	## target.global_position lúc này sẽ lỗi vì object đã bị giải phóng. Dừng hẳn di chuyển thay
	## vì không còn ai để đuổi theo nữa.
	if GameManager.is_game_over or target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if status_controller.is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := (target.global_position - global_position).normalized()
	var speed_bonus := 1.0 + (combat_stats.move_speed_p / 100.0 if combat_stats else 0.0)
	velocity = direction * speed * speed_bonus * status_controller.move_speed_multiplier
	move_and_slide()

	if direction.x != 0:
		sprite.flip_h = direction.x < 0

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

func play_hit_punch() -> void:
	var base_scale := sprite.get_meta("base_scale", sprite.scale) as Vector2
	sprite.set_meta("base_scale", base_scale)
	sprite.scale = base_scale * 1.6
	var tween := create_tween()
	tween.tween_property(sprite, "scale", base_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func die() -> void:
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
	## Ưu tiên take_damage_from() (pipeline CombatFormulas đầy đủ — roll trúng/né, tương khắc Ngũ
	## Hành, % kháng) khi target hỗ trợ (Player). Fallback take_damage() cho các body khác (VD test
	## scene chưa có take_damage_from) để không phá vỡ tương thích.
	if body.has_method("take_damage_from") and combat_stats:
		var min_dmg := int(contact_damage)
		## Va chạm = đòn cận chiến -> bên bị đánh phản melee damage return về quái này.
		var mods := CombatFormulas.HitModifiers.new()
		mods.attacker_node = self
		mods.is_melee = true
		body.take_damage_from(combat_stats, min_dmg, min_dmg, CombatFormulas.DamageType.PHYSICS, combat_stats.element, mods)
	elif body.has_method("take_damage"):
		body.take_damage(contact_damage)

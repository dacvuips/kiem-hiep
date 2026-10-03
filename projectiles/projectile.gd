extends Area2D
class_name Projectile
## Ngoài damage/movement, Projectile phát signal để 1 hành vi tuỳ biến riêng (VD combo/effect
## phức tạp) có thể tự quyết định làm gì trong lúc bay hoặc khi trúng đích — KHÔNG cần
## Projectile biết trước combo là gì.

## Phát mỗi _physics_process trong lúc còn bay — Director dùng để tự quét AreaQuery quanh
## global_position mà không cần Projectile biết "aura" là gì. delta truyền kèm để Director tự
## trừ cooldown nội bộ đúng theo thời gian thật, không phải đoán qua Engine.physics_ticks.
signal traveled(global_pos: Vector2, delta: float)
## Phát khi trúng 1 target (trước khi Projectile tự xử lý damage mặc định) — Director dùng
## để thêm hiệu ứng phụ (nổ diện rộng khác, DoT, chain...) tại đúng thời điểm/vị trí va chạm.
signal hit_target(target: Node, global_pos: Vector2)

const BURST_COUNT = 4
const BURST_SPEED_RATIO = 0.8
const BURST_DAMAGE_RATIO = 0.5
const BURST_MAX_DISTANCE = 300.0
const BURST_MONITOR_DELAY = 0.08

const ProjectileScene := preload("res://projectiles/projectile.tscn")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 10.0
var is_burst: bool = false
var max_distance: float = -1.0
var traveled_distance: float = 0.0
var monitor_delay_remaining: float = 0.0

## Cách sprite xử lý hướng bay:
##  - FLIP_HORIZONTAL: chỉ lật ngang trái/phải (đúng cho sprite kiểu "nhân vật 2D", VD quả cầu
##    tròn hoặc hình có phối cảnh cố định — xoay 360° sẽ làm méo/trông sai).
##  - ROTATE_TO_DIRECTION: xoay rotation theo đúng góc bay thật (đúng cho sprite có hướng rõ
##    ràng như mũi tên/lưỡi kiếm/tia sét — cần "chỉ thẳng" theo mọi hướng, kể cả bắn chéo).
## Set từ ProjectileCastBehavior/Skill Director lúc spawn qua apply_orientation_mode(); mặc định
## FLIP_HORIZONTAL để không đổi hành vi của skill/đường bắn cũ (setup() qua StoneData).
enum OrientationMode { FLIP_HORIZONTAL, ROTATE_TO_DIRECTION }
var orientation_mode: OrientationMode = OrientationMode.FLIP_HORIZONTAL
## Tốc độ giảm mỗi giây — 0 = giữ nguyên tốc độ suốt hành trình (mặc định). Set qua
## apply_speed_decay(). Không bao giờ để speed xuống dưới 0.
var speed_decay_per_second: float = 0.0

## --- Gem System (resolved skill stats) — null nếu bắn theo đường cũ (StoneData.setup) ---
var resolved_stats: ResolvedSkillStats = null
## CombatantStats của người/quái BẮN viên đạn này — CHÍNH XÁC 100% VLTK cần AttackRating của bên
## tấn công để roll trúng/né (xem CombatFormulas.roll_hit), không thể suy ra chỉ từ `damage` cũ.
## null = fallback AttackRating cao (gần như luôn trúng, giữ hành vi "bullet-heaven" cũ) — set qua
## setup_from_resolved() khi caster có combat_stats (Player/Enemy đều có field này).
var attacker_stats: CombatantStats = null
## Phần phụ của đòn skill gửi kèm khi trúng — dựng lại mỗi lần setup_from_resolved() (per-instance).
var _hit_mods: CombatFormulas.HitModifiers = null
var _pierced_targets: Array = []
var _pierce_remaining: int = 0
var _chain_remaining: int = 0

## Mục tiêu đang bám (chỉ dùng khi resolved_stats.is_homing == true) — set từ ngoài qua
## setup_from_resolved()/set_homing_target(), Projectile tự xoay hướng bay về phía nó mỗi frame.
var homing_target: Node2D = null

## Hiệu ứng phụ chạy song song trong lúc bay (VD "tia sét tự động") — gắn từ
## ProjectileCastBehavior lúc spawn qua set_aura_effects(). Mỗi Projectile giữ state RIÊNG
## của mình (per-instance, không phải trên Resource dùng chung) nên nhiều player cùng dùng
## chung 1 skill vẫn không đụng độ dữ liệu — xem [[project-multiplayer-shared-skills]].
var _aura_effects: Array[ProjectileAuraEffect] = []
var _aura_states: Dictionary = {}  ## ProjectileAuraEffect -> Variant (state riêng của aura đó)

func set_aura_effects(effects: Array[ProjectileAuraEffect]) -> void:
	_aura_effects = effects
	_aura_states.clear()

func get_aura_state(aura: ProjectileAuraEffect, default_value: Variant) -> Variant:
	return _aura_states.get(aura, default_value)

func set_aura_state(aura: ProjectileAuraEffect, value: Variant) -> void:
	_aura_states[aura] = value

## SpriteFrames/scale gốc của scene (VD atlas "loc-xoay.png" + scale 0.14 mặc định) — lưu lại
## lúc _ready() để apply_flight_sprite_frames()/apply_visual_scale() có giá trị trả về khi
## skill không tùy chỉnh riêng, vì Projectile bị ObjectPool tái sử dụng cho nhiều skill khác
## nhau qua lại.
var _default_sprite_frames: SpriteFrames
var _default_sprite_scale: Vector2

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
	_default_sprite_frames = $Sprite.sprite_frames
	_default_sprite_scale = $Sprite.scale

## Đổi animation BAY (pha loop) theo skill đang bắn — dùng cho combo Fusion có sprite sheet
## AI-gen riêng (SkillGemData.flight_sprite_frames). override == null thì trả về animation mặc
## định của scene, vì node này có thể được ObjectPool tái dùng cho skill khác ngay sau đó.
## Animation impact (chạy 1 lần khi trúng đích) KHÔNG nằm ở đây — xem ImpactVfx.custom().
func apply_flight_sprite_frames(override: SpriteFrames) -> void:
	$Sprite.sprite_frames = override if override else _default_sprite_frames
	$Sprite.play("default")

## Phóng to/thu nhỏ HÌNH ẢNH viên đạn theo SkillGemData.visual_scale — chỉ đổi Sprite.scale,
## KHÔNG đụng tới CollisionShape2D nên bán kính va chạm/nổ thật (base_explosion_radius) vẫn
## tính độc lập theo đúng thiết kế "kích thước hiển thị tách biệt kích thước gameplay".
func apply_visual_scale(multiplier: float) -> void:
	$Sprite.scale = _default_sprite_scale * multiplier

## Dịch vị trí HÌNH ẢNH theo SkillGemData.visual_offset — dùng khi sprite AI-gen không canh
## đúng tâm, chỉnh cho khớp với vị trí va chạm thật (CollisionShape2D không đổi vị trí).
func apply_visual_offset(offset: Vector2) -> void:
	$Sprite.position = offset

## Set từ SkillGemData.orientation_mode — quyết định _physics_process() lật ngang hay xoay
## rotation theo hướng bay (xem enum OrientationMode để biết khi nào dùng cách nào).
func apply_orientation_mode(mode: OrientationMode) -> void:
	orientation_mode = mode
	if mode == OrientationMode.ROTATE_TO_DIRECTION:
		$Sprite.flip_h = false
	else:
		rotation = 0.0

## Set từ SkillGemData.speed_decay_per_second — 0 giữ nguyên hành vi cũ (tốc độ không đổi).
func apply_speed_decay(decay_per_second: float) -> void:
	speed_decay_per_second = decay_per_second

func setup(_direction: Vector2, stone: StoneData, damage_multiplier: float = 1.0) -> void:
	direction = _direction.normalized()
	speed = stone.speed
	damage = stone.damage * damage_multiplier
	is_burst = false
	max_distance = -1.0
	traveled_distance = 0.0
	rotation = 0.0
	monitoring = true
	monitorable = true
	monitor_delay_remaining = 0.0
	resolved_stats = null
	_pierced_targets.clear()
	_pierce_remaining = 0
	_chain_remaining = 0
	orientation_mode = OrientationMode.FLIP_HORIZONTAL
	speed_decay_per_second = 0.0
	_disconnect_director_signals()
	$Sprite.flip_h = direction.x < 0.0
	$Sprite.play("default")

## Bắn theo Gem System — dùng ResolvedSkillStats (đã tổng hợp Skill+Support+Element+Fusion Gem)
## thay vì StoneData thô. Giữ song song với setup() cũ để không phá code hiện có.
## target: mục tiêu ban đầu của viên đạn này — dùng làm homing_target nếu stats.is_homing.
## caster_stats: CombatantStats của người/quái bắn — truyền null nếu caster chưa có (fallback
## AttackRating cao, xem attacker_stats ở trên).
## caster_node: người bắn (để bên bị trúng phản đòn / người bắn hút máu) — null nếu không cần.
func setup_from_resolved(_direction: Vector2, stats: ResolvedSkillStats, target: Node2D = null, caster_stats: CombatantStats = null, caster_node: Node = null) -> void:
	direction = _direction.normalized()
	speed = stats.projectile_speed
	damage = stats.damage
	## Phần phụ của đòn (damage hệ, chí mạng ×2, ngũ hành tương khắc) — chí mạng roll 1 lần cho cả
	## viên đạn, CombatFormulas nhân ×2 cho từng loại damage lúc tính (đúng KNpc::CalcDamage).
	_hit_mods = stats.make_hit_mods(caster_node)
	is_burst = false
	max_distance = -1.0
	traveled_distance = 0.0
	rotation = 0.0
	monitoring = true
	monitorable = true
	monitor_delay_remaining = 0.0
	resolved_stats = stats
	attacker_stats = caster_stats
	_pierced_targets.clear()
	_pierce_remaining = stats.pierce_count
	_chain_remaining = stats.chain_count
	modulate = stats.color
	orientation_mode = OrientationMode.FLIP_HORIZONTAL
	speed_decay_per_second = 0.0
	homing_target = target if stats.is_homing else null
	set_aura_effects([])
	_disconnect_director_signals()
	$Sprite.flip_h = direction.x < 0.0
	$Sprite.play("default")

## ObjectPool tái sử dụng lại CÙNG 1 node cho lần cast tiếp theo (kể cả của skill/player khác)
## — nếu không gỡ hết listener cũ, 1 Skill Director đã connect traveled/hit_target ở lần
## cast TRƯỚC đó sẽ vẫn bị gọi nhầm khi node này bay cho 1 skill hoàn toàn khác. Bắt buộc gọi
## mỗi khi setup lại, kể cả setup() cũ.
func _disconnect_director_signals() -> void:
	for connection in traveled.get_connections():
		traveled.disconnect(connection["callable"])
	for connection in hit_target.get_connections():
		hit_target.disconnect(connection["callable"])

func _on_pool_release() -> void:
	monitoring = false
	monitorable = false

func _physics_process(delta: float) -> void:
	if monitor_delay_remaining > 0.0:
		monitor_delay_remaining -= delta
		if monitor_delay_remaining <= 0.0:
			monitoring = true
			monitorable = true

	if resolved_stats != null and resolved_stats.is_homing:
		_update_homing(delta)

	for aura in _aura_effects:
		aura.tick(self, delta)

	## Xử lý hướng hiển thị mỗi frame để tự đúng hướng cả khi is_homing/chain đổi direction
	## giữa chừng, không cần sửa riêng từng nơi gán direction. Xem OrientationMode.
	match orientation_mode:
		OrientationMode.ROTATE_TO_DIRECTION:
			rotation = direction.angle()
		_:
			if direction.x != 0.0:
				$Sprite.flip_h = direction.x < 0.0

	if speed_decay_per_second > 0.0:
		speed = max(0.0, speed - speed_decay_per_second * delta)

	var step := direction * speed * delta
	position += step
	traveled_distance += step.length()
	traveled.emit(global_position, delta)
	if max_distance > 0.0 and traveled_distance >= max_distance:
		_release()

## Xoay dần hướng bay về phía homing_target mỗi frame (không snap tức thì, dùng turn_speed
## để đạn vẫn có quán tính uốn cong tự nhiên). Tự tìm lại mục tiêu mới nếu target hiện tại
## đã chết/bị giải phóng, để đạn không "khựng" bay thẳng khi hết mục tiêu bám.
func _update_homing(delta: float) -> void:
	if homing_target == null or not is_instance_valid(homing_target):
		homing_target = _find_nearest_enemy_excluding(_pierced_targets)
		if homing_target == null:
			return
	var to_target := (homing_target.global_position - global_position).normalized()
	var turn_speed: float = resolved_stats.homing_turn_speed
	direction = direction.slerp(to_target, clamp(turn_speed * delta, 0.0, 1.0)).normalized()

func _find_nearest_enemy_excluding(exclude: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D) or exclude.has(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < nearest_distance:
			nearest_distance = dist
			nearest = enemy
	return nearest

func _on_area_entered(area: Area2D) -> void:
	_hit(area)

func _on_body_entered(body: Node2D) -> void:
	_hit(body)

func _hit(target: Node) -> void:
	if resolved_stats != null:
		_hit_with_resolved_stats(target)
		return

	if target.has_method("take_damage"):
		target.take_damage(damage)
	VfxManager.play("hit_explosion", global_position)
	if not is_burst:
		spawn_burst()
	_release()

func _hit_with_resolved_stats(target: Node) -> void:
	if _pierced_targets.has(target):
		return
	_pierced_targets.append(target)
	hit_target.emit(target, global_position)

	_deal_damage_to(target, damage)
	_apply_on_hit_status(target)
	VfxManager.play(resolved_stats.vfx_hit_name, global_position)
	SfxManager.play_skill_hit(resolved_stats, global_position)

	if resolved_stats.explosion_radius > 0.0:
		_explode_at(global_position)

	if _pierce_remaining > 0:
		_pierce_remaining -= 1
		return  ## xuyên tiếp, không release

	if _chain_remaining > 0:
		var next_target := _find_chain_target(target)
		if next_target:
			_chain_remaining -= 1
			direction = (next_target.global_position - global_position).normalized()
			return

	_release()

## Điểm tích hợp DUY NHẤT giữa Gem System (ResolvedSkillStats) và CombatFormulas (pipeline VLTK
## CHÍNH XÁC 100%: roll trúng/né theo AttackRating vs Defense, tương khắc Ngũ Hành, % kháng...).
## Ưu tiên take_damage_from() nếu target hỗ trợ (Player hiện đã có; Enemy dùng take_damage() thường
## nên vẫn rơi vào fallback bên dưới cho tới khi Enemy cũng chuyển sang take_damage_from()).
func _deal_damage_to(target: Node, amount: float) -> void:
	if target.has_method("take_damage_from"):
		var whole := int(amount)
		var stats := attacker_stats if attacker_stats else _fallback_attacker_stats()
		var damage_type: CombatFormulas.DamageType = resolved_stats.main_damage_type \
				if resolved_stats.main_damage_type >= 0 \
				else _combat_damage_type_for_element(resolved_stats.element)
		target.take_damage_from(stats, whole, whole, damage_type, resolved_stats.element, _hit_mods)
	elif target.has_method("take_damage"):
		target.take_damage(amount)

## Chưa có caster_stats (VD skill cũ chưa truyền, hoặc caster không phải Player/Enemy) — dùng
## AttackRating cao để giữ đúng cảm giác "bắn trúng gần như chắc chắn" của bullet-heaven hiện tại,
## khớp cùng fallback trong Player.take_damage()/Enemy tương lai.
func _fallback_attacker_stats() -> CombatantStats:
	var stats := CombatantStats.new()
	stats.attack_rating = 999
	return stats

## Map ElementTypes (hệ ngũ hành của game này) sang CombatFormulas.DamageType (loại kháng/giáp
## dùng trong pipeline VLTK gốc) — theo đúng ánh xạ đã dùng ở CharacterStatusScreen (Hỏa/Thủy/Thổ/
## Mộc/Kim ↔ Fire/Cold/Poison/Light/Physics).
func _combat_damage_type_for_element(element: ElementTypes.ElementType) -> CombatFormulas.DamageType:
	match element:
		ElementTypes.ElementType.HOA:
			return CombatFormulas.DamageType.FIRE
		ElementTypes.ElementType.THUY:
			return CombatFormulas.DamageType.COLD
		ElementTypes.ElementType.THO:
			return CombatFormulas.DamageType.POISON
		ElementTypes.ElementType.MOC:
			return CombatFormulas.DamageType.LIGHT
		_:
			return CombatFormulas.DamageType.PHYSICS

func _apply_on_hit_status(target: Node) -> void:
	if not target.has_node("StatusEffectController"):
		return
	var controller: StatusEffectController = target.get_node("StatusEffectController")
	for entry in resolved_stats.on_hit_status_effects:
		var chance: float = entry.get("chance", 1.0)
		if randf() > chance:
			continue
		var effect := StatusEffectFactory.create(
			entry.get("effect_id", ""),
			damage,
			resolved_stats.element,
			0.2,
			entry.get("duration", -1.0),
			entry.get("magnitude", -1.0)
		)
		controller.apply_effect(effect)

func _explode_at(center: Vector2) -> void:
	## explosion_radius balance theo "mét tượng trưng" (SkillGemData.base_explosion_radius +
	## Support Gem cộng dồn) — quy đổi sang pixel ở đây, cùng cách với AreaSkillEffect.setup(),
	## để so sánh đúng đơn vị với distance_to() (tính bằng pixel thật của world).
	var radius := GameplayUnits.meters_to_pixels(resolved_stats.explosion_radius)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D):
			continue
		if enemy.global_position.distance_to(center) <= radius and not _pierced_targets.has(enemy):
			_deal_damage_to(enemy, damage * 0.5)
			_apply_on_hit_status(enemy)

func _find_chain_target(exclude: Node) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	const CHAIN_RANGE := 250.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == exclude or _pierced_targets.has(enemy) or not (enemy is Node2D):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= CHAIN_RANGE and dist < nearest_distance:
			nearest_distance = dist
			nearest = enemy
	return nearest

func spawn_burst() -> void:
	var spawn_position := global_position
	var parent := get_parent()
	var base_speed := speed
	var base_damage := damage
	var base_angle := randf() * TAU
	for i in range(BURST_COUNT):
		var angle := base_angle + (TAU / BURST_COUNT * i)
		var burst_direction := Vector2.RIGHT.rotated(angle)
		ObjectPool.acquire_deferred(ProjectileScene, parent, spawn_position, func(projectile: Projectile):
			projectile.direction = burst_direction
			projectile.speed = base_speed * BURST_SPEED_RATIO
			projectile.damage = base_damage * BURST_DAMAGE_RATIO
			projectile.is_burst = true
			projectile.max_distance = BURST_MAX_DISTANCE
			projectile.traveled_distance = 0.0
			projectile.monitoring = false
			projectile.monitorable = false
			projectile.monitor_delay_remaining = BURST_MONITOR_DELAY
			projectile.rotation = 0.0
			projectile.get_node("Sprite").play("default")
		)

func _on_screen_exited() -> void:
	_release()

func _release() -> void:
	ObjectPool.release.call_deferred(self)

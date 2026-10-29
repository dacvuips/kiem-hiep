extends CharacterBody2D

signal died

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
## Cấu hình spawn của quái này ở map hiện tại (chứa các hệ số nhân strength/vitality/level_add).
var _entry: EnemySpawnEntry
## Bản dựng combat (CombatantBuild) của con quái này — giữ lại để dựng lại chỉ số khi dính buff/bùa.
var _build: CombatantBuild
var level: int:
	get: return _build.level if _build != null else 1
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
## Kỹ năng đánh xa / bắn đạn của quái VLTK (nếu có trong dữ liệu quái).
var _active_skill_id: int = 0
var _active_skill_level: int = 1
var _attack_radius: float = ATTACK_RANGE
var _attack_action: String = "attack1"

## VLTK gốc (NormalSync): gom sát thương theo chu kỳ (~0.2s) rồi mới hiển thị 1 số duy nhất,
## tránh spam số đè nhau khi trúng skill nhiều tia / hiệu ứng đa tầng.
const DAMAGE_BATCH_INTERVAL := 0.2
var _accumulated_damage: float = 0.0
var _damage_batch_timer: float = 0.0

@onready var health_bar := $HealthBar
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var status_controller: StatusEffectController = $StatusEffectController

var _base_sprite_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	collision_mask &= ~32  ## Quái đi xuyên vật cản (obstacle layer)
	_base_sprite_scale = sprite.scale
	target = get_tree().get_first_node_in_group("player")
	if not $HitArea.body_entered.is_connected(_on_hit_area_body_entered):
		$HitArea.body_entered.connect(_on_hit_area_body_entered)
	sprite.play("walk")

## `entry` gắn EnemyTierData gốc + hệ số nhân/thời điểm RIÊNG cho map đang chơi — xem
## stages/enemy_spawn_entry.gd. Contact damage/speed/scale vẫn lấy nguyên từ `entry.tier` (chưa hỗ
## trợ nhân theo map cho các field gameplay-ngoài-combat này).
func setup(entry: EnemySpawnEntry) -> void:
	_entry = entry
	var tier := entry.tier
	_build = entry.to_build()
	camp = _build.camp
	_accumulated_damage = 0.0
	_damage_batch_timer = 0.0
	status_controller.clear_all()
	_use_vltk_look(tier.vltk_monster_id, tier.scale_override)
	_build_name_plate(tier)
	combat_stats = CombatantStats.build(_build)
	_apply_vltk_stats()
	max_health = float(combat_stats.max_hp)  ## HP CHÍNH XÁC 100% VLTK, suy từ Vitality — xem CombatantStats
	contact_damage = tier.contact_damage * entry.strength_multiplier
	speed = tier.speed
	exp_drop = tier.exp_drop
	gem_texture = tier.gem_texture
	possible_drops = tier.possible_drops

	health = max_health
	health_bar.set_max_health(max_health)
	sprite.scale = _base_sprite_scale * tier.scale_override
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
	_active_skill_id = 0
	_active_skill_level = 1
	_attack_radius = ATTACK_RANGE
	_attack_action = "attack1"
	if _vltk_data.is_empty():
		return
	var lvl := level
	if _vltk_id >= 0:
		if _build != null:
			_vltk_data["series"] = int(_build.element)
		_vltk_data = MonsterData.apply_level_script(_vltk_data, _vltk_id, lvl)
	if not _vltk_data.has("stats"):
		return
	combat_stats.max_hp = maxi(1, MonsterData.stat_at_level(_vltk_data, "life", lvl))
	combat_stats.defense = MonsterData.stat_at_level(_vltk_data, "defense", lvl)
	combat_stats.attack_rating = MonsterData.stat_at_level(_vltk_data, "attack_rating", lvl)
	if _entry != null:
		combat_stats.max_hp = maxi(1, int(combat_stats.max_hp * _entry.vitality_multiplier))
		combat_stats.defense = int(combat_stats.defense * _entry.dexterity_multiplier)
		combat_stats.attack_rating = int(combat_stats.attack_rating * _entry.dexterity_multiplier)
	for sk in _vltk_data.get("skills", []):
		var sid := int(sk[0])
		var slv := int(sk[1])
		if sid <= 0:
			continue
		var eff_lv := slv if _vltk_data.get("skill_levels_exact", false) else clampi(slv + lvl / 5, 1, 30)
		if _vltk_damage.x < 0:
			_vltk_damage = MonsterData.melee_damage(_vltk_data, lvl, sid, eff_lv)
			if _entry != null and _vltk_damage.x >= 0:
				_vltk_damage = Vector2i(int(_vltk_damage.x * _entry.strength_multiplier), int(_vltk_damage.y * _entry.strength_multiplier))
		var s := VltkSkillData.skill(sid, eff_lv)
		if not s.is_empty():
			var rad := float(s.get("attack_radius", ATTACK_RANGE))
			var is_missile := int(s.get("style", 0)) == VltkSkillCaster.STYLE_MISSILES
			var is_melee := int(s.get("melee", 1)) == 1
			if is_missile and not is_melee and rad > ATTACK_RANGE and rad > _attack_radius:
				_active_skill_id = sid
				_active_skill_level = eff_lv
				_attack_radius = rad
				match int(s.get("char_anim", 9)):
					10: _attack_action = "attack2"
					11, 14: _attack_action = "magic"
					_: _attack_action = "attack1"

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
	if _vltk_sprite == null:
		_vltk_sprite = MonsterSprite.new()
		add_child(_vltk_sprite)
	_vltk_sprite.position = Vector2(0, feet_y)
	_vltk_sprite.scale = Vector2.ONE * scale_factor
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
	if _accumulated_damage > 0.0:
		_damage_batch_timer -= delta
		if _damage_batch_timer <= 0.0:
			_flush_damage_number()

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
		var dist_to_player := to_player.length()
		if _atk_time >= 0.0:
			_tick_vltk_attack(delta)
			return
		if _atk_cooldown <= 0.0 and dist_to_player <= _attack_radius:
			_begin_vltk_attack(to_player)
			return
		## Giữ cự ly dừng hợp lý, không lao xuyên tâm người chơi gây giật lắc qua lại
		var stop_dist := maxf(28.0, _attack_radius * 0.75) if _attack_radius <= ATTACK_RANGE else _attack_radius * 0.8
		if dist_to_player <= stop_dist:
			velocity = Vector2.ZERO
			move_and_slide()
			var d := VltkMath.dir_between(Vector2.ZERO, VltkMath.to_logic(to_player))
			if d >= 0:
				_vltk_dir64 = d
			_update_vltk_pose(Vector2.ZERO, delta)
			return
	var direction := (target.global_position - global_position).normalized()
	var speed_bonus := 1.0 + (combat_stats.move_speed_p / 100.0 if combat_stats else 0.0)
	velocity = direction * speed * speed_bonus * status_controller.move_speed_multiplier
	## Quái có thể đi xuyên vật cản (ignore_obstacles = true) để không kẹt cây/đá ngoài trời, nhưng vẫn bị chặn trong ô vuông ải
	velocity = VltkWorld.slide_velocity(global_position + Vector2(0, VltkWorld.FEET_OFFSET), velocity, delta, false, true)
	move_and_slide()

	if direction.x != 0:
		sprite.flip_h = direction.x < 0
	_update_vltk_pose(direction, delta)

func _begin_vltk_attack(to_player: Vector2) -> void:
	_atk_time = 0.0
	_atk_hit = false
	_play_vltk_sound(_attack_action)
	_atk_len = float(MonsterData.action_frames(_vltk_data, _attack_action)) / VltkMath.FPS
	var d := VltkMath.dir_between(Vector2.ZERO, VltkMath.to_logic(to_player))
	if d >= 0:
		_vltk_dir64 = d
	velocity = Vector2.ZERO
	_vltk_sprite.set_pose(_attack_action, _vltk_dir64, 0.0)

func _tick_vltk_attack(delta: float) -> void:
	_atk_time += delta
	velocity = Vector2.ZERO
	move_and_slide()
	if not _atk_hit and _atk_time >= _atk_len * ATTACK_FIRE_PERCENT:
		_atk_hit = true
		if _active_skill_id > 0:
			var s := VltkSkillData.skill(_active_skill_id, _active_skill_level)
			if not s.is_empty() and int(s.get("style", 0)) == VltkSkillCaster.STYLE_MISSILES and is_instance_valid(target):
				var ctx := VltkCastContext.new()
				ctx.launcher = self
				ctx.world = get_parent()
				ctx.stats = _make_hit_stats(_active_skill_id, _active_skill_level)
				ctx.attacker_stats = combat_stats
				ctx.target_group = &"player"
				VltkSkillCaster.cast(ctx, _active_skill_id, _active_skill_level, VltkMath.logic_of(target), target)
			elif is_instance_valid(target) and global_position.distance_to(target.global_position) <= _attack_radius * 1.4:
				_deal_contact_damage(target)
		elif is_instance_valid(target) and global_position.distance_to(target.global_position) <= _attack_radius * 1.4:
			_deal_contact_damage(target)
	_vltk_sprite.set_pose(_attack_action, _vltk_dir64, clampf(_atk_time / _atk_len, 0.0, 1.0))
	if _atk_time >= _atk_len:
		_atk_time = -1.0
		_atk_cooldown = _atk_len * 0.5

func _make_hit_stats(skill_id: int, skill_level: int) -> ResolvedSkillStats:
	var stats := ResolvedSkillStats.new()
	var lv := skill_level if _vltk_data.get("skill_levels_exact", false) else clampi(skill_level + level / 5, 1, 30)
	var skill_info := VltkSkillData.skill(skill_id, skill_level)
	var series := int(skill_info.get("series", -1))
	stats.element = (series if series >= 0 and series <= 4 else int(_build.element)) as ElementTypes.ElementType
	stats.main_damage_type = CombatFormulas.DamageType.PHYSICS

	var elements := {}
	var cold := VltkSkillData.hit_attrib(skill_id, "colddamage_v", lv)
	var fire := VltkSkillData.hit_attrib(skill_id, "firedamage_v", lv)
	var light := VltkSkillData.hit_attrib(skill_id, "lightingdamage_v", lv)
	var poison := VltkSkillData.hit_attrib(skill_id, "poisondamage_v", lv)
	if not cold.is_empty():
		elements[CombatFormulas.DamageType.COLD] = Vector2i(int(cold[0]), int(cold[2] if cold.size() > 2 else cold[0]))
		stats.freeze_frames = int(cold[1])
	if not fire.is_empty():
		elements[CombatFormulas.DamageType.FIRE] = Vector2i(int(fire[0]), int(fire[2] if fire.size() > 2 else fire[0]))
	if not light.is_empty():
		elements[CombatFormulas.DamageType.LIGHT] = Vector2i(int(light[0]), int(light[2] if light.size() > 2 else light[0]))
	if not poison.is_empty():
		var poison_damage := int(poison[0])
		elements[CombatFormulas.DamageType.POISON] = Vector2i(poison_damage, poison_damage)
		stats.poison_time_frames = int(poison[1])
		stats.poison_interval_frames = maxi(1, int(poison[2]))
	var stun := VltkSkillData.hit_attrib(skill_id, "stun_p", lv)
	if not stun.is_empty():
		stats.stun_chance_p = int(stun[0])
		stats.stun_frames = int(stun[1])
	var deadly := VltkSkillData.hit_attrib(skill_id, "deadlystrike_p", lv)
	if not deadly.is_empty():
		stats.crit_chance = clampf(float(deadly[0]) / 100.0, 0.0, 1.0)
	var series_p := VltkSkillData.hit_attrib(skill_id, "seriesdamage_p", lv)
	if not series_p.is_empty():
		stats.five_elements_damage_p = int(series_p[0])
	var ignore_def := VltkSkillData.hit_attrib(skill_id, "ignoredefense_p", lv)
	if not ignore_def.is_empty():
		stats.ignore_defense_percent = int(ignore_def[0])

	var is_physical := int(skill_info.get("physical", 1)) == 1
	var flat := VltkSkillData.hit_attrib(skill_id, "physicsdamage_v", lv)
	var enhance := VltkSkillData.hit_attrib(skill_id, "physicsenhance_p", lv)

	var stage_dmg_scale := _get_stage_damage_scale()
	if not _vltk_data.is_empty():
		var dmg := MonsterData.melee_damage(_vltk_data, level, skill_id, skill_level)
		var mult := (_entry.strength_multiplier if _entry != null else 1.0) * stage_dmg_scale
		if dmg.x >= 0 and is_physical:
			stats.damage_min = float(dmg.x) * mult
			stats.damage_max = float(dmg.y) * mult
			stats.damage = (stats.damage_min + stats.damage_max) * 0.5
		elif not is_physical:
			if not flat.is_empty():
				var f_min := float(flat[0]) * mult
				var f_max := float(flat[2] if flat.size() > 2 else flat[0]) * mult
				stats.damage_min = f_min
				stats.damage_max = f_max
				stats.damage = (f_min + f_max) * 0.5
			else:
				stats.damage_min = 0.0
				stats.damage_max = 0.0
				stats.damage = 0.0
		else:
			stats.damage_min = 0.0
			stats.damage_max = 0.0
			stats.damage = 0.0
	else:
		# Fallback cho Enemy thuần roguelite không có dữ liệu VLTK gốc
		var base_dmg := contact_damage * stage_dmg_scale
		if not enhance.is_empty():
			stats.damage = base_dmg * (100.0 + float(enhance[0])) / 100.0
		elif not flat.is_empty():
			stats.damage = (float(flat[0]) + float(flat[2] if flat.size() > 2 else flat[0])) * 0.5 + base_dmg * 0.5
		elif elements.is_empty():
			stats.damage = base_dmg
		else:
			stats.damage = 0.0
		if stats.damage > 0.0:
			stats.damage_min = maxf(1.0, stats.damage * 0.85)
			stats.damage_max = maxf(stats.damage_min, stats.damage * 1.15)
		else:
			stats.damage_min = 0.0
			stats.damage_max = 0.0

	var elem_mult := (_entry.strength_multiplier if _entry != null else 1.0) * stage_dmg_scale
	if elem_mult != 1.0:
		for t in elements:
			var rg: Vector2i = elements[t]
			elements[t] = Vector2i(int(rg.x * elem_mult), int(rg.y * elem_mult))

	var extra: Dictionary = combat_stats.outer_element_damage if is_physical else combat_stats.inner_element_damage
	for t in extra:
		elements[t] = elements.get(t, Vector2i.ZERO) + extra[t]
	stats.extra_damage_ranges = elements
	return stats

func take_damage(amount: float) -> void:
	health -= amount
	health_bar.set_health(health)
	_accumulate_damage(amount)
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
	_accumulate_damage(float(final_damage))
	play_hit_punch()
	if health <= 0:
		die()

func spawn_miss_number() -> void:
	var spawn_position := global_position + Vector2(0, -20)
	ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), spawn_position, func(number): number.set_miss())

## Gọi bởi StatusEffectController khi 1 DOT effect (burn/poison/bleed) tick — tách riêng khỏi
## take_damage() thường để không spam hit-punch animation mỗi tick.
func take_status_damage(amount: float, _effect_id: String, _source_node: Node = null) -> void:
	health -= amount
	health_bar.set_health(health)
	_accumulate_damage(amount)
	if health <= 0:
		die()

## Tiếng quái VLTK theo động tác (bảng npc动作声音表): bị đánh / chết / đánh. Quái không có hình VLTK thì im lặng.
func _play_vltk_sound(action: String) -> void:
	if _vltk_data.is_empty():
		return
	var stream := VltkSound.npc(str(_vltk_data.get("res", "")), action)
	if stream != null:
		SfxManager.play(stream, global_position)

func _interrupt_attack() -> void:
	if _atk_time >= 0.0:
		_atk_time = -1.0
		_atk_hit = true
		_atk_cooldown = maxf(_atk_cooldown, 0.35)
		if _vltk_sprite != null:
			var hurt_frames := MonsterData.action_frames(_vltk_data, "hurt")
			_vltk_sprite.set_pose("hurt" if hurt_frames > 0 else "stand", _vltk_dir64, 0.0)

func play_hit_punch() -> void:
	_play_vltk_sound("hurt")
	_interrupt_attack()
	var look: Node2D = _vltk_sprite if _vltk_sprite != null else sprite
	var base_scale := look.get_meta("base_scale", look.scale) as Vector2
	look.set_meta("base_scale", base_scale)
	look.scale = base_scale * (1.25 if _vltk_sprite != null else 1.6)
	var tween := create_tween()
	tween.tween_property(look, "scale", base_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

var _is_dead: bool = false

func is_dead() -> bool:
	return _is_dead

func _on_pool_acquire() -> void:
	_is_dead = false
	visible = true
	_accumulated_damage = 0.0
	_damage_batch_timer = 0.0
	_atk_time = -1.0
	_atk_hit = false
	_atk_cooldown = 0.0
	_vltk_time = 0.0
	modulate = Color.WHITE
	target = get_tree().get_first_node_in_group("player")
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", false)
	var hit_col := get_node_or_null("HitArea/CollisionShape2D") as CollisionShape2D
	if hit_col:
		hit_col.set_deferred("disabled", false)

func _on_pool_release() -> void:
	_is_dead = true
	if status_controller:
		status_controller.clear_all()
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)
	var hit_col := get_node_or_null("HitArea/CollisionShape2D") as CollisionShape2D
	if hit_col:
		hit_col.set_deferred("disabled", true)

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	died.emit()
	_flush_damage_number()
	_play_vltk_sound("die")
	if _vltk_sprite != null:
		## Cảnh chết đúng hình quái VLTK (xác nằm lại rồi mờ dần) thay cho hiệu ứng nổ chung.
		MonsterCorpse.spawn(get_parent(), _vltk_id, _vltk_dir64, _vltk_sprite.global_position, _vltk_sprite.scale.x)
	else:
		VfxManager.play("enemy_death", global_position)
	if PlayerStats.explosion_on_kill_chance > 0.0 and randf() < PlayerStats.explosion_on_kill_chance:
		_trigger_kill_explosion()
	spawn_gem()
	spawn_random_drops()
	if has_meta("pool_key"):
		ObjectPool.release(self)
	else:
		queue_free()

func _trigger_kill_explosion() -> void:
	var pos := global_position
	VfxManager.play("hit_explosion", pos)
	var tree := get_tree()
	if tree == null:
		return
	var enemies := tree.get_nodes_in_group("enemies")
	var base_dmg := 60.0 * PlayerStats.damage_multiplier
	for e in enemies:
		if e != null and is_instance_valid(e) and e != self and e is Node2D:
			if pos.distance_to(e.global_position) <= PlayerStats.explosion_radius:
				if e.has_method("take_damage"):
					e.take_damage(base_dmg * PlayerStats.explosion_damage_ratio)

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

func _accumulate_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if _accumulated_damage <= 0.0:
		_damage_batch_timer = DAMAGE_BATCH_INTERVAL
	_accumulated_damage += amount

func _flush_damage_number() -> void:
	if _accumulated_damage > 0.0:
		spawn_damage_number(_accumulated_damage)
		_accumulated_damage = 0.0
		_damage_batch_timer = 0.0

func spawn_damage_number(amount: float) -> void:
	var spawn_position := global_position + Vector2(0, -20)
	ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), spawn_position, func(number): number.set_damage(amount))

func _on_hit_area_body_entered(body: Node) -> void:
	if _vltk_sprite != null:
		return  ## hình VLTK đánh bằng động tác đánh (xem _tick_vltk_attack), không sát thương lúc chạm
	_deal_contact_damage(body)

func _get_stage_damage_scale() -> float:
	var scale := 1.0
	if _entry != null:
		scale *= _entry.damage_multiplier
	var st: StageData = GameManager.current_stage if GameManager else null
	if st != null:
		scale *= st.stage_monster_damage_multiplier
	return scale

func _deal_contact_damage(body: Node) -> void:
	## Ưu tiên take_damage_from() (pipeline CombatFormulas đầy đủ — roll trúng/né, tương khắc Ngũ
	## Hành, % kháng) khi target hỗ trợ (Player). Fallback take_damage() cho các body khác (VD test
	## scene chưa có take_damage_from) để không phá vỡ tương thích.
	var scale := _get_stage_damage_scale()
	if body.has_method("take_damage_from") and combat_stats:
		var min_dmg := int(contact_damage * scale)
		var max_dmg := min_dmg
		if _vltk_damage.x >= 0:
			min_dmg = int(_vltk_damage.x * scale)
			max_dmg = int(_vltk_damage.y * scale)
		## Va chạm = đòn cận chiến -> bên bị đánh phản melee damage return về quái này.
		var mods := CombatFormulas.HitModifiers.new()
		mods.attacker_node = self
		mods.is_melee = true
		if not combat_stats.outer_element_damage.is_empty():
			mods.extra_damages = combat_stats.outer_element_damage.duplicate()
		body.take_damage_from(combat_stats, min_dmg, max_dmg, CombatFormulas.DamageType.PHYSICS, combat_stats.element, mods)
	elif body.has_method("take_damage"):
		body.take_damage(contact_damage * scale)

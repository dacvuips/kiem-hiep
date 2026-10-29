extends CharacterBody2D
class_name PkBot
## ĐỐI THỦ BOT trong trận PK (PkMatch) — đánh như người chơi thật: hồ sơ nhân vật đầy đủ (PkBotProfile), chỉ số tính bằng đúng
## CombatantStats của người chơi, ra chiêu qua SectSkillController (cùng bộ máy chiêu VLTK, cấp skill đọc từ hồ sơ bot), nhận đòn
## qua HitResolver như Player, uống thuốc hồi sinh lực bằng PotionEffect (cùng công thức thuốc gốc).
## Gốc node = THÂN, chân = gốc + FEET_OFFSET (như Player / RemotePlayer) để sắp độ sâu cùng nhà/cây.
##
## AI (thiết kế của game này — VLTK gốc không có bot): đứng ngoài tầm thì chạy tới; trong tầm thì ra đòn chính, thỉnh thoảng
## chạy ngang (né đạn) như người thật; buff bản thân khi hết; máu dưới POTION_HP_RATIO thì uống thuốc (có độ trễ phản xạ).

signal died(bot: PkBot)

const FEET_OFFSET := 30.0
const SPEED := 150.0                     ## = Player.SPEED
const THINK_SEC := 0.15
const POTION_HP_RATIO := 0.5
const POTION_COOLDOWN := 3.0
const POTION_COUNT := 6                  ## số bình thuốc mang theo cả trận
const STRAFE_CHANCE := 0.12              ## mỗi lượt suy nghĩ trong tầm: xác suất chạy ngang 1 đoạn
const HealthBarScene := preload("res://ui/HealthBar.tscn")
const CharacterAura = preload("res://systems/effects/character_aura.gd")
const NAME_COLOR := Color(1.0, 0.3, 1.0)  ## tên đối thủ PK màu tím hồng (như RemotePlayer.PK_ENEMY_COLOR)

var profile: PlayerProfile
var combat_stats: CombatantStats
var max_health := 1.0
var health := 1.0
var max_mana := 1.0
var mana := 1.0
var camp: int = Camp.Type.FREE
## Luôn là địch của người chơi (CombatTargeting) — chiêu của người chơi trúng bot, bùa/buff của bot nhắm người chơi.
var pk_enemy := true
## Chiêu của bot gây sát thương nhóm này (VltkSkillRunner đọc thuộc tính này).
var cast_target_group: StringName = &"player"
## false = đứng yên không đánh (đếm ngược trước trận / trận đã xong).
var active := false
## true = không nhận sát thương (đếm ngược trước trận).
var invulnerable := true

var avatar: CharacterAvatar
var aura: AnimatedSprite2D
var status_controller: StatusEffectController
var skill_controller: SectSkillController
var target: Node2D
var potions_left := POTION_COUNT
var last_attacker: Node = null
var last_attacker_name: String = ""
var brawl_team: String = ""
var is_match_fighter: bool = false
var _name_label: Label = null

var _dead := false
var _main_skill: SkillDefinition
var _buffs: Array[SkillDefinition] = []
var _curses: Array[SkillDefinition] = []
var _think := 0.0
var _potion_ready := 0.0
var _potion_delay := -1.0               ## > 0: đang "phản xạ" trước khi uống
var _strafe_time := 0.0
var _strafe_dir := Vector2.ZERO
var _casting := false
var _health_bar: Node2D
var _potion_item: ItemInstance
var _path := PackedVector2Array()        ## lộ trình (điểm CHÂN) tới đối thủ — vòng qua giá vũ khí / rào
var _replan := 0.0
const REPLAN_SEC := 0.5
const WAYPOINT_RADIUS := 10.0

func setup(bot_profile: PlayerProfile) -> void:
	profile = bot_profile

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 32
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 10)
	shape.shape = rect
	shape.position = Vector2(0, FEET_OFFSET)
	add_child(shape)

	avatar = CharacterAvatar.new()
	avatar.name = "Avatar"
	avatar.position = Vector2(0, FEET_OFFSET)
	add_child(avatar)
	avatar.action_finished.connect(_on_action_finished)

	aura = CharacterAura.create_aura_node()
	aura.position = avatar.position + Vector2(0, 1)
	add_child(aura)

	status_controller = StatusEffectController.new()
	status_controller.name = "StatusEffectController"
	add_child(status_controller)
	status_controller.stats_changed.connect(_refresh_stats)

	var sect := SectRegistry.get_by_id(profile.sect_id)
	skill_controller = SectSkillController.new()
	skill_controller.name = "SectSkillController"
	skill_controller.owner_profile = profile
	add_child(skill_controller)
	skill_controller.setup(sect)

	_refresh_stats()
	health = max_health
	mana = max_mana
	_apply_look()
	_build_name_plate()
	_pick_skills(sect)
	_potion_item = _choose_potion()

func _apply_look() -> void:
	var gender := "female" if profile.gender == PlayerProfile.Gender.FEMALE else "male"
	var look := Equipment.get_appearance(profile.equipment, gender, false)
	var final_gender: String = str(look.get("gender", gender))
	avatar.voice_gender = final_gender
	avatar.set_gender(final_gender)
	avatar.set_appearance(look["helm"], look["armor"], look["weapon"], look["horse"])
	if look.has("modulate"):
		avatar.modulate = look["modulate"]
	else:
		avatar.modulate = Color.WHITE
	avatar.play("stand")

func _build_name_plate() -> void:
	var label := Label.new()
	label.text = profile.display_name
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", NAME_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 18)
	label.position = Vector2(-80, -66)
	add_child(label)
	_name_label = label
	_health_bar = HealthBarScene.instantiate()
	add_child(_health_bar)
	_health_bar.position = Vector2(0, -44)
	_health_bar.scale = Vector2(1.4, 0.7)
	_update_bar()

## Đổi màu tên và tiền tố phe (VD đấu đội Lộn Xộn: [Phe Xanh], [Phe Đỏ]).
func set_name_color(col: Color, prefix: String = "") -> void:
	if _name_label:
		_name_label.add_theme_color_override("font_color", col)
		if prefix != "":
			_name_label.text = "%s %s" % [prefix, profile.display_name if profile else ""]

func _update_bar() -> void:
	if _health_bar:
		_health_bar.set_max_health(max_health)
		_health_bar.set_health(health)

func _refresh_stats() -> void:
	var ratio := health / max_health if max_health > 0.0 else 1.0
	var mana_ratio := mana / max_mana if max_mana > 0.0 else 1.0
	combat_stats = profile.get_combat_stats(status_controller.get_state_attrib_sources())
	max_health = maxf(1.0, float(combat_stats.max_hp))
	health = max_health * ratio
	max_mana = maxf(1.0, float(combat_stats.max_mana))
	mana = max_mana * mana_ratio
	_update_bar()

## Đòn chính = skill đánh mạnh nhất (PkBotProfile.best_attack_skill); buff bản thân và bùa đã học, bộ máy chiêu chạy được.
func _pick_skills(sect: SectDefinition) -> void:
	_main_skill = skill_controller.get_main_skill()
	if sect == null:
		return
	for s in sect.skills:
		var s_lv: int = profile.get_skill_level(s.id) if profile != null else 0
		if s_lv <= 0 or s.category != SkillDefinition.SkillCategory.ACTIVE:
			continue
		if SectSkillController.is_self_buff(s):
			_buffs.append(s)
		elif s.is_state_skill() and s.target_enemy:
			_curses.append(s)

## Thuốc hồi sinh lực hợp với lượng máu: món có tổng lượng hồi gần 40% sinh lực tối đa nhất (misc_items.json, nguồn "potion").
func _choose_potion() -> ItemInstance:
	var best_id := ""
	var best_gap := INF
	for m in ItemDatabase.list_misc("potion"):
		var total := 0.0
		for e in m.get("effects", []):
			if str(e[0]) == "lifepotion_v":
				total += float(e[1]) * float(e[2]) / float(PotionEffect.UPDATE_FRAMES)
		if total <= 0.0:
			continue
		var gap := absf(total - max_health * 0.4)
		if gap < best_gap:
			best_gap = gap
			best_id = str(m["id"])
	return ItemGenerator.generate_misc(best_id) if best_id != "" else null

# ---------------------------------------------------------------- giao diện chung với Player (bộ máy chiêu / HitResolver gọi)

func get_ground_position() -> Vector2:
	return avatar.global_position if avatar else global_position + Vector2(0, FEET_OFFSET)

func is_dead() -> bool:
	return _dead

func can_cast() -> bool:
	return not _dead

func notify(_text: String) -> void:
	pass

func heal(amount: float) -> void:
	if _dead:
		return
	health = minf(max_health, health + amount)
	_update_bar()

func begin_skill_action(physical: bool, aim_position: Vector2, duration: float = -1.0) -> float:
	var to_aim := aim_position - global_position
	if to_aim.length() > 1.0:
		avatar.face(to_aim.normalized())
	_casting = true
	avatar.play("attack" if physical else "cast", duration)
	return avatar.get_action_duration() if duration <= 0.0 else duration

func on_hit_target(target: Node, skill_info: Dictionary = {}) -> void:
	if skill_controller != null and is_instance_valid(target) and target is Node2D:
		skill_controller.trigger_auto_attack_skills(self, target as Node2D, skill_info)

func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: CombatFormulas.DamageType = CombatFormulas.DamageType.PHYSICS,
		attacker_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM,
		mods: CombatFormulas.HitModifiers = null) -> void:
	if _dead or invulnerable:
		return
	if mods != null and mods.attacker_node != null:
		last_attacker = mods.attacker_node
		if "profile" in last_attacker and last_attacker.profile:
			last_attacker_name = str(last_attacker.profile.display_name)
		elif "display_name" in last_attacker:
			last_attacker_name = str(last_attacker.display_name)
		elif last_attacker.is_in_group("player") and GameManager.local_profile:
			last_attacker_name = str(GameManager.local_profile.display_name)
	var final_damage := HitResolver.receive(self, combat_stats, int(health), attacker_stats,
			min_damage, max_damage, damage_type, attacker_element, mods)
	if final_damage == HitResolver.MISSED or final_damage == 0:
		return
	_lose(float(final_damage))
	if not _dead:
		avatar.play_event_sound("hurt")

## Hồi sinh bot tại toạ độ chỉ định (chế độ Lộn Xộn / Loạn đả).
func respawn_at(spawn_pos: Vector2) -> void:
	_dead = false
	active = true
	invulnerable = false
	health = max_health
	_apply_look()
	avatar.play("stand")
	global_position = spawn_pos
	_update_bar()
	potions_left = POTION_COUNT
	last_attacker = null
	last_attacker_name = ""

func take_damage(amount: float) -> void:
	var a := CombatantStats.new()
	a.attack_rating = 999
	take_damage_from(a, int(amount), int(amount))

func take_status_damage(amount: float, _effect_id: String, source_node: Node = null) -> void:
	if not _dead and not invulnerable:
		if source_node != null:
			last_attacker = source_node
			if "profile" in last_attacker and last_attacker.profile:
				last_attacker_name = str(last_attacker.profile.display_name)
			elif "display_name" in last_attacker:
				last_attacker_name = str(last_attacker.display_name)
			elif last_attacker.is_in_group("player") and GameManager.local_profile:
				last_attacker_name = str(GameManager.local_profile.display_name)
		_lose(amount)

func _lose(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		_die()
	_update_bar()

func _die() -> void:
	if _dead:
		return
	_dead = true
	health = 0.0
	active = false
	velocity = Vector2.ZERO
	avatar.play_event_sound("die")
	avatar.play("sit")
	avatar.modulate = Color(0.75, 0.4, 0.95, 1.0)
	# Xử lý đồ sát / PK điểm nếu bị người chơi hạ gục ngoài chế độ thi đấu tournament
	if not is_match_fighter and last_attacker != null and is_instance_valid(last_attacker) and last_attacker.is_in_group("player"):
		var p_profile := GameManager.local_profile
		var player_node = last_attacker
		var pk_mode_val: int = player_node.get("pk_mode") if "pk_mode" in player_node else 0
		if pk_mode_val == 2 and p_profile != null:
			p_profile.pk_value = mini(10, p_profile.pk_value + 1)
			SaveManager.save_profile(p_profile)
			SaveManager.flush_online()
			var victim_name := profile.display_name if profile and profile.display_name != "" else "người chơi"
			var main_scene := get_tree().current_scene if get_tree() else null
			if main_scene and main_scene.has_method("_notify_player"):
				main_scene._notify_player("Bạn đã đồ sát %s! Trị PK tăng lên %d." % [victim_name, p_profile.pk_value])
	died.emit(self)

func _on_action_finished(finished: String) -> void:
	if finished == "attack" or finished == "cast":
		_casting = false
		avatar.play("stand")

# ---------------------------------------------------------------- AI

func _physics_process(delta: float) -> void:
	if _dead:
		return
	skill_controller.tick(delta)
	skill_controller.tick_aura(self, delta)
	velocity = Vector2.ZERO
	if not active or status_controller.is_stunned:
		_move(delta)
		return
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
	if target == null or (target.has_method("is_dead") and target.is_dead()):
		_move(delta)
		return
	_tick_potion(delta)
	_think -= delta
	if _think <= 0.0:
		_think = THINK_SEC
		_decide()
	if _strafe_time > 0.0 and not _casting:
		_strafe_time -= delta
		velocity = _strafe_dir * SPEED * status_controller.move_speed_multiplier
	elif not _casting and _logic_dist() > _attack_range() * 0.85:
		velocity = _chase_dir(delta) * SPEED * status_controller.move_speed_multiplier
	else:
		_path.clear()
	_move(delta)

## Hướng chạy tới đối thủ theo lộ trình tìm đường của map (tìm lại mỗi REPLAN_SEC giây); không có lộ trình thì chạy thẳng.
func _chase_dir(delta: float) -> Vector2:
	var feet := get_ground_position()
	_replan -= delta
	if _replan <= 0.0 or _path.is_empty():
		_replan = REPLAN_SEC
		_path = VltkWorld.find_path(feet, VltkMath.ground_of(target))
	while not _path.is_empty() and feet.distance_to(_path[0]) <= WAYPOINT_RADIUS:
		_path.remove_at(0)
	var goal: Vector2 = _path[0] if not _path.is_empty() else VltkMath.ground_of(target)
	return (goal - feet).normalized()

func _move(delta: float) -> void:
	if velocity != Vector2.ZERO:
		avatar.face(velocity.normalized())
		if not _casting and avatar.action != "run":
			avatar.play("run")
	elif not _casting and avatar.action == "run":
		avatar.play("stand")
	velocity = VltkWorld.slide_velocity(global_position, velocity, delta)
	move_and_slide()

func _decide() -> void:
	## Buff bản thân hết hạn -> ra lại (như người chơi bấm buff).
	for s in _buffs:
		if not status_controller.has_state(s.id) and skill_controller.try_cast_loop(s, self, self):
			return
	var dist := _logic_dist()
	if dist > _attack_range():
		return
	for s in _curses:
		if randf() < 0.3 and skill_controller.try_cast_loop(s, self, target):
			return
	if _main_skill != null and skill_controller.try_cast_loop(_main_skill, self, target):
		return
	## Đang hồi chiêu: thỉnh thoảng chạy ngang né đạn.
	if randf() < STRAFE_CHANCE:
		var to := (target.global_position - global_position).normalized()
		_strafe_dir = Vector2(-to.y, to.x) * (1.0 if randf() < 0.5 else -1.0)
		_strafe_time = randf_range(0.3, 0.7)

## Máu thấp: chờ 0,3-0,8 giây (phản xạ người thật) rồi uống 1 bình — còn thuốc, hết hồi bình trước, không đang có thuốc tác dụng.
func _tick_potion(delta: float) -> void:
	_potion_ready -= delta
	if _potion_delay > 0.0:
		_potion_delay -= delta
		if _potion_delay <= 0.0:
			_potion_delay = -1.0
			if potions_left > 0 and PotionEffect.drink(self, _potion_item):
				potions_left -= 1
				_potion_ready = POTION_COOLDOWN
		return
	if _potion_item == null or potions_left <= 0 or _potion_ready > 0.0 or health > max_health * POTION_HP_RATIO:
		return
	if PotionEffect.of(self).is_active():
		return
	_potion_delay = randf_range(0.3, 0.8)

## Tầm đòn chính (đơn vị logic VLTK như Player.get_skill_radius).
func _attack_range() -> float:
	if _main_skill != null:
		var r := _main_skill.get_attack_radius_at_level(1)
		if r > 0.0:
			return r
	return 150.0

func _logic_dist() -> float:
	return VltkMath.logic_of(self).distance_to(VltkMath.logic_of(target))

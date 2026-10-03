extends CharacterBody2D

const DamageNumberScene := preload("res://effects/damage_number.tscn")

const SPEED = 150.0
const INVINCIBLE_DURATION = 3.0
const INVINCIBLE_BLINKS = 3
## Vị trí (y) tên nhân vật khi đi bộ — ngay trên đầu nhân vật ghép — và độ nâng thêm khi cưỡi ngựa.
const NAME_LABEL_Y = -58.0
const RIDE_HEAD_RAISE = 24.0

@export var max_health: float = 100.0
@export var base_range: float = 150.0

## Máu hiện tại — mọi thay đổi (trúng đòn, độc, hồi máu, đổi chỉ số) phát health_changed cho HUD.
signal health_changed(health: float, max_health: float)
var health: float:
	set(value):
		health = value
		health_changed.emit(health, max_health)
var last_direction: Vector2 = Vector2.RIGHT
var is_invincible: bool = false
## Snapshot số liệu combat CHÍNH XÁC 100% VLTK (AttackRating/Defense/Damage/Kháng theo Ngũ Hành) —
## dựng từ PlayerProfile lúc _ready(), xem CombatantStats + CombatFormulas (systems/combat/).
var combat_stats: CombatantStats
## true = tự động thi triển skill khả dụng vào kẻ địch gần nhất; false = chờ người chơi bấm phím.
var is_auto_mode: bool = false
## Phe hiện tại (Camp.Type) = MÀU TÊN — đồng đội là người CÙNG MÀU (CombatTargeting). Lấy từ
## PlayerProfile.get_current_camp(); đổi qua set_camp() để tên đổi màu theo.
var camp: int = Camp.Type.BEGIN
## Bật PK: mới đánh/bùa được người chơi KHÁC màu (phe Sát thủ luôn đánh được).
var pk_enabled: bool = false
var _name_label: Label

## Bấm/chạm 1 điểm trên bản đồ -> chạy tới đó (giống VLTK). Giữ chuột/ngón tay -> chạy theo con trỏ.
## Bàn phím/joystick luôn ưu tiên và hủy điểm đến. Chỉ nhận cú bấm GUI không ăn (_unhandled_input),
## nên bấm lên nút/khung/joystick không làm nhân vật chạy.
const MOVE_ARRIVE_DISTANCE := 6.0
## Kẹt vật cản (đi không tới) quá lâu thì bỏ điểm đến, không giậm chân tại chỗ mãi.
const MOVE_STUCK_TIMEOUT := 0.4
var _move_target: Vector2
var _has_move_target: bool = false
var _move_follow_held: bool = false
var _move_stuck_time: float = 0.0
var _move_marker: Node2D

@onready var range_indicator := $RangeIndicator
## Nhân vật ghép bộ phận kiểu VLTK (mũ/áo/vũ khí đổi hình theo trang bị, 8 hướng) — xem CharacterAvatar.
@onready var avatar: CharacterAvatar = $Avatar
@onready var aura: AnimatedSprite2D = $Aura
@onready var status_controller: StatusEffectController = $StatusEffectController
@onready var skill_controller: SectSkillController = $SectSkillController

var is_attacking: bool = false
var is_casting: bool = false

func _ready() -> void:
	var profile := GameManager.local_profile
	combat_stats = profile.get_combat_stats() if profile else CombatantStats.new()
	## HP tối đa hiển thị/dùng trong màn chơi lấy từ CombatantStats (VLTK gốc), KHÔNG dùng
	## @export max_health cũ nữa — giữ @export chỉ để làm giá trị fallback khi chưa có profile
	## (VD chạy thẳng scene này trong Editor để test).
	if profile:
		max_health = float(combat_stats.max_hp)
	health = max_health
	range_indicator.set_radius(get_current_range())
	avatar.action_finished.connect(_on_avatar_action_finished)
	## Aura có sprite_frames gán sẵn trong scene nhưng KHÔNG autoplay — không có dòng này, nó
	## đứng yên tại đúng frame được lưu lúc chỉnh trong Editor, không bao giờ tự động chạy.
	aura.play("default")

	var sect := SectRegistry.get_by_id(profile.sect_id) if profile else null
	skill_controller.setup(sect)
	## Buff/bùa thêm hoặc hết hạn -> dựng lại chỉ số (CombatantStats.build gồm trạng thái đang dính).
	status_controller.stats_changed.connect(refresh_combat_stats)
	_build_name_label(profile.display_name if profile else "")
	refresh_appearance()
	set_camp(profile.get_current_camp() if profile else Camp.Type.BEGIN)
	_build_move_marker()

## Đổi phe (màu tên) — VD vào sự kiện/bang chiến, bật PK thành Sát thủ. Đồng đội tính lại tự động vì
## CombatTargeting đọc `camp` mỗi lần quét.
func set_camp(new_camp: int) -> void:
	camp = new_camp
	if _name_label:
		_name_label.add_theme_color_override("font_color", Camp.get_color(camp))

## Tên nhân vật trên đầu, tô màu theo phe (giống VLTK) — đặt ngay trên thanh máu.
func _build_name_label(display_name: String) -> void:
	_name_label = Label.new()
	_name_label.text = display_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.size = Vector2(160, 18)
	_name_label.position = Vector2(-80, NAME_LABEL_Y)
	add_child(_name_label)

## Dựng lại combat_stats từ profile — gọi sau khi học/nâng skill nội tại hoặc cộng điểm GIỮA trận
## (VD đóng bảng Kỹ Năng Võ Công) để bonus mới có hiệu lực ngay. Giữ nguyên % máu hiện tại.
func refresh_combat_stats() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	var health_ratio := health / max_health if max_health > 0.0 else 1.0
	combat_stats = profile.get_combat_stats(status_controller.get_state_attrib_sources())
	max_health = float(combat_stats.max_hp)
	health = max_health * health_ratio
	refresh_appearance()

## Mặc/tháo mũ, áo, vũ khí -> đổi hình nhân vật ngay (gọi kèm refresh_combat_stats sau mỗi lần đổi trang bị).
## Mới có bộ hình nam — nhân vật nữ tạm dùng hình nam cho tới khi nhập bộ nữ.
func refresh_appearance() -> void:
	var profile := GameManager.local_profile
	if profile == null or avatar == null:
		return
	var look := Equipment.get_appearance(profile.equipment)
	if look["helm"] != avatar.helm_res or look["armor"] != avatar.armor_res or look["weapon"] != avatar.weapon_res \
			or look["horse"] != avatar.horse_res:
		avatar.set_appearance(look["helm"], look["armor"], look["weapon"], look["horse"])
	## Cưỡi ngựa thì đầu cao hơn ~24px -> dời tên lên theo.
	if _name_label:
		_name_label.position.y = NAME_LABEL_Y - (RIDE_HEAD_RAISE if avatar.is_riding() else 0.0)

# ------------------------------------------------------------ bấm để chạy tới

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_set_move_target(get_global_mouse_position())
			_move_follow_held = true
		else:
			_move_follow_held = false

## Chạy tới 1 điểm theo TOẠ ĐỘ MÀN HÌNH (VD cú chạm trong vùng joystick — MoveJoystick.tapped).
func move_to_screen_position(screen_position: Vector2) -> void:
	_set_move_target(get_canvas_transform().affine_inverse() * screen_position)

func _set_move_target(world_position: Vector2) -> void:
	_move_target = world_position
	_has_move_target = true
	_move_stuck_time = 0.0
	_move_marker.global_position = world_position
	_move_marker.visible = true

func _clear_move_target() -> void:
	_has_move_target = false
	_move_follow_held = false
	_move_marker.visible = false

## Hướng chạy tới điểm đến (Vector2.ZERO = không có / đã tới nơi).
func _get_move_target_vector(delta: float) -> Vector2:
	if not _has_move_target:
		return Vector2.ZERO
	## Đang giữ chuột: điểm đến bám theo con trỏ (nhả ở chỗ nào cũng phải dừng bám, kể cả trên UI).
	if _move_follow_held:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_set_move_target(get_global_mouse_position())
		else:
			_move_follow_held = false
	var to_target := _move_target - global_position
	if to_target.length() <= MOVE_ARRIVE_DISTANCE:
		if not _move_follow_held:
			_clear_move_target()
		return Vector2.ZERO
	## Kẹt: vận tốc thực sau move_and_slide gần 0 dù đang muốn chạy.
	if not is_attacking and get_real_velocity().length() < 5.0:
		_move_stuck_time += delta
		if _move_stuck_time >= MOVE_STUCK_TIMEOUT and not _move_follow_held:
			_clear_move_target()
			return Vector2.ZERO
	else:
		_move_stuck_time = 0.0
	return to_target.normalized()

## Vòng tròn nhỏ đánh dấu điểm đến — top_level để đứng yên trên bản đồ, không chạy theo nhân vật.
func _build_move_marker() -> void:
	_move_marker = MoveTargetMarker.new()
	_move_marker.top_level = true
	_move_marker.visible = false
	_move_marker.z_index = -1
	add_child(_move_marker)

func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2.ZERO:
		if _has_move_target:
			_clear_move_target()
	else:
		input_vector = _get_move_target_vector(delta)
	## Choáng (m_StunState gốc): đứng yên, không di chuyển/ra chiêu (_try_cast cũng tự chặn).
	if status_controller.is_stunned:
		input_vector = Vector2.ZERO
		_move_stuck_time = 0.0
	if input_vector != Vector2.ZERO and not is_attacking:
		last_direction = input_vector
		update_facing(input_vector)

	## Làm chậm (Băng sát) giảm tốc độ chạy theo StatusEffectController.move_speed_multiplier.
	## fastwalkrun_p (buff tốc chạy, VD Thanh Phong phù) cộng % tốc độ gốc.
	var speed := SPEED * (1.0 + combat_stats.move_speed_p / 100.0) * status_controller.move_speed_multiplier
	velocity = Vector2.ZERO if is_attacking else input_vector * speed
	move_and_slide()

	if not is_attacking and not is_casting:
		update_move_animation(input_vector)

	if Input.is_action_just_pressed("attack") and not is_attacking:
		play_attack()

	range_indicator.set_radius(get_current_range())

	if Input.is_action_just_pressed("toggle_auto"):
		is_auto_mode = not is_auto_mode

	## Bị làm chậm thì hồi chiêu cũng chậm theo — VLTK bỏ qua 1/2 frame MỌI hành động khi đóng băng.
	skill_controller.tick(delta * status_controller.move_speed_multiplier)
	var target := get_nearest_enemy()

	## Auto CHỈ tự động đòn chính — skill phụ (phím skill_1-4) luôn phải bấm thủ công, kể cả khi
	## đang bật Auto, xem SectSkillController.try_cast_auto().
	if is_auto_mode:
		if target and skill_controller.try_cast_auto(self, target):
			play_cast()
	elif Input.is_action_just_pressed("attack_skill"):
		## Không bắt buộc có mục tiêu ở đây — skill buff lên mình thi triển được khi không có quái gần,
		## SectSkillController._try_cast tự từ chối đòn đánh thiếu mục tiêu.
		if skill_controller.try_cast_main(self, get_cast_target()):
			play_cast()

	## Phím skill_1-4 = 4 ô đầu của trang thanh skill đang chọn.
	var page_start: int = GameManager.local_profile.hotbar_page * PlayerProfile.HOTBAR_SLOTS_PER_PAGE 			if GameManager.local_profile else 0
	for i in range(4):
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			if skill_controller.try_cast_skill(page_start + i, self, get_cast_target()):
				play_cast()

func update_facing(direction: Vector2) -> void:
	avatar.face(direction)

func update_move_animation(input_vector: Vector2) -> void:
	var anim_name := "run" if input_vector != Vector2.ZERO else "stand"
	if avatar.action != anim_name:
		avatar.play(anim_name)

func play_attack() -> void:
	is_attacking = true
	_face_nearest_enemy()
	avatar.play("attack")

## Ra chiêu: quay về phía mục tiêu gần nhất rồi diễn động tác thi triển (chạy 1 lần, xong tự về đứng/chạy).
func play_cast() -> void:
	if is_attacking or is_casting:
		return
	is_casting = true
	_face_nearest_enemy()
	avatar.play("cast")

## Mục tiêu khi người chơi TỰ ra chiêu (phím / nút skill), theo khung "Tùy chỉnh kỹ năng":
##   - Đánh theo hướng trước mặt: luôn là 1 điểm phía trước mặt (không nhắm quái).
##   - Không mục tiêu: quái gần nhất, không có quái thì điểm phía trước mặt (vẫn ra chiêu được).
##   - Mặc định: quái gần nhất (null = không ra được chiêu đánh, buff lên mình vẫn được).
func get_cast_target() -> Node2D:
	var profile := GameManager.local_profile
	if profile and profile.get_skill_setting("face_direction"):
		return _make_cast_point()
	var target := get_nearest_enemy()
	if target == null and profile and profile.get_skill_setting("no_target"):
		return _make_cast_point()
	return target

## Điểm mục tiêu ảo phía trước mặt (meta "cast_point" — SectSkillCast/bùa nhận biết để không đuổi/áp trạng thái
## lên nó); tự huỷ sau vài giây.
const CAST_POINT_DISTANCE := 220.0
func _make_cast_point() -> Node2D:
	var point := Node2D.new()
	point.set_meta("cast_point", true)
	get_parent().add_child(point)
	point.global_position = global_position + last_direction.normalized() * CAST_POINT_DISTANCE
	get_tree().create_timer(3.0).timeout.connect(point.queue_free)
	return point

func _face_nearest_enemy() -> void:
	if GameManager.local_profile and GameManager.local_profile.get_skill_setting("face_direction"):
		avatar.face(last_direction)  ## đánh theo hướng đang quay — không xoay về quái
		return
	var target := get_nearest_enemy()
	if target:
		last_direction = (target.global_position - global_position).normalized()
	avatar.face(last_direction)

## Động tác ra chiêu của bộ máy chiêu VLTK (VltkSkillRunner): quay về điểm nhắm, ngoại công diễn "đánh", nội công
## diễn "thi triển". Trả về thời lượng động tác (giây) — đạn bắn ở 60% thời lượng này.
func begin_skill_action(physical: bool, aim_position: Vector2) -> float:
	var to_aim := aim_position - global_position
	if to_aim.length() > 1.0:
		last_direction = to_aim.normalized()
	avatar.face(last_direction)
	is_casting = true
	avatar.play("attack" if physical else "cast")
	return avatar.get_action_duration()

func _on_avatar_action_finished(finished: String) -> void:
	if finished == "attack" and is_attacking:
		is_attacking = false
	elif finished == "cast" or finished == "attack":
		is_casting = false
	else:
		return
	avatar.play("stand")

## Điểm chân nhân vật (avatar đặt lệch xuống so với gốc node) — bộ máy chiêu VLTK lấy làm toạ độ người thi triển.
func get_ground_position() -> Vector2:
	return avatar.global_position

func get_current_range() -> float:
	return base_range * PlayerStats.range_multiplier

func get_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_distance: float = INF
	var max_range := get_current_range()
	for enemy in enemies:
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= max_range and distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest

func heal(amount: float) -> void:
	health = min(max_health, health + amount)

## Nhận 1 đòn tấn công THẬT — chạy đúng pipeline CombatFormulas.resolve_damage (CHÍNH XÁC 100%
## VLTK: tương khắc Ngũ Hành, % kháng, chí mạng...). `attacker_stats` là CombatantStats của bên gây
## damage (Enemy dùng CombatantStats.from_enemy_tier(), Player khác dùng combat_stats của chính nó
## khi PvP online sau này) — bắt buộc truyền vào để roll trúng/né đúng AttackRating vs Defense của
## CHÍNH player này, không còn dùng % giảm sát thương cố định (PlayerDefenseStats cũ, đã xoá).
## mods: phần phụ của đòn skill — xem Enemy.take_damage_from() / CombatFormulas.HitModifiers.
func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: CombatFormulas.DamageType = CombatFormulas.DamageType.PHYSICS,
		attacker_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM,
		mods: CombatFormulas.HitModifiers = null) -> void:
	if is_invincible:
		return
	var final_damage := HitResolver.receive(self, combat_stats, int(health), attacker_stats,
			min_damage, max_damage, damage_type, attacker_element, mods)
	if final_damage == HitResolver.MISSED:
		spawn_miss_text()
		return
	if final_damage == 0:
		return  ## đòn chỉ mang trạng thái (bùa)

	health -= final_damage
	if health <= 0:
		die()
	else:
		start_invincibility()

## Đường tắt cho va chạm đơn giản (enemy contact_damage kiểu bullet-heaven hiện tại — không phải
## đòn "thật" có AttackRating riêng) — bọc thành 1 đòn physics tay không với AttackRating cố định
## cao (100 = luôn gần như trúng, giữ đúng cảm giác "chạm là dính" của thể loại này) cho tới khi
## enemy có CombatantStats riêng đầy đủ qua from_enemy_tier(). Enemy nên gọi take_damage_from()
## trực tiếp với CombatantStats thật của nó khi đã setup xong (xem enemy.gd).
func take_damage(amount: float) -> void:
	var fallback_attacker := CombatantStats.new()
	fallback_attacker.attack_rating = 999  ## Gần như luôn trúng — khớp cảm giác va chạm "chắc trúng"
	var whole := int(amount)
	take_damage_from(fallback_attacker, whole, whole)

func spawn_miss_text() -> void:
	var spawn_position := global_position + Vector2(0, -20)
	ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), spawn_position, func(number): number.set_miss())

## Gọi bởi StatusEffectController khi trúng DOT (nếu về sau player bị debuff từ boss).
func take_status_damage(amount: float, _effect_id: String) -> void:
	health -= amount
	if health <= 0:
		die()

func start_invincibility() -> void:
	is_invincible = true
	var blink_interval := INVINCIBLE_DURATION / (INVINCIBLE_BLINKS * 2.0)
	for i in range(INVINCIBLE_BLINKS * 2):
		avatar.modulate = Color(1, 0.3, 0.3, 1) if i % 2 == 0 else Color(1, 1, 1, 1)
		await get_tree().create_timer(blink_interval).timeout
	avatar.modulate = Color(1, 1, 1, 1)
	is_invincible = false

func die() -> void:
	print("Player died")
	GameManager.notify_game_over()
	queue_free()

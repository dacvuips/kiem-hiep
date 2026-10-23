extends CharacterBody2D
class_name VltkMonster
## QUÁI VLTK GỐC chạy theo dữ liệu Npcs.txt + hình ảnh/skill nhập bởi tools/import_vltk_monsters.py:
##   - đi / đứng / bị đánh / chết với hình đúng từng động tác, 8 hướng, thời lượng theo số frame gốc (18 nhịp/giây);
##   - AI theo KNpcAI::ProcessAIType01 gốc (tuần tra, giữ vùng hoạt động, chọn skill 1-4 theo xác suất, đuổi tới tầm đánh);
##   - đánh bằng đúng skill 1-4 của quái (đạn/vùng nổ qua bộ máy chiêu VltkSkillCaster, nhắm vào người chơi).
## Dùng chung giao diện "quái" của game (nhóm "enemies", take_damage_from, StatusEffectController, combat_stats, camp) nên
## mọi skill của người chơi đánh được và tính trúng/né/kháng/độc/choáng như quái thường.
## Máu / sát thương / phòng thủ / chính xác theo cấp lấy từ công thức gốc VLTK (MonsterData.stat_at_level); quái nào
## chưa có dữ liệu gốc thì dùng chỉ số thử nghiệm suy từ cấp.

signal died(monster: VltkMonster)

const DamageNumberScene := preload("res://effects/damage_number.tscn")
const HealthBarScene := preload("res://ui/HealthBar.tscn")
const StatusControllerScript := preload("res://systems/effects/status_effect_controller.gd")

enum State { IDLE, WALK, ATTACK, HURT, DEAD }

const FPS := 18.0
## Đạn bắn ở 60% động tác (ATTACKACTION_EFFECT_PERCENT gốc) — giống VltkSkillRunner.
const ATTACK_FIRE_PERCENT := 0.6
const DEFAULT_ATTACK_RADIUS := 75.0
const CORPSE_STAY := 1.0
const CORPSE_FADE := 0.6

## VLTK gốc (NormalSync): gom sát thương theo chu kỳ (~0.2s) rồi mới hiển thị 1 số duy nhất,
## tránh spam số đè nhau khi trúng skill nhiều tia / hiệu ứng đa tầng.
const DAMAGE_BATCH_INTERVAL := 0.2
var _accumulated_damage: float = 0.0
var _damage_batch_timer: float = 0.0

var monster_id: int = 0
var data: Dictionary = {}
var level: int = 1
## BOSS XANH (script server Revive: ~2% mỗi lần quái sinh): tên xanh dương, kháng 75% mọi loại, sát thương x3 (cấp 50+, thấp hơn thì x2),
## nhanh hơn, rớt 5 lần (DropTable.roll_blue_boss). Đặt TRƯỚC khi add_child.
var blue_boss: bool = false
## BOSS HOÀNG KIM (10 Đại Boss Hoàng Kim môn phái): tên vàng óng, hào quang, chỉ số cực cao, rơi bảo vật & trang bị hoàng kim.
var gold_boss: bool = false
## TIỂU HOÀNG KIM (Diệu Như, Liễu Thanh Thanh, Trương Tông Chính): bảo vật, bí kíp, thủy tinh.
var small_gold_boss: bool = false
## BOSS SÁT THỦ (Nhiếp Thí Trần truy nã): thưởng trang bị danh dự.
var killer_boss: bool = false
## Độ khó ĐỊA NGỤC (1-5 sao, 0 = map thường): máu, sát thương và tỉ lệ rơi đồ nhân số sao (DropTable.roll_hell). Đặt TRƯỚC khi add_child.
var hell_stars: int = 0
## false = quái đứng yên (tắt AI) — để xem hình hoặc để người chơi tập đánh.
var ai_enabled: bool = true
var camp: int = Camp.Type.ANIMAL
var combat_stats: CombatantStats
var health: float = 1.0
var max_health: float = 1.0
var status_controller: StatusEffectController
## Phe trong Chiến Trường / MOBA Tống Kim LOL ("song", "jin" hoặc "")
var battle_side: String = ""
var target: Node2D = null

## MOBA Tống Kim LOL: lính hành quân 3 đường & tướng soái
var is_lane_creep: bool = false
var lane_waypoints: Array[Vector2] = []
var lane_waypoint_idx: int = 0
var moba_damage_multiplier: float = 1.0
var is_moba_general: bool = false
var _foe_search_timer: float = 0.0

var _build: CombatantBuild
var _sprite: MonsterSprite
var _health_bar: Node2D
var _state: State = State.IDLE
var _action: String = "stand"
var _state_frames: float = 0.0   ## game frame đã trôi trong trạng thái này
var _state_len: float = 1.0      ## độ dài (game frame) của 1 vòng động tác
var _dir64: int = 0
var _origin_logic: Vector2 = Vector2.ZERO
var _cur_active: float = 0.0
var _walk_dest: Vector2 = Vector2.ZERO
var _ai_time: float = 0.0
var _game_time: float = 0.0
var _skill_ready: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _active_slot: int = 0
var _fired: bool = false
var _death_time: float = 0.0
var _max_radius: float = -1.0
var _last_walk_pos: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0
var _avoid_timer: float = 0.0
var _avoid_dir: Vector2 = Vector2.ZERO
var _ghost_timer: float = 0.0
var _nav_path: PackedVector2Array = PackedVector2Array()
var _nav_goal: Vector2 = Vector2.ZERO

## ONLINE: quái do game server điều khiển (net_eid != 0). Không chạy AI / không tự trừ máu: vị trí + động tác lấy từ
## server (nội suy), sát thương mình gây được báo lên server, chiêu của quái chỉ ra khi server báo (S_MATTACK).
var net_eid: int = 0
## > 0: máu cố định (bỏ qua máu theo cấp của bảng quái) — quái ải Thách Thức Thời Gian dùng máu gốc của script ải.
var hp_override: int = 0
var _net_buffer: Array = []       ## [{t, pos, dir, action, hp, flags}] theo giờ server
var _net_real_attack := false     ## đòn đang ra nhắm vào chính mình -> gây sát thương thật
var _last_predicted_dmg_ms: int = 0 ## thời điểm gần nhất client gây sát thương (chống rubberband máu)
const NET_INTERP_DELAY_MS := 140.0

## Tạo quái `monster_id` (STT Npcs.txt) cấp `lvl` tại `world_pos`. null nếu không có dữ liệu.
## `series_override` 0-4 (Kim..Thổ) = ép hệ ngũ hành của quái này (dùng để thử tương khắc); -1 = theo bảng quái gốc.
static func spawn(parent: Node, id: int, lvl: int, world_pos: Vector2, with_ai: bool = true, series_override: int = -1) -> VltkMonster:
	var m := MonsterData.monster(id)
	if m.is_empty() or parent == null:
		return null
	var node := VltkMonster.new()
	node.monster_id = id
	node.data = m
	if series_override >= 0 and series_override <= 4:
		node.data = m.duplicate()   ## không ghi đè vào bảng quái dùng chung
		node.data["series"] = series_override
	node.level = maxi(1, lvl)
	node.ai_enabled = with_ai
	node.position = world_pos
	parent.add_child(node)
	return node

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 32
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)

	_sprite = MonsterSprite.new()
	add_child(_sprite)
	_sprite.set_resource(str(data.get("res", "")))

	status_controller = StatusControllerScript.new()
	status_controller.name = "StatusEffectController"
	add_child(status_controller)
	status_controller.stats_changed.connect(refresh_combat_stats)

	_health_bar = HealthBarScene.instantiate()
	add_child(_health_bar)
	_health_bar.position = Vector2(0, -_sprite.get_height() - 10.0)   ## thanh máu cao 40px, gốc ở GIỮA -> đặt x = 0 cho căn giữa quái
	if not gold_boss and data.get("is_boss", false):
		var bt := str(data.get("boss_type", ""))
		if bt == "gold":
			gold_boss = true
		elif bt == "small_gold":
			small_gold_boss = true
		elif bt == "killer":
			killer_boss = true

	var plate := NamePlate.new()
	add_child(plate)
	plate.setup(str(data.get("name", "")).strip_edges(), clampi(int(data.get("series", 0)), 0, 4) as ElementTypes.ElementType, blue_boss, gold_boss or small_gold_boss)
	plate.place_above(_health_bar)
	if gold_boss:
		_sprite.scale = Vector2(1.25, 1.25)
	elif small_gold_boss:
		_sprite.scale = Vector2(1.15, 1.15)

	_origin_logic = VltkMath.to_logic(global_position)
	_cur_active = float(data.get("active", 400))
	_dir64 = randi() % VltkMath.MAX_DIR
	_apply_level_script()
	_build_stats()
	_enter(State.IDLE, "stand")

## SCRIPT CẤP GỐC (npclevelscript qua MonsterData.level_table): engine gốc gọi lúc sinh quái với HỆ + CẤP của điểm sinh ->
## chiêu Skill1-4 + cấp chiêu Level1-4 (VD animal.lua: cận chiến ngũ hành 419..423 theo hệ), tham số AI; chỉ số (máu, chính xác,
## phòng thủ, sát thương) đọc ở MonsterData.stat_at_level, kháng + sát thương cơ bản ở _apply_vltk_stats. Quái không có script giữ
## dữ liệu Npcs.txt như cũ.
var _level_table: Dictionary = {}

func _apply_level_script() -> void:
	data = MonsterData.apply_level_script(data, monster_id, level)   ## cùng hàm với quái game server (ServerMonster)
	_level_table = data.get("level_table", {})

## Kháng (%) + sát thương cơ bản của script cấp -> CombatantStats (cùng trường như người chơi): *DamageBase = ngoại công,
## *MagicBase = nội công (cộng vào chiêu ngoại / nội công tương ứng ở _make_hit_stats).
const LEVEL_RESISTS := {"PhysicsResist": CombatFormulas.DamageType.PHYSICS, "ColdResist": CombatFormulas.DamageType.COLD,
	"FireResist": CombatFormulas.DamageType.FIRE, "LightResist": CombatFormulas.DamageType.LIGHT,
	"PoisonResist": CombatFormulas.DamageType.POISON}
## Thứ tự mảng data["resist_max"] (cột *ResistMax của Npcs.txt, tools/import_vltk_monsters.py).
const RESIST_MAX_ORDER := ["FireResist", "ColdResist", "LightResist", "PoisonResist", "PhysicsResist"]
const LEVEL_ELEMENT_BASES := {"Poison": CombatFormulas.DamageType.POISON, "Cold": CombatFormulas.DamageType.COLD,
	"Fire": CombatFormulas.DamageType.FIRE, "Lighting": CombatFormulas.DamageType.LIGHT}

func _apply_level_combat(stats: CombatantStats) -> void:
	if _level_table.is_empty():
		return
	var caps: Array = data.get("resist_max", [])
	for field in LEVEL_RESISTS:
		var type: int = LEVEL_RESISTS[field]
		var at := RESIST_MAX_ORDER.find(field)
		var cap := int(caps[at]) if at >= 0 and at < caps.size() and int(caps[at]) > 0 else 75
		stats.resist_percent[type] = mini(MonsterData.level_value(_level_table, field, level), cap)
		stats.resist_percent_cap[type] = cap
	stats.add_physics_damage = maxi(0, MonsterData.level_value(_level_table, "PhysicalDamageBase", level))
	stats.add_physics_magic = maxi(0, MonsterData.level_value(_level_table, "PhysicalMagicBase", level))
	for name in LEVEL_ELEMENT_BASES:
		var type: int = LEVEL_ELEMENT_BASES[name]
		var outer := MonsterData.level_value(_level_table, name + "DamageBase", level)
		var inner := MonsterData.level_value(_level_table, name + "MagicBase", level)
		if outer > 0:
			stats.outer_element_damage[type] = Vector2i(outer, outer)
		if inner > 0:
			stats.inner_element_damage[type] = Vector2i(inner, inner)

## Chỉ số thử nghiệm theo cấp: máu theo Vitality, trúng/né theo Dexterity, ngũ hành theo Series gốc.
func _build_stats() -> void:
	_build = CombatantBuild.new()
	_build.level = level
	_build.element = clampi(int(data.get("series", 0)), 0, 4) as ElementTypes.ElementType
	_build.camp = camp
	var life_k := float(data.get("life_param", 100)) / 100.0
	_build.vitality = int((20 + level * 6) * life_k)
	_build.dexterity = 10 + level * 3
	_build.strength = 10 + level * 3
	_build.energy = 10
	combat_stats = CombatantStats.build(_build)
	_apply_vltk_stats(combat_stats)
	max_health = maxf(1.0, float(combat_stats.max_hp))
	health = max_health
	if _health_bar != null:
		_health_bar.set_max_health(max_health)

## Ghi đè máu / chính xác / phòng thủ bằng số gốc theo cấp (máu thử nghiệm theo Vitality bị thay).
func _apply_vltk_stats(stats: CombatantStats) -> void:
	var life := MonsterData.stat_at_level(data, "life", level)
	if life >= 0:
		stats.max_hp = maxi(1, life)
	if hp_override > 0:
		stats.max_hp = hp_override
	stats.max_hp *= _hell_mult()
	var ar := MonsterData.stat_at_level(data, "attack_rating", level)
	if ar >= 0:
		stats.attack_rating = ar
	var def := MonsterData.stat_at_level(data, "defense", level)
	if def >= 0:
		stats.defense = def
	_apply_level_combat(stats)
	if gold_boss:
		if hp_override <= 0:
			stats.max_hp = maxi(stats.max_hp, 1800000)
		for type in [CombatFormulas.DamageType.PHYSICS, CombatFormulas.DamageType.COLD, CombatFormulas.DamageType.FIRE, CombatFormulas.DamageType.LIGHT, CombatFormulas.DamageType.POISON]:
			stats.resist_percent[type] = maxi(int(stats.resist_percent.get(type, 0)), 85)
			stats.resist_percent_cap[type] = maxi(int(stats.resist_percent_cap.get(type, 0)), 85)
	elif blue_boss:
		for type in [CombatFormulas.DamageType.PHYSICS, CombatFormulas.DamageType.COLD, CombatFormulas.DamageType.FIRE, CombatFormulas.DamageType.LIGHT, CombatFormulas.DamageType.POISON]:
			stats.resist_percent[type] = 75
			stats.resist_percent_cap[type] = maxi(int(stats.resist_percent_cap.get(type, 0)), 75)

## Dựng lại chỉ số khi dính/hết buff-bùa (giữ nguyên % máu) — như Enemy.refresh_combat_stats.
func refresh_combat_stats() -> void:
	if _build == null:
		return
	var ratio := health / max_health if max_health > 0.0 else 1.0
	combat_stats = CombatantStats.build(_build, status_controller.get_state_attrib_sources())
	_apply_vltk_stats(combat_stats)
	max_health = maxf(1.0, float(combat_stats.max_hp))
	health = max_health * ratio
	if _health_bar != null:
		_health_bar.set_max_health(max_health)
	_health_bar.set_health(health)

func get_ground_position() -> Vector2:
	return global_position

## Chiều cao thân (để bấm chọn mục tiêu).
func get_body_height() -> float:
	return _sprite.get_height() if _sprite != null else 60.0

func is_dead() -> bool:
	return _state == State.DEAD

## Quái đang giao chiến với `node` (nhắm vào nó và nó trong tầm nhìn — như _ai_think khoá địch). Auto dùng để tự vệ.
func is_engaging(node: Node2D) -> bool:
	var base_vis := float(data.get("vision", 400))
	var max_vis: float = 2500.0 if (gold_boss and not is_moba_general) else maxf(base_vis * 1.6, 750.0)
	return node != null and target == node and not is_dead() \
		and VltkMath.to_logic(global_position).distance_to(VltkMath.logic_of(node)) <= max_vis

# ---------------------------------------------------------------- trạng thái / hoạt ảnh

func _enter(state: State, action: String) -> void:
	_state = state
	_action = action
	_state_frames = 0.0
	_state_len = float(MonsterData.action_frames(data, action))
	if state == State.WALK:
		_last_walk_pos = global_position
	else:
		_stuck_time = 0.0
		_avoid_timer = 0.0
		_ghost_timer = 0.0
	_play_action_sound(action)

## KNpcRes::PlaySound — phát tiếng của động tác khi động tác bắt đầu (bảng npc动作声音表: quái → động tác → wav).
func _play_action_sound(action: String) -> void:
	var stream := VltkSound.npc(str(data.get("res", "")), action)
	if stream != null:
		SfxManager.play(stream, global_position)

func _progress(loop: bool) -> float:
	if loop:
		return fmod(_state_frames, _state_len) / _state_len
	return clampf(_state_frames / _state_len, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	var frames := delta * FPS
	_game_time += frames
	if _accumulated_damage > 0.0:
		_damage_batch_timer -= delta
		if _damage_batch_timer <= 0.0:
			_flush_damage_number()
	if _state == State.DEAD:
		_tick_dead(delta, frames)
		return
	if net_eid != 0:
		_tick_net(frames)
		return
	if target == null or not is_instance_valid(target) or (target.has_method("is_dead") and target.is_dead()):
		target = null
		if battle_side != "":
			_foe_search_timer -= delta
			if _foe_search_timer <= 0.0:
				_foe_search_timer = 0.35
				var foe := "jin" if battle_side == "song" else "song"
				target = _find_nearest_foe(foe)
		else:
			target = get_tree().get_first_node_in_group("player")
	var frozen := GameManager.is_game_over or status_controller.is_stunned
	_state_frames += frames
	velocity = Vector2.ZERO
	if not frozen:
		match _state:
			State.WALK:
				_tick_walk(frames)
			State.ATTACK:
				_tick_attack()
			State.HURT:
				if _state_frames >= _state_len:
					_enter(State.IDLE, "stand")
		if ai_enabled and (_state == State.IDLE or _state == State.WALK):
			_ai_time += frames
			if _ai_time >= float(maxi(1, int(data.get("ai_max_time", 10)))):
				_ai_time = 0.0
				_ai_think()
	if _ghost_timer > 0.0:
		_ghost_timer -= get_physics_process_delta_time()
	var ignore_obs: bool = _ghost_timer > 0.0
	velocity = VltkWorld.slide_velocity(global_position, velocity, get_physics_process_delta_time(), false, ignore_obs)
	move_and_slide()
	if is_moba_general:
		var here_logic := VltkMath.to_logic(global_position)
		if here_logic.distance_to(_origin_logic) > TongKimLolRules.GENERAL_CAMP_RADIUS:
			var clamped_logic := _origin_logic + (here_logic - _origin_logic).normalized() * TongKimLolRules.GENERAL_CAMP_RADIUS
			global_position = VltkMath.to_world(clamped_logic)
	var looping := _state == State.IDLE or _state == State.WALK
	_sprite.set_pose(_action, _dir64, _progress(looping))

func _tick_walk(frames: float) -> void:
	var here := VltkMath.to_logic(global_position)
	var to_dest := _walk_dest - here
	var speed_mult: float = status_controller.move_speed_multiplier if status_controller != null else 1.0
	var speed_val := float(data.get("run_speed", data.get("walk_speed", 7))) if (target != null and is_instance_valid(target)) else float(data.get("walk_speed", 6))
	var step := maxf(speed_val, 6.0) * frames * speed_mult

	# Khi đang dí mục tiêu: nếu mục tiêu di chuyển cách đích đến hiện tại > 45 logic px thì liên tục cập nhật đường đi bám theo
	if target != null and is_instance_valid(target) and not GameManager.is_game_over:
		var target_logic := VltkMath.logic_of(target)
		var target_world := VltkMath.to_world(target_logic)
		if _nav_goal.distance_to(target_world) > 45.0:
			_walk_to(target_logic)
			to_dest = _walk_dest - here

	# Khi đã tới gần nút đường dẫn A* hiện tại
	if to_dest.length() <= maxf(step, 24.0):
		if _nav_path.size() > 1:
			_nav_path.remove_at(0)
			_walk_dest = VltkMath.to_logic(_nav_path[0])
			to_dest = _walk_dest - here
		elif _nav_path.size() == 1:
			_nav_path.clear()
			if _nav_goal != Vector2.ZERO:
				_walk_dest = VltkMath.to_logic(_nav_goal)
				to_dest = _walk_dest - here
			else:
				_enter(State.IDLE, "stand")
				_stuck_time = 0.0
				_avoid_timer = 0.0
				return
		elif to_dest.length() <= maxf(step, 4.0):
			_enter(State.IDLE, "stand")
			_stuck_time = 0.0
			_avoid_timer = 0.0
			return

	# Phát hiện vướng vật cản (quái không di chuyển được dù đang trong trạng thái WALK)
	var delta := frames / float(FPS)
	var moved_dist := global_position.distance_to(_last_walk_pos)
	_last_walk_pos = global_position
	if moved_dist < 1.0 and step > 1.0:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)

	# Tự động tìm lại đường A* mới từ vị trí hiện tại khi bị kẹt > 0.25s
	if _stuck_time >= 0.25 and _nav_goal != Vector2.ZERO:
		var w := VltkWorld.current
		if w != null and w._nav != null:
			var replanned := VltkWorld.find_path(global_position, _nav_goal)
			if replanned.size() > 0:
				_nav_path = replanned
				_walk_dest = VltkMath.to_logic(_nav_path[0])
				to_dest = _walk_dest - here

	# Nếu bị kẹt góc hẹp > 0.8s: kích hoạt chế độ ghost 0.4s để trượt thoát khỏi mép vật cản
	if _stuck_time >= 0.8:
		_ghost_timer = 0.4

	# Bỏ qua waypoint nếu bị kẹt vật cản quá 1.5 giây (dành cho lính hành quân is_lane_creep)
	if is_lane_creep and _stuck_time >= 1.5 and not lane_waypoints.is_empty():
		if lane_waypoint_idx < lane_waypoints.size() - 1:
			lane_waypoint_idx += 1
			_nav_goal = lane_waypoints[lane_waypoint_idx]
			_nav_path.clear()
			_walk_dest = VltkMath.to_logic(_nav_goal)
		_stuck_time = 0.0
		_avoid_timer = 0.0

	var dir_norm := to_dest.normalized()
	var move_dir := dir_norm

	# Cơ chế lách vật cản đa góc (Obstacle Avoidance): thử các góc trượt 30, -30, 45, -45, 60, -60, 90, -90, 120, -120 độ
	if _avoid_timer > 0.0:
		_avoid_timer -= delta
		move_dir = _avoid_dir
	elif _stuck_time >= 0.25:
		var best_cand := Vector2.ZERO
		var candidates: Array[Vector2] = [
			dir_norm.rotated(PI * 0.17),
			dir_norm.rotated(-PI * 0.17),
			dir_norm.rotated(PI * 0.25),
			dir_norm.rotated(-PI * 0.25),
			dir_norm.rotated(PI * 0.35),
			dir_norm.rotated(-PI * 0.35),
			dir_norm.rotated(PI * 0.5),
			dir_norm.rotated(-PI * 0.5),
			dir_norm.rotated(PI * 0.67),
			dir_norm.rotated(-PI * 0.67)
		]
		var w := VltkWorld.current
		for cand in candidates:
			if w != null:
				var test_pos := global_position + VltkMath.to_world(cand * 28.0)
				if not w._blocked_at(test_pos):
					best_cand = cand
					break
			else:
				best_cand = cand
				break
		if best_cand != Vector2.ZERO:
			_avoid_dir = best_cand
			_avoid_timer = 0.45
			move_dir = best_cand

	var dir := VltkMath.dir_between(Vector2.ZERO, move_dir)
	if dir >= 0:
		_dir64 = dir
	var speed_logic := move_dir * float(data.get("walk_speed", 6)) * (1.25 if blue_boss else 1.0) * FPS * speed_mult
	velocity = VltkMath.to_world(speed_logic)

func _walk_to(dest_logic: Vector2) -> void:
	if is_moba_general:
		var d := dest_logic.distance_to(_origin_logic)
		if d > TongKimLolRules.GENERAL_CAMP_RADIUS:
			dest_logic = _origin_logic + (dest_logic - _origin_logic).normalized() * TongKimLolRules.GENERAL_CAMP_RADIUS

	var dest_world := VltkMath.to_world(dest_logic)
	var w := VltkWorld.current
	if w != null and w._nav != null and global_position.distance_to(dest_world) > 40.0:
		if _nav_path.is_empty() or _nav_goal.distance_to(dest_world) > 40.0:
			_nav_goal = dest_world
			var path := VltkWorld.find_path(global_position, dest_world)
			if not path.is_empty():
				_nav_path = path
				_walk_dest = VltkMath.to_logic(_nav_path[0])
			else:
				_walk_dest = dest_logic
	else:
		_nav_goal = dest_world
		_walk_dest = dest_logic

	if _state != State.WALK:
		_enter(State.WALK, "walk")

# ---------------------------------------------------------------- AI (KNpcAI::ProcessAIType01 gốc)

## Tham số AI: AI loại 1 dùng đúng AIParam1-9 của quái; loại khác (khác cách đọc tham số) dùng giá trị chung hợp lý.
func _ai_params() -> Array:
	if data.has("ai_params") and not (data["ai_params"] as Array).is_empty():
		return data["ai_params"]
	return [30, 25, 25, 25, 25, 25, 25, 0, 0]

func _skill_data(slot: int) -> Dictionary:
	var sk: Array = data["skills"][slot]
	if int(sk[0]) <= 0:
		return {}
	return VltkSkillData.skill(int(sk[0]), int(sk[1]))

func _skill_radius(slot: int) -> float:
	var s := _skill_data(slot)
	return float(s.get("attack_radius", DEFAULT_ATTACK_RADIUS)) if not s.is_empty() else DEFAULT_ATTACK_RADIUS

## Tầm xa nhất trong các skill (AIParam[9] = bình phương tầm này, tính lúc nạp quái ở KNpc gốc).
func _max_skill_radius() -> float:
	if _max_radius < 0.0:
		_max_radius = 0.0
		for slot in 4:
			if int(data["skills"][slot][0]) > 0:
				_max_radius = maxf(_max_radius, _skill_radius(slot))
		if _max_radius <= 0.0:
			_max_radius = DEFAULT_ATTACK_RADIUS
	return _max_radius

## Tìm mục tiêu phe địch gần nhất trong MOBA Tống Kim LOL
func _find_nearest_foe(foe_side: String) -> Node2D:
	var best_node: Node2D = null
	var best_dist := 1.0e9
	var my_pos := global_position
	var is_gb: bool = gold_boss and not is_moba_general
	var max_range: float = 2500.0 if is_gb else 900.0
	var max_dist_sq: float = max_range * max_range

	# Nếu là Boss Hoàng Kim, ưu tiên tuyệt đối tìm Boss Hoàng Kim phe đối phương trước
	if is_gb:
		for node in get_tree().get_nodes_in_group("enemies"):
			if node == self or not is_instance_valid(node) or not (node is Node2D):
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			if "battle_side" in node and node.battle_side == foe_side:
				if "gold_boss" in node and node.gold_boss and not node.get("is_moba_general"):
					var d := my_pos.distance_squared_to(node.global_position)
					if d <= max_dist_sq:
						return node

	# 1. Kiểm tra người chơi
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and is_instance_valid(player) and not (player.has_method("is_dead") and player.is_dead()):
		var p_side := "song"
		if TongKimLolState.current != null:
			p_side = TongKimLolState.current.team_side
		if p_side == foe_side:
			var allowed := true
			if is_moba_general:
				allowed = player.global_position.distance_to(VltkMath.to_world(_origin_logic)) <= TongKimLolRules.GENERAL_CAMP_RADIUS + 80.0
			if allowed:
				var d := my_pos.distance_squared_to(player.global_position)
				if d < best_dist and d <= max_dist_sq:
					best_dist = d
					best_node = player

	# 2. Kiểm tra quái/lính/Tướng phe đối địch
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node) or not (node is Node2D):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if "battle_side" in node and node.battle_side == foe_side:
			if is_moba_general and node.global_position.distance_to(VltkMath.to_world(_origin_logic)) > TongKimLolRules.GENERAL_CAMP_RADIUS + 80.0:
				continue
			var d := my_pos.distance_squared_to(node.global_position)
			if d < best_dist and d <= max_dist_sq:
				best_dist = d
				best_node = node

	return best_node

func _ai_think() -> void:
	var mode := int(data.get("ai_mode", 0))
	if mode <= 0:
		return  ## AIMode 0/trống: NPC đứng yên
	var p := _ai_params()
	var here := VltkMath.to_logic(global_position)
	## KeepActiveRange: lính thường ra khỏi vùng hoạt động thì quay về chỗ sinh ra.
	## Lính lane MOBA & Boss Hoàng Kim không bị leash về chỗ sinh mà hành quân theo đường.
	## Tướng Soái MOBA không bao giờ được ra khỏi doanh trại GENERAL_CAMP_RADIUS.
	if is_moba_general:
		var camp_dist := here.distance_to(_origin_logic)
		if camp_dist > TongKimLolRules.GENERAL_CAMP_RADIUS:
			target = null
			_walk_to(_origin_logic)
			return
	elif not is_lane_creep and not gold_boss:
		var base_active := float(data.get("active", 400))
		# Khi đang dí mục tiêu: nới rộng bán kính hoạt động để quái truy đuổi người chơi
		var active := maxf(base_active * 2.0, 1500.0) if (target != null and is_instance_valid(target)) else base_active
		var from_origin := here.distance_to(_origin_logic)
		if active < from_origin:
			_cur_active = active * 0.5
		if _cur_active < from_origin:
			target = null
			_walk_to(_origin_logic)
			return
		_cur_active = active
	else:
		_origin_logic = here
	## Khoá kẻ địch trong tầm nhìn.
	var enemy: Node2D = null
	if target != null and is_instance_valid(target) and not GameManager.is_game_over:
		if is_moba_general:
			var t_from_camp := VltkMath.logic_of(target).distance_to(_origin_logic)
			if t_from_camp <= TongKimLolRules.GENERAL_CAMP_RADIUS + 80.0:
				enemy = target
			else:
				target = null
		else:
			# Nâng phạm vi nhìn thấy player rộng hơn (tối thiểu 750 logic px bao quát toàn màn hình)
			var base_vis := float(data.get("vision", 400))
			var max_vis: float = 2500.0 if (gold_boss and not is_moba_general) else maxf(base_vis * 1.6, 750.0)
			if here.distance_to(VltkMath.logic_of(target)) <= max_vis:
				enemy = target
	if enemy == null:
		if is_lane_creep and not lane_waypoints.is_empty():
			_march_lane(here)
			return
		if int(p[0]) > 0 and randi() % 100 < int(p[0]):
			_patrol()
		return
	var dist := here.distance_to(VltkMath.logic_of(enemy))
	if dist > _max_skill_radius():
		if is_moba_general:
			var enemy_from_camp := VltkMath.logic_of(enemy).distance_to(_origin_logic)
			if enemy_from_camp > TongKimLolRules.GENERAL_CAMP_RADIUS + 80.0:
				target = null
				_walk_to(_origin_logic)
				return
			_walk_to(VltkMath.logic_of(enemy))
			return
		# Đang ngoài tầm skill: quái PHẢI DÍ theo kẻ địch
		_walk_to(VltkMath.logic_of(enemy))
		return
	## Trong tầm: chọn 1 trong 4 skill theo xác suất AIParam2-5.
	var total_weight := 0
	for i in 4:
		if int(data["skills"][i][0]) > 0:
			total_weight += maxi(0, int(p[i + 1]))
	if total_weight <= 0:
		total_weight = 100
	var roll := randi() % total_weight
	var slot := -1
	var acc := 0
	for i in 4:
		if int(data["skills"][i][0]) <= 0:
			continue
		acc += maxi(0, int(p[i + 1]))
		if roll < acc:
			slot = i
			break
	if slot < 0:
		return
	if int(data["skills"][slot][0]) <= 0 or _game_time < _skill_ready[slot]:
		# Skill chưa sẵn sàng / đang hồi: tiếp tục bám theo dí kẻ địch
		_walk_to(VltkMath.logic_of(enemy))
		return
	_active_slot = slot
	_follow_attack(enemy)

## Lính hành quân theo đường (lane march) cho đến khi gặp địch hoặc tới đích
func _march_lane(here: Vector2) -> void:
	while lane_waypoint_idx < lane_waypoints.size():
		var wp_world: Vector2 = lane_waypoints[lane_waypoint_idx]
		var wp_logic := VltkMath.to_logic(wp_world)
		if here.distance_to(wp_logic) <= 120.0:
			lane_waypoint_idx += 1
			_nav_path.clear()
		else:
			_walk_to(wp_logic)
			return
	# Khi đã đi hết waypoint, tìm Tướng đối phương làm mục tiêu tối hậu
	if battle_side != "":
		var foe := "jin" if battle_side == "song" else "song"
		var final_foe := _find_nearest_foe(foe)
		if final_foe != null:
			target = final_foe

## CommonAction: 80% về/đứng ở chỗ sinh ra, 20% đi tới điểm ngẫu nhiên trong nửa vùng hoạt động.
func _patrol() -> void:
	var off := Vector2.ZERO
	if randi() % 100 >= 80:
		var half := maxi(1, int(_cur_active * 0.5))
		off = Vector2(randi_range(-half, half), randi_range(-half, half))
	_walk_to(_origin_logic + off)

## FollowAttack: đủ gần thì ra chiêu, không thì đi tới.
func _follow_attack(enemy: Node2D) -> void:
	var here := VltkMath.to_logic(global_position)
	var there := VltkMath.logic_of(enemy)
	if here.distance_to(there) <= _skill_radius(_active_slot):
		_begin_attack(_active_slot)
	else:
		_walk_to(there)

# ---------------------------------------------------------------- tấn công

func _begin_attack(slot: int) -> void:
	var s := _skill_data(slot)
	var action := "attack1"
	match int(s.get("char_anim", 9)):
		10: action = "attack2"
		11, 14: action = "magic"
	if target != null and is_instance_valid(target):
		var d := VltkMath.dir_between(VltkMath.to_logic(global_position), VltkMath.logic_of(target))
		if d >= 0:
			_dir64 = d
	_enter(State.ATTACK, action)
	_fired = false
	_skill_ready[slot] = _game_time + float(maxi(int(s.get("time_per_cast", 0)), int(_state_len)))
	if not s.is_empty():
		VltkSkillRunner.play_precast(self, s)

func _tick_attack() -> void:
	if not _fired and _state_frames >= _state_len * ATTACK_FIRE_PERCENT:
		_fired = true
		_fire_skill()
	if _state_frames >= _state_len:
		_enter(State.IDLE, "stand")

func _fire_skill() -> void:
	if target == null or not is_instance_valid(target) or GameManager.is_game_over:
		return
	## Online, đòn nhắm người khác: chỉ vẽ hiệu ứng (đạn bay không gây sát thương), không đánh cận chiến.
	var visual_only := net_eid != 0 and not _net_real_attack
	var sk: Array = data["skills"][_active_slot]
	var skill_id := int(sk[0])
	var skill_level := int(sk[1])
	var s := VltkSkillData.skill(skill_id, skill_level)
	## Quái có thể vừa di chuyển lúc ra chiêu: nhắm vị trí người chơi LÚC BẮN.
	var is_melee := int(s.get("melee", 1)) == 1
	if not s.is_empty() and not is_melee and int(s.get("style", 0)) == VltkSkillCaster.STYLE_MISSILES:
		var ctx := VltkCastContext.new()
		ctx.launcher = self
		ctx.world = get_parent()
		ctx.stats = null if visual_only else _make_hit_stats(skill_id, skill_level)
		ctx.attacker_stats = combat_stats
		if battle_side != "":
			ctx.target_group = &"moba_all"
		else:
			ctx.target_group = &"player"
		VltkSkillCaster.cast(ctx, skill_id, skill_level, VltkMath.logic_of(target), target)
		return
	if visual_only:
		return
	## Skill cận chiến (melee = 1) hoặc kiểu 1/2/3: đánh thẳng nếu người chơi còn trong tầm.
	var radius := float(s.get("attack_radius", DEFAULT_ATTACK_RADIUS)) if not s.is_empty() else DEFAULT_ATTACK_RADIUS
	if VltkMath.to_logic(global_position).distance_to(VltkMath.logic_of(target)) <= radius * 1.2:
		## Đòn cận chiến: tính đúng công thức KNpc::AppendSkillEffect qua _make_hit_stats (bao gồm sát thương Min/Max,
		## nguyên tố ngoại công/nội công, làm chậm, choáng, chí mạng và tương khắc ngũ hành).
		var hit_stats := _make_hit_stats(skill_id, skill_level)
		var dmg_min := int(hit_stats.damage_min)
		var dmg_max := int(hit_stats.damage_max)
		var mods := hit_stats.make_hit_mods(self, true)
		mods.use_attack_rating = int(s.get("use_ar", 1)) != 0
		mods.do_hurt_p = int(s.get("do_hurt", 100))
		if target.has_method("take_damage_from"):
			target.take_damage_from(combat_stats, dmg_min, dmg_max, hit_stats.main_damage_type, hit_stats.element, mods)

## Sát thương cơ bản [nhỏ nhất, lớn nhất] theo cấp (công thức gốc); quái chưa có dữ liệu -> chỉ số thử nghiệm.
func _damage_range() -> Vector2:
	# Quái / Lính trong MOBA Tống Kim LOL (Bộ binh & Cung binh):
	# Sử dụng công thức dame hợp lý theo cấp để lính đánh nhau vừa phải (~150 dame), không bị one-shot lính hay người chơi
	if is_lane_creep or monster_id == TongKimLolRules.CREEP_MELEE_TPL or monster_id == TongKimLolRules.CREEP_RANGED_TPL:
		var creep_dmg := 35.0 + float(level) * 2.3
		var add_phys_creep: int = combat_stats.add_physics_damage if combat_stats else 0
		return Vector2(creep_dmg + add_phys_creep, creep_dmg + add_phys_creep)

	var lo := MonsterData.stat_at_level(data, "min_damage", level)
	var hi := MonsterData.stat_at_level(data, "max_damage", level)
	var add_phys: int = combat_stats.add_physics_damage if combat_stats else 0
	if lo > 0 or hi > 0:
		return Vector2(lo + add_phys, maxf(lo, hi) + add_phys)
	var d := _test_damage()
	if is_moba_general:
		d = maxf(d, 300.0)
	return Vector2(d + add_phys, d + add_phys)

func _hell_mult() -> int:
	return maxi(1, hell_stars)

func _boss_damage_mult() -> float:
	return (3.0 if DropTable.tier_of(level) >= 5 else 2.0) if blue_boss else 1.0

func _base_damage() -> float:
	var r := _damage_range()
	return (r.x + r.y) * 0.5 * _boss_damage_mult()

func _test_damage() -> float:
	var k := (float(data.get("min_damage_param", 100)) + float(data.get("max_damage_param", 100))) / 200.0
	return (8.0 + level * 3.0) * k

## Đòn của skill quái THEO HỆ: chuẩn công thức KNpc::AppendSkillEffect gốc VLTK 1:
## - Lực tay gốc = [MinDamage + PhysicalDamageBase, MaxDamage + PhysicalDamageBase]
## - Ngoại công (physical = 1): Lực tay * (100 + physicsenhance_p) / 100 + physicsdamage_v
## - Nội công (physical = 0): physicsdamage_v + PhysicalMagicBase
## - Thuộc tính nguyên tố (colddamage_v, firedamage_v, lightingdamage_v, poisondamage_v) + *DamageBase / *MagicBase
## - Hiệu ứng trúng đòn: stun_p (choáng), deadlystrike_p (chí mạng), seriesdamage_p (ngũ hành)
func _make_hit_stats(skill_id: int, skill_level: int) -> ResolvedSkillStats:
	var stats := ResolvedSkillStats.new()
	## Có script cấp: cấp chiêu đúng như script trả (Level1-4); không có: cấp gốc + cấp quái / 5 (số gốc cấp 1 quá nhỏ).
	var lv := skill_level if data.get("skill_levels_exact", false) else clampi(skill_level + level / 5, 1, 30)
	var skill := VltkSkillData.skill(skill_id, skill_level)
	var series := int(skill.get("series", -1))
	stats.element = (series if series >= 0 and series <= 4 else (int(_build.element) if _build else 0)) as ElementTypes.ElementType
	stats.main_damage_type = CombatFormulas.DamageType.PHYSICS

	var elements := {}
	var cold := VltkSkillData.hit_attrib(skill_id, "colddamage_v", lv)
	var fire := VltkSkillData.hit_attrib(skill_id, "firedamage_v", lv)
	var light := VltkSkillData.hit_attrib(skill_id, "lightingdamage_v", lv)
	var poison := VltkSkillData.hit_attrib(skill_id, "poisondamage_v", lv)
	if not cold.is_empty():
		elements[CombatFormulas.DamageType.COLD] = _element_range(cold)
		stats.freeze_frames = int(cold[1])
	if not fire.is_empty():
		elements[CombatFormulas.DamageType.FIRE] = _element_range(fire)
	if not light.is_empty():
		elements[CombatFormulas.DamageType.LIGHT] = _element_range(light)
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

	var is_physical := int(skill.get("physical", 1)) == 1
	var r := _damage_range()
	var lo := r.x
	var hi := r.y

	var enhance := VltkSkillData.hit_attrib(skill_id, "physicsenhance_p", lv)
	var flat := VltkSkillData.hit_attrib(skill_id, "physicsdamage_v", lv)
	var has_physics := false

	if is_physical:
		if not enhance.is_empty():
			lo = lo * (100.0 + float(enhance[0])) / 100.0
			hi = hi * (100.0 + float(enhance[0])) / 100.0
			has_physics = true
		if not flat.is_empty():
			var f_min := float(flat[0])
			var f_max := float(flat[2] if flat.size() > 2 else flat[0])
			lo += f_min
			hi += f_max
			has_physics = true
		if not has_physics:
			if elements.is_empty():
				has_physics = true  # đòn vật lý thường không khai báo thuộc tính
			else:
				lo = 0.0
				hi = 0.0
	else:
		# Chiêu nội công (không dùng lực tay nhân physicsenhance_p)
		if not flat.is_empty():
			lo = float(flat[0])
			hi = float(flat[2] if flat.size() > 2 else flat[0])
			var add_magic: float = float(combat_stats.add_physics_magic) if combat_stats else 0.0
			lo += add_magic
			hi += add_magic
			has_physics = true
		else:
			# Chiêu nội công không có physicsdamage_v:
			# Với quái / NPC, lực tay cơ bản r.x / r.y luôn được sử dụng làm sát thương nền,
			# đảm bảo quái đánh xa (như Cung Binh dùng skill 165) và Tướng Soái có sát thương vật lý đầy đủ ngang bộ binh
			lo = r.x
			hi = r.y
			has_physics = true

	## Sát thương cơ bản của script cấp: chiêu ngoại công cộng *DamageBase, nội công cộng *MagicBase (đúng KNpc::AppendSkillEffect).
	var extra: Dictionary = (combat_stats.outer_element_damage if is_physical else combat_stats.inner_element_damage) if combat_stats != null else {}
	for t in extra:
		elements[t] = elements.get(t, Vector2i.ZERO) + extra[t]

	var boss_mult := _boss_damage_mult()
	if is_moba_general:
		boss_mult = maxf(boss_mult, 8.0)
	var hell_mult := float(_hell_mult())
	var total_mult := boss_mult * hell_mult * moba_damage_multiplier

	if has_physics and (lo > 0.0 or hi > 0.0):
		lo *= total_mult
		hi *= total_mult
		stats.damage_min = lo
		stats.damage_max = hi
		stats.damage = (lo + hi) * 0.5
	else:
		stats.damage_min = 0.0
		stats.damage_max = 0.0
		stats.damage = 0.0

	if total_mult != 1.0:
		for t in elements:
			var elem_range: Vector2i = elements[t]
			elements[t] = Vector2i(int(elem_range.x * total_mult), int(elem_range.y * total_mult))

	stats.extra_damage_ranges = elements
	return stats

## colddamage_v/firedamage_v/lightingdamage_v: giá trị 1 = sát thương nhỏ nhất, giá trị 3 = lớn nhất (thiếu thì bằng nhỏ nhất).
static func _element_range(v: Array) -> Vector2i:
	var low := int(v[0])
	var high := int(v[2]) if v.size() > 2 and int(v[2]) >= low else low
	return Vector2i(low, high)

# ---------------------------------------------------------------- nhận đòn / chết

## Nhận 1 đòn qua đúng pipeline HitResolver (như Enemy.take_damage_from).
func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: CombatFormulas.DamageType = CombatFormulas.DamageType.PHYSICS,
		attacker_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM,
		mods: CombatFormulas.HitModifiers = null) -> void:
	if _state == State.DEAD:
		return
	if battle_side != "":
		# Chặn quái/tướng cùng phe đánh nhau
		if mods != null and mods.attacker_node != null and "battle_side" in mods.attacker_node:
			if str(mods.attacker_node.battle_side) == battle_side:
				return
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and "combat_stats" in player and attacker_stats == player.combat_stats:
			if TongKimLolState.current != null and TongKimLolState.current.team_side == battle_side:
				return
	var final_damage := HitResolver.receive(self, combat_stats, int(health), attacker_stats,
			min_damage, max_damage, damage_type, attacker_element, mods)
	if final_damage == HitResolver.MISSED:
		_spawn_number(0.0, true)
		return
	if final_damage == 0:
		return  ## đòn chỉ mang trạng thái (bùa)
	## DoHurt của skill: % khựng khi trúng (KNpc::ReceiveDamage gốc: g_RandPercent(nDoHurtP) -> DoHurt()).
	var staggers := mods == null or randi_range(0, 99) < mods.do_hurt_p
	if net_eid != 0:
		_net_damage(float(final_damage), staggers)
		return
	_apply_damage(float(final_damage), staggers)

func take_damage(amount: float) -> void:
	if _state != State.DEAD:
		if net_eid != 0:
			_net_damage(amount, true)
			return
		_apply_damage(amount, true)

func take_status_damage(amount: float, _effect_id: String) -> void:
	if _state != State.DEAD:
		if net_eid != 0:
			_net_damage(amount, false)
			return
		_apply_damage(amount, false)

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	_health_bar.set_health(health)

func _apply_damage(amount: float, staggers: bool) -> void:
	health -= amount
	_health_bar.set_health(health)
	_accumulate_damage(amount)
	if health <= 0.0:
		die()
		return
	## KNpc::DoHurt: bị đánh -> diễn động tác bị thương, rút ngắn theo HitRecover; HitRecover >= 100 thì không khựng.
	if staggers and _state != State.HURT:
		var recover := int(data.get("hit_recover", 0))
		if recover < 100:
			var hurt_frames := float(MonsterData.action_frames(data, "hurt")) * float(100 - recover) / 100.0
			_enter(State.HURT, "hurt")
			_state_len = maxf(1.0, hurt_frames)

func die() -> void:
	if _state == State.DEAD:
		return
	_flush_damage_number()
	remove_from_group("enemies")  ## xác không còn là mục tiêu của skill
	set_deferred("collision_layer", 0)
	_health_bar.visible = false
	velocity = Vector2.ZERO
	z_index = -1
	_enter(State.DEAD, "die")
	_death_time = 0.0
	if net_eid == 0 and PlayerStats.explosion_on_kill_chance > 0.0 and randf() < PlayerStats.explosion_on_kill_chance:
		_trigger_kill_explosion()
	if net_eid != 0:
		return   ## online: thưởng do server báo (S_KILL -> grant_rewards)
	grant_rewards()
	died.emit(self)

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

## Rớt đồ theo bảng script server gốc (DropTable) + kinh nghiệm (KillRewards, chia theo tổ đội).
## Online: chỉ gọi khi server báo mình được thưởng; `with_drops` = mình là người hạ đòn cuối.
func grant_rewards(with_drops := true) -> void:
	if _state != State.DEAD:
		die()
	if with_drops and net_eid == 0:   ## online: đồ rơi do server tung (S_DROPS)
		var drops: Array
		var luck := 0
		var loop := Engine.get_main_loop()
		var player_node: Node = (loop as SceneTree).get_first_node_in_group("player") if loop is SceneTree else null
		if player_node != null and "combat_stats" in player_node and player_node.combat_stats != null:
			luck = player_node.combat_stats.lucky_v
		if gold_boss:
			drops = DropTable.roll_gold_boss(level, int(_build.element))
			ChatBox.push_system("[color=#ffd700][Võ Lâm Minh Chủ][/color] Hào kiệt đã kích sát thành công [Hoàng Kim] %s!" % str(data.get("name", "Boss")))
		elif small_gold_boss:
			drops = DropTable.roll_small_gold_boss(level, int(_build.element))
			ChatBox.push_system("[color=#ffff00][Tiểu Hoàng Kim][/color] Hào kiệt đã kích sát thành công [Tiểu Hoàng Kim] %s!" % str(data.get("name", "Boss")))
		elif killer_boss:
			drops = DropTable.roll_killer_boss(level, int(_build.element))
			ChatBox.push_system("[color=#ff9900][Nhiếp Thí Trần][/color] Hào kiệt đã hoàn thành tiêu diệt [Sát Thủ] %s!" % str(data.get("name", "Boss")))
		elif hell_stars > 0:
			drops = DropTable.roll_hell(level, int(_build.element), hell_stars, blue_boss)
		else:
			drops = DropTable.roll_blue_boss(level, int(_build.element), luck) if blue_boss else DropTable.roll(level, int(_build.element), luck)
		if not drops.is_empty():
			GroundDrop.spawn_drops(get_parent(), position, drops)
	if net_eid != 0:
		return   ## online: kinh nghiệm do game server tính và báo (S_PROGRESS)
	KillRewards.on_monster_killed(self)

# ---------------------------------------------------------------- online (quái của game server)

## Bản tin vị trí / động tác từ server.
func net_push_state(server_ms: float, st: Dictionary) -> void:
	var item := st.duplicate()
	item["t"] = server_ms
	_net_buffer.append(item)
	if _net_buffer.size() > 20:
		_net_buffer.pop_front()

## Server báo quái ra chiêu `slot` vào `target_node`. real = target là chính mình (tính sát thương thật).
func net_attack(slot: int, target_node: Node2D, dir64: int, real: bool) -> void:
	if _state == State.DEAD or slot < 0 or slot > 3:
		return
	target = target_node
	_dir64 = dir64
	_active_slot = slot
	_net_real_attack = real
	_begin_attack(slot)

func _net_damage(amount: float, staggers: bool) -> void:
	_accumulate_damage(amount)
	_last_predicted_dmg_ms = Time.get_ticks_msec()
	## Trừ trước trên thanh máu theo cơ chế Client Prediction (VLTK gốc): không có delay
	health = maxf(0.0, health - amount)
	_health_bar.set_health(health)
	if health <= 0.0:
		die()
	elif staggers and _state != State.ATTACK and _state != State.DEAD:
		_enter(State.HURT, "hurt")
	NetClient.send_damage(net_eid, amount, staggers)

func _tick_net(frames: float) -> void:
	_state_frames += frames
	if _state == State.ATTACK:
		_tick_attack()   ## diễn hết đòn đang ra (bắn ở 60%) rồi mới theo động tác server
		_sprite.set_pose(_action, _dir64, _progress(false))
	if not _net_buffer.is_empty():
		var delay := NetClient.adaptive_interp_delay_ms() if NetClient.has_method("adaptive_interp_delay_ms") else NET_INTERP_DELAY_MS
		var render_t := NetClient.server_now_ms() - delay
		while _net_buffer.size() >= 2 and float(_net_buffer[1].t) <= render_t:
			_net_buffer.pop_front()
		var a: Dictionary = _net_buffer[0]
		var feet: Vector2 = a.pos
		if _net_buffer.size() >= 2:
			var b: Dictionary = _net_buffer[1]
			var span := float(b.t) - float(a.t)
			var k := clampf((render_t - float(a.t)) / span, 0.0, 1.0) if span > 0.0 else 1.0
			feet = (a.pos as Vector2).lerp(b.pos, k)
			## Dead-reckoning: nếu đã vượt qua mốc b, tiếp tục ngoại suy theo hướng di chuyển
			if k >= 1.0 and span > 0.0:
				var vel := (b.pos as Vector2 - a.pos as Vector2) / span
				var overshoot := render_t - float(b.t)
				feet = (b.pos as Vector2) + vel * clampf(overshoot, 0.0, span * 0.5)
		## Snap: quái bị dịch chuyển đột ngột (hồi sinh / teleport) thì nhảy ngay, không lerp.
		## Gần (< 400px): lerp mượt về đúng vị trí (hệ số 0.85/frame tại 60fps = hội tụ trong ~4 frame).
		if global_position.distance_to(feet) > 400.0:
			global_position = feet
		else:
			global_position = global_position.lerp(feet, 0.85)
		var server_hp := max_health * float(a.hp) / 100.0
		## Máu quái trong giao tranh là đơn điệu giảm (monotonic decreasing):
		## Tuyệt đối không cho bản tin trễ / độ phân giải 1-byte kéo ngược máu lên ("mất rồi có lại").
		health = minf(health, server_hp)
		_health_bar.set_health(health)
		if (int(a.flags) & NetProto.FLAG_DEAD) != 0 or int(a.hp) == 0:
			die()
			return
		if _state != State.ATTACK:
			var act := NetProto.monster_action_name(int(a.action))
			if act != _action:
				_enter(State.WALK if act == "walk" else (State.HURT if act == "hurt" else State.IDLE), act)
			_dir64 = int(a.dir)
	if _state != State.ATTACK:
		var looping := _state == State.IDLE or _state == State.WALK
		_sprite.set_pose(_action, _dir64, _progress(looping))

func _tick_dead(delta: float, frames: float) -> void:
	_state_frames += frames
	_sprite.set_pose("die", _dir64, _progress(false))
	if _state_frames < _state_len:
		return
	_death_time += delta
	if _death_time > CORPSE_STAY:
		modulate.a = clampf(1.0 - (_death_time - CORPSE_STAY) / CORPSE_FADE, 0.0, 1.0)
	if _death_time >= CORPSE_STAY + CORPSE_FADE:
		queue_free()

func _accumulate_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if _accumulated_damage <= 0.0:
		_damage_batch_timer = DAMAGE_BATCH_INTERVAL
	_accumulated_damage += amount

func _flush_damage_number() -> void:
	if _accumulated_damage > 0.0:
		_spawn_number(_accumulated_damage, false)
		_accumulated_damage = 0.0
		_damage_batch_timer = 0.0

func _spawn_number(amount: float, miss: bool) -> void:
	var at := global_position + Vector2(0, -_sprite.get_height() * 0.6)
	ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), at, func(number):
		if miss:
			number.set_miss()
		else:
			number.set_damage(amount))

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

var monster_id: int = 0
var data: Dictionary = {}
var level: int = 1
## BOSS XANH (script server Revive: ~2% mỗi lần quái sinh): tên xanh dương, kháng 75% mọi loại, sát thương x3 (cấp 50+, thấp hơn thì x2),
## nhanh hơn, rớt 5 lần (DropTable.roll_blue_boss). Đặt TRƯỚC khi add_child.
var blue_boss: bool = false
## Độ khó ĐỊA NGỤC (1-5 sao, 0 = map thường): máu, sát thương và tỉ lệ rơi đồ nhân số sao (DropTable.roll_hell). Đặt TRƯỚC khi add_child.
var hell_stars: int = 0
## false = quái đứng yên (tắt AI) — để xem hình hoặc để người chơi tập đánh.
var ai_enabled: bool = true
var camp: int = Camp.Type.ANIMAL
var combat_stats: CombatantStats
var health: float = 1.0
var max_health: float = 1.0
var status_controller: StatusEffectController
var target: Node2D = null

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

## ONLINE: quái do game server điều khiển (net_eid != 0). Không chạy AI / không tự trừ máu: vị trí + động tác lấy từ
## server (nội suy), sát thương mình gây được báo lên server, chiêu của quái chỉ ra khi server báo (S_MATTACK).
var net_eid: int = 0
## > 0: máu cố định (bỏ qua máu theo cấp của bảng quái) — quái ải Thách Thức Thời Gian dùng máu gốc của script ải.
var hp_override: int = 0
var _net_buffer: Array = []       ## [{t, pos, dir, action, hp, flags}] theo giờ server
var _net_real_attack := false     ## đòn đang ra nhắm vào chính mình -> gây sát thương thật
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
	var plate := NamePlate.new()
	add_child(plate)
	plate.setup(str(data.get("name", "")).strip_edges(), clampi(int(data.get("series", 0)), 0, 4) as ElementTypes.ElementType, blue_boss)
	plate.place_above(_health_bar)

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
	if blue_boss:
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
	return node != null and target == node and not is_dead() 			and VltkMath.to_logic(global_position).distance_to(VltkMath.logic_of(node)) <= float(data.get("vision", 400))

# ---------------------------------------------------------------- trạng thái / hoạt ảnh

func _enter(state: State, action: String) -> void:
	_state = state
	_action = action
	_state_frames = 0.0
	_state_len = float(MonsterData.action_frames(data, action))
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
	if _state == State.DEAD:
		_tick_dead(delta, frames)
		return
	if net_eid != 0:
		_tick_net(frames)
		return
	if target == null or not is_instance_valid(target):
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
	velocity = VltkWorld.slide_velocity(global_position, velocity, get_physics_process_delta_time())
	move_and_slide()
	var looping := _state == State.IDLE or _state == State.WALK
	_sprite.set_pose(_action, _dir64, _progress(looping))

func _tick_walk(frames: float) -> void:
	var here := VltkMath.to_logic(global_position)
	var to_dest := _walk_dest - here
	var step := float(data.get("walk_speed", 6)) * frames * status_controller.move_speed_multiplier
	if to_dest.length() <= maxf(step, 4.0):
		_enter(State.IDLE, "stand")
		return
	var dir := VltkMath.dir_between(here, _walk_dest)
	if dir >= 0:
		_dir64 = dir
	var speed_logic := to_dest.normalized() * float(data.get("walk_speed", 6)) * (1.25 if blue_boss else 1.0) * FPS * status_controller.move_speed_multiplier
	velocity = VltkMath.to_world(speed_logic)

func _walk_to(dest_logic: Vector2) -> void:
	_walk_dest = dest_logic
	if _state != State.WALK:
		_enter(State.WALK, "walk")

# ---------------------------------------------------------------- AI (KNpcAI::ProcessAIType01 gốc)

## Tham số AI: AI loại 1 dùng đúng AIParam1-9 của quái; loại khác (khác cách đọc tham số) dùng giá trị chung hợp lý.
func _ai_params() -> Array:
	if int(data.get("ai_mode", 1)) == 1:
		return data.get("ai_params", [30, 25, 25, 25, 25, 25, 25, 0, 0])
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

func _ai_think() -> void:
	var mode := int(data.get("ai_mode", 0))
	if mode <= 0:
		return  ## AIMode 0/trống: NPC đứng yên
	var p := _ai_params()
	var here := VltkMath.to_logic(global_position)
	## KeepActiveRange: ra khỏi vùng hoạt động thì quay về chỗ sinh ra.
	var active := float(data.get("active", 400))
	var from_origin := here.distance_to(_origin_logic)
	if active < from_origin:
		_cur_active = active * 0.5
	if _cur_active < from_origin:
		_walk_to(_origin_logic)
		return
	_cur_active = active
	## Khoá kẻ địch trong tầm nhìn.
	var enemy: Node2D = null
	if target != null and is_instance_valid(target) and not GameManager.is_game_over:
		if here.distance_to(VltkMath.logic_of(target)) <= float(data.get("vision", 400)):
			enemy = target
	if enemy == null:
		if int(p[0]) > 0 and randi() % 100 < int(p[0]):
			_patrol()
		return
	var dist := here.distance_to(VltkMath.logic_of(enemy))
	if dist > _max_skill_radius():
		var r := randi() % 100
		if r < int(p[5]):
			return                          # đứng chờ
		if r < int(p[5]) + int(p[6]):
			_patrol()                       # tuần tra
			return
		_walk_to(VltkMath.logic_of(enemy))  # tiến lại gần
		return
	## Trong tầm: chọn 1 trong 4 skill theo xác suất AIParam2-5.
	var roll := randi() % 100
	var slot := -1
	var acc := 0
	for i in 4:
		acc += int(p[i + 1])
		if roll < acc:
			slot = i
			break
	if slot < 0:
		return
	if int(data["skills"][slot][0]) <= 0 or _game_time < _skill_ready[slot]:
		_patrol()
		return
	_active_slot = slot
	_follow_attack(enemy)

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
		VltkSkillRunner.play_cast_sound(self, int(data["skills"][slot][0]))

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
	if not s.is_empty() and int(s.get("style", 0)) == VltkSkillCaster.STYLE_MISSILES:
		var ctx := VltkCastContext.new()
		ctx.launcher = self
		ctx.world = get_parent()
		ctx.stats = null if visual_only else _make_hit_stats(skill_id, skill_level)
		ctx.attacker_stats = combat_stats
		ctx.target_group = &"player"
		VltkSkillCaster.cast(ctx, skill_id, skill_level, VltkMath.logic_of(target), target)
		return
	if visual_only:
		return
	## Skill cận chiến kiểu 1/2/3 chưa có bộ máy riêng: đánh thẳng nếu người chơi còn trong tầm.
	var radius := float(s.get("attack_radius", DEFAULT_ATTACK_RADIUS)) if not s.is_empty() else DEFAULT_ATTACK_RADIUS
	if VltkMath.to_logic(global_position).distance_to(VltkMath.logic_of(target)) <= radius * 1.2:
		## Đòn cận chiến = sát thương cơ bản theo cấp + sát thương cộng thêm của chính skill (thú/quái cơ bản có
		## min/max cơ bản = 0, toàn bộ sát thương nằm ở skill) — giống _make_hit_stats.
		var dmg := MonsterData.melee_damage(data, level, skill_id, skill_level)
		var dmg_min := int(dmg.x * _boss_damage_mult() * _hell_mult())
		var dmg_max := int(dmg.y * _boss_damage_mult() * _hell_mult())
		if dmg_min < 0:  # chưa có dữ liệu gốc
			dmg_min = int(_test_damage() * _hell_mult())
			dmg_max = dmg_min
		var mods := CombatFormulas.HitModifiers.new()
		mods.attacker_node = self
		mods.is_melee = true
		if target.has_method("take_damage_from"):
			target.take_damage_from(combat_stats, dmg_min, dmg_max, CombatFormulas.DamageType.PHYSICS, _build.element, mods)

## Sát thương cơ bản [nhỏ nhất, lớn nhất] theo cấp (công thức gốc); quái chưa có dữ liệu -> chỉ số thử nghiệm.
func _damage_range() -> Vector2:
	var lo := MonsterData.stat_at_level(data, "min_damage", level)
	var hi := MonsterData.stat_at_level(data, "max_damage", level)
	if lo >= 0 and hi >= 0:
		return Vector2(lo, maxf(lo, hi))
	var d := _test_damage()
	return Vector2(d, d)

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

## Đòn của skill quái THEO HỆ: thuộc tính theo cấp của chính skill (đọc từ lua gốc) quyết định loại sát thương —
##   physicsenhance_p/physicsdamage_v = vật lý; colddamage_v = băng (+ làm chậm); firedamage_v = hỏa;
##   lightingdamage_v = lôi; poisondamage_v = độc (rút máu dần); stun_p = choáng; deadlystrike_p = chí mạng;
##   seriesdamage_p = ngũ hành tương khắc. Hệ của đòn = Series của skill (không có thì Series của quái).
## Cấp skill hiệu dụng = cấp skill gốc + cấp quái / 5 (giá trị gốc ở cấp 1 rất nhỏ, quái cấp cao cần mạnh hơn).
func _make_hit_stats(skill_id: int, skill_level: int) -> ResolvedSkillStats:
	var stats := ResolvedSkillStats.new()
	## Có script cấp: cấp chiêu đúng như script trả (Level1-4); không có: cấp gốc + cấp quái / 5 (số gốc cấp 1 quá nhỏ).
	var lv := skill_level if data.get("skill_levels_exact", false) else clampi(skill_level + level / 5, 1, 30)
	var base := _base_damage()
	var skill := VltkSkillData.skill(skill_id, skill_level)
	var series := int(skill.get("series", -1))
	stats.element = (series if series >= 0 and series <= 4 else int(_build.element)) as ElementTypes.ElementType
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

	var enhance := VltkSkillData.hit_attrib(skill_id, "physicsenhance_p", lv)
	var flat := VltkSkillData.hit_attrib(skill_id, "physicsdamage_v", lv)
	if not enhance.is_empty():
		stats.damage = base * (100.0 + float(enhance[0])) / 100.0
	elif not flat.is_empty():
		stats.damage = (float(flat[0]) + float(flat[2] if flat.size() > 2 else flat[0])) * 0.5 + base * 0.5
	elif elements.is_empty():
		stats.damage = base       # skill không khai báo gì: đòn vật lý thường
	else:
		stats.damage = 0.0        # chỉ có sát thương nguyên tố
	## Sát thương cơ bản của script cấp: chiêu ngoại công cộng *DamageBase, nội công cộng *MagicBase (như người chơi).
	var physical := int(skill.get("physical", 1)) == 1
	var extra: Dictionary = combat_stats.outer_element_damage if physical else combat_stats.inner_element_damage
	for t in extra:
		elements[t] = elements.get(t, Vector2i.ZERO) + extra[t]
	if stats.damage > 0.0 or elements.is_empty():
		stats.damage += float(combat_stats.add_physics_damage if physical else combat_stats.add_physics_magic)
	if hell_stars > 1:
		stats.damage *= hell_stars
		for t in elements:
			elements[t] = (elements[t] as Vector2i) * hell_stars
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
	_spawn_number(amount, false)
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
	remove_from_group("enemies")  ## xác không còn là mục tiêu của skill
	set_deferred("collision_layer", 0)
	_health_bar.visible = false
	velocity = Vector2.ZERO
	z_index = -1
	_enter(State.DEAD, "die")
	_death_time = 0.0
	if net_eid != 0:
		return   ## online: thưởng do server báo (S_KILL -> grant_rewards)
	grant_rewards()
	died.emit(self)

## Rớt đồ theo bảng script server gốc (DropTable) + kinh nghiệm (KillRewards, chia theo tổ đội).
## Online: chỉ gọi khi server báo mình được thưởng; `with_drops` = mình là người hạ đòn cuối.
func grant_rewards(with_drops := true) -> void:
	if with_drops and net_eid == 0:   ## online: đồ rơi do server tung (S_DROPS)
		var drops: Array
		if hell_stars > 0:
			drops = DropTable.roll_hell(level, int(_build.element), hell_stars, blue_boss)
		else:
			drops = DropTable.roll_blue_boss(level, int(_build.element)) if blue_boss else DropTable.roll(level, int(_build.element))
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
	_spawn_number(amount, false)
	## Hiện trước trên thanh máu cho cảm giác ngay; số máu thật lấy theo server ở bản tin sau.
	health = maxf(1.0, health - amount)
	_health_bar.set_health(health)
	NetClient.send_damage(net_eid, amount, staggers)

func _tick_net(frames: float) -> void:
	_state_frames += frames
	if _state == State.ATTACK:
		_tick_attack()   ## diễn hết đòn đang ra (bắn ở 60%) rồi mới theo động tác server
		_sprite.set_pose(_action, _dir64, _progress(false))
	if not _net_buffer.is_empty():
		var render_t := NetClient.server_now_ms() - NET_INTERP_DELAY_MS
		while _net_buffer.size() >= 2 and float(_net_buffer[1].t) <= render_t:
			_net_buffer.pop_front()
		var a: Dictionary = _net_buffer[0]
		var feet: Vector2 = a.pos
		if _net_buffer.size() >= 2:
			var b: Dictionary = _net_buffer[1]
			var span := float(b.t) - float(a.t)
			feet = (a.pos as Vector2).lerp(b.pos, clampf((render_t - float(a.t)) / span, 0.0, 1.0) if span > 0.0 else 1.0)
		global_position = feet
		health = max_health * float(a.hp) / 100.0
		_health_bar.set_health(health)
		if (int(a.flags) & NetProto.FLAG_DEAD) != 0:
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

func _spawn_number(amount: float, miss: bool) -> void:
	var at := global_position + Vector2(0, -_sprite.get_height() * 0.6)
	ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), at, func(number):
		if miss:
			number.set_miss()
		else:
			number.set_damage(amount))

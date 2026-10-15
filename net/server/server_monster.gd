class_name ServerMonster
extends ServerEntity
## Quái trên game server: dữ liệu + AI (port KNpcAI::ProcessAIType01 giống VltkMonster), không Node / hình ảnh.
## Toạ độ logic VLTK = VltkMath.to_logic (y x2), tốc độ đi = walk_speed đơn vị logic / frame (18 frame/giây).
##
## Server quyết định đi đâu, đánh ai, lúc nào; khi ra chiêu thì báo (S_MATTACK) cho người đang thấy quái —
## máy của người bị nhắm chạy đòn thật (đạn / cận chiến, né, kháng), máy khác chỉ vẽ hiệu ứng.
## Máu quái nằm ở server: người chơi báo sát thương (C_DAMAGE) đã kiểm tra, hết máu thì chết và hồi sinh sau `respawn` giây.

enum State { IDLE, WALK, ATTACK, HURT, DEAD }

const DEFAULT_ATTACK_RADIUS := 75.0
const CORPSE_SECONDS := 3.0

var monster_id := 0
var data: Dictionary = {}
var series := 0
var blue_boss := false
var spawn_entry: Dictionary = {}
var max_hp := 1.0
var cur_hp := 1.0
var respawn_seconds := 40.0
var state := State.IDLE
var hidden := false               ## đã chết xong + ẩn, chờ hồi sinh
var dead_at := 0.0
var contributors: Dictionary = {} ## eid người chơi -> tổng sát thương (để chia thưởng)
var last_hitter := 0

var _action_name := "stand"
var _state_frames := 0.0
var _state_len := 1.0
var _origin_logic := Vector2.ZERO
var _cur_active := 400.0
var _walk_dest := Vector2.ZERO
var _ai_time := 0.0
var _game_time := 0.0
var _skill_ready: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _max_radius := -1.0
var _target_eid := 0
## Chiến trường Tống Kim: quái của 1 phe (Nguyên Soái) — chỉ đánh / bị đánh bởi người phe kia. "" = quái thường.
var battle_side := ""

## Tạo từ 1 mục npcs của map.json. null nếu quái không có dữ liệu mẫu.
static func from_entry(n: Dictionary, eid_value: int) -> ServerMonster:
	var base := MonsterData.monster(int(n.get("t", 0)))
	if base.is_empty():
		return null
	var m := ServerMonster.new()
	m.eid = eid_value
	m.kind = NetProto.KIND_MONSTER
	m.monster_id = int(n.t)
	m.data = base.duplicate()
	m.series = clampi(int(n.get("series", base.get("series", 0))), 0, 4)
	m.data["series"] = m.series
	m.level = maxi(1, int(n.get("lv", 1)))
	m.name = str(base.get("name", "")).strip_edges()
	m.spawn_entry = n
	m.respawn_seconds = maxf(5.0, float(n.get("respawn", 40)))
	m.pos = Vector2(float(n.px), float(n.py))
	m._origin_logic = VltkMath.to_logic(m.pos)
	m.reset()
	return m

## (Hồi) sinh: đủ máu, về chỗ gốc, 2% thành boss xanh như script Revive gốc.
func reset() -> void:
	blue_boss = randf() < DropTable.BLUE_BOSS_CHANCE
	var life := MonsterData.stat_at_level(data, "life", level)
	if life < 0:
		life = int((20 + level * 6) * float(data.get("life_param", 100)) / 100.0) * 10
	max_hp = maxf(1.0, float(life))
	cur_hp = max_hp
	pos = VltkMath.to_world(_origin_logic)
	_cur_active = float(data.get("active", 400))
	dir = randi() % VltkMath.MAX_DIR
	contributors.clear()
	last_hitter = 0
	hidden = false
	flags = 0
	_skill_ready = [0.0, 0.0, 0.0, 0.0]
	_enter(State.IDLE, "stand")
	hp = 100
	touch()

func write_spawn(b: StreamPeerBuffer) -> void:
	super.write_spawn(b)
	b.put_u16(monster_id)
	b.put_u8(series)
	b.put_u8(1 if blue_boss else 0)

func is_dead() -> bool:
	return state == State.DEAD

func _enter(s: State, action_name: String) -> void:
	state = s
	_action_name = action_name
	action = NetProto.monster_action_index(action_name)
	_state_frames = 0.0
	_state_len = float(MonsterData.action_frames(data, action_name))
	touch()

# ---------------------------------------------------------------- mô phỏng (1 lần / tick server = 1 frame VLTK)

func tick(gs: GameServer) -> void:
	_game_time += 1.0
	if state == State.DEAD:
		return
	_state_frames += 1.0
	match state:
		State.WALK:
			_tick_walk(gs)
		State.ATTACK:
			if _state_frames >= _state_len:
				_enter(State.IDLE, "stand")
		State.HURT:
			if _state_frames >= _state_len:
				_enter(State.IDLE, "stand")
	if state == State.IDLE or state == State.WALK:
		_ai_time += 1.0
		if _ai_time >= float(maxi(1, int(data.get("ai_max_time", 10)))):
			_ai_time = 0.0
			_ai_think(gs)

func _tick_walk(gs: GameServer) -> void:
	var here := VltkMath.to_logic(pos)
	var to_dest := _walk_dest - here
	var step := float(data.get("walk_speed", 6)) * (1.25 if blue_boss else 1.0)
	if to_dest.length() <= maxf(step, 4.0):
		_enter(State.IDLE, "stand")
		return
	var d := VltkMath.dir_between(here, _walk_dest)
	if d >= 0 and d != dir:
		dir = d
	var next := VltkMath.to_world(here + to_dest.normalized() * step)
	## Trượt theo từng trục khi vướng vật cản (như VltkWorld.slide_velocity).
	if gs.grid.is_blocked(next):
		var only_x := Vector2(next.x, pos.y)
		var only_y := Vector2(pos.x, next.y)
		if not gs.grid.is_blocked(only_x):
			next = only_x
		elif not gs.grid.is_blocked(only_y):
			next = only_y
		else:
			_enter(State.IDLE, "stand")
			return
	pos = next
	touch()
	gs.aoi.update(self)

func _walk_to(dest_logic: Vector2) -> void:
	_walk_dest = dest_logic
	if state != State.WALK:
		_enter(State.WALK, "walk")

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

func _max_skill_radius() -> float:
	if _max_radius < 0.0:
		_max_radius = 0.0
		for slot in 4:
			if int(data["skills"][slot][0]) > 0:
				_max_radius = maxf(_max_radius, _skill_radius(slot))
		if _max_radius <= 0.0:
			_max_radius = DEFAULT_ATTACK_RADIUS
	return _max_radius

func _ai_think(gs: GameServer) -> void:
	if int(data.get("ai_mode", 0)) <= 0:
		return
	var p := _ai_params()
	var here := VltkMath.to_logic(pos)
	var active := float(data.get("active", 400))
	var from_origin := here.distance_to(_origin_logic)
	if active < from_origin:
		_cur_active = active * 0.5
	if _cur_active < from_origin:
		_walk_to(_origin_logic)
		return
	_cur_active = active
	var enemy := gs.nearest_player(pos, float(data.get("vision", 400)), battle_side)
	if enemy == null:
		_target_eid = 0
		if int(p[0]) > 0 and randi() % 100 < int(p[0]):
			_patrol()
		return
	_target_eid = enemy.eid
	var there := VltkMath.to_logic(enemy.pos)
	var dist := here.distance_to(there)
	if dist > _max_skill_radius():
		var r := randi() % 100
		if r < int(p[5]):
			return
		if r < int(p[5]) + int(p[6]):
			_patrol()
			return
		_walk_to(there)
		return
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
	if dist <= _skill_radius(slot):
		_begin_attack(gs, slot, enemy)
	else:
		_walk_to(there)

func _patrol() -> void:
	var off := Vector2.ZERO
	if randi() % 100 >= 80:
		var half := maxi(1, int(_cur_active * 0.5))
		off = Vector2(randi_range(-half, half), randi_range(-half, half))
	_walk_to(_origin_logic + off)

func _begin_attack(gs: GameServer, slot: int, enemy: ServerEntity) -> void:
	var s := _skill_data(slot)
	var action_name := "attack1"
	match int(s.get("char_anim", 9)):
		10: action_name = "attack2"
		11, 14: action_name = "magic"
	var d := VltkMath.dir_between(VltkMath.to_logic(pos), VltkMath.to_logic(enemy.pos))
	if d >= 0:
		dir = d
	_enter(State.ATTACK, action_name)
	_skill_ready[slot] = _game_time + float(maxi(int(s.get("time_per_cast", 0)), int(_state_len)))
	gs.monster_attack(self, slot, enemy)

# ---------------------------------------------------------------- nhận sát thương

## Trả true nếu quái chết vì đòn này.
func receive_damage(attacker_eid: int, amount: float, staggers: bool) -> bool:
	if state == State.DEAD or amount <= 0.0:
		return false
	cur_hp -= amount
	contributors[attacker_eid] = float(contributors.get(attacker_eid, 0.0)) + amount
	last_hitter = attacker_eid
	hp = clampi(ceili(cur_hp / max_hp * 100.0), 0, 100)
	touch()
	if cur_hp <= 0.0:
		hp = 0
		flags |= NetProto.FLAG_DEAD
		_enter(State.DEAD, "die")
		return true
	if staggers and state != State.HURT:
		var recover := int(data.get("hit_recover", 0))
		if recover < 100:
			_enter(State.HURT, "hurt")
			_state_len = maxf(1.0, float(MonsterData.action_frames(data, "hurt")) * float(100 - recover) / 100.0)
	return false

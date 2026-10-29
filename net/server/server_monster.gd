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
var is_boss := false
var gold_boss := false
var small_gold_boss := false
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
var _next_ai_time := 0.0
var _game_time := 0.0
var _active_slot := 0
var _skill_ready: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _max_radius := -1.0
var _target_eid := 0
## Chiến trường Tống Kim: quái của 1 phe (Nguyên Soái) — chỉ đánh / bị đánh bởi người phe kia. "" = quái thường.
var battle_side := ""
## Quái phòng ĐỊA NGỤC (FieldServer): 1-5 sao — máu ×sao ở đây; sát thương ×sao tính ở máy người bị đánh (VltkMonster.hell_stars,
## game đọc số sao của phòng); rơi đồ theo DropTable.roll_hell. 0 = thường.
var hell_stars := 0
## Thông số AI đọc 1 lần từ `data` (_cache_params) — tick chạy cho hàng nghìn quái mỗi giây, tra Dictionary bằng chuỗi mỗi tick rất tốn.
var _ai_mode := 0
var _ai_max_time := 10.0
var _walk_speed := 6.0
var _vision := 400.0
var _active := 400.0
var _ai_p: Array = []

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
	m.apply_level_script()
	m.reset()
	return m

## Script cấp gốc theo hệ + cấp hiện tại (máu / kinh nghiệm / chiêu / AI — giống hệt quái offline VltkMonster). Gọi lại sau khi đổi
## `level` (phòng Địa Ngục) rồi reset().
func apply_level_script() -> void:
	data = MonsterData.apply_level_script(_base_data(), monster_id, level)
	_max_radius = -1.0
	_cache_params()

## Dữ liệu mẫu quái (trước script cấp) + hệ của điểm sinh — script cấp tính lại từ đây khi đổi cấp.
func _base_data() -> Dictionary:
	var d := MonsterData.monster(monster_id).duplicate()
	d["series"] = series
	return d

func _cache_params() -> void:
	_ai_mode = int(data.get("ai_mode", 0))
	_ai_max_time = float(maxi(1, int(data.get("ai_max_time", 10))))
	_walk_speed = float(data.get("walk_speed", 6))
	_vision = float(data.get("vision", 400))
	_active = float(data.get("active", 700))
	_ai_p = data.get("ai_params", [30, 25, 25, 25, 25, 25, 25, 0, 0]) if int(data.get("ai_mode", 1)) == 1 else [30, 25, 25, 25, 25, 25, 25, 0, 0]

## (Hồi) sinh: đủ máu, về chỗ gốc, 2% thành boss xanh như script Revive gốc.
func reset() -> void:
	blue_boss = randf() < DropTable.BLUE_BOSS_CHANCE
	var life := MonsterData.stat_at_level(data, "life", level)
	if life < 0:
		life = int((20 + level * 6) * float(data.get("life_param", 100)) / 100.0) * 10
	max_hp = maxf(1.0, float(life)) * maxi(1, hell_stars)
	if is_boss or data.get("is_boss", false):
		blue_boss = false
		var bt := str(data.get("boss_type", "gold"))
		if bt == "small_gold":
			max_hp = maxf(max_hp, float(data.get("life", 15000000)))
		elif bt == "killer":
			max_hp = maxf(max_hp, float(data.get("life", 500000)))
		else:
			max_hp = maxf(max_hp, float(data.get("life", 18000000)))
	cur_hp = max_hp
	pos = VltkMath.to_world(_origin_logic)
	_cur_active = _active
	dir = randi() % VltkMath.MAX_DIR
	contributors.clear()
	last_hitter = 0
	hidden = false
	flags = 0
	_skill_ready = [0.0, 0.0, 0.0, 0.0]
	_next_ai_time = 0.0
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

# ---------------------------------------------------------------- mô phỏng (1 tick server = 1 frame VLTK)

## Chạy `frames` frame VLTK một lượt. GameServer gọi mỗi quái 2 tick 1 lần với frames = 2 (vị trí chỉ gửi đi 2 tick 1 lần nên người
## chơi thấy y hệt, CPU còn một nửa); thời gian chiêu / AI / hồi chiêu vẫn tính đúng theo frame.
func tick(gs: GameServer, frames := 1) -> void:
	_game_time += frames
	if state == State.DEAD:
		return
	_state_frames += frames
	match state:
		State.WALK:
			_tick_walk(gs, frames)
		State.ATTACK:
			if _state_frames >= _state_len:
				_enter(State.IDLE, "stand")
				if _target_eid != 0 and _has_melee_skill():
					var target_conn = gs.conn_of_eid(_target_eid)
					if target_conn != null and target_conn.entity != null:
						var t_dist := VltkMath.to_logic(pos).distance_to(VltkMath.to_logic(target_conn.entity.pos))
						if t_dist > 65.0:
							_walk_to(VltkMath.to_logic(target_conn.entity.pos))
		State.HURT:
			if _state_frames >= _state_len:
				_enter(State.IDLE, "stand")
	if state == State.IDLE or state == State.WALK:
		if _game_time >= _next_ai_time:
			_next_ai_time = _game_time + _ai_max_time
			_ai_think(gs)

func _tick_walk(gs: GameServer, frames := 1) -> void:
	var here := VltkMath.to_logic(pos)
	var to_dest := _walk_dest - here
	var run_spd := float(data.get("run_speed", _walk_speed))
	var base_spd := maxf(run_spd, _walk_speed) if _target_eid != 0 else _walk_speed
	var step := maxf(base_spd, 6.0) * (1.25 if blue_boss else 1.0) * frames

	# Khi đang dí mục tiêu: nếu mục tiêu di chuyển thì liên tục cập nhật đường đi bám theo
	if _target_eid != 0:
		var target_conn = gs.conn_of_eid(_target_eid)
		if target_conn != null and target_conn.entity != null:
			var target_logic := VltkMath.to_logic(target_conn.entity.pos)
			var stop_rad := 65.0 if _has_melee_skill() else (_skill_radius(_active_slot) * 0.85)
			if here.distance_to(target_logic) <= stop_rad:
				_enter(State.IDLE, "stand")
				var d := VltkMath.dir_between(here, target_logic)
				if d >= 0:
					dir = d
				return
			if _walk_dest.distance_to(target_logic) > 45.0:
				_walk_dest = target_logic
				to_dest = _walk_dest - here
			# Không bao giờ cho to_dest đi ngược hướng với mục tiêu
			var to_enemy := target_logic - here
			if to_dest.dot(to_enemy) < 0.0:
				to_dest = to_enemy
	if to_dest.length() <= maxf(step, 4.0):
		_enter(State.IDLE, "stand")
		return
	var d := VltkMath.dir_between(Vector2.ZERO, to_dest)
	if d >= 0 and d != dir:
		dir = d
	var next := VltkMath.to_world(here + to_dest.normalized() * step)
	## Trượt theo từng trục khi vướng vật cản (như VltkWorld.slide_velocity).
	var grid: MapGrid = gs.grid_of(self)
	if grid.is_blocked(next):
		var only_x := Vector2(next.x, pos.y)
		var only_y := Vector2(pos.x, next.y)
		if not grid.is_blocked(only_x):
			next = only_x
		elif not grid.is_blocked(only_y):
			next = only_y
		else:
			_enter(State.IDLE, "stand")
			return
	pos = next
	touch()
	gs.aoi.update(self)

func _walk_to(dest_logic: Vector2) -> void:
	_walk_dest = dest_logic
	var d := VltkMath.dir_between(VltkMath.to_logic(pos), dest_logic)
	if d >= 0:
		dir = d
	if state != State.WALK:
		_enter(State.WALK, "walk")

func _skill_data(slot: int) -> Dictionary:
	var sk: Array = data["skills"][slot]
	if int(sk[0]) <= 0:
		return {}
	return VltkSkillData.skill(int(sk[0]), int(sk[1]))

func _skill_radius(slot: int) -> float:
	var s := _skill_data(slot)
	var rad := float(s.get("attack_radius", DEFAULT_ATTACK_RADIUS)) if not s.is_empty() else DEFAULT_ATTACK_RADIUS
	var is_melee_skill := int(s.get("melee", 0)) == 1
	var anim_id := int(s.get("char_anim", 9))
	var is_melee_anim := anim_id in [9, 10]
	var has_missile := int(s.get("child", 0)) > 0 or int(s.get("by_missle", 0)) == 1
	if is_melee_skill or is_melee_anim or not has_missile:
		rad = minf(rad, 75.0)
	return rad

func _max_skill_radius() -> float:
	if _max_radius < 0.0:
		_max_radius = 0.0
		for slot in 4:
			if int(data["skills"][slot][0]) > 0:
				_max_radius = maxf(_max_radius, _skill_radius(slot))
		if _max_radius <= 0.0:
			_max_radius = DEFAULT_ATTACK_RADIUS
	return _max_radius

func _has_melee_skill() -> bool:
	for slot in 4:
		if int(data["skills"][slot][0]) > 0 and _skill_radius(slot) <= 75.0:
			return true
	return false

func _ai_think(gs: GameServer) -> void:
	if _ai_mode <= 0 or _vision <= 0.0:
		return
	var p := _ai_p
	var here := VltkMath.to_logic(pos)
	var active := _active
	var from_origin := here.distance_to(_origin_logic)
	var max_active := active * 2.0 if _target_eid != 0 else active
	if max_active < from_origin:
		_cur_active = active * 0.5
	if _cur_active < from_origin:
		_target_eid = 0
		_walk_to(_origin_logic)
		return
	_cur_active = active
	var search_vis := _vision * 1.5 if _target_eid != 0 else _vision
	var enemy := gs.nearest_player(pos, search_vis, battle_side, cell_base)
	if enemy == null:
		_target_eid = 0
		if int(p[0]) > 0 and randi() % 100 < int(p[0]):
			_patrol()
		return
	_target_eid = enemy.eid
	var there := VltkMath.to_logic(enemy.pos)
	var dist := here.distance_to(there)
	if dist > _max_skill_radius():
		_walk_to(there)
		return
	## Khi quái đã đứng gần người chơi (cự ly cận chiến <= 85px): không sử dụng skill tầm xa nữa, chỉ dùng đòn cận chiến/đánh thường.
	var is_close_range := dist <= 85.0
	var has_melee_skill := false
	for i in 4:
		if int(data["skills"][i][0]) > 0 and _skill_radius(i) <= 75.0:
			has_melee_skill = true
			break

	var total_weight := 0
	for i in 4:
		if int(data["skills"][i][0]) > 0:
			if is_close_range and has_melee_skill and _skill_radius(i) > 75.0:
				continue
			total_weight += maxi(0, int(p[i + 1]))
	if total_weight <= 0:
		total_weight = 100
	var roll := randi() % total_weight
	var slot := -1
	var acc := 0
	for i in 4:
		if int(data["skills"][i][0]) <= 0:
			continue
		if is_close_range and has_melee_skill and _skill_radius(i) > 75.0:
			continue
		acc += maxi(0, int(p[i + 1]))
		if roll < acc:
			slot = i
			break
	if slot < 0:
		return
	_active_slot = slot
	if int(data["skills"][slot][0]) <= 0 or _game_time < _skill_ready[slot]:
		var stop_rad := 65.0 if has_melee_skill else (_skill_radius(slot) * 0.85)
		if dist <= stop_rad:
			_enter(State.IDLE, "stand")
			var d := VltkMath.dir_between(here, there)
			if d >= 0:
				dir = d
			return
		_walk_to(there)
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
	var target_dist := VltkMath.to_logic(pos).distance_to(VltkMath.to_logic(enemy.pos))
	if target_dist > _skill_radius(slot):
		_walk_to(VltkMath.to_logic(enemy.pos))
		return
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

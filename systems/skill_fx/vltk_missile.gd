extends Node2D
class_name VltkMissile
## Phép chia nguyên trong file này là CỐ Ý — chép đúng số học số nguyên của bản gốc C++ (g_DirCos, ô logic 32...).
@warning_ignore_start("integer_division")
## 1 viên đạn VLTK — chép vòng đời KMissle gốc (KMissle.cpp), chạy 18 nhịp/giây trên toạ độ logic (VltkMath):
##   sinh ra (DoWait: hiệu ứng "chờ") -> chờ tới StartLifeTime -> PrePareFly -> bay (OnFly theo MoveKind, sự kiện Fly
##   mỗi FlyEventTime nhịp) -> va chạm (CheckCollision: CollidRange 1 = chạm gần nhất, >1 = quét ±ô) -> ProcessCollision
##   (sát thương mọi mục tiêu trong ±DmgRange/2 ô, giới hạn HitCount, cách nhau DmgInterval nhịp) -> DoCollision
##   (ColVanish = 1 biến mất, 0 bay xuyên tiếp) / hết LifeTime (AutoExplode thì nổ) -> DoVanish (sự kiện Vanished).
## Ảnh: giai đoạn bay vẽ trên chính đạn (KMissleRes::Draw); chờ / biến mất / trúng đòn là VltkEffect riêng.
## State runtime nằm hết trên instance (dùng chung skill giữa nhiều người chơi được, ObjectPool tái sử dụng).

const SCENE := preload("res://systems/skill_fx/VltkMissile.tscn")

enum MoveKind { STAND = 0, LINE = 1, RANDOM = 2, CIRCLE = 3, HELIX = 4, FOLLOW = 5, MOTION = 6, PARABOLA = 7,
		SINGLE_LINE = 8, ROLLBACK = 100, TOSS = 101 }
const Phase := VltkSkillData.Phase
## MISSLE_MIN/MAX_COLLISION_ZHEIGHT: chạm đất (Z <= 0) thì nổ/biến mất; bay cao hơn 20 không va chạm.
const MIN_COLLISION_Z := 0
const MAX_COLLISION_Z := 20
## Interupt_EndOldMissleLifeWhenMove: người thi triển di chuyển thì đạn biến mất.
const INTERRUPT_END_WHEN_MOVE := 1
## Đạn Follow (bám mục tiêu) chỉnh hướng sau mỗi FOLLOW_REAIM_TICKS nhịp. KMissle.cpp gốc dùng 8 nhịp (lượn cung).
## Đặt 4 để đường đạn vừa bám sát mục tiêu vừa lượn vòng cung mượt mà chuẩn VLTK.
const FOLLOW_REAIM_TICKS := 4
const DRAW_Z := 1
## Đạn Follow mất mục tiêu (quái đã chết giữa chừng / chưa có mục tiêu) thì đuổi quái gần nhất trong tầm này (toạ độ logic) thay vì
## bay thẳng luôn; quét lại mỗi RETARGET_TICKS nhịp cho rẻ. (Bản gốc bay thẳng — đây là chỉnh theo yêu cầu "đạn dí theo".)
const RETARGET_RANGE := 480.0
const RETARGET_TICKS := 2

static var _next_serial := 1

var ctx: VltkCastContext
var skill: Dictionary = {}     ## skill (đã áp cấp) sinh ra đạn — quyết định sự kiện của đạn (KSkill::CreateMissle)
var data: Dictionary = {}      ## thông số đạn (Missles.txt + ghi đè theo cấp)
var serial := 0                ## đổi mỗi lần lấy từ pool — đạn con giữ (cha, serial) để biết cha còn là viên cũ không
var logic := Vector2.ZERO
var dir := 0
var x_factor := 0              ## hướng bay ×1024 (m_nXFactor/m_nYFactor)
var y_factor := 0
var follow_target: Node2D = null
var status: int = Phase.WAIT

var _speed := 0
var _life := 0
var _cur_life := 0
var _start_life := 0
var _height := 0               ## ×1024
var _z := 0
var _height_speed := 0
var _z_acc := 0
var _move_kind := 0
var _angle := 0
var _temp1 := 0
var _temp2 := 0
var _next_dmg_tick := 0
var _last_col: Node = null
var _ref := Vector2.ZERO
var _parent: VltkMissile = null
var _parent_serial := 0
var _launcher_src := Vector2.ZERO
var _phases: Array = []
var _variant_b := false       ## đang dùng bộ ảnh/âm B (MultiShow)
var _effects: Array = []       ## [{end: nhịp kết thúc (theo _cur_life), target}] — SpecialMovieIsAllEnd / 1 hiệu ứng/mục tiêu
var _acc := 0.0
var _anim: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite

## Sinh 1 viên đạn của skill `skill_lv` tại `logic_pos` (KSkill::Cast* + CreateMissle). null nếu skill không có đạn.
static func create(cast_ctx: VltkCastContext, skill_lv: Dictionary, logic_pos: Vector2, missile_dir: int,
		target: Node2D, start_life: int, parent: VltkMissile = null) -> VltkMissile:
	var m_data := VltkSkillData.missile_for(skill_lv)
	if m_data.is_empty() or cast_ctx.world == null:
		return null
	var m: VltkMissile = ObjectPool.acquire(SCENE, cast_ctx.world)
	m._setup(cast_ctx, skill_lv, m_data, logic_pos, missile_dir, target, start_life, parent)
	return m

func _setup(cast_ctx: VltkCastContext, skill_lv: Dictionary, m_data: Dictionary, logic_pos: Vector2, missile_dir: int,
		target: Node2D, start_life: int, parent: VltkMissile) -> void:
	ctx = cast_ctx
	skill = skill_lv
	data = m_data
	serial = _next_serial
	_next_serial += 1
	logic = logic_pos
	_ref = logic_pos
	dir = wrapi(missile_dir, 0, VltkMath.MAX_DIR)
	follow_target = target
	_parent = parent
	_parent_serial = parent.serial if parent else 0
	_move_kind = int(data.get("move_kind", 0))
	_speed = int(data.get("speed", 0))
	_height = int(data["height_raw"]) if data.has("height_raw") else int(data.get("height", 0)) << 10
	_z = _height >> 10
	_height_speed = int(data.get("zspeed", 0))
	_z_acc = int(data.get("zacc", 0))
	_angle = 0
	_temp1 = 0
	_temp2 = 0
	_next_dmg_tick = 0
	_last_col = null
	_effects.clear()
	_acc = 0.0
	_cur_life = 0
	_start_life = start_life
	var range_mult := 1.0
	if ctx != null and ctx.stats != null and ctx.stats.range_multiplier > 0.0:
		range_mult = ctx.stats.range_multiplier
	elif ctx != null and ctx.launcher != null and ctx.launcher.is_in_group("player"):
		range_mult = PlayerStats.range_multiplier
	_life = int((int(data.get("life", 0)) + start_life) * range_mult)
	_launcher_src = ctx.launcher_logic() if ctx.is_valid() else logic
	## MultiShow: cùng 1 đạn có 2 bộ ảnh, chọn ngẫu nhiên (KMissle::operator=).
	_phases = data.get("anims", [])
	_variant_b = false
	if int(data.get("multi_show", 0)) and randi() % 2 == 1:
		var anims_b: Array = data.get("anims_b", [])
		if not anims_b.is_empty() and anims_b.size() > Phase.FLY and anims_b[Phase.FLY] != null:
			_phases = anims_b
			_variant_b = true
	if _move_kind in [MoveKind.LINE, MoveKind.ROLLBACK, MoveKind.FOLLOW]:
		set_factors(VltkMath.dir_cos(dir), VltkMath.dir_sin(dir))
	z_index = DRAW_Z
	if _sprite == null:
		_sprite = $Sprite
	_sprite.visible = false
	_sprite.centered = false
	_sprite.region_enabled = true
	var fly: Variant = _phase(Phase.FLY)
	_anim = VltkSkillData.anim(str(fly["anim"])) if fly is Dictionary else {}
	_sprite.texture = VltkSkillData.texture(str(fly["anim"])) if fly is Dictionary else null
	status = Phase.WAIT
	global_position = VltkMath.to_world(logic)
	_spawn_effect(Phase.WAIT, logic)  ## DoWait

func set_factors(xf: int, yf: int) -> void:
	x_factor = xf
	y_factor = yf

## Parabola từ CastExtractiveLineMissle: tốc độ lên = gia tốc × (số nhịp tới đích - 1) / 2 -> rơi đúng tại đích.
func aim_parabola(distance: float) -> void:
	if _move_kind == MoveKind.PARABOLA and _speed > 0:
		var time := int(distance) / _speed
		_height_speed = _z_acc * (time - 1) / 2

func get_logic_pos() -> Vector2:
	return logic

func _phase(phase: int) -> Variant:
	return _phases[phase] if phase < _phases.size() else null

func _physics_process(delta: float) -> void:
	_acc += delta
	while _acc >= VltkMath.TICK:
		_acc -= VltkMath.TICK
		if not _activate():
			ObjectPool.release(self)
			return
	_update_visual()

## KMissle::Activate — false = đạn đã xong (trả về pool).
func _activate() -> bool:
	if ctx == null or not ctx.is_valid():
		_do_vanish()
		return false
	if follow_target != null and not (is_instance_valid(follow_target) and follow_target.is_inside_tree()):
		follow_target = null
	if _cur_life >= _life and status != Phase.VANISH and status != Phase.COLLISION:
		if int(data.get("auto_explode", 0)):
			_process_collision_at(logic, int(data.get("dmg_range", 0)))
			if int(skill.get("collide_event", 0)):
				_on_event("collide")
		_do_vanish()
		return false
	if _cur_life == _start_life and status != Phase.VANISH:
		if _prepare_fly():
			status = Phase.FLY
			_play_sound(Phase.FLY, logic)  ## KMissle: PlaySound(MS_DoFly) lúc bắt đầu bay
		else:
			_do_vanish()
			return false
	if status == Phase.FLY:
		_on_fly()
		var fly_time := int(skill.get("fly_time", 0))
		if int(skill.get("fly_event", 0)) and fly_time > 0 and (_cur_life - _start_life) % fly_time == 0:
			_on_event("fly")
	_cur_life += 1
	return status != Phase.VANISH

func _prepare_fly() -> bool:
	if _move_kind == MoveKind.ROLLBACK:
		_temp2 = _start_life + (_life - _start_life) / 2
	if int(skill.get("stop_when_move", 0)) and ctx.launcher_logic() != _launcher_src:
		return false
	if int(skill.get("heel", 0)):
		## HeelAtParent: dịch theo độ lệch của cha (đạn mẹ hoặc người thi triển) kể từ lúc sinh.
		var parent_pos: Vector2
		if _parent_serial != 0:
			if not (is_instance_valid(_parent) and _parent.serial == _parent_serial):
				return false
			parent_pos = _parent.logic
		else:
			parent_pos = ctx.launcher_logic()
		logic += parent_pos - _ref
	return true

func _on_fly() -> void:
	if int(skill.get("stop_when_move", 0)) == INTERRUPT_END_WHEN_MOVE and ctx.launcher_logic() != _launcher_src:
		_spawn_effect(Phase.VANISH, logic)
		_do_vanish()
		return
	if _z_acc:  ## ZAxisMove
		_height = maxi(0, _height + _height_speed)
		_height_speed -= _z_acc
		_z = _height >> 10
	var off := Vector2.ZERO
	match _move_kind:
		MoveKind.LINE, MoveKind.PARABOLA, MoveKind.SINGLE_LINE:
			off = Vector2(_speed * x_factor, _speed * y_factor)
		MoveKind.ROLLBACK:
			if _temp1 == 0 and _temp2 <= _cur_life:
				x_factor = -x_factor
				y_factor = -y_factor
				_temp1 = 1
				dir = wrapi(dir - VltkMath.MAX_DIR / 2, 0, VltkMath.MAX_DIR)
			off = Vector2(_speed * x_factor, _speed * y_factor)
		MoveKind.CIRCLE, MoveKind.HELIX:
			off = _orbit_step()
		MoveKind.FOLLOW:
			_temp1 += 1
			if follow_target == null and _cur_life % RETARGET_TICKS == 0:
				follow_target = _find_retarget()
			if _temp1 > FOLLOW_REAIM_TICKS:
				_temp1 = 0
				if follow_target != null:
					var des := VltkMath.logic_of(follow_target)
					var dist := int(logic.distance_to(des))
					if dist != 0:
						x_factor = (int(des.x - logic.x) << 10) / dist
						y_factor = (int(des.y - logic.y) << 10) / dist
						dir = maxi(0, VltkMath.dir_between(logic, des))
			off = Vector2(x_factor * _speed, y_factor * _speed)
	logic += off / 1024.0
	if _check_collision() == -1:
		## Đạn parabol (lựu đạn) rơi chạm đất thì nổ ngay điểm rơi — z giảm nhanh nên hay lọt qua khung z ≤ 20 mà chưa kịp trúng.
		if int(data.get("auto_explode", 0)) or _move_kind == MoveKind.PARABOLA:
			_process_collision_at(logic, int(data.get("dmg_range", 0)))
		_spawn_effect(Phase.VANISH, logic)
		_do_vanish()

## Quái (địch của người thi triển) gần đạn nhất trong RETARGET_RANGE; null nếu không có.
func _find_retarget() -> Node2D:
	var best: Node2D = null
	var best_d := RETARGET_RANGE * RETARGET_RANGE
	for t in ctx.targets():
		if not _is_target(t):
			continue
		var d := (VltkMath.logic_of(t) - logic).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best

## MISSLE_MMK_Circle / Helix: quay quanh người thi triển (Param2 = 0) hoặc tại chỗ; Param1 = chiều quay.
func _orbit_step() -> Vector2:
	var pre := wrapi(_angle - 1, 0, VltkMath.MAX_DIR)
	dir = wrapi(_angle + VltkMath.MAX_DIR / 4, 0, VltkMath.MAX_DIR)
	var radius_speed := (_speed + 30) if _move_kind == MoveKind.CIRCLE else (_speed + _cur_life + 50)
	var d := Vector2(radius_speed * (VltkMath.dir_cos(_angle) - VltkMath.dir_cos(pre)),
			radius_speed * (VltkMath.dir_sin(_angle) - VltkMath.dir_sin(pre)))
	if int(data.get("param2", 0)) == 0:
		logic = ctx.launcher_logic()
		if _move_kind == MoveKind.CIRCLE:
			logic += Vector2(30 * (VltkMath.dir_cos(_angle) + VltkMath.dir_cos(pre)),
					30 * (VltkMath.dir_sin(_angle) + VltkMath.dir_sin(pre))) / 1024.0
	_angle = wrapi(_angle + (1 if int(data.get("param1", 0)) else -1), 0, VltkMath.MAX_DIR)
	return d

## KMissle::CheckCollision: -1 = chạm đất, 0 = không chạm, 1 = chạm.
func _check_collision() -> int:
	if _z <= MIN_COLLISION_Z:
		return -1
	if _z > MAX_COLLISION_Z:
		return 0
	var collide_range := int(data.get("collide_range", 0))
	var dmg_range := int(data.get("dmg_range", 0))
	if collide_range == 1:
		var hit := _nearest_collision()
		if hit == null:
			return 0
		if dmg_range == 1:
			_process_collision_at(VltkMath.logic_of(hit), dmg_range)
		else:
			_process_collision_at(logic, dmg_range)
		if _last_col != hit:
			if _move_kind == MoveKind.LINE:
				_last_col = hit
			_do_collision()
		return 1
	var cell := VltkMath.cell_of(logic)
	for t in ctx.targets():
		if not _is_target(t):
			continue
		var c := VltkMath.cell_of(VltkMath.logic_of(t)) - cell
		if absi(c.x) <= collide_range and absi(c.y) <= collide_range:
			## Vùng sát thương (dmg_range / 2 ô) hẹp hơn vùng dò va chạm: chưa ai nằm trong vùng sát thương thì cứ bay tiếp,
			## không nổ/biến mất sớm (nếu không đạn parabol nổ ngay lúc mới bay mà chưa trúng ai).
			if _process_collision_at(logic, dmg_range) > 0:
				_do_collision()
				return 1
			break
	return 0

## CheckNearestCollision: mục tiêu trong 3×3 ô quanh đạn và cách đạn không quá 1 ô (32) mỗi trục.
func _nearest_collision() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for t in ctx.targets():
		if not _is_target(t):
			continue
		var d := VltkMath.logic_of(t) - logic
		if absf(d.x) <= VltkMath.CELL and absf(d.y) <= VltkMath.CELL and d.length_squared() < best_d:
			best_d = d.length_squared()
			best = t
	return best

func _is_target(t: Node) -> bool:
	if not (t is Node2D and is_instance_valid(t) and t.is_inside_tree() and t != ctx.launcher):
		return false
	if t.has_method("is_dead") and t.is_dead():
		return false
	if ctx != null and ctx.launcher != null:
		var l_side: String = str(ctx.launcher.get("battle_side")) if "battle_side" in ctx.launcher else ""
		if l_side != "":
			var t_side: String = ""
			if "battle_side" in t:
				t_side = str(t.battle_side)
			elif t.is_in_group("player"):
				if TongKimLolState.current != null:
					t_side = TongKimLolState.current.team_side
			if t_side == l_side:
				return false
	return true

## KMissle::ProcessCollision: mọi mục tiêu trong ±range/2 ô quanh tâm — hiệu ứng trúng đòn + sát thương.
func _process_collision_at(center: Vector2, dmg_range: int) -> int:
	var interval := int(data.get("dmg_interval", 0))
	if interval:
		if _next_dmg_tick > _cur_life:
			return 0
		_next_dmg_tick = _cur_life + interval
	if dmg_range <= 0:
		return 0
	var r := dmg_range / 2
	var center_cell := VltkMath.cell_of(center)
	var hits: Array = []
	for t in ctx.targets():
		if not _is_target(t):
			continue
		var c := VltkMath.cell_of(VltkMath.logic_of(t)) - center_cell
		if absi(c.x) <= r and absi(c.y) <= r:
			hits.append([c.x, c.y, t])
	hits.sort()  ## thứ tự quét ô gốc: x rồi y
	var count := 0
	var hit_count := int(data.get("hit_count", 0))
	for h in hits:
		var target: Node2D = h[2]
		count += 1
		var follow := target if int(data.get("col_follow", 0)) else null
		_spawn_effect(Phase.COLLISION, VltkMath.logic_of(target), follow, target)
		ctx.deal_damage(target, skill)
		if hit_count > 0 and count >= hit_count:
			break
	return count

## KMissle::DoCollision.
func _do_collision() -> void:
	if status == Phase.COLLISION:
		return
	if int(skill.get("collide_event", 0)):
		_on_event("collide")
	if int(data.get("col_vanish", 0)):
		_spawn_effect(Phase.VANISH, logic)
		_do_vanish()
	else:
		if _effects_all_ended():
			_spawn_effect(Phase.COLLISION, logic)
		status = Phase.FLY

## KMissle::DoVanish (sự kiện Vanished bắn trước khi đạn biến mất).
func _do_vanish() -> void:
	if status == Phase.VANISH:
		return
	if ctx != null and ctx.is_valid() and int(skill.get("vanish_event", 0)):
		_on_event("vanish")
	status = Phase.VANISH

## KSkill::OnMissleEvent: skill sự kiện ở cấp EventSkillLevel; ByMissle = bắn từ vị trí đạn, không thì từ người thi triển.
func _on_event(kind: String) -> void:
	var event_skill := int(skill.get(kind + "_skill", 0))
	var event_level := int(skill.get("event_level", 0))
	if event_skill <= 0 or event_level <= 0 or not ctx.is_valid():
		return
	VltkSkillCaster.cast_event(ctx, event_skill, event_level, self if int(skill.get("by_missle", 0)) else null)

## KMissle::CreateSpecialEffect — mỗi đạn chỉ 1 hiệu ứng còn chạy trên cùng 1 mục tiêu.
func _spawn_effect(phase: int, at_logic: Vector2, follow: Node2D = null, target: Node = null) -> void:
	if target != null:
		for e in _effects:
			if e["target"] == target and e["end"] >= _cur_life:
				return
	_play_sound(phase, at_logic)  ## KMissle::CreateSpecialEffect gọi PlaySound(trạng thái) sau khi qua kiểm tra trùng
	var fx := VltkEffect.spawn(ctx.world, _phase(phase), at_logic - Vector2(0, 5), _z, dir, follow)
	if fx:
		_effects.append({"end": _cur_life + fx.end_tick, "target": target})

## Tiếng đạn theo giai đoạn (SndFile1..4 / SndFileB1..4 trong Missles.txt), phát tại vị trí đạn.
func _play_sound(phase: int, at_logic: Vector2) -> void:
	var stream := VltkSound.missile(int(skill.get("child", 0)), phase, _variant_b)
	if stream != null:
		SfxManager.play(stream, VltkMath.to_world(at_logic))

func _effects_all_ended() -> bool:
	for e in _effects:
		if e["end"] >= _cur_life:
			return false
	return true

## KMissleRes::Draw giai đoạn bay: LoopPlay = lặp theo nhịp; không thì trải đều số frame trên thời gian sống.
func _update_visual() -> void:
	global_position = VltkMath.to_world(logic)
	var fly: Variant = _phase(Phase.FLY)
	var cur := _cur_life - _start_life
	var all_frames := _life - _start_life
	if status != Phase.FLY or not (fly is Dictionary) or _sprite.texture == null or _anim.is_empty() or cur < 0 \
			or (all_frames != 0 and all_frames < cur):
		_sprite.visible = false
		return
	var dirs := maxi(1, int(fly["dirs"]))
	var per_dir := maxi(1, int(fly["frames"]) / dirs)
	var interval := maxi(1, int(fly["interval"]))
	if all_frames == 0:
		all_frames = per_dir
	var frame: int
	if int(data.get("loop", 0)):
		var sub_start := int(data.get("sub_start", 0))
		var sub_stop := int(data.get("sub_stop", 0))
		if not int(data.get("sub_loop", 0)):
			frame = (cur / interval) % per_dir
		elif cur / interval < sub_start:
			frame = cur / interval
		elif sub_start == sub_stop:
			frame = sub_start
		else:
			frame = sub_start + ((cur - sub_start) / interval) % (sub_stop - sub_start)
	else:
		frame = per_dir * cur / all_frames
	if frame > per_dir - 1:
		_sprite.visible = false
		return
	var index := VltkMath.image_dir(dir, dirs) * per_dir + frame
	if index >= int(_anim.get("frames", 1)):
		_sprite.visible = false
		return
	var size: Array = _anim["size"]
	var offset: Array = _anim["offset"]
	var cols := int(_anim.get("cols", 1))
	_sprite.visible = true
	_sprite.region_rect = Rect2((index % cols) * size[0], (index / cols) * size[1], size[0], size[1])
	_sprite.position = Vector2(offset[0], offset[1] - _z * VltkMath.Z_SCREEN)

func _on_pool_release() -> void:
	ctx = null
	follow_target = null
	_parent = null
	_last_col = null
	_effects.clear()

@warning_ignore_restore("integer_division")

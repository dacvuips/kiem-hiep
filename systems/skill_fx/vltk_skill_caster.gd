extends RefCounted
class_name VltkSkillCaster
## Thi triển skill VLTK theo đúng KSkill gốc (KSkills.cpp): Cast -> CastMissles theo đội hình (MisslesForm) ->
## CastWall / CastLine / CastSpread / CastCircle / CastZone / CastExtractiveLineMissle -> sinh đạn (BaseSkill = 1) hoặc
## thi triển tiếp skill con (BaseSkill = 0) tại từng vị trí, rồi skill sự kiện Start.
## Toạ độ logic (VltkMath). Người thi triển = ctx.launcher; "đạn mẹ" (khi skill sự kiện bắn từ đạn) = from_missile.

enum Form { WALL, LINE, SPREAD, CIRCLE, RANDOM, ZONE, AT_TARGET, AT_FIRER }
## Cách sinh đạn (eMisslesGenerateStyle): thời điểm xuất hiện của viên thứ i.
enum Generate { NONE, SAME_TIME, ORDER, RANDOM_ORDER, RANDOM_SAME, CENTER_EXTEND_LINE }
const STYLE_MISSILES := 0

## Người thi triển ra chiêu nhắm `des` (logic) / mục tiêu `target` (null = nhắm điểm). Trả về số đạn đã sinh.
static func cast(ctx: VltkCastContext, skill_id: int, level: int, des: Vector2, target: Node2D, wait: int = 0) -> int:
	return _cast(ctx, VltkSkillData.skill(skill_id, level), des, target, wait, null)

## KSkill::OnMissleEvent: chỉ skill bắn đạn; từ đạn (ByMissle) thì đội hình lấy vị trí/hướng/mục tiêu của đạn,
## không thì từ người thi triển nhắm chính chỗ mình đứng. Gọi thẳng CastMissles (không kích Start của skill sự kiện).
static func cast_event(ctx: VltkCastContext, skill_id: int, level: int, from_missile: VltkMissile) -> int:
	var s := VltkSkillData.skill(skill_id, level)
	if s.is_empty() or int(s["style"]) != STYLE_MISSILES:
		return 0
	var des := from_missile.logic if from_missile else ctx.launcher_logic()
	return _cast_missiles(ctx, s, des, null, 0, from_missile)

## KSkill::Cast.
static func _cast(ctx: VltkCastContext, s: Dictionary, des: Vector2, target: Node2D, wait: int, from_missile: VltkMissile) -> int:
	if s.is_empty() or not ctx.is_valid():
		return 0
	var count := 0
	if int(s["style"]) == STYLE_MISSILES:
		count = _cast_missiles(ctx, s, des, target, wait, from_missile)
	var start_skill := int(s.get("start_skill", 0))
	var event_level := int(s.get("event_level", 0))
	if int(s.get("start_event", 0)) and start_skill > 0 and event_level > 0:
		count += _cast(ctx, VltkSkillData.skill(start_skill, event_level), des, target, wait, from_missile)
	return count

## KSkill::CastMissles.
static func _cast_missiles(ctx: VltkCastContext, s: Dictionary, des: Vector2, target: Node2D, wait: int,
		from_missile: VltkMissile) -> int:
	var form := int(s["form"])
	if from_missile != null:
		var ref := from_missile.logic
		var mdir := from_missile.dir
		var mtarget := from_missile.follow_target
		match form:
			Form.WALL:
				return _wall(ctx, s, wrapi(mdir + VltkMath.MAX_DIR / 4, 0, VltkMath.MAX_DIR), ref, mtarget, wait, from_missile)
			Form.LINE:
				return _line(ctx, s, mdir, ref, mtarget, wait, from_missile)
			Form.SPREAD:
				return _spread(ctx, s, mdir, ref, mtarget, wait, from_missile)
			Form.CIRCLE:
				return _circle(ctx, s, mdir, ref, mtarget, wait, from_missile)
			Form.ZONE, Form.AT_TARGET, Form.AT_FIRER:
				return _zone(ctx, s, mdir, ref, mtarget, wait, from_missile)
		return 0
	var src := ctx.launcher_logic()
	if target != null and is_instance_valid(target):
		des = VltkMath.logic_of(target)
	var dir := maxi(0, VltkMath.dir_between(src, des))
	var child_kind := int(VltkSkillData.missile_for(s).get("move_kind", -1))
	var single := int(s["child_num"]) == 1
	match form:
		Form.WALL:
			var wdir := wrapi(dir + VltkMath.MAX_DIR / 4, 0, VltkMath.MAX_DIR)
			var at := des if int(s["param1"]) == 0 or int(s["param2"]) == 0 else src
			return _wall(ctx, s, wdir, at, target, wait, null)
		Form.LINE:
			if single and child_kind in [VltkMissile.MoveKind.LINE, VltkMissile.MoveKind.PARABOLA]:
				return _extractive_line(ctx, s, dir, src, des, target, wait)
			return _line(ctx, s, dir, src, target, wait, null)
		Form.SPREAD:
			if single and child_kind == VltkMissile.MoveKind.LINE:
				return _extractive_line(ctx, s, dir, src, des, target, wait)
			return _spread(ctx, s, dir, src, target, wait, null)
		Form.CIRCLE:
			return _circle(ctx, s, dir, src if int(s["param1"]) == 0 else des, target, wait, null)
		Form.ZONE, Form.AT_FIRER:
			return _zone(ctx, s, dir, src, target, wait, null)
		Form.AT_TARGET:
			return _zone(ctx, s, dir, des, target, wait, null)
	return 0

## GetMissleGenerateTime: thời điểm xuất hiện (nhịp) của viên thứ i, tính cả WaitTime của skill.
static func generate_time(s: Dictionary, i: int) -> int:
	var w := int(s["wait"])
	var g := int(s["gen_data"])
	match int(s["gen_style"]):
		Generate.SAME_TIME:
			return w + g
		Generate.ORDER:
			return w + i * g
		Generate.RANDOM_ORDER:
			if g <= 0:
				return w + i * g
			if randi() % 2 == 1:
				return w + i * g + randi() % g
			return maxi(0, w + i * g - randi() % maxi(1, g / 2))
		Generate.RANDOM_SAME:
			return w + (randi() % g if g > 0 else 0)
		Generate.CENTER_EXTEND_LINE:
			var n := int(s["child_num"])
			return w if n <= 1 else w + absi(i - n / 2) * g
	return w

## 1 vị trí trong đội hình: sinh đạn (BaseSkill) hoặc thi triển skill con tại đó.
static func _emit(ctx: VltkCastContext, s: Dictionary, i: int, pos: Vector2, missile_dir: int, target: Node2D,
		wait: int, parent: VltkMissile) -> VltkMissile:
	var t := wait + generate_time(s, i)
	if int(s["base"]) == 1:
		return VltkMissile.create(ctx, s, pos, missile_dir, target, t, parent)
	var child_level := int(s.get("child_level", 0))
	var child := VltkSkillData.skill(int(s["child"]), child_level if child_level > 0 else int(s["level"]))
	_cast(ctx, child, pos, null, t, parent)
	return null

static func _offset(dir: int, dist: float) -> Vector2:
	return Vector2(VltkMath.dir_cos(dir) * dist, VltkMath.dir_sin(dir) * dist) / 1024.0

## CastWall: Param1 = khoảng cách giữa 2 đạn; Param2 != 0 thì đạn quay về hướng ban đầu (bay tới trước).
static func _wall(ctx: VltkCastContext, s: Dictionary, dir: int, ref: Vector2, target: Node2D, wait: int, parent: VltkMissile) -> int:
	var num := int(s["child_num"])
	var each := int(s["param1"])
	var cur := -each * num / 2
	var count := 0
	for i in num:
		var mdir := wrapi(dir - VltkMath.MAX_DIR / 4, 0, VltkMath.MAX_DIR) if int(s["param2"]) else dir
		if _emit(ctx, s, i, ref + _offset(dir, cur), mdir, target, wait, parent):
			count += 1
		cur += each
	return count

## CastLine: Param1 = khoảng cách mỗi đạn dọc hướng bay; Param2 != 0 = xếp so le 2 bên vuông góc.
static func _line(ctx: VltkCastContext, s: Dictionary, dir: int, ref: Vector2, target: Node2D, wait: int, parent: VltkMissile) -> int:
	var num := int(s["child_num"])
	var each := int(s["param1"])
	var count := 0
	var side := 0
	for i in num:
		var pos: Vector2
		if int(s["param2"]):
			var cur := -each * num / 2
			var d1 := dir + VltkMath.MAX_DIR / 4
			if d1 > VltkMath.MAX_DIR:
				d1 -= VltkMath.MAX_DIR
			if i % 2:
				cur = -cur
				side += 1
			pos = ref + _offset(d1, cur * side)
		else:
			pos = ref + _offset(dir, each * (i + 1))
		if _emit(ctx, s, i, pos, dir, target, wait, parent):
			count += 1
	return count

## CastExtractiveLineMissle: 1 đạn bay chính xác từ người thi triển tới điểm nhắm (không làm tròn theo 64 hướng).
static func _extractive_line(ctx: VltkCastContext, s: Dictionary, dir: int, src: Vector2, des: Vector2, target: Node2D, wait: int) -> int:
	var dist := int(src.distance_to(des))
	if dist == 0:
		return 0
	if int(s["base"]) != 1:
		_cast(ctx, VltkSkillData.skill(int(s["child"]), int(s["level"])), des, null, wait + generate_time(s, 0), null)
		return 0
	var m := VltkMissile.create(ctx, s, src, dir, target, wait + generate_time(s, 0), null)
	if m == null:
		return 0
	m.aim_parabola(dist)
	if m.data.get("move_kind", 0) in [VltkMissile.MoveKind.LINE, VltkMissile.MoveKind.PARABOLA, VltkMissile.MoveKind.FOLLOW]:
		m.set_factors((int(des.x - src.x) << 10) / dist, (int(des.y - src.y) << 10) / dist)
	return 1

## CastCircle: num đạn chia đều 64 hướng, cách tâm Param2.
static func _circle(ctx: VltkCastContext, s: Dictionary, dir: int, ref: Vector2, target: Node2D, wait: int, parent: VltkMissile) -> int:
	var num := maxi(1, int(s["child_num"]))
	var first := int(s["param2"])
	var per := VltkMath.MAX_DIR / num
	var count := 0
	for i in num:
		var sub := wrapi(dir + per * i, 0, VltkMath.MAX_DIR)
		if _emit(ctx, s, i, ref + _offset(sub, first), sub, target, wait, parent):
			count += 1
	return count

## CastSpread: toả quạt, Param1 = góc giữa 2 đạn (đơn vị 1/64 vòng), Param2 = quãng đầu; có mục tiêu thì xoay quanh
## đúng vector tới mục tiêu.
static func _spread(ctx: VltkCastContext, s: Dictionary, dir: int, ref: Vector2, target: Node2D, wait: int, parent: VltkMissile) -> int:
	var num := int(s["child_num"])
	var first := int(s["param2"])
	var step := int(s["param1"])
	var radius := num / 2
	var xf := 0
	var yf := 0
	var aimed := target != null and is_instance_valid(target)
	if aimed:
		var des := VltkMath.logic_of(target)
		var dist := int(ref.distance_to(des))
		if dist == 0:
			aimed = false
		else:
			xf = (int(des.x - ref.x) << 10) / dist
			yf = (int(des.y - ref.y) << 10) / dist
	var count := 0
	for i in num:
		var dsub := step * radius
		var cur_sub := wrapi(dir - step * radius, 0, VltkMath.MAX_DIR)
		var sin_ab: int
		var cos_ab: int
		if aimed:
			dsub = wrapi(dsub + 48, 0, VltkMath.MAX_DIR)
			sin_ab = (yf * VltkMath.dir_cos(dsub) - xf * VltkMath.dir_sin(dsub)) >> 10
			cos_ab = (xf * VltkMath.dir_cos(dsub) + yf * VltkMath.dir_sin(dsub)) >> 10
		else:
			sin_ab = VltkMath.dir_sin(cur_sub)
			cos_ab = VltkMath.dir_cos(cur_sub)
		var pos := ref + Vector2(cos_ab * first, sin_ab * first) / 1024.0
		var m := _emit(ctx, s, i, pos, cur_sub, target, wait, parent)
		if m:
			m.set_factors(cos_ab, sin_ab)
			count += 1
		radius -= 1
	return count

## CastZone: lưới num × num ô quanh tâm (Param1 = 1: chỉ lấy hình tròn nội tiếp).
static func _zone(ctx: VltkCastContext, s: Dictionary, dir: int, ref: Vector2, target: Node2D, wait: int, parent: VltkMissile) -> int:
	var num := int(s["child_num"])
	var begin := ref if num == 1 else ref - Vector2(num * VltkMath.CELL / 2, num * VltkMath.CELL / 2)
	var count := 0
	for i in num:
		for j in num:
			if int(s["param1"]) == 1:
				var di := i - num / 2
				var dj := j - num / 2
				if di * di + dj * dj > num * num / 4:
					continue
			if _emit(ctx, s, i * num + j, begin + Vector2(j * VltkMath.CELL, i * VltkMath.CELL), dir, target, wait, parent):
				count += 1
	return count

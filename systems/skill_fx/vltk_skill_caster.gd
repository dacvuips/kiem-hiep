extends RefCounted
class_name VltkSkillCaster
## Phép chia nguyên trong file này là CỐ Ý — chép đúng số học số nguyên của bản gốc C++ (g_DirCos, ô logic 32...).
@warning_ignore_start("integer_division")
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
	## Skill sự kiện HỖ TRỢ (TargetAlly/TargetSelf, không đánh địch — VD Ngọc Tuyền Tâm Kinh 1114 -> FlyEvent 1115 liệu
	## thương): đạn của nó không gây sát thương mà áp trạng thái lên người cùng phe quanh chỗ đạn mẹ (ByMissle).
	if int(s.get("target_enemy", 0)) == 0 and (int(s.get("target_ally", 0)) != 0 or int(s.get("target_self", 0)) != 0):
		SectSkillController.apply_event_support(ctx.launcher, skill_id, level,
				from_missile.logic if from_missile != null else ctx.launcher_logic())
	var target: Node2D = null
	if from_missile != null:
		if is_instance_valid(from_missile._last_col) and from_missile._last_col is Node2D:
			target = from_missile._last_col as Node2D
		elif is_instance_valid(from_missile.follow_target) and from_missile.follow_target is Node2D:
			target = from_missile.follow_target as Node2D
	var des := VltkMath.logic_of(target) if target != null else (from_missile.logic if from_missile else ctx.launcher_logic())
	var event_ctx := VltkSkillCaster._resolve_event_context(ctx, s, level)
	return _cast_missiles(event_ctx, s, des, target, 0, from_missile)

## KSkill::Cast.
static func _cast(ctx: VltkCastContext, s: Dictionary, des: Vector2, target: Node2D, wait: int, from_missile: VltkMissile) -> int:
	if s.is_empty() or not ctx.is_valid():
		return 0
	var count := 0
	if int(s["style"]) == STYLE_MISSILES or int(s.get("child", 0)) > 0:
		count = _cast_missiles(ctx, s, des, target, wait, from_missile)
	var start_skill := int(s.get("start_skill", 0))
	var event_level := int(s.get("event_level", 0))
	if event_level <= 0 or (event_level <= 1 and int(s.get("level", 1)) > 1):
		event_level = int(s.get("level", 1))
	if int(s.get("start_event", 0)) and start_skill > 0 and event_level > 0:
		var start_s := VltkSkillData.skill(start_skill, event_level)
		var start_ctx := VltkSkillCaster._resolve_event_context(ctx, start_s, event_level)
		count += _cast(start_ctx, start_s, des, target, wait, from_missile)

	# Kích nổ khí trường (CanDetonate) như Thần Quang Toàn Nhiễu kích nổ Ma Vân Kiếm Khí
	_check_candetonate(ctx, s, des)

	return count

## Kiểm tra và kích nổ các khí trường phù hợp (CanDetonate)
static func _check_candetonate(ctx: VltkCastContext, s: Dictionary, center: Vector2) -> void:
	var skill_id := int(s.get("id", 0))
	var level := int(s.get("level", 1))
	var target_codes: Array[int] = []
	var bonus_pct := 0.0
	var has_detonate := false

	for key in ["candetonate1", "candetonate2", "candetonate3"]:
		if s.has(key):
			var cd_val: Variant = s[key]
			if cd_val is Array and cd_val.size() >= 3:
				var code: int = int(cd_val[0])
				if code > 0:
					target_codes.append(code)
					has_detonate = true
				var pct: float = float(cd_val[2])
				if pct > bonus_pct:
					bonus_pct = pct

	if skill_id == 1384 or has_detonate:
		if target_codes.is_empty():
			target_codes = [107264, 109568]
		if bonus_pct <= 0.0:
			bonus_pct = 100.0 + (level - 1) * (350.0 / 25.0) if level <= 26 else 450.0 + (level - 26) * (110.0 / 6.0)
		var radius: float = float(s.get("attack_radius", 600))
		var bonus_mult := bonus_pct / 100.0
		VltkMissile.detonate_missiles(ctx.launcher, target_codes, center, radius, bonus_mult)

## KSkill::CastMissles.
static func _cast_missiles(ctx: VltkCastContext, s: Dictionary, des: Vector2, target: Node2D, wait: int,
		from_missile: VltkMissile) -> int:
	## Mục tiêu có thể đã chết/bị giải phóng giữa chừng (đạn đuổi theo quái rồi quái chết) — truyền thẳng vào hàm có tham
	## số kiểu Node2D sẽ lỗi "previously freed", nên đổi về null (= nhắm điểm) trước.
	if not is_instance_valid(target):
		target = null
	var form := int(s["form"])
	if from_missile != null:
		var mtarget: Node2D = target if target != null else (from_missile._last_col as Node2D if is_instance_valid(from_missile._last_col) and from_missile._last_col is Node2D else (from_missile.follow_target if is_instance_valid(from_missile.follow_target) else null))
		var ref := VltkMath.logic_of(mtarget) if mtarget != null else from_missile.logic
		var mdir := from_missile.dir
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
	var res_count := 0
	match form:
		Form.WALL:
			var wdir := wrapi(dir + VltkMath.MAX_DIR / 4, 0, VltkMath.MAX_DIR)
			var at := des if int(s["param1"]) == 0 or int(s["param2"]) == 0 else src
			res_count = _wall(ctx, s, wdir, at, target, wait, null)
		Form.LINE:
			if single and child_kind in [VltkMissile.MoveKind.LINE, VltkMissile.MoveKind.PARABOLA]:
				res_count = _extractive_line(ctx, s, dir, src, des, target, wait)
			else:
				res_count = _line(ctx, s, dir, src, target, wait, null)
		Form.SPREAD:
			if single and child_kind == VltkMissile.MoveKind.LINE:
				res_count = _extractive_line(ctx, s, dir, src, des, target, wait)
			else:
				res_count = _spread(ctx, s, dir, src, target, wait, null)
		Form.CIRCLE:
			res_count = _circle(ctx, s, dir, src if int(s["param1"]) == 0 else des, target, wait, null)
		Form.ZONE, Form.AT_FIRER:
			res_count = _zone(ctx, s, dir, src, target, wait, null)
		Form.AT_TARGET:
			res_count = _zone(ctx, s, dir, des, target, wait, null)

	# Survivor Perk: Bắn đạn ngược hướng ra sau lưng (Hồi Mã Thương)
	if from_missile == null and ctx != null and ctx.launcher != null and ctx.launcher.is_in_group("player"):
		_emit_rear_bullets(ctx, s, dir, src, wait)

	return res_count

static func _emit_rear_bullets(ctx: VltkCastContext, s: Dictionary, dir: int, src: Vector2, wait: int) -> void:
	var rear_count := SurvivorPerks.get_rear_bullet_count()
	if rear_count <= 0 or ctx == null:
		return
	var rear_dir := wrapi(dir + VltkMath.MAX_DIR / 2, 0, VltkMath.MAX_DIR)
	for i in rear_count:
		var step := (1 if (i % 2 == 1) else -1) * int((i + 1) / 2)
		var sub_dir := wrapi(rear_dir + step * 2, 0, VltkMath.MAX_DIR)
		_emit(ctx, s, 200 + i, src, sub_dir, null, wait, null)

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

static func _get_extra_projectiles(ctx: VltkCastContext, base_num: int = 1) -> int:
	var extra := 0
	if ctx != null and ctx.star_level > 1:
		extra += base_num * (ctx.star_level - 1)
	if ctx != null and ctx.launcher != null and ctx.launcher.is_in_group("player"):
		extra += PlayerStats.extra_projectile_count
	return extra

static func _offset(dir: int, dist: float) -> Vector2:
	return Vector2(VltkMath.dir_cos(dir) * dist, VltkMath.dir_sin(dir) * dist) / 1024.0

## CastWall: Param1 = khoảng cách giữa 2 đạn; Param2 != 0 thì đạn quay về hướng ban đầu (bay tới trước).
static func _wall(ctx: VltkCastContext, s: Dictionary, dir: int, ref: Vector2, target: Node2D, wait: int, parent: VltkMissile) -> int:
	var base_n := int(s["child_num"])
	var num := base_n + _get_extra_projectiles(ctx, base_n)
	var each := float(int(s["param1"]))
	var cur: float = -each * float(num - 1) / 2.0 if num > 1 else 0.0
	var count := 0
	for i in num:
		var mdir := wrapi(dir - VltkMath.MAX_DIR / 4, 0, VltkMath.MAX_DIR) if int(s["param2"]) else dir
		if _emit(ctx, s, i, ref + _offset(dir, cur), mdir, target, wait, parent):
			count += 1
		cur += each
	return count

## CastLine: Param1 = khoảng cách mỗi đạn dọc hướng bay; Param2 != 0 = xếp so le 2 bên vuông góc.
static func _line(ctx: VltkCastContext, s: Dictionary, dir: int, ref: Vector2, target: Node2D, wait: int, parent: VltkMissile) -> int:
	var base_n := int(s["child_num"])
	var num := base_n + _get_extra_projectiles(ctx, base_n)
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
	var total_count := 0
	var extra := _get_extra_projectiles(ctx, 1)
	var total_shots := 1 + extra
	for i in total_shots:
		var cur_dir := dir
		var cur_des := des
		if i > 0:
			var step := (1 if (i % 2 == 1) else -1) * int((i + 1) / 2)
			cur_dir = wrapi(dir + step * 2, 0, VltkMath.MAX_DIR)
			var angle_rad := float(step) * 0.12
			var diff := des - src
			var rotated := diff.rotated(angle_rad)
			cur_des = src + rotated
		var m := VltkMissile.create(ctx, s, src, cur_dir, target if i == 0 else null, wait + generate_time(s, 0), null)
		if m != null:
			var cur_dist := int(src.distance_to(cur_des))
			m.aim_parabola(cur_dist)
			if int(m.data.get("move_kind", 0)) in [VltkMissile.MoveKind.LINE, VltkMissile.MoveKind.PARABOLA, VltkMissile.MoveKind.FOLLOW]:
				if cur_dist > 0:
					m.set_factors((int(cur_des.x - src.x) << 10) / cur_dist, (int(cur_des.y - src.y) << 10) / cur_dist)
			total_count += 1
	return total_count

## CastCircle: num đạn chia đều 64 hướng, cách tâm Param2.
static func _circle(ctx: VltkCastContext, s: Dictionary, dir: int, ref: Vector2, target: Node2D, wait: int, parent: VltkMissile) -> int:
	var base_n := int(s["child_num"])
	var num := maxi(1, base_n + _get_extra_projectiles(ctx, base_n))
	var first := int(s["param2"])
	var count := 0
	for i in num:
		var step_offset := roundi(float(i * VltkMath.MAX_DIR) / float(num))
		var sub := wrapi(dir + step_offset, 0, VltkMath.MAX_DIR)
		if _emit(ctx, s, i, ref + _offset(sub, first), sub, target, wait, parent):
			count += 1
	return count

## CastSpread: toả quạt, Param1 = góc giữa 2 đạn (đơn vị 1/64 vòng), Param2 = quãng đầu; có mục tiêu thì xoay quanh
## đúng vector tới mục tiêu.
static func _spread(ctx: VltkCastContext, s: Dictionary, dir: int, ref: Vector2, target: Node2D, wait: int, parent: VltkMissile) -> int:
	var base_n := int(s["child_num"])
	var num := base_n + _get_extra_projectiles(ctx, base_n)
	var first := int(s["param2"])
	var step := int(s["param1"])
	if step == 0 and num > 1:
		step = 2
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

## Số liệu đòn của skill con `skill_id` ở cấp `level` nếu nó có SkillDefinition trong phái của người thi triển (người chơi / bot có
## SectSkillController) — null nếu không có (skill con ngoài bảng phái / quái đánh): khi đó tính thô từ lua như cũ.
static func _sect_event_stats(ctx: VltkCastContext, skill_id: int, level: int) -> ResolvedSkillStats:
	if ctx == null or skill_id <= 0 or ctx.launcher == null or not is_instance_valid(ctx.launcher):
		return null
	if not ("skill_controller" in ctx.launcher):
		return null
	var ctrl = ctx.launcher.get("skill_controller")
	if not (ctrl is SectSkillController):
		return null
	var def: SkillDefinition = (ctrl as SectSkillController).find_by_vltk_id(skill_id)
	if def == null or def.is_state_skill():
		return null
	return (ctrl as SectSkillController)._resolve_stats(def, ctx.launcher as Node2D, maxi(1, level))

## Tạo hoặc điều chỉnh ngữ cảnh thi triển cho skill sự kiện (FlyEvent, VanishEvent, CollideEvent, StartEvent).
## Nếu skill sự kiện có thuộc tính sát thương riêng (colddamage_v, firedamage_v, lightingdamage_v, poisondamage_v,
## physicsdamage_v, magicdamage_v...), tạo ResolvedSkillStats riêng đúng chuẩn VLTK (CreateMissleMagicAttribsData).
static func _resolve_event_context(ctx: VltkCastContext, s: Dictionary, level: int) -> VltkCastContext:
	if ctx == null:
		return ctx
	var levels: Dictionary = s.get("levels", {})
	var has_cold := levels.has("colddamage_v")
	var has_fire := levels.has("firedamage_v")
	var has_light := levels.has("lightingdamage_v")
	var has_poison := levels.has("poisondamage_v")
	var has_phys := levels.has("physicsdamage_v")
	var has_magic := levels.has("magicdamage_v")
	var has_enhance := levels.has("physicsenhance_p")

	if not (has_cold or has_fire or has_light or has_poison or has_phys or has_magic or has_enhance):
		return ctx

	var ev_ctx := VltkCastContext.new()
	ev_ctx.launcher = ctx.launcher
	ev_ctx.world = ctx.world
	ev_ctx.attacker_stats = ctx.attacker_stats
	var is_launcher_enemy := ctx.launcher != null and ctx.launcher.is_in_group(&"enemies")
	if int(s.get("target_enemy", 0)) != 0:
		ev_ctx.target_group = &"player" if is_launcher_enemy else &"enemies"
	elif int(s.get("target_ally", 0)) != 0 or int(s.get("target_self", 0)) != 0:
		ev_ctx.target_group = &"enemies" if is_launcher_enemy else &"allies"
	else:
		ev_ctx.target_group = ctx.target_group
	ev_ctx.star_level = ctx.star_level
	ev_ctx.detonate_mult = ctx.detonate_mult

	## Skill con CÓ trong bảng phái (VD Kiếm Minh Thương Khung 1107 / Kiếm Vũ Diệu Nguyệt 1105 của Kiếm Thùy Tinh Hà): tính đúng
	## KNpc::AppendSkillEffect gốc qua SectSkillController._resolve_stats ở cấp sự kiện — có "hỗ trợ từ kỹ năng khác"
	## (GetAddSkillDamage), lực tay / vũ khí, sát thương hệ của trang bị, cường hóa Lôi, chí mạng, độ chính xác.
	var sect_stats := _sect_event_stats(ctx, int(s.get("id", 0)), level)
	if sect_stats != null:
		if ctx.detonate_mult > 1.0:   ## deal_damage chỉ nhân phần chính; phần hệ nhân ở đây như nhánh dưới
			for t in sect_stats.extra_damage_ranges.keys():
				var r: Vector2i = sect_stats.extra_damage_ranges[t]
				sect_stats.extra_damage_ranges[t] = Vector2i(int(r.x * ctx.detonate_mult), int(r.y * ctx.detonate_mult))
		var ev_state_id := int(s.get("state", 0))
		if ev_state_id > 0 and (sect_stats.state_meta.is_empty() or int(sect_stats.state_meta.get("state_id", 0)) == 0):
			var dur_seconds := 5.0
			var asp: int = -15
			var sk_enh: int = 0
			if level >= 21:
				sk_enh = -2
			sect_stats.state_attribs = {
				"attackspeed_v": Vector3i(asp, int(dur_seconds * 18), 0),
				"castspeed_v": Vector3i(asp, int(dur_seconds * 18), 0),
				"attackspeed_yan_v": Vector3i(asp, int(dur_seconds * 18), 0),
				"castspeed_yan_v": Vector3i(asp, int(dur_seconds * 18), 0),
				"skill_enhance": Vector3i(sk_enh, int(dur_seconds * 18), 0),
			}
			sect_stats.state_source_id = "vltk_skill_%d_state_%d" % [int(s.get("id", 0)), ev_state_id]
			sect_stats.state_seconds = dur_seconds
			sect_stats.state_meta = {
				"state_id": ev_state_id,
				"name": str(s.get("name", "Trạng thái")),
				"is_debuff": int(s.get("target_enemy", 1)) == 1,
				"hit_chance_p": 100
			}
		ev_ctx.stats = sect_stats
		return ev_ctx

	var ev_stats := ResolvedSkillStats.new()
	if ctx.stats != null:
		ev_stats.crit_chance = ctx.stats.crit_chance
		ev_stats.five_elements_damage_p = ctx.stats.five_elements_damage_p
		ev_stats.element = ctx.stats.element
		ev_stats.range_multiplier = ctx.stats.range_multiplier

	var series := int(s.get("series", -1))
	if series >= 0 and series < 5:
		ev_stats.element = series as ElementTypes.ElementType

	if levels.has("seriesdamage_p"):
		var s_arr: Array = levels["seriesdamage_p"]
		if not s_arr.is_empty():
			ev_stats.five_elements_damage_p = int(s_arr[clampi(level, 1, s_arr.size()) - 1][0])

	var total_min := 0
	var total_max := 0

	var dmg_mult := 1.0
	if ctx.launcher != null and is_instance_valid(ctx.launcher) and ctx.launcher.is_in_group("player"):
		dmg_mult *= PlayerStats.damage_multiplier
	if ctx.detonate_mult > 1.0:
		dmg_mult *= ctx.detonate_mult
	var skill_enhance := 0.0
	if ctx.attacker_stats != null and ctx.attacker_stats.skill_enhance_p > 0:
		skill_enhance = ctx.attacker_stats.skill_enhance_p / 100.0

	if has_cold:
		var arr: Array = levels["colddamage_v"]
		if not arr.is_empty():
			var val: Array = arr[clampi(level, 1, arr.size()) - 1]
			var lo := int(float(val[0]) * (1.0 + skill_enhance) * dmg_mult)
			var hi := int(float(val[2] if val.size() > 2 else val[0]) * (1.0 + skill_enhance) * dmg_mult)
			ev_stats.extra_damage_ranges[CombatFormulas.DamageType.COLD] = Vector2i(lo, hi)
			total_min += lo
			total_max += hi
			var f_frames := int(val[1]) if val.size() > 1 else 0
			ev_stats.freeze_frames = maxi(18, f_frames)

	if has_fire:
		var arr: Array = levels["firedamage_v"]
		if not arr.is_empty():
			var val: Array = arr[clampi(level, 1, arr.size()) - 1]
			var lo := int(float(val[0]) * (1.0 + skill_enhance) * dmg_mult)
			var hi := int(float(val[2] if val.size() > 2 else val[0]) * (1.0 + skill_enhance) * dmg_mult)
			ev_stats.extra_damage_ranges[CombatFormulas.DamageType.FIRE] = Vector2i(lo, hi)
			total_min += lo
			total_max += hi

	if has_light:
		var arr: Array = levels["lightingdamage_v"]
		if not arr.is_empty():
			var val: Array = arr[clampi(level, 1, arr.size()) - 1]
			var lo := int(float(val[0]) * (1.0 + skill_enhance) * dmg_mult)
			var hi := int(float(val[2] if val.size() > 2 else val[0]) * (1.0 + skill_enhance) * dmg_mult)
			ev_stats.extra_damage_ranges[CombatFormulas.DamageType.LIGHT] = Vector2i(lo, hi)
			total_min += lo
			total_max += hi

	if has_poison:
		var arr: Array = levels["poisondamage_v"]
		if not arr.is_empty():
			var val: Array = arr[clampi(level, 1, arr.size()) - 1]
			var dmg := int(float(val[0]) * (1.0 + skill_enhance) * dmg_mult)
			var time_frames := int(val[1]) if val.size() > 1 else 18
			var interval := int(val[2]) if val.size() > 2 else 18
			ev_stats.extra_damage_ranges[CombatFormulas.DamageType.POISON] = Vector2i(dmg, dmg)
			ev_stats.poison_tick_damage = dmg
			ev_stats.poison_time_frames = time_frames
			ev_stats.poison_interval_frames = interval
			total_min += dmg
			total_max += dmg

	if has_phys:
		var arr: Array = levels["physicsdamage_v"]
		if not arr.is_empty():
			var val: Array = arr[clampi(level, 1, arr.size()) - 1]
			var lo := int(float(val[0]) * (1.0 + skill_enhance) * dmg_mult)
			var hi := int(float(val[2] if val.size() > 2 else val[0]) * (1.0 + skill_enhance) * dmg_mult)
			ev_stats.extra_damage_ranges[CombatFormulas.DamageType.PHYSICS] = Vector2i(lo, hi)
			total_min += lo
			total_max += hi

	if has_magic:
		var arr: Array = levels["magicdamage_v"]
		if not arr.is_empty():
			var val: Array = arr[clampi(level, 1, arr.size()) - 1]
			var lo := int(float(val[0]) * (1.0 + skill_enhance) * dmg_mult)
			var hi := int(float(val[2] if val.size() > 2 else val[0]) * (1.0 + skill_enhance) * dmg_mult)
			ev_stats.extra_damage_ranges[CombatFormulas.DamageType.MAGIC] = Vector2i(lo, hi)
			total_min += lo
			total_max += hi

	if has_enhance:
		var arr: Array = levels["physicsenhance_p"]
		if not arr.is_empty():
			var val: Array = arr[clampi(level, 1, arr.size()) - 1]
			var p_enhance := float(val[0])
			var base_unarmed := 50.0
			if ctx.attacker_stats != null:
				base_unarmed = (ctx.attacker_stats.unarmed_min_damage + ctx.attacker_stats.unarmed_max_damage) * 0.5
			var phys := int(base_unarmed * (100.0 + p_enhance) / 100.0 * dmg_mult)
			var cur_phys: Vector2i = ev_stats.extra_damage_ranges.get(CombatFormulas.DamageType.PHYSICS, Vector2i.ZERO)
			ev_stats.extra_damage_ranges[CombatFormulas.DamageType.PHYSICS] = cur_phys + Vector2i(phys, phys)
			total_min += phys
			total_max += phys

	if levels.has("stun_p"):
		var arr: Array = levels["stun_p"]
		if not arr.is_empty():
			var val: Array = arr[clampi(level, 1, arr.size()) - 1]
			ev_stats.stun_chance_p = int(val[0])
			if val.size() > 1:
				ev_stats.stun_frames = int(val[1])

	var state_id := int(s.get("state", 0))
	if state_id > 0:
		var missrate := 0
		if levels.has("missle_missrate"):
			var arr: Array = levels["missle_missrate"]
			if not arr.is_empty():
				missrate = int(arr[clampi(level, 1, arr.size()) - 1][0])
		var hit_chance := clampi(100 - missrate, 1, 100) if missrate > 0 else 100

		var dur_seconds := 0.27
		if levels.has("randmove"):
			var arr: Array = levels["randmove"]
			if not arr.is_empty():
				var val: Array = arr[clampi(level, 1, arr.size()) - 1]
				var frames := int(val[1]) if val.size() > 1 else (int(val[0]) if val.size() > 0 else 5)
				dur_seconds = maxf(0.27, float(frames) / 18.0)
		elif str(s.get("id")) == "1131":
			dur_seconds = 0.27
		elif int(s.get("id", 0)) in [1970, 101970] or state_id in [240, 100240]:
			dur_seconds = 5.0
			var asp: int = -15
			var sk_enh: int = 0
			if level >= 21:
				sk_enh = -2
			ev_stats.state_attribs = {
				"attackspeed_v": Vector3i(asp, int(dur_seconds * 18), 0),
				"castspeed_v": Vector3i(asp, int(dur_seconds * 18), 0),
				"attackspeed_yan_v": Vector3i(asp, int(dur_seconds * 18), 0),
				"castspeed_yan_v": Vector3i(asp, int(dur_seconds * 18), 0),
				"skill_enhance": Vector3i(sk_enh, int(dur_seconds * 18), 0),
			}

		ev_stats.state_source_id = "vltk_skill_%d_state_%d" % [int(s.get("id", 0)), state_id]
		ev_stats.state_seconds = dur_seconds
		ev_stats.state_meta = {
			"state_id": state_id,
			"name": str(s.get("name", "Trạng thái")),
			"is_debuff": int(s.get("target_enemy", 1)) == 1,
			"hit_chance_p": hit_chance
		}

	ev_stats.damage_min = 0.0
	ev_stats.damage_max = 0.0
	ev_stats.damage = float(total_max)
	ev_stats.main_damage_type = CombatFormulas.DamageType.PHYSICS

	ev_ctx.stats = ev_stats
	return ev_ctx

@warning_ignore_restore("integer_division")

extends RefCounted
class_name VltkSkillRunner
## Phép chia nguyên trong file này là CỐ Ý — chép đúng số học số nguyên của bản gốc C++ (g_DirCos, ô logic 32...).
@warning_ignore_start("integer_division")
## Cầu nối skill môn phái (SkillDefinition) -> bộ máy chiêu VLTK gốc (VltkSkillCaster). Thay cho SectSkillCast với
## skill có dữ liệu skill_fx (tools/import_vltk_skill_fx.py).
##
## Trình tự như KNpc::DoSkill gốc:
##   1. Ảnh xuất chiêu PreCastSpr hiện ngay trên người (KNpcRes::SetSpecialSpr), quay mặt về mục tiêu, diễn động tác
##      (ngoại công: đánh, nội công: thi triển).
##   2. Tới 60% động tác (ATTACKACTION_EFFECT_PERCENT) mới bắn đạn — nhắm vị trí mục tiêu LÚC ĐÓ.

const ATTACK_EFFECT_PERCENT := 0.6
## Hoạt ảnh xuất chiêu hỗ trợ: 1.0 = đúng chuẩn 100% nhịp gốc VLTK
const SUPPORT_ANIM_SPEED := 1.0

## SkillStyle 1 = CẬN CHIẾN (SKILL_SS_Melee) — MisslesForm của nó là eMeleeForm gốc (SkillDef.h, đếm tiếp sau 8 đội hình đạn).
const STYLE_MELEE := 1
const MELEE_BLUR_ATTACK := 8      ## Melee_AttackWithBlur: 1 đòn đánh nhanh
const MELEE_RUN_ATTACK := 11      ## Melee_RunAndAttack: CHẠY lao tới mục tiêu rồi đánh
const MELEE_MANY_ATTACK := 12     ## Melee_ManyAttack: nhiều đòn liên tiếp
const MELEE_MOVE_WITH_BLUR := 13  ## Melee_MoveWithBlur: LƯỚT tới và để lại bóng mờ (Táp Đạp Lưu Tinh, Mê Ảnh Tùng)
const RUSH_STOP_DISTANCE := 42.0  ## chạy tới cách mục tiêu chừng này thì dừng để đánh
const MELEE_APPROACH_SECONDS := 2.0  ## tối đa chạy tới mục tiêu ngoài tầm trong chừng này giây
const TRAIL_CAST_TICKS := 3.0     ## đang chạy lao tới: cứ 3 nhịp thi triển skill con 1 lần (gốc: mỗi nhịp)

## Bóng mờ nhân vật (KNpcRes::SetBlur gốc) — chỉ người thi triển có CharacterAvatar.
static func set_blur(caster: Node, on: bool) -> void:
	if caster != null and is_instance_valid(caster) and "avatar" in caster and caster.avatar != null:
		caster.avatar.set_blur(on)

## KNpc::DoSkill gốc: skill có NeedShadow = 1 bật bóng mờ lúc ra chiêu (tắt ở 60% động tác).
static func needs_shadow(s: Dictionary) -> bool:
	return int(s.get("need_shadow", 0)) != 0

static func is_melee_supported(s: Dictionary) -> bool:
	return int(s.get("style", 0)) == STYLE_MELEE and int(s.get("form", 0)) in [MELEE_BLUR_ATTACK, MELEE_RUN_ATTACK, MELEE_MANY_ATTACK, MELEE_MOVE_WITH_BLUR]

## Skill dùng được bộ máy mới: có SkillId gốc + dữ liệu skill_fx + là skill bắn đạn nhắm địch HOẶC cận chiến (đòn liên tiếp /
## chạy tới đánh).
static func supports(skill: SkillDefinition, level: int) -> bool:
	if skill == null or skill.vltk_skill_id <= 0:
		return false
	var s := VltkSkillData.skill(skill.vltk_skill_id, level)
	if s.is_empty():
		return false
	if is_melee_supported(s):
		return true
	if not skill.target_enemy:
		return false
	return int(s["style"]) == VltkSkillCaster.STYLE_MISSILES or int(s.get("child", 0)) > 0

static func execute(caster: Node2D, target: Node2D, stats: ResolvedSkillStats, skill: SkillDefinition, level: int) -> void:
	var s := VltkSkillData.skill(skill.vltk_skill_id, level)
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	ctx.stats = stats
	ctx.attacker_stats = caster.combat_stats if "combat_stats" in caster else null
	if GameModeManager.is_offline() and GameManager.game_mode == GameManager.GameMode.STAGE:
		ctx.star_level = PlayerStats.get_skill_star(skill.id) if (caster != null and caster.is_in_group("player")) else 1
	else:
		ctx.star_level = 1
	## Người thi triển không phải nhân vật của mình (VD bot PK đánh người chơi) tự khai nhóm mục tiêu.
	if "cast_target_group" in caster:
		ctx.target_group = caster.cast_target_group
	## Mục tiêu ảo (điểm phía trước mặt) chỉ dùng toạ độ — không bám theo.
	var aim_node: Node2D = null if (target == null or target.has_meta("cast_point")) else target
	var aim_point := VltkMath.logic_of(target) if target != null else VltkMath.logic_of(caster)
	play_precast(caster, s)
	play_cast_sound(caster, skill.vltk_skill_id)
	if is_melee_supported(s):
		SfxManager.play_skill_cast(stats, caster.global_position)
		var melee_rad: float = caster.get_skill_radius(skill) if caster.has_method("get_skill_radius") else skill.get_attack_radius_at_level(level)
		_run_melee(ctx, caster, aim_node.get_instance_id() if aim_node != null else 0, aim_point, level, s, melee_rad)
		return
	var delay := 0.0
	if caster.has_method("begin_skill_action"):
		delay = caster.begin_skill_action(int(s.get("physical", 0)) == 1, target.global_position) * ATTACK_EFFECT_PERCENT
	var shadow := needs_shadow(s)
	if shadow:
		set_blur(caster, true)
	SfxManager.play_skill_cast(stats, caster.global_position)
	## Lambda KHÔNG giữ node mục tiêu (quái có thể chết trong lúc chờ tới 60% động tác -> Godot báo "capture was freed"):
	## chỉ giữ ID đối tượng rồi tra lại lúc bắn.
	var aim_id: int = aim_node.get_instance_id() if aim_node != null else 0
	var caster_id := caster.get_instance_id()
	var fire := func() -> void:
		if shadow:
			set_blur(instance_from_id(caster_id), false)
		if not ctx.is_valid():
			return
		var des := aim_point
		var live_aim: Node2D = instance_from_id(aim_id) as Node2D if aim_id != 0 else null
		if live_aim != null and live_aim.is_inside_tree():
			des = VltkMath.logic_of(live_aim)
		else:
			live_aim = null
		VltkSkillCaster.cast(ctx, skill.vltk_skill_id, level, des, live_aim)
	if delay <= 0.0:
		fire.call()
	else:
		caster.get_tree().create_timer(delay, false).timeout.connect(fire)

## ---- Skill CẬN CHIẾN (KNpc::CastMeleeSkill / OnManyAttack / OnRunAttack gốc) ----
## Mục tiêu tra lại bằng ID mỗi bước (quái có thể chết giữa chừng) — không giữ node qua các lần chờ.
static func _melee_aim(target_id: int, fallback_logic: Vector2) -> Dictionary:
	var node: Node2D = instance_from_id(target_id) as Node2D if target_id != 0 else null
	if node != null and node.is_inside_tree():
		return {"node": node, "logic": VltkMath.logic_of(node)}
	return {"node": null, "logic": fallback_logic}

## Skill con (ChildSkillId — đòn đánh tầm gần, đạn "Công kích vật lý" 63...) thi triển ở cấp của skill cha, nhắm mục tiêu.
static func _melee_hit(ctx: VltkCastContext, s: Dictionary, level: int, aim: Dictionary) -> void:
	var child := int(s.get("child", 0))
	if child > 0 and ctx.is_valid():
		VltkSkillCaster.cast(ctx, child, level, aim["logic"], aim["node"])

## Mục tiêu NGOÀI tầm skill thì nhân vật chạy tới trước (như VLTK gốc: bấm đánh quái xa -> đi tới tầm rồi mới ra chiêu).
static func _melee_approach(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, attack_radius: float) -> Dictionary:
	var aim := _melee_aim(target_id, fallback_logic)
	if aim["node"] == null or attack_radius <= 0.0 or not caster.has_method("rush_toward"):
		return aim
	if VltkMath.logic_of(caster).distance_to(aim["logic"]) <= attack_radius:
		return aim
	caster.rush_toward(aim["node"], MELEE_APPROACH_SECONDS, maxf(attack_radius * 0.7, RUSH_STOP_DISTANCE))
	while ctx.is_valid() and caster.is_rushing():
		await caster.get_tree().create_timer(0.05, false).timeout
	return _melee_aim(target_id, aim["logic"])

static func _run_melee(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary, attack_radius: float) -> void:
	caster.set_meta(MELEE_BUSY_META, Time.get_ticks_msec())
	await _run_melee_form(ctx, caster, target_id, fallback_logic, level, s, attack_radius)
	if is_instance_valid(caster):
		caster.remove_meta(MELEE_BUSY_META)
		set_blur(caster, false)

## Đang lao tới / đánh liên hoàn cận chiến (gốc: Npc còn ở trạng thái do_manyattack/do_runattack thì chưa ra chiêu khác).
## Quá MELEE_BUSY_MAX_MS coi như đã xong (phòng coroutine bị bỏ dở).
const MELEE_BUSY_META := &"vltk_melee_busy_ms"
const MELEE_BUSY_MAX_MS := 6000

static func is_melee_busy(caster: Node) -> bool:
	if caster == null or not caster.has_meta(MELEE_BUSY_META):
		return false
	return Time.get_ticks_msec() - int(caster.get_meta(MELEE_BUSY_META)) < MELEE_BUSY_MAX_MS

static func _run_melee_form(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary, attack_radius: float) -> void:
	match int(s["form"]):
		MELEE_MANY_ATTACK:
			var near := await _melee_approach(ctx, caster, target_id, fallback_logic, attack_radius)
			if ctx.is_valid():
				await _melee_many(ctx, caster, target_id, near["logic"], level, s)
		MELEE_RUN_ATTACK:
			await _melee_run(ctx, caster, target_id, fallback_logic, level, s)
		MELEE_MOVE_WITH_BLUR:
			await _melee_move_blur(ctx, caster, target_id, fallback_logic, level, s)
		_:
			var near_single := await _melee_approach(ctx, caster, target_id, fallback_logic, attack_radius)
			if ctx.is_valid():
				await _melee_single(ctx, caster, target_id, near_single["logic"], level, s)

## 1 đòn: diễn động tác đánh, tới 60% động tác thì trúng.
static func _melee_single(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary) -> void:
	var aim := _melee_aim(target_id, fallback_logic)
	var duration := 0.5
	if caster.has_method("begin_skill_action"):
		duration = caster.begin_skill_action(true, VltkMath.to_world(aim["logic"]))
	set_blur(caster, true)  ## DoBlurAttack: bật bóng mờ, OnSkill tắt ở 60% động tác
	await caster.get_tree().create_timer(duration * ATTACK_EFFECT_PERCENT, false).timeout
	set_blur(caster, false)
	_melee_hit(ctx, s, level, _melee_aim(target_id, aim["logic"]))

## DoManyAttack/OnManyAttack: ChildSkillNum đòn liên tiếp; mỗi đòn dài GetMissleGenerateTime(i) nhịp, diễn động tác đánh rồi
## HẾT đòn mới thi triển skill con tại mục tiêu.
static func _melee_many(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary) -> void:
	var steps := maxi(1, int(s.get("child_num", 1)))
	var aim := _melee_aim(target_id, fallback_logic)
	for step in steps:
		if not ctx.is_valid():
			return
		var gen_interval := maxi(2, int(s.get("gen_data", 3)))
		var step_frames: int = int(s.get("wait", 0)) if (step == 0 and int(s.get("wait", 0)) > 0) else gen_interval
		var seconds := float(maxi(2, step_frames)) / VltkMath.FPS
		if caster.has_method("begin_skill_action"):
			## Trả về độ dài thật (Băng sát: dài gấp đôi) — đòn kế tiếp chờ đúng hết động tác.
			seconds = caster.begin_skill_action(true, VltkMath.to_world(aim["logic"]), seconds)
		set_blur(caster, true)  ## DoManyAttack: bật bóng mờ mỗi đòn
		await caster.get_tree().create_timer(seconds, false).timeout
		if not ctx.is_valid():
			return
		aim = _melee_aim(target_id, aim["logic"])
		_melee_hit(ctx, s, level, aim)

## DoRunAttack/OnRunAttack: bước 0 = nhân vật CHẠY lao tới mục tiêu (tối đa GetMissleGenerateTime(0) nhịp), vừa chạy vừa
## thi triển skill con; bước 1 = đứng lại đánh, tới 60% động tác thì trúng.
static func _melee_run(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary) -> void:
	var aim := _melee_aim(target_id, fallback_logic)
	if aim["node"] != null and caster.has_method("rush_toward"):
		## Thời gian lao tối thiểu theo dữ liệu gốc (GetMissleGenerateTime(0) nhịp), kéo dài đủ để TỚI nơi nếu mục tiêu còn xa.
		var rush_seconds := float(maxi(2, VltkSkillCaster.generate_time(s, 0))) / VltkMath.FPS
		if caster.has_method("get_rush_speed"):
			var need := caster.global_position.distance_to((aim["node"] as Node2D).global_position) / maxf(caster.get_rush_speed(), 1.0)
			rush_seconds = clampf(maxf(rush_seconds, need + 0.15), rush_seconds, MELEE_APPROACH_SECONDS * 0.75)
		caster.rush_toward(aim["node"], rush_seconds, RUSH_STOP_DISTANCE)
		set_blur(caster, true)  ## DoRunAttack bước 0: bóng mờ suốt lúc lao tới
		while ctx.is_valid() and caster.is_rushing():
			await caster.get_tree().create_timer(TRAIL_CAST_TICKS / VltkMath.FPS, false).timeout
			if ctx.is_valid() and caster.is_rushing():
				aim = _melee_aim(target_id, aim["logic"])
				_melee_hit(ctx, s, level, aim)
	if not ctx.is_valid():
		return
	await _melee_single(ctx, caster, target_id, aim["logic"], level, s)

## DoBlurMove/OnBlurMove: Lướt tới vị trí chỉ định (tối đa param1 pixel logic), để lại bóng mờ (tàn ảnh / kiếm ảnh)
## và thi triển hiệu ứng đạn / tia sét dọc đường lướt.
static func _melee_move_blur(ctx: VltkCastContext, caster: Node2D, target_id: int, fallback_logic: Vector2, level: int, s: Dictionary) -> void:
	if not is_instance_valid(caster):
		return
	var caster_logic := VltkMath.logic_of(caster)
	var aim := _melee_aim(target_id, fallback_logic)
	var des_logic: Vector2 = aim["logic"]

	## Xác định hướng lướt
	var dir_vec := des_logic - caster_logic
	if dir_vec.length_squared() < 4.0:
		if "avatar" in caster and caster.avatar != null:
			var d8: int = caster.avatar.direction
			var d64: int = d8 * 8
			dir_vec = Vector2(float(VltkMath.dir_cos(d64)), float(VltkMath.dir_sin(d64)))
		elif "facing_direction" in caster:
			dir_vec = caster.facing_direction
		else:
			dir_vec = Vector2.DOWN
	dir_vec = dir_vec.normalized()

	## Khoảng cách lướt tối đa theo cấp (skill_param1_v đã được VltkSkillData nạp vào s["param1"])
	var max_len: float = float(s.get("param1", 280))
	if max_len <= 0.0:
		max_len = 280.0
	var want_dist := caster_logic.distance_to(des_logic)
	var dash_dist: float = minf(want_dist, max_len) if want_dist > 20.0 else max_len

	## Điểm đích logic & world
	var target_logic := caster_logic + dir_vec * dash_dist
	var start_world := caster.global_position
	var target_world := VltkMath.to_world(target_logic)

	## Kiểm tra chướng ngại vật địa hình: nếu vướng tường thì dừng trước vật cản
	if caster is CharacterBody2D:
		var cb := caster as CharacterBody2D
		var motion := target_world - start_world
		var test_col := cb.move_and_collide(motion, true)
		if test_col != null:
			var travel_dist := maxf(0.0, test_col.get_travel().length() - 8.0)
			target_world = start_world + motion.normalized() * travel_dist
			target_logic = VltkMath.to_logic(target_world)

	## Hướng 64 cho đạn và xoay mặt nhân vật
	var dir_64: int = VltkMath.dir_between(caster_logic, target_logic)
	if dir_64 < 0:
		if caster.has_method("get_facing_direction"):
			var fwd: Vector2 = caster.get_facing_direction()
			dir_64 = VltkMath.dir_between(Vector2.ZERO, fwd)
		if dir_64 < 0:
			dir_64 = 0

	var dir_8 := wrapi(int(round(float(dir_64) / 8.0)), 0, 8)
	var move_vec := target_world - start_world
	if "avatar" in caster and caster.avatar != null:
		if caster.avatar.has_method("set_direction8"):
			caster.avatar.set_direction8(dir_8)
		elif caster.avatar.has_method("face") and not move_vec.is_zero_approx():
			caster.avatar.face(move_vec.normalized())
	if caster.has_method("set_facing_direction") and not move_vec.is_zero_approx():
		caster.set_facing_direction(move_vec.normalized())

	## 1. Bắt đầu lướt: Bật bóng mờ (tàn ảnh kiếm ảnh suốt quãng đường lướt từ chỗ đứng tới đích)
	set_blur(caster, true)
	var avatar = caster.avatar if ("avatar" in caster and caster.avatar != null) else null
	if avatar != null and avatar.has_method("spawn_blur_ghost"):
		avatar.spawn_blur_ghost(start_world, 0.7, 0.6)

	## Di chuyển lướt nhanh tới đích trong 0.12s
	var dash_duration := 0.12
	var elapsed := 0.0
	var last_ghost_pos := start_world
	var ghost_step := 32.0  ## Mỗi 32 pixel để lại 1 bóng mờ dọc lộ trình
	while elapsed < dash_duration and ctx.is_valid() and is_instance_valid(caster):
		await caster.get_tree().process_frame
		elapsed += caster.get_process_delta_time()
		var t := clampf(elapsed / dash_duration, 0.0, 1.0)
		caster.global_position = start_world.lerp(target_world, t)
		if avatar != null and avatar.has_method("spawn_blur_ghost"):
			var moved := caster.global_position.distance_to(last_ghost_pos)
			while moved >= ghost_step:
				last_ghost_pos += (caster.global_position - last_ghost_pos).normalized() * ghost_step
				avatar.spawn_blur_ghost(last_ghost_pos, 0.65, 0.55)
				moved = caster.global_position.distance_to(last_ghost_pos)

	if is_instance_valid(caster):
		caster.global_position = target_world
		if avatar != null and avatar.has_method("spawn_blur_ghost"):
			avatar.spawn_blur_ghost(target_world, 0.6, 0.5)

	## 2. Sau khi lướt tới nơi: nhân vật vung kiếm tung chiêu (nếu là chiêu tấn công có đòn sát thương / đạn)
	var attack_dir_vec := move_vec.normalized() if not move_vec.is_zero_approx() else Vector2.RIGHT
	if (int(s.get("child", 0)) > 0 or int(s.get("do_hurt", 0)) > 0) and is_instance_valid(caster) and caster.has_method("begin_skill_action"):
		caster.begin_skill_action(int(s.get("physical", 0)) == 1, target_world + attack_dir_vec * 50.0, 0.25)

	## 3. Xuất ra hình ảnh tia sét (Missile 100537: 飒沓流星 với anim fx_88b4dd05 và âm thanh sf_xy_stlx)
	## Tia sét xuất phát tại điểm đích (target_logic) và hướng tia sét trùng với hướng nhân vật đánh tới (dir_64)
	if int(s.get("child", 0)) > 0 and ctx.is_valid():
		VltkMissile.create(ctx, s, target_logic, dir_64, aim["node"], 0, null)

	## 4. Gây sát thương ngoại công/lôi sát lên mục tiêu và kẻ địch phía trước điểm đến
	if ctx.is_valid() and ctx.stats != null:
		if aim["node"] != null and is_instance_valid(aim["node"]):
			ctx.deal_damage(aim["node"], s)
		for target_candidate in ctx.targets():
			if not is_instance_valid(target_candidate) or target_candidate == aim["node"]:
				continue
			if VltkMath.logic_of(target_candidate).distance_to(target_logic) <= 64.0:
				ctx.deal_damage(target_candidate, s)

	## 5. Giữ bóng mờ thêm 0.15s để các bóng tàn ảnh mờ dần tự nhiên theo nhịp gốc
	if is_instance_valid(caster):
		var tree := caster.get_tree()
		if tree != null:
			await tree.create_timer(0.15, false).timeout
		if is_instance_valid(caster):
			set_blur(caster, false)

## Skill HỖ TRỢ (buff, bùa, hào quang, hồi máu — không phải đạn nhắm địch): diễn đủ phần "thi triển" của KNpc::DoSkill gốc —
## ảnh xuất chiêu trên người, động tác thi triển, rồi ở 60% động tác thi triển tiếp đội hình đạn/skill con (MisslesForm
## 6 = tại mục tiêu, 7 = tại người dùng, ... ) CHỈ ĐỂ VẼ: không gây sát thương (ctx.stats = null).
## `target` null = tự nhắm vào mình (buff). Hình trạng thái gắn trên người do VltkStateSprite đảm nhiệm.
static func play_support(caster: Node2D, target: Node2D, skill: SkillDefinition, level: int, stats: ResolvedSkillStats = null) -> void:
	if skill == null or skill.vltk_skill_id <= 0 or not VltkSkillData.has_skill(skill.vltk_skill_id):
		return
	var s := VltkSkillData.skill(skill.vltk_skill_id, level)
	play_precast(caster, s, SUPPORT_ANIM_SPEED)
	var aim: Node2D = target if target != null and not target.has_meta("cast_point") else caster
	var delay := 0.0
	if caster.has_method("begin_skill_action"):
		delay = caster.begin_skill_action(false, aim.global_position) * ATTACK_EFFECT_PERCENT
	if int(s.get("style", 0)) != VltkSkillCaster.STYLE_MISSILES and int(s.get("child", 0)) <= 0:
		return
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	ctx.stats = stats
	ctx.attacker_stats = caster.combat_stats if "combat_stats" in caster else null
	var aim_id: int = aim.get_instance_id()  ## không bắt node trong lambda (có thể bị giải phóng lúc chờ)
	var fire := func() -> void:
		if not ctx.is_valid():
			return
		var live_aim: Node2D = instance_from_id(aim_id) as Node2D
		var des := VltkMath.logic_of(live_aim) if live_aim != null and live_aim.is_inside_tree() else ctx.launcher_logic()
		VltkSkillCaster.cast(ctx, skill.vltk_skill_id, level, des, null)
	if delay <= 0.0:
		fire.call()
	else:
		caster.get_tree().create_timer(delay, false).timeout.connect(fire)

## Online: VẼ LẠI chiêu người chơi khác vừa ra (S_CAST) — ảnh xuất chiêu, tiếng, đội hình đạn; ctx.stats = null nên không
## gây sát thương (máy người ra chiêu tính đòn thật). Skill cận chiến chỉ diễn 1 đòn skill con vào mục tiêu (không lao tới).
static func replay(caster: Node2D, vltk_skill_id: int, level: int, aim_node: Node2D, aim_logic: Vector2) -> void:
	if vltk_skill_id <= 0 or not VltkSkillData.has_skill(vltk_skill_id):
		return
	var s := VltkSkillData.skill(vltk_skill_id, level)
	play_precast(caster, s)
	play_cast_sound(caster, vltk_skill_id)
	_replay_blur(caster, s)
	var fire_id := vltk_skill_id
	if is_melee_supported(s):
		fire_id = int(s.get("child", 0))
	elif int(s.get("style", 0)) != VltkSkillCaster.STYLE_MISSILES and int(s.get("child", 0)) <= 0:
		return
	if fire_id <= 0:
		return
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.world = caster.get_parent()
	ctx.stats = null
	var des := VltkMath.logic_of(aim_node) if aim_node != null else aim_logic
	VltkSkillCaster.cast(ctx, fire_id, level, des, aim_node)

## Online: bóng mờ cho chiêu người khác (chỉ vẽ) — cận chiến: suốt chuỗi đòn; skill NeedShadow: tới 60% động tác.
static func _replay_blur(caster: Node2D, s: Dictionary) -> void:
	var seconds := 0.0
	if is_melee_supported(s):
		var ticks := 0
		for step in maxi(1, int(s.get("child_num", 1))):
			ticks += maxi(2, VltkSkillCaster.generate_time(s, step))
		seconds = float(ticks) / VltkMath.FPS
	elif needs_shadow(s):
		seconds = SectSkillController.action_seconds(int(s.get("physical", 0)) == 1, null) * ATTACK_EFFECT_PERCENT
	if seconds <= 0.0 or not ("avatar" in caster and caster.avatar != null):
		return
	set_blur(caster, true)
	var caster_id := caster.get_instance_id()
	caster.get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		set_blur(instance_from_id(caster_id), false))

## Tiếng ra chiêu gốc (KSkill::PlayPreCastSound: ManCastSnd / FMCastSnd theo giới tính người thi triển).
## Theo chuẩn VLTK gốc (KNpc::PlayPreCastSound: if (IsPlayer())): chỉ người chơi (Player/RemotePlayer/PKBot có avatar)
## mới phát tiếng hô hào nam/nữ. Quái vật / NPC dùng tiếng động tác quái riêng trong npc动作声音表 (VltkSound.npc), không
## la hét giọng người chơi. Skill không có tiếng gốc thì thôi (âm theo hệ của SfxManager.play_skill_cast vẫn chạy riêng).
static func play_cast_sound(caster: Node2D, vltk_skill_id: int) -> void:
	if caster == null or not ("avatar" in caster and caster.avatar != null):
		return
	var female: bool = caster.avatar.is_voice_female()
	var stream := VltkSound.skill_cast(vltk_skill_id, female)
	if stream != null:
		SfxManager.play(stream, caster.global_position)

## Ảnh PreCastSpr: chạy hết số frame 1 hướng trong (frame/hướng × nhịp_ms / 50) nhịp, bám theo người thi triển.
static func play_precast(caster: Node2D, s: Dictionary, speed: float = 1.0) -> void:
	var key := str(s.get("precast", ""))
	if key == "":
		return
	var anim := VltkSkillData.anim(key)
	if anim.is_empty():
		return
	var phase := {"anim": key, "frames": int(anim["frames"]), "dirs": int(anim["dirs"]),
			"interval": maxi(1, int(anim["interval"]) / 50)}
	var facing := 0
	if "avatar" in caster and caster.avatar:
		facing = int(caster.avatar.direction) * VltkMath.MAX_DIR / 8
	VltkEffect.spawn(caster.get_parent(), phase, VltkMath.logic_of(caster), 0.0, facing, caster, speed)

@warning_ignore_restore("integer_division")

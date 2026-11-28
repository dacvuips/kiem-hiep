class_name BotCombatBrain
extends RefCounted
## BỘ NÃO CHIẾN ĐẤU "như người thật" (docs/plans/bot-lon-xon-pubg.md mục 2b) — dùng chung Lộn Xộn / PUBG.
## Kịch bản màn (bước 3, 4) đặt `target_eid` (đánh ai) / `goal` (đi đâu); não này lo ĐÁNH THẾ NÀO:
##   bộ chiêu tự phân loại theo phái · combo buff -> bùa -> khống chế -> dồn đòn (đòn vùng khi đông) · cận chiến vòng quanh / đánh xa
##   thả diều · né theo đường đạn (tin ra chiêu thật, có trễ phản xạ, tỉ lệ theo độ khó) · nhảy áp sát / thoát thân / né đòn vùng ·
##   bơm máu (không uống chồng, giữ 2 bình cuối) · ngồi thiền lúc rảnh · so lợi thế để đánh / rút · phân tâm, ngắm lệch, sai sót.
## Mỗi bot 1 instance (trạng thái riêng), nghĩ 5 lần / giây (BotManager.THINK_EVERY) -> tối đa 5 thao tác / giây như người.

enum Diff { EASY, NORMAL, HARD }

## Thông số theo độ khó: phản xạ (giây), tỉ lệ né, sai sót, nhảy chiến thuật, theo combo (bùa / khống chế), thả diều,
## phân tâm (xác suất mỗi lượt nghĩ), ngắm lệch (px), nhịp tay (chần chừ tối đa sau mỗi đòn, giây — người chơi kém bấm chậm hơn).
const DIFF := [
	{"react": Vector2(0.35, 0.6), "dodge": 0.2, "mistake": 0.12, "jump": 0.1, "combo": 0.35, "kite": false, "distract": 0.02, "aim": 40.0, "tempo": 0.45},
	{"react": Vector2(0.25, 0.45), "dodge": 0.5, "mistake": 0.06, "jump": 0.45, "combo": 0.75, "kite": true, "distract": 0.01, "aim": 20.0, "tempo": 0.2},
	{"react": Vector2(0.15, 0.3), "dodge": 0.8, "mistake": 0.02, "jump": 0.85, "combo": 1.0, "kite": true, "distract": 0.003, "aim": 8.0, "tempo": 0.05},
]
const FIGHT_POTION_HP := 0.55       ## đang đánh nhau: máu dưới mức này thì uống
const IDLE_POTION_HP := 0.45        ## rảnh: dưới mức này mới uống (còn lại ngồi thiền)
const KEEP_POTIONS := 2             ## giữ 2 bình cuối cho lúc nguy kịch
const CRITICAL_HP := 0.3
const FLEE_HP := 0.25
const BUFF_REFRESH_SEC := 3.0
const DEBUFF_REFRESH_SEC := 2.0
const SIT_BELOW_HP := 0.9
const SAFE_RADIUS := 600.0          ## không có địch trong chừng này px = rảnh
const JUMP_GAP := Vector2(200, 470) ## khoảng cách nhảy áp sát
const AOE_CROWD := 3

var target_eid := 0                 ## đánh ai (kịch bản màn đặt; 0 = rảnh)
var aggressive := false             ## tính cách hiếu chiến: ít rút hơn
var _kit := {}                      ## {main, attacks:[{sk, avg, aoe, control}], buffs, debuffs, aura}
var _kit_level := -1
var _queue: Array = []              ## [{at, kind, data}] việc làm sau trễ phản xạ
var _distract_until := 0.0
var _orbit := 1.0                   ## chiều vòng quanh mục tiêu
var _orbit_flip_at := 0.0
var _applied := {}                  ## target_eid -> {skill_id: hết lúc} bùa mình đã thả
var _last_dist := -1.0
var _dodge_ready := 0.0              ## hồi né: chưa tới lúc này thì không né nữa
const DODGE_COOLDOWN := [2.5, 1.5, 1.0]
var _away_streak := 0               ## số lượt nghĩ liền mục tiêu xa dần (>= 3 = đang chạy trốn thật)
var _fleeing_target := false
var _next_idle := 0.0
var _next_attack_at := 0.0          ## nhịp tay: chưa tới lúc này thì chưa bấm đòn kế

func _init(target := 0) -> void:
	target_eid = target

func _p(b: ServerBot) -> Dictionary:
	return DIFF[clampi(b.difficulty, 0, 2)]

func _react(b: ServerBot) -> float:
	var r: Vector2 = _p(b).react
	return randf_range(r.x, r.y)

# ================================================================== bộ chiêu

## Phân loại chiêu của phái (làm lại khi lên cấp — mở thêm chiêu).
func _ensure_kit(b: ServerBot) -> void:
	if _kit_level == b.profile.level and not _kit.is_empty():
		return
	_kit_level = b.profile.level
	var attacks: Array = []
	var buffs: Array = []
	var debuffs: Array = []
	var aura: SkillDefinition = null
	for sk: SkillDefinition in b.skills:
		if sk.is_aura:
			if aura == null:
				aura = sk
			continue
		if sk.is_state_skill():
			if sk.target_enemy:
				debuffs.append(sk)
			else:
				buffs.append(sk)
			continue
		if not sk.target_enemy:
			continue
		var h := BotCombat.roll_skill_hit(b, sk)
		var mods: CombatFormulas.HitModifiers = h.mods
		var extra := 0.0
		for v in mods.extra_damages.values():
			extra += (float((v as Vector2i).x) + float((v as Vector2i).y)) * 0.5
		var avg := (float(h.min) + float(h.max)) * 0.5 + extra
		if avg <= 0.0 and mods.stun_chance_p <= 0 and mods.freeze_frames <= 0:
			continue
		var form := sk.vltk_missle_form
		attacks.append({"sk": sk, "avg": avg, "aoe": form in [2, 3, 5] or sk.get_effect_radius_px() >= 80.0,
			"control": mods.stun_chance_p > 0 or mods.freeze_frames > 0, "basic": sk.is_basic_attack})
	attacks.sort_custom(func(x, y): return float(x.avg) > float(y.avg))
	_kit = {"main": b.main_skill, "attacks": attacks, "buffs": buffs, "debuffs": debuffs, "aura": aura}

func kit() -> Dictionary:
	return _kit

## Chiêu tấn công tốt nhất đang dùng được và với tới mục tiêu ở `dist`.
func _best_ready_attack(b: ServerBot, dist: float, now: float, want_aoe := false, want_control := false) -> SkillDefinition:
	for a in _kit.attacks:
		if want_aoe and not bool(a.aoe):
			continue
		if want_control and not bool(a.control):
			continue
		var sk: SkillDefinition = a.sk
		if b.skill_ready(sk, now) and dist <= b.skill_range(sk) * 1.05:
			return sk
	return null

func _avg_of(sk: SkillDefinition) -> float:
	for a in _kit.attacks:
		if a.sk == sk:
			return float(a.avg)
	return 0.0

## Tầm "ưa thích": tầm của chiêu mạnh nhất (không tính đánh thường).
func _ideal_range(b: ServerBot) -> float:
	for a in _kit.attacks:
		if not bool(a.basic):
			return b.skill_range(a.sk)
	return b.skill_range(b.main_skill)

func is_melee(b: ServerBot) -> bool:
	return _ideal_range(b) <= 130.0

# ================================================================== nhịp nghĩ

func think(b: ServerBot, mgr: BotManager, _dt: float) -> void:
	var now: float = mgr.gs.now()
	if b.dead:
		_queue.clear()
		_applied.clear()
		return
	_run_queue(b, mgr, now)
	if b.is_stunned(now) or now < _distract_until:
		return
	var P := _p(b)
	if randf() < float(P.distract):
		_distract_until = now + randf_range(0.5, 1.5)   ## người thật đôi khi phân tâm
		return
	_ensure_kit(b)
	var aura: SkillDefinition = _kit.aura
	if aura != null and b.profile.active_aura_id != aura.id and b.skill_ready(aura, now):
		mgr.cast_self(b, aura)
		return
	var t: ServerEntity = mgr.gs.entity_of(target_eid) if target_eid != 0 else null
	if t != null and (t.room_id != b.room_id or (t.flags & (NetProto.FLAG_DEAD | NetProto.FLAG_HIDE)) != 0):   ## ẩn thân: mất dấu
		t = null
	var dist := b.pos.distance_to(t.pos) if t != null else INF
	var in_fight := t != null and dist < SAFE_RADIUS
	if _want_potion(b, in_fight, now) and not _queued("drink"):
		_push(now + _react(b), "drink", null)
	if t == null:
		_last_dist = -1.0
		_idle(b, mgr, now)
		return
	b.sitting = false
	_away_streak = _away_streak + 1 if _last_dist >= 0.0 and dist > _last_dist + 10.0 else 0
	_fleeing_target = _away_streak >= 3   ## xa dần 3 lượt liền (~0,6 giây) mới là chạy trốn, không phải bước vòng / né
	_last_dist = dist
	if _should_flee(b, t, mgr):
		_flee(b, mgr, t, now)
		return
	## buff đủ trước khi lao vào
	if dist < SAFE_RADIUS * 1.5:
		for bf: SkillDefinition in _kit.buffs:
			if b.state_left(bf.id, now) < BUFF_REFRESH_SEC and b.skill_ready(bf, now):
				mgr.cast_self(b, bf)
				return
	var ideal := _ideal_range(b)
	## nhảy áp sát: đuổi kẻ đang chạy mà đáng đuổi (máu dưới 60% — sắp hạ được), hoặc thỉnh thoảng lao vào từ xa.
	## Bay 2,2 giây không đánh được: người giỏi không nhảy đuổi người còn khoẻ đang chạy theo người khác.
	var chase_worth := _fleeing_target and t.hp <= 60
	if dist > ideal * 1.2 and dist >= JUMP_GAP.x and dist <= JUMP_GAP.y and (chase_worth or dist > 350.0) \
			and randf() < float(P.jump) * (1.0 if chase_worth else 0.35):
		var lead := t.pos + (t.pos - b.pos).normalized() * 40.0 if _fleeing_target else t.pos
		if b.jump_toward(lead, now):
			return
	## bùa lên mục tiêu trước khi dồn sát thương
	for db: SkillDefinition in _kit.debuffs:
		if dist <= b.skill_range(db) and b.skill_ready(db, now) and _applied_left(t.eid, db.id, now) < DEBUFF_REFRESH_SEC \
				and randf() < float(P.combo):
			if mgr.cast(b, db, t):
				var secs := float(db.get_state_payload(b.skill_level(db)).seconds)
				if not _applied.has(t.eid):
					_applied[t.eid] = {}
				_applied[t.eid][db.id] = now + secs
				return
	## khống chế kẻ đang chạy / sắp chết
	var t_low := t.hp <= 40
	if (_fleeing_target or t_low) and randf() < float(P.combo):
		var ctl := _best_ready_attack(b, dist, now, false, true)
		var best := _best_ready_attack(b, dist, now)
		## khống chế chỉ khi không yếu hơn hẳn đòn mạnh nhất đang có (không đổi sát thương lấy khống chế vô ích)
		if ctl != null and (best == null or _avg_of(ctl) >= _avg_of(best) * 0.6) and _cast_at(b, mgr, ctl, t):
			return
	## đòn vùng khi đông
	if _crowd_near(b, mgr, t, 120.0) >= AOE_CROWD:
		var aoe := _best_ready_attack(b, dist, now, true)
		if aoe != null and _cast_at(b, mgr, aoe, t):
			return
	## dồn đòn
	var atk := _best_ready_attack(b, dist, now)
	if atk != null:
		if randf() < float(P.mistake):
			_distract_until = now + randf_range(0.3, 0.8)   ## sai sót: khựng lại / chậm 1 nhịp như người
			return
		if _cast_at(b, mgr, atk, t):
			return
	_move_in_fight(b, t, dist, ideal, now)

func _cast_at(b: ServerBot, mgr: BotManager, sk: SkillDefinition, t: ServerEntity) -> bool:
	var now: float = mgr.gs.now()
	if now < _next_attack_at:
		return false
	var aim_px: float = _p(b).aim
	mgr.aim_error = Vector2(randf_range(-aim_px, aim_px), randf_range(-aim_px, aim_px) * 0.5)
	var ok := mgr.cast(b, sk, t)
	mgr.aim_error = Vector2.ZERO
	if ok:
		_next_attack_at = now + randf() * float(_p(b).tempo)
	return ok

# ================================================================== di chuyển trong giao tranh

func _move_in_fight(b: ServerBot, t: ServerEntity, dist: float, ideal: float, now: float) -> void:
	var to_me := (b.pos - t.pos).normalized() if dist > 1.0 else Vector2.RIGHT
	if now >= _orbit_flip_at:
		_orbit_flip_at = now + randf_range(1.5, 4.0)
		if randf() < 0.4:
			_orbit = -_orbit
	if dist > ideal * 0.95:
		## áp sát theo đường hơi cong (không thẳng tắp như máy)
		var side := to_me.orthogonal() * _orbit * minf(dist * 0.25, 80.0)
		b.go_to(t.pos + to_me * ideal * 0.7 + side)
		return
	## Đang đi dở 1 bước còn xa: đi tiếp cho liền mạch (đổi đích mỗi lượt nghĩ = chạy-dừng-chạy, người xem thấy giật).
	if b.move_dest != Vector2.INF and b.pos.distance_to(b.move_dest) > b.speed * BotManager.THINK_EVERY * 0.5:
		return
	## Mỗi bước di chuyển dài ít nhất ~ quãng đi được trong 1,5 lượt nghĩ -> bot còn đang chạy khi tới lượt nghĩ sau.
	var min_step := b.speed * BotManager.THINK_EVERY * 1.5
	if is_melee(b):
		## cận chiến: vòng quanh mục tiêu, không đứng thẳng hàng
		var r := maxf(55.0, ideal * 0.7)
		var ang := to_me.angle() + _orbit * clampf(min_step / r + randf_range(0.0, 0.4), 0.6, 1.5)
		b.go_to(t.pos + Vector2.from_angle(ang) * r)
	elif bool(_p(b).kite) and dist < ideal * 0.55:
		## đánh xa bị áp sát: lùi chéo ra để thả diều
		b.go_to(b.pos + (to_me + to_me.orthogonal() * _orbit * 0.6).normalized() * 140.0)
	else:
		## đứng đánh nhưng không đứng yên: bước ngang (đủ dài để không chạy-dừng)
		b.go_to(b.pos + to_me.orthogonal() * _orbit * randf_range(min_step, min_step * 1.8))

# ================================================================== đánh / rút

## Lợi thế mình / địch: máu còn x sức (cấp làm thước đo khi không biết chỉ số thật của người chơi).
func advantage(b: ServerBot, t: ServerEntity) -> float:
	var mine := b.hp_ratio() * float(b.level + 10)
	var theirs := (float(t.hp) / 100.0) * float(t.level + 10)
	return mine / maxf(0.05, theirs)

func _should_flee(b: ServerBot, t: ServerEntity, _mgr: BotManager) -> bool:
	if t is ServerMonster:
		return b.hp_ratio() < FLEE_HP and b.potion_count() == 0
	if b.hp_ratio() < FLEE_HP and b.potion_count() == 0:
		return true
	var limit := 0.25 if aggressive else 0.4
	return b.hp_ratio() < 0.5 and advantage(b, t) < limit

func _flee(b: ServerBot, mgr: BotManager, t: ServerEntity, now: float) -> void:
	var away := (b.pos - t.pos).normalized() if b.pos != t.pos else Vector2.RIGHT
	var grid: MapGrid = mgr.gs.grid_of(b)
	var dist := b.pos.distance_to(t.pos)
	## bị áp sát: nhảy cắt đuôi, ưu tiên hướng có vật cản nhảy qua được
	if dist < 260.0 and randf() < float(_p(b).jump):
		var best := away
		if grid != null:
			for k in [0.0, 0.6, -0.6, 1.1, -1.1]:
				var d := away.rotated(k)
				var mid := b.pos + d * 90.0
				var land := b.pos + d * ServerBot.JUMP_SPEED * ServerBot.JUMP_SEC * 0.8
				if (grid.is_blocked(mid) and grid.is_jumpable(mid)) and not grid.is_blocked(land):
					best = d
					break
		if b.jump_toward(b.pos + best * 300.0, now):
			return
	var dest := b.pos + away.rotated(randf_range(-0.4, 0.4)) * 260.0
	if grid != null and grid.is_blocked(dest):
		var free := grid.free_near(dest)
		if free != Vector2.ZERO:
			dest = free
	b.go_to(dest)

# ================================================================== thuốc / rảnh

func _want_potion(b: ServerBot, in_fight: bool, now: float) -> bool:
	if now < b.potion_until:
		return false   ## thuốc trước còn chạy: không uống chồng
	var hp := b.hp_ratio()
	var n := b.potion_count()
	if n <= 0:
		return false
	if n <= KEEP_POTIONS and hp >= CRITICAL_HP:
		return false   ## giữ bình cuối cho lúc nguy
	return hp < (FIGHT_POTION_HP if in_fight else IDLE_POTION_HP)

## Rảnh: ngồi thiền hồi máu khi không có địch gần, không thì đứng nhìn quanh / đi lòng vòng.
func _idle(b: ServerBot, mgr: BotManager, now: float) -> void:
	var danger := false
	for e in mgr.nearby(b, SAFE_RADIUS):
		if e != b and not (e is ServerMonster) and not _is_ally(b, e):
			danger = true
			break
	if not danger and b.hp_ratio() < SIT_BELOW_HP and b.move_dest == Vector2.INF:
		if not b.sitting:
			b.stop()
			b.sitting = true
			b.touch()
		return
	b.sitting = false
	if now < _next_idle:
		return
	_next_idle = now + randf_range(2.0, 6.0)
	if randf() < 0.5:
		b.face(Vector2.from_angle(randf() * TAU))   ## nhìn quanh
	else:
		b.go_to(b.pos + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 120.0))

func _is_ally(b: ServerBot, e: ServerEntity) -> bool:
	return b.policy != null and b.policy.has_method("is_ally") and b.policy.is_ally(b, e)

func _crowd_near(b: ServerBot, mgr: BotManager, t: ServerEntity, radius: float) -> int:
	var n := 0
	for e in mgr.nearby(b, b.pos.distance_to(t.pos) + radius):
		if e != b and not _is_ally(b, e) and (e as ServerEntity).pos.distance_to(t.pos) <= radius:
			n += 1
	return n

func _applied_left(teid: int, skill_id: String, now: float) -> float:
	var d: Dictionary = _applied.get(teid, {})
	return maxf(0.0, float(d.get(skill_id, 0.0)) - now)

# ================================================================== né đòn

## Có người ra chiêu gần mình (BotManager báo, từ tin ra chiêu thật). Né sau trễ phản xạ, tỉ lệ theo độ khó — không né 100%.
func on_threat(b: ServerBot, mgr: BotManager, caster: ServerEntity, skill_id: int, t_eid: int, aim: Vector2) -> void:
	if b.dead or _is_ally(b, caster):
		return
	var aimed_at_me := t_eid == b.eid or aim.distance_to(b.pos) < 160.0
	if not aimed_at_me or randf() > float(_p(b).dodge):
		return
	## Đòn cận chiến (kẻ đánh đứng sát): đòn tới sau ~0,25 giây, né thường không kịp mà còn tự ra khỏi tầm đánh của mình — người thật
	## đứng đổi đòn, chỉ né / lùi khi máu dưới 35% (đang tìm đường thoát).
	if b.pos.distance_to(caster.pos) < 140.0 and b.hp_ratio() >= 0.35:
		return
	## Người thật không né liên tục được: có hồi né theo độ khó, và không bỏ dở động tác ra chiêu đang đánh để né.
	var now_d: float = mgr.gs.now()
	if now_d < _dodge_ready or now_d < b.action_until:
		return
	_dodge_ready = now_d + float(DODGE_COOLDOWN[clampi(b.difficulty, 0, 2)])
	## Đang trong tầm đánh mục tiêu của mình, chiêu sẵn sàng, máu còn khá: đứng đổi đòn (né lúc này là tự bỏ nhịp đánh).
	var mine: ServerEntity = mgr.gs.entity_of(target_eid) if target_eid != 0 else null
	if mine != null and not _kit.is_empty() and b.hp_ratio() >= 0.5 and _best_ready_attack(b, b.pos.distance_to(mine.pos), mgr.gs.now()) != null:
		return
	var sk := _skill_of(mgr, caster, skill_id)
	var form := sk.vltk_missle_form if sk != null else 1
	var radius := maxf(BotManager.MIN_HIT_RADIUS, sk.get_effect_radius_px()) if sk != null else BotManager.MIN_HIT_RADIUS
	var from_caster := (b.pos - caster.pos).normalized() if b.pos != caster.pos else Vector2.RIGHT
	var side := from_caster.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	var now: float = mgr.gs.now()
	var at := now + _react(b)
	match form:
		5, 6:
			## đòn nổ tại chỗ: chạy ra khỏi vùng nổ, đòn lớn thì nhảy
			var out := (b.pos - aim).normalized() if b.pos != aim else side
			if radius >= 100.0 and randf() < float(_p(b).jump):
				_push(at, "jump", b.pos + out * 260.0)
			else:
				_push(at, "dodge", aim + out * (radius + 50.0))
		1:
			## đạn thẳng: bước vuông góc hướng bay, đủ ra khỏi bề rộng đạn
			_push(at, "dodge", b.pos + side * (radius + 45.0))
		_:
			if b.pos.distance_to(caster.pos) < 140.0:
				_push(at, "dodge", b.pos + (from_caster + side).normalized() * 90.0)   ## cận chiến: lùi chéo
			else:
				_push(at, "dodge", b.pos + side * 80.0)

func _skill_of(mgr: BotManager, caster: ServerEntity, skill_id: int) -> SkillDefinition:
	var prof: PlayerProfile = null
	var cb: ServerBot = mgr.get_bot(caster.eid)
	if cb != null:
		prof = cb.profile
	elif mgr.gs.has_method("conn_of_eid"):
		var c = mgr.gs.conn_of_eid(caster.eid)
		if c != null and "profile" in c:
			prof = c.profile
	return ProfileGuard.skill_by_vltk_id(prof, skill_id) if prof != null else null

# ================================================================== hàng việc trễ phản xạ

func _push(at: float, kind: String, data: Variant) -> void:
	_queue.append({"at": at, "kind": kind, "data": data})

func _queued(kind: String) -> bool:
	return _queue.any(func(q): return str(q.kind) == kind)

func _run_queue(b: ServerBot, _mgr: BotManager, now: float) -> void:
	if _queue.is_empty():
		return
	var keep: Array = []
	for q in _queue:
		if float(q.at) > now:
			keep.append(q)
			continue
		match str(q.kind):
			"drink":
				b.drink_potion(now)
			"dodge":
				b.tally.dodges += 1
				b.sitting = false
				b.action_until = minf(b.action_until, now)   ## né thì bỏ nốt động tác đang dở
				b.go_to(q.data)
			"jump":
				b.jump_toward(q.data, now)
	_queue = keep

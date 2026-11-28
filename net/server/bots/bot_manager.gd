class_name BotManager
extends RefCounted
## Giữ mọi bot người chơi trên game server (ServerBot) — sinh / bỏ, chạy nhịp (não + thân), giao đòn:
##   bot ra chiêu -> hình ảnh S_CAST cho người đang thấy + đòn tới mục tiêu sau thời gian bay (mục tiêu chạy khỏi tầm / nhảy thì trượt),
##   người thật đánh bot (C_PVP_HIT qua RelationServer) -> on_player_hit, quái đánh bot -> on_monster_attack.
## Luật màn (ai đánh được bot, bot chết thì sao) nằm ở bot.policy (LonXonServer / PubgServer — bước 3, 4).

const THINK_EVERY := 0.2          ## não nghĩ 5 lần / giây
const HIT_DELAY_MELEE := 0.25     ## đòn cận chiến trúng sau chừng này giây
const MISSILE_SPEED := 600.0      ## đạn bay (px/giây) — đòn tầm xa trúng sau khoảng cách / tốc độ
const HIT_RANGE_SLACK := 1.35     ## lúc trúng, mục tiêu còn trong tầm x hệ số này mới tính (chạy khỏi tầm = né được)
const MONSTER_HIT_DELAY := 0.4
const MAX_HITS_PER_SEC_ON_BOT := 20
const MIN_HIT_RADIUS := 45.0     ## nửa bề rộng đạn / bán kính nổ tối thiểu (px)
const THREAT_RADIUS := 700.0     ## bot "thấy" người ra chiêu trong chừng này px

var gs   ## GameServer (hoặc bản giả trong test): now(), entity_of(eid), conn_of_eid(eid), grid_of(e), aoi, add_bot_entity(bot),
         ## remove_bot_entity(bot), broadcast_cast(...), send_pvp_hit(c, eid, raw), bot_damage_monster(bot, m, amount)
var bots := {}            ## eid -> ServerBot
var _pending: Array = []  ## [{at, bot, target_eid, hit, range}] đòn đang bay
var _think_in := {}       ## eid -> giây còn lại tới lượt nghĩ sau
var _hits_window := {}    ## eid bot -> [giây bắt đầu, số đòn] chống dồn gói
var next_eid := 0         ## 0 = xin eid từ gs.alloc_eid()

func _init(server) -> void:
	gs = server

func _alloc_eid() -> int:
	if gs.has_method("alloc_eid"):
		return gs.alloc_eid()
	next_eid += 1
	return 7_000_000 + next_eid

## Sinh bot từ hồ sơ tại `feet` trong phòng `room_id` (vùng ô `base`).
func spawn(profile: PlayerProfile, feet: Vector2, room_id := 0, base := Vector2i.ZERO, brain: Object = null, policy: Object = null) -> ServerBot:
	var b := ServerBot.create(_alloc_eid(), profile)
	b.pos = feet
	b.room_id = room_id
	b.cell_base = base
	b.brain = brain
	b.policy = policy
	b.has_moved = true
	bots[b.eid] = b
	_think_in[b.eid] = randf() * THINK_EVERY
	gs.add_bot_entity(b)
	return b

func remove(b: ServerBot) -> void:
	if not bots.has(b.eid):
		return
	bots.erase(b.eid)
	_think_in.erase(b.eid)
	_hits_window.erase(b.eid)
	_pending = _pending.filter(func(p): return p.bot != b and int(p.target_eid) != b.eid)
	_monster_hits = _monster_hits.filter(func(h): return h.bot != b)
	gs.remove_bot_entity(b)
	b.free_resources()

func get_bot(eid: int) -> ServerBot:
	return bots.get(eid)

func is_bot(eid: int) -> bool:
	return bots.has(eid)

func tick(dt: float) -> void:
	var now: float = gs.now()
	for eid in bots.keys():
		var b: ServerBot = bots.get(eid)
		if b == null:
			continue
		_think_in[eid] = float(_think_in.get(eid, 0.0)) - dt
		if float(_think_in[eid]) <= 0.0:
			_think_in[eid] = THINK_EVERY
			if b.brain != null and b.brain.has_method("think"):
				b.brain.think(b, self, THINK_EVERY)
		if b.tick_body(gs.grid_of(b), now, dt):
			gs.aoi.update(b)
		if b.policy != null and b.policy.has_method("tick_bot"):
			b.policy.tick_bot(b, self, now)
	_deliver(now)
	tick_monster_hits(now)

# ------------------------------------------------------------------ bot ra chiêu

## Bot ra chiêu `sk` vào thực thể `target` (người thật / bot / quái). false = chưa ra được (hồi chiêu, khoá động tác, ngoài tầm…).
func cast(b: ServerBot, sk: SkillDefinition, target: ServerEntity) -> bool:
	var now: float = gs.now()
	if target == null or not b.skill_ready(sk, now) or b.is_jumping(now):
		return false
	var rng := b.skill_range(sk)
	var dist := b.pos.distance_to(target.pos)
	if dist > rng * 1.1:
		return false
	var aim := target.pos + aim_error
	aim_error = Vector2.ZERO
	b.begin_cast(sk, aim, now)
	gs.broadcast_cast(b, sk.vltk_skill_id, b.skill_level(sk), 0, target.eid, aim)
	var hit := BotCombat.roll_skill_hit(b, sk)
	var melee := bool(hit.physical) and rng <= 120.0
	var delay := HIT_DELAY_MELEE if melee else maxf(HIT_DELAY_MELEE, dist / MISSILE_SPEED)
	_pending.append({"at": now + delay, "bot": b, "target_eid": target.eid, "hit": hit, "range": rng, "origin": b.pos, "aim": aim,
		"form": -1 if melee else sk.vltk_missle_form, "radius": maxf(MIN_HIT_RADIUS, sk.get_effect_radius_px())})
	_notify_cast(b, sk, target.eid, aim)
	return true

## Sai số ngắm của lần ra chiêu kế tiếp (não bot đặt trước khi gọi cast — người thật ngắm không chuẩn tuyệt đối).
var aim_error := Vector2.ZERO

## Bot tự thi triển chiêu hỗ trợ lên mình: buff (trạng thái có thời gian) hoặc bật hào quang.
func cast_self(b: ServerBot, sk: SkillDefinition) -> bool:
	var now: float = gs.now()
	if sk == null or not b.skill_ready(sk, now) or b.is_jumping(now):
		return false
	b.begin_cast(sk, b.pos + Vector2(0, 1), now)
	gs.broadcast_cast(b, sk.vltk_skill_id, b.skill_level(sk), NetProto.CAST_SUPPORT, b.eid, b.pos)
	if sk.is_aura:
		b.set_aura(sk.id)
	else:
		b.tally.buffs += 1
		var payload := sk.get_state_payload(b.skill_level(sk))
		b.add_state(sk.id, payload.attribs, float(payload.seconds), now)
	return true

func _deliver(now: float) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	for p in _pending:
		if float(p.at) > now:
			keep.append(p)
			continue
		var b: ServerBot = p.bot
		if b.dead or not bots.has(b.eid):
			continue
		var t: ServerEntity = gs.entity_of(int(p.target_eid))
		if t == null or t.room_id != b.room_id or b.pos.distance_to(t.pos) > float(p.range) * HIT_RANGE_SLACK:
			continue   ## mục tiêu đã chạy khỏi tầm / rời phòng: trượt (né được)
		if not still_in_path(p, t.pos):
			continue   ## bước ngang khỏi đường đạn / ra khỏi vùng nổ: né được
		_apply_hit(b, t, p.hit, now)
	_pending = keep

func _apply_hit(b: ServerBot, t: ServerEntity, hit: Dictionary, now: float) -> void:
	if t is ServerBot:
		var tb := t as ServerBot
		if tb.dead or not _allowed(b, tb):
			return
		var dmg := BotCombat.bot_vs_bot(b, tb, hit)
		if dmg > 0:
			b.tally.hits += 1
			b.tally.dmg += dmg
		if dmg > 0 and tb.lose_hp(float(dmg), now, b.eid, b.name):
			_on_bot_died(tb)
	elif t is ServerMonster:
		var m := t as ServerMonster
		if m.is_dead():
			return
		var dmg := BotCombat.damage_vs_monster(b, m, hit)
		if dmg > 0:
			b.tally.hits += 1
			b.tally.dmg += dmg
		if dmg > 0:
			gs.bot_damage_monster(b, m, float(dmg))
	else:
		var c = gs.conn_of_eid(t.eid)
		if c == null or (t.flags & NetProto.FLAG_DEAD) != 0:
			return
		b.tally.hits += 1
		gs.send_pvp_hit(c, b.eid, BotCombat.encode_for_player(b, hit))

# ------------------------------------------------------------------ bot bị đánh

func _allowed(attacker: ServerEntity, b: ServerBot) -> bool:
	if attacker == null or attacker == b or attacker.room_id != b.room_id or b.dead:
		return false
	if b.policy != null and b.policy.has_method("allows_hit_bot"):
		return b.policy.allows_hit_bot(attacker, b)
	return true

## Người thật đánh bot (C_PVP_HIT, eid là bot). Gói đã qua giới hạn số gói / giây của RelationServer.
func on_player_hit(c, eid: int, bytes: PackedByteArray) -> void:
	var b: ServerBot = bots.get(eid)
	if b == null or c == null or c.entity == null or (c.entity.flags & NetProto.FLAG_DEAD) != 0:
		return
	if not _allowed(c.entity, b) or not GameServer.near(b, c.entity, GameServer.MAX_HIT_DISTANCE):
		return
	var now: float = gs.now()
	var w: Array = _hits_window.get(eid, [now, 0])
	if now - float(w[0]) > 1.0:
		w = [now, 0]
	w[1] = int(w[1]) + 1
	_hits_window[eid] = w
	if int(w[1]) > MAX_HITS_PER_SEC_ON_BOT:
		return
	var d := PvpHit.decode(bytes)
	if d.is_empty():
		return
	PvpHit.sanitize(d, c.max_hit)
	var dmg := BotCombat.resolve_pvp_packet_on_bot(b, d, c.entity.eid)
	if dmg > 0 and b.lose_hp(float(dmg), now, c.entity.eid, c.entity.name):
		_on_bot_died(b)

## Quái ra chiêu vào bot: đòn tới sau MONSTER_HIT_DELAY (bot nhảy / chạy xa thì trượt).
func on_monster_attack(m: ServerMonster, b: ServerBot) -> void:
	_monster_hits.append({"at": gs.now() + MONSTER_HIT_DELAY, "m": m, "bot": b})

var _monster_hits: Array = []   ## [{at, m, bot}] đòn quái đang tới bot

func tick_monster_hits(now: float) -> void:
	if _monster_hits.is_empty():
		return
	var keep: Array = []
	for h in _monster_hits:
		if float(h.at) > now:
			keep.append(h)
			continue
		var m: ServerMonster = h.m
		var b: ServerBot = h.bot
		if m.is_dead() or b.dead or not bots.has(b.eid) or b.pos.distance_to(m.pos) > 260.0:
			continue
		var dmg := BotCombat.monster_hit_on_bot(m, b)
		if dmg > 0 and b.lose_hp(float(dmg), now, m.eid, ""):
			_on_bot_died(b)
	_monster_hits = keep

func _on_bot_died(b: ServerBot) -> void:
	_pending = _pending.filter(func(p): return p.bot != b)
	if b.policy != null and b.policy.has_method("on_bot_died"):
		b.policy.on_bot_died(b)

## Lúc đòn tới, mục tiêu đứng ở `at` còn nằm trong đường đạn / vùng nổ không (theo dạng đạn MisslesForm gốc):
##   cận chiến (-1) / không rõ: đã xét tầm ở trên; 1 thẳng: cách đường đạn (từ chỗ ra chiêu qua điểm ngắm) <= bán kính;
##   5 vùng / 6 tại mục tiêu: cách điểm ngắm <= bán kính nổ; 2 toả / 3 vòng / 7 tại người thi triển: trong vòng quanh chỗ ra chiêu.
static func still_in_path(p: Dictionary, at: Vector2) -> bool:
	var form := int(p.get("form", -1))
	var r := float(p.get("radius", MIN_HIT_RADIUS))
	var origin: Vector2 = p.get("origin", at)
	var aim: Vector2 = p.get("aim", at)
	match form:
		1:
			var dir := aim - origin
			if dir.length() < 1.0:
				return at.distance_to(origin) <= r
			var along := (at - origin).dot(dir.normalized())
			if along < -r:
				return false
			var closest := origin + dir.normalized() * along
			return at.distance_to(closest) <= r
		5, 6:
			return at.distance_to(aim) <= r
		2, 3, 7:
			return at.distance_to(origin) <= float(p.get("range", r)) * HIT_RANGE_SLACK
		_:
			return true

## Báo cho các bot ở gần (trừ người ra chiêu) rằng `caster` vừa ra chiêu nhắm `target_eid` / điểm `aim` — não bot quyết né.
## GameServer gọi cho chiêu của người thật; BotManager.cast tự gọi cho chiêu của bot.
func on_cast_seen(caster: ServerEntity, skill_id: int, target_eid: int, aim: Vector2) -> void:
	_notify(caster, skill_id, target_eid, aim)

func _notify_cast(b: ServerBot, sk: SkillDefinition, target_eid: int, aim: Vector2) -> void:
	_notify(b, sk.vltk_skill_id, target_eid, aim)

func _notify(caster: ServerEntity, skill_id: int, target_eid: int, aim: Vector2) -> void:
	for eid in bots:
		var b: ServerBot = bots[eid]
		if b == caster or b.dead or b.room_id != caster.room_id or b.pos.distance_to(caster.pos) > THREAT_RADIUS:
			continue
		if b.brain != null and b.brain.has_method("on_threat"):
			b.brain.on_threat(b, self, caster, skill_id, target_eid, aim)

## Thực thể trong bán kính quanh bot (cùng phòng): người thật, bot khác, quái. Dùng gs.entities_near nếu có (AOI), không thì duyệt bot.
func nearby(b: ServerBot, radius: float) -> Array:
	if gs.has_method("entities_near"):
		return gs.entities_near(b.pos, radius, b.room_id, b.cell_base)
	var out: Array = []
	for eid in bots:
		var o: ServerBot = bots[eid]
		if o != b and o.room_id == b.room_id and o.pos.distance_to(b.pos) <= radius:
			out.append(o)
	return out

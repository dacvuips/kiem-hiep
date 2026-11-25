extends Node
## Bot người chơi phía server — BƯỚC 1 (thân + chiến đấu server-side), GameServer GIẢ (không mạng):
## sinh bot từ hồ sơ, đi, nhảy (miễn sát thương lúc bay), uống thuốc (hồi dần, không uống chồng), ra chiêu (hình ảnh + đòn tới máy người
## thật qua S_PVP_HIT), chạy khỏi tầm = né được, người thật đánh bot (C_PVP_HIT -> server tính đòn), bot đấu bot tới chết, quái đánh bot,
## bot đánh quái.
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/bot_body_tests.tscn

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

class FakeAoi:
	func update(_e) -> void:
		pass
	func remove(_e) -> void:
		pass

class FakeConn:
	var entity: ServerEntity
	var max_hit := 1.0e7

class FakeGs:
	var t := 0.0
	var aoi := FakeAoi.new()
	var entities := {}
	var conns := {}          ## eid -> FakeConn
	var casts: Array = []    ## [{eid, skill, target}]
	var pvp: Array = []      ## [{to, from, raw}]
	var monster_dmg: Array = []
	var next := 100
	func now() -> float:
		return t
	func alloc_eid() -> int:
		next += 1
		return next
	func entity_of(eid: int):
		return entities.get(eid)
	func conn_of_eid(eid: int):
		return conns.get(eid)
	func grid_of(_e):
		return null
	func add_bot_entity(b) -> void:
		entities[b.eid] = b
	func remove_bot_entity(b) -> void:
		entities.erase(b.eid)
	func broadcast_cast(e, skill_id: int, _lv: int, _f: int, target: int, _aim: Vector2) -> void:
		casts.append({"eid": e.eid, "skill": skill_id, "target": target})
	func send_pvp_hit(c, from: int, raw: PackedByteArray) -> void:
		pvp.append({"to": c.entity.eid, "from": from, "raw": raw})
	func bot_damage_monster(b, m, amount: float) -> void:
		monster_dmg.append({"bot": b.eid, "m": m.eid, "amount": amount})

class Policy:
	var allow := true
	var died: Array = []
	func allows_hit_bot(_a, _b) -> bool:
		return allow
	func on_bot_died(b) -> void:
		died.append(b.eid)

var gs: FakeGs
var mgr: BotManager

func _ready() -> void:
	run()
	print("RESULT %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _profile(sect: String, lv := 90, name := "Bot") -> PlayerProfile:
	var p := PlayerProfile.new()
	p.display_name = name
	p.sect_id = sect
	p.level = lv
	p.apply_start_stats()
	p.potential_points = 0
	LonXonRules.refresh_skills(p)
	LonXonRules.give_potions(p)
	return p

## Chạy `sec` giây giả, mỗi nhịp 1/18 giây.
func _run(sec: float) -> void:
	var dt := 1.0 / 18.0
	var n := int(sec / dt)
	for i in n:
		gs.t += dt
		mgr.tick(dt)

func _player_entity(eid: int, at: Vector2) -> FakeConn:
	var e := ServerEntity.new()
	e.eid = eid
	e.kind = NetProto.KIND_PLAYER
	e.pos = at
	e.name = "Người %d" % eid
	gs.entities[eid] = e
	var c := FakeConn.new()
	c.entity = e
	gs.conns[eid] = c
	return c

func run() -> void:
	gs = FakeGs.new()
	mgr = BotManager.new(gs)

	# --- sinh bot
	var a := mgr.spawn(_profile("thieu_lam", 90, "Bot A"), Vector2(1000, 1000))
	check("Bot là thực thể người chơi trong thế giới", a.kind == NetProto.KIND_PLAYER and gs.entities.has(a.eid) and mgr.is_bot(a.eid))
	check("Bot có đòn chính + chỉ số + đầy máu", a.main_skill != null and a.max_hp > 1.0 and a.cur_hp == a.max_hp and a.hp == 100,
		[a.main_skill, a.max_hp])
	check("Bot có ngoại hình như người chơi", a.look.has("armor") and a.name == "Bot A")
	check("Bot có nhiều chiêu chủ động", a.skills.size() >= 2, a.skills.map(func(s): return s.id))

	# --- đi
	a.go_to(Vector2(1300, 1000))
	_run(1.0)
	check("Đi ~150 px/giây, động tác chạy", absf(a.pos.x - 1150.0) < 15.0 and a.action == NetProto.action_index("run"), a.pos)
	_run(2.0)
	check("Tới nơi thì đứng", a.pos.distance_to(Vector2(1300, 1000)) < 5.0 and a.action == NetProto.action_index("stand"), a.pos)

	# --- nhảy: bay, miễn sát thương, đáp xuống
	check("Nhảy được", a.jump_toward(Vector2(1600, 1000), gs.t))
	_run(0.5)
	check("Đang bay: cờ nhảy + độ cao", (a.flags & NetProto.FLAG_JUMPING) != 0 and a.z > 0 and a.pos.x > 1300.0)
	check("Đang bay: miễn sát thương", not a.lose_hp(100.0, gs.t) and a.cur_hp == a.max_hp)
	check("Đang bay: không nhảy chồng", not a.jump_toward(Vector2(2000, 1000), gs.t))
	_run(2.0)
	check("Đáp xuống: hết cờ nhảy", (a.flags & NetProto.FLAG_JUMPING) == 0 and a.z == 0)

	# --- thuốc
	a.cur_hp = a.max_hp * 0.3
	var pots := a.potion_count()
	check("Có 10 bình", pots == 10, pots)
	check("Uống thuốc", a.drink_potion(gs.t) and a.potion_count() == 9)
	check("Không uống chồng khi thuốc còn chạy", not a.drink_potion(gs.t))
	_run(3.1)
	check("Thuốc hồi dần ~30% máu trong 3 giây", absf(a.hp_ratio() - 0.6) < 0.03, a.hp_ratio())

	# --- bot đánh người thật: hình ảnh + đòn tới máy người đó
	var me := _player_entity(50, a.pos + Vector2(40, 0))
	a.cur_hp = a.max_hp
	_run(1.0)
	check("Bot ra chiêu khi người trong tầm", mgr.cast(a, a.main_skill, me.entity), [a.skill_range(a.main_skill)])
	check("Người xung quanh thấy hình ảnh chiêu (S_CAST) với mã chiêu VLTK", gs.casts.size() == 1 and int(gs.casts[0].skill) == a.main_skill.vltk_skill_id
		and int(gs.casts[0].target) == 50)
	check("Hồi chiêu / khoá động tác: không ra chiêu liền", not mgr.cast(a, a.main_skill, me.entity))
	_run(0.6)
	check("Đòn tới máy người thật (S_PVP_HIT)", gs.pvp.size() == 1 and int(gs.pvp[0].from) == a.eid)
	var d := PvpHit.decode(gs.pvp[0].raw) if not gs.pvp.is_empty() else {}
	check("Gói đòn hợp lệ, có sát thương", not d.is_empty() and int(d["max"]) > 0, d.get("max"))

	# --- người chạy khỏi tầm trước khi đòn tới = né được
	gs.pvp.clear()
	me.entity.pos = a.pos + Vector2(40, 0)
	var cast2 := false
	for i in 40:
		cast2 = mgr.cast(a, a.main_skill, me.entity)
		if cast2:
			break
		_run(0.25)
	check("Ra chiêu lần 2 sau hồi chiêu", cast2)
	me.entity.pos = a.pos + Vector2(900, 0)
	_run(0.6)
	check("Chạy khỏi tầm trước lúc trúng: không mất máu (né)", gs.pvp.is_empty())

	# --- người thật đánh bot
	var pol := Policy.new()
	a.policy = pol
	me.entity.pos = a.pos + Vector2(60, 0)
	var strong := CombatantStats.new()
	strong.attack_rating = 100000
	var raw := PvpHit.encode(strong, 300, 300, CombatFormulas.DamageType.PHYSICS, 0, null)
	var before := a.cur_hp
	mgr.on_player_hit(me, a.eid, raw)
	check("Người thật đánh trúng bot: server trừ máu bot", a.cur_hp < before, [before, a.cur_hp])
	check("Ghi người đánh cuối", a.last_hitter_eid == 50)
	pol.allow = false
	before = a.cur_hp
	mgr.on_player_hit(me, a.eid, raw)
	check("Luật màn không cho đánh: không mất máu", a.cur_hp == before)
	pol.allow = true
	me.entity.pos = a.pos + Vector2(5000, 0)
	mgr.on_player_hit(me, a.eid, raw)
	check("Đứng quá xa: không đánh được", a.cur_hp == before)
	me.entity.room_id = 9
	me.entity.pos = a.pos + Vector2(60, 0)
	mgr.on_player_hit(me, a.eid, raw)
	check("Khác phòng: không đánh được", a.cur_hp == before)
	me.entity.room_id = 0

	# --- bot đánh quái
	var m := ServerMonster.new()
	m.eid = 900
	m.kind = NetProto.KIND_MONSTER
	m.level = 10
	m.max_hp = 5000
	m.cur_hp = 5000
	m.data = {"stats": {"attack_rating": [100, 0, 0, 2000], "min_damage": [100, 0, 0, 80], "max_damage": [100, 0, 0, 160], "defense": [100, 0, 0, 5]}}
	m.pos = a.pos + Vector2(30, 0)
	gs.entities[900] = m
	var cast_ok := false
	for i in 40:   ## chờ hết hồi chiêu đòn chính
		cast_ok = mgr.cast(a, a.main_skill, m)
		if cast_ok:
			break
		_run(0.25)
	_run(0.6)
	check("Bot đánh quái: sát thương tới quái", cast_ok and gs.monster_dmg.size() >= 1 and float(gs.monster_dmg[0].amount) > 0.0, gs.monster_dmg)

	# --- quái đánh bot
	var hp0 := a.cur_hp
	for i in 15:
		mgr.on_monster_attack(m, a)
		_run(0.5)
	check("Quái đánh trúng bot (server tính đòn quái)", a.cur_hp < hp0, [hp0, a.cur_hp])

	# --- bot đấu bot tới chết
	var b1 := mgr.spawn(_profile("thien_vuong_bang", 90, "Bot B1"), Vector2(3000, 3000), 0, Vector2i.ZERO, null, Policy.new())
	var b2 := mgr.spawn(_profile("nga_mi", 60, "Bot B2"), Vector2(3150, 3000), 0, Vector2i.ZERO, null, Policy.new())
	b1.brain = BotDuelBrain.new(b2.eid)
	b2.brain = BotDuelBrain.new(b1.eid)
	var fought := 0.0
	while fought < 180.0 and not b1.dead and not b2.dead:
		_run(1.0)
		fought += 1.0
	check("2 bot đấu nhau tới khi có người chết", b1.dead or b2.dead, [b1.hp_ratio(), b2.hp_ratio(), fought])
	var loser := b1 if b1.dead else b2
	var winner := b2 if b1.dead else b1
	check("Bot chết: cờ chết, động tác ngã, báo luật màn", (loser.flags & NetProto.FLAG_DEAD) != 0 and loser.hp == 0
		and loser.action == NetProto.action_index("die") and (loser.policy as Policy).died.has(loser.eid))
	check("Người hạ cuối là bot kia", loser.last_hitter_eid == winner.eid)
	for x in [b1, b2]:
		var h := BotCombat.roll_skill_hit(x, x.main_skill)
		print("    %s: đòn chính %s (đánh thường %s) tầm %d, sát thương %d-%d, máu %d, thủ %d, chính xác %d" % [x.name, x.main_skill.id,
			x.main_skill.is_basic_attack, int(x.skill_range(x.main_skill)), int(h.min), int(h.max), int(x.max_hp), x.stats.defense, x.stats.attack_rating])
		for sk in x.skills:
			var hs := BotCombat.roll_skill_hit(x, sk)
			print("      chiêu %s cấp %d: %d-%d tầm %d địch=%s bản thân=%s hào quang=%s" % [sk.id, x.skill_level(sk), int(hs.min), int(hs.max),
				int(x.skill_range(sk)), sk.target_enemy, sk.target_self, sk.is_aura])
	var probe1 := ServerBot.create(1, b1.profile)
	var probe2 := ServerBot.create(2, b2.profile)
	var dealt := [0, 0]
	for i in 200:
		dealt[0] += maxi(0, BotCombat.bot_vs_bot(probe1, probe2, BotCombat.roll_skill_hit(probe1, probe1.main_skill)))
		dealt[1] += maxi(0, BotCombat.bot_vs_bot(probe2, probe1, BotCombat.roll_skill_hit(probe2, probe2.main_skill)))
	print("    sát thương thực trung bình / đòn: B1 -> B2 %.1f, B2 -> B1 %.1f" % [dealt[0] / 200.0, dealt[1] / 200.0])
	probe1.free_resources()
	probe2.free_resources()
	check("Đòn chính của bot là chiêu phái (không phải đánh thường)", not b1.main_skill.is_basic_attack and not b2.main_skill.is_basic_attack,
		[b1.main_skill.id, b2.main_skill.id])
	check("Bot cấp cao hơn (90) thắng bot cấp 60", winner == b1, [winner.name, fought])
	var n_before := gs.pvp.size()
	_run(3.0)
	check("Chết rồi thì không ra đòn nữa", not loser.lose_hp(10.0, gs.t))
	loser.revive(Vector2(3000, 3200), gs.t)
	check("Hồi sinh: đầy máu, hết cờ chết", not loser.dead and loser.cur_hp == loser.max_hp and (loser.flags & NetProto.FLAG_DEAD) == 0)

	_test_poison_stacks()

	# --- bỏ bot
	mgr.remove(a)
	check("Bỏ bot: rời thế giới", not gs.entities.has(a.eid) and not mgr.is_bot(a.eid))

## Độc lên bot (server): trúng liên tục thì GỘP lớp độc như KNpc::ReceiveDamage gốc — nhịp rút to dần, không bị đè.
func _test_poison_stacks() -> void:
	var p := ServerBot.create(9001, _profile("thieu_lam", 90, "Bot Độc"))
	p.stats.poison_time_reduce_p = 0
	p.max_hp = 1.0e9
	p.cur_hp = p.max_hp
	var mods := CombatFormulas.HitModifiers.new()
	mods.poison_time_frames = 60
	mods.poison_interval_frames = 10
	var dealt := {CombatFormulas.DamageType.POISON: 181}
	var t := 0.0
	var ticks: Array = []
	for f in 18 * 4:   ## 4 giây, trúng mỗi 20 frame
		if f % 20 == 0:
			p.apply_hit_effects(mods, dealt, t, 0)
		var hp := p.cur_hp
		t += 1.0 / 18.0
		p._tick_states(t)
		if p.cur_hp < hp:
			ticks.append(int(round(hp - p.cur_hp)))
	check("Bot dính độc: có rút máu theo nhịp", ticks.size() >= 6, ticks)
	check("Bot dính độc liên tục: nhịp rút tăng dần (gộp lớp độc)", ticks.size() > 0 and ticks.max() >= 181 * 3, ticks)
	## Đánh 1 lần: rút đúng 6 nhịp × 181 rồi hết.
	var q := ServerBot.create(9002, _profile("thieu_lam", 90, "Bot Độc 2"))
	q.stats.poison_time_reduce_p = 0
	q.max_hp = 1.0e9
	q.cur_hp = q.max_hp
	q.apply_hit_effects(mods, dealt, 0.0, 0)
	for f in 18 * 5:
		q._tick_states((f + 1) / 18.0)
	check("Bot trúng độc 1 lần: rút 6 nhịp × 181 rồi hết", is_equal_approx(q.max_hp - q.cur_hp, 181.0 * 6) and q._poison.is_empty(),
		q.max_hp - q.cur_hp)
	p.free_resources()
	q.free_resources()

extends Node
## BỘ NÃO CHIẾN ĐẤU của bot (BotCombatBrain — bước 2), GameServer GIẢ: phân loại bộ chiêu, bật hào quang, buff trước khi đánh, thả bùa,
## né theo đường đạn (tỉ lệ theo độ khó), đường đạn / vùng nổ quyết định trúng, bơm máu (giữ 2 bình cuối), ngồi thiền, rút khi yếu,
## thả diều, vòng quanh, nhảy áp sát, bị choáng thì đứng, bot Khó thắng bot Dễ cùng sức.
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/bot_brain_tests.tscn

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

class FakeGs:
	var t := 0.0
	var aoi := FakeAoi.new()
	var entities := {}
	var casts: Array = []
	var next := 100
	func now() -> float:
		return t
	func alloc_eid() -> int:
		next += 1
		return next
	func entity_of(eid: int):
		return entities.get(eid)
	func conn_of_eid(_eid: int):
		return null
	func grid_of(_e):
		return null
	func add_bot_entity(b) -> void:
		entities[b.eid] = b
	func remove_bot_entity(b) -> void:
		entities.erase(b.eid)
	func broadcast_cast(e, skill_id: int, _lv: int, flags: int, target: int, _aim: Vector2) -> void:
		casts.append({"eid": e.eid, "skill": skill_id, "target": target, "flags": flags})
	func send_pvp_hit(_c, _from: int, _raw: PackedByteArray) -> void:
		pass
	func bot_damage_monster(_b, _m, _amount: float) -> void:
		pass

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
	LonXonRules.refresh_skills(p)
	LonXonRules.give_potions(p)
	return p

func _bot(sect: String, at: Vector2, diff := 1, lv := 90, target := 0) -> ServerBot:
	var b := mgr.spawn(_profile(sect, lv, "%s %d" % [sect, gs.next]), at, 0, Vector2i.ZERO, BotCombatBrain.new(target))
	b.difficulty = diff
	return b

func _run(sec: float) -> void:
	var dt := 1.0 / 18.0
	for i in int(sec / dt):
		gs.t += dt
		mgr.tick(dt)

func _reset() -> void:
	for eid in mgr.bots.keys():
		mgr.remove(mgr.bots[eid])
	gs.casts.clear()

## Phái đầu tiên có ít nhất 1 chiêu thuộc nhóm `group` trong bộ chiêu.
func _sect_with(group: String) -> String:
	for sect in SectRegistry.load_all():
		var b := _bot(sect.id, Vector2(50000, 50000))
		var br: BotCombatBrain = b.brain
		br._ensure_kit(b)
		var ok := br.kit()[group] != null if group == "aura" else not (br.kit()[group] as Array).is_empty()
		mgr.remove(b)
		if ok:
			return sect.id
	return ""

func run() -> void:
	gs = FakeGs.new()
	mgr = BotManager.new(gs)

	# --- bộ chiêu
	var tv := _bot("thien_vuong_bang", Vector2(1000, 1000))
	var tvb: BotCombatBrain = tv.brain
	tvb._ensure_kit(tv)
	var k := tvb.kit()
	print("    Thiên Vương: %d đòn đánh (mạnh nhất %s), %d buff, %d bùa, hào quang %s" % [k.attacks.size(),
		(k.attacks[0].sk as SkillDefinition).id if not k.attacks.is_empty() else "-", k.buffs.size(), k.debuffs.size(), k.aura])
	check("Bộ chiêu: có đòn đánh, xếp mạnh -> yếu", k.attacks.size() >= 3 and float(k.attacks[0].avg) >= float(k.attacks[-1].avg))
	check("Bộ chiêu: có buff bản thân (Thiên Vương)", not (k.buffs as Array).is_empty(), k.buffs)
	var aura_sect := _sect_with("aura")
	var debuff_sect := _sect_with("debuffs")
	print("    phái có hào quang: %s · phái có bùa: %s" % [aura_sect, debuff_sect])
	check("Có phái có hào quang và phái có bùa", aura_sect != "" and debuff_sect != "")
	_reset()

	# --- hào quang bật ngay
	if aura_sect != "":
		var au := _bot(aura_sect, Vector2(1000, 1000))
		_run(1.0)
		var aura: SkillDefinition = (au.brain as BotCombatBrain).kit().aura
		check("Bật hào quang ngay khi vào", au.profile.active_aura_id == aura.id and gs.casts.any(func(c): return int(c.flags) == NetProto.CAST_SUPPORT))
		_reset()

	# --- buff trước khi đánh
	var a := _bot("thien_vuong_bang", Vector2(1000, 1000), 2)
	var dummy := _bot("nga_mi", Vector2(1300, 1000), 1, 30)
	dummy.brain = null
	(a.brain as BotCombatBrain).target_eid = dummy.eid
	var buff: SkillDefinition = (a.brain as BotCombatBrain).kit().buffs[0] if not ((a.brain as BotCombatBrain).kit().get("buffs", []) as Array).is_empty() else null
	_run(1.0)
	buff = (a.brain as BotCombatBrain).kit().buffs[0]
	check("Buff bản thân trước khi lao vào", a.has_state(buff.id, gs.t), a.states.keys())
	var def_before := ServerBot.create(1, a.profile)
	check("Buff đổi chỉ số thật của bot", a.stats.defense != def_before.stats.defense or a.max_hp != def_before.max_hp
		or a.stats.attack_rating != def_before.stats.attack_rating, [a.stats.defense, def_before.stats.defense])
	def_before.free_resources()
	_reset()

	# --- bùa lên mục tiêu
	if debuff_sect != "":
		var caster := _bot(debuff_sect, Vector2(1000, 1000), 2)
		var victim := _bot("thieu_lam", Vector2(1150, 1000), 1, 30)
		victim.brain = null
		(caster.brain as BotCombatBrain).target_eid = victim.eid
		var got := false
		for i in 40:
			_run(0.5)
			for sid in victim.states:
				if bool(victim.states[sid].debuff):
					got = true
			if got:
				break
		check("Thả bùa lên mục tiêu (trạng thái debuff trên bot bị đánh)", got, victim.states.keys())
		_reset()

	# --- đường đạn / vùng nổ quyết định trúng
	var line := {"form": 1, "radius": 45.0, "origin": Vector2(0, 0), "aim": Vector2(300, 0), "range": 400.0}
	check("Đạn thẳng: đứng trên đường đạn thì trúng", BotManager.still_in_path(line, Vector2(250, 20)))
	check("Đạn thẳng: bước ngang 90px thì né được", not BotManager.still_in_path(line, Vector2(250, 95)))
	var blast := {"form": 6, "radius": 100.0, "origin": Vector2(0, 0), "aim": Vector2(300, 0)}
	check("Nổ tại chỗ: trong vùng trúng, ra khỏi vùng né", BotManager.still_in_path(blast, Vector2(350, 30)) and not BotManager.still_in_path(blast, Vector2(450, 0)))

	# --- tỉ lệ né theo độ khó
	var shooter := _bot("nga_mi", Vector2(2000, 2000))
	shooter.brain = null
	var straight: SkillDefinition = null
	for sk in shooter.skills:
		if sk.vltk_missle_form == 1:
			straight = sk
	var rates := []
	for diff in 3:
		var dodger := _bot("thieu_lam", Vector2(2300, 2000), diff)
		var n := 0
		for i in 400:
			var br := BotCombatBrain.new()
			br.on_threat(dodger, mgr, shooter, straight.vltk_skill_id if straight else 0, dodger.eid, dodger.pos)
			if not br._queue.is_empty():
				n += 1
		rates.append(n / 400.0)
		mgr.remove(dodger)
	print("    tỉ lệ né Dễ / Thường / Khó: %.2f / %.2f / %.2f" % rates)
	check("Né theo độ khó ~20% / 50% / 80%", absf(rates[0] - 0.2) < 0.07 and absf(rates[1] - 0.5) < 0.08 and absf(rates[2] - 0.8) < 0.07, rates)
	var br2 := BotCombatBrain.new()
	var dg := _bot("thieu_lam", Vector2(2300, 2000), 2)
	var dodged := false
	for i in 30:
		br2.on_threat(dg, mgr, shooter, straight.vltk_skill_id if straight else 0, dg.eid, dg.pos)
		if not br2._queue.is_empty():
			dodged = true
			break
	var q: Dictionary = br2._queue[0] if dodged else {}
	check("Né đạn thẳng = bước vuông góc hướng bay, có trễ phản xạ", dodged and float(q.at) > gs.t + 0.1
		and absf(((q.data as Vector2) - dg.pos).normalized().dot((dg.pos - shooter.pos).normalized())) < 0.2, q)
	_reset()

	# --- bơm máu: đang đánh < 55%, giữ 2 bình cuối, nguy kịch thì uống nốt
	var p := _bot("thieu_lam", Vector2(1000, 1000))
	var foe := _bot("nga_mi", Vector2(1200, 1000), 1, 90)
	foe.brain = null
	var pb: BotCombatBrain = p.brain
	pb.target_eid = foe.eid
	p.cur_hp = p.max_hp * 0.5
	var c0 := p.potion_count()
	_run(1.0)
	print("    [thuốc] máu %.2f, chết %s, choáng %s, hàng việc %s, thuốc chạy tới %.1f (giờ %.1f), phân tâm tới %.1f, kit %s" % [p.hp_ratio(), p.dead,
		p.is_stunned(gs.t), pb._queue, p.potion_until, gs.t, pb._distract_until, not pb._kit.is_empty()])
	check("Đánh nhau, máu 50%: uống thuốc (sau trễ phản xạ)", p.potion_count() == c0 - 1, [c0, p.potion_count()])
	(p.profile.inventory[0] as ItemInstance).count = 2
	p.potion_until = 0.0
	p.cur_hp = p.max_hp * 0.4
	_run(1.5)
	check("Còn 2 bình, máu 40%: giữ lại", p.potion_count() == 2)
	p.cur_hp = p.max_hp * 0.2
	p.potion_until = 0.0
	_run(1.5)
	check("Máu 20%: uống bình dự trữ", p.potion_count() == 1)
	_reset()

	# --- ngồi thiền lúc rảnh
	var s := _bot("thieu_lam", Vector2(1000, 1000))
	s.cur_hp = s.max_hp * 0.6
	_run(1.5)
	var hp_sit := s.hp_ratio()
	_run(3.0)
	check("Rảnh, máu 60%: ngồi thiền (động tác ngồi) và hồi máu", s.sitting and s.action == NetProto.action_index("sit") and s.hp_ratio() > hp_sit + 0.05,
		[s.sitting, hp_sit, s.hp_ratio()])
	_reset()

	# --- rút khi yếu
	var w := _bot("nga_mi", Vector2(1000, 1000), 1, 40)
	var strong := _bot("thien_vuong_bang", Vector2(1150, 1000), 1, 150)
	strong.brain = null
	(w.brain as BotCombatBrain).target_eid = strong.eid
	(w.profile.inventory[0] as ItemInstance).count = 0
	w.profile.inventory.clear()
	w.cur_hp = w.max_hp * 0.2
	var d0 := w.pos.distance_to(strong.pos)
	_run(2.0)
	check("Máu 20%, hết thuốc, địch mạnh: bỏ chạy", w.pos.distance_to(strong.pos) > d0 + 100.0, [d0, w.pos.distance_to(strong.pos)])
	_reset()

	# --- thả diều (đánh xa bị áp sát)
	var r := _bot("nga_mi", Vector2(1000, 1000), 2)
	var m := _bot("thieu_lam", Vector2(1060, 1000), 1, 30)
	m.brain = null
	var rb: BotCombatBrain = r.brain
	rb.target_eid = m.eid
	rb._ensure_kit(r)
	var ideal := rb._ideal_range(r)
	for sk in r.skills:
		r.ready_at[sk.id] = 1.0e9   ## hết chiêu: chỉ còn di chuyển
	r.profile.active_aura_id = ""
	var dk0 := r.pos.distance_to(m.pos)
	_run(1.5)
	check("Đánh xa (tầm %d) bị áp sát: lùi ra thả diều quá nửa tầm" % int(ideal), not rb.is_melee(r) and r.pos.distance_to(m.pos) > maxf(dk0 + 30.0, ideal * 0.55),
		[dk0, r.pos.distance_to(m.pos)])
	_reset()

	# --- cận chiến vòng quanh
	var o := _bot("thieu_lam", Vector2(1000, 1000), 1)
	var tgt := _bot("nga_mi", Vector2(1060, 1000), 1, 30)
	tgt.brain = null
	(o.brain as BotCombatBrain).target_eid = tgt.eid
	(o.brain as BotCombatBrain)._ensure_kit(o)
	for sk in o.skills:
		o.ready_at[sk.id] = 1.0e9
	var ang_prev := (o.pos - tgt.pos).angle()
	var turned := 0.0
	var far := 0.0
	for i in 10:
		_run(0.2)
		var ang := (o.pos - tgt.pos).angle()
		turned += absf(angle_difference(ang_prev, ang))
		ang_prev = ang
		far = maxf(far, o.pos.distance_to(tgt.pos))
	check("Cận chiến: vòng quanh mục tiêu (quay > 1 rad trong 2 giây), vẫn sát", turned > 1.0 and far < 160.0, [turned, far])
	_reset()

	# --- nhảy áp sát kẻ chạy
	var j := _bot("thieu_lam", Vector2(1000, 1000), 2)
	var run := _bot("nga_mi", Vector2(1300, 1000), 1, 30)
	run.brain = null
	(j.brain as BotCombatBrain).target_eid = run.eid
	var jumped := false
	for i in 30:
		run.pos += Vector2(12, 0)
		_run(0.2)
		if j.is_jumping(gs.t) or (j.flags & NetProto.FLAG_JUMPING) != 0:
			jumped = true
			break
	check("Nhảy áp sát kẻ đang chạy (Khó)", jumped, j.pos.distance_to(run.pos))
	_reset()

	# --- bị choáng: đứng im, không ra chiêu
	var st := _bot("thieu_lam", Vector2(1000, 1000))
	var mods := CombatFormulas.HitModifiers.new()
	mods.stun_chance_p = 100
	mods.stun_frames = 54
	st.apply_hit_effects(mods, {}, gs.t)
	check("Choáng: không ra chiêu, không nhảy", st.is_stunned(gs.t) and not st.skill_ready(st.main_skill, gs.t) and not st.jump_toward(Vector2(0, 0), gs.t))
	_run(3.5)
	check("Hết choáng sau ~3 giây", not st.is_stunned(gs.t))
	_reset()

	# --- Khó thắng Dễ (cùng phái, cùng cấp)
	var hard_wins := 0
	var fights := 20
	var sum_hard := {"casts": 0, "hits": 0, "dmg": 0, "taken": 0, "jumps": 0, "potions": 0, "dodges": 0, "buffs": 0}
	var sum_easy := sum_hard.duplicate()
	for f in fights:
		var hx := 1000.0 + f * 5000.0
		var hard := _bot("thieu_lam", Vector2(hx, 1000), 2, 90)
		var easy := _bot("thieu_lam", Vector2(hx + 250.0, 1000), 0, 90)
		(hard.brain as BotCombatBrain).target_eid = easy.eid
		(easy.brain as BotCombatBrain).target_eid = hard.eid
		var tt := 0.0
		while tt < 150.0 and not hard.dead and not easy.dead:
			_run(1.0)
			tt += 1.0
		if easy.dead and not hard.dead:
			hard_wins += 1
		for key in sum_hard:
			sum_hard[key] += int(hard.tally[key])
			sum_easy[key] += int(easy.tally[key])
		_reset()
	print("    Khó thắng Dễ %d / %d trận" % [hard_wins, fights])
	print("    tổng 20 trận  Khó: %s" % sum_hard)
	print("                  Dễ : %s" % sum_easy)
	check("Bot Khó thắng bot Dễ cùng sức phần lớn số trận (>= 13/20)", hard_wins >= 13, hard_wins)

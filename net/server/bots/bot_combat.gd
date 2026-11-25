class_name BotCombat
extends RefCounted
## TÍNH ĐÒN CỦA BOT TRÊN SERVER (bot không có máy để tự tính) — dùng đúng CombatFormulas như máy người chơi (HitResolver):
## trúng / né (attack_rating vs defense), giáp, kháng từng loại sát thương, tương khắc ngũ hành, chí mạng, hệ số PK.
##   - Người thật đánh bot: gói C_PVP_HIT (PvpHit) -> resolve_on_bot.
##   - Bot đánh người thật: roll_skill_hit -> PvpHit.encode -> S_PVP_HIT tới máy người đó (máy họ tự né / kháng như PvP thường).
##   - Bot đánh bot: roll_skill_hit -> resolve_on_bot.   - Bot đánh quái: damage_vs_monster.   - Quái đánh bot: monster_hit_on_bot.
## Hàm thuần (không Node trong cây cảnh) -> chạy được trên server headless và trong test.

const MISSED := -1

## Node tạm làm "người thi triển" cho SectSkillController._resolve_stats (đọc combat_stats / mana của caster).
class _Caster extends Node2D:
	var combat_stats: CombatantStats
	var mana := 0.0

## Số liệu 1 đòn của chiêu `sk` do bot ra: {min, max, type, element, mods (HitModifiers), physical}.
static func roll_skill_hit(bot: ServerBot, sk: SkillDefinition) -> Dictionary:
	var caster := _Caster.new()
	caster.combat_stats = bot.stats
	caster.mana = bot.mana
	var prev := GameManager.local_profile
	GameManager.local_profile = bot.profile   ## _resolve_stats có chỗ đọc hồ sơ qua GameManager (như ProfileGuard.max_hit)
	var st: ResolvedSkillStats = bot.skill_ctl._resolve_stats(sk, caster)
	GameManager.local_profile = prev
	caster.free()
	var low := int(st.damage_min) if st.damage_min >= 0.0 else int(st.damage)
	var high := int(st.damage_max) if st.damage_max >= 0.0 else int(st.damage)
	var mods := st.make_hit_mods(null, sk.is_physical())
	return {"min": maxi(0, low), "max": maxi(low, high), "type": st.main_damage_type if st.main_damage_type >= 0 else CombatFormulas.DamageType.PHYSICS,
		"element": st.element, "mods": mods, "physical": sk.is_physical()}

## Gói PvpHit của đòn bot -> gửi S_PVP_HIT cho máy người bị đánh.
static func encode_for_player(bot: ServerBot, hit: Dictionary) -> PackedByteArray:
	return PvpHit.encode(bot.stats, int(hit.min), int(hit.max), int(hit.type), int(hit.element), hit.mods)

## Đòn (chỉ số người đánh + min/max + loại + hệ + mods) vào bot. Trả về sát thương thực (>= 0) hoặc MISSED. KHÔNG tự trừ máu.
## Áp luôn hiệu ứng của đòn lên bot (bùa / làm chậm / độc / choáng) như HitResolver + StatusEffectController của người chơi.
static func resolve_on_bot(bot: ServerBot, attacker: CombatantStats, min_damage: int, max_damage: int, damage_type: int,
		element: int, mods: CombatFormulas.HitModifiers, is_pk := true, from_monster := false, from_eid := 0, monster_elite := false) -> int:
	if mods == null:
		mods = CombatFormulas.HitModifiers.new()
	if mods.is_state_only:
		if bot.is_jumping(bot.now_cache):
			return MISSED
		bot.add_state(mods.state_source_id, mods.state_attribs, mods.state_seconds, bot.now_cache, true)   ## bùa thuần
		return 0
	var ignore_def: int = maxi(attacker.ignore_defense_p if attacker else 0, mods.ignore_defense_percent)
	if mods.use_attack_rating:
		var ar := CombatFormulas.hit_attack_rating(attacker, mods)
		var hit := CombatFormulas.roll_monster_hit(ar, bot.stats.defense, ignore_def) if from_monster \
				else CombatFormulas.roll_hit(ar, bot.stats.defense, ignore_def)
		if not hit:
			return MISSED
	mods.is_pk = is_pk
	mods.five_elements_rate_percent = CombatFormulas.MONSTER_FIVE_ELEMENTS_RATE_PERCENT if from_monster else 100
	var parts: Dictionary = mods.extra_damages.duplicate()
	var main: Vector2i = parts.get(damage_type, Vector2i.ZERO)
	parts[damage_type] = main + Vector2i(min_damage, max_damage)
	if not from_monster or monster_elite:   ## quái map thường: đúng bảng C++; chỉ ải Tinh anh mới nhân hệ số server
		parts = CombatFormulas.apply_server_damage_scaling(parts, element)
	if from_monster:
		for t in parts.keys():
			var p: Vector2i = parts[t]
			parts[t] = Vector2i(p.x * CombatFormulas.MONSTER_DAMAGE_RATE_PERCENT / 100, p.y * CombatFormulas.MONSTER_DAMAGE_RATE_PERCENT / 100)
	var dealt := {}
	var final := CombatFormulas.resolve_multi_damage(attacker, bot.stats, int(bot.cur_hp), parts, element as ElementTypes.ElementType,
		mods, dealt, int(bot.mana))
	if not bot.is_jumping(bot.now_cache):
		bot.apply_hit_effects(mods, dealt, bot.now_cache, from_eid, CombatFormulas.poison_tick_damage(bot.stats, parts, is_pk))
	return maxi(final, 0)

## Gói C_PVP_HIT của người thật (đã PvpHit.decode + sanitize) vào bot.
static func resolve_pvp_packet_on_bot(bot: ServerBot, d: Dictionary, from_eid := 0) -> int:
	var attacker := CombatantStats.new()
	PvpHit._load(attacker, d["as"])
	var mods := CombatFormulas.HitModifiers.new()
	PvpHit._load(mods, d["mods"])
	return resolve_on_bot(bot, attacker, int(d["min"]), int(d["max"]), int(d["type"]), int(d["el"]), mods, true, false, from_eid)

## Đòn của bot `a` vào bot `b`.
static func bot_vs_bot(a: ServerBot, b: ServerBot, hit: Dictionary) -> int:
	return resolve_on_bot(b, a.stats, int(hit.min), int(hit.max), int(hit.type), int(hit.element), hit.mods, true, false, a.eid)

## Sát thương đòn bot lên quái server (quái không có kháng chi tiết ở server: dùng phòng thủ + hệ của quái).
static func damage_vs_monster(bot: ServerBot, m: ServerMonster, hit: Dictionary) -> int:
	var def := CombatantStats.new()
	def.defense = maxi(0, MonsterData.stat_at_level(m.data, "defense", m.level))
	def.element = m.series as ElementTypes.ElementType
	var mods: CombatFormulas.HitModifiers = hit.mods
	if mods.use_attack_rating and not CombatFormulas.roll_hit(CombatFormulas.hit_attack_rating(bot.stats, mods), def.defense, mods.ignore_defense_percent):
		return MISSED
	var parts: Dictionary = mods.extra_damages.duplicate()
	parts[int(hit.type)] = parts.get(int(hit.type), Vector2i.ZERO) + Vector2i(int(hit.min), int(hit.max))
	parts = CombatFormulas.apply_server_damage_scaling(parts, int(hit.element))
	return maxi(0, CombatFormulas.resolve_multi_damage(bot.stats, def, int(m.cur_hp), parts, int(hit.element) as ElementTypes.ElementType, mods))

## Quái `m` đánh trúng bot (chỉ số đánh của quái theo cấp, sát thương quái đánh người x MONSTER_DAMAGE_RATE_PERCENT như máy người chơi).
static func monster_hit_on_bot(m: ServerMonster, bot: ServerBot) -> int:
	var a := CombatantStats.new()
	a.attack_rating = maxi(0, MonsterData.stat_at_level(m.data, "attack_rating", m.level))
	a.element = m.series as ElementTypes.ElementType
	var lo := maxi(0, MonsterData.stat_at_level(m.data, "min_damage", m.level))
	var hi := maxi(lo, MonsterData.stat_at_level(m.data, "max_damage", m.level))
	if hi <= 0:
		return MISSED
	return resolve_on_bot(bot, a, lo, hi, CombatFormulas.DamageType.PHYSICS, m.series, null, false, true, 0, m.hell_stars > 0)

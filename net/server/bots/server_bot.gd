class_name ServerBot
extends ServerEntity
## BOT NGƯỜI CHƠI do server điều khiển (docs/plans/bot-lon-xon-pubg.md) — người thật thấy như 1 người chơi khác (KIND_PLAYER trong AOI).
## Chỉ có THÂN ở đây: hồ sơ + chỉ số (CombatantStats như người chơi), máu / nội lực / thuốc, đi trên MapGrid, nhảy, ra chiêu (hồi chiêu,
## khoá động tác), chết. Đánh ai / đi đâu do `brain` quyết (BotDuelBrain, sau này BotCombatBrain + kịch bản Lộn Xộn / PUBG);
## tính đòn do BotCombat. Mọi trạng thái nằm trên chính bot (nhiều bot dùng chung Resource skill).

const BASE_SPEED := 150.0          ## = Player.SPEED (px/giây)
const JUMP_SEC := 40.0 / 18.0      ## = Player.JUMP_DEFAULT_FRAMES (40 frame VLTK)
const JUMP_SPEED := 12.0 * 18.0    ## = Player.JUMP_SPEED (px/giây)
const JUMP_COOLDOWN := 1.5
const ACTION_LOCK_SEC := 18.0 / 18.0 * 0.5   ## khoá động tác tối thiểu sau mỗi chiêu (giãn cách ra chiêu ~ người chơi)
const POTION_COOLDOWN := 1.0
const POTION_HEAL_SEC := 3.0       ## thuốc hồi dần trong chừng này giây (như PotionEffect)
const POTION_HEAL_P := 0.3         ## mỗi bình hồi 30% máu tối đa
const MANA_REGEN_P := 0.02         ## hồi 2% nội lực / giây

var profile: PlayerProfile
var stats: CombatantStats
var max_hp := 1.0
var cur_hp := 1.0
var max_mana := 1.0
var mana := 1.0
var skill_ctl: SectSkillController
var main_skill: SkillDefinition
var skills: Array[SkillDefinition] = []     ## mọi chiêu chủ động dùng được (đã học, gắn được ô)
var ready_at := {}                          ## skill.id -> lúc hết hồi chiêu (giây server)
var action_until := 0.0                     ## đang khoá động tác tới lúc này
var potion_until := 0.0                     ## thuốc đang chạy tới lúc này (không uống chồng)
var _potion_rate := 0.0                     ## máu hồi / giây của bình đang chạy
var _potion_ready := 0.0
var jump_until := 0.0
var _jump_dir := Vector2.ZERO
var _jump_ready := 0.0
var dead := false
var died_at := 0.0
var last_hitter_eid := 0
var last_hitter_name := ""
var difficulty := 1                         ## 0 Dễ / 1 Thường / 2 Khó (BotCombatBrain dùng)
## Bộ não: Object có think(bot, gs, dt). null = đứng yên.
var brain: Object = null
## Luật của màn đang ở (LonXonServer / PubgServer / thử): Object có allows_hit_bot(attacker_entity, bot) -> bool và
## on_bot_died(bot) — null = ai cũng đánh được, chết thì nằm đó.
var policy: Object = null
var move_dest := Vector2.INF                ## đang đi tới (chân, px) — INF = đứng
var speed := BASE_SPEED
## Bộ đếm hành vi (đo độ "thông minh" / cân chỉnh): ra chiêu, trúng, sát thương gây ra, nhận, nhảy, uống thuốc, né, bị trúng.
var tally := {"casts": 0, "hits": 0, "dmg": 0, "taken": 0, "jumps": 0, "potions": 0, "dodges": 0, "buffs": 0}
var now_cache := 0.0                        ## giây server ở nhịp gần nhất (BotCombat dùng khi áp hiệu ứng)

## ---- Trạng thái (như StatusEffectController của người chơi) ----
## source_id -> {attribs: {tên: Vector3i}, until, debuff}. Thuộc tính cộng vào chỉ số qua profile.get_combat_stats(state_sources).
var states := {}
var slow_until := 0.0                       ## đang bị làm chậm (Băng sát)
var stun_until := 0.0                       ## đang bị choáng: không đi / không ra chiêu
var _poison := {}                           ## {d: rút mỗi nhịp, t: frame còn lại, c: nhịp (frame), acc, last}
var _poison_from := 0                       ## eid người gây độc gần nhất (tính người hạ)
var sitting := false                        ## ngồi thiền (hồi nhanh hơn, BotCombatBrain bật lúc rảnh)
const SLOW_FACTOR := 0.5
const SIT_REGEN_P := 0.03                   ## ngồi thiền: hồi 3% máu / giây

static func create(eid_value: int, bot_profile: PlayerProfile) -> ServerBot:
	var b := ServerBot.new()
	b.eid = eid_value
	b.kind = NetProto.KIND_PLAYER
	b.setup(bot_profile)
	return b

func setup(bot_profile: PlayerProfile) -> void:
	profile = bot_profile
	name = profile.display_name
	level = profile.level
	camp = profile.get_current_camp()
	refresh_stats()
	cur_hp = max_hp
	mana = max_mana
	refresh_look()
	if skill_ctl != null:
		skill_ctl.free()
	skill_ctl = SectSkillController.new()
	skill_ctl.owner_profile = profile
	skill_ctl.setup(SectRegistry.get_by_id(profile.sect_id))
	main_skill = skill_ctl.get_main_skill()
	skills.clear()
	var sect := SectRegistry.get_by_id(profile.sect_id)
	if sect != null:
		for sk in sect.skills:
			if sk != null and sk.category == SkillDefinition.SkillCategory.ACTIVE and not sk.is_hidden and sk.parent_skill_id == "" \
					and skill_ctl.is_skill_usable(sk) and profile.get_skill_level(sk.id) > 0:
				skills.append(sk)
	if main_skill != null and not skills.has(main_skill):
		skills.push_front(main_skill)
	## Hồ sơ bot chưa gắn đòn chính -> mặc định là đánh thường tay không. Người chơi thật luôn gắn chiêu mạnh nhất của phái làm đòn
	## chính: bot cũng vậy (chiêu nhắm địch, không phải hào quang, sát thương trung bình cao nhất).
	if main_skill == null or main_skill.is_basic_attack:
		var best: SkillDefinition = null
		var best_dmg := 0.0
		for sk in skills:
			if sk.is_basic_attack or sk.is_aura or not sk.target_enemy:
				continue
			var h := BotCombat.roll_skill_hit(self, sk)
			var avg := (float(h.min) + float(h.max)) * 0.5
			if avg > best_dmg:
				best_dmg = avg
				best = sk
		if best != null:
			main_skill = best

## Đọc lại chỉ số từ hồ sơ (đổi đồ / lên cấp / cộng điểm). Giữ tỉ lệ máu, nội lực hiện tại.
func refresh_stats() -> void:
	var hp_ratio := cur_hp / max_hp if max_hp > 0.0 else 1.0
	var mp_ratio := mana / max_mana if max_mana > 0.0 else 1.0
	stats = profile.get_combat_stats(_state_sources())
	max_hp = maxf(1.0, float(stats.max_hp))
	max_mana = maxf(1.0, float(stats.max_mana))
	cur_hp = clampf(max_hp * hp_ratio, 0.0, max_hp)
	mana = clampf(max_mana * mp_ratio, 0.0, max_mana)
	speed = BASE_SPEED * (1.0 + stats.move_speed_p / 100.0)
	level = profile.level
	_sync_hp()
	touch()

func refresh_look() -> void:
	look = GameServer.look_from_profile(profile.to_dict())
	if profile.riding and int(look.get("horse", -1)) >= 0:
		flags |= NetProto.FLAG_RIDING
	else:
		flags &= ~NetProto.FLAG_RIDING
	look_dirty = true
	touch()

func _state_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sid in states:
		out.append(states[sid].attribs)
	return out

## Buff / bùa `source_id` trong `seconds` giây (gặp lại thì làm mới). debuff = do kẻ địch thả lên.
func add_state(source_id: String, attribs: Dictionary, seconds: float, now: float, debuff := false) -> void:
	if source_id == "" or seconds <= 0.0 or dead:
		return
	states[source_id] = {"attribs": attribs, "until": now + seconds, "debuff": debuff}
	refresh_stats()

func has_state(source_id: String, now: float) -> bool:
	return states.has(source_id) and float(states[source_id].until) > now

## Giây còn lại của trạng thái (0 = không có).
func state_left(source_id: String, now: float) -> float:
	return maxf(0.0, float(states[source_id].until) - now) if states.has(source_id) else 0.0

func is_stunned(now: float) -> bool:
	return now < stun_until

## Bật hào quang (skill is_aura) — thuộc tính tính như nguồn cố định khi đang bật (CombatantBuild).
func set_aura(skill_id: String) -> void:
	if profile.active_aura_id == skill_id:
		return
	profile.active_aura_id = skill_id
	refresh_stats()

## Hiệu ứng của 1 đòn trúng (làm chậm / độc / choáng / bùa) — như StatusEffectController.apply_vltk_hit + HitResolver._apply_hit_state.
## `poison_tick` như StatusEffectController.apply_vltk_hit (CombatFormulas.poison_tick_damage; -1 = theo damage độc của cú đầu).
func apply_hit_effects(mods: CombatFormulas.HitModifiers, dealt: Dictionary, now: float, from_eid := 0, poison_tick := -1) -> void:
	if mods == null or dead:
		return
	if int(dealt.get(CombatFormulas.DamageType.COLD, 0)) > 0 and mods.freeze_frames > 0:
		slow_until = maxf(slow_until, now + SkillDefinition.frames_to_seconds(_reduce(mods.freeze_frames, stats.freeze_time_reduce_p)))
	var poison := int(dealt.get(CombatFormulas.DamageType.POISON, 0))
	if poison > 0 and mods.poison_time_frames > 0:
		## Như StatusEffectController.apply_vltk_hit: nhịp rút không tương khắc, không chí mạng.
		if poison_tick >= 0:
			poison = poison_tick
		elif mods.is_deadly_strike:
			poison = maxi(1, int(poison / CombatFormulas.DEADLY_STRIKE_MULTIPLIER))
		var frames := StatusEffectController._reduce_frames(mods.poison_time_frames, stats.poison_time_reduce_p)
		if frames > 0 and poison > 0:
			_add_poison(poison, frames, maxi(1, mods.poison_interval_frames), now, from_eid)
	if mods.stun_chance_p > 0 and mods.stun_frames > 0 and now >= stun_until and randi_range(1, 100) <= mods.stun_chance_p:
		stun_until = now + SkillDefinition.frames_to_seconds(_reduce(mods.stun_frames, stats.stun_time_reduce_p))
		move_dest = Vector2.INF
	if mods.state_source_id != "":
		add_state(mods.state_source_id, mods.state_attribs, mods.state_seconds, now, true)

## Trúng độc — KNpc::ReceiveDamage gốc: chưa dính thì nhận lớp mới; đang dính thì GỘP 2 lớp (lượng rút mỗi nhịp cộng dồn,
## thời gian trung bình có trọng số) — dính càng lâu, trúng càng nhiều thì nhịp rút càng to.
func _add_poison(damage: int, frames: int, interval: int, now: float, from_eid: int) -> void:
	if from_eid != 0:
		_poison_from = from_eid
	if _poison.is_empty():
		_poison = {"d": damage, "t": frames, "c": interval, "acc": 0.0, "last": now}
		return
	var mixed := SectSkillController._mix_poison(Vector3i(int(_poison.d), int(_poison.t), int(_poison.c)),
			Vector3i(damage, frames, interval))
	_poison.d = mixed.x
	_poison.t = mixed.y
	_poison.c = maxi(1, mixed.z)

## Nhịp độc — KNpc::Activate gốc: mỗi frame game (18/giây) nTime--, nTime chia hết cho nhịp thì rút, về 0 thì hết độc.
func _tick_poison(now: float) -> void:
	var acc := float(_poison.acc) + maxf(0.0, now - float(_poison.last)) * SkillDefinition.VLTK_GAME_FPS
	_poison.last = now
	while acc >= 1.0 and int(_poison.t) > 0:
		acc -= 1.0
		_poison.t = int(_poison.t) - 1
		if int(_poison.t) % int(_poison.c) == 0:
			lose_hp(float(_poison.d), now, _poison_from, "")
			if _poison.is_empty():   ## chết vì độc: die() đã xoá
				return
	_poison.acc = acc
	if int(_poison.t) <= 0:
		_poison = {}

static func _reduce(frames: int, reduce_p: int) -> int:
	return maxi(0, frames * (100 - clampi(reduce_p, -100, 95)) / 100)

func _tick_states(now: float) -> void:
	var changed := false
	for sid in states.keys():
		if float(states[sid].until) <= now:
			states.erase(sid)
			changed = true
	if changed:
		refresh_stats()
	if not _poison.is_empty():
		_tick_poison(now)

func free_resources() -> void:
	if skill_ctl != null:
		skill_ctl.free()
		skill_ctl = null

# ------------------------------------------------------------------ máu / chết

func _sync_hp() -> void:
	var p := clampi(roundi(cur_hp / max_hp * 100.0), 0, 100)
	if p == 0 and cur_hp > 0.0:
		p = 1
	if p != hp:
		hp = p
		touch()

func hp_ratio() -> float:
	return cur_hp / max_hp

func is_jumping(now: float) -> bool:
	return now < jump_until

## Trừ máu. true = vừa chết.
func lose_hp(amount: float, now: float, from_eid := 0, from_name := "") -> bool:
	if dead or amount <= 0.0 or is_jumping(now):   ## đang bay trên không: miễn sát thương như người chơi
		return false
	if from_eid != 0:
		last_hitter_eid = from_eid
		last_hitter_name = from_name
	cur_hp = maxf(0.0, cur_hp - amount)
	tally.taken += int(amount)
	sitting = false
	_sync_hp()
	if cur_hp <= 0.0:
		die(now)
		return true
	return false

func heal(amount: float) -> void:
	if dead:
		return
	cur_hp = minf(max_hp, cur_hp + amount)
	_sync_hp()

func die(now: float) -> void:
	dead = true
	died_at = now
	cur_hp = 0.0
	move_dest = Vector2.INF
	jump_until = 0.0
	potion_until = 0.0
	sitting = false
	stun_until = 0.0
	slow_until = 0.0
	_poison = {}
	if not states.is_empty():
		states.clear()
		refresh_stats()
	flags |= NetProto.FLAG_DEAD
	flags &= ~NetProto.FLAG_JUMPING
	action = NetProto.action_index("die")
	z = 0
	_sync_hp()
	touch()

## Sống lại đầy máu / nội lực tại `at`.
func revive(at: Vector2, now: float) -> void:
	dead = false
	cur_hp = max_hp
	mana = max_mana
	pos = at
	move_dest = Vector2.INF
	flags &= ~NetProto.FLAG_DEAD
	action = NetProto.action_index("stand")
	ready_at.clear()
	action_until = now
	_sync_hp()
	touch()

# ------------------------------------------------------------------ thuốc

func potion_count() -> int:
	var n := 0
	for it in profile.inventory:
		if it != null and it.misc_id == LonXonRules.POTION_ID:
			n += it.count
	return n

## Uống 1 bình (hồi dần POTION_HEAL_SEC giây). false = không có / đang hồi / thuốc trước còn chạy.
func drink_potion(now: float) -> bool:
	if dead or now < _potion_ready or now < potion_until:
		return false
	for i in profile.inventory.size():
		var it: ItemInstance = profile.inventory[i]
		if it != null and it.misc_id == LonXonRules.POTION_ID and it.count > 0:
			it.count -= 1
			if it.count <= 0:
				profile.inventory.remove_at(i)
			_potion_rate = max_hp * POTION_HEAL_P / POTION_HEAL_SEC
			potion_until = now + POTION_HEAL_SEC
			_potion_ready = now + POTION_COOLDOWN
			tally.potions += 1
			return true
	return false

# ------------------------------------------------------------------ chiêu

func skill_ready(sk: SkillDefinition, now: float) -> bool:
	return sk != null and not dead and not is_stunned(now) and now >= action_until and now >= float(ready_at.get(sk.id, 0.0)) \
		and mana >= _mana_cost(sk)

func _mana_cost(sk: SkillDefinition) -> float:
	return maxf(0.0, sk.mana_cost)

func skill_level(sk: SkillDefinition) -> int:
	return maxi(1, profile.get_skill_level(sk.id))

## Tầm thi triển (px) — như Player.get_skill_radius.
func skill_range(sk: SkillDefinition) -> float:
	if sk == null:
		return 60.0
	var r := sk.get_attack_radius_at_level(skill_level(sk))
	if r <= 0.0:
		r = sk.range if sk.range > 0.0 else 60.0
	return r

## Bắt đầu ra chiêu: trừ nội lực, đặt hồi chiêu + khoá động tác, quay mặt, động tác đánh.
func begin_cast(sk: SkillDefinition, aim: Vector2, now: float) -> void:
	mana = maxf(0.0, mana - _mana_cost(sk))
	tally.casts += 1
	var cd := sk.get_cooldown_at_level(skill_level(sk))
	ready_at[sk.id] = now + maxf(cd, ACTION_LOCK_SEC)
	action_until = now + ACTION_LOCK_SEC
	face(aim - pos)
	action = NetProto.action_index("attack" if sk.is_physical() else "cast")
	move_dest = Vector2.INF
	sitting = false
	touch()

# ------------------------------------------------------------------ đi / nhảy

func face(v: Vector2) -> void:
	if v == Vector2.ZERO:
		return
	var d := wrapi(roundi((rad_to_deg(v.angle()) - 90.0) / 45.0), 0, 8)
	if d != dir:
		dir = d
		touch()

func go_to(feet: Vector2) -> void:
	move_dest = feet

func stop() -> void:
	move_dest = Vector2.INF

## Nhảy (khinh công) theo hướng `to` — bay JUMP_SEC giây, qua được ô nhảy được, miễn sát thương lúc bay.
func jump_toward(to: Vector2, now: float) -> bool:
	if dead or now < _jump_ready or is_jumping(now) or is_stunned(now) or to == pos:
		return false
	_jump_dir = (to - pos).normalized()
	jump_until = now + JUMP_SEC
	_jump_ready = jump_until + JUMP_COOLDOWN
	tally.jumps += 1
	flags |= NetProto.FLAG_JUMPING
	action = NetProto.action_index("jump")
	face(_jump_dir)
	touch()
	return true

## 1 nhịp thân: thuốc, nội lực, nhảy / đi. Trả về true nếu vị trí đổi (GameServer cập nhật AOI).
func tick_body(grid: MapGrid, now: float, dt: float) -> bool:
	now_cache = now
	if dead:
		return false
	_tick_states(now)
	if dead:
		return false
	if now < potion_until:
		heal(_potion_rate * dt)
	mana = minf(max_mana, mana + max_mana * MANA_REGEN_P * dt * (3.0 if sitting else 1.0))
	if sitting:
		heal(max_hp * SIT_REGEN_P * dt)
		if move_dest != Vector2.INF or is_jumping(now):
			sitting = false
	var old := pos
	if is_stunned(now):
		if action != NetProto.action_index("hurt"):
			action = NetProto.action_index("hurt")
			touch()
		return false
	var spd := speed * (SLOW_FACTOR if now < slow_until else 1.0)
	if is_jumping(now):
		var left := jump_until - now
		var t := 1.0 - left / JUMP_SEC
		z = int(sin(t * PI) * 60.0)
		var next := pos + _jump_dir * JUMP_SPEED * dt
		if grid == null or (grid.in_bounds(next) and (not grid.is_blocked(next) or grid.is_jumpable(next))):
			pos = next
		touch()
	elif z != 0 or (flags & NetProto.FLAG_JUMPING) != 0:
		z = 0
		flags &= ~NetProto.FLAG_JUMPING
		## đáp xuống ô chặn (nhảy qua chưa hết): lùi về ô trống gần nhất
		if grid != null and grid.is_blocked(pos):
			var safe := grid.free_near(pos)
			if safe != Vector2.ZERO:
				pos = safe
		action = NetProto.action_index("stand")
		touch()
	elif move_dest != Vector2.INF and now >= action_until:
		var to := move_dest - pos
		var step := spd * dt
		if to.length() <= maxf(step, 4.0):
			pos = move_dest if grid == null or not grid.is_blocked(move_dest) else pos
			move_dest = Vector2.INF
			action = NetProto.action_index("stand")
		else:
			var next := pos + to.normalized() * step
			if grid != null and grid.is_blocked(next):
				## trượt theo trục / né chéo khi vướng (như quái server)
				var tried := false
				for alt in [Vector2(next.x, pos.y), Vector2(pos.x, next.y), pos + to.normalized().rotated(0.7) * step, pos + to.normalized().rotated(-0.7) * step]:
					if not grid.is_blocked(alt):
						next = alt
						tried = true
						break
				if not tried:
					move_dest = Vector2.INF
					action = NetProto.action_index("stand")
					touch()
					return false
			face(next - pos)
			pos = next
			action = NetProto.action_index("run")
		touch()
	elif sitting:
		if action != NetProto.action_index("sit"):
			action = NetProto.action_index("sit")
			touch()
	elif now >= action_until and action != NetProto.action_index("stand"):
		action = NetProto.action_index("stand")
		touch()
	if pos != old:
		has_moved = true
		return true
	return false

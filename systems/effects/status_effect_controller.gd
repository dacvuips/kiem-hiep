extends Node
class_name StatusEffectController
## Component gắn làm con của Enemy/Player để quản lý các StatusEffect đang áp lên nó.
## Add vào scene: EnemyBase/Player thêm 1 node con StatusEffectController, rồi gọi
## apply_effect() từ nơi xử lý va chạm (Projectile._hit, PartnerBase attack...).

signal effect_applied(effect_id: String)
signal effect_expired(effect_id: String)
## Bộ trạng thái thuộc tính (buff/bùa) vừa thêm/hết hạn — chủ (Player/Enemy) nghe signal này để dựng
## lại combat_stats bằng CombatantStats.build(..., get_state_attrib_sources()).
signal stats_changed

var _active_effects: Dictionary = {}  ## effect_id -> StatusEffect
## Trạng thái THUỘC TÍNH (m_StateSkillList gốc) — source_id (VD id skill buff) -> {"attribs":
## {tên VLTK: Vector3i}, "time": giây còn lại}. Cùng nguồn áp lại thì làm mới thời gian, không cộng dồn.
var _states: Dictionary = {}
## Hồi máu theo lifereplenish — gốc cộng mỗi GAME_UPDATE_TIME (10 frame) khi KHÔNG bị choáng.
const REPLENISH_INTERVAL := 10.0 / 18.0
var _replenish_timer: float = 0.0

## Multiplier tốc độ di chuyển tổng hợp từ mọi effect đang active (slow/freeze) — entity
## chủ sở hữu đọc giá trị này mỗi frame để nhân vào velocity, thay vì tự quản lý riêng lẻ.
var move_speed_multiplier: float = 1.0
var is_stunned: bool = false

func _physics_process(delta: float) -> void:
	if _tint_color != Color.WHITE:
		_apply_tint(false)   ## giữ màu nhuộm sau khi hết nhấp nháy đỏ
	_tick_states(delta)
	_tick_replenish(delta)
	if _active_effects.is_empty():
		return
	var target := get_parent()
	var expired_ids := []
	for effect_id in _active_effects.keys():
		var effect: StatusEffect = _active_effects[effect_id]
		if effect.tick(delta, target):
			expired_ids.append(effect_id)
	for effect_id in expired_ids:
		_active_effects.erase(effect_id)
		effect_expired.emit(effect_id)
	_recalculate_derived_state()

func apply_effect(effect: StatusEffect) -> void:
	if _active_effects.has(effect.effect_id):
		var existing: StatusEffect = _active_effects[effect.effect_id]
		existing.refresh(effect.duration, effect.damage_per_tick, effect.magnitude)
	else:
		_active_effects[effect.effect_id] = effect
		effect_applied.emit(effect.effect_id)
	_recalculate_derived_state()

## Tăng tốc độ chạy tạm thời (Phi Tốc Đan, buff chiêu thức...)
func apply_speed_buff(percent: float, duration: float) -> void:
	if duration <= 0.0 or percent <= 0.0:
		return
	apply_effect(StatusEffect.new("speed_buff", duration, 0.0, 1.0, percent))

## Làm chậm của Băng sát: VLTK bỏ qua 1/2 số frame hành động (m_FreezeState, `nTime & 1`) = chậm 50%.
const VLTK_FREEZE_SLOW := 0.5

## Hiệu ứng khi TRÚNG 1 đòn skill — NGUYÊN VĂN KNpc::ReceiveDamage gốc:
##   - Băng sát gây được damage + đang KHÔNG bị chậm -> làm chậm freeze_frames (đang chậm thì không làm mới).
##   - Độc sát gây được damage -> trúng độc: mỗi poison_interval rút đúng lượng Độc sát vừa gây; đang
##     trúng độc thì GỘP 2 lớp độc theo công thức gốc (damage/thời gian/nhịp trung bình có trọng số).
##   - Choáng: roll stun_chance_p % (chỉ khi đang không bị choáng), độc lập với damage.
## Thời gian mỗi hiệu ứng trừ % giảm của CHÍNH bên bị trúng (`defender`), tối đa MAX_RESIST %.
## `dealt` = damage thực từng loại của đòn (CombatFormulas.resolve_multi_damage out_dealt).
func apply_vltk_hit(mods: CombatFormulas.HitModifiers, dealt: Dictionary, defender: CombatantStats) -> void:
	if mods == null:
		return
	if dealt.get(CombatFormulas.DamageType.COLD, 0) > 0 and mods.freeze_frames > 0 and not has_effect("freeze"):
		var frames := _reduce_frames(mods.freeze_frames, defender.freeze_time_reduce_p)
		if frames > 0:
			apply_effect(StatusEffect.new("freeze", SkillDefinition.frames_to_seconds(frames), 0.0, 1.0, VLTK_FREEZE_SLOW))

	var poison_damage: int = dealt.get(CombatFormulas.DamageType.POISON, 0)
	if poison_damage > 0 and mods.poison_time_frames > 0:
		## Lượng rút mỗi lần không nhân chí mạng (CalcDamage lúc tick độc gốc truyền bIsDS = FALSE).
		if mods.poison_tick_damage > 0:
			poison_damage = mods.poison_tick_damage   ## gốc: m_PoisonState.nValue[0] = damage khai báo của skill
		elif mods.is_deadly_strike:
			poison_damage = maxi(1, int(poison_damage / CombatFormulas.DEADLY_STRIKE_MULTIPLIER))
		var time_frames := _reduce_frames(mods.poison_time_frames, defender.poison_time_reduce_p)
		if time_frames > 0:
			_apply_vltk_poison(poison_damage, time_frames, maxi(1, mods.poison_interval_frames))

	if mods.stun_chance_p > 0 and mods.stun_frames > 0 and not is_stunned and randi_range(1, 100) <= mods.stun_chance_p:
		var stun_frames := _reduce_frames(mods.stun_frames, defender.stun_time_reduce_p)
		if stun_frames > 0:
			apply_effect(StatusEffect.new("stun", SkillDefinition.frames_to_seconds(stun_frames)))

static func _reduce_frames(frames: int, reduce_p: int) -> int:
	## Gốc: `if (nRdc >= MAX_PERCENT) nRdc = MAX_RESIST;` — giảm tối đa MAX_RESIST %, âm thì kéo dài.
	var rdc := CombatFormulas.MAX_RESIST if reduce_p >= 100 else reduce_p
	return frames - frames * rdc / 100

func _apply_vltk_poison(damage: int, time_frames: int, interval_frames: int) -> void:
	var fps := SkillDefinition.VLTK_GAME_FPS
	if not _active_effects.has("poison"):
		var effect := StatusEffect.new("poison", time_frames / fps, float(damage), interval_frames / fps)
		effect.frame_mode = true
		effect.frames_left = time_frames
		effect.interval_frames = interval_frames
		apply_effect(effect)
		return
	## Gộp 2 lớp độc — KNpc::ReceiveDamage (nhánh m_PoisonState.nTime > 0):
	##   d = ((c1+c2)·d1/c1 + (c1+c2)·d2/c2) / 2;  t = (t1·d1·c2 + t2·d2·c1) / (d1·c2 + d2·c1);  c = (c1+c2)/2
	var existing: StatusEffect = _active_effects["poison"]
	var d1 := int(existing.damage_per_tick)
	var t1 := existing.frames_left
	var c1 := existing.interval_frames
	var d2 := damage
	var t2 := time_frames
	var c2 := interval_frames
	if c1 <= 0 or d1 <= 0:
		_active_effects.erase("poison")
		_apply_vltk_poison(damage, time_frames, interval_frames)
		return
	existing.damage_per_tick = float(((c1 + c2) * d1 / c1 + (c1 + c2) * d2 / c2) / 2)
	existing.frames_left = (t1 * d1 * c2 + t2 * d2 * c1) / (d1 * c2 + d2 * c1)
	existing.time_remaining = float(existing.frames_left) / fps
	existing.duration = maxf(existing.duration, existing.time_remaining)
	existing.interval_frames = (c1 + c2) / 2
	existing.tick_rate = float(existing.interval_frames) / fps

## Áp 1 bộ trạng thái thuộc tính (buff lên mình / bùa lên địch) trong `seconds` giây.
## `meta` cho phần hiển thị (StateVisuals): {"icon": Texture2D, "name": String, "is_debuff": bool}.
func apply_state(source_id: String, attribs: Dictionary, seconds: float, meta: Dictionary = {}) -> void:
	if attribs.is_empty() or seconds <= 0.0:
		return
	_states[source_id] = {"attribs": attribs, "time": seconds, "duration": seconds, "meta": meta}
	_ensure_visuals()
	stats_changed.emit()

## Trạng thái đang dính cho phần hiển thị: [{"meta", "time", "duration"}, ...].
func get_state_display_list() -> Array:
	var out := []
	for source_id in _states:
		var st: Dictionary = _states[source_id]
		out.append({"meta": st["meta"], "time": st["time"], "duration": st["duration"]})
	return out

var _visuals: StateVisuals

func _ensure_visuals() -> void:
	if _visuals != null and is_instance_valid(_visuals):
		return
	var owner_node := get_parent()
	if owner_node is Node2D:
		_visuals = StateVisuals.new()
		_visuals.controller = self
		owner_node.add_child(_visuals)

func has_state(source_id: String) -> bool:
	return _states.has(source_id)

## Nguồn thuộc tính của mọi trạng thái đang dính — đưa vào CombatantStats.build().
func get_state_attrib_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for source_id in _states:
		out.append(_states[source_id]["attribs"])
	return out

func _tick_states(delta: float) -> void:
	if _states.is_empty():
		return
	var expired := []
	for source_id in _states:
		_states[source_id]["time"] -= delta
		if _states[source_id]["time"] <= 0.0:
			expired.append(source_id)
	for source_id in expired:
		_states.erase(source_id)
	if not expired.is_empty():
		stats_changed.emit()

func _tick_replenish(delta: float) -> void:
	var owner_node := get_parent()
	if owner_node == null or not ("combat_stats" in owner_node) or owner_node.combat_stats == null:
		return
	var stats: CombatantStats = owner_node.combat_stats
	if stats.life_replenish == 0:
		return
	_replenish_timer += delta
	while _replenish_timer >= REPLENISH_INTERVAL:
		_replenish_timer -= REPLENISH_INTERVAL
		if is_stunned:
			continue
		var amount := stats.life_replenish + stats.life_replenish * stats.life_replenish_p / 100.0
		## Hồi máu ÂM (bùa rút máu, VD Bắc Minh Đáo Hải) đi đường nhận damage để còn chết được.
		if amount < 0.0 and owner_node.has_method("take_status_damage"):
			owner_node.take_status_damage(-amount, "life_drain")
		elif amount > 0.0 and owner_node.has_method("heal"):
			owner_node.heal(amount)

func has_effect(effect_id: String) -> bool:
	return _active_effects.has(effect_id)

func clear_all() -> void:
	_active_effects.clear()
	var had_states := not _states.is_empty()
	_states.clear()
	_recalculate_derived_state()
	if had_states:
		stats_changed.emit()

## Hình báo trạng thái trúng đòn (giống VLTK gốc, dùng chung người chơi/quái/NPC):
##   - Độc sát (poison)    : nhân vật nhuộm XANH LÁ ĐẬM suốt lúc còn độc.
##   - Băng sát (freeze)   : nhân vật nhuộm VÀNG (và bị làm chậm).
##   - Lôi sát (stun)      : VÒNG TRÒN quay trên đầu (StunRing), đứng yên tại chỗ — không nhuộm màu.
## Nhuộm bằng `modulate` của node hình ảnh chủ (Avatar / MonsterSprite / Sprite) rồi giữ lại mỗi frame (không đè lúc nhấp nháy đỏ khi bị đánh).
const TINT_FREEZE := Color(1.0, 0.92, 0.3)
const TINT_POISON := Color(0.3, 0.72, 0.3)

var _tint_target: CanvasItem
var _tint_color := Color.WHITE
const StunRingScript := preload("res://systems/effects/stun_ring.gd")
var _stun_ring: Node2D

func _find_tint_target() -> CanvasItem:
	var owner_node := get_parent()
	if owner_node == null:
		return null
	for prop in ["avatar", "_sprite"]:
		var v: Variant = owner_node.get(prop)
		if v is CanvasItem:
			return v
	var sprite: CanvasItem = owner_node.get_node_or_null("Sprite")
	if sprite == null:
		sprite = owner_node.get_node_or_null("Sprite2D")
	return sprite

func _update_tint() -> void:
	if _tint_target == null or not is_instance_valid(_tint_target):
		_tint_target = _find_tint_target()
	var tint := Color.WHITE
	if _active_effects.has("freeze") or _active_effects.has("slow"):
		tint = TINT_FREEZE
	elif _active_effects.has("poison"):
		tint = TINT_POISON
	var changed := tint != _tint_color
	_tint_color = tint
	_apply_tint(changed)
	## Vòng choáng trên đầu.
	var owner_node := get_parent()
	if is_stunned and owner_node is Node2D:
		if _stun_ring == null or not is_instance_valid(_stun_ring):
			_stun_ring = StunRingScript.new()
			owner_node.add_child(_stun_ring)
	elif _stun_ring != null:
		if is_instance_valid(_stun_ring):
			_stun_ring.queue_free()
		_stun_ring = null

## Đặt màu nhuộm lên node hình ảnh; chỉ ghi khi màu hiện tại là trắng hoặc đúng màu ta đã ghi lần trước (đang nhấp nháy đỏ thì để yên).
var _applied_color := Color.WHITE

static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01

func _apply_tint(_force: bool = false) -> void:
	if _tint_target == null or not is_instance_valid(_tint_target):
		return
	var cur := _tint_target.modulate
	if _same_rgb(cur, _tint_color):
		_applied_color = _tint_color
		return
	if _same_rgb(cur, Color.WHITE) or _same_rgb(cur, _applied_color):
		_tint_target.modulate = Color(_tint_color.r, _tint_color.g, _tint_color.b, cur.a)
		_applied_color = _tint_color

func _recalculate_derived_state() -> void:
	move_speed_multiplier = 1.0
	is_stunned = false
	for effect_id in _active_effects.keys():
		var effect: StatusEffect = _active_effects[effect_id]
		match effect_id:
			"slow":
				move_speed_multiplier *= (1.0 - effect.magnitude)
			"freeze":
				move_speed_multiplier *= (1.0 - effect.magnitude)
			"speed_buff":
				move_speed_multiplier *= (1.0 + effect.magnitude)
			"stun":
				is_stunned = true
	_update_tint()

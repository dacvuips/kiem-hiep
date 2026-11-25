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
## Vừa áp 1 trạng thái (buff/bùa) — quái online nghe để báo bùa lên server cho người khác thấy hình.
signal state_applied(source_id: String, seconds: float, meta: Dictionary)
## 1 trạng thái (buff/bùa) vừa hết hạn thời gian duy trì — người nghe (Player/SectSkillController) xử lý cơ chế kích hoạt khi hết buff.
signal state_expired(source_id: String, meta: Dictionary)

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
var is_confused: bool = false

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
	if effect.effect_id in ["freeze", "slow", "poison", "stun"]:
		var owner_node := get_parent()
		var cstats = owner_node.get("combat_stats") if owner_node else null
		if cstats != null and "ignore_negative_state_p" in cstats and int(cstats.ignore_negative_state_p) >= 100:
			return
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
## `poison_tick` = lượng rút mỗi nhịp đã tính theo gốc (CombatFormulas.poison_tick_damage: không tương khắc, không chí mạng);
## -1 = không có, lấy theo damage Độc thực của cú đánh đầu (cách cũ).
func apply_vltk_hit(mods: CombatFormulas.HitModifiers, dealt: Dictionary, defender: CombatantStats, poison_tick: int = -1) -> void:
	if mods == null:
		return
	if defender != null and defender.ignore_negative_state_p >= 100:
		return
	if dealt.get(CombatFormulas.DamageType.COLD, 0) > 0 and mods.freeze_frames > 0 and not has_effect("freeze"):
		var frames := _reduce_frames(mods.freeze_frames, defender.freeze_time_reduce_p)
		if frames > 0:
			apply_effect(StatusEffect.new("freeze", SkillDefinition.frames_to_seconds(frames), 0.0, 1.0, VLTK_FREEZE_SLOW))

	var poison_damage: int = dealt.get(CombatFormulas.DamageType.POISON, 0)
	if poison_damage > 0 and mods.poison_time_frames > 0:
		## Lượng rút mỗi lần lấy theo damage thực tế sau khi đã trừ Kháng Độc và Tương Khắc Ngũ Hành.
		## Không nhân chí mạng ở nhịp rút (KNpc::Activate tick độc gốc gọi CalcDamage với bIsDS = FALSE).
		if poison_tick >= 0:
			poison_damage = poison_tick
		elif mods.is_deadly_strike:
			poison_damage = maxi(1, int(poison_damage / CombatFormulas.DEADLY_STRIKE_MULTIPLIER))
		var time_frames := _reduce_frames(mods.poison_time_frames, defender.poison_time_reduce_p)
		if time_frames > 0 and poison_damage > 0:
			_apply_vltk_poison(poison_damage, time_frames, maxi(1, mods.poison_interval_frames), mods.attacker_node)

	if mods.stun_chance_p > 0 and mods.stun_frames > 0 and not is_stunned and randi_range(1, 100) <= mods.stun_chance_p:
		var stun_frames := _reduce_frames(mods.stun_frames, defender.stun_time_reduce_p)
		if stun_frames > 0:
			var stun_sec := SkillDefinition.frames_to_seconds(stun_frames)
			apply_effect(StatusEffect.new("stun", stun_sec))
			apply_state("debuff_stun", {}, stun_sec, {"state_id": 50, "name": "Choáng", "is_debuff": true})

static func _reduce_frames(frames: int, reduce_p: int) -> int:
	## Gốc: `if (nRdc >= MAX_PERCENT) nRdc = MAX_RESIST;` — giảm tối đa MAX_RESIST %, âm thì kéo dài.
	var rdc := CombatFormulas.MAX_RESIST if reduce_p >= 100 else reduce_p
	return frames - frames * rdc / 100

func _apply_vltk_poison(damage: int, time_frames: int, interval_frames: int, attacker_node: Node = null) -> void:
	var fps := SkillDefinition.VLTK_GAME_FPS
	if not _active_effects.has("poison"):
		var effect := StatusEffect.new("poison", time_frames / fps, float(damage), interval_frames / fps)
		effect.frame_mode = true
		effect.frames_left = time_frames
		effect.interval_frames = interval_frames
		effect.tick_counter = StatusEffect.first_tick_in(time_frames, interval_frames)
		effect.attacker_node = attacker_node
		apply_effect(effect)
		return
	var existing: StatusEffect = _active_effects["poison"]
	if attacker_node != null:
		existing.attacker_node = attacker_node
	if existing.interval_frames <= 0 or int(existing.damage_per_tick) <= 0:
		_active_effects.erase("poison")
		_apply_vltk_poison(damage, time_frames, interval_frames, attacker_node)
		return
	var merged := merge_poison(Vector3i(int(existing.damage_per_tick), existing.frames_left, existing.interval_frames),
			Vector3i(damage, time_frames, interval_frames))
	existing.damage_per_tick = float(merged.x)
	existing.frames_left = merged.y
	existing.time_remaining = float(existing.frames_left) / fps
	existing.duration = maxf(existing.duration, existing.time_remaining)
	existing.interval_frames = merged.z
	existing.tick_counter = mini(existing.tick_counter, merged.z)   ## nhịp ngắn lại thì rút sớm hơn, không đợi nhịp cũ
	existing.tick_rate = float(existing.interval_frames) / fps

## Gộp lớp độc mới {d, t, c} vào lớp đang dính (dùng chung máy người chơi + bot server):
##   - Lượng rút mỗi nhịp và nhịp: như KNpc::ReceiveDamage gốc — d = ((c1+c2)·d1/c1 + (c1+c2)·d2/c2) / 2 (cùng nhịp = cộng dồn),
##     c = (c1+c2)/2.
##   - Thời gian: KHÁC gốc (cân bằng riêng của game) — lấy lớp CÒN DÀI HƠN, max(t1, t2). Gốc lấy trung bình có trọng số theo
##     lượng độc nên chồng độc càng to thì thời gian càng ngắn rồi mất trắng (tụt từ hàng nghìn về vài trăm). Giờ còn trúng độc
##     là còn giữ chuỗi; ngừng trúng độc thì hết sau thời gian của lớp cuối.
##   - Trần: vì thời gian không còn ngắn lại, đánh liên tục thì chồng độc cộng mãi (đã thấy 500 triệu/nhịp lên boss). Lượng rút
##     tối đa POISON_STACK_MAX lần 1 lớp (lớp đang dính đã to hơn thì giữ nguyên, không tăng). Server online chặn mỗi đòn ở
##     ProfileGuard.max_hit (= đòn to nhất x CRIT_MULT x TOLERANCE) nên trần này phải <= đó, không thì máy mình trừ máu quái về 0
##     mà server chỉ trừ phần trong trần -> quái "hết máu" mà không chết.
## Chia nguyên CỐ Ý như gốc.
const POISON_STACK_MAX := 3

@warning_ignore("integer_division")
static func merge_poison(cur: Vector3i, add: Vector3i) -> Vector3i:
	var c1 := maxi(1, cur.z)
	var c2 := maxi(1, add.z)
	var d := ((c1 + c2) * cur.x / c1 + (c1 + c2) * add.x / c2) / 2
	d = mini(d, maxi(cur.x, add.x * POISON_STACK_MAX))
	return Vector3i(d, maxi(cur.y, add.y), maxi(1, (c1 + c2) / 2))

## Áp 1 bộ trạng thái thuộc tính (buff lên mình / bùa lên địch) trong `seconds` giây.
## `meta` cho phần hiển thị (StateVisuals): {"icon": Texture2D, "name": String, "is_debuff": bool, "state_id": int}.
func apply_state(source_id: String, attribs: Dictionary, seconds: float, meta: Dictionary = {}, total_duration: float = -1.0) -> void:
	if (attribs.is_empty() and int(meta.get("state_id", 0)) <= 0) or seconds <= 0.0:
		return
	if meta.get("is_debuff", false) == true or source_id.begins_with("debuff_"):
		var owner_node := get_parent()
		var cstats = owner_node.get("combat_stats") if owner_node else null
		if cstats != null and "ignore_negative_state_p" in cstats and int(cstats.ignore_negative_state_p) >= 100:
			return
	var dur := total_duration if total_duration > 0.0 else seconds
	_states[source_id] = {"attribs": attribs, "time": seconds, "duration": maxf(dur, seconds), "meta": meta}
	_sync_profile_state(source_id, _states[source_id])
	_ensure_visuals()
	_update_confused_status()
	stats_changed.emit()
	state_applied.emit(source_id, seconds, meta)

func _sync_profile_state(source_id: String, st: Dictionary) -> void:
	if not (source_id.begins_with("item:") or ((st.get("meta", {}) as Dictionary).get("persist", false) == true)):
		return
	var owner_node := get_parent()
	if owner_node == null or not owner_node.is_in_group("player"):
		return
	var prof := GameManager.local_profile if GameManager != null else null
	if prof == null:
		return
	prof.set_active_state(source_id, st["attribs"], float(st["time"]), float(st["duration"]), st["meta"])

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

func get_state(source_id: String) -> Dictionary:
	return _states.get(source_id, {})

## ẨN THÂN (thuộc tính "hide" gốc — KNpcAttribModify::Hide đặt m_HideState.nTime): có trạng thái mang "hide" còn chạy.
func is_hidden() -> bool:
	for source_id in _states:
		if (_states[source_id]["attribs"] as Dictionary).has("hide"):
			return true
	return false

## KNpc::DoSkill gốc: thi triển võ công -> `m_HideState.nTime = 0` (hiện hình). Trả về true nếu vừa bỏ ẩn thân.
func break_hide() -> bool:
	var gone := []
	for source_id in _states:
		if (_states[source_id]["attribs"] as Dictionary).has("hide"):
			gone.append(source_id)
	if gone.is_empty():
		return false
	var owner_node := get_parent()
	var prof: PlayerProfile = GameManager.local_profile if (owner_node != null and owner_node.is_in_group("player") and GameManager != null) else null
	for source_id in gone:
		_states.erase(source_id)
		if prof != null:
			prof.remove_active_state(source_id)
	stats_changed.emit()
	return true

## Nguồn thuộc tính của mọi trạng thái đang dính — đưa vào CombatantStats.build().
func get_state_attrib_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for source_id in _states:
		out.append(_states[source_id]["attribs"])
	return out

func _tick_states(delta: float) -> void:
	if _states.is_empty():
		return
	var owner_node := get_parent()
	var prof: PlayerProfile = GameManager.local_profile if (owner_node != null and owner_node.is_in_group("player") and GameManager != null) else null
	var expired := []
	for source_id in _states:
		_states[source_id]["time"] -= delta
		var rem := float(_states[source_id]["time"])
		if rem <= 0.0:
			expired.append(source_id)
		elif prof != null and (source_id.begins_with("item:") or ((_states[source_id].get("meta", {}) as Dictionary).get("persist", false) == true)):
			for pst in prof.active_states:
				if pst is Dictionary and str(pst.get("source_id", "")) == source_id:
					pst["time"] = rem
					break
	for source_id in expired:
		var st_meta: Dictionary = _states[source_id].get("meta", {}) if _states.has(source_id) else {}
		_states.erase(source_id)
		if prof != null:
			prof.remove_active_state(source_id)
		state_expired.emit(source_id, st_meta)
	if not expired.is_empty():
		_update_confused_status()
		stats_changed.emit()

func _tick_replenish(delta: float) -> void:
	var owner_node := get_parent()
	if owner_node == null or not ("combat_stats" in owner_node) or owner_node.combat_stats == null:
		return
	var stats: CombatantStats = owner_node.combat_stats
	if stats.life_replenish == 0 and stats.mana_replenish == 0:
		return
	_replenish_timer += delta
	while _replenish_timer >= REPLENISH_INTERVAL:
		_replenish_timer -= REPLENISH_INTERVAL
		if is_stunned:
			continue
		if stats.life_replenish != 0:
			var amount := stats.life_replenish + stats.life_replenish * stats.life_replenish_p / 100.0
			## Hồi máu ÂM (bùa rút máu, VD Bắc Minh Đáo Hải) đi đường nhận damage để còn chết được.
			if amount < 0.0 and owner_node.has_method("take_status_damage"):
				owner_node.take_status_damage(-amount, "life_drain")
			elif amount > 0.0 and owner_node.has_method("heal"):
				owner_node.heal(amount)
		if stats.mana_replenish != 0:
			var m_amount := stats.mana_replenish + stats.mana_replenish * stats.mana_replenish_p / 100.0
			if m_amount > 0.0 and owner_node.has_method("restore_mana"):
				owner_node.restore_mana(m_amount)

## Nhịp HÀNH ĐỘNG (động tác, thời điểm ra đòn, nhịp nghĩ của quái): KNpc::ProcessState gốc — đang Băng sát thì nhịp lẻ
## (`m_FreezeState.nTime & 1`) trả TRUE, KNpc::Activate return trước AI / lệnh / ProcStatus -> mọi việc chậm 1/2.
## (Tốc độ CHẠY đã giảm riêng qua move_speed_multiplier — đừng nhân thêm hệ số này vào bước đi.)
func action_time_scale() -> float:
	return 1.0 - VLTK_FREEZE_SLOW if _active_effects.has("freeze") else 1.0

func remove_effect(effect_id: String) -> void:
	if _active_effects.erase(effect_id):
		effect_expired.emit(effect_id)
		_recalculate_derived_state()

func has_effect(effect_id: String) -> bool:
	return _active_effects.has(effect_id)

func get_effect(effect_id: String) -> StatusEffect:
	return _active_effects.get(effect_id)

func clear_all() -> void:
	_active_effects.clear()
	var had_states := not _states.is_empty()
	_states.clear()
	_recalculate_derived_state()
	if had_states:
		stats_changed.emit()

## Hóa giải / xóa bỏ toàn bộ hiệu ứng tiêu cực (choáng, chậm, đóng băng, độc, debuff)
func cleanse_negative_effects() -> void:
	var cleared_effect := false
	for eid in ["freeze", "slow", "poison", "stun"]:
		if _active_effects.erase(eid):
			cleared_effect = true
			effect_expired.emit(eid)
	var expired_states := []
	for source_id in _states:
		var st: Dictionary = _states[source_id]
		var meta: Dictionary = st.get("meta", {})
		if meta.get("is_debuff", false) == true or source_id.begins_with("debuff_"):
			expired_states.append(source_id)
	for sid in expired_states:
		_states.erase(sid)
	if cleared_effect or not expired_states.is_empty():
		_recalculate_derived_state()
		_update_confused_status()
		stats_changed.emit()

func _update_confused_status() -> void:
	var confused := false
	for st in _states.values():
		var attribs: Dictionary = st.get("attribs", {})
		var meta: Dictionary = st.get("meta", {})
		if attribs.has("randmove") or int(meta.get("state_id", 0)) == 121:
			confused = true
			break
	is_confused = confused

## Hình báo trạng thái trúng đòn (giống VLTK gốc, dùng chung người chơi/quái/NPC):
##   - Độc sát (poison)    : nhân vật nhuộm XANH LÁ ĐẬM suốt lúc còn độc.
##   - Băng sát (freeze)   : nhân vật nhuộm VÀNG (và bị làm chậm) — KNpc gốc SetAdjustColorId(adjustcolor_freeze) = dòng 2
##     settings/AdjustColor.txt (R 250, G 255, B 0): nhân màu từng điểm ảnh với RGB/256 -> bỏ hẳn kênh lam.
##   - Lôi sát (stun)      : VÒNG SAO XOAY trên đầu (Status 50: mag_spe_眩晕) — không nhuộm màu.
## Nhuộm bằng `modulate` của node hình ảnh chủ (Avatar / MonsterSprite / Sprite) rồi giữ lại mỗi frame (không đè lúc nhấp nháy đỏ khi bị đánh).
const TINT_FREEZE := Color(250.0 / 256.0, 255.0 / 256.0, 0.0)
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
	## Hình có lớp nhuộm trạng thái riêng (CharacterAvatar / MonsterSprite): không tranh `modulate` với mặt nạ, nhấp nháy đỏ,
	## màu phe... — gốc cũng nhuộm riêng từng bộ phận (m_cDrawFile Color) chứ không đụng màu khác.
	if _tint_target.has_method("set_status_tint"):
		if not _same_rgb(_applied_color, _tint_color) or _force:
			_tint_target.set_status_tint(_tint_color)
			_applied_color = _tint_color
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

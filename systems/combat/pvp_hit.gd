class_name PvpHit
extends RefCounted
## Một đòn người chơi đánh người chơi (Cừu sát online) đi qua mạng: máy người đánh gói đúng các tham số mà
## take_damage_from nhận (chỉ số người đánh, sát thương min/max, loại, hệ, HitModifiers); server cắt theo trần sát thương rồi
## chuyển cho máy người bị đánh — máy đó gọi take_damage_from của chính nhân vật mình (né / kháng / giáp / hiệu ứng tính đúng
## như bị quái đánh). Đóng gói bằng var_to_bytes (không có Object) — giải gói luôn bằng bytes_to_var (không tạo Object).

const MAX_BYTES := 16384

## Mọi biến script kiểu dữ liệu thuần của `o` (bỏ Object như attacker_node).
static func _dump(o: Object) -> Dictionary:
	var d := {}
	for p in o.get_property_list():
		if (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var v: Variant = o.get(p.name)
		if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING, TYPE_DICTIONARY, TYPE_VECTOR2I, TYPE_ARRAY]:
			d[p.name] = v
	return d

## Chỉ nhận khoá có sẵn trên `o` và đúng kiểu.
static func _load(o: Object, d: Variant) -> void:
	if not d is Dictionary:
		return
	for k in d:
		if not k is String or not (k in o):
			continue
		var cur: Variant = o.get(k)
		if typeof(cur) == typeof(d[k]):
			o.set(k, d[k])

static func encode(attacker: CombatantStats, min_damage: int, max_damage: int, damage_type: int, element: int,
		mods: CombatFormulas.HitModifiers) -> PackedByteArray:
	var hit := {
		"as": _dump(attacker) if attacker else {},
		"min": min_damage, "max": max_damage, "type": damage_type, "el": element,
		"mods": _dump(mods) if mods else {},
	}
	return var_to_bytes(hit)

## {} nếu gói hỏng.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_BYTES:
		return {}
	var v: Variant = bytes_to_var(bytes)
	if not v is Dictionary:
		return {}
	var d: Dictionary = v
	for k in ["min", "max", "type", "el"]:
		if typeof(d.get(k)) != TYPE_INT:
			return {}
	if not d.get("as") is Dictionary or not d.get("mods") is Dictionary:
		return {}
	return d

## Server: cắt mọi phần sát thương theo trần `cap` của người đánh (ProfileGuard.max_hit).
static func sanitize(d: Dictionary, cap: float) -> void:
	var top := int(cap)
	d["min"] = clampi(int(d["min"]), 0, top)
	d["max"] = clampi(int(d["max"]), int(d["min"]), top)
	var mods: Dictionary = d["mods"]
	var extra: Variant = mods.get("extra_damages", {})
	if extra is Dictionary:
		for k in extra:
			var v: Variant = extra[k]
			extra[k] = Vector2i(clampi(v.x, 0, top), clampi(v.y, 0, top)) if v is Vector2i else Vector2i.ZERO
	mods["poison_tick_damage"] = clampi(int(mods.get("poison_tick_damage", 0)), 0, top)
	## Trạng thái (bùa) mang theo đòn: không cho thời gian vô lý.
	mods["state_seconds"] = clampf(float(mods.get("state_seconds", 0.0)), 0.0, 60.0)

## Máy người bị đánh: áp đòn lên nhân vật của mình.
static func apply(victim: Node, d: Dictionary, attacker_node: Node) -> void:
	if victim == null or not victim.has_method("take_damage_from"):
		return
	var attacker := CombatantStats.new()
	_load(attacker, d["as"])
	var mods := CombatFormulas.HitModifiers.new()
	_load(mods, d["mods"])
	mods.attacker_node = attacker_node
	victim.take_damage_from(attacker, int(d["min"]), int(d["max"]), int(d["type"]) as CombatFormulas.DamageType,
		int(d["el"]) as ElementTypes.ElementType, mods)

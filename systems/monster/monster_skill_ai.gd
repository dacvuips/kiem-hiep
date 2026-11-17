extends RefCounted
class_name MonsterSkillAi
## Chọn chiêu gần / xa cho quái — dùng chung cho VltkMonster (offline / client) và ServerMonster (online).
##
## Quy tắc:
##  1. Gặp mục tiêu lần đầu: nếu có chiêu đánh xa sẵn sàng và mục tiêu trong tầm -> mở màn bằng chiêu xa.
##  2. Sau đó quái áp sát và đánh gần (đánh thường) liên tục.
##  3. Mục tiêu chạy ra xa (quá far_distance) nhưng còn trong tầm chiêu xa -> đánh xa.
## Quái chỉ có chiêu xa (khỉ ném đá, rắn phun độc, Tật Vũ...) được thêm ô ảo BASIC_SLOT = "Công kích vật lý" (skill 53)
## để áp sát đánh thường.

const SLOT_COUNT := 5
const BASIC_SLOT := 4
const BASIC_SKILL := [53, 1]
const MELEE_RADIUS := 75.0
## Đứng trong cự ly này thì chỉ đánh gần.
const CLOSE_RANGE := 85.0

const APPROACH := -1  ## đi lại gần mục tiêu
const WAIT := -2      ## đứng chờ hồi chiêu

## [skill_id, level] của ô `slot` (BASIC_SLOT = đánh thường, chỉ dùng khi quái không có chiêu gần nào).
static func slot_skill(skills: Array, slot: int) -> Array:
	if slot == BASIC_SLOT:
		return BASIC_SKILL
	if slot < 0 or slot >= skills.size():
		return [0, 1]
	return skills[slot]

## Khoảng cách coi là "người chơi ở xa" với chiêu tầm `ranged_radius` (logic px).
static func far_distance(ranged_radius: float) -> float:
	return clampf(ranged_radius * 0.5, 150.0, 250.0)

## Chiêu có đánh địch được không (loại chiêu hồi máu / buff bản thân như Trị liệu thuật ra khỏi lựa chọn tấn công).
static func is_attack_skill(s: Dictionary) -> bool:
	return not s.is_empty() and int(s.get("target_enemy", 1)) != 0

## radii[i] = tầm ô i (< 0 = ô trống / không phải chiêu tấn công), cho 4 ô thật (index 0..3).
## Trả về radii đủ SLOT_COUNT phần tử: ô BASIC_SLOT = MELEE_RADIUS nếu quái không có chiêu gần nào nhưng có chiêu xa.
static func with_basic(radii: Array) -> Array:
	var out: Array = radii.duplicate()
	while out.size() < BASIC_SLOT:
		out.append(-1.0)
	var has_melee := false
	var has_ranged := false
	for i in BASIC_SLOT:
		var r := float(out[i])
		if r < 0.0:
			continue
		if r <= MELEE_RADIUS:
			has_melee = true
		else:
			has_ranged = true
	out.resize(SLOT_COUNT)
	out[BASIC_SLOT] = MELEE_RADIUS if (has_ranged and not has_melee) else -1.0
	return out

## Chọn ô ra chiêu. radii: kết quả with_basic(); ready[i]: ô i hết hồi chiêu; weights[i]: AIParam2-5 (ô 0..3);
## opened: đã ra chiêu với mục tiêu này rồi. Trả về ô (0..4), APPROACH hoặc WAIT.
static func pick(dist: float, radii: Array, ready: Array, weights: Array, opened: bool) -> int:
	var melee: Array = []
	var ranged: Array = []
	var best_ranged := 0.0
	for i in SLOT_COUNT:
		var r := float(radii[i]) if i < radii.size() else -1.0
		if r < 0.0:
			continue
		if r <= MELEE_RADIUS:
			melee.append(i)
		else:
			ranged.append(i)
			best_ranged = maxf(best_ranged, r)
	if melee.is_empty() and ranged.is_empty():
		return WAIT
	## Sát bên: chỉ đánh gần.
	if dist <= CLOSE_RANGE and not melee.is_empty():
		return _weighted(_filter_ready(melee, ready), weights, WAIT)
	## Mở màn, hoặc mục tiêu đã chạy ra xa: đánh xa nếu có chiêu xa sẵn sàng với tới.
	var in_reach: Array = []
	for i in _filter_ready(ranged, ready):
		if dist <= float(radii[i]) and (not opened or dist > far_distance(float(radii[i])) or melee.is_empty()):
			in_reach.append(i)
	if not in_reach.is_empty():
		return _weighted(in_reach, weights, APPROACH)
	return APPROACH

static func _filter_ready(slots: Array, ready: Array) -> Array:
	var out: Array = []
	for i in slots:
		if i < ready.size() and ready[i]:
			out.append(i)
	return out

static func _weighted(slots: Array, weights: Array, fallback: int) -> int:
	if slots.is_empty():
		return fallback
	var total := 0
	for i in slots:
		total += _weight(weights, i)
	if total <= 0:
		return slots[randi() % slots.size()]
	var roll := randi() % total
	var acc := 0
	for i in slots:
		acc += _weight(weights, i)
		if roll < acc:
			return i
	return slots[slots.size() - 1]

static func _weight(weights: Array, slot: int) -> int:
	if slot == BASIC_SLOT:
		return 100
	return maxi(0, int(weights[slot])) if slot < weights.size() else 0

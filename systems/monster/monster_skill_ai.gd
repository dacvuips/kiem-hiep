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
## opened: đã ra chiêu mở màn với mục tiêu này rồi; vision_range: phạm vi tìm kiếm người chơi của quái.
## Quy tắc:
## - Chiêu xa có cooldown 4 giây; đòn đánh thường cận chiến cooldown 2 giây.
## - Khi mới phát hiện người chơi (not opened): quái đánh chiêu xa mở màn (cooldown 4 giây).
## - Khi đã mở màn (opened == true):
##   + Nếu khoảng cách thấp hơn vị trí tìm xa nhất trừ đi 200px (dist < vision_range - 200):
##     quái đánh cận chiến liên tục (dí theo và đánh cận chiến), không dùng skill đánh xa.
##   + Nếu quá 4s (chiêu xa sẵn sàng) mà khoảng cách >= vị trí tìm xa nhất trừ đi 200px (dist >= vision_range - 200):
##     quái thi triển skill đánh xa, rồi cooldown 4 giây, rồi lại dí đánh thường.
##   + Trong thời gian cooldown 4 giây: quái dí theo đánh thường cận chiến.
## can_reach = false: quái đang dí mà bị vật cản chặn đường (không áp sát được) -> được dùng chiêu xa dù mục tiêu ở gần,
## nếu không thì đứng kẹt sau vật cản mãi không đánh.
## Trả về ô (0..4), APPROACH hoặc WAIT.
static func pick(dist: float, radii: Array, ready: Array, weights: Array, opened: bool, vision_range: float = 400.0,
		can_reach: bool = true) -> int:
	var melee: Array = []
	var ranged: Array = []
	for i in SLOT_COUNT:
		var r := float(radii[i]) if i < radii.size() else -1.0
		if r < 0.0:
			continue
		if r <= MELEE_RADIUS:
			melee.append(i)
		else:
			ranged.append(i)

	if melee.is_empty() and ranged.is_empty():
		return WAIT

	# 1. Đang đứng ngay sát bên (cận chiến): luôn ưu tiên đánh cận chiến
	if dist <= CLOSE_RANGE and not melee.is_empty():
		return _weighted(_filter_ready(melee, ready), weights, WAIT)

	# 2. Quái thuần cận chiến (không có chiêu xa):
	if ranged.is_empty():
		if dist <= CLOSE_RANGE:
			return _weighted(_filter_ready(melee, ready), weights, WAIT)
		return APPROACH

	# 3. Quái có chiêu xa:
	var ready_ranged := _filter_ready(ranged, ready)
	var ranged_threshold := maxf(vision_range - 200.0, CLOSE_RANGE)

	# TRƯỜNG HỢP A: MỚI GẶP NGƯỜI CHƠI (chưa mở màn - not opened)
	# Quái dùng chiêu đánh xa để mở màn (cooldown 4 giây).
	if not opened:
		if not ready_ranged.is_empty():
			var in_reach: Array = []
			for i in ready_ranged:
				if dist <= float(radii[i]):
					in_reach.append(i)
			if not in_reach.is_empty():
				return _weighted(in_reach, weights, APPROACH)
			# Chiêu xa sẵn sàng nhưng chưa tới tầm: bước tới để vào tầm bắn chiêu xa
			return APPROACH
		return APPROACH

	# TRƯỜNG HỢP B: ĐÃ MỞ MÀN (opened == true)
	# Yêu cầu:
	# - Nếu khoảng cách thấp hơn vị trí tìm xa nhất trừ đi 200px (dist < ranged_threshold):
	#   Quái sẽ đánh cận chiến liên tục (dí theo và đánh cận chiến), KHÔNG dùng chiêu xa!
	## (Bị vật cản chặn đường áp sát thì bỏ qua luật này — xuống dưới dùng chiêu xa nếu sẵn sàng và trong tầm.)
	if dist < ranged_threshold and (can_reach or dist <= CLOSE_RANGE):
		if dist <= CLOSE_RANGE and not melee.is_empty():
			return _weighted(_filter_ready(melee, ready), weights, WAIT)
		return APPROACH

	# - Nếu quá 4s mà người chơi ở vị trí tầm tìm xa nhất trừ đi 200px (dist >= ranged_threshold):
	#   Quái vẫn thi triển skill đánh xa, rồi cooldown 4s, rồi lại dí đánh thường.
	if not ready_ranged.is_empty():
		var in_reach: Array = []
		for i in ready_ranged:
			if dist <= float(radii[i]):
				in_reach.append(i)
		if not in_reach.is_empty():
			return _weighted(in_reach, weights, APPROACH)
		# Có chiêu xa nhưng dist > tầm chiêu xa: bước tới để vào tầm
		return APPROACH

	# Chiêu xa chưa qua 8s (đang trong thời gian cooldown 8s):
	# Quái dí theo người chơi để đánh cận chiến
	if dist <= CLOSE_RANGE and not melee.is_empty():
		return _weighted(_filter_ready(melee, ready), weights, WAIT)
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

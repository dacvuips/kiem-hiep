extends RefCounted
class_name LonXonRules
## Luật màn LỘN XỘN (hỗn chiến tự do, docs/plans/lon-xon.md) — hàm tĩnh thuần, dùng chung máy người chơi + LonXonServer.
## Hồ sơ trong Lộn Xộn là hồ sơ TẠM (server không bao giờ lưu), các hàm ở đây sửa thẳng hồ sơ đó.

# ------------------------------------------------------------------ host
const HOST_COUNT := 5
const HOST_CAPACITY := 50

# ------------------------------------------------------------------ nhân vật
const START_LEVEL := 50
const LEVEL_PER_KILL := 5            ## hạ 1 quái (đòn kết liễu) = +5 cấp
const MAX_LEVEL := 200
const POTION_ID := "1_8_0_4"         ## Hồi Thiên Tái Tạo Đơn
const START_POTIONS := 10            ## lúc vào + mỗi lần hồi sinh
const RESPAWN_SEC := 5.0
const SPAWN_PROTECT_SEC := 3.0

# ------------------------------------------------------------------ rơi đồ của quái
const EQUIP_DROPS_MIN := 3           ## 3–5 món trang bị / quái (trung bình 4)
const EQUIP_DROPS_MAX := 5
const BLUE_RATE := 0.70              ## mỗi món: 70% đồ xanh
const GOLD_RATE := 0.25              ##           25% Hoàng Kim thường, còn lại (5%) Hoàng Kim Môn Phái
const HORSE_RATE := 0.50
const BOOK_RATE := 0.03
const BOOK_STACK := 5

## Tầng kỹ năng học bằng Đại Thành Bí Kíp. Bảng skill: 9x của 10 phái cũ có req_level 80, 5 phái mới 90.
const BOOK_TIERS := [9, 12, 15, 18]
const BOOK_IDS := {9: "lonxon_bikip_9", 12: "lonxon_bikip_12", 15: "lonxon_bikip_15", 18: "lonxon_bikip_18"}

# ------------------------------------------------------------------ Lệnh Bài
const TOKEN_SCORE := 1000
const TOKEN_SCALE := 0.10            ## to hơn 10% / Lệnh Bài
const TOKEN_RADIUS := 0.05           ## bán kính skill +5% / Lệnh Bài
const TOKEN_VIEW := 0.10             ## tầm nhìn +10% / Lệnh Bài
const TOKEN_SCALE_CAP := 10          ## hiệu ứng to / bán kính tính tối đa 10 Lệnh Bài
const TOKEN_VIEW_CAP := 5            ## tầm nhìn tính tối đa 5 Lệnh Bài (AOI + hiệu năng)
const TOKEN_OWNER_LOCK_SEC := 10.0   ## chủ không nhặt lại Lệnh Bài của mình trong chừng này giây
const BOARD_SIZE := 5

## Đang ở trong 1 trận Lộn Xộn trên máy này (LonXonManager bật/tắt) — Đại Thành Bí Kíp chỉ dùng được khi true.
static var in_match := false

# ================================================================== kỹ năng

## Tầng của kỹ năng theo cấp yêu cầu: 18 / 15 / 12 / 9, còn lại 0 (kỹ năng thường — tự max theo cấp).
static func skill_tier(sk: SkillDefinition) -> int:
	if sk == null:
		return 0
	if sk.req_level >= 180:
		return 18
	if sk.req_level >= 150:
		return 15
	if sk.req_level >= 120:
		return 12
	if sk.req_level >= 80:
		return 9
	return 0

static func _sect_skills(profile: PlayerProfile) -> Array:
	if profile == null or profile.sect_id == "" or SectRegistry == null:
		return []
	var sect: SectDefinition = SectRegistry.get_by_id(profile.sect_id)
	return sect.skills if sect != null else []

static func _max_of(sk: SkillDefinition) -> int:
	return sk.max_level if sk.max_level > 0 else 20

## Đặt lại cấp kỹ năng theo cấp nhân vật — kỹ năng chỉ mở khi nhân vật đủ cấp yêu cầu (cấp 5x chỉ có kỹ năng tới 5x):
## - kỹ năng thường (tầng 0): đủ cấp -> MAX;
## - kỹ năng tầng 9x/12x/15x/18x: đủ cấp -> TỰ MỞ ở cấp 1 (không cần học), Đại Thành Bí Kíp nâng tiếp +1 cấp mỗi cuốn;
## - chưa đủ cấp -> 0; kỹ năng con (parent_skill_id) theo cấp kỹ năng cha.
## Trả về các kỹ năng vừa mở lần này (để gắn vào ô skill trống).
static func refresh_skills(profile: PlayerProfile) -> Array[String]:
	var unlocked: Array[String] = []
	var skills := _sect_skills(profile)
	for sk: SkillDefinition in skills:
		if sk == null or sk.id == "" or sk.parent_skill_id != "":
			continue
		var before := int(profile.skill_levels.get(sk.id, 0))
		var lv := 0
		if sk.req_level <= profile.level:
			lv = _max_of(sk) if skill_tier(sk) == 0 else maxi(before, 1)
		profile.skill_levels[sk.id] = lv
		if before <= 0 and lv > 0:
			unlocked.append(sk.id)
	for sk: SkillDefinition in skills:
		if sk != null and sk.id != "" and sk.parent_skill_id != "":
			profile.skill_levels[sk.id] = mini(int(profile.skill_levels.get(sk.parent_skill_id, 0)), _max_of(sk))
	return unlocked

## Bỏ khỏi ô skill các kỹ năng chưa mở; ô trống hết thì gắn các kỹ năng đã mở (như PUBG).
static func _refresh_hotbar(profile: PlayerProfile) -> void:
	var any := false
	for i in profile.hotbar_skill_ids.size():
		var sid := profile.hotbar_skill_ids[i]
		if sid != "" and int(profile.skill_levels.get(sid, 0)) <= 0:
			profile.hotbar_skill_ids[i] = ""
		elif sid != "":
			any = true
	if any:
		return
	var ids: Array[String] = []
	for sk: SkillDefinition in _sect_skills(profile):
		if sk != null:
			ids.append(sk.id)
	_put_on_hotbar(profile, ids)

## Gắn các kỹ năng (đã mở, gắn được) vào ô skill còn trống, theo thứ tự.
static func _put_on_hotbar(profile: PlayerProfile, ids: Array[String]) -> void:
	var by_id := {}
	for sk: SkillDefinition in _sect_skills(profile):
		if sk != null:
			by_id[sk.id] = sk
	for sid in ids:
		var sk: SkillDefinition = by_id.get(sid)
		if sk == null or not sk.can_assign_to_hotbar() or sk.is_basic_attack or int(profile.skill_levels.get(sid, 0)) <= 0:
			continue
		if sid in profile.hotbar_skill_ids:
			continue
		var slot := profile.hotbar_skill_ids.find("")
		if slot < 0:
			return
		profile.hotbar_skill_ids[slot] = sid

static func _recalc(profile: PlayerProfile) -> void:
	if profile.has_method("recalc_stats"):
		profile.call("recalc_stats")

# ================================================================== vào trận / lên cấp

## Hồ sơ tạm lúc vào trận: cấp 50, 4 chỉ số gốc + điểm tiềm năng đủ 49 cấp (tự cộng), kỹ năng tới 5x (refresh_skills),
## tay trắng + START_POTIONS bình ở ô thuốc 1. Ngựa + vũ khí 5x đến từ bước chọn thẻ (PubgDraftPopup tier 5).
static func apply_start(profile: PlayerProfile) -> void:
	profile.level = START_LEVEL
	profile.current_exp = 0
	profile.apply_start_stats()
	profile.potential_points = (START_LEVEL - 1) * PlayerProfile.POTENTIAL_POINTS_PER_LEVEL
	profile.skill_levels.clear()
	refresh_skills(profile)
	profile.skill_points = 0
	_refresh_hotbar(profile)
	profile.inventory.clear()
	profile.equipment.clear()
	profile.riding = false
	give_potions(profile)
	_recalc(profile)

## Cấp lại thuốc khởi đầu (lúc vào + mỗi lần hồi sinh) và gắn vào ô thuốc 1.
static func give_potions(profile: PlayerProfile) -> void:
	var potion := ItemGenerator.generate_misc(POTION_ID, 0, 0, START_POTIONS)
	if potion != null:
		profile.add_item(potion)
	if profile.quick_items.size() > 0:
		profile.quick_items[0] = POTION_ID

## +n cấp (tối đa 200): điểm tiềm năng như lên cấp thường; kỹ năng vừa đủ cấp tự mở (thường = MAX, 9x+ = cấp 1)
## và tự gắn vào ô skill còn trống. Trả về số cấp thực tăng.
static func add_levels(profile: PlayerProfile, n: int) -> int:
	var before := profile.level
	var target := mini(MAX_LEVEL, before + maxi(n, 0))
	while profile.level < target:
		profile.level_up()
	profile.skill_points = 0   ## Lộn Xộn không dùng điểm kỹ năng
	var unlocked := refresh_skills(profile)
	_refresh_hotbar(profile)
	_put_on_hotbar(profile, unlocked)
	_recalc(profile)
	return profile.level - before

## Hạ 1 quái bằng đòn kết liễu.
static func on_monster_kill(profile: PlayerProfile) -> int:
	return add_levels(profile, LEVEL_PER_KILL)

# ================================================================== rơi đồ

## 1 món trang bị: 70% xanh (theo cấp người hạ quái) / 25% Hoàng Kim thường / 5% Hoàng Kim Môn Phái.
static func roll_equipment(killer_level: int) -> ItemInstance:
	var r := randf()
	var it: ItemInstance = null
	if r < BLUE_RATE:
		it = DropTable.roll_blue_for_level(killer_level)
	elif r < BLUE_RATE + GOLD_RATE:
		it = DropTable.roll_normal_gold_item()
	else:
		it = DropTable.roll_sect_gold_item()
	return it

static func make_book(tier: int, count: int = BOOK_STACK) -> ItemInstance:
	if not BOOK_IDS.has(tier):
		return null
	return ItemGenerator.generate_misc(BOOK_IDS[tier], 0, 0, count)

## Đồ rơi của 1 quái: [{"type": "item", "item": ItemInstance}, ...] (cùng dạng DropTable.roll / PubgServer.roll_drops).
static func roll_drops(killer_level: int) -> Array:
	var out: Array = []
	for i in randi_range(EQUIP_DROPS_MIN, EQUIP_DROPS_MAX):
		var eq := roll_equipment(killer_level)
		if eq != null:
			out.append({"type": "item", "item": eq})
	if randf() < HORSE_RATE:
		var horse := DropTable.roll_horse()
		if horse != null:
			out.append({"type": "item", "item": horse})
	var pot := ItemGenerator.generate_misc(POTION_ID)
	if pot != null:
		out.append({"type": "item", "item": pot})
	if randf() < BOOK_RATE:
		var book := make_book(BOOK_TIERS[randi() % BOOK_TIERS.size()])
		if book != null:
			out.append({"type": "item", "item": book})
	return out

## Bị hạ: lấy HẾT trang bị đang mặc + hành trang ra khỏi hồ sơ (server rải ra đất quanh xác). Giữ cấp / kỹ năng / điểm.
static func death_drops(profile: PlayerProfile) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for part in profile.equipment.keys():
		var it: ItemInstance = profile.equipment[part]
		if it != null:
			out.append(it)
	profile.equipment.clear()
	for it in profile.inventory:
		if it != null:
			out.append(it)
	profile.inventory.clear()
	profile.riding = false
	_recalc(profile)
	return out

# ================================================================== Đại Thành Bí Kíp

## Tầng của cuốn bí kíp theo mã vật phẩm, 0 = không phải Đại Thành Bí Kíp.
static func book_tier(misc_id: String) -> int:
	for tier in BOOK_IDS:
		if BOOK_IDS[tier] == misc_id:
			return tier
	return 0

## Các kỹ năng (hiện trong bảng, không phải kỹ năng con) của phái thuộc tầng `tier`.
static func book_candidates(profile: PlayerProfile, tier: int) -> Array[SkillDefinition]:
	var out: Array[SkillDefinition] = []
	for sk: SkillDefinition in _sect_skills(profile):
		if sk != null and not sk.is_hidden and sk.parent_skill_id == "" and skill_tier(sk) == tier:
			out.append(sk)
	return out

## Lý do không học được (rỗng = học được).
static func book_block_reason(profile: PlayerProfile, tier: int, skill_id: String) -> String:
	if not in_match:
		return "Đại Thành Bí Kíp chỉ dùng được trong màn Lộn Xộn."
	var sk: SkillDefinition = null
	for c in book_candidates(profile, tier):
		if c.id == skill_id:
			sk = c
	if sk == null:
		return "Bí kíp %dx không dùng được cho kỹ năng này." % tier
	if profile.level < sk.req_level:
		return "Cần đạt cấp %d để lĩnh hội [%s]." % [sk.req_level, sk.skill_name]
	if profile.get_skill_level(sk.id) >= _max_of(sk):
		return "[%s] đã đạt cấp tối đa." % sk.skill_name
	return ""

## +1 cấp `skill_id` (kỹ năng con theo cùng). Trả về lý do lỗi, rỗng = thành công.
static func learn_from_book(profile: PlayerProfile, tier: int, skill_id: String) -> String:
	var why := book_block_reason(profile, tier, skill_id)
	if why != "":
		return why
	profile.skill_levels[skill_id] = profile.get_skill_level(skill_id) + 1
	refresh_skills(profile)
	_refresh_hotbar(profile)
	_recalc(profile)
	return ""

## Kỹ năng mặc định khi bấm "Dùng": kỹ năng học được có cấp thấp nhất. "" = không có kỹ năng nào học được.
static func default_book_skill(profile: PlayerProfile, tier: int) -> String:
	var best := ""
	var best_lv := 1 << 30
	for sk in book_candidates(profile, tier):
		if book_block_reason(profile, tier, sk.id) != "":
			continue
		var lv := profile.get_skill_level(sk.id)
		if lv < best_lv:
			best = sk.id
			best_lv = lv
	return best

# ================================================================== Lệnh Bài

static func score_for(tokens: int) -> int:
	return maxi(tokens, 0) * TOKEN_SCORE

## Chết đang giữ n Lệnh Bài: rớt 1 (của bản thân) + n/2; còn giữ n - n/2. Trả về Vector2i(rớt, còn giữ).
static func death_token_split(n: int) -> Vector2i:
	n = maxi(n, 0)
	var half := n / 2
	return Vector2i(1 + half, n - half)

static func scale_for(tokens: int) -> float:
	return 1.0 + TOKEN_SCALE * clampi(tokens, 0, TOKEN_SCALE_CAP)

static func radius_mult_for(tokens: int) -> float:
	return 1.0 + TOKEN_RADIUS * clampi(tokens, 0, TOKEN_SCALE_CAP)

static func view_mult_for(tokens: int) -> float:
	return 1.0 + TOKEN_VIEW * clampi(tokens, 0, TOKEN_VIEW_CAP)

## Zoom camera (Godot: zoom nhỏ hơn = thấy rộng hơn) khi giữ `tokens` Lệnh Bài.
static func zoom_for(base_zoom: float, tokens: int) -> float:
	return base_zoom / view_mult_for(tokens)

## Bảng xếp hạng: entries = [{"cid", "name", "score"}, ...] -> k người điểm cao nhất (điểm > 0), bằng điểm xếp theo tên.
static func top_n(entries: Array, k: int = BOARD_SIZE) -> Array:
	var list := entries.filter(func(e: Dictionary) -> bool: return int(e.get("score", 0)) > 0)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("score", 0))
		var sb := int(b.get("score", 0))
		if sa != sb:
			return sa > sb
		return str(a.get("name", "")) < str(b.get("name", "")))
	return list.slice(0, k)

## Số hạng trên đầu: cid -> 1/2/3 cho top 3 (có điểm).
static func rank_badges(entries: Array) -> Dictionary:
	var out := {}
	var top := top_n(entries, 3)
	for i in top.size():
		out[top[i].get("cid")] = i + 1
	return out

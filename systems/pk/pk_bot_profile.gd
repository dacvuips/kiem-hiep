extends RefCounted
class_name PkBotProfile
## Dựng NHÂN VẬT của bot PK (đối thủ khi "Tự tìm đối thủ" quá PkRules.MATCH_WAIT_SEC giây không có người): một PlayerProfile đầy
## đủ như người chơi thật cùng cấp — tên ngẫu nhiên (họ + tên của SocialDirectory), môn phái ngẫu nhiên (Đại hội võ lâm: cùng phái
## với người chơi), điểm tiềm năng + điểm kỹ năng đúng số người chơi có ở cấp đó, trang bị xanh cùng bậc cấp, đòn chính và hào quang.
## Chỉ là dữ liệu — PkBot dùng hồ sơ này cho CombatantStats + SectSkillController (cùng đường tính đòn như nhân vật thật).
##
## Cách cộng điểm / học skill là THIẾT KẾ của game này (VLTK gốc không có bot): phái ngoại công dồn Sức mạnh + Thân pháp, nội công
## dồn Nội công; skill cấp cao học trước, dồn đầy rồi mới sang skill sau.

## [Sức mạnh, Thân pháp, Sinh khí, Nội công] — tỉ lệ chia điểm tiềm năng.
const SPLIT_PHYSICAL := [0.5, 0.3, 0.2, 0.0]
const SPLIT_INNER := [0.0, 0.1, 0.3, 0.6]
## Số dòng magic mỗi món trang bị (đồ xanh) — 4 dòng: mạnh vừa phải, không vượt người chơi đồ hoàng kim.
const MAGIC_LINES := 4

static func create(level: int, sect_id: String = "", rng: RandomNumberGenerator = null) -> PlayerProfile:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var p := PlayerProfile.new()
	var sect := SectRegistry.get_by_id(sect_id) if sect_id != "" else null
	if sect == null:
		var sects := SectRegistry.load_all()
		sect = sects[rng.randi() % sects.size()]
	p.display_name = random_name(rng)
	p.gender = PlayerProfile.Gender.FEMALE if rng.randf() < 0.5 else PlayerProfile.Gender.MALE
	p.set_sect(sect)
	p.apply_start_stats()
	for i in clampi(level, 1, 200) - 1:
		p.level_up()
	_spend_potential(p, sect)
	_learn_skills(p, sect)
	_dress(p, sect, rng)
	return p

static func random_name(rng: RandomNumberGenerator) -> String:
	var family: Array = SocialDirectory.FAMILY
	var given: Array = SocialDirectory.GIVEN
	return "%s %s" % [family[rng.randi() % family.size()], given[rng.randi() % given.size()]]

## Phái ngoại công hay nội công: theo đa số skill đánh của phái.
static func is_physical_sect(sect: SectDefinition) -> bool:
	var physical := 0
	var inner := 0
	for s in sect.skills:
		if is_attack_skill(s):
			if s.is_physical():
				physical += 1
			else:
				inner += 1
	return physical >= inner

## Skill đánh thật (gây sát thương, chủ động): không phải đánh thường, hào quang, buff/bùa.
static func is_attack_skill(s: SkillDefinition) -> bool:
	return s != null and s.category == SkillDefinition.SkillCategory.ACTIVE and not s.is_aura and not s.is_basic_attack \
			and not s.is_state_skill() and s.vltk_skill_id > 0

static func _spend_potential(p: PlayerProfile, sect: SectDefinition) -> void:
	var split: Array = SPLIT_PHYSICAL if is_physical_sect(sect) else SPLIT_INNER
	var total := p.potential_points
	var stats := [PlayerProfile.BaseStat.STRENGTH, PlayerProfile.BaseStat.DEXTERITY, PlayerProfile.BaseStat.VITALITY,
		PlayerProfile.BaseStat.ENERGY]
	for i in stats.size():
		p.add_potential_points(stats[i], int(total * float(split[i])))
	p.add_potential_points(PlayerProfile.BaseStat.VITALITY, p.potential_points)   ## phần lẻ còn lại

## Học skill: cấp yêu cầu cao trước, dồn tới tối đa; skill luyện (90/120/150) lĩnh hội cấp 1. Chọn đòn chính + hào quang.
static func _learn_skills(p: PlayerProfile, sect: SectDefinition) -> void:
	var order := sect.skills.duplicate()
	order.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool: return a.req_level > b.req_level)
	for s in order:
		if s.practice_only:
			p.learn_practice_skill(s.id)
			continue
		while p.learn_skill(s.id):
			pass
	var main := best_attack_skill(p, sect)
	if main != null:
		p.main_skill_id = main.id
	for s in order:
		if p != null and s.is_aura and p.get_skill_level(s.id) > 0:
			p.active_aura_id = s.id
			break

## Skill đánh mạnh nhất đã học mà bộ máy chiêu VLTK chạy được (cấp yêu cầu cao nhất).
static func best_attack_skill(p: PlayerProfile, sect: SectDefinition) -> SkillDefinition:
	var best: SkillDefinition = null
	if p == null or sect == null:
		return null
	for s in sect.skills:
		var s_lv: int = p.get_skill_level(s.id) if p != null else 0
		if not is_attack_skill(s) or (s_lv <= 0 and not s.is_main_attack):
			continue
		if not VltkSkillRunner.supports(s, maxi(1, s_lv)):
			continue
		if best == null or s.req_level > best.req_level:
			best = s
	return best

## Trang bị xanh cùng bậc cấp (cấp 10 nhân vật = đồ cấp 1, tối đa 10) cho mọi ô; vũ khí đúng loại đòn chính đòi hỏi.
static func _dress(p: PlayerProfile, sect: SectDefinition, rng: RandomNumberGenerator) -> void:
	var tier := clampi(ceili(p.level / 10.0), 1, 10)
	var magic := []
	for i in MAGIC_LINES:
		magic.append(tier)
	var main := SectRegistry.get_by_id(p.sect_id)
	var main_skill: SkillDefinition = null
	for s in (main.skills if main else []):
		if s.id == p.main_skill_id:
			main_skill = s
	for detail in ItemDatabase.Detail.values():
		if detail == ItemDatabase.Detail.HORSE:
			continue
		var particular := _pick_particular(detail, main_skill, rng)
		if particular < 0:
			continue
		var levels := ItemDatabase.get_levels(detail, particular)
		if levels.is_empty():
			continue
		var lv: int = levels[0]
		for l in levels:
			if l <= tier:
				lv = l
		var item := ItemGenerator.generate(detail, particular, lv, rng.randi() % 5, magic)
		if item == null:
			continue
		var parts: Array = Equipment.DETAIL_TO_PARTS.get(detail, [])
		for part in parts:
			if not p.equipment.has(part):
				p.equipment[part] = item
				break
		## 2 ô nhẫn: thêm 1 nhẫn nữa.
		if detail == ItemDatabase.Detail.RING:
			var ring2 := ItemGenerator.generate(detail, particular, lv, rng.randi() % 5, magic)
			for part in parts:
				if not p.equipment.has(part) and ring2 != null:
					p.equipment[part] = ring2
					break

## Loại cụ thể của món: vũ khí theo hạn chế vũ khí của đòn chính (EqtLimit: -1 quyền thủ = không cầm vũ khí, 0..8 vũ khí cận
## chiến, 100+ ám khí); món khác ngẫu nhiên. -1 = bỏ trống ô này.
static func _pick_particular(detail: int, main_skill: SkillDefinition, rng: RandomNumberGenerator) -> int:
	var limit := main_skill.weapon_limit if main_skill != null else -2
	if detail == ItemDatabase.Detail.MELEE:
		if limit >= 100 or limit == -1:
			return -1
		if limit >= 0:
			return limit
		return 0                                   ## không hạn chế: cầm kiếm
	if detail == ItemDatabase.Detail.RANGE:
		return limit - 100 if limit >= 100 else -1
	var particulars := ItemDatabase.get_particulars(detail)
	return particulars[rng.randi() % particulars.size()] if not particulars.is_empty() else -1

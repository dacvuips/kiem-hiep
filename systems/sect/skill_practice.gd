class_name SkillPractice
extends RefCounted
## LUYỆN KỸ NĂNG 90 / 120 / 150 (skill practice_only) — theo VLTK gốc:
## - Kỹ năng ĐÁNH (nhắm địch, KSkill::IsTargetEnemy): mỗi đòn TRÚNG quái của chiêu đang dùng (m_ActiveSkillID) +HIT_EXP thành
##   thạo (KNpc::ReceiveDamage -> KSkillList::IncreaseExp(1 * g_SkillExpRate)).
## - Kỹ năng BỊ ĐỘNG / HÀO QUANG / BUFF: nhận KILL_EXP_PERCENT % kinh nghiệm giết quái (KPlayer::AddSelfExp -> AddSkillExp).
## - Đủ mốc của cấp hiện tại (settings/npc/player/magic_level_exp.txt, cột LEVELn) thì +1 cấp, thành thạo về 0
##   (KSkillList::IncreaseLevel). Chỉ luyện tới MAX_TRAIN_LEVEL (MAX_TRAIN_SKILLEXPLEVEL = 20); skill chưa lĩnh hội không luyện.
## Số liệu: data/skill_practice/magic_level_exp.json (tools/export_skill_practice_exp.py). Kỹ năng không có trong bảng gốc
## (5 phái mới) lấy dòng trung vị cùng tầng 90 / 120 / 150.

## GameSetting.ini [ServerConfig] SkillRate / Skill120Rate (bản server VS2022: 234 / 50).
const HIT_EXP := 234
const KILL_EXP_PERCENT := 50
const MAX_TRAIN_LEVEL := 20
## Chiêu đánh vừa ra trong khoảng này mới tính là "chiêu đang dùng" khi đòn trúng (đạn bay / độc ngấm chậm).
const ACTIVE_WINDOW_SEC := 4.0
const TABLE_PATH := "res://data/skill_practice/magic_level_exp.json"

static var _table: Dictionary = {}
static var _tier_fallback: Dictionary = {}
static var _loaded := false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if f == null:
		push_warning("SkillPractice: thiếu " + TABLE_PATH)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_table = data

## Tầng 90 / 120 / 150 theo cấp yêu cầu (0 = không phải skill luyện).
static func tier_of(sk: SkillDefinition) -> int:
	if sk == null or not sk.practice_only:
		return 0
	if sk.req_level >= 150:
		return 150
	if sk.req_level >= 120:
		return 120
	return 90

## Dòng mốc của tầng (trung vị theo tổng) cho skill không có trong bảng gốc. Rỗng nếu chưa có dữ liệu.
static func _fallback_row(tier: int) -> Array:
	if _tier_fallback.has(tier):
		return _tier_fallback[tier]
	var rows: Array = []
	for sect: SectDefinition in SectRegistry.load_all():
		for sk: SkillDefinition in sect.skills:
			if sk != null and tier_of(sk) == tier and _table.has(str(sk.vltk_skill_id)):
				rows.append(_table[str(sk.vltk_skill_id)])
	var row: Array = []
	if not rows.is_empty():
		rows.sort_custom(func(a: Array, b: Array) -> bool: return _sum(a) < _sum(b))
		row = rows[rows.size() / 2]
	_tier_fallback[tier] = row
	return row

static func _sum(a: Array) -> int:
	var s := 0
	for v in a:
		s += int(v)
	return s

## Thành thạo cần để từ cấp `level` lên `level + 1` (0 = không luyện được nữa).
static func next_exp(sk: SkillDefinition, level: int) -> int:
	if tier_of(sk) == 0 or level <= 0 or level >= train_cap(sk):
		return 0
	_load()
	var row: Variant = _table.get(str(sk.vltk_skill_id))
	if not (row is Array) or (row as Array).is_empty():
		row = _fallback_row(tier_of(sk))
	var arr: Array = row
	if level - 1 >= arr.size():
		return 0
	return maxi(int(arr[level - 1]), 0)

## Cấp cao nhất luyện được (không vượt cấp tối đa của skill).
static func train_cap(sk: SkillDefinition) -> int:
	return mini(MAX_TRAIN_LEVEL, sk.max_level) if sk.max_level > 0 else MAX_TRAIN_LEVEL

## Skill luyện bằng đòn trúng (đánh địch) — còn lại (bị động, hào quang, buff) luyện bằng kinh nghiệm giết quái.
static func is_hit_trained(sk: SkillDefinition) -> bool:
	return tier_of(sk) > 0 and sk.category == SkillDefinition.SkillCategory.ACTIVE and not sk.is_aura and sk.target_enemy

## Cộng `amount` thành thạo cho `skill_id`. Trả về true nếu lên cấp.
static func add(profile: PlayerProfile, sk: SkillDefinition, amount: int) -> bool:
	if profile == null or sk == null or amount <= 0:
		return false
	var lv := profile.get_skill_level(sk.id)
	var need := next_exp(sk, lv)
	if need <= 0:
		return false
	var cur := int(profile.skill_exp.get(sk.id, 0)) + amount
	if cur < need:
		profile.skill_exp[sk.id] = cur
		return false
	profile.skill_levels[sk.id] = lv + 1
	profile.skill_exp[sk.id] = 0
	return true

## Đòn của người chơi `profile` trúng quái khi chiêu đang dùng là `skill_id`. Trả về skill vừa lên cấp (null nếu không).
static func on_hit(profile: PlayerProfile, skill_id: String) -> SkillDefinition:
	if profile == null or skill_id == "":
		return null
	var sk := _find(profile, skill_id)
	if sk == null or not is_hit_trained(sk):
		return null
	return sk if add(profile, sk, HIT_EXP) else null

## Đòn của nhân vật trên máy này (`attacker`) trúng quái — gọi từ VltkMonster / Enemy sau khi qua roll trúng (kể cả bị giáp nuốt hết).
## Hồ sơ tạm của trận PUBG / Lộn Xộn không luyện.
static func on_monster_hit(attacker: Node) -> void:
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_in_group("player"):
		return
	if attacker != attacker.get_tree().get_first_node_in_group("player"):
		return
	if LonXonRules.in_match or PubgManager.is_pubg_active():
		return
	var ctrl: Variant = attacker.get("skill_controller")
	if not (ctrl is SectSkillController):
		return
	var c: SectSkillController = ctrl
	if c.active_skill_id == "" or Time.get_ticks_msec() - c.active_skill_at > int(ACTIVE_WINDOW_SEC * 1000.0):
		return
	var profile := GameManager.local_profile
	var before := int(profile.skill_exp.get(c.active_skill_id, 0)) if profile != null else 0
	var up := on_hit(profile, c.active_skill_id)
	if up != null:
		announce(profile, [up])
	elif profile != null and int(profile.skill_exp.get(c.active_skill_id, 0)) != before:
		SaveManager.request_exp_save(profile, 5.0)

## Như on_monster_hit nhưng tự tìm người đánh từ mods.attacker_node, không có thì so CombatantStats với nhân vật trên máy này.
static func on_monster_hit_by(mods: CombatFormulas.HitModifiers, attacker_stats: CombatantStats, tree: SceneTree) -> void:
	if tree == null:
		return
	var hitter: Node = mods.attacker_node if mods != null and is_instance_valid(mods.attacker_node) else null
	if hitter == null and attacker_stats != null:
		var p := tree.get_first_node_in_group("player")
		if p != null and "combat_stats" in p and p.combat_stats == attacker_stats:
			hitter = p
	on_monster_hit(hitter)

## Kinh nghiệm giết quái của nhân vật trên máy này (offline: KillRewards, online: S_PROGRESS) -> skill bị động / hào quang.
static func on_local_kill_exp(profile: PlayerProfile, exp_gained: int) -> void:
	if profile == null or exp_gained <= 0 or LonXonRules.in_match or PubgManager.is_pubg_active():
		return
	announce(profile, on_kill_exp(profile, exp_gained))

## Kinh nghiệm giết quái `exp_gained` -> mọi skill luyện bị động / hào quang / buff đã lĩnh hội. Trả về các skill lên cấp.
static func on_kill_exp(profile: PlayerProfile, exp_gained: int) -> Array[SkillDefinition]:
	var up: Array[SkillDefinition] = []
	var amount := exp_gained * KILL_EXP_PERCENT / 100
	if profile == null or amount <= 0 or profile.sect_id == "":
		return up
	var sect: SectDefinition = SectRegistry.get_by_id(profile.sect_id)
	if sect == null:
		return up
	for sk: SkillDefinition in sect.skills:
		if sk != null and tier_of(sk) > 0 and not is_hit_trained(sk) and add(profile, sk, amount):
			up.append(sk)
	return up

static func _find(profile: PlayerProfile, skill_id: String) -> SkillDefinition:
	var sect: SectDefinition = SectRegistry.get_by_id(profile.sect_id)
	if sect == null:
		return null
	for sk: SkillDefinition in sect.skills:
		if sk != null and sk.id == skill_id:
			return sk
	return null

## Báo lên cấp + lưu hồ sơ + làm mới chỉ số nhân vật trên bản đồ (dùng chung cho đòn trúng / giết quái).
static func announce(profile: PlayerProfile, skills: Array) -> void:
	if skills.is_empty():
		return
	for sk: SkillDefinition in skills:
		ChatBox.push_system("[color=#ffaa00][Luyện công][/color] Kỹ năng [color=#55ff55]%s[/color] đã lên cấp %d!" % [sk.skill_name, profile.get_skill_level(sk.id)])
	SaveManager.save_profile(profile)
	var loop := Engine.get_main_loop()
	var player: Node = (loop as SceneTree).get_first_node_in_group("player") if loop is SceneTree else null
	if player != null and player.has_method("refresh_combat_stats"):
		player.refresh_combat_stats()

## Dòng mô tả luyện cho bảng kỹ năng ("" = không phải skill luyện).
static func describe(profile: PlayerProfile, sk: SkillDefinition) -> String:
	if tier_of(sk) == 0 or profile == null:
		return ""
	var how := "mỗi đòn trúng quái +%d" % HIT_EXP if is_hit_trained(sk) else "nhận %d%% kinh nghiệm giết quái" % KILL_EXP_PERCENT
	var lv := profile.get_skill_level(sk.id)
	if lv <= 0:
		return "Kỹ năng cao cấp: lĩnh hội khi đủ cấp, sau đó luyện tập (%s)" % how
	var need := next_exp(sk, lv)
	if need <= 0:
		return "Luyện tập: đã tới cấp %d (cấp cao hơn dùng Đại Thành Bí Kíp)" % lv if lv >= MAX_TRAIN_LEVEL else "Luyện tập: đã tối đa"
	var cur := int(profile.skill_exp.get(sk.id, 0))
	return "Độ thành thạo: %d / %d (%d%%) — %s" % [cur, need, cur * 100 / need, how]

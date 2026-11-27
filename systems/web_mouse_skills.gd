extends RefCounted

class_name WebMouseSkills

## Skill CHUỘT TRÁI / CHUỘT PHẢI của bản web — theo đúng client VLTK gốc:
##   - Ô T (ImediaLeftSkill) = skill chuột trái (KPlayer::m_nLeftSkillID): bấm trái vào kẻ địch -> đuổi theo và ĐÁNH LIÊN TỤC
##     bằng skill này tới khi mục tiêu chết / bấm chỗ khác (Npc::m_nPeopleIdx). Shift + bấm trái = ra skill trái tại con trỏ.
##   - Ô P (ImediaRightSkill) = skill chuột phải (m_nRightSkillID): giữ chuột phải = ra chiêu về phía con trỏ. Chọn HÀO QUANG
##     cho ô P = bật hào quang đó (KPlayer::SetRightSkill -> SetAuraSkill), chọn skill khác = tắt hào quang; hào quang ở ô P
##     thì bấm chuột phải không ra chiêu (ProcessMouse: IsAura -> return).
##   - Bấm ô T / P mở bảng chọn (KUiSkillTree) liệt kê skill gán được (KSkillList::GetLeft/RightSkillSortList, ô đầu = đòn
##     vũ khí đang cầm). Đang mở bảng, rê chuột lên skill rồi bấm Q E R Y U H = gán phím tắt; đóng bảng, bấm phím đó = đổi
##     skill trái/phải sang skill đã gán (KUiSkillTree::HandleShortcutKey, Ui/autoexec.lua ShortcutSkill(0..5)).
## Skill phải dùng chung PlayerProfile.main_skill_id (chuột phải / phím J / Auto đều đọc nó). Skill trái + phím tắt lưu trên
## máy theo nhân vật (gốc lưu trong ini của client, SKILLTREE_SHORTCUT_SKILL_SAVE).

const LR_PATH := "res://data/skill_fx/skill_lr.json"   ## tools/export_skill_lr.py: SkillId -> [LRSkill, is_base, SkillStyle]
const SAVE_PATH := "user://web_mouse_skills.cfg"
## Gốc (Ui/autoexec.lua ShortcutSkill 0..5) là Q W E A S D; game giữ W/A/S/D để đi bộ nên đổi sang các phím còn trống.
const SHORTCUT_KEYS: Array[Key] = [KEY_Q, KEY_E, KEY_R, KEY_Y, KEY_U, KEY_H]
const SHORTCUT_NAMES := ["Q", "E", "R", "Y", "U", "H"]
const LR_BOTH := 0
const LR_LEFT_ONLY := 1
const LR_RIGHT_ONLY := 2
const STYLE_THIEF := 13

static var _lr: Dictionary = {}
static var _cfg: ConfigFile = null

static func _lr_table() -> Dictionary:
	if _lr.is_empty():
		var f := FileAccess.open(LR_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_lr = parsed
	return _lr

static func _config() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(SAVE_PATH)
	return _cfg

static func _section() -> String:
	var p := GameManager.local_profile
	return "char_%d" % (p.id if p != null else 0)

static func _save() -> void:
	if OS.get_environment("KIEMHIEP_NO_SAVE") == "1":
		return
	_config().save(SAVE_PATH)

## Skill có vào danh sách chuột trái (left = true) / phải không — đúng điều kiện KSkillList (kể cả thứ tự toán tử gốc:
## (không phải đòn cơ bản VÀ LRSkill cả 2) HOẶC LRSkill đúng phía). Skill không có trong Skills.txt: cho vào nếu thi triển được.
static func is_eligible(skill: SkillDefinition, left: bool) -> bool:
	if skill == null or skill.is_hidden:
		return false
	var row: Variant = _lr_table().get(str(skill.vltk_skill_id))
	if not (row is Array) or (row as Array).size() < 3:
		return skill.can_assign_to_hotbar() and not (left and skill.is_aura)
	var lr := int(row[0])
	var is_base := int(row[1]) == 1
	var style := int(row[2])
	if style <= 3:
		return (not is_base and lr == LR_BOTH) or lr == (LR_LEFT_ONLY if left else LR_RIGHT_ONLY)
	if style == STYLE_THIEF and left:
		return false
	return true

## Danh sách bảng chọn: ô đầu = đòn vũ khí đang cầm, rồi skill đã học (cấp >= 1, đủ cấp nhân vật) theo thứ tự trong phái.
static func eligible_skills(controller: SectSkillController, left: bool) -> Array[SkillDefinition]:
	var out: Array[SkillDefinition] = []
	if controller == null:
		return out
	var basic := controller.get_default_main_skill()
	if basic != null:
		out.append(basic)
	var p := GameManager.local_profile
	if controller.sect == null or p == null:
		return out
	for s in controller.sect.skills:
		if s == null or s == basic or s.parent_skill_id != "":
			continue
		if p.get_skill_level(s.id) <= 0 and not SectSkillController.DEBUG_UNLOCK_ALL_SKILLS:
			continue
		if p.level < s.req_level:
			continue
		if is_eligible(s, left):
			out.append(s)
	return out

static func _find(controller: SectSkillController, skill_id: String) -> SkillDefinition:
	if controller == null or skill_id == "":
		return null
	if controller.sect != null:
		for s in controller.sect.skills:
			if s != null and s.id == skill_id:
				return s
	var basic := controller.get_default_main_skill()
	return basic if basic != null and basic.id == skill_id else null

## Skill chuột trái hiện tại (mặc định / skill không còn dùng được = đòn vũ khí đang cầm — KPlayer::UpdateWeaponSkill).
static func left_skill(controller: SectSkillController) -> SkillDefinition:
	var s := _find(controller, str(_config().get_value(_section(), "left", "")))
	if s == null or not controller.is_skill_usable(s) or not is_eligible(s, true):
		return controller.get_default_main_skill() if controller else null
	return s

static func right_skill(controller: SectSkillController) -> SkillDefinition:
	return controller.get_main_skill() if controller else null

static func set_left(skill: SkillDefinition) -> void:
	_config().set_value(_section(), "left", skill.id if skill != null else "")
	_save()

## Ô P: đổi skill chính (lưu hồ sơ như chọn trong bảng Kỹ năng). Hào quang -> bật; skill khác -> tắt hào quang (gốc).
static func set_right(player: Node, skill: SkillDefinition) -> void:
	var p := GameManager.local_profile
	if p == null or skill == null:
		return
	p.set_main_skill("" if skill.is_basic_attack else skill.id)
	var new_aura := skill.id if skill.is_aura else ""
	if p.active_aura_id != new_aura:
		p.active_aura_id = new_aura
		if player != null and is_instance_valid(player):
			if player.has_method("refresh_combat_stats"):
				player.refresh_combat_stats()
			if player.has_method("_refresh_aura_sprite"):
				player._refresh_aura_sprite()
	SaveManager.save_profile(p)

## Phím tắt `index` (0..5 = Q E R Y U H): {"id": skill id, "left": bool} hoặc {}.
static func shortcut(index: int) -> Dictionary:
	var v: Variant = _config().get_value(_section(), "key_%d" % index, {})
	return v if v is Dictionary else {}

## Gán phím tắt `index` cho skill của bảng trái/phải; skill đó đang ở phím khác (cùng phía) thì phím kia bị xoá (gốc).
static func set_shortcut(index: int, skill: SkillDefinition, left: bool) -> void:
	for i in SHORTCUT_KEYS.size():
		var d := shortcut(i)
		if i != index and str(d.get("id", "")) == skill.id and bool(d.get("left", false)) == left:
			_config().set_value(_section(), "key_%d" % i, {})
	_config().set_value(_section(), "key_%d" % index, {"id": skill.id, "left": left})
	_save()

## Phím tắt của `skill` trong bảng trái/phải ("" nếu chưa gán).
static func shortcut_name(skill: SkillDefinition, left: bool) -> String:
	for i in SHORTCUT_KEYS.size():
		var d := shortcut(i)
		if str(d.get("id", "")) == skill.id and bool(d.get("left", false)) == left:
			return SHORTCUT_NAMES[i]
	return ""

## Bấm phím tắt khi bảng đóng: đổi skill trái/phải sang skill đã gán (bỏ qua nếu skill không còn trong danh sách).
static func apply_shortcut(index: int, player: Node) -> void:
	var d := shortcut(index)
	if d.is_empty() or player == null or not ("skill_controller" in player):
		return
	var left := bool(d.get("left", false))
	var controller: SectSkillController = player.skill_controller
	var skill := _find(controller, str(d.get("id", "")))
	if skill == null or not eligible_skills(controller, left).has(skill):
		return
	if left:
		set_left(skill)
	else:
		set_right(player, skill)

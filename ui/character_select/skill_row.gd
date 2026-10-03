extends HBoxContainer
class_name SkillRow
## 1 dòng skill trong bảng preview Bước 3 — dựng từ SkillDefinition thuần, không giữ state.

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _desc_label: Label = %DescLabel
@onready var _stat_label: Label = %StatLabel

func setup(skill: SkillDefinition) -> void:
	_icon.texture = skill.icon
	_icon.visible = skill.icon != null
	_name_label.text = skill.skill_name
	_desc_label.text = skill.description
	_stat_label.text = _build_stat_text(skill)

func _build_stat_text(skill: SkillDefinition) -> String:
	if not skill.is_active:
		return "Bị động · Yêu cầu Lv.%d" % skill.req_level
	var parts: Array[String] = ["Lv.%d" % skill.req_level]
	if skill.base_damage > 0.0:
		parts.append("ST %d" % int(skill.base_damage))
	if skill.mana_cost > 0.0:
		parts.append("Nội lực %d" % int(skill.mana_cost))
	if skill.cooldown > 0.0:
		parts.append("Hồi %.1fs" % skill.cooldown)
	return " · ".join(parts)

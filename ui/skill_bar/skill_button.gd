extends Button
class_name SkillButton
## 1 nút skill TRÒN viền trắng trong SkillBarUI — vẽ icon + khoá xám khi skill phụ chưa học.
## Nút phụ có thể là ô TRỐNG (skill = null) khi người chơi chưa gắn skill vào ô đó.
## Hiển thị huy hiệu tầng (Tier Badge: 3 TẦNG, 2 TẦNG) ngoài map.
## Không hiển thị tooltip trên thanh chiêu ngoài map chơi (tránh che khuất tầm nhìn chiến đấu).

const SLOT_BG := Color(0.1, 0.12, 0.16, 0.85)
const SLOT_BG_HOVER := Color(0.18, 0.2, 0.26, 0.9)
const SLOT_BORDER := Color(1, 1, 1, 0.95)
const BORDER_WIDTH := 3
const CIRCLE_MASK_SHADER := preload("res://ui/shaders/circle_mask.gdshader")

@onready var _icon: TextureRect = %Icon
@onready var _lock_overlay: Panel = %LockOverlay

var skill: SkillDefinition
var is_main: bool = false
@export var show_tooltip: bool = false

var _tier_badge: PanelContainer = null
var _tier_label: Label = null

## StyleBox hình tròn (bo góc = nửa cạnh) viền trắng — dùng chung cho nút skill trong trận và ô
## hotbar trong bảng Kỹ Năng Võ Công để 2 nơi nhìn giống nhau.
static func make_round_style(diameter: float, bg: Color, border: Color = SLOT_BORDER, border_width: int = BORDER_WIDTH) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(ceil(diameter * 0.5)))
	style.anti_aliasing = true
	return style

## Material bỏ viền khung vuông của icon skill gốc + thu icon vừa trong nút tròn, KHÔNG cắt tròn
## (cùng shader với node Icon trong SkillButton.tscn).
## round_crop = true: icon phủ kín nút tròn, cắt tròn (nút trên màn chơi).
static func make_icon_fit_material(round_crop := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CIRCLE_MASK_SHADER
	material.set_shader_parameter("round_crop", round_crop)
	return material

static func apply_round_style(button: Button, diameter: float) -> void:
	var normal := make_round_style(diameter, SLOT_BG)
	var hover := make_round_style(diameter, SLOT_BG_HOVER)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

const EMPTY_SLOT_TINT := Color(1, 1, 1, 0.45)

func _ready() -> void:
	_ensure_tier_badge()

func _ensure_tier_badge() -> void:
	if _tier_badge != null and is_instance_valid(_tier_badge):
		return
	_tier_badge = PanelContainer.new()
	_tier_badge.name = "TierBadge"
	_tier_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_badge.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.16, 0.95)
	style.border_color = Color(1.0, 0.82, 0.28, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	_tier_badge.add_theme_stylebox_override("panel", style)

	_tier_label = Label.new()
	_tier_label.name = "TierLabel"
	_tier_label.add_theme_font_size_override("font_size", 9)
	_tier_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tier_badge.add_child(_tier_label)

	add_child(_tier_badge)
	_tier_badge.layout_mode = 1
	_tier_badge.anchors_preset = Control.PRESET_TOP_RIGHT
	_tier_badge.anchor_left = 1.0
	_tier_badge.anchor_right = 1.0
	_tier_badge.anchor_top = 0.0
	_tier_badge.anchor_bottom = 0.0
	_tier_badge.offset_left = -40.0
	_tier_badge.offset_top = -2.0
	_tier_badge.offset_right = 4.0
	_tier_badge.offset_bottom = 16.0

## skill_def = null -> hiện ô trống "+" (chưa gắn skill), bấm không làm gì.
func setup(skill_def: SkillDefinition, main: bool) -> void:
	skill = skill_def
	is_main = main
	_ensure_tier_badge()

	## Đường kính lấy theo kích thước đặt trong SkillBarUI.tscn (ô chính lớn hơn ô phụ); chưa đặt thì mặc định.
	var diameter := custom_minimum_size.x if custom_minimum_size.x > 0.0 else (108.0 if main else 64.0)
	custom_minimum_size = Vector2(diameter, diameter)
	apply_round_style(self, diameter)
	if _lock_overlay:
		_lock_overlay.add_theme_stylebox_override("panel", make_round_style(diameter, Color(0.1, 0.1, 0.1, 0.6), Color.TRANSPARENT, 0))
	autowrap_mode = TextServer.AUTOWRAP_WORD
	add_theme_font_size_override("font_size", 13 if main else 11)
	self_modulate = EMPTY_SLOT_TINT if skill_def == null else Color.WHITE

	if skill_def == null:
		tooltip_text = ""
		if _icon:
			_icon.texture = null
		text = "+"
		add_theme_font_size_override("font_size", 24)
		if _tier_badge:
			_tier_badge.visible = false
		return

	if _icon:
		_icon.texture = skill_def.icon
	text = skill_def.skill_name if skill_def.icon == null else ""

	# Không hiển thị nhãn tầng trên nút skill ngoài map (theo yêu cầu UI)
	if _tier_badge:
		_tier_badge.visible = false

	## Bỏ tooltip ở slot skill ngoài map chơi (tránh che khuất tầm nhìn chiến đấu)
	tooltip_text = ""

func _make_custom_tooltip(_for_text: String) -> Object:
	return null

static func get_child_skills(parent_skill: SkillDefinition) -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	if parent_skill == null:
		return result
	for sect in SectRegistry.load_all():
		for candidate in sect.skills:
			if candidate.parent_skill_id == parent_skill.id:
				result.append(candidate)
	result.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool:
		return get_skill_tier(a) < get_skill_tier(b)
	)
	return result

static func get_skill_tier(s: SkillDefinition) -> int:
	var text := (s.skill_name + " " + s.description).to_lower()
	if "tầng 2" in text or "tăng 2" in text or "tầng thứ 2" in text:
		return 2
	if "tầng 3" in text or "tăng 3" in text or "tầng thứ 3" in text:
		return 3
	if "tầng 4" in text or "tăng 4" in text or "tầng thứ 4" in text:
		return 4
	return 2

## learned = true nếu là skill chính (luôn dùng được) hoặc skill phụ đã học >=1 cấp.
func refresh(_cooldown_ratio: float, learned: bool) -> void:
	if _lock_overlay:
		_lock_overlay.visible = not learned
	disabled = not learned

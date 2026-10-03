extends Button
class_name SkillButton
## 1 nút skill TRÒN viền trắng trong SkillBarUI — vẽ icon + overlay hồi chiêu dạng radial
## (TextureProgressBar dùng texture hình tròn, fill ngược chiều kim đồng hồ, thu nhỏ dần khi hết
## cooldown) + khoá xám khi skill phụ chưa học. Nút phụ có thể là ô TRỐNG (skill = null) khi người
## chơi chưa gắn skill vào ô đó.

const SLOT_BG := Color(0.1, 0.12, 0.16, 0.85)
const SLOT_BG_HOVER := Color(0.18, 0.2, 0.26, 0.9)
const SLOT_BORDER := Color(1, 1, 1, 0.95)
const BORDER_WIDTH := 2
const CIRCLE_MASK_SHADER := preload("res://ui/shaders/circle_mask.gdshader")

@onready var _icon: TextureRect = %Icon
@onready var _cooldown_overlay: TextureProgressBar = %CooldownOverlay
@onready var _lock_overlay: Panel = %LockOverlay

var skill: SkillDefinition
var is_main: bool = false

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

## Material cắt icon vuông thành hình tròn (cùng shader với node Icon trong SkillButton.tscn).
static func make_circle_mask_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CIRCLE_MASK_SHADER
	return material

static func apply_round_style(button: Button, diameter: float) -> void:
	var normal := make_round_style(diameter, SLOT_BG)
	var hover := make_round_style(diameter, SLOT_BG_HOVER)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## skill_def = null -> hiện ô trống "+" (chưa gắn skill), bấm không làm gì.
func setup(skill_def: SkillDefinition, main: bool) -> void:
	skill = skill_def
	is_main = main
	## Đường kính lấy theo kích thước đặt trong SkillBarUI.tscn (ô chính lớn hơn ô phụ); chưa đặt thì mặc định.
	var diameter := custom_minimum_size.x if custom_minimum_size.x > 0.0 else (108.0 if main else 64.0)
	custom_minimum_size = Vector2(diameter, diameter)
	apply_round_style(self, diameter)
	_lock_overlay.add_theme_stylebox_override("panel", make_round_style(diameter, Color(0.1, 0.1, 0.1, 0.6), Color.TRANSPARENT, 0))
	autowrap_mode = TextServer.AUTOWRAP_WORD
	add_theme_font_size_override("font_size", 13 if main else 11)
	if skill_def == null:
		_icon.texture = null
		text = "+"
		add_theme_font_size_override("font_size", 24)
		return
	_icon.texture = skill_def.icon
	## Ảnh skill gốc VLTK (tools/import_vltk_skill_icons.py); skill hiếm hoi không có ảnh -> hiện tên skill.
	text = skill_def.skill_name if skill_def.icon == null else ""

## learned = true nếu là skill chính (luôn dùng được) hoặc skill phụ đã học >=1 cấp.
func refresh(cooldown_ratio: float, learned: bool) -> void:
	_cooldown_overlay.value = cooldown_ratio * 100.0
	_lock_overlay.visible = not learned
	disabled = not learned

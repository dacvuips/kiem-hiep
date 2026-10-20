extends Control
class_name AgeRatingBadge

## BIỂU TƯỢNG PHÂN LOẠI ĐỘ TUỔI 18+ THEO QUY ĐỊNH PHÁP LUẬT VIỆT NAM (Thông tư 24/2014 & Nghị định 147/2024)
## Hiển thị liên tục ở góc trên bên trái màn hình trong suốt thời gian chơi game.

const BADGE_SIZE := Vector2(44.0, 44.0)
const BADGE_POS := Vector2(18.0, 10.0)
const BADGE_PATH := "res://assets/ui/badge_18.png"

var _tex_rect: TextureRect

func _init() -> void:
	name = "AgeRatingBadge"
	mouse_filter = Control.MOUSE_FILTER_PASS
	position = BADGE_POS
	custom_minimum_size = BADGE_SIZE
	size = BADGE_SIZE

	_tex_rect = TextureRect.new()
	_tex_rect.name = "BadgeTexture"
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_tex_rect.tooltip_text = "Trò chơi dành cho người chơi từ 18 tuổi trở lên (18+)\nChơi quá 180 phút một ngày sẽ ảnh hưởng xấu đến sức khỏe"

	# Load texture: thử ResourceLoader trước, nếu chưa import thì load trực tiếp từ file PNG
	var tex: Texture2D = null
	if ResourceLoader.exists(BADGE_PATH):
		tex = load(BADGE_PATH) as Texture2D
	if tex == null:
		var global_p := ProjectSettings.globalize_path(BADGE_PATH)
		var img := Image.load_from_file(global_p)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_tex_rect.texture = tex
	add_child(_tex_rect)

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_info_popup()

func _show_info_popup() -> void:
	# Toast thông báo ngắn gọn khi chạm/bấm vào biểu tượng 18+
	if get_node_or_null("NoticeLabel") != null:
		return
	var label := Label.new()
	label.name = "NoticeLabel"
	label.text = "Trò chơi dành cho người từ 18 tuổi trở lên (18+)\nChơi quá 180 phút một ngày sẽ ảnh hưởng xấu đến sức khỏe"
	label.position = Vector2(BADGE_SIZE.x + 8.0, 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.92)
	style.border_color = Color(0.83, 0.68, 0.21, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	label.add_theme_stylebox_override("panel", style)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.75))
	add_child(label)

	var tween := create_tween()
	if tween:
		tween.tween_interval(3.0)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free)

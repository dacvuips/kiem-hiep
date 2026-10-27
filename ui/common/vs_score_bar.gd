extends Control
class_name VsScoreBar
## Thanh hiển thị tỷ số trận đấu VS phong cách Tống Kim / PK
## Banner nghệ thuật Tống (Đỏ/Vàng) vs Kim (Xanh) với biểu tượng VS rực lửa ở trung tâm.
## Text và số được bố trí chuẩn xác theo tham chiếu:
##   - Bên Trái (Đỏ): [Tên Phe 1 (Vàng kim)]  [Điểm số 1 (Trắng sáng)]
##   - Giữa: Biểu tượng VS rực lửa & đồng hồ thời gian trận đấu (ngay dưới VS)
##   - Bên Phải (Xanh): [Điểm số 2 (Trắng sáng)]  [Tên Phe 2 (Xanh lam)]

const TEX_PATH := "res://assets/ui/vs_score_bar.png"

# Màu sắc chuẩn theo thiết kế tham chiếu
const COLOR_LEFT_NAME := Color(0.98, 0.85, 0.55)      # Vàng kim ấm (Tống / Phe Ta)
const COLOR_LEFT_SCORE := Color(1.0, 0.96, 0.95)     # Trắng sáng ánh ấm
const COLOR_RIGHT_SCORE := Color(0.92, 0.97, 1.0)    # Trắng sáng ánh lam
const COLOR_RIGHT_NAME := Color(0.40, 0.85, 1.0)     # Xanh lam sáng (Kim / Phe Địch)
const COLOR_TIMER := Color(1.0, 0.92, 0.45)          # Vàng tươi đồng hồ trận

var _banner_rect: Control
var _bg_tex: TextureRect
var _left_name_lbl: Label
var _left_score_lbl: Label
var _right_score_lbl: Label
var _right_name_lbl: Label
var _timer_lbl: Label
var _title_lbl: Label
var _subtitle_lbl: Label

static func get_banner_texture() -> Texture2D:
	if ResourceLoader.exists(TEX_PATH):
		var res: Variant = load(TEX_PATH)
		if res is Texture2D:
			return res
	var global_path := ProjectSettings.globalize_path(TEX_PATH)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_left = -230.0
	offset_right = 230.0
	offset_top = 48.0
	offset_bottom = 112.0
	custom_minimum_size = Vector2(460, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _build_ui() -> void:
	# 1. Tiêu đề phía trên (tùy chọn)
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 13)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_lbl.add_theme_constant_override("outline_size", 3)
	_title_lbl.position = Vector2(0, -18)
	_title_lbl.size = Vector2(460, 18)
	_title_lbl.visible = false
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_lbl)

	# 2. Khung Banner chính (460 x 58)
	_banner_rect = Control.new()
	_banner_rect.custom_minimum_size = Vector2(460, 58)
	_banner_rect.size = Vector2(460, 58)
	_banner_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_rect)

	_bg_tex = TextureRect.new()
	_bg_tex.texture = get_banner_texture()
	_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_rect.add_child(_bg_tex)

	# 3. Phía bên trái (Đỏ): Tên phe (x=16..130) + Số điểm (x=130..200)
	_left_name_lbl = Label.new()
	_left_name_lbl.text = "Tướng Tống"
	_left_name_lbl.position = Vector2(16, 15)
	_left_name_lbl.size = Vector2(114, 30)
	_left_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_left_name_lbl.add_theme_font_size_override("font_size", 16)
	_left_name_lbl.add_theme_color_override("font_color", COLOR_LEFT_NAME)
	_left_name_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.02, 0.95))
	_left_name_lbl.add_theme_constant_override("outline_size", 4)
	_left_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_rect.add_child(_left_name_lbl)

	_left_score_lbl = Label.new()
	_left_score_lbl.text = "100%"
	_left_score_lbl.position = Vector2(130, 14)
	_left_score_lbl.size = Vector2(70, 32)
	_left_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_left_score_lbl.add_theme_font_size_override("font_size", 20)
	_left_score_lbl.add_theme_color_override("font_color", COLOR_LEFT_SCORE)
	_left_score_lbl.add_theme_color_override("font_outline_color", Color(0.25, 0.04, 0.04, 0.95))
	_left_score_lbl.add_theme_constant_override("outline_size", 4)
	_left_score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_rect.add_child(_left_score_lbl)

	# 4. Phía bên phải (Xanh): Số điểm (x=260..330) + Tên phe (x=330..444)
	_right_score_lbl = Label.new()
	_right_score_lbl.text = "100%"
	_right_score_lbl.position = Vector2(260, 14)
	_right_score_lbl.size = Vector2(70, 32)
	_right_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_right_score_lbl.add_theme_font_size_override("font_size", 20)
	_right_score_lbl.add_theme_color_override("font_color", COLOR_RIGHT_SCORE)
	_right_score_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.25, 0.95))
	_right_score_lbl.add_theme_constant_override("outline_size", 4)
	_right_score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_rect.add_child(_right_score_lbl)

	_right_name_lbl = Label.new()
	_right_name_lbl.text = "Tướng Kim"
	_right_name_lbl.position = Vector2(330, 15)
	_right_name_lbl.size = Vector2(114, 30)
	_right_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_right_name_lbl.add_theme_font_size_override("font_size", 16)
	_right_name_lbl.add_theme_color_override("font_color", COLOR_RIGHT_NAME)
	_right_name_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.18, 0.95))
	_right_name_lbl.add_theme_constant_override("outline_size", 4)
	_right_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_rect.add_child(_right_name_lbl)

	# 5. Đồng hồ thời gian trận đấu (ngay dưới biểu tượng VS trung tâm)
	_timer_lbl = Label.new()
	_timer_lbl.text = ""
	_timer_lbl.position = Vector2(180, 56)
	_timer_lbl.size = Vector2(100, 20)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_lbl.add_theme_font_size_override("font_size", 14)
	_timer_lbl.add_theme_color_override("font_color", COLOR_TIMER)
	_timer_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer_lbl.add_theme_constant_override("outline_size", 3)
	_timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer_lbl)

	# 6. Dòng thông tin phụ phía dưới (sub info / phase)
	_subtitle_lbl = Label.new()
	_subtitle_lbl.text = ""
	_subtitle_lbl.position = Vector2(0, 74)
	_subtitle_lbl.size = Vector2(460, 20)
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_lbl.add_theme_font_size_override("font_size", 12)
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_subtitle_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_subtitle_lbl.add_theme_constant_override("outline_size", 3)
	_subtitle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_lbl.visible = false
	add_child(_subtitle_lbl)

## Đặt tên và điểm số 2 bên
func set_sides(left_name: String, left_score: Variant, right_score: Variant, right_name: String) -> void:
	set_left(left_name, left_score)
	set_right(right_name, right_score)

func set_left(name: String, score: Variant) -> void:
	if name != "":
		_left_name_lbl.text = name
		_left_name_lbl.add_theme_font_size_override("font_size", 16 if name.length() > 6 else 19)
	_left_score_lbl.text = str(score)
	_left_score_lbl.add_theme_font_size_override("font_size", 20 if str(score).length() >= 4 else 22)

func set_right(name: String, score: Variant) -> void:
	if name != "":
		_right_name_lbl.text = name
		_right_name_lbl.add_theme_font_size_override("font_size", 16 if name.length() > 6 else 19)
	_right_score_lbl.text = str(score)
	_right_score_lbl.add_theme_font_size_override("font_size", 20 if str(score).length() >= 4 else 22)

func set_scores(left_score: Variant, right_score: Variant) -> void:
	_left_score_lbl.text = str(left_score)
	_left_score_lbl.add_theme_font_size_override("font_size", 20 if str(left_score).length() >= 4 else 22)
	_right_score_lbl.text = str(right_score)
	_right_score_lbl.add_theme_font_size_override("font_size", 20 if str(right_score).length() >= 4 else 22)

func set_names(left_name: String, right_name: String) -> void:
	if left_name != "":
		_left_name_lbl.text = left_name
		_left_name_lbl.add_theme_font_size_override("font_size", 16 if left_name.length() > 6 else 19)
	if right_name != "":
		_right_name_lbl.text = right_name
		_right_name_lbl.add_theme_font_size_override("font_size", 16 if right_name.length() > 6 else 19)

func set_name_colors(left_color: Color, right_color: Color) -> void:
	if _left_name_lbl:
		_left_name_lbl.add_theme_color_override("font_color", left_color)
	if _right_name_lbl:
		_right_name_lbl.add_theme_color_override("font_color", right_color)

func set_timer(time_str: String) -> void:
	_timer_lbl.text = time_str
	_timer_lbl.visible = not time_str.is_empty()

func set_title(title_text: String) -> void:
	_title_lbl.text = title_text
	_title_lbl.visible = not title_text.is_empty()

func set_subtitle(sub_text: String) -> void:
	_subtitle_lbl.text = sub_text
	_subtitle_lbl.visible = not sub_text.is_empty()

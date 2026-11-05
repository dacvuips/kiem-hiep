extends CanvasLayer

## SceneTransition: Hệ thống chuyển cảnh & màn hình tải mượt mà (Fade & Loading Overlay).
## Đảm bảo khi đổi map hoặc chuyển scene không bao giờ bị lộ màu xám mặc định của Godot.

signal transition_finished

const TIPS: Array[String] = [
	"Hành tẩu giang hồ, dĩ hòa vi quý...",
	"Thập đại môn phái, ngũ hành tương sinh tương khắc...",
	"Luyện công nơi thâm sơn cùng cốc, tôi luyện ý chí anh hùng...",
	"Trang bị đúng hệ ngũ hành để kích hoạt thuộc tính ẩn...",
	"Gia nhập bang hội để cùng huynh đệ chinh chiến công thành...",
	"Tọa kỵ thần mã giúp đại hiệp gia tăng đáng kể tốc độ di chuyển...",
	"Dược liệu trân quý từ Dược Điếm là hành trang không thể thiếu khi xuất chiến..."
]

var _is_transitioning: bool = false
var _overlay: Control
var _bg: ColorRect
var _content: VBoxContainer
var _title_label: Label
var _tip_label: Label
var _dots_label: Label
var _dots_timer: float = 0.0

func _init() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build_ui()
	_set_overlay_visible(false)

func _process(delta: float) -> void:
	if _is_transitioning and is_instance_valid(_dots_label):
		_dots_timer += delta * 4.0
		var dots_count := (int(_dots_timer) % 4)
		_dots_label.text = ".".repeat(dots_count)

func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.name = "TransitionOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Nền đen tuyền
	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.color = Color(0.04, 0.04, 0.05, 1.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_bg)

	# Khung nội dung ở giữa màn hình
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.set_anchors_preset(Control.PRESET_CENTER)
	_content.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_content.grow_vertical = Control.GROW_DIRECTION_BOTH
	_content.custom_minimum_size = Vector2(400, 150)
	_content.add_theme_constant_override("separation", 12)
	_overlay.add_child(_content)

	# Tiêu đề Map / Tải cảnh
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(title_row)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "Đang Chuyển Bản Đồ"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.38)) # Vàng hoàng kim
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_row.add_child(_title_label)

	_dots_label = Label.new()
	_dots_label.name = "DotsLabel"
	_dots_label.text = "..."
	_dots_label.custom_minimum_size = Vector2(24, 0)
	_dots_label.add_theme_font_size_override("font_size", 22)
	_dots_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.38))
	title_row.add_child(_dots_label)

	# Đường kẻ chỉ vàng trang trí
	var line := ColorRect.new()
	line.name = "Divider"
	line.color = Color(0.76, 0.63, 0.32, 0.6)
	line.custom_minimum_size = Vector2(240, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(line)

	# Gợi ý / Danh ngôn kiếm hiệp
	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	_tip_label.text = TIPS[0]
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(360, 40)
	_tip_label.add_theme_font_size_override("font_size", 13)
	_tip_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72, 0.85))
	_content.add_child(_tip_label)

func _set_overlay_visible(v: bool) -> void:
	if _overlay != null:
		_overlay.visible = v
		_overlay.modulate.a = 1.0 if v else 0.0

## Đổi Scene mượt mà với hiệu ứng mờ đen & màn hình tải
func change_scene(scene_path: String, map_name: String = "", custom_tip: String = "", min_wait: float = 0.35) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	var start_time := Time.get_ticks_msec()

	# Cập nhật thông tin giao diện
	if _title_label != null:
		if map_name.strip_edges() != "":
			_title_label.text = "Tiến Vào %s" % map_name
		else:
			_title_label.text = "Đang Tải Dữ Liệu"

	if _tip_label != null:
		if custom_tip.strip_edges() != "":
			_tip_label.text = custom_tip
		else:
			_tip_label.text = TIPS.pick_random()

	# 1. Bật overlay và chặn chuột click
	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# 2. Fade to black (Mờ dần vào màn đen)
	var tween_in := create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_in.tween_property(_overlay, "modulate:a", 1.0, 0.2).from(0.0)
	await tween_in.finished

	# 3. Chuyển scene chính thức
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneTransition: Lỗi khi chuyển scene '%s': %d" % [scene_path, err])

	# 4. Đợi Scene mới khởi tạo và render xong các frame đầu tiên
	# Chờ tối thiểu 3 frame để Main.tscn dựng Player, Camera2D và VltkMap hoàn tất warm_up
	for i in 4:
		await get_tree().process_frame

	# 5. Đảm bảo thời gian hiển thị tối thiểu để người chơi không bị nhấp nháy màn hình
	var elapsed := (Time.get_ticks_msec() - start_time) / 1000.0
	if elapsed < min_wait:
		await get_tree().create_timer(min_wait - elapsed).timeout

	# 6. Fade from black (Mở sáng thế giới game)
	var tween_out := create_tween()
	tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_out.tween_property(_overlay, "modulate:a", 0.0, 0.25)
	await tween_out.finished

	# 7. Hoàn tất
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit()

## Fade out nhanh (dùng khi chỉ muốn tối dần màn hình)
func fade_out_async(duration: float = 0.25) -> void:
	if _overlay == null:
		return
	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.visible = false
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_overlay, "modulate:a", 1.0, duration).from(_overlay.modulate.a)
	await tween.finished

## Fade in nhanh (sáng dần trở lại)
func fade_in_async(duration: float = 0.25) -> void:
	if _overlay == null:
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_overlay, "modulate:a", 0.0, duration).from(_overlay.modulate.a)
	await tween.finished
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.visible = true

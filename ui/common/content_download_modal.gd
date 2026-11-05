extends CanvasLayer

## Modal chờ nạp tài nguyên thế giới (Dành cho bản Web khi người chơi vào game trước khi tải ngầm xong)

var _overlay: ColorRect
var _panel: PanelContainer
var _pct_label: Label
var _bar: ProgressBar
var _bytes_label: Label
var _speed_label: Label
var _tip_label: Label
var _tip_timer: Timer

const TIPS := [
	"Ngũ Hành Tương Khắc: Kim > Mộc > Thổ > Thủy > Hỏa > Kim. Tấn công hệ bị khắc nhận thêm 30% sát thương!",
	"Đặc tính Ngũ Hành: Kim gây Thọ Thương, Mộc gây Trúng Độc, Thủy gây Làm Chậm, Hỏa gây Bỏng Cháy, Thổ gây Choáng.",
	"Treo Máy Bế Quan: Dù bạn thoát game, nhân vật vẫn miệt mài tu luyện, tích lũy Bạc, Exp và nhặt trang bị quý.",
	"Cường Hóa Huyền Tinh: Đạt mốc cường hóa +4, +8, +12, +16 sẽ kích hoạt các dòng thuộc tính ẩn cực mạnh.",
	"Cộng Điểm Tiềm Năng: Thiếu Lâm/Thiên Vương nâng Sức Mạnh & Thể Lực; Nga Mi/Thúy Yên ưu tiên Nội Công; Đường Môn cần Thân Pháp."
]

func _init() -> void:
	layer = 120

func _ready() -> void:
	_build_ui()
	
	# Kết nối signal từ WebContentManager
	var mgr = get_node_or_null("/root/WebContentManager")
	if mgr:
		mgr.progress_updated.connect(_on_progress)
		mgr.content_loaded.connect(_on_content_loaded)
		_on_progress(mgr.progress_percent, mgr.loaded_bytes, mgr.total_bytes, mgr.download_speed)
	
	_start_tip_cycle()

func _build_ui() -> void:
	# Nền tối mờ toàn màn hình
	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.015, 0.01, 0.88)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(480, 240)
	
	# StyleBox khung hoàng kim wuxia
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.96)
	sb.border_color = Color(0.85, 0.70, 0.35, 0.75)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0, 0, 0, 0.8)
	sb.shadow_size = 25
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Header
	var title := Label.new()
	title.text = "⚔️ ĐANG CHUẨN BỊ THẾ GIỚI VÕ LÂM ⚔️"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = "Tài nguyên bản đồ và hiệu ứng chiêu thức đang được nạp vào máy.\nQuá trình này chỉ cần tải 1 lần duy nhất!"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72))
	desc.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc)
	
	vbox.add_spacer(false)
	
	# Progress Header
	var hbox_header := HBoxContainer.new()
	var state_lbl := Label.new()
	state_lbl.text = "Tiến độ nạp tài nguyên:"
	state_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	state_lbl.add_theme_font_size_override("font_size", 12)
	hbox_header.add_child(state_lbl)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_header.add_child(spacer)
	
	_pct_label = Label.new()
	_pct_label.text = "0%"
	_pct_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_pct_label.add_theme_font_size_override("font_size", 15)
	hbox_header.add_child(_pct_label)
	vbox.add_child(hbox_header)
	
	# Progress Bar
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.07, 0.05, 0.03, 1.0)
	bar_bg.corner_radius_top_left = 7
	bar_bg.corner_radius_top_right = 7
	bar_bg.corner_radius_bottom_left = 7
	bar_bg.corner_radius_bottom_right = 7
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.96, 0.62, 0.10)
	bar_fill.corner_radius_top_left = 7
	bar_fill.corner_radius_top_right = 7
	bar_fill.corner_radius_bottom_left = 7
	bar_fill.corner_radius_bottom_right = 7
	_bar.add_theme_stylebox_override("background", bar_bg)
	_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_bar)
	
	# Progress Footer
	var hbox_footer := HBoxContainer.new()
	_bytes_label = Label.new()
	_bytes_label.text = "Đang khởi tạo..."
	_bytes_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.52))
	_bytes_label.add_theme_font_size_override("font_size", 11)
	hbox_footer.add_child(_bytes_label)
	
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_footer.add_child(spacer2)
	
	_speed_label = Label.new()
	_speed_label.text = ""
	_speed_label.add_theme_color_override("font_color", Color(0.25, 0.75, 1.0))
	_speed_label.add_theme_font_size_override("font_size", 11)
	hbox_footer.add_child(_speed_label)
	vbox.add_child(hbox_footer)
	
	# Tip Box
	var tip_panel := PanelContainer.new()
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0.04, 0.03, 0.02, 0.8)
	tip_sb.corner_radius_top_left = 6
	tip_sb.corner_radius_top_right = 6
	tip_sb.corner_radius_bottom_left = 6
	tip_sb.corner_radius_bottom_right = 6
	tip_panel.add_theme_stylebox_override("panel", tip_sb)
	
	var tip_margin := MarginContainer.new()
	tip_margin.add_theme_constant_override("margin_left", 8)
	tip_margin.add_theme_constant_override("margin_right", 8)
	tip_margin.add_theme_constant_override("margin_top", 6)
	tip_margin.add_theme_constant_override("margin_bottom", 6)
	tip_panel.add_child(tip_margin)
	
	_tip_label = Label.new()
	_tip_label.text = "💡 " + TIPS[0]
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	_tip_label.add_theme_font_size_override("font_size", 11)
	tip_margin.add_child(_tip_label)
	vbox.add_child(tip_panel)

func _format_bytes(bytes: int) -> String:
	if bytes <= 0:
		return "0 MB"
	if bytes >= 1073741824:
		return "%.2f GB" % (bytes / 1073741824.0)
	return "%.1f MB" % (bytes / 1048576.0)

func _on_progress(pct: int, loaded: int, total: int, speed: String) -> void:
	if _bar:
		_bar.value = pct
	if _pct_label:
		_pct_label.text = "%d%%" % pct
	if _bytes_label:
		if total > 0:
			_bytes_label.text = "%s / %s" % [_format_bytes(loaded), _format_bytes(total)]
		else:
			_bytes_label.text = _format_bytes(loaded)
	if _speed_label:
		_speed_label.text = speed

func _on_content_loaded() -> void:
	if _pct_label:
		_pct_label.text = "100%"
	if _bar:
		_bar.value = 100
	if _bytes_label:
		_bytes_label.text = "Nạp xong!"
	
	# Fade out và đóng modal
	var tween := create_tween()
	tween.tween_property(self, "offset:y", -30, 0.25)
	tween.parallel().tween_property(_overlay, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _start_tip_cycle() -> void:
	_tip_timer = Timer.new()
	_tip_timer.wait_time = 4.0
	_tip_timer.autostart = true
	add_child(_tip_timer)
	_tip_timer.timeout.connect(func():
		var tip = TIPS.pick_random()
		if _tip_label:
			_tip_label.text = "💡 " + tip
	)

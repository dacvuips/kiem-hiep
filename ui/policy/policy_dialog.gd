extends CanvasLayer
class_name PolicyDialog
## BẢNG ĐIỀU KHOẢN & CHÍNH SÁCH DỊCH VỤ:
## Hiển thị ngay trên màn hình đăng nhập trước khi cho phép người chơi đăng nhập.
## Chỉ hiển thị 1 lần duy nhất; sau khi người chơi bấm "Đồng Ý & Tiếp Tục",
## lưu trạng thái vào user://policy_accepted.cfg và lần sau không hiển thị nữa.
## Sử dụng khung UI của màn hình Chọn Server (ServerSelect).

signal accepted_done

const CFG_PATH := "user://policy_accepted.cfg"

static var _current_dialog: CanvasLayer = null

var _dim: ColorRect
var _panel: Panel
var _check: CheckBox
var _enter_btn: TextureButton
var _back_btn: Button
var _message: Label
var _content: RichTextLabel

static func is_accepted() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		return bool(cfg.get_value("policy", "accepted", false))
	return false

static func set_accepted(val: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("policy", "accepted", val)
	cfg.set_value("policy", "accepted_time", Time.get_datetime_string_from_system())
	cfg.save(CFG_PATH)

static func reset() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("policy", "accepted", false)
	cfg.save(CFG_PATH)

## Hiển thị bảng điều khoản trên màn hình nếu chưa được chấp nhận
static func show_if_needed(host: Node) -> CanvasLayer:
	if is_accepted():
		return null
	if _current_dialog != null and is_instance_valid(_current_dialog):
		return _current_dialog
	var script: GDScript = load("res://ui/policy/policy_dialog.gd")
	var dlg: CanvasLayer = script.new()
	_current_dialog = dlg
	host.add_child(dlg)
	return dlg

func _ready() -> void:
	layer = 75

	# Nền tối mờ phủ toàn màn hình
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.7)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	# Node Stage co giãn đồng bộ theo kích thước chuẩn 1280x720
	var stage := Control.new()
	stage.name = "Stage"
	stage.set_script(load("res://ui/character_create/stage_fit.gd"))
	stage.set("design_size", Vector2(1280, 720))
	stage.custom_minimum_size = Vector2(1280, 720)
	add_child(stage)

	var font: Font = load("res://assets/fonts/BeVietnamPro-Regular.ttf")

	# --- 1. KHUNG CHÍNH (DialogFrame theo chuẩn ServerSelect) ---
	_panel = Panel.new()
	_panel.offset_left = 270.0
	_panel.offset_top = 44.0
	_panel.offset_right = 1010.0
	_panel.offset_bottom = 666.0

	var dialog_bg := StyleBoxFlat.new()
	dialog_bg.bg_color = Color(0.04, 0.11, 0.13, 0.94)
	dialog_bg.border_width_left = 2
	dialog_bg.border_width_top = 2
	dialog_bg.border_width_right = 2
	dialog_bg.border_width_bottom = 2
	dialog_bg.border_color = Color(0.92, 0.78, 0.45, 1.0)
	dialog_bg.corner_radius_top_left = 18
	dialog_bg.corner_radius_top_right = 18
	dialog_bg.corner_radius_bottom_right = 18
	dialog_bg.corner_radius_bottom_left = 18
	dialog_bg.shadow_color = Color(0, 0, 0, 0.65)
	dialog_bg.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", dialog_bg)
	stage.add_child(_panel)

	# Viền trong (InnerBorder)
	var inner_border := Panel.new()
	inner_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_border.offset_left = 6.0
	inner_border.offset_top = 6.0
	inner_border.offset_right = -6.0
	inner_border.offset_bottom = -6.0
	var inner_sb := StyleBoxFlat.new()
	inner_sb.bg_color = Color(0, 0, 0, 0)
	inner_sb.border_width_left = 1
	inner_sb.border_width_top = 1
	inner_sb.border_width_right = 1
	inner_sb.border_width_bottom = 1
	inner_sb.border_color = Color(0.75, 0.62, 0.35, 0.5)
	inner_sb.corner_radius_top_left = 14
	inner_sb.corner_radius_top_right = 14
	inner_sb.corner_radius_bottom_right = 14
	inner_sb.corner_radius_bottom_left = 14
	inner_border.add_theme_stylebox_override("panel", inner_sb)
	_panel.add_child(inner_border)

	# Dải tiêu đề (TitleBar)
	var title_bar := Panel.new()
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.offset_left = 6.0
	title_bar.offset_top = 6.0
	title_bar.offset_right = -6.0
	title_bar.offset_bottom = 54.0
	var title_sb := StyleBoxFlat.new()
	title_sb.bg_color = Color(0.08, 0.2, 0.23, 0.65)
	title_sb.border_width_bottom = 1
	title_sb.border_color = Color(0.85, 0.72, 0.45, 0.5)
	title_sb.corner_radius_top_left = 14
	title_sb.corner_radius_top_right = 14
	title_bar.add_theme_stylebox_override("panel", title_sb)
	_panel.add_child(title_bar)

	# Tiêu đề chữ
	var title_lbl := Label.new()
	title_lbl.offset_left = 270.0
	title_lbl.offset_top = 50.0
	title_lbl.offset_right = 1010.0
	title_lbl.offset_bottom = 98.0
	title_lbl.text = "ĐIỀU KHOẢN & CHÍNH SÁCH DỊCH VỤ"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", font)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.55))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.14))
	title_lbl.add_theme_constant_override("outline_size", 6)
	stage.add_child(title_lbl)

	# --- 2. THẺ NỘI DUNG (ContentCard & Scroll) ---
	var content_card := Panel.new()
	content_card.offset_left = 295.0
	content_card.offset_top = 110.0
	content_card.offset_right = 985.0
	content_card.offset_bottom = 496.0
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.02, 0.06, 0.07, 0.65)
	card_sb.border_width_left = 1
	card_sb.border_width_top = 1
	card_sb.border_width_right = 1
	card_sb.border_width_bottom = 1
	card_sb.border_color = Color(0.2, 0.38, 0.4, 0.5)
	card_sb.corner_radius_top_left = 10
	card_sb.corner_radius_top_right = 10
	card_sb.corner_radius_bottom_right = 10
	card_sb.corner_radius_bottom_left = 10
	content_card.add_theme_stylebox_override("panel", card_sb)
	stage.add_child(content_card)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 14.0
	scroll.offset_top = 12.0
	scroll.offset_right = -14.0
	scroll.offset_bottom = -12.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_card.add_child(scroll)

	_content = RichTextLabel.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.bbcode_enabled = true
	_content.fit_content = true
	_content.scroll_active = false
	_content.add_theme_font_override("normal_font", font)
	_content.add_theme_font_size_override("normal_font_size", 14)
	scroll.add_child(_content)

	_setup_policy_text()

	# --- 3. CHECKBOX ĐỒNG Ý ---
	_check = CheckBox.new()
	_check.offset_left = 310.0
	_check.offset_top = 508.0
	_check.offset_right = 970.0
	_check.offset_bottom = 544.0
	_check.focus_mode = Control.FOCUS_NONE
	_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_check.text = " Tôi đã đọc, hiểu rõ và đồng ý với tất cả Điều Khoản & Chính Sách"
	_check.add_theme_font_override("font", font)
	_check.add_theme_font_size_override("font_size", 14)
	_check.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	_check.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.45))
	_check.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
	_check.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_check.add_theme_constant_override("outline_size", 4)
	if ResourceLoader.exists("res://ui/login/icon_check.png"):
		_check.add_theme_icon_override("checked", load("res://ui/login/icon_check.png"))
	if ResourceLoader.exists("res://ui/login/icon_uncheck.png"):
		_check.add_theme_icon_override("unchecked", load("res://ui/login/icon_uncheck.png"))
	stage.add_child(_check)

	# Nhãn thông báo
	_message = Label.new()
	_message.offset_left = 295.0
	_message.offset_top = 546.0
	_message.offset_right = 985.0
	_message.offset_bottom = 572.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_override("font", font)
	_message.add_theme_font_size_override("font_size", 13)
	_message.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_message.add_theme_constant_override("outline_size", 4)
	_message.visible = false
	stage.add_child(_message)

	# --- 4. NÚT THAO TÁC (Từ Chối / Đồng Ý & Tiếp Tục) ---
	_back_btn = Button.new()
	_back_btn.text = "Từ Chối"
	_back_btn.offset_left = 360.0
	_back_btn.offset_top = 578.0
	_back_btn.offset_right = 500.0
	_back_btn.offset_bottom = 626.0
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_back_btn.add_theme_font_override("font", font)
	_back_btn.add_theme_font_size_override("font_size", 16)
	_back_btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	var back_sb := StyleBoxFlat.new()
	back_sb.bg_color = Color(0.08, 0.16, 0.18, 0.75)
	back_sb.border_width_left = 1
	back_sb.border_width_top = 1
	back_sb.border_width_right = 1
	back_sb.border_width_bottom = 1
	back_sb.border_color = Color(0.85, 0.72, 0.45, 0.6)
	back_sb.corner_radius_top_left = 16
	back_sb.corner_radius_top_right = 16
	back_sb.corner_radius_bottom_right = 16
	back_sb.corner_radius_bottom_left = 16
	_back_btn.add_theme_stylebox_override("normal", back_sb)
	_back_btn.pressed.connect(_on_decline_pressed)
	stage.add_child(_back_btn)

	_enter_btn = TextureButton.new()
	_enter_btn.offset_left = 535.0
	_enter_btn.offset_top = 572.0
	_enter_btn.offset_right = 815.0
	_enter_btn.offset_bottom = 632.0
	_enter_btn.focus_mode = Control.FOCUS_NONE
	_enter_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_enter_btn.ignore_texture_size = true
	_enter_btn.stretch_mode = TextureButton.STRETCH_SCALE
	if ResourceLoader.exists("res://ui/login/btn_blank.png"):
		_enter_btn.texture_normal = load("res://ui/login/btn_blank.png")
	_enter_btn.pressed.connect(_on_agree_pressed)
	stage.add_child(_enter_btn)

	var enter_lbl := Label.new()
	enter_lbl.text = "Đồng Ý & Tiếp Tục"
	enter_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	enter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enter_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enter_lbl.add_theme_font_override("font", font)
	enter_lbl.add_theme_font_size_override("font_size", 18)
	enter_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	enter_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	enter_lbl.add_theme_constant_override("outline_size", 5)
	_enter_btn.add_child(enter_lbl)

	# Hiệu ứng phóng to nhẹ nhàng khi xuất hiện
	_panel.pivot_offset = Vector2(370, 310)
	_panel.scale = Vector2(0.94, 0.94)
	_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2)

func _setup_policy_text() -> void:
	var bb := ""
	bb += "[b][color=#FFD54F]KÍNH CHÀO QUÝ HIỆP KHÁCH BỐN PHƯƠNG,[/color][/b]\n"
	bb += "Chào mừng quý nhân sĩ đã gia nhập thế giới võ lâm [color=#FFD54F][b]Kiếm Hiệp[/b][/color]. Để xây dựng một môi trường giang hồ công bằng, an toàn và lành mạnh, xin vui lòng đọc kỹ và tuân thủ các điều khoản dịch vụ dưới đây trước khi đăng nhập trải nghiệm trò chơi.\n\n"

	bb += "[b][color=#81C784]I. ĐIỀU KHOẢN DỊCH VỤ & THỎA THUẬN NGƯỜI CHƠI[/color][/b]\n"
	bb += "1. [color=#FFE082]Tôn trọng sân chơi công bằng:[/color] Nghiêm cấm mọi hành vi sử dụng phần mềm thứ ba can thiệp vào game (hack, cheat, mod, auto can thiệp bộ nhớ máy chủ, thay đổi chỉ số nhân vật trái phép). Mọi tài khoản vi phạm sẽ bị khóa vĩnh viễn không cần báo trước.\n"
	bb += "2. [color=#FFE082]Bảo quản thông tin tài khoản:[/color] Quý hiệp khách có trách nhiệm tự bảo mật tài khoản và mật khẩu của mình. Không chia sẻ tài khoản cho người khác để tránh rủi ro mất mát trang bị, tiền tệ và tài sản ảo trong game.\n"
	bb += "3. [color=#FFE082]Quyền sở hữu tài sản số:[/color] Mọi vật phẩm, ngân lượng, trang bị trong trò chơi thuộc quyền quản lý của hệ sinh thái trò chơi. Nghiêm cấm hành vi lợi dụng lỗi game (bug/exploit) để trục lợi; nếu phát hiện cần báo ngay cho Bổn Trang.\n\n"

	bb += "[b][color=#81C784]II. CHÍNH SÁCH BẢO MẬT & BẢO VỆ DỮ LIỆU CÁ NHÂN[/color][/b]\n"
	bb += "1. [color=#FFE082]Mã hóa an toàn:[/color] Mọi thông tin tài khoản và mật khẩu đăng nhập đều được mã hóa một chiều chuẩn quốc tế an toàn cao nhất trước khi lưu trữ vào cơ sở dữ liệu.\n"
	bb += "2. [color=#FFE082]Bảo mật quyền riêng tư:[/color] Ban điều hành cam kết không thu thập dữ liệu trái phép, không tiết lộ, mua bán hay chia sẻ thông tin cá nhân của hiệp khách cho bất kỳ bên thứ ba nào khi chưa có sự chấp thuận của bạn.\n"
	bb += "3. [color=#FFE082]Bảo lưu nhật ký giao dịch:[/color] Hệ thống lưu trữ nhật ký giao dịch, chiến báo và lịch sử nạp/rút để bảo vệ quyền lợi chính đáng của người chơi khi có tranh chấp.\n\n"

	bb += "[b][color=#81C784]III. QUY TẮC ỨNG XỬ & VĂN HÓA VÕ LÂM[/color][/b]\n"
	bb += "1. [color=#FFE082]Văn minh trên các kênh tán gẫu:[/color] Không sử dụng từ ngữ xúc phạm, miệt thị vùng miền, tôn giáo, chính trị hoặc phát tán thông tin độc hại, văn hóa phẩm đồi trụy trên các kênh Thế giới, Bang hội, Mật.\n"
	bb += "2. [color=#FFE082]Giải quyết ân oán công minh:[/color] Mọi tranh chấp, ân oán giang hồ xin hãy phân định tài năng thông qua võ đài PK, Tống Kim Đại Chiến hoặc Đại Hội Võ Lâm.\n\n"

	bb += "[b][color=#81C784]IV. ĐỘ TUỔI QUY ĐỊNH & SỨC KHỎE NGƯỜI CHƠI[/color][/b]\n"
	bb += "1. [color=#FFE082]Độ tuổi tham gia:[/color] Trò chơi có yếu tố giao tranh kiếm hiệp, khuyến nghị dành cho người chơi từ [b]18 tuổi trở lên[/b].\n"
	bb += "2. [color=#FFE082]Khuyến cáo thời lượng:[/color] Chơi game quá 180 phút mỗi ngày có thể gây ảnh hưởng không tốt đến sức khỏe và sinh hoạt hàng ngày. Hãy rèn luyện và nghỉ ngơi điều độ.\n\n"

	bb += "[center][color=#88929A]Bằng việc đánh dấu vào ô bên dưới và bấm \"Đồng Ý & Tiếp Tục\", quý hiệp khách đã xác nhận đã đọc, hiểu rõ và cam kết tuân thủ toàn bộ các điều khoản trên.[/color][/center]"

	_content.text = bb

func _on_agree_pressed() -> void:
	if not _check.button_pressed:
		_show_message("Vui lòng tích chọn ô \"Tôi đã đọc và đồng ý...\" để tiếp tục!")
		_highlight_check()
		return

	# Lưu trạng thái đã chấp nhận (chỉ cần 1 lần duy nhất)
	set_accepted(true)

	_show_message("Đã chấp nhận điều khoản. Đang vào game...", Color(0.4, 0.95, 0.5))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2(0.94, 0.94), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.18)
	tween.tween_property(_dim, "color:a", 0.0, 0.18)
	tween.chain().tween_callback(func() -> void:
		_current_dialog = null
		accepted_done.emit()
		queue_free()
	)

func _on_decline_pressed() -> void:
	_show_message("Hiệp khách cần đồng ý điều khoản dịch vụ để tiếp tục tham gia Kiếm Hiệp.")

func _show_message(msg: String, color: Color = Color(1.0, 0.85, 0.55)) -> void:
	_message.text = msg
	_message.add_theme_color_override("font_color", color)
	_message.visible = true

func _highlight_check() -> void:
	var tw := create_tween()
	tw.tween_property(_check, "modulate", Color(1.0, 0.4, 0.4), 0.15)
	tw.tween_property(_check, "modulate", Color(1.0, 1.0, 1.0), 0.15)
	tw.tween_property(_check, "modulate", Color(1.0, 0.4, 0.4), 0.15)
	tw.tween_property(_check, "modulate", Color(1.0, 1.0, 1.0), 0.15)

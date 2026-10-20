extends CanvasLayer
class_name TelegramCommunityPopup
## POPUP CỘNG ĐỒNG TELEGRAM:
## Hiển thị thông tin nhóm Telegram, mã QR quét bằng điện thoại,
## nút mở nhóm trực tiếp qua trình duyệt/ứng dụng Telegram và nút sao chép liên kết.

const TELEGRAM_URL := "https://t.me/+pHIdQN3dgV45MWM1"
const POPUP_WIDTH := 440.0

static var _current_popup: TelegramCommunityPopup = null

var _dim: ColorRect
var _panel: PanelContainer
var _status_lbl: Label

static func open(host: Node) -> TelegramCommunityPopup:
	if _current_popup != null and is_instance_valid(_current_popup):
		return _current_popup
	var popup := TelegramCommunityPopup.new()
	_current_popup = popup
	host.get_tree().root.add_child(popup)
	return popup

func _ready() -> void:
	layer = 65

	# Nền tối mờ click ra ngoài để đóng
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(_dim)

	# Khung Popup trung tâm
	_panel = PanelContainer.new()
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.08, 0.09, 0.98)
	panel_sb.border_width_left = 2
	panel_sb.border_width_top = 2
	panel_sb.border_width_right = 2
	panel_sb.border_width_bottom = 2
	panel_sb.border_color = Color(0.72, 0.58, 0.28, 0.95)
	panel_sb.corner_radius_top_left = 12
	panel_sb.corner_radius_top_right = 12
	panel_sb.corner_radius_bottom_right = 12
	panel_sb.corner_radius_bottom_left = 12
	panel_sb.shadow_color = Color(0, 0, 0, 0.7)
	panel_sb.shadow_size = 20
	panel_sb.content_margin_left = 20.0
	panel_sb.content_margin_right = 20.0
	panel_sb.content_margin_top = 16.0
	panel_sb.content_margin_bottom = 18.0
	_panel.add_theme_stylebox_override("panel", panel_sb)

	_panel.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# --- 1. TIÊU ĐỀ: Logo Telegram + Tên Popup + Nút Đóng ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var icon_rect := TextureRect.new()
	icon_rect.texture = load("res://ui/social/icon_telegram.png") if ResourceLoader.exists("res://ui/social/icon_telegram.png") else null
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon_rect)

	var title_lbl := Label.new()
	title_lbl.text = "CỘNG ĐỒNG TELEGRAM"
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.custom_minimum_size = Vector2(30, 30)
	var close_sb := _make_box_style(Color(0.18, 0.08, 0.08, 0.9), Color(0.65, 0.25, 0.25, 0.8), 6)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# Đường phân cách
	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = Color(0.72, 0.58, 0.28, 0.4)
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	vbox.add_child(sep)

	# --- 2. MÔ TẢ ---
	var desc := Label.new()
	desc.text = "Gia nhập nhóm Telegram để giao lưu hảo hữu bốn phương, nhận Giftcode tân thủ và thông báo sự kiện mới nhất!"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.85, 0.84, 0.8))
	desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(desc)

	# --- 3. MÃ QR CODE ---
	var qr_center := CenterContainer.new()
	vbox.add_child(qr_center)

	var qr_card := PanelContainer.new()
	var qr_sb := StyleBoxFlat.new()
	qr_sb.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	qr_sb.border_width_left = 2
	qr_sb.border_width_top = 2
	qr_sb.border_width_right = 2
	qr_sb.border_width_bottom = 2
	qr_sb.border_color = Color(0.78, 0.65, 0.32, 1.0)
	qr_sb.corner_radius_top_left = 10
	qr_sb.corner_radius_top_right = 10
	qr_sb.corner_radius_bottom_right = 10
	qr_sb.corner_radius_bottom_left = 10
	qr_sb.content_margin_left = 8.0
	qr_sb.content_margin_right = 8.0
	qr_sb.content_margin_top = 8.0
	qr_sb.content_margin_bottom = 8.0
	qr_card.add_theme_stylebox_override("panel", qr_sb)
	qr_center.add_child(qr_card)

	var qr_rect := TextureRect.new()
	var qr_tex: Texture2D = null
	if FileAccess.file_exists("res://ui/social/telegram_qr.png"):
		var img := Image.load_from_file("res://ui/social/telegram_qr.png")
		if img != null and not img.is_empty():
			qr_tex = ImageTexture.create_from_image(img)
	if qr_tex == null and ResourceLoader.exists("res://ui/social/telegram_qr.png"):
		var res = load("res://ui/social/telegram_qr.png")
		if res is Texture2D:
			qr_tex = res
	qr_rect.texture = qr_tex
	qr_rect.custom_minimum_size = Vector2(175, 212)
	qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr_card.add_child(qr_rect)

	var qr_hint := Label.new()
	qr_hint.text = "📱 Quét mã QR bằng camera điện thoại để vào nhóm"
	qr_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qr_hint.add_theme_color_override("font_color", Color(0.65, 0.72, 0.75))
	qr_hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(qr_hint)

	# --- 4. TRẠNG THÁI PHẢN HỒI ---
	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_color_override("font_color", Color(0.5, 0.95, 0.55))
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.text = ""
	vbox.add_child(_status_lbl)

	# --- 5. NÚT THAO TÁC ---
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_vbox)

	# Nút tham gia trực tiếp (Mở Telegram)
	var open_btn := Button.new()
	open_btn.text = "🚀 Tham Gia Nhóm Telegram"
	open_btn.focus_mode = Control.FOCUS_NONE
	open_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	open_btn.custom_minimum_size = Vector2(0, 42)
	var tg_sb := _make_box_style(Color(0.16, 0.67, 0.93, 1.0), Color(0.55, 0.85, 1.0, 1.0), 8)
	var tg_hover_sb := _make_box_style(Color(0.24, 0.74, 0.98, 1.0), Color(0.75, 0.92, 1.0, 1.0), 8)
	open_btn.add_theme_stylebox_override("normal", tg_sb)
	open_btn.add_theme_stylebox_override("hover", tg_hover_sb)
	open_btn.add_theme_stylebox_override("pressed", tg_hover_sb)
	open_btn.add_theme_color_override("font_color", Color.WHITE)
	open_btn.add_theme_font_size_override("font_size", 14)
	open_btn.pressed.connect(_on_open_telegram)
	btn_vbox.add_child(open_btn)

	# Nút sao chép link nhóm
	var copy_btn := Button.new()
	copy_btn.text = "📋 Sao Chép Liên Kết Nhóm"
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	copy_btn.custom_minimum_size = Vector2(0, 36)
	var cp_sb := _make_box_style(Color(0.12, 0.16, 0.18, 0.9), Color(0.72, 0.58, 0.28, 0.8), 8)
	var cp_hover_sb := _make_box_style(Color(0.18, 0.24, 0.26, 0.95), Color(0.9, 0.75, 0.35, 1.0), 8)
	copy_btn.add_theme_stylebox_override("normal", cp_sb)
	copy_btn.add_theme_stylebox_override("hover", cp_hover_sb)
	copy_btn.add_theme_stylebox_override("pressed", cp_hover_sb)
	copy_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	copy_btn.add_theme_font_size_override("font_size", 13)
	copy_btn.pressed.connect(_on_copy_link)
	btn_vbox.add_child(copy_btn)

	# Hiệu ứng phóng to nhẹ nhàng khi xuất hiện
	_panel.pivot_offset = Vector2(POPUP_WIDTH * 0.5, 230)
	_panel.scale = Vector2(0.92, 0.92)
	_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)

func _make_box_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb

func _on_open_telegram() -> void:
	OS.shell_open(TELEGRAM_URL)
	if _status_lbl != null:
		_status_lbl.text = "✔ Đang mở nhóm Telegram trên trình duyệt/ứng dụng..."

func _on_copy_link() -> void:
	DisplayServer.clipboard_set(TELEGRAM_URL)
	if _status_lbl != null:
		_status_lbl.text = "✔ Đã sao chép link nhóm: %s" % TELEGRAM_URL

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if _current_popup == self:
		_current_popup = null
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(_dim, "color:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

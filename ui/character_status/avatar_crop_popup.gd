extends SocialWindow
class_name AvatarCropPopup
## Popup cắt và chỉnh sửa ảnh đại diện (Avatar Crop Popup):
## - Hỗ trợ kéo di chuyển ảnh (pan) bằng chuột hoặc chạm vuốt.
## - Hỗ trợ phóng to / thu nhỏ (zoom in / out) bằng cuộn chuột hoặc thanh trượt.
## - Khung cắt chuẩn vuông 200x200 px, vùng bên ngoài khung được làm tối (che mờ).
## - Xuất ra định dạng chuẩn 200x200 JPG chất lượng cao.

signal cropped(jpg_bytes: PackedByteArray)

const VIEW_SIZE := Vector2(320, 320)
const CROP_FRAME_SIZE := Vector2(200, 200)
const CROP_ORIGIN := Vector2(60, 60) # (320 - 200) / 2 = 60

var _src_image: Image
var _src_texture: ImageTexture
var _on_cropped_cb: Callable

var _image_pos := Vector2.ZERO
var _zoom_scale := 1.0
var _min_zoom := 0.2
var _max_zoom := 4.0

var _pan_dragging := false
var _last_mouse := Vector2.ZERO

var _crop_canvas: Control
var _zoom_slider: HSlider
var _zoom_label: Label

static func open(host: Node, src_img: Image, on_cropped: Callable) -> AvatarCropPopup:
	var win := AvatarCropPopup.new(src_img, on_cropped)
	SocialWindow.present(host, win, &"avatar_crop")
	return win

func _init(src_img: Image = null, on_cropped: Callable = Callable()) -> void:
	super._init("Cắt Ảnh Đại Diện", "Kéo để chỉnh góc · Cuộn chuột hoặc dùng thanh trượt để Zoom (Chuẩn 200×200 JPG)", 460.0)
	_src_image = src_img
	_on_cropped_cb = on_cropped
	if _src_image:
		_src_texture = ImageTexture.create_from_image(_src_image)
	
	_setup_ui()
	_reset_transform()

func _setup_ui() -> void:
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 10)
	body.add_child(container)

	# Vùng hiển thị cắt ảnh
	var view_card := GameUi.panel(GameUi.PANEL)
	view_card.custom_minimum_size = VIEW_SIZE
	view_card.size = VIEW_SIZE
	view_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view_card.clip_contents = true
	container.add_child(view_card)

	_crop_canvas = Control.new()
	_crop_canvas.custom_minimum_size = VIEW_SIZE
	_crop_canvas.size = VIEW_SIZE
	_crop_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_crop_canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_crop_canvas.draw.connect(_on_canvas_draw)
	_crop_canvas.gui_input.connect(_on_canvas_gui_input)
	view_card.add_child(_crop_canvas)

	# Thanh điều khiển Zoom
	var zoom_row := HBoxContainer.new()
	zoom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	zoom_row.add_theme_constant_override("separation", 8)
	container.add_child(zoom_row)

	var lbl_z := SocialUi.label("Thu/Phóng:", SocialUi.MUTED, 13)
	zoom_row.add_child(lbl_z)

	var btn_zoom_out := SocialUi.small_button("－")
	btn_zoom_out.custom_minimum_size = Vector2(28, 28)
	btn_zoom_out.pressed.connect(func() -> void: _set_zoom(_zoom_scale - 0.1))
	zoom_row.add_child(btn_zoom_out)

	_zoom_slider = HSlider.new()
	_zoom_slider.custom_minimum_size = Vector2(160, 24)
	_zoom_slider.min_value = _min_zoom
	_zoom_slider.max_value = _max_zoom
	_zoom_slider.step = 0.02
	_zoom_slider.value = _zoom_scale
	_zoom_slider.value_changed.connect(func(v: float) -> void: _set_zoom(v, false))
	zoom_row.add_child(_zoom_slider)

	var btn_zoom_in := SocialUi.small_button("＋")
	btn_zoom_in.custom_minimum_size = Vector2(28, 28)
	btn_zoom_in.pressed.connect(func() -> void: _set_zoom(_zoom_scale + 0.1))
	zoom_row.add_child(btn_zoom_in)

	_zoom_label = SocialUi.label("100%", SocialUi.TEXT, 13)
	_zoom_label.custom_minimum_size = Vector2(45, 0)
	zoom_row.add_child(_zoom_label)

	var btn_reset := SocialUi.small_button("🔄 Đặt Lại")
	btn_reset.pressed.connect(_reset_transform)
	zoom_row.add_child(btn_reset)

	# Hàng nút hành động
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	container.add_child(btn_row)

	var btn_cancel := SocialUi.stone_button("Huỷ Bỏ", Vector2(140, 38))
	btn_cancel.pressed.connect(func() -> void: close_requested.emit())
	btn_row.add_child(btn_cancel)

	var btn_confirm := SocialUi.stone_button("✅ Cắt & Lưu (200×200 JPG)", Vector2(240, 38))
	btn_confirm.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(btn_confirm)

func _reset_transform() -> void:
	if _src_image == null:
		return
	var sw := float(_src_image.get_width())
	var sh := float(_src_image.get_height())
	if sw <= 0.0 or sh <= 0.0:
		return
	
	# Tự động tính tỷ lệ sao cho ảnh vừa khít hoặc phủ kín khung 200x200
	var scale_x := CROP_FRAME_SIZE.x / sw
	var scale_y := CROP_FRAME_SIZE.y / sh
	var fit_scale := maxf(scale_x, scale_y)
	_zoom_scale = clampf(fit_scale, _min_zoom, _max_zoom)

	# Đặt tâm ảnh trùng tâm khung cắt
	var scaled_w := sw * _zoom_scale
	var scaled_h := sh * _zoom_scale
	var crop_center := CROP_ORIGIN + CROP_FRAME_SIZE * 0.5
	_image_pos = crop_center - Vector2(scaled_w, scaled_h) * 0.5

	if _zoom_slider:
		_zoom_slider.value = _zoom_scale
	if _zoom_label:
		_zoom_label.text = "%d%%" % int(round(_zoom_scale * 100))
	if _crop_canvas:
		_crop_canvas.queue_redraw()

func _set_zoom(new_zoom: float, update_slider: bool = true) -> void:
	var old_zoom := _zoom_scale
	_zoom_scale = clampf(new_zoom, _min_zoom, _max_zoom)
	if is_equal_approx(old_zoom, _zoom_scale):
		return
	
	# Giữ nguyên tâm khung cắt khi zoom
	var crop_center := CROP_ORIGIN + CROP_FRAME_SIZE * 0.5
	var ratio := _zoom_scale / old_zoom
	_image_pos = crop_center + (_image_pos - crop_center) * ratio

	if update_slider and _zoom_slider:
		_zoom_slider.value = _zoom_scale
	if _zoom_label:
		_zoom_label.text = "%d%%" % int(round(_zoom_scale * 100))
	if _crop_canvas:
		_crop_canvas.queue_redraw()

func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pan_dragging = true
				_last_mouse = mb.position
			else:
				_pan_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_zoom(_zoom_scale + 0.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_zoom(_zoom_scale - 0.1)

	elif event is InputEventMouseMotion and _pan_dragging:
		var mm := event as InputEventMouseMotion
		_image_pos += mm.position - _last_mouse
		_last_mouse = mm.position
		_crop_canvas.queue_redraw()

func _on_canvas_draw() -> void:
	# 1. Vẽ ảnh nguồn với kích thước và vị trí đã zoom/pan
	if _src_texture:
		var sw := float(_src_image.get_width())
		var sh := float(_src_image.get_height())
		var dst_rect := Rect2(_image_pos, Vector2(sw * _zoom_scale, sh * _zoom_scale))
		_crop_canvas.draw_texture_rect(_src_texture, dst_rect, false)

	# 2. Vẽ 4 khối làm tối (vùng ngoài khung xem như bỏ)
	var mask_color := Color(0.0, 0.0, 0.0, 0.68)
	var x1 := CROP_ORIGIN.x
	var y1 := CROP_ORIGIN.y
	var x2 := x1 + CROP_FRAME_SIZE.x
	var y2 := y1 + CROP_FRAME_SIZE.y

	# Khối trên
	_crop_canvas.draw_rect(Rect2(0, 0, VIEW_SIZE.x, y1), mask_color)
	# Khối dưới
	_crop_canvas.draw_rect(Rect2(0, y2, VIEW_SIZE.x, VIEW_SIZE.y - y2), mask_color)
	# Khối trái
	_crop_canvas.draw_rect(Rect2(0, y1, x1, CROP_FRAME_SIZE.y), mask_color)
	# Khối phải
	_crop_canvas.draw_rect(Rect2(x2, y1, VIEW_SIZE.x - x2, CROP_FRAME_SIZE.y), mask_color)

	# 3. Vẽ viền khung cắt vuông 200x200 màu vàng kim
	var border_color := Color(1.0, 0.85, 0.25, 0.95)
	_crop_canvas.draw_rect(Rect2(CROP_ORIGIN, CROP_FRAME_SIZE), border_color, false, 2.0)

	# Góc viền trang trí 4 góc (Corner accents)
	var corner_len := 12.0
	var col_corner := Color(1.0, 1.0, 0.4)
	# Góc trên-trái
	_crop_canvas.draw_line(Vector2(x1, y1), Vector2(x1 + corner_len, y1), col_corner, 3.0)
	_crop_canvas.draw_line(Vector2(x1, y1), Vector2(x1, y1 + corner_len), col_corner, 3.0)
	# Góc trên-phải
	_crop_canvas.draw_line(Vector2(x2, y1), Vector2(x2 - corner_len, y1), col_corner, 3.0)
	_crop_canvas.draw_line(Vector2(x2, y1), Vector2(x2, y1 + corner_len), col_corner, 3.0)
	# Góc dưới-trái
	_crop_canvas.draw_line(Vector2(x1, y2), Vector2(x1 + corner_len, y2), col_corner, 3.0)
	_crop_canvas.draw_line(Vector2(x1, y2), Vector2(x1, y2 - corner_len), col_corner, 3.0)
	# Góc dưới-phải
	_crop_canvas.draw_line(Vector2(x2, y2), Vector2(x2 - corner_len, y2), col_corner, 3.0)
	_crop_canvas.draw_line(Vector2(x2, y2), Vector2(x2, y2 - corner_len), col_corner, 3.0)

func _on_confirm_pressed() -> void:
	if _src_image == null:
		close_requested.emit()
		return
	
	# image_offset so với góc trên-trái của khung 200x200 (CROP_ORIGIN)
	var rel_offset := _image_pos - CROP_ORIGIN
	var jpg_bytes := CustomAvatarHelper.convert_to_jpg_200(_src_image, rel_offset, _zoom_scale, CROP_FRAME_SIZE)

	if not jpg_bytes.is_empty():
		cropped.emit(jpg_bytes)
		if _on_cropped_cb.is_valid():
			_on_cropped_cb.call(jpg_bytes)

	close_requested.emit()

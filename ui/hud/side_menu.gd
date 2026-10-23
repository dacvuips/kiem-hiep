extends HBoxContainer
class_name SideMenu
## Hàng nút tiện ích ở góc trên phải màn chơi (kiểu VLTK mobile): các ô tròn xếp ngang, sát bên trái nút Cài đặt (Main đặt vị trí). Ảnh lấy từ thanh công cụ gốc
## (assets/ui/toolbar, mỗi ảnh 3 khung ghép ngang: thường / rê chuột / sáng); nút không có ảnh gốc dùng ký hiệu chữ.
## Main truyền danh sách nút qua add_entry().

const SLOT := 46.0
const ICON := 30.0
const GAP := 6

func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Thêm 1 nút: `sheet` = tên ảnh trong assets/ui/toolbar ("" = dùng `glyph` chữ), `tip` = chú thích khi rê chuột.
func add_entry(sheet: String, glyph: String, tip: String, on_press: Callable) -> Button:
	var b := make_button(sheet, glyph, tip, on_press)
	add_child(b)
	return b

## 1 ô tròn kiểu cột tiện ích (dùng cả cho nút đặt riêng, VD nút Thoát cạnh mini map).
static func make_button(sheet: String, glyph: String, tip: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	var normal := GameUi.box(Color(0.06, 0.07, 0.06, 0.82), Color(0.45, 0.42, 0.30), int(SLOT / 2), 2, 0)
	var hover := GameUi.box(Color(0.12, 0.12, 0.08, 0.92), GameUi.BORDER_ACTIVE, int(SLOT / 2), 2, 0)
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var frames := _frames(sheet)
	if frames.is_empty():
		b.text = glyph
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", GameUi.GOLD)
	else:
		var icon := TextureRect.new()
		icon.texture = frames[0]
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(ICON, ICON)
		icon.position = Vector2((SLOT - ICON) * 0.5, (SLOT - ICON) * 0.5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		b.mouse_entered.connect(func() -> void: icon.texture = frames[mini(1, frames.size() - 1)])
		b.mouse_exited.connect(func() -> void: icon.texture = frames[0])
		b.button_down.connect(func() -> void: icon.texture = frames[frames.size() - 1])
		b.button_up.connect(func() -> void: icon.texture = frames[0])

	var badge := PanelContainer.new()
	badge.name = "ActiveBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color(0.25, 0.95, 0.35)
	dot.set_corner_radius_all(5)
	dot.border_width_left = 1
	dot.border_width_top = 1
	dot.border_width_right = 1
	dot.border_width_bottom = 1
	dot.border_color = Color(0.1, 0.35, 0.1, 0.9)
	badge.add_theme_stylebox_override("panel", dot)
	badge.custom_minimum_size = Vector2(10, 10)
	badge.size = Vector2(10, 10)
	badge.position = Vector2(SLOT - 13, SLOT - 13)
	b.add_child(badge)

	b.pressed.connect(on_press)
	return b

## Bật/tắt trạng thái hoạt động (viền vàng rực, chấm xanh góc dưới) cho nút tiện ích có chế độ toggle (như Giao dịch).
static func set_active(b: Button, active: bool) -> void:
	if b == null or not is_instance_valid(b):
		return
	var normal_box: StyleBox
	var hover_box: StyleBox
	if active:
		normal_box = GameUi.box(Color(0.20, 0.16, 0.05, 0.95), GameUi.GOLD, int(SLOT / 2), 2, 0)
		hover_box = GameUi.box(Color(0.28, 0.22, 0.06, 0.98), Color(1.0, 0.95, 0.5), int(SLOT / 2), 2, 0)
	else:
		normal_box = GameUi.box(Color(0.06, 0.07, 0.06, 0.82), Color(0.45, 0.42, 0.30), int(SLOT / 2), 2, 0)
		hover_box = GameUi.box(Color(0.12, 0.12, 0.08, 0.92), GameUi.BORDER_ACTIVE, int(SLOT / 2), 2, 0)
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, normal_box)
	b.add_theme_stylebox_override("hover", hover_box)
	b.add_theme_stylebox_override("pressed", hover_box)
	var badge := b.get_node_or_null("ActiveBadge") as Control
	if badge:
		badge.visible = active

## Các khung (vuông, ghép ngang) của ảnh thanh công cụ gốc; [] nếu không có ảnh.
static func _frames(sheet: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var path := "res://assets/ui/toolbar/%s.png" % sheet
	if sheet == "" or not ResourceLoader.exists(path):
		return out
	var tex: Texture2D = load(path)
	var h := tex.get_height()
	for i in maxi(1, tex.get_width() / h):
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * h, 0, h, h)
		out.append(a)
	return out

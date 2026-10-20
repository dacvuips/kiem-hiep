extends Button
class_name ItemSlotButton
## Ô chứa 1 món đồ (ô trang bị, ô hành trang...) — dùng chung:
##   - Rê chuột: tooltip mô tả CÓ MÀU (RichTextLabel, BBCode từ ItemText) thay tooltip chữ trơn mặc định.
##   - Đồ hoàng kim / đồ tím: đúng 2 line đối diện nhau chạy quanh 4 cạnh (RarityRing.draw_ring, chuẩn VLTK).

const GOLD := Color(1.0, 0.78, 0.0)

## BBCode mô tả món (rỗng = không có tooltip màu, dùng tooltip_text thường).
var item_bbcode: String = ""
var is_gold: bool = false:
	set(value):
		is_gold = value
		set_process(value)
		queue_redraw()
var _ring_color := RarityRing.GOLD
## true = dùng ảnh đã thu nhỏ sẵn (ô hành trang 48px). Ảnh luôn vẽ ĐÚNG KÍCH THƯỚC GỐC, căn đúng điểm ảnh, không phóng
## to — chỉ thu nhỏ khi lớn hơn ô (có mipmap) -> nét như game gốc.
var small_icons: bool = false
## Hệ số phóng ảnh tối đa khi vẽ (1 = giữ kích thước gốc). Hành trang nhiều ô đặt > 1 để ảnh vừa khít khung món.
var icon_max_scale: float = 1.0
var _item_icon: Texture2D
## Số lượng chồng (vật phẩm khác: thuốc, khoáng thạch...) — > 1 thì ghi số ở góc dưới phải ô.
var _count: int = 1

func _ready() -> void:
	set_process(is_gold)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## Nền đỏ khi nhân vật CHƯA ĐỦ yêu cầu để dùng món (giống ô đồ VLTK).
const UNUSABLE_BG := Color(0.26, 0.06, 0.05, 0.95)
## Nền phủ sau ảnh khi ô CÓ đồ (alpha 0 = không phủ). Ô trang bị trong bảng Nhân vật dùng để che hình mờ vẽ sẵn
## trong ảnh khung (bóng mũ/áo/nhẫn...) khi đã mặc đồ.
var filled_backdrop: Color = Color(0, 0, 0, 0)
var _backdrop: ColorRect

## Gán món hiển thị (null = ô trống). `bbcode` = ItemText.build(...). `usable` = đủ yêu cầu
## (Equipment.can_use) — false thì nền ô đỏ.
func show_item(item: ItemInstance, bbcode: String, empty_tooltip: String = "", usable: bool = true) -> void:
	_set_unusable(item != null and not usable)
	_set_backdrop(item != null and filled_backdrop.a > 0.0)
	if item:
		## Có ảnh vật phẩm -> chỉ hiện ảnh (vẽ trong _draw); thiếu ảnh -> hiện tên chữ như cũ.
		_item_icon = item.get_icon(small_icons)
		text = "" if _item_icon else item.get_base().get("name", "?")
		add_theme_color_override("font_color", item.get_quality_color())
		item_bbcode = bbcode
		tooltip_text = " "  ## khác rỗng để Godot gọi _make_custom_tooltip
		_ring_color = RarityRing.color_of(item)
		is_gold = _ring_color.a > 0.0   ## có vòng sáng (hoàng kim hoặc tím)
		_count = item.count
		queue_redraw()
	else:
		_item_icon = null
		text = ""
		item_bbcode = ""
		tooltip_text = empty_tooltip
		is_gold = false
		_count = 1
		queue_redraw()

func set_count(c: int) -> void:
	_count = c
	queue_redraw()

var _unusable: bool = false

func _set_backdrop(show: bool) -> void:
	if _backdrop == null:
		if not show:
			return
		_backdrop = ColorRect.new()
		_backdrop.show_behind_parent = true
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_backdrop)
		move_child(_backdrop, 0)
	_backdrop.color = filled_backdrop
	_backdrop.visible = show

## Nền đỏ vẽ trong _draw: TRÊN nền ô (stylebox của ô hành trang đặc, lớp nằm sau sẽ bị che) và DƯỚI ảnh vật phẩm.
func _set_unusable(unusable: bool) -> void:
	if unusable != _unusable:
		_unusable = unusable
		queue_redraw()

func _make_custom_tooltip(_for_text: String) -> Object:
	if item_bbcode == "":
		return null
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.92)
	style.border_color = _ring_color if is_gold else Color(0.4, 0.4, 0.45)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(300, 0)
	label.add_theme_font_size_override("normal_font_size", 13)
	label.text = item_bbcode
	panel.add_child(label)
	return panel

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _unusable:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), UNUSABLE_BG)
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), Color(0.50, 0.12, 0.10, 0.75), false, 1.0)
	if _item_icon:
		_draw_item_icon()
	if _count > 1:
		var font := get_theme_default_font()
		var label := str(_count)
		var pos := Vector2(size.x - 3.0 - font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, size.y - 4.0)
		draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if not is_gold:
		return
	RarityRing.draw_ring(self, Rect2(Vector2(1, 1), size - Vector2(2, 2)), RarityRing.get_global_phase(), _ring_color)

## Ảnh ở giữa ô: giữ kích thước gốc (không phóng to), chỉ thu nhỏ khi vượt lòng ô; toạ độ làm tròn để mỗi điểm ảnh
## rơi đúng 1 điểm màn hình.
func _draw_item_icon() -> void:
	var inner := Rect2(Vector2.ZERO, size).grow(-3.0)
	var tex_size := _item_icon.get_size()
	var scale := minf(icon_max_scale, minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y))
	var draw_size := (tex_size * scale).round()
	var pos := (inner.position + (inner.size - draw_size) * 0.5).floor()
	draw_texture_rect(_item_icon, Rect2(pos, draw_size), false)

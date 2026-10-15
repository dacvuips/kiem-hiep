extends CanvasLayer
class_name ItemDetailPopup
## Khung xem chi tiết 1 món đồ kiểu VLTK mobile: tên (màu theo phẩm chất) trên cùng, ô ảnh vật phẩm + Cấp / loại đồ, phần mô tả thuộc tính (cuộn được nếu dài), cột nút hành động lớn bên phải (VD Trang bị, Vứt bỏ, Tháo).
## Bấm ra ngoài để tắt. Bố cục nằm trong ItemDetailPopup.tscn, khung/nút lấy từ GameUi (chỉ tên món giữ màu theo phẩm chất).

const SCENE_PATH := "res://ui/items/ItemDetailPopup.tscn"
## Chiều cao tối đa phần mô tả — dài hơn thì cuộn.
const BODY_MAX_HEIGHT := 380.0

var _bbcode: String
var _actions: Array
var _item: ItemInstance

## bbcode: mô tả (ItemText.build(..., with_name = false)); actions: [[chữ nút, Callable], ...] — bấm nút thì gọi
## Callable rồi đóng khung; item: món đồ để vẽ phần đầu (tên, ảnh, cấp, loại đồ) — null thì chỉ hiện mô tả.
static func open(parent: Node, bbcode: String, actions: Array, item: ItemInstance = null) -> ItemDetailPopup:
	var popup: ItemDetailPopup = load(SCENE_PATH).instantiate()
	popup._bbcode = bbcode
	popup._actions = actions
	popup._item = item
	parent.add_child(popup)
	return popup

func _ready() -> void:
	add_to_group(UiPopups.GROUP)   ## đang mở thì lăn chuột không zoom camera
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameUi.apply()
	(%Dim as ColorRect).color = GameUi.DIM
	%Dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	_fill_header()
	(%Body as RichTextLabel).text = _bbcode
	var template: Button = %ActionTemplate
	for action in _actions:
		var b: Button = template.duplicate()
		b.visible = true
		b.text = action[0]
		var cb: Callable = action[1]
		b.pressed.connect(func() -> void:
			cb.call()
			queue_free())
		%Actions.add_child(b)
	## Mô tả ngắn thì khung vừa nội dung, dài thì cuộn trong BODY_MAX_HEIGHT.
	await get_tree().process_frame
	var body: RichTextLabel = %Body
	(%BodyScroll as ScrollContainer).custom_minimum_size.y = minf(body.get_content_height() + 4.0, BODY_MAX_HEIGHT)

func _fill_header() -> void:
	var name_label: Label = %NameLabel
	if _item == null:
		name_label.get_parent().get_node("Header").visible = false
		name_label.visible = false
		return
	var base := _item.get_base()
	name_label.text = base.get("name", "?")
	name_label.add_theme_color_override("font_color", Color.html(ItemText.name_color_of(_item)))
	var icon_rect: TextureRect = %Icon
	icon_rect.texture = _item.get_icon()
	## Vừa ô (lòng 108px) -> giữ đúng kích thước gốc cho nét; lớn hơn mới thu nhỏ giữ tỉ lệ.
	if icon_rect.texture and icon_rect.texture.get_height() <= 108 and icon_rect.texture.get_width() <= 108:
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	else:
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	(%LevelLabel as RichTextLabel).text = "[color=#e8d9a8]Cấp:[/color] [color=#ffffff]%d[/color]" % _item.get_level()
	var quality := "Hoàng Kim" if _item.is_gold() else ("Đồ xanh" if not _item.magic.is_empty() else "Đồ thường")
	(%NoteLabel as Label).text = "%s · %s" % [ItemDatabase.DETAIL_NAMES.get(_item.get_detail(), ""), quality]

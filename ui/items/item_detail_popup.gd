extends CanvasLayer
class_name ItemDetailPopup

const TouchScrollHelperScript = preload("res://ui/common/touch_scroll_helper.gd")
const ItemChatHelper = preload("res://systems/items/item_chat_helper.gd")
## Khung xem chi tiết 1 món đồ kiểu VLTK mobile: tên (màu theo phẩm chất) trên cùng, ô ảnh vật phẩm + Cấp / loại đồ, phần mô tả thuộc tính (cuộn được nếu dài), cột nút hành động lớn bên phải (VD Trang bị, Vứt bỏ, Tháo).
## Bấm ra ngoài để tắt. Bố cục nằm trong ItemDetailPopup.tscn, khung/nút lấy từ GameUi (chỉ tên món giữ màu theo phẩm chất).

const SCENE_PATH := "res://ui/items/ItemDetailPopup.tscn"
## Chiều rộng chuẩn tối thiểu của khung popup (giữ khung ngang cân đối).
const POPUP_WIDTH := 430.0
## Chiều cao tối đa phần mô tả — dài hơn thì cuộn.
const BODY_MAX_HEIGHT := 380.0

var _bbcode: String
var _actions: Array
var _item: ItemInstance
var _extra: Control

## bbcode: mô tả (ItemText.build(..., with_name = false)); actions: [[chữ nút, Callable], ...] — bấm nút thì gọi
## Callable rồi đóng khung; item: món đồ để vẽ phần đầu (tên, ảnh, cấp, loại đồ) — null thì chỉ hiện mô tả.
## extra: khối thêm ở DƯỚI CÙNG khung, sau phần mô tả (VD nội dung rao của món treo ở Chợ) — null = không có.
static func open(parent: Node, bbcode: String, actions: Array, item: ItemInstance = null, extra: Control = null) -> ItemDetailPopup:
	var popup: ItemDetailPopup = load(SCENE_PATH).instantiate()
	popup._bbcode = bbcode
	popup._actions = actions
	popup._item = item
	popup._extra = extra
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
	if _extra != null:
		$Center/Row/Card/Box.add_child(_extra)
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

	## Nút gắn liên kết vật phẩm vào khung chat
	if _item != null:
		var chat_b: Button = template.duplicate()
		chat_b.visible = true
		chat_b.text = "Gắn vào chat"
		chat_b.tooltip_text = "Gắn liên kết vật phẩm vào khung chat để người khác xem"
		chat_b.pressed.connect(func() -> void:
			ItemChatHelper.attach_to_chat(_item, get_tree().root)
			queue_free())
		%Actions.add_child(chat_b)
	## Không tự động xuống hàng (autowrap) để các dòng thuộc tính luôn nằm trọn trên 1 dòng chuẩn VLTK.
	## Chiều ngang popup tự động co giãn theo dòng dài nhất (tối thiểu POPUP_WIDTH).
	var body: RichTextLabel = %Body
	var scroll: ScrollContainer = %BodyScroll
	body.autowrap_mode = TextServer.AUTOWRAP_OFF
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	await get_tree().process_frame
	var content_w: float = body.get_content_width()
	scroll.custom_minimum_size.x = maxf(POPUP_WIDTH, content_w + 32.0)
	scroll.custom_minimum_size.y = minf(maxf(body.get_content_height() + 8.0, 60.0), BODY_MAX_HEIGHT)
	TouchScrollHelperScript.attach(scroll, $Center/Row/Card as Control)

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
	var quality := ItemText.quality_name_of(_item)
	var detail_text: String = ItemDatabase.DETAIL_NAMES.get(_item.get_detail(), "")
	if detail_text == "":
		(%NoteLabel as Label).text = quality
	else:
		(%NoteLabel as Label).text = "%s · %s" % [detail_text, quality]

	if has_node("%PriceLabel"):
		var price_label: RichTextLabel = %PriceLabel
		if _item.can_sell():
			var sale_price := _item.get_sale_price()
			var price_str := InventoryPopup.format_money(sale_price)
			if _item.is_misc() and _item.count > 1:
				var unit_str := InventoryPopup.format_money(_item.get_unit_sale_price())
				price_label.text = "[color=#e8d9a8]Giá bán:[/color] [color=#ffd700]%s Lượng[/color] [color=#a0a0a0](%s/cái)[/color]" % [price_str, unit_str]
			else:
				price_label.text = "[color=#e8d9a8]Giá bán:[/color] [color=#ffd700]%s Lượng[/color]" % price_str
			price_label.visible = true
		else:
			if _item.is_locked():
				price_label.text = "[color=#ff6060]Vật phẩm đã khóa (Không thể bán)[/color]"
			else:
				price_label.text = "[color=#808080]Không thể bán[/color]"
			price_label.visible = true

extends SocialWindow
class_name TongKimLolShopWindow
## Cửa hàng Quân Nhu trong ải Tống Kim LOL (mua thuốc & bùa tác chiến bằng Vàng Tống Kim)

var _gold_label: Label
var _buy_buttons: Dictionary = {}

static func open(host: Node) -> TongKimLolShopWindow:
	var win := TongKimLolShopWindow.new()
	return SocialWindow.present(host, win, &"tong_kim_lol_shop") as TongKimLolShopWindow

func _init() -> void:
	super._init("Quân Nhu Tống Kim", "Dược liệu & bùa hỗ trợ tác chiến chiến trường", 500.0)
	_gold_label = SocialUi.label("", SocialUi.GOLD, 15)
	body.add_child(_gold_label)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)

	for item in TongKimLolRules.SHOP_ITEMS:
		var row := GameUi.panel(GameUi.PANEL)
		row.custom_minimum_size.y = 56
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)

		# Khung hình ảnh thuốc / vật phẩm
		var icon_frame := PanelContainer.new()
		icon_frame.custom_minimum_size = Vector2(44, 44)
		icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var frame_box := GameUi.box(GameUi.BG_INNER, GameUi.BORDER, 6, 1, 3)
		icon_frame.add_theme_stylebox_override("panel", frame_box)
		icon_frame.tooltip_text = "%s\n%s" % [str(item.get("name", "")), str(item.get("desc", ""))]

		var icon_rect := TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon_rect.custom_minimum_size = Vector2(36, 36)
		icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.texture = load_item_icon(item)
		icon_frame.add_child(icon_rect)
		hbox.add_child(icon_frame)

		# Thông tin chi tiết thuốc & đơn giá
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		var title := SocialUi.label(str(item["name"]), SocialUi.TITLE, 14)
		var desc := SocialUi.label("%s  ·  🪙 Giá: %d Vàng" % [str(item["desc"]), int(item["price"])], SocialUi.TEXT, 12)
		info.add_child(title)
		info.add_child(desc)
		hbox.add_child(info)

		# Nút Mua thuốc
		var buy_btn := SocialUi.small_button("Mua")
		buy_btn.custom_minimum_size = Vector2(64, 30)
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy_btn.pressed.connect(_on_buy_pressed.bind(item))
		hbox.add_child(buy_btn)
		_buy_buttons[item] = buy_btn

		list.add_child(row)

	var close_btn := SocialUi.stone_button("Đóng")
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	body.add_child(close_btn)

	_update_gold()

## Tải ảnh đại diện của thuốc hoặc bùa tác chiến
static func load_item_icon(item: Dictionary) -> Texture2D:
	var path: String = str(item.get("icon", ""))
	if path != "":
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		var full_path := "res://assets/items/icons/" + path + ".png"
		if ResourceLoader.exists(full_path):
			return load(full_path) as Texture2D
		var small_path := "res://assets/items/icons_small/" + path + ".png"
		if ResourceLoader.exists(small_path):
			return load(small_path) as Texture2D
	var base_rec := ItemDatabase.get_misc(str(item.get("id", "")))
	if not base_rec.is_empty():
		var tex := ItemDatabase.get_icon(base_rec)
		if tex:
			return tex
	return null

func _on_buy_pressed(item: Dictionary) -> void:
	var state := TongKimLolState.instance()
	if state and state.apply_shop_item(item):
		_update_gold()
		ChatBox.push_system("[color=#5cd882]Đã mua %s thành công![/color]" % str(item.get("name", "")))
	else:
		ChatBox.push_system("[color=#ff4444]Không đủ Vàng Tống Kim để mua vật phẩm này![/color]")

func _update_gold() -> void:
	var state := TongKimLolState.instance()
	var gold := state.match_gold if state else 0
	_gold_label.text = "🪙 Vàng Tống Kim hiện có: %d Vàng" % gold
	for it in _buy_buttons:
		var btn: Button = _buy_buttons[it]
		if is_instance_valid(btn):
			var price := int(it.get("price", 0))
			btn.disabled = (gold < price)

func _process(_d: float) -> void:
	_update_gold()

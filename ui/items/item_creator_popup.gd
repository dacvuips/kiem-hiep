extends CanvasLayer
class_name ItemCreatorPopup
## Bảng "Tạo đồ" (bản thử/debug): chọn phẩm chất, loại, cấp, hệ... -> xem trước -> thêm vào Hành trang.
##   - Thường / Xanh: loại cụ thể (Kiếm, Đao, Côn, Phi tiêu..., từng kiểu Áo/Mũ, Ngựa), cấp 1-10, hệ,
##     số dòng magic + cấp magic (xanh) — sinh bằng ItemGenerator.generate (đúng Gen_MagicAttrib gốc).
##   - Hoàng kim: loại, lọc môn phái (tất cả / không môn phái / từng phái), chọn đúng món, độ hoàn mỹ 0-10
##     — sinh bằng ItemGenerator.generate_gold.
## Mỗi lần đổi lựa chọn sinh lại bản xem trước; "Tạo" thêm đúng món đang xem trước.

enum Quality { NORMAL, MAGIC, GOLD }

var _profile: PlayerProfile
var _on_changed: Callable
var _quality: OptionButton
var _type: OptionButton
var _level: OptionButton
var _series: OptionButton
var _lines: OptionButton
var _magic_level: OptionButton
var _menpai: OptionButton
var _gold_item: OptionButton
var _perfection: OptionButton
var _rows: Dictionary = {}  ## tên hàng -> HBoxContainer (ẩn/hiện theo phẩm chất)
var _preview_text: RichTextLabel
var _preview_icon: TextureRect
var _message: Label
var _preview: ItemInstance
## Danh sách loại cho đồ thường/xanh: [detail, particular]; cho hoàng kim: [detail, particular hoặc -1].
var _normal_types: Array = []
var _gold_types: Array = []
var _gold_indices: Array[int] = []

static func open(parent: Node, profile: PlayerProfile, on_changed: Callable) -> ItemCreatorPopup:
	var popup := ItemCreatorPopup.new()
	popup._profile = profile
	popup._on_changed = on_changed
	parent.add_child(popup)
	return popup

func _ready() -> void:
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.06, 1.0)
	style.border_color = Color(0.83, 0.68, 0.21)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)
	var title := Label.new()
	title.text = "Tạo đồ (TEST)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.83, 0.68, 0.21))
	root.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var form := VBoxContainer.new()
	form.custom_minimum_size = Vector2(330, 0)
	body.add_child(form)

	_quality = _add_option(form, "quality", "Phẩm chất", ["Thường", "Xanh (magic)", "Hoàng kim"])
	_type = _add_option(form, "type", "Loại", [])
	_level = _add_option(form, "level", "Cấp đồ", [])
	_series = _add_option(form, "series", "Hệ", ElementTypes.ELEMENT_NAME.values())
	_lines = _add_option(form, "lines", "Số dòng magic", ["1", "2", "3", "4", "5", "6"])
	_lines.select(5)
	_magic_level = _add_option(form, "magic_level", "Cấp dòng magic", ["Theo cấp đồ", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])
	var menpai_names := ["Tất cả", "Không môn phái"]
	for sect_id in Equipment.MENPAI_ORDER:
		var sect := SectRegistry.get_by_id(sect_id)
		menpai_names.append(sect.sect_name if sect else sect_id)
	_menpai = _add_option(form, "menpai", "Môn phái", menpai_names)
	_gold_item = _add_option(form, "gold_item", "Món", [])
	var perfection := []
	for i in 11:
		perfection.append("%d/10" % i)
	_perfection = _add_option(form, "perfection", "Độ hoàn mỹ", perfection)
	_perfection.select(10)

	## Cột xem trước: ảnh vật phẩm (kích thước gốc, nét) phía trên mô tả.
	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 6)
	body.add_child(preview_box)
	_preview_icon = TextureRect.new()
	_preview_icon.custom_minimum_size = Vector2(300, 110)
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	preview_box.add_child(_preview_icon)
	_preview_text = RichTextLabel.new()
	_preview_text.bbcode_enabled = true
	_preview_text.custom_minimum_size = Vector2(300, 300)
	_preview_text.add_theme_font_size_override("normal_font_size", 13)
	preview_box.add_child(_preview_text)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)
	for spec in [["Đổi roll khác", _rebuild_preview], ["Tạo", _on_create.bind(false)],
			["Tạo & mặc", _on_create.bind(true)], ["Đóng", queue_free]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		buttons.add_child(b)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_color", Color(0.6, 0.9, 0.55))
	root.add_child(_message)

	_quality.item_selected.connect(func(_i: int) -> void: _on_quality_changed())
	_type.item_selected.connect(func(_i: int) -> void: _on_type_changed())
	_menpai.item_selected.connect(func(_i: int) -> void: _refresh_gold_items())
	for opt in [_level, _series, _lines, _magic_level, _gold_item, _perfection]:
		opt.item_selected.connect(func(_i: int) -> void: _rebuild_preview())
	_build_type_lists()
	_series.select(_default_series())
	_on_quality_changed()

func _add_option(parent: VBoxContainer, key: String, label_text: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.fit_to_longest_item = false
	for it in items:
		opt.add_item(str(it))
	row.add_child(opt)
	parent.add_child(row)
	_rows[key] = row
	return opt

## Hệ mặc định = hệ được nhân vật TƯƠNG SINH (mặc vào là bật 1 dòng ẩn ngay).
func _default_series() -> int:
	var sect := SectRegistry.get_by_id(_profile.sect_id)
	return int(Equipment.ACCRUE.get(sect.element, 0)) if sect else 0

func _build_type_lists() -> void:
	for detail in ItemDatabase.Detail.values():
		for particular in ItemDatabase.get_particulars(detail):
			_normal_types.append([detail, particular])
		if ItemDatabase.WEAPON_PARTICULAR_NAMES.has(detail):
			for particular in ItemDatabase.WEAPON_PARTICULAR_NAMES[detail]:
				_gold_types.append([detail, particular])
		else:
			_gold_types.append([detail, -1])

func _on_quality_changed() -> void:
	var gold := _quality.selected == Quality.GOLD
	_rows["level"].visible = not gold
	_rows["series"].visible = not gold
	_rows["lines"].visible = _quality.selected == Quality.MAGIC
	_rows["magic_level"].visible = _quality.selected == Quality.MAGIC
	_rows["menpai"].visible = gold
	_rows["gold_item"].visible = gold
	_rows["perfection"].visible = gold
	_type.clear()
	for t in (_gold_types if gold else _normal_types):
		var label: String = ItemDatabase.get_particular_label(t[0], t[1]) if t[1] >= 0 else ItemDatabase.DETAIL_NAMES[t[0]]
		## Ảnh: món cấp thấp nhất của loại đó (đồ thường) / món hoàng kim đầu tiên của loại (hoàng kim).
		var icon: Texture2D = null
		if gold:
			var found := ItemDatabase.find_gold(t[0], -2, t[1])
			icon = ItemDatabase.get_icon(ItemDatabase.get_gold(found[0]), true) if not found.is_empty() else null
		else:
			var levels := ItemDatabase.get_levels(t[0], t[1])
			icon = ItemDatabase.get_icon(ItemDatabase.get_base(ItemDatabase.find_base(t[0], t[1], levels[0])), true) 					if not levels.is_empty() else null
		_add_option_item(_type, label, icon)
	_type.select(0)
	_on_type_changed()

func _on_type_changed() -> void:
	if _quality.selected == Quality.GOLD:
		_refresh_gold_items()
		return
	var t: Array = _normal_types[_type.selected]
	_level.clear()
	for lv in ItemDatabase.get_levels(t[0], t[1]):
		var icon := ItemDatabase.get_icon(ItemDatabase.get_base(ItemDatabase.find_base(t[0], t[1], lv)), true)
		_add_option_item(_level, "Cấp %d" % lv, icon, lv)
	var wanted := clampi(ceili(_profile.level / 10.0), 1, 10)
	for i in _level.item_count:
		if _level.get_item_id(i) <= wanted:
			_level.select(i)
	_rebuild_preview()

## Dòng danh sách có ẢNH vật phẩm (bản nhỏ icons_small, tối đa 48px — đúng kích thước nên không bị co, vẫn nét).
const ICON_LIST_SIZE := 48

static func _add_option_item(opt: OptionButton, label: String, icon: Texture2D, id: int = -1) -> void:
	if icon:
		opt.add_icon_item(icon, label, id)
	else:
		opt.add_item(label, id)
	var popup := opt.get_popup()
	popup.add_theme_constant_override("icon_max_width", ICON_LIST_SIZE)
	opt.add_theme_constant_override("icon_max_width", 24)

## " - Thiếu Lâm" cho đồ hoàng kim môn phái (requiremenpai = chỉ số trong Equipment.MENPAI_ORDER), "" nếu không.
static func _menpai_suffix(menpai: int) -> String:
	if menpai < 0 or menpai >= Equipment.MENPAI_ORDER.size():
		return ""
	var sect := SectRegistry.get_by_id(Equipment.MENPAI_ORDER[menpai])
	return " - %s" % (sect.sect_name if sect else Equipment.MENPAI_ORDER[menpai])

func _refresh_gold_items() -> void:
	var t: Array = _gold_types[_type.selected]
	var menpai := _menpai.selected - 2  ## 0 "Tất cả" -> -2, 1 "Không môn phái" -> -1, 2.. -> 0..9
	_gold_indices = ItemDatabase.find_gold(t[0], menpai, t[1])
	_gold_item.clear()
	for idx in _gold_indices:
		var g := ItemDatabase.get_gold(idx)
		var req_level := 0
		for req in g["require"]:
			if req[0] == "requirelevel":
				req_level = int(req[1])
		## Ghi luôn môn phái ngay cạnh tên món để chọn nhanh (đồ không giới hạn môn phái thì không ghi).
		_add_option_item(_gold_item, "%s%s (cấp %d)" % [g["name"], _menpai_suffix(int(g.get("menpai", -1))), req_level],
				ItemDatabase.get_icon(g, true))
	if _gold_item.item_count > 0:
		_gold_item.select(0)
	_rebuild_preview()

func _rebuild_preview() -> void:
	_preview = null
	match _quality.selected:
		Quality.GOLD:
			if _gold_item.selected >= 0 and _gold_item.selected < _gold_indices.size():
				_preview = ItemGenerator.generate_gold(_gold_indices[_gold_item.selected], _perfection.selected)
		_:
			var t: Array = _normal_types[_type.selected]
			var level := _level.get_item_id(_level.selected) if _level.selected >= 0 else 1
			var magic_levels := []
			if _quality.selected == Quality.MAGIC:
				var magic_level := level if _magic_level.selected == 0 else _magic_level.selected
				for i in _lines.selected + 1:
					magic_levels.append(magic_level)
			_preview = ItemGenerator.generate(t[0], t[1], level, _series.selected, magic_levels)
	_preview_text.text = ItemText.build(_preview, _profile) if _preview else "[color=#888888]Không có món nào khớp bộ lọc.[/color]"
	_preview_icon.texture = _preview.get_icon() if _preview else null
	## Ảnh lớn hơn khung (110px) thì thu nhỏ giữ tỉ lệ; vừa khung thì giữ kích thước gốc cho nét.
	var big := _preview_icon.texture != null and _preview_icon.texture.get_height() > 110
	_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE if big else TextureRect.EXPAND_KEEP_SIZE
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if big else TextureRect.STRETCH_KEEP_CENTERED

func _on_create(equip_now: bool) -> void:
	if _preview == null:
		return
	if not _profile.add_item(_preview):
		_message.text = "Hành trang đầy (%d món)." % PlayerProfile.INVENTORY_CAPACITY
		return
	var item_name: String = _preview.get_base().get("name", "?")
	_message.text = "Đã tạo: %s" % item_name
	if equip_now:
		var err := _profile.equip_from_inventory(_profile.inventory.size() - 1)
		_message.text = "Đã tạo và mặc: %s" % item_name if err == "" else "Đã tạo %s — %s" % [item_name, err]
	SaveManager.save_profile(_profile)
	if _on_changed.is_valid():
		_on_changed.call()
	_rebuild_preview()  ## roll món mới cho lần tạo tiếp

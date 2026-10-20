extends CanvasLayer
class_name ItemCreatorPopup
## Bảng "Tạo đồ" (bản thử/debug): chọn phẩm chất, loại, cấp, hệ... -> xem trước -> thêm vào Hành trang.
##   - Thường / Xanh: loại cụ thể (Kiếm, Đao, Côn, Phi tiêu..., từng kiểu Áo/Mũ, Ngựa), cấp 1-10, hệ,
##     số dòng magic + cấp magic (xanh) — sinh bằng ItemGenerator.generate (đúng Gen_MagicAttrib gốc).
##   - Hoàng kim: loại, lọc môn phái (tất cả / không môn phái / từng phái), chọn đúng món, độ hoàn mỹ 0-10
##     — sinh bằng ItemGenerator.generate_gold.
##   - Thuốc / Huyền Tinh - ép đồ tím / Sát thủ / Phong Lăng Độ: vật phẩm khác (misc_items.json) — danh sách theo NPC thử nghiệm gốc
##     (script/global/nobitaxd/npc/npcthunghiem.lua: TrangBiTim, HuyenTinh, KhoangThach, ThuyTinh, PhucDuyen, HoTro_CapSatThuGian,
##     itemPLD) + các lệnh bài Sát thủ / Phong Lăng Độ khác trong magicscript.txt, questkey.txt gốc,
##     chọn cấp / hệ (món có cấp, hệ) + số lượng — sinh bằng ItemGenerator.generate_misc.
## Mỗi lần đổi lựa chọn sinh lại bản xem trước; "Tạo" thêm đúng món đang xem trước.

enum Quality { NORMAL, MAGIC, GOLD, MASK, MANTLE, POTION, PURPLE, KILLER, FERRY, MONEY }
## Nhóm "Ngân lượng": cộng thẳng vào tiền mang theo (profile.gold), không phải vật phẩm.
const MONEY_AMOUNTS := [10000, 100000, 1000000, 10000000, 100000000]
const MONEY_MAX := 2000000000  ## int32 gốc — không cho tiền vượt quá
## Vật liệu ép đồ tím: Huyền Tinh, Nguyên khoáng hiện 1/2/3 (Huyền Thiết, Mật Ngân, Chu Sa) + Nguyên thạch ẩn 1/2/3 có hệ
## (Khổng Tước, Phù Dung, Chung Nhũ), Thủy tinh Lam/Tử/Lục, Phúc Duyên Lộ tiểu/trung/đại, Thần bí khoáng thạch (vật phẩm phụ Chế tạo).
const PURPLE_ITEMS := ["6_1_147", "6_1_149", "6_1_150", "6_1_151", "6_1_152", "6_1_153", "6_1_154",
	"4_238_1", "4_239_1", "4_240_1", "6_1_122", "6_1_123", "6_1_124", "6_1_398"]
## Sát Thủ lệnh (phần thưởng giết Boss sát thủ, 5 lệnh cùng cấp đổi 1 giản) + Sát thủ giản (gọi Boss),
## Sát Thủ Giản lễ hộp (mở ra 2 giản), Sát Thủ Bí Bảo, Lệnh Bài Sát Thủ + Huyết Lệ Chi Thư (nhiệm vụ Nhiếp Thí Trần),
## Ngọc Long Lệnh Bài (sát thủ), Lệnh bài Bắc Đẩu - Boss sát thủ.
const KILLER_ITEMS := ["6_1_399", "6_1_400", "6_1_2339", "6_1_2347", "6_1_30565", "6_1_30568", "6_1_2631", "6_1_3520"]
## Phong Lăng Độ (missions/fengling_ferry/fld_head.lua): Lệnh bài Phong Lăng Độ (4,489 — giao cho Thuyền phu để lên thuyền),
## Lệnh Bài Thủy Tặc (thuyền đặc biệt) + Bảo Rương Thủy Tặc (thưởng), Ngọc Long Lệnh Bài (Phong Lăng Độ),
## Lệnh bài Bắc Đẩu - Phong Lăng Độ cấp 1/2.
const FERRY_ITEMS := ["4_489_1", "6_1_2745", "6_1_2743", "6_1_2630", "6_1_3517", "6_1_3518"]
## Cấp gốc: Huyền Tinh AddItem(6,1,147,1..10); Sát Thủ lệnh lib_killlevel.lua AddItem(6,1,399,20..90,hệ).
const MISC_LEVELS := {"6_1_147": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "6_1_399": [20, 30, 40, 50, 60, 70, 80, 90],
	"6_1_400": [20, 30, 40, 50, 60, 70, 80, 90]}
const AMOUNTS := [1, 5, 10, 20, 50, 100]

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
var _amount: OptionButton
var _money: OptionButton
var _equip_button: Button
var _reroll_button: Button
var _rows: Dictionary = {}  ## tên hàng -> HBoxContainer (ẩn/hiện theo phẩm chất)
var _preview_text: RichTextLabel
var _preview_icon: TextureRect
var _message: Label
var _preview: ItemInstance
## Danh sách loại cho đồ thường/xanh: [detail, particular]; cho hoàng kim: [detail, particular hoặc -1].
var _normal_types: Array = []
var _gold_types: Array = []
var _gold_indices: Array[int] = []
## Nhóm vật phẩm khác (Quality.POTION/PURPLE/KILLER/FERRY) -> [mã misc_items.json].
var _misc_types: Dictionary = {}

static func open(parent: Node, profile: PlayerProfile, on_changed: Callable) -> ItemCreatorPopup:
	var popup := ItemCreatorPopup.new()
	popup._profile = profile
	popup._on_changed = on_changed
	parent.add_child(popup)
	return popup

func _ready() -> void:
	add_to_group(UiPopups.GROUP)   ## đang mở thì lăn chuột không zoom camera
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS
	## Khung/tiêu đề/nút lấy từ GameUi để đồng bộ với mọi popup khác.
	var dim := GameUi.dim_rect()
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := GameUi.panel(GameUi.WINDOW)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)
	var title := GameUi.title("Tạo đồ (TEST)")
	root.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var form := VBoxContainer.new()
	form.custom_minimum_size = Vector2(330, 0)
	body.add_child(form)

	_quality = _add_option(form, "quality", "Nhóm", ["Thường", "Xanh (magic)", "Hoàng kim", "Mặt nạ", "Phi phong", "Thuốc",
		"Huyền Tinh - ép đồ tím", "Sát thủ (lệnh bài)", "Phong Lăng Độ (lệnh bài)", "Ngân lượng"])
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
	_amount = _add_option(form, "amount", "Số lượng", AMOUNTS)
	var money_labels := []
	for v in MONEY_AMOUNTS:
		money_labels.append("%s lượng" % _money_text(v))
	_money = _add_option(form, "money", "Số tiền", money_labels)
	_money.select(2)

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
	## [chữ, hàm, biến thể nút] — "Tạo" là nút chính.
	for spec in [["Đổi roll khác", _rebuild_preview, GameUi.BUTTON], ["Tạo", _on_create.bind(false), GameUi.PRIMARY],
			["Tạo & mặc", _on_create.bind(true), GameUi.BUTTON], ["Đóng", queue_free, GameUi.BUTTON]]:
		var b := GameUi.button(spec[0], spec[2])
		b.pressed.connect(spec[1])
		buttons.add_child(b)
		if spec[0] == "Tạo & mặc":
			_equip_button = b
		elif spec[0] == "Đổi roll khác":
			_reroll_button = b
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_color", GameUi.LABEL_GREEN)
	root.add_child(_message)

	_quality.item_selected.connect(func(_i: int) -> void: _on_quality_changed())
	_type.item_selected.connect(func(_i: int) -> void: _on_type_changed())
	_menpai.item_selected.connect(func(_i: int) -> void: _refresh_gold_items())
	for opt in [_level, _series, _lines, _magic_level, _gold_item, _perfection, _amount, _money]:
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
	return int(Equipment.ACCRUE.get(_profile.get_element(), 0))

func _build_type_lists() -> void:
	for detail in ItemDatabase.Detail.values():
		for particular in ItemDatabase.get_particulars(detail):
			_normal_types.append([detail, particular])
		if ItemDatabase.WEAPON_PARTICULAR_NAMES.has(detail):
			for particular in ItemDatabase.WEAPON_PARTICULAR_NAMES[detail]:
				_gold_types.append([detail, particular])
		else:
			_gold_types.append([detail, -1])
	## Thuốc: bỏ món trùng tên (VD 4 "Bánh chưng Nhân táo" cùng tác dụng).
	var potions := []
	var seen := {}
	for m in ItemDatabase.list_misc("potion"):
		if not seen.has(m["name"]):
			seen[m["name"]] = true
			potions.append(str(m["id"]))
	_misc_types = {Quality.POTION: potions, Quality.PURPLE: PURPLE_ITEMS, Quality.KILLER: KILLER_ITEMS,
		Quality.FERRY: FERRY_ITEMS}

func _is_misc_mode() -> bool:
	return _misc_types.has(_quality.selected)

## Mã vật phẩm khác đang chọn ("" nếu không ở nhóm vật phẩm khác).
func _misc_id() -> String:
	if not _is_misc_mode() or _type.selected < 0:
		return ""
	return str(_misc_types[_quality.selected][_type.selected])

func _on_quality_changed() -> void:
	var money := _quality.selected == Quality.MONEY
	for key in _rows:
		_rows[key].visible = key == "quality" or (key == "money") == money
	_equip_button.visible = not money
	_reroll_button.visible = not money
	if money:
		_rebuild_preview()
		return
	if _quality.selected == Quality.MASK:
		for k in ["level", "series", "lines", "magic_level", "menpai", "gold_item", "perfection", "amount"]:
			_rows[k].visible = false
		_equip_button.visible = true
		_type.clear()
		for particular in ItemDatabase.get_particulars(ItemDatabase.Detail.MASK):
			var base := ItemDatabase.get_base(ItemDatabase.find_base(ItemDatabase.Detail.MASK, particular, 1))
			var label: String = str(base.get("name", "Mặt nạ %d" % particular))
			var icon := ItemDatabase.get_icon(base, true)
			_add_option_item(_type, label, icon)
		_type.select(0)
		_rebuild_preview()
		return
	if _quality.selected == Quality.MANTLE:
		for k in ["level", "series", "lines", "magic_level", "menpai", "gold_item", "perfection", "amount"]:
			_rows[k].visible = false
		_equip_button.visible = true
		_type.clear()
		for lv in ItemDatabase.get_levels(ItemDatabase.Detail.MANTLE, 0):
			var base := ItemDatabase.get_base(ItemDatabase.find_base(ItemDatabase.Detail.MANTLE, 0, lv))
			var label: String = "%s (Cấp %d)" % [str(base.get("name", "Phi phong")), lv]
			var icon := ItemDatabase.get_icon(base, true)
			_add_option_item(_type, label, icon)
		_type.select(0)
		_rebuild_preview()
		return

	var gold := _quality.selected == Quality.GOLD
	var misc := _is_misc_mode()
	_rows["level"].visible = not gold
	_rows["series"].visible = not gold
	_rows["amount"].visible = misc
	_equip_button.visible = not misc
	_rows["lines"].visible = _quality.selected == Quality.MAGIC
	_rows["magic_level"].visible = _quality.selected == Quality.MAGIC
	_rows["menpai"].visible = gold
	_rows["gold_item"].visible = gold
	_rows["perfection"].visible = gold
	_type.clear()
	if misc:
		for misc_id in _misc_types[_quality.selected]:
			var m := ItemDatabase.get_misc(misc_id)
			_add_option_item(_type, str(m.get("name", misc_id)), ItemDatabase.get_icon(m, true))
		_type.select(0)
		_on_type_changed()
		return
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
	if _quality.selected == Quality.MASK or _quality.selected == Quality.MANTLE:
		_rebuild_preview()
		return
	if _quality.selected == Quality.GOLD:
		_refresh_gold_items()
		return
	if _is_misc_mode():
		var misc_id := _misc_id()
		_level.clear()
		for lv in MISC_LEVELS.get(misc_id, []):
			_level.add_item("Cấp %d" % lv, lv)
		_rows["level"].visible = _level.item_count > 0
		if _level.item_count > 0:
			_level.select(_level.item_count - 1)  ## mặc định cấp cao nhất (Huyền Tinh 10, Sát thủ 90)
		_rows["series"].visible = misc_id in ItemText.MISC_WITH_SERIES
		_rebuild_preview()
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
	if _quality.selected == Quality.MONEY:
		_preview_icon.texture = null
		_preview_text.text = "[center][color=#ffff00]+%s lượng[/color]

[color=#ffffff]Đang mang theo: %s lượng[/color][/center]" % [
				_money_text(MONEY_AMOUNTS[_money.selected]), _money_text(_profile.gold)]
		return
	match _quality.selected:
		Quality.MASK:
			var particular := _type.selected if _type.selected >= 0 else 0
			_preview = ItemGenerator.generate(ItemDatabase.Detail.MASK, particular, 1, 0, [])
		Quality.MANTLE:
			var level := _type.selected + 1 if _type.selected >= 0 else 1
			_preview = ItemGenerator.generate(ItemDatabase.Detail.MANTLE, 0, level, 0, [])
		Quality.POTION, Quality.PURPLE, Quality.KILLER, Quality.FERRY:
			var level := _level.get_item_id(_level.selected) if _rows["level"].visible and _level.selected >= 0 else 0
			_preview = ItemGenerator.generate_misc(_misc_id(), level, _series.selected, AMOUNTS[_amount.selected])
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
	if _quality.selected == Quality.MONEY:
		_create_money()
		return
	if _preview == null:
		return
	if _preview.is_misc():
		_create_misc()
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
	SaveManager.flush_online()
	if _on_changed.is_valid():
		_on_changed.call()
	_rebuild_preview()  ## roll món mới cho lần tạo tiếp

## Vật phẩm khác: tạo đủ "Số lượng" — món chồng được thì gom thành chồng (tối đa cột Stack gốc), không thì mỗi món 1 ô.
func _create_misc() -> void:
	var remaining: int = AMOUNTS[_amount.selected]
	var added := 0
	while remaining > 0:
		var item := ItemGenerator.generate_misc(_preview.misc_id, _preview.item_level, _preview.series, remaining)
		if not _profile.add_item(item):
			break
		added += item.count
		remaining -= item.count
	var item_name := str(_preview.get_base().get("name", "?"))
	_message.text = "Đã tạo: %s x%d" % [item_name, added] if remaining == 0 			else "Hành trang đầy — mới tạo được %s x%d" % [item_name, added]
	if added > 0:
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
		if _on_changed.is_valid():
			_on_changed.call()

## Ngân lượng: cộng vào tiền mang theo, chặn ở MONEY_MAX.
func _create_money() -> void:
	var before := _profile.gold
	_profile.gold = mini(_profile.gold + MONEY_AMOUNTS[_money.selected], MONEY_MAX)
	_message.text = "Đã thêm %s lượng" % _money_text(_profile.gold - before) if _profile.gold > before 			else "Tiền mang theo đã tối đa (%s lượng)." % _money_text(MONEY_MAX)
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	if _on_changed.is_valid():
		_on_changed.call()
	_rebuild_preview()

## 1.500.000 -> "150 vạn"; số lẻ vạn ghi đủ có dấu chấm.
static func _money_text(v: int) -> String:
	@warning_ignore("integer_division")
	if v >= 10000 and v % 10000 == 0:
		return "%d vạn" % (v / 10000)
	var s := str(v)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += "."
		out += s[i]
	return out

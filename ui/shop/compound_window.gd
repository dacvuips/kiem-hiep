extends SocialWindow
class_name CompoundWindow
## CHẾ TẠO (nút "Chế tạo" trong Hành trang): 6 thẻ theo Compound.Op — Sát thủ giản, Luyện Huyền Tinh, Nâng cấp khoáng,
## Tách khoáng, Chế đồ tím, Khảm đồ tím. Luật + tỉ lệ đúng script gốc: systems/items/compound.gd.
## Cách dùng: bấm 1 ô nguyên liệu (viền vàng = đang chọn) -> bấm món trong lưới "Hành trang" bên dưới để đặt vào; bấm lại ô đã có
## đồ để bỏ ra. Tỉ lệ từng kết quả hiện ngay khi đủ nguyên liệu.
##   - Đang ở trên map (online): gửi C_CRAFT, game server chế tạo trên hồ sơ của server rồi gửi S_NOTICE + S_PROFILE.
##   - Offline: chế tạo trên hồ sơ trong máy rồi lưu. Online nhưng ở ngoài map: phải vào map (đồ chỉ server tạo ra).

const SLOT := 56.0
const GRID_COLUMNS := 10
const ALT_TARGET := -1

var _profile: PlayerProfile
var _on_changed: Callable
var _op := 0
var _slots: Array = []        ## ItemInstance | null theo ô của Compound.slots_of(_op)
var _alts: Array = []         ## vật phẩm phụ
var _target := 0              ## ô đang chọn (ALT_TARGET = vật phẩm phụ)
var _tab_buttons: Array[Button] = []
var _slot_row: HBoxContainer
var _alt_row: HBoxContainer
var _alt_box: Control
var _preview: RichTextLabel
var _grid: GridContainer
var _grid_title: Label
var _message: Label
var _make_button: Button

static func open(host: Node, profile: PlayerProfile, on_changed: Callable = Callable()) -> CompoundWindow:
	var win := CompoundWindow.new()
	win._profile = profile
	win._on_changed = on_changed
	return SocialWindow.present(host, win, &"compound") as CompoundWindow

func _init() -> void:
	super._init("Chế Tạo", "Thợ rèn · Huyền Tinh · Sát thủ giản", 760.0)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in Compound.OP_NAMES.size():
		var b := GameUi.button(Compound.OP_NAMES[i], GameUi.TAB)
		b.custom_minimum_size = Vector2(112, 34)
		b.pressed.connect(_select_op.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	body.add_child(tabs)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size.x = 380
	top.add_child(left)
	var slot_frame := GameUi.panel(GameUi.PANEL)
	left.add_child(slot_frame)
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 10)
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_frame.add_child(_slot_row)
	_alt_box = VBoxContainer.new()
	left.add_child(_alt_box)
	var alt_head := HBoxContainer.new()
	alt_head.add_child(SocialUi.label("Vật phẩm phụ (tăng tỉ lệ):", SocialUi.MUTED, 13))
	var alt_pick := SocialUi.small_button("+ Thêm")
	alt_pick.pressed.connect(func() -> void: _set_target(ALT_TARGET))
	alt_head.add_child(alt_pick)
	_alt_box.add_child(alt_head)
	_alt_row = HBoxContainer.new()
	_alt_row.add_theme_constant_override("separation", 4)
	_alt_box.add_child(_alt_row)

	var right := GameUi.panel(GameUi.PANEL)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.fit_content = true
	_preview.scroll_active = false
	_preview.custom_minimum_size = Vector2(320, 150)
	_preview.add_theme_font_size_override("normal_font_size", 13)
	right.add_child(_preview)

	_grid_title = SocialUi.label("", SocialUi.LABEL_BLUE, 13)
	body.add_child(_grid_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 2 * (SLOT + 4) + 6)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)

	_message = SocialUi.label("", SocialUi.WARN, 13)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	var buttons := add_button_row()
	_make_button = SocialUi.stone_button("Chế tạo")
	_make_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_button.pressed.connect(_make)
	buttons.add_child(_make_button)
	var clear := SocialUi.stone_button("Bỏ hết")
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(func() -> void: _select_op(_op))
	buttons.add_child(clear)
	NetClient.server_notice.connect(_on_notice)

func _ready() -> void:
	_select_op(0)

func _select_op(op: int) -> void:
	_op = op
	for k in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[k], k == op)
	_slots = []
	for s in Compound.slots_of(op):
		_slots.append(null)
	_alts = []
	_alt_box.visible = Compound.uses_alt(op)
	_target = 0
	_message.text = ""
	_refresh()

func _set_target(t: int) -> void:
	_target = t
	_refresh()

# ---------------------------------------------------------------- vẽ

func _refresh() -> void:
	_drop_missing()
	for c in _slot_row.get_children():
		c.queue_free()
	var defs := Compound.slots_of(_op)
	for i in defs.size():
		var col := VBoxContainer.new()
		col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var b := _slot_button(_slots[i], i == _target)
		b.pressed.connect(_on_slot.bind(i))
		col.add_child(b)
		var l := SocialUi.label(str(defs[i]["label"]), SocialUi.MUTED, 11, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size.x = SLOT + 16
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		_slot_row.add_child(col)
	for c in _alt_row.get_children():
		c.queue_free()
	for i in _alts.size():
		var b := _slot_button(_alts[i], false, 40.0)
		b.pressed.connect(func() -> void:
			_alts.remove_at(i)
			_refresh())
		_alt_row.add_child(b)
	_fill_grid()
	_render_plan()

func _slot_button(item: ItemInstance, active: bool, size := SLOT) -> ItemSlotButton:
	var b := ItemSlotButton.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.small_icons = true
	b.add_theme_stylebox_override("normal", GameUi.box(GameUi.BG_INNER, GameUi.BORDER_ACTIVE if active else GameUi.BORDER, 4, 2 if active else 1, 2))
	b.add_theme_stylebox_override("hover", GameUi.box(GameUi.BG_INNER, GameUi.BORDER_ACTIVE, 4, 1, 2))
	b.add_theme_stylebox_override("pressed", GameUi.box(GameUi.ACTIVE_BG, GameUi.BORDER_ACTIVE, 4, 1, 2))
	if item:
		b.show_item(item, ItemText.build(item, _profile))
		if item.is_misc() and item.item_level > 0:   ## Huyền Tinh / khoáng / lệnh bài: cấp ở góc trên trái
			var lv := SocialUi.label("C%d" % item.item_level, SocialUi.GOLD, 11)
			lv.position = Vector2(3, 1)
			lv.add_theme_color_override("font_outline_color", Color.BLACK)
			lv.add_theme_constant_override("outline_size", 3)
			lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(lv)
	return b

## Lưới "Hành trang": món đặt được vào ô đang chọn (còn đủ số lượng chưa dùng).
func _fill_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var kind := "alt" if _target == ALT_TARGET else str(Compound.slots_of(_op)[_target]["kind"]) if _target < _slots.size() else ""
	var label := "vật phẩm phụ" if _target == ALT_TARGET else (str(Compound.slots_of(_op)[_target]["label"]) if _target < _slots.size() else "")
	_grid_title.text = "Hành trang — chọn %s:" % label.to_lower()
	if _profile == null or kind == "":
		return
	var used := _used_counts()
	var n := 0
	for it in _profile.inventory:
		it.ensure_uid()   ## món mới sinh chưa có mã -> các ô phân biệt được món
		if not Compound.fits(it, kind) or int(used.get(it.uid, 0)) >= it.count:
			continue
		var b := _slot_button(it, false)
		b.pressed.connect(_put.bind(it))
		_grid.add_child(b)
		n += 1
	if n == 0:
		_grid_title.text += "  (không có món phù hợp)"

func _render_plan() -> void:
	var lines := []
	var cost: int = Compound.COST[_op]
	lines.append("[color=#e8d9a8]Phí chế tạo:[/color] %s" % ("miễn phí" if cost == 0 else "%s lượng" % InventoryPopup.format_money(cost)))
	if _slots.has(null):
		lines.append("")
		lines.append("[color=#9a9a9a]%s[/color]" % _hint())
		_preview.text = "\n".join(lines)
		_make_button.disabled = true
		return
	var p := Compound.plan(_profile, _op, _slots, _alts)
	if not p["ok"]:
		lines.append("")
		lines.append("[color=#ff7070]%s[/color]" % p["error"])
		_preview.text = "\n".join(lines)
		_make_button.disabled = true
		return
	if p.has("note"):
		lines.append("[color=#b8b0a0]%s[/color]" % p["note"])
	lines.append("")
	lines.append("[color=#e8d9a8]Kết quả có thể:[/color]")
	for o in p["outcomes"]:
		lines.append("[color=#ffd75a]%5.1f%%[/color]  %s" % [float(o["prob"]) * 100.0, o["text"]])
	if float(p["fail"]) > 0.0005:
		lines.append("[color=#ff7070]%5.1f%%  Thất bại[/color]%s" % [float(p["fail"]) * 100.0,
			(" (%s)" % p["fail_note"]) if p.has("fail_note") else " (mất nguyên liệu)"])
	_preview.text = "\n".join(lines)
	_make_button.disabled = false

func _hint() -> String:
	match _op:
		Compound.Op.KILLER:
			return "Đặt 5 Sát Thủ lệnh cùng cấp — nhận 1 Sát thủ giản cùng cấp, hệ là hệ của 1 trong 5 lệnh."
		Compound.Op.REFINE:
			return "Đặt nhẫn, dây chuyền / hộ thân phù, ngọc bội / hương nang (trắng hoặc xanh). Càng nhiều dòng thuộc tính, Huyền Tinh càng cao."
		Compound.Op.UPGRADE:
			return "Đặt 3 Huyền Tinh (hoặc 3 khoáng thuộc tính giống nhau) cùng cấp để lên 1 cấp. Thất bại chỉ mất 1 viên."
		Compound.Op.DISTILL:
			return "Đồ trắng/xanh + Huyền Tinh + nguyên khoáng: nguyên khoáng quyết định tách dòng thứ mấy (nguyên thạch = dòng ẩn, phải cùng hệ đồ)."
		Compound.Op.FORGE:
			return "Đồ trắng/xanh (không phải trang sức) + Huyền Tinh -> đồ tím có 1-5 ô khảm. Huyền Tinh cấp càng cao càng nhiều ô; cấp 1 luôn thất bại."
		Compound.Op.ENCHASE:
			return "Đồ tím + Huyền Tinh + khoáng thuộc tính đúng ô trống đầu tiên (Huyền Thiết khoáng ô 1, Khổng Tước Thạch ô 2 ...)."
	return ""

# ---------------------------------------------------------------- thao tác

func _on_slot(i: int) -> void:
	if _slots[i] != null and _target == i:
		_slots[i] = null   ## bấm lại ô đang chọn có đồ = bỏ ra
	_target = i
	_refresh()

func _put(item: ItemInstance) -> void:
	if _target == ALT_TARGET:
		if _alts.size() < Compound.MAX_ALT:
			_alts.append(item)
	elif _target < _slots.size():
		_slots[_target] = item
		## Tự chuyển sang ô trống kế tiếp.
		for k in _slots.size():
			var j := (_target + 1 + k) % _slots.size()
			if _slots[j] == null:
				_target = j
				break
	_message.text = ""
	_refresh()

## Số đơn vị mỗi món đang nằm trong các ô (1 chồng có thể đặt vào nhiều ô).
func _used_counts() -> Dictionary:
	var used := {}
	for it in _slots + _alts:
		if it != null:
			used[it.uid] = int(used.get(it.uid, 0)) + 1
	return used

## Món đã rời hành trang (vừa chế tạo / bị dùng hết) thì bỏ khỏi ô.
func _drop_missing() -> void:
	if _profile == null:
		return
	var have := {}
	for it in _profile.inventory:
		have[it.uid] = it
	var used := {}
	for i in _slots.size():
		var it: ItemInstance = _slots[i]
		if it == null:
			continue
		var cur: ItemInstance = have.get(it.uid)
		used[it.uid] = int(used.get(it.uid, 0)) + 1
		if cur == null or cur.count < int(used[it.uid]):
			_slots[i] = null
		else:
			_slots[i] = cur
	var keep := []
	for it in _alts:
		var cur: ItemInstance = have.get(it.uid)
		used[it.uid] = int(used.get(it.uid, 0)) + 1
		if cur != null and cur.count >= int(used[it.uid]):
			keep.append(cur)
	_alts = keep

func _make() -> void:
	if _profile == null or _slots.has(null):
		return
	var uids := _slots.map(func(it: ItemInstance) -> String: return it.ensure_uid())
	var alt := _alts.map(func(it: ItemInstance) -> String: return it.ensure_uid())
	if NetClient.is_in_world():
		NetClient.send_craft(_op, uids, alt)   ## kết quả: S_NOTICE + S_PROFILE từ server
		_make_button.disabled = true
		return
	if AccountApi.is_logged_in():
		_message.text = "Đang chơi online: hãy vào bản đồ rồi chế tạo (máy chủ tạo đồ)."
		return
	var r := Compound.run(_profile, _op, uids, alt)
	_message.text = str(r["message"])
	if r["ok"]:
		SaveManager.save_profile(_profile)
		if _on_changed.is_valid():
			_on_changed.call()
	_after_craft()

func _after_craft() -> void:
	## Nguyên liệu đã dùng tự rơi khỏi ô (_drop_missing); món còn lại giữ nguyên để chế tiếp.
	_refresh()

func _on_notice(text: String) -> void:
	if not is_instance_valid(_message):
		return
	_message.text = text
	## S_PROFILE tới cùng lúc: đọc lại hồ sơ mới (GameManager.local_profile) rồi vẽ lại.
	(func() -> void:
		if is_instance_valid(self):
			_profile = GameManager.local_profile if GameManager.local_profile else _profile
			_after_craft()
			if _on_changed.is_valid():
				_on_changed.call()).call_deferred()

extends SocialWindow
class_name EventCraftWindow
## CHẾ TẠO SỰ KIỆN NĂM — bố cục như cửa sổ Giao dịch: trái là hành trang (tab Túi), phải là lưới ô nhỏ "Ô chế tạo".
## Kéo (hoặc bấm) nguyên liệu từ hành trang sang ô chế tạo, nhập số lượng muốn đặt; kéo / bấm món trong ô chế tạo để lấy lại.
## Món đặt vào CHỈ được giữ chỗ (ItemRoomView.slotted_counts) — vẫn nằm trong hành trang tới lúc bấm "Bắt đầu", nên đóng cửa sổ
## hay lưu giữa chừng không mất đồ. Chọn công thức hoặc "Tự động": SeasonalEvents.plan tự tính số lần ép tối đa, phần dư
## giữ lại hành trang; nhiều công thức chung nguyên liệu thì thử mọi thứ tự để ép được nhiều thành phẩm nhất.
## Offline: SeasonalEvents.craft trên hồ sơ máy. Online: gửi C_EVENT, server ép rồi trả S_NOTICE + S_PROFILE.

signal profile_changed

const CELL := 37
const SLOT_W := 6
const SLOT_H := 4

var _ev: Dictionary
var _profile: PlayerProfile
var _placed: Dictionary = {}          ## uid -> số lượng đặt vào
var _slots := ItemContainer.new(SLOT_W, SLOT_H, 1)
var _bag := 0
var _bag_tabs: Array[Button] = []
var _bag_view: ItemRoomView
var _slot_view: ItemRoomView
var _recipe_pick: OptionButton
var _recipe_ids: Array = []
var _times_row: HBoxContainer
var _times: SpinBox
var _preview: Label
var _result_row: HFlowContainer
var _gold_label: Label
var _msg: PanelContainer
var _start_btn: Button
var _waiting := false

static func open(host: Node, ev: Dictionary, profile: PlayerProfile) -> EventCraftWindow:
	return SocialWindow.present(host, EventCraftWindow.new(ev, profile), &"event_craft", true) as EventCraftWindow

func _init(ev: Dictionary = {}, profile: PlayerProfile = null) -> void:
	super._init("Chế tạo — %s" % ev.get("name", ""), "", 1060.0)
	_ev = ev
	_profile = profile
	if _profile == null or _ev.is_empty():
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)

	## ---- trái: hành trang
	var bag := SocialUi.section("Hành trang — bấm hoặc kéo nguyên liệu sang ô chế tạo")
	cols.add_child(bag[0])
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	bag[1].add_child(tabs)
	for i in PlayerProfile.OPEN_BAGS:
		var b := GameUi.button("Túi %d" % (i + 1), GameUi.TAB)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_bag = i
			_refresh())
		tabs.add_child(b)
		_bag_tabs.append(b)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PlayerProfile.ROOM_WIDTH * CELL + 10, 380)
	_bag_view = ItemRoomView.new()
	_bag_view.cell = CELL
	scroll.add_child(_bag_view)
	bag[1].add_child(scroll)
	_gold_label = SocialUi.label("", SocialUi.GOLD, 14, HORIZONTAL_ALIGNMENT_CENTER)
	bag[1].add_child(_gold_label)

	## ---- phải: công thức + ô chế tạo + xem trước
	var right := SocialUi.section("Ô chế tạo")
	right[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right[0])
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 8)
	pick_row.add_child(SocialUi.label("Công thức:", GameUi.GOLD, 13))
	_recipe_pick = OptionButton.new()
	_recipe_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_pick.add_item("Tự động — ép được nhiều thành phẩm nhất")
	_recipe_ids.append(SeasonalEvents.AUTO)
	for r in _ev.get("recipes", []):
		_recipe_pick.add_item(str(r.get("name", "")))
		_recipe_ids.append(str(r["id"]))
	_recipe_pick.item_selected.connect(func(_i: int) -> void: _refresh())
	pick_row.add_child(_recipe_pick)
	right[1].add_child(pick_row)

	var slot_box := CenterContainer.new()
	_slot_view = ItemRoomView.new()
	_slot_view.cell = CELL
	slot_box.add_child(_slot_view)
	right[1].add_child(slot_box)

	_times_row = HBoxContainer.new()
	_times_row.add_theme_constant_override("separation", 8)
	_times_row.add_child(SocialUi.label("Số lần mua:", GameUi.GOLD, 13))
	_times = SpinBox.new()
	_times.min_value = 1
	_times.max_value = SeasonalEvents.MAX_BATCH
	_times.value = 1
	_times.value_changed.connect(func(_v: float) -> void: _refresh())
	_times_row.add_child(_times)
	right[1].add_child(_times_row)

	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	var fill := GameUi.button("Tự đặt nguyên liệu", GameUi.BUTTON)
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.tooltip_text = "Đặt hết nguyên liệu của công thức đang chọn (Tự động: mọi nguyên liệu sự kiện) có trong hành trang"
	fill.pressed.connect(_auto_fill)
	quick.add_child(fill)
	var clear := GameUi.button("Bỏ hết", GameUi.BUTTON)
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(func() -> void:
		_placed.clear()
		_refresh())
	quick.add_child(clear)
	right[1].add_child(quick)

	_preview = SocialUi.label("", SocialUi.TEXT, 13)
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size = Vector2(1, 90)
	right[1].add_child(_preview)
	right[1].add_child(SocialUi.label("Thành phẩm:", GameUi.GOLD, 13))
	_result_row = SeasonalEventUi.flow(4)
	right[1].add_child(_result_row)

	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)

	var buttons := add_button_row()
	var guide := SocialUi.stone_button("Hướng dẫn")
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.pressed.connect(func() -> void: SeasonalEventUi.open_guide(get_host(), _ev))
	buttons.add_child(guide)
	_start_btn = SocialUi.stone_button("Bắt đầu")
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.pressed.connect(_on_start)
	buttons.add_child(_start_btn)
	var close := SocialUi.stone_button("Đóng")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void: close_requested.emit())
	buttons.add_child(close)

	## bấm / kéo: hành trang -> ô chế tạo (nhập số lượng); ô chế tạo -> hành trang (lấy lại)
	_bag_view.item_pressed.connect(_ask_place)
	_slot_view.item_pressed.connect(func(item: ItemInstance) -> void: _unplace(item.uid))
	_slot_view.transfer_handler = func(item: ItemInstance, from: Object, _to: Object, _x: int, _y: int, _b: int) -> bool:
		if from == _profile:
			_ask_place(item)
		return false
	_bag_view.transfer_handler = func(item: ItemInstance, from: Object, _to: Object, _x: int, _y: int, _b: int) -> bool:
		if from == _slots:
			_unplace(item.uid)
		return false
	if NetClient.server_notice.is_connected(_on_notice) == false:
		NetClient.server_notice.connect(_on_notice)
	_refresh()

func _exit_tree() -> void:
	if NetClient.server_notice.is_connected(_on_notice):
		NetClient.server_notice.disconnect(_on_notice)

# ---------------------------------------------------------------- đặt / lấy nguyên liệu

func _remaining(item: ItemInstance) -> int:
	return item.count - int(_placed.get(item.uid, 0))

func _ask_place(item: ItemInstance) -> void:
	if item == null:
		return
	if not item.is_misc() or not SeasonalEvents.material_ids(_ev).has(item.misc_id):
		_say("%s không phải nguyên liệu của %s." % [item.get_display_name(), _ev.get("name", "")], false)
		return
	var left := _remaining(item)
	if left <= 0:
		_say("Đã đặt hết %s." % item.get_display_name(), false)
		return
	if left == 1:
		_place(item, 1)
		return
	SocialWindow.prompt(get_host(), "Đặt %s" % item.get_display_name(), "Số lượng (1 – %d)" % left, func(text: String) -> void:
		var n := int(text) if text.strip_edges().is_valid_int() else 0
		if n > 0:
			_place(item, mini(n, left)), str(left), false, left)

func _place(item: ItemInstance, n: int) -> void:
	item.ensure_uid()
	_placed[item.uid] = mini(int(_placed.get(item.uid, 0)) + n, item.count)
	_say("", true)
	_refresh()

func _unplace(uid: String) -> void:
	_placed.erase(uid)
	_refresh()

## Đặt hết nguyên liệu của công thức đang chọn (Tự động: mọi nguyên liệu của sự kiện) có trong hành trang.
func _auto_fill() -> void:
	var want := {}
	var rid := _current_recipe()
	if rid == SeasonalEvents.AUTO:
		want = SeasonalEvents.material_ids(_ev)
	else:
		for m in SeasonalEvents.get_recipe(_ev, rid).get("materials", []):
			for mid in SeasonalEvents.mat_items(m):
				want[mid] = true
	var n := 0
	for it in _profile.inventory:
		if it.is_misc() and want.has(it.misc_id) and not SecurityLock.is_item_locked(it) and it.trade_price == 0:
			it.ensure_uid()
			_placed[it.uid] = it.count
			n += 1
	if n == 0:
		_say("Hành trang chưa có nguyên liệu nào cho công thức này.", false)
	_refresh()

## Bỏ món đã đặt mà không còn trong hành trang (vừa ép / dùng / bán) hoặc đã ít đi.
func _sync_placed() -> void:
	var by_uid := {}
	for it in _profile.inventory:
		by_uid[it.uid] = it
	for uid in _placed.keys():
		var it: ItemInstance = by_uid.get(uid)
		if it == null:
			_placed.erase(uid)
		elif int(_placed[uid]) > it.count:
			_placed[uid] = it.count

func _rebuild_slots() -> void:
	_slots.clear()
	for it in _profile.inventory:
		var n := int(_placed.get(it.uid, 0))
		if n <= 0:
			continue
		var c := ItemInstance.from_dict(it.to_dict())
		c.uid = it.uid
		c.count = n
		_slots.add_item(c)

# ---------------------------------------------------------------- hiển thị

func _current_recipe() -> String:
	var i := _recipe_pick.selected if _recipe_pick != null else 0
	return str(_recipe_ids[i]) if i >= 0 and i < _recipe_ids.size() else SeasonalEvents.AUTO

func _times_cap() -> int:
	var r := SeasonalEvents.get_recipe(_ev, _current_recipe())
	return int(_times.value) if not r.is_empty() and (r.get("materials", []) as Array).is_empty() else -1

func _refresh() -> void:
	if _profile == null:
		return
	if GameManager.local_profile != null and GameManager.local_profile != _profile and NetClient.is_in_world():
		_profile = GameManager.local_profile
	_sync_placed()
	_rebuild_slots()
	for i in _bag_tabs.size():
		GameUi.set_active(_bag_tabs[i], i == _bag)
	_bag_view.bag = _bag
	_bag_view.slotted_counts = _placed.duplicate()
	_bag_view.setup(_profile)
	_slot_view.setup(_slots, _profile)
	_gold_label.text = "%s lượng" % InventoryPopup.format_money(_profile.gold)

	var rid := _current_recipe()
	var recipe := SeasonalEvents.get_recipe(_ev, rid)
	var buying := not recipe.is_empty() and (recipe.get("materials", []) as Array).is_empty()
	_times_row.visible = buying
	for c in _result_row.get_children():
		c.queue_free()
	var per := SeasonalEvents.current_period(_ev)
	var active: bool = per.get("status", "") == "ongoing"
	var p := SeasonalEvents.plan(_profile, _ev, rid, _placed, _times_cap())
	if not active:
		_preview.text = "Sự kiện chưa diễn ra — mở từ %s đến %s." % [SeasonalEvents.format_date(per["start"]), SeasonalEvents.format_date(per["end"])]
		_preview.add_theme_color_override("font_color", SocialUi.WARN)
	elif _placed.is_empty() and not buying:
		_preview.text = "Kéo nguyên liệu vào ô chế tạo (hoặc bấm \"Tự đặt nguyên liệu\")."
		_preview.add_theme_color_override("font_color", SocialUi.SUBTITLE)
		if not recipe.is_empty():
			_result_row.add_child(SeasonalEventUi.recipe_row(recipe))
	elif not p["ok"]:
		_preview.text = str(p["message"])
		_preview.add_theme_color_override("font_color", SocialUi.WARN)
		if not recipe.is_empty():
			_result_row.add_child(SeasonalEventUi.recipe_row(recipe))
	else:
		_preview.add_theme_color_override("font_color", SocialUi.TEXT)
		var lines: Array = []
		for s in p["steps"]:
			var r: Dictionary = s[0]
			var rate := " (tỷ lệ %s%%)" % SeasonalEvents.pct(float(r["rate"])) if r.has("rate") else ""
			lines.append("• Ép %d lần: %s%s" % [int(s[1]), r.get("name", ""), rate])
		if int(p["money"]) > 0:
			lines.append("Tốn %s lượng." % SeasonalEvents._fmt(int(p["money"])))
		var left: Dictionary = p["left"]
		if not left.is_empty():
			var parts: Array = []
			for mid in left:
				parts.append("%d %s" % [int(left[mid]), SeasonalEvents.item_name(str(mid))])
			lines.append("Phần dư giữ lại hành trang: " + ", ".join(parts))
		_preview.text = "\n".join(lines)
		for s in p["steps"]:
			var res: Variant = s[0]["result"]
			if res is Dictionary and res.has("item"):
				_result_row.add_child(SeasonalEventUi.icon_cell(str(res["item"]), int(res.get("count", 1)) * int(s[1])))
			else:
				for mid in SeasonalEvents.result_items(res).slice(0, 10):
					_result_row.add_child(SeasonalEventUi.icon_cell(str(mid)))
				if SeasonalEvents.result_items(res).is_empty():
					_result_row.add_child(SocialUi.label(", ".join(SeasonalEvents.describe(res)), GameUi.LABEL_GREEN, 13))
	_start_btn.disabled = not active or not p["ok"] or _waiting

func _say(text: String, good: bool) -> void:
	if text == "":
		_msg.visible = false
		return
	SocialUi.set_banner(_msg, text, good)
	_msg.visible = true

# ---------------------------------------------------------------- ép

func _on_start() -> void:
	var rid := _current_recipe()
	var cap := _times_cap()
	if NetClient.is_in_world():
		_waiting = true
		_start_btn.disabled = true
		NetClient.send_event("craft", {"ev": str(_ev["id"]), "recipe": rid, "items": _placed.duplicate(), "times": cap})
		_say("Đang gửi lên máy chủ…", true)
		return
	if GameModeManager.is_online():
		_say("Mất kết nối máy chủ, chưa ép được.", false)
		return
	var r := SeasonalEvents.craft(_profile, str(_ev["id"]), rid, _placed.duplicate(), cap)
	_say(str(r["message"]), bool(r["ok"]))
	if r["ok"]:
		_placed.clear()
		SaveManager.save_profile(_profile)
		profile_changed.emit()
	_refresh()

func _on_notice(text: String) -> void:
	if not _waiting or not is_instance_valid(self):
		return
	_waiting = false
	var good := text.begins_with("Ép ")
	_say(text, good)
	if good:
		_placed.clear()
	## S_PROFILE tới sau / cùng lúc S_NOTICE — làm mới ở khung sau để lấy hồ sơ mới.
	(func() -> void:
		if is_instance_valid(self):
			_refresh()
			profile_changed.emit()).call_deferred()

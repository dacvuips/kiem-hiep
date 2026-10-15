extends SocialWindow
class_name AutoSettingsWindow
## Khung "Thiết lập auto đánh" — theo bảng auto của kiemhieptinh1.vn: 2 thẻ trên cùng AUTO - Luyện công / AUTO - PK (mỗi thẻ 1 bộ
## AutoSettings riêng, thẻ đang chọn là bộ auto dùng), cột trái 5 mục Hồi phục / Tấn công / Di chuyển / Hậu cần & Chiến Báo /
## Nhặt đồ & Tổ đội. Sửa gì ghi thẳng vào bộ đang chọn; đóng khung / bật auto thì lưu hồ sơ.

const PAGES := ["Hồi phục", "Tấn công", "Di chuyển", "Hậu cần &\nChiến Báo", "Nhặt đồ\n& Tổ đội"]
const MODE_NAMES := ["AUTO - Luyện công", "AUTO - PK"]
const POTIONS := ["Hồi Thiên Đan", "Đại Bổ Tán", "Ngũ Hoa Ngọc Lộ Hoàn"]
const SLOT_SIZE := Vector2(52, 52)
const NUM_WIDTH := 84.0

var profile: PlayerProfile
var _s: AutoSettings
var _page := 0
var _mode_buttons: Array[Button] = []
var _page_buttons: Array[Button] = []
var _content: VBoxContainer
var _toggle: Button

static func open(host: Node, p: PlayerProfile) -> AutoSettingsWindow:
	return SocialWindow.present(host, AutoSettingsWindow.new(p), &"auto_settings") as AutoSettingsWindow

func _init(p: PlayerProfile) -> void:
	super._init("Thiết lập auto đánh", "", 960.0)
	profile = p
	_s = p.get_auto_settings()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for i in MODE_NAMES.size():
		var b := _tab_button(MODE_NAMES[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_mode.bind(i))
		tabs.add_child(b)
		_mode_buttons.append(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	row.add_child(nav)
	for i in PAGES.size():
		var b := _tab_button(PAGES[i])
		b.custom_minimum_size = Vector2(110, 64)
		b.pressed.connect(_set_page.bind(i))
		nav.add_child(b)
		_page_buttons.append(b)
	var panel := GameUi.panel(GameUi.PANEL)
	panel.custom_minimum_size = Vector2(810, 430)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	var buttons := add_button_row()
	_toggle = SocialUi.stone_button("")
	_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toggle.pressed.connect(_on_toggle_auto)
	buttons.add_child(_toggle)
	var close := SocialUi.stone_button("Đóng")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void: close_requested.emit())
	buttons.add_child(close)
	close_requested.connect(_save)
	_refresh_tabs()
	_rebuild()

func _process(_delta: float) -> void:
	var p := _player()
	var on: bool = p != null and p.is_auto_mode
	var text := "Tắt auto" if on else "Bật auto"
	if _toggle.text != text:
		_toggle.text = text

# ------------------------------------------------------------------ thẻ / trang

func _set_mode(mode: int) -> void:
	if mode == profile.auto_mode:
		_refresh_tabs()  # bấm lại thẻ đang chọn: thẻ toggle tự nhả ra → đặt lại trạng thái chọn
		return
	profile.auto_mode = mode
	_s = profile.get_auto_settings()
	_changed()
	_refresh_tabs()
	_rebuild()

func _set_page(page: int) -> void:
	_page = page
	_refresh_tabs()
	_rebuild()

func _refresh_tabs() -> void:
	for i in _mode_buttons.size():
		GameUi.set_active(_mode_buttons[i], i == profile.auto_mode)
	for i in _page_buttons.size():
		GameUi.set_active(_page_buttons[i], i == _page)

func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()
	match _page:
		0: _build_recovery()
		1: _build_attack()
		2: _build_movement()
		3: _build_logistics()
		4: _build_loot()

func _changed() -> void:
	var p := _player()
	if p != null:
		p.auto.apply_settings()

func _save() -> void:
	_changed()
	SaveManager.save_profile(profile)

func _on_toggle_auto() -> void:
	var p := _player()
	if p == null:
		return
	_save()
	p.is_auto_mode = not p.is_auto_mode

func _player() -> Node:
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null

# ------------------------------------------------------------------ 1. Hồi phục

func _build_recovery() -> void:
	_header("Sử dụng Dược Phẩm")
	var grid := _grid(6)
	for h in ["", "Mức 1", "Mili giây", "Mức 2", "Số lượng", "Mili giây"]:
		grid.add_child(SocialUi.label(h, SocialUi.TITLE, 13, HORIZONTAL_ALIGNMENT_CENTER))
	grid.add_child(_check("Sinh lực (%):", "hp_on"))
	grid.add_child(_num("hp_lv1", 1, 99))
	grid.add_child(_num("hp_ms1", 100, 10000, 100))
	grid.add_child(_num("hp_lv2", 1, 99))
	grid.add_child(_num("hp_count2", 1, 10))
	grid.add_child(_num("hp_ms2", 100, 10000, 100))
	grid.add_child(_check("Nội lực (%):", "mp_on"))
	grid.add_child(_num("mp_lv1", 1, 99))
	grid.add_child(_num("mp_ms1", 100, 10000, 100))
	grid.add_child(_num("mp_lv2", 1, 99))
	grid.add_child(_num("mp_count2", 1, 10))
	grid.add_child(_num("mp_ms2", 100, 10000, 100))
	_note("Chưa có bình thuốc trong game: máu dưới Mức 1 thì auto ngồi thiền hồi máu khi quanh mình không có địch.")

	_header("Dùng Thổ Địa Phù Khi")
	var g2 := _grid(3)
	g2.add_child(_row([_check("Sinh lực dưới (%):", "tdp_low_hp_on"), _num("tdp_low_hp", 1, 99)]))
	g2.add_child(_check("Hết bình sinh lực", "tdp_no_hp_potion"))
	g2.add_child(_check("Hành trang đầy", "tdp_bag_full"))
	g2.add_child(_row([_check("Độ bền thấp", "tdp_low_dura_on"), _num("tdp_low_dura", 1, 99)]))
	g2.add_child(_check("Hết bình nội lực", "tdp_no_mp_potion"))
	_note("Chưa có Thổ Địa Phù / thành thị: gặp các điều kiện trên auto sẽ dừng tại chỗ và ghi chiến báo.")

	_header("Vật phẩm hỗ trợ")
	var g3 := _grid(3)
	g3.add_child(_check("Nhân đôi kinh nghiệm", "use_double_exp"))
	g3.add_child(_check("Tăng tốc kỹ năng", "use_skill_speed"))
	g3.add_child(_check("Tăng cường May Mắn", "use_luck"))
	g3.add_child(_check("Tẩy trị PK", "use_pk_clear"))
	g3.add_child(_check("Dùng thuốc bổ trợ", "use_tonic"))

# ------------------------------------------------------------------ 2. Tấn công

enum SlotKind { ATTACK, SUPPORT, AURA }

func _build_attack() -> void:
	_header("Thiết lập Tấn Công")
	var groups := HBoxContainer.new()
	groups.add_theme_constant_override("separation", 28)
	_content.add_child(groups)
	for g in [["Tấn công", "attack_skills", SlotKind.ATTACK], ["Kỹ năng Hỗ trợ", "support_skills", SlotKind.SUPPORT],
			["Vòng sáng & Buff máu", "aura_skills", SlotKind.AURA]]:
		var box := VBoxContainer.new()
		box.add_child(SocialUi.label(g[0], SocialUi.TEXT, 14))
		var slots := HBoxContainer.new()
		slots.add_theme_constant_override("separation", 6)
		for i in AutoSettings.SLOTS:
			slots.add_child(_skill_slot(g[1], i, g[2]))
		box.add_child(slots)
		groups.add_child(box)
	_content.add_child(_row([SocialUi.label("Phạm vi", SocialUi.TEXT, 14), _num("scan_range", 100, 5000, 50),
		SocialUi.label("    Tiếp cận", SocialUi.TEXT, 14), _num("approach", 50, 5000, 50)]))
	_note("Không đặt ô Tấn công nào thì auto đánh bằng đòn ở nút chính. Bấm ô để chọn / bỏ kỹ năng.")

	_header("Tuỳ biến ưu tiên")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_content.add_child(row)
	var left := _grid(2)
	left.get_parent().remove_child(left)
	row.add_child(left)
	left.add_child(_check("Đánh người", "target_players"))
	left.add_child(_check("Đánh quái", "target_monsters"))
	left.add_child(_check("Ưu tiên Boss", "prefer_boss"))
	left.add_child(_check("Truy đuổi", "chase"))
	left.add_child(_check("Mục tiêu thấp máu", "prefer_low_hp"))
	var el := VBoxContainer.new()
	row.add_child(el)
	el.add_child(_check("Ngũ hành", "element_filter_on"))
	for i in 5:
		var cb := CheckBox.new()
		cb.text = ElementTypes.ELEMENT_NAME.get(i, "?")
		for c in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
			cb.add_theme_color_override(c, Color("#" + ItemText.ELEMENT_COLORS[i]))
		cb.button_pressed = bool(_s.elements[i])
		cb.toggled.connect(func(on: bool) -> void:
			_s.elements[i] = on
			_changed())
		el.add_child(cb)
	var sect_col := VBoxContainer.new()
	row.add_child(sect_col)
	sect_col.add_child(_check("Môn phái", "sect_filter_on"))
	var sects := GridContainer.new()
	sects.columns = 2
	sects.add_theme_constant_override("h_separation", 12)
	sect_col.add_child(sects)
	for sect in SectRegistry.load_all():
		var cb := CheckBox.new()
		cb.text = sect.sect_name
		cb.add_theme_color_override("font_color", SocialUi.TEXT)
		cb.button_pressed = sect.id in _s.sects
		var sid := sect.id
		cb.toggled.connect(func(on: bool) -> void:
			if on and not (sid in _s.sects):
				_s.sects.append(sid)
			elif not on:
				_s.sects.erase(sid)
			_changed())
		sects.add_child(cb)

func _skill_slot(key: String, index: int, kind: SlotKind) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SLOT_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	## Ô kỹ năng tròn (ô biểu tượng, không phải nút chữ) — giữ hình riêng nhưng màu lấy từ GameUi
	b.add_theme_stylebox_override("normal", GameUi.box(GameUi.BUTTON_BG, GameUi.BORDER, 26, 2, 4))
	b.add_theme_stylebox_override("hover", GameUi.box(GameUi.BUTTON_BG_HOVER, GameUi.BORDER_ACTIVE, 26, 2, 4))
	b.add_theme_stylebox_override("pressed", GameUi.box(GameUi.BUTTON_BG_PRESSED, GameUi.BORDER_ACTIVE, 26, 2, 4))
	var skill := _find_skill(str(_s.get(key)[index]))
	if skill != null:
		b.icon = skill.icon
		b.tooltip_text = skill.skill_name
		if skill.icon == null:
			b.text = skill.skill_name.left(4)
	else:
		b.text = "+"
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", SocialUi.MUTED)
	b.pressed.connect(func() -> void: _open_skill_menu(b, key, index, kind))
	return b

func _open_skill_menu(anchor: Control, key: String, index: int, kind: SlotKind) -> void:
	var menu := PopupMenu.new()
	var options: Array[SkillDefinition] = _candidates(kind)
	menu.add_item("— Bỏ trống —", 0)
	for i in options.size():
		if options[i].icon != null:
			menu.add_icon_item(options[i].icon, options[i].skill_name, i + 1)
		else:
			menu.add_item(options[i].skill_name, i + 1)
		menu.set_item_icon_max_width(menu.item_count - 1, 28)
	menu.id_pressed.connect(func(id: int) -> void:
		_s.get(key)[index] = "" if id == 0 else options[id - 1].id
		_changed()
		_rebuild())
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.popup(Rect2i(Vector2i(anchor.get_screen_position() + Vector2(0, anchor.size.y)), Vector2i.ZERO))

## Kỹ năng đã học hợp nhóm: Tấn công = chiêu đánh địch; Hỗ trợ = buff/bùa; Vòng sáng & Buff máu = hào quang + buff lên mình/đồng đội.
func _candidates(kind: SlotKind) -> Array[SkillDefinition]:
	var out: Array[SkillDefinition] = []
	var p := _player()
	if p == null:
		return out
	var controller: SectSkillController = p.skill_controller
	if controller.sect == null:
		return out
	for skill in controller.sect.skills:
		if not skill.can_assign_to_hotbar() or not controller.is_skill_usable(skill):
			continue
		var state := skill.is_state_skill()
		var ok := false
		match kind:
			SlotKind.ATTACK: ok = skill.target_enemy and not skill.is_aura and not state
			SlotKind.SUPPORT: ok = state and not skill.is_aura
			SlotKind.AURA: ok = skill.is_aura or (state and not skill.target_enemy)
		if ok:
			out.append(skill)
	return out

func _find_skill(id: String) -> SkillDefinition:
	var p := _player()
	return p.skill_controller.get_skill(id) if p != null and id != "" else null

# ------------------------------------------------------------------ 3. Di chuyển

func _build_movement() -> void:
	var anchor_label := SocialUi.label(_anchor_text(), SocialUi.MUTED, 13)
	var save_anchor := SocialUi.small_button("Lưu toạ độ")
	save_anchor.pressed.connect(func() -> void:
		var feet: Variant = _player_feet()
		if feet == null:
			return
		_s.anchor = feet
		_s.has_anchor = true
		_changed()
		anchor_label.text = _anchor_text())
	_content.add_child(_row([_check("Đánh quanh điểm", "anchor_on"), _num("anchor_radius", 100, 5000, 50), save_anchor, anchor_label]))
	_content.add_child(_row([_check("Chạy toạ độ", "route_on"), _num("route_radius", 100, 5000, 50),
		SocialUi.label("      ", SocialUi.TEXT), _check("Theo sau đội trưởng", "follow_leader_on"), _num("follow_leader_dist", 50, 2000, 10)]))
	_content.add_child(_row([_check("Đổi bản đồ khi chết", "change_map_on_death"), _num("change_map_deaths", 1, 20),
		SocialUi.label("lần trong", SocialUi.TEXT, 14), _num("change_map_minutes", 1, 60), SocialUi.label("phút", SocialUi.TEXT, 14)]))

	_header("Toạ độ chạy (lần lượt từ trên xuống)")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	var list := SocialUi.item_list(Vector2(320, 180))
	row.add_child(list)
	var fill := func() -> void:
		list.clear()
		for i in _s.route.size():
			list.add_item("%d.  %s" % [i + 1, AutoSettings.coord_text(_s.route[i])])
	fill.call()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	var add := SocialUi.stone_button("Thêm", Vector2(110, 36))
	add.tooltip_text = "Thêm vị trí đang đứng"
	add.pressed.connect(func() -> void:
		var feet: Variant = _player_feet()
		if feet != null:
			_s.route.append(feet)
			_changed()
			fill.call())
	var del := SocialUi.stone_button("Xoá", Vector2(110, 36))
	del.pressed.connect(func() -> void:
		var sel := list.get_selected_items()
		if not sel.is_empty():
			_s.route.remove_at(sel[0])
			_changed()
			fill.call())
	var clear := SocialUi.stone_button("Xoá hết", Vector2(110, 36))
	clear.pressed.connect(func() -> void:
		_s.route.clear()
		_changed()
		fill.call())
	for b in [add, del, clear]:
		col.add_child(b)
	_note("Chạy toạ độ: đánh quái trong bán kính quanh từng toạ độ, hết quái thì sang toạ độ kế. Bản đồ hiện chỉ có 1 nên chưa đổi bản đồ khi chết, chỉ ghi chiến báo.")

func _anchor_text() -> String:
	return "Điểm: %s" % AutoSettings.coord_text(_s.anchor) if _s.has_anchor else "Chưa lưu điểm"

func _player_feet() -> Variant:
	var p := _player()
	return p.global_position + Vector2(0, VltkWorld.FEET_OFFSET) if p != null else null

# ------------------------------------------------------------------ 4. Hậu cần & Chiến báo

func _build_logistics() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	_content.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(SocialUi.label("Thiết lập mua Dược:", SocialUi.TITLE, 14))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	left.add_child(g)
	g.add_child(_check("Rút tiền vạn", "withdraw_money"))
	g.add_child(_check("Cất trang bị", "store_equip"))
	g.add_child(_check("Bán rác", "sell_junk"))
	g.add_child(_check("Sửa trang bị", "repair_equip"))
	for i in _s.potion_buys.size():
		left.add_child(_potion_row(i))
	left.add_child(_row([_check("Mua Tuý Cơ Hồng Bao", "buy_tuyco"), _check("Mua TĐP", "buy_tdp")]))
	left.add_child(_check("Quay lại điểm cũ", "return_to_spot"))
	var map_edit := SocialUi.line_edit("<Bản đồ luyện công>")
	map_edit.text = _s.train_map
	map_edit.custom_minimum_size.x = 220
	map_edit.text_changed.connect(func(t: String) -> void: _s.train_map = t)
	left.add_child(_row([_check("", "train_map_on"), map_edit]))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(SocialUi.label("Thiết lập chiến báo:", SocialUi.TITLE, 14))
	right.add_child(_row([_check("Phù liên tiếp", "report_tdp_on"), _num("report_tdp_count", 1, 20),
		SocialUi.label("lần trong", SocialUi.TEXT, 14), _num("report_tdp_minutes", 1, 60), SocialUi.label("phút", SocialUi.TEXT, 14)]))
	right.add_child(_row([SocialUi.label("      Đổ thông báo", SocialUi.TEXT, 14), _num("report_tdp_notify", 1, 10), SocialUi.label("lần", SocialUi.TEXT, 14)]))
	right.add_child(_row([_check("Chết liên tiếp", "report_death_on"), _num("report_death_count", 1, 20),
		SocialUi.label("lần trong", SocialUi.TEXT, 14), _num("report_death_minutes", 1, 60), SocialUi.label("phút", SocialUi.TEXT, 14)]))
	right.add_child(_row([SocialUi.label("      Đổ thông báo", SocialUi.TEXT, 14), _num("report_death_notify", 1, 10), SocialUi.label("lần", SocialUi.TEXT, 14)]))
	var history := SocialUi.stone_button("Xem lịch sử", Vector2(160, 36))
	history.pressed.connect(_show_history)
	right.add_child(history)
	_note("Chưa có cửa hàng / thuốc / rương tự động: mục mua dược, bán, cất, sửa được lưu sẵn để dùng khi có hệ thống.")

func _potion_row(i: int) -> HBoxContainer:
	var entry: Array = _s.potion_buys[i]
	var cb := CheckBox.new()
	cb.button_pressed = bool(entry[0])
	cb.toggled.connect(func(on: bool) -> void: _s.potion_buys[i][0] = on)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.custom_minimum_size.x = 220
	for n in POTIONS:
		opt.add_item(n)
	opt.select(maxi(POTIONS.find(str(entry[1])), 0))
	opt.item_selected.connect(func(idx: int) -> void: _s.potion_buys[i][1] = POTIONS[idx])
	var qty := _spin(0, 200, 1, int(entry[2]))
	qty.value_changed.connect(func(v: float) -> void: _s.potion_buys[i][2] = int(v))
	return _row([cb, opt, qty])

func _show_history() -> void:
	var win := SocialWindow.new("Lịch sử chiến báo", "%d dòng gần nhất" % profile.auto_log.size(), 460.0)
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(420, 280)
	text.add_theme_color_override("default_color", SocialUi.TEXT)
	var lines := []
	for i in range(profile.auto_log.size() - 1, -1, -1):
		var e: Dictionary = profile.auto_log[i]
		var t := Time.get_datetime_string_from_unix_time(int(e.get("t", 0)) + _tz_offset(), true)
		lines.append("[color=#9a9a9a]%s[/color]  %s" % [t, str(e.get("text", ""))])
	text.bbcode_enabled = true
	text.text = "\n".join(lines) if not lines.is_empty() else "Chưa có chiến báo."
	win.body.add_child(text)
	SocialWindow.present(get_parent().get_parent(), win, &"auto_history")

static func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

# ------------------------------------------------------------------ 5. Nhặt đồ & Tổ đội

func _build_loot() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_content.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(SocialUi.label("Thiết lập nhặt đồ:", SocialUi.TITLE, 14))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	left.add_child(g)
	g.add_child(_row([SocialUi.label("Phạm vi nhặt", SocialUi.TEXT, 14), _num("pick_range", 50, 3000, 50)]))
	g.add_child(_check("Nhặt tiền vạn", "pick_money"))
	g.add_child(_check("Nhặt tất cả", "pick_all"))
	g.add_child(_check("Nhặt trang bị xanh", "pick_blue"))
	g.add_child(_check("Tuỳ chọn lọc đồ khi nhặt", "pick_filter"))
	g.add_child(_check("Đạo cụ", "pick_props"))
	g.add_child(Control.new())
	g.add_child(_check("Không bán trang sức", "keep_jewelry"))

	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 4)
	left.add_child(SocialUi.label("Lọc thuộc tính (chữ trong dòng thuộc tính + giá trị tối thiểu):", SocialUi.MUTED, 12))
	left.add_child(rows_box)
	var fill_rows := func(self_ref: Callable) -> void:
		for c in rows_box.get_children():
			c.queue_free()
		for i in _s.filter_rows.size():
			rows_box.add_child(_filter_row(i, self_ref))
	fill_rows.call(fill_rows)
	var add_row := SocialUi.small_button("⊕  Thêm dòng")
	add_row.pressed.connect(func() -> void:
		_s.filter_rows.append({"text": "", "min": 0})
		fill_rows.call(fill_rows))
	left.add_child(add_row)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size.x = 210
	row.add_child(right)
	right.add_child(_check("Thiết lập tổ đội", "team_on"))
	right.add_child(SocialUi.label("Mời đội", SocialUi.TEXT, 14))
	right.add_child(_option("invite_mode", AutoSettings.INVITE_NAMES))
	right.add_child(SocialUi.label("Nhận lời mời", SocialUi.TEXT, 14))
	right.add_child(_option("accept_mode", AutoSettings.ACCEPT_NAMES))
	var list_btn := SocialUi.stone_button("Thiết lập danh sách", Vector2(0, 36))
	var set_list := func(t: String) -> void:
		var names := []
		for n in t.split(",", false):
			if n.strip_edges() != "":
				names.append(n.strip_edges())
		_s.team_list = names
		_changed()
	list_btn.pressed.connect(func() -> void:
		SocialWindow.prompt(get_parent().get_parent(), "Danh sách tổ đội", "Tên người chơi, cách nhau bằng dấu phẩy",
				set_list, ", ".join(_s.team_list)))
	right.add_child(list_btn)

func _filter_row(i: int, refill: Callable) -> HBoxContainer:
	var data: Dictionary = _s.filter_rows[i]
	var edit := SocialUi.line_edit("VD: Sinh lực / Kháng độc / Tốc độ chạy")
	edit.text = str(data.get("text", ""))
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(t: String) -> void: _s.filter_rows[i]["text"] = t)
	var min_v := _spin(0, 9999, 1, int(data.get("min", 0)))
	min_v.value_changed.connect(func(v: float) -> void: _s.filter_rows[i]["min"] = int(v))
	var del := GameUi.button(GameUi.ICON_CLOSE)
	del.pressed.connect(func() -> void:
		_s.filter_rows.remove_at(i)
		refill.call(refill))
	return _row([edit, min_v, del])

# ------------------------------------------------------------------ widget gắn với AutoSettings

func _check(text: String, key: String) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_color_override("font_color", SocialUi.TEXT)
	cb.add_theme_color_override("font_pressed_color", SocialUi.TEXT)
	cb.add_theme_color_override("font_hover_color", SocialUi.GOLD)
	cb.button_pressed = bool(_s.get(key))
	cb.toggled.connect(func(on: bool) -> void:
		_s.set(key, on)
		_changed())
	return cb

func _num(key: String, min_v: int, max_v: int, step := 1) -> SpinBox:
	var sb := _spin(min_v, max_v, step, int(_s.get(key)))
	sb.value_changed.connect(func(v: float) -> void: _s.set(key, int(v)))
	return sb

func _spin(min_v: int, max_v: int, step: int, value: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.step = step
	sb.value = value
	sb.custom_minimum_size.x = NUM_WIDTH
	sb.alignment = HORIZONTAL_ALIGNMENT_CENTER
	sb.get_line_edit().add_theme_color_override("font_color", SocialUi.GOLD)
	return sb

func _option(key: String, names: Array) -> OptionButton:
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	for n in names:
		opt.add_item(n)
	opt.select(clampi(int(_s.get(key)), 0, names.size() - 1))
	opt.item_selected.connect(func(idx: int) -> void:
		_s.set(key, idx)
		_changed())
	return opt

func _header(text: String) -> void:
	var panel := GameUi.panel(GameUi.SECTION)
	panel.add_child(SocialUi.label(text, SocialUi.LABEL_GREEN, 14))
	_content.add_child(panel)

func _note(text: String) -> void:
	var l := SocialUi.label(text, SocialUi.MUTED, 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)

func _grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 6)
	_content.add_child(g)
	return g

func _row(children: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for c in children:
		h.add_child(c)
	return h

## Thẻ chung (GameUi.TAB): đang chọn = pressed, đặt qua GameUi.set_active trong _refresh_tabs.
func _tab_button(text: String) -> Button:
	var b := GameUi.button(text, GameUi.TAB)
	b.custom_minimum_size.y = 36
	return b

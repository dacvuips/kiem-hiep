extends SocialWindow
class_name GuildWindow
## BANG HỘI — bố cục như màn "Bang hội" của VLTK gốc: thanh 5 tab [Tin tức] [Chiêu Mộ] [Sử dụng chức năng] [Phân phối chức năng] [Nhật ký],
## thanh dưới [Tạo mới] [Xem tin Bang khác] [Đóng] và dòng "Bạn đã Online …". Chưa có bang thì hiện bảng các bang đang tuyển + điều kiện lập bang.
## Luật: GuildService + GuildRules (KPlayerTong gốc).

enum Tab { NEWS, RECRUIT, USE, PERMS, LOG }
const TAB_NAMES := ["Tin tức", "Chiêu Mộ", "Sử dụng chức năng", "Phân phối chức năng", "Nhật ký"]
const PAGE_SIZE := 12
const LOG_TABS := ["Công cáo bang hội", "Sự kiện bang hội", "Lịch sử bang hội"]

var _hub: SocialHub
var _guild: GuildService
var _profile: PlayerProfile
var _tab: int = Tab.NEWS
var _log_tab := 0
var _page := 0
var _online_only := false
var _search := ""
var _selected_member := ""
var _tab_bar: HBoxContainer
var _content: VBoxContainer
var _msg: PanelContainer
var _create_btn: Button
var _online_label: Label
var _opened_ms := 0

static func open(host: Node, hub: SocialHub) -> GuildWindow:
	return SocialWindow.present(host, GuildWindow.new(hub), &"guild") as GuildWindow

func _init(hub: SocialHub = null) -> void:
	super._init("Bang Hội", "", 860.0)
	_hub = hub
	if _hub == null:
		return
	_guild = _hub.guild
	_profile = _hub.profile
	_opened_ms = Time.get_ticks_msec()
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)
	body.add_child(_tab_bar)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(840, clampi(DisplayServer.window_get_size().y - 300, 320, 520))
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	body.add_child(scroll)
	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)
	## Thanh dưới: Tạo mới | Xem tin Bang khác | Đóng
	var buttons := add_button_row()
	_create_btn = SocialUi.stone_button("Tạo mới")
	var others := SocialUi.stone_button("Xem tin Bang khác")
	var close := SocialUi.stone_button("Đóng")
	for b in [_create_btn, others, close]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	_online_label = SocialUi.label("", SocialUi.LABEL_GREEN, 12, HORIZONTAL_ALIGNMENT_RIGHT)
	body.add_child(_online_label)
	_create_btn.pressed.connect(_open_create_dialog)
	others.pressed.connect(func() -> void: GuildListWindow.open(_host(), _hub))
	close.pressed.connect(func() -> void: close_requested.emit())
	_guild.changed.connect(_rebuild)
	_guild.message.connect(_on_message)
	_rebuild()

func _exit_tree() -> void:
	if _guild != null:
		if _guild.changed.is_connected(_rebuild):
			_guild.changed.disconnect(_rebuild)
		if _guild.message.is_connected(_on_message):
			_guild.message.disconnect(_on_message)

func _host() -> Node:
	return get_tree().current_scene if is_inside_tree() else null

func _process(_delta: float) -> void:
	if _online_label != null:
		var mins := (Time.get_ticks_msec() - _opened_ms) / 60000
		_online_label.text = "Bạn đã Online %d h %02d phút" % [mins / 60, mins % 60]

func _on_message(text: String, good: bool) -> void:
	SocialUi.set_banner(_msg, text, good)
	_msg.visible = true

func _clear_content() -> void:
	for c in _content.get_children():
		c.queue_free()

func _rebuild() -> void:
	if _content == null:
		return
	_clear_content()
	for c in _tab_bar.get_children():
		c.queue_free()
	_create_btn.disabled = _guild.in_guild()
	if not _guild.in_guild():
		set_subtitle("Chưa gia nhập bang hội nào")
		GuildListWindow.fill(_content, _hub, _host(), true)
		SaveManager.save_profile(_profile)
		return
	set_subtitle("%s · %s" % [_guild.guild_name(), GuildRules.figure_name(_guild.local_figure())])
	for i in TAB_NAMES.size():
		var b := SocialUi.small_button(TAB_NAMES[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = i == _tab
		b.pressed.connect(func() -> void:
			_tab = i
			_rebuild())
		_tab_bar.add_child(b)
	match _tab:
		Tab.NEWS:
			_build_news()
		Tab.RECRUIT:
			_build_recruit()
		Tab.USE:
			_build_use()
		Tab.PERMS:
			_build_perms()
		Tab.LOG:
			_build_log()
	SaveManager.save_profile(_profile)

# ------------------------------------------------------------------ dữ liệu thành viên
func _sorted_members() -> Array:
	var sorted := _guild.members().duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["figure"]) > int(b["figure"]) if int(a["figure"]) != int(b["figure"]) else int(a["level"]) > int(b["level"]))
	return sorted

## Đang trực tuyến (người chơi giả: cố định theo mã để danh sách ổn định).
func _is_online(m: Dictionary) -> bool:
	return bool(m.get("local", false)) or int(m.get("mock_id", 0)) % 3 != 0

func _filtered_members() -> Array:
	var out := []
	var rank := 0
	for m in _sorted_members():
		rank += 1
		if _online_only and not _is_online(m):
			continue
		var row: Dictionary = m.duplicate()
		row["rank"] = rank
		out.append(row)
	return out

## Bảng thành viên "Hạng | Thành viên | Chức vị" có phân trang. `select_cb(name)` gọi khi chọn dòng (có thể rỗng).
func _member_table(select_cb: Callable = Callable()) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tree := Tree.new()
	tree.columns = 3
	tree.hide_root = true
	tree.column_titles_visible = true
	tree.set_column_title(0, "Hạng")
	tree.set_column_title(1, "Thành viên")
	tree.set_column_title(2, "Chức vị")
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 50)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 110)
	tree.custom_minimum_size = Vector2(380, 300)
	tree.add_theme_stylebox_override("panel", SocialUi.box(Color(0.025, 0.03, 0.03), SocialUi.BORDER, 4, 1, 4))
	tree.add_theme_color_override("font_color", SocialUi.TEXT)
	tree.add_theme_color_override("title_button_color", SocialUi.GOLD)
	tree.add_theme_color_override("font_selected_color", SocialUi.GOLD)
	tree.add_theme_stylebox_override("selected", SocialUi.box(Color(0.16, 0.14, 0.05), SocialUi.TITLE, 3, 1, 2))
	tree.add_theme_stylebox_override("selected_focus", SocialUi.box(Color(0.16, 0.14, 0.05), SocialUi.TITLE, 3, 1, 2))
	var rows := _filtered_members()
	var pages := maxi(1, int(ceil(rows.size() / float(PAGE_SIZE))))
	_page = clampi(_page, 0, pages - 1)
	var root := tree.create_item()
	for m in rows.slice(_page * PAGE_SIZE, (_page + 1) * PAGE_SIZE):
		var it := tree.create_item(root)
		it.set_text(0, str(m["rank"]))
		it.set_text(1, str(m["name"]) + ("  (bạn)" if m.get("local", false) else ""))
		it.set_text(2, GuildRules.figure_name(int(m["figure"])))
		it.set_metadata(0, str(m["name"]))
		var col := SocialUi.LABEL_GREEN if _is_online(m) else SocialUi.MUTED
		for c in 3:
			it.set_custom_color(c, col)
		if str(m["name"]) == _selected_member:
			it.select(0)
	if select_cb.is_valid():
		tree.item_selected.connect(func() -> void:
			var sel := tree.get_selected()
			if sel != null:
				_selected_member = str(sel.get_metadata(0))
				select_cb.call(_selected_member))
	box.add_child(tree)
	## Hiển thị trên mạng + Truy tìm
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var online := CheckBox.new()
	online.text = "Hiển thị trên mạng"
	online.button_pressed = _online_only
	online.add_theme_color_override("font_color", SocialUi.TEXT)
	online.toggled.connect(func(v: bool) -> void:
		_online_only = v
		_page = 0
		_rebuild())
	top.add_child(online)
	var search := SocialUi.line_edit("tên thành viên")
	search.text = _search
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(search)
	var find := SocialUi.small_button("Truy tìm")
	find.pressed.connect(func() -> void: _on_find(search.text))
	search.text_submitted.connect(func(t: String) -> void: _on_find(t))
	top.add_child(find)
	box.add_child(top)
	## Phân trang: Trước | Kế | Chuyển đến N
	var pager := HBoxContainer.new()
	pager.add_theme_constant_override("separation", 6)
	var prev := SocialUi.small_button("Trước")
	prev.disabled = _page <= 0
	prev.pressed.connect(func() -> void:
		_page -= 1
		_rebuild())
	var nxt := SocialUi.small_button("Kế")
	nxt.disabled = _page >= pages - 1
	nxt.pressed.connect(func() -> void:
		_page += 1
		_rebuild())
	pager.add_child(prev)
	pager.add_child(nxt)
	pager.add_child(SocialUi.label("Chuyển đến", SocialUi.SUBTITLE, 12))
	var go := SpinBox.new()
	go.min_value = 1
	go.max_value = pages
	go.value = _page + 1
	go.value_changed.connect(func(v: float) -> void:
		_page = int(v) - 1
		_rebuild())
	pager.add_child(go)
	pager.add_child(SocialUi.label("/ %d" % pages, SocialUi.SUBTITLE, 12))
	box.add_child(pager)
	return box

## "Truy tìm": nhảy tới trang chứa thành viên có tên khớp.
func _on_find(text: String) -> void:
	_search = text.strip_edges()
	var needle := _search.to_lower()
	if needle == "":
		return
	var rows := _filtered_members()
	for i in rows.size():
		if str(rows[i]["name"]).to_lower().contains(needle):
			_page = i / PAGE_SIZE
			_selected_member = str(rows[i]["name"])
			_rebuild()
			return
	SocialUi.set_banner(_msg, "Không tìm thấy thành viên \"%s\"." % _search, false)
	_msg.visible = true

# ------------------------------------------------------------------ tab Tin tức
func _build_news() -> void:
	var g: Dictionary = _guild.data()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	_content.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(380, 0)
	cols.add_child(left)
	var news := SocialUi.info_box("Tin tức")
	var master_name := ""
	for m in _guild.members():
		if int(m["figure"]) == GuildRules.Figure.MASTER:
			master_name = str(m["name"])
	news[1].add_child(SocialUi.kv("Bang hội:", str(g["name"]), SocialUi.LABEL_RED, SocialUi.GOLD))
	news[1].add_child(SocialUi.kv("Bang chủ:", master_name, SocialUi.LABEL_RED, SocialUi.TEXT))
	news[1].add_child(SocialUi.kv("Phe:", Camp.get_camp_name(int(g["camp"])), SocialUi.LABEL_RED, Camp.get_color(int(g["camp"]))))
	news[1].add_child(SocialUi.kv("Nhân số:", "%d / %d" % [_guild.members().size(), _guild.member_cap()], SocialUi.LABEL_RED, SocialUi.TEXT))
	news[1].add_child(SocialUi.kv("Cấp bang:", "%d   (kinh nghiệm %d / %d)" % [int(g["level"]), int(g["exp"]), SocialRules.tong_exp_for_level(int(g["level"]) + 1)], SocialUi.LABEL_BLUE))
	news[1].add_child(SocialUi.kv("Quỹ bang:", "%s lượng" % InventoryPopup.format_money(int(g["fund"])), SocialUi.LABEL_BLUE, SocialUi.GOLD))
	news[1].add_child(SocialUi.kv("Khuynh hướng:", str(g.get("tendency", "—")), SocialUi.LABEL_BLUE))
	left.add_child(news[0])
	var left_trial := _guild.trial_seconds_left()
	if left_trial > 0:
		var min_m := int(SocialRules.tong()["test_period"]["min_member"])
		left.add_child(SocialUi.banner("Thử thách: còn %dh%02dp — cần đủ %d thành viên (hiện %d) kẻo bang giải tán." % [left_trial / 3600, (left_trial % 3600) / 60, min_m, _guild.members().size()], false))
	var help := SocialUi.section("Giúp đỡ", SocialUi.MUTED, SocialUi.INFO_BG)
	for line in ["Bang chủ/Trưởng lão chiêu mộ người ở tab Chiêu Mộ.", "Bang chủ phân quyền ở tab Phân phối chức năng.", "Quyên góp quỹ ở tab Sử dụng chức năng: quỹ ≥ 1.000.000 mỗi 750 giây đổi ra kinh nghiệm bang.", "Công cáo, sự kiện và lịch sử ở tab Nhật ký."]:
		var l := SocialUi.label("•  " + line, SocialUi.SUBTITLE, 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help[1].add_child(l)
	left.add_child(help[0])
	cols.add_child(_member_table())

# ------------------------------------------------------------------ tab Chiêu Mộ
func _build_recruit() -> void:
	var g: Dictionary = _guild.data()
	var can := _guild.is_officer()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	_content.add_child(cols)
	var left := SocialUi.section("Tin tức chiêu mộ bang hội", SocialUi.WARN, SocialUi.SECTION_BG)
	left[0].custom_minimum_size = Vector2(420, 0)
	var tend := _option_row("Khuynh hướng", GuildRules.TENDENCIES, str(g.get("tendency", GuildRules.TENDENCIES[0])), can)
	var act := _option_row("Hoạt động chủ", GuildRules.ACTIVITIES, str(g.get("activity", GuildRules.ACTIVITIES[0])), can)
	left[1].add_child(tend[0])
	left[1].add_child(act[0])
	left[1].add_child(SocialUi.label("Tin nhắn bang (lời chào gửi người xin vào)", SocialUi.LABEL_RED, 13))
	var msg_edit := TextEdit.new()
	msg_edit.text = str(g.get("recruit_msg", ""))
	msg_edit.custom_minimum_size = Vector2(0, 110)
	msg_edit.editable = can
	msg_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	left[1].add_child(msg_edit)
	var acc_row := HBoxContainer.new()
	acc_row.add_child(SocialUi.label("Cao hơn", SocialUi.TEXT, 13))
	var acc := SpinBox.new()
	acc.min_value = 0
	acc.max_value = 150
	acc.value = int(g.get("accept_level", 0))
	acc.editable = can
	acc_row.add_child(acc)
	acc_row.add_child(SocialUi.label("cấp tự động nhập bang (0 = luôn chờ duyệt)", SocialUi.TEXT, 13))
	left[1].add_child(acc_row)
	var rej_row := HBoxContainer.new()
	rej_row.add_child(SocialUi.label("Từ chối gamer dưới", SocialUi.TEXT, 13))
	var rej := SpinBox.new()
	rej.min_value = 0
	rej.max_value = 150
	rej.value = int(g.get("reject_level", 0))
	rej.editable = can
	rej_row.add_child(rej)
	rej_row.add_child(SocialUi.label("cấp xin nhập bang", SocialUi.TEXT, 13))
	left[1].add_child(rej_row)
	var recruit_on := CheckBox.new()
	recruit_on.text = "Đang tuyển người"
	recruit_on.button_pressed = bool(g.get("recruit", false))
	recruit_on.disabled = not can
	recruit_on.add_theme_color_override("font_color", SocialUi.TEXT)
	recruit_on.toggled.connect(func(v: bool) -> void: _guild.set_recruit(v))
	left[1].add_child(recruit_on)
	var publish := SocialUi.stone_button("Bảo lưu và công bố tin")
	publish.disabled = not can
	publish.pressed.connect(func() -> void:
		_guild.set_recruit_info(tend[1].get_item_text(tend[1].selected), act[1].get_item_text(act[1].selected), msg_edit.text, int(acc.value), int(rej.value)))
	left[1].add_child(publish)
	cols.add_child(left[0])

	var right := SocialUi.section("Danh sách thành viên xin gia nhập", SocialUi.LABEL_BLUE, SocialUi.INFO_BG)
	right[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list := SocialUi.item_list(Vector2(300, 260))
	for a in _guild.applies():
		var idx := list.add_item("%s  (Cấp %d · %s)" % [a["name"], int(a["level"]), a["sect"]])
		list.set_item_metadata(idx, str(a["name"]))
	right[1].add_child(list)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 6)
	var ok := SocialUi.stone_button("Đồng ý", Vector2(0, 34))
	var no := SocialUi.stone_button("Cự tuyệt", Vector2(0, 34))
	for b in [ok, no]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not can
		r1.add_child(b)
	right[1].add_child(r1)
	ok.pressed.connect(func() -> void:
		if not list.get_selected_items().is_empty():
			_guild.accept_applicant(str(list.get_item_metadata(list.get_selected_items()[0]))))
	no.pressed.connect(func() -> void:
		if not list.get_selected_items().is_empty():
			_guild.reject_applicant(str(list.get_item_metadata(list.get_selected_items()[0]))))
	cols.add_child(right[0])

## Hàng "Nhãn: [OptionButton]". Trả về [HBox, OptionButton].
func _option_row(label_text: String, options: Array, current: String, enabled: bool) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(SocialUi.label(label_text, SocialUi.LABEL_RED, 14))
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for o in options:
		ob.add_item(str(o))
	var idx := options.find(current)
	ob.select(maxi(0, idx))
	ob.disabled = not enabled
	row.add_child(ob)
	return [row, ob]

# ------------------------------------------------------------------ tab Sử dụng chức năng
func _build_use() -> void:
	var g: Dictionary = _guild.data()
	var fund := SocialUi.section("💰 Quyên góp quỹ bang", SocialUi.GOLD, SocialUi.INFO_BG)
	fund[1].add_child(SocialUi.kv("Quỹ hiện có:", "%s lượng" % InventoryPopup.format_money(int(g["fund"])), SocialUi.LABEL_BLUE, SocialUi.GOLD))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	var amt := SocialUi.line_edit("Số tiền quyên góp")
	amt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(amt)
	var don := SocialUi.small_button("Quyên góp")
	don.pressed.connect(func() -> void:
		var t := amt.text.strip_edges()
		_guild.donate(int(t) if t.is_valid_int() else 0))
	drow.add_child(don)
	fund[1].add_child(drow)
	_content.add_child(fund[0])

	if _guild.is_officer() and not _guild.is_full():
		var near := SocialUi.section("👥 Mời người vào bang", SocialUi.LABEL_BLUE, SocialUi.INFO_BG)
		var count := 0
		for m in SocialDirectory.players(_profile):
			if m.guild_name != "" or m.team_tag != "":
				continue
			var r2 := HBoxContainer.new()
			r2.add_theme_constant_override("separation", 8)
			var l2 := SocialUi.label(m.name, Camp.get_color(m.camp), 14)
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r2.add_child(l2)
			r2.add_child(SocialUi.label("Cấp %d · %s" % [m.level, m.sect_name], SocialUi.SUBTITLE, 12))
			var inv := SocialUi.small_button("Mời")
			inv.pressed.connect(func() -> void: _guild.invite(m))
			r2.add_child(inv)
			near[1].add_child(r2)
			count += 1
			if count >= 5:
				break
		_content.add_child(near[0])

	if _guild.has_perm(GuildRules.PERM_RENAME):
		var rn := SocialUi.section("✎ Đổi tên bang", SocialUi.LABEL_GREEN, SocialUi.SECTION_BG)
		var rrow := HBoxContainer.new()
		rrow.add_theme_constant_override("separation", 8)
		var name_edit := SocialUi.line_edit("Tên bang mới")
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rrow.add_child(name_edit)
		var go := SocialUi.small_button("Đổi tên")
		go.pressed.connect(func() -> void: _guild.rename(name_edit.text))
		rrow.add_child(go)
		rn[1].add_child(rrow)
		_content.add_child(rn[0])

	if _guild.is_master():
		var hand := SocialUi.section("👑 Nhường chức Bang chủ", SocialUi.WARN, SocialUi.INFO_BG)
		var any := false
		for m in _guild.members():
			if int(m["figure"]) == GuildRules.Figure.DIRECTOR:
				any = true
				var r3 := HBoxContainer.new()
				var l3 := SocialUi.label(str(m["name"]), SocialUi.LABEL_RED, 14)
				l3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r3.add_child(l3)
				var hb := SocialUi.small_button("Nhường chức")
				hb.pressed.connect(func() -> void:
					SocialWindow.confirm(_host(), "Nhường chức", "Nhường chức Bang chủ cho %s?" % m["name"], func() -> void: _guild.change_master(str(m["name"]))))
				r3.add_child(hb)
				hand[1].add_child(r3)
		if not any:
			hand[1].add_child(SocialUi.label("Chưa có Trưởng lão nào để nhường chức.", SocialUi.MUTED, 13))
		_content.add_child(hand[0])
		var dis := SocialUi.stone_button("Giải tán bang hội")
		dis.pressed.connect(func() -> void:
			SocialWindow.confirm(_host(), "Giải tán bang hội", "Giải tán bang hội \"%s\"? Việc này không hoàn lại được." % g["name"], func() -> void: _guild.disband()))
		_content.add_child(dis)
	else:
		var leave := SocialUi.stone_button("Rời bang")
		leave.pressed.connect(func() -> void:
			var fee: Dictionary = SocialRules.tong()["leave"]
			SocialWindow.confirm(_host(), "Rời bang hội", "Rời bang tốn %d lượng và %d danh vọng, và %d giờ sau mới xin vào bang khác được. Đồng ý?" % [int(fee["money"]), int(fee["repute"]), int(fee["seconds"]) / 3600], func() -> void: _guild.leave()))
		_content.add_child(leave)

# ------------------------------------------------------------------ tab Phân phối chức năng
func _build_perms() -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	_content.add_child(cols)
	var left := SocialUi.section("Quyền hạn", SocialUi.LABEL_RED, SocialUi.SECTION_BG)
	left[0].custom_minimum_size = Vector2(380, 0)
	var is_master := _guild.is_master()
	var selected_label := SocialUi.label("Chọn một thành viên ở danh sách bên phải.", SocialUi.SUBTITLE, 13)
	left[1].add_child(selected_label)
	var checks := {}
	var grid := GridContainer.new()
	grid.columns = 2
	for perm in GuildRules.PERMS:
		var cb := CheckBox.new()
		cb.text = GuildRules.PERM_NAMES[perm]
		cb.add_theme_color_override("font_color", SocialUi.TEXT)
		cb.disabled = true
		checks[perm] = cb
		grid.add_child(cb)
	left[1].add_child(grid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var all := SocialUi.small_button("Chọn tất cả")
	var apply := SocialUi.stone_button("Phân quyền", Vector2(0, 34))
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all.disabled = true
	apply.disabled = true
	row.add_child(all)
	row.add_child(apply)
	left[1].add_child(row)
	if not is_master:
		left[1].add_child(SocialUi.label("Chỉ Bang chủ mới phân quyền được.", SocialUi.WARN, 12))
	cols.add_child(left[0])
	## Khi chọn thành viên: nạp quyền hiện tại vào các ô (Bang chủ mới sửa được, và không sửa quyền Bang chủ).
	var on_select := func(member_name: String) -> void:
		var m := {}
		for x in _guild.members():
			if str(x["name"]) == member_name:
				m = x
		if m.is_empty():
			return
		selected_label.text = "%s — %s" % [member_name, GuildRules.figure_name(int(m["figure"]))]
		var editable := is_master and int(m["figure"]) != GuildRules.Figure.MASTER
		var perms := _guild.perms_of(m)
		for perm in checks:
			checks[perm].button_pressed = perm in perms
			checks[perm].disabled = not editable
		all.disabled = not editable
		apply.disabled = not editable
	all.pressed.connect(func() -> void:
		for perm in checks:
			checks[perm].button_pressed = true)
	apply.pressed.connect(func() -> void:
		var chosen := []
		for perm in checks:
			if checks[perm].button_pressed:
				chosen.append(perm)
		_guild.set_perms(_selected_member, chosen))
	cols.add_child(_member_table(on_select))
	if _selected_member != "":
		on_select.call_deferred(_selected_member)

# ------------------------------------------------------------------ tab Nhật ký
func _build_log() -> void:
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 4)
	for i in LOG_TABS.size():
		var b := SocialUi.small_button(LOG_TABS[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = i == _log_tab
		b.pressed.connect(func() -> void:
			_log_tab = i
			_rebuild())
		sub.add_child(b)
	_content.add_child(sub)
	var area := TextEdit.new()
	area.custom_minimum_size = Vector2(0, 320)
	area.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	area.add_theme_color_override("font_color", SocialUi.LABEL_GREEN)
	area.add_theme_color_override("font_readonly_color", SocialUi.LABEL_GREEN)
	var can_log := _guild.has_perm(GuildRules.PERM_LOG)
	if _log_tab == 0:
		area.text = str(_guild.data().get("notice", ""))
		area.editable = can_log
	else:
		var kind := "event" if _log_tab == 1 else "history"
		var lines := []
		for entry in _guild.data().get("log", []):
			if str(entry.get("kind", "history")) == kind:
				lines.append("[%s] %s" % [Time.get_datetime_string_from_unix_time(int(entry["at"])).replace("T", " "), str(entry["text"])])
		area.text = "\n".join(lines) if not lines.is_empty() else "Chưa có ghi chép."
		area.editable = false
	_content.add_child(area)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var event_btn := SocialUi.stone_button("Sự việc", Vector2(140, 36))
	event_btn.disabled = not can_log
	event_btn.pressed.connect(func() -> void:
		SocialWindow.prompt(_host(), "Sự việc", "Nội dung sự việc (tối đa 80 ký tự)", func(t: String) -> void: _guild.add_event(t)))
	var msg_btn := SocialUi.stone_button("Lời nhắn", Vector2(140, 36))
	msg_btn.disabled = not can_log or _log_tab != 0
	msg_btn.tooltip_text = "Lưu công cáo bang hội"
	msg_btn.pressed.connect(func() -> void: _guild.set_notice(area.text))
	buttons.add_child(event_btn)
	buttons.add_child(msg_btn)
	_content.add_child(buttons)

# ------------------------------------------------------------------ hộp "Lập bang hội"
func _open_create_dialog() -> void:
	var win := SocialWindow.new("Lập Bang Hội", "", 400.0)
	var name_row := SocialUi.kv("Bang hội", "", SocialUi.LABEL_RED)
	name_row.remove_child(name_row.get_child(1))
	var name_edit := SocialUi.line_edit("Tên bang (tối đa %d ký tự)" % int(SocialRules.tong()["name_max_length"]))
	name_edit.max_length = int(SocialRules.tong()["name_max_length"])
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	win.body.add_child(name_row)
	var camp_row := HBoxContainer.new()
	camp_row.add_theme_constant_override("separation", 8)
	camp_row.add_child(SocialUi.label("Phe phái bang", SocialUi.LABEL_RED, 14))
	var camp_pick := OptionButton.new()
	camp_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cp in GuildRules.CAMPS:
		camp_pick.add_item(Camp.get_camp_name(cp), cp)
	camp_row.add_child(camp_pick)
	win.body.add_child(camp_row)
	var blockers := _guild.create_blockers(_hub.team)
	var info := SocialUi.info_box("✦ Điều kiện lập bang")
	var c: Dictionary = SocialRules.tong()["create"]
	info[1].add_child(SocialUi.label("Cấp ≥ %d · Lãnh đạo ≥ %d · %s lượng · Danh vọng ≥ %d · Phúc duyên ≥ %d" % [int(c["level"]), int(c["lead_level"]), InventoryPopup.format_money(int(c["money"])), int(c["repute"]), int(c["fuyuan"])], SocialUi.TEXT, 12))
	for b in blockers:
		info[1].add_child(SocialUi.label("✘ " + b, SocialUi.LABEL_RED, 12))
	if blockers.is_empty():
		info[1].add_child(SocialUi.label("✔ Bạn đủ điều kiện lập bang.", SocialUi.LABEL_GREEN, 13))
	win.body.add_child(info[0])
	var row := win.add_button_row()
	var ok := SocialUi.stone_button("xác nhận")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.disabled = not blockers.is_empty()
	var cancel := SocialUi.stone_button("hủy bỏ")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	row.add_child(cancel)
	SocialWindow.present(_host(), win, &"guild_create")
	ok.pressed.connect(func() -> void:
		var err := _guild.create(name_edit.text, camp_pick.get_selected_id(), _hub.team)
		if err == "":
			win.close_requested.emit())
	cancel.pressed.connect(func() -> void: win.close_requested.emit())
	## Cho kiểm thử/gọi mã: điền sẵn qua thuộc tính của cửa sổ.
	win.set_meta("name_edit", name_edit)
	win.set_meta("camp_pick", camp_pick)
	win.set_meta("ok", ok)

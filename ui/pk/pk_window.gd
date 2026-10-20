extends SocialWindow
class_name PkWindow
## Popup PK (nút "PK" ở Character Hub) — 2 tab theo VLTK gốc: Đại hội võ lâm (đấu cùng phái) / Võ lâm Liên đấu (mọi phái), xem
## PkRules. Mỗi tab:
##   - Danh sách PHÒNG CHỜ ĐÁNH (vào đấu; phòng có khoá thì hỏi mật khẩu) và PHÒNG ĐANG ĐÁNH (vào xem) + ô tìm phòng theo ID.
##   - [Tạo phòng]: hỏi có đặt mật khẩu không -> mở phòng chờ có ID 6 số (PkLobby).
##   - [Tự tìm đối thủ]: tìm phòng chờ hợp (chênh <= 10 cấp, Đại hội: cùng phái); quá 1 phút không có -> đấu với bot cùng cấp
##     (tên, phái ngẫu nhiên — Đại hội: cùng phái), PkBotProfile.
## Vào trận: on_play(PkRules.arena_entry(...)) — Character Hub đổi cảnh như Vượt Ải.
## ONLINE (đã đăng nhập + arena server đang mở, GET /v1/arena mỗi POLL_SEC giây): danh sách là phòng thật của mọi người; tạo / vào /
## xem / tự tìm đều vào thẳng arena server (ArenaServer kiểm tra mật khẩu, cấp, phái; ArenaClient lo phần còn lại). Chưa đăng nhập /
## arena server chưa mở: chạy cục bộ như trên (PkLobby + bot).

const LIST_SIZE := Vector2(300, 220)
const FOUND_DELAY := 2.0           ## tìm được đối thủ: hiện tên đối thủ chừng này giây rồi mới vào trận
const POLL_SEC := 2.0

enum View { LOBBY, ROOM, SEARCH }

var _profile: PlayerProfile
var _on_play: Callable
var _mode: PkRules.Mode = PkRules.Mode.LIEN_DAU
var _view: View = View.LOBBY
var _tab_buttons: Array[Button] = []
var _content: VBoxContainer
var _search_box: LineEdit
var _waiting_list: VBoxContainer
var _fighting_list: VBoxContainer
var _status: Label
var _room: Dictionary = {}
var _search_time := 0.0
var _found_in := -1.0
var _found_entry: Dictionary = {}
var _timer_label: Label
var _arena: Dictionary = {}        ## GET /v1/arena: {open, host, port, ws_url, rooms}
var _poll := 0.0
var _fetching := false

static func open(host: Node, profile: PlayerProfile, on_play: Callable) -> PkWindow:
	var win := PkWindow.new(profile, on_play)
	return SocialWindow.present(host, win, &"pk") as PkWindow

func _init(profile: PlayerProfile = null, on_play: Callable = Callable()) -> void:
	super._init("PK", "Võ Lâm Minh Chủ triệu tập anh hùng thiên hạ so tài", 660.0)
	_profile = profile
	_on_play = on_play
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	for m in [PkRules.Mode.DAI_HOI, PkRules.Mode.LIEN_DAU, PkRules.Mode.THACH_DAU]:
		var b := GameUi.button(PkRules.MODE_NAMES[m])
		b.custom_minimum_size = Vector2(150, 36)
		b.pressed.connect(_select_mode.bind(m))
		tabs.add_child(b)
		_tab_buttons.append(b)
	body.add_child(tabs)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	body.add_child(_content)
	_select_mode(PkRules.Mode.DAI_HOI if profile != null and profile.has_sect() else PkRules.Mode.LIEN_DAU)
	_fetch_arena()
	## Đóng popup khi đang chờ trong phòng: huỷ luôn phòng (không để phòng "ma" trong danh sách).
	close_requested.connect(func() -> void:
		if _view == View.ROOM:
			PkLobby.close_own(_profile))

## Đấu trường online đang mở (đã đăng nhập + arena server báo về).
func _online() -> bool:
	return AccountApi.is_logged_in() and bool(_arena.get("open", false))

func _fetch_arena() -> void:
	if _fetching or not AccountApi.is_logged_in():
		return
	_fetching = true
	var r: Dictionary = await AccountApi.arena(ServerSelectScreen.selected_server_id)
	_fetching = false
	if not is_inside_tree():
		return
	_arena = r.data if r.ok and r.data is Dictionary else {}
	if _view == View.LOBBY:
		_refresh_lists()

## Vào arena server làm việc `action` ({op: create | join | watch | match, room, password}).
func _enter_online(action: Dictionary) -> void:
	var server := {"host": str(_arena.get("host", "")), "port": int(_arena.get("port", 7797)), "ws_url": str(_arena.get("ws_url", "")),
		"name": "Đấu trường PK"}
	_enter(PkRules.arena_entry({"mode": _mode, "online": true, "server": server, "action": action}))

## Phòng của arena server ở tab đang xem: chờ đánh (waiting) / đang đánh (prepare, fight).
func _online_rooms(waiting: bool) -> Array:
	var out := []
	for r in _arena.get("rooms", []):
		if int(r.get("mode", -1)) != _mode:
			continue
		var st := str(r.get("state", ""))
		if (waiting and st == "waiting") or (not waiting and st in ["prepare", "fight"]):
			out.append(r)
	return out

static func _locked(r: Dictionary) -> bool:
	return bool(r.get("locked", false)) or str(r.get("password", "")) != ""

func _select_mode(m: PkRules.Mode) -> void:
	if _view != View.LOBBY:
		return                      ## đang chờ phòng / đang tìm: không đổi tab
	_mode = m
	for i in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[i], i == int(m))
	_show_lobby()

func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()
	_timer_label = null

# ---------------------------------------------------------------- sảnh: danh sách phòng

func _show_lobby() -> void:
	_view = View.LOBBY
	_clear()
	var intro := SocialUi.label(PkRules.MODE_INTRO[_mode], SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(intro)
	var rec := PkMatch.record_of(_profile, _mode)
	if PkRules.has_rank_points(_mode):
		var pts: int = _profile.pk_points if _profile else int(rec.get("points", 0))
		_content.add_child(SocialUi.label("Điều kiện: cấp từ %d%s   ·   Điểm BXH: %d   ·   Thắng %d · Thua %d (+10 thắng, -2 thua)" % [
				int(PkRules.MIN_LEVEL[_mode]),
				" · cùng môn phái" if _mode == PkRules.Mode.DAI_HOI else "",
				pts, int(rec.get("win", 0)), int(rec.get("lose", 0))],
				SocialUi.LABEL_BLUE, 14, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		_content.add_child(SocialUi.label("Tự do tỷ thí võ nghệ   ·   Thành tích: thắng %d · thua %d (Không tính điểm xếp hạng)" % [
				int(rec.get("win", 0)), int(rec.get("lose", 0))],
				SocialUi.LABEL_GREEN, 14, HORIZONTAL_ALIGNMENT_CENTER))

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	_content.add_child(search_row)
	search_row.add_child(SocialUi.label("Tìm phòng theo ID:", SocialUi.TEXT, 14))
	_search_box = SocialUi.line_edit("Nhập ID phòng (6 số)")
	_search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_box.text_changed.connect(func(_t: String) -> void: _refresh_lists())
	search_row.add_child(_search_box)

	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 12)
	_content.add_child(lists)
	_waiting_list = _make_list(lists, "Phòng chờ đánh")
	_fighting_list = _make_list(lists, "Đang đánh")
	_refresh_lists()

	var reason := PkRules.check_entry(_profile, _mode)
	_status = SocialUi.label(reason, SocialUi.WARN, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = reason != ""
	_content.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)
	var create := SocialUi.stone_button("Tạo phòng", Vector2(180, 44))
	create.disabled = reason != ""
	create.pressed.connect(_ask_create_room)
	row.add_child(create)
	var find := SocialUi.stone_button("Tự tìm đối thủ", Vector2(180, 44))
	find.disabled = reason != ""
	find.pressed.connect(_start_search)
	row.add_child(find)

func _make_list(parent: Control, header: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(SocialUi.label(header, SocialUi.TITLE, 15, HORIZONTAL_ALIGNMENT_CENTER))
	var frame := GameUi.panel(GameUi.PANEL)
	col.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list

func _refresh_lists() -> void:
	if _waiting_list == null or not is_instance_valid(_waiting_list):
		return
	var query := _search_box.text.strip_edges() if _search_box else ""
	for pair in [[_waiting_list, PkLobby.WAITING], [_fighting_list, PkLobby.FIGHTING]]:
		var list: VBoxContainer = pair[0]
		for c in list.get_children():
			c.queue_free()
		var source: Array = _online_rooms(pair[1] == PkLobby.WAITING) if _online() else PkLobby.rooms(_mode, pair[1])
		var rooms := source.filter(func(r: Dictionary) -> bool: return query == "" or str(r["id"]).begins_with(query))
		for r in rooms:
			list.add_child(_room_row(r, pair[1] == PkLobby.WAITING))
		if rooms.is_empty():
			var empty := SocialUi.label("Không có phòng nào." if query == "" else "Không có phòng ID %s." % query, SocialUi.MUTED, 13,
					HORIZONTAL_ALIGNMENT_CENTER)
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list.add_child(empty)

func _room_row(r: Dictionary, waiting: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lock := "🔒 " if _locked(r) else ""
	var format := ""
	if int(r.get("mode", 0)) == PkRules.Mode.THACH_DAU:
		var s := int(r.get("team_size", 1))
		format = "[%s] " % PkRules.format_name(s)
	var text := "%s%s#%s  %s\nCấp %d · %s" % [lock, format, r["id"], r["host"], int(r["level"]), r["sect_name"]]
	if not waiting and r.has("fighters"):   ## phòng của arena server
		var f: Array = r["fighters"]
		text = "%s%s#%s · %d người xem\n%s vs %s" % [lock, format, r["id"], int(r.get("spectators", 0)), f[0] if f.size() > 0 else "?",
				f[1] if f.size() > 1 else "?"]
	elif not waiting:
		text = "%s#%s\n%s vs %s" % [format, r["id"], r.get("host", "?"), r.get("guest", "?")]
	var l := SocialUi.label(text, SocialUi.TEXT, 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if waiting:
				_join_room(r)
			else:
				_watch_room(r))
	row.add_child(l)
	var b := SocialUi.small_button("Vào" if waiting else "Xem")
	b.pressed.connect(_join_room.bind(r) if waiting else _watch_room.bind(r))
	row.add_child(b)
	return row

func _join_room(r: Dictionary) -> void:
	if _online():
		var why := PkRules.check_entry(_profile, _mode)
		if why != "":
			_flash(why)
			return
		_with_password(r, func(pw: String) -> void: _enter_online({"op": "join", "room": str(r["id"]), "password": pw}))
		return
	if str(r["host"]) == _profile.display_name:
		_show_room(r)
		return
	var reason := PkRules.check_entry(_profile, _mode)
	if reason == "" and not PkRules.can_match(_mode, _profile.level, _profile.sect_id, int(r["level"]), str(r["sect_id"])):
		reason = "Chênh lệch quá %d cấp%s." % [PkRules.MATCH_LEVEL_DIFF, " hoặc khác môn phái" if _mode == PkRules.Mode.DAI_HOI else ""]
	if reason != "":
		_flash(reason)
		return
	if str(r["password"]) == "":
		_flash("Vào đấu với người chơi khác cần chơi online (đang phát triển).")
		return
	SocialWindow.prompt(self, "Phòng #%s" % r["id"], "Mật khẩu phòng", func(pw: String) -> void:
		_flash("Sai mật khẩu." if pw != str(r["password"]) else "Vào đấu với người chơi khác cần chơi online (đang phát triển)."),
		"", true)

func _watch_room(r: Dictionary) -> void:
	if not _online():
		_flash("Vào xem trận cần chơi online.")
		return
	_with_password(r, func(pw: String) -> void: _enter_online({"op": "watch", "room": str(r["id"]), "password": pw}))

## Phòng có khoá: hỏi mật khẩu (server kiểm tra) rồi gọi then_do(mật khẩu); không khoá: gọi luôn với "".
func _with_password(r: Dictionary, then_do: Callable) -> void:
	if not _locked(r):
		then_do.call("")
		return
	SocialWindow.prompt(self, "Phòng #%s" % r["id"], "Mật khẩu phòng", func(pw: String) -> void: then_do.call(pw.strip_edges()), "", true)

func _flash(text: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = text
		_status.visible = true

# ---------------------------------------------------------------- tạo phòng

func _ask_create_room() -> void:
	if _mode == PkRules.Mode.THACH_DAU:
		_show_thach_dau_create_dialog()
		return
	SocialWindow.ask_yes_no(self, "Tạo phòng", "Đặt mật khẩu cho phòng?\n(Phòng có mật khẩu chỉ người biết mật khẩu mới vào được.)",
		func(yes: bool) -> void:
			if yes:
				SocialWindow.prompt(self, "Mật khẩu phòng", "Nhập mật khẩu (1-16 ký tự)", func(pw: String) -> void:
					pw = pw.strip_edges().left(16)
					if pw == "":
						_flash("Chưa nhập mật khẩu — chưa tạo phòng.")
						return
					_create_room(pw, 1), "", true)
			else:
				_create_room("", 1),
		"Có", "Không")

func _show_thach_dau_create_dialog() -> void:
	var dlg := SocialWindow.new("Tạo Phòng Thách Đấu", "Chọn thể thức so tài võ nghệ", 480.0)
	var selected_team_size := [1]
	
	dlg.body.add_child(SocialUi.label("Chọn thể thức thi đấu:", SocialUi.TITLE, 14))
	
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	dlg.body.add_child(grid)
	
	var format_buttons: Array[Button] = []
	for s in PkRules.TEAM_FORMATS:
		var btn := GameUi.button(PkRules.format_name(s))
		btn.custom_minimum_size = Vector2(100, 36)
		btn.pressed.connect(func() -> void:
			selected_team_size[0] = s
			for b in format_buttons:
				GameUi.set_active(b, b == btn)
		)
		grid.add_child(btn)
		format_buttons.append(btn)
	GameUi.set_active(format_buttons[0], true)
	
	dlg.body.add_child(SocialUi.label("Mật khẩu phòng (để trống nếu không khóa):", SocialUi.TEXT, 13))
	var pw_input := SocialUi.line_edit("Nhập mật khẩu (1-16 ký tự)")
	pw_input.secret = true
	dlg.body.add_child(pw_input)
	
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	dlg.body.add_child(btn_row)
	
	var btn_confirm := SocialUi.stone_button("Tạo phòng", Vector2(160, 40))
	btn_confirm.pressed.connect(func() -> void:
		var pw := pw_input.text.strip_edges().left(16)
		dlg.queue_free()
		_create_room(pw, selected_team_size[0])
	)
	btn_row.add_child(btn_confirm)
	
	var btn_cancel := SocialUi.stone_button("Hủy", Vector2(160, 40))
	btn_cancel.pressed.connect(func() -> void:
		dlg.queue_free()
	)
	btn_row.add_child(btn_cancel)
	
	SocialWindow.present(self, dlg, &"thach_dau_create")

## Online: vào arena server mở phòng; offline / Thách đấu: phòng chờ cục bộ (PkLobby).
func _create_room(password: String, team_size: int = 1) -> void:
	if _mode == PkRules.Mode.THACH_DAU:
		_show_room(PkLobby.create(_profile, _mode, password, team_size))
		return
	if _online():
		_enter_online({"op": "create", "password": password, "team_size": team_size})
	else:
		_show_room(PkLobby.create(_profile, _mode, password, team_size))

func _show_room(room: Dictionary) -> void:
	_view = View.ROOM
	_room = room
	_search_time = 0.0
	_clear()
	var team_size: int = PkRules.team_size_for(room)
	var format_tag := (" [%s]" % PkRules.format_name(team_size)) if _mode == PkRules.Mode.THACH_DAU else ""
	_content.add_child(SocialUi.label("Phòng #%s%s" % [room["id"], format_tag], SocialUi.TITLE, 22, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(SocialUi.label("%s · Chủ phòng: %s (cấp %d, %s)" % [PkRules.MODE_NAMES[_mode], room["host"], int(room["level"]),
			room["sect_name"]], SocialUi.TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(SocialUi.label("Mật khẩu: %s" % ("có" if str(room["password"]) != "" else "không"), SocialUi.LABEL_BLUE, 14,
			HORIZONTAL_ALIGNMENT_CENTER))

	var is_host := (str(room.get("host", "")) == (_profile.display_name if _profile else ""))

	# 2 Cột danh sách 2 phe
	var teams_row := HBoxContainer.new()
	teams_row.add_theme_constant_override("separation", 16)
	_content.add_child(teams_row)

	var team_a: Array = room.get("team_a", [])
	var team_b: Array = room.get("team_b", [])

	_make_team_panel(teams_row, "Phe Chủ phòng (Xanh)", team_a, team_size, "a", is_host)
	_make_team_panel(teams_row, "Phe Thách đấu (Đỏ)", team_b, team_size, "b", is_host)

	var hint := SocialUi.label("Chia sẻ ID phòng cho đồng đội / đối thủ để vào phòng." if _mode == PkRules.Mode.THACH_DAU else "Đang chờ đối thủ…",
			SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)

	_timer_label = SocialUi.label("", SocialUi.GOLD, 16, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_timer_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)

	if is_host:
		var btn_start := SocialUi.stone_button("Bắt đầu trận", Vector2(160, 42))
		btn_start.pressed.connect(_start_room_match)
		row.add_child(btn_start)

		if not _online() or _mode == PkRules.Mode.THACH_DAU:
			var btn_bot := SocialUi.stone_button("Thêm Bot", Vector2(140, 42))
			btn_bot.pressed.connect(_add_bot_to_room)
			row.add_child(btn_bot)

		var cancel := SocialUi.stone_button("Huỷ phòng", Vector2(140, 42))
		cancel.pressed.connect(func() -> void:
			PkLobby.close(str(_room["id"]))
			_room = {}
			_show_lobby())
		row.add_child(cancel)
	else:
		var btn_ready := SocialUi.stone_button("Sẵn sàng", Vector2(160, 42))
		btn_ready.pressed.connect(_toggle_ready_in_room)
		row.add_child(btn_ready)

		var leave := SocialUi.stone_button("Rời phòng", Vector2(160, 42))
		leave.pressed.connect(func() -> void:
			if _profile:
				PkLobby.leave_room(str(_room["id"]), _profile.display_name)
			_room = {}
			_show_lobby())
		row.add_child(leave)

func _make_team_panel(parent: Control, header: String, members: Array, team_size: int, team_code: String, is_host: bool) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)

	var head_label := SocialUi.label("%s (%d/%d)" % [header, members.size(), team_size],
			SocialUi.LABEL_BLUE if team_code == "a" else SocialUi.GOLD, 14, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(head_label)

	var frame := GameUi.panel(GameUi.PANEL)
	col.add_child(frame)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for i in team_size:
		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 6)
		list.add_child(slot_row)

		if i < members.size():
			var m: Dictionary = members[i]
			var star := "★ " if bool(m.get("is_host", false)) else ""
			var ready_text := " [Sẵn sàng]" if bool(m.get("ready", false)) else " [Chờ]"
			var text := "%s%s (Cấp %d · %s)%s" % [star, m.get("name", "?"), int(m.get("level", 1)), m.get("sect_name", ""), ready_text]
			var l := SocialUi.label(text, SocialUi.TEXT, 12)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			slot_row.add_child(l)

			# Nút đá người (chủ phòng thấy trên các thành viên khác)
			if is_host and str(m.get("name", "")) != (_profile.display_name if _profile else ""):
				var kick_b := SocialUi.small_button("Đá")
				kick_b.pressed.connect(func() -> void:
					_kick_member_from_room(str(m.get("name", "")), int(m.get("cid", 0)))
				)
				slot_row.add_child(kick_b)
		else:
			var empty_l := SocialUi.label("(Slot %d trống)" % (i + 1), SocialUi.MUTED, 12)
			empty_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_row.add_child(empty_l)

			var join_b := SocialUi.small_button("Vào slot")
			join_b.pressed.connect(func() -> void:
				_switch_team_slot(team_code)
			)
			slot_row.add_child(join_b)

func _switch_team_slot(target_team: String) -> void:
	if _online():
		NetClient.send_arena(ArenaServer.OP_SWITCH_TEAM, {"team": target_team})
		return
	if _profile and not _room.is_empty():
		PkLobby.join_team(str(_room["id"]), _profile, target_team)
		_show_room(PkLobby.find(str(_room["id"])))

func _kick_member_from_room(target_name: String, target_cid: int = 0) -> void:
	if _online():
		NetClient.send_arena(ArenaServer.OP_KICK_MEMBER, {"target_cid": target_cid})
		return
	if not _room.is_empty():
		PkLobby.kick_member(str(_room["id"]), target_name)
		_show_room(PkLobby.find(str(_room["id"])))

func _toggle_ready_in_room() -> void:
	if _online():
		NetClient.send_arena(ArenaServer.OP_READY, {"ready": true})
		return
	if _profile and not _room.is_empty():
		PkLobby.toggle_ready(str(_room["id"]), _profile.display_name)
		_show_room(PkLobby.find(str(_room["id"])))

func _add_bot_to_room() -> void:
	if not _room.is_empty():
		var team_b: Array = _room.get("team_b", [])
		var team_a: Array = _room.get("team_a", [])
		var team_size: int = int(_room.get("team_size", 1))
		var target_team := "b" if team_b.size() < team_size else ("a" if team_a.size() < team_size else "")
		if target_team != "":
			PkLobby.add_bot(str(_room["id"]), target_team, _profile.level if _profile else 90)
			_show_room(PkLobby.find(str(_room["id"])))

func _start_room_match() -> void:
	if _online() and _mode != PkRules.Mode.THACH_DAU:
		_enter_online({"op": "start", "room": str(_room["id"])})
		return
	var team_size: int = PkRules.team_size_for(_room)
	var team_a: Array = _room.get("team_a", []).duplicate(true)
	var team_b: Array = _room.get("team_b", []).duplicate(true)
	# Tự động điền bot vào các slot còn trống nếu chưa đủ
	while team_a.size() < team_size:
		var bot := PkBotProfile.create(_profile.level if _profile else 90)
		var sect := SectRegistry.get_by_id(bot.sect_id)
		team_a.append({"name": bot.display_name, "level": bot.level, "sect_id": bot.sect_id, "sect_name": sect.sect_name if sect else "",
			"ready": true, "is_bot": true, "bot_data": bot.to_dict()})
	while team_b.size() < team_size:
		var bot := PkBotProfile.create(_profile.level if _profile else 90)
		var sect := SectRegistry.get_by_id(bot.sect_id)
		team_b.append({"name": bot.display_name, "level": bot.level, "sect_id": bot.sect_id, "sect_name": sect.sect_name if sect else "",
			"ready": true, "is_bot": true, "bot_data": bot.to_dict()})
	var opponent_profile: Dictionary = team_b[0].get("bot_data", {}) if not team_b.is_empty() and team_b[0].has("bot_data") else {}
	var entry := PkRules.arena_entry({
		"mode": _mode,
		"team_size": team_size,
		"team_a": team_a,
		"team_b": team_b,
		"opponent": opponent_profile
	})
	_enter(entry)

# ---------------------------------------------------------------- tự tìm đối thủ

func _start_search() -> void:
	var reason := PkRules.check_entry(_profile, _mode)
	if reason != "":
		_flash(reason)
		return
	if _online():   ## arena server ghép người thật; quá 1 phút không có thì ArenaClient chuyển sang đấu bot
		_enter_online({"op": "match"})
		return
	_view = View.SEARCH
	_search_time = 0.0
	_found_in = -1.0
	_clear()
	_content.add_child(SocialUi.label("Đang tìm đối thủ…", SocialUi.TITLE, 22, HORIZONTAL_ALIGNMENT_CENTER))
	var rule := "Chênh lệch không quá %d cấp%s. Sau %d giây chưa có ai sẽ ghép với đối thủ cùng cấp." % [PkRules.MATCH_LEVEL_DIFF,
			", cùng môn phái" if _mode == PkRules.Mode.DAI_HOI else "", int(PkRules.MATCH_WAIT_SEC)]
	var l := SocialUi.label(rule, SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)
	_timer_label = SocialUi.label("", SocialUi.GOLD, 20, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_timer_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	var cancel := SocialUi.stone_button("Huỷ tìm", Vector2(180, 44))
	cancel.pressed.connect(func() -> void:
		_found_in = -1.0
		_show_lobby())
	row.add_child(cancel)

func _process(delta: float) -> void:
	if _view == View.LOBBY and AccountApi.is_logged_in():
		_poll -= delta
		if _poll <= 0.0:
			_poll = POLL_SEC
			_fetch_arena()
	match _view:
		View.ROOM:
			_search_time += delta
			if _timer_label:
				_timer_label.text = "Đã chờ %s" % TimeChallenge.format_time(int(_search_time))
		View.SEARCH:
			if _found_in >= 0.0:
				_found_in -= delta
				if _found_in < 0.0:
					_enter(_found_entry)
				return
			_search_time += delta
			if _timer_label:
				_timer_label.text = "%s / %s" % [TimeChallenge.format_time(int(_search_time)), TimeChallenge.format_time(int(PkRules.MATCH_WAIT_SEC))]
			var room := PkLobby.find_match(_profile, _mode)
			if not room.is_empty():
				_flash("Tìm thấy phòng #%s — vào đấu với người chơi khác cần chơi online (đang phát triển)." % room["id"])
			if _search_time >= PkRules.MATCH_WAIT_SEC:
				_match_bot()

## Hết thời gian chờ: bot cùng cấp — Đại hội võ lâm cùng phái, Liên đấu phái ngẫu nhiên.
func _match_bot() -> void:
	var sect_id := _profile.sect_id if _mode == PkRules.Mode.DAI_HOI else ""
	var bot := PkBotProfile.create(_profile.level, sect_id)
	var sect := SectRegistry.get_by_id(bot.sect_id)
	_found_entry = PkRules.arena_entry({"mode": _mode, "opponent": bot.to_dict()})
	_found_in = FOUND_DELAY
	_clear()
	_content.add_child(SocialUi.label("Đã tìm thấy đối thủ!", SocialUi.TITLE, 22, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(SocialUi.label("%s · Cấp %d · %s" % [bot.display_name, bot.level, sect.sect_name if sect else "?"],
			SocialUi.GOLD, 18, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(SocialUi.label("Đang vào %s…" % PkRules.ARENA_MAP_NAME, SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER))

func _enter(entry: Dictionary) -> void:
	_view = View.LOBBY
	PkLobby.close_own(_profile)
	close_requested.emit()
	if _on_play.is_valid():
		_on_play.call(entry)

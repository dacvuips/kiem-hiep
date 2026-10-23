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

const LIST_SIZE := Vector2(680, 260)
const FOUND_DELAY := 2.0           ## tìm được đối thủ: hiện tên đối thủ chừng này giây rồi mới vào trận
const POLL_SEC := 2.0
const MODE_ALL := -1

enum View { LOBBY, ROOM, SEARCH }

var _profile: PlayerProfile
var _on_play: Callable
var _mode: int = MODE_ALL
var _view: View = View.LOBBY
var _tab_buttons: Array[Button] = []
var _content: VBoxContainer
var _search_box: LineEdit
var _state_filter_btn: OptionButton
var _state_filter: String = ""
var _room_list: VBoxContainer
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
	super._init("PK", "Võ Lâm Minh Chủ triệu tập anh hùng thiên hạ so tài", 720.0)
	_profile = profile
	_on_play = on_play
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	var modes := [MODE_ALL, PkRules.Mode.DAI_HOI, PkRules.Mode.LIEN_DAU, PkRules.Mode.THACH_DAU, PkRules.Mode.LON_XON, PkRules.Mode.TONG_KIM_LOL]
	for m in modes:
		var title: String = "Tất cả" if m == MODE_ALL else PkRules.MODE_NAMES[m]
		var b := GameUi.button(title)
		b.custom_minimum_size = Vector2(86 if m == MODE_ALL else 112, 34)
		b.pressed.connect(_select_mode.bind(m))
		tabs.add_child(b)
		_tab_buttons.append(b)
	body.add_child(tabs)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	body.add_child(_content)
	_select_mode(MODE_ALL)
	_fetch_arena()
	## Đóng popup khi đang chờ trong phòng: huỷ luôn phòng (không để phòng "ma" trong danh sách).
	close_requested.connect(func() -> void:
		if _view == View.ROOM:
			PkLobby.close_own(_profile))

func _enter_tree() -> void:
	if _arena.is_empty():
		_fetch_arena()

## Đấu trường online đang mở (đã đăng nhập + arena server báo về).
func _online() -> bool:
	return AccountApi.is_logged_in() and bool(_arena.get("open", false))

func _fetch_arena() -> void:
	if _fetching or not AccountApi.is_logged_in():
		return
	_fetching = true
	var r: Dictionary = await AccountApi.arena(ServerSelectScreen.selected_server_id)
	_fetching = false
	if r.ok and r.data is Dictionary:
		_arena = r.data
	elif r.status == 401:
		_arena = {}
	if is_inside_tree() and _view == View.LOBBY:
		_refresh_lists()

## Vào arena server làm việc `action` ({op: create | join | watch | match, room, password}).
func _enter_online(action: Dictionary) -> void:
	var target_mode: int = int(action.get("mode", _mode))
	if target_mode == MODE_ALL:
		target_mode = int(action.get("mode", PkRules.Mode.LIEN_DAU))
	var server := {"host": str(_arena.get("host", "")), "port": int(_arena.get("port", 7797)), "ws_url": str(_arena.get("ws_url", "")),
		"name": "Đấu trường PK"}
	_enter(PkRules.arena_entry({"mode": target_mode, "online": true, "server": server, "action": action}))

## Phòng của arena server: lọc theo mode (-1 = tất cả) và state ("" = tất cả).
func _online_rooms(mode_filter: int = -1, state_filter: String = "") -> Array:
	var out := []
	for r in _arena.get("rooms", []):
		if mode_filter >= 0 and int(r.get("mode", -1)) != mode_filter:
			continue
		var st := str(r.get("state", ""))
		var is_waiting := (st == "waiting")
		if state_filter == PkLobby.WAITING and not is_waiting:
			continue
		if state_filter == PkLobby.FIGHTING and is_waiting:
			continue
		out.append(r)
	return out

static func _locked(r: Dictionary) -> bool:
	return bool(r.get("locked", false)) or str(r.get("password", "")) != ""

func _select_mode(m: int) -> void:
	if _view != View.LOBBY:
		return                      ## đang chờ phòng / đang tìm: không đổi tab
	_mode = m
	var modes := [MODE_ALL, PkRules.Mode.DAI_HOI, PkRules.Mode.LIEN_DAU, PkRules.Mode.THACH_DAU, PkRules.Mode.LON_XON, PkRules.Mode.TONG_KIM_LOL]
	for i in _tab_buttons.size():
		if i < modes.size():
			GameUi.set_active(_tab_buttons[i], modes[i] == m)
	_show_lobby()

func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()
	_timer_label = null

# ---------------------------------------------------------------- sảnh: danh sách phòng

func _show_lobby() -> void:
	_view = View.LOBBY
	_clear()

	# 1. Giới thiệu / Điều kiện & Thành tích
	if _mode == MODE_ALL:
		var intro := SocialUi.label("Toàn bộ các phòng tỷ thí & trận đấu đang mở trong giang hồ", SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
		_content.add_child(intro)
	else:
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
					SocialUi.LABEL_BLUE, 13, HORIZONTAL_ALIGNMENT_CENTER))
		else:
			_content.add_child(SocialUi.label("Tự do tỷ thí võ nghệ   ·   Thành tích: thắng %d · thua %d (Không tính điểm xếp hạng)" % [
					int(rec.get("win", 0)), int(rec.get("lose", 0))],
					SocialUi.LABEL_GREEN, 13, HORIZONTAL_ALIGNMENT_CENTER))

	# 2. Thanh tìm kiếm và bộ lọc trạng thái
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	_content.add_child(filter_row)

	_search_box = SocialUi.line_edit("Tìm theo ID phòng (#...) hoặc tên người chơi")
	_search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_box.text_changed.connect(func(_t: String) -> void: _refresh_lists())
	filter_row.add_child(_search_box)

	_state_filter_btn = OptionButton.new()
	_state_filter_btn.focus_mode = Control.FOCUS_NONE
	_state_filter_btn.custom_minimum_size = Vector2(150, 36)
	_state_filter_btn.add_item("Tất cả trạng thái", 0)
	_state_filter_btn.add_item("● Đang chờ", 1)
	_state_filter_btn.add_item("⚔ Đang đánh", 2)
	_state_filter_btn.item_selected.connect(func(idx: int) -> void:
		match idx:
			1: _state_filter = PkLobby.WAITING
			2: _state_filter = PkLobby.FIGHTING
			_: _state_filter = ""
		_refresh_lists()
	)
	filter_row.add_child(_state_filter_btn)

	var refresh_b := SocialUi.small_button("↻ Làm mới")
	refresh_b.custom_minimum_size = Vector2(85, 36)
	refresh_b.pressed.connect(func() -> void:
		_fetch_arena()
		_refresh_lists()
	)
	filter_row.add_child(refresh_b)

	# 3. Tiêu đề danh sách phòng (Table Header)
	var th_panel := GameUi.panel(GameUi.SECTION)
	th_panel.custom_minimum_size.y = 28
	var th_box := HBoxContainer.new()
	th_box.add_theme_constant_override("separation", 8)
	th_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	th_box.offset_left = 10
	th_box.offset_right = -10
	th_panel.add_child(th_box)

	var th_mode := SocialUi.label("Chế độ / ID", SocialUi.MUTED, 12)
	th_mode.custom_minimum_size.x = 130
	th_box.add_child(th_mode)

	var th_info := SocialUi.label("Thông tin phòng / Đấu thủ", SocialUi.MUTED, 12)
	th_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th_box.add_child(th_info)

	var th_slots := SocialUi.label("Số người", SocialUi.MUTED, 12, HORIZONTAL_ALIGNMENT_CENTER)
	th_slots.custom_minimum_size.x = 75
	th_box.add_child(th_slots)

	var th_status := SocialUi.label("Trạng thái", SocialUi.MUTED, 12, HORIZONTAL_ALIGNMENT_CENTER)
	th_status.custom_minimum_size.x = 95
	th_box.add_child(th_status)

	var th_action := SocialUi.label("Thao tác", SocialUi.MUTED, 12, HORIZONTAL_ALIGNMENT_CENTER)
	th_action.custom_minimum_size.x = 75
	th_box.add_child(th_action)

	_content.add_child(th_panel)

	# 4. Danh sách chung các phòng (Scrollable Unified Room List)
	var frame := GameUi.panel(GameUi.PANEL)
	_content.add_child(frame)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	_room_list = VBoxContainer.new()
	_room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_room_list)
	_waiting_list = _room_list
	_fighting_list = _room_list

	_refresh_lists()

	# 5. Thanh nút chức năng bên dưới
	var reason := PkRules.check_entry(_profile, _mode) if _mode >= 0 else ""
	_status = SocialUi.label(reason, SocialUi.WARN, 13, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = reason != ""
	_content.add_child(_status)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)

	var create := SocialUi.stone_button("Tạo phòng", Vector2(180, 42))
	create.disabled = reason != ""
	create.pressed.connect(_ask_create_room)
	row.add_child(create)

	var find := SocialUi.stone_button("Tự tìm đối thủ", Vector2(180, 42))
	find.disabled = reason != ""
	find.pressed.connect(_start_search)
	row.add_child(find)

func _refresh_lists() -> void:
	if _room_list == null or not is_instance_valid(_room_list):
		return
	for c in _room_list.get_children():
		c.queue_free()

	var source: Array = []
	if _online():
		source.append_array(_online_rooms(_mode, _state_filter))
		for lr in PkLobby.rooms(_mode, _state_filter):
			var already_in := false
			for sr in source:
				if str(sr.get("id", "")) == str(lr.get("id", "")):
					already_in = true
					break
			if not already_in:
				source.append(lr)
	else:
		source = PkLobby.rooms(_mode, _state_filter)

	var query := _search_box.text.strip_edges().to_lower().trim_prefix("#") if _search_box else ""
	var rooms := source.filter(func(r: Dictionary) -> bool:
		if query == "":
			return true
		var id_str := str(r.get("id", "")).to_lower().trim_prefix("#")
		var host_str := str(r.get("host", "")).to_lower()
		var sect_str := str(r.get("sect_name", "")).to_lower()
		return id_str.contains(query) or host_str.contains(query) or sect_str.contains(query)
	)

	# Sắp xếp: phòng chờ còn chỗ lên trước, rồi đến phòng chờ đủ, rồi đến phòng đang đánh
	rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var st_a := str(a.get("state", ""))
		var st_b := str(b.get("state", ""))
		if st_a != st_b:
			return st_a == PkLobby.WAITING
		return int(a.get("created_ms", 0)) > int(b.get("created_ms", 0))
	)

	for r in rooms:
		_room_list.add_child(_room_row(r))

	if rooms.is_empty():
		var empty_text := "Hiện chưa có phòng nào trong danh sách.\nHãy bấm [Tạo phòng] để mở phòng mới hoặc [Tự tìm đối thủ] để hệ thống tự ghép trận!"
		if _fetching and _arena.is_empty():
			empty_text = "Đang tải danh sách phòng đấu..."
		elif query != "":
			empty_text = "Không tìm thấy phòng nào phù hợp với '%s'." % query
		elif _state_filter != "":
			empty_text = "Không có phòng nào ở trạng thái '%s'." % ("Đang chờ" if _state_filter == PkLobby.WAITING else "Đang đánh")
		var empty := SocialUi.label(empty_text, SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_room_list.add_child(empty)

static func _mode_tag(r: Dictionary) -> Array:
	var m: int = int(r.get("mode", 0))
	var s: int = int(r.get("team_size", 1))
	match m:
		PkRules.Mode.DAI_HOI:
			return ["[Đại Hội]", Color(0.35, 0.82, 0.95)]
		PkRules.Mode.LIEN_DAU:
			return ["[Liên Đấu]", Color(0.98, 0.82, 0.35)]
		PkRules.Mode.THACH_DAU:
			return ["[%s]" % PkRules.format_name(s), Color(0.82, 0.58, 0.98)]
		PkRules.Mode.LON_XON:
			var b_type := str(r.get("brawl_type", "solo"))
			if b_type == "solo":
				return ["[Loạn Đả 16]", Color(0.98, 0.6, 0.25)]
			else:
				return ["[Đội %s]" % PkRules.format_name(s), Color(0.98, 0.6, 0.25)]
		PkRules.Mode.TONG_KIM_LOL:
			return ["[Tống Kim %s]" % PkRules.format_name(s), Color(0.35, 0.88, 0.55)]
		_:
			return ["[PK]", SocialUi.TEXT]

func _room_row(r: Dictionary) -> Control:
	var row_panel := GameUi.panel(GameUi.PANEL)
	row_panel.custom_minimum_size.y = 48

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row_panel.add_child(row)

	var st := str(r.get("state", ""))
	var is_waiting := (st == PkLobby.WAITING or st == "waiting")
	var r_mode := int(r.get("mode", 0))
	var team_sz := int(r.get("team_size", 1))

	# 1. Chế độ & ID
	var tag_info := _mode_tag(r)
	var col_id := VBoxContainer.new()
	col_id.custom_minimum_size.x = 130
	col_id.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col_id)

	var tag_label := SocialUi.label(tag_info[0], tag_info[1] as Color, 12)
	col_id.add_child(tag_label)

	var lock_icon := " 🔒" if _locked(r) else ""
	var id_label := SocialUi.label("#%s%s" % [r.get("id", "000000"), lock_icon], SocialUi.GOLD, 13)
	col_id.add_child(id_label)

	# 2. Thông tin phòng / Đấu thủ
	var col_info := VBoxContainer.new()
	col_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col_info)

	var desc_text := ""
	var sub_text := ""
	if is_waiting:
		var host_name := str(r.get("host", "?"))
		var host_lv := int(r.get("level", 1))
		var host_sect := str(r.get("sect_name", "Vô môn phái"))
		desc_text = "Chủ phòng: %s" % host_name
		sub_text = "Cấp %d · %s" % [host_lv, host_sect]
		if r_mode == PkRules.Mode.LON_XON:
			var tk := int(r.get("target_kills", 20))
			var map_info := PkRules.get_brawl_map_info(int(r.get("map_id", 319)))
			sub_text += " · %s (%d mạng)" % [map_info["name"], tk]
		elif r_mode == PkRules.Mode.TONG_KIM_LOL:
			sub_text += " · Ải Tống Kim MOBA"
	else:
		if r.has("fighters"):
			var f: Array = r["fighters"]
			var f0 := str(f[0]) if f.size() > 0 else "?"
			var f1 := str(f[1]) if f.size() > 1 else "?"
			desc_text = "%s vs %s" % [f0, f1]
			var specs := int(r.get("spectators", 0))
			sub_text = "Trận đấu online" + (" · 👁 %d khán giả" % specs if specs > 0 else "")
		else:
			var host_name := str(r.get("host", "?"))
			var guest_name := str(r.get("guest", ""))
			if r_mode == PkRules.Mode.LON_XON:
				desc_text = "Loạn Đả 16 người đang kịch chiến!"
				sub_text = "Chủ phòng: %s" % host_name
			elif r_mode == PkRules.Mode.TONG_KIM_LOL:
				desc_text = "Chiến trường Tống Kim (Phe Tống vs Phe Kim)"
				sub_text = "Chủ phòng: %s" % host_name
			else:
				desc_text = "%s vs %s" % [host_name, guest_name if guest_name != "" else "Đối thủ"]
				sub_text = "Đang giao tranh quyết liệt"

	var l_desc := SocialUi.label(desc_text, SocialUi.TEXT, 13)
	l_desc.clip_text = true
	col_info.add_child(l_desc)

	var l_sub := SocialUi.label(sub_text, SocialUi.MUTED, 11)
	l_sub.clip_text = true
	col_info.add_child(l_sub)

	# 3. Số người / Sức chứa
	var max_players := 2
	var cur_players := 0
	if r_mode == PkRules.Mode.LON_XON and str(r.get("brawl_type", "solo")) == "solo":
		max_players = 16
		cur_players = (r.get("solo_slots", []) as Array).size()
		if cur_players == 0 and r.has("host"): cur_players = 1
	elif r_mode in [PkRules.Mode.THACH_DAU, PkRules.Mode.TONG_KIM_LOL] or (r_mode == PkRules.Mode.LON_XON and str(r.get("brawl_type", "")) == "team"):
		max_players = team_sz * 2
		var ta: Array = r.get("team_a", [])
		var tb: Array = r.get("team_b", [])
		cur_players = ta.size() + tb.size()
		if cur_players == 0 and r.has("host"): cur_players = 1
	else:
		max_players = 2
		cur_players = 1 if is_waiting else 2

	var is_full := (cur_players >= max_players)
	var slots_col := VBoxContainer.new()
	slots_col.custom_minimum_size.x = 75
	slots_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(slots_col)

	var l_slots := SocialUi.label("%d/%d" % [cur_players, max_players], SocialUi.GOLD if not is_full else SocialUi.WARN, 13, HORIZONTAL_ALIGNMENT_CENTER)
	slots_col.add_child(l_slots)

	# 4. Trạng thái (Status Badge)
	var status_col := VBoxContainer.new()
	status_col.custom_minimum_size.x = 95
	status_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(status_col)

	var status_text := "● Đang chờ" if is_waiting else "⚔ Đang đánh"
	var status_color := (SocialUi.WARN if is_full else SocialUi.LABEL_GREEN) if is_waiting else Color(0.95, 0.45, 0.25)
	if is_waiting and is_full:
		status_text = "● Sẵn sàng"
	var l_status := SocialUi.label(status_text, status_color, 12, HORIZONTAL_ALIGNMENT_CENTER)
	status_col.add_child(l_status)

	# 5. Thao tác
	var act_col := VBoxContainer.new()
	act_col.custom_minimum_size.x = 75
	act_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(act_col)

	if is_waiting:
		var btn := SocialUi.stone_button("Vào", Vector2(70, 32))
		btn.pressed.connect(_join_room.bind(r))
		act_col.add_child(btn)
	elif r_mode != PkRules.Mode.TONG_KIM_LOL and r_mode != PkRules.Mode.LON_XON:
		var btn := SocialUi.small_button("Xem")
		btn.custom_minimum_size = Vector2(70, 32)
		btn.pressed.connect(_watch_room.bind(r))
		act_col.add_child(btn)
	else:
		var lbl := SocialUi.label("Đang đấu", SocialUi.MUTED, 11, HORIZONTAL_ALIGNMENT_CENTER)
		act_col.add_child(lbl)

	# Nhấp vào dòng để vào hoặc xem
	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	row_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if is_waiting:
				_join_room(r)
			elif r_mode != PkRules.Mode.TONG_KIM_LOL and r_mode != PkRules.Mode.LON_XON:
				_watch_room(r)
	)

	return row_panel

func _join_room(r: Dictionary) -> void:
	var r_mode := int(r.get("mode", 0))
	if _online():
		var why := PkRules.check_entry(_profile, r_mode)
		if why != "":
			_flash(why)
			return
		_with_password(r, func(pw: String) -> void: _enter_online({"op": "join", "mode": r_mode, "room": str(r["id"]), "password": pw}))
		return
	if str(r["host"]) == (_profile.display_name if _profile else ""):
		_show_room(r)
		return
	var reason := PkRules.check_entry(_profile, r_mode)
	if reason == "" and not PkRules.can_match(r_mode, _profile.level, _profile.sect_id, int(r["level"]), str(r["sect_id"])):
		reason = "Chênh lệch quá %d cấp%s." % [PkRules.MATCH_LEVEL_DIFF, " hoặc khác môn phái" if r_mode == PkRules.Mode.DAI_HOI else ""]
	if reason != "":
		_flash(reason)
		return
	if r_mode == PkRules.Mode.THACH_DAU or r_mode == PkRules.Mode.LON_XON or r_mode == PkRules.Mode.TONG_KIM_LOL:
		_with_password(r, func(pw: String) -> void:
			if str(r.get("password", "")) != "" and pw != str(r["password"]):
				_flash("Sai mật khẩu phòng.")
				return
			if r_mode == PkRules.Mode.LON_XON and str(r.get("brawl_type", "")) == "solo":
				var solo_slots: Array = r.get("solo_slots", [])
				if solo_slots.size() >= 16:
					_flash("Phòng Loạn Đả đã đủ 16 người.")
					return
				var sect := SectRegistry.get_by_id(_profile.sect_id)
				solo_slots.append({
					"name": _profile.display_name,
					"level": _profile.level,
					"sect_id": _profile.sect_id,
					"sect_name": sect.sect_name if sect else "Vô môn phái",
					"ready": true,
					"is_host": false
				})
				r["solo_slots"] = solo_slots
				_show_room(r)
				return
			var target_team := "b" if (r.get("team_b", []) as Array).size() < int(r.get("team_size", 1)) else "a"
			if PkLobby.join_team(str(r["id"]), _profile, target_team):
				_show_room(PkLobby.find(str(r["id"])))
			else:
				_flash("Phòng đã đủ người.")
		)
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
	var r_mode := int(r.get("mode", 0))
	_with_password(r, func(pw: String) -> void: _enter_online({"op": "watch", "mode": r_mode, "room": str(r["id"]), "password": pw}))

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
	if _mode == MODE_ALL:
		_show_mode_select_dialog("Tạo Phòng", func(chosen_mode: int) -> void:
			_mode = chosen_mode
			_ask_create_room()
		)
		return
	if _mode == PkRules.Mode.LON_XON:
		_show_lon_xon_create_dialog()
		return
	if _mode == PkRules.Mode.THACH_DAU or _mode == PkRules.Mode.TONG_KIM_LOL:
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

func _show_mode_select_dialog(title: String, on_chosen: Callable) -> void:
	var dlg := SocialWindow.new(title, "Chọn chế độ thi đấu", 460.0)
	dlg.body.add_child(SocialUi.label("Chọn chế độ thi đấu:", SocialUi.TITLE, 14, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dlg.body.add_child(grid)

	var modes := [PkRules.Mode.DAI_HOI, PkRules.Mode.LIEN_DAU, PkRules.Mode.THACH_DAU, PkRules.Mode.LON_XON, PkRules.Mode.TONG_KIM_LOL]
	for m in modes:
		var btn := GameUi.button(PkRules.MODE_NAMES[m])
		btn.custom_minimum_size = Vector2(190, 40)
		btn.pressed.connect(func() -> void:
			dlg.queue_free()
			on_chosen.call(m)
		)
		grid.add_child(btn)

	var cancel := SocialUi.stone_button("Đóng", Vector2(140, 36))
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func() -> void: dlg.queue_free())
	dlg.body.add_child(cancel)
	SocialWindow.present(self, dlg, &"mode_select")

func _show_lon_xon_create_dialog() -> void:
	var dlg := SocialWindow.new("Tạo Phòng Lộn Xộn", "Chọn thể thức Loạn đả hoặc Đấu đội, bản đồ và số mạng kết thúc", 520.0)
	var selected_brawl_type := ["solo"] # "solo" hoặc "team"
	var selected_team_size := [1]
	var selected_map_id := [319] # Lâm Du Quan
	var selected_target_kills := [20]
	
	dlg.body.add_child(SocialUi.label("1. Chế độ thi đấu:", SocialUi.TITLE, 14))
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 12)
	dlg.body.add_child(mode_row)
	
	var btn_solo := GameUi.button("Đấu đơn (16 người)")
	btn_solo.custom_minimum_size = Vector2(180, 36)
	var btn_team := GameUi.button("Đấu theo đội (2 phe)")
	btn_team.custom_minimum_size = Vector2(180, 36)
	mode_row.add_child(btn_solo)
	mode_row.add_child(btn_team)
	GameUi.set_active(btn_solo, true)
	
	var team_format_container := VBoxContainer.new()
	team_format_container.visible = false
	dlg.body.add_child(team_format_container)
	team_format_container.add_child(SocialUi.label("Thể thức đấu đội (1vs1 -> 8vs8):", SocialUi.TEXT, 13))
	
	var team_grid := GridContainer.new()
	team_grid.columns = 4
	team_grid.add_theme_constant_override("h_separation", 8)
	team_grid.add_theme_constant_override("v_separation", 6)
	team_format_container.add_child(team_grid)
	
	var format_buttons: Array[Button] = []
	for s in PkRules.TEAM_FORMATS:
		var b := GameUi.button(PkRules.format_name(s))
		b.custom_minimum_size = Vector2(100, 32)
		b.pressed.connect(func() -> void:
			selected_team_size[0] = s
			for btn in format_buttons:
				GameUi.set_active(btn, btn == b)
		)
		team_grid.add_child(b)
		format_buttons.append(b)
	GameUi.set_active(format_buttons[0], true)
	
	btn_solo.pressed.connect(func() -> void:
		selected_brawl_type[0] = "solo"
		GameUi.set_active(btn_solo, true)
		GameUi.set_active(btn_team, false)
		team_format_container.visible = false
	)
	btn_team.pressed.connect(func() -> void:
		selected_brawl_type[0] = "team"
		GameUi.set_active(btn_solo, false)
		GameUi.set_active(btn_team, true)
		team_format_container.visible = true
	)
	
	dlg.body.add_child(SocialUi.label("2. Chọn bản đồ thi đấu:", SocialUi.TITLE, 14))
	var map_row := HBoxContainer.new()
	map_row.alignment = BoxContainer.ALIGNMENT_CENTER
	map_row.add_theme_constant_override("separation", 8)
	dlg.body.add_child(map_row)
	
	var map_buttons: Array[Button] = []
	for m_info in PkRules.BRAWL_MAPS:
		var b := GameUi.button(m_info["name"])
		b.custom_minimum_size = Vector2(145, 36)
		var mid: int = int(m_info["id"])
		b.pressed.connect(func() -> void:
			selected_map_id[0] = mid
			for btn in map_buttons:
				GameUi.set_active(btn, btn == b)
		)
		map_row.add_child(b)
		map_buttons.append(b)
	GameUi.set_active(map_buttons[0], true)
	
	dlg.body.add_child(SocialUi.label("3. Số mạng kết thúc trận (10 - 200 mạng):", SocialUi.TITLE, 14))
	var target_label := SocialUi.label("Mục tiêu: 20 mạng (Đủ số mạng sẽ kết thúc trận)", SocialUi.GOLD, 13, HORIZONTAL_ALIGNMENT_CENTER)
	dlg.body.add_child(target_label)
	
	var quick_row := HBoxContainer.new()
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.add_theme_constant_override("separation", 6)
	dlg.body.add_child(quick_row)
	
	var quick_kills := [10, 15, 20, 25, 30, 35, 40, 50, 100, 200]
	var quick_buttons: Array[Button] = []
	for qk in quick_kills:
		var b := SocialUi.small_button(str(qk))
		b.pressed.connect(func() -> void:
			selected_target_kills[0] = qk
			target_label.text = "Mục tiêu: %d mạng (Đủ số mạng sẽ kết thúc trận)" % qk
			for btn in quick_buttons:
				GameUi.set_active(btn, btn == b)
		)
		quick_row.add_child(b)
		quick_buttons.append(b)
	GameUi.set_active(quick_buttons[2], true)
	
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
		_create_lon_xon_room(pw, selected_brawl_type[0], selected_team_size[0], selected_map_id[0], selected_target_kills[0])
	)
	btn_row.add_child(btn_confirm)
	
	var btn_cancel := SocialUi.stone_button("Hủy", Vector2(160, 40))
	btn_cancel.pressed.connect(func() -> void:
		dlg.queue_free()
	)
	btn_row.add_child(btn_cancel)
	
	SocialWindow.present(self, dlg, &"lon_xon_create")

func _create_lon_xon_room(password: String, brawl_type: String, team_size: int, map_id: int, target_kills: int) -> void:
	var extra := {
		"brawl_type": brawl_type,
		"team_size": team_size,
		"map_id": map_id,
		"target_kills": target_kills
	}
	if _online():
		_enter_online({"op": "create", "mode": _mode, "password": password, "team_size": team_size,
			"brawl_type": brawl_type, "map_id": map_id, "target_kills": target_kills})
	else:
		_show_room(PkLobby.create(_profile, _mode, password, team_size, extra))

func _show_thach_dau_create_dialog() -> void:
	var is_lol := _mode == PkRules.Mode.TONG_KIM_LOL
	var title := "Tạo Phòng Tống Kim LOL" if is_lol else "Tạo Phòng Thách Đấu"
	var subtitle := "Chọn thể thức thi đấu MOBA 1vs1 đến 5vs5" if is_lol else "Chọn thể thức so tài võ nghệ"
	var dlg := SocialWindow.new(title, subtitle, 480.0)
	var selected_team_size := [1]
	
	dlg.body.add_child(SocialUi.label("Chọn thể thức thi đấu:", SocialUi.TITLE, 14))
	
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	dlg.body.add_child(grid)
	
	var format_buttons: Array[Button] = []
	var formats: Array = TongKimLolRules.TEAM_SIZES if is_lol else PkRules.TEAM_FORMATS
	for s in formats:
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

## Online: vào arena server mở phòng; offline: phòng chờ cục bộ (PkLobby).
func _create_room(password: String, team_size: int = 1) -> void:
	if _online():
		_enter_online({"op": "create", "mode": _mode, "password": password, "team_size": team_size})
	else:
		_show_room(PkLobby.create(_profile, _mode, password, team_size))

func _show_room(room: Dictionary, keep_timer: bool = false) -> void:
	_view = View.ROOM
	_room = room
	if not keep_timer:
		_search_time = 0.0
	_clear()
	var team_size: int = PkRules.team_size_for(room)
	var is_lol := _mode == PkRules.Mode.TONG_KIM_LOL
	var is_brawl := _mode == PkRules.Mode.LON_XON
	var brawl_type := str(room.get("brawl_type", "solo")) if is_brawl else ""
	var format_tag := ""
	if is_brawl:
		if brawl_type == "solo":
			format_tag = " [Đấu đơn - 16 người]"
		else:
			format_tag = " [Đấu đội %s]" % PkRules.format_name(team_size)
	elif _mode == PkRules.Mode.THACH_DAU or is_lol:
		format_tag = " [%s]" % PkRules.format_name(team_size)
	_content.add_child(SocialUi.label("Phòng #%s%s" % [room["id"], format_tag], SocialUi.TITLE, 22, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(SocialUi.label("%s · Chủ phòng: %s (cấp %d, %s)" % [PkRules.MODE_NAMES[_mode], room["host"], int(room["level"]),
			room["sect_name"]], SocialUi.TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER))
	if is_brawl:
		var map_info := PkRules.get_brawl_map_info(int(room.get("map_id", 319)))
		var tk := int(room.get("target_kills", 20))
		_content.add_child(SocialUi.label("Bản đồ: %s   ·   Mục tiêu kết thúc: %d mạng   ·   Thưởng: Điểm x 30 EXP" % [
			map_info["name"], tk
		], SocialUi.GOLD, 13, HORIZONTAL_ALIGNMENT_CENTER))
	elif is_lol:
		_content.add_child(SocialUi.label("Bản đồ: Ải Tống Kim (Chiến trường MOBA)   ·   Thời gian: 40 phút   ·   Thưởng: EXP x10",
			SocialUi.GOLD, 13, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(SocialUi.label("Mật khẩu: %s" % ("có" if str(room["password"]) != "" else "không"), SocialUi.LABEL_BLUE, 14,
			HORIZONTAL_ALIGNMENT_CENTER))

	var is_host := (str(room.get("host", "")) == (_profile.display_name if _profile else ""))

	var team_a: Array = room.get("team_a", [])
	var team_b: Array = room.get("team_b", [])
	var count_a: int = team_a.size()
	var count_b: int = team_b.size()
	var total_players: int = count_a + count_b
	var total_required: int = team_size * 2
	var is_full: bool = (count_a == team_size and count_b == team_size)
	var all_ready: bool = true
	for m in team_a + team_b:
		if not bool(m.get("is_host", false)) and not bool(m.get("ready", false)):
			all_ready = false
			break

	if is_brawl and brawl_type == "solo":
		var solo_slots: Array = room.get("solo_slots", [])
		_make_solo_panel(_content, solo_slots, is_host)
	else:
		# 2 Cột danh sách 2 phe
		var teams_row := HBoxContainer.new()
		teams_row.add_theme_constant_override("separation", 16)
		_content.add_child(teams_row)

		var header_a := "Phe Xanh" if is_brawl else ("Phe Tống (Xanh Lam)" if is_lol else "Phe Chủ phòng (Xanh)")
		var header_b := "Phe Đỏ" if is_brawl else ("Phe Kim (Đỏ Cam)" if is_lol else "Phe Thách đấu (Đỏ)")
		_make_team_panel(teams_row, header_a, team_a, team_size, "a", is_host)
		_make_team_panel(teams_row, header_b, team_b, team_size, "b", is_host)

	var hint_text := "Đang chờ đối thủ…"
	if is_brawl:
		hint_text = "Tự do so tài võ nghệ. Bấm [Bắt đầu trận] để tự động điền Bot hoặc chia sẻ ID phòng."
	elif is_lol:
		if not is_full:
			hint_text = "Đang chờ đủ người chơi (%d/%d người). Phe Tống: %d/%d · Phe Kim: %d/%d.\nHãy chia sẻ ID phòng #%s để người chơi khác tham gia!" % [
				total_players, total_required, count_a, team_size, count_b, team_size, room["id"]
			]
		elif not all_ready:
			hint_text = "Đã đủ %d/%d người chơi! Đang chờ tất cả thành viên bấm [Sẵn sàng] để bắt đầu trận..." % [
				total_players, total_required
			]
		else:
			hint_text = "Phòng đã đủ người và tất cả đã sẵn sàng! Chủ phòng có thể bấm [Bắt đầu trận] để khai chiến!"
	elif _mode == PkRules.Mode.THACH_DAU:
		hint_text = "Chia sẻ ID phòng cho đồng đội / đối thủ để vào phòng."
	var hint := SocialUi.label(hint_text, SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
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
		if is_lol:
			if not is_full:
				btn_start.disabled = true
				btn_start.text = "Chờ đủ người (%d/%d)" % [total_players, total_required]
			elif not all_ready:
				btn_start.disabled = true
				btn_start.text = "Chờ sẵn sàng"
		btn_start.pressed.connect(_start_room_match)
		row.add_child(btn_start)

		if not _online() or _mode == PkRules.Mode.THACH_DAU or _mode == PkRules.Mode.LON_XON or is_lol:
			var btn_bot := SocialUi.stone_button("Thêm Bot", Vector2(140, 42))
			btn_bot.pressed.connect(_add_bot_to_room)
			if is_lol and is_full:
				btn_bot.disabled = true
			row.add_child(btn_bot)

		var cancel := SocialUi.stone_button("Huỷ phòng", Vector2(140, 42))
		cancel.pressed.connect(func() -> void:
			PkLobby.close(str(_room["id"]))
			_room = {}
			_show_lobby())
		row.add_child(cancel)
	else:
		var my_name := _profile.display_name if _profile else ""
		var is_my_ready := false
		for m: Dictionary in (team_a + team_b):
			if str(m.get("name", "")) == my_name:
				is_my_ready = bool(m.get("ready", false))
				break
		var btn_ready := SocialUi.stone_button("Hủy sẵn sàng" if is_my_ready else "Sẵn sàng", Vector2(160, 42))
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

func _make_solo_panel(parent: Control, members: Array, is_host: bool) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)

	var head_label := SocialUi.label("Danh Sách Đấu Thủ (%d/16)" % members.size(), SocialUi.GOLD, 14, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(head_label)

	var frame := GameUi.panel(GameUi.PANEL)
	col.add_child(frame)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	for i in 16:
		var slot_box := HBoxContainer.new()
		slot_box.custom_minimum_size.x = 270
		slot_box.add_theme_constant_override("separation", 6)
		grid.add_child(slot_box)

		if i < members.size():
			var m: Dictionary = members[i]
			var star := "★ " if bool(m.get("is_host", false)) else ""
			var bot_tag := " [Bot]" if bool(m.get("is_bot", false)) else ""
			var text := "%sSlot %d: %s (Cấp %d · %s)%s" % [star, i + 1, m.get("name", "?"), int(m.get("level", 1)), m.get("sect_name", ""), bot_tag]
			var l := SocialUi.label(text, SocialUi.TEXT, 12)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			slot_box.add_child(l)
			if is_host and i > 0:
				var kick_b := SocialUi.small_button("Xóa")
				kick_b.pressed.connect(func() -> void:
					members.remove_at(i)
					_room["solo_slots"] = members
					_show_room(_room)
				)
				slot_box.add_child(kick_b)
		else:
			var empty_l := SocialUi.label("Slot %d: (Tự động điền Bot)" % (i + 1), SocialUi.MUTED, 12)
			empty_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_box.add_child(empty_l)

func _add_bot_to_room() -> void:
	if not _room.is_empty():
		if _mode == PkRules.Mode.LON_XON and str(_room.get("brawl_type", "")) == "solo":
			var solo_slots: Array = _room.get("solo_slots", [])
			if solo_slots.size() < 16:
				PkLobby.add_bot(str(_room["id"]), "", _profile.level if _profile else 90)
				_show_room(PkLobby.find(str(_room["id"])))
			return
		var team_b: Array = _room.get("team_b", [])
		var team_a: Array = _room.get("team_a", [])
		var team_size: int = int(_room.get("team_size", 1))
		var target_team := "b" if team_b.size() < team_size else ("a" if team_a.size() < team_size else "")
		if target_team != "":
			PkLobby.add_bot(str(_room["id"]), target_team, _profile.level if _profile else 90)
			_show_room(PkLobby.find(str(_room["id"])))

func _start_room_match() -> void:
	if _online() and _mode != PkRules.Mode.THACH_DAU and _mode != PkRules.Mode.TONG_KIM_LOL and _mode != PkRules.Mode.LON_XON:
		_enter_online({"op": "start", "room": str(_room["id"])})
		return
	if _mode == PkRules.Mode.LON_XON:
		var b_type := str(_room.get("brawl_type", "solo"))
		var map_id: int = int(_room.get("map_id", 319))
		var target_k: int = int(_room.get("target_kills", 20))
		if b_type == "solo":
			var solo_slots: Array = _room.get("solo_slots", []).duplicate(true)
			while solo_slots.size() < 16:
				var bot := PkBotProfile.create(_profile.level if _profile else 90)
				var sect := SectRegistry.get_by_id(bot.sect_id)
				solo_slots.append({
					"name": bot.display_name,
					"level": bot.level,
					"sect_id": bot.sect_id,
					"sect_name": sect.sect_name if sect else "Vô môn phái",
					"ready": true,
					"is_bot": true,
					"bot_data": bot.to_dict()
				})
			var entry := PkRules.arena_entry({
				"mode": _mode,
				"brawl_type": "solo",
				"map_id": map_id,
				"target_kills": target_k,
				"solo_combatants": solo_slots,
				"room_id": str(_room.get("id", ""))
			})
			_enter(entry)
			return
		else:
			var team_sz: int = PkRules.team_size_for(_room)
			var team_a: Array = _room.get("team_a", []).duplicate(true)
			var team_b: Array = _room.get("team_b", []).duplicate(true)
			while team_a.size() < team_sz:
				var bot := PkBotProfile.create(_profile.level if _profile else 90)
				var sect := SectRegistry.get_by_id(bot.sect_id)
				team_a.append({"name": bot.display_name, "level": bot.level, "sect_id": bot.sect_id, "sect_name": sect.sect_name if sect else "Vô môn phái",
					"ready": true, "is_bot": true, "bot_data": bot.to_dict()})
			while team_b.size() < team_sz:
				var bot := PkBotProfile.create(_profile.level if _profile else 90)
				var sect := SectRegistry.get_by_id(bot.sect_id)
				team_b.append({"name": bot.display_name, "level": bot.level, "sect_id": bot.sect_id, "sect_name": sect.sect_name if sect else "Vô môn phái",
					"ready": true, "is_bot": true, "bot_data": bot.to_dict()})
			var my_side := "song"
			var p_name := _profile.display_name if _profile else ""
			for m in team_b:
				if str(m.get("name", "")) == p_name:
					my_side = "jin"
					break
			var entry := PkRules.arena_entry({
				"mode": _mode,
				"brawl_type": "team",
				"map_id": map_id,
				"target_kills": target_k,
				"team_size": team_sz,
				"team_a": team_a,
				"team_b": team_b,
				"side": my_side,
				"room_id": str(_room.get("id", ""))
			})
			_enter(entry)
			return

	if _mode == PkRules.Mode.TONG_KIM_LOL:
		var team_sz: int = PkRules.team_size_for(_room)
		var team_a: Array = _room.get("team_a", []).duplicate(true)
		var team_b: Array = _room.get("team_b", []).duplicate(true)
		if team_a.size() < team_sz or team_b.size() < team_sz:
			_flash("Phòng chưa đủ người chơi! Cần đủ %d/%d người mỗi phe để bắt đầu." % [team_sz, team_sz])
			return
		for m in team_a + team_b:
			if not bool(m.get("is_host", false)) and not bool(m.get("ready", false)):
				_flash("Vẫn còn người chơi chưa sẵn sàng!")
				return
		var my_side := "song"
		var p_name := _profile.display_name if _profile else ""
		for m in team_b:
			if str(m.get("name", "")) == p_name:
				my_side = "jin"
				break
		var entry := PkRules.arena_entry({
			"mode": _mode,
			"team_size": team_sz,
			"team_a": team_a,
			"team_b": team_b,
			"side": my_side,
			"room_id": str(_room.get("id", ""))
		})
		_enter(entry)
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

	var my_side := "song"
	var p_name := _profile.display_name if _profile else ""
	for m in team_b:
		if str(m.get("name", "")) == p_name:
			my_side = "jin"
			break

	var entry := PkRules.arena_entry({
		"mode": _mode,
		"team_size": team_size,
		"team_a": team_a,
		"team_b": team_b,
		"side": my_side,
		"opponent": opponent_profile
	})
	_enter(entry)

# ---------------------------------------------------------------- tự tìm đối thủ

func _start_search() -> void:
	if _mode == MODE_ALL:
		_show_mode_select_dialog("Tự Tìm Đối Thủ", func(chosen_mode: int) -> void:
			_mode = chosen_mode
			_start_search()
		)
		return
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
			if not _room.is_empty():
				var rid := str(_room.get("id", ""))
				var cur_r := PkLobby.find(rid)
				if cur_r.is_empty():
					_room = {}
					_flash("Phòng đã bị huỷ.")
					_show_lobby()
				elif cur_r.hash() != _room.hash():
					_show_room(cur_r, true)
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

## Hết thời gian chờ: bot cùng cấp — Đại hội võ lâm cùng phái, Liên đấu phái ngẫu nhiên, Lộn xộn loạn đả 16 người.
func _match_bot() -> void:
	if _mode == PkRules.Mode.LON_XON:
		var solo_slots: Array = []
		for i in 16:
			var b := PkBotProfile.create(_profile.level if _profile else 90)
			var s := SectRegistry.get_by_id(b.sect_id)
			solo_slots.append({
				"name": b.display_name,
				"level": b.level,
				"sect_id": b.sect_id,
				"sect_name": s.sect_name if s else "Vô môn phái",
				"ready": true,
				"is_bot": true,
				"bot_data": b.to_dict()
			})
		_found_entry = PkRules.arena_entry({
			"mode": _mode,
			"brawl_type": "solo",
			"map_id": 319,
			"target_kills": 20,
			"solo_combatants": solo_slots
		})
		_found_in = FOUND_DELAY
		_clear()
		_content.add_child(SocialUi.label("Đã tìm thấy phòng đấu Loạn Đả!", SocialUi.TITLE, 22, HORIZONTAL_ALIGNMENT_CENTER))
		_content.add_child(SocialUi.label("16 Hiệp Khách cùng tham gia quyết chiến tại Lâm Du Quan", SocialUi.GOLD, 16, HORIZONTAL_ALIGNMENT_CENTER))
		_content.add_child(SocialUi.label("Đang tiến vào chiến trường…", SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER))
		return
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

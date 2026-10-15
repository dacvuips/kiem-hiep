extends SocialWindow
class_name PkWindow
## Popup PK (nút "PK" ở Character Hub) — 2 tab theo VLTK gốc: Đại hội võ lâm (đấu cùng phái) / Võ lâm Liên đấu (mọi phái), xem
## PkRules. Mỗi tab:
##   - Danh sách PHÒNG CHỜ ĐÁNH (vào đấu; phòng có khoá thì hỏi mật khẩu) và PHÒNG ĐANG ĐÁNH (vào xem) + ô tìm phòng theo ID.
##   - [Tạo phòng]: hỏi có đặt mật khẩu không -> mở phòng chờ có ID 6 số (PkLobby).
##   - [Tự tìm đối thủ]: tìm phòng chờ hợp (chênh <= 10 cấp, Đại hội: cùng phái); quá 1 phút không có -> đấu với bot cùng cấp
##     (tên, phái ngẫu nhiên — Đại hội: cùng phái), PkBotProfile.
## Vào trận: on_play(PkRules.arena_entry(...)) — Character Hub đổi cảnh như Vượt Ải.

const LIST_SIZE := Vector2(300, 220)
const FOUND_DELAY := 2.0           ## tìm được đối thủ: hiện tên đối thủ chừng này giây rồi mới vào trận

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
	for m in [PkRules.Mode.DAI_HOI, PkRules.Mode.LIEN_DAU]:
		var b := GameUi.button(PkRules.MODE_NAMES[m])
		b.custom_minimum_size = Vector2(170, 36)
		b.pressed.connect(_select_mode.bind(m))
		tabs.add_child(b)
		_tab_buttons.append(b)
	body.add_child(tabs)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	body.add_child(_content)
	_select_mode(PkRules.Mode.DAI_HOI if profile != null and profile.has_sect() else PkRules.Mode.LIEN_DAU)
	## Đóng popup khi đang chờ trong phòng: huỷ luôn phòng (không để phòng "ma" trong danh sách).
	close_requested.connect(func() -> void:
		if _view == View.ROOM:
			PkLobby.close_own(_profile))

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
	_content.add_child(SocialUi.label("Điều kiện: cấp từ %d%s   ·   Thành tích: thắng %d · thua %d" % [int(PkRules.MIN_LEVEL[_mode]),
			" · cùng môn phái" if _mode == PkRules.Mode.DAI_HOI else "", int(rec.get("win", 0)), int(rec.get("lose", 0))],
			SocialUi.LABEL_BLUE, 14, HORIZONTAL_ALIGNMENT_CENTER))

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
		var rooms := PkLobby.rooms(_mode, pair[1]).filter(func(r: Dictionary) -> bool: return query == "" or str(r["id"]).begins_with(query))
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
	var lock := "🔒 " if str(r["password"]) != "" else ""
	var text := "%s#%s  %s\nCấp %d · %s" % [lock, r["id"], r["host"], int(r["level"]), r["sect_name"]]
	if not waiting:
		text = "#%s
%s vs %s" % [r["id"], r["host"], r["guest"]]
	var l := SocialUi.label(text, SocialUi.TEXT, 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	row.add_child(l)
	var b := SocialUi.small_button("Vào" if waiting else "Xem")
	b.pressed.connect(_join_room.bind(r) if waiting else _watch_room.bind(r))
	row.add_child(b)
	return row

func _join_room(r: Dictionary) -> void:
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

func _watch_room(_r: Dictionary) -> void:
	_flash("Vào xem trận cần chơi online (đang phát triển).")

func _flash(text: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = text
		_status.visible = true

# ---------------------------------------------------------------- tạo phòng

func _ask_create_room() -> void:
	SocialWindow.ask_yes_no(self, "Tạo phòng", "Đặt mật khẩu cho phòng?\n(Phòng có mật khẩu chỉ người biết mật khẩu mới vào được.)",
		func(yes: bool) -> void:
			if yes:
				SocialWindow.prompt(self, "Mật khẩu phòng", "Nhập mật khẩu (1-16 ký tự)", func(pw: String) -> void:
					pw = pw.strip_edges().left(16)
					if pw == "":
						_flash("Chưa nhập mật khẩu — chưa tạo phòng.")
						return
					_show_room(PkLobby.create(_profile, _mode, pw)), "", true)
			else:
				_show_room(PkLobby.create(_profile, _mode, "")),
		"Có", "Không")

func _show_room(room: Dictionary) -> void:
	_view = View.ROOM
	_room = room
	_search_time = 0.0
	_clear()
	_content.add_child(SocialUi.label("Phòng #%s" % room["id"], SocialUi.TITLE, 22, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(SocialUi.label("%s · Chủ phòng: %s (cấp %d, %s)" % [PkRules.MODE_NAMES[_mode], room["host"], int(room["level"]),
			room["sect_name"]], SocialUi.TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(SocialUi.label("Mật khẩu: %s" % ("có" if str(room["password"]) != "" else "không"), SocialUi.LABEL_BLUE, 14,
			HORIZONTAL_ALIGNMENT_CENTER))
	var hint := SocialUi.label("Gửi ID phòng cho bạn bè để họ tìm và vào đấu. Đang chờ đối thủ…", SocialUi.MUTED, 13,
			HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)
	_timer_label = SocialUi.label("", SocialUi.GOLD, 18, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_timer_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	var cancel := SocialUi.stone_button("Huỷ phòng", Vector2(180, 44))
	cancel.pressed.connect(func() -> void:
		PkLobby.close(str(_room["id"]))
		_room = {}
		_show_lobby())
	row.add_child(cancel)

# ---------------------------------------------------------------- tự tìm đối thủ

func _start_search() -> void:
	var reason := PkRules.check_entry(_profile, _mode)
	if reason != "":
		_flash(reason)
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

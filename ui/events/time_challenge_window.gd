extends SocialWindow
class_name TimeChallengeWindow

const TimeChallengeLobby = preload("res://systems/challenge/time_challenge_lobby.gd")
const TimeChallengeScript = preload("res://systems/challenge/time_challenge.gd")
## CỬA SỔ TỔ ĐỘI VƯỢT ẢI THÁCH THỨC THỜI GIAN (28 Ải — Độc Cô Quỷ Kiếm)
##   - Hỗ trợ tổ đội tối đa 8 người chơi cùng vượt ải map 480.
##   - Thiết kế chuẩn giống bên PK: Có danh sách tất cả các phòng & phòng chờ chi tiết.
##   - Quản lý sẵn sàng nghiêm ngặt: Toàn bộ thành viên sẵn sàng thì chủ phòng mới được bắt đầu.
##   - Hỗ trợ thêm Bot hiệp khách trợ thủ để trải nghiệm tổ đội đầy đủ ngay cả khi chơi một mình.

enum View { LOBBY, ROOM }

var _profile: PlayerProfile
var _on_play: Callable
var _view: View = View.LOBBY
var _current_room_id := ""
var _content_box: VBoxContainer
var _search_edit: LineEdit
var _state_filter: String = ""

static func open(host: Node, profile: PlayerProfile, on_play: Callable) -> TimeChallengeWindow:
	var script: GDScript = load("res://ui/events/time_challenge_window.gd")
	var win: TimeChallengeWindow = script.new(profile, on_play)
	return SocialWindow.present(host, win, &"time_challenge_party") as TimeChallengeWindow

func _init(profile: PlayerProfile = null, on_play: Callable = Callable()) -> void:
	super._init("THÁCH THỨC THỜI GIAN", "Nhiếp Thí Trần: Tiếp nhận thử thách đồng đội 8 người chinh phục 28 ải", 740.0)
	_profile = profile
	_on_play = on_play
	if subtitle_label:
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
		subtitle_label.add_theme_font_size_override("font_size", 13)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 10)
	body.add_child(_content_box)

	var my_room := TimeChallengeLobby.find_own(_profile)
	if not my_room.is_empty():
		_current_room_id = str(my_room["id"])
		_view = View.ROOM
	else:
		_view = View.LOBBY

	_render()

func _render() -> void:
	for c in _content_box.get_children():
		c.queue_free()

	match _view:
		View.LOBBY:
			_render_lobby_view()
		View.ROOM:
			_render_room_view()

# ==============================================================================
# VIEW 1: SẢNH DANH SÁCH TẤT CẢ CÁC PHÒNG
# ==============================================================================
func _render_lobby_view() -> void:
	var r_rules := TimeChallengeScript.rules()

	# 1. Banner nếu đang có phòng của chính mình
	var own_room := TimeChallengeLobby.find_own(_profile)
	if not own_room.is_empty():
		var banner := GameUi.panel(GameUi.PANEL)
		banner.custom_minimum_size.y = 44
		_content_box.add_child(banner)

		var b_box := HBoxContainer.new()
		b_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b_box.offset_left = 12
		b_box.offset_right = -12
		b_box.add_theme_constant_override("separation", 10)
		banner.add_child(b_box)

		var b_tag := SocialUi.label("⚔ PHÒNG CỦA BẠN: #%s" % own_room["id"], SocialUi.GOLD, 13)
		b_box.add_child(b_tag)

		var st_txt := "● Đang chờ thành viên" if str(own_room.get("state", "")) == TimeChallengeLobby.WAITING else "⚔ Đang khiêu chiến"
		var b_info := SocialUi.label("(%d/%d thành viên · %s)" % [
			own_room.get("members", []).size(), int(own_room.get("max_members", 8)), st_txt
		], SocialUi.TEXT, 12)
		b_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_box.add_child(b_info)

		var b_rejoin := SocialUi.stone_button("Vào lại phòng", Vector2(120, 32))
		b_rejoin.pressed.connect(func() -> void:
			_current_room_id = str(own_room["id"])
			_view = View.ROOM
			_render()
		)
		b_box.add_child(b_rejoin)

		var b_close := SocialUi.small_button("Hủy phòng")
		b_close.custom_minimum_size = Vector2(80, 32)
		b_close.pressed.connect(func() -> void:
			TimeChallengeLobby.close(str(own_room["id"]))
			_current_room_id = ""
			_render()
		)
		b_box.add_child(b_close)

	# 2. Điều kiện tham gia & thông tin luật chơi
	var info_card := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(info_card)
	var ibox := VBoxContainer.new()
	ibox.add_theme_constant_override("separation", 4)
	info_card.add_child(ibox)

	var desc_lbl := SocialUi.label(
		"Tổ đội 8 Hiệp Khách cùng khiêu chiến 28 ải quái & Độc Cô Quỷ Kiếm · Máu quái scale theo quy mô tổ đội.",
		SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER
	)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ibox.add_child(desc_lbl)

	var cost_txt := TimeChallengeScript._money(int(r_rules.get("cost", 150000)))
	var entry_str := "Điều kiện: Cấp >= %d · Phí: %s lượng + 1 %s · Hôm nay: %d/%d lượt." % [
		int(r_rules.get("min_level", 80)), cost_txt, TimeChallengeScript.ENTRY_ITEM_NAME,
		TimeChallengeScript.runs_today(_profile), int(r_rules.get("runs_per_day", 2))
	]
	var entry_lbl := SocialUi.label(entry_str, SocialUi.LABEL_BLUE, 13, HORIZONTAL_ALIGNMENT_CENTER)
	ibox.add_child(entry_lbl)

	var reason := TimeChallengeScript.check_entry(_profile)
	if reason != "":
		var warn_lbl := SocialUi.label("⚠️ " + reason, SocialUi.WARN, 13, HORIZONTAL_ALIGNMENT_CENTER)
		ibox.add_child(warn_lbl)

	# 3. Thanh tìm kiếm, bộ lọc trạng thái và làm mới
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	_content_box.add_child(filter_row)

	_search_edit = SocialUi.line_edit("Tìm theo ID (#...) hoặc tên chủ phòng")
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(func(_t: String) -> void: _render_room_list_items())
	filter_row.add_child(_search_edit)

	var state_filter_btn := OptionButton.new()
	state_filter_btn.focus_mode = Control.FOCUS_NONE
	state_filter_btn.custom_minimum_size = Vector2(140, 36)
	state_filter_btn.add_item("Tất cả trạng thái", 0)
	state_filter_btn.add_item("● Đang chờ", 1)
	state_filter_btn.add_item("⚔ Đang đánh", 2)
	match _state_filter:
		TimeChallengeLobby.WAITING: state_filter_btn.selected = 1
		TimeChallengeLobby.FIGHTING: state_filter_btn.selected = 2
		_: state_filter_btn.selected = 0
	state_filter_btn.item_selected.connect(func(idx: int) -> void:
		match idx:
			1: _state_filter = TimeChallengeLobby.WAITING
			2: _state_filter = TimeChallengeLobby.FIGHTING
			_: _state_filter = ""
		_render_room_list_items()
	)
	filter_row.add_child(state_filter_btn)

	var refresh_b := SocialUi.small_button("↻")
	refresh_b.tooltip_text = "Làm mới danh sách"
	refresh_b.custom_minimum_size = Vector2(36, 36)
	refresh_b.add_theme_font_size_override("font_size", 16)
	refresh_b.pressed.connect(func() -> void: _render())
	filter_row.add_child(refresh_b)

	# 4. Hàng nút chức năng chính: Tạo phòng & Vào nhanh
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	_content_box.add_child(action_row)

	var btn_create := SocialUi.stone_button("➕ Tạo Phòng Tổ Đội", Vector2(190, 40))
	btn_create.pressed.connect(_on_create_room_pressed)
	action_row.add_child(btn_create)

	var btn_quick := SocialUi.stone_button("⚡ Vào Nhanh / Tìm Đội", Vector2(170, 40))
	btn_quick.pressed.connect(_on_quick_join_pressed)
	action_row.add_child(btn_quick)

	_content_box.add_child(SocialUi.label("Danh Sách Các Phòng Khiêu Chiến Tổ Đội 8 Người:", SocialUi.TITLE, 14))

	# 5. Danh sách các phòng (Container có thể cuộn)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.name = "RoomListBox"
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)

	_render_room_list_items()

func _render_room_list_items() -> void:
	var list_box := _content_box.find_child("RoomListBox", true, false) as VBoxContainer
	if list_box == null:
		return
	for c in list_box.get_children():
		c.queue_free()

	var all_rooms := TimeChallengeLobby.rooms(_state_filter)
	var search_text := _search_edit.text.strip_edges().to_lower() if _search_edit else ""

	var filtered: Array[Dictionary] = []
	for r in all_rooms:
		if search_text != "":
			var rid := str(r.get("id", "")).to_lower()
			var rhost := str(r.get("host", "")).to_lower()
			if not (search_text in rid or search_text in rhost):
				continue
		filtered.append(r)

	if filtered.is_empty():
		var empty_lbl := SocialUi.label("Hiện chưa có phòng nào phù hợp. Hãy bấm [➕ Tạo Phòng Tổ Đội] để khởi tạo nhóm!", SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
		empty_lbl.custom_minimum_size.y = 80
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		list_box.add_child(empty_lbl)
		return

	for r in filtered:
		var card := GameUi.panel(GameUi.SECTION)
		list_box.add_child(card)
		var cr := HBoxContainer.new()
		cr.add_theme_constant_override("separation", 12)
		card.add_child(cr)

		var r_info := VBoxContainer.new()
		r_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cr.add_child(r_info)

		var rid := str(r.get("id", ""))
		var rhost := str(r.get("host", ""))
		var rlvl: int = int(r.get("level", 90))
		var rsect := str(r.get("sect_name", "Võ Đang"))
		var is_locked: bool = str(r.get("password", "")).strip_edges() != ""
		var lock_tag := " 🔒 [Có Mật Khẩu]" if is_locked else " 🔓 [Tự Do]"
		var is_waiting := str(r.get("state", "")) == TimeChallengeLobby.WAITING
		var state_tag := "● Đang chờ" if is_waiting else "⚔ Đang đánh"
		var state_col := Color(0.35, 0.95, 0.45) if is_waiting else Color(1.0, 0.45, 0.35)

		var r_title := SocialUi.label("⚔ Phòng #%s · Chủ phòng: %s (Cấp %d - %s) %s" % [
			rid, rhost, rlvl, rsect, lock_tag
		], Color(1.0, 0.85, 0.25), 14)
		r_info.add_child(r_title)

		var members: Array = r.get("members", [])
		var mem_names: Array[String] = []
		for m in members:
			var is_rd: bool = bool(m.get("ready", false))
			var is_h: bool = bool(m.get("is_host", false))
			var tag := " [Chủ phòng]" if is_h else (" [Sẵn sàng]" if is_rd else " [Chờ]")
			mem_names.append(str(m.get("name", "")) + tag)
		var mem_lbl := SocialUi.label("Thành viên (%d/8): %s   ·   Trạng thái: %s" % [
			members.size(), ", ".join(mem_names), state_tag
		], SocialUi.MUTED, 12)
		mem_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r_info.add_child(mem_lbl)

		var btn_join := SocialUi.stone_button("Tham Gia" if is_waiting else "Đang Đánh", Vector2(110, 36))
		btn_join.disabled = not is_waiting
		btn_join.pressed.connect(func() -> void:
			if is_locked:
				SocialWindow.prompt(self, "Mật Khẩu Phòng #%s" % rid, "Nhập mật khẩu phòng:", func(pw: String) -> void:
					_try_join_room(rid, pw.strip_edges())
				, "", true)
			else:
				_try_join_room(rid, "")
		)
		cr.add_child(btn_join)

func _on_create_room_pressed() -> void:
	if _profile == null:
		return
	var reason := TimeChallengeScript.check_entry(_profile)
	if reason != "":
		SocialWindow.info(self, "Chưa Đủ Điều Kiện", reason)
		return

	SocialWindow.prompt(self, "Tạo Phòng Vượt Ải Tổ Đội", "Đặt mật khẩu phòng (để trống nếu phòng công khai):", func(pw: String) -> void:
		var room := TimeChallengeLobby.create(_profile, pw.strip_edges(), TimeChallengeLobby.MAX_MEMBERS)
		_current_room_id = str(room["id"])
		_view = View.ROOM
		_render()
	)

func _on_quick_join_pressed() -> void:
	if _profile == null:
		return
	var reason := TimeChallengeScript.check_entry(_profile)
	if reason != "":
		SocialWindow.info(self, "Chưa Đủ Điều Kiện", reason)
		return

	var m := TimeChallengeLobby.find_match(_profile)
	if m.is_empty():
		SocialWindow.ask_yes_no(self, "Không Có Phòng Trống",
			"Hiện không có phòng nào còn chỗ trống.\nBạn có muốn tự tạo một phòng mới ngay bây giờ không?",
			func(yes: bool) -> void:
				if yes:
					_on_create_room_pressed()
		)
		return

	_try_join_room(str(m["id"]), "")

func _try_join_room(room_id: String, password: String) -> void:
	var res := TimeChallengeLobby.join(room_id, _profile, password)
	if not res.get("ok", false):
		SocialWindow.info(self, "Không Thể Tham Gia", str(res.get("msg", "Gia nhập thất bại!")))
		return
	_current_room_id = room_id
	_view = View.ROOM
	_render()

# ==============================================================================
# VIEW 2: PHÒNG CHỜ TỔ ĐỘI 8 NGƯỜI
# ==============================================================================
func _render_room_view() -> void:
	var room := TimeChallengeLobby.find(_current_room_id)
	if room.is_empty():
		_current_room_id = ""
		_view = View.LOBBY
		_render()
		return

	var my_name := _profile.display_name if _profile else ""
	var is_member := false
	for m in room.get("members", []):
		if str(m.get("name", "")) == my_name:
			is_member = true
			break
	if not is_member:
		_current_room_id = ""
		_view = View.LOBBY
		SocialWindow.info(self, "Thông Báo", "Bạn đã rời khỏi hoặc bị chủ phòng kích ra khỏi phòng!")
		_render()
		return

	var is_host := (str(room.get("host", "")) == my_name)

	# 1. Thanh điều hướng trên cùng
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	_content_box.add_child(top_bar)

	var btn_back := SocialUi.small_button("← Danh Sách Phòng")
	btn_back.custom_minimum_size = Vector2(150, 32)
	btn_back.pressed.connect(func() -> void:
		_view = View.LOBBY
		_render()
	)
	top_bar.add_child(btn_back)

	var room_title := SocialUi.label("⚔ PHÒNG CHỜ TỔ ĐỘI #%s [Tối đa 8 người]" % room["id"], SocialUi.TITLE, 18, HORIZONTAL_ALIGNMENT_CENTER)
	room_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(room_title)

	var btn_leave := SocialUi.small_button("Hủy Phòng" if is_host else "Rời Phòng")
	btn_leave.custom_minimum_size = Vector2(110, 32)
	btn_leave.pressed.connect(func() -> void:
		TimeChallengeLobby.leave(_current_room_id, _profile)
		_current_room_id = ""
		_view = View.LOBBY
		_render()
	)
	top_bar.add_child(btn_leave)

	# 2. Panel thông tin phòng & mật khẩu
	var info_panel := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(info_panel)
	var ib := HBoxContainer.new()
	ib.alignment = BoxContainer.ALIGNMENT_CENTER
	ib.add_theme_constant_override("separation", 20)
	info_panel.add_child(ib)

	ib.add_child(SocialUi.label("👑 Chủ phòng: %s" % room["host"], Color(1.0, 0.85, 0.25), 13))
	ib.add_child(SocialUi.label("🗺️ Bản đồ: Thách Thức Thời Gian (28 Ải)", Color(0.4, 0.85, 1.0), 13))

	var pw: String = str(room.get("password", "")).strip_edges()
	if pw != "":
		ib.add_child(SocialUi.label("🔒 Mật khẩu: %s" % pw, Color(1.0, 0.85, 0.3), 13))
		if is_host:
			var btn_clear_pw := SocialUi.small_button("🔓 Bỏ MK")
			btn_clear_pw.pressed.connect(func() -> void:
				TimeChallengeLobby.set_password(_current_room_id, _profile, "")
				_render()
			)
			ib.add_child(btn_clear_pw)
	else:
		ib.add_child(SocialUi.label("🔓 Công khai (Không MK)", SocialUi.MUTED, 13))
		if is_host:
			var btn_set_pw := SocialUi.small_button("🔒 Đặt MK")
			btn_set_pw.pressed.connect(func() -> void:
				SocialWindow.prompt(self, "Đặt Mật Khẩu Phòng", "Nhập mật khẩu mới:", func(new_pw: String) -> void:
					if new_pw.strip_edges() != "":
						TimeChallengeLobby.set_password(_current_room_id, _profile, new_pw.strip_edges())
						_render()
				)
			)
			ib.add_child(btn_set_pw)

	# 3. Lưới hiển thị 8 Slot thành viên (Grid 2 cột x 4 dòng)
	_content_box.add_child(SocialUi.label("Đội Hình Tổ Đội (Tối đa 8 Hiệp Khách):", SocialUi.TITLE, 14))

	var scroll_slots := ScrollContainer.new()
	scroll_slots.custom_minimum_size = Vector2(700, 240)
	_content_box.add_child(scroll_slots)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	scroll_slots.add_child(grid)

	var members: Array = room.get("members", [])
	for i in TimeChallengeLobby.MAX_MEMBERS:
		var slot_card := GameUi.panel(GameUi.SECTION)
		slot_card.custom_minimum_size = Vector2(340, 52)
		grid.add_child(slot_card)

		var sr := HBoxContainer.new()
		sr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sr.offset_left = 8
		sr.offset_right = -8
		sr.offset_top = 4
		sr.offset_bottom = -4
		sr.add_theme_constant_override("separation", 8)
		slot_card.add_child(sr)

		if i < members.size():
			var m_data: Dictionary = members[i]
			var m_name := str(m_data.get("name", ""))
			var m_lvl: int = int(m_data.get("level", 90))
			var m_sect := str(m_data.get("sect_name", "Võ Đang"))
			var m_is_host: bool = bool(m_data.get("is_host", false))
			var m_ready: bool = bool(m_data.get("ready", false))
			var m_is_bot: bool = bool(m_data.get("is_bot", false))

			var icon_tag := "👑 " if m_is_host else ("🤖 " if m_is_bot else "👤 ")
			var info_col := VBoxContainer.new()
			info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_col.alignment = BoxContainer.ALIGNMENT_CENTER
			info_col.add_theme_constant_override("separation", 2)
			sr.add_child(info_col)

			var name_lbl := SocialUi.label("%s%s" % [icon_tag, m_name],
				Color(1.0, 0.9, 0.5) if m_is_host else SocialUi.TEXT, 13)
			info_col.add_child(name_lbl)

			var sub_lbl := SocialUi.label("Cấp %d - %s" % [m_lvl, m_sect], SocialUi.SUBTITLE, 11)
			info_col.add_child(sub_lbl)

			if m_is_host:
				var host_tag := SocialUi.label("👑 CHỦ PHÒNG", Color(1.0, 0.85, 0.25), 12)
				host_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				sr.add_child(host_tag)
			elif m_ready:
				var rd_tag := SocialUi.label("✅ SẴN SÀNG", Color(0.35, 0.95, 0.45), 12)
				rd_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				sr.add_child(rd_tag)
			else:
				var not_rd_tag := SocialUi.label("⏳ CHƯA SẴN SÀNG", Color(1.0, 0.45, 0.35), 12)
				not_rd_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				sr.add_child(not_rd_tag)

			# Nút sẵn sàng cho bản thân
			if not m_is_host and m_name == my_name:
				var btn_toggle := SocialUi.stone_button("Hủy Sẵn Sàng" if m_ready else "Sẵn Sàng", Vector2(100, 28))
				btn_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				btn_toggle.pressed.connect(func() -> void:
					TimeChallengeLobby.toggle_ready(_current_room_id, m_name)
					_render()
				)
				sr.add_child(btn_toggle)
			elif is_host and not m_is_host:
				var btn_kick := SocialUi.small_button("❌")
				btn_kick.tooltip_text = "Kích khỏi phòng"
				btn_kick.custom_minimum_size = Vector2(28, 28)
				btn_kick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var kick_name := m_name
				btn_kick.pressed.connect(func() -> void:
					SocialWindow.ask_yes_no(self, "Kích Khỏi Phòng", "Bạn có chắc muốn kích '%s' khỏi phòng không?" % kick_name, func(yes: bool) -> void:
						if yes:
							TimeChallengeLobby.kick(_current_room_id, kick_name, _profile)
							_render()
					)
				)
				sr.add_child(btn_kick)
		else:
			# Slot trống
			var empty_txt := SocialUi.label("Vị trí %d: (Còn trống...)" % (i + 1), SocialUi.MUTED, 12)
			empty_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sr.add_child(empty_txt)

			if is_host and GameModeManager.can_add_bot():
				var btn_add_bot := SocialUi.small_button("➕ Thêm Bot")
				btn_add_bot.custom_minimum_size = Vector2(85, 28)
				btn_add_bot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				btn_add_bot.pressed.connect(func() -> void:
					TimeChallengeLobby.add_bot(_current_room_id, _profile.level if _profile else 90)
					_render()
				)
				sr.add_child(btn_add_bot)

	# 4. Tiện ích cho chủ phòng (Điền Bot / Xóa Bot - chỉ cho Offline)
	if is_host and GameModeManager.can_add_bot():
		var bot_row := HBoxContainer.new()
		bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bot_row.add_theme_constant_override("separation", 10)
		_content_box.add_child(bot_row)

		var btn_fill_bots := SocialUi.stone_button("⚡ Đầy Đội 8 Người (Điền Bot)", Vector2(230, 36))
		btn_fill_bots.tooltip_text = "Tự động thêm bot vào các slot trống để đủ 8 người ngay lập tức"
		btn_fill_bots.pressed.connect(func() -> void:
			TimeChallengeLobby.fill_bots(_current_room_id, _profile.level if _profile else 90)
			_render()
		)
		bot_row.add_child(btn_fill_bots)

		var btn_clear_bots := SocialUi.small_button("Xóa Hết Bot")
		btn_clear_bots.custom_minimum_size = Vector2(100, 36)
		btn_clear_bots.pressed.connect(func() -> void:
			while TimeChallengeLobby.remove_bot(_current_room_id):
				pass
			_render()
		)
		bot_row.add_child(btn_clear_bots)

	# 5. Thanh trạng thái Sẵn sàng và Nút Khai chiến
	var all_ready: bool = TimeChallengeLobby.is_all_ready(room)

	var action_box := VBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 6)
	_content_box.add_child(action_box)

	var hint_text := ""
	var hint_col := Color.WHITE
	if not all_ready:
		hint_text = "⚠️ Chờ thành viên trong tổ đội bấm [Sẵn Sàng]! Tất cả sẵn sàng hết chủ phòng mới có thể bắt đầu."
		hint_col = Color(1.0, 0.45, 0.35)
	else:
		hint_text = "✨ Toàn bộ tổ đội %d/8 người đã sẵn sàng! Chủ phòng hãy bấm nút bên dưới để khai chiến!" % members.size()
		hint_col = Color(0.35, 0.95, 0.45)

	var hint_lbl := SocialUi.label(hint_text, hint_col, 13, HORIZONTAL_ALIGNMENT_CENTER)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_box.add_child(hint_lbl)

	var enter_btn := SocialUi.stone_button("⚔️ TIẾN VÀO VƯỢT ẢI (KHAI CHIẾN TỔ ĐỘI)", Vector2(380, 46))
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter_btn.add_theme_font_size_override("font_size", 15)
	enter_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))

	var can_enter := is_host and all_ready and (TimeChallengeScript.check_entry(_profile) == "")
	enter_btn.disabled = not can_enter
	enter_btn.pressed.connect(_on_start_challenge_pressed)
	action_box.add_child(enter_btn)

func _on_start_challenge_pressed() -> void:
	var room := TimeChallengeLobby.find(_current_room_id)
	if room.is_empty():
		return

	var reason := TimeChallengeScript.check_entry(_profile)
	if reason != "":
		SocialWindow.info(self, "Chưa Đủ Điều Kiện", reason)
		return

	if not TimeChallengeScript.pay_entry(_profile):
		SocialWindow.info(self, "Lỗi", "Thanh toán lệ phí tham gia vượt ải thất bại!")
		return

	TimeChallengeLobby.set_fighting(_current_room_id)

	var entry := TimeChallengeScript.map_entry()
	entry["team_challenge"] = true
	entry["room_id"] = str(room["id"])
	entry["team_members"] = room.get("members", [])

	close_requested.emit()

	if _on_play.is_valid():
		_on_play.call(entry)
	else:
		var loop := Engine.get_main_loop() as SceneTree
		if loop and loop.root:
			var gm: Node = loop.root.get_node_or_null("GameManager")
			if gm:
				gm.set("field_map", entry)
		get_tree().change_scene_to_file("res://Main.tscn")

extends SocialWindow
class_name TeamWindow
## LẬP NHÓM (tổ đội) — bố cục như màn "Lập nhóm" của VLTK gốc: bên trái "Nhóm của mình", giữa cột nút [Mời nhóm] [Trục xuất] [..] [Cập nhật]
## [Rời nhóm], bên phải "Người chơi" (người quanh đây + người xin vào đội); dưới là "Tài lãnh đạo" (cấp lãnh đạo), ô "Tìm kiếm", và hàng
## [Lập nhóm ■] [Đóng]. Luật: TeamService (KPlayerTeam/KTeam gốc).

var _hub: SocialHub
var _team: TeamService
var _profile: PlayerProfile
var _members_list: ItemList
var _players_list: ItemList
var _search: LineEdit
var _lead_row: HBoxContainer
var _info_row: HBoxContainer
var _invite_btn: Button
var _kick_btn: Button
var _toggle_btn: Button
var _refresh_btn: Button
var _leave_btn: Button
var _view_btn: Button
var _create_btn: Button
var _create_light: ColorRect
var _pick: OptionButton
var _msg: PanelContainer

static func open(host: Node, hub: SocialHub) -> TeamWindow:
	return SocialWindow.present(host, TeamWindow.new(hub), &"team") as TeamWindow

func _init(hub: SocialHub = null) -> void:
	super._init("Lập Nhóm", "", 640.0)
	_hub = hub
	if _hub == null:
		return
	_team = _hub.team
	_profile = _hub.profile

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	body.add_child(cols)
	var left := SocialUi.section("Nhóm của mình")
	_members_list = SocialUi.item_list(Vector2(210, 230))
	left[1].add_child(_members_list)
	left[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left[0])

	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	_invite_btn = SocialUi.stone_button("Mời nhóm", Vector2(110, 38))
	_kick_btn = SocialUi.stone_button("Trục xuất", Vector2(110, 38))
	_toggle_btn = SocialUi.stone_button("Đóng nhóm", Vector2(110, 38))
	_refresh_btn = SocialUi.stone_button("Cập nhật", Vector2(110, 38))
	_leave_btn = SocialUi.stone_button("Rời nhóm", Vector2(110, 38))
	_view_btn = SocialUi.stone_button("Xem trang bị", Vector2(110, 38))
	for b in [_invite_btn, _kick_btn, _toggle_btn, _view_btn, _refresh_btn, _leave_btn]:
		mid.add_child(b)
	cols.add_child(mid)

	var right := SocialUi.info_box("Người chơi")
	_players_list = SocialUi.item_list(Vector2(210, 230))
	right[1].add_child(_players_list)
	right[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right[0])

	## Dòng dưới: Tài lãnh đạo | Tìm kiếm
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_lead_row = SocialUi.kv("Tài lãnh đạo", "", SocialUi.LABEL_BLUE, SocialUi.GOLD)
	row.add_child(_lead_row)
	row.add_child(SocialUi.label("Tìm kiếm", SocialUi.LABEL_BLUE, 14))
	_search = SocialUi.line_edit("tên người chơi")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_search)
	body.add_child(row)

	## Dòng thông tin nhóm + cách nhặt đồ
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	_info_row = SocialUi.kv("Nhóm:", "", SocialUi.LABEL_GREEN)
	info_row.add_child(_info_row)
	info_row.add_child(SocialUi.label("Nhặt đồ:", SocialUi.LABEL_BLUE, 14))
	_pick = OptionButton.new()
	for i in TeamService.PICK_NAMES.size():
		_pick.add_item(TeamService.PICK_NAMES[i], i)
	info_row.add_child(_pick)
	body.add_child(info_row)

	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)

	## Thanh dưới: [Lập nhóm ■] [Đóng]
	var buttons := add_button_row()
	_create_btn = SocialUi.stone_button("Lập nhóm")
	_create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_light = SocialUi.indicator(false)
	var cb_row := HBoxContainer.new()
	cb_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_row.add_theme_constant_override("separation", 6)
	cb_row.add_child(_create_btn)
	cb_row.add_child(_create_light)
	buttons.add_child(cb_row)
	var close := SocialUi.stone_button("Đóng")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(close)

	_invite_btn.pressed.connect(_on_invite)
	_kick_btn.pressed.connect(_on_kick)
	_toggle_btn.pressed.connect(func() -> void: _team.set_open(not _team.open))
	_refresh_btn.pressed.connect(_on_refresh)
	_leave_btn.pressed.connect(func() -> void: _team.leave())
	_view_btn.pressed.connect(_on_view_equip)
	_create_btn.pressed.connect(func() -> void: _team.create_team())
	_pick.item_selected.connect(func(idx: int) -> void: _team.set_pick_mode(idx))
	_search.text_changed.connect(func(_t: String) -> void: _fill_players())
	close.pressed.connect(func() -> void: close_requested.emit())
	_members_list.item_selected.connect(func(_i: int) -> void: _update_buttons())
	_players_list.item_selected.connect(func(_i: int) -> void: _update_buttons())
	_team.changed.connect(_rebuild)
	_team.message.connect(_on_message)
	_rebuild()

func _exit_tree() -> void:
	if _team != null:
		if _team.changed.is_connected(_rebuild):
			_team.changed.disconnect(_rebuild)
		if _team.message.is_connected(_on_message):
			_team.message.disconnect(_on_message)

func _on_message(text: String, good: bool) -> void:
	SocialUi.set_banner(_msg, text, good)
	_msg.visible = true

# ------------------------------------------------------------------ dữ liệu hai danh sách
func _selected_member() -> TeamService.Member:
	var sel := _members_list.get_selected_items()
	return _members_list.get_item_metadata(sel[0]) if not sel.is_empty() else null

func _selected_player() -> Variant:
	var sel := _players_list.get_selected_items()
	return _players_list.get_item_metadata(sel[0]) if not sel.is_empty() else null

func _rebuild() -> void:
	if _members_list == null:
		return
	_members_list.clear()
	for m in _team.all_members():
		var tag := "★ " if m == _team.captain else "   "
		var idx := _members_list.add_item("%s%s%s  (Cấp %d)" % [tag, m.name, " (bạn)" if m.is_local else "", m.level])
		_members_list.set_item_metadata(idx, m)
		if m == _team.captain:
			_members_list.set_item_custom_fg_color(idx, SocialUi.GOLD)
	_fill_players()
	SocialUi.set_kv(_lead_row, "%d   (%d / %d)" % [_profile.lead_level, _profile.lead_exp, SocialRules.lead_exp_to_next(_profile.lead_level)], SocialUi.GOLD)
	if _team.in_team():
		SocialUi.set_kv(_info_row, "%d / %d người — %s" % [_team.total(), _team.capacity(), "đang mở" if _team.open else "đã đóng"], SocialUi.TEXT)
	else:
		SocialUi.set_kv(_info_row, "chưa có (tối đa %d người theo cấp lãnh đạo)" % SocialRules.team_size(_profile.lead_level), SocialUi.MUTED)
	_pick.select(_team.pick_mode)
	_pick.disabled = not _team.is_captain()
	SocialUi.set_indicator(_create_light, _team.in_team())
	_create_btn.disabled = _team.in_team()
	_toggle_btn.text = "Đóng nhóm" if _team.open else "Mở nhóm"
	_update_buttons()

func _fill_players() -> void:
	_players_list.clear()
	var filter := _search.text.strip_edges().to_lower() if _search != null else ""
	## Người xin vào đội (chỉ đội trưởng thấy) hiện trước.
	for m in _team.applicants:
		if filter != "" and not m.name.to_lower().contains(filter):
			continue
		var idx := _players_list.add_item("[xin vào] %s  (Cấp %d)" % [m.name, m.level])
		_players_list.set_item_metadata(idx, m)
		_players_list.set_item_custom_fg_color(idx, SocialUi.WARN)
	for m in SocialDirectory.players(_profile):
		if m.team_tag != "" and not (_team.in_team() and _team.captain != null and _team.captain.mock == m):
			continue
		if _team.applicants.has(m) or (filter != "" and not m.name.to_lower().contains(filter)):
			continue
		var idx2 := _players_list.add_item("%s  (Cấp %d · %s)" % [m.name, m.level, m.sect_name])
		_players_list.set_item_metadata(idx2, m)
		_players_list.set_item_custom_fg_color(idx2, Camp.get_color(m.camp))

func _update_buttons() -> void:
	var sel_player: Variant = _selected_player()
	var sel_member := _selected_member()
	var applicant_selected: bool = sel_player is MockPlayer and _team.applicants.has(sel_player)
	## "Mời nhóm": đội trưởng mời người đang chọn (hoặc nhận người xin vào); chưa có đội thì xin vào đội của người đó.
	_invite_btn.disabled = sel_player == null or (_team.in_team() and not _team.is_captain())
	_invite_btn.text = "Nhận vào" if applicant_selected else ("Xin vào" if not _team.in_team() else "Mời nhóm")
	_kick_btn.disabled = not (_team.is_captain() and (sel_member != null and sel_member != _team.captain or applicant_selected))
	_kick_btn.text = "Từ chối" if applicant_selected else "Trục xuất"
	_toggle_btn.disabled = not _team.is_captain()
	_leave_btn.disabled = not _team.in_team()
	_view_btn.disabled = sel_player == null and (sel_member == null or sel_member.mock == null)

func _on_invite() -> void:
	var target: Variant = _selected_player()
	if not (target is MockPlayer):
		return
	if _team.applicants.has(target):
		_team.accept_applicant(target)
	elif _team.in_team():
		_team.invite(target)
	else:
		_team.apply_to(target)

func _on_kick() -> void:
	var target: Variant = _selected_player()
	if target is MockPlayer and _team.applicants.has(target):
		_team.reject_applicant(target)
		return
	var member := _selected_member()
	if member != null:
		_team.kick(member)

## "Xem trang bị": người đang chọn ở danh sách người chơi, hoặc đồng đội đang chọn.
func _on_view_equip() -> void:
	var target: MockPlayer = null
	var sel_player: Variant = _selected_player()
	if sel_player is MockPlayer:
		target = sel_player
	else:
		var m := _selected_member()
		if m != null:
			target = m.mock
	var err := []
	if target == null or ViewEquipWindow.open_for(get_tree().current_scene, _profile, target, err) == null:
		SocialUi.set_banner(_msg, str(err[0]) if not err.is_empty() else "Hãy chọn một người chơi.", false)
		_msg.visible = true

## "Cập nhật": làm mới danh sách (và cho người chơi giả có cơ hội xin vào đội).
func _on_refresh() -> void:
	_team.simulate_applicants()
	_rebuild()

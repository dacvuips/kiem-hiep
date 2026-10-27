extends SocialWindow
class_name PkStakeWindow

const PkStakeSession = preload("res://systems/pk/pk_stake_session.gd")
## CỬA SỔ ĐẶT CƯỢC THÁCH ĐẤU — Cho phép đặt Vật Phẩm, Tiền Lượng, Xu, KNB vào khung cược.
## Cả 2 bên xác nhận KHOÁ cược. Bên thắng trận thách đấu sẽ nhận toàn bộ tài sản cược của cả 2 bên!

var _session: PkStakeSession
var _profile: PlayerProfile
var _room: Dictionary
var _local_team: String = "a" ## "a" hoặc "b"
var _cell := 37

var _side_a_view: ItemRoomView
var _side_b_view: ItemRoomView
var _bag_view: ItemRoomView
var _bag := 0
var _bag_tabs: Array[Button] = []

var _a_money_btn: Button
var _a_xu_btn: Button
var _a_jade_btn: Button
var _a_lock_btn: Button
var _a_lock_light: ColorRect
var _a_name_label: Label

var _b_money_btn: Button
var _b_xu_btn: Button
var _b_jade_btn: Button
var _b_lock_btn: Button
var _b_lock_light: ColorRect
var _b_name_label: Label

var _my_gold_lbl: Label
var _my_xu_lbl: Label
var _my_jade_lbl: Label

var _status_lbl: Label
var _msg_banner: PanelContainer

static func open(host: Node, session: PkStakeSession, profile: PlayerProfile, room: Dictionary, local_team: String = "a") -> PkStakeWindow:
	var win := PkStakeWindow.new(session, profile, room, local_team)
	return SocialWindow.present(host, win, &"pk_stake") as PkStakeWindow

func _init(session: PkStakeSession = null, profile: PlayerProfile = null, room: Dictionary = {}, local_team: String = "a") -> void:
	super._init("ĐẶT CƯỢC THÁCH ĐẤU", "Vật phẩm, Lượng, Xu, KNB sẽ được trao trọn vẹn cho trưởng nhóm bên THẮNG", 940.0)
	_session = session
	_profile = profile
	_room = room
	_local_team = local_team

	if _session == null:
		return

	_session.changed.connect(_refresh)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)

	# ================= CỘT 1: PHE XANH (TEAM A) =================
	var col_a := _build_team_wager_column("a", "🛡️ Phe Xanh", Color(0.25, 0.70, 1.0), Color(0.06, 0.08, 0.14, 0.9))
	cols.add_child(col_a)

	# ================= CỘT 2: PHE ĐỎ (TEAM B) =================
	var col_b := _build_team_wager_column("b", "⚔️ Phe Đỏ", Color(1.0, 0.40, 0.40), Color(0.14, 0.06, 0.06, 0.9))
	cols.add_child(col_b)

	# ================= CỘT 3: HÀNH TRANG BẢN THÂN =================
	var col_bag := _build_bag_column()
	cols.add_child(col_bag)

	# ================= DÒNG THÔNG BÁO & NÚT ĐÓNG =================
	_msg_banner = SocialUi.banner("", true)
	_msg_banner.visible = false
	body.add_child(_msg_banner)

	var bottom_row := add_button_row()
	_status_lbl = SocialUi.label("Hãy đặt tiền, xu, KNB và vật phẩm muốn cược, sau đó bấm [Khoá Cược] để chốt.", SocialUi.GOLD, 13, HORIZONTAL_ALIGNMENT_CENTER)
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(_status_lbl)

	var close_btn := SocialUi.stone_button("Xong & Trở Về Phòng", Vector2(160, 36))
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	bottom_row.add_child(close_btn)

	_setup_interactions()
	_refresh()

func _build_team_wager_column(team_code: String, title: String, head_color: Color, bg_color: Color) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(250, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)

	var head_lbl := SocialUi.label(title, head_color, 15, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(head_lbl)

	var name_lbl := SocialUi.label("Trưởng nhóm: --", SocialUi.SUBTITLE, 12, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(name_lbl)
	if team_code == "a":
		_a_name_label = name_lbl
	else:
		_b_name_label = name_lbl

	var frame := PanelContainer.new()
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = bg_color
	frame_sb.border_color = head_color
	frame_sb.set_border_width_all(1)
	frame_sb.set_corner_radius_all(6)
	frame_sb.content_margin_left = 6
	frame_sb.content_margin_right = 6
	frame_sb.content_margin_top = 6
	frame_sb.content_margin_bottom = 6
	frame.add_theme_stylebox_override("panel", frame_sb)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	frame.add_child(inner)

	var item_view := ItemRoomView.new()
	item_view.cell = _cell
	item_view.custom_minimum_size = Vector2(PkStakeSession.ROOM_WIDTH * _cell, PkStakeSession.ROOM_HEIGHT * _cell)
	inner.add_child(item_view)

	if team_code == "a":
		_side_a_view = item_view
	else:
		_side_b_view = item_view

	# Hàng Tiền Lượng
	var gold_btn := GameUi.button("0 lượng", GameUi.BUTTON)
	gold_btn.add_theme_color_override("font_color", GameUi.LABEL_GREEN)
	gold_btn.custom_minimum_size = Vector2(0, 26)
	inner.add_child(gold_btn)

	# Hàng Xu
	var xu_btn := GameUi.button("0 Xu", GameUi.BUTTON)
	xu_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	xu_btn.custom_minimum_size = Vector2(0, 26)
	inner.add_child(xu_btn)

	# Hàng KNB
	var jade_btn := GameUi.button("0 KNB", GameUi.BUTTON)
	jade_btn.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	jade_btn.custom_minimum_size = Vector2(0, 26)
	inner.add_child(jade_btn)

	# Hàng Nút Khoá & Đèn
	var lock_row := HBoxContainer.new()
	lock_row.add_theme_constant_override("separation", 6)
	var lock_btn := SocialUi.stone_button("Khoá Cược")
	lock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lock_light := SocialUi.indicator(false)
	lock_row.add_child(lock_btn)
	lock_row.add_child(lock_light)
	inner.add_child(lock_row)

	if team_code == "a":
		_a_money_btn = gold_btn
		_a_xu_btn = xu_btn
		_a_jade_btn = jade_btn
		_a_lock_btn = lock_btn
		_a_lock_light = lock_light
	else:
		_b_money_btn = gold_btn
		_b_xu_btn = xu_btn
		_b_jade_btn = jade_btn
		_b_lock_btn = lock_btn
		_b_lock_light = lock_light

	col.add_child(frame)
	return col

func _build_bag_column() -> Control:
	var bag_section := SocialUi.section("Hành trang của tôi — Bấm món đồ để cược")
	var col: Control = bag_section[0]
	var inner: Control = bag_section[1]
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	inner.add_child(tabs)
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
	scroll.custom_minimum_size = Vector2(PlayerProfile.ROOM_WIDTH * _cell + 8, PkStakeSession.ROOM_HEIGHT * _cell + 10)
	_bag_view = ItemRoomView.new()
	_bag_view.cell = _cell
	scroll.add_child(_bag_view)
	inner.add_child(scroll)

	# Số dư của nhân vật
	var balance_box := VBoxContainer.new()
	balance_box.add_theme_constant_override("separation", 2)
	_my_gold_lbl = SocialUi.label("Tiền: 0 lượng", GameUi.LABEL_GREEN, 12)
	_my_xu_lbl = SocialUi.label("Xu: 0", Color(1.0, 0.85, 0.3), 12)
	_my_jade_lbl = SocialUi.label("KNB: 0", Color(0.4, 0.85, 1.0), 12)
	balance_box.add_child(_my_gold_lbl)
	balance_box.add_child(_my_xu_lbl)
	balance_box.add_child(_my_jade_lbl)
	inner.add_child(balance_box)

	return col

func _setup_interactions() -> void:
	# Click từ hành trang -> Đưa vào cược phe mình
	_bag_view.item_pressed.connect(func(item: ItemInstance) -> void:
		_say(_session.offer_item(_local_team, item, _profile))
	)

	# Click từ khung cược Phe Xanh -> Lấy lại
	_side_a_view.item_pressed.connect(func(item: ItemInstance) -> void:
		if _local_team == "a":
			_say(_session.take_back_item("a", item, _profile))
	)

	# Click từ khung cược Phe Đỏ -> Lấy lại
	_side_b_view.item_pressed.connect(func(item: ItemInstance) -> void:
		if _local_team == "b":
			_say(_session.take_back_item("b", item, _profile))
	)

	# Các nút nhập tiền Phe Xanh
	_a_money_btn.pressed.connect(func() -> void: _prompt_money("a"))
	_a_xu_btn.pressed.connect(func() -> void: _prompt_xu("a"))
	_a_jade_btn.pressed.connect(func() -> void: _prompt_jade("a"))
	_a_lock_btn.pressed.connect(func() -> void: _say(_session.toggle_lock("a")))

	# Các nút nhập tiền Phe Đỏ
	_b_money_btn.pressed.connect(func() -> void: _prompt_money("b"))
	_b_xu_btn.pressed.connect(func() -> void: _prompt_xu("b"))
	_b_jade_btn.pressed.connect(func() -> void: _prompt_jade("b"))
	_b_lock_btn.pressed.connect(func() -> void: _say(_session.toggle_lock("b")))

func _prompt_money(team_code: String) -> void:
	if team_code != _local_team:
		_say("Bạn không phải trưởng nhóm của phe này.")
		return
	if _session.get_side(team_code).locked:
		_say("Phe bạn đã khoá cược, hãy mở khoá để chỉnh sửa.")
		return
	var max_val := _profile.gold if _profile else 0
	SocialWindow.prompt(get_tree().current_scene, "Đặt Tiền Lượng Cược", "Nhập số lượng (0 – %s)" % InventoryPopup.format_money(max_val),
		func(text: String) -> void:
			var val := clampi(int(text.strip_edges()) if text.strip_edges().is_valid_int() else 0, 0, max_val)
			_say(_session.set_gold(team_code, val, _profile)),
		str(_session.get_side(team_code).gold), false, max_val
	)

func _prompt_xu(team_code: String) -> void:
	if team_code != _local_team:
		_say("Bạn không phải trưởng nhóm của phe này.")
		return
	if _session.get_side(team_code).locked:
		_say("Phe bạn đã khoá cược, hãy mở khoá để chỉnh sửa.")
		return
	var max_val := _profile.xu if _profile else 0
	SocialWindow.prompt(get_tree().current_scene, "Đặt Tiền Xu Cược", "Nhập số Xu (0 – %d)" % max_val,
		func(text: String) -> void:
			var val := clampi(int(text.strip_edges()) if text.strip_edges().is_valid_int() else 0, 0, max_val)
			_say(_session.set_xu(team_code, val, _profile)),
		str(_session.get_side(team_code).xu), false, max_val
	)

func _prompt_jade(team_code: String) -> void:
	if team_code != _local_team:
		_say("Bạn không phải trưởng nhóm của phe này.")
		return
	if _session.get_side(team_code).locked:
		_say("Phe bạn đã khoá cược, hãy mở khoá để chỉnh sửa.")
		return
	var max_val := _profile.jade if _profile else 0
	SocialWindow.prompt(get_tree().current_scene, "Đặt KNB Cược", "Nhập số Kim Nguyên Bảo (0 – %d)" % max_val,
		func(text: String) -> void:
			var val := clampi(int(text.strip_edges()) if text.strip_edges().is_valid_int() else 0, 0, max_val)
			_say(_session.set_jade(team_code, val, _profile)),
		str(_session.get_side(team_code).jade), false, max_val
	)

func _say(msg: String) -> void:
	if msg == "":
		_msg_banner.visible = false
	else:
		SocialUi.set_banner(_msg_banner, msg, false)
		_msg_banner.visible = true

func _refresh() -> void:
	if _session == null:
		return

	var side_a := _session.side_a
	var side_b := _session.side_b

	_side_a_view.setup(side_a.room, _profile)
	_side_b_view.setup(side_b.room, _profile)

	_a_name_label.text = "Trưởng nhóm: %s" % (side_a.leader_name if side_a.leader_name != "" else "(Chưa có)")
	_b_name_label.text = "Trưởng nhóm: %s" % (side_b.leader_name if side_b.leader_name != "" else "(Chưa có)")

	_a_money_btn.text = "💰 %s lượng" % InventoryPopup.format_money(side_a.gold)
	_a_xu_btn.text = "🪙 %d Xu" % side_a.xu
	_a_jade_btn.text = "💎 %d KNB" % side_a.jade

	_b_money_btn.text = "💰 %s lượng" % InventoryPopup.format_money(side_b.gold)
	_b_xu_btn.text = "🪙 %d Xu" % side_b.xu
	_b_jade_btn.text = "💎 %d KNB" % side_b.jade

	SocialUi.set_indicator(_a_lock_light, side_a.locked)
	SocialUi.set_indicator(_b_lock_light, side_b.locked)

	_a_lock_btn.text = "Mở Khoá" if side_a.locked else "Khoá Cược"
	_b_lock_btn.text = "Mở Khoá" if side_b.locked else "Khoá Cược"

	# Quyền bấm nút: chỉ trưởng nhóm của phe đó mới được chỉnh sửa/khoá phe mình
	var can_control_a := (_local_team == "a")
	var can_control_b := (_local_team == "b")

	_a_money_btn.disabled = not can_control_a or side_a.locked
	_a_xu_btn.disabled = not can_control_a or side_a.locked
	_a_jade_btn.disabled = not can_control_a or side_a.locked
	_a_lock_btn.disabled = not can_control_a

	_b_money_btn.disabled = not can_control_b or side_b.locked
	_b_xu_btn.disabled = not can_control_b or side_b.locked
	_b_jade_btn.disabled = not can_control_b or side_b.locked
	_b_lock_btn.disabled = not can_control_b

	# Cập nhật hành trang cá nhân
	_bag_view.bag = _bag
	for i in _bag_tabs.size():
		GameUi.set_active(_bag_tabs[i], i == _bag)
	_bag_view.setup(_profile)

	if _profile:
		_my_gold_lbl.text = "Tiền lượng: %s" % InventoryPopup.format_money(_profile.gold)
		_my_xu_lbl.text = "Tiền xu: %d" % _profile.xu
		_my_jade_lbl.text = "KNB: %d" % _profile.jade

	# Cập nhật dòng trạng thái dưới cùng
	if side_a.locked and side_b.locked:
		_status_lbl.text = "✅ Cả hai phe đã KHOÁ CƯỢC thành công! Sẵn sàng khai chiến so tài!"
		_status_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	elif side_a.locked:
		_status_lbl.text = "Phe Xanh đã khoá cược. Đang chờ Phe Đỏ xác nhận khoá cược..."
		_status_lbl.add_theme_color_override("font_color", SocialUi.GOLD)
	elif side_b.locked:
		_status_lbl.text = "Phe Đỏ đã khoá cược. Đang chờ Phe Xanh xác nhận khoá cược..."
		_status_lbl.add_theme_color_override("font_color", SocialUi.GOLD)
	else:
		_status_lbl.text = "Hãy đặt tiền, xu, KNB và vật phẩm muốn cược, sau đó bấm [Khoá Cược] để chốt."
		_status_lbl.add_theme_color_override("font_color", SocialUi.GOLD)

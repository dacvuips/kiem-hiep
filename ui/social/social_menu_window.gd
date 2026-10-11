extends SocialWindow
class_name SocialMenuWindow
## MENU GIAO LƯU — cửa vào các chức năng xã hội (Tổ đội, Bang hội, Rương chứa đồ, Bày bán, Khoá bảo vệ) và danh sách "Người chơi quanh đây"
## (xem quầy / giao dịch). Mở từ nút "Giao lưu" ở màn chơi và menu "Chợ" ở Hub.

var _hub: SocialHub
var _profile: PlayerProfile
var _near_box: VBoxContainer
var _msg: PanelContainer

static func open(host: Node, profile: PlayerProfile) -> SocialMenuWindow:
	return SocialWindow.present(host, SocialMenuWindow.new(SocialHub.of(profile)), &"social_menu") as SocialMenuWindow

func _init(hub: SocialHub = null) -> void:
	super._init("Giao Lưu", "Tổ đội · Bang hội · Rương · Giao dịch · Bày bán", 520.0)
	_hub = hub
	if _hub == null:
		return
	_profile = _hub.profile
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var entries := [
		["👥 Tổ đội", func() -> void: TeamWindow.open(_host(), _hub)],
		["⚑ Bang hội", func() -> void: GuildWindow.open(_host(), _hub)],
		["🧰 Rương", func() -> void: StorageWindow.open(_host(), _profile)],
		["🏷 Bày bán", func() -> void: StallWindow.open(_host(), _hub)],
		["🔑 Khoá bảo vệ", func() -> void: SecurityWindow.open(_host(), _profile)],
	]
	for e in entries:
		var b := SocialUi.stone_button(str(e[0]), Vector2(150, 44))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(e[1])
		grid.add_child(b)
	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)
	var near := SocialUi.section("🚶 Người chơi quanh đây", SocialUi.LABEL_BLUE, SocialUi.INFO_BG)
	_near_box = near[1]
	body.add_child(near[0])
	var close := SocialUi.stone_button("Đóng")
	close.pressed.connect(func() -> void: close_requested.emit())
	body.add_child(close)
	_refresh_nearby()

func _host() -> Node:
	return get_tree().current_scene

func _say(err: String, ok_text := "") -> void:
	SocialUi.set_banner(_msg, err if err != "" else ok_text, err == "")
	_msg.visible = true

func _refresh_nearby() -> void:
	for c in _near_box.get_children():
		c.queue_free()
	for m in SocialDirectory.players(_profile):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := SocialUi.label(m.name, Camp.get_color(m.camp), 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var state := ""
		if m.stall_open:
			state = "· đang bày bán"
		elif m.trade_open:
			state = "· mở giao dịch"
		if m.guild_name != "":
			state += " · " + m.guild_name
		row.add_child(SocialUi.label("Cấp %d · %s %s" % [m.level, m.sect_name, state], SocialUi.SUBTITLE, 12))
		var eq := SocialUi.small_button("Xem trang bị")
		eq.pressed.connect(func() -> void: _view_equip(m))
		row.add_child(eq)
		if m.stall_open:
			var v := SocialUi.small_button("Xem quầy")
			v.pressed.connect(func() -> void: StallBrowseWindow.open(_host(), _hub, m))
			row.add_child(v)
		else:
			var t := SocialUi.small_button("Giao dịch")
			t.disabled = not m.trade_open
			t.pressed.connect(func() -> void: _trade(m))
			row.add_child(t)
		_near_box.add_child(row)

func _view_equip(m: MockPlayer) -> void:
	var err := []
	if ViewEquipWindow.open_for(_host(), _profile, m, err) == null:
		_say(str(err[0]))

func _trade(m: MockPlayer) -> void:
	var err := _hub.start_trade(m)
	if err == "online":
		_say("Đã gửi lời mời giao dịch tới %s — chờ đồng ý." % m.name)
		return
	if err != "":
		_say(err)
		return
	TradeWindow.open(_host(), _hub)

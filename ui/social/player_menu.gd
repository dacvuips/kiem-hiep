extends CanvasLayer
class_name PlayerMenu
## MENU NGƯỜI CHƠI — bấm vào người chơi khác trên map (PopUpContextPeopleMenu gốc). Mục nào không đủ điều kiện thì ẩn (như gốc):
##   Xem quầy (họ đang bày bán) · Tán gẫu (luôn) · Hảo hữu (chưa là bạn) · Giao dịch (họ đang mở giao dịch) · Tổ đội · Theo sau · Tin tức · Cừu sát ·
##   Sổ đen (chưa chặn) · Đóng.
## Bấm ra ngoài menu = đóng (không làm nhân vật chạy tới chỗ bấm).

const LAYER := 57
const WIDTH := 150.0

static var current: PlayerMenu

var _player: Node2D
var _target: RemotePlayer
var _panel: PanelContainer

static func open(player: Node2D, target: RemotePlayer, screen_pos: Vector2) -> PlayerMenu:
	close_current()
	if player == null or not is_instance_valid(player):
		return null
	var tree := player.get_tree() if player.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var m := PlayerMenu.new()
	m._player = player
	m._target = target
	tree.current_scene.add_child(m)
	m._build(screen_pos)
	current = m
	return m

static func close_current() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null

func _build(screen_pos: Vector2) -> void:
	add_to_group(UiPopups.GROUP)   ## đang mở thì lăn chuột không zoom camera
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	## Nền trong suốt phủ màn hình: bấm ra ngoài menu thì đóng, cú bấm không lọt xuống map.
	var back := Control.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close_current())
	add_child(back)
	_panel = GameUi.panel(GameUi.WINDOW)  # khung cửa sổ chung của game
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	box.add_child(GameUi.label(_target.display_name, GameUi.TITLE, 14, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(GameUi.label("Cấp %d" % _target.level, GameUi.MUTED, 12, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(GameUi.divider())
	for item in _items():
		var b := GameUi.button(str(item[0]), GameUi.BUTTON)
		b.custom_minimum_size = Vector2(WIDTH - 2 * GameUi.PAD_WINDOW, 32)
		var action: Callable = item[1]
		b.pressed.connect(func() -> void:
			close_current()
			action.call())
		box.add_child(b)
	## Đặt cạnh chỗ bấm, không tràn khỏi màn hình.
	_panel.reset_size()
	var view := _player.get_viewport().get_visible_rect().size
	var size := _panel.get_combined_minimum_size()
	_panel.position = Vector2(clampf(screen_pos.x + 12, 4, view.x - size.x - 4), clampf(screen_pos.y - 20, 4, view.y - size.y - 4))

func _profile() -> PlayerProfile:
	return GameManager.local_profile

func _items() -> Array:
	var p := _profile()
	var name := _target.display_name
	var eid := _target.eid
	var items := []
	items.append(["Xem thông tin", _view_info])
	items.append(["Tán gẫu", _chat])
	items.append(["Tổ đội", _team])
	if (_target.flags & NetProto.FLAG_TRADE_OPEN) != 0 or GameManager.field_map.get("guild_map", false):
		items.append(["Giao dịch", _trade])
	else:
		items.append(["Giao dịch (chưa mở)", _trade_not_open])
	items.append(["Theo sau", func() -> void:
		if is_instance_valid(_player) and is_instance_valid(_target) and _player.has_method("start_follow"):
			_player.start_follow(_target)])
	items.append(["Cừu sát", _enmity])
	if p == null or not p.blacklist.has(name):
		items.append(["Sổ đen", _blacklist])
	items.append(["Đóng", func() -> void: pass])
	return items

func _host() -> Node:
	if _player != null and is_instance_valid(_player):
		var tree := _player.get_tree() if _player.is_inside_tree() else Engine.get_main_loop() as SceneTree
		if tree != null:
			return tree.current_scene
	return null

func _notify(text: String) -> void:
	if is_instance_valid(_player) and _player.has_method("notify"):
		_player.notify(text)

func _mock() -> MockPlayer:
	return SocialDirectory.find_by_id(_profile(), _target.eid) if _profile() else null

func _view_info() -> void:
	var p := _profile()
	if p == null:
		return
	if NetClient.is_in_world():
		NetClient.send_view_equip(_target.eid)
		return
	var m := _mock()
	if m != null:
		var err := []
		ViewEquipWindow.open_for(_host(), p, m, err)
	else:
		_notify("Không tìm thấy thông tin của %s." % _target.display_name)

func _chat() -> void:
	var sync := NetWorldSync.current
	var box: ChatBox = sync.chat_box() if sync else null
	if box:
		box.open_whisper(_target.display_name)

func _trade() -> void:
	var p := _profile()
	if p == null:
		return
	var m := _mock()
	if m == null:
		return
	if not p.trade_open and not p.stall_open:
		var err_open := StallService.open_trade(p)
		if err_open == "" and NetClient.is_in_world():
			NetClient.send_stall(SocialServer.TRADE_OPEN)
	var hub := SocialHub.of(p)
	var err := hub.start_trade(m)
	if err == "online":
		_notify("Đã gửi lời mời giao dịch — hãy chờ đối phương trả lời.")
		return
	if err != "":
		_notify(err)
		return
	TradeWindow.open(_host(), hub)

func _trade_not_open() -> void:
	_notify("%s chưa bật mở giao dịch. Họ cần bấm icon Giao dịch (F4) để mở." % _target.display_name)

func _team() -> void:
	var p := _profile()
	if p == null:
		return
	var hub := SocialHub.of(p)
	if NetClient.is_in_world():
		NetClient.send_team(SocialServer.TEAM_INVITE, _target.eid)
		_notify("Đã gửi lời mời vào tổ đội tới %s." % _target.display_name)
	else:
		var m := _mock()
		if m != null:
			var err := hub.team.invite(m)
			if err != "":
				_notify(err)
				return
			_notify("Đã gửi lời mời vào tổ đội tới %s." % _target.display_name)
		else:
			_notify("Đã mời %s vào tổ đội." % _target.display_name)
	TeamWindow.open(_host(), hub)

func _enmity() -> void:
	var eid := _target.eid
	var name := _target.display_name
	SocialWindow.confirm(_host(), "Cừu sát", "Tuyên bố cừu sát %s?\nSau 10 giây hai bên có thể đánh nhau trong 10 phút. Hạ được đối phương thì trị PK của bạn tăng 2." % name,
		func() -> void: NetClient.send_enmity(eid))

func _blacklist() -> void:
	var p := _profile()
	var name := _target.display_name
	if p == null or p.blacklist.has(name):
		return
	if p.blacklist.size() >= 100:
		_notify("Sổ đen đã đầy (100 người).")
		return
	p.blacklist.append(name)
	SaveManager.save_profile(p)
	_notify("Đã thêm %s vào sổ đen — không nhận tin nhắn của người này nữa." % name)

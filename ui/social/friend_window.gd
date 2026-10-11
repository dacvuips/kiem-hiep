extends SocialWindow
class_name FriendWindow
## HẢO HỮU + SỔ ĐEN: danh sách bạn (online thì hỏi server ai đang trong game) với nút Tán gẫu / Xoá, và danh sách người bị chặn
## tin nhắn với nút Bỏ chặn. Kết bạn / chặn từ menu bấm vào người chơi (PlayerMenu).

var _profile: PlayerProfile
var _friend_box: VBoxContainer
var _black_box: VBoxContainer
var _online: Dictionary = {}   ## tên -> {online, level} (S_FRIEND_LIST)

static func open(host: Node, profile: PlayerProfile) -> FriendWindow:
	return SocialWindow.present(host, FriendWindow.new(profile), &"friends") as FriendWindow

func _init(profile: PlayerProfile = null) -> void:
	super._init("Hảo Hữu", "Bạn bè · Sổ đen", 420.0)
	_profile = profile
	if _profile == null:
		return
	var fr := SocialUi.section("🤝 Hảo hữu", SocialUi.LABEL_GREEN, SocialUi.SECTION_BG)
	_friend_box = fr[1]
	body.add_child(fr[0])
	var bl := SocialUi.section("⛔ Sổ đen (không nhận tin nhắn)", SocialUi.LABEL_RED, SocialUi.SECTION_BG)
	_black_box = bl[1]
	body.add_child(bl[0])
	var close := SocialUi.stone_button("Đóng")
	close.pressed.connect(func() -> void: close_requested.emit())
	body.add_child(close)
	NetClient.friend_list.connect(_on_list)
	_refresh()
	NetClient.send_friend(RelationServer.FRIEND_LIST)

func _exit_tree() -> void:
	if NetClient.friend_list.is_connected(_on_list):
		NetClient.friend_list.disconnect(_on_list)

func _on_list(list: Array) -> void:
	_online.clear()
	for f in list:
		if f is Dictionary:
			_online[str(f.get("name", ""))] = f
	_refresh()

func _refresh() -> void:
	for c in _friend_box.get_children():
		c.queue_free()
	for c in _black_box.get_children():
		c.queue_free()
	if _profile.friends.is_empty():
		_friend_box.add_child(SocialUi.label("Chưa có hảo hữu. Bấm vào người chơi khác → Hảo hữu để kết giao.", SocialUi.MUTED, 12))
	for n in _profile.friends:
		var name := str(n)
		var info: Dictionary = _online.get(name, {})
		var on := bool(info.get("online", false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(SocialUi.indicator(on))
		var text := name + ("  (cấp %d)" % int(info.level) if on else "  — vắng mặt")
		var l := SocialUi.label(text, SocialUi.TEXT if on else SocialUi.MUTED, 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if on:
			var chat := SocialUi.small_button("Tán gẫu")
			chat.pressed.connect(func() -> void:
				var box: ChatBox = NetWorldSync.current.chat_box() if NetWorldSync.current else null
				if box:
					box.open_whisper(name)
					close_requested.emit())
			row.add_child(chat)
		var del := SocialUi.small_button("Xoá")
		del.pressed.connect(func() -> void:
			SocialWindow.confirm(get_tree().current_scene, "Hảo hữu", "Xoá %s khỏi danh sách hảo hữu?" % name, func() -> void:
				NetClient.send_friend(RelationServer.FRIEND_REMOVE, 0, 0, name)
				_profile.friends.erase(name)
				_refresh()))
		row.add_child(del)
		_friend_box.add_child(row)
	if _profile.blacklist.is_empty():
		_black_box.add_child(SocialUi.label("Sổ đen trống.", SocialUi.MUTED, 12))
	for n in _profile.blacklist:
		var name := str(n)
		var row := HBoxContainer.new()
		var l := SocialUi.label(name, SocialUi.TEXT, 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var un := SocialUi.small_button("Bỏ chặn")
		un.pressed.connect(func() -> void:
			_profile.blacklist.erase(name)
			SaveManager.save_profile(_profile)
			_refresh())
		row.add_child(un)
		_black_box.add_child(row)

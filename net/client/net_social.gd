extends Node
class_name NetSocial
## Phần XÃ HỘI + HỒ SƠ của kết nối game server, dùng chung cho màn chơi (NetWorldSync) và sảnh Character Hub (HubSession):
##   - hồ sơ chuẩn server gửi (S_PROFILE) -> chép vào GameManager.local_profile, phát profile_applied; version lưu (S_SAVED);
##   - thông báo server (S_NOTICE) -> notify (màn chơi: chữ trên đầu nhân vật; Hub: thông báo nổi);
##   - lời mời / trạng thái giao dịch, tổ đội, bang hội, hảo hữu -> SocialHub + cửa sổ xã hội (hộp hỏi Đồng ý / Từ chối).
## Không biết gì về map / quái / người khác trên map (phần đó ở NetWorldSync).

signal profile_applied

static var current: NetSocial
## Danh sách bang (S_GUILD_LIST) — GuildListWindow đọc.
var guild_list: Array = []
## Hiện 1 dòng thông báo cho người chơi.
var notify: Callable = func(_text: String) -> void: pass

static func create(notify_func: Callable) -> NetSocial:
	var s := NetSocial.new()
	s.name = "NetSocial"
	s.notify = notify_func
	return s

func _ready() -> void:
	current = self
	ChatPanel.ensure_listening()   ## ghi lịch sử tin từ lúc nối server (khung Tán gẫu mở lúc nào cũng thấy tin gần đây)
	if not NetClient.saved.is_connected(SaveManager.set_online_version):
		NetClient.saved.connect(SaveManager.set_online_version)
	NetClient.profile_received.connect(_on_profile)
	NetClient.server_notice.connect(func(text: String) -> void: notify.call(text))
	NetClient.trade_invite.connect(_on_trade_invite)
	NetClient.trade_state.connect(_on_trade_state)
	NetClient.trade_end.connect(_on_trade_end)
	NetClient.team_state.connect(_on_team_state)
	NetClient.team_invite.connect(_on_team_invite)
	NetClient.guild_received.connect(_on_guild)
	NetClient.guild_list.connect(func(list: Array) -> void: guild_list = list)
	NetClient.guild_invite.connect(_on_guild_invite)
	NetClient.friend_invite.connect(_on_friend_invite)

func _exit_tree() -> void:
	if current == self:
		current = null

func _on_profile(data: Dictionary) -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	profile.copy_from(PlayerProfile.from_dict(data))
	profile_applied.emit()

func _hub() -> SocialHub:
	return SocialHub.of(GameManager.local_profile) if GameManager.local_profile else null

## Hộp hỏi lời mời (giao dịch / tổ đội / bang...) — khung chung của cửa sổ xã hội.
func _ask(title: String, text: String, answer: Callable) -> void:
	SocialWindow.ask_yes_no(get_tree().current_scene, title, text, answer)

func _on_trade_invite(from_eid: int, from_name: String) -> void:
	_ask("Giao dịch", "%s muốn giao dịch với bạn." % from_name, func(ok: bool) -> void:
		NetClient.send_trade_answer(from_eid, ok))

func _on_trade_state(partner_eid: int, partner_name: String, mine: Dictionary, theirs: Dictionary) -> void:
	var hub := _hub()
	if hub == null:
		return
	var t := hub.trade as NetTradeSession
	if t == null or not t.active or t.partner_eid != partner_eid:
		t = NetTradeSession.new(hub.profile, partner_eid, partner_name)
		hub.trade = t
		t.finished.connect(func(ok: bool, msg: String) -> void: hub.notice.emit(msg, ok))
		t.apply_state(mine, theirs)
		TradeWindow.open(get_tree().current_scene, hub)
		return
	t.apply_state(mine, theirs)

func _on_trade_end(success: bool, message: String) -> void:
	var hub := _hub()
	if hub and hub.trade is NetTradeSession:
		(hub.trade as NetTradeSession).end(success, message)

func _on_guild(data: Dictionary) -> void:
	var hub := _hub()
	if hub:
		hub.guild.apply_net_guild(data)

func _on_guild_invite(guild_name: String, from_name: String) -> void:
	_ask("Bang hội", "%s mời bạn vào bang %s." % [from_name, guild_name], func(ok: bool) -> void:
		NetClient.send_guild(GuildServer.G_ANSWER, {"guild": guild_name, "accept": ok}))

func _on_friend_invite(from_eid: int, from_name: String) -> void:
	var p := GameManager.local_profile
	if p and p.blacklist.has(from_name):
		NetClient.send_friend(RelationServer.FRIEND_ANSWER, from_eid, 0)   ## sổ đen: tự từ chối
		return
	_ask("Hảo hữu", "%s xin phép gia nhập bằng hữu." % from_name, func(ok: bool) -> void:
		NetClient.send_friend(RelationServer.FRIEND_ANSWER, from_eid, 1 if ok else 0))

func _on_team_state(st: Dictionary) -> void:
	var hub := _hub()
	if hub:
		hub.team.apply_net_state(st)

func _on_team_invite(captain_eid: int, captain_name: String) -> void:
	_ask("Tổ đội", "%s mời bạn vào tổ đội." % captain_name, func(ok: bool) -> void:
		NetClient.send_team(SocialServer.TEAM_ANSWER, captain_eid, 1 if ok else 0))

extends Node
class_name NetWorldSync
## Nối map MAIN_MAP với game server khi chơi online (main.gd thêm node này nếu đã đăng nhập + đã chọn nhân vật trên server):
##   - kết nối NetClient, đặt nhân vật mình ở vị trí server cấp;
##   - gửi vị trí / hướng / động tác của mình tối đa NetProto.CLIENT_SEND_RATE lần/giây (đứng yên thì 1 lần/giây);
##   - tạo / cập nhật / xóa RemotePlayer cho người chơi khác trong tầm nhìn;
##   - bị server kéo về (đi quá nhanh / xuyên vật cản) thì đặt lại vị trí.

const RECONNECT_DELAY := 5.0
## Lỗi này thì không tự kết nối lại (phải xử lý ở màn trước).
const FATAL := ["logged_in_elsewhere", "banned", "version", "unauthorized", "character_not_found", "service_key",
	"battle_end", "battle_no_side", "arena_end"]

var player: CharacterBody2D   ## player.gd (không có class_name) — gọi hàm theo kiểu động
var _remotes: Dictionary = {}     ## eid -> RemotePlayer
## Kết nối tới máy chủ game KHÁC máy chủ đã chọn (chiến trường Tống Kim: {host, port, ws_url, name}) — {} = máy chủ đã chọn.
var server_override: Dictionary = {}
var _monsters: Dictionary = {}    ## eid -> VltkMonster (chế độ online)
var _drops: Dictionary = {}       ## drop_id -> GroundDrop
var _send_timer := 0.0
var _heartbeat := 0.0
var _last_sent := {}
var _last_look := {}
var _reconnect_in := -1.0

## Đang chạy trong map (để SocialDirectory lấy người chơi thật ở gần).
static var current: NetWorldSync
## Danh sách bang trên server (S_GUILD_LIST) cho màn xin vào bang.
var guild_list: Array = []

static func is_online_mode() -> bool:
	return AccountApi.is_logged_in() and SaveManager.online_character_id != 0 and not ServerSelectScreen.selected_server.is_empty()

func _ready() -> void:
	NetClient.connected_to_world.connect(_on_connected)
	NetClient.disconnected.connect(_on_disconnected)
	NetClient.entity_spawned.connect(_on_spawn)
	NetClient.entity_despawned.connect(_on_despawn)
	NetClient.entity_state.connect(_on_state)
	NetClient.entity_look.connect(_on_look)
	NetClient.position_corrected.connect(_on_corrected)
	NetClient.monster_attack.connect(_on_monster_attack)
	NetClient.player_cast.connect(_on_player_cast)
	NetClient.monster_killed.connect(_on_monster_killed)
	NetClient.progress.connect(_on_progress)
	if not NetClient.saved.is_connected(SaveManager.set_online_version):
		NetClient.saved.connect(SaveManager.set_online_version)
	NetClient.profile_received.connect(_on_profile)
	NetClient.drops_received.connect(_on_drops)
	NetClient.picked.connect(_on_picked)
	NetClient.drop_gone.connect(_on_drop_gone)
	NetClient.server_notice.connect(_notify)
	NetClient.trade_invite.connect(_on_trade_invite)
	NetClient.trade_state.connect(_on_trade_state)
	NetClient.trade_end.connect(_on_trade_end)
	NetClient.stall_items.connect(_on_stall_items)
	NetClient.stall_sign.connect(_on_stall_sign)
	NetClient.team_state.connect(_on_team_state)
	NetClient.team_invite.connect(_on_team_invite)
	NetClient.guild_received.connect(_on_guild)
	NetClient.guild_list.connect(_on_guild_list)
	NetClient.guild_invite.connect(_on_guild_invite)
	NetClient.friend_invite.connect(_on_friend_invite)
	NetClient.camp_changed.connect(func(eid: int, new_camp: int, new_nation: int) -> void:
		var rp := remote_of(eid)
		if rp:
			rp.set_camp(new_camp, new_nation))
	NetClient.enmity_state.connect(_on_enmity)
	NetClient.pvp_hit.connect(_on_pvp_hit)
	NetClient.view_equip.connect(_on_view_equip)
	current = self
	_add_chat_box()
	_connect()

func _on_guild_list(list: Array) -> void:
	guild_list = list

func _on_pvp_hit(attacker_eid: int, hit: Dictionary) -> void:
	if player and is_instance_valid(player):
		PvpHit.apply(player, hit, remote_of(attacker_eid))

func _on_view_equip(snap: Dictionary) -> void:
	if not snap.is_empty():
		ViewEquipWindow.open_snapshot(get_tree().current_scene, ViewEquipService.snapshot_from_wire(snap))

func _exit_tree() -> void:
	if current == self:
		current = null
	## Gửi bản cuối cho game server (server lưu khi mình rời), rồi đánh dấu version phải hỏi lại.
	if NetClient.is_in_world() and GameManager.local_profile:
		NetClient.send_profile(GameManager.local_profile.to_dict())
	NetClient.disconnect_from_server()
	SaveManager.mark_version_unknown()

## Khung chat trên lớp giao diện của màn chơi (giữa, sát đáy màn hình — mọc lên trên khi mở).
func _add_chat_box() -> void:
	var ui: Node = get_parent().get_node_or_null("UI")
	if ui == null:
		return
	if ui.get_node_or_null("ChatBox") == null:
		ChatBox.attach(ui)

func _connect() -> void:
	_reconnect_in = -1.0
	_notify("Đang kết nối máy chủ game…")
	var token: String = await AccountApi.access_token()
	if token == "":
		_notify("Phiên đăng nhập đã hết hạn — hãy đăng nhập lại")
		return
	NetClient.connect_to(_server(), token, SaveManager.online_character_id)

func _server() -> Dictionary:
	return server_override if not server_override.is_empty() else ServerSelectScreen.selected_server

func remotes() -> Array:
	return _remotes.values()

func monsters() -> Array:
	return _monsters.values()

func _notify(text: String) -> void:
	if player and is_instance_valid(player):
		player.notify(text)

func _on_connected(_eid: int, feet: Vector2, _name: String) -> void:
	NetClient.send_guild(GuildServer.G_LIST)
	_notify("Đã vào %s" % _server().get("name", ""))
	_teleport(feet)
	_last_sent = {}
	_last_look = {}

## Bản nhân vật chuẩn của server (vào map / sau giao dịch): chép vào hồ sơ đang dùng rồi làm mới hình + chỉ số.
## Đã nhận bản nhân vật chuẩn của server trong phiên này (trước đó hồ sơ trong game có thể còn số liệu chưa được server xác nhận).
var profile_synced := false

func _on_profile(data: Dictionary) -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	profile_synced = true
	profile.copy_from(PlayerProfile.from_dict(data))
	if player and is_instance_valid(player):
		player.refresh_combat_stats()

func _on_drops(list: Array) -> void:
	for d in list:
		var id := int(d.id)
		## GroundDrop tự queue_free() khi hết hạn, nên dictionary có thể còn giữ
		## một reference đã được giải phóng. Đọc qua Variant trước khi kiểm tra.
		var existing: Variant = _drops.get(id)
		if is_instance_valid(existing):
			continue
		_drops.erase(id)
		var g := GroundDrop.new()
		if d.has("amount"):
			g.setup_money(int(d.amount))
		else:
			g.setup_item(ItemInstance.from_dict(d.item))
		g.net_id = id
		g.position = d.pos
		_parent().add_child(g)
		_drops[id] = g

func _on_picked(id: int, amount: int, item: Dictionary) -> void:
	var profile := GameManager.local_profile
	if profile:
		if amount > 0:
			profile.gold += amount
			_notify("Nhặt được %d lượng" % amount)
		elif not item.is_empty():
			var it := ItemInstance.from_dict(item)
			if not profile.can_place(it, it.room_x, it.room_y, it.room_bag) or not _place_at(profile, it):
				profile.add_item(it)
			_notify("Nhặt được %s" % it.get_display_name())
		SaveManager.save_profile(profile)
	_on_drop_gone(id)

## Đặt món đúng ô server đã xếp (giữ khớp với hồ sơ server).
func _place_at(profile: PlayerProfile, it: ItemInstance) -> bool:
	if it.room_x < 0:
		return false
	profile.inventory.append(it)
	return true

func _on_drop_gone(id: int) -> void:
	## Không gán thẳng reference trong dictionary vào biến kiểu Node: nếu drop đã
	## tự queue_free() vì hết hạn, phép gán đó sẽ phát lỗi "previously freed instance".
	var g: Variant = _drops.get(id)
	_drops.erase(id)
	if is_instance_valid(g):
		(g as Node).queue_free()

# ---------------------------------------------------------------- giao lưu với người chơi thật

## Người chơi thật đang trong tầm nhìn, dạng MockPlayer (giao diện xã hội có sẵn dùng định dạng này). id = eid trên server.
func nearby_players() -> Array[MockPlayer]:
	var out: Array[MockPlayer] = []
	for r: RemotePlayer in _remotes.values():
		if not is_instance_valid(r):
			continue
		var m := MockPlayer.new()
		m.id = r.eid
		m.name = r.display_name
		m.level = r.level
		m.camp = r.camp
		m.stall_open = (r.flags & NetProto.FLAG_STALL) != 0 or r.stall_title != ""
		m.stall_title = r.stall_title
		m.trade_open = (r.flags & NetProto.FLAG_TRADE_OPEN) != 0
		m.invite_accept_rate = 1.0
		out.append(m)
	return out

func _hub() -> SocialHub:
	return SocialHub.of(GameManager.local_profile) if GameManager.local_profile else null

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

## Cừu sát hiện tại của mình: {state, eid, name, launcher} (state = RelationServer.ENMITY_*).
var enmity: Dictionary = {}

func _on_enmity(state: int, other_eid: int, other_name: String, launcher: bool) -> void:
	var old := int(enmity.get("eid", 0))
	enmity = {"state": state, "eid": other_eid, "name": other_name, "launcher": launcher} if state != RelationServer.ENMITY_NONE else {}
	if old != 0 and old != other_eid and remote_of(old) != null:
		remote_of(old).set_pk_enemy(false)
	_apply_enmity(other_eid)

## Đối thủ cừu sát (đang trong giai đoạn đánh) thành "địch": vào nhóm enemies để chiêu của mình đánh trúng, tên đổi màu.
func _apply_enmity(eid: int) -> void:
	var r: RemotePlayer = remote_of(eid)
	if r == null or not is_instance_valid(r):
		return
	r.set_pk_enemy(int(enmity.get("eid", 0)) == eid and int(enmity.get("state", 0)) == RelationServer.ENMITY_FIGHT)

func _on_friend_invite(from_eid: int, from_name: String) -> void:
	var p := GameManager.local_profile
	if p and p.blacklist.has(from_name):
		NetClient.send_friend(RelationServer.FRIEND_ANSWER, from_eid, 0)   ## sổ đen: tự từ chối
		return
	_ask("Hảo hữu", "%s xin phép gia nhập bằng hữu." % from_name, func(ok: bool) -> void:
		NetClient.send_friend(RelationServer.FRIEND_ANSWER, from_eid, 1 if ok else 0))

## Chuỗi các bước của menu người chơi cần tới node người chơi khác (theo eid).
## Đọc kiểu Variant trước: gán thẳng node đã free vào biến có kiểu sẽ báo lỗi "previously freed instance".
func remote_of(eid: int) -> RemotePlayer:
	var v: Variant = _remotes.get(eid)
	return v as RemotePlayer if is_instance_valid(v) else null

func _monster_of(eid: int) -> VltkMonster:
	var v: Variant = _monsters.get(eid)
	return v as VltkMonster if is_instance_valid(v) else null

## Khung chat (chỉ có khi online).
func chat_box() -> ChatBox:
	return get_parent().get_node_or_null("UI/ChatBox") as ChatBox

func _on_guild_invite(guild_name: String, from_name: String) -> void:
	_ask("Bang hội", "%s mời bạn vào bang %s." % [from_name, guild_name], func(ok: bool) -> void:
		NetClient.send_guild(GuildServer.G_ANSWER, {"guild": guild_name, "accept": ok}))

func _on_team_state(st: Dictionary) -> void:
	var hub := _hub()
	if hub:
		hub.team.apply_net_state(st)

func _on_team_invite(captain_eid: int, captain_name: String) -> void:
	_ask("Tổ đội", "%s mời bạn vào tổ đội." % captain_name, func(ok: bool) -> void:
		NetClient.send_team(SocialServer.TEAM_ANSWER, captain_eid, 1 if ok else 0))

## Hỏi Đồng ý / Từ chối.
## Hộp hỏi lời mời (giao dịch / tổ đội / bang...) — khung chung của cửa sổ xã hội.
func _ask(title: String, text: String, answer: Callable) -> void:
	SocialWindow.ask_yes_no(get_tree().current_scene, title, text, answer)

## Biển quầy của ai đó đổi. Của mình mà "" = server đã dọn quầy (hết hàng, rời chỗ ngồi...) -> tắt quầy trên máy.
func _on_stall_sign(eid: int, title: String) -> void:
	if eid == NetClient.my_eid:
		var p := GameManager.local_profile
		if p != null and title == "" and p.stall_open:
			StallService.close_stall(p)
		elif p != null and title != "" and not p.stall_open:
			NetClient.send_stall(SocialServer.STALL_CLOSE)   ## máy đã dọn quầy (không ngồi được) trước khi server mở xong
		return
	var r := remote_of(eid)
	if r:
		r.set_stall_title(title)

func _on_stall_items(_seller_eid: int, title: String, items: Array) -> void:
	if StallBrowseWindow.current != null and is_instance_valid(StallBrowseWindow.current):
		StallBrowseWindow.current.set_goods(title, items)

## Kinh nghiệm / cấp do server tính: cộng y hệt cách server cộng (cùng PlayerProfile.add_exp) rồi chốt theo số của server.
func _on_progress(gained: int, level: int, current_exp: int) -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	var before := profile.level
	profile.add_exp(gained)
	profile.level = level
	profile.current_exp = current_exp
	if profile.level != before and player and is_instance_valid(player):
		player.refresh_combat_stats()
		_notify("Lên cấp %d!" % profile.level)

func _on_disconnected(code: String, message: String) -> void:
	SaveManager.mark_version_unknown()
	for r in _remotes.values():
		r.queue_free()
	_remotes.clear()
	for m in _monsters.values():
		if is_instance_valid(m):
			m.queue_free()
	_monsters.clear()
	_notify(message)
	if code not in FATAL:
		_reconnect_in = RECONNECT_DELAY

func _teleport(feet: Vector2) -> void:
	if player == null:
		return
	player.global_position = feet - Vector2(0, RemotePlayer.FEET_OFFSET)
	player.velocity = Vector2.ZERO

func _on_corrected(feet: Vector2) -> void:
	_teleport(feet)

func _parent() -> Node:
	if VltkWorld.current and VltkWorld.current.map:
		return VltkWorld.current.map.objects_root
	return get_parent()

func _on_spawn(info: Dictionary) -> void:
	if int(info.kind) == NetProto.KIND_MONSTER:
		_spawn_monster(info)
		return
	if int(info.kind) != NetProto.KIND_PLAYER or remote_of(int(info.eid)) != null:
		return
	var r := RemotePlayer.new()
	_parent().add_child(r)
	r.setup(info)
	_remotes[r.eid] = r
	_apply_enmity(r.eid)

func _spawn_monster(info: Dictionary) -> void:
	var eid := int(info.eid)
	if _monster_of(eid) != null:
		return
	var data := MonsterData.monster(int(info.monster_id))
	if data.is_empty():
		return
	var m := VltkMonster.new()
	m.net_eid = eid
	m.monster_id = int(info.monster_id)
	m.data = data.duplicate()
	m.data["series"] = int(info.series)
	m.level = maxi(1, int(info.level))
	m.blue_boss = bool(info.blue)
	m.ai_enabled = false
	m.position = info.pos
	_parent().add_child(m)
	m.net_push_state(NetClient.server_now_ms() - VltkMonster.NET_INTERP_DELAY_MS, info)
	_monsters[eid] = m

func _on_monster_attack(m_eid: int, slot: int, target_eid: int, dir64: int) -> void:
	var m: VltkMonster = _monster_of(m_eid)
	if m == null or not is_instance_valid(m):
		return
	var mine := target_eid == NetClient.my_eid
	var target_node: Node2D = player if mine else remote_of(target_eid)
	if target_node == null:
		return
	m.net_attack(slot, target_node, dir64, mine)

## Người khác ra chiêu: vẽ lại trên nhân vật của họ (không sát thương — máy họ tính đòn thật).
func _on_player_cast(caster_eid: int, skill_id: int, level: int, cast_flags: int, target_eid: int, aim: Vector2) -> void:
	var r: RemotePlayer = remote_of(caster_eid)
	if r == null or not is_instance_valid(r):
		return
	var target_node: Node2D = null
	if target_eid != 0 and (cast_flags & NetProto.CAST_SUPPORT) == 0:
		if target_eid == NetClient.my_eid:
			target_node = player
		elif _remotes.has(target_eid):
			target_node = remote_of(target_eid)
		elif _monsters.has(target_eid):
			target_node = _monster_of(target_eid)
	VltkSkillRunner.replay(r, skill_id, level, target_node, VltkMath.to_logic(aim))

func _on_monster_killed(k: Dictionary) -> void:
	var m: VltkMonster = _monster_of(int(k.eid))
	if m == null or not is_instance_valid(m):
		return
	m.grant_rewards(bool(k.last_hit))

func _on_despawn(eid: int) -> void:
	var node: Node = _monster_of(eid) if _monsters.has(eid) else remote_of(eid)
	_monsters.erase(eid)
	_remotes.erase(eid)
	if node == null:
		return
	if player and player.get_selected_target() == node:
		player.clear_target()
	node.queue_free()

func _on_state(eid: int, server_ms: int, st: Dictionary) -> void:
	var r: RemotePlayer = remote_of(eid)
	if r:
		r.push_state(server_ms, st)
		return
	var m: VltkMonster = _monster_of(eid)
	if m and is_instance_valid(m):
		m.net_push_state(float(server_ms), st)

func _on_look(eid: int, look: Dictionary) -> void:
	var r: RemotePlayer = remote_of(eid)
	if r:
		r.set_look(look)

func _process(delta: float) -> void:
	if _reconnect_in > 0.0:
		_reconnect_in -= delta
		if _reconnect_in <= 0.0:
			_connect()
		return
	if not NetClient.is_in_world() or player == null or not is_instance_valid(player):
		return
	var av: CharacterAvatar = player.avatar
	var look := {"helm": av.helm_res, "armor": av.armor_res, "weapon": av.weapon_res, "horse": av.horse_res}
	if look != _last_look:
		_last_look = look
		NetClient.send_look(look)
	_send_timer -= delta
	_heartbeat -= delta
	if _send_timer > 0.0:
		return
	var z: float = av.get_height()
	var flags := 0
	if player.is_riding():
		flags |= NetProto.FLAG_RIDING
	if player.is_sitting():
		flags |= NetProto.FLAG_SITTING
	if player.is_dead():
		flags |= NetProto.FLAG_DEAD
	if z > 0.5:
		flags |= NetProto.FLAG_JUMPING
	var cur := {"feet": player.get_ground_position().round(), "dir": av.direction, "action": av.action, "z": int(z), "flags": flags}
	if cur == _last_sent and _heartbeat > 0.0:
		return
	_last_sent = cur
	_send_timer = 1.0 / NetProto.CLIENT_SEND_RATE
	_heartbeat = 1.0
	NetClient.send_move(cur.feet, cur.dir, cur.action, cur.z, flags)

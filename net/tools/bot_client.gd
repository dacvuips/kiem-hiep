class_name BotClient
extends RefCounted
## Người chơi giả (không hình ảnh) — dùng cho kiểm thử mạng và load test.
## Mỗi bot có 1 kết nối ENet riêng tới game server, gửi C_HELLO, ghi lại những gì nhận được.

var peer := ENetMultiplayerPeer.new()
var eid := 0
var feet := Vector2.ZERO
var name := ""
var in_world := false
var error_code := ""
var error_message := ""
var known: Dictionary = {}        ## eid -> {name, pos, ...}
var corrections := 0
var attacked_by: Dictionary = {}  ## monster eid -> số lần quái ra chiêu vào mình
var kills: Array = []             ## các S_KILL nhận được
var exp_gained := 0
var level := 0
var saved_version := 0
var profile: Dictionary = {}      ## bản nhân vật server gửi (S_PROFILE)
var grant_ack := 0
var drops: Dictionary = {}        ## drop_id -> {pos, owner, amount | item}
var picked: Array = []            ## [{id, amount, item}]
var notices: Array = []
var trade_invites: Array = []     ## [{from, name}]
var trade: Dictionary = {}        ## trạng thái giao dịch mới nhất {partner, mine, theirs}
var trade_ended: Array = []       ## [{ok, msg}]
var stall: Dictionary = {}        ## {seller, title, items}
var team: Dictionary = {}         ## trạng thái đội mới nhất {in_team, captain, members:[eid], applicants:[eid], pick}
var team_invites: Array = []      ## [captain_eid]
var chats: Array = []             ## [{channel, from, to, text}]
var guild: Dictionary = {}        ## bang của mình (S_GUILD)
var guild_list: Array = []
var states_received := 0
var friend_invites: Array = []    ## [{from, name}]
var friend_list: Array = []
var view_snap: Dictionary = {}
var enmity: Dictionary = {}       ## {state, other, name, launcher}
var pvp_hits: Array = []          ## [{from, hit}]
var dead := false                 ## gửi cờ FLAG_DEAD trong C_MOVE
var casts: Array = []             ## [{caster, skill, level, flags, target, aim}] (S_CAST)
var closed := false
var _token := ""
var _character_id := 0

func start(host: String, port: int, token: String, character_id: int) -> bool:
	_token = token
	_character_id = character_id
	if peer.create_client(host, port, 2) != OK:
		return false
	peer.peer_connected.connect(func(_id: int) -> void:
		NetProto.tune_enet_peer(peer.get_peer(1))
		_hello())
	peer.peer_disconnected.connect(func(_id: int) -> void: closed = true)
	return true

func _hello() -> void:
	var b := NetProto.writer(NetProto.C_HELLO)
	b.put_u16(NetProto.VERSION)
	NetProto.put_str(b, _token)
	b.put_u32(_character_id)
	_send(b, NetProto.CH_RELIABLE)

func _send(b: StreamPeerBuffer, ch: int) -> void:
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(1)
	peer.transfer_channel = ch
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if ch == NetProto.CH_RELIABLE else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	peer.put_packet(b.data_array)

func move_to(p: Vector2, action := "run", dir := 0) -> void:
	feet = p
	var b := NetProto.writer(NetProto.C_MOVE)
	b.put_float(p.x)
	b.put_float(p.y)
	b.put_u8(dir)
	b.put_u8(NetProto.action_index(action))
	b.put_u8(0)
	b.put_u8(NetProto.FLAG_DEAD if dead else 0)
	_send(b, NetProto.CH_RELIABLE)

## Phe của người chơi khác mình đang thấy (gói xuất hiện + S_CAMP).
func known_camp(other: int) -> int:
	return int(known[other].get("camp", -99)) if known.has(other) else -99

func friend(op: int, target := 0, arg := 0, fname := "") -> void:
	var b := NetProto.writer(NetProto.C_FRIEND)
	b.put_u8(op)
	b.put_u32(target)
	b.put_u8(arg)
	NetProto.put_str(b, fname)
	_send(b, NetProto.CH_RELIABLE)

func view_equip(target: int) -> void:
	var b := NetProto.writer(NetProto.C_VIEW_EQUIP)
	b.put_u32(target)
	_send(b, NetProto.CH_RELIABLE)

func declare_enmity(target: int) -> void:
	var b := NetProto.writer(NetProto.C_ENMITY)
	b.put_u32(target)
	_send(b, NetProto.CH_RELIABLE)

func pvp_hit(target: int, min_d: int, max_d: int) -> void:
	var a := CombatantStats.new()
	a.attack_rating = 999
	var raw := PvpHit.encode(a, min_d, max_d, CombatFormulas.DamageType.PHYSICS, 0, null)
	var b := NetProto.writer(NetProto.C_PVP_HIT)
	b.put_u32(target)
	b.put_u32(raw.size())
	b.put_data(raw)
	_send(b, NetProto.CH_RELIABLE)

func cast(skill_id: int, lv: int, target_eid: int, aim: Vector2, cast_flags := 0) -> void:
	var b := NetProto.writer(NetProto.C_CAST)
	b.put_u16(skill_id)
	b.put_u8(lv)
	b.put_u8(cast_flags)
	b.put_u32(target_eid)
	NetProto.put_state_pos(b, aim)
	_send(b, NetProto.CH_RELIABLE)

func damage(monster_eid: int, amount: int) -> void:
	var b := NetProto.writer(NetProto.C_DAMAGE)
	b.put_u32(monster_eid)
	b.put_u32(amount)
	b.put_u8(1)
	_send(b, NetProto.CH_RELIABLE)

## Quái gần nhất mình đang thấy (eid hoặc 0).
func nearest_monster() -> int:
	var best := 0
	var best_d := INF
	for id in known:
		if int(known[id].kind) == NetProto.KIND_MONSTER and int(known[id].get("hp", 100)) > 0:
			var d := (known[id].pos as Vector2).distance_to(feet)
			if d < best_d:
				best_d = d
				best = id
	return best

func trade_request(target: int) -> void:
	var b := NetProto.writer(NetProto.C_TRADE_REQ)
	b.put_u32(target)
	_send(b, NetProto.CH_RELIABLE)

func trade_answer(from: int, accept: bool) -> void:
	var b := NetProto.writer(NetProto.C_TRADE_ANSWER)
	b.put_u32(from)
	b.put_u8(1 if accept else 0)
	_send(b, NetProto.CH_RELIABLE)

func trade_op(op: int, uid := "", amount := 0) -> void:
	var b := NetProto.writer(NetProto.C_TRADE_OP)
	b.put_u8(op)
	if op == SocialServer.OP_OFFER or op == SocialServer.OP_TAKE:
		NetProto.put_str(b, uid)
	elif op == SocialServer.OP_MONEY:
		b.put_u32(amount)
	_send(b, NetProto.CH_RELIABLE)

func stall_op(op: int, title := "", seller := 0, uid := "") -> void:
	var b := NetProto.writer(NetProto.C_STALL)
	b.put_u8(op)
	if op == SocialServer.STALL_OPEN:
		NetProto.put_str(b, title)
	elif op == SocialServer.STALL_BROWSE:
		b.put_u32(seller)
	elif op == SocialServer.STALL_BUY:
		b.put_u32(seller)
		NetProto.put_str(b, uid)
	_send(b, NetProto.CH_RELIABLE)

func security(op: int, password := "", old_password := "") -> void:
	var b := NetProto.writer(NetProto.C_SECURITY)
	b.put_u8(op)
	NetProto.put_str(b, SecurityLock._hash(password) if password != "" else "")
	NetProto.put_str(b, SecurityLock._hash(old_password) if old_password != "" else "")
	_send(b, NetProto.CH_RELIABLE)

func guild_op(op: int, args := {}) -> void:
	var b := NetProto.writer(NetProto.C_GUILD)
	b.put_u8(op)
	NetProto.put_str(b, JSON.stringify(args))
	_send(b, NetProto.CH_RELIABLE)

func guild_member_names() -> Array:
	var out := []
	for m in guild.get("members", []):
		out.append(str(m.get("name", "")))
	return out

func say(channel: int, text: String, to := "") -> void:
	var b := NetProto.writer(NetProto.C_CHAT)
	b.put_u8(channel)
	NetProto.put_str(b, to)
	NetProto.put_str(b, text)
	_send(b, NetProto.CH_RELIABLE)

func heard(text: String) -> bool:
	return chats.any(func(c: Dictionary) -> bool: return str(c.text) == text)

func team_op(op: int, arg := 0, arg2 := 0) -> void:
	var b := NetProto.writer(NetProto.C_TEAM)
	b.put_u8(op)
	b.put_u32(arg)
	b.put_u8(arg2)
	_send(b, NetProto.CH_RELIABLE)

## Các uid đồ trong túi theo bản server mới nhất.
func inventory_uids() -> Array:
	var out := []
	for it in profile.get("inventory", []):
		out.append(str(it.get("uid", "")))
	return out

func pickup(drop_id: int) -> void:
	var b := NetProto.writer(NetProto.C_PICKUP)
	b.put_u32(drop_id)
	_send(b, NetProto.CH_RELIABLE)

func send_profile(data: Dictionary) -> void:
	var b := NetProto.writer(NetProto.C_PROFILE)
	b.put_u32(grant_ack)
	NetProto.put_json(b, data)
	_send(b, NetProto.CH_RELIABLE)

func close() -> void:
	peer.close()
	closed = true

func poll() -> void:
	if closed:
		return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		_on_packet(peer.get_packet())

func _read_spawn(b: StreamPeerBuffer) -> void:
	var id := b.get_u32()
	var kind := b.get_u8()
	var n := NetProto.get_str(b)
	var lv := b.get_u16()
	var cp := b.get_8()
	known[id] = {"kind": kind, "name": n, "level": lv, "camp": cp, "pos": Vector2(b.get_float(), b.get_float())}
	b.get_data(4)
	known[id]["hp"] = b.get_u8()
	if kind == NetProto.KIND_MONSTER:
		known[id]["monster_id"] = b.get_u16()
		b.get_data(2)
	else:
		NetProto.get_look(b)

func _on_packet(pkt: PackedByteArray) -> void:
	var b := NetProto.reader(pkt)
	match b.get_u8():
		NetProto.S_WELCOME:
			eid = b.get_u32()
			feet = Vector2(b.get_float(), b.get_float())
			name = NetProto.get_str(b)
			in_world = true
		NetProto.S_ERROR:
			error_code = NetProto.get_str(b)
			error_message = NetProto.get_str(b)
		NetProto.S_SPAWN:
			_read_spawn(b)
		NetProto.S_SPAWNS:
			for i in b.get_u16():
				_read_spawn(b)
		NetProto.S_DESPAWNS:
			for i in b.get_u16():
				known.erase(b.get_u32())
		NetProto.S_DESPAWN:
			known.erase(b.get_u32())
		NetProto.S_STATE:
			b.get_u32()
			for i in b.get_u16():
				var id := b.get_u32()
				var pos := NetProto.get_state_pos(b)
				b.get_data(3)
				var hp := b.get_u8()
				states_received += 1
				if known.has(id):
					known[id].pos = pos
					known[id].hp = hp
		NetProto.S_MATTACK:
			var m := b.get_u32()
			b.get_u8()
			if b.get_u32() == eid:
				attacked_by[m] = int(attacked_by.get(m, 0)) + 1
		NetProto.S_KILL:
			kills.append({"eid": b.get_u32(), "monster_id": b.get_u16()})
		NetProto.S_PROGRESS:
			exp_gained += b.get_u32()
			level = b.get_u16()
		NetProto.S_SAVED:
			saved_version = b.get_u32()
		NetProto.S_PROFILE:
			grant_ack = b.get_u32()
			profile = NetProto.get_json(b)
		NetProto.S_DROPS:
			for i in b.get_u16():
				var id := b.get_u32()
				var d := {"pos": Vector2(b.get_float(), b.get_float()), "owner": b.get_u32()}
				if b.get_u8() == 0:
					d["amount"] = b.get_u32()
				else:
					d["item"] = JSON.parse_string(NetProto.get_str(b, 65535))
				drops[id] = d
		NetProto.S_PICKED:
			grant_ack = b.get_u32()
			var id := b.get_u32()
			var got := {"id": id}
			if b.get_u8() == 0:
				got["amount"] = b.get_u32()
			else:
				got["item"] = JSON.parse_string(NetProto.get_str(b, 65535))
			picked.append(got)
			drops.erase(id)
		NetProto.S_DROP_GONE:
			drops.erase(b.get_u32())
		NetProto.S_NOTICE:
			notices.append(NetProto.get_str(b))
		NetProto.S_TRADE_INVITE:
			var from := b.get_u32()
			trade_invites.append({"from": from, "name": NetProto.get_str(b)})
		NetProto.S_TRADE_STATE:
			var t := {"partner": b.get_u32(), "partner_name": NetProto.get_str(b)}
			for side in ["mine", "theirs"]:
				var d := {"money": b.get_u32(), "locked": b.get_u8() != 0, "ok": b.get_u8() != 0, "age": b.get_u32(), "uids": []}
				for k in b.get_u16():
					d.uids.append(str(JSON.parse_string(NetProto.get_str(b, 65535)).get("uid", "")))
				t[side] = d
			trade = t
		NetProto.S_TRADE_END:
			var ok := b.get_u8() != 0
			trade_ended.append({"ok": ok, "msg": NetProto.get_str(b)})
		NetProto.S_TEAM_STATE:
			var st := {"in_team": b.get_u8() != 0, "members": [], "applicants": []}
			if st.in_team:
				st["captain"] = b.get_u32()
				st["open"] = b.get_u8() != 0
				st["pick"] = b.get_u8()
				b.get_u8()
				for i in b.get_u8():
					st.members.append(b.get_u32())
					NetProto.get_str(b)
					b.get_u16()
					b.get_8()
					b.get_u8()
					NetProto.get_str(b)
				for i in b.get_u8():
					st.applicants.append(b.get_u32())
					NetProto.get_str(b)
					b.get_u16()
			team = st
		NetProto.S_GUILD:
			var raw := NetProto.get_str(b, 1 << 20)
			var parsed: Variant = JSON.parse_string(raw) if raw != "" else null
			guild = parsed if parsed is Dictionary else {}
		NetProto.S_GUILD_LIST:
			var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 1 << 20))
			guild_list = parsed if parsed is Array else []
		NetProto.S_CAMP:
			var ce := b.get_u32()
			var cv := b.get_8()
			if known.has(ce):
				known[ce]["camp"] = cv
		NetProto.S_FRIEND_INVITE:
			var fe := b.get_u32()
			friend_invites.append({"from": fe, "name": NetProto.get_str(b)})
		NetProto.S_FRIEND_LIST:
			var fl: Variant = JSON.parse_string(NetProto.get_str(b, 1 << 20))
			friend_list = fl if fl is Array else []
		NetProto.S_VIEW_EQUIP:
			view_snap = NetProto.get_json(b)
		NetProto.S_ENMITY:
			var est := b.get_u8()
			var eo := b.get_u32()
			var en := NetProto.get_str(b)
			enmity = {"state": est, "other": eo, "name": en, "launcher": b.get_u8() != 0}
		NetProto.S_PVP_HIT:
			var pa := b.get_u32()
			var pn := b.get_u32()
			pvp_hits.append({"from": pa, "hit": PvpHit.decode(b.get_data(pn)[1])})
		NetProto.S_CAST:
			var cst := {"caster": b.get_u32(), "skill": b.get_u16(), "level": b.get_u8(), "flags": b.get_u8(), "target": b.get_u32()}
			cst["aim"] = NetProto.get_state_pos(b)
			casts.append(cst)
		NetProto.S_CHAT:
			var ch := b.get_u8()
			b.get_u32()
			var from := NetProto.get_str(b)
			var to := NetProto.get_str(b)
			chats.append({"channel": ch, "from": from, "to": to, "text": NetProto.get_str(b)})
		NetProto.S_TEAM_INVITE:
			team_invites.append(b.get_u32())
			NetProto.get_str(b)
		NetProto.S_STALL_ITEMS:
			var s := {"seller": b.get_u32(), "title": NetProto.get_str(b), "items": []}
			for k in b.get_u16():
				s.items.append(JSON.parse_string(NetProto.get_str(b, 65535)))
			stall = s
		NetProto.S_CORRECT:
			corrections += 1
			feet = Vector2(b.get_float(), b.get_float())

extends Node
## Autoload NetClient — kết nối game server (chế độ MAIN_MAP online).
## PC / mobile: ENet (UDP). Web: WebSocket. Sau khi kết nối gửi C_HELLO (access token + mã nhân vật); server trả S_WELCOME.
## Không biết gì về hình ảnh: phát signal cho NetWorldSync vẽ.

signal connected_to_world(my_eid: int, feet: Vector2, my_name: String)
signal disconnected(code: String, message: String)
signal entity_spawned(info: Dictionary)
signal entity_despawned(eid: int)
signal entity_state(eid: int, server_ms: int, state: Dictionary)
signal entity_look(eid: int, look: Dictionary)
signal position_corrected(feet: Vector2)
signal monster_attack(monster_eid: int, slot: int, target_eid: int, dir64: int)
signal monster_killed(info: Dictionary)
signal progress(exp_gained: int, level: int, current_exp: int)
signal saved(version: int)
signal profile_received(data: Dictionary)
signal drops_received(drops: Array)
signal picked(drop_id: int, amount: int, item: Dictionary)
signal drop_gone(drop_id: int)
signal server_notice(text: String)
signal trade_invite(from_eid: int, from_name: String)
signal trade_state(partner_eid: int, partner_name: String, mine: Dictionary, theirs: Dictionary)
signal trade_end(success: bool, message: String)
signal stall_items(seller_eid: int, title: String, items: Array)
signal team_state(state: Dictionary)
signal team_invite(captain_eid: int, captain_name: String)

## Số thứ tự quà (đồ / tiền) server cho mà hồ sơ trên máy đã áp — gửi kèm C_PROFILE.
var grant_ack := 0

enum Status { OFFLINE, CONNECTING, IN_WORLD }

var status := Status.OFFLINE
var my_eid := 0
## Lệch giờ ước lượng: server_ms - client_ms (để nội suy theo giờ server).
var clock_offset := 0.0
var rtt_ms := 0.0

var _peer: MultiplayerPeer
var _last_error := ["", ""]
var _ping_timer := 0.0
var _connect_deadline := 0.0

## Kết nối tới máy chủ (dict lấy từ /v1/servers: host, port, ws_url).
func connect_to(server: Dictionary, access_token: String, character_id: int) -> void:
	disconnect_from_server()
	_last_error = ["", ""]
	var err := OK
	if OS.has_feature("web"):
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_client(str(server.get("ws_url", "")))
		_peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		err = enet.create_client(str(server.get("host", "127.0.0.1")), int(server.get("port", 7777)), 2)
		_peer = enet
	if err != OK:
		_fail("connect_failed", "Không kết nối được máy chủ game")
		return
	status = Status.CONNECTING
	_connect_deadline = Time.get_ticks_msec() / 1000.0 + 10.0
	_peer.peer_connected.connect(func(_id: int) -> void:
		if _peer is ENetMultiplayerPeer:
			NetProto.tune_enet_peer((_peer as ENetMultiplayerPeer).get_peer(1))
		_send_hello(access_token, character_id))
	_peer.peer_disconnected.connect(func(_id: int) -> void:
		_fail(_last_error[0] if _last_error[0] != "" else "disconnected",
			_last_error[1] if _last_error[1] != "" else "Mất kết nối với máy chủ game"))

func disconnect_from_server() -> void:
	if _peer:
		_peer.close()
	_peer = null
	status = Status.OFFLINE
	my_eid = 0

func is_in_world() -> bool:
	return status == Status.IN_WORLD

func server_now_ms() -> float:
	return Time.get_ticks_msec() + clock_offset

func _fail(code: String, message: String) -> void:
	var was := status
	disconnect_from_server()
	if was != Status.OFFLINE:
		disconnected.emit(code, message)

func _send(b: StreamPeerBuffer, channel := NetProto.CH_RELIABLE) -> void:
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_peer.set_target_peer(1)
	_peer.transfer_channel = channel
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if channel == NetProto.CH_RELIABLE \
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	_peer.put_packet(b.data_array)

func _send_hello(token: String, character_id: int) -> void:
	var b := NetProto.writer(NetProto.C_HELLO)
	b.put_u16(NetProto.VERSION)
	NetProto.put_str(b, token)
	b.put_u32(character_id)
	_send(b)

## Gửi vị trí chân + hiển thị của nhân vật mình.
func send_move(feet: Vector2, dir: int, action: String, z: float, flags: int) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_MOVE)
	b.put_float(feet.x)
	b.put_float(feet.y)
	b.put_u8(dir & 7)
	b.put_u8(NetProto.action_index(action))
	b.put_u8(clampi(int(z), 0, 255))
	b.put_u8(flags)
	_send(b)   ## tin cậy: gói nhỏ, tối đa 15/giây — gửi không tin cậy từ máy người chơi từng bị ENet bỏ mất hàng loạt

## Báo sát thương mình gây cho quái (server kiểm tra rồi trừ máu chung).
func send_damage(monster_eid: int, amount: float, staggers: bool) -> void:
	if status != Status.IN_WORLD or amount <= 0.0:
		return
	var b := NetProto.writer(NetProto.C_DAMAGE)
	b.put_u32(monster_eid)
	b.put_u32(clampi(int(amount), 0, 0x7fffffff))
	b.put_u8(1 if staggers else 0)
	_send(b)

## Gửi bản nhân vật cho game server (thay cho lưu HTTP khi đang trong map online).
func send_profile(data: Dictionary) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_PROFILE)
	b.put_u32(grant_ack)
	NetProto.put_json(b, data)
	_send(b)

func send_trade_request(target_eid: int) -> void:
	var b := NetProto.writer(NetProto.C_TRADE_REQ)
	b.put_u32(target_eid)
	_send(b)

func send_trade_answer(from_eid: int, accept: bool) -> void:
	var b := NetProto.writer(NetProto.C_TRADE_ANSWER)
	b.put_u32(from_eid)
	b.put_u8(1 if accept else 0)
	_send(b)

func send_trade_op(op: int, uid := "", amount := 0) -> void:
	var b := NetProto.writer(NetProto.C_TRADE_OP)
	b.put_u8(op)
	if op == SocialServer.OP_OFFER or op == SocialServer.OP_TAKE:
		NetProto.put_str(b, uid)
	elif op == SocialServer.OP_MONEY:
		b.put_u32(amount)
	_send(b)

## Bày bán / mở giao dịch. op = SocialServer.STALL_* / TRADE_OPEN / TRADE_CLOSE.
func send_stall(op: int, title := "", seller_eid := 0, uid := "") -> void:
	var b := NetProto.writer(NetProto.C_STALL)
	b.put_u8(op)
	match op:
		SocialServer.STALL_OPEN:
			NetProto.put_str(b, title)
		SocialServer.STALL_BROWSE:
			b.put_u32(seller_eid)
		SocialServer.STALL_BUY:
			b.put_u32(seller_eid)
			NetProto.put_str(b, uid)
	_send(b)

## Tổ đội: op = SocialServer.TEAM_*, arg = eid người liên quan, arg2 = đồng ý / mở / chế độ nhặt.
func send_team(op: int, arg := 0, arg2 := 0) -> void:
	var b := NetProto.writer(NetProto.C_TEAM)
	b.put_u8(op)
	b.put_u32(arg)
	b.put_u8(arg2)
	_send(b)

func send_pickup(drop_id: int) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_PICKUP)
	b.put_u32(drop_id)
	_send(b)

func send_discard(item_uid: String) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_DISCARD)
	NetProto.put_str(b, item_uid)
	_send(b)

func send_look(look: Dictionary) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_LOOK)
	for k in ["helm", "armor", "weapon", "horse"]:
		b.put_16(int(look.get(k, -1)))
	_send(b)

func _process(delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	if _peer == null:
		return
	if status == Status.CONNECTING and Time.get_ticks_msec() / 1000.0 > _connect_deadline:
		_fail("timeout", "Máy chủ game không phản hồi")
		return
	while _peer and _peer.get_available_packet_count() > 0:
		_on_packet(_peer.get_packet())
	if status == Status.IN_WORLD:
		_ping_timer -= delta
		if _ping_timer <= 0.0:
			_ping_timer = 2.0
			var b := NetProto.writer(NetProto.C_PING)
			b.put_u32(Time.get_ticks_msec())
			_send(b)

func _read_spawn(b: StreamPeerBuffer) -> void:
	var info := {
		"eid": b.get_u32(), "kind": b.get_u8(), "name": NetProto.get_str(b), "level": b.get_u16(), "camp": b.get_8(),
		"pos": Vector2(b.get_float(), b.get_float()), "dir": b.get_u8(), "action": b.get_u8(), "z": b.get_u8(),
		"flags": b.get_u8(), "hp": b.get_u8(),
	}
	if int(info.kind) == NetProto.KIND_PLAYER:
		info["look"] = NetProto.get_look(b)
	else:
		info["monster_id"] = b.get_u16()
		info["series"] = b.get_u8()
		info["blue"] = b.get_u8() != 0
	entity_spawned.emit(info)

func _on_packet(pkt: PackedByteArray) -> void:
	if pkt.is_empty():
		return
	var b := NetProto.reader(pkt)
	match b.get_u8():
		NetProto.S_WELCOME:
			my_eid = b.get_u32()
			var feet := Vector2(b.get_float(), b.get_float())
			var my_name := NetProto.get_str(b)
			status = Status.IN_WORLD
			connected_to_world.emit(my_eid, feet, my_name)
		NetProto.S_ERROR:
			_last_error = [NetProto.get_str(b), NetProto.get_str(b)]
		NetProto.S_SPAWN:
			_read_spawn(b)
		NetProto.S_SPAWNS:
			for i in b.get_u16():
				_read_spawn(b)
		NetProto.S_DESPAWNS:
			for i in b.get_u16():
				entity_despawned.emit(b.get_u32())
		NetProto.S_DESPAWN:
			entity_despawned.emit(b.get_u32())
		NetProto.S_STATE:
			var server_ms := b.get_u32()
			var n := b.get_u16()
			for i in n:
				var eid := b.get_u32()
				var st := {
					"pos": Vector2(b.get_float(), b.get_float()), "dir": b.get_u8(), "action": b.get_u8(),
					"z": b.get_u8(), "flags": b.get_u8(), "hp": b.get_u8(),
				}
				entity_state.emit(eid, server_ms, st)
		NetProto.S_LOOK:
			var eid := b.get_u32()
			entity_look.emit(eid, NetProto.get_look(b))
		NetProto.S_MATTACK:
			var m_eid := b.get_u32()
			var slot := b.get_u8()
			var target := b.get_u32()
			monster_attack.emit(m_eid, slot, target, b.get_u8())
		NetProto.S_KILL:
			var k := {"eid": b.get_u32(), "monster_id": b.get_u16(), "level": b.get_u16(), "series": b.get_u8(),
				"blue": b.get_u8() != 0, "pos": Vector2(b.get_float(), b.get_float())}
			var share := b.get_u8()
			k["share"] = share & 0x7f
			k["last_hit"] = (share & 0x80) != 0
			monster_killed.emit(k)
		NetProto.S_PROGRESS:
			var gained := b.get_u32()
			var lv := b.get_u16()
			progress.emit(gained, lv, b.get_64())
		NetProto.S_SAVED:
			saved.emit(b.get_u32())
		NetProto.S_PROFILE:
			var seq := b.get_u32()
			var data := NetProto.get_json(b)
			if not data.is_empty():
				grant_ack = seq
				profile_received.emit(data)
		NetProto.S_DROPS:
			var list: Array = []
			for i in b.get_u16():
				var d := {"id": b.get_u32(), "pos": Vector2(b.get_float(), b.get_float()), "owner": b.get_u32()}
				if b.get_u8() == 0:
					d["amount"] = b.get_u32()
				else:
					var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 65535))
					d["item"] = parsed if parsed is Dictionary else {}
				list.append(d)
			drops_received.emit(list)
		NetProto.S_PICKED:
			var seq := b.get_u32()
			var id := b.get_u32()
			var amount := 0
			var item := {}
			if b.get_u8() == 0:
				amount = b.get_u32()
			else:
				var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 65535))
				item = parsed if parsed is Dictionary else {}
			picked.emit(id, amount, item)
			grant_ack = seq
		NetProto.S_DROP_GONE:
			drop_gone.emit(b.get_u32())
		NetProto.S_NOTICE:
			server_notice.emit(NetProto.get_str(b))
		NetProto.S_TRADE_INVITE:
			var from := b.get_u32()
			trade_invite.emit(from, NetProto.get_str(b))
		NetProto.S_TRADE_STATE:
			var pid := b.get_u32()
			var pname := NetProto.get_str(b)
			var sides := []
			for i in 2:
				var d := {"money": b.get_u32(), "locked": b.get_u8() != 0, "ok": b.get_u8() != 0, "ok_age_ms": b.get_u32(), "items": []}
				for k in b.get_u16():
					var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 65535))
					if parsed is Dictionary:
						d.items.append(parsed)
				sides.append(d)
			trade_state.emit(pid, pname, sides[0], sides[1])
		NetProto.S_TRADE_END:
			var ok := b.get_u8() != 0
			trade_end.emit(ok, NetProto.get_str(b))
		NetProto.S_TEAM_STATE:
			var st := {"in_team": b.get_u8() != 0}
			if st.in_team:
				st["captain"] = b.get_u32()
				st["open"] = b.get_u8() != 0
				st["pick"] = b.get_u8()
				st["turn"] = b.get_u8()
				st["members"] = []
				for i in b.get_u8():
					st.members.append({"eid": b.get_u32(), "name": NetProto.get_str(b), "level": b.get_u16(), "camp": b.get_8(),
						"lead": b.get_u8(), "sect": NetProto.get_str(b)})
				st["applicants"] = []
				for i in b.get_u8():
					st.applicants.append({"eid": b.get_u32(), "name": NetProto.get_str(b), "level": b.get_u16()})
			team_state.emit(st)
		NetProto.S_TEAM_INVITE:
			var cap := b.get_u32()
			team_invite.emit(cap, NetProto.get_str(b))
		NetProto.S_STALL_ITEMS:
			var seller := b.get_u32()
			var title := NetProto.get_str(b)
			var items := []
			for k in b.get_u16():
				var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 65535))
				if parsed is Dictionary:
					items.append(parsed)
			stall_items.emit(seller, title, items)
		NetProto.S_CORRECT:
			position_corrected.emit(Vector2(b.get_float(), b.get_float()))
		NetProto.S_PONG:
			var sent := b.get_u32()
			var server_ms := b.get_u32()
			var now := Time.get_ticks_msec()
			rtt_ms = float(now - sent)
			var offset := float(server_ms) + rtt_ms * 0.5 - now
			clock_offset = offset if clock_offset == 0.0 else lerpf(clock_offset, offset, 0.2)

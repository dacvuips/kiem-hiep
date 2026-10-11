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
var states_received := 0
var closed := false
var _token := ""
var _character_id := 0

func start(host: String, port: int, token: String, character_id: int) -> bool:
	_token = token
	_character_id = character_id
	if peer.create_client(host, port, 2) != OK:
		return false
	peer.peer_connected.connect(func(_id: int) -> void: _hello())
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
	b.put_u8(0)
	_send(b, NetProto.CH_STATE)

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

func close() -> void:
	peer.close()
	closed = true

func poll() -> void:
	if closed:
		return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		_on_packet(peer.get_packet())

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
			var id := b.get_u32()
			var kind := b.get_u8()
			var n := NetProto.get_str(b)
			var lv := b.get_u16()
			b.get_8()
			known[id] = {"kind": kind, "name": n, "level": lv, "pos": Vector2(b.get_float(), b.get_float())}
			b.get_data(4)
			known[id]["hp"] = b.get_u8()
			if kind == NetProto.KIND_MONSTER:
				known[id]["monster_id"] = b.get_u16()
		NetProto.S_DESPAWN:
			known.erase(b.get_u32())
		NetProto.S_STATE:
			b.get_u32()
			for i in b.get_u16():
				var id := b.get_u32()
				var pos := Vector2(b.get_float(), b.get_float())
				b.get_data(4)
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
		NetProto.S_CORRECT:
			corrections += 1
			feet = Vector2(b.get_float(), b.get_float())

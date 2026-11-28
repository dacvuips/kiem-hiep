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
## Hình bùa đang dính trên quái (người khác áp): [[state_id, giây còn lại], ...].
signal monster_states(monster_eid: int, states: Array)
signal monster_killed(info: Dictionary)
signal progress(exp_gained: int, level: int, current_exp: int)
signal saved(version: int)
signal profile_received(data: Dictionary)
signal drops_received(drops: Array)
signal picked(drop_id: int, amount: int, item: Dictionary)
signal drop_gone(drop_id: int)
signal server_notice(text: String)
signal event_times_changed   ## lịch sự kiện năm GM đặt vừa đổi (S_EVENT_TIMES)
signal trade_invite(from_eid: int, from_name: String)
signal trade_state(partner_eid: int, partner_name: String, mine: Dictionary, theirs: Dictionary)
signal trade_end(success: bool, message: String)
signal market_received(data: Dictionary)
signal stall_items(seller_eid: int, title: String, items: Array)
signal stall_sign(eid: int, title: String)
signal team_state(state: Dictionary)
signal team_hp(list: Array)   ## [{eid, hp (0..100), near}] — máu đồng đội (S_TEAM_HP)
signal team_invite(captain_eid: int, captain_name: String)
signal team_apply(applicant_eid: int, applicant_name: String, applicant_level: int)
signal guild_received(data: Dictionary)
signal guild_list(list: Array)
signal guild_invite(guild_name: String, from_name: String)
signal player_cast(caster_eid: int, skill_id: int, level: int, cast_flags: int, target_eid: int, aim: Vector2)
signal enmity_state(state: int, other_eid: int, other_name: String, launcher: bool)
signal pvp_hit(attacker_eid: int, hit: Dictionary)
signal camp_changed(eid: int, camp: int, nation: int)
signal player_guild_changed(eid: int, guild_name: String, guild_emblem: int)
signal friend_invite(from_eid: int, from_name: String)
signal friend_list(list: Array)
signal view_equip(snapshot: Dictionary)
signal chat_received(channel: int, from_eid: int, from_name: String, to_name: String, text: String)
## Chiến trường Tống Kim (battle server): {op: "state" | "joined" | "reject" | "result", ...}.
signal battle_message(msg: Dictionary)
## Đấu trường PK: tin S_ARENA {op: room | state | result | reject | searching | no_match} (ArenaClient).
signal arena_message(msg: Dictionary)
## Phòng train chung Vượt Ải: tin S_FIELD {op: room | reject, ...} (FieldClient).
signal field_message(msg: Dictionary)
## Chiến Trường Sinh Tồn (PubgServer trên game server thế giới): tin S_PUBG — xem PubgServer.
signal pubg_message(msg: Dictionary)
## Lộn Xộn (LonXonServer trên game server thế giới): tin S_LONXON — xem LonXonServer.
signal lonxon_message(msg: Dictionary)
## Oẳn tù xì: tin S_RPS {op: invite | state | end, ...} — xem RpsServer.
signal rps_message(msg: Dictionary)

## Số thứ tự quà (đồ / tiền) server cho mà hồ sơ trên máy đã áp — gửi kèm C_PROFILE.
var grant_ack := 0

enum Status { OFFLINE, CONNECTING, IN_WORLD }

var status := Status.OFFLINE
var my_eid := 0
## Lệch giờ ước lượng: server_ms - client_ms (để nội suy theo giờ server).
var clock_offset := 0.0
var rtt_ms := 0.0
var _clock_target := 0.0   ## lệch giờ đo được gần nhất (clock_offset trượt dần tới đây, không nhảy bậc -> nội suy không giật)

## ---- Bộ đệm nội suy tự điều chỉnh (jitter buffer) ----
## Mỗi mẫu vị trí nhận được: độ "muộn" = giờ server hiện tại - giờ lấy mẫu. Vẽ trễ = đỉnh độ muộn gần đây + 1 nhịp gửi
## (SNAPSHOT_MS) + đệm nhỏ -> luôn có mẫu kế tiếp để nội suy mà không trễ thừa. Tách người chơi (mẫu đi 2 chặng
## game A -> server -> game B) và quái (server tự mô phỏng, 1 chặng).
enum Interp { PLAYER, MONSTER }
const INTERP_MIN_MS := 60.0
const INTERP_MAX_MS := 320.0
const INTERP_MARGIN_MS := 12.0
const LATENESS_DECAY_PER_SEC := 25.0   ## đỉnh độ muộn hạ dần (ms/giây): 1 lần nghẽn giữ đệm lớn vài giây rồi mới thu lại
var _lateness_peak := [60.0, 20.0]
var _interp_delay := [120.0, 80.0]

## Ghi nhận 1 mẫu vị trí vừa tới (giờ lấy mẫu theo giờ server).
func note_sample(kind: int, sample_server_ms: float) -> void:
	var late := server_now_ms() - sample_server_ms
	if late > 0.0 and late < 2000.0:
		_lateness_peak[kind] = maxf(_lateness_peak[kind], late)

## Độ trễ vẽ hiện tại (ms) của người chơi khác / quái.
func interp_delay_ms(kind: int = Interp.PLAYER) -> float:
	return _interp_delay[kind]

func _tick_interp(delta: float) -> void:
	for k in 2:
		_lateness_peak[k] = maxf(0.0, _lateness_peak[k] - LATENESS_DECAY_PER_SEC * delta)
		var target := clampf(_lateness_peak[k] + NetProto.SNAPSHOT_MS + INTERP_MARGIN_MS, INTERP_MIN_MS, INTERP_MAX_MS)
		## Tăng nhanh (tránh rỗng đệm), giảm chậm (tránh nhân vật khác chạy nhanh/chậm thấy rõ khi trễ đổi).
		var rate := 400.0 if target > _interp_delay[k] else 20.0
		_interp_delay[k] = move_toward(_interp_delay[k], target, rate * delta)
	if absf(_clock_target - clock_offset) > 250.0:
		clock_offset = _clock_target
	else:
		clock_offset = move_toward(clock_offset, _clock_target, 10.0 * delta)

var _peer: MultiplayerPeer
var _last_error := ["", ""]
var _ping_timer := 0.0
var _connect_deadline := 0.0

## Kết nối tới máy chủ (dict lấy từ /v1/servers: host, port, ws_url).
## hub = true: kết nối SẢNH từ Character Hub (HubSession) — không có nhân vật trên map; dùng Chợ / giao dịch theo ID / chat / tổ đội / bang.
var is_hub := false

func connect_to(server: Dictionary, access_token: String, character_id: int, hub := false) -> void:
	disconnect_from_server()
	is_hub = hub
	_last_error = ["", ""]
	var err := OK
	var ws_url := str(server.get("ws_url", ""))
	# WebSocket: bản web (bắt buộc), và máy chủ thật đặt sau proxy 1 cổng (ws_url dạng wss://<tên miền>/ws/...).
	# Máy dev (ws_url dạng ws://127.0.0.1:...) vẫn dùng ENet/UDP nhanh hơn.
	if OS.has_feature("web") or ws_url.begins_with("wss://"):
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_client(ws_url)
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
		_send_hello(access_token, character_id, hub))
	var this_peer := _peer
	_peer.peer_disconnected.connect(func(_id: int) -> void:
		# Tín hiệu này phát ra giữa _peer.poll(): đóng/giải phóng peer ngay tại đây làm Godot sập (signal 11),
		# nên dời sang cuối khung hình, và bỏ qua nếu lúc đó đã đổi sang kết nối khác.
		(func() -> void:
			if _peer != this_peer:
				return
			_fail(_last_error[0] if _last_error[0] != "" else "disconnected",
				_last_error[1] if _last_error[1] != "" else "Mất kết nối với máy chủ game")).call_deferred())

func disconnect_from_server() -> void:
	if _peer:
		_peer.close()
	_peer = null
	status = Status.OFFLINE
	my_eid = 0
	SeasonalEvents.use_local_overrides()   ## rời online: lịch sự kiện về bản của máy

func is_in_world() -> bool:
	return status == Status.IN_WORLD

func server_now_ms() -> float:
	return Time.get_ticks_msec() + clock_offset

## Độ trễ nội suy thích ứng theo Ping (VLTK gốc):
## Ping thấp (<= 30ms): hạ xuống 85ms - 90ms (nhanh hơn 50ms).
## Ping cao (> 80ms): tự nâng lên 140ms - 160ms chống rỗng bộ đệm.
## Giữ cho mã cũ: nay = độ trễ vẽ người chơi khác của bộ đệm tự điều chỉnh.
func adaptive_interp_delay_ms() -> float:
	return interp_delay_ms(Interp.PLAYER)

func _fail(code: String, message: String) -> void:
	var was := status
	disconnect_from_server()
	if was != Status.OFFLINE:
		disconnected.emit(code, message)

## Đếm gói gửi lên theo loại trong cửa sổ 1 giây: gần trần chống dồn của server (GameServer.MAX_PACKETS_PER_SEC) thì in ra
## log để biết gói nào gửi nhiều (server đá "flood" khi vượt).
const SEND_WARN_PER_SEC := 60
var _send_window_ms := 0
var _send_count := 0
var _send_types: Dictionary = {}

func _send(b: StreamPeerBuffer, channel := NetProto.CH_RELIABLE) -> void:
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _send_window_ms > 1000:
		if _send_count >= SEND_WARN_PER_SEC:
			print("[NetClient] gửi %d gói/giây — theo loại: %s" % [_send_count, _send_types])
		_send_window_ms = now_ms
		_send_count = 0
		_send_types.clear()
	_send_count += 1
	var t: int = b.data_array[0]
	_send_types[t] = int(_send_types.get(t, 0)) + 1
	_peer.set_target_peer(1)
	_peer.transfer_channel = channel
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if channel == NetProto.CH_RELIABLE \
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	_peer.put_packet(b.data_array)

func _send_hello(token: String, character_id: int, hub := false) -> void:
	var b := NetProto.writer(NetProto.C_HELLO)
	b.put_u16(NetProto.VERSION)
	NetProto.put_str(b, token)
	b.put_u32(character_id)
	b.put_u8(NetProto.HELLO_HUB if hub else NetProto.HELLO_WORLD)
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
	b.put_u32(int(server_now_ms()) & 0xFFFFFFFF)   ## giờ lấy mẫu (giờ server)
	_send(b)   ## tin cậy: gói nhỏ, tối đa 15/giây — gửi không tin cậy từ máy người chơi từng bị ENet bỏ mất hàng loạt

## Mình vừa ra chiêu: server chuyển cho người xung quanh vẽ lại. `aim` = toạ độ chân điểm nhắm (px thế giới).
func send_cast(skill_id: int, level: int, cast_flags: int, target_eid: int, aim: Vector2) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_CAST)
	b.put_u16(clampi(skill_id, 0, 65535))
	b.put_u8(clampi(level, 1, 63))
	b.put_u8(cast_flags)
	b.put_u32(target_eid)
	NetProto.put_state_pos(b, aim)
	_send(b)

## Báo bùa mình vừa áp lên quái (choáng, làm chậm, bùa phái...) để server chuyển cho người khác đang thấy quái đó vẽ hình.
## Không gửi ngay: gom lại, gửi 1 gói C_MSTATE_BATCH cùng nhịp với sát thương (_flush_damage) — bùa áp cả vùng trúng hàng
## chục quái 1 lúc không làm tràn gói/giây (server đá "Gửi dữ liệu quá nhanh").
var _pending_mstate: Dictionary = {}   ## Vector2i(monster_eid, state_id) -> thời gian (1/10 giây), giữ lần dài nhất

func send_monster_state(monster_eid: int, state_id: int, seconds: float) -> void:
	if status != Status.IN_WORLD or state_id <= 0 or seconds <= 0.0:
		return
	var key := Vector2i(monster_eid, state_id)
	_pending_mstate[key] = maxi(int(_pending_mstate.get(key, 0)), clampi(int(round(seconds * 10.0)), 1, 600))

func _flush_mstate() -> void:
	if _pending_mstate.is_empty():
		return
	if status != Status.IN_WORLD:
		_pending_mstate.clear()
		return
	var keys := _pending_mstate.keys()
	var start := 0
	while start < keys.size():
		var n := mini(keys.size() - start, 255)
		var b := NetProto.writer(NetProto.C_MSTATE_BATCH)
		b.put_u8(n)
		for i in n:
			var key: Vector2i = keys[start + i]
			b.put_u32(key.x)
			b.put_u32(key.y)
			b.put_u16(int(_pending_mstate[key]))
		_send(b)
		start += n
	_pending_mstate.clear()

## Báo sát thương mình gây cho quái (server kiểm tra rồi trừ máu chung). Không gửi ngay: gom theo quái rồi gửi 1 gói
## C_DAMAGE_BATCH mỗi DAMAGE_FLUSH_SEC (xem _flush_damage) — skill nhiều nhịp đánh bầy quái không làm tràn gói/giây.
const DAMAGE_FLUSH_SEC := 0.1
var _pending_damage: Dictionary = {}   ## khoá (monster_eid, hoặc -monster_eid - 1 cho rút độc) -> [tổng sát thương, số đòn, khựng]
var _damage_flush_timer := 0.0

## `poison` = nhịp rút độc: gửi mục riêng có cờ DAMAGE_POISON (server không chặn trần 1 đòn).
func send_damage(monster_eid: int, amount: float, staggers: bool, poison := false) -> void:
	if status != Status.IN_WORLD or amount <= 0.0:
		return
	var key := -monster_eid - 1 if poison else monster_eid
	var entry: Array = _pending_damage.get(key, [0, 0, false])
	if int(entry[1]) >= NetProto.DAMAGE_MAX_HITS:
		_flush_damage()
		entry = [0, 0, false]
	entry[0] = mini(int(entry[0]) + int(amount), 0x7fffffff)
	entry[1] = int(entry[1]) + 1
	entry[2] = bool(entry[2]) or staggers
	_pending_damage[key] = entry

func _flush_damage() -> void:
	_damage_flush_timer = DAMAGE_FLUSH_SEC
	_flush_mstate()
	if _pending_damage.is_empty():
		return
	if status != Status.IN_WORLD:
		_pending_damage.clear()
		return
	var eids := _pending_damage.keys()
	var start := 0
	while start < eids.size():
		var n := mini(eids.size() - start, 255)
		var b := NetProto.writer(NetProto.C_DAMAGE_BATCH)
		b.put_u8(n)
		for i in n:
			var key: int = eids[start + i]
			var entry: Array = _pending_damage[key]
			b.put_u32(key if key >= 0 else -key - 1)
			b.put_u32(int(entry[0]))
			b.put_u8((1 if entry[2] else 0) | (NetProto.DAMAGE_POISON if key < 0 else 0) | (mini(int(entry[1]), NetProto.DAMAGE_MAX_HITS) << NetProto.DAMAGE_HITS_SHIFT))
		_send(b)
		start += n
	_pending_damage.clear()

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

func send_trade_request_id(character_id: int) -> void:
	var b := NetProto.writer(NetProto.C_TRADE_REQ_ID)
	b.put_u32(character_id)
	_send(b)

## Chợ Giao Thương: op + tham số (xem NetProto.C_MARKET). Server trả S_MARKET.
func send_market(op: String, args := {}) -> void:
	if status != Status.IN_WORLD:
		return
	var a: Dictionary = args.duplicate()
	a["op"] = op
	var b := NetProto.writer(NetProto.C_MARKET)
	NetProto.put_str(b, JSON.stringify(a))
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

## Khoá bảo vệ: gửi MÃ BĂM (SecurityLock._hash), không gửi mật mã gốc.
func send_security(op: int, hash1 := "", hash2 := "") -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_SECURITY)
	b.put_u8(op)
	NetProto.put_str(b, hash1)
	NetProto.put_str(b, hash2)
	_send(b)

## Bang hội: op = GuildServer.G_*, args = tham số.
func send_guild(op: int, args := {}) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_GUILD)
	b.put_u8(op)
	NetProto.put_str(b, JSON.stringify(args))
	_send(b)

## Chiến trường Tống Kim: op = BattleServer.OP_* (JOIN {side}).
## Hiệu thuốc: mua `count` bình `misc_id` (server trả S_NOTICE + S_PROFILE).
func send_shop_buy(misc_id: String, count: int) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_SHOP_BUY)
	NetProto.put_str(b, misc_id)
	b.put_u8(clampi(count, 1, PotionShop.MAX_COUNT))
	_send(b)

## Thợ rèn: sửa món `uid` ("" = sửa hết đồ còn sửa được), mode = NetProto.REPAIR_* (server trả S_NOTICE + S_PROFILE).
func send_repair(uid: String, mode: int) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_REPAIR)
	NetProto.put_str(b, uid)
	b.put_u8(mode)
	_send(b)

## S_ITEM_DUR: chép độ bền server vừa trừ vào hồ sơ đang dùng (câu báo "sắp hỏng / đã hỏng" đi riêng qua S_NOTICE;
## món hỏng bị tháo thì server gửi thêm S_PROFILE).
func _on_item_dur(b: StreamPeerBuffer) -> void:
	var prof: PlayerProfile = GameManager.local_profile
	for i in b.get_u8():
		var uid := NetProto.get_str(b, 64)
		var dur := b.get_16()
		var item := ItemDurability.find_by_uid(prof, uid)
		if item != null:
			item.durability = dur

## Ủy thác: op "buy" {mid, n} / "use" {uid} — server làm trên hồ sơ của nó rồi gửi S_NOTICE + S_PROFILE.
func send_uy_thac(op: String, args: Dictionary = {}) -> void:
	if status != Status.IN_WORLD:
		return
	var payload := args.duplicate()
	payload["op"] = op
	var b := NetProto.writer(NetProto.C_UY_THAC)
	NetProto.put_str(b, JSON.stringify(payload))
	_send(b)

## Chế tạo (Compound): server làm trên hồ sơ của nó rồi gửi S_NOTICE (kết quả) + S_PROFILE.
func send_craft(op: int, uids: Array, alt: Array) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_CRAFT)
	NetProto.put_str(b, JSON.stringify({"op": op, "uids": uids, "alt": alt}))
	_send(b)

## Hành trang: "split" {uid, n} — server tách chồng trên hồ sơ của nó rồi gửi S_PROFILE.
func send_item_op(op: String, args: Dictionary = {}) -> void:
	if status != Status.IN_WORLD:
		return
	var a := args.duplicate()
	a["op"] = op
	var w := NetProto.writer(NetProto.C_ITEM_OP)
	NetProto.put_str(w, JSON.stringify(a))
	_send(w)

## Sự kiện năm: "craft" {ev, recipe, items: {uid: n}, times} / "open" {uid} — server làm trên hồ sơ của nó rồi gửi S_NOTICE + S_PROFILE.
func send_event(op: String, args: Dictionary = {}) -> void:
	if status != Status.IN_WORLD:
		return
	var payload := args.duplicate()
	payload["op"] = op
	var b := NetProto.writer(NetProto.C_EVENT)
	NetProto.put_str(b, JSON.stringify(payload))
	_send(b)

## Dã Tẩu: server trao thưởng (claim_option / claim_milestone) trên hồ sơ của server rồi gửi S_NOTICE + S_PROFILE.
func send_da_tau(op: String, args: Dictionary = {}) -> void:
	if status != Status.IN_WORLD:
		return
	var payload := args.duplicate()
	payload["op"] = op
	var b := NetProto.writer(NetProto.C_DA_TAU)
	NetProto.put_str(b, JSON.stringify(payload))
	_send(b)

func send_battle(op: int, args := {}) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_BATTLE)
	b.put_u8(op)
	NetProto.put_str(b, JSON.stringify(args))
	_send(b)

## Đấu trường PK: op ArenaServer.OP_* + tham số json.
func send_arena(op: int, args := {}) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_ARENA)
	b.put_u8(op)
	NetProto.put_str(b, JSON.stringify(args))
	_send(b)

## Chiến Trường Sinh Tồn: op PubgServer.OP_* + tham số json. Gửi được cả từ Hub (kết nối sảnh) lẫn trong trận.
func send_pubg(op: int, args := {}) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_PUBG)
	b.put_u8(op)
	NetProto.put_str(b, JSON.stringify(args))
	_send(b)

## Lộn Xộn: op LonXonServer.OP_* + tham số json. Gửi được cả từ Hub (xem / vào host) lẫn trong host.
func send_lonxon(op: int, args := {}) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_LONXON)
	b.put_u8(op)
	NetProto.put_str(b, JSON.stringify(args))
	_send(b)

## Phòng train chung Vượt Ải: op FieldServer.OP_* + tham số json.
func send_field(op: int, args := {}) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_FIELD)
	b.put_u8(op)
	NetProto.put_str(b, JSON.stringify(args))
	_send(b)

func send_chat(channel: int, to_name: String, text: String) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_CHAT)
	b.put_u8(channel)
	NetProto.put_str(b, to_name)
	NetProto.put_str(b, text)
	_send(b)

## Tổ đội: op = SocialServer.TEAM_*, arg = eid người liên quan, arg2 = đồng ý / mở / chế độ nhặt.
## Hảo hữu: op = RelationServer.FRIEND_*.
func send_friend(op: int, eid := 0, arg := 0, name := "") -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_FRIEND)
	b.put_u8(op)
	b.put_u32(eid)
	b.put_u8(arg)
	NetProto.put_str(b, name)
	_send(b)

## Oẳn tù xì: gửi C_RPS {op, ...} (RpsServer.on_rps).
func send_rps(d: Dictionary) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_RPS)
	NetProto.put_str(b, JSON.stringify(d))
	_send(b)

## "Cừu sát": tuyên bố cừu sát người chơi `eid`.
func send_enmity(eid: int) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_ENMITY)
	b.put_u32(eid)
	_send(b)

## Đòn mình đánh trúng đối thủ cừu sát (PvpHit.encode).
func send_pvp_hit(eid: int, hit: PackedByteArray) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_PVP_HIT)
	b.put_u32(eid)
	b.put_u32(hit.size())
	b.put_data(hit)
	_send(b)

## "Tin tức": xin xem trang bị người chơi `eid` (server trả S_VIEW_EQUIP).
func send_view_equip(eid: int) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_VIEW_EQUIP)
	b.put_u32(eid)
	_send(b)

## Báo % máu của mình (gọi khi đổi) — server chuyển cho đồng đội + người xung quanh để vẽ thanh máu.
func send_hp(percent: int) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_HP)
	b.put_u8(clampi(percent, 0, 100))
	_send(b)

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

func send_revive() -> void:
	if status != Status.IN_WORLD:
		return
	_send(NetProto.writer(NetProto.C_REVIVE))

func send_look(look: Dictionary) -> void:
	if status != Status.IN_WORLD:
		return
	var b := NetProto.writer(NetProto.C_LOOK)
	for k in ["helm", "armor", "weapon", "horse"]:
		b.put_16(int(look.get(k, -1)))
	b.put_u8(int(look.get("gender", 0)))
	b.put_16(int(look.get("mask_particular", -1)))
	b.put_32(int(look.get("aura_state", 0)))
	NetProto.put_states(b, look.get("states", []))
	NetProto.put_aura(b, look)
	_send(b)

func _process(delta: float) -> void:
	if _peer == null:
		return
	var peer := _peer   # giữ tham chiếu để peer không bị giải phóng giữa lúc poll()
	peer.poll()
	if _peer != peer:
		return
	if status == Status.CONNECTING and Time.get_ticks_msec() / 1000.0 > _connect_deadline:
		_fail("timeout", "Máy chủ game không phản hồi")
		return
	while _peer and _peer.get_available_packet_count() > 0:
		_on_packet(_peer.get_packet())
	if status == Status.IN_WORLD:
		_tick_interp(delta)
		_damage_flush_timer -= delta
		if _damage_flush_timer <= 0.0:
			_flush_damage()
		_ping_timer -= delta
		if _ping_timer <= 0.0:
			_ping_timer = 1.0
			var b := NetProto.writer(NetProto.C_PING)
			b.put_u32(Time.get_ticks_msec())
			_send(b)

func _read_spawn(b: StreamPeerBuffer) -> void:
	var info := {
		"eid": b.get_u32(), "kind": b.get_u8(), "name": NetProto.get_str(b), "level": b.get_u16(), "camp": b.get_8(),
		"nation": b.get_u8(), "stall_title": NetProto.get_str(b), "pos": Vector2(b.get_float(), b.get_float()), "dir": b.get_u8(), "action": b.get_u8(), "z": b.get_u8(),
		"flags": b.get_u16(), "hp": b.get_u8(),
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
			_pending_damage.clear()   ## đòn gom từ phiên / map trước không gửi sang map mới
			_pending_mstate.clear()
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
				var pos := NetProto.get_state_pos(b)
				var da := b.get_u8()
				var st := {
					"pos": pos, "dir": da & 7, "action": da >> 3,
					"z": b.get_u8(), "flags": b.get_u16(), "hp": b.get_u8(),
				}
				entity_state.emit(eid, server_ms - b.get_u8() * NetProto.STATE_AGE_UNIT_MS, st)
		NetProto.S_CAST:
			var caster := b.get_u32()
			var sid := b.get_u16()
			var lv := b.get_u8()
			var cf := b.get_u8()
			var tgt := b.get_u32()
			player_cast.emit(caster, sid, lv, cf, tgt, NetProto.get_state_pos(b))
		NetProto.S_LOOK:
			var eid := b.get_u32()
			entity_look.emit(eid, NetProto.get_look(b))
		NetProto.S_MSTATE:
			var ms_eid := b.get_u32()
			var ms_n := b.get_u8()
			var ms_list := []
			for i in ms_n:
				if b.get_available_bytes() < 6:
					break
				ms_list.append([b.get_u32(), float(b.get_u16()) / 10.0])
			monster_states.emit(ms_eid, ms_list)
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
		NetProto.S_EVENT_TIMES:
			SeasonalEvents.apply_remote_overrides(JSON.parse_string(NetProto.get_str(b, 65535)))
			event_times_changed.emit()
		NetProto.S_ITEM_DUR:
			_on_item_dur(b)
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
		NetProto.S_MARKET:
			market_received.emit(NetProto.get_json(b))
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
		NetProto.S_TEAM_HP:
			var thp := []
			for i in b.get_u8():
				if b.get_available_bytes() < 6:
					break
				thp.append({"eid": b.get_u32(), "hp": b.get_u8(), "near": b.get_u8() != 0})
			team_hp.emit(thp)
		NetProto.S_GUILD:
			var raw := NetProto.get_str(b, 1 << 20)
			var parsed: Variant = JSON.parse_string(raw) if raw != "" else null
			guild_received.emit(parsed if parsed is Dictionary else {})
		NetProto.S_BATTLE:
			var msg: Variant = JSON.parse_string(NetProto.get_str(b, 1 << 16))
			if msg is Dictionary:
				battle_message.emit(msg)
		NetProto.S_PUBG:
			var pmsg := NetProto.get_json(b)
			if not pmsg.is_empty():
				pubg_message.emit(pmsg)
		NetProto.S_RPS:
			var rmsg: Variant = JSON.parse_string(NetProto.get_str(b, 1 << 14))
			if rmsg is Dictionary:
				rps_message.emit(rmsg)
		NetProto.S_LONXON:
			var lmsg := NetProto.get_json(b)
			if not lmsg.is_empty():
				lonxon_message.emit(lmsg)
		NetProto.S_ARENA:
			var amsg := NetProto.unpack_arena_msg(b)
			if not amsg.is_empty():
				arena_message.emit(amsg)
		NetProto.S_FIELD:
			var fmsg: Variant = JSON.parse_string(NetProto.get_str(b, 1 << 16))
			if fmsg is Dictionary:
				field_message.emit(fmsg)
		NetProto.S_PLAYER_GUILD:
			var geid := b.get_u32()
			var gname := NetProto.get_str(b)
			var gemblem := b.get_u16()
			player_guild_changed.emit(geid, gname, gemblem)
		NetProto.S_GUILD_LIST:
			var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 1 << 20))
			guild_list.emit(parsed if parsed is Array else [])
		NetProto.S_ENMITY:
			var est := b.get_u8()
			var eother := b.get_u32()
			var ename := NetProto.get_str(b)
			enmity_state.emit(est, eother, ename, b.get_u8() != 0)
		NetProto.S_PVP_HIT:
			var attacker := b.get_u32()
			var n := b.get_u32()
			if n <= PvpHit.MAX_BYTES and n <= b.get_available_bytes():
				var hit := PvpHit.decode(b.get_data(n)[1])
				if not hit.is_empty():
					pvp_hit.emit(attacker, hit)
		NetProto.S_CAMP:
			var ceid := b.get_u32()
			var cv := b.get_8()
			camp_changed.emit(ceid, cv, b.get_u8())
		NetProto.S_FRIEND_INVITE:
			var feid := b.get_u32()
			friend_invite.emit(feid, NetProto.get_str(b))
		NetProto.S_FRIEND_LIST:
			var parsed_f: Variant = JSON.parse_string(NetProto.get_str(b, 1 << 20))
			friend_list.emit(parsed_f if parsed_f is Array else [])
		NetProto.S_VIEW_EQUIP:
			view_equip.emit(NetProto.get_json(b))
		NetProto.S_GUILD_INVITE:
			var gname := NetProto.get_str(b)
			guild_invite.emit(gname, NetProto.get_str(b))
		NetProto.S_CHAT:
			var ch := b.get_u8()
			var from := b.get_u32()
			var from_name := NetProto.get_str(b)
			var to_name := NetProto.get_str(b)
			chat_received.emit(ch, from, from_name, to_name, NetProto.get_str(b))
		NetProto.S_TEAM_INVITE:
			var cap := b.get_u32()
			team_invite.emit(cap, NetProto.get_str(b))
		NetProto.S_TEAM_APPLY:
			var ap_eid := b.get_u32()
			var ap_name := NetProto.get_str(b)
			var ap_lvl := b.get_u16()
			team_apply.emit(ap_eid, ap_name, ap_lvl)
		NetProto.S_STALL_SIGN:
			var seid := b.get_u32()
			stall_sign.emit(seid, NetProto.get_str(b))
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
			var rtt := float(now - sent)
			rtt_ms = rtt if rtt_ms == 0.0 else lerpf(rtt_ms, rtt, 0.25)
			## Mẫu có RTT cao (gói bị giữ lại) cho lệch giờ sai -> bỏ; còn lại làm mục tiêu, clock_offset trượt dần tới.
			if clock_offset == 0.0 or rtt <= rtt_ms * 1.5 + 5.0:
				var offset := float(server_ms) + rtt * 0.5 - now
				if clock_offset == 0.0:
					clock_offset = offset
					_clock_target = offset
				else:
					_clock_target = lerpf(_clock_target, offset, 0.3)

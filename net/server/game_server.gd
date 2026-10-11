extends Node
class_name GameServer
## GAME SERVER (Godot headless) cho chế độ MAIN_MAP. Chạy:
##   godot --headless --path . res://net/server/game_server.tscn
## Cấu hình bằng biến môi trường (xem server/run_game_server.sh):
##   GAME_SERVICE_KEY  khóa gọi API nội bộ của server tài khoản (bắt buộc)
##   GAME_ACCOUNT_URL  địa chỉ server tài khoản           (mặc định http://127.0.0.1:8080)
##   GAME_SERVER_ID    mã máy chủ trong bảng game_servers  (mặc định 1)
##   GAME_ENET_PORT / GAME_WS_PORT                          (mặc định 7777 / 7778)
##   GAME_MAX_PLAYERS                                       (mặc định 2000)
##
## Nghe cùng lúc ENet (UDP — PC/mobile) và WebSocket (web). Mỗi kết nối: chờ C_HELLO (access token + mã nhân vật)
## -> hỏi server tài khoản -> vào map. Server mô phỏng 18 tick/giây, gửi vị trí 9 lần/giây theo lưới tầm nhìn (AOI).
##
## Di chuyển (B1): game tự chạy nhân vật rồi gửi vị trí; server KIỂM TRA (tốc độ tối đa theo "ngân sách quãng đường",
## ô vật cản, ra ngoài map) và kéo về vị trí hợp lệ nếu sai. Bước sau server sẽ tự tính cả chiêu thức / quái.

const MAP_DIR := "res://world/main_map"
const HELLO_TIMEOUT := 10.0
## Tốc độ tối đa chấp nhận (px/giây): lao chiêu ~390, nhảy 216 — để dư cho trễ mạng.
const MAX_SPEED := 440.0
## Ngân sách quãng đường tích tối đa (giây) — bù gói đến dồn do mạng giật, không cho tích lâu để dịch chuyển xa.
const MOVE_BUDGET_CAP := 1.2
const MAX_PACKETS_PER_SEC := 80

enum ConnState { WAIT_HELLO, AUTH, IN_WORLD, CLOSING }

class Conn:
	var key := ""
	var peer: MultiplayerPeer
	var peer_id := 0
	var state := ConnState.WAIT_HELLO
	var since := 0.0
	var entity: ServerEntity
	var account_id := 0
	var username := ""
	var character_id := 0
	var known: Dictionary = {}          ## eid -> version đã gửi cho người này
	var move_budget := 0.0              ## quãng đường (px) còn được phép đi
	var last_move_at := 0.0
	var packets := 0
	var packets_window := 0.0

var grid: MapGrid
var aoi := AoiGrid.new()
var account: AccountLink
var _enet := ENetMultiplayerPeer.new()
var _ws := WebSocketMultiplayerPeer.new()
var _conns: Dictionary = {}            ## key -> Conn
var _by_character: Dictionary = {}     ## character_id -> Conn (1 nhân vật chỉ online 1 nơi)
var _entities: Dictionary = {}         ## eid -> ServerEntity
var _next_eid := 1
var _tick := 0
var _acc := 0.0
var _now := 0.0
var max_players := 2000

func _ready() -> void:
	Engine.max_fps = 120
	grid = MapGrid.load_from(MAP_DIR)
	if grid == null:
		get_tree().quit(1)
		return
	account = AccountLink.new()
	account.base_url = _env("GAME_ACCOUNT_URL", "http://127.0.0.1:8080").trim_suffix("/")
	account.service_key = _env("GAME_SERVICE_KEY", "")
	account.server_id = int(_env("GAME_SERVER_ID", "1"))
	max_players = int(_env("GAME_MAX_PLAYERS", "2000"))
	add_child(account)
	if account.service_key == "":
		push_error("Thiếu GAME_SERVICE_KEY — game server không xác thực được người chơi")
		get_tree().quit(1)
		return
	var enet_port := int(_env("GAME_ENET_PORT", "7777"))
	var ws_port := int(_env("GAME_WS_PORT", "7778"))
	if _enet.create_server(enet_port, mini(max_players, 4095), 2) != OK:
		push_error("Không mở được cổng ENet %d" % enet_port)
		get_tree().quit(1)
		return
	if _ws.create_server(ws_port) != OK:
		push_error("Không mở được cổng WebSocket %d" % ws_port)
		get_tree().quit(1)
		return
	for p: MultiplayerPeer in [_enet, _ws]:
		p.peer_connected.connect(_on_peer_connected.bind(p))
		p.peer_disconnected.connect(_on_peer_disconnected.bind(p))
	print("Game server: map %dx%d ô, ENet :%d, WebSocket :%d, máy chủ %d, tài khoản %s" % [
		grid.cols, grid.rows, enet_port, ws_port, account.server_id, account.base_url])

func _env(k: String, def: String) -> String:
	var v := OS.get_environment(k)
	return v if v != "" else def

# ---------------------------------------------------------------- vòng lặp

func _process(delta: float) -> void:
	_now += delta
	for p: MultiplayerPeer in [_enet, _ws]:
		p.poll()
		while p.get_available_packet_count() > 0:
			var from := p.get_packet_peer()
			var pkt := p.get_packet()
			var c: Conn = _conns.get(_key(p, from))
			if c:
				_on_packet(c, pkt)
	_acc += delta
	var step := 1.0 / NetProto.TICK_RATE
	while _acc >= step:
		_acc -= step
		_tick += 1
		_simulate(step)
		if _tick % NetProto.SNAPSHOT_EVERY == 0:
			_send_snapshots()

func _simulate(_dt: float) -> void:
	for c: Conn in _conns.values():
		if c.state == ConnState.WAIT_HELLO and _now - c.since > HELLO_TIMEOUT:
			_kick(c, "timeout", "Hết thời gian chờ vào game")

# ---------------------------------------------------------------- kết nối

func _key(p: MultiplayerPeer, id: int) -> String:
	return ("e:" if p == _enet else "w:") + str(id)

func _on_peer_connected(id: int, p: MultiplayerPeer) -> void:
	var c := Conn.new()
	c.key = _key(p, id)
	c.peer = p
	c.peer_id = id
	c.since = _now
	_conns[c.key] = c

func _on_peer_disconnected(id: int, p: MultiplayerPeer) -> void:
	var c: Conn = _conns.get(_key(p, id))
	if c:
		_drop(c)

func _drop(c: Conn) -> void:
	_conns.erase(c.key)
	if c.character_id != 0 and _by_character.get(c.character_id) == c:
		_by_character.erase(c.character_id)
	if c.entity:
		aoi.remove(c.entity)
		_entities.erase(c.entity.eid)
		print("Rời map: %s (%s)" % [c.entity.name, c.username])

func _send(c: Conn, b: StreamPeerBuffer, channel := NetProto.CH_RELIABLE) -> void:
	var p := c.peer
	p.set_target_peer(c.peer_id)
	p.transfer_channel = channel
	p.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if channel == NetProto.CH_RELIABLE \
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	p.put_packet(b.data_array)

## Gửi lỗi rồi ngắt (chờ chút cho gói lỗi kịp đi).
func _kick(c: Conn, code: String, message: String) -> void:
	if c.state == ConnState.CLOSING:
		return
	var b := NetProto.writer(NetProto.S_ERROR)
	NetProto.put_str(b, code)
	NetProto.put_str(b, message)
	_send(c, b)
	c.state = ConnState.CLOSING
	if c.entity:
		aoi.remove(c.entity)
		_entities.erase(c.entity.eid)
		c.entity = null
	var peer := c.peer
	var id := c.peer_id
	var key := c.key
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if _conns.has(key):   ## còn kết nối (chưa tự ngắt) thì ngắt
			peer.disconnect_peer(id))

# ---------------------------------------------------------------- gói tin

func _on_packet(c: Conn, pkt: PackedByteArray) -> void:
	if pkt.is_empty() or c.state == ConnState.CLOSING:
		return
	## Chặn gửi dồn dập.
	if _now - c.packets_window > 1.0:
		c.packets_window = _now
		c.packets = 0
	c.packets += 1
	if c.packets > MAX_PACKETS_PER_SEC:
		_kick(c, "flood", "Gửi dữ liệu quá nhanh")
		return
	var b := NetProto.reader(pkt)
	var type := b.get_u8()
	match type:
		NetProto.C_HELLO:
			if c.state == ConnState.WAIT_HELLO:
				_on_hello(c, b)
		NetProto.C_MOVE:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 12:
				_on_move(c, b)
		NetProto.C_LOOK:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 8:
				_on_look(c, b)
		NetProto.C_PING:
			if b.get_available_bytes() >= 4:
				var r := NetProto.writer(NetProto.S_PONG)
				r.put_u32(b.get_u32())
				r.put_u32(Time.get_ticks_msec())
				_send(c, r)

func _on_hello(c: Conn, b: StreamPeerBuffer) -> void:
	var version := b.get_u16()
	var token := NetProto.get_str(b, 2048)
	var character_id := b.get_u32() if b.get_available_bytes() >= 4 else 0
	if version != NetProto.VERSION:
		_kick(c, "version", "Phiên bản game đã cũ, hãy cập nhật")
		return
	if _by_character.size() >= max_players:
		_kick(c, "full", "Máy chủ đã đầy, vui lòng thử lại sau")
		return
	c.state = ConnState.AUTH
	var r: Dictionary = await account.join(token, character_id)
	if not _conns.has(c.key) or c.state != ConnState.AUTH:
		return   ## đã ngắt trong lúc chờ
	if not r.ok:
		_kick(c, r.code, r.message)
		return
	var acc: Dictionary = r.account
	var ch: Dictionary = r.character
	## Nhân vật đang online ở nơi khác -> đá phiên cũ.
	var old: Conn = _by_character.get(character_id)
	if old and old != c:
		_kick(old, "logged_in_elsewhere", "Nhân vật vừa đăng nhập ở nơi khác")
	c.account_id = int(acc.id)
	c.username = str(acc.username)
	c.character_id = character_id
	_by_character[character_id] = c
	var data: Dictionary = ch.get("data", {}) if ch.get("data") is Dictionary else {}
	var e := ServerEntity.new()
	e.eid = _next_eid
	_next_eid += 1
	e.kind = NetProto.KIND_PLAYER
	e.name = str(ch.get("name", "?"))
	e.level = int(ch.get("level", 1))
	e.camp = int(data.get("camp", 0))
	e.look = look_from_profile(data)
	e.flags = NetProto.FLAG_RIDING if int(e.look.horse) >= 0 else 0
	e.pos = grid.free_near(grid.default_center())
	c.entity = e
	_entities[e.eid] = e
	aoi.update(e)
	c.state = ConnState.IN_WORLD
	c.move_budget = MAX_SPEED * MOVE_BUDGET_CAP
	c.last_move_at = _now
	var w := NetProto.writer(NetProto.S_WELCOME)
	w.put_u32(e.eid)
	w.put_float(e.pos.x)
	w.put_float(e.pos.y)
	NetProto.put_str(w, e.name)
	_send(c, w)
	print("Vào map: %s (%s) eid %d — online %d" % [e.name, c.username, e.eid, _by_character.size()])

## Ngoại hình từ dữ liệu nhân vật (PlayerProfile.to_dict) — cùng cách Player.refresh_appearance().
static func look_from_profile(data: Dictionary) -> Dictionary:
	var profile := PlayerProfile.from_dict(data)
	var gender_key := "female" if profile.gender == PlayerProfile.Gender.FEMALE else "male"
	var look := Equipment.get_appearance(profile.equipment, gender_key, profile.riding)
	look["gender"] = 1 if gender_key == "female" else 0
	return look

func _on_move(c: Conn, b: StreamPeerBuffer) -> void:
	var p := Vector2(b.get_float(), b.get_float())
	var dir := b.get_u8() & 7
	var action := clampi(b.get_u8(), 0, NetProto.ACTIONS.size() - 1)
	var z := b.get_u8()
	var flags := b.get_u8() & 0x0f
	var e := c.entity
	c.move_budget = minf(c.move_budget + (_now - c.last_move_at) * MAX_SPEED, MAX_SPEED * MOVE_BUDGET_CAP)
	c.last_move_at = _now
	var dist := e.pos.distance_to(p)
	var jumping := (flags & NetProto.FLAG_JUMPING) != 0
	var bad := not is_finite(p.x) or not is_finite(p.y) or not grid.in_bounds(p) or dist > c.move_budget + 16.0
	if not bad and grid.is_blocked(p) and not (jumping and grid.is_jumpable(p)) and not grid.is_blocked(e.pos):
		bad = true
	if bad:
		var r := NetProto.writer(NetProto.S_CORRECT)
		r.put_float(e.pos.x)
		r.put_float(e.pos.y)
		_send(c, r)
		return
	c.move_budget -= dist
	if p != e.pos or dir != e.dir or action != e.action or z != e.z or flags != e.flags:
		e.pos = p
		e.dir = dir
		e.action = action
		e.z = z
		e.flags = flags
		e.touch()
		aoi.update(e)

func _on_look(c: Conn, b: StreamPeerBuffer) -> void:
	## B1: ngoại hình do game báo (đổi trang bị / lên ngựa). Bước B3 server tự tính từ dữ liệu nhân vật.
	var e := c.entity
	var look := {"gender": e.look.get("gender", 0)}
	for k in ["helm", "armor", "weapon", "horse"]:
		look[k] = clampi(b.get_16(), -1, 4096)
	if look != e.look:
		e.look = look
		e.touch()
		e.set_meta("look_changed", true)

# ---------------------------------------------------------------- gửi trạng thái theo AOI

func _send_snapshots() -> void:
	var now_ms := Time.get_ticks_msec()
	for c: Conn in _conns.values():
		if c.state != ConnState.IN_WORLD or c.entity == null:
			continue
		var visible := {}
		var states := NetProto.writer(NetProto.S_STATE)
		states.put_u32(now_ms)
		states.put_u16(0)   ## số mục — ghi lại sau
		var n := 0
		for e in aoi.around(c.entity.pos):
			if e.eid == c.entity.eid:
				continue
			visible[e.eid] = true
			if not c.known.has(e.eid):
				var s := NetProto.writer(NetProto.S_SPAWN)
				e.write_spawn(s)
				_send(c, s)
				c.known[e.eid] = e.version
				continue
			if c.known[e.eid] == e.version:
				continue
			if e.has_meta("look_changed"):
				var l := NetProto.writer(NetProto.S_LOOK)
				l.put_u32(e.eid)
				NetProto.put_look(l, e.look)
				_send(c, l)
			e.write_state(states)
			c.known[e.eid] = e.version
			n += 1
		for eid in c.known.keys():
			if not visible.has(eid):
				c.known.erase(eid)
				var d := NetProto.writer(NetProto.S_DESPAWN)
				d.put_u32(eid)
				_send(c, d)
		if n > 0:
			states.seek(5)
			states.put_u16(n)
			_send(c, states, NetProto.CH_STATE)
	for e: ServerEntity in _entities.values():
		if e.has_meta("look_changed"):
			e.remove_meta("look_changed")

func online_count() -> int:
	return _by_character.size()

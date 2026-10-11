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
## Sát thương báo lên: tối đa mỗi giây, xa hơn khoảng này không tính.
const MAX_DAMAGE_PER_SEC := 30
const MAX_HIT_DISTANCE := 1200.0
## Lưu nhân vật lên server tài khoản tối đa mỗi chừng này giây (khi có thay đổi) + lúc thoát.
const SAVE_INTERVAL := 60.0
const MAX_PROFILE_PER_SEC := 2
## Đồ rơi: nằm trên đất chừng này giây; chủ (người hạ quái) được nhặt trước OWNER_SECONDS giây, sau đó ai cũng nhặt được.
const DROP_LIFETIME := 90.0
const DROP_OWNER_SECONDS := 30.0
const PICKUP_REACH := 200.0

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
	var damage_msgs := 0
	var damage_window := 0.0
	## Bản dữ liệu nhân vật của SERVER (PlayerProfile.to_dict) — nguồn sự thật về cấp / kinh nghiệm khi online.
	var data: Dictionary = {}
	var profile: PlayerProfile
	var char_version := 0
	var dirty := false
	var last_save := 0.0
	var saving := false
	var save_queued := false
	## Bị đá vì đăng nhập nơi khác: phiên mới nhận dữ liệu + version; lần lưu đang chạy của phiên cũ chuyển version sang đây.
	var handoff: Conn
	## Xã hội (SocialServer)
	var trade = null                    ## SocialServer.Trade đang tham gia
	var team = null                     ## SocialServer.Team đang ở
	var trade_open := false
	var stall_open := false
	var stall_title := ""
	## C_PROFILE đến dồn (quá MAX_PROFILE_PER_SEC): giữ bản mới nhất, xử lý ở tick sau thay vì bỏ.
	var pending_profile: Dictionary = {}
	var pending_ack := 0
	## Chat
	var muted_until := 0.0              ## giây unix (web Admin cấm chat)
	var last_chat := -100.0
	var last_world_chat := -100.0
	var max_hit := 2000.0
	var last_profile_at := -10.0
	## "Quà" server đã cho (nhặt đồ / tiền) mà game có thể chưa áp: [{seq, amount, item}] — gói C_PROFILE gửi trước khi
	## game nhận S_PICKED không được làm mất quà (server cộng lại phần game chưa xác nhận).
	var grant_seq := 0
	var grants: Array = []
	## Lần gửi bản chuẩn (S_PROFILE) gần nhất có seq này: bản game gửi lên với ack nhỏ hơn là bản CŨ (trước khi game nhận
	## bản chuẩn — VD vừa giao dịch xong) -> bỏ qua, không thì mất đồ / tiền vừa nhận.
	var min_ack := 0

var grid: MapGrid
var aoi := AoiGrid.new()
var account: AccountLink
var _enet := ENetMultiplayerPeer.new()
var _ws := WebSocketMultiplayerPeer.new()
var _conns: Dictionary = {}            ## key -> Conn
var _by_character: Dictionary = {}     ## character_id -> Conn (1 nhân vật chỉ online 1 nơi)
var _saving_chars: Dictionary = {}     ## character_id -> số lần lưu đang chạy (vào lại ngay sau khi thoát phải chờ)
var _entities: Dictionary = {}         ## eid -> ServerEntity
var _monsters: Array[ServerMonster] = []
var _players_by_eid: Dictionary = {}   ## eid -> Conn
## Đồ rơi trên đất: drop_id -> {pos, owner, free_at, until, amount, item (Dictionary)}
var _drops: Dictionary = {}
var _next_drop := 1
var _next_eid := 1
var _tick := 0
var _acc := 0.0
var _now := 0.0
var max_players := 2000
var social: SocialServer
var chat: ChatServer
var guild: GuildServer
## Hỏi server tài khoản trạng thái khoá / cấm chat của người đang online mỗi chừng này giây.
var STATUS_POLL_SECONDS := 30.0
var _status_polling := false
var _last_status_poll := 0.0
## Chế độ kiểm thử (GAME_TEST_MODE=1): mỗi quái chết luôn rớt thêm 1 túi tiền để bài test chắc chắn có đồ rơi. TẮT khi chạy thật.
var test_mode := false

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
	test_mode = _env("GAME_TEST_MODE", "0") == "1"
	if test_mode:
		push_warning("GAME_TEST_MODE=1: mỗi quái chết rớt thêm tiền (chỉ dùng khi kiểm thử)")
	add_child(account)
	if account.service_key == "":
		push_error("Thiếu GAME_SERVICE_KEY — game server không xác thực được người chơi")
		get_tree().quit(1)
		return
	_spawn_monsters()
	social = SocialServer.new(self)
	chat = ChatServer.new(self)
	guild = GuildServer.new(self)
	guild.load_all()
	STATUS_POLL_SECONDS = float(_env("GAME_STATUS_POLL", "30"))
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
	print("Game server: map %dx%d ô, %d quái, ENet :%d, WebSocket :%d, máy chủ %d, tài khoản %s" % [
		grid.cols, grid.rows, _monsters.size(), enet_port, ws_port, account.server_id, account.base_url])

## Quái theo bãi trong map.json (role "monster" có dữ liệu mẫu) — luôn tồn tại trên server, không phụ thuộc người chơi.
func _spawn_monsters() -> void:
	for n in grid.data.get("npcs", []):
		if str(n.get("role", "")) != "monster":
			continue
		var m := ServerMonster.from_entry(n, _next_eid)
		if m == null:
			continue
		_next_eid += 1
		_monsters.append(m)
		_entities[m.eid] = m
		aoi.update(m)

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
		social.tick(step, _now)
		guild.tick(step)
		for c: Conn in _conns.values():
			if not c.pending_profile.is_empty() and c.trade == null and _now - c.last_profile_at >= 1.0 / MAX_PROFILE_PER_SEC:
				_apply_profile(c, c.pending_profile, c.pending_ack)
		if _tick % NetProto.TICK_RATE == 0:
			_save_due()
			_prune_drops()
			if _now - _last_status_poll >= STATUS_POLL_SECONDS:
				_last_status_poll = _now
				_poll_status()
		if _tick % NetProto.SNAPSHOT_EVERY == 0:
			_send_snapshots()

func _simulate(_dt: float) -> void:
	for c: Conn in _conns.values():
		if c.state == ConnState.WAIT_HELLO and _now - c.since > HELLO_TIMEOUT:
			_kick(c, "timeout", "Hết thời gian chờ vào game")
	## Quái chỉ "thức" ở ô có người chơi trong vòng 2 ô (rộng hơn tầm nhìn 1 ô để quái kịp đi tới) — vùng vắng không tốn CPU.
	var awake := {}
	for c: Conn in _conns.values():
		if c.entity != null and c.state == ConnState.IN_WORLD:
			var cell := aoi.cell_of(c.entity.pos)
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					awake[cell + Vector2i(dx, dy)] = true
	for m in _monsters:
		if m.hidden:
			if _now >= m.dead_at + m.respawn_seconds:
				m.reset()
				_entities[m.eid] = m
				aoi.update(m)
			continue
		if m.is_dead():
			if _now >= m.dead_at + ServerMonster.CORPSE_SECONDS:
				m.hidden = true
				aoi.remove(m)
				_entities.erase(m.eid)
			continue
		if awake.has(m.cell):
			m.tick(self)

## Người chơi còn sống gần nhất trong tầm nhìn (đơn vị logic) của quái.
func nearest_player(feet: Vector2, vision_logic: float) -> ServerEntity:
	var here := VltkMath.to_logic(feet)
	var best: ServerEntity = null
	var best_d := vision_logic
	for e in aoi.around(feet):
		if e.kind != NetProto.KIND_PLAYER or (e.flags & NetProto.FLAG_DEAD) != 0:
			continue
		var d := here.distance_to(VltkMath.to_logic(e.pos))
		if d <= best_d:
			best_d = d
			best = e
	return best

## Quái bắt đầu ra chiêu: báo cho mọi người đang thấy quái (máy người bị nhắm chạy đòn thật).
func monster_attack(m: ServerMonster, slot: int, target: ServerEntity) -> void:
	var b := NetProto.writer(NetProto.S_MATTACK)
	b.put_u32(m.eid)
	b.put_u8(slot)
	b.put_u32(target.eid)
	b.put_u8(m.dir)
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD and (c.known.has(m.eid) or c.entity == target):
			_send(c, b)

# ---------------------------------------------------------------- kết nối

func _key(p: MultiplayerPeer, id: int) -> String:
	return ("e:" if p == _enet else "w:") + str(id)

func _on_peer_connected(id: int, p: MultiplayerPeer) -> void:
	if p == _enet:
		NetProto.tune_enet_peer(_enet.get_peer(id))
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
	if c.entity:
		social.on_leave(c)
	_conns.erase(c.key)
	if c.dirty and c.character_id != 0:
		_save(c)   ## lưu lần cuối (chạy nền, không cần kết nối còn sống)
	elif c.save_queued == false and c.saving and c.character_id != 0:
		c.save_queued = c.dirty
	if c.character_id != 0 and _by_character.get(c.character_id) == c:
		_by_character.erase(c.character_id)
	if c.entity:
		aoi.remove(c.entity)
		_entities.erase(c.entity.eid)
		_players_by_eid.erase(c.entity.eid)
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
	if c.entity and c.state == ConnState.IN_WORLD:
		social.on_leave(c)   ## huỷ giao dịch, rời đội trước khi mất thực thể
	c.state = ConnState.CLOSING
	if c.entity:
		aoi.remove(c.entity)
		_entities.erase(c.entity.eid)
		_players_by_eid.erase(c.entity.eid)
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
		NetProto.C_DAMAGE:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 9:
				_on_damage(c, b)
		NetProto.C_PROFILE:
			if c.state == ConnState.IN_WORLD:
				_on_profile(c, b)
		NetProto.C_TRADE_REQ:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 4:
				social.on_trade_request(c, b.get_u32())
		NetProto.C_TRADE_ANSWER:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 5:
				var from := b.get_u32()
				social.on_trade_answer(c, from, b.get_u8() != 0)
		NetProto.C_TRADE_OP:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 1:
				social.on_trade_op(c, b)
		NetProto.C_STALL:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 1:
				social.on_stall(c, b)
		NetProto.C_GUILD:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 3:
				guild.on_guild(c, b)
		NetProto.C_CHAT:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 3:
				chat.on_chat(c, b)
		NetProto.C_TEAM:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 1:
				social.on_team(c, b)
		NetProto.C_PICKUP:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 4:
				_on_pickup(c, b.get_u32())
		NetProto.C_DISCARD:
			if c.state == ConnState.IN_WORLD:
				_on_discard(c, NetProto.get_str(b, 64))
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
	## Nhân vật vừa thoát và đang lưu lần cuối: chờ lưu xong rồi mới nạp (không thì nạp bản cũ, lần lưu sau bị lệch version).
	var waited := 0.0
	while _saving_chars.has(character_id) and not _by_character.has(character_id) and waited < 8.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
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
	var take_over: Conn = null
	if old and old != c and old.profile != null:
		take_over = old
		old.character_id = 0      ## phiên cũ không tự lưu nữa
		old.handoff = c
		_kick(old, "logged_in_elsewhere", "Nhân vật vừa đăng nhập ở nơi khác")
	elif old and old != c:
		_kick(old, "logged_in_elsewhere", "Nhân vật vừa đăng nhập ở nơi khác")
	c.account_id = int(acc.id)
	c.muted_until = _unix_of(acc.get("muted_until"))
	c.username = str(acc.username)
	c.character_id = character_id
	_by_character[character_id] = c
	var data: Dictionary = ch.get("data", {}) if ch.get("data") is Dictionary else {}
	if int(data.get("server_seen", 0)) == 0:
		data = ProfileGuard.sanitize_new(data)
	c.profile = PlayerProfile.from_dict(data)
	c.data = c.profile.to_dict()   ## gán uid cho đồ cũ chưa có — rồi gửi bản chuẩn này xuống game (S_PROFILE)
	c.dirty = true
	c.char_version = int(ch.get("version", 0))
	if take_over:   ## dữ liệu trong RAM của phiên cũ mới nhất (có thể chưa kịp lưu)
		c.data = take_over.data
		c.profile = take_over.profile
		c.char_version = take_over.char_version
		c.grant_seq = take_over.grant_seq
	c.last_save = _now
	c.max_hit = ProfileGuard.max_hit(c.profile)
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
	_players_by_eid[e.eid] = c
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
	guild.on_join(c)
	send_profile(c)
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
	var flags := (b.get_u8() & NetProto.CLIENT_FLAGS) | (c.entity.flags & ~NetProto.CLIENT_FLAGS)
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

## Sát thương người chơi gây cho quái (tính ở máy người đánh bằng pipeline chiêu hiện có). Server kiểm tra: quái còn sống,
## đủ gần, không vượt trần sát thương của chính nhân vật (ProfileGuard.max_hit), không gửi dồn dập.
func _on_damage(c: Conn, b: StreamPeerBuffer) -> void:
	var m_eid := b.get_u32()
	var amount := float(b.get_u32())
	var staggers := (b.get_u8() & 1) != 0
	if _now - c.damage_window > 1.0:
		c.damage_window = _now
		c.damage_msgs = 0
	c.damage_msgs += 1
	if c.damage_msgs > MAX_DAMAGE_PER_SEC:
		return
	var m := _entities.get(m_eid) as ServerMonster
	if m == null or m.is_dead() or (c.entity.flags & NetProto.FLAG_DEAD) != 0:
		return
	if m.pos.distance_to(c.entity.pos) > MAX_HIT_DISTANCE:
		return
	amount = minf(amount, c.max_hit)
	if m.receive_damage(c.entity.eid, amount, staggers):
		_on_monster_killed(m)

## Quái chết: thưởng cho người đánh (kinh nghiệm theo phần sát thương; rớt đồ cho người hạ đòn cuối), hẹn giờ ẩn xác + hồi sinh.
func _on_monster_killed(m: ServerMonster) -> void:
	m.dead_at = _now
	var total := 0.0
	for v in m.contributors.values():
		total += float(v)
	## Kinh nghiệm: đội của người hạ đòn cuối chia theo luật tổ đội; người góp sức ngoài đội nhận theo phần sát thương.
	var killer_conn: Conn = _players_by_eid.get(m.last_hitter)
	var team_got: Dictionary = {}
	if killer_conn:
		team_got = social.team_exp(killer_conn, m.pos, MonsterData.stat_at_level(m.data, "exp", m.level), m.level)
	for c: Conn in team_got:
		_give_exp(c, int(team_got[c]))
	for eid in m.contributors:
		var c: Conn = _players_by_eid.get(eid)
		if c == null:
			continue
		var share := clampi(roundi(float(m.contributors[eid]) / maxf(total, 1.0) * 100.0), 0, 100)
		var b := NetProto.writer(NetProto.S_KILL)
		b.put_u32(m.eid)
		b.put_u16(m.monster_id)
		b.put_u16(m.level)
		b.put_u8(m.series)
		b.put_u8(1 if m.blue_boss else 0)
		b.put_float(m.pos.x)
		b.put_float(m.pos.y)
		b.put_u8(share | (0x80 if eid == m.last_hitter else 0))
		_send(c, b)
		if not team_got.has(c):
			_grant_exp(c, m, share)
	## Rớt đồ: server tung xúc xắc theo bảng gốc, đồ thuộc người hạ đòn cuối (DROP_OWNER_SECONDS giây đầu).
	var rolls := DropTable.roll_blue_boss(m.level, m.series) if m.blue_boss else DropTable.roll(m.level, m.series)
	var placed: Array = []
	for i in rolls.size():
		var off := Vector2(randf_range(-22, 22), randf_range(-8, 8)) * (1.0 if rolls.size() > 1 else 0.4)
		var d: Dictionary = rolls[i]
		placed.append(_add_drop(m.pos + off, m.last_hitter, int(d.get("amount", 0)) if str(d.type) == "money" else 0,
			(d.item as ItemInstance).to_dict() if str(d.type) == "item" else {}))
	var killer: Conn = _players_by_eid.get(m.last_hitter)
	if test_mode and killer and killer.entity:   ## kiểm thử: luôn có 1 túi tiền + 1 món đồ ngay dưới chân người hạ quái
		placed.append(_add_drop(killer.entity.pos, m.last_hitter, 7, {}))
		placed.append(_add_drop(killer.entity.pos, m.last_hitter, 0, ItemGenerator.random_equipment(maxi(1, m.level)).to_dict()))
	_broadcast_drops(m.pos, placed)

## Kinh nghiệm do server cộng vào bản nhân vật của server rồi báo game (S_PROGRESS).
func _grant_exp(c: Conn, m: ServerMonster, share: int) -> void:
	if c.profile == null:
		return
	_give_exp(c, ProfileGuard.exp_for_kill(c.profile.level, m.data, m.level, share))

func _give_exp(c: Conn, got: int) -> void:
	if got <= 0 or c.profile == null:
		return
	var before := c.profile.level
	c.profile.add_exp(got)
	c.data["level"] = c.profile.level
	c.data["exp"] = c.profile.current_exp
	c.data["skill_points"] = c.profile.skill_points
	c.data["potential_points"] = c.profile.potential_points
	c.data["max_stamina"] = c.profile.max_stamina
	c.data["stamina"] = c.profile.stamina
	c.dirty = true
	if c.profile.level != before and c.entity:
		c.entity.level = c.profile.level
		c.entity.touch()
		c.max_hit = ProfileGuard.max_hit(c.profile)
	var b := NetProto.writer(NetProto.S_PROGRESS)
	b.put_u32(got)
	b.put_u16(c.profile.level)
	b.put_64(c.profile.current_exp)
	_send(c, b)

## Game gửi bản nhân vật mới (đổi trang bị, cộng điểm, túi đồ...): gộp theo luật ProfileGuard.
func _on_profile(c: Conn, b: StreamPeerBuffer) -> void:
	var ack := b.get_u32() if b.get_available_bytes() >= 4 else 0
	var client := NetProto.get_json(b)
	if client.is_empty():
		return
	## Đang giao dịch: đồ đang nằm trong phòng giao dịch ở server -> bỏ qua bản game gửi (xong giao dịch server gửi bản chuẩn).
	if c.trade != null or ack < c.min_ack:
		return
	if _now - c.last_profile_at < 1.0 / MAX_PROFILE_PER_SEC:
		c.pending_profile = client
		c.pending_ack = ack
		return
	_apply_profile(c, client, ack)

func _apply_profile(c: Conn, client: Dictionary, ack: int) -> void:
	c.last_profile_at = _now
	c.pending_profile = {}
	## Quà game chưa xác nhận (seq > ack): cộng lại vào bản gộp.
	var pending: Array = []
	var pending_gold := 0
	for g in c.grants:
		if int(g.seq) > ack:
			pending.append(g)
			pending_gold += int(g.amount)
	c.grants = pending
	var merged := ProfileGuard.merge(c.data, client, pending_gold)
	var money_from_server: bool = merged.get("_money_from_server", false)
	merged.erase("_money_from_server")
	var p := PlayerProfile.from_dict(merged)
	if not pending.is_empty():
		var have := ProfileGuard.items_by_uid(merged)
		for g in pending:
			if int(g.amount) > 0:
				if not money_from_server:   ## tiền server đã gồm khoản này
					p.gold += int(g.amount)
			elif not have.has(str(g.item.get("uid", ""))):
				p.add_item(ItemInstance.from_dict(g.item))
		merged = p.to_dict()
	c.data = merged
	c.profile = p
	c.max_hit = ProfileGuard.max_hit(c.profile)
	c.dirty = true

## Gửi bản nhân vật chuẩn của server xuống game.
func send_profile(c: Conn) -> void:
	c.grants.clear()   ## game sẽ chép nguyên bản này -> mọi quà đã nằm trong đó
	c.grant_seq += 1
	c.min_ack = c.grant_seq
	var b := NetProto.writer(NetProto.S_PROFILE)
	b.put_u32(c.grant_seq)
	NetProto.put_json(b, c.data)
	_send(c, b)
	if c.entity and c.profile and not c.profile.guild.is_empty():
		guild.send_guild(c)   ## bản bang có cờ "của mình" (S_PROFILE chép bản chung)

func notice(c: Conn, text: String) -> void:
	var b := NetProto.writer(NetProto.S_NOTICE)
	NetProto.put_str(b, text)
	_send(c, b)

# ---------------------------------------------------------------- đồ rơi

func _add_drop(pos: Vector2, owner_eid: int, amount: int, item: Dictionary) -> int:
	var id := _next_drop
	_next_drop += 1
	_drops[id] = {"pos": pos, "owner": owner_eid, "free_at": _now + DROP_OWNER_SECONDS, "until": _now + DROP_LIFETIME,
		"amount": amount, "item": item}
	return id

## Báo đồ rơi cho mọi người đang ở gần (3x3 ô AOI quanh chỗ rơi).
func _broadcast_drops(at: Vector2, ids: Array) -> void:
	if ids.is_empty():
		return
	var b := NetProto.writer(NetProto.S_DROPS)
	b.put_u16(ids.size())
	for id in ids:
		var d: Dictionary = _drops[id]
		b.put_u32(id)
		b.put_float(d.pos.x)
		b.put_float(d.pos.y)
		b.put_u32(int(d.owner))
		if int(d.amount) > 0:
			b.put_u8(0)
			b.put_u32(int(d.amount))
		else:
			b.put_u8(1)
			NetProto.put_str(b, JSON.stringify(d.item))
	for e in aoi.around(at):
		var c: Conn = _players_by_eid.get(e.eid)
		if c:
			_send(c, b)

func _drop_gone(id: int) -> void:
	var d: Dictionary = _drops.get(id, {})
	_drops.erase(id)
	if d.is_empty():
		return
	var b := NetProto.writer(NetProto.S_DROP_GONE)
	b.put_u32(id)
	for e in aoi.around(d.pos):
		var c: Conn = _players_by_eid.get(e.eid)
		if c:
			_send(c, b)

func _prune_drops() -> void:
	for id in _drops.keys():
		if _now > float(_drops[id].until):
			_drop_gone(id)

func _on_pickup(c: Conn, id: int) -> void:
	var d: Dictionary = _drops.get(id, {})
	if d.is_empty():
		return
	if c.entity.pos.distance_to(d.pos) > PICKUP_REACH:
		notice(c, "Đứng gần hơn mới nhặt được")
		return
	## Trong DROP_OWNER_SECONDS đầu: cùng đội với chủ đồ thì theo luật nhặt của đội; người ngoài thì chỉ chủ được nhặt.
	if int(d.owner) != 0 and _now < float(d.free_at):
		var owner: Conn = conn_of_eid(int(d.owner))
		if owner and owner.team and owner.team == c.team:
			if not social.team_can_pick(c, int(d.owner)):
				notice(c, "Theo luật nhặt đồ của tổ đội, chưa tới lượt bạn nhặt.")
				return
		elif int(d.owner) != c.entity.eid:
			notice(c, "Đồ này của người khác, chưa nhặt được")
			return
	var b := NetProto.writer(NetProto.S_PICKED)
	c.grant_seq += 1
	b.put_u32(c.grant_seq)
	b.put_u32(id)
	if int(d.amount) > 0:
		c.profile.gold += int(d.amount)
		c.grants.append({"seq": c.grant_seq, "amount": int(d.amount), "item": {}})
		b.put_u8(0)
		b.put_u32(int(d.amount))
	else:
		var item := ItemInstance.from_dict(d.item)
		if not c.profile.add_item(item):
			c.grant_seq -= 1
			notice(c, "Hành trang đã đầy")
			return
		c.grants.append({"seq": c.grant_seq, "amount": 0, "item": item.to_dict()})
		b.put_u8(1)
		NetProto.put_str(b, JSON.stringify(item.to_dict()))
	c.data = c.profile.to_dict()
	c.dirty = true
	_send(c, b)
	_drop_gone(id)
	social.team_picked(c)

## Vứt món trong túi xuống đất: server bỏ khỏi hồ sơ rồi đặt thành đồ rơi ai cũng nhặt được.
func _on_discard(c: Conn, uid: String) -> void:
	for i in c.profile.inventory.size():
		var it: ItemInstance = c.profile.inventory[i]
		if it.uid == uid:
			if SecurityLock.is_item_locked(it):
				return
			c.profile.inventory.remove_at(i)
			c.data = c.profile.to_dict()
			c.dirty = true
			it.room_x = -1
			it.room_y = -1
			var id := _add_drop(c.entity.pos + Vector2(randf_range(-14, 14), 6), 0, 0, it.to_dict())
			_broadcast_drops(c.entity.pos, [id])
			return

## Hồ sơ server vừa đổi (giao dịch, mua bán...): chụp lại dữ liệu, đánh dấu lưu, gửi bản chuẩn xuống game.
func profile_changed(c: Conn) -> void:
	c.data = c.profile.to_dict()
	c.dirty = true
	c.max_hit = ProfileGuard.max_hit(c.profile)
	if _conns.has(c.key) and c.state == ConnState.IN_WORLD:
		send_profile(c)

func in_world_conns() -> Array:
	var out := []
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD and c.entity:
			out.append(c)
	return out

func conn_of_eid(eid: int) -> Conn:
	var c: Conn = _players_by_eid.get(eid)
	return c if c and c.state == ConnState.IN_WORLD and _conns.has(c.key) else null

func now() -> float:
	return _now

func conn_of_name(character_name: String) -> Conn:
	var key := character_name.strip_edges().to_lower()
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD and c.entity and c.entity.name.to_lower() == key:
			return c
	return null

## Thời điểm RFC3339 (JSON từ server tài khoản) -> giây unix; null / rỗng -> 0.
static func _unix_of(v: Variant) -> float:
	if v == null or str(v) == "":
		return 0.0
	return float(Time.get_unix_time_from_datetime_string(str(v).left(19))) - _tz_offset(str(v))

static func _tz_offset(s: String) -> float:
	## "...+07:00" / "...Z": Time.get_unix_time_from_datetime_string coi chuỗi là UTC -> trừ độ lệch múi giờ.
	if s.ends_with("Z") or s.length() < 6:
		return 0.0
	var tail := s.right(6)
	if tail[0] != "+" and tail[0] != "-":
		return 0.0
	var secs := int(tail.substr(1, 2)) * 3600 + int(tail.substr(4, 2)) * 60
	return float(secs if tail[0] == "+" else -secs)

## Áp ngay lệnh khoá / cấm chat từ web Admin cho người đang online.
func _poll_status() -> void:
	if _status_polling:
		return
	var ids := []
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD and c.account_id != 0:
			ids.append(c.account_id)
	if ids.is_empty():
		return
	_status_polling = true
	var r: Dictionary = await account.status(ids)
	_status_polling = false
	if not r.ok:
		return
	var st: Dictionary = r.get("statuses", {})
	for c: Conn in _conns.values():
		var s: Variant = st.get(str(c.account_id))
		if not s is Dictionary or c.state != ConnState.IN_WORLD:
			continue
		c.muted_until = _unix_of(s.get("muted_until"))
		if bool(s.get("banned", false)):
			_kick(c, "banned", str(s.get("ban_message", "Tài khoản đã bị khoá")))

func send(c: Conn, b: StreamPeerBuffer) -> void:
	_send(c, b)

func _save_due() -> void:
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD and c.dirty and not c.saving and _now - c.last_save >= SAVE_INTERVAL:
			_save(c)

## Lưu tuần tự: đang có lần lưu chạy thì xếp hàng, lưu xong sẽ lưu tiếp bản mới nhất (2 lần lưu chồng nhau cùng version
## thì 1 lần bị từ chối -> mất dữ liệu).
func _save(c: Conn) -> void:
	if c.saving:
		c.save_queued = true
		return
	c.saving = true
	c.dirty = false
	c.last_save = _now
	var char_id := c.character_id
	_saving_chars[char_id] = int(_saving_chars.get(char_id, 0)) + 1
	var r: Dictionary = await account.save_character(char_id, c.char_version, c.data)
	_saving_chars[char_id] = int(_saving_chars[char_id]) - 1
	if int(_saving_chars[char_id]) <= 0:
		_saving_chars.erase(char_id)
	c.saving = false
	if r.ok and c.handoff:
		c.handoff.char_version = int(r.version)   ## phiên mới (đã nhận dữ liệu) lưu tiếp bằng version mới
	if c.save_queued:
		c.save_queued = false
		if r.ok:
			c.char_version = int(r.version)
		_save(c)
		return
	if r.ok:
		c.char_version = int(r.version)
		if _conns.has(c.key) and c.state == ConnState.IN_WORLD:
			var b := NetProto.writer(NetProto.S_SAVED)
			b.put_u32(c.char_version)
			_send(c, b)
	else:
		c.dirty = true
		push_warning("Lưu nhân vật %d lỗi: %s" % [c.character_id, r.get("message", "")])

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
		## Thực thể mới vào tầm / rời tầm: gộp vào 1 gói mỗi loại (vào map gặp ~50 quái = 1 gói thay vì 50).
		var spawns := NetProto.writer(NetProto.S_SPAWNS)
		spawns.put_u16(0)
		var n_spawn := 0
		for e in aoi.around(c.entity.pos):
			if e.eid == c.entity.eid:
				continue
			visible[e.eid] = true
			if not c.known.has(e.eid):
				e.write_spawn(spawns)
				n_spawn += 1
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
		var gone: Array = []
		for eid in c.known.keys():
			if not visible.has(eid):
				c.known.erase(eid)
				gone.append(eid)
		if not gone.is_empty():
			var d := NetProto.writer(NetProto.S_DESPAWNS)
			d.put_u16(gone.size())
			for eid in gone:
				d.put_u32(eid)
			_send(c, d)
		if n_spawn > 0:
			spawns.seek(1)
			spawns.put_u16(n_spawn)
			_send(c, spawns)
		if n > 0:
			states.seek(5)
			states.put_u16(n)
			_send(c, states, NetProto.CH_STATE)
	for e: ServerEntity in _entities.values():
		if e.has_meta("look_changed"):
			e.remove_meta("look_changed")

func online_count() -> int:
	return _by_character.size()

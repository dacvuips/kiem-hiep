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
	var max_hit := 2000.0
	var last_profile_at := -10.0

var grid: MapGrid
var aoi := AoiGrid.new()
var account: AccountLink
var _enet := ENetMultiplayerPeer.new()
var _ws := WebSocketMultiplayerPeer.new()
var _conns: Dictionary = {}            ## key -> Conn
var _by_character: Dictionary = {}     ## character_id -> Conn (1 nhân vật chỉ online 1 nơi)
var _entities: Dictionary = {}         ## eid -> ServerEntity
var _monsters: Array[ServerMonster] = []
var _players_by_eid: Dictionary = {}   ## eid -> Conn
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
	_spawn_monsters()
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
		if _tick % NetProto.TICK_RATE == 0:
			_save_due()
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
	_conns.erase(c.key)
	if c.dirty and c.character_id != 0:
		_save(c)   ## lưu lần cuối (chạy nền, không cần kết nối còn sống)
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
	c.data = data
	c.profile = PlayerProfile.from_dict(data)
	c.char_version = int(ch.get("version", 0))
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
		_grant_exp(c, m, share)

## Kinh nghiệm do server cộng vào bản nhân vật của server rồi báo game (S_PROGRESS).
func _grant_exp(c: Conn, m: ServerMonster, share: int) -> void:
	if c.profile == null:
		return
	var got := ProfileGuard.exp_for_kill(c.profile.level, m.data, m.level, share)
	if got <= 0:
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
	if _now - c.last_profile_at < 1.0 / MAX_PROFILE_PER_SEC:
		return
	c.last_profile_at = _now
	var client := NetProto.get_json(b)
	if client.is_empty():
		return
	c.data = ProfileGuard.merge(c.data, client)
	c.profile = PlayerProfile.from_dict(c.data)
	c.max_hit = ProfileGuard.max_hit(c.profile)
	c.dirty = true

func _save_due() -> void:
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD and c.dirty and not c.saving and _now - c.last_save >= SAVE_INTERVAL:
			_save(c)

func _save(c: Conn) -> void:
	c.saving = true
	c.dirty = false
	c.last_save = _now
	var r: Dictionary = await account.save_character(c.character_id, c.char_version, c.data)
	c.saving = false
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

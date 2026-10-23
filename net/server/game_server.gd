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
##   GAME_MAP_DIR      thư mục map server chạy             (mặc định DEFAULT_MAP_DIR)
##   GAME_BATTLE=1     tiến trình CHIẾN TRƯỜNG TỐNG KIM (BattleServer) — chạy map chiến trường, cổng riêng; xem BattleServer
##   GAME_FIELD=1      tiến trình PHÒNG TRAIN CHUNG (FieldServer) — map luyện công / Địa Ngục của màn Vượt Ải, mỗi phòng 1 bản map riêng
##
## Nghe cùng lúc ENet (UDP — PC/mobile) và WebSocket (web). Mỗi kết nối: chờ C_HELLO (access token + mã nhân vật)
## -> hỏi server tài khoản -> vào map. Server mô phỏng 18 tick/giây, gửi vị trí 9 lần/giây theo lưới tầm nhìn (AOI).
##
## Di chuyển (B1): game tự chạy nhân vật rồi gửi vị trí; server KIỂM TRA (tốc độ tối đa theo "ngân sách quãng đường",
## ô vật cản, ra ngoài map) và kéo về vị trí hợp lệ nếu sai. Bước sau server sẽ tự tính cả chiêu thức / quái.

const DEFAULT_MAP_DIR := "res://world/maps/map_321"   ## map chính đã bỏ: server chạy map Trường Bạch Sơn Nam 1 (Vượt Ải)
const HELLO_TIMEOUT := 10.0
## Quái mô phỏng mỗi chừng này tick (= NetProto.SNAPSHOT_EVERY: vị trí chỉ gửi đi theo nhịp này nên bước nhỏ hơn không ai thấy).
const MONSTER_TICK_EVERY := 2
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
## Gói được phép từ kết nối SẢNH — mọi gói "trong map" khác (di chuyển, ra chiêu, sát thương, nhặt / vứt đồ, PK, cừu sát, xem trang bị
## người đứng gần, giao dịch / bày bán tại chỗ, chiến trường / đấu trường / phòng train chung...) bị bỏ qua.
const HUB_ALLOWED := [NetProto.C_PROFILE, NetProto.C_MARKET, NetProto.C_TRADE_REQ_ID, NetProto.C_TRADE_ANSWER, NetProto.C_TRADE_OP,
	NetProto.C_CHAT, NetProto.C_TEAM, NetProto.C_GUILD, NetProto.C_FRIEND, NetProto.C_SECURITY, NetProto.C_PING]

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
	var known: Dictionary = {}          ## eid đang thấy (đã gửi gói xuất hiện)
	var view_cell := Vector2i(1 << 30, 1 << 30)   ## ô AOI tâm lúc gửi trước
	var move_budget := 0.0              ## quãng đường (px) còn được phép đi
	var last_move_at := 0.0
	var packets := 0
	var packets_window := 0.0
	var damage_msgs := 0
	var cast_msgs := 0
	var last_view_equip := -100.0
	## Cừu sát (RelationServer): {other, state, until, launcher}; {} = không.
	var enmity: Dictionary = {}
	var pvp_msgs := 0
	var pvp_window := 0.0
	var last_pvp_from := 0
	var last_pvp_at := -100.0
	var cast_window := 0.0
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
	## Kết nối SẢNH (Character Hub, NetProto.HELLO_HUB): nhân vật không đứng trên map (không vào lưới tầm nhìn, room_id -1 = không
	## "gần" ai), chỉ được gửi các gói trong HUB_ALLOWED — dùng cho Chợ, giao dịch theo ID, chat, tổ đội, bang, bạn bè từ Hub.
	var hub := false
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
	var max_speed := MAX_SPEED          ## px/giây được phép — theo tốc chạy thật của nhân vật (ProfileGuard.max_speed)
	var last_profile_at := -10.0
	## "Quà" server đã cho (nhặt đồ / tiền) mà game có thể chưa áp: [{seq, amount, item}] — gói C_PROFILE gửi trước khi
	## game nhận S_PICKED không được làm mất quà (server cộng lại phần game chưa xác nhận).
	var grant_seq := 0
	var grants: Array = []
	## Quà chờ từ web (đổi Xu -> Nguyên bảo): id đã cộng vào RAM (chống cộng 2 lần) / id chưa lưu (gửi kèm lần lưu tới).
	var seen_web_grants: Dictionary = {}
	var unsaved_web_grants: Array = []
	## Lần gửi bản chuẩn (S_PROFILE) gần nhất có seq này: bản game gửi lên với ack nhỏ hơn là bản CŨ (trước khi game nhận
	## bản chuẩn — VD vừa giao dịch xong) -> bỏ qua, không thì mất đồ / tiền vừa nhận.
	var min_ack := 0
	var is_gm := false

var grid: MapGrid
var aoi := AoiGrid.new()
var account: AccountLink
var _enet := ENetMultiplayerPeer.new()
var _ws := WebSocketMultiplayerPeer.new()
var _conns: Dictionary = {}            ## key -> Conn
var _by_character: Dictionary = {}     ## character_id -> Conn (1 nhân vật chỉ online 1 nơi)
var _by_account: Dictionary = {}       ## account_id -> Conn (1 tài khoản chỉ online 1 nơi trên server)
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
## Chợ Giao Thương — chỉ máy chủ thế giới (null ở tiến trình chiến trường).
var market: MarketServer
var relation: RelationServer
## Chiến trường Tống Kim (chỉ tiến trình GAME_BATTLE=1), null = server thế giới thường.
var battle: BattleServer
## Đấu trường PK (GAME_ARENA=1, map 397): phòng 1 chọi 1 + người xem — ArenaServer.
var arena: ArenaServer
## Phòng train chung (GAME_FIELD=1): mỗi phòng 1 bản map luyện công / Địa Ngục + quái riêng, vào bằng ID 6 số — FieldServer.
var field: FieldServer
var map_dir := DEFAULT_MAP_DIR
## Hỏi server tài khoản trạng thái khoá / cấm chat của người đang online mỗi chừng này giây.
var STATUS_POLL_SECONDS := 30.0
var _status_polling := false
var _look_dirty: Array[ServerEntity] = []   ## thực thể đổi ngoại hình từ lượt gửi trước
## Số đo hiệu năng (in mỗi METRICS_SECONDS giây): thời gian xử lý tick, byte gửi đi, số gói.
const METRICS_SECONDS := 10.0
var _m_ticks := 0
var _m_tick_us := 0
var _m_sim_us := 0
var _m_snap_us := 0
var _m_tick_max_us := 0
var _m_bytes := 0
var _m_packets := 0
var _m_awake := 0
## Bán kính (ô AOI) vùng quái "thức" quanh mỗi người chơi — GAME_AWAKE_RADIUS, mặc định 1 (= vùng nhìn thấy 3x3).
var awake_radius := 1                  ## tổng số quái được mô phỏng (thức) qua các tick trong kỳ đo
var _m_at := 0.0
var _last_status_poll := 0.0
## Chế độ kiểm thử (GAME_TEST_MODE=1): mỗi quái chết luôn rớt thêm 1 túi tiền để bài test chắc chắn có đồ rơi. TẮT khi chạy thật.
var test_mode := false
## CHỈ KHI PHÁT TRIỂN (GAME_DEV_TRUST_CLIENT=1): nhận nguyên hồ sơ game gửi (cấp / đồ / tiền từ nút TEST) — xem ProfileGuard.merge.
var dev_trust_client := true
## Dấu phiên bản gói (res://build_info.json do server/dev.sh ghi lúc build): {commit, dirty, built_at} — {} khi chạy thẳng từ mã nguồn.
var build_info: Dictionary = {}
## ---- Vận hành từ web Admin (nhịp tim tới server tài khoản — xem _heartbeat)
const HEARTBEAT_SECONDS := 5.0
## Hệ số kinh nghiệm hạ quái (Thông số game ở web Admin, kẹp 1..EXP_MULT_MAX). Hệ số rơi đồ / tiền nằm ở DropTable.set_rates.
var exp_mult := 1.0
const EXP_MULT_MAX := 10.0
var _hb_at := 0.0
var _hb_busy := false
var _started_unix := 0
var _last_tick_avg := 0.0
var _last_tick_max := 0.0
var _last_kbs := 0.0
var _ack_command := 0             ## mã lệnh admin gần nhất đã nhận (báo lại để server tài khoản xoá lệnh)
## Đang KHỞI ĐỘNG LẠI ÊM: không nhận người mới, đếm ngược báo người chơi, hết giờ thì lưu mọi nhân vật rồi thoát (Docker tự bật lại).
var draining := false
var _drain_until := 0.0
var _drain_message := ""
var _drain_next_notice := 0.0
var _shutting_down := false

func _ready() -> void:
	Engine.max_fps = 120
	build_info = load_build_info()
	_started_unix = int(Time.get_unix_time_from_system())
	map_dir = _env("GAME_MAP_DIR", DEFAULT_MAP_DIR)
	grid = MapGrid.load_from(map_dir)
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
	dev_trust_client = _env("GAME_DEV_TRUST_CLIENT", "1") == "1"
	if dev_trust_client:
		push_warning("GAME_DEV_TRUST_CLIENT=1: nhận nguyên hồ sơ game gửi (chỉ dùng khi phát triển, KHÔNG bật trên máy chủ thật)")
	add_child(account)
	if account.service_key == "":
		push_error("Thiếu GAME_SERVICE_KEY — game server không xác thực được người chơi")
		get_tree().quit(1)
		return
	if _env("GAME_FIELD", "0") == "1":
		field = FieldServer.new(self)   ## map của tiến trình chỉ là "sảnh" chờ vào phòng: không sinh quái
	else:
		_spawn_monsters()
	social = SocialServer.new(self)
	chat = ChatServer.new(self)
	guild = GuildServer.new(self)
	relation = RelationServer.new(self)
	if _env("GAME_BATTLE", "0") == "1":
		battle = BattleServer.new(self, map_dir)
		if not battle.is_ready():
			get_tree().quit(1)
			return
	if _env("GAME_ARENA", "0") == "1":
		arena = ArenaServer.new(self)
	guild.load_all()
	if battle == null and arena == null and field == null:
		market = MarketServer.new(self)
		market.load_all()
	STATUS_POLL_SECONDS = float(_env("GAME_STATUS_POLL", "30"))
	awake_radius = clampi(int(_env("GAME_AWAKE_RADIUS", "1")), 1, 3)
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
	print("Game server %s: map %dx%d ô, %d quái, ENet :%d, WebSocket :%d, máy chủ %d, tài khoản %s" % [build_label(),
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

static func load_build_info() -> Dictionary:
	var path := "res://build_info.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

## "bản a1b2c3d (có sửa) 2026-10-15T10:00:00Z" / "chạy từ mã nguồn".
func build_label() -> String:
	if build_info.is_empty():
		return "(chạy từ mã nguồn)"
	return "bản %s%s %s" % [build_info.get("commit", "?"), " (có sửa)" if build_info.get("dirty", false) else "", build_info.get("built_at", "")]

## Biến môi trường k; không có thì đọc file ở k_FILE (Docker Swarm secrets, /run/secrets/...).
func _env(k: String, def: String) -> String:
	var v := OS.get_environment(k)
	if v == "" and OS.get_environment(k + "_FILE") != "":
		v = FileAccess.get_file_as_string(OS.get_environment(k + "_FILE")).strip_edges()
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
		var t0 := Time.get_ticks_usec()
		_acc -= step
		_tick += 1
		var ts := Time.get_ticks_usec()
		_simulate(step)
		_m_sim_us += Time.get_ticks_usec() - ts
		social.tick(step, _now)
		relation.tick(_now)
		guild.tick(step)
		if market:
			market.tick(step)
		if battle:
			battle.tick(step)
		if arena:
			arena.tick(step)
		if field:
			field.tick(step)
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
			var tn := Time.get_ticks_usec()
			_send_snapshots()
			_m_snap_us += Time.get_ticks_usec() - tn
		var dt_us := Time.get_ticks_usec() - t0
		_m_ticks += 1
		_m_tick_us += dt_us
		_m_tick_max_us = maxi(_m_tick_max_us, dt_us)
	if _now - _m_at >= METRICS_SECONDS:
		_print_metrics()
	if _now - _hb_at >= HEARTBEAT_SECONDS:
		_hb_at = _now
		_heartbeat()
	if draining:
		_tick_drain()

func _print_metrics() -> void:
	var span := maxf(0.001, _now - _m_at)
	var online := _by_character.size()
	if online > 0 or _m_ticks > 0:
		var alive := 0
		for m in _monsters:
			if not m.hidden and not m.is_dead():
				alive += 1
		print("[đo] online %d | tick tb %.2f ms, max %.2f ms (ngân sách %.1f ms) (quái %.2f, gửi vị trí %.2f) | gửi %.1f KB/s (%.2f KB/s/người), %d gói/s | quái sống %d, thức %d" % [
			online, _m_tick_us / 1000.0 / maxi(1, _m_ticks), _m_tick_max_us / 1000.0, 1000.0 / NetProto.TICK_RATE,
			_m_sim_us / 1000.0 / maxi(1, _m_ticks), _m_snap_us / 1000.0 / maxi(1, _m_ticks),
			_m_bytes / 1024.0 / span, _m_bytes / 1024.0 / span / maxi(1, online), int(_m_packets / span), alive, _m_awake / maxi(1, _m_ticks)])
	_last_tick_avg = _m_tick_us / 1000.0 / maxi(1, _m_ticks)
	_last_tick_max = _m_tick_max_us / 1000.0
	_last_kbs = _m_bytes / 1024.0 / span
	_m_at = _now
	_m_ticks = 0
	_m_tick_us = 0
	_m_tick_max_us = 0
	_m_sim_us = 0
	_m_snap_us = 0
	_m_bytes = 0
	_m_packets = 0
	_m_awake = 0

func _simulate(_dt: float) -> void:
	for c: Conn in _conns.values():
		if c.state == ConnState.WAIT_HELLO and _now - c.since > HELLO_TIMEOUT:
			_kick(c, "timeout", "Hết thời gian chờ vào game")
	## Quái chỉ "thức" trong 3x3 ô quanh người chơi = đúng vùng người đó NHÌN THẤY. Quái xa hơn 1 ô (>= 1024 px) không ai thấy và cũng
	## không phát hiện được ai (tầm nhìn quái ~400) — cho ngủ để khỏi tốn CPU / băng thông đi tuần vô ích.
	var awake := {}
	for c: Conn in _conns.values():
		if c.entity != null and c.state == ConnState.IN_WORLD and not c.hub:
			var cell := c.entity.cell
			for dx in range(-awake_radius, awake_radius + 1):
				for dy in range(-awake_radius, awake_radius + 1):
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
		## Mỗi quái chạy 2 tick 1 lần (bước đôi) — chia 2 nhóm chẵn / lẻ theo eid để mỗi tick gánh 1 nửa.
		if awake.has(m.cell) and (m.eid + _tick) % MONSTER_TICK_EVERY == 0:
			_m_awake += 1
			m.tick(self, MONSTER_TICK_EVERY)

## Người chơi còn sống gần nhất trong tầm nhìn (đơn vị logic) của quái.
## exclude_side (chiến trường): quái của phe này -> chỉ nhắm người đã vào phe KIA. base = vùng ô AOI của phòng quái đang ở.
func nearest_player(feet: Vector2, vision_logic: float, exclude_side := "", base := Vector2i.ZERO) -> ServerEntity:
	var here := VltkMath.to_logic(feet)
	var best: ServerEntity = null
	var best_d := vision_logic
	var center := aoi.cell_of(feet, base)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for e: ServerEntity in aoi.player_bucket(center + Vector2i(dx, dy)).values():
				if (e.flags & NetProto.FLAG_DEAD) != 0:
					continue
				if exclude_side != "" and battle:
					var side := battle.side_of(_players_by_eid.get(e.eid))
					if side == "" or side == exclude_side:
						continue
				var d := here.distance_to(VltkMath.to_logic(e.pos))
				if d <= best_d:
					best_d = d
					best = e
	return best

## Quái bắt đầu ra chiêu: báo cho mọi người đang thấy quái (máy người bị nhắm chạy đòn thật).
## Dùng lưới AOI thay vì duyệt toàn bộ kết nối — O(ô) thay vì O(n người chơi).
func monster_attack(m: ServerMonster, slot: int, target: ServerEntity) -> void:
	var b := NetProto.writer(NetProto.S_MATTACK)
	b.put_u32(m.eid)
	b.put_u8(slot)
	b.put_u32(target.eid)
	b.put_u8(m.dir)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for e: ServerEntity in aoi.bucket(m.cell + Vector2i(dx, dy)).values():
				var vc: Conn = _players_by_eid.get(e.eid)
				if vc and vc.state == ConnState.IN_WORLD and (vc.known.has(m.eid) or e == target):
					_send(vc, b)

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
		relation.on_leave(c)
		if battle:
			battle.on_leave(c)
		if arena:
			arena.on_leave(c)
		if field:
			field.on_leave(c)
	_conns.erase(c.key)
	if c.entity and c.character_id != 0:
		c.dirty = true   ## vị trí lúc thoát luôn phải lưu
	if c.dirty and c.character_id != 0:
		_save(c)   ## lưu lần cuối (chạy nền, không cần kết nối còn sống)
	elif c.save_queued == false and c.saving and c.character_id != 0:
		c.save_queued = c.dirty
	if c.character_id != 0 and _by_character.get(c.character_id) == c:
		_by_character.erase(c.character_id)
	if c.account_id != 0 and _by_account.get(c.account_id) == c:
		_by_account.erase(c.account_id)
	if c.entity:
		aoi.remove(c.entity)
		_entities.erase(c.entity.eid)
		_players_by_eid.erase(c.entity.eid)
		print("Rời map: %s (%s)" % [c.entity.name, c.username])

func _send(c: Conn, b: StreamPeerBuffer, channel := NetProto.CH_RELIABLE) -> void:
	_m_bytes += b.data_array.size()
	_m_packets += 1
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
		relation.on_leave(c)
		if field:
			field.on_leave(c)   ## chủ phòng bị đá -> đóng phòng
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
	if c.hub and not HUB_ALLOWED.has(type):
		return
	match type:
		NetProto.C_HELLO:
			if c.state == ConnState.WAIT_HELLO:
				_on_hello(c, b)
		NetProto.C_MOVE:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 12:
				_on_move(c, b)
		NetProto.C_CAST:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 14:
				_on_cast(c, b)
		NetProto.C_DAMAGE:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 9:
				_on_damage(c, b)
		NetProto.C_PROFILE:
			if c.state == ConnState.IN_WORLD:
				_on_profile(c, b)
		NetProto.C_TRADE_REQ:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 4:
				social.on_trade_request(c, b.get_u32())
		NetProto.C_TRADE_REQ_ID:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 4:
				social.on_trade_request_id(c, b.get_u32())
		NetProto.C_MARKET:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 2 and market:
				market.on_market(c, b)
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
		NetProto.C_SECURITY:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 5:
				social.on_security(c, b)
		NetProto.C_GUILD:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 3:
				guild.on_guild(c, b)
		NetProto.C_FRIEND:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 8:
				relation.on_friend(c, b)
		NetProto.C_ENMITY:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 4:
				relation.on_enmity(c, b.get_u32())
		NetProto.C_PVP_HIT:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 8:
				var target := b.get_u32()
				var n := b.get_u32()
				if n <= PvpHit.MAX_BYTES and n <= b.get_available_bytes():
					var r := b.get_data(n)
					relation.on_pvp_hit(c, target, r[1])
		NetProto.C_VIEW_EQUIP:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 4:
				relation.on_view_equip(c, b.get_u32())
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
		NetProto.C_REVIVE:
			if c.state == ConnState.IN_WORLD:
				_on_revive(c)
		NetProto.C_SHOP_BUY:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 3:
				var mid := NetProto.get_str(b, 32)
				var r := PotionShop.buy(c.profile, mid, b.get_u8() if b.get_available_bytes() >= 1 else 1)
				if r["ok"]:
					profile_changed(c)
				notice(c, str(r["message"]))
		NetProto.C_CRAFT:
			if c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 3:
				var a = JSON.parse_string(NetProto.get_str(b, 2048))
				if a is Dictionary:
					var r := Compound.run(c.profile, int(a.get("op", -1)), _str_list(a.get("uids", []), 6),
						_str_list(a.get("alt", []), Compound.MAX_ALT))
					if r["ok"]:
						profile_changed(c)
					notice(c, str(r["message"]))
		NetProto.C_BATTLE:
			if battle and c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 3:
				battle.on_battle(c, b)
		NetProto.C_ARENA:
			if arena and c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 3:
				arena.on_arena(c, b)
		NetProto.C_FIELD:
			if field and c.state == ConnState.IN_WORLD and b.get_available_bytes() >= 3:
				field.on_field(c, b)
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
	var mode := b.get_u8() if b.get_available_bytes() >= 1 else NetProto.HELLO_WORLD
	if mode == NetProto.HELLO_HUB and (battle or arena or field):
		_kick(c, "bad_mode", "Máy chủ này không nhận kết nối từ sảnh")
		return
	c.hub = mode == NetProto.HELLO_HUB
	if version != NetProto.VERSION:
		_kick(c, "version", "Phiên bản game đã cũ, hãy cập nhật")
		return
	if _by_character.size() >= max_players:
		_kick(c, "full", "Máy chủ đã đầy, vui lòng thử lại sau")
		return
	if draining:
		_kick(c, "maintenance", "Máy chủ đang khởi động lại, vui lòng vào lại sau ít phút")
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
	var acc_id := int(acc.id)

	## Tài khoản đang online ở phiên khác -> đá phiên cũ ngay lập tức
	var old_acc: Conn = _by_account.get(acc_id)
	if old_acc and old_acc != c:
		old_acc.character_id = 0
		_kick(old_acc, "logged_in_elsewhere", "Tài khoản vừa đăng nhập ở thiết bị khác")

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
	c.account_id = acc_id
	_by_account[acc_id] = c
	c.muted_until = _unix_of(acc.get("muted_until"))
	c.username = str(acc.username)
	c.is_gm = bool(acc.get("is_gm", false))
	if not c.is_gm:
		var gm_list := _env("GM_ACCOUNTS", "").split(",")
		for gm_name in gm_list:
			var trimmed := gm_name.strip_edges()
			if trimmed != "" and trimmed.to_lower() == c.username.to_lower():
				c.is_gm = true
				break
	c.character_id = character_id
	_by_character[character_id] = c
	var data: Dictionary = ch.get("data", {}) if ch.get("data") is Dictionary else {}
	var new_character := int(data.get("server_seen", 0)) == 0
	if new_character:
		if dev_trust_client or c.is_gm:   ## GM hoặc phát triển: giữ cấp / đồ đã TEST ở Hub trước lần vào map đầu tiên
			data["server_seen"] = 1
		else:
			data = ProfileGuard.sanitize_new(data)
	c.profile = PlayerProfile.from_dict(data)
	## Nhân vật mới: quà tân thủ (cấp khởi đầu + đồ) do server sinh -> uid đồ là của server, qua được ProfileGuard.
	var starter_items := 0
	if new_character and not c.is_gm:
		starter_items = StarterKit.apply(c.profile)
		if StarterKit.give_sect_weapon(c.profile) != null:   ## đã chọn phái ở Hub trước lần vào map đầu
			starter_items += 1
	var admin_items := c.profile.apply_admin_grants()   ## đồ web Admin tặng: sinh thành món thật (lưu ngay ở lần lưu tới)
	c.data = c.profile.to_dict()   ## gán uid cho đồ cũ chưa có — rồi gửi bản chuẩn này xuống game (S_PROFILE)
	c.dirty = true
	c.char_version = int(ch.get("version", 0))
	if take_over:   ## dữ liệu trong RAM của phiên cũ mới nhất (có thể chưa kịp lưu)
		c.data = take_over.data
		c.profile = take_over.profile
		c.char_version = take_over.char_version
		c.grant_seq = take_over.grant_seq
		c.seen_web_grants = take_over.seen_web_grants
		c.unsaved_web_grants = take_over.unsaved_web_grants
	c.last_save = _now
	_last_status_poll = -INF   ## hỏi ngay quà chờ (nạp thẻ trên web) cho nhân vật vừa vào
	c.max_hit = ProfileGuard.max_hit(c.profile)
	c.max_speed = ProfileGuard.max_speed(c.profile)
	var e := ServerEntity.new()
	e.eid = _next_eid
	_next_eid += 1
	e.kind = NetProto.KIND_PLAYER
	e.name = str(ch.get("name", "?"))
	e.level = c.profile.level   ## (cột level của bảng nhân vật có thể cũ: quà tân thủ vừa nâng cấp ở trên, chưa lưu)
	e.camp = c.profile.get_current_camp()
	e.nation = Nation.Type.NONE   ## phe Tống / Kim chỉ có trong trận (refresh_camp)
	e.look = look_from_profile(data)
	e.flags = NetProto.FLAG_RIDING if int(e.look.horse) >= 0 else 0
	if battle:   ## chiến trường: chưa có phe thì đứng tạm ở điểm xuất phát (vị trí đã lưu là vị trí ngoài thế giới)
		e.pos = grid.open_spawn_near(grid.default_center())
	elif arena:   ## đấu trường PK: chưa vào phòng thì đứng ở chỗ người xem (không ai thấy cho tới khi vào phòng)
		e.pos = arena.entry_pos()
	elif field:   ## phòng train chung: đứng ở sảnh (không thấy ai) tới khi tạo / vào phòng (C_FIELD)
		e.pos = field.entry_pos()
	else:
		e.pos = take_over.entity.pos if take_over and take_over.entity else saved_pos(data)
	c.entity = e
	_players_by_eid[e.eid] = c
	if c.hub:
		e.room_id = -1   ## sảnh: không vào lưới tầm nhìn, không "gần" ai (GameServer.near so room_id)
	else:
		_entities[e.eid] = e
		aoi.update(e)
	c.state = ConnState.IN_WORLD
	c.move_budget = c.max_speed * MOVE_BUDGET_CAP
	c.last_move_at = _now
	var w := NetProto.writer(NetProto.S_WELCOME)
	w.put_u32(e.eid)
	w.put_float(e.pos.x)
	w.put_float(e.pos.y)
	NetProto.put_str(w, e.name)
	_send(c, w)
	guild.on_join(c)
	if market:
		market.on_join(c)
	send_profile(c)
	if admin_items > 0 and not take_over:
		notice(c, "Nhận %d vật phẩm từ Quản trị viên (xem hành trang)." % admin_items)
	if starter_items > 0 and not take_over:
		notice(c, "Nhận quà tân thủ: %d vật phẩm (xem hành trang)." % starter_items)
	if (admin_items > 0 or starter_items > 0) and not take_over:
		_save(c)
	if battle:
		battle.on_join_world(c)
	print("%s: %s (%s) eid %d — online %d" % ["Vào sảnh" if c.hub else "Vào map", e.name, c.username, e.eid, _by_character.size()])

## Chỗ đứng lúc thoát (khoá "pos" do _save ghi). Chưa có / ra ngoài map / kẹt trong vùng kín -> điểm xuất phát thông thoáng;
## rơi vào vật cản (map đổi) -> ô trống gần đó.
func saved_pos(data: Dictionary) -> Vector2:
	var v = data.get("pos")
	if v is Array and v.size() == 2:
		var p := Vector2(float(v[0]), float(v[1]))
		if grid.in_bounds(p):
			var at := p if not grid.is_blocked(p) else grid.free_near(p)
			if grid.is_open_area(at):
				return at   ## (kẹt trong vùng kín giữa vật cản — VD khối đá giữa map — thì về chỗ thông thoáng)
	return grid.open_spawn_near(grid.default_center())

## Ngoại hình từ dữ liệu nhân vật (PlayerProfile.to_dict) — cùng cách Player.refresh_appearance().
static func look_from_profile(data: Dictionary) -> Dictionary:
	var profile := PlayerProfile.from_dict(data)
	var gender_key := "female" if profile.gender == PlayerProfile.Gender.FEMALE else "male"
	var look := Equipment.get_appearance(profile.equipment, gender_key, profile.riding)
	var final_gender: String = str(look.get("gender", gender_key))
	look["gender"] = 1 if final_gender == "female" else 0
	look["mask_particular"] = int(look.get("mask_particular", -1))
	var state_id := 0
	if profile.active_aura_id != "":
		var sect := SectRegistry.get_by_id(profile.sect_id)
		if sect:
			for skill in sect.skills:
				if skill.id == profile.active_aura_id:
					state_id = skill.vltk_state_special_id
					break
	look["aura_state"] = state_id
	return look

func _on_move(c: Conn, b: StreamPeerBuffer) -> void:
	var p := Vector2(b.get_float(), b.get_float())
	var dir := b.get_u8() & 7
	var action := clampi(b.get_u8(), 0, NetProto.ACTIONS.size() - 1)
	var z := b.get_u8()
	var flags := (b.get_u8() & NetProto.CLIENT_FLAGS) | (c.entity.flags & ~NetProto.CLIENT_FLAGS)
	var e := c.entity
	var grid := grid_of(e)
	c.move_budget = minf(c.move_budget + (_now - c.last_move_at) * c.max_speed, c.max_speed * MOVE_BUDGET_CAP)
	c.last_move_at = _now
	var dist := e.pos.distance_to(p)
	var jumping := (flags & NetProto.FLAG_JUMPING) != 0
	var bad := not is_finite(p.x) or not is_finite(p.y) or not grid.in_bounds(p) or dist > c.move_budget + 16.0
	if not bad and grid.is_blocked(p) and not (jumping and grid.is_jumpable(p)) and not grid.is_blocked(e.pos):
		bad = true
	if not bad and battle and not battle.allows_pos(c, p):
		bad = true   ## chưa khai chiến / mới hồi sinh: không được rời doanh trại
	if bad:
		var r := NetProto.writer(NetProto.S_CORRECT)
		r.put_float(e.pos.x)
		r.put_float(e.pos.y)
		_send(c, r)
		return
	c.move_budget -= dist
	if (flags & NetProto.FLAG_DEAD) != 0 and (e.flags & NetProto.FLAG_DEAD) == 0:
		if battle:
			battle.on_died(c)
		if arena:
			arena.on_died(c)
		relation.on_died(c)
	## Bày bán = ngồi yên tại chỗ: rời chỗ / lên ngựa / nhảy / chết thì tự dọn quầy, còn lại người khác luôn thấy đang ngồi.
	if c.stall_open:
		if dist > 1.0 or (flags & (NetProto.FLAG_RIDING | NetProto.FLAG_JUMPING | NetProto.FLAG_DEAD)) != 0:
			social.close_stall(c)   ## game tự báo "Đã đứng dậy" (Player._tick_stall)
			flags = (flags & NetProto.CLIENT_FLAGS) | (c.entity.flags & ~NetProto.CLIENT_FLAGS)
		else:
			action = NetProto.action_index("sit")
			flags |= NetProto.FLAG_SITTING
	if p != e.pos or dir != e.dir or action != e.action or z != e.z or flags != e.flags:
		e.pos = p
		e.dir = dir
		e.action = action
		e.z = z
		e.flags = flags
		e.touch()
		aoi.update(e)
		if battle:
			battle.on_moved(c, p)   ## ô cổng doanh trại chiến trường

## Chết rồi bấm "Về thành dưỡng sức": về điểm xuất phát của map. Chỉ nhận khi đang chết (cờ FLAG_DEAD) -> không dùng để dịch chuyển tự do.
func _on_revive(c: Conn) -> void:
	var e := c.entity
	if (e.flags & NetProto.FLAG_DEAD) == 0:
		return
	e.flags &= ~NetProto.FLAG_DEAD
	if battle and battle.on_revive(c):   ## chiến trường: về hậu doanh phe mình
		return
	if arena and arena.on_revive(c):     ## đấu trường PK: đứng lại chỗ của mình trong phòng
		return
	if field and field.on_revive(c):     ## phòng train chung: về điểm xuất phát của map phòng
		return
	e.pos = grid.open_spawn_near(grid.default_center())
	e.touch()
	aoi.update(e)
	c.move_budget = c.max_speed * MOVE_BUDGET_CAP
	c.last_move_at = _now
	var r := NetProto.writer(NetProto.S_CORRECT)
	r.put_float(e.pos.x)
	r.put_float(e.pos.y)
	_send(c, r)

## Sát thương người chơi gây cho quái (tính ở máy người đánh bằng pipeline chiêu hiện có). Server kiểm tra: quái còn sống,
## đủ gần, không vượt trần sát thương của chính nhân vật (ProfileGuard.max_hit), không gửi dồn dập.
## Người chơi ra chiêu: chuyển cho người đang thấy họ để VẼ lại (sát thương vẫn đi đường C_DAMAGE riêng).
const MAX_CASTS_PER_SEC := 12

func _on_cast(c: Conn, b: StreamPeerBuffer) -> void:
	if _now - c.cast_window > 1.0:
		c.cast_window = _now
		c.cast_msgs = 0
	c.cast_msgs += 1
	if c.cast_msgs > MAX_CASTS_PER_SEC or (c.entity.flags & NetProto.FLAG_DEAD) != 0:
		return
	var skill_id := b.get_u16()
	var level := clampi(b.get_u8(), 1, 63)
	var cast_flags := b.get_u8() & NetProto.CAST_SUPPORT
	var target_eid := b.get_u32()
	var aim := NetProto.get_state_pos(b)
	if aim.distance_to(c.entity.pos) > NetProto.AOI_CELL * 1.5:
		aim = c.entity.pos
	var out := NetProto.writer(NetProto.S_CAST)
	out.put_u32(c.entity.eid)
	out.put_u16(skill_id)
	out.put_u8(level)
	out.put_u8(cast_flags)
	out.put_u32(target_eid)
	NetProto.put_state_pos(out, aim)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for v: ServerEntity in aoi.bucket(c.entity.cell + Vector2i(dx, dy)).values():
				var vc: Conn = _players_by_eid.get(v.eid)
				if vc and vc != c and vc.known.has(c.entity.eid):
					_send(vc, out)

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
	if not near(m, c.entity, MAX_HIT_DISTANCE):   ## (khác phòng train chung = không đánh được dù cùng toạ độ)
		return
	if m.battle_side != "" and (battle == null or not battle.can_hit_monster(c, m)):
		return   ## Nguyên Soái: chỉ người phe kia đánh được
	amount = minf(amount, c.max_hit)
	## Khi quái bị khựng: ép trạng thái "hurt" ngay vào entity để S_STATE tiếp theo broadcast cho mọi người thấy
	if staggers and not m.is_dead():
		var hurt_action := NetProto.monster_action_index("hurt")
		if m.hp > 0 and m.action != hurt_action:
			m.action = hurt_action
			m.touch()
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
	if battle and m.battle_side != "":
		battle.on_monster_killed(m, killer_conn)
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
	var rolls: Array
	if m.hell_stars > 0:   ## quái phòng Địa Ngục
		rolls = DropTable.roll_hell(m.level, m.series, m.hell_stars, m.blue_boss)
	else:
		rolls = DropTable.roll_blue_boss(m.level, m.series) if m.blue_boss else DropTable.roll(m.level, m.series)
	var placed: Array = []
	for i in rolls.size():
		var off := Vector2(randf_range(-22, 22), randf_range(-8, 8)) * (1.0 if rolls.size() > 1 else 0.4)
		var d: Dictionary = rolls[i]
		placed.append(_add_drop(m.pos + off, m.last_hitter, int(d.get("amount", 0)) if str(d.type) == "money" else 0,
			(d.item as ItemInstance).to_dict() if str(d.type) == "item" else {}, m))
	var killer: Conn = _players_by_eid.get(m.last_hitter)
	if test_mode and killer and killer.entity:   ## kiểm thử: luôn có 1 túi tiền + 1 món đồ ngay dưới chân người hạ quái
		placed.append(_add_drop(killer.entity.pos, m.last_hitter, 7, {}, m))
		placed.append(_add_drop(killer.entity.pos, m.last_hitter, 0, ItemGenerator.random_equipment(maxi(1, m.level)).to_dict(), m))
	_broadcast_drops(m.pos, placed, m.cell_base)

## Kinh nghiệm do server cộng vào bản nhân vật của server rồi báo game (S_PROGRESS).
func _grant_exp(c: Conn, m: ServerMonster, share: int) -> void:
	if c.profile == null:
		return
	_give_exp(c, ProfileGuard.exp_for_kill(c.profile.level, m.data, m.level, share))

func _give_exp(c: Conn, got: int) -> void:
	if got <= 0 or c.profile == null:
		return
	got = int(got * exp_mult)
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
		c.max_speed = ProfileGuard.max_speed(c.profile)
		refresh_camp(c)
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
	var trust := dev_trust_client or c.is_gm
	var merged := ProfileGuard.merge(c.data, client, pending_gold, trust)
	var money_from_server: bool = merged.get("_money_from_server", false)
	merged.erase("_money_from_server")
	var p := PlayerProfile.from_dict(merged)
	## Vừa gia nhập phái (server nhận ở ProfileGuard._guard_sect): phát vũ khí tân thủ đúng loại phái rồi gửi bản chuẩn xuống game.
	var weapon: ItemInstance = null
	if str(c.data.get("sect_id", "")) == "" and p.has_sect():
		weapon = StarterKit.give_sect_weapon(p)
		if weapon != null:
			merged = p.to_dict()
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
	c.max_speed = ProfileGuard.max_speed(c.profile)
	c.dirty = true
	refresh_camp(c)
	if weapon != null:
		send_profile(c)
		notice(c, "Môn phái tặng vũ khí tân thủ: %s (xem hành trang)." % weapon.get_base().get("name", "?"))

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

## `where` = thực thể ở chỗ rơi (quái / người vứt) — đồ thuộc phòng train chung của nó.
func _add_drop(pos: Vector2, owner_eid: int, amount: int, item: Dictionary, where: ServerEntity) -> int:
	var id := _next_drop
	_next_drop += 1
	_drops[id] = {"pos": pos, "owner": owner_eid, "free_at": _now + DROP_OWNER_SECONDS, "until": _now + DROP_LIFETIME,
		"amount": amount, "item": item, "room": where.room_id, "base": where.cell_base}
	return id

## Báo đồ rơi cho mọi người đang ở gần (3x3 ô AOI quanh chỗ rơi, trong vùng ô `base` của phòng).
func _broadcast_drops(at: Vector2, ids: Array, base := Vector2i.ZERO) -> void:
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
	for e in aoi.around(at, base):
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
	for e in aoi.around(d.pos, d.get("base", Vector2i.ZERO)):
		var c: Conn = _players_by_eid.get(e.eid)
		if c:
			_send(c, b)

func _prune_drops() -> void:
	for id in _drops.keys():
		if _now > float(_drops[id].until):
			_drop_gone(id)

func _on_pickup(c: Conn, id: int) -> void:
	var d: Dictionary = _drops.get(id, {})
	if d.is_empty() or int(d.get("room", 0)) != c.entity.room_id:
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
			var id := _add_drop(c.entity.pos + Vector2(randf_range(-14, 14), 6), 0, 0, it.to_dict(), c.entity)
			_broadcast_drops(c.entity.pos, [id], c.entity.cell_base)
			return

## Phe (màu tên) / phe Tống-Kim đổi: báo người đang thấy + chính mình. Phe chỉ nằm trong gói xuất hiện nên phải báo riêng.
func refresh_camp(c: Conn) -> void:
	if c.entity == null or c.profile == null:
		return
	var nc := c.profile.get_current_camp()
	var nation := battle.nation_of(c) if battle else Nation.Type.NONE   ## phe Tống / Kim chỉ có trong trận chiến trường
	if nc == c.entity.camp and nation == c.entity.nation:
		return
	c.entity.camp = nc
	c.entity.nation = nation
	var b := NetProto.writer(NetProto.S_CAMP)
	b.put_u32(c.entity.eid)
	b.put_8(nc)
	b.put_u8(c.entity.nation)
	send_to_viewers(c, b)

## Gửi gói cho chính `c` + mọi người đang thấy `c` (dùng cho thông tin chỉ nằm trong gói xuất hiện: phe, biển quầy...).
func send_to_viewers(c: Conn, b: StreamPeerBuffer) -> void:
	_send(c, b)
	for v: Conn in _conns.values():
		if v != c and v.state == ConnState.IN_WORLD and v.known.has(c.entity.eid):
			_send(v, b)

## Hồ sơ server vừa đổi (giao dịch, mua bán...): chụp lại dữ liệu, đánh dấu lưu, gửi bản chuẩn xuống game.
func profile_changed(c: Conn) -> void:
	c.data = c.profile.to_dict()
	c.dirty = true
	c.max_hit = ProfileGuard.max_hit(c.profile)
	c.max_speed = ProfileGuard.max_speed(c.profile)
	if _conns.has(c.key) and c.state == ConnState.IN_WORLD:
		send_profile(c)
		refresh_camp(c)

func in_world_conns() -> Array:
	var out := []
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD and c.entity:
			out.append(c)
	return out

func conn_of_eid(eid: int) -> Conn:
	var c: Conn = _players_by_eid.get(eid)
	return c if c and c.state == ConnState.IN_WORLD and _conns.has(c.key) else null

## Đặt nhân vật về `p` (server quyết định) và báo game kéo về.
func teleport(c: Conn, p: Vector2) -> void:
	var e := c.entity
	e.pos = p
	e.touch()
	aoi.update(e)
	c.move_budget = c.max_speed * MOVE_BUDGET_CAP
	c.last_move_at = _now
	var r := NetProto.writer(NetProto.S_CORRECT)
	r.put_float(p.x)
	r.put_float(p.y)
	_send(c, r)

## Thêm / bỏ quái lúc đang chạy (chiến trường: Nguyên Soái). Người đang thấy tự nhận xuất hiện / biến mất qua lưới tầm nhìn.
func add_monster(m: ServerMonster) -> void:
	m.eid = _next_eid
	_next_eid += 1
	_monsters.append(m)
	_entities[m.eid] = m
	aoi.update(m)

func remove_monster(m: ServerMonster) -> void:
	aoi.remove(m)
	_entities.erase(m.eid)
	_monsters.erase(m)

func kick(c: Conn, code: String, message: String) -> void:
	_kick(c, code, message)

func now() -> float:
	return _now

## Người đang trong map có mã nhân vật này (null = không online / chưa vào map).
func conn_of_character(character_id: int) -> Conn:
	var c: Conn = _by_character.get(character_id)
	return c if c and c.state == ConnState.IN_WORLD and c.entity and _conns.has(c.key) else null

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
	var char_ids := []
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD and c.account_id != 0:
			ids.append(c.account_id)
			char_ids.append(c.character_id)
	if ids.is_empty():
		return
	_status_polling = true
	var r: Dictionary = await account.status(ids, char_ids)
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
	## Web Admin vừa sửa dữ liệu nhân vật: đá ra KHÔNG lưu (bản trong RAM đã cũ — lưu sẽ bị từ chối), vào lại là nạp bản mới.
	var reload: Variant = r.get("reload", [])
	if reload is Array:
		for id in reload:
			var rc: Conn = _by_character.get(int(id))
			if rc == null or rc.state != ConnState.IN_WORLD:
				continue
			_by_character.erase(rc.character_id)
			rc.character_id = 0   ## không lưu lần cuối, không cho phiên mới lấy dữ liệu RAM cũ
			rc.dirty = false
			_kick(rc, "admin_edit", "Nhân vật vừa được Quản trị viên cập nhật — hãy vào lại game.")
	var gr: Variant = r.get("grants", {})
	if gr is Dictionary:
		for c: Conn in _conns.values():
			if c.state == ConnState.IN_WORLD and gr.has(str(c.character_id)):
				_apply_web_grants(c, gr[str(c.character_id)])

## Nguyên bảo đổi từ Xu trên web: cộng vào bản nhân vật của server, gửi bản chuẩn xuống game, lưu ngay (kèm id quà để đánh dấu).
func _apply_web_grants(c: Conn, list: Variant) -> void:
	if not list is Array or c.profile == null:
		return
	var got := 0
	for g in list:
		var id := int(g.get("id", 0))
		var jade := int(g.get("jade", 0))
		if id <= 0 or jade <= 0 or c.seen_web_grants.has(id):
			continue
		c.seen_web_grants[id] = true
		c.unsaved_web_grants.append(id)
		c.profile.jade += jade
		got += jade
	if got > 0:
		profile_changed(c)
		notice(c, "Nhận %d Nguyên bảo từ Ví Xu." % got)
		_save(c)

func send(c: Conn, b: StreamPeerBuffer) -> void:
	_send(c, b)

## Lưu nhân vật ngay (sau khi đồ / tiền đổi chủ ở chợ) thay vì chờ SAVE_INTERVAL.
func save_now(c: Conn) -> void:
	if _conns.has(c.key) and c.state == ConnState.IN_WORLD:
		_save(c)

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
	if c.entity and not c.hub and battle == null and arena == null and field == null:   ## vị trí do server giữ (sảnh: không đổi chỗ đứng) (game không được tự ghi "pos"); chiến trường giữ vị trí ngoài thế giới
		c.data["pos"] = [snappedf(c.entity.pos.x, 0.1), snappedf(c.entity.pos.y, 0.1)]
	c.last_save = _now
	var char_id := c.character_id
	_saving_chars[char_id] = int(_saving_chars.get(char_id, 0)) + 1
	var sent_grants: Array = c.unsaved_web_grants.duplicate()
	var r: Dictionary = await account.save_character(char_id, c.char_version, c.data, sent_grants)
	if r.ok:
		for id in sent_grants:
			c.unsaved_web_grants.erase(id)
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
	if b.get_available_bytes() >= 5:
		look["gender"] = b.get_u8()
		look["mask_particular"] = b.get_16()
		look["aura_state"] = b.get_16()
	else:
		look["mask_particular"] = int(e.look.get("mask_particular", -1))
		look["aura_state"] = int(e.look.get("aura_state", 0))
	if look != e.look:
		e.look = look
		e.touch()
		if not e.look_dirty:
			e.look_dirty = true
			_look_dirty.append(e)

# ---------------------------------------------------------------- vận hành (web Admin › Máy chủ)

func process_kind() -> String:
	if battle:
		return "battle"
	if arena:
		return "arena"
	if field:
		return "field"
	return "world"

## Gửi trạng thái tiến trình; câu trả lời mang thông số game + lệnh admin (khởi động lại êm). Không chồng 2 lần gửi.
func _heartbeat() -> void:
	if _hb_busy or account == null:
		return
	_hb_busy = true
	var rooms := field.rooms.size() if field else (arena.rooms.size() if arena else 0)
	var state := {"server_id": account.server_id, "kind": process_kind(), "index": field.index if field else 0,
		"host": _env("GAME_PUBLIC_HOST", "127.0.0.1"), "port": int(_env("GAME_ENET_PORT", "7777")), "build": build_info,
		"online": _by_character.size(), "rooms": rooms, "monsters": _monsters.size(), "tick_avg_ms": snappedf(_last_tick_avg, 0.01),
		"tick_max_ms": snappedf(_last_tick_max, 0.01), "send_kbs": snappedf(_last_kbs, 0.1),
		"uptime_sec": int(Time.get_unix_time_from_system()) - _started_unix, "draining": draining,
		"drain_left": maxi(0, ceili(_drain_until - _now)) if draining else 0, "ack_command": _ack_command}
	var r: Dictionary = await account.heartbeat(state)
	_hb_busy = false
	if not r.ok:
		return
	var st: Variant = r.get("settings")
	if st is Dictionary:
		_apply_settings(st)
	var cmd: Variant = r.get("command")
	if cmd is Dictionary and int(cmd.get("id", 0)) > _ack_command:
		_ack_command = int(cmd.get("id", 0))
		if str(cmd.get("action", "")) == "restart":
			start_drain(clampi(int(cmd.get("seconds", 60)), 10, 1800), str(cmd.get("message", "")).left(200), str(cmd.get("by", "")))

## Thông số game từ web Admin — kẹp lại trong khoảng cho phép dù server tài khoản đã kiểm.
func _apply_settings(st: Dictionary) -> void:
	var e := clampf(float(st.get("exp_mult", 1.0)), 1.0, EXP_MULT_MAX)
	if not is_equal_approx(e, exp_mult):
		print("Thông số game: kinh nghiệm x%.2f" % e)
	exp_mult = e
	var item := float(st.get("drop_item_mult", 1.0))
	var money := float(st.get("drop_money_mult", 1.0))
	if not is_equal_approx(clampf(item, 1.0, DropTable.ITEM_RATE_MAX), DropTable.item_rate_mult) \
			or not is_equal_approx(clampf(money, 1.0, DropTable.MONEY_RATE_MAX), DropTable.money_rate_mult):
		print("Thông số game: rơi trang bị x%.2f, tiền x%.2f" % [clampf(item, 1.0, DropTable.ITEM_RATE_MAX), clampf(money, 1.0, DropTable.MONEY_RATE_MAX)])
	DropTable.set_rates(item, money)

## Bắt đầu khởi động lại êm: còn `seconds` giây (báo người chơi), không nhận người mới.
func start_drain(seconds: int, message: String, by := "") -> void:
	if draining:
		return
	draining = true
	_drain_until = _now + seconds
	_drain_message = message
	_drain_next_notice = 0.0
	print("KHỞI ĐỘNG LẠI ÊM sau %d giây (lệnh của %s): %s" % [seconds, by, message])

func _tick_drain() -> void:
	if _shutting_down:
		return
	var left := _drain_until - _now
	if left <= 0.0:
		_shutdown()
		return
	if _now >= _drain_next_notice:
		var text := "[Hệ thống] Máy chủ sẽ khởi động lại sau %d giây%s — hãy tìm chỗ an toàn, dữ liệu được lưu tự động." % [ceili(left),
			(": " + _drain_message) if _drain_message != "" else ""]
		for c: Conn in _conns.values():
			if c.state == ConnState.IN_WORLD:
				notice(c, text)
		## Báo dày dần: mỗi phút -> mỗi 10 giây (dưới 1 phút) -> mỗi giây (10 giây cuối).
		_drain_next_notice = _now + (60.0 if left > 75.0 else (10.0 if left > 12.0 else 1.0))

## Hết giờ: lưu MỌI nhân vật (chờ tối đa 20 giây), mời mọi người ra, rồi thoát (Docker restart: unless-stopped bật lại tiến trình).
func _shutdown() -> void:
	_shutting_down = true
	print("Khởi động lại: lưu %d nhân vật..." % _by_character.size())
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD and c.character_id != 0 and c.profile != null:
			c.dirty = true
			_save(c)
	var waited := 0.0
	while not _saving_chars.is_empty() and waited < 20.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	if not _saving_chars.is_empty():
		push_warning("Khởi động lại: %d nhân vật lưu chưa xong sau 20 giây" % _saving_chars.size())
	for c: Conn in _conns.values():
		if c.state == ConnState.IN_WORLD:
			c.dirty = false   ## vừa lưu — _drop không lưu lại lần nữa
			_kick(c, "maintenance", "Máy chủ đang khởi động lại, vui lòng vào lại sau ít phút")
	await get_tree().create_timer(1.0).timeout
	print("Khởi động lại: thoát tiến trình")
	get_tree().quit(0)

# ---------------------------------------------------------------- gửi trạng thái theo AOI

## Mỗi ô AOI mã hoá 1 lần các thực thể đổi trạng thái từ lượt trước; người xem đứng yên trong ô chỉ ghép 9 khối đó
## (không duyệt từng thực thể). Chỉ khi người xem sang ô khác mới quét lại toàn bộ 3x3 để tính vào/rời tầm.
## Bất biến: c.known chỉ chứa thực thể ở 3x3 ô quanh c.view_cell tính tới lượt gửi trước.
func _send_snapshots() -> void:
	var now_ms := Time.get_ticks_msec()
	var blob := {}     ## ô -> StreamPeerBuffer các bản ghi S_STATE
	var blob_n := {}   ## ô -> số bản ghi
	for e: ServerEntity in _entities.values():
		if e.snap_ver == e.version:
			continue
		e.snap_ver = e.version
		var buf: StreamPeerBuffer = blob.get(e.cell)
		if buf == null:
			buf = StreamPeerBuffer.new()
			blob[e.cell] = buf
			blob_n[e.cell] = 0
		e.write_state(buf)
		blob_n[e.cell] += 1
	for c: Conn in _conns.values():
		if c.state != ConnState.IN_WORLD or c.entity == null or c.hub:
			continue
		var me := c.entity
		var known := c.known
		var center := me.cell
		## Thực thể mới vào tầm / rời tầm: gộp vào 1 gói mỗi loại (vào map gặp ~50 quái = 1 gói thay vì 50).
		var spawns := NetProto.writer(NetProto.S_SPAWNS)
		spawns.put_u16(0)
		var n_spawn := 0
		var gone: Array[int] = []
		if center != c.view_cell:
			c.view_cell = center
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for e: ServerEntity in aoi.bucket(center + Vector2i(dx, dy)).values():
						if e != me and not known.has(e.eid) and can_see(c, e):
							known[e.eid] = 0
							e.write_spawn(spawns)
							n_spawn += 1
			for eid: int in known:
				if not _in_view(c, eid, center):
					gone.append(eid)
		else:
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var cell := center + Vector2i(dx, dy)
					for e: ServerEntity in aoi.entered_in(cell):
						if e != me and not known.has(e.eid) and _in_view(c, e.eid, center):
							known[e.eid] = 0
							e.write_spawn(spawns)
							n_spawn += 1
					for eid: int in aoi.left_from(cell):
						if known.has(eid) and not _in_view(c, eid, center):
							gone.append(eid)
		if not gone.is_empty():
			var d := NetProto.writer(NetProto.S_DESPAWNS)
			d.put_u16(gone.size())
			for eid: int in gone:
				known.erase(eid)
				d.put_u32(eid)
			_send(c, d)
		if n_spawn > 0:
			spawns.seek(1)
			spawns.put_u16(n_spawn)
			_send(c, spawns)
		var states := NetProto.writer(NetProto.S_STATE)
		states.put_u32(now_ms)
		states.put_u16(0)   ## số mục — ghi lại sau
		var n := 0
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var buf: StreamPeerBuffer = blob.get(center + Vector2i(dx, dy))
				if buf != null:
					states.put_data(buf.data_array)
					n += blob_n[center + Vector2i(dx, dy)]
		if n > 0:
			states.seek(5)
			states.put_u16(n)
			_send(c, states, NetProto.CH_STATE)
	aoi.entered.clear()
	aoi.left.clear()
	## Ngoại hình đổi: báo cho người đang thấy (thực thể mới vào tầm đã nhận ngoại hình trong gói xuất hiện).
	for e: ServerEntity in _look_dirty:
		var l := NetProto.writer(NetProto.S_LOOK)
		l.put_u32(e.eid)
		NetProto.put_look(l, e.look)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for v: ServerEntity in aoi.bucket(e.cell + Vector2i(dx, dy)).values():
					var vc: Conn = _players_by_eid.get(v.eid)
					if vc and vc.known.has(e.eid):
						_send(vc, l)
		e.look_dirty = false
	_look_dirty.clear()

func _in_view(viewer: Conn, eid: int, center: Vector2i) -> bool:
	var e: ServerEntity = _entities.get(eid)
	return e != null and absi(e.cell.x - center.x) <= 1 and absi(e.cell.y - center.y) <= 1 and can_see(viewer, e)

## Người xem `viewer` có được thấy thực thể `e` không — đấu trường PK: chỉ người cùng phòng (ArenaServer.can_see); phòng train chung:
## chỉ thực thể cùng phòng (sảnh không thấy ai); nơi khác luôn thấy.
func can_see(viewer: Conn, e: ServerEntity) -> bool:
	if field:
		return viewer.entity.room_id != 0 and viewer.entity.room_id == e.room_id
	return arena == null or arena.can_see(viewer, e)

## Bản đồ vật cản nơi thực thể đứng: map phòng train chung của nó, không thì map của tiến trình.
func grid_of(e: ServerEntity) -> MapGrid:
	return field.grid_of_room(e.room_id) if field and e.room_id != 0 else grid

## 2 thực thể cùng chỗ (cùng phòng train chung) và cách nhau không quá `dist` px — dùng cho mọi kiểm tra "đứng gần".
static func near(a: ServerEntity, b: ServerEntity, dist: float) -> bool:
	return a.room_id == b.room_id and a.pos.distance_to(b.pos) <= dist

## Bỏ mọi đồ rơi của phòng `room_id` (phòng đóng — người trong phòng đã bị mời ra nên không cần báo).
func clear_room_drops(room_id: int) -> void:
	for id in _drops.keys():
		if int(_drops[id].get("room", 0)) == room_id:
			_drops.erase(id)

func online_count() -> int:
	return _by_character.size()

## Mảng chữ từ JSON của game (tối đa `limit` phần tử, mỗi phần tử tối đa 32 ký tự) — chống gói lạ.
static func _str_list(v: Variant, limit: int) -> Array:
	var out := []
	if v is Array:
		for x in (v as Array).slice(0, limit):
			out.append(str(x).left(32))
	return out

extends RefCounted
class_name ArenaServer
## ĐẤU TRƯỜNG PK online (GAME_ARENA=1): game server riêng chạy map 397 "Đấu Trường Liên Đấu Kiệt Xuất" (khối giữa) — popup PK
## (PkWindow) ở Character Hub. Luật chế độ ở PkRules (Đại hội võ lâm: cùng phái, Võ lâm Liên đấu: mọi phái).
##   - PHÒNG: 1 chủ phòng + 1 đối thủ (đấu) + người xem. ID 6 số, có thể đặt mật khẩu. Mọi phòng dùng CHUNG 1 sân nhưng TÁCH BIỆT:
##     người trong phòng chỉ THẤY người cùng phòng (can_see -> GameServer._send_snapshots), chỉ đánh được đối thủ trong phòng mình
##     lúc đang đấu (allows_hit -> RelationServer.on_pvp_hit). Chưa vào phòng nào thì không thấy ai.
##   - TỰ TÌM ĐỐI THỦ: phòng chờ không khoá hợp (PkRules.can_match: chênh <= 10 cấp, Đại hội cùng phái) -> vào đấu; không có thì ghép
##     với người khác đang tìm; quá PkRules.MATCH_WAIT_SEC giây -> báo "no_match" (game tự chuyển sang đấu bot như bản offline).
##   - TRẬN: đủ 2 người -> chuẩn bị PREPARE_SEC (đứng ở 2 đầu sân, chưa đánh được) -> đấu FIGHT_SEC -> 1 bên trọng thương = thua; hết giờ
##     bên còn nhiều % máu hơn thắng; bỏ trận = thua -> công bố kết quả, END_SEC giây sau mời mọi người rời đấu trường.
## Danh sách phòng báo lên server tài khoản (POST /internal/game/arena) mỗi REPORT_EVERY giây — popup PK đọc qua GET /v1/arena.
##
## Tin game -> server: C_ARENA u8 op + str json; server -> game: S_ARENA str json {op: "room" | "state" | "result" | "reject" | "no_match"}.

const OP_CREATE := 1      ## {mode, password}
const OP_JOIN := 2        ## {room, password} — vào đấu
const OP_WATCH := 3       ## {room, password} — vào xem
const OP_MATCH := 4       ## {mode} — tự tìm đối thủ
const OP_LEAVE := 5
const OP_STATE := 6
const OP_REJECT_OPPONENT := 7
const OP_SWITCH_TEAM := 8
const OP_READY := 9
const OP_START := 10
const OP_KICK_MEMBER := 11

const WAITING := "waiting"
const PREPARE := "prepare"
const FIGHT := "fight"
const ENDED := "ended"
const END_SEC := 8.0
const REPORT_EVERY := 2.0
const STATE_EVERY := 1.0
const FIGHTER_GAP := 120.0
const SPECTATOR_OFFSET := Vector2(0, 180)

var gs   ## GameServer
var rooms := {}            ## id -> phòng {id, mode, password, host, level, sect_id, sect_name, fighters: [cid], spectators: [cid], state, left}
var room_of := {}          ## character_id -> id phòng
var queue := {}            ## character_id -> {mode, since}
var center := Vector2.ZERO
var slots: Array[Vector2] = []
var spectator_pos := Vector2.ZERO
var public_host := ""
var public_port := 0
var public_ws := ""
var _grids := {}
var _report_in := 0.0
var _state_in := 0.0

func _get_grid(map_id: int) -> MapGrid:
	if _grids.has(map_id):
		return _grids[map_id]
	var dir := ""
	if map_id == TongKimLolRules.MAP_ID:
		dir = TongKimLolRules.MAP_DIR
	else:
		var info := PkRules.get_brawl_map_info(map_id)
		dir = str(info.get("dir", PkRules.ARENA_DIR))
	var g := MapGrid.load_from(dir)
	if g != null:
		_grids[map_id] = g
		return g
	return gs.grid

func _init(server) -> void:
	gs = server
	public_host = gs._env("GAME_PUBLIC_HOST", "127.0.0.1")
	public_port = int(gs._env("GAME_ENET_PORT", "7797"))
	public_ws = gs._env("GAME_PUBLIC_WS", "ws://%s:%s" % [public_host, gs._env("GAME_WS_PORT", "7798")])
	center = _arena_center(gs.grid)
	slots = [gs.grid.free_near(center - Vector2(FIGHTER_GAP, 0)), gs.grid.free_near(center + Vector2(FIGHTER_GAP, 0))]
	spectator_pos = gs.grid.free_near(center + SPECTATOR_OFFSET)
	print("Đấu trường PK: tâm sân ", center)

## Tâm vùng trống liền lớn nhất quanh điểm xuất phát (đấu trường gốc là lưới ô đấu có rào; điểm xuất phát có thể nằm trên rào) —
## cùng cách PkMatch (bản offline) chọn sân.
static func _arena_center(grid: MapGrid) -> Vector2:
	if grid != null and not grid.dir.ends_with("map_397"):
		var c := grid.default_center()
		if c != Vector2.ZERO:
			return c
	if PkRules.ARENA_CENTER != Vector2.ZERO:
		return PkRules.ARENA_CENTER
	var around := grid.default_center() if grid != null else Vector2.ZERO
	var seen := {}
	var best: Array[Vector2i] = []
	for gy in range(-8, 9):
		for gx in range(-8, 9):
			var seed := grid.world_to_cell(around + Vector2(gx, gy) * 160.0)
			if seen.has(seed) or grid.is_blocked(grid.cell_to_world(seed)):
				continue
			var comp: Array[Vector2i] = []
			var q: Array[Vector2i] = [seed]
			seen[seed] = true
			while not q.is_empty() and comp.size() < 30000:
				var c: Vector2i = q.pop_back()
				comp.append(c)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if not seen.has(n) and not grid.is_blocked(grid.cell_to_world(n)):
						seen[n] = true
						q.append(n)
			if comp.size() > best.size():
				best = comp
	if best.is_empty():
		return around
	var sum := Vector2.ZERO
	for c in best:
		sum += grid.cell_to_world(c)
	var mid := sum / best.size()
	var nearest := best[0]
	for c in best:
		if grid.cell_to_world(c).distance_squared_to(mid) < grid.cell_to_world(nearest).distance_squared_to(mid):
			nearest = c
	return grid.cell_to_world(nearest)

func entry_pos() -> Vector2:
	return spectator_pos

# ---------------------------------------------------------------- tầm nhìn / đánh

## `viewer` thấy thực thể `e` không: chỉ người cùng phòng (chưa vào phòng = không thấy ai). Quái (không có ở map này) luôn thấy.
func can_see(viewer, e) -> bool:
	var other = gs._players_by_eid.get(e.eid)
	if other == null:
		return true
	var mine = room_of.get(viewer.character_id, "")
	return mine != "" and mine == room_of.get(other.character_id, "")

func allows_hit(a, b) -> bool:
	var id = room_of.get(a.character_id, "")
	if id == "" or id != room_of.get(b.character_id, "") or a == b:
		return false
	var r: Dictionary = rooms.get(id, {})
	if r.get("state", "") != FIGHT:
		return false
	var team_a: Array = r.get("team_a", [])
	var team_b: Array = r.get("team_b", [])
	var a_in_a := team_a.has(a.character_id)
	var b_in_a := team_a.has(b.character_id)
	var a_in_b := team_b.has(a.character_id)
	var b_in_b := team_b.has(b.character_id)
	return (a_in_a and b_in_b) or (a_in_b and b_in_a)

## Tầm nhìn đổi (vào / rời phòng): bắt người đó + mọi người cùng phòng quét lại thực thể quanh mình ở lượt gửi tới.
func _refresh_view(id: String) -> void:
	for c in gs.in_world_conns():
		if room_of.get(c.character_id, "") == id:
			c.view_cell = Vector2i(1 << 30, 1 << 30)

func _refresh_one(c) -> void:
	c.view_cell = Vector2i(1 << 30, 1 << 30)

# ---------------------------------------------------------------- tin từ game

func on_arena(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 512))
	var args: Dictionary = parsed if parsed is Dictionary else {}
	match op:
		OP_CREATE:
			_create(c, int(args.get("mode", PkRules.Mode.LIEN_DAU)), str(args.get("password", "")).left(16), int(args.get("team_size", 1)), args)
		OP_JOIN:
			_join(c, str(args.get("room", "")), str(args.get("password", "")), false, str(args.get("team", "")))
		OP_WATCH:
			_join(c, str(args.get("room", "")), str(args.get("password", "")), true)
		OP_MATCH:
			_match(c, int(args.get("mode", PkRules.Mode.LIEN_DAU)))
		OP_LEAVE:
			_leave_room(c, true)
			gs.kick(c, "arena_end", "Đã rời đấu trường")
		OP_STATE:
			_send_state(c)
		OP_REJECT_OPPONENT:
			_reject_opponent(c)
		OP_SWITCH_TEAM:
			_switch_team(c, str(args.get("team", "")))
		OP_READY:
			_set_ready(c, bool(args.get("ready", true)))
		OP_START:
			_start_match(c)
		OP_KICK_MEMBER:
			_kick_member(c, int(args.get("target_cid", 0)))

func _mode_ok(c, mode: int) -> bool:
	if not PkRules.MODE_NAMES.has(mode):
		_reject(c, "Chế độ không hợp lệ.")
		return false
	var why := PkRules.check_entry(c.profile, mode)
	if why != "":
		_reject(c, why)
		return false
	return true

func _create(c, mode: int, password: String, team_size: int = 1, extra: Dictionary = {}) -> void:
	if room_of.has(c.character_id) or not _mode_ok(c, mode):
		return
	var sect := SectRegistry.get_by_id(c.profile.sect_id)
	var id := ""
	while id == "" or rooms.has(id):
		id = "%06d" % randi_range(100000, 999999)
	var s_size: int = clampi(team_size, 1, 5) if mode == PkRules.Mode.TONG_KIM_LOL else (clampi(team_size, 1, 8) if (mode == PkRules.Mode.THACH_DAU or mode == PkRules.Mode.LON_XON) else 1)
	var brawl_type: String = str(extra.get("brawl_type", "solo")) if mode == PkRules.Mode.LON_XON else ""
	var map_id: int = TongKimLolRules.MAP_ID if mode == PkRules.Mode.TONG_KIM_LOL else int(extra.get("map_id", 319))
	var target_kills: int = int(extra.get("target_kills", 20))
	rooms[id] = {"id": id, "mode": mode, "team_size": s_size, "password": password, "host": c.profile.display_name, "level": c.profile.level,
		"sect_id": c.profile.sect_id, "sect_name": sect.sect_name if sect else "Vô môn phái",
		"brawl_type": brawl_type, "map_id": map_id, "target_kills": target_kills,
		"team_a": [c.character_id], "team_b": [],
		"fighters": [c.character_id], "ready": {c.character_id: true}, "spectators": [], "state": WAITING, "left": 0.0, "winner": ""}
	_enter_room(c, id, false)
	_report()

func _join(c, id: String, password: String, watch: bool, target_team := "") -> void:
	if room_of.has(c.character_id):
		return
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		_reject(c, "Không có phòng #%s." % id)
		return
	if str(r["password"]) != "" and password != str(r["password"]):
		_reject(c, "Sai mật khẩu phòng #%s." % id)
		return
	var r_mode := int(r.get("mode", 0))
	if r_mode == PkRules.Mode.TONG_KIM_LOL and r["state"] != WAITING:
		_reject(c, "Phòng #%s đang trong trận đấu, không thể vào." % id)
		return
	if not watch:
		var is_solo_brawl := (r_mode == PkRules.Mode.LON_XON and str(r.get("brawl_type", "solo")) == "solo")
		var team_size: int = int(r.get("team_size", 1))
		var team_a: Array = r.get("team_a", [])
		var team_b: Array = r.get("team_b", [])
		if is_solo_brawl:
			if r["state"] != WAITING or (r.get("fighters", []) as Array).size() >= 16:
				_reject(c, "Phòng #%s đã đủ 16 người hoặc đang trong trận đấu." % id)
				return
		else:
			if r["state"] != WAITING or (team_a.size() >= team_size and team_b.size() >= team_size):
				_reject(c, "Phòng #%s đã đủ người đấu hoặc đang trong trận đấu." % id)
				return
		if not _mode_ok(c, r_mode):
			return
		if not PkRules.can_match(r_mode, c.profile.level, c.profile.sect_id, int(r["level"]), str(r["sect_id"])):
			_reject(c, "Khác môn phái với chủ phòng." if r_mode == PkRules.Mode.DAI_HOI else "Không thể vào phòng.")
			return
		if is_solo_brawl:
			if not (r["fighters"] as Array).has(c.character_id):
				(r["fighters"] as Array).append(c.character_id)
				(r["team_a"] as Array).append(c.character_id)
		else:
			if target_team == "b" and team_b.size() < team_size:
				team_b.append(c.character_id)
			elif target_team == "a" and team_a.size() < team_size:
				team_a.append(c.character_id)
			elif team_b.size() < team_size:
				team_b.append(c.character_id)
			elif team_a.size() < team_size:
				team_a.append(c.character_id)
			r["team_a"] = team_a
			r["team_b"] = team_b
			r["fighters"] = team_a + team_b
		(r["ready"] as Dictionary)[c.character_id] = false
		_report()
	_enter_room(c, id, watch)

func _match(c, mode: int) -> void:
	if room_of.has(c.character_id) or not _mode_ok(c, mode):
		return
	for id in rooms:
		var r: Dictionary = rooms[id]
		if int(r["mode"]) == mode and r["state"] == WAITING and r["fighters"].size() == 1 and str(r["password"]) == "" \
				and PkRules.can_match(mode, c.profile.level, c.profile.sect_id, int(r["level"]), str(r["sect_id"])):
			_enter_room(c, id, false)
			return
	for cid in queue:
		var other = gs._by_character.get(cid)
		var q: Dictionary = queue[cid]
		if other == null or int(q["mode"]) != mode or other == c:
			continue
		if PkRules.can_match(mode, c.profile.level, c.profile.sect_id, other.profile.level, other.profile.sect_id):
			queue.erase(cid)
			_create(other, mode, "")
			var id: String = room_of.get(cid, "")
			if id != "":
				_enter_room(c, id, false)
			return
	queue[c.character_id] = {"mode": mode, "since": gs.now()}
	_send(c, {"op": "searching", "wait": PkRules.MATCH_WAIT_SEC})

func _spawn_pos_for(c, r: Dictionary, watch: bool) -> Vector2:
	var r_mode := int(r.get("mode", 0))
	if r_mode == PkRules.Mode.TONG_KIM_LOL:
		if watch:
			return TongKimLolRules.MAP_CENTER_POS
		var is_b: bool = (r.get("team_b", []) as Array).has(c.character_id)
		var base_pos: Vector2 = TongKimLolRules.HOME_JIN_POS if is_b else TongKimLolRules.HOME_SONG_POS
		var team: Array = r.get("team_b", []) if is_b else r.get("team_a", [])
		var idx: int = team.find(c.character_id)
		if idx < 0:
			idx = 0
		var off := Vector2(0, (float(idx) - float(maxi(1, team.size()) - 1) * 0.5) * 40.0)
		return base_pos + off
	elif r_mode == PkRules.Mode.LON_XON:
		var map_id: int = int(r.get("map_id", 319))
		var grid: MapGrid = _get_grid(map_id)
		var c_pos := grid.open_spawn_near(grid.default_center())
		if watch:
			return c_pos
		var brawl_type: String = str(r.get("brawl_type", "solo"))
		if brawl_type == "solo":
			var fighters: Array = r.get("fighters", [])
			var idx: int = fighters.find(c.character_id)
			if idx < 0:
				idx = 0
			var angle := float(idx) * TAU / float(maxi(1, fighters.size()))
			var dist := 180.0 + float(idx % 3) * 90.0
			return grid.open_spawn_near(c_pos + Vector2(cos(angle), sin(angle)) * dist)
		else:
			var is_b: bool = (r.get("team_b", []) as Array).has(c.character_id)
			var team: Array = r.get("team_b", []) if is_b else r.get("team_a", [])
			var idx: int = team.find(c.character_id)
			if idx < 0:
				idx = 0
			var y_off := (float(idx) - float(maxi(1, team.size()) - 1) * 0.5) * 50.0
			var side_x := 360.0 if is_b else -360.0
			return grid.open_spawn_near(c_pos + Vector2(side_x, y_off))
	else:
		if watch:
			return spectator_pos
		var fighters: Array = r.get("fighters", [])
		var idx: int = fighters.find(c.character_id)
		return slots[1] if idx == 1 else slots[0]

func _enter_room(c, id: String, watch: bool) -> void:
	var r: Dictionary = rooms[id]
	queue.erase(c.character_id)
	room_of[c.character_id] = id
	if watch:
		r["spectators"].append(c.character_id)
	elif not r["fighters"].has(c.character_id):
		r["fighters"].append(c.character_id)
	_refresh_view(id)
	_send(c, {"op": "room", "role": "spectator" if watch else "fighter"})
	gs.teleport(c, _spawn_pos_for(c, r, watch))
	if int(r.get("mode", 0)) != PkRules.Mode.THACH_DAU and int(r.get("mode", 0)) != PkRules.Mode.TONG_KIM_LOL and int(r.get("mode", 0)) != PkRules.Mode.LON_XON and r["fighters"].size() == 2 and r["state"] == WAITING:
		_start_prepare(id)
	_broadcast_state(id)

func _start_prepare(id: String) -> void:
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		return
	r["state"] = PREPARE
	r["left"] = PkRules.PREPARE_SEC
	var fighters: Array = r.get("fighters", [])
	for cid in fighters:
		var f = gs._by_character.get(cid)
		if f:
			gs.teleport(f, _spawn_pos_for(f, r, false))

func _switch_team(c, target_team: String) -> void:
	var id: String = room_of.get(c.character_id, "")
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty() or r["state"] != WAITING:
		return
	var team_size: int = int(r.get("team_size", 1))
	var team_a: Array = r.get("team_a", [])
	var team_b: Array = r.get("team_b", [])
	if target_team == "a" and team_a.size() < team_size:
		team_b.erase(c.character_id)
		if not team_a.has(c.character_id):
			team_a.append(c.character_id)
	elif target_team == "b" and team_b.size() < team_size:
		team_a.erase(c.character_id)
		if not team_b.has(c.character_id):
			team_b.append(c.character_id)
	r["team_a"] = team_a
	r["team_b"] = team_b
	r["fighters"] = team_a + team_b
	if r["state"] == WAITING:
		gs.teleport(c, _spawn_pos_for(c, r, false))
	_broadcast_state(id)

func _set_ready(c, is_ready: bool) -> void:
	var id: String = room_of.get(c.character_id, "")
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty() or r["state"] != WAITING:
		return
	(r["ready"] as Dictionary)[c.character_id] = is_ready
	_broadcast_state(id)

func _start_match(c) -> void:
	var id: String = room_of.get(c.character_id, "")
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty() or r["state"] != WAITING:
		return
	var team_a: Array = r.get("team_a", [])
	var team_b: Array = r.get("team_b", [])
	if team_a.is_empty() or team_a[0] != c.character_id:
		_reject(c, "Chỉ chủ phòng mới có thể bắt đầu trận đấu.")
		return
	if team_b.is_empty():
		_reject(c, "Chưa có đối thủ tham gia.")
		return
	var team_size: int = int(r.get("team_size", 1))
	if int(r.get("mode", 0)) == PkRules.Mode.TONG_KIM_LOL:
		if team_a.size() < team_size or team_b.size() < team_size:
			_reject(c, "Phòng chưa đủ người chơi (cần %d/%d người mỗi phe)." % [team_size, team_size])
			return
		var ready_map: Dictionary = r.get("ready", {})
		for cid in team_a + team_b:
			if cid != c.character_id and not bool(ready_map.get(cid, false)):
				_reject(c, "Vẫn còn người chơi chưa sẵn sàng.")
				return
	_start_prepare(id)
	_broadcast_state(id)

func _kick_member(c, target_cid: int) -> void:
	var id: String = room_of.get(c.character_id, "")
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty() or r["state"] != WAITING:
		return
	var team_a: Array = r.get("team_a", [])
	if team_a.is_empty() or team_a[0] != c.character_id:
		_reject(c, "Chỉ chủ phòng mới có quyền đá thành viên.")
		return
	if target_cid == c.character_id:
		return
	var target = gs._by_character.get(target_cid)
	if target:
		_leave_room(target, false)
		gs.kick(target, "arena_end", "Bạn đã bị chủ phòng đá khỏi phòng.")

func _reject_opponent(c) -> void:
	var id: String = room_of.get(c.character_id, "")
	if id == "":
		return
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		return
	if not PkRules.can_kick(int(r["mode"])):
		_reject(c, "Chế độ này không thể đá đối thủ ra.")
		return
	var team_a: Array = r.get("team_a", [])
	if team_a.is_empty() or team_a[0] != c.character_id:
		_reject(c, "Chỉ chủ phòng mới có quyền từ chối đối thủ.")
		return
	if r["state"] not in [WAITING, PREPARE]:
		_reject(c, "Trận đấu đã diễn ra, không thể từ chối.")
		return
	var team_b: Array = r.get("team_b", [])
	if team_b.is_empty():
		return
	for cid in team_b:
		var opponent = gs._by_character.get(cid)
		room_of.erase(cid)
		if opponent:
			_refresh_one(opponent)
			gs.kick(opponent, "arena_end", "Chủ phòng đã từ chối khiêu chiến.")
	r["team_b"] = []
	r["fighters"] = team_a.duplicate()
	r["state"] = WAITING
	r["left"] = 0.0
	_refresh_view(id)
	_send(c, {"op": "rejected_opponent", "msg": "Đã từ chối đối thủ. Phòng tiếp tục chờ người thách đấu khác."})
	_broadcast_state(id)

func _leave_room(c, by_player: bool) -> void:
	queue.erase(c.character_id)
	var id: String = room_of.get(c.character_id, "")
	if id == "":
		return
	var r: Dictionary = rooms.get(id, {})
	room_of.erase(c.character_id)
	_refresh_one(c)
	if r.is_empty():
		return
	r["spectators"].erase(c.character_id)
	(r.get("ready", {}) as Dictionary).erase(c.character_id)
	var team_a: Array = r.get("team_a", [])
	var team_b: Array = r.get("team_b", [])
	var in_a := team_a.has(c.character_id)
	var in_b := team_b.has(c.character_id)
	if in_a:
		team_a.erase(c.character_id)
	if in_b:
		team_b.erase(c.character_id)
	r["fighters"].erase(c.character_id)
	if in_a or in_b:
		if r["state"] in [PREPARE, FIGHT] and by_player:
			var opp_team := "b" if in_a else "a"
			_finish_team(id, opp_team, "%s đã bỏ trận." % c.profile.display_name)
		if r["state"] == WAITING:
			if team_a.is_empty():
				_close(id)
				return
	_refresh_view(id)
	_broadcast_state(id)

func on_leave(c) -> void:
	_leave_room(c, true)

func on_died(c) -> void:
	var id: String = room_of.get(c.character_id, "")
	var r: Dictionary = rooms.get(id, {})
	if not r.is_empty() and r["state"] == FIGHT and r["fighters"].has(c.character_id):
		var r_mode := int(r.get("mode", 0))
		if r_mode == PkRules.Mode.TONG_KIM_LOL:
			return ## Trong Tống Kim LOL người chơi chết sẽ hồi sinh tại doanh trại
		if r_mode == PkRules.Mode.LON_XON and str(r.get("brawl_type", "solo")) == "solo":
			return ## Trong Lộn Xộn Solo chết sẽ hồi sinh ngẫu nhiên trên bản đồ
		var team_a: Array = r.get("team_a", [])
		var team_b: Array = r.get("team_b", [])
		var alive_a := _alive_team_count(team_a)
		var alive_b := _alive_team_count(team_b)
		if alive_a == 0:
			_finish_team(id, "b", "Phe Xanh Dương đã bị quét sạch!")
		elif alive_b == 0:
			_finish_team(id, "a", "Phe Đỏ đã bị quét sạch!")

## Chết trong đấu trường: không về điểm xuất phát map — đứng lại chỗ của mình trong phòng (trận đã có kết quả hoặc hồi sinh).
func on_revive(c) -> bool:
	var id: String = room_of.get(c.character_id, "")
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		gs.teleport(c, spectator_pos)
		return true
	var is_spec: bool = (r.get("spectators", []) as Array).has(c.character_id)
	gs.teleport(c, _spawn_pos_for(c, r, is_spec))
	return true

## Bản đồ vật cản tương ứng với phòng PK đang tham gia
func grid_of(e) -> MapGrid:
	var c = gs._players_by_eid.get(e.eid)
	if c == null:
		return null
	var id: String = room_of.get(c.character_id, "")
	if id == "" or not rooms.has(id):
		return null
	var r: Dictionary = rooms[id]
	var r_mode := int(r.get("mode", 0))
	if r_mode == PkRules.Mode.TONG_KIM_LOL:
		return _get_grid(TongKimLolRules.MAP_ID)
	elif r_mode == PkRules.Mode.LON_XON:
		return _get_grid(int(r.get("map_id", 319)))
	return gs.grid

func _alive_team_count(team_cids: Array) -> int:
	var c := 0
	for cid in team_cids:
		var m = gs._by_character.get(cid)
		if m and m.entity and (m.entity.flags & NetProto.FLAG_DEAD) == 0 and m.entity.hp > 0:
			c += 1
	return c

func _team_hp_ratio(team_cids: Array) -> float:
	var total_hp := 0.0
	var total_max := 0.0
	for cid in team_cids:
		var m = gs._by_character.get(cid)
		if m and m.entity:
			total_hp += float(m.entity.hp)
			total_max += maxf(float(m.entity.max_hp), 1.0)
	return total_hp / maxf(total_max, 1.0)

# ---------------------------------------------------------------- nhịp

func tick(delta: float) -> void:
	var now: float = gs.now()
	for cid in queue.keys():
		if now - float(queue[cid]["since"]) >= PkRules.MATCH_WAIT_SEC:
			var c = gs._by_character.get(cid)
			var mode := int(queue[cid]["mode"])
			queue.erase(cid)
			if c:
				_send(c, {"op": "no_match", "mode": mode})
	for id in rooms.keys():
		var r: Dictionary = rooms[id]
		if r["state"] == WAITING:
			continue
		r["left"] = float(r["left"]) - delta
		if r["left"] > 0.0:
			continue
		match r["state"]:
			PREPARE:
				r["state"] = FIGHT
				r["left"] = PkRules.FIGHT_SEC
				_broadcast_state(id)
			FIGHT:
				var team_a: Array = r.get("team_a", [])
				var team_b: Array = r.get("team_b", [])
				var alive_a := _alive_team_count(team_a)
				var alive_b := _alive_team_count(team_b)
				if alive_a != alive_b:
					var win_team := "a" if alive_a > alive_b else "b"
					_finish_team(id, win_team, "Hết giờ — phe %s còn nhiều người sống sót hơn (%d vs %d)." % [
						"Xanh Dương" if win_team == "a" else "Đỏ", maxi(alive_a, alive_b), mini(alive_a, alive_b)
					])
				else:
					var hp_a := _team_hp_ratio(team_a)
					var hp_b := _team_hp_ratio(team_b)
					var win_team := "a" if hp_a >= hp_b else "b"
					_finish_team(id, win_team, "Hết giờ — phe %s còn nhiều sinh lực hơn." % ("Xanh Dương" if win_team == "a" else "Đỏ"))
			ENDED:
				for cid in r["fighters"] + r["spectators"]:
					var m = gs._by_character.get(cid)
					room_of.erase(cid)
					if m:
						gs.kick(m, "arena_end", "Trận đấu đã kết thúc")
				_close(id)
	_state_in -= delta
	if _state_in <= 0.0:
		_state_in = STATE_EVERY
		for id in rooms:
			_broadcast_state(id)
	_report_in -= delta
	if _report_in <= 0.0:
		_report_in = REPORT_EVERY
		_report()

func _finish_team(id: String, win_team: String, why: String) -> void:
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty() or r["state"] == ENDED:
		return
	r["state"] = ENDED
	r["left"] = END_SEC
	var win_name := "Phe Xanh Dương" if win_team == "a" else "Phe Đỏ"
	r["winner"] = win_name
	var m_mode := int(r["mode"]) as PkRules.Mode
	var has_pts := PkRules.has_rank_points(m_mode)
	var win_cids: Array = r.get("team_a" if win_team == "a" else "team_b", [])
	for cid in r["fighters"] + r["spectators"]:
		var m = gs._by_character.get(cid)
		if m:
			var is_win: bool = win_cids.has(cid)
			var delta := 0
			if has_pts and r["fighters"].has(cid) and m.profile:
				delta = PkRules.WIN_POINTS if is_win else -PkRules.LOSE_POINTS
				m.profile.pk_points = maxi(0, m.profile.pk_points + delta)
			_send(m, {"op": "result", "win": is_win, "fighter": r["fighters"].has(cid), "winner": win_name,
				"why": why, "mode": m_mode, "points_delta": delta, "pk_points": m.profile.pk_points if m.profile else 0})
	_broadcast_state(id)

func _finish(id: String, winner_cid: int, why: String) -> void:
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		return
	var win_team := "a" if (r.get("team_a", []) as Array).has(winner_cid) else "b"
	_finish_team(id, win_team, why)

func _close(id: String) -> void:
	rooms.erase(id)
	_report()

# ---------------------------------------------------------------- gửi tin

func _public_room(r: Dictionary) -> Dictionary:
	var team_a_info := []
	var team_b_info := []
	for cid in r.get("team_a", []):
		var m = gs._by_character.get(cid)
		if m and m.profile:
			var sect := SectRegistry.get_by_id(m.profile.sect_id)
			team_a_info.append({"cid": cid, "name": m.profile.display_name, "level": m.profile.level, "sect_id": m.profile.sect_id,
				"sect_name": sect.sect_name if sect else "Vô môn phái", "ready": bool((r.get("ready", {}) as Dictionary).get(cid, false)),
				"is_host": cid == (r.get("team_a", [0]) as Array)[0]})
	for cid in r.get("team_b", []):
		var m = gs._by_character.get(cid)
		if m and m.profile:
			var sect := SectRegistry.get_by_id(m.profile.sect_id)
			team_b_info.append({"cid": cid, "name": m.profile.display_name, "level": m.profile.level, "sect_id": m.profile.sect_id,
				"sect_name": sect.sect_name if sect else "Vô môn phái", "ready": bool((r.get("ready", {}) as Dictionary).get(cid, false)),
				"is_host": false})
	var names := []
	for inf in team_a_info: names.append(inf["name"])
	for inf in team_b_info: names.append(inf["name"])
	return {"id": r["id"], "mode": int(r["mode"]), "team_size": int(r.get("team_size", 1)),
		"brawl_type": str(r.get("brawl_type", "solo")), "map_id": int(r.get("map_id", 319)),
		"target_kills": int(r.get("target_kills", 20)), "host": r["host"],
		"level": int(r["level"]), "sect_name": r["sect_name"], "locked": str(r["password"]) != "", "state": r["state"],
		"fighters": names, "team_a": team_a_info, "team_b": team_b_info,
		"spectators": r["spectators"].size(), "left": ceili(maxf(float(r["left"]), 0.0)), "winner": r.get("winner", "")}

func _state_for(c, r: Dictionary) -> Dictionary:
	var st := _public_room(r)
	st["op"] = "state"
	var eids_a := []
	for cid in r.get("team_a", []):
		var m = gs._by_character.get(cid)
		if m and m.entity: eids_a.append(m.entity.eid)
	var eids_b := []
	for cid in r.get("team_b", []):
		var m = gs._by_character.get(cid)
		if m and m.entity: eids_b.append(m.entity.eid)
	st["team_a_eids"] = eids_a
	st["team_b_eids"] = eids_b
	st["fighter_eids"] = eids_a + eids_b
	var in_a := (r.get("team_a", []) as Array).has(c.character_id)
	var in_b := (r.get("team_b", []) as Array).has(c.character_id)
	st["role"] = "fighter" if (in_a or in_b) else "spectator"
	st["my_team"] = "a" if in_a else ("b" if in_b else "")
	return st

func _send_state(c) -> void:
	var r: Dictionary = rooms.get(room_of.get(c.character_id, ""), {})
	if not r.is_empty():
		_send(c, _state_for(c, r))

func _broadcast_state(id: String) -> void:
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		return
	for cid in r["fighters"] + r["spectators"]:
		var m = gs._by_character.get(cid)
		if m:
			_send(m, _state_for(m, r))

func _reject(c, text: String) -> void:
	_send(c, {"op": "reject", "msg": text})

func _send(c, msg: Dictionary) -> void:
	var b := NetProto.writer(NetProto.S_ARENA)
	NetProto.pack_arena_msg(b, msg)
	gs.send(c, b)

func _report() -> void:
	var list := []
	for id in rooms:
		list.append(_public_room(rooms[id]))
	gs.account.report_arena({"server_id": gs.account.server_id, "host": public_host, "port": public_port, "ws_url": public_ws,
		"open": true, "rooms": list})

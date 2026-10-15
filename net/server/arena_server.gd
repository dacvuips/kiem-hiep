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
var _report_in := 0.0
var _state_in := 0.0

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
	var around := grid.default_center()
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
	return r.get("state", "") == FIGHT and r["fighters"].has(a.character_id) and r["fighters"].has(b.character_id)

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
			_create(c, int(args.get("mode", PkRules.Mode.LIEN_DAU)), str(args.get("password", "")).left(16))
		OP_JOIN:
			_join(c, str(args.get("room", "")), str(args.get("password", "")), false)
		OP_WATCH:
			_join(c, str(args.get("room", "")), str(args.get("password", "")), true)
		OP_MATCH:
			_match(c, int(args.get("mode", PkRules.Mode.LIEN_DAU)))
		OP_LEAVE:
			_leave_room(c, true)
			gs.kick(c, "arena_end", "Đã rời đấu trường")
		OP_STATE:
			_send_state(c)

func _mode_ok(c, mode: int) -> bool:
	if not PkRules.MODE_NAMES.has(mode):
		_reject(c, "Chế độ không hợp lệ.")
		return false
	var why := PkRules.check_entry(c.profile, mode)
	if why != "":
		_reject(c, why)
		return false
	return true

func _create(c, mode: int, password: String) -> void:
	if room_of.has(c.character_id) or not _mode_ok(c, mode):
		return
	var sect := SectRegistry.get_by_id(c.profile.sect_id)
	var id := ""
	while id == "" or rooms.has(id):
		id = "%06d" % randi_range(100000, 999999)
	rooms[id] = {"id": id, "mode": mode, "password": password, "host": c.profile.display_name, "level": c.profile.level,
		"sect_id": c.profile.sect_id, "sect_name": sect.sect_name if sect else "Vô môn phái", "fighters": [c.character_id],
		"spectators": [], "state": WAITING, "left": 0.0, "winner": ""}
	_enter_room(c, id, false)

func _join(c, id: String, password: String, watch: bool) -> void:
	if room_of.has(c.character_id):
		return
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		_reject(c, "Không có phòng #%s." % id)
		return
	if str(r["password"]) != "" and password != str(r["password"]):
		_reject(c, "Sai mật khẩu phòng #%s." % id)
		return
	if not watch:
		if r["state"] != WAITING or r["fighters"].size() >= 2:
			_reject(c, "Phòng #%s đã đủ người đấu — có thể vào xem." % id)
			return
		if not _mode_ok(c, int(r["mode"])):
			return
		if not PkRules.can_match(int(r["mode"]), c.profile.level, c.profile.sect_id, int(r["level"]), str(r["sect_id"])):
			_reject(c, "Chênh lệch quá %d cấp%s với chủ phòng." % [PkRules.MATCH_LEVEL_DIFF,
					" hoặc khác môn phái" if int(r["mode"]) == PkRules.Mode.DAI_HOI else ""])
			return
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

func _enter_room(c, id: String, watch: bool) -> void:
	var r: Dictionary = rooms[id]
	queue.erase(c.character_id)
	room_of[c.character_id] = id
	if watch:
		r["spectators"].append(c.character_id)
		gs.teleport(c, spectator_pos)
	elif not r["fighters"].has(c.character_id):
		r["fighters"].append(c.character_id)
	if not watch:
		gs.teleport(c, slots[r["fighters"].find(c.character_id)])
	_refresh_view(id)
	_send(c, {"op": "room", "role": "spectator" if watch else "fighter"})
	if r["fighters"].size() == 2 and r["state"] == WAITING:
		r["state"] = PREPARE
		r["left"] = PkRules.PREPARE_SEC
		for i in 2:
			var f = gs._by_character.get(r["fighters"][i])
			if f:
				gs.teleport(f, slots[i])
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
	if r["fighters"].has(c.character_id):
		if r["state"] in [PREPARE, FIGHT] and by_player:
			_finish(id, _other_fighter(r, c.character_id), "%s đã bỏ trận." % c.profile.display_name)
		r["fighters"].erase(c.character_id)
		if r["state"] == WAITING and r["fighters"].is_empty():
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
		_finish(id, _other_fighter(r, c.character_id), "%s đã trọng thương." % c.profile.display_name)

## Chết trong đấu trường: không về điểm xuất phát map — đứng lại chỗ của mình trong phòng (trận đã có kết quả).
func on_revive(c) -> bool:
	var id: String = room_of.get(c.character_id, "")
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		gs.teleport(c, spectator_pos)
		return true
	var i: int = r["fighters"].find(c.character_id)
	gs.teleport(c, slots[i] if i >= 0 else spectator_pos)
	return true

static func _other_fighter(r: Dictionary, cid: int) -> int:
	for f in r["fighters"]:
		if f != cid:
			return f
	return 0

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
				var a = gs._by_character.get(r["fighters"][0]) if r["fighters"].size() > 0 else null
				var b = gs._by_character.get(r["fighters"][1]) if r["fighters"].size() > 1 else null
				var hp_a: int = a.entity.hp if a and a.entity else 0
				var hp_b: int = b.entity.hp if b and b.entity else 0
				_finish(id, a.character_id if hp_a >= hp_b and a else (b.character_id if b else 0), "Hết giờ — bên còn nhiều sinh lực hơn thắng.")
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

func _finish(id: String, winner_cid: int, why: String) -> void:
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty() or r["state"] == ENDED:
		return
	r["state"] = ENDED
	r["left"] = END_SEC
	var winner = gs._by_character.get(winner_cid)
	r["winner"] = winner.profile.display_name if winner else ""
	for cid in r["fighters"] + r["spectators"]:
		var m = gs._by_character.get(cid)
		if m:
			_send(m, {"op": "result", "win": cid == winner_cid, "fighter": r["fighters"].has(cid), "winner": r["winner"],
				"why": why, "mode": int(r["mode"])})
	_broadcast_state(id)

func _close(id: String) -> void:
	rooms.erase(id)

# ---------------------------------------------------------------- gửi tin

func _public_room(r: Dictionary) -> Dictionary:
	var names := []
	for cid in r["fighters"]:
		var m = gs._by_character.get(cid)
		names.append(m.profile.display_name if m else "?")
	return {"id": r["id"], "mode": int(r["mode"]), "host": r["host"], "level": int(r["level"]), "sect_name": r["sect_name"],
		"locked": str(r["password"]) != "", "state": r["state"], "fighters": names, "spectators": r["spectators"].size(),
		"left": ceili(maxf(float(r["left"]), 0.0)), "winner": r["winner"]}

func _state_for(c, r: Dictionary) -> Dictionary:
	var eids := []
	for cid in r["fighters"]:
		var m = gs._by_character.get(cid)
		eids.append(m.entity.eid if m and m.entity else 0)
	var st := _public_room(r)
	st["op"] = "state"
	st["fighter_eids"] = eids
	st["role"] = "fighter" if r["fighters"].has(c.character_id) else "spectator"
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
	NetProto.put_str(b, JSON.stringify(msg))
	gs.send(c, b)

func _report() -> void:
	var list := []
	for id in rooms:
		list.append(_public_room(rooms[id]))
	gs.account.report_arena({"server_id": gs.account.server_id, "host": public_host, "port": public_port, "ws_url": public_ws,
		"open": true, "rooms": list})

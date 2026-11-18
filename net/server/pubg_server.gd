extends RefCounted
class_name PubgServer
## CHIẾN TRƯỜNG SINH TỒN (PUBG Võ Lâm) ONLINE — chạy NGAY TRÊN game server thế giới (mỗi máy chủ 1 bộ đội / trận riêng, đúng luật
## "chỉ ghép với người cùng máy chủ"). Không cần tiến trình / cổng / Docker riêng.
##
## 1. ĐỘI CHỜ (từ Character Hub qua kết nối sảnh HELLO_HUB): tạo đội 1-4 người (mã PUBG-xxxx), bạn bè nhập mã vào đội, sẵn sàng,
##    chat trong đội, chủ đội đặt mật khẩu / bật tự ghép / mời ra. Chủ đội bấm tìm trận khi mọi người sẵn sàng.
## 2. GHÉP TRẬN theo kiểu đội (Solo / Duo / Trio / Squad): đội cùng kiểu vào hàng chờ; đủ PubgManager.match_capacity người, hoặc chờ
##    quá SEARCH_SEC mà có >= min_squads đội -> mở trận. Đội bật tự ghép mà thiếu người được gộp với đội tự ghép khác.
##    Trận mới đấu < BACKFILL_MAX_SEC còn chỗ thì nhận thêm đội.
## 3. TRẬN: map Tống Kim 1, khung 140x80 region ngẫu nhiên, quái trong khung (rớt Hoàng Kim môn phái 90%, thuốc 50%, ngựa 20%),
##    vòng bo theo seed (PubgManager — máy người chơi tính + trừ máu). Mỗi trận = 1 "phòng" thực thể riêng (room_id + cell_base
##    như FieldServer) nên không ai ngoài trận thấy / đánh được người trong trận. Khác đội trong trận đánh được nhau.
##    Người chơi vào trận bằng kết nối thường (HELLO_WORLD): server thay hồ sơ bằng HỒ SƠ TẠM cấp 200 (PubgManager.apply_match_build)
##    — KHÔNG BAO GIỜ LƯU (GameServer._save bỏ qua), đồ trong trận mất hết khi ra. Chết / thoát = bị loại. Đội cuối cùng còn sống thắng.
##
## Tin game -> server: C_PUBG u8 op + str json. Server -> game: S_PUBG json {op: ...}:
##   "room" {room}            đội chờ của mình (thành viên, chủ đội, sẵn sàng, trạng thái)      "none"  không còn ở đội nào
##   "chat" {from, to, text}  chat trong đội                                                   "reject" {msg}
##   "searching" {found, cap, waited, max_wait}                                                "match" {...} vào trận
##   "mstate" {alive_players, alive_squads, squad_eids, enemy_eids, elapsed}                   "eliminated" {rank, ...}
##   "result" {win, rank, squads, why}

const OP_CREATE := 1      ## {mode 1-4, fill, quick}
const OP_JOIN := 2        ## {code, password}
const OP_LEAVE := 3
const OP_READY := 4       ## {ready}
const OP_KICK := 5        ## {cid}
const OP_PASSWORD := 6    ## {password}
const OP_FILL := 7        ## {on}
const OP_CHAT := 8        ## {text, to}
const OP_SEARCH := 9
const OP_CANCEL := 10
const OP_STATE := 11
const OP_QUIT := 12       ## bỏ trận (trong trận)
const OP_DRAFT := 13      ## {horse 1-5, weapon 0-13, build {str, dex, vit, eng}} — chọn thẻ đầu trận (1 lần)

## Gói được gửi khi đang trong trận — chặn giao dịch / chợ / bày bán / mua / chế tạo... để đồ của hồ sơ tạm không lọt ra ngoài.
const MATCH_ALLOWED := [NetProto.C_MOVE, NetProto.C_CAST, NetProto.C_DAMAGE, NetProto.C_PROFILE, NetProto.C_PICKUP,
	NetProto.C_DISCARD, NetProto.C_LOOK, NetProto.C_REVIVE, NetProto.C_PING, NetProto.C_PVP_HIT, NetProto.C_CHAT,
	NetProto.C_PUBG, NetProto.C_VIEW_EQUIP]

const ROOM_CELLS := 4096          ## vùng ô AOI mỗi trận chiếm theo trục y (như FieldServer)
const FIRST_SLOT := 16            ## trận dùng slot >= 16 (cell_base cách xa map thế giới)
const MATCH_RID_BASE := 9_000_000 ## room_id thực thể của trận = BASE + slot (không trùng ID phòng 6 số của FieldServer)
const JOIN_TIMEOUT := 90.0        ## đã ghép trận mà không vào kịp -> coi như bị loại
const END_SEC := 12.0             ## có kết quả -> sau chừng này giây mời mọi người rời trận
const MATCH_EXTRA_SEC := 120.0    ## trận dài tối đa = tổng thời gian bo + chừng này (rồi xếp hạng theo người còn sống)
const MAX_CHAT := 120
const CHAT_KEEP := 40
const SPAWN_SPREAD := 0.6         ## điểm thả đội: trong 60% giữa khung chơi
const BACKFILL_MAX_SEC := PubgManager.BACKFILL_MAX_SEC

var gs   ## GameServer
var rooms := {}          ## mã "PUBG-1234" -> đội chờ {id, mode, fill, quick, password, leader, members: [cid], ready: {cid: bool},
                         ##   searching, search_since, chat: [], created}
var room_of := {}        ## character_id -> mã đội chờ
var matches := {}        ## rid -> trận {rid, slot, base, mode, box, seed, started, squads: [{sid, members, names}], alive: {cid: true},
                         ##   joined: {cid: true}, ranks: {sid: hạng}, state "playing" | "ended", ended_at, monsters, spawn: {sid: Vector2}}
var match_of := {}       ## character_id -> rid trận đã ghép (kể cả chưa vào kịp)
var grid: MapGrid        ## map Tống Kim 1 (nạp lần đầu cần)
var min_squads := 2
var search_sec := PubgManager.MATCH_SEARCH_SEC
var always_open := false
var tz_offset_sec := 7 * 3600     ## giờ mở tính theo giờ Việt Nam (máy chủ Docker thường chạy UTC)
var _free_slots: Array[int] = []
var _next_slot := FIRST_SLOT
var _tick_in := 0.0

func _init(server) -> void:
	gs = server
	min_squads = maxi(1, int(gs._env("PUBG_MIN_SQUADS", "2")))
	search_sec = float(gs._env("PUBG_SEARCH_SEC", str(PubgManager.MATCH_SEARCH_SEC)))
	always_open = gs._env("PUBG_ALWAYS_OPEN", "0") == "1"
	tz_offset_sec = int(float(gs._env("PUBG_TZ_OFFSET_HOURS", "7")) * 3600.0)
	print("Chiến Trường Sinh Tồn: giờ mở %s (UTC%+d)%s, tối thiểu %d đội/trận, tìm trận %ds" % [PubgManager.schedule_text(),
		tz_offset_sec / 3600, " — LUÔN MỞ" if always_open else "", min_squads, int(search_sec)])

func _grid() -> MapGrid:
	if grid == null:
		grid = MapGrid.load_from(PubgManager.TONGKIM1_DIR)
	return grid

## Giây trong ngày theo giờ Việt Nam (không phụ thuộc múi giờ máy chủ).
func now_sec_of_day() -> int:
	return posmod(int(Time.get_unix_time_from_system()) + tz_offset_sec, 86400)

func _closed_reason() -> String:
	return "Chiến Trường Sinh Tồn chỉ mở %s.
Còn %s nữa mới mở." % [PubgManager.schedule_text(),
		PubgManager.fmt_hms(PubgManager.secs_until_open(now_sec_of_day()))]

func is_open_for(c) -> bool:
	return always_open or c.is_gm or PubgManager.is_open_at(now_sec_of_day())

# ---------------------------------------------------------------- tra cứu cho GameServer

func in_match(c) -> bool:
	return c != null and c.pubg_match != 0

func has_room(rid: int) -> bool:
	return matches.has(rid)

func grid_of_room(rid: int) -> MapGrid:
	return _grid() if matches.has(rid) else null

## Khác đội trong cùng trận, cả 2 còn sống, trận đang đấu.
func allows_hit(a, b) -> bool:
	if a == null or b == null or a.pubg_match == 0 or a.pubg_match != b.pubg_match:
		return false
	var m: Dictionary = matches.get(a.pubg_match, {})
	if m.is_empty() or m.state != "playing":
		return false
	if not m.alive.has(a.character_id) or not m.alive.has(b.character_id):
		return false
	return _squad_of(m, a.character_id) != _squad_of(m, b.character_id)

# ---------------------------------------------------------------- tin từ game

func on_pubg(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 1024))
	var args: Dictionary = parsed if parsed is Dictionary else {}
	if c.pubg_match != 0:
		if op == OP_QUIT:
			_eliminate(c.character_id, "Bỏ trận")
			gs.kick(c, "pubg_end", "Đã rời Chiến Trường Sinh Tồn.")
		elif op == OP_STATE:
			_send_match_state(matches.get(c.pubg_match, {}), c)
		elif op == OP_DRAFT:
			_draft(c, args)
		return
	match op:
		OP_CREATE:
			_create(c, clampi(int(args.get("mode", 1)), 1, 4), bool(args.get("fill", false)), bool(args.get("quick", false)))
		OP_JOIN:
			_join(c, PubgManager.normalize_room_code(str(args.get("code", ""))), str(args.get("password", "")).strip_edges())
		OP_LEAVE:
			_leave_room(c.character_id)
			_send(c, {"op": "none"})
		OP_READY:
			_set_ready(c, bool(args.get("ready", true)))
		OP_KICK:
			_kick_member(c, int(args.get("cid", 0)))
		OP_PASSWORD:
			_set_password(c, str(args.get("password", "")).strip_edges().left(16))
		OP_FILL:
			_set_fill(c, bool(args.get("on", false)))
		OP_CHAT:
			_chat(c, str(args.get("text", "")).strip_edges().left(MAX_CHAT), str(args.get("to", "")))
		OP_SEARCH:
			_search(c)
		OP_CANCEL:
			_cancel_search(c)
		OP_STATE:
			var r: Dictionary = rooms.get(room_of.get(c.character_id, ""), {})
			if r.is_empty():
				_send(c, {"op": "none", "schedule": _schedule_info(c)})
			else:
				_send(c, _room_msg(r, c))
				_send(c, {"op": "chat_log", "lines": r.chat})

# ---------------------------------------------------------------- đội chờ

func _create(c, mode: int, fill: bool, quick: bool) -> void:
	if not is_open_for(c):
		_reject(c, _closed_reason())
		return
	if match_of.has(c.character_id):
		_reject(c, "Bạn đang có trận chưa kết thúc.")
		return
	_leave_room(c.character_id)
	var id := ""
	while id == "" or rooms.has(id):
		id = "PUBG-%04d" % randi_range(1000, 9999)
	var r := {"id": id, "mode": mode, "fill": fill and mode > 1, "quick": quick, "password": "", "leader": c.character_id,
		"members": [c.character_id], "ready": {c.character_id: quick or mode == 1}, "searching": false, "search_since": 0.0,
		"chat": [], "created": gs.now()}
	rooms[id] = r
	room_of[c.character_id] = id
	if mode > 1:
		_system(r, "%s đã tạo đội. Gửi mã [color=#ffd84a]%s[/color] cho bạn bè để vào cùng đội." % [_name(c.character_id), id])
	_broadcast_room(r)
	if quick or mode == 1:
		_search(c)

func _join(c, code: String, password: String) -> void:
	if not is_open_for(c):
		_reject(c, _closed_reason())
		return
	if match_of.has(c.character_id):
		_reject(c, "Bạn đang có trận chưa kết thúc.")
		return
	var r: Dictionary = rooms.get(code, {})
	if r.is_empty():
		_reject(c, "❓ Không tìm thấy đội có mã %s." % code, "not_found")
		return
	if r.members.has(c.character_id):
		_broadcast_room(r)
		return
	if r.searching:
		_reject(c, "🔍 Đội %s đang tìm trận, hãy chờ chủ đội hủy tìm." % code, "searching")
		return
	if (r.members as Array).size() >= int(r.mode):
		_reject(c, "⚠️ Đội %s đã đủ người!" % code, "full")
		return
	if str(r.password) != "" and password != str(r.password):
		_reject(c, "Sai mật khẩu đội %s." % code, "password")
		return
	_leave_room(c.character_id)
	r.members.append(c.character_id)
	r.ready[c.character_id] = false
	room_of[c.character_id] = code
	_system(r, "%s đã vào đội." % _name(c.character_id))
	_broadcast_room(r)
	_send(c, {"op": "chat_log", "lines": r.chat})

func _leave_room(cid: int) -> void:
	var id: String = room_of.get(cid, "")
	if id == "":
		return
	room_of.erase(cid)
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		return
	r.members.erase(cid)
	r.ready.erase(cid)
	if (r.members as Array).is_empty():
		rooms.erase(id)
		return
	if r.searching:
		_stop_search(r, "%s đã rời đội — dừng tìm trận." % _name(cid))
	if int(r.leader) == cid:
		r.leader = int(r.members[0])
		_system(r, "%s rời đội. %s làm chủ đội." % [_name(cid), _name(r.leader)])
	else:
		_system(r, "%s đã rời đội." % _name(cid))
	_broadcast_room(r)

func _own_room(c) -> Dictionary:
	var r: Dictionary = rooms.get(room_of.get(c.character_id, ""), {})
	if r.is_empty():
		_send(c, {"op": "none"})
	return r

func _set_ready(c, on: bool) -> void:
	var r := _own_room(c)
	if r.is_empty() or r.searching:
		return
	r.ready[c.character_id] = on
	_broadcast_room(r)

func _kick_member(c, cid: int) -> void:
	var r := _own_room(c)
	if r.is_empty() or int(r.leader) != c.character_id or cid == c.character_id or not r.members.has(cid) or r.searching:
		return
	_system(r, "%s đã bị mời ra khỏi đội." % _name(cid))
	_leave_room(cid)
	var t = gs.conn_of_character(cid)
	if t:
		_send(t, {"op": "none", "msg": "Bạn đã bị chủ đội mời ra."})

func _set_password(c, pw: String) -> void:
	var r := _own_room(c)
	if r.is_empty() or int(r.leader) != c.character_id:
		return
	r.password = pw
	_system(r, "Chủ đội đã %s mật khẩu." % ("đặt" if pw != "" else "bỏ"))
	_broadcast_room(r)

func _set_fill(c, on: bool) -> void:
	var r := _own_room(c)
	if r.is_empty() or int(r.leader) != c.character_id or r.searching:
		return
	r.fill = on and int(r.mode) > 1
	_broadcast_room(r)

func _chat(c, text: String, to: String) -> void:
	var r := _own_room(c)
	if r.is_empty() or text == "":
		return
	if c.muted_until > Time.get_unix_time_from_system():
		_reject(c, "Bạn đang bị cấm chat.")
		return
	var line := {"from": _name(c.character_id), "to": to, "text": text}
	if to == "":
		r.chat.append(line)
		if r.chat.size() > CHAT_KEEP:
			r.chat.pop_front()
		for cid in r.members:
			_send_cid(cid, {"op": "chat", "line": line})
	else:
		for cid in r.members:
			if _name(cid) == to or cid == c.character_id:
				_send_cid(cid, {"op": "chat", "line": line})

func _system(r: Dictionary, bbcode: String) -> void:
	var line := {"from": "", "to": "", "text": bbcode, "system": true}
	r.chat.append(line)
	if r.chat.size() > CHAT_KEEP:
		r.chat.pop_front()
	for cid in r.members:
		_send_cid(cid, {"op": "chat", "line": line})

func _search(c) -> void:
	var r := _own_room(c)
	if r.is_empty() or r.searching:
		return
	if int(r.leader) != c.character_id:
		_reject(c, "Chỉ chủ đội mới bấm tìm trận.")
		return
	if not is_open_for(c):
		_reject(c, _closed_reason())
		return
	for cid in r.members:
		if not bool(r.ready.get(cid, false)):
			_reject(c, "Còn thành viên chưa sẵn sàng.")
			return
	if (r.members as Array).size() < int(r.mode) and not r.fill:
		_reject(c, "Đội chưa đủ %d người — bật Tự ghép đội để ghép thêm người lạ." % int(r.mode))
		return
	r.searching = true
	r.search_since = gs.now()
	_system(r, "Bắt đầu tìm trận…")
	_broadcast_room(r)
	_matchmake()

func _cancel_search(c) -> void:
	var r := _own_room(c)
	if r.is_empty() or not r.searching:
		return
	_stop_search(r, "%s đã hủy tìm trận." % _name(c.character_id))

func _stop_search(r: Dictionary, why: String) -> void:
	r.searching = false
	r.search_since = 0.0
	_system(r, why)
	_broadcast_room(r)

# ---------------------------------------------------------------- ghép trận

## Đội tìm trận cùng kiểu, ghép nhóm "tự ghép" thiếu người với nhau (tổng <= số người mỗi đội). Trả [[mã đội...], ...] = các đội trận.
func _squads_for(mode: int) -> Array:
	var full: Array = []
	var partial: Array = []
	for id in rooms:
		var r: Dictionary = rooms[id]
		if not r.searching or int(r.mode) != mode:
			continue
		if (r.members as Array).size() >= mode or not r.fill:
			full.append([id])
		else:
			partial.append(id)
	partial.sort_custom(func(a, b): return (rooms[a].members as Array).size() > (rooms[b].members as Array).size())
	var groups: Array = []
	for id in partial:
		var placed := false
		for g in groups:
			if _group_size(g) + (rooms[id].members as Array).size() <= mode:
				g.append(id)
				placed = true
				break
		if not placed:
			groups.append([id])
	full.append_array(groups)
	full.sort_custom(func(a, b): return _group_since(a) < _group_since(b))
	return full

func _group_size(g: Array) -> int:
	var n := 0
	for id in g:
		n += (rooms[id].members as Array).size()
	return n

func _group_since(g: Array) -> float:
	var t := INF
	for id in g:
		t = minf(t, float(rooms[id].search_since))
	return t

func _matchmake() -> void:
	for mode in range(1, 5):
		var groups := _squads_for(mode)
		if groups.is_empty():
			continue
		var cap := PubgManager.match_capacity(mode)
		## Trận đang đấu < 5 phút còn chỗ: thêm đội vào (thay vì bắt chờ).
		for g in groups.duplicate():
			var m := _backfill_match(mode, _group_size(g))
			if m.is_empty():
				continue
			## Đội tự ghép thiếu người: ưu tiên ghép vào 1 đội tự ghép còn chỗ của trận (không thả 1 mình như 1 đội riêng).
			var mate := _fill_squad(m, g)
			if not mate.is_empty():
				_join_squad(m, mate, g)
			else:
				_add_squad(m, g)
			groups.erase(g)
		if groups.is_empty():
			continue
		var players := 0
		for g in groups:
			players += _group_size(g)
		var waited: float = gs.now() - _group_since(groups[0])
		if players >= cap or (waited >= search_sec and groups.size() >= min_squads):
			var take: Array = []
			var n := 0
			for g in groups:
				if n + _group_size(g) > cap:
					break
				take.append(g)
				n += _group_size(g)
			_start_match(mode, take)
		else:
			for g in groups:
				for id in g:
					for cid in rooms[id].members:
						_send_cid(cid, {"op": "searching", "found": players, "cap": cap, "squads": groups.size(),
							"waited": int(gs.now() - float(rooms[id].search_since)), "max_wait": int(search_sec),
							"need_squads": min_squads})

func _backfill_match(mode: int, size: int) -> Dictionary:
	for rid in matches:
		var m: Dictionary = matches[rid]
		if m.state != "playing" or int(m.mode) != mode or gs.now() - float(m.started) > BACKFILL_MAX_SEC:
			continue
		if _match_players(m) + size <= PubgManager.match_capacity(mode):
			return m
	return {}

## Đội tự ghép (thiếu người) trong trận còn chỗ cho nhóm `g` (cũng là đội tự ghép thiếu người). {} = không có.
func _fill_squad(m: Dictionary, g: Array) -> Dictionary:
	var size := _group_size(g)
	var g_fill := true
	for id in g:
		if not bool(rooms[id].fill):
			g_fill = false
	if not g_fill or size >= int(m.mode):
		return {}
	for s in m.squads:
		if bool(s.get("fill", false)) and (s.members as Array).size() + size <= int(m.mode):
			return s
	return {}

## Ghép nhóm đội chờ `g` vào đội `squad` đang có trong trận (cùng điểm thả).
func _join_squad(m: Dictionary, squad: Dictionary, g: Array) -> void:
	for id in g:
		var r: Dictionary = rooms.get(id, {})
		for cid in r.get("members", []):
			squad.members.append(cid)
			squad.names.append(_name(cid))
			room_of.erase(cid)
			match_of[cid] = m.rid
			m.alive[cid] = true
		rooms.erase(id)
	for cid in squad.members:
		_send_cid(cid, _match_msg(m, cid))   ## đồng đội mới: báo lại danh sách đội (người đã vào trận chỉ cập nhật tên)

func _match_players(m: Dictionary) -> int:
	var n := 0
	for s in m.squads:
		n += (s.members as Array).size()
	return n

func _start_match(mode: int, groups: Array) -> void:
	var g := _grid()
	if g == null:
		for grp in groups:
			for id in grp:
				_stop_search(rooms[id], "Máy chủ chưa có bản đồ Chiến Trường Sinh Tồn.")
		return
	var slot: int = _free_slots.pop_back() if not _free_slots.is_empty() else _next_slot
	if slot == _next_slot:
		_next_slot += 1
	var rid := MATCH_RID_BASE + slot
	var box := PubgManager.generate_random_arena_box()
	var m := {"rid": rid, "slot": slot, "base": Vector2i(0, slot * ROOM_CELLS), "mode": mode, "box": box, "seed": randi(),
		"started": gs.now(), "squads": [], "alive": {}, "joined": {}, "ranks": {}, "state": "playing", "ended_at": 0.0,
		"monsters": [], "spawn": {}, "next_sid": 1, "state_in": 0.0}
	matches[rid] = m
	_spawn_monsters(m)
	for grp in groups:
		_add_squad(m, grp)
	print("PUBG: mở trận #%d (%d người/đội) — %d đội, %d người, %d quái" % [rid, mode, m.squads.size(), _match_players(m), m.monsters.size()])

## Đưa 1 nhóm đội chờ (đã gộp) vào trận: đóng đội chờ, cấp điểm thả, báo từng người vào trận.
func _add_squad(m: Dictionary, grp: Array) -> void:
	var sid := int(m.next_sid)
	m.next_sid = sid + 1
	var members: Array = []
	var fill := true
	for id in grp:
		var r: Dictionary = rooms.get(id, {})
		fill = fill and bool(r.get("fill", false))
		for cid in r.get("members", []):
			members.append(cid)
			room_of.erase(cid)
		rooms.erase(id)
	var names: Array = members.map(func(cid): return _name(cid))
	m.squads.append({"sid": sid, "members": members, "names": names, "fill": fill and members.size() < int(m.mode)})
	var box: Rect2 = m.box
	var center := box.get_center()
	var p := center + Vector2(randf_range(-0.5, 0.5) * box.size.x * SPAWN_SPREAD, randf_range(-0.5, 0.5) * box.size.y * SPAWN_SPREAD)
	var spawn: Vector2 = _grid().open_spawn_near(p)
	if spawn == Vector2.ZERO:
		spawn = _grid().open_spawn_near(center)
	m.spawn[sid] = spawn
	for cid in members:
		match_of[cid] = m.rid
		m.alive[cid] = true
		_send_cid(cid, _match_msg(m, cid))

func _match_msg(m: Dictionary, cid: int) -> Dictionary:
	var box: Rect2 = m.box
	var sid := _squad_of(m, cid)
	var sp: Vector2 = m.spawn.get(sid, box.get_center())
	var squad: Dictionary = _squad(m, sid)
	return {"op": "match", "rid": m.rid, "mode": m.mode, "box": [box.position.x, box.position.y, box.size.x, box.size.y],
		"seed": m.seed, "elapsed": gs.now() - float(m.started), "spawn": [sp.x, sp.y], "squad": squad.get("names", []),
		"squad_id": sid, "players": _match_players(m), "squads": m.squads.size()}

## Quái của map trong khung chơi (map Tống Kim 1 có ~20 nghìn quái, chỉ sinh phần nằm trong khung của trận).
func _spawn_monsters(m: Dictionary) -> void:
	var box: Rect2 = m.box
	for n in _grid().data.get("npcs", []):
		if str(n.get("role", "")) != "monster":
			continue
		if not box.has_point(Vector2(float(n.get("px", 0)), float(n.get("py", 0)))):
			continue
		var mon := ServerMonster.from_entry(n, 0)
		if mon == null:
			continue
		mon.room_id = m.rid
		mon.cell_base = m.base
		gs.add_monster(mon)
		m.monsters.append(mon)

## Đồ rơi của quái trong trận: Hoàng Kim môn phái 90%, thuốc 50%, ngựa 20% (như bản offline).
static func roll_drops() -> Array:
	var out: Array = []
	if randf() <= 0.90:
		var gold := DropTable.roll_sect_gold_item()
		if gold != null:
			out.append({"type": "item", "item": gold})
	if randf() <= 0.50:
		var pot := DropTable.roll_pharmacy_item()
		if pot != null:
			out.append({"type": "item", "item": pot})
	if randf() <= 0.20:
		var horse := DropTable.roll_horse()
		if horse != null:
			out.append({"type": "item", "item": horse})
	return out

# ---------------------------------------------------------------- vào / trong trận

## Kết nối thường (HELLO_WORLD) của người đã được ghép trận: thay hồ sơ bằng hồ sơ tạm cấp 200. Trả về true nếu là người của trận.
func on_hello(c) -> bool:
	var rid: int = int(match_of.get(c.character_id, 0))
	var m: Dictionary = matches.get(rid, {})
	if m.is_empty() or m.state != "playing" or not m.alive.has(c.character_id):
		match_of.erase(c.character_id)
		return false
	c.pubg_match = rid
	var p := PlayerProfile.from_dict(c.data.duplicate(true))
	PubgManager.apply_match_build(p, false)
	c.profile = p
	c.data = p.to_dict()
	c.dirty = false
	return true

## Gọi sau khi thực thể đã tạo: đặt vào phòng của trận + điểm thả của đội.
func place(c) -> void:
	var m: Dictionary = matches.get(c.pubg_match, {})
	if m.is_empty() or c.entity == null:
		return
	m.joined[c.character_id] = true
	c.entity.room_id = m.rid
	c.entity.cell_base = m.base
	var sid := _squad_of(m, c.character_id)
	var sp: Vector2 = m.spawn.get(sid, (m.box as Rect2).get_center())
	c.entity.pos = _grid().free_near(sp + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
	c.view_cell = Vector2i(1 << 30, 1 << 30)

## Sau S_WELCOME + S_PROFILE: báo thông tin trận (khung, seed, thời gian đã đấu) để máy người chơi dựng vòng bo.
func on_entered(c) -> void:
	var m: Dictionary = matches.get(c.pubg_match, {})
	if m.is_empty():
		return
	_send(c, _match_msg(m, c.character_id))
	_broadcast_match_state(m)

## Chọn thẻ đầu trận (popup PubgDraftPopup): ngựa 8x + vũ khí cấp 10 + điểm tiềm năng theo build đã lưu. Server tự sinh đồ
## (đồ máy người chơi tự sinh không qua được ProfileGuard). Mỗi người 1 lần mỗi trận.
func _draft(c, args: Dictionary) -> void:
	var m: Dictionary = matches.get(c.pubg_match, {})
	if m.is_empty() or m.state != "playing":
		return
	if not m.has("drafted"):
		m["drafted"] = {}
	if m.drafted.has(c.character_id):
		return
	m.drafted[c.character_id] = true
	var p: PlayerProfile = c.profile
	var elem := int(p.get_element())
	var horse := PubgDraftPopup.make_horse(int(args.get("horse", 1)), elem)
	var weapon := PubgDraftPopup.make_weapon(int(args.get("weapon", 0)), elem)
	if horse != null:
		p.equipment[Equipment.Part.HORSE] = horse
		p.riding = true
	if weapon != null:
		p.equipment[Equipment.Part.WEAPON] = weapon
	var build: Dictionary = args.get("build", {}) if args.get("build", {}) is Dictionary else {}
	var add := {}
	var total := 0
	for k in ["str", "dex", "vit", "eng"]:
		add[k] = maxi(0, int(build.get(k, 0)))
		total += int(add[k])
	if total > 0 and total <= p.potential_points:
		p.strength += int(add.str)
		p.dexterity += int(add.dex)
		p.vitality += int(add.vit)
		p.energy += int(add.eng)
		p.potential_points -= total
	if p.has_method("recalc_stats"):
		p.recalc_stats()
	gs.profile_changed(c)

func on_died(c) -> void:
	if c.pubg_match != 0:
		_eliminate(c.character_id, "Trọng thương")

## Chết trong trận: không hồi sinh (đứng xem tới khi có kết quả). true = GameServer không xử lý tiếp.
func on_revive(c) -> bool:
	return c.pubg_match != 0

func on_leave(c) -> void:
	if c.hub:
		_leave_room(c.character_id)
		return
	if c.pubg_match != 0:
		_eliminate(c.character_id, "Rời trận")
		if c.entity:
			c.entity.room_id = 0
			c.entity.cell_base = Vector2i.ZERO

func _eliminate(cid: int, why: String) -> void:
	var rid: int = int(match_of.get(cid, 0))
	var m: Dictionary = matches.get(rid, {})
	if m.is_empty() or not m.alive.has(cid):
		return
	m.alive.erase(cid)
	var sid := _squad_of(m, cid)
	var squad_dead := true
	for other in _squad(m, sid).get("members", []):
		if m.alive.has(other):
			squad_dead = false
			break
	var alive_squads := _alive_squads(m)
	if squad_dead and m.state == "playing":
		m.ranks[sid] = alive_squads.size() + 1
	var t = gs.conn_of_character(cid)
	if t and t.pubg_match == rid:
		_send(t, {"op": "eliminated", "why": why, "rank": int(m.ranks.get(sid, 0)), "squads": m.squads.size(),
			"squad_out": squad_dead, "alive_players": m.alive.size()})
	if m.state == "playing" and alive_squads.size() <= 1:
		_finish(m, "Đội cuối cùng còn trụ lại!" if alive_squads.size() == 1 else "Không còn ai sống sót.")
	else:
		_broadcast_match_state(m)

func _alive_squads(m: Dictionary) -> Array:
	var out: Array = []
	for s in m.squads:
		for cid in s.members:
			if m.alive.has(cid):
				out.append(int(s.sid))
				break
	return out

func _finish(m: Dictionary, why: String) -> void:
	if m.state != "playing":
		return
	m.state = "ended"
	m.ended_at = gs.now()
	var alive := _alive_squads(m)
	## Hết giờ còn nhiều đội: đội còn nhiều người sống hơn xếp trên.
	alive.sort_custom(func(a, b): return _alive_in(m, a) > _alive_in(m, b))
	for i in alive.size():
		m.ranks[alive[i]] = i + 1
	var winner_names: Array = _squad(m, alive[0]).get("names", []) if not alive.is_empty() else []
	print("PUBG: kết thúc trận #%d — thắng: %s" % [m.rid, ", ".join(PackedStringArray(winner_names.map(func(n): return str(n))))])
	for s in m.squads:
		for cid in s.members:
			var t = gs.conn_of_character(cid)
			if t and t.pubg_match == m.rid:
				var rank := int(m.ranks.get(s.sid, m.squads.size()))
				_send(t, {"op": "result", "win": rank == 1, "rank": rank, "squads": m.squads.size(), "why": why,
					"winners": winner_names})

func _alive_in(m: Dictionary, sid: int) -> int:
	var n := 0
	for cid in _squad(m, sid).get("members", []):
		if m.alive.has(cid):
			n += 1
	return n

func _close_match(m: Dictionary) -> void:
	matches.erase(m.rid)
	for s in m.squads:
		for cid in s.members:
			if int(match_of.get(cid, 0)) == m.rid:
				match_of.erase(cid)
			var t = gs.conn_of_character(cid)
			if t and t.pubg_match == m.rid:
				gs.kick(t, "pubg_end", "Chiến Trường Sinh Tồn đã kết thúc.")
	for mon: ServerMonster in m.monsters:
		gs.remove_monster(mon)
	m.monsters.clear()
	gs.clear_room_drops(m.rid)
	_free_slots.append(int(m.slot))
	print("PUBG: đóng trận #%d" % m.rid)

func tick(delta: float) -> void:
	_tick_in -= delta
	if _tick_in > 0.0:
		return
	_tick_in = 1.0
	_matchmake()
	var max_len := _zone_total_sec() + MATCH_EXTRA_SEC
	for rid in matches.keys():
		var m: Dictionary = matches[rid]
		var age: float = gs.now() - float(m.started)
		if m.state == "playing":
			for cid in m.alive.keys():
				if not m.joined.has(cid) and age >= JOIN_TIMEOUT:
					_eliminate(cid, "Không vào trận kịp")
			if m.state == "playing" and age >= max_len:
				_finish(m, "Hết giờ — xếp hạng theo số người còn sống.")
			elif m.state == "playing":
				m.state_in = float(m.state_in) - 1.0
				if m.state_in <= 0.0:
					m.state_in = 3.0
					_broadcast_match_state(m)
		elif gs.now() - float(m.ended_at) >= END_SEC:
			_close_match(m)

static func _zone_total_sec() -> float:
	var t := 0.0
	for i in PubgManager.ZONE_COUNT:
		t += PubgManager.zone_wait_sec(i) + PubgManager.zone_shrink_sec(i)
	return t

# ---------------------------------------------------------------- gửi tin

func _squad_of(m: Dictionary, cid: int) -> int:
	for s in m.squads:
		if (s.members as Array).has(cid):
			return int(s.sid)
	return 0

func _squad(m: Dictionary, sid: int) -> Dictionary:
	for s in m.squads:
		if int(s.sid) == sid:
			return s
	return {}

func _broadcast_match_state(m: Dictionary) -> void:
	for s in m.squads:
		for cid in s.members:
			var t = gs.conn_of_character(cid)
			if t and t.pubg_match == m.rid:
				_send_match_state(m, t)

func _send_match_state(m: Dictionary, c) -> void:
	if m.is_empty():
		return
	var my_sid := _squad_of(m, c.character_id)
	var squad_eids: Array = []
	var enemy_eids: Array = []
	for s in m.squads:
		for cid in s.members:
			var t = gs.conn_of_character(cid)
			if t == null or t.entity == null or t.pubg_match != m.rid:
				continue
			if int(s.sid) == my_sid:
				squad_eids.append(t.entity.eid)
			elif m.alive.has(cid):
				enemy_eids.append(t.entity.eid)
	_send(c, {"op": "mstate", "alive_players": m.alive.size(), "alive_squads": _alive_squads(m).size(), "squads": m.squads.size(),
		"squad_eids": squad_eids, "enemy_eids": enemy_eids, "elapsed": gs.now() - float(m.started), "state": m.state})

func _name(cid: int) -> String:
	var t = gs.conn_of_character(cid)
	if t and t.entity:
		return t.entity.name
	if t and t.profile:
		return t.profile.display_name
	return "?"

func _schedule_info(c) -> Dictionary:
	var now := now_sec_of_day()
	return {"open": is_open_for(c), "until_open": PubgManager.secs_until_open(now), "until_close": PubgManager.secs_until_close(now),
		"always": always_open, "gm": c.is_gm}

func _room_msg(r: Dictionary, viewer) -> Dictionary:
	var members: Array = []
	for cid in r.members:
		var t = gs.conn_of_character(cid)
		var info := {"cid": cid, "name": _name(cid), "leader": cid == int(r.leader), "ready": bool(r.ready.get(cid, false)),
			"is_self": viewer != null and cid == viewer.character_id}
		if t and t.profile:
			var sect := SectRegistry.get_by_id(t.profile.sect_id)
			info["level"] = t.profile.level
			info["sect"] = sect.sect_name if sect else "Vô môn phái"
			info["gender"] = "female" if t.profile.gender == PlayerProfile.Gender.FEMALE else "male"
			var lk := GameServer.look_from_profile(t.data)
			info["look"] = {"helm": int(lk.get("helm", -1)), "armor": int(lk.get("armor", -1)), "weapon": int(lk.get("weapon", -1)),
				"horse": int(lk.get("horse", -1))}
		members.append(info)
	return {"op": "room", "room": {"id": r.id, "mode": int(r.mode), "fill": bool(r.fill), "quick": bool(r.quick),
		"has_password": str(r.password) != "", "password": str(r.password) if viewer != null and viewer.character_id == int(r.leader) else "",
		"leader_cid": int(r.leader), "members": members, "searching": bool(r.searching),
		"waited": int(gs.now() - float(r.search_since)) if r.searching else 0, "max_wait": int(search_sec),
		"cap": PubgManager.match_capacity(int(r.mode))}, "schedule": _schedule_info(viewer)}

func _broadcast_room(r: Dictionary) -> void:
	for cid in r.members:
		var t = gs.conn_of_character(cid)
		if t:
			_send(t, _room_msg(r, t))

func _reject(c, text: String, code := "") -> void:
	_send(c, {"op": "reject", "msg": text, "code": code})

func _send_cid(cid: int, msg: Dictionary) -> void:
	var t = gs.conn_of_character(cid)
	if t:
		_send(t, msg)

func _send(c, msg: Dictionary) -> void:
	var b := NetProto.writer(NetProto.S_PUBG)
	NetProto.put_json(b, msg)
	gs.send(c, b)

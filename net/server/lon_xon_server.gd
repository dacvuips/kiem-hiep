extends RefCounted
class_name LonXonServer
## LỘN XỘN ONLINE (docs/plans/lon-xon.md) — hỗn chiến tự do, chạy ngay trên game server thế giới cạnh PubgServer.
##
## - HOST_COUNT host dựng sẵn (lần đầu có người hỏi), sống mãi: mỗi host 1 khung 140x80 region ngẫu nhiên trên Tống Kim 1
##   (như PUBG, KHÔNG vòng bo, KHÔNG hết giờ), 1 "phòng" thực thể riêng (room_id + cell_base) -> ngoài host không thấy / đánh được.
## - Từ Hub (kết nối sảnh): OP_STATE xem số người từng host, OP_JOIN {host} giữ chỗ -> "match". Game vào map bằng kết nối thường
##   (HELLO_WORLD): server thay hồ sơ bằng HỒ SƠ TẠM (LonXonRules.apply_start: cấp 50) — KHÔNG BAO GIỜ LƯU.
## - Mỗi người 1 phe: ai cũng đánh được nhau (trừ người vừa hồi sinh, SPAWN_PROTECT_SEC).
## - Hạ quái (đòn cuối): +5 cấp, quái rơi đồ theo LonXonRules.roll_drops(cấp người hạ).
## - Bị hạ: TOÀN BỘ trang bị + hành trang rớt ra đất (ai cũng nhặt ngay) + Lệnh Bài (1 + ½ số đang giữ). Sau RESPAWN_SEC giây
##   game gửi C_REVIVE -> hồi sinh ở chỗ ngẫu nhiên trong khung, cấp lại thuốc, được chọn lại thẻ 5x (OP_DRAFT).
## - Lệnh Bài: món misc LonXonRules.TOKEN_ITEM_ID dưới đất; nhặt lên server cộng bộ đếm (không vào túi). Điểm = Lệnh Bài × 1000,
##   bảng Top 5 + số hạng 1/2/3 phát cho cả host khi đổi.
##
## Tin game -> server: C_LONXON u8 op + str json. Server -> game: S_LONXON json {op: ...}:
##   "hosts" {hosts: [{host, players, cap}]}          "match" {host, rid, box, spawn}         "reject" {msg}       "none"
##   "board" {top: [{name, score, tokens, eid}], badges: {eid: hạng}, sizes: {eid: Lệnh Bài}}   "tokens" {n, score}
##   "died" {respawn_in, items, tokens, killer}        "respawn" {}                           "level" {level, gained}

const OP_STATE := 1
const OP_JOIN := 2        ## {host 1..HOST_COUNT}
const OP_QUIT := 3        ## trong host: rời
const OP_DRAFT := 4       ## {horse 1-5, weapon 0-13} — chọn thẻ 5x (1 lần mỗi lần sống)

## Gói được gửi khi đang ở trong host (như PUBG: chặn giao dịch / chợ / bày bán / mua / chế tạo).
const MATCH_ALLOWED := [NetProto.C_MOVE, NetProto.C_CAST, NetProto.C_DAMAGE, NetProto.C_MSTATE, NetProto.C_PROFILE, NetProto.C_PICKUP,
	NetProto.C_DISCARD, NetProto.C_LOOK, NetProto.C_REVIVE, NetProto.C_PING, NetProto.C_PVP_HIT, NetProto.C_CHAT,
	NetProto.C_LONXON, NetProto.C_VIEW_EQUIP]

const ROOM_CELLS := 4096
const FIRST_SLOT := 8             ## host dùng slot 8..12 (PUBG dùng >= 16, map thế giới slot 0)
const RID_BASE := 8_000_000       ## room_id thực thể của host = BASE + số host
const JOIN_TIMEOUT := 90.0        ## giữ chỗ mà không vào kịp -> bỏ chỗ
const BOARD_EVERY := 0.5          ## gộp tin bảng điểm: tối đa 2 lần / giây
const DEATH_SCATTER := 46.0       ## bán kính rải đồ quanh xác

var gs   ## GameServer
var hosts := {}          ## rid -> {host, rid, slot, base, box, monsters: [], members: {cid: true}, joined: {cid: true},
                         ##   reserved_at: {cid: giây}, tokens: {cid: int}, board_dirty}
var host_of := {}        ## character_id -> rid (đã giữ chỗ / đang ở trong)
var dead_at := {}        ## character_id -> lúc chết (đang chờ hồi sinh)
var protect_until := {}  ## character_id -> hết miễn sát thương sau hồi sinh
var drafted := {}        ## character_id -> true (đã chọn thẻ 5x của lần sống này)
var grid: MapGrid
var _board_in := 0.0
var _tick_in := 0.0
## Chỉ cho bài test online (LONXON_TEST_SPAWN=1): mọi người vào / hồi sinh sát tâm khung host (bot đi bộ không phải băng cả khung).
var test_spawn := false

func _init(server) -> void:
	gs = server
	if gs.has_method("_env"):
		test_spawn = gs._env("LONXON_TEST_SPAWN", "0") == "1"
	if test_spawn:
		print("Lộn Xộn: LONXON_TEST_SPAWN=1 — vào / hồi sinh sát tâm khung (chỉ dùng khi test)")
	## Nạp sẵn lưới Tống Kim 1 lúc server khởi động (~5 giây): nạp giữa chừng lúc người đầu tiên vào host làm cả server khựng
	## (mọi người khác mất phản hồi). Dùng chung với PUBG.
	if gs is Node:
		var t0 := Time.get_ticks_msec()
		_grid()
		print("Lộn Xộn: nạp sẵn bản đồ Tống Kim 1 (%d ms)" % (Time.get_ticks_msec() - t0))

func _grid() -> MapGrid:
	if grid == null:
		var p = gs.get("pubg")
		grid = p._grid() if p != null else MapGrid.load_from(PubgManager.TONGKIM1_DIR)   ## dùng chung bản đồ đã nạp của PUBG
	return grid

## Dựng HOST_COUNT host (lần đầu cần). Quái sinh khi host có người đầu tiên.
func _ensure_hosts() -> void:
	if not hosts.is_empty():
		return
	for i in LonXonRules.HOST_COUNT:
		var slot := FIRST_SLOT + i
		var rid := RID_BASE + i + 1
		hosts[rid] = {"host": i + 1, "rid": rid, "slot": slot, "base": Vector2i(0, slot * ROOM_CELLS),
			"box": PubgManager.generate_random_arena_box(), "monsters": [], "members": {}, "joined": {}, "reserved_at": {},
			"tokens": {}, "board_dirty": false}

func host_by_index(n: int) -> Dictionary:
	_ensure_hosts()
	return hosts.get(RID_BASE + n, {})

# ---------------------------------------------------------------- tra cứu cho GameServer

## Conn.lonxon_host: > 0 = room_id host đang ở; LEFT = đã rời host nhưng kết nối này vẫn mang hồ sơ TẠM (GameServer kiểm `!= 0`
## để không bao giờ lưu / nhận quà vào hồ sơ đó — kết nối sắp bị đóng); 0 = không liên quan Lộn Xộn.
const LEFT := -1

func in_host(c) -> bool:
	return c != null and int(c.get("lonxon_host")) > 0

func has_room(rid: int) -> bool:
	return hosts.has(rid)

func grid_of_room(rid: int) -> MapGrid:
	return _grid() if hosts.has(rid) else null

## Cùng host, khác người, bên bị đánh không đang miễn sát thương sau hồi sinh.
func allows_hit(a, b) -> bool:
	if a == null or b == null or a == b or not in_host(a) or a.lonxon_host != b.lonxon_host:
		return false
	if dead_at.has(a.character_id) or dead_at.has(b.character_id):
		return false
	return gs.now() >= float(protect_until.get(b.character_id, 0.0))

func tokens_of(cid: int) -> int:
	var h: Dictionary = hosts.get(int(host_of.get(cid, 0)), {})
	return int(h.get("tokens", {}).get(cid, 0)) if not h.is_empty() else 0

# ---------------------------------------------------------------- tin từ game

func on_lonxon(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 1024))
	var args: Dictionary = parsed if parsed is Dictionary else {}
	handle(c, op, args)

func handle(c, op: int, args: Dictionary) -> void:
	if in_host(c):
		match op:
			OP_QUIT:
				_leave(c, "Rời Lộn Xộn")
				gs.kick(c, "lonxon_end", "Đã rời Lộn Xộn.")
			OP_DRAFT:
				_draft(c, args)
			OP_STATE:
				_send_board_to(hosts.get(c.lonxon_host, {}), c)
				_send(c, {"op": "tokens", "n": tokens_of(c.character_id), "score": LonXonRules.score_for(tokens_of(c.character_id))})
		return
	match op:
		OP_STATE:
			_send(c, _hosts_msg())
		OP_JOIN:
			_join(c, int(args.get("host", 0)))

func _hosts_msg() -> Dictionary:
	_ensure_hosts()
	var out: Array = []
	for rid in hosts:
		var h: Dictionary = hosts[rid]
		out.append({"host": int(h.host), "players": (h.members as Dictionary).size(), "cap": LonXonRules.HOST_CAPACITY})
	out.sort_custom(func(a, b): return int(a.host) < int(b.host))
	return {"op": "hosts", "hosts": out}

## Giữ chỗ trong host `n` (từ Hub) rồi báo "match" -> game vào map.
func _join(c, n: int) -> void:
	var h := host_by_index(n)
	if h.is_empty():
		_reject(c, "Host không tồn tại.")
		return
	var p = gs.get("pubg")
	if p != null and (int(c.get("pubg_match")) != 0 or p.room_of.has(c.character_id) or p.match_of.has(c.character_id)):
		_reject(c, "Đang ở trong Chiến Trường Sinh Tồn — hãy rời đội / trận PUBG trước.")
		return
	var old: int = int(host_of.get(c.character_id, 0))
	if old != 0 and old != int(h.rid):
		_remove_member(c.character_id)
	if not h.members.has(c.character_id) and (h.members as Dictionary).size() >= LonXonRules.HOST_CAPACITY:
		_reject(c, "Host %d đã đủ %d người." % [n, LonXonRules.HOST_CAPACITY])
		return
	h.members[c.character_id] = true
	h.reserved_at[c.character_id] = gs.now()
	host_of[c.character_id] = h.rid
	if (h.monsters as Array).is_empty():
		_spawn_monsters(h)
	_send(c, _match_msg(h))

func _match_msg(h: Dictionary) -> Dictionary:
	var box: Rect2 = h.box
	var c := box.get_center()
	return {"op": "match", "host": int(h.host), "rid": int(h.rid), "box": [box.position.x, box.position.y, box.size.x, box.size.y],
		"spawn": [c.x, c.y]}

## Quái của map nằm trong khung host (như PubgServer._spawn_monsters) — hồi sinh theo nhịp thường của GameServer.
func _spawn_monsters(h: Dictionary) -> void:
	var g := _grid()
	if g == null:
		return
	var box: Rect2 = h.box
	for n in g.data.get("npcs", []):
		if str(n.get("role", "")) != "monster":
			continue
		if not box.has_point(Vector2(float(n.get("px", 0)), float(n.get("py", 0)))):
			continue
		var mon := ServerMonster.from_entry(n, 0)
		if mon == null:
			continue
		mon.room_id = h.rid
		mon.cell_base = h.base
		gs.add_monster(mon)
		h.monsters.append(mon)
	print("Lộn Xộn: host %d — %d quái" % [int(h.host), (h.monsters as Array).size()])

# ---------------------------------------------------------------- vào / trong host

## Kết nối thường (HELLO_WORLD) của người đã giữ chỗ: thay hồ sơ bằng hồ sơ tạm cấp 50. true = người của Lộn Xộn.
func on_hello(c) -> bool:
	var rid: int = int(host_of.get(c.character_id, 0))
	var h: Dictionary = hosts.get(rid, {})
	if h.is_empty() or not h.members.has(c.character_id):
		host_of.erase(c.character_id)
		return false
	c.lonxon_host = rid
	var p := PlayerProfile.from_dict(c.data.duplicate(true))
	LonXonRules.apply_start(p)
	c.profile = p
	c.data = p.to_dict()
	c.dirty = false
	dead_at.erase(c.character_id)
	drafted.erase(c.character_id)
	h.tokens[c.character_id] = 0
	return true

## Sau khi thực thể đã tạo: vào phòng của host + chỗ ngẫu nhiên trong khung.
func place(c) -> void:
	var h: Dictionary = hosts.get(int(c.lonxon_host), {})
	if h.is_empty() or c.entity == null:
		return
	h.joined[c.character_id] = true
	c.entity.room_id = h.rid
	c.entity.cell_base = h.base
	c.entity.pos = random_spot(h)
	c.view_cell = Vector2i(1 << 30, 1 << 30)

## Chỗ đứng ngẫu nhiên trong khung host (giữa 80% khung, ô đi được).
func random_spot(h: Dictionary) -> Vector2:
	var box: Rect2 = h.box
	var g := _grid()
	if test_spawn and g != null:
		## Test: mọi người đứng chung 1 chỗ cạnh con quái đầu tiên của host (khung ngẫu nhiên — tâm khung có thể không có quái gần).
		var anchor: Vector2 = (h.monsters[0] as ServerMonster).pos + Vector2(160, 0) if not (h.monsters as Array).is_empty() else box.get_center()
		return g.open_spawn_near(anchor + Vector2(randf_range(-40, 40), randf_range(-20, 20)))
	for i in 8:
		var p := box.position + Vector2(randf_range(0.1, 0.9) * box.size.x, randf_range(0.1, 0.9) * box.size.y)
		var s: Vector2 = g.free_near(p) if g != null else p
		if s != Vector2.ZERO and box.has_point(s):
			return s
	return g.open_spawn_near(box.get_center()) if g != null else box.get_center()

func on_entered(c) -> void:
	var h: Dictionary = hosts.get(int(c.lonxon_host), {})
	if h.is_empty():
		return
	_send(c, _match_msg(h))
	_send(c, {"op": "tokens", "n": 0, "score": 0})
	_send_board_to(h, c)
	_mark_board(h)

## Chọn thẻ 5x (popup PubgDraftPopup tier 5): server tự sinh ngựa + vũ khí, tự cộng Sức/Thân cho đủ cầm vũ khí.
func _draft(c, args: Dictionary) -> void:
	if drafted.has(c.character_id) or dead_at.has(c.character_id):
		return
	drafted[c.character_id] = true
	var p: PlayerProfile = c.profile
	var elem := int(p.get_element())
	var horse := PubgDraftPopup.make_horse(int(args.get("horse", 1)), elem, PubgDraftPopup.TIER_LONXON)
	var weapon := PubgDraftPopup.make_weapon(int(args.get("weapon", 0)), elem, PubgDraftPopup.TIER_LONXON)
	if horse != null:
		p.equipment[Equipment.Part.HORSE] = horse
		p.riding = true
	if weapon != null:
		p.equipment[Equipment.Part.WEAPON] = weapon
		PubgDraftPopup.auto_meet_weapon(p, weapon)
	if p.has_method("recalc_stats"):
		p.call("recalc_stats")
	gs.profile_changed(c)

## Người hạ đòn cuối 1 quái trong host: +5 cấp.
func on_monster_killed(c) -> void:
	if c == null or not in_host(c) or dead_at.has(c.character_id):
		return
	var gained := LonXonRules.on_monster_kill(c.profile)
	if gained <= 0:
		return
	if c.entity:
		c.entity.level = c.profile.level
	gs.profile_changed(c)
	_send(c, {"op": "level", "level": c.profile.level, "gained": gained})

## Đồ rơi của quái trong host (theo cấp người hạ).
func roll_drops(killer) -> Array:
	var lv: int = killer.profile.level if killer != null and killer.profile != null else LonXonRules.START_LEVEL
	return LonXonRules.roll_drops(lv)

## Bị hạ: đổ toàn bộ đồ + Lệnh Bài ra đất, chờ hồi sinh.
func on_died(c, killer_name := "") -> void:
	if not in_host(c) or dead_at.has(c.character_id):
		return
	dead_at[c.character_id] = gs.now()
	var dropped := _drop_everything(c)
	_send(c, {"op": "died", "respawn_in": LonXonRules.RESPAWN_SEC, "items": int(dropped.x), "tokens": int(dropped.y),
		"killer": killer_name})

## Rải đồ + Lệnh Bài của `c` quanh chỗ đứng. Trả về Vector2i(số món, số Lệnh Bài).
func _drop_everything(c) -> Vector2i:
	var h: Dictionary = hosts.get(int(c.lonxon_host), {})
	if h.is_empty() or c.entity == null or c.profile == null:
		return Vector2i.ZERO
	var items := LonXonRules.death_drops(c.profile)
	var held := int(h.tokens.get(c.character_id, 0))
	var split := LonXonRules.death_token_split(held)
	h.tokens[c.character_id] = split.y
	var list: Array = []
	for it: ItemInstance in items:
		it.room_x = -1
		it.room_y = -1
		list.append({"item": it.to_dict()})
	var token := ItemGenerator.generate_misc(LonXonRules.TOKEN_ITEM_ID, 0, 0, split.x)
	if token != null:
		list.append({"item": token.to_dict(), "token_from": c.character_id,
			"token_lock": gs.now() + LonXonRules.TOKEN_OWNER_LOCK_SEC, "lifetime": LonXonRules.TOKEN_DROP_LIFETIME})
	gs.scatter_drops(c.entity, list, DEATH_SCATTER)
	gs.profile_changed(c)
	if c.entity:
		c.entity.level = c.profile.level
	_send(c, {"op": "tokens", "n": split.y, "score": LonXonRules.score_for(split.y)})
	_mark_board(h)
	return Vector2i(items.size(), split.x)

## Nhặt đồ rơi `d`: Lệnh Bài -> cộng bộ đếm, trả về true (GameServer bỏ đồ khỏi đất, không cho vào túi).
## Trả về "" = không phải Lệnh Bài (GameServer nhặt như thường); "ok" = đã nhặt; còn lại = lý do không nhặt được.
func on_pickup(c, d: Dictionary) -> String:
	var it: Dictionary = d.get("item", {})
	if str(it.get("mid", "")) != LonXonRules.TOKEN_ITEM_ID:
		return ""
	if not in_host(c) or dead_at.has(c.character_id):
		return "Không nhặt được lúc này."
	if int(d.get("token_from", 0)) == c.character_id and gs.now() < float(d.get("token_lock", 0.0)):
		return "Lệnh Bài của chính bạn — chờ %d giây nữa mới nhặt lại được." % ceili(float(d.token_lock) - gs.now())
	var h: Dictionary = hosts.get(int(c.lonxon_host), {})
	var n := maxi(1, int(it.get("count", 1)))
	var total := int(h.tokens.get(c.character_id, 0)) + n
	h.tokens[c.character_id] = total
	_send(c, {"op": "tokens", "n": total, "score": LonXonRules.score_for(total), "gained": n})
	_mark_board(h)
	return "ok"

## C_REVIVE: chỉ nhận khi đã chờ đủ RESPAWN_SEC. true = GameServer không xử lý tiếp (kể cả khi chưa đủ giờ).
func on_revive(c) -> bool:
	if not in_host(c):
		return false
	var died: float = float(dead_at.get(c.character_id, -1.0))
	if died < 0.0 or gs.now() - died < LonXonRules.RESPAWN_SEC - 0.25:
		return true
	var h: Dictionary = hosts.get(int(c.lonxon_host), {})
	dead_at.erase(c.character_id)
	drafted.erase(c.character_id)
	protect_until[c.character_id] = gs.now() + LonXonRules.SPAWN_PROTECT_SEC
	if c.entity:
		c.entity.flags &= ~NetProto.FLAG_DEAD
	LonXonRules.give_potions(c.profile)
	gs.profile_changed(c)
	if c.entity and not h.is_empty():
		gs.teleport(c, random_spot(h))
	_send(c, {"op": "respawn", "protect": LonXonRules.SPAWN_PROTECT_SEC})
	return true

func on_leave(c) -> void:
	if c.hub or not in_host(c):
		return
	_leave(c, "Rời Lộn Xộn")

## Rời host (thoát / bỏ trận / mất kết nối): đồ + Lệnh Bài rớt ra đất như chết, bỏ chỗ. Kết nối giữ dấu LEFT (hồ sơ tạm: không lưu).
func _leave(c, _why: String) -> void:
	if not in_host(c):
		return
	if not dead_at.has(c.character_id):
		_drop_everything(c)
	_remove_member(c.character_id)
	c.lonxon_host = LEFT
	c.dirty = false
	if c.entity:
		c.entity.room_id = 0
		c.entity.cell_base = Vector2i.ZERO

func _remove_member(cid: int) -> void:
	var h: Dictionary = hosts.get(int(host_of.get(cid, 0)), {})
	host_of.erase(cid)
	dead_at.erase(cid)
	drafted.erase(cid)
	protect_until.erase(cid)
	if h.is_empty():
		return
	h.members.erase(cid)
	h.joined.erase(cid)
	h.reserved_at.erase(cid)
	h.tokens.erase(cid)
	_mark_board(h)

func tick(delta: float) -> void:
	_board_in -= delta
	if _board_in <= 0.0:
		_board_in = BOARD_EVERY
		for rid in hosts:
			var h: Dictionary = hosts[rid]
			if h.board_dirty:
				h.board_dirty = false
				_broadcast_board(h)
	_tick_in -= delta
	if _tick_in > 0.0:
		return
	_tick_in = 1.0
	for rid in hosts:
		var h: Dictionary = hosts[rid]
		for cid in (h.members as Dictionary).keys():
			if not h.joined.has(cid) and gs.now() - float(h.reserved_at.get(cid, 0.0)) >= JOIN_TIMEOUT:
				_remove_member(cid)   ## giữ chỗ mà không vào kịp

# ---------------------------------------------------------------- bảng điểm

func _mark_board(h: Dictionary) -> void:
	if not h.is_empty():
		h.board_dirty = true

func board_entries(h: Dictionary) -> Array:
	var out: Array = []
	for cid in h.joined:
		var t = gs.conn_of_character(cid)
		if t == null or int(t.get("lonxon_host")) != int(h.rid):
			continue
		var n := int(h.tokens.get(cid, 0))
		out.append({"cid": cid, "eid": t.entity.eid if t.entity else 0, "name": _name(t), "tokens": n, "score": LonXonRules.score_for(n)})
	return out

func _board_msg(h: Dictionary) -> Dictionary:
	var entries := board_entries(h)
	var top: Array = []
	for e in LonXonRules.top_n(entries):
		top.append({"name": e.name, "score": e.score, "tokens": e.tokens, "eid": e.eid})
	var badges := {}
	var sizes := {}   ## eid -> số Lệnh Bài đang giữ (máy người chơi vẽ người đó to hơn)
	var by_cid := LonXonRules.rank_badges(entries)
	for e in entries:
		if by_cid.has(e.cid):
			badges[str(e.eid)] = int(by_cid[e.cid])
		if int(e.tokens) > 0:
			sizes[str(e.eid)] = int(e.tokens)
	return {"op": "board", "top": top, "badges": badges, "sizes": sizes}

func _broadcast_board(h: Dictionary) -> void:
	var msg := _board_msg(h)
	for cid in h.joined:
		var t = gs.conn_of_character(cid)
		if t and int(t.get("lonxon_host")) == int(h.rid):
			_send(t, msg)

func _send_board_to(h: Dictionary, c) -> void:
	if not h.is_empty():
		_send(c, _board_msg(h))

# ---------------------------------------------------------------- gửi tin

func _name(t) -> String:
	if t.entity:
		return t.entity.name
	return t.profile.display_name if t.profile else "?"

func _reject(c, text: String) -> void:
	_send(c, {"op": "reject", "msg": text})

func _send(c, msg: Dictionary) -> void:
	var b := NetProto.writer(NetProto.S_LONXON)
	NetProto.put_json(b, msg)
	gs.send(c, b)

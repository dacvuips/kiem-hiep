extends RefCounted
class_name FieldServer
## PHÒNG TRAIN CHUNG của màn Vượt Ải (GAME_FIELD=1): 1 tiến trình game server chứa NHIỀU PHÒNG, mỗi phòng = 1 bản riêng của 1 map
## luyện công (tab Thường) hoặc map Địa Ngục (tab Địa Ngục, 1-5 sao) với bầy quái riêng.
##   - Vào map lúc đã đăng nhập = TẠO PHÒNG: server cấp ID 6 số không trùng, người tạo là CHỦ PHÒNG. Người khác nhập ID ở màn Vượt Ải
##     -> game tra phòng qua GET /v1/field (biết map để nạp) -> vào đúng phòng đó (tối đa MAX_MEMBERS người).
##   - CHỦ PHÒNG RỜI (về Hub, mất kết nối, bị đá) = ĐÓNG PHÒNG: mọi người còn lại bị mời ra (mã "field_end"), quái / đồ rơi của phòng bị bỏ.
##   - Tách phòng: thực thể có room_id + cell_base (ServerEntity) — mỗi phòng 1 vùng ô AOI riêng nên người / quái phòng khác không bao
##     giờ nằm trong tầm nhìn của nhau; mọi kiểm tra "đứng gần" của server đi qua GameServer.near (so cả phòng); vật cản theo map của
##     phòng (GameServer.grid_of). Chưa vào phòng = đứng ở "sảnh" (map của tiến trình), không thấy ai (GameServer.can_see).
##   - Địa Ngục: quái cấp MapCatalog.hell_level(nhóm), máu ×sao (ServerMonster.hell_stars), rơi đồ DropTable.roll_hell; sát thương ×sao
##     tính ở máy người bị đánh (game đọc số sao trong GameManager.field_map).
## Danh sách phòng báo lên server tài khoản (POST /internal/game/field) mỗi REPORT_EVERY giây.
## NHIỀU TIẾN TRÌNH: chạy nhiều field server (mỗi cái 1 GAME_FIELD_INDEX 0-8, cổng riêng) — chữ số đầu của ID phòng = index + 1 nên ID không
## trùng giữa các tiến trình; server tài khoản gộp phòng của mọi tiến trình, chỉ tiến trình vắng nhất cho phòng mới.
##
## Tin game -> server: C_FIELD u8 op + str json; server -> game: S_FIELD str json {op: "room" | "reject", ...}.

const OP_CREATE := 1      ## {map_id, tier (0 = Thường, 10-12 = Địa Ngục), stars}
const OP_JOIN := 2        ## {room, map_id, tier}

const MAX_MEMBERS := 8
const REPORT_EVERY := 2.0
## Vùng ô AOI mỗi phòng chiếm (theo trục y): map lớn nhất cỡ vài chục ô 1024px — 4096 ô là dư.
const ROOM_CELLS := 4096

var gs   ## GameServer
var rooms := {}            ## id (chuỗi 6 số) -> phòng {id, rid, map_id, name, tier, stars, level, dir, grid, base, spawn, host, host_name,
                           ##   members: [character_id], monsters: [ServerMonster]}
var room_of := {}          ## character_id -> id phòng
var public_host := ""
var public_port := 0
var public_ws := ""
var _grids := {}           ## map_id -> MapGrid (chỉ đọc, dùng chung mọi phòng cùng map)
var _rooms_by_rid := {}    ## room_id (số) -> phòng
var _free_slots: Array[int] = []
var _next_slot := 1
var _entry := Vector2.ZERO
var _report_in := 0.0
var index := 0             ## GAME_FIELD_INDEX — chữ số đầu ID phòng = index + 1

func _init(server) -> void:
	gs = server
	public_host = gs._env("GAME_PUBLIC_HOST", "127.0.0.1")
	public_port = int(gs._env("GAME_ENET_PORT", "7807"))
	public_ws = gs._env("GAME_PUBLIC_WS", "ws://%s:%s" % [public_host, gs._env("GAME_WS_PORT", "7808")])
	index = clampi(int(gs._env("GAME_FIELD_INDEX", "0")), 0, 8)
	_entry = gs.grid.open_spawn_near(gs.grid.default_center())
	print("Phòng train chung #%d: %d map Thường, Địa Ngục %s, ID phòng %d00000-%d99999" % [index, MapCatalog.all().size(),
		str(MapCatalog.HELL_TIERS), index + 1, index + 1])

func entry_pos() -> Vector2:
	return _entry

func grid_of_room(rid: int) -> MapGrid:
	var r: Dictionary = _rooms_by_rid.get(rid, {})
	return r.get("grid", gs.grid)

# ---------------------------------------------------------------- tin từ game

func on_field(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 512))
	var args: Dictionary = parsed if parsed is Dictionary else {}
	if room_of.has(c.character_id):
		_reject(c, "Bạn đang ở trong 1 phòng.")
		return
	match op:
		OP_CREATE:
			_create(c, int(args.get("map_id", 0)), int(args.get("tier", 0)), int(args.get("stars", 1)))
		OP_JOIN:
			_join(c, str(args.get("room", "")).strip_edges(), int(args.get("map_id", 0)), int(args.get("tier", 0)))

## Map được phép: tab Thường = mọi map trong danh mục luyện công; Địa Ngục = map của nhóm đó (MapCatalog.HELL_MAPS). {} = không hợp lệ.
static func map_entry(map_id: int, tier: int) -> Dictionary:
	var maps: Array = MapCatalog.hell_maps(tier) if tier != 0 else MapCatalog.all()
	for m in maps:
		if int(m["id"]) == map_id:
			return m
	return {}

func _create(c, map_id: int, tier: int, stars: int) -> void:
	var m := map_entry(map_id, tier)
	if m.is_empty() or not MapCatalog.is_playable(m):
		_reject(c, "Bản đồ này không mở phòng được.")
		return
	var grid: MapGrid = _grids.get(map_id)
	if grid == null:
		grid = MapGrid.load_from(str(m["dir"]))
		if grid == null:
			_reject(c, "Máy chủ chưa có bản đồ này.")
			return
		_grids[map_id] = grid
	var id := _new_id()
	var slot: int = _free_slots.pop_back() if not _free_slots.is_empty() else _next_slot
	if slot == _next_slot:
		_next_slot += 1
	var hell := tier != 0
	var r := {"id": id, "rid": int(id), "map_id": map_id, "name": str(m["name"]), "tier": tier,
		"stars": clampi(stars, 1, MapCatalog.HELL_MAX_STARS) if hell else 0, "level": int(m["level"]), "dir": str(m["dir"]),
		"grid": grid, "slot": slot, "base": Vector2i(0, slot * ROOM_CELLS), "spawn": grid.open_spawn_near(grid.default_center()),
		"host": c.character_id, "host_name": c.entity.name, "members": [], "monsters": []}
	rooms[id] = r
	_rooms_by_rid[r.rid] = r
	_spawn_monsters(r)
	print("Mở phòng #%s: %s%s — chủ %s, %d quái" % [id, r.name, " Địa Ngục %d★" % r.stars if hell else "", r.host_name, r.monsters.size()])
	_enter(c, r)

func _join(c, id: String, map_id: int, tier: int) -> void:
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		_reject(c, "Không có phòng #%s (phòng đã đóng hoặc sai ID)." % id)
		return
	if int(r.map_id) != map_id or int(r.tier) != tier:
		_reject(c, "Phòng #%s đang ở bản đồ khác — hãy nhập lại ID." % id)
		return
	if (r.members as Array).size() >= MAX_MEMBERS:
		_reject(c, "Phòng #%s đã đủ %d người." % [id, MAX_MEMBERS])
		return
	_enter(c, r)

## ID 6 số chưa có phòng nào dùng; chữ số đầu = index + 1 (không trùng phòng của tiến trình field khác).
func _new_id() -> String:
	while true:
		var id := str((index + 1) * 100000 + randi_range(0, 99999))
		if not rooms.has(id):
			return id
	return ""

## Quái theo bãi của map phòng (như GameServer._spawn_monsters) — Địa Ngục: cấp của nhóm + số sao.
func _spawn_monsters(r: Dictionary) -> void:
	var grid: MapGrid = r.grid
	for n in grid.data.get("npcs", []):
		if str(n.get("role", "")) != "monster":
			continue
		var m := ServerMonster.from_entry(n, 0)
		if m == null:
			continue
		m.room_id = r.rid
		m.cell_base = r.base
		if int(r.tier) != 0:
			m.level = int(r.level)
			m.hell_stars = int(r.stars)
			m.apply_level_script()   ## chiêu / AI / máu theo cấp mới (script cấp gốc)
			m.reset()                ## đủ máu theo cấp mới + số sao
		gs.add_monster(m)
		r.monsters.append(m)

func _enter(c, r: Dictionary) -> void:
	room_of[c.character_id] = r.id
	r.members.append(c.character_id)
	c.entity.room_id = r.rid
	c.entity.cell_base = r.base
	c.view_cell = Vector2i(1 << 30, 1 << 30)   ## quét lại tầm nhìn ở lượt gửi tới
	gs.teleport(c, r.spawn)
	_send(c, _room_msg(r, "room"))
	_broadcast(r)

## Rời phòng (về Hub / mất kết nối / bị đá). Chủ phòng rời = đóng phòng.
func on_leave(c) -> void:
	var id: String = room_of.get(c.character_id, "")
	if id == "":
		return
	room_of.erase(c.character_id)
	var r: Dictionary = rooms.get(id, {})
	if r.is_empty():
		return
	r.members.erase(c.character_id)
	if c.entity:
		c.entity.room_id = 0
		c.entity.cell_base = Vector2i.ZERO
	if int(r.host) == c.character_id:
		_close(r, "Chủ phòng %s đã rời — phòng #%s đóng." % [r.host_name, id])
	else:
		_broadcast(r)

func _close(r: Dictionary, why: String) -> void:
	rooms.erase(r.id)
	_rooms_by_rid.erase(r.rid)
	for cid in (r.members as Array).duplicate():
		room_of.erase(cid)
		var m = gs.conn_of_character(cid)
		if m:
			gs.kick(m, "field_end", why)
	r.members.clear()
	for mon: ServerMonster in r.monsters:
		gs.remove_monster(mon)
	r.monsters.clear()
	gs.clear_room_drops(r.rid)
	_free_slots.append(int(r.slot))
	print("Đóng phòng #%s" % r.id)

## Chết bấm "Về thành dưỡng sức": về điểm xuất phát của map phòng.
func on_revive(c) -> bool:
	var r: Dictionary = rooms.get(room_of.get(c.character_id, ""), {})
	if r.is_empty():
		return false
	gs.teleport(c, r.spawn)
	return true

func tick(delta: float) -> void:
	_report_in -= delta
	if _report_in <= 0.0:
		_report_in = REPORT_EVERY
		_report()

# ---------------------------------------------------------------- gửi tin

func _room_msg(r: Dictionary, op: String) -> Dictionary:
	var names := []
	for cid in r.members:
		var m = gs.conn_of_character(cid)
		if m and m.entity:
			names.append(m.entity.name)
	return {"op": op, "id": r.id, "map_id": r.map_id, "name": r.name, "tier": r.tier, "stars": r.stars, "host": r.host_name,
		"members": names, "max": MAX_MEMBERS}

## Danh sách người trong phòng đổi: báo mọi người trong phòng.
func _broadcast(r: Dictionary) -> void:
	var msg := _room_msg(r, "state")
	for cid in r.members:
		var m = gs.conn_of_character(cid)
		if m:
			_send(m, msg)

func _reject(c, text: String) -> void:
	_send(c, {"op": "reject", "msg": text})

func _send(c, msg: Dictionary) -> void:
	var b := NetProto.writer(NetProto.S_FIELD)
	NetProto.put_str(b, JSON.stringify(msg))
	gs.send(c, b)

func _report() -> void:
	var list := []
	for id in rooms:
		var r: Dictionary = rooms[id]
		list.append({"id": id, "map_id": r.map_id, "tier": r.tier, "stars": r.stars, "host": r.host_name,
			"members": (r.members as Array).size(), "max": MAX_MEMBERS})
	gs.account.report_field({"server_id": gs.account.server_id, "index": index, "host": public_host, "port": public_port, "ws_url": public_ws,
		"open": true, "players": gs.online_count(), "rooms": list})

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
const OP_GUILD := 3       ## {guild, map_id}
const OP_BOSS := 4        ## {boss_id, map_id, boss_name}

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
		OP_GUILD:
			_guild_enter(c, str(args.get("guild", "")).strip_edges(), int(args.get("map_id", 987)))
		OP_BOSS:
			_boss_enter(c, int(args.get("boss_id", 0)), int(args.get("map_id", 0)), str(args.get("boss_name", "Boss Hoàng Kim")))

## Map được phép: tab Thường = mọi map trong danh mục luyện công; Địa Ngục = map của nhóm đó (MapCatalog.HELL_MAPS). {} = không hợp lệ.
static func map_entry(map_id: int, tier: int) -> Dictionary:
	if map_id in [987, 921, 922, 923, 924]:
		return {"id": map_id, "name": "Tổng Đà Bang Hội", "dir": "res://world/maps/map_%d" % map_id, "level": 1}
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
	var spawn_center: Vector2 = grid.default_center()
	if m.has("arena_center"):
		var ac = m["arena_center"]
		if ac is Vector2:
			spawn_center = ac
		elif ac is Array and (ac as Array).size() >= 2:
			spawn_center = Vector2(float(ac[0]), float(ac[1]))
	var r := {"id": id, "rid": int(id), "map_id": map_id, "name": str(m["name"]), "tier": tier,
		"stars": clampi(stars, 1, MapCatalog.HELL_MAX_STARS) if hell else 0, "level": int(m["level"]), "dir": str(m["dir"]),
		"grid": grid, "slot": slot, "base": Vector2i(0, slot * ROOM_CELLS), "spawn": grid.open_spawn_near(spawn_center),
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

## Vào hoặc mở Tổng Đà Bang Hội (mọi thành viên cùng bang vào chung 1 phòng).
func _guild_enter(c, guild_name: String, map_id: int) -> void:
	if guild_name == "":
		_reject(c, "Bạn chưa có bang hội.")
		return
	if map_id <= 0:
		map_id = 987
	for r in rooms.values():
		if str(r.get("guild", "")) == guild_name:
			_enter(c, r)
			return
	var m := map_entry(map_id, 0)
	if m.is_empty() or not MapCatalog.is_playable(m):
		_reject(c, "Bản đồ Tổng Đà chưa sẵn sàng trên máy chủ.")
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
	var spawn_center: Vector2 = grid.default_center()
	var r := {"id": id, "rid": int(id), "map_id": map_id, "name": "Tổng Đà Bang Hội - %s" % guild_name, "tier": 0,
		"stars": 0, "level": 1, "dir": str(m["dir"]), "grid": grid, "slot": slot, "base": Vector2i(0, slot * ROOM_CELLS),
		"spawn": grid.open_spawn_near(spawn_center), "host": c.character_id, "host_name": c.entity.name,
		"members": [], "monsters": [], "guild": guild_name, "max": 100}
	rooms[id] = r
	_rooms_by_rid[r.rid] = r
	print("Mở Tổng Đà Bang Hội #%s: %s — %s khởi tạo" % [id, guild_name, r.host_name])
	_enter(c, r)

## Vào hoặc mở phòng Săn Boss Hoàng Kim chung (tất cả người chơi săn cùng 1 Boss vào chung 1 phòng).
func _boss_enter(c, boss_id: int, map_id: int, boss_name: String) -> void:
	if boss_id <= 0 or map_id <= 0:
		_reject(c, "Thông tin Boss không hợp lệ.")
		return
	var room_key := "boss_%d" % boss_id
	for r in rooms.values():
		if str(r.get("boss_key", "")) == room_key:
			_enter(c, r)
			return
	var m := map_entry(map_id, 0)
	if m.is_empty() or not MapCatalog.is_playable(m):
		_reject(c, "Bản đồ Boss chưa sẵn sàng trên máy chủ.")
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
	var spawn_center: Vector2 = grid.default_center()
	var default_spawn: Vector2 = grid.open_spawn_near(spawn_center + Vector2(0, 320.0))
	if default_spawn == Vector2.ZERO:
		default_spawn = grid.open_spawn_near(spawn_center + Vector2(-1600.0, -1000.0))
		if default_spawn == Vector2.ZERO:
			default_spawn = grid.open_spawn_near(spawn_center)
	var r := {"id": id, "rid": int(id), "map_id": map_id, "name": "Săn Boss: %s" % boss_name, "tier": 0,
		"stars": 0, "level": 95, "dir": str(m["dir"]), "grid": grid, "slot": slot, "base": Vector2i(0, slot * ROOM_CELLS),
		"spawn": default_spawn, "host": c.character_id, "host_name": c.entity.name,
		"members": [], "monsters": [], "boss_key": room_key, "boss_id": boss_id, "boss_name": boss_name,
		"max": 100, "is_boss": true}
	rooms[id] = r
	_rooms_by_rid[r.rid] = r
	_spawn_monsters(r)
	_spawn_boss_monster(r, boss_id, spawn_center)
	print("Mở phòng Săn Boss #%s: %s (Boss ID %d, Map %d) — %s khởi tạo" % [id, boss_name, boss_id, map_id, r.host_name])
	_enter(c, r)

## Sinh Boss Hoàng Kim / Tiểu Hoàng Kim thật sự cho phòng săn Boss trên server
func _spawn_boss_monster(r: Dictionary, boss_id: int, spawn_center: Vector2) -> void:
	var grid: MapGrid = r.grid
	var boss_pos: Vector2 = grid.open_spawn_near(spawn_center)
	if boss_pos == Vector2.ZERO:
		boss_pos = spawn_center
	var mdata: Dictionary = MonsterData.monster(boss_id)
	var blv: int = int(mdata.get("level", 95))
	var btype: String = str(mdata.get("boss_type", "gold"))
	var boss_entry := {
		"t": boss_id,
		"lv": blv,
		"px": boss_pos.x,
		"py": boss_pos.y,
		"respawn": 1.0e9
	}
	var bm := ServerMonster.from_entry(boss_entry, 0)
	if bm != null:
		bm.room_id = r.rid
		bm.cell_base = r.base
		bm.level = blv
		bm.is_boss = true
		if btype == "small_gold":
			bm.gold_boss = false
			bm.small_gold_boss = true
		else:
			bm.gold_boss = true
			bm.small_gold_boss = false
		bm.apply_level_script()
		bm.reset()
		gs.add_monster(bm)
		r.monsters.append(bm)
		print("Sinh Boss %s (ID %d, Cấp %d, Loại %s) tại %s cho phòng #%s" % [bm.name, boss_id, blv, btype, boss_pos, r.id])

func allows_boss_pvp(a, b) -> bool:
	if a == null or b == null or a.entity == null or b.entity == null:
		return false
	var rid_a: int = a.entity.room_id
	var rid_b: int = b.entity.room_id
	if rid_a == 0 or rid_a != rid_b:
		return false
	var r: Dictionary = _rooms_by_rid.get(rid_a, {})
	return bool(r.get("is_boss", false))

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
	var ppos: Vector2 = r.spawn
	if bool(r.get("is_boss", false)):
		ppos = r.spawn + Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
	gs.teleport(c, ppos)
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
	if r.get("guild", "") != "" or bool(r.get("is_boss", false)):
		if (r.members as Array).is_empty():
			_close(r, "")
		else:
			_broadcast(r)
		return
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
		"members": names, "max": int(r.get("max", MAX_MEMBERS)), "guild": str(r.get("guild", "")),
		"boss_name": str(r.get("boss_name", "")), "is_boss": bool(r.get("is_boss", false))}

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

extends Node
## Kiểm thử LOGIC LonXonServer bằng GameServer GIẢ (không cần server tài khoản / mạng): xem host, giữ chỗ, vào host với hồ sơ tạm
## cấp 50, chọn thẻ 5x, hạ quái +5 cấp, PK tự do, chết rớt hết đồ + Lệnh Bài, nhặt Lệnh Bài, bảng Top 5, hồi sinh sau 5 giây, rời host.
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/lon_xon_server_logic_tests.tscn

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

class FakeConn:
	var character_id := 0
	var hub := true
	var is_gm := false
	var pubg_match := 0
	var lonxon_host := 0
	var profile: PlayerProfile
	var data: Dictionary = {}
	var dirty := false
	var entity: ServerEntity
	var view_cell := Vector2i.ZERO
	var msgs: Array = []
	var kicked := ""

	func last(op: String) -> Dictionary:
		for i in range(msgs.size() - 1, -1, -1):
			if str(msgs[i].get("op")) == op:
				return msgs[i]
		return {}

class FakeGs:
	var t := 0.0
	var conns := {}
	var monsters: Array = []
	var drops := {}
	var next_drop := 1

	func now() -> float:
		return t

	func conn_of_character(cid: int):
		return conns.get(cid)

	func send(c, b: StreamPeerBuffer) -> void:
		var r := NetProto.reader(b.data_array)
		if r.get_u8() == NetProto.S_LONXON:
			c.msgs.append(NetProto.get_json(r))

	func kick(c, code: String, _message: String) -> void:
		c.kicked = code

	func add_monster(m) -> void:
		monsters.append(m)

	func remove_monster(m) -> void:
		monsters.erase(m)

	func profile_changed(c) -> void:
		c.data = c.profile.to_dict()

	func teleport(c, p: Vector2) -> void:
		c.entity.pos = p

	func scatter_drops(where: ServerEntity, list: Array, _radius: float) -> Array:
		var ids: Array = []
		for entry in list:
			var d: Dictionary = {"pos": where.pos, "owner": 0, "room": where.room_id}
			for k in entry:
				d[k] = entry[k]
			drops[next_drop] = d
			ids.append(next_drop)
			next_drop += 1
		return ids

var gs: FakeGs
var lx: LonXonServer

func _ready() -> void:
	run()
	print("RESULT %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _conn(cid: int, name: String) -> FakeConn:
	var c := FakeConn.new()
	c.character_id = cid
	var p := PlayerProfile.new()
	p.display_name = name
	p.sect_id = "thieu_lam"
	p.level = 150
	p.gold = 123456
	p.add_item(ItemGenerator.generate_misc("1_0_0_1"))
	c.profile = p
	c.data = p.to_dict()
	gs.conns[cid] = c
	return c

## Hub giữ chỗ -> game vào map (HELLO_WORLD): như GameServer._on_hello.
func _enter(c: FakeConn, host: int) -> bool:
	c.hub = true
	lx.handle(c, LonXonServer.OP_JOIN, {"host": host})
	if c.last("match").is_empty():
		return false
	c.hub = false
	if not lx.on_hello(c):
		return false
	var e := ServerEntity.new()
	e.eid = 1000 + c.character_id
	e.name = c.profile.display_name
	c.entity = e
	lx.place(c)
	lx.on_entered(c)
	return true

func _token_drop_ids() -> Array:
	var out: Array = []
	for id in gs.drops:
		if str(gs.drops[id].get("item", {}).get("mid", "")) == LonXonRules.TOKEN_ITEM_ID:
			out.append(id)
	return out

func run() -> void:
	gs = FakeGs.new()
	lx = LonXonServer.new(gs)
	var a := _conn(1, "An")
	var b := _conn(2, "Bình")
	var c3 := _conn(3, "Cường")

	# --- Hub: xem host
	a.hub = true
	lx.handle(a, LonXonServer.OP_STATE, {})
	var hosts: Array = a.last("hosts").get("hosts", [])
	check("Có 5 host", hosts.size() == 5, hosts)
	check("Host trống, tối đa 50", hosts.size() == 5 and int(hosts[0].players) == 0 and int(hosts[0].cap) == 50)
	lx.handle(a, LonXonServer.OP_JOIN, {"host": 9})
	check("Host không tồn tại -> từ chối", not a.last("reject").is_empty())

	# --- Vào host 2
	check("An vào host 2", _enter(a, 2))
	var h := lx.host_by_index(2)
	check("Host 2 sinh quái trong khung", gs.monsters.size() > 0, gs.monsters.size())
	check("Hồ sơ tạm: cấp 50", a.profile.level == 50)
	check("Hồ sơ tạm: hết tiền / đồ thật", a.profile.equipment.is_empty() and a.profile.inventory.size() == 1 and a.profile.inventory[0].misc_id == "1_8_0_4")
	check("Hồ sơ tạm: không đánh dấu lưu", not a.dirty)
	check("Vào phòng của host", a.entity.room_id == int(h.rid) and a.entity.cell_base == h.base)
	check("Đứng trong khung host", (h.box as Rect2).has_point(a.entity.pos), a.entity.pos)
	check("Đã báo match + khung", a.last("match").get("box", []).size() == 4)
	lx.handle(a, LonXonServer.OP_STATE, {})
	check("Xem bảng trong host", not a.last("board").is_empty())
	a.hub = true
	lx.handle(a, LonXonServer.OP_STATE, {})
	a.hub = false
	check("Sảnh khác: đếm 1 người host 2", int(lx._hosts_msg().hosts[1].players) == 1)

	check("Bình vào host 2", _enter(b, 2))
	check("Cường vào host 3", _enter(c3, 3))

	# --- Chọn thẻ 5x
	lx.handle(a, LonXonServer.OP_DRAFT, {"horse": 2, "weapon": 0})
	var wpn: ItemInstance = a.profile.equipment.get(Equipment.Part.WEAPON)
	var hor: ItemInstance = a.profile.equipment.get(Equipment.Part.HORSE)
	check("Thẻ 5x: ngựa Tử Lưu + đang cưỡi", hor != null and str(hor.get_base().get("name", "")) == "Tử Lưu" and a.profile.riding)
	check("Thẻ 5x: kiếm cấp 5, cầm được", wpn != null and int(wpn.get_base().get("level", 0)) == 5 and Equipment.can_use(wpn, a.profile))
	lx.handle(a, LonXonServer.OP_DRAFT, {"horse": 5, "weapon": 3})
	check("Thẻ 5x: chỉ 1 lần mỗi lần sống", str(a.profile.equipment[Equipment.Part.HORSE].get_base().get("name", "")) == "Tử Lưu")

	# --- Hạ quái +5 cấp, rơi đồ theo cấp
	lx.on_monster_killed(a)
	check("Hạ quái: An cấp 55", a.profile.level == 55 and int(a.last("level").get("gained", 0)) == 5)
	check("Rơi đồ theo bảng Lộn Xộn (có Hồi Thiên)", lx.roll_drops(a).any(func(d): return (d.item as ItemInstance).misc_id == "1_8_0_4"))

	# --- PK tự do
	check("Cùng host: đánh được nhau", lx.allows_hit(a, b) and lx.allows_hit(b, a))
	check("Khác host: không đánh được", not lx.allows_hit(a, c3))
	check("Không tự đánh mình", not lx.allows_hit(a, a))

	# --- Bình chết lần đầu: rớt hết đồ + 1 Lệnh Bài
	lx.handle(b, LonXonServer.OP_DRAFT, {"horse": 1, "weapon": 1})
	var b_items := b.profile.inventory.size() + b.profile.equipment.size()
	lx.on_died(b, "An")
	var died := b.last("died")
	check("Bình chết: báo chờ 5 giây, người hạ là An", float(died.get("respawn_in", 0)) == 5.0 and str(died.get("killer", "")) == "An")
	check("Bình chết: hồ sơ trống", b.profile.inventory.is_empty() and b.profile.equipment.is_empty())
	check("Bình chết: rớt đủ %d món + 1 Lệnh Bài" % b_items, gs.drops.size() == b_items + 1 and int(died.get("tokens", 0)) == 1)
	var tok_ids := _token_drop_ids()
	check("Lệnh Bài dưới đất: 1 cái, khoá chủ 10 giây", tok_ids.size() == 1 and int(gs.drops[tok_ids[0]].item.count) == 1
		and int(gs.drops[tok_ids[0]].token_from) == 2)
	check("Đang chết: không bị đánh / không đánh", not lx.allows_hit(a, b) and not lx.allows_hit(b, a))

	# --- Nhặt Lệnh Bài
	check("Đồ thường: không phải việc của Lộn Xộn", lx.on_pickup(a, {"item": {"mid": "1_8_0_4"}}) == "")
	check("Người chết không nhặt được", lx.on_pickup(b, gs.drops[tok_ids[0]]) != "ok")
	check("An nhặt Lệnh Bài", lx.on_pickup(a, gs.drops[tok_ids[0]]) == "ok")
	gs.drops.erase(tok_ids[0])
	check("An: 1 Lệnh Bài = 1000 điểm", lx.tokens_of(1) == 1 and int(a.last("tokens").score) == 1000)
	check("Lệnh Bài không vào túi", not a.profile.inventory.any(func(it): return it.misc_id == LonXonRules.TOKEN_ITEM_ID))

	# --- Bảng Top 5 + số hạng
	lx.tick(1.0)
	var board := a.last("board")
	check("Bảng: An đứng đầu 1000 điểm", board.get("top", []).size() >= 1 and str(board.top[0].name) == "An" and int(board.top[0].score) == 1000)
	check("Bảng: người 0 điểm không vào top", board.top.size() == 1)
	check("Số hạng 1 trên đầu An", int(board.get("badges", {}).get(str(a.entity.eid), 0)) == 1)
	check("Bảng gửi số Lệnh Bài từng người (để vẽ to)", int(board.get("sizes", {}).get(str(a.entity.eid), 0)) == 1 and not board.sizes.has(str(b.entity.eid)))
	check("Host khác không nhận bảng host 2", c3.last("board").get("top", []).is_empty())

	# --- Hồi sinh
	lx.on_revive(b)
	check("Chưa đủ 5 giây: chưa hồi sinh", lx.dead_at.has(2))
	gs.t += 5.0
	b.entity.flags |= NetProto.FLAG_DEAD
	check("C_REVIVE được xử lý ở Lộn Xộn", lx.on_revive(b))
	check("Đủ 5 giây: hồi sinh, bỏ cờ chết", not lx.dead_at.has(2) and (b.entity.flags & NetProto.FLAG_DEAD) == 0)
	check("Hồi sinh trong khung host", (h.box as Rect2).has_point(b.entity.pos))
	check("Hồi sinh: được 10 bình", b.profile.inventory.size() == 1 and b.profile.inventory[0].count == 10)
	check("Hồi sinh: giữ cấp", b.profile.level == 50)
	check("Miễn sát thương 3 giây", not lx.allows_hit(a, b) and lx.allows_hit(b, a))
	gs.t += 3.0
	check("Hết miễn sát thương", lx.allows_hit(a, b))
	lx.handle(b, LonXonServer.OP_DRAFT, {"horse": 3, "weapon": 2})
	check("Hồi sinh: chọn lại thẻ 5x", b.profile.equipment.get(Equipment.Part.HORSE) != null)

	# --- An giữ 5 Lệnh Bài rồi chết: rớt 1 + 2 = 3, còn 3
	lx.hosts[h.rid].tokens[1] = 5
	gs.drops.clear()
	lx.on_died(a, "Bình")
	check("An chết giữ 5: rớt 3 Lệnh Bài", int(a.last("died").tokens) == 3 and int(gs.drops[_token_drop_ids()[0]].item.count) == 3)
	check("An còn 3 Lệnh Bài, cấp giữ nguyên 55", lx.tokens_of(1) == 3 and a.profile.level == 55)
	gs.t += 2.0
	check("An tự nhặt lại Lệnh Bài của mình trong 10 giây: không được", lx.on_pickup(a, gs.drops[_token_drop_ids()[0]]) != "ok")
	check("Bình nhặt 3 Lệnh Bài", lx.on_pickup(b, gs.drops[_token_drop_ids()[0]]) == "ok" and lx.tokens_of(2) == 3)

	# --- Rời host: đồ + Lệnh Bài rớt, bỏ chỗ
	gs.drops.clear()
	lx.handle(b, LonXonServer.OP_QUIT, {})
	check("Bình rời: bị mời ra", b.kicked == "lonxon_end" and b.lonxon_host == 0)
	check("Bình rời: Lệnh Bài rớt (1 + 1)", _token_drop_ids().size() == 1 and int(gs.drops[_token_drop_ids()[0]].item.count) == 2)
	check("Bình rời: bỏ chỗ trong host", not h.members.has(2) and not lx.host_of.has(2))

	# --- Giữ chỗ mà không vào kịp
	var d := _conn(4, "Dũng")
	d.hub = true
	lx.handle(d, LonXonServer.OP_JOIN, {"host": 1})
	check("Dũng giữ chỗ host 1", lx.host_by_index(1).members.has(4))
	gs.t += LonXonServer.JOIN_TIMEOUT + 1.0
	lx.tick(1.0)
	check("Không vào kịp 90 giây: bỏ chỗ", not lx.host_by_index(1).members.has(4))

	# --- Host đầy
	var full := lx.host_by_index(5)
	for i in LonXonRules.HOST_CAPACITY:
		full.members[100 + i] = true
	var e := _conn(5, "Em")
	e.hub = true
	lx.handle(e, LonXonServer.OP_JOIN, {"host": 5})
	check("Host đầy 50 người: từ chối", not e.last("reject").is_empty() and not full.members.has(5))

extends Node
## Kiểm thử LOGIC PubgServer (đội chờ, ghép trận, tự ghép đội, vào trận với hồ sơ tạm, chọn thẻ, loại, xếp hạng, đóng trận) bằng
## GameServer GIẢ — không cần server tài khoản / mạng. Bài test với bot thật qua mạng: tests/pubg_online_tests.gd.

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

## Kết nối giả: đủ trường PubgServer / GameServer dùng.
class FakeConn:
	var character_id := 0
	var hub := true
	var is_gm := false
	var muted_until := 0.0
	var pubg_match := 0
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

## GameServer giả: thời gian tự chỉnh, gửi tin = ghi vào FakeConn.msgs.
class FakeGs:
	var t := 0.0
	var conns := {}
	var monsters: Array = []
	var env := {"PUBG_ALWAYS_OPEN": "1", "PUBG_MIN_SQUADS": "2", "PUBG_SEARCH_SEC": "5"}

	func _env(k: String, def: String) -> String:
		return str(env.get(k, def))

	func now() -> float:
		return t

	func conn_of_character(cid: int):
		return conns.get(cid)

	func send(c, b: StreamPeerBuffer) -> void:
		var r := NetProto.reader(b.data_array)
		if r.get_u8() == NetProto.S_PUBG:
			c.msgs.append(NetProto.get_json(r))

	func kick(c, code: String, _message: String) -> void:
		c.kicked = code

	func add_monster(m) -> void:
		monsters.append(m)

	func remove_monster(m) -> void:
		monsters.erase(m)

	func clear_room_drops(_rid: int) -> void:
		pass

	func profile_changed(c) -> void:
		c.data = c.profile.to_dict()

func _ready() -> void:
	run()
	print("RESULT %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(1 if _fail > 0 else 0)

var gs: FakeGs
var ps: PubgServer

func conn(cid: int, name: String) -> FakeConn:
	var c := FakeConn.new()
	c.character_id = cid
	var p := PlayerProfile.new()
	p.display_name = name
	p.level = 35
	var potion := ItemGenerator.generate_misc("1_8_0_4", 0, 0, 1)
	p.add_item(potion)
	c.profile = p
	c.data = p.to_dict()
	var e := ServerEntity.new()
	e.eid = cid + 1000
	e.name = name
	c.entity = e
	gs.conns[cid] = c
	return c

func op(c: FakeConn, code: int, args := {}) -> void:
	var b := NetProto.writer(NetProto.C_PUBG)
	b.put_u8(code)
	NetProto.put_str(b, JSON.stringify(args))
	var r := NetProto.reader(b.data_array)
	r.get_u8()
	ps.on_pubg(c, r)

func tick(sec: float) -> void:
	var steps := int(ceil(sec))
	for i in steps:
		gs.t += 1.0
		ps.tick(1.0)

func run() -> void:
	gs = FakeGs.new()
	ps = PubgServer.new(gs)
	var a := conn(1, "An")
	var b := conn(2, "Binh")
	var c := conn(3, "Cuong")
	var d := conn(4, "Dung")
	var e := conn(5, "Em")

	## Đội chờ
	op(a, PubgServer.OP_CREATE, {"mode": 2})
	var code := str(a.last("room").room.id)
	check("Tạo đội Duo có mã", code.begins_with("PUBG-"), code)
	op(b, PubgServer.OP_JOIN, {"code": code.replace("PUBG-", "")})
	check("Vào đội bằng số mã", (b.last("room").room.members as Array).size() == 2)
	op(e, PubgServer.OP_JOIN, {"code": code})
	check("Đội đủ người -> từ chối", str(e.last("reject").get("code")) == "full")
	op(a, PubgServer.OP_PASSWORD, {"password": "123"})
	op(b, PubgServer.OP_LEAVE)
	op(e, PubgServer.OP_JOIN, {"code": code})
	check("Đội có mật khẩu: sai -> từ chối", str(e.last("reject").get("code")) == "password")
	op(e, PubgServer.OP_JOIN, {"code": code, "password": "123"})
	check("Đúng mật khẩu -> vào được", (e.last("room").room.members as Array).size() == 2)
	op(a, PubgServer.OP_KICK, {"cid": 5})
	check("Chủ đội mời ra", e.last("none") != {} and (a.last("room").room.members as Array).size() == 1)
	op(a, PubgServer.OP_PASSWORD, {"password": ""})
	op(b, PubgServer.OP_JOIN, {"code": code})
	op(a, PubgServer.OP_SEARCH)
	check("Chưa sẵn sàng -> không tìm trận", a.last("reject") != {} and not bool(a.last("room").room.searching))
	op(a, PubgServer.OP_READY, {"ready": true})
	op(b, PubgServer.OP_READY, {"ready": true})
	var chat_before := b.msgs.size()
	op(a, PubgServer.OP_CHAT, {"text": "hello"})
	check("Chat tới đồng đội", b.msgs.size() > chat_before and str(b.last("chat").line.text) == "hello")
	op(a, PubgServer.OP_SEARCH)
	check("Đủ sẵn sàng -> đang tìm trận", bool(a.last("room").room.searching))

	## Chỉ 1 đội: chờ quá hạn vẫn chưa mở trận (cần >= 2 đội)
	tick(8)
	check("1 đội chờ quá hạn: chưa mở trận", a.last("match").is_empty() and ps.matches.is_empty())
	check("Đang tìm: báo số người", int(a.last("searching").get("found", 0)) == 2)

	## Đội thứ 2: 2 người lẻ bật tự ghép -> gộp thành 1 đội
	op(c, PubgServer.OP_CREATE, {"mode": 2, "fill": true})
	op(c, PubgServer.OP_READY, {"ready": true})
	op(d, PubgServer.OP_CREATE, {"mode": 2, "fill": true})
	op(d, PubgServer.OP_READY, {"ready": true})
	op(c, PubgServer.OP_SEARCH)
	op(d, PubgServer.OP_SEARCH)
	tick(1)
	check("Có trận: 2 đội (A+B, C+D tự ghép)", ps.matches.size() == 1 and not a.last("match").is_empty() and not d.last("match").is_empty())
	var m: Dictionary = ps.matches.values()[0] if not ps.matches.is_empty() else {}
	check("Tự ghép: C và D chung 1 đội", not m.is_empty() and m.squads.size() == 2 and ps._squad_of(m, 3) == ps._squad_of(m, 4))
	check("Quái trong trận chỉ trong khung chơi", gs.monsters.size() > 0 and gs.monsters.all(func(x) -> bool: return (m.box as Rect2).has_point(x.pos)),
		gs.monsters.size())
	check("Đội chờ đã đóng khi vào trận", ps.rooms.is_empty() and ps.room_of.is_empty())

	## Vào trận (kết nối thường)
	for x in [a, b, c, d]:
		x.hub = false
		var ok := ps.on_hello(x)
		ps.place(x)
		ps.on_entered(x)
		check("%s vào trận: hồ sơ tạm cấp 200, tay trắng" % x.profile.display_name, ok and x.pubg_match == m.rid and x.profile.level == 200 \
			and x.profile.inventory.size() == 1 and x.profile.inventory[0].count == 50 and x.entity.room_id == m.rid \
			and (m.box as Rect2).grow(64).has_point(x.entity.pos))
	check("Khác đội đánh được nhau", ps.allows_hit(a, c))
	check("Cùng đội không đánh được nhau", not ps.allows_hit(a, b))
	var stranger := conn(9, "NgoaiTran")
	stranger.hub = false
	check("Người ngoài trận không vào được trận", not ps.on_hello(stranger) and stranger.pubg_match == 0)

	## Chọn thẻ
	op(a, PubgServer.OP_DRAFT, {"horse": 3, "weapon": 0, "build": {"str": 200, "vit": 100}})
	check("Chọn thẻ: ngựa + vũ khí do server sinh", a.profile.equipment.has(Equipment.Part.HORSE) and a.profile.equipment.has(Equipment.Part.WEAPON))
	check("Chọn thẻ: cộng 300 điểm tiềm năng", a.profile.potential_points == 695)
	op(a, PubgServer.OP_DRAFT, {"horse": 1, "weapon": 1, "build": {"str": 600}})
	check("Chọn thẻ chỉ 1 lần", a.profile.potential_points == 695)
	op(b, PubgServer.OP_DRAFT, {"build": {"str": 5000}})
	check("Build vượt số điểm -> không cộng", b.profile.potential_points == 995)

	## Loại / xếp hạng
	ps.on_died(b)
	check("B bị loại, đội A còn người", not bool(b.last("eliminated").squad_out) and m.state == "playing")
	check("Bị loại thì không hồi sinh", ps.on_revive(b))
	ps.on_died(a)
	check("A bị loại -> đội A hạng 2", int(a.last("eliminated").rank) == 2)
	check("Đội C thắng, trận kết thúc", bool(c.last("result").win) and m.state == "ended")
	check("A nhận kết quả hạng 2", int(a.last("result").rank) == 2 and not bool(a.last("result").win))
	tick(PubgServer.END_SEC + 1)
	check("Hết giờ chờ -> đóng trận, mời rời (pubg_end)", ps.matches.is_empty() and c.kicked == "pubg_end" and gs.monsters.is_empty())
	check("Hết trận: không còn ai bị gắn trận", ps.match_of.is_empty())

	## Rời trận giữa chừng = bị loại; không vào trận kịp = bị loại
	for x in [a, b, c, d]:
		x.pubg_match = 0
		x.hub = true
		x.kicked = ""
		x.msgs.clear()
	op(a, PubgServer.OP_CREATE, {"mode": 1})
	op(c, PubgServer.OP_CREATE, {"mode": 1})
	tick(6)
	check("Solo: 2 người -> mở trận sau thời gian tìm", ps.matches.size() == 1)
	var m2: Dictionary = ps.matches.values()[0] if not ps.matches.is_empty() else {}
	a.hub = false
	ps.on_hello(a)
	ps.place(a)
	tick(PubgServer.JOIN_TIMEOUT + 1)
	check("Không vào trận kịp -> bị loại, người còn lại thắng", not m2.is_empty() and m2.state == "ended" and bool(a.last("result").get("win", false)))
	tick(PubgServer.END_SEC + 1)
	check("Trận solo đóng", ps.matches.is_empty())

	## Giờ mở (máy chủ chạy UTC vẫn tính theo giờ Việt Nam)
	gs.env["PUBG_ALWAYS_OPEN"] = "0"
	var ps2 := PubgServer.new(gs)
	check("Giờ mở tính theo UTC+7", ps2.tz_offset_sec == 7 * 3600)
	e.msgs.clear()
	var open_now := PubgManager.is_open_at(ps2.now_sec_of_day())
	var b2 := NetProto.writer(NetProto.C_PUBG)
	b2.put_u8(PubgServer.OP_CREATE)
	NetProto.put_str(b2, JSON.stringify({"mode": 1}))
	var r2 := NetProto.reader(b2.data_array)
	r2.get_u8()
	ps2.on_pubg(e, r2)
	check("Ngoài giờ mở -> từ chối tạo đội (trong giờ -> cho)", (e.last("reject") != {}) != open_now, [open_now, e.msgs])

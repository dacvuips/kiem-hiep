extends Node
## Kiểm thử game server (B1) với bot thật qua ENet. Cần chạy sẵn:
##   cd server && docker compose up -d                 (server tài khoản)
##   GODOT=... bash server/run_game_server.sh          (game server)
## rồi: godot --headless --path . res://tests/net_tests.tscn
## In PASS/FAIL từng ca, cuối cùng "RESULT x/y", thoát mã 1 nếu có ca hỏng.

const API := "http://127.0.0.1:8080"
const HOST := "127.0.0.1"
const PORT := 7777

var _pass := 0
var _fail := 0
var _bots: Array[BotClient] = []

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func _process(_d: float) -> void:
	for b in _bots:
		b.poll()

func _ready() -> void:
	await run()
	for b in _bots:
		b.close()
	print("RESULT %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(1 if _fail > 0 else 0)

## Chờ tới khi cond() đúng hoặc hết giờ.
func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()

func bot(token: String, character_id: int) -> BotClient:
	var b := BotClient.new()
	b.start(HOST, PORT, token, character_id)
	_bots.append(b)
	return b

## Tạo tài khoản + nhân vật qua API thật, trả [access_token, character_id].
func make_player(tag: String) -> Array:
	var user := "n%s%d" % [tag, Time.get_unix_time_from_system() as int % 10000000]
	var r := await http("POST", "/v1/auth/register", {"username": user, "email": user + "@example.com", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	var p := PlayerProfile.new()
	p.set_sect(SectRegistry.get_by_element(ElementTypes.ElementType.KIM)[0])
	var c := await http("POST", "/v1/characters", {"server_id": 1, "slot": 0, "name": "Bot " + user.substr(1), "data": p.to_dict()}, token)
	return [token, int(c.get("id", 0))]

func http(method: String, path: String, body: Dictionary, token := "") -> Dictionary:
	var h := HTTPRequest.new()
	add_child(h)
	var headers := ["Content-Type: application/json"]
	if token != "":
		headers.append("Authorization: Bearer " + token)
	if method == "GET":
		h.request(API + path, headers, HTTPClient.METHOD_GET)
	else:
		h.request(API + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	var res: Array = await h.request_completed
	h.queue_free()
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return d if d is Dictionary else {}

## B2: quái do server điều khiển.
func test_monsters(p: BotClient) -> void:
	## Đi tới gần 1 bãi quái (dịch chuyển dần, đúng tốc độ) để chắc chắn thấy quái.
	check("thấy quái của server", await wait_until(func() -> bool: return p.nearest_monster() != 0, 3.0) or await _walk_to_monsters(p),
		p.known.size())
	var m := p.nearest_monster()
	if m == 0:
		return
	var mpos: Vector2 = p.known[m].pos
	## Đứng sát quái -> quái chủ động ra chiêu (quái VLTK thường chủ động trong tầm nhìn).
	await _walk(p, mpos + Vector2(40, 0))
	var aggro := await wait_until(func() -> bool: return not p.attacked_by.is_empty(), 8.0)
	## Quái gần nhất có thể là loại không chủ động: thử thêm vài con khác.
	var tried := {m: true}
	for extra in 3:
		if aggro:
			break
		var other := 0
		var best := INF
		for id in p.known:
			if int(p.known[id].kind) == NetProto.KIND_MONSTER and not tried.has(id):
				var dd := (p.known[id].pos as Vector2).distance_to(p.feet)
				if dd < best:
					best = dd
					other = id
		if other == 0:
			break
		tried[other] = true
		await _walk(p, (p.known[other].pos as Vector2) + Vector2(40, 0))
		aggro = await wait_until(func() -> bool: return not p.attacked_by.is_empty(), 8.0)
	check("quái ra chiêu vào người đứng gần", aggro, p.attacked_by)
	## Sát thương từ quá xa không tính.
	var hp_before := int(p.known[m].get("hp", 100))
	p.move_to(p.feet)
	## Đánh tới chết (trần mỗi đòn theo cấp: 2000).
	for i in 60:
		if not p.known.has(m) or int(p.known[m].get("hp", 100)) == 0:
			break
		p.damage(m, 1999)
		await get_tree().create_timer(0.08).timeout
	check("quái mất máu theo sát thương", hp_before == 100, hp_before)
	check("nhận thưởng khi hạ quái (S_KILL)", await wait_until(func() -> bool:
		return p.kills.any(func(k: Dictionary) -> bool: return int(k.eid) == m), 5.0), p.kills)
	check("xác quái biến mất sau vài giây", await wait_until(func() -> bool: return not p.known.has(m), 6.0))
	check("server cộng kinh nghiệm khi hạ quái (S_PROGRESS)", p.exp_gained > 0, p.exp_gained)

## C1: đồ rơi do server, nhặt qua server, gian lận đồ / tiền không được lưu. Đóng kết nối p ở cuối.
func test_items(p: BotClient, info: Array) -> void:
	check("vào map nhận bản nhân vật chuẩn (S_PROFILE)", not p.profile.is_empty(), p.profile.keys().size())
	## Hạ quái tới khi có đồ rơi (bảng rớt có thể không ra gì mỗi lần).
	for round in 15:
		if not p.drops.is_empty():
			break
		var m := p.nearest_monster()
		if m == 0:
			await _walk_to_monsters(p)
			m = p.nearest_monster()
			if m == 0:
				break
		await _walk(p, (p.known[m].pos as Vector2) + Vector2(30, 0))
		for i in 80:
			if not p.known.has(m) or int(p.known[m].get("hp", 100)) == 0:
				break
			p.damage(m, 100000)
			await get_tree().create_timer(0.06).timeout
		await wait_until(func() -> bool: return not p.drops.is_empty(), 1.5)
	check("server rớt đồ khi hạ quái (S_DROPS)", not p.drops.is_empty(), p.drops.size())
	var gold_got := 0
	var items_got: Array = []
	for id in p.drops.keys():
		var d: Dictionary = p.drops[id]
		await _walk(p, d.pos)
		if (d.pos as Vector2).distance_to(p.feet) > 140.0:
			continue   ## đồ rơi sau vật cản: bỏ qua
		p.pickup(id)
		await wait_until(func() -> bool: return p.picked.any(func(x: Dictionary) -> bool: return int(x.id) == id), 2.0)
	for x in p.picked:
		if x.has("amount"):
			gold_got += int(x.amount)
		else:
			items_got.append(str(x.item.get("uid", "")))
	check("nhặt được đồ / tiền qua server (S_PICKED)", not p.picked.is_empty(), p.notices)
	## Gian lận: thêm món tự chế + tăng tiền. Gửi bản KHÔNG có món vừa nhặt (giả lập gói đến trước S_PICKED, ack cũ).
	var fake := p.profile.duplicate(true)
	fake["gold"] = 999999
	var inv: Array = fake.get("inventory", [])
	inv.append({"base": 1, "gold": -1, "series": 0, "uid": "deadbeefdeadbeef", "magic": [], "base_values": []})
	fake["inventory"] = inv
	var real_ack := p.grant_ack
	p.grant_ack = 0
	p.send_profile(fake)
	p.grant_ack = real_ack
	await get_tree().create_timer(0.6).timeout
	p.close()
	await get_tree().create_timer(1.5).timeout
	var row := await _character(info)
	var saved_uids := []
	for it in row.data.get("inventory", []):
		saved_uids.append(str(it.get("uid", "")))
	check("món tự chế không được lưu", not saved_uids.has("deadbeefdeadbeef"), saved_uids)
	check("tiền gian lận không được lưu", int(row.data.gold) < 999999, row.data.gold)
	check("tiền nhặt được vẫn còn (dù gói gửi trước S_PICKED)", int(row.data.gold) == int(p.profile.get("gold", 0)) + gold_got, [row.data.gold, gold_got])
	check("đồ nhặt được vẫn còn", items_got.all(func(u: String) -> bool: return saved_uids.has(u)), [items_got, saved_uids])

## C2: giao dịch + bày bán giữa 2 người thật, đồ / tiền đổi chủ ở server; lưu HTTP ngoài map không tăng được tiền.
func test_trade_and_stall() -> void:
	var xi := await make_player("x")
	var yi := await make_player("y")
	var x := bot(xi[0], xi[1])
	var y := bot(yi[0], yi[1])
	if not await wait_until(func() -> bool: return x.in_world and y.in_world and not x.profile.is_empty()):
		check("C2: 2 bot vào map", false)
		return
	check("C2: nhân vật mới được server khởi tạo (server_seen, không tiền)", int(x.profile.get("server_seen", 0)) == 1 and int(x.profile.get("gold", -1)) == 0, x.profile.get("gold"))
	## X kiếm 1 món + tiền (chế độ test: đồ rơi ngay dưới chân người hạ quái)
	var m := x.nearest_monster()
	if m == 0:
		await _walk_to_monsters(x)
		m = x.nearest_monster()
	await _walk(x, (x.known[m].pos as Vector2) + Vector2(30, 0))
	for i in 80:
		if not x.known.has(m) or int(x.known[m].get("hp", 100)) == 0:
			break
		x.damage(m, 100000)
		await get_tree().create_timer(0.06).timeout
	await wait_until(func() -> bool: return x.drops.size() >= 2, 3.0)
	for id in x.drops.keys():
		x.pickup(id)
	await wait_until(func() -> bool: return x.picked.size() >= 2, 3.0)
	var item_uid := ""
	for p in x.picked:
		if p.has("item"):
			item_uid = str(p.item.get("uid", ""))
	check("C2: X có món đồ để giao dịch", item_uid != "", x.picked)
	if item_uid == "":
		return
	## Y đi tới cạnh X, mở giao dịch; X xin giao dịch.
	await _walk(y, x.feet + Vector2(40, 0))
	y.stall_op(SocialServer.TRADE_OPEN)
	await get_tree().create_timer(0.3).timeout
	x.trade_request(y.eid)
	check("C2: Y nhận lời mời giao dịch", await wait_until(func() -> bool: return not y.trade_invites.is_empty(), 3.0), x.notices)
	y.trade_answer(x.eid, true)
	check("C2: phòng giao dịch mở cho cả 2", await wait_until(func() -> bool: return not x.trade.is_empty() and not y.trade.is_empty(), 3.0))
	x.trade_op(SocialServer.OP_OFFER, item_uid)
	check("C2: Y thấy món X bỏ vào", await wait_until(func() -> bool: return y.trade.get("theirs", {}).get("uids", []).has(item_uid), 3.0), y.trade)
	x.trade_op(SocialServer.OP_LOCK)
	y.trade_op(SocialServer.OP_LOCK)
	await wait_until(func() -> bool: return x.trade.get("theirs", {}).get("locked", false), 3.0)
	x.trade_op(SocialServer.OP_CONFIRM)
	await get_tree().create_timer(0.3).timeout
	y.trade_op(SocialServer.OP_CONFIRM)   ## bên bấm sau phải chờ 5 giây
	await get_tree().create_timer(0.5).timeout
	check("C2: bấm Đồng ý quá sớm bị nhắc chờ", y.notices.any(func(n: String) -> bool: return n.contains("đợi")), y.notices)
	await get_tree().create_timer(5.0).timeout
	y.trade_op(SocialServer.OP_CONFIRM)
	check("C2: giao dịch thành công", await wait_until(func() -> bool: return not y.trade_ended.is_empty() and y.trade_ended[-1].ok, 3.0), y.trade_ended)
	check("C2: món đồ sang tay Y", await wait_until(func() -> bool: return y.inventory_uids().has(item_uid) and not x.inventory_uids().has(item_uid), 3.0))
	## Bày bán: Y đặt giá 5 rồi mở quầy, X mua lại.
	var py := y.profile.duplicate(true)
	for it in py.inventory:
		if str(it.uid) == item_uid:
			it["price"] = 5
	y.send_profile(py)
	await get_tree().create_timer(0.6).timeout
	y.stall_op(SocialServer.STALL_OPEN, "Hàng tốt giá rẻ")
	await get_tree().create_timer(0.4).timeout
	x.stall_op(SocialServer.STALL_BROWSE, "", y.eid)
	check("C2: X xem quầy thấy món có giá", await wait_until(func() -> bool:
		return x.stall.get("items", []).any(func(d: Dictionary) -> bool: return str(d.uid) == item_uid and int(d.price) == 5), 3.0), [x.stall, y.notices])
	var x_gold := int(x.profile.get("gold", 0))
	x.stall_op(SocialServer.STALL_BUY, "", y.eid, item_uid)
	check("C2: mua ở quầy: đồ về X, tiền sang Y", await wait_until(func() -> bool:
		return x.inventory_uids().has(item_uid) and int(x.profile.gold) == x_gold - 5 and int(y.profile.gold) == 5, 3.0),
		[x.notices, y.notices, x.profile.get("gold"), y.profile.get("gold")])
	x.close()
	y.close()
	await get_tree().create_timer(1.5).timeout
	var rx := await _character(xi)
	var ry := await _character(yi)
	var saved_x := []
	for it in rx.data.get("inventory", []):
		saved_x.append(str(it.uid))
	check("C2: kết quả được lưu", saved_x.has(item_uid) and int(ry.data.gold) == 5, [saved_x, ry.data.gold])
	## Lưu HTTP từ Hub (ngoài map) không tăng được tiền / đồ.
	var cheat: Dictionary = ry.data.duplicate(true)
	cheat["gold"] = 999999
	(cheat.inventory as Array).append({"uid": "cafebabecafebabe", "base": 1})
	await http_put("/v1/characters/%d" % int(yi[1]), {"version": int(ry.version), "data": cheat}, yi[0])
	var ry2 := await _character(yi)
	var uids2 := []
	for it in ry2.data.get("inventory", []):
		uids2.append(str(it.uid))
	check("C2: lưu HTTP ngoài map không tăng được tiền", int(ry2.data.gold) == 5, ry2.data.gold)
	check("C2: lưu HTTP ngoài map không thêm được đồ lạ", not uids2.has("cafebabecafebabe"), uids2)

## C3: tổ đội thật — lập đội, mời, xin vào, chia kinh nghiệm, luật nhặt đồ, rời / giải tán.
func test_team() -> void:
	var pi := await make_player("p")
	var qi := await make_player("q")
	var ri := await make_player("r")
	var p := bot(pi[0], pi[1])
	var q := bot(qi[0], qi[1])
	var r := bot(ri[0], ri[1])
	if not await wait_until(func() -> bool: return p.in_world and q.in_world and r.in_world):
		check("C3: 3 bot vào map", false)
		return
	p.team_op(SocialServer.TEAM_CREATE)
	check("C3: lập đội", await wait_until(func() -> bool: return p.team.get("in_team", false) and int(p.team.captain) == p.eid, 3.0), p.notices)
	p.team_op(SocialServer.TEAM_INVITE, q.eid)
	check("C3: Q nhận lời mời", await wait_until(func() -> bool: return q.team_invites.has(p.eid), 3.0), p.notices)
	q.team_op(SocialServer.TEAM_ANSWER, p.eid, 1)
	check("C3: Q vào đội", await wait_until(func() -> bool: return q.team.get("members", []).size() == 2 and p.team.members.size() == 2, 3.0))
	r.team_op(SocialServer.TEAM_APPLY, p.eid)
	check("C3: đội trưởng thấy R xin vào", await wait_until(func() -> bool: return p.team.get("applicants", []).has(r.eid), 3.0), r.notices)
	p.team_op(SocialServer.TEAM_ACCEPT, r.eid)
	check("C3: R vào đội (3 người)", await wait_until(func() -> bool: return r.team.get("members", []).size() == 3, 3.0), p.notices)
	## Cả đội đứng gần quái, P hạ quái -> Q, R cũng nhận kinh nghiệm.
	var m := p.nearest_monster()
	if m == 0:
		await _walk_to_monsters(p)
		m = p.nearest_monster()
	var spot: Vector2 = (p.known[m].pos as Vector2) + Vector2(30, 0)
	await _walk(p, spot)
	await _walk(q, spot + Vector2(0, 20))
	await _walk(r, spot + Vector2(0, -20))
	var q_exp := q.exp_gained
	var r_exp := r.exp_gained
	for i in 80:
		if not p.known.has(m) or int(p.known[m].get("hp", 100)) == 0:
			break
		p.damage(m, 100000)
		await get_tree().create_timer(0.06).timeout
	check("C3: đồng đội trong tầm được chia kinh nghiệm", await wait_until(func() -> bool: return q.exp_gained > q_exp and r.exp_gained > r_exp, 3.0),
		[q.exp_gained, r.exp_gained])
	## Luật nhặt "đội trưởng nhặt": Q không nhặt được đồ rơi của P.
	p.team_op(SocialServer.TEAM_PICK, 0, TeamService.Pick.CAPTAIN)
	await wait_until(func() -> bool: return int(q.team.get("pick", -1)) == TeamService.Pick.CAPTAIN, 2.0)
	await wait_until(func() -> bool: return not q.drops.is_empty(), 2.0)
	var did := -1
	for id in q.drops:
		if int(q.drops[id].owner) == p.eid:
			did = id
	if did >= 0:
		q.pickup(did)
		check("C3: luật đội trưởng nhặt chặn Q", await wait_until(func() -> bool:
			return q.notices.any(func(n: String) -> bool: return n.contains("lượt")), 2.0), q.notices)
	## Q rời đội: đội còn 2; P (đội trưởng) rời: giải tán.
	q.team_op(SocialServer.TEAM_LEAVE)
	check("C3: thành viên rời, đội còn lại", await wait_until(func() -> bool: return not q.team.get("in_team", true) and p.team.members.size() == 2, 3.0))
	p.team_op(SocialServer.TEAM_LEAVE)
	check("C3: đội trưởng rời = giải tán", await wait_until(func() -> bool: return not r.team.get("in_team", true), 3.0))
	for x in [p, q, r]:
		x.close()

## C4a: chat — kênh gần, nhắn riêng, giới hạn kênh thế giới.
func test_chat() -> void:
	var ui := await make_player("u")
	var vi := await make_player("v")
	var u := bot(ui[0], ui[1])
	var v := bot(vi[0], vi[1])
	if not await wait_until(func() -> bool: return u.in_world and v.in_world):
		check("C4: 2 bot vào map", false)
		return
	await get_tree().create_timer(0.5).timeout
	u.say(ChatServer.NEAR, "xin chào cả nhà")
	check("C4: kênh gần tới người đứng cạnh", await wait_until(func() -> bool: return v.heard("xin chào cả nhà"), 3.0), v.chats)
	await get_tree().create_timer(1.0).timeout
	u.say(ChatServer.PRIVATE, "nhắn riêng nè", v.name)
	check("C4: nhắn riêng theo tên", await wait_until(func() -> bool: return v.heard("nhắn riêng nè") and u.heard("nhắn riêng nè"), 3.0), v.chats)
	await get_tree().create_timer(1.0).timeout
	u.say(ChatServer.PRIVATE, "ai đó", "Không Có Ai Tên Này")
	check("C4: nhắn riêng người không online", await wait_until(func() -> bool:
		return u.notices.any(func(n: String) -> bool: return n.contains("không online")), 3.0), u.notices)
	await get_tree().create_timer(1.0).timeout
	u.say(ChatServer.WORLD, "rao bán đồ 1")
	await get_tree().create_timer(1.0).timeout
	u.say(ChatServer.WORLD, "rao bán đồ 2")
	await get_tree().create_timer(1.0).timeout
	check("C4: kênh thế giới nhận tin đầu", v.heard("rao bán đồ 1"))
	check("C4: kênh thế giới chặn gửi dồn (chờ 10 giây)", not v.heard("rao bán đồ 2") and u.notices.any(func(n: String) -> bool: return n.contains("Kênh thế giới")), u.notices)
	u.say(ChatServer.NEAR, "[color=red]giả mạo[/color]")
	check("C4: tin có mã định dạng vẫn tới nguyên văn (game tự chặn hiển thị)", await wait_until(func() -> bool: return v.heard("[color=red]giả mạo[/color]"), 3.0))
	u.close()
	v.close()

## C4b: bang hội thật — lập, xin vào, duyệt, thông báo, chat bang, rời, giải tán.
func test_guild() -> void:
	var gi := await make_player("g")
	var hi := await make_player("h")
	var g := bot(gi[0], gi[1])
	var h := bot(hi[0], hi[1])
	if not await wait_until(func() -> bool: return g.in_world and h.in_world):
		check("C4b: 2 bot vào map", false)
		return
	g.guild_op(GuildServer.G_TEST_BOOST)
	h.guild_op(GuildServer.G_TEST_BOOST)
	await get_tree().create_timer(0.5).timeout
	var gname := "Bang " + str(gi[1])
	g.guild_op(GuildServer.G_CREATE, {"title": gname, "camp": GuildRules.CAMPS[0]})
	check("C4b: lập bang", await wait_until(func() -> bool: return str(g.guild.get("name", "")) == gname, 3.0), g.notices)
	h.guild_op(GuildServer.G_LIST)
	check("C4b: bang có trong danh sách", await wait_until(func() -> bool:
		return h.guild_list.any(func(x: Dictionary) -> bool: return str(x.name) == gname), 3.0))
	h.guild_op(GuildServer.G_APPLY, {"guild": gname})
	check("C4b: bang chủ thấy đơn xin vào", await wait_until(func() -> bool:
		return g.guild.get("applies", []).any(func(a: Dictionary) -> bool: return str(a.name) == h.name), 3.0), h.notices)
	g.guild_op(GuildServer.G_ACCEPT, {"name": h.name})
	check("C4b: H vào bang", await wait_until(func() -> bool: return h.guild_member_names().has(h.name) and g.guild_member_names().size() == 2, 3.0), g.notices)
	check("C4b: cờ 'của mình' đúng người", h.guild.get("members", []).any(func(m: Dictionary) -> bool: return m.name == h.name and m.get("local", false)))
	g.guild_op(GuildServer.G_NOTICE, {"text": "Tối nay đánh Tống Kim"})
	check("C4b: thông báo bang tới thành viên", await wait_until(func() -> bool: return str(h.guild.get("notice", "")) == "Tối nay đánh Tống Kim", 3.0))
	h.say(ChatServer.GUILD, "chào bang chủ")
	check("C4b: chat kênh bang", await wait_until(func() -> bool: return g.heard("chào bang chủ"), 3.0))
	h.guild_op(GuildServer.G_LEAVE)
	check("C4b: rời bang", await wait_until(func() -> bool: return h.guild.is_empty() and g.guild_member_names().size() == 1, 3.0), h.notices)
	g.guild_op(GuildServer.G_DISBAND)
	check("C4b: giải tán bang", await wait_until(func() -> bool: return g.guild.is_empty(), 3.0), g.notices)
	h.guild_op(GuildServer.G_LIST)
	check("C4b: bang đã giải tán biến khỏi danh sách", await wait_until(func() -> bool:
		return not h.guild_list.any(func(x: Dictionary) -> bool: return str(x.name) == gname), 3.0))
	g.close()
	h.close()

## C5: khoá bảo vệ do server giữ — đặt mật mã thì khoá, khoá thì không mời giao dịch, mở bằng mật mã đúng.
func test_security() -> void:
	var si := await make_player("s")
	var ti := await make_player("t")
	var s := bot(si[0], si[1])
	var t := bot(ti[0], ti[1])
	if not await wait_until(func() -> bool: return s.in_world and t.in_world):
		check("C5: 2 bot vào map", false)
		return
	s.security(SocialServer.SEC_SET, "1234")
	check("C5: đặt mật mã thì khoá luôn", await wait_until(func() -> bool: return bool(s.profile.get("security_locked", false)), 3.0))
	t.stall_op(SocialServer.TRADE_OPEN)
	await get_tree().create_timer(0.3).timeout
	s.trade_request(t.eid)
	check("C5: đang khoá không mời giao dịch được", await wait_until(func() -> bool:
		return s.notices.any(func(n: String) -> bool: return n.contains("khoá bảo vệ")), 3.0), s.notices)
	s.security(SocialServer.SEC_UNLOCK, "9999")
	check("C5: mật mã sai không mở được", await wait_until(func() -> bool:
		return s.notices.any(func(n: String) -> bool: return n.contains("không chính xác")), 3.0) and bool(s.profile.get("security_locked", false)))
	s.security(SocialServer.SEC_UNLOCK, "1234")
	check("C5: mật mã đúng mở được", await wait_until(func() -> bool: return not bool(s.profile.get("security_locked", true)), 3.0))
	s.close()
	t.close()

func http_put(path: String, body: Dictionary, token: String) -> Dictionary:
	var h := HTTPRequest.new()
	add_child(h)
	h.request(API + path, ["Content-Type: application/json", "Authorization: Bearer " + token], HTTPClient.METHOD_PUT, JSON.stringify(body))
	var res: Array = await h.request_completed
	h.queue_free()
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return d if d is Dictionary else {}

func _character(info: Array) -> Dictionary:
	var list := await http("GET", "/v1/characters?server_id=1", {}, info[0])
	for c in list.get("characters", []):
		if int(c.id) == int(info[1]):
			return c
	return {}

## B3: gửi bản nhân vật gian lận cấp -> server giữ cấp của mình; thay đổi hợp lệ (thanh skill) vẫn được lưu khi thoát.
func test_profile_guard(p: BotClient, info: Array) -> void:
	var list := await http("GET", "/v1/characters?server_id=1", {}, info[0])
	var row: Dictionary = {}
	for c in list.get("characters", []):
		if int(c.id) == int(info[1]):
			row = c
	var data: Dictionary = row.get("data", {}).duplicate(true)
	var real_level := int(row.get("level", 1))
	data["level"] = 99
	data["exp"] = 0
	data["potential_points"] = 9999
	data["hotbar_page"] = 1
	p.send_profile(data)
	await get_tree().create_timer(0.5).timeout
	p.close()
	await get_tree().create_timer(1.5).timeout
	list = await http("GET", "/v1/characters?server_id=1", {}, info[0])
	for c in list.get("characters", []):
		if int(c.id) == int(info[1]):
			row = c
	check("cấp gian lận không được lưu", int(row.level) == maxi(real_level, p.level), [row.level, real_level, p.level])
	check("điểm tiềm năng gian lận không được lưu", int(row.data.potential_points) < 9999, row.data.potential_points)
	check("thay đổi hợp lệ được server lưu khi thoát", int(row.data.hotbar_page) == 1, row.data.hotbar_page)

## Tìm quái: đi theo các hướng tới khi thấy (bước 25 px / 1/15 giây ~ 375 px/s, dưới tốc độ tối đa).
func _walk_to_monsters(p: BotClient) -> bool:
	for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		for i in 40:
			p.move_to(p.feet + dir * 25.0)
			await get_tree().create_timer(1.0 / 15.0).timeout
			if p.nearest_monster() != 0:
				return true
	return false

func _walk(p: BotClient, to: Vector2) -> void:
	for i in 200:
		var d := to - p.feet
		if d.length() < 10.0:
			return
		p.move_to(p.feet + d.limit_length(25.0))
		await get_tree().create_timer(1.0 / 15.0).timeout

func run() -> void:
	var a_info := await make_player("a")
	var b_info := await make_player("b")
	check("tạo 2 người chơi thử", a_info[1] > 0 and b_info[1] > 0, [a_info, b_info])
	if a_info[1] == 0:
		return

	var bad := bot("token-sai", int(a_info[1]))
	check("token sai bị từ chối", await wait_until(func() -> bool: return bad.error_code != ""), bad.error_code)
	check("…mã lỗi unauthorized", bad.error_code == "unauthorized", bad.error_code)

	var a := bot(a_info[0], a_info[1])
	var b := bot(b_info[0], b_info[1])
	var ok := await wait_until(func() -> bool: return a.in_world and b.in_world)
	check("2 bot vào map", ok, [a.error_code, b.error_code])
	if not ok:
		check("game server đang chạy ở cổng 7777", false, "chạy: bash server/run_game_server.sh")
		return
	check("thấy nhau", await wait_until(func() -> bool: return a.known.has(b.eid) and b.known.has(a.eid)))
	check("tên người kia đúng", str(a.known.get(b.eid, {}).get("name", "")) == b.name)

	## A đi 120 px trong ~0,8 giây (tốc độ bình thường) -> B thấy vị trí mới.
	var start := a.feet
	for i in 12:
		a.move_to(start + Vector2(10 * (i + 1), 0), "run", 6)
		await get_tree().create_timer(1.0 / 15.0).timeout
	check("B nhận vị trí mới của A", await wait_until(func() -> bool:
		return b.known.has(a.eid) and (b.known[a.eid].pos as Vector2).distance_to(start + Vector2(120, 0)) < 2.0), b.known.get(a.eid))
	check("đi bình thường không bị kéo về", a.corrections == 0, a.corrections)

	## Gian lận: nhảy 3000 px trong 1 gói -> bị kéo về, B không thấy vị trí giả.
	var honest := a.feet
	a.move_to(honest + Vector2(3000, 0))
	check("dịch chuyển bị kéo về", await wait_until(func() -> bool: return a.corrections > 0), a.corrections)
	await get_tree().create_timer(0.4).timeout
	check("người khác không thấy vị trí gian lận", (b.known.get(a.eid, {}).get("pos", Vector2.ZERO) as Vector2).distance_to(honest) < 2.0)

	## Đăng nhập nhân vật A lần 2 -> phiên đầu bị đá.
	var a2 := bot(a_info[0], a_info[1])
	check("đăng nhập lần 2 vào được", await wait_until(func() -> bool: return a2.in_world))
	check("phiên cũ bị đá", await wait_until(func() -> bool: return a.error_code == "logged_in_elsewhere"), a.error_code)

	await test_monsters(a2)

	## B thoát -> A2 thấy B biến mất.
	check("A2 thấy B", await wait_until(func() -> bool: return a2.known.has(b.eid)))
	b.close()
	check("B thoát thì biến mất", await wait_until(func() -> bool: return not a2.known.has(b.eid)))

	await test_items(a2, a_info)
	await test_trade_and_stall()
	await test_team()
	await test_chat()
	await test_guild()
	await test_security()

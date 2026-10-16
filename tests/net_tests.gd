extends Node
## Kiểm thử game server (B1) với bot thật qua ENet. Cần chạy sẵn:
##   cd server && docker compose up -d                 (server tài khoản)
##   GODOT=... bash server/run_game_server.sh          (game server)
## rồi: godot --headless --path . res://tests/net_tests.tscn
## In PASS/FAIL từng ca, cuối cùng "RESULT x/y", thoát mã 1 nếu có ca hỏng.

const API := "http://127.0.0.1:8080"
const HOST := "127.0.0.1"
## Cổng ENet của game server cần thử (GAME_ENET_PORT, mặc định 7777) — chạy bản thử song song server đang mở.
var PORT := int(OS.get_environment("GAME_ENET_PORT")) if OS.has_environment("GAME_ENET_PORT") else 7777

var _pass := 0
var _fail := 0
var _bots: Array[BotClient] = []

var _skip := 0
## Server tài khoản đang bật DEV_TRUST_CLIENT_SAVES (máy dev, nút TEST): lưu HTTP được phép ghi nguyên dữ liệu game gửi -> các ca
## chống gian lận khi lưu HTTP không áp dụng (server/test.sh đặt biến này theo server/.env).
var DEV_TRUST_SAVES := OS.get_environment("DEV_TRUST_CLIENT_SAVES").to_lower() in ["true", "1"]

## Ca không áp dụng trong cấu hình hiện tại: in SKIP kèm lý do, không tính đạt / hỏng.
func skip(name: String, why: String) -> void:
	_skip += 1
	print("SKIP ", name, "  (", why, ")")

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
	print("RESULT %d/%d%s" % [_pass, _pass + _fail, " (bỏ qua %d)" % _skip if _skip > 0 else ""])
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
	## Server tài khoản giới hạn yêu cầu / phút theo IP (RATE_LIMIT_IP_PER_MIN — giữ nguyên, là lớp bảo vệ): chạy liền nhiều bài
	## test tạo hàng chục tài khoản bot thì bị 429 -> chờ rồi thử lại (tối đa ~1 phút).
	for attempt in 30:
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
		if int(res[1]) == 429:
			await get_tree().create_timer(2.0).timeout
			continue
		var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
		return d if d is Dictionary else {}
	return {}

## B2: quái do server điều khiển.
## Đánh quái `m` tới chết. Server cắt mỗi đòn theo trần của nhân vật (ProfileGuard.max_hit — nhân vật mới cấp 10: MIN_CAP) và tối đa
## MAX_DAMAGE_PER_SEC đòn / giây -> quái cấp 100 (~32000 máu theo script cấp gốc) cần ~110 đòn: gửi ~25 đòn / giây, tối đa 12 giây.
func _kill(b: BotClient, m: int) -> void:
	for i in 300:
		if not b.known.has(m) or int(b.known[m].get("hp", 100)) == 0:
			return
		b.damage(m, 100000)
		await get_tree().create_timer(0.04).timeout

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
	await _kill(p, m)
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
		await _kill(p, m)
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
	await _kill(x, m)
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
	check("Bày bán: người xung quanh thấy biển tên quầy trên đầu", str(x.known[y.eid].get("stall_title", "")) == "Hàng tốt giá rẻ", x.known[y.eid])
	check("Bày bán: người bán hiện đang ngồi", await wait_until(func() -> bool:
		return int(x.known[y.eid].get("action", -1)) == NetProto.action_index("sit") and (int(x.known[y.eid].get("flags", 0)) & NetProto.FLAG_SITTING) != 0, 3.0),
		x.known[y.eid])
	var x_gold := int(x.profile.get("gold", 0))
	x.stall_op(SocialServer.STALL_BUY, "", y.eid, item_uid)
	check("C2: mua ở quầy: đồ về X, tiền sang Y", await wait_until(func() -> bool:
		return x.inventory_uids().has(item_uid) and int(x.profile.gold) == x_gold - 5 and int(y.profile.gold) == 5, 3.0),
		[x.notices, y.notices, x.profile.get("gold"), y.profile.get("gold")])
	check("Bày bán: hết hàng thì tự dọn quầy, biển trên đầu biến mất", await wait_until(func() -> bool:
		return str(x.known[y.eid].get("stall_title", "x")) == "", 3.0), x.known[y.eid])
	## Bày bán rồi đứng dậy đi chỗ khác: server tự dọn quầy, người xung quanh mất biển
	var px := x.profile.duplicate(true)
	for it in px.inventory:
		if str(it.uid) == item_uid:
			it["price"] = 7
	x.send_profile(px)
	await get_tree().create_timer(0.6).timeout
	x.stall_op(SocialServer.STALL_OPEN, "")
	check("Bày bán: không đặt tên quầy thì dùng tên mặc định", await wait_until(func() -> bool:
		return str(y.known[x.eid].get("stall_title", "")).begins_with("Quầy của "), 3.0), y.known[x.eid])
	await get_tree().create_timer(0.3).timeout
	x.move_to(x.feet + Vector2(20, 0))
	check("Bày bán: di chuyển thì quầy tự dọn", await wait_until(func() -> bool:
		return str(y.known[x.eid].get("stall_title", "x")) == "" and x.my_stall_sign == "", 3.0), [y.known[x.eid], x.my_stall_sign])
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
	if DEV_TRUST_SAVES:
		skip("C2: lưu HTTP ngoài map không tăng được tiền / thêm đồ lạ", "server tài khoản bật DEV_TRUST_CLIENT_SAVES — máy thật phải tắt")
	else:
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
	await _kill(p, m)
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
## Ra chiêu: người đứng gần nhận S_CAST (đúng chiêu / cấp / mục tiêu / điểm nhắm) để vẽ lại; người ra chiêu không nhận lại.
func test_cast() -> void:
	var ai := await make_player("k")
	var bi := await make_player("l")
	var a := bot(ai[0], ai[1])
	var b := bot(bi[0], bi[1])
	if not await wait_until(func() -> bool: return a.in_world and b.in_world and a.known.has(b.eid) and b.known.has(a.eid)):
		check("Chiêu: 2 bot thấy nhau", false)
		return
	a.cast(1234, 7, b.eid, b.feet)
	var got := await wait_until(func() -> bool: return not b.casts.is_empty(), 3.0)
	var c: Dictionary = b.casts[0] if got else {}
	check("Chiêu: người gần nhận S_CAST", got and int(c.caster) == a.eid and int(c.skill) == 1234 and int(c.level) == 7
		and int(c.target) == b.eid and (c.aim as Vector2).distance_to(b.feet) < 1.0, c)
	check("Chiêu: người ra chiêu không nhận lại", a.casts.is_empty())
	for i in 30:
		a.cast(1234, 7, 0, a.feet)
	await get_tree().create_timer(1.0).timeout
	check("Chiêu: giới hạn số chiêu mỗi giây", b.casts.size() <= 1 + GameServer.MAX_CASTS_PER_SEC, b.casts.size())
	a.close()
	b.close()

## Menu người chơi: hảo hữu (xin -> đồng ý -> cả 2 có nhau), tin tức (xem trang bị), cừu sát (đếm ngược -> đánh -> PK).
func test_relations() -> void:
	var ai := await make_player("f")
	var bi := await make_player("g")
	var a := bot(ai[0], ai[1])
	var b := bot(bi[0], bi[1])
	if not await wait_until(func() -> bool: return a.in_world and b.in_world and a.known.has(b.eid) and b.known.has(a.eid)):
		check("Quan hệ: 2 bot thấy nhau", false)
		return
	## Hảo hữu
	a.friend(RelationServer.FRIEND_ASK, b.eid)
	check("Hảo hữu: bên kia nhận lời xin kết giao", await wait_until(func() -> bool: return not b.friend_invites.is_empty(), 3.0))
	b.friend(RelationServer.FRIEND_ANSWER, a.eid, 1)
	check("Hảo hữu: đồng ý thì cả 2 có nhau trong danh sách", await wait_until(func() -> bool:
		return (a.profile.get("friends", []) as Array).has(b.name) and (b.profile.get("friends", []) as Array).has(a.name), 3.0),
		[a.profile.get("friends"), b.profile.get("friends")])
	a.friend(RelationServer.FRIEND_LIST)
	check("Hảo hữu: danh sách báo bạn đang online", await wait_until(func() -> bool:
		return a.friend_list.any(func(f: Dictionary) -> bool: return f.name == b.name and bool(f.online)), 3.0), a.friend_list)
	b.friend(RelationServer.FRIEND_ANSWER, a.eid, 1)   ## trả lời khi không có lời xin: bỏ qua
	## Tin tức
	b.view_equip(a.eid)
	check("Tin tức: nhận bản trang bị của người kia", await wait_until(func() -> bool: return str(b.view_snap.get("name", "")) == a.name, 3.0), b.view_snap)
	## Trang bị qua mạng phải dựng lại được thành ItemInstance (lỗi cũ: gửi thẳng đối tượng -> thành chuỗi).
	var sp := PlayerProfile.new()
	var it := ItemInstance.new()
	it.base_index = 3
	sp.equipment[Equipment.Part.WEAPON] = it
	var wire: Variant = JSON.parse_string(JSON.stringify(ViewEquipService.snapshot_to_wire(ViewEquipService.snapshot_of_profile(sp))))
	var back := ViewEquipService.snapshot_from_wire(wire)
	check("Tin tức: trang bị qua mạng dựng lại thành ItemInstance", back.equipment.get(Equipment.Part.WEAPON) is ItemInstance
		and (back.equipment[Equipment.Part.WEAPON] as ItemInstance).base_index == 3, back.equipment)
	b.view_snap = {}
	b.view_equip(a.eid)
	await get_tree().create_timer(0.4).timeout
	check("Tin tức: xem liên tục bị chặn", b.view_snap.is_empty())
	## Quà tân thủ nâng nhân vật mới lên StarterKit.START_LEVEL (= hết Tân thủ, đủ cấp chọn phái) ngay lần vào map đầu: người xung quanh
	## thấy đúng cấp + phe theo phái (không còn Tân thủ tên trắng), nên cừu sát được ngay.
	check("Quà tân thủ: nhân vật mới hiện cấp %d, phe theo phái" % StarterKit.START_LEVEL,
		int(a.known.get(b.eid, {}).get("level", 0)) == StarterKit.START_LEVEL and int(a.known_camp(b.eid)) != Camp.Type.BEGIN, a.known.get(b.eid))
	a.pvp_hit(b.eid, 10, 20)
	await get_tree().create_timer(0.4).timeout
	check("Cừu sát: chưa tuyên bố thì đòn không tới", b.pvp_hits.is_empty())
	a.declare_enmity(b.eid)
	check("Cừu sát: 2 bên vào đếm ngược", await wait_until(func() -> bool:
		return int(a.enmity.get("state", 0)) == RelationServer.ENMITY_WAIT and int(b.enmity.get("state", 0)) == RelationServer.ENMITY_WAIT 			and bool(a.enmity.launcher) and not bool(b.enmity.launcher), 3.0), [a.enmity, b.enmity])
	a.pvp_hit(b.eid, 10, 20)
	await get_tree().create_timer(0.3).timeout
	check("Cừu sát: đang đếm ngược chưa đánh được", b.pvp_hits.is_empty())
	check("Cừu sát: hết đếm ngược thì vào trận", await wait_until(func() -> bool:
		return int(a.enmity.get("state", 0)) == RelationServer.ENMITY_FIGHT and int(b.enmity.get("state", 0)) == RelationServer.ENMITY_FIGHT, 4.0))
	a.pvp_hit(b.eid, 10, 99999999)
	check("Cừu sát: đòn tới máy đối thủ, bị cắt theo trần", await wait_until(func() -> bool: return not b.pvp_hits.is_empty(), 3.0)
		and int(b.pvp_hits[0].hit.get("max", 0)) < 99999999, b.pvp_hits)
	b.dead = true
	b.move_to(b.feet + Vector2(4, 0))
	check("Cừu sát: hạ đối thủ thì kết thúc + người khởi xướng +2 PK", await wait_until(func() -> bool:
		return a.enmity.get("state", 0) == 0 and int(a.profile.get("pk_value", 0)) == 2, 3.0), [a.enmity, a.profile.get("pk_value")])
	a.close()
	b.close()

## Nạp thẻ (web): đơn -> cổng giả lập -> ví Xu -> đổi Nguyên bảo cho nhân vật ĐANG ONLINE và nhân vật OFFLINE (nhận lúc vào map).
## Cần account server bật SHOP_SANDBOX=true.
func _jade_of(token: String, character_id: int) -> int:
	var r := await http("GET", "/v1/characters?server_id=1", {}, token)
	for c in r.get("characters", []):
		if int(c.id) == character_id:
			return int(c.data.get("jade", 0))
	return -1

func _buy_xu(token: String, vnd: int) -> Dictionary:
	var o := await http("POST", "/v1/shop/orders", {"amount_vnd": vnd}, token)
	var code := str(o.get("order", {}).get("code", ""))
	if code == "":
		return o
	return await http("POST", "/v1/shop/sandbox/%s/pay" % code, {}, token)

func test_shop() -> void:
	var cfg := await http("GET", "/v1/shop/config", {})
	if not bool(cfg.get("sandbox", false)):
		check("Nạp thẻ: account server bật SHOP_SANDBOX=true", false, cfg)
		return
	var ai := await make_player("p")
	var token: String = ai[0]
	var bad := await http("POST", "/v1/shop/orders", {"amount_vnd": 12345}, token)
	check("Nạp thẻ: mệnh giá lạ bị từ chối", str(bad.get("code", "")) == "bad_amount", bad)
	var paid := await _buy_xu(token, 10000)
	check("Nạp thẻ: thanh toán giả lập thành công", str(paid.get("order", {}).get("status", "")) == "paid", paid)
	var again := await http("POST", "/v1/shop/sandbox/%s/pay" % str(paid.get("order", {}).get("code", "")), {}, token)
	check("Nạp thẻ: 1 đơn chỉ cộng 1 lần", str(again.get("code", "")) == "order_done", again)
	var w := await http("GET", "/v1/shop/wallet", {}, token)
	var xu_per := int(cfg.get("xu_per_10k", 100))
	check("Nạp thẻ: ví nhận đúng số Xu", int(w.get("xu", -1)) == xu_per, w)
	var over := await http("POST", "/v1/shop/transfer", {"character_id": ai[1], "xu": xu_per + 1}, token)
	check("Đổi Xu: không đủ Xu thì từ chối", str(over.get("code", "")) == "not_enough_xu", over)
	## Nhân vật đang online: Nguyên bảo tới qua lần hỏi định kỳ (GAME_STATUS_POLL), có trong S_PROFILE và được lưu.
	var a := bot(ai[0], ai[1])
	if not await wait_until(func() -> bool: return a.in_world):
		check("Đổi Xu: bot vào map", false)
		return
	var jade_per := int(cfg.get("jade_per_xu", 1))
	var tr := await http("POST", "/v1/shop/transfer", {"character_id": ai[1], "xu": 40}, token)
	check("Đổi Xu: trừ ví", int(tr.get("xu", -1)) == xu_per - 40, tr)
	check("Đổi Xu: nhân vật online nhận Nguyên bảo", await wait_until(func() -> bool: return int(a.profile.get("jade", 0)) == 40 * jade_per, 8.0),
		a.profile.get("jade"))
	var saved := false
	for i in 20:
		if await _jade_of(token, ai[1]) == 40 * jade_per:
			saved = true
			break
		await get_tree().create_timer(0.5).timeout
	check("Đổi Xu: Nguyên bảo đã được lưu vào nhân vật", saved)
	await get_tree().create_timer(4.0).timeout   ## qua thêm 1 lần hỏi định kỳ: không được cộng lại
	check("Đổi Xu: không cộng 2 lần", int(a.profile.get("jade", 0)) == 40 * jade_per, a.profile.get("jade"))
	a.close()
	## Nhân vật offline: đổi trước, vào map mới nhận.
	var bi := await make_player("q")
	await _buy_xu(bi[0], 20000)
	await http("POST", "/v1/shop/transfer", {"character_id": bi[1], "xu": 25}, bi[0])
	var b := bot(bi[0], bi[1])
	check("Đổi Xu: nhân vật offline nhận Nguyên bảo khi vào map", await wait_until(func() -> bool:
		return b.in_world and int(b.profile.get("jade", 0)) == 25 * jade_per, 8.0), b.profile.get("jade"))
	b.close()

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

## Thoát game rồi vào lại -> đứng đúng chỗ lúc thoát (server lưu "pos" khi rời map).
func test_saved_position() -> void:
	var info := await make_player("p")
	var p := bot(info[0], info[1])
	if not await wait_until(func() -> bool: return p.in_world):
		check("Vị trí: vào map", false, p.error_code)
		return
	var first := p.feet
	await _walk(p, first + Vector2(60, 30))
	await get_tree().create_timer(0.3).timeout
	var left_at := p.feet
	check("Vị trí: đã đi khỏi chỗ xuất phát", left_at.distance_to(first) > 30.0, [first, left_at])
	p.close()
	var saved := false
	for i in 20:
		var d: Variant = (await _character(info)).get("data", {}).get("pos")
		if d is Array and Vector2(float(d[0]), float(d[1])).distance_to(left_at) < 2.0:
			saved = true
			break
		await get_tree().create_timer(0.25).timeout
	check("Vị trí: lưu khi thoát", saved)
	var again := bot(info[0], info[1])
	check("Vị trí: vào lại đúng chỗ cũ", await wait_until(func() -> bool: return again.in_world)
		and again.feet.distance_to(left_at) < 2.0, [left_at, again.feet])
	again.close()

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
	await test_cast()
	await test_relations()
	await test_shop()
	await test_saved_position()
	await test_hub_market()
	if OS.get_environment("NET_TEST_RESTART") == "1":   ## LÀM TẮT game server thử — chỉ server/test.sh bật, chạy cuối cùng
		await test_graceful_restart()

## Kết nối SẢNH (Character Hub, NetProto.HELLO_HUB): không có nhân vật trên map (không ai thấy, không di chuyển được) nhưng Chợ chạy
## thật: món người này treo, người khác (tài khoản khác) thấy cùng 1 sổ chợ — đồng bộ, không phải hàng giả sinh trên từng máy.
func _market_reply(b: BotClient, from: int, op: String, timeout := 4.0) -> Dictionary:
	await wait_until(func() -> bool:
		for i in range(from, b.market_msgs.size()):
			if b.market_msgs[i].get("op") == op:
				return true
		return false, timeout)
	for i in range(from, b.market_msgs.size()):
		if b.market_msgs[i].get("op") == op:
			return b.market_msgs[i]
	return {}

func test_hub_market() -> void:
	var i1 := await make_player("h")
	var i2 := await make_player("k")
	var iw := await make_player("w")
	var w := bot(iw[0], iw[1])
	var h1 := BotClient.new()
	h1.start(HOST, PORT, i1[0], i1[1], true)
	_bots.append(h1)
	var h2 := BotClient.new()
	h2.start(HOST, PORT, i2[0], i2[1], true)
	_bots.append(h2)
	var ok := await wait_until(func() -> bool: return h1.in_world and h2.in_world and w.in_world and not h1.profile.is_empty(), 8.0)
	check("Sảnh: vào bằng kết nối sảnh, nhận hồ sơ nhân vật", ok, [h1.error_message, h2.error_message])
	if not ok:
		return
	await get_tree().create_timer(1.0).timeout
	check("Sảnh: người trên map không thấy người ở sảnh", not w.known.has(h1.eid) and not w.known.has(h2.eid))
	check("Sảnh: người ở sảnh không thấy ai / quái nào", h1.known.is_empty(), h1.known.size())
	h1.move_to(h1.feet + Vector2(40, 0))   ## gói di chuyển từ sảnh bị bỏ qua
	await get_tree().create_timer(0.5).timeout
	check("Sảnh: gửi di chuyển không làm hiện ra trên map", not w.known.has(h1.eid))
	## Treo 1 món từ sảnh của tài khoản 1
	var uid := ""
	for it in h1.profile.get("inventory", []):
		if int(it.get("lock", 0)) == 0:
			uid = str(it.get("uid", ""))
			break
	var n1 := h1.market_msgs.size()
	h1.market("sell", {"uid": uid, "price": 4321, "cur": MarketBook.CUR_GOLD})
	var sold := await _market_reply(h1, n1, "done")
	check("Sảnh: treo bán được từ sảnh", bool(sold.get("ok", false)), sold)
	## Tài khoản 2 (sảnh) xem chợ: thấy đúng món đó của tài khoản 1
	await get_tree().create_timer(0.3).timeout
	var n2 := h2.market_msgs.size()
	h2.market("list", {"filter": {}, "page": 0})
	var lst := await _market_reply(h2, n2, "list")
	var mine := (lst.get("items", []) as Array).filter(func(l: Dictionary) -> bool:
		return str(l.get("seller", "")) == h1.name and int(l.get("price", 0)) == 4321)
	check("Chợ đồng bộ: tài khoản khác thấy món vừa treo (cùng 1 sổ chợ trên server)", not mine.is_empty(), [h1.name, (lst.get("items", []) as Array).size()])
	check("Chợ: phân trang %d món / trang" % MarketBook.PAGE_SIZE, int(lst.get("pages", 0)) >= 1 and (lst.get("items", []) as Array).size() <= MarketBook.PAGE_SIZE
		and int(lst.get("total", -1)) >= (lst.get("items", []) as Array).size(), [lst.get("page"), lst.get("pages"), lst.get("total")])
	## Dọn: huỷ treo
	if not mine.is_empty():
		await get_tree().create_timer(0.3).timeout
		var n3 := h1.market_msgs.size()
		h1.market("cancel", {"id": str(mine[0].get("id", ""))})
		var cancelled := await _market_reply(h1, n3, "done")
		check("Chợ: huỷ treo từ sảnh, món về hành trang", bool(cancelled.get("ok", false)), cancelled)
	h1.close()
	h2.close()
	w.close()

## Khởi động lại êm (lệnh web Admin; ở đây /testrestart): báo đếm ngược, chặn người mới, LƯU dữ liệu chưa lưu rồi mới mời ra.
func test_graceful_restart() -> void:
	var info := await make_player("r")
	var late_info := await make_player("l")
	var r := bot(info[0], info[1])
	if not await wait_until(func() -> bool: return r.in_world, 8.0):
		check("Khởi động lại: bot vào map", false, r.error_message)
		return
	var gold0 := int(r.profile.get("gold", 0))
	r.say(ChatServer.NEAR, "/testgold 777")   ## thay đổi CHƯA lưu (server lưu định kỳ mỗi 60 giây)
	await wait_until(func() -> bool: return int(r.profile.get("gold", 0)) == gold0 + 777, 4.0)
	await get_tree().create_timer(1.1).timeout   ## chat chờ giữa 2 lần nói
	r.say(ChatServer.NEAR, "/testrestart 4")
	check("Khởi động lại: người đang chơi nhận thông báo đếm ngược", await wait_until(func() -> bool:
		return r.notices.any(func(n: String) -> bool: return n.contains("khởi động lại")), 3.0), r.notices.slice(-2))
	var late := bot(late_info[0], late_info[1])
	check("Khởi động lại: người mới không vào được trong lúc đếm ngược", await wait_until(func() -> bool:
		return late.error_code != "" or late.in_world, 5.0) and late.error_code == "maintenance", [late.error_code, late.in_world])
	check("Khởi động lại: hết giờ thì mời người chơi ra (maintenance)", await wait_until(func() -> bool: return r.error_code == "maintenance", 15.0),
		r.error_code)
	var saved := -1
	var lst := await http("GET", "/v1/characters?server_id=1", {}, info[0])
	for ch in lst.get("characters", []):
		if int(ch.id) == int(info[1]):
			saved = int(ch.data.get("gold", -1))
	check("Khởi động lại: thay đổi chưa lưu đã được LƯU trước khi tắt", saved == gold0 + 777, [saved, gold0 + 777])

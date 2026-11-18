extends Node
## Kiểm thử CHIẾN TRƯỜNG SINH TỒN ONLINE (PubgServer trên server thế giới) với bot thật qua ENet. Cần server tài khoản + 1 server
## thế giới thử chạy với PUBG_ALWAYS_OPEN=1 PUBG_MIN_SQUADS=2 PUBG_SEARCH_SEC=3 (server/test.sh tự bật ở cổng 7957):
##   GAME_ENET_PORT=7957 godot --headless --path . res://tests/pubg_online_tests.tscn
## Luồng: 4 bot ở Hub (kết nối sảnh) lập 2 đội Duo bằng mã -> sẵn sàng -> tìm trận -> server ghép 1 trận -> từng bot nối lại kết nối
## thường -> vào trận với hồ sơ tạm cấp 200 -> chọn thẻ -> giao dịch bị chặn -> chết / bị loại -> kết quả -> mời rời -> về Hub hồ sơ thật
## còn nguyên (server không lưu hồ sơ tạm). In PASS/FAIL, cuối cùng "RESULT x/y".

var API := OS.get_environment("PUBG_API") if OS.has_environment("PUBG_API") else "http://127.0.0.1:8080"
const HOST := "127.0.0.1"
var PORT := int(OS.get_environment("GAME_ENET_PORT")) if OS.has_environment("GAME_ENET_PORT") else 7957

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

func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()

func sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

## Tài khoản + nhân vật mới; trả {token, cid, name}.
func make_account(tag: String) -> Dictionary:
	var user := "pg%s%d" % [tag, Time.get_unix_time_from_system() as int % 10000000]
	var r := await http("POST", "/v1/auth/register", {"username": user, "email": user + "@example.com", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	var p := PlayerProfile.new()
	var c := await http("POST", "/v1/characters", {"server_id": 1, "slot": 0, "name": "PG " + user.substr(2), "data": p.to_dict()}, token)
	return {"token": token, "cid": int(c.get("id", 0))}

func connect_bot(acc: Dictionary, hub: bool) -> BotClient:
	var b := BotClient.new()
	b.start(HOST, PORT, str(acc.token), int(acc.cid), hub)
	_bots.append(b)
	await wait_until(func() -> bool: return b.in_world or b.error_code != "", 8.0)
	return b

## Nhân vật mới vào map lần đầu (server đánh dấu server_seen + quà tân thủ) rồi thoát — như người chơi thật trước khi vào Hub.
func first_visit(acc: Dictionary) -> int:
	var b := await connect_bot(acc, false)
	await wait_until(func() -> bool: return not b.profile.is_empty(), 5.0)
	var lv := int(b.profile.get("level", 0))
	b.close()
	_bots.erase(b)
	await sleep(1.5)   ## server lưu lần cuối
	return lv

func http(method: String, path: String, body: Dictionary, token := "") -> Dictionary:
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

## Gửi C_PUBG rồi chờ gói có op thuộc `ops` mới tới.
func pubg(b: BotClient, op: int, args: Dictionary, ops: Array, timeout := 6.0) -> Dictionary:
	var n := b.pubg_msgs.size()
	b.pubg(op, args)
	await wait_until(func() -> bool: return _msg(b, n, ops) != {}, timeout)
	return _msg(b, n, ops)

static func _msg(b: BotClient, from: int, ops: Array) -> Dictionary:
	for i in range(from, b.pubg_msgs.size()):
		if str(b.pubg_msgs[i].get("op")) in ops:
			return b.pubg_msgs[i]
	return {}

static func last(b: BotClient, op: String) -> Dictionary:
	for i in range(b.pubg_msgs.size() - 1, -1, -1):
		if str(b.pubg_msgs[i].get("op")) == op:
			return b.pubg_msgs[i]
	return {}

static func room_id(msg: Dictionary) -> String:
	return str((msg.get("room", {}) as Dictionary).get("id", ""))

func run() -> void:
	var accs: Array = []
	for t in ["a", "b", "c", "d", "e"]:
		accs.append(await make_account(t))
	var start_levels: Array = []
	for acc in accs:
		start_levels.append(await first_visit(acc))
	check("5 nhân vật mới vào map lần đầu", start_levels.all(func(l): return int(l) > 0 and int(l) < 200), start_levels)

	## --- 1. Đội chờ ở Hub ---
	var hubs: Array[BotClient] = []
	for acc in accs:
		hubs.append(await connect_bot(acc, true))
	check("5 bot nối sảnh (Hub)", hubs.all(func(b: BotClient) -> bool: return b.in_world), hubs.map(func(b): return b.error_message))
	var a: BotClient = hubs[0]
	var b: BotClient = hubs[1]
	var c: BotClient = hubs[2]
	var d: BotClient = hubs[3]
	var e: BotClient = hubs[4]

	var ra := await pubg(a, PubgServer.OP_CREATE, {"mode": 2, "fill": false}, ["room", "reject"])
	var code_a := room_id(ra)
	check("A tạo đội Duo -> có mã PUBG-xxxx", code_a.begins_with("PUBG-"), ra)
	var rb := await pubg(b, PubgServer.OP_JOIN, {"code": code_a.replace("PUBG-", "")}, ["room", "reject"])
	check("B vào đội bằng mã (chỉ số)", room_id(rb) == code_a and (rb.room.members as Array).size() == 2, rb)
	var re := await pubg(e, PubgServer.OP_JOIN, {"code": code_a}, ["room", "reject"])
	check("E vào đội đã đủ người -> bị từ chối", str(re.get("op")) == "reject" and str(re.get("code")) == "full", re)

	var chat_n := b.pubg_msgs.size()
	a.pubg(PubgServer.OP_CHAT, {"text": "xin chao doi", "to": ""})
	await wait_until(func() -> bool: return _msg(b, chat_n, ["chat"]) != {} and str(_msg(b, chat_n, ["chat"]).line.text) == "xin chao doi", 4.0)
	check("Chat trong đội tới đồng đội", str(_msg(b, chat_n, ["chat"]).get("line", {}).get("text", "")) == "xin chao doi")

	var not_ready := await pubg(a, PubgServer.OP_SEARCH, {}, ["reject", "room"])
	check("Tìm trận khi chưa ai sẵn sàng -> bị chặn", str(not_ready.get("op")) == "reject", not_ready)
	await pubg(a, PubgServer.OP_READY, {"ready": true}, ["room"])
	await pubg(b, PubgServer.OP_READY, {"ready": true}, ["room"])

	var rc := await pubg(c, PubgServer.OP_CREATE, {"mode": 2, "fill": false}, ["room"])
	var code_c := room_id(rc)
	await pubg(d, PubgServer.OP_JOIN, {"code": code_c}, ["room"])
	await pubg(c, PubgServer.OP_READY, {"ready": true}, ["room"])
	await pubg(d, PubgServer.OP_READY, {"ready": true}, ["room"])

	## --- 2. Ghép trận ---
	var sa := await pubg(a, PubgServer.OP_SEARCH, {}, ["room"])
	check("Đội A bắt đầu tìm trận", bool((sa.get("room", {}) as Dictionary).get("searching", false)), sa)
	c.pubg(PubgServer.OP_SEARCH, {})
	var all_matched := await wait_until(func() -> bool:
		return [a, b, c, d].all(func(x: BotClient) -> bool: return last(x, "match") != {}), 15.0)
	check("2 đội Duo được ghép chung 1 trận", all_matched and int(last(a, "match").get("rid", 0)) == int(last(c, "match").get("rid", -1)),
		[last(a, "match"), last(c, "match")])
	if not all_matched:
		return
	var m := last(a, "match")
	var box := Rect2(float(m.box[0]), float(m.box[1]), float(m.box[2]), float(m.box[3]))
	check("Tin trận có khung 140x80 region + seed + đội", box.size == Vector2(140 * 512, 80 * 512) and (m.squad as Array).size() == 2, m)
	var ra2 := await pubg(e, PubgServer.OP_JOIN, {"code": code_a}, ["reject", "room"])
	check("Đội đã vào trận thì mã đội không còn", str(ra2.get("op")) == "reject", ra2)

	## --- 3. Vào trận bằng kết nối thường ---
	var real_inv: Array = []
	for x in [a, b, c, d]:
		real_inv.append(x.inventory_uids())
		x.close()
	_bots = _bots.filter(func(x: BotClient) -> bool: return not [a, b, c, d].has(x))
	await sleep(1.0)
	var fa := await connect_bot(accs[0], false)
	var fb := await connect_bot(accs[1], false)
	var fc := await connect_bot(accs[2], false)
	var fd := await connect_bot(accs[3], false)
	var fighters: Array[BotClient] = [fa, fb, fc, fd]
	check("4 bot vào trận", fighters.all(func(x: BotClient) -> bool: return x.in_world), fighters.map(func(x): return x.error_message))
	await wait_until(func() -> bool: return fighters.all(func(x: BotClient) -> bool: return not x.profile.is_empty() and last(x, "match") != {}), 6.0)
	check("Điểm vào trận nằm trong khung chơi", fighters.all(func(x: BotClient) -> bool: return box.has_point(x.feet)), fighters.map(func(x): return x.feet))
	check("Hồ sơ trong trận: cấp 200, 995 điểm tiềm năng", int(fa.profile.get("level", 0)) == 200 and int(fa.profile.get("potential_points", 0)) == 995,
		[fa.profile.get("level"), fa.profile.get("potential_points")])
	var inv: Array = fa.profile.get("inventory", [])
	check("Hồ sơ trong trận: tay trắng + 50 bình thuốc", inv.size() == 1 and int((inv[0] as Dictionary).get("count", 0)) == 50 \
		and (fa.profile.get("equipment", {}) as Dictionary).is_empty(), [inv.size(), fa.profile.get("equipment")])
	await wait_until(func() -> bool: return fa.known.has(fb.eid), 4.0)
	check("Đồng đội thấy nhau trong trận", fa.known.has(fb.eid))
	check("Có quái trong trận", fa.known.values().any(func(k) -> bool: return k.kind == NetProto.KIND_MONSTER) \
		or fc.known.values().any(func(k) -> bool: return k.kind == NetProto.KIND_MONSTER))
	var st := last(fa, "mstate")
	check("Trạng thái trận: 4 người, 2 đội, đồng đội = mình + B", int(st.get("alive_players", 0)) == 4 and int(st.get("alive_squads", 0)) == 2 \
		and (st.squad_eids as Array).has(fb.eid), st)

	## --- 4. Chọn thẻ (server sinh ngựa + vũ khí) ---
	var before_v := int(fa.profile.get("vitality", 0))
	fa.pubg(PubgServer.OP_DRAFT, {"horse": 2, "weapon": 1, "build": {"vit": 100}})
	await wait_until(func() -> bool: return (fa.profile.get("equipment", {}) as Dictionary).size() >= 2, 4.0)
	var eq: Dictionary = fa.profile.get("equipment", {})
	check("Chọn thẻ: server trang bị ngựa + vũ khí", eq.size() >= 2, eq.keys())
	check("Chọn thẻ: cộng điểm tiềm năng theo build", int(fa.profile.get("vitality", 0)) == before_v + 100 and int(fa.profile.get("potential_points", 0)) == 895,
		[fa.profile.get("vitality"), fa.profile.get("potential_points")])
	var eq_n := (fa.profile.get("equipment", {}) as Dictionary).size()
	fa.pubg(PubgServer.OP_DRAFT, {"horse": 5, "weapon": 3, "build": {"str": 500}})
	await sleep(1.0)
	check("Chọn thẻ chỉ 1 lần mỗi trận", int(fa.profile.get("potential_points", 0)) == 895 and (fa.profile.get("equipment", {}) as Dictionary).size() == eq_n)

	## --- 5. Chặn giao dịch: người ngoài (E ở Hub) xin giao dịch với người trong trận ---
	var e_notes := e.notices.size()
	var trade := NetProto.writer(NetProto.C_TRADE_REQ_ID)
	trade.put_u32(int(accs[0].cid))
	e._send(trade, NetProto.CH_RELIABLE)
	await wait_until(func() -> bool: return e.notices.size() > e_notes, 4.0)
	check("Giao dịch với người đang trong trận bị chặn", e.notices.size() > e_notes and str(e.notices.back()).contains("Sinh Tồn") and fa.trade_invites.is_empty(),
		e.notices.slice(e_notes))

	## --- 6. Loại / kết quả ---
	fb.dead = true
	fb.move_to(fb.feet)
	await wait_until(func() -> bool: return last(fb, "eliminated") != {}, 4.0)
	var el := last(fb, "eliminated")
	check("B chết -> bị loại, đội vẫn còn A", el != {} and not bool(el.get("squad_out", true)), el)
	var corr := fb.corrections
	fb.revive()
	await sleep(1.0)
	check("Bị loại thì không hồi sinh được (server không đưa về điểm hồi sinh)", fb.corrections == corr)
	fa.dead = true
	fa.move_to(fa.feet)
	await wait_until(func() -> bool: return last(fa, "eliminated") != {} and last(fc, "result") != {}, 5.0)
	check("A chết -> đội A hạng 2", int(last(fa, "eliminated").get("rank", 0)) == 2, last(fa, "eliminated"))
	var res_c := last(fc, "result")
	check("Đội C thắng (TOP 1)", bool(res_c.get("win", false)) and int(res_c.get("rank", 0)) == 1, res_c)
	check("Đội A nhận kết quả hạng 2", int(last(fa, "result").get("rank", 0)) == 2, last(fa, "result"))
	await wait_until(func() -> bool: return fighters.all(func(x: BotClient) -> bool: return x.error_code == "pubg_end" or x.closed), 20.0)
	check("Hết trận -> server mời mọi người rời (pubg_end)", fighters.all(func(x: BotClient) -> bool: return x.error_code == "pubg_end"),
		fighters.map(func(x): return x.error_code))

	## --- 7. Về Hub: hồ sơ thật còn nguyên (hồ sơ tạm không được lưu) ---
	for x in fighters:
		x.close()
	await sleep(2.0)
	var back := await connect_bot(accs[0], true)
	await wait_until(func() -> bool: return not back.profile.is_empty(), 5.0)
	check("Về Hub: cấp thật như trước trận (không phải 200)", int(back.profile.get("level", 0)) == int(start_levels[0]),
		[back.profile.get("level"), start_levels[0]])
	check("Về Hub: túi đồ thật còn nguyên", back.inventory_uids() == real_inv[0], [back.inventory_uids().size(), (real_inv[0] as Array).size()])
	var again := await pubg(back, PubgServer.OP_STATE, {}, ["none", "room"])
	check("Về Hub: không còn kẹt trong đội / trận", str(again.get("op")) == "none", again)

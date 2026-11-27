extends Node
## Kiểm thử ĐỦ KÊNH CHAT online với bot thật qua ENet — đúng người nhận / không nhận theo mục đích từng kênh:
##   Gần (người đứng gần), Tổ đội (chỉ thành viên đội), Môn phái (cùng phái), Thế giới (mọi người), Riêng (đúng tên).
## + người ở SẢNH (Hub — kết nối HELLO_HUB) và người ở tiến trình khác (phòng train Vượt Ải — field server).
## Cần chạy sẵn server tài khoản + game server thế giới (GAME_ENET_PORT) + field server (FIELD_PORT, 0 = bỏ phần đó):
##   KIEMHIEP_NO_SAVE=1 GAME_ENET_PORT=7777 FIELD_PORT=7807 godot --headless --path . res://tests/chat_channels_net_tests.tscn
## (Kênh Bang hội đã có ở net_tests C4b.) In PASS/FAIL từng ca, cuối cùng "RESULT x/y".

const API := "http://127.0.0.1:8080"
const HOST := "127.0.0.1"
var PORT := int(OS.get_environment("GAME_ENET_PORT")) if OS.has_environment("GAME_ENET_PORT") else 7777
var FIELD_PORT := int(OS.get_environment("FIELD_PORT")) if OS.has_environment("FIELD_PORT") else 0

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

## Tạo tài khoản + nhân vật (phái theo hệ `element`), trả [access_token, character_id, tên].
func make_player(tag: String, element: int) -> Array:
	var user := "ch%s%d" % [tag, Time.get_unix_time_from_system() as int % 10000000]
	var r := await http("POST", "/v1/auth/register", {"username": user, "email": user + "@example.com", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	var p := PlayerProfile.new()
	p.set_sect(SectRegistry.get_by_element(element)[0])
	var name := "Chat " + user.substr(2)
	var c := await http("POST", "/v1/characters", {"server_id": 1, "slot": 0, "name": name, "data": p.to_dict()}, token)
	return [token, int(c.get("id", 0)), name]

func bot(info: Array, port: int, hub := false) -> BotClient:
	var b := BotClient.new()
	b.start(HOST, port, info[0], info[1], hub)
	_bots.append(b)
	return b

func http(method: String, path: String, body: Dictionary, token := "") -> Dictionary:
	for attempt in 30:
		var h := HTTPRequest.new()
		add_child(h)
		var headers := ["Content-Type: application/json"]
		if token != "":
			headers.append("Authorization: Bearer " + token)
		h.request(API + path, headers, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET, JSON.stringify(body))
		var res: Array = await h.request_completed
		h.queue_free()
		if int(res[1]) == 429:
			await sleep(2.0)
			continue
		var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
		return data if data is Dictionary else {}
	return {}

## Nói rồi chờ đủ giãn cách của server (MIN_INTERVAL 0.8 giây).
func say(b: BotClient, ch: int, text: String, to := "") -> void:
	b.say(ch, text, to)
	await sleep(1.0)

func run() -> void:
	var kim := ElementTypes.ElementType.KIM
	var moc := ElementTypes.ElementType.MOC
	var ai := await make_player("a", kim)
	var bi := await make_player("b", kim)
	var ci := await make_player("c", moc)
	var hi := await make_player("h", moc)
	var a := bot(ai, PORT)
	var b := bot(bi, PORT)
	var c := bot(ci, PORT)
	var h := bot(hi, PORT, true)   ## người đang ở Hub (sảnh)
	if not await wait_until(func() -> bool: return a.in_world and b.in_world and c.in_world and h.in_world, 10.0):
		check("4 bot vào game (3 map + 1 sảnh)", false, [a.error_message, b.error_message, c.error_message, h.error_message])
		return
	await sleep(0.8)

	## ---- Tổ đội: A lập đội, B vào; C ngoài đội
	a.team_op(SocialServer.TEAM_CREATE)
	await wait_until(func() -> bool: return a.team.get("in_team", false), 3.0)
	a.team_op(SocialServer.TEAM_INVITE, b.eid)
	await wait_until(func() -> bool: return b.team_invites.has(a.eid), 3.0)
	b.team_op(SocialServer.TEAM_ANSWER, a.eid, 1)
	check("chuẩn bị: A + B cùng đội", await wait_until(func() -> bool: return b.team.get("members", []).size() == 2, 3.0), b.team)

	## ---- Gần
	await say(a, ChatServer.NEAR, "gan 1")
	check("Gần: B đứng gần nhận", await wait_until(func() -> bool: return b.heard("gan 1"), 3.0), b.chats)
	check("Gần: người ở Hub KHÔNG nhận (không đứng trên map)", not h.heard("gan 1"), h.chats)

	## ---- Tổ đội
	await say(a, ChatServer.TEAM, "doi 1")
	check("Tổ đội: B (cùng đội) nhận", await wait_until(func() -> bool: return b.heard("doi 1"), 3.0), b.chats)
	check("Tổ đội: A thấy lại tin của mình", a.heard("doi 1"), a.chats)
	check("Tổ đội: C (ngoài đội) KHÔNG nhận", not c.heard("doi 1"), c.chats)
	await say(c, ChatServer.TEAM, "doi c")
	check("Tổ đội: chưa có đội -> báo", await wait_until(func() -> bool:
		return c.notices.any(func(n: String) -> bool: return n.contains("chưa có tổ đội")), 3.0), c.notices)

	## ---- Môn phái (A, B hệ Kim cùng phái; C hệ Mộc khác phái)
	await say(a, ChatServer.FACTION, "phai 1")
	check("Môn phái: B (cùng phái) nhận", await wait_until(func() -> bool: return b.heard("phai 1"), 3.0), b.chats)
	check("Môn phái: C (khác phái) KHÔNG nhận", not c.heard("phai 1"), c.chats)

	## ---- Riêng
	await say(a, ChatServer.PRIVATE, "rieng 1", ci[2])
	check("Riêng: C (đúng tên) nhận", await wait_until(func() -> bool: return c.heard("rieng 1"), 3.0), c.chats)
	check("Riêng: A thấy lại tin đã gửi", a.heard("rieng 1"), a.chats)
	check("Riêng: B KHÔNG nhận", not b.heard("rieng 1"), b.chats)
	await say(a, ChatServer.PRIVATE, "rieng hub", hi[2])
	check("Riêng: người ở Hub nhận", await wait_until(func() -> bool: return h.heard("rieng hub"), 3.0), h.chats)

	## ---- Thế giới
	await say(a, ChatServer.WORLD, "the gioi 1")
	check("Thế giới: B nhận", await wait_until(func() -> bool: return b.heard("the gioi 1"), 3.0), b.chats)
	check("Thế giới: C nhận", c.heard("the gioi 1"), c.chats)
	check("Thế giới: người ở Hub nhận", h.heard("the gioi 1"), h.chats)

	## ---- Hub gửi kênh Gần: không ai trên map nhận (sảnh không đứng ở đâu cả)
	h.notices.clear()
	await say(h, ChatServer.NEAR, "gan tu hub")
	await sleep(0.5)
	check("Gần từ Hub: người trên map KHÔNG nhận", not a.heard("gan tu hub") and not b.heard("gan tu hub") and not c.heard("gan tu hub"),
		[a.heard("gan tu hub"), b.heard("gan tu hub"), c.heard("gan tu hub")])
	check("Gần từ Hub: báo chỉ dùng trong map", h.notices.any(func(n: String) -> bool: return n.contains("chỉ dùng khi đang ở trong map")), h.notices)

	## ---- Tiến trình khác: người ở phòng train Vượt Ải (field server)
	if FIELD_PORT > 0:
		var fi := await make_player("f", moc)
		var f := bot(fi, FIELD_PORT)
		if not await wait_until(func() -> bool: return f.in_world, 10.0):
			check("bot vào field server", false, f.error_message)
			return
		await sleep(11.0)   ## qua giãn cách kênh thế giới (10 giây) của A
		await say(a, ChatServer.WORLD, "the gioi 2")
		check("Thế giới: người ở Vượt Ải (tiến trình khác) nhận", await wait_until(func() -> bool: return f.heard("the gioi 2"), 4.0), f.chats)
		a.notices.clear()
		await say(a, ChatServer.PRIVATE, "rieng field", fi[2])
		check("Riêng: người ở Vượt Ải (tiến trình khác) nhận", await wait_until(func() -> bool: return f.heard("rieng field"), 4.0),
			[f.chats, a.notices])
		await say(f, ChatServer.WORLD, "tu vuot ai")
		check("Thế giới: người ở map thế giới nhận tin từ Vượt Ải", await wait_until(func() -> bool: return a.heard("tu vuot ai"), 4.0), a.chats)

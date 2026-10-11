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
	var aggro := await wait_until(func() -> bool: return not p.attacked_by.is_empty(), 12.0)
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

	await test_profile_guard(a2, a_info)

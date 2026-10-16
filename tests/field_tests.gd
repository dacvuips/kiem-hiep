extends Node
## Kiểm thử PHÒNG TRAIN CHUNG Vượt Ải (FieldServer) với bot thật qua ENet. Cần chạy sẵn server tài khoản + field server:
##   GODOT=... bash server/run_field_server.sh
## rồi: godot --headless --path . res://tests/field_tests.tscn   (FIELD_API / GAME_ENET_PORT đổi địa chỉ nếu cần)
## In PASS/FAIL, cuối cùng "RESULT x/y".

var API := OS.get_environment("FIELD_API") if OS.has_environment("FIELD_API") else "http://127.0.0.1:8080"
const HOST := "127.0.0.1"
var PORT := int(OS.get_environment("GAME_ENET_PORT")) if OS.has_environment("GAME_ENET_PORT") else 7807
const NORMAL_MAP := 20        ## Giang Tân Thôn (1x)
## Cổng tiến trình field thứ 2 — đặt FIELD_PORT2 để thử chạy nhiều tiến trình. FIELD_INDEX / FIELD_INDEX2 = GAME_FIELD_INDEX của 2
## tiến trình đang thử (server/test.sh dùng 7 và 8 để không đụng field server thật index 0 đang chạy).
var PORT2 := int(OS.get_environment("FIELD_PORT2")) if OS.has_environment("FIELD_PORT2") else 0
var INDEX1 := int(OS.get_environment("FIELD_INDEX")) if OS.has_environment("FIELD_INDEX") else 0
var INDEX2 := int(OS.get_environment("FIELD_INDEX2")) if OS.has_environment("FIELD_INDEX2") else 1
const HELL_TIER := 12

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

func make_bot(tag: String, port := -1) -> BotClient:
	var user := "fd%s%d" % [tag, Time.get_unix_time_from_system() as int % 10000000]
	var r := await http("POST", "/v1/auth/register", {"username": user, "email": user + "@example.com", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	var p := PlayerProfile.new()
	var c := await http("POST", "/v1/characters", {"server_id": 1, "slot": 0, "name": "FD " + user.substr(2), "data": p.to_dict()}, token)
	var b := BotClient.new()
	b.set_meta("token", token)
	b.start(HOST, PORT if port < 0 else port, token, int(c.get("id", 0)))
	_bots.append(b)
	await wait_until(func() -> bool: return b.in_world or b.error_code != "", 8.0)
	return b

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

## Gửi C_FIELD rồi chờ gói "room" / "reject" mới.
func field(b: BotClient, op: int, args: Dictionary) -> Dictionary:
	var n := b.field_msgs.size()
	b.field(op, args)
	await wait_until(func() -> bool: return _reply(b, n) != {}, 6.0)
	return _reply(b, n)

static func _reply(b: BotClient, from: int) -> Dictionary:
	for i in range(from, b.field_msgs.size()):
		if b.field_msgs[i].get("op") in ["room", "reject"]:
			return b.field_msgs[i]
	return {}

static func last_state(b: BotClient) -> Dictionary:
	for i in range(b.field_msgs.size() - 1, -1, -1):
		if b.field_msgs[i].get("op") in ["room", "state"]:
			return b.field_msgs[i]
	return {}

static func monsters_of(b: BotClient) -> Array:
	return b.known.keys().filter(func(id: int) -> bool: return b.known[id].kind == NetProto.KIND_MONSTER)

static func sees_player(b: BotClient, other: BotClient) -> bool:
	return b.known.has(other.eid)

func run() -> void:
	var a := await make_bot("a")
	var b := await make_bot("b")
	var c := await make_bot("c")
	check("3 bot vào sảnh field server", a.in_world and b.in_world and c.in_world, [a.error_message, b.error_message, c.error_message])
	if not (a.in_world and b.in_world and c.in_world):
		return
	await sleep(0.5)
	check("sảnh: không thấy ai", not sees_player(a, b) and monsters_of(a).is_empty(), a.known.size())

	## Tạo phòng Thường
	var room := await field(a, FieldServer.OP_CREATE, {"map_id": NORMAL_MAP, "tier": 0})
	var id := str(room.get("id", ""))
	check("tạo phòng -> ID 6 số", room.get("op") == "room" and id.length() == 6 and id.is_valid_int(), room)
	await wait_until(func() -> bool: return monsters_of(a).size() > 0, 5.0)
	check("chủ phòng thấy quái của map phòng", monsters_of(a).size() > 0)
	## Server tài khoản: GET /v1/field liệt kê phòng (màn Vượt Ải tra ID ở đây trước khi kết nối)
	var listed := {}
	var t0 := Time.get_ticks_msec()
	while listed.is_empty() and Time.get_ticks_msec() - t0 < 6000:
		var st := await http("GET", "/v1/field?server_id=1", {}, str(a.get_meta("token")))
		for r in st.get("rooms", []):
			if str(r.get("id", "")) == id:
				listed = st
				listed["room"] = r
		if listed.is_empty():
			await sleep(0.5)
	check("/v1/field có phòng vừa tạo + địa chỉ field server", not listed.is_empty() and bool(listed.get("open")) and int(listed.room.get("port", 0)) == PORT
		and int(listed.room.get("map_id", 0)) == NORMAL_MAP, listed)
	var entry := MapSelectWindow.join_entry(listed.get("room", {}))
	check("tra ID ra đúng map để nạp", int(entry.get("id", 0)) == NORMAL_MAP and MapCatalog.is_playable(entry), entry.get("name"))

	## Vào bằng ID
	var bad := await field(b, FieldServer.OP_JOIN, {"room": "000000", "map_id": NORMAL_MAP, "tier": 0})
	check("sai ID -> từ chối", bad.get("op") == "reject", bad)
	var wrong_map := await field(b, FieldServer.OP_JOIN, {"room": id, "map_id": 2, "tier": 0})
	check("đúng ID nhưng khác map -> từ chối", wrong_map.get("op") == "reject", wrong_map)
	var joined := await field(b, FieldServer.OP_JOIN, {"room": id, "map_id": NORMAL_MAP, "tier": 0})
	check("vào phòng bằng ID", joined.get("op") == "room" and str(joined.get("id")) == id, joined)
	await wait_until(func() -> bool: return sees_player(a, b) and sees_player(b, a), 5.0)
	check("2 người cùng phòng thấy nhau", sees_player(a, b) and sees_player(b, a))
	await wait_until(func() -> bool: return (last_state(a).get("members", []) as Array).size() == 2, 3.0)
	check("chủ phòng nhận danh sách 2 người", (last_state(a).get("members", []) as Array).size() == 2, last_state(a))

	## Phòng thứ 2 cùng map: tách biệt hẳn
	var room2 := await field(c, FieldServer.OP_CREATE, {"map_id": NORMAL_MAP, "tier": 0})
	check("phòng thứ 2 cùng map có ID khác", room2.get("op") == "room" and str(room2.get("id")) != id, room2)
	await wait_until(func() -> bool: return monsters_of(c).size() > 0, 5.0)
	await sleep(0.5)
	check("người phòng khác không thấy nhau (dù cùng chỗ)", not sees_player(a, c) and not sees_player(c, a) and not sees_player(b, c))
	var shared := monsters_of(a).filter(func(e: int) -> bool: return c.known.has(e))
	check("quái 2 phòng là 2 bầy riêng", shared.is_empty() and monsters_of(c).size() > 0, shared.size())

	## Đánh quái phòng khác: server bỏ qua
	var target: int = monsters_of(c)[0] if not monsters_of(c).is_empty() else 0
	var hp_before: int = c.known[target].hp if target != 0 else 0
	for i in 5:
		a.damage(target, 999999)
	await sleep(0.6)
	check("không đánh được quái phòng khác", target != 0 and c.known.has(target) and int(c.known[target].hp) == hp_before and a.kills.is_empty(),
		[target, hp_before, c.known.get(target, {}).get("hp")])

	## Phòng Địa Ngục: quái cấp 120
	var d := await make_bot("d")
	var hell_map := int(MapCatalog.HELL_MAPS[HELL_TIER][0])
	var hroom := await field(d, FieldServer.OP_CREATE, {"map_id": hell_map, "tier": HELL_TIER, "stars": 5})
	check("tạo phòng Địa Ngục 12x 5 sao", hroom.get("op") == "room" and int(hroom.get("stars", 0)) == 5, hroom)
	await wait_until(func() -> bool: return monsters_of(d).size() > 0, 5.0)
	var levels := {}
	for e in monsters_of(d):
		levels[int(d.known[e].level)] = true
	check("quái phòng Địa Ngục cấp 120", levels.keys() == [120], levels.keys())
	var not_hell := await field(b, FieldServer.OP_CREATE, {"map_id": NORMAL_MAP, "tier": HELL_TIER, "stars": 3})
	check("map không thuộc Địa Ngục -> từ chối", not_hell.get("op") == "reject", not_hell)

	## Chủ phòng rời -> phòng đóng, người còn lại bị mời ra
	a.close()
	await wait_until(func() -> bool: return b.error_code != "", 6.0)
	check("chủ phòng rời -> người trong phòng nhận field_end", b.error_code == "field_end", [b.error_code, b.error_message])
	var e := await make_bot("e")
	var gone := await field(e, FieldServer.OP_JOIN, {"room": id, "map_id": NORMAL_MAP, "tier": 0})
	check("phòng đã đóng -> ID không vào được nữa", gone.get("op") == "reject", gone)
	if PORT2 > 0:
		await test_two_processes(e)

## 2 tiến trình field: ID không trùng (chữ số đầu = index + 1), /v1/field gộp phòng của cả 2 kèm địa chỉ, chỉ tiến trình vắng hơn.
func test_two_processes(p1: BotClient) -> void:
	var p2 := await make_bot("p", PORT2)
	check("bot vào tiến trình field thứ 2", p2.in_world, p2.error_message)
	if not p2.in_world:
		return
	var r1 := await field(p1, FieldServer.OP_CREATE, {"map_id": NORMAL_MAP, "tier": 0})
	var r2 := await field(p2, FieldServer.OP_CREATE, {"map_id": NORMAL_MAP, "tier": 0})
	var id1 := str(r1.get("id", ""))
	var id2 := str(r2.get("id", ""))
	check("ID phòng 2 tiến trình khác chữ số đầu", id1.begins_with(str(INDEX1 + 1)) and id2.begins_with(str(INDEX2 + 1)), [id1, id2])
	var st := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		st = await http("GET", "/v1/field?server_id=1", {}, str(p1.get_meta("token")))
		var ids := (st.get("rooms", []) as Array).map(func(r: Dictionary) -> String: return str(r.get("id", "")))
		if ids.has(id1) and ids.has(id2):
			break
		await sleep(0.5)
	var by_id := {}
	for r in st.get("rooms", []):
		by_id[str(r.get("id", ""))] = r
	check("/v1/field gộp phòng của cả 2 tiến trình", by_id.has(id1) and by_id.has(id2), by_id.keys())
	check("mỗi phòng kèm cổng tiến trình giữ nó", int(by_id.get(id1, {}).get("port", 0)) == PORT and int(by_id.get(id2, {}).get("port", 0)) == PORT2,
		[by_id.get(id1, {}).get("port"), by_id.get(id2, {}).get("port")])
	## Thêm 2 người vào tiến trình 1 -> phòng mới KHÔNG chỉ vào tiến trình 1 (đông nhất); có thể là tiến trình 2 hoặc field server thật
	## đang chạy song song (vắng hơn nữa)
	var x := await make_bot("x")
	var y := await make_bot("y")
	await field(x, FieldServer.OP_JOIN, {"room": id1, "map_id": NORMAL_MAP, "tier": 0})
	await field(y, FieldServer.OP_JOIN, {"room": id1, "map_id": NORMAL_MAP, "tier": 0})
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		st = await http("GET", "/v1/field?server_id=1", {}, str(p1.get_meta("token")))
		if int(st.get("port", 0)) != PORT and int(st.get("port", 0)) != 0:
			break
		await sleep(0.5)
	check("phòng mới không chỉ vào tiến trình đông nhất", int(st.get("port", 0)) != PORT and int(st.get("port", 0)) != 0,
		[st.get("port"), st.get("players")])

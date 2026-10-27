extends Node
## Kiểm tra 2 người chơi vào map Boss:
## 1. Không qua phòng chờ, trực tiếp vào chung 1 phòng.
## 2. Cùng thấy nhau ngay lập tức (AOI).
## 3. Không bị văng toạ độ ra ngoài map (grey void).
## 4. Thấy Boss Hoàng Kim xuất hiện trong map.

var API := OS.get_environment("FIELD_API") if OS.has_environment("FIELD_API") else "https://kiem-hiep-api.viettheo.site"
var HOST := OS.get_environment("GAME_HOST") if OS.has_environment("GAME_HOST") else "161.248.147.33"
var PORT := int(OS.get_environment("GAME_ENET_PORT")) if OS.has_environment("GAME_ENET_PORT") else 7807

var _pass := 0
var _fail := 0
var _bots: Array[BotClient] = []

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS: ", name)
	else:
		_fail += 1
		print("FAIL: ", name, "  | Detail: ", detail)

func _process(_d: float) -> void:
	for b in _bots:
		b.poll()

func _ready() -> void:
	await run()
	for b in _bots:
		b.close()
	print("RESULT: %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func wait_until(cond: Callable, timeout := 8.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout * 1000):
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func make_bot(tag: String) -> BotClient:
	var user := "b%s%d" % [tag, Time.get_unix_time_from_system() as int % 10000000]
	var r := await http("POST", "/v1/auth/register", {"username": user, "email": user + "@test.com", "password": "password123"})
	var token := str(r.get("access_token", ""))
	var p := PlayerProfile.new()
	var c := await http("POST", "/v1/characters", {"server_id": 1, "slot": 0, "name": "B" + user.substr(2), "data": p.to_dict()}, token)
	print("User: %s | Token: %s | Char: %s" % [user, token.substr(0, 10), c])
	var b := BotClient.new()
	b.set_meta("token", token)
	var ws_url: String = "wss://kiem-hiep-api.viettheo.site/ws/field/0"
	b.start(HOST, PORT, token, int(c.get("id", 0)), false, ws_url)
	_bots.append(b)
	await wait_until(func() -> bool: return b.in_world or b.error_code != "", 10.0)
	return b

func http(method: String, path: String, body: Dictionary, token := "") -> Dictionary:
	for attempt in 15:
		var h := HTTPRequest.new()
		add_child(h)
		var headers := ["Content-Type: application/json"]
		if token != "":
			headers.append("Authorization: Bearer " + token)
		var json_str := JSON.stringify(body) if not body.is_empty() else ""
		var err := h.request(API + path, headers, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET, json_str)
		if err != OK:
			h.queue_free()
			await sleep(0.5)
			continue
		var res: Array = await h.request_completed
		h.queue_free()
		var status: int = res[1]
		if status == 429:
			await sleep(1.0)
			continue
		var raw: PackedByteArray = res[3]
		var parsed = JSON.parse_string(raw.get_string_from_utf8())
		return parsed if parsed is Dictionary else {}
	return {}

func field(b: BotClient, op: int, args: Dictionary) -> Dictionary:
	var from := b.field_msgs.size()
	b.field(op, args)
	await wait_until(func() -> bool: return b.field_msgs.size() > from, 6.0)
	for i in range(from, b.field_msgs.size()):
		var m: Dictionary = b.field_msgs[i]
		if m.get("op") in ["room", "reject"]:
			return m
	return {}

static func sees_player(b: BotClient, other: BotClient) -> bool:
	return b.known.has(other.eid)

func run() -> void:
	print("--- BẮT ĐẦU TEST SĂN BOSS 2 NGƯỜI CHƠI ---")
	print("Kết nối tới: %s:%d (API: %s)" % [HOST, PORT, API])
	
	var a := await make_bot("a")
	var b := await make_bot("b")
	check("2 bot kết nối thành công tới field server", a.in_world and b.in_world, [a.error_message, b.error_message])
	if not (a.in_world and b.in_world):
		return

	await sleep(0.5)
	check("Lúc ở sảnh chờ: 2 bot chưa vào phòng, không thấy nhau", not sees_player(a, b) and not sees_player(b, a))

	# Bot A vào Boss Huyền Giác Đại Sư (ID 740, Map 320)
	var boss_args := {
		"boss_id": 740,
		"map_id": 320,
		"boss_name": "Huyền Giác Đại Sư"
	}
	var room_a := await field(a, FieldServer.OP_BOSS, boss_args)
	var id_a := str(room_a.get("id", ""))
	check("Bot A vào map Boss thành công -> nhận phòng Boss", room_a.get("op") == "room" and bool(room_a.get("is_boss", false)), room_a)
	check("Thông tin phòng Boss có tên boss chuẩn", str(room_a.get("boss_name", "")) == "Huyền Giác Đại Sư", room_a.get("boss_name"))

	# Bot B cũng bấm Vào Săn Boss Huyền Giác Đại Sư
	var room_b := await field(b, FieldServer.OP_BOSS, boss_args)
	var id_b := str(room_b.get("id", ""))
	check("Bot B vào map Boss thành công", room_b.get("op") == "room" and bool(room_b.get("is_boss", false)), room_b)
	check("Bot B vào CÙNG PHÒNG với Bot A (không phòng chờ, vào trực tiếp)", id_a == id_b and id_a != "", "ID A: %s | ID B: %s" % [id_a, id_b])

	# Chờ AOI đồng bộ và 2 bot thấy nhau
	var both_see := await wait_until(func() -> bool: return sees_player(a, b) and sees_player(b, a), 6.0)
	check("2 người chơi CÙNG THẤY NHAU ngay trong map Boss", both_see)

	# Kiểm tra toạ độ spawn: không bị văng ra hư không (grey void)
	check("Bot A toạ độ hợp lệ (không phải (0,0) hay toạ độ map 1)", a.feet.length() > 100.0, a.feet)
	check("Bot B toạ độ hợp lệ gần Bot A", a.feet.distance_to(b.feet) < 1500.0, "Dist: %f" % a.feet.distance_to(b.feet))

	# Kiểm tra thấy quái Boss xuất hiện
	var sees_boss := await wait_until(func() -> bool:
		for eid in a.known:
			var e: Dictionary = a.known[eid]
			if int(e.get("kind", -1)) == NetProto.KIND_MONSTER:
				return true
		return false
	, 6.0)
	check("Bot A nhìn thấy Boss trên máy chủ", sees_boss)
	
	print("--- TEST HOÀN TẤT ---")

extends Node
## LOAD TEST: tạo N tài khoản + nhân vật bot rồi cho vào map cùng lúc, mỗi bot đi lang thang quanh điểm xuất phát (rải ra
## bán kính SPREAD), thỉnh thoảng đánh quái gần, thỉnh thoảng chat kênh gần. Đo ở phía bot: byte nhận / giây, số gói, trễ ping.
## Đo ở phía server: dòng "[đo] ..." trong log game server (thời gian tick, KB/s gửi đi).
##
## Chạy (account server + game server đã bật; nên đặt RATE_LIMIT_IP_PER_MIN cao ở server/.env khi tạo nhiều bot):
##   godot --headless --path . res://net/tools/load_test.tscn -- --bots=200 --seconds=60 [--port=7777]
## Phòng train chung (field server, cổng 7807): --field — cứ FIELD_ROOM bot 1 phòng (bot đầu tạo phòng map FIELD_MAP, các bot sau
## vào bằng ID), mỗi bot đi lang thang trong map phòng mình.
## Tài khoản bot DÙNG LẠI giữa các lần chạy (lt_<số>: đăng nhập trước, chưa có mới đăng ký) — không đẻ thêm tài khoản rác; bị giới hạn
## tốc độ (HTTP 429) thì chờ rồi thử lại.

const API := "http://127.0.0.1:8080"
const SPREAD := 2500.0             ## px quanh điểm xuất phát
const STEP := 22.0                 ## px mỗi bước (15 bước/giây ~ 330 px/s)

var bots: Array[BotClient] = []
var _goals: Array[Vector2] = []
var _home := Vector2.ZERO
var _n := 100
var _seconds := 60.0
var _done := 0
var _port := 7777
var _field := false
const FIELD_ROOM := 8
const FIELD_MAP := 121             ## Long Môn Trấn (1x, nhiều quái nhất danh mục)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bots="):
			_n = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--port="):
			_port = int(arg.get_slice("=", 1))
		elif arg == "--field":
			_field = true
			if _port == 7777:
				_port = 7807
	print("Load test: %d bot, %d giây, cổng %d%s" % [_n, _seconds, _port, " (phòng train chung)" if _field else ""])
	var tag := ""
	## Tạo tài khoản song song (tối đa 20 yêu cầu cùng lúc).
	var started := 0
	while _done < _n:
		while started < _n and started - _done < 20:
			_spawn(tag, started)
			started += 1
		await get_tree().process_frame
	print("  đã tạo %d / %d bot" % [bots.size(), _n])
	var t := 0.0
	while t < 15.0 and bots.any(func(b: BotClient) -> bool: return not b.in_world and b.error_code == ""):
		await get_tree().process_frame
		t += get_process_delta_time()
	var inside := bots.filter(func(b: BotClient) -> bool: return b.in_world)
	print("Vào map: %d / %d (lỗi: %s)" % [inside.size(), bots.size(), _errors()])
	if inside.is_empty():
		get_tree().quit(1)
		return
	_home = inside[0].feet
	if _field:
		await _enter_rooms(inside)
	await _run()
	get_tree().quit()

## Chạy nền: tạo tài khoản + nhân vật rồi cho bot kết nối.
func _spawn(tag: String, i: int) -> void:
	var info: Array = await _make(tag, i)
	if int(info[1]) > 0:
		var b := BotClient.new()
		b.start("127.0.0.1", _port, info[0], info[1])
		bots.append(b)
		_goals.append(Vector2.INF)
	_done += 1

func _make(tag: String, i: int) -> Array:
	var user := "lt%s_%d" % [tag, i]
	var r := await _http(HTTPClient.METHOD_POST, "/v1/auth/login", {"username": user, "password": "matkhau1"})
	if str(r.get("access_token", "")) == "":
		r = await _http(HTTPClient.METHOD_POST, "/v1/auth/register", {"username": user, "email": user + "@load.test", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	if token == "":
		return ["", 0]
	var list := await _http(HTTPClient.METHOD_GET, "/v1/characters?server_id=1", {}, token)
	for ch in list.get("characters", []):
		return [token, int(ch.get("id", 0))]
	var p := PlayerProfile.new()
	var sects := SectRegistry.get_by_element(i % 5 as ElementTypes.ElementType)
	p.set_sect(sects[0])
	var c := await _http(HTTPClient.METHOD_POST, "/v1/characters", {"server_id": 1, "slot": 0, "name": "Bot LT %d" % i, "data": p.to_dict()}, token)
	return [token, int(c.get("id", 0))]

func _http(method: int, path: String, body: Dictionary, token := "") -> Dictionary:
	for attempt in 30:
		var h := HTTPRequest.new()
		add_child(h)
		var headers := ["Content-Type: application/json"]
		if token != "":
			headers.append("Authorization: Bearer " + token)
		h.request(API + path, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(body))
		var res: Array = await h.request_completed
		h.queue_free()
		if int(res[1]) == 429:   ## giới hạn tốc độ theo IP: chờ rồi thử lại
			await get_tree().create_timer(2.0).timeout
			continue
		var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
		return d if d is Dictionary else {}
	return {}

## --field: bot đầu mỗi nhóm FIELD_ROOM tạo phòng, các bot sau vào bằng ID; điểm lang thang = chỗ xuất phát trong map phòng.
func _enter_rooms(inside: Array) -> void:
	var rooms := 0
	for g in range(0, inside.size(), FIELD_ROOM):
		var host: BotClient = inside[g]
		var n := host.field_msgs.size()
		host.field(FieldServer.OP_CREATE, {"map_id": FIELD_MAP, "tier": 0})
		var t := 0.0
		while host.field_msgs.size() == n and t < 5.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		var id := str(host.field_msgs.back().get("id", "")) if host.field_msgs.size() > n else ""
		if id == "":
			continue
		rooms += 1
		for k in range(g + 1, mini(g + FIELD_ROOM, inside.size())):
			(inside[k] as BotClient).field(FieldServer.OP_JOIN, {"room": id, "map_id": FIELD_MAP, "tier": 0})
	await get_tree().create_timer(1.5).timeout
	_home = inside[0].feet
	print("Phòng train chung: %d phòng, mỗi phòng tối đa %d bot" % [rooms, FIELD_ROOM])

func _errors() -> String:
	var counts := {}
	for b in bots:
		if b.error_code != "":
			counts[b.error_code] = int(counts.get(b.error_code, 0)) + 1
	return str(counts)

func _process(_d: float) -> void:
	for b in bots:
		b.poll()

func _run() -> void:
	var elapsed := 0.0
	var step_timer := 0.0
	var report := 0.0
	var start_states := _sum_states()
	while elapsed < _seconds:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		elapsed += dt
		step_timer += dt
		report += dt
		if step_timer >= 1.0 / 15.0:
			step_timer = 0.0
			for i in bots.size():
				_step(i)
		if report >= 10.0:
			report = 0.0
			var st := _sum_states()
			print("  [bot] %.0f s: %d trong map, %d bản tin vị trí/giây (cả nhóm), lỗi %s" % [
				elapsed, bots.filter(func(b: BotClient) -> bool: return b.in_world and not b.closed).size(), (st - start_states) / 10, _errors()])
			start_states = st
	for b in bots:
		b.close()

func _sum_states() -> int:
	var n := 0
	for b in bots:
		n += b.states_received
	return n

## 1 bước của bot i: đi tới đích ngẫu nhiên; tới nơi chọn đích mới; đôi khi đánh quái gần / chat.
func _step(i: int) -> void:
	var b := bots[i]
	if not b.in_world or b.closed:
		return
	if _goals[i] == Vector2.INF or b.feet.distance_to(_goals[i]) < STEP * 2.0:
		_goals[i] = _home + Vector2(randf_range(-SPREAD, SPREAD), randf_range(-SPREAD, SPREAD))
	var d := _goals[i] - b.feet
	b.move_to(b.feet + d.limit_length(STEP), "run", int(fposmod(d.angle() / (PI / 4.0) - 2.0, 8.0)))
	if b.corrections > 3:
		b.corrections = 0
		_goals[i] = Vector2.INF   ## vướng vật cản: đổi hướng
	if randf() < 0.01:
		var m := b.nearest_monster()
		if m != 0 and (b.known[m].pos as Vector2).distance_to(b.feet) < 300.0:
			b.damage(m, 50)
	if randf() < 0.0005:
		b.say(ChatServer.NEAR, "luyện công cùng nhau nào")

extends Node
## LOAD TEST: tạo N tài khoản + nhân vật bot rồi cho vào map cùng lúc, mỗi bot đi lang thang quanh điểm xuất phát (rải ra
## bán kính SPREAD), thỉnh thoảng đánh quái gần, thỉnh thoảng chat kênh gần. Đo ở phía bot: byte nhận / giây, số gói, trễ ping.
## Đo ở phía server: dòng "[đo] ..." trong log game server (thời gian tick, KB/s gửi đi).
##
## Chạy (account server + game server đã bật; nên đặt RATE_LIMIT_IP_PER_MIN cao ở server/.env khi tạo nhiều bot):
##   godot --headless --path . res://net/tools/load_test.tscn -- --bots=200 --seconds=60

const API := "http://127.0.0.1:8080"
const SPREAD := 2500.0             ## px quanh điểm xuất phát
const STEP := 22.0                 ## px mỗi bước (15 bước/giây ~ 330 px/s)

var bots: Array[BotClient] = []
var _goals: Array[Vector2] = []
var _home := Vector2.ZERO
var _n := 100
var _seconds := 60.0
var _done := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bots="):
			_n = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
	print("Load test: %d bot, %d giây" % [_n, _seconds])
	var tag := "%d" % (Time.get_unix_time_from_system() as int % 100000)
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
	await _run()
	get_tree().quit()

## Chạy nền: tạo tài khoản + nhân vật rồi cho bot kết nối.
func _spawn(tag: String, i: int) -> void:
	var info: Array = await _make(tag, i)
	if int(info[1]) > 0:
		var b := BotClient.new()
		b.start("127.0.0.1", 7777, info[0], info[1])
		bots.append(b)
		_goals.append(Vector2.INF)
	_done += 1

func _make(tag: String, i: int) -> Array:
	var user := "lt%s_%d" % [tag, i]
	var r := await _http(HTTPClient.METHOD_POST, "/v1/auth/register", {"username": user, "email": user + "@load.test", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	if token == "":
		return ["", 0]
	var p := PlayerProfile.new()
	var sects := SectRegistry.get_by_element(i % 5 as ElementTypes.ElementType)
	p.set_sect(sects[0])
	var c := await _http(HTTPClient.METHOD_POST, "/v1/characters", {"server_id": 1, "slot": 0, "name": "Bot %s %d" % [tag, i], "data": p.to_dict()}, token)
	return [token, int(c.get("id", 0))]

func _http(method: int, path: String, body: Dictionary, token := "") -> Dictionary:
	var h := HTTPRequest.new()
	add_child(h)
	var headers := ["Content-Type: application/json"]
	if token != "":
		headers.append("Authorization: Bearer " + token)
	h.request(API + path, headers, method, JSON.stringify(body))
	var res: Array = await h.request_completed
	h.queue_free()
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return d if d is Dictionary else {}

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

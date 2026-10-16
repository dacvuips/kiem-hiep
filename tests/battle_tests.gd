extends Node
## Kiểm thử CHIẾN TRƯỜNG TỐNG KIM (BattleServer) với bot thật qua ENet. Cần chạy sẵn server tài khoản + battle server, trận rút ngắn:
##   GAME_TEST_MODE=1 GAME_BATTLE_SIGNUP=50 GAME_BATTLE_FIGHT=110 GAME_BATTLE_MIN_LEVEL=1 GAME_BATTLE_MARSHAL_LIFE=100000 GODOT=... bash server/run_battle_server.sh
##   (hoặc đơn giản: bash server/dev.sh test --battle)
## rồi: godot --headless --path . res://tests/battle_tests.tscn   (BATTLE_API / GAME_ENET_PORT đổi địa chỉ nếu cần)
## Chạy ngay sau khi bật battle server (đang báo danh). In PASS/FAIL, cuối cùng "RESULT x/y".

var API := OS.get_environment("BATTLE_API") if OS.has_environment("BATTLE_API") else "http://127.0.0.1:8080"
const HOST := "127.0.0.1"
var PORT := int(OS.get_environment("GAME_ENET_PORT")) if OS.has_environment("GAME_ENET_PORT") else 7787

var _pass := 0
var _fail := 0
var _bots: Array[BotClient] = []
var _data: Dictionary = {}
var _area_of := {}                 ## phe -> khu "1" / "2" (server bốc thăm, gói "joined")

## Dữ liệu doanh trại của phe `side` trong trận này.
func side_data(side: String) -> Dictionary:
	return _data["areas"][_area_of[side]]

func camp_rect(side: String) -> Rect2:
	var r: Array = side_data(side)["camp_rect"]
	return Rect2(r[0], r[1], r[2], r[3])

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
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle/map_378.json"))
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

func last_op(b: BotClient, op: String) -> Dictionary:
	for i in range(b.battle_msgs.size() - 1, -1, -1):
		if b.battle_msgs[i].get("op") == op:
			return b.battle_msgs[i]
	return {}

## Báo danh phe `side`, chờ server trả "joined" hoặc "reject" (gói mới sau lần gửi này).
func join(b: BotClient, side: String) -> Dictionary:
	var n := b.battle_msgs.size()
	b.battle(BattleServer.OP_JOIN, {"side": side})
	await wait_until(func() -> bool:
		for i in range(n, b.battle_msgs.size()):
			if b.battle_msgs[i].get("op") in ["joined", "reject"]:
				return true
		return false, 5.0)
	for i in range(n, b.battle_msgs.size()):
		if b.battle_msgs[i].get("op") in ["joined", "reject"]:
			var m: Dictionary = b.battle_msgs[i]
			if m.get("op") == "joined":
				_area_of[str(m["side"])] = str(m["area"])
			return m
	return {}

func make_bot(tag: String) -> Array:
	var user := "tk%s%d" % [tag, Time.get_unix_time_from_system() as int % 10000000]
	var r := await http("POST", "/v1/auth/register", {"username": user, "email": user + "@example.com", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	var p := PlayerProfile.new()
	var c := await http("POST", "/v1/characters", {"server_id": 1, "slot": 0, "name": "TK " + user.substr(2), "data": p.to_dict()}, token)
	var b := BotClient.new()
	b.start(HOST, PORT, token, int(c.get("id", 0)))
	_bots.append(b)
	await wait_until(func() -> bool: return b.in_world or b.error_code != "", 8.0)
	return [b, token]

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

## Đi theo đường A* trên lưới vật cản của map (MapGrid, ô 32x16) tới gần `to`, mỗi bước ≈ tốc độ chạy.
func walk(b: BotClient, to: Vector2, stop_within := 300.0, timeout := 45.0) -> bool:
	var grid := MapGrid.load_from("res://world/maps/map_378")
	var a := grid.world_to_cell(b.feet)
	var z := grid.world_to_cell(to)
	var lo := Vector2i(mini(a.x, z.x), mini(a.y, z.y)) - Vector2i(60, 120)
	var hi := Vector2i(maxi(a.x, z.x), maxi(a.y, z.y)) + Vector2i(60, 120)
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(lo, hi - lo)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for x in range(lo.x, hi.x):
		for y in range(lo.y, hi.y):
			if grid.is_blocked(grid.cell_to_world(Vector2i(x, y))):
				astar.set_point_solid(Vector2i(x, y))
	var path := astar.get_id_path(a, z, true)
	var t := 0.0
	var stops := range(0, path.size(), 2)
	if path.size() > 0 and stops[-1] != path.size() - 1:
		stops.append(path.size() - 1)   ## luôn tới ô cuối (ô cổng)
	for i in stops:
		var target := grid.cell_to_world(path[i])
		while b.feet.distance_to(target) > 1.0 and t < timeout:
			var step := (target - b.feet).limit_length(34.0)
			var sent := b.feet + step
			b.move_to(sent)
			await sleep(0.08)
			t += 0.08
			if b.feet.distance_to(sent) > 200.0:   ## server dịch chuyển (qua cổng) -> dừng
				return b.feet.distance_to(to) <= stop_within
		if b.feet.distance_to(to) <= stop_within or t >= timeout:
			break
	return b.feet.distance_to(to) <= stop_within

## Ô cổng hậu doanh đi tới được (không nằm trên vật cản), gần điểm hậu doanh nhất.
func _trap_point(side: String) -> Vector2:
	var grid := MapGrid.load_from("res://world/maps/map_378")
	var h: Array = side_data(side)["home"][0]
	var home := Vector2(h[0], h[1])
	var best := Vector2.INF
	for p in side_data(side)["home_trap"]:
		var v := grid.cell_to_world(grid.world_to_cell(Vector2(p[0], p[1])))
		if not grid.is_blocked(v) and (best == Vector2.INF or v.distance_to(home) < best.distance_to(home)):
			best = v
	return best

func _near_home(b: BotClient, side: String, within := 400.0) -> bool:
	for p in side_data(side)["home"]:
		if b.feet.distance_to(Vector2(p[0], p[1])) <= within:
			return true
	return false

## Đi tới ô cổng hậu doanh phe mình, chờ server dịch chuyển sang đại doanh (vị trí nhảy xa).
func exit_home(b: BotClient, side: String) -> bool:
	var trap := _trap_point(side)
	var c0 := b.corrections
	await walk(b, trap, 8.0, 15.0)
	await wait_until(func() -> bool: return b.corrections > c0 and b.feet.distance_to(trap) > 300.0, 3.0)
	return b.feet.distance_to(trap) > 300.0 and not _near_home(b, side)

func _count_mid(b: BotClient, mid: String) -> int:
	var n := 0
	for it in b.profile.get("inventory", []):
		if str(it.get("mid", "")) == mid:
			n += maxi(1, int(it.get("count", 1)))
	return n

func _monster_eid(b: BotClient, tpl: int) -> int:
	for id in b.known:
		if int(b.known[id].get("monster_id", -1)) == tpl:
			return int(id)
	return 0

func run() -> void:
	var s: Array[BotClient] = []
	var token := ""
	for i in 6:
		var r := await make_bot("s%d" % i)
		s.append(r[0])
		token = r[1]
	var j: BotClient = (await make_bot("j"))[0]
	check("bot vào battle server", s.all(func(b: BotClient) -> bool: return b.in_world) and j.in_world, j.error_message)

	var st := await http("GET", "/v1/battle?server_id=1", {}, token)
	check("/v1/battle mở, đang báo danh, map 378", bool(st.get("open", false)) and st.get("phase") == "signup" and int(st.get("map_id", 0)) == 378, st)

	## Phe Tống vào 5 người khi Kim 0 người: người thứ 6 bị từ chối vì lệch quân (>= 5).
	for i in 5:
		var m := await join(s[i], "song")
		check("Tống thứ %d vào được" % (i + 1), m.get("op") == "joined", m)
	var rej := await join(s[5], "song")
	check("Tống thứ 6 bị từ chối vì lệch quân", rej.get("op") == "reject" and str(rej.get("message", "")).contains("cách biệt"), rej)
	check("bị từ chối nhưng vẫn đứng ngoài trận", s[5].battle_state.is_empty())
	var mj := await join(j, "jin")
	check("Kim vào được", mj.get("op") == "joined", mj)
	check("vào trận -> đưa về khu trại Kim", camp_rect("jin").has_point(j.feet), j.feet)
	var spam := await join(s[5], "song")
	check("bấm lại trong 10 giây bị chặn", spam.get("op") == "reject" and str(spam.get("message", "")).contains("giây"), spam)
	await sleep(10.2)
	var ok6 := await join(s[5], "song")
	check("hết 10 giây, Kim đã có người -> Tống thứ 6 vào được", ok6.get("op") == "joined", ok6)
	var switch := await join(s[0], "jin")
	check("đã báo danh Tống thì không đổi sang Kim", switch.get("op") == "reject" and str(switch.get("message", "")).contains("đổi phe"), switch)

	## Lúc báo danh: ra khỏi doanh trại bị kéo lại.
	var before := s[0].corrections
	var home := s[0].feet
	var out := Vector2(camp_rect("song").end.x + 200.0, home.y)
	s[0].move_to(home + (out - home).normalized() * 30.0)
	await sleep(0.2)
	var inside_ok := s[0].corrections == before
	for k in 200:
		s[0].move_to(s[0].feet + Vector2(34, 0))
		await sleep(0.08)
		if s[0].corrections > before or not camp_rect("song").grow(-20).has_point(s[0].feet):
			break
	check("đi trong trại được", inside_ok)
	check("chưa khai chiến: ra khỏi trại bị kéo lại", s[0].corrections > before and camp_rect("song").has_point(s[0].feet), s[0].feet)

	await sleep(3.5)
	st = await http("GET", "/v1/battle?server_id=1", {}, token)
	check("/v1/battle đếm đúng số người mỗi phe (Tống 6, Kim 1)", int(st.get("song", -1)) == 6 and int(st.get("jin", -1)) == 1, st)

	## Quân nhu quan (lúc báo danh, trong hậu doanh): cần tiền -> /testgold (GAME_TEST_MODE=1).
	var buyer := s[1]
	buyer.say(ChatServer.NEAR, "/testgold 100000")
	await wait_until(func() -> bool: return int(buyer.profile.get("gold", 0)) >= 100000, 4.0)
	var gold0 := int(buyer.profile.get("gold", 0))
	var doc: Array = side_data("song")["doctor"]
	await walk(buyer, Vector2(doc[0], doc[1]), 250.0, 20.0)
	buyer.battle(BattleServer.OP_BUY, {"mid": "1_0_0_1", "count": 3})
	var bought := await wait_until(func() -> bool: return _count_mid(buyer, "1_0_0_1") == 3, 4.0)
	check("Quân nhu quan: mua 3 Kim Sáng Dược (tiểu)", bought, [buyer.notices.slice(-2), buyer.feet])
	check("Quân nhu quan: trừ đúng tiền (3 x 50)", int(buyer.profile.get("gold", 0)) == gold0 - 150, [gold0, buyer.profile.get("gold")])

	## Khai chiến.
	var fought := await wait_until(func() -> bool: return j.battle_state.get("phase") == "fight", 90.0)
	check("tới giờ thì khai chiến", fought, j.battle_state)
	## Hậu doanh là khu kín: ra bằng ô cổng (server dịch chuyển sang đại doanh).
	var out_s := await exit_home(s[0], "song")
	var out_j := await exit_home(j, "jin")
	check("khai chiến: bước vào cổng hậu doanh -> sang đại doanh (Tống, Kim)", out_s and out_j, [s[0].feet, j.feet])
	var n_far := s[0].notices.size()
	s[0].battle(BattleServer.OP_BUY, {"mid": "1_0_0_1", "count": 1})
	await wait_until(func() -> bool: return s[0].notices.size() > n_far, 3.0)
	check("Quân nhu quan: ở xa thì không mua được", s[0].notices.size() > n_far and str(s[0].notices[-1]).contains("đến gần"), s[0].notices.slice(n_far))

	## Nguyên Soái: 2 phe bằng điểm (0:0) -> cả 2 xuất hiện ở đại doanh. Tống và Kim cùng tới chỗ Nguyên Soái Tống.
	var g: Array = side_data("song")["general"]
	var general := Vector2(g[0], g[1])
	await walk(s[0], general, 500.0, 30.0)
	var reached := out_j and await walk(j, general, 700.0, 60.0)
	check("Kim ra chiến trường đi tới đại doanh Tống", reached, [j.feet, general])
	var marshal_tpl: int = BattleServer.MARSHAL_TPL["song"]
	var seen := await wait_until(func() -> bool: return _monster_eid(j, marshal_tpl) != 0, 70.0)
	check("tới giờ Nguyên Soái Tống xuất hiện ở đại doanh", seen, j.notices.slice(-3))
	var mk := _monster_eid(j, marshal_tpl)
	if seen:
		## AI gốc: ngoài tầm chiêu thì mỗi lần nghĩ chỉ 20% tiến tới (ai_param) -> đứng sát để Nguyên Soái ra chiêu.
		await walk(j, j.known[mk]["pos"], 150.0, 10.0)
		var hit_me := await wait_until(func() -> bool: return j.attacked_by.has(mk), 30.0)
		check("Nguyên Soái Tống tấn công người phe Kim", hit_me)
		check("Nguyên Soái Tống không tấn công người phe Tống", not s[0].attacked_by.has(mk))
		for k in 60:   ## người Tống đánh Nguyên Soái phe mình: server bỏ qua
			s[0].damage(mk, 9999)
			await sleep(0.04)
		await sleep(0.6)
		check("người Tống không đánh được Nguyên Soái phe mình", int(j.known.get(mk, {}).get("hp", 0)) == 100, j.known.get(mk))
		var killed := false
		for k in 900:
			j.damage(mk, 9999)
			await sleep(0.04)
			if int(j.known.get(mk, {}).get("hp", 100)) == 0 or not j.known.has(mk):
				killed = true
				break
		check("người Kim hạ được Nguyên Soái Tống", killed, j.known.get(mk))
		var avg := (6 + 1) / 2.0
		var want := BattleServer.NPC_RANK6_POINTS + floori((1.0 - (1 - avg) / avg) * BattleServer.MARSHAL_POINTS)
		var got_pts := await wait_until(func() -> bool: return int(j.battle_state.get("me", {}).get("points", 0)) == want, 4.0)
		check("hạ Nguyên Soái: +30 + 1000 x hệ số phe ít người (= %d)" % want, got_pts, j.battle_state.get("me"))

	## PvP: người Tống hạ người Kim.
	if reached:
		await walk(j, s[0].feet, 600.0, 20.0)
		s[0].pvp_hit(j.eid, 500, 600)
		await wait_until(func() -> bool: return not j.pvp_hits.is_empty(), 3.0)
		check("Tống đánh trúng Kim (đòn chuyển tới máy bị đánh)", not j.pvp_hits.is_empty())
		j.dead = true
		j.move_to(j.feet)
		var scored := await wait_until(func() -> bool: return int(s[0].battle_state.get("me", {}).get("points", 0)) == BattleServer.KILL_POINTS, 4.0)
		check("hạ người phe kia +%d điểm cho người hạ" % BattleServer.KILL_POINTS, scored, s[0].battle_state)
		check("người chết bị tính 1 lần chết", int(j.battle_state.get("me", {}).get("deaths", 0)) == 1, j.battle_state)
		var c0 := j.corrections
		j.revive()
		await wait_until(func() -> bool: return j.corrections > c0, 3.0)
		check("Về thành dưỡng sức -> về hậu doanh phe Kim", _near_home(j, "jin"), j.feet)
		var n0 := j.notices.size()
		await walk(j, _trap_point("jin"), 8.0, 6.0)
		await sleep(0.3)
		var refused := j.notices.size() > n0 and str(j.notices[-1]).contains("rời khỏi hậu doanh")
		check("mới hồi sinh: cổng hậu doanh chưa cho ra (%d giây)" % int(BattleServer.REVIVE_PROTECT), refused and _near_home(j, "jin", 1500.0), [j.feet, j.notices.slice(n0)])

	var ended := await wait_until(func() -> bool: return not last_op(j, "result").is_empty(), 170.0)
	var res := last_op(j, "result")
	check("hết giờ: phe hạ Nguyên Soái phe kia thắng (Kim) dù ít điểm hơn", ended and res.get("winner") == "jin", res)
	var mult := BattleServer.reward_multiplier()
	var wk := BattleServer.weekend_multiplier()
	var jr: Dictionary = res.get("reward", {})
	var j_pts := int(res.get("me", {}).get("points", 0))
	check("thưởng phe thắng: điểm tích lũy = (1200 + điểm trận) x hệ số", int(jr.get("points", -1)) == (BattleServer.WIN_POINTS * mult + j_pts) * wk, jr)
	check("thưởng phe thắng: +danh vọng và 1 vật phẩm", int(jr.get("repute", 0)) == BattleServer.WIN_REPUTE * mult and str(jr.get("item", "")) != "", jr)
	## Mỗi bot nhận gói kết quả riêng — chờ cả bên thua (không thì đọc lúc gói của s[0] chưa tới: test chập chờn).
	await wait_until(func() -> bool: return not last_op(s[0], "result").is_empty(), 5.0)
	var sr: Dictionary = last_op(s[0], "result").get("reward", {})
	check("thưởng phe thua: điểm tích lũy = (600 + điểm trận) x hệ số, không có vật phẩm", int(sr.get("points", -1)) == (BattleServer.LOSE_POINTS * mult + BattleServer.KILL_POINTS) * wk and not sr.has("item"), sr)
	var saved_pts := await wait_until(func() -> bool: return int(s[0].profile.get("songjin_points", 0)) == int(sr.get("total", -2)), 4.0)
	check("điểm tích lũy nằm trong nhân vật (S_PROFILE)", saved_pts, [s[0].profile.get("songjin_points"), sr])

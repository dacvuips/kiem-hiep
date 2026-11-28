extends Node
## Bot người chơi phía server qua MẠNG THẬT (bước 1): server thế giới thử chạy GAME_TEST_MODE=1 (server/test.sh: cổng 7977).
##   GAME_ENET_PORT=7977 godot --headless --path . res://tests/bot_online_tests.tscn
## Bot client gõ "/testbot thien_vuong_bang 90" -> server sinh 1 bot cạnh mình: bot hiện ra như người chơi khác, chạy tới, ra chiêu
## (S_CAST), đòn tới máy mình (S_PVP_HIT); mình đánh lại (C_PVP_HIT) -> server tính đòn, máu bot giảm, tới chết.

var API := OS.get_environment("BOT_API") if OS.has_environment("BOT_API") else "http://127.0.0.1:8080"
const HOST := "127.0.0.1"
var PORT := int(OS.get_environment("GAME_ENET_PORT")) if OS.has_environment("GAME_ENET_PORT") else 7977

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

func http(path: String, body: Dictionary, token := "") -> Dictionary:
	for attempt in 30:
		var h := HTTPRequest.new()
		add_child(h)
		var headers := ["Content-Type: application/json"]
		if token != "":
			headers.append("Authorization: Bearer " + token)
		h.request(API + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
		var res: Array = await h.request_completed
		h.queue_free()
		if int(res[1]) == 429:
			await get_tree().create_timer(2.0).timeout
			continue
		var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
		return d if d is Dictionary else {}
	return {}

func run() -> void:
	var user := "bt%d" % (Time.get_unix_time_from_system() as int % 10000000)
	var r := await http("/v1/auth/register", {"username": user, "email": user + "@example.com", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	var c := await http("/v1/characters", {"server_id": 1, "slot": 0, "name": "BT " + user.substr(2), "data": PlayerProfile.new().to_dict()}, token)
	var me := BotClient.new()
	me.start(HOST, PORT, token, int(c.get("id", 0)), false)
	_bots.append(me)
	check("Vào map", await wait_until(func() -> bool: return me.in_world, 8.0), me.error_message)
	await wait_until(func() -> bool: return not me.profile.is_empty(), 5.0)
	me.say(0, "/testlevel 200")
	await get_tree().create_timer(1.0).timeout

	var n := me.notices.size()
	me.say(0, "/testbot thien_vuong_bang 90")
	await wait_until(func() -> bool: return me.notices.slice(n).any(func(t): return str(t).begins_with("testbot ")), 5.0)
	var note: String = ""
	for t in me.notices.slice(n):
		if str(t).begins_with("testbot "):
			note = str(t)
	var bot_eid := int(note.get_slice(" ", 1)) if note != "" else 0
	check("Server sinh bot", bot_eid > 0, me.notices.slice(n))
	if bot_eid == 0:
		return
	check("Bot hiện ra như 1 người chơi khác", await wait_until(func() -> bool: return me.known.has(bot_eid), 4.0)
		and int(me.known[bot_eid].kind) == NetProto.KIND_PLAYER, me.known.get(bot_eid))
	var start: Vector2 = me.known[bot_eid].pos if me.known.has(bot_eid) else Vector2.ZERO
	await wait_until(func() -> bool: return me.known.has(bot_eid) and (me.known[bot_eid].pos as Vector2).distance_to(start) > 5.0, 4.0)
	check("Bot chạy tới mình (vị trí đổi)", me.known.has(bot_eid) and (me.known[bot_eid].pos as Vector2).distance_to(start) > 5.0)
	check("Bot ra chiêu, mình thấy hình ảnh (S_CAST)", await wait_until(func() -> bool: return me.casts.any(func(x): return int(x.caster) == bot_eid), 8.0))
	check("Đòn của bot tới máy mình (S_PVP_HIT)", await wait_until(func() -> bool: return me.pvp_hits.any(func(x): return int(x.from) == bot_eid), 6.0))
	var hit: Dictionary = {}
	for x in me.pvp_hits:
		if int(x.from) == bot_eid:
			hit = x.hit
	check("Gói đòn hợp lệ, có sát thương", not hit.is_empty() and int(hit.get("max", 0)) > 0, hit.get("max"))

	## Mình đánh lại bot
	var hp0 := int(me.known[bot_eid].get("hp", 100))
	for i in 60:
		var bp: Vector2 = me.known[bot_eid].pos if me.known.has(bot_eid) else me.feet
		if me.feet.distance_to(bp) > 60.0:
			me.move_to(me.feet + (bp - me.feet).limit_length(25.0))
		me.pvp_hit(bot_eid, 5000, 9000)
		await get_tree().create_timer(0.1).timeout
		if me.known.has(bot_eid) and int(me.known[bot_eid].get("hp", 100)) < hp0:
			break
	check("Mình đánh trúng bot: máu bot giảm (server tính đòn)", me.known.has(bot_eid) and int(me.known[bot_eid].get("hp", 100)) < hp0,
		[hp0, me.known.get(bot_eid, {}).get("hp")])
	for i in 300:
		if not me.known.has(bot_eid) or int(me.known[bot_eid].get("hp", 100)) == 0:
			break
		var bp: Vector2 = me.known[bot_eid].pos
		if me.feet.distance_to(bp) > 60.0:
			me.move_to(me.feet + (bp - me.feet).limit_length(25.0))
		me.pvp_hit(bot_eid, 5000, 9000)
		await get_tree().create_timer(0.1).timeout
	await wait_until(func() -> bool: return me.known.has(bot_eid) and (int(me.known[bot_eid].get("flags", 0)) & NetProto.FLAG_DEAD) != 0, 3.0)
	check("Bot chết: máu 0 + cờ chết", me.known.has(bot_eid) and int(me.known[bot_eid].get("hp", 1)) == 0, me.known.get(bot_eid))
	var hits_at_death := me.pvp_hits.size()
	await get_tree().create_timer(2.0).timeout
	check("Bot chết rồi không đánh nữa", me.pvp_hits.size() == hits_at_death)

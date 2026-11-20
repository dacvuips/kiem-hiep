extends Node
## ĐO BOT QUA MẠNG THẬT: độ trễ (ping), độ mượt (nhịp cập nhật vị trí bot người chơi thấy, bước giật), tải server (tick, băng thông)
## và hành vi ("độ thông minh": ra chiêu, trúng, né, nhảy, thuốc, buff, hạ gục theo độ khó) — 2 mức: 20 bot rồi 60 bot hỗn chiến.
## Cần server thế giới thử GAME_TEST_MODE=1 (lệnh /testbots, /testbotstats) + server tài khoản:
##   GAME_ENET_PORT=7977 godot --headless --path . res://tests/bot_bench_tests.tscn
## In bảng số liệu + PASS/FAIL theo ngưỡng, cuối "RESULT x/y".

var API := OS.get_environment("BOT_API") if OS.has_environment("BOT_API") else "http://127.0.0.1:8080"
const HOST := "127.0.0.1"
var PORT := int(OS.get_environment("GAME_ENET_PORT")) if OS.has_environment("GAME_ENET_PORT") else 7977
var OBSERVE_SEC := float(OS.get_environment("BOT_BENCH_SEC")) if OS.has_environment("BOT_BENCH_SEC") else 30.0

var _pass := 0
var _fail := 0
var me: BotClient

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name, "  ", detail)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func _process(_d: float) -> void:
	if me:
		me.poll()

func _ready() -> void:
	await run()
	if me:
		me.close()
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

func _notice_after(n: int, prefix: String) -> String:
	for t in me.notices.slice(n):
		if str(t).begins_with(prefix):
			return str(t)
	return ""

## Quan sát `sec` giây: ping mỗi 0,5 giây; theo dõi vị trí mọi bot đang thấy mỗi khung hình.
func observe(sec: float) -> Dictionary:
	me.pongs.clear()
	var casts0 := me.casts.size()
	var last_pos := {}       ## eid -> Vector2
	var last_t := {}         ## eid -> giây lần đổi vị trí trước
	var last_run := {}       ## eid -> lần cập nhật trước bot đang chạy
	var was_dead := {}       ## eid -> lần trước đang chết (bước dịch chỗ lúc hồi sinh không phải giật)
	var stops := 0           ## số lần đang chạy thì dừng
	var intervals: Array = []
	var big_steps := 0
	var steps := 0
	var t := 0.0
	var ping_in := 0.0
	var start_ms := Time.get_ticks_msec()
	while t < sec:
		await get_tree().process_frame
		var now := (Time.get_ticks_msec() - start_ms) / 1000.0
		t = now
		ping_in -= get_process_delta_time()
		if ping_in <= 0.0:
			ping_in = 0.5
			me.ping()
		for eid in me.known:
			var k: Dictionary = me.known[eid]
			if int(k.get("kind", 0)) != NetProto.KIND_PLAYER or eid == me.eid:
				continue
			var p: Vector2 = k.pos
			var dead := (int(k.get("flags", 0)) & NetProto.FLAG_DEAD) != 0
			var running := int(k.get("action", 0)) == NetProto.action_index("run")
			if not running:
				if bool(last_run.get(eid, false)):
					stops += 1   ## đang chạy thì dừng (đứng / ra chiêu / ngồi)
				last_run[eid] = false   ## đứng giữa chừng: đếm lại nhịp từ đầu
			if last_pos.has(eid) and p != last_pos[eid]:
				var d: float = p.distance_to(last_pos[eid])
				if not dead and not bool(was_dead.get(eid, false)) and d < 400.0:   ## (bỏ bước dịch chỗ do hồi sinh)
					steps += 1
					if d > 60.0:
						big_steps += 1   ## 1 lần cập nhật nhảy > 60px = giật
					## nhịp cập nhật khi bot CHẠY LIÊN TỤC (không có lúc đứng xen giữa)
					if running and bool(last_run.get(eid, false)) and now - float(last_t[eid]) < 1.0:
						intervals.append(now - float(last_t[eid]))
				last_run[eid] = running
				last_t[eid] = now
			elif not last_pos.has(eid):
				last_t[eid] = now
			last_pos[eid] = p
			was_dead[eid] = dead
	var pongs: Array = me.pongs.duplicate()
	pongs.sort()
	var avg_ping := 0.0
	for x in pongs:
		avg_ping += float(x)
	avg_ping /= maxf(1.0, float(pongs.size()))
	intervals.sort()
	var avg_iv := 0.0
	for x in intervals:
		avg_iv += float(x)
	avg_iv /= maxf(1.0, float(intervals.size()))
	var jitter := 0.0
	for x in intervals:
		jitter += (float(x) - avg_iv) * (float(x) - avg_iv)
	jitter = sqrt(jitter / maxf(1.0, float(intervals.size())))
	return {"ping_avg": avg_ping, "ping_p95": float(pongs[int(pongs.size() * 0.95)]) if not pongs.is_empty() else -1.0,
		"ping_n": pongs.size(), "update_avg": avg_iv, "update_p95": float(intervals[int(intervals.size() * 0.95)]) if not intervals.is_empty() else -1.0,
		"jitter": jitter, "steps": steps, "big_steps": big_steps, "stops_per_bot_s": stops / maxf(1.0, float(last_pos.size())) / sec, "casts_per_s": (me.casts.size() - casts0) / sec,
		"bots_seen": last_pos.size()}

func stats() -> Dictionary:
	var n := me.notices.size()
	me.say(0, "/testbotstats")
	await wait_until(func() -> bool: return _notice_after(n, "botstats ") != "", 5.0)
	var s := _notice_after(n, "botstats ")
	var d: Variant = JSON.parse_string(s.substr(9)) if s != "" else null
	return d if d is Dictionary else {}

func spawn(n: int) -> bool:
	var k := me.notices.size()
	me.say(0, "/testbots %d -1" % n)
	return await wait_until(func() -> bool: return _notice_after(k, "testbots ") != "", 10.0)

func report(label: String, o: Dictionary, st: Dictionary) -> void:
	print("==== %s ====" % label)
	print("  Độ trễ (ping khứ hồi): tb %.1f ms, p95 %.1f ms (%d mẫu)" % [o.ping_avg, o.ping_p95, o.ping_n])
	print("  Độ mượt: thấy %d bot, lúc chạy cập nhật vị trí tb %.0f ms / lần (p95 %.0f ms, lệch chuẩn %.0f ms), %d bước, %d bước giật > 60px, chạy-dừng %.2f lần / bot / giây" % [
		o.bots_seen, o.update_avg * 1000.0, o.update_p95 * 1000.0, o.jitter * 1000.0, o.steps, o.big_steps, o.stops_per_bot_s])
	print("  Server: tick tb %.2f ms, max %.2f ms (ngân sách 55,6 ms), gửi %.1f KB/s; hình ảnh chiêu người xem nhận %.1f lần/giây" % [
		float(st.get("tick_avg", -1)), float(st.get("tick_max", -1)), float(st.get("kbs", -1)), o.casts_per_s])
	var names := {"0": "Dễ", "1": "Thường", "2": "Khó"}
	for key in ["0", "1", "2"]:
		var r: Dictionary = st.get("by_diff", {}).get(key, {})
		if r.is_empty():
			continue
		var nb := maxf(1.0, float(r.bots))
		print("  %-6s %2d bot | /bot: ra chiêu %.0f, trúng %.0f (%.0f%%), sát thương %.0f, bị nhận %.0f, hạ %.1f, né %.1f, nhảy %.1f, thuốc %.1f, buff %.1f" % [
			names[key], int(r.bots), r.casts / nb, r.hits / nb, 100.0 * float(r.hits) / maxf(1.0, float(r.casts)), r.dmg / nb, r.taken / nb,
			r.kills / nb, r.dodges / nb, r.jumps / nb, r.potions / nb, r.buffs / nb])
	print("  Số lần bị hạ (cả trận): %d" % int(st.get("deaths", 0)))

func run() -> void:
	var user := "bb%d" % (Time.get_unix_time_from_system() as int % 10000000)
	var r := await http("/v1/auth/register", {"username": user, "email": user + "@example.com", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	var c := await http("/v1/characters", {"server_id": 1, "slot": 0, "name": "BB " + user.substr(2), "data": PlayerProfile.new().to_dict()}, token)
	me = BotClient.new()
	me.start(HOST, PORT, token, int(c.get("id", 0)), false)
	check("Vào map", await wait_until(func() -> bool: return me.in_world, 8.0), me.error_message)
	await wait_until(func() -> bool: return not me.profile.is_empty(), 5.0)
	## Không bot nào: đo độ trễ nền
	var base := await observe(5.0)
	print("  Độ trễ nền (chưa có bot): tb %.1f ms, p95 %.1f ms" % [base.ping_avg, base.ping_p95])

	for step in [[20, "20 bot hỗn chiến"], [40, "60 bot hỗn chiến"]]:
		check("Sinh %d bot" % step[0], await spawn(int(step[0])))
		await get_tree().create_timer(3.0).timeout
		var o := await observe(OBSERVE_SEC)
		var st := await stats()
		report(str(step[1]), o, st)
		var total := 20 if step[0] == 20 else 60
		check("[%s] độ trễ tb < 50 ms" % step[1], o.ping_avg >= 0.0 and o.ping_avg < 50.0, o.ping_avg)
		check("[%s] bot đang chạy cập nhật đều (tb <= 80 ms / lần, server gửi ~56 ms)" % step[1], o.update_avg > 0.0 and o.update_avg <= 0.08, o.update_avg)
		check("[%s] gần như không giật (bước > 60px < 2%%)" % step[1], o.steps > 0 and float(o.big_steps) / float(o.steps) < 0.02, [o.big_steps, o.steps])
		check("[%s] server tick tb < %d ms" % [step[1], 10 if total == 20 else 25], float(st.get("tick_avg", 999)) < (10.0 if total == 20 else 25.0), st.get("tick_avg"))
		check("[%s] server tick max trong ngân sách 55,6 ms" % step[1], float(st.get("tick_max", 999)) < 55.6, st.get("tick_max"))
		var all := {"casts": 0, "hits": 0, "dodges": 0, "jumps": 0, "potions": 0, "buffs": 0}
		for key in st.get("by_diff", {}):
			for k in all:
				all[k] += int(st.by_diff[key].get(k, 0))
		check("[%s] bot đánh nhau thật (ra chiêu, trúng, có người bị hạ)" % step[1], all.casts > 0 and all.hits > 0 and int(st.get("deaths", 0)) > 0, [all, st.get("deaths")])
		check("[%s] bot dùng đủ kỹ năng người: né, nhảy, uống thuốc, buff" % step[1], all.dodges > 0 and all.jumps > 0 and all.potions > 0 and all.buffs > 0, all)
	var st2 := await stats()
	var e: Dictionary = st2.get("by_diff", {}).get("0", {})
	var h: Dictionary = st2.get("by_diff", {}).get("2", {})
	var e_k := float(e.get("kills", 0)) / maxf(1.0, float(e.get("bots", 1)))
	var h_k := float(h.get("kills", 0)) / maxf(1.0, float(h.get("bots", 1)))
	check("Bot Khó hạ nhiều hơn bot Dễ (trung bình / bot)", h_k > e_k, [h_k, e_k])

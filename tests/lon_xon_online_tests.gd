extends Node
## Kiểm thử LỘN XỘN ONLINE (LonXonServer trên server thế giới) với bot thật qua ENet. Cần server tài khoản + 1 server thế giới thử
## chạy với LONXON_TEST_SPAWN=1 (mọi người vào sát tâm khung host — server/test.sh tự bật ở cổng 7967):
##   GAME_ENET_PORT=7967 godot --headless --path . res://tests/lon_xon_online_tests.tscn
## Luồng: bot ở Hub xem host + giữ chỗ -> nối lại kết nối thường -> vào host với hồ sơ tạm cấp 50 -> chọn thẻ 5x -> hạ quái +5 cấp
## (rơi đồ theo bảng Lộn Xộn) -> giao dịch bị chặn -> B chết: rớt hết đồ + Lệnh Bài -> hồi sinh sớm bị từ chối, đủ 5 giây thì hồi sinh
## -> A nhặt Lệnh Bài -> bảng Top 5 -> rời host -> về Hub hồ sơ thật còn nguyên. In PASS/FAIL, cuối cùng "RESULT x/y".

var API := OS.get_environment("LONXON_API") if OS.has_environment("LONXON_API") else "http://127.0.0.1:8080"
const HOST := "127.0.0.1"
var PORT := int(OS.get_environment("GAME_ENET_PORT")) if OS.has_environment("GAME_ENET_PORT") else 7967

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

func http(method: String, path: String, body: Dictionary, token := "") -> Dictionary:
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

func make_account(tag: String) -> Dictionary:
	var user := "lx%s%d" % [tag, Time.get_unix_time_from_system() as int % 10000000]
	var r := await http("POST", "/v1/auth/register", {"username": user, "email": user + "@example.com", "password": "matkhau1"})
	var token := str(r.get("access_token", ""))
	var p := PlayerProfile.new()
	p.sect_id = "thieu_lam"
	var c := await http("POST", "/v1/characters", {"server_id": 1, "slot": 0, "name": "LX " + user.substr(2), "data": p.to_dict()}, token)
	return {"token": token, "cid": int(c.get("id", 0))}

func connect_bot(acc: Dictionary, hub: bool) -> BotClient:
	var b := BotClient.new()
	b.start(HOST, PORT, str(acc.token), int(acc.cid), hub)
	_bots.append(b)
	await wait_until(func() -> bool: return b.in_world or b.error_code != "", 8.0)
	return b

## Nhân vật mới vào map lần đầu (quà tân thủ) rồi thoát — như người chơi thật trước khi vào Hub. Trả về cấp thật.
func first_visit(acc: Dictionary) -> int:
	var b := await connect_bot(acc, false)
	await wait_until(func() -> bool: return not b.profile.is_empty(), 5.0)
	var lv := int(b.profile.get("level", 0))
	b.close()
	_bots.erase(b)
	await sleep(1.5)
	return lv

func lx(b: BotClient, op: int, args: Dictionary, ops: Array, timeout := 6.0) -> Dictionary:
	var n := b.lonxon_msgs.size()
	b.lonxon(op, args)
	await wait_until(func() -> bool: return _msg(b, n, ops) != {}, timeout)
	return _msg(b, n, ops)

static func _msg(b: BotClient, from: int, ops: Array) -> Dictionary:
	for i in range(from, b.lonxon_msgs.size()):
		if str(b.lonxon_msgs[i].get("op")) in ops:
			return b.lonxon_msgs[i]
	return {}

static func last(b: BotClient, op: String) -> Dictionary:
	for i in range(b.lonxon_msgs.size() - 1, -1, -1):
		if str(b.lonxon_msgs[i].get("op")) == op:
			return b.lonxon_msgs[i]
	return {}

func _walk(p: BotClient, to: Vector2) -> void:
	for i in 300:
		var d := to - p.feet
		if d.length() < 10.0:
			return
		p.move_to(p.feet + d.limit_length(25.0))
		await get_tree().create_timer(1.0 / 15.0).timeout

func _walk_to_monsters(p: BotClient) -> bool:
	for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		for i in 60:
			p.move_to(p.feet + dir * 25.0)
			await get_tree().create_timer(1.0 / 15.0).timeout
			if p.nearest_monster() != 0:
				return true
	return false

func _kill(b: BotClient, m: int) -> void:
	for i in 300:
		if not b.known.has(m) or int(b.known[m].get("hp", 100)) == 0:
			return
		b.damage(m, 100000)
		await get_tree().create_timer(0.04).timeout

static func _items(b: BotClient) -> int:
	return (b.profile.get("inventory", []) as Array).size() + (b.profile.get("equipment", {}) as Dictionary).size()

func run() -> void:
	var accs: Array = []
	for t in ["a", "b", "c", "d"]:
		accs.append(await make_account(t))
	var start_levels: Array = []
	for acc in accs:
		start_levels.append(await first_visit(acc))
	check("4 nhân vật mới vào map lần đầu", start_levels.all(func(l): return int(l) > 0), start_levels)

	## --- 1. Hub: xem host + giữ chỗ ---
	var ha := await connect_bot(accs[0], true)
	var hb := await connect_bot(accs[1], true)
	var hc := await connect_bot(accs[2], true)
	var hd := await connect_bot(accs[3], true)
	check("4 bot nối sảnh (Hub)", [ha, hb, hc, hd].all(func(x: BotClient) -> bool: return x.in_world))
	var hosts := await lx(ha, LonXonServer.OP_STATE, {}, ["hosts"])
	check("Hub thấy 5 host, mỗi host tối đa 50", (hosts.get("hosts", []) as Array).size() == 5 and int(hosts.hosts[0].cap) == 50, hosts)
	var ma := await lx(ha, LonXonServer.OP_JOIN, {"host": 2}, ["match", "reject"])
	var mb := await lx(hb, LonXonServer.OP_JOIN, {"host": 2}, ["match", "reject"])
	var mc := await lx(hc, LonXonServer.OP_JOIN, {"host": 3}, ["match", "reject"])
	check("A, B giữ chỗ host 2; C host 3", str(ma.get("op")) == "match" and int(ma.get("host", 0)) == 2 and int(mb.get("rid", 0)) == int(ma.get("rid", -1))
		and int(mc.get("host", 0)) == 3, [ma, mb, mc])
	if str(ma.get("op")) != "match":
		return
	var box := Rect2(float(ma.box[0]), float(ma.box[1]), float(ma.box[2]), float(ma.box[3]))
	check("Khung host 140x80 region", box.size == Vector2(140 * 512, 80 * 512), box)
	var bad := await lx(hd, LonXonServer.OP_JOIN, {"host": 9}, ["match", "reject"])
	check("Host không tồn tại -> từ chối", str(bad.get("op")) == "reject", bad)
	var counted := await lx(hd, LonXonServer.OP_STATE, {}, ["hosts"])
	check("Hub đếm 2 người ở host 2", int(counted.hosts[1].players) == 2, counted)

	## --- 2. Vào host bằng kết nối thường ---
	var real_inv := ha.inventory_uids()
	for x in [ha, hb, hc]:
		x.close()
	_bots = _bots.filter(func(x: BotClient) -> bool: return not [ha, hb, hc].has(x))
	await sleep(1.0)
	var fa := await connect_bot(accs[0], false)
	var fb := await connect_bot(accs[1], false)
	var fc := await connect_bot(accs[2], false)
	var fighters: Array[BotClient] = [fa, fb, fc]
	check("3 bot vào host", fighters.all(func(x: BotClient) -> bool: return x.in_world), fighters.map(func(x): return x.error_message))
	await wait_until(func() -> bool: return fighters.all(func(x: BotClient) -> bool: return not x.profile.is_empty() and last(x, "match") != {}), 6.0)
	check("Điểm vào nằm trong khung host", box.has_point(fa.feet) and box.has_point(fb.feet), [fa.feet, fb.feet])
	check("Hồ sơ trong host: cấp 50, 245 điểm tiềm năng", int(fa.profile.get("level", 0)) == 50 and int(fa.profile.get("potential_points", 0)) == 245,
		[fa.profile.get("level"), fa.profile.get("potential_points")])
	var inv: Array = fa.profile.get("inventory", [])
	check("Hồ sơ trong host: tay trắng + 10 Hồi Thiên", inv.size() == 1 and str(inv[0].get("mid", "")) == "1_8_0_4" and int(inv[0].get("count", 0)) == 10
		and (fa.profile.get("equipment", {}) as Dictionary).is_empty(), [inv, fa.profile.get("equipment")])
	await wait_until(func() -> bool: return fa.known.has(fb.eid), 4.0)
	check("Cùng host thấy nhau", fa.known.has(fb.eid))
	check("Khác host không thấy nhau", not fa.known.has(fc.eid) and not fc.known.has(fa.eid))

	## --- 3. Chọn thẻ 5x ---
	fa.lonxon(LonXonServer.OP_DRAFT, {"horse": 2, "weapon": 0})
	await wait_until(func() -> bool: return (fa.profile.get("equipment", {}) as Dictionary).size() >= 2, 4.0)
	var eq: Dictionary = fa.profile.get("equipment", {})
	var wpn: ItemInstance = null
	for k in eq:
		var it := ItemInstance.from_dict(eq[k])
		if it.get_base().get("detail", -1) == ItemDatabase.Detail.MELEE:
			wpn = it
	check("Thẻ 5x: server trang bị ngựa + kiếm cấp 5", eq.size() >= 2 and wpn != null and int(wpn.get_base().get("level", 0)) == 5, eq.keys())

	## --- 4. Hạ quái: +5 cấp, rơi đồ theo bảng Lộn Xộn ---
	var saw := await wait_until(func() -> bool: return fa.nearest_monster() != 0, 3.0) or await _walk_to_monsters(fa)
	check("Có quái trong host", saw, fa.known.size())
	if saw:
		var m := fa.nearest_monster()
		await _walk(fa, (fa.known[m].pos as Vector2) + Vector2(30, 0))
		var drops_before := fa.drops.size()
		await _kill(fa, m)
		await wait_until(func() -> bool: return last(fa, "level") != {}, 4.0)
		check("Hạ quái: +5 cấp (55)", int(last(fa, "level").get("level", 0)) == 55 and int(fa.profile.get("level", 0)) == 55,
			[last(fa, "level"), fa.profile.get("level")])
		await wait_until(func() -> bool: return fa.drops.size() > drops_before, 3.0)
		var has_potion := false
		var equip_n := 0
		for id in fa.drops:
			var it: Dictionary = fa.drops[id].get("item", {})
			if str(it.get("mid", "")) == "1_8_0_4":
				has_potion = true
			elif not it.is_empty() and str(it.get("mid", "")) == "":
				equip_n += 1
		check("Quái rơi 1 Hồi Thiên + 3–5 trang bị", has_potion and equip_n >= 3, [has_potion, equip_n, fa.drops.size()])

	## --- 5. Giao dịch với người trong host bị chặn ---
	var d_notes := hd.notices.size()
	var trade := NetProto.writer(NetProto.C_TRADE_REQ_ID)
	trade.put_u32(int(accs[0].cid))
	hd._send(trade, NetProto.CH_RELIABLE)
	await wait_until(func() -> bool: return hd.notices.size() > d_notes, 4.0)
	check("Giao dịch với người trong Lộn Xộn bị chặn", hd.notices.size() > d_notes and str(hd.notices.back()).contains("Lộn Xộn"), hd.notices.slice(d_notes))

	## --- 6. B chết cạnh A: rớt hết đồ + Lệnh Bài ---
	fb.lonxon(LonXonServer.OP_DRAFT, {"horse": 1, "weapon": 1})
	await wait_until(func() -> bool: return (fb.profile.get("equipment", {}) as Dictionary).size() >= 2, 4.0)
	await _walk(fb, fa.feet + Vector2(40, 0))
	var b_items := _items(fb)
	var a_drops_before := fa.drops.duplicate()
	fb.dead = true
	fb.move_to(fb.feet)
	await wait_until(func() -> bool: return last(fb, "died") != {}, 4.0)
	var died := last(fb, "died")
	check("B chết: báo chờ 5 giây", float(died.get("respawn_in", 0)) == 5.0, died)
	check("B chết: rớt %d món + 1 Lệnh Bài" % b_items, int(died.get("items", -1)) == b_items and int(died.get("tokens", 0)) == 1, died)
	await wait_until(func() -> bool: return _items(fb) == 0, 3.0)
	check("B chết: hồ sơ trống", _items(fb) == 0, fb.profile.get("inventory"))
	var found: Array = []   ## (lambda không gán được biến ngoài -> dùng mảng)
	await wait_until(func() -> bool:
		for id in fa.drops:
			if not a_drops_before.has(id) and str(fa.drops[id].get("item", {}).get("mid", "")) == LonXonRules.TOKEN_ITEM_ID:
				found.append(id)
				return true
		return false, 4.0)
	var token_id: int = int(found[0]) if not found.is_empty() else 0
	check("A thấy Lệnh Bài + đồ của B dưới đất", token_id != 0 and fa.drops.size() - a_drops_before.size() == b_items + 1,
		[token_id, fa.drops.size() - a_drops_before.size()])

	## --- 7. Hồi sinh: sớm bị từ chối, đủ 5 giây thì được ---
	var corr := fb.corrections
	fb.revive()
	await sleep(1.0)
	check("Hồi sinh sớm (chưa đủ 5 giây) bị từ chối", fb.corrections == corr and last(fb, "respawn") == {})
	await sleep(4.5)
	fb.revive()
	await wait_until(func() -> bool: return last(fb, "respawn") != {}, 4.0)
	check("Đủ 5 giây: hồi sinh", last(fb, "respawn") != {})
	await wait_until(func() -> bool: return fb.corrections > corr, 2.0)
	check("Hồi sinh trong khung host", box.has_point(fb.feet), fb.feet)
	await wait_until(func() -> bool: return (fb.profile.get("inventory", []) as Array).size() == 1, 3.0)
	check("Hồi sinh: được lại 10 Hồi Thiên", (fb.profile.get("inventory", []) as Array).size() == 1
		and int(fb.profile.inventory[0].get("count", 0)) == 10, fb.profile.get("inventory"))

	## --- 8. A nhặt Lệnh Bài -> 1000 điểm, đứng đầu bảng ---
	if token_id != 0:
		await _walk(fa, fa.drops[token_id].pos)
		var tn := fa.lonxon_msgs.size()
		fa.pickup(token_id)
		await wait_until(func() -> bool: return _msg(fa, tn, ["tokens"]) != {}, 4.0)
		var tk := _msg(fa, tn, ["tokens"])
		check("A nhặt Lệnh Bài: 1 cái = 1000 điểm", int(tk.get("n", 0)) == 1 and int(tk.get("score", 0)) == 1000, [tk, fa.notices.slice(-2)])
		check("Lệnh Bài không vào túi", not (fa.profile.get("inventory", []) as Array).any(func(it): return str(it.get("mid", "")) == LonXonRules.TOKEN_ITEM_ID))
		await wait_until(func() -> bool:
			var bd := last(fb, "board")
			return (bd.get("top", []) as Array).size() >= 1 and int(bd.top[0].get("eid", 0)) == fa.eid, 4.0)
		var board := last(fb, "board")
		check("Bảng Top 5 (B nhận): A đứng đầu 1000 điểm", (board.get("top", []) as Array).size() >= 1 and int(board.top[0].get("score", 0)) == 1000, board)
		check("Số hạng 1 của A + kích thước theo Lệnh Bài", int(board.get("badges", {}).get(str(fa.eid), 0)) == 1
			and int(board.get("sizes", {}).get(str(fa.eid), 0)) == 1, board)
		check("Host khác không nhận bảng host 2", not (last(fc, "board").get("top", []) as Array).any(func(e): return int(e.get("eid", 0)) == fa.eid))

	## --- 9. Rời host -> về Hub hồ sơ thật còn nguyên ---
	fa.lonxon(LonXonServer.OP_QUIT, {})
	await wait_until(func() -> bool: return fa.error_code == "lonxon_end" or fa.closed, 5.0)
	check("A rời host: server mời ra (lonxon_end)", fa.error_code == "lonxon_end", fa.error_code)
	for x in fighters:
		x.close()
	await sleep(2.0)
	var back := await connect_bot(accs[0], true)
	await wait_until(func() -> bool: return not back.profile.is_empty(), 5.0)
	check("Về Hub: cấp thật như trước (không phải 50/55)", int(back.profile.get("level", 0)) == int(start_levels[0]), [back.profile.get("level"), start_levels[0]])
	check("Về Hub: túi đồ thật còn nguyên", back.inventory_uids() == real_inv, [back.inventory_uids().size(), real_inv.size()])
	var again := await lx(back, LonXonServer.OP_STATE, {}, ["hosts", "board"])
	check("Về Hub: không còn kẹt trong host", str(again.get("op")) == "hosts", again)

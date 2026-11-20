extends "res://tests/net_tests.gd"
## Ủy thác ONLINE với server thật (bash server/dev.sh up): bot vào SẢNH như Character Hub, cộng KNB như công cụ GM (gửi hồ sơ — cần
## GAME_DEV_TRUST_CLIENT=1 máy dev), mua + dùng Bạch Câu Hoàn qua C_UY_THAC, rồi lùi mốc thoát game trong DB 2 giờ (docker compose exec
## postgres) và vào lại: server phải cộng EXP + trừ quỹ.
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/uy_thac_online_tests.tscn

const SERVER_REPO := "../kiem-hiep-server"

func uy_thac(b: BotClient, op: String, args := {}) -> void:
	var a: Dictionary = args.duplicate()
	a["op"] = op
	var w := NetProto.writer(NetProto.C_UY_THAC)
	NetProto.put_str(w, JSON.stringify(a))
	b._send(w, NetProto.CH_RELIABLE)

func _notice_has(b: BotClient, text: String) -> bool:
	for n in b.notices:
		if str(n).contains(text):
			return true
	return false

func _count(b: BotClient, mid: String) -> Array:   ## [tổng số viên, uid đầu tiên]
	var n := 0
	var uid := ""
	for it in b.profile.get("inventory", []):
		if it is Dictionary and str(it.get("mid", it.get("misc_id", ""))) == mid:
			n += int(it.get("count", 1))
			if uid == "":
				uid = str(it.get("uid", ""))
	return [n, uid]

## Lùi mốc thoát game của nhân vật trong DB (như thể đã rời `secs` giây).
func _rewind_seen(character_id: int, secs: int) -> bool:
	var sql := "UPDATE characters SET data = jsonb_set(data, '{uy_thac_seen}', to_jsonb((data->>'uy_thac_seen')::bigint - %d)) WHERE id = %d" % [secs, character_id]
	var out := []
	var code := OS.execute("docker", ["compose", "--project-directory", ProjectSettings.globalize_path("res://").path_join(SERVER_REPO),
		"exec", "-T", "postgres", "psql", "-U", "kiemhiep", "-d", "kiemhiep", "-c", sql], out, true)
	print("  psql: ", str(out).strip_edges())
	return code == 0 and str(out).contains("UPDATE 1")

func run() -> void:
	await test_buy_use_settle()
	await test_four_characters()

## Hồ sơ đã LƯU trong DB (danh sách nhân vật của tài khoản): id -> {level (cột), exp, data_level, bank}.
func _saved(token: String) -> Dictionary:
	var r := await http("GET", "/v1/characters?server_id=1", {}, token)
	var out := {}
	for c in r.get("characters", []):
		var d: Dictionary = c.get("data", {})
		out[int(c.id)] = {"level": int(c.get("level", 0)), "data_level": int(d.get("level", 0)), "exp": int(d.get("exp", 0)),
			"bank": UyThac.bank_secs(PlayerProfile.from_dict(d))}
	return out

## Vào sảnh bằng nhân vật `cid` (cùng tài khoản: server đá phiên cũ nếu còn).
func _enter(token: String, cid: int) -> BotClient:
	var b := bot(token, cid)
	b.start(HOST, PORT, token, cid, true)
	await wait_until(func() -> bool: return b.in_world and not b.profile.is_empty(), 8.0)
	return b

## 1 tài khoản 4 nhân vật: chỉ nhân vật ô 2 dùng Bạch Câu Hoàn -> rời 2 giờ, vào lại: CHỈ nhân vật đó được cộng EXP (cả lúc vào lại
## lẫn bản đã lưu trong DB), 3 nhân vật kia giữ nguyên EXP / cấp, không có thông báo ủy thác.
func test_four_characters() -> void:
	var user := "uyt%d" % (Time.get_unix_time_from_system() as int % 10000000)
	var reg := await http("POST", "/v1/auth/register", {"username": user, "email": user + "@example.com", "password": "matkhau1"})
	var token := str(reg.get("access_token", ""))
	var ids: Array[int] = []
	for slot in 4:
		var p := PlayerProfile.new()
		p.set_sect(SectRegistry.get_by_element(ElementTypes.ElementType.KIM)[0])
		var c := await http("POST", "/v1/characters", {"server_id": 1, "slot": slot, "name": "U%s%d" % [user.substr(3), slot], "data": p.to_dict()}, token)
		ids.append(int(c.get("id", 0)))
	check("4 nhân vật: tạo đủ 4 ô", token != "" and not ids.has(0), ids)
	if ids.has(0):
		return
	var target := ids[2]
	# Mỗi nhân vật vào sảnh 1 lần (server ghi mốc); riêng ô 2 mua + dùng 1 Đại Bạch Câu hoàn.
	for cid in ids:
		var b := await _enter(token, cid)
		if cid == target:
			var p: Dictionary = b.profile.duplicate(true)
			p["jade"] = 100
			b.send_profile(p)
			await get_tree().create_timer(1.0).timeout
			uy_thac(b, "buy", {"mid": "6_1_130", "n": 1})
			await wait_until(func() -> bool: return int(_count(b, "6_1_130")[0]) == 1, 4.0)
			uy_thac(b, "use", {"uid": _count(b, "6_1_130")[1]})
			check("4 nhân vật: ô 2 dùng Bạch Câu Hoàn (+8 giờ)", await wait_until(func() -> bool:
				return int((b.profile.get("uy_thac_bank", {}) as Dictionary).get("1.5", 0)) == 8 * 3600, 4.0), b.profile.get("uy_thac_bank"))
		b.close()
		await get_tree().create_timer(2.0).timeout   ## server lưu lần cuối
	var before := await _saved(token)
	check("4 nhân vật: chỉ ô 2 có giờ ủy thác", int(before[target].bank) == 8 * 3600
		and ids.all(func(cid: int) -> bool: return cid == target or int(before[cid].bank) == 0), before)
	# Cả 4 cùng "rời game" 2 giờ.
	var all_ok := true
	for cid in ids:
		all_ok = _rewind_seen(cid, 2 * 3600) and all_ok
	check("4 nhân vật: lùi mốc 2 giờ cả 4", all_ok)
	# Vào lại lần lượt.
	for cid in ids:
		var b := await _enter(token, cid)
		await get_tree().create_timer(1.5).timeout
		var got := _notice_has(b, "Ủy thác")
		var lv := int(b.profile.get("level", 0))
		var ex := int(b.profile.get("exp", 0))
		var changed: bool = lv != int(before[cid].data_level) or ex != int(before[cid].exp)
		if cid == target:
			check("4 nhân vật: ô 2 vào lại có thông báo + được cộng EXP (exp %d -> %d)" % [int(before[cid].exp), ex], got and changed, b.notices)
		else:
			check("4 nhân vật: ô %d KHÔNG được cộng gì" % ids.find(cid), not got and not changed, [b.notices, lv, ex, before[cid]])
		b.close()
		await get_tree().create_timer(2.0).timeout
	# Bản đã lưu trong DB (cái màn Danh sách nhân vật / Hub đọc).
	var after := await _saved(token)
	for cid in ids:
		var slot := ids.find(cid)
		if cid == target:
			check("DB: ô 2 đã lưu EXP mới + quỹ còn ~6 giờ", (int(after[cid].exp) > int(before[cid].exp) or int(after[cid].data_level) > int(before[cid].data_level))
				and int(after[cid].bank) <= 6 * 3600 and int(after[cid].bank) > 6 * 3600 - 120
				and int(after[cid].level) == int(after[cid].data_level), [before[cid], after[cid]])
		else:
			check("DB: ô %d giữ nguyên EXP / cấp" % slot, int(after[cid].exp) == int(before[cid].exp)
				and int(after[cid].data_level) == int(before[cid].data_level), [before[cid], after[cid]])

func test_buy_use_settle() -> void:
	var info := await make_player("u")
	var token: String = info[0]
	var cid: int = info[1]
	check("Tạo tài khoản + nhân vật", token != "" and cid > 0, info)
	var a := bot(token, cid)
	a.hub = true
	a.start(HOST, PORT, token, cid, true)
	if not await wait_until(func() -> bool: return a.in_world and not a.profile.is_empty(), 8.0):
		check("Bot vào sảnh", false)
		return
	check("Bot vào sảnh", true)

	# Mua khi chưa có KNB: bị từ chối, có thông báo (server mới hiểu lệnh).
	uy_thac(a, "buy", {"mid": "6_1_130", "n": 1})
	check("Không đủ KNB: server báo lỗi", await wait_until(func() -> bool: return _notice_has(a, "Không đủ KNB"), 4.0), a.notices)

	# GM cộng 1000 KNB (sửa hồ sơ rồi gửi lên — máy dev tin hồ sơ game).
	var p: Dictionary = a.profile.duplicate(true)
	p["jade"] = 1000
	a.send_profile(p)
	await get_tree().create_timer(1.0).timeout
	uy_thac(a, "buy", {"mid": "6_1_130", "n": 2})
	check("Mua 2 Đại Bạch Câu hoàn bằng KNB GM cho", await wait_until(func() -> bool: return _notice_has(a, "Đã mua 2"), 4.0), a.notices)
	check("Server trừ 20 KNB", await wait_until(func() -> bool: return int(a.profile.get("jade", 0)) == 980, 3.0), a.profile.get("jade"))
	var have := _count(a, "6_1_130")
	check("Hành trang có 2 viên (1 chồng, có uid)", int(have[0]) == 2 and str(have[1]) != "", have)

	uy_thac(a, "use", {"uid": have[1]})
	check("Dùng 1 viên: +8 giờ ủy thác", await wait_until(func() -> bool:
		return int((a.profile.get("uy_thac_bank", {}) as Dictionary).get("1.5", 0)) == 8 * 3600, 4.0), a.profile.get("uy_thac_bank"))
	check("Còn 1 viên", int(_count(a, "6_1_130")[0]) == 1, _count(a, "6_1_130"))
	var level_before := int(a.profile.get("level", 0))
	var exp_before := int(a.profile.get("exp", 0))

	# Thoát game, lùi mốc 2 giờ, vào lại.
	a.close()
	await get_tree().create_timer(3.0).timeout   ## server lưu lần cuối
	check("Lùi mốc thoát game 2 giờ trong DB", _rewind_seen(cid, 2 * 3600))
	var b := bot(token, cid)
	b.start(HOST, PORT, token, cid, true)
	check("Vào lại: thông báo ủy thác", await wait_until(func() -> bool: return _notice_has(b, "Ủy thác 2 giờ"), 8.0), b.notices)
	## (vài giây chờ server lưu + vào lại cũng là thời gian đã rời game -> được tính thêm)
	check("Vào lại: quỹ còn ~6 giờ", await wait_until(func() -> bool:
		var left := int((b.profile.get("uy_thac_bank", {}) as Dictionary).get("1.5", 0))
		return left <= 6 * 3600 and left > 6 * 3600 - 60, 3.0), b.profile.get("uy_thac_bank"))
	var gained: bool = int(b.profile.get("level", 0)) > level_before or int(b.profile.get("exp", 0)) > exp_before
	check("Vào lại: được cộng EXP (cấp %d -> %d)" % [level_before, int(b.profile.get("level", 0))], gained,
		[b.profile.get("level"), b.profile.get("exp")])
	b.close()

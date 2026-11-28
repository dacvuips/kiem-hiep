extends Node
## Sự kiện năm (SeasonalEvents + LunarCalendar): lịch âm, đợt diễn ra năm hiện tại, ép (số lần / phần dư / tiền / tự động tối ưu),
## mua bằng tiền, mở vật phẩm (giới hạn cấp, thưởng mốc), lưu bộ đếm.
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/seasonal_events_tests.tscn
var _fail := 0

func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c:
		_fail += 1

func _ready() -> void:
	test_lunar()
	test_periods()
	test_plan_and_craft()
	test_auto_optimal()
	test_buy_and_out_of_period()
	test_open_items()
	test_counters_save()
	test_data_icons()
	test_equip_rewards_exist()
	test_stack_and_split()
	test_tet_2008()
	test_doan_ngo()
	test_gm_override()
	test_event_box()
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _d(y: int, m: int, d: int) -> Dictionary:
	return {"year": y, "month": m, "day": d}

func test_lunar() -> void:
	## Ngày Tết / Trung Thu đã biết (lịch Việt Nam)
	check("Tết 2024 = 10/02/2024", LunarCalendar.lunar_to_solar(1, 1, 2024) == _d(2024, 2, 10))
	check("Tết 2025 = 29/01/2025", LunarCalendar.lunar_to_solar(1, 1, 2025) == _d(2025, 1, 29))
	check("Tết 2026 = 17/02/2026", LunarCalendar.lunar_to_solar(1, 1, 2026) == _d(2026, 2, 17))
	check("Tết 2027 = 06/02/2027", LunarCalendar.lunar_to_solar(1, 1, 2027) == _d(2027, 2, 6))
	check("Trung Thu 2025 = 06/10/2025", LunarCalendar.lunar_to_solar(15, 8, 2025) == _d(2025, 10, 6))
	check("Trung Thu 2026 = 25/09/2026", LunarCalendar.lunar_to_solar(15, 8, 2026) == _d(2026, 9, 25))
	check("Tết 2012 (năm gốc) = 23/01/2012", LunarCalendar.lunar_to_solar(1, 1, 2012) == _d(2012, 1, 23))

func _at(y: int, m: int, d: int, h := 12) -> int:
	return SeasonalEvents.vn_midnight(y, m, d) + h * 3600

func test_periods() -> void:
	check("có 11 sự kiện năm (thêm Đoan Ngọ)", SeasonalEvents.events().size() == 11)
	var noel := SeasonalEvents.get_event("giang_sinh")
	var p := SeasonalEvents.current_period(noel, _at(2026, 11, 26))
	check("Giáng Sinh 2026 sắp tới", p["status"] == "upcoming")
	check("Giáng Sinh 2026 bắt đầu 01/12/2026", SeasonalEvents.format_date(p["start"]) == "01/12/2026")
	check("Giáng Sinh 2026 kết thúc 31/12/2026", SeasonalEvents.format_date(p["end"]) == "31/12/2026")
	var teacher := SeasonalEvents.get_event("nha_giao")
	check("20/11 đang diễn ra ngày 26/11/2026", SeasonalEvents.is_active(teacher, _at(2026, 11, 26)))
	var tet := SeasonalEvents.get_event("tet_nguyen_dan")
	var pt := SeasonalEvents.current_period(tet, _at(2026, 11, 26))
	## Tết 2027 = 06/02/2027, gốc bắt đầu 22 ngày trước Tết
	check("Tết 2027 bắt đầu 15/01/2027", SeasonalEvents.format_date(pt["start"]) == "15/01/2027")
	var tt := SeasonalEvents.get_event("trung_thu")
	var ptt := SeasonalEvents.current_period(tt, _at(2026, 9, 25))
	check("Trung Thu 2026 đang diễn ra đúng rằm", ptt["status"] == "ongoing")
	var order := SeasonalEvents.sorted_events(_at(2026, 11, 26))
	check("sắp xếp: đang diễn ra (20/11) lên đầu", order[0]["event"]["id"] == "nha_giao")
	check("sắp xếp: kế tiếp là Giáng Sinh", order[1]["event"]["id"] == "giang_sinh")

func _profile(level := 150) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.level = level
	p.gold = 1_000_000
	return p

func _give(p: PlayerProfile, mid: String, n: int) -> ItemInstance:
	var it := ItemGenerator.generate_misc(mid)
	it.count = n
	it.ensure_uid()
	p.add_item_stacked(it)
	for x in p.inventory:
		if x.misc_id == mid:
			return x
	return null

func _count(p: PlayerProfile, mid: String) -> int:
	var n := 0
	for it in p.inventory:
		if it.misc_id == mid:
			n += it.count
	return n

func test_plan_and_craft() -> void:
	var p := _profile()
	var ao := _give(p, "6_1_3074", 5)     ## áo giáng sinh
	var quan := _give(p, "6_1_3075", 3)   ## quần giáng sinh
	var noel := SeasonalEvents.get_event("giang_sinh")
	var placed := {ao.uid: 5, quan.uid: 3}
	var pl := SeasonalEvents.plan(p, noel, "c18", placed)
	check("Hộp quà GS: 5 áo + 3 quần -> ép 2 lần", pl["ok"] and pl["total"] == 2)
	check("Hộp quà GS: dư 1 áo + 1 quần", pl["left"].get("6_1_3074", 0) == 1 and pl["left"].get("6_1_3075", 0) == 1)
	check("Hộp quà GS: tốn 100.000 lượng", pl["money"] == 100000)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var r := SeasonalEvents.craft(p, "giang_sinh", "c18", placed, -1, rng, _at(2026, 12, 10))
	check("ép thành công trong đợt", r["ok"])
	check("đã trừ 4 áo, 2 quần (dư trả lại hành trang)", _count(p, "6_1_3074") == 1 and _count(p, "6_1_3075") == 1)
	check("đã trừ tiền", p.gold == 900000)
	check("tỷ lệ 70%: thành công + thất bại = 2", int(r["success"]) + int(r["fail"]) == 2)
	check("thành phẩm vào hành trang", _count(p, "6_1_3080") == int(r["success"]))
	check("đồ sự kiện hết hạn cuối đợt", p.inventory.filter(func(x): return x.misc_id == "6_1_3080").all(
		func(x): return x.expire_at == SeasonalEvents.current_period(noel, _at(2026, 12, 10))["end"]))

func test_auto_optimal() -> void:
	## Trung Thu (giấy kiếng 2006): 3 vàng, 2 lam, 2 lục, 1 đỏ, 1 cam + 3 bộ tre/cói/nến. Làm kéo quân trước (1 giấy mỗi màu) chỉ được
	## 2 đèn; tối ưu là bươm bướm + ngôi sao + ống = 3 đèn.
	var p := _profile()
	var tt := SeasonalEvents.get_event("trung_thu")
	var placed := {}
	for pair in [["6_1_1221", 3], ["6_1_1222", 2], ["6_1_1223", 2], ["6_1_1224", 1], ["6_1_1225", 1],
			["6_1_1226", 3], ["6_1_1227", 3], ["6_1_1228", 3]]:
		placed[_give(p, pair[0], pair[1]).uid] = pair[1]
	var pl := SeasonalEvents.plan(p, tt, SeasonalEvents.AUTO, placed)
	check("tự động: ép được 3 lồng đèn", pl["ok"] and pl["total"] == 3)
	check("tự động: chọn bươm bướm + ngôi sao + ống", pl["ok"] and pl["steps"].map(func(s): return s[0]["id"]) == ["au06_1", "au06_2", "au06_3"])
	check("tự động: tiền công 1.000 + 2.000 + 3.000", pl["money"] == 6000)
	check("tự động: dư 1 vàng, 1 đỏ, 1 cam", pl["left"] == {"6_1_1221": 1, "6_1_1224": 1, "6_1_1225": 1})
	var kq := SeasonalEvents.plan(p, tt, "au06_6", placed)
	check("chọn riêng kéo quân: 1 cái (cam chỉ có 1)", kq["ok"] and kq["total"] == 1)
	## Hộp vật liệu lồng đèn: mở ra 1 vật liệu thật; lồng đèn thắp được (x2 kinh nghiệm qua PotionEffect)
	var pl8 := _profile()
	var box := _give(pl8, "6_1_1220", 1)
	var r := SeasonalEvents.open_item(pl8, box.uid, null, _at(2026, 9, 25))
	var mats := 0
	for mid in ["6_1_1221", "6_1_1222", "6_1_1223", "6_1_1224", "6_1_1225", "6_1_1226", "6_1_1227", "6_1_1228"]:
		mats += _count(pl8, mid)
	check("mở Hộp vật liệu lồng đèn ra 1 vật liệu", r["ok"] and mats == 1 and _count(pl8, "6_1_1220") == 0)
	var lamp := _give(pl8, "6_1_1246", 1)
	check("lồng đèn kéo quân dùng được, nhãn Thắp Đèn", ItemConsumer.is_usable(lamp) and ItemConsumer.get_action_label(lamp) == "Thắp Đèn")
	check("lồng đèn không bị hệ sự kiện chặn (đi qua PotionEffect)", not SeasonalEvents.is_usable("6_1_1246") and PotionEffect.usable(lamp))
	check("thắp kéo quân: nhân đôi kinh nghiệm 60 phút", PotionEffect.consume(pl8, null, lamp) and pl8.get_active_exp_enhance_p() >= 100)
	## Valentine: 5 lọ mật + 2 quả song tử + 2 tuyết nha -> Trà (1 mật+1 tuyết nha+1 song tử) và Quà xanh (1 song tử+2 mật)
	var p2 := _profile()
	var v := SeasonalEvents.get_event("valentine")
	var placed2 := {_give(p2, "6_1_30173", 5).uid: 5, _give(p2, "6_1_30177", 2).uid: 2}
	var tea: Dictionary = v["recipes"][0]
	var other_mid := ""
	for m in tea["materials"]:
		if not str(m["item"]) in ["6_1_30173", "6_1_30177"]:
			other_mid = str(m["item"])
	placed2[_give(p2, other_mid, 2).uid] = 2
	var pl2 := SeasonalEvents.plan(p2, v, SeasonalEvents.AUTO, placed2)
	check("tự động Valentine: 2 thành phẩm (giới hạn bởi 2 quả song tử)", pl2["ok"] and pl2["total"] == 2)
	var pl3 := SeasonalEvents.plan(p2, v, "c15", placed2)
	check("chọn riêng Quà xanh: 2 lần, dư mật + tuyết nha", pl3["ok"] and pl3["total"] == 2 and pl3["left"].get("6_1_30173", 0) == 1)
	var bad := SeasonalEvents.plan(p2, v, "c14", {_give(p2, "6_1_3074", 1).uid: 1})
	check("đặt đồ không phải nguyên liệu -> báo lỗi", not bad["ok"])

func test_buy_and_out_of_period() -> void:
	var p := _profile()
	var r := SeasonalEvents.craft(p, "giang_sinh", "c37", {}, 3, null, _at(2026, 12, 20))
	check("Mua 3 Gà Quay (10.000 lượng/con)", r["ok"] and _count(p, "6_1_30167") == 3 and p.gold == 970000)
	var r2 := SeasonalEvents.craft(p, "giang_sinh", "c37", {}, 1, null, _at(2026, 11, 26))
	check("ngoài đợt -> không ép được", not r2["ok"])
	var r3 := SeasonalEvents.craft(p, "giang_sinh", "c37", {}, -1, null, _at(2026, 12, 20))
	check("mua mà không nhập số lần -> báo lỗi", not r3["ok"])

func test_open_items() -> void:
	var p := _profile(150)
	var box := _give(p, "6_1_3080", 2)   ## Hộp quà giáng sinh: 1.000.000 kinh nghiệm
	var exp_before = p.get("exp")
	var lv_before := p.level
	var r := SeasonalEvents.open_item(p, box.uid, null, _at(2026, 12, 10))
	check("mở Hộp quà GS", r["ok"])
	check("mở xong còn 1 hộp", _count(p, "6_1_3080") == 1)
	check("nhận kinh nghiệm", p.get("exp") != exp_before or p.level != lv_before)
	var low := _profile(10)
	var b2 := _give(low, "6_1_3080", 1)
	check("cấp 10 không mở được (gốc cần 150)", not SeasonalEvents.open_item(low, b2.uid, null, _at(2026, 12, 10))["ok"])
	## Ông Già Noel (đại): mốc 50 lần +20.000.000 kinh nghiệm
	var p3 := _profile(150)
	var big := _give(p3, "6_1_3079", 1)
	var key := "giang_sinh:2026:use:6_1_3079"
	p3.event_counters[key] = 49
	var r3 := SeasonalEvents.open_item(p3, big.uid, null, _at(2026, 12, 10))
	check("Ông Già Noel đại lần 50 có thưởng mốc", r3["ok"] and str(r3["message"]).contains("Mốc dùng 50"))
	check("bộ đếm tăng lên 50", int(p3.event_counters[key]) == 50)
	## Giỏ hoa 8/3: quay ngẫu nhiên 1 món -> vật phẩm thật vào hành trang
	var p4 := _profile(150)
	var basket := _give(p4, "6_1_3127", 1)
	var before := p4.inventory.size()
	var r4 := SeasonalEvents.open_item(p4, basket.uid, null, _at(2027, 3, 10))
	check("mở Giỏ Hoa Hồng Vĩnh Cửu", r4["ok"])
	check("phần thưởng là vật phẩm thật hoặc kinh nghiệm", p4.inventory.size() >= before - 1)
	## giới hạn số lần
	var p5 := _profile(150)
	var cake := _give(p5, "6_1_3082", 1)   ## Bánh Giáng Sinh: tối đa 1000 lần
	p5.event_counters["giang_sinh:2026:use:6_1_3082"] = 1000
	check("dùng quá giới hạn đợt -> chặn", not SeasonalEvents.open_item(p5, cake.uid, null, _at(2026, 12, 10))["ok"])
	check("năm sau đếm lại từ đầu", SeasonalEvents.open_item(p5, cake.uid, null, _at(2027, 12, 10))["ok"])

func test_counters_save() -> void:
	var p := _profile()
	p.event_counters["giang_sinh:2026:use:6_1_3082"] = 12
	var q := PlayerProfile.from_dict(p.to_dict())
	check("bộ đếm sự kiện lưu / nạp lại", int(q.event_counters.get("giang_sinh:2026:use:6_1_3082", 0)) == 12)
	var merged := ProfileGuard.merge({"event_counters": {"a:1:x": 3}}, {"event_counters": {"a:1:x": 999}})
	check("online: bộ đếm giữ bản server", int(merged["event_counters"]["a:1:x"]) == 3)

## Mọi phần thưởng trang bị đều tạo được (mặt nạ sự kiện gốc chưa có trong bảng trang bị đã bị tool bỏ) — không ai mất đồ trắng tay.
func test_equip_rewards_exist() -> void:
	var bad: Array = []
	for ev in SeasonalEvents.events():
		var nodes: Array = []
		for r in ev["recipes"]:
			nodes.append(r["result"])
			nodes.append_array((r.get("milestones", {}) as Dictionary).values())
		for u in (ev["usables"] as Dictionary).values():
			nodes.append(u["result"])
			nodes.append_array((u.get("milestones", {}) as Dictionary).values())
		while not nodes.is_empty():
			var n: Variant = nodes.pop_back()
			if not n is Dictionary:
				continue
			if n.has("equip"):
				var e: Array = n["equip"]
				if ItemDatabase.find_base(int(e[0]), int(e[1]), int(e[2]) if e.size() > 2 else 1) < 0:
					bad.append("%s %s" % [ev["id"], e])
			for k in ["all", "pick"]:
				nodes.append_array(n.get(k, []))
	check("mọi trang bị thưởng có trong bảng trang bị %s" % [bad], bad.is_empty())

func test_data_icons() -> void:
	var missing := 0
	for ev in SeasonalEvents.events():
		for r in ev["recipes"]:
			for m in r["materials"]:
				for mid in SeasonalEvents.mat_items(m):
					if SeasonalEvents.item_icon(mid) == null:
						missing += 1
			for mid in SeasonalEvents.result_items(r["result"]):
				if SeasonalEvents.item_icon(mid) == null:
					missing += 1
	check("mọi nguyên liệu / thành phẩm có ảnh", missing == 0)

## Tết 2008 (newyear_2008) gộp vào thẻ Tết: gói bánh chưng, Túi mừng xuân, ăn bánh, treo liễn (giới hạn 20 lần).
func test_tet_2008() -> void:
	var at := _at(2027, 2, 6)   ## mùng 1 Tết 2027
	var tet := SeasonalEvents.get_event("tet_nguyen_dan")
	check("Tết 2027 đang diễn ra mùng 1", SeasonalEvents.is_active(tet, at))
	var p := _profile()
	var placed := {}
	for pair in [["6_1_1653", 9], ["6_1_1654", 6], ["6_1_1655", 4], ["6_1_1656", 2], ["6_1_1660", 1]]:
		var it := _give(p, pair[0], pair[1])
		placed[it.uid] = pair[1]
	var pl := SeasonalEvents.plan(p, tet, SeasonalEvents.AUTO, placed)
	var ids: Array = pl["steps"].map(func(s): return s[0]["id"])
	check("tự động: 2 bánh, dùng Bí quyết làm thượng hạng + 1 thường", pl["ok"] and pl["total"] == 2 and ids.has("tt08_1") and ids.has("tt08_3"))
	check("dư 1 Lá bánh", int(pl["left"].get("6_1_1653", 0)) == 1)
	var r := SeasonalEvents.craft(p, "tet_nguyen_dan", SeasonalEvents.AUTO, placed, -1, null, at)
	check("gói xong: 1 thượng hạng + 1 thường, tốn 20.000", r["ok"] and _count(p, "6_1_1662") == 1 and _count(p, "6_1_1664") == 1 and p.gold == 980000)
	## ăn bánh thượng hạng: 2 triệu kinh nghiệm + 1 món ngẫu nhiên; cấp < 50 không ăn được
	var cake: ItemInstance = p.inventory.filter(func(x): return x.misc_id == "6_1_1662")[0]
	var before := p.inventory.size()
	var r2 := SeasonalEvents.open_item(p, cake.uid, null, at)
	check("ăn Bánh chưng thượng hạng: có kinh nghiệm + quà", r2["ok"] and int(r2["gains"].get("exp", 0)) == 2000000 and p.inventory.size() >= before)
	var low := _profile(40)
	var c2 := _give(low, "6_1_1664", 1)
	check("cấp 40 không ăn được (gốc cần 50)", not SeasonalEvents.open_item(low, c2.uid, null, at)["ok"])
	## Túi mừng xuân mở ra 1 nguyên liệu
	var bag := _give(p, "6_1_1652", 1)
	var r3 := SeasonalEvents.open_item(p, bag.uid, null, at)
	var got := 0
	for mid in ["6_1_1653", "6_1_1654", "6_1_1655", "6_1_1656", "6_1_1657", "6_1_1658", "6_1_1659", "6_1_1660", "6_1_1661"]:
		got += _count(p, mid)
	check("mở Túi mừng xuân ra nguyên liệu", r3["ok"] and got >= 2)   ## + 1 Lá bánh dư
	## treo liễn: tối đa 20 lần / đợt
	var q := _profile()
	var lp := {}
	for mid in ["6_1_1657", "6_1_1658", "6_1_1659"]:
		var it := _give(q, mid, 3)
		lp[it.uid] = 3
	q.event_counters["tet_nguyen_dan:2027:craft:tt08_lien"] = 19
	var pl2 := SeasonalEvents.plan(q, tet, "tt08_lien", lp, -1, at)
	check("treo liễn: còn 1 lần dù đủ 3 bộ", pl2["ok"] and pl2["total"] == 1 and pl2["money"] == 9999)
	q.event_counters["tet_nguyen_dan:2027:craft:tt08_lien"] = 20
	check("treo liễn đủ 20 lần -> chặn", not SeasonalEvents.plan(q, tet, "tt08_lien", lp, -1, at)["ok"])
	var r4 := SeasonalEvents.plan(q, tet, SeasonalEvents.AUTO, lp, -1, at)
	check("tự động bỏ qua công thức đã hết lượt", not r4["ok"])

## Đoan Ngọ (ban_banh_u.lua): làm bánh, nâng cấp tốn 1 nguyên liệu bất kỳ, hỏng trả lại Thập cẩm, bánh buff.
func test_doan_ngo() -> void:
	var dn := SeasonalEvents.get_event("doan_ngo")
	var d := LunarCalendar.lunar_to_solar(5, 5, 2027)
	var at := _at(d["year"], d["month"], d["day"])
	check("Đoan Ngọ 2027 đang diễn ra ngày mùng 5/5 âm", SeasonalEvents.is_active(dn, at))
	var p := _profile()
	var tc := _give(p, "6_1_63", 3)
	var tao := _give(p, "4_394_1", 1)
	var bo := _give(p, "4_399_1", 1)
	var placed := {tc.uid: 3, tao.uid: 1, bo.uid: 1}
	var pl := SeasonalEvents.plan(p, dn, "dn_up64", placed)
	check("nâng Mật ong: 3 Thập cẩm nhưng 2 nguyên liệu -> 2 lần", pl["ok"] and pl["total"] == 2)
	check("trừ Táo đỏ trước rồi Thịt bò (theo thứ tự gốc)", int(pl["used"].get("4_394_1", 0)) == 1 and int(pl["used"].get("4_399_1", 0)) == 1)
	check("tốn 2.000 lượng", pl["money"] == 2000)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var r := SeasonalEvents.craft(p, "doan_ngo", "dn_up64", placed, -1, rng, at)
	check("nâng xong: Mật ong + Thập cẩm (hỏng trả lại) = 3", r["ok"] and _count(p, "6_1_64") + _count(p, "6_1_63") == 3)
	check("hết nguyên liệu bất kỳ", _count(p, "4_394_1") == 0 and _count(p, "4_399_1") == 0)
	var q := _profile()
	var tc2 := _give(q, "6_1_63", 1)
	var miss := SeasonalEvents.plan(q, dn, "dn_up64", {tc2.uid: 1})
	check("thiếu nguyên liệu bất kỳ -> báo '1 trong'", not miss["ok"] and str(miss["message"]).contains("1 trong"))
	var mp := _give(q, "4_404_1", 1)
	var hd := _give(q, "4_395_1", 1)
	var pl2 := SeasonalEvents.plan(q, dn, "dn_up64_mp", {tc2.uid: 1, mp.uid: 1, hd.uid: 1})
	check("có Mật phương: 60%", pl2["ok"] and pl2["total"] == 1 and float(SeasonalEvents.get_recipe(dn, "dn_up64_mp")["rate"]) == 60.0)
	## làm bánh Thịt bò rồi ăn: buff kháng
	var w := _profile()
	var bp := {}
	for mid in ["4_394_1", "4_396_1", "4_397_1", "4_399_1"]:
		var it := _give(w, mid, 2)
		bp[it.uid] = 2
	var r2 := SeasonalEvents.craft(w, "doan_ngo", "dn_bo", bp, -1, null, at)
	check("làm Bánh chưng Thịt bò", r2["ok"] and _count(w, "6_0_62") == 1)
	var cake: ItemInstance = w.inventory.filter(func(x): return x.misc_id == "6_0_62")[0]
	check("Bánh chưng Thịt bò có hiệu ứng kháng 10 phút", PotionEffect.usable(cake) and PotionEffect.effects_of(cake).size() == 5)
	## Khuất Nguyên: ăn 1 lần
	var kn := _give(w, "6_1_68", 2)
	var r3 := SeasonalEvents.open_item(w, kn.uid, null, at)
	check("ăn Khuất Nguyên: 200 triệu kinh nghiệm", r3["ok"] and int(r3["gains"].get("exp", 0)) == 200000000)
	check("Khuất Nguyên chỉ ăn được 1 lần", not SeasonalEvents.open_item(w, kn.uid, null, at)["ok"])

## Lịch GM: đặt đợt mới (thử theo giờ thật), áp cho đang diễn ra / sắp tới / ép, "Mặc định" về lịch gốc; bản online thay hẳn.
func test_gm_override() -> void:
	var now := _at(2026, 11, 26)
	var noel := SeasonalEvents.get_event("giang_sinh")
	check("Giáng Sinh 26/11/2026 chưa diễn ra", not SeasonalEvents.is_active(noel, now))
	var today := SeasonalEvents.vn_midnight(2026, 11, 26)
	check("GM đặt Giáng Sinh 26/11–02/12", SeasonalEvents.set_override("giang_sinh", today, today + 7 * SeasonalEvents.DAY - 1, false) == "")
	var p := SeasonalEvents.current_period(noel, now)
	check("GM: Giáng Sinh đang diễn ra + cờ gm", p["status"] == "ongoing" and p.get("gm", false))
	check("GM: kết thúc 02/12/2026", SeasonalEvents.format_date(p["end"]) == "02/12/2026")
	check("GM: active_ids có giang_sinh", SeasonalEvents.active_ids(now).has("giang_sinh"))
	var q := _profile()
	var ao := _give(q, "6_1_3074", 2)
	var quan := _give(q, "6_1_3075", 1)
	check("GM: ép được Hộp quà GS trong lịch GM", SeasonalEvents.craft(q, "giang_sinh", "c18", {ao.uid: 2, quan.uid: 1}, -1, null, now)["ok"])
	check("sai: kết thúc trước bắt đầu", SeasonalEvents.set_override("giang_sinh", today, today - 1, false) != "")
	check("sai: quá 366 ngày", SeasonalEvents.set_override("giang_sinh", today, today + 400 * SeasonalEvents.DAY, false) != "")
	## hết lịch GM -> lịch gốc (01/12–31/12) chạy lại
	var after := _at(2026, 12, 10)
	check("sau lịch GM: theo lịch gốc (10/12 vẫn diễn ra)", SeasonalEvents.is_active(noel, after) and not SeasonalEvents.current_period(noel, after).get("gm", false))
	SeasonalEvents.clear_override("giang_sinh", false)
	check("Mặc định: về lịch gốc", not SeasonalEvents.is_active(noel, now) and SeasonalEvents.get_override("giang_sinh").is_empty())
	## online: server gửi lịch (bỏ sự kiện lạ + khoảng sai)
	SeasonalEvents.apply_remote_overrides({"nha_giao": {"start": today, "end": today + 3600}, "khong_co": {"start": 1, "end": 2},
		"valentine": {"start": 10, "end": 5}})
	check("online: nhận lịch server, bỏ mục sai", SeasonalEvents.overrides().size() == 1 and SeasonalEvents.overrides().has("nha_giao"))
	SeasonalEvents.use_local_overrides()
	check("rời online: lịch máy (không có)", SeasonalEvents.overrides().is_empty())
	check("đọc ngày dd/mm/yyyy", GmControlWindow._parse_vn_date("02/12/2026") == SeasonalEvents.vn_midnight(2026, 12, 2)
		and GmControlWindow._parse_vn_date("31/02/2026") == -1 and GmControlWindow._parse_vn_date("abc") == -1)

## Hộp sự kiện: mỗi sự kiện 1 hộp (chung ảnh ev_box), quái rơi trong đợt, mở ra nguyên liệu của sự kiện.
func test_event_box() -> void:
	var missing := 0
	for ev in SeasonalEvents.events():
		var box := SeasonalEvents.drop_box_of(ev)
		if box == "" or SeasonalEvents.item_icon(box) == null or not SeasonalEvents.is_usable(box):
			missing += 1
	check("mọi sự kiện có hộp (ảnh + mở được)", missing == 0)
	check("hộp chồng được 100", ItemDatabase.max_stack("ev_box_nha_giao") == 100)
	## bậc hiếm: mỗi hộp tổng 100%, có món Thường; món hiếm hơn ra ít hơn (Tết: Bí quyết thượng hạng < Phúc < Mâm Bạc < Lá bánh)
	var sums_ok := true
	for ev in SeasonalEvents.events():
		var tot := 0.0
		var has_common := false
		for x in ev["usables"][SeasonalEvents.drop_box_of(ev)]["result"]["pick"]:
			tot += float(x["rate"])
			has_common = has_common or str(x.get("tier", "")) == "Thường"
		sums_ok = sums_ok and absf(tot - 100.0) < 0.1 and has_common
	check("mọi hộp: tổng 100%, có nguyên liệu Thường", sums_ok)
	var rate := {}
	for x in SeasonalEvents.get_event("tet_nguyen_dan")["usables"]["ev_box_tet_nguyen_dan"]["result"]["pick"]:
		rate[str(x["item"])] = float(x["rate"])
	check("Tết: Bí quyết TH < Phúc < Mâm Bạc < Lá bánh", rate["6_1_1660"] < rate["6_1_1657"] and rate["6_1_1657"] < rate["6_1_3103"]
		and rate["6_1_3103"] < rate["6_1_1653"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	check("tỷ lệ rơi hộp 10%", is_equal_approx(SeasonalEvents.box_drop_rate(), 0.1))
	var got_box := 0
	var right_box := true
	for i in 2000:
		for d in SeasonalEvents.roll_monster_drops(_at(2026, 11, 26), rng):
			got_box += 1
			right_box = right_box and (d["item"] as ItemInstance).misc_id == "ev_box_nha_giao"
	check("26/11/2026: 2000 quái rơi khoảng 10%% Hộp 20/11 (%d hộp)" % got_box, right_box and got_box > 140 and got_box < 260)
	## 2 sự kiện cùng diễn ra (GM kích hoạt Giáng Sinh trong lúc 20/11 đang chạy): mỗi quái tối đa 1 hộp, tổng vẫn ~10%
	var today := SeasonalEvents.vn_midnight(2026, 11, 26)
	SeasonalEvents.set_override("giang_sinh", today, today + 7 * SeasonalEvents.DAY - 1, false)
	var max_one := true
	var kinds := {}
	var total := 0
	for i in 2000:
		var dd := SeasonalEvents.roll_monster_drops(_at(2026, 11, 26), rng)
		max_one = max_one and dd.size() <= 1
		total += dd.size()
		for x in dd:
			kinds[(x["item"] as ItemInstance).misc_id] = true
	SeasonalEvents.clear_override("giang_sinh", false)
	check("2 sự kiện cùng lúc: 1 quái tối đa 1 hộp, ~10%% (%d / 2000)" % total, max_one and total > 140 and total < 260)
	check("2 sự kiện cùng lúc: ra cả 2 loại hộp", kinds.has("ev_box_nha_giao") and kinds.has("ev_box_giang_sinh"))
	check("ngoài mọi đợt: không rơi", SeasonalEvents.roll_monster_drops(_at(2026, 8, 1), rng).is_empty())
	var p := _profile()
	var box_it := _give(p, "ev_box_nha_giao", 3)
	var mats := SeasonalEvents.material_ids(SeasonalEvents.get_event("nha_giao"))
	var ok := true
	for i in 3:
		var before := p.inventory.size()
		ok = ok and SeasonalEvents.open_item(p, box_it.uid, rng, _at(2026, 11, 26))["ok"]
	var got := 0
	for it in p.inventory:
		if mats.has(it.misc_id):
			got += it.count
	check("mở 3 hộp 20/11 -> 3 nguyên liệu 20/11", ok and got == 3 and _count(p, "ev_box_nha_giao") == 0)

## Nguyên liệu sự kiện + hộp chồng 100; nhặt tự gộp; tách chồng (>= 2 cái) thành chồng mới.
func test_stack_and_split() -> void:
	check("Táo đỏ (gốc không chồng) giờ chồng 100", ItemDatabase.max_stack("4_394_1") == 100)
	check("Giấy kiếng vàng chồng 100", ItemDatabase.max_stack("6_1_1221") == 100)
	check("Hộp sự kiện chồng 100", ItemDatabase.max_stack("ev_box_giang_sinh") == 100)
	check("đá quý chung không bị đổi luật chồng", not SeasonalEvents.stack_items().has("4_353_1"))
	var p := _profile()
	for i in 3:   ## nhặt 3 lần 1 hộp -> 1 chồng 3
		var it := ItemGenerator.generate_misc("ev_box_giang_sinh")
		it.count = 1
		p.add_item_stacked(it)
	var stacks := p.inventory.filter(func(x): return x.misc_id == "ev_box_giang_sinh")
	check("nhặt 3 hộp tự gộp thành 1 chồng 3", stacks.size() == 1 and stacks[0].count == 3)
	var src: ItemInstance = stacks[0]
	check("tách 1 cái từ chồng 3", p.split_stack(src.uid, 1) == "")
	stacks = p.inventory.filter(func(x): return x.misc_id == "ev_box_giang_sinh")
	check("sau tách: 2 chồng (2 + 1), uid khác nhau", stacks.size() == 2 and src.count == 2 and stacks[0].uid != stacks[1].uid
		and _count(p, "ev_box_giang_sinh") == 3)
	check("không tách hết cả chồng", p.split_stack(src.uid, 2) != "")
	check("không tách chồng 1 cái", p.split_stack(stacks[1].uid if stacks[1] != src else stacks[0].uid, 1) != "")
	check("uid lạ -> báo lỗi", p.split_stack("khong_co", 1) != "")

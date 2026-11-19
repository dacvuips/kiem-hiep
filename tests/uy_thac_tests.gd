extends Node
## Ủy thác (UyThac, chỉ online): Bạch Câu Hoàn -> quỹ giờ, thoát game vẫn lên cấp; mốc giờ / quỹ chỉ server ghi (ProfileGuard).
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/uy_thac_tests.tscn

var _fail := 0

func check(name: String, ok: bool) -> void:
	print(("  OK  " if ok else "FAIL ") + name)
	if not ok:
		_fail += 1

func _profile(level: int, seen: int, bank := {}) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.level = level
	p.uy_thac_seen = seen
	p.uy_thac_bank = bank.duplicate()
	return p

func _count(p: PlayerProfile, mid: String) -> int:
	var n := 0
	for it in p.inventory:
		if it != null and it.misc_id == mid:
			n += it.count
	return n

func _ready() -> void:
	var now := 2_000_000_000
	var h8 := 8 * 3600

	# Không có giờ ủy thác: không cộng, vẫn đặt mốc.
	var p := _profile(20, now - 7200)
	check("Quỹ rỗng: không cộng", UyThac.settle(p, now).is_empty() and p.current_exp == 0 and p.uy_thac_seen == now)

	# Chưa có mốc / rời < 10 phút / đồng hồ lùi: không cộng, không tiêu quỹ.
	p = _profile(20, 0, {"1.0": h8})
	check("Chưa có mốc: không cộng", UyThac.settle(p, now).is_empty() and UyThac.bank_secs(p) == h8)
	p = _profile(20, now - UyThac.MIN_SECS + 1, {"1.0": h8})
	check("Rời < 10 phút: không cộng", UyThac.settle(p, now).is_empty() and UyThac.bank_secs(p) == h8)
	p = _profile(20, now + 5000, {"1.0": h8})
	check("Đồng hồ lùi: không cộng", UyThac.settle(p, now).is_empty())

	# 1 giờ x1: đúng EXP/giờ, quỹ trừ 1 giờ.
	p = _profile(20, now - 3600, {"1.0": h8})
	var per_hour := UyThac.exp_per_hour(p)
	var r := UyThac.settle(p, now)
	check("1 giờ x1: +%d EXP" % per_hour, int(r.get("exp", 0)) == per_hour and p.current_exp == per_hour)
	check("1 giờ: quỹ còn 7 giờ", UyThac.bank_secs(p) == 7 * 3600 and int(r.get("bank_left", 0)) == 7 * 3600)

	# Hệ số x2 tiêu trước, gấp đôi EXP.
	p = _profile(20, now - 3600, {"1.0": h8, "2.0": h8})
	r = UyThac.settle(p, now)
	check("x2 tiêu trước, EXP gấp đôi", int(r.get("exp", 0)) == per_hour * 2 and int(p.uy_thac_bank["1.0"]) == h8 and int(p.uy_thac_bank["2.0"]) == 7 * 3600)

	# Rời 3 ngày nhưng quỹ chỉ 8 giờ: tính 8 giờ, quỹ về 0 (xoá khoá).
	p = _profile(20, now - 3 * 86400, {"1.0": h8})
	r = UyThac.settle(p, now)
	check("Rời 3 ngày, quỹ 8 giờ: chỉ tính 8 giờ", int(r.get("secs", 0)) == h8 and UyThac.bank_secs(p) == 0 and p.uy_thac_bank.is_empty())
	check("8 giờ: lên cấp (20 -> %d)" % p.level, p.level >= 21 and int(r.get("to", 0)) == p.level)

	# Cấp tối đa: không cộng, không tiêu quỹ.
	p = _profile(PlayerProfile.MAX_LEVEL, now - 7200, {"1.0": h8})
	check("Cấp 200: không cộng", UyThac.settle(p, now).is_empty() and UyThac.bank_secs(p) == h8)

	# Mua + dùng Bạch Câu Hoàn.
	p = _profile(20, 0)
	p.gold = 250000
	check("Không đủ lượng cho 3 viên: từ chối", not UyThac.buy(p, "6_1_74", 3)["ok"] and p.gold == 250000)
	r = UyThac.buy(p, "6_1_74", 2)
	check("Mua 2 Bạch Câu hoàn: trừ 200.000 lượng", r["ok"] and p.gold == 50000 and _count(p, "6_1_74") == 2)
	check("Không đủ KNB: từ chối", not UyThac.buy(p, "6_1_130", 1)["ok"])
	check("Mã lạ: từ chối", not UyThac.buy(p, "1_0_0", 1)["ok"])
	p.to_dict()   ## server: gán uid cho đồ mới khi dựng bản chuẩn (S_PROFILE / lưu)
	var uid := ""
	for it in p.inventory:
		if it.misc_id == "6_1_74":
			uid = it.uid
	r = UyThac.use(p, uid)
	check("Dùng 1 viên: +8 giờ x1, còn 1 viên", r["ok"] and int(p.uy_thac_bank.get("1.0", 0)) == h8 and _count(p, "6_1_74") == 1)
	check("Dùng uid lạ: từ chối", not UyThac.use(p, "khong_co")["ok"])
	p.uy_thac_bank = {"1.0": UyThac.BANK_MAX_SECS - 3600}
	check("Quỹ gần đầy: không dùng thêm", not UyThac.use(p, uid)["ok"] and _count(p, "6_1_74") == 1)

	# Lưu / nạp giữ mốc + quỹ + báo cáo.
	p = _profile(30, now - 7200, {"1.5": h8})
	UyThac.settle(p, now)
	var back := PlayerProfile.from_dict(p.to_dict())
	check("to_dict/from_dict giữ mốc + quỹ + báo cáo", back.uy_thac_seen == now and UyThac.bank_secs(back) == h8 - 7200
		and int(back.uy_thac_report.get("exp", 0)) == int(p.uy_thac_report.get("exp", 0)))

	# Online: game tự sửa mốc lùi / tự cộng quỹ -> ProfileGuard giữ bản server (cả chế độ dev).
	var server := _profile(30, now, {"1.0": 3600}).to_dict()
	var client := server.duplicate(true)
	client["uy_thac_seen"] = 1
	client["uy_thac_bank"] = {"2.0": 999999}
	client["uy_thac_report"] = {"exp": 999999999}
	for trust in [false, true]:
		var merged := ProfileGuard.merge(server, client, 0, trust)
		check("ProfileGuard giữ mốc + quỹ server (trust=%s)" % trust, int(merged.get("uy_thac_seen", 0)) == now
			and merged.get("uy_thac_bank", {}) == {"1.0": 3600} and (merged.get("uy_thac_report", {}) as Dictionary).is_empty())
	check("sanitize_new bỏ mốc + quỹ", int(ProfileGuard.sanitize_new(client).get("uy_thac_seen", -1)) == 0
		and (ProfileGuard.sanitize_new(client).get("uy_thac_bank", {}) as Dictionary).is_empty())

	print("--- uy_thac_tests: %s ---" % ("TẤT CẢ ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)

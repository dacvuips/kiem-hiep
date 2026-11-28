extends Node
## Luật rơi đồ: Đồ Hoàng Kim / thuốc Hiệu Thuốc / ngựa CHỈ rơi trong Lộn Xộn và PUBG (Chiến Trường Sinh Tồn).
## Mọi map / chế độ khác (quái thường, boss xanh, boss Hoàng Kim, Tiểu HK, Sát thủ, Địa Ngục) giữ bảng gốc DropTable.

var _fails := 0

func _check(ok: bool, msg: String) -> void:
	print(("  ✓ " if ok else "  ✗ FAIL: ") + msg)
	if not ok:
		_fails += 1

func _ready() -> void:
	print("=== TEST LUẬT RƠI ĐỒ: HK / THUỐC / NGỰA CHỈ Ở LỘN XỘN + PUBG ===")
	_test_original_tables()
	_test_mode_tables()
	print("FAILS=%d" % _fails)
	get_tree().quit(_fails)

## Đếm [hoàng kim, ngựa, thuốc Hiệu Thuốc, trang bị xanh] trong 1 danh sách rơi.
static func _count(drops: Array, acc: Array) -> void:
	for d in drops:
		if str(d.get("type", "")) != "item":
			continue
		var it: ItemInstance = d["item"]
		if it.is_gold():
			acc[0] += 1
		elif it.is_misc():
			if it.misc_id in PotionShop.items():
				acc[2] += 1
		elif it.get_base().get("detail") == ItemDatabase.Detail.HORSE:
			acc[1] += 1
		else:
			acc[3] += 1

func _test_original_tables() -> void:
	print("[1] Bảng gốc (map thường, boss, Địa Ngục) — không HK / thuốc / ngựa")
	DropTable.set_rates(30.0, 1.0)   ## tăng tỉ lệ rơi đồ để 1 lượt chạy thấy được đồ xanh
	var normal := [0, 0, 0, 0]
	for i in 3000:
		_count(DropTable.roll(50, 0, 0), normal)
	_check(normal[0] == 0 and normal[1] == 0 and normal[2] == 0, "quái thường: HK=%d ngựa=%d thuốc=%d" % [normal[0], normal[1], normal[2]])
	_check(normal[3] > 0, "quái thường vẫn rơi trang bị xanh như gốc (%d món)" % normal[3])
	var boss := [0, 0, 0, 0]
	for i in 50:
		_count(DropTable.roll_blue_boss(50, 0), boss)
		_count(DropTable.roll_gold_boss(95, 0), boss)
		_count(DropTable.roll_small_gold_boss(95, 0), boss)
		_count(DropTable.roll_killer_boss(75, 0), boss)
		_count(DropTable.roll_hell(110, 0, 5, false), boss)
		_count(DropTable.roll_hell(110, 0, 5, true), boss)
	_check(boss[0] == 0 and boss[1] == 0 and boss[2] == 0, "boss / Địa Ngục: HK=%d ngựa=%d thuốc=%d" % [boss[0], boss[1], boss[2]])
	_check(boss[3] > 0, "boss / Địa Ngục rơi trang bị xanh (%d món)" % boss[3])
	DropTable.set_rates(1.0, 1.0)

func _test_mode_tables() -> void:
	print("[2] Bảng riêng PUBG + Lộn Xộn — có HK / thuốc / ngựa")
	var pubg := [0, 0, 0, 0]
	for i in 300:
		_count(PubgServer.roll_drops(), pubg)
	_check(pubg[0] > 0 and pubg[1] > 0 and pubg[2] > 0, "PUBG: HK=%d ngựa=%d thuốc=%d" % [pubg[0], pubg[1], pubg[2]])
	var lx := [0, 0, 0, 0]
	for i in 300:
		_count(LonXonRules.roll_drops(60), lx)
	_check(lx[0] + lx[1] + lx[2] > 0, "Lộn Xộn: HK=%d ngựa=%d thuốc=%d" % [lx[0], lx[1], lx[2]])

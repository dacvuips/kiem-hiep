extends Node
## Uống chồng thuốc (PotionEffect): tổng hồi giữ đúng công thức gốc, nhịp dày lên khi chồng cùng loại.
## Chạy: godot --headless --path . res://tests/potion_stack_tests.tscn

class FakeTarget extends Node:
	var healed := 0.0
	var mana := 0.0
	var ticks := 0
	func heal(v: float) -> void:
		healed += v
		ticks += 1
	func restore_mana(v: float) -> void:
		mana += v

var _fail := 0

func check(name: String, ok: bool) -> void:
	print(("  OK  " if ok else "  FAIL ") + name)
	if not ok:
		_fail += 1

func _target() -> FakeTarget:
	var t := FakeTarget.new()
	add_child(t)
	return t

## Chạy đúng n frame game (18 frame/giây).
func _run(pe: PotionEffect, n: int) -> void:
	for i in n:
		pe._process(1.0 / PotionEffect.GAME_FPS + 0.000001)

## Thuốc xếp chồng trong hành trang: tối đa ItemDatabase.POTION_STACK (50) bình 1 ô.
func _bag_stack_tests() -> void:
	check("Kim Sáng Dược chồng 50", ItemDatabase.max_stack("1_0_0_1") == 50)
	check("Thuốc Tống Kim chồng 50", ItemDatabase.max_stack("6_155") == 50)
	check("Trang bị không chồng", ItemDatabase.max_stack("") == 1)
	var p := PlayerProfile.new()
	p.gold = 10_000_000
	var r := PotionShop.buy(p, "1_0_0_1", 60)
	check("Mua 60 bình: đủ 60", int(r.get("bought", 0)) == 60)
	var counts: Array = []
	for it in p.inventory:
		counts.append(it.count)
	check("Mua 60 bình: 2 ô 50 + 10", counts == [50, 10])
	PotionShop.buy(p, "1_0_0_1", 45)
	counts.clear()
	for it in p.inventory:
		counts.append(it.count)
	check("Mua thêm 45: lấp ô 10 rồi ô mới (50, 50, 5)", counts == [50, 50, 5])
	PotionShop.buy(p, "1_1_0_1", 3)
	check("Thuốc khác loại: ô riêng", p.inventory.size() == 4 and p.inventory[3].count == 3)
	## Món khoá không gộp với món tự do.
	var locked := ItemGenerator.generate_misc("1_1_0_1")
	locked.lock_state = ItemInstance.LOCK_LOCKED
	p.add_item_stacked(locked)
	check("Món khoá không gộp chồng tự do", p.inventory.size() == 5)
	## 1 món count lớn tự tách thành nhiều chồng.
	var big := ItemGenerator.generate_misc("1_2_0_1")
	big.count = 120
	check("Thêm 120 bình 1 lần: nhận hết", p.add_item_stacked(big))
	var total := 0
	var cells := 0
	for it in p.inventory:
		if it.misc_id == "1_2_0_1":
			total += it.count
			cells += 1
			check("Không chồng nào vượt 50", it.count <= 50)
	check("120 bình -> 3 ô, tổng 120", total == 120 and cells == 3)

func _ready() -> void:
	print("\n--- potion_stack_tests ---")
	# 1 bình: giống gốc — 20 nhịp x 150 = 3000, nhịp 10 frame.
	var t := _target()
	var pe := PotionEffect.of(t)
	pe.add(150.0, 200)
	check("1 bình: nhịp 10 frame", pe.life_interval() == 10)
	_run(pe, 10)
	check("1 bình: nhịp đầu sau 10 frame +150", is_equal_approx(t.healed, 150.0) and t.ticks == 1)
	_run(pe, 200)
	check("1 bình: tổng 3000, 20 nhịp", is_equal_approx(t.healed, 3000.0) and t.ticks == 20)
	check("1 bình: hết tác dụng", not pe.is_active())

	# 2 bình cùng loại cùng lúc: nhịp 5 frame, tổng 6000 trong 200 frame.
	t = _target()
	pe = PotionEffect.of(t)
	pe.add(150.0, 200)
	pe.add(150.0, 200)
	check("2 bình: nhịp 5 frame", pe.life_interval() == 5)
	_run(pe, 5)
	check("2 bình: nhịp đầu sau 5 frame +150", is_equal_approx(t.healed, 150.0))
	_run(pe, 100)
	check("2 bình: sau 105 frame = 3150 (tốc độ/giây gấp đôi)", is_equal_approx(t.healed, 3150.0))
	_run(pe, 200)
	check("2 bình: tổng 6000, 40 nhịp", is_equal_approx(t.healed, 6000.0) and t.ticks == 40)

	# 3 bình: nhịp 3 frame, chia lẻ không hụt.
	t = _target()
	pe = PotionEffect.of(t)
	for i in 3:
		pe.add(150.0, 200)
	check("3 bình: nhịp 3 frame", pe.life_interval() == 3)
	_run(pe, 220)
	check("3 bình: tổng đủ 9000", is_equal_approx(t.healed, 9000.0))

	# Bình 2 uống sau 90 frame: tổng = phần còn lại + bình mới (1650 + 3000 + 1350 đã hồi).
	t = _target()
	pe = PotionEffect.of(t)
	pe.add(150.0, 200)
	_run(pe, 90)
	pe.add(150.0, 200)
	_run(pe, 250)
	check("Uống chồng giữa chừng: tổng 6000", is_equal_approx(t.healed, 6000.0))

	# Bình nhỏ chồng bình lớn khác loại: không dày nhịp, tổng vẫn đủ.
	t = _target()
	pe = PotionEffect.of(t)
	pe.add(150.0, 200)
	pe.add(25.0, 100)
	check("Khác loại (đại + tiểu): giữ nhịp 10", pe.life_interval() == 10)
	_run(pe, 220)
	check("Khác loại: tổng 3000 + 250", is_equal_approx(t.healed, 3250.0))

	# Hết tác dụng rồi uống lại 1 bình: nhịp về 10.
	pe.add(150.0, 200)
	check("Uống lại sau khi hết: nhịp 10", pe.life_interval() == 10)

	# Nội lực cùng cơ chế.
	t = _target()
	pe = PotionEffect.of(t)
	pe.add_mana(100.0, 100)
	pe.add_mana(100.0, 100)
	check("Nội lực 2 bình: nhịp 5", pe.mana_interval() == 5)
	_run(pe, 120)
	check("Nội lực 2 bình: tổng 2000", is_equal_approx(t.mana, 2000.0))

	_bag_stack_tests()

	print("--- potion_stack_tests: %s ---" % ("TẤT CẢ ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)

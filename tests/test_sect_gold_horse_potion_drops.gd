extends Node

func _ready() -> void:
	print("=== TEST HỆ THỐNG RƠI ĐỒ MỚI: ĐỒ HOÀNG KIM MÔN PHÁI, NGỰA & HIỆU THUỐC ===")
	_test_database_helpers()
	_test_roll_methods()
	_test_normal_monster_drops()
	_test_boss_drops()
	print("PASS ALL: Quái chỉ rớt đồ Hoàng Kim Môn Phái, Ngựa ngẫu nhiên và vật phẩm Hiệu Thuốc hoàn tất chuẩn xác!")
	get_tree().quit(0)

func _test_database_helpers() -> void:
	print("[1] Kiểm tra cơ sở dữ liệu...")
	var sect_golds := ItemDatabase.get_sect_gold_indices()
	assert(sect_golds.size() >= 5000, "Phải có ít nhất 5000 món đồ Hoàng Kim Môn Phái (thực tế: %d)" % sect_golds.size())
	for i in 20:
		var g_idx: int = sect_golds[randi() % sect_golds.size()]
		var g_rec := ItemDatabase.get_gold(g_idx)
		assert(not g_rec.is_empty(), "Món hoàng kim %d phải tồn tại" % g_idx)
		assert(int(g_rec.get("menpai", -1)) >= 0, "Món %s phải thuộc môn phái (menpai >= 0)" % str(g_rec.get("name")))

	var horses := ItemDatabase.get_horse_base_indices()
	assert(horses.size() >= 300, "Phải có ít nhất 300 ngựa (thực tế: %d)" % horses.size())
	for i in 20:
		var b_idx: int = horses[randi() % horses.size()]
		var b_rec := ItemDatabase.get_base(b_idx)
		assert(not b_rec.is_empty(), "Ngựa base %d phải tồn tại" % b_idx)
		assert(int(b_rec.get("detail", -1)) == ItemDatabase.Detail.HORSE, "Món %s phải là ngựa (detail=HORSE)" % str(b_rec.get("name")))
	print("  ✓ Database: %d đồ Hoàng Kim Môn Phái, %d Ngựa hợp lệ!" % [sect_golds.size(), horses.size()])

func _test_roll_methods() -> void:
	print("[2] Kiểm tra hàm sinh đơn lẻ...")
	var gold_item := DropTable.roll_sect_gold_item()
	assert(gold_item != null, "roll_sect_gold_item không được null")
	assert(gold_item.is_gold(), "Đồ sinh ra phải là đồ hoàng kim (is_gold)")
	var gold_rec := ItemDatabase.get_gold(gold_item.gold_index)
	assert(int(gold_rec.get("menpai", -1)) >= 0, "Đồ hoàng kim phải có môn phái")
	print("  ✓ Sinh thử đồ HKMP: %s (Hệ: %d)" % [gold_item.get_display_name(), gold_item.series])

	var horse_item := DropTable.roll_horse()
	assert(horse_item != null, "roll_horse không được null")
	var horse_rec := horse_item.get_base()
	assert(int(horse_rec.get("detail", -1)) == ItemDatabase.Detail.HORSE, "Đồ sinh ra phải là ngựa")
	print("  ✓ Sinh thử Ngựa: %s" % horse_item.get_display_name())

	var pot_item := DropTable.roll_pharmacy_item()
	assert(pot_item != null, "roll_pharmacy_item không được null")
	assert(pot_item.is_misc(), "Thuốc phải là misc item")
	print("  ✓ Sinh thử Hiệu Thuốc: %s" % pot_item.get_display_name())

func _test_normal_monster_drops() -> void:
	print("[3] Kiểm tra rơi đồ quái thường (1000 lượt)...")
	var count_gold := 0
	var count_horse := 0
	var count_pot := 0
	var count_blue := 0
	for i in 1000:
		var drops := DropTable.roll(50, 0, 0)
		for d in drops:
			if str(d.get("type", "")) == "item":
				var it: ItemInstance = d["item"]
				if it.is_gold():
					count_gold += 1
				elif not it.is_misc() and it.get_base().get("detail") == ItemDatabase.Detail.HORSE:
					count_horse += 1
				elif it.is_misc() and it.misc_id in PotionShop.items():
					count_pot += 1
				elif not it.is_misc() and not it.is_gold():
					count_blue += 1

	print("  Quái thường 1000 con: HKMP = %d, Ngựa = %d, Thuốc = %d, Đồ xanh thường = %d" % [
		count_gold, count_horse, count_pot, count_blue
	])
	assert(count_gold >= 100, "Phải rơi nhiều đồ Hoàng Kim Môn Phái (~15%%)")
	assert(count_horse >= 20, "Phải rơi Ngựa (~5%%)")
	assert(count_pot >= 250, "Phải rơi nhiều dược phẩm Hiệu Thuốc (~35%%)")
	assert(count_blue == 0, "TUYỆT ĐỐI không được rơi trang bị xanh thường nữa!")

func _test_boss_drops() -> void:
	print("[4] Kiểm tra rơi đồ Boss...")
	# Boss Hoàng Kim
	var g_drops := DropTable.roll_gold_boss(95, 0)
	var boss_gold := 0
	var boss_horse := 0
	var boss_pot := 0
	for d in g_drops:
		if str(d.get("type", "")) == "item":
			var it: ItemInstance = d["item"]
			if it.is_gold():
				boss_gold += 1
			elif not it.is_misc() and it.get_base().get("detail") == ItemDatabase.Detail.HORSE:
				boss_horse += 1
			elif it.is_misc() and it.misc_id in PotionShop.items():
				boss_pot += 1
	print("  Boss Hoàng Kim: HKMP = %d món, Ngựa = %d con, Thuốc = %d bình" % [boss_gold, boss_horse, boss_pot])
	assert(boss_gold >= 4, "Boss Hoàng Kim phải rơi 4-6 món HKMP")
	assert(boss_horse >= 1, "Boss Hoàng Kim phải rơi 1-2 Ngựa")
	assert(boss_pot >= 3, "Boss Hoàng Kim phải rơi 3-5 Thuốc")

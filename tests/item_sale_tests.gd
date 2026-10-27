extends Node
## Kiểm thử tính năng Bán Vật Phẩm đổi lấy Vàng (Lượng) & Công thức tính giá chuẩn gốc VLTK

var _passes := 0
var _fails := 0

func check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("PASS: %s" % name)
	else:
		_fails += 1
		printerr("FAIL: %s" % name)

func _ready() -> void:
	print("\n--- BẮT ĐẦU TEST BÁN VẬT PHẨM & CÔNG THỨC GIÁ CHUẨN GỐC VLTK ---")

	# 1. Kiểm tra BUY_SELL_SCALE = 4 (25% giá gốc theo KBuySell.h gốc)
	check("BUY_SELL_SCALE = 4", ItemInstance.BUY_SELL_SCALE == 4)

	# 2. Tạo trang bị mẫu: Thiết Trủy thủ (base_index 0, giá gốc 100)
	var dagger := ItemInstance.new()
	dagger.base_index = 0
	check("Thiết Trủy thủ giá gốc = 100", dagger.get_base_price() == 100)
	check("Thiết Trủy thủ giá bán = 25 (100 / 4)", dagger.get_sale_price() == 25)
	check("Thiết Trủy thủ can_sell = true", dagger.can_sell())

	# 3. Món đồ bị khoá bảo hiểm -> không thể bán (giá bán = 0, can_sell = false)
	dagger.lock_state = ItemInstance.LOCK_LOCKED
	check("Đồ bị khoá: is_locked = true", dagger.is_locked())
	check("Đồ bị khoá: giá bán = 0", dagger.get_sale_price() == 0)
	check("Đồ bị khoá: can_sell = false", not dagger.can_sell())
	dagger.lock_state = ItemInstance.LOCK_NORMAL

	# 4. Vật phẩm xếp chồng (misc / thuốc / dược phẩm)
	# Kim Sáng Dược (tiểu): misc_id = "1_0_0_1", price = 50
	var potion := ItemInstance.new()
	potion.misc_id = "1_0_0_1"
	potion.count = 1
	check("Kim Sáng Dược giá gốc = 50", potion.get_base_price() == 50)
	# 50 / 4 = 12
	check("Kim Sáng Dược đơn giá bán = 12", potion.get_unit_sale_price() == 12)
	check("Kim Sáng Dược 1 bình giá bán = 12", potion.get_sale_price() == 12)

	potion.count = 10
	check("Kim Sáng Dược 10 bình giá bán = 120 (12 x 10)", potion.get_sale_price() == 120)

	# 5. Món đồ có giá 0 (ví dụ vật phẩm nhiệm vụ không có giá) -> không bán được
	var zero_item := ItemInstance.new()
	zero_item.base_index = -1
	check("Vật phẩm giá 0 không bán được", zero_item.get_sale_price() == 0 and not zero_item.can_sell())

	# 6. Kiểm tra quy trình bán trong PlayerProfile và InventoryPopup
	var profile := PlayerProfile.new()
	profile.display_name = "DaiHiep"
	profile.gold = 1000
	profile.add_item(dagger)
	profile.add_item(potion)

	check("Hành trang có 2 món", profile.inventory.size() == 2)
	var initial_gold := profile.gold

	# Bán Thiết Trủy thủ (25 lượng)
	var sell_idx := profile.inventory.find(dagger)
	check("Tìm thấy Thiết Trủy thủ trong túi", sell_idx >= 0)
	var price_dagger := dagger.get_sale_price()
	profile.inventory.remove_at(sell_idx)
	profile.gold += price_dagger

	check("Sau khi bán Thiết Trủy thủ: hành trang còn 1 món", profile.inventory.size() == 1)
	check("Sau khi bán: tiền tăng đúng 25 lượng (%d -> %d)" % [initial_gold, profile.gold], profile.gold == initial_gold + 25)

	# 7. Kiểm tra SecurityLock chặn bán đồ khi nhân vật đang khoá bảo vệ
	var err_set := SecurityLock.set_password(profile, "123456")
	check("Đặt mật khẩu bảo vệ thành công", err_set == "")
	check("Nhân vật đang bị khoá bảo vệ", SecurityLock.is_locked(profile))
	check("SecurityLock chặn lệnh A_NPC_SELL", SecurityLock.check(profile, SecurityLock.A_NPC_SELL) != "")

	SecurityLock.unlock(profile, "123456")
	check("Mở khoá bảo vệ thành công", not SecurityLock.is_locked(profile))
	check("Mở khoá xong cho phép bán", SecurityLock.check(profile, SecurityLock.A_NPC_SELL) == "")

	# 8. Kiểm tra ProfileGuard đồng bộ tiền hợp lệ khi bán đồ
	var server_profile := PlayerProfile.new()
	server_profile.gold = 1000
	var s_item := ItemInstance.new()
	s_item.base_index = 0
	server_profile.add_item(s_item)

	var s_dict := server_profile.to_dict()
	var c_dict := server_profile.to_dict()

	# Client bán s_item: xóa khỏi inventory và tăng gold thêm 25
	c_dict["inventory"] = []
	c_dict["gold"] = 1000 + 25

	var merged := ProfileGuard.merge(s_dict, c_dict, 0, false)
	check("ProfileGuard chấp thuận tiền từ vật phẩm đã bán", int(merged.get("gold", 0)) == 1025)
	check("ProfileGuard không đánh dấu _money_from_server", not merged.get("_money_from_server", false))

	# Thử gian lận tiền (tăng 500 lượng nhưng chỉ bán đồ 25 lượng) -> Server từ chối
	var cheat_dict := server_profile.to_dict()
	cheat_dict["inventory"] = []
	cheat_dict["gold"] = 1000 + 500
	var cheat_merged := ProfileGuard.merge(s_dict, cheat_dict, 0, false)
	check("ProfileGuard bác bỏ tiền gian lận vượt quá giá trị bán", int(cheat_merged.get("gold", 0)) == 1000)

	print("\nKẾT QUẢ TEST: %d PASS, %d FAIL" % [_passes, _fails])
	if _fails == 0:
		print("ALL TESTS PASSED!\n")
	get_tree().quit(0 if _fails == 0 else 1)

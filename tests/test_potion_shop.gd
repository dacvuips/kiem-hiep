extends Node

const PotionShopScript = preload("res://systems/items/potion_shop.gd")
const PotionShopWindowScript = preload("res://ui/shop/potion_shop_window.gd")

func _ready() -> void:
	print("\n--- BẮT ĐẦU TEST HIỆU THUỐC & THỔ ĐỊA PHÙ ---")
	
	# 1. Danh mục thuốc chính thống + Thổ Địa Phù (x1)
	var items: Array[String] = PotionShopScript.items()
	print("[1] Số lượng vật phẩm Dược Điếm chính thống: ", items.size())
	assert(items.size() == 27, "Dược Điếm phải có đúng 27 món (26 thuốc + Thổ Địa Phù x1)")
	assert(items.has("5_0_0"), "Dược Điếm phải có Thổ Địa Phù x1 (5_0_0)")
	
	# 2. Kiểm tra không chứa các món rác / sự kiện / hoàn tăng chỉ số
	for id in PotionShopScript.EXCLUDED_POTION_IDS:
		assert(not items.has(id), "Món bị loại trừ %s không được xuất hiện trong Dược Điếm" % id)
	print("[2] Đã kiểm tra loại trừ hoàn toàn các món rác/sự kiện/hoàn trùng icon")
	
	# 3. Phân loại chuẩn 0..3
	for mid in items:
		var cat: int = PotionShopScript.category_of(mid)
		assert(cat >= 0 and cat <= 3, "Thuốc Dược Điếm phải thuộc nhóm 0..3: %s" % mid)
	print("[3] Tất cả 27 món Dược Điếm đều thuộc 4 nhóm công dụng chuẩn VLTK 1")
	
	# 4. Danh mục Tống Kim
	var sj: Array[String] = PotionShopScript.songjin_items()
	print("[4] Số lượng vật phẩm Tống Kim: ", sj.size())
	assert(sj.size() == 18, "Vật phẩm Tống Kim phải có 18 món")
	assert(not sj.has("1_0_cuuchuyen"), "Cửu Chuyển Hoàn Hồn Đan không được trùng trong Tống Kim")
	assert(not sj.has("1_1_odau"), "Ô Đầu Hoàn Thần Đan không được trùng trong Tống Kim")
	
	# 5. Khởi tạo giao diện PotionShopWindow
	var win = PotionShopWindowScript.new()
	assert(win != null, "Khởi tạo PotionShopWindow thành công")
	add_child(win)
	
	# Tab 0: Dược Điếm
	win._select_tab(0)
	print("[5] Grid child count Tab Dược Điếm (gồm ô đệm sang hàng): ", win._grid.get_child_count())
	assert(win._grid.get_child_count() >= 27, "Tab Dược Điếm phải có đủ các ô thuốc")
	
	# Tab 1: Tống Kim
	win._select_tab(1)
	print("[5] Grid child count Tab Tống Kim: ", win._grid.get_child_count())
	assert(win._grid.get_child_count() == 18, "Tab Tống Kim phải có đúng 18 món")
	win.queue_free()
	
	# 6. Kiểm tra Thổ Địa Phù x2000 (Kỳ Trân Các - 6_1_438)
	var tdp2000: ItemInstance = ItemGenerator.generate_misc("6_1_438")
	assert(tdp2000 != null, "Sinh Thổ Địa Phù 6_1_438 thành công")
	assert(tdp2000.count == 2000, "Thổ Địa Phù trên Kỳ Trân Các phải có số lần sử dụng là 2000 (hiện tại: %d)" % tdp2000.count)
	print("[6] Thổ Địa Phù Kỳ Trân Các có đúng count = 2000: PASS")
	
	# 7. Kiểm tra Thổ Địa Phù x1 (Dược Điếm - 5_0_0)
	var tdp1: ItemInstance = ItemGenerator.generate_misc("5_0_0")
	assert(tdp1 != null, "Sinh Thổ Địa Phù 5_0_0 thành công")
	assert(tdp1.count == 1, "Thổ Địa Phù x1 phải có count = 1")
	print("[7] Thổ Địa Phù x1 có đúng count = 1: PASS")
	
	# 8. Kiểm tra mua Thổ Địa Phù x1 tại PotionShop
	var profile: PlayerProfile = PlayerProfile.new()
	profile.gold = 50000
	var buy_res := PotionShopScript.buy(profile, "5_0_0", 2)
	assert(buy_res["ok"] == true, "Mua Thổ Địa Phù x1 tại Hiệu Thuốc phải thành công")
	assert(buy_res["bought"] == 2, "Mua đúng số lượng 2")
	assert(profile.gold == 50000 - 1000, "Trừ đúng 1000 lượng cho 2 lá phù (500 lượng/lá)")
	print("[8] Mua Thổ Địa Phù x1 tại Hiệu Thuốc thành công: PASS")
	
	# 9. Kiểm tra cơ chế tiêu hao Thổ Địa Phù x2000 (không còn vô hạn)
	profile.inventory.clear()
	profile.add_item(tdp2000)
	var dummy_player = Node.new()
	add_child(dummy_player)
	
	var use_res := ItemConsumer.use_item(profile, tdp2000, dummy_player)
	assert(use_res["ok"] == true, "Dùng Thổ Địa Phù thành công")
	assert(tdp2000.count == 1999, "Dùng Thổ Địa Phù x2000 phải trừ 1 còn 1999 (hiện tại: %d)" % tdp2000.count)
	print("[9] Thổ Địa Phù tiêu hao đúng 1 lượt sau khi dùng (còn 1999/2000): PASS")
	
	dummy_player.queue_free()
	print("\n--- TẤT CẢ TEST HIỆU THUỐC & THỔ ĐỊA PHÙ ĐÃ HOÀN THÀNH XUẤT SẮC! ---")
	get_tree().quit(0)

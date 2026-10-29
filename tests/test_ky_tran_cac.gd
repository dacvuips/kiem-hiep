extends Node

const KyTranCacShop = preload("res://systems/items/ky_tran_cac_shop.gd")
const KyTranCacWindow = preload("res://ui/shop/ky_tran_cac_window.gd")

func _ready() -> void:
	print("\n--- BẮT ĐẦU TEST KỲ TRÂN CÁC ---")
	test_catalog_structure()
	test_item_generation()
	test_buy_single_item()
	test_buy_with_insufficient_xu()
	test_cart_flow()
	test_window_instantiation()
	test_character_hub_integration()
	print("\n--- TẤT CẢ TEST KỲ TRÂN CÁC ĐÃ HOÀN THÀNH XUẤT SẮC! ---")
	get_tree().quit(0)

func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		printerr("FAIL: ", msg)
		get_tree().quit(1)
	else:
		print("PASS: ", msg)

func test_catalog_structure() -> void:
	print("\n[1] Kiểm tra danh mục và phân trang Kỳ Trân Các...")
	var cats: Array[String] = KyTranCacShop.get_categories()
	assert_true(cats.size() == 2, "Kỳ Trân Các có đúng 2 danh mục: Vật Phẩm và Tính Năng")
	assert_true(cats[0] == "Vật Phẩm" and cats[1] == "Tính Năng", "Tên 2 danh mục chuẩn")

	# Tab Vật Phẩm có 2 trang
	var vp_pages: int = KyTranCacShop.get_page_count(0)
	assert_true(vp_pages == 2, "Tab Vật Phẩm có 2 trang (chuẩn theo ảnh mẫu)")

	var vp_p1: Array[Dictionary] = KyTranCacShop.get_items_for_page(0, 0)
	assert_true(vp_p1.size() == 15, "Trang 1 của Vật Phẩm có đúng 15 món đồ")

	var vp_p2: Array[Dictionary] = KyTranCacShop.get_items_for_page(0, 1)
	assert_true(vp_p2.size() == 1, "Trang 2 của Vật Phẩm có 1 món đồ (Trống Khải Hoàn)")
	assert_true(vp_p2[0]["name"] == "Trống Khải Hoàn", "Món đầu trang 2 là Trống Khải Hoàn")

	# Tab Tính Năng có 3 trang
	var tn_pages: int = KyTranCacShop.get_page_count(1)
	assert_true(tn_pages == 3, "Tab Tính Năng có 3 trang")

	var tn_p1: Array[Dictionary] = KyTranCacShop.get_items_for_page(1, 0)
	assert_true(tn_p1.size() == 15, "Trang 1 của Tính Năng có đúng 15 món đồ")

	var tn_p2: Array[Dictionary] = KyTranCacShop.get_items_for_page(1, 1)
	assert_true(tn_p2.size() == 15, "Trang 2 của Tính Năng có đúng 15 Bí Kíp 180 môn phái")

	var tn_p3: Array[Dictionary] = KyTranCacShop.get_items_for_page(1, 2)
	assert_true(tn_p3.size() == 3, "Trang 3 của Tính Năng có 3 món đồ")

func test_item_generation() -> void:
	print("\n[2] Kiểm tra sinh vật phẩm từ ItemDatabase...")
	var all_items: Array[Dictionary] = []
	all_items.append_array(KyTranCacShop.get_items_for_page(0, 0))
	all_items.append_array(KyTranCacShop.get_items_for_page(0, 1))
	all_items.append_array(KyTranCacShop.get_items_for_page(1, 0))
	all_items.append_array(KyTranCacShop.get_items_for_page(1, 1))
	all_items.append_array(KyTranCacShop.get_items_for_page(1, 2))

	for it in all_items:
		var item_id: String = str(it.get("id"))
		var item_name: String = str(it.get("name"))
		var rec: Dictionary = ItemDatabase.get_misc(item_id)
		assert_true(not rec.is_empty(), "Item ID '%s' (%s) tồn tại trong ItemDatabase" % [item_id, item_name])
		var inst: ItemInstance = ItemGenerator.generate_misc(item_id)
		assert_true(inst != null, "ItemGenerator tạo thành công món '%s'" % item_name)

func test_buy_single_item() -> void:
	print("\n[3] Kiểm tra luồng mua 1 vật phẩm...")
	var profile: PlayerProfile = PlayerProfile.new()
	profile.xu = 100
	var initial_xu: int = profile.xu

	# Mua 1 Tiên Thảo Lộ đặc biệt (12 Xu)
	var res: Dictionary = KyTranCacShop.buy_item(profile, "6_1_1181", 1, 12, "Tiên Thảo Lộ đặc biệt")
	assert_true(res.get("ok", false), "Mua thành công Tiên Thảo Lộ đặc biệt")
	assert_true(profile.xu == initial_xu - 12, "Số Xu bị trừ chính xác: còn %d Xu" % profile.xu)
	assert_true(profile.inventory.size() > 0, "Vật phẩm đã được thêm vào hành trang")

	# Mua 3 Thần Hành Phù (20 Xu x 3 = 60 Xu)
	res = KyTranCacShop.buy_item(profile, "6_1_1266", 3, 20, "Thần Hành Phù")
	assert_true(res.get("ok", false), "Mua thành công 3 Thần Hành Phù")
	assert_true(profile.xu == initial_xu - 12 - 60, "Số Xu còn lại: %d Xu" % profile.xu)

func test_buy_with_insufficient_xu() -> void:
	print("\n[4] Kiểm tra trường hợp không đủ Xu...")
	var profile: PlayerProfile = PlayerProfile.new()
	profile.xu = 5

	# Thử mua Tín vật môn phái (200 Xu)
	var res: Dictionary = KyTranCacShop.buy_item(profile, "6_1_1670", 1, 200, "Tín vật môn phái")
	assert_true(not res.get("ok", true), "Không cho phép mua khi thiếu Xu")
	assert_true(res.get("need_xu", false), "Trả về cờ need_xu để gợi ý nạp")
	assert_true(profile.xu == 5, "Xu không bị trừ khi mua thất bại")

func test_cart_flow() -> void:
	print("\n[5] Kiểm tra Giỏ Hàng Kỳ Trân Các...")
	KyTranCacShop.clear_cart()
	assert_true(KyTranCacShop.get_cart().is_empty(), "Giỏ hàng ban đầu trống")

	# Thêm món vào giỏ
	KyTranCacShop.add_to_cart("4_239_1", "Tử Thủy Tinh", 20, 2)
	KyTranCacShop.add_to_cart("6_1_30191", "Chìa Khóa Vàng", 1, 5)

	assert_true(KyTranCacShop.get_cart().size() == 2, "Giỏ hàng có 2 loại món")
	assert_true(KyTranCacShop.get_cart_count() == 7, "Tổng số lượng trong giỏ là 7")
	assert_true(KyTranCacShop.get_cart_total() == 20 * 2 + 1 * 5, "Tổng tiền giỏ hàng là 45 Xu")

	# Sửa số lượng
	KyTranCacShop.update_cart_item_count("6_1_30191", 10)
	assert_true(KyTranCacShop.get_cart_total() == 20 * 2 + 1 * 10, "Tổng tiền cập nhật thành 50 Xu")

	# Xoá món
	KyTranCacShop.remove_from_cart("4_239_1")
	assert_true(KyTranCacShop.get_cart().size() == 1, "Sau khi xóa còn 1 loại món")

	# Mua giỏ hàng
	var profile: PlayerProfile = PlayerProfile.new()
	profile.xu = 100
	var res: Dictionary = KyTranCacShop.buy_cart(profile)
	assert_true(res.get("ok", false), "Thanh toán giỏ hàng thành công")
	assert_true(profile.xu == 90, "Số Xu sau khi thanh toán giỏ hàng là 90")
	assert_true(KyTranCacShop.get_cart().is_empty(), "Giỏ hàng được làm trống sau khi mua hết")

func test_window_instantiation() -> void:
	print("\n[6] Kiểm tra khởi tạo giao diện KyTranCacWindow...")
	var win: KyTranCacWindow = KyTranCacWindow.new()
	assert_true(win != null, "Khởi tạo KyTranCacWindow thành công")
	assert_true(win.custom_minimum_size.x >= 700.0, "Kích thước tối thiểu cửa sổ đạt chuẩn")
	win.queue_free()

func test_character_hub_integration() -> void:
	print("\n[7] Kiểm tra tích hợp Kỳ Trân Các trong Character Hub...")
	var scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	assert_true(scene != null, "Load CharacterHub.tscn thành công")
	var hub = scene.instantiate()
	assert_true(hub != null, "Instantiate CharacterHub thành công")
	add_child(hub)

	var top_btn = hub.find_child("KyTranCacTopButton", true, false)
	assert_true(top_btn != null, "Character Hub có nút Kỳ Trân Các trên TopBar")

	hub.queue_free()

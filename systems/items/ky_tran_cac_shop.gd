class_name KyTranCacShop
extends RefCounted

## KỲ TRÂN CÁC (Kỳ Trân Các / Cash Shop chuẩn VLTK 1):
## Cung cấp giao diện mua sắm các bảo vật, lệnh bài, bí kíp, phù du hành... thanh toán bằng Tiền Xu (Xu).
## Phân loại danh mục:
##   - Tab "Vật Phẩm": các lệnh bài, thủy tinh, chìa khóa, lễ hộp, bảo thạch...
##   - Tab "Tính Năng": các loại phù (thổ địa phù vô hạn, thần hành phù, hồi thành phù), bí kíp, tiên thảo lộ, tử mẫu lệnh...

const SLOTS_PER_PAGE: int = 15
const CATEGORIES: Array[String] = ["Vật Phẩm", "Tính Năng"]

## Danh sách vật phẩm Tab "Vật Phẩm" (2 trang)
const ITEMS_VAT_PHAM: Array[Array] = [
	# Trang 1 / 2 (15 món đầy đủ)
	[
		{"id": "4_489_1", "name": "Lệnh bài Phong Lăng Độ", "price_original": 2, "price": 2},
		{"id": "ky_datau_hoanthanh", "name": "Lệnh Bài Hoàn Thành Dã Tẩu", "price_original": 2, "price": 2},
		{"id": "4_239_1", "name": "Tử Thủy Tinh", "price_original": 20, "price": 20},
		{"id": "6_1_2745", "name": "Lệnh Bài Thủy Tặc", "price_original": 2, "price": 2},
		{"id": "6_1_30191", "name": "Chìa Khóa Vàng", "price_original": 1, "price": 1},
		{"id": "4_240_1", "name": "Lục Thủy Tinh", "price_original": 20, "price": 20},
		{"id": "6_1_2339", "name": "Sát Thủ Giản lễ hộp", "price_original": 4, "price": 4},
		{"id": "ky_tui_thuoc_lac", "name": "Túi Thuốc Lắc", "price_original": 5, "price": 5},
		{"id": "ky_thien_nien_tran_lo", "name": "Thiên Niên Trần Lộ", "price_original": 2, "price": 2},
		{"id": "6_1_1670", "name": "Tín vật môn phái", "price_original": 200, "price": 200},
		{"id": "4_353_1", "name": "Tinh Hồng Bảo Thạch", "price_original": 10, "price": 10},
		{"id": "6_1_1617", "name": "Viêm Đế Lệnh", "price_original": 2, "price": 2},
		{"id": "6_1_30448", "name": "Tính Danh Chi Lệnh", "price_original": 40, "price": 40},
		{"id": "4_238_1", "name": "Lam Thủy Tinh", "price_original": 20, "price": 20},
		{"id": "ky_tui_lenh_bai_datau", "name": "Túi Lệnh Bài Dã Tẩu", "price_original": 15, "price": 15},
	],
	# Trang 2 / 2 (1 món, 14 ô trống)
	[
		{"id": "6_1_2309", "name": "Trống Khải Hoàn", "price_original": 10, "price": 10},
	]
]

## Danh sách vật phẩm Tab "Tính Năng" (3 trang)
const ITEMS_TINH_NANG: Array[Array] = [
	# Trang 1 / 3 (15 món: vật phẩm hỗ trợ + 5 Bí Kíp Dị Kỹ 180 mới)
	[
		{"id": "6_1_1427", "name": "Tử Mẫu Lệnh", "price_original": 10, "price": 10},
		{"id": "6_1_72", "name": "Thiên sơn Bảo Lộ", "price_original": 2, "price": 2},
		{"id": "6_1_438", "name": "Thổ địa phù (sử dụng vô hạn)", "price_original": 20, "price": 20},
		{"id": "6_1_2424", "name": "Đại Thành Bí Kíp 90", "price_original": 100, "price": 100},
		{"id": "6_1_1375", "name": "Thư đặc xá triều đình", "price_original": 5, "price": 5},
		{"id": "6_1_1266", "name": "Thần Hành Phù", "price_original": 20, "price": 20},
		{"id": "6_1_1181", "name": "Tiên Thảo Lộ đặc biệt", "price_original": 12, "price": 12},
		{"id": "6_1_1083", "name": "Hồi thành phù (lớn)", "price_original": 10, "price": 10},
		{"id": "6_1_12", "name": "Bàn Nhược Tâm Kinh", "price_original": 10, "price": 10},
		{"id": "6_1_125", "name": "Quế Hoa Tửu", "price_original": 3, "price": 3},
		{"id": "6_1_18016", "name": "Bí Kíp - Hạo Nhiên Chi Khí", "price_original": 50, "price": 50},
		{"id": "6_1_18017", "name": "Bí Kíp - Mai Danh Ẩn Tính", "price_original": 50, "price": 50},
		{"id": "6_1_18018", "name": "Bí Kíp - Ngạo Huyết Chiến Ý", "price_original": 50, "price": 50},
		{"id": "6_1_18019", "name": "Bí Kíp - Tận Trung Báo Quốc", "price_original": 50, "price": 50},
		{"id": "6_1_18020", "name": "Bí Kíp - Vạn Lý Liêu Nguyên", "price_original": 50, "price": 50},
	],
	# Trang 2 / 3 (15 món: Toàn bộ Bí Kíp 180 của 15 Môn Phái)
	[
		{"id": "6_1_18001", "name": "Bí Kíp 180 - Kim Quyền La Hán", "price_original": 50, "price": 50},
		{"id": "6_1_18002", "name": "Bí Kíp 180 - Chinh Chiến Bát Phương", "price_original": 50, "price": 50},
		{"id": "6_1_18003", "name": "Bí Kíp 180 - Sâm La Độc Hải", "price_original": 50, "price": 50},
		{"id": "6_1_18004", "name": "Bí Kíp 180 - Hấp Tinh Trận", "price_original": 50, "price": 50},
		{"id": "6_1_18005", "name": "Bí Kíp 180 - Ba La Tâm Kinh", "price_original": 50, "price": 50},
		{"id": "6_1_18006", "name": "Bí Kíp 180 - Huyền Băng Vô Tắc", "price_original": 50, "price": 50},
		{"id": "6_1_18007", "name": "Bí Kíp 180 - Liệt Hỏa Phần Thiên", "price_original": 50, "price": 50},
		{"id": "6_1_18008", "name": "Bí Kíp 180 - Ô Y Quyết", "price_original": 50, "price": 50},
		{"id": "6_1_18009", "name": "Bí Kíp 180 - Chân Võ Thất Tiết", "price_original": 50, "price": 50},
		{"id": "6_1_18010", "name": "Bí Kíp 180 - Thiên Cương Khí Kính", "price_original": 50, "price": 50},
		{"id": "6_1_18011", "name": "Bí Kíp 180 - Độc Cô Cửu Kiếm", "price_original": 50, "price": 50},
		{"id": "6_1_18012", "name": "Bí Kíp 180 - Trừ Gian Diệt Nịnh", "price_original": 50, "price": 50},
		{"id": "6_1_18013", "name": "Bí Kíp 180 - Thập Bộ Nhất Sát", "price_original": 50, "price": 50},
		{"id": "6_1_18014", "name": "Bí Kíp 180 - Bôn Lang Thương", "price_original": 50, "price": 50},
		{"id": "6_1_18015", "name": "Bí Kíp 180 - Lôi Đình Nhất Kích", "price_original": 50, "price": 50},
	],
	# Trang 3 / 3 (3 món: Cần câu, Đại Thành Bí Kíp 120, 150)
	[
		{"id": "6_1_3919", "name": "Cần câu", "price_original": 3, "price": 3},
		{"id": "6_1_2425", "name": "Đại Thành Bí Kíp 120", "price_original": 150, "price": 150},
		{"id": "6_1_30446", "name": "Đại Thành Bí Kíp 150", "price_original": 200, "price": 200},
	]
]

## Giỏ hàng hiện tại (chứa danh sách các món đang chọn mua)
static var _cart: Array[Dictionary] = []

static func get_categories() -> Array[String]:
	return CATEGORIES

static func get_page_count(category_index: int) -> int:
	match category_index:
		0:
			return ITEMS_VAT_PHAM.size()
		1:
			return ITEMS_TINH_NANG.size()
		_:
			return 1

static func get_items_for_page(category_index: int, page_index: int) -> Array[Dictionary]:
	var pages: Array[Array] = ITEMS_VAT_PHAM if category_index == 0 else ITEMS_TINH_NANG
	if page_index < 0 or page_index >= pages.size():
		return []
	var res: Array[Dictionary] = []
	for it in pages[page_index]:
		res.append(it)
	return res

## Mua trực tiếp 1 vật phẩm với số lượng `count`
static func buy_item(profile: PlayerProfile, item_id: String, count: int, unit_price: int, item_name: String = "") -> Dictionary:
	if profile == null:
		return {"ok": false, "message": "Không tìm thấy thông tin nhân vật."}
	if count <= 0:
		return {"ok": false, "message": "Số lượng mua không hợp lệ."}
	
	var total_price: int = unit_price * count
	if profile.xu < total_price:
		return {
			"ok": false,
			"need_xu": true,
			"message": "Không đủ Tiền Xu! Cần %d Xu (hiện có: %d Xu)." % [total_price, profile.xu]
		}
	
	# Tạo món đồ và kiểm tra hành trang
	var bought_count: int = 0
	for i in count:
		var item: ItemInstance = ItemGenerator.generate_misc(item_id)
		if item == null:
			# Fallback nếu là đồ có cách generate khác
			item = ItemGenerator.generate_misc(item_id, 0, 0, 1)
		if item == null or not profile.add_item(item):
			break
		bought_count += 1
	
	if bought_count == 0:
		return {"ok": false, "message": "Hành trang đã đầy, không thể chứa thêm vật phẩm."}
	
	var actual_cost: int = unit_price * bought_count
	profile.xu -= actual_cost
	
	var disp_name: String = item_name
	if disp_name == "":
		var rec := ItemDatabase.get_misc(item_id)
		disp_name = str(rec.get("name", item_id))
	
	var msg: String = "Mua thành công %d x %s (tiêu hao %d Xu)." % [bought_count, disp_name, actual_cost]
	if bought_count < count:
		msg += " (Hành trang đầy nên dừng lại)"
	
	return {
		"ok": true,
		"bought": bought_count,
		"cost": actual_cost,
		"message": msg
	}

# ================= CART MANAGEMENT =================
static func get_cart() -> Array[Dictionary]:
	return _cart

static func get_cart_count() -> int:
	var total: int = 0
	for it in _cart:
		total += int(it.get("count", 0))
	return total

static func get_cart_total() -> int:
	var total: int = 0
	for it in _cart:
		total += int(it.get("price", 0)) * int(it.get("count", 0))
	return total

static func add_to_cart(item_id: String, name: String, price: int, count: int = 1) -> void:
	for it in _cart:
		if str(it.get("id", "")) == item_id:
			it["count"] = int(it.get("count", 0)) + count
			return
	_cart.append({
		"id": item_id,
		"name": name,
		"price": price,
		"count": count
	})

static func remove_from_cart(item_id: String) -> void:
	for i in range(_cart.size() - 1, -1, -1):
		if str(_cart[i].get("id", "")) == item_id:
			_cart.remove_at(i)
			return

static func update_cart_item_count(item_id: String, new_count: int) -> void:
	if new_count <= 0:
		remove_from_cart(item_id)
		return
	for it in _cart:
		if str(it.get("id", "")) == item_id:
			it["count"] = new_count
			return

static func clear_cart() -> void:
	_cart.clear()

## Mua toàn bộ giỏ hàng
static func buy_cart(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {"ok": false, "message": "Không tìm thấy thông tin nhân vật."}
	if _cart.is_empty():
		return {"ok": false, "message": "Giỏ hàng đang trống."}
	
	var total_xu: int = get_cart_total()
	if profile.xu < total_xu:
		return {
			"ok": false,
			"need_xu": true,
			"message": "Không đủ Tiền Xu! Giỏ hàng cần %d Xu (hiện có: %d Xu)." % [total_xu, profile.xu]
		}
	
	var total_bought: int = 0
	var total_spent: int = 0
	var remaining_items: Array[Dictionary] = []
	
	for it in _cart:
		var item_id: String = str(it.get("id", ""))
		var count: int = int(it.get("count", 1))
		var price: int = int(it.get("price", 0))
		var bought_for_this: int = 0
		
		for i in count:
			var item: ItemInstance = ItemGenerator.generate_misc(item_id)
			if item == null or not profile.add_item(item):
				break
			bought_for_this += 1
		
		total_bought += bought_for_this
		total_spent += price * bought_for_this
		
		if bought_for_this < count:
			var left: int = count - bought_for_this
			remaining_items.append({
				"id": item_id,
				"name": it.get("name", ""),
				"price": price,
				"count": left
			})
	
	profile.xu -= total_spent
	_cart = remaining_items
	
	if total_bought == 0:
		return {"ok": false, "message": "Hành trang đã đầy, không thể mua món nào trong giỏ hàng."}
	
	var msg: String = "Thanh toán thành công! Đã mua %d vật phẩm, tiêu hao %d Xu." % [total_bought, total_spent]
	if not remaining_items.is_empty():
		msg += " (Một số món chưa mua hết do đầy túi)"
	
	return {
		"ok": true,
		"bought": total_bought,
		"cost": total_spent,
		"message": msg
	}

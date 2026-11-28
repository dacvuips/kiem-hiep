extends Node

const DaTauData = preload("res://systems/quest/da_tau_data.gd")
const DaTauManager = preload("res://systems/quest/da_tau_manager.gd")
const DaTauWindow = preload("res://ui/events/da_tau_window.gd")

func _ready() -> void:
	print("=== TEST HÌNH ẢNH & RỚT MẬT ĐỒ / ĐỊA CHÍ / ĐỊA ĐỒ CHÍ ===")
	_test_source_icons()
	_test_drop_rates()
	_test_pickup_behavior()
	_test_da_tau_window_layout_and_reward_buttons()
	_test_live_cross_window_sync()
	print("PASS ALL: Hình ảnh source gốc, UI DaTauWindow, nút option và sync tức thì hoạt động chuẩn xác!")
	get_tree().quit(0)

func _test_source_icons() -> void:
	for mid in ["6_1_196", "6_1_206", "6_1_213", "4_351_1"]:
		var rec := ItemDatabase.get_misc(mid)
		assert(not rec.is_empty(), "Misc item phải tồn tại: %s" % mid)
		var tex := ItemDatabase.get_icon(rec, false)
		assert(tex != null and tex.get_width() > 0, "Icon phải tải được cho %s" % mid)
		var small_tex := ItemDatabase.get_icon(rec, true)
		assert(small_tex != null and small_tex.get_width() > 0, "Small icon phải tải được cho %s" % mid)
	var sheet := GroundDrop._get_scroll_sheet()
	assert(sheet != null, "Ground sprite item_shenmituzhi.png phải tải được")
	assert(sheet.get_width() == 68 * 7 and sheet.get_height() == 78, "item_shenmituzhi.png phải đủ 7 frame 68x78")
	for btn_name in ["ExpBtn", "Money", "Item", "Lucky", "Random", "PointBtn"]:
		var btex := DaTauWindow._get_datau_btn_texture(btn_name)
		assert(btex != null and btex.get_width() == 48 and btex.get_height() == 48, "Nút VLTK Spr/datau/%s.png phải tải được (48x48)" % btn_name)
	print("  [1] PASS: Tải đủ ảnh gốc vật phẩm, ground sprite 7 frame và 6 nút Spr/datau (48x48).")

func _test_drop_rates() -> void:
	var dd_lv30 := 0
	var md_lv30 := 0
	var n_normal := 4000
	for i in n_normal:
		for d in DropTable.roll(30, 0, 0):
			if str(d.get("type", "")) == "item":
				var it: ItemInstance = d["item"]
				if it.misc_id == DropTable.MISC_DIA_DO_CHI:
					dd_lv30 += 1
				elif it.misc_id == DropTable.MISC_MAT_DO:
					md_lv30 += 1
	var dd_rate := float(dd_lv30) / float(n_normal)
	print("  [2a] Quái thường lv30 (%d kills): Địa đồ chí = %d (%.2f%%), Mật đồ thần bí = %d (%.3f%%)" % [
		n_normal, dd_lv30, dd_rate * 100.0, md_lv30, float(md_lv30) / float(n_normal) * 100.0
	])
	assert(dd_rate >= 0.015 and dd_rate <= 0.055, "Địa đồ chí lv30 phải quanh 3.125%%")
	assert(md_lv30 >= 1, "Mật đồ thần bí phải có rớt ở quái thường")

	var dd_lv90 := 0
	for i in 2000:
		for d in DropTable.roll(90, 0, 0):
			if str(d.get("type", "")) == "item" and (d["item"] as ItemInstance).misc_id == DropTable.MISC_DIA_DO_CHI:
				dd_lv90 += 1
	var dd90_rate := float(dd_lv90) / 2000.0
	print("  [2b] Quái thường lv90 (2000 kills): Địa đồ chí = %d (%.2f%%)" % [dd_lv90, dd90_rate * 100.0])
	assert(dd90_rate >= 0.04 and dd90_rate <= 0.095, "Địa đồ chí lv90 phải quanh 6.25%%-7.5%%")

	var mc_boss := 0
	for i in 500:
		for d in DropTable.roll_blue_boss(40, 0, 0):
			if str(d.get("type", "")) == "item" and (d["item"] as ItemInstance).misc_id == DropTable.MISC_MAT_CHI:
				mc_boss += 1
	print("  [2c] Boss xanh lv40 (500 kills): Mật chí (6_1_213) = %d cuộn" % mc_boss)
	assert(mc_boss >= 40, "Boss xanh lv40 phải rớt nhiều Mật chí (~21.6%%/boss)")

	assert(is_equal_approx(DaTauData.get_diadochi_rate(75), 0.075), "Map 9x (75) phải dùng rate 7.5%% từ npcdroprate90.ini")
	assert(is_equal_approx(DaTauData.get_matdo_rate(20), 0.00606), "Map 1x (20) phải dùng rate 0.606%% từ npcdroprate10.ini")

func _test_pickup_behavior() -> void:
	var prof := PlayerProfile.new()
	prof.display_name = "TestScrollPickup"
	prof.level = 70
	DaTauManager.reset_daily_if_needed(prof)
	prof.da_tau["da_tau_points_session"] = 0
	prof.da_tau["current_quest"] = {
		"type": 4,
		"level_link": 8,
		"map_id": 70,
		"godot_map_id": 70,
		"map_name": "Vũ Lăng Sơn",
		"scroll_type": 1,
		"need_num": 3,
		"done_num": 0,
		"reward_pts": 300000,
		"desc": "Thu thập 3 cuộn Địa đồ chí tại Vũ Lăng Sơn",
	}
	## Sai loại cuộn (Mật chí 6_1_213 trong khi NV cần Địa đồ chí) -> KHÔNG tăng done_num, quy đổi +1 mảnh SHXT
	var wrong := DaTauManager.try_collect_picked_scroll(prof, "6_1_213", 70)
	assert(wrong.get("counted") == false and wrong.get("shxt_added") == true, "Nhặt Mật chí khi quest cần Địa đồ chí phải quy đổi mảnh SHXT")
	assert(int(prof.da_tau.get("da_tau_points_session", 0)) == 1, "da_tau_points_session phải tăng lên 1")
	assert(int(prof.da_tau["current_quest"]["done_num"]) == 0, "done_num vẫn là 0")

	## Sai map (map 20 != 70) -> KHÔNG tăng done_num, quy đổi +1 mảnh SHXT
	var wrong_map := DaTauManager.try_collect_picked_scroll(prof, "6_1_206", 20)
	assert(wrong_map.get("counted") == false and wrong_map.get("shxt_added") == true, "Nhặt sai map phải quy đổi mảnh SHXT")
	assert(int(prof.da_tau.get("da_tau_points_session", 0)) == 2, "da_tau_points_session phải tăng lên 2")

	## Đúng map (70) & đúng loại (6_1_206) -> tăng done_num
	var ok := DaTauManager.try_collect_picked_scroll(prof, "6_1_206", 70)
	assert(ok.get("counted") == true and ok.get("done") == 1, "Nhặt đúng Địa đồ chí trên đúng map phải tăng tiến độ Dã Tẩu")
	assert(int(prof.da_tau.get("da_tau_points_session", 0)) == 2, "Nhặt đúng nhiệm vụ thì không đổi thành mảnh SHXT")

	## Test trực tiếp GroundDrop._pick_up: 6_1_206 KHÔNG bao giờ vào inventory!
	var fake_player := Node2D.new()
	add_child(fake_player)
	GameManager.local_profile = prof
	GameManager.field_map = {"id": 70, "name": "Vũ Lăng Sơn"}
	var gd := GroundDrop.new()
	gd.item = ItemGenerator.generate_misc("6_1_206", 1, 0, 1)
	add_child(gd)
	gd._pick_up(fake_player)
	assert(DaTauManager.count_bag_scrolls(prof, 1) == 0, "6_1_206 KHÔNG được nằm trong hành trang sau khi nhặt")
	assert(int(prof.da_tau["current_quest"]["done_num"]) == 2, "Dã Tẩu phải ghi nhận done_num = 2 sau khi nhặt GroundDrop 6_1_206")

	## Trong khi đó 6_1_196 (Mật đồ thần bí) LÀ item hành trang bình thường
	var gd_matdo := GroundDrop.new()
	gd_matdo.item = ItemGenerator.generate_misc("6_1_196", 1, 0, 1)
	add_child(gd_matdo)
	gd_matdo._pick_up(fake_player)
	var bag_matdo := 0
	for it in prof.inventory:
		if it != null and it.misc_id == "6_1_196":
			bag_matdo += maxi(it.count, 1)
	assert(bag_matdo == 1, "Mật đồ thần bí (6_1_196) phải vào hành trang bình thường")
	fake_player.queue_free()
	print("  [3] PASS: Nhặt Địa đồ chí/Mật chí ghi nhận trực tiếp Dã Tẩu (hoặc +1 SHXT), không vào túi; Mật đồ vào túi bình thường.")

func _test_da_tau_window_layout_and_reward_buttons() -> void:
	## 1. Kiểm tra ánh xạ nút VLTK gốc
	assert(DaTauWindow._resolve_datau_btn_name({"type": "exp"}) == "ExpBtn")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "gold"}) == "Money")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "misc", "misc_id": "4_238_1"}) == "Lucky")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "misc", "misc_id": "4_239_1"}) == "Lucky")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "misc", "misc_id": "4_240_1"}) == "Lucky")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "misc", "misc_id": "4_353_1"}) == "Lucky")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "equip"}) == "Item")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "misc", "misc_id": "6_1_71"}) == "Item")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "item_thaiy"}) == "Item")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "misc", "misc_id": "6_1_1476"}) == "Random")
	assert(DaTauWindow._resolve_datau_btn_name({"type": "point"}) == "PointBtn")

	## 2. Kiểm tra bố cục modal Dã Tẩu (ảnh 1)
	var prof := PlayerProfile.new()
	prof.display_name = "TestDaTauUI"
	prof.level = 70
	DaTauManager.reset_daily_if_needed(prof)
	prof.da_tau["done_today"] = 1
	prof.da_tau["current_quest"] = {
		"type": 4,
		"level_link": 8,
		"map_id": 70,
		"godot_map_id": 70,
		"map_name": "Vũ Lăng Sơn",
		"scroll_type": 1,
		"need_num": 5,
		"done_num": 0,
		"reward_pts": 800000,
		"desc": "Thu thập 5 cuộn Địa đồ chí tại Vũ Lăng Sơn",
	}
	var win := DaTauWindow.new(prof)
	add_child(win)
	var all_labels: Array[String] = []
	var stack: Array[Node] = [win]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Label:
			all_labels.append((cur as Label).text)
		for c in cur.get_children():
			stack.append(c)
	var joined := "\n".join(all_labels)
	assert(joined.contains("Nhiệm Vụ #2 — Thu thập 5 cuộn Địa đồ chí tại Vũ Lăng Sơn"), "Header phải gộp desc: 'Nhiệm Vụ #2 — Thu thập ...'")
	assert(not joined.contains("Thu Thập Địa Đồ / Mật Chí"), "Không được còn tiêu đề loại cũ 'Thu Thập Địa Đồ / Mật Chí'")
	assert(not joined.contains("Thưởng hoàn thành:"), "Không được còn dòng 'Thưởng hoàn thành: +... Điểm Dã Tẩu...'")
	assert(not joined.contains("Địa đồ chí (Thần bí đồ chí)"), "Không được còn thẻ Địa đồ chí / Tỉ lệ rớt ở dưới")
	assert(not joined.contains("Tỉ lệ rớt nguồn gốc"), "Không được còn dòng Tỉ lệ rớt nguồn gốc ở dưới")
	win.queue_free()

	## 3. Kiểm tra 3 nút phần thưởng hiển thị TextureButton ảnh Spr/datau/*.png
	prof.da_tau["current_quest"]["done_num"] = 5
	prof.da_tau["pending_options"] = [
		{"type": "exp", "name": "Kinh Nghiệm", "btn_icon": "ExpBtn", "amount": 10000, "desc": "+10.000 EXP"},
		{"type": "misc", "misc_id": "4_238_1", "name": "Lam Thủy Tinh", "btn_icon": "Lucky", "quantity": 1, "desc": "Lam Thủy Tinh ×1"},
		{"type": "gold", "name": "Ngân Lượng", "btn_icon": "Money", "amount": 50000, "desc": "+50.000 Bạc"},
	]
	var win_rew := DaTauWindow.new(prof)
	add_child(win_rew)
	var tex_btn_count := 0
	var rstack: Array[Node] = [win_rew]
	while not rstack.is_empty():
		var cur: Node = rstack.pop_back()
		if cur is TextureButton and (cur as TextureButton).texture_normal != null:
			tex_btn_count += 1
		for c in cur.get_children():
			rstack.append(c)
	assert(tex_btn_count == 3, "Phải có đúng 3 TextureButton ảnh Spr/datau cho 3 option thưởng (hiện có %d)" % tex_btn_count)
	win_rew.queue_free()
	print("  [4] PASS: Bố cục modal Dã Tẩu (ảnh 1) & 3 nút chọn thưởng Spr/datau hoạt động chuẩn.")

func _collect_texts(root_node: Node) -> String:
	var out: Array[String] = []
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Label:
			out.append((cur as Label).text)
		elif cur is Button:
			out.append((cur as Button).text)
		for c in cur.get_children():
			stack.append(c)
	return "\n".join(out)

func _test_live_cross_window_sync() -> void:
	var prof := PlayerProfile.new()
	prof.display_name = "TestLiveSync"
	prof.level = 70
	prof.xu = 20
	GameManager.local_profile = prof
	DaTauManager.reset_daily_if_needed(prof)
	prof.da_tau["skip_today"] = 1
	prof.da_tau["done_today"] = 2
	prof.da_tau["current_quest"] = {
		"type": 4,
		"level_link": 8,
		"map_id": 70,
		"godot_map_id": 70,
		"map_name": "Vũ Lăng Sơn",
		"scroll_type": 1,
		"need_num": 5,
		"done_num": 0,
		"reward_pts": 800000,
		"desc": "Thu thập 5 cuộn Địa đồ chí tại Vũ Lăng Sơn",
	}

	var dt_win := DaTauWindow.open(self, prof)
	var before_txt := _collect_texts(dt_win)
	assert(before_txt.contains("Lệnh bài hủy: 0"), "Ban đầu Dã Tẩu phải hiện Lệnh bài hủy: 0")
	assert(before_txt.contains("❌ Hủy Nhiệm Vụ (Về #1)"), "Ban đầu nút hủy phải cảnh báo Về #1")

	## Mở thêm Kỳ Trân Các & Hành Trang song song với Dã Tẩu rồi mua Lệnh Bài Hủy Dã Tẩu
	var ktc_win := KyTranCacWindow.open(self, Callable(), prof) as KyTranCacWindow
	var inv_popup := InventoryPopup.open(self, prof, Callable(), false)
	var buy_res: Dictionary = KyTranCacShop.buy_item(prof, "ky_datau_huy", 2, 1, "Lệnh Bài Hủy Dã Tẩu")
	assert(buy_res.get("ok", false), "Mua Lệnh Bài Hủy Dã Tẩu phải thành công")
	SaveManager.save_profile(prof, true)

	## Ngay lập tức kiểm tra các cửa sổ đang mở mà KHÔNG cần đóng/mở lại
	var after_txt := _collect_texts(dt_win)
	assert(after_txt.contains("Lệnh bài hủy: 2"), "Dã Tẩu phải cập nhật NGAY lập tức thành Lệnh bài hủy: 2")
	assert(after_txt.contains("🎫 Hủy Miễn Phí (Lệnh Bài ×2)"), "Nút hủy phải đổi NGAY thành 🎫 Hủy Miễn Phí (Lệnh Bài ×2)")
	assert(ktc_win._xu_label.text.contains("18"), "Kỳ Trân Các phải cập nhật NGAY Xu còn lại = 18")

	## Test SocialWindow.present đưa DaTauWindow có sẵn lên trước cũng tự refresh
	var cancel_res := DaTauManager.cancel_quest(prof)
	assert(cancel_res.get("ok") == true and cancel_res.get("item_consumed") == true, "Hủy bằng Lệnh Bài phải thành công và trừ 1 lệnh bài")
	assert(DaTauManager.count_free_cancel_items(prof) == 1, "Còn lại 1 Lệnh Bài Hủy")
	DaTauWindow.open(self, prof)
	var presented_txt := _collect_texts(dt_win)
	assert(presented_txt.contains("Nhận Nhiệm Vụ Dã Tẩu"), "SocialWindow.present phải refresh DaTauWindow khi đưa lên trước")
	assert(presented_txt.contains("Lệnh bài hủy: 1"), "Dã Tẩu phải hiển thị còn 1 lệnh bài hủy")

	## Cập nhật tiền/xu ở Tiền Trang -> SaveManager.save_profile phải sync Kỳ Trân Các & mọi cửa sổ tức thì
	prof.xu = 50
	SaveManager.save_profile(prof, true)
	assert(ktc_win._xu_label.text.contains("50"), "Kỳ Trân Các phải sync NGAY khi Xu đổi thành 50")

	var tt_win := TienTrangWindow.open(self, Callable(), prof) as TienTrangWindow
	assert(tt_win._xu_label.text.contains("50"), "Tiền Trang phải hiển thị đúng Xu = 50")
	prof.xu = 75
	SaveManager.save_profile(prof, true)
	assert(tt_win._xu_label.text.contains("75"), "Tiền Trang phải sync NGAY khi Xu đổi thành 75")

	dt_win.close_requested.emit()
	tt_win.close_requested.emit()
	inv_popup.queue_free()
	print("  [5] PASS: Mua Lệnh Bài Hủy ở Kỳ Trân Các và mọi thay đổi SaveManager/GM đồng bộ tức thì sang Dã Tẩu & các cửa sổ khác.")

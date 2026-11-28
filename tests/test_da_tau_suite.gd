extends Node
## Suite test toàn diện cho tính năng Dã Tẩu (TaskLink)

const DaTauData = preload("res://systems/quest/da_tau_data.gd")
const DaTauManager = preload("res://systems/quest/da_tau_manager.gd")
const DaTauWindow = preload("res://ui/events/da_tau_window.gd")
const DaTauSubmitWindow = preload("res://ui/events/da_tau_submit_window.gd")

func _ready() -> void:
	print("==================================================")
	print("--- BẮT ĐẦU TEST TOÀN BỘ HỆ THỐNG DÃ TẨU ---")
	print("==================================================")
	_clean_test_files()
	test_profile_da_tau()
	test_quest_lifecycle()
	test_skip_limit()
	test_cancel_with_item_and_reset()
	test_instant_complete_with_item()
	test_scroll_drop()
	test_type3_and_type2_scrolls()
	test_type5_exp_and_type6_shxt()
	test_all_levellink_maps()
	test_milestones()
	test_character_hub_integration()
	test_teleport_callback()
	test_disk_persistence()
	test_reward_items_in_bag_and_server_sync()
	_clean_test_files()
	print("==================================================")
	print("🎉 TẤT CẢ TEST DÃ TẨU ĐỀU PASS THÀNH CÔNG! 🎉")
	print("==================================================")
	get_tree().quit(0)

func _clean_test_files() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.begins_with("da_tau_records_"):
				if file_name.contains("Test") or file_name.contains("ĐạiHiệp") or file_name.contains("default") or file_name.contains("PersistentHero"):
					dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

func test_profile_da_tau() -> void:
	print("[1] Test PlayerProfile serialize/deserialize da_tau...")
	var prof := PlayerProfile.new()
	prof.display_name = "ĐạiHiệpTest"
	prof.level = 85
	DaTauManager.reset_daily_if_needed(prof)
	assert(prof.da_tau is Dictionary, "da_tau phải là Dictionary")
	assert(prof.da_tau["done_today"] == 0, "done_today khởi đầu phải là 0")
	assert(prof.da_tau["skip_today"] == 0, "skip_today khởi đầu phải là 0")

	var d := prof.to_dict()
	assert(d.has("da_tau"), "to_dict phải chứa key da_tau")
	var loaded := PlayerProfile.from_dict(d)
	assert(loaded.da_tau is Dictionary, "from_dict phải phục hồi da_tau")
	print("  -> PASS: PlayerProfile lưu/tải da_tau chuẩn xác.")

func test_quest_lifecycle() -> void:
	print("[2] Test vòng đời nhận và hoàn thành nhiệm vụ & 3 Option chọn thưởng...")
	var prof := PlayerProfile.new()
	prof.display_name = "Test_Lifecycle"
	prof.level = 60
	DaTauManager.reset_daily_if_needed(prof)

	assert(DaTauManager.can_accept(prof) == true, "Phải có thể nhận nhiệm vụ")
	var q := DaTauManager.accept_quest(prof)
	assert(not q.is_empty(), "Quest tạo ra không được rỗng")
	assert(DaTauManager.can_accept(prof) == false, "Đang có quest thì không thể nhận thêm")

	var cur_q: Variant = DaTauManager.get_current_quest(prof)
	assert(cur_q != null, "get_current_quest phải trả về quest")

	# Mô phỏng hoàn thành tiến độ
	var q_dict := cur_q as Dictionary
	q_dict["done_num"] = q_dict.get("need_num", 1)
	assert(DaTauManager.check_quest_complete(prof) == true, "check_quest_complete phải true khi đủ điều kiện")

	# Test sinh đúng 3 Option chọn 1 trong 3 (chuẩn JX1)
	var options := DaTauManager.get_or_create_reward_options(prof)
	assert(options.size() == 3, "Dã Tẩu phải sinh đúng 3 Option phần thưởng")
	assert(options[0]["type"] == "exp", "Option 1 phải là EXP")
	assert(options[1]["type"] == "gold", "Option 2 phải là Ngân lượng/Bạc")
	assert(options[2].has("name"), "Option 3 phải là Vật phẩm/May mắn")

	# Chọn option 1 (Ngân lượng)
	var old_gold: int = prof.gold
	var rew := DaTauManager.claim_reward_option(prof, 1)
	assert(not rew.is_empty(), "Phải chọn thưởng thành công")
	assert(prof.gold > old_gold, "Tiền phải được cộng khi chọn option Ngân lượng")
	assert(prof.da_tau["done_today"] == 1, "done_today phải tăng lên 1")
	assert(prof.da_tau["current_quest"] == null, "current_quest phải được reset về null")
	print("  -> PASS: Vòng đời nhiệm vụ và cơ chế 3 Option (chọn 1 trong 3) hoạt động hoàn hảo.")

func test_skip_limit() -> void:
	print("[3] Test giới hạn bỏ qua 1 lượt/ngày...")
	var prof := PlayerProfile.new()
	prof.display_name = "Test_SkipLimit"
	prof.level = 50
	DaTauManager.reset_daily_if_needed(prof)

	DaTauManager.accept_quest(prof)
	assert(DaTauManager.get_current_quest(prof) != null, "Đang có quest")

	# Lần 1: Bỏ qua thành công
	var skip1 := DaTauManager.skip_quest(prof)
	assert(skip1 == true, "Lần bỏ qua đầu tiên phải thành công")
	assert(prof.da_tau["current_quest"] == null, "Quest đã bị hủy")
	assert(prof.da_tau["skip_today"] == 1, "skip_today phải là 1")

	# Nhận quest mới
	DaTauManager.accept_quest(prof)
	assert(DaTauManager.get_current_quest(prof) != null, "Đã nhận quest mới")

	# Lần 2: Bỏ qua thất bại vì hết lượt
	var skip2 := DaTauManager.skip_quest(prof)
	assert(skip2 == false, "Lần bỏ qua thứ 2 phải thất bại (chỉ 1 lượt/ngày)")
	assert(prof.da_tau["current_quest"] != null, "Quest vẫn còn nguyên")
	print("  -> PASS: Giới hạn 1 lượt bỏ qua/ngày hoạt động chính xác.")

func test_cancel_with_item_and_reset() -> void:
	print("[3b] Test hủy nhiệm vụ bằng Lệnh Bài Hủy Dã Tẩu và reset về #1 khi không có item...")
	# Kiểm tra item mới trong ItemDatabase & Kỳ Trân Các
	var item_rec := ItemDatabase.get_misc(DaTauData.FREE_CANCEL_ITEM_ID)
	assert(not item_rec.is_empty(), "Item ky_datau_huy phải tồn tại trong ItemDatabase")
	var page2 := KyTranCacShop.get_items_for_page(0, 1)
	var found_in_shop := false
	for entry in page2:
		if str(entry.get("id", "")) == DaTauData.FREE_CANCEL_ITEM_ID:
			found_in_shop = true
			break
	assert(found_in_shop, "Lệnh Bài Hủy Dã Tẩu phải được bán trong Kỳ Trân Các")

	var prof := PlayerProfile.new()
	prof.display_name = "Test_CancelItemReset"
	prof.level = 60
	DaTauManager.reset_daily_if_needed(prof)

	# Mô phỏng đã hoàn thành 5 nhiệm vụ hôm nay (đang chuẩn bị nhận #6)
	prof.da_tau["done_today"] = 5
	prof.da_tau["total_done"] = 12
	prof.da_tau["da_tau_points"] = 50000

	# 1) Lần hủy đầu tiên dùng lượt bỏ miễn phí ngày -> tính tiếp done_today = 6 (+1 chuỗi)
	DaTauManager.accept_quest(prof)
	var res1 := DaTauManager.cancel_quest(prof)
	assert(res1.get("ok") == true and res1.get("mode") == "daily_free", "Hủy lần 1 phải dùng lượt miễn phí ngày")
	assert(prof.da_tau["done_today"] == 6, "Lượt miễn phí ngày phải tính tiếp số nhiệm vụ: done_today = 6")
	assert(prof.da_tau["total_done"] == 13, "Lượt miễn phí ngày phải tăng total_done = 13")
	assert(prof.da_tau["current_quest"] == null, "Quest phải được xóa sau khi hủy")

	# 2) Thêm 2 Lệnh Bài Hủy Dã Tẩu vào hành trang, hết lượt miễn phí ngày -> hủy miễn phí bằng item
	var token := ItemGenerator.generate_misc(DaTauData.FREE_CANCEL_ITEM_ID, 0, 0, 2)
	assert(token != null and prof.add_item(token), "Phải thêm được 2 Lệnh Bài Hủy Dã Tẩu vào hành trang")
	assert(DaTauManager.count_free_cancel_items(prof) == 2, "Phải đếm được 2 Lệnh Bài Hủy Dã Tẩu")

	DaTauManager.accept_quest(prof)
	var preview_item := DaTauManager.get_cancel_preview(prof)
	assert(preview_item.get("mode") == "item_free", "Preview phải báo mode item_free khi có item")
	var res2 := DaTauManager.cancel_quest(prof)
	assert(res2.get("ok") == true and res2.get("mode") == "item_free", "Hủy khi hết lượt ngày nhưng có item phải thành công ở mode item_free")
	assert(res2.get("item_consumed") == true, "Phải tiêu hao 1 item")
	assert(DaTauManager.count_free_cancel_items(prof) == 1, "Số lượng Lệnh Bài Hủy Dã Tẩu phải giảm còn 1")
	assert(prof.da_tau["done_today"] == 7, "Dùng item hủy miễn phí phải tính tiếp done_today = 7")
	assert(prof.da_tau["total_done"] == 14, "Dùng item hủy miễn phí phải tăng total_done = 14")

	# 3) Tiêu nốt 1 item còn lại -> tính tiếp done_today = 8
	DaTauManager.accept_quest(prof)
	var res3 := DaTauManager.cancel_quest(prof)
	assert(res3.get("ok") == true and res3.get("mode") == "item_free", "Hủy bằng item cuối cùng thành công")
	assert(DaTauManager.count_free_cancel_items(prof) == 0, "Đã hết Lệnh Bài Hủy Dã Tẩu trong hành trang")
	assert(prof.da_tau["done_today"] == 8, "done_today phải được tính tiếp thành 8")
	assert(prof.da_tau["total_done"] == 15, "total_done phải được tính tiếp thành 15")

	# 4) Không còn lượt miễn phí và không còn item -> vẫn cho hủy nhưng reset done_today = 0 (làm lại từ #1)
	DaTauManager.accept_quest(prof)
	if DaTauManager.check_quest_complete(prof):
		prof.da_tau["current_quest"] = {"type": 1, "level_link": 1, "desc": "Mua 3 Thái Y Linh Đan", "need_num": 3, "done_num": 0, "reward_pts": 15000}
	var preview_reset := DaTauManager.get_cancel_preview(prof)
	assert(preview_reset.get("mode") == "reset" and preview_reset.get("will_reset") == true, "Preview phải báo will_reset = true")

	# Kiểm tra UI DaTauWindow nút hủy không bị disable khi mode == reset
	var dummy_host := Node.new()
	add_child(dummy_host)
	var win := DaTauWindow.new(prof)
	dummy_host.add_child(win)
	var cancel_btn: Button = null
	var stack: Array[Node] = [win]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is Button and curr.text.contains("Hủy"):
			cancel_btn = curr
			break
		for child in curr.get_children():
			stack.append(child)
	assert(cancel_btn != null, "Phải hiển thị nút Hủy khi hết lượt miễn phí và không có item")
	assert(cancel_btn.disabled == false, "Nút Hủy KHÔNG được bị disable")
	dummy_host.queue_free()

	var res4 := DaTauManager.cancel_quest(prof)
	assert(res4.get("ok") == true and res4.get("mode") == "reset", "Hủy không có item vẫn phải thành công với mode reset")
	assert(res4.get("reset_streak") == true, "reset_streak phải là true")
	assert(prof.da_tau["done_today"] == 0, "done_today phải reset về 0 để nhận lại Nhiệm Vụ #1")
	assert(prof.da_tau["current_quest"] == null, "current_quest phải bị xóa")
	assert(prof.da_tau["total_done"] == 15, "total_done phải được giữ nguyên khi reset chuỗi")
	assert(prof.da_tau["da_tau_points"] == 50000, "da_tau_points phải được giữ nguyên")
	print("  -> PASS: Hủy nhiệm vụ bằng item miễn phí và reset về #1 hoạt động chuẩn xác.")

func test_instant_complete_with_item() -> void:
	print("[3c] Test dùng Lệnh Bài Hoàn Thành Dã Tẩu trong modal Dã Tẩu (không dùng trực tiếp trong túi)...")
	var prof := PlayerProfile.new()
	prof.display_name = "Test_InstantComplete"
	prof.level = 60
	prof.strength = 10
	DaTauManager.reset_daily_if_needed(prof)

	var tok := ItemGenerator.generate_misc(DaTauData.INSTANT_COMPLETE_ITEM_ID, 0, 0, 2)
	assert(tok != null and prof.add_item(tok), "Phải thêm được 2 Lệnh Bài Hoàn Thành Dã Tẩu")
	assert(DaTauManager.count_instant_complete_items(prof) == 2, "Phải đếm được 2 Lệnh Bài Hoàn Thành")
	assert(ItemConsumer.is_da_tau_modal_token(tok) == true, "Item phải được nhận diện là token dùng trong modal Dã Tẩu")

	# Dùng từ ItemConsumer (trong túi) KHÔNG được tiêu hao item hay cộng EXP/Gold giả
	var old_exp: int = prof.current_exp
	var old_gold: int = prof.gold
	var bag_res := ItemConsumer.use_item(prof, tok)
	assert(bag_res.get("ok") == false, "Không được phép hoàn thành hoặc tiêu hao Lệnh Bài trực tiếp từ túi")
	assert(DaTauManager.count_instant_complete_items(prof) == 2, "Số lượng Lệnh Bài trong túi phải giữ nguyên 2")
	assert(prof.current_exp == old_exp and prof.gold == old_gold, "Không được cộng EXP/Gold khi bấm từ túi")

	# Khi chưa có quest -> không thể hoàn thành nhanh
	var no_q_res := DaTauManager.instant_complete_quest(prof)
	assert(no_q_res.get("ok") == false and no_q_res.get("reason") == "no_quest", "Chưa có quest thì không được tiêu hao item")
	assert(DaTauManager.count_instant_complete_items(prof) == 2, "Số lượng Lệnh Bài vẫn giữ nguyên 2")

	# Gán 1 quest Type 5 chưa đủ EXP -> dùng Lệnh Bài Hoàn Thành vẫn phải hoàn tất
	prof.da_tau["current_quest"] = {
		"type": 5,
		"level_link": 5,
		"numeric_type": 2,
		"need_value": 9999,
		"reward_pts": 25000,
		"done_num": 0,
		"need_num": 9999,
		"desc": "Tích lũy 9.999 Điểm Kinh Nghiệm",
	}
	assert(DaTauManager.check_quest_complete(prof) == false, "Quest Type 5 ban đầu chưa hoàn thành")

	# Kiểm tra UI DaTauWindow hiển thị nút Dùng Lệnh Bài Hoàn Thành
	var dummy_host := Node.new()
	add_child(dummy_host)
	var win := DaTauWindow.new(prof)
	dummy_host.add_child(win)
	var instant_btn: Button = null
	var stack: Array[Node] = [win]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is Button and curr.text.contains("Dùng Lệnh Bài Hoàn Thành"):
			instant_btn = curr
			break
		for child in curr.get_children():
			stack.append(child)
	assert(instant_btn != null, "DaTauWindow phải hiển thị nút Dùng Lệnh Bài Hoàn Thành khi có item và chưa hoàn thành quest")
	dummy_host.queue_free()

	# Thực hiện hoàn thành nhanh trong modal
	var ic_res := DaTauManager.instant_complete_quest(prof)
	assert(ic_res.get("ok") == true, "instant_complete_quest phải thành công")
	assert(DaTauManager.count_instant_complete_items(prof) == 1, "Số lượng Lệnh Bài phải giảm từ 2 xuống 1")
	assert(DaTauManager.check_quest_complete(prof) == true, "Quest Type 5 phải được đánh dấu hoàn thành ngay")

	# Gọi lại khi đã hoàn thành -> không trừ thêm item
	var dup_res := DaTauManager.instant_complete_quest(prof)
	assert(dup_res.get("ok") == false and dup_res.get("reason") == "already_complete", "Không được trừ thêm Lệnh Bài khi quest đã hoàn thành")
	assert(DaTauManager.count_instant_complete_items(prof) == 1, "Số lượng Lệnh Bài vẫn phải là 1")

	# Kiểm tra giao diện chọn thưởng: bỏ dòng TỰ ĐỘNG TÍCH LŨY, bỏ Điểm Dã Tẩu Tích Lũy, bỏ nút Chọn Thưởng Này, nhấp hình để chọn
	var reward_host := Node.new()
	add_child(reward_host)
	var rwin := DaTauWindow.new(prof)
	reward_host.add_child(rwin)
	var reward_icon_btns: Array[BaseButton] = []
	var has_auto_pts_lbl := false
	var has_accum_pts_lbl := false
	var has_choose_btn := false
	var rstack: Array[Node] = [rwin._content_box]
	while not rstack.is_empty():
		var curr: Node = rstack.pop_back()
		if curr is Label:
			if curr.text.contains("TỰ ĐỘNG TÍCH LŨY"):
				has_auto_pts_lbl = true
			if curr.text.contains("Điểm Dã Tẩu Tích Lũy"):
				has_accum_pts_lbl = true
		elif curr is Button and curr.text.contains("Chọn Thưởng Này"):
			has_choose_btn = true
		elif curr is TextureButton or (curr is Button and curr.flat):
			reward_icon_btns.append(curr)
		for child in curr.get_children():
			rstack.append(child)
	assert(not has_auto_pts_lbl, "Không được hiển thị dòng TỰ ĐỘNG TÍCH LŨY")
	assert(not has_accum_pts_lbl, "Không được hiển thị Điểm Dã Tẩu Tích Lũy")
	assert(not has_choose_btn, "Không được hiển thị nút Chọn Thưởng Này")
	assert(reward_icon_btns.size() == 3, "Phải có đúng 3 hình ảnh phần thưởng có thể nhấp để chọn")

	# Kiểm tra giá trị EXP / Tiền theo công thức JX1 gốc (reward_pts = 25.000 -> EXP ~7.200..10.800, Tiền ~862..1.437)
	var opts := DaTauManager.get_or_create_reward_options(prof)
	var exp_amt := int(opts[0].get("amount", 0))
	var gold_amt := int(opts[1].get("amount", 0))
	assert(exp_amt >= 7200 and exp_amt <= 10800, "EXP phải theo công thức JX1 tasklink_award.lua (~7.200..10.800), thực tế=%d" % exp_amt)
	assert(gold_amt >= 862 and gold_amt <= 1437, "Tiền phải theo công thức JX1 tasklink_award.lua (~862..1.437), thực tế=%d" % gold_amt)

	reward_icon_btns[0].pressed.emit()
	reward_host.queue_free()

	assert(prof.da_tau["done_today"] == 1, "done_today phải tăng lên 1 sau khi nhấp hình phần thưởng")
	assert(prof.da_tau["total_done"] == 1, "total_done phải tăng lên 1")
	assert(prof.da_tau["current_quest"] == null, "current_quest phải reset về null")
	print("  -> PASS: Lệnh Bài Hoàn Thành Dã Tẩu hoạt động chuẩn trong modal Dã Tẩu.")

func test_scroll_drop() -> void:
	print("[4] Test rớt Địa đồ / Mật chí khi đánh quái...")
	var prof := PlayerProfile.new()
	prof.display_name = "Test_ScrollDrop"
	prof.level = 70
	DaTauManager.reset_daily_if_needed(prof)

	# Gán cưỡng bức 1 quest Type 4 ở map_id = 70 (Vũ Lăng Sơn)
	prof.da_tau["current_quest"] = {
		"type": 4,
		"level_link": 8,
		"map_id": 70,
		"map_name": "Vũ Lăng Sơn",
		"scroll_type": 1,
		"need_num": 5,
		"done_num": 0,
		"reward_pts": 300000,
	}

	# Đánh quái ở sai map (map 2) -> không rớt
	for i in 20:
		DaTauManager.try_drop_scroll(prof, 2)
	assert(prof.da_tau["current_quest"]["done_num"] == 0, "Sai map không được rớt")

	# Đánh quái ở đúng map (map 70) -> tỉ lệ rớt ~0.06 nên lặp nhiều lần
	var dropped := false
	for i in 200:
		if DaTauManager.try_drop_scroll(prof, 70):
			dropped = true
			break
	assert(dropped == true, "Đúng map phải rớt cuộn khi đánh đủ số lượng quái")
	print("  -> PASS: Logic rớt cuộn theo map hoạt động chuẩn xác.")

func test_type3_and_type2_scrolls() -> void:
	print("[4b] Test Type 3 (Cho Dã Tẩu xem trang bị có chỉ số) & Type 2 (Tìm nộp món trang bị/vật phẩm)...")
	var prof := PlayerProfile.new()
	prof.display_name = "Test_Type3Type2"
	prof.level = 80
	DaTauManager.reset_daily_if_needed(prof)

	# --- TEST TYPE 3: CHO DÃ TẨU XEM TRANG BỊ CÓ THUỘC TÍNH (KHÔNG TIÊU HAO ĐỒ) ---
	prof.da_tau["current_quest"] = {
		"type": 3,
		"level_link": 10,
		"magic_code": 85,
		"attrib": "lifemax_v",
		"magic_name": "Tăng sinh lực",
		"min_value": 51,
		"max_value": 100,
		"unit": "điểm",
		"need_num": 1,
		"done_num": 0,
		"reward_pts": 300000,
		"desc": "Cho Dã Tẩu xem trang bị có thuộc tính Tăng sinh lực (51 đến 100điểm)",
	}

	# Khi hành trang và trên người chưa có món đồ nào có thuộc tính này:
	assert(DaTauManager.find_matching_item_for_type3(prof, prof.da_tau["current_quest"]).get("found", false) == false, "Ban đầu chưa có món đồ nào đạt yêu cầu")
	assert(DaTauManager.check_quest_complete(prof) == false, "Chưa có đồ đạt yêu cầu thì check_quest_complete phải false")

	# Tạo 1 món trang bị có dòng lifemax_v = 75 (nằm trong khoảng 51 đến 100)
	var test_ring: ItemInstance = ItemGenerator.generate(3, 0, 1, 0, [], 0, -1) # Hoàng Ngọc Giới Chỉ
	if test_ring != null:
		test_ring.magic.clear()
		test_ring.magic.append({
			"attrib": "lifemax_v",
			"value": [75, -1, 0],
			"name": "Tăng sinh lực",
			"prefix": true
		})
		prof.add_item(test_ring)

	# Kiểm tra lại Type 3 sau khi có đồ
	var match_t3 := DaTauManager.find_matching_item_for_type3(prof, prof.da_tau["current_quest"])
	assert(match_t3.get("found", false) == true, "Phải tìm thấy món trang bị có thuộc tính Tăng sinh lực 75 điểm")
	assert(DaTauManager.check_quest_complete(prof) == false, "Có đồ trong túi nhưng chưa nộp/cho xem qua rương thì check_quest_complete vẫn PHẢI false (không auto lấy trong rương!)")

	# Cho xem món đồ cụ thể (show_specific_item_for_type3)
	var show_res := DaTauManager.show_specific_item_for_type3(prof, test_ring)
	assert(show_res.get("ok") == true, "show_specific_item_for_type3 phải thành công")
	assert(DaTauManager.check_quest_complete(prof) == true, "Sau khi xác nhận cho xem, check_quest_complete mới true")
	# ĐẶC BIỆT: Món đồ vẫn còn nguyên trong túi, không hề bị xóa!
	assert(prof.inventory.has(test_ring), "Type 3 chỉ xem nên món trang bị không bị xóa khỏi hành trang")

	# --- TEST TYPE 2: TÌM MÓN TRANG BỊ / VẬT PHẨM (NỘP TIÊU HAO ĐỒ) ---
	prof.inventory.clear()
	prof.da_tau["current_quest"] = {
		"type": 2,
		"level_link": 10,
		"kind": "equip",
		"detail": 3,
		"particular": 0,
		"item_level": 3,
		"series": -1,
		"item_name": "Phù Dung Thạch Giới Chỉ",
		"need_num": 1,
		"done_num": 0,
		"reward_pts": 300000,
		"desc": "Tìm 1 món Phù Dung Thạch Giới Chỉ đem về cho Dã Tẩu",
	}

	# Khi chưa có đồ:
	assert(DaTauManager.find_matching_item_for_type2(prof, prof.da_tau["current_quest"]) < 0, "Chưa có đồ phù hợp trong túi")
	assert(DaTauManager.check_quest_complete(prof) == false, "Chưa có đồ thì không thể hoàn thành Type 2")

	# Tạo 2 món cùng loại: 1 món target để nộp, 1 món good để giữ lại
	var target_ring: ItemInstance = ItemGenerator.generate(3, 0, 3, 0, [], 0, -1)
	assert(target_ring != null, "Phải tạo được Phù Dung Thạch Giới Chỉ")
	prof.add_item(target_ring)

	var good_ring: ItemInstance = ItemGenerator.generate(3, 0, 3, 0, [], 0, -1)
	good_ring.magic.append({"attrib": "lifemax_v", "value": [200, -1, 0], "name": "Món Xịn Giữ Lại"})
	prof.add_item(good_ring)

	assert(prof.inventory.has(target_ring), "target_ring phải ở trong hành trang")
	assert(prof.inventory.has(good_ring), "good_ring phải ở trong hành trang")

	# Kiểm tra: Có đồ trong hành trang nhưng chưa nộp qua rương nộp đồ -> KHÔNG ĐƯỢC auto hoàn thành!
	assert(DaTauManager.find_matching_item_for_type2(prof, prof.da_tau["current_quest"]) >= 0, "Phải tìm thấy vị trí món đồ trong hành trang")
	assert(DaTauManager.check_quest_complete(prof) == false, "Khi có đồ trong hành trang nhưng chưa nộp, check_quest_complete vẫn PHẢI false!")

	# Thực hiện nộp ĐÚNG món target_ring do người chơi chọn:
	var sub_ok := DaTauManager.submit_specific_item_for_type2(prof, target_ring)
	assert(sub_ok == true, "submit_specific_item_for_type2 phải thành công")
	assert(prof.da_tau["current_quest"]["done_num"] == 1, "done_num phải là 1 sau khi nộp")
	assert(not prof.inventory.has(target_ring), "Món đồ nộp phải bị thu hồi khỏi hành trang!")
	assert(prof.inventory.has(good_ring), "Món xịn muốn giữ lại tuyệt đối KHÔNG bị lấy nhầm!")
	assert(DaTauManager.check_quest_complete(prof) == true, "Sau khi nộp đồ thành công, check_quest_complete mới true")

	# --- TEST RƯƠNG NỘP ĐỒ DA_TAU_SUBMIT_WINDOW (10x6 Ô, HOÀN TRẢ ĐỒ AN TOÀN) ---
	var submit_win := DaTauSubmitWindow.new(prof, prof.da_tau["current_quest"])
	assert(submit_win._chest_container.ROOM_WIDTH == 10, "Rương nộp đồ phải có chiều dài 10 ô")
	assert(submit_win._chest_container.ROOM_HEIGHT == 6, "Rương nộp đồ phải có chiều cao 6 ô")

	# Test chuyển good_ring vào rương nộp rồi đóng cửa sổ -> đồ phải tự động trả về túi
	prof.inventory.erase(good_ring)
	submit_win._chest_container.add_item(good_ring)
	assert(submit_win._chest_container.owns(good_ring), "good_ring phải nằm trong rương nộp")
	assert(not prof.inventory.has(good_ring), "good_ring tạm thời rời khỏi túi")

	# Đóng cửa sổ (hủy / bấm X)
	submit_win.close_requested.emit()
	assert(prof.inventory.has(good_ring), "Khi đóng/hủy rương nộp, good_ring phải được hoàn trả 100% về túi an toàn!")
	submit_win.queue_free()

	print("  -> PASS: Type 3 (chỉ xem trang bị có thuộc tính, không mất đồ), Type 2 (tìm món đồ, nộp đúng món trừ đồ, giữ món xịn) và DaTauSubmitWindow (10x6 ô) hoạt động hoàn hảo.")

func test_type5_exp_and_type6_shxt() -> void:
	print("[4c] Test Type 5 (Tích lũy EXP khi đánh quái) & Type 6 (Nộp Mảnh Sơn Hà Xã Tắc)...")
	var prof := PlayerProfile.new()
	prof.display_name = "Test_Type5Type6"
	prof.level = 50
	DaTauManager.reset_daily_if_needed(prof)

	# 1. Test không có nhiệm vụ nào vừa nhận là hoàn thành ngay lập tức
	for ll in range(1, 10):
		prof.level = ll * 10
		prof.strength = 500
		prof.dexterity = 500
		prof.vitality = 500
		prof.energy = 500
		prof.da_tau["da_tau_points_session"] = 100
		prof.da_tau["current_quest"] = null
		var accepted := DaTauManager.accept_quest(prof)
		assert(not accepted.is_empty(), "Phải nhận được quest ở LevelLink %d" % ll)
		assert(DaTauManager.check_quest_complete(prof) == false, "Nhiệm vụ vừa nhận tuyệt đối KHÔNG được hoàn thành ngay lập tức!")

	# 2. Test tiến độ Type 5: Tích lũy EXP
	prof.da_tau["current_quest"] = {
		"type": 5,
		"level_link": 5,
		"numeric_type": 2,
		"need_value": 50000,
		"need_num": 50000,
		"done_num": 0,
		"reward_pts": 80000,
		"desc": "Tích lũy 50.000 Điểm Kinh Nghiệm",
	}
	assert(DaTauManager.check_quest_complete(prof) == false, "Type 5 ban đầu done_num=0 chưa hoàn thành")
	prof.add_exp(20000)
	var q5 := prof.da_tau["current_quest"] as Dictionary
	assert(q5["done_num"] == 20000, "Cộng 20.000 EXP thì done_num phải bằng 20.000")
	assert(DaTauManager.check_quest_complete(prof) == false, "Chưa đủ 50.000 EXP không được hoàn thành")
	prof.add_exp(30000)
	assert(q5["done_num"] == 50000, "Cộng thêm 30.000 EXP thì done_num phải đạt 50.000")
	assert(DaTauManager.check_quest_complete(prof) == true, "Đủ 50.000 EXP thì Type 5 phải hoàn thành")

	# 3. Test Type 6: Nộp Mảnh Sơn Hà Xã Tắc (chỉ xong khi bấm Nộp Mảnh trừ điểm)
	prof.da_tau["da_tau_points_session"] = 10
	prof.da_tau["current_quest"] = {
		"type": 6,
		"level_link": 3,
		"num": 5,
		"need_num": 5,
		"done_num": 0,
		"reward_pts": 45000,
		"desc": "Nộp 5 Mảnh Sơn Hà Xã Tắc (hiện có: 10)",
	}
	assert(DaTauManager.check_quest_complete(prof) == false, "Có 10 mảnh trong người nhưng chưa nộp thì chưa hoàn thành")
	var sub_fail := DaTauManager.consume_da_tau_points(prof, 20)
	assert(sub_fail == false, "Không đủ điểm nộp thì phải thất bại")
	assert(DaTauManager.check_quest_complete(prof) == false, "Nộp thất bại chưa thể hoàn thành")

	var sub_ok := DaTauManager.consume_da_tau_points(prof, 5)
	assert(sub_ok == true, "Nộp 5 mảnh phải thành công")
	assert(prof.da_tau["da_tau_points_session"] == 5, "Điểm còn lại phải là 5")
	assert(prof.da_tau["current_quest"]["done_num"] == 5, "done_num phải là 5")
	assert(DaTauManager.check_quest_complete(prof) == true, "Sau khi nộp đủ điểm thì Type 6 hoàn thành")
	print("  -> PASS: Type 5 (tích lũy EXP) & Type 6 (nộp mảnh SHXT) hoạt động chính xác, không tự động hoàn thành ngay.")

func test_all_levellink_maps() -> void:
	print("[5] Test toàn bộ map Dã Tẩu theo 20 bậc LevelLink (1-2, 3-5, 6-10, 11-20)...")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	
	var total_unique_maps := {}
	for ll in range(1, 21):
		var maps_in_ll := DaTauData.get_findmaps_for_level_link(ll)
		assert(not maps_in_ll.is_empty(), "LevelLink %d phải có ít nhất 1 map nhiệm vụ" % ll)
		for entry in maps_in_ll:
			var mid: int = entry["godot_map_id"]
			total_unique_maps[mid] = true
			var dir_path := "res://world/maps/map_%d" % mid
			assert(DirAccess.dir_exists_absolute(dir_path), "Thư mục map phải tồn tại: %s" % dir_path)
			var diadochi_rate := DaTauData.get_diadochi_rate(mid)
			var matchi_rate := DaTauData.get_matchi_rate(mid)
			assert(diadochi_rate > 0.0, "Tỉ lệ Địa đồ chí phải > 0 cho map %d" % mid)
			assert(matchi_rate > 0.0, "Tỉ lệ Mật chí phải > 0 cho map %d" % mid)
	
	print("  -> Đã xác thực thành công %d map độc lập qua 20 bậc LevelLink." % total_unique_maps.size())
	assert(total_unique_maps.size() >= 55, "Tổng số map Dã Tẩu phải đạt ít nhất 55 map chuẩn")
	print("  -> PASS: Toàn bộ map LevelLink 1-2, 3-5, 6-10, 11-20 đều tồn tại và có tỉ lệ rớt chuẩn.")

func test_milestones() -> void:
	print("[5] Test mốc thưởng theo tổng số nhiệm vụ (100 -> 8000 HKMP)...")
	var prof := PlayerProfile.new()
	prof.display_name = "Test_Milestones"
	prof.level = 90
	prof.sect_id = "thieu_lam"
	DaTauManager.reset_daily_if_needed(prof)

	# Giả lập save v1 cũ đã từng nhận mốc 0 theo điểm (chỉ 1 nhiệm vụ) -> phải tự reset claimed
	prof.da_tau["milestone_version"] = 1
	prof.da_tau["claimed_milestones"] = [0]
	prof.da_tau["total_done"] = 1
	var claimable_v1 := DaTauManager.get_claimable_milestones(prof)
	assert(claimable_v1.is_empty(), "Mới xong 1 nhiệm vụ không được nhận mốc 100")
	assert(prof.da_tau["claimed_milestones"].is_empty(), "Save v1 phải được migrate reset claimed cũ")

	# Đủ mốc 100 nhiệm vụ (index 0), chưa đủ mốc 300 (index 1)
	prof.da_tau["total_done"] = 150
	var claimable := DaTauManager.get_claimable_milestones(prof)
	assert(claimable == [0], "Chỉ được nhận mốc 0 (100 nhiệm vụ)")

	var gold_before := prof.gold
	var res := DaTauManager.claim_milestone(prof, 0)
	assert(res.get("ok", false), "Nhận mốc 100 thành công")
	assert(0 in prof.da_tau["claimed_milestones"], "Mốc 0 đã lưu vào claimed")
	assert(prof.gold == gold_before + 50000, "Phải cộng 50.000 lượng ở mốc 100")
	assert(prof.inventory.size() >= 1, "Phải nhận được Tiên Thảo Lộ vào hành trang")

	var res_again := DaTauManager.claim_milestone(prof, 0)
	assert(res_again.is_empty(), "Không thể nhận lại mốc đã nhận")

	# Đủ mốc 2000 (Nhu Tình/Hiệp Cốt), 3000 (An Bang), 4000 (Định Quốc), 6000 (Phi Vân), 8000 (HKMP)
	prof.da_tau["total_done"] = 8000
	var count_non_empty := func(it: ItemInstance) -> int:
		var c := 0
		for l in it.magic:
			if str(l.get("attrib", "")) != "":
				c += 1
		return c
	var native_line_count := func(gold_idx: int) -> int:
		var rec := ItemDatabase.get_gold(gold_idx)
		var lines: Array = rec.get("magic", [])
		var c := 0
		for i in mini(lines.size(), ItemInstance.MAX_MAGIC):
			if lines[i] != null:
				c += 1
		return c

	var res_2000 := DaTauManager.claim_milestone(prof, 4)
	assert(res_2000.get("ok", false), "Nhận mốc 2000 thành công")
	var nthc_item: ItemInstance = null
	for it in prof.inventory:
		if it.gold_index >= 185 and it.gold_index <= 192:
			nthc_item = it
			break
	assert(nthc_item != null, "Mốc 2000 phải ra đồ Nhu Tình hoặc Hiệp Cốt")
	assert(count_non_empty.call(nthc_item) == native_line_count.call(nthc_item.gold_index), "Đồ Hoàng Kim mốc 2000 phải giữ đúng số dòng gốc của món đó")

	var res_3000 := DaTauManager.claim_milestone(prof, 5)
	assert(res_3000.get("ok", false), "Nhận mốc 3000 thành công")
	var ab_item := prof.inventory[prof.inventory.size() - 1]
	assert(ab_item.get_display_name().contains("An Bang"), "Mốc 3000 phải ra đồ An Bang")
	assert(count_non_empty.call(ab_item) == native_line_count.call(ab_item.gold_index), "Đồ Hoàng Kim An Bang phải giữ đúng số dòng gốc của món đó")

	var inv_before := prof.inventory.size()
	var res_4000 := DaTauManager.claim_milestone(prof, 6)
	assert(res_4000.get("ok", false), "Nhận mốc 4000 thành công")
	var dq_item := prof.inventory[prof.inventory.size() - 1]
	assert(dq_item.get_display_name().contains("Định Quốc"), "Mốc 4000 phải ra đồ Định Quốc")
	assert(count_non_empty.call(dq_item) == native_line_count.call(dq_item.gold_index), "Đồ Hoàng Kim Định Quốc phải giữ đúng số dòng gốc (2 dòng, không ép thành 6)")

	var hk_a := ItemGenerator.generate_gold_random(0, 101)
	var hk_b := ItemGenerator.generate_gold_random(0, 202)
	assert(hk_a.magic != hk_b.magic, "Chỉ số đồ Hoàng Kim phải roll ngẫu nhiên giữa các lần sinh")

	var res_6000 := DaTauManager.claim_milestone(prof, 7)
	assert(res_6000.get("ok", false), "Nhận mốc 6000 thành công")
	var horse_item := prof.inventory[prof.inventory.size() - 1]
	assert(horse_item.get_display_name().contains("Phi Vân"), "Mốc 6000 phải ra ngựa Phi Vân")

	var prestige_before := prof.prestige
	var res_8000 := DaTauManager.claim_milestone(prof, 8)
	assert(res_8000.get("ok", false), "Nhận mốc 8000 thành công")
	assert(prof.prestige == prestige_before + 200, "Mốc 8000 phải cộng 200 Danh Vọng")
	var hkmp_item := prof.inventory[prof.inventory.size() - 1]
	assert(hkmp_item.gold_index >= 0 and int(ItemDatabase.get_gold(hkmp_item.gold_index).get("menpai", -1)) == 0, "Mốc 8000 Thiếu Lâm phải ra đồ HKMP Thiếu Lâm (menpai=0)")
	assert(count_non_empty.call(hkmp_item) == native_line_count.call(hkmp_item.gold_index), "Đồ HKMP mốc 8000 phải giữ đúng số dòng gốc của món đó")
	assert(prof.inventory.size() == inv_before + 3, "Phải thêm đủ 3 món mốc 4000/6000/8000 vào hành trang")

	# Kiểm tra render Tab Phần Thưởng Tích Lũy trên DaTauWindow không lỗi
	var dummy_host := Node.new()
	add_child(dummy_host)
	var win := DaTauWindow.new(prof)
	dummy_host.add_child(win)
	win._select_tab(1)
	dummy_host.queue_free()
	print("  -> PASS: Hệ thống mốc 100 -> 8000 (Định Quốc, Phi Vân, HKMP) hoạt động hoàn hảo.")

func test_character_hub_integration() -> void:
	print("[6] Test tích hợp nút Dã Tẩu trong CharacterHub...")
	var hub_scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	assert(hub_scene != null, "CharacterHub.tscn phải tồn tại")
	var hub: Node = hub_scene.instantiate()
	assert(hub != null, "CharacterHub instantiate thành công")
	var datau_btn = hub.get_node_or_null("%DaTauButton")
	assert(datau_btn != null, "%DaTauButton phải tồn tại trong CharacterHub.tscn")
	var siege_btn = hub.get_node_or_null("%SiegeButton")
	var manor_btn = hub.get_node_or_null("%ManorButton")
	assert(siege_btn != null and manor_btn != null, "SiegeButton và ManorButton phải tồn tại")

	print("  Vị trí nút:")
	print("    SiegeButton: offset_left = %f, offset_right = %f" % [siege_btn.offset_left, siege_btn.offset_right])
	print("    DaTauButton: offset_left = %f, offset_right = %f" % [datau_btn.offset_left, datau_btn.offset_right])
	print("    ManorButton: offset_left = %f, offset_right = %f" % [manor_btn.offset_left, manor_btn.offset_right])

	assert(datau_btn.offset_left >= siege_btn.offset_right, "Nút Dã Tẩu phải nằm sau nút Công Thành Chiến")
	assert(manor_btn.offset_left >= 1060.0, "Nút Sơn Trang phải ở góc dưới bên phải")

	# Test mở DaTauWindow
	var prof := PlayerProfile.new()
	var win: SocialWindow = DaTauWindow.open(hub, prof)
	assert(win != null, "DaTauWindow.open phải trả về window")
	hub.queue_free()
	print("  -> PASS: Nút Dã Tẩu và DaTauWindow trong CharacterHub hoạt động chuẩn xác.")

func test_teleport_callback() -> void:
	print("[7] Test callback dịch chuyển đến bản đồ làm nhiệm vụ Dã Tẩu...")
	# 1. Kiểm tra MapCatalog.get_by_id
	var entry_20 := MapCatalog.get_by_id(20)
	assert(not entry_20.is_empty(), "Map 20 (Giang Tân Thôn) phải tìm thấy trong MapCatalog")
	assert(entry_20.get("name") == "Giang Tân Thôn", "Tên map phải là Giang Tân Thôn")

	# 2. Tạo mock Callable nhận Dictionary
	var received_entry: Dictionary = {}
	var callback = func(e: Dictionary) -> void:
		received_entry.merge(e, true)

	# 3. Giả lập quest tìm bản đồ (type 4)
	var prof := PlayerProfile.new()
	prof.level = 80
	DaTauManager.reset_daily_if_needed(prof)
	prof.da_tau["current_quest"] = {
		"id": "dt_test",
		"type": 4,
		"title": "Thu thập Mật Chí",
		"desc": "Đến Sa Mạc 1 tìm mật chí",
		"godot_map_id": 225,
		"map_name": "Sa Mạc 1",
		"need_num": 1,
		"done_num": 0,
		"reward_pts": 50,
	}

	var dummy_host := Node.new()
	add_child(dummy_host)
	var win := DaTauWindow.new(prof, callback)
	dummy_host.add_child(win)

	# Tìm nút teleport trong cây node của win
	var btn_found: Button = null
	var stack: Array[Node] = [win]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is Button and curr.text.contains("Sa Mạc 1"):
			btn_found = curr
			break
		for child in curr.get_children():
			stack.append(child)

	assert(btn_found != null, "Phải tìm thấy nút dịch chuyển 'Đến Ngay: Sa Mạc 1'")
	btn_found.emit_signal("pressed")

	assert(not received_entry.is_empty(), "Callback _enter_field_map phải nhận được Dictionary")
	assert(int(received_entry.get("id", 0)) == 225, "ID map nhận được phải là 225")
	assert(received_entry.has("dir"), "Map entry phải có đường dẫn 'dir'")

	dummy_host.queue_free()
	print("  -> PASS: Nút Đến Ngay gọi callback với Dictionary hợp lệ thành công!")

func test_disk_persistence() -> void:
	print("[8] Test lưu trữ bền vững (Disk Persistence) tránh mất nhiệm vụ khi thoát ra vào lại...")
	var test_char_name := "PersistentHero_Test"
	var prof := PlayerProfile.new()
	prof.display_name = test_char_name
	prof.level = 75

	# Dọn dẹp file cũ nếu có
	var rec_path := DaTauManager.get_record_path(prof)
	if FileAccess.file_exists(rec_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(rec_path))

	# 1. Nhận quest mới
	var q := DaTauManager.accept_quest(prof)
	assert(not q.is_empty(), "Phải nhận được quest")
	assert(FileAccess.file_exists(rec_path), "File lưu trữ đĩa user://da_tau_records_...json phải được tạo ngay lập tức")

	# 2. Hoàn thành 1 quest để tăng done_today và total_done
	var q_dict := q as Dictionary
	q_dict["done_num"] = q_dict.get("need_num", 1)
	var rew := DaTauManager.complete_quest(prof)
	assert(not rew.is_empty(), "Phải hoàn thành được quest")
	assert(prof.da_tau["done_today"] == 1, "done_today phải bằng 1")
	assert(prof.da_tau["total_done"] == 1, "total_done phải bằng 1")

	# Nhận tiếp quest số 2
	var q2 := DaTauManager.accept_quest(prof)
	assert(not q2.is_empty(), "Phải nhận được quest thứ 2")
	var q2_desc: String = q2.get("desc", "")

	# 3. Giả lập tình huống THOÁT RA VÀO LẠI (Tạo PlayerProfile hoàn toàn mới với da_tau = {})
	# Mô phỏng tình huống server hoặc hệ thống nạp lại profile trắng da_tau
	var new_session_prof := PlayerProfile.new()
	new_session_prof.display_name = test_char_name
	new_session_prof.level = 75
	assert(new_session_prof.da_tau.is_empty(), "Profile phiên mới khởi đầu da_tau rỗng")

	# Gọi DaTauManager._get_state: phải tự động nạp lại từ file đĩa
	var restored_state := DaTauManager._get_state(new_session_prof)
	assert(restored_state["done_today"] == 1, "Phục hồi thành công done_today = 1 (đã xong quest 1, đang ở quest 2)")
	assert(restored_state["total_done"] == 1, "Phục hồi thành công total_done = 1")
	assert(restored_state["current_quest"] != null, "Phục hồi thành công quest 2 đang làm, không bị mất")
	assert((restored_state["current_quest"] as Dictionary).get("desc") == q2_desc, "Mô tả quest 2 phải khớp chính xác")

	# 4. Test copy_from không bị ghi đè bởi profile rỗng
	var empty_other := PlayerProfile.new()
	empty_other.display_name = test_char_name
	new_session_prof.copy_from(empty_other)
	assert(not new_session_prof.da_tau.is_empty(), "copy_from không được phép xoá da_tau khi other có da_tau rỗng")
	assert(new_session_prof.da_tau["done_today"] == 1, "done_today vẫn phải được giữ nguyên sau copy_from")

	# 5. Test lưu trữ 3 Option phần thưởng khi đang chờ chọn mà thoát game
	var q2_dict := restored_state["current_quest"] as Dictionary
	q2_dict["done_num"] = q2_dict.get("need_num", 1)
	var opts := DaTauManager.get_or_create_reward_options(new_session_prof)
	assert(opts.size() == 3, "Phải sinh đủ 3 options")

	# Thoát game phiên 3: vào lại phải giữ nguyên 3 options đó
	var session_3_prof := PlayerProfile.new()
	session_3_prof.display_name = test_char_name
	session_3_prof.level = 75
	var s3_state := DaTauManager._get_state(session_3_prof)
	assert(s3_state["pending_options"].size() == 3, "3 Options đang chờ phải được phục hồi nguyên vẹn từ đĩa")

	# Chọn option 0 (EXP)
	var s3_exp_before: int = session_3_prof.current_exp
	var claim_res := DaTauManager.claim_reward_option(session_3_prof, 0)
	assert(claim_res["done_today"] == 2, "Hoàn thành nhiệm vụ 2 thành công")
	assert(session_3_prof.current_exp > s3_exp_before or session_3_prof.level > 75, "EXP hoặc Level đã tăng")
	assert(session_3_prof.da_tau["current_quest"] == null, "Nhiệm vụ 2 đã đóng")
	assert(session_3_prof.da_tau["pending_options"].is_empty(), "pending_options đã được xóa sau khi chọn")

	# Dọn dẹp file test
	if FileAccess.file_exists(rec_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(rec_path))

	print("  -> PASS: Dã Tẩu tự động lưu đĩa và phục hồi 100% dữ liệu khi thoát ra vào lại thành công!")

func test_reward_items_in_bag_and_server_sync() -> void:
	print("[9] Test nhận vật phẩm Dã Tẩu vào túi, hiển thị InventoryPopup, rollback khi túi đầy và sync ProfileGuard...")
	var ProfileGuardScript = preload("res://net/server/profile_guard.gd")
	var prof := PlayerProfile.new()
	prof.display_name = "Test_RewardBag"
	prof.level = 80
	DaTauManager.reset_daily_if_needed(prof)

	var dummy_quest := {
		"type": 1,
		"level_link": 8,
		"desc": "Mua 3 Thái Y Linh Đan",
		"need_num": 3,
		"done_num": 3,
		"reward_pts": 120000,
		"gold_cost": 12000,
	}

	# 1. Test tất cả loại Option 2 (misc, item_thaiy, equip) đều vào túi và hiển thị trong InventoryPopup
	var sample_opt2s := [
		{"type": "misc", "misc_id": "6_1_71", "name": "Tiên Thảo Lộ", "quantity": 1, "desc": "Tiên Thảo Lộ ×1"},
		{"type": "misc", "misc_id": "4_238_1", "name": "Lam Thủy Tinh", "quantity": 1, "desc": "Lam Thủy Tinh ×1"},
		{"type": "misc", "misc_id": "6_1_1476", "name": "Bao Hoàng Kim Dã Tẩu", "quantity": 1, "desc": "Bao Hoàng Kim Dã Tẩu ×1"},
		{"type": "item_thaiy", "misc_id": "6_1_71", "name": "Tiên Thảo Lộ", "quantity": 4, "desc": "Dược phẩm: Tiên Thảo Lộ ×4"},
		{"type": "equip", "name": "Trang Bị Dã Tẩu", "quantity": 1, "desc": "Trang bị ngẫu nhiên theo cấp độ"},
	]

	var inv_popup := InventoryPopup.open(self, prof, Callable(), false)
	for opt2 in sample_opt2s:
		prof.da_tau["current_quest"] = dummy_quest.duplicate(true)
		prof.da_tau["pending_options"] = [
			{"type": "exp", "name": "Kinh Nghiệm", "amount": 50000, "desc": "+50.000 EXP"},
			{"type": "gold", "name": "Ngân Lượng", "amount": 10000, "desc": "+10.000 Bạc"},
			opt2.duplicate(true),
		]
		var inv_before := prof.inventory.size()
		var res := DaTauManager.claim_reward_option(prof, 2)
		assert(res.get("ok", false) == true, "Nhận option 2 (%s) phải thành công" % str(opt2.get("name")))
		assert(prof.inventory.size() == inv_before + 1, "Túi phải tăng thêm 1 vật phẩm (%s)" % str(opt2.get("name")))
		var added := prof.inventory[prof.inventory.size() - 1]
		assert(added.room_x >= 0 and added.room_y >= 0 and added.room_bag >= 0, "Vật phẩm thưởng phải được xếp tọa độ hợp lệ trong túi")
		inv_popup.refresh()
		var item_btns := 0
		for child in inv_popup._room.get_children():
			if child is ItemSlotButton:
				item_btns += 1
		assert(item_btns >= 1, "InventoryPopup phải render vật phẩm vừa nhận trong túi")
	inv_popup.queue_free()

	# 2. Test khi hành trang đầy hoàn toàn: claim_reward_option phải trả inventory_full và KHÔNG mất quest
	var full_prof := PlayerProfile.new()
	full_prof.display_name = "Test_FullBag"
	full_prof.level = 50
	DaTauManager.reset_daily_if_needed(full_prof)
	for bag_i in PlayerProfile.OPEN_BAGS:
		for y_i in PlayerProfile.ROOM_HEIGHT:
			for x_i in PlayerProfile.ROOM_WIDTH:
				var filler := ItemGenerator.generate_misc("6_1_71", 0, 0, 1)
				filler.room_bag = bag_i
				filler.room_x = x_i
				filler.room_y = y_i
				full_prof.inventory.append(filler)
	assert(full_prof.find_free_spot_any(Vector2i(1, 1)).z < 0, "Túi test phải đầy 100%")
	full_prof.da_tau["current_quest"] = dummy_quest.duplicate(true)
	full_prof.da_tau["pending_options"] = [
		{"type": "exp", "name": "Kinh Nghiệm", "amount": 50000, "desc": "+50.000 EXP"},
		{"type": "gold", "name": "Ngân Lượng", "amount": 10000, "desc": "+10.000 Bạc"},
		{"type": "misc", "misc_id": "4_238_1", "name": "Lam Thủy Tinh", "quantity": 1, "desc": "Lam Thủy Tinh ×1"},
	]
	var full_res := DaTauManager.claim_reward_option(full_prof, 2)
	assert(full_res.get("ok", false) == false and full_res.get("error", "") == "inventory_full", "Túi đầy phải báo inventory_full")
	assert(full_prof.da_tau["current_quest"] != null, "Túi đầy không được đánh dấu mất quest")
	assert(full_prof.da_tau["pending_options"].size() == 3, "Túi đầy phải giữ nguyên pending_options")

	# 3. Test validate_pending_options chống giả mạo và giữ option hợp lệ
	var srv_prof := PlayerProfile.new()
	srv_prof.display_name = "Test_ServerGuard"
	srv_prof.level = 80
	srv_prof.da_tau = DaTauData.DEFAULT_STATE.duplicate(true)
	srv_prof.da_tau["current_quest"] = dummy_quest.duplicate(true)
	var valid_opts := DaTauManager.get_or_create_reward_options(srv_prof)
	DaTauManager.validate_pending_options(srv_prof)
	assert(srv_prof.da_tau["pending_options"].size() == 3, "validate_pending_options phải giữ nguyên option hợp lệ")

	srv_prof.da_tau["pending_options"] = [
		{"type": "exp", "amount": 999999999},
		{"type": "gold", "amount": 999999999},
		{"type": "misc", "misc_id": "6_1_18001", "quantity": 1},
	]
	DaTauManager.validate_pending_options(srv_prof)
	assert(srv_prof.da_tau["pending_options"].is_empty(), "validate_pending_options phải xóa option bị giả mạo")

	# 4. Test mô phỏng server trao thưởng rồi ProfileGuard.merge không bao giờ làm mất đồ
	srv_prof.da_tau["current_quest"] = dummy_quest.duplicate(true)
	srv_prof.da_tau["pending_options"] = valid_opts
	var srv_claim := DaTauManager.claim_reward_option(srv_prof, 2)
	assert(srv_claim.get("ok", false) == true, "Server trao thưởng Dã Tẩu thành công")
	var server_dict := srv_prof.to_dict()
	var merged: Dictionary = ProfileGuardScript.merge(server_dict, server_dict, 0, false)
	assert((merged.get("inventory", []) as Array).size() == srv_prof.inventory.size(), "Đồ thưởng do server trao phải được ProfileGuard giữ nguyên trong túi")

	print("  -> PASS: Vật phẩm Dã Tẩu vào túi, hiển thị InventoryPopup, rollback túi đầy và đồng bộ server/ProfileGuard chuẩn xác!")

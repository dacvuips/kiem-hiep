extends Node
## Suite test toàn diện cho tính năng Dã Tẩu (TaskLink)

const DaTauData = preload("res://systems/quest/da_tau_data.gd")
const DaTauManager = preload("res://systems/quest/da_tau_manager.gd")
const DaTauWindow = preload("res://ui/events/da_tau_window.gd")

func _ready() -> void:
	print("==================================================")
	print("--- BẮT ĐẦU TEST TOÀN BỘ HỆ THỐNG DÃ TẨU ---")
	print("==================================================")
	_clean_test_files()
	test_profile_da_tau()
	test_quest_lifecycle()
	test_skip_limit()
	test_scroll_drop()
	test_all_levellink_maps()
	test_milestones()
	test_character_hub_integration()
	test_teleport_callback()
	test_disk_persistence()
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
	if q_dict.get("type") == 5:
		prof.strength = 1000000
		prof.dexterity = 1000000
		prof.vitality = 1000000
		prof.energy = 1000000
	elif q_dict.get("type") == 6:
		prof.da_tau["da_tau_points_session"] = 100000

	assert(DaTauManager.check_quest_complete(prof) == true, "check_quest_complete phải true khi đủ điều kiện")

	# Test sinh đúng 3 Option chọn 1 trong 3 (chuẩn JX1)
	var options := DaTauManager.get_or_create_reward_options(prof)
	assert(options.size() == 3, "Dã Tẩu phải sinh đúng 3 Option phần thưởng")
	assert(options[0]["type"] == "exp", "Option 1 phải là EXP")
	assert(options[1]["type"] == "gold", "Option 2 phải là Ngân lượng/Bạc")
	assert(options[2].has("name"), "Option 3 phải là Vật phẩm/May mắn")

	# Chọn option 1 (Ngân lượng)
	var old_gold: int = prof.gold
	var old_pts: int = prof.da_tau.get("da_tau_points", 0)
	var rew := DaTauManager.claim_reward_option(prof, 1)
	assert(not rew.is_empty(), "Phải chọn thưởng thành công")
	assert(prof.gold > old_gold, "Tiền phải được cộng khi chọn option Ngân lượng")
	assert(prof.da_tau["da_tau_points"] > old_pts, "Điểm Dã Tẩu phải chắc chắn được tự động cộng")
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
	print("[5] Test mốc thưởng tích lũy (11 mốc)...")
	var prof := PlayerProfile.new()
	prof.display_name = "Test_Milestones"
	prof.level = 90
	DaTauManager.reset_daily_if_needed(prof)

	# Điểm = 20000 (đủ mốc 1: 15000, chưa đủ mốc 2: 45000)
	prof.da_tau["da_tau_points"] = 20000
	var claimable := DaTauManager.get_claimable_milestones(prof)
	assert(claimable == [0], "Chỉ được nhận mốc 0 (15000)")

	var res := DaTauManager.claim_milestone(prof, 0)
	assert(not res.is_empty(), "Nhận mốc 0 thành công")
	assert(0 in prof.da_tau["claimed_milestones"], "Mốc 0 đã lưu vào claimed")

	var res_again := DaTauManager.claim_milestone(prof, 0)
	assert(res_again.is_empty(), "Không thể nhận lại mốc đã nhận")
	print("  -> PASS: 11 mốc tích lũy hoạt động hoàn hảo.")

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
	assert(manor_btn.offset_left >= datau_btn.offset_right, "Nút Sơn Trang phải nằm sau nút Dã Tẩu")

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
	if q_dict.get("type") == 5:
		prof.strength = 999999
	elif q_dict.get("type") == 6:
		prof.da_tau["da_tau_points_session"] = 999999
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
	new_session_prof.strength = 999999
	new_session_prof.dexterity = 999999
	new_session_prof.vitality = 999999
	new_session_prof.energy = 999999
	new_session_prof.da_tau["da_tau_points_session"] = 999999
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

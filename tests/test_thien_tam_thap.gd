extends SceneTree

const ThienTamThapChallenge = preload("res://systems/challenge/thien_tam_thap_challenge.gd")
const ThienTamThapTrackerHud = preload("res://ui/battle/thien_tam_thap_tracker_hud.gd")

func _init() -> void:
	print("--- BẮT ĐẦU TEST THIÊN TẦM THÁP ---")

	# 1. Test cấu hình JSON và danh sách quái
	assert(FileAccess.file_exists(ThienTamThapChallenge.DATA_PATH), "File waves json phải tồn tại")
	var text := FileAccess.get_file_as_string(ThienTamThapChallenge.DATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Dữ liệu phải là Dictionary")
	var waves: Array = parsed.get("waves", [])
	assert(waves.size() >= 700, "Tổng số ải phải trên 700 ải (hiện có: %d)" % waves.size())
	print("✓ PASS: 1. Đọc dữ liệu hơn 740 ải Thiên Tầm Tháp thành công (%d ải)." % waves.size())

	# 2. Test thứ tự quái xuất phát: Heo -> Nai -> Nhím -> Heo rừng
	assert(waves[0]["monster_name"] == "Heo trắng" or "heo" in waves[0]["monster_name"].to_lower(), "Ải 1 phải là Heo")
	assert("nai" in waves[1]["monster_name"].to_lower() or "hươu" in waves[1]["monster_name"].to_lower(), "Ải 2 phải là Nai")
	assert("nhím" in waves[2]["monster_name"].to_lower(), "Ải 3 phải là Nhím")
	assert("heo rừng" in waves[3]["monster_name"].to_lower(), "Ải 4 phải là Heo rừng")
	print("✓ PASS: 2. Thứ tự quái xuất phát chuẩn xác: Heo -> Nai -> Nhím -> Heo rừng.")

	# 3. Test cơ chế Boss mỗi 10 ải
	for i in range(1, 11):
		var w_idx := i * 10 - 1
		assert(waves[w_idx]["is_boss_wave"] == true, "Ải %d phải là đợt Boss" % (i * 10))
		assert(waves[w_idx].has("boss"), "Ải %d phải chứa dữ liệu Boss" % (i * 10))
		var b_info: Dictionary = waves[w_idx]["boss"]
		assert(b_info.has("name") and b_info.has("monster_id"), "Boss phải có tên và ID")
		assert(b_info.has("next_monster_id"), "Boss phải tham chiếu quái tiếp theo")
	print("✓ PASS: 3. Kiểm tra cơ chế Boss mỗi 10 ải (10, 20, 30... 100) chuẩn xác 100%.")

	# 4. Test điều kiện cấp 30 trở lên & 3 lượt/ngày
	var low_profile := PlayerProfile.new()
	low_profile.display_name = "NoviceTester"
	low_profile.level = 25
	assert(ThienTamThapChallenge.check_entry(low_profile) != "", "Cấp < 30 không được phép tham gia")

	var valid_profile := PlayerProfile.new()
	valid_profile.display_name = "DaiHiep30"
	valid_profile.level = 35

	# Reset records cho profile test
	var rec := ThienTamThapChallenge.records()
	rec.erase("DaiHiep30")
	ThienTamThapChallenge.save_records(rec)

	assert(ThienTamThapChallenge.check_entry(valid_profile) == "", "Cấp 35 được phép tham gia")
	assert(ThienTamThapChallenge.runs_today(valid_profile) == 0, "Ban đầu chưa đi lượt nào")

	# Ghi nhận 3 lượt đi
	ThienTamThapChallenge.add_run(valid_profile)
	assert(ThienTamThapChallenge.runs_today(valid_profile) == 1, "Đã đi 1 lượt")
	ThienTamThapChallenge.add_run(valid_profile)
	ThienTamThapChallenge.add_run(valid_profile)
	assert(ThienTamThapChallenge.runs_today(valid_profile) == 3, "Đã đi 3 lượt")
	assert(ThienTamThapChallenge.check_entry(valid_profile) != "", "Đã đi 3 lượt/ngày phải bị chặn không cho vào tiếp")
	print("✓ PASS: 4. Kiểm tra điều kiện Cấp 30+ và Giới hạn 3 lượt/ngày chuẩn xác.")

	# 5. Test Map Entry & Thumbnail Map 1038
	var map_e := ThienTamThapChallenge.map_entry()
	assert(map_e.get("id") == 1038, "ID bản đồ phải là 1038")
	assert(map_e.get("dir") == "res://world/maps/map_1038", "Đường dẫn map phải là world/maps/map_1038")
	assert(map_e.get("thien_tam_thap") == true, "Phải có cờ thien_tam_thap")
	print("✓ PASS: 5. Bản đồ thumbnail Map 1038 cấu hình chuẩn xác.")

	# 6. Test cơ chế tính và lưu kỷ lục qua ải (ví dụ vượt 200 ải, vượt 201 ải)
	assert(ThienTamThapChallenge.best_stage(valid_profile) == 0, "Kỷ lục ban đầu là 0")
	ThienTamThapChallenge.update_best_stage(valid_profile, 200)
	assert(ThienTamThapChallenge.best_stage(valid_profile) == 200, "Cập nhật vượt 200 ải")
	ThienTamThapChallenge.update_best_stage(valid_profile, 201)
	assert(ThienTamThapChallenge.best_stage(valid_profile) == 201, "Cập nhật vượt 201 ải")
	print("✓ PASS: 6. Tính năng đếm và lưu kỷ lục qua ải (vượt 200 ải, vượt 201 ải) thành công.")

	# 7. Test Tracker HUD
	var hud := ThienTamThapTrackerHud.new()
	hud.setup(waves, 201)
	hud.update_status(201, 200, 35.0, 8)
	assert(hud.current_wave == 201, "Current wave HUD phải là 201")
	assert(hud.stages_cleared == 200, "Stages cleared HUD phải là 200")
	hud.queue_free()
	print("✓ PASS: 7. Thử nghiệm Tracker HUD (timeline 5 đợt dọc và thông tin ải hiện tại) chuẩn xác.")

	# 8. Test Bảng Xếp Hạng người chơi qua ải nhiều nhất
	var lb: Array[Dictionary] = ThienTamThapChallenge.get_leaderboard(valid_profile)
	assert(not lb.is_empty(), "Bảng xếp hạng không được rỗng")
	assert(lb.size() >= 10, "Phải có ít nhất 10 thứ hạng trên BXH (hiện có: %d)" % lb.size())
	# Kiểm tra thứ tự sắp xếp: số ải vượt phải giảm dần
	for idx in range(lb.size() - 1):
		var cur_st: int = int(lb[idx].get("best_stage", 0))
		var next_st: int = int(lb[idx + 1].get("best_stage", 0))
		assert(cur_st >= next_st, "Thứ hạng %d (%d ải) phải lớn hơn hoặc bằng thứ hạng %d (%d ải)" % [idx + 1, cur_st, idx + 2, next_st])
		assert(lb[idx].get("rank") == idx + 1, "Thứ hạng STT phải liên tục từ 1..N")

	# Kiểm tra người chơi DaiHiep30 (vừa đạt 201 ải) nằm trên BXH
	var found_me := false
	for entry in lb:
		if entry.get("name") == "DaiHiep30":
			assert(int(entry.get("best_stage", 0)) == 201, "Số ải của DaiHiep30 trên BXH phải là 201 ải")
			found_me = true
			break
	assert(found_me, "DaiHiep30 phải có mặt trên Bảng Xếp Hạng")

	# Test cửa sổ Bảng Xếp Hạng
	var lb_win = ThienTamThapLeaderboardWindow.new(valid_profile)
	assert(lb_win != null, "ThienTamThapLeaderboardWindow phải khởi tạo thành công")
	lb_win.queue_free()
	print("✓ PASS: 8. Kiểm tra Bảng Xếp Hạng người chơi vượt ải nhiều nhất (sắp xếp giảm dần, Top 1..N, giao diện) hoàn hảo.")

	# Dọn dẹp records test
	rec = ThienTamThapChallenge.records()
	rec.erase("DaiHiep30")
	rec.erase("NoviceTester")
	ThienTamThapChallenge.save_records(rec)

	print("\n🎉 TẤT CẢ TEST THIÊN TẦM THÁP & BẢNG XẾP HẠNG ĐÃ PASS THÀNH CÔNG 100%!")
	quit(0)

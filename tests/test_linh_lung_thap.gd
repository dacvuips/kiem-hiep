extends SceneTree

const LinhLungThapChallenge = preload("res://systems/challenge/linh_lung_thap_challenge.gd")

func _init() -> void:
	print("--- BẮT ĐẦU TEST LINH LUNG THÁP ---")

	# 1. Test cấu hình JSON và dữ liệu
	var d := LinhLungThapChallenge.data()
	assert(not d.is_empty(), "Data LinhLungThap không được rỗng")
	assert(LinhLungThapChallenge.floors().size() == 7, "Phải có đúng 7 tầng tháp")
	print("✓ PASS: 1. Đọc dữ liệu 7 tầng Linh Lung Tháp thành công.")

	# 2. Test thông tin từng tầng
	for i in range(1, 8):
		var fd := LinhLungThapChallenge.floor_data(i)
		assert(fd.has("name"), "Tầng %d phải có tên" % i)
		assert(fd.has("pillar_pts"), "Tầng %d phải có điểm Cầm Long Trụ" % i)
	print("✓ PASS: 2. Cấu hình chi tiết 7 tầng tháp hoàn chỉnh.")

	# 3. Test Item Lệnh bài & Rương
	var misc_token := ItemDatabase.get_misc(LinhLungThapChallenge.ENTRY_ITEM_ID)
	assert(not misc_token.is_empty(), "Item Lệnh Bài Linh Lung Tháp (4_999_0) phải tồn tại trong ItemDatabase")
	assert(misc_token.get("name") == "Lệnh Bài Linh Lung Tháp", "Tên item lệnh bài phải chính xác")
	print("✓ PASS: 3. Item Lệnh Bài Linh Lung Tháp đăng ký chuẩn xác.")

	var misc_chest := ItemDatabase.get_misc(LinhLungThapChallenge.CHEST_ITEM_ID)
	assert(not misc_chest.is_empty(), "Item Rương Đoạt Khôi (4_999_1) phải tồn tại trong ItemDatabase")
	print("✓ PASS: 4. Item Rương Linh Lung Tháp Đoạt Khôi đăng ký chuẩn xác.")

	# 4. Test PlayerProfile & Lệnh bài
	var profile := PlayerProfile.new()
	profile.display_name = "DaiHiepTest"
	profile.level = 85
	profile.gold = 100000

	# Reset record của DaiHiepTest trước khi test
	var rec := LinhLungThapChallenge._records()
	rec.erase("DaiHiepTest")
	LinhLungThapChallenge._save_records(rec)

	# Kiểm tra điều kiện level 8x (>= 80)
	assert(LinhLungThapChallenge.MIN_LEVEL == 80, "Cấp tối thiểu tham gia phải là 80 (8x)")
	assert(LinhLungThapChallenge.MIN_PLAYERS == 5, "Số người tối thiểu phải là 5")

	var low_profile := PlayerProfile.new()
	low_profile.level = 79
	assert(LinhLungThapChallenge.check_entry(low_profile) != "", "Level < 80 không được phép tham gia")

	# Ban đầu chưa có lệnh bài
	assert(LinhLungThapChallenge.entry_item_count(profile) == 0, "Chưa có lệnh bài")

	# Nhận thử nghiệm lệnh bài
	LinhLungThapChallenge.claim_test_item(profile)
	assert(LinhLungThapChallenge.entry_item_count(profile) == 1, "Sau khi nhận phải có 1 lệnh bài")
	print("✓ PASS: 5. Nhận và kiểm tra số lượng Lệnh Bài trong túi đồ thành công.")

	# 5. Test Điều kiện & Trừ phí báo danh
	var reason := LinhLungThapChallenge.check_entry(profile)
	assert(reason == "", "Đủ điều kiện tham gia (reason phải rỗng): " + reason)

	var pay_ok := LinhLungThapChallenge.pay_entry(profile)
	assert(pay_ok == true, "Báo danh thành công")
	assert(LinhLungThapChallenge.entry_item_count(profile) == 0, "Sau khi báo danh phải trừ 1 lệnh bài")
	assert(LinhLungThapChallenge.runs_today(profile) >= 1, "Đã ghi nhận lượt tham gia hôm nay")
	print("✓ PASS: 6. Quy trình báo danh và trừ phí/lệnh bài chính xác 100%.")

	# 6. Test map entry
	var prep_e := LinhLungThapChallenge.prep_map_entry()
	assert(prep_e.get("linh_lung_prep") == true, "Prep map entry phải có cờ linh_lung_prep")
	assert(prep_e.get("id") == 1037, "Prep map entry phải là Map 1037 Khu Chuẩn Bị Linh Lung Tháp")
	print("✓ PASS: 7. Cấu hình prep_map_entry chuẩn xác vào Map #1037 Khu Chuẩn Bị Linh Lung Tháp.")

	var map_e := LinhLungThapChallenge.map_entry()
	assert(map_e.get("linh_lung_thap") == true, "Map entry phải có cờ linh_lung_thap")
	assert(map_e.get("id") == 1038, "Map entry phải là Map 1038 Linh Lung Tháp gốc")
	print("✓ PASS: 8. Cấu hình map_entry chuyển cảnh chuẩn xác vào Map #1038 Linh Lung Tháp.")

	# 7. Test Khu chuẩn bị (Phòng chờ 5 phút = 300 giây và Tọa độ 200/199)
	var prep = LinhLungPrepArea.new()
	assert(prep.PREP_DURATION_SEC == 300.0, "Thời gian phòng chờ phải đúng 5 phút (300 giây)")
	assert(prep.SPAWN_POS == Vector2(51200, 50944), "Vị trí trả/spawn player phải là tọa độ 200/199 (Vector2(51200, 50944))")
	prep.queue_free()
	print("✓ PASS: 9. Kiểm tra Phòng chờ 5 phút (300 giây) và Tọa độ trả về 200/199 đạt chuẩn.")

	# 8. Test cơ chế Tháp, Tích lũy Điểm Tầng & Giáng tầng
	var chal := LinhLungThapChallenge.new()
	assert(chal.TOTAL_FLOORS == 7, "Tổng số tầng tháp là 7")
	assert(chal.current_floor == 1, "Bắt đầu tại tầng 1")
	assert(LinhLungThapChallenge.target_floor_score(1) == 150, "Tầng 1 yêu cầu 150 điểm để thăng tầng")

	# Test tích điểm thăng tầng
	chal._add_score(100)
	assert(chal.floor_score == 100 and chal.current_floor == 1, "Chưa đủ 150 điểm thì chưa lên tầng")
	chal._add_score(60) # 100 + 60 = 160 >= 150 -> thăng tầng 2!
	assert(chal.current_floor == 2, "Đạt đủ 160/150 điểm phải thăng lên Tầng 2")
	assert(chal.floor_score == 0, "Lên tầng mới thì điểm tầng reset về 0")

	# Giả lập khi bị hạ gục tại tầng 2 -> rơi tụt xuống tầng 1
	chal._on_player_died()
	assert(chal.current_floor == 1, "Bị hạ gục tại tầng 2 phải giáng tầng rơi xuống tầng 1")
	chal.queue_free()
	print("✓ PASS: 10. Kiểm tra Cơ chế Tính Điểm Thăng Tầng và Giáng tầng hoạt động chuẩn xác 100%.")

	print("\n🎉 TẤT CẢ TEST LINH LUNG THÁP ĐÃ PASS THÀNH CÔNG 100%!")
	quit(0)

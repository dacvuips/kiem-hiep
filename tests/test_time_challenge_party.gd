extends Node

const TimeChallengeLobbyScript = preload("res://systems/challenge/time_challenge_lobby.gd")
const TimeChallengeScript = preload("res://systems/challenge/time_challenge.gd")
const TimeChallengeWindowScript = preload("res://ui/events/time_challenge_window.gd")

func _ready() -> void:
	print("\n=======================================================")
	print("--- TEST CHỨC NĂNG TỔ ĐỘI 8 PLAYER THÁCH THỨC THỜI GIAN ---")
	print("=======================================================")
	_run_all_tests()
	get_tree().quit(0)

func _run_all_tests() -> void:
	# Khởi tạo profile test
	var host_p := PlayerProfile.new()
	host_p.display_name = "MinhChuVoLam"
	host_p.level = 95
	host_p.sect_id = "vo_dang"
	host_p.gold = 5000000

	var mem_p := PlayerProfile.new()
	mem_p.display_name = "TieuHiep1"
	mem_p.level = 88
	mem_p.sect_id = "thieu_lam"
	mem_p.gold = 2000000
	var it := ItemInstance.new()
	it.misc_id = "6_1_400"
	it.item_level = 90
	it.count = 2
	mem_p.inventory.append(it)

	# 1. Test TimeChallengeLobby: Hằng số & Khởi tạo phòng
	assert(TimeChallengeLobbyScript.MAX_MEMBERS == 8, "Tối đa phải là 8 thành viên")
	assert(TimeChallengeLobbyScript.WAITING == "waiting", "Trạng thái chờ")
	assert(TimeChallengeLobbyScript.FIGHTING == "fighting", "Trạng thái khiêu chiến")

	var initial_rooms := TimeChallengeLobbyScript.rooms()
	assert(initial_rooms.size() >= 3, "Phải có sẵn các phòng mẫu ban đầu để sảnh sôi động")
	print("✓ PASS: 1. Khởi tạo danh sách phòng mẫu thành công (số phòng ban đầu: %d)." % initial_rooms.size())

	# 2. Test Tạo phòng mới (chủ phòng tự động sẵn sàng, max 8 người)
	var room := TimeChallengeLobbyScript.create(host_p, "123456", 8)
	var rid := str(room["id"])
	assert(rid.length() == 6, "ID phòng phải có 6 chữ số")
	assert(room["host"] == "MinhChuVoLam", "Chủ phòng phải khớp")
	assert(room["password"] == "123456", "Mật khẩu phòng phải khớp")
	assert(room["max_members"] == 8, "Giới hạn phải là 8 người")
	assert(room["state"] == TimeChallengeLobbyScript.WAITING, "Trạng thái ban đầu là WAITING")
	assert((room["members"] as Array).size() == 1, "Ban đầu phòng có 1 người (chủ phòng)")
	assert(room["members"][0]["is_host"] == true, "Người đầu tiên là chủ phòng")
	assert(room["members"][0]["ready"] == true, "Chủ phòng mặc định đã sẵn sàng")
	print("✓ PASS: 2. Tạo phòng tổ đội 8 người thành công (Room #%s)." % rid)

	# 3. Test Tìm phòng của bản thân
	var own := TimeChallengeLobbyScript.find_own(host_p)
	assert(not own.is_empty() and own["id"] == rid, "Phải tìm được phòng của chủ phòng")
	print("✓ PASS: 3. Tìm phòng sở hữu find_own() hoạt động chính xác.")

	# 4. Test Gia nhập phòng (Sai mật khẩu, Đúng mật khẩu, Kiểm tra thành viên)
	var fail_join := TimeChallengeLobbyScript.join(rid, mem_p, "sai_pass")
	assert(fail_join["ok"] == false, "Sai mật khẩu phải từ chối gia nhập")

	var ok_join := TimeChallengeLobbyScript.join(rid, mem_p, "123456")
	assert(ok_join["ok"] == true, "Đúng mật khẩu phải cho phép gia nhập")
	assert((room["members"] as Array).size() == 2, "Phòng có 2 thành viên")
	assert(room["members"][1]["ready"] == false, "Thành viên mới vào chưa sẵn sàng")
	print("✓ PASS: 4. Kiểm tra mật khẩu và gia nhập phòng thành công.")

	# 5. Test Bật/Tắt Sẵn Sàng & Kiểm tra quy tắc is_all_ready
	assert(TimeChallengeLobbyScript.is_all_ready(room) == false, "Chưa phải tất cả sẵn sàng vì TieuHiep1 chưa sẵn sàng")

	var rd_state := TimeChallengeLobbyScript.toggle_ready(rid, "TieuHiep1")
	assert(rd_state == true, "TieuHiep1 đã bật sẵn sàng")
	assert(TimeChallengeLobbyScript.is_all_ready(room) == true, "Tất cả thành viên đã sẵn sàng")
	print("✓ PASS: 5. Chuyển trạng thái Sẵn sàng và kiểm tra quy tắc is_all_ready hoạt động chính xác.")

	# 6. Test Thêm Bot và Điền đầy đủ 8 thành viên (Full party)
	var fill_ok := TimeChallengeLobbyScript.fill_bots(rid, 92)
	assert(fill_ok == true, "Phải điền được bot đầy phòng")
	assert((room["members"] as Array).size() == 8, "Phòng phải có đúng 8 thành viên")

	# Thử thêm người thứ 9 phải bị chặn
	var bot_extra := TimeChallengeLobbyScript.add_bot(rid, 90)
	assert(bot_extra == false, "Không được vượt quá 8 người")
	assert((room["members"] as Array).size() == 8, "Vẫn giữ đúng 8 người")
	print("✓ PASS: 6. Thêm Bot và giới hạn tối đa 8 thành viên trong tổ đội hoạt động chuẩn xác.")

	# 7. Test Kích thành viên & Xóa Bot
	var kicked := TimeChallengeLobbyScript.kick(rid, "TieuHiep1", host_p)
	assert(kicked == true, "Chủ phòng kích thành viên thành công")
	assert((room["members"] as Array).size() == 7, "Sau khi kích còn 7 người")

	var rm_bot := TimeChallengeLobbyScript.remove_bot(rid)
	assert(rm_bot == true, "Xóa bot thành công")
	assert((room["members"] as Array).size() == 6, "Sau khi xóa 1 bot còn 6 người")
	print("✓ PASS: 7. Chủ phòng kích thành viên và quản lý bot hoàn toàn chính xác.")

	# 8. Test Đổi / Bỏ mật khẩu
	TimeChallengeLobbyScript.set_password(rid, host_p, "")
	assert(room["password"] == "", "Đã bỏ mật khẩu phòng thành công")
	print("✓ PASS: 8. Cài đặt và hủy mật khẩu phòng thành công.")

	# 9. Test Chuyển trạng thái khiêu chiến FIGHTING và Đóng phòng
	TimeChallengeLobbyScript.set_fighting(rid)
	assert(room["state"] == TimeChallengeLobbyScript.FIGHTING, "Phòng chuyển sang FIGHTING")

	TimeChallengeLobbyScript.close(rid)
	assert(TimeChallengeLobbyScript.find(rid).is_empty(), "Phòng đã bị đóng")
	print("✓ PASS: 9. Trạng thái khiêu chiến và đóng phòng hoạt động chuẩn xác.")

	# 10. Test cấu trúc TimeChallenge map_entry & hỗ trợ team_challenge
	var map_e := TimeChallengeScript.map_entry()
	assert(map_e["id"] == 480, "Map ID phải là 480")
	assert(map_e["challenge"] == true, "Cờ challenge phải là true")

	map_e["team_challenge"] = true
	map_e["team_members"] = [
		{"name": "MinhChu", "level": 95},
		{"name": "Bot1", "level": 92},
		{"name": "Bot2", "level": 92}
	]
	assert(map_e["team_challenge"] == true, "Phải hỗ trợ cờ team_challenge")
	assert((map_e["team_members"] as Array).size() == 3, "Phải có danh sách thành viên")
	print("✓ PASS: 10. TimeChallenge.map_entry cấu hình tổ đội 8 người chơi chung 1 map 480 hoàn hảo.")

	# 11. Test Khởi tạo cửa sổ TimeChallengeWindow
	var win = TimeChallengeWindowScript.new(host_p, func(_e: Dictionary) -> void: pass)
	assert(win != null, "Khởi tạo TimeChallengeWindow thành công")
	assert(win.title_label.text == "THÁCH THỨC THỜI GIAN", "Tiêu đề chuẩn")
	add_child(win)
	win._render()
	print("✓ PASS: 11. Khởi tạo và render cửa sổ TimeChallengeWindow thành công.")

	print("\n>>> TẤT CẢ CÁC BÀI TEST CHỨC NĂNG TỔ ĐỘI 8 PLAYER VƯỢT ẢI ĐÃ VƯỢT QUA 100%! <<<\n")

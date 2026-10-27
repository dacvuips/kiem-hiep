extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU TEST PK VẬN TIÊU TRONG PK_WINDOW ---")
	_run_tests()

func _run_tests() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "DaiHiepTieuCuc"
	profile.level = 88
	profile.gold = 5000000
	profile.sect_id = "vo_dang"

	# 1. Kiểm tra PkRules.Mode.VAN_TIEU & Quy định ngày T7/CN
	assert(PkRules.Mode.has("VAN_TIEU"), "PkRules phải có Mode.VAN_TIEU")
	assert(PkRules.MODE_NAMES[PkRules.Mode.VAN_TIEU] == "Vận Tiêu (Long Môn Tiêu Cục)", "Tên chế độ phải chuẩn")
	assert(PkRules.MIN_LEVEL[PkRules.Mode.VAN_TIEU] == 30, "Cấp tối thiểu phải là 30")
	EscortWindow.test_bypass_day = true
	assert(EscortWindow.is_escort_day() == true, "Khi bypass test phải là true")
	print("PASS: 1. PkRules.Mode.VAN_TIEU định nghĩa chính xác & Tuân thủ ngày T7/CN.")

	# 2. Kiểm tra tạo phòng Vận Tiêu trong PkLobby (Mặc định 5vs5 cố định)
	var r := PkLobby.create(profile, PkRules.Mode.VAN_TIEU, "", 1, {
		"cart_tier_id": "bronze",
		"cart_name": "🛡️ Tiêu Xa Đồng (Trung Cấp)",
		"role": "defender"
	})
	assert(not r.is_empty(), "Phải tạo được phòng Vận Tiêu")
	assert(int(r.get("mode", -1)) == PkRules.Mode.VAN_TIEU, "Mode phòng phải là VAN_TIEU")
	assert(int(r.get("team_size", 0)) == 5, "Team size phải cố định là 5 dù truyền vào 1")
	assert((r.get("team_a", []) as Array).size() == 1, "Phe Hộ Tiêu (Xanh) phải có chủ phòng")
	print("PASS: 2. PkLobby tạo phòng Vận Tiêu mặc định 5v5 thành công.")

	# 3. Kiểm tra gia nhập xen kẽ và đổi phe (Đỏ vs Xanh)
	var guest := PlayerProfile.new()
	guest.display_name = "CuopTieuLaoTo"
	guest.level = 85
	guest.sect_id = "ngu_doc"
	var joined := PkLobby.join_team(str(r["id"]), guest, "b")
	assert(joined, "Khách phải vào được Phe Đỏ (Cướp Tiêu - team b)")
	var r_updated := PkLobby.find(str(r["id"]))
	assert((r_updated.get("team_b", []) as Array).size() == 1, "Phe Đỏ phải có 1 thành viên")
	print("PASS: 3. Khách tham gia Phe Đỏ (Cướp Tiêu) xen kẽ thành công.")

	# 4. Kiểm tra PkWindow khởi tạo và chọn chế độ VAN_TIEU
	var entered_box := [{}]
	var on_play_cb := func(entry: Dictionary) -> void:
		entered_box[0] = entry

	var win := PkWindow.new(profile, on_play_cb)
	add_child(win)
	win._select_mode(PkRules.Mode.VAN_TIEU)
	assert(win._mode == PkRules.Mode.VAN_TIEU, "PkWindow phải chuyển sang Mode.VAN_TIEU")
	print("PASS: 4. PkWindow render danh sách phòng Vận Tiêu thành công.")

	# 5. Kiểm tra hiển thị phòng và bắt đầu trận đấu
	win._show_room(r_updated)
	win._start_room_match()
	var entered_entry: Dictionary = entered_box[0]
	assert(not entered_entry.is_empty(), "Phải tạo được entry khi bấm Bắt đầu trận")
	assert(entered_entry.has("cart_data") or entered_entry.has("pk"), "Entry phải có dữ liệu xe tiêu (cart_data)")
	assert(entered_entry.has("pk"), "Entry phải có dữ liệu pk")
	assert(entered_entry.get("id", 0) == 37, "Bản đồ vận tiêu phải là Map 37 Biện Kinh")
	print("PASS: 5. Khởi hành trận Vận Tiêu 5v5 với đầy đủ xe tiêu và 2 phe vào Map 37 Biện Kinh thành công.")

	# 6. Kiểm tra Tự tìm đối thủ / Ghép bot timeout
	win._mode = PkRules.Mode.VAN_TIEU
	win._match_bot()
	assert(not win._found_entry.is_empty(), "Phải ghép được bot cho chuyến tiêu")
	assert(win._found_entry.get("id", 0) == 37, "Bot match phải vào Map 37 Biện Kinh")
	print("PASS: 6. Tính năng Tự tìm đối thủ & Điền bot cho Vận Tiêu thành công.")

	print("\n--- TOÀN BỘ 6 MỤC KIỂM THỬ PK VẬN TIÊU ĐỀU ĐẠT 100% (PASS)! ---")
	get_tree().quit(0)

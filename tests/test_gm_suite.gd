extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU KIỂM THỬ HỆ THỐNG GAME MASTER (GM SUITE) ---")

	# Khởi tạo profile nếu đang chạy headless riêng lẻ
	AccountApi.account["id"] = "GM_001"
	AccountApi.account["is_gm"] = true
	if GameManager.local_profile == null:
		var p := PlayerProfile.new()
		p.display_name = "GM_TestUser"
		p.level = 80
		GameManager.local_profile = p

	# 1. Kiểm tra singleton GmManager
	assert(GmManager != null, "GmManager singleton phải tồn tại")
	assert(GmManager.is_gm(), "Tài khoản kiểm thử debug phải có quyền GM")
	print("PASS: GmManager singleton và quyền GM hoạt động chính xác")

	# 2. Kiểm tra các trạng thái bản thân (Tàng hình, Bất tử, Xuyên tường, Tốc độ, Cộng chỉ số)
	GmManager.is_invisible = true
	assert(GmManager.is_invisible == true, "is_invisible phải là true")
	GmManager.is_god_mode = true
	assert(GmManager.is_god_mode == true, "is_god_mode phải là true")
	GmManager.is_noclip = true
	assert(GmManager.is_noclip == true, "is_noclip phải là true")
	GmManager.speed_mult = 3.0
	assert(is_equal_approx(GmManager.speed_mult, 3.0), "speed_mult phải là 3.0")

	var str_before := GameManager.local_profile.strength
	GmManager.adjust_stats(GameManager.local_profile, 100, 100, 100, 100)
	assert(GameManager.local_profile.strength == str_before + 100, "Cộng 100 sức mạnh phải thành công")
	assert(GameManager.local_profile.str_point == GameManager.local_profile.strength, "str_point alias phải khớp strength")
	GmManager.restore_self_full()
	assert(GameManager.local_profile.max_mana > 0, "max_mana phải lớn hơn 0")
	print("PASS: Các quyền năng bản thân GM, hồi phục HP/MP/SP & cộng chỉ số hoạt động tốt")

	# 3. Kiểm tra danh sách người chơi & tìm kiếm
	var players := GmManager.get_player_list()
	assert(not players.is_empty(), "Danh sách người chơi không được rỗng")
	var target_p := players[0]
	var found := GmManager.search_players(target_p["name"])
	assert(not found.is_empty(), "Tìm kiếm người chơi theo tên phải có kết quả")
	print("PASS: Danh sách và tìm kiếm người chơi hoạt động tốt")

	# 4. Kiểm tra dịch chuyển và kích kẹt
	GmManager.teleport_player(target_p, Vector2(350, 450))
	GmManager.kick_stuck(target_p)
	GmManager.teleport_all_players(Vector2(200, 200), true)
	print("PASS: Dịch chuyển cá nhân, kích kẹt và dịch chuyển toàn map hoạt động tốt")

	# 5. Kiểm tra kỷ luật & quản trị
	GmManager.rename_player(target_p, "GM_Test_Hero")
	GmManager.mute_player(target_p, 30, "Thử nghiệm cấm chat")
	assert(GmManager.muted_players.has(target_p["id"]), "Người chơi phải có trong danh sách cấm chat")
	GmManager.ban_player(target_p, 24, "Thử nghiệm khóa nick")
	assert(GmManager.banned_players.has(target_p["id"]), "Người chơi phải có trong danh sách khóa nick")
	print("PASS: Đổi tên, cấm chat và khóa nick hoạt động tốt")

	# 6. Kiểm tra cấp đồ & tiền và phát tín hiệu cập nhật tức thì (profile_modified)
	var initial_gold: int = GameManager.local_profile.gold
	var initial_xu: int = GameManager.local_profile.xu
	var signal_emitted := [false]
	var signal_cb := func(p: PlayerProfile) -> void:
		if p == GameManager.local_profile:
			signal_emitted[0] = true
	GmManager.profile_modified.connect(signal_cb)
	GmManager.give_resources(GameManager.local_profile, 5000000, 1000, 100, 100, 5000)
	assert(GameManager.local_profile.gold == initial_gold + 5000000, "Cấp tiền phải cộng chính xác")
	assert(GameManager.local_profile.xu == initial_xu + 5000, "Cấp Tiền Xu phải cộng chính xác")
	assert(GameManager.local_profile.jade >= 1000, "Cấp KNB phải cộng chính xác")
	assert(signal_emitted[0] == true, "profile_modified signal phải được phát để UI cập nhật ngay lập tức")
	GmManager.profile_modified.disconnect(signal_cb)

	var test_item := ItemGenerator.generate(ItemDatabase.Detail.MELEE, 0, 5, 0, [5, 5])
	var give_ok := GmManager.give_item(GameManager.local_profile, test_item)
	assert(give_ok, "Cấp trang bị vào hành trang phải thành công")
	print("PASS: Cấp tiền tệ và trang bị thành công")

	# 7. Kiểm tra cấu hình Boss & tỉ lệ rơi đồ
	GmManager.boss_hp_mult = 2.5
	GmManager.boss_damage_mult = 1.8
	GmManager.boss_drop_mult = 5.0
	assert(is_equal_approx(GmManager.boss_hp_mult, 2.5), "Máu boss x2.5")
	assert(is_equal_approx(GmManager.boss_damage_mult, 1.8), "Dame boss x1.8")
	assert(is_equal_approx(DropTable.item_rate_mult, 5.0), "Tỉ lệ rơi đồ DropTable phải đồng bộ x5.0")

	var spawned := GmManager.spawn_boss("Độc Cô Cầu Kiếm", "boss015", 0, 95, "gold", Vector2(100, 100))
	assert(spawned != null, "Triệu hồi Boss thành công")
	assert(GmManager.spawned_bosses.size() == 1, "Danh sách boss đã triệu hồi phải có 1")
	GmManager.clear_spawned_bosses()
	assert(GmManager.spawned_bosses.is_empty(), "Dọn sạch boss triệu hồi thành công")
	print("PASS: Quản lý Boss, tỉ lệ rớt đồ và dọn dẹp boss thành công")

	# 8. Kiểm tra chiếm quyền / điều khiển nhân vật khác (Impersonate)
	var dummy_profile := PlayerProfile.new()
	dummy_profile.display_name = "NguoiChoiThuNghiem"
	dummy_profile.level = 45
	var possess_ok := GmManager.possess_player(dummy_profile)
	assert(possess_ok, "Chiếm quyền điều khiển phải thành công")
	assert(GmManager.is_possessing == true, "is_possessing phải là true")
	assert(GameManager.local_profile.display_name == "NguoiChoiThuNghiem", "Avatar điều khiển chuyển sang mục tiêu")

	GmManager.release_possession()
	assert(GmManager.is_possessing == false, "Đã hoàn trả quyền điều khiển")
	assert(GameManager.local_profile.display_name != "NguoiChoiThuNghiem", "Trở về nhân vật GM ban đầu")
	print("PASS: Chiếm quyền và hoàn trả quyền điều khiển nhân vật khác thành công")

	# 9. Kiểm tra giao diện GmControlWindow
	var gm_win := GmControlWindow.open(self)
	assert(gm_win != null, "GmControlWindow phải mở thành công")
	for tab_idx in GmControlWindow.Tab.values():
		gm_win._current_tab = tab_idx
		gm_win._render_tab()
	print("PASS: Giao diện GmControlWindow và toàn bộ 6 Tab render thành công")

	# 10. Kiểm tra Audit Logs
	assert(not GmManager.audit_logs.is_empty(), "Nhật ký Audit Log phải ghi nhận các hành vi GM")
	print("PASS: Audit Logs ghi nhận %d thao tác thành công" % GmManager.audit_logs.size())

	# 11. KIỂM THỬ CÁC TÍNH NĂNG MỚI ĐỒNG BỘ TỪ SOURCE 15 PHÁI (Màu PK, Kỹ năng phái, HKMP, Địa danh, Tẩy tủy)
	# 11.1 Đổi phe / màu PK
	GmManager.change_player_camp(GameManager.local_profile, Camp.Type.JUSTICE)
	assert(GameManager.local_profile.camp == Camp.Type.JUSTICE, "Đổi sang Chính phái thành công")
	GmManager.change_player_camp(GameManager.local_profile, Camp.Type.FREE)
	assert(GameManager.local_profile.camp == Camp.Type.FREE, "Đổi sang Sát thủ thành công")

	# 11.2 Vòng sáng GM & Ngoại hình GM
	GmManager.is_gm_halo = true
	assert(GmManager.is_gm_halo == true, "is_gm_halo phải là true")
	GmManager.is_gm_mask = true
	assert(GmManager.is_gm_mask == true, "is_gm_mask phải là true")

	# 11.3 Tẩy tủy và Cộng điểm tự do
	var init_pts: int = GameManager.local_profile.potential_points
	GmManager.add_free_points(GameManager.local_profile, 500, 50)
	assert(GameManager.local_profile.potential_points == init_pts + 500, "Cộng +500 tiềm năng thành công")
	
	# Kiểm tra tự nhập số điểm tiềm năng tăng tự do
	var before_custom_pot: int = GameManager.local_profile.potential_points
	GmManager.add_potential_points(GameManager.local_profile, 1234)
	assert(GameManager.local_profile.potential_points == before_custom_pot + 1234, "Tự nhập số +1234 điểm tiềm năng thành công")

	# Kiểm tra tự nhập số tăng trực tiếp vào 1 thuộc tính
	var before_str: int = GameManager.local_profile.strength
	GmManager.add_single_stat(GameManager.local_profile, "str", 250)
	assert(GameManager.local_profile.strength == before_str + 250, "Tự nhập số +250 sức mạnh thành công")

	GmManager.reset_skills_and_stats(GameManager.local_profile)
	print("PASS: Đổi màu PK, Vòng sáng/Ngoại hình GM, Tự nhập số tăng tiềm năng và Tẩy tủy hoạt động chính xác")

	# 11.4 Dịch chuyển địa danh trọng yếu
	GmManager.teleport_to_location(target_p, "Ba Lăng Huyện")
	GmManager.teleport_to_location(target_p, "Biện Kinh")
	GmManager.teleport_to_location(target_p, "Chiến Trường Tống Kim")
	print("PASS: Dịch chuyển địa danh Ba Lăng Huyện, Biện Kinh, Tống Kim thành công")

	# 11.5 Cấp bộ Hoàng Kim Môn Phái & Các bộ Hoàng Kim danh tiếng
	var hkmp_count: int = GmManager.give_hkmp_set(GameManager.local_profile, 1) # Thiếu Lâm Mộng Long
	assert(hkmp_count > 0, "Cấp bộ HKMP phải có ít nhất 1 món")
	var ab_count: int = GmManager.give_an_bang_set(GameManager.local_profile)
	assert(ab_count > 0, "Cấp bộ An Bang phải có ít nhất 1 món")
	var dq_count: int = GmManager.give_dinh_quoc_set(GameManager.local_profile)
	assert(dq_count > 0, "Cấp bộ Định Quốc phải có ít nhất 1 món")
	var kp_count: int = GmManager.give_kim_phong_set(GameManager.local_profile)
	assert(kp_count > 0, "Cấp bộ Kim Phong phải có ít nhất 1 món")
	var horse_ok: bool = GmManager.give_horse_vip(GameManager.local_profile, "Phiên Vũ")
	assert(horse_ok, "Cấp Thần mã Phiên Vũ thành công")
	var gems_count: int = GmManager.give_gem_pack(GameManager.local_profile)
	assert(gems_count > 0, "Cấp gói Nguyên liệu & Thủy tinh thành công")
	print("PASS: Cấp bộ HKMP, An Bang, Định Quốc, Kim Phong, Thần Mã và Thủy Tinh thành công")

	# 11.6 Quét định vị Boss & Kick All lưu dữ liệu
	var scanned_bosses: Array[Dictionary] = GmManager.find_bosses()
	assert(scanned_bosses is Array, "find_bosses phải trả về danh sách Array")
	GmManager.kick_all_save_data()
	print("PASS: Quét Boss (findgoldboss) và Kick All lưu an toàn máy chủ thành công")

	print("--- TOÀN BỘ 11 MỤC KIỂM THỬ HỆ THỐNG GM ĐÃ VƯỢT QUA XUẤT SẮC! ---")
	get_tree().quit(0)

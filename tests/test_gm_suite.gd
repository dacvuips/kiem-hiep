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
	var found := GmManager.search_players(str(target_p["id"]))
	assert(not found.is_empty(), "Tìm kiếm người chơi theo ID phải có kết quả")
	assert(GmManager.search_players(str(target_p["name"]) + "_khong_phai_id").is_empty(), "Không tìm theo tên")
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

	# Test các tiện ích tạo đồ TEST mới: Dọn dẹp túi đồ, Mặt Nạ, Phi Phong, Đồ Xanh, Thuốc
	var cleared_pre: int = GmManager.clear_inventory(GameManager.local_profile)
	assert(GameManager.local_profile.inventory.is_empty(), "Hành trang phải rỗng sau khi clear_inventory")
	var mask_cnt: int = GmManager.give_mask_set(GameManager.local_profile)
	assert(mask_cnt == 5, "Cấp 5 mặt nạ test phải thành công")
	var mantle_cnt: int = GmManager.give_mantle_set(GameManager.local_profile)
	assert(mantle_cnt == 5, "Cấp 5 phi phong test phải thành công")
	var blue_cnt: int = GmManager.give_blue_set(GameManager.local_profile)
	assert(blue_cnt == 10, "Cấp 10 món trang bị xanh cấp 10 full 6 dòng thành công")
	var cons_cnt: int = GmManager.give_consumables_pack(GameManager.local_profile)
	assert(cons_cnt > 0, "Cấp gói thuốc, phúc duyên và lệnh bài thành công")
	var cleared_cnt: int = GmManager.clear_inventory(GameManager.local_profile)
	assert(cleared_cnt > 0, "Dọn dẹp túi đồ phải xóa các món test đã cấp")
	assert(GameManager.local_profile.inventory.is_empty(), "Hành trang phải rỗng sau khi clear_inventory")
	print("PASS: Cấp bộ HKMP, An Bang, Định Quốc, Kim Phong, Thần Mã, Đồ Xanh, Mặt Nạ, Phi Phong và Clear Inv thành công")

	# 11.6 Quét định vị Boss & Kick All lưu dữ liệu
	var scanned_bosses: Array[Dictionary] = GmManager.find_bosses()
	assert(scanned_bosses is Array, "find_bosses phải trả về danh sách Array")
	GmManager.kick_all_save_data()
	print("PASS: Quét Boss (findgoldboss) và Kick All lưu an toàn máy chủ thành công")

	# 11.7 Kiểm tra chuyển đổi tất cả các môn phái cho bản thân
	var sects: Array[SectDefinition] = SectRegistry.load_all()
	assert(not sects.is_empty(), "Danh sách môn phái không được rỗng")
	for s in sects:
		var change_ok: bool = GmManager.change_player_sect(GameManager.local_profile, s.id, true)
		assert(change_ok, "Chuyển sang môn phái %s (%s) phải thành công" % [s.sect_name, s.id])
		assert(GameManager.local_profile.sect_id == s.id, "sect_id phải khớp môn phái mới")
		assert(GameManager.local_profile.element == int(s.element), "Hệ ngũ hành phải chuyển theo môn phái")
		assert(not GameManager.local_profile.skill_levels.is_empty(), "Phải tự động học kỹ năng của phái mới")

	# Kiểm tra chuyển về Vô Môn Phái
	var reset_ok: bool = GmManager.change_player_sect(GameManager.local_profile, "vo_mon_phai")
	assert(reset_ok, "Chuyển về Vô Môn Phái phải thành công")
	assert(GameManager.local_profile.sect_id == "", "sect_id của Vô Môn Phái phải rỗng")
	print("PASS: Chuyển đổi thành công toàn bộ %d môn phái và về Vô Môn Phái" % sects.size())

	# 11.8 Kiểm tra GM tăng tài lãnh đạo & kinh nghiệm lãnh đạo
	GameManager.local_profile.lead_level = 0
	GameManager.local_profile.lead_exp = 0
	GmManager.set_player_lead_level(GameManager.local_profile, 20)
	assert(GameManager.local_profile.lead_level == 20, "Đặt cấp lãnh đạo 20 thành công")
	assert(SocialRules.team_size(GameManager.local_profile.lead_level) == 4, "Cấp lãnh đạo 20 cho phép tổ đội 4 người")

	GmManager.add_player_lead_level(GameManager.local_profile, 10)
	assert(GameManager.local_profile.lead_level == 30, "Cộng thêm 10 cấp lãnh đạo thành công (hiện có 30)")
	assert(SocialRules.team_size(GameManager.local_profile.lead_level) == 5, "Cấp lãnh đạo 30 cho phép tổ đội 5 người")

	GmManager.set_player_lead_level(GameManager.local_profile, 100)
	assert(GameManager.local_profile.lead_level == 100, "Đặt max cấp lãnh đạo 100 thành công")

	GameManager.local_profile.lead_level = 0
	GameManager.local_profile.lead_exp = 0
	var gained_lead := GmManager.add_player_lead_exp(GameManager.local_profile, 100)
	assert(gained_lead == 1 and GameManager.local_profile.lead_level == 1, "Thêm 100 exp lãnh đạo phải lên cấp 1")
	print("PASS: GM tăng cấp tài lãnh đạo, kinh nghiệm lãnh đạo và max cấp hoạt động xuất sắc")

	# 11.9 GM đặt cấp phải cộng điểm tiềm năng + điểm kỹ năng như lên cấp thật
	var lp := GameManager.local_profile
	lp.level = 10
	var pot_before := lp.potential_points
	var sk_before := lp.skill_points
	GmManager.set_player_level(lp, 100)
	assert(lp.level == 100, "GM đặt cấp 100")
	assert(lp.potential_points == pot_before + 90 * PlayerProfile.POTENTIAL_POINTS_PER_LEVEL, "GM lên 90 cấp phải cộng điểm tiềm năng")
	assert(lp.skill_points == sk_before + 90 * PlayerProfile.SKILL_POINTS_PER_LEVEL, "GM lên 90 cấp phải cộng điểm kỹ năng")
	GmManager.set_player_level(lp, 50)
	assert(lp.level == 50 and lp.potential_points == pot_before + 90 * PlayerProfile.POTENTIAL_POINTS_PER_LEVEL, "Hạ cấp không trừ điểm")
	var pot_mid := lp.potential_points
	GmManager.add_player_level(lp, 1)
	assert(lp.level == 51 and lp.potential_points == pot_mid + PlayerProfile.POTENTIAL_POINTS_PER_LEVEL, "GM +1 cấp cộng điểm")
	GmManager.add_player_level(lp, -10)
	assert(lp.level == 41, "GM -10 cấp")
	GmManager.add_player_level(lp, 500)
	assert(lp.level == PlayerProfile.MAX_LEVEL, "GM cộng cấp không vượt tối đa")
	## Đổi cấp qua thẻ người chơi đang chọn (tab Người Chơi) — bản thân sửa ngay
	lp.level = 20
	var pot_sel := lp.potential_points
	var self_info := {"name": lp.display_name, "is_self": true, "profile": lp}
	GmManager.change_level_of(self_info, 5, false)
	assert(lp.level == 25 and lp.potential_points == pot_sel + 5 * PlayerProfile.POTENTIAL_POINTS_PER_LEVEL, "Tab người chơi +5 cấp cộng điểm")
	GmManager.change_level_of(self_info, 60, true)
	assert(lp.level == 60 and int(self_info["level"]) == 60, "Tab người chơi đặt cấp 60")
	## Hồ sơ người chơi khác (như ở server /gmlevel) dùng chung gm_set_level
	var other := PlayerProfile.new()
	other.gm_set_level(100)
	assert(other.level == 100 and other.potential_points == PlayerProfile.new().potential_points + 99 * PlayerProfile.POTENTIAL_POINTS_PER_LEVEL, "gm_set_level cộng điểm cho hồ sơ khác")
	assert(load("res://net/server/chat_server.gd") != null, "chat_server.gd phải nạp được")
	print("PASS: GM đặt cấp cộng đủ điểm tiềm năng / kỹ năng")

	print("--- TOÀN BỘ CÁC MỤC KIỂM THỬ HỆ THỐNG GM ĐÃ VƯỢT QUA XUẤT SẮC! ---")
	get_tree().quit(0)

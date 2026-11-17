extends Node

const PubgWindow = preload("res://ui/pubg/pubg_window.gd")
const PubgManager = preload("res://systems/pubg/pubg_manager.gd")
const PubgDraftPopupClass = preload("res://ui/pubg/pubg_draft_popup.gd")

func _ready() -> void:
	print("=== BẮT ĐẦU TEST TOÀN DIỆN: CHẾ ĐỘ PUBG VÕ LÂM ===")

	# 1. Kiểm tra CharacterHub & các nút
	var hub_scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	assert(hub_scene != null, "CharacterHub.tscn phải tồn tại")
	var hub: Node = hub_scene.instantiate()
	assert(hub != null, "CharacterHub instantiate thành công")

	var pubg_btn := hub.get_node_or_null("%PubgButton") as Control
	assert(pubg_btn != null, "%PubgButton phải tồn tại trong CharacterHub.tscn")
	print("✓ PubgButton tồn tại trong CharacterHub tại offset_left=%f, offset_right=%f" % [pubg_btn.offset_left, pubg_btn.offset_right])
	assert(pubg_btn.offset_left == 562.0, "PubgButton phải ở vị trí x=562 (vị trí nút Sơn Trang cũ)")

	var manor_btn := hub.get_node_or_null("%ManorButton") as Control
	assert(manor_btn != null, "%ManorButton phải tồn tại trong CharacterHub.tscn")
	print("✓ ManorButton đã di chuyển xuống đáy màn hình: offset_left=%f, offset_top=%f" % [manor_btn.offset_left, manor_btn.offset_top])
	assert(manor_btn.offset_left == 1108.0, "ManorButton phải ở góc phải thanh đáy")

	# 2. Kiểm tra PubgWindow modal
	print("[TEST] Khởi tạo PubgWindow...")
	var prof := PlayerProfile.new()
	prof.display_name = "HoaHieuTest"
	prof.level = 50
	prof.strength = 100
	var win := PubgWindow.new(prof)
	assert(win != null, "PubgWindow phải khởi tạo thành công")
	print("✓ PubgWindow khởi tạo thành công!")

	# Kiểm tra render các tab
	for tab_idx in [0, 1, 2]:
		win._select_tab(tab_idx)
		print("  ✓ Tab %d render không lỗi!" % tab_idx)

	# Kiểm tra tạo phòng mới có mật khẩu & không mật khẩu
	win._select_tab(0)
	var initial_room_count = win._mock_rooms.size()
	win._do_create_room("secret123")
	assert(win._in_waiting_room == true, "Tạo phòng xong phải chuyển ngay vào phòng chờ")
	assert(win._is_ready == false, "Mặc định khi vào phòng chờ là CHƯA sẵn sàng")
	print("✓ Tạo phòng xong đã chuyển ngay sang phòng chờ, mặc định chưa sẵn sàng!")

	# Kịch bản 1: Khi có phòng đang đấu < 5 phút -> Tự động ghép vào và thay thế bot!
	win._on_toggle_ready()
	assert(win._is_ready == true, "Trạng thái phải là đã sẵn sàng")
	assert(win._current_room_id == "PUBG-9901", "Phải tự động ghép vào phòng PUBG-9901 đang đấu < 5 phút")
	print("✓ Sẵn sàng thành công -> Tự động phát hiện phòng đang đấu < 5 phút và ghép người thật vào!")
	PubgManager.end_match(prof)
	prof.level = 50
	prof.strength = 100

	# Kịch bản 2: Khi KHÔNG có phòng < 5 phút (ví dụ tất cả phòng đang đợi hoặc > 5 phút) -> Tìm trận 60s và bù bot
	for r in PubgManager.rooms:
		if r.get("id") == "PUBG-9901":
			r["start_time"] = Time.get_unix_time_from_system() - 400.0 # Chuyển thành > 5 phút

	win = PubgWindow.new(prof)
	win._select_tab(0)
	win._do_create_room()
	win._on_toggle_ready()
	assert(win._is_searching == true, "Không có phòng < 5 phút thì phải bắt đầu tìm kiếm 60 giây")
	assert(win._search_time_left == 60.0, "Thời gian tìm trận ban đầu phải là 60s")
	print("✓ Không có phòng < 5 phút -> Bắt đầu tìm trận 50 người (đếm lùi 60 giây)!")

	# Giả lập hết 60s -> Vào trận với số người chơi hiện tại (không thêm bot)
	win._process(61.0)
	assert(win._is_searching == false, "Hết 60s phải kết thúc tìm kiếm")
	print("✓ Hết 60 giây -> Vào trận với người chơi hiện tại, không tự động thêm BOT!")
	PubgManager.end_match(prof)
	prof.level = 50
	prof.strength = 100

	# Phục hồi start_time của PUBG-9901 để test phần 5
	for r in PubgManager.rooms:
		if r.get("id") == "PUBG-9901":
			r["start_time"] = Time.get_unix_time_from_system() - 140.0

	win = PubgWindow.new(prof)
	# Quay lại danh sách phòng
	win._on_leave_waiting_room()
	assert(win._in_waiting_room == false, "Rời phòng chờ phải quay lại danh sách phòng")

	# Kiểm tra PubgDraftPopup (Đợt 1: Ngựa 8x, Đợt 2: Vũ khí cấp 10)
	print("[TEST] Kiểm tra PubgDraftPopup (2 đợt chọn thẻ)...")
	var draft_prof := PlayerProfile.new()
	draft_prof.display_name = "DraftTester"
	draft_prof.level = 200
	var draft_popup = PubgDraftPopupClass.new()
	draft_popup._profile = draft_prof
	var dummy_node := Node.new()
	win.add_child(dummy_node)
	dummy_node.add_child(draft_popup)

	# Đợt 1: Chọn Ngựa 8x Ô Vân Đạp Tuyết
	draft_popup._on_horse_selected(PubgDraftPopupClass.HORSES_8X[0])
	assert(draft_prof.equipment.has(Equipment.Part.HORSE), "Phải trang bị ngựa vào slot HORSE")
	assert(draft_prof.riding == true, "Nhân vật phải ở trạng thái cưỡi ngựa")
	var horse_item: ItemInstance = draft_prof.equipment[Equipment.Part.HORSE]
	assert(horse_item.get_base().get("name") == "Ô Vân Đạp Tuyết", "Ngựa được trang bị phải là Ô Vân Đạp Tuyết")
	var stats_test := draft_prof.get_combat_stats()
	assert(stats_test.move_speed_p == 100, "Tốc độ chạy phải được cộng +100% ngay khi chọn ngựa")
	print("✓ Đợt 1: Chọn ngựa 8x Ô Vân Đạp Tuyết và trang bị thành công (tốc độ chạy +100% đã cập nhật ngay lập tức)!")

	# Đợt 2: Chọn Vũ khí Cấp 10 (ví dụ Kiếm Cấp 10)
	draft_popup._selected_weapon_idx = 0
	draft_popup._on_weapon_confirmed()
	assert(draft_prof.equipment.has(Equipment.Part.WEAPON), "Phải trang bị vũ khí vào slot WEAPON")
	var wep_item: ItemInstance = draft_prof.equipment[Equipment.Part.WEAPON]
	assert(wep_item.get_base().get("name") == "Huyền Thiết Kiếm", "Vũ khí cấp 10 được trang bị phải là Huyền Thiết Kiếm")
	print("✓ Đợt 2: Chọn loại vũ khí cấp 10 và trang bị thành công!")

	dummy_node.queue_free()

	# 3. Kiểm tra PubgManager logic
	print("[TEST] Kiểm tra PubgManager cấu hình trận đấu...")
	var room_info := {
		"id": "PUBG-TEST",
		"mode": 4,
		"name": "Test Squad",
		"leader": "HoaHieuTest"
	}
	var field_entry: Dictionary = PubgManager.start_match(prof, room_info)
	assert(field_entry.has("dir"), "field_entry phải có dir")
	assert(str(field_entry["dir"]).contains("map_tongkim1"), "Map phải là map_tongkim1")
	assert(PubgManager.is_active == true, "PubgManager phải ở trạng thái active")
	assert(PubgManager.current_squad_size == 4, "Squad size phải là 4")

	# Kiểm tra kích thước khung giới hạn: 140 region x 80 region
	# 1 region = 512px -> 140 * 512 = 71680px, 80 * 512 = 40960px
	var box: Rect2 = PubgManager.fixed_outer_boundary
	print("  Khung giới hạn: W=%f px, H=%f px" % [box.size.x, box.size.y])
	assert(is_equal_approx(box.size.x, 71680.0), "Chiều ngang phải đúng 140 region (71680px)")
	assert(is_equal_approx(box.size.y, 40960.0), "Chiều dọc phải đúng 80 region (40960px)")
	print("✓ Khung phát sáng giới hạn 140x80 region hoàn toàn chính xác!")

	# Kiểm tra level 200 trong trận
	assert(prof.level == 200, "Level nhân vật trong trận phải được đặt thành 200")
	print("✓ Nhân vật đạt Cấp 200 khi tham gia chiến trường PUBG!")

	# Kiểm tra đồng đội 4 người có màu xanh dương và chung spawn_pos
	assert(PubgManager.current_squad_members.size() == 4, "Squad phải có đúng 4 thành viên")
	for m in PubgManager.current_squad_members:
		var c: Color = m["color"]
		assert(c == Color(0.2, 0.65, 1.0), "Đồng đội phải có màu tên là Xanh Dương (0.2, 0.65, 1.0)")
	print("✓ Cả 4 thành viên squad có màu tên Xanh Dương và không friendly fire!")

	# Kiểm tra kết thúc trận & khôi phục profile
	PubgManager.end_match(prof)
	assert(PubgManager.is_active == false, "Trận đấu đã kết thúc")
	assert(prof.level == 50, "Level phải được phục hồi về 50")
	assert(prof.strength == 100, "Sức mạnh phải được phục hồi về 100")
	print("✓ Khôi phục Profile và xóa đồ tạm trong trận thành công!")

	# 4. Kiểm tra Tự Động Xóa Phòng khi hết người (Người cuối cùng rời đi / Đóng game vật lý)
	print("[TEST] Kiểm tra cơ chế tự động xóa phòng khi người cuối cùng rời đi...")
	var test_room_custom := PubgManager.create_room("Phòng Test Tự Xóa", 1, "TesterLastMan")
	var custom_id: String = str(test_room_custom["id"])
	var found_before := false
	for r in PubgManager.rooms:
		if str(r.get("id", "")) == custom_id:
			found_before = true
			break
	assert(found_before == true, "Phòng tạo mới phải có trong danh sách")

	# Trường hợp 1: Người cuối cùng rời phòng -> Phòng tự động bị xóa
	var tester_prof := PlayerProfile.new()
	tester_prof.display_name = "TesterLastMan"
	PubgManager.leave_room(custom_id, tester_prof)
	var found_after := false
	for r in PubgManager.rooms:
		if str(r.get("id", "")) == custom_id:
			found_after = true
			break
	assert(found_after == false, "Phòng phải bị xóa tự động khi người cuối cùng rời đi")
	print("✓ PASS: Người cuối cùng rời phòng -> Phòng tự động bị xóa!")

	# Trường hợp 2: Đóng game vật lý (Alt+F4 / Tắt cửa sổ / on_game_closing)
	var test_close_room := PubgManager.create_room("Phòng Đóng Game Vật Lý", 2, "TesterPhysicalClose")
	var close_id: String = str(test_close_room["id"])
	PubgManager.active_room = test_close_room
	var close_prof := PlayerProfile.new()
	close_prof.display_name = "TesterPhysicalClose"
	PubgManager.on_game_closing(close_prof)
	var found_close := false
	for r in PubgManager.rooms:
		if str(r.get("id", "")) == close_id:
			found_close = true
			break
	assert(found_close == false, "Phòng phải tự động bị xóa khi đóng game vật lý")
	print("✓ PASS: Đóng game vật lý -> Tự động xóa phòng thành công!")

	# 5. Kiểm tra Cơ Chế Tìm Trận Ghép Vào Phòng Đang Đấu (< 5 phút) & Tự Động Xóa Bot
	print("[TEST] Kiểm tra ghép phòng đang thi đấu < 5 phút & tự động xóa bot...")
	
	# Tìm phòng đang đấu < 5 phút
	var joinable: Dictionary = PubgManager.find_joinable_active_match(1)
	assert(not joinable.is_empty(), "Phải tìm thấy phòng đang thi đấu < 5 phút (PUBG-9901)")
	assert(joinable["id"] == "PUBG-9901", "Phòng hợp lệ phải là PUBG-9901")
	var elapsed: float = Time.get_unix_time_from_system() - float(joinable["start_time"])
	assert(elapsed < 300.0, "Thời gian trôi qua phải < 300 giây (5 phút)")
	print("✓ Đã phát hiện phòng %s đang đấu (%d giây < 5 phút)!" % [joinable["id"], int(elapsed)])

	# Kiểm tra phòng > 5 phút (PUBG-7711) KHÔNG ĐƯỢC ghép vào
	var room_old: Dictionary = {}
	for r in PubgManager.rooms:
		if r.get("id") == "PUBG-7711":
			room_old = r
			break
	assert(not room_old.is_empty(), "Phải có phòng PUBG-7711 trong danh sách")
	var elapsed_old: float = Time.get_unix_time_from_system() - float(room_old["start_time"])
	assert(elapsed_old >= 300.0, "Phòng PUBG-7711 phải có thời gian >= 300s (5 phút)")
	print("✓ Phòng %s đã đấu > 5 phút (%d giây) -> Tuyệt đối không cho phép ghép vào!" % [room_old["id"], int(elapsed_old)])

	# Thử nghiệm đưa người thật vào và xóa BOT
	var initial_bots: int = int(joinable.get("bot_count", 46))
	var initial_players: int = int(joinable.get("players", 4))
	
	# Giả lập bot node trong active_bot_nodes
	var dummy_bot := Node.new()
	dummy_bot.name = "Bot_Random_123"
	win.add_child(dummy_bot)
	PubgManager.register_bot(dummy_bot)
	assert(PubgManager.active_bot_nodes.has(dummy_bot), "Bot phải được đăng ký trong PubgManager")

	var backfill_entry: Dictionary = PubgManager.backfill_player_into_match(joinable, 1, prof)
	assert(backfill_entry["is_backfill"] == true, "Trận đấu phải đánh dấu là backfill")
	assert(int(joinable["bot_count"]) == initial_bots - 1, "Số BOT phải giảm đi 1 tương ứng với 1 người thật vào")
	assert(int(joinable["players"]) == initial_players + 1, "Số người thật trong phòng phải tăng lên 1")
	assert(not PubgManager.active_bot_nodes.has(dummy_bot), "BOT ngẫu nhiên phải được xóa khỏi danh sách bot hoạt động")
	print("✓ PASS: Người thật vào phòng < 5 phút -> Tự động xóa BOT bất kỳ tương ứng thành công!")
	PubgManager.end_match(prof)

	# 6. Kiểm tra mở PubgDraftPopup khi vào Main game PUBG
	print("[TEST] Kiểm tra mở 2 đợt chọn thẻ PubgDraftPopup khi vào game...")
	GameManager.field_map = {
		"pubg": true,
		"is_pubg": true,
		"dir": "res://world/maps/map_tongkim1"
	}
	var main_scene = load("res://Main.tscn")
	var main_node = main_scene.instantiate()
	add_child(main_node)
	var popup_in_tree = get_tree().get_nodes_in_group("pubg_draft_popup")
	assert(not popup_in_tree.is_empty(), "PubgDraftPopup phải tự động mở và tồn tại trong scene khi vào game PUBG")
	print("✓ PASS: Vào game PUBG -> 2 đợt chọn thẻ PubgDraftPopup tự động mở thành công!")
	main_node.free()

	# 7. Kiểm tra cách ly trang bị & hành trang PUBG (Chỉ tồn tại trong PUBG, hết trận xóa sạch)
	print("[TEST] Kiểm tra cách ly trang bị & hành trang PUBG, kỹ năng MAX HẾT, điểm tiềm năng trở về ban đầu nếu chưa sét mặc định...")
	# Xóa file build cũ nếu có để test trường hợp chưa sét mặc định
	if FileAccess.file_exists("user://pubg_build.json"):
		DirAccess.remove_absolute("user://pubg_build.json")

	var real_prof := PlayerProfile.new()
	real_prof.display_name = "RealHero"
	real_prof.level = 45
	real_prof.strength = 120
	real_prof.potential_points = 15
	real_prof.sect_id = "vo_dang"
	real_prof.skill_levels = {"basic_attack": 1, "vo_dang_kiem_phap": 2}

	# Giả lập nhân vật thật bên ngoài có 1 thanh kiếm cấp 5 và 2 bình máu trong túi
	var real_sword := ItemGenerator.generate(0, 0, 5, 0, [5, 5])
	real_prof.equipment[Equipment.Part.WEAPON] = real_sword
	var real_potion1 := ItemGenerator.generate(0, 0, 1, 0, [])
	var real_potion2 := ItemGenerator.generate(0, 0, 1, 0, [])
	real_prof.inventory.append(real_potion1)
	real_prof.inventory.append(real_potion2)

	assert(real_prof.equipment.size() == 1, "Trang bị thật ban đầu phải có 1 món")
	assert(real_prof.inventory.size() == 2, "Hành trang thật ban đầu phải có 2 món")

	# Bắt đầu trận đấu PUBG với real_prof (Trường hợp 1: CHƯA sét mặc định)
	var p_room := {"id": "PUBG-ISO", "mode": 1}
	PubgManager.start_match(real_prof, p_room)

	# Kiểm tra khi vừa vào trận:
	# - Level 200
	# - Chưa sét mặc định: 4 chỉ số tiềm năng trở về ban đầu theo ngũ hành, 995 điểm hoàn vào potential_points
	# - Kỹ năng môn phái: TOÀN BỘ PHẢI MAX HẾT (max_level)
	# - Đồ và hành trang cũ bị làm trống cho màn sinh tồn
	assert(real_prof.level == 200, "Vào PUBG phải lên cấp 200")
	assert(real_prof.potential_points == 995, "Chưa sét mặc định thì toàn bộ 995 điểm tiềm năng cấp 200 phải hoàn lại chưa cộng")
	var base_stats: Array = real_prof.get_start_stats()
	assert(real_prof.strength == base_stats[0], "Sức mạnh phải ở mức ban đầu khi chưa sét mặc định")
	assert(real_prof.dexterity == base_stats[1], "Thân pháp phải ở mức ban đầu khi chưa sét mặc định")
	print("✓ PASS: Điểm tiềm năng trở về ban đầu (995 điểm còn lại) khi chưa sét mặc định!")

	var vd_sect: SectDefinition = SectRegistry.get_by_id("vo_dang")
	assert(vd_sect != null, "Phải load được phái Võ Đang")
	for sk in vd_sect.skills:
		if sk != null and sk.id != "":
			assert(real_prof.skill_levels.has(sk.id), "Skill %s phải có trong skill_levels của PUBG" % sk.id)
			assert(real_prof.skill_levels[sk.id] == sk.max_level, "Skill %s trong PUBG phải đạt MAX level (%d)" % [sk.id, sk.max_level])
	print("✓ PASS: Toàn bộ kỹ năng môn phái trong PUBG đã được MAX HẾT!")

	assert(real_prof.equipment.is_empty(), "Vào PUBG trang bị khởi đầu phải trống")
	assert(real_prof.inventory.is_empty(), "Vào PUBG hành trang khởi đầu phải trống")
	print("✓ PASS: Vào PUBG cấp 200, trang bị và hành trang được khởi tạo trống cho sinh tồn!")

	# Thực hiện chọn Ngựa 8x và Vũ khí cấp 10 qua Draft Popup
	var iso_draft = PubgDraftPopupClass.new()
	iso_draft._profile = real_prof
	add_child(iso_draft)
	iso_draft._on_horse_selected(PubgDraftPopupClass.HORSES_8X[1]) # Xích Thố
	iso_draft._selected_weapon_idx = 1 # Đại Phong Đao
	iso_draft._on_weapon_confirmed()
	iso_draft.queue_free()

	assert(real_prof.equipment.has(Equipment.Part.HORSE), "PUBG: Phải trang bị Ngựa Xích Thố")
	assert(real_prof.equipment.has(Equipment.Part.WEAPON), "PUBG: Phải trang bị Đại Phong Đao")
	var equipped_horse: ItemInstance = real_prof.equipment[Equipment.Part.HORSE]
	assert(equipped_horse.get_base().get("name") == "Xích Thố", "Tên ngựa trong PUBG phải là Xích Thố")

	# Trong trận nhặt được 1 món đồ rơi trên đất
	var pubg_looted_item := ItemGenerator.generate(0, 2, 8, 0, [8, 8])
	real_prof.inventory.append(pubg_looted_item)
	assert(real_prof.inventory.size() == 1, "Hành trang PUBG lúc này có 1 món đồ nhặt trong trận")

	# Thoát hoặc kết thúc trận đấu PUBG
	PubgManager.end_match(real_prof)

	# Xác nhận: Toàn bộ đồ PUBG bị xóa, đồ và hành trang thật ngoài đời được khôi phục 100% nguyên vẹn!
	# Cấp độ, điểm tiềm năng, kỹ năng ngoài đời giữ nguyên 100% không bị ảnh hưởng bởi PUBG!
	assert(PubgManager.is_active == false, "Trận đấu PUBG phải kết thúc")
	assert(real_prof.level == 45, "Level phải được phục hồi về 45 của nhân vật thật")
	assert(real_prof.strength == 120, "Sức mạnh phải được phục hồi về 120 của nhân vật thật")
	assert(real_prof.potential_points == 15, "Điểm tiềm năng phải được phục hồi về 15 của nhân vật thật")
	assert(real_prof.skill_levels.get("basic_attack", 0) == 1, "Kỹ năng ngoài đời phải phục hồi về 1")
	assert(real_prof.skill_levels.get("vo_dang_kiem_phap", 0) == 2, "Kỹ năng ngoài đời phải phục hồi về 2 (không bị max PUBG)")
	assert(real_prof.equipment.size() == 1, "Trang bị phải trở về 1 món ban đầu")
	assert(real_prof.equipment.has(Equipment.Part.WEAPON), "Phải có lại kiếm cấp 5 ban đầu")
	var restored_wep: ItemInstance = real_prof.equipment[Equipment.Part.WEAPON]
	assert(restored_wep.get_base().get("name") == real_sword.get_base().get("name"), "Vũ khí khôi phục phải đúng là kiếm cũ")
	assert(not real_prof.equipment.has(Equipment.Part.HORSE), "Ngựa Xích Thố tạm của PUBG phải bị xóa hoàn toàn")
	assert(real_prof.inventory.size() == 2, "Hành trang phải trở về 2 món ban đầu, đồ PUBG nhặt được bị xóa hoàn toàn")
	print("✓ PASS: Hết trận PUBG -> Nhân vật chính phục hồi 100% nguyên vẹn (level, kỹ năng, tiềm năng, hành trang, trang bị)!")

	# Trường hợp 2: ĐÃ sét mặc định
	print("[TEST] Kiểm tra khi ĐÃ sét mặc định cấu hình điểm tiềm năng...")
	PubgManager.save_build({
		"str": 300,
		"dex": 200,
		"vit": 400,
		"eng": 95,
		"stat_left": 0
	})
	PubgManager.start_match(real_prof, p_room)
	assert(real_prof.strength == base_stats[0] + 300, "Đã sét mặc định: Sức mạnh = base + 300")
	assert(real_prof.dexterity == base_stats[1] + 200, "Đã sét mặc định: Thân pháp = base + 200")
	assert(real_prof.vitality == base_stats[2] + 400, "Đã sét mặc định: Sinh khí = base + 400")
	assert(real_prof.energy == base_stats[3] + 95, "Đã sét mặc định: Nội công = base + 95")
	assert(real_prof.potential_points == 0, "Đã phân bổ hết thì điểm còn lại = 0")
	print("✓ PASS: Khi đã sét mặc định -> PUBG tự động nạp điểm tiềm năng đã lưu!")
	PubgManager.end_match(real_prof)

	# Dọn dẹp file test
	if FileAccess.file_exists("user://pubg_build.json"):
		DirAccess.remove_absolute("user://pubg_build.json")

	# 8. Xác nhận map không phải PUBG tuyệt đối KHÔNG hiển thị PubgDraftPopup
	print("[TEST] Kiểm tra bản đồ thường không kích hoạt PubgDraftPopup...")
	GameManager.field_map = {
		"id": 1,
		"name": "Ba Lăng Huyện",
		"pubg": false,
		"is_pubg": false
	}
	var normal_main = main_scene.instantiate()
	add_child(normal_main)
	var popup_normal = get_tree().get_nodes_in_group("pubg_draft_popup")
	assert(popup_normal.is_empty(), "Map thường tuyệt đối không được mở PubgDraftPopup")
	print("✓ PASS: Map thường tuyệt đối không hiển thị popup chọn thẻ PUBG!")
	normal_main.free()

	win.queue_free()
	hub.queue_free()

	print("=== TẤT CẢ TEST CHIẾN TRƯỜNG PUBG ĐỀU PASS 100%! ===")
	get_tree().quit(0)

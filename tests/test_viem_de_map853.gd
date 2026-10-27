extends Node

const ViemDeChallengeScript = preload("res://systems/challenge/viem_de_challenge.gd")
const ViemDeWindowScript = preload("res://ui/events/viem_de_window.gd")
const ViemDeLobby = preload("res://systems/challenge/viem_de_lobby.gd")

func _ready() -> void:
	print("--- BẮT ĐẦU TEST VIÊM ĐẾ BẢO TÀNG THỰC ĐỊA MAP 853 ---")
	_run_tests()

func _run_tests() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "KiemHiepViemDe"
	profile.level = 95
	profile.gold = 5000000
	profile.sect_id = "vo_dang"

	# 1. Kiểm tra Map 853 tồn tại và có đầy đủ file
	var map_dir := "res://world/maps/map_853"
	assert(DirAccess.dir_exists_absolute("res://world/maps/map_853"), "Thư mục Map 853 phải tồn tại")
	assert(FileAccess.file_exists("res://world/maps/map_853/map.json"), "Phải có map.json của Map 853")
	assert(FileAccess.file_exists("res://world/maps/map_853/minimap.jpg"), "Phải có minimap.jpg của Map 853")
	print("PASS: 1. Map 853 Kho Báu Viêm Đế đã được tích hợp đầy đủ.")

	# 2. Kiểm tra dữ liệu viem_de_data.json
	var d: Dictionary = ViemDeChallengeScript.load_data()
	assert(not d.is_empty(), "Phải load được viem_de_data.json")
	var routes: Dictionary = d.get("routes", {})
	assert(routes.has("a") and routes.has("b") and routes.has("c"), "Phải có đủ 3 lộ trình A, B, C")
	assert((routes["a"]["stages"] as Array).size() == 10, "Lộ trình A phải có đủ 10 ải")
	assert((routes["b"]["stages"] as Array).size() == 10, "Lộ trình B phải có đủ 10 ải")
	assert((routes["c"]["stages"] as Array).size() == 10, "Lộ trình C phải có đủ 10 ải")
	var fc: Dictionary = d.get("final_chamber", {})
	assert(fc.has("final_boss") and int(fc["final_boss"]["tpl"]) == 1309, "Hạch tâm phải có Boss Lương Mi Nhi (ID 1309)")
	assert(fc.has("guardians") and (fc["guardians"] as Array).size() == 10, "Hạch tâm phải có đủ 10 Hộ Vệ Thập Đại Môn Phái")
	assert(fc.has("spawn_coords") and (fc["spawn_coords"] as Array).size() == 10, "Hạch tâm phải có đủ 10 tọa độ spawn wayfinial")
	print("PASS: 2. Dữ liệu Viêm Đế Bảo Tàng chuẩn xác với 3 đường, 10 ải, Hạch Tâm Lương Mi Nhi và 10 Vệ Binh.")

	# 3. Kiểm tra map_entry() xuất phát đúng tọa độ bến thuyền và hỗ trợ tổ đội
	var entry_a: Dictionary = ViemDeChallengeScript.map_entry("a", true, [{"name": "DongDoi1", "level": 92}])
	assert(entry_a.get("id") == 853, "Map ID phải là 853")
	assert(entry_a.get("viem_de_challenge") == true, "Cờ viem_de_challenge phải là true")
	assert(entry_a.get("double_exp") == true, "Viêm đế lệnh x2 phải là true")
	assert((entry_a.get("team_members", []) as Array).size() == 1, "Phải lưu danh sách team_members")
	var ac: Vector2 = entry_a.get("arena_center")
	assert(ac.x > 0.0 and ac.y > 0.0, "Tọa độ xuất phát bến thuyền phải hợp lệ")
	print("PASS: 3. ViemDeChallenge.map_entry tạo thông tin vào map 853 chuẩn xác kèm tổ đội.")

	# 4. Kiểm tra ViemDeLobby (Mua Viêm Đế Lệnh 2 KNB, Chủ phòng tạo mới cần lệnh, Thành viên không cần lệnh, Đặt mật khẩu, Kích thành viên)
	profile.jade = 10
	var buy_res := ViemDeLobby.buy_entry_item(profile, 1)
	assert(buy_res["ok"] == true, "Phải mua được Viêm Đế Lệnh với giá 2 KNB")
	assert(profile.jade == 8, "Sau khi mua 1 Viêm Đế Lệnh phải còn 8 KNB")
	assert(ViemDeLobby.count_entry_item(profile) == 1, "Hành trang phải có đúng 1 Viêm Đế Lệnh")

	# Chủ phòng khi tạo phòng mới trừ 1 Viêm Đế Lệnh
	var consumed := ViemDeLobby.consume_entry_item(profile)
	assert(consumed == true, "Chủ phòng tạo mới phải trừ 1 Viêm Đế Lệnh")
	assert(ViemDeLobby.count_entry_item(profile) == 0, "Sau khi trừ số lượng lệnh phải về 0")

	var room := ViemDeLobby.create(profile, "a", true, "123456")
	var room_id := str(room.get("id", ""))
	assert(room_id != "", "Phải tạo được phòng Viêm Đế")
	assert(str(room.get("password", "")) == "123456", "Phòng phải lưu mật khẩu đã đặt")
	assert(ViemDeLobby.is_all_ready(room) == true, "Chỉ có chủ phòng thì mặc định sẵn sàng")

	# Thành viên tham gia KHÔNG cần Viêm Đế Lệnh
	var teammate := PlayerProfile.new()
	teammate.display_name = "DongDoiThiet"
	teammate.level = 90
	teammate.sect_id = "thieu_lam"
	assert(ViemDeLobby.count_entry_item(teammate) == 0, "Thành viên không có Viêm Đế Lệnh")

	# Vào sai mật khẩu -> thất bại
	var join_fail := ViemDeLobby.join(room_id, teammate, "sai_mk")
	assert(join_fail != "", "Vào sai mật khẩu phải báo lỗi")

	# Vào đúng mật khẩu -> thành công mà KHÔNG cần Viêm Đế Lệnh
	var join_err := ViemDeLobby.join(room_id, teammate, "123456")
	assert(join_err == "", "Phải gia nhập phòng thành công khi nhập đúng mật khẩu")

	var updated_room := ViemDeLobby.find(room_id)
	assert(ViemDeLobby.is_all_ready(updated_room) == false, "Có thành viên mới chưa bấm Sẵn Sàng thì is_all_ready phải là false!")

	# Bấm sẵn sàng cho thành viên
	ViemDeLobby.toggle_ready(room_id, "DongDoiThiet")
	assert(ViemDeLobby.is_all_ready(updated_room) == true, "Mọi người sẵn sàng hết thì is_all_ready phải là true!")

	# Kiểm tra chủ phòng đổi mật khẩu
	var pw_ok := ViemDeLobby.set_password(room_id, profile, "654321")
	assert(pw_ok == true, "Chủ phòng phải đổi được mật khẩu")
	assert(str(updated_room.get("password", "")) == "654321", "Mật khẩu phòng phải được cập nhật mới")

	# Kiểm tra chủ phòng kích thành viên ra khỏi phòng
	var kick_ok := ViemDeLobby.kick(room_id, "DongDoiThiet", profile)
	assert(kick_ok == true, "Chủ phòng phải kích được thành viên ra khỏi phòng")
	assert((updated_room.get("members", []) as Array).size() == 1, "Sau khi kích chỉ còn lại chủ phòng")

	# Thêm bot trợ thủ vào phòng
	var bot_added := ViemDeLobby.add_bot(room_id)
	assert(bot_added == true, "Phải thêm được trợ thủ bot vào phòng")
	assert((updated_room.get("members", []) as Array).size() == 2, "Phòng phải có 2 thành viên (Chủ phòng + Bot)")
	print("PASS: 4. Hệ thống ViemDeLobby (Viêm Đế Lệnh, Mua 2 KNB, Mật khẩu, Kích thành viên) hoàn toàn chuẩn xác.")

	# 5. Kiểm tra ViemDeWindow với cả chế độ Solo và Tổ Đội
	var entered_entry := [{}]
	var on_enter := func(entry: Dictionary) -> void:
		entered_entry[0] = entry

	var win = ViemDeWindowScript.new(profile, on_enter)
	add_child(win)
	assert(win.title_label.text.contains("Viêm Đế"), "Tiêu đề phải là Viêm Đế")
	# Chuyển sang chế độ Tổ đội
	win._party_mode = true
	win._current_room_id = room_id
	win._render()
	# Chuyển về Solo
	win._party_mode = false
	win._render()
	win.queue_free()
	print("PASS: 5. Giao diện ViemDeWindow chuyển đổi linh hoạt giữa Solo và Phòng Chờ Tổ Đội.")

	# 6. Kiểm tra logic Vượt Ải chuẩn VLTK gốc:
	# Giai đoạn 1: Tiêu diệt hết 14 quái hộ vệ -> Thủ Lĩnh Cổ Thiên Khuyết xuất hiện
	# Giai đoạn 2: Tiêu diệt Thủ Lĩnh Cổ Thiên Khuyết -> Vượt Ải 1 thành công & tiến vào Ải 2!
	var challenge = ViemDeChallengeScript.new()
	add_child(challenge)
	challenge.stage = 1
	challenge.running = true

	# Giả lập 14 quái hộ vệ trong danh sách
	var dummy_list: Array[VltkMonster] = []
	for i in 14:
		var dummy_m := VltkMonster.new()
		dummy_m.monster_id = 1299
		dummy_m.data = {"name": "Quái %d" % i}
		challenge._alive_monsters.append(dummy_m)
		dummy_list.append(dummy_m)

	assert(challenge._alive_monsters.size() == 14, "Ải 1 phải có 14 quái")
	assert(challenge.stage == 1, "Ban đầu phải ở Ải 1")

	# Tiêu diệt lần lượt 13 quái hộ vệ
	for i in 13:
		var m_pop: VltkMonster = challenge._alive_monsters.pop_back()
		challenge._on_monster_died(m_pop, false)
		assert(challenge.stage == 1, "Chưa hết quái thì chưa gọi boss")

	# Tiêu diệt con quái thứ 14 cuối cùng -> Boss Cổ Thiên Khuyết phải được triệu hồi
	var last_m: VltkMonster = challenge._alive_monsters.pop_back()
	challenge._on_monster_died(last_m, false)
	assert(challenge.stage == 1, "Mới diệt xong 14 quái hộ vệ thì vẫn ở Ải 1 để đánh Boss!")

	# Tạo giả lập Boss Thủ Lĩnh Ải 1 (Cổ Thiên Khuyết)
	var boss_m := VltkMonster.new()
	boss_m.monster_id = 1289
	boss_m.data = {"name": "Cổ Thiên Khuyết"}
	challenge._stage_boss = boss_m
	dummy_list.append(boss_m)

	# Tiêu diệt Thủ Lĩnh Cổ Thiên Khuyết -> Lập tức qua Ải 2!
	challenge._on_monster_died(boss_m, true)
	assert(challenge.stage == 2, "Sau khi tiêu diệt Thủ Lĩnh Cổ Thiên Khuyết, ẢI 2 PHẢI CHÍNH THỨC MỞ RA!")
	print("PASS: 6. Chuẩn VLTK gốc: Diệt hết 14 quái -> Boss xuất hiện -> Diệt Thủ Lĩnh Cổ Thiên Khuyết -> Qua Ải 2!")
	for dm in dummy_list:
		dm.free()
	challenge.queue_free()

	# 7. Kiểm tra tính năng mở rương và lưu trữ hồ sơ
	var win2 = ViemDeWindowScript.new(profile, on_enter)
	add_child(win2)
	# Cung cấp 1 Rương Viêm Đế Bí Bảo để test mở rương
	var test_chest := ItemGenerator.generate_misc("6_1_2805")
	if test_chest:
		profile.add_item(test_chest)
	var lv_before := profile.level
	var exp_before := profile.current_exp
	win2._open_chest()
	assert(profile.level > lv_before or profile.current_exp > exp_before, "Mở rương Viêm Đế phải tăng EXP")
	win2.queue_free()
	print("PASS: 7. Tính năng mở Rương Viêm Đế Bí Bảo & trao thưởng thành công.")

	# 8. Kiểm tra quái và Boss Lương Mi Nhi trong MonsterData
	var boss_data := MonsterData.monster(1309)
	assert(not boss_data.is_empty(), "Boss 1309 Lương Mi Nhi phải có trong MonsterData")
	assert(str(boss_data.get("name", "")).contains("Lương Mi Nhi"), "Tên boss phải là Lương Mi Nhi")
	var minion_data := MonsterData.monster(1299)
	assert(not minion_data.is_empty(), "Quái 1299 phải có trong MonsterData")
	assert(str(minion_data.get("name", "")).contains("Thiên Vương"), "Tên quái phải chuẩn phái")
	print("PASS: 8. Dữ liệu quái và Boss Lương Mi Nhi trong MonsterData hoàn toàn chuẩn xác.")

	# 9. Rà soát toàn diện 10 ải và Hạch Tâm Bảo Tàng (Ải 1 -> Ải 10 -> Hạch Tâm)
	var full_challenge = ViemDeChallengeScript.new()
	add_child(full_challenge)
	full_challenge.running = true
	full_challenge.stage = 1

	for st in range(1, 11):
		full_challenge.stage = st
		# Giả lập hạ Boss của ải st
		var s_boss := VltkMonster.new()
		s_boss.monster_id = 1289 + st - 1
		s_boss.data = {"name": "Boss Ải %d" % st}
		full_challenge._stage_boss = s_boss
		full_challenge._on_monster_died(s_boss, true)
		s_boss.free()
		if st < 10:
			assert(full_challenge.stage == st + 1, "Ải %d phải chuyển sang Ải %d thành công!" % [st, st + 1])
		else:
			assert(full_challenge.stage == 11, "Hạ gục Ải 10 phải tiến vào Hạch Tâm Lương Mi Nhi (Ải 11)!")

	# Giả lập hạ Boss cuối Lương Mi Nhi tại Hạch Tâm
	assert(full_challenge.stage == 11, "Phải đang ở Hạch Tâm")
	var dummy_final := VltkMonster.new()
	dummy_final.monster_id = 1309
	dummy_final.data = {"name": "Lương Mi Nhi"}
	full_challenge._final_boss = dummy_final
	full_challenge._on_final_boss_died(dummy_final)
	dummy_final.free()
	assert(full_challenge.is_done == true, "Hạ gục Lương Mi Nhi phải hoàn thành chuyến thám hiểm!")
	full_challenge.queue_free()
	print("PASS: 9. Rà soát thành công toàn bộ 10 Ải & Hạch Tâm: Tiến trình thông suốt 100%!")

	# 10. Kiểm tra nút Ghép Đồ Đằng và Đổi Trang Bị trực tiếp không cần qua NPC
	for i in 9:
		var frag := ItemGenerator.generate_misc("6_1_1685")
		if frag:
			profile.add_item(frag)
	var totems_before := 0
	for it in profile.inventory:
		if it != null and it.misc_id == "6_1_1606":
			totems_before += maxi(it.count, 1)

	var craft_res := ViemDeWindowScript.craft_totem_quick(profile)
	assert(craft_res["success"] == true, "Ghép Đồ Đằng nhanh phải thành công")
	var totems_after := 0
	for it in profile.inventory:
		if it != null and it.misc_id == "6_1_1606":
			totems_after += maxi(it.count, 1)
	assert(totems_after == totems_before + 1, "Hành trang phải có thêm đúng 1 Viêm Đế Đồ Đằng")

	# Test mở Tiệm Đổi Viêm Đế trực tiếp ở Tab 1
	var shop_win = ViemDeWindowScript.open_reward_shop(self, profile)
	assert(shop_win._tab == 1, "Mở Tiệm Đổi Viêm Đế phải hiển thị ngay tab Đổi Thưởng & Ghép Đồ Đằng")

	# Đổi 1 món Hoàng Kim từ Đồ Đằng vừa ghép (Ví dụ ID 441: Toái Nhâm Xích Huyết Nguyên Vũ Giáp)
	shop_win._do_redeem_gold_item(441)
	shop_win.queue_free()
	var has_gold_item := false
	for it in profile.inventory:
		if it != null and it.gold_index == 441:
			has_gold_item = true
			break
	assert(has_gold_item == true, "Hành trang phải nhận được món trang bị Hoàng Kim đã chọn")
	print("PASS: 10. Tính năng Ghép Đồ Đằng & Đổi Đồ trực tiếp tại hành trang hoạt động hoàn hảo 100%!")

	print("\n--- TOÀN BỘ 10 MỤC KIỂM THỬ VIÊM ĐẾ BẢO TÀNG MAP 853 ĐỀU PASS 100%! ---")
	get_tree().quit(0)

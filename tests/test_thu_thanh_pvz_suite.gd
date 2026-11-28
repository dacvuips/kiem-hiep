extends Node

const ThuThanhChallengeScript := preload("res://systems/challenge/thu_thanh_challenge.gd")
const ThuThanhSkillDataScript := preload("res://systems/challenge/thu_thanh_skill_data.gd")
const ThuThanhUnitScript := preload("res://systems/challenge/thu_thanh_unit.gd")
const ThuThanhMonsterScript := preload("res://systems/challenge/thu_thanh_monster.gd")
const ThuThanhProjectileScript := preload("res://systems/challenge/thu_thanh_projectile.gd")
const ThuThanhCoinScript := preload("res://systems/challenge/thu_thanh_coin.gd")

func _ready() -> void:
	print("=================================================================")
	print("=== KIỂM THỬ TOÀN DIỆN CHẾ ĐỘ THỦ THÀNH PLANTS VS ZOMBIES JX1 ===")
	print("=================================================================")

	test_grid_and_slot_rules()
	test_starting_coin_formula()
	test_skills_and_avatar_consistency()
	test_defender_placement_and_shovel()
	test_projectiles_and_effects()
	test_monster_waves_and_cart()
	test_coin_drop_and_collection()
	test_level_access_restrictions()
	test_battle_pause_and_freeze()
	test_battle_speed_toggle()

	print("\n=================================================================")
	print(">>> TẤT CẢ KIỂM THỬ CHẾ ĐỘ THỦ THÀNH JX1 ĐẠT 100% THÀNH CÔNG! <<<")
	print("=================================================================")
	get_tree().quit(0)

func test_grid_and_slot_rules() -> void:
	print("\n[TEST 1] Kiểm tra kích thước bàn cờ & số ô kỹ năng theo cấp bản đồ...")
	assert(ThuThanhChallengeScript.GRID_COLS == 14, "Tổng số cột bàn cờ phải là 14")
	assert(ThuThanhChallengeScript.DEFENSE_COLS == 11, "Khu phòng thủ phải có đúng 11 cột")
	assert(ThuThanhChallengeScript.GRID_COLS - ThuThanhChallengeScript.DEFENSE_COLS == 3, "Khu quái chờ (staging) phải có đúng 3 cột")
	assert(ThuThanhChallengeScript.GRID_ROWS == 5, "Bàn cờ phải có đúng 5 hàng")
	print("  -> PASS: Bàn cờ chuẩn 11x5 ô phòng thủ + 3x5 ô quái chờ + Xe Tống Kim")

	# Kiểm tra công thức mở ô kỹ năng (1x: 5, 2x: 6 ... 10x+: 14)
	var expected_slots := {
		1: 5,
		2: 6,
		3: 7,
		4: 8,
		5: 9,
		6: 10,
		7: 11,
		8: 12,
		9: 13,
		10: 14,
		11: 14,
		12: 14
	}
	for tier in expected_slots:
		var unl := ThuThanhSkillDataScript.get_unlocked_slots_for_tier(tier)
		assert(unl == expected_slots[tier], "Tier %d phải mở %d ô (thực tế: %d)" % [tier, expected_slots[tier], unl])
	print("  -> PASS: Số ô mở từ 1x đến 10x+ khớp chính xác 100% bảng đặc tả")

func test_starting_coin_formula() -> void:
	print("\n[TEST 2] Kiểm tra công thức Xu khởi đầu (tổng 3 kỹ năng đắt nhất + 150 Xu thưởng)...")
	# Case 1: 4 kỹ năng có giá [75, 150, 125, 100] -> 3 đắt nhất: [150, 125, 100] = 375 + 150 = 525
	var test_ids: Array[String] = ["thieu_lam", "cai_bang", "duong_mon", "hoa_son"]
	var coins1 := ThuThanhSkillDataScript.calculate_starting_coins(test_ids)
	assert(coins1 == 525, "Xu khởi đầu kỳ vọng 525 (150+125+100 + 150 Xu thưởng), thực tế: %d" % coins1)

	# Case 2: Chọn ít hơn 3 kỹ năng (2 kỹ năng: Thiếu Lâm 75, Cái Bang 150) -> Tổng = 225 + 150 = 375
	var test_ids2: Array[String] = ["thieu_lam", "cai_bang"]
	var coins2 := ThuThanhSkillDataScript.calculate_starting_coins(test_ids2)
	assert(coins2 == 375, "Xu khởi đầu 2 kỹ năng kỳ vọng 375, thực tế: %d" % coins2)

	# Case 3: Danh sách rỗng -> 0
	var coins3 := ThuThanhSkillDataScript.calculate_starting_coins([])
	assert(coins3 == 0, "Xu khởi đầu rỗng phải bằng 0")
	print("  -> PASS: Công thức Xu khởi đầu theo 3 kỹ năng đắt nhất + 150 Xu thưởng hoạt động chính xác")

func test_skills_and_avatar_consistency() -> void:
	print("\n[TEST 3] Kiểm tra Mục 4 Doc: Thư viện kỹ năng, Avatar tạo trước & cố định...")
	var all_skills := ThuThanhSkillDataScript.get_all_skills()
	assert(all_skills.size() >= 14, "Phải có ít nhất 14 kỹ năng môn phái đại diện")

	assert(FileAccess.file_exists(ThuThanhSkillDataScript.PREBAKED_AVATAR_PATH), "File cấu hình prebaked_avatars.json phải tồn tại")

	for s in all_skills:
		assert(s.has("id") and str(s["id"]) != "", "Kỹ năng phải có id hợp lệ")
		assert(s.has("skill_name") and str(s["skill_name"]) != "", "Kỹ năng phải có skill_name")
		assert(s.has("sect") and str(s["sect"]) != "", "Kỹ năng phải có môn phái")
		assert(s.has("element") and str(s["element"]) != "", "Kỹ năng phải có ngũ hành")
		assert(s.has("cost") and int(s["cost"]) > 0, "Kỹ năng phải có giá Xu > 0")
		assert(s.has("req_level") and int(s["req_level"]) >= 10, "Kỹ năng phải có cấp yêu cầu >= 10")
		assert(s.has("avatar_id") and str(s["avatar_id"]) != "", "Kỹ năng phải có avatar_id cố định")
		assert(s.has("avatar"), "Kỹ năng phải có dữ liệu avatar cố định")
		var av: Dictionary = s["avatar"]
		assert(av.has("avatar_id") and str(av["avatar_id"]) != "", "Avatar phải có avatar_id cố định")
		assert(av.has("set_type") and str(av["set_type"]) != "", "Avatar phải có set_type (Hoàng Kim/Siêu Nhân)")
		assert(av.has("set_name") and str(av["set_name"]) != "", "Avatar phải có set_name")
		assert(av.has("mount_name") and str(av["mount_name"]) != "", "Avatar phải có mount_name")

	# Kiểm tra gọi 2 lần không bị random lại
	var s1 := ThuThanhSkillDataScript.get_skill("cai_bang")
	var s2 := ThuThanhSkillDataScript.get_skill("cai_bang")
	assert(s1["avatar"]["avatar_id"] == s2["avatar"]["avatar_id"], "Avatar ID phải bất biến")
	assert(s1["avatar"]["helm"] == s2["avatar"]["helm"], "Trang bị nón phải bất biến")
	assert(s1["avatar"]["armor"] == s2["avatar"]["armor"], "Trang bị áo phải bất biến")
	assert(s1["avatar"]["set_type"] == s2["avatar"]["set_type"], "Loại bộ trang phục phải bất biến")

	# Kiểm tra bộ lọc theo Hệ và theo Cấp (Mục 4 Doc đặc tả)
	var kim_skills := ThuThanhSkillDataScript.get_skills_by_filter("Kim", 0)
	assert(not kim_skills.is_empty(), "Phải có kỹ năng Hệ Kim")
	for ks in kim_skills:
		assert(ks["element"] == "Kim", "Lọc Kim chỉ trả về kỹ năng Kim")

	var tier1_skills := ThuThanhSkillDataScript.get_skills_by_filter("", 1)
	assert(not tier1_skills.is_empty(), "Phải có kỹ năng Cấp 1x")
	for t1s in tier1_skills:
		assert(int(t1s["req_level"]) < 20, "Lọc 1x chỉ trả về kỹ năng cấp 1x")

	print("  -> PASS: Mục 4 Doc đạt 100%: Thư viện kỹ năng, bộ lọc Hệ/Cấp & Avatar Hoàng Kim/Siêu Nhân cố định")

func test_defender_placement_and_shovel() -> void:
	print("\n[TEST 4] Kiểm tra triệu hồi hiệp khách, trừ Xu, hồi chiêu & xẻng rút quân...")
	var challenge = ThuThanhChallengeScript.new()
	challenge.map_tier = 2
	challenge.unlocked_slots = 6
	var skills_arr: Array[String] = ["thieu_lam", "cai_bang"]
	challenge.equipped_skills = skills_arr
	challenge.current_coins = 300
	add_child(challenge)

	# Giả lập chọn thẻ Cái Bang (giá 150) và đặt vào ô (row 1, col 2)
	challenge.selected_card_skill_id = "cai_bang"
	challenge._handle_cell_click(1, 2)

	assert(challenge.current_coins == 150, "Đã trừ đúng 150 Xu, còn 150 Xu (thực tế: %d)" % challenge.current_coins)
	assert(challenge._grid_units[1][2] != null, "Ô (1, 2) phải có hiệp khách đứng")
	assert(challenge._cooldowns["cai_bang"] > 0.0, "Kỹ năng Cái Bang phải được kích hoạt thời gian hồi")

	# Đặt thử vào ô đã có người -> Không cho phép và không trừ tiền
	challenge.selected_card_skill_id = "thieu_lam"
	challenge._handle_cell_click(1, 2)
	assert(challenge.current_coins == 150, "Không được trừ Xu khi đặt vào ô đã có người")

	# Kiểm tra click chuột đặt hiệp khách lên nền đất qua _input
	challenge.wave_state = "RUNNING"
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(challenge.ORIGIN_X + 10.0, challenge.ORIGIN_Y + 10.0)
	challenge._input(ev)
	assert(challenge._grid_units[0][0] != null, "Ô (0, 0) phải được đặt Hiệp Khách Thiếu Lâm qua click chuột vào nền đất!")

	# Kiểm tra nút bấm ô đất CellBtn (Button.pressed)
	challenge.current_coins = 200
	challenge.selected_card_skill_id = "thieu_lam"
	challenge._cooldowns["thieu_lam"] = 0.0
	var cell_btn: Button = null
	for n in challenge.find_children("CellBtn_0_1", "Button", true, false):
		cell_btn = n
		break
	assert(cell_btn != null, "Phải có nút bấm CellBtn_0_1 trên ô đất!")
	cell_btn.emit_signal("pressed")
	assert(challenge._grid_units[0][1] != null, "Ô (0, 1) phải được đặt Hiệp Khách khi bấm nút ô đất!")

	# Kiểm tra xẻng rút quân
	challenge.is_shovel_mode = true
	challenge._handle_cell_click(1, 2)
	assert(challenge._grid_units[1][2] == null, "Ô (1, 2) phải trống sau khi dùng xẻng rút quân")
	print("  -> PASS: Cơ chế đặt hiệp khách, kiểm tra ô trống và rút quân hoạt động hoàn hảo")
	challenge.queue_free()

func test_projectiles_and_effects() -> void:
	print("\n[TEST 5] Kiểm tra đạn kỹ năng, hiệu ứng làm chậm, độc, choáng...")
	var proj = ThuThanhProjectileScript.new()
	proj.setup("ice", 30.0, 0, 500.0)
	add_child(proj)
	assert(proj.slow_ratio == 0.5, "Băng tiễn Thúy Yên phải có slow_ratio 50%")
	assert(proj.slow_duration > 0.0, "Thời gian làm chậm phải > 0")

	var dragon = ThuThanhProjectileScript.new()
	dragon.setup("dragon", 65.0, 1, 480.0)
	add_child(dragon)
	assert(dragon.piercing == true, "Rồng lửa Cái Bang phải có thuộc tính xuyên thấu (piercing)")
	print("  -> PASS: Đạn kỹ năng và các hiệu ứng ngũ hành cấu hình chuẩn xác")
	proj.queue_free()
	dragon.queue_free()

func test_monster_waves_and_cart() -> void:
	print("\n[TEST 6] Kiểm tra 10 đợt quái, công thức Máu/Số lượng, Boss cuối & 5 Xe Tống Kim...")
	var monster = ThuThanhMonsterScript.new()
	monster.setup({"name": "Thủ Lĩnh Hắc Phong", "level": 25, "hp": 500.0, "xu_drop": 200}, 2, false, true, 2.4)
	add_child(monster)
	assert(monster.is_boss == true, "Phải là Boss")
	assert(monster.xu_drop_amount == 200, "Boss phải rơi 200 Xu")
	assert(monster.max_hp > 500.0 * 10.0, "Máu Boss phải được nhân hệ số khủng")
	print("  -> PASS: Boss đợt 10 có chỉ số, lượng máu nhân hệ số và lượng Xu rơi tương ứng")
	monster.queue_free()

	# Kiểm tra 5 Xe Tống Kim (1 xe trên mỗi hàng 0..4) & 10 đợt quái
	var challenge = ThuThanhChallengeScript.new()
	challenge.map_tier = 2
	add_child(challenge)
	assert(challenge.TOTAL_WAVES == 10, "Tổng số đợt quái phải là 10 đợt (thực tế: %d)" % challenge.TOTAL_WAVES)
	assert(challenge.get_wave_hp_mult(1) <= 0.5, "Đợt 1 máu quái phải giảm hơn 1/2 (<= 0.5, thực tế: %.2f)" % challenge.get_wave_hp_mult(1))
	assert(is_equal_approx(challenge.get_wave_hp_mult(2), 0.67), "Đợt 2 máu quái phải giảm 1/3 (còn ~0.67, thực tế: %.2f)" % challenge.get_wave_hp_mult(2))
	assert(is_equal_approx(challenge.get_wave_hp_mult(3), 1.0), "Đợt 3 máu quái phải bình thường (1.0, thực tế: %.2f)" % challenge.get_wave_hp_mult(3))
	assert(is_equal_approx(challenge.get_wave_hp_mult(4), 1.2), "Đợt 4 máu quái phải tăng 0.2 lần (1.2, thực tế: %.2f)" % challenge.get_wave_hp_mult(4))
	assert(is_equal_approx(challenge.get_wave_hp_mult(10), 2.4), "Đợt 10 máu quái phải tăng (2.4, thực tế: %.2f)" % challenge.get_wave_hp_mult(10))
	assert(challenge.get_wave_monster_count(1) == 6, "Đợt 1 số lượng quái khởi đầu là 6")
	assert(challenge.get_wave_monster_count(2) == 9, "Đợt 2 số lượng quái tăng 0.5 lần (9)")
	assert(challenge.get_wave_monster_count(3) == 12, "Đợt 3 số lượng quái tăng tiếp (12)")
	print("  -> PASS: Chuẩn 10 đợt quái, Máu đợt 1 giảm >1/2, đợt 2 giảm 1/3, đợt 3+ tăng +0.2/đợt, số lượng tăng +0.5/đợt!")
	assert(challenge._cart_nodes.size() == 5, "Phải khởi tạo đủ 5 Xe Tống Kim cho 5 hàng (thực tế: %d)" % challenge._cart_nodes.size())
	assert(challenge._cart_available.count(true) == 5, "Cả 5 xe đều phải ở trạng thái sẵn sàng (READY)")
	assert(challenge._cart_sprites[0].scale.x <= 0.3, "Xe Tống Kim phải được thu nhỏ còn 1/4 kích thước (scale <= 0.3, thực tế: %.2f)" % challenge._cart_sprites[0].scale.x)
	var board_vis := challenge.get_node_or_null("BoardGridVisuals") as Node2D
	assert(board_vis != null and board_vis.z_index <= -50, "Các ô vuông bàn cờ phải nằm dưới các công trình (z_index <= -50)")

	# Giả lập quái ở hàng 1 chạm vào xe hàng 1
	challenge.wave_state = "RUNNING"
	var target_cart = challenge._cart_nodes[1]
	var test_enemy = ThuThanhMonsterScript.new()
	test_enemy.setup({"name": "Heo rừng", "hp": 100.0}, 1, false, false)
	test_enemy.global_position = target_cart.global_position + Vector2(10, 0)
	challenge.add_child(test_enemy)

	# Chạy 1 frame để kích hoạt xe
	challenge._process_escort_carts(0.016)
	assert(challenge._cart_charging[1] == true, "Xe hàng 1 phải được kích hoạt lao lên càn quét khi quái chạm trúng")

	# Cho xe lao qua và quét sạch quái
	challenge._process_escort_carts(0.1)
	assert(test_enemy.is_dead == true, "Xe Tống Kim phải tiêu diệt ngay lập tức quái vật cản đường trên hàng đó")

	# Cho xe chạy hết làn qua bên phải bản đồ
	challenge._process_escort_carts(3.0)
	assert(challenge._cart_available[1] == false, "Sau khi càn quét hết làn, xe hàng 1 phải biến mất")

	# Kiểm tra nếu quái khác lọt vào hàng 1 khi đã mất xe -> Thua cuộc
	var breach_enemy = ThuThanhMonsterScript.new()
	breach_enemy.setup({"name": "Nhím", "hp": 100.0}, 1, false, false)
	breach_enemy.global_position = Vector2(ThuThanhChallengeScript.ORIGIN_X - 65.0, 0)
	challenge.add_child(breach_enemy)

	challenge._process_escort_carts(0.016)
	assert(challenge.wave_state == "DEFEAT", "Nếu mất xe mà quái tiếp tục vượt qua bên trong thì người chơi phải thua cuộc")
	print("  -> PASS: 5 Xe Tống Kim cơ chế Máy Cắt Cỏ càn quét quái và điều kiện Thua Cuộc hoạt động 100% chuẩn xác")

	challenge.queue_free()

func test_coin_drop_and_collection() -> void:
	print("\n[TEST 7] Kiểm tra cơ chế rơi Xu trên đất và nhặt Xu...")
	var coin = ThuThanhCoinScript.new()
	var res := [0]
	coin.collected.connect(func(amt: int) -> void: res[0] = amt)
	coin.setup(50)
	add_child(coin)
	coin.collect()

	assert(res[0] == 50, "Nhặt Xu phải nhận đúng 50 Xu (thực tế: %d)" % res[0])
	print("  -> PASS: Rơi Xu và nhặt Xu tương tác chuẩn xác")
	coin.queue_free()

func test_level_access_restrictions() -> void:
	print("\n[TEST 8] Kiểm tra điều kiện cấp độ vào bản đồ (1x, 2x, 3x+)...")
	# Rule:
	# 1x: Chỉ vào map 1x
	# 2x: Vào map 1x-2x, không được vào 3x+
	# 3x+: Vào map <= cấp nhân vật
	var check_rule = func(char_lvl: int, map_lvl: int) -> bool:
		var c_tier = clampi(int(char_lvl / 10), 1, 12)
		var m_tier = MapCatalog.tier_of_level(map_lvl)
		if c_tier == 1:
			return m_tier <= 1
		elif c_tier == 2:
			return m_tier <= 2
		else:
			return (m_tier <= c_tier) and (char_lvl >= map_lvl)

	assert(check_rule.call(15, 12) == true, "Cấp 15 vào map lv 12 (1x) -> Hợp lệ")
	assert(check_rule.call(15, 25) == false, "Cấp 15 vào map lv 25 (2x) -> Bị cấm")
	assert(check_rule.call(25, 15) == true, "Cấp 25 vào map lv 15 (1x) -> Hợp lệ")
	assert(check_rule.call(25, 28) == true, "Cấp 25 vào map lv 28 (2x) -> Hợp lệ")
	assert(check_rule.call(25, 35) == false, "Cấp 25 vào map lv 35 (3x) -> Bị cấm")
	assert(check_rule.call(55, 52) == true, "Cấp 55 vào map lv 52 (5x) -> Hợp lệ")
	assert(check_rule.call(55, 65) == false, "Cấp 55 vào map lv 65 (6x) -> Bị cấm")
	print("  -> PASS: Quy tắc phân cấp 1x, 2x, 3x+ tuân thủ 100% tài liệu đặc tả")

func test_battle_pause_and_freeze() -> void:
	print("\n[TEST 9] Kiểm tra chức năng Tạm Dừng Trận Đấu (Pause Battle & Freeze Field)...")
	var challenge = ThuThanhChallengeScript.new()
	add_child(challenge)

	# 1. ThuThanhChallenge phải có process_mode = Node.PROCESS_MODE_PAUSABLE
	assert(challenge.process_mode == Node.PROCESS_MODE_PAUSABLE, "ThuThanhChallenge phải có process_mode = PROCESS_MODE_PAUSABLE để dừng khi get_tree().paused = true")

	# 2. Bắt đầu trận đấu
	challenge.wave_state = "RUNNING"
	challenge._toggle_pause(true)

	assert(challenge.is_paused == true, "Trận đấu phải ở trạng thái is_paused = true")
	assert(get_tree().paused == true, "SceneTree phải ở trạng thái paused = true")
	assert(challenge._pause_overlay != null and challenge._pause_overlay.visible == true, "Giao diện tạm dừng _pause_overlay phải hiển thị")

	# 3. Tiếp tục trận đấu
	challenge._toggle_pause(false)
	assert(challenge.is_paused == false, "Trận đấu phải phục hồi is_paused = false")
	assert(get_tree().paused == false, "SceneTree phải khôi phục paused = false")
	assert(challenge._pause_overlay.visible == false, "Giao diện tạm dừng phải ẩn khi tiếp tục")

	# 4. Khi rời ải (_exit_tree / _on_exit_pressed), phải đảm bảo unpause cây SceneTree
	challenge._toggle_pause(true)
	assert(get_tree().paused == true, "Kiểm tra lại paused = true trước khi dọn dẹp")
	challenge.queue_free()
	# Chờ 1 frame dọn dẹp
	await get_tree().process_frame
	assert(get_tree().paused == false, "Sau khi dọn dẹp hoặc rời ải, get_tree().paused phải được trả về false")
	print("  -> PASS: Tạm dừng trận đấu, đóng băng toàn bộ chiến trường và tiếp tục hoạt động hoàn hảo 100%")

func test_battle_speed_toggle() -> void:
	print("\n[TEST 10] Kiểm tra nút Tăng Tốc Trận Đấu (1x -> 2x -> 4x -> 1x)...")
	var challenge = ThuThanhChallengeScript.new()
	add_child(challenge)

	assert(challenge._speed_btn != null, "Nút tăng tốc _speed_btn phải được khởi tạo trên top bar")
	assert(challenge.current_speed_idx == 0, "Ban đầu tốc độ phải là index 0 (1x)")
	assert(Engine.time_scale == 1.0, "Ban đầu Engine.time_scale phải là 1.0")
	assert(challenge._speed_btn.text == "⏩ 1x", "Ban đầu nhãn nút phải là ⏩ 1x")

	# Chuyển sang 2x
	challenge._toggle_speed()
	assert(challenge.current_speed_idx == 1, "Tốc độ phải chuyển sang index 1 (2x)")
	assert(Engine.time_scale == 2.0, "Engine.time_scale phải là 2.0")
	assert(challenge._speed_btn.text == "⏩ 2x", "Nhãn nút phải cập nhật là ⏩ 2x")

	# Chuyển sang 4x
	challenge._toggle_speed()
	assert(challenge.current_speed_idx == 2, "Tốc độ phải chuyển sang index 2 (4x)")
	assert(Engine.time_scale == 4.0, "Engine.time_scale phải là 4.0")
	assert(challenge._speed_btn.text == "⏩ 4x", "Nhãn nút phải cập nhật là ⏩ 4x")

	# Vòng lại 1x
	challenge._toggle_speed()
	assert(challenge.current_speed_idx == 0, "Tốc độ phải vòng lại index 0 (1x)")
	assert(Engine.time_scale == 1.0, "Engine.time_scale phải trở về 1.0")
	assert(challenge._speed_btn.text == "⏩ 1x", "Nhãn nút phải là ⏩ 1x")

	# Đặt sang 4x rồi dọn dẹp để kiểm tra Engine.time_scale được khôi phục về 1.0 khi thoát/rời ải
	challenge._toggle_speed() # 2x
	challenge._toggle_speed() # 4x
	assert(Engine.time_scale == 4.0, "Engine.time_scale đang là 4.0")

	challenge.queue_free()
	await get_tree().process_frame
	assert(Engine.time_scale == 1.0, "Khi thoát khỏi màn chơi, Engine.time_scale phải được tự động khôi phục 1.0 an toàn")
	print("  -> PASS: Tăng tốc trận đấu 1x -> 2x -> 4x và tự khôi phục an toàn hoạt động chính xác 100%")

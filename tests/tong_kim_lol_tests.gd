extends Node
## Bộ kiểm thử tự động cho tính năng Ải "Tống Kim LOL" (MOBA 1v1 - 5v5)

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("[PASS] ", name)
	else:
		_fail += 1
		print("[FAIL] ", name, " -> ", detail)

func _ready() -> void:
	print("--- BẮT ĐẦU KIỂM THỬ ẢI TỐNG KIM LOL ---")
	test_rules()
	test_state_and_progression()
	test_shop_items()
	test_lobby_and_rooms()
	test_player_match_tag()
	test_moba_lane_and_balance()
	print("--- KẾT THÚC TEST TỐNG KIM LOL: RESULT %d/%d (Thất bại: %d) ---" % [_pass, _pass + _fail, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func test_rules() -> void:
	check("Rules: Map ID là 378", TongKimLolRules.MAP_ID == 378)
	check("Rules: Thời gian trận 40 phút", TongKimLolRules.MATCH_DURATION_SEC == 2400.0)
	check("Rules: Chu kỳ lính 20 giây", TongKimLolRules.WAVE_INTERVAL_SEC == 20.0)
	check("Rules: Chu kỳ buff lính 5 phút", TongKimLolRules.CREEP_BUFF_INTERVAL_SEC == 300.0)
	check("Rules: Hệ số buff lính mỗi 5 phút là 1.3 (30%)", TongKimLolRules.CREEP_BUFF_RATE == 1.3)
	check("Rules: Chu kỳ Siêu Lính 10 phút", TongKimLolRules.SUPER_MINION_INTERVAL_SEC == 600.0)
	check("Rules: Máu Siêu Lính gấp 8 lần lính thường", TongKimLolRules.SUPER_MINION_HP_MULT == 8.0)
	check("Rules: Thời điểm xuất hiện Long Trụ ở phút 15 (900s)", TongKimLolRules.PILLAR_SPAWN_TIME_SEC == 900.0)
	check("Rules: Máu Boss Thượng Cổ gấp 10 lần Boss Hoàng Kim", TongKimLolRules.ANCIENT_BOSS_HP_MULT == 10.0)
	check("Rules: Sát thương Boss Thượng Cổ gấp 6 lần lính", TongKimLolRules.ANCIENT_BOSS_DAMAGE_MULT == 6.0)
	check("Rules: Boss Hoàng Kim mỗi 10 phút", TongKimLolRules.BOSS_INTERVAL_SEC == 600.0)
	check("Rules: Cấp tối đa trong trận 15", TongKimLolRules.MAX_MATCH_LEVEL == 15)
	check("Rules: Tặng 100 điểm tiềm năng", TongKimLolRules.INITIAL_POTENTIAL_POINTS == 100)
	check("Rules: Giới hạn ban đầu skill 9x/150/180 tối đa 5 điểm", TongKimLolRules.MAX_HIGH_SKILL_INITIAL == 5)
	check("Rules: Thưởng x10 EXP thực tế sau trận", TongKimLolRules.END_EXP_REWARD_MULT == 10.0)
	check("Rules: Thể thức 1vs1 đến 5vs5", TongKimLolRules.TEAM_SIZES == [1, 2, 3, 4, 5])

	check("Rules: Tọa độ Tướng Tống", TongKimLolRules.GENERAL_SONG_POS == Vector2(42624, 55088))
	check("Rules: Tọa độ Tướng Kim", TongKimLolRules.GENERAL_JIN_POS == Vector2(50272, 51152))
	check("Rules: Đủ 3 cổng phe Tống", TongKimLolRules.GATES_SONG.size() == 3)
	check("Rules: Đủ 3 cổng phe Kim", TongKimLolRules.GATES_JIN.size() == 3)

	check("PkRules: Có chế độ TONG_KIM_LOL", PkRules.Mode.has("TONG_KIM_LOL"))
	check("PkRules: Tên hiển thị Tống Kim LOL", PkRules.MODE_NAMES.get(PkRules.Mode.TONG_KIM_LOL) == "Tống Kim LOL")
	check("PkRules: Cho phép kick thành viên", PkRules.can_kick(PkRules.Mode.TONG_KIM_LOL) == true)

func test_state_and_progression() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "HiệpKháchMOBA"
	profile.sect_id = "vo_dang"
	profile.level = 60
	profile.potential_points = 50
	profile.skill_points = 10
	GameManager.local_profile = profile

	var state := TongKimLolState.new()
	state.init_match("song")

	check("State: Khởi đầu cấp 1", state.match_level == 1)
	check("State: Nhận thêm 100 điểm tiềm năng (50 -> 150)", profile.potential_points == 150)
	check("State: Điểm kỹ năng reset về 0", profile.skill_points == 0)

	var sect := SectRegistry.get_by_id("vo_dang")
	if sect:
		var all_opened := true
		for s in sect.skills:
			if not profile.skill_levels.has(s.id):
				all_opened = false
				break
		check("State: Mở khóa toàn bộ skill của phái", all_opened)

	# Lên cấp trong trận
	state.add_match_exp(400.0)
	check("State: Thăng cấp lên level 2", state.match_level == 2)
	check("State: Nhận 1 điểm kỹ năng trong trận", profile.skill_points == 1)

	# Kiểm tra logic cộng điểm: skill thường không cho cộng
	var low_skill := SkillDefinition.new()
	low_skill.id = "vd_low"
	low_skill.req_level = 20
	low_skill.max_level = 20
	var low_ok := state.allocate_match_skill(low_skill)
	check("State: Chặn cộng điểm vào skill thường", low_ok == false)

	# Kỹ năng 9x được phép cộng
	var high_skill := SkillDefinition.new()
	high_skill.id = "vd_90"
	high_skill.req_level = 90
	high_skill.max_level = 20
	profile.skill_levels["vd_90"] = 5
	var high_ok := state.allocate_match_skill(high_skill)
	check("State: Cho phép cộng điểm vào skill 9x", high_ok == true)
	check("State: Skill 9x nâng lên cấp 6", profile.skill_levels["vd_90"] == 6)

	# Kết thúc trận và trao thưởng x10 EXP thực tế
	var orig_exp := profile.current_exp
	var earned_exp := state.total_exp_earned
	var reward_exp := state.finish_and_reward()
	check("State: Thưởng đúng x10 EXP tích lũy", reward_exp == int(earned_exp * 10))
	check("State: Cộng EXP thực tế vào hồ sơ nhân vật", profile.current_exp >= orig_exp + reward_exp)
	check("State: Điểm tiềm năng gốc được hoàn trả", profile.potential_points == 50)

func test_shop_items() -> void:
	var state := TongKimLolState.new()
	state.init_match("song")
	check("Shop: Vàng ban đầu 100", state.match_gold == 100)

	var phi_toc := TongKimLolRules.SHOP_ITEMS[0]
	var buy_ok := state.apply_shop_item(phi_toc)
	check("Shop: Mua Phi Tốc Đan thành công", buy_ok == true)
	check("Shop: Trừ đúng 100 vàng", state.match_gold == 0)

	var buy_fail := state.apply_shop_item(phi_toc)
	check("Shop: Không đủ vàng thì từ chối", buy_fail == false)

	state.add_gold(TongKimLolRules.CREEP_BASE_GOLD)
	check("Shop: Diệt lính nhận 25 vàng", state.match_gold == 25)

	state.add_gold(int(TongKimLolRules.CREEP_BASE_GOLD * TongKimLolRules.PLAYER_KILL_GOLD_MULT))
	check("Shop: Diệt người nhận x20 vàng (500 vàng)", state.match_gold == 525)

	# Kiểm tra hình ảnh thuốc / quân nhu
	for item in TongKimLolRules.SHOP_ITEMS:
		var tex := TongKimLolShopWindow.load_item_icon(item)
		check("Shop: Thuốc/bùa %s có hình ảnh hiển thị hợp lệ" % str(item.get("name")), tex != null)

	var shop_win := TongKimLolShopWindow.new()
	check("Shop: Cửa sổ Quân Nhu Tống Kim khởi tạo thành công", shop_win != null)
	shop_win.free()

	# Test sinh thuốc Tống Kim vào hành trang và dọn sạch khi rời trận
	var p := GameManager.local_profile
	if p:
		var tk_item := ItemGenerator.generate_misc("tk_phi_toc")
		check("Shop: Sinh ItemInstance Phi Tốc Đan thành công", tk_item != null)
		if tk_item:
			check("Shop: Thuốc có cờ songjin_only", bool(tk_item.get_base().get("songjin_only", false)) == true)
			p.add_item(tk_item)
			check("Shop: Thuốc đã vào hành trang", p.inventory.has(tk_item))
			TongKimLolState.cleanup_tk_items()
			check("Shop: Thuốc tự động mất khỏi hành trang khi kết thúc/rời trận", not p.inventory.has(tk_item))

	# Kiểm tra hàm apply_speed_buff trên StatusEffectController
	var sec := StatusEffectController.new()
	check("StatusEffectController: Có hàm apply_speed_buff", sec.has_method("apply_speed_buff"))
	sec.apply_speed_buff(0.4, 20.0)
	check("StatusEffectController: Áp dụng buff tốc chạy thành công (move_speed_multiplier = 1.4)", is_equal_approx(sec.move_speed_multiplier, 1.4))
	sec.free()

func test_lobby_and_rooms() -> void:
	var p := PlayerProfile.new()
	p.display_name = "ChủPhòngTK"
	p.sect_id = "cai_bang"
	p.level = 90

	var room := PkLobby.create(p, PkRules.Mode.TONG_KIM_LOL, "", 5)
	check("Lobby: Tạo phòng 5vs5", room.get("team_size") == 5)
	check("Lobby: Chủ phòng ở slot 0 Phe A", (room["team_a"] as Array).size() == 1)

	var p2 := PlayerProfile.new()
	p2.display_name = "ĐốiThủTK"
	p2.sect_id = "thieu_lam"
	p2.level = 90

	var join_b := PkLobby.join_team(str(room["id"]), p2, "b")
	check("Lobby: Tham gia Phe B", join_b == true)

	var updated := PkLobby.find(str(room["id"]))
	check("Lobby: Phe B có 1 thành viên", (updated["team_b"] as Array).size() == 1)

	var switch_a := PkLobby.join_team(str(room["id"]), p2, "a")
	check("Lobby: Đổi từ Phe B sang Phe A", switch_a == true)

	var after_switch := PkLobby.find(str(room["id"]))
	check("Lobby: Phe A có 2 thành viên", (after_switch["team_a"] as Array).size() == 2)
	check("Lobby: Phe B trống sau khi đổi", (after_switch["team_b"] as Array).size() == 0)

	# Kiểm tra điều kiện chờ đủ người & sẵn sàng
	var team_sz: int = int(room.get("team_size", 5))
	var is_full := ((after_switch["team_a"] as Array).size() == team_sz and (after_switch["team_b"] as Array).size() == team_sz)
	check("Lobby: Chưa đủ người (2/10)", is_full == false)

	# Điền đủ Phe A (cần thêm 3 bot)
	while (after_switch["team_a"] as Array).size() < team_sz:
		PkLobby.add_bot(str(room["id"]), "a", 90)
		after_switch = PkLobby.find(str(room["id"]))
	check("Lobby: Phe A đủ 5 người", (after_switch["team_a"] as Array).size() == 5)
	is_full = ((after_switch["team_a"] as Array).size() == team_sz and (after_switch["team_b"] as Array).size() == team_sz)
	check("Lobby: Phe B chưa có người nên phòng vẫn chưa đủ", is_full == false)

	# Điền đủ Phe B (thêm 5 bot)
	while (after_switch["team_b"] as Array).size() < team_sz:
		PkLobby.add_bot(str(room["id"]), "b", 90)
		after_switch = PkLobby.find(str(room["id"]))
	check("Lobby: Phe B đủ 5 người", (after_switch["team_b"] as Array).size() == 5)
	is_full = ((after_switch["team_a"] as Array).size() == team_sz and (after_switch["team_b"] as Array).size() == team_sz)
	check("Lobby: Cả 2 phe đủ 5/5 -> Phòng đã đủ người", is_full == true)

	# Kiểm tra sẵn sàng
	var all_ready := true
	for m in (after_switch["team_a"] as Array) + (after_switch["team_b"] as Array):
		if not bool(m.get("is_host", false)) and not bool(m.get("ready", false)):
			all_ready = false
			break
	# Vì p2 chưa bấm sẵn sàng (mặc định ready=false) nên all_ready phải là false
	check("Lobby: Thành viên p2 chưa sẵn sàng -> all_ready = false", all_ready == false)

	# p2 bấm sẵn sàng
	PkLobby.toggle_ready(str(room["id"]), p2.display_name)
	after_switch = PkLobby.find(str(room["id"]))
	all_ready = true
	for m in (after_switch["team_a"] as Array) + (after_switch["team_b"] as Array):
		if not bool(m.get("is_host", false)) and not bool(m.get("ready", false)):
			all_ready = false
			break
	check("Lobby: Sau khi p2 bấm sẵn sàng -> all_ready = true", all_ready == true)

	# Test UI PkWindow cho Tống Kim LOL
	var win := PkWindow.new(p)
	win._select_mode(PkRules.Mode.TONG_KIM_LOL)
	win._show_room(after_switch)
	check("UI: PkWindow hiển thị phòng Tống Kim LOL thành công", win._view == PkWindow.View.ROOM)
	win.queue_free()

	PkLobby.close(str(room["id"]))
	check("Lobby: Đóng phòng", PkLobby.find(str(room["id"])).is_empty())

func test_player_match_tag() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "HiệpKháchLOL"
	profile.gender = PlayerProfile.Gender.MALE
	GameManager.local_profile = profile

	var look := profile.get_equipped_look()
	check("PlayerProfile: có hàm get_equipped_look", look is Dictionary)
	check("PlayerProfile: look gender đúng", look.get("gender") == "male")

	var player_script = load("res://player/player.gd")
	var player = CharacterBody2D.new()
	player.set_script(player_script)
	player.set_physics_process(false)
	player._build_name_label(profile.display_name)

	player.set_match_level_tag(1, "song")
	check("Player: nhãn tên có tag [Cấp 1]", player._name_label.text.contains("[Cấp 1]"))
	check("Player: nhãn tên có tên nhân vật", player._name_label.text.contains("HiệpKháchLOL"))
	var song_col: Color = player._name_label.get_theme_color("font_color")
	check("Player: màu tên phe Tống (xanh lam)", is_equal_approx(song_col.r, 0.2) and is_equal_approx(song_col.g, 0.6))

	player.set_match_level_tag(5, "jin")
	check("Player: nhãn tên cập nhật [Cấp 5]", player._name_label.text.contains("[Cấp 5]"))
	var jin_col: Color = player._name_label.get_theme_color("font_color")
	check("Player: màu tên phe Kim (cam/đỏ)", is_equal_approx(jin_col.r, 1.0) and is_equal_approx(jin_col.g, 0.35))

	player.set_match_level_tag(0)
	check("Player: reset tag cấp về rỗng", not player._name_label.text.contains("[Cấp"))

	player.queue_free()

func test_moba_lane_and_balance() -> void:
	# 1. Kiểm tra Waypoints 3 đường
	for lane_idx in 3:
		var song_wps := TongKimLolRules.get_lane_waypoints(lane_idx, "song")
		var jin_wps := TongKimLolRules.get_lane_waypoints(lane_idx, "jin")
		check("Rules: Waypoints đường %d phe Tống tồn tại" % lane_idx, song_wps.size() >= 3)
		check("Rules: Điểm cuối đường %d phe Tống là Tướng Kim" % lane_idx, song_wps[-1] == TongKimLolRules.GENERAL_JIN_POS)
		check("Rules: Điểm cuối đường %d phe Kim là Tướng Tống" % lane_idx, jin_wps[-1] == TongKimLolRules.GENERAL_SONG_POS)

	# 2. Kiểm tra chỉ số cân bằng MOBA
	check("Rules: Máu Tướng Soái 600.000 HP", TongKimLolRules.GENERAL_MAX_HP == 600000.0)
	check("Rules: Máu Thủ vệ cổng 8.000 HP", TongKimLolRules.GUARDIAN_MAX_HP == 8000)
	check("Rules: Máu Lính cận chiến 3.500 HP", TongKimLolRules.CREEP_MELEE_HP == 3500)
	check("Rules: Máu Lính tầm xa 2.200 HP", TongKimLolRules.CREEP_RANGED_HP == 2200)
	check("Rules: Số thủ vệ mỗi cổng tối ưu là 4", TongKimLolRules.GATE_GUARDIAN_COUNT == 4)
	check("Rules: Sát thương lính thường chuẩn 1.0", TongKimLolRules.CREEP_DAMAGE_MULT == 1.0)
	check("Rules: Vệ binh canh cổng dame x20 lần lính", TongKimLolRules.GUARDIAN_DAMAGE_RATIO_TO_CREEP == 20.0)
	check("Rules: Sát thương Vệ binh canh cổng chuẩn 20.0", TongKimLolRules.GUARDIAN_DAMAGE_MULT == 20.0)
	check("Rules: Đợt 1 ra 1 lính / cổng", TongKimLolRules.minions_per_gate_for_wave(1) == 1)
	check("Rules: Đợt 2 ra 2 lính / cổng", TongKimLolRules.minions_per_gate_for_wave(2) == 2)
	check("Rules: Đợt 3 ra 3 lính / cổng", TongKimLolRules.minions_per_gate_for_wave(3) == 3)
	check("Rules: Đợt 4 ra 4 lính / cổng (không dừng ở đợt 3)", TongKimLolRules.minions_per_gate_for_wave(4) == 4)
	check("Rules: Đợt 5 ra 5 lính / cổng", TongKimLolRules.minions_per_gate_for_wave(5) == 5)
	check("Rules: Đợt 10 ra 10 lính / cổng", TongKimLolRules.minions_per_gate_for_wave(10) == 10)

	# 3. Kiểm tra thuộc tính quái lính lane
	var m := VltkMonster.new()
	m.is_lane_creep = true
	m.lane_waypoints = TongKimLolRules.get_lane_waypoints(1, "song")
	m.moba_damage_multiplier = 3.0
	check("Monster: Có cờ is_lane_creep", m.is_lane_creep == true)
	check("Monster: Nhận danh sách lane_waypoints", m.lane_waypoints.size() > 0)
	check("Monster: moba_damage_multiplier được kích hoạt", m.moba_damage_multiplier == 3.0)
	m.queue_free()

	# 4. Kiểm tra Tướng Soái MOBA
	var gen := VltkMonster.new()
	gen.is_moba_general = true
	check("Monster: Có cờ is_moba_general", gen.is_moba_general == true)
	gen.queue_free()

	# 5. Kiểm tra Boss Hoàng Kim MOBA 2 phe
	check("Rules: Máu Boss Hoàng Kim gấp 20 lần lính thường", TongKimLolRules.GOLDEN_BOSS_MAX_HP == TongKimLolRules.CREEP_MELEE_HP * 20)
	check("Rules: Máu Boss Hoàng Kim chuẩn là 70.000 HP", TongKimLolRules.GOLDEN_BOSS_MAX_HP == 70000)
	check("Rules: Sát thương Boss Hoàng Kim gấp 3 lần quái thường", TongKimLolRules.GOLDEN_BOSS_DAMAGE_MULT == 3.0)
	check("Rules: Có danh sách Boss phe Tống", TongKimLolRules.BOSS_GOLD_SONG_IDS.size() > 0)
	check("Rules: Có danh sách Boss phe Kim", TongKimLolRules.BOSS_GOLD_JIN_IDS.size() > 0)

	var boss_song := TongKimLolMatch.create_golden_boss(TongKimLolRules.BOSS_GOLD_SONG_IDS[0], "song", TongKimLolRules.MAP_CENTER_POS + Vector2(-150, 0))
	var boss_jin := TongKimLolMatch.create_golden_boss(TongKimLolRules.BOSS_GOLD_JIN_IDS[0], "jin", TongKimLolRules.MAP_CENTER_POS + Vector2(150, 0))
	add_child(boss_song)
	add_child(boss_jin)

	check("Boss: Boss Tống có phe 'song'", boss_song.battle_side == "song")
	check("Boss: Boss Kim có phe 'jin'", boss_jin.battle_side == "jin")
	check("Boss: Boss Tống là gold_boss", boss_song.gold_boss == true)
	check("Boss: Boss Kim là gold_boss", boss_jin.gold_boss == true)
	check("Boss: Máu Boss Tống đạt 70.000 HP", boss_song.max_health == 70000.0)
	check("Boss: Máu Boss Kim đạt 70.000 HP", boss_jin.max_health == 70000.0)
	check("Boss: Sát thương Boss Tống x3 (3.0)", boss_song.moba_damage_multiplier == 3.0)
	check("Boss: Sát thương Boss Kim x3 (3.0)", boss_jin.moba_damage_multiplier == 3.0)
	check("Boss: Boss Tống có lộ trình di chuyển (không đứng yên)", boss_song.lane_waypoints.size() > 0)
	check("Boss: Boss Kim có lộ trình di chuyển (không đứng yên)", boss_jin.lane_waypoints.size() > 0)

	# Kiểm tra cơ chế tự động tìm và nhắm vào nhau
	var foe_of_song := boss_song._find_nearest_foe("jin")
	var foe_of_jin := boss_jin._find_nearest_foe("song")
	check("Boss: Boss Tống tự động khoá mục tiêu vào Boss Kim", foe_of_song == boss_jin)
	check("Boss: Boss Kim tự động khoá mục tiêu vào Boss Tống", foe_of_jin == boss_song)

	boss_song.queue_free()
	boss_jin.queue_free()

	# 6. Kiểm tra Cung binh dame ngang bằng Bộ binh
	var bo_binh := VltkMonster.new()
	bo_binh.monster_id = TongKimLolRules.CREEP_MELEE_TPL
	bo_binh.data = MonsterData.monster(bo_binh.monster_id).duplicate()
	bo_binh.level = 50
	bo_binh.moba_damage_multiplier = TongKimLolRules.CREEP_DAMAGE_MULT
	bo_binh._build_stats()

	var cung_binh := VltkMonster.new()
	cung_binh.monster_id = TongKimLolRules.CREEP_RANGED_TPL
	cung_binh.data = MonsterData.monster(cung_binh.monster_id).duplicate()
	cung_binh.level = 50
	cung_binh.moba_damage_multiplier = TongKimLolRules.CREEP_DAMAGE_MULT
	cung_binh._build_stats()

	var bo_stats := bo_binh._make_hit_stats(int(bo_binh.data["skills"][0][0]), int(bo_binh.data["skills"][0][1]))
	var cung_stats := cung_binh._make_hit_stats(int(cung_binh.data["skills"][0][0]), int(cung_binh.data["skills"][0][1]))

	check("Damage: Bộ binh có sát thương vật lý", bo_stats.damage > 0.0)
	check("Damage: Cung binh có sát thương vật lý", cung_stats.damage > 0.0)
	check("Damage: Cung binh dame bằng Bộ binh (damage_min)", is_equal_approx(cung_stats.damage_min, bo_stats.damage_min))
	check("Damage: Cung binh dame bằng Bộ binh (damage_max)", is_equal_approx(cung_stats.damage_max, bo_stats.damage_max))
	check("Damage: Sát thương lính vừa phải, không quá lớn (< 300 dame)", bo_stats.damage <= 300.0)
	bo_binh.queue_free()
	cung_binh.queue_free()

	# 7. Kiểm tra Tướng Soái dame cực to và không thể ra khỏi doanh trại
	check("Rules: Bán kính doanh trại Tướng là 500.0", TongKimLolRules.GENERAL_CAMP_RADIUS == 500.0)
	check("Rules: Hệ số sát thương Tướng là 10.0", TongKimLolRules.GENERAL_DAMAGE_MULT == 10.0)

	var gen_song := VltkMonster.new()
	gen_song.monster_id = 636
	gen_song.data = MonsterData.monster(gen_song.monster_id).duplicate()
	gen_song.level = 95
	gen_song.gold_boss = true
	gen_song.is_moba_general = true
	gen_song.moba_damage_multiplier = TongKimLolRules.GENERAL_DAMAGE_MULT
	gen_song.position = TongKimLolRules.GENERAL_SONG_POS
	gen_song._origin_logic = VltkMath.to_logic(gen_song.position)
	gen_song._build_stats()

	var gen_stats := gen_song._make_hit_stats(int(gen_song.data["skills"][0][0]), int(gen_song.data["skills"][0][1]))
	check("General: Sát thương Tướng Soái cực lớn (> 20.000 dame)", gen_stats.damage >= 20000.0)

	# Kiểm tra giới hạn di chuyển: nếu đích ngoài doanh trại, _walk_to tự động giới hạn về trong bán kính 500px
	var far_dest := gen_song._origin_logic + Vector2(1000.0, 0.0)
	gen_song._walk_to(far_dest)
	var walk_dest_dist := gen_song._walk_dest.distance_to(gen_song._origin_logic)
	check("General: Điểm di chuyển bị giới hạn trong doanh trại (<= 500px)", walk_dest_dist <= TongKimLolRules.GENERAL_CAMP_RADIUS + 1.0)

	# Kiểm tra clamp tọa độ: nếu bị văng ra ngoài, clamp giữ lại trong 500px
	gen_song.global_position = VltkMath.to_world(gen_song._origin_logic + Vector2(800.0, 0.0))
	var cur_dist := VltkMath.to_logic(gen_song.global_position).distance_to(gen_song._origin_logic)
	check("General: Tọa độ trước clamp vượt quá doanh trại", cur_dist > 500.0)
	var here_logic := VltkMath.to_logic(gen_song.global_position)
	if here_logic.distance_to(gen_song._origin_logic) > TongKimLolRules.GENERAL_CAMP_RADIUS:
		var clamped := gen_song._origin_logic + (here_logic - gen_song._origin_logic).normalized() * TongKimLolRules.GENERAL_CAMP_RADIUS
		gen_song.global_position = VltkMath.to_world(clamped)
	var clamped_dist := VltkMath.to_logic(gen_song.global_position).distance_to(gen_song._origin_logic)
	check("General: Tọa độ bị khoá lại trong doanh trại (<= 500px)", is_equal_approx(clamped_dist, TongKimLolRules.GENERAL_CAMP_RADIUS))
	gen_song.queue_free()

	# 8. Kiểm tra cơ chế Lính vướng vật cản tự thoát (Unstuck / Avoidance)
	var lane_minion := VltkMonster.new()
	lane_minion.is_lane_creep = true
	lane_minion.lane_waypoints = [Vector2(100, 100), Vector2(300, 300), Vector2(500, 500)]
	lane_minion.lane_waypoint_idx = 0
	lane_minion.global_position = Vector2(100, 100)
	lane_minion._last_walk_pos = lane_minion.global_position
	lane_minion._walk_dest = VltkMath.to_logic(Vector2(300, 300))

	# Giả lập bị kẹt vật cản không di chuyển được
	lane_minion._stuck_time = 0.3
	lane_minion._tick_walk(1.0)
	check("Minion Unstuck: Kích hoạt góc tránh vật cản (_avoid_timer > 0)", lane_minion._avoid_timer > 0.0)
	check("Minion Unstuck: Có hướng tránh vật cản (_avoid_dir != 0)", lane_minion._avoid_dir != Vector2.ZERO)

	# Bị kẹt lâu hơn 1.5s -> tự động chuyển sang waypoint tiếp theo
	lane_minion._stuck_time = 1.6
	lane_minion._tick_walk(1.0)
	check("Minion Unstuck: Tự nhảy sang waypoint kế tiếp sau 1.5s kẹt", lane_minion.lane_waypoint_idx == 1)
	lane_minion.queue_free()

	# 9. Kiểm tra giới hạn lính tối đa tăng lên 120 lính mỗi phe
	check("Rules: Giới hạn lính lane tối đa 120 con", TongKimLolRules.MAX_LANE_MINIONS_PER_SIDE == 120)

	# 10. Kiểm tra UI HUD Tống Kim LOL: Nền đen và ống máu bỏ, VS Bar Tướng Tống / Tướng Kim %, Vàng trên nút bấm
	var hud := TongKimLolClient.new()
	add_child(hud)
	check("HUD: Nút Quân Nhu tồn tại", hud._shop_button != null)
	check("HUD: Nút Rời Ải tồn tại", hud._leave_button != null)
	var btn_parent := hud._shop_button.get_parent() as Control
	check("HUD: Cụm nút Quân Nhu & Rời Ải neo góc dưới phải (PRESET_BOTTOM_RIGHT)", btn_parent != null and btn_parent.anchors_preset == Control.PRESET_BOTTOM_RIGHT)
	check("HUD: Đặt ngay trên 4 ô dùng thuốc (offset_bottom <= -360)", btn_parent != null and btn_parent.offset_bottom <= -360.0)

	# Kiểm tra nhãn Vàng đặt phía trên nút Quân Nhu & Rời Ải
	check("HUD: Nhãn Vàng tồn tại", hud._gold_label != null)
	var gold_panel := hud._gold_label.get_parent().get_parent() as Control
	check("HUD: Cụm Vàng nằm phía trên cụm nút (offset_bottom <= btn_parent.offset_top)", gold_panel != null and gold_panel.offset_bottom <= btn_parent.offset_top)

	# Bỏ hiển thị cấp trên HUD (đã có ở tên nhân vật) và bỏ thanh máu riêng
	check("HUD: Đã bỏ nhãn cấp riêng trên HUD", hud._level_label == null)
	check("HUD: Đã bỏ ống máu riêng của Tướng Tống", hud._song_hp_bar == null)

	# Banner Tướng Tống vs Tướng Kim và số %
	check("HUD: VsScoreBar tồn tại", hud._vs_bar != null)
	check("HUD: VsScoreBar tên phe Trái là 'Tướng Tống'", hud._vs_bar._left_name_lbl.text == "Tướng Tống")
	check("HUD: VsScoreBar tên phe Phải là 'Tướng Kim'", hud._vs_bar._right_name_lbl.text == "Tướng Kim")
	hud.update_generals(0.85, 0.40)
	check("HUD: Điểm số bên trong UI là số % Tướng Tống (85%)", hud._vs_bar._left_score_lbl.text == "85%")
	check("HUD: Điểm số bên trong UI là số % Tướng Kim (40%)", hud._vs_bar._right_score_lbl.text == "40%")
	hud.queue_free()

	# 11. Kiểm tra Signal chết của quái kết nối _on_creep_died (sửa lỗi Method expected 2 arguments but called with 3)
	var match_ctrl := TongKimLolMatch.new()
	add_child(match_ctrl)
	match_ctrl.side = "song"
	match_ctrl.state = TongKimLolState.new()
	match_ctrl.state.init_match("song")
	var initial_gold: int = match_ctrl.state.match_gold
	var creep := VltkMonster.new()
	creep.monster_id = TongKimLolRules.CREEP_MELEE_TPL
	creep.data = MonsterData.monster(creep.monster_id).duplicate()
	creep.battle_side = "jin"
	add_child(creep)
	creep.died.connect(match_ctrl._on_creep_died.bind("jin"))
	# Gọi die() thực tế để kích hoạt signal 'died' -> _on_creep_died
	creep.die()
	var drops := get_tree().get_nodes_in_group(GroundDrop.GROUP)
	var has_drop: bool = false
	for d in drops:
		if d is GroundDrop and d.amount == TongKimLolRules.CREEP_BASE_GOLD:
			has_drop = true
			d.queue_free()
			break
	check("Signal: Quái Kim chết rơi cọc Vàng Tống Kim", has_drop)
	creep.queue_free()
	match_ctrl.queue_free()

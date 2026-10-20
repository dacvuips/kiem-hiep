extends Node

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func _ready() -> void:
	print("--- BẮT ĐẦU TEST PK THÁCH ĐẤU & XẾP HẠNG ---")
	test_rules()
	test_profile_and_points()
	test_team_formats_and_slots()
	test_lobby_teams()
	test_pk_window_ui()
	test_pk_match_reject()
	test_pk_match_team()
	test_ranking_window()
	print("--- KẾT THÚC TEST: RESULT %d/%d (Thất bại: %d) ---" % [_pass, _pass + _fail, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func test_rules() -> void:
	check("rules: có enum Mode.THACH_DAU", PkRules.Mode.has("THACH_DAU"))
	check("rules: tên hiển thị Thách đấu", PkRules.MODE_NAMES.get(PkRules.Mode.THACH_DAU) == "Thách đấu")
	check("rules: can_kick Thách đấu là true", PkRules.can_kick(PkRules.Mode.THACH_DAU) == true)
	check("rules: can_kick Đại hội là false", PkRules.can_kick(PkRules.Mode.DAI_HOI) == false)
	check("rules: can_kick Liên đấu là false", PkRules.can_kick(PkRules.Mode.LIEN_DAU) == false)
	check("rules: has_rank_points Đại hội là true", PkRules.has_rank_points(PkRules.Mode.DAI_HOI) == true)
	check("rules: has_rank_points Liên đấu là true", PkRules.has_rank_points(PkRules.Mode.LIEN_DAU) == true)
	check("rules: has_rank_points Thách đấu là false", PkRules.has_rank_points(PkRules.Mode.THACH_DAU) == false)

	var p := PlayerProfile.new()
	p.display_name = "KiemKhach"
	p.level = 10
	check("rules: cấp 10 vào Thách đấu được", PkRules.check_entry(p, PkRules.Mode.THACH_DAU) == "")
	p.level = 5
	check("rules: cấp 5 vào Thách đấu bị từ chối", PkRules.check_entry(p, PkRules.Mode.THACH_DAU) != "")

	check("rules: Thách đấu cho phép ghép tự do", PkRules.can_match(PkRules.Mode.THACH_DAU, 10, "hoa_son", 90, "cai_bang") == true)
	check("rules: Đại hội khác phái không ghép được", PkRules.can_match(PkRules.Mode.DAI_HOI, 90, "hoa_son", 90, "cai_bang") == false)

func test_profile_and_points() -> void:
	var p := PlayerProfile.new()
	p.display_name = "NguoiChoi"
	p.pk_points = 50
	var d := p.to_dict()
	check("profile: to_dict lưu pk_points", int(d.get("pk_points", -1)) == 50)
	var loaded := PlayerProfile.from_dict(d)
	check("profile: from_dict nạp lại pk_points", loaded.pk_points == 50)

	GameManager.local_profile = p
	# Test win/lose points in DAI_HOI & LIEN_DAU
	p.pk_points = 20
	var d_win := PkMatch.record_result(PkRules.Mode.DAI_HOI, true)
	check("points: thắng Đại hội cộng 10 điểm", d_win == 10 and p.pk_points == 30)
	var d_lose := PkMatch.record_result(PkRules.Mode.DAI_HOI, false)
	check("points: thua Đại hội trừ 2 điểm", d_lose == -2 and p.pk_points == 28)

	# Test win in LIEN_DAU
	d_win = PkMatch.record_result(PkRules.Mode.LIEN_DAU, true)
	check("points: thắng Liên đấu cộng 10 điểm", d_win == 10 and p.pk_points == 38)

	# Test point floor at 0
	p.pk_points = 1
	d_lose = PkMatch.record_result(PkRules.Mode.LIEN_DAU, false)
	check("points: không bị âm dưới 0", p.pk_points == 0)

	# Test THACH_DAU does not alter rank points
	p.pk_points = 100
	var d_thach_win := PkMatch.record_result(PkRules.Mode.THACH_DAU, true)
	check("points: Thách đấu thắng không đổi điểm", d_thach_win == 0 and p.pk_points == 100)
	var d_thach_lose := PkMatch.record_result(PkRules.Mode.THACH_DAU, false)
	check("points: Thách đấu thua không đổi điểm", d_thach_lose == 0 and p.pk_points == 100)

func test_pk_window_ui() -> void:
	var p := PlayerProfile.new()
	p.display_name = "Tester"
	p.level = 95
	p.sect_id = "hoa_son"
	var win := PkWindow.new(p)
	add_child(win)

	var tabs_found: Array[String] = []
	for b in win.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.text in ["Đại hội võ lâm", "Võ lâm Liên đấu", "Thách đấu"]:
			tabs_found.append(btn.text)
	check("ui: PkWindow có đủ 3 nút tab", tabs_found.has("Đại hội võ lâm") and tabs_found.has("Võ lâm Liên đấu") and tabs_found.has("Thách đấu"))

	# Test switching to THACH_DAU
	win._select_mode(PkRules.Mode.THACH_DAU)
	check("ui: chọn tab Thách đấu thành công", win._mode == PkRules.Mode.THACH_DAU)

	win.queue_free()

func test_pk_match_reject() -> void:
	# Test match in LIEN_DAU (no reject button)
	GameManager.field_map = {"pk": {"mode": PkRules.Mode.LIEN_DAU}}
	var m_lien_dau := PkMatch.new()
	add_child(m_lien_dau)
	check("pk_match: Liên đấu không có nút từ chối đối thủ", m_lien_dau._reject_button == null)
	m_lien_dau.queue_free()

	# Test match in THACH_DAU (has reject button)
	GameManager.field_map = {"pk": {"mode": PkRules.Mode.THACH_DAU}}
	var m_thach_dau := PkMatch.new()
	add_child(m_thach_dau)
	check("pk_match: Thách đấu có nút từ chối đối thủ", m_thach_dau._reject_button != null)
	check("pk_match: trước khi từ chối running=false, done=false", not m_thach_dau.running and not m_thach_dau.done)

	# Simulate pressing reject button
	m_thach_dau._on_reject_opponent()
	check("pk_match: sau khi từ chối done=true, running=false", m_thach_dau.done and not m_thach_dau.running)
	check("pk_match: trận đấu không bắt đầu và hẹn giờ rời sàn", m_thach_dau._leave_in > 0.0)
	check("pk_match: nút từ chối ẩn đi", m_thach_dau._reject_button.visible == false)

	m_thach_dau.queue_free()
	GameManager.field_map = {}

func test_team_formats_and_slots() -> void:
	check("formats: đủ 8 thể thức 1..8", PkRules.TEAM_FORMATS.size() == 8)
	check("formats: tên thể thức 1vs1", PkRules.format_name(1) == "1vs1")
	check("formats: tên thể thức 3vs3", PkRules.format_name(3) == "3vs3")
	check("formats: tên thể thức 8vs8", PkRules.format_name(8) == "8vs8")

	var slots_1 := PkRules.get_spawn_slots(Vector2(1000, 1000), 1)
	check("slots: 1vs1 có 1 slot mỗi bên", (slots_1["team_a"] as Array).size() == 1 and (slots_1["team_b"] as Array).size() == 1)

	var slots_8 := PkRules.get_spawn_slots(Vector2(1000, 1000), 8)
	check("slots: 8vs8 có 8 slot mỗi bên", (slots_8["team_a"] as Array).size() == 8 and (slots_8["team_b"] as Array).size() == 8)
	var sa: Array = slots_8["team_a"]
	var sb: Array = slots_8["team_b"]
	check("slots: Đội A ở bên trái x < 1000", sa[0].x < 1000.0)
	check("slots: Đội B ở bên phải x > 1000", sb[0].x > 1000.0)

func test_lobby_teams() -> void:
	var p1 := PlayerProfile.new()
	p1.display_name = "HostP1"
	p1.level = 90
	var room := PkLobby.create(p1, PkRules.Mode.THACH_DAU, "", 3)
	check("lobby: tạo phòng 3vs3 có team_size=3", int(room.get("team_size", 0)) == 3)
	check("lobby: host tự động ở team_a", (room.get("team_a", []) as Array).size() == 1)

	var p2 := PlayerProfile.new()
	p2.display_name = "MemberP2"
	p2.level = 90
	var ok_join := PkLobby.join_team(str(room["id"]), p2, "b")
	check("lobby: người chơi 2 vào team_b thành công", ok_join and (room.get("team_b", []) as Array).size() == 1)

	# Test thêm bot
	var ok_bot := PkLobby.add_bot(str(room["id"]), "b", 90)
	check("lobby: thêm bot vào team_b thành công", ok_bot and (room.get("team_b", []) as Array).size() == 2)

	# Test đá người
	var ok_kick := PkLobby.kick_member(str(room["id"]), "MemberP2")
	check("lobby: đá thành viên P2 thành công", ok_kick and (room.get("team_b", []) as Array).size() == 1)

	PkLobby.close(str(room["id"]))

func test_pk_match_team() -> void:
	# Test team match 3vs3 offline
	var p := PlayerProfile.new()
	p.display_name = "TeamCaptain"
	p.level = 95
	p.sect_id = "hoa_son"
	GameManager.local_profile = p
	GameManager.field_map = {"pk": {"mode": PkRules.Mode.THACH_DAU, "team_size": 3}}
	var m := PkMatch.new()
	add_child(m)

	check("pk_match_team: team_size gán đúng 3", m.team_size == 3)
	# _spawn_bot runs deferred, but we can verify structure
	m.queue_free()
	GameManager.field_map = {}

func test_ranking_window() -> void:
	var p := PlayerProfile.new()
	p.display_name = "CaoThuVLTK"
	p.level = 99
	p.sect_id = "cai_bang"
	p.pk_points = 180

	var rw := RankingWindow.new(p)
	add_child(rw)
	check("ranking: có đủ 4 tab", RankingWindow.TABS.size() == 4 and RankingWindow.TABS.has("Võ Lâm PK"))

	# Switch to tab Võ Lâm PK (index 2)
	rw._select_tab(2)
	check("ranking: chuyển sang tab Võ Lâm PK thành công", rw._tab == 2)

	# Ensure board child is created
	var boards := rw._content.get_children()
	check("ranking: tab Võ Lâm PK có hiển thị bảng xếp hạng", not boards.is_empty())

	rw.queue_free()

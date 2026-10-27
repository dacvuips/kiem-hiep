extends Node

const PkStakeSession = preload("res://systems/pk/pk_stake_session.gd")
const PkStakeWindow = preload("res://ui/pk/pk_stake_window.gd")

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
	test_thach_dau_side_colors()
	test_ranking_window()
	test_stake_system()
	test_stake_window_ui()
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
	check("rules: Liên đấu chênh lệch cấp vẫn ghép được", PkRules.can_match(PkRules.Mode.LIEN_DAU, 10, "hoa_son", 90, "cai_bang") == true)
	check("rules: Đại hội cùng phái chênh lệch cấp vẫn ghép được", PkRules.can_match(PkRules.Mode.DAI_HOI, 10, "hoa_son", 90, "hoa_son") == true)
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

	var modes_found: Array[String] = []
	if win._mode_filter_btn != null:
		for i in win._mode_filter_btn.item_count:
			modes_found.append(win._mode_filter_btn.get_item_text(i))
	for b in win.find_children("*", "Button", true, false):
		var btn := b as Button
		modes_found.append(btn.text)
	var has_dh := modes_found.any(func(s: String) -> bool: return s.to_lower().contains("đại hội"))
	var has_ld := modes_found.any(func(s: String) -> bool: return s.to_lower().contains("liên đấu"))
	var has_td := modes_found.any(func(s: String) -> bool: return s.to_lower().contains("thách đấu"))
	check("ui: PkWindow có đủ các chế độ PK", has_dh and has_ld and has_td)

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

func test_thach_dau_side_colors() -> void:
	print("--- TEST MÀU SẮC 2 PHE THÁCH ĐẤU ---")
	# 1. Test Player overhead color & prefix
	var prof := PlayerProfile.new()
	prof.display_name = "HiepKhachXanh"
	prof.level = 80
	GameManager.local_profile = prof

	var player_script = load("res://player/player.gd")
	var p = CharacterBody2D.new()
	p.set_script(player_script)
	p.set_physics_process(false)
	p._build_name_label(prof.display_name)

	# Phe Xanh
	p.set_name_color(Color(0.25, 0.70, 1.0), "[Phe Xanh]")
	check("player: tiền tố [Phe Xanh] hiển thị trên đầu", p._name_label.text.contains("[Phe Xanh]"))
	var col_blue: Color = p._name_label.get_theme_color("font_color")
	check("player: màu tên Phe Xanh (xanh dương)", is_equal_approx(col_blue.r, 0.25) and is_equal_approx(col_blue.b, 1.0))

	# Phe Đỏ
	p.set_name_color(Color(1.0, 0.35, 0.35), "[Phe Đỏ]")
	check("player: tiền tố [Phe Đỏ] hiển thị trên đầu", p._name_label.text.contains("[Phe Đỏ]"))
	var col_red: Color = p._name_label.get_theme_color("font_color")
	check("player: màu tên Phe Đỏ (đỏ)", is_equal_approx(col_red.r, 1.0) and is_equal_approx(col_red.g, 0.35))

	p.reset_name_color()
	check("player: reset_name_color xóa bỏ tiền tố", not p._name_label.text.contains("[Phe"))
	p.queue_free()

	# 2. Test RemotePlayer overhead color & prefix
	var rp := RemotePlayer.new()
	rp.setup({"eid": 999, "name": "DoiThuDo", "level": 80, "camp": 0, "pos": Vector2.ZERO, "look": {}, "flags": 0, "dir": 0, "action": "stand", "z": 0.0})
	rp.set_name_color(Color(1.0, 0.35, 0.35), "[Phe Đỏ]")
	check("remote_player: có hàm set_name_color và tiền tố [Phe Đỏ]", rp._label != null and rp._label.text.contains("[Phe Đỏ]"))
	rp.queue_free()

	# 3. Test Room UI colors in PkWindow
	var win := PkWindow.new(prof)
	add_child(win)
	win._select_mode(PkRules.Mode.THACH_DAU)
	var room := PkLobby.create(prof, PkRules.Mode.THACH_DAU, "", 2)
	win._show_room(room)

	# Tìm các panel 2 phe trong phòng
	var labels := win.find_children("*", "Label", true, false)
	var has_blue_header := false
	var has_red_header := false
	for l in labels:
		var lbl := l as Label
		if lbl.text.contains("Phe Xanh Dương"):
			has_blue_header = true
			var c: Color = lbl.get_theme_color("font_color")
			check("ui_room: tiêu đề Phe Xanh Dương có màu xanh", is_equal_approx(c.r, 0.25) and is_equal_approx(c.b, 1.0))
		elif lbl.text.contains("Phe Đỏ ("):
			has_red_header = true
			var c: Color = lbl.get_theme_color("font_color")
			check("ui_room: tiêu đề Phe Đỏ có màu đỏ", is_equal_approx(c.r, 1.0) and is_equal_approx(c.g, 0.40))
	check("ui_room: có tiêu đề Phe Xanh Dương", has_blue_header)
	check("ui_room: có tiêu đề Phe Đỏ", has_red_header)
	PkLobby.close(str(room["id"]))
	win.queue_free()

	# 4. Test PkMatch HUD & VsScoreBar colors for Thách Đấu
	GameManager.field_map = {"pk": {"mode": PkRules.Mode.THACH_DAU, "team_size": 2}}
	var m := PkMatch.new()
	add_child(m)
	check("pk_match: VsScoreBar bên trái là Phe Xanh", m._vs_bar._left_name_lbl.text == "Phe Xanh")
	check("pk_match: VsScoreBar bên phải là Phe Đỏ", m._vs_bar._right_name_lbl.text == "Phe Đỏ")
	var l_col: Color = m._vs_bar._left_name_lbl.get_theme_color("font_color")
	var r_col: Color = m._vs_bar._right_name_lbl.get_theme_color("font_color")
	check("pk_match: màu tên Phe Xanh là xanh dương", is_equal_approx(l_col.r, 0.25) and is_equal_approx(l_col.b, 1.0))
	check("pk_match: màu tên Phe Đỏ là đỏ", is_equal_approx(r_col.r, 1.0) and is_equal_approx(r_col.g, 0.35))
	m.queue_free()
	GameManager.field_map = {}

func test_stake_system() -> void:
	print("--- TEST HỆ THỐNG ĐẶT CƯỢC THÁCH ĐẤU ---")
	var p_a := PlayerProfile.new()
	p_a.display_name = "DaiHiepA"
	p_a.gold = 500000
	p_a.xu = 200
	p_a.jade = 50

	var test_item := ItemGenerator.generate_misc("6_1_1877")
	if test_item != null:
		p_a.add_item(test_item)

	var p_b := PlayerProfile.new()
	p_b.display_name = "DaiHiepB"
	p_b.gold = 300000
	p_b.xu = 150
	p_b.jade = 30

	var session := PkStakeSession.new()
	session.side_a.leader_name = p_a.display_name
	session.side_b.leader_name = p_b.display_name

	# Test đặt tiền, xu, knb phe A
	var err_gold := session.set_gold("a", 100000, p_a)
	check("stake: đặt tiền lượng A thành công", err_gold == "" and session.side_a.gold == 100000)
	var err_xu := session.set_xu("a", 50, p_a)
	check("stake: đặt xu A thành công", err_xu == "" and session.side_a.xu == 50)
	var err_jade := session.set_jade("a", 15, p_a)
	check("stake: đặt KNB A thành công", err_jade == "" and session.side_a.jade == 15)

	# Test đặt vật phẩm phe A
	if test_item != null:
		var has_before := p_a.inventory.has(test_item)
		var err_item := session.offer_item("a", test_item, p_a)
		check("stake: đặt vật phẩm A thành công", err_item == "")
		check("stake: vật phẩm bị gỡ khỏi hành trang A", not p_a.inventory.has(test_item) and has_before)
		check("stake: vật phẩm nằm trong khung cược A", session.side_a.room.owns(test_item))

	# Test đặt tiền phe B
	session.set_gold("b", 80000, p_b)
	session.set_xu("b", 40, p_b)
	session.set_jade("b", 10, p_b)
	check("stake: phe B đặt cược đúng", session.side_b.gold == 80000 and session.side_b.xu == 40 and session.side_b.jade == 10)

	# Test khoá cược
	check("stake: trước khi khoá cả hai chưa khoá", not session.is_both_locked())
	session.toggle_lock("a")
	check("stake: phe A đã khoá", session.side_a.locked == true)

	# Khi đã khoá thử sửa cược thì bị chặn
	var err_modify := session.set_gold("a", 200000, p_a)
	check("stake: khi đã khoá thì không sửa được cược", err_modify != "" and session.side_a.gold == 100000)

	session.toggle_lock("b")
	check("stake: cả hai bên đã xác nhận khoá", session.is_both_locked() == true)

	# Test khấu trừ ký quỹ khi vào trận
	session.deduct_escrow(p_a, "a")
	check("stake: khấu trừ tiền ký quỹ của trưởng nhóm A", p_a.gold == 400000)
	check("stake: khấu trừ xu ký quỹ của trưởng nhóm A", p_a.xu == 150)
	check("stake: khấu trừ KNB ký quỹ của trưởng nhóm A", p_a.jade == 35)

	# Test trao thưởng khi phe A THẮNG
	var res := session.payout_to_winner("a", p_a, "a")
	check("stake: kết quả trả về là bên A thắng", res.is_winner == true)
	check("stake: tổng tiền cược gộp cả 2 bên (100k + 80k)", res.total_gold == 180000)
	check("stake: tổng xu gộp cả 2 bên (50 + 40)", res.total_xu == 90)
	check("stake: tổng KNB gộp cả 2 bên (15 + 10)", res.total_jade == 25)

	# Kiểm tra tài sản thực tế của trưởng nhóm A sau khi nhận giải thưởng:
	# Ban đầu có 500k, bị trừ 100k ký quỹ còn 400k, sau đó nhận tổng 180k -> 580k (+80k thắng từ B)
	check("stake: trưởng nhóm A nhận đủ 580k lượng", p_a.gold == 580000)
	# Xu: 200 - 50 = 150 + 90 = 240 xu (+40 xu thắng từ B)
	check("stake: trưởng nhóm A nhận đủ 240 xu", p_a.xu == 240)
	# KNB: 50 - 15 = 35 + 25 = 60 KNB (+10 KNB thắng từ B)
	check("stake: trưởng nhóm A nhận đủ 60 KNB", p_a.jade == 60)
	if test_item != null:
		check("stake: trưởng nhóm A nhận lại vật phẩm vào hành trang", p_a.inventory.has(test_item))

	# Test hoàn trả khi huỷ / hoà (refund_all)
	var s2 := PkStakeSession.new()
	s2.set_gold("a", 50000, p_a)
	s2.deduct_escrow(p_a, "a")
	check("stake: sau khi trừ cược s2", p_a.gold == 530000)
	s2.refund_all(p_a, "a")
	check("stake: hoàn trả toàn bộ khi huỷ trận", p_a.gold == 580000)

func test_stake_window_ui() -> void:
	print("--- TEST UI CỬA SỔ ĐẶT CƯỢC THÁCH ĐẤU ---")
	var p := PlayerProfile.new()
	p.display_name = "BangChu"
	p.gold = 1000000
	p.xu = 500
	p.jade = 100

	var sess := PkStakeSession.new()
	sess.side_a.leader_name = p.display_name
	sess.side_b.leader_name = "DoiThu"

	var win := PkStakeWindow.new(sess, p, {}, "a")
	add_child(win)

	check("stake_ui: khởi tạo cửa sổ đặt cược thành công", win != null)
	check("stake_ui: nút tiền A tồn tại", win._a_money_btn != null)
	check("stake_ui: nút xu A tồn tại", win._a_xu_btn != null)
	check("stake_ui: nút KNB A tồn tại", win._a_jade_btn != null)
	check("stake_ui: nút khoá cược A tồn tại", win._a_lock_btn != null)
	check("stake_ui: nút khoá cược B tồn tại", win._b_lock_btn != null)

	# Bấm khoá cược A trên UI
	win._a_lock_btn.emit_signal("pressed")
	check("stake_ui: bấm nút khoá cược A cập nhật trạng thái", sess.side_a.locked == true)

	win.queue_free()

	# Kiểm tra nút mở khung cược trong phòng Thách Đấu
	var p_host := PlayerProfile.new()
	p_host.display_name = "ChuPhong"
	var pk_win := PkWindow.new(p_host)
	add_child(pk_win)
	pk_win._select_mode(PkRules.Mode.THACH_DAU)
	var room := PkLobby.create(p_host, PkRules.Mode.THACH_DAU, "", 2)
	check("lobby: phòng thách đấu tự động có stake_session", room.has("stake") and room["stake"] != null)

	pk_win._show_room(room)
	var found_btn := false
	for b in pk_win.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.text.contains("Khung Cược") or btn.text.contains("Đặt Cược"):
			found_btn = true
			break
	check("lobby_ui: phòng chờ Thách Đấu có nút mở khung đặt cược", found_btn)

	PkLobby.close(str(room["id"]))
	pk_win.queue_free()


extends Node
## Phía máy người chơi của Lộn Xộn (không cần server): LonXonManager vào / ra host (sao lưu + trả hồ sơ thật), LonXonWindow (số người
## từng host, Bắt Đầu -> vào map khi server báo "match"), LonXonClient (Lệnh Bài: to / tầm skill / camera, Top 5, số hạng, đếm ngược
## hồi sinh, chọn thẻ 5x).
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/lon_xon_client_tests.tscn

var _fail := 0

func check(name: String, ok: bool, detail: Variant = "") -> void:
	print(("  OK  " if ok else "  FAIL ") + name + ("" if ok else "  %s" % str(detail)))
	if not ok:
		_fail += 1

## Nhân vật giả: đủ trường LonXonClient dùng.
class FakePlayer extends Node2D:
	signal died
	var avatar := Node2D.new()
	var view_mult := 1.0
	var skill_radius_mult := 1.0
	var suppress_death_popup := false
	var revived := 0
	var notes: Array = []
	func _ready() -> void:
		add_child(avatar)
	func revive() -> void:
		revived += 1
	func notify(t: String) -> void:
		notes.append(t)

func _profile() -> PlayerProfile:
	var p := PlayerProfile.new()
	p.display_name = "Thử"
	p.sect_id = "thieu_lam"
	p.level = 150
	p.gold = 777
	p.add_item(ItemGenerator.generate_misc("1_0_0_1"))
	return p

func _ready() -> void:
	await _manager_tests()
	await _window_tests()
	await _client_tests()
	print("--- lon_xon_client_tests: %s ---" % ("TẤT CẢ ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)

func _manager_tests() -> void:
	var p := _profile()
	GameManager.local_profile = p
	var entry := LonXonManager.start_online(p, {"op": "match", "host": 3, "rid": 8000003, "box": [1000, 2000, 71680, 40960], "spawn": [5000, 6000]})
	check("Mục map: cờ Lộn Xộn online", bool(entry.get("lon_xon")) and bool(entry.get("lonxon_online")) and int(entry.get("lonxon_host")) == 3)
	check("Mục map: map Tống Kim 1 + khung", str(entry.get("dir")) == PubgManager.TONGKIM1_DIR and (entry.arena_box as Rect2).size == Vector2(71680, 40960))
	check("Mục map: không phải PUBG (không mở thẻ 8x / vòng bo)", not entry.has("pubg") and not entry.has("is_pubg"))
	check("Đang ở Lộn Xộn, host 3", LonXonManager.is_active and LonXonManager.host == 3)
	## Trong host: hồ sơ thành bản tạm -> rời: trả lại nguyên vẹn
	LonXonRules.apply_start(p)
	GameManager.field_map = entry
	LonXonManager.end(p)
	check("Rời: trả cấp 150 + tiền + túi thật", p.level == 150 and p.gold == 777 and p.inventory.size() == 1 and p.inventory[0].misc_id == "1_0_0_1")
	check("Rời: tắt cờ + bỏ field_map", not LonXonManager.is_active and not LonXonRules.in_match and GameManager.field_map.is_empty())

func _window_tests() -> void:
	var p := _profile()
	var played: Array = []
	var win := LonXonWindow.open(self, p, func(e: Dictionary) -> void: played.append(e)) as LonXonWindow
	await get_tree().process_frame
	check("Offline: báo chỉ chơi online", not win._online and win._status.text.contains("online"))
	## Giả lập online: server trả số người từng host
	win._online = true
	win._on_lonxon_message({"op": "hosts", "hosts": [{"host": 1, "players": 7, "cap": 50}, {"host": 4, "players": 50, "cap": 50}]})
	check("Host 1: 7/50", win._host_buttons[0].text.contains("7/50"))
	check("Host 4 đầy: khoá nút", win._host_buttons[3].disabled)
	win._pick_host(2)
	win._on_start_pressed()
	check("Bắt Đầu: đang vào host 2", win._joining and win._status.text.contains("Host 2"))
	win._on_lonxon_message({"op": "match", "host": 2, "rid": 8000002, "box": [0, 0, 100, 100], "spawn": [50, 50]})
	check("Server báo match: vào map Lộn Xộn host 2", played.size() == 1 and int(played[0].get("lonxon_host")) == 2)
	await get_tree().process_frame
	check("Cửa sổ tự đóng", not is_instance_valid(win))
	LonXonManager.end(p)

func _client_tests() -> void:
	var p := _profile()
	GameManager.local_profile = p
	LonXonManager.start_online(p, {"host": 1, "box": [0, 0, 100, 100]})
	var player := FakePlayer.new()
	player.add_to_group("player")
	add_child(player)
	var cl := LonXonClient.create()
	add_child(cl)
	await get_tree().process_frame
	check("Vào host: tắt bảng 'Về thành dưỡng sức'", player.suppress_death_popup)
	check("Vào host: hồ sơ tạm cấp 50 trên máy", p.level == 50)
	check("Vào host: bật cờ dùng bí kíp", LonXonRules.in_match)
	var popups := get_tree().get_nodes_in_group("pubg_draft_popup")
	check("Vào host: mở popup chọn thẻ 5x", popups.size() == 1 and popups[0]._tier == PubgDraftPopup.TIER_LONXON)
	for pp in popups:
		pp.queue_free()

	cl._on_message({"op": "tokens", "n": 3, "score": 3000, "gained": 3})
	check("3 Lệnh Bài: to x1.3", player.avatar.scale.is_equal_approx(Vector2.ONE * 1.3))
	check("3 Lệnh Bài: tầm skill x1.15", is_equal_approx(player.skill_radius_mult, 1.15))
	check("3 Lệnh Bài: tầm nhìn x1.3", is_equal_approx(player.view_mult, 1.3))
	check("Thông báo nhặt Lệnh Bài", player.notes.any(func(t): return str(t).contains("+3 Lệnh Bài")))
	cl._on_message({"op": "tokens", "n": 12, "score": 12000})
	check("12 Lệnh Bài: trần to x2, tầm nhìn x1.5", player.avatar.scale.is_equal_approx(Vector2.ONE * 2.0) and is_equal_approx(player.view_mult, 1.5))

	NetClient.my_eid = 77
	cl._on_message({"op": "board", "top": [{"name": "Bình", "score": 5000, "eid": 5}, {"name": "Thử", "score": 3000, "eid": 77}],
		"badges": {"5": 1, "77": 2}, "sizes": {"5": 5, "77": 3}})
	check("Top 5: dòng 1 = Bình 5.000", cl._board_rows[0].text == "1. Bình — 5.000")
	check("Top 5: dòng 2 = mình", cl._board_rows[1].text.begins_with("2. Thử"))
	check("Top 5: dòng trống ẩn", not cl._board_rows[2].visible)
	check("Mình trong top: ẩn dòng 'Bạn:'", not cl._board_me.visible)
	var badge := player.get_node_or_null(LonXonClient.BADGE_NAME) as Label
	check("Số hạng 2 trên đầu mình", badge != null and badge.text == "2")
	cl._on_message({"op": "board", "top": [{"name": "Bình", "score": 5000, "eid": 5}], "badges": {"5": 1}, "sizes": {}})
	await get_tree().process_frame
	check("Rớt khỏi top 3: gỡ số hạng", player.get_node_or_null(LonXonClient.BADGE_NAME) == null)
	check("Ngoài top: hiện dòng 'Bạn:'", cl._board_me.visible)

	# Chết -> đếm ngược 5 giây -> gửi hồi sinh -> server báo respawn
	player.died.emit()
	cl._on_message({"op": "died", "respawn_in": 5.0, "items": 4, "tokens": 7, "killer": "Bình"})
	check("Chết: hiện đếm ngược", cl._countdown.visible and cl._dead)
	cl._process(2.0)
	check("Đếm ngược còn 3 giây", cl._countdown.text.contains("3 giây"))
	check("Báo bị Bình hạ, rớt 4 món + 7 Lệnh Bài", player.notes.any(func(t): return str(t).contains("Bình") and str(t).contains("7 Lệnh Bài")))
	cl._process(3.5)
	cl._process(0.1)
	check("Hết giờ: đang gửi hồi sinh", cl._countdown.text.contains("hồi sinh"))
	check("Chưa nhận respawn: chưa sống lại", player.revived == 0)
	cl._on_message({"op": "respawn", "protect": 3})
	check("Server báo respawn: sống lại, ẩn đếm ngược", player.revived == 1 and not cl._countdown.visible and not cl._dead)
	popups = get_tree().get_nodes_in_group("pubg_draft_popup")
	check("Hồi sinh: mở lại popup chọn thẻ 5x", popups.size() == 1)
	for pp in popups:
		pp.queue_free()

	cl._on_message({"op": "level", "level": 55, "gained": 5})
	check("Lên cấp: thông báo", player.notes.any(func(t): return str(t).contains("Lên cấp 55")))
	cl.queue_free()
	await get_tree().process_frame
	check("Thoát host: trả tầm nhìn / tầm skill", is_equal_approx(player.view_mult, 1.0) and is_equal_approx(player.skill_radius_mult, 1.0))
	LonXonManager.end(p)

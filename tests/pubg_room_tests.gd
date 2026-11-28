extends Node
## Phòng chờ PUBG: tạo phòng 1-4 người, vào phòng bằng mã, thẻ thành viên (hình nhân vật/ngựa/ngoại trang), chat.
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/pubg_room_tests.tscn
##   (bỏ --headless + đặt PUBG_SHOT=đường_dẫn.png để chụp ảnh phòng chờ 4 người)
var _fail := 0
func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

func _ready() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "HỏaLong"
	profile.level = 120
	PubgManager.schedule_bypass = true   ## test chạy giờ nào cũng được
	PubgManager.rooms.clear()
	PubgManager.init_default_rooms()

	var win: PubgWindow = PubgWindow.open(self, profile) as PubgWindow
	await get_tree().process_frame
	if OS.get_environment("PUBG_SHOT") != "":
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("PUBG_SHOT").replace(".png", "_list.png"))

	# Tạo phòng 4 người
	win._create_mode = 4
	win._do_create_room("")
	await get_tree().process_frame
	var room: Dictionary = win._current_room
	check("Tạo phòng 4 người -> mode 4", int(room.get("mode", 0)) == 4)
	check("Có 1 thành viên là mình, làm chủ phòng", win._members(room).size() == 1 and win._am_leader(room))
	check("Vẽ 4 thẻ (1 người + 3 chỗ trống)", _count_cards(win) == 4)
	check("Có hình nhân vật trong thẻ", _find(win, "CharacterAvatar") != null)

	# Chat
	win._chat_input.text = "xin chào [b]đội[/b]"
	win._on_chat_send()
	var last: String = str(room["chat"].back())
	check("Chat ghi vào lịch sử phòng, chặn bbcode", last.contains("xin chào [lb]b]"))

	# Thêm đồng đội máy, rồi mời ra
	win._on_add_bot_member()
	win._on_add_bot_member()
	check("Thêm 2 bot -> 3 người", win._members(room).size() == 3 and int(room["players"]) == 3)
	# Chat mật: bấm tên trong chat (meta) -> kênh Mật; gửi -> dòng [Mật]; chọn lại Tán gẫu
	var mate_name: String = str(win._members(room)[1]["name"])
	win._chat_log.meta_clicked.emit(mate_name)
	check("Bấm tên -> chuyển sang chat mật", win._chat_target == mate_name and win._chat_channel_btn.text.contains(mate_name))
	win._chat_input.text = "đi chung nhé"
	win._on_chat_send()
	check("Tin mật ghi [Mật] tới đúng người", str(room["chat"].back()).contains("[Mật] Bạn → ") and str(room["chat"].back()).contains(mate_name))
	var pend: Array = ChatBox._pending_lines
	## dòng kiểu gốc: ảnh kênh Riêng (chtx_4 / chtx_self) + "người gửi → người nhận:" + nội dung (ChatBox.format_line)
	check("Tin mật lưu sang chat chính (kênh Riêng)", not pend.is_empty() and str(pend.back()).contains("HỏaLong → " + mate_name)
		and str(pend.back()).contains("đi chung nhé") and (str(pend.back()).contains("chtx_4") or str(pend.back()).contains("chtx_self")))
	var box := ChatBox.create()
	add_child(box)
	check("Khung chat chính dựng xong -> nhận tin mật đang chờ", ChatBox._pending_lines.is_empty() and box._log.get_parsed_text().contains("đi chung nhé"))
	box.queue_free()
	win._chat_log.meta_clicked.emit(win._my_name())
	check("Bấm tên mình -> không đổi kênh", win._chat_target == mate_name)
	win._set_chat_target("")
	check("Chọn Tán gẫu -> về kênh phòng", win._chat_target == "" and win._chat_channel_btn.text.contains("Tán gẫu"))
	check("Thẻ chỉ còn tên + cấp + phái", not _has_text(win, "Ngựa:") and not _has_text(win, "Phi phong:") and _has_text(win, "Cấp 120 — "))

	var bot_name: String = str(win._members(room)[2]["name"])
	win._on_kick_member(bot_name)
	check("Mời ra -> 2 người", win._members(room).size() == 2 and int(room["players"]) == 2)
	check("Chat vẫn còn sau khi vẽ lại", win._chat_log.get_parsed_text().contains("xin chào"))

	var shot := OS.get_environment("PUBG_SHOT")
	if shot != "":
		win._on_add_bot_member()
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		print("Đã chụp ", shot)

	# Rời phòng (chủ phòng) -> xóa phòng
	var rid := str(room["id"])
	win._on_leave_waiting_room()
	check("Chủ phòng rời -> phòng bị xóa", PubgManager.rooms.all(func(r: Dictionary) -> bool: return str(r["id"]) != rid))

	# Vào phòng người khác bằng mã (PUBG-1024: Squad đang có 3 người)
	win._select_tab(0)
	win._edit_join_code.text = "1024"
	win._on_join_by_code()
	await get_tree().process_frame
	var r2: Dictionary = win._current_room
	check("Nhập '1024' -> vào PUBG-1024", str(r2.get("id", "")) == "PUBG-1024" and win._in_waiting_room)
	check("Phòng có 4 người, mình không phải chủ phòng", win._members(r2).size() == 4 and not win._am_leader(r2))
	check("Chủ phòng giữ tên cũ", str(win._members(r2)[0]["name"]) == "DươngQuá")
	win._on_leave_waiting_room()
	check("Rời phòng người khác -> còn 3 người", win._members(r2).size() == 3 and int(r2["players"]) == 3)

	# Mã sai / phòng đầy
	win._select_tab(0)
	win._edit_join_code.text = "PUBG-0000"
	win._on_join_by_code()
	check("Mã sai -> không vào phòng", not win._in_waiting_room)

	# ---- Kiểu PUBG thật: không danh sách phòng, giờ mở, máy chủ, tự ghép đội ----
	check("Tab Vào Trận không còn bảng danh sách phòng", not _has_text(win, "Chủ Phòng") and _has_button(win, "BẮT ĐẦU CHƠI"))
	win._show_mode_select_popup()
	check("Popup chọn chế độ có đủ 4 chế độ", _has_button(win, "SOLO") and _has_button(win, "SQUAD"))
	for c in win.get_children():
		if c.is_in_group("pubg_mode_popup"):
			c.queue_free()
	check("Giờ mở 20:00-22:00", PubgManager.is_open_at(20 * 3600) and PubgManager.is_open_at(22 * 3600 - 1) and not PubgManager.is_open_at(22 * 3600) and not PubgManager.is_open_at(19 * 3600 + 59 * 60))
	check("Còn 1 giờ nữa mới mở lúc 19:00", PubgManager.secs_until_open(19 * 3600) == 3600 and PubgManager.secs_until_open(23 * 3600) == 21 * 3600)
	check("Còn 30 phút nữa đóng lúc 21:30", PubgManager.secs_until_close(21 * 3600 + 1800) == 1800)
	if not PubgManager.is_open_at(PubgManager.now_sec_of_day()):
		PubgManager.schedule_bypass = false
		if AccountApi != null:
			AccountApi.gm_mode_enabled = false
			check("Người thường ngoài giờ mở -> is_open() = false", not PubgManager.is_open() and PubgManager.closed_reason() != "")
			check("Người thường ngoài giờ mở -> _check_open() = false", not win._check_open())
			for c in win.get_children():
				if c is SocialWindow:
					c.queue_free()

			AccountApi.gm_mode_enabled = true
			check("GM ngoài giờ mở -> is_open() = true (Bất chấp thời gian)", PubgManager.is_open() and PubgManager.closed_reason() == "")
			check("GM ngoài giờ mở -> _check_open() = true", win._check_open())
			win._update_schedule_label()
			check("GM dòng giờ hiển thị QUYỀN GM", win._lbl_schedule != null and win._lbl_schedule.text.contains("QUYỀN GM: ĐANG MỞ"))

		var before := PubgManager.rooms.size()
		win._on_start_pressed()
		check("Ngoài giờ mở -> không tạo phòng / không tìm trận", PubgManager.rooms.size() == before and not win._is_searching and not win._in_waiting_room)
		for c in win.get_children():
			if c is SocialWindow:
				c.queue_free()   ## đóng hộp báo "Chưa Tới Giờ Mở"
		PubgManager.schedule_bypass = true
	var other_srv := {"id": "PUBG-5555", "mode": 2, "status": PubgManager.STATUS_WAITING, "server_id": 2}
	check("Đội ở máy chủ khác -> không vào được", PubgManager.join_block_reason(other_srv, 1, 1) == "other_server" and PubgManager.join_block_reason(other_srv, 1, 2) == "")
	check("Phòng mẫu offline thuộc mọi máy chủ", PubgManager.same_server({"id": "x"}, 3))
	check("Tự ghép: Squad 2 người bật fill -> ghép 2 người lạ", PubgManager.fill_slots({"mode": 4, "fill": true}, 2) == 2 and PubgManager.fill_slots({"mode": 4, "fill": false}, 2) == 0)
	var sq_prof := PlayerProfile.new()
	sq_prof.display_name = "ĐộiTrưởng"
	PubgManager.start_match(sq_prof, {"id": "PUBG-SQ", "mode": 4, "members": [{"name": "ĐộiTrưởng", "is_self": true}, {"name": "BạnThân"}]})
	check("Tắt tự ghép -> vào trận đúng 2 người trong đội", PubgManager.current_squad_size == 2 and PubgManager.current_squad_members.size() == 2 and str(PubgManager.current_squad_members[1]["name"]) == "BạnThân")
	PubgManager.end_match(sq_prof)
	win._fill_on = true
	win._create_mode = 2
	var fd: Dictionary = win._do_create_room("")
	check("Tạo đội ghi máy chủ + bật tự ghép", fd.has("server_id") and bool(fd["fill"]))
	win._on_toggle_fill()
	check("Chủ phòng tắt tự ghép", not bool(fd["fill"]))
	win._on_leave_waiting_room()
	win._select_tab(0)

	# ---- Cơ chế tìm trận / tạo phòng kiểu game lớn ----
	check("Sức chứa trận theo đội", PubgManager.match_capacity(1) == 50 and PubgManager.match_capacity(3) == 48 and PubgManager.match_capacity(4) == 48)
	check("Chuẩn hoá mã phòng", PubgManager.normalize_room_code(" pubg_77 ") == "PUBG-77")

	# Bỏ các trận giả lập đang đấu để không bị ghép thay bot (vào map thật) giữa test
	for i in range(PubgManager.rooms.size() - 1, -1, -1):
		if str(PubgManager.rooms[i].get("status", "")) == PubgManager.STATUS_PLAYING:
			PubgManager.rooms.remove_at(i)

	# Chơi Ngay: phòng 1 người, tự tìm trận luôn
	win._on_quick_play()
	var q: Dictionary = win._current_room
	check("Chơi Ngay -> phòng 1 người, đang tìm trận", int(q["mode"]) == 1 and win._is_searching and str(q["status"]) == PubgManager.STATUS_SEARCHING)
	check("Phòng đang tìm trận không cho người khác vào", PubgManager.join_block_reason(q, 0) == "searching")
	win._on_cancel_search()
	check("Hủy tìm Solo -> về màn Vào Trận, bỏ phòng tạm", not win._is_searching and not win._in_waiting_room and PubgManager.find_room(str(q["id"])).is_empty())

	# Tạo phòng mới khi đang ở phòng khác -> tự rời phòng cũ (mỗi người chỉ 1 phòng)
	var qid := str(q["id"])
	win._create_mode = 2
	var duo: Dictionary = win._do_create_room("")
	check("Tạo phòng mới -> phòng cũ bị giải tán", PubgManager.find_room(qid).is_empty() and int(duo["mode"]) == 2)
	check("Mã phòng không trùng", PubgManager.find_room(str(duo["id"])) == duo)

	# Mặc định ai vào phòng cũng Chưa Sẵn Sàng, kể cả chủ phòng; cả phòng sẵn sàng -> tự tìm trận
	var mate := win._make_bot_member([])
	mate["ready"] = false
	duo["members"].append(mate)
	win._sync_player_count(duo)
	win._render_content()
	# Lỗi người chơi báo: chủ phòng Chưa Sẵn Sàng mà không có nút nào -> kẹt
	check("Chủ phòng chưa sẵn sàng -> có nút BẤM SẴN SÀNG", not win._is_ready and win._btn_ready.text.contains("BẤM SẴN SÀNG") and not win._btn_ready.disabled)
	win._on_toggle_ready()
	check("Chủ phòng sẵn sàng, đồng đội chưa -> chờ (nút khóa) + có Hủy Sẵn Sàng", win._btn_ready.disabled and not win._is_searching and _has_button(win, "Hủy Sẵn Sàng"))
	win._on_toggle_ready()
	mate["ready"] = true
	win._on_toggle_ready()
	check("Cả phòng sẵn sàng -> tự bắt đầu tìm trận", win._is_searching and win._matched_players_count >= 2)

	# Đóng cửa sổ khi đang tìm -> hủy tìm, mở lại quay về đúng phòng chờ
	win.close_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check("Đóng cửa sổ -> phòng không kẹt ở Đang Tìm Trận", str(duo["status"]) != PubgManager.STATUS_SEARCHING)
	win = PubgWindow.open(self, profile) as PubgWindow
	await get_tree().process_frame
	check("Mở lại -> về đúng phòng chờ cũ", win._in_waiting_room and is_same(win._current_room, duo))

	# Vào phòng có chủ phòng là máy: mình sẵn sàng -> chủ phòng tự tìm trận
	win._edit_join_code = LineEdit.new()
	win._edit_join_code.text = "3392"
	win._on_join_by_code()
	var trio: Dictionary = win._current_room
	check("Vào phòng khác -> tự rời phòng cũ", str(trio["id"]) == "PUBG-3392" and win._self_index(duo) < 0)
	win._on_toggle_ready()
	await get_tree().create_timer(1.5).timeout
	check("Cả đội sẵn sàng -> chủ phòng máy tự tìm trận", win._is_searching)
	win._on_leave_waiting_room()
	check("Rời khi đang tìm -> phòng mở lại", str(trio["status"]) != PubgManager.STATUS_SEARCHING and win._self_index(trio) < 0)

	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _count_cards(win: PubgWindow) -> int:
	var n := 0
	for c in _all(win):
		if c is PanelContainer and c.get_parent() is HBoxContainer and c.get_parent().alignment == BoxContainer.ALIGNMENT_CENTER and c.get_parent().get_parent() is VBoxContainer:
			n += 1
	return n

func _has_button(root: Node, s: String) -> bool:
	for c in _all(root):
		if c is Button and (c as Button).text.contains(s):
			return true
	return false

func _has_text(root: Node, s: String) -> bool:
	for c in _all(root):
		if c is Label and (c as Label).text.contains(s):
			return true
	return false

func _find(root: Node, cls: String) -> Node:
	for c in _all(root):
		if c.get_script() != null and c.get_script().get_global_name() == cls:
			return c
	return null

func _all(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out

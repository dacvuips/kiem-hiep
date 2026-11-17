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
	PubgManager.rooms.clear()
	PubgManager.init_default_rooms()

	var win: PubgWindow = PubgWindow.open(self, profile) as PubgWindow
	await get_tree().process_frame

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

	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _count_cards(win: PubgWindow) -> int:
	var n := 0
	for c in _all(win):
		if c is PanelContainer and c.get_parent() is HBoxContainer and c.get_parent().alignment == BoxContainer.ALIGNMENT_CENTER and c.get_parent().get_parent() is VBoxContainer:
			n += 1
	return n

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

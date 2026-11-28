extends Node

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS: ", name)
	else:
		_fail += 1
		print("FAIL: ", name, " | ", detail)

func _ready() -> void:
	print("--- BẮT ĐẦU TEST KHUNG CHAT, EXP QUÁI, KNB & TIÊN THẢO LỘ ---")
	test_chat_box_tabs()
	test_chat_commands()
	test_kill_exp_display()
	print("RESULT: ", _pass, "/", _pass + _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func test_chat_box_tabs() -> void:
	print("[1] Test ChatBox tabs...")
	var chat := ChatBox.create()
	add_child(chat)

	# Initially ALL tab
	check("Mặc định phải là Tab.ALL", chat._current_tab == ChatBox.Tab.ALL)

	# Add normal chat and system message
	chat.add_line("Người chơi: Xin chào thế giới!", false)
	ChatBox.push_system("[color=#ffaa00][Hệ thống][/color] Tin tức hệ thống 1")

	# Check message counts in ALL tab
	check("Phải có 2 tin trong _messages", chat._messages.size() == 2)
	check("Cả 2 tin phải hiện trong tab Tất cả", chat._lines == 2)

	# Switch to SYSTEM tab
	chat._set_tab(ChatBox.Tab.SYSTEM)
	check("Chuyển sang Tab.SYSTEM thành công", chat._current_tab == ChatBox.Tab.SYSTEM)
	check("Chỉ 1 tin hệ thống được hiện trong tab Hệ thống", chat._lines == 1)

	# Add another system message while in SYSTEM tab
	ChatBox.push_exp("Nhím Rừng", 250)
	check("Tin EXP KHÔNG ghi vào khung chat", chat._lines == 1 and chat._messages.size() == 2)
	check("EXP hiện chữ nổi +250 EXP", chat._exp_rows.size() == 1 and (chat._exp_rows[0].label as Label).text == "+250 EXP")
	for i in 4:
		ChatBox.push_exp("Nhím Rừng", 10 + i)
	check("Chữ EXP nổi tối đa 3 dòng", chat._exp_rows.size() == 3)
	chat._update_exp(ChatBox.EXP_LIFE + 0.1)
	check("Chữ EXP biến mất sau 3 giây", chat._exp_rows.is_empty() and chat._exp_pool.size() == 3)

	# Add another normal player message while in SYSTEM tab
	chat.add_line("Người chơi 2: Đang ở đâu thế?", false, ChatServer.WORLD)
	check("Tin người chơi KHÔNG được hiện trong tab Hệ thống", chat._lines == 1)
	check("Tổng tin lưu trữ phải là 3", chat._messages.size() == 3)

	# Switch back to ALL tab
	chat._set_tab(ChatBox.Tab.ALL)
	check("Tất cả 3 tin phải hiển thị khi quay về tab Tất cả", chat._lines == 3)

	# Lọc theo kênh Thế giới
	chat._set_channel_view(ChatServer.WORLD)
	check("Lọc kênh Thế giới chỉ hiện 1 tin", chat._lines == 1)
	chat._set_tab(ChatBox.Tab.ALL)

	# Ô chọn kênh gửi
	check("Ô chọn kênh có 6 tần số", chat._channel_pick.item_count == 6)
	chat._set_send_channel(ChatServer.PRIVATE)
	check("Chọn kênh Riêng hiện ô tên người nhận", chat._to.visible)
	chat._set_send_channel(ChatServer.FACTION)
	check("Chọn kênh Môn phái ẩn ô tên", not chat._to.visible and chat._channel == ChatServer.FACTION)

	chat.queue_free()

func test_chat_commands() -> void:
	print("[2] Test Chat commands (/knb, /ttl)...")
	var p := PlayerProfile.new()
	p.display_name = "TestPlayer"
	p.jade = 100
	GameManager.local_profile = p

	var chat := ChatBox.create()
	add_child(chat)

	# Test /knb command
	chat._handle_slash_command("/knb 2500")
	check("KNB phải tăng từ 100 lên 2600", p.jade == 2600, "Thực tế: %d" % p.jade)

	# Test /xu command
	chat._handle_slash_command("/xu 1500")
	check("Xu phải tăng lên 1500", p.xu == 1500, "Thực tế: %d" % p.xu)

	# Test /ttl command
	var initial_item_count := p.inventory.size()
	chat._handle_slash_command("/ttl")
	check("Phải thêm 4 vật phẩm (TTL 1h, 8h, Hoàn, KNB)", p.inventory.size() == initial_item_count + 4)

	var found_ttl_1h := false
	var found_ttl_8h := false
	var found_ttl_hoan := false
	var found_knb := false
	for it in p.inventory:
		if it.misc_id == "6_1_71": found_ttl_1h = true
		if it.misc_id == "6_1_1181": found_ttl_8h = true
		if it.misc_id == "6_1_113": found_ttl_hoan = true
		if it.misc_id == "6_1_1877": found_knb = true

	check("Phải có Tiên Thảo Lộ 1h", found_ttl_1h)
	check("Phải có Tiên Thảo Lộ đặc biệt 8h", found_ttl_8h)
	check("Phải có Tiên Thảo hoàn", found_ttl_hoan)
	check("Phải có Kim Nguyên Bảo vật phẩm", found_knb)

	# Test /lead command
	chat._handle_slash_command("/lead 25")
	check("/lead 25 đặt cấp lãnh đạo thành 25", p.lead_level == 25, "Thực tế: %d" % p.lead_level)
	chat._handle_slash_command("/lead +5")
	check("/lead +5 tăng cấp lãnh đạo lên 30", p.lead_level == 30, "Thực tế: %d" % p.lead_level)

	# Test /leadexp command
	p.lead_level = 0
	p.lead_exp = 0
	chat._handle_slash_command("/leadexp 100")
	check("/leadexp 100 thăng cấp lãnh đạo lên 1", p.lead_level == 1 and p.lead_exp == 100)

	chat.queue_free()

func test_kill_exp_display() -> void:
	print("[3] Test hiển thị EXP khi diệt quái...")
	var chat := ChatBox.create()
	add_child(chat)

	var p := PlayerProfile.new()
	p.level = 10
	p.current_exp = 0
	GameManager.local_profile = p

	var m := VltkMonster.new()
	m.level = 10
	m.data = {
		"name": "Heo Rừng",
		"exp": 120,
		"element": 0,
	}

	var before_exp := p.current_exp
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP   ## Vượt Ải (mặc định) không cộng exp hạ quái
	KillRewards.on_monster_killed(m)
	check("EXP người chơi phải tăng khi diệt quái", p.current_exp > before_exp)

	# EXP hạ quái không vào chat, chỉ hiện chữ nổi
	check("Không ghi tin kinh nghiệm vào chat", chat._messages.is_empty())
	check("Có chữ nổi +EXP", chat._exp_rows.size() == 1 and (chat._exp_rows[0].label as Label).text.begins_with("+"))

	m.free()
	chat.queue_free()

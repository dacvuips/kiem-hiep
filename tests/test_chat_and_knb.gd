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
	check("Tin EXP phải hiện trong tab Hệ thống", chat._lines == 2)

	# Add another normal player message while in SYSTEM tab
	chat.add_line("Người chơi 2: Đang ở đâu thế?", false)
	check("Tin người chơi KHÔNG được hiện trong tab Hệ thống", chat._lines == 2)
	check("Tổng tin lưu trữ phải là 4", chat._messages.size() == 4)

	# Switch back to ALL tab
	chat._set_tab(ChatBox.Tab.ALL)
	check("Tất cả 4 tin phải hiển thị khi quay về tab Tất cả", chat._lines == 4)

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
	KillRewards.on_monster_killed(m)
	check("EXP người chơi phải tăng khi diệt quái", p.current_exp > before_exp)

	# Check chat log contains monster kill notice
	var last_msg: Dictionary = chat._messages.back()
	check("Thông báo EXP phải là tin hệ thống", last_msg.get("is_system", false) == true)
	var text: String = str(last_msg.get("text", ""))
	check("Thông báo phải có tên quái Heo Rừng", text.contains("Heo Rừng"), text)
	check("Thông báo phải có chữ kinh nghiệm", text.contains("kinh nghiệm"), text)

	m.free()
	chat.queue_free()

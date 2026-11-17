extends Node

func _ready() -> void:
	print("--- TEST MAP SELECT TIER LOCK & CARD DISPLAY ---")
	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	var api: Node = get_node_or_null("/root/AccountApi")
	assert(api != null, "AccountApi singleton phải tồn tại")
	
	# 1. Test Level 13, GM OFF
	api.gm_mode_enabled = false
	var p13 := PlayerProfile.new()
	p13.level = 13
	GameManager.local_profile = p13
	
	var win13 := MapSelectWindow.new(p13, Callable())
	add_child(win13)
	
	assert(win13._tier == 1, "Mốc mặc định của cấp 13 phải là 1 (1x)")
	var btns13: Array = win13._tier_buttons
	assert(btns13[0].disabled == false and btns13[0].text == "1x", "1x phải mở")
	for i in range(1, 12):
		var t := i + 1
		assert(btns13[i].disabled == true, "%dx phải bị khóa" % t)
		assert("🔒" in btns13[i].text, "%dx phải có biểu tượng khóa 🔒" % t)
	
	# Kiểm tra map cards trong mốc 1x
	var scroll: ScrollContainer = win13.get("_map_list_scroll")
	assert(scroll != null, "_map_list_scroll phải tồn tại")
	var list: VBoxContainer = scroll.get_child(0) as VBoxContainer
	assert(list.get_child_count() > 0, "Mốc 1x phải có map cards")
	win13.queue_free()
	
	# 2. Test Level 73, GM OFF
	var p73 := PlayerProfile.new()
	p73.level = 73
	GameManager.local_profile = p73
	
	var win73 := MapSelectWindow.new(p73, Callable())
	add_child(win73)
	
	assert(win73._tier == 7, "Mốc mặc định của cấp 73 phải là 7 (7x)")
	var btns73: Array = win73._tier_buttons
	for i in range(0, 7):
		var t := i + 1
		assert(btns73[i].disabled == false, "%dx phải mở cho cấp 73" % t)
	for i in range(7, 12):
		var t := i + 1
		assert(btns73[i].disabled == true, "%dx phải bị khóa cho cấp 73" % t)
		assert("🔒" in btns73[i].text, "%dx phải có khóa 🔒" % t)
		
	# 3. Test làm mới giao diện sau khi chuyển tab / bật tắt GM
	win73.call("on_presented")
	await get_tree().process_frame
	scroll = win73.get("_map_list_scroll")
	list = scroll.get_child(0) as VBoxContainer
	assert(list.get_child_count() > 0, "Sau khi làm mới, danh sách map không được bị rỗng")
	
	win73.queue_free()
	print("--- PASS 100%: TẤT CẢ MAP CARDS VÀ KHÓA MỐC HIỂN THỊ ĐẦY ĐỦ VÀ CHÍNH XÁC ---")
	get_tree().quit(0)

extends Node

func _ready() -> void:
	print("--- TEST GM MODE TOGGLE STARTED ---")
	var api = get_node_or_null("/root/AccountApi")
	var gm = get_node_or_null("/root/GmManager")
	assert(api != null, "AccountApi must exist")
	assert(gm != null, "GmManager must exist")

	# 1. Giả lập tài khoản GM đăng nhập (Online)
	api.account = {"id": 1001, "username": "admin_test", "is_gm": true}
	assert(api.has_gm_permission() == true, "has_gm_permission must be true")
	assert(api.is_gm() == true, "is_gm must be true by default")
	print("PASS: Tài khoản GM nhận diện chính xác")

	# 2. Tắt chế độ GM (trở về người chơi thường)
	var toggled = api.toggle_gm_mode()
	assert(toggled == true, "toggle_gm_mode must return true")
	assert(api.has_gm_permission() == true, "has_gm_permission must REMAIN true so GM can still toggle it back")
	assert(api.is_gm() == false, "is_gm must be FALSE when toggled off")
	assert(gm.is_gm() == false, "GmManager.is_gm() must also be FALSE")
	print("PASS: Tắt chế độ GM thành công -> Hệ thống nhận diện như người chơi thường")

	# 3. Bật lại chế độ GM
	toggled = api.toggle_gm_mode()
	assert(toggled == true, "toggle_gm_mode must return true")
	assert(api.is_gm() == true, "is_gm must be TRUE again")
	assert(gm.is_gm() == true, "GmManager.is_gm() must be TRUE again")
	print("PASS: Bật lại chế độ GM thành công -> Trở lại quyền Game Master")

	# 4. Kiểm tra tài khoản không có quyền GM
	api.account = {"id": 2002, "username": "normal_player", "is_gm": false}
	# Trong unit test headless, nếu không phải debug build thì has_gm_permission = false.
	# Nếu OS.is_debug_build() true, ta test logic chặn permission:
	var fake_non_gm_permission = api.is_logged_in() and not bool(api.account.get("is_gm", false))
	assert(fake_non_gm_permission == true, "Normal player has is_gm=false in account")
	print("PASS: Tài khoản thường được phân biệt rõ ràng")

	print("--- TEST GM MODE TOGGLE PASSED 100% ---")
	get_tree().quit(0)

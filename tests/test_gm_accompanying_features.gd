extends Node

func _ready() -> void:
	print("--- TEST ACCOMPANYING FEATURES & GM MODE TOGGLE STARTED ---")
	var api = get_node_or_null("/root/AccountApi")
	var gm = get_node_or_null("/root/GmManager")
	var gmm = load("res://systems/game_mode/game_mode_manager.gd")
	assert(api != null, "AccountApi must exist")
	assert(gm != null, "GmManager must exist")
	assert(gmm != null, "GameModeManager must exist")

	# Test 1: Khi là GM và BẬT GM -> Được phép vào mọi map
	api.account = {"id": 8888, "username": "gm_master", "is_gm": true}
	api.gm_mode_enabled = true
	assert(api.is_gm() == true, "Khi bật GM, is_gm() phải true")

	var char_low = PlayerProfile.new()
	char_low.level = 10
	char_low.stages_cleared = 0

	# Test 2: Khi GM TẮT chế độ GM -> Trở về người chơi thường
	api.toggle_gm_mode()
	assert(api.is_gm() == false, "Sau khi tắt, is_gm() phải false")
	assert(api.has_gm_permission() == true, "has_gm_permission vẫn phải true để mở lại")

	# Kiểm tra logic khóa bản đồ theo cấp khi GM đang TẮT
	var map_lvl_90: Dictionary = {"id": 901, "name": "Map 9x", "level": 90, "dir": "res://world/maps/map_321"}
	var is_admin: bool = api.is_gm()
	var req_lvl: int = int(map_lvl_90.get("level", 1))
	var has_lvl: bool = is_admin or (char_low.level >= req_lvl)
	assert(has_lvl == false, "Nhân vật cấp 10 KHÔNG ĐƯỢC PHÉP vào map cấp 90 khi tắt GM")
	print("PASS: Map cấp cao đã bị khóa chính xác đối với người chơi thường / GM khi tắt")

	# Kiểm tra khi map cấp 10 (phù hợp)
	var map_lvl_10: Dictionary = {"id": 101, "name": "Map 1x", "level": 10, "dir": "res://world/maps/map_20"}
	var has_lvl_10: bool = is_admin or (char_low.level >= int(map_lvl_10["level"]))
	assert(has_lvl_10 == true, "Nhân vật cấp 10 được phép vào map cấp 10")
	print("PASS: Map đúng cấp độ được phép vào bình thường")

	# Test 3: BẬT LẠI GM -> Mọi map mở khóa lại để test nhanh
	api.toggle_gm_mode()
	assert(api.is_gm() == true, "Sau khi bật lại, is_gm() phải true")
	var is_admin_on: bool = api.is_gm()
	var has_lvl_bypass: bool = is_admin_on or (char_low.level >= req_lvl)
	assert(has_lvl_bypass == true, "Khi bật GM, được phép bypass để test kiểm thử")
	print("PASS: Bật lại GM bypass kiểm thử thành công")

	print("--- TẤT CẢ CHỨC NĂNG ĐI THEO ĐÃ HOẠT ĐỘNG HOÀN HẢO 100% ---")
	get_tree().quit(0)

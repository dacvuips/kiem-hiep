extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU TEST PROFILE GUARD & ĐỒNG BỘ PHÍA SERVER ---")
	var success := true
	var ProfileGuardScript = preload("res://net/server/profile_guard.gd")

	# 1. Test ProfileGuard.merge với stage_stars
	var server_data := {
		"level": 10,
		"exp": 1000,
		"gold": 500,
		"stage_stars": {
			"0": 2,
			"1": 1
		}
	}

	var client_data := {
		"level": 10,
		"exp": 1000,
		"gold": 500,
		"stage_stars": {
			"0": 3,   # nâng từ 2 sao lên 3 sao
			"2": 2    # hoàn thành ải 2 đạt 2 sao
		}
	}

	var merged: Dictionary = ProfileGuardScript.merge(server_data, client_data, 0, false)
	var stars: Dictionary = merged.get("stage_stars", {})

	if stars.get("0") != 3:
		push_error("FAIL: stage 0 phải được cập nhật lên 3 sao! Thực tế: %s" % str(stars.get("0")))
		success = false
	else:
		print("PASS: stage 0 hợp nhất thành công lên 3 sao")

	if stars.get("1") != 1:
		push_error("FAIL: stage 1 phải giữ nguyên 1 sao từ server! Thực tế: %s" % str(stars.get("1")))
		success = false
	else:
		print("PASS: stage 1 giữ nguyên 1 sao từ server")

	if stars.get("2") != 2:
		push_error("FAIL: stage 2 phải được thêm mới 2 sao! Thực tế: %s" % str(stars.get("2")))
		success = false
	else:
		print("PASS: stage 2 thêm mới 2 sao")

	# 2. Test client gửi rỗng stage_stars thì server không được làm mất sao cũ
	var client_empty_stars := {
		"level": 10,
		"exp": 1000,
		"gold": 500
	}
	var merged_retain: Dictionary = ProfileGuardScript.merge(server_data, client_empty_stars, 0, false)
	var retained_stars: Dictionary = merged_retain.get("stage_stars", {})
	if retained_stars.get("0") != 2 or retained_stars.get("1") != 1:
		push_error("FAIL: Sao cũ từ server bị mất khi client gửi rỗng!")
		success = false
	else:
		print("PASS: Bảo vệ toàn vẹn sao của server khi client gửi thiếu trường stage_stars")

	# 3. Test max_hit của ProfileGuard hoạt động bình thường với môn phái và skill
	var test_prof := PlayerProfile.new()
	test_prof.display_name = "Thử Nghiệm Server"
	test_prof.level = 10
	test_prof.sect_id = "thieu_lam"
	var max_hit_val: float = ProfileGuardScript.max_hit(test_prof)
	if max_hit_val < ProfileGuardScript.MIN_CAP:
		push_error("FAIL: max_hit nhỏ hơn MIN_CAP (%f < %f)" % [max_hit_val, ProfileGuardScript.MIN_CAP])
		success = false
	else:
		print("PASS: ProfileGuard.max_hit tính toán chuẩn xác cho môn phái: %f" % max_hit_val)

	print("==========================================")
	if success:
		print("TẤT CẢ TEST ĐỒNG BỘ PROFILE GUARD SERVER ĐÃ PASS 100%!")
	else:
		push_error("CÓ LỖI XẢY RA TRONG TEST SERVER!")
	print("==========================================")
	get_tree().quit(0 if success else 1)

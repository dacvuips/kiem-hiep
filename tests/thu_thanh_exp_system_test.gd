extends SceneTree

const ThuThanhSkillData := preload("res://systems/challenge/thu_thanh_skill_data.gd")
const PlayerProfileScript := preload("res://systems/player_profile.gd")

func _init() -> void:
	print("--- BẮT ĐẦU KIỂM THỬ HỆ THỐNG EXP VÀ LEVEL THỦ THÀNH (ZOMBIES VS PLANTS) ---")
	test_thu_thanh_exp_and_skill_points()
	test_skill_upgrade_level_restriction()
	test_profile_persistence()
	print("--- TẤT CẢ KIỂM THỬ ĐÃ THÀNH CÔNG RỰC RỠ! ---")
	quit(0)

func test_thu_thanh_exp_and_skill_points() -> void:
	print("[TEST 1] Kiểm tra khởi tạo và tăng level nhận +10 điểm kỹ năng...")
	ThuThanhSkillData.load_progress()
	ThuThanhSkillData.set_thu_thanh_level(10)
	ThuThanhSkillData.set_thu_thanh_exp(0)
	ThuThanhSkillData.set_skill_points(10)

	var init_lvl := ThuThanhSkillData.get_thu_thanh_level()
	assert(init_lvl == 10, "Cấp khởi đầu phải là 10, nhận được: %d" % init_lvl)
	var init_pts := ThuThanhSkillData.get_skill_points()
	assert(init_pts == 10, "Điểm khởi đầu phải là 10, nhận được: %d" % init_pts)

	var next_exp := ThuThanhSkillData.get_exp_to_next_level(10)
	print("EXP cần để lên cấp từ 10: %d" % next_exp)

	# Thêm đủ EXP để tăng 1 cấp
	var res := ThuThanhSkillData.add_thu_thanh_exp(next_exp)
	assert(bool(res.get("leveled_up", false)) == true, "Phải lên cấp thành công")
	assert(int(res.get("new_level", 0)) == 11, "Cấp mới phải là 11")
	assert(int(res.get("levels_gained", 0)) == 1, "Số cấp tăng phải là 1")
	assert(int(res.get("skill_points_gained", 0)) == 10, "Số điểm kỹ năng nhận được phải là 10")

	var cur_pts := ThuThanhSkillData.get_skill_points()
	assert(cur_pts == 20, "Tổng điểm kỹ năng sau khi lên 1 cấp phải là 20 (10 + 10), nhận được: %d" % cur_pts)
	print("=> TEST 1 THÀNH CÔNG: Tăng 1 level cộng đúng 10 điểm kỹ năng!")

func test_skill_upgrade_level_restriction() -> void:
	print("[TEST 2] Kiểm tra ràng buộc: chỉ cộng điểm cho skill có req_level <= Cấp Thủ Thành...")
	# Giả lập người chơi đang ở Level 70
	ThuThanhSkillData.set_thu_thanh_level(70)
	ThuThanhSkillData.set_skill_points(50)
	ThuThanhSkillData.reset_skills()

	# 1. Kỹ năng cấp 10 (Thiếu Lâm - La Hán Trận, req_level = 10) <= 70 -> ĐƯỢC PHÉP CỘNG
	var check_tl := ThuThanhSkillData.can_upgrade_skill("thieu_lam")
	assert(bool(check_tl.get("can_upgrade", false)) == true, "Skill cấp 10 phải nâng cấp được khi ở level 70")
	var up_tl := ThuThanhSkillData.upgrade_skill("thieu_lam")
	assert(up_tl == true, "Nâng cấp skill cấp 10 phải thành công")
	assert(ThuThanhSkillData.get_skill_level("thieu_lam") == 2, "Level skill thieu_lam phải là 2")

	# 2. Tìm một kỹ năng cấp 70 và một kỹ năng cấp 80/90
	var all_skills := ThuThanhSkillData.get_all_skills()
	var skill_70_id := ""
	var skill_80_id := ""
	for s in all_skills:
		var req := int(s.get("req_level", 10))
		if req == 70 and skill_70_id == "":
			skill_70_id = str(s["id"])
		elif req == 80 and skill_80_id == "":
			skill_80_id = str(s["id"])

	print("Skill 70 mẫu: %s, Skill 80 mẫu: %s" % [skill_70_id, skill_80_id])

	if skill_70_id != "":
		# Level 70 được cộng điểm cho skill cấp 70
		var check_70 := ThuThanhSkillData.can_upgrade_skill(skill_70_id)
		assert(bool(check_70.get("can_upgrade", false)) == true, "Skill cấp 70 phải nâng cấp được khi người chơi level 70")
		var up_70 := ThuThanhSkillData.upgrade_skill(skill_70_id)
		assert(up_70 == true, "Cộng điểm cho skill cấp 70 phải thành công")

	if skill_80_id != "":
		# Level 70 KHÔNG ĐƯỢC cộng điểm cho skill cấp 80
		var check_80 := ThuThanhSkillData.can_upgrade_skill(skill_80_id)
		assert(bool(check_80.get("can_upgrade", false)) == false, "Skill cấp 80 KHÔNG ĐƯỢC PHÉP nâng cấp khi người chơi level 70")
		var up_80 := ThuThanhSkillData.upgrade_skill(skill_80_id)
		assert(up_80 == false, "Cố gắng cộng điểm cho skill cấp 80 khi ở level 70 phải bị từ chối")
		print("Lý do từ chối cộng skill cấp 80: %s" % str(check_80.get("reason", "")))

	print("=> TEST 2 THÀNH CÔNG: Đang level 70 chỉ cộng cho các skill level 70 trở xuống!")

func test_profile_persistence() -> void:
	print("[TEST 3] Kiểm tra lưu/nạp vào PlayerProfile...")
	var prof: PlayerProfile = PlayerProfileScript.new()
	prof.thu_thanh_level = 70
	prof.thu_thanh_exp = 350
	prof.thu_thanh_skill_points = 45

	var dict := prof.to_dict()
	assert(dict.get("thu_thanh_level", 0) == 70, "to_dict phải chứa thu_thanh_level = 70")
	assert(dict.get("thu_thanh_exp", 0) == 350, "to_dict phải chứa thu_thanh_exp = 350")
	assert(dict.get("thu_thanh_skill_points", 0) == 45, "to_dict phải chứa thu_thanh_skill_points = 45")

	var loaded := PlayerProfileScript.from_dict(dict)
	assert(loaded.thu_thanh_level == 70, "from_dict phải khôi phục thu_thanh_level = 70")
	assert(loaded.thu_thanh_exp == 350, "from_dict phải khôi phục thu_thanh_exp = 350")
	assert(loaded.thu_thanh_skill_points == 45, "from_dict phải khôi phục thu_thanh_skill_points = 45")
	print("=> TEST 3 THÀNH CÔNG: Dữ liệu PlayerProfile đồng bộ hoàn hảo!")

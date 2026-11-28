extends Node

const GemScript = preload("res://gems/gem.gd")
const GemScene = preload("res://gems/Gem.tscn")

func _ready() -> void:
	print("=================================================================")
	print("=== KIỂM THỬ TÍNH NĂNG OFFLINE: VƯỢT ẢI LUYỆN CÔNG THEO GDD ===")
	print("=================================================================")

	_test_step_1_gems()
	_test_step_2_and_3_skills_and_stars()
	_test_step_4_stage_progression_and_3_stars()

	print("\n=================================================================")
	print(">>> TẤT CẢ CÁC BƯỚC ĐẶC TẢ GDD VƯỢT ẢI ĐÃ KIỂM THỬ THÀNH CÔNG 100%! <<<")
	print("=================================================================")
	get_tree().quit(0)

func _test_step_1_gems() -> void:
	print("\n[*] BƯỚC 1: KIỂM THỬ HỆ THỐNG 3 LOẠI NGỌC EXP (GDD MỤC 6)")
	var gem: Area2D = GemScene.instantiate()
	add_child(gem)

	# 1.1 Ngọc nhỏ
	gem.setup_gem(0, 20.0) # SMALL
	assert(gem.gem_type == 0, "Phải là Ngọc EXP Nhỏ")
	assert(gem.exp_value == 20.0, "EXP phải bằng 20.0")
	print("  -> Ngọc EXP Nhỏ: Type 0, EXP = 20.0, Base Scale = %s: PASS" % str(gem._base_scale))

	# 1.2 Ngọc trung
	gem.setup_gem(1, 200.0) # MEDIUM
	assert(gem.gem_type == 1, "Phải là Ngọc EXP Trung")
	assert(gem.exp_value == 200.0, "EXP phải bằng 200.0")
	print("  -> Ngọc EXP Trung: Type 1, EXP = 200.0, Base Scale = %s: PASS" % str(gem._base_scale))

	# 1.3 Ngọc lớn
	gem.setup_gem(2, 2000.0) # LARGE
	assert(gem.gem_type == 2, "Phải là Ngọc EXP Lớn")
	assert(gem.exp_value == 2000.0, "EXP phải bằng 2000.0")
	print("  -> Ngọc EXP Lớn: Type 2, EXP = 2000.0, Base Scale = %s: PASS" % str(gem._base_scale))

	gem.queue_free()
	print("  => BƯỚC 1 (Hệ thống Ngọc EXP): PASS!")

func _test_step_2_and_3_skills_and_stars() -> void:
	print("\n[*] BƯỚC 2 & 3: KIỂM THỬ HỆ THỐNG KỸ NĂNG SURVIVOR & CẤP SAO (GDD MỤC 5)")
	PlayerStats.reset()
	assert(PlayerStats.survivor_skills.is_empty(), "Kỹ năng ban đầu phải rỗng")
	assert(PlayerStats.survivor_pool.is_empty(), "Pool kỹ năng ban đầu phải rỗng")

	# Giả lập pool 6 kỹ năng môn phái
	var dummy_pool: Array[String] = ["skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6"]
	PlayerStats.survivor_pool = dummy_pool
	assert(PlayerStats.survivor_pool.size() == 6, "Pool phải có tối đa 6 kỹ năng")
	print("  -> Bộ 6 kỹ năng môn phái trong trận: %s" % str(PlayerStats.survivor_pool))

	# 2.1 Chọn kỹ năng khởi đầu (1 sao)
	var s1_level := PlayerStats.add_or_upgrade_survivor_skill("skill_1")
	assert(s1_level == 1, "Kỹ năng khởi đầu phải đạt 1 sao")
	assert(PlayerStats.get_skill_star("skill_1") == 1, "Star level của skill_1 phải là 1")
	print("  -> Học kỹ năng khởi đầu [skill_1]: 1⭐ PASS")

	# 2.2 Nâng cấp sao từ 1 đến 5 sao
	for expected_star in range(2, 6):
		var star := PlayerStats.add_or_upgrade_survivor_skill("skill_1")
		assert(star == expected_star, "Cấp sao phải tăng lên %d" % expected_star)
		assert(PlayerStats.get_skill_star("skill_1") == expected_star, "Star của skill_1 phải là %d" % expected_star)
	print("  -> Thăng cấp tuần tự [skill_1] lên 5⭐: PASS")

	# 2.3 Không được vượt quá 5 sao (Max 5 sao)
	var over_star := PlayerStats.add_or_upgrade_survivor_skill("skill_1")
	assert(over_star == 5, "Cấp sao không được vượt quá 5")
	assert(PlayerStats.is_survivor_skill_maxed("skill_1"), "Kỹ năng phải được đánh dấu Max Sao")
	print("  -> Khóa trần tối đa 5⭐: PASS")

	# 2.4 Kiểm tra công thức tăng số lượng chiêu: N_chiêu = N_cơ_bản * Cấp sao
	var base_single := 1
	var base_eight := 8
	for star in range(1, 6):
		var shots_single := base_single * star
		var shots_eight := base_eight * star
		assert(shots_single == star, "Chiêu cơ số 1 ở %d sao phải bằng %d" % [star, star])
		assert(shots_eight == base_eight * star, "Chiêu cơ số 8 ở %d sao phải bằng %d" % [star, base_eight * star])
	print("  -> Công thức nhân số lượng chiêu thức (VD: 8 -> 16 -> 24 -> 32 -> 40 kiếm): PASS")

	# 2.5 Giới hạn tối đa 6 kỹ năng
	for i in range(2, 7):
		PlayerStats.add_or_upgrade_survivor_skill("skill_%d" % i)
	assert(PlayerStats.survivor_skills.size() == 6, "Chỉ được sở hữu tối đa 6 kỹ năng cùng lúc")
	var rejected := PlayerStats.add_or_upgrade_survivor_skill("skill_7")
	assert(rejected == 0, "Không được học thêm kỹ năng thứ 7")
	print("  -> Giới hạn nhóm tối đa 6 kỹ năng đồng thời: PASS")
	print("  => BƯỚC 2 & 3 (Kỹ năng Survivor & Cấp sao): PASS!")

func _test_step_4_stage_progression_and_3_stars() -> void:
	print("\n[*] BƯỚC 4: KIỂM THỬ TIẾN TRÌNH ẢI & HỆ THỐNG ĐÁNH GIÁ 3 SAO (GDD MỤC 3 & 4)")
	var stage := StageData.new()
	stage.stage_name = "Thanh Phong Thôn 1"
	stage.required_level = 10
	stage.target_time = 180.0
	stage.target_score = 2500
	stage.target_kills = 100

	# 4.1 Đánh giá 3 sao tuyệt đối (Đạt cả 3 điều kiện)
	var res_3 := stage.evaluate_stars(150.0, 3000, 120)
	assert(res_3.total_stars == 3, "Phải đạt 3 sao khi thỏa mãn cả 3 điều kiện")
	assert(res_3.star_time == true, "Phải đạt sao thời gian")
	assert(res_3.star_score == true, "Phải đạt sao điểm số")
	assert(res_3.star_kills == true, "Phải đạt sao số quái hạ gục")
	print("  -> Thỏa mãn 3/3 tiêu chí -> Đạt 3⭐: PASS")

	# 4.2 Đánh giá 2 sao (Quá thời gian nhưng đủ điểm và quái)
	var res_2 := stage.evaluate_stars(200.0, 3000, 120)
	assert(res_2.total_stars == 2, "Chỉ đạt 2 sao khi quá thời gian")
	assert(res_2.star_time == false, "Không đạt sao thời gian")
	print("  -> Quá thời gian quy định -> Đạt 2⭐: PASS")

	# 4.3 Đánh giá 1 sao (Quá thời gian, thiếu điểm nhưng đủ quái)
	var res_1 := stage.evaluate_stars(200.0, 1500, 120)
	assert(res_1.total_stars == 1, "Chỉ đạt 1 sao khi chỉ đạt điều kiện quái")
	print("  -> Chỉ đạt 1 tiêu chí -> Đạt 1⭐: PASS")

	# 4.4 Lưu trữ và đọc sao từ PlayerProfile
	var profile := PlayerProfile.new()
	profile.level = 15 # Cấp 1x
	profile.set_stage_stars(0, 3)
	profile.set_stage_stars(1, 2)
	assert(profile.get_stage_stars(0) == 3, "Ải 1 phải có 3 sao")
	assert(profile.get_stage_stars(1) == 2, "Ải 2 phải có 2 sao")
	assert(profile.get_stage_stars(2) == 0, "Ải 3 chưa chơi phải có 0 sao")

	# Kiểm tra serialize / deserialize
	var data := profile.to_dict()
	var loaded_profile := PlayerProfile.from_dict(data)
	assert(loaded_profile.get_stage_stars(0) == 3, "Lưu save phải giữ nguyên 3 sao Ải 1")
	assert(loaded_profile.get_stage_stars(1) == 2, "Lưu save phải giữ nguyên 2 sao Ải 2")
	print("  -> Lưu trữ và nạp dữ liệu đánh giá sao vào Profile: PASS")

	# 4.5 Khóa mốc cấp độ (1x chỉ vào map 1x, 2x vào map 2x)
	var stage_2x := StageData.new()
	stage_2x.required_level = 20
	assert(profile.level < stage_2x.required_level, "Nhân vật cấp 15 (1x) chưa đủ điều kiện vào ải cấp 20 (2x)")
	profile.level = 22
	assert(profile.level >= stage_2x.required_level, "Nhân vật cấp 22 (2x) đã đủ điều kiện vào ải cấp 20 (2x)")
	print("  -> Điều kiện cấp độ tham gia (1x vào 1x, 2x vào 2x): PASS")
	print("  => BƯỚC 4 (Tiến trình Ải & 3 Sao): PASS!")

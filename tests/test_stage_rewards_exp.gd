extends Node

func _ready() -> void:
	print("=== KIỂM THỬ PHẦN THƯỞNG EXP KHIÊU CHIẾN SƠN MÔN ===")
	
	# 1. Kiểm tra previews
	var stages: Array[StageData] = GameManager.get_all_stages()
	assert(stages.size() >= 1, "Phải nạp được ít nhất 1 ải")
	print("Đã nạp %d ải." % stages.size())

	for i in mini(stages.size(), 12):
		var st: StageData = stages[i]
		var previews := StageRewards.get_previews_for_stage(st, i)
		assert(previews.size() >= 1, "Mỗi ải phải có preview phần thưởng")
		var exp_prev: Dictionary = previews[0]
		assert(exp_prev.get("id") == "exp", "Phần thưởng đầu tiên phải là EXP")
		assert(exp_prev.get("icon_path") == StageRewards.ICON_EXP, "Icon EXP phải hợp lệ")
		print("Ải %2d (%-25s): Thưởng EXP: %-10s | %s" % [
			i + 1, st.stage_name, exp_prev.get("badge"), exp_prev.get("tooltip").replace("\n", " ")
		])

	# 2. Test trao phần thưởng thực tế và cộng exp vào profile thật
	var p := PlayerProfile.new()
	p.display_name = "Thử Nghiệm"
	p.level = 10
	p.current_exp = 0
	var old_level := p.level
	var old_exp := p.current_exp
	var exp_need := p.get_exp_to_next_level()
	print("\n--- Test Profile trước khi nhận thưởng ---")
	print("Nhân vật: %s | Cấp: %d | EXP: %d/%d" % [p.display_name, p.level, p.current_exp, exp_need])

	var res := StageRewards.roll_stage_rewards(stages[0], p, 0)
	var exp_reward: int = res.get("exp", 0)
	assert(exp_reward >= 40000 and exp_reward <= 100000, "EXP Ải 1 phải trong khoảng 40.000 ~ 100.000 (x20)")
	print("Vượt Ải 1 thành công! Nhận được: +%d EXP" % exp_reward)
	print("Profile sau khi nhận thưởng:")
	print("Cấp: %d (Tăng +%d cấp) | EXP: %d/%d" % [
		p.level, p.level - old_level, p.current_exp, p.get_exp_to_next_level()
	])
	assert(p.current_exp > old_exp or p.level > old_level, "EXP hoặc Cấp của nhân vật phải tăng lên")

	print("\nKIỂM THỬ PHẦN THƯỞNG EXP VƯỢT ẢI THÀNH CÔNG 100%!")
	get_tree().quit(0)

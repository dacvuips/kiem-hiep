extends SceneTree

func _init() -> void:
	print("--- TEST SYNERGY VÕ ĐANG IN ENGINE ---")
	var sect: SectDefinition = load("res://systems/sect/data/vo_dang.tres")
	assert(sect != null, "Load vo_dang.tres failed")

	var profile := PlayerProfile.new()
	profile.sect_id = "vo_dang"
	
	# Tìm các skill
	var no_loi: SkillDefinition
	var thien_dia: SkillDefinition
	var nhan_kiem: SkillDefinition
	var tao_hoa: SkillDefinition
	
	for s in sect.skills:
		if s.id == "vo_dang_no_loi_chi":
			no_loi = s
		elif s.id == "vo_dang_thien_dia_vo_cuc":
			thien_dia = s
		elif s.id == "vo_dang_nhan_kiem_hop_nhat":
			nhan_kiem = s
		elif s.id == "vo_dang_tao_hoa_thai_thanh":
			tao_hoa = s
			
	assert(no_loi != null and thien_dia != null and nhan_kiem != null and tao_hoa != null, "Skills not found")
	
	# Lúc chưa học gì: hỗ trợ = 0%
	var sup0 := thien_dia.get_support_percent_from_other_skills(sect.skills, profile)
	print("Thiên Địa Vô Cực khi chưa học Nộ Lôi Chỉ: ", sup0, "%")
	assert(sup0 == 0.0, "Support must be 0% when unlearned")
	
	# Học Nộ Lôi Chỉ cấp 20
	profile.skill_levels["vo_dang_no_loi_chi"] = 20
	var sup_td := thien_dia.get_support_percent_from_other_skills(sect.skills, profile)
	print("Thiên Địa Vô Cực khi học Nộ Lôi Chỉ lv 20: +", sup_td, "% (Kỳ vọng: 110%)")
	assert(is_equal_approx(sup_td, 110.0), "Thiên Địa Vô Cực must receive +110% from Nộ Lôi Chỉ")
	
	# Học thêm Bác Cấp Nhi Phục lv 20 (+120%) và Vô Ngã Vô Kiếm lv 20 (+130%)
	profile.skill_levels["vo_dang_bac_cap_nhi_phuc"] = 20
	profile.skill_levels["vo_dang_vo_nga_vo_kiem"] = 20
	var sup_td_full := thien_dia.get_support_percent_from_other_skills(sect.skills, profile)
	print("Thiên Địa Vô Cực khi học full 3 skill hỗ trợ lv 20: +", sup_td_full, "% (Kỳ vọng: 360%)")
	assert(is_equal_approx(sup_td_full, 360.0), "Thiên Địa Vô Cực must receive +360% total")
	
	# Học full hỗ trợ cho Tạo Hóa Thái Thanh 150: Nộ Lôi (92%) + Bác Cấp (100%) + Vô Ngã (108%) + Thiên Địa (60%) = 360%
	profile.skill_levels["vo_dang_thien_dia_vo_cuc"] = 20
	var sup_th := tao_hoa.get_support_percent_from_other_skills(sect.skills, profile)
	print("Tạo Hóa Thái Thanh khi học full 4 skill hỗ trợ: +", sup_th, "% (Kỳ vọng: 360%)")
	assert(is_equal_approx(sup_th, 360.0), "Tạo Hóa Thái Thanh must receive +360% total")
	
	# Test Nhánh Kiếm: Học Thương Hải Minh Nguyệt lv 20 (+60%) + Tam Hoàn Thao Nguyệt lv 20 (+125%) = 185% cho Nhân Kiếm Hợp Nhất
	profile.skill_levels["vo_dang_thuong_hai_minh_nguyet"] = 20
	profile.skill_levels["vo_dang_tam_hoan_thao_nguyet"] = 20
	var sup_nk := nhan_kiem.get_support_percent_from_other_skills(sect.skills, profile)
	print("Nhân Kiếm Hợp Nhất khi học Thương Hải lv20 + Tam Hoàn lv20: +", sup_nk, "% (Kỳ vọng: 185%)")
	assert(is_equal_approx(sup_nk, 185.0), "Nhân Kiếm Hợp Nhất must receive +185% total")

	print("\n>>> TẤT CẢ TEST TÍNH TOÁN & CỘNG DỒN HỖ TRỢ SYNERGY VÕ ĐANG ĐÃ PASS 100%! <<<")
	quit(0)

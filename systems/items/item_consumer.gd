class_name ItemConsumer
extends RefCounted

## Xử lý dùng vật phẩm (Item Usage / Consumption / Open Chests):
## Áp dụng cho toàn bộ các vật phẩm tiêu hao, rương báu, lễ hộp, đan dược, bí kíp, lệnh bài...
## Hoạt động được ở cả trong trận đấu (Map) và ngoài sảnh (CharacterHub).

## BẢNG 15 BÍ KÍP 180 CỦA 15 MÔN PHÁI (6_1_18001 -> 6_1_18015)
const BIKIP_180_MAP: Dictionary = {
	"6_1_18001": {"sect": "thieu_lam", "skill": "thieu_lam_kim_quyen_la_han", "name": "Kim Quyền La Hán", "sect_name": "Thiếu Lâm"},
	"6_1_18002": {"sect": "thien_vuong_bang", "skill": "thien_vuong_chinh_chien_bat_phuong", "name": "Chinh Chiến Bát Phương", "sect_name": "Thiên Vương"},
	"6_1_18003": {"sect": "ngu_doc_giao", "skill": "ngu_doc_sam_la_doc_hai", "name": "Sâm La Độc Hải", "sect_name": "Ngũ Độc"},
	"6_1_18004": {"sect": "duong_mon", "skill": "duong_mon_hap_tinh_tran", "name": "Hấp Tinh Trận", "sect_name": "Đường Môn"},
	"6_1_18005": {"sect": "nga_mi", "skill": "nga_mi_ba_la_tam_kinh", "name": "Ba La Tâm Kinh", "sect_name": "Nga Mi"},
	"6_1_18006": {"sect": "thuy_yen_mon", "skill": "thuy_yen_huyen_bang_vo_tac", "name": "Huyền Băng Vô Tắc", "sect_name": "Thúy Yên"},
	"6_1_18007": {"sect": "cai_bang", "skill": "cai_bang_o_y_quyet", "name": "Ô Y Quyết", "sect_name": "Cái Bang"},
	"6_1_18008": {"sect": "thien_nhan_giao", "skill": "thien_nhan_liet_hoa_phan_thien", "name": "Liệt Hỏa Phần Thiên", "sect_name": "Thiên Nhẫn"},
	"6_1_18009": {"sect": "vo_dang", "skill": "vo_dang_chan_vo_that_tiet", "name": "Chân Võ Thất Tiết", "sect_name": "Võ Đang"},
	"6_1_18010": {"sect": "con_lon", "skill": "con_lon_thien_cuong_khi_kinh", "name": "Thiên Cương Khí Kính", "sect_name": "Côn Lôn"},
	"6_1_18011": {"sect": "hoa_son", "skill": "hoa_son_cuu_kiem_hop_nhat", "name": "Cửu Kiếm Hợp Nhất", "sect_name": "Hoa Sơn"},
	"6_1_18012": {"sect": "vu_hon", "skill": "vu_hon_tru_gian_diet_ninh", "name": "Trừ Gian Diệt Nịnh", "sect_name": "Vũ Hồn"},
	"6_1_18013": {"sect": "tieu_dao", "skill": "tieu_dao_thap_bo_nhat_sat", "name": "Thập Bộ Nhất Sát", "sect_name": "Tiêu Dao"},
	"6_1_18014": {"sect": "duong_gia", "skill": "duong_gia_bon_lang_thuong", "name": "Bôn Lang Thương", "sect_name": "Dương Môn"},
	"6_1_18015": {"sect": "minh_giao", "skill": "minh_giao_loi_dinh_nhat_kich", "name": "Lôi Đình Nhất Kích", "sect_name": "Minh Giáo"},
}

static func is_chest_or_box(item: ItemInstance) -> bool:
	if item == null:
		return false
	var mid := item.misc_id
	if mid in ["6_1_2339", "6_1_2805", "item_goldenbox", "ky_tui_thuoc_lac", "ky_tui_lenh_bai_datau"]:
		return true
	var name_lower := item.get_display_name().to_lower()
	return name_lower.contains("rương") or name_lower.contains("hộp") or name_lower.contains("túi") or name_lower.contains("gói")

static func get_action_label(item: ItemInstance) -> String:
	if item == null:
		return "Dùng"
	if not item.is_misc():
		return "Trang bị"
	if is_chest_or_box(item):
		var name_lower := item.get_display_name().to_lower()
		if name_lower.contains("rương"):
			return "Mở Rương"
		elif name_lower.contains("hộp"):
			return "Mở Hộp"
		elif name_lower.contains("túi"):
			return "Mở Túi"
		return "Dùng"
	return "Dùng"

static func _fmt(n: int) -> String:
	var s := str(n)
	var res := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0 and s[i - 1] != "-":
			res = "." + res
	return res

static func _consume_one(profile: PlayerProfile, item: ItemInstance, index: int) -> void:
	if item.count > 1:
		item.count -= 1
	else:
		profile.inventory.remove_at(index)

static func use_item(profile: PlayerProfile, item: ItemInstance, player: Node = null, host: Node = null) -> Dictionary:
	if profile == null or item == null:
		return {"ok": false, "message": "Thông tin vật phẩm không hợp lệ."}
	
	var index := profile.inventory.find(item)
	if index < 0:
		return {"ok": false, "message": "Vật phẩm không còn trong hành trang."}
	
	var mid := item.misc_id
	var item_name := item.get_display_name()

	# 1. SÁT THỦ GIẢN LỄ HỘP (6_1_2339)
	if mid == "6_1_2339":
		_consume_one(profile, item, index)
		var gained_exp := randi_range(800000, 2000000)
		var gained_gold := randi_range(50000, 200000)
		profile.add_exp(gained_exp)
		profile.gold += gained_gold
		
		# Tặng 1 Thủy tinh hoặc Tinh Hồng Bảo Thạch ngẫu nhiên
		var tt_pool := ["4_238_1", "4_239_1", "4_240_1", "4_353_1"]
		var tt_id: String = tt_pool.pick_random()
		var tt_it := ItemGenerator.generate_misc(tt_id)
		var tt_name := "Bảo Thạch"
		if tt_it != null:
			tt_name = tt_it.get_display_name()
			profile.add_item(tt_it)
		
		# Tặng 1 Lệnh bài Thủy Tặc hoặc Phong Lăng Độ
		var lb_pool := ["6_1_2745", "4_489_1"]
		var lb_id: String = lb_pool.pick_random()
		var lb_it := ItemGenerator.generate_misc(lb_id)
		var lb_name := "Lệnh Bài"
		if lb_it != null:
			lb_name = lb_it.get_display_name()
			profile.add_item(lb_it)

		return {
			"ok": true,
			"message": "Mở [Sát Thủ Giản lễ hộp] thành công!\n+ %s EXP\n+ %s Lượng\n+ 1 %s\n+ 1 %s" % [
				_fmt(gained_exp),
				_fmt(gained_gold),
				tt_name,
				lb_name
			]
		}

	# 2. TÚI THUỐC LẮC (ky_tui_thuoc_lac)
	if mid == "ky_tui_thuoc_lac":
		_consume_one(profile, item, index)
		# Tặng 5 Thiên Sơn Bảo Lộ (6_1_72)
		var tsbl := ItemGenerator.generate_misc("6_1_72", 0, 0, 5)
		if tsbl != null:
			profile.add_item(tsbl)
		# Tặng 2 Tiên Thảo Lộ đặc biệt (6_1_1181)
		var ttl := ItemGenerator.generate_misc("6_1_1181", 0, 0, 2)
		if ttl != null:
			profile.add_item(ttl)
		# Tặng 5 Hồi Thành Phù (6_1_1083)
		var htp := ItemGenerator.generate_misc("6_1_1083", 0, 0, 5)
		if htp != null:
			profile.add_item(htp)
		return {
			"ok": true,
			"message": "Mở [Túi Thuốc Lắc] thành công!\n+ 5 x Thiên Sơn Bảo Lộ\n+ 2 x Tiên Thảo Lộ đặc biệt\n+ 5 x Hồi Thành Phù"
		}

	# 3. TÚI LỆNH BÀI DÃ TẨU (ky_tui_lenh_bai_datau)
	if mid == "ky_tui_lenh_bai_datau":
		_consume_one(profile, item, index)
		var lb_it := ItemGenerator.generate_misc("ky_datau_hoanthanh", 0, 0, 5)
		if lb_it != null:
			profile.add_item(lb_it)
		return {
			"ok": true,
			"message": "Mở [Túi Lệnh Bài Dã Tẩu] nhận được 5 x Lệnh Bài Hoàn Thành Dã Tẩu."
		}

	# 4. LỆNH BÀI HOÀN THÀNH DÃ TẨU (ky_datau_hoanthanh)
	if mid == "ky_datau_hoanthanh":
		_consume_one(profile, item, index)
		var exp_gain := 500000
		var gold_gain := 50000
		profile.add_exp(exp_gain)
		profile.gold += gold_gain
		profile.prestige += 20
		profile.fuyuan += 10
		return {
			"ok": true,
			"message": "Sử dụng [Lệnh Bài Hoàn Thành Dã Tẩu] hoàn tất nhiệm vụ!\n+ %s EXP\n+ %s Lượng\n+ 20 Danh Vọng\n+ 10 Phúc Duyên" % [
				_fmt(exp_gain),
				_fmt(gold_gain)
			]
		}

	# 5. THIÊN NIÊN TRẦN LỘ (ky_thien_nien_tran_lo)
	if mid == "ky_thien_nien_tran_lo":
		_consume_one(profile, item, index)
		var max_st: int = profile.max_stamina if profile.max_stamina > 0 else 1918
		profile.max_stamina = max_st + 50
		profile.stamina = profile.max_stamina
		profile.add_exp(1000000)
		return {
			"ok": true,
			"message": "Uống [Thiên Niên Trần Lộ]! Thể Lực hồi phục 100%, tăng vĩnh viễn +50 Thể Lực tối đa và nhận +1.000.000 EXP."
		}

	# 6. BÀN NHƯỢC TÂM KINH (6_1_12)
	if mid == "6_1_12":
		_consume_one(profile, item, index)
		profile.skill_points += 1
		profile.potential_points += 5
		return {
			"ok": true,
			"message": "Lĩnh ngộ [Bàn Nhược Tâm Kinh]! Nhận thêm +1 Điểm Kỹ Năng và +5 Điểm Tiềm Năng."
		}

	# 7. ĐẠI THÀNH BÍ KÍP 90 (6_1_2424)
	if mid == "6_1_2424":
		_consume_one(profile, item, index)
		profile.skill_points += 2
		profile.add_exp(2000000)
		return {
			"ok": true,
			"message": "Luyện thành [Đại Thành Bí Kíp 90]! Nhận thêm +2 Điểm Kỹ Năng và +2.000.000 EXP."
		}

	# 7.1. ĐẠI THÀNH BÍ KÍP 120 (6_1_2425)
	if mid == "6_1_2425":
		_consume_one(profile, item, index)
		profile.skill_points += 3
		profile.add_exp(3000000)
		return {
			"ok": true,
			"message": "Luyện thành [Đại Thành Bí Kíp 120]! Nhận thêm +3 Điểm Kỹ Năng và +3.000.000 EXP."
		}

	# 7.2. ĐẠI THÀNH BÍ KÍP 150 (6_1_30446)
	if mid == "6_1_30446":
		_consume_one(profile, item, index)
		profile.skill_points += 5
		profile.add_exp(5000000)
		return {
			"ok": true,
			"message": "Luyện thành [Đại Thành Bí Kíp 150]! Nhận thêm +5 Điểm Kỹ Năng và +5.000.000 EXP."
		}

	# 8. TRỐNG KHẢI HOÀN (6_1_2309)
	if mid == "6_1_2309":
		_consume_one(profile, item, index)
		profile.add_exp(1000000)
		profile.prestige += 30
		return {
			"ok": true,
			"message": "Đánh vang [Trống Khải Hoàn]! Khí thế ngút trời, nhận +1.000.000 EXP và +30 Danh Vọng."
		}

	# 9. THƯ ĐẶC XÁ TRIỀU ĐÌNH (6_1_1375)
	if mid == "6_1_1375":
		_consume_one(profile, item, index)
		if "pk_value" in profile:
			profile.set("pk_value", 0)
		profile.prestige += 50
		return {
			"ok": true,
			"message": "Triều đình ban chiếu đặc xá! Xóa sạch điểm PK và gia tăng +50 Danh Vọng."
		}

	# 10. QUẾ HOA TỬU (6_1_125)
	if mid == "6_1_125":
		_consume_one(profile, item, index)
		var max_st: int = profile.max_stamina if profile.max_stamina > 0 else 1918
		profile.stamina = max_st
		profile.add_exp(300000)
		return {
			"ok": true,
			"message": "Thưởng thức [Quế Hoa Tửu]! Thể lực hồi đầy và nhận +300.000 EXP."
		}

	# 11. VIÊM ĐẾ BÍ BẢO / RƯƠNG VIÊM ĐẾ (6_1_2805)
	if mid == "6_1_2805":
		_consume_one(profile, item, index)
		var gained_exp := randi_range(1500000, 3500000)
		var gained_gold := randi_range(150000, 350000)
		profile.add_exp(gained_exp)
		profile.gold += gained_gold
		var frags := randi_range(1, 3)
		for i in frags:
			var frag_it := ItemGenerator.generate_misc("6_1_1685")
			if frag_it != null:
				profile.add_item(frag_it)
		var tt_ids := ["4_238_1", "4_239_1", "4_240_1"]
		var tt_it := ItemGenerator.generate_misc(tt_ids.pick_random())
		var tt_name := "Thủy Tinh"
		if tt_it != null:
			tt_name = tt_it.get_display_name()
			profile.add_item(tt_it)
		return {
			"ok": true,
			"message": "Mở [Viêm Đế Bí Bảo] thành công!\n+ %s EXP\n+ %s Lượng\n+ %d Mảnh Đồ Đằng\n+ 1 %s" % [
				_fmt(gained_exp),
				_fmt(gained_gold),
				frags,
				tt_name
			]
		}

	# 12. RƯƠNG VÀNG / ITEM_GOLDENBOX
	if mid == "item_goldenbox" or item_name.to_lower().contains("rương vàng"):
		_consume_one(profile, item, index)
		var gained_exp := randi_range(1000000, 3000000)
		var gained_gold := randi_range(100000, 300000)
		profile.add_exp(gained_exp)
		profile.gold += gained_gold
		var tt_ids := ["4_238_1", "4_239_1", "4_240_1", "4_353_1"]
		var tt_it := ItemGenerator.generate_misc(tt_ids.pick_random())
		var tt_name := "Bảo Thạch"
		if tt_it != null:
			tt_name = tt_it.get_display_name()
			profile.add_item(tt_it)
		return {
			"ok": true,
			"message": "Mở [Rương Vàng] thành công!\n+ %s EXP\n+ %s Lượng\n+ 1 %s" % [
				_fmt(gained_exp),
				_fmt(gained_gold),
				tt_name
			]
		}

	# 12.6. RƯƠNG BÁCH THÚ SƠN TRANG (ruong_bach_thu_son_trang)
	if mid == "ruong_bach_thu_son_trang":
		_consume_one(profile, item, index)
		return open_ruong_bach_thu(profile)

	# 13. THỦY TINH & TINH HỒNG BẢO THẠCH (4_238_1, 4_239_1, 4_240_1, 4_353_1)
	if mid in ["4_238_1", "4_239_1", "4_240_1", "4_353_1"]:
		if host != null:
			var script_comp: GDScript = load("res://ui/shop/compound_window.gd") as GDScript
			if script_comp != null:
				script_comp.open(host, Callable(), profile)
				return {"ok": true, "message": "Đã mở Tiệm Ép Đồ & Nâng Cấp Trang Bị."}
		return {"ok": true, "message": "Thủy tinh & Tinh Hồng Bảo Thạch dùng để ép trang bị tại Tiệm Ép Đồ."}

	# 14. PHÚC DUYÊN LỘ (6_1_122, 6_1_123, 6_1_124)
	if PotionEffect.is_fuyuan_potion(item):
		var fy := PotionEffect.get_fuyuan_amount(item)
		_consume_one(profile, item, index)
		profile.fuyuan += fy
		return {
			"ok": true,
			"message": "Đã dùng %s (+%d Điểm Phúc Duyên). Hiện có: %d điểm." % [item_name, fy, profile.fuyuan]
		}

	# 15. CÁC LOẠI LỆNH BÀI (Phong Lăng Độ, Thủy Tặc, Viêm Đế)
	if mid in ["4_489_1", "6_1_2745", "6_1_1617"]:
		_consume_one(profile, item, index)
		var exp_gain := 400000
		var gold_gain := 40000
		profile.add_exp(exp_gain)
		profile.gold += gold_gain
		profile.prestige += 15
		return {
			"ok": true,
			"message": "Sử dụng %s thành công!\n+ %s EXP\n+ %s Lượng\n+ 15 Danh Vọng" % [
				item_name,
				_fmt(exp_gain),
				_fmt(gold_gain)
			]
		}

	# 16. PHÙ DỊCH CHUYỂN (Thần Hành Phù, Thổ Địa Phù, Hồi Thành Phù)
	if mid in ["6_1_1083", "6_1_1266", "6_1_438"]:
		if mid != "6_1_438": # Thổ địa phù dùng vô hạn
			_consume_one(profile, item, index)
		var max_st: int = profile.max_stamina if profile.max_stamina > 0 else 1918
		profile.stamina = max_st
		profile.add_exp(150000)
		return {
			"ok": true,
			"message": "Sử dụng %s thành công! Thể lực đã hồi phục đầy đủ." % item_name
		}

	# 17. TIÊN THẢO LỘ & THIÊN SƠN BẢO LỘ (6_1_1181, 6_1_71, 6_1_72...)
	if mid in ["6_1_1181", "6_1_71", "6_1_1765", "6_1_113", "6_1_72", "6_0_70"]:
		if player != null and PotionEffect.usable(item):
			if PotionEffect.consume(profile, player, item):
				return {"ok": true, "message": "Đã dùng %s kích hoạt hiệu ứng dược thảo!" % item_name}
		# Nếu dùng ở Hub (không có player node)
		_consume_one(profile, item, index)
		var exp_gain := 1000000 if mid in ["6_1_1181", "6_1_1765"] else 400000
		profile.add_exp(exp_gain)
		profile.fuyuan += 20
		return {
			"ok": true,
			"message": "Uống %s thành công!\n+ %s EXP\n+ 20 Phúc Duyên" % [
				item_name,
				_fmt(exp_gain)
			]
		}

	# 18. BÌNH HỒI MÁU / NỘI LỰC THÔNG THƯỜNG
	if PotionEffect.usable(item):
		if player != null:
			if PotionEffect.consume(profile, player, item):
				return {"ok": true, "message": "Đã dùng %s hồi phục sinh khí." % item_name}
			return {"ok": false, "message": "Không thể dùng lúc này."}
		else:
			# Dùng ở Hub: Hồi đầy thể lực
			_consume_one(profile, item, index)
			var max_st: int = profile.max_stamina if profile.max_stamina > 0 else 1918
			profile.stamina = max_st
			return {"ok": true, "message": "Đã dùng %s hồi phục Thể Lực." % item_name}

		# 18.5. BÍ KÍP VÕ CÔNG (Bí Kíp - Hạo Nhiên Chi Khí hoặc Bí Kíp Môn Phái)
	if mid == "6_1_18016" or item_name.begins_with("Bí Kíp - Hạo Nhiên Chi Khí"):
		if profile.sect_id != "hoa_son":
			return {"ok": false, "message": "Bí kíp này là tuyệt học của phái Hoa Sơn, môn phái khác không thể lĩnh hội!"}
		if profile.level < 120:
			return {"ok": false, "message": "Yêu cầu đẳng cấp 120 trở lên mới có thể lĩnh hội tâm pháp Hạo Nhiên Chi Khí!"}
		
		var cur_lvl: int = profile.get_skill_level("hoa_son_hao_nhien_chi_khi")
		if cur_lvl >= 20:
			return {"ok": false, "message": "Võ công [Hạo Nhiên Chi Khí] đã tu luyện đến cảnh giới tối đa (Cấp 20)!"}
		
		_consume_one(profile, item, index)
		var new_lvl := cur_lvl + 1
		profile.skill_levels["hoa_son_hao_nhien_chi_khi"] = new_lvl
		profile.add_exp(1000000)
		return {
			"ok": true,
			"message": "Lĩnh hội bí kíp thành công! Kỹ năng [Hạo Nhiên Chi Khí] đạt Cấp %d/20!\n+ 1.000.000 EXP" % new_lvl
		}

		# 18.6. BÍ KÍP VÕ CÔNG TIÊU DAO (Bí Kíp - Mai Danh Ẩn Tính)
	if mid == "6_1_18017" or item_name.begins_with("Bí Kíp - Mai Danh Ẩn Tính"):
		if profile.sect_id != "tieu_dao":
			return {"ok": false, "message": "Bí kíp này là tuyệt học của phái Tiêu Dao, môn phái khác không thể lĩnh hội!"}
		if profile.level < 120:
			return {"ok": false, "message": "Yêu cầu đẳng cấp 120 trở lên mới có thể lĩnh hội dị kỹ Mai Danh Ẩn Tính!"}
		
		var cur_lvl: int = profile.get_skill_level("tieu_dao_mai_danh_an_tinh")
		if cur_lvl >= 20:
			return {"ok": false, "message": "Võ công [Mai Danh Ẩn Tính] đã tu luyện đến cảnh giới tối đa (Cấp 20)!"}
		
		_consume_one(profile, item, index)
		var new_lvl := cur_lvl + 1
		profile.skill_levels["tieu_dao_mai_danh_an_tinh"] = new_lvl
		profile.add_exp(1000000)
		return {
			"ok": true,
			"message": "Lĩnh hội bí kíp thành công! Kỹ năng [Mai Danh Ẩn Tính] đạt Cấp %d/20!\n+ 1.000.000 EXP" % new_lvl
		}

		# 18.7. BÍ KÍP VÕ CÔNG DƯƠNG MÔN (Bí Kíp - Ngạo Huyết Chiến Ý)
	if mid == "6_1_18018" or item_name.begins_with("Bí Kíp - Ngạo Huyết Chiến Ý"):
		if profile.sect_id != "duong_gia":
			return {"ok": false, "message": "Bí kíp này là tuyệt học của phái Dương Môn, môn phái khác không thể lĩnh hội!"}
		if profile.level < 120:
			return {"ok": false, "message": "Yêu cầu đẳng cấp 120 trở lên mới có thể lĩnh hội dị kỹ Ngạo Huyết Chiến Ý!"}
		
		var cur_lvl: int = profile.get_skill_level("duong_gia_ngao_huyet_chien_y")
		if cur_lvl >= 20:
			return {"ok": false, "message": "Võ công [Ngạo Huyết Chiến Ý] đã tu luyện đến cảnh giới tối đa (Cấp 20)!"}
		
		_consume_one(profile, item, index)
		var new_lvl := cur_lvl + 1
		profile.skill_levels["duong_gia_ngao_huyet_chien_y"] = new_lvl
		profile.add_exp(1000000)
		return {
			"ok": true,
			"message": "Lĩnh hội bí kíp thành công! Kỹ năng [Ngạo Huyết Chiến Ý] đạt Cấp %d/20!\n+ 1.000.000 EXP" % new_lvl
		}

		# 18.8. BÍ KÍP VÕ CÔNG VŨ HỒN (Bí Kíp - Tận Trung Báo Quốc)
	if mid == "6_1_18019" or item_name.begins_with("Bí Kíp - Tận Trung Báo Quốc"):
		if profile.sect_id != "vu_hon":
			return {"ok": false, "message": "Bí kíp này là tuyệt học của phái Vũ Hồn, môn phái khác không thể lĩnh hội!"}
		if profile.level < 120:
			return {"ok": false, "message": "Yêu cầu đẳng cấp 120 trở lên mới có thể lĩnh hội dị kỹ Tận Trung Báo Quốc!"}
		
		var cur_lvl: int = profile.get_skill_level("vu_hon_tan_trung_bao_quoc")
		if cur_lvl >= 20:
			return {"ok": false, "message": "Võ công [Tận Trung Báo Quốc] đã tu luyện đến cảnh giới tối đa (Cấp 20)!"}
		
		_consume_one(profile, item, index)
		var new_lvl := cur_lvl + 1
		profile.skill_levels["vu_hon_tan_trung_bao_quoc"] = new_lvl
		profile.add_exp(1000000)
		return {
			"ok": true,
			"message": "Lĩnh hội bí kíp thành công! Kỹ năng [Tận Trung Báo Quốc] đạt Cấp %d/20!\n+ 1.000.000 EXP" % new_lvl
		}

	# 18.9. BÍ KÍP VÕ CÔNG MINH GIÁO (Bí Kíp - Vạn Lý Liêu Nguyên)
	if mid == "6_1_18020" or item_name.begins_with("Bí Kíp - Vạn Lý Liêu Nguyên"):
		if profile.sect_id != "minh_giao":
			return {"ok": false, "message": "Bí kíp này là tuyệt học của phái Minh Giáo, môn phái khác không thể lĩnh hội!"}
		if profile.level < 120:
			return {"ok": false, "message": "Yêu cầu đẳng cấp 120 trở lên mới có thể lĩnh hội dị kỹ Vạn Lý Liêu Nguyên!"}
		
		var cur_lvl: int = profile.get_skill_level("minh_giao_van_ly_lieu_nguyen")
		if cur_lvl >= 20:
			return {"ok": false, "message": "Võ công [Vạn Lý Liêu Nguyên] đã tu luyện đến cảnh giới tối đa (Cấp 20)!"}
		
		_consume_one(profile, item, index)
		var new_lvl := cur_lvl + 1
		profile.skill_levels["minh_giao_van_ly_lieu_nguyen"] = new_lvl
		profile.add_exp(1000000)
		return {
			"ok": true,
			"message": "Lĩnh hội bí kíp thành công! Kỹ năng [Vạn Lý Liêu Nguyên] đạt Cấp %d/20!\n+ 1.000.000 EXP" % new_lvl
		}

	# 18.10. TOÀN BỘ BÍ KÍP 180 (6_1_18001 -> 6_1_18015 của 15 Môn Phái)
	if BIKIP_180_MAP.has(mid):
		var info: Dictionary = BIKIP_180_MAP[mid]
		var target_sect: String = str(info["sect"])
		var target_skill: String = str(info["skill"])
		var sk_name: String = str(info["name"])
		var s_name: String = str(info["sect_name"])

		if profile.sect_id != target_sect:
			return {"ok": false, "message": "Bí kíp 180 này là tuyệt kỹ trấn phái của [%s], môn phái khác không thể tu luyện!" % s_name}
		if profile.level < 120:
			return {"ok": false, "message": "Yêu cầu đẳng cấp 120 trở lên mới có thể tu luyện tuyệt kỹ trấn phái 180!"}

		var cur_lvl: int = profile.get_skill_level(target_skill)
		if cur_lvl >= 20:
			return {"ok": false, "message": "Võ công [%s] đã đạt đến cảnh giới tối cao (Cấp 20)!" % sk_name}

		_consume_one(profile, item, index)
		var new_lvl := cur_lvl + 1
		profile.skill_levels[target_skill] = new_lvl
		profile.add_exp(1500000)
		return {
			"ok": true,
			"message": "Lĩnh hội Bí Kíp 180 thành công! Kỹ năng [%s] đạt Cấp %d/20!\n+ 1.500.000 EXP" % [sk_name, new_lvl]
		}

	# 19. MỌI MÓN MISC KHÁC (Chìa khóa, cần câu, vật phẩm đặc biệt...)
	_consume_one(profile, item, index)
	profile.add_exp(200000)
	profile.gold += 10000
	return {
		"ok": true,
		"message": "Đã sử dụng [%s]!\n+ 200.000 EXP\n+ 10.000 Lượng" % item_name
	}

## MỞ RƯƠNG BÁCH THÚ SƠN TRANG (Phần thưởng khi đổi thịt thú nuôi cho NPC Trù Thần)
## Mở ra nhận:
## 1. Lượng lớn EXP & Ngân lượng
## 2. Trang Bị Quý: 15% Hoàng Kim Môn Phái, 85% Trang bị Xanh Cực Phẩm Cấp 9-10 (4-6 dòng)
## 3. Tiên Thảo Lộ (50% cơ hội rơi Tiên Thảo Lộ Đặc Biệt hoặc Thường)
## 4. Thủy Tinh / Tinh Hồng Bảo Thạch (40% cơ hội)
## 5. CỰC HIẾM: Ngẫu nhiên Bí Kíp 180 của 15 phái (~2.5% tỷ lệ) hoặc Đại Thành Bí Kíp 150 (~5.0% tỷ lệ)
static func open_ruong_bach_thu(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {"ok": false, "message": "Không tìm thấy hồ sơ nhân vật!"}

	var gained_exp := randi_range(300000, 800000)
	var gained_gold := randi_range(50000, 150000)
	profile.add_exp(gained_exp)
	profile.gold += gained_gold

	var rewards_text: Array[String] = [
		"+ %s EXP" % _fmt(gained_exp),
		"+ %s Lượng" % _fmt(gained_gold)
	]

	# 1. ĐỒ TRANG BỊ
	var equip_item: ItemInstance = null
	if randf() < 0.15:
		equip_item = ItemGenerator.generate_gold(randi_range(0, 4790), randi_range(7, 10))
		if equip_item != null:
			rewards_text.append("✨ [HOÀNG KIM] %s" % equip_item.get_display_name())
	if equip_item == null:
		var tier_arr: Array = (DropTable.TIERS[10] as Array).duplicate()
		equip_item = DropTable._roll_blue_item(tier_arr, randi_range(0, 4), randi_range(4, 6))
		if equip_item != null:
			rewards_text.append("🛡️ [Trang Bị] %s (%d dòng)" % [equip_item.get_display_name(), equip_item.magic.size()])
	if equip_item != null:
		profile.add_item(equip_item)

	# 2. TIÊN THẢO LỘ
	if randf() < 0.50:
		var ttl_id := "6_1_1181" if randf() < 0.50 else "6_1_71"
		var ttl_count := randi_range(1, 2)
		var ttl_item := ItemGenerator.generate_misc(ttl_id, 0, 0, ttl_count)
		if ttl_item != null:
			profile.add_item(ttl_item)
			rewards_text.append("🌿 %dx %s" % [ttl_count, ttl_item.get_display_name()])

	# 3. THỦY TINH & BẢO THẠCH
	if randf() < 0.40:
		var gem_ids := ["4_238_1", "4_239_1", "4_240_1", "4_353_1"]
		var gem_item := ItemGenerator.generate_misc(gem_ids.pick_random(), 0, 0, 1)
		if gem_item != null:
			profile.add_item(gem_item)
			rewards_text.append("💎 1x %s" % gem_item.get_display_name())

	# 4. SKILL 180 (CỰC HIẾM ~2.5%): Ngẫu nhiên Bí Kíp 180 trong 15 Môn Phái
	var got_skill_180 := false
	if randf() < 0.025:
		var b180_keys := BIKIP_180_MAP.keys()
		var picked_180: String = b180_keys.pick_random()
		var b180_item := ItemGenerator.generate_misc(picked_180, 0, 0, 1)
		if b180_item != null:
			profile.add_item(b180_item)
			var sk_info: Dictionary = BIKIP_180_MAP.get(picked_180, {})
			var sk_name: String = str(sk_info.get("name", "Bí Kíp 180"))
			var s_name: String = str(sk_info.get("sect_name", "Môn Phái"))
			rewards_text.append("⭐ [CỰC HIẾM] Bí Kíp 180 [%s] (%s)!" % [sk_name, s_name])
			got_skill_180 = true

	# 5. SKILL 150 (CỰC HIẾM ~5.0%): Rơi [Đại Thành Bí Kíp 150]
	var got_skill_150 := false
	if not got_skill_180 and randf() < 0.050:
		var b150_item := ItemGenerator.generate_misc("6_1_30446", 0, 0, 1)
		if b150_item != null:
			profile.add_item(b150_item)
			rewards_text.append("🌟 [CỰC HIẾM] [Đại Thành Bí Kíp 150] (+5 Điểm Kỹ Năng)!")
			got_skill_150 = true

	var title_msg := "🎉 Mở [Rương Bách Thú Sơn Trang] Thành Công!"
	if got_skill_180 or got_skill_150:
		title_msg = "🎊 [ĐẠI CÁT ĐẠI LỢI] Khí Vận Hanh Thông! Mở Rương Bách Thú Nhận Tuyệt Phẩm!"

	return {
		"ok": true,
		"message": "%s\n%s" % [title_msg, "\n".join(rewards_text)]
	}

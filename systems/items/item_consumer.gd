class_name ItemConsumer
extends RefCounted

## Xử lý dùng vật phẩm (Item Usage / Consumption / Open Chests):
## Áp dụng cho toàn bộ các vật phẩm tiêu hao, rương báu, lễ hộp, đan dược, bí kíp, lệnh bài...
## Hoạt động được ở cả trong trận đấu (Map) và ngoài sảnh (CharacterHub).

const HUB_SCENE_PATH := "res://ui/character_hub/CharacterHub.tscn"
const TOWN_PORTAL_IDS: Array[String] = ["6_1_438", "5_0_0"]

static var _is_exiting_to_hub: bool = false

static func is_town_portal(item: ItemInstance) -> bool:
	return item != null and item.is_misc() and item.misc_id in TOWN_PORTAL_IDS

static func is_da_tau_modal_token(item: ItemInstance) -> bool:
	return item != null and item.is_misc() and item.misc_id in ["ky_datau_hoanthanh", "ky_datau_huy"]

static func _exit_to_hub_now(profile: PlayerProfile) -> void:
	if _is_exiting_to_hub:
		return
	_is_exiting_to_hub = true
	var loop := Engine.get_main_loop()
	var tree := loop as SceneTree if loop is SceneTree else null
	if tree != null:
		tree.paused = false
	var gm: Node = tree.root.get_node_or_null("GameManager") if tree != null and tree.root != null else null
	var save_mgr: Node = tree.root.get_node_or_null("SaveManager") if tree != null and tree.root != null else null
	var acc_api: Node = tree.root.get_node_or_null("AccountApi") if tree != null and tree.root != null else null
	var is_gm: bool = acc_api != null and acc_api.has_method("is_gm") and acc_api.is_gm()
	var gm_mode: Variant = gm.get("game_mode") if gm != null else null
	var is_stage: bool = gm != null and (gm.get("current_stage") != null or (gm_mode != null and int(gm_mode) == 0))
	if profile != null and save_mgr != null:
		if save_mgr.has_method("save_profile"):
			save_mgr.save_profile(profile)
		if save_mgr.has_method("flush_online"):
			await save_mgr.flush_online()
	if tree != null:
		var transition: Node = tree.root.get_node_or_null("SceneTransition") if tree.root != null else null
		if transition != null and transition.has_method("change_scene"):
			transition.change_scene(HUB_SCENE_PATH, "Về Thành Dưỡng Sức")
		else:
			tree.change_scene_to_file(HUB_SCENE_PATH)
	_is_exiting_to_hub = false

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
	if mid in ["6_1_1476", "6_1_2339", "6_1_2805", "item_goldenbox", "ky_tui_thuoc_lac", "ky_tui_lenh_bai_datau", "ruong_bach_thu_son_trang", "6_1_1144", "6_1_1145"]:
		return true
	var name_lower := item.get_display_name().to_lower()
	if name_lower.contains("rương") or name_lower.contains("hộp") or name_lower.contains("túi") or name_lower.contains("gói") or name_lower.contains("bao"):
		return true
	var intro := str(item.get_base().get("intro", "")).to_lower()
	if intro.contains("sử dụng sẽ") or intro.contains("sử dụng có") or intro.contains("sử dụng nhận"):
		return true
	return false

static func is_summon_token(item: ItemInstance) -> bool:
	if item == null or not item.is_misc():
		return false
	return item.misc_id in ["6_1_2969", "6_1_3083", "6_1_3084", "6_1_3085", "6_1_4946", "6_1_30074"]

static func is_usable(item: ItemInstance) -> bool:
	if item == null or not item.is_misc():
		return false
	var mid := item.misc_id
	if is_chest_or_box(item):
		return true
	if PotionEffect.usable(item) or PotionEffect.is_fuyuan_potion(item):
		return true
	if is_town_portal(item) or mid in ["6_1_1083", "6_1_1266"]:
		return true
	if mid in ["ky_thien_nien_tran_lo", "6_1_12", "6_1_2424", "6_1_2425", "6_1_30446", "6_1_22", "6_1_26", "6_1_2396", "6_1_2309", "6_1_1375", "6_1_125"]:
		return true
	if BIKIP_180_MAP.has(mid) or mid in ["6_1_18017", "6_1_18018", "6_1_18019", "6_1_18020", "6_1_18021", "6_1_18022", "6_1_18023", "6_1_18024", "6_1_18025"]:
		return true
	if is_summon_token(item):
		return true
	if LonXonRules.book_tier(mid) > 0:
		return true
	return false

static func get_action_label(item: ItemInstance) -> String:
	if item == null:
		return ""
	if not item.is_misc():
		return "Trang bị"
	if not is_usable(item):
		return ""
	var mid := item.misc_id
	if is_chest_or_box(item):
		var name_lower := item.get_display_name().to_lower()
		if name_lower.contains("rương"):
			return "Mở Rương"
		elif name_lower.contains("hộp"):
			return "Mở Hộp"
		elif name_lower.contains("túi"):
			return "Mở Túi"
		elif name_lower.contains("bao"):
			return "Mở Bao"
		return "Mở"
	if is_summon_token(item):
		return "Triệu Hồi"
	if mid == "6_1_2396":
		return "Mở Mã Bài"
	if mid == "6_1_2309":
		return "Đánh Trống"
	if is_town_portal(item):
		return "Về Thành"
	if mid in ["6_1_1083", "6_1_1266"]:
		return "Dịch Chuyển"
	if mid in ["6_1_12", "6_1_2424", "6_1_2425", "6_1_30446", "6_1_22", "6_1_26"] or BIKIP_180_MAP.has(mid) or mid in ["6_1_18017", "6_1_18018", "6_1_18019", "6_1_18020", "6_1_18021", "6_1_18022", "6_1_18023", "6_1_18024", "6_1_18025"]:
		return "Luyện Bí Kíp"
	if PotionEffect.usable(item) or PotionEffect.is_fuyuan_potion(item) or mid in ["ky_thien_nien_tran_lo", "6_1_125"]:
		return "Uống"
	return "Sử dụng"

static func get_special_actions(item: ItemInstance, host: Node, profile: PlayerProfile, on_play: Callable = Callable(), on_changed: Callable = Callable()) -> Array:
	if item == null or not item.is_misc():
		return []
	var mid := item.misc_id
	var actions: Array = []

	# 0. ĐẠI THÀNH BÍ KÍP (Lộn Xộn): mỗi kỹ năng cùng tầng 1 nút "Học <tên>"
	var book_tier := LonXonRules.book_tier(mid)
	if book_tier > 0 and profile != null:
		for sk in LonXonRules.book_candidates(profile, book_tier):
			var sid := sk.id
			actions.append(["Học %s (%d/%d)" % [sk.skill_name, profile.get_skill_level(sid), sk.max_level], func() -> void:
				var r := use_book(profile, item, sid)
				if host != null and host.has_method("_show_toast"):
					host.call("_show_toast", str(r.get("message", "")))
				if on_changed.is_valid():
					on_changed.call()
			])

	# 1. PHONG LĂNG ĐỘ (4_489_1: Lệnh bài Phong Lăng Độ, 6_1_2745: Lệnh Bài Thủy Tặc)
	if mid in ["4_489_1", "6_1_2745"]:
		actions.append(["Đi Phong Lăng Độ", func() -> void:
			var w := _open_map_select(host, profile, on_play)
			if w != null and w.has_method("_select_tab"):
				w._select_tab(2)
		])

	# 2. KHO BÁU VIÊM ĐẾ (6_1_1617: Viêm Đế Lệnh; 6_1_2805, 6_1_1685, 6_1_1606: Đổi thưởng)
	if mid == "6_1_1617":
		actions.append(["Kho Báu Viêm Đế", func() -> void:
			var script: GDScript = load("res://ui/events/viem_de_window.gd")
			if script != null and script.has_method("open"):
				script.open(host, profile, on_play)
		])
	elif mid in ["6_1_2805", "6_1_1685", "6_1_1606"]:
		actions.append(["Tiệm Đổi Viêm Đế", func() -> void:
			var script: GDScript = load("res://ui/events/viem_de_window.gd")
			if script != null and script.has_method("open_reward_shop"):
				script.open_reward_shop(host, profile)
		])

	# 3. LINH LUNG THÁP (4_999_0)
	if mid == "4_999_0":
		actions.append(["Linh Lung Tháp", func() -> void:
			var w := _open_map_select(host, profile, on_play)
			if w != null and w.has_method("_select_tab"):
				w._select_tab(2)
		])

	# 4. NHIỆM VỤ DÃ TẨU (ky_datau_hoanthanh, ky_datau_huy)
	if is_da_tau_modal_token(item):
		actions.append(["Mở Dã Tẩu", func() -> void:
			var script: GDScript = load("res://ui/events/da_tau_window.gd")
			if script != null and script.has_method("open"):
				script.open(host, profile, on_play)
		])

	# 5. TIỆM ÉP ĐỒ / CHẾ TẠO (CompoundWindow):
	# Mảnh Lệnh Bài 1-7, Sát Thủ Lệnh (5 lệnh -> 1 giản), Thủy Tinh, Tinh Hồng, Huyền Tinh, Nguyên khoáng, Khoáng thuộc tính
	if mid in ["4_51_0", "4_52_0", "4_53_0", "4_54_0", "4_55_0", "4_56_0", "4_57_0", "6_1_399", "4_238_1", "4_239_1", "4_240_1", "4_353_1", "6_1_147"] or mid in ["6_1_149", "6_1_150", "6_1_151", "6_1_152", "6_1_153", "6_1_154", "6_1_200", "6_1_201", "6_1_202", "6_1_203", "6_1_204", "6_1_205"]:
		actions.append(["Tiệm Ép Đồ", func() -> void:
			var script: GDScript = load("res://ui/shop/compound_window.gd")
			if script != null and script.has_method("open"):
				script.open(host, profile, on_changed)
		])

	# 6. NHIỆM VỤ SÁT THỦ (Sát Thủ Giản 6_1_400, Lệnh Bài Sát Thủ 6_1_30565)
	if mid in ["6_1_400", "6_1_30565"]:
		actions.append(["Nhiệm Vụ Sát Thủ", func() -> void:
			var tree := Engine.get_main_loop() as SceneTree
			var cur := tree.current_scene if tree else null
			if cur != null and cur.has_method("_show_toast"):
				cur._show_toast("Mang Sát Thủ Giản đến gặp NPC Nhiếp Thí Trần tại 7 đại thành thị để nhận nhiệm vụ Sát Thủ!")
			elif cur != null and cur.has_method("_show_message"):
				cur._show_message("Mang Sát Thủ Giản đến gặp NPC Nhiếp Thí Trần tại 7 đại thành thị để nhận nhiệm vụ Sát Thủ!")
		])

	# 7. CÔNG THÀNH CHIẾN (Thủ thành / Công thành lệnh bài của 7 đại thành thị)
	if mid in ["4_354_1", "4_355_1", "4_356_1", "4_357_1", "4_358_1", "4_359_1", "4_360_1", "4_361_1", "4_362_1", "4_363_1", "4_364_1", "4_365_1", "4_366_1", "4_367_1", "4_368_1", "6_1_2395"]:
		actions.append(["Công Thành Chiến", func() -> void:
			var script: GDScript = load("res://ui/city_war/city_war_window.gd")
			if script != null and script.has_method("open"):
				script.open(host, profile, on_play)
		])

	# 8. CHIẾN TRƯỜNG TỐNG KIM (Quốc chiến Tống/Kim, Lệnh bài Tống Kim Liên Server)
	if mid in ["6_1_1167", "6_1_2057", "6_1_2058", "6_1_3307"]:
		actions.append(["Chiến Trường Tống Kim", func() -> void:
			var w := _open_map_select(host, profile, on_play)
			if w != null and w.has_method("_select_tab"):
				w._select_tab(1)
		])

	# 9. HOA SƠN LUẬN KIẾM / ANH HÙNG HỘI / VÕ LÂM LIÊN ĐẤU
	if mid in ["4_241_0", "4_347_1", "4_348_1", "4_349_1", "4_350_1", "6_1_407", "6_1_408", "6_1_409", "6_1_410", "6_1_411", "6_1_412", "6_1_413", "6_1_414", "6_1_415", "6_1_416", "6_1_417", "6_1_418", "6_1_419", "6_1_420", "6_1_1068", "6_1_1069", "6_1_1070", "6_1_1071"]:
		actions.append(["Anh Hùng Hội", func() -> void:
			var tree := Engine.get_main_loop() as SceneTree
			var cur := tree.current_scene if tree else null
			if cur != null and cur.has_method("_show_toast"):
				cur._show_toast("Tín vật tham gia Anh Hùng Hội / Võ Lâm Liên Đấu. Hãy gặp Võ Lâm Quan Viên để báo danh!")
			elif cur != null and cur.has_method("_show_message"):
				cur._show_message("Tín vật tham gia Anh Hùng Hội / Võ Lâm Liên Đấu. Hãy gặp Võ Lâm Quan Viên để báo danh!")
		])

	return actions

static func _open_map_select(host: Node, profile: PlayerProfile, on_play: Callable) -> Object:
	var script: GDScript = load("res://ui/map_select/map_select_window.gd")
	if script != null and script.has_method("open"):
		return script.open(host, profile, on_play)
	return null

static func _try_spawn_summon_monster(player: Node, tpl: int, m_name: String) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var m_script: GDScript = load("res://systems/monster/vltk_monster.gd")
	if m_script == null:
		return false
	var base: Dictionary = MonsterData.monster(tpl)
	if base.is_empty():
		base = {"name": m_name, "level": 90, "life": 500000}

	var m: Node = m_script.new()
	m.set("monster_id", tpl)
	var data_copy: Dictionary = base.duplicate(true)
	data_copy["name"] = m_name
	data_copy["series"] = randi() % 5
	m.set("data", data_copy)
	m.set("level", int(base.get("level", 90)))
	m.set("ai_enabled", true)
	if m.get("level") == null or int(m.get("level")) <= 0:
		m.set("level", 90)

	var spawn_pos: Vector2 = player.position + Vector2(randf_range(-120.0, 120.0), randf_range(-120.0, 120.0))
	m.position = spawn_pos

	var target_parent: Node = null
	var world_script: GDScript = load("res://world/vltk_world.gd")
	if world_script != null and world_script.has_method("objects_layer"):
		target_parent = world_script.objects_layer()
	if target_parent == null:
		target_parent = player.get_parent()

	if target_parent != null:
		target_parent.add_child(m)
		return true
	return false

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

## Dùng 1 cuốn Đại Thành Bí Kíp cho `skill_id` ("" = kỹ năng cùng tầng có cấp thấp nhất còn học được).
static func use_book(profile: PlayerProfile, item: ItemInstance, skill_id: String) -> Dictionary:
	var tier := LonXonRules.book_tier(item.misc_id if item != null else "")
	var index := profile.inventory.find(item) if profile != null else -1
	if tier <= 0 or index < 0:
		return {"ok": false, "message": "Vật phẩm không còn trong hành trang."}
	if skill_id == "":
		skill_id = LonXonRules.default_book_skill(profile, tier)
		if skill_id == "":
			var why := LonXonRules.book_block_reason(profile, tier, "")
			if LonXonRules.in_match:
				why = "Không có kỹ năng %dx nào học được lúc này (chưa đủ cấp hoặc đã tối đa)." % tier
			return {"ok": false, "message": why}
	var err := LonXonRules.learn_from_book(profile, tier, skill_id)
	if err != "":
		return {"ok": false, "message": err}
	_consume_one(profile, item, index)
	var sk_name := skill_id
	for sk in LonXonRules.book_candidates(profile, tier):
		if sk.id == skill_id:
			sk_name = sk.skill_name
	return {"ok": true, "message": "Lĩnh hội Đại Thành Bí Kíp %dx: [%s] đạt cấp %d." % [tier, sk_name, profile.get_skill_level(skill_id)]}

static func use_item(profile: PlayerProfile, item: ItemInstance, player: Node = null, host: Node = null) -> Dictionary:
	if profile == null or item == null:
		return {"ok": false, "message": "Thông tin vật phẩm không hợp lệ."}
	
	var index := profile.inventory.find(item)
	if index < 0:
		return {"ok": false, "message": "Vật phẩm không còn trong hành trang."}
	
	var mid := item.misc_id
	var item_name := item.get_display_name()

	# 0. ĐẠI THÀNH BÍ KÍP (Lộn Xộn): bấm Dùng = học kỹ năng cùng tầng đang có cấp thấp nhất
	if LonXonRules.book_tier(mid) > 0:
		return use_book(profile, item, "")

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
		return {
			"ok": false,
			"message": "Hãy mở bảng Nhiệm Vụ Dã Tẩu khi đang có nhiệm vụ và bấm 'Dùng Lệnh Bài Hoàn Thành' để hoàn tất ngay nhiệm vụ!"
		}

	# 4.1. LỆNH BÀI HỦY DÃ TẨU (ky_datau_huy)
	if mid == "ky_datau_huy":
		return {
			"ok": true,
			"message": "Hãy mở bảng Nhiệm Vụ Dã Tẩu và bấm 'Hủy Nhiệm Vụ' khi hết lượt bỏ miễn phí ngày — lệnh bài sẽ tự động được dùng để giữ chuỗi nhiệm vụ!"
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

	# 7.3. TẨY TỦY KINH (6_1_22) & VÕ LÂM MẬT TỊCH (6_1_26)
	if mid == "6_1_22":
		_consume_one(profile, item, index)
		profile.potential_points += 5
		return {
			"ok": true,
			"message": "Lĩnh ngộ [Tẩy Tủy Kinh]! Nhận thêm +5 Điểm Tiềm Năng."
		}

	if mid == "6_1_26":
		_consume_one(profile, item, index)
		profile.skill_points += 1
		return {
			"ok": true,
			"message": "Lĩnh ngộ [Võ Lâm Mật Tịch]! Nhận thêm +1 Điểm Kỹ Năng."
		}

	# 7.4. MÃ BÀI - PHI VÂN (6_1_2396)
	if mid == "6_1_2396":
		var horse := ItemGenerator.generate(ItemDatabase.Detail.HORSE, 8, 10, 0, [])
		if horse == null:
			return {"ok": false, "message": "Không tạo được ngựa Phi Vân!"}
		if not profile.add_item(horse):
			return {"ok": false, "message": "Hành trang không đủ chỗ trống để nhận ngựa Phi Vân!"}
		_consume_one(profile, item, index)
		return {
			"ok": true,
			"message": "Đã mở [Mã bài - Phi Vân] nhận được thú cưỡi [Phi Vân]!"
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

	# 12.7. BAO HOÀNG KIM (6_1_1476) - Thường nhận từ Dã Tẩu hoặc sự kiện
	# Mô tả: "Sử dụng sẽ có xác suất nhận được một trong những vật phẩm sau: vũ khí hoặc trang bị Hoàng Kim, Thần bí khoáng thạch, Huyền tinh khoáng thạch cấp 8 và túi may mắn (đại)."
	if mid == "6_1_1476" or item_name.to_lower().contains("bao hoàng kim"):
		_consume_one(profile, item, index)
		var gained_exp := randi_range(800000, 2000000)
		var gained_gold := randi_range(80000, 250000)
		profile.add_exp(gained_exp)
		profile.gold += gained_gold

		var roll := randf()
		var rewarded_name := ""
		if roll < 0.15:
			# 15%: Vũ khí hoặc trang bị Hoàng Kim
			var gold_count := ItemDatabase.get_gold_count()
			if gold_count > 0:
				var gold_idx := randi() % gold_count
				var gold_it := ItemGenerator.generate_gold(gold_idx, randi_range(7, 10))
				if gold_it != null:
					profile.add_item(gold_it)
					rewarded_name = "✨ [Trang Bị Hoàng Kim] %s" % gold_it.get_display_name()
		elif roll < 0.45:
			# 30%: Thần bí khoáng thạch (6_1_398)
			var tbkt := ItemGenerator.generate_misc("6_1_398", 0, 0, 1)
			if tbkt != null:
				profile.add_item(tbkt)
				rewarded_name = "💎 %s" % tbkt.get_display_name()
		elif roll < 0.70:
			# 25%: Huyền tinh khoáng thạch cấp 8 (6_1_147)
			var ht8 := ItemGenerator.generate_misc("6_1_147", 8, 0, 1)
			if ht8 != null:
				profile.add_item(ht8)
				rewarded_name = "⭐ %s Cấp 8" % ht8.get_display_name()
		else:
			# 30%: Túi may mắn (đại) (6_1_1144)
			var tmm := ItemGenerator.generate_misc("6_1_1144", 0, 0, 1)
			if tmm != null:
				profile.add_item(tmm)
				rewarded_name = "🎁 %s" % tmm.get_display_name()

		if rewarded_name == "":
			rewarded_name = "Ngân Lượng và Kinh Nghiệm dồi dào"

		return {
			"ok": true,
			"message": "Mở [%s] thành công!\n+ %s EXP\n+ %s Lượng\n+ 1x %s" % [
				item_name,
				_fmt(gained_exp),
				_fmt(gained_gold),
				rewarded_name
			]
		}

	# 12.8. TÚI MAY MẮN (ĐẠI) (6_1_1144) & TÚI MAY MẮN (TIỂU) (6_1_1145)
	if mid == "6_1_1144":
		_consume_one(profile, item, index)
		var gained_exp := randi_range(300000, 800000)
		var gained_gold := randi_range(30000, 100000)
		profile.add_exp(gained_exp)
		profile.gold += gained_gold
		var pool := ["6_1_71", "6_1_1181", "6_1_72", "6_1_122", "6_1_123", "4_238_1", "4_239_1", "4_240_1", "4_353_1", "6_1_147"]
		var items_given: Array[String] = []
		for i in 4:
			var pick: String = pool.pick_random()
			var it: ItemInstance = null
			if pick == "6_1_147":
				it = ItemGenerator.generate_misc(pick, randi_range(2, 6), 0, 1)
			else:
				it = ItemGenerator.generate_misc(pick, 0, 0, 1)
			if it != null:
				profile.add_item(it)
				items_given.append(it.get_display_name())
		return {
			"ok": true,
			"message": "Mở [Túi May Mắn (Đại)] nhận được:\n+ %s EXP\n+ %s Lượng\n+ %s" % [
				_fmt(gained_exp),
				_fmt(gained_gold),
				"\n+ ".join(items_given)
			]
		}

	if mid == "6_1_1145":
		_consume_one(profile, item, index)
		var gained_exp := randi_range(100000, 300000)
		var gained_gold := randi_range(10000, 40000)
		profile.add_exp(gained_exp)
		profile.gold += gained_gold
		var pool := ["6_1_71", "6_1_72", "6_1_122", "4_238_1", "4_239_1"]
		var pick: String = pool.pick_random()
		var it := ItemGenerator.generate_misc(pick, 0, 0, 1)
		var it_name := "Vật phẩm ngẫu nhiên"
		if it != null:
			profile.add_item(it)
			it_name = it.get_display_name()
		return {
			"ok": true,
			"message": "Mở [Túi May Mắn (Tiểu)] nhận được:\n+ %s EXP\n+ %s Lượng\n+ 1x %s" % [
				_fmt(gained_exp),
				_fmt(gained_gold),
				it_name
			]
		}

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

	# 15. LỆNH BÀI TRIỆU HỒI (Mộc Nhân, Boss Trương Tuyên, Kim Thí Lượng, Mộ Dung Toàn, Quái Vật)
	if is_summon_token(item):
		var target_name := "Mộc Nhân"
		var tpl_id := 1161
		if mid == "6_1_2969":
			target_name = "Mộc Nhân"
			tpl_id = 1161
		elif mid == "6_1_3083":
			target_name = "Boss Trương Tuyên"
			tpl_id = 1873
		elif mid == "6_1_3084":
			target_name = "Boss Kim Thí Lượng"
			tpl_id = 1874
		elif mid == "6_1_3085":
			target_name = "Boss Mộ Dung Toàn"
			tpl_id = 1875
		elif mid in ["6_1_4946", "6_1_30074"]:
			target_name = "Quái Vật Luyện Công"
			tpl_id = 1161

		if player == null:
			return {
				"ok": false,
				"message": "Cần vào bản đồ chiến đấu hoặc bãi luyện công dã ngoại mới có thể triệu hồi [%s]!" % target_name
			}

		var spawned := _try_spawn_summon_monster(player, tpl_id, target_name)
		if not spawned:
			return {
				"ok": false,
				"message": "Không thể triệu hồi [%s] tại khu vực này (hãy di chuyển đến vị trí trống)!" % target_name
			}

		_consume_one(profile, item, index)
		return {
			"ok": true,
			"message": "Sử dụng [%s] thành công!\nĐã triệu hồi [%s] xuất hiện gần bạn!" % [item_name, target_name]
		}

	# 15b. CÁC LOẠI LỆNH BÀI SỰ KIỆN & TÍN VẬT HOẠT ĐỘNG (Phong Lăng Độ, Viêm Đế, Linh Lung Tháp, Tống Kim...)
	if mid in ["4_489_1", "6_1_2745"]:
		return {
			"ok": false,
			"message": "Lệnh bài Phong Lăng Độ là tín vật lên thuyền vượt sông Hoàng Hà. Hãy mở tab Ải hoặc đến Bến Tàu Phong Lăng Độ để tham gia!"
		}
	if mid == "6_1_1617":
		return {
			"ok": false,
			"message": "Viêm Đế Lệnh là tín vật mở phòng khiêu chiến Kho Báu Viêm Đế. Hãy mở bảng Kho Báu Viêm Đế để sử dụng!"
		}
	if mid == "4_999_0":
		return {
			"ok": false,
			"message": "Lệnh Bài Linh Lung Tháp dùng để báo danh khiêu chiến 7 tầng Linh Lung Tháp tại tab Ải hoặc gặp NPC Nhạc Xung!"
		}
	if mid == "6_1_399":
		return {
			"ok": false,
			"message": "Sát Thủ Lệnh dùng để ghép thành Sát Thủ Giản (5 lệnh cùng cấp -> 1 giản) tại Tiệm Ép Đồ!"
		}
	if mid in ["6_1_400", "6_1_30565"]:
		return {
			"ok": false,
			"message": "Mang Sát Thủ Giản đến gặp NPC Nhiếp Thí Trần tại 7 đại thành thị để nhận nhiệm vụ Sát Thủ truy bắt ác tặc!"
		}
	if mid in ["4_51_0", "4_52_0", "4_53_0", "4_54_0", "4_55_0", "4_56_0", "4_57_0"]:
		return {
			"ok": false,
			"message": "Mảnh Lệnh Bài là nguyên liệu nhiệm vụ, hãy vào Tiệm Ép Đồ để ghép!"
		}
	if mid in ["4_354_1", "4_355_1", "4_356_1", "4_357_1", "4_358_1", "4_359_1", "4_360_1", "4_361_1", "4_362_1", "4_363_1", "4_364_1", "4_365_1", "4_366_1", "4_367_1", "4_368_1", "6_1_2395"]:
		return {
			"ok": false,
			"message": "Lệnh Bài Công Thành dùng để bang chủ báo danh Công Thành Chiến tại Công Thành Quan Viên!"
		}
	if mid in ["6_1_1167", "6_1_2057", "6_1_2058", "6_1_3307"]:
		return {
			"ok": false,
			"message": "Tín vật Chiến Trường Tống Kim, hãy dùng để báo danh tại Mộ Binh Quan Tống / Kim!"
		}
	if mid in ["4_241_0", "4_347_1", "4_348_1", "4_349_1", "4_350_1", "6_1_407", "6_1_408", "6_1_409", "6_1_410", "6_1_411", "6_1_412", "6_1_413", "6_1_414", "6_1_415", "6_1_416", "6_1_417", "6_1_418", "6_1_419", "6_1_420", "6_1_1068", "6_1_1069", "6_1_1070", "6_1_1071"]:
		return {
			"ok": false,
			"message": "Tín vật tham gia Hoa Sơn Luận Kiếm / Anh Hùng Hội / Võ Lâm Liên Đấu!"
		}

	# 16. THỔ ĐỊA PHÙ (6_1_438 x2000, 5_0_0 x1) — lập tức thoát ra Character Hub, không hỏi gì
	if is_town_portal(item):
		if player == null:
			return {
				"ok": false,
				"message": "Bạn đang ở Character Hub rồi!"
			}
		_consume_one(profile, item, index)
		_exit_to_hub_now(profile)
		return {
			"ok": true,
			"exit_to_hub": true,
			"message": ""
		}

	# 16b. PHÙ DỊCH CHUYỂN KHÁC (Thần Hành Phù, Hồi Thành Phù)
	if mid in ["6_1_1083", "6_1_1266"]:
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
		var blocked := PotionEffect.block_reason(item, profile)
		if blocked != "":
			return {"ok": false, "message": blocked}
		if PotionEffect.consume(profile, player, item):
			var msg := "Uống %s thành công!" % item_name
			if mid in ["6_1_1181", "6_1_1765"]:
				msg = "Uống %s thành công!\nNhân đôi kinh nghiệm (x2 EXP) trong 8 giờ." % item_name
			elif mid == "6_1_71":
				msg = "Uống %s thành công!\nNhân đôi kinh nghiệm (x2 EXP) trong 1 giờ." % item_name
			elif mid == "6_1_113":
				msg = "Uống %s thành công!\nTăng 50%% kinh nghiệm luyện công trong 1 giờ." % item_name
			elif mid == "6_1_72":
				msg = "Uống %s thành công!\nTăng 10 điểm May Mắn trong 1 giờ." % item_name
			elif mid == "6_0_70":
				msg = "Dùng %s thành công!\nTăng 30 điểm May Mắn trong 30 phút." % item_name
			return {"ok": true, "message": msg}
		return {"ok": false, "message": "Không thể sử dụng %s lúc này." % item_name}

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

	# 18.11. CÁC LOẠI RƯƠNG, HỘP, TÚI, BAO KHÁC (is_chest_or_box)
	if is_chest_or_box(item):
		_consume_one(profile, item, index)
		var gained_exp := randi_range(200000, 600000)
		var gained_gold := randi_range(20000, 80000)
		profile.add_exp(gained_exp)
		profile.gold += gained_gold
		var gem_pool := ["4_238_1", "4_239_1", "4_240_1", "6_1_71", "6_1_72"]
		var gem := ItemGenerator.generate_misc(gem_pool.pick_random(), 0, 0, 1)
		var extra_text := ""
		if gem != null:
			profile.add_item(gem)
			extra_text = "\n+ 1x %s" % gem.get_display_name()
		return {
			"ok": true,
			"message": "Mở [%s] thành công!\n+ %s EXP\n+ %s Lượng%s" % [
				item_name,
				_fmt(gained_exp),
				_fmt(gained_gold),
				extra_text
			]
		}

	# 19. MỌI MÓN MISC KHÁC KHÔNG PHẢI VẬT PHẨM TIÊU HAO TRỰC TIẾP
	# Tuyệt đối không tự ý tiêu hao và không cộng EXP/Gold giả đối với các tín vật, nguyên liệu, thẻ bài
	return {
		"ok": false,
		"message": "[%s] là tín vật / nguyên liệu, không thể sử dụng trực tiếp trong túi đồ." % item_name
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

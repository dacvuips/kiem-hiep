extends Node
## Luật màn Lộn Xộn (LonXonRules): hồ sơ vào trận, lên cấp theo quái, rơi đồ, chết rớt đồ, Đại Thành Bí Kíp, Lệnh Bài.
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/lon_xon_rules_tests.tscn

var _fail := 0

func check(name: String, ok: bool) -> void:
	print(("  OK  " if ok else "  FAIL ") + name)
	if not ok:
		_fail += 1

func _profile(sect_id: String) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.sect_id = sect_id
	p.display_name = "Thử"
	p.level = 120
	p.skill_levels = {"thieu_lam_kim_quyen_la_han": 20}
	p.add_item(ItemGenerator.generate_misc("1_0_0_1"))
	return p

func _skill(sect_id: String, id: String) -> SkillDefinition:
	for sk in SectRegistry.get_by_id(sect_id).skills:
		if sk.id == id:
			return sk
	return null

func _start_tests() -> void:
	var p := _profile("thieu_lam")
	LonXonRules.apply_start(p)
	check("Vào trận: cấp 50", p.level == 50)
	check("Vào trận: 245 điểm tiềm năng", p.potential_points == 49 * 5)
	check("Vào trận: không còn điểm kỹ năng", p.skill_points == 0)
	check("Vào trận: trang bị trống", p.equipment.is_empty())
	check("Vào trận: túi chỉ có 10 bình Hồi Thiên", p.inventory.size() == 1 and p.inventory[0].misc_id == "1_8_0_4" and p.inventory[0].count == 10)
	check("Vào trận: ô thuốc 1 = Hồi Thiên", p.quick_items[0] == "1_8_0_4")
	var sk10 := _skill("thieu_lam", "thieu_lam_dat_ma_do_giang")   ## 9x (req 80)
	check("Tầng: Đạt Ma Độ Giang = 9x", LonXonRules.skill_tier(sk10) == 9)
	check("Tầng: Kim Quyền La Hán = 18x", LonXonRules.skill_tier(_skill("thieu_lam", "thieu_lam_kim_quyen_la_han")) == 18)
	check("9x bắt đầu cấp 0", p.get_skill_level("thieu_lam_dat_ma_do_giang") == 0)
	check("18x hồ sơ thật bị xoá về 0", p.get_skill_level("thieu_lam_kim_quyen_la_han") == 0)
	var max_ok := true
	var not_yet_ok := true
	for sk in SectRegistry.get_by_id("thieu_lam").skills:
		if sk.parent_skill_id != "" or LonXonRules.skill_tier(sk) > 0:
			continue
		var want := (sk.max_level if sk.max_level > 0 else 20) if sk.req_level <= 50 else 0
		if p.get_skill_level(sk.id) != want:
			if sk.req_level <= 50:
				max_ok = false
			else:
				not_yet_ok = false
	check("Kỹ năng thường cấp <= 50: MAX", max_ok)
	check("Kỹ năng thường cấp > 50 (6x): chưa có", not_yet_ok)
	var hot_ok := true
	for sid in p.hotbar_skill_ids:
		if sid != "" and p.get_skill_level(sid) <= 0:
			hot_ok = false
	check("Ô skill không còn kỹ năng chưa học", hot_ok)

	# Lên cấp: 30 quái là 200, không vượt 200.
	var gained := LonXonRules.on_monster_kill(p)
	check("Hạ 1 quái: +5 cấp", gained == 5 and p.level == 55)
	check("Hạ 1 quái: +25 điểm tiềm năng", p.potential_points == 54 * 5)
	for i in 29:
		LonXonRules.on_monster_kill(p)
	check("30 quái: cấp 200", p.level == 200)
	check("Quái thứ 31: không tăng nữa", LonXonRules.on_monster_kill(p) == 0 and p.level == 200)
	var all_max := true
	for sk in SectRegistry.get_by_id("thieu_lam").skills:
		if sk.parent_skill_id == "" and LonXonRules.skill_tier(sk) == 0 and p.get_skill_level(sk.id) != (sk.max_level if sk.max_level > 0 else 20):
			all_max = false
	check("Cấp 200: mọi kỹ năng thường đã MAX", all_max)
	check("Cấp 200: 9x tự mở cấp 1", p.get_skill_level("thieu_lam_vo_tuong_tram") == 1)
	check("Cấp 200: 18x tự mở cấp 1", p.get_skill_level("thieu_lam_kim_quyen_la_han") == 1)

	# Mở theo đúng mốc cấp: 75 chưa có 9x, 80 có (yêu cầu cấp 80), tự gắn vào ô skill trống.
	var q := _profile("thieu_lam")
	LonXonRules.apply_start(q)
	for i in q.hotbar_skill_ids.size():
		if i >= 3:
			q.hotbar_skill_ids[i] = ""
	LonXonRules.add_levels(q, 25)
	check("Cấp 75: 9x chưa mở", q.get_skill_level("thieu_lam_dat_ma_do_giang") == 0)
	LonXonRules.add_levels(q, 5)
	check("Cấp 80: 9x tự mở cấp 1, không cần học", q.get_skill_level("thieu_lam_dat_ma_do_giang") == 1)
	check("Cấp 80: 12x chưa mở", q.get_skill_level("thieu_lam_dai_thua_nhu_lai_chu") == 0)
	check("Cấp 80: 9x tự gắn vào ô skill trống", "thieu_lam_dat_ma_do_giang" in q.hotbar_skill_ids)
	LonXonRules.add_levels(q, 40)
	check("Cấp 120: 12x tự mở", q.get_skill_level("thieu_lam_dai_thua_nhu_lai_chu") == 1)
	check("Cấp 120: 15x chưa mở", q.get_skill_level("thieu_lam_vi_da_hien_xu") == 0)

func _drop_tests() -> void:
	var blue := 0
	var gold := 0
	var sect_gold := 0
	var equip := 0
	var horses := 0
	var potions := 0
	var books := 0
	var min_eq := 99
	var max_eq := 0
	var runs := 2000
	var sect_set := {}
	for i in ItemDatabase.get_sect_gold_indices():
		sect_set[i] = true
	for r in runs:
		var drops := LonXonRules.roll_drops(100)
		var eq_here := 0
		var pot_here := 0
		for d in drops:
			var it: ItemInstance = d.item
			if it.is_misc():
				if it.misc_id == "1_8_0_4":
					pot_here += it.count
				elif LonXonRules.book_tier(it.misc_id) > 0:
					books += 1
					if it.count != 5:
						_fail += 1
						print("  FAIL bí kíp không đủ 5 cuốn")
				continue
			if it.is_gold():
				eq_here += 1
				if sect_set.has(it.gold_index):
					sect_gold += 1
				else:
					gold += 1
				continue
			if int(it.get_base().get("detail", -1)) == ItemDatabase.Detail.HORSE:
				horses += 1
				continue
			eq_here += 1
			blue += 1
		equip += eq_here
		min_eq = mini(min_eq, eq_here)
		max_eq = maxi(max_eq, eq_here)
		if pot_here != 1:
			potions = -1_000_000
		else:
			potions += 1
	var n := float(equip)
	print("    rơi %d lượt: %d món (xanh %.1f%% / HK %.1f%% / HKMP %.1f%%), ngựa %.1f%%, bí kíp %.1f%%" % [runs, equip,
		blue / n * 100.0, gold / n * 100.0, sect_gold / n * 100.0, horses * 100.0 / runs, books * 100.0 / runs])
	check("Mỗi quái 3–5 món trang bị", min_eq >= 3 and max_eq <= 5)
	check("Trung bình ~4 món", absf(n / runs - 4.0) < 0.15)
	check("Đồ xanh ~70%", absf(blue / n - 0.70) < 0.03)
	check("Hoàng Kim ~25%", absf(gold / n - 0.25) < 0.03)
	check("Hoàng Kim Môn Phái ~5%", absf(sect_gold / n - 0.05) < 0.015)
	check("Ngựa ~50%", absf(horses / float(runs) - 0.5) < 0.04)
	check("Đúng 1 bình Hồi Thiên mỗi quái", potions == runs)
	check("Bí kíp ~3%", absf(books / float(runs) - 0.03) < 0.015)

func _death_tests() -> void:
	var p := _profile("thieu_lam")
	LonXonRules.apply_start(p)
	LonXonRules.add_levels(p, 20)
	p.equipment[Equipment.Part.WEAPON] = LonXonRules.roll_equipment(70)
	p.add_item(LonXonRules.roll_equipment(70))
	var expect := p.equipment.size() + p.inventory.size()
	var lv := p.level
	var dropped := LonXonRules.death_drops(p)
	check("Chết: rớt đủ %d món" % expect, dropped.size() == expect)
	check("Chết: túi + trang bị trống", p.inventory.is_empty() and p.equipment.is_empty())
	check("Chết: giữ cấp", p.level == lv)

func _book_tests() -> void:
	var p := _profile("thieu_lam")
	LonXonRules.apply_start(p)
	var book := LonXonRules.make_book(9)
	check("Đại Thành Bí Kíp 9x: 5 cuốn", book != null and book.count == 5)
	check("Tên bí kíp", book != null and book.get_display_name().contains("Đại Thành Bí Kíp 9x"))
	check("Mã bí kíp -> tầng", LonXonRules.book_tier("lonxon_bikip_15") == 15 and LonXonRules.book_tier("1_8_0_4") == 0)
	check("Ứng viên 9x Thiếu Lâm: 3 chiêu", LonXonRules.book_candidates(p, 9).size() == 3)
	p.add_item(book)

	LonXonRules.in_match = false
	var r := ItemConsumer.use_item(p, book)
	check("Ngoài Lộn Xộn: không dùng được", not bool(r.ok) and str(r.message).contains("Lộn Xộn"))
	LonXonRules.in_match = true
	r = ItemConsumer.use_item(p, book)
	check("Cấp 50: chưa đủ cấp 80 học 9x", not bool(r.ok))
	LonXonRules.add_levels(p, 30)   ## cấp 80
	r = ItemConsumer.use_item(p, book)
	check("Cấp 80: dùng bí kíp 9x được", bool(r.ok))
	check("Dùng 1 cuốn: còn 4", book.count == 4)
	var learned := 0
	for sk in LonXonRules.book_candidates(p, 9):
		learned += p.get_skill_level(sk.id)
	check("3 chiêu 9x tự mở cấp 1, bí kíp nâng 1 chiêu lên 2", learned == 4)
	var err := LonXonRules.learn_from_book(p, 12, "thieu_lam_dat_ma_do_giang")
	check("Sai tầng: từ chối", err != "")
	for i in 20:
		LonXonRules.learn_from_book(p, 9, "thieu_lam_vo_tuong_tram")
	var lv := p.get_skill_level("thieu_lam_vo_tuong_tram")
	err = LonXonRules.learn_from_book(p, 9, "thieu_lam_vo_tuong_tram")
	check("Đạt tối đa: từ chối", lv == 20 and err != "")
	var hidden_ok := true
	for sk in SectRegistry.get_by_id("thieu_lam").skills:
		if sk.parent_skill_id == "thieu_lam_vo_tuong_tram" and p.get_skill_level(sk.id) == 0:
			hidden_ok = false
	check("Kỹ năng con theo kỹ năng cha", hidden_ok)
	LonXonRules.add_levels(p, 5)
	check("Lên cấp không xoá kỹ năng đã học bằng bí kíp", p.get_skill_level("thieu_lam_vo_tuong_tram") == 20)
	var acts := ItemConsumer.get_special_actions(book, null, p)
	check("Nút Học cho từng chiêu 9x", acts.size() == 3)
	LonXonRules.in_match = false

func _token_tests() -> void:
	check("Điểm: 3 Lệnh Bài = 3000", LonXonRules.score_for(3) == 3000)
	check("Chết giữ 0: rớt 1, còn 0", LonXonRules.death_token_split(0) == Vector2i(1, 0))
	check("Chết giữ 5: rớt 3, còn 3", LonXonRules.death_token_split(5) == Vector2i(3, 3))
	check("Chết giữ 4: rớt 3, còn 2", LonXonRules.death_token_split(4) == Vector2i(3, 2))
	check("To: 1 Lệnh Bài = 1.1", is_equal_approx(LonXonRules.scale_for(1), 1.1))
	check("To: trần 10 Lệnh Bài = 2.0", is_equal_approx(LonXonRules.scale_for(30), 2.0))
	check("Bán kính: 2 Lệnh Bài = 1.1", is_equal_approx(LonXonRules.radius_mult_for(2), 1.1))
	check("Bán kính: trần 1.5", is_equal_approx(LonXonRules.radius_mult_for(99), 1.5))
	check("Tầm nhìn: trần 5 Lệnh Bài = 1.5", is_equal_approx(LonXonRules.view_mult_for(8), 1.5))
	check("Zoom 1.0 + 5 Lệnh Bài -> 0.667", is_equal_approx(LonXonRules.zoom_for(1.0, 5), 1.0 / 1.5))
	var board := [
		{"cid": 1, "name": "An", "score": 2000}, {"cid": 2, "name": "Bình", "score": 5000},
		{"cid": 3, "name": "Cường", "score": 0}, {"cid": 4, "name": "Dũng", "score": 2000},
		{"cid": 5, "name": "Em", "score": 1000}, {"cid": 6, "name": "Phú", "score": 3000},
		{"cid": 7, "name": "Giang", "score": 1000},
	]
	var top := LonXonRules.top_n(board)
	check("Top 5: đủ 5 người", top.size() == 5)
	check("Top 5: đúng thứ tự điểm", top[0].cid == 2 and top[1].cid == 6 and top[2].cid == 1 and top[3].cid == 4)
	check("Top 5: bỏ người 0 điểm", top.all(func(e: Dictionary) -> bool: return e.cid != 3))
	var badges := LonXonRules.rank_badges(board)
	check("Số trên đầu: top 1/2/3", badges.get(2) == 1 and badges.get(6) == 2 and badges.get(1) == 3 and badges.size() == 3)

## Bước chọn thẻ 5x (PubgDraftPopup tier 5): ngựa cấp 5 + vũ khí cấp 5, dùng được ở cấp 50; bộ 8x của PUBG không đổi.
func _draft_tests() -> void:
	var names := []
	var horses_ok := true
	for h in PubgDraftPopup.HORSES_5X:
		var it := PubgDraftPopup.make_horse(int(h.level), 0, PubgDraftPopup.TIER_LONXON)
		if it == null or int(it.get_base().get("level", 0)) != 5 or int(it.get_base().get("detail", -1)) != ItemDatabase.Detail.HORSE:
			horses_ok = false
		else:
			names.append(it.get_base().get("name", ""))
	check("5 ngựa 5x đúng cấp 5: %s" % ", ".join(names), horses_ok and names.size() == 5)
	check("Tên ngựa 5x khớp bảng đồ", names == ["Hoàng Phiêu", "Tử Lưu", "Ngọc Hoa Thông", "Hắc Kỳ", "Hồng Ly"])
	var weap_ok := true
	for i in PubgDraftPopup.WEAPONS_10.size():
		var w := PubgDraftPopup.make_weapon(i, 0, PubgDraftPopup.TIER_LONXON)
		if w == null:
			weap_ok = false
			continue
		for r in w.get_requirements():
			if str(r[0]) == "requirelevel" and int(r[1]) > 50:
				weap_ok = false
	check("14 vũ khí 5x đều yêu cầu cấp <= 50", weap_ok)
	check("Tên vũ khí 5x lấy từ bảng đồ (Kiếm cấp 5)", PubgDraftPopup.weapon_name(0, PubgDraftPopup.TIER_LONXON) != PubgDraftPopup.weapon_name(0, PubgDraftPopup.TIER_PUBG))
	var w8 := PubgDraftPopup.make_weapon(0, 0)
	var req8 := 0
	for r in w8.get_requirements():
		if str(r[0]) == "requirelevel":
			req8 = int(r[1])
	check("PUBG vẫn vũ khí cấp 10 (yêu cầu cấp 81)", req8 == 81)
	var h8 := PubgDraftPopup.make_horse(1, 0)
	check("PUBG vẫn thần mã 8x", h8 != null and int(h8.get_base().get("particular", -1)) == 5)

	# Tự cộng Sức / Thân cho đủ vũ khí: Bối Trang Nỗ (Thân 110).
	var p := _profile("duong_mon")
	LonXonRules.apply_start(p)
	var crossbow := PubgDraftPopup.make_weapon(11, 0, PubgDraftPopup.TIER_LONXON)
	var pts := p.potential_points
	var dex0 := p.dexterity
	var add := PubgDraftPopup.auto_meet_weapon(p, crossbow)
	var need_dex := 0
	for r in crossbow.get_requirements():
		if str(r[0]) == "requiredex":
			need_dex = int(r[1])
	check("Tự cộng Thân vừa đủ %d" % need_dex, p.dexterity == maxi(dex0, need_dex))
	check("Trừ đúng điểm tiềm năng", p.potential_points == pts - int(add.get("str", 0)) - int(add.get("dex", 0)))
	check("Đủ rồi thì không cộng thêm", PubgDraftPopup.auto_meet_weapon(p, crossbow).is_empty())

	# Popup bộ 5x dựng được, chọn xong ghi lựa chọn riêng (không đụng PubgManager.pending_draft của PUBG).
	PubgManager.pending_draft = {}
	PubgDraftPopup.lonxon_pending_draft = {}
	var q := _profile("thieu_lam")
	LonXonRules.apply_start(q)
	var popup := PubgDraftPopup.open(self, q, Callable(), PubgDraftPopup.TIER_LONXON)
	await get_tree().process_frame
	check("Popup 5x: tiêu đề Lộn Xộn", popup._title_label.text.contains("LỘN XỘN"))
	popup._on_horse_selected(PubgDraftPopup.HORSES_5X[2])
	check("Chọn ngựa: cưỡi Ngọc Hoa Thông", q.riding and q.equipment.get(Equipment.Part.HORSE) != null
		and str(q.equipment[Equipment.Part.HORSE].get_base().get("name", "")) == "Ngọc Hoa Thông")
	popup._select_weapon(1)
	popup._on_weapon_confirmed()
	var wq: ItemInstance = q.equipment.get(Equipment.Part.WEAPON)
	check("Chọn vũ khí: Đao cấp 5", wq != null and int(wq.get_base().get("level", 0)) == 5)
	check("Ghi lựa chọn 5x", PubgDraftPopup.lonxon_pending_draft == {"horse": 3, "weapon": 1})
	check("Không ghi vào lựa chọn PUBG", PubgManager.pending_draft.is_empty())
	check("Cấp 50 cầm được vũ khí 5x (đủ Sức / Thân)", Equipment.can_use(wq, q))

func _ready() -> void:
	await _draft_tests()
	_start_tests()
	_drop_tests()
	_death_tests()
	_book_tests()
	_token_tests()
	print("--- lon_xon_rules_tests: %s ---" % ("TẤT CẢ ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)

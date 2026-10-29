extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("=== BẮT ĐẦU KIỂM THỬ TOÀN DIỆN HỆ THỐNG TRANG BỊ & STATS ===")
	print("==================================================================")
	
	test_base_attributes()
	test_visible_and_hidden_attributes()
	test_activation_matrix()
	test_horse_and_gold_set_activation()
	test_weapon_damage_and_strength_scaling()
	test_magic_attrib_table_coverage()
	test_runtime_player_sync()
	test_new_special_attributes()

	print("==================================================================")
	print("=== HOÀN TẤT KIỂM THỬ HỆ THỐNG TRANG BỊ ===")
	print("==================================================================")
	quit()

# ------------------------------------------------------------------
# TEST 1: THUỘC TÍNH GỐC (BASE ATTRIBUTES)
# ------------------------------------------------------------------
func test_base_attributes() -> void:
	print("\n--- TEST 1: THUỘC TÍNH GỐC (BASE ATTRIBUTES) ---")
	var profile := PlayerProfile.new()
	profile.element = ElementTypes.ElementType.KIM
	profile.strength = 100
	profile.dexterity = 50
	profile.vitality = 50
	profile.energy = 20
	profile.level = 10
	
	var base_stats := profile.get_combat_stats()
	var def_before := base_stats.defense
	print("Chỉ số ban đầu: Defense = %d, Min Dmg = %d, Max Dmg = %d" % [def_before, base_stats.unarmed_min_damage, base_stats.unarmed_max_damage])
	
	# Tạo 1 áo trắng có armordefense_v = 80
	var armor := ItemInstance.new()
	armor.base_index = ItemDatabase.find_base(ItemDatabase.Detail.ARMOR, 0, 1)
	armor.series = ElementTypes.ElementType.HOA
	armor.base_values = [["armordefense_v", 80], ["durability_v", 25]]
	armor.magic = []
	
	profile.equipment[Equipment.Part.BODY] = armor
	var stats_after := profile.get_combat_stats()
	print("Sau khi mặc áo (armordefense_v = 80): Defense = %d (Tăng +%d)" % [stats_after.defense, stats_after.defense - def_before])
	assert(stats_after.defense == def_before + 80, "Thuộc tính gốc phòng thủ phải cộng chính xác vào stats!")
	print("=> TEST 1 ĐẠT: Thuộc tính gốc (armordefense_v) cộng chính xác vào Player stats.")

# ------------------------------------------------------------------
# TEST 2: THUỘC TÍNH HIỆN (CHẴN) & ẨN (LẺ)
# ------------------------------------------------------------------
func test_visible_and_hidden_attributes() -> void:
	print("\n--- TEST 2: DÒNG HIỆN (0, 2, 4) & DÒNG ẨN (1, 3, 5) ---")
	# Tạo 1 nhẫn hệ HỎA với 3 dòng hiện và 3 dòng ẩn:
	# Dòng 0 (hiện): lifemax_v = 100
	# Dòng 1 (ẩn 1): fireres_p = 25
	# Dòng 2 (hiện): manamax_v = 80
	# Dòng 3 (ẩn 2): fastwalkrun_p = 15
	# Dòng 4 (hiện): attackrating_v = 120
	# Dòng 5 (ẩn 3): allres_p = 10
	var ring := ItemInstance.new()
	ring.base_index = ItemDatabase.find_base(ItemDatabase.Detail.RING, 0, 1)
	ring.series = ElementTypes.ElementType.HOA
	ring.magic = [
		{"attrib": "lifemax_v", "value": [100, 0, 0]},         # index 0: Hiện
		{"attrib": "fireres_p", "value": [25, 0, 0]},          # index 1: Ẩn 1
		{"attrib": "manamax_v", "value": [80, 0, 0]},          # index 2: Hiện
		{"attrib": "fastwalkrun_p", "value": [15, 0, 0]},      # index 3: Ẩn 2
		{"attrib": "attackrating_v", "value": [120, 0, 0]},    # index 4: Hiện
		{"attrib": "allres_p", "value": [10, 0, 0]}            # index 5: Ẩn 3
	]
	
	# Trường hợp A: Nhân vật hệ KIM (Kim KHÔNG sinh Hỏa) -> 0 dòng ẩn kích hoạt
	var p_kim := PlayerProfile.new()
	p_kim.element = ElementTypes.ElementType.KIM
	p_kim.equipment[Equipment.Part.RING1] = ring
	var counts_kim := Equipment.get_active_counts(p_kim.equipment, p_kim.element)
	print("KIM mặc Nhẫn HỎA (không tương sinh): Số dòng ẩn kích hoạt = %d" % counts_kim.get(Equipment.Part.RING1, 0))
	assert(counts_kim.get(Equipment.Part.RING1, 0) == 0, "Không tương sinh thì active phải bằng 0")
	
	var effective_kim := Equipment.get_effective_magic(ring, 0)
	print("Số dòng có hiệu lực: %d (Kỳ vọng: 3 dòng hiện)" % effective_kim.size())
	assert(effective_kim.size() == 3, "Chỉ có 3 dòng hiện hiệu lực!")
	for m in effective_kim:
		assert(m.attrib in ["lifemax_v", "manamax_v", "attackrating_v"], "Chỉ các dòng hiện mới được có mặt")
	
	# Trường hợp B: Nhân vật hệ MỘC (Mộc SINH Hỏa) -> 1 dòng ẩn kích hoạt (Ẩn 1)
	var p_moc := PlayerProfile.new()
	p_moc.element = ElementTypes.ElementType.MOC
	p_moc.equipment[Equipment.Part.RING1] = ring
	var counts_moc := Equipment.get_active_counts(p_moc.equipment, p_moc.element)
	print("MỘC mặc Nhẫn HỎA (Mộc sinh Hỏa): Số dòng ẩn kích hoạt = %d" % counts_moc.get(Equipment.Part.RING1, 0))
	assert(counts_moc.get(Equipment.Part.RING1, 0) == 1, "Mộc sinh Hỏa phải kích hoạt 1 dòng ẩn")
	
	var effective_moc := Equipment.get_effective_magic(ring, 1)
	print("Số dòng có hiệu lực: %d (Kỳ vọng: 3 dòng hiện + 1 dòng ẩn 1 = 4 dòng)" % effective_moc.size())
	assert(effective_moc.size() == 4, "Phải có 4 dòng hiệu lực!")
	assert(effective_moc[1].attrib == "fireres_p", "Dòng ẩn 1 (fireres_p) phải có hiệu lực")
	
	# Kiểm tra stats của p_moc
	var stats_moc := p_moc.get_combat_stats()
	print("Chỉ số p_moc: Kháng Hỏa = %d%% (ẩn 1), Tốc chạy = +%d%% (ẩn 2 chưa mở)" % [
		stats_moc.resist_percent.get(CombatFormulas.DamageType.FIRE, 0),
		stats_moc.move_speed_p
	])
	assert(stats_moc.resist_percent.get(CombatFormulas.DamageType.FIRE, 0) == 25, "Kháng hỏa phải tăng 25% từ dòng ẩn 1")
	assert(stats_moc.move_speed_p == 0, "Dòng ẩn 2 chưa kích hoạt thì tốc chạy không được tăng!")
	print("=> TEST 2 ĐẠT: Phân định dòng hiện và kích hoạt dòng ẩn ngũ hành hoạt động hoàn hảo.")

# ------------------------------------------------------------------
# TEST 3: MA TRẬN KÍCH HOẠT ĐỒ LẪN NHAU (ACTIVATED_BY MATRIX)
# ------------------------------------------------------------------
func test_activation_matrix() -> void:
	print("\n--- TEST 3: MA TRẬN KÍCH HOẠT ĐỒ LẪN NHAU (ACTIVATED_BY) ---")
	var profile := PlayerProfile.new()
	profile.element = ElementTypes.ElementType.THO
	
	var ring := ItemInstance.new()
	ring.base_index = ItemDatabase.find_base(ItemDatabase.Detail.RING, 0, 1)
	ring.series = ElementTypes.ElementType.HOA
	ring.magic = [
		{"attrib": "lifemax_v", "value": [50, 0, 0]},
		{"attrib": "fireres_p", "value": [10, 0, 0]},
		{"attrib": "manamax_v", "value": [50, 0, 0]},
		{"attrib": "coldres_p", "value": [15, 0, 0]},
		{"attrib": "attackrating_v", "value": [50, 0, 0]},
		{"attrib": "allres_p", "value": [20, 0, 0]}
	]
	profile.equipment[Equipment.Part.RING1] = ring
	
	# Chỉ có nhẫn: 0 kích hoạt
	var c0 := Equipment.get_active_counts(profile.equipment, profile.element)
	assert(c0.get(Equipment.Part.RING1, 0) == 0, "Chưa có đồ kích hoạt")
	
	# Mặc thêm Vũ khí hệ Mộc -> +1
	var weapon := ItemInstance.new()
	weapon.base_index = ItemDatabase.find_base(ItemDatabase.Detail.MELEE, 0, 1)
	weapon.series = ElementTypes.ElementType.MOC
	profile.equipment[Equipment.Part.WEAPON] = weapon
	var c1 := Equipment.get_active_counts(profile.equipment, profile.element)
	print("Mặc thêm Vũ khí Mộc -> Kích hoạt Ring 1 = %d (kỳ vọng 1)" % c1.get(Equipment.Part.RING1, 0))
	assert(c1.get(Equipment.Part.RING1, 0) == 1, "Vũ khí Mộc sinh Ring Hỏa -> kích hoạt 1")
	
	# Mặc thêm Mũ hệ Mộc -> +1 nữa = 2
	var helm := ItemInstance.new()
	helm.base_index = ItemDatabase.find_base(ItemDatabase.Detail.HELM, 0, 1)
	helm.series = ElementTypes.ElementType.MOC
	profile.equipment[Equipment.Part.HEAD] = helm
	var c2 := Equipment.get_active_counts(profile.equipment, profile.element)
	print("Mặc thêm Mũ Mộc -> Kích hoạt Ring 1 = %d (kỳ vọng 2)" % c2.get(Equipment.Part.RING1, 0))
	assert(c2.get(Equipment.Part.RING1, 0) == 2, "Cả Vũ khí & Mũ Mộc sinh Ring Hỏa -> kích hoạt 2")
	
	# Giờ đổi hệ nhân vật sang Mộc -> Mộc sinh Hỏa -> +1 nữa = 3 (Tối đa mở cả 3 dòng ẩn)
	profile.element = ElementTypes.ElementType.MOC
	var c3 := Equipment.get_active_counts(profile.equipment, profile.element)
	print("Nhân vật chuyển sang Mộc -> Kích hoạt Ring 1 = %d (kỳ vọng 3 - Mở hết)" % c3.get(Equipment.Part.RING1, 0))
	assert(c3.get(Equipment.Part.RING1, 0) == 3, "Nhân vật + 2 món kích hoạt -> đạt tối đa 3 dòng ẩn")
	
	var stats := profile.get_combat_stats()
	print("Chỉ số sau khi kích hoạt cả 3 dòng ẩn:")
	print("  Kháng Hỏa (ẩn 1): %d%%" % stats.resist_percent.get(CombatFormulas.DamageType.FIRE, 0))
	print("  Kháng Băng (ẩn 2): %d%%" % stats.resist_percent.get(CombatFormulas.DamageType.COLD, 0))
	print("  Kháng Tất Cả (ẩn 3): %d%%" % stats.resist_percent.get(CombatFormulas.DamageType.LIGHT, 0))
	assert(stats.resist_percent.get(CombatFormulas.DamageType.FIRE, 0) >= 30, "Kháng Hỏa = 10 (ẩn 1) + 20 (allres ẩn 3)")
	assert(stats.resist_percent.get(CombatFormulas.DamageType.COLD, 0) >= 35, "Kháng Băng = 15 (ẩn 2) + 20 (allres ẩn 3)")
	print("=> TEST 3 ĐẠT: Ma trận kích hoạt 10 ô chính xác 100% theo source gốc.")

# ------------------------------------------------------------------
# TEST 4: NGỰA & HOÀNG KIM FULL BỘ
# ------------------------------------------------------------------
func test_horse_and_gold_set_activation() -> void:
	print("\n--- TEST 4: NGOẠI LỆ NGỰA & HOÀNG KIM FULL BỘ ---")
	var profile := PlayerProfile.new()
	profile.element = ElementTypes.ElementType.KIM
	
	# Ngựa hệ Hỏa (Kim không sinh Hỏa)
	var horse := ItemInstance.new()
	horse.base_index = ItemDatabase.find_base(ItemDatabase.Detail.HORSE, 0, 1)
	horse.series = ElementTypes.ElementType.HOA
	horse.magic = [
		{"attrib": "lifemax_v", "value": [100, 0, 0]},
		{"attrib": "fastwalkrun_p", "value": [30, 0, 0]},
		{"attrib": "manamax_v", "value": [100, 0, 0]},
		{"attrib": "stuntimereduce_p", "value": [40, 0, 0]},
		{"attrib": "attackrating_v", "value": [100, 0, 0]},
		{"attrib": "allres_p", "value": [15, 0, 0]}
	]
	profile.equipment[Equipment.Part.HORSE] = horse
	var c_horse := Equipment.get_active_counts(profile.equipment, profile.element)
	print("Ngựa kích hoạt: %d dòng ẩn (Kỳ vọng: 3 dòng - luôn mở hết)" % c_horse.get(Equipment.Part.HORSE, 0))
	assert(c_horse.get(Equipment.Part.HORSE, 0) == 3, "Ngựa (Part >= HORSE) phải luôn mở hết 3 dòng ẩn!")
	
	# Kiểm tra khi riding = false -> chỉ số ngựa bị bỏ qua
	profile.riding = false
	var b_unmounted := profile.to_build()
	var stats_unmounted := CombatantStats.build(b_unmounted)
	print("Khi xuống ngựa: Tốc chạy = +%d%%, Giảm choáng = %d%%" % [stats_unmounted.move_speed_p, stats_unmounted.stun_time_reduce_p])
	assert(stats_unmounted.move_speed_p == 0, "Xuống ngựa thì thuộc tính ngựa không được tính")
	
	profile.riding = true
	var b_mounted := profile.to_build()
	var stats_mounted := CombatantStats.build(b_mounted)
	print("Khi lên ngựa: Tốc chạy = +%d%%, Giảm choáng = %d%%" % [stats_mounted.move_speed_p, stats_mounted.stun_time_reduce_p])
	assert(stats_mounted.move_speed_p == 30, "Lên ngựa phải nhận đủ thuộc tính ẩn (+30% tốc chạy)")
	assert(stats_mounted.stun_time_reduce_p == 40, "Lên ngựa phải nhận đủ 40% giảm choáng")
	print("=> TEST 4 ĐẠT: Ngựa mở 100% dòng ẩn và chỉ tính chỉ số khi cưỡi.")

# ------------------------------------------------------------------
# TEST 5: SÁT THƯƠNG VŨ KHÍ & TIỀM NĂNG SỨC MẠNH (PASS 1 & WEAPON DAMAGE)
# ------------------------------------------------------------------
func test_weapon_damage_and_strength_scaling() -> void:
	print("\n--- TEST 5: SÁT THƯƠNG VŨ KHÍ & SỨC MẠNH (KPlayer::SetNpcPhysicsDamage) ---")
	var profile := PlayerProfile.new()
	profile.element = ElementTypes.ElementType.KIM
	profile.strength = 150 # Sức mạnh = 150 -> Str/5 = 30
	profile.vitality = 50
	profile.dexterity = 50
	profile.energy = 20
	profile.level = 10
	
	# Tạo Vũ khí cận chiến: base min=50, max=100.
	# Dòng magic: weapondamagemin_v = 10, weapondamagemax_v = 20, weapondamageenhance_p = 50%
	# Dòng magic:
	# Index 0 (hiện): strength_v = 25 -> Dòng HIỆN, luôn có hiệu lực
	# Index 1 (ẩn 1): weapondamagemin_v = 10
	# Index 2 (hiện): weapondamageenhance_p = 50%
	# Index 3 (ẩn 2): weapondamagemax_v = 20
	var sword := ItemInstance.new()
	sword.base_index = ItemDatabase.find_base(ItemDatabase.Detail.MELEE, 0, 1)
	sword.series = ElementTypes.ElementType.KIM
	sword.base_values = [["weapondamagemin_v", 50], ["weapondamagemax_v", 100], ["durability_v", 30]]
	sword.magic = [
		{"attrib": "strength_v", "value": [25, 0, 0]},              # index 0: Hiện -> cộng Sức mạnh ở Pass 1
		{"attrib": "weapondamagemin_v", "value": [10, 0, 0]},        # index 1: Ẩn
		{"attrib": "weapondamageenhance_p", "value": [50, 0, 0]},    # index 2: Hiện
		{"attrib": "weapondamagemax_v", "value": [20, 0, 0]}         # index 3: Ẩn
	]
	
	profile.equipment[Equipment.Part.WEAPON] = sword
	var stats := profile.get_combat_stats()
	print("Kết quả tính toán Lực tay có vũ khí:")
	print("  Strength thực tế = %d (kỳ vọng 175)" % stats.strength)
	print("  Lực tay Min = %d (kỳ vọng 125)" % stats.unarmed_min_damage)
	print("  Lực tay Max = %d (kỳ vọng 215)" % stats.unarmed_max_damage)
	assert(stats.strength == 175, "Strength phải nhận +25 từ dòng magic vũ khí ở Pass 1")
	assert(stats.unarmed_min_damage == 125, "Lực tay min phải bằng 90 vũ khí + 35 Str/5")
	assert(stats.unarmed_max_damage == 215, "Lực tay max phải bằng 180 vũ khí + 35 Str/5")
	print("=> TEST 5 ĐẠT: Quy trình tính sát thương vũ khí và hệ số Sức mạnh/5 hoàn toàn khớp VLTK gốc.")

# ------------------------------------------------------------------
# TEST 6: PHỦ SÓNG CÁC DÒNG THUỘC TÍNH (MAGIC ATTRIB TABLE COVERAGE)
# ------------------------------------------------------------------
func test_magic_attrib_table_coverage() -> void:
	print("\n--- TEST 6: KIỂM TRA PHỦ SÓNG THUỘC TÍNH (MAGIC ATTRIB TABLE) ---")
	var magic_file := "res://data/items/magic_attribs.json"
	assert(FileAccess.file_exists(magic_file), "Phải có file magic_attribs.json")
	var fa := FileAccess.open(magic_file, FileAccess.READ)
	var magic_data: Array = JSON.parse_string(fa.get_as_text())
	fa.close()
	
	var unique_attribs := {}
	for entry in magic_data:
		var name_str: String = str(entry.get("attrib", ""))
		if name_str != "":
			unique_attribs[name_str] = unique_attribs.get(name_str, 0) + 1
			
	print("Tổng số dòng thuộc tính unique trong database game: %d" % unique_attribs.size())
	
	var dummy_stats := CombatantStats.new()
	var dummy_val := Vector3i(10, 0, 0)
	
	var supported_count := 0
	var unsupported_list := []
	
	for a_name in unique_attribs:
		var ok := false
		if a_name in MagicAttribTable.BASE_STAT_ATTRIBS:
			ok = true
		elif a_name in Equipment.NON_STAT_ATTRIBS:
			ok = true # Handled in weapon damage or durability
		else:
			ok = MagicAttribTable.apply(dummy_stats, a_name, dummy_val)
			
		if ok:
			supported_count += 1
		else:
			unsupported_list.append(a_name)
			
	print("Số thuộc tính được HỖ TRỢ và CỘNG VÀO STATS: %d / %d" % [supported_count, unique_attribs.size()])
	if not unsupported_list.is_empty():
		print("CÁC THUỘC TÍNH CHƯA ĐƯỢC XỬ LÝ (BỊ BỎ QUA): ", unsupported_list)
	else:
		print("Toàn bộ thuộc tính trong database trang bị đều được hỗ trợ!")

# ------------------------------------------------------------------
# TEST 7: KIỂM TRA ĐỒNG BỘ THỜI GIAN THỰC TRÊN NODE PLAYER (RUNTIME SYNC)
# ------------------------------------------------------------------
func test_runtime_player_sync() -> void:
	print("\n--- TEST 7: KIỂM TRA ĐỒNG BỘ THỜI GIAN THỰC (RUNTIME SYNC) TRÊN PLAYER ---")
	var profile := PlayerProfile.new()
	profile.display_name = "KiemHiepTester"
	profile.level = 10
	profile.element = ElementTypes.ElementType.KIM
	profile.strength = 100
	profile.vitality = 50
	profile.dexterity = 50
	profile.energy = 20
	
	var initial_stats := profile.get_combat_stats()
	var hp_initial := initial_stats.max_hp
	print("Profile stats HP ban đầu: %d" % hp_initial)
	
	# Đăng ký theo dõi signal equipment_changed
	var signal_fired := [0]
	profile.equipment_changed.connect(func() -> void:
		signal_fired[0] += 1
	)
	
	# Tạo 1 món đồ +300 Máu vào hành trang
	var hat := ItemInstance.new()
	hat.base_index = ItemDatabase.find_base(ItemDatabase.Detail.HELM, 0, 1)
	hat.series = ElementTypes.ElementType.THO # Thổ sinh Kim
	hat.magic = [
		{"attrib": "lifemax_v", "value": [300, 0, 0]}
	]
	profile.inventory.append(hat)
	
	# Mặc đồ từ hành trang
	var err: String = profile.equip_from_inventory(0)
	assert(err == "", "Mặc đồ phải thành công")
	print("Đã gọi profile.equip_from_inventory(0) -> Signal equipment_changed phát ra: %d lần" % signal_fired[0])
	assert(signal_fired[0] == 1, "Signal equipment_changed phải được phát ra khi mặc đồ!")
	
	var new_stats := profile.get_combat_stats()
	print("Chỉ số mới trên PlayerProfile: Max HP = %d (Tăng +%d)" % [new_stats.max_hp, new_stats.max_hp - hp_initial])
	assert(new_stats.max_hp == hp_initial + 300, "Profile stats phải tăng 300 HP")
	
	# Tháo đồ ra
	var unequip_ok := profile.unequip(Equipment.Part.HEAD)
	assert(unequip_ok, "Tháo đồ phải thành công")
	print("Đã gọi profile.unequip(HEAD) -> Signal equipment_changed phát ra: %d lần" % signal_fired[0])
	assert(signal_fired[0] == 2, "Signal equipment_changed phải được phát ra khi tháo đồ!")
	print("=> TEST 7 ĐẠT: Lỗ hổng Desync đã được khắc phục hoàn toàn bằng signal equipment_changed.")

# ------------------------------------------------------------------
# TEST 8: KIỂM TRA THUỘC TÍNH MỚI (ALLSKILL, IGNOREDEFENSE, DAMAGE2ADDMANA)
# ------------------------------------------------------------------
func test_new_special_attributes() -> void:
	print("\n--- TEST 8: KIỂM TRA CÁC THUỘC TÍNH ĐẶC BIỆT MỚI BỔ SUNG ---")
	var profile := PlayerProfile.new()
	# Dây chuyền hệ Thổ -> Cần nhân vật hệ HỎA (Hỏa sinh Thổ) để kích hoạt dòng ẩn 1 (ignoredefense_p)
	# Và cần Thắt lưng hệ HỎA để kích hoạt dòng ẩn 2 (metalskill_v)
	profile.element = ElementTypes.ElementType.HOA
	
	var amulet := ItemInstance.new()
	amulet.base_index = ItemDatabase.find_base(ItemDatabase.Detail.AMULET, 0, 1)
	amulet.series = ElementTypes.ElementType.THO
	amulet.magic = [
		{"attrib": "allskill_v", "value": [2, 0, 0]},          # index 0: Hiện
		{"attrib": "ignoredefense_p", "value": [30, 0, 0]},     # index 1: Ẩn 1 (kích hoạt bởi Hỏa nhân vật)
		{"attrib": "damage2addmana_p", "value": [20, 0, 0]},    # index 2: Hiện
		{"attrib": "metalskill_v", "value": [1, 0, 0]}         # index 3: Ẩn 2 (kích hoạt bởi Thắt lưng Hỏa)
	]
	profile.equipment[Equipment.Part.AMULET] = amulet
	
	# Mặc thêm Thắt lưng Hỏa (Belt kích hoạt Amulet)
	var belt := ItemInstance.new()
	belt.base_index = ItemDatabase.find_base(ItemDatabase.Detail.BELT, 0, 1)
	belt.series = ElementTypes.ElementType.HOA
	profile.equipment[Equipment.Part.BELT] = belt
	
	var stats := profile.get_combat_stats()
	print("Kết quả áp dụng thuộc tính đặc biệt sau khi kích hoạt ngũ hành:")
	print("  +All Skills: %d (Kỳ vọng: 2)" % stats.all_skills_bonus)
	print("  +Bỏ qua phòng thủ: %d%% (Kỳ vọng: 30%%)" % stats.ignore_defense_p)
	print("  +Sát thương chuyển hóa Mana: %d%% (Kỳ vọng: 20%%)" % stats.damage_to_mana_p)
	print("  +Tổng skill hệ Kim: %d (2 all + 1 Kim = 3)" % stats.get_skill_bonus(ElementTypes.ElementType.KIM))
	
	assert(stats.all_skills_bonus == 2, "allskill_v phải cộng 2 cấp skill")
	assert(stats.ignore_defense_p == 30, "ignoredefense_p phải cộng 30% xuyên giáp khi kích hoạt ẩn 1")
	assert(stats.damage_to_mana_p == 20, "damage2addmana_p phải cộng 20% chuyển hóa mana")
	assert(stats.get_skill_bonus(ElementTypes.ElementType.KIM) == 3, "Kỹ năng Kim phải được hưởng cả allskill lẫn metalskill khi kích hoạt ẩn 2")
	print("=> TEST 8 ĐẠT: Toàn bộ thuộc tính đặc biệt đã hoạt động và cộng chính xác vào stats.")

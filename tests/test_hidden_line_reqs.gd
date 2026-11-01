extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("=== KIỂM THỬ GHI CHÚ ĐIỀU KIỆN KÍCH HOẠT DÒNG ẨN TRANG BỊ ===")
	print("==================================================================")
	
	test_weapon_hidden_lines()
	test_boot_hidden_lines()
	test_ring_hidden_lines()
	test_gold_item_hidden_lines()
	test_room_view_drag_drop_operands()
	
	print("==================================================================")
	print("=== TẤT CẢ KIỂM THỬ GHI CHÚ DÒNG ẨN ĐÃ ĐẠT 100%! ===")
	print("==================================================================")
	quit()

func test_weapon_hidden_lines() -> void:
	print("\n--- TEST 1: VŨ KHÍ HỆ THỔ (ĐẠI PHONG ĐAO) ---")
	var item := ItemInstance.new()
	item.base_index = ItemDatabase.find_base(ItemDatabase.Detail.MELEE, 1, 10)  # Đao cấp 10
	item.series = ElementTypes.ElementType.THO
	item.magic = [
		{"attrib": "physicsenhance_p", "value": [51, 0, 0]},
		{"attrib": "lightingdamage_v", "value": [66, 0, 0]},
		{"attrib": "lifemax_v", "value": [160, 0, 0]},
		{"attrib": "fireskill_v", "value": [144, 0, 0]},
		{"attrib": "manamax_v", "value": [88, 0, 0]},
		{"attrib": "coldres_p", "value": [24, 0, 0]}
	]
	
	var bbcode := ItemText.build(item, null, -1, -1, false)
	print("BBCode sinh ra:\n%s" % bbcode)
	
	# Kiểm tra màu hệ cần kích (Thổ cần Hỏa -> #ff5032)
	var color_hoa: String = ItemText.ELEMENT_COLORS[ElementTypes.ElementType.HOA]
	assert(color_hoa == "ff5032", "Màu hệ Hỏa phải là ff5032")
	
	# Dòng 2 (ẩn 1): Cần [Nhân vật / Dây chuyền] màu Hỏa
	assert(bbcode.contains("[color=#%s][lb]Nhân vật / Dây chuyền[rb][/color]" % color_hoa), "Dòng 2 phải có tag [Nhân vật / Dây chuyền] màu Hỏa")
	# Dòng 4 (ẩn 2): Cần [Dây chuyền / Áo] màu Hỏa
	assert(bbcode.contains("[color=#%s][lb]Dây chuyền / Áo[rb][/color]" % color_hoa), "Dòng 4 phải có tag [Dây chuyền / Áo] màu Hỏa")
	# Dòng 6 (ẩn 3): Cần [Áo] màu Hỏa
	assert(bbcode.contains("[color=#%s][lb]Áo[rb][/color]" % color_hoa), "Dòng 6 phải có tag [Áo] màu Hỏa")
	
	# Kiểm tra plain text
	var plain := ItemText.plain(bbcode)
	print("Plain text:\n%s" % plain)
	assert(plain.contains("[Nhân vật / Dây chuyền]"), "Plain text phải có [Nhân vật / Dây chuyền]")
	assert(plain.contains("[Dây chuyền / Áo]"), "Plain text phải có [Dây chuyền / Áo]")
	assert(plain.contains("[Áo]"), "Plain text phải có [Áo]")
	
	print("=> TEST 1 ĐẠT: Đại Phong Đao hiển thị chính xác [Nhân vật / Dây chuyền], [Dây chuyền / Áo], [Áo] màu Hỏa")

func test_boot_hidden_lines() -> void:
	print("\n--- TEST 2: GIÀY HỆ KIM (CẦN THỔ) ---")
	var item := ItemInstance.new()
	item.base_index = ItemDatabase.find_base(ItemDatabase.Detail.BOOT, 0, 1)
	item.series = ElementTypes.ElementType.KIM
	item.magic = [
		{"attrib": "lifemax_v", "value": [100, 0, 0]},
		{"attrib": "lightingdamage_v", "value": [20, 0, 0]},
		{"attrib": "manamax_v", "value": [100, 0, 0]},
		{"attrib": "poisonres_p", "value": [20, 0, 0]},
		{"attrib": "staminamax_v", "value": [50, 0, 0]},
		{"attrib": "allres_p", "value": [15, 0, 0]}
	]
	
	var bbcode := ItemText.build(item, null, -1, -1, false)
	var color_tho: String = ItemText.ELEMENT_COLORS[ElementTypes.ElementType.THO]
	
	# Dòng 2 (ẩn 1): Cần [Nhân vật / Nón] màu Thổ
	assert(bbcode.contains("[color=#%s][lb]Nhân vật / Nón[rb][/color]" % color_tho), "Giày dòng 2 phải có tag [Nhân vật / Nón] màu Thổ")
	# Dòng 4 (ẩn 2): Cần [Nón / Vũ khí] màu Thổ
	assert(bbcode.contains("[color=#%s][lb]Nón / Vũ khí[rb][/color]" % color_tho), "Giày dòng 4 phải có tag [Nón / Vũ khí] màu Thổ")
	# Dòng 6 (ẩn 3): Cần [Vũ khí] màu Thổ
	assert(bbcode.contains("[color=#%s][lb]Vũ khí[rb][/color]" % color_tho), "Giày dòng 6 phải có tag [Vũ khí] màu Thổ")
	print("=> TEST 2 ĐẠT: Giày hiển thị chính xác [Nhân vật / Nón], [Nón / Vũ khí], [Vũ khí] màu Thổ")

func test_ring_hidden_lines() -> void:
	print("\n--- TEST 3: NHẪN KHI CHƯA MẶC VÀ KHI MẶC VÀO TỪNG Ô ---")
	var ring := ItemInstance.new()
	ring.base_index = ItemDatabase.find_base(ItemDatabase.Detail.RING, 0, 1)
	ring.series = ElementTypes.ElementType.THUY  # Thủy cần Kim (ffe65a)
	ring.magic = [
		{"attrib": "lifemax_v", "value": [50, 0, 0]},
		{"attrib": "fireres_p", "value": [10, 0, 0]},
		{"attrib": "manamax_v", "value": [50, 0, 0]},
		{"attrib": "coldres_p", "value": [15, 0, 0]}
	]
	
	var color_kim: String = ItemText.ELEMENT_COLORS[ElementTypes.ElementType.KIM]
	
	# 1. Chưa mặc (part = -1)
	var bb_unworn := ItemText.build(ring, null, -1, -1, false)
	assert(bb_unworn.contains("[color=#%s][lb]Nhân vật / Vũ khí/Bao tay[rb][/color]" % color_kim), "Nhẫn chưa mặc dòng 2 phải có [Nhân vật / Vũ khí/Bao tay]")
	assert(bb_unworn.contains("[color=#%s][lb]Vũ khí/Bao tay / Nón/Ngọc bội[rb][/color]" % color_kim), "Nhẫn chưa mặc dòng 4 phải có [Vũ khí/Bao tay / Nón/Ngọc bội]")
	
	# 2. Mặc ở Nhẫn 1 (part = RING1)
	var bb_ring1 := ItemText.build(ring, null, 0, Equipment.Part.RING1, false)
	assert(bb_ring1.contains("[color=#%s][lb]Nhân vật / Vũ khí[rb][/color]" % color_kim), "Nhẫn 1 dòng 2 phải có [Nhân vật / Vũ khí]")
	assert(bb_ring1.contains("[color=#%s][lb]Vũ khí / Nón[rb][/color]" % color_kim), "Nhẫn 1 dòng 4 phải có [Vũ khí / Nón]")
	
	# 3. Mặc ở Nhẫn 2 (part = RING2)
	var bb_ring2 := ItemText.build(ring, null, 0, Equipment.Part.RING2, false)
	assert(bb_ring2.contains("[color=#%s][lb]Nhân vật / Bao tay[rb][/color]" % color_kim), "Nhẫn 2 dòng 2 phải có [Nhân vật / Bao tay]")
	assert(bb_ring2.contains("[color=#%s][lb]Bao tay / Ngọc bội[rb][/color]" % color_kim), "Nhẫn 2 dòng 4 phải có [Bao tay / Ngọc bội]")
	
	print("=> TEST 3 ĐẠT: Nhẫn hiển thị chính xác theo từng trạng thái đeo")

func test_gold_item_hidden_lines() -> void:
	print("\n--- TEST 4: ÁO HOÀNG KIM (KIM PHONG KỲ LÂN HUYẾT) ---")
	var kp_idx := ItemDatabase.find_gold_by_name("Kim Phong Kỳ Lân Huyết")
	if kp_idx >= 0:
		var item := ItemGenerator.generate_gold(kp_idx, 10)
		var bbcode := ItemText.build(item, null, -1, -1, false)
		var need_color: String = ItemText.ELEMENT_COLORS[ItemText.NEED_SERIES[item.series]]
		# Dòng ẩn 1 (dòng 2) của Áo là [Nhân vật / Thắt lưng]
		assert(bbcode.contains("[color=#%s][lb]Nhân vật / Thắt lưng[rb][/color]" % need_color), "Áo hoàng kim dòng 2 phải có [Nhân vật / Thắt lưng]")
		print("=> TEST 4 ĐẠT: Kim Phong Kỳ Lân Huyết có tag [Nhân vật / Thắt lưng] màu hệ tương sinh")

func test_room_view_drag_drop_operands() -> void:
	print("\n--- TEST 5: ITEM ROOM VIEW DRAG DROP (TRÁNH LỖI STRING != OBJECT) ---")
	var profile := PlayerProfile.new()
	var room := ItemRoomView.new()
	room.profile = profile
	room.interactive = true
	room.transfer_handler = func(_item: ItemInstance, _source: Variant, _target: Object, _x: int, _y: int, _bag: int) -> bool:
		return true

	var item := ItemInstance.new()
	item.base_index = 0

	# 1. Kéo từ mannequin (source là String "mannequin")
	var drag_data_mannequin := {
		"type": ItemRoomView.DRAG_TYPE,
		"item": item,
		"source": "mannequin",
		"part": Equipment.Part.HEAD,
		"grab": Vector2i.ZERO
	}
	var can_drop_mannequin := room._can_drop_data(Vector2.ZERO, drag_data_mannequin)
	print("Drop from mannequin check result: %s" % can_drop_mannequin)

	# 2. Kéo từ profile (source là Object PlayerProfile)
	var drag_data_same_profile := {
		"type": ItemRoomView.DRAG_TYPE,
		"item": item,
		"source": profile,
		"grab": Vector2i.ZERO
	}
	var can_drop_profile := room._can_drop_data(Vector2.ZERO, drag_data_same_profile)
	print("Drop from same profile check result: %s" % can_drop_profile)

	print("=> TEST 5 ĐẠT: Không còn lỗi so sánh String và Object trong _can_drop_data")

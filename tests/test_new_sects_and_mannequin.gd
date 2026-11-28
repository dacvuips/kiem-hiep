extends Node

func _ready() -> void:
	print("--- TEST NEW SECTS EQUIPMENT & MANNEQUIN ---")
	
	# 1. Test Gold Equipment data of new sects
	var total_gold := ItemDatabase.get_gold_count()
	assert(total_gold > 0, "Gold equipment database must be loaded")
	
	# Menpai 10: Hoa Son, 11: Vu Hon, 12: Tieu Dao, 13: Duong Mon
	var counts := {10: 0, 11: 0, 12: 0, 13: 0}
	for i in total_gold:
		var item_dict := ItemDatabase.get_gold(i)
		var mp: int = int(item_dict.get("menpai", -1))
		if mp in counts:
			counts[mp] += 1
	
	print("Gold equipment counts by sect:")
	print("  Hoa Son (10): %d items" % counts[10])
	print("  Vu Hon (11): %d items" % counts[11])
	print("  Tieu Dao (12): %d items" % counts[12])
	print("  Duong Mon (13): %d items" % counts[13])
	
	assert(counts[10] >= 10, "Hoa Son must have gold items")
	assert(counts[11] >= 20, "Vu Hon must have 20 gold items (Blade + Shield sets)")
	assert(counts[12] >= 20, "Tieu Dao must have 20 gold items (Sword + Qin sets)")
	assert(counts[13] >= 20, "Duong Mon must have 20 gold items (Bow + Spear sets)")
	print("PASS: New sects gold equipment loaded correctly")
	
	# 2. Test PlayerProfile appearance with new weapons
	var profile := PlayerProfile.new()
	profile.gender = PlayerProfile.Gender.MALE
	
	# Vũ Hồn Đao Thuẫn (Detail 0: Melee, Particular 7, Level 10)
	var vuhon_item := ItemGenerator.generate(0, 7, 10, 0, [1, 1], 10, 101)
	assert(vuhon_item != null, "Vu Hon weapon item instance created")
	profile.equipment[Equipment.Part.WEAPON] = vuhon_item
	
	var look := Equipment.get_appearance(profile.equipment, "male", false, false)
	print("Vu Hon look: helm=%s, armor=%s, weapon=%s, horse=%s" % [look.helm, look.armor, look.weapon, look.horse])
	assert(int(look.weapon) == 161, "Vu Hon Blade/Shield weapon res should be 161")
	print("PASS: Vu Hon weapon appearance is 161 (Dao Thuan)")
	
	# Vũ Hồn Thuẫn Đao (Detail 0: Melee, Particular 8, Level 10)
	var vuhon_shield_blade := ItemGenerator.generate(0, 8, 10, 0, [1, 1], 10, 102)
	assert(vuhon_shield_blade != null, "Vu Hon shield blade item instance created")
	profile.equipment[Equipment.Part.WEAPON] = vuhon_shield_blade
	look = Equipment.get_appearance(profile.equipment, "male", false, false)
	print("Vu Hon Shield/Blade look: weapon=%s" % look.weapon)
	assert(int(look.weapon) == 162, "Vu Hon Shield/Blade weapon res should be 162")
	print("PASS: Vu Hon weapon appearance is 162 (Thuan Dao)")
	
	# Dương Môn Cung (Detail 1: Range, Particular 4, Level 10)
	var duongmon_bow := ItemGenerator.generate(1, 4, 10, 0, [1, 1], 10, 103)
	assert(duongmon_bow != null, "Duong Mon bow item instance created")
	profile.equipment[Equipment.Part.WEAPON] = duongmon_bow
	look = Equipment.get_appearance(profile.equipment, "male", false, false)
	print("Duong Mon Bow look: weapon=%s" % look.weapon)
	assert(int(look.weapon) == 164, "Duong Mon Bow weapon res should be 164")
	print("PASS: Duong Mon bow appearance is 164 (Cung)")
	
	# Dương Môn Thương (Detail 0: Melee, Particular 3, Level 10)
	var duongmon_spear := ItemGenerator.generate(0, 3, 10, 0, [1, 1], 10, 104)
	assert(duongmon_spear != null, "Duong Mon spear item instance created")
	profile.equipment[Equipment.Part.WEAPON] = duongmon_spear
	look = Equipment.get_appearance(profile.equipment, "male", false, false)
	print("Duong Mon Spear look: weapon=%s" % look.weapon)
	assert(int(look.weapon) == 24, "Duong Mon Spear weapon res should be 24")
	print("PASS: Duong Mon spear appearance is 24 (Thuong)")
	
	# 3. Test Riding and Horse stats
	# Tạo ngựa: Detail 10: Horse, Particular 0, Level 1
	var horse_item := ItemGenerator.generate(10, 0, 1, 0, [1, 1], 10, 105)
	if horse_item != null:
		profile.equipment[Equipment.Part.HORSE] = horse_item
		profile.riding = true
		var look_ride := Equipment.get_appearance(profile.equipment, "male", profile.riding, false)
		assert(int(look_ride.horse) >= 0, "Horse look should be >= 0 when riding")
		
		# Stats khi xuống ngựa
		profile.riding = false
		var look_unride := Equipment.get_appearance(profile.equipment, "male", profile.riding, false)
		assert(int(look_unride.horse) == -1, "Horse look should be -1 when not riding")
		print("PASS: Riding toggle appearance correctly reflects horse")
	
	# 4. CharacterHub: khung Trang bị không có mannequin
	var hub_scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Khung Trang bị không còn nhân vật mặc đồ / nút Xoay / nút Lên ngựa (đè lên ô đồ).
	for n in ["EquipMannequin", "RotateMannequinBtn", "RideToggleBtn"]:
		assert(hub.get_node_or_null("%EquipBackground/" + n) == null, n + " should not exist")
	print("PASS: Equip panel has no mannequin overlay")
	
	print("--- ALL NEW SECTS & MANNEQUIN TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit()

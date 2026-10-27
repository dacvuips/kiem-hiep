extends Node

func _ready() -> void:
	print("--- TEST HUB DRAG & DROP ---")
	var profile := PlayerProfile.new()
	profile.display_name = "KiemHiepTester"
	profile.gold = 50000

	var hub_scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)

	await get_tree().process_frame
	await get_tree().process_frame

	# 1. Add equipment directly to hub._profile
	var sword := ItemGenerator.generate(0, 0, 1, 0, [1, 1], 10, 123)
	assert(sword != null, "Must generate sword")
	hub._profile.add_item(sword)

	var armor := ItemGenerator.generate(2, 0, 1, 0, [1, 1], 10, 124)
	assert(armor != null, "Must generate armor")
	hub._profile.add_item(armor)

	# Test 1: Equip sword via drop handler directly (simulating drop)
	var sword_data = {"type": ItemRoomView.DRAG_TYPE, "item": sword, "source": hub._profile, "grab": Vector2i.ZERO}
	assert(hub._can_drop_on_equip_slot(Vector2.ZERO, sword_data, Equipment.Part.WEAPON), "Must allow dropping sword on WEAPON slot")
	hub._drop_on_equip_slot(Vector2.ZERO, sword_data, Equipment.Part.WEAPON)
	await get_tree().process_frame
	assert(hub._profile.equipment.get(Equipment.Part.WEAPON) == sword, "Sword must be equipped on character")
	print("PASS: Drop item onto equipment slot works")

	# Test 2: Unequip sword by dragging back to inventory (simulating transfer_handler)
	var free_spot = hub._profile.find_free_spot(sword.get_size(), 0)
	assert(free_spot.x >= 0, "Must have free spot for sword")
	var can_unequip = hub._room.transfer_handler.call(sword, "mannequin", hub._profile, free_spot.x, free_spot.y, 0)
	assert(can_unequip, "Must allow unequipping sword back into inventory")
	assert(hub._profile.equipment.get(Equipment.Part.WEAPON) == null, "Weapon slot must be empty")
	assert(hub._profile.inventory.has(sword), "Inventory must have sword back")
	print("PASS: Unequip item back to inventory works")

	# Ensure storage is unlocked for testing
	hub._profile.security_locked = false

	# Test 3: Transfer to Storage
	var storage_spot = hub._profile.storage.find_free_spot(armor.get_size(), 0)
	assert(storage_spot.x >= 0, "Must have free spot in storage")
	var can_store = StorageService.transfer(hub._profile, armor, hub._profile, hub._profile.storage, storage_spot.x, storage_spot.y, 0)
	assert(can_store, "Must allow transferring armor to storage")
	assert(hub._profile.storage.owns(armor), "Storage must own armor")
	assert(not hub._profile.inventory.has(armor), "Inventory must no longer have armor")
	print("PASS: Transfer item from inventory to storage works")

	# Test 4: Transfer from Storage back to Inventory via room transfer_handler
	var armor_spot = hub._profile.find_free_spot(armor.get_size(), 0)
	assert(armor_spot.x >= 0, "Must have free spot for armor")
	var can_take = hub._room.transfer_handler.call(armor, hub._profile.storage, hub._profile, armor_spot.x, armor_spot.y, 0)
	assert(can_take, "Must allow transferring armor from storage to inventory")
	assert(not hub._profile.storage.owns(armor), "Storage must no longer own armor")
	assert(hub._profile.inventory.has(armor), "Inventory must have armor back")
	print("PASS: Transfer item from storage to inventory works")

	# Test 5: SkillBookView hotbar drag
	hub._profile.sect_id = "cai_bang"
	var all_skills: Array[SkillDefinition] = hub._load_all_skills()
	var sb := SkillBookView.new(hub._profile, all_skills)
	add_child(sb)
	await get_tree().process_frame

	var test_skill: SkillDefinition = null
	for s in all_skills:
		if s.can_assign_to_hotbar():
			test_skill = s
			break
	if test_skill:
		var skill_drag = SkillBarUI.make_drag_data(test_skill.id, SkillBarUI.FROM_BOOK)
		assert(sb._can_drop_wheel(Vector2.ZERO, skill_drag, 0), "Must allow dropping skill on wheel slot 0")
		sb._drop_wheel(Vector2.ZERO, skill_drag, 0)
		assert(hub._profile.hotbar_skill_ids[0] == test_skill.id, "Skill must be assigned to slot 0")
		print("PASS: Skill drag and drop to wheel slot works")
	sb.queue_free()

	hub.queue_free()
	print("--- ALL HUB DRAG & DROP TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)

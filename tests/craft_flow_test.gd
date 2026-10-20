extends Node

func _ready() -> void:
	print("=== RUNNING CRAFT FLOW TEST ===")
	var profile := PlayerProfile.new()
	profile.gold = 100000

	# 1. Add 5 Killer tokens (6_1_399) level 90
	for i in 5:
		var token := ItemGenerator.generate_misc("6_1_399", 90, i)
		token.ensure_uid()
		profile.add_item(token)

	assert(profile.inventory.size() == 5, "Profile should have 5 tokens")

	# 2. Setup ItemRoomView
	var room := ItemRoomView.new()
	add_child(room)
	room.setup(profile)

	var initial_item_count := 0
	for c in room.get_children():
		if c is ItemSlotButton:
			initial_item_count += 1
	print("Step 1 - Bag initial items displayed: ", initial_item_count)
	assert(initial_item_count == 5, "Bag should display all 5 tokens initially")

	# 3. Create CompoundWindow and switch to Refine -> Killer
	var win := CompoundWindow.new()
	win._profile = profile
	add_child(win)
	win._refine_sub = CompoundWindow.RefineSub.KILLER
	win._switch_tab(CompoundWindow.Tab.REFINE)

	# 4. Put 5 tokens into craft slots
	for it in profile.inventory:
		win._put(it)

	var used := win.get_used_counts()
	print("Step 2 - Slotted items count: ", used.size())
	assert(win._slots.filter(func(s): return s != null).size() == 5, "All 5 slots should be filled")

	# Update room with slotted counts
	room.slotted_counts = win.get_used_counts()
	room.rebuild()

	var after_slot_count := 0
	for c in room.get_children():
		if c is ItemSlotButton:
			after_slot_count += 1
	print("Step 3 - Bag items displayed while slotted: ", after_slot_count)
	assert(after_slot_count == 0, "Bag should NOT display any tokens while they are in craft slots!")

	# 5. Remove 1 item from slot
	win.remove_slot_item(0)
	room.slotted_counts = win.get_used_counts()
	room.rebuild()

	var after_remove_count := 0
	for c in room.get_children():
		if c is ItemSlotButton:
			after_remove_count += 1
	print("Step 4 - Bag items displayed after removing 1 from slot: ", after_remove_count)
	assert(after_remove_count == 1, "The removed token should immediately reappear in the bag!")

	# Put it back
	for it in profile.inventory:
		if not win._slots.has(it):
			win._put(it)
			break

	assert(win._slots.filter(func(s): return s != null).size() == 5, "All 5 slots filled again")
	room.slotted_counts = win.get_used_counts()
	room.rebuild()

	# 6. Call _make() to compound Sát Thủ Giản
	win._make()
	print("Step 5 - Message after make: ", win._message.text)

	var found_sword := false
	for it in profile.inventory:
		if it.misc_id == "6_1_400":
			found_sword = true
			print("  Found Sát Thủ Giản: ", it.get_display_name(), " lvl=", it.get_level(), " series=", it.series)

	assert(found_sword, "Sát Thủ Giản (6_1_400) MUST be in profile.inventory after craft!")
	assert(profile.inventory.size() == 1, "Inventory should only have the 1 Sát Thủ Giản (5 tokens consumed)")

	# Check that slots in CompoundWindow are cleared
	var filled_slots_after := win._slots.filter(func(s): return s != null).size()
	print("Step 6 - Filled craft slots after make: ", filled_slots_after)
	assert(filled_slots_after == 0, "Craft slots should be empty after craft!")

	# Check that room renders the new sword
	room.slotted_counts = win.get_used_counts()
	room.rebuild()
	var final_bag_count := 0
	for c in room.get_children():
		if c is ItemSlotButton:
			final_bag_count += 1
	print("Step 7 - Bag items displayed after craft: ", final_bag_count)
	assert(final_bag_count == 1, "Bag should display the newly crafted Sát Thủ Giản!")

	print("=== ALL CRAFT FLOW TESTS PASSED! ===")
	get_tree().quit(0)

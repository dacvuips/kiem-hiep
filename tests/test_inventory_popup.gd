extends Node

func _ready() -> void:
	print("--- BEGIN TEST INVENTORY POPUP ---")
	var profile := PlayerProfile.new()
	profile.display_name = "TestPlayer"
	profile.gold = 1250000
	profile.jade = 888

	var popup := InventoryPopup.open(self, profile, func() -> void: pass, false)
	assert(popup != null, "popup should instantiate")
	await get_tree().process_frame
	await get_tree().process_frame

	var frame: Control = popup.get_node("%Frame")
	assert(frame != null, "Frame should exist")
	print("Popup Frame size: ", frame.size, " position: ", frame.position)

	var title: Label = popup.get_node("Frame/Root/TitleBar/TitleRow/Title")
	assert(title != null, "Title should exist")
	assert(title.text == "Hành trang", "Title text matches")
	print("Title verified: ", title.text)

	var close_btn = popup.get_node("%CloseButton")
	assert(close_btn != null, "CloseButton should exist")

	var gold_val: Label = popup.get_node("%GoldValue")
	var jade_val: Label = popup.get_node("%JadeValue")
	assert(gold_val != null and jade_val != null, "Gold and Jade labels must exist")
	print("Gold text: ", gold_val.text)
	print("Jade text: ", jade_val.text)
	assert(gold_val.text == "125 vạn Lượng", "Gold text formatted correctly: " + gold_val.text)
	assert(jade_val.text == "888", "Jade text formatted correctly: " + jade_val.text)

	var bag_tabs: Control = popup.get_node("%BagTabs")
	assert(bag_tabs.get_child_count() == 6, "Must have 6 bag tabs")
	print("Bag tabs count: ", bag_tabs.get_child_count())

	# Test tab switching
	popup._select_bag(1)
	assert(popup._bag == 1, "Bag switched to 1")

	# Test test buttons
	assert(popup.has_node("%SortButton"), "SortButton exists")
	assert(popup.has_node("%ShopButton"), "ShopButton exists")
	assert(popup.has_node("%CraftButton"), "CraftButton exists")
	assert(popup.has_node("%TestAddButton"), "TestAddButton exists")
	assert(popup.has_node("%TestCreateButton"), "TestCreateButton exists")
	assert(popup.has_node("%TestMaskButton"), "TestMaskButton exists")
	assert(popup.has_node("%TestMantleButton"), "TestMantleButton exists")

	# Test adding masks via test button
	popup._on_test_mask_pressed()
	var masks := 0
	for item in profile.inventory:
		if item.get_detail() == ItemDatabase.Detail.MASK:
			masks += 1
	assert(masks == 5, "Added 5 masks successfully, found: " + str(masks))
	print("Mask count in inv: ", masks)

	# Test adding mantles via test button
	popup._on_test_mantle_pressed()
	var mantles := 0
	for item in profile.inventory:
		if item.get_detail() == ItemDatabase.Detail.MANTLE:
			mantles += 1
	assert(mantles == 5, "Added 5 mantles successfully, found: " + str(mantles))
	print("Mantle count in inv: ", mantles)

	# Capture screenshot for visual inspection
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/19b274a4-94f9-4e81-a9b0-97af13a4db76/inventory_popup_rendered.png")
		print("SCREENSHOT_SAVED")

	popup.queue_free()
	await get_tree().process_frame
	print("--- TEST INVENTORY POPUP PASSED COMPLETELY ---")
	get_tree().quit(0)

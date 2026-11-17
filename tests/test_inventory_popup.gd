extends Node

func _ready() -> void:
	print("--- BEGIN TEST INVENTORY POPUP ---")
	var profile := PlayerProfile.new()
	profile.display_name = "TestPlayer"
	profile.gold = 1250000
	profile.xu = 500
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

	var gold_val: Label = popup.get_node_or_null("%GoldValue")
	var xu_val: Label = popup.get_node_or_null("%XuValue")
	var jade_val: Label = popup.get_node_or_null("%JadeValue")
	assert(gold_val == null and xu_val == null and jade_val == null, "Tiền tệ đã bị xóa khỏi túi hành trang")
	assert(InventoryPopup.format_money(1250000) == "125 vạn", "Format money works")

	var bag_tabs: Control = popup.get_node("%BagTabs")
	assert(bag_tabs.get_child_count() == 5, "Must have 5 bag tabs")
	print("Bag tabs count: ", bag_tabs.get_child_count())

	# Test tab switching
	popup._select_bag(1)
	assert(popup._bag == 1, "Bag switched to 1")

	# Test test buttons
	assert(popup.has_node("%SortButton"), "SortButton exists")
	assert(popup.has_node("%SellButton"), "SellButton exists")
	assert(popup.has_node("%ShopButton"), "ShopButton exists")
	assert(not popup.has_node("%TestCreateButton"), "TestCreateButton should not exist in Inventory UI (moved to GM)")

	# Test SellButton Quick Sell Mode
	var sell_btn: Button = popup.get_node("%SellButton")
	assert(sell_btn.text == "Bán", "SellButton initial text is Bán")
	assert(not popup._quick_sell_mode, "Quick sell mode initially false")

	sell_btn.emit_signal("pressed")
	assert(popup._quick_sell_mode, "Quick sell mode is active after click")
	assert(sell_btn.text == "Đang Bán", "SellButton shows Đang Bán when active")

	# Test adding masks via test button
	popup._on_test_mask_pressed()
	var masks := 0
	for item in profile.inventory:
		if item.get_detail() == ItemDatabase.Detail.MASK:
			masks += 1
	assert(masks == 5, "Added 5 masks successfully, found: " + str(masks))
	print("Mask count in inv: ", masks)

	# Nhấp vào 1 món đồ khi đang ở chế độ bán nhanh -> bán ngay lập tức
	var item_to_sell = profile.inventory[0]
	var initial_gold := profile.gold
	var expected_sale_price: int = item_to_sell.get_sale_price()
	var initial_inv_count := profile.inventory.size()

	popup._on_item_pressed(item_to_sell)
	assert(profile.inventory.size() == initial_inv_count - 1, "Item removed after quick sell")
	assert(profile.gold == initial_gold + expected_sale_price, "Gold increased by sale price")
	assert(popup._quick_sell_mode, "Quick sell mode remains active for chaining sells")
	print("Quick sell test passed! Gold increased by: ", expected_sale_price)

	# Bấm nút Bán lần nữa để tắt chế độ bán
	sell_btn.emit_signal("pressed")
	assert(not popup._quick_sell_mode, "Quick sell mode disabled after second click")
	assert(sell_btn.text == "Bán", "SellButton text reverted to Bán")

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

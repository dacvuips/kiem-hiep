extends Node

func _ready() -> void:
	print("--- TEST STORAGE VISUAL IN CHARACTER HUB ---")
	var hub_scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)

	await get_tree().process_frame
	await get_tree().process_frame

	# Switch to Trang Bị (Inventory view)
	if hub.has_method("_set_view"):
		hub._set_view("equipment")
		for i in 3:
			await get_tree().process_frame

	# Simulate clicking %StorageButton in InvActions
	assert(hub.has_node("%StorageButton"), "CharacterHub must have %StorageButton")
	var btn: Button = hub.get_node("%StorageButton")
	btn.pressed.emit()

	# Wait a couple of frames for layout and positioning
	for i in 5:
		await get_tree().process_frame

	# Find StorageWindow
	var st: StorageWindow = null
	for w in get_tree().get_nodes_in_group("social_windows"):
		if w is StorageWindow and is_instance_valid(w):
			st = w
			break

	assert(st != null, "StorageWindow must be open")
	print("StorageWindow pos: ", st.position, ", size: ", st.size)
	print("Storage tab count: ", st._box_tabs.get_child_count())
	for i in st._box_tabs.get_child_count():
		var b: Button = st._box_tabs.get_child(i)
		print("  Tab %d: text='%s', disabled=%s" % [i, b.text, b.disabled])

	# Check bottom button row
	var buttons_found: Array[String] = []
	for c in st.body.get_children():
		if c is HBoxContainer and c != st._box_tabs and c != st._store_row:
			for b in c.get_children():
				if b is Button:
					buttons_found.append(b.text)
	print("Buttons found in StorageWindow: ", buttons_found)

	# Capture image
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/d54a99ab-ec36-4726-b82d-55b33245c0ff/storage_visual.png")
		print("Saved screenshot to storage_visual.png")

	print("--- TEST STORAGE VISUAL FINISHED SUCCESSFULLY ---")
	get_tree().quit(0)

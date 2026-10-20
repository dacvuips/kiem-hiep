extends SceneTree

const TouchScrollHelper = preload("res://ui/common/touch_scroll_helper.gd")

func _init() -> void:
	print("TEST: Starting touch scroll & draggable test...")
	test_draggable_disabled_in_hub()
	test_touch_scroll_drag_and_tap()
	print("TEST: ALL TESTS PASSED!")
	quit()

func test_draggable_disabled_in_hub() -> void:
	var hub := Control.new()
	hub.name = "CharacterHub"
	root.add_child(hub)

	var win := SocialWindow.new("Test", "Sub", 400.0)
	hub.add_child(win)

	assert(win.draggable == false, "Window inside CharacterHub must have draggable = false!")
	print("PASS: Window inside CharacterHub has draggable = false")

	var orig_pos := win.position
	# Simulate drag on bar
	var event_down := InputEventMouseButton.new()
	event_down.button_index = MOUSE_BUTTON_LEFT
	event_down.pressed = true
	win._gui_input(event_down)

	var event_motion := InputEventMouseMotion.new()
	event_motion.relative = Vector2(100, 100)
	win._gui_input(event_motion)

	assert(win.position == orig_pos, "Window inside CharacterHub must NOT move when dragged!")
	print("PASS: Window inside CharacterHub did not move when dragged")

	hub.queue_free()

func test_touch_scroll_drag_and_tap() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 200)
	scroll.size = Vector2(300, 200)
	scroll.position = Vector2(50, 50)
	root.add_child(scroll)

	var vbox := VBoxContainer.new()
	scroll.add_child(vbox)

	var clicked := false
	var btn := Button.new()
	btn.text = "Button 1"
	btn.custom_minimum_size = Vector2(280, 50)
	btn.pressed.connect(func(): clicked = true)
	vbox.add_child(btn)

	for i in range(20):
		var b := Button.new()
		b.text = "Item %d" % i
		b.custom_minimum_size = Vector2(280, 50)
		vbox.add_child(b)

	var helper = TouchScrollHelper.attach(scroll, scroll)
	assert(helper != null, "TouchScrollHelper must attach successfully")
	print("PASS: TouchScrollHelper attached")

	# Simulate drag motion on helper
	helper._is_touching = true
	helper._touch_index = -1
	helper._start_pos = Vector2(100, 100)
	helper._last_pos = Vector2(100, 100)
	helper._start_scroll_v = 0

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100, 60) # drag up by 40px
	helper._input(motion)

	assert(scroll.scroll_vertical == 40, "ScrollContainer should have scrolled to 40, got %d" % scroll.scroll_vertical)
	assert(helper._is_dragging == true, "Helper should be in dragging state")
	print("PASS: Drag motion scrolled container to %d" % scroll.scroll_vertical)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(100, 60)
	helper._input(release)

	assert(helper._is_dragging == false, "Helper should reset dragging on release")
	assert(clicked == false, "Button should not have been clicked during drag")
	print("PASS: Button was not triggered during drag")

	scroll.queue_free()

extends SceneTree

func _initialize() -> void:
	print("TEST: Starting simplified VirtualKeyboardBar tests...")
	
	var root_node := Control.new()
	root.add_child(root_node)

	var script: GDScript = load("res://ui/common/virtual_keyboard_bar.gd")
	assert(script != null, "Could not load virtual_keyboard_bar.gd")
	var bar: Node = script.new()
	root_node.add_child(bar)
	
	var user_edit := LineEdit.new()
	user_edit.name = "UserInput"
	user_edit.placeholder_text = "Nhập tài khoản"
	root_node.add_child(user_edit)

	# 1. Ban đầu: Bar ẩn
	assert(not bar._panel.visible, "Bar must be hidden initially")
	print("PASS: Initially hidden")

	# 2. Focus vào input NHƯNG chưa có bàn phím ảo (kb_h == 0): Bar vẫn PHẢI ẨN!
	bar._on_viewport_focus_changed(user_edit)
	bar._process(0.016)
	assert(not bar._panel.visible, "Bar must REMAIN HIDDEN when virtual keyboard height is 0")
	print("PASS: Focus without virtual keyboard does NOT show bar")

	# 3. Khi bàn phím điện thoại mở lên (kb_h > 0): Bar mới hiển thị!
	user_edit.text = "kiemhiep99"
	bar.set_simulated_keyboard_height(350.0)
	bar._process(0.016)
	assert(bar._panel.visible, "Bar MUST SHOW when virtual keyboard is open (kb_h > 0)")
	assert(bar._preview_label.text == "kiemhiep99", "Preview text must show current typed value")
	print("PASS: Bar shows ONLY when virtual keyboard is open")

	# 4. Khi gõ thay đổi text: Bar cập nhật tức thì
	user_edit.text = "kiemhiep99_updated"
	bar._process(0.016)
	assert(bar._preview_label.text == "kiemhiep99_updated", "Preview text updates realtime")
	print("PASS: Realtime typing updates")

	# 5. Nút xoá [✕]
	bar._on_clear_pressed()
	assert(user_edit.text == "", "Clear button empties the input")
	bar._process(0.016)
	print("PASS: Clear button works")

	# 6. Khi bàn phím điện thoại đóng lại (kb_h == 0): Bar tự động ẩn đi!
	bar.set_simulated_keyboard_height(0.0)
	bar._process(0.016)
	assert(not bar._panel.visible, "Bar MUST HIDE when virtual keyboard closes (kb_h == 0)")
	print("PASS: Bar automatically hides when keyboard closes")

	print("TEST: ALL SIMPLIFIED VIRTUAL KEYBOARD TESTS PASSED!")
	quit(0)

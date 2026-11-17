extends Node

func _ready() -> void:
	print("--- TEST PUBG STAT LINE_EDIT INPUT START ---")

	var profile := PlayerProfile.new()
	profile.display_name = "PubgInputTester"

	var win := PubgWindow.new(profile)
	add_child(win)

	# Chuyển sang Tab 1: Phân Bổ Điểm Cấp 200
	win._select_tab(1)

	assert(win._edit_str is LineEdit, "_edit_str must be a LineEdit")
	assert(win._edit_dex is LineEdit, "_edit_dex must be a LineEdit")
	assert(win._edit_vit is LineEdit, "_edit_vit must be a LineEdit")
	assert(win._edit_eng is LineEdit, "_edit_eng must be a LineEdit")
	print("✔ 4 trường tiềm năng đều là LineEdit cho phép nhập số trực tiếp")

	# Reset về 0 điểm ban đầu để test nhập
	win._on_reset_build_pressed()

	# 1. Test nhập số trực tiếp: nhập 300 vào Sức Mạnh
	win._edit_str.text = "300"
	win._edit_str.text_changed.emit("300")
	assert(win._stat_allocated["str"] == 300, "Str should be 300")
	assert(win._stat_points_left == 995 - 300, "Remaining points should be 695")
	print("✔ Nhập trực tiếp 300 vào Sức Mạnh: điểm còn lại = %d" % win._stat_points_left)

	# 2. Test nhập 250 vào Thân Pháp
	win._edit_dex.text = "250"
	win._edit_dex.text_changed.emit("250")
	assert(win._stat_allocated["dex"] == 250, "Dex should be 250")
	assert(win._stat_points_left == 995 - 300 - 250, "Remaining points should be 445")
	print("✔ Nhập trực tiếp 250 vào Thân Pháp: điểm còn lại = %d" % win._stat_points_left)

	# 3. Test nhập vượt quá số điểm tối đa (ví dụ nhập 9999 vào Sinh Khí) -> tự động clamp về số điểm còn lại (445)
	win._edit_vit.text = "9999"
	win._edit_vit.text_changed.emit("9999")
	assert(win._stat_allocated["vit"] == 445, "Vit should be clamped to 445, got %d" % win._stat_allocated["vit"])
	assert(win._stat_points_left == 0, "Remaining points should be 0")
	assert(win._edit_vit.text == "445", "LineEdit text should be clamped to '445'")
	print("✔ Nhập vượt quá điểm còn lại (9999) tự động kẹp về tối đa %s" % win._edit_vit.text)

	# 4. Test nút Về Ban Đầu (Reset)
	win._on_reset_build_pressed()
	assert(win._stat_allocated["str"] == 0, "Str should reset to 0")
	assert(win._stat_allocated["dex"] == 0, "Dex should reset to 0")
	assert(win._stat_allocated["vit"] == 0, "Vit should reset to 0")
	assert(win._stat_allocated["eng"] == 0, "Eng should reset to 0")
	assert(win._edit_str.text == "0", "Str text should be '0'")
	assert(win._stat_points_left == 995, "Points left should be 995")
	print("✔ Nút Về Ban Đầu reset tất cả ô nhập về 0 và 995 điểm còn lại")

	win.queue_free()
	print("--- TEST PUBG STAT LINE_EDIT INPUT PASSED ALL ---")
	get_tree().quit(0)

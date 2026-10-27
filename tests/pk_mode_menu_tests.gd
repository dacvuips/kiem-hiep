extends Node

func _ready() -> void:
	print("--- TEST PK MODE MENU & DIRECT SELECTION ---")
	test_pk_mode_menu()
	print("--- KẾT THÚC TEST PK MODE MENU: THÀNH CÔNG ---")
	get_tree().quit(0)

func test_pk_mode_menu() -> void:
	var state := {"mode": -1}
	var callback := func(mode: int) -> void:
		state["mode"] = mode

	# 1. Test mở menu
	var menu := PkModeMenu.open(self, 0, callback)
	assert(PkModeMenu.is_open(), "Menu PK phải đang mở")
	assert(menu != null, "Instance menu phải tồn tại")
	print("[PASS] PkModeMenu mở thành công")

	# 2. Test các nút lựa chọn trong menu
	var panel = menu.get_node("_panel") if menu.has_node("_panel") else menu._panel
	assert(panel != null, "_panel phải tồn tại")
	var root_vbox = panel.get_child(0) as VBoxContainer
	assert(root_vbox != null, "VBox chứa option phải tồn tại")

	# Tìm các nút lựa chọn trong VBox
	var option_buttons: Array[Button] = []
	for child in root_vbox.get_children():
		if child is Button and child.text != "✕":
			option_buttons.append(child)

	assert(option_buttons.size() == 4, "Phải có đúng 4 chế độ PK: Luyện Công, Chiến Đấu, Đồ Sát, Bang Chiến")
	print("[PASS] Đủ 4 lựa chọn chế độ PK")

	# 3. Test chọn trực tiếp chế độ Đồ Sát (mode 2)
	var do_sat_btn = option_buttons[2]
	do_sat_btn.pressed.emit()
	assert(state["mode"] == 2, "Callback phải nhận đúng mode 2 (Đồ Sát)")
	assert(not PkModeMenu.is_open(), "Menu phải tự đóng sau khi chọn")
	print("[PASS] Chọn trực tiếp Đồ Sát thành công và menu tự đóng")

	# 4. Test chọn trực tiếp từ Đồ Sát về Luyện Công (mode 0)
	state["mode"] = -1
	menu = PkModeMenu.open(self, 2, callback)
	var luyen_cong_btn: Button = null
	for child in menu._panel.get_child(0).get_children():
		if child is Button and child.text != "✕":
			luyen_cong_btn = child
			break
	assert(luyen_cong_btn != null, "Nút Luyện Công phải tồn tại")
	luyen_cong_btn.pressed.emit()
	assert(state["mode"] == 0, "Callback phải nhận đúng mode 0 (Luyện Công)")
	print("[PASS] Chọn trực tiếp từ Đồ Sát về Luyện Công thành công")

	# 5. Test đóng menu bằng hàm close
	menu = PkModeMenu.open(self, 0, callback)
	assert(PkModeMenu.is_open(), "Menu đang mở")
	PkModeMenu.close()
	assert(not PkModeMenu.is_open(), "Menu đã đóng")
	print("[PASS] Đóng menu PkModeMenu.close() thành công")

	# 6. Test thời gian chờ (cooldown) khi chuyển từ PK về Bình thường
	state["mode"] = -1
	var cd_state := {"remain": 15.0}
	var get_cd := func() -> float:
		return cd_state["remain"]

	menu = PkModeMenu.open(self, 2, callback, null, get_cd)
	luyen_cong_btn = null
	for child in menu._panel.get_child(0).get_children():
		if child is Button and child.text != "✕":
			luyen_cong_btn = child
			break
	assert(luyen_cong_btn != null, "Nút Luyện Công phải tồn tại")

	# Khi cooldown > 0: bấm nút không được chuyển, menu không đóng
	luyen_cong_btn.pressed.emit()
	assert(state["mode"] == -1, "Không được chuyển về Bình thường khi cooldown > 0")
	assert(PkModeMenu.is_open(), "Menu không đóng khi bấm lúc cooldown chưa hết")
	print("[PASS] Chặn chuyển về Bình thường khi đang trong thời gian chờ (cooldown = 15s)")

	# Khi cooldown hết (= 0): bấm nút sẽ chuyển thành công
	cd_state["remain"] = 0.0
	luyen_cong_btn.pressed.emit()
	assert(state["mode"] == 0, "Chuyển về Bình thường thành công sau khi hết cooldown")
	assert(not PkModeMenu.is_open(), "Menu đóng sau khi chuyển thành công")
	print("[PASS] Cho phép chuyển về Bình thường khi hết thời gian chờ")

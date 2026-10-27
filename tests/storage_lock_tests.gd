extends Node
## Kiểm thử tính năng Khóa Rương & Rương Chứa Đồ chuẩn VLTK

var _passes := 0
var _fails := 0

func _ready() -> void:
	print("\n--- BẮT ĐẦU TEST KHÓA RƯƠNG & RƯƠNG CHỨA ĐỒ CHUẨN GỐC VLTK ---")

	var profile := PlayerProfile.new()
	profile.display_name = "DaiHiep"

	# 1. Kiểm tra SecurityLock theo chuẩn gốc
	check("Chưa đặt mật mã thì has_password = false", not SecurityLock.has_password(profile))
	check("Chưa đặt mật mã thì is_locked = false", not SecurityLock.is_locked(profile))

	# 2. Đặt mật khẩu (1..16 ký tự theo MIN/MAX_PASSWORD_LENGTH)
	var err_set := SecurityLock.set_password(profile, "123456")
	check("Đặt mật mã bảo vệ thành công", err_set == "")
	check("Sau khi đặt mật mã thì has_password = true", SecurityLock.has_password(profile))
	check("Sau khi đặt mật mã thì tự động vào trạng thái Đang Khóa", SecurityLock.is_locked(profile))

	# 3. Khi đang khóa: các thao tác nguy hiểm bị chặn
	check("Đang khóa chặn mở quầy", SecurityLock.check(profile, SecurityLock.A_OPEN_STALL) != "")
	check("Đang khóa chặn giao dịch", SecurityLock.check(profile, SecurityLock.A_TRADE_START) != "")
	check("Đang khóa chặn vứt đồ", SecurityLock.check(profile, SecurityLock.A_DROP_ITEM) != "")
	check("Đang khóa chặn rút/gửi tiền rương", SecurityLock.check(profile, SecurityLock.A_STORE_MONEY) != "")
	check("Đang khóa chặn thao tác rương đồ", SecurityLock.check(profile, SecurityLock.A_STORAGE) != "")

	# 4. Mở khóa (Unlock)
	var err_wrong := SecurityLock.unlock(profile, "654321")
	check("Nhập sai mật mã thì không mở được khóa", err_wrong != "" and SecurityLock.is_locked(profile))

	var err_right := SecurityLock.unlock(profile, "123456")
	check("Nhập đúng mật mã thì mở khóa thành công", err_right == "" and not SecurityLock.is_locked(profile))
	check("Mở khóa xong cho phép thao tác rương đồ", SecurityLock.check(profile, SecurityLock.A_STORAGE) == "")

	# 5. Khóa lại ngay (Re-lock)
	var err_relock := SecurityLock.lock(profile)
	check("Bấm Khóa thì rương khóa lại ngay", err_relock == "" and SecurityLock.is_locked(profile))

	# 6. Kiểm tra giao diện CharacterHub có nút Rương và nút Khóa
	var hub_scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)

	var has_storage_btn: bool = hub.has_node("%StorageButton")
	check("CharacterHub có nút %StorageButton (Rương Đồ)", has_storage_btn)

	var has_sec_btn: bool = hub.has_node("%SecurityButton")
	check("CharacterHub có nút %SecurityButton (Khóa Rương)", has_sec_btn)

	if has_sec_btn:
		var sec_btn: Button = hub.get_node("%SecurityButton")
		check("Nút Khóa Rương có text hiển thị trạng thái", sec_btn.text != "")

	hub.queue_free()

	# 7. Kiểm tra StorageWindow mở được và đúng thiết kế 8 slot dọc, 4 tabs (2,3,4 disabled)
	check("Rương chứa đồ có chiều cao 8 slot dọc", profile.storage.ROOM_HEIGHT == 8)
	var st := StorageWindow.new(profile)
	add_child(st)
	check("StorageWindow có lưới rương", st._box_view != null)
	check("StorageWindow có tấm che khóa bảo vệ", st._lock_cover != null)
	check("StorageWindow đang khóa thì tấm che hiện", st._lock_cover.visible == true)
	check("StorageWindow có 4 tab rương", st._box_tabs.get_child_count() >= 4)
	if st._box_tabs.get_child_count() >= 4:
		var tab0: Button = st._box_tabs.get_child(0)
		var tab1: Button = st._box_tabs.get_child(1)
		var tab2: Button = st._box_tabs.get_child(2)
		var tab3: Button = st._box_tabs.get_child(3)
		check("Tab Rương 1 khả dụng", not tab0.disabled)
		check("Tab Rương 2 bị khóa", tab1.disabled and "🔒" in tab1.text)
		check("Tab Rương 3 bị khóa", tab2.disabled and "🔒" in tab2.text)
		check("Tab Rương 4 bị khóa", tab3.disabled and "🔒" in tab3.text)
	st.queue_free()

	print("--- KẾT THÚC TEST: RESULT %d/%d (Thất bại: %d) ---\n" % [_passes, _passes + _fails, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

func check(desc: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("PASS: %s" % desc)
	else:
		_fails += 1
		print("FAIL: %s" % desc)

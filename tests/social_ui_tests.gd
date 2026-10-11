extends Node
## Kiểm thử GIAO DIỆN xã hội: dựng từng cửa sổ, bấm nút như người chơi, kiểm trạng thái. Chạy:
##   godot --headless --path . res://tests/social_ui_tests.tscn

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame

func find_buttons(root: Node, text: String) -> Array[Button]:
	var out: Array[Button] = []
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			out.append(n)
	return out

func press(root: Node, text: String) -> bool:
	for b in find_buttons(root, text):
		if not b.disabled and b.is_visible_in_tree():
			b.pressed.emit()
			return true
	return false

## Cửa sổ xã hội đang mở thuộc lớp `cls` (vd KeypadWindow).
func window_of(kind_name: String) -> SocialWindow:
	var found: SocialWindow = null
	for w in get_tree().get_nodes_in_group("social_windows"):
		if w is SocialWindow and is_instance_valid(w) and not w.is_queued_for_deletion() and w.get_class() != "" and w.get_script().get_global_name() == kind_name:
			found = w
	return found

## Gõ mật mã lên bàn phím số đang mở rồi xác nhận.
func keypad(code: String) -> bool:
	var k := window_of("KeypadWindow") as KeypadWindow
	if k == null:
		return false
	k.type_and_submit(code)
	return true

func _ready() -> void:
	SocialDirectory.reset()
	var p := PlayerProfile.new()
	p.display_name = "UiTester"
	p.set_sect(SectRegistry.get_by_element(ElementTypes.ElementType.MOC)[0])
	p.level = 60
	p.lead_level = 25
	p.gold = 80_000_000
	p.prestige = 600
	p.fuyuan = 700
	GameManager.local_profile = p
	for i in 6:
		p.add_item(ItemGenerator.random_equipment(40))
	var hub := SocialHub.of(p)

	## Menu giao lưu
	var menu := SocialMenuWindow.open(self, p)
	await frames()
	check("ui: menu giao lưu dựng được + có người quanh đây", menu != null and not menu.find_children("*", "Button", true, false).is_empty())

	## Bàn phím số: 10 phím chữ số ngẫu nhiên + Đính chính
	var kp := KeypadWindow.ask(self, "Thử", "Nhập", func(_c: String) -> void: pass)
	await frames()
	var digits := {}
	for b in kp.find_children("*", "Button", true, false):
		if (b as Button).text.length() == 1 and (b as Button).text.is_valid_int():
			digits[(b as Button).text] = true
	check("ui: bàn phím số có đủ 10 chữ số", digits.size() == 10)
	kp.close_requested.emit()
	await frames()

	## Khoá bảo vệ qua bàn phím số
	var sec := SecurityWindow.open(self, p)
	await frames()
	press(sec, "Đặt mật mã")
	await frames()
	keypad("1234")
	await frames()
	keypad("1234")
	await frames()
	check("ui: đặt mật mã qua bàn phím số (nhập 2 lần)", SecurityLock.is_locked(p) and SecurityLock.unlock_check(p, "1234"))
	press(sec, "Mở khoá")
	await frames()
	keypad("9999")
	await frames()
	check("ui: sai mật mã vẫn khoá", SecurityLock.is_locked(p))
	press(sec, "Mở khoá")
	await frames()
	keypad("1234")
	await frames()
	check("ui: đúng mật mã mở khoá", not SecurityLock.is_locked(p))
	press(sec, "Đặt mật mã")
	check("ui: đã có mật mã thì không đặt lại", not press(sec, "Đặt mật mã"))
	sec.close_requested.emit()
	await frames()

	## Rương: đang khoá → bị che
	SecurityLock.lock(p)
	var st := StorageWindow.open(self, p)
	await frames()
	check("ui: rương đang khoá bị che bằng tấm khoá", st._lock_cover.visible)
	var item := p.inventory[0]
	check("ui: rương khoá không kéo thả được", not StorageService.transfer(p, item, p, p.storage, 0, 0, 0))
	st.submit_money(true, "100")
	check("ui: rương khoá không gửi tiền", p.storage_gold == 0)
	press(st, "Mở khoá")
	await frames()
	keypad("0000")
	await frames()
	check("ui: sai mật mã rương vẫn che", st._lock_cover.visible)
	press(st, "Mở khoá")
	await frames()
	keypad("1234")
	await frames()
	check("ui: đúng mật mã thì mở rương", not st._lock_cover.visible and not SecurityLock.is_locked(p))
	var ok := StorageService.transfer(p, item, p, p.storage, 0, 0, 0)
	st._refresh()
	await frames()
	check("ui: kéo thả hành trang -> rương", ok and p.storage.owns(item))
	st.submit_money(true, "5000")
	check("ui: gửi tiền vào rương", p.storage_gold == 5000)
	st.submit_money(false, "2000")
	check("ui: rút tiền", p.storage_gold == 3000)
	var before_boxes := StorageService.box_count(p)
	st._expand_btn.pressed.emit()
	await frames()
	press(self, "Đồng ý")        # hộp xác nhận "Mở rộng rương"
	await frames()
	check("ui: mở rộng rương (có hộp xác nhận)", StorageService.box_count(p) == before_boxes + 1)
	press(st, "Khoá")
	await frames()
	check("ui: bấm Khoá thì khoá lại rương", SecurityLock.is_locked(p) and st._lock_cover.visible)
	st.close_requested.emit()
	await frames()
	SecurityLock.unlock(p, "1234")
	SecurityLock.clear_password(p, "1234")

	## Bày bán
	var stall_item := p.inventory[1]
	StallService.set_price(p, stall_item, 777)
	var sw := StallWindow.open(self, hub)
	await frames()
	check("ui: không cưỡi ngựa (không có nhân vật) thì không báo lỗi cưỡi", not sw._is_riding())
	press(sw, "Mở quầy")
	await frames()
	check("ui: mở quầy bày bán", p.stall_open, ((sw._msg.get_child(0) as Label).text if sw._msg.visible else "no msg"))
	press(sw, "Dọn quầy")
	await frames()
	check("ui: dọn quầy", not p.stall_open)
	press(sw, "Mở giao dịch")
	await frames()
	check("ui: mở giao dịch", p.trade_open)
	sw.close_requested.emit()
	StallService.close_trade(p)

	## Xem quầy giả + mua
	var seller: MockPlayer = null
	for m in SocialDirectory.players(p):
		if m.stall_open and not StallService.browse(m).is_empty():
			seller = m
	check("ui: có quầy giả để xem", seller != null)
	if seller != null:
		var sb := StallBrowseWindow.open(self, hub, seller)
		await frames()
		var goods := StallService.browse(seller)
		var n_before := p.inventory.size()
		press(sb, "Mua")
		await frames()
		check("ui: mua đồ từ quầy giả", p.inventory.size() == n_before + 1 or goods.size() == StallService.browse(seller).size() + 1)
		sb.close_requested.emit()

	## Giao dịch: Đồng ý (khoá) → Xác nhận (chốt)
	var partner := SocialDirectory.players(p)[0]
	partner.trade_open = true
	partner.stall_open = false
	partner.invite_accept_rate = 1.0
	partner.haggle = 0.9
	var terr := hub.start_trade(partner)
	check("ui: bắt đầu giao dịch", terr == "", terr)
	if terr == "":
		var tw := TradeWindow.open(self, hub)
		await frames()
		var offer := p.inventory[0]
		hub.trade.offer_item(hub.trade.local(), offer)
		press(tw, "Đồng ý")
		await frames()
		check("ui: giao dịch — Đồng ý khoá phần của mình, người giả cũng khoá", hub.trade.local().locked and hub.trade.partner().locked)
		press(tw, "Xác nhận")
		await frames()
		hub.trade.tick(6.0)
		await frames()
		check("ui: giao dịch hoàn tất", not hub.trade.active and not p.inventory.has(offer))
		tw.close_requested.emit()

	## Lập nhóm
	SocialDirectory.reset()
	var tm := TeamWindow.open(self, hub)
	await frames()
	press(tm, "Lập nhóm")
	await frames()
	check("ui: Lập nhóm tạo tổ đội", hub.team.is_captain())
	var pool := SocialDirectory.players(p)
	for m in pool:
		m.invite_accept_rate = 1.0
		m.camp = Camp.Type.JUSTICE
	tm._players_list.select(0)
	tm._players_list.item_selected.emit(0)
	await frames()
	press(tm, "Mời nhóm")
	await frames()
	check("ui: chọn người rồi Mời nhóm", hub.team.total() == 2)
	check("ui: danh sách 'Nhóm của mình' có 2 người", tm._members_list.item_count == 2)
	press(tm, "Rời nhóm")
	await frames()
	check("ui: Rời nhóm", not hub.team.in_team())
	tm.close_requested.emit()
	await frames()

	## Bang hội: hộp Lập bang hội → 5 tab
	var gw := GuildWindow.open(self, hub)
	await frames()
	gw._open_create_dialog()
	await frames()
	var dlg := window_of("SocialWindow")
	var created_dialog := false
	for w in get_tree().get_nodes_in_group("social_windows"):
		if w is SocialWindow and w.kind == &"guild_create":
			dlg = w
			created_dialog = true
	check("ui: hộp Lập bang hội mở được", created_dialog)
	if created_dialog:
		(dlg.get_meta("name_edit") as LineEdit).text = "Bang Test"
		press(dlg, "xác nhận")
		await frames()
	check("ui: lập bang hội qua hộp xác nhận", hub.guild.in_guild() and hub.guild.is_master())
	var tabs_ok := true
	for t in GuildWindow.Tab.values():
		gw._tab = t
		gw._rebuild()
		await frames()
		tabs_ok = tabs_ok and gw._content.get_child_count() > 0
	check("ui: cả 5 tab bang hội dựng được", tabs_ok)
	gw._tab = GuildWindow.Tab.PERMS
	gw._rebuild()
	await frames()
	check("ui: bang hội có nút Tạo mới / Xem tin Bang khác / Đóng", not find_buttons(gw, "Tạo mới").is_empty() and not find_buttons(gw, "Xem tin Bang khác").is_empty())
	gw.close_requested.emit()
	await frames(2)

	## Xem trang bị người chơi khác
	ViewEquipService.reset()
	var target: MockPlayer = null
	for m in SocialDirectory.players(p):
		if m.equipment.size() >= 2:
			target = m
			break
	check("ui: có người chơi giả mặc đồ để xem", target != null)
	if target != null:
		var err_list := []
		var vw := ViewEquipWindow.open_for(self, p, target, err_list)
		await frames()
		check("ui: mở cửa sổ xem trang bị", vw != null, str(err_list))
		if vw != null:
			var slots := vw.find_children("Slot*", "ItemSlotButton", true, false)
			check("ui: đủ 11 ô trang bị", slots.size() == Equipment.Part.values().size())
			var shown := 0
			for sl in slots:
				if (sl as ItemSlotButton).item_bbcode != "":
					shown += 1
			check("ui: ô có đồ hiển thị đúng số món đang mặc", shown == target.equipment.size(), "%d / %d" % [shown, target.equipment.size()])
			vw.close_requested.emit()
			await frames()
		var err2 := []
		var again := ViewEquipWindow.open_for(self, p, target, err2)
		check("ui: xem lại ngay bị chặn (30 nhịp) và báo lỗi", again == null and not err2.is_empty())

	## Tổng kết
	print("RESULT ", _pass, "/", _pass + _fail)
	get_tree().quit(1 if _fail > 0 else 0)

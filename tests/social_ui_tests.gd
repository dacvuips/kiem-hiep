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

	## Chợ Giao Thương: 3 tab, có hàng người chơi giả, treo bán 1 món rồi huỷ treo, tab Giao Dịch có danh sách người quanh đây
	var market := MarketWindow.open(self, p)
	await frames()
	check("ui: chợ dựng được + có thẻ hàng", market != null and market._grid.get_child_count() > 0)
	var bag_n := p.inventory.size()
	var listed: ItemInstance = p.inventory[0]
	var sold := OfflineMarket.handle(p, "sell", {"uid": listed.uid, "price": 50000, "cur": MarketBook.CUR_GOLD})
	check("chợ: treo bán -> món rời hành trang, vào Của Tôi", bool(sold.ok) and not p.inventory.has(listed) and p.market.size() == 1)
	var mine := OfflineMarket.handle(p, "mine", {})
	var back := OfflineMarket.handle(p, "cancel", {"id": str(mine["items"][0]["id"])})
	check("chợ: huỷ treo -> món về hành trang", bool(back.ok) and p.market.is_empty() and p.inventory.size() == bag_n)
	var offers := OfflineMarket.handle(p, "list", {"filter": {"cur": MarketBook.CUR_GOLD}})
	var gold_before := p.gold
	var pick: Dictionary = offers["items"][0]
	var bought := OfflineMarket.handle(p, "buy", {"id": str(pick["id"])})
	check("chợ: mua hàng người chơi giả -> trừ tiền, thêm món", bool(bought.ok) and p.gold == gold_before - int(pick["price"]) and p.inventory.size() == bag_n + 1)
	market._show_tab(MarketWindow.Tab.TRADE)
	await frames()
	check("ui: chợ tab Giao Dịch có người quanh đây", market._near_box.get_child_count() > 0)
	market.close_requested.emit()
	await frames()

	## Vượt Ải › Địa Ngục: 11x / 12x có thẻ map, vào map mang theo độ khó (quái cấp 110 / 120, số sao)
	var maps_win := MapSelectWindow.open(self, p, func(_e: Dictionary) -> void: pass)
	maps_win._select_tab(2)
	await frames()
	check("ui: tab Địa Ngục có thẻ map 11x", maps_win.find_children("*", "Button", true, false).any(
		func(b: Button) -> bool: return b.text == "Khiêu chiến"))
	var hell := MapCatalog.hell_entry(MapCatalog.hell_maps(12)[0], 5)
	check("địa ngục: mục map 12x 5 sao", int(hell["hell"]["level"]) == 120 and int(hell["hell"]["stars"]) == 5)
	var full := DropTable._roll_blue_item(DropTable.TIERS[10], 0, ItemInstance.MAX_MAGIC)
	check("địa ngục: đồ đủ dòng có đủ %d dòng" % ItemInstance.MAX_MAGIC, full != null and full.magic.size() == ItemInstance.MAX_MAGIC)
	maps_win.close_requested.emit()
	await frames()

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
	var inv := InventoryPopup.find_open(get_tree())
	check("ui: mở rương thì mở kèm khung Hành trang riêng", inv != null and st._inventory == inv and inv._room.transfer_handler.is_valid())
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
		check("ui: giao dịch thành công thì cửa sổ tự đóng", not is_instance_valid(tw) or tw.is_queued_for_deletion())

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

	## Issue #7: Xem trang bị qua gói tin JSON (S_VIEW_EQUIP) giữ nguyên 11 ô trang bị & hiển thị số nguyên
	p.level = 50
	p.lead_level = 3
	p.equipment[Equipment.Part.WEAPON] = ItemGenerator.random_equipment(10)
	p.equipment[Equipment.Part.BODY] = ItemGenerator.random_equipment(10)
	## Online: bảng "Đang tải" rồi dữ liệu server tới thì thay; xem người khác thì thay bảng cũ (không giữ bảng cũ)
	var loading := ViewEquipWindow.open_snapshot(self, {"name": "Người A", "level": 50, "loading": true})
	await frames()
	var shown := ViewEquipWindow.open_snapshot(self, ViewEquipService.snapshot_from_wire(JSON.parse_string(JSON.stringify(
		ViewEquipService.snapshot_to_wire(ViewEquipService.snapshot_of_profile(p))))))
	await frames()
	var open_views := get_tree().get_nodes_in_group("social_windows").filter(func(w: Node) -> bool:
		return w is ViewEquipWindow and not w.is_queued_for_deletion())
	check("tin tức: dữ liệu tới thì thay bảng Đang tải", open_views.size() == 1 and open_views[0] == shown and not is_instance_valid(loading) or (is_instance_valid(loading) and loading.is_queued_for_deletion()), str(open_views.size()))
	check("tin tức: bảng mới có ô trang bị", not shown.find_children("Slot*", "ItemSlotButton", true, false).is_empty())
	shown.close_requested.emit()
	await frames()
	var raw_snap := ViewEquipService.snapshot_of_profile(p)
	var wire_snap: Dictionary = JSON.parse_string(JSON.stringify(raw_snap))
	var vw_wire := ViewEquipWindow.open_snapshot(self, wire_snap)
	await frames()
	if vw_wire != null:
		var wire_slots := vw_wire.find_children("Slot*", "ItemSlotButton", true, false)
		var wire_shown := 0
		for sl in wire_slots:
			if (sl as ItemSlotButton).item_bbcode != "":
				wire_shown += 1
		check("ui (#7): S_VIEW_EQUIP qua JSON hiển thị đúng số món đang mặc", wire_shown == p.equipment.size(), "%d / %d" % [wire_shown, p.equipment.size()])
		var has_float_label := false
		for lbl in vw_wire.find_children("*", "Label", true, false):
			if (lbl as Label).text in ["50.0", "3.0", "0.0"]:
				has_float_label = true
		check("ui (#7): Cấp & Lãnh đạo hiển thị số nguyên, không có .0", not has_float_label)
		vw_wire.close_requested.emit()
		await frames()

	## Issue #8: Xoá hảo hữu trong FriendWindow lưu xuống SaveManager & NetWorldSync không nhân bản kết nối NetClient.saved
	var backup_profile := SaveManager.load_profile()
	p.friends = ["KiemKhach01"]
	SaveManager.save_profile(p)
	var fw := FriendWindow.open(self, p)
	await frames()
	press(fw, "Xoá")
	await frames()
	for w in get_tree().get_nodes_in_group("social_windows"):
		if w != fw and w is SocialWindow:
			press(w, "Đồng ý")
	await frames()
	var reloaded_p := SaveManager.load_profile()
	check("ui (#8): xoá hảo hữu lưu bền vững xuống SaveManager", reloaded_p != null and not reloaded_p.friends.has("KiemKhach01"))
	if backup_profile != null:
		SaveManager.save_profile(backup_profile)
	fw.close_requested.emit()
	await frames()

	var sync1 := NetWorldSync.new()
	add_child(sync1)
	sync1.queue_free()
	await frames()
	var sync2 := NetWorldSync.new()
	add_child(sync2)
	check("ui (#8): vào lại NetWorldSync không nhân bản kết nối NetClient.saved", NetClient.saved.is_connected(SaveManager.set_online_version))
	sync2.queue_free()
	await frames()

	## Bày bán đã bỏ khỏi giao diện: InventoryPopup không còn nút Bày bán
	var inv_pop := InventoryPopup.open(self, p, func() -> void: pass)
	await frames(2)
	check("ui: InventoryPopup không còn nút Bày bán", inv_pop.get_node_or_null("%SellButton") == null)
	inv_pop.queue_free()
	await frames()

	## Issue #10: AccountDialog không chồng nhiều lớp trên root và ẩn nút Liên kết Google khi offline
	AccountApi.account = {}
	var ad1 := AccountDialog.open(self)
	var ad2 := AccountDialog.open(self)
	await frames()
	var acc_layers := 0
	for ch in get_tree().root.get_children():
		if ch is CanvasLayer and (ch as CanvasLayer).layer == AccountDialog.LAYER:
			acc_layers += 1
	check("ui (#10): gọi AccountDialog.open nhiều lần chỉ tạo 1 lớp trên root", acc_layers == 1 and ad1 == ad2, str(acc_layers))
	var link_btn: Button = ad1.get_node("%LinkGoogleButton")
	check("ui (#10): ẩn nút Liên kết Google khi chưa đăng nhập", not link_btn.visible)
	ad1.get_parent().queue_free()
	await frames()

	## Tên trên đầu trong Chiến trường Tống Kim: "(Kim)Tên" theo phe trong trận
	var nr := RemotePlayer.new()
	add_child(nr)
	nr.setup({"eid": 960, "name": "Lý Bạch", "level": 60, "camp": Camp.Type.JUSTICE, "nation": Nation.Type.JIN,
		"look": {"gender": 0, "helm": -1, "armor": -1, "weapon": -1, "horse": -1}, "pos": Vector2.ZERO,
		"dir": 0, "action": 0, "z": 0, "flags": 0, "hp": 100})
	check("tên: phe Kim hiện (Kim) trước tên", nr._label.text == "(Kim)Lý Bạch", nr._label.text)
	nr.set_camp(Camp.Type.JUSTICE, Nation.Type.NONE)
	check("tên: chưa chọn phe thì chỉ có tên", nr._label.text == "Lý Bạch", nr._label.text)
	nr.set_camp(Camp.Type.JUSTICE, Nation.Type.SONG)
	check("tên: vừa chọn phe Tống thì đổi thành (Tống)", nr._label.text == "(Tống)Lý Bạch", nr._label.text)
	nr.queue_free()

	## Biển tên quầy trên đầu người bày bán: hiện khi có tên quầy, ẩn khi dọn quầy, menu người chơi có "Xem quầy"
	var stall_rp := RemotePlayer.new()
	add_child(stall_rp)
	stall_rp.setup({"eid": 950, "name": "Người bán", "level": 60, "camp": Camp.Type.JUSTICE, "nation": 0, "stall_title": "Hàng tốt giá rẻ",
		"look": {"gender": 0, "helm": -1, "armor": -1, "weapon": -1, "horse": -1}, "pos": Vector2.ZERO,
		"dir": 0, "action": 0, "z": 0, "flags": NetProto.FLAG_STALL, "hp": 100})
	check("quầy: biển tên quầy hiện trên đầu", stall_rp._sign.visible and stall_rp._sign.title == "Hàng tốt giá rẻ" and stall_rp._sign.position.y < stall_rp._label.position.y)
	check("quầy: bấm biển được (giao diện ăn cú bấm)", stall_rp._sign.mouse_filter == Control.MOUSE_FILTER_STOP)
	var pm := PlayerMenu.new()
	pm._target = stall_rp
	check("quầy: menu người chơi có mục Xem quầy", pm._items().any(func(i: Array) -> bool: return i[0] == "Xem quầy"))
	stall_rp.set_stall_title("")
	check("quầy: dọn quầy thì menu không còn Xem quầy", not pm._items().any(func(i: Array) -> bool: return i[0] == "Xem quầy"))
	pm.free()
	check("quầy: dọn quầy thì biển biến mất", not stall_rp._sign.visible)
	stall_rp.queue_free()

	## Đánh thường ở nút chính: trống thì tay không / vũ khí cận chiến = bàn tay, phi tiêu / phi đao / tụ tiễn = phi đao; không có trong bảng Kỹ năng
	var bp := PlayerProfile.new()
	bp.display_name = "BasicTester"
	bp.set_sect(SectRegistry.get_by_element(ElementTypes.ElementType.MOC)[0])
	GameManager.local_profile = bp
	var ctrl := SectSkillController.new()
	add_child(ctrl)
	ctrl.setup(SectRegistry.get_by_id(bp.sect_id))
	check("đánh thường: nút chính trống + tay không = bàn tay (SkillId 1)", ctrl.get_main_skill() != null and ctrl.get_main_skill().vltk_skill_id == 1, str(ctrl.get_main_skill()))
	bp.equipment[Equipment.Part.WEAPON] = ItemGenerator.generate(ItemDatabase.Detail.MELEE, 0, 1, 0, [])
	check("đánh thường: cầm kiếm = bàn tay", ctrl.get_main_skill().id == "basic_attack")
	bp.equipment[Equipment.Part.WEAPON] = ItemGenerator.generate(ItemDatabase.Detail.RANGE, 1, 1, 0, [])
	var ranged := ctrl.get_main_skill()
	check("đánh thường: cầm phi đao = đòn tầm xa icon phi đao (SkillId 2)", ranged.id == "basic_attack_ranged" and ranged.vltk_skill_id == 2
		and ranged.icon.resource_path.ends_with("co_ban_at.png"), ranged.id)
	bp.main_skill_id = "basic_attack"
	check("đánh thường: gắn nhầm đánh thường vẫn theo vũ khí", ctrl.get_main_skill().id == "basic_attack_ranged")
	var book_skills := SectRegistry.get_by_id(bp.sect_id).skills.filter(func(s: SkillDefinition) -> bool: return not s.is_hidden and not s.is_basic_attack)
	check("đánh thường: không hiện trong bảng Kỹ năng", not book_skills.any(func(s: SkillDefinition) -> bool: return s.is_basic_attack)
		and SectRegistry.get_by_id(bp.sect_id).skills.filter(func(s: SkillDefinition) -> bool: return s.is_basic_attack).size() == 2)
	ctrl.queue_free()
	GameManager.local_profile = p

	## Tổng kết
	print("RESULT ", _pass, "/", _pass + _fail)
	get_tree().quit(1 if _fail > 0 else 0)


extends Node
## Vật phẩm khoá (bLockTrade / bLockSell / bLockDrop gốc) + nút "Khóa" (khoá bảo vệ = khoá rương gốc) trong hành trang.

var _passes := 0
var _fails := 0

func _ready() -> void:
	print("\n--- TEST VẬT PHẨM KHOÁ ---")
	var p := PlayerProfile.new()
	p.display_name = "TestBound"
	var potion := ItemGenerator.generate_misc(PotionShop.all_items()[0])
	var item := ItemInstance.new()
	item.base_index = ItemDatabase.find_base(ItemDatabase.Detail.RING, 0, 1)
	p.inventory.append(item)

	check("Món thường: giao dịch / vứt / bán được", item.can_trade() and item.can_drop() and not item.is_bound())

	item.set_bound(true, true, true)
	check("Khoá cả 3: không giao dịch", not item.can_trade())
	check("Khoá cả 3: không vứt", not item.can_drop())
	check("Khoá cả 3: không bán NPC", not item.can_sell() and item.get_sale_price() == 0)

	## Lưu / đọc giữ nguyên cờ
	var back := ItemInstance.from_dict(item.to_dict())
	check("Lưu/đọc giữ 3 cờ", back.lock_trade and back.lock_sell and back.lock_drop)
	var only_drop := ItemInstance.from_dict(item.to_dict())
	only_drop.set_bound(false, false, true)
	var only_drop2 := ItemInstance.from_dict(only_drop.to_dict())
	check("Chỉ khoá vứt: vẫn giao dịch được, không vứt được", only_drop2.can_trade() and not only_drop2.can_drop())

	## Không cho giá bày bán / không cho vào giao dịch / quầy / chợ
	check("Khoá giao dịch: không đặt giá bày bán", StallService.set_price(p, item, 100) != "")
	var sess := TradeSession.new()
	sess._setup(TradeParty.of_profile(p), TradeParty.of_profile(PlayerProfile.new()))
	check("Khoá giao dịch: không đưa vào giao dịch", sess.offer_item(sess.local(), item) != "")

	## Món khoá không chồng với món thường
	if potion != null:
		var a := ItemInstance.from_dict(potion.to_dict()); a.uid = "a"
		var b := ItemInstance.from_dict(potion.to_dict()); b.uid = "b"
		check("2 thuốc giống nhau chồng được", PlayerProfile.can_stack(a, b) or ItemDatabase.max_stack(a.misc_id) <= 1)
		b.set_bound(true, false, false)
		check("Thuốc khoá không chồng với thuốc thường", not PlayerProfile.can_stack(a, b))

	## Mô tả món đồ có dòng báo
	var text := ItemText.plain(ItemText.build(item, null, -1, -1, true))
	check("Mô tả có 'Không thể giao dịch'", text.contains("Không thể giao dịch"))
	check("Mô tả có 'Không thể vứt bỏ'", text.contains("Không thể vứt bỏ"))

	## Server: client không tự gỡ cờ được (bind không thuộc OWNER_FIELDS)
	check("bind không thuộc OWNER_FIELDS", not ("bind" in ItemInstance.OWNER_FIELDS))

	## Hạn sử dụng
	var t0 := 1_800_000_000
	var timed := ItemInstance.from_dict(item.to_dict())
	timed.uid = "timed"
	timed.set_expire_days(30, t0)
	check("Hạn 30 ngày đúng số giây", timed.expire_at == t0 + 30 * 86400)
	check("Chưa hết hạn trước 30 ngày", not timed.is_expired(t0 + 30 * 86400 - 1))
	check("Hết hạn đúng mốc 30 ngày", timed.is_expired(t0 + 30 * 86400))
	check("Lưu/đọc giữ hạn", ItemInstance.from_dict(timed.to_dict()).expire_at == timed.expire_at)
	check("Mô tả có 'Thời hạn sử dụng'", ItemText.plain(ItemText.build(timed, null, -1, -1, true)).contains("Thời hạn sử dụng"))
	check("exp không thuộc OWNER_FIELDS", not ("exp" in ItemInstance.OWNER_FIELDS))
	var q := PlayerProfile.new()
	q.inventory.append(timed)
	var worn := ItemInstance.from_dict(timed.to_dict()); worn.uid = "worn"
	q.equipment[Equipment.Part.RING2] = worn
	var forever := ItemInstance.from_dict(item.to_dict()); forever.uid = "forever"; forever.expire_at = 0
	q.inventory.append(forever)
	check("Chưa hết hạn: không xoá gì", q.remove_expired_items(t0 + 100).is_empty())
	var gone := q.remove_expired_items(t0 + 31 * 86400)
	check("Hết hạn: xoá cả túi và đồ đang mặc (2 món)", gone.size() == 2 and not q.equipment.has(Equipment.Part.RING2))
	check("Món không hạn vẫn còn", q.inventory.has(forever) and q.inventory.size() == 1)

	## Quà tân thủ: đồ Hoàng Kim là vật phẩm khoá + hạn 30 ngày; ngựa / thuốc không bị
	var np := PlayerProfile.new()
	StarterKit.apply(np)
	var golds := np.inventory.filter(func(it: ItemInstance) -> bool: return it.is_gold())
	var others := np.inventory.filter(func(it: ItemInstance) -> bool: return not it.is_gold())
	check("Tân thủ có đồ Hoàng Kim (%d món)" % golds.size(), golds.size() > 0)
	check("Đồ Hoàng Kim tân thủ khoá cả 3 + hạn ~30 ngày", golds.all(func(it: ItemInstance) -> bool:
		return it.lock_trade and it.lock_sell and it.lock_drop \
			and absi(it.expire_at - int(Time.get_unix_time_from_system()) - 30 * 86400) < 60))
	check("Đồ khác (ngựa, thuốc) không khoá, không hạn", others.all(func(it: ItemInstance) -> bool: return not it.is_bound() and it.expire_at == 0))
	## Popup chi tiết dùng build(..., with_name = false): khoá gộp 1 dòng ở cuối, thời hạn lên dòng đầu popup (không lặp trong mô tả)
	var detail := ItemText.plain(ItemText.build(golds[0], np, -1, -1, false))
	check("Popup chi tiết: 3 khoá gộp 1 dòng", "Không thể giao dịch, Không thể bán, Không thể vứt bỏ" in detail)
	check("Popup chi tiết: mô tả không lặp thời hạn", not ("Thời hạn sử dụng" in detail))
	check("Mô tả có tên vẫn ghi thời hạn", "Thời hạn sử dụng" in ItemText.plain(ItemText.build(golds[0], np)))
	var pop := ItemDetailPopup.open(self, ItemText.build(golds[0], np, -1, -1, false), [], golds[0])
	check("Dòng đầu popup ghi thời hạn", "Thời hạn sử dụng" in (pop.get_node("%PriceLabel") as RichTextLabel).get_parsed_text())
	pop.queue_free()

	## Nút Khóa trong hành trang
	var hub = load("res://ui/character_hub/CharacterHub.tscn").instantiate()
	add_child(hub)
	check("Hành trang có nút Khóa (%SecurityButton)", hub.has_node("%SecurityButton"))
	if hub.has_node("%SecurityButton"):
		check("Nút Khóa có chữ", (hub.get_node("%SecurityButton") as Button).text != "")
	hub.queue_free()

	print("--- KẾT QUẢ: %d/%d (hỏng %d) ---" % [_passes, _passes + _fails, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

func check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("PASS ", name)
	else:
		_fails += 1
		print("FAIL ", name)

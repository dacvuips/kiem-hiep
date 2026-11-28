extends Node
## Độ bền trang bị (ItemDurability) — tụt khi ra chiêu / chết / đổi vùng, hỏng, sửa, sửa đồ hỏng hẳn — theo VLTK gốc.

var _passes := 0
var _fails := 0

func _ready() -> void:
	print("\n--- TEST ĐỘ BỀN TRANG BỊ ---")
	var p := PlayerProfile.new()
	p.display_name = "TestDur"
	var weapon := ItemGenerator.generate(ItemDatabase.Detail.MELEE, 0, 3, 0, [], 0, 11)
	var armor := ItemGenerator.generate(ItemDatabase.Detail.ARMOR, 0, 3, 0, [], 0, 12)
	var boot := ItemGenerator.generate(ItemDatabase.Detail.BOOT, 0, 3, 0, [], 0, 13)
	var ring := ItemGenerator.generate(ItemDatabase.Detail.RING, 0, 3, 0, [], 0, 14)
	check("Sinh đồ: vũ khí / áo / giày có độ bền đầy", weapon.get_max_durability() > 0 and weapon.durability == weapon.get_max_durability()
		and armor.durability == armor.get_max_durability() and boot.get_max_durability() > 0)
	check("Nhẫn không có độ bền", not ItemDurability.has_durability(ring))
	p.equipment[Equipment.Part.WEAPON] = weapon
	p.equipment[Equipment.Part.BODY] = armor
	p.equipment[Equipment.Part.FOOT] = boot
	p.equipment[Equipment.Part.RING1] = ring

	## KItem::Abrade: tỉ lệ 1/N
	var w_max := weapon.durability
	check("Tỉ lệ 1/1 luôn tụt 1", ItemDurability.abrade_item(weapon, 0, 1) == w_max - 1)
	check("Ô tỉ lệ 0 không tụt", ItemDurability.abrade_item(weapon, 0, 0) == -1 and weapon.durability == w_max - 1)
	weapon.durability = w_max

	## Ra chiêu: chỉ vũ khí (Attack Weapon=768) — chạy nhiều lần thì vũ khí tụt, áo / giày không đổi
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20000:
		ItemDurability.abrade(p, ItemDurability.Kind.ATTACK, rng)
	check("Ra chiêu: vũ khí tụt (~26 điểm / 20000 chiêu)", weapon.durability < w_max and weapon.durability > w_max - 60)
	check("Ra chiêu: áo, giày không tụt", armor.durability == armor.get_max_durability() and boot.durability == boot.get_max_durability())

	## Đổi vùng: giày (Move Foot=7680)
	for i in 50000:
		ItemDurability.abrade(p, ItemDurability.Kind.MOVE, rng)
	check("Đổi vùng: giày tụt, áo không", boot.durability < boot.get_max_durability() and armor.durability == armor.get_max_durability())
	check("Vùng bản đồ 512px", ItemDurability.region_of(Vector2(511, 1030)) == Vector2i(0, 2))

	## Chết có trị PK 5: áo mất ngay 40% độ bền tối đa (PKPunish.txt) + có thể thêm 1; vũ khí không (Defend Weapon=0)
	p.pk_value = 5
	var a_max := armor.get_max_durability()
	var w_before := weapon.durability
	ItemDurability.abrade(p, ItemDurability.Kind.DEFEND, rng)
	check("Chết PK 5: áo mất 40 phần trăm", armor.durability <= a_max - a_max * 40 / 100 and armor.durability >= a_max - a_max * 40 / 100 - 1)
	check("Chết: vũ khí không tụt", weapon.durability == w_before)
	p.pk_value = 0

	## Hỏng: độ bền 1 -> 0 thì báo + tháo về hành trang, mất tác dụng, không mặc lại được
	weapon.durability = 1
	var dmg_before := Equipment.get_weapon_damage(p.equipment)
	var changes := []
	var guard := 0
	while changes.is_empty() and guard < 200000:
		changes = ItemDurability.abrade(p, ItemDurability.Kind.ATTACK, rng)
		guard += 1
	check("Vũ khí hỏng: độ bền 0", weapon.durability == 0 and ItemDurability.is_broken(weapon))
	check("Câu báo đã hỏng", not changes.is_empty() and "đã bị hỏng" in ItemDurability.change_message(changes[0]))
	check("Món hỏng về hành trang", not p.equipment.has(Equipment.Part.WEAPON) and weapon in p.inventory)
	check("Trước khi hỏng có sát thương vũ khí", dmg_before["kind"] != "")
	var eq_broken := {Equipment.Part.WEAPON: weapon}
	check("Đồ hỏng không còn sát thương / chỉ số", Equipment.get_weapon_damage(eq_broken)["kind"] == "" and Equipment.working(eq_broken).is_empty())
	check("Không mặc lại được đồ hỏng", p.equip_from_inventory(p.inventory.find(weapon)) != "")
	check("Hiển thị: Đã hỏng", "Đã hỏng" in ItemText.plain(ItemText.build(weapon, p, -1, -1, false)))

	## Sửa thường (KPlayer::RepairItem)
	boot.durability = boot.get_max_durability() / 2
	var price := ItemDurability.repair_price(boot)
	check("Giá sửa > 0", price > 0)
	var expect := boot.get_base_price() * 50 / 100 * (boot.get_max_durability() - boot.durability) / boot.get_max_durability() * 16 / 16
	check("Giá sửa đúng công thức gốc (đồ trắng)", price == maxi(expect, 1))
	p.gold = 0
	check("Không đủ tiền thì không sửa", not ItemDurability.repair(p, boot)["ok"])
	p.gold = price + 5
	var r := ItemDurability.repair(p, boot)
	check("Sửa xong đầy độ bền, trừ đúng tiền", r["ok"] and boot.durability == boot.get_max_durability() and p.gold == 5)
	check("Đồ hỏng không sửa thường được", ItemDurability.repair(p, weapon)["message"] == ItemDurability.MSG_CANT_REPAIR)

	## Sửa đồ hỏng hẳn (thoren.lua): 50 vạn lượng hoặc 10 xu
	p.gold = 100
	check("Thiếu 50 vạn lượng", not ItemDurability.repair_broken(p, weapon, false)["ok"])
	p.xu = 10
	r = ItemDurability.repair_broken(p, weapon, true)
	check("Sửa hỏng bằng 10 xu", r["ok"] and p.xu == 0 and weapon.durability == weapon.get_max_durability())
	var why := p.equip_from_inventory(p.inventory.find(weapon))
	check("Sau khi sửa không còn bị chặn vì hỏng (%s)" % why, not ("hỏng" in why))

	## Sửa tất cả
	armor.durability = 1
	boot.durability = 1
	p.gold = 10_000_000
	r = ItemDurability.repair_all(p)
	check("Sửa tất cả", r["ok"] and armor.durability == armor.get_max_durability() and boot.durability == boot.get_max_durability())

	## Lưu / đọc
	weapon.durability = 0
	check("Lưu đồ hỏng giữ 0", ItemInstance.from_dict(weapon.to_dict()).durability == 0)
	var old := weapon.to_dict()
	old.erase("dk")
	check("Save cũ độ bền 0 -> đầy (không coi là hỏng)", ItemInstance.from_dict(old).durability == weapon.get_max_durability())

	## Không thể phá hủy
	var hard := ItemGenerator.generate(ItemDatabase.Detail.ARMOR, 0, 3, 0, [], 0, 15)
	hard.magic.append({"attrib": "indestructible_b", "value": [1, 0, 0], "name": "", "prefix": true})
	check("indestructible_b: không tụt", ItemDurability.abrade_item(hard, 90, 1) == -1)
	check("Hiển thị: Không thể phá hủy", "Không thể phá hủy" in ItemText.plain(ItemText.build(hard, p, -1, -1, false)))

	## Online: game gửi độ bền khác -> server giữ bản của nó
	var server_p := PlayerProfile.new()
	var sw := ItemGenerator.generate(ItemDatabase.Detail.MELEE, 0, 3, 0, [], 0, 21)
	sw.ensure_uid()
	sw.durability = 3
	server_p.equipment[Equipment.Part.WEAPON] = sw
	var server_data := server_p.to_dict()
	var client_data := server_data.duplicate(true)
	client_data["equipment"][str(Equipment.Part.WEAPON)]["durability"] = sw.get_max_durability()
	var merged := ProfileGuard.merge(server_data, client_data)
	check("Server giữ độ bền của mình", int(merged["equipment"][str(Equipment.Part.WEAPON)]["durability"]) == 3)

	## Giao diện: đồ hỏng nền đỏ (như chưa đủ yêu cầu), nút "Sửa" trong hành trang, chế độ sửa
	var up := PlayerProfile.new()
	up.display_name = "TestDurUi"
	var bad := ItemGenerator.generate(ItemDatabase.Detail.BOOT, 0, 1, 0, [], 0, 31)
	bad.durability = 0
	var worn := ItemGenerator.generate(ItemDatabase.Detail.BELT, 0, 1, 0, [], 0, 32)
	worn.durability = maxi(worn.get_max_durability() - 3, 1)
	up.add_item(bad)
	up.add_item(worn)
	check("Đồ hỏng: nền đỏ (can_use = false)", not Equipment.can_use(bad, up))
	check("Đồ còn bền cấp 1: nền thường", Equipment.can_use(worn, up))
	var inv := InventoryPopup.open(self, up, Callable())
	var rbtn := inv.find_child("RepairButton", true, false) as Button
	check("Hành trang có nút Sửa cạnh nút Bán", rbtn != null and rbtn.text == "Sửa")
	if rbtn != null:
		rbtn.pressed.emit()
		check("Bấm Sửa: bật chế độ sửa", inv._repair_mode and rbtn.text == "Đang Sửa")
		up.gold = 1_000_000
		var cost := ItemDurability.repair_price(worn)
		inv._on_item_pressed(worn)
		check("Chế độ sửa: bấm món là sửa ngay, trừ tiền", worn.durability == worn.get_max_durability() and up.gold == 1_000_000 - cost)
		inv._on_item_pressed(bad)
		check("Chế độ sửa: món hỏng chưa sửa ngay (hỏi cách trả)", bad.durability == 0 and up.gold == 1_000_000 - cost)
		rbtn.pressed.emit()
		check("Bấm lại: tắt chế độ sửa", not inv._repair_mode and rbtn.text == "Sửa")
	ItemDetailPopup.close_all(get_tree())
	inv.queue_free()
	GameManager.local_profile = up
	var hub = load("res://ui/character_hub/CharacterHub.tscn").instantiate()
	add_child(hub)
	check("Màn nhân vật: hành trang có nút Sửa", hub.find_child("RepairButton", true, false) != null)
	hub.queue_free()
	GameManager.local_profile = null

	print("RESULT %d/%d (hỏng %d)" % [_passes, _passes + _fails, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

func check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("PASS ", name)
	else:
		_fails += 1
		print("FAIL ", name)

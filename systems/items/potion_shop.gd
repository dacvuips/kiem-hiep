class_name PotionShop
## HIỆU THUỐC (nút "Hiệu thuốc" trong Hành trang): bán mọi loại thuốc đang có trong game — vật phẩm misc_items nguồn "potion", có giá
## (cột price gốc) và dùng được (PotionEffect.usable); trùng tên thì giữ 1 món. Dùng chung game (offline mua thẳng) và game server
## (online: gói C_SHOP_BUY -> GameServer gọi buy() trên hồ sơ của server rồi gửi S_PROFILE) — luật mua giống hệt nhau.
## Thuốc Tống Kim (nguồn "songjin", xếp cuối): món có giá "points" trả bằng điểm tích lũy Tống Kim, còn lại trả lượng.

const MAX_COUNT := 99   ## tối đa mỗi lần mua (gói C_SHOP_BUY: u8)

static var _items: Array[String] = []

## Mã các thuốc đang bán, xếp theo nhóm công dụng (hồi máu, nội lực, cả hai, thể lực / giải độc, hoàn tăng chỉ số, Tống Kim), trong nhóm rẻ -> đắt.
static func items() -> Array[String]:
	if not _items.is_empty():
		return _items
	var seen := {}
	for rec in ItemDatabase.list_misc("potion"):
		var mid := str(rec.get("id", ""))
		var name := str(rec.get("name", ""))
		if int(rec.get("price", 0)) <= 0 or seen.has(name):
			continue
		if not PotionEffect.usable(ItemGenerator.generate_misc(mid)):
			continue
		seen[name] = true
		_items.append(mid)
	for rec in ItemDatabase.list_misc("songjin"):
		var mid := str(rec.get("id", ""))
		if cost_of(mid) > 0 and PotionEffect.usable(ItemGenerator.generate_misc(mid)):
			_items.append(mid)
	## Theo nhóm công dụng (category_of), trong nhóm: rẻ -> đắt (Tống Kim: trả lượng trước, trả điểm sau), cùng giá giữ thứ tự gốc.
	var order := {}
	for i in _items.size():
		order[_items[i]] = i
	_items.sort_custom(func(x: String, y: String) -> bool:
		var kx := [category_of(x), 1 if uses_points(x) else 0, cost_of(x), order[x]]
		var ky := [category_of(y), 1 if uses_points(y) else 0, cost_of(y), order[y]]
		return kx < ky)
	return _items

## Nhóm công dụng (Hiệu thuốc xếp theo nhóm, mỗi nhóm bắt đầu hàng mới): CATEGORY_NAMES.
const CATEGORY_NAMES := ["Hồi máu", "Hồi nội lực", "Hồi máu + nội lực", "Thể lực / giải độc", "Hoàn tăng chỉ số", "Đồ Tống Kim"]

static func category_of(mid: String) -> int:
	var rec := ItemDatabase.get_misc(mid)
	if str(rec.get("source", "")) == "songjin":
		return 5
	var life := false
	var mana := false
	var other_tick := false
	for e in rec.get("effects", []):
		match str(e[0]):
			"lifepotion_v", "lifereplenish_v":
				life = true
			"manapotion_v", "manareplenish_v":
				mana = true
			"stamina_v", "poisondamagereduce_v":
				other_tick = true
	if life and mana:
		return 2
	if life:
		return 0
	if mana:
		return 1
	return 3 if other_tick else 4

## Món trả bằng điểm tích lũy Tống Kim (không phải lượng).
static func uses_points(mid: String) -> bool:
	return int(ItemDatabase.get_misc(mid).get("points", 0)) > 0

## Giá 1 bình theo đơn vị của món (điểm Tống Kim hoặc lượng).
static func cost_of(mid: String) -> int:
	var rec := ItemDatabase.get_misc(mid)
	return int(rec.get("points", 0)) if uses_points(mid) else int(rec.get("price", 0))

## "1.200 điểm Tống Kim" / "5 vạn lượng".
static func cost_text(mid: String, n: int = 1) -> String:
	return ("%d điểm Tống Kim" % (cost_of(mid) * n)) if uses_points(mid) else ("%s lượng" % InventoryPopup.format_money(cost_of(mid) * n))

static func price_of(mid: String) -> int:
	return int(ItemDatabase.get_misc(mid).get("price", 0))

## Mua `n` bình `mid` vào `profile`: trừ tiền, thêm vào túi (hết chỗ thì chỉ tính tiền số bình đã thêm).
## Trả {ok, bought, message}.
static func buy(profile: PlayerProfile, mid: String, n: int) -> Dictionary:
	if profile == null or not items().has(mid):
		return {"ok": false, "bought": 0, "message": "Món này không bán ở Hiệu thuốc."}
	n = clampi(n, 1, MAX_COUNT)
	var price := cost_of(mid)
	var points := uses_points(mid)
	var name := str(ItemDatabase.get_misc(mid).get("name", ""))
	if (profile.songjin_points if points else profile.gold) < price * n:
		return {"ok": false, "bought": 0, "message": "Không đủ %s (cần %s)." % ["điểm Tống Kim" if points else "tiền", cost_text(mid, n)]}
	var bought := 0
	for i in n:
		var item := ItemGenerator.generate_misc(mid)
		if item == null or not profile.add_item(item):
			break
		bought += 1
	if bought == 0:
		return {"ok": false, "bought": 0, "message": "Hành trang đã đầy."}
	if points:
		profile.songjin_points -= price * bought
	else:
		profile.gold -= price * bought
	return {"ok": true, "bought": bought, "message": "Đã mua %d %s (%s)%s." % [bought, name, cost_text(mid, bought),
		"" if bought == n else " — hành trang đã đầy"]}

class_name PotionShop
## HIỆU THUỐC (Dược Điếm): bán các loại dược phẩm chuẩn theo game gốc Võ Lâm Truyền Kỳ 1 —
## phân loại theo 4 nhóm công dụng (Hồi sinh lực, Hồi nội lực, Song hồi, Thể lực & giải độc).
## Hỗ trợ danh mục riêng "Quân Nhu Tống Kim" cho các vật phẩm chiến trường Tống Kim (dùng điểm hoặc lượng).
## Dùng chung game (offline mua thẳng) và game server (online: gói C_SHOP_BUY -> GameServer gọi buy()).

const MAX_COUNT := 99   ## tối đa mỗi lần mua (gói C_SHOP_BUY: u8)

## Các món đồ ăn / sự kiện / quest / đan dược không thuộc Dược Điếm chính thống.
const EXCLUDED_POTION_IDS := [
	"1_3_0_2",  # Đùi gà (thức ăn / quest)
	"1_3_0_3",  # Bánh Trung Thu hư (sự kiện)
	"1_3_0_4",  # Toàn Quả hoàn
	"1_3_0_5",  # Toàn Quả hoàn
	"1_7_0_1",  # Bánh chưng Nhân táo (sự kiện)
	"1_7_0_3",  # Bánh chưng Nhân táo
	"1_7_0_4",  # Bánh chưng Nhân táo
	"1_7_0_5",  # Bánh chưng Nhân táo
	"1_9_0_1",  # Phá Quan Hành Quân Đan
	"1_9_0_2",  # Tống Kim Hành Quan Đan
	# 10 loại hoàn tăng thuộc tính (không bán ở Dược Điếm gốc và đều trùng icon obj-potion15):
	"1_5_0_1", "1_5_0_2", "1_5_0_3", "1_5_0_4", "1_5_0_5",
	"1_6_0_1", "1_6_0_2", "1_6_0_3", "1_6_0_4", "1_6_0_5",
]

## Các món Tống Kim trùng lặp với Dược Điếm (Cửu Chuyển, Ô Đầu):
const EXCLUDED_SONGJIN_IDS := [
	"1_0_cuuchuyen",
	"1_1_odau",
]

const PotionEffectScript = preload("res://systems/items/potion_effect.gd")

static var _items: Array[String] = []
static var _songjin_items: Array[String] = []

## Thuốc Dược Điếm chính thống (chuẩn game gốc VLTK 1)
static func items() -> Array[String]:
	if not _items.is_empty():
		return _items
	var seen := {}
	var excluded := {}
	for id in EXCLUDED_POTION_IDS:
		excluded[id] = true
	for rec in ItemDatabase.list_misc("potion"):
		var mid := str(rec.get("id", ""))
		var name := str(rec.get("name", ""))
		if excluded.has(mid) or int(rec.get("price", 0)) <= 0 or seen.has(name):
			continue
		if not PotionEffectScript.usable(ItemGenerator.generate_misc(mid)):
			continue
		seen[name] = true
		_items.append(mid)
	## Thổ Địa Phù (x1) bán ở Hiệu Thuốc theo đúng game gốc VLTK 1
	if not _items.has("5_0_0"):
		_items.append("5_0_0")
	var order := {}
	for i in _items.size():
		order[_items[i]] = i
	_items.sort_custom(func(x: String, y: String) -> bool:
		var kx := [category_of(x), cost_of(x), order[x]]
		var ky := [category_of(y), cost_of(y), order[y]]
		return kx < ky)
	return _items

## Vật phẩm chiến trường Tống Kim (Quân Nhu)
static func songjin_items() -> Array[String]:
	if not _songjin_items.is_empty():
		return _songjin_items
	var excluded := {}
	for id in EXCLUDED_SONGJIN_IDS:
		excluded[id] = true
	for rec in ItemDatabase.list_misc("songjin"):
		var mid := str(rec.get("id", ""))
		if excluded.has(mid) or mid.begins_with("tk_"):
			continue
		if cost_of(mid) > 0 and PotionEffectScript.usable(ItemGenerator.generate_misc(mid)):
			_songjin_items.append(mid)
	var order := {}
	for i in _songjin_items.size():
		order[_songjin_items[i]] = i
	_songjin_items.sort_custom(func(x: String, y: String) -> bool:
		var kx := [1 if uses_points(x) else 0, cost_of(x), order[x]]
		var ky := [1 if uses_points(y) else 0, cost_of(y), order[y]]
		return kx < ky)
	return _songjin_items

## Toàn bộ vật phẩm có thể mua (dùng cho server check mua hợp lệ)
static func all_items() -> Array[String]:
	var all: Array[String] = []
	all.append_array(items())
	all.append_array(songjin_items())
	return all

## Nhóm công dụng (Hiệu thuốc xếp theo nhóm, mỗi nhóm bắt đầu hàng mới): CATEGORY_NAMES.
const CATEGORY_NAMES := ["Hồi máu", "Hồi nội lực", "Hồi máu + nội lực", "Thể lực / giải độc / phù", "Chiến trường Tống Kim"]

static func category_of(mid: String) -> int:
	var rec := ItemDatabase.get_misc(mid)
	if str(rec.get("source", "")) == "songjin":
		return 4
	var life := false
	var mana := false
	for e in rec.get("effects", []):
		match str(e[0]):
			"lifepotion_v", "lifereplenish_v":
				life = true
			"manapotion_v", "manareplenish_v":
				mana = true
	if life and mana:
		return 2
	if life:
		return 0
	if mana:
		return 1
	return 3

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
	if profile == null or not all_items().has(mid):
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
		if item == null or not profile.add_item_stacked(item):
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

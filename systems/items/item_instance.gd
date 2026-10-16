extends RefCounted
class_name ItemInstance
## 1 món trang bị CỤ THỂ (đã sinh) — dữ liệu thuần, to_dict()/from_dict() để lưu save và gửi qua mạng.
## Tương đương KItem gốc: đồ gốc (ItemDatabase) + ngũ hành + giá trị thuộc tính gốc đã roll + tối đa 6
## dòng magic (dòng 1/3/5 = tiền tố, luôn hiệu lực; dòng 2/4/6 = hậu tố, ẨN tới khi được kích hoạt
## bằng ngũ hành — xem Equipment.get_active_counts).

## Phiên bản dữ liệu đồ (data/items) mà base_index/gold_index trỏ vào — 2 = nhập lại từ bản 15 phái. Save cũ không có
## "dv" được đổi chỉ số qua ItemDatabase.remap_index (= DATA_VERSION trong tools/import_vltk_items.py).
const DATA_VERSION := 2
const MAX_MAGIC := 6  ## MAX_ITEM_NORMAL_MAGICATTRIB gốc (2 dòng mở rộng 7-8 là của hoàng kim, chưa có)

var base_index: int = -1
## Đồ HOÀNG KIM: chỉ số trong bảng hoàng kim (ItemDatabase.get_gold) — -1 = đồ thường/xanh (base_index).
var gold_index: int = -1
## 2 dòng mở rộng của hoàng kim (ExpandMagic gốc) — bật theo số món CÙNG BỘ đang mặc (Equipment).
var expand_magic: Array = []
## Vật phẩm KHÔNG phải trang bị (thuốc, khoáng thạch, lệnh bài...): mã trong misc_items.json (ItemDatabase.get_misc) — "" = trang bị.
## Món loại này dùng `count` (số lượng chồng), `item_level` (cấp vật phẩm gốc — VD Huyền Tinh 1-10, Sát Thủ lệnh 20-90)
## và `series` (hệ — Sát Thủ lệnh/giản, Nguyên thạch); không có thuộc tính gốc/dòng magic.
var misc_id: String = ""
var count: int = 1
var item_level: int = 0
var series: int = ElementTypes.ElementType.KIM
## Giá trị thuộc tính gốc đã roll: [[tên, giá trị], ...] (VD weapondamagemin_v 4, durability_v 20).
var base_values: Array = []
## Dòng magic: [{"attrib": tên VLTK, "value": [v0, v1, v2], "name": tên hiển thị, "prefix": bool}, ...]
var magic: Array = []
var durability: int = 0
## Tham số sinh (giống KItemGeneratorParam) — giữ để kiểm tra/tái tạo khi online.
var gen_seed: int = 0
## Ô trên cùng-trái của món trong hành trang (lưới ROOM_WIDTH × ROOM_HEIGHT của PlayerProfile); -1 = chưa xếp chỗ.
var room_x: int = -1
var room_y: int = -1
## Túi chứa món (0 = Túi 1...).
var room_bag: int = 0
var luck: int = 0
## ---- Khoá món đồ / bày bán (KLockItem + itradeprice gốc) ----
## Trạng thái khoá: LOCK_NORMAL = tự do; LOCK_LOCKED = đã khoá (không bán/giao dịch/vứt/đặt giá); LOCK_UNLOCKING = đang chờ mở khoá
## (hết `unlock_at` mới thành tự do); LOCK_FOREVER / LOCK_CHARACTER = khoá vĩnh viễn / gắn nhân vật (không đổi được).
const LOCK_CHARACTER := -3
const LOCK_FOREVER := -2
const LOCK_LOCKED := -1
const LOCK_NORMAL := 0
const LOCK_UNLOCKING := 1
var lock_state: int = LOCK_NORMAL
## ---- Đồ tím (Trang bị Huyền Tinh — Compound: Chế đồ tím / Khảm) ----
## Phẩm chất gốc (GetItemQuality): 0 = trắng/xanh, 2 = đồ tím (có ô khảm). Hoàng kim nhận biết qua gold_index.
const QUALITY_PURPLE := 2
var quality: int = 0
## Số ô khảm CÒN TRỐNG của đồ tím — nằm sau các dòng magic đã khảm (ô k = dòng magic thứ k).
var sockets: int = 0
## Khoáng thuộc tính (6_1_200..205): mã thuộc tính (MAGIC_ID) mang theo — tách từ đồ, dùng để khảm.
var ore_magic: int = 0
## Mã riêng của MÓN ĐỒ NÀY (không trùng món nào khác) — online: server dùng để biết món nào thuộc về ai, chống nhân bản đồ.
var uid: String = ""

static func new_uid() -> String:
	return "%08x%08x" % [randi(), randi()]

## Các khoá trong to_dict() mà chủ đồ được tự đổi (vị trí, khoá, giá bán) — còn lại là chỉ số món đồ, chỉ server tạo ra.
const OWNER_FIELDS := ["rx", "ry", "rb", "lock", "unlock_at", "price"]
var unlock_at: int = 0          ## thời điểm (giây unix) hết chờ mở khoá
var trade_price: int = 0        ## giá bày bán (lượng); 0 = không bán

## Kích thước trong hành trang (số ô rộng × cao) — xem ItemDatabase.size_of().
func get_size() -> Vector2i:
	return ItemDatabase.size_of(get_base())

func get_base() -> Dictionary:
	if misc_id != "":
		return ItemDatabase.get_misc(misc_id)
	return ItemDatabase.get_gold(gold_index) if gold_index >= 0 else ItemDatabase.get_base(base_index)

func is_misc() -> bool:
	return misc_id != ""

## Ảnh vật phẩm (null = không có ảnh -> ô hiện tên chữ). small = bản thu nhỏ sẵn cho ô hành trang 48px.
func get_icon(small: bool = false) -> Texture2D:
	return ItemDatabase.get_icon(get_base(), small)

func is_gold() -> bool:
	return gold_index >= 0

## ĐỒ TÍM: món đã qua "Chế đồ tím" (quality 2) — tên màu tím, ô có vòng sáng tím (RarityRing).
func is_purple() -> bool:
	return quality == QUALITY_PURPLE and not is_misc()

## Bộ hoàng kim (Group gốc) — 0 nếu không thuộc bộ nào. need1: số món để bật mỗi dòng mở rộng;
## need2: số món để đủ bộ (bật hết mọi dòng ẩn).
func get_set_group() -> int:
	return int(get_base().get("group", 0)) if is_gold() else 0

func get_set_need(key: String) -> int:
	return int(get_base().get(key, 0))

## Vật phẩm khác trả -1 — "detail" của chúng (VD thuốc 0-9) trùng số loại trang bị, không được coi là đồ mặc được.
func get_detail() -> int:
	return -1 if is_misc() else int(get_base().get("detail", -1))

func get_level() -> int:
	if is_misc() and item_level > 0:
		return item_level
	return int(get_base().get("level", 1))

func is_weapon() -> bool:
	return get_detail() in [ItemDatabase.Detail.MELEE, ItemDatabase.Detail.RANGE]

func get_base_value(attrib_name: String) -> int:
	for entry in base_values:
		if entry[0] == attrib_name:
			return int(entry[1])
	return 0

func get_max_durability() -> int:
	return get_base_value("durability_v")

## Tên hiển thị: tên đồ gốc (+ hệ). Màu theo phẩm chất: get_quality_color().
func get_display_name() -> String:
	if is_misc():
		return "%s x%d" % [get_base().get("name", "?"), count] if count > 1 else str(get_base().get("name", "?"))
	return "%s (%s)" % [get_base().get("name", "?"), ElementTypes.ELEMENT_NAME.get(series, "?")]

## Thường trắng, có dòng magic xanh lam (đồ xanh VLTK), hoàng kim vàng.
func get_quality_color() -> Color:
	if is_gold():
		return Color(1.0, 0.82, 0.25)
	if is_purple():
		return Color(0.8, 0.5, 1.0)
	return Color(0.45, 0.7, 1.0) if not magic.is_empty() else Color(0.92, 0.92, 0.9)

## Yêu cầu: [[tên requireXXX, giá trị], ...] (requirelevel/requirestr/requiredex/requirevit/requireeng/
## requireseries/requiresex/requiremenpai).
func get_requirements() -> Array:
	return get_base().get("require", [])

func to_dict() -> Dictionary:
	return {"dv": DATA_VERSION, "base": base_index, "gold": gold_index, "series": series, "base_values": base_values.duplicate(true),
		"magic": magic.duplicate(true), "expand_magic": expand_magic.duplicate(true), "durability": durability,
		"seed": gen_seed, "luck": luck, "rx": room_x, "ry": room_y, "rb": room_bag,
		"lock": lock_state, "unlock_at": unlock_at, "price": trade_price, "uid": _ensure_uid(),
		"mid": misc_id, "count": count, "ilv": item_level, "q": quality, "sk": sockets, "om": ore_magic}

func _ensure_uid() -> String:
	if uid == "":
		uid = new_uid()
	return uid

## Mã riêng của món (sinh nếu chưa có) — Chế tạo chọn nguyên liệu theo mã này.
func ensure_uid() -> String:
	return _ensure_uid()

static func from_dict(data: Dictionary) -> ItemInstance:
	var item := ItemInstance.new()
	item.base_index = int(data.get("base", -1))
	item.gold_index = int(data.get("gold", -1))
	if int(data.get("dv", 1)) < DATA_VERSION:
		item.base_index = ItemDatabase.remap_index("base", item.base_index)
		item.gold_index = ItemDatabase.remap_index("gold", item.gold_index)
	item.series = int(data.get("series", 0))
	item.base_values = data.get("base_values", []).duplicate(true)
	for line in data.get("magic", []):
		var v: Array = line.get("value", [0, 0, 0])
		var entry := {"attrib": str(line.get("attrib", "")), "value": [int(v[0]), int(v[1]), int(v[2])],
			"name": str(line.get("name", "")), "prefix": bool(line.get("prefix", true))}
		for k in ["mid", "mlv"]:   ## dòng khảm của đồ tím: mã thuộc tính + cấp thuộc tính (Compound)
			if line.has(k):
				entry[k] = int(line[k])
		item.magic.append(entry)
	for line in data.get("expand_magic", []):
		var ev: Array = line.get("value", [0, 0, 0])
		item.expand_magic.append({"attrib": str(line.get("attrib", "")), "value": [int(ev[0]), int(ev[1]), int(ev[2])],
			"name": str(line.get("name", "")), "prefix": true})
	item.durability = int(data.get("durability", 0))
	item.gen_seed = int(data.get("seed", 0))
	item.luck = int(data.get("luck", 0))
	item.room_x = int(data.get("rx", -1))
	item.room_y = int(data.get("ry", -1))
	item.room_bag = int(data.get("rb", 0))
	item.lock_state = int(data.get("lock", LOCK_NORMAL))
	item.unlock_at = int(data.get("unlock_at", 0))
	item.trade_price = int(data.get("price", 0))
	item.uid = str(data.get("uid", ""))
	item.misc_id = str(data.get("mid", ""))
	item.count = maxi(int(data.get("count", 1)), 1)
	item.item_level = int(data.get("ilv", 0))
	item.quality = int(data.get("q", 0))
	item.sockets = clampi(int(data.get("sk", 0)), 0, MAX_MAGIC)
	item.ore_magic = int(data.get("om", 0))
	if item.uid == "":
		item.uid = new_uid()
	return item

extends RefCounted
class_name MarketBook
## CHỢ GIAO THƯƠNG — sổ hàng treo bán chung của cả máy chủ (mỗi người tối đa MAX_SLOTS món, treo LISTING_SECONDS giây).
## Cùng 1 bộ luật chạy ở 2 nơi: game server (MarketServer — sổ chung, lưu PostgreSQL) và khi chơi một mình (OfflineMarket — hàng người
## chơi giả + hàng của mình lưu trong PlayerProfile.market). Sổ chỉ giữ dữ liệu thuần (Dictionary) để lưu / gửi mạng nguyên dạng.
##
## Listing: {id, sid (mã người bán: character_id online / -1 = mình khi offline / id người chơi giả), seller, item (ItemInstance.to_dict),
##           price, cur (CUR_GOLD lượng | CUR_JADE KNB), at, until (giây unix), state ("on" đang bán | "sold" đã bán chờ nhận tiền)}
## Treo bán: món RỜI hành trang vào sổ. Hết hạn: món nằm lại trong sổ (state "on" nhưng quá until) chờ chủ bấm "Nhận lại".
## Bán được: tiền về người bán ngay nếu đang online, không thì nằm trong sổ (state "sold") tới lúc vào game / mở chợ. Thuế TAX_PERCENT.

const MAX_SLOTS := 10
const LISTING_SECONDS := 7 * 86400
const TAX_PERCENT := 0
const PAGE_SIZE := 60
const CUR_GOLD := 0
const CUR_JADE := 1
const MAX_PRICE := [2_000_000_000, 10_000_000]   ## theo cur

const STATE_ON := "on"
const STATE_SOLD := "sold"

## Loại hàng trong bộ lọc "Loại": [mã, tên].
const CATEGORIES := [
	["all", "Toàn bộ"], ["melee", "Cận chiến"], ["range", "Tầm xa"], ["armor", "Y phục"], ["helm", "Nón"],
	["cuff", "Hộ uyển"], ["boot", "Giày"], ["belt", "Yêu đái"], ["jewel", "Trang sức"], ["pendant", "Ngọc bội"],
	["horse", "Ngựa"], ["potion", "Dược phẩm"], ["quest", "Nhiệm vụ"], ["tool", "Đạo cụ"],
]
const _DETAIL_CATEGORY := {
	ItemDatabase.Detail.MELEE: "melee", ItemDatabase.Detail.RANGE: "range", ItemDatabase.Detail.ARMOR: "armor",
	ItemDatabase.Detail.HELM: "helm", ItemDatabase.Detail.CUFF: "cuff", ItemDatabase.Detail.BOOT: "boot",
	ItemDatabase.Detail.BELT: "belt", ItemDatabase.Detail.RING: "jewel", ItemDatabase.Detail.AMULET: "jewel",
	ItemDatabase.Detail.PENDANT: "pendant", ItemDatabase.Detail.HORSE: "horse",
}

var listings: Dictionary = {}     ## id -> listing
var _items: Dictionary = {}       ## id -> ItemInstance (đọc 1 lần từ listing.item, dùng cho bộ lọc / hiển thị)

# ------------------------------------------------------------------ dữ liệu

func put(l: Dictionary) -> void:
	listings[str(l["id"])] = l
	_items.erase(str(l["id"]))

func remove(id: String) -> void:
	listings.erase(id)
	_items.erase(id)

func item_of(id: String) -> ItemInstance:
	if not _items.has(id):
		var l: Dictionary = listings.get(id, {})
		_items[id] = ItemInstance.from_dict(l.get("item", {})) if l.get("item") is Dictionary else null
	return _items[id]

func of_seller(sid: int) -> Array:
	var out := []
	for l in listings.values():
		if int(l["sid"]) == sid:
			out.append(l)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	return out

static func new_id(now: int) -> String:
	return "%x%s" % [now, ItemInstance.new_uid()]

static func is_live(l: Dictionary, now: int) -> bool:
	return str(l.get("state", "")) == STATE_ON and int(l.get("until", 0)) > now

# ------------------------------------------------------------------ bộ lọc

## filter: {cat: mã CATEGORIES, series: -1 | hệ, level: 0 | cấp, attrib: "" | tên thuộc tính (attrib_options), cur: -1 | CUR_*, name: chữ}
func query(filter: Dictionary, now: int, limit := PAGE_SIZE) -> Array:
	var out := []
	for id in listings:
		var l: Dictionary = listings[id]
		if is_live(l, now) and matches(item_of(id), l, filter):
			out.append(l)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	return out.slice(0, limit)

static func matches(item: ItemInstance, l: Dictionary, f: Dictionary) -> bool:
	if item == null:
		return false
	var cat := str(f.get("cat", "all"))
	if cat != "all" and category_of(item) != cat:
		return false
	var series := int(f.get("series", -1))
	if series >= 0 and (item.is_misc() or item.series != series):
		return false
	var level := int(f.get("level", 0))
	if level > 0 and item.get_level() != level:
		return false
	var cur := int(f.get("cur", -1))
	if cur >= 0 and int(l.get("cur", CUR_GOLD)) != cur:
		return false
	var attrib := str(f.get("attrib", ""))
	if attrib != "" and not _has_attrib(item, attrib_options().get(attrib, [])):
		return false
	var text := str(f.get("name", "")).strip_edges().to_lower()
	if text != "" and not str(item.get_base().get("name", "")).to_lower().contains(text):
		return false
	return true

static func category_of(item: ItemInstance) -> String:
	if item.is_misc():
		match str(item.get_base().get("source", "")):
			"potion":
				return "potion"
			"questkey":
				return "quest"
		return "tool"
	return str(_DETAIL_CATEGORY.get(item.get_detail(), "tool"))

static func _has_attrib(item: ItemInstance, keys: Array) -> bool:
	for line in item.magic + item.expand_magic:
		if keys.has(str(line.get("attrib", ""))):
			return true
	return false

## Bộ lọc "Thuộc Tính": tên hiển thị (phần trước dấu ":" trong MagicDesc gốc) -> các mã thuộc tính VLTK cùng tên.
static var _attrib_options: Dictionary = {}
static func attrib_options() -> Dictionary:
	if _attrib_options.is_empty():
		for rec in ItemDatabase.get_magic_records():
			var key := str(rec.get("attrib", ""))
			var label := ItemDatabase.get_desc_template(key).get_slice(":", 0).strip_edges()
			if label == "" or label.contains("#"):
				continue
			if not _attrib_options.has(label):
				_attrib_options[label] = []
			if not (_attrib_options[label] as Array).has(key):
				_attrib_options[label].append(key)
	return _attrib_options

# ------------------------------------------------------------------ tiền

static func money(p: PlayerProfile, cur: int) -> int:
	return p.jade if cur == CUR_JADE else p.gold

static func add_money(p: PlayerProfile, cur: int, amount: int) -> void:
	if cur == CUR_JADE:
		p.jade += amount
	else:
		p.gold += amount

static func proceeds(price: int) -> int:
	@warning_ignore("integer_division")
	return price - price * TAX_PERCENT / 100

## "30 KNB" / "3 vạn lượng" / "2,5 vạn lượng" / "800 lượng".
static func price_text(price: int, cur: int) -> String:
	if cur == CUR_JADE:
		return "%d KNB" % price
	if price < 10000:
		return "%d lượng" % price
	var van := snappedf(price / 10000.0, 0.01)
	var s := str(int(van)) if is_equal_approx(van, roundf(van)) else String.num(van, 2).replace(".", ",")
	return "%s vạn lượng" % s

## Thời gian còn lại kiểu "6n 21g" / "5g 12p" / "Hết hạn".
static func remaining_text(until: int, now: int) -> String:
	var left := until - now
	if left <= 0:
		return "Hết hạn"
	@warning_ignore("integer_division")
	var d := left / 86400
	@warning_ignore("integer_division")
	var h := (left % 86400) / 3600
	@warning_ignore("integer_division")
	var m := (left % 3600) / 60
	if d > 0:
		return "%dn %dg" % [d, h]
	return "%dg %dp" % [h, maxi(1, m)] if h > 0 else "%dp" % maxi(1, m)

# ------------------------------------------------------------------ thao tác (trên hồ sơ của người thao tác)

## Treo bán món `uid` trong hành trang của `p`. Trả về [lỗi, listing] — lỗi "" thì món đã rời hành trang, listing đã vào sổ.
func sell(p: PlayerProfile, sid: int, uid: String, price: int, cur: int, now: int) -> Array:
	var blocked := SecurityLock.check(p, SecurityLock.A_OPEN_STALL)
	if blocked != "":
		return [blocked, {}]
	if p.stall_open:
		return ["Đang bày bán — hãy dọn quầy trước.", {}]
	var item: ItemInstance = null
	for it in p.inventory:
		if it.uid == uid:
			item = it
			break
	if item == null:
		return ["Món đồ không có trong hành trang.", {}]
	if SecurityLock.is_item_locked(item) or item.lock_state == ItemInstance.LOCK_CHARACTER:
		return ["Món đồ đang bị khoá, không treo bán được.", {}]
	if cur != CUR_GOLD and cur != CUR_JADE:
		return ["Loại tiền không hợp lệ.", {}]
	if price <= 0 or price > int(MAX_PRICE[cur]):
		return ["Giá không hợp lệ.", {}]
	if of_seller(sid).size() >= MAX_SLOTS:
		return ["Đã treo đủ %d món — hãy huỷ treo bớt." % MAX_SLOTS, {}]
	p.inventory.erase(item)
	item.trade_price = 0
	item.room_x = -1
	item.room_y = -1
	var l := {"id": new_id(now), "sid": sid, "seller": p.display_name, "item": item.to_dict(), "price": price, "cur": cur,
		"at": now, "until": now + LISTING_SECONDS, "state": STATE_ON}
	put(l)
	return ["", l]

## Mua listing `id`. Tiền người mua trừ, món vào hành trang; listing đổi sang "sold" (người gọi trả tiền cho người bán qua claim).
## Trả về [lỗi, listing].
func buy(p: PlayerProfile, buyer_sid: int, id: String, now: int) -> Array:
	var blocked := SecurityLock.check(p, SecurityLock.A_STALL_BUY)
	if blocked != "":
		return [blocked, {}]
	var l: Dictionary = listings.get(id, {})
	if l.is_empty() or not is_live(l, now):
		return ["Món hàng đã được bán hoặc hết hạn.", {}]
	if int(l["sid"]) == buyer_sid:
		return ["Không thể mua hàng của chính mình.", {}]
	var cur := int(l["cur"])
	var price := int(l["price"])
	if money(p, cur) < price:
		return ["Không đủ %s." % ("KNB" if cur == CUR_JADE else "lượng"), {}]
	var item := ItemInstance.from_dict(l["item"])
	if not p.add_item(item):
		return ["Hành trang đã đầy.", {}]
	add_money(p, cur, -price)
	l["state"] = STATE_SOLD
	l["buyer"] = p.display_name
	l["item"] = {}          ## món đã sang người mua — sổ chỉ còn giữ tiền chờ người bán nhận
	l["name"] = str(item.get_base().get("name", "?"))
	_items.erase(id)
	return ["", l]

## Người bán nhận tiền các món đã bán. Trả về tổng đã nhận theo loại tiền [lượng, KNB] và xoá listing khỏi sổ.
func claim_sold(p: PlayerProfile, sid: int) -> Array:
	var got := [0, 0]
	for l in of_seller(sid):
		if str(l["state"]) == STATE_SOLD:
			var cur := int(l["cur"])
			var amount := proceeds(int(l["price"]))
			add_money(p, cur, amount)
			got[cur] += amount
			remove(str(l["id"]))
	return got

## Huỷ treo / nhận lại món hết hạn: món về hành trang. "" nếu xong.
func cancel(p: PlayerProfile, sid: int, id: String) -> String:
	var l: Dictionary = listings.get(id, {})
	if l.is_empty() or int(l["sid"]) != sid:
		return "Không tìm thấy món đang treo."
	if str(l["state"]) != STATE_ON:
		return "Món này đã bán."
	var item := ItemInstance.from_dict(l["item"])
	if not p.add_item(item):
		return "Hành trang đã đầy."
	remove(id)
	return ""

## Dòng thông báo "đã bán" cho người bán (đọc trước khi claim_sold xoá listing).
static func sold_line(l: Dictionary) -> String:
	return "%s đã mua %s của bạn: +%s." % [str(l.get("buyer", "?")), str(l.get("name", "?")),
		price_text(proceeds(int(l["price"])), int(l["cur"]))]

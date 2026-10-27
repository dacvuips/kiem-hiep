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
const TAX_PERCENT := 3                  ## 3% / ngày đăng bán
const TAX_INTERVAL_SECONDS := 86400     ## chu kỳ 24h thu thuế duy trì
const PAGE_SIZE := 50                   ## số món mỗi trang danh sách Giao Thương
const CUR_GOLD := 0
const CUR_JADE := 1
const MAX_PRICE := [2_000_000_000, 10_000_000]   ## theo cur

## "Nội dung rao" người bán ghi kèm món (không bắt buộc): tối đa NOTE_MAX ký tự, 1 dòng (clean_note — server làm sạch, không tin game).
const NOTE_MAX := 100
const STATE_ON := "on"
const STATE_PROCESSING := "processing"
const STATE_SOLD := "sold"

var _busy_sell_uids: Dictionary = {} ## uid -> true: chống spam click / concurrent sell cùng 1 item

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
## 1 trang (PAGE_SIZE món, mới treo trước) các món khớp bộ lọc: {items, page, pages, total}. `page` ngoài khoảng -> kẹp về trang có thật.
func query(filter: Dictionary, now: int, page := 0) -> Dictionary:
	var out := []
	for id in listings:
		var l: Dictionary = listings[id]
		if is_live(l, now) and matches(item_of(id), l, filter):
			out.append(l)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	var pages := maxi(1, ceili(out.size() / float(PAGE_SIZE)))
	page = clampi(page, 0, pages - 1)
	return {"items": out.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE), "page": page, "pages": pages, "total": out.size()}

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
		p.jade = clampi(p.jade + amount, 0, PlayerProfile.MAX_JADE)
	else:
		if amount > 0:
			var space_in_pocket := maxi(0, PlayerProfile.MAX_GOLD - p.gold)
			if amount <= space_in_pocket:
				p.gold += amount
			else:
				p.gold = PlayerProfile.MAX_GOLD
				var overflow := amount - space_in_pocket
				p.storage_gold = clampi(p.storage_gold + overflow, 0, PlayerProfile.MAX_STORAGE_GOLD)
		else:
			p.gold = maxi(0, p.gold + amount)

static func proceeds(price: int) -> int:
	@warning_ignore("integer_division")
	return price - price * TAX_PERCENT / 100

## Phí niêm yết 3% / ngày (tính theo giá bán):
static func listing_fee(price: int, cur: int) -> int:
	var base_gold: int = price if cur == CUR_GOLD else price * 30000
	return maxi(100, int(ceili(base_gold * (TAX_PERCENT / 100.0))))

## Kiểm tra tổng tiền trong túi + tiền trong rương có đủ phí không
static func can_afford_tax(p: PlayerProfile, fee: int) -> bool:
	return (p.gold + p.storage_gold) >= fee

## Trừ thuế: trừ vào túi trước, nếu thiếu thì trừ tiếp vào rương
static func deduct_tax(p: PlayerProfile, fee: int) -> bool:
	if not can_afford_tax(p, fee):
		return false
	if p.gold >= fee:
		p.gold -= fee
	else:
		var remain := fee - p.gold
		p.gold = 0
		p.storage_gold -= remain
	return true

## Trả vật phẩm về cho người chơi:
## 1. Hành trang (túi 1..3).
## 2. Rương đồ đã mở khóa (rương 1..storage_extra+1).
## 3. Rương khóa (các ngăn rương mở rộng chưa mở, bag = storage_extra+1..MAX_EXTRA_BOXES).
## Muốn lấy đồ ở rương khóa thì chỉ cần mở khóa rương đó.
static func return_item_to_player(p: PlayerProfile, item: ItemInstance) -> Dictionary:
	if item == null:
		return {"ok": false, "target": ""}
	
	# 1. Thử đưa vào hành trang
	if p.add_item(item):
		return {"ok": true, "target": "hành trang"}
	
	# 2. Thử đưa vào các ngăn rương đã mở khóa
	var spot := p.storage.find_free_spot_any(item.get_size())
	if spot.z >= 0:
		item.room_x = spot.x
		item.room_y = spot.y
		item.room_bag = spot.z
		p.storage.inventory.append(item)
		return {"ok": true, "target": "Rương %d" % (spot.z + 1)}
	
	# 3. Thử đưa vào các ngăn Rương Khóa chưa mở (từ storage_extra + 1 đến MAX_EXTRA_BOXES)
	for locked_bag in range(p.storage_extra + 1, 1 + StorageService.MAX_EXTRA_BOXES):
		var s := p.storage.find_free_spot(item.get_size(), locked_bag)
		if s.x >= 0:
			item.room_x = s.x
			item.room_y = s.y
			item.room_bag = locked_bag
			p.storage.inventory.append(item)
			return {"ok": true, "target": "Rương Khóa (Rương %d — mở khóa rương để lấy)" % (locked_bag + 1)}
	
	# 4. Dự phòng khẩn cấp nếu toàn bộ rương đã kín:
	var emergency_bag := 1 + StorageService.MAX_EXTRA_BOXES
	var s_em := p.storage.find_free_spot(item.get_size(), emergency_bag)
	if s_em.x < 0:
		s_em = Vector2i(0, 0)
	item.room_x = s_em.x
	item.room_y = s_em.y
	item.room_bag = emergency_bag
	p.storage.inventory.append(item)
	return {"ok": true, "target": "Rương Khóa (Rương Dự Phòng)"}

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
## Nội dung rao an toàn: bỏ ký tự điều khiển (xuống dòng / tab -> dấu cách), gộp khoảng trắng, cắt NOTE_MAX ký tự. Hiển thị bằng chữ
## thường (Label), không qua BBCode — không chèn được định dạng / liên kết.
static func clean_note(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var ch := raw.unicode_at(i)
		out += " " if ch < 32 or ch == 127 else raw[i]
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges().left(NOTE_MAX)

func sell(p: PlayerProfile, sid: int, uid: String, price: int, cur: int, now: int, note := "") -> Array:
	var blocked := SecurityLock.check(p, SecurityLock.A_OPEN_STALL)
	if blocked != "":
		return [blocked, {}]
	if p.stall_open:
		return ["Đang bày bán — hãy dọn quầy trước.", {}]
	if _busy_sell_uids.has(uid):
		return ["Vật phẩm đang được xử lý đăng bán.", {}]
	_busy_sell_uids[uid] = true
	var item: ItemInstance = null
	for it in p.inventory:
		if it.uid == uid:
			item = it
			break
	if item == null:
		_busy_sell_uids.erase(uid)
		return ["Món đồ không có trong hành trang.", {}]
	if SecurityLock.is_item_locked(item) or item.lock_state == ItemInstance.LOCK_CHARACTER:
		_busy_sell_uids.erase(uid)
		return ["Món đồ đang bị khoá, không treo bán được.", {}]
	if item.trade_price > 0:
		_busy_sell_uids.erase(uid)
		return ["Món đồ đang được đặt giá bày bán.", {}]
	if cur != CUR_GOLD and cur != CUR_JADE:
		_busy_sell_uids.erase(uid)
		return ["Loại tiền không hợp lệ.", {}]
	if price <= 0 or price > int(MAX_PRICE[cur]):
		_busy_sell_uids.erase(uid)
		return ["Giá không hợp lệ.", {}]
	if of_seller(sid).size() >= MAX_SLOTS:
		_busy_sell_uids.erase(uid)
		return ["Đã treo đủ %d món — hãy huỷ treo bớt." % MAX_SLOTS, {}]
	var fee := listing_fee(price, cur)
	if not can_afford_tax(p, fee):
		_busy_sell_uids.erase(uid)
		return ["Không đủ tiền đóng thuế đăng bán 3%%/ngày (cần %s). Tổng tiền trong túi và rương không đủ!" % price_text(fee, CUR_GOLD), {}]
	deduct_tax(p, fee)
	p.inventory.erase(item)
	_busy_sell_uids.erase(uid)
	item.trade_price = 0
	item.room_x = -1
	item.room_y = -1
	var l := {"id": new_id(now), "sid": sid, "seller": p.display_name, "item": item.to_dict(), "price": price, "cur": cur,
		"at": now, "until": now + LISTING_SECONDS, "state": STATE_ON, "tax_fee": fee, "tax_paid_until": now + TAX_INTERVAL_SECONDS}
	var clean := clean_note(note)
	if clean != "":
		l["note"] = clean
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
	if str(l.get("state", "")) != STATE_ON:
		return ["Món hàng đang được xử lý giao dịch.", {}]
	if int(l["sid"]) == buyer_sid:
		return ["Không thể mua hàng của chính mình.", {}]

	# Khóa tức thì trạng thái sang processing để ngăn chặn song song / race condition
	l["state"] = STATE_PROCESSING

	var cur := int(l["cur"])
	var price := int(l["price"])
	if money(p, cur) < price:
		l["state"] = STATE_ON
		return ["Không đủ %s." % ("KNB" if cur == CUR_JADE else "lượng"), {}]
	var item := item_of(id)
	if item == null:
		l["state"] = STATE_ON
		return ["Dữ liệu món đồ bị lỗi.", {}]
	var sz := item.get_size()
	if p.find_free_spot_any(sz).z < 0:
		l["state"] = STATE_ON
		return ["Hành trang không đủ chỗ trống (cần vùng %dx%d ô). Hãy dọn bớt túi đồ trước khi mua!" % [sz.x, sz.y], {}]
	if not p.add_item(item):
		l["state"] = STATE_ON
		return ["Hành trang không đủ chỗ trống.", {}]
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

## Huỷ treo / nhận lại món hết hạn: món về hành trang, rương hoặc rương khóa.
func cancel(p: PlayerProfile, sid: int, id: String) -> Dictionary:
	var l: Dictionary = listings.get(id, {})
	if l.is_empty() or int(l["sid"]) != sid:
		return {"error": "Không tìm thấy món đang treo.", "target": ""}
	if str(l.get("state", "")) != STATE_ON:
		return {"error": "Món này đã bán hoặc đang giao dịch.", "target": ""}

	# Khóa trạng thái listing ngay lập tức
	l["state"] = STATE_PROCESSING

	var item := item_of(id)
	if item == null:
		l["state"] = STATE_ON
		return {"error": "Dữ liệu món đồ bị lỗi.", "target": ""}
	var ret := return_item_to_player(p, item)
	if not ret.get("ok", false):
		l["state"] = STATE_ON
		return {"error": "Không thể hoàn trả vật phẩm.", "target": ""}
	remove(id)
	return {"error": "", "target": str(ret.get("target", "hành trang"))}

## Kiểm tra và thu thuế 3%/ngày cho các món đang treo của người bán `sid`.
## Nếu đủ tiền: trừ tiền (túi trước, rương sau) và gia hạn thêm 1 ngày.
## Nếu KHÔNG đủ tiền hoặc hết hạn 7 ngày: tự động hủy treo và hoàn trả vật phẩm về hành trang/rương/rương khóa!
## Trả về mảng các thông báo kết quả: [{type, id, name, text}].
func process_seller_daily_taxes(p: PlayerProfile, sid: int, now: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for l in of_seller(sid):
		if str(l.get("state", "")) != STATE_ON:
			continue
		var id := str(l.get("id", ""))
		var until := int(l.get("until", 0))
		var paid_until := int(l.get("tax_paid_until", int(l.get("at", 0)) + TAX_INTERVAL_SECONDS))
		var it := item_of(id)
		var item_name := str(it.get_base().get("name", "Vật phẩm")) if it else "Vật phẩm"

		# 1. Hết hạn niêm yết 7 ngày
		if now >= until:
			var ret := return_item_to_player(p, it)
			remove(id)
			results.append({
				"type": "cancelled",
				"id": id,
				"name": item_name,
				"text": "Món %s đã hết hạn niêm yết (7 ngày) và được hoàn trả về %s." % [item_name, ret.get("target", "hành trang")]
			})
			continue

		# 2. Hết hạn 24h chu kỳ thuế ngày -> thu thuế ngày mới
		if now >= paid_until:
			var fee := int(l.get("tax_fee", listing_fee(int(l.get("price", 0)), int(l.get("cur", 0)))))
			if can_afford_tax(p, fee):
				deduct_tax(p, fee)
				l["tax_paid_until"] = now + TAX_INTERVAL_SECONDS
				results.append({
					"type": "paid",
					"id": id,
					"name": item_name,
					"text": "Đã trừ %s phí duy trì ngày mới (3%%) cho món %s trên Chợ." % [price_text(fee, CUR_GOLD), item_name]
				})
			else:
				# Không đủ tiền đóng 3% phí ngày mới -> Tự động hủy treo và trả đồ về!
				var ret := return_item_to_player(p, it)
				remove(id)
				results.append({
					"type": "cancelled",
					"id": id,
					"name": item_name,
					"text": "Không đủ tiền đóng thuế duy trì 3%% ngày mới (cần %s)! Món %s đã bị hủy treo và chuyển về %s." % [price_text(fee, CUR_GOLD), item_name, ret.get("target", "hành trang")]
				})
	return results

## Dòng thông báo "đã bán" cho người bán (đọc trước khi claim_sold xoá listing).
static func sold_line(l: Dictionary) -> String:
	return "%s đã mua %s của bạn: +%s." % [str(l.get("buyer", "?")), str(l.get("name", "?")),
		price_text(proceeds(int(l["price"])), int(l["cur"]))]

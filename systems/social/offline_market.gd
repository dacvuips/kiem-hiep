extends RefCounted
class_name OfflineMarket
## CHỢ GIAO THƯƠNG khi chơi một mình: sổ MarketBook gồm hàng của người chơi giả (SocialDirectory, sinh lại mỗi phiên) + hàng của mình
## (PlayerProfile.market, được lưu). Trả lời đúng định dạng gói S_MARKET của MarketServer để MarketWindow không cần biết đang online hay không.
## Khách giả thỉnh thoảng mua hàng mình treo (tick) — tiền về ngay như người bán đang online.

const SELF_SID := -1
const CUSTOMER_SECONDS := 15.0

static var _book: MarketBook
static var _owner_key := ""

static func now() -> int:
	return int(Time.get_unix_time_from_system())

static func book(p: PlayerProfile) -> MarketBook:
	var key := "%s|%d" % [p.display_name, p.get_instance_id()]
	if _book == null or _owner_key != key:
		_owner_key = key
		_book = MarketBook.new()
		_fill_mock(p)
		for l in p.market:
			if l is Dictionary and l.has("id"):
				_book.put((l as Dictionary).duplicate(true))
	return _book

## op: "list" {filter} | "mine" | "sell" {uid, price, cur} | "buy" {id} | "cancel" {id} -> Dictionary như S_MARKET.
static func handle(p: PlayerProfile, op: String, args: Dictionary) -> Dictionary:
	var b := book(p)
	var t := now()
	match op:
		"list":
			return {"op": "list", "items": b.query(args.get("filter", {}), t), "now": t}
		"mine":
			var got := b.claim_sold(p, SELF_SID)
			if got[0] > 0 or got[1] > 0:
				_store(p)
			return {"op": "mine", "items": b.of_seller(SELF_SID), "now": t, "slots": MarketBook.MAX_SLOTS}
		"sell":
			var r := b.sell(p, SELF_SID, str(args.get("uid", "")), int(args.get("price", 0)), int(args.get("cur", 0)), t)
			if r[0] == "":
				_store(p)
			return _done(r[0], "Đã treo bán %s." % _name(r[1]))
		"buy":
			var r := b.buy(p, SELF_SID, str(args.get("id", "")), t)
			if r[0] == "":
				b.remove(str(r[1]["id"]))   ## người bán là người chơi giả: tiền coi như đã về họ
				_store(p)
			return _done(r[0], "Mua %s thành công!" % str(r[1].get("name", "")))
		"cancel":
			var err := b.cancel(p, SELF_SID, str(args.get("id", "")))
			if err == "":
				_store(p)
			return _done(err, "Đã huỷ treo — món đồ đã về hành trang.")
	return _done("Thao tác không hợp lệ.", "")

## Khách giả mua hàng mình treo (gọi từ SocialHub.tick). Trả về các dòng thông báo bán được.
static var _clock := 0.0
static func tick(p: PlayerProfile, delta: float, rng: RandomNumberGenerator) -> Array[String]:
	var lines: Array[String] = []
	if p.market.is_empty():
		return lines
	_clock += delta
	if _clock < CUSTOMER_SECONDS:
		return lines
	_clock = 0.0
	var b := book(p)
	var t := now()
	var mine := b.of_seller(SELF_SID).filter(func(l: Dictionary) -> bool: return MarketBook.is_live(l, t))
	if mine.is_empty():
		return lines
	var l: Dictionary = mine[rng.randi() % mine.size()]
	var item := b.item_of(str(l["id"]))
	var fair := float(MockPlayer.suggested_price(item)) if item else 1.0
	var price := float(l["price"]) * (30000.0 if int(l["cur"]) == MarketBook.CUR_JADE else 1.0)   ## 1 KNB ~ 3 vạn lượng
	var chance := clampf(1.2 - price / maxf(1.0, fair) * 0.6, 0.03, 0.8)
	if rng.randf() > chance:
		return lines
	var buyers := SocialDirectory.players(p)
	l["state"] = MarketBook.STATE_SOLD
	l["buyer"] = buyers[rng.randi() % buyers.size()].name if not buyers.is_empty() else "Khách"
	l["name"] = str(item.get_base().get("name", "?")) if item else "?"
	l["item"] = {}
	lines.append(MarketBook.sold_line(l))
	b.claim_sold(p, SELF_SID)
	_store(p)
	return lines

static func _store(p: PlayerProfile) -> void:
	p.market = _book.of_seller(SELF_SID).duplicate(true)
	SaveManager.save_profile(p)

static func _done(err: String, ok_text: String) -> Dictionary:
	return {"op": "done", "ok": err == "", "msg": err if err != "" else ok_text}

static func _name(l: Dictionary) -> String:
	var d: Variant = l.get("item", {})
	return str(ItemInstance.from_dict(d).get_base().get("name", "")) if d is Dictionary and not (d as Dictionary).is_empty() else ""

## Hàng của người chơi giả: mỗi người 1-3 món (trang bị / thuốc), giá quanh giá gợi ý, 1/4 số món bán bằng KNB.
static func _fill_mock(p: PlayerProfile) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p.display_name) ^ 0x3A2B
	var t := now()
	var potions := ItemDatabase.list_misc("potion")
	for m in SocialDirectory.players(p):
		for k in rng.randi_range(1, 3):
			var item: ItemInstance
			if not potions.is_empty() and rng.randf() < 0.2:
				item = ItemGenerator.generate_misc(str(potions[rng.randi() % potions.size()]["id"]), 0, 0, rng.randi_range(5, 50))
			else:
				item = ItemGenerator.random_equipment(clampi(m.level + rng.randi_range(-10, 10), 1, 150))
			if item == null:
				continue
			var fair := MockPlayer.suggested_price(item) * maxi(1, item.count)
			var cur := MarketBook.CUR_JADE if rng.randf() < 0.25 else MarketBook.CUR_GOLD
			var price := maxi(1, int(fair * rng.randf_range(0.8, 1.6) / 30000.0)) if cur == MarketBook.CUR_JADE \
				else maxi(100, int(snappedf(fair * rng.randf_range(0.8, 1.6), 1000)))
			var at := t - rng.randi_range(60, MarketBook.LISTING_SECONDS - 3600)
			_book.put({"id": MarketBook.new_id(at), "sid": m.id, "seller": m.name, "item": item.to_dict(), "price": price,
				"cur": cur, "at": at, "until": at + MarketBook.LISTING_SECONDS, "state": MarketBook.STATE_ON})

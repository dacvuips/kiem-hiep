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

## Câu rao mẫu của người bán giả (chơi một mình).
const SAMPLE_NOTES := [
	"Hàng chuẩn, bán nhanh để lấy tiền mua ngựa.",
	"Giá mềm cho anh em tân thủ, ai cần thì mua liền tay.",
	"Đồ đánh boss rơi ra, còn mới tinh, không bớt nữa nhé.",
	"Cần gấp lượng để gia nhập bang — giá đã rẻ nhất chợ rồi!",
	"Ai mua nhiều món của mình thì nhắn riêng, sẽ bớt thêm.",
	"Bán thanh lý hành trang đầy, chỉ treo trong vài ngày.",
]

## op: "list" {filter} | "mine" | "sell" {uid, price, cur} | "buy" {id} | "cancel" {id} -> Dictionary như S_MARKET.
static func handle(p: PlayerProfile, op: String, args: Dictionary) -> Dictionary:
	var b := book(p)
	var t := now()
	match op:
		"list":
			var res := b.query(args.get("filter", {}), t, int(args.get("page", 0)))
			res["op"] = "list"
			res["now"] = t
			return res
		"mine":
			var tax_events := b.process_seller_daily_taxes(p, SELF_SID, t)
			var got := b.claim_sold(p, SELF_SID)
			if got[0] > 0 or got[1] > 0 or not tax_events.is_empty():
				_store(p)
			return {"op": "mine", "items": b.of_seller(SELF_SID), "now": t, "slots": MarketBook.MAX_SLOTS}
		"sell":
			var r := b.sell(p, SELF_SID, str(args.get("uid", "")), int(args.get("price", 0)), int(args.get("cur", 0)), t, str(args.get("note", "")))
			if r[0] == "":
				_store(p)
			return _done(r[0], "Đã treo bán %s (đã trừ 3%% thuế)." % _name(r[1]))
		"buy":
			var r := b.buy(p, SELF_SID, str(args.get("id", "")), t)
			if r[0] == "":
				b.remove(str(r[1]["id"]))   ## người bán là người chơi giả: tiền coi như đã về họ
				_store(p)
			return _done(r[0], "Mua %s thành công!" % str(r[1].get("name", "")))
		"cancel":
			var res := b.cancel(p, SELF_SID, str(args.get("id", "")))
			var err: String = str(res.get("error", ""))
			if err == "":
				_store(p)
			var target_str := str(res.get("target", "hành trang"))
			return _done(err, "Đã huỷ treo — món đồ đã chuyển về %s." % target_str)
	return _done("Thao tác không hợp lệ.", "")

## Cấm tuyệt đối bot mua đồ — chỉ người chơi thật mới có quyền mua đồ.
static func tick(_p: PlayerProfile, _delta: float, _rng: RandomNumberGenerator) -> Array[String]:
	return []

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
			var l := {"id": MarketBook.new_id(at), "sid": m.id, "seller": m.name, "item": item.to_dict(), "price": price,
				"cur": cur, "at": at, "until": at + MarketBook.LISTING_SECONDS, "state": MarketBook.STATE_ON}
			if rng.randf() < 0.5:   ## người bán giả cũng rao như người thật (khoảng nửa số món)
				l["note"] = SAMPLE_NOTES[rng.randi() % SAMPLE_NOTES.size()]
			_book.put(l)

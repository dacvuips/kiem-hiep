extends RefCounted
class_name StallService
## BÀY BÁN (quầy bán cá nhân) — theo KProtocolProcess::TradeSet/TradeBuy + KPlayer::TradeStart/SendTradeItem của VLTK gốc:
##   - Người bán đặt GIÁ cho từng món trong hành trang (c2s_playertradeset). Món KHOÁ (khoá món / không giao dịch) không được đặt giá.
##   - Mở quầy (c2s_playertradestart) khi: không bị khoá bảo vệ, không đang giao dịch, không cưỡi ngựa, có ít nhất 1 món đã đặt giá.
##   - Đang bày bán thì NGỒI tại chỗ, tên quầy hiện trên đầu (người khác bấm vào xem hàng); đứng dậy / di chuyển là dọn quầy.
##   - Chỉ món đã đặt giá, KHÔNG khoá, nằm trong hành trang mới hiện trên quầy.
##   - Người mua (c2s_playertradebuy) phải: không bị khoá bảo vệ, không ở chế độ chiến đấu, quầy còn mở, món còn đó, đủ tiền, đủ chỗ.
##     Mua xong: món chuyển sang người mua, tiền chuyển sang người bán (không thuế).
## Hai trạng thái "mở giao dịch" và "bày bán" loại trừ nhau (gốc: PLAYER_MENU_STATE_TRADEOPEN vs quầy yêu cầu trạng thái NORMAL).

const MAX_PRICE := 2_000_000_000

# ------------------------------------------------------------------ người bán
## Đặt giá (0 = bỏ khỏi quầy). "" nếu thành công.
static func set_price(p: PlayerProfile, item: ItemInstance, price: int) -> String:
	if not p.inventory.has(item):
		return "Món đồ không có trong hành trang."
	if price < 0 or price > MAX_PRICE:
		return "Giá không hợp lệ."
	if price > 0 and SecurityLock.is_item_locked(item):
		return "Món đồ đang bị khoá, không đặt giá được."
	item.trade_price = price
	return ""

static func priced_items(p: PlayerProfile) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for it in p.inventory:
		if it.trade_price > 0 and not SecurityLock.is_item_locked(it):
			out.append(it)
	return out

static func open_stall(p: PlayerProfile, title: String, riding := false) -> String:
	var blocked := SecurityLock.check(p, SecurityLock.A_OPEN_STALL)
	if blocked != "":
		return blocked
	if riding:
		return "Đang cưỡi ngựa, không bày bán được — hãy xuống ngựa trước."
	if priced_items(p).is_empty():
		return "Hãy đặt giá cho ít nhất một món đồ trước khi bày bán."
	p.trade_open = false
	p.stall_open = true
	p.stall_title = title.strip_edges().left(40)
	if p.stall_title == "":
		p.stall_title = "Quầy của %s" % p.display_name   ## biển trên đầu luôn có chữ để người khác bấm vào
	return ""

static func close_stall(p: PlayerProfile) -> void:
	p.stall_open = false

static func open_trade(p: PlayerProfile) -> String:
	var blocked := SecurityLock.check(p, SecurityLock.A_OPEN_STALL)
	if blocked != "":
		return blocked
	if p.stall_open:
		return "Đang bày bán — hãy dọn quầy trước."
	p.trade_open = true
	return ""

static func close_trade(p: PlayerProfile) -> void:
	p.trade_open = false

# ------------------------------------------------------------------ người mua
## Hàng trên quầy của người chơi giả (món đã đặt giá, không khoá).
static func browse(seller: MockPlayer) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if not seller.stall_open:
		return out
	for it in seller.bag.inventory:
		if it.trade_price > 0 and not SecurityLock.is_item_locked(it):
			out.append(it)
	return out

## Mua món `item` từ quầy `seller` (người bán là người chơi giả hoặc thật). `buyer_fighting` = đang chiến đấu (gốc cấm mua).
## "" nếu thành công.
static func buy(buyer: TradeParty, seller: TradeParty, item: ItemInstance, buyer_fighting := false, seller_stall_open := true) -> String:
	if buyer.profile:
		var blocked := SecurityLock.check(buyer.profile, SecurityLock.A_STALL_BUY)
		if blocked != "":
			return blocked
	if buyer_fighting:
		return "Đang ở chế độ chiến đấu, không mua được."
	# Cho phép mua khi người bán offline / ủy thác bày bán
	if not seller.owns(item) or item.trade_price <= 0 or SecurityLock.is_item_locked(item):
		return "Món đồ đã được bán hoặc không còn trên quầy."
	var price := item.trade_price
	if buyer.gold() < price:
		return "Không đủ tiền."
	if not buyer.can_receive([item]):
		return "Hành trang đã đầy."
	seller.detach(item)
	item.trade_price = 0
	buyer.receive(item)
	buyer.add_gold(-price)
	seller.add_gold(price)
	return ""

## Người chơi giả mua từ QUẦY CỦA NGƯỜI CHƠI THẬT (khi chơi một mình để quầy có khách). Mỗi lần gọi (ví dụ mỗi vài giây) có xác suất
## bán được 1 món; món rẻ hơn giá gợi ý bán chạy hơn. Trả về các giao dịch đã xảy ra [{buyer, item_name, price}].
static func simulate_customers(p: PlayerProfile, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var sales: Array[Dictionary] = []
	if not p.stall_open:
		return sales
	var goods := priced_items(p)
	if goods.is_empty():
		p.stall_open = false
		return sales
	var customers := SocialDirectory.players(p)
	var pick: MockPlayer = customers[rng.randi() % customers.size()]
	var item: ItemInstance = goods[rng.randi() % goods.size()]
	var fair := float(MockPlayer.suggested_price(item))
	var ratio := float(item.trade_price) / maxf(1.0, fair)       ## 1 = đúng giá gợi ý
	var chance := clampf(1.3 - ratio * 0.6, 0.02, 0.9)           ## rẻ → dễ bán, đắt gấp 2 lần → gần như không bán
	if rng.randf() > chance or pick.gold < item.trade_price:
		return sales
	var name_of := item.get_display_name()
	var price := item.trade_price
	if buy(TradeParty.of_mock(pick), TradeParty.of_profile(p), item) == "":
		sales.append({"buyer": pick.name, "item_name": name_of, "price": price})
	if priced_items(p).is_empty():
		p.stall_open = false        ## hết hàng thì tự dọn quầy
	return sales

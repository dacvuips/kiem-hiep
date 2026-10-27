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

static func open_stall(_p: PlayerProfile, _title: String, _riding := false) -> String:
	return "Tính năng Bày Bán tại chỗ đã đóng — vui lòng sử dụng Chợ Giao Thương để treo bán vật phẩm."

static func close_stall(p: PlayerProfile) -> void:
	p.stall_open = false

static func open_trade(p: PlayerProfile) -> String:
	var blocked := SecurityLock.check(p, SecurityLock.A_OPEN_STALL)
	if blocked != "":
		return blocked
	p.trade_open = true
	return ""

static func close_trade(p: PlayerProfile) -> void:
	p.trade_open = false

# ------------------------------------------------------------------ người mua
## Hàng trên quầy: tính năng đã chuyển sang Chợ Giao Thương
static func browse(_seller: MockPlayer) -> Array[ItemInstance]:
	return []

static func buy(_buyer: TradeParty, _seller: TradeParty, _item: ItemInstance, _buyer_fighting := false, _seller_stall_open := true) -> String:
	return "Tính năng Bày Bán tại chỗ đã đóng — vui lòng sử dụng Chợ Giao Thương để mua bán vật phẩm."

## Cấm tuyệt đối bot mua đồ — chỉ người chơi thật mới có quyền mua đồ qua Chợ.
static func simulate_customers(_p: PlayerProfile, _rng: RandomNumberGenerator) -> Array[Dictionary]:
	return []

extends RefCounted
class_name TradeSession
## GIAO DỊCH TRỰC TIẾP 2 NGƯỜI — theo KPlayer::TradeApplyStart/TradeMoveMoney/TradeDecision của VLTK gốc:
##   1. Mỗi bên bỏ đồ vào PHÒNG GIAO DỊCH 10 x 4 và nhập tiền muốn đưa (chỉ khi bên đó CHƯA khoá).
##   2. "Khoá" (decision 2): bên đó không sửa được nữa. Cả 2 khoá rồi mới được bấm "Đồng ý" (decision 1).
##   3. Bên bấm Đồng ý SAU phải chờ >= OK_DELAY_MS (defPLAYER_TRADE_STATE = 5000 ms) kể từ lúc bên kia bấm — tránh bấm vội khi bên kia
##      vừa đổi đồ. Cả 2 đồng ý thì kiểm tra: tiền không âm cho cả 2, mỗi bên còn chỗ nhận đồ, rồi đổi tiền + đồ.
##   4. "Huỷ" (decision 0) ở bất kỳ lúc nào: đồ trả về chủ cũ, tiền không đổi.
## Đồ nằm trong phòng giao dịch bị GỠ khỏi túi chủ (như RecoverTrade gốc) nên không thể vứt/bán/đem đi chỗ khác trong lúc giao dịch.

signal changed
signal finished(success: bool, message: String)

const OK_DELAY_MS := 5000
const ROOM_WIDTH := 10
const ROOM_HEIGHT := 4

class TradeSide:
	var party: TradeParty
	var room := ItemContainer.new(ROOM_WIDTH, ROOM_HEIGHT, 1)
	var money: int = 0
	var locked: bool = false
	var ok: bool = false
	var ok_at_ms: int = 0

var sides: Array[TradeSide] = []     ## [0] = người chơi thật, [1] = đối phương
var active := true
var mock_ai: MockTradeAI = null
var now_ms := 0                 ## đồng hồ giả lập (UI cập nhật mỗi frame bằng tick); test gán trực tiếp

## Xin giao dịch: trả về TradeSession hoặc null + lời báo lỗi trong `error`.
static func request(local: PlayerProfile, partner: MockPlayer, out_error: Array = []) -> TradeSession:
	var err := SecurityLock.check(local, SecurityLock.A_TRADE_START)
	if err == "":
		if partner == null or not partner.trade_open:
			err = "Đối phương không mở giao dịch."
		elif partner.stall_open and not partner.trade_open:
			err = "Đối phương đang bày bán."
		elif RandomNumberGenerator.new().randf() > partner.invite_accept_rate:
			err = "%s từ chối giao dịch." % partner.name
	if err != "":
		out_error.append(err)
		return null
	var s := TradeSession.new()
	s._setup(TradeParty.of_profile(local), TradeParty.of_mock(partner))
	s.mock_ai = MockTradeAI.new(s, partner)
	return s

func _setup(a: TradeParty, b: TradeParty) -> void:
	for party in [a, b]:
		var side := TradeSide.new()
		side.party = party
		sides.append(side)

func local() -> TradeSide:
	return sides[0]

func partner() -> TradeSide:
	return sides[1]

func other(side: TradeSide) -> TradeSide:
	return sides[1] if side == sides[0] else sides[0]

# ------------------------------------------------------------------ thao tác của một bên
func _reject(msg: String) -> String:
	return msg

## Bỏ món vào phòng giao dịch. "" nếu thành công.
func offer_item(side: TradeSide, item: ItemInstance) -> String:
	if not active:
		return "Giao dịch đã kết thúc."
	if side.locked:
		return "Bạn đã khoá giao dịch, không sửa được nữa."
	if not side.party.owns(item):
		return "Món đồ không có trong hành trang."
	if SecurityLock.is_item_locked(item) or item.lock_state == ItemInstance.LOCK_CHARACTER:
		return "Món đồ đang bị khoá, không giao dịch được."
	var spot := side.room.find_free_spot_any(item.get_size())
	if spot.z < 0:
		return "Phòng giao dịch đã đầy."
	side.party.detach(item)
	side.room.place_item(item, spot.x, spot.y, spot.z)
	_after_change(side)
	return ""

## Lấy món từ phòng giao dịch về túi.
func take_back(side: TradeSide, item: ItemInstance) -> String:
	if not active:
		return "Giao dịch đã kết thúc."
	if side.locked:
		return "Bạn đã khoá giao dịch, không sửa được nữa."
	if not side.room.owns(item):
		return "Món đồ không có trong phòng giao dịch."
	if not side.party.receive(item):
		return "Hành trang đã đầy."
	side.room.remove_item(item)
	_after_change(side)
	return ""

## Đặt số tiền muốn đưa (0..tiền đang có) — KPlayer::TradeMoveMoney gốc: số không hợp lệ thì về 0.
func set_money(side: TradeSide, amount: int) -> String:
	if not active:
		return "Giao dịch đã kết thúc."
	if side.locked:
		return "Bạn đã khoá giao dịch, không sửa được nữa."
	side.money = amount if amount >= 0 and amount <= side.party.gold() else 0
	_after_change(side)
	return "" if side.money == amount else "Số tiền không hợp lệ."

func lock(side: TradeSide) -> String:
	if not active:
		return "Giao dịch đã kết thúc."
	side.locked = true
	_after_change(side, false)
	if mock_ai and side == local():
		mock_ai.on_local_locked()
	return ""

## Bấm "Đồng ý". Trả về "" nếu được ghi nhận (có thể chưa hoàn tất), hoặc lời báo lỗi.
func confirm(side: TradeSide) -> String:
	if not active:
		return "Giao dịch đã kết thúc."
	var o := other(side)
	if not (side.locked and o.locked):
		return "Cả hai bên phải khoá giao dịch trước."
	if not o.ok:
		side.ok = true
		side.ok_at_ms = now_ms
		changed.emit()
		if mock_ai and side == local():
			mock_ai.on_local_confirmed()
		return ""
	if now_ms - o.ok_at_ms < OK_DELAY_MS:
		return "Vui lòng đợi %d giây rồi bấm Đồng ý." % int(ceil(float(OK_DELAY_MS - (now_ms - o.ok_at_ms)) / 1000.0))
	side.ok = true
	return _finalize()

func cancel(reason := "Giao dịch đã bị huỷ.") -> void:
	if not active:
		return
	for s in sides:
		for it in s.room.inventory.duplicate():
			s.room.remove_item(it)
			if not s.party.receive(it):
				## Túi đầy khi trả đồ (hiếm): ép vào túi bằng cách thêm hàng mới — mô phỏng bằng thêm vào cuối danh sách.
				s.party.items().append(it)
		s.money = 0
	active = false
	finished.emit(false, reason)

func _after_change(side: TradeSide, reset_locks := true) -> void:
	if reset_locks:
		for s in sides:
			s.ok = false
	changed.emit()
	if mock_ai and side == local() and reset_locks:
		mock_ai.on_local_changed()

func _finalize() -> String:
	var a := local()
	var b := partner()
	## Tiền: mỗi bên sau khi đổi không được âm.
	if a.money < 0 or a.party.gold() + b.money - a.money < 0:
		a.money = 0
		a.ok = false
		b.ok = false
		return "Số tiền của bạn không đủ."
	if b.money < 0 or b.party.gold() + a.money - b.money < 0:
		b.money = 0
		a.ok = false
		b.ok = false
		return "Đối phương không đủ tiền."
	## Chỗ nhận đồ.
	var a_can := a.party.can_receive(b.room.inventory)
	var b_can := b.party.can_receive(a.room.inventory)
	if not a_can or not b_can:
		a.ok = false
		b.ok = false
		changed.emit()
		return "Hành trang của bạn không đủ chỗ." if not a_can else "Hành trang của đối phương không đủ chỗ."
	a.party.add_gold(b.money - a.money)
	b.party.add_gold(a.money - b.money)
	for it in b.room.inventory.duplicate():
		b.room.remove_item(it)
		a.party.receive(it)
	for it in a.room.inventory.duplicate():
		a.room.remove_item(it)
		b.party.receive(it)
	active = false
	finished.emit(true, "Giao dịch thành công!")
	return ""

## Đồng hồ: UI gọi mỗi frame (delta giây). Đẩy now_ms và cho người chơi giả hành động đúng giờ.
func tick(delta: float) -> void:
	if not active:
		return
	now_ms += int(delta * 1000.0)
	if mock_ai:
		mock_ai.tick()

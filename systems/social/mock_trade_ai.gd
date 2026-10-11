extends RefCounted
class_name MockTradeAI
## Bộ não của NGƯỜI CHƠI GIẢ khi giao dịch với người chơi thật: đợi người chơi KHOÁ, định giá phần họ đưa (MockPlayer.suggested_price),
## rồi đưa ra phần đáp lại cho tương xứng (hệ số `haggle` của người đó), tự khoá và tự bấm Đồng ý đúng sau OK_DELAY_MS.
## Không thấy hợp lý thì để nguyên (không khoá) và để lại lời nhắn ở `comment` cho giao diện hiện. Online: bỏ lớp này, đối phương là người thật.

var session: TradeSession
var mock: MockPlayer
var comment := ""
var _confirm_at_ms := -1

func _init(s: TradeSession, m: MockPlayer) -> void:
	session = s
	mock = m

func on_local_changed() -> void:
	## Người chơi sửa đồ → mọi khoá/đồng ý bị gỡ (TradeSession đã reset ok); AI bỏ phần đã đưa để tính lại sau.
	_confirm_at_ms = -1
	var side := session.partner()
	if side.locked or not side.room.inventory.is_empty() or side.money > 0:
		side.locked = false
		for it in side.room.inventory.duplicate():
			side.room.remove_item(it)
			side.party.receive(it)
		side.money = 0
	comment = ""

func on_local_locked() -> void:
	var local := session.local()
	var side := session.partner()
	var value_in := mock.total_value(local.room.inventory, local.money)
	if value_in <= 0:
		comment = "Bạn chưa đưa gì cả."
		session.changed.emit()
		return
	var target := int(value_in * mock.haggle)
	if local.room.inventory.is_empty():
		## Người chơi chỉ đưa tiền → đổi bằng đồ trong túi (tham lam theo giá, không vượt giá trị).
		var picks := _pick_items_up_to(target)
		if picks.is_empty():
			comment = "Tôi không có món nào hợp với số tiền đó."
			session.changed.emit()
			return
		for it in picks:
			session.offer_item(side, it)
	else:
		## Người chơi đưa đồ → trả tiền tương ứng.
		if mock.gold < int(target * 0.5):
			comment = "Tôi không đủ tiền để mua món này."
			session.changed.emit()
			return
		session.set_money(side, mini(target, mock.gold))
	comment = "Được, tôi khoá rồi — bạn xem lại và bấm Đồng ý nhé."
	session.lock(side)

func on_local_confirmed() -> void:
	if session.partner().locked and session.local().locked:
		_confirm_at_ms = session.now_ms + TradeSession.OK_DELAY_MS

func tick() -> void:
	if _confirm_at_ms >= 0 and session.now_ms >= _confirm_at_ms:
		_confirm_at_ms = -1
		var err := session.confirm(session.partner())
		if err != "":
			comment = err

func _pick_items_up_to(budget: int) -> Array[ItemInstance]:
	var cand: Array[ItemInstance] = []
	for it in mock.bag.inventory:
		if not SecurityLock.is_item_locked(it):
			cand.append(it)
	cand.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool: return MockPlayer.suggested_price(a) > MockPlayer.suggested_price(b))
	var out: Array[ItemInstance] = []
	var total := 0
	for it in cand:
		var price := MockPlayer.suggested_price(it)
		if total + price <= budget and out.size() < 8:
			out.append(it)
			total += price
	return out

class_name NetTradeSession
extends TradeSession
## Giao dịch với NGƯỜI CHƠI THẬT (online): cùng giao diện TradeSession nên TradeWindow dùng nguyên — nhưng mọi thao tác chỉ GỬI lên
## game server (SocialServer chạy TradeSession thật trên bản nhân vật của server); trạng thái hiển thị lấy từ S_TRADE_STATE.
## Đồ mình bỏ vào phòng được ẩn khỏi túi trên máy cho giống bản gốc; xong / huỷ giao dịch server gửi bản nhân vật chuẩn (S_PROFILE).

var partner_eid := 0
var _profile: PlayerProfile
var _hidden: Dictionary = {}       ## uid -> ItemInstance đang ẩn khỏi túi (đã bỏ vào phòng)

func _init(profile: PlayerProfile, partner_id: int, partner_name: String) -> void:
	_profile = profile
	partner_eid = partner_id
	var mock := MockPlayer.new()
	mock.id = partner_id
	mock.name = partner_name
	_setup(TradeParty.of_profile(profile), TradeParty.of_mock(mock))

## Trạng thái từ server: [mine, theirs] = {money, locked, ok, ok_age_ms, items: Array[Dictionary]}.
func apply_state(mine: Dictionary, theirs: Dictionary) -> void:
	now_ms = Time.get_ticks_msec()
	_fill(sides[0], mine)
	_fill(sides[1], theirs)
	## Ẩn khỏi túi đồ mình đang để trong phòng (server vẫn giữ chúng thuộc về mình tới khi giao dịch xong).
	var in_room := {}
	for it in sides[0].room.inventory:
		in_room[it.uid] = true
	for uid in _hidden.keys():
		if not in_room.has(uid):
			_profile.inventory.append(_hidden[uid])
			_hidden.erase(uid)
	for i in range(_profile.inventory.size() - 1, -1, -1):
		var it: ItemInstance = _profile.inventory[i]
		if in_room.has(it.uid):
			_hidden[it.uid] = it
			_profile.inventory.remove_at(i)
	changed.emit()

func _fill(side: TradeSide, d: Dictionary) -> void:
	side.money = int(d.money)
	side.locked = bool(d.locked)
	side.ok = bool(d.ok)
	side.ok_at_ms = now_ms - int(d.ok_age_ms)
	side.room.inventory.clear()   ## giữ nguyên đối tượng phòng (TradeWindow đang tham chiếu)
	for item_dict in d.items:
		var it := ItemInstance.from_dict(item_dict)
		var spot := side.room.find_free_spot_any(it.get_size())
		if spot.z >= 0:
			side.room.place_item(it, spot.x, spot.y, spot.z)

func end(success: bool, message: String) -> void:
	if not active:
		return
	active = false
	## Server gửi bản chuẩn (S_PROFILE) TRƯỚC gói kết thúc: đồ đã về đúng chủ. Chỉ trả lại món chưa có ở đâu cả (mất bản chuẩn) —
	## trả bừa sẽ thành đồ "ma" (đã đưa đi vẫn còn) hoặc nhân đôi uid (huỷ: mặc 1 bản, bản kia vẫn nằm trong túi).
	var have := {}
	for it in _profile.inventory:
		have[it.uid] = true
	for it in _profile.equipment.values():
		have[(it as ItemInstance).uid] = true
	for uid in _hidden:
		if not have.has(uid):
			_profile.inventory.append(_hidden[uid])
	_hidden.clear()
	finished.emit(success, message)

# ---------------------------------------------------------------- thao tác -> server (lỗi trả về qua S_NOTICE)

func offer_item(side: TradeSide, item: ItemInstance) -> String:
	if not active or side != local():
		return "Giao dịch đã kết thúc."
	if side.locked:
		return "Bạn đã khoá giao dịch, không sửa được nữa."
	NetClient.send_trade_op(SocialServer.OP_OFFER, item.uid)
	return ""

func take_back(side: TradeSide, item: ItemInstance) -> String:
	if not active or side != local():
		return "Giao dịch đã kết thúc."
	if side.locked:
		return "Bạn đã khoá giao dịch, không sửa được nữa."
	NetClient.send_trade_op(SocialServer.OP_TAKE, item.uid)
	return ""

func set_money(side: TradeSide, amount: int) -> String:
	if not active or side != local():
		return "Giao dịch đã kết thúc."
	if amount < 0 or amount > _profile.gold:
		return "Số tiền không hợp lệ."
	NetClient.send_trade_op(SocialServer.OP_MONEY, "", amount)
	return ""

func lock(side: TradeSide) -> String:
	if not active:
		return "Giao dịch đã kết thúc."
	NetClient.send_trade_op(SocialServer.OP_LOCK)
	return ""

func confirm(side: TradeSide) -> String:
	if not active:
		return "Giao dịch đã kết thúc."
	var o := other(side)
	if not (side.locked and o.locked):
		return "Cả hai bên phải khoá giao dịch trước."
	if o.ok and now_ms - o.ok_at_ms < OK_DELAY_MS:
		return "Vui lòng đợi %d giây rồi bấm Đồng ý." % int(ceil(float(OK_DELAY_MS - (now_ms - o.ok_at_ms)) / 1000.0))
	NetClient.send_trade_op(SocialServer.OP_CONFIRM)
	return ""

func cancel(_reason := "Giao dịch đã bị huỷ.") -> void:
	if active:
		NetClient.send_trade_op(SocialServer.OP_CANCEL)

func tick(_delta: float) -> void:
	now_ms = Time.get_ticks_msec()

class_name SocialServer
extends RefCounted
## Xã hội giữa người chơi THẬT trên game server: giao dịch trực tiếp + bày bán.
## Chạy đúng luật gốc bằng chính TradeSession / StallService của game, nhưng trên BẢN NHÂN VẬT CỦA SERVER (Conn.profile) —
## đồ và tiền chỉ đổi chủ ở server, xong thì gửi bản chuẩn (S_PROFILE) cho cả 2 bên. Game chỉ gửi thao tác.

const TRADE_RANGE := 600.0         ## px — đứng xa hơn không xin giao dịch được
const INVITE_SECONDS := 20.0

## Lệnh trong C_TRADE_OP
const OP_OFFER := 1
const OP_TAKE := 2
const OP_MONEY := 3
const OP_LOCK := 4
const OP_CONFIRM := 5
const OP_CANCEL := 6
## Lệnh trong C_STALL
const STALL_OPEN := 1
const STALL_CLOSE := 2
const STALL_BROWSE := 3
const STALL_BUY := 4
const TRADE_OPEN := 5
const TRADE_CLOSE := 6

class Trade:
	var session: TradeSession
	var conns: Array = []          ## [GameServer.Conn, GameServer.Conn] cùng thứ tự session.sides

var gs: GameServer
var _invites: Dictionary = {}      ## "from_eid:to_eid" -> hết hạn (giây server)

func _init(server: GameServer) -> void:
	gs = server

func tick(dt: float, now: float) -> void:
	for k in _invites.keys():
		if now > float(_invites[k]):
			_invites.erase(k)
	var seen := {}
	for c in gs.in_world_conns():
		if c.trade and not seen.has(c.trade):
			seen[c.trade] = true
			(c.trade as Trade).session.tick(dt)

# ---------------------------------------------------------------- giao dịch

func on_trade_request(c, target_eid: int) -> void:
	var t = gs.conn_of_eid(target_eid)
	if t == null or t == c:
		gs.notice(c, "Người chơi không còn ở gần.")
		return
	if c.entity.pos.distance_to(t.entity.pos) > TRADE_RANGE:
		gs.notice(c, "Đứng gần hơn mới giao dịch được.")
		return
	var err := SecurityLock.check(c.profile, SecurityLock.A_TRADE_START)
	if err == "":
		if c.trade or t.trade:
			err = "Bạn hoặc đối phương đang trong một giao dịch."
		elif not t.trade_open:
			err = "Đối phương không mở giao dịch."
		elif t.stall_open:
			err = "Đối phương đang bày bán."
	if err != "":
		gs.notice(c, err)
		return
	_invites["%d:%d" % [c.entity.eid, t.entity.eid]] = gs.now() + INVITE_SECONDS
	var b := NetProto.writer(NetProto.S_TRADE_INVITE)
	b.put_u32(c.entity.eid)
	NetProto.put_str(b, c.entity.name)
	gs.send(t, b)
	gs.notice(c, "Đã gửi lời mời giao dịch tới %s." % t.entity.name)

func on_trade_answer(c, from_eid: int, accept: bool) -> void:
	var key := "%d:%d" % [from_eid, c.entity.eid]
	if not _invites.has(key):
		return
	_invites.erase(key)
	var f = gs.conn_of_eid(from_eid)
	if f == null:
		return
	if not accept:
		gs.notice(f, "%s từ chối giao dịch." % c.entity.name)
		return
	if f.trade or c.trade:
		gs.notice(c, "Đối phương đang bận giao dịch khác.")
		return
	var t := Trade.new()
	t.session = TradeSession.new()
	t.session._setup(TradeParty.of_profile(f.profile), TradeParty.of_profile(c.profile))
	t.conns = [f, c]
	t.session.changed.connect(func() -> void: _send_state(t))
	t.session.finished.connect(func(ok: bool, msg: String) -> void: _end(t, ok, msg))
	f.trade = t
	c.trade = t
	_send_state(t)

func on_trade_op(c, b: StreamPeerBuffer) -> void:
	var t: Trade = c.trade
	if t == null or not t.session.active:
		return
	var side: TradeSession.TradeSide = t.session.sides[t.conns.find(c)]
	var op := b.get_u8()
	var err := ""
	match op:
		OP_OFFER:
			var it := _find(c.profile.inventory, NetProto.get_str(b, 64))
			err = t.session.offer_item(side, it) if it else "Món đồ không có trong hành trang."
		OP_TAKE:
			var it := _find(side.room.inventory, NetProto.get_str(b, 64))
			err = t.session.take_back(side, it) if it else "Món đồ không có trong phòng giao dịch."
		OP_MONEY:
			err = t.session.set_money(side, b.get_u32())
		OP_LOCK:
			err = t.session.lock(side)
		OP_CONFIRM:
			err = t.session.confirm(side)
		OP_CANCEL:
			t.session.cancel("%s đã huỷ giao dịch." % c.entity.name)
			return
	if err != "":
		gs.notice(c, err)
		_send_state(t)

## Người chơi rời game giữa giao dịch: huỷ (đồ về chủ cũ trên bản server).
func on_leave(c) -> void:
	if c.trade:
		(c.trade as Trade).session.cancel("%s đã rời đi, giao dịch bị huỷ." % c.entity.name)

static func _find(list: Array, uid: String) -> ItemInstance:
	for it in list:
		if (it as ItemInstance).uid == uid:
			return it
	return null

## Trạng thái giao dịch cho từng bên (bên mình trước): tiền, khoá, đồng ý, đồ trong phòng.
func _send_state(t: Trade) -> void:
	for i in 2:
		var c = t.conns[i]
		var other = t.conns[1 - i]
		var b := NetProto.writer(NetProto.S_TRADE_STATE)
		b.put_u32(other.entity.eid)
		NetProto.put_str(b, other.entity.name)
		for side in [t.session.sides[i], t.session.sides[1 - i]]:
			b.put_u32(side.money)
			b.put_u8(1 if side.locked else 0)
			b.put_u8(1 if side.ok else 0)
			b.put_u32(maxi(0, t.session.now_ms - side.ok_at_ms) if side.ok else 0)
			b.put_u16(side.room.inventory.size())
			for it in side.room.inventory:
				NetProto.put_str(b, JSON.stringify((it as ItemInstance).to_dict()))
		gs.send(c, b)

func _end(t: Trade, ok: bool, msg: String) -> void:
	for c in t.conns:
		c.trade = null
		gs.profile_changed(c)
		var b := NetProto.writer(NetProto.S_TRADE_END)
		b.put_u8(1 if ok else 0)
		NetProto.put_str(b, msg)
		gs.send(c, b)

# ---------------------------------------------------------------- bày bán / mở giao dịch

func on_stall(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	match op:
		STALL_OPEN:
			var title := NetProto.get_str(b, 200)
			var riding: bool = (c.entity.flags & NetProto.FLAG_RIDING) != 0
			var err := StallService.open_stall(c.profile, title, riding)
			if err != "":
				gs.notice(c, err)
			else:
				c.stall_open = true
				c.trade_open = false
				c.stall_title = c.profile.stall_title
			_flags(c)
		STALL_CLOSE:
			c.stall_open = false
			_flags(c)
		TRADE_OPEN:
			var err := StallService.open_trade(c.profile) if not c.stall_open else "Đang bày bán — hãy dọn quầy trước."
			if err != "":
				gs.notice(c, err)
			else:
				c.trade_open = true
			_flags(c)
		TRADE_CLOSE:
			c.trade_open = false
			_flags(c)
		STALL_BROWSE:
			_browse(c, b.get_u32())
		STALL_BUY:
			var seller_eid := b.get_u32()
			_buy(c, seller_eid, NetProto.get_str(b, 64))

func _flags(c) -> void:
	var f: int = c.entity.flags & ~(NetProto.FLAG_STALL | NetProto.FLAG_TRADE_OPEN)
	if c.stall_open:
		f |= NetProto.FLAG_STALL
	if c.trade_open:
		f |= NetProto.FLAG_TRADE_OPEN
	if f != c.entity.flags:
		c.entity.flags = f
		c.entity.touch()

func _browse(c, seller_eid: int) -> void:
	var s = gs.conn_of_eid(seller_eid)
	var b := NetProto.writer(NetProto.S_STALL_ITEMS)
	b.put_u32(seller_eid)
	if s == null or not s.stall_open or c.entity.pos.distance_to(s.entity.pos) > TRADE_RANGE:
		NetProto.put_str(b, "")
		b.put_u16(0)
		gs.send(c, b)
		return
	var goods: Array[ItemInstance] = StallService.priced_items(s.profile)
	NetProto.put_str(b, s.stall_title)
	b.put_u16(goods.size())
	for it in goods:
		NetProto.put_str(b, JSON.stringify(it.to_dict()))
	gs.send(c, b)

func _buy(c, seller_eid: int, uid: String) -> void:
	var s = gs.conn_of_eid(seller_eid)
	if s == null or s == c:
		gs.notice(c, "Quầy đã đóng.")
		return
	if c.trade or s.trade:
		gs.notice(c, "Đang giao dịch, không mua được.")
		return
	if c.entity.pos.distance_to(s.entity.pos) > TRADE_RANGE:
		gs.notice(c, "Đứng gần quầy hơn mới mua được.")
		return
	var item := _find(s.profile.inventory, uid)
	if item == null:
		gs.notice(c, "Món đồ đã được bán hoặc không còn trên quầy.")
		_browse(c, seller_eid)
		return
	var name_of := item.get_display_name()
	var price := item.trade_price
	var err := StallService.buy(TradeParty.of_profile(c.profile), TradeParty.of_profile(s.profile), item, false, s.stall_open)
	if err != "":
		gs.notice(c, err)
		return
	gs.profile_changed(c)
	gs.profile_changed(s)
	gs.notice(c, "Đã mua %s giá %d lượng." % [name_of, price])
	gs.notice(s, "%s đã mua %s của bạn: +%d lượng." % [c.entity.name, name_of, price])
	if StallService.priced_items(s.profile).is_empty():
		s.stall_open = false   ## hết hàng thì tự dọn quầy
		_flags(s)
		gs.notice(s, "Quầy đã hết hàng.")
	_browse(c, seller_eid)

class_name MarketServer
extends RefCounted
## CHỢ GIAO THƯƠNG trên game server: 1 sổ MarketBook chung cho cả máy chủ, giữ trong RAM, lưu từng món treo vào PostgreSQL qua API nội bộ
## (/internal/game/market). Mọi thao tác chạy trên BẢN NHÂN VẬT CỦA SERVER (Conn.profile) — đồ / tiền chỉ đổi chủ ở đây, xong gửi bản chuẩn
## (S_PROFILE) và lưu nhân vật ngay để sổ chợ và hồ sơ không lệch nhau lâu.
## Người bán đang online: tiền về ngay. Không online: món nằm trong sổ ở trạng thái "sold", nhận khi vào game / mở tab "Của Tôi".

const FLUSH_SECONDS := 1.0
const MIN_OP_GAP := 0.15          ## giây giữa 2 thao tác chợ của 1 người (chống gửi dồn)

var gs: GameServer
var book := MarketBook.new()
var _loaded := false
var _dirty: Dictionary = {}       ## id listing cần lưu (còn trong sổ) / xoá (đã ra khỏi sổ)
var _flushing := false
var _flush_clock := 0.0
var _last_op: Dictionary = {}     ## character_id -> giây server

func _init(server: GameServer) -> void:
	gs = server

func load_all() -> void:
	var r: Dictionary = await gs.account.list_market()
	if not r.ok:
		push_warning("Không nạp được chợ: %s" % r.get("message", ""))
		return
	for row in r.get("listings", []):
		if row.get("data") is Dictionary and (row.data as Dictionary).has("id"):
			book.put(row.data)
	_loaded = true
	print("Chợ giao thương: %d món" % book.listings.size())

func tick(dt: float) -> void:
	_flush_clock += dt
	if _flush_clock >= FLUSH_SECONDS:
		_flush_clock = 0.0
		_flush()

## Vào map: nhận tiền các món đã bán lúc vắng mặt.
func on_join(c) -> void:
	if _loaded:
		_settle(c)

func on_market(c, b: StreamPeerBuffer) -> void:
	var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 4096))
	var a: Dictionary = parsed if parsed is Dictionary else {}
	if not _loaded:
		_done(c, "Chợ đang khởi động, hãy thử lại sau.")
		return
	var now_s := gs.now()
	if now_s - float(_last_op.get(c.character_id, -10.0)) < MIN_OP_GAP:
		return
	_last_op[c.character_id] = now_s
	var t := int(Time.get_unix_time_from_system())
	var sid: int = c.character_id
	match str(a.get("op", "")):
		"list":
			var f: Variant = a.get("filter", {})
			var res := book.query(f if f is Dictionary else {}, t, int(a.get("page", 0)))
			res["op"] = "list"
			res["now"] = t
			_reply(c, res)
		"mine":
			_settle(c)
			_send_mine(c, t)
		"sell":
			if c.trade:
				_done(c, "Đang giao dịch, không treo bán được.")
				return
			var r := book.sell(c.profile, sid, str(a.get("uid", "")), int(a.get("price", 0)), int(a.get("cur", 0)), t, str(a.get("note", "")))
			if r[0] != "":
				_done(c, r[0])
				return
			_dirty[str(r[1]["id"])] = true
			_changed(c)
			_done(c, "", "Đã treo bán — xem ở tab Của Tôi.")
		"buy":
			if c.trade:
				_done(c, "Đang giao dịch, không mua được.")
				return
			var r := book.buy(c.profile, sid, str(a.get("id", "")), t)
			if r[0] != "":
				_done(c, r[0])
				return
			var l: Dictionary = r[1]
			_dirty[str(l["id"])] = true
			_changed(c)
			_done(c, "", "Mua %s thành công!" % str(l.get("name", "")))
			var seller = gs.conn_of_character(int(l["sid"]))
			if seller:
				_settle(seller)
		"cancel":
			var id := str(a.get("id", ""))
			var err := book.cancel(c.profile, sid, id)
			if err != "":
				_done(c, err)
				return
			_dirty[id] = true
			_changed(c)
			_done(c, "", "Đã huỷ treo — món đồ đã về hành trang.")
			_send_mine(c, t)

## Trả tiền các món đã bán cho người bán đang online.
func _settle(c) -> void:
	var sold := book.of_seller(c.character_id).filter(func(l: Dictionary) -> bool: return str(l["state"]) == MarketBook.STATE_SOLD)
	if sold.is_empty():
		return
	for l in sold:
		gs.notice(c, MarketBook.sold_line(l))
		_dirty[str(l["id"])] = true
	book.claim_sold(c.profile, c.character_id)
	_changed(c)

func _changed(c) -> void:
	gs.profile_changed(c)
	gs.save_now(c)

func _send_mine(c, t: int) -> void:
	_reply(c, {"op": "mine", "items": book.of_seller(c.character_id), "now": t, "slots": MarketBook.MAX_SLOTS})

func _done(c, err: String, ok_text := "") -> void:
	_reply(c, {"op": "done", "ok": err == "", "msg": err if err != "" else ok_text})

func _reply(c, d: Dictionary) -> void:
	var b := NetProto.writer(NetProto.S_MARKET)
	NetProto.put_json(b, d)
	gs.send(c, b)

## Lưu / xoá các món đã đổi. Lỗi thì giữ lại để lần sau lưu tiếp (không mất món treo khi server tài khoản chập chờn).
func _flush() -> void:
	if _flushing or _dirty.is_empty():
		return
	_flushing = true
	var ids := _dirty.keys()
	_dirty.clear()
	for id in ids:
		var r: Dictionary
		if book.listings.has(id):
			r = await gs.account.save_market(id, book.listings[id])
		else:
			r = await gs.account.delete_market(id)
		if not r.ok:
			_dirty[id] = true
			push_warning("Lưu chợ %s lỗi: %s" % [id, r.get("message", "")])
	_flushing = false

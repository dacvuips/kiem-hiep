extends Node
## Kiểm thử OẲN TÙ XÌ: luật thắng thua (RpsServer.judge), RpsServer với GameServer GIẢ (mời / từ chối / đồng ý, chọn + xác nhận,
## giấu lựa chọn đối thủ, đếm ngược 3 giây, tỉ số, chơi tiếp, rời / thoát), và RpsWindow vẽ theo trạng thái.
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/rps_tests.tscn

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

class FakeConn:
	var entity: ServerEntity
	var msgs: Array = []
	var notices: Array = []

	func last(op: String) -> Dictionary:
		for i in range(msgs.size() - 1, -1, -1):
			if str(msgs[i].get("op")) == op:
				return msgs[i]
		return {}

class FakeGs:
	var t := 0.0
	var by_eid := {}

	func now() -> float:
		return t

	func conn_of_eid(eid: int):
		return by_eid.get(eid)

	func notice(c, text: String) -> void:
		c.notices.append(text)

	func send(c, b: StreamPeerBuffer) -> void:
		var r := NetProto.reader(b.data_array)
		if r.get_u8() == NetProto.S_RPS:
			var d: Variant = JSON.parse_string(NetProto.get_str(r, 1 << 14))
			if d is Dictionary:
				c.msgs.append(d)

func _conn(gs: FakeGs, eid: int, name: String, pos: Vector2) -> FakeConn:
	var c := FakeConn.new()
	c.entity = ServerEntity.new()
	c.entity.eid = eid
	c.entity.name = name
	c.entity.pos = pos
	gs.by_eid[eid] = c
	return c

func _ready() -> void:
	_test_judge()
	_test_server()
	await _test_window()
	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _test_judge() -> void:
	var R := RpsServer.ROCK
	var S := RpsServer.SCISSORS
	var P := RpsServer.PAPER
	check("Búa thắng Kéo", RpsServer.judge(R, S) == 1 and RpsServer.judge(S, R) == -1)
	check("Kéo thắng Bao", RpsServer.judge(S, P) == 1 and RpsServer.judge(P, S) == -1)
	check("Bao thắng Búa", RpsServer.judge(P, R) == 1 and RpsServer.judge(R, P) == -1)
	check("Cùng ra = hoà", RpsServer.judge(R, R) == 0 and RpsServer.judge(S, S) == 0 and RpsServer.judge(P, P) == 0)

func _test_server() -> void:
	var gs := FakeGs.new()
	var rps := RpsServer.new(gs)
	var a := _conn(gs, 1, "An", Vector2(100, 100))
	var b := _conn(gs, 2, "Bình", Vector2(200, 100))
	var far := _conn(gs, 3, "Xa", Vector2(9000, 9000))

	rps.on_rps(a, {"op": "invite", "eid": 3})
	check("mời người ở xa: bị chặn", far.msgs.is_empty() and a.notices.size() == 1)
	rps.on_rps(a, {"op": "invite", "eid": 1})
	check("mời chính mình: không gửi", a.msgs.is_empty())

	rps.on_rps(a, {"op": "invite", "eid": 2})
	var inv := b.last("invite")
	check("B nhận lời mời có tên A", int(inv.get("from", 0)) == 1 and str(inv.get("name")) == "An", inv)
	rps.on_rps(b, {"op": "answer", "eid": 1, "accept": false})
	check("B từ chối: A được báo, không có trận", rps.match_of(a) == null and str(a.notices.back()).contains("từ chối"))
	rps.on_rps(b, {"op": "answer", "eid": 1, "accept": true})
	check("trả lời lời mời đã dùng: bỏ qua", rps.match_of(a) == null)

	rps.on_rps(a, {"op": "invite", "eid": 2})
	rps.on_rps(b, {"op": "answer", "eid": 1, "accept": true})
	var st := a.last("state")
	check("đồng ý: cả 2 nhận trạng thái ván 1 chọn", st.get("phase") == "pick" and int(st.get("round")) == 1 and b.last("state").get("phase") == "pick", st)
	check("tên 2 bên đúng phía", st.me.name == "An" and st.opp.name == "Bình" and b.last("state").me.name == "Bình")
	rps.on_rps(far, {"op": "invite", "eid": 1})
	check("đang chơi thì người khác không mời được", far.notices.size() > 0)

	rps.on_rps(a, {"op": "pick", "choice": RpsServer.ROCK})
	var sb := b.last("state")
	check("A xác nhận: B thấy A đã chọn nhưng KHÔNG thấy lựa chọn", bool(sb.opp.picked) and int(sb.opp.choice) == -1 and sb.phase == "pick", sb)
	rps.on_rps(a, {"op": "pick", "choice": RpsServer.PAPER})
	check("đã xác nhận thì không đổi được", rps.match_of(a).picks[0] == RpsServer.ROCK)
	rps.on_rps(b, {"op": "pick", "choice": RpsServer.SCISSORS})
	st = a.last("state")
	check("cả 2 xác nhận: đếm ngược 3 giây", st.phase == "countdown" and absf(float(st.countdown) - 3.0) < 0.01 and int(st.opp.choice) == -1, st)
	gs.t = 2.9
	rps.tick(gs.t)
	check("chưa đủ 3 giây: chưa lật", a.last("state").phase == "countdown")
	gs.t = 3.0
	rps.tick(gs.t)
	st = a.last("state")
	sb = b.last("state")
	check("A (Búa) thắng B (Kéo)", st.phase == "result" and st.result == "win" and sb.result == "lose", [st, sb])
	check("tên người thắng / thua", st.winner == "An" and st.loser == "Bình" and sb.winner == "An")
	check("tỉ số 1-0, lộ lựa chọn đối thủ", int(st.me.wins) == 1 and int(st.opp.wins) == 0 and int(st.opp.choice) == RpsServer.SCISSORS and int(sb.opp.wins) == 1)
	check("lịch sử theo phía mỗi người", st.history.size() == 1 and int(st.history[0].r) == 1 and int(sb.history[0].r) == -1 and sb.history[0].winner == "An")

	rps.on_rps(a, {"op": "next"})
	check("1 người bấm Chơi tiếp: chờ người kia", b.last("state").phase == "result" and bool(b.last("state").opp.ready))
	rps.on_rps(b, {"op": "next"})
	st = a.last("state")
	check("đủ 2 người: sang ván 2", st.phase == "pick" and int(st.round) == 2 and not bool(st.me.picked))

	rps.on_rps(a, {"op": "pick", "choice": RpsServer.PAPER})
	rps.on_rps(b, {"op": "pick", "choice": RpsServer.PAPER})
	gs.t += 3.0
	rps.tick(gs.t)
	st = a.last("state")
	check("ván 2 hoà", st.result == "draw" and int(st.draws) == 1 and st.winner == "")
	rps.on_rps(a, {"op": "next"})
	rps.on_rps(b, {"op": "next"})
	rps.on_rps(a, {"op": "pick", "choice": RpsServer.SCISSORS})
	rps.on_rps(b, {"op": "pick", "choice": RpsServer.ROCK})
	gs.t += 3.0
	rps.tick(gs.t)
	sb = b.last("state")
	check("ván 3 B thắng: tỉ số 1-1, hoà 1", sb.result == "win" and int(sb.me.wins) == 1 and int(sb.opp.wins) == 1 and int(sb.draws) == 1, sb)

	rps.on_rps(a, {"op": "pick", "choice": 0})
	check("chọn khi đang xem kết quả: bỏ qua", rps.match_of(a).phase == "result")
	rps.on_rps(a, {"op": "leave"})
	var end := b.last("end")
	check("A rời: B nhận kết thúc + tỉ số chung cuộc", str(end.get("msg", "")).contains("An đã rời") and str(end.msg).contains("1 - 1"), end)
	check("trận đã gỡ cho cả 2", rps.match_of(a) == null and rps.match_of(b) == null)

	## Thoát game giữa trận
	rps.on_rps(a, {"op": "invite", "eid": 2})
	rps.on_rps(b, {"op": "answer", "eid": 1, "accept": true})
	rps.on_leave(b)
	check("B thoát: A được báo, trận gỡ", str(a.last("end").get("msg", "")).contains("Bình") and rps.match_of(a) == null)
	## Lời mời hết hạn
	rps.on_rps(a, {"op": "invite", "eid": 2})
	gs.t += RpsServer.INVITE_SECONDS + 1.0
	rps.tick(gs.t)
	rps.on_rps(b, {"op": "answer", "eid": 1, "accept": true})
	check("lời mời quá 30 giây: hết hiệu lực", rps.match_of(a) == null)

func _state(phase: String, extra := {}) -> Dictionary:
	var st := {"op": "state", "round": 2, "phase": phase, "draws": 1,
		"me": {"eid": 1, "name": "An", "wins": 3, "picked": false, "choice": -1, "ready": false},
		"opp": {"eid": 2, "name": "Bình", "wins": 1, "picked": true, "choice": -1, "ready": false},
		"history": [{"round": 1, "me": 0, "op": 1, "r": 1, "winner": "An"}]}
	st.merge(extra, true)
	return st

func _test_window() -> void:
	RpsWindow.handle(self, _state("pick"))
	await get_tree().process_frame
	var w := RpsWindow.current
	check("cửa sổ mở khi có trạng thái", w != null and is_instance_valid(w))
	if w == null:
		return
	check("icon Búa / Kéo / Bao tải được", RpsWindow._icon(0) != null and RpsWindow._icon(1) != null and RpsWindow._icon(2) != null)
	check("bảng tỉ số: tên + số thắng", w._name_me.text.contains("An") and w._name_opp.text == "Bình" and w._score_me.text == "3" and w._score_opp.text == "1")
	check("ván chọn: 3 icon lớn hiện, Xác nhận khoá khi chưa chọn", w._pick_row.visible and w._pick_btns.size() == 3 and w._confirm.disabled)
	check("báo đối thủ đã xác nhận", w._status.text.contains("Bình đã xác nhận"))
	w._pick_btns[2].pressed.emit()
	check("chọn Bao: nút sáng, Xác nhận mở", w._sel == 2 and w._pick_btns[2].button_pressed and not w._confirm.disabled)
	w.apply(_state("countdown", {"countdown": 2.5, "me": {"name": "An", "wins": 3, "picked": true, "choice": 2}}))
	check("đếm ngược: hiện số 3, đối thủ úp", w._reveal_row.visible and not w._pick_row.visible and w._big.text == "3" and w._reveal_opp.texture == null)
	w.apply(_state("result", {"result": "win", "winner": "An", "loser": "Bình",
		"me": {"name": "An", "wins": 4, "picked": true, "choice": 2, "ready": false},
		"opp": {"name": "Bình", "wins": 1, "picked": true, "choice": 0, "ready": true}}))
	check("kết quả: THẮNG, tên người thắng / thua, nút Chơi tiếp", w._big.text == "THẮNG!" and w._status.text.contains("Người thắng: An")
		and w._status.text.contains("Người thua: Bình") and w._next.visible and not w._next.disabled, w._status.text)
	check("lật lựa chọn đối thủ (Búa)", w._reveal_opp.texture != null and w._reveal_opp_lbl.text.contains("Búa"))
	check("lịch sử ván", w._history.get_child_count() >= 1)
	RpsWindow.handle(self, {"op": "end", "msg": "Bình đã rời đi."})
	await get_tree().process_frame
	check("kết thúc: đóng cửa sổ", RpsWindow.current == null)

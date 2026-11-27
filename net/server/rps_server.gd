class_name RpsServer
extends RefCounted
## OẲN TÙ XÌ (Búa / Kéo / Bao) giữa 2 người chơi online — menu bấm vào người chơi khác › "Oẳn tù xì".
##   1. A mời B (C_RPS {op:"invite", eid}) -> B nhận hộp hỏi (S_RPS {op:"invite", from, name}), trả lời {op:"answer", eid, accept}.
##   2. Đồng ý -> mở ván: mỗi bên chọn Búa / Kéo / Bao rồi XÁC NHẬN ({op:"pick", choice}) — server giữ lựa chọn, không báo cho bên kia.
##   3. Cả 2 xác nhận -> đếm ngược COUNTDOWN giây (phase "countdown") -> server phân thắng / thua / hoà, cộng tỉ số (phase "result").
##   4. Mỗi bên bấm "Chơi tiếp" ({op:"next"}) -> đủ 2 người thì sang ván mới. {op:"leave"} / thoát game = kết thúc, báo bên kia.
## Server là nguồn sự thật (lựa chọn, kết quả, tỉ số) — máy người chơi chỉ vẽ theo S_RPS {op:"state"}.
## Không tiền cược, không lưu hồ sơ: tỉ số chỉ sống trong phiên chơi.

const ROCK := 0       ## Búa
const SCISSORS := 1   ## Kéo
const PAPER := 2      ## Bao
const NAMES := ["Búa", "Kéo", "Bao"]

const INVITE_SECONDS := 30.0
const COUNTDOWN := 3.0
const INVITE_RANGE := 1536.0   ## px — đứng trong tầm nhìn (3x3 ô AOI), như Hảo hữu / Tin tức
const HISTORY := 10            ## số ván gần nhất gửi kèm trạng thái

## 1 = a thắng, -1 = b thắng, 0 = hoà. Búa thắng Kéo, Kéo thắng Bao, Bao thắng Búa.
static func judge(a: int, b: int) -> int:
	if a == b:
		return 0
	return 1 if (a - b + 3) % 3 == 2 else -1

class Match:
	var a          ## Conn người mời
	var b          ## Conn người được mời
	var round := 1
	var phase := "pick"   ## pick | countdown | result
	var picks := [-1, -1]
	var ready := [false, false]   ## đã bấm "Chơi tiếp" sau khi có kết quả
	var wins := [0, 0]
	var draws := 0
	var reveal_at := 0.0
	var last := 0          ## kết quả ván vừa rồi theo phía a (judge)
	var history: Array = []   ## [{round, a, b, r}] — r theo phía a

	func side(c) -> int:
		return 0 if c == a else (1 if c == b else -1)

	func other(c):
		return b if c == a else a

var gs   ## GameServer (kiểu lỏng để bài test dùng server giả)
var _invites: Dictionary = {}   ## "from_eid:to_eid" -> hết hạn (giây server)
var _matches: Dictionary = {}   ## eid -> Match (cả 2 bên cùng trỏ 1 trận)

func _init(server) -> void:
	gs = server

func match_of(c) -> Match:
	return _matches.get(c.entity.eid) if c != null and c.entity != null else null

func tick(now: float) -> void:
	for k in _invites.keys():
		if now > float(_invites[k]):
			_invites.erase(k)
	var seen := {}
	for m: Match in _matches.values():
		if seen.has(m):
			continue
		seen[m] = true
		if m.phase == "countdown" and now >= m.reveal_at:
			_reveal(m)

func on_rps(c, d: Dictionary) -> void:
	match str(d.get("op", "")):
		"invite":
			_invite(c, int(d.get("eid", 0)))
		"answer":
			_answer(c, int(d.get("eid", 0)), bool(d.get("accept", false)))
		"pick":
			_pick(c, int(d.get("choice", -1)))
		"next":
			_next(c)
		"leave":
			_end(match_of(c), c, "%s đã rời khỏi Oẳn tù xì." % c.entity.name)

func _invite(c, eid: int) -> void:
	var t = gs.conn_of_eid(eid)
	if t == null or t == c or t.entity == null:
		gs.notice(c, "Người chơi không còn ở gần.")
		return
	if not GameServer.near(c.entity, t.entity, INVITE_RANGE):
		gs.notice(c, "Đứng gần hơn mới mời chơi Oẳn tù xì được.")
		return
	if match_of(c) != null:
		gs.notice(c, "Bạn đang chơi Oẳn tù xì rồi.")
		return
	if match_of(t) != null:
		gs.notice(c, "%s đang chơi Oẳn tù xì với người khác." % t.entity.name)
		return
	var key := "%d:%d" % [c.entity.eid, t.entity.eid]
	if _invites.has(key):
		gs.notice(c, "Đã mời rồi — hãy chờ %s trả lời." % t.entity.name)
		return
	_invites[key] = gs.now() + INVITE_SECONDS
	_send(t, {"op": "invite", "from": c.entity.eid, "name": c.entity.name})
	gs.notice(c, "Đã mời %s chơi Oẳn tù xì — hãy chờ đối phương trả lời." % t.entity.name)

func _answer(c, from_eid: int, accept: bool) -> void:
	var key := "%d:%d" % [from_eid, c.entity.eid]
	if not _invites.has(key):
		return
	_invites.erase(key)
	var f = gs.conn_of_eid(from_eid)
	if f == null or f.entity == null:
		gs.notice(c, "Người mời đã rời đi.")
		return
	if not accept:
		gs.notice(f, "%s từ chối chơi Oẳn tù xì." % c.entity.name)
		return
	if match_of(f) != null or match_of(c) != null:
		gs.notice(c, "Một trong hai người đang chơi Oẳn tù xì rồi.")
		return
	var m := Match.new()
	m.a = f
	m.b = c
	_matches[f.entity.eid] = m
	_matches[c.entity.eid] = m
	_broadcast(m)

func _pick(c, choice: int) -> void:
	var m := match_of(c)
	if m == null or m.phase != "pick" or choice < ROCK or choice > PAPER:
		return
	var s := m.side(c)
	if m.picks[s] >= 0:
		return   ## đã xác nhận: không đổi được
	m.picks[s] = choice
	if m.picks[0] >= 0 and m.picks[1] >= 0:
		m.phase = "countdown"
		m.reveal_at = gs.now() + COUNTDOWN
	_broadcast(m)

func _reveal(m: Match) -> void:
	m.last = judge(m.picks[0], m.picks[1])
	if m.last == 1:
		m.wins[0] += 1
	elif m.last == -1:
		m.wins[1] += 1
	else:
		m.draws += 1
	m.history.append({"round": m.round, "a": m.picks[0], "b": m.picks[1], "r": m.last})
	if m.history.size() > HISTORY:
		m.history.pop_front()
	m.phase = "result"
	m.ready = [false, false]
	_broadcast(m)

func _next(c) -> void:
	var m := match_of(c)
	if m == null or m.phase != "result":
		return
	m.ready[m.side(c)] = true
	if m.ready[0] and m.ready[1]:
		m.round += 1
		m.phase = "pick"
		m.picks = [-1, -1]
		m.ready = [false, false]
	_broadcast(m)

## Kết thúc trận (`leaver` rời / thoát): báo bên còn lại, gỡ trận.
func _end(m: Match, leaver, message: String) -> void:
	if m == null:
		return
	_matches.erase(m.a.entity.eid if m.a.entity else -1)
	_matches.erase(m.b.entity.eid if m.b.entity else -1)
	for k in _matches.keys():
		if _matches[k] == m:
			_matches.erase(k)
	var summary := "Tỉ số chung cuộc: %s %d - %d %s (hoà %d)." % [_name(m.a), m.wins[0], m.wins[1], _name(m.b), m.draws]
	for c in [m.a, m.b]:
		if c != leaver:
			_send(c, {"op": "end", "msg": message + "\n" + summary})

func on_leave(c) -> void:
	if c == null or c.entity == null:
		return
	var m := match_of(c)
	if m != null:
		_end(m, c, "%s đã rời đi, Oẳn tù xì kết thúc." % c.entity.name)
	for k in _invites.keys():
		var parts: PackedStringArray = (k as String).split(":")
		if int(parts[0]) == c.entity.eid or int(parts[1]) == c.entity.eid:
			_invites.erase(k)

static func _name(c) -> String:
	return str(c.entity.name) if c != null and c.entity != null else "?"

## Trạng thái nhìn từ phía `c`: lựa chọn của đối thủ chỉ lộ ra khi đã có kết quả.
func state_for(m: Match, c) -> Dictionary:
	var s := m.side(c)
	var o := 1 - s
	var sign := 1 if s == 0 else -1
	var hist := []
	for h in m.history:
		var r := int(h["r"]) * sign
		hist.append({"round": h["round"], "me": h["a"] if s == 0 else h["b"], "op": h["b"] if s == 0 else h["a"],
			"r": r, "winner": "" if r == 0 else (_name(c) if r > 0 else _name(m.other(c)))})
	var st := {
		"op": "state",
		"round": m.round,
		"phase": m.phase,
		"me": {"eid": c.entity.eid, "name": _name(c), "wins": m.wins[s], "picked": m.picks[s] >= 0, "choice": m.picks[s], "ready": m.ready[s]},
		"opp": {"eid": m.other(c).entity.eid, "name": _name(m.other(c)), "wins": m.wins[o], "picked": m.picks[o] >= 0,
			"choice": m.picks[o] if m.phase == "result" else -1, "ready": m.ready[o]},
		"draws": m.draws,
		"history": hist,
	}
	if m.phase == "countdown":
		st["countdown"] = maxf(0.0, m.reveal_at - gs.now())
	if m.phase == "result":
		var r: int = m.last * sign
		st["result"] = "win" if r > 0 else ("lose" if r < 0 else "draw")
		st["winner"] = "" if r == 0 else (_name(c) if r > 0 else _name(m.other(c)))
		st["loser"] = "" if r == 0 else (_name(m.other(c)) if r > 0 else _name(c))
	return st

func _broadcast(m: Match) -> void:
	for c in [m.a, m.b]:
		_send(c, state_for(m, c))

func _send(c, d: Dictionary) -> void:
	var out := NetProto.writer(NetProto.S_RPS)
	NetProto.put_str(out, JSON.stringify(d))
	gs.send(c, out)

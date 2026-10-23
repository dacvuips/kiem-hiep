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

## Lệnh trong C_TEAM
const TEAM_CREATE := 1
const TEAM_DISMISS := 2
const TEAM_LEAVE := 3
const TEAM_INVITE := 4
const TEAM_APPLY := 5
const TEAM_ACCEPT := 6
const TEAM_REJECT := 7
const TEAM_KICK := 8
const TEAM_CAPTAIN := 9
const TEAM_OPEN := 10
const TEAM_PICK := 11
const TEAM_ANSWER := 12
const MAX_APPLY := 32

## Tổ đội trên server (KTeam gốc). members[0] = đội trưởng.
class Team:
	var members: Array = []        ## Conn
	var open := true
	var pick_mode := TeamService.Pick.FREE
	var turn := 0
	var applicants: Array = []     ## Conn
	func captain():
		return members[0]

## Lệnh khoá bảo vệ (C_SECURITY): server giữ mật mã băm + trạng thái khoá.
const SEC_SET := 1      ## hash1 = mã mới, hash2 = mã cũ (rỗng nếu chưa có)
const SEC_CLEAR := 2    ## hash1
const SEC_LOCK := 3
const SEC_UNLOCK := 4   ## hash1

class Trade:
	var session: TradeSession
	var conns: Array = []          ## [GameServer.Conn, GameServer.Conn] cùng thứ tự session.sides

var gs: GameServer
var _invites: Dictionary = {}      ## "from_eid:to_eid" -> hết hạn (giây server)
var _team_invites: Dictionary = {} ## "captain_eid:to_eid" -> hết hạn

func _init(server: GameServer) -> void:
	gs = server

func tick(dt: float, now: float) -> void:
	for k in _invites.keys():
		if now > float(_invites[k]):
			_invites.erase(k)
	for k in _team_invites.keys():
		if now > float(_team_invites[k]):
			_team_invites.erase(k)
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
	if not GameServer.near(c.entity, t.entity, TRADE_RANGE):
		gs.notice(c, "Đứng gần hơn mới giao dịch được.")
		return
	var in_guild_room := false
	if gs.field:
		var r: Dictionary = gs.field.rooms.get(gs.field.room_of.get(c.character_id, ""), {})
		in_guild_room = r.get("guild", "") != ""
	_invite(c, t, not in_guild_room)

## Xin giao dịch theo ID nhân vật (Chợ › Giao dịch): bất kể đứng đâu trên máy chủ, đối phương không cần "mở giao dịch" —
## họ nhận hộp hỏi đồng ý như lời mời thường; đồng ý thì on_trade_answer mở giao dịch.
func on_trade_request_id(c, character_id: int) -> void:
	var t = gs.conn_of_character(character_id)
	if t == c:
		gs.notice(c, "Không thể giao dịch với chính mình.")
		return
	if t == null or gs.battle:
		gs.notice(c, "Không tìm thấy người chơi có ID %d hoặc họ đang không trực tuyến. (Bạn có thể mua vật phẩm của họ trên Chợ Giao Thương)." % character_id)
		return
	_invite(c, t, false)

## `need_open` = lời mời tại chỗ (bấm người đứng gần): đối phương phải đang mở giao dịch.
func _invite(c, t, need_open: bool) -> void:
	var err := SecurityLock.check(c.profile, SecurityLock.A_TRADE_START)
	if err == "":
		if c.trade or t.trade:
			err = "Bạn hoặc đối phương đang trong một giao dịch."
		elif need_open and not t.trade_open:
			err = "Đối phương không mở giao dịch."
		elif t.stall_open:
			err = "Đối phương đang bày bán."
	var key := "%d:%d" % [c.entity.eid, t.entity.eid]
	if err == "" and _invites.has(key):
		err = "Đã gửi lời mời tới %s — hãy chờ trả lời." % t.entity.name   ## chống gửi dồn lời mời (nhất là mời theo ID)
	if err != "":
		gs.notice(c, err)
		return
	_invites[key] = gs.now() + INVITE_SECONDS
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

## Người chơi rời game: huỷ giao dịch (đồ về chủ cũ trên bản server), rời tổ đội.
func on_leave(c) -> void:
	if c.trade:
		(c.trade as Trade).session.cancel("%s đã rời đi, giao dịch bị huỷ." % c.entity.name)
	if c.team:
		_leave_team(c, "%s đã rời game." % c.entity.name)
	for t in _all_teams():
		if t.applicants.has(c):
			t.applicants.erase(c)
			_send_team(t)

# ---------------------------------------------------------------- tổ đội (KTeam / KPlayerTeam gốc)

func _all_teams() -> Array:
	var out := []
	for c in gs.in_world_conns():
		if c.team and not out.has(c.team):
			out.append(c.team)
	return out

static func _capacity(t: Team) -> int:
	return 1 + SocialRules.team_member_cap(t.captain().profile.lead_level)

static func _camp_of(c) -> int:
	return c.profile.get_current_camp()

## Luật vào đội (KTeam::CheckAddCondition): người ngoài tân thủ không vào đội của đội trưởng tân thủ.
func _join_error(t: Team, c) -> String:
	if c.team:
		return "%s đã ở trong một tổ đội khác." % c.entity.name
	if t.members.size() >= _capacity(t):
		return "Đội đã đủ %d người." % _capacity(t)
	if _camp_of(c) != Camp.Type.BEGIN and _camp_of(t.captain()) == Camp.Type.BEGIN:
		return "Không thể vào đội của người tân thủ."
	return ""

func _add(t: Team, c) -> void:
	t.members.append(c)
	t.applicants.erase(c)
	c.team = t
	if t.members.size() >= _capacity(t):
		t.open = false   ## đầy người thì tự đóng đội
	for m in t.members:
		gs.notice(m, "%s đã gia nhập tổ đội." % c.entity.name)
	_send_team(t)

func on_team(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	var arg := b.get_u32() if b.get_available_bytes() >= 4 else 0
	var arg2 := b.get_u8() if b.get_available_bytes() >= 1 else 0
	var t: Team = c.team
	var is_cap: bool = t != null and t.captain() == c
	match op:
		TEAM_CREATE:
			if t:
				gs.notice(c, "Bạn đang ở trong một tổ đội.")
				return
			if SocialRules.team_member_cap(c.profile.lead_level) < 1:
				gs.notice(c, "Chưa đủ cấp lãnh đạo để lập đội.")
				return
			t = Team.new()
			t.members = [c]
			c.team = t
			gs.notice(c, "Tạo tổ đội thành công.")
			_send_team(t)
		TEAM_DISMISS:
			if is_cap:
				_disband(t, "Tổ đội đã giải tán.")
		TEAM_LEAVE:
			if t:
				_leave_team(c, "%s đã rời tổ đội." % c.entity.name)
		TEAM_INVITE:
			var target = gs.conn_of_eid(arg)
			## Chưa có đội thì lập đội trước rồi mời (TeamInviteAdd gốc: TEAM_OI_CREATE rồi TEAM_OI_INVITE).
			if t == null and target != null and SocialRules.team_member_cap(c.profile.lead_level) >= 1:
				t = Team.new()
				t.members = [c]
				c.team = t
				is_cap = true
				gs.notice(c, "Tạo tổ đội thành công.")
				_send_team(t)
			if not is_cap or target == null:
				gs.notice(c, "Chỉ đội trưởng mới mời được người vào đội." if not is_cap else "Người chơi không còn ở gần.")
				return
			if not t.open:
				gs.notice(c, "Đội đang đóng, hãy mở đội để mời người.")
				return
			var err := _join_error(t, target)
			if err != "":
				gs.notice(c, err)
				return
			_team_invites["%d:%d" % [c.entity.eid, target.entity.eid]] = gs.now() + 20.0
			var w := NetProto.writer(NetProto.S_TEAM_INVITE)
			w.put_u32(c.entity.eid)
			NetProto.put_str(w, c.entity.name)
			gs.send(target, w)
			gs.notice(c, "Đã mời %s vào đội." % target.entity.name)
		TEAM_ANSWER:
			var key := "%d:%d" % [arg, c.entity.eid]
			if not _team_invites.has(key):
				return
			_team_invites.erase(key)
			var cap = gs.conn_of_eid(arg)
			if cap == null or cap.team == null or cap.team.captain() != cap:
				gs.notice(c, "Tổ đội không còn nữa.")
				return
			if arg2 == 0:
				gs.notice(cap, "%s từ chối lời mời vào đội." % c.entity.name)
				return
			var err := _join_error(cap.team, c)
			if err != "":
				gs.notice(c, err)
				return
			_add(cap.team, c)
		TEAM_APPLY:
			var cap = gs.conn_of_eid(arg)
			if t:
				gs.notice(c, "Bạn đang ở trong một tổ đội.")
				return
			if cap == null or cap.team == null or cap.team.captain() != cap:
				gs.notice(c, "Người này không phải đội trưởng đang nhận người.")
				return
			var ct: Team = cap.team
			if not ct.open:
				gs.notice(c, "Đội đang đóng.")
				return
			var err := _join_error(ct, c)
			if err != "":
				gs.notice(c, err)
				return
			if not ct.applicants.has(c) and ct.applicants.size() < MAX_APPLY:
				ct.applicants.append(c)
			gs.notice(c, "Đã gửi lời xin vào đội của %s." % cap.entity.name)
			gs.notice(cap, "%s (cấp %d) xin vào đội." % [c.entity.name, c.profile.level])
			_send_team(ct)
		TEAM_ACCEPT, TEAM_REJECT:
			var who = gs.conn_of_eid(arg)
			if not is_cap or who == null or not t.applicants.has(who):
				return
			t.applicants.erase(who)
			if op == TEAM_REJECT:
				gs.notice(who, "%s từ chối cho bạn vào đội." % c.entity.name)
				_send_team(t)
				return
			var err := _join_error(t, who)
			if err != "":
				gs.notice(c, err)
				_send_team(t)
				return
			_add(t, who)
		TEAM_KICK:
			var who = gs.conn_of_eid(arg)
			if is_cap and who != null and who != c and t.members.has(who):
				_remove(t, who)
				gs.notice(who, "Bạn đã bị mời ra khỏi tổ đội.")
				for m in t.members:
					gs.notice(m, "%s đã bị mời ra khỏi tổ đội." % who.entity.name)
				t.open = t.members.size() < _capacity(t)
				_send_team(t)
		TEAM_CAPTAIN:
			var who = gs.conn_of_eid(arg)
			if not is_cap or who == null or who == c or not t.members.has(who):
				return
			if t.members.size() > 1 + SocialRules.team_member_cap(who.profile.lead_level):
				gs.notice(c, "%s chưa đủ cấp lãnh đạo để dẫn %d người." % [who.entity.name, t.members.size()])
				return
			t.members.erase(who)
			t.members.push_front(who)
			for m in t.members:
				gs.notice(m, "%s trở thành đội trưởng." % who.entity.name)
			_send_team(t)
		TEAM_OPEN:
			if is_cap:
				if arg2 != 0 and t.members.size() >= _capacity(t):
					gs.notice(c, "Đội đã đủ người, không mở được.")
				else:
					t.open = arg2 != 0
				_send_team(t)
		TEAM_PICK:
			if is_cap:
				t.pick_mode = clampi(arg2, 0, TeamService.PICK_NAMES.size() - 1)
				t.turn = 0
				_send_team(t)

func _remove(t: Team, c) -> void:
	t.members.erase(c)
	c.team = null
	_send_team_to(c, null)

## Rời đội: đội viên rời thì đội còn; đội trưởng rời = giải tán (KTeam::DeleteMember gốc).
func _leave_team(c, msg: String) -> void:
	var t: Team = c.team
	if t == null:
		return
	if t.captain() == c:
		_disband(t, "Đội trưởng rời đội — tổ đội giải tán.")
		return
	_remove(t, c)
	for m in t.members:
		gs.notice(m, msg)
	t.open = t.members.size() < _capacity(t) and t.open
	_send_team(t)

func _disband(t: Team, msg: String) -> void:
	for m in t.members.duplicate():
		m.team = null
		gs.notice(m, msg)
		_send_team_to(m, null)
	t.members.clear()
	t.applicants.clear()

func _send_team(t: Team) -> void:
	for m in t.members:
		_send_team_to(m, t)

func _send_team_to(c, t: Team) -> void:
	var b := NetProto.writer(NetProto.S_TEAM_STATE)
	if t == null or t.members.is_empty():
		b.put_u8(0)
		gs.send(c, b)
		return
	b.put_u8(1)
	b.put_u32(t.captain().entity.eid)
	b.put_u8(1 if t.open else 0)
	b.put_u8(t.pick_mode)
	b.put_u8(t.turn % maxi(1, t.members.size()))
	b.put_u8(t.members.size())
	for m in t.members:
		b.put_u32(m.entity.eid)
		NetProto.put_str(b, m.entity.name)
		b.put_u16(m.profile.level)
		b.put_8(_camp_of(m))
		b.put_u8(m.profile.lead_level)
		NetProto.put_str(b, m.profile.sect_name)
	var apps: Array = t.applicants if t.captain() == c else []
	b.put_u8(apps.size())
	for a in apps:
		b.put_u32(a.entity.eid)
		NetProto.put_str(b, a.entity.name)
		b.put_u16(a.profile.level)
	gs.send(c, b)

## Được nhặt đồ rơi của `owner_eid` không (luật nhặt của đội người hạ quái — KTeam::CheckIn gốc). true = được.
func team_can_pick(picker, owner_eid: int) -> bool:
	var owner = gs.conn_of_eid(owner_eid)
	if owner == null or owner.team == null or owner.team != picker.team:
		return false
	var t: Team = owner.team
	match t.pick_mode:
		TeamService.Pick.FREE:
			return true
		TeamService.Pick.CAPTAIN:
			return picker == t.captain()
		TeamService.Pick.ALTERNATE:
			return t.members[t.turn % t.members.size()] == picker
	return picker == owner   ## SELF: chỉ người hạ quái

func team_picked(picker) -> void:
	var t: Team = picker.team
	if t and t.pick_mode == TeamService.Pick.ALTERNATE:
		t.turn = (t.turn + 1) % maxi(1, t.members.size())
		_send_team(t)

## Chia kinh nghiệm cho đội của người hạ quái (đồng đội trong tầm ExpRules.SHARE_DISTANCE) — KPlayer::AddExp gốc.
## Trả {conn: exp} cho mọi người được nhận; đội trưởng có mặt nhận thêm kinh nghiệm lãnh đạo.
func team_exp(killer, monster_pos: Vector2, base_exp: int, monster_level: int) -> Dictionary:
	var out := {}
	var t: Team = killer.team
	if t == null:
		return out
	var present: Array = []
	var levels := []
	for m in t.members:
		if m.entity and m.entity.room_id == killer.entity.room_id and m.entity.pos.distance_to(monster_pos) <= ExpRules.SHARE_DISTANCE:
			present.append(m)
			levels.append(m.profile.level)
	var shares := ExpRules.team_shares(base_exp, levels)
	for i in present.size():
		out[present[i]] = ExpRules.self_exp(present[i].profile.level, monster_level, int(shares[i]))
	var cap = t.captain()
	if present.has(cap) and present.size() > 1:
		var gained := ExpRules.add_lead_exp(cap.profile, ExpRules.lead_exp(base_exp, levels, cap.profile.level))
		cap.data["lead_level"] = cap.profile.lead_level
		cap.data["lead_exp"] = cap.profile.lead_exp
		cap.dirty = true
		if gained > 0:
			gs.notice(cap, "Cấp lãnh đạo tăng lên %d." % cap.profile.lead_level)
			gs.profile_changed(cap)
	return out

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

# ---------------------------------------------------------------- khoá bảo vệ

func on_security(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	var h1 := NetProto.get_str(b, 128)
	var h2 := NetProto.get_str(b, 128)
	var p: PlayerProfile = c.profile
	var err := ""
	match op:
		SEC_SET:
			if p.security_hash != "" and h2 != p.security_hash:
				err = "Mật khẩu cũ không chính xác!"
			elif h1.length() != 64:
				err = "Mật khẩu không hợp lệ."
			else:
				p.security_hash = h1
				p.security_locked = true
		SEC_CLEAR:
			if p.security_hash == "" or h1 != p.security_hash:
				err = "Mật mã kiểm chứng không chính xác!"
			else:
				p.security_hash = ""
				p.security_locked = false
		SEC_LOCK:
			if p.security_hash == "":
				err = "Bạn chưa đặt mật khẩu bảo vệ nên không thể khoá."
			else:
				p.security_locked = true
		SEC_UNLOCK:
			if p.security_hash != "" and h1 != p.security_hash:
				err = "Giải mã khoá bảo vệ thất bại: mật mã kiểm chứng không chính xác!"
			else:
				p.security_locked = false
	if err != "":
		gs.notice(c, err)
	gs.profile_changed(c)   ## đồng bộ trạng thái khoá (đúng hay sai đều gửi bản chuẩn)

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
				c.entity.action = NetProto.action_index("sit")   ## người khác thấy ngồi ngay, không chờ gói di chuyển
				c.entity.flags |= NetProto.FLAG_SITTING
				c.entity.touch()
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

## Dọn quầy do server (người bán rời chỗ ngồi...). `why` = thông báo cho người bán.
func close_stall(c, why := "") -> void:
	if not c.stall_open:
		return
	c.stall_open = false
	c.profile.stall_open = false
	_flags(c)
	if why != "":
		gs.notice(c, why)

func _flags(c) -> void:
	var f: int = c.entity.flags & ~(NetProto.FLAG_STALL | NetProto.FLAG_TRADE_OPEN)
	if c.stall_open:
		f |= NetProto.FLAG_STALL
	if c.trade_open:
		f |= NetProto.FLAG_TRADE_OPEN
	if f != c.entity.flags:
		c.entity.flags = f
		c.entity.touch()
	## Biển quầy trên đầu: chỉ nằm trong gói xuất hiện nên đổi thì báo riêng người đang thấy + chính mình.
	var sign: String = c.stall_title if c.stall_open else ""
	if sign != c.entity.stall_title:
		c.entity.stall_title = sign
		var b := NetProto.writer(NetProto.S_STALL_SIGN)
		b.put_u32(c.entity.eid)
		NetProto.put_str(b, sign)
		gs.send_to_viewers(c, b)

func _browse(c, seller_eid: int) -> void:
	var s = gs.conn_of_eid(seller_eid)
	var b := NetProto.writer(NetProto.S_STALL_ITEMS)
	b.put_u32(seller_eid)
	if s == null or not s.stall_open or not GameServer.near(c.entity, s.entity, TRADE_RANGE):
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
	if not GameServer.near(c.entity, s.entity, TRADE_RANGE):
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
		close_stall(s, "Quầy đã hết hàng.")   ## hết hàng thì tự dọn quầy
	_browse(c, seller_eid)

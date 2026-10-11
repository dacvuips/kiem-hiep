class_name RelationServer
extends RefCounted
## Quan hệ giữa người chơi trên game server (menu bấm vào người chơi khác — PopUpContextPeopleMenu gốc):
##   - HẢO HỮU (friend_c2c_askaddfriend / repaddfriend gốc): xin kết giao -> bên kia Đồng ý / Từ chối -> thêm vào danh sách
##     của CẢ HAI. Bên kia đã có mình trong danh sách thì tự thêm, không hỏi. Cả hai phải đang online.
##     Danh sách nằm trong hồ sơ nhân vật (`friends`, tên nhân vật) — server giữ, game không tự thêm được.
##   - TIN TỨC (c2s_viewequip gốc): xem trang bị người đứng gần, không cần họ đồng ý; chờ 30 nhịp (~1,7 giây) giữa 2 lần xem.
## Sổ đen là của riêng mỗi người (chỉ lọc tin nhắn ở máy mình) nên không qua đây.

const FRIEND_ASK := 1      ## eid = người được xin
const FRIEND_ANSWER := 2   ## eid = người xin, arg = 1 đồng ý / 0 từ chối
const FRIEND_REMOVE := 3   ## name = tên bạn cần xoá
const FRIEND_LIST := 4     ## xin danh sách bạn kèm trạng thái online

## Không có trong source gốc (server không giới hạn) — giới hạn của game để hồ sơ không phình mãi.
const MAX_FRIENDS := 100
const INVITE_SECONDS := 30.0
## defMAX_VIEW_EQUIP_TIME = 30 nhịp game (18 nhịp/giây).
const VIEW_EQUIP_SECONDS := 30.0 / 18.0
const VIEW_RANGE := 1536.0   ## px — phải đứng trong tầm nhìn (3x3 ô AOI)

var gs: GameServer
var _asks: Dictionary = {}   ## "from_eid:to_eid" -> hết hạn (giây server)

func _init(server: GameServer) -> void:
	gs = server

func tick(now: float) -> void:
	for k in _asks.keys():
		if now > float(_asks[k]):
			_asks.erase(k)
	for c in gs.in_world_conns():
		tick_enmity(c)

# ---------------------------------------------------------------- hảo hữu

func on_friend(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	var eid := b.get_u32()
	var arg := b.get_u8()
	var name := NetProto.get_str(b, 64)
	match op:
		FRIEND_ASK:
			_ask(c, eid)
		FRIEND_ANSWER:
			_answer(c, eid, arg == 1)
		FRIEND_REMOVE:
			var list: Array = c.profile.friends
			if list.has(name):
				list.erase(name)
				gs.notice(c, "Đã xoá %s khỏi danh sách hảo hữu." % name)
				gs.profile_changed(c)
		FRIEND_LIST:
			send_list(c)

func _ask(c, eid: int) -> void:
	var t = gs.conn_of_eid(eid)
	if t == null or t == c:
		gs.notice(c, "Hiện không thể kết giao với người này.")
		return
	var me: String = c.entity.name
	var other: String = t.entity.name
	if (c.profile.friends as Array).has(other):
		gs.notice(c, "%s đã ở trong danh sách hảo hữu." % other)
		return
	if (c.profile.friends as Array).size() >= MAX_FRIENDS:
		gs.notice(c, "Danh sách hảo hữu đã đầy (%d người)." % MAX_FRIENDS)
		return
	## Bên kia đã có mình trong danh sách: thêm luôn (answerAgree gốc).
	if (t.profile.friends as Array).has(me):
		_make_friends(c, t)
		return
	_asks["%d:%d" % [c.entity.eid, t.entity.eid]] = gs.now() + INVITE_SECONDS
	var out := NetProto.writer(NetProto.S_FRIEND_INVITE)
	out.put_u32(c.entity.eid)
	NetProto.put_str(out, me)
	gs.send(t, out)
	gs.notice(c, "Bạn đến %s xin phép được kết giao." % other)

func _answer(c, from_eid: int, agree: bool) -> void:
	var key := "%d:%d" % [from_eid, c.entity.eid]
	if not _asks.has(key):
		return
	_asks.erase(key)
	var f = gs.conn_of_eid(from_eid)
	if f == null:
		return
	if not agree:
		gs.notice(f, "%s từ chối yêu cầu kết bạn." % c.entity.name)
		return
	_make_friends(f, c)

func _make_friends(a, b) -> void:
	for pair in [[a, b], [b, a]]:
		var list: Array = pair[0].profile.friends
		var other: String = pair[1].entity.name
		if not list.has(other) and list.size() < MAX_FRIENDS:
			list.append(other)
		gs.notice(pair[0], "Thêm %s vào danh sách bằng hữu thành công." % other)
		gs.profile_changed(pair[0])

func send_list(c) -> void:
	var list := []
	for n in c.profile.friends:
		var f = gs.conn_of_name(str(n))
		list.append({"name": str(n), "online": f != null, "level": f.profile.level if f else 0})
	var out := NetProto.writer(NetProto.S_FRIEND_LIST)
	NetProto.put_str(out, JSON.stringify(list))
	gs.send(c, out)

func on_leave(c) -> void:
	if int(c.enmity.get("state", ENMITY_NONE)) != ENMITY_NONE:
		var other = gs.conn_of_eid(int(c.enmity.get("other", 0)))
		c.enmity = {}
		if other:
			end_enmity(other, "%s đã rời đi, cừu sát kết thúc." % c.entity.name)
	for k in _asks.keys():
		var parts: PackedStringArray = (k as String).split(":")
		if int(parts[0]) == c.entity.eid or int(parts[1]) == c.entity.eid:
			_asks.erase(k)

# ---------------------------------------------------------------- tin tức (xem trang bị)

func on_view_equip(c, eid: int) -> void:
	if gs.now() - c.last_view_equip < VIEW_EQUIP_SECONDS:
		gs.notice(c, "Xem trang bị quá nhanh, hãy đợi giây lát.")
		return
	c.last_view_equip = gs.now()
	var t = gs.conn_of_eid(eid)
	if t == null or t == c:
		gs.notice(c, "Không thấy người chơi này.")
		return
	if (t.entity.pos as Vector2).distance_to(c.entity.pos) > VIEW_RANGE:
		gs.notice(c, "%s không ở gần bạn." % t.entity.name)
		return
	var out := NetProto.writer(NetProto.S_VIEW_EQUIP)
	NetProto.put_json(out, ViewEquipService.snapshot_of_profile(t.profile))
	gs.send(c, out)

# ---------------------------------------------------------------- cừu sát (KPlayerPK::EnmityPKOpen gốc)

const ENMITY_NONE := 0
const ENMITY_WAIT := 1     ## đếm ngược, chưa được đánh
const ENMITY_FIGHT := 2    ## hai bên là địch của nhau
const ENMITY_WAIT_SECONDS := 200.0 / 18.0       ## PK_ANMITY_TIME = 200 nhịp
const ENMITY_FIGHT_SECONDS := 10800.0 / 18.0    ## PK_ANMITY_CLOSE_TIME = 10800 nhịp (10 phút)
const PK_ENMITY_KILL := 2      ## PKSet.ini EnmityPK — người KHỞI XƯỚNG giết được đối phương
const PK_BE_KILLED := -1       ## PKSet.ini BeKilled
const PK_NO_FIGHT := 6         ## NotFightWhenHightPK
const PK_NO_ENMITY_LOCKED := 3 ## PKNotSwitchPKWhenLock: PK >= 3 mà đang khoá bảo vệ thì không cừu sát được
const PK_MAX := 10
const KILL_CREDIT_SECONDS := 10.0   ## chết trong vòng này sau đòn của đối thủ thì tính là bị họ giết
const MAX_PVP_HITS_PER_SEC := 15

func on_enmity(c, eid: int) -> void:
	var t = gs.conn_of_eid(eid)
	var err := _enmity_error(c, t)
	if err != "":
		gs.notice(c, err)
		return
	## Đối phương đang cừu sát người khác: huỷ cái cũ, ép theo người mới (gốc).
	if int(t.enmity.get("state", ENMITY_NONE)) != ENMITY_NONE:
		end_enmity(t, "")
	var until: float = gs.now() + (1.0 if gs.test_mode else ENMITY_WAIT_SECONDS)   ## kiểm thử: đếm ngược 1 giây
	c.enmity = {"other": t.entity.eid, "state": ENMITY_WAIT, "until": until, "launcher": true}
	t.enmity = {"other": c.entity.eid, "state": ENMITY_WAIT, "until": until, "launcher": false}
	_send_enmity(c)
	_send_enmity(t)
	gs.notice(c, "Bạn tuyên bố cừu sát %s. Sau 10 giây bắt đầu tiến hành cừu sát!" % t.entity.name)
	gs.notice(t, "%s tuyên bố cừu sát bạn. Sau 10 giây bắt đầu tiến hành cừu sát!" % c.entity.name)

func _enmity_error(c, t) -> String:
	if t == null or t == c:
		return "Không thể cừu sát người này."
	if (t.entity.pos as Vector2).distance_to(c.entity.pos) > VIEW_RANGE:
		return "%s không ở gần bạn." % t.entity.name
	if (c.entity.flags & NetProto.FLAG_DEAD) != 0 or (t.entity.flags & NetProto.FLAG_DEAD) != 0:
		return "Không thể cừu sát lúc này."
	if c.profile.pk_value >= PK_NO_FIGHT:
		return "Trị PK của bạn quá cao, không thể cừu sát."
	if c.profile.pk_value >= PK_NO_ENMITY_LOCKED and c.profile.security_locked:
		return "Trị PK từ %d trở lên phải mở khoá bảo vệ mới cừu sát được." % PK_NO_ENMITY_LOCKED
	if c.profile.get_current_camp() == Camp.Type.BEGIN:
		return "Tân thủ không thể cừu sát."
	if t.profile.get_current_camp() == Camp.Type.BEGIN:
		return "Không thể cừu sát tân thủ."
	if int(c.enmity.get("state", ENMITY_NONE)) != ENMITY_NONE:
		return "Bạn đang trong trạng thái cừu sát."
	if c.trade != null:
		return "Đang giao dịch, không thể cừu sát."
	return ""

func tick_enmity(c) -> void:
	var st := int(c.enmity.get("state", ENMITY_NONE))
	if st == ENMITY_NONE or gs.now() < float(c.enmity.until):
		return
	if st == ENMITY_WAIT:
		c.enmity.state = ENMITY_FIGHT
		c.enmity.until = gs.now() + ENMITY_FIGHT_SECONDS
		_send_enmity(c)
		var other = gs.conn_of_eid(int(c.enmity.other))
		gs.notice(c, "Bắt đầu cừu sát với %s!" % (other.entity.name if other else ""))
	else:
		end_enmity(c, "Hết thời gian cừu sát.")

## Kết thúc cừu sát của `c` và đối phương. msg rỗng = không báo.
func end_enmity(c, msg: String) -> void:
	var other = gs.conn_of_eid(int(c.enmity.get("other", 0)))
	for x in [c, other]:
		if x == null or int(x.enmity.get("state", ENMITY_NONE)) == ENMITY_NONE:
			continue
		x.enmity = {}
		_send_enmity(x)
		if msg != "":
			gs.notice(x, msg)

func _send_enmity(c) -> void:
	var out := NetProto.writer(NetProto.S_ENMITY)
	var st := int(c.enmity.get("state", ENMITY_NONE))
	out.put_u8(st)
	var other = gs.conn_of_eid(int(c.enmity.get("other", 0)))
	out.put_u32(other.entity.eid if other else 0)
	NetProto.put_str(out, other.entity.name if other else "")
	out.put_u8(1 if bool(c.enmity.get("launcher", false)) else 0)
	gs.send(c, out)

func _fighting(a, b) -> bool:
	return a != null and b != null and int(a.enmity.get("state", 0)) == ENMITY_FIGHT \
		and int(a.enmity.get("other", 0)) == b.entity.eid and int(b.enmity.get("other", 0)) == a.entity.eid

## Đòn của `c` vào người chơi `eid`: chỉ khi 2 bên đang cừu sát nhau; cắt theo trần sát thương rồi chuyển cho máy bị đánh.
func on_pvp_hit(c, eid: int, bytes: PackedByteArray) -> void:
	if gs.now() - c.pvp_window > 1.0:
		c.pvp_window = gs.now()
		c.pvp_msgs = 0
	c.pvp_msgs += 1
	if c.pvp_msgs > MAX_PVP_HITS_PER_SEC:
		return
	var t = gs.conn_of_eid(eid)
	if not _fighting(c, t) or (c.entity.flags & NetProto.FLAG_DEAD) != 0 or (t.entity.flags & NetProto.FLAG_DEAD) != 0:
		return
	if (t.entity.pos as Vector2).distance_to(c.entity.pos) > GameServer.MAX_HIT_DISTANCE:
		return
	var hit := PvpHit.decode(bytes)
	if hit.is_empty():
		return
	PvpHit.sanitize(hit, c.max_hit)
	t.last_pvp_from = c.entity.eid
	t.last_pvp_at = gs.now()
	var out := NetProto.writer(NetProto.S_PVP_HIT)
	out.put_u32(c.entity.eid)
	var raw := var_to_bytes(hit)
	out.put_u32(raw.size())
	out.put_data(raw)
	gs.send(t, out)

## Người chơi `c` vừa chết (cờ FLAG_DEAD bật).
func on_died(c) -> void:
	if int(c.enmity.get("state", ENMITY_NONE)) == ENMITY_NONE:
		return
	var killer = gs.conn_of_eid(int(c.enmity.get("other", 0)))
	var by_enemy: bool = killer != null and c.last_pvp_from == killer.entity.eid and gs.now() - c.last_pvp_at <= KILL_CREDIT_SECONDS \
		and _fighting(c, killer)
	if by_enemy:
		## Chỉ người KHỞI XƯỚNG giết được đối phương mới bị cộng PK (IsEnmityPKLauncher gốc).
		if bool(killer.enmity.get("launcher", false)):
			killer.profile.pk_value = mini(PK_MAX, killer.profile.pk_value + PK_ENMITY_KILL)
			gs.notice(killer, "Bạn đã hạ %s. Trị PK tăng lên %d." % [c.entity.name, killer.profile.pk_value])
			gs.profile_changed(killer)
		else:
			gs.notice(killer, "Bạn đã hạ %s." % c.entity.name)
		c.profile.pk_value = maxi(0, c.profile.pk_value + PK_BE_KILLED)
		gs.notice(c, "Bạn bị %s hạ trong cừu sát." % killer.entity.name)
		gs.profile_changed(c)
	end_enmity(c, "Cừu sát kết thúc.")

class_name GuildServer
extends RefCounted
## BANG HỘI trên game server: mỗi bang là 1 Dictionary DÙNG CHUNG (định dạng GuildService), lưu PostgreSQL qua API nội bộ.
## Thao tác của thành viên chạy bằng chính GuildService gốc trên bản bang chung (đặt tạm vào hồ sơ server của người thao tác,
## đánh dấu "local" cho đúng người đó). Vào / rời / lập / giải tán / xin vào / mời / duyệt do server xử lý vì cần người thật.
## Sau mỗi thay đổi: lưu bang + gửi bản mới (S_GUILD) cho thành viên đang online.

const FUND_TICK_SECONDS := 30

## Lệnh C_GUILD (tham số trong JSON)
const G_CREATE := 1        ## {title, camp}
const G_DISBAND := 2
const G_LEAVE := 3
const G_APPLY := 4         ## {guild}
const G_ACCEPT := 5        ## {name}
const G_REJECT := 6        ## {name}
const G_INVITE := 7        ## {eid}
const G_ANSWER := 8        ## {guild, accept}
const G_INSTATE := 9       ## {name, figure}
const G_KICK := 10         ## {name}
const G_MASTER := 11       ## {name}
const G_NOTICE := 12       ## {text}
const G_EVENT := 13        ## {text}
const G_RENAME := 14       ## {name}
const G_RECRUIT_INFO := 15 ## {tendency, activity, msg, accept_level, reject_level}
const G_RECRUIT := 16      ## {value}
const G_TITLE := 17        ## {name, title}
const G_DONATE := 18       ## {amount}
const G_PERMS := 19        ## {name, perms}
const G_LIST := 20
const G_TEST_BOOST := 99   ## CHỈ khi GAME_TEST_MODE=1: nâng nhân vật thử đủ điều kiện lập / rời bang

var gs: GameServer
var guilds: Dictionary = {}        ## tên bang -> Dictionary (bản chung, không có cờ "local")
var _invites: Dictionary = {}      ## "guild|to_eid" -> hết hạn
var _loaded := false
var _fund_clock := 0.0

func _init(server: GameServer) -> void:
	gs = server

func load_all() -> void:
	var r: Dictionary = await gs.account.list_guilds()
	if not r.ok:
		push_warning("Không nạp được bang hội: %s" % r.get("message", ""))
		return
	for g in r.get("guilds", []):
		if g.get("data") is Dictionary:
			guilds[str(g.name)] = g.data
	_loaded = true
	print("Bang hội: %d" % guilds.size())

func guild_of_name(member_name: String) -> Dictionary:
	for g in guilds.values():
		for m in g.get("members", []):
			if str(m.get("name", "")) == member_name:
				return g
	return {}

## Người chơi vào map: gắn bang chung (nếu còn là thành viên), bỏ bản bang cũ trong hồ sơ nếu đã bị đuổi / bang giải tán.
func on_join(c) -> void:
	var g := guild_of_name(c.entity.name)
	c.profile.guild = g
	c.data["guild"] = g
	send_guild(c)

func tick(dt: float) -> void:
	_fund_clock += dt
	if _fund_clock < FUND_TICK_SECONDS:
		return
	_fund_clock = 0.0
	for k in _invites.keys():
		if gs.now() > float(_invites[k]):
			_invites.erase(k)
	## Quỹ bang -> kinh nghiệm bang, thử thách bang mới (giống SocialHub.tick khi chơi một mình).
	for name in guilds.keys():
		var g: Dictionary = guilds[name]
		var holder := PlayerProfile.new()
		holder.guild = g
		var svc := GuildService.new(holder)
		var changed := svc.process_fund(FUND_TICK_SECONDS) > 0
		if svc.check_trial():
			_disband(name, "Bang hội không đủ thành viên trong thời gian thử thách nên đã giải tán.")
			continue
		if changed:
			_save(name)
			_broadcast(name)

# ---------------------------------------------------------------- lệnh

func on_guild(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 8192))
	var a: Dictionary = parsed if parsed is Dictionary else {}
	match op:
		G_TEST_BOOST:
			if gs.test_mode:
				var cfg: Dictionary = SocialRules.tong()["create"]
				var p: PlayerProfile = c.profile
				p.level = maxi(p.level, int(cfg["level"]))
				p.lead_level = maxi(p.lead_level, int(cfg["lead_level"]))
				p.gold = maxi(p.gold, int(cfg["money"]) + int(SocialRules.tong()["leave"]["money"]) + 1000)
				p.prestige = maxi(p.prestige, int(cfg["repute"]) + int(SocialRules.tong()["leave"]["repute"]))
				p.fuyuan = maxi(p.fuyuan, int(cfg["fuyuan"]))
				gs.profile_changed(c)
		G_LIST:
			_send_list(c)
		G_CREATE:
			_create(c, str(a.get("title", "")), int(a.get("camp", 0)))
		G_APPLY:
			_apply(c, str(a.get("guild", "")))
		G_ACCEPT, G_REJECT:
			_decide(c, str(a.get("name", "")), op == G_ACCEPT)
		G_INVITE:
			_invite(c, int(a.get("eid", 0)))
		G_ANSWER:
			_answer(c, str(a.get("guild", "")), bool(a.get("accept", false)))
		G_LEAVE:
			_leave(c)
		G_DISBAND:
			_run(c, func(svc: GuildService) -> String: return svc.disband(), func(name: String) -> void:
				_disband(name, "Bang hội đã giải tán."))
		G_KICK:
			var who := str(a.get("name", ""))
			_run(c, func(svc: GuildService) -> String: return svc.kick(who), func(_n: String) -> void:
				var k = gs.conn_of_name(who)
				if k:
					k.profile.guild = {}
					k.profile.camp = -1
					gs.profile_changed(k)
					send_guild(k)
					gs.notice(k, "Bạn đã bị mời ra khỏi bang hội."))
		G_INSTATE:
			var who := str(a.get("name", ""))
			var fig := int(a.get("figure", 0))
			_run(c, func(svc: GuildService) -> String: return svc.instate(who, fig))
		G_MASTER:
			var who := str(a.get("name", ""))
			_run(c, func(svc: GuildService) -> String: return svc.change_master(who))
		G_NOTICE:
			var text := str(a.get("text", ""))
			_run(c, func(svc: GuildService) -> String: return svc.set_notice(text))
		G_EVENT:
			var text := str(a.get("text", ""))
			_run(c, func(svc: GuildService) -> String: return svc.add_event(text))
		G_RENAME:
			_rename(c, str(a.get("name", "")))
		G_RECRUIT_INFO:
			_run(c, func(svc: GuildService) -> String:
				return svc.set_recruit_info(str(a.get("tendency", "")), str(a.get("activity", "")), str(a.get("msg", "")),
					int(a.get("accept_level", 0)), int(a.get("reject_level", 0))))
		G_RECRUIT:
			var v := bool(a.get("value", false))
			_run(c, func(svc: GuildService) -> String: return svc.set_recruit(v))
		G_TITLE:
			var who := str(a.get("name", ""))
			var title := str(a.get("title", ""))
			_run(c, func(svc: GuildService) -> String: return svc.set_title(who, title))
		G_DONATE:
			var amount := int(a.get("amount", 0))
			_run(c, func(svc: GuildService) -> String: return svc.donate(amount), func(_n: String) -> void: gs.profile_changed(c))
		G_PERMS:
			var who := str(a.get("name", ""))
			var perms: Array = a.get("perms", []) if a.get("perms") is Array else []
			_run(c, func(svc: GuildService) -> String: return svc.set_perms(who, perms))

## Chạy 1 thao tác GuildService của người `c` trên bang chung. after(tên bang) chạy khi thành công.
func _run(c, action: Callable, after: Callable = Callable()) -> void:
	var g := guild_of_name(c.entity.name)
	if g.is_empty():
		gs.notice(c, "Bạn chưa có bang hội.")
		return
	var name := str(g.name)
	_mark_local(g, c.entity.name)
	c.profile.guild = g
	var svc := GuildService.new(c.profile)
	var said := []
	svc.message.connect(func(text: String, _good: bool) -> void: said.append(text))
	var err: String = action.call(svc)
	_mark_local(g, "")
	for t in said:
		gs.notice(c, t)
	if err != "":
		if said.is_empty():
			gs.notice(c, err)
		c.profile.guild = g
		return
	if after.is_valid():
		after.call(name)
	if guilds.has(name):
		c.profile.guild = guilds[name]
		_save(name)
		_broadcast(name)

static func _mark_local(g: Dictionary, member_name: String) -> void:
	for m in g.get("members", []):
		m["local"] = str(m.get("name", "")) == member_name

func _create(c, title: String, camp: int) -> void:
	title = title.strip_edges()
	if guilds.has(title):
		gs.notice(c, "Bang hội đã tồn tại hoặc tên bang bị lỗi, không thể tạo.")
		return
	if not guild_of_name(c.entity.name).is_empty():
		gs.notice(c, "Thành viên bang hội không thể lập thêm một bang hội khác!")
		return
	c.profile.guild = {}
	c.profile.trade_open = c.trade_open
	c.profile.stall_open = c.stall_open
	var svc := GuildService.new(c.profile)
	svc.message.connect(func(text: String, _good: bool) -> void: gs.notice(c, text))
	var err := svc.create(title, camp, null if c.team == null else _team_stub())
	if err != "":
		return
	var g: Dictionary = c.profile.guild
	_mark_local(g, "")
	guilds[str(g.name)] = g
	_save(str(g.name))
	gs.profile_changed(c)   ## trừ tiền lập bang, đổi phe
	send_guild(c)

## create_blockers chỉ cần biết có đang trong tổ đội không.
static func _team_stub() -> TeamService:
	var t := TeamService.new(PlayerProfile.new())
	t.captain = TeamService.Member.new()
	return t

func _apply(c, guild_name: String) -> void:
	var g: Dictionary = guilds.get(guild_name, {})
	if g.is_empty():
		gs.notice(c, "Bang hội không còn tồn tại.")
		return
	if not guild_of_name(c.entity.name).is_empty():
		gs.notice(c, "Bạn đã ở trong một bang hội.")
		return
	var wait: int = c.profile.guild_join_after - SecurityLock.now()
	if wait > 0:
		gs.notice(c, "Mới rời bang — còn %d giờ nữa mới xin vào bang khác được." % ceili(wait / 3600.0))
		return
	if not bool(g.get("recruit", false)):
		gs.notice(c, "Bang này đang không tuyển người.")
		return
	if c.profile.level < int(g.get("accept_level", 0)):
		gs.notice(c, "Bang yêu cầu cấp %d trở lên." % int(g.get("accept_level", 0)))
		return
	var applies: Array = g.get("applies", [])
	for ap in applies:
		if str(ap.get("name", "")) == c.entity.name:
			gs.notice(c, "Bạn đã gửi đơn xin vào bang này.")
			return
	applies.append({"name": c.entity.name, "level": c.profile.level, "sect": c.profile.sect_name, "mock_id": -1})
	g["applies"] = applies
	_save(guild_name)
	_broadcast(guild_name)
	gs.notice(c, "Đã gửi đơn xin vào bang %s." % guild_name)

## Người có quyền duyệt (Bang chủ / Trưởng lão) nhận / từ chối đơn. Người xin phải đang online.
func _decide(c, applicant: String, accept: bool) -> void:
	var g := guild_of_name(c.entity.name)
	if g.is_empty():
		return
	_mark_local(g, c.entity.name)
	var holder := PlayerProfile.new()
	holder.guild = g
	var can := GuildService.new(holder).is_officer()
	_mark_local(g, "")
	if not can:
		gs.notice(c, "Bạn không có quyền duyệt đơn.")
		return
	var applies: Array = g.get("applies", [])
	var found := -1
	for i in applies.size():
		if str(applies[i].get("name", "")) == applicant:
			found = i
	if found < 0:
		return
	applies.remove_at(found)
	var name := str(g.name)
	var who = gs.conn_of_name(applicant)
	if accept:
		if who == null:
			gs.notice(c, "%s không online — không duyệt được (đơn đã huỷ)." % applicant)
		elif not guild_of_name(applicant).is_empty():
			gs.notice(c, "%s đã vào bang khác." % applicant)
		elif g.get("members", []).size() >= SocialRules.tong_member_cap(int(g.get("level", 1))):
			gs.notice(c, "Bang đã đủ người.")
		else:
			_enroll(name, who)
	else:
		if who:
			gs.notice(who, "Bang %s từ chối đơn của bạn." % name)
	_save(name)
	_broadcast(name)

func _enroll(guild_name: String, who) -> void:
	var g: Dictionary = guilds[guild_name]
	var fig := GuildRules.Figure.MEMBER
	g["members"].append({"name": who.entity.name, "figure": fig, "level": who.profile.level, "sect": who.profile.sect_name,
		"joined_at": SecurityLock.now(), "devote": 0, "title": "", "local": false, "mock_id": -1, "perms": GuildRules.default_perms(fig)})
	var log: Array = g.get("log", [])
	log.append({"at": SecurityLock.now(), "text": "%s gia nhập bang hội." % who.entity.name, "kind": "history"})
	while log.size() > GuildService.MAX_LOG:
		log.pop_front()
	g["log"] = log
	who.profile.guild = g
	who.profile.camp = int(g.get("camp", who.profile.camp))
	gs.profile_changed(who)
	gs.notice(who, "Bạn đã gia nhập bang %s." % guild_name)

func _invite(c, target_eid: int) -> void:
	var g := guild_of_name(c.entity.name)
	var t = gs.conn_of_eid(target_eid)
	if g.is_empty() or t == null:
		return
	_mark_local(g, c.entity.name)
	var holder := PlayerProfile.new()
	holder.guild = g
	var can := GuildService.new(holder).is_officer()
	_mark_local(g, "")
	if not can:
		gs.notice(c, "Chỉ Bang chủ / Trưởng lão mới mời người vào bang.")
		return
	if not guild_of_name(t.entity.name).is_empty():
		gs.notice(c, "%s đã ở trong một bang hội." % t.entity.name)
		return
	_invites["%s|%d" % [g.name, t.entity.eid]] = gs.now() + 30.0
	var w := NetProto.writer(NetProto.S_GUILD_INVITE)
	NetProto.put_str(w, str(g.name))
	NetProto.put_str(w, c.entity.name)
	gs.send(t, w)
	gs.notice(c, "Đã mời %s vào bang." % t.entity.name)

func _answer(c, guild_name: String, accept: bool) -> void:
	var key := "%s|%d" % [guild_name, c.entity.eid]
	if not _invites.has(key) or not guilds.has(guild_name):
		return
	_invites.erase(key)
	if not accept:
		return
	if not guild_of_name(c.entity.name).is_empty():
		return
	if c.profile.guild_join_after > SecurityLock.now():
		gs.notice(c, "Mới rời bang — chưa vào bang khác được.")
		return
	_enroll(guild_name, c)
	_save(guild_name)
	_broadcast(guild_name)

func _leave(c) -> void:
	var g := guild_of_name(c.entity.name)
	if g.is_empty():
		return
	var name := str(g.name)
	_mark_local(g, c.entity.name)
	c.profile.guild = g
	var svc := GuildService.new(c.profile)
	svc.message.connect(func(text: String, _good: bool) -> void: gs.notice(c, text))
	var err := svc.leave()   ## trừ phí, đặt thời gian chờ, profile.guild = {}
	_mark_local(g, "")
	if err != "":
		c.profile.guild = g
		return
	var members: Array = g.get("members", [])
	for i in range(members.size() - 1, -1, -1):
		if str(members[i].get("name", "")) == c.entity.name:
			members.remove_at(i)
	var log: Array = g.get("log", [])
	log.append({"at": SecurityLock.now(), "text": "%s rời bang hội." % c.entity.name, "kind": "history"})
	g["log"] = log
	gs.profile_changed(c)
	send_guild(c)
	_save(name)
	_broadcast(name)

func _rename(c, new_name: String) -> void:
	new_name = new_name.strip_edges()
	var g := guild_of_name(c.entity.name)
	if g.is_empty():
		return
	var old := str(g.name)
	if new_name != old and guilds.has(new_name):
		gs.notice(c, "Tên bang đã có người dùng.")
		return
	_run(c, func(svc: GuildService) -> String: return svc.rename(new_name), func(_n: String) -> void:
		guilds.erase(old)
		guilds[str(g.name)] = g
		_save(str(g.name), old))

func _disband(name: String, msg: String) -> void:
	var g: Dictionary = guilds.get(name, {})
	guilds.erase(name)
	gs.account.delete_guild(name)
	for m in g.get("members", []):
		var who = gs.conn_of_name(str(m.get("name", "")))
		if who:
			who.profile.guild = {}
			who.profile.camp = -1
			gs.profile_changed(who)
			send_guild(who)
			gs.notice(who, msg)

# ---------------------------------------------------------------- gửi / lưu

func _save(name: String, old_name := "") -> void:
	if guilds.has(name):
		gs.account.save_guild(name, guilds[name], old_name)

func _broadcast(name: String) -> void:
	var g: Dictionary = guilds.get(name, {})
	for m in g.get("members", []):
		var who = gs.conn_of_name(str(m.get("name", "")))
		if who:
			who.profile.guild = g
			send_guild(who)

## Bản bang cho riêng người này (cờ "local" ở đúng mục của họ). Không có bang thì gửi chuỗi rỗng.
func send_guild(c) -> void:
	var g := guild_of_name(c.entity.name)
	var b := NetProto.writer(NetProto.S_GUILD)
	if g.is_empty():
		NetProto.put_str(b, "")
	else:
		var copy: Dictionary = g.duplicate(true)
		_mark_local(copy, c.entity.name)
		NetProto.put_str(b, JSON.stringify(copy))
	gs.send(c, b)

## Danh sách bang (để xin vào): tên, phe, cấp, số người, bang chủ, đang tuyển...
func _send_list(c) -> void:
	var list := []
	for g in guilds.values():
		var master := ""
		for m in g.get("members", []):
			if int(m.get("figure", -1)) == GuildRules.Figure.MASTER:
				master = str(m.get("name", ""))
		list.append({"name": g.name, "camp": g.get("camp", 0), "level": g.get("level", 1), "members": g.get("members", []).size(),
			"cap": SocialRules.tong_member_cap(int(g.get("level", 1))), "master": master, "recruit": g.get("recruit", false),
			"accept_level": g.get("accept_level", 0), "tendency": g.get("tendency", ""), "activity": g.get("activity", ""),
			"recruit_msg": g.get("recruit_msg", "")})
	var b := NetProto.writer(NetProto.S_GUILD_LIST)
	NetProto.put_str(b, JSON.stringify(list))
	gs.send(c, b)

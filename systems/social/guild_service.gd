extends RefCounted
class_name GuildService
## BANG HỘI — theo KPlayerTong / KTongData / Tong_Setting.ini của VLTK gốc (xem docs/vltk_social_systems_reference.md).
## Dữ liệu bang nằm TRONG PlayerProfile.guild (Dictionary, lưu cùng nhân vật) vì chưa có server chung; khi online, `guild` là bản sao
## server gửi xuống và các hàm dưới đây chuyển thành lệnh gửi server. Mọi hàm hành động trả về "" nếu thành công, hoặc lời báo lỗi.
##
## Cấu trúc guild: {name, camp, level, exp, fund, notice, recruit, accept_level, created_at, members: [...], applies: [...], log: [...]}
##   member: {name, figure (GuildRules.Figure), level, sect, joined_at, devote, title, local (true nếu là mình), mock_id}
##   apply : {name, level, sect, mock_id}

signal changed
signal message(text: String, good: bool)

const MAX_NOTICE := 256
const MAX_TITLE := 12
const MAX_LOG := 40
## Gốc yêu cầu 1 món đồ riêng (Nhạc Vương Kiếm, RequireItem=1,4,195) để lập bang — game này chưa có món đó nên bỏ qua điều kiện này.
const REQUIRE_CREATE_ITEM := false

var profile: PlayerProfile
var rng := RandomNumberGenerator.new()

func _init(p: PlayerProfile) -> void:
	profile = p
	rng.randomize()

## Online: bang nằm ở game server; S_GUILD gửi bản mới (cờ "local" ở mục của mình).
func apply_net_guild(data: Dictionary) -> void:
	profile.guild = data
	changed.emit()

func in_guild() -> bool:
	return not profile.guild.is_empty()

func data() -> Dictionary:
	return profile.guild

func guild_name() -> String:
	return str(profile.guild.get("name", ""))

func _say(text: String, good := false) -> String:
	message.emit(text, good)
	return text

## kind: "history" (vào/rời/lập/nhường chức/đổi tên...) hoặc "event" (sự kiện do người quản lý thêm vào, quyên góp, bổ nhiệm...).
func _log(text: String, kind := "history") -> void:
	var log: Array = profile.guild.get("log", [])
	log.append({"at": SecurityLock.now(), "text": text, "kind": kind})
	while log.size() > MAX_LOG:
		log.pop_front()
	profile.guild["log"] = log

# ------------------------------------------------------------------ thành viên
func members() -> Array:
	return profile.guild.get("members", [])

func applies() -> Array:
	return profile.guild.get("applies", [])

func local_member() -> Dictionary:
	for m in members():
		if m.get("local", false):
			return m
	return {}

func local_figure() -> int:
	var m := local_member()
	return int(m.get("figure", GuildRules.Figure.MEMBER)) if not m.is_empty() else -1

func is_officer() -> bool:
	return in_guild() and local_figure() in [GuildRules.Figure.MASTER, GuildRules.Figure.DIRECTOR]

func is_master() -> bool:
	return in_guild() and local_figure() == GuildRules.Figure.MASTER

## Quyền của một thành viên (Bang chủ luôn đủ quyền).
func perms_of(m: Dictionary) -> Array:
	if int(m.get("figure", 0)) == GuildRules.Figure.MASTER:
		return GuildRules.PERMS.duplicate()
	return m.get("perms", GuildRules.default_perms(int(m.get("figure", 0))))

func has_perm(perm: String) -> bool:
	var m := local_member()
	return not m.is_empty() and perm in perms_of(m)

## Trao/thu quyền cho 1 thành viên (chỉ Bang chủ; không đổi quyền của Bang chủ).
func set_perms(member_name: String, perms: Array) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_PERMS, {"name": member_name, "perms": perms})
		return ""
	if not is_master():
		return _say("Chỉ Bang chủ mới phân quyền được.")
	var m := _find(member_name)
	if m.is_empty() or int(m["figure"]) == GuildRules.Figure.MASTER:
		return "Không phân quyền được cho người này."
	var clean := []
	for p in perms:
		if p in GuildRules.PERMS:
			clean.append(p)
	m["perms"] = clean
	_log("%s được phân lại quyền hạn." % member_name, "event")
	_say("Đã phân quyền cho %s." % member_name, true)
	changed.emit()
	return ""

func count_figure(figure: int) -> int:
	var n := 0
	for m in members():
		if int(m["figure"]) == figure:
			n += 1
	return n

func member_cap() -> int:
	return SocialRules.tong_member_cap(int(profile.guild.get("level", 1)))

func is_full() -> bool:
	return members().size() >= member_cap()

func _find(member_name: String) -> Dictionary:
	for m in members():
		if m["name"] == member_name:
			return m
	return {}

# ------------------------------------------------------------------ lập bang
## Các điều kiện lập bang CHƯA đạt — danh sách lời giải thích (rỗng = đủ điều kiện). Thứ tự và ngưỡng theo KPlayerTong::ApplyCreateTong
## (cấp + lãnh đạo từ Tong_Setting.ini VNG; tiền/danh vọng/phúc duyên từ server).
func create_blockers(team: TeamService = null) -> Array[String]:
	var c: Dictionary = SocialRules.tong()["create"]
	var out: Array[String] = []
	if in_guild():
		out.append("Thành viên bang hội không thể lập thêm một bang hội khác!")
	if profile.level < int(c["level"]):
		out.append("Bạn chưa đủ cấp %d." % int(c["level"]))
	if profile.lead_level < int(c["lead_level"]):
		out.append("Bạn chưa đủ cấp lãnh đạo %d (hiện %d)." % [int(c["lead_level"]), profile.lead_level])
	if profile.gold < int(c["money"]):
		out.append("Bạn chưa đủ %d lượng." % int(c["money"]))
	if team != null and team.in_team():
		out.append("Bạn đang trong tổ đội, không thể lập bang!")
	if profile.stall_open or profile.trade_open:
		out.append("Bạn đang bày bán hoặc mở giao dịch, không thể lập bang!")
	if profile.prestige < int(c["repute"]):
		out.append("Bạn chưa đủ %d danh vọng." % int(c["repute"]))
	if profile.fuyuan < int(c["fuyuan"]):
		out.append("Bạn chưa đủ %d phúc duyên." % int(c["fuyuan"]))
	return out

func create(guild_title: String, camp: int, team: TeamService = null) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_CREATE, {"title": guild_title, "camp": camp})
		return ""
	if not GuildRules.is_valid_name(guild_title):
		return _say("Tên bang hội không hợp lệ (1-%d ký tự)." % int(SocialRules.tong()["name_max_length"]))
	if camp not in GuildRules.CAMPS:
		return _say("Phe phái của bang hội không hợp lệ.")
	var blockers := create_blockers(team)
	if not blockers.is_empty():
		return _say(blockers[0])
	if SocialDirectory.guild_names(profile).has(guild_title.strip_edges()):
		return _say("Bang hội đã tồn tại hoặc tên bang bị lỗi, không thể tạo.")
	var cost := int(SocialRules.tong()["create"]["money"])
	profile.gold -= cost
	var now := SecurityLock.now()
	profile.guild = {
		"name": guild_title.strip_edges(), "camp": camp, "level": 1, "exp": 0, "fund": 0, "notice": "", "recruit": true,
		"accept_level": 0, "created_at": now, "members": [], "applies": [], "log": [],
	}
	_add_local(GuildRules.Figure.MASTER)
	profile.camp = camp
	_log("%s lập bang hội." % profile.display_name)
	_say("Thành lập bang hội thành công!", true)
	changed.emit()
	return ""

func _add_local(figure: int) -> void:
	members().append({"name": profile.display_name, "figure": figure, "level": profile.level, "sect": profile.sect_name,
			"joined_at": SecurityLock.now(), "devote": 0, "title": "", "local": true, "mock_id": -1, "perms": GuildRules.default_perms(figure)})

# ------------------------------------------------------------------ vào / rời bang
## Xin vào bang của `master` (bang chủ/trưởng lão giả đang tuyển). Bang giả được dựng từ SocialDirectory.
func apply_join(target: MockPlayer, team: TeamService = null) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_APPLY, {"guild": target.guild_name})
		return ""
	if in_guild():
		return _say("Thành viên bang hội không thể gia nhập bang hội khác!")
	if team != null and team.in_team():
		return _say("Bạn đang trong tổ đội, không thể xin vào bang!")
	var wait := join_cooldown_left()
	if wait > 0:
		return _say("Bạn mới rời bang, còn %d giờ nữa mới xin vào bang khác được." % int(ceil(wait / 3600.0)))
	if target.guild_name == "" or not target.recruit or target.guild_figure == GuildRules.Figure.MEMBER:
		return _say("%s không nhận người vào bang." % target.name)
	var snapshot := SocialDirectory.guild_snapshot(profile, target.guild_name)
	if snapshot.is_empty():
		return _say("Bang hội không tồn tại.")
	var accept_level := int(snapshot.get("accept_level", 0))
	var auto := accept_level > 0 and profile.level >= accept_level
	if not auto and rng.randf() > target.invite_accept_rate:
		return _say("%s từ chối cho bạn vào bang." % target.name)
	if snapshot["members"].size() >= SocialRules.tong_member_cap(int(snapshot["level"])):
		return _say("Bang hội đã đủ thành viên.")
	profile.guild = snapshot
	_add_local(GuildRules.Figure.MEMBER)
	profile.camp = int(snapshot["camp"])
	_log("%s gia nhập bang hội." % profile.display_name)
	_say("Bạn đã gia nhập bang hội %s." % guild_name(), true)
	changed.emit()
	return ""

## Quan chức mời 1 người chơi giả vào bang.
func invite(m: MockPlayer) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_INVITE, {"eid": m.id})
		return ""
	if not is_officer():
		return _say("Chỉ Bang chủ/Trưởng lão mới mời người vào bang.")
	if is_full():
		return _say("Bang hội đã đủ %d thành viên." % member_cap())
	if m.guild_name != "":
		return _say("%s đã thuộc một bang hội." % m.name)
	if not _find(m.name).is_empty():
		return _say("%s đã ở trong bang." % m.name)
	if m.team_tag != "":
		return _say("%s đang trong tổ đội." % m.name)
	if rng.randf() > m.invite_accept_rate:
		return _say("%s từ chối lời mời vào bang." % m.name)
	_enroll(m)
	return ""

func _enroll(m: MockPlayer) -> void:
	m.guild_name = guild_name()
	m.guild_figure = GuildRules.Figure.MEMBER
	members().append({"name": m.name, "figure": GuildRules.Figure.MEMBER, "level": m.level, "sect": m.sect_name,
			"joined_at": SecurityLock.now(), "devote": 0, "title": "", "local": false, "mock_id": m.id, "perms": []})
	_log("%s gia nhập bang hội." % m.name)
	_say("%s đã gia nhập bang hội." % m.name, true)
	changed.emit()

func accept_applicant(ap_name: String) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_ACCEPT, {"name": ap_name})
		return ""
	if not is_officer():
		return _say("Chỉ Bang chủ/Trưởng lão mới nhận người.")
	var found := {}
	for a in applies():
		if a["name"] == ap_name:
			found = a
	if found.is_empty():
		return "Người này không còn trong danh sách xin vào."
	if is_full():
		return _say("Bang hội đã đủ thành viên.")
	applies().erase(found)
	var m := SocialDirectory.find_by_id(profile, int(found.get("mock_id", -1)))
	if m != null and m.guild_name == "":
		_enroll(m)
	else:
		changed.emit()
		return _say("Người này đã gia nhập nơi khác.")
	return ""

func reject_applicant(ap_name: String) -> void:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_REJECT, {"name": ap_name})
		return
	for a in applies().duplicate():
		if a["name"] == ap_name:
			applies().erase(a)
	changed.emit()

## Người chơi giả xin vào bang của mình (chỉ khi đang tuyển người). Trả về tên người vừa xin hoặc "".
func simulate_applicants() -> String:
	if NetClient.is_in_world():
		return ""   ## người xin vào là người thật
	if not in_guild() or not is_officer() or not bool(profile.guild.get("recruit", false)) or is_full():
		return ""
	if rng.randf() > 0.35:
		return ""
	var accept_level := int(profile.guild.get("accept_level", 0))
	var reject_level := int(profile.guild.get("reject_level", 0))
	for m in SocialDirectory.players(profile):
		if m.guild_name != "" or m.team_tag != "" or m.level < reject_level:
			continue        ## "Từ chối gamer dưới N cấp xin nhập bang"
		var queued := false
		for a in applies():
			if a["name"] == m.name:
				queued = true
		if queued or not _find(m.name).is_empty():
			continue
		if accept_level > 0 and m.level > accept_level:
			_enroll(m)       ## "Cao hơn N cấp tự động nhập bang"
			return m.name
		applies().append({"name": m.name, "level": m.level, "sect": m.sect_name, "mock_id": m.id})
		message.emit("%s (cấp %d) xin vào bang." % [m.name, m.level], true)
		changed.emit()
		return m.name
	return ""

func join_cooldown_left() -> int:
	return maxi(0, profile.guild_join_after - SecurityLock.now())

## Rời bang: Bang chủ không rời được (phải nhường chức); người khác trả phí rời bang (LeavMn lượng + LeaveRp danh vọng) và phải chờ LeaveTm
## giây mới xin vào bang khác được.
func leave() -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_LEAVE, {})
		return ""
	if not in_guild():
		return "Bạn chưa có bang hội."
	if is_master():
		return _say("Bang chủ phải nhường chức cho người khác trước khi rời bang.")
	var fee: Dictionary = SocialRules.tong()["leave"]
	if profile.gold < int(fee["money"]):
		return _say("Cần %d lượng phí rời bang." % int(fee["money"]))
	if profile.prestige < int(fee["repute"]):
		return _say("Cần %d danh vọng để rời bang." % int(fee["repute"]))
	profile.gold -= int(fee["money"])
	profile.prestige -= int(fee["repute"])
	_release_mock(profile.display_name)
	profile.guild = {}
	profile.camp = -1
	profile.guild_join_after = SecurityLock.now() + int(fee["seconds"])
	_say("Bạn đã rời bang hội.", true)
	changed.emit()
	return ""

func _release_mock(member_name: String) -> void:
	var m := SocialDirectory.find_by_name(profile, member_name)
	if m != null:
		m.guild_name = ""
		m.guild_figure = GuildRules.Figure.MEMBER

## Giải tán bang (chỉ Bang chủ). Các thành viên giả được thả.
func disband() -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_DISBAND, {})
		return ""
	if not is_master():
		return _say("Chỉ Bang chủ mới giải tán được bang hội.")
	for m in members():
		_release_mock(str(m["name"]))
	profile.guild = {}
	profile.camp = -1
	_say("Bang hội đã giải tán.", true)
	changed.emit()
	return ""

# ------------------------------------------------------------------ chức vụ / quản lý
## Bổ nhiệm — KPlayerTong::CheckInstate gốc: ai được đổi chức ai, và giới hạn 7 Trưởng lão / 56 Đội trưởng.
func instate(member_name: String, new_figure: int) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_INSTATE, {"name": member_name, "figure": new_figure})
		return ""
	if not is_officer() or not has_perm(GuildRules.PERM_INSTATE):
		return _say("Bạn không có quyền bổ nhiệm.")
	var m := _find(member_name)
	if m.is_empty():
		return "Không tìm thấy thành viên."
	var cur := int(m["figure"])
	if not GuildRules.can_instate(local_figure(), cur, new_figure):
		return _say("Bạn không có quyền đổi %s thành %s." % [GuildRules.figure_name(cur), GuildRules.figure_name(new_figure)])
	if count_figure(new_figure) >= GuildRules.max_for_figure(new_figure):
		return _say("Số %s đã đạt tối đa (%d)." % [GuildRules.figure_name(new_figure), GuildRules.max_for_figure(new_figure)])
	m["figure"] = new_figure
	m["perms"] = GuildRules.default_perms(new_figure)
	var mock := SocialDirectory.find_by_name(profile, member_name)
	if mock != null:
		mock.guild_figure = new_figure
	_log("%s được bổ nhiệm làm %s." % [member_name, GuildRules.figure_name(new_figure)], "event")
	_say("%s trở thành %s." % [member_name, GuildRules.figure_name(new_figure)], true)
	changed.emit()
	return ""

func kick(member_name: String) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_KICK, {"name": member_name})
		return ""
	if not is_officer() or not has_perm(GuildRules.PERM_KICK):
		return _say("Bạn không có quyền khai trừ.")
	var m := _find(member_name)
	if m.is_empty() or m.get("local", false):
		return "Không khai trừ được người này."
	if not GuildRules.can_kick(local_figure(), int(m["figure"])):
		return _say("Bạn không có quyền khai trừ %s." % GuildRules.figure_name(int(m["figure"])))
	members().erase(m)
	_release_mock(member_name)
	_log("%s bị khai trừ khỏi bang." % member_name, "event")
	_say("%s đã bị khai trừ khỏi bang." % member_name, true)
	changed.emit()
	return ""

## Nhường chức Bang chủ cho một Trưởng lão (người nhường xuống làm Trưởng lão).
func change_master(member_name: String) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_MASTER, {"name": member_name})
		return ""
	if not is_master():
		return _say("Chỉ Bang chủ mới nhường chức được.")
	var m := _find(member_name)
	if m.is_empty() or m.get("local", false):
		return "Không tìm thấy thành viên."
	if int(m["figure"]) != GuildRules.Figure.DIRECTOR:
		return _say("Chỉ nhường chức cho Trưởng lão.")
	m["figure"] = GuildRules.Figure.MASTER
	local_member()["figure"] = GuildRules.Figure.DIRECTOR
	var mock := SocialDirectory.find_by_name(profile, member_name)
	if mock != null:
		mock.guild_figure = GuildRules.Figure.MASTER
	_log("%s nhường chức Bang chủ cho %s." % [profile.display_name, member_name])
	_say("Đã nhường chức Bang chủ cho %s." % member_name, true)
	changed.emit()
	return ""

func set_notice(text: String) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_NOTICE, {"text": text})
		return ""
	if not has_perm(GuildRules.PERM_LOG):
		return _say("Bạn không có quyền sửa công cáo bang hội.")
	profile.guild["notice"] = text.strip_edges().left(MAX_NOTICE)
	changed.emit()
	return ""

## "Sự việc": thêm 1 dòng vào nhật ký sự kiện của bang (cần quyền Nhật ký).
func add_event(text: String) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_EVENT, {"text": text})
		return ""
	if not has_perm(GuildRules.PERM_LOG):
		return _say("Bạn không có quyền ghi nhật ký bang hội.")
	var t := text.strip_edges().left(80)
	if t == "":
		return "Nội dung trống."
	_log(t, "event")
	changed.emit()
	return ""

## Đổi tên bang (cần quyền Đổi tên).
func rename(new_name: String) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_RENAME, {"name": new_name})
		return ""
	if not in_guild() or not has_perm(GuildRules.PERM_RENAME):
		return _say("Bạn không có quyền đổi tên bang hội.")
	if not GuildRules.is_valid_name(new_name):
		return _say("Tên bang hội không hợp lệ.")
	var n := new_name.strip_edges()
	if n != guild_name() and SocialDirectory.guild_names(profile).has(n):
		return _say("Tên bang hội đã tồn tại.")
	var old := guild_name()
	profile.guild["name"] = n
	for m in SocialDirectory.guild_members(profile, old):
		m.guild_name = n
	_log("Bang hội đổi tên từ %s thành %s." % [old, n])
	_say("Đã đổi tên bang hội.", true)
	changed.emit()
	return ""

## Thông tin CHIÊU MỘ (màn "Chiêu Mộ", nút "Bảo lưu và công bố tin"): khuynh hướng, hoạt động chính, lời nhắn chào, cấp tự nhận, cấp từ chối.
func set_recruit_info(tendency: String, activity: String, message_text: String, accept_level: int, reject_level: int) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_RECRUIT_INFO, {"tendency": tendency, "activity": activity, "msg": message_text, "accept_level": accept_level, "reject_level": reject_level})
		return ""
	if not is_officer():
		return _say("Chỉ Bang chủ/Trưởng lão mới công bố tin chiêu mộ.")
	profile.guild["tendency"] = tendency
	profile.guild["activity"] = activity
	profile.guild["recruit_msg"] = message_text.strip_edges().left(MAX_NOTICE)
	profile.guild["accept_level"] = clampi(accept_level, 0, 150)
	profile.guild["reject_level"] = clampi(reject_level, 0, 150)
	_say("Đã lưu và công bố tin chiêu mộ.", true)
	changed.emit()
	return ""

func set_recruit(value: bool) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_RECRUIT, {"value": value})
		return ""
	if not is_officer():
		return _say("Chỉ Bang chủ/Trưởng lão mới đổi được.")
	profile.guild["recruit"] = value
	changed.emit()
	return ""

## Cấp tối thiểu để TỰ ĐỘNG được nhận khi xin vào (0 = luôn phải chờ duyệt) — "tham số tuyển người" gốc.
func set_accept_level(level: int) -> String:
	if not is_officer():
		return _say("Chỉ Bang chủ/Trưởng lão mới đổi được.")
	profile.guild["accept_level"] = clampi(level, 0, 150)
	changed.emit()
	return ""

func set_title(member_name: String, title: String) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_TITLE, {"name": member_name, "title": title})
		return ""
	if not is_officer():
		return _say("Chỉ Bang chủ/Trưởng lão mới đặt danh hiệu.")
	var m := _find(member_name)
	if m.is_empty():
		return "Không tìm thấy thành viên."
	m["title"] = title.strip_edges().left(MAX_TITLE)
	changed.emit()
	return ""

# ------------------------------------------------------------------ quỹ bang / cấp bang / thử thách
## Quyên góp tiền vào quỹ bang (cộng điểm cống hiến bằng số tiền / 1000).
func donate(amount: int) -> String:
	if NetClient.is_in_world():
		NetClient.send_guild(GuildServer.G_DONATE, {"amount": amount})
		return ""
	if not in_guild():
		return "Bạn chưa có bang hội."
	if amount <= 0 or profile.gold < amount:
		return _say("Số tiền không hợp lệ hoặc không đủ.")
	profile.gold -= amount
	profile.guild["fund"] = int(profile.guild["fund"]) + amount
	local_member()["devote"] = int(local_member()["devote"]) + amount / 1000
	_log("%s quyên góp %d lượng vào quỹ bang." % [profile.display_name, amount], "event")
	_say("Đã quyên góp %d lượng." % amount, true)
	changed.emit()
	return ""

## Một chu kỳ [MoneyToExp] (mỗi TimeLong = 750 giây): quỹ >= MoneyLimit thì trừ NormalMoney, cộng NormalExp kinh nghiệm bang; thiếu thì trừ
## LimitMoney / LimitExp (cả hai bằng 0 ở VNG nên không đổi). Lên cấp bang theo bảng [LevelExp]. Trả về số chu kỳ đã xử lý.
func process_fund(elapsed_seconds: int) -> int:
	if not in_guild():
		return 0
	var cfg: Dictionary = SocialRules.tong()["money_to_exp"]
	var period := maxi(1, int(cfg["TimeLong"]))
	var last := int(profile.guild.get("fund_tick_at", int(profile.guild.get("created_at", SecurityLock.now()))))
	var now := last + elapsed_seconds
	var cycles := (now - last) / period
	for i in cycles:
		var fund := int(profile.guild["fund"])
		if fund >= int(cfg["MoneyLimit"]):
			var extra := maxi(0, members().size() - int(cfg["NormalMemberLimit"])) * int(cfg["NormalMemberLimitMoney"])
			profile.guild["fund"] = maxi(0, fund - int(cfg["NormalMoney"]) - extra)
			profile.guild["exp"] = int(profile.guild["exp"]) + int(cfg["NormalExp"])
		else:
			profile.guild["fund"] = maxi(0, fund - int(cfg["LimitMoney"]))
			profile.guild["exp"] = maxi(0, int(profile.guild["exp"]) - int(cfg["LimitExp"]))
		_update_level()
	profile.guild["fund_tick_at"] = last + cycles * period
	if cycles > 0:
		changed.emit()
	return cycles

func _update_level() -> void:
	var max_level: int = SocialRules.tong()["levels"].size()
	while int(profile.guild["level"]) < max_level and int(profile.guild["exp"]) >= SocialRules.tong_exp_for_level(int(profile.guild["level"]) + 1):
		profile.guild["level"] = int(profile.guild["level"]) + 1
		_log("Bang hội lên cấp %d." % int(profile.guild["level"]))

## Thời gian thử thách của bang mới (TongTest): phải đạt MinMember thành viên trong TimeLong giây. Trả về số giây còn lại (-1 nếu đã qua
## thử thách).
func trial_seconds_left(now: int = -1) -> int:
	if not in_guild():
		return -1
	var t: Dictionary = SocialRules.tong()["test_period"]
	if members().size() >= int(t["min_member"]) or bool(profile.guild.get("trial_done", false)):
		profile.guild["trial_done"] = true
		return -1
	var at := now if now >= 0 else SecurityLock.now()
	return maxi(0, int(profile.guild["created_at"]) + int(t["seconds"]) - at)

## Hết thời gian thử thách mà chưa đủ người thì bang bị giải tán. Trả về true nếu vừa giải tán.
func check_trial(now: int = -1) -> bool:
	if trial_seconds_left(now) == 0:
		for m in members():
			_release_mock(str(m["name"]))
		profile.guild = {}
		profile.camp = -1
		_say("Bang hội không đủ thành viên trong thời gian thử thách nên đã giải tán.")
		changed.emit()
		return true
	return false

extends RefCounted
class_name TeamService
## TỔ ĐỘI — theo KPlayerTeam / KTeam của VLTK gốc (xem docs/vltk_social_systems_reference.md):
##   - Tạo đội: phải đang cho phép tổ đội (m_bCreatTeamFlag), chưa ở trong đội. Đội mới MỞ (nhận người).
##   - Số người tối đa = 1 (đội trưởng) + min(7, số_người_theo_cấp_lãnh_đạo - 1) (KTeam::CalcCaptainPower, bảng [LevelUnionNum] VNG).
##   - Mời: chỉ đội trưởng, đội phải MỞ, đối phương phải cho phép tổ đội; đối phương đồng ý/từ chối. Xin vào: gửi lời xin tới đội trưởng
##     (danh sách xin tối đa 32), đội trưởng nhận/từ chối. Người đã trong đội khác phải rời đội cũ trước.
##   - Người đang ở phe khác "Tân thủ" không vào được đội có đội trưởng "Tân thủ" (KTeam::CheckAddCondition).
##   - Rời đội: thành viên rời thì đội còn; ĐỘI TRƯỞNG rời = giải tán cả đội. Đội trưởng được đuổi người, đổi đội trưởng, mở/đóng đội,
##     chọn cách nhặt đồ.
##   - Nhặt đồ (m_nModePick): 0 tự nhặt, 1 nhặt tự do, 2 đội trưởng nhặt, 3 nhặt luân phiên.
##   - Chia kinh nghiệm: ExpRules (cự ly 768, k = 100 + 15 * số người).
## Trạng thái nằm trên thể hiện (online: server là nơi giữ đội, lớp này chỉ là ảnh chụp phía người chơi).

signal changed
signal message(text: String, good: bool)

enum Pick { SELF, FREE, CAPTAIN, ALTERNATE }
const PICK_NAMES := ["Tự nhặt", "Nhặt tự do", "Đội trưởng nhặt", "Nhặt luân phiên"]
const MAX_APPLY_LIST := 32

class Member:
	var id: int = 0
	var name: String = ""
	var level: int = 1
	var sect_name: String = ""
	var camp: int = Camp.Type.BEGIN
	var lead_level: int = 0
	var is_local: bool = false
	var mock: MockPlayer = null
	static func from_mock(m: MockPlayer) -> Member:
		var x := Member.new()
		x.id = m.id
		x.name = m.name
		x.level = m.level
		x.sect_name = m.sect_name
		x.camp = m.camp
		x.lead_level = m.lead_level
		x.mock = m
		return x
	static func from_profile(p: PlayerProfile) -> Member:
		var x := Member.new()
		x.id = 1
		x.name = p.display_name
		x.level = p.level
		x.sect_name = p.sect_name
		x.camp = p.get_current_camp()
		x.lead_level = p.lead_level
		x.is_local = true
		return x

var profile: PlayerProfile
var captain: Member = null
var members: Array[Member] = []           ## KHÔNG gồm đội trưởng
var open := true
var pick_mode: int = Pick.FREE
var pk_follow := false
var allow_create := true                  ## cho phép tổ đội (m_bCreatTeamFlag)
var auto_refuse_invite := false
var applicants: Array[MockPlayer] = []
var rng := RandomNumberGenerator.new()
var _turn := 0                            ## chỉ số người đang tới lượt nhặt (0 = đội trưởng, i+1 = members[i])

func _init(p: PlayerProfile) -> void:
	profile = p
	rng.randomize()

func in_team() -> bool:
	return captain != null

func is_captain() -> bool:
	return captain != null and captain.is_local

func total() -> int:
	return 0 if captain == null else 1 + members.size()

func capacity() -> int:
	return 0 if captain == null else 1 + SocialRules.team_member_cap(captain.lead_level)

func is_full() -> bool:
	return total() >= capacity()

func all_members() -> Array[Member]:
	var out: Array[Member] = []
	if captain:
		out.append(captain)
		out.append_array(members)
	return out

func _say(text: String, good := false) -> String:
	message.emit(text, good)
	return text

func _find_member(id: int) -> Member:
	for m in all_members():
		if m.id == id:
			return m
	return null

func _in_team_name(name: String) -> bool:
	for m in all_members():
		if m.name == name:
			return true
	return false

# ------------------------------------------------------------------ tạo / giải tán
## Tạo tổ đội mới (mình là đội trưởng). "" nếu thành công.
func create_team() -> String:
	if not allow_create:
		return _say("Bạn đang tắt chức năng tổ đội.")
	if in_team():
		return _say("Bạn đang ở trong một tổ đội.")
	captain = Member.from_profile(profile)
	captain.lead_level = profile.lead_level
	members.clear()
	applicants.clear()
	open = true
	_turn = 0
	profile.trade_open = false          ## gốc: tạo đội thì thôi trạng thái mở giao dịch
	_say("Tạo tổ đội thành công.", true)
	changed.emit()
	return ""

func dismiss() -> String:
	if not is_captain():
		return _say("Chỉ đội trưởng mới giải tán được tổ đội.")
	_clear()
	_say("Tổ đội đã giải tán.", true)
	return ""

func _clear() -> void:
	for m in all_members():
		if m.mock:
			m.mock.team_tag = ""
	captain = null
	members.clear()
	applicants.clear()
	changed.emit()

## Rời đội: đội viên rời thì đội còn lại; đội trưởng rời thì giải tán cả đội (KTeam::DeleteMember gốc).
func leave() -> String:
	if not in_team():
		return "Bạn chưa có tổ đội."
	if is_captain():
		_clear()
		_say("Đội trưởng rời đội — tổ đội giải tán.", true)
	else:
		_clear()
		_say("Bạn đã rời tổ đội.", true)
	return ""

# ------------------------------------------------------------------ mời / xin vào
func _check_join_condition(m: MockPlayer) -> String:
	if m.team_tag != "":
		return "%s đã ở trong một tổ đội khác." % m.name
	if m.camp != Camp.Type.BEGIN and captain.camp == Camp.Type.BEGIN:
		return "Không thể đưa %s vào đội của người tân thủ." % m.name
	return ""

func _add_member(m: MockPlayer) -> void:
	members.append(Member.from_mock(m))
	m.team_tag = "t"
	changed.emit()

## Đội trưởng mời một người chơi giả. "" nếu họ đồng ý và vào đội, hoặc lời giải thích vì sao không.
func invite(m: MockPlayer) -> String:
	if not is_captain():
		return _say("Chỉ đội trưởng mới mời được người vào đội.")
	if not open:
		return _say("Đội đang đóng, hãy mở đội để mời người.")
	if is_full():
		return _say("Đội đã đủ %d người (cấp lãnh đạo %d)." % [capacity(), captain.lead_level])
	var err := _check_join_condition(m)
	if err != "":
		return _say(err)
	if rng.randf() > m.invite_accept_rate:
		return _say("%s từ chối lời mời vào đội." % m.name)
	_add_member(m)
	if is_full():
		open = false                    ## gốc: đầy người thì tự đóng đội
	_say("%s đã gia nhập tổ đội." % m.name, true)
	return ""

## Mình xin vào đội của một người chơi giả (họ làm đội trưởng). Đội giả được dựng tại chỗ với vài đồng đội.
func apply_to(captain_mock: MockPlayer) -> String:
	if in_team():
		return _say("Bạn đang ở trong một tổ đội.")
	if not allow_create:
		return _say("Bạn đang tắt chức năng tổ đội.")
	if captain_mock.team_tag != "":
		return _say("%s không phải đội trưởng đang nhận người." % captain_mock.name)
	var size_cap := 1 + SocialRules.team_member_cap(captain_mock.lead_level)
	if size_cap < 2:
		return _say("%s chưa đủ cấp lãnh đạo để lập đội." % captain_mock.name)
	if captain_mock.camp == Camp.Type.BEGIN and profile.get_current_camp() != Camp.Type.BEGIN:
		return _say("Không thể vào đội của người tân thủ.")
	if rng.randf() > captain_mock.invite_accept_rate:
		return _say("%s từ chối cho bạn vào đội." % captain_mock.name)
	captain = Member.from_mock(captain_mock)
	captain_mock.team_tag = "c"
	members.clear()
	var fillers := 0
	for other in SocialDirectory.players(profile):
		if fillers >= mini(2, size_cap - 2):
			break
		if other != captain_mock and other.team_tag == "" and other.guild_name == captain_mock.guild_name:
			_add_member(other)
			fillers += 1
	members.append(Member.from_profile(profile))
	open = true
	_turn = 0
	_say("Bạn đã gia nhập tổ đội của %s." % captain_mock.name, true)
	changed.emit()
	return ""

## Mô phỏng người chơi giả xin vào đội của mình (gọi theo nhịp từ giao diện). Trả về người vừa xin hoặc null.
func simulate_applicants() -> MockPlayer:
	if not is_captain() or not open or is_full() or applicants.size() >= MAX_APPLY_LIST:
		return null
	if rng.randf() > 0.4:
		return null
	for m in SocialDirectory.players(profile):
		if m.team_tag == "" and not applicants.has(m) and _check_join_condition(m) == "" and not _in_team_name(m.name):
			applicants.append(m)
			message.emit("%s (cấp %d) xin vào đội." % [m.name, m.level], true)
			changed.emit()
			return m
	return null

func accept_applicant(m: MockPlayer) -> String:
	if not is_captain():
		return _say("Chỉ đội trưởng mới nhận người.")
	if not applicants.has(m):
		return "Người này không còn trong danh sách xin vào."
	if is_full():
		return _say("Đội đã đủ người.")
	var err := _check_join_condition(m)
	if err != "":
		applicants.erase(m)
		changed.emit()
		return _say(err)
	applicants.erase(m)
	_add_member(m)
	if is_full():
		open = false
	_say("%s đã gia nhập tổ đội." % m.name, true)
	return ""

func reject_applicant(m: MockPlayer) -> void:
	applicants.erase(m)
	changed.emit()

# ------------------------------------------------------------------ quản lý
func kick(member: Member) -> String:
	if not is_captain():
		return _say("Chỉ đội trưởng mới đuổi được người.")
	if member == captain or not members.has(member):
		return _say("Không đuổi được người này.")
	if member.mock:
		member.mock.team_tag = ""
	members.erase(member)
	open = not is_full()
	_say("%s đã bị mời ra khỏi tổ đội." % member.name, true)
	changed.emit()
	return ""

## Đổi đội trưởng sang một thành viên (chỉ đội trưởng). Đội trưởng mới phải đủ cấp lãnh đạo chứa số người hiện có.
func change_captain(member: Member) -> String:
	if not is_captain():
		return _say("Chỉ đội trưởng mới đổi được đội trưởng.")
	if not members.has(member):
		return _say("Chọn một thành viên trong đội.")
	if total() > 1 + SocialRules.team_member_cap(member.lead_level):
		return _say("%s chưa đủ cấp lãnh đạo để dẫn %d người." % [member.name, total()])
	members.erase(member)
	members.append(captain)
	captain = member
	_say("%s trở thành đội trưởng." % member.name, true)
	changed.emit()
	return ""

func set_open(value: bool) -> String:
	if not is_captain():
		return _say("Chỉ đội trưởng mới đóng/mở đội.")
	if value and is_full():
		return _say("Đội đã đủ người, không mở được.")
	open = value
	changed.emit()
	return ""

func set_pick_mode(mode: int) -> String:
	if not is_captain():
		return _say("Chỉ đội trưởng mới đổi cách nhặt đồ.")
	pick_mode = clampi(mode, 0, PICK_NAMES.size() - 1)
	_turn = 0
	changed.emit()
	return ""

# ------------------------------------------------------------------ nhặt đồ
## Mình có được nhặt món rơi (do đồng đội/quái) lúc này không — KTeam::CheckIn gốc.
func can_local_pick() -> bool:
	if not in_team():
		return true
	match pick_mode:
		Pick.CAPTAIN:
			return is_captain()
		Pick.ALTERNATE:
			return all_members()[_turn % total()].is_local
	return true       ## SELF / FREE

## Gọi sau khi mình nhặt xong 1 món: lượt chuyển cho người kế (chế độ luân phiên).
func advance_turn() -> void:
	if in_team() and pick_mode == Pick.ALTERNATE:
		_turn = (_turn + 1) % total()

# ------------------------------------------------------------------ kinh nghiệm
## Quái cấp `target_level` chết, kinh nghiệm gốc `exp` — trả về kinh nghiệm MÌNH nhận (đã chia đội + trừ chênh cấp) và cộng kinh nghiệm
## lãnh đạo nếu mình là đội trưởng. `in_range` = tên đồng đội đang trong tầm chia (rỗng = tất cả trong tầm).
func local_exp_for_kill(exp: int, target_level: int, in_range: Array = []) -> int:
	if not in_team():
		return ExpRules.self_exp(profile.level, target_level, exp)
	var present: Array[Member] = []
	for m in all_members():
		if m.is_local or in_range.is_empty() or in_range.has(m.name):
			present.append(m)
	var levels := []
	for m in present:
		levels.append(m.level)
	var shares := ExpRules.team_shares(exp, levels)
	var mine := 0
	for i in present.size():
		if present[i].is_local:
			mine = ExpRules.self_exp(profile.level, target_level, int(shares[i]))
	if is_captain():
		ExpRules.add_lead_exp(profile, ExpRules.lead_exp(exp, levels, captain.level))
	return mine

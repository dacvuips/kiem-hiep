extends RefCounted
class_name SocialHub
## ĐIỂM TRUY CẬP DUY NHẤT tới trạng thái xã hội ĐANG CHẠY của 1 nhân vật: tổ đội, bang hội, phiên giao dịch hiện tại, nhật ký bày bán.
## Mỗi PlayerProfile có đúng 1 SocialHub (tạo lười). Trạng thái lâu dài (rương, bang, khoá, giá bán) nằm trong PlayerProfile và được lưu;
## ở đây chỉ giữ cái chạy tạm (tổ đội, giao dịch đang mở). Online: các dịch vụ bên trong đổi sang gọi server, giao diện không phải đổi.

signal notice(text: String, good: bool)      ## thông báo ngắn cho người chơi (khách mua hàng, có người xin vào đội/bang...)

static var _hubs: Dictionary = {}

var profile: PlayerProfile
var team: TeamService
var guild: GuildService
var trade: TradeSession = null
var stall_log: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _stall_clock := 0.0
var _team_clock := 0.0
var _guild_clock := 0.0
var _fund_clock := 0.0

static func of(p: PlayerProfile) -> SocialHub:
	var key := p.get_instance_id()
	if not _hubs.has(key) or not is_instance_valid(_hubs[key].profile):
		_hubs[key] = SocialHub.new(p)
	return _hubs[key]

static func forget(p: PlayerProfile) -> void:
	_hubs.erase(p.get_instance_id())

func _init(p: PlayerProfile) -> void:
	profile = p
	_rng.randomize()
	team = TeamService.new(p)
	guild = GuildService.new(p)
	for svc in [team, guild]:
		svc.message.connect(func(text: String, good: bool) -> void: notice.emit(text, good))

func start_trade(partner: MockPlayer) -> String:
	if trade != null and trade.active:
		return "Bạn đang trong một giao dịch."
	if NetClient.is_in_world():
		## Online: xin server; đối phương đồng ý thì server mở giao dịch (NetWorldSync mở cửa sổ).
		NetClient.send_trade_request(partner.id)
		return "online"
	var err := []
	var s := TradeSession.request(profile, partner, err)
	if s == null:
		return str(err[0]) if not err.is_empty() else "Không giao dịch được."
	trade = s
	s.finished.connect(func(_ok: bool, msg: String) -> void: notice.emit(msg, _ok))
	return ""

## Giao dịch theo ID nhân vật (tab "Giao dịch" của Chợ): không cần đứng gần / đối phương mở giao dịch — bên kia nhận hộp hỏi đồng ý.
## Online: ID = mã nhân vật trên máy chủ, server gửi lời mời, đồng ý thì mở cửa sổ giao dịch. Offline: ID người chơi giả.
func start_trade_by_id(player_id: int) -> String:
	if trade != null and trade.active:
		return "Bạn đang trong một giao dịch."
	if player_id <= 0:
		return "ID không hợp lệ."
	if NetClient.is_in_world():
		if player_id == SaveManager.online_character_id:
			return "Không thể giao dịch với chính mình."
		NetClient.send_trade_request_id(player_id)
		return "online"
	var partner := SocialDirectory.find_by_id(profile, player_id)
	if partner == null:
		return "Không tìm thấy người chơi có ID %d (hoặc đang không trực tuyến)." % player_id
	partner.trade_open = true   ## mời theo ID: đối phương tự quyết đồng ý hay không (invite_accept_rate)
	return start_trade(partner)

## Nhịp chạy nền (gọi mỗi frame từ SocialTicker hoặc cửa sổ đang mở): khách giả mua hàng, người xin vào đội/bang, quỹ bang, thử thách bang.
func tick(delta: float) -> void:
	if trade != null and trade.active:
		trade.tick(delta)
	if NetClient.is_in_world():
		return   ## online: khách mua hàng / người xin vào là người thật (server báo) — không giả lập
	for line in OfflineMarket.tick(profile, delta, _rng):
		notice.emit(line, true)
	if profile.stall_open:
		_stall_clock += delta
		if _stall_clock >= 6.0:
			_stall_clock = 0.0
			for sale in StallService.simulate_customers(profile, _rng):
				var line := "%s mua %s với giá %d lượng." % [sale["buyer"], sale["item_name"], sale["price"]]
				stall_log.append(line)
				if stall_log.size() > 30:
					stall_log.pop_front()
				notice.emit(line, true)
	if team.is_captain():
		_team_clock += delta
		if _team_clock >= 9.0:
			_team_clock = 0.0
			team.simulate_applicants()
	if guild.in_guild():
		_guild_clock += delta
		if _guild_clock >= 8.0:
			_guild_clock = 0.0
			guild.simulate_applicants()
			guild.check_trial()
		_fund_clock += delta
		if _fund_clock >= 30.0:
			guild.process_fund(int(_fund_clock))
			_fund_clock = 0.0

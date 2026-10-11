extends RefCounted
class_name SocialDirectory
## DANH SÁCH NGƯỜI CHƠI GIẢ quanh nhân vật (xem MockPlayer). Sinh cố định theo tên nhân vật (cùng nhân vật luôn gặp cùng những người)
## và giữ trong phiên chơi. Online: thay hàm players() bằng dữ liệu server — mọi nơi khác chỉ gọi hàm ở đây.

const FAMILY := ["Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Vũ", "Đặng", "Bùi", "Đỗ", "Ngô", "Dương", "Lý", "Mộ Dung", "Đoàn", "Tiêu", "Lâm"]
const GIVEN := ["Vô Kỵ", "Thanh Phong", "Hạo Thiên", "Tuyết Nhi", "Minh Nguyệt", "Kiếm Tâm", "Bách Lý", "Phi Vân", "Chấn Đông", "Hàn Băng",
		"Nhược Hy", "Thiên Ân", "Long Vĩ", "Dạ Lan", "Tử Yên", "Cuồng Đao", "Ngọc Hà", "Phong Lôi", "Mặc Vũ", "Lăng Ba"]
const GUILDS := [
	{"name": "Thiên Long Bang", "camp": Camp.Type.JUSTICE},
	{"name": "Hắc Phong Đường", "camp": Camp.Type.EVIL},
	{"name": "Bạch Vân Các", "camp": Camp.Type.BALANCE},
]
const PLAYER_COUNT := 14

static var _players: Array[MockPlayer] = []
static var _owner_key: String = ""

static func reset() -> void:
	_players.clear()
	_owner_key = ""

static func players(profile: PlayerProfile) -> Array[MockPlayer]:
	if NetClient.is_in_world() and NetWorldSync.current != null:
		return NetWorldSync.current.nearby_players()
	var key := "%s|%d" % [profile.display_name, profile.level / 10]
	if _owner_key != key or _players.is_empty():
		_owner_key = key
		_players = _generate(profile)
	return _players

static func find_by_name(profile: PlayerProfile, player_name: String) -> MockPlayer:
	for p in players(profile):
		if p.name == player_name:
			return p
	return null

static func find_by_id(profile: PlayerProfile, player_id: int) -> MockPlayer:
	for p in players(profile):
		if p.id == player_id:
			return p
	return null

static func guild_members(profile: PlayerProfile, guild_name: String) -> Array[MockPlayer]:
	var out: Array[MockPlayer] = []
	for p in players(profile):
		if p.guild_name == guild_name:
			out.append(p)
	return out

static func _generate(profile: PlayerProfile) -> Array[MockPlayer]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(profile.display_name) ^ 0x5EED
	var sects := SectRegistry.load_all()
	var out: Array[MockPlayer] = []
	var used := {}
	for i in PLAYER_COUNT:
		var p := MockPlayer.new()
		p.id = 1000 + i
		var nm := ""
		while nm == "" or used.has(nm):
			nm = "%s %s" % [FAMILY[rng.randi() % FAMILY.size()], GIVEN[rng.randi() % GIVEN.size()]]
		used[nm] = true
		p.name = nm
		p.level = clampi(profile.level + rng.randi_range(-12, 25), 1, 150)
		var sect: SectDefinition = sects[rng.randi() % sects.size()]
		p.sect_id = sect.id
		p.sect_name = sect.sect_name
		p.female = rng.randf() < 0.5
		var need := PlayerProfile.required_gender(int(sect.element))
		if need >= 0:
			p.female = need == PlayerProfile.Gender.FEMALE
		p.camp = Camp.default_for_sect(sect)
		p.lead_level = clampi(p.level / 4 + rng.randi_range(-3, 3), 0, 60)
		p.fuyuan = rng.randi_range(0, 900)
		p.repute = rng.randi_range(0, 700)
		p.gold = rng.randi_range(20_000, 8_000_000)
		p.trade_open = rng.randf() < 0.85
		p.invite_accept_rate = rng.randf_range(0.55, 0.95)
		p.haggle = rng.randf_range(0.75, 1.0)
		for k in rng.randi_range(4, 9):
			p.bag.add_item(ItemGenerator.random_equipment(p.level))
		_dress(p, rng)
		out.append(p)
	## 3 bang giả: mỗi bang 1 bang chủ + vài trưởng lão/đội trưởng/đệ tử; bang chủ đang tuyển người.
	var idx := 0
	for g in GUILDS:
		var master: MockPlayer = out[idx]
		master.guild_name = str(g["name"])
		master.guild_figure = GuildRules.Figure.MASTER
		master.camp = int(g["camp"])
		master.level = maxi(master.level, 55)
		master.lead_level = maxi(master.lead_level, 22)
		master.recruit = true
		idx += 1
		for j in 3:
			var m: MockPlayer = out[idx]
			m.guild_name = str(g["name"])
			m.guild_figure = GuildRules.Figure.DIRECTOR if j == 0 else (GuildRules.Figure.MANAGER if j == 1 else GuildRules.Figure.MEMBER)
			m.camp = int(g["camp"])
			idx += 1
	## Vài người có quầy bày bán đang mở, hàng có giá.
	var stalls := 0
	for p in out:
		if stalls >= 5:
			break
		if p.guild_name == "" and rng.randf() < 0.55:
			p.stall_open = true
			p.trade_open = false
			p.stall_title = "Bán đồ giá mềm, ai cần ghé xem"
			for it in p.bag.inventory:
				it.trade_price = int(MockPlayer.suggested_price(it) * rng.randf_range(0.8, 1.7))
			stalls += 1
	## Luôn có ít nhất 1 quầy đang mở để người chơi thử xem/mua.
	if stalls == 0:
		for p in out:
			if p.guild_name == "":
				p.stall_open = true
				p.trade_open = false
				p.stall_title = "Bán đồ giá mềm, ai cần ghé xem"
				for it in p.bag.inventory:
					it.trade_price = int(MockPlayer.suggested_price(it) * rng.randf_range(0.8, 1.7))
				break
	return out

## Tên các bang giả đang có (để chặn lập bang trùng tên).
static func guild_names(profile: PlayerProfile) -> Array[String]:
	var out: Array[String] = []
	for g in GUILDS:
		out.append(str(g["name"]))
	players(profile)
	return out

## Bản chụp dữ liệu 1 bang giả theo định dạng GuildService (dùng khi người chơi gia nhập). Rỗng nếu không có bang đó.
static func guild_snapshot(profile: PlayerProfile, guild_name: String) -> Dictionary:
	var info := {}
	for g in GUILDS:
		if g["name"] == guild_name:
			info = g
	if info.is_empty():
		return {}
	var members := []
	for m in guild_members(profile, guild_name):
		members.append({"name": m.name, "figure": m.guild_figure, "level": m.level, "sect": m.sect_name,
				"joined_at": SecurityLock.now() - 86400 * (3 + m.id % 30), "devote": (m.level * 37) % 900, "title": "", "local": false, "mock_id": m.id,
				"perms": GuildRules.default_perms(m.guild_figure)})
	return {"name": guild_name, "camp": int(info["camp"]), "level": 3, "exp": 9500, "fund": 1_200_000,
			"notice": "Chào mừng đến %s! Chăm chỉ luyện công, giúp đỡ đồng môn." % guild_name, "recruit": true,
			"accept_level": 30 if guild_name == "Thiên Long Bang" else 0, "created_at": SecurityLock.now() - 86400 * 40,
			"members": members, "applies": [], "log": [], "trial_done": true,
			"tendency": GuildRules.TENDENCIES[abs(hash(guild_name)) % GuildRules.TENDENCIES.size()], "activity": GuildRules.ACTIVITIES[0],
			"recruit_msg": "Chào mừng bạn! Hãy chăm chỉ luyện công và giúp đỡ đồng môn.", "reject_level": 0}

## Mặc cho người chơi giả: lần lượt sinh đồ ngẫu nhiên theo cấp rồi đeo vào ô hợp loại còn trống (không phải ô nào cũng có đồ).
static func _dress(p: MockPlayer, rng: RandomNumberGenerator) -> void:
	for attempt in 40:
		var item := ItemGenerator.random_equipment(p.level)
		if item == null:
			continue
		var parts: Array = Equipment.DETAIL_TO_PARTS.get(item.get_detail(), [])
		for part in parts:
			if not p.equipment.has(part) and rng.randf() < 0.8:
				p.equipment[part] = item
				break

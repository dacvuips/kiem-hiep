extends RefCounted
class_name StarterKit
## QUÀ TÂN THỦ cho nhân vật MỚI TẠO — theo script gốc VLTK 15 phái: script/global/login.lua gọi HoTroTanThu() (cfg_server.lua
## CFG_HoTroTanThu = 1) khi nhân vật cấp 1 đăng nhập lần đầu; danh sách đồ trong script/global/nobitaxd/config/cfg_activity_bonus.lua:
##   Thần Hành Phù (6,1,1266), Hồi thành phù (6,1,438 = Thổ địa phù dùng vô hạn), 9 món Trang Bị Kim Phong (AddGoldItem 177..185),
##   Nhẫn tân thủ (AddGoldItem 514 = Thuần Tịnh Chi Giới), ngựa Túc Sương (0,10,2,9).
##   Mặt nạ tân thủ (0,11,561) bỏ qua — game chưa có ô mặt nạ. Lệnh bài tân thủ (6,1,4258) không có trong dữ liệu vật phẩm.
## Khác gốc (người dùng yêu cầu): cấp khởi đầu START_LEVEL (gốc Level_KhoiTao = 1) + thuốc hồi sinh lực / nội lực (gốc không phát),
## và 1 vũ khí đúng loại môn phái khi gia nhập phái (give_sect_weapon — bộ Kim Phong gốc không có vũ khí).
##
## Online: CHỈ game server phát (GameServer lần đầu nhân vật vào map, server_seen == 0) để đồ có uid server biết; offline: lúc tạo.

const ITEMS := 1                   ## bit của PlayerProfile.starter_kit
const WEAPON := 2
const START_LEVEL := 10            ## = PlayerProfile.NEWBIE_LEVEL: vào game là đủ cấp chọn phái
const GOLD_ROWS := [176, 177, 178, 179, 180, 181, 182, 183, 184, 513]   ## AddGoldItem 177..185 (Kim Phong) + 514 (nhẫn tân thủ)
const HORSE := [ItemDatabase.Detail.HORSE, 2, 9]                       ## Túc Sương
const MISC := [["6_1_1266", 1], ["6_1_438", 1]]                         ## Thần Hành Phù, Thổ địa phù
## [mã thuốc, số bình]: Kim Sáng Dược (trung) hồi sinh lực, Ngưng Thần đan (trung) hồi nội lực — thuốc không chồng nên mỗi bình 1 ô.
const POTIONS := [["1_0_0_2", 10], ["1_1_0_2", 10]]

## Phát quà tân thủ (1 lần / nhân vật): lên START_LEVEL (cộng đủ điểm tiềm năng / kỹ năng như lên cấp thường) + đồ vào túi.
## Trả số món đã thêm (0 = đã nhận rồi). Món không đủ chỗ thì bỏ.
static func apply(p: PlayerProfile) -> int:
	if p == null or p.starter_kit & ITEMS:
		return 0
	p.starter_kit |= ITEMS
	while p.level < START_LEVEL:
		p.level_up()
	var added := 0
	for row in GOLD_ROWS:
		added += _add(p, ItemGenerator.generate_gold(ItemDatabase.gold_index_of_row(row)))
	var horse := ItemDatabase.find_base(HORSE[0], HORSE[1], HORSE[2])
	if horse >= 0:
		added += _add(p, ItemGenerator.generate(HORSE[0], HORSE[1], HORSE[2], p.get_element(), []))
	for m in MISC:
		added += _add(p, ItemGenerator.generate_misc(str(m[0]), 0, 0, int(m[1])))
	for pot in POTIONS:
		for i in int(pot[1]):
			added += _add(p, ItemGenerator.generate_misc(str(pot[0])))
	return added

## Vũ khí tân thủ khi vừa gia nhập phái (1 lần): đúng loại vũ khí đòn chính của phái đòi hỏi (hạn chế vũ khí EqtLimit), cấp 1, hệ
## của nhân vật. Phái đánh tay không (quyền thủ) thì không có vũ khí. Trả món đã thêm (null = không phát).
static func give_sect_weapon(p: PlayerProfile) -> ItemInstance:
	if p == null or p.starter_kit & WEAPON or not p.has_sect():
		return null
	p.starter_kit |= WEAPON
	var limit := weapon_limit_of(SectRegistry.get_by_id(p.sect_id))
	var detail := -1
	var particular := 0
	if limit >= 100:
		detail = ItemDatabase.Detail.RANGE
		particular = limit - 100
	elif limit >= 0:
		detail = ItemDatabase.Detail.MELEE
		particular = limit
	elif limit == -2:
		detail = ItemDatabase.Detail.MELEE   ## không hạn chế: kiếm
	if detail < 0:
		return null
	var levels := ItemDatabase.get_levels(detail, particular)
	if levels.is_empty():
		return null
	var item := ItemGenerator.generate(detail, particular, int(levels[0]), p.get_element(), [])
	return item if _add(p, item) > 0 else null

## Phái mới bản 15 phái: skill không ghi EqtLimit -> vũ khí riêng của phái (ItemDatabase.WEAPON_PARTICULAR_NAMES: ám khí 3 = Cầm
## của Tiêu Dao, 4 = Cung của Dương Gia).
const SECT_WEAPON := {"tieu_dao": 103, "duong_gia": 104}

## Hạn chế vũ khí của phái: theo đòn chính của phái (is_main_attack), không có thì loại vũ khí nhiều skill đánh dùng nhất.
static func weapon_limit_of(sect: SectDefinition) -> int:
	if sect == null:
		return -2
	if SECT_WEAPON.has(sect.id):
		return int(SECT_WEAPON[sect.id])
	var count := {}
	for s in sect.skills:
		if s.is_main_attack and s.weapon_limit != -2:
			return s.weapon_limit
		if PkBotProfile.is_attack_skill(s) and s.weapon_limit != -2:
			count[s.weapon_limit] = int(count.get(s.weapon_limit, 0)) + 1
	var best := -2
	for k in count:
		if best == -2 or int(count[k]) > int(count[best]):
			best = k
	return best

static func _add(p: PlayerProfile, item: ItemInstance) -> int:
	return 1 if item != null and p.add_item(item) else 0

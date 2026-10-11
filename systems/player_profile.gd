extends RefCounted
class_name PlayerProfile
## Thông tin nhân vật NGOÀI trận (tên, giới tính, cấp, tiền tệ, tiến độ ải, ô ngọc) — hiển thị ở
## màn Nhân Vật. Chỉ chứa DỮ LIỆU thuần, có to_dict()/from_dict() để lưu save hoặc gửi lên server
## khi chơi online (mỗi player trong phòng có 1 PlayerProfile riêng, không dùng chung).
##
## Khác PlayerStats (autoload): PlayerStats là cấp/EXP TRONG 1 lượt chơi, reset mỗi lượt.

enum Gender { MALE, FEMALE }

## Cấp nhân vật cần đạt để mở từng ô gắn ngọc (ô i mở khi level >= GEM_SLOT_UNLOCK_LEVELS[i]).
const GEM_SLOT_UNLOCK_LEVELS: Array[int] = [1, 10, 20, 30, 40, 50]

var display_name: String = ""
var gender: Gender = Gender.MALE
var level: int = 1
var current_exp: int = 0
## Danh xưng hiển thị trong màn Thuộc Tính (VD "Lục Các Trưởng Lão" trong VLTK gốc) — game CHƯA có
## hệ thống cấp danh xưng, khởi điểm rỗng cho đến khi có tính năng đó.
var title: String = ""
## Phúc duyên/Danh vọng/Xếp hạng thế giới — game CHƯA có hệ thống tính các chỉ số này, khởi điểm
## 0/rỗng thay vì hard-code trong UI, sẵn sàng gắn logic thật khi tính năng tương ứng ra đời.
var fuyuan: int = 0
var prestige: int = 0
var world_rank: String = ""
## id trong SectDefinition ("" = chưa chọn — chỉ xảy ra với save rất cũ trước khi có hệ môn phái).
var sect_id: String = ""
var sect_name: String = "Vô Môn Phái"
## Phe hiện tại (Camp.Type) = MÀU TÊN, quyết định ai là đồng đội (cùng màu). -1 = theo phe mặc định của
## môn phái (Camp.default_for_sect); đặt giá trị khác khi nhân vật đổi phe (sự kiện, bang chiến...).
var camp: int = -1

func get_current_camp() -> int:
	return camp if camp >= 0 else Camp.default_for_sect(SectRegistry.get_by_id(sect_id))

## 4 chỉ số gốc VLTK (Lực/Nhanh nhẹn/Sinh khí/Nội công) — người chơi tự cộng bằng "điểm tiềm
## năng" nhận mỗi khi lên cấp (xem UiStatus.ini gốc: Strength/Dexterity/Vitality/Energy +
## RemainPoint). Khởi điểm CHÍNH XÁC 100% VLTK — NGUYÊN VĂN settings/npc/player/NewPlayerIni00-09.ini
## (ipower=35, iagility=25, iouter=25, iinside=15, xem docs/vltk_player_stats_reference.md mục 1) —
## KHÔNG phải số áng chừng. Quan trọng: Dexterity < 32 sẽ cho AttackRating âm (CombatFormulas.
## calc_base_attack_rating = Dexterity×4−28) → luôn Miss 100%, xem CombatFormulas.calc_hit_percent.
var strength: int = 35
var dexterity: int = 25
var vitality: int = 25
var energy: int = 15
## Chỉ số khởi điểm cấp 1 THEO HỆ — settings/npc/player/NewPlayerIni<Hệ*2+Giới>.ini gốc (KPlayer.cpp: Series * 2 + Sex), cột
## ipower/iagility/iouter/iinside = Sức mạnh/Thân pháp/Sinh khí/Nội công; 2 giới cùng số. Thứ tự hệ = ElementTypes (Kim, Mộc, Thủy, Hỏa, Thổ).
## (NewPlayerBaseAttribute.ini gốc toàn 0 nên không có tác dụng.)
const START_STATS := [[35, 25, 25, 15], [20, 35, 20, 25], [25, 25, 25, 25], [30, 20, 30, 20], [20, 15, 25, 40]]

## [Sức mạnh, Thân pháp, Sinh khí, Nội công] khởi điểm của hệ môn phái hiện tại (chưa chọn phái = Kim).
func get_start_stats() -> Array:
	var sect := SectRegistry.get_by_id(sect_id)
	var element: int = int(sect.element) if sect else 0
	return START_STATS[clampi(element, 0, START_STATS.size() - 1)]

## Đặt 4 chỉ số gốc về khởi điểm của hệ (chỉ dùng khi tạo nhân vật / tẩy điểm — không đụng điểm tiềm năng).
func apply_start_stats() -> void:
	var st := get_start_stats()
	strength = st[0]
	dexterity = st[1]
	vitality = st[2]
	energy = st[3]

## Điểm tiềm năng chưa phân bổ — nhận mỗi khi lên cấp, dùng cộng vào 1 trong 4 chỉ số gốc trên
## (KHÁC skill_points, vốn dùng riêng để học/nâng skill).
var potential_points: int = 0
const POTENTIAL_POINTS_PER_LEVEL := 5

## Điểm kỹ năng chưa dùng — nhận mỗi khi lên level, dùng để học/nâng cấp skill phụ của môn phái.
var skill_points: int = 0
## skill_id (String) -> cấp đã học (int), 0/không có key = chưa học. Áp dụng cho MỌI skill kể cả
## đòn chính (đòn chính dùng được ngay ở cấp 0, cộng điểm để nâng sức mạnh).
var skill_levels: Dictionary = {}

const SKILL_POINTS_PER_LEVEL := 1

## Ô skill phụ ngoài màn chơi do người chơi TỰ GẮN (bảng Kỹ năng) — skill_id từng ô, "" = ô trống. 2 TRANG x 8 ô
## (nút "1"/"2" trên cụm nút skill đổi trang): ô thứ i của trang p = chỉ số p * HOTBAR_SLOTS_PER_PAGE + i. Luôn đủ
## HOTBAR_SLOT_COUNT phần tử. Phím skill_1-4 = 4 ô đầu của trang đang chọn.
const HOTBAR_SLOTS_PER_PAGE := 8
const HOTBAR_PAGES := 2
const HOTBAR_SLOT_COUNT := HOTBAR_SLOTS_PER_PAGE * HOTBAR_PAGES
var hotbar_skill_ids: Array[String] = []
## Ô THI TRIỂN LIÊN TỤC (LOOP_SLOT_COUNT ô): skill gắn vào đây tự ra chiêu mỗi khi hồi xong (VD Vô Hình Độc) — xem
## Player._tick_loop_skills. Mỗi skill chỉ nằm ở 1 chỗ (nút chính / hotbar / ô liên tục).
const LOOP_SLOT_COUNT := 1
var loop_skill_ids: Array[String] = []
## Trang thanh skill đang chọn (0/1).
var hotbar_page: int = 0
## Vị trí các nút skill do người chơi tự sắp xếp: khoá ("main", "s0".."s7", "loop0") -> [dx, dy] = độ dời (pixel HUD) so với vị trí
## mặc định trong SkillBarUI.tscn. Thiếu khoá = đúng chỗ mặc định. Dùng chung cho cụm nút trong trận và bảng Kỹ Năng Võ Công.
var skill_layout: Dictionary = {}

func get_layout_offset(key: String) -> Vector2:
	var v: Variant = skill_layout.get(key)
	return Vector2(float(v[0]), float(v[1])) if v is Array and v.size() >= 2 else Vector2.ZERO

func set_layout_offset(key: String, offset: Vector2) -> void:
	if offset.length() < 0.5:
		skill_layout.erase(key)
	else:
		skill_layout[key] = [snappedf(offset.x, 0.1), snappedf(offset.y, 0.1)]
## Hào quang đang BẬT (skill is_aura — La Hán Trận, Thất Tinh Trận...): bấm skill để bật/tắt, chỉ 1 hào quang cùng
## lúc như chuột phải VLTK gốc. "" = không bật. Thuộc tính hào quang cộng vào chỉ số khi đang bật (CombatantBuild).
var active_aura_id: String = ""
## Khung "Tùy chỉnh kỹ năng" (bảng Kỹ năng): no_target = không có quái gần vẫn ra chiêu về phía trước mặt;
## face_direction = luôn ra chiêu theo hướng nhân vật đang quay (không tự nhắm quái gần nhất); tap_release = nút skill
## ra chiêu khi NHẢ tay (tắt = ra chiêu ngay lúc chạm). Chế độ Auto vẫn tự nhắm quái.
var skill_settings: Dictionary = {"no_target": false, "face_direction": false, "tap_release": false}

func get_skill_setting(key: String) -> bool:
	return bool(skill_settings.get(key, false))
## Skill người chơi tự gắn vào NÚT CHÍNH (nút lớn, cũng là skill chế độ Auto tự đánh) — "" = dùng
## đòn chính mặc định của môn phái (SkillDefinition.is_main_attack).
var main_skill_id: String = ""

## Túi đồ (hành trang) và đồ đang mặc — ItemInstance (dữ liệu thuần). equipment: Equipment.Part -> ItemInstance.
var inventory: Array[ItemInstance] = []
var equipment: Dictionary = {}
## Đang cưỡi ngựa (m_bRideHorse gốc). Chỉ có nghĩa khi ô Ngựa có đồ: mặc ngựa -> tự lên ngựa, tháo ngựa -> xuống
## (KItemList::Equip/UnEquip). Chỉ số/dòng magic của ngựa CHỈ có hiệu lực khi đang cưỡi (KNpc::SwitchRideHorse).
var riding: bool = true
## HÀNH TRANG kiểu VLTK: lưới ROOM_WIDTH × ROOM_HEIGHT ô, mỗi món chiếm số ô rộng × cao riêng (ItemInstance.get_size) tại
## (room_x, room_y). Hết chỗ trống đủ lớn = túi đầy. 16 × 20 theo bản VLTK mở rộng trong ảnh mẫu của người dùng
## (source gốc GameDataDef.h: EQUIPMENT_ROOM_WIDTH/HEIGHT = 6 × 10) — đổi 2 hằng số này là đổi cỡ lưới, mọi thứ tự co theo.
const ROOM_WIDTH := 16
const ROOM_HEIGHT := 20
## Số túi (Túi 1..BAG_COUNT trên cột bên phải) và số túi ĐÃ MỞ — túi chưa mở bị khoá, mở thêm bằng cách tăng OPEN_BAGS.
const BAG_COUNT := 6
const OPEN_BAGS := 3
const INVENTORY_CAPACITY := ROOM_WIDTH * ROOM_HEIGHT * OPEN_BAGS  ## tổng số ô của các túi đang mở

var gold: int = 0
var jade: int = 0

## ---- Xã hội: rương, khoá bảo vệ, lãnh đạo, bang hội, bày bán (logic ở systems/social/*) ----
## Rương chứa đồ (REPOSITORY gốc): 1 rương chính 6 x 10 + tối đa 5 rương mở rộng (storage_extra = số đã mở); tiền gửi riêng.
var storage := ItemContainer.new(6, 10, 1)
var storage_extra: int = 0
var storage_gold: int = 0
## Khoá bảo vệ: mật khẩu 1-16 ký tự (chỉ lưu mã băm); đang khoá thì chặn mở bày bán/giao dịch/mua bán NPC/gửi tiền/vứt đồ.
var security_hash: String = ""
var security_locked: bool = false
## Cấp lãnh đạo (KPlayer::m_nLeadLevel/m_nLeadExp): quyết định số người tối đa trong tổ đội và điều kiện lập bang.
var lead_level: int = 0
var lead_exp: int = 0
## Bang hội (KPlayerTong + dữ liệu bang chạy cục bộ): rỗng = chưa vào bang.
var guild: Dictionary = {}
## Thời điểm (giây unix) sớm nhất được xin vào bang khác sau khi rời bang (LeaveTm gốc).
var guild_join_after: int = 0
## Câu rao bán khi mở quầy bày bán.
var stall_title: String = ""
## Trạng thái ĐANG chạy (không lưu): đang bày bán / đang mở giao dịch (nhận lời xin giao dịch). Hai trạng thái loại trừ nhau.
var stall_open: bool = false
var trade_open: bool = false
var stamina: int = 100   ## khởi điểm gốc 100 (imaxstamina của NewPlayerIni)
var max_stamina: int = 100

## Số ải đã vượt (0 = chưa vượt ải nào) — ải đang chơi tiếp theo là index này.
var stages_cleared: int = 0
var herb_garden_level: int = 1
var pending_quest_count: int = 0
## id gem trong từng ô ("" = trống), luôn đủ GEM_SLOT_UNLOCK_LEVELS.size() phần tử.
var gem_slots: Array[String] = []

func _init() -> void:
	gem_slots.resize(GEM_SLOT_UNLOCK_LEVELS.size())
	gem_slots.fill("")
	hotbar_skill_ids.resize(HOTBAR_SLOT_COUNT)
	hotbar_skill_ids.fill("")
	loop_skill_ids.resize(LOOP_SLOT_COUNT)
	loop_skill_ids.fill("")

## TẠM THỜI — đường cong EXP ngoài trận, chỉnh khi cân bằng game.
func get_exp_to_next_level() -> int:
	return 100 + (level - 1) * 150

func is_gem_slot_unlocked(index: int) -> bool:
	return level >= GEM_SLOT_UNLOCK_LEVELS[index]

func get_combat_stats(state_sources: Array[Dictionary] = []) -> CombatantStats:
	return CombatantStats.from_profile(self, state_sources)

## Bản dựng combat của nhân vật này — CÙNG định dạng với quái/người chơi khác (CombatantBuild), gửi
## lên server khi online bằng to_build().to_dict().
func to_build() -> CombatantBuild:
	var b := CombatantBuild.new()
	b.level = level
	var sect := SectRegistry.get_by_id(sect_id)
	b.element = sect.element if sect else ElementTypes.ElementType.KIM
	b.strength = strength
	b.dexterity = dexterity
	b.vitality = vitality
	b.energy = energy
	b.female = gender == Gender.FEMALE
	b.sect_id = sect_id
	b.skill_levels = skill_levels.duplicate()
	b.camp = get_current_camp()
	## Mọi đồ đang mặc đều có tác dụng — kể cả khi chỉ số tụt dưới yêu cầu (tẩy điểm, tháo món cộng chỉ số):
	## đúng VLTK gốc, yêu cầu CHỈ chặn lúc mặc từ Hành trang vào (equip_from_inventory).
	b.equipment = equipment.duplicate()
	b.riding = riding
	b.active_aura_id = active_aura_id
	return b

## Gán môn phái đã chọn ở màn Chọn Nhân Vật — cập nhật cả sect_id (nguồn sự thật) lẫn sect_name
## (cache hiển thị, CharacterHub đang đọc trực tiếp field này) để luôn đồng bộ.
func set_sect(sect_def: SectDefinition) -> void:
	## Chưa cộng điểm nào (đang đúng khởi điểm của hệ cũ) thì đổi sang khởi điểm của hệ mới; đã cộng điểm thì giữ nguyên.
	## Cấp 1 và chưa có điểm tiềm năng thì không thể đã cộng gì -> luôn lấy khởi điểm hệ mới (kể cả save cũ mang bộ chỉ số sai).
	var untouched: bool = (level == 1 and potential_points == 0) or [strength, dexterity, vitality, energy] == get_start_stats()
	sect_id = sect_def.id
	sect_name = sect_def.sect_name
	var need := required_gender(int(sect_def.element))
	if need >= 0:
		gender = need as Gender
	if untouched:
		apply_start_stats()

## Cộng EXP nhân vật (lâu dài, khác PlayerStats.current_exp trong-trận) — lên level thì cấp thêm
## điểm kỹ năng để học/nâng skill phụ. Dùng while thay vì if để xử lý đúng khi cộng đủ EXP nhảy
## nhiều level cùng lúc trong 1 lần gọi.
func add_exp(amount: int) -> void:
	current_exp += amount
	while current_exp >= get_exp_to_next_level():
		current_exp -= get_exp_to_next_level()
		level_up()

## Lên 1 cấp + nhận điểm kỹ năng/tiềm năng tương ứng — dùng chung cho add_exp() và nút test lên cấp
## (DebugCheatPanel), để 2 đường lên cấp luôn cộng điểm giống hệt nhau.
func level_up() -> void:
	level += 1
	max_stamina = _stamina_for_level()
	stamina = max_stamina
	skill_points += SKILL_POINTS_PER_LEVEL
	potential_points += POTENTIAL_POINTS_PER_LEVEL

## Học mới/nâng 1 cấp cho skill phụ thuộc môn phái hiện tại — false nếu hết điểm, đã max level,
## hoặc skill không tồn tại trong môn phái đã chọn (VD id gõ sai/môn phái đổi giữa chừng).
func learn_skill(skill_id: String) -> bool:
	if skill_points <= 0:
		return false
	var sect := SectRegistry.get_by_id(sect_id)
	if sect == null:
		return false
	var skill: SkillDefinition = null
	for candidate in sect.skills:
		if candidate.id == skill_id:
			skill = candidate
			break
	## Đòn chính (is_main_attack) cũng học/nâng được — dùng được sẵn từ cấp 0, nhưng cộng điểm để
	## mạnh lên theo cấp như VLTK gốc (VD Phích Lịch đơn req_level 10, max_level 20).
	if skill == null:
		return false
	if level < skill.req_level:
		return false
	## Skill luyện (90/120/150) không cộng điểm — dùng learn_practice_skill (lĩnh hội cấp 1).
	if skill.practice_only:
		return false
	var current: int = skill_levels.get(skill_id, 0)
	if current >= skill.max_level:
		return false
	skill_levels[skill_id] = current + 1
	skill_points -= 1
	return true

## Cấp skill vượt cấp tối đa (dữ liệu skill đã đồng bộ lại theo Skills.txt gốc — VD max 26 -> 20) thì hạ về tối đa,
## hoàn lại điểm kỹ năng phần vượt (skill luyện không mua bằng điểm thì không hoàn).
func _clamp_skill_levels() -> void:
	for skill_id in skill_levels.keys():
		var skill := _find_sect_skill(skill_id)
		if skill == null or int(skill_levels[skill_id]) <= skill.max_level:
			continue
		if not skill.practice_only:
			skill_points += int(skill_levels[skill_id]) - skill.max_level
		skill_levels[skill_id] = skill.max_level

func _find_sect_skill(skill_id: String) -> SkillDefinition:
	var sect := SectRegistry.get_by_id(sect_id)
	if sect:
		for candidate in sect.skills:
			if candidate.id == skill_id:
				return candidate
	return null

## Skill luyện (practice_only): đủ cấp thì lĩnh hội CẤP 1 miễn phí, không tốn điểm (như đọc bí kíp VLTK gốc).
func learn_practice_skill(skill_id: String) -> bool:
	var skill := _find_sect_skill(skill_id)
	if skill == null or not skill.practice_only or level < skill.req_level or get_skill_level(skill_id) > 0:
		return false
	skill_levels[skill_id] = 1
	return true

## CHỈ dùng cho nút TEST (bản debug): +1 cấp bỏ qua cấp nhân vật/điểm kỹ năng/skill luyện, không tốn điểm.
func debug_raise_skill(skill_id: String) -> bool:
	var skill := _find_sect_skill(skill_id)
	if skill == null or get_skill_level(skill_id) >= skill.max_level:
		return false
	skill_levels[skill_id] = get_skill_level(skill_id) + 1
	return true

## Về cấp 1 như nhân vật mới tạo: cấp/EXP về đầu, bỏ luôn toàn bộ điểm kiếm được từ các cấp đã lên
## (tẩy điểm rồi xoá sạch điểm tiềm năng/kỹ năng về khởi điểm). GIỮ tên/giới tính/môn phái/tiền
## tệ/tiến độ ải. Dùng cho nút "Về cấp 1" của DebugCheatPanel.
func reset_to_level_1() -> void:
	refund_all_points()
	var fresh := PlayerProfile.new()
	level = fresh.level
	current_exp = fresh.current_exp
	potential_points = fresh.potential_points
	skill_points = fresh.skill_points
	skill_levels.clear()  ## kể cả skill luyện (tẩy điểm thường giữ lại chúng)

## Tẩy điểm (giữ nguyên cấp/EXP): 4 chỉ số gốc về khởi điểm, số điểm đã cộng HOÀN LẠI vào
## potential_points; bỏ học mọi skill, tổng số cấp đã học HOÀN LẠI vào skill_points. Thanh skill về
## trống vì skill không còn học. Khởi điểm lấy từ 1 PlayerProfile mới để không lặp lại hằng số.
## Dùng cho nút Tẩy điểm của DebugCheatPanel. Trả về số điểm đã hoàn:
## {"potential": int, "skill": int}.
func refund_all_points() -> Dictionary:
	var fresh := PlayerProfile.new()
	var start: Array = get_start_stats()
	var spent_potential: int = (strength - start[0]) + (dexterity - start[1]) + (vitality - start[2]) + (energy - start[3])
	potential_points += maxi(spent_potential, 0)
	apply_start_stats()

	## Skill luyện (90/120/150) không mua bằng điểm -> không hoàn điểm và GIỮ nguyên khi tẩy điểm.
	var spent_skill := 0
	var kept := {}
	for skill_id in skill_levels:
		var skill := _find_sect_skill(skill_id)
		if skill and skill.practice_only:
			kept[skill_id] = skill_levels[skill_id]
		else:
			spent_skill += int(skill_levels[skill_id])
	skill_points += spent_skill
	skill_levels = kept
	hotbar_skill_ids = fresh.hotbar_skill_ids
	loop_skill_ids = fresh.loop_skill_ids
	main_skill_id = fresh.main_skill_id
	return {"potential": maxi(spent_potential, 0), "skill": spent_skill}

## Giới tính được phép của hệ: Kim = chỉ nam, Thủy = chỉ nữ (Nga Mi, Thúy Yên chỉ nhận nữ), hệ khác cả hai. Trả về -1 = cả hai.
static func required_gender(element: int) -> int:
	if element == ElementTypes.ElementType.KIM:
		return Gender.MALE
	if element == ElementTypes.ElementType.THUY:
		return Gender.FEMALE
	return -1

## Nhân vật lưu từ bản cũ: (1) giới tính không hợp hệ -> đổi theo hệ; (2) còn nguyên khởi điểm Kim dù hệ khác, cấp 1 và chưa có điểm
## tiềm năng nào (không thể đã cộng) -> đổi sang khởi điểm đúng của hệ; (3) thể lực khởi điểm cũ 120 -> 100 (bản gốc).
func _migrate_vltk_start_values() -> void:
	var sect := SectRegistry.get_by_id(sect_id)
	if sect == null:
		return
	var need := required_gender(int(sect.element))
	if need >= 0 and gender != need:
		gender = need as Gender
	if level == 1 and potential_points == 0 and [strength, dexterity, vitality, energy] == START_STATS[0]:
		apply_start_stats()
	var full := stamina >= max_stamina
	max_stamina = _stamina_for_level()
	stamina = max_stamina if full else mini(stamina, max_stamina)

## Thể lực tối đa theo cấp/giới (xem CombatantStats.STAMINA_PER_LEVEL_*).
func _stamina_for_level() -> int:
	var per_level := CombatantStats.STAMINA_PER_LEVEL_FEMALE if gender == Gender.FEMALE else CombatantStats.STAMINA_PER_LEVEL_MALE
	return CombatantStats.STAMINA_BASE + (level - 1) * per_level

## Khoá JSON là chuỗi (JSON không có khoá số) — from_dict đổi lại về int.
func _equipment_to_dict() -> Dictionary:
	var out := {}
	for part in equipment:
		out[str(part)] = (equipment[part] as ItemInstance).to_dict()
	return out

func get_skill_level(skill_id: String) -> int:
	return int(skill_levels.get(skill_id, 0))

## ---- Trang bị ----
## Thêm vào túi, xếp vào chỗ trống đủ lớn đầu tiên của túi đầu tiên còn chỗ — false nếu hết chỗ ở mọi túi đang mở.
func add_item(item: ItemInstance) -> bool:
	if item == null:
		return false
	var spot := find_free_spot_any(item.get_size())
	if spot.z < 0:
		return false
	item.room_x = spot.x
	item.room_y = spot.y
	item.room_bag = spot.z
	inventory.append(item)
	return true

## Số hàng đang hiển thị của túi `bag`: tối thiểu ROOM_HEIGHT, dài hơn nếu có món (từ save cũ) nằm dưới hàng cuối.
func get_room_height(bag: int = 0) -> int:
	var rows := ROOM_HEIGHT
	for it in inventory:
		if it.room_bag == bag:
			rows = maxi(rows, it.room_y + it.get_size().y)
	return rows

## Số ô đang bị chiếm (mọi túi).
func get_used_cells() -> int:
	var used := 0
	for it in inventory:
		var size := it.get_size()
		used += size.x * size.y
	return used

## Ô (x, y) của túi `bag` có bị món nào (trừ `except`) chiếm không.
func _cell_blocked(x: int, y: int, bag: int, except: ItemInstance) -> bool:
	for it in inventory:
		if it == except or it.room_x < 0 or it.room_bag != bag:
			continue
		var size := it.get_size()
		if x >= it.room_x and x < it.room_x + size.x and y >= it.room_y and y < it.room_y + size.y:
			return true
	return false

## Đặt món `item` tại ô trên-trái (x, y) của túi `bag` có hợp lệ không (trong lưới + không đè món khác; chính nó được bỏ qua).
func can_place(item: ItemInstance, x: int, y: int, bag: int, rows: int = ROOM_HEIGHT) -> bool:
	if bag < 0 or bag >= OPEN_BAGS:
		return false
	var size := item.get_size()
	if x < 0 or y < 0 or x + size.x > ROOM_WIDTH or y + size.y > rows:
		return false
	for cy in range(y, y + size.y):
		for cx in range(x, x + size.x):
			if _cell_blocked(cx, cy, bag, item):
				return false
	return true

## Chỗ trống đầu tiên trong túi `bag` cho món kích thước `size` (Vector2i(-1, -1) nếu không có).
func find_free_spot(size: Vector2i, bag: int, except: ItemInstance = null, rows: int = ROOM_HEIGHT) -> Vector2i:
	for y in range(0, rows - size.y + 1):
		for x in range(0, ROOM_WIDTH - size.x + 1):
			var free := true
			for cy in range(y, y + size.y):
				for cx in range(x, x + size.x):
					if _cell_blocked(cx, cy, bag, except):
						free = false
						break
				if not free:
					break
			if free:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

## Chỗ trống đầu tiên ở BẤT KỲ túi đang mở (duyệt Túi 1 -> ...): Vector3i(x, y, túi); z = -1 nếu hết chỗ.
func find_free_spot_any(size: Vector2i, except: ItemInstance = null) -> Vector3i:
	for bag in OPEN_BAGS:
		var spot := find_free_spot(size, bag, except)
		if spot.x >= 0:
			return Vector3i(spot.x, spot.y, bag)
	return Vector3i(-1, -1, -1)

## Kéo món sang ô (x, y) của túi `bag` — false nếu không vừa chỗ.
func move_item(item: ItemInstance, x: int, y: int, bag: int) -> bool:
	if not inventory.has(item) or not can_place(item, x, y, bag, get_room_height(bag)):
		return false
	item.room_x = x
	item.room_y = y
	item.room_bag = bag
	return true

## Chuyển món sang túi `bag` (vào chỗ trống đầu tiên của túi đó) — false nếu túi chưa mở / hết chỗ.
func move_to_bag(item: ItemInstance, bag: int) -> bool:
	if not inventory.has(item) or bag < 0 or bag >= OPEN_BAGS:
		return false
	var spot := find_free_spot(item.get_size(), bag, item)
	if spot.x < 0:
		return false
	item.room_x = spot.x
	item.room_y = spot.y
	item.room_bag = bag
	return true

## Sắp xếp: theo loại đồ (vũ khí, áo, mũ...), hoàng kim trước, cấp cao trước — rồi xếp lại từ Túi 1. Món nào không vừa
## trong các túi đang mở (chỉ khi save cũ đã tràn) được đặt xuống hàng thêm của Túi 1 thay vì mất.
func sort_inventory() -> void:
	inventory.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		if a.get_detail() != b.get_detail():
			return a.get_detail() < b.get_detail()
		if a.is_gold() != b.is_gold():
			return a.is_gold()
		return a.get_level() > b.get_level())
	_repack(inventory.duplicate())

## Xếp lại danh sách `items` first-fit từ ô đầu của Túi 1.
func _repack(items: Array) -> void:
	for it in items:
		it.room_x = -1
		it.room_y = -1
	for it in items:
		_place_anywhere(it)

## Đặt `it` vào chỗ trống đầu tiên của các túi đang mở; hết chỗ thì xuống hàng thêm của Túi 1 (không bao giờ làm mất món).
func _place_anywhere(it: ItemInstance) -> void:
	var spot := find_free_spot_any(it.get_size(), it)
	if spot.z >= 0:
		it.room_x = spot.x
		it.room_y = spot.y
		it.room_bag = spot.z
		return
	var overflow := find_free_spot(it.get_size(), 0, it, 200)
	it.room_x = overflow.x
	it.room_y = overflow.y
	it.room_bag = 0

## Sau khi nạp save: món chưa có vị trí / trùng chỗ / ngoài lưới / túi chưa mở thì xếp lại first-fit (save cũ không lưu vị trí).
func _layout_inventory() -> void:
	var settled: Array = []
	var pending: Array = []
	for it in inventory:
		var ok: bool = it.room_x >= 0 and it.room_y >= 0 and it.room_x + it.get_size().x <= ROOM_WIDTH \
				and it.room_bag >= 0 and it.room_bag < OPEN_BAGS
		if ok:
			for other in settled:
				if other.room_bag != it.room_bag:
					continue
				var a := Rect2i(it.room_x, it.room_y, it.get_size().x, it.get_size().y)
				var b := Rect2i(other.room_x, other.room_y, other.get_size().x, other.get_size().y)
				if a.intersects(b):
					ok = false
					break
		(settled if ok else pending).append(it)
	for it in pending:
		it.room_x = -1
		it.room_y = -1
	for it in pending:
		_place_anywhere(it)

## Mặc món thứ `index` trong túi. Trả về "" nếu thành công, không thì lý do (chưa đủ yêu cầu...). Ô đang
## có đồ thì đồ cũ về túi. Nhẫn: ưu tiên ô Nhẫn 1 trống, rồi Nhẫn 2, đều có thì thay Nhẫn 1.
func equip_from_inventory(index: int) -> String:
	if index < 0 or index >= inventory.size():
		return "Không có món đồ này"
	var item := inventory[index]
	var parts: Array = Equipment.DETAIL_TO_PARTS.get(item.get_detail(), [])
	if parts.is_empty():
		return "Không mặc được món này"
	var part: int = parts[0]
	for p in parts:
		if not equipment.has(p):
			part = p
			break
	## Xét yêu cầu với chỉ số SAU KHI bỏ món đang ở ô đó (không tính chỉ số của món sắp bị thay).
	var ctx := Equipment.get_requirement_context(self, part)
	var unmet := Equipment.get_unmet_requirements(item, self, ctx)
	if not unmet.is_empty():
		return "Chưa đủ yêu cầu: " + ", ".join(unmet)
	inventory.remove_at(index)
	if equipment.has(part):
		## Đồ cũ về túi: ưu tiên đúng chỗ món mới vừa rời, không vừa thì chỗ trống đầu tiên; hết chỗ thì huỷ việc mặc.
		var old: ItemInstance = equipment[part]
		var spot := Vector3i(item.room_x, item.room_y, item.room_bag)
		if not can_place(old, spot.x, spot.y, spot.z):
			spot = find_free_spot_any(old.get_size())
		if spot.z < 0:
			inventory.insert(index, item)
			return "Hành trang không đủ chỗ để đổi đồ"
		old.room_x = spot.x
		old.room_y = spot.y
		old.room_bag = spot.z
		inventory.append(old)
	equipment[part] = item
	if part == Equipment.Part.HORSE:
		riding = true
	return ""

## Tháo đồ ở ô `part` về túi — false nếu ô trống hoặc túi đầy.
func unequip(part: int) -> bool:
	if not equipment.has(part):
		return false
	var worn: ItemInstance = equipment[part]
	var spot := find_free_spot_any(worn.get_size())
	if spot.z < 0:
		return false  ## không còn chỗ trống đủ lớn ở túi nào
	worn.room_x = spot.x
	worn.room_y = spot.y
	worn.room_bag = spot.z
	inventory.append(worn)
	equipment.erase(part)
	if part == Equipment.Part.HORSE:
		riding = false
	return true

## Gắn skill vào ô hotbar `index` — skill đã nằm ở ô khác thì chuyển sang ô mới (không cho 1 skill
## chiếm 2 ô). Việc kiểm tra skill có được phép gắn không (ACTIVE, đã học) do nơi gọi đảm nhận, xem
## SkillDefinition.can_assign_to_hotbar().
func set_hotbar_slot(index: int, skill_id: String) -> void:
	if index < 0 or index >= HOTBAR_SLOT_COUNT:
		return
	for i in HOTBAR_SLOT_COUNT:
		if hotbar_skill_ids[i] == skill_id:
			hotbar_skill_ids[i] = ""
	hotbar_skill_ids[index] = skill_id
	if main_skill_id == skill_id:
		main_skill_id = ""
	clear_loop_skill(skill_id)

## Gắn skill vào ô thi triển liên tục `index` ("" = bỏ trống ô) — rời mọi chỗ khác của skill đó.
func set_loop_slot(index: int, skill_id: String) -> void:
	if index < 0 or index >= LOOP_SLOT_COUNT:
		return
	if skill_id != "":
		clear_hotbar_skill(skill_id)
		clear_loop_skill(skill_id)
		if main_skill_id == skill_id:
			main_skill_id = ""
	loop_skill_ids[index] = skill_id

func clear_loop_skill(skill_id: String) -> void:
	if skill_id == "":
		return
	for i in LOOP_SLOT_COUNT:
		if loop_skill_ids[i] == skill_id:
			loop_skill_ids[i] = ""

## Gắn skill vào nút chính — skill đang nằm ở nút phụ nào thì rời nút đó. "" = về đòn chính mặc định.
func set_main_skill(skill_id: String) -> void:
	if skill_id != "":
		clear_hotbar_skill(skill_id)
		clear_loop_skill(skill_id)
	main_skill_id = skill_id

func clear_hotbar_skill(skill_id: String) -> void:
	for i in HOTBAR_SLOT_COUNT:
		if hotbar_skill_ids[i] == skill_id:
			hotbar_skill_ids[i] = ""

## -1 nếu skill không nằm trong ô hotbar nào.
func get_hotbar_index(skill_id: String) -> int:
	return hotbar_skill_ids.find(skill_id)

enum BaseStat { STRENGTH, DEXTERITY, VITALITY, ENERGY }

## Cộng 1 điểm tiềm năng vào 1 trong 4 chỉ số gốc — false nếu hết điểm. Không giới hạn tối đa
## (VLTK gốc cũng không giới hạn cứng, chỉ bị giới hạn tự nhiên bởi tổng điểm tiềm năng kiếm được).
func add_potential_point(stat: BaseStat) -> bool:
	if potential_points <= 0:
		return false
	match stat:
		BaseStat.STRENGTH:
			strength += 1
		BaseStat.DEXTERITY:
			dexterity += 1
		BaseStat.VITALITY:
			vitality += 1
		BaseStat.ENERGY:
			energy += 1
	potential_points -= 1
	return true

## Cộng nhiều điểm tiềm năng 1 lần (popup nhập số) — tự kẹp trong số điểm đang có; trả về số điểm đã cộng.
func add_potential_points(stat: BaseStat, amount: int) -> int:
	var added := 0
	while added < amount and add_potential_point(stat):
		added += 1
	return added

## Chép toàn bộ dữ liệu từ `other` vào chính hồ sơ này (giữ nguyên đối tượng — UI / SocialHub đang tham chiếu nó).
## Online: server gửi bản nhân vật chuẩn (S_PROFILE) -> game chép vào hồ sơ đang dùng.
func copy_from(other: PlayerProfile) -> void:
	for p in get_property_list():
		if (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			set(p.name, other.get(p.name))

## Online: game server đã kiểm tra / khởi tạo phần kinh tế của nhân vật này (lần đầu vào map). 0 = chưa.
var server_seen: int = 0

func to_dict() -> Dictionary:
	return {
		"server_seen": server_seen,
		"name": display_name,
		"gender": gender,
		"level": level,
		"exp": current_exp,
		"title": title,
		"fuyuan": fuyuan,
		"prestige": prestige,
		"world_rank": world_rank,
		"sect_id": sect_id,
		"sect_name": sect_name,
		"camp": camp,
		"inventory": inventory.map(func(it: ItemInstance) -> Dictionary: return it.to_dict()),
		"equipment": _equipment_to_dict(),
		"strength": strength,
		"dexterity": dexterity,
		"vitality": vitality,
		"energy": energy,
		"potential_points": potential_points,
		"skill_points": skill_points,
		"skill_levels": skill_levels,
		"gold": gold,
		"jade": jade,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"stages_cleared": stages_cleared,
		"herb_garden_level": herb_garden_level,
		"pending_quest_count": pending_quest_count,
		"gem_slots": gem_slots,
		"hotbar_skill_ids": hotbar_skill_ids,
		"hotbar_page": hotbar_page,
		"skill_layout": skill_layout,
		"loop_skill_ids": loop_skill_ids,
		"active_aura_id": active_aura_id,
		"skill_settings": skill_settings,
		"main_skill_id": main_skill_id,
		"storage": storage.to_array(),
		"storage_extra": storage_extra,
		"storage_gold": storage_gold,
		"security_hash": security_hash,
		"security_locked": security_locked,
		"lead_level": lead_level,
		"lead_exp": lead_exp,
		"guild": guild,
		"guild_join_after": guild_join_after,
		"stall_title": stall_title,
	}

static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.display_name = str(data.get("name", ""))
	profile.gender = int(data.get("gender", Gender.MALE)) as Gender
	profile.level = int(data.get("level", 1))
	profile.current_exp = int(data.get("exp", 0))
	profile.title = str(data.get("title", ""))
	profile.fuyuan = int(data.get("fuyuan", 0))
	profile.prestige = int(data.get("prestige", 0))
	profile.world_rank = str(data.get("world_rank", ""))
	profile.sect_id = str(data.get("sect_id", ""))
	profile.sect_name = str(data.get("sect_name", profile.sect_name))
	profile.camp = int(data.get("camp", -1))
	profile.server_seen = int(data.get("server_seen", 0))
	for item_data in data.get("inventory", []):
		profile.inventory.append(ItemInstance.from_dict(item_data))
	profile._layout_inventory()
	var saved_equipment: Dictionary = data.get("equipment", {})
	for part in saved_equipment:
		profile.equipment[int(part)] = ItemInstance.from_dict(saved_equipment[part])
	profile.strength = int(data.get("strength", profile.strength))
	profile.dexterity = int(data.get("dexterity", profile.dexterity))
	profile.vitality = int(data.get("vitality", profile.vitality))
	profile.energy = int(data.get("energy", profile.energy))
	profile.potential_points = int(data.get("potential_points", 0))
	profile.skill_points = int(data.get("skill_points", 0))
	var saved_skill_levels: Dictionary = data.get("skill_levels", {})
	for skill_id in saved_skill_levels.keys():
		profile.skill_levels[str(skill_id)] = int(saved_skill_levels[skill_id])
	profile.gold = int(data.get("gold", 0))
	profile.jade = int(data.get("jade", 0))
	profile.stamina = int(data.get("stamina", profile.max_stamina))
	profile.max_stamina = int(data.get("max_stamina", profile.max_stamina))
	profile.stages_cleared = int(data.get("stages_cleared", 0))
	profile.herb_garden_level = int(data.get("herb_garden_level", 1))
	profile.pending_quest_count = int(data.get("pending_quest_count", 0))
	var saved_slots: Array = data.get("gem_slots", [])
	for i in mini(saved_slots.size(), profile.gem_slots.size()):
		profile.gem_slots[i] = str(saved_slots[i])
	var saved_hotbar: Array = data.get("hotbar_skill_ids", [])
	for i in mini(saved_hotbar.size(), HOTBAR_SLOT_COUNT):
		profile.hotbar_skill_ids[i] = str(saved_hotbar[i])
	var saved_loop: Array = data.get("loop_skill_ids", [])
	for i in mini(saved_loop.size(), LOOP_SLOT_COUNT):
		profile.loop_skill_ids[i] = str(saved_loop[i])
	profile.main_skill_id = str(data.get("main_skill_id", ""))
	profile.hotbar_page = clampi(int(data.get("hotbar_page", 0)), 0, HOTBAR_PAGES - 1)
	var saved_layout: Variant = data.get("skill_layout", {})
	if saved_layout is Dictionary:
		profile.skill_layout = saved_layout.duplicate(true)
	profile.active_aura_id = str(data.get("active_aura_id", ""))
	profile.storage_extra = clampi(int(data.get("storage_extra", 0)), 0, 5)
	profile.storage.bag_count = 1 + profile.storage_extra
	profile.storage.load_array(data.get("storage", []))
	profile.storage_gold = maxi(0, int(data.get("storage_gold", 0)))
	profile.security_hash = str(data.get("security_hash", ""))
	profile.security_locked = bool(data.get("security_locked", false)) and profile.security_hash != ""
	profile.lead_level = clampi(int(data.get("lead_level", 0)), 0, 100)
	profile.lead_exp = maxi(0, int(data.get("lead_exp", 0)))
	var saved_guild: Variant = data.get("guild", {})
	profile.guild = saved_guild.duplicate(true) if saved_guild is Dictionary else {}
	profile.stall_title = str(data.get("stall_title", ""))
	profile.guild_join_after = int(data.get("guild_join_after", 0))
	profile._migrate_vltk_start_values()
	profile._clamp_skill_levels()
	var saved_settings: Dictionary = data.get("skill_settings", {})
	for key in profile.skill_settings:
		profile.skill_settings[key] = bool(saved_settings.get(key, false))
	return profile

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
## Trang thanh skill đang chọn (0/1).
var hotbar_page: int = 0
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
const INVENTORY_CAPACITY := 60

var gold: int = 0
var jade: int = 0
var stamina: int = 120
var max_stamina: int = 120

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
	b.sect_id = sect_id
	b.skill_levels = skill_levels.duplicate()
	b.camp = get_current_camp()
	## Mọi đồ đang mặc đều có tác dụng — kể cả khi chỉ số tụt dưới yêu cầu (tẩy điểm, tháo món cộng chỉ số):
	## đúng VLTK gốc, yêu cầu CHỈ chặn lúc mặc từ Hành trang vào (equip_from_inventory).
	b.equipment = equipment.duplicate()
	b.active_aura_id = active_aura_id
	return b

## Gán môn phái đã chọn ở màn Chọn Nhân Vật — cập nhật cả sect_id (nguồn sự thật) lẫn sect_name
## (cache hiển thị, CharacterHub đang đọc trực tiếp field này) để luôn đồng bộ.
func set_sect(sect_def: SectDefinition) -> void:
	sect_id = sect_def.id
	sect_name = sect_def.sect_name

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
	var spent_potential := (strength - fresh.strength) + (dexterity - fresh.dexterity) \
			+ (vitality - fresh.vitality) + (energy - fresh.energy)
	potential_points += maxi(spent_potential, 0)
	strength = fresh.strength
	dexterity = fresh.dexterity
	vitality = fresh.vitality
	energy = fresh.energy

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
	main_skill_id = fresh.main_skill_id
	return {"potential": maxi(spent_potential, 0), "skill": spent_skill}

## Khoá JSON là chuỗi (JSON không có khoá số) — from_dict đổi lại về int.
func _equipment_to_dict() -> Dictionary:
	var out := {}
	for part in equipment:
		out[str(part)] = (equipment[part] as ItemInstance).to_dict()
	return out

func get_skill_level(skill_id: String) -> int:
	return int(skill_levels.get(skill_id, 0))

## ---- Trang bị ----
## Thêm vào túi — false nếu túi đầy.
func add_item(item: ItemInstance) -> bool:
	if item == null or inventory.size() >= INVENTORY_CAPACITY:
		return false
	inventory.append(item)
	return true

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
		inventory.append(equipment[part])
	equipment[part] = item
	return ""

## Tháo đồ ở ô `part` về túi — false nếu ô trống hoặc túi đầy.
func unequip(part: int) -> bool:
	if not equipment.has(part) or inventory.size() >= INVENTORY_CAPACITY:
		return false
	inventory.append(equipment[part])
	equipment.erase(part)
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

## Gắn skill vào nút chính — skill đang nằm ở nút phụ nào thì rời nút đó. "" = về đòn chính mặc định.
func set_main_skill(skill_id: String) -> void:
	if skill_id != "":
		clear_hotbar_skill(skill_id)
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

func to_dict() -> Dictionary:
	return {
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
		"active_aura_id": active_aura_id,
		"skill_settings": skill_settings,
		"main_skill_id": main_skill_id,
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
	for item_data in data.get("inventory", []):
		profile.inventory.append(ItemInstance.from_dict(item_data))
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
	profile.main_skill_id = str(data.get("main_skill_id", ""))
	profile.hotbar_page = clampi(int(data.get("hotbar_page", 0)), 0, HOTBAR_PAGES - 1)
	profile.active_aura_id = str(data.get("active_aura_id", ""))
	profile._clamp_skill_levels()
	var saved_settings: Dictionary = data.get("skill_settings", {})
	for key in profile.skill_settings:
		profile.skill_settings[key] = bool(saved_settings.get(key, false))
	return profile

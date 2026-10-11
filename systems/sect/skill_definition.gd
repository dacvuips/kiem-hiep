extends Resource
class_name SkillDefinition
## Dữ liệu THUẦN của 1 chiêu thức thuộc môn phái — 1 mục trong bảng "Kỹ Năng Võ Công" đầy đủ
## (SkillBookScreen). KHÔNG phải mọi SkillDefinition đều hiện ở hotbar ngoài màn chơi — chỉ
## is_main_attack (đòn chính) và 4 skill phụ người chơi tự gắn (PlayerProfile.hotbar_skill_ids,
## lọc bằng can_assign_to_hotbar()) mới hiện ở đó, xem SectSkillController.get_sub_skills(). KHÔNG liên quan/không thay thế SkillGemData của
## gem_system cũ (đã gỡ bỏ).

enum SkillCategory { ACTIVE, PASSIVE }

@export var id: String = ""
@export var skill_name: String = ""
@export var icon: Texture2D
## true = tạm ẩn khỏi bảng "Kỹ Năng Võ Công" (SkillBookScreen) — dữ liệu vẫn còn, chỉ chưa sẵn
## sàng hiển thị (VD chưa có icon/cân bằng số liệu xong). Không ảnh hưởng combat/is_main_attack.
## KHÔNG dùng cho skill con tự động (xem parent_skill_id) — is_hidden=true CHỈ vì chưa sẵn sàng
## hiển thị tạm thời, còn skill con luôn ẩn khỏi lưới chính vĩnh viễn vì lý do khác (được nhúng
## hiển thị trong popup skill cha thay vì đứng riêng — xem SkillBookScreen._build_detail_popup).
@export var is_hidden: bool = false

## id của skill CHA nếu đây là "skill con" tự động kích hoạt kèm (VD nFiveElements/skill_flyevent
## trong VLTK gốc — 1 skill chính bắn ra kèm theo 1 hiệu ứng phụ độc lập, xem ghi chú trong
## docs/vltk_all_sects_skills_reference.md). Rỗng = skill độc lập bình thường, không phải skill
## con của ai. SkillBookScreen dùng field này để NHÚNG toàn bộ thông tin/stat_lines của skill con
## vào NGAY TRONG popup của skill cha (dạng "Tăng 2: <tên skill con>" — đúng bố cục ảnh mẫu VLTK
## gốc), thay vì hiện thành 1 skill riêng biệt trong lưới — is_hidden=true LUÔN đi kèm field này.
@export var parent_skill_id: String = ""
@export_multiline var description: String = ""
@export var is_active: bool = true
## "Lưu phái" hiển thị trong popup chi tiết VLTK gốc, VD "Phi Tiêu/Phi đao/Tự tiến (Ngoại công)"
## hoặc "Hãm Tĩnh (Nội công)" — nguyên văn từ ảnh mẫu game gốc, không suy luận/đoán từ field khác.
@export var school_text: String = ""
## ACTIVE = thi triển được (dù có nằm trong hotbar hay không); PASSIVE = không cast được, chỉ
## cộng chỉ số ngầm khi học (xem passive_*_bonus), tương ứng ô "nội tại" trong ảnh mẫu VLTK.
@export var category: SkillCategory = SkillCategory.ACTIVE
## true = đòn đánh chính của môn phái — dùng được sẵn không cần học (cấp 0 tính như cấp 1), vẫn
## cộng "điểm kỹ năng" được để nâng cấp tới max_level như skill thường.
@export var is_main_attack: bool = false
## true = skill ĐÁNH THƯỜNG chung (VLTK gốc SkillId 1 "Công kích vật lý"): phái nào cũng có, cấp 1, dùng ngay không cần học.
## SectRegistry gắn skill này vào đầu danh sách của MỌI phái (systems/sect/common/basic_attack.tres).
@export var is_basic_attack: bool = false
## KHÔNG CÒN DÙNG — hotbar giờ do người chơi tự gắn (PlayerProfile.hotbar_skill_ids). Giữ field để
## các file .tres cũ vẫn load được.
@export var is_hotbar: bool = false
@export var req_level: int = 1
## Skill cao cấp (bảng SKILL90/SKILL120/SKILL150 của factionhead.lua gốc): đủ cấp thì LĨNH HỘI cấp 1 miễn phí (như đọc
## bí kíp), sau đó KHÔNG cộng điểm kỹ năng để nâng — VLTK gốc tăng cấp các skill này bằng luyện tập. Đánh dấu tự động
## bởi tools/sort_sect_skills.py. Bản debug có nút "Nâng cấp (TEST)" bỏ qua giới hạn để thử skill.
@export var practice_only: bool = false
## Đồng bộ từ Skills.txt bằng tools/sync_skills_from_vltk.py: SkillId gốc, hạn chế vũ khí (EqtLimit: -2 không hạn chế,
## -1 quyền thủ, 0 kiếm, 1 đơn đao, 2 côn bổng, 3 thương, 4 song chùy, 5 song đao, 100 phi tiêu, 101 phi đao, 102 tụ
## tiễn) và hạn chế cưỡi ngựa (HorseLimit 1 = chỉ thi triển khi xuống ngựa, 2 = chỉ khi cưỡi ngựa). Kiểm tra lúc thi triển ở
## get_cast_block_reason() (KSkill::CanCastSkill gốc), gọi từ SectSkillController.
@export var vltk_skill_id: int = 0
@export var weapon_limit: int = -2
@export var horse_limit: int = 0

## Chữ + màu dòng "Hạn chế vũ khí" (GameSetting.ini [WeaponLimit] gốc); "" = không hạn chế.
const WEAPON_LIMIT_TEXT := {
	-1: ["Quyền Thủ", "ff6040"], 0: ["Kiếm", "40e0ff"], 1: ["Đơn Đao", "60ff60"], 2: ["Côn Bổng", "c0a060"],
	3: ["Thương", "ffff40"], 4: ["Song Chùy", "ff80c0"], 5: ["Song Đao", "e0e0e0"], 100: ["Phi Tiêu", "d0a060"],
	101: ["Phi Đao", "60a0ff"], 102: ["Tụ Tiễn", "4080ff"],
}

## Lý do KHÔNG thi triển được ("" = được) theo KSkill::CanCastSkill gốc: `weapon_class` = loại vũ khí đang cầm
## (Equipment.get_weapon_class), `riding` = đang cưỡi ngựa.
func get_cast_block_reason(weapon_class: int, riding: bool) -> String:
	if weapon_limit != -2 and weapon_class != weapon_limit:
		var entry: Array = WEAPON_LIMIT_TEXT.get(weapon_limit, ["đúng loại vũ khí"])
		return "Cần trang bị %s để thi triển" % entry[0]
	if horse_limit == 1 and riding:
		return "Đang cưỡi ngựa, không thể thi triển"
	if horse_limit == 2 and not riding:
		return "Cần cưỡi ngựa để thi triển"
	return ""

func get_weapon_limit_bbcode() -> String:
	if not WEAPON_LIMIT_TEXT.has(weapon_limit):
		return ""
	var entry: Array = WEAPON_LIMIT_TEXT[weapon_limit]
	return "Hạn chế vũ khí: [color=#%s]%s[/color]" % [entry[1], entry[0]]
@export var max_level: int = 10
@export var base_damage: float = 0.0
## Giữ lại field này nhưng KHÔNG dùng để giới hạn thi triển — game không có mana/nội lực. Đây là
## số MÔ PHỎNG dùng cho combat cast (SectSkillController) — số "Tiêu hao nội lực" hiển thị THẬT
## cho người chơi (đúng VLTK gốc, tăng theo cấp) nằm trong stat_lines bên dưới.
@export var mana_cost: float = 0.0
@export var cooldown: float = 1.0
@export var range: float = 100.0
@export var element: ElementTypes.ElementType = ElementTypes.ElementType.THO
## Damage cộng thêm mỗi cấp đã học (level 1 = base_damage, level N = base_damage + growth*(N-1)).
## Đây là số MÔ PHỎNG dùng cho combat cast — số sát thương THẬT hiển thị cho người chơi (VD "Độc
## sát: 29 điểm/lần") nằm trong stat_lines, có thể khác con số này vì VLTK dùng nhiều field damage
## riêng theo hệ (poisondamage_v, colddamage_v...) không quy đổi thẳng 1-1 sang combat game này.
@export var damage_growth_per_level: float = 8.0
## Danh sách "dòng chỉ số" hiển thị trong popup SkillBookScreen (VD "Tăng sát thương vật lý: 20%
## → 80%", "Tiêu hao nội lực: 20 → 60") — lấy NGUYÊN VĂN số liệu thật từ VLTK (script/skill/
## <faction>.lua), linh hoạt vì mỗi skill dùng tổ hợp field khác nhau. Không ảnh hưởng combat cast
## thật (base_damage/mana_cost/cooldown ở trên), chỉ để hiển thị đúng thông tin tham khảo cho
## người chơi giống game gốc.
@export var stat_lines: Array[SkillStatLine] = []
## Scene projectile riêng — để trống dùng scene mặc định của SectSkillCast.
@export var projectile_scene: PackedScene
@export var vfx_hit_name: String = "hit_explosion"
@export var color: Color = Color.WHITE

## ---- Dữ liệu VLTK gốc — nhập tự động bằng tools/import_vltk_hit_effects.py (đừng sửa tay) ----
@export_group("VLTK gốc")
## TOÀN BỘ thuộc tính magic của skill trong lua gốc: {tên: [3 thành phần]}, mỗi thành phần là
## PackedFloat32Array(cấp, giá trị, mã hàm nội suy, ...) — tính ở 1 cấp bằng eval_level_points().
## Ý nghĩa từng tên khi áp vào nhân vật: MagicAttribTable. Thành phần [1] của thuộc tính trạng thái
## (buff/bùa) là THỜI GIAN hiệu lực (frame VLTK, 18 frame/giây).
@export var vltk_attribs: Dictionary = {}
## Cột Skills.txt: skill nhắm kẻ địch / đồng đội / bản thân, và là hào quang (bật/tắt, không thi triển).
@export var target_enemy: bool = false
@export var target_ally: bool = false
@export var target_self: bool = false
@export var is_aura: bool = false
## Cột IsPhysical Skills.txt (bIsPhysical gốc): 1 ngoại công, 0 nội công, -1 chưa ghép được dòng gốc.
@export var vltk_is_physical: int = -1
## Cột MisslesForm (eMisslesForm gốc): 0 tường, 1 thẳng, 2 toả, 3 vòng tròn, 4 ngẫu nhiên, 5 vùng,
## 6 TẠI MỤC TIÊU, 7 TẠI NGƯỜI THI TRIỂN.
@export var vltk_missle_form: int = -1
## Cột AttackRadius: tầm thi triển (pixel bản đồ VLTK).
@export var vltk_attack_radius: int = 0
## Cột StateSpecialId: hiệu ứng hình ảnh trạng thái gốc (chưa có sprite tương ứng, giữ để nối sau).
@export var vltk_state_special_id: int = 0
## Đạn con (Missles.txt): IsRangeDmg = ảnh hưởng cả VÙNG; DmgRange = cạnh vùng vuông tính bằng ô bản đồ
## (KMissle::ProcessCollision quét ±DmgRange/2 ô quanh tâm); CanColFriend giữ để tham khảo.
@export var vltk_damage_range: int = 0
@export var vltk_range_damage: int = 0
@export var vltk_hit_friend: int = 0
@export_group("")

const MF_AT_TARGET := 6
const MF_AT_FIRER := 7
## 1 ô bản đồ VLTK = 32 pixel (REGION_CELL_SIZE_X gốc). Đổi hằng số này nếu tỉ lệ nhân vật trong game
## khác VLTK — mọi phạm vi skill tự co giãn theo.
const VLTK_CELL_PIXELS := 32.0

## Bán kính vùng ảnh hưởng (pixel) — 0 = chỉ 1 mục tiêu. Vùng gốc là hình vuông ±DmgRange/2 ô, quy ra
## bán kính tới mép ô ngoài cùng: (DmgRange/2 + 0.5) ô.
func get_effect_radius_px() -> float:
	if vltk_range_damage == 0 or vltk_damage_range <= 0:
		return 0.0
	return (vltk_damage_range / 2 + 0.5) * VLTK_CELL_PIXELS

const VLTK_GAME_FPS := 18.0  ## GAME_FPS trong GameDataDef.h gốc

## Giá trị 3 thành phần của 1 thuộc tính tại `level` — Vector3i.ZERO nếu skill không có thuộc tính đó.
## Đúng GetSkillLevelData gốc: thành phần thiếu tính là 0.
func get_attrib(attrib_name: String, level: int) -> Vector3i:
	var comps: Array = vltk_attribs.get(attrib_name, [])
	var v := Vector3i.ZERO
	for i in mini(comps.size(), 3):
		v[i] = eval_level_points(comps[i], level)
	return v

func has_attrib(attrib_name: String) -> bool:
	return vltk_attribs.has(attrib_name)

## Thuộc tính của ĐÒN ĐÁNH — đúng danh sách KNpc::AppendSkillEffect gốc xử lý khi skill trúng đích.
## Mọi thuộc tính KHÁC của 1 skill chủ động là thuộc tính TRẠNG THÁI (buff/bùa, có thời gian hiệu lực).
const HIT_ATTRIBS := ["attackrating_p", "attackrating_v", "ignoredefense_p", "magicdamage_v", "seriesdamage_p",
	"deadlystrike_p", "fatallystrike_p", "steallife_p", "stealmana_p", "stealstamina_p", "physicsenhance_p",
	"physicsdamage_v", "colddamage_v", "firedamage_v", "lightingdamage_v", "poisondamage_v", "stun_p",
	"ignorenegativestate_p", "randmove"]

## Skill buff/bùa: chủ động, không phải hào quang, CHỈ có thuộc tính trạng thái (không gây damage).
## target_enemy = bùa (bắn ra, trúng địch thì áp lên địch); còn lại = buff lên chính mình.
func is_state_skill() -> bool:
	if category != SkillCategory.ACTIVE or is_aura or vltk_attribs.is_empty():
		return false
	for attrib_name in vltk_attribs:
		if attrib_name in HIT_ATTRIBS:
			return false
	return true

## Gói trạng thái của skill buff/bùa tại `level`: {"attribs": {tên: Vector3i(giá trị, 0, 0)}, "seconds":
## thời gian hiệu lực} — thời gian lấy thành phần [1] lớn nhất (frame VLTK -> giây).
func get_state_payload(level: int) -> Dictionary:
	var attribs := {}
	var frames := 0
	for attrib_name in vltk_attribs:
		var v := get_attrib(attrib_name, level)
		attribs[attrib_name] = Vector3i(v.x, 0, 0)
		frames = maxi(frames, v.y)
	return {"attribs": attribs, "seconds": frames_to_seconds(frames)}

## Mọi thuộc tính tại `level` — {tên: Vector3i} — để đưa vào MagicAttribTable/CombatantStats.build().
func get_attribs_at_level(level: int) -> Dictionary:
	var out := {}
	for attrib_name in vltk_attribs:
		out[attrib_name] = get_attrib(attrib_name, level)
	return out

## Hàm Link(x, points) của script/skill/head.lua gốc (+ Line/Conic/Extrac): nội suy giữa 2 mốc kề
## nhau theo hàm của mốc sau, ngoài khoảng thì ngoại suy theo 2 mốc đầu/cuối; floor như
## GetSkillLevelData. `points` = PackedFloat32Array(cấp, giá trị, mã hàm, ...). Rỗng -> 0.
static func eval_level_points(points: PackedFloat32Array, level: int) -> int:
	var count := points.size() / 3
	if count == 0:
		return 0
	if count == 1:
		return int(points[1])
	var seg := 1  ## mốc SAU của đoạn dùng để tính
	if level > points[(count - 1) * 3]:
		seg = count - 1
	elif level >= points[0]:
		for i in range(1, count):
			if level <= points[i * 3]:
				seg = i
				break
	var x1 := points[(seg - 1) * 3]
	var y1 := points[(seg - 1) * 3 + 1]
	var x2 := points[seg * 3]
	var y2 := points[seg * 3 + 1]
	var curve := int(points[seg * 3 + 2])
	if is_equal_approx(x1, x2):
		return int(y2)
	if curve == 1:  ## Conic: y = a·x² + c đi qua 2 mốc
		if x1 < 0 or x2 < 0:
			return 0
		return floori((y2 - y1) * level * level / (x2 * x2 - x1 * x1) - (y2 - y1) * x1 * x1 / (x2 * x2 - x1 * x1) + y1)
	return floori((y2 - y1) * (level - x1) / (x2 - x1) + y1)  ## Line / Extrac (gốc tính giống nhau)

static func frames_to_seconds(frames: int) -> float:
	return frames / VLTK_GAME_FPS

## ---- Chỉ áp dụng khi category == PASSIVE — cộng NGẦM vào CombatantStats theo cấp đã học
## (learned_level), xem CombatantStats.from_profile(). Không dùng cho combat cast.
@export_group("Passive bonus (chỉ dùng khi category = PASSIVE)")
@export var passive_attack_bonus: float = 0.0
@export var passive_defense_bonus: float = 0.0
@export var passive_max_hp_bonus: float = 0.0

## Nội suy tuyến tính 1 cặp giá trị (level 1 -> max_level) tại 1 cấp bất kỳ — dùng bởi
## SkillStatLine.format_at_level(). Khớp đúng công thức VLTK gốc (interpolate tuyến tính giữa
## {1, v1} và {max_level, v_max}, floor kết quả).
func interpolate_at_level(value_at_level_1: float, value_at_max_level: float, at_level: int) -> float:
	if max_level <= 1:
		return value_at_level_1
	var t := clampf(float(at_level - 1) / float(max_level - 1), 0.0, 1.0)
	return floorf(lerpf(value_at_level_1, value_at_max_level, t))

## Skill được phép gắn vào nút skill ngoài trận (nút chính lẫn 4 nút phụ): phải thi triển được
## (ACTIVE — kể cả skill buff), không phải skill con tự động/đang ẩn khỏi bảng. Đòn chính mặc định
## (is_main_attack) cũng gắn được, VD chuyển xuống nút phụ khi nút chính đã thay skill khác.
func can_assign_to_hotbar() -> bool:
	return category == SkillCategory.ACTIVE and not is_hidden and parent_skill_id == ""

## Tên hệ trong nhãn "<hệ> sát" (damage tuyệt đối theo nguyên tố — colddamage_v/firedamage_v/
## lightingdamage_v/poisondamage_v gốc VLTK) -> loại damage tương ứng trong CombatFormulas.
const ELEMENT_DAMAGE_NAMES := {
	"Băng": CombatFormulas.DamageType.COLD,
	"Hỏa": CombatFormulas.DamageType.FIRE,
	"Lôi": CombatFormulas.DamageType.LIGHT,
	"Độc": CombatFormulas.DamageType.POISON,
}
const PHYSICS_DAMAGE_LABELS := ["Sát thương vật lý"]
const SCHOOL_OUTER := "outer"  ## ngoại công
const SCHOOL_INNER := "inner"  ## nội công

## Nhãn damage hệ: "Băng sát", "Băng sát - ngoại công", "Băng sát - nội công" (tương tự Hỏa/Lôi/Độc)
## -> {"type": DamageType, "school": SCHOOL_OUTER/SCHOOL_INNER/"" (không ghi)}; {} nếu không phải.
static func parse_element_damage_label(label: String) -> Dictionary:
	var parts := label.split(" - ")
	var head := parts[0].strip_edges()
	if not head.ends_with(" sát"):
		return {}
	var element_name := head.trim_suffix(" sát")
	if not ELEMENT_DAMAGE_NAMES.has(element_name):
		return {}
	var school := ""
	if parts.size() > 1:
		var tail := parts[1].to_lower()
		school = SCHOOL_OUTER if "ngoại công" in tail else (SCHOOL_INNER if "nội công" in tail else "")
	return {"type": ELEMENT_DAMAGE_NAMES[element_name], "school": school}

## Skill ngoại công (bIsPhysical gốc VLTK) hay nội công — theo "Lưu phái" ghi trong school_text
## ("… (Ngoại công)" / "… (Nội công)"). Skill không ghi thì coi là ngoại công nếu có dòng % sát
## thương vật lý (physicsenhance_p chỉ có ở skill ngoại công).
func is_physical() -> bool:
	if vltk_is_physical >= 0:
		return vltk_is_physical == 1
	if "Ngoại công" in school_text:
		return true
	if "Nội công" in school_text:
		return false
	for line in stat_lines:
		if line.label in PHYSICS_DAMAGE_LABELS and line.suffix.strip_edges() == "%":
			return true
	return false

## Số liệu damage THẬT (VLTK) tại 1 cấp, đọc từ chính các dòng stat_lines hiển thị trong popup —
## để combat khớp 100% với số người chơi thấy:
##   physics_enhance: % tăng damage vật lý (physicsenhance_p) — -1.0 nếu skill không có dòng này
##                    (khi đó combat dùng base_damage/damage_growth_per_level mô phỏng cũ).
##   physics_flat:    Vector2i(min, max) damage vật lý tuyệt đối (physicsdamage_v).
##   elements:        CombatFormulas.DamageType -> Vector2i(min, max) damage tuyệt đối theo hệ.
##   deadly_strike:   % tỷ lệ "Tấn công chí mạng" (deadlystrike_p) — 0 nếu không có.
##   five_elements_damage_p: "Ngũ hành tương khắc %" (seriesdamage_p) — 0 nếu không có.
func get_combat_damage_at_level(at_level: int) -> Dictionary:
	var physics_enhance := -1.0
	var physics_flat := Vector2i.ZERO
	var elements := {}
	var deadly_strike := 0
	var five_elements_damage_p := 0
	for line in stat_lines:
		var value_range := stat_line_range(line, at_level)
		if line.label == "Tấn công chí mạng":
			deadly_strike += value_range.x
		elif line.label == "Ngũ hành tương khắc":
			five_elements_damage_p += value_range.x
		elif line.label in PHYSICS_DAMAGE_LABELS:
			if not line.is_range and line.suffix.strip_edges() == "%":
				physics_enhance = maxf(physics_enhance, 0.0) + value_range.x
			else:
				physics_flat += value_range
		else:
			var element_info := parse_element_damage_label(line.label)
			if not element_info.is_empty():
				var damage_type: int = element_info["type"]
				elements[damage_type] = elements.get(damage_type, Vector2i.ZERO) + value_range
	return {"physics_enhance": physics_enhance, "physics_flat": physics_flat, "elements": elements,
			"deadly_strike": deadly_strike, "five_elements_damage_p": five_elements_damage_p}

## Giá trị 1 dòng tại cấp `at_level` dạng Vector2i(min, max) — dòng 1 số thì min == max.
func stat_line_range(line: SkillStatLine, at_level: int) -> Vector2i:
	if line.is_range:
		return Vector2i(int(interpolate_at_level(line.min_at_level_1, line.min_at_max_level, at_level)),
				int(interpolate_at_level(line.max_at_level_1, line.max_at_max_level, at_level)))
	var value := int(interpolate_at_level(line.value_at_level_1, line.value_at_max_level, at_level))
	return Vector2i(value, value)

func get_damage_at_level(at_level: int) -> float:
	return base_damage + damage_growth_per_level * maxf(0.0, float(at_level - 1))

## Tổng % "Hỗ trợ từ các kỹ năng khác" tại 1 cấp — CHIỀU NGƯỢC của "Tăng sát thương kỹ năng liên
## kết #N" (xem SkillStatLine.target_skill_id). Quét TẤT CẢ skill khác trong CÙNG môn phái
## (`all_skills`, dùng đã học ở cấp nào thì tính theo cấp ĐÃ HỌC của skill NGUỒN, không phải cấp
## của skill đang xem — đúng cơ chế gốc KSkillList::GetAddSkillDamage chỉ cộng nếu skill nguồn đã
## học, SkillLevel > 0), cộng dồn value_at_max_level tại learned_level của mọi stat_line có
## target_skill_id == self.id. Trả về 0.0 nếu không có skill nào hỗ trợ (ẩn dòng UI trong trường
## hợp này, xem SkillBookScreen).
func get_support_percent_from_other_skills(all_skills: Array[SkillDefinition], profile: PlayerProfile) -> float:
	var total := 0.0
	for other in all_skills:
		if other.id == id:
			continue
		var other_learned_level := profile.get_skill_level(other.id)
		if other_learned_level <= 0:
			continue
		for stat_line in other.stat_lines:
			if stat_line.target_skill_id == id:
				total += other.interpolate_at_level(stat_line.value_at_level_1, stat_line.value_at_max_level, other_learned_level)
	return total

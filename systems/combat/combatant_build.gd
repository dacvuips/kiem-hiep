extends RefCounted
class_name CombatantBuild
## "Bản dựng" của MỘT bên tham chiến bất kỳ — player, quái, hay NGƯỜI CHƠI KHÁC khi online — chỉ là
## DỮ LIỆU THUẦN (không node/scene), đưa vào CombatantStats.build() để ra chỉ số combat. Đây là điểm
## chung duy nhất: cân bằng/scale/thêm nguồn chỉ số đều sửa ở đây hoặc ở MagicAttribTable, không
## viết bảng riêng cho từng loại quái hay từng player.
##
## Nguồn tạo:
##   - Player cục bộ: PlayerProfile.to_build()
##   - Quái: EnemySpawnEntry.to_build() (chỉ số gốc + tăng trưởng theo cấp + hệ số map + thuộc tính thêm)
##   - Người chơi khác khi online: CombatantBuild.from_dict(dữ liệu server gửi về) — to_dict() là
##     định dạng gửi qua mạng, server tính lại được y hệt (deterministic).

var level: int = 1
var element: ElementTypes.ElementType = ElementTypes.ElementType.KIM
var strength: int = 35
var dexterity: int = 25
var vitality: int = 25
var energy: int = 15
## Giới tính (0 nam / 1 nữ) — chỉ ảnh hưởng thể lực mỗi cấp (level_add.txt: StaminaMale/FemalePerLevel).
var female: bool = false
## Môn phái + cấp skill đã học -> skill NỘI TẠI đã học được cộng vào chỉ số (qua vltk_attribs).
var sect_id: String = ""
var skill_levels: Dictionary = {}  ## skill_id (String) -> cấp (int)
## Phe (Camp.Type) = màu tên — đồng đội là CÙNG phe, xem Camp.relation / CombatTargeting.
var camp: int = Camp.Type.ANIMAL
## Đồ đang mặc — Equipment.Part -> ItemInstance. Cộng chỉ số (gồm dòng ẩn kích hoạt theo ngũ hành) qua
## Equipment.get_attrib_sources; damage vũ khí qua Equipment.get_weapon_damage (CombatantStats.build).
var equipment: Dictionary = {}
## Thuộc tính magic thêm, cố định — {tên VLTK: Vector3i} — VD quái "kháng Hỏa 30%":
## {"fireres_p": Vector3i(30, 0, 0)}; sau này trang bị cũng cộng vào đây.
var extra_attribs: Dictionary = {}
## Hào quang đang bật (skill is_aura) — thuộc tính của nó tính như nguồn cố định khi còn bật.
var active_aura_id: String = ""
## false = không tính đồ ở ô Ngựa (xuống ngựa). Quái/người chơi khác mặc định cưỡi.
var riding: bool = true

## Mọi nguồn thuộc tính CỐ ĐỊNH của bản dựng: thuộc tính thêm + trang bị + skill nội tại đã học + hào quang ĐANG
## BẬT (active_aura_id). Mỗi phần tử {tên: Vector3i}.
func get_permanent_attrib_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if not extra_attribs.is_empty():
		sources.append(extra_attribs)
	if not equipment.is_empty():
		var worn := equipment
		if not riding and equipment.has(Equipment.Part.HORSE):
			worn = equipment.duplicate()
			worn.erase(Equipment.Part.HORSE)
		sources.append_array(Equipment.get_attrib_sources(worn, element))
	var sect := SectRegistry.get_by_id(sect_id) if sect_id != "" else null
	if sect == null:
		return sources
	for skill in sect.skills:
		var aura_on := skill.is_aura and skill.id == active_aura_id
		if not aura_on and (skill.category != SkillDefinition.SkillCategory.PASSIVE or skill.is_aura):
			continue
		var learned := int(skill_levels.get(skill.id, 0))
		if learned > 0 and not skill.vltk_attribs.is_empty():
			sources.append(skill.get_attribs_at_level(learned))
	return sources

func to_dict() -> Dictionary:
	var attribs := {}
	for attrib_name in extra_attribs:
		var v: Vector3i = extra_attribs[attrib_name]
		attribs[attrib_name] = [v.x, v.y, v.z]
	return {
		"level": level, "element": element,
		"strength": strength, "dexterity": dexterity, "vitality": vitality, "energy": energy,
		"sect_id": sect_id, "skill_levels": skill_levels.duplicate(), "extra_attribs": attribs,
		"camp": camp, "active_aura_id": active_aura_id, "riding": riding,
		"equipment": _equipment_to_dict(),
	}

func _equipment_to_dict() -> Dictionary:
	var out := {}
	for part in equipment:
		out[str(part)] = (equipment[part] as ItemInstance).to_dict()
	return out

static func from_dict(data: Dictionary) -> CombatantBuild:
	var b := CombatantBuild.new()
	b.level = int(data.get("level", b.level))
	b.element = int(data.get("element", b.element)) as ElementTypes.ElementType
	b.strength = int(data.get("strength", b.strength))
	b.dexterity = int(data.get("dexterity", b.dexterity))
	b.vitality = int(data.get("vitality", b.vitality))
	b.energy = int(data.get("energy", b.energy))
	b.sect_id = str(data.get("sect_id", ""))
	b.camp = int(data.get("camp", b.camp))
	b.active_aura_id = str(data.get("active_aura_id", ""))
	b.riding = bool(data.get("riding", true))
	var saved_equipment: Dictionary = data.get("equipment", {})
	for part in saved_equipment:
		b.equipment[int(part)] = ItemInstance.from_dict(saved_equipment[part])
	var levels: Dictionary = data.get("skill_levels", {})
	for skill_id in levels:
		b.skill_levels[str(skill_id)] = int(levels[skill_id])
	var attribs: Dictionary = data.get("extra_attribs", {})
	for attrib_name in attribs:
		var arr: Array = attribs[attrib_name]
		b.extra_attribs[str(attrib_name)] = Vector3i(int(arr[0]), int(arr[1]) if arr.size() > 1 else 0, int(arr[2]) if arr.size() > 2 else 0)
	return b

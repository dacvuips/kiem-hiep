extends RefCounted
class_name SectRegistry
## Quét thư mục systems/sect/data/*.tres lúc runtime — thêm môn phái mới sau này chỉ cần thêm
## 1 file .tres vào thư mục đó, không cần sửa code.

const DATA_DIR := "res://systems/sect/data/"
const BASIC_ATTACK_PATH := "res://systems/sect/common/basic_attack.tres"
const BASIC_ATTACK_RANGED_PATH := "res://systems/sect/common/basic_attack_ranged.tres"

static var _cache: Array[SectDefinition] = []
static var _loaded: bool = false

static func load_all() -> Array[SectDefinition]:
	if _loaded:
		return _cache
	_loaded = true
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("SectRegistry: không mở được thư mục '%s'." % DATA_DIR)
		return _cache
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		## Bản đã xuất (game / game server) chỉ còn "x.tres.remap" trong thư mục — vẫn load bằng tên gốc "x.tres".
		file_name = file_name.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			var sect: SectDefinition = load(DATA_DIR + file_name)
			if sect:
				_add_basic_attack(sect)
				_cache.append(sect)
		file_name = dir.get_next()
	return _cache

## 2 skill đánh thường chung (cấp 1: cận chiến SkillId 1 + tầm xa SkillId 2) — gắn vào đầu danh sách skill của mọi phái nếu chưa có.
## Không hiện trong bảng Kỹ năng; nút chính trống thì tự dùng đòn hợp vũ khí (basic_attack_for).
static func _add_basic_attack(sect: SectDefinition) -> void:
	for path in [BASIC_ATTACK_RANGED_PATH, BASIC_ATTACK_PATH]:
		var basic: SkillDefinition = load(path)
		if basic != null and not sect.skills.any(func(s: SkillDefinition) -> bool: return s.id == basic.id):
			sect.skills.insert(0, basic)

## Đánh thường hợp vũ khí đang cầm: phi tiêu / phi đao / tụ tiễn (Equipment.get_weapon_class >= 100) = tầm xa (icon phi đao),
## còn lại (tay không, vũ khí cận chiến) = cận chiến (icon bàn tay).
static func basic_attack_for(equipment: Dictionary) -> SkillDefinition:
	return load(BASIC_ATTACK_RANGED_PATH if Equipment.get_weapon_class(equipment) >= 100 else BASIC_ATTACK_PATH)

static func get_by_id(id: String) -> SectDefinition:
	for sect in load_all():
		if sect.id == id:
			return sect
	return null

static func get_by_element(element: ElementTypes.ElementType) -> Array[SectDefinition]:
	var result: Array[SectDefinition] = []
	for sect in load_all():
		if sect.element == element:
			result.append(sect)
	return result

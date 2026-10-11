extends RefCounted
class_name SectRegistry
## Quét thư mục systems/sect/data/*.tres lúc runtime — thêm môn phái mới sau này chỉ cần thêm
## 1 file .tres vào thư mục đó, không cần sửa code.

const DATA_DIR := "res://systems/sect/data/"
const BASIC_ATTACK_PATH := "res://systems/sect/common/basic_attack.tres"

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
		if file_name.ends_with(".tres"):
			var sect: SectDefinition = load(DATA_DIR + file_name)
			if sect:
				_add_basic_attack(sect)
				_cache.append(sect)
		file_name = dir.get_next()
	return _cache

## Skill đánh thường chung (cấp 1) — gắn vào đầu danh sách skill của mọi phái nếu chưa có.
static func _add_basic_attack(sect: SectDefinition) -> void:
	var basic: SkillDefinition = load(BASIC_ATTACK_PATH)
	if basic == null:
		return
	for skill in sect.skills:
		if skill.is_basic_attack:
			return
	sect.skills.insert(0, basic)

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

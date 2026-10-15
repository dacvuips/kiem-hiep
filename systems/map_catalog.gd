class_name MapCatalog
## Danh mục MAP LUYỆN CÔNG cho màn "Vượt Ải" (tab Thường): data/maps/map_catalog.json do tools/export_training_maps.py ghi —
## map, cấp quái, tên quái lấy từ script server VLTK gốc (script/startgame, AddNpcNew), hình map ở world/maps/map_<số map>/.
##
## Mục = {id, name, kind, level, monster_count, monsters: [{t, name, level, count}], dir}. dir = "" khi map chưa xuất hình (chưa vào được).
## Nhóm cấp ("tier") 1..12 = 1x..12x: cấp quái 10-19 -> 1x, 20-29 -> 2x ... (map gốc cấp 10 là map tân thủ, xếp vào 1x).

const PATH := "res://data/maps/map_catalog.json"
const TIER_COUNT := 12

static var _maps: Array = []
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_maps = parsed.get("maps", [])
		_maps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return [int(a["level"]), int(a["id"])] < [int(b["level"]), int(b["id"])])

static func all() -> Array:
	_ensure()
	return _maps

static func tier_of_level(level: int) -> int:
	@warning_ignore("integer_division")
	return clampi(level / 10, 1, TIER_COUNT)

## Map thuộc nhóm `tier` (1 = 1x), xếp theo cấp rồi số map.
static func in_tier(tier: int) -> Array:
	return all().filter(func(m: Dictionary) -> bool: return tier_of_level(int(m["level"])) == tier)

static func is_playable(entry: Dictionary) -> bool:
	var dir := str(entry.get("dir", ""))
	return dir != "" and FileAccess.file_exists(dir.path_join("map.json"))

## Ảnh mini map của map (đã xuất cùng thư mục map); null nếu chưa có.
static func minimap_texture(entry: Dictionary) -> Texture2D:
	var dir := str(entry.get("dir", ""))
	if dir == "":
		return null
	var path := dir.path_join("minimap.jpg")
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):   ## chưa được Godot nhập (vừa xuất xong, editor chưa mở lại) -> đọc thẳng ảnh
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		return ImageTexture.create_from_image(image) if image != null else null
	return null

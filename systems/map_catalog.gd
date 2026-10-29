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

## Mốc Vượt Ải Thường mở sẵn cho nhân vật cấp `level`: mốc cùng cấp (tier_of_level); mốc đó chưa có map thì lấy mốc có map gần nhất
## (ưu tiên mốc thấp hơn, vd cấp 115 -> 10x).
static func normal_tier_for_level(level: int) -> int:
	var t := tier_of_level(level)
	for d in TIER_COUNT:
		if t - d >= 1 and not in_tier(t - d).is_empty():
			return t - d
		if t + d <= TIER_COUNT and not in_tier(t + d).is_empty():
			return t + d
	return t

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

# ---------------------------------------------------------------- Địa Ngục (tab "Địa Ngục" của màn Vượt Ải)
## Map ĐỊA NGỤC 10x / 11x / 12x: dùng lại map luyện công gốc (gốc không có map cấp 110+), quái nâng lên hell_level của nhóm.
## Mỗi nhóm dùng map khác nhau: 10x = map 8x-9x nâng lên cấp 100, 11x / 12x = map 10x nâng lên 110 / 120.
## Mỗi map chọn độ khó 1-5 sao: máu, sát thương, tỉ lệ rơi đồ của quái nhân đúng số sao; 5 sao mọi món rơi ra đều đủ dòng magic.
## Đổi map của nhóm nào: sửa HELL_MAPS (số map gốc phải có trong map_catalog.json).
const HELL_TIERS := [10, 11, 12]
const HELL_MAX_STARS := 5
const HELL_MAPS := {
	10: [224, 320, 319, 123],            ## Sa Mạc Địa Biểu, Chân Núi Trường Bạch, Lâm Du Quan, Lão Hổ Động
	11: [225, 226, 227, 75, 93, 124],    ## Sa Mạc 1-3, Xi Vưu Động, Tiến Cúc Động, Hiên Viên Động
	12: [321, 322, 336, 340],            ## Trường Bạch Sơn Nam / Bắc, Phong Lăng Độ, Mạc Cao Quật
}

static func hell_level(tier: int) -> int:
	return tier * 10

## Map Địa Ngục của nhóm `tier` (10 / 11 / 12): bản sao mục map gốc + cấp quái mới. Chưa có độ khó — thêm bằng hell_entry().
static func hell_maps(tier: int) -> Array:
	var out := []
	for id in HELL_MAPS.get(tier, []):
		for m in all():
			if int(m["id"]) == int(id):
				var e: Dictionary = m.duplicate(true)
				e["level"] = hell_level(tier)
				e["hell_tier"] = tier
				out.append(e)
				break
	return out

## Mục map để vào (GameManager.field_map): thêm "hell" = {tier, level, stars} — VltkWorld sinh quái theo đó.
static func hell_entry(m: Dictionary, stars: int) -> Dictionary:
	var e: Dictionary = m.duplicate(true)
	var tier := int(m.get("hell_tier", 11))
	stars = clampi(stars, 1, HELL_MAX_STARS)
	e["hell"] = {"tier": tier, "level": hell_level(tier), "stars": stars}
	e["name"] = "%s · Tinh Anh %d★" % [str(m["name"]), stars]
	return e

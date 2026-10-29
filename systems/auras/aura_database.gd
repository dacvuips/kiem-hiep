extends RefCounted
class_name AuraDatabase
## Quản lý toàn bộ danh mục Hào Quang (Aura / Quang Hoàn) VLTK đã trích xuất từ source gốc.

const CATALOG_PATH := "res://data/auras/aura_catalog.json"

static var _cached_catalog: Array = []
static var _by_id: Dictionary = {}
static var _thumb_cache: Dictionary = {}

static func get_all() -> Array:
	_ensure()
	return _cached_catalog

static func get_by_state(state_id: int) -> Dictionary:
	_ensure()
	return _by_id.get(state_id, {})

static func get_categories() -> Array[String]:
	_ensure()
	var cats: Array[String] = ["Tất Cả", "Vòng Sáng", "Phi Phong & Danh Hiệu", "Môn Phái", "VIP & Sự Kiện", "Khác"]
	return cats

static func get_thumb(thumb_res: String) -> Texture2D:
	if thumb_res == "":
		return null
	if _thumb_cache.has(thumb_res):
		return _thumb_cache[thumb_res]

	var tex: Texture2D = null
	if ResourceLoader.exists(thumb_res):
		var r = load(thumb_res)
		if r is Texture2D:
			tex = r
	if tex == null:
		var global_path := ProjectSettings.globalize_path(thumb_res)
		if FileAccess.file_exists(thumb_res):
			var img := Image.load_from_file(global_path)
			if img != null:
				tex = ImageTexture.create_from_image(img)

	if tex != null:
		_thumb_cache[thumb_res] = tex
	return tex

static func _ensure() -> void:
	if not _cached_catalog.is_empty():
		return
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		_cached_catalog = parsed
		for item in _cached_catalog:
			if item is Dictionary and item.has("state_id"):
				_by_id[int(item["state_id"])] = item

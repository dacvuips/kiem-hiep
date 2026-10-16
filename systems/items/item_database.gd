extends RefCounted
class_name ItemDatabase
## Dữ liệu trang bị VLTK gốc (data/items/*.json, sinh bởi tools/import_vltk_items.py) — nạp 1 lần, dùng
## chung (chỉ đọc). Xem docs/vltk_equipment_reference.md.

const EQUIPMENT_PATH := "res://data/items/equipment.json"
const MAGIC_PATH := "res://data/items/magic_attribs.json"
const GOLD_PATH := "res://data/items/gold_equipment.json"
const DESC_PATH := "res://data/items/magic_desc.json"

## EQUIPDETAILTYPE gốc — đồng thời là chỉ số cột tỷ lệ rơi (nType) trong magicattrib.txt.
enum Detail { MELEE, RANGE, ARMOR, RING, AMULET, BOOT, BELT, HELM, CUFF, PENDANT, HORSE }
const DETAIL_NAMES := {
	Detail.MELEE: "Vũ khí", Detail.RANGE: "Ám khí", Detail.ARMOR: "Áo", Detail.RING: "Nhẫn",
	Detail.AMULET: "Dây chuyền", Detail.BOOT: "Giày", Detail.BELT: "Thắt lưng", Detail.HELM: "Mũ",
	Detail.CUFF: "Bao tay", Detail.PENDANT: "Ngọc bội", Detail.HORSE: "Ngựa",
}
## Tên loại cụ thể của vũ khí (ParticularType gốc) — loại khác dùng tên món cấp thấp nhất làm nhãn.
const WEAPON_PARTICULAR_NAMES := {
	Detail.MELEE: {0: "Kiếm", 1: "Đao", 2: "Côn (bổng)", 3: "Thương", 4: "Chùy", 5: "Song đao", 6: "Triền thủ",
		7: "Đao thuẫn", 8: "Thuẫn đao"},
	## 3 Cầm (Tiêu Dao), 4 Cung (Dương Gia) — bản 15 phái.
	Detail.RANGE: {0: "Phi tiêu", 1: "Phi đao", 2: "Tụ tiễn", 3: "Cầm", 4: "Cung"},
}

static var _equipment: Array = []
static var _magic: Array = []
static var _gold: Array = []
static var _desc: Dictionary = {}
## Bộ hoàng kim (Group) -> chỉ số các món trong bộ.
static var _gold_groups: Dictionary = {}
## detail -> particular -> level -> chỉ số trong _equipment
static var _index: Dictionary = {}

static func _ensure_loaded() -> void:
	if not _equipment.is_empty():
		return
	_equipment = _load_json(EQUIPMENT_PATH)
	_magic = _load_json(MAGIC_PATH)
	for i in _equipment.size():
		var e: Dictionary = _equipment[i]
		var by_particular: Dictionary = _index.get_or_add(int(e["detail"]), {})
		var by_level: Dictionary = by_particular.get_or_add(int(e["particular"]), {})
		if not by_level.has(int(e["level"])):
			by_level[int(e["level"])] = i

## Hoàng kim (~5MB) chỉ nạp khi thật sự cần (sinh/hiện đồ hoàng kim).
static func _ensure_gold_loaded() -> void:
	if not _gold.is_empty():
		return
	_gold = _load_json(GOLD_PATH)
	for i in _gold.size():
		var group := int(_gold[i]["group"])
		if group > 0:
			(_gold_groups.get_or_add(group, []) as Array).append(i)

static var _skill_names: Dictionary = {}
static var _remap: Dictionary = {}

## Chỉ số đồ trong save CŨ (dữ liệu trước khi nhập lại bản 15 phái) -> chỉ số hiện tại; -1 = món không còn trong
## dữ liệu mới. `table` = "base" / "gold". Bảng data/items/index_remap.json do tools/import_vltk_items.py sinh.
static func remap_index(table: String, old_index: int) -> int:
	if old_index < 0:
		return old_index
	if _remap.is_empty():
		var file := FileAccess.open("res://data/items/index_remap.json", FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text()) if file else null
		_remap = data if data is Dictionary else {"_": ""}
	var arr: Array = _remap.get(table, [])
	return int(arr[old_index]) if old_index < arr.size() else -1

## Tên kỹ năng VLTK theo SkillId số (Skills.txt) — cho dòng "Kỹ năng [ <tên> ]: +N cấp".
static func get_vltk_skill_name(skill_id: int) -> String:
	if _skill_names.is_empty():
		var file := FileAccess.open("res://data/items/skill_names.json", FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			_skill_names = data if data is Dictionary else {"_": ""}
	return str(_skill_names.get(str(skill_id), ""))

## Mẫu câu hiển thị thuộc tính (settings/MagicDesc.ini gốc) — "" nếu không có.
static func get_desc_template(attrib_name: String) -> String:
	if _desc.is_empty():
		var file := FileAccess.open(DESC_PATH, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			_desc = data if data is Dictionary else {"_": ""}
	return str(_desc.get(attrib_name, ""))

## Các món CÙNG BỘ hoàng kim (mỗi loại đồ 1 món, theo thứ tự ô) — để hiện danh sách bộ trong mô tả.
static func get_gold_set_members(group: int) -> Array[int]:
	_ensure_gold_loaded()
	var out: Array[int] = []
	var seen_details := {}
	for idx in _gold_groups.get(group, []):
		var detail := int(_gold[idx]["detail"])
		if seen_details.has(detail):
			continue
		seen_details[detail] = true
		out.append(idx)
	return out

static func _load_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ItemDatabase: không mở được %s" % path)
		return []
	var data = JSON.parse_string(file.get_as_text())
	return data if data is Array else []

static func get_base(base_index: int) -> Dictionary:
	_ensure_loaded()
	return _equipment[base_index] if base_index >= 0 and base_index < _equipment.size() else {}

## Ảnh vật phẩm (icon hành trang/ô trang bị) từ cột Image gốc — assets/items/icons/<tên file>.png (kích thước gốc,
## có mipmap) và icons_small/ (đã thu nhỏ Lanczos vừa ô hành trang 48px), sinh bởi tools/import_vltk_item_icons.py.
## null nếu món không có ảnh (vài ảnh không có trong dữ liệu gốc).
const ICON_DIR := "res://assets/items/icons/"
const ICON_SMALL_DIR := "res://assets/items/icons_small/"
static var _icons: Dictionary = {}

static func get_icon(base: Dictionary, small: bool = false) -> Texture2D:
	var image: String = base.get("image", "")
	if image == "":
		return null
	## Vật phẩm khác (misc_items.json) có sẵn tên ảnh "icon" (tên ảnh gốc chữ Hán / trùng tên đã đổi sang ASCII).
	var key: String = base.get("icon", "")
	if key == "":
		key = image.replace("\\", "/").get_file().get_basename().to_lower()
	var path := (ICON_SMALL_DIR if small else ICON_DIR) + key + ".png"
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path]

## Kích thước món trong hành trang tính bằng Ô (rộng × cao) — cột Width/Height của bảng đồ gốc. Đồ hoàng kim không có
## cột này trong dữ liệu nhập nên lấy theo kích thước phổ biến nhất của cùng loại (loại + loại cụ thể), rồi cùng loại, rồi 1×1.
static var _kind_sizes: Dictionary = {}

static func size_of(base: Dictionary) -> Vector2i:
	var w := int(base.get("width", 0))
	var h := int(base.get("height", 0))
	if w > 0 and h > 0:
		return Vector2i(w, h)
	_ensure_loaded()
	if _kind_sizes.is_empty():
		var counts := {}
		for e in _equipment:
			var size := Vector2i(int(e.get("width", 1)), int(e.get("height", 1)))
			for key in ["%d:%d" % [int(e["detail"]), int(e["particular"])], str(int(e["detail"]))]:
				var by_size: Dictionary = counts.get_or_add(key, {})
				by_size[size] = int(by_size.get(size, 0)) + 1
		for key in counts:
			var best := Vector2i(1, 1)
			var best_count := -1
			for size in counts[key]:
				if counts[key][size] > best_count:
					best_count = counts[key][size]
					best = size
			_kind_sizes[key] = best
	var detail := int(base.get("detail", -1))
	var particular := int(base.get("particular", 0))
	var by_particular := "%d:%d" % [detail, particular]
	if _kind_sizes.has(by_particular):
		return _kind_sizes[by_particular]
	return _kind_sizes.get(str(detail), Vector2i(1, 1))

static func get_gold(gold_index: int) -> Dictionary:
	_ensure_gold_loaded()
	return _gold[gold_index] if gold_index >= 0 and gold_index < _gold.size() else {}

## Chỉ số hoàng kim của dòng gốc `row` (cột "row" = số dòng trong goldequip.txt, AddGoldItem(0, row + 1) của script gốc). -1 nếu không có.
static func gold_index_of_row(row: int) -> int:
	_ensure_gold_loaded()
	for i in _gold.size():
		if int(_gold[i].get("row", -1)) == row:
			return i
	return -1

## ---- Vật phẩm KHÔNG phải trang bị (misc_items.json: thuốc, khoáng thạch, lệnh bài...) ----
## Mã "genre_detail_particular" (thuốc thêm "_cấp") — ItemInstance lưu mã này (không lưu chỉ số) để nhập lại dữ liệu không lệch.
const MISC_PATH := "res://data/items/misc_items.json"
## Thuốc Tống Kim (tools/import_vltk_songjin_potions.py): nạp chung bảng vật phẩm khác với nguồn "songjin" — giá "points" = điểm tích
## lũy Tống Kim (PlayerProfile.songjin_points), "money" = lượng; mỗi bình 1 ô; "songjin_only" = chỉ dùng trong chiến trường.
const SONGJIN_PATH := "res://data/items/songjin_potions.json"
static var _misc: Dictionary = {}

## ~2.4MB — chỉ nạp khi thật sự cần (tạo/hiện vật phẩm khác).
static func get_misc(misc_id: String) -> Dictionary:
	if _misc.is_empty():
		for m in _load_json(MISC_PATH):
			_misc[str(m["id"])] = m
		for m in _load_json(SONGJIN_PATH):
			var rec: Dictionary = (m as Dictionary).duplicate(true)
			rec["source"] = "songjin"
			rec["intro"] = str(m.get("desc", ""))
			rec["price"] = int(m.get("money", 0))
			rec["width"] = 1
			rec["height"] = 1
			_misc[str(m["id"])] = rec
	return _misc.get(misc_id, {})

## Các món cùng nguồn (cột "source": potion / questkey / magicscript / townportal), đúng thứ tự file gốc.
static func list_misc(source: String) -> Array:
	get_misc("")
	return _misc.values().filter(func(m: Dictionary) -> bool: return m.get("source", "") == source)

## Chỉ số đồ gốc theo (loại chi tiết, loại cụ thể, cấp 1-10) — -1 nếu không có.
static func find_base(detail: int, particular: int, level: int) -> int:
	_ensure_loaded()
	return int(_index.get(detail, {}).get(particular, {}).get(level, -1))

static func get_particulars(detail: int) -> Array:
	_ensure_loaded()
	var keys: Array = _index.get(detail, {}).keys()
	keys.sort()
	return keys

static func get_levels(detail: int, particular: int) -> Array:
	_ensure_loaded()
	var keys: Array = _index.get(detail, {}).get(particular, {}).keys()
	keys.sort()
	return keys

## Nhãn 1 loại cụ thể: tên loại vũ khí, hoặc tên món cấp thấp nhất (VD "Áo — Sa Di phục").
static func get_particular_label(detail: int, particular: int) -> String:
	var names: Dictionary = WEAPON_PARTICULAR_NAMES.get(detail, {})
	if names.has(particular):
		return "%s — %s" % [DETAIL_NAMES.get(detail, "?"), names[particular]]
	var levels := get_levels(detail, particular)
	var first := get_base(find_base(detail, particular, levels[0])) if not levels.is_empty() else {}
	return "%s — %s" % [DETAIL_NAMES.get(detail, "?"), first.get("name", str(particular))]

static func get_magic_records() -> Array:
	_ensure_loaded()
	return _magic

## Chỉ số hoàng kim khớp bộ lọc. `menpai`: -2 = tất cả, -1 = không môn phái, 0-14 = MENPAI_ORDER.
static func find_gold(detail: int, menpai: int = -2, particular: int = -1) -> Array[int]:
	_ensure_gold_loaded()
	var out: Array[int] = []
	for i in _gold.size():
		var g: Dictionary = _gold[i]
		if int(g["detail"]) != detail:
			continue
		if particular >= 0 and int(g["particular"]) != particular:
			continue
		if menpai != -2 and int(g["menpai"]) != menpai:
			continue
		out.append(i)
	return out

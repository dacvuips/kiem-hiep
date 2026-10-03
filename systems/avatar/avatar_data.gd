extends RefCounted
class_name AvatarData
## Dữ liệu nhân vật ghép bộ phận (data/avatar/<gender>.json, sinh bởi tools/import_vltk_avatar.py) + cache texture
## DÙNG CHUNG cho mọi nhân vật: 50 người cùng mặc 1 áo chỉ nạp texture đó 1 lần, tải lười khi lần đầu cần.
##
## Mã hình (res) = chỉ số hàng bảng bộ phận gốc VLTK. Món đồ -> mã hình theo đúng KItemChangeRes.cpp: key =
## particular*10 + level ("0" = không mặc gì). Mã chưa xuất trong đợt hình hiện tại -> lùi về hình mặc định.

const DATA_PATH := "res://data/avatar/%s.json"
## Nơi lưu hình tải về theo nhu cầu (bản online, chưa dùng) — ưu tiên hơn hình đóng gói.
const USER_CACHE_DIR := "user://avatar/%s/"

static var _cache: Dictionary = {}   ## gender -> AvatarData
static var _textures: Dictionary = {}  ## tên file png -> Texture2D (null = không có hình)

var gender: String
var data: Dictionary
var anchor: Vector2
var fps: float = 18.0

static func get_for(gender_name: String) -> AvatarData:
	if not _cache.has(gender_name):
		var d := AvatarData.new()
		d.gender = gender_name
		var text := FileAccess.get_file_as_string(DATA_PATH % gender_name)
		d.data = JSON.parse_string(text) if text != "" else {}
		if d.data.is_empty():
			push_error("AvatarData: thiếu hoặc lỗi %s" % (DATA_PATH % gender_name))
		d.anchor = Vector2(d.data.get("anchor", [160, 200])[0], d.data.get("anchor", [160, 200])[1])
		d.fps = float(d.data.get("fps", 18))
		## JSON đọc mọi số thành float -> đổi danh sách mã đã xuất sang int để has(res) so đúng.
		var exported: Dictionary = d.data.get("exported", {})
		for group in exported:
			var ints: Array[int] = []
			for v in exported[group]:
				ints.append(int(v))
			exported[group] = ints
		_cache[gender_name] = d
	return _cache[gender_name]

## Bộ động tác (stand/run/hurt/die/attack/attack2/cast -> tên động tác gốc) theo mã hình vũ khí; `riding` = đang
## cưỡi ngựa -> bảng liên kết khi cưỡi (mọi vũ khí chung bộ Ride*, riêng ám khí đánh bằng RideMagic).
func get_action_set(weapon_res: int, riding: bool = false) -> Dictionary:
	var per_weapon: Array = data.get("weapon_ride_action_set" if riding else "weapon_action_set", [])
	var sets: Array = data.get("ride_action_sets" if riding else "action_sets", [])
	if per_weapon.is_empty() or sets.is_empty():
		return data["action_sets"][0]
	var idx: int = per_weapon[weapon_res] if weapon_res >= 0 and weapon_res < per_weapon.size() else 0
	if idx < 0:
		idx = per_weapon[0]
	return sets[idx]

## Tên file sprite của 1 bộ phận ở mã hình + động tác gốc ("" = không có lớp này, VD tóc của đồ thường).
func get_sprite_key(part: String, res: int, action: String) -> String:
	var by_res: Dictionary = data.get("sprites", {}).get(part, {})
	return by_res.get(str(res), {}).get(action, "")

func get_shadow_key(action: String) -> String:
	return data.get("shadow", {}).get(action, "")

func get_file(key: String) -> Dictionary:
	return data.get("files", {}).get(key, {})

## Texture 1 sheet, nạp lười + dùng chung. PNG nhân vật để importer "keep" (Godot KHÔNG nhập) -> tự đọc PNG bảng
## màu rồi tạo ImageTexture: bản build nhẹ ~2,4 lần, hình y hệt (đã so từng điểm ảnh).
## Thứ tự tìm: thư mục tải về USER_CACHE_DIR trước (dành cho bản online tải hình theo nhu cầu — chỉ cần ghi PNG vào
## đây là game dùng), rồi tới bản đóng gói res://.
func get_texture(key: String) -> Texture2D:
	var file := key + ".png"
	if _textures.has(file):
		return _textures[file]
	var tex: Texture2D = null
	for dir in [USER_CACHE_DIR % gender, data.get("png_dir", "")]:
		var path: String = dir + file
		if not FileAccess.file_exists(path):
			continue
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			tex = ImageTexture.create_from_image(image)
			break
	_textures[file] = tex
	return tex

## Hình có sẵn trên máy không (đóng gói hoặc đã tải) — bản online dùng để biết cần tải thêm file nào.
func has_texture_file(key: String) -> bool:
	var file := key + ".png"
	return FileAccess.file_exists(USER_CACHE_DIR % gender + file) or FileAccess.file_exists(data.get("png_dir", "") + file)

## Thứ tự lớp (số lớp gốc, sau -> trước) cho động tác gốc, hướng sprite và frame tổng (dir * frame/hướng + frame).
func get_draw_order(action: String, dir: int, global_frame: int) -> Array:
	var order: Dictionary = data.get("draw_order", {}).get(action, {})
	if order.is_empty():
		return []
	var by_frame: Dictionary = order.get("frames", {})
	if by_frame.has(str(global_frame)):
		return by_frame[str(global_frame)]
	return order["dirs"][dir]

## Mã hình có trong đợt xuất không (nhóm "helm"/"armor"/"weapon").
func is_exported(group: String, res: int) -> bool:
	return data.get("exported", {}).get(group, []).has(res)

## Hình khi ô trang bị trống. Ngựa: -1 = không cưỡi.
func default_res(group: String) -> int:
	match group:
		"helm": return int(data["item_res"]["helm"]["0"])
		"armor": return int(data["item_res"]["armor"]["0"])
		"horse": return -1
	return int(data["item_res"]["melee"]["0"])

## Món đồ -> mã hình theo KItemChangeRes ("helm"/"armor"/"melee"/"range"). Mã chưa xuất trong đợt hình: lùi về
## CÙNG LOẠI cấp thấp hơn gần nhất (kiếm cấp 9 -> hình kiếm cấp thấp hơn đã có), rồi dòng đầu (particular 0) cùng
## cấp trở xuống, cuối cùng mới tới hình mặc định.
func res_for_item(kind: String, particular: int, level: int) -> int:
	var group := "weapon" if kind == "melee" or kind == "range" else kind
	var table: Dictionary = data.get("item_res", {}).get(kind, {})
	for p in [particular, 0]:
		for lv in range(level, 0, -1):
			var key := str(p * 10 + lv)
			if table.has(key) and is_exported(group, int(table[key])):
				return int(table[key])
	## Ngựa chưa có hình: vẫn phải cưỡi -> mượn con đầu tiên đã xuất thay vì "không cưỡi".
	if group == "horse":
		var horses: Array = data.get("exported", {}).get("horse", [])
		return horses[0] if not horses.is_empty() else -1
	return default_res(group)

## Đồ HOÀNG KIM có hình riêng (GoldEquipRes, theo số hàng gốc) — -1 nếu không có / chưa xuất trong đợt hình
## (khi đó dùng res_for_item theo loại + cấp của chính món).
func res_for_gold(row: int, group: String) -> int:
	var key := str(row)
	var table: Dictionary = data.get("gold_res", {})
	if table.has(key) and is_exported(group, int(table[key])):
		return int(table[key])
	return -1

extends RefCounted
class_name HudLayout
## Quản lý cấu hình vị trí & kích thước giao diện gameplay (HUD).
## Lưu vào user://settings.cfg (mục [hud_layout]) trên máy người dùng, KHÔNG phụ thuộc tài khoản.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "hud_layout"

const ELEMENTS := {
	# --- CÁC NÚT SKILL ĐÁNH (TỪNG NÚT ĐỘC LẬP) ---
	"skill_main": {
		"title": "Nút Đánh Chính (Võ Công)",
		"desc": "Nút xuất chiêu chính lớn nhất ở góc dưới phải",
		"category": "skill",
		"skill_key": "main",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_s0": {
		"title": "Chiêu 1 (Skill 1)",
		"desc": "Nút kỹ năng chiến đấu ô số 1",
		"category": "skill",
		"skill_key": "s0",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_s1": {
		"title": "Chiêu 2 (Skill 2)",
		"desc": "Nút kỹ năng chiến đấu ô số 2",
		"category": "skill",
		"skill_key": "s1",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_s2": {
		"title": "Chiêu 3 (Skill 3)",
		"desc": "Nút kỹ năng chiến đấu ô số 3",
		"category": "skill",
		"skill_key": "s2",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_s3": {
		"title": "Chiêu 4 (Skill 4)",
		"desc": "Nút kỹ năng chiến đấu ô số 4",
		"category": "skill",
		"skill_key": "s3",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_s4": {
		"title": "Chiêu 5 (Skill 5)",
		"desc": "Nút kỹ năng chiến đấu ô số 5",
		"category": "skill",
		"skill_key": "s4",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_s5": {
		"title": "Chiêu 6 (Skill 6)",
		"desc": "Nút kỹ năng chiến đấu ô số 6",
		"category": "skill",
		"skill_key": "s5",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_s6": {
		"title": "Chiêu 7 (Skill 7)",
		"desc": "Nút kỹ năng chiến đấu ô số 7",
		"category": "skill",
		"skill_key": "s6",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_s7": {
		"title": "Chiêu 8 (Skill 8)",
		"desc": "Nút kỹ năng chiến đấu ô số 8",
		"category": "skill",
		"skill_key": "s7",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_loop0": {
		"title": "Chiêu Liên Tục",
		"desc": "Ô kỹ năng thi triển tự động liên tục khi hồi chiêu",
		"category": "skill",
		"skill_key": "loop0",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_jump": {
		"title": "Nút Nhảy (Khinh Công)",
		"desc": "Nút khinh công / nhảy vượt địa hình (phím Space)",
		"category": "skill",
		"skill_key": "jump",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_horse": {
		"title": "Nút Lên / Xuống Ngựa",
		"desc": "Nút cưỡi ngựa hoặc xuống ngựa di chuyển nhanh (phím M)",
		"category": "skill",
		"skill_key": "horse",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"skill_sit": {
		"title": "Nút Ngồi Xuống (Thiền)",
		"desc": "Nút ngồi phục hồi thể lực / đứng dậy (phím C)",
		"category": "skill",
		"skill_key": "sit",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 300.0,
	},

	# --- CÁC THÀNH PHẦN HUD KHÁC ---
	"top_bar": {
		"title": "Thanh Máu & Năng Lượng",
		"desc": "Thanh sinh lực, nội lực, thể lực, cấp độ và kinh nghiệm",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.75,
		"max_scale": 1.5,
		"range_x": 400.0,
		"range_y": 200.0,
	},
	"minimap": {
		"title": "Bản Đồ Nhỏ (MiniMap)",
		"desc": "Khung bản đồ thu nhỏ góc trên phải, tên map và toạ độ",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.7,
		"max_scale": 1.6,
		"range_x": 500.0,
		"range_y": 300.0,
	},
	"chat_box": {
		"title": "Khung Chat",
		"desc": "Khung trò chuyện hệ thống và thế giới sát đáy màn hình",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"width": 400.0,
		"scale": 1.0,
		"min_scale": 0.8,
		"max_scale": 1.4,
		"min_width": 280.0,
		"max_width": 750.0,
		"range_x": 500.0,
		"range_y": 300.0,
	},
	"quick_items": {
		"title": "Slot Bơm Máu (Thuốc Nhanh)",
		"desc": "4 ô thuốc hồi phục nhanh bên cạnh cụm kỹ năng",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.75,
		"max_scale": 1.4,
		"range_x": 500.0,
		"range_y": 300.0,
	},
	"side_menu": {
		"title": "Các Ô Túi & Tiện Ích",
		"desc": "Hàng nút Nhân vật, Hành trang/Túi, Kỹ năng, Kỳ Trân Các",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.75,
		"max_scale": 1.4,
		"range_x": 500.0,
		"range_y": 300.0,
	},
	"auto_button": {
		"title": "Nút Tự Động (Auto)",
		"desc": "Nút bật/tắt Auto tự đánh",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.75,
		"max_scale": 1.4,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"auto_gear": {
		"title": "Cấu Hình Auto (⚙)",
		"desc": "Nút bánh răng mở bảng thiết lập tự động đánh & bơm thuốc",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.75,
		"max_scale": 1.4,
		"range_x": 400.0,
		"range_y": 300.0,
	},
	"pk_mode": {
		"title": "Trạng Thái Chiến Đấu / Luyện Công (PK)",
		"desc": "Nút trạng thái PK (Luyện Công, Chiến Đấu, Đồ Sát) góc trên trái (phím F9)",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.75,
		"max_scale": 1.5,
		"range_x": 500.0,
		"range_y": 300.0,
	},
	"bottom_bar": {
		"title": "Cụm Thao Tác (Đội / PK / Giao Dịch)",
		"desc": "Hàng nút nhanh ở đáy màn hình cạnh nút Ngồi",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.75,
		"max_scale": 1.4,
		"range_x": 500.0,
		"range_y": 200.0,
	},
	"joystick": {
		"title": "Cần Di Chuyển (Joystick)",
		"desc": "Vùng cần ảo di chuyển nhân vật góc dưới trái",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.75,
		"max_scale": 1.4,
		"range_x": 300.0,
		"range_y": 300.0,
	},
	"exit_button": {
		"title": "Nút Cài Đặt (⚙)",
		"desc": "Nút bánh răng mở bảng Cài Đặt",
		"category": "general",
		"offset_x": 0.0,
		"offset_y": 0.0,
		"scale": 1.0,
		"min_scale": 0.75,
		"max_scale": 1.4,
		"range_x": 400.0,
		"range_y": 200.0,
	},
}

static var _loaded := false
static var _data: Dictionary = {}
static var _listeners: Array[Callable] = []

static func add_listener(c: Callable) -> void:
	if not _listeners.has(c):
		_listeners.append(c)

static func remove_listener(c: Callable) -> void:
	_listeners.erase(c)

static func notify_changed() -> void:
	for c in _listeners:
		if c.is_valid():
			c.call()

static func get_element(id: String) -> Dictionary:
	_ensure_loaded()
	if _data.has(id):
		return _data[id]
	if ELEMENTS.has(id):
		return ELEMENTS[id].duplicate()
	return {"offset_x": 0.0, "offset_y": 0.0, "scale": 1.0}

static func get_skill_element(skill_key: String) -> Dictionary:
	return get_element("skill_" + skill_key)

static func set_element_offset(id: String, offset: Vector2) -> void:
	_ensure_loaded()
	var d: Dictionary = get_element(id).duplicate()
	d["offset_x"] = snappedf(offset.x, 1.0)
	d["offset_y"] = snappedf(offset.y, 1.0)
	_data[id] = d
	_save_element(id, d)
	notify_changed()

static func set_element_scale(id: String, s: float) -> void:
	_ensure_loaded()
	var d: Dictionary = get_element(id).duplicate()
	d["scale"] = snappedf(s, 0.05)
	_data[id] = d
	_save_element(id, d)
	notify_changed()

static func set_element_property(id: String, prop: String, val: Variant) -> void:
	_ensure_loaded()
	var d: Dictionary = get_element(id).duplicate()
	d[prop] = val
	_data[id] = d
	_save_element(id, d)
	notify_changed()

static func reset_element(id: String) -> void:
	_ensure_loaded()
	if ELEMENTS.has(id):
		_data[id] = ELEMENTS[id].duplicate()
		_save_element(id, _data[id])
		notify_changed()

static func reset_all() -> void:
	_ensure_loaded()
	_data.clear()
	for id in ELEMENTS:
		_data[id] = ELEMENTS[id].duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		cfg.erase_section(SECTION)
		cfg.save(SETTINGS_PATH)
	notify_changed()

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_from_file()

static func _load_from_file() -> void:
	_data.clear()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for id in ELEMENTS:
		if cfg.has_section_key(SECTION, id):
			var val: Variant = cfg.get_value(SECTION, id)
			if val is Dictionary:
				var def: Dictionary = ELEMENTS[id].duplicate()
				for k in val:
					def[k] = val[k]
				_data[id] = def

static func _save_element(id: String, val: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION, id, val)
	cfg.save(SETTINGS_PATH)

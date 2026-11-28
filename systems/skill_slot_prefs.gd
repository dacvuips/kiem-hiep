extends RefCounted
class_name SkillSlotPrefs
## Bố cục cụm nút skill do người chơi tự sắp xếp — cài đặt của MÁY, lưu ở user://settings.cfg (mục [skill_slots]),
## KHÔNG nằm trong hồ sơ nhân vật nên không bao giờ gửi lên server (giống HudLayout / GameSettings).
##   layout: khoá ("main", "s0".."s7", "loop0", "sit" / "jump" / "horse") -> [dx, dy] độ dời so với vị trí mặc định.
##   slots:  khoá như trên -> {"on": bool, "size": tỉ lệ} (bật / tắt ô + cỡ ô).
## Chạy kiểm thử (KIEMHIEP_NO_SAVE) chỉ giữ trong bộ nhớ, không ghi file.

const SETTINGS_PATH := "user://settings.cfg"   ## cùng file với HudLayout / GameSettings / MusicManager
const SECTION := "skill_slots"

static var _loaded := false
static var layout: Dictionary = {}
static var slots: Dictionary = {}

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if _no_save():
		return
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var l: Variant = cfg.get_value(SECTION, "layout", {})
	var s: Variant = cfg.get_value(SECTION, "slots", {})
	layout = (l as Dictionary).duplicate(true) if l is Dictionary else {}
	slots = (s as Dictionary).duplicate(true) if s is Dictionary else {}

static func is_empty() -> bool:
	ensure_loaded()
	return layout.is_empty() and slots.is_empty()

## Chuyển 1 lần bố cục cũ còn nằm trong file hồ sơ (bản trước lưu theo nhân vật) sang máy, nếu máy chưa có gì.
static func import_legacy(old_layout: Variant, old_slots: Variant) -> void:
	if not is_empty():
		return
	if old_layout is Dictionary:
		layout = (old_layout as Dictionary).duplicate(true)
	if old_slots is Dictionary:
		slots = (old_slots as Dictionary).duplicate(true)
	if not is_empty():
		save()

static func reset() -> void:
	ensure_loaded()
	layout.clear()
	slots.clear()
	save()

static func save() -> void:
	if _no_save():
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   ## đọc lại trước khi ghi để không đè các mục khác
	cfg.set_value(SECTION, "layout", layout)
	cfg.set_value(SECTION, "slots", slots)
	cfg.save(SETTINGS_PATH)

static func _no_save() -> bool:
	return OS.has_environment("KIEMHIEP_NO_SAVE")

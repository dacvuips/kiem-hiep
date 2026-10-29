extends RefCounted
class_name GameSettings
## Cài đặt của MÁY (không theo nhân vật) — chung file user://settings.cfg với MusicManager & SfxManager (mục [audio]).
## Ở đây: mục [camera] — mức zoom đã chọn và có cho lăn chuột zoom hay không; mục [general] — ngôn ngữ hiển thị. Đọc 1 lần rồi giữ trong bộ nhớ.

const SETTINGS_PATH := "user://settings.cfg"   ## cùng file với MusicManager.SETTINGS_PATH / SfxManager.SETTINGS_PATH
const DEFAULT_ZOOM := 1.1
const DEFAULT_LOCALE := "vi"
## Xa nhất (không cho thu nhỏ thêm): giới hạn vùng nhìn bản đồ để đảm bảo hiệu năng và cân bằng PK.
const ZOOM_MIN := 0.8
const ZOOM_MAX := 1.5

static var _loaded := false
static var _zoom := DEFAULT_ZOOM
static var _wheel_zoom := true
static var _locale := DEFAULT_LOCALE

static func locale() -> String:
	_load()
	return _locale

static func set_locale(code: String) -> void:
	_load()
	_locale = code
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		var mgr: Node = main_loop.root.get_node_or_null("LocalizationManager")
		if mgr != null and mgr.has_method("set_locale"):
			mgr.set_locale(code, true)
			return
	TranslationServer.set_locale(code)
	_write_section("general", "locale", code)

static func camera_zoom() -> float:
	_load()
	return _zoom

static func set_camera_zoom(z: float) -> void:
	_load()
	_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	_write("zoom", _zoom)

static func wheel_zoom() -> bool:
	_load()
	return _wheel_zoom

static func set_wheel_zoom(on: bool) -> void:
	_load()
	_wheel_zoom = on
	_write("wheel_zoom", on)

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_zoom = clampf(float(cfg.get_value("camera", "zoom", DEFAULT_ZOOM)), ZOOM_MIN, ZOOM_MAX)
	_wheel_zoom = bool(cfg.get_value("camera", "wheel_zoom", true))
	_locale = str(cfg.get_value("general", "locale", DEFAULT_LOCALE))

## Đọc lại file trước khi ghi để không đè mục [audio] của MusicManager.
static func _write(key: String, value: Variant) -> void:
	_write_section("camera", key, value)

static func _write_section(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(section, key, value)
	cfg.save(SETTINGS_PATH)

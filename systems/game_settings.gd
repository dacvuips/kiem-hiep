extends RefCounted
class_name GameSettings
## Cài đặt của MÁY (không theo nhân vật) — chung file user://settings.cfg với MusicManager (mục [audio]).
## Ở đây: mục [camera] — mức zoom đã chọn và có cho lăn chuột zoom hay không. Đọc 1 lần rồi giữ trong bộ nhớ.

const SETTINGS_PATH := "user://settings.cfg"   ## cùng file với MusicManager.SETTINGS_PATH
const DEFAULT_ZOOM := 0.8
const ZOOM_MIN := 0.225
const ZOOM_MAX := 1.5

static var _loaded := false
static var _zoom := DEFAULT_ZOOM
static var _wheel_zoom := true

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

## Đọc lại file trước khi ghi để không đè mục [audio] của MusicManager.
static func _write(key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("camera", key, value)
	cfg.save(SETTINGS_PATH)

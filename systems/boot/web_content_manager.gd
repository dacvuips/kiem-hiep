extends Node

## WebContentManager (ContentManager) - Quản lý tải ngầm và nạp gói tài nguyên thế giới (Content Packs).
## - Trên Web: Tải ngầm content.pck qua CacheStorage (JavaScript worker/stream).
## - Trên Android / Native Launcher: Tải ngầm các gói (avatar, monster, skill_fx, maps, audio, items)
##   lưu vào user://content/ và nạp nóng qua ProjectSettings.load_resource_pack.
## Giúp mở màn hình Login / Chọn Server / Tạo nhân vật chỉ trong 2-3s (~120MB),
## trong khi toàn bộ thế giới (~1.2GB) được tải ngầm dưới nền.

signal progress_updated(percent: int, loaded_bytes: int, total_bytes: int, speed_str: String)
signal content_loaded

const CONTENT_DIR := "user://content"
const MANIFEST_PATH := "user://content/manifest.json"

var is_web: bool = false
var is_native_streaming: bool = false
var is_ready: bool = false

var progress_percent: int = 0
var loaded_bytes: int = 0
var total_bytes: int = 0
var download_speed: String = ""

var _poll_timer: Timer
var _modal_instance: CanvasLayer = null
var _pending_callbacks: Array[Callable] = []

var _badge_layer: CanvasLayer
var _badge_label: Label
var _badge_panel: PanelContainer

# Native download state
var _native_http: HTTPRequest = null
var _manifest: Dictionary = {}
var _missing_packs: Array = []
var _current_pack: Dictionary = {}
var _total_native_bytes: int = 0
var _already_dl_bytes: int = 0
var _last_sample_bytes: int = 0
var _sample_timer: float = 0.0
var _is_downloading_pack: bool = false
var _retry_count: int = 0

func _ready() -> void:
	# Chạy trong Godot Editor: toàn bộ tài nguyên res:// đã có sẵn trên ổ đĩa, bỏ qua tải ngầm
	if OS.has_feature("editor"):
		print("[ContentManager] Chạy trong Godot Editor (Dev Mode) -> Bỏ qua tải ngầm, sẵn sàng 100%.")
		is_ready = true
		content_loaded.emit()
		return

	is_web = OS.has_feature("web")
	if is_web:
		_create_status_badge()
		_start_polling()
		return

	# Native (Android / Launcher PC)
	_init_native_content_streaming()

func _create_status_badge() -> void:
	if _badge_layer and is_instance_valid(_badge_layer):
		return
	_badge_layer = CanvasLayer.new()
	_badge_layer.layer = 90
	add_child(_badge_layer)
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_badge_layer.add_child(margin)
	
	_badge_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.03, 0.85)
	sb.border_color = Color(0.85, 0.65, 0.25, 0.45)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_badge_panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(_badge_panel)
	
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 8)
	inner.add_theme_constant_override("margin_right", 8)
	inner.add_theme_constant_override("margin_top", 4)
	inner.add_theme_constant_override("margin_bottom", 4)
	_badge_panel.add_child(inner)
	
	_badge_label = Label.new()
	_badge_label.text = "⚡ Đang kết nối tài nguyên thế giới..."
	_badge_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_badge_label.add_theme_font_size_override("font_size", 11)
	inner.add_child(_badge_label)

func _update_badge() -> void:
	if not _badge_label or not is_instance_valid(_badge_label):
		return
	if is_ready:
		_badge_label.text = "✅ Tài nguyên thế giới đã sẵn sàng"
		_badge_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		var tween := create_tween()
		tween.tween_interval(2.5)
		tween.tween_property(_badge_panel, "modulate:a", 0.0, 0.6)
		tween.tween_callback(func(): 
			if _badge_layer and is_instance_valid(_badge_layer):
				_badge_layer.queue_free()
		)
	else:
		if download_speed != "":
			_badge_label.text = "⚡ Tải ngầm thế giới: %d%% (%s)" % [progress_percent, download_speed]
		else:
			_badge_label.text = "⚡ Tải ngầm thế giới: %d%%" % progress_percent

# ========================================================
# WEB STREAMING (JavaScript CacheStorage)
# ========================================================

func _start_polling() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.25
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_tick)
	_on_poll_tick()

func _on_poll_tick() -> void:
	if is_ready:
		if _poll_timer:
			_poll_timer.stop()
		return
	
	if not JavaScriptBridge:
		is_ready = true
		_flush_callbacks()
		return
	
	var is_done = JavaScriptBridge.eval("Boolean(window.__CONTENT_PCK_STATUS && window.__CONTENT_PCK_STATUS.is_ready)")
	var pct = JavaScriptBridge.eval("Number(window.__CONTENT_PCK_STATUS ? window.__CONTENT_PCK_STATUS.percent : 0)")
	var loaded = JavaScriptBridge.eval("Number(window.__CONTENT_PCK_STATUS ? window.__CONTENT_PCK_STATUS.loaded : 0)")
	var total = JavaScriptBridge.eval("Number(window.__CONTENT_PCK_STATUS ? window.__CONTENT_PCK_STATUS.total : 0)")
	var speed = JavaScriptBridge.eval("String(window.__CONTENT_PCK_STATUS ? window.__CONTENT_PCK_STATUS.speed : '')")
	
	progress_percent = int(pct) if pct != null else 0
	loaded_bytes = int(loaded) if loaded != null else 0
	total_bytes = int(total) if total != null else 0
	download_speed = str(speed) if speed != null else ""
	
	progress_updated.emit(progress_percent, loaded_bytes, total_bytes, download_speed)
	_update_badge()
	
	if bool(is_done):
		_mount_content_pack()

func _mount_content_pack() -> void:
	if is_ready:
		return
	
	var pack_path := "/content.pck"
	var mounted := false
	if FileAccess.file_exists(pack_path):
		mounted = ProjectSettings.load_resource_pack(pack_path, false)
	elif FileAccess.file_exists("res://content.pck"):
		mounted = ProjectSettings.load_resource_pack("res://content.pck", false)
	
	if mounted:
		print("[WebContentManager] Đã mount gói tài nguyên thế giới thành công!")
		is_ready = true
		content_loaded.emit()
		_update_badge()
		_flush_callbacks()
	else:
		push_warning("[WebContentManager] Chưa tìm thấy / mount được /content.pck, thử lại lần sau...")

# ========================================================
# NATIVE / ANDROID STREAMING (Background HTTPRequest)
# ========================================================

func _init_native_content_streaming() -> void:
	# Nếu không có manifest.json trong user://content hoặc đang chạy trong Godot Editor
	if OS.has_feature("editor") or not FileAccess.file_exists(MANIFEST_PATH):
		print("[ContentManager] Không chạy qua Launcher (chế độ phát triển trực tiếp) -> Đánh dấu sẵn sàng.")
		is_ready = true
		content_loaded.emit()
		return
	
	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(manifest_text)
	if not parsed is Dictionary:
		is_ready = true
		return
	
	_manifest = parsed as Dictionary
	var packs: Array = _manifest.get("packs", [])
	
	_missing_packs.clear()
	_total_native_bytes = 0
	_already_dl_bytes = 0
	
	for p_var in packs:
		if not p_var is Dictionary:
			continue
		var p: Dictionary = p_var
		if p.get("name") == "core":
			continue # core đã được launcher nạp trước
		
		var file_name: String = str(p.get("file", ""))
		var size: int = int(p.get("size", 0))
		var file_path: String = CONTENT_DIR.path_join(file_name)
		
		if FileAccess.file_exists(file_path) and _file_size(file_path) == size:
			# Đã có sẵn trên máy -> nạp luôn vào bộ nhớ game
			var ok := ProjectSettings.load_resource_pack(file_path, false)
			print("[ContentManager] Nạp gói tài nguyên sẵn có: %s -> %s" % [file_name, ok])
		else:
			# Chưa có hoặc tải dở -> đưa vào hàng đợi tải ngầm
			_missing_packs.append(p)
			_total_native_bytes += size
	
	if _missing_packs.is_empty():
		print("[ContentManager] Toàn bộ gói tài nguyên thế giới đã có sẵn trên thiết bị!")
		is_ready = true
		content_loaded.emit()
		return
	
	# Cần tải ngầm các gói còn lại
	is_native_streaming = true
	is_ready = false
	total_bytes = _total_native_bytes
	loaded_bytes = 0
	
	_create_status_badge()
	_native_http = HTTPRequest.new()
	_native_http.timeout = 120.0
	add_child(_native_http)
	_native_http.request_completed.connect(_on_native_pack_completed)
	
	set_process(true)
	_download_next_native_pack()

func _download_next_native_pack() -> void:
	if _missing_packs.is_empty():
		print("[ContentManager] Hoàn tất toàn bộ tải ngầm tài nguyên thế giới!")
		is_ready = true
		is_native_streaming = false
		set_process(false)
		_update_badge()
		content_loaded.emit()
		_flush_callbacks()
		return
	
	_current_pack = _missing_packs[0]
	var file_name: String = str(_current_pack.get("file", ""))
	var part_path: String = CONTENT_DIR.path_join(file_name + ".part")
	
	var base_url := str(_manifest.get("files_base", ""))
	if not (base_url.begins_with("https://") or base_url.begins_with("http://")):
		var acc_url := "https://kiem-hiep-api.viettheo.site"
		if AccountApi and AccountApi.has_method("get_base_url"):
			var u: String = AccountApi.get_base_url()
			if u != "":
				acc_url = u
		base_url = acc_url.trim_suffix("/") + "/client/files/"
	var url := base_url.trim_suffix("/") + "/" + file_name
	
	_is_downloading_pack = true
	_native_http.download_file = part_path
	print("[ContentManager] Đang tải ngầm gói %s (%s)..." % [_current_pack.get("name"), file_name])
	var err := _native_http.request(url)
	if err != OK:
		push_error("[ContentManager] Request lỗi %d, thử lại sau 3s..." % err)
		_is_downloading_pack = false
		await get_tree().create_timer(3.0).timeout
		_download_next_native_pack()

func _on_native_pack_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_is_downloading_pack = false
	var file_name: String = str(_current_pack.get("file", ""))
	var size: int = int(_current_pack.get("size", 0))
	var part_path: String = CONTENT_DIR.path_join(file_name + ".part")
	var final_path: String = CONTENT_DIR.path_join(file_name)
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if _file_size(part_path) == size:
			var da := DirAccess.open(CONTENT_DIR)
			if da:
				if da.file_exists(file_name):
					da.remove(file_name)
				da.rename(file_name + ".part", file_name)
			
			var ok := ProjectSettings.load_resource_pack(final_path, false)
			print("[ContentManager] Nạp thành công gói %s -> %s" % [file_name, ok])
			
			_already_dl_bytes += size
			_retry_count = 0
			_missing_packs.pop_front()
			_download_next_native_pack()
			return
		else:
			push_warning("[ContentManager] Gói %s sai kích thước, tải lại..." % file_name)
	else:
		push_warning("[ContentManager] Tải gói %s thất bại (mã %d), thử lại..." % [file_name, response_code])
	
	_retry_count += 1
	var delay: float = minf(10.0, 2.0 * float(_retry_count))
	await get_tree().create_timer(delay).timeout
	_download_next_native_pack()

func _process(delta: float) -> void:
	if not is_native_streaming or is_ready or not _is_downloading_pack or not _native_http:
		return
	
	var cur_chunk: int = _native_http.get_downloaded_bytes()
	if cur_chunk < 0:
		cur_chunk = 0
	
	var total_dl := _already_dl_bytes + cur_chunk
	loaded_bytes = total_dl
	total_bytes = _total_native_bytes
	
	if _total_native_bytes > 0:
		progress_percent = clamp(int(float(total_dl) / float(_total_native_bytes) * 100), 0, 99)
	
	_sample_timer += delta
	if _sample_timer >= 0.5:
		var bytes_diff := total_dl - _last_sample_bytes
		var speed_bytes_per_sec := float(bytes_diff) / _sample_timer
		download_speed = _format_speed(speed_bytes_per_sec)
		_last_sample_bytes = total_dl
		_sample_timer = 0.0
		_update_badge()
		progress_updated.emit(progress_percent, loaded_bytes, total_bytes, download_speed)

func _format_speed(bytes_per_sec: float) -> String:
	if bytes_per_sec >= 1048576.0:
		return "%.1f MB/s" % (bytes_per_sec / 1048576.0)
	elif bytes_per_sec >= 1024.0:
		return "%.0f KB/s" % (bytes_per_sec / 1024.0)
	return "%.0f B/s" % bytes_per_sec

func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f != null else 0

# ========================================================
# CHỐT CHẶN AN TOÀN TRƯỚC KHI VÀO GAME
# ========================================================

func _flush_callbacks() -> void:
	var cbs := _pending_callbacks.duplicate()
	_pending_callbacks.clear()
	for cb in cbs:
		if cb.is_valid():
			cb.call()

func ensure_ready(caller: Node, on_ready_callback: Callable) -> void:
	if is_ready or OS.has_feature("editor"):
		is_ready = true
		on_ready_callback.call()
		return
	
	_pending_callbacks.append(on_ready_callback)
	_show_modal(caller)

func _show_modal(caller: Node) -> void:
	if _modal_instance and is_instance_valid(_modal_instance):
		return
	
	var modal_script = preload("res://ui/common/content_download_modal.gd")
	var modal = modal_script.new()
	var root = caller.get_tree().root
	root.add_child(modal)
	_modal_instance = modal

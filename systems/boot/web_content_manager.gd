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
const INSTALLED_PATH := "user://content/installed.json"
## Gói HTTP 4xx (máy chủ đã xoá bản cũ...) thử chừng này lần rồi bỏ qua, không kẹt vòng tải.
const MAX_CLIENT_ERROR_TRIES := 3

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
var _manifest: Dictionary = {}
var _missing_packs: Array = []
var _current_pack: Dictionary = {}
var _total_native_bytes: int = 0
var _already_dl_bytes: int = 0
var _last_sample_bytes: int = 0
var _sample_timer: float = 0.0
var _is_downloading_pack: bool = false
var _retry_count: int = 0
var _streaming_loop_running: bool = false
## Byte của bản sau (chỉ tải, không nạp) — không tính vào tiến độ của cổng chọn nhân vật.
var _next_bytes: int = 0
## Đang tải gói của bản sau: không cập nhật tiến độ cổng / huy hiệu.
var _quiet: bool = false
## Đã tải xong bản cập nhật, chờ mở lại app.
var update_downloaded: bool = false

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
	if OS.has_feature("editor"):
		print("[ContentManager] Chạy trong Godot Editor -> Đánh dấu sẵn sàng.")
		is_ready = true
		content_loaded.emit()
		_flush_callbacks()
		return

	if not FileAccess.file_exists(MANIFEST_PATH):
		# Lần mở app đầu sau khi cài, autoload này chạy TRƯỚC khi launcher kịp ghi manifest.json.
		# Trên thiết bị thật: KHÔNG đánh dấu sẵn sàng (để cổng ở màn chọn nhân vật chặn lại), chờ manifest rồi tải.
		if OS.has_feature("android") or OS.has_feature("ios"):
			print("[ContentManager] Chưa có manifest từ launcher -> chờ rồi tải ngầm (cổng vào game đang đóng).")
			is_ready = false
			_wait_for_manifest_then_stream()
			return
		print("[ContentManager] Không chạy qua Launcher (chế độ phát triển trực tiếp) -> Đánh dấu sẵn sàng.")
		is_ready = true
		content_loaded.emit()
		_flush_callbacks()
		return
	
	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(manifest_text)
	if not parsed is Dictionary:
		is_ready = true
		_flush_callbacks()
		return
	
	_manifest = parsed as Dictionary
	# Bản ĐANG CHẠY = installed.json (launcher đã nạp core của bản này). Gói của bản này thiếu -> tải rồi NẠP, cổng chọn
	# nhân vật chờ. Gói của BẢN SAU (manifest.json mới hơn) -> chỉ tải về máy, KHÔNG nạp: launcher dùng ở lần mở app sau.
	# Không bao giờ nạp core/gói của bản khác lúc game đang chạy (script cũ kẹt lại -> văng, lỗi 2026-11-28).
	var current: Array = _manifest.get("packs", [])
	var inst: Variant = JSON.parse_string(FileAccess.get_file_as_string(INSTALLED_PATH)) 			if FileAccess.file_exists(INSTALLED_PATH) else null
	if inst is Dictionary and (inst as Dictionary).get("packs") is Array:
		current = (inst as Dictionary)["packs"]
	var current_files := {}
	for p_var in current:
		if p_var is Dictionary:
			current_files[str((p_var as Dictionary).get("file", ""))] = true

	_missing_packs.clear()
	_total_native_bytes = 0
	_already_dl_bytes = 0
	_next_bytes = 0

	for p_var in current:
		if not p_var is Dictionary:
			continue
		var p: Dictionary = (p_var as Dictionary).duplicate()
		if p.get("name") == "core":
			continue # core của bản này launcher đã nạp
		var file_name: String = str(p.get("file", ""))
		var size: int = int(p.get("size", 0))
		var file_path: String = CONTENT_DIR.path_join(file_name)
		if FileAccess.file_exists(file_path) and _file_size(file_path) == size:
			var ok := ProjectSettings.load_resource_pack(file_path, false)
			print("[ContentManager] Nạp gói tài nguyên sẵn có: %s -> %s" % [file_name, ok])
		else:
			p["_mount"] = true
			_missing_packs.append(p)
			_total_native_bytes += size

	for p_var in _manifest.get("packs", []):
		if not p_var is Dictionary:
			continue
		var p: Dictionary = (p_var as Dictionary).duplicate()
		var file_name: String = str(p.get("file", ""))
		var file_path: String = CONTENT_DIR.path_join(file_name)
		if current_files.has(file_name) or (FileAccess.file_exists(file_path) and _file_size(file_path) == int(p.get("size", 0))):
			continue
		p["_mount"] = false
		_missing_packs.append(p)
		_next_bytes += int(p.get("size", 0))

	if _total_native_bytes == 0:
		print("[ContentManager] Gói của bản đang chạy đã đủ trên thiết bị!")
		is_ready = true
		content_loaded.emit()
		_flush_callbacks()
		if _missing_packs.is_empty():
			return
		print("[ContentManager] Có bản cập nhật %d -> tải ngầm %d gói (dùng ở lần mở app sau)." % [
				int(_manifest.get("version", 0)), _missing_packs.size()])

	# Đợi đăng nhập xong mới bắt đầu tải ngầm gói tài nguyên thế giới để tránh nghẽn mạng lúc đăng nhập
	var api = get_node_or_null("/root/AccountApi")
	if api == null or not api.is_logged_in():
		print("[ContentManager] Chưa đăng nhập -> Tạm hoãn tải ngầm gói tài nguyên thế giới.")
		if api != null and api.has_signal("logged_in") and not api.logged_in.is_connected(_start_native_streaming):
			api.logged_in.connect(_start_native_streaming, CONNECT_ONE_SHOT)
		if _total_native_bytes == 0:
			# Chỉ còn bản sau: chơi Offline thì không bao giờ đăng nhập -> vẫn tải sau một lúc.
			get_tree().create_timer(15.0).timeout.connect(_start_native_streaming)
		return

	_start_native_streaming()

func _wait_for_manifest_then_stream() -> void:
	for _i in 120:
		await get_tree().create_timer(1.0).timeout
		if FileAccess.file_exists(MANIFEST_PATH):
			print("[ContentManager] Launcher đã ghi manifest -> bắt đầu tải ngầm.")
			_init_native_content_streaming()
			return
	# Quá lâu vẫn không có manifest (không chạy qua launcher) -> không có gì để chờ, mở cổng.
	print("[ContentManager] Hết thời gian chờ manifest từ launcher -> mở cổng.")
	is_ready = true
	content_loaded.emit()
	_flush_callbacks()

func _start_native_streaming() -> void:
	if _streaming_loop_running or _missing_packs.is_empty():
		return
	is_native_streaming = true
	is_ready = _total_native_bytes == 0
	total_bytes = _total_native_bytes
	loaded_bytes = _already_dl_bytes
	
	if not is_ready:
		_create_status_badge()
	_run_native_download_loop()

func _get_pack_url(file_name: String) -> String:
	var base_url := str(_manifest.get("files_base", ""))
	if not (base_url.begins_with("https://") or base_url.begins_with("http://")):
		var acc_url := "https://kiem-hiep-api.viettheo.site"
		var api = get_node_or_null("/root/AccountApi")
		if api != null and api.has_method("get_base_url"):
			var u: String = api.get_base_url()
			if u != "":
				acc_url = u
		base_url = acc_url.trim_suffix("/") + "/client/files/"
	return base_url.trim_suffix("/") + "/" + file_name

func _parse_url(url: String) -> Dictionary:
	var tls := url.begins_with("https://")
	if not tls and not url.begins_with("http://"):
		return {}
	var rest := url.substr(8 if tls else 7)
	var slash := rest.find("/")
	var host := rest if slash < 0 else rest.substr(0, slash)
	var path := "/" if slash < 0 else rest.substr(slash)
	var port := 443 if tls else 80
	var colon := host.rfind(":")
	if colon > 0:
		port = int(host.substr(colon + 1))
		host = host.substr(0, colon)
	if host.is_empty() or port <= 0:
		return {}
	return {"tls": tls, "host": host, "port": port, "path": path}

func _compute_sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var length := f.get_length()
	var t := Time.get_ticks_msec()
	while f.get_position() < length:
		ctx.update(f.get_buffer(1 << 20))
		if Time.get_ticks_msec() - t > 12:
			await get_tree().process_frame
			t = Time.get_ticks_msec()
	f.close()
	return ctx.finish().hex_encode()

func _download_file_resumable(url: String, part_path: String, size: int) -> String:
	var u := _parse_url(url)
	if u.is_empty():
		return "URL không hợp lệ: " + url
	
	var have := _file_size(part_path) if FileAccess.file_exists(part_path) else 0
	if have > size:
		DirAccess.remove_absolute(part_path)
		have = 0
	
	if have == size:
		return ""
	
	var http := HTTPClient.new()
	http.read_chunk_size = 1 << 18 # 256KB
	var tls_opts = TLSOptions.client() if u["tls"] else null
	var err := http.connect_to_host(u["host"], u["port"], tls_opts)
	if err != OK:
		return "Không kết nối được host %s (mã %d)" % [u["host"], err]
	
	var t0 := Time.get_ticks_msec()
	while http.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		http.poll()
		if Time.get_ticks_msec() - t0 > 15000:
			http.close()
			return "Timeout kết nối máy chủ"
		await get_tree().process_frame
	
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		return "Kết nối thất bại (status %d)" % http.get_status()
	
	var headers := PackedStringArray(["User-Agent: KiemHiepClient/1.0"])
	if have > 0:
		headers.append("Range: bytes=%d-" % have)
	
	err = http.request(HTTPClient.METHOD_GET, u["path"], headers)
	if err != OK:
		http.close()
		return "Không gửi được request (mã %d)" % err
	
	t0 = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		if Time.get_ticks_msec() - t0 > 15000:
			http.close()
			return "Timeout phản hồi từ máy chủ"
		await get_tree().process_frame
	
	if not http.has_response():
		http.close()
		return "Máy chủ không có phản hồi"
	
	var code := http.get_response_code()
	var f: FileAccess = null
	if code == 206 and have > 0:
		f = FileAccess.open(part_path, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	elif code == 200:
		have = 0
		f = FileAccess.open(part_path, FileAccess.WRITE)
	elif code == 416:
		http.close()
		DirAccess.remove_absolute(part_path)
		return "Range không khớp (416), xóa part tải lại"
	else:
		http.close()
		return "Máy chủ báo lỗi HTTP %d" % code
	
	if f == null:
		http.close()
		return "Không thể mở file ghi: %s" % part_path
	
	var last_data := Time.get_ticks_msec()
	var frame_t := last_data
	var speed_calc_t := last_data
	var speed_calc_bytes := have
	
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		if http.get_status() != HTTPClient.STATUS_BODY:
			break
		
		var chunk := http.read_response_body_chunk()
		var now := Time.get_ticks_msec()
		
		if chunk.is_empty():
			if now - last_data > 20000: # 20 giây idle timeout
				break
			await get_tree().process_frame
			frame_t = Time.get_ticks_msec()
			continue
		
		f.store_buffer(chunk)
		if f.get_error() != OK:
			f.close()
			http.close()
			return "Lỗi ghi dữ liệu vào máy (mã %d)" % f.get_error()
		
		have += chunk.size()
		last_data = now
		
		# Cập nhật tốc độ & tiến độ mỗi 0.5s
		if now - speed_calc_t >= 500:
			var delta_s := float(now - speed_calc_t) / 1000.0
			var bytes_diff := have - speed_calc_bytes
			download_speed = _format_speed(float(bytes_diff) / delta_s)
			speed_calc_t = now
			speed_calc_bytes = have
			
			loaded_bytes = _already_dl_bytes + have
			if _total_native_bytes > 0 and not _quiet:
				progress_percent = clamp(int(float(loaded_bytes) / float(_total_native_bytes) * 100), 0, 99)
			if not _quiet:
				_update_badge()
				progress_updated.emit(progress_percent, loaded_bytes, _total_native_bytes, download_speed)
		
		if now - frame_t > 12:
			await get_tree().process_frame
			frame_t = Time.get_ticks_msec()
	
	f.close()
	http.close()
	
	if not _quiet:
		loaded_bytes = _already_dl_bytes + have
		if _total_native_bytes > 0:
			progress_percent = clamp(int(float(loaded_bytes) / float(_total_native_bytes) * 100), 0, 99)
		_update_badge()
		progress_updated.emit(progress_percent, loaded_bytes, _total_native_bytes, download_speed)
	
	if have < size:
		return "Mất kết nối khi đang tải (%d / %d bytes)" % [have, size]
	if have > size:
		DirAccess.remove_absolute(part_path)
		return "Dữ liệu tải về sai kích thước"
	
	return ""

func _run_native_download_loop() -> void:
	_streaming_loop_running = true
	_retry_count = 0

	while not _missing_packs.is_empty():
		_current_pack = _missing_packs[0]
		var mount: bool = bool(_current_pack.get("_mount", true))
		_quiet = not mount
		var file_name: String = str(_current_pack.get("file", ""))
		var size: int = int(_current_pack.get("size", 0))
		var expected_sha: String = str(_current_pack.get("sha256", "")).to_lower()
		var pack_name: String = str(_current_pack.get("name", file_name))
		var part_path: String = CONTENT_DIR.path_join(file_name + ".part")
		var final_path: String = CONTENT_DIR.path_join(file_name)

		var url := _get_pack_url(file_name)
		print("[ContentManager] Bắt đầu tải ngầm gói %s (%s, %d bytes, %s)..." % [
				pack_name, file_name, size, "bản đang chạy" if mount else "bản sau"])

		var success := false
		var retry_delay := 2.0
		var client_errors := 0

		while not success:
			var err_msg := await _download_file_resumable(url, part_path, size)
			if err_msg == "":
				if expected_sha != "":
					if mount and _badge_label and is_instance_valid(_badge_label):
						_badge_label.text = "⚡ Đang kiểm tra %s..." % pack_name
					var actual_sha := await _compute_sha256(part_path)
					if actual_sha != expected_sha:
						push_error("[ContentManager] Checksum sai lệch cho %s! Tải lại..." % file_name)
						DirAccess.remove_absolute(part_path)
						await get_tree().create_timer(2.0).timeout
						continue

				if FileAccess.file_exists(final_path):
					DirAccess.remove_absolute(final_path)
				var ren_err := DirAccess.rename_absolute(part_path, final_path)
				if ren_err != OK:
					push_error("[ContentManager] Không đổi tên được file %s (lỗi %d)" % [file_name, ren_err])
					await get_tree().create_timer(3.0).timeout
					continue

				if mount:
					var load_ok := ProjectSettings.load_resource_pack(final_path, false)
					print("[ContentManager] Nạp nóng thành công gói %s -> %s" % [file_name, load_ok])
					_already_dl_bytes += size
				else:
					print("[ContentManager] Đã tải gói %s của bản sau (chưa nạp)." % file_name)
				success = true
			elif err_msg.contains("HTTP 4"):
				# Máy chủ không còn gói này (VD bản cũ đã bị xoá) -> bỏ qua, không kẹt cả vòng tải.
				client_errors += 1
				push_warning("[ContentManager] %s: %s (lần %d)" % [file_name, err_msg, client_errors])
				if client_errors >= MAX_CLIENT_ERROR_TRIES:
					break
				await get_tree().create_timer(retry_delay).timeout
			else:
				push_warning("[ContentManager] Lỗi tải gói %s: %s. Thử lại sau %.1fs..." % [file_name, err_msg, retry_delay])
				if mount and _badge_label and is_instance_valid(_badge_label):
					_badge_label.text = "⚡ Mạng gián đoạn, tự kết nối lại..."
				await get_tree().create_timer(retry_delay).timeout
				retry_delay = minf(8.0, retry_delay * 1.5)

		_missing_packs.pop_front()
		# Hết gói của bản đang chạy -> mở cổng ngay, phần còn lại (bản sau) tải tiếp lặng lẽ.
		if not is_ready and not _has_pending_mount():
			_mark_current_ready()

	_quiet = false
	if not is_ready:
		_mark_current_ready()
	if _next_bytes > 0:
		update_downloaded = true
		print("[ContentManager] Đã tải xong bản cập nhật %d — dùng ở lần mở app sau." % int(_manifest.get("version", 0)))
		_show_update_ready_badge()
	is_native_streaming = false
	_streaming_loop_running = false

func _has_pending_mount() -> bool:
	for p in _missing_packs:
		if bool((p as Dictionary).get("_mount", true)):
			return true
	return false

func _mark_current_ready() -> void:
	print("[ContentManager] Gói của bản đang chạy đã đủ.")
	is_ready = true
	progress_percent = 100
	loaded_bytes = total_bytes
	download_speed = ""
	_update_badge()
	progress_updated.emit(100, total_bytes, total_bytes, "")
	content_loaded.emit()
	_flush_callbacks()

func _show_update_ready_badge() -> void:
	_create_status_badge()
	if _badge_label and is_instance_valid(_badge_label):
		_badge_label.text = "✅ Đã tải bản cập nhật — mở lại game để dùng"
		_badge_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		var tween := create_tween()
		tween.tween_interval(8.0)
		tween.tween_property(_badge_panel, "modulate:a", 0.0, 0.6)
		tween.tween_callback(func():
			if _badge_layer and is_instance_valid(_badge_layer):
				_badge_layer.queue_free()
		)

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
	if not _streaming_loop_running and not _missing_packs.is_empty():
		_start_native_streaming()

func _show_modal(caller: Node) -> void:
	if _modal_instance and is_instance_valid(_modal_instance):
		return
	
	var modal_script = preload("res://ui/common/content_download_modal.gd")
	var modal = modal_script.new()
	var root = caller.get_tree().root
	root.add_child(modal)
	_modal_instance = modal

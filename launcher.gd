extends Control
## Trình tải game JX1 Idle Origin — thứ DUY NHẤT nằm trong APK (vài chục MB, chủ yếu là engine Godot).
##
## Mỗi lần mở app:
##   1. Hỏi máy chủ GET /v1/client/manifest (danh sách gói .pck của bản game mới nhất + sha256).
##   2. Gói nào chưa có trên máy (tên file có mã băm nội dung, VD core-1a2b3c4d.pck) thì tải về user://content/
##      — tải tiếp được khi rớt mạng (Range), kiểm sha256 xong mới đổi tên .part -> .pck.
##   3. Ghi user://content/installed.json, xoá gói cũ, khởi động lại app chạy game bằng `--main-pack core.pck`
##      (Android: GodotApp.java đọc file đánh dấu user://boot_game). Gói còn lại do autoload ContentPacks của game nạp.
## Mất mạng nhưng đã có bản tải trước -> vào game luôn (game chơi offline được).
## Bản engine/launcher quá cũ so với manifest -> báo tải APK mới (chỉ khi đổi phiên bản Godot hoặc sửa launcher).

## Tăng khi sửa launcher/GodotApp.java theo cách bản game mới phụ thuộc vào (manifest.min_launcher).
const LAUNCHER_VERSION := 1
const SETTING_URL := "kiem_hiep/network/account_url"
const DEFAULT_URL := "https://kiem-hiep-api.viettheo.site"
const CONTENT_DIR := "user://content"
const INSTALLED_PATH := "user://content/installed.json"
## GodotApp.java đọc lúc mở app: dòng 1 = đường dẫn core.pck, dòng 2 = thư mục gói. Đọc xong xoá (dùng 1 lần),
## nên lần mở app sau lại vào launcher để kiểm tra cập nhật.
const BOOT_MARKER := "user://boot_game"
const MANIFEST_TIMEOUT := 10.0
const CONNECT_TIMEOUT_MS := 15000
## Không nhận được byte nào trong chừng này -> coi như rớt mạng, kết nối lại và tải tiếp.
const IDLE_TIMEOUT_MS := 30000
const MAX_TRIES := 6
## Thời gian tối đa mỗi khung hình dành cho tải/kiểm file, giữ giao diện mượt.
const FRAME_BUDGET_MS := 12
const PACK_FILE_RE := "^[a-z0-9_-]{1,64}\\.pck$"

var _base_url := DEFAULT_URL
var _status: Label
var _detail: Label
var _version_label: Label
var _bar: ProgressBar
var _button: Button
var _button_action := Callable()
var _file_re := RegEx.create_from_string(PACK_FILE_RE)
var _manifest_http_code := 0

# Tiến độ tải tổng (mọi gói cần tải trong lần này).
var _dl_total := 0
var _dl_done := 0
var _speed_t0 := 0
var _speed_b0 := 0
var _speed := 0.0

func _ready() -> void:
	if OS.has_feature("editor") or OS.has_feature("web"):
		get_tree().change_scene_to_file.call_deferred("res://ui/mode_select/ModeSelect.tscn")
		return
	_base_url = str(ProjectSettings.get_setting(SETTING_URL, DEFAULT_URL))
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--account-url="):
			_base_url = arg.substr("--account-url=".length())
	_base_url = _base_url.trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(CONTENT_DIR)
	_build_ui()
	_run()

# --- Luồng chính ---

func _run() -> void:
	_set_button("", Callable())
	_bar.visible = false
	_detail.text = ""
	_say("Đang kiểm tra phiên bản mới...")
	var installed := _read_json(INSTALLED_PATH)
	_show_versions(installed)
	var manifest := await _fetch_manifest()
	if manifest.is_empty():
		if _installed_ok(installed):
			_say("Không kết nối được máy chủ — vào game bằng bản đã tải.")
			await get_tree().create_timer(1.2).timeout
			_boot(installed)
		elif _manifest_http_code == 503:
			_fail("Máy chủ đang cập nhật bản cài đặt.\nVui lòng thử lại sau ít phút.")
		else:
			_fail("Không kết nối được máy chủ.\nKiểm tra mạng rồi thử lại.")
		return
	var bad := _check_manifest(manifest)
	if bad == "outdated":
		_say("Cần cài bản mới của game (bản cài hiện tại đã quá cũ).")
		var apk_url := str(manifest.get("apk_url", ""))
		if apk_url.begins_with("https://") or apk_url.begins_with("http://"):
			_set_button("Tải bản cài mới", func() -> void: OS.shell_open(apk_url))
		return
	if bad != "":
		_fail("Dữ liệu cập nhật trên máy chủ bị lỗi (%s).\nVui lòng thử lại sau." % bad)
		return

	var packs: Array = manifest["packs"]
	var todo: Array = []
	_dl_total = 0
	_dl_done = 0
	for p: Dictionary in packs:
		if not _pack_present(p):
			todo.append(p)
			_dl_total += int(p["size"])
	if not todo.is_empty():
		DisplayServer.screen_set_keep_on(true)
		_bar.visible = true
		_speed_t0 = Time.get_ticks_msec()
		_speed_b0 = 0
		_speed = 0.0
		var first_install := not _installed_ok(installed)
		for p: Dictionary in todo:
			_say(("Đang tải dữ liệu game" if first_install else "Đang cập nhật bản mới") + " (%s)..." % p["name"])
			var err := await _fetch_pack(manifest, p)
			if err != "":
				DisplayServer.screen_set_keep_on(false)
				_fail(err)
				return
		DisplayServer.screen_set_keep_on(false)

	var now_installed := {
		"version": int(manifest.get("version", 0)),
		"engine": str(manifest.get("engine", "")),
		"packs": packs,
	}
	if not _write_json_atomic(INSTALLED_PATH, now_installed):
		_fail("Không ghi được dữ liệu vào máy (bộ nhớ đầy?).")
		return
	_cleanup(packs)
	_show_versions(now_installed)
	_boot(now_installed)

## "" = hợp lệ; "outdated" = cần APK mới; còn lại = mô tả lỗi.
func _check_manifest(m: Dictionary) -> String:
	if int(m.get("min_launcher", 1)) > LAUNCHER_VERSION:
		return "outdated"
	# Gói xuất từ Godot khác phiên bản (major.minor) có thể không chạy được trên engine trong APK này.
	var engine := str(m.get("engine", "")).split(".")
	var v := Engine.get_version_info()
	if engine.size() < 2 or int(engine[0]) != int(v["major"]) or int(engine[1]) != int(v["minor"]):
		return "outdated"
	var packs: Variant = m.get("packs")
	if not packs is Array or (packs as Array).is_empty():
		return "không có gói"
	for p: Variant in packs:
		if not p is Dictionary:
			return "gói sai định dạng"
		var d := p as Dictionary
		if _file_re.search(str(d.get("file", ""))) == null or int(d.get("size", 0)) <= 0 \
				or str(d.get("sha256", "")).length() != 64:
			return "gói %s sai định dạng" % d.get("name", "?")
	return ""

func _fetch_manifest() -> Dictionary:
	_manifest_http_code = 0
	var req := HTTPRequest.new()
	req.timeout = MANIFEST_TIMEOUT
	add_child(req)
	var headers := PackedStringArray(["Cache-Control: no-cache", "User-Agent: KiemHiepLauncher/%d" % LAUNCHER_VERSION])
	if req.request(_base_url + "/v1/client/manifest", headers) != OK:
		req.queue_free()
		return {}
	var res: Array = await req.request_completed
	req.queue_free()
	_manifest_http_code = int(res[1])
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or _manifest_http_code != 200:
		return {}
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return data if data is Dictionary else {}

func _pack_url(manifest: Dictionary, file: String) -> String:
	# files_base: để gói trên CDN riêng (VD https://cdn.kiemhiep.vn/client/). Mặc định server tài khoản phục vụ.
	var base := str(manifest.get("files_base", ""))
	if not (base.begins_with("https://") or base.begins_with("http://")):
		base = _base_url + "/client/files/"
	return base.trim_suffix("/") + "/" + file

## Gói đã nằm trên máy: file .pck chỉ xuất hiện sau khi kiểm sha256 xong (đổi tên từ .part), nên đủ kích thước là dùng được.
func _pack_present(p: Dictionary) -> bool:
	var path := CONTENT_DIR.path_join(str(p["file"]))
	return FileAccess.file_exists(path) and _file_size(path) == int(p["size"])

func _installed_ok(installed: Dictionary) -> bool:
	var packs: Variant = installed.get("packs")
	if not packs is Array or (packs as Array).is_empty():
		return false
	for p: Variant in packs:
		if not p is Dictionary or _file_re.search(str((p as Dictionary).get("file", ""))) == null \
				or not _pack_present(p):
			return false
	return true

# --- Tải 1 gói ---

func _fetch_pack(manifest: Dictionary, p: Dictionary) -> String:
	var file := str(p["file"])
	var size := int(p["size"])
	var final_path := CONTENT_DIR.path_join(file)
	var part := final_path + ".part"
	var url := _pack_url(manifest, file)
	var base := _dl_done
	var err := ""
	for attempt in MAX_TRIES:
		err = await _download(url, part, size, base)
		if err == "":
			break
		if attempt == MAX_TRIES - 1:
			return err + "\nBấm Thử lại — phần đã tải được giữ nguyên."
		_detail.text = "%s — thử lại lần %d..." % [err, attempt + 1]
		await get_tree().create_timer(2.0 * (attempt + 1)).timeout
	_say("Đang kiểm tra dữ liệu (%s)..." % p["name"])
	var sha := await _sha256(part)
	if sha != str(p["sha256"]).to_lower():
		DirAccess.remove_absolute(part)
		_dl_done = base
		return "Dữ liệu tải về bị lỗi (%s).\nBấm Thử lại để tải lại." % p["name"]
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	if DirAccess.rename_absolute(part, final_path) != OK:
		return "Không ghi được dữ liệu vào máy (bộ nhớ đầy?)."
	_dl_done = base + size
	return ""

## Tải url vào file `part`, tải tiếp từ phần đã có. "" = đủ `size` byte.
func _download(url: String, part: String, size: int, base: int) -> String:
	var u := _parse_url(url)
	if u.is_empty():
		return "Địa chỉ tải không hợp lệ"
	var have := _file_size(part) if FileAccess.file_exists(part) else 0
	if have > size:
		DirAccess.remove_absolute(part)
		have = 0
	_dl_done = base + have
	if have == size:
		return ""
	var http := HTTPClient.new()
	http.read_chunk_size = 1 << 18
	if http.connect_to_host(u["host"], u["port"], TLSOptions.client() if u["tls"] else null) != OK:
		return "Không kết nối được máy chủ tải"
	var t0 := Time.get_ticks_msec()
	while http.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		http.poll()
		if Time.get_ticks_msec() - t0 > CONNECT_TIMEOUT_MS:
			return "Hết thời gian kết nối"
		await get_tree().process_frame
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return "Không kết nối được máy chủ tải"
	var headers := PackedStringArray(["User-Agent: KiemHiepLauncher/%d" % LAUNCHER_VERSION])
	if have > 0:
		headers.append("Range: bytes=%d-" % have)
	if http.request(HTTPClient.METHOD_GET, u["path"], headers) != OK:
		return "Không gửi được yêu cầu tải"
	t0 = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		if Time.get_ticks_msec() - t0 > CONNECT_TIMEOUT_MS:
			return "Máy chủ không phản hồi"
		await get_tree().process_frame
	if not http.has_response():
		return "Máy chủ không phản hồi"
	var code := http.get_response_code()
	var f: FileAccess
	if code == 206 and have > 0:
		f = FileAccess.open(part, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	elif code == 200:
		have = 0 # máy chủ không hỗ trợ tải tiếp -> tải lại từ đầu
		f = FileAccess.open(part, FileAccess.WRITE)
	elif code == 416:
		DirAccess.remove_absolute(part)
		return "Dữ liệu tải dở không khớp, tải lại"
	else:
		return "Máy chủ báo lỗi %d" % code
	if f == null:
		return "Không ghi được dữ liệu vào máy (bộ nhớ đầy?)"
	_dl_done = base + have
	var last_data := Time.get_ticks_msec()
	var frame_t := last_data
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		if http.get_status() != HTTPClient.STATUS_BODY:
			break
		var chunk := http.read_response_body_chunk()
		var now := Time.get_ticks_msec()
		if chunk.is_empty():
			if now - last_data > IDLE_TIMEOUT_MS:
				break
			_update_progress()
			await get_tree().process_frame
			frame_t = Time.get_ticks_msec()
			continue
		f.store_buffer(chunk)
		if f.get_error() != OK:
			f.close()
			return "Không ghi được dữ liệu vào máy (bộ nhớ đầy?)"
		have += chunk.size()
		_dl_done += chunk.size()
		last_data = now
		if now - frame_t > FRAME_BUDGET_MS:
			_update_progress()
			await get_tree().process_frame
			frame_t = Time.get_ticks_msec()
	f.close()
	http.close()
	_update_progress()
	if have < size:
		return "Mất kết nối khi đang tải"
	if have > size:
		DirAccess.remove_absolute(part)
		return "Dữ liệu tải về sai kích thước"
	return ""

func _sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var length := f.get_length()
	var t := Time.get_ticks_msec()
	while f.get_position() < length:
		ctx.update(f.get_buffer(1 << 20))
		if Time.get_ticks_msec() - t > FRAME_BUDGET_MS:
			_detail.text = "Kiểm tra %d%%" % int(100.0 * f.get_position() / max(1, length))
			await get_tree().process_frame
			t = Time.get_ticks_msec()
	f.close() # Windows không cho đổi tên file đang mở
	return ctx.finish().hex_encode()

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

func _boot(installed: Dictionary) -> void:
	_say("Đang vào game...")
	_bar.visible = false
	_detail.text = ""
	var packs: Array = installed.get("packs", [])
	# Nạp toàn bộ các gói tài nguyên đã tải về vào virtual filesystem res://
	for i in range(packs.size()):
		var p: Dictionary = packs[i]
		var file_name: String = str(p.get("file", ""))
		var pck_path := CONTENT_DIR.path_join(file_name)
		if FileAccess.file_exists(pck_path):
			var replace := (i == 0)
			var ok := ProjectSettings.load_resource_pack(pck_path, replace)
			print("Launcher: Nạp gói %s (replace=%s) -> %s" % [file_name, replace, ok])
		else:
			_fail("Thiếu gói dữ liệu: " + file_name)
			return

	await get_tree().process_frame
	print("Launcher: Chuyển cảnh sang màn hình chọn chế độ chơi (Offline / Online)...")
	get_tree().change_scene_to_file.call_deferred("res://ui/mode_select/ModeSelect.tscn")

func _restart_via_java() -> void:
	pass

# --- Tiện ích file ---

func _cleanup(packs: Array) -> void:
	var keep := {}
	for p: Dictionary in packs:
		keep[str(p["file"])] = true
	var d := DirAccess.open(CONTENT_DIR)
	if d == null:
		return
	for name in d.get_files():
		var is_pack := name.ends_with(".pck") or name.ends_with(".pck.part")
		if is_pack and not keep.has(name.trim_suffix(".part")):
			d.remove(name)

func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return n

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _write_json_atomic(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		return false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK

# --- Giao diện ---

func _build_ui() -> void:
	var bg := TextureRect.new()
	var bg_res := "res://art/bg.jpg" if ResourceLoader.exists("res://art/bg.jpg") else "res://launcher/art/bg.jpg"
	if ResourceLoader.exists(bg_res):
		bg.texture = load(bg_res)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var logo := TextureRect.new()
	var logo_res := "res://art/logo.png" if ResourceLoader.exists("res://art/logo.png") else "res://launcher/art/logo.png"
	if ResourceLoader.exists(logo_res):
		logo.texture = load(logo_res)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	logo.offset_left = 24
	logo.offset_top = 20
	logo.offset_right = 284
	logo.offset_bottom = 158
	add_child(logo)

	var box := VBoxContainer.new()
	box.anchor_left = 0.15
	box.anchor_right = 0.85
	box.anchor_top = 0.62
	box.anchor_bottom = 0.95
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	_status = _label(24)
	box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 22)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.65, 0.25)
	fill.set_corner_radius_all(6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.border_color = Color(0.85, 0.65, 0.25, 0.6)
	back.set_border_width_all(1)
	back.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	_detail = _label(18)
	_detail.modulate = Color(1, 1, 1, 0.85)
	box.add_child(_detail)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(240, 56)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.add_theme_font_size_override("font_size", 22)
	_button.pressed.connect(func() -> void:
		if _button_action.is_valid():
			_button_action.call())
	box.add_child(_button)

	_version_label = _label(14)
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version_label.modulate = Color(1, 1, 1, 0.6)
	_version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_version_label.offset_left = -400
	_version_label.offset_top = -28
	_version_label.offset_right = -12
	_version_label.offset_bottom = -6
	add_child(_version_label)

func _label(font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	var font_res := "res://art/BeVietnamPro-Regular.ttf" if ResourceLoader.exists("res://art/BeVietnamPro-Regular.ttf") else "res://launcher/art/BeVietnamPro-Regular.ttf"
	if ResourceLoader.exists(font_res):
		l.add_theme_font_override("font", load(font_res))
	return l

func _say(text: String) -> void:
	_status.text = text
	print("Launcher: ", text.replace("
", " "))

func _fail(text: String) -> void:
	_say(text)
	_set_button("Thử lại", _run)

func _set_button(text: String, action: Callable) -> void:
	_button.text = text
	_button.visible = not text.is_empty()
	_button_action = action

func _show_versions(installed: Dictionary) -> void:
	var game := "bản %d" % int(installed["version"]) if installed.has("version") else "chưa cài"
	_version_label.text = "Launcher v%d · Game %s" % [LAUNCHER_VERSION, game]

func _update_progress() -> void:
	if _dl_total <= 0:
		return
	_bar.value = float(_dl_done) / _dl_total
	var now := Time.get_ticks_msec()
	if now - _speed_t0 >= 1000:
		var bps := (_dl_done - _speed_b0) * 1000.0 / (now - _speed_t0)
		_speed = bps if _speed <= 0.0 else lerpf(_speed, bps, 0.4)
		_speed_t0 = now
		_speed_b0 = _dl_done
	var text := "%s / %s" % [_mb(_dl_done), _mb(_dl_total)]
	if _speed > 0.0:
		text += " · %s/s" % _mb(int(_speed))
		var left := int((_dl_total - _dl_done) / _speed)
		if left > 0:
			text += " · còn %d:%02d" % [left / 60, left % 60]
	_detail.text = text

func _mb(bytes: int) -> String:
	return "%.1f MB" % (bytes / 1048576.0)

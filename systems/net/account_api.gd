extends Node
## Autoload AccountApi — gọi server tài khoản (server/account, Go) qua HTTP/JSON. Chạy được cả PC, mobile và web.
##
## BẢO MẬT: client KHÔNG giữ khóa bí mật nào. Chỉ giữ token của chính người chơi:
##   - access token (15 phút) chỉ nằm trong RAM;
##   - refresh token (30 ngày) chỉ lưu xuống máy khi tích "Ghi nhớ đăng nhập". Server xoay vòng refresh token mỗi lần dùng
##     và thu hồi mọi phiên nếu thấy token cũ bị dùng lại, nên token bị chép trộm sẽ sớm vô hiệu.
##   File phiên được mã hóa bằng mã máy (OS.get_unique_id) — chỉ để file chép sang máy khác không đọc được, không phải khóa server.
##
## Mọi hàm public đều `await` được và trả về Dictionary:
##   {"ok": bool, "status": int (HTTP), "code": String (mã lỗi server, rỗng nếu ok), "message": String, "data": Variant}

signal logged_out

## Địa chỉ server tài khoản. Đổi bằng tham số dòng lệnh `--account-url=https://...` hoặc Project Settings
## "kiem_hiep/network/account_url" (dùng khi xuất bản game).
const DEFAULT_URL := "http://127.0.0.1:8080"
const SETTING_URL := "kiem_hiep/network/account_url"
const SESSION_PATH := "user://session.dat"
## Cửa sổ game nào đang GIỮ file phiên (mã tiến trình). Mở 2 cửa sổ game trên 1 máy: cửa sổ thứ 2 không được tự đăng nhập bằng phiên
## của cửa sổ 1 — nếu không, 2 cửa sổ cùng xoay vòng 1 refresh token, server coi là token bị đánh cắp và thu hồi mọi phiên (đá văng).
const SESSION_LOCK_PATH := "user://session.lock"
const TIMEOUT := 15.0
## Làm mới access token sớm chừng này giây trước khi hết hạn.
const REFRESH_MARGIN := 30.0

var base_url := DEFAULT_URL
## Thông tin tài khoản đang đăng nhập: {id, username, email, has_password, google_linked}. Rỗng = chưa đăng nhập.
var account: Dictionary = {}

var _access := ""
var _access_expire_at := 0.0 ## giây (Time.get_ticks_msec()/1000)
var _refresh := ""
var _remember := true
var _refreshing := false
var _google_cancel := false
signal _refresh_finished(ok: bool)
## Phát khi phát hiện tài khoản bị đá do đăng nhập ở thiết bị khác
signal session_invalidated(reason: String)

func _ready() -> void:
	base_url = str(ProjectSettings.get_setting(SETTING_URL, DEFAULT_URL))
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--account-url="):
			base_url = arg.get_slice("=", 1)
	if OS.has_feature("web"):
		var web_override: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('account-url')")
		if web_override != null and str(web_override).begins_with("http"):
			base_url = str(web_override)
		else:
			var origin: Variant = JavaScriptBridge.eval("window.location.origin")
			if origin != null and str(origin).begins_with("http"):
				base_url = str(origin)
	base_url = base_url.trim_suffix("/")

func is_logged_in() -> bool:
	return not account.is_empty()

func username() -> String:
	return str(account.get("username", ""))

## Kiểm tra tài khoản có quyền GM (được server xác nhận trong dữ liệu tài khoản)
func is_gm() -> bool:
	if is_logged_in():
		return bool(account.get("is_gm", false))
	return OS.is_debug_build()

# ---------------------------------------------------------------- tài khoản

func login(user: String, password: String, remember: bool) -> Dictionary:
	_remember = remember
	var r := await _request(HTTPClient.METHOD_POST, "/v1/auth/login", {"username": user, "password": password})
	if r.ok:
		_apply_session(r.data)
	return r

func register(user: String, email: String, password: String) -> Dictionary:
	_remember = true
	var r := await _request(HTTPClient.METHOD_POST, "/v1/auth/register", {"username": user, "email": email, "password": password})
	if r.ok:
		_apply_session(r.data)
	return r

## Gửi mã đặt lại mật khẩu về email. Server luôn trả ok (kể cả tên/email không khớp) để chống dò tài khoản.
func forgot_password(user: String, email: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/v1/auth/forgot", {"username": user, "email": email})

func reset_password(user: String, code: String, new_password: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/v1/auth/reset", {"username": user, "code": code, "new_password": new_password})

## Đổi mật khẩu khi đang đăng nhập. Server đăng xuất mọi máy khác và trả phiên mới cho máy này.
func change_password(old_password: String, new_password: String) -> Dictionary:
	var r := await _authed(HTTPClient.METHOD_POST, "/v1/account/password", {"old_password": old_password, "new_password": new_password})
	if r.ok:
		_apply_session(r.data)
	return r

## Đăng nhập Google (hoặc LIÊN KẾT Google nếu link = true và đang đăng nhập): mở trình duyệt của máy, chờ người chơi
## đăng nhập xong rồi nhận phiên từ server. Gọi cancel_google() để hủy chờ. Trả về như login().
func google_login(link := false) -> Dictionary:
	_google_cancel = false
	var start: Dictionary
	if link:
		start = await _authed(HTTPClient.METHOD_POST, "/v1/auth/google/start", {})
	else:
		start = await _request(HTTPClient.METHOD_POST, "/v1/auth/google/start", {})
	if not start.ok:
		return start
	var d: Dictionary = start.data
	var auth_url := str(d.get("auth_url", ""))
	if not auth_url.begins_with("https://"):
		return _fail(0, "bad_auth_url", "Địa chỉ đăng nhập không hợp lệ hoặc không an toàn")
	OS.shell_open(auth_url)
	var interval := maxf(1.0, float(d.get("interval", 2)))
	var deadline := _now() + float(d.get("expires_in", 300))
	while _now() < deadline:
		await get_tree().create_timer(interval).timeout
		if _google_cancel:
			return _fail(0, "google_canceled", "Đã hủy đăng nhập Google")
		var r := await _request(HTTPClient.METHOD_POST, "/v1/auth/google/poll", {"state": d.state, "poll_secret": d.poll_secret})
		if r.status == 202 or r.code == "network":
			continue   ## chưa xong / rớt mạng tạm thời: hỏi tiếp
		if r.ok:
			_remember = true
			_apply_session(r.data)
		return r
	return _fail(0, "google_expired", "Hết thời gian chờ đăng nhập Google, hãy thử lại")

func cancel_google() -> void:
	_google_cancel = true

func logout() -> void:
	if _refresh != "":
		await _request(HTTPClient.METHOD_POST, "/v1/auth/logout", {"refresh_token": _refresh})
	_clear_session()
	logged_out.emit()

## Có phiên đã ghi nhớ trên máy này không (để tự đăng nhập lại). Cửa sổ game khác đang giữ phiên thì coi như không có.
func has_saved_session() -> bool:
	return FileAccess.file_exists(SESSION_PATH) and _own_session_file()

## Tên tài khoản của phiên đã ghi nhớ (để điền sẵn), rỗng nếu không có.
func saved_username() -> String:
	return str(_read_session_file().get("username", ""))

## Đăng nhập lại bằng refresh token đã ghi nhớ. Thất bại (hết hạn, bị thu hồi, bị khóa) thì xóa phiên đã lưu.
func resume() -> Dictionary:
	var saved := _read_session_file()
	_refresh = str(saved.get("refresh_token", ""))
	if _refresh == "":
		return _fail(0, "no_session", "")
	_remember = true
	var ok: bool = await _do_refresh()
	if ok:
		return {"ok": true, "status": 200, "code": "", "message": "", "data": account}
	return _fail(401, "unauthorized", "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại")

# ---------------------------------------------------------------- dữ liệu game

func servers() -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, "/v1/servers")

## Nhân vật của tài khoản trên 1 máy chủ: data = {"characters": [{id, slot, name, gender, sect_id, level, version, data}], "max": 4}.
func characters(server_id: int) -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, "/v1/characters?server_id=%d" % server_id)

## Bảng xếp hạng máy chủ: {level, money: [{rank, name, level, sect_id, gender, money}], sect_level, sect_money: {sect_id: [...]}}.
## Server giữ kết quả ~60 giây (ttl_seconds) — mở lại bảng trong khoảng đó thấy cùng số liệu.
func rankings(server_id: int) -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, "/v1/rankings?server_id=%d" % server_id)

## Chiến trường Tống Kim của máy chủ: {open, phase, phase_left, song, jin, song_points, jin_points, balance, side_cap, min_level,
## map_id, map_name, host, port, ws_url}. open = false khi battle server không chạy.
func battle(server_id: int) -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, "/v1/battle?server_id=%d" % server_id)

## Đấu trường PK: danh sách phòng + địa chỉ arena server ({open, host, port, ws_url, rooms: [...]}).
func arena(server_id: int) -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, "/v1/arena?server_id=%d" % server_id)

## Phòng train chung Vượt Ải: địa chỉ field server + danh sách phòng ({open, host, port, ws_url, rooms: [{id, map_id, tier, stars,
## host, members, max}]}) — tạo phòng / tìm phòng theo ID trước khi kết nối.
func field(server_id: int) -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, "/v1/field?server_id=%d" % server_id)

## Tạo nhân vật ở ô `slot`. profile_data = PlayerProfile.to_dict(). Server kiểm tra tên (2–16 ký tự, không trùng trong máy chủ).
func create_character(server_id: int, slot: int, character_name: String, profile_data: Dictionary) -> Dictionary:
	return await _authed(HTTPClient.METHOD_POST, "/v1/characters",
		{"server_id": server_id, "slot": slot, "name": character_name, "data": profile_data})

## Lưu tiến trình. version = bản đang có; server trả version mới. Lệch version (máy khác vừa lưu) -> code "stale_save".
func save_character(character_id: int, version: int, profile_data: Dictionary) -> Dictionary:
	return await _authed(HTTPClient.METHOD_PUT, "/v1/characters/%d" % character_id, {"version": version, "data": profile_data})

## Xóa nhân vật (xóa mềm, admin khôi phục được) — phải nhập lại mật khẩu tài khoản.
func delete_character(character_id: int, password: String) -> Dictionary:
	return await _authed(HTTPClient.METHOD_DELETE, "/v1/characters/%d" % character_id, {"password": password})

## Kiểm tra phiên đăng nhập còn hiệu lực hay đã bị đá do thiết bị khác đăng nhập.
func check_session() -> Dictionary:
	return await _authed(HTTPClient.METHOD_GET, "/v1/auth/session")

## Access token hiện tại (còn hạn) — dùng khi kết nối game server. Rỗng nếu chưa đăng nhập / không làm mới được.
func access_token() -> String:
	if not await _ensure_access():
		return ""
	return _access

# ---------------------------------------------------------------- phiên

func _apply_session(data: Variant) -> void:
	if not data is Dictionary:
		return
	_access = str(data.get("access_token", ""))
	_refresh = str(data.get("refresh_token", ""))
	_access_expire_at = _now() + float(data.get("expires_in", 0))
	account = data.get("account", {})
	if not _own_session_file():
		return   ## cửa sổ game khác đang giữ file phiên: không ghi đè / xoá phiên của nó
	if _remember:
		_write_session_file()
	else:
		DirAccess.remove_absolute(SESSION_PATH)

func _clear_session() -> void:
	## Đăng xuất / hết phiên: bỏ nhân vật đang chơi để tài khoản sau không thấy nhân vật của tài khoản trước.
	GameManager.local_profile = null
	SaveManager.clear_online_character()
	_access = ""
	_refresh = ""
	_access_expire_at = 0.0
	account = {}
	if FileAccess.file_exists(SESSION_PATH) and _own_session_file():
		DirAccess.remove_absolute(SESSION_PATH)

## Cửa sổ game này có được dùng file phiên không: chưa ai giữ / người giữ đã tắt -> nhận giữ; cửa sổ khác còn chạy -> không.
func _own_session_file() -> bool:
	var me := OS.get_process_id()
	var holder := 0
	if FileAccess.file_exists(SESSION_LOCK_PATH):
		holder = FileAccess.get_file_as_string(SESSION_LOCK_PATH).strip_edges().to_int()
	if holder == me:
		return true
	if holder > 0 and OS.is_process_running(holder):
		return false
	var f := FileAccess.open(SESSION_LOCK_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(str(me))
	return true

## Tắt game: trả quyền giữ file phiên cho cửa sổ mở sau.
func _exit_tree() -> void:
	if FileAccess.file_exists(SESSION_LOCK_PATH) 			and FileAccess.get_file_as_string(SESSION_LOCK_PATH).strip_edges().to_int() == OS.get_process_id():
		DirAccess.remove_absolute(SESSION_LOCK_PATH)

const _SESSION_PREFIX_OBF: PackedByteArray = [49, 8, 13, 2, 30, 20, 225, 251, 191, 234, 197, 212, 221, 220, 211, 173, 240]

func _session_key() -> String:
	## Không phải bí mật của server — chỉ gắn file phiên với máy này.
	var id := OS.get_unique_id()
	var prefix := Obfuscator.deobfuscate(_SESSION_PREFIX_OBF)
	return (prefix + (id if id != "" else OS.get_name())).sha256_text()

func _write_session_file() -> void:
	var f := FileAccess.open_encrypted_with_pass(SESSION_PATH, FileAccess.WRITE, _session_key())
	if f:
		f.store_string(JSON.stringify({"refresh_token": _refresh, "username": username()}))

func _read_session_file() -> Dictionary:
	if not FileAccess.file_exists(SESSION_PATH):
		return {}
	var f := FileAccess.open_encrypted_with_pass(SESSION_PATH, FileAccess.READ, _session_key())
	if f == null:
		DirAccess.remove_absolute(SESSION_PATH) ## file hỏng / chép từ máy khác
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _ensure_access() -> bool:
	if _access != "" and _now() < _access_expire_at - REFRESH_MARGIN:
		return true
	if _refresh == "":
		return false
	return await _do_refresh()

## Làm mới phiên. Nhiều lời gọi cùng lúc chỉ gửi 1 yêu cầu (refresh token dùng 1 lần, gửi 2 lần = bị coi là đánh cắp).
func _do_refresh() -> bool:
	if _refreshing:
		return await _refresh_finished
	_refreshing = true
	var r := await _request(HTTPClient.METHOD_POST, "/v1/auth/refresh", {"refresh_token": _refresh})
	if r.ok:
		_apply_session(r.data)
	elif r.status == 401 or r.status == 403:
		_clear_session()
		logged_out.emit()
	_refreshing = false
	_refresh_finished.emit(r.ok)
	return r.ok

func _authed(method: HTTPClient.Method, path: String, body: Variant = null) -> Dictionary:
	if not await _ensure_access():
		return _fail(401, "unauthorized", "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại")
	var r := await _request(method, path, body, _access)
	if r.status == 401:
		if r.code == "logged_in_elsewhere":
			_clear_session()
			session_invalidated.emit(r.message)
			return r
		if _refresh != "" and await _do_refresh():
			r = await _request(method, path, body, _access)
			if r.code == "logged_in_elsewhere":
				_clear_session()
				session_invalidated.emit(r.message)
	return r

# ---------------------------------------------------------------- HTTP

func _request(method: HTTPClient.Method, path: String, body: Variant = null, bearer := "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if bearer != "":
		headers.append("Authorization: Bearer " + bearer)
	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(base_url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return _fail(0, "network", "Không kết nối được máy chủ, hãy kiểm tra mạng")
	var res: Array = await http.request_completed
	http.queue_free()
	var result: int = res[0]
	var status: int = res[1]
	if result != HTTPRequest.RESULT_SUCCESS:
		if result == HTTPRequest.RESULT_TIMEOUT:
			return _fail(0, "network", "Máy chủ không phản hồi, vui lòng thử lại")
		return _fail(0, "network", "Không kết nối được máy chủ, hãy kiểm tra mạng")
	var raw_bytes: PackedByteArray = res[3]
	if raw_bytes.size() >= 2 and raw_bytes[0] == 0x1F and raw_bytes[1] == 0x8B:
		raw_bytes = raw_bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var text := raw_bytes.get_string_from_utf8()
	var trimmed := text.strip_edges()
	var data: Variant = null
	if trimmed.begins_with("{") or trimmed.begins_with("["):
		data = JSON.parse_string(trimmed)
	if status >= 200 and status < 300:
		return {"ok": true, "status": status, "code": "", "message": "", "data": data}
	if data is Dictionary:
		return _fail(status, str(data.get("code", "error")), str(data.get("message", "Có lỗi xảy ra")))
	return _fail(status, "error", "Máy chủ gặp sự cố (%d), vui lòng thử lại sau" % status)

func _fail(status: int, code: String, message: String) -> Dictionary:
	return {"ok": false, "status": status, "code": code, "message": message, "data": null}

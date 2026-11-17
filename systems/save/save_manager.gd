extends Node
## Autoload — lưu/load tiến trình PlayerStats (level/exp/multiplier TRONG 1 lượt chơi) ra
## res://user data (JSON). Tiến trình môn phái/skill (lâu dài) nằm ở PlayerProfile — xem phần
## PlayerProfile bên dưới, lưu file riêng profile.json.

const SAVE_PATH := "user://savegame.json"

## Khóa mã hóa bảo vệ file lưu cục bộ, gắn liền với thiết bị người chơi (chống sửa file text trực tiếp).
const _KEY_PREFIX_OBF: PackedByteArray = [48, 25, 89, 66, 5, 28, 242, 238, 191, 234, 197, 196, 219, 199, 213, 183, 179, 235]

static func _save_key() -> String:
	var id := "" if OS.has_feature("web") else OS.get_unique_id()
	var prefix := Obfuscator.deobfuscate(_KEY_PREFIX_OBF)
	return (prefix + (id if id != "" else OS.get_name())).sha256_text()

signal game_saved
signal game_loaded

## ---------------- Đọc/ghi file lưu an toàn ----------------
## - Ghi: mã hoá (AES-256, khoá gắn thiết bị) vào file .tmp -> đọc lại kiểm tra -> giữ bản cũ thành .bak -> đổi tên .tmp
##   thành file chính. Tắt game/hết pin giữa lúc ghi thì file chính hoặc .bak vẫn còn nguyên, không mất nhân vật.
## - Đọc: file mã hoá của Godot có kiểm tra toàn vẹn (MD5 nội dung) — sửa 1 byte hay chép sang máy khác là không mở được.
##   File bản rõ (JSON thường) CHỈ chấp nhận khi máy này chưa từng ghi bản mã hoá (lưu cũ trước khi có mã hoá);
##   đã có dấu SECURE_MARKER thì bản rõ bị từ chối -> không thể sửa tay file JSON để cộng đồ/tiền.
const SECURE_MARKER_PATH := "user://.save_secure"
const _GDEC_MAGIC := "GDEC"   ## 4 byte đầu file mã hoá của Godot (FileAccessEncrypted)

func _write_secure(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var text := JSON.stringify(data)
	var f := FileAccess.open_encrypted_with_pass(tmp, FileAccess.WRITE, _save_key())
	if f == null:
		push_warning("SaveManager: không mở được file để ghi (%s)" % tmp)
		return false
	f.store_string(text)
	f.close()
	## Đọc lại bản vừa ghi: hỏng (đầy bộ nhớ...) thì bỏ, giữ nguyên file cũ.
	if _read_encrypted(tmp) != text:
		push_warning("SaveManager: bản lưu vừa ghi không đọc lại được (%s), giữ bản cũ" % path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var bak := abs_path + ".bak"
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(abs_path, bak)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path) != OK:
		push_warning("SaveManager: không đổi tên được file lưu (%s)" % path)
		return false
	_mark_secure()
	return true

func _read_encrypted(path: String) -> String:
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, _save_key())
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text

static func _is_encrypted_file(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 4:
		return false
	var magic := f.get_buffer(4).get_string_from_ascii()
	f.close()
	return magic == _GDEC_MAGIC

func _mark_secure() -> void:
	if FileAccess.file_exists(SECURE_MARKER_PATH):
		return
	var f := FileAccess.open(SECURE_MARKER_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("1")
		f.close()

## Trả về Dictionary đã giải mã, hoặc {} nếu không có / bị sửa / hỏng. Hỏng thì thử bản dự phòng .bak.
func _read_secure(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var text := ""
		if _is_encrypted_file(p):
			text = _read_encrypted(p)
			if text == "":
				push_warning("SaveManager: file lưu bị sửa hoặc không thuộc máy này (%s)" % p)
				continue
		elif FileAccess.file_exists(SECURE_MARKER_PATH):
			push_warning("SaveManager: từ chối file lưu không mã hoá (%s)" % p)
			continue
		else:
			text = FileAccess.get_file_as_string(p)   ## bản cũ trước khi có mã hoá — lần lưu kế tiếp sẽ mã hoá lại
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			return parsed
		push_warning("SaveManager: file lưu hỏng định dạng (%s)" % p)
	return {}

## Chạy kiểm thử tự động (đặt biến môi trường KIEMHIEP_NO_SAVE=1) thì KHÔNG ghi đè file lưu thật của người chơi.
static func _saving_disabled() -> bool:
	return OS.has_environment("KIEMHIEP_NO_SAVE")

func save_game(_player: Node) -> void:
	if _saving_disabled():
		return
	var data := {
		"version": 1,
		"player_stats": _serialize_player_stats(),
	}

	if _write_secure(SAVE_PATH, data):
		game_saved.emit()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game(_player: Node) -> bool:
	if not has_save():
		return false

	var data := _read_secure(SAVE_PATH)
	if data.is_empty():
		return false
	_deserialize_player_stats(data.get("player_stats", {}))
	game_loaded.emit()
	return true

## ---------------- PlayerProfile (nhân vật ngoài trận) ----------------
## 2 chế độ:
##   - ONLINE (đã đăng nhập tài khoản): nhân vật nằm trên server (AccountApi.characters/create_character/save_character).
##     save_profile() gom các lần lưu trong ONLINE_SAVE_DELAY giây rồi gửi 1 lần; đóng game thì gửi nốt trước khi thoát.
##     File profile.json trên máy KHÔNG được đọc/ghi để tài khoản này không thấy nhân vật của tài khoản khác.
##   - Chưa đăng nhập (chạy thẳng scene để test): đọc/ghi user://profile.json như cũ.

const PROFILE_PATH := "user://profile.json"
const OFFLINE_PROFILE_PATH := "user://profile_offline.json"
const ONLINE_SAVE_DELAY := 2.0
const EXP_SAVE_DELAY := 5.0

## Quản lý 4 slot nhân vật Offline (slot 0..3) tương tự như Online
var current_offline_slot: int = 0

## Lưu lên server thất bại (mất mạng, máy khác vừa lưu...) — UI có thể nghe để báo người chơi.
signal online_save_failed(message: String)
## Phát ngay khi hồ sơ nhân vật được lưu hoặc cập nhật (mua đồ, đổi tiền, nhận/trả nhiệm vụ, S_PROFILE, GM...) để mọi cửa sổ/HUD đồng bộ tức thì.
signal profile_changed(profile: PlayerProfile)

var _emitting_profile_changed := false

## Nhân vật đang chơi trên server (0 = chưa chọn).
var online_character_id := 0
var _online_version := 0
var _pending_profile: PlayerProfile
var _online_saving := false
var _online_timer: Timer
## Vừa rời map online: game server đã lưu với version mới mà máy chưa biết -> lần lưu HTTP kế tiếp hỏi lại version trước.
var _version_unknown := false

var _exp_save_timer: Timer
var _pending_exp_profile: PlayerProfile = null

func _ready() -> void:
	_online_timer = Timer.new()
	_online_timer.one_shot = true
	_online_timer.wait_time = ONLINE_SAVE_DELAY
	_online_timer.timeout.connect(flush_online)
	add_child(_online_timer)

	_exp_save_timer = Timer.new()
	_exp_save_timer.one_shot = true
	_exp_save_timer.wait_time = EXP_SAVE_DELAY
	_exp_save_timer.timeout.connect(_on_exp_save_timeout)
	add_child(_exp_save_timer)

	_purge_online_caches()
	## Tự xử lý nút đóng cửa sổ để kịp gửi bản lưu cuối lên server.
	get_tree().auto_accept_quit = false
	var gm := get_node_or_null("/root/GmManager")
	if gm != null and gm.has_signal("profile_modified"):
		gm.profile_modified.connect(func(p: PlayerProfile) -> void:
			notify_profile_changed(p)
		)

func notify_profile_changed(profile: PlayerProfile = null) -> void:
	var target := profile if profile != null else GameManager.local_profile
	if target == null or _emitting_profile_changed:
		return
	_emitting_profile_changed = true
	profile_changed.emit(target)
	_emitting_profile_changed = false

## Hẹn giờ lưu EXP (debounce/batching 5 giây) khi đánh quái hoặc nhận EXP dã tẩu.
## Giúp chống giật lag khi tung chiêu diệt nhiều quái cùng lúc, đồng thời bảo đảm lưu tự động mỗi 5s.
func request_exp_save(profile: PlayerProfile = null, delay: float = EXP_SAVE_DELAY) -> void:
	var target := profile if profile != null else GameManager.local_profile
	if target == null:
		return
	_pending_exp_profile = target
	if _exp_save_timer == null:
		_exp_save_timer = Timer.new()
		_exp_save_timer.one_shot = true
		_exp_save_timer.wait_time = EXP_SAVE_DELAY
		_exp_save_timer.timeout.connect(_on_exp_save_timeout)
		add_child(_exp_save_timer)
	if _exp_save_timer.is_stopped():
		_exp_save_timer.start(delay)

func _on_exp_save_timeout() -> void:
	if _pending_exp_profile != null:
		var p := _pending_exp_profile
		_pending_exp_profile = null
		save_profile(p)

## Ép lưu ngay lập tức mọi EXP đang chờ gom (dùng khi thoát game, chuyển map, đổi ứng dụng).
func flush_exp_save() -> void:
	if _exp_save_timer != null and not _exp_save_timer.is_stopped():
		_exp_save_timer.stop()
	_on_exp_save_timeout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.cleanup_rooms_on_game_closing()
		flush_exp_save()
		if _pending_profile != null or _online_saving:
			await flush_online()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		flush_exp_save()
		if _pending_profile != null and not _online_saving:
			flush_online()

func _online() -> bool:
	return AccountApi.is_logged_in()

## Gọi khi vào game bằng 1 nhân vật trên server (màn Danh sách / Tạo nhân vật).
func set_online_character(character_id: int, version: int) -> void:
	online_character_id = character_id
	_online_version = version
	_pending_profile = null

func clear_online_character() -> void:
	online_character_id = 0
	_online_version = 0
	_pending_profile = null
	if _online_timer:
		_online_timer.stop()

## Game server báo đã lưu (S_SAVED) / vừa rời map.
func set_online_version(version: int) -> void:
	_online_version = version
	_version_unknown = false

func mark_version_unknown() -> void:
	_version_unknown = true

## Gửi ngay bản lưu đang chờ (nếu có). await được.
## Đang trong map online: gửi cho game server (server gộp + lưu). Ngoài map: lưu thẳng qua API (HTTP).
func flush_online() -> void:
	while _online_saving:
		await get_tree().process_frame
	if _pending_profile == null or online_character_id == 0:
		return
	var profile := _pending_profile
	_pending_profile = null
	if NetClient.is_in_world():
		NetClient.send_profile(profile.to_dict())
		if not NetClient.is_hub:
			return
	if _version_unknown:
		await _refresh_version()
	_online_saving = true
	var r: Dictionary = await AccountApi.save_character(online_character_id, _online_version, profile.to_dict())
	_online_saving = false
	if r.ok:
		_online_version = int(r.data.get("version", _online_version + 1))
		return
	push_warning("SaveManager: lưu nhân vật lên server lỗi: %s" % r.message)
	if r.code == "network" and _pending_profile == null:
		_pending_profile = profile   ## mất mạng: giữ lại, lần lưu sau gửi tiếp
		_online_timer.start(ONLINE_SAVE_DELAY * 5)
	online_save_failed.emit(r.message)

func _refresh_version() -> void:
	var r: Dictionary = await AccountApi.characters(ServerSelectScreen.selected_server_id)
	if r.ok:
		for c in r.data.get("characters", []):
			if int(c.get("id", 0)) == online_character_id:
				set_online_version(int(c.get("version", _online_version)))
				return

## OFFLINE và ONLINE TÁCH HẲN:
##   - Offline: file trên máy, KHÔNG phụ thuộc đăng nhập / tài khoản (chơi offline không cần tài khoản).
##   - Online: nhân vật CHỈ đến từ server (danh sách nhân vật / S_PROFILE). Máy KHÔNG đọc cũng KHÔNG ghi bản sao
##     hồ sơ online nào — mọi thay đổi gửi lên server và được server kiểm tra (ProfileGuard / guardClientSave) mới nhận.
func get_offline_profile_path(slot: int = -1) -> String:
	var s := current_offline_slot if slot < 0 else slot
	return "user://profile_offline_slot_%d.json" % s

func get_profile_path() -> String:
	return get_offline_profile_path() if GameModeManager.is_offline() else ""

func has_offline_profile(slot: int = -1) -> bool:
	var s := current_offline_slot if slot < 0 else slot
	_migrate_account_scoped_offline(s)
	var p := get_offline_profile_path(s)
	if FileAccess.file_exists(p) or FileAccess.file_exists(p + ".bak"):
		return true
	if s == 0:
		return FileAccess.file_exists(OFFLINE_PROFILE_PATH) or FileAccess.file_exists(PROFILE_PATH)
	return false

## Bản cũ từng lưu offline theo tài khoản (profile_offline_<acc>_slot_N.json) khi lỡ đang đăng nhập.
## Slot không-tài-khoản còn trống thì nhận bản mới nhất trong số đó, để người chơi không mất nhân vật offline.
func _migrate_account_scoped_offline(slot: int) -> void:
	var target := get_offline_profile_path(slot)
	if FileAccess.file_exists(target):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var suffix := "_slot_%d.json" % slot
	var best := ""
	var best_time := -1
	for f in dir.get_files():
		if f.begins_with("profile_offline_") and f.ends_with(suffix) and f != target.get_file():
			var t := FileAccess.get_modified_time("user://" + f)
			if t > best_time:
				best_time = t
				best = f
	if best != "":
		dir.copy("user://" + best, target)
		print("SaveManager: chuyển nhân vật offline cũ %s -> %s (không còn gắn tài khoản)" % [best, target.get_file()])

## Xoá các bản sao hồ sơ online cũ còn sót trên máy (trước đây game có ghi cache) — online chỉ tin server.
func _has_any_online_file() -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	for f in dir.get_files():
		if f.begins_with("profile_online"):
			return true
	return false

func _purge_online_caches() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("profile_online"):
			dir.remove(f)

func has_profile() -> bool:
	return GameModeManager.is_offline() and has_offline_profile()

func save_offline_profile(profile: PlayerProfile, slot: int = -1) -> void:
	if profile == null or _saving_disabled():
		return
	var s := current_offline_slot if slot < 0 else slot
	if _exp_save_timer != null and not _exp_save_timer.is_stopped():
		_exp_save_timer.stop()
	_pending_exp_profile = null
	var data := profile.to_dict()
	_write_secure(get_offline_profile_path(s), data)
	# Nếu lưu slot 0 thì đồng bộ thêm vào profile_offline.json cũ để tương thích
	if s == 0:
		_write_secure(OFFLINE_PROFILE_PATH, data)
	notify_profile_changed(profile)

func load_offline_profile(slot: int = -1) -> PlayerProfile:
	var s := current_offline_slot if slot < 0 else slot
	_migrate_account_scoped_offline(s)
	var path := get_offline_profile_path(s)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak") and s == 0:
		if FileAccess.file_exists(OFFLINE_PROFILE_PATH):
			path = OFFLINE_PROFILE_PATH
		elif FileAccess.file_exists(PROFILE_PATH):
			path = PROFILE_PATH
	var data := _read_secure(path)
	if data.is_empty():
		return null
	return PlayerProfile.from_dict(data)

func save_online_profile(profile: PlayerProfile, flush_immediately: bool = false) -> void:
	if profile == null:
		return
	if _exp_save_timer != null and not _exp_save_timer.is_stopped():
		_exp_save_timer.stop()
	_pending_exp_profile = null
	## Không ghi file trên máy: chỉ gửi lên server, server kiểm tra rồi mới lưu.
	if _online() and online_character_id != 0:
		_pending_profile = profile
		if flush_immediately:
			if _online_timer:
				_online_timer.stop()
			flush_online()
		else:
			_online_timer.start(ONLINE_SAVE_DELAY)
	notify_profile_changed(profile)

## Online: KHÔNG đọc hồ sơ từ máy. Nhân vật online chỉ lấy từ server (màn Danh sách nhân vật / S_PROFILE).
func load_online_profile() -> PlayerProfile:
	return null

func save_profile(profile: PlayerProfile, flush_immediately: bool = false) -> void:
	# Bảo vệ: Không ghi đè hồ sơ nhân vật thật khi đang trong trận đấu PUBG (Chiến trường sinh tồn)
	var pubg_cls = load("res://systems/pubg/pubg_manager.gd")
	if pubg_cls and pubg_cls.is_active:
		return
	if GameModeManager.is_offline():
		save_offline_profile(profile)
	else:
		save_online_profile(profile, flush_immediately)

func load_profile() -> PlayerProfile:
	if GameModeManager.is_offline():
		return load_offline_profile()
	return load_online_profile()

## Khôi phục GameManager.local_profile về bản đã lưu (dùng khi nhân vật thường chết/thoát trận, không phải GM).
## Online: bản trên server (flush_online phải gọi trước); Offline: bản trong file.
func restore_profile_from_save() -> void:
	if GameManager.local_profile == null:
		return
	if not GameModeManager.is_offline() and _online() and online_character_id != 0:
		return
	var restored := load_profile()
	if restored != null:
		GameManager.local_profile.copy_from(restored)
		print("SaveManager: khôi phục hồ sơ về bản lưu gần nhất (%s)" % ("OFFLINE" if GameModeManager.is_offline() else "ONLINE"))

func delete_offline_profile(slot: int = -1) -> bool:
	var s := current_offline_slot if slot < 0 else slot
	var path := get_offline_profile_path(s)
	var removed := false
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if err == OK:
			removed = true
	if s == 0 and FileAccess.file_exists(OFFLINE_PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OFFLINE_PROFILE_PATH))
		removed = true
	## Xoá luôn bản dự phòng, không thì nhân vật đã xoá "sống lại" từ .bak.
	for p in [path, OFFLINE_PROFILE_PATH if s == 0 else ""]:
		for ext in [".bak", ".tmp"]:
			if p != "" and FileAccess.file_exists(p + ext):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p + ext))
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		var gm = tree.root.get_node("GameManager")
		if gm != null:
			gm.local_profile = null
	notify_profile_changed(null)
	print("SaveManager: Đã xóa hồ sơ Offline thành công (%s)" % path)
	return removed

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## ---------------- PlayerStats ----------------

func _serialize_player_stats() -> Dictionary:
	return {
		"level": PlayerStats.level,
		"current_exp": PlayerStats.current_exp,
		"exp_to_next_level": PlayerStats.exp_to_next_level,
		"damage_multiplier": PlayerStats.damage_multiplier,
		"attack_speed_multiplier": PlayerStats.attack_speed_multiplier,
		"range_multiplier": PlayerStats.range_multiplier,
		"extra_projectile_count": PlayerStats.extra_projectile_count,
		"applied_upgrade_ids": PlayerStats.applied_upgrade_ids,
	}

func _deserialize_player_stats(data: Dictionary) -> void:
	if data.is_empty():
		return
	PlayerStats.level = int(data.get("level", 1))
	PlayerStats.current_exp = float(data.get("current_exp", 0.0))
	PlayerStats.exp_to_next_level = float(data.get("exp_to_next_level", 500.0))
	PlayerStats.damage_multiplier = float(data.get("damage_multiplier", 1.0))
	PlayerStats.attack_speed_multiplier = float(data.get("attack_speed_multiplier", 1.0))
	PlayerStats.range_multiplier = float(data.get("range_multiplier", 1.0))
	PlayerStats.extra_projectile_count = 0
	var ids: Array[String] = []
	for id in data.get("applied_upgrade_ids", []):
		ids.append(str(id))
	PlayerStats.applied_upgrade_ids = ids

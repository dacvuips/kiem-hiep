extends Node
## Autoload — lưu/load tiến trình PlayerStats (level/exp/multiplier TRONG 1 lượt chơi) ra
## res://user data (JSON). Tiến trình môn phái/skill (lâu dài) nằm ở PlayerProfile — xem phần
## PlayerProfile bên dưới, lưu file riêng profile.json.

const SAVE_PATH := "user://savegame.json"

## Khóa mã hóa bảo vệ file lưu cục bộ, gắn liền với thiết bị người chơi (chống sửa file text trực tiếp).
const _KEY_PREFIX_OBF: PackedByteArray = [48, 25, 89, 66, 5, 28, 242, 238, 191, 234, 197, 196, 219, 199, 213, 183, 179, 235]

static func _save_key() -> String:
	var id := OS.get_unique_id()
	var prefix := Obfuscator.deobfuscate(_KEY_PREFIX_OBF)
	return (prefix + (id if id != "" else OS.get_name())).sha256_text()

signal game_saved
signal game_loaded

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

	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, _save_key())
	if file == null:
		push_warning("SaveManager: không mở được file để ghi (%s)" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	game_saved.emit()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game(_player: Node) -> bool:
	if not has_save():
		return false

	var text := ""
	# Thử đọc mã hoá trước; nếu file cũ chưa mã hoá thì đọc thường để tương thích ngược
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, _save_key())
	if file != null:
		text = file.get_as_text()
		file.close()
	else:
		file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			text = file.get_as_text()
			file.close()
		else:
			push_warning("SaveManager: không mở được file để đọc (%s)" % SAVE_PATH)
			return false

	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveManager: file save hỏng hoặc sai định dạng.")
		return false

	var data: Dictionary = parsed
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
const ONLINE_SAVE_DELAY := 2.0

## Lưu lên server thất bại (mất mạng, máy khác vừa lưu...) — UI có thể nghe để báo người chơi.
signal online_save_failed(message: String)

## Nhân vật đang chơi trên server (0 = chưa chọn).
var online_character_id := 0
var _online_version := 0
var _pending_profile: PlayerProfile
var _online_saving := false
var _online_timer: Timer
## Vừa rời map online: game server đã lưu với version mới mà máy chưa biết -> lần lưu HTTP kế tiếp hỏi lại version trước.
var _version_unknown := false

func _ready() -> void:
	_online_timer = Timer.new()
	_online_timer.one_shot = true
	_online_timer.wait_time = ONLINE_SAVE_DELAY
	_online_timer.timeout.connect(flush_online)
	add_child(_online_timer)
	## Tự xử lý nút đóng cửa sổ để kịp gửi bản lưu cuối lên server.
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _pending_profile != null or _online_saving:
			await flush_online()
		get_tree().quit()

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

func has_profile() -> bool:
	if _online() and online_character_id != 0:
		return false
	return FileAccess.file_exists(PROFILE_PATH)

func save_profile(profile: PlayerProfile) -> void:
	if profile == null:
		return
	## Luôn lưu vào file máy cục bộ (PROFILE_PATH) được mã hoá bằng khoá máy để bảo vệ dữ liệu
	if not _saving_disabled():
		var file := FileAccess.open_encrypted_with_pass(PROFILE_PATH, FileAccess.WRITE, _save_key())
		if file != null:
			file.store_string(JSON.stringify(profile.to_dict(), "\t"))
			file.close()
		else:
			push_warning("SaveManager: không mở được file để ghi (%s)" % PROFILE_PATH)

	## Online: lưu lên server cho nhân vật ĐÃ CHỌN trong tiến trình này (set_online_character)
	if _online():
		if online_character_id != 0:
			_pending_profile = profile
			_online_timer.start(ONLINE_SAVE_DELAY)
		return

## Khôi phục GameManager.local_profile về bản đã lưu (dùng khi nhân vật thường chết/thoát trận, không phải GM).
## Online: bản trên server (flush_online phải gọi trước); Offline: bản trong file.
func restore_profile_from_save() -> void:
	if GameManager.local_profile == null:
		return
	var restored: PlayerProfile = null
	if _online() and online_character_id != 0:
		## Online: server giữ bản đúng (game server không lưu khi người chơi chết/thoát giữa chừng bởi flush_online trả về không gửi S_PROFILE)
		## — nạp lại khi vào Hub qua AccountApi.characters; không cần làm gì thêm ở đây.
		return
	## Offline: nạp lại từ file
	restored = load_profile()
	if restored != null:
		GameManager.local_profile.copy_from(restored)
		print("SaveManager: khôi phục hồ sơ về bản lưu gần nhất (nhân vật thường, không phải GM)")

func load_profile() -> PlayerProfile:
	if not has_profile():
		return null
	var text := ""
	var file := FileAccess.open_encrypted_with_pass(PROFILE_PATH, FileAccess.READ, _save_key())
	if file != null:
		text = file.get_as_text()
		file.close()
	else:
		file = FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if file != null:
			text = file.get_as_text()
			file.close()
		else:
			push_warning("SaveManager: không mở được file profile.")
			return null
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveManager: file profile hỏng hoặc sai định dạng.")
		return null
	return PlayerProfile.from_dict(parsed)

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

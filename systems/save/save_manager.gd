extends Node
## Autoload — lưu/load tiến trình PlayerStats (level/exp/multiplier TRONG 1 lượt chơi) ra
## res://user data (JSON). Tiến trình môn phái/skill (lâu dài) nằm ở PlayerProfile — xem phần
## PlayerProfile bên dưới, lưu file riêng profile.json.

const SAVE_PATH := "user://savegame.json"

signal game_saved
signal game_loaded

func save_game(_player: Node) -> void:
	var data := {
		"version": 1,
		"player_stats": _serialize_player_stats(),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
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

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: không mở được file để đọc (%s)" % SAVE_PATH)
		return false
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveManager: file save hỏng hoặc sai định dạng.")
		return false

	var data: Dictionary = parsed
	_deserialize_player_stats(data.get("player_stats", {}))
	game_loaded.emit()
	return true

## ---------------- PlayerProfile (nhân vật ngoài trận) ----------------
## File riêng với savegame.json: profile tồn tại xuyên suốt nhiều lượt chơi, còn savegame.json
## là tiến trình gem/skill. Khi lên online, 2 hàm này sẽ đổi thành gọi API server.

const PROFILE_PATH := "user://profile.json"

func has_profile() -> bool:
	return FileAccess.file_exists(PROFILE_PATH)

func save_profile(profile: PlayerProfile) -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: không mở được file để ghi (%s)" % PROFILE_PATH)
		return
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))
	file.close()

func load_profile() -> PlayerProfile:
	if not has_profile():
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
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
	PlayerStats.exp_to_next_level = float(data.get("exp_to_next_level", 10.0))
	PlayerStats.damage_multiplier = float(data.get("damage_multiplier", 1.0))
	PlayerStats.attack_speed_multiplier = float(data.get("attack_speed_multiplier", 1.0))
	PlayerStats.range_multiplier = float(data.get("range_multiplier", 1.0))
	PlayerStats.extra_projectile_count = int(data.get("extra_projectile_count", 0))
	var ids: Array[String] = []
	for id in data.get("applied_upgrade_ids", []):
		ids.append(str(id))
	PlayerStats.applied_upgrade_ids = ids

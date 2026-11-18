extends RefCounted
class_name LonXonManager
## Trạng thái Lộn Xộn trên MÁY NGƯỜI CHƠI (online — LonXonServer giữ luật thật). Như PubgManager.start_online_match / end_match:
## vào host thì sao lưu hồ sơ thật, ra thì trả lại nguyên vẹn (server không bao giờ lưu hồ sơ tạm).

const MAP_ID := 45

static var is_active := false
static var match_confirmed := false
static var host := 0
static var box := Rect2()
static var backup_profile_data: Dictionary = {}

## Tin "match" của LonXonServer (lúc đang ở Hub) -> mục map cho Character Hub._enter_field_map.
## KHÔNG sửa hồ sơ ở đây: Hub còn gửi hồ sơ lên server lúc rời màn — hồ sơ tạm chỉ dựng khi đã vào map (LonXonClient).
static func start_online(profile: PlayerProfile, msg: Dictionary) -> Dictionary:
	is_active = true
	match_confirmed = false
	host = int(msg.get("host", 0))
	backup_profile_data = profile.to_dict().duplicate(true) if profile != null else {}
	PubgDraftPopup.lonxon_pending_draft = {}
	var b: Array = msg.get("box", [0, 0, 0, 0])
	box = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3])) if b.size() >= 4 else Rect2()
	var sp_arr: Array = msg.get("spawn", [])
	var spawn: Vector2 = Vector2(float(sp_arr[0]), float(sp_arr[1])) if sp_arr.size() >= 2 else box.get_center()
	var title := "Lộn Xộn — Host %d" % host
	return {
		"id": MAP_ID, "name": title, "title": title, "kind": "Battlefield",
		"dir": PubgManager.TONGKIM1_DIR, "folder": PubgManager.TONGKIM1_DIR,
		"lon_xon": true, "lonxon_online": true, "lonxon_host": host,
		"arena_box": box, "arena_center": box.get_center(), "arena_size": box.size,
		"spawn_pos": spawn, "start": [int(spawn.x / PubgManager.REGION_PX), int(spawn.y / PubgManager.REGION_PX)],
		"no_monsters": false,
	}

## Rời host: trả hồ sơ thật, tắt cờ trận.
static func end(profile: PlayerProfile = null) -> void:
	is_active = false
	match_confirmed = false
	host = 0
	LonXonRules.in_match = false
	PubgDraftPopup.lonxon_pending_draft = {}
	var target := profile
	if target == null and GameManager and "local_profile" in GameManager:
		target = GameManager.local_profile
	if target != null and not backup_profile_data.is_empty():
		target.copy_from(PlayerProfile.from_dict(backup_profile_data))
		if target.has_signal("equipment_changed"):
			target.equipment_changed.emit()
		if target.has_method("recalc_stats"):
			target.recalc_stats()
		if SaveManager != null and SaveManager.has_signal("profile_changed"):
			SaveManager.profile_changed.emit(target)
	backup_profile_data.clear()
	if GameManager and "field_map" in GameManager and GameManager.field_map is Dictionary and GameManager.field_map.get("lon_xon", false):
		GameManager.field_map = {}

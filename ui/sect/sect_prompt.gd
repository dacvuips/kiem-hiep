extends Node
class_name SectPrompt
## Node nhẹ đặt trong cảnh chơi: nhân vật Vô Môn Phái đủ PlayerProfile.NEWBIE_LEVEL thì mở SectChoiceWindow (giống NationPrompt).
## BẮT BUỘC chọn phái (không "Để sau"): nhân vật mới vào game đã ở cấp 10 (StarterKit) nên bảng hiện ngay khi vào map.
## Không tự mở khi cây đang tạm dừng (đang mở bảng khác). Offline: chọn xong phát vũ khí tân thủ (online do game server phát).

const CHECK_INTERVAL := 1.0

var _window: SectChoiceWindow
var _check_left := 0.0

func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	var p := GameManager.local_profile
	if is_instance_valid(_window) and (p == null or not p.needs_sect()):
		_window.close_requested.emit()   ## server vừa trả cấp thật < 10 (hoặc đã có phái) -> thôi hỏi
		return
	if p == null or not p.needs_sect() or is_instance_valid(_window) or get_tree().paused or not _server_ready():
		return
	ask_now()

## Online: chỉ hỏi khi đã nhận bản nhân vật chuẩn của server (cấp thật) — cấp tăng bằng nút TEST ở Hub chỉ có ở máy mình,
## server vẫn giữ cấp cũ và sẽ không nhận phái.
func _server_ready() -> bool:
	return not NetWorldSync.is_online_mode() or (NetWorldSync.current != null and NetWorldSync.current.profile_synced)

## Mở bảng chọn phái ngay (bỏ qua "Để sau") — false nếu nhân vật chưa cần chọn phái.
func ask_now() -> bool:
	var p := GameManager.local_profile
	if p == null or not p.needs_sect() or not _server_ready():
		return false
	if is_instance_valid(_window):
		_window.bring_to_front()
		return true
	_window = SectChoiceWindow.open(get_tree().current_scene, p)
	_window.chosen.connect(_on_chosen)
	return true

func _on_chosen(sect: SectDefinition) -> void:
	var p := GameManager.local_profile
	var weapon: ItemInstance = null
	if not NetWorldSync.is_online_mode():
		weapon = StarterKit.give_sect_weapon(p)
	SaveManager.save_profile(p)
	SaveManager.flush_online()   ## online: gửi ngay, tránh bản server cũ (S_PROFILE) ghi đè phái vừa chọn
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("refresh_sect"):
		player.refresh_sect()
	var bar := get_tree().current_scene.get_node_or_null("UI/SkillBarUI") as SkillBarUI
	if bar != null:
		bar.refresh_sub_skills()
	if player != null and player.has_method("_notice"):
		player._notice("Đã gia nhập %s! Mở bảng Kỹ năng để học võ công." % sect.sect_name)
		if weapon != null:
			player._notice("Môn phái tặng vũ khí tân thủ: %s (xem hành trang)." % weapon.get_base().get("name", "?"))

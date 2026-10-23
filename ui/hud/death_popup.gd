extends CanvasLayer
class_name DeathPopup
## Bảng "Bạn đã bị trọng thương!" khi nhân vật chết (như VLTK gốc): giữ nguyên cảnh vật phía sau, chỉ hiện khung chữ ở giữa-dưới
## với dòng "Về thành dưỡng sức" — bấm để về Character Hub (Chiến trường Tống Kim: sống lại ở hậu doanh phe mình).

const HUB_SCENE_PATH := "res://ui/character_hub/CharacterHub.tscn"

static func show_for(host: Node) -> DeathPopup:
	if host == null or not is_instance_valid(host):
		return null
	var tree := host.get_tree() if host.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var popup := DeathPopup.new()
	tree.current_scene.add_child(popup)
	return popup

func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	## Khung + nút theo chuẩn GameUi (không phủ nền tối — giữ cảnh vật phía sau như VLTK gốc).
	var panel := GameUi.panel(GameUi.WINDOW)
	panel.custom_minimum_size = Vector2(520, 150)
	## Ngay GIỮA màn hình (giữa cả ngang lẫn dọc).
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	anchor.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	panel.add_child(box)

	var message := Label.new()
	message.text = "Bạn đã bị trọng thương!"
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_color", GameUi.TEXT)
	box.add_child(message)

	var go_home := GameUi.button("Về thành dưỡng sức", GameUi.PRIMARY)
	go_home.custom_minimum_size.x = 220
	go_home.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	go_home.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go_home.pressed.connect(_go_home)
	box.add_child(go_home)

## Mọi map: về Character Hub. Riêng Chiến trường Tống Kim: sống lại ở hậu doanh phe mình (server kéo về điểm hồi sinh).
## GM: lưu và giữ nguyên dữ liệu (không rollback). Người thường: load lại từ bản đã lưu trước khi vào màn (không lưu bản chết).
func _go_home() -> void:
	PlayerStats.reset()
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = false
	var player: Node = tree.get_first_node_in_group("player") if tree != null else null
	var in_battle := not (GameManager.field_map.get("battle", {}) as Dictionary).is_empty()
	if in_battle and player != null and player.has_method("revive_at_start"):
		player.revive_at_start()
		queue_free()
		return
	if GameManager.local_profile != null:
		if AccountApi.is_gm():
			## GM: lưu toàn bộ tiến trình (cấp, đồ, kỹ năng từ TEST đều được giữ lại)
			SaveManager.save_profile(GameManager.local_profile)
			await SaveManager.flush_online()
		else:
			## Người thường: KHÔNG lưu bản chết — khôi phục hồ sơ về trạng thái trước trận
			SaveManager.restore_profile_from_save()
			await SaveManager.flush_online()
	get_tree().change_scene_to_file(HUB_SCENE_PATH)

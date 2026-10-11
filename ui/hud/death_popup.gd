extends CanvasLayer
class_name DeathPopup
## Bảng "Bạn đã bị trọng thương!" khi nhân vật chết (như VLTK gốc): giữ nguyên cảnh vật phía sau, chỉ hiện khung chữ ở giữa-dưới
## với dòng "Về thành dưỡng sức" — bấm để rời trận, quay về Hub (nơi hồi phục).

const HUB_SCENE_PATH := "res://ui/character_hub/CharacterHub.tscn"
const GOLD := Color(0.83, 0.68, 0.21)

static func show_for(host: Node) -> DeathPopup:
	var popup := DeathPopup.new()
	host.get_tree().current_scene.add_child(popup)
	return popup

func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.05, 0.88)
	style.border_color = Color(0.55, 0.52, 0.42)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
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
	message.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	box.add_child(message)

	var go_home := Button.new()
	go_home.text = "Về thành dưỡng sức"
	go_home.flat = true
	go_home.focus_mode = Control.FOCUS_NONE
	go_home.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	go_home.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go_home.add_theme_font_size_override("font_size", 17)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		go_home.add_theme_color_override(c, Color(0.95, 0.93, 0.85) if c == "font_color" else GOLD)
	go_home.pressed.connect(_go_home)
	box.add_child(go_home)

func _go_home() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE_PATH)

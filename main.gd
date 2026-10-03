extends Node2D

@export var stage_for_testing: StageData

var elapsed_time: float = 0.0
var current_world: Node

@onready var time_label: Label = $UI/TimeLabel
@onready var world_container: Node = $World
@onready var skill_bar_ui: SkillBarUI = $UI/SkillBarUI
@onready var joystick: MoveJoystick = $UI/VirtualJoystick
@onready var status_hud: PlayerStatusHud = $UI/PlayerStatusHud

const HUB_SCENE_PATH := "res://ui/character_hub/CharacterHub.tscn"

var _skill_book_open: bool = false
## Map hiện tại có cho hiện joystick không (StageData.show_move_joystick) — để khôi phục đúng trạng
## thái sau khi đóng bảng skill (lúc mở bảng luôn ẩn joystick).
var _joystick_enabled: bool = true
var _exit_confirm: PanelContainer
## Khung Nhân vật / Hành trang mở trong trận (null = đang đóng). KHÔNG tạm dừng trận, joystick vẫn hiện —
## vừa xem đồ vừa chạy được (giống VLTK, cũng là cách duy nhất khi chơi online).
var _status_window: CharacterStatusWindow
var _inventory_window: InventoryPopup

func _ready() -> void:
	current_world = world_container

	var stage: StageData = GameManager.current_stage if GameManager.current_stage else stage_for_testing
	if stage:
		load_stage(stage)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		skill_bar_ui.setup(player)
		status_hud.setup(player)
		## Bấm (không kéo) trong vùng joystick vẫn là "chạy tới chỗ bấm" như ở mọi chỗ khác trên bản đồ.
		joystick.tapped.connect(player.move_to_screen_position)

	_build_exit_button()
	$UI/CharacterButton.pressed.connect(_toggle_status_window)
	$UI/InventoryButton.pressed.connect(_toggle_inventory_window)
	$UI/SkillsButton.pressed.connect(_open_skill_book)

func load_stage(stage: StageData) -> void:
	GameManager.start_stage(stage)
	_joystick_enabled = stage.show_move_joystick
	joystick.visible = _joystick_enabled

	if stage.world_scene:
		var old_world := current_world
		var new_world := stage.world_scene.instantiate()
		add_child(new_world)
		move_child(new_world, old_world.get_index())
		current_world = new_world
		old_world.queue_free()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	elapsed_time += delta
	var total_seconds := int(elapsed_time)
	@warning_ignore("integer_division")
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]

func _unhandled_key_input(event: InputEvent) -> void:
	if not (OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F9:
		PlayerStats.level_up()
	elif event.keycode == KEY_F5:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			SaveManager.save_game(player)
			print("Đã lưu game.")
	elif event.keycode == KEY_F6:
		var player := get_tree().get_first_node_in_group("player")
		if player and SaveManager.load_game(player):
			print("Đã tải game.")
	elif event.keycode == KEY_F10:
		DebugDataBrowser.open(self, func() -> void: pass)

## Mở bảng "Kỹ Năng Võ Công" ngay trong trận (tái dùng phím open_gem_menu vốn dùng cho
## GemSocketScreen cũ, đã gỡ bỏ cùng gem_system) — pause game trong lúc xem/học skill.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_gem_menu"):
		_open_skill_book()

## Mở bảng Kỹ Năng — phím G (action open_gem_menu) hoặc nút "Kỹ năng" ở thanh trên.
func _open_skill_book() -> void:
	if _skill_book_open:
		return
	if GameManager.local_profile == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var sect := SectRegistry.get_by_id(GameManager.local_profile.sect_id)
	if sect == null:
		return
	_skill_book_open = true
	get_tree().paused = true
	## Ẩn joystick trong lúc mở bảng (bảng phủ gần kín màn). Gắn skill lên thanh kỹ năng làm ngay trong cột
	## "Tùy chỉnh kỹ năng" của bảng, đóng bảng thì thanh skill trong trận vẽ lại theo profile.
	joystick.visible = false
	SkillBookScreen.open(self, GameManager.local_profile, sect.skills, func() -> void:
		_skill_book_open = false
		get_tree().paused = false
		joystick.visible = _joystick_enabled
		skill_bar_ui.refresh_sub_skills()
		## Skill nội tại vừa học trong bảng cộng bonus vào combat_stats — áp dụng ngay, không đợi trận sau.
		if is_instance_valid(player):
			player.refresh_combat_stats())

# ------------------------------------------------- khung Nhân vật / Hành trang trong trận

## 2 khung độc lập, kéo di chuyển được, mở cùng lúc được. Bấm lại nút để đóng. Trận vẫn chạy.
func _toggle_status_window() -> void:
	if is_instance_valid(_status_window):
		_status_window.queue_free()
		return
	if GameManager.local_profile == null:
		return
	_status_window = CharacterStatusWindow.open(self, GameManager.local_profile, _toggle_inventory_window)
	_status_window.screen.profile_changed.connect(_on_panel_profile_changed)

func _toggle_inventory_window() -> void:
	if is_instance_valid(_inventory_window):
		_inventory_window.queue_free()
		return
	if GameManager.local_profile == null:
		return
	_inventory_window = InventoryPopup.open(self, GameManager.local_profile, _on_panel_profile_changed, false)

## Mặc/tháo đồ, cộng điểm: vẽ lại khung Nhân vật + áp chỉ số mới lên nhân vật ngay.
func _on_panel_profile_changed() -> void:
	if is_instance_valid(_status_window):
		_status_window.screen.refresh()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.refresh_combat_stats()

## Nút "Thoát Trận" góc trên trái — bấm hiện popup xác nhận trước khi quay về Character Hub,
## tránh mất tiến độ trận đang chơi do bấm nhầm.
func _build_exit_button() -> void:
	var ui: CanvasLayer = $UI
	var button := Button.new()
	button.text = "Thoát Trận"
	button.offset_left = 20
	button.offset_top = 20
	button.offset_right = 140
	button.offset_bottom = 56
	button.pressed.connect(_on_exit_button_pressed)
	ui.add_child(button)

func _on_exit_button_pressed() -> void:
	if _exit_confirm:
		return
	get_tree().paused = true

	var overlay := CanvasLayer.new()
	overlay.layer = 90
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	_exit_confirm = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.96)
	style.border_color = Color(0.83, 0.68, 0.21)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	_exit_confirm.add_theme_stylebox_override("panel", style)
	center.add_child(_exit_confirm)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_exit_confirm.add_child(vbox)

	var message := Label.new()
	message.text = "Bạn có chắc muốn thoát trận?\nTiến độ trận đấu hiện tại sẽ không được lưu."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	vbox.add_child(message)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	var confirm_button := Button.new()
	confirm_button.text = "Thoát"
	confirm_button.pressed.connect(_on_exit_confirmed)
	button_row.add_child(confirm_button)

	var cancel_button := Button.new()
	cancel_button.text = "Hủy"
	cancel_button.pressed.connect(_on_exit_cancelled.bind(overlay))
	button_row.add_child(cancel_button)

func _on_exit_confirmed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE_PATH)

func _on_exit_cancelled(overlay: CanvasLayer) -> void:
	overlay.queue_free()
	_exit_confirm = null
	get_tree().paused = false

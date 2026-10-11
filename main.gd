extends Node2D

@export var stage_for_testing: StageData

var elapsed_time: float = 0.0

@onready var time_label: Label = $UI/TimeLabel
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

## Map VLTK dùng để lấy nhạc nền khi StageData không khai báo vltk_map_id — tạm, thay bằng map thật của màn.
const DEFAULT_MUSIC_MAP_ID := 1

func _play_stage_music(stage: StageData) -> void:
	var map_id := stage.vltk_map_id if stage.vltk_map_id > 0 else DEFAULT_MUSIC_MAP_ID
	MusicManager.play_map(map_id)

func _exit_tree() -> void:
	MusicManager.stop()

func _ready() -> void:
	var free_roam := GameManager.game_mode == GameManager.GameMode.MAIN_MAP
	var stage: StageData = GameManager.current_stage if GameManager.current_stage else stage_for_testing
	if free_roam:
		_enter_main_map()
	elif stage:
		load_stage(stage)
		_play_stage_music(stage)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		skill_bar_ui.setup(player)
		status_hud.setup(player)
		var top_bar := TopStatusBar.new()
		$UI.add_child(top_bar)
		top_bar.setup(player)
		## Bấm (không kéo) trong vùng joystick vẫn là "chạy tới chỗ bấm" như ở mọi chỗ khác trên bản đồ.
		joystick.tapped.connect(player.move_to_screen_position)

	if player:
		var mini_map := MiniMap.new()
		mini_map.name = "MiniMap"
		$UI.add_child(mini_map)
		mini_map.setup(player)

	_build_exit_button()
	_build_social_buttons()
	add_child(SocialTicker.new())   ## nhịp nền xã hội: khách mua hàng bày bán, người xin vào đội/bang
	_build_monster_test_button()
	_build_skill_test_button()
	$UI/CharacterButton.pressed.connect(_toggle_status_window)
	$UI/InventoryButton.pressed.connect(_toggle_inventory_window)
	$UI/SkillsButton.pressed.connect(_open_skill_book)

## Chế độ "Chơi": đi lại tự do trên toàn map chính. Không ô vuông giới hạn, không sinh quái / vật phẩm kiểu sinh tồn, không đếm giờ ải.
## Vẫn giữ nguyên: skill + thanh skill, trang bị, cộng chỉ số, di chuyển, ngựa, mini map.
func _enter_main_map() -> void:
	GameManager.current_stage = null
	joystick.visible = true
	_joystick_enabled = true
	time_label.visible = false
	$Spawner.set_process(false)
	$PickupSpawner.set_process(false)
	VltkWorld.net_monsters = NetWorldSync.is_online_mode()
	if VltkWorld.current != null:
		VltkWorld.current.setup_main_map()
	MusicManager.play_map(DEFAULT_MUSIC_MAP_ID)
	## Online: nối với game server (thấy người chơi khác, server kiểm tra di chuyển).
	if NetWorldSync.is_online_mode():
		var sync := NetWorldSync.new()
		sync.name = "NetWorldSync"
		sync.player = get_tree().get_first_node_in_group("player")
		add_child(sync)

func load_stage(stage: StageData) -> void:
	GameManager.start_stage(stage)
	_joystick_enabled = stage.show_move_joystick
	joystick.visible = _joystick_enabled

	## Map chính (World = VltkWorld) dùng chung mọi màn; màn chỉ là 1 ô vuông trên đó (StageData.arena_*).
	if VltkWorld.current != null:
		VltkWorld.current.setup_stage(stage)

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
	if event.keycode == KEY_F8:
		## Chép toạ độ (pixel map) của nhân vật để dán vào StageData.arena_center khi đặt ô vuông màn chơi.
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p:
			var feet := p.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
			var text := "Vector2(%d, %d)" % [roundi(feet.x), roundi(feet.y)]
			DisplayServer.clipboard_set(text)
			print("arena_center = ", text, "  (đã chép vào clipboard)")
	elif event.keycode == KEY_F9:
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

## Hàng nút xã hội RIÊNG LẺ (mỗi chức năng 1 nút) nằm dưới thanh trạng thái, bên phải khung thông tin nhân vật:
## Tổ đội · Bang hội · Rương · Bày bán · Khoá bảo vệ.
func _build_social_buttons() -> void:
	var entries := [
		["Giao lưu", "Người chơi ở gần: giao dịch, xem quầy, xem trang bị", func(p: PlayerProfile) -> void: SocialMenuWindow.open(self, p)],
		["Tổ đội", "Lập nhóm, mời / xin vào đội", func(p: PlayerProfile) -> void: TeamWindow.open(self, SocialHub.of(p))],
		["Bang hội", "Bang hội: tin tức, chiêu mộ, quyền hạn, nhật ký", func(p: PlayerProfile) -> void: GuildWindow.open(self, SocialHub.of(p))],
		["Rương", "Rương chứa đồ (có khoá bảo vệ)", func(p: PlayerProfile) -> void: StorageWindow.open(self, p)],
		["Bày bán", "Đặt giá và bày bán đồ, mở giao dịch", func(p: PlayerProfile) -> void: StallWindow.open(self, SocialHub.of(p))],
		["Khoá bảo vệ", "Mật mã bảo vệ rương và đồ đạc", func(p: PlayerProfile) -> void: SecurityWindow.open(self, p)],
	]
	var x := 310.0
	for e in entries:
		var button := Button.new()
		button.text = e[0]
		button.offset_left = x
		button.offset_top = 80
		button.offset_right = x + 108
		button.offset_bottom = 114
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = e[1]
		var open_fn: Callable = e[2]
		button.pressed.connect(func() -> void:
			if GameManager.local_profile != null:
				open_fn.call(GameManager.local_profile))
		$UI.add_child(button)
		x += 116.0

## Nút "Quái" — mở/đóng popup thử quái VLTK (danh sách mọi quái, xem động tác, tạo quái quanh người chơi để thử).
var _monster_popup: MonsterTestPopup

func _build_monster_test_button() -> void:
	var button := Button.new()
	button.text = "Quái"
	button.offset_left = 510
	button.offset_top = 36
	button.offset_right = 600
	button.offset_bottom = 72
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Danh sách quái VLTK — tạo quái để thử"
	button.pressed.connect(_toggle_monster_popup)
	$UI.add_child(button)

func _toggle_monster_popup() -> void:
	if _monster_popup == null or not is_instance_valid(_monster_popup):
		_monster_popup = MonsterTestPopup.new()
		$UI.add_child(_monster_popup)
		return
	_monster_popup.visible = not _monster_popup.visible

## Nút "Skill" — mở/đóng bảng tổng hợp skill (chia theo phái) để thi triển thử.
var _skill_popup: SkillTestPopup

func _build_skill_test_button() -> void:
	var button := Button.new()
	button.text = "Skill"
	button.offset_left = 660
	button.offset_top = 36
	button.offset_right = 750
	button.offset_bottom = 72
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Bảng tất cả skill theo phái — thi triển thử"
	button.pressed.connect(_toggle_skill_popup)
	$UI.add_child(button)

func _toggle_skill_popup() -> void:
	if _skill_popup == null or not is_instance_valid(_skill_popup):
		_skill_popup = SkillTestPopup.new()
		$UI.add_child(_skill_popup)
		return
	_skill_popup.visible = not _skill_popup.visible

## Nút "Thoát Trận" góc trên trái — bấm hiện popup xác nhận trước khi quay về Character Hub,
## tránh mất tiến độ trận đang chơi do bấm nhầm.
func _build_exit_button() -> void:
	var ui: CanvasLayer = $UI
	var button := Button.new()
	button.text = "Thoát" if GameManager.game_mode == GameManager.GameMode.MAIN_MAP else "Thoát Trận"
	button.offset_left = 20
	button.offset_top = 36
	button.offset_right = 140
	button.offset_bottom = 72
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

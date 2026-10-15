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

	_build_side_menu()
	$UI.add_child(QuickItemBar.new())   ## 4 ô thuốc nhanh ngay trên cụm nút skill
	add_child(SocialTicker.new())   ## nhịp nền xã hội: khách mua hàng bày bán, người xin vào đội/bang
	_sect_prompt = SectPrompt.new()   ## Vô Môn Phái đủ cấp 10 thì hỏi gia nhập môn phái
	add_child(_sect_prompt)
	if OS.is_debug_build():   ## công cụ thử (chỉ bản debug): hàng nút nhỏ góc trên trái
		_build_debug_button("Quái", "Danh sách quái VLTK — tạo quái để thử", _toggle_monster_popup)
		_build_debug_button("Skill", "Bảng tất cả skill theo phái — thi triển thử", _toggle_skill_popup)
		_build_debug_button("TEST", "Thử nhân vật: lên cấp, đồ, tiền, cộng chỉ số", _open_test_window)

## Chế độ "Chơi": đi lại tự do trên toàn map chính. Không ô vuông giới hạn, không sinh quái / vật phẩm kiểu sinh tồn, không đếm giờ ải.
## Vẫn giữ nguyên: skill + thanh skill, trang bị, cộng chỉ số, di chuyển, ngựa, mini map.
func _enter_main_map() -> void:
	GameManager.current_stage = null
	joystick.visible = true
	_joystick_enabled = true
	time_label.visible = false
	$Spawner.set_process(false)
	$PickupSpawner.set_process(false)
	## Map luyện công (màn "Vượt Ải"): game server hiện chỉ chạy map chính -> map này chơi offline, quái do client sinh.
	var field := GameManager.field_map
	## Chiến trường Tống Kim (tab Ải): luôn online, nối tới battle server riêng ({side, server}).
	var battle: Dictionary = field.get("battle", {})
	## Đấu trường PK online (popup PK lúc đã đăng nhập): nối tới arena server riêng ({mode, online, server, action}).
	var pk: Dictionary = field.get("pk", {})
	var pk_online := bool(pk.get("online", false))
	var online := (NetWorldSync.is_online_mode() and field.is_empty()) or not battle.is_empty() or pk_online
	VltkWorld.net_monsters = online
	if VltkWorld.current != null:
		if not field.is_empty():
			VltkWorld.current.map_dir = str(field["dir"])
		VltkWorld.current.setup_main_map()
	## Thách Thức Thời Gian (tab "Ải" của màn Vượt Ải): đấu trường map 480, quái theo từng ải.
	if field.get("challenge", false):
		var challenge := TimeChallenge.new()
		challenge.name = "TimeChallenge"
		add_child(challenge)
	## Trận PK với bot (nút PK ở Character Hub, offline / không tìm được người): đấu trường map 397.
	if field.has("pk") and not pk_online:
		var match_node := PkMatch.new()
		match_node.name = "PkMatch"
		add_child(match_node)
	if field.is_empty() or not MusicManager.play_map(int(field["id"])):
		MusicManager.play_map(DEFAULT_MUSIC_MAP_ID)
	## Online: nối với game server (thấy người chơi khác, server kiểm tra di chuyển).
	if online:
		var sync := NetWorldSync.new()
		sync.name = "NetWorldSync"
		sync.player = get_tree().get_first_node_in_group("player")
		sync.server_override = pk.get("server", {}) if pk_online else battle.get("server", {})
		add_child(sync)
	else:
		ChatBox.attach($UI)   ## offline vẫn có ô chat Gần (online: NetWorldSync tự thêm)
	if not battle.is_empty():
		add_child(BattleClient.create(str(battle["side"]), int(field["id"])))
	if pk_online:
		add_child(ArenaClient.create(pk))

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

var _sect_prompt: SectPrompt

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
	if sect == null:   ## Vô Môn Phái: chưa có skill phái — đủ cấp thì mở bảng chọn phái
		if _sect_prompt != null and _sect_prompt.ask_now():
			return
		player._notice("Chưa gia nhập môn phái — đạt cấp %d để chọn phái và học võ công." % PlayerProfile.NEWBIE_LEVEL)
		return
	_skill_book_open = true
	## Chỉ mở bảng — trận vẫn chạy bình thường (không dừng game, không tắt nhạc, giữ joystick). Gắn skill lên thanh kỹ năng làm
	## ngay trong cột "Tùy chỉnh kỹ năng" của bảng, đóng bảng thì thanh skill trong trận vẽ lại theo profile.
	SkillBookScreen.open(self, GameManager.local_profile, sect.skills, func() -> void:
		_skill_book_open = false
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
	if not is_instance_valid(_inventory_window):
		_inventory_window = InventoryPopup.find_open(get_tree())   ## có thể đang mở kèm Rương chứa đồ
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

## Nút "Quái" — mở/đóng popup thử quái VLTK (danh sách mọi quái, xem động tác, tạo quái quanh người chơi để thử).
var _monster_popup: MonsterTestPopup

func _toggle_monster_popup() -> void:
	if _monster_popup == null or not is_instance_valid(_monster_popup):
		_monster_popup = MonsterTestPopup.new()
		$UI.add_child(_monster_popup)
		return
	_monster_popup.visible = not _monster_popup.visible

## Nút "Skill" — mở/đóng bảng tổng hợp skill (chia theo phái) để thi triển thử.
var _skill_popup: SkillTestPopup

func _toggle_skill_popup() -> void:
	if _skill_popup == null or not is_instance_valid(_skill_popup):
		_skill_popup = SkillTestPopup.new()
		$UI.add_child(_skill_popup)
		return
	_skill_popup.visible = not _skill_popup.visible

## Cột nút tiện ích bên trái (kiểu VLTK mobile) — SideMenu (hàng ngang góc trên phải): Nhân vật, Hành trang, Kỹ năng, sát bên trái nút Cài đặt (có Thoát) cạnh mini map.
func _build_side_menu() -> void:
	var menu := SideMenu.new()
	menu.name = "SideMenu"
	menu.add_entry("status", "", "Nhân vật", _toggle_status_window)
	menu.add_entry("items", "", "Hành trang", _toggle_inventory_window)
	menu.add_entry("skills", "", "Kỹ năng (phím G)", _open_skill_book)
	## Nút Cài đặt: góc trên phải, sát bên trái mini map. Nút "Thoát về Character Hub" nằm trong khung Cài đặt.
	var exit_button := SideMenu.make_button("", "⚙", "Cài đặt: nhạc nền, zoom camera, thoát", func() -> void:
		SettingsWindow.open(self, _on_exit_button_pressed))
	exit_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var right := MiniMap.SCREEN_MARGIN + MiniMap.BASE_SIZE.x * MiniMap.UI_SCALE + 6.0
	exit_button.offset_right = -right
	exit_button.offset_left = -right - SideMenu.SLOT
	exit_button.offset_top = MiniMap.SCREEN_MARGIN
	exit_button.offset_bottom = MiniMap.SCREEN_MARGIN + SideMenu.SLOT
	exit_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	$UI.add_child(exit_button)
	## 3 nút Nhân vật / Hành trang / Kỹ năng: hàng ngang sát bên trái nút Cài đặt.
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_right = exit_button.offset_left - SideMenu.GAP
	menu.offset_left = menu.offset_right - (3 * SideMenu.SLOT + 2 * SideMenu.GAP)
	menu.offset_top = exit_button.offset_top
	menu.offset_bottom = exit_button.offset_bottom
	menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu.alignment = BoxContainer.ALIGNMENT_END
	$UI.add_child(menu)

## Nút công cụ thử (chỉ bản debug) — xếp thành hàng nhỏ ở góc trên trái.
var _debug_x := 8.0

func _build_debug_button(text: String, tip: String, on_press: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.offset_left = _debug_x
	button.offset_top = 4
	button.offset_right = _debug_x + 72
	button.offset_bottom = 34
	button.pressed.connect(on_press)
	$UI.add_child(button)
	_debug_x += 80.0

func _open_test_window() -> void:
	if GameManager.local_profile == null:
		return
	var win := TestWindow.open(self, GameManager.local_profile)
	if not win.profile_changed.is_connected(_on_panel_profile_changed):
		win.profile_changed.connect(_on_panel_profile_changed)

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

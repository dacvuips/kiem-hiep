extends Node2D

@export var stage_for_testing: StageData

var elapsed_time: float = 0.0

@onready var time_label: Label = $UI/TimeLabel
@onready var skill_bar_ui: SkillBarUI = $UI/SkillBarUI
@onready var joystick: MoveJoystick = $UI/VirtualJoystick
@onready var status_hud: PlayerStatusHud = $UI/PlayerStatusHud

const HUB_SCENE_PATH := "res://ui/character_hub/CharacterHub.tscn"

var _skill_book_open: bool = false
var _skill_book_screen: SkillBookScreen
## Map hiện tại có cho hiện joystick không (StageData.show_move_joystick) — để khôi phục đúng trạng
## thái sau khi đóng bảng skill (lúc mở bảng luôn ẩn joystick).
var _joystick_enabled: bool = true
var _exit_confirm: PanelContainer
## Khung Nhân vật / Hành trang mở trong trận (null = đang đóng).
## Riêng ở ải "Khiêu Chiến Sơn Môn" (StageData), mở bất kỳ khung nào (Nhân vật, Hành trang, Kỹ năng) đều tạm dừng trận.
var _status_window: CharacterStatusWindow
var _inventory_window: InventoryPopup

## Map VLTK dùng để lấy nhạc nền khi StageData không khai báo vltk_map_id — tạm, thay bằng map thật của màn.
const DEFAULT_MUSIC_MAP_ID := 1

func _play_stage_music(stage: StageData) -> void:
	var map_id := stage.vltk_map_id if stage.vltk_map_id > 0 else DEFAULT_MUSIC_MAP_ID
	MusicManager.play_map(map_id)

func _exit_tree() -> void:
	MusicManager.stop()
	PlayerStats.reset()
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = false

func _ready() -> void:
	for arg in OS.get_cmdline_args():
		if arg == "--test-arena":
			var p := PlayerProfile.new()
			p.display_name = "DaiHiep"
			p.level = 95
			p.sect_id = "cai_bang"
			GameManager.local_profile = p
			var bot := PkBotProfile.create(95, "cai_bang")
			GameManager.field_map = PkRules.arena_entry({"mode": PkRules.Mode.DAI_HOI, "opponent": bot.to_dict()})
			GameManager.game_mode = GameManager.GameMode.MAIN_MAP
			_test_arena_and_quit.call_deferred()
			break
		elif arg == "--test-badge":
			_test_badge_and_quit.call_deferred()
			break

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

	$UI.add_child(AgeRatingBadge.new())
	add_child(SocialTicker.new())   ## nhịp nền xã hội: khách mua hàng bày bán, người xin vào đội/bang
	_sect_prompt = SectPrompt.new()   ## Vô Môn Phái đủ cấp 10 thì hỏi gia nhập môn phái
	add_child(_sect_prompt)
	if AccountApi.is_gm():   ## công cụ thử (chỉ admin GM): hàng nút nhỏ góc trên trái
		_build_debug_button("Quái", "Danh sách quái VLTK — tạo quái để thử", _toggle_monster_popup)
		_build_debug_button("Skill", "Bảng tất cả skill theo phái — thi triển thử", _toggle_skill_popup)
		_build_debug_button("TEST", "Thử nhân vật: lên cấp, đồ, tiền, cộng chỉ số", _open_test_window)

## Chế độ "Chơi": đi lại tự do trên toàn map chính. Không ô vuông giới hạn, không sinh quái / vật phẩm kiểu sinh tồn, không đếm giờ ải.
## Vẫn giữ nguyên: skill + thanh skill, trang bị, cộng chỉ số, di chuyển, ngựa, mini map.
func _enter_main_map() -> void:
	PlayerStats.reset()
	GameManager.current_stage = null
	joystick.visible = true
	_joystick_enabled = true
	time_label.visible = false
	$Spawner.set_process(false)
	$PickupSpawner.set_process(false)
	## Map luyện công / Địa Ngục (màn "Vượt Ải"): chưa đăng nhập -> chơi offline, quái do client sinh; đã đăng nhập -> phòng train
	## chung trên field server (field_map.field).
	var field := GameManager.field_map
	## Chiến trường Tống Kim (tab Ải): luôn online, nối tới battle server riêng ({side, server}).
	var battle: Dictionary = field.get("battle", {})
	## Đấu trường PK online (popup PK lúc đã đăng nhập): nối tới arena server riêng ({mode, online, server, action}).
	var pk: Dictionary = field.get("pk", {})
	var pk_online := bool(pk.get("online", false))
	## Phòng train chung (map luyện công / Địa Ngục lúc đã đăng nhập): nối tới field server ({server, action}) — FieldClient.
	var room: Dictionary = field.get("field", {})
	var online := (NetWorldSync.is_online_mode() and field.is_empty()) or not battle.is_empty() or pk_online or not room.is_empty()
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
	## Ải Thuyền Phong Lăng Độ (tab "Ải" của màn Vượt Ải): map 336, diệt Thủy tặc & Boss Yên Hiểu Trái.
	elif field.get("phong_lang_do", false):
		var pld := PhongLangDoChallenge.new()
		pld.name = "PhongLangDoChallenge"
		add_child(pld)
	## Ải Tống Kim LOL (MOBA 1vs1 - 5vs5 trên map 378)
	if field.get("tong_kim_lol", false) or int(field.get("pk", {}).get("mode", -1)) == PkRules.Mode.TONG_KIM_LOL:
		var lol_match := TongKimLolMatch.new()
		lol_match.name = "TongKimLolMatch"
		add_child(lol_match)
	## Trận PK Lộn Xộn (Loạn đả 16 người hoặc Đấu đội)
	elif int(field.get("pk", {}).get("mode", -1)) == PkRules.Mode.LON_XON or field.get("brawl", false):
		var brawl_script: GDScript = load("res://systems/pk/pk_brawl_match.gd")
		var brawl_match = brawl_script.new()
		brawl_match.name = "PkBrawlMatch"
		add_child(brawl_match)
	## Trận PK với bot (nút PK ở Character Hub, offline / không tìm được người): đấu trường map 397.
	elif field.has("pk") and not pk_online:
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
		sync.server_override = pk.get("server", {}) if pk_online else room.get("server", {}) if not room.is_empty() else battle.get("server", {})
		add_child(sync)
	else:
		ChatBox.attach($UI)   ## offline vẫn có ô chat Gần (online: NetWorldSync tự thêm)
	if not battle.is_empty():
		add_child(BattleClient.create(str(battle["side"]), int(field["id"])))
	if pk_online:
		add_child(ArenaClient.create(pk))
	if not room.is_empty():
		add_child(FieldClient.create(room))
	elif field.get("guild_map", false) and not online:
		_spawn_offline_guild_members.call_deferred()

func _spawn_offline_guild_members() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player") as Node2D
	var base_pos: Vector2 = player.global_position if player != null else Vector2.ZERO
	var profile := GameManager.local_profile
	if profile == null:
		return
	var hub := SocialHub.of(profile)
	var members: Array = hub.guild.members()
	var offsets: Array[Vector2] = [
		Vector2(120, -60), Vector2(-130, -50), Vector2(100, 80),
		Vector2(-110, 90), Vector2(180, 20), Vector2(-190, 30),
		Vector2(60, 140), Vector2(-70, 150)
	]
	var i := 0
	for m in members:
		if bool(m.get("local", false)):
			continue
		var rp := RemotePlayer.new()
		var p_pos: Vector2 = base_pos + (offsets[i % offsets.size()] if i < offsets.size() else Vector2(randf_range(-200, 200), randf_range(-150, 150)))
		var info := {
			"eid": int(m.get("mock_id", 1000 + i)),
			"name": str(m.get("name", "Thành Viên")),
			"level": int(m.get("level", 50)),
			"camp": int(profile.camp),
			"look": {"gender": 0, "helm": 0, "armor": 1, "weapon": 1, "horse": 0},
			"pos": p_pos,
			"flags": NetProto.FLAG_TRADE_OPEN,
			"dir": randi() % 8,
			"action": 0,
			"z": 0,
			"hp": 100
		}
		var parent := VltkWorld.entity_parent() if VltkWorld.current != null else self
		parent.add_child(rp)
		rp.setup(info)
		i += 1
		if i >= 8:
			break

func load_stage(stage: StageData) -> void:
	PlayerStats.reset()
	GameManager.start_stage(stage)
	_joystick_enabled = stage.show_move_joystick
	joystick.visible = _joystick_enabled

	## Map chính (World = VltkWorld) dùng chung mọi màn; màn chỉ là 1 ô vuông trên đó (StageData.arena_*).
	if VltkWorld.current != null:
		if stage.vltk_map_id > 0:
			var target_dir := "res://world/maps/map_%d" % stage.vltk_map_id
			if DirAccess.dir_exists_absolute(target_dir):
				VltkWorld.current.map_dir = target_dir
		VltkWorld.current.setup_stage(stage)

func _process(delta: float) -> void:
	if get_tree().paused or GameManager.is_game_over or (has_node("Spawner") and $Spawner.stage_cleared):
		return
	var p := GameManager.local_profile
	var cur_trade_open: bool = p != null and p.trade_open
	if cur_trade_open != _last_trade_open:
		_last_trade_open = cur_trade_open
		_refresh_trade_button()
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
		if GameManager.local_profile != null:
			GameManager.local_profile.level_up()
			SaveManager.save_profile(GameManager.local_profile)
			SaveManager.flush_online()
			print("F9: Lên cấp nhân vật -> Cấp %d" % GameManager.local_profile.level)
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
## GemSocketScreen cũ, đã gỡ bỏ cùng gem_system) — pause game trong lúc xem/học skill khi ở chế độ ải.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_gem_menu"):
		_toggle_skill_book()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		_toggle_trade_mode()

var _sect_prompt: SectPrompt

func _is_stage_mode() -> bool:
	return GameManager.current_stage != null or GameManager.game_mode == GameManager.GameMode.STAGE

func is_any_menu_window_open() -> bool:
	if _skill_book_open or is_instance_valid(_skill_book_screen):
		return true
	if is_instance_valid(_status_window) and not _status_window.is_queued_for_deletion():
		return true
	if is_instance_valid(_inventory_window) and not _inventory_window.is_queued_for_deletion():
		return true
	return false

func _update_stage_pause() -> void:
	if not _is_stage_mode():
		return
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _exit_confirm != null:
		tree.paused = true
		return
	tree.paused = is_any_menu_window_open()

func _toggle_skill_book() -> void:
	if is_instance_valid(_skill_book_screen):
		_skill_book_screen._on_close_pressed()
		return
	_open_skill_book()

## Mở bảng Kỹ Năng — phím G (action open_gem_menu) hoặc nút "Kỹ năng" ở thanh trên.
func _open_skill_book() -> void:
	if _skill_book_open or is_instance_valid(_skill_book_screen):
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
	_update_stage_pause()
	_skill_book_screen = SkillBookScreen.open(self, GameManager.local_profile, sect.skills, func() -> void:
		_skill_book_open = false
		_skill_book_screen = null
		_update_stage_pause()
		skill_bar_ui.refresh_sub_skills()
		## Skill nội tại vừa học trong bảng cộng bonus vào combat_stats — áp dụng ngay, không đợi trận sau.
		if is_instance_valid(player):
			player.refresh_combat_stats()
	)

# ------------------------------------------------- khung Nhân vật / Hành trang trong trận

## 2 khung độc lập, kéo di chuyển được, mở cùng lúc được. Bấm lại nút để đóng.
## Riêng ở ải "Khiêu Chiến Sơn Môn", mở bất kỳ khung nào (Kỹ năng, Hành trang, Trang bị) đều tạm dừng game lại.
## Ở map dã ngoại / train chung, trận vẫn chạy tự do bình thường.
func _toggle_status_window() -> void:
	if is_instance_valid(_status_window):
		var win := _status_window
		_status_window = null
		win.queue_free()
		_update_stage_pause()
		return
	if GameManager.local_profile == null:
		return
	_status_window = CharacterStatusWindow.open(self, GameManager.local_profile, _toggle_inventory_window)
	_status_window.screen.profile_changed.connect(_on_panel_profile_changed)
	_status_window.tree_exited.connect(func() -> void:
		if _status_window == null or _status_window.is_queued_for_deletion():
			_status_window = null
			_update_stage_pause()
	)
	_update_stage_pause()

func _toggle_inventory_window() -> void:
	if not is_instance_valid(_inventory_window):
		_inventory_window = InventoryPopup.find_open(get_tree())   ## có thể đang mở kèm Rương chứa đồ
	if is_instance_valid(_inventory_window):
		var win := _inventory_window
		_inventory_window = null
		win.queue_free()
		_update_stage_pause()
		return
	if GameManager.local_profile == null:
		return
	_inventory_window = InventoryPopup.open(self, GameManager.local_profile, _on_panel_profile_changed, false)
	_inventory_window.tree_exited.connect(func() -> void:
		if _inventory_window == null or _inventory_window.is_queued_for_deletion():
			_inventory_window = null
			_update_stage_pause()
	)
	_update_stage_pause()

## Mặc/tháo đồ, cộng điểm: vẽ lại khung Nhân vật + áp chỉ số mới lên nhân vật ngay.
func _on_panel_profile_changed() -> void:
	if is_instance_valid(_status_window):
		_status_window.screen.refresh()
	var tree := get_tree()
	if tree != null:
		var player := tree.get_first_node_in_group("player")
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

var _trade_button: Button
var _last_trade_open: bool = false

## Cột nút tiện ích bên trái (kiểu VLTK mobile) — SideMenu (hàng ngang góc trên phải): Nhân vật, Hành trang, Kỹ năng, Giao dịch, sát bên trái nút Cài đặt (có Thoát) cạnh mini map.
func _build_side_menu() -> void:
	var menu := SideMenu.new()
	menu.name = "SideMenu"
	menu.add_entry("status", "", "Nhân vật", _toggle_status_window)
	menu.add_entry("items", "", "Hành trang", _toggle_inventory_window)
	menu.add_entry("skills", "", "Kỹ năng (phím G)", _toggle_skill_book)
	_trade_button = menu.add_entry("exchange", "🤝", "Bật giao dịch (phím F4)", _toggle_trade_mode)
	_refresh_trade_button()
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
	## Các nút tiện ích: hàng ngang sát bên trái nút Cài đặt.
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_right = exit_button.offset_left - SideMenu.GAP
	var count := menu.get_child_count()
	menu.offset_left = menu.offset_right - (count * SideMenu.SLOT + (count - 1) * SideMenu.GAP)
	menu.offset_top = exit_button.offset_top
	menu.offset_bottom = exit_button.offset_bottom
	menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu.alignment = BoxContainer.ALIGNMENT_END
	$UI.add_child(menu)

func _toggle_trade_mode() -> void:
	var p := GameManager.local_profile
	if p == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player) and player.get("selected_target") is RemotePlayer:
		var target: RemotePlayer = player.get("selected_target")
		if target != null and is_instance_valid(target):
			_request_direct_trade(target)
			return

	if p.trade_open:
		StallService.close_trade(p)
		if NetClient.is_in_world():
			NetClient.send_stall(SocialServer.TRADE_CLOSE)
		SaveManager.save_profile(p)
		_notify_player("Đã tắt mở giao dịch.")
	else:
		var err := StallService.open_trade(p)
		if err != "":
			_notify_player(err)
			return
		if NetClient.is_in_world():
			NetClient.send_stall(SocialServer.TRADE_OPEN)
		SaveManager.save_profile(p)
		_notify_player("Đã bật mở giao dịch — người chơi khác có thể giao dịch trực tiếp với bạn.")
	_refresh_trade_button()

func _request_direct_trade(target: RemotePlayer) -> void:
	var p := GameManager.local_profile
	if p == null or target == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var dist := player.global_position.distance_to(target.global_position)
	if dist > SocialServer.TRADE_RANGE:
		_notify_player("Đứng gần hơn mới giao dịch được.")
		return

	if not p.trade_open and not p.stall_open:
		var err := StallService.open_trade(p)
		if err == "":
			if NetClient.is_in_world():
				NetClient.send_stall(SocialServer.TRADE_OPEN)
			SaveManager.save_profile(p)
			_refresh_trade_button()

	var target_open: bool = (target.flags & NetProto.FLAG_TRADE_OPEN) != 0 or GameManager.field_map.get("guild_map", false)
	if not target_open:
		_notify_player("%s chưa bật mở giao dịch." % target.display_name)
		return

	var hub := SocialHub.of(p)
	if NetClient.is_in_world():
		NetClient.send_trade_request(target.eid)
		_notify_player("Đã gửi lời mời giao dịch tới %s." % target.display_name)
	else:
		var m := SocialDirectory.find_by_id(p, target.eid)
		if m != null:
			var err := hub.start_trade(m)
			if err == "":
				TradeWindow.open(self, hub)
			elif err != "online":
				_notify_player(err)

func _notify_player(text: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.has_method("notify"):
		player.notify(text)
	else:
		print("[Giao dịch] ", text)

func _refresh_trade_button() -> void:
	if _trade_button == null or not is_instance_valid(_trade_button):
		return
	var p := GameManager.local_profile
	var is_open: bool = p != null and p.trade_open
	SideMenu.set_active(_trade_button, is_open)
	if is_open:
		_trade_button.tooltip_text = "Đang mở giao dịch (F4)\nNgười chơi khác có thể giao dịch trực tiếp với bạn.\n(Bấm để tắt mở giao dịch)"
	else:
		_trade_button.tooltip_text = "Bật giao dịch (F4)\nBật mở giao dịch để người chơi khác có thể giao dịch trực tiếp với bạn.\n(Chọn người chơi rồi bấm để xin giao dịch)"

## Nút công cụ thử (chỉ bản debug) — xếp thành hàng nhỏ ở góc trên trái; trong phòng train chung thì nằm dưới khung ID phòng.
var _debug_x := 70.0

func _build_debug_button(text: String, tip: String, on_press: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	var top := 4.0 + (FieldClient.HUD_HEIGHT if GameManager.field_map.has("field") else 0.0)
	button.offset_left = _debug_x
	button.offset_top = top
	button.offset_right = _debug_x + 72
	button.offset_bottom = top + 30
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
	if AccountApi.is_gm():
		message.text = "Bạn có chắc muốn thoát trận?\n(GM) Toàn bộ tiến trình sẽ được lưu lại."
	else:
		message.text = "Bạn có chắc muốn thoát trận?\nTiến trình trận sẽ không được lưu — nhân vật trở về trạng thái trước khi vào."
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
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = false
	if GameManager.local_profile != null:
		if AccountApi.is_gm():
			## GM: lưu toàn bộ tiến trình khi thoát trận
			SaveManager.save_profile(GameManager.local_profile)
		else:
			## Người thường: KHÔNG lưu bản thoát giữa trận — khôi phục về trạng thái trước trận
			SaveManager.restore_profile_from_save()
		await SaveManager.flush_online()
	if tree != null:
		tree.change_scene_to_file(HUB_SCENE_PATH)

func _on_exit_cancelled(overlay: CanvasLayer) -> void:
	overlay.queue_free()
	_exit_confirm = null
	if _is_stage_mode():
		_update_stage_pause()
	else:
		var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.paused = false

func _test_badge_and_quit() -> void:
	await get_tree().create_timer(1.2).timeout
	var badge = $UI.get_node_or_null("AgeRatingBadge")
	print("TEST_BADGE_NODE: ", badge)
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/27fde8f4-05c5-4d1f-b02c-10dfdae0fe5e/gameplay_18plus_live.png")
		print("BADGE_SCREENSHOT_SAVED")
	get_tree().quit(0)

func _test_arena_and_quit() -> void:
	await get_tree().create_timer(1.2).timeout
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var bot: Node2D = find_child("PkBot", true, false) as Node2D
	print("TEST_ARENA_CHECK:")
	if player:
		print("Player global_position = ", player.global_position, " | Dist to ARENA_CENTER = ", player.global_position.distance_to(PkRules.ARENA_CENTER))
	if bot:
		print("Bot global_position = ", bot.global_position, " | Dist to ARENA_CENTER = ", bot.global_position.distance_to(PkRules.ARENA_CENTER))
	if player and bot:
		print("Distance between Player and Bot = ", player.global_position.distance_to(bot.global_position))
	await get_tree().create_timer(0.4).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/d6888eb9-bf62-47ed-a3a2-f742759dfa21/arena_in_action.png")
		print("ARENA_SCREENSHOT_SAVED")
	get_tree().quit()

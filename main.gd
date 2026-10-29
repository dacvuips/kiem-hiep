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

var _ky_tran_cac_window: KyTranCacWindow

## Map VLTK dùng để lấy nhạc nền khi StageData không khai báo vltk_map_id — tạm, thay bằng map thật của màn.

const DEFAULT_MUSIC_MAP_ID := 1

const PkRoomBadge = preload("res://ui/hud/pk_room_badge.gd")

func _play_stage_music(stage: StageData) -> void:

	var map_id := stage.vltk_map_id if stage.vltk_map_id > 0 else DEFAULT_MUSIC_MAP_ID

	MusicManager.play_map(map_id)

func _exit_tree() -> void:

	HudLayout.remove_listener(_apply_hud_layout)

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

	$UI.add_child(QuickItemBar.new())

	HudLayout.add_listener(_apply_hud_layout)

	_apply_hud_layout()   ## 4 ô thuốc nhanh ngay trên cụm nút skill

	if LocalizationManager != null:
		LocalizationManager.locale_changed.connect(func(_loc: String) -> void:
			_refresh_pk_ui()
		)

	$UI.add_child(AgeRatingBadge.new())

	add_child(SocialTicker.new())   ## nhịp nền xã hội: khách mua hàng bày bán, người xin vào đội/bang

	_sect_prompt = SectPrompt.new()   ## Vô Môn Phái đủ cấp 10 thì hỏi gia nhập môn phái

	add_child(_sect_prompt)

	if AccountApi.is_gm():   ## công cụ thử (chỉ admin GM): hàng nút nhỏ góc trên trái

		_build_debug_button("★ GM ★", "Trung tâm điều hành Game Master (Phím F12)", _open_gm_window, true)

		_build_debug_button("Quái", "Danh sách quái VLTK — tạo quái để thử", _toggle_monster_popup)

		_build_debug_button("Skill", "Bảng tất cả skill theo phái — thi triển thử", _toggle_skill_popup)

		_build_debug_button("TEST", "Thử nhân vật: lên cấp, đồ, tiền, cộng chỉ số", _open_test_window)

		GmManager.profile_modified.connect(func(target_profile: PlayerProfile) -> void:
			if target_profile == null or target_profile == GameManager.local_profile:
				_on_panel_profile_changed()
				if is_instance_valid(_inventory_window) and _inventory_window.has_method("refresh"):
					_inventory_window.refresh()
		)

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

	## Ải Hộ Tống Tiêu Xa (Long Môn Tiêu Cục): map 53 Ba Lăng Huyện

	elif field.get("escort_field", false):

		var escort := EscortChallenge.new()

		escort.name = "EscortChallenge"

		add_child(escort)

	## Ải Viêm Đế Bảo Tàng (Thực địa Map 853 Kho Báu Viêm Đế):

	elif field.get("viem_de_challenge", false):

		var ydbz_script: GDScript = load("res://systems/challenge/viem_de_challenge.gd")

		var ydbz = ydbz_script.new()

		ydbz.name = "ViemDeChallenge"

		add_child(ydbz)

	## Ải Bảo Vệ Trụ Danh Dự (Công Thành Chiến Lâm An map 1001)

	elif field.get("honor_defense", false):

		var honor_script: GDScript = load("res://systems/challenge/honor_defense_challenge.gd")

		if honor_script != null:

			var defense = honor_script.new()

			defense.name = "HonorDefenseChallenge"

			add_child(defense)

	## Ải Tống Kim LOL (MOBA 1vs1 - 5vs5 trên map 378)

	if field.get("tong_kim_lol", false) or int(field.get("pk", {}).get("mode", -1)) == PkRules.Mode.TONG_KIM_LOL:

		var lol_match := TongKimLolMatch.new()

		lol_match.name = "TongKimLolMatch"

		add_child(lol_match)

	## Trận PK Lộn Xộn (Loạn đả 16 người hoặc Đấu đội - chỉ cho Offline khi có bot)

	elif (int(field.get("pk", {}).get("mode", -1)) == PkRules.Mode.LON_XON or field.get("brawl", false)) and not pk_online:

		if GameModeManager.allows_bot():

			var brawl_script: GDScript = load("res://systems/pk/pk_brawl_match.gd")

			var brawl_match = brawl_script.new()

			brawl_match.name = "PkBrawlMatch"

			add_child(brawl_match)

	## Trận PK với bot (nút PK ở Character Hub, offline / không tìm được người): đấu trường map 397.

	elif field.has("pk") and not pk_online:

		if GameModeManager.allows_bot():

			var match_node := PkMatch.new()

			match_node.name = "PkMatch"

			add_child(match_node)

	var is_pk: bool = field.has("pk") or field.get("brawl", false) or field.get("tong_kim_lol", false)

	if is_pk:

		var room_id: String = str(field.get("pk", {}).get("room_id", field.get("room", {}).get("id", "")))

		if room_id.is_empty() and not pk_online:

			room_id = str(randi_range(100000, 999999))

			if field.has("pk"):

				field["pk"]["room_id"] = room_id

		var m_val: int = int(field.get("pk", {}).get("mode", -1))

		if m_val < 0 and field.get("tong_kim_lol", false):

			m_val = PkRules.Mode.TONG_KIM_LOL

		elif m_val < 0 and field.get("brawl", false):

			m_val = PkRules.Mode.LON_XON

		PkRoomBadge.attach($UI, room_id, m_val)

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

	elif field.get("guild_map", false) and not online and GameModeManager.allows_bot():

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

	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode == KEY_F9:

			_toggle_pk_menu(_pk_button if is_instance_valid(_pk_button) else _pk_hud_btn)

			get_viewport().set_input_as_handled()

			return

		elif event.keycode == KEY_P:

			_toggle_team_window()

			get_viewport().set_input_as_handled()

			return

		elif event.keycode == KEY_F4:

			_toggle_trade_mode()

			get_viewport().set_input_as_handled()

			return

		elif event.keycode == KEY_M or event.keycode == KEY_TAB:

			_toggle_map_panel()

			get_viewport().set_input_as_handled()

			return

		elif event.keycode == KEY_F11:

			_toggle_ky_tran_cac()

			get_viewport().set_input_as_handled()

			return

		elif event.keycode == KEY_F12:

			if AccountApi.is_gm():

				_open_gm_window()

				get_viewport().set_input_as_handled()

				return

	if event.is_action_pressed("open_gem_menu"):

		_toggle_skill_book()

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

func _toggle_ky_tran_cac() -> void:

	if is_instance_valid(_ky_tran_cac_window):

		var win := _ky_tran_cac_window

		_ky_tran_cac_window = null

		win.queue_free()

		return

	if GameManager.local_profile == null:

		return

	_ky_tran_cac_window = KyTranCacWindow.open(self, _on_panel_profile_changed, GameManager.local_profile)

	_ky_tran_cac_window.tree_exited.connect(func() -> void:

		if _ky_tran_cac_window == null or _ky_tran_cac_window.is_queued_for_deletion():

			_ky_tran_cac_window = null

	)

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

var _team_button: Button

var _team_window: Control = null

var _pk_button: Button

var _pk_hud_btn: Button

var _pk_mode: int = 0

var _bottom_action_bar: HBoxContainer

## Cột nút tiện ích bên phải — SideMenu (hàng ngang góc trên phải): Nhân vật, Hành trang, Kỹ năng, Cài đặt.

func _build_side_menu() -> void:

	var menu := SideMenu.new()

	menu.name = "SideMenu"

	menu.add_entry("status", "", "Nhân vật", _toggle_status_window)

	menu.add_entry("items", "", "Hành trang", _toggle_inventory_window)

	menu.add_entry("skills", "", "Kỹ năng (phím G)", _toggle_skill_book)

	menu.add_entry("itemex", "Kỳ", "Kỳ Trân Các (phím F11)", _toggle_ky_tran_cac)

	_build_pk_hud()

	## Nút Cài đặt: góc trên phải, sát bên trái mini map. Nút "Thoát về Character Hub" nằm trong khung Cài đặt.

	var exit_button := SideMenu.make_button("", "⚙", "Cài đặt: nhạc nền, zoom camera, thoát", func() -> void:

		SettingsWindow.open(self, _on_exit_button_pressed))

	exit_button.name = "ExitButton"

	exit_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)

	var right := MiniMap.SCREEN_MARGIN + MiniMap.BASE_SIZE.x * MiniMap.UI_SCALE + 6.0

	exit_button.offset_right = -right

	exit_button.offset_left = -right - SideMenu.SLOT

	exit_button.offset_top = MiniMap.SCREEN_MARGIN

	exit_button.offset_bottom = MiniMap.SCREEN_MARGIN + SideMenu.SLOT

	exit_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	$UI.add_child(exit_button)

	## Các nút tiện ích: hàng ngang nằm ngay dưới nút Cài đặt, thẳng hàng bên trái mini map, không chèn lên TopStatusBar.

	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)

	menu.offset_right = -right

	var count := menu.get_child_count()

	menu.offset_left = menu.offset_right - (count * SideMenu.SLOT + (count - 1) * SideMenu.GAP)

	menu.offset_top = exit_button.offset_bottom + 4.0

	menu.offset_bottom = menu.offset_top + SideMenu.SLOT

	menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	menu.alignment = BoxContainer.ALIGNMENT_END

	$UI.add_child(menu)

	_build_bottom_action_bar()

## Cụm nút thao tác (Tổ đội, Chiến đấu/PK, Giao dịch) đặt cạnh nút Ngồi ở góc dưới màn hình

func _build_bottom_action_bar() -> void:

	if _bottom_action_bar and is_instance_valid(_bottom_action_bar):

		return

	_bottom_action_bar = HBoxContainer.new()

	_bottom_action_bar.name = "BottomActionBar"

	_bottom_action_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)

	_bottom_action_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_bottom_action_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_bottom_action_bar.add_theme_constant_override("separation", 6)

	_bottom_action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_team_button = SideMenu.make_button("party", "👥", "Tổ Đội (phím P)", _toggle_team_window)

	_pk_button = SideMenu.make_button("pk", "", "Chế độ PK (phím F9): Chọn Luyện Công / Chiến Đấu / Đồ Sát", func() -> void: _toggle_pk_menu(_pk_button))

	_trade_button = SideMenu.make_button("exchange", "🤝", "Bật giao dịch (phím F4)", _toggle_trade_mode)

	_bottom_action_bar.add_child(_team_button)

	_bottom_action_bar.add_child(_pk_button)

	_bottom_action_bar.add_child(_trade_button)

	_refresh_trade_button()

	_refresh_pk_ui()

	# Căn sát bên trái nút Ngồi (SitButton offset_left = -409, height 52)

	_bottom_action_bar.offset_right = -415.0

	_bottom_action_bar.offset_left = -415.0 - (3 * SideMenu.SLOT + 2 * 6)

	_bottom_action_bar.offset_top = -58.0

	_bottom_action_bar.offset_bottom = -14.0

	$UI.add_child(_bottom_action_bar)

func _apply_hud_layout() -> void:

	if not is_inside_tree() or not has_node("UI"):

		return

	var mm_data: Dictionary = HudLayout.get_element("minimap")

	var mm_scale: float = float(mm_data.get("scale", 1.0))

	var mm_ox: float = float(mm_data.get("offset_x", 0.0))

	var mm_oy: float = float(mm_data.get("offset_y", 0.0))

	var right_base: float = MiniMap.SCREEN_MARGIN + MiniMap.BASE_SIZE.x * MiniMap.UI_SCALE * mm_scale + 6.0 - mm_ox

	# Exit button (Cài đặt)

	var exit_btn := $UI.get_node_or_null("ExitButton") as Button

	if exit_btn != null:

		var exit_data: Dictionary = HudLayout.get_element("exit_button")

		var exit_ox: float = float(exit_data.get("offset_x", 0.0))

		var exit_oy: float = float(exit_data.get("offset_y", 0.0))

		var exit_scale: float = float(exit_data.get("scale", 1.0))

		var right: float = right_base - exit_ox

		exit_btn.offset_right = -right

		exit_btn.offset_left = -right - SideMenu.SLOT * exit_scale

		exit_btn.offset_top = MiniMap.SCREEN_MARGIN + mm_oy + exit_oy

		exit_btn.offset_bottom = MiniMap.SCREEN_MARGIN + SideMenu.SLOT * exit_scale + mm_oy + exit_oy

		exit_btn.scale = Vector2.ONE * exit_scale

	# SideMenu (Hàng nút túi đồ / nhân vật...)

	var side_menu := $UI.get_node_or_null("SideMenu") as SideMenu

	if side_menu != null:

		var side_data: Dictionary = HudLayout.get_element("side_menu")

		var side_ox: float = float(side_data.get("offset_x", 0.0))

		var side_oy: float = float(side_data.get("offset_y", 0.0))

		var side_scale: float = float(side_data.get("scale", 1.0))

		var count: int = side_menu.get_child_count()

		var right: float = right_base - side_ox

		side_menu.offset_right = -right

		side_menu.offset_left = side_menu.offset_right - (count * SideMenu.SLOT + (count - 1) * SideMenu.GAP) * side_scale

		var top_base: float = MiniMap.SCREEN_MARGIN + SideMenu.SLOT + 4.0

		side_menu.offset_top = top_base + mm_oy + side_oy

		side_menu.offset_bottom = side_menu.offset_top + SideMenu.SLOT * side_scale

		side_menu.scale = Vector2.ONE * side_scale

	# BottomActionBar (Tổ đội, PK, Giao dịch)

	if _bottom_action_bar != null and is_instance_valid(_bottom_action_bar):

		var bar_data: Dictionary = HudLayout.get_element("bottom_bar")

		var bar_ox: float = float(bar_data.get("offset_x", 0.0))

		var bar_oy: float = float(bar_data.get("offset_y", 0.0))

		var bar_scale: float = float(bar_data.get("scale", 1.0))

		_bottom_action_bar.offset_right = -415.0 + bar_ox

		_bottom_action_bar.offset_left = -415.0 - (3 * SideMenu.SLOT + 2 * 6) * bar_scale + bar_ox

		_bottom_action_bar.offset_top = -58.0 + bar_oy

		_bottom_action_bar.offset_bottom = -14.0 + bar_oy

		_bottom_action_bar.scale = Vector2.ONE * bar_scale

	# Joystick

	if joystick != null and is_instance_valid(joystick):

		var joy_data: Dictionary = HudLayout.get_element("joystick")

		var joy_ox: float = float(joy_data.get("offset_x", 0.0))

		var joy_oy: float = float(joy_data.get("offset_y", 0.0))

		var joy_scale: float = float(joy_data.get("scale", 1.0))

		joystick.offset_left = joy_ox

		joystick.offset_right = 440.0 * joy_scale + joy_ox

		joystick.offset_top = -380.0 * joy_scale + joy_oy

		joystick.offset_bottom = joy_oy

		joystick.scale = Vector2.ONE * joy_scale

	# Nút trạng thái PK (Luyện Công / Chiến Đấu)
	if _top_left_bar != null and is_instance_valid(_top_left_bar):
		var pk_data: Dictionary = HudLayout.get_element("pk_mode")
		var pk_ox: float = float(pk_data.get("offset_x", 0.0))
		var pk_oy: float = float(pk_data.get("offset_y", 0.0))
		var pk_scale: float = float(pk_data.get("scale", 1.0))
		_top_left_bar.offset_left = 12.0 + pk_ox
		_top_left_bar.offset_top = 72.0 + pk_oy
		_top_left_bar.offset_bottom = 104.0 + pk_oy
		_top_left_bar.scale = Vector2.ONE * pk_scale

func _toggle_trade_mode() -> void:

	var p := GameManager.local_profile

	if p == null:

		return

	var player := get_tree().get_first_node_in_group("player") as Node2D

	if player != null and is_instance_valid(player):

		var target_node: Variant = player.get_selected_target() if player.has_method("get_selected_target") else player.get("selected_target")

		if is_instance_valid(target_node) and target_node is RemotePlayer:

			_request_direct_trade(target_node as RemotePlayer)

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

	if p == null or not is_instance_valid(target):

		return

	var player := get_tree().get_first_node_in_group("player") as Node2D

	if player == null or not is_instance_valid(player):

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

		if NetWorldSync.is_online_mode():
			_notify_player("Chưa kết nối máy chủ game.")
			return

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

func _toggle_team_window() -> void:

	if is_instance_valid(_team_window):

		_team_window.queue_free()

		_team_window = null

		return

	var p := GameManager.local_profile

	if p:

		_team_window = TeamWindow.open(self, SocialHub.of(p))

func _toggle_map_panel() -> void:

	var existing := get_tree().root.get_node_or_null("MapPanel")

	if existing != null:

		existing.queue_free()

		return

	var minimap_node: MiniMap = $UI.get_node_or_null("MiniMap")

	var player := get_tree().get_first_node_in_group("player") as Node2D

	if minimap_node != null and player != null:

		var panel := MapPanel.new()

		panel.name = "MapPanel"

		get_tree().root.add_child(panel)

		panel.setup(minimap_node, player)

var _top_left_bar: HBoxContainer

func _ensure_top_left_bar() -> HBoxContainer:

	if _top_left_bar != null and is_instance_valid(_top_left_bar):

		return _top_left_bar

	_top_left_bar = HBoxContainer.new()

	_top_left_bar.name = "TopLeftActionBar"

	_top_left_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)

	_top_left_bar.offset_left = 12.0

	_top_left_bar.offset_top = 72.0

	_top_left_bar.offset_bottom = 104.0

	_top_left_bar.add_theme_constant_override("separation", 6)

	_top_left_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	$UI.add_child(_top_left_bar)

	return _top_left_bar

func _build_pk_hud() -> void:

	if _pk_hud_btn and is_instance_valid(_pk_hud_btn):

		return

	_pk_hud_btn = Button.new()

	_pk_hud_btn.name = "PkModeBadge"

	_pk_hud_btn.focus_mode = Control.FOCUS_NONE

	_pk_hud_btn.custom_minimum_size = Vector2(115, 30)

	_pk_hud_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_pk_hud_btn.pressed.connect(func() -> void: _toggle_pk_menu(_pk_hud_btn))

	var bar := _ensure_top_left_bar()

	bar.add_child(_pk_hud_btn)

	_refresh_pk_ui()

const PK_COOLDOWN_WAR_TO_PEACE := 10.0      ## 10 giây chờ từ Chiến đấu về Luyện công

const PK_COOLDOWN_MURDER_TO_PEACE := 30.0   ## 30 giây chờ từ Đồ sát về Luyện công

const PK_COOLDOWN_TONGWAR_TO_PEACE := 10.0  ## 10 giây chờ từ Bang chiến về Luyện công

var _pk_cooldown_until: float = 0.0

func get_pk_peace_cooldown_remaining() -> float:

	if _pk_mode == 0:

		return 0.0

	var now := Time.get_ticks_msec() / 1000.0

	return maxf(0.0, _pk_cooldown_until - now)

func _toggle_pk_menu(origin: Control = null) -> void:

	if PkModeMenu.is_open():

		PkModeMenu.close()

		return

	PkModeMenu.open(self, _pk_mode, set_pk_mode, origin, get_pk_peace_cooldown_remaining)

func set_pk_mode(target_mode: int) -> void:

	var lp := GameManager.local_profile

	var has_guild: bool = lp != null and not lp.guild.is_empty()

	if target_mode == 3 and not has_guild:

		_notify_player("Chưa gia nhập Bang Hội — không thể bật Bang Chiến!")

		return

	if target_mode == _pk_mode:

		return

	# Kiểm tra thời gian chờ khi chuyển về Bình thường (Luyện công)

	if target_mode == 0 and _pk_mode != 0:

		var cd := get_pk_peace_cooldown_remaining()

		if cd > 0.0:

			_notify_player("⏳ Chưa thể chuyển về [BÌNH THƯỜNG / LUYỆN CÔNG]! Cần chờ thêm %d giây." % ceili(cd))

			return

	_pk_mode = target_mode

	var now := Time.get_ticks_msec() / 1000.0

	if _pk_mode != 0:

		var cd_sec := PK_COOLDOWN_MURDER_TO_PEACE if _pk_mode == 2 else PK_COOLDOWN_WAR_TO_PEACE

		_pk_cooldown_until = now + cd_sec

	else:

		_pk_cooldown_until = 0.0

	var player := get_tree().get_first_node_in_group("player")

	if player and "pk_mode" in player:

		player.pk_mode = _pk_mode

		if player.has_method("set_camp"):

			var base_camp: int = lp.get_current_camp() if lp else Camp.Type.BEGIN

			var target_camp: int = Camp.Type.FREE if _pk_mode == 2 else (Camp.Type.TONGWAR if _pk_mode == 3 else base_camp)

			player.set_camp(target_camp)

	var others := get_tree().get_nodes_in_group("other_players")

	var my_camp: int = player.camp if player else Camp.Type.BEGIN

	for node in others:

		var rp := node as RemotePlayer

		if rp and is_instance_valid(rp):

			if _pk_mode == 2:  ## Đồ sát: đánh mọi người ngoài tân thủ

				rp.set_pk_enemy(rp.camp != Camp.Type.BEGIN)

			elif _pk_mode == 1:  ## Chiến đấu phe: đánh người khác phe cũng bật chiến đấu

				var rp_in_war: bool = (rp.flags & NetProto.FLAG_PK) != 0 or bool(rp.get("pk_mode"))

				rp.set_pk_enemy(rp_in_war and rp.camp != my_camp and rp.camp != Camp.Type.BEGIN)

			elif _pk_mode == 3:  ## Bang chiến

				rp.set_pk_enemy(rp.camp == Camp.Type.TONGWAR)

			else:  ## Luyện công (bình thường): chỉ tự vệ khi bị đồ sát

				rp.set_pk_enemy((rp.flags & NetProto.FLAG_PK) != 0)

	_refresh_pk_ui()

	match _pk_mode:

		0:

			_notify_player("🛡️ Chế độ [LUYỆN CÔNG] (F9) — Hòa bình luyện công, không tấn công người khác.")

		1:

			_notify_player("⚔️ ĐÃ BẬT CHẾ ĐỘ [CHIẾN ĐẤU PHE] (F9) — Tấn công người chơi khác phe có bật chiến đấu!")

		2:

			_notify_player("💀 ĐÃ BẬT CHẾ ĐỘ [ĐỒ SÁT] (F9) — Tên đỏ rực! Có thể tấn công mọi người chơi!")

		3:

			_notify_player("🚩 ĐÃ BẬT CHẾ ĐỘ [BANG CHIẾN] (F9) — Chiến đấu vì Bang Hội!")

func _toggle_pk_mode() -> void:

	var lp := GameManager.local_profile

	var has_guild: bool = lp != null and not lp.guild.is_empty()

	var max_mode: int = 3 if has_guild else 2

	set_pk_mode((_pk_mode + 1) % (max_mode + 1))

func _refresh_pk_ui() -> void:

	if _pk_button and is_instance_valid(_pk_button):

		# Giữ nguyên icon gốc VLTK (pk.png), không ghi đè text emoji lên nút!

		_pk_button.text = ""

		SideMenu.set_active(_pk_button, _pk_mode != 0)

		match _pk_mode:

			0:

				_pk_button.tooltip_text = "Chế độ PK (F9): [LUYỆN CÔNG]\n(Bấm để mở danh sách chọn chế độ PK)"

			1:

				_pk_button.tooltip_text = "Chế độ PK (F9): [CHIẾN ĐẤU PHE]\n(Bấm để mở danh sách chọn chế độ PK)"

			2:

				_pk_button.tooltip_text = "Chế độ PK (F9): [ĐỒ SÁT]\n(Bấm để mở danh sách chọn chế độ PK)"

			3:

				_pk_button.tooltip_text = "Chế độ PK (F9): [BANG CHIẾN]\n(Bấm để mở danh sách chọn chế độ PK)"

	if _pk_hud_btn and is_instance_valid(_pk_hud_btn):

		var sb := StyleBoxFlat.new()

		sb.corner_radius_top_left = 6

		sb.corner_radius_top_right = 6

		sb.corner_radius_bottom_right = 6

		sb.corner_radius_bottom_left = 6

		sb.border_width_left = 2

		sb.border_width_top = 2

		sb.border_width_right = 2

		sb.border_width_bottom = 2

		sb.content_margin_left = 8

		sb.content_margin_right = 8

		match _pk_mode:

			0:

				_pk_hud_btn.text = "🛡️ " + tr("Luyện Công")

				_pk_hud_btn.tooltip_text = tr("Chế độ PK: [LUYỆN CÔNG] (Bấm F9 để đổi)\nHòa bình luyện công, không tấn công người chơi khác.")

				sb.bg_color = Color(0.08, 0.12, 0.08, 0.92)

				sb.border_color = Color(0.35, 0.85, 0.45)

				sb.shadow_color = Color(0.2, 0.8, 0.3, 0.3)

				sb.shadow_size = 4

				_pk_hud_btn.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))

			1:

				_pk_hud_btn.text = "⚔️ " + tr("Chiến Đấu")

				_pk_hud_btn.tooltip_text = tr("Chế độ PK: [CHIẾN ĐẤU PHE] (Bấm F9 để đổi)\nChiến đấu theo Phe (Chính / Tà / Trung Lập).")

				sb.bg_color = Color(0.25, 0.14, 0.04, 0.92)

				sb.border_color = Color(1.0, 0.65, 0.2)

				sb.shadow_color = Color(1.0, 0.5, 0.1, 0.4)

				sb.shadow_size = 5

				_pk_hud_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))

			2:

				_pk_hud_btn.text = "💀 " + tr("Đồ Sát")

				_pk_hud_btn.tooltip_text = tr("Chế độ PK: [ĐỒ SÁT] (Bấm F9 để đổi)\nTên đỏ rực, có thể tấn công tất cả người chơi ngoài tổ đội.")

				sb.bg_color = Color(0.28, 0.04, 0.04, 0.92)

				sb.border_color = Color(1.0, 0.25, 0.25)

				sb.shadow_color = Color(1.0, 0.1, 0.1, 0.5)

				sb.shadow_size = 6

				_pk_hud_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))

			3:

				_pk_hud_btn.text = "🚩 " + tr("Bang Chiến")

				_pk_hud_btn.tooltip_text = tr("Chế độ PK: [BANG CHIẾN] (Bấm F9 để đổi)\nChiến tranh giữa các bang hội.")

				sb.bg_color = Color(0.18, 0.05, 0.28, 0.92)

				sb.border_color = Color(0.75, 0.3, 0.95)

				sb.shadow_color = Color(0.7, 0.2, 0.9, 0.4)

				sb.shadow_size = 5

				_pk_hud_btn.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0))

		_pk_hud_btn.add_theme_stylebox_override("normal", sb)

		_pk_hud_btn.add_theme_stylebox_override("hover", sb)

		_pk_hud_btn.add_theme_stylebox_override("pressed", sb)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_pk_ui()

func _update_pk_hud_button() -> void:
	_refresh_pk_ui()

## Nút công cụ thử (chỉ bản debug/GM) — xếp thẳng hàng cùng nút PK ở góc trên trái, không chèn đè lên nhau.

func _build_debug_button(text: String, tip: String, on_press: Callable, is_gold_highlight: bool = false) -> Button:

	var button := Button.new()

	button.text = text

	button.tooltip_text = tip

	button.focus_mode = Control.FOCUS_NONE

	button.custom_minimum_size = Vector2(74 if is_gold_highlight else 64, 30)

	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if is_gold_highlight:

		button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))

		var sb := StyleBoxFlat.new()

		sb.bg_color = Color(0.18, 0.12, 0.04, 0.95)

		sb.border_color = Color(0.95, 0.75, 0.2)

		sb.set_border_width_all(2)

		sb.set_corner_radius_all(4)

		button.add_theme_stylebox_override("normal", sb)

		button.add_theme_stylebox_override("hover", sb)

		button.add_theme_stylebox_override("pressed", sb)

	button.pressed.connect(on_press)

	var bar := _ensure_top_left_bar()

	bar.add_child(button)

	return button

func _open_gm_window() -> void:

	var existing := get_tree().current_scene.find_child("GmControlWindow", true, false)

	if existing:

		existing.queue_free()

		return

	GmControlWindow.open(self)

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

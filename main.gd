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
var _key_guide_window: KeyGuideWindow = null
var _settings_window: SettingsWindow = null
var _guild_window: GuildWindow = null
var _friend_window: FriendWindow = null

## Map VLTK dùng để lấy nhạc nền khi StageData không khai báo vltk_map_id — tạm, thay bằng map thật của màn.

const DEFAULT_MUSIC_MAP_ID := 1

const PkRoomBadge = preload("res://ui/hud/pk_room_badge.gd")
const SelectedSkillsWindow = preload("res://ui/hud/selected_skills_window.gd")

func _play_stage_music(stage: StageData) -> void:

	var map_id := stage.vltk_map_id if stage.vltk_map_id > 0 else DEFAULT_MUSIC_MAP_ID

	MusicManager.play_map(map_id)

func _exit_tree() -> void:

	HudLayout.remove_listener(_apply_hud_layout)

	MusicManager.stop()

	PlayerStats.reset()

	var pubg_cls = load("res://systems/pubg/pubg_manager.gd")
	if pubg_cls and pubg_cls.is_active:
		pubg_cls.end_match(GameManager.local_profile)

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

	if GameManager.local_profile == null:
		GameManager.local_profile = SaveManager.load_profile()
		if GameManager.local_profile == null:
			var default_p := PlayerProfile.new()
			default_p.display_name = "Đại Hiệp"
			default_p.level = 10
			default_p.sect_id = "vo_dang"
			GameManager.local_profile = default_p

	var free_roam := GameManager.game_mode == GameManager.GameMode.MAIN_MAP

	var stage: StageData = GameManager.current_stage if GameManager.current_stage else stage_for_testing

	if free_roam:

		_enter_main_map()

	elif stage:

		load_stage(stage)

		_play_stage_music(stage)

	var is_thu_thanh: bool = (GameManager.field_map is Dictionary and GameManager.field_map.get("thu_thanh_mode", false) == true)
	if is_thu_thanh:
		if has_node("UI"):
			$UI.visible = false
		return

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

	var quick_item_bar := QuickItemBar.new()
	$UI.add_child(quick_item_bar)
	if GameManager.is_manor_mode():
		quick_item_bar.visible = false

	HudLayout.add_listener(_apply_hud_layout)

	_apply_hud_layout()   ## 4 ô thuốc nhanh ngay trên cụm nút skill
	if skill_bar_ui != null:
		skill_bar_ui.sit_follows_bar = true
		skill_bar_ui.layout_applied.connect(_queue_fit_bars_to_skill_buttons)
		skill_bar_ui.apply_layout()

	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		loc_mgr.locale_changed.connect(func(_loc: String) -> void:
			_refresh_pk_ui()
		)

	$UI.add_child(AgeRatingBadge.new())

	add_child(SocialTicker.new())   ## nhịp nền xã hội: khách mua hàng bày bán, người xin vào đội/bang

	_sect_prompt = SectPrompt.new()   ## Vô Môn Phái đủ cấp 10 thì hỏi gia nhập môn phái

	add_child(_sect_prompt)

	if AccountApi.is_gm():   ## công cụ thử (chỉ admin GM): hàng nút nhỏ góc trên trái
		_setup_gm_buttons()

	var tm_intro: Node = get_node_or_null("/root/TutorialManager")
	if tm_intro and tm_intro.has_method("is_in_intro_flow") and tm_intro.is_in_intro_flow():
		tm_intro.continue_in_game_tutorial(self)
	elif (GameManager.field_map is Dictionary and GameManager.field_map.get("survivor_mode", false) == true) or (GameModeManager.is_offline() and GameManager.current_stage != null):
		var p_prof := GameManager.local_profile
		var s_id: String = p_prof.sect_id if p_prof != null and p_prof.sect_id != "" else "vo_dang"
		var w_class: int = Equipment.get_weapon_class(p_prof.equipment) if p_prof != null else -1
		SurvivorManager.init_pool(s_id, w_class)
		var level_up_ui: Node = get_node_or_null("LevelUpUi")
		if level_up_ui == null:
			level_up_ui = get_node_or_null("UI/LevelUpUI")
		if level_up_ui and level_up_ui.has_method("show_initial_skill_selection"):
			level_up_ui.show_initial_skill_selection.call_deferred()

	if GameManager.field_map is Dictionary and (GameManager.field_map.get("pubg", false) or GameManager.field_map.get("is_pubg", false)):
		_open_pubg_draft_popup()

func _open_pubg_draft_popup() -> void:
	var prof: PlayerProfile = GameManager.local_profile
	var player_node := get_tree().get_first_node_in_group("player") as Node2D
	var draft_script: GDScript = load("res://ui/pubg/pubg_draft_popup.gd")
	if draft_script and draft_script.has_method("open"):
		draft_script.open(self, prof, func() -> void:
			if is_instance_valid(player_node):
				if player_node.has_method("refresh_combat_stats"):
					player_node.refresh_combat_stats()
				elif player_node.has_method("refresh_appearance"):
					player_node.refresh_appearance()
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

	## Chiến Trường Sinh Tồn online (PubgServer trên server thế giới): nối như map thường, server đưa vào trận — PubgClient.
	var pubg_online := bool(field.get("pubg_online", false)) and NetWorldSync.is_online_mode()
	## Lộn Xộn (LonXonServer trên server thế giới): nối như map thường, server đưa vào host — LonXonClient.
	var lonxon_online := bool(field.get("lonxon_online", false)) and NetWorldSync.is_online_mode()
	var online := (NetWorldSync.is_online_mode() and field.is_empty()) or not battle.is_empty() or pk_online or not room.is_empty() or pubg_online or lonxon_online

	VltkWorld.net_monsters = online

	if VltkWorld.current != null:
		if not field.is_empty() and field.has("dir"):
			VltkWorld.current.map_dir = str(field["dir"])
		elif VltkWorld.current.map_dir == "" or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(VltkWorld.current.map_dir)):
			VltkWorld.current.map_dir = "res://world/maps/map_200"
		VltkWorld.current.setup_main_map()

	## Chế độ Thủ Thành (Zombies vs Plants JX1): Bàn cờ 11x5, hiệp khách, Xe Lương Thảo, 5 đợt quái
	if field.get("thu_thanh_mode", false):
		var tt_script: GDScript = load("res://systems/challenge/thu_thanh_challenge.gd")
		if tt_script != null:
			var tt = tt_script.new()
			tt.name = "ThuThanhChallenge"
			add_child(tt)
		if has_node("UI"):
			$UI.visible = false

	elif field.get("survivor_mode", false):
		var survivor_challenge := SurvivorWaveChallenge.new()
		survivor_challenge.name = "SurvivorWaveChallenge"
		add_child(survivor_challenge)

	## Thách Thức Thời Gian (tab "Ải" của màn Vượt Ải): đấu trường map 480, quái theo từng ải.

	elif field.get("challenge", false):

		var challenge := TimeChallenge.new()

		challenge.name = "TimeChallenge"

		add_child(challenge)

	## Ải Thuyền Phong Lăng Độ (tab "Ải" của màn Vượt Ải): map 336, diệt Thủy tặc & Boss Yên Hiểu Trái.

	elif field.get("phong_lang_do", false):

		var pld := PhongLangDoChallenge.new()

		pld.name = "PhongLangDoChallenge"

		add_child(pld)

	## Khu Chuẩn Bị Linh Lung Tháp (Map #1037)
	elif field.get("linh_lung_prep", false):
		var prep_script: GDScript = load("res://systems/challenge/linh_lung_prep_area.gd")
		if prep_script != null:
			var prep = prep_script.new()
			prep.name = "LinhLungPrepArea"
			add_child(prep)

	## Ải Linh Lung Tháp (tab "Ải" của màn Vượt Ải): 7 tầng tháp & Cầm Long Trụ
	elif field.get("linh_lung_thap", false):
		var llt_script: GDScript = load("res://systems/challenge/linh_lung_thap_challenge.gd")
		if llt_script != null:
			var llt = llt_script.new()
			llt.name = "LinhLungThapChallenge"
			add_child(llt)

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

	## Ải Hiệp Phong Luận Kiếm (Map 1040)

	elif field.get("thien_tam_thap", false):

		var ttt_script: GDScript = load("res://systems/challenge/thien_tam_thap_challenge.gd")

		if ttt_script != null:

			var ttt = ttt_script.new()

			ttt.name = "ThienTamThapChallenge"

			add_child(ttt)

	## Trận Công Thành Chiến (20 vs 20 trên map 378 - 20 phút)
	if field.get("city_war", false):
		var cw_match := CityWarMatch.new()
		cw_match.name = "CityWarMatch"
		add_child(cw_match)
	## Ải Tống Kim LOL (MOBA 1vs1 - 5vs5 trên map 378)
	elif field.get("tong_kim_lol", false) or int(field.get("pk", {}).get("mode", -1)) == PkRules.Mode.TONG_KIM_LOL:

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

	## Map Nguyệt Ca Đảo (Sơn Trang Nông Trại) - chỉ nạp khi vào chế độ Sơn Trang (manor)
	if field.get("manor", false):
		# Đảm bảo UI nổi lên trên màn phủ bóng tối ban đêm (layer 10)
		if has_node("UI") and $UI is CanvasLayer:
			$UI.layer = 10

		var farm_hud_script: GDScript = load("res://ui/son_trang/farm_hud.gd")
		if farm_hud_script != null:
			var f_hud = farm_hud_script.new()
			f_hud.name = "FarmHUD"
			$UI.add_child(f_hud)

		# Khởi tạo Hệ thống Chu kỳ Ngày & Đêm Sơn Trang (Day & Night System với quầng sáng đống lửa)
		var day_night_script: GDScript = load("res://systems/son_trang/farm_day_night_controller.gd")
		if day_night_script != null:
			var day_night_node = day_night_script.new()
			day_night_node.name = "FarmDayNightController"
			add_child(day_night_node)
		
		# Khởi tạo khu đất trồng trọt tại tọa độ 185/185 -> 185/187 -> 193/190 -> 191/187
		var plots_script: GDScript = load("res://systems/son_trang/farm_plots_controller.gd")
		if plots_script != null:
			var plots_node = plots_script.new()
			plots_node.name = "FarmPlotsController"
			var farm_pos: Vector2 = plots_script.FARM_CENTER_WORLD if "FARM_CENTER_WORLD" in plots_script else Vector2(48512, 47998)
			plots_node.position = farm_pos
			if VltkWorld.current != null:
				VltkWorld.current.add_child(plots_node)
			else:
				add_child(plots_node)

		# Khởi tạo khu chăn nuôi tại tọa độ 194/193
		var livestock_script: GDScript = load("res://systems/son_trang/livestock_controller.gd")
		if livestock_script != null:
			var ls_node = livestock_script.new()
			ls_node.name = "LivestockController"
			var ls_pos: Vector2 = livestock_script.LIVESTOCK_CENTER_WORLD if "LIVESTOCK_CENTER_WORLD" in livestock_script else Vector2(49792, 49536)
			ls_node.position = ls_pos
			if VltkWorld.current != null:
				VltkWorld.current.add_child(ls_node)
			else:
				add_child(ls_node)

		# Khởi tạo 4 NPC Thương Nhân chuyên dụng (Chăn nuôi 195/192, Trồng trọt 191/186, Cá nước ngọt 180/185, Cá biển 196/197)
		var npc_script: GDScript = load("res://systems/son_trang/farm_npc_controller.gd")
		if npc_script != null:
			var npc_node = npc_script.new()
			npc_node.name = "FarmNPCController"
			if VltkWorld.current != null:
				VltkWorld.current.add_child(npc_node)
			else:
				add_child(npc_node)

		# Khởi tạo 2 Khu Nuôi Trồng Thủy Hải Sản (Ao Cá Nước Ngọt 181/185 & Bè Cá Biển 196/196)
		var fish_script: GDScript = load("res://systems/son_trang/farm_fish_controller.gd")
		if fish_script != null:
			var fish_node = fish_script.new()
			fish_node.name = "FarmFishController"
			if VltkWorld.current != null:
				VltkWorld.current.add_child(fish_node)
			else:
				add_child(fish_node)

		# Khởi tạo các Đống Lửa Sơn Trang (Campfire) tại mỗi vị trí NPC
		var campfire_script: GDScript = load("res://systems/son_trang/farm_campfire_controller.gd")
		if campfire_script != null:
			var campfire_node = campfire_script.new()
			campfire_node.name = "FarmCampfireController"
			campfire_node.position = Vector2.ZERO
			if VltkWorld.current != null:
				VltkWorld.current.add_child(campfire_node)
			else:
				add_child(campfire_node)

	# Khởi tạo Thú Cưng / Vật Nuôi Đồng Hành theo sau nhân vật khi di chuyển ở ngoài
	_setup_pet_companion()

	var is_pk: bool = field.has("pk") or field.get("brawl", false) or field.get("tong_kim_lol", false) or field.get("city_war", false)

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

	if pubg_online:

		add_child(PubgClient.create())

	if lonxon_online:

		add_child(LonXonClient.create())

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

	if event.ctrl_pressed:
		if event.keycode == KEY_F8:
			## Chép toạ độ (pixel map) của nhân vật để dán vào StageData.arena_center khi đặt ô vuông màn chơi.
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p:
				var feet := p.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
				var text := "Vector2(%d, %d)" % [roundi(feet.x), roundi(feet.y)]
				DisplayServer.clipboard_set(text)
				print("arena_center = ", text, "  (đã chép vào clipboard)")
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_F5:
			var player := get_tree().get_first_node_in_group("player")
			if player:
				SaveManager.save_game(player)
				print("Đã lưu game (Ctrl+F5).")
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_F6:
			var player := get_tree().get_first_node_in_group("player")
			if player and SaveManager.load_game(player):
				print("Đã tải game (Ctrl+F6).")
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_F10:
			DebugDataBrowser.open(self, func() -> void: pass)
			get_viewport().set_input_as_handled()
			return
	elif event.keycode == KEY_F10:
		DebugDataBrowser.open(self, func() -> void: pass)
		get_viewport().set_input_as_handled()
		return

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

## Mở / Tắt các bảng giao diện theo chuẩn phím tắt VLTK PC:
## F1: Trợ giúp / Bảng hướng dẫn phím tắt (KeyGuideWindow)
## F2: Cài đặt hệ thống (SettingsWindow)
## F3 / C: Bảng thuộc tính nhân vật & Trang bị (CharacterStatusWindow)
## F4 / B / I: Bảng hành trang (InventoryPopup)
## F5 / K / G: Bảng kỹ năng võ công (SkillBookScreen)
## F6: Bang Hội (GuildWindow)
## F7 / T / O: Bật / tắt chế độ Giao dịch
## F8: Danh sách Hảo hữu (FriendWindow)
## F9: Chuyển chế độ PK
## F11: Kỳ Trân Các (KyTranCacWindow)
## F12: GM Control / Cài đặt
## P: Bật / Tắt giao diện Tổ đội (TeamWindow)
## Tab: Bật / Tắt bản đồ khu vực
## Esc: Đóng bảng trên cùng / Mở Cài đặt hệ thống
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_ev := event as InputEventKey
		var typing := _typing()

		# Phím Escape: đóng cửa sổ đang mở, nếu không có cửa sổ thì mở Cài đặt
		if key_ev.keycode == KEY_ESCAPE:
			if not _close_top_menu_window():
				_toggle_settings_window()
			get_viewport().set_input_as_handled()
			return

		# F1: Bảng Trợ giúp / Hướng dẫn phím tắt
		if key_ev.keycode == KEY_F1:
			_toggle_key_guide_window()
			get_viewport().set_input_as_handled()
			return

		# F2: Cài đặt hệ thống
		elif key_ev.keycode == KEY_F2:
			_toggle_settings_window()
			get_viewport().set_input_as_handled()
			return

		# F3 hoặc C: Bảng thuộc tính nhân vật & Trang bị
		elif key_ev.keycode == KEY_F3 or (not typing and key_ev.keycode == KEY_C):
			_toggle_status_window()
			get_viewport().set_input_as_handled()
			return

		# F4 hoặc B / I: Bảng hành trang / Rương đồ cá nhân
		elif key_ev.keycode == KEY_F4 or (not typing and (key_ev.keycode == KEY_B or key_ev.keycode == KEY_I)):
			_toggle_inventory_window()
			get_viewport().set_input_as_handled()
			return

		# F5 hoặc K / G: Bảng kỹ năng võ công (Skill Book)
		elif key_ev.keycode == KEY_F5 or (not typing and (key_ev.keycode == KEY_K or key_ev.keycode == KEY_G)):
			_toggle_skill_book()
			get_viewport().set_input_as_handled()
			return

		# F6: Bang Hội
		elif key_ev.keycode == KEY_F6:
			_toggle_guild_window()
			get_viewport().set_input_as_handled()
			return

		# F7 hoặc T / O: Bật / tắt chế độ Giao dịch
		elif key_ev.keycode == KEY_F7 or (not typing and (key_ev.keycode == KEY_T or key_ev.keycode == KEY_O)):
			_toggle_trade_mode()
			get_viewport().set_input_as_handled()
			return

		# F8: Danh sách Hảo hữu
		elif key_ev.keycode == KEY_F8:
			_toggle_friend_window()
			get_viewport().set_input_as_handled()
			return

		# F9: Chuyển chế độ PK (Luyện Công / Phe / Đồ Sát / Bang)
		elif key_ev.keycode == KEY_F9:
			_toggle_pk_menu(_pk_button if is_instance_valid(_pk_button) else _pk_hud_btn)
			get_viewport().set_input_as_handled()
			return

		# F11: Kỳ Trân Các
		elif key_ev.keycode == KEY_F11:
			_toggle_ky_tran_cac()
			get_viewport().set_input_as_handled()
			return

		# F12: Quản trị GM (nếu có quyền), hoặc Cài đặt hệ thống
		elif key_ev.keycode == KEY_F12:
			if AccountApi.is_gm():
				_open_gm_window()
			else:
				_toggle_settings_window()
			get_viewport().set_input_as_handled()
			return

		# P: Bật / Tắt giao diện Tổ đội (Party)
		elif not typing and key_ev.keycode == KEY_P:
			_toggle_team_window()
			get_viewport().set_input_as_handled()
			return

		# TAB: Bật / Tắt Bản đồ toàn cảnh
		elif key_ev.keycode == KEY_TAB:
			_toggle_map_panel()
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
	if is_instance_valid(_key_guide_window) and not _key_guide_window.is_queued_for_deletion():
		return true
	if is_instance_valid(_settings_window) and not _settings_window.is_queued_for_deletion():
		return true
	if is_instance_valid(_guild_window) and not _guild_window.is_queued_for_deletion():
		return true
	if is_instance_valid(_friend_window) and not _friend_window.is_queued_for_deletion():
		return true
	if is_instance_valid(_team_window) and not _team_window.is_queued_for_deletion():
		return true
	if is_instance_valid(_ky_tran_cac_window) and not _ky_tran_cac_window.is_queued_for_deletion():
		return true
	if SelectedSkillsWindow.instance != null and is_instance_valid(SelectedSkillsWindow.instance):
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

func _close_top_menu_window() -> bool:
	if is_instance_valid(_key_guide_window):
		_key_guide_window.close_requested.emit()
		_key_guide_window = null
		_update_stage_pause()
		return true
	if is_instance_valid(_settings_window):
		_settings_window.close_requested.emit()
		_settings_window = null
		_update_stage_pause()
		return true
	if is_instance_valid(_guild_window):
		_guild_window.close_requested.emit()
		_guild_window = null
		_update_stage_pause()
		return true
	if is_instance_valid(_friend_window):
		_friend_window.close_requested.emit()
		_friend_window = null
		_update_stage_pause()
		return true
	if is_instance_valid(_team_window):
		_team_window.queue_free()
		_team_window = null
		_update_stage_pause()
		return true
	if is_instance_valid(_ky_tran_cac_window):
		var win := _ky_tran_cac_window
		_ky_tran_cac_window = null
		win.queue_free()
		_update_stage_pause()
		return true
	if _skill_book_open or is_instance_valid(_skill_book_screen):
		if is_instance_valid(_skill_book_screen):
			_skill_book_screen._on_close_pressed()
		else:
			_skill_book_open = false
		_update_stage_pause()
		return true
	if is_instance_valid(_status_window):
		var win := _status_window
		_status_window = null
		win.queue_free()
		_update_stage_pause()
		return true
	if is_instance_valid(_inventory_window):
		var win := _inventory_window
		_inventory_window = null
		win.queue_free()
		_update_stage_pause()
		return true
	return false

func _toggle_key_guide_window() -> void:
	if is_instance_valid(_key_guide_window):
		_key_guide_window.close_requested.emit()
		_key_guide_window = null
		_update_stage_pause()
		return
	_key_guide_window = KeyGuideWindow.open(self)
	if _key_guide_window:
		_key_guide_window.close_requested.connect(func() -> void:
			_key_guide_window = null
			_update_stage_pause()
		)
	_update_stage_pause()

func _toggle_settings_window() -> void:
	if is_instance_valid(_settings_window):
		_settings_window.close_requested.emit()
		_settings_window = null
		_update_stage_pause()
		return
	_settings_window = SettingsWindow.open(self, _on_exit_button_pressed)
	if _settings_window:
		_settings_window.close_requested.connect(func() -> void:
			_settings_window = null
			_update_stage_pause()
		)
	_update_stage_pause()

func _toggle_guild_window() -> void:
	if is_instance_valid(_guild_window):
		_guild_window.close_requested.emit()
		_guild_window = null
		_update_stage_pause()
		return
	var p := GameManager.local_profile
	if p:
		_guild_window = GuildWindow.open(self, SocialHub.of(p))
		if _guild_window:
			_guild_window.close_requested.connect(func() -> void:
				_guild_window = null
				_update_stage_pause()
			)
	_update_stage_pause()

func _toggle_friend_window() -> void:
	if is_instance_valid(_friend_window):
		_friend_window.close_requested.emit()
		_friend_window = null
		_update_stage_pause()
		return
	if GameManager.local_profile:
		_friend_window = FriendWindow.open(self, GameManager.local_profile)
		if _friend_window:
			_friend_window.close_requested.connect(func() -> void:
				_friend_window = null
				_update_stage_pause()
			)
	_update_stage_pause()

func _toggle_selected_skills_window() -> void:
	SelectedSkillsWindow.toggle_window(self)

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

	_status_window.profile_changed.connect(_on_panel_profile_changed)

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

		_status_window.refresh()

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
## Hàng nút thao tác: mép phải (= mép phải nút Ngồi cũ trong SkillBarUI.tscn), ô Ngồi 52px, 3 nút tròn + 3 khe 6px.
const BOTTOM_BAR_RIGHT := -357.0 + SkillBarUI.CLUSTER_SHIFT_X
## Mép phải hàng nút tiện ích — đi theo cụm nút skill (SkillBarUI.CLUSTER_SHIFT_X) để khỏi chồng.
const SIDE_MENU_RIGHT := -360.0 + SkillBarUI.CLUSTER_SHIFT_X
const BOTTOM_BAR_SIT_SLOT := 52.0
const BOTTOM_BAR_WIDTH := 3 * SideMenu.SLOT + BOTTOM_BAR_SIT_SLOT + 3 * 6
var _pk_frames: Array[Texture2D] = []

## Cột nút tiện ích bên phải — SideMenu (hàng ngang góc trên phải): Nhân vật, Hành trang, Kỹ năng, Cài đặt.

func _build_side_menu() -> void:

	var menu := SideMenu.new()

	menu.name = "SideMenu"

	menu.add_entry("status", "", "Nhân vật (phím F3 / C)", _toggle_status_window)

	menu.add_entry("items", "", "Hành trang (phím F4 / B)", _toggle_inventory_window)

	var skill_btn := menu.add_entry("skills", "", "Kỹ năng (phím F5 / K / G)", _toggle_skill_book)
	skill_btn.add_to_group("tutorial_skill_menu_btn")

	if GameModeManager.is_offline():   ## chỉ offline mới có cửa sổ "Võ công đã chọn"
		menu.add_entry("", "⚡", "Võ công đã chọn", _toggle_selected_skills_window)

	menu.add_entry("itemex", "Kỳ", "Kỳ Trân Các (phím F11)", _toggle_ky_tran_cac)

	_build_pk_hud()
	$UI.add_child(TeamListHud.new())   ## khung danh sách tổ đội góc trái, ngay dưới hàng nút PK

	## Nút Cài đặt: góc trên phải, sát bên trái mini map. Nút "Thoát về Character Hub" nằm trong khung Cài đặt.

	var exit_button := SideMenu.make_button("", "⚙", "Cài đặt (phím F2 / Esc): nhạc nền, zoom camera, thoát", func() -> void:

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

	## Các nút tiện ích: chuyển xuống hàng dưới cùng (sát mép đáy, thẳng hàng đều với cụm nút thao tác ở hàng trên).

	menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)

	menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	menu.grow_vertical = Control.GROW_DIRECTION_BEGIN

	menu.offset_right = SIDE_MENU_RIGHT

	var count := menu.get_child_count()

	menu.offset_left = SIDE_MENU_RIGHT - (count * SideMenu.SLOT + (count - 1) * SideMenu.GAP)

	menu.offset_top = -58.0

	menu.offset_bottom = -12.0

	menu.alignment = BoxContainer.ALIGNMENT_END

	$UI.add_child(menu)

	_build_bottom_action_bar()

## Cụm nút thao tác (Tổ đội, Chiến đấu/PK, Giao dịch) đặt ở hàng trên, thẳng hàng đều với cụm tiện ích phía dưới

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

	_trade_button = SideMenu.make_button("exchange", "🤝", "Bật giao dịch (phím F7 / T)", _toggle_trade_mode)
	SideMenu.make_bare(_trade_button)   ## ảnh giao dịch gốc đã là nút tròn: bỏ nền đen, cho to bằng nút Ngồi

	## Nút PK: KHÔNG dùng 3 khung ảnh pk.png làm thường / rê chuột / bấm — 3 khung đó là 3 TRẠNG THÁI PK
	## (gốc Player_PK::UpdateData: SetFrame 0 Luyện công, 1 Chiến đấu, 2 Đồ sát, 3 Bang chiến). _refresh_pk_ui đổi ảnh.
	_pk_button = SideMenu.make_button("", "", "Chế độ PK (phím F9): Chọn Luyện Công / Chiến Đấu / Đồ Sát", func() -> void: _toggle_pk_menu(_pk_button))
	_pk_frames = SideMenu._frames("pk")
	var pk_icon := TextureRect.new()
	pk_icon.name = "PkIcon"
	pk_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pk_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pk_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pk_button.add_child(pk_icon)

	var pk_glyph := Label.new()
	pk_glyph.name = "PkGlyph"
	pk_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pk_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pk_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	pk_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pk_glyph.add_theme_font_size_override("font_size", 20)
	_pk_button.add_child(pk_glyph)

	SideMenu.make_bare(_pk_button, 0.0)
	## Ô trống giữ chỗ cho nút Ngồi (SitButton nằm trong SkillBarUI, đặt đúng vào ô này).
	var sit_slot := Control.new()
	sit_slot.name = "SitSlot"
	sit_slot.custom_minimum_size = Vector2(BOTTOM_BAR_SIT_SLOT, SideMenu.SLOT)
	sit_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_team_button = SideMenu.make_button("party", "👥", "Tổ Đội (phím P)", _toggle_team_window)

	## Thứ tự: Giao dịch, [Ngồi], Tổ đội, PK — nút PK ngoài cùng bên phải (chỗ nút Ngồi cũ).
	_bottom_action_bar.add_child(_trade_button)

	_bottom_action_bar.add_child(sit_slot)

	_bottom_action_bar.add_child(_team_button)

	_bottom_action_bar.add_child(_pk_button)

	_refresh_trade_button()

	_refresh_pk_ui()

	# Hàng trên (Giao dịch, Ngồi, Tổ đội, PK) thẳng hàng y = -112.0 đến -66.0, mép phải = mép phải nút Ngồi cũ
	_bottom_action_bar.offset_right = BOTTOM_BAR_RIGHT

	_bottom_action_bar.offset_left = BOTTOM_BAR_RIGHT - BOTTOM_BAR_WIDTH

	_bottom_action_bar.offset_top = -112.0

	_bottom_action_bar.offset_bottom = -66.0

	$UI.add_child(_bottom_action_bar)

var _fit_bars_pending := false

## Nút Ngồi thuộc cụm thao tác (Giao dịch / Ngồi / Tổ đội / PK): kéo / đổi cỡ cụm thì nút Ngồi đi theo.
func _queue_fit_bars_to_skill_buttons() -> void:
	if _fit_bars_pending:
		return
	_fit_bars_pending = true
	await get_tree().process_frame   ## chờ container xếp xong con mới đọc được toạ độ thật
	_fit_bars_pending = false
	_fit_bars_to_skill_buttons()

func _fit_bars_to_skill_buttons() -> void:
	if skill_bar_ui == null or not is_instance_valid(skill_bar_ui):
		return
	if _bottom_action_bar == null or not is_instance_valid(_bottom_action_bar):
		return
	var slot := _bottom_action_bar.get_node_or_null("SitSlot") as Control
	if slot == null:
		return
	## Nút Ngồi vuông, cạnh = ô Ngồi (52) x cỡ cụm, canh giữa ô.
	var r := slot.get_global_rect()
	var side := BOTTOM_BAR_SIT_SLOT * _bottom_action_bar.scale.x
	skill_bar_ui.place_sit_at(Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)))

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

	# SideMenu (Hàng nút túi đồ / nhân vật... ở hàng dưới sát đáy)

	var side_menu := $UI.get_node_or_null("SideMenu") as SideMenu

	if side_menu != null:

		var side_data: Dictionary = HudLayout.get_element("side_menu")

		var side_ox: float = float(side_data.get("offset_x", 0.0))

		var side_oy: float = float(side_data.get("offset_y", 0.0))

		var side_scale: float = float(side_data.get("scale", 1.0))

		var count: int = side_menu.get_child_count()

		side_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)

		side_menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN

		side_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN

		side_menu.offset_right = SIDE_MENU_RIGHT + side_ox

		side_menu.offset_left = SIDE_MENU_RIGHT - (count * SideMenu.SLOT + (count - 1) * SideMenu.GAP) * side_scale + side_ox

		side_menu.offset_top = -58.0 + side_oy

		side_menu.offset_bottom = -12.0 + side_oy

		side_menu.scale = Vector2.ONE * side_scale

	# BottomActionBar (Giao dịch, PK, Tổ đội ở hàng trên)

	if _bottom_action_bar != null and is_instance_valid(_bottom_action_bar):

		var bar_data: Dictionary = HudLayout.get_element("bottom_bar")

		var bar_ox: float = float(bar_data.get("offset_x", 0.0))

		var bar_oy: float = float(bar_data.get("offset_y", 0.0))

		var bar_scale: float = float(bar_data.get("scale", 1.0))

		_bottom_action_bar.offset_right = BOTTOM_BAR_RIGHT + bar_ox

		_bottom_action_bar.offset_left = BOTTOM_BAR_RIGHT - BOTTOM_BAR_WIDTH * bar_scale + bar_ox

		_bottom_action_bar.offset_top = -112.0 + bar_oy

		_bottom_action_bar.offset_bottom = -66.0 + bar_oy

		_bottom_action_bar.scale = Vector2.ONE * bar_scale

	_queue_fit_bars_to_skill_buttons()

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

		_trade_button.tooltip_text = "Đang mở giao dịch (F7 / T)\nNgười chơi khác có thể giao dịch trực tiếp với bạn.\n(Bấm để tắt mở giao dịch)"

	else:

		_trade_button.tooltip_text = "Bật giao dịch (F7 / T)\nBật mở giao dịch để người chơi khác có thể giao dịch trực tiếp với bạn.\n(Chọn người chơi rồi bấm để xin giao dịch)"

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

	# Đồng bộ cờ mạng ngay lập tức sang server và các client khác
	var sync_node := get_node_or_null("NetWorldSync")
	if sync_node and sync_node.has_method("force_sync"):
		sync_node.force_sync()

	var others := get_tree().get_nodes_in_group("other_players")
	var my_camp: int = player.camp if player else (lp.get_current_camp() if lp else Camp.Type.BEGIN)
	for node in others:
		var rp := node as RemotePlayer
		if rp and is_instance_valid(rp):
			if rp.has_method("update_pk_relation"):
				rp.update_pk_relation()
			else:
				if _pk_mode == 2:  ## Đồ sát: đánh mọi người ngoài tân thủ
					rp.set_pk_enemy(rp.camp != Camp.Type.BEGIN)
				elif _pk_mode == 1:  ## Chiến đấu phe: đánh người khác phe cũng bật chiến đấu
					var rp_in_war: bool = (rp.flags & NetProto.FLAG_PK_WAR) != 0
					var rp_in_murder: bool = (rp.flags & NetProto.FLAG_PK) != 0
					rp.set_pk_enemy(rp_in_murder or (rp_in_war and rp.camp != my_camp and rp.camp != Camp.Type.BEGIN))
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
		_pk_button.text = ""
		var pk_icon := _pk_button.get_node_or_null("PkIcon") as TextureRect
		var pk_glyph := _pk_button.get_node_or_null("PkGlyph") as Label

		var border_color: Color
		var bg_color: Color
		var shadow_col: Color

		match _pk_mode:
			0:  ## Luyện công (Hòa bình) - Icon Khiên 🛡️
				if pk_icon != null:
					pk_icon.visible = false
				if pk_glyph != null:
					pk_glyph.text = "🛡️"
					pk_glyph.visible = true
				border_color = Color(0.35, 0.85, 0.45)
				bg_color = Color(0.06, 0.14, 0.08, 0.92)
				shadow_col = Color(0.2, 0.8, 0.3, 0.3)
				_pk_button.tooltip_text = "Chế độ PK (F9): [LUYỆN CÔNG]\n(Bấm để mở danh sách chọn chế độ PK)"
			1:  ## Chiến đấu phe - Icon 2 Kiếm Chéo ⚔️ (ảnh pk.png gốc)
				if pk_icon != null and not _pk_frames.is_empty():
					pk_icon.texture = _pk_frames[0]
					pk_icon.modulate = Color(1.0, 0.85, 0.4)
					pk_icon.visible = true
					if pk_glyph != null:
						pk_glyph.visible = false
				else:
					if pk_icon != null:
						pk_icon.visible = false
					if pk_glyph != null:
						pk_glyph.text = "⚔️"
						pk_glyph.visible = true
				border_color = Color(1.0, 0.65, 0.2)
				bg_color = Color(0.25, 0.14, 0.04, 0.92)
				shadow_col = Color(1.0, 0.5, 0.1, 0.5)
				_pk_button.tooltip_text = "Chế độ PK (F9): [CHIẾN ĐẤU PHE]\n(Bấm để mở danh sách chọn chế độ PK)"
			2:  ## Đồ sát - Icon Đầu Lâu 💀
				if pk_icon != null:
					pk_icon.visible = false
				if pk_glyph != null:
					pk_glyph.text = "💀"
					pk_glyph.visible = true
				border_color = Color(1.0, 0.25, 0.25)
				bg_color = Color(0.28, 0.04, 0.04, 0.92)
				shadow_col = Color(1.0, 0.1, 0.1, 0.6)
				_pk_button.tooltip_text = "Chế độ PK (F9): [ĐỒ SÁT]\n(Bấm để mở danh sách chọn chế độ PK)"
			3:  ## Bang chiến - Icon Cờ 🚩
				if pk_icon != null:
					pk_icon.visible = false
				if pk_glyph != null:
					pk_glyph.text = "🚩"
					pk_glyph.visible = true
				border_color = Color(0.85, 0.5, 1.0)
				bg_color = Color(0.18, 0.05, 0.28, 0.92)
				shadow_col = Color(0.7, 0.2, 0.9, 0.5)
				_pk_button.tooltip_text = "Chế độ PK (F9): [BANG CHIẾN]\n(Bấm để mở danh sách chọn chế độ PK)"

		# Viền tròn và hiệu ứng phát sáng cho nút tròn PK
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(SideMenu.SLOT / 2))
		sb.bg_color = bg_color
		sb.border_color = border_color
		sb.set_border_width_all(2)
		sb.shadow_color = shadow_col
		sb.shadow_size = 5
		for st in ["normal", "focus", "hover", "pressed"]:
			_pk_button.add_theme_stylebox_override(st, sb)

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

func _setup_gm_buttons() -> void:
	_build_debug_button("★ GM ★", "Trung tâm điều hành Game Master (Phím F12)", _open_gm_window, true)
	_build_debug_button("Quái", "Danh sách quái VLTK — tạo quái để thử", _toggle_monster_popup)
	_build_debug_button("Skill", "Bảng tất cả skill theo phái — thi triển thử", _toggle_skill_popup)
	_build_debug_button("TEST", "Thử nhân vật: lên cấp, đồ, tiền, cộng chỉ số", _open_test_window)
	if GmManager != null and GmManager.has_signal("profile_modified"):
		GmManager.connect("profile_modified", func(target_profile: PlayerProfile) -> void:
			if target_profile == null or target_profile == GameManager.local_profile:
				_on_panel_profile_changed()
				if is_instance_valid(_inventory_window) and _inventory_window.has_method("refresh"):
					_inventory_window.refresh()
		)

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

	var pubg_cls = load("res://systems/pubg/pubg_manager.gd")
	if pubg_cls and pubg_cls.is_active:
		pubg_cls.end_match(GameManager.local_profile)

	if GameManager.local_profile != null:

		if AccountApi.is_gm():

			## GM: lưu toàn bộ tiến trình khi thoát trận

			SaveManager.save_profile(GameManager.local_profile)

		else:

			## Người thường: KHÔNG lưu bản thoát giữa trận — khôi phục về trạng thái trước trận

			SaveManager.restore_profile_from_save()

		await SaveManager.flush_online()

	if GameManager != null and GameManager.is_training_stage() and not GameModeManager.is_offline():
		GameManager.record_training_exit()

	if tree != null:

		var transition: Node = tree.root.get_node_or_null("SceneTransition") if tree.root != null else null
		if transition != null and transition.has_method("change_scene"):
			transition.change_scene(HUB_SCENE_PATH, "Về Thành Dưỡng Sức")
		else:
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

func _setup_pet_companion() -> void:
	var farm_mgr = get_node_or_null("/root/FarmManager")
	if farm_mgr == null:
		return
	var companion_info: Dictionary = farm_mgr.active_companion
	if companion_info.is_empty():
		return

	var pet_script: GDScript = load("res://systems/son_trang/pet_companion.gd")
	if pet_script == null:
		return

	var pet = pet_script.new(companion_info)
	pet.name = "ActivePetCompanion"
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		pet.target_player = player
		pet.global_position = player.global_position + Vector2(-35, 20)

	if VltkWorld.current != null:
		VltkWorld.current.add_child(pet)
	else:
		add_child(pet)

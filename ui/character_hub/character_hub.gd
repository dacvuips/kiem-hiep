extends Control
class_name CharacterHubScreen
## Sảnh chính "Nhân Vật" — Bảng thông tin nhân vật, kinh nghiệm, thuộc tính chiến đấu,
## trang bị, PK / Vượt Ải và hệ thống 9 danh mục menu phải.
## Thiết kế chuẩn 100% theo Ảnh 1, các khung tạo bằng CSS (StyleBoxFlat) tái sử dụng cao.

const SELECT_SCENE_PATH := "res://ui/character_select/CharacterSelect.tscn"
const ROSTER_SCENE_PATH := "res://ui/character_roster/CharacterRoster.tscn"
const GAME_SCENE_PATH := "res://Main.tscn"
const FADE_DURATION := 0.3

const COLOR_GOLD := Color("f0d08a")
const COLOR_CREAM := Color("eadcc0")
const COLOR_OUTLINE := Color("120c06")
const COLOR_POTENTIAL := Color(0.95, 0.25, 0.2)

const NAV_ITEMS := [
	["equipment", "Trang Bị"],
	["skills", "Kỹ Năng"],
	["events", "Sự Kiện"],
	["guild", "Bang Hội"],
	["social", "Giao Dịch"],
	["crafting", "Chế Tạo"],
	["ranking", "BXH"],
	["settings", "Cài Đặt"],
]

const SLOT_TO_PART := {
	"SlotLeft0": Equipment.Part.MASK,
	"SlotLeft1": Equipment.Part.CUFF,
	"SlotLeft2": Equipment.Part.RING1,
	"SlotLeft3": Equipment.Part.RING2,
	"SlotLeft4": Equipment.Part.PENDANT,
	"SlotLeft5": Equipment.Part.MANTLE,
	"SlotRight1": Equipment.Part.AMULET,
	"SlotRight2": Equipment.Part.WEAPON,
	"SlotRight3": Equipment.Part.FOOT,
	"SlotHead": Equipment.Part.HEAD,
	"SlotBody": Equipment.Part.BODY,
	"SlotBelt": Equipment.Part.BELT,
	"SlotHorse": Equipment.Part.HORSE,
}

const SkillBookViewScript = preload("res://ui/character_hub/skill_book_view.gd")
const TouchScrollHelperScript = preload("res://ui/common/touch_scroll_helper.gd")

const TEX_EQUIP_BG_MALE := preload("res://assets/ui/bo_icon_nhan_vat/trang_bi/trang_bi_nam.png")
const TEX_EQUIP_BG_FEMALE := preload("res://assets/ui/bo_icon_nhan_vat/trang_bi/trang_bi_nu.png")
const ICON_CHECK := preload("res://ui/login/icon_check.png")

@export var stages: Array[StageData] = [
	preload("res://stages/stage_01/stage_01.tres"),
	preload("res://stages/stage_02/stage_02.tres"),
	preload("res://stages/stage_03/stage_03.tres"),
	preload("res://stages/stage_04/stage_04.tres"),
	preload("res://stages/stage_05/stage_05.tres"),
	preload("res://stages/stage_06/stage_06.tres"),
	preload("res://stages/stage_07/stage_07.tres"),
	preload("res://stages/stage_08/stage_08.tres"),
	preload("res://stages/stage_09/stage_09.tres"),
	preload("res://stages/stage_10/stage_10.tres"),
	preload("res://stages/stage_11/stage_11.tres"),
	preload("res://stages/stage_12/stage_12.tres"),
]

var _profile: PlayerProfile
var _toast_tween: Tween
var _all_skills: Array[SkillDefinition] = []

var _room: ItemRoomView
var _current_bag: int = 0
var _current_view: String = "character"
var _events_view: EventScheduleWindow
var _skills_view: Control
var _guild_view: GuildWindow
var _market_view: MarketWindow
var _crafting_view: CompoundWindow
var _ranking_view: RankingWindow
var _settings_view: SettingsWindow
var _style_nav_active: StyleBox
var _style_nav_normal: StyleBox
var _style_tab_active: StyleBox
var _style_tab_normal: StyleBox
const PORTRAIT_TURN_SECONDS := 1.5
var _portrait_timer: Timer
var _disguise_banner: PanelContainer
var _disguise_label: Label
var _disguise_icon: TextureRect
var _hub_custom_avatar_view: TextureRect
var _hub_avatar_upload_box: PanelContainer
var _hub_avatar_delete_btn: Button

func _ready() -> void:
	MusicManager.stop(0.5)
	if PlayerStats.has_method("reset"):
		PlayerStats.reset()
	add_to_group("character_hub")
	if "--capture-screenshot" in OS.get_cmdline_args() or "--test-open-popup" in OS.get_cmdline_args() or "--test-open-inventory" in OS.get_cmdline_args() or "--test-open-skills" in OS.get_cmdline_args() or "--test-equipment-red" in OS.get_cmdline_args() or "--test-open-events" in OS.get_cmdline_args() or "--test-tutorial-welcome" in OS.get_cmdline_args() or "--test-tutorial-spotlight" in OS.get_cmdline_args() or "--test-tutorial-mode1" in OS.get_cmdline_args() or "--test-tutorial-mode2" in OS.get_cmdline_args():
		_create_mock_profile()
	else:
		_profile = GameManager.local_profile
		if _profile == null:
			_profile = SaveManager.load_profile()
			GameManager.local_profile = _profile
		if _profile == null:
			if OS.has_feature("editor") or OS.is_debug_build():
				_create_mock_profile()
			else:
				get_tree().change_scene_to_file.call_deferred(ROSTER_SCENE_PATH if AccountApi.is_logged_in() else SELECT_SCENE_PATH)
				return

	_all_skills = _load_all_skills()

	# Gán sự kiện nút
	if has_node("%BackButton"):
		%BackButton.pressed.connect(_on_back_pressed)
	if has_node("%CloseButton"):
		%CloseButton.pressed.connect(_on_back_pressed)
	%PlayButton.pressed.connect(func() -> void: PkWindow.open(self, _profile, _enter_field_map))
	%ChallengeButton.pressed.connect(func() -> void: MapSelectWindow.open(self, _profile, _enter_field_map))

	# Nút Kỳ Trân Các trên TopBar (thay thế ô thể lực cuối)
	if has_node("%KyTranCacTopButton"):
		%KyTranCacTopButton.pressed.connect(func() -> void:
			KyTranCacWindow.open(self, func() -> void:
				refresh()
				_refresh_inventory_view()
				_refresh_equipment_display()
			, _profile)
		)

	# Sự kiện nạp / mua thêm (Mở Tiền Trang & Kỳ Trân Các)
	%GoldPlusButton.pressed.connect(func() -> void:
		TienTrangWindow.open(self, func() -> void:
			refresh()
			_refresh_inventory_view()
		, _profile)
	)
	if has_node("%XuPlusButton"):
		%XuPlusButton.pressed.connect(func() -> void:
			KyTranCacWindow.open(self, func() -> void:
				refresh()
				_refresh_inventory_view()
			, _profile)
		)
	if has_node("%FrameCurrencyXu"):
		%FrameCurrencyXu.mouse_filter = Control.MOUSE_FILTER_STOP
		%FrameCurrencyXu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		%FrameCurrencyXu.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				KyTranCacWindow.open(self, func() -> void:
					refresh()
					_refresh_inventory_view()
				, _profile)
		)
	%JadePlusButton.pressed.connect(func() -> void:
		TienTrangWindow.open(self, func() -> void:
			refresh()
			_refresh_inventory_view()
		, _profile)
	)
	if has_node("%StaminaPlusButton"):
		%StaminaPlusButton.pressed.connect(_show_toast.bind("Hồi Thể Lực: đang phát triển"))

	# Nút cộng điểm tiềm năng
	%BaseStatButton0.pressed.connect(_add_stat.bind(0)) # Sức mạnh
	%BaseStatButton1.pressed.connect(_add_stat.bind(1)) # Thân pháp
	%BaseStatButton2.pressed.connect(_add_stat.bind(2)) # Sinh khí
	%BaseStatButton3.pressed.connect(_add_stat.bind(3)) # Nội công

	if has_node("%GmButton"):
		var is_gm := AccountApi.is_gm()
		%GmButton.visible = is_gm
		if is_gm:
			%GmButton.pressed.connect(_toggle_gm_window)
		else:
			%GmButton.queue_free()

	GmManager.profile_modified.connect(_on_gm_profile_modified)
	GmManager.gm_state_changed.connect(func() -> void:
		_refresh_portrait()
		_refresh_mask_check()
	)

	if has_node("%ChatButton"):
		%ChatButton.pressed.connect(func() -> void:
			ChatPanel.toggle(self)
		)

	if has_node("%SocialButton"):
		%SocialButton.pressed.connect(func() -> void:
			TelegramCommunityPopup.open(self)
		)

	if has_node("%GuideButton"):
		%GuideButton.pressed.connect(func() -> void:
			TutorialManager.start_explore_tutorial(self)
		)

	_style_nav_active = %CharacterButton.get_theme_stylebox("normal")
	_style_nav_normal = %NavButton1.get_theme_stylebox("normal")
	_style_tab_active = %BagTabs.get_child(0).get_theme_stylebox("normal")
	_style_tab_normal = %BagTabs.get_child(1).get_theme_stylebox("normal")

	_setup_inventory_view()
	_setup_equipment_slots()
	_setup_nav_buttons()
	_setup_portrait()
	_set_view("character")

	var stage := get_node_or_null("Stage") as Control
	if stage:
		if stage.has_signal("layout_adapted"):
			stage.layout_adapted.connect(_on_stage_layout_adapted)
		if get_viewport():
			get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout.call_deferred()

	refresh()
	_sync_world_rank.call_deferred()

	if LocalizationManager != null and LocalizationManager.has_signal("locale_changed"):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_retranslate_tree(self)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	_ask_sect_if_needed.call_deferred()

	HubSession.attach(self)

	for arg in (OS.get_cmdline_args() + OS.get_cmdline_user_args()):
		if arg == "--capture-screenshot":
			_capture_and_quit.call_deferred()
			break
		if arg == "--test-open-popup":
			_test_open_popup_and_quit.call_deferred()
			break
		if arg == "--test-open-inventory":
			_test_open_inventory_and_quit.call_deferred()
			break
		if arg == "--test-open-inv-popover":
			_test_open_inv_popover_and_quit.call_deferred()
			break
		if arg == "--test-open-skills":
			_test_open_skills_and_quit.call_deferred()
			break
		if arg == "--test-equipment-red":
			_test_equipment_red_and_quit.call_deferred()
			break
		if arg == "--test-open-crafting":
			_test_open_crafting_and_quit.call_deferred()
			break
		if arg == "--test-open-guild":
			_test_open_guild_and_quit.call_deferred()
			break
		if arg == "--test-open-events":
			_test_open_events_and_quit.call_deferred()
			break
		if arg == "--test-views":
			_test_all_views_and_quit.call_deferred()
			break
		if arg == "--test-open-chat":
			_test_open_chat_and_quit.call_deferred()
			break
		if arg == "--test-open-social":
			_test_open_social_and_quit.call_deferred()
			break
		if arg == "--test-tutorial-welcome":
			_test_tutorial_welcome_and_quit.call_deferred()
			break
		if arg == "--test-tutorial-spotlight" or arg == "--test-tutorial-mode1":
			_test_tutorial_spotlight_and_quit.call_deferred()
			break
		if arg == "--test-tutorial-mode2":
			_test_tutorial_mode2_and_quit.call_deferred()
			break

	# Chức năng Introduce / Hướng dẫn tân thủ khi người dùng vào game
	if TutorialManager.should_show_intro():
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if is_inside_tree() and TutorialManager.should_show_intro():
				TutorialManager.start_initial_tutorial(self)
		)

func _test_tutorial_welcome_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	TutorialManager.start_explore_tutorial(self)
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/00e47e0c-5398-4269-a7db-2fbd05431d77/tutorial_mode2_step1.png")
		print("TUTORIAL_MODE2_STEP1_CAPTURE_SUCCESS")
	get_tree().quit()

func _test_tutorial_spotlight_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	TutorialManager.start_initial_tutorial(self) # Dạng 1: Đầu game
	await get_tree().create_timer(0.8).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/00e47e0c-5398-4269-a7db-2fbd05431d77/tutorial_mode1_step1.png")
		print("TUTORIAL_MODE1_STEP1_CAPTURE_SUCCESS")
	
	# Thử nghiệm click vào vùng sáng để tự động chuyển sang Bước 2 (Trang Bị)
	if is_instance_valid(TutorialManager._active_overlay):
		TutorialManager._active_overlay._handle_target_click()
	await get_tree().create_timer(0.8).timeout
	var img2 := get_viewport().get_texture().get_image()
	if img2:
		img2.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/00e47e0c-5398-4269-a7db-2fbd05431d77/tutorial_mode1_step2.png")
		print("TUTORIAL_MODE1_STEP2_CAPTURE_SUCCESS")

	get_tree().quit()

func _test_tutorial_mode2_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	TutorialManager.start_explore_tutorial(self) # Dạng 2: Khám phá toàn bộ nút
	await get_tree().create_timer(0.8).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/00e47e0c-5398-4269-a7db-2fbd05431d77/tutorial_mode2_tour_step1.png")
		print("TUTORIAL_MODE2_STEP1_CAPTURE_SUCCESS")

	# Test bấm nút Next
	if is_instance_valid(TutorialManager._active_overlay):
		TutorialManager._active_overlay._on_next_step_pressed()
	await get_tree().create_timer(0.8).timeout
	var img2 := get_viewport().get_texture().get_image()
	if img2:
		img2.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/00e47e0c-5398-4269-a7db-2fbd05431d77/tutorial_mode2_tour_step2.png")
		print("TUTORIAL_MODE2_STEP2_CAPTURE_SUCCESS")

	# Test bấm tiếp để xem 1 nút khác (nút Kỹ Năng)
	if is_instance_valid(TutorialManager._active_overlay):
		TutorialManager._active_overlay._on_next_step_pressed() # sang step 3: CharacterButton
		TutorialManager._active_overlay._on_next_step_pressed() # sang step 4: NavButton0
		TutorialManager._active_overlay._on_next_step_pressed() # sang step 5: NavButton1
	await get_tree().create_timer(0.8).timeout
	var img3 := get_viewport().get_texture().get_image()
	if img3:
		img3.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/00e47e0c-5398-4269-a7db-2fbd05431d77/tutorial_mode2_tour_skills.png")
		print("TUTORIAL_MODE2_SKILLS_CAPTURE_SUCCESS")

	get_tree().quit()

func _test_open_social_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	TelegramCommunityPopup.open(self)
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://telegram_popup_rendered.png")
		print("SOCIAL_POPUP_SUCCESS")
	get_tree().quit()

func _test_open_chat_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	var panel := ChatPanel.open(self)
	await get_tree().create_timer(0.4).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/d6888eb9-bf62-47ed-a3a2-f742759dfa21/chat_slideout_world.png")

	panel.set_channel(ChatServer.PRIVATE, "ĐộcCôCầuBại")
	panel._input.text = "Huynh đệ, tối nay cùng đi Tống Kim nhé!"
	panel._send()
	await get_tree().create_timer(0.4).timeout
	var img2 := get_viewport().get_texture().get_image()
	if img2:
		img2.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/d6888eb9-bf62-47ed-a3a2-f742759dfa21/chat_slideout_private.png")
		print("CHAT_SLIDEOUT_SUCCESS")
	get_tree().quit()

func _test_open_events_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	_set_view("events")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func _test_open_guild_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	_set_view("guild")
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/559e8e6c-9764-4a53-b7ce-0cbbb23fca67/guild_view_rendered.png")
		print("GUILD_CAPTURE_SUCCESS")
	get_tree().quit()

func _test_open_crafting_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	_set_view("crafting")
	await get_tree().create_timer(0.5).timeout
	var art_dir := "C:/Users/Hieu Tran/.gemini/antigravity/brain/df8b09dc-a236-4d3a-b238-b41d8124b85f"
	if _crafting_view:
		for tab_idx in 5:
			_crafting_view._switch_tab(tab_idx)
			await get_tree().create_timer(0.3).timeout
			var img := get_viewport().get_texture().get_image()
			if img:
				img.save_png("%s/crafting_tab_%d.png" % [art_dir, tab_idx])
		# Also capture overall view on tab 1 (Lấy)
		_crafting_view._switch_tab(1)
		await get_tree().create_timer(0.3).timeout
		var img_main := get_viewport().get_texture().get_image()
		if img_main:
			img_main.save_png("%s/crafting_view_rendered.png" % art_dir)
			print("CRAFTING_ALL_TABS_CAPTURE_SUCCESS")
	get_tree().quit()

func _test_open_skills_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	_set_view("skills")
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/df8b09dc-a236-4d3a-b238-b41d8124b85f/skills_view_rendered.png")
		print("SKILLS_CAPTURE_SUCCESS")
	get_tree().quit()

func _test_all_views_and_quit() -> void:
	var art_dir := "C:/Users/Hieu Tran/.gemini/antigravity/brain/0dce5cdf-eaa7-4ea2-90f8-52b8023e74b5"
	_profile.strength = 500
	_profile.dexterity = 500
	for idx in range(mini(20, _profile.inventory.size()) - 1, -1, -1):
		_equip_item_from_inv(idx)
	var gold_item := ItemGenerator.generate_gold(0)
	if gold_item:
		_profile.equipment[Equipment.Part.HEAD] = gold_item
	var purple_armor := ItemGenerator.random_equipment(60)
	if purple_armor:
		purple_armor.quality = ItemInstance.QUALITY_PURPLE
		_profile.equipment[Equipment.Part.BODY] = purple_armor
	var gold_belt := ItemGenerator.generate_gold(1)
	if gold_belt:
		_profile.equipment[Equipment.Part.BELT] = gold_belt
	await get_tree().create_timer(0.3).timeout
	var views := ["skills", "guild", "social", "crafting", "ranking", "settings", "character"]
	for v in views:
		_set_view(v)
		await get_tree().create_timer(0.4).timeout
		var img := get_viewport().get_texture().get_image()
		if img:
			img.save_png("%s/view_%s.png" % [art_dir, v])
			print("CAPTURED_%s" % v.to_upper())
	get_tree().quit()

func _test_open_inventory_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	_set_view("equipment")
	await get_tree().create_timer(0.4).timeout
	_profile.strength = 500
	_profile.dexterity = 500
	for idx in range(mini(6, _profile.inventory.size()) - 1, -1, -1):
		_equip_item_from_inv(idx)
	await get_tree().create_timer(0.5).timeout
	if %ToastLabel:
		%ToastLabel.visible = false
	var inv_box: Control = %InventoryView.get_node("InvBox")
	var equip_box: Control = %CenterPanel.get_node("EquipBox")
	print("VERIFY_HEIGHTS: inv_box pos=", inv_box.global_position, " size=", inv_box.size, " | equip_box pos=", equip_box.global_position, " size=", equip_box.size)
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/df8b09dc-a236-4d3a-b238-b41d8124b85f/character_hub_inventory_rendered.png")
		print("INVENTORY_CAPTURE_SUCCESS")
	get_tree().quit()

func _test_open_inv_popover_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	_set_view("equipment")
	await get_tree().create_timer(0.4).timeout
	if not _profile.inventory.is_empty():
		_on_room_item_pressed(_profile.inventory[0])
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/e7181ab1-2eee-4037-a34b-915ce2905884/character_hub_popover_rendered.png")
		print("POPOVER_CAPTURE_SUCCESS")
	get_tree().quit()

func _test_open_popup_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	%BaseStatButton0.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/e7181ab1-2eee-4037-a34b-915ce2905884/character_hub_popup_rendered.png")
		print("POPUP_CAPTURE_SUCCESS")
	get_tree().quit()

func _capture_and_quit() -> void:
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/71930568-ecf3-412d-924b-1c1d4144f4a7/character_hub_rendered.png")
		print("CAPTURE_SUCCESS")
	get_tree().quit()

func _test_equipment_red_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	_profile.level = 100
	_profile.strength = 500
	_profile.dexterity = 500
	_profile.vitality = 500
	_profile.energy = 500
	_set_view("equipment")
	await get_tree().create_timer(0.4).timeout

	# Trang bị các món đúng loại: Hoàng kim, Đồ tím, Đồ thường
	var gold_helm := ItemGenerator.generate_gold(0)
	if gold_helm:
		_profile.equipment[Equipment.Part.HEAD] = gold_helm

	var purple_body := ItemGenerator.generate(ItemDatabase.Detail.ARMOR, 0, 5, 0, [5, 5])
	if purple_body:
		purple_body.quality = ItemInstance.QUALITY_PURPLE
		_profile.equipment[Equipment.Part.BODY] = purple_body

	var normal_belt := ItemGenerator.generate(ItemDatabase.Detail.BELT, 0, 5, 0, [5, 5])
	if normal_belt:
		_profile.equipment[Equipment.Part.BELT] = normal_belt

	var purple_foot := ItemGenerator.generate(ItemDatabase.Detail.BOOT, 0, 5, 0, [5, 5])
	if purple_foot:
		purple_foot.quality = ItemInstance.QUALITY_PURPLE
		_profile.equipment[Equipment.Part.FOOT] = purple_foot

	var normal_weap := ItemGenerator.generate(ItemDatabase.Detail.MELEE, 0, 5, 0, [5, 5])
	if normal_weap:
		_profile.equipment[Equipment.Part.WEAPON] = normal_weap

	var normal_ring := ItemGenerator.generate(ItemDatabase.Detail.RING, 0, 5, 0, [5, 5])
	if normal_ring:
		_profile.equipment[Equipment.Part.RING1] = normal_ring

	var purple_cuff := ItemGenerator.generate(ItemDatabase.Detail.CUFF, 0, 5, 0, [5, 5])
	if purple_cuff:
		purple_cuff.quality = ItemInstance.QUALITY_PURPLE
		_profile.equipment[Equipment.Part.CUFF] = purple_cuff

	var gold_pendant := ItemGenerator.generate_gold(2)
	if gold_pendant:
		_profile.equipment[Equipment.Part.PENDANT] = gold_pendant

	var normal_horse := ItemGenerator.generate(ItemDatabase.Detail.HORSE, 0, 1, 0, [])
	if normal_horse:
		_profile.equipment[Equipment.Part.HORSE] = normal_horse

	var normal_amulet := ItemGenerator.generate(ItemDatabase.Detail.AMULET, 0, 5, 0, [5, 5])
	if normal_amulet:
		_profile.equipment[Equipment.Part.AMULET] = normal_amulet

	var sample_mask := ItemGenerator.generate(ItemDatabase.Detail.MASK, 0, 1, 0, [])
	if sample_mask:
		_profile.equipment[Equipment.Part.MASK] = sample_mask

	var sample_mantle := ItemGenerator.generate(ItemDatabase.Detail.MANTLE, 0, 5, 0, [])
	if sample_mantle:
		_profile.equipment[Equipment.Part.MANTLE] = sample_mantle

	# 1. Chụp ảnh Nam
	_profile.gender = PlayerProfile.Gender.MALE
	_refresh_equipment_display()
	_refresh_inventory_view()
	await get_tree().create_timer(0.6).timeout
	var img_male := get_viewport().get_texture().get_image()
	if img_male:
		img_male.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/5fbd93d4-c6cf-49b3-9068-e209de66311c/male_equip_captured.png")
		print("MALE_EQUIP_CAPTURE_SUCCESS")

	# 2. Chụp ảnh Nữ
	_profile.gender = PlayerProfile.Gender.FEMALE
	_refresh_equipment_display()
	_refresh_inventory_view()
	await get_tree().create_timer(0.6).timeout
	var img_female := get_viewport().get_texture().get_image()
	if img_female:
		img_female.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/5fbd93d4-c6cf-49b3-9068-e209de66311c/female_equip_captured.png")
		print("FEMALE_EQUIP_CAPTURE_SUCCESS")

	get_tree().quit()

## Tạo hồ sơ mẫu khi chạy F6 test trực tiếp
func _create_mock_profile() -> void:
	_profile = PlayerProfile.new()
	_profile.display_name = "HoaHieu"
	_profile.title = ""
	_profile.fuyuan = 0
	_profile.prestige = 0
	_profile.level = 200
	_profile.world_rank = ""
	_profile.gold = 998800
	_profile.jade = 0
	_profile.stamina = 1918
	_profile.max_stamina = 1918
	_profile.potential_points = 1010
	_profile.strength = 30
	_profile.dexterity = 20
	_profile.vitality = 30
	_profile.energy = 20
	_profile.current_exp = 62
	_profile.sect_id = "cai_bang"
	if _profile.inventory.is_empty():
		for i in 12:
			var it: ItemInstance = ItemGenerator.random_equipment(_profile.level)
			if it:
				_profile.add_item(it)
	GameManager.local_profile = _profile
	SaveManager.save_profile(_profile)

func _on_gm_profile_modified(target_profile: PlayerProfile) -> void:
	if target_profile == null or target_profile == _profile or target_profile == GameManager.local_profile:
		_profile = GameManager.local_profile
		refresh()
		_refresh_inventory_view()
		_refresh_equipment_display()
		_refresh_pk_label()
		_refresh_portrait()
		_refresh_mask_check()
		if _skills_view and is_instance_valid(_skills_view) and _skills_view.visible:
			_skills_view._profile = _profile
			if _skills_view.has_method("_refresh"):
				_skills_view._refresh()
		if _market_view and is_instance_valid(_market_view) and _market_view.visible:
			if _market_view.has_method("_refresh_money"):
				_market_view._refresh_money()

func refresh() -> void:
	if _profile == null or not is_inside_tree() or not has_node("%GoldValueLabel"):
		return

	# Thanh tiền tệ top
	%GoldValueLabel.text = _format_number(_profile.gold)
	if has_node("%XuValueLabel"):
		%XuValueLabel.text = _format_number(_profile.xu)
	%JadeValueLabel.text = _format_number(_profile.jade if _profile.jade > 0 else 0)
	if has_node("%StaminaValueLabel"):
		%StaminaValueLabel.text = "%d/%d" % [_profile.stamina, _profile.max_stamina]

	# Thông tin nhân vật
	%NameValue.text = _profile.display_name
	%TitleValue.text = _profile.title if not _profile.title.is_empty() else "—"
	%FuyuanValue.text = str(_profile.fuyuan)
	%PrestigeValue.text = str(_profile.prestige)
	%LevelValue.text = str(_profile.level)
	%RankValue.text = _profile.world_rank if not _profile.world_rank.is_empty() else "—"

	var s := _profile.get_combat_stats()
	var max_hp: int = s.max_hp if s.max_hp > 0 else 859
	var max_mp: int = s.max_mana if s.max_mana > 0 else 250
	var cur_hp: int = max_hp
	var cur_mp: int = max_mp
	var max_stam: int = _profile.max_stamina if _profile.max_stamina > 0 else 1918
	var cur_stam: int = _profile.stamina

	%LifeValue.text = "%d/%d" % [cur_hp, max_hp]
	if %HpBar is ProgressBar:
		%HpBar.max_value = 100.0
		%HpBar.value = (float(cur_hp) / float(maxi(max_hp, 1))) * 100.0

	%ManaValue.text = "%d/%d" % [cur_mp, max_mp]
	if %MpBar is ProgressBar:
		%MpBar.max_value = 100.0
		%MpBar.value = (float(cur_mp) / float(maxi(max_mp, 1))) * 100.0

	%StaminaValue.text = "%d/%d" % [cur_stam, max_stam]
	if %StaminaBar is ProgressBar:
		%StaminaBar.max_value = 100.0
		%StaminaBar.value = (float(cur_stam) / float(maxi(max_stam, 1))) * 100.0

	var elem_name := "Vô Hệ"
	if _profile.sect_id != "":
		elem_name = ElementTypes.ELEMENT_NAME.get(_sect_element(), "Hỏa")
	elif _profile.has_method("get_element"):
		elem_name = ElementTypes.ELEMENT_NAME.get(_profile.get_element(), "Vô Hệ")
	%ElementValue.text = elem_name

	if has_node("%LeadValue"):
		var next_lead_exp := SocialRules.lead_exp_to_next(_profile.lead_level)
		if next_lead_exp > 0:
			%LeadValue.text = "Cấp %d (%s/%s)" % [_profile.lead_level, _format_number(_profile.lead_exp), _format_number(next_lead_exp)]
		else:
			%LeadValue.text = "Cấp %d (Tối đa)" % _profile.lead_level
	if has_node("%LeadRow"):
		var cap := SocialRules.team_size(_profile.lead_level)
		var next_exp_str := _format_number(SocialRules.lead_exp_to_next(_profile.lead_level)) if SocialRules.lead_exp_to_next(_profile.lead_level) > 0 else "Tối đa"
		(%LeadRow as Control).tooltip_text = "Cấp Lãnh Đạo: %d\nKinh nghiệm: %s / %s\nSố thành viên tổ đội tối đa: %d người" % [
			_profile.lead_level,
			_format_number(_profile.lead_exp),
			next_exp_str,
			cap
		]

	# Kinh nghiệm
	var max_e: int = _profile.get_exp_to_next_level() if _profile.get_exp_to_next_level() > 0 else 15200
	%ExpValue.text = "%s/%s" % [_format_number(_profile.current_exp), _format_number(max_e)]
	if %ExpBar is ProgressBar:
		%ExpBar.max_value = 100.0
		%ExpBar.value = (float(_profile.current_exp) / float(maxi(max_e, 1))) * 100.0

	# 4 chỉ số cơ bản
	%BaseStatValue0.text = str(_profile.strength)
	%BaseStatValue1.text = str(_profile.dexterity)
	%BaseStatValue2.text = str(_profile.vitality)
	%BaseStatValue3.text = str(_profile.energy)

	var has_pts: bool = _profile.potential_points > 0
	%BaseStatButton0.disabled = not has_pts
	%BaseStatButton1.disabled = not has_pts
	%BaseStatButton2.disabled = not has_pts
	%BaseStatButton3.disabled = not has_pts

	# Thuộc tính chiến đấu
	var min_dmg: int = s.unarmed_min_damage if s.unarmed_min_damage > 0 else 6
	var max_dmg: int = s.unarmed_max_damage if s.unarmed_max_damage > 0 else 6
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	var left_info := SectSkillController.get_left_hand_info(_profile, player)
	var left_damage: Vector2i = left_info.damage
	var left_uses_ar: bool = left_info.use_ar
	%DamageLeftValue.text = "%d/%d" % [left_damage.x, left_damage.y]
	%DamageRightValue.text = "%d/%d" % [min_dmg, max_dmg]
	%ChinhXacValue.text = "%s/%d" % [str(s.attack_rating) if left_uses_ar else "-", s.attack_rating if s.attack_rating > 0 else 52]
	%NeTranhValue.text = str(s.defense if s.defense != 0 else -20)
	%ChayValue.text = "10"
	%CongKichValue.text = "%d/%d" % [s.attack_speed, s.cast_speed]
	%TiemNangValue.text = str(_profile.potential_points)
	%DefenseValue.text = "%d%%" % s.get_capped_resist(CombatFormulas.DamageType.PHYSICS)
	%ResistValue0.text = "%d%%" % s.get_capped_resist(CombatFormulas.DamageType.PHYSICS)
	%ResistValue1.text = "%d%%" % s.get_capped_resist(CombatFormulas.DamageType.COLD)
	%ResistValue2.text = "%d%%" % s.get_capped_resist(CombatFormulas.DamageType.LIGHT)
	%ResistValue3.text = "%d%%" % s.get_capped_resist(CombatFormulas.DamageType.FIRE)
	%ResistValue4.text = "%d%%" % s.get_capped_resist(CombatFormulas.DamageType.POISON)

	# Cập nhật hiển thị trang bị đang mặc trên hình nhân vật
	_refresh_equipment_display()
	_refresh_portrait()

	if has_node("%SecurityButton"):
		var sec_btn: Button = %SecurityButton
		if not SecurityLock.has_password(_profile):
			sec_btn.text = "Đặt Khóa"
		elif SecurityLock.is_locked(_profile):
			sec_btn.text = "🔒 Mở Khóa"
		else:
			sec_btn.text = "🔓 Đang Mở"

func _sync_world_rank() -> void:
	if _profile == null:
		return
	var rank_str := await RankingWindow.fetch_my_rank(_profile)
	if not rank_str.is_empty() and rank_str != "—":
		_profile.world_rank = rank_str
		if has_node("%RankValue"):
			%RankValue.text = _profile.world_rank

func _setup_portrait() -> void:
	if not has_node("%PortraitBox"):
		return
	var box: Control = %PortraitBox
	box.clip_contents = true
	box.resized.connect(_place_portrait)

	if _hub_custom_avatar_view == null:
		_hub_custom_avatar_view = TextureRect.new()
		_hub_custom_avatar_view.name = "CustomAvatarView"
		_hub_custom_avatar_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_hub_custom_avatar_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hub_custom_avatar_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hub_custom_avatar_view.mouse_filter = Control.MOUSE_FILTER_STOP
		_hub_custom_avatar_view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_hub_custom_avatar_view.tooltip_text = "Nhấp để đổi ảnh đại diện (200×200)"
		_hub_custom_avatar_view.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_open_avatar_uploader()
		)
		box.add_child(_hub_custom_avatar_view)

	if _hub_avatar_upload_box == null:
		_hub_avatar_upload_box = PanelContainer.new()
		_hub_avatar_upload_box.name = "AvatarUploadBox"
		_hub_avatar_upload_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_hub_avatar_upload_box.mouse_filter = Control.MOUSE_FILTER_STOP
		_hub_avatar_upload_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.08, 0.12, 0.85)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.35, 0.6, 0.85, 0.7)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		_hub_avatar_upload_box.add_theme_stylebox_override("panel", sb)

		var v_box := VBoxContainer.new()
		v_box.alignment = BoxContainer.ALIGNMENT_CENTER
		v_box.add_theme_constant_override("separation", 4)
		_hub_avatar_upload_box.add_child(v_box)

		var cam_icon := Label.new()
		cam_icon.text = "📷"
		cam_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cam_icon.add_theme_font_size_override("font_size", 22)
		v_box.add_child(cam_icon)

		var upload_lbl := Label.new()
		upload_lbl.text = "Tải ảnh lên"
		upload_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upload_lbl.add_theme_font_size_override("font_size", 13)
		upload_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		v_box.add_child(upload_lbl)

		var size_hint := Label.new()
		size_hint.text = "200×200 px"
		size_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		size_hint.add_theme_font_size_override("font_size", 10)
		size_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		v_box.add_child(size_hint)

		_hub_avatar_upload_box.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_open_avatar_uploader()
		)
		box.add_child(_hub_avatar_upload_box)

	if _hub_avatar_delete_btn == null:
		_hub_avatar_delete_btn = Button.new()
		_hub_avatar_delete_btn.name = "AvatarDeleteBtn"
		_hub_avatar_delete_btn.text = "✕"
		_hub_avatar_delete_btn.custom_minimum_size = Vector2(22, 22)
		_hub_avatar_delete_btn.size = Vector2(22, 22)
		_hub_avatar_delete_btn.tooltip_text = "Xóa ảnh đại diện"
		_hub_avatar_delete_btn.focus_mode = Control.FOCUS_NONE
		_hub_avatar_delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var b_style := StyleBoxFlat.new()
		b_style.bg_color = Color(0.75, 0.15, 0.15, 0.85)
		b_style.border_width_left = 1
		b_style.border_width_top = 1
		b_style.border_width_right = 1
		b_style.border_width_bottom = 1
		b_style.border_color = Color(1.0, 0.4, 0.4, 0.9)
		b_style.corner_radius_top_left = 11
		b_style.corner_radius_top_right = 11
		b_style.corner_radius_bottom_left = 11
		b_style.corner_radius_bottom_right = 11
		_hub_avatar_delete_btn.add_theme_stylebox_override("normal", b_style)
		_hub_avatar_delete_btn.add_theme_color_override("font_color", Color.WHITE)
		_hub_avatar_delete_btn.add_theme_font_size_override("font_size", 11)

		_hub_avatar_delete_btn.pressed.connect(_on_delete_avatar_pressed)
		box.add_child(_hub_avatar_delete_btn)

	_place_portrait()

func _open_avatar_uploader() -> void:
	CustomAvatarHelper.pick_image_file(self, func(img: Image) -> void:
		if img == null:
			return
		AvatarCropPopup.open(self, img, func(jpg_bytes: PackedByteArray) -> void:
			if jpg_bytes.is_empty():
				return
			if _profile:
				_profile.set_custom_avatar_from_jpg(jpg_bytes)
				CustomAvatarHelper.save_avatar_cache(_profile.display_name, SaveManager.online_character_id, jpg_bytes)
				SaveManager.save_profile(_profile)
				SaveManager.flush_online()
			if _hub_custom_avatar_view:
				var res_img := CustomAvatarHelper.load_image_from_bytes(jpg_bytes)
				if res_img:
					_hub_custom_avatar_view.texture = ImageTexture.create_from_image(res_img)
			_refresh_portrait()
			_show_toast("Đã cập nhật ảnh đại diện thành công!")
		)
	)

func _on_delete_avatar_pressed() -> void:
	SocialWindow.ask_yes_no(self, "Xóa Ảnh Đại Diện", "Bạn có chắc chắn muốn xóa ảnh đại diện này không?", func(yes: bool) -> void:
		if yes:
			if _profile:
				_profile.clear_custom_avatar()
				CustomAvatarHelper.delete_avatar_cache(_profile.display_name, SaveManager.online_character_id)
				SaveManager.save_profile(_profile)
				SaveManager.flush_online()
			_refresh_portrait()
			_show_toast("Đã xóa ảnh đại diện!")
	)

func _place_portrait() -> void:
	if not has_node("%PortraitBox"):
		return
	var box: Control = %PortraitBox
	if has_node("%PortraitAvatar"):
		var avatar: Node2D = %PortraitAvatar
		avatar.scale = Vector2(1.4, 1.4)
		avatar.position = Vector2(box.size.x * 0.5, box.size.y - 6.0)
	if _disguise_icon:
		_disguise_icon.position = Vector2(box.size.x - 24.0, 4.0)
	if _hub_avatar_delete_btn:
		_hub_avatar_delete_btn.position = Vector2(box.size.x - 26.0, 4.0)

func _turn_portrait() -> void:
	if not has_node("%PortraitAvatar"):
		return
	var avatar: CharacterAvatar = %PortraitAvatar
	avatar.face(Vector2.DOWN.rotated(deg_to_rad(45.0 * ((avatar.direction + 1) % 8))))

func _setup_disguise_ui() -> void:
	if not has_node("%PortraitBox"):
		return
	var box: Control = %PortraitBox
	if _disguise_banner == null:
		_disguise_banner = PanelContainer.new()
		_disguise_banner.name = "DisguiseBanner"
		_disguise_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disguise_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_disguise_banner.offset_top = -24.0
		_disguise_banner.offset_bottom = 0.0
		_disguise_banner.offset_left = 2.0
		_disguise_banner.offset_right = -2.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.04, 0.08, 0.92)
		sb.border_width_top = 1
		sb.border_color = Color(0.85, 0.7, 0.25, 0.9)
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		_disguise_banner.add_theme_stylebox_override("panel", sb)

		_disguise_label = Label.new()
		_disguise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_disguise_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_disguise_label.add_theme_font_size_override("font_size", 11)
		_disguise_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
		_disguise_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_disguise_label.add_theme_constant_override("outline_size", 3)
		_disguise_banner.add_child(_disguise_label)
		box.add_child(_disguise_banner)

	if _disguise_icon == null:
		_disguise_icon = TextureRect.new()
		_disguise_icon.name = "DisguiseIcon"
		_disguise_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_disguise_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_disguise_icon.custom_minimum_size = Vector2(20, 20)
		_disguise_icon.size = Vector2(20, 20)
		_disguise_icon.position = Vector2(box.size.x - 24.0, 4.0)
		box.add_child(_disguise_icon)

func _refresh_portrait() -> void:
	if not has_node("%PortraitBox") or _profile == null:
		return
	if _hub_avatar_upload_box == null:
		_setup_portrait()
	_setup_disguise_ui()

	# Luôn ẩn mannequin nhân vật/ngựa để dành trọn vẹn ô cho Avatar / Tải ảnh lên
	if has_node("%PortraitAvatar"):
		(%PortraitAvatar as Node2D).visible = false
	if _portrait_timer and not _portrait_timer.is_stopped():
		_portrait_timer.stop()

	if not _profile.has_custom_avatar() and _profile.display_name != "":
		var cached := CustomAvatarHelper.get_avatar_base64_cache(_profile.display_name, SaveManager.online_character_id)
		if cached != "":
			_profile.custom_avatar = cached

	var has_custom: bool = _profile.has_custom_avatar()
	if has_custom:
		var tex: ImageTexture = _profile.get_custom_avatar_texture()
		if tex and _hub_custom_avatar_view:
			_hub_custom_avatar_view.texture = tex
			_hub_custom_avatar_view.visible = true
			if _hub_avatar_upload_box:
				_hub_avatar_upload_box.visible = false
			if _hub_avatar_delete_btn:
				_hub_avatar_delete_btn.visible = true
				_hub_avatar_delete_btn.move_to_front()
	else:
		# Chưa có avatar: Hiển thị ô "Tải ảnh lên" 📷
		if _hub_custom_avatar_view:
			_hub_custom_avatar_view.visible = false
		if _hub_avatar_upload_box:
			_hub_avatar_upload_box.visible = true
			_hub_avatar_upload_box.move_to_front()
		if _hub_avatar_delete_btn:
			_hub_avatar_delete_btn.visible = false

	# Cập nhật hiển thị dịch dung (nếu có mặt nạ)
	var gender_str := "female" if _profile.gender == PlayerProfile.Gender.FEMALE else "male"
	var look := Equipment.get_appearance(_profile.equipment, gender_str, _profile.riding, _profile.show_mask)
	var is_masked: bool = bool(look.get("is_masked", false))
	if _disguise_banner:
		_disguise_banner.visible = is_masked
		if is_masked:
			_disguise_label.text = "🎭 %s" % str(look.get("disguise_title", "Dịch Dung"))
			_disguise_banner.move_to_front()
	if _disguise_icon:
		_disguise_icon.visible = is_masked
		if is_masked:
			_disguise_icon.texture = look.get("mask_icon")
			_disguise_icon.tooltip_text = "Đang dịch dung: %s" % str(look.get("mask_name", ""))
			_disguise_icon.move_to_front()

func _sect_element() -> ElementTypes.ElementType:
	var sect := SectRegistry.get_by_id(_profile.sect_id)
	return sect.element if sect else ElementTypes.ElementType.HOA

func _add_stat(idx: int) -> void:
	if _profile == null or _profile.potential_points <= 0:
		_show_toast("Không còn điểm tiềm năng", true)
		return
	PotentialPointPopup.open(self, _profile, idx, func(added: int) -> void:
		if added > 0:
			SaveManager.save_profile(_profile)
			SaveManager.flush_online()
			refresh()
	)

func _setup_inventory_view() -> void:
	if %InvGrid:
		%InvGrid.queue_free()
	if _room == null:
		_room = ItemRoomView.new()
		_room.cell = 37
		_room.item_pressed.connect(_on_room_item_pressed)
		_room.changed.connect(func() -> void:
			SaveManager.save_profile(_profile)
			SaveManager.flush_online()
			refresh()
			_refresh_inventory_view()
		)
		_room.transfer_handler = func(item: ItemInstance, source: Variant, _target: Object, x: int, y: int, bag: int) -> bool:
			if (source is Object) and source == _profile.storage:
				return StorageService.transfer(_profile, item, source, _profile, x, y, bag)
			if str(source) == "mannequin":
				var part: int = -1
				for p in _profile.equipment:
					if _profile.equipment[p] == item:
						part = p
						break
				if part >= 0:
					if _profile.can_place(item, x, y, bag, _profile.get_room_height(bag)):
						item.room_x = x
						item.room_y = y
						item.room_bag = bag
						_profile.inventory.append(item)
						_profile.equipment.erase(part)
						if part == Equipment.Part.HORSE:
							_profile.riding = false
						return true
			return false
		%InvScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		%InvScroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		%InvScroll.add_child(_room)
		var inv_body := get_node_or_null("Stage/LeftPanel/InventoryView/InvBox/Body") as Control
		TouchScrollHelperScript.attach(%InvScroll, inv_body if inv_body != null else %InvScroll)

	if _profile and _profile.storage and not _profile.storage.changed.is_connected(_on_storage_changed):
		_profile.storage.changed.connect(_on_storage_changed)

	var bags := %BagTabs.get_children()
	for i in bags.size():
		var btn := bags[i] as Button
		if btn:
			btn.pressed.connect(_select_bag.bind(i))
			btn.set_drag_forwarding(Callable(), _can_drop_on_tab.bind(i), _drop_on_tab.bind(i))

	%SortButton.text = tr(%SortButton.text)
	%SortButton.pressed.connect(_on_sort_pressed)
	if has_node("%ShopButton"):
		%ShopButton.text = tr(%ShopButton.text)
		%ShopButton.pressed.connect(func() -> void:
			PotionShopWindow.open(self, func() -> void:
				refresh()
				_refresh_inventory_view()
			, _profile)
		)
	if has_node("%CraftButton"):
		%CraftButton.text = tr(%CraftButton.text)
		%CraftButton.pressed.connect(func() -> void:
			_set_view("crafting")
		)
	if has_node("%StorageButton"):
		%StorageButton.text = tr(%StorageButton.text)
		%StorageButton.pressed.connect(_toggle_storage_window)
	if has_node("%SecurityButton"):
		%SecurityButton.text = tr(%SecurityButton.text)
		%SecurityButton.pressed.connect(func() -> void:
			if not SecurityLock.has_password(_profile):
				SecurityWindow.open(self, _profile)
			elif SecurityLock.is_locked(_profile):
				KeypadWindow.ask(self, "Mở khóa bảo vệ", "Nhập mật mã để mở khóa.", func(code: String) -> void:
					var err := SecurityLock.unlock(_profile, code)
					if err == "":
						_show_toast("Giải mã khóa bảo vệ thành công!")
					else:
						_show_toast("Mật mã kiểm chứng không chính xác!", true)
					refresh()
				)
			else:
				var _err := SecurityLock.lock(_profile)
				_show_toast("Đã bật khóa bảo vệ!")
				refresh()
		)
	var is_gm := AccountApi.is_gm()
	if has_node("%TestCreateButton"):
		var btn: Button = get_node("%TestCreateButton")
		btn.visible = is_gm
		if not is_gm:
			btn.queue_free()

	if is_gm:
		if has_node("%TestCreateButton"):
			%TestCreateButton.text = tr(%TestCreateButton.text)
			%TestCreateButton.pressed.connect(func() -> void:
				ItemCreatorPopup.open(self, _profile, func() -> void:
					SaveManager.save_profile(_profile)
					SaveManager.flush_online()
					refresh()
					_refresh_inventory_view()
				)
			)
	if has_node("%CloseInvBtn"):
		%CloseInvBtn.pressed.connect(func() -> void:
			_set_view("character")
		)

func _can_drop_on_tab(_at: Vector2, data: Variant, bag: int) -> bool:
	return data is Dictionary and data.get("type") == ItemRoomView.DRAG_TYPE and bag < PlayerProfile.OPEN_BAGS and (data["item"] as ItemInstance).room_bag != bag

func _drop_on_tab(_at: Vector2, data: Variant, bag: int) -> void:
	if _profile == null or not (data is Dictionary and data.get("item") is ItemInstance):
		return
	var item: ItemInstance = data["item"]
	if _profile.move_to_bag(item, bag):
		SaveManager.save_profile(_profile)
		_select_bag(bag)
	else:
		_show_toast("Túi %d đã đầy chỗ cho món này" % (bag + 1), true)

func _setup_equipment_slots() -> void:
	if has_node("%MaskVisualCheck"):
		%MaskVisualCheck.toggled.connect(_on_mask_visual_check_toggled)
	for slot_name in SLOT_TO_PART:
		var btn: Button = get_node_or_null("%" + slot_name)
		if btn:
			var part: int = SLOT_TO_PART[slot_name]
			btn.set_meta("draggable", true)
			btn.pressed.connect(_on_equip_slot_pressed.bind(part))
			btn.set_drag_forwarding(Callable(), _can_drop_on_equip_slot.bind(part), _drop_on_equip_slot.bind(part))

func _can_drop_on_equip_slot(_at: Vector2, data: Variant, part: int) -> bool:
	if not (data is Dictionary and data.get("type") == ItemRoomView.DRAG_TYPE):
		return false
	var item: ItemInstance = data.get("item")
	if item == null:
		return false
	var parts: Array = Equipment.DETAIL_TO_PARTS.get(item.get_detail(), [])
	return part in parts

func _drop_on_equip_slot(_at: Vector2, data: Variant, _part: int) -> void:
	var item: ItemInstance = data.get("item")
	if item == null or _profile == null:
		return
	var index := _profile.inventory.find(item)
	if index >= 0:
		_equip_item_from_inv(index)

func _drag_equipped_item(at_position: Vector2, part: int, item: ItemInstance, widget: Control) -> Variant:
	var preview := Control.new()
	var icon = item.get_icon(false)
	if icon != null:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size = widget.size
		tex.position = -at_position
		tex.modulate.a = 0.85
		preview.add_child(tex)
	widget.set_drag_preview(preview)
	return {"type": ItemRoomView.DRAG_TYPE, "item": item, "source": "mannequin", "part": part, "grab": Vector2i.ZERO}

func _refresh_equipment_display() -> void:
	if _profile == null:
		return
	var equip_bg: TextureRect = get_node_or_null("%EquipBackground")
	if equip_bg == null and %CenterPanel:
		equip_bg = %CenterPanel.get_node_or_null("EquipBox/EquipBackground")
	if equip_bg:
		if _profile.gender == PlayerProfile.Gender.FEMALE:
			equip_bg.texture = TEX_EQUIP_BG_FEMALE
		else:
			equip_bg.texture = TEX_EQUIP_BG_MALE

	var ctx := Equipment.get_requirement_context(_profile)
	for slot_name in SLOT_TO_PART:
		var btn: Button = get_node_or_null("%" + slot_name)
		if btn == null:
			continue
		var part: int = SLOT_TO_PART[slot_name]
		var icon: TextureRect = btn.get_node_or_null("Icon")
		var item: ItemInstance = _profile.equipment.get(part)
		var unusable: bool = (item != null and not Equipment.can_use(item, _profile, ctx))
		_update_slot_backdrop(btn, item != null, unusable, item)
		_update_slot_rarity(btn, item)
		btn.set_meta("draggable", true)
		if item != null:
			btn.set_drag_forwarding(_drag_equipped_item.bind(part, item, btn), _can_drop_on_equip_slot.bind(part), _drop_on_equip_slot.bind(part))
			if icon:
				icon.texture = item.get_icon()
				var tex_sz := icon.texture.get_size()
				if tex_sz.x > btn.size.x or tex_sz.y > btn.size.y:
					icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				else:
					icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.visible = true
			btn.tooltip_text = item.get_display_name()
		else:
			btn.set_drag_forwarding(Callable(), _can_drop_on_equip_slot.bind(part), _drop_on_equip_slot.bind(part))
			if icon:
				icon.texture = null
				icon.visible = false
			btn.tooltip_text = ""

	for unused_slot in ["SlotRight0", "SlotRight4", "SlotRight5"]:
		var btn: Button = get_node_or_null("%" + unused_slot)
		if btn:
			var icon: TextureRect = btn.get_node_or_null("Icon")
			if icon:
				icon.texture = null
				icon.visible = false
			_update_slot_backdrop(btn, false)
			_update_slot_rarity(btn, null)
			btn.tooltip_text = ""
	_refresh_mask_check()
	_refresh_pk_label()

func _refresh_pk_label() -> void:
	if not has_node("%PkValueLabel"):
		return
	var pk_val: int = _profile.pk_value if _profile else 0
	var lbl: Label = %PkValueLabel
	lbl.text = str(pk_val)
	if pk_val > 0:
		lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.2))
	else:
		lbl.add_theme_color_override("font_color", Color(0.98, 0.78, 0.12))
	lbl.tooltip_text = "Điểm PK: %d\n(Mỗi lần đồ sát người chơi sẽ tăng 1 điểm PK)" % pk_val

func _refresh_mask_check() -> void:
	if not has_node("%MaskVisualCheck") or _profile == null:
		return
	var btn: Button = %MaskVisualCheck
	var mask_item: ItemInstance = _profile.equipment.get(Equipment.Part.MASK)
	if mask_item == null:
		btn.disabled = true
		btn.button_pressed = false
		btn.icon = null
		btn.tooltip_text = "Chưa đeo mặt nạ"
	else:
		btn.disabled = false
		btn.set_pressed_no_signal(_profile.show_mask)
		btn.icon = ICON_CHECK if _profile.show_mask else null
		btn.tooltip_text = "Ngoại hình mặt nạ: Đang bật\n(Bấm để tắt hiển thị giao diện bên ngoài)" if _profile.show_mask else "Ngoại hình mặt nạ: Đang tắt\n(Bấm để mở hiển thị giao diện bên ngoài)"

func _on_mask_visual_check_toggled(pressed: bool) -> void:
	if _profile == null:
		return
	_profile.show_mask = pressed
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	_refresh_mask_check()
	_refresh_portrait()
	_sync_game_player_appearance()

func _sync_game_player_appearance() -> void:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		var player = tree.get_first_node_in_group("player")
		if player != null and player.has_method("refresh_appearance"):
			player.refresh_appearance()

func _update_slot_rarity(btn: Control, item: ItemInstance) -> void:
	RarityRing.attach(btn, item)

func _update_slot_backdrop(btn: Button, show: bool, unusable: bool = false, item: ItemInstance = null) -> void:
	var bg: Panel = btn.get_node_or_null("Backdrop")
	if bg == null:
		if not show:
			return
		bg = Panel.new()
		bg.name = "Backdrop"
		bg.show_behind_parent = true
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		var style := StyleBoxFlat.new()
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.set_corner_radius_all(2)
		bg.add_theme_stylebox_override("panel", style)
		btn.add_child(bg)
		btn.move_child(bg, 0)
	if not show:
		bg.visible = false
		return
	bg.visible = true
	var style: StyleBoxFlat = bg.get_theme_stylebox("panel")
	style.set_border_width_all(1)
	if unusable:
		style.bg_color = Color(0.26, 0.06, 0.05, 1.0)
		if item != null and item.is_gold():
			style.border_color = Color(1.0, 0.78, 0.0, 0.40)
		elif item != null and item.is_purple():
			style.border_color = Color(0.85, 0.28, 1.0, 0.40)
		else:
			style.border_color = Color(0.50, 0.12, 0.10, 0.85)
	else:
		style.bg_color = Color(0.04, 0.05, 0.06, 1.0)
		if item != null and item.is_gold():
			style.border_color = Color(1.0, 0.78, 0.0, 0.40)
		elif item != null and item.is_purple():
			style.border_color = Color(0.85, 0.28, 1.0, 0.40)
		else:
			style.border_color = Color(0.18, 0.28, 0.28, 0.5)

	# Cập nhật style hover phù hợp với chất lượng món đồ
	var hover_style := StyleBoxFlat.new()
	hover_style.set_corner_radius_all(2)
	hover_style.set_border_width_all(2)
	if item != null and item.is_purple():
		hover_style.bg_color = Color(0.85, 0.28, 1.0, 0.15)
		hover_style.border_color = Color(0.88, 0.45, 1.0, 0.95)
		hover_style.shadow_color = Color(0.85, 0.28, 1.0, 0.4)
		hover_style.shadow_size = 3
	elif item != null and item.is_gold():
		hover_style.bg_color = Color(1.0, 0.85, 0.3, 0.15)
		hover_style.border_color = Color(1.0, 0.88, 0.45, 0.95)
		hover_style.shadow_color = Color(1.0, 0.82, 0.2, 0.4)
		hover_style.shadow_size = 3
	else:
		hover_style.bg_color = Color(0.2, 0.6, 0.5, 0.15)
		hover_style.border_color = Color(0.3, 0.8, 0.7, 0.8)
		hover_style.shadow_color = Color(0, 0, 0, 0)
		hover_style.shadow_size = 0
	btn.add_theme_stylebox_override("hover", hover_style)

func _on_equip_slot_pressed(part: int) -> void:
	if _profile == null:
		return
	var item: ItemInstance = _profile.equipment.get(part)
	if item == null:
		_set_view("equipment")
		return
	var series := _profile.get_element() if _profile.has_method("get_element") else _sect_element()
	var counts := Equipment.get_active_counts(_profile.equipment, series)
	var desc := ItemText.build(item, _profile, counts.get(part, 0), part, false)
	var actions: Array = [
		["Tháo đồ", func() -> void: _unequip_item(part, item)]
	]
	ItemDetailPopup.open(self, desc, actions, item)

func _unequip_item(part: int, item: ItemInstance) -> void:
	if _profile.unequip(part):
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
		_show_toast("Đã tháo %s" % item.get_display_name())
		refresh()
		_refresh_inventory_view()
	else:
		_show_toast("Hành trang đã đầy, không thể tháo đồ!", true)

func _set_view(view: String) -> void:
	_current_view = view
	var show_char: bool = (view == "character")
	%InfoBox.visible = show_char

	# Trang bị (CenterPanel) CHỈ hiện khi ở màn "Nhân vật" hoặc "Trang bị"
	# Các màn "Kỹ năng", "Bang hội", "Giao dịch", "BXH", "Cài đặt", "Chế tạo" đều ẩn Trang bị
	%CenterPanel.visible = (view in ["character", "equipment"])

	# Riêng "Chế tạo" thì đổi vị trí: Hành trang bên trái, Chế tạo bên phải
	if view == "crafting":
		%InventoryView.visible = true
		%InventoryView.position = Vector2.ZERO
	elif view == "equipment":
		%InventoryView.visible = true
		%InventoryView.position = Vector2.ZERO
	else:
		%InventoryView.visible = false
		%InventoryView.position = Vector2.ZERO

	if _events_view:
		_events_view.visible = (view == "events")
	if _skills_view:
		_skills_view.visible = (view == "skills")
	if _guild_view:
		_guild_view.visible = (view == "guild")
	if _market_view:
		_market_view.visible = (view == "social")
	if _crafting_view:
		if view != "crafting" and is_instance_valid(_crafting_view):
			_crafting_view.clear_all_slots()
		_crafting_view.visible = (view == "crafting")
	if _ranking_view:
		_ranking_view.visible = (view == "ranking")
	if _settings_view:
		_settings_view.visible = (view == "settings")

	_update_nav_styles(view)

	match view:
		"character":
			refresh()
		"events":
			_show_events_view()
		"equipment":
			_refresh_equipment_display()
			_refresh_inventory_view()
		"skills":
			_show_skills_view()
		"guild":
			_show_guild_view()
		"social":
			_show_social_view()
		"crafting":
			_show_crafting_view()
		"ranking":
			_show_ranking_view()
		"settings":
			_show_settings_view()

	_update_responsive_layout.call_deferred()

func _update_nav_styles(active_view: String) -> void:
	_style_button(%CharacterButton, active_view == "character")

	for i in NAV_ITEMS.size():
		var id: String = NAV_ITEMS[i][0]
		var btn: Button = get_node_or_null("%%NavButton%d" % i)
		if btn:
			_style_button(btn, id == active_view)

func _style_button(btn: Button, active: bool) -> void:
	if active:
		if _style_nav_active:
			btn.add_theme_stylebox_override("normal", _style_nav_active)
			btn.add_theme_stylebox_override("hover", _style_nav_active)
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		if _style_nav_normal:
			btn.add_theme_stylebox_override("normal", _style_nav_normal)
			btn.add_theme_stylebox_override("hover", %NavButton0.get_theme_stylebox("hover"))
		btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82, 1))

func _show_skills_view() -> void:
	if _all_skills.is_empty():
		_all_skills = _load_all_skills()
	if _all_skills.is_empty():
		if _profile != null and _profile.needs_sect():
			_ask_sect_if_needed()
		else:
			_show_toast("Chưa gia nhập môn phái — đạt cấp %d để chọn phái" % PlayerProfile.NEWBIE_LEVEL, true)
		_set_view("character")
		return
	if _skills_view == null:
		_skills_view = SkillBookViewScript.new(_profile, _all_skills)
		_skills_view.set_docked(true, true)
		_skills_view.close_requested.connect(func() -> void: _set_view("character"))
		_skills_view.skill_changed.connect(func() -> void: refresh())
		%LeftPanel.add_child(_skills_view)
	else:
		_skills_view._profile = _profile
	_skills_view.set_docked(true, true)
	_skills_view.visible = true
	_skills_view.size = Vector2(1000, 585)
	_skills_view._refresh()

func _show_guild_view() -> void:
	if _guild_view == null:
		_guild_view = GuildWindow.new(SocialHub.of(_profile))
		_guild_view.set_docked(true, true)
		_guild_view.close_requested.connect(func() -> void: _set_view("character"))
		_guild_view.enter_map_requested.connect(_enter_field_map)
		%LeftPanel.add_child(_guild_view)
	_guild_view.set_docked(true, true)
	_guild_view.visible = true
	_guild_view._rebuild()

func _show_social_view() -> void:
	if _market_view == null:
		_market_view = MarketWindow.new(SocialHub.of(_profile))
		_market_view.set_docked(true, true)
		_market_view.close_requested.connect(func() -> void: _set_view("character"))
		%LeftPanel.add_child(_market_view)
	_market_view.set_docked(true, true)
	_market_view.visible = true
	_market_view.size = Vector2(1000, 585)
	_market_view._refresh_money()

func _show_crafting_view() -> void:
	if _crafting_view == null:
		_crafting_view = CompoundWindow.new()
		_crafting_view._profile = _profile
		_crafting_view.set_docked(true, false, 475.0, Vector2(565.0, 68.0))
		_crafting_view.close_requested.connect(func() -> void: _set_view("character"))
		_crafting_view.slots_changed.connect(func() -> void: _refresh_inventory_view())
		_crafting_view._on_changed = func() -> void:
			_refresh_inventory_view()
			refresh()
		%LeftPanel.add_child(_crafting_view)
	_crafting_view.set_docked(true, false, 475.0, Vector2(565.0, 68.0))
	_crafting_view.visible = true
	_crafting_view.set_deferred("position", Vector2(565.0, 68.0))
	_crafting_view.set_deferred("size", Vector2(475.0, 585.0))
	_refresh_inventory_view()

func _show_ranking_view() -> void:
	if _ranking_view == null:
		_ranking_view = RankingWindow.new(_profile)
		_ranking_view.set_docked(true, true)
		_ranking_view.close_requested.connect(func() -> void: _set_view("character"))
		%LeftPanel.add_child(_ranking_view)
	_ranking_view.set_docked(true, true)
	_ranking_view.visible = true
	_ranking_view._load()

func _show_settings_view() -> void:
	if _settings_view == null:
		_settings_view = SettingsWindow.new(true)
		_settings_view.set_docked(true, true)
		_settings_view.close_requested.connect(func() -> void: _set_view("character"))
		_settings_view.setup_hub_actions(_on_change_server_pressed, _on_quit_game_pressed, _on_change_character_pressed)
		%LeftPanel.add_child(_settings_view)
	_settings_view.set_docked(true, true)
	_settings_view.visible = true

func _show_events_view() -> void:
	if _events_view == null:
		_events_view = EventScheduleWindow.new(_profile, _enter_field_map)
		_events_view.set_docked(true, true)
		_events_view.close_requested.connect(func() -> void: _set_view("character"))
		_events_view.event_action_requested.connect(_on_event_action)
		%LeftPanel.add_child(_events_view)
	_events_view.set_docked(true, true)
	_events_view.visible = true
	_events_view.refresh()

func _on_event_action(event_id: String) -> void:
	match event_id:
		"battle", "time_challenge", "ferry":
			var win := MapSelectWindow.open(self, _profile, _enter_field_map)
			win._select_tab(2)
		"world_boss":
			var win := MapSelectWindow.open(self, _profile, _enter_field_map)
			win._select_tab(3)
		"pk_arena":
			PkWindow.open(self, _profile, _enter_field_map)
		"hoa_dang":
			LanternWindow.open(self, _profile)
		"escort":
			var pk_win := PkWindow.open(self, _profile, _enter_field_map)
			pk_win._select_mode(PkRules.Mode.VAN_TIEU)
		"siege":
			SiegeWindow.open(self, _profile, _enter_field_map)
		"huy_hoang":
			HuyHoangWindow.open(self, _profile)
		"bat_nha":
			BatNhaWindow.open(self, _profile)
		"viem_de":
			ViemDeWindow.open(self, _profile, _enter_field_map)

func _setup_nav_buttons() -> void:
	%CharacterButton.pressed.connect(func() -> void:
		_set_view("character")
	)

	for i in NAV_ITEMS.size():
		var id: String = NAV_ITEMS[i][0]
		var label_text: String = NAV_ITEMS[i][1]
		var btn: Button = get_node_or_null("%%NavButton%d" % i)
		if btn == null:
			continue
		match id:
			"events", "equipment", "skills", "guild", "social", "crafting", "ranking", "settings":
				btn.pressed.connect(_set_view.bind(id))
			_:
				btn.pressed.connect(_show_toast.bind("%s: đang phát triển" % label_text))

func _select_bag(bag_idx: int) -> void:
	if bag_idx >= PlayerProfile.OPEN_BAGS:
		_show_toast("Túi %d chưa mở" % (bag_idx + 1), true)
		return
	_current_bag = bag_idx
	if _room:
		_room.bag = bag_idx
	_refresh_inventory_view()

func _refresh_inventory_view() -> void:
	if _profile == null or not is_inside_tree() or not has_node("%BagTabs"):
		return

	var bags := %BagTabs.get_children()
	for i in bags.size():
		var btn := bags[i] as Button
		if btn:
			var is_open: bool = (i < PlayerProfile.OPEN_BAGS)
			btn.disabled = not is_open
			if _style_tab_active and _style_tab_normal:
				btn.add_theme_stylebox_override("normal", _style_tab_active if i == _current_bag else _style_tab_normal)

	if _room:
		_room.bag = _current_bag
		if _current_view == "crafting" and _crafting_view and is_instance_valid(_crafting_view):
			_room.slotted_counts = _crafting_view.get_used_counts()
		else:
			_room.slotted_counts = {}
		_room.setup(_profile)

func _toggle_storage_window() -> void:
	for w in get_tree().get_nodes_in_group("social_windows"):
		if w is StorageWindow and is_instance_valid(w):
			w.close_requested.emit()
			return
	var win := StorageWindow.open(self, _profile)
	if win:
		win.position = Vector2(560.0, 68.0)
		win.size = Vector2(280.0, 585.0)

func _on_storage_changed() -> void:
	refresh()
	_refresh_inventory_view()

func _on_room_item_pressed(item: ItemInstance) -> void:
	if _profile == null or item == null:
		return
	var index := _profile.inventory.find(item)
	if index < 0:
		return
	var actions: Array = []
	if not item.is_misc():
		actions.append(["Trang bị", func() -> void: _equip_item_from_inv(index)])
	else:
		var use_label := ItemConsumer.get_action_label(item)
		actions.append([use_label, func() -> void: _use_item_from_inv(index)])
	actions.append(["Vứt bỏ", func() -> void: _drop_item_from_inv(index)])

	if item.misc_id in ["4_238_1", "4_239_1", "4_240_1", "4_353_1"]:
		actions.append(["Tiệm Ép Đồ", func() -> void: CompoundWindow.open(self, _profile, Callable())])
	elif item.misc_id in ["6_1_2805", "6_1_1685", "6_1_1606"]:
		actions.append(["Tiệm Đổi Viêm Đế", func() -> void: ViemDeWindow.open_reward_shop(self, _profile)])
	if item.can_sell():
		var label := "Bán (%s Lượng)" % InventoryPopup.format_money(item.get_sale_price())
		actions.insert(1, [label, func() -> void: _sell_item_from_inv(index)])
	if _current_view == "crafting" and _crafting_view and is_instance_valid(_crafting_view):
		actions.insert(0, ["Đặt vào chế tạo", func() -> void: _crafting_view._put(item)])

	var storage_win: StorageWindow = null
	for w in get_tree().get_nodes_in_group("social_windows"):
		if w is StorageWindow and is_instance_valid(w):
			storage_win = w
			break
	if storage_win:
		actions.insert(0, ["Cất vào rương", func() -> void:
			var err := StorageService.store_item(_profile, item, storage_win._box)
			if err != "":
				_show_toast(err, true)
			else:
				_show_toast("Đã cất %s vào rương." % item.get_display_name())
				SaveManager.save_profile(_profile)
				SaveManager.flush_online()
				refresh()
				_refresh_inventory_view()
				storage_win._refresh()
		])

	ItemDetailPopup.open(self, ItemText.build(item, _profile, -1, -1, false), actions, item)

func _equip_item_from_inv(index: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	var item: ItemInstance = _profile.inventory[index]
	var item_name: String = str(item.get_display_name())
	var err := _profile.equip_from_inventory(index)
	if err != "":
		_show_toast(err, true)
	else:
		_show_toast("Đã trang bị %s!" % item_name)
		SaveManager.save_profile(_profile)
		refresh()
		_refresh_inventory_view()

func _drop_item_from_inv(index: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	var item: ItemInstance = _profile.inventory[index]
	var blocked := SecurityLock.check(_profile, SecurityLock.A_DROP_ITEM)
	if blocked == "" and SecurityLock.is_item_locked(item):
		blocked = "Món đồ đang bị khoá, không vứt được."
	if blocked != "":
		_show_toast(blocked, true)
		return
	_profile.inventory.remove_at(index)
	_show_toast("Đã vứt %s" % item.get_display_name())
	SaveManager.save_profile(_profile)
	refresh()
	_refresh_inventory_view()

func _sell_item_from_inv(index: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	var item: ItemInstance = _profile.inventory[index]
	var blocked := SecurityLock.check(_profile, SecurityLock.A_NPC_SELL)
	if blocked == "" and SecurityLock.is_item_locked(item):
		blocked = "Món đồ đang bị khoá, không thể bán."
	if blocked != "":
		_show_toast(blocked, true)
		return
	if not item.can_sell():
		_show_toast("Vật phẩm này không thể bán.", true)
		return

	var sale_price: int = int(item.get_sale_price())
	var item_name: String = str(item.get_display_name())

	if item.is_gold() or item.is_purple():
		var popup := ConfirmationDialog.new()
		popup.title = "Xác nhận bán"
		popup.dialog_text = "Bạn có chắc muốn bán [%s] với giá %s Lượng không?" % [item_name, InventoryPopup.format_money(sale_price)]
		popup.ok_button_text = "Bán"
		popup.cancel_button_text = "Hủy"
		add_child(popup)
		popup.confirmed.connect(func() -> void:
			_execute_sell_from_inv(index, item_name, sale_price)
			popup.queue_free()
		)
		popup.canceled.connect(func() -> void:
			popup.queue_free()
		)
		popup.popup_centered()
		return

	_execute_sell_from_inv(index, item_name, sale_price)

func _execute_sell_from_inv(index: int, item_name: String, sale_price: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	_profile.inventory.remove_at(index)
	_profile.gold += sale_price
	_show_toast("Đã bán %s nhận được %s Lượng." % [item_name, InventoryPopup.format_money(sale_price)])
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	refresh()
	_refresh_inventory_view()

func _use_item_from_inv(index: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	var item: ItemInstance = _profile.inventory[index]
	var player := get_tree().get_first_node_in_group("player")
	var res := ItemConsumer.use_item(_profile, item, player, self)
	if res.has("message") and str(res["message"]) != "":
		_show_toast(str(res["message"]), not res.get("ok", false))
	if res.get("ok", false):
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
		refresh()
		_refresh_inventory_view()

func _open_viem_de_chest_hub(index: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	var item: ItemInstance = _profile.inventory[index]
	if item.count > 1:
		item.count -= 1
	else:
		_profile.inventory.remove_at(index)

	var gained_exp := randi_range(1500000, 3500000)
	var gained_gold := randi_range(150000, 350000)
	_profile.add_exp(gained_exp)
	_profile.gold += gained_gold

	var frags := randi_range(1, 3)
	for i in frags:
		var frag_it := ItemGenerator.generate_misc("6_1_1685")
		if frag_it != null:
			_profile.add_item(frag_it)

	var tt_ids := ["4_238_1", "4_239_1", "4_240_1"]
	var tt_pick: String = tt_ids.pick_random()
	var tt_it := ItemGenerator.generate_misc(tt_pick)
	var tt_name := "Thủy Tinh"
	if tt_it != null:
		tt_name = tt_it.get_name()
		_profile.add_item(tt_it)

	var w_script: GDScript = load("res://ui/events/viem_de_window.gd")
	if w_script != null:
		var rec: Dictionary = w_script._get_records_for(_profile)
		rec["chests"] = maxi(0, int(rec.get("chests", 0)) - 1)
		rec["totem_fragments"] = int(rec.get("totem_fragments", 0)) + frags
		w_script._save_records_for(rec, _profile)

	_show_toast("Mở [Viêm Đế Bí Bảo] thành công!\n+ %s EXP\n+ %s Lượng\n+ %d Mảnh Đồ Đằng\n+ 1 %s" % [
		InventoryPopup.format_money(gained_exp),
		InventoryPopup.format_money(gained_gold),
		frags,
		tt_name
	])
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	refresh()
	_refresh_inventory_view()

func _craft_viem_de_totem_hub(_index: int) -> void:
	if _profile == null:
		return
	var res: Dictionary = ViemDeWindow.craft_totem_quick(_profile)
	_show_toast(str(res.get("message", "")), not res.get("ok", false))
	refresh()
	_refresh_inventory_view()

func _on_sort_pressed() -> void:
	if _profile == null:
		return
	_profile.sort_inventory()
	SaveManager.save_profile(_profile)
	_show_toast("Đã sắp xếp hành trang")
	_refresh_inventory_view()

func _on_skills_nav_pressed() -> void:
	_set_view("skills")

func _on_change_character_pressed() -> void:
	SocialWindow.confirm(self, "Chọn Nhân Vật", "Lưu dữ liệu và trở về màn hình chọn nhân vật?", func() -> void:
		if _profile != null:
			SaveManager.save_profile(_profile)
			await SaveManager.flush_online()
		if AccountApi.is_logged_in():
			get_tree().change_scene_to_file(ROSTER_SCENE_PATH)
			return
		get_tree().change_scene_to_file(SELECT_SCENE_PATH)
	)

func _on_change_server_pressed() -> void:
	SocialWindow.confirm(self, "Chọn Máy Chủ", "Lưu dữ liệu và trở về màn hình chọn máy chủ?", func() -> void:
		if _profile != null:
			SaveManager.save_profile(_profile)
			await SaveManager.flush_online()
		get_tree().change_scene_to_file("res://ui/server_select/ServerSelect.tscn")
	)

func _on_quit_game_pressed() -> void:
	SocialWindow.confirm(self, "Thoát Game", "Lưu dữ liệu và thoát khỏi trò chơi?", func() -> void:
		if _profile != null:
			SaveManager.save_profile(_profile)
			await SaveManager.flush_online()
		get_tree().quit()
	)

func _on_back_pressed() -> void:
	if _profile != null:
		SaveManager.save_profile(_profile)
		await SaveManager.flush_online()
	if AccountApi.is_logged_in():
		get_tree().change_scene_to_file(ROSTER_SCENE_PATH)
		return
	get_tree().change_scene_to_file(SELECT_SCENE_PATH)

func _enter_field_map(entry: Dictionary) -> void:
	if _profile != null:
		SaveManager.save_profile(_profile)
		await SaveManager.flush_online()
	if entry.has("stage") and entry["stage"] is StageData:
		GameManager.game_mode = GameManager.GameMode.STAGE
		GameManager.field_map = {}
		GameManager.current_stage = entry["stage"]
	else:
		GameManager.game_mode = GameManager.GameMode.MAIN_MAP
		GameManager.field_map = entry
		GameManager.current_stage = null
	GameManager.is_game_over = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(get_tree().change_scene_to_file.bind(GAME_SCENE_PATH))

func _show_toast(message: String, is_error: bool = false) -> void:
	var toast: Label = %ToastLabel
	if toast == null:
		return

	# Tự động nhận diện thông báo lỗi nếu chưa gán is_error rõ ràng
	if not is_error:
		var lower := message.to_lower()
		for kw in [
			"cảnh giới", "không thể", "thất bại", "chưa đủ", "không đủ",
			"đã đầy", "chưa mở", "không chính xác", "không còn", "đã tối đa",
			"bị khóa", "chưa gia nhập", "không hợp lệ", "lỗi", "chưa học"
		]:
			if kw in lower:
				is_error = true
				break

	toast.text = message
	toast.visible = true
	toast.modulate.a = 1.0

	# Thiết lập kiểu dáng (StyleBox + Màu chữ)
	if is_error:
		# Nền đỏ cho lỗi
		var box_err := StyleBoxFlat.new()
		box_err.bg_color = Color(0.42, 0.07, 0.07, 0.94)  ## Nền đỏ đô/đỏ sẫm rõ ràng
		box_err.border_color = Color(0.92, 0.28, 0.28, 0.98)  ## Viền đỏ tươi nổi bật
		box_err.set_border_width_all(1)
		box_err.set_corner_radius_all(6)
		box_err.content_margin_left = 22.0
		box_err.content_margin_right = 22.0
		box_err.content_margin_top = 8.0
		box_err.content_margin_bottom = 8.0
		box_err.shadow_color = Color(0, 0, 0, 0.6)
		box_err.shadow_size = 5
		toast.add_theme_stylebox_override("normal", box_err)

		# Chữ hơi đỏ đậm xíu (viền outline đen sắc nét bảo đảm độ tương phản tối đa)
		toast.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38, 1.0))
		toast.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.0, 1.0))
		toast.add_theme_constant_override("outline_size", 4)
	else:
		# Toast thông thường (thành công / thông tin)
		var box_ok := StyleBoxFlat.new()
		box_ok.bg_color = Color(0.08, 0.08, 0.07, 0.94)  ## Nền tối kiếm hiệp
		box_ok.border_color = Color(0.78, 0.62, 0.28, 0.9)  ## Viền vàng kim
		box_ok.set_border_width_all(1)
		box_ok.set_corner_radius_all(6)
		box_ok.content_margin_left = 22.0
		box_ok.content_margin_right = 22.0
		box_ok.content_margin_top = 8.0
		box_ok.content_margin_bottom = 8.0
		box_ok.shadow_color = Color(0, 0, 0, 0.6)
		box_ok.shadow_size = 5
		toast.add_theme_stylebox_override("normal", box_ok)

		toast.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
		toast.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		toast.add_theme_constant_override("outline_size", 4)

	# Tính toán kích thước tự động vừa vặn nội dung và căn giữa
	var font := toast.get_theme_font("font")
	var font_size := toast.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 18
	var text_w := 0.0
	if font:
		text_w = font.get_string_size(message, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	else:
		text_w = float(message.length() * 11)

	var vw := get_viewport_rect().size.x
	if vw <= 0:
		vw = 1280.0
	var toast_w := clampf(text_w + 48.0, 260.0, minf(vw - 60.0, 960.0))
	toast.size.x = toast_w
	toast.offset_left = (vw - toast_w) * 0.5
	toast.offset_right = toast.offset_left + toast_w

	# Tự động giãn chiều cao nếu thông báo có nhiều dòng
	var lines := message.split("\n")
	var toast_h := maxf(40.0, float(lines.size() * 24 + 16))
	toast.size.y = toast_h
	toast.offset_top = 550.0 - (toast_h - 40.0) * 0.5
	toast.offset_bottom = toast.offset_top + toast_h

	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(toast.hide)

func _load_all_skills() -> Array[SkillDefinition]:
	if _profile == null or _profile.sect_id == "":
		return []
	var sect := SectRegistry.get_by_id(_profile.sect_id)
	return sect.skills if sect else []

func _ask_sect_if_needed() -> void:
	if _profile == null or not _profile.needs_sect():
		return
	var win := SectChoiceWindow.open(self, _profile)
	win.chosen.connect(func(sect: SectDefinition) -> void:
		_all_skills = _load_all_skills()
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
		refresh()
	)

static func format_number(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > 3:
		result = "." + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result

static func _format_number(value: int) -> String:
	return format_number(value)

# ================================================================ Thích ứng màn hình dài (Full 2 bên / Responsive)
func _on_stage_layout_adapted(virtual_w: float, _virtual_h: float, extra_w: float) -> void:
	_apply_responsive_offsets(virtual_w, extra_w)

func _update_responsive_layout() -> void:
	var stage := get_node_or_null("Stage") as Control
	if stage == null or not is_inside_tree():
		return
	var vp_size := get_viewport_rect().size
	if vp_size.y <= 0.0 or vp_size.x <= 0.0:
		return
	var s := vp_size.y / 720.0
	var vw := vp_size.x / s
	var extra_w := maxf(0.0, vw - 1280.0)
	_apply_responsive_offsets(vw, extra_w)

func _apply_responsive_offsets(vw: float, extra_w: float) -> void:
	var stage := get_node_or_null("Stage") as Control
	if stage == null:
		return

	# 1. TopBar & Cụm Tiền tệ
	var top_bar := stage.get_node_or_null("TopBar") as Control
	if top_bar:
		top_bar.size.x = vw
		var gold := top_bar.get_node_or_null("FrameCurrencyGold") as Control
		var xu := top_bar.get_node_or_null("FrameCurrencyXu") as Control
		var jade := top_bar.get_node_or_null("FrameCurrencyJade") as Control
		var ktc := top_bar.get_node_or_null("KyTranCacTopButton") as Control
		var stam := top_bar.get_node_or_null("FrameCurrencyStamina") as Control
		if gold:
			gold.offset_left = 696.0 + extra_w
			gold.offset_right = 836.0 + extra_w
		if xu:
			xu.offset_left = 844.0 + extra_w
			xu.offset_right = 984.0 + extra_w
		if jade:
			jade.offset_left = 992.0 + extra_w
			jade.offset_right = 1132.0 + extra_w
		if ktc:
			ktc.offset_left = 1140.0 + extra_w
			ktc.offset_right = 1256.0 + extra_w
		elif stam:
			stam.offset_left = 1140.0 + extra_w
			stam.offset_right = 1256.0 + extra_w

	# 2. RightPanel bám sát mép phải
	var right_panel := stage.get_node_or_null("RightPanel") as Control
	if right_panel:
		right_panel.offset_left = 1060.0 + extra_w
		right_panel.offset_right = 1262.0 + extra_w

	# 3. BottomBar
	var bot_bar := stage.get_node_or_null("BottomBar") as Control
	if bot_bar:
		bot_bar.size.x = vw

	# 4. ToastLabel căn giữa màn hình
	var toast := stage.get_node_or_null("%ToastLabel") as Control
	if toast:
		var toast_w := toast.size.x if toast.size.x > 0.0 else 480.0
		toast.offset_left = (vw - toast_w) * 0.5
		toast.offset_right = toast.offset_left + toast_w

	# 5. Cân chỉnh khu vực giữa (LeftPanel / CenterPanel)
	var left_panel := stage.get_node_or_null("%LeftPanel") as Control
	var center_panel := stage.get_node_or_null("%CenterPanel") as Control
	var shift_center := extra_w * 0.5
	if left_panel and center_panel:
		left_panel.offset_left = shift_center
		left_panel.offset_right = 545.0 + shift_center
		center_panel.offset_left = 565.0 + shift_center
		center_panel.offset_right = 1040.0 + shift_center

	# 6. Căn giữa các cửa sổ docked đang mở (Sự kiện, Kỹ năng, Bang hội...)
	for win in [_skills_view, _guild_view, _market_view, _ranking_view, _settings_view, _events_view]:
		if win and is_instance_valid(win) and win.visible:
			_reposition_docked_window(win, vw, extra_w)

func _reposition_docked_window(win: Control, _vw: float, extra_w: float) -> void:
	if win == null or not is_instance_valid(win):
		return
	var left_p := %LeftPanel as Control
	var left_p_offset := left_p.offset_left if left_p else 0.0
	var right_boundary := 1060.0 + extra_w
	var avail_w := right_boundary - 18.0
	var target_w := 1000.0 if (win is SocialWindow and (win as SocialWindow).is_full_width) else (win.size.x if win.size.x > 0 else 1000.0)
	win.size = Vector2(target_w, 585.0)
	var desired_x := 18.0 + maxf(0.0, (avail_w - target_w) * 0.5)
	win.position.x = desired_x - left_p_offset

func _on_locale_changed(_code: String) -> void:
	_retranslate_tree(self)

	# Làm mới các tab túi nếu có
	if has_node("%BagTabs"):
		var bags := %BagTabs.get_children()
		for i in bags.size():
			var btn := bags[i] as Button
			if btn:
				btn.text = tr("Túi %d" % (i + 1))

	# Làm mới các cửa sổ docked đang mở để tải lại bằng ngôn ngữ mới
	if _skills_view != null and is_instance_valid(_skills_view):
		var was_vis := _skills_view.visible
		_skills_view.queue_free()
		_skills_view = null
		if was_vis:
			_show_skills_view()
	if _events_view != null and is_instance_valid(_events_view):
		var was_vis := _events_view.visible
		_events_view.queue_free()
		_events_view = null
		if was_vis:
			_show_events_view()
	if _guild_view != null and is_instance_valid(_guild_view):
		var was_vis := _guild_view.visible
		_guild_view.queue_free()
		_guild_view = null
		if was_vis:
			_show_guild_view()
	if _ranking_view != null and is_instance_valid(_ranking_view):
		var was_vis := _ranking_view.visible
		_ranking_view.queue_free()
		_ranking_view = null
		if was_vis:
			_show_ranking_view()
	if _crafting_view != null and is_instance_valid(_crafting_view):
		var was_vis := _crafting_view.visible
		_crafting_view.queue_free()
		_crafting_view = null
		if was_vis:
			_show_crafting_view()
	if _market_view != null and is_instance_valid(_market_view):
		var was_vis := _market_view.visible
		_market_view.queue_free()
		_market_view = null
		if was_vis:
			_show_social_view()

	refresh()

func _retranslate_tree(node: Node) -> void:
	if node is Button:
		var btn := node as Button
		if not btn.text.is_empty():
			var key: String = btn.get_meta(&"orig_text", btn.text)
			btn.set_meta(&"orig_text", key)
			btn.text = tr(key)
		if not btn.tooltip_text.is_empty():
			var t_key: String = btn.get_meta(&"orig_tooltip", btn.tooltip_text)
			btn.set_meta(&"orig_tooltip", t_key)
			btn.tooltip_text = tr(t_key)
	elif node is Label:
		var lbl := node as Label
		if not lbl.text.is_empty():
			var key: String = lbl.get_meta(&"orig_text", lbl.text)
			lbl.set_meta(&"orig_text", key)
			if LocalizationManager != null and LocalizationManager.TRANSLATIONS.has(key):
				lbl.text = tr(key)
	for child in node.get_children():
		_retranslate_tree(child)

func _toggle_gm_window() -> void:
	if not AccountApi.is_gm():
		return
	var existing := get_tree().current_scene.find_child("GmControlWindow", true, false)
	if existing:
		existing.queue_free()
	else:
		var gm_script: GDScript = load("res://ui/gm/gm_control_window.gd")
		if gm_script:
			gm_script.open(self)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12 and AccountApi.is_gm():
			_toggle_gm_window()
			get_viewport().set_input_as_handled()

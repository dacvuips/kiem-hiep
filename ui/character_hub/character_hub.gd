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
	["events", "Sự Kiện"],
	["equipment", "Trang Bị"],
	["skills", "Kỹ Năng"],
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

func _ready() -> void:
	add_to_group("character_hub")
	if "--capture-screenshot" in OS.get_cmdline_args() or "--test-open-popup" in OS.get_cmdline_args() or "--test-open-inventory" in OS.get_cmdline_args() or "--test-open-skills" in OS.get_cmdline_args() or "--test-equipment-red" in OS.get_cmdline_args() or "--test-open-events" in OS.get_cmdline_args():
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


	# Sự kiện nạp / mua thêm
	%GoldPlusButton.pressed.connect(_show_toast.bind("Nạp Vàng: đang phát triển"))
	%JadePlusButton.pressed.connect(_show_toast.bind("Nạp Ngọc: đang phát triển"))
	%StaminaPlusButton.pressed.connect(_show_toast.bind("Hồi Thể Lực: đang phát triển"))

	# Nút cộng điểm tiềm năng
	%BaseStatButton0.pressed.connect(_add_stat.bind(0)) # Sức mạnh
	%BaseStatButton1.pressed.connect(_add_stat.bind(1)) # Thân pháp
	%BaseStatButton2.pressed.connect(_add_stat.bind(2)) # Sinh khí
	%BaseStatButton3.pressed.connect(_add_stat.bind(3)) # Nội công

	if has_node("%DebugCheatPanel"):
		%DebugCheatPanel.profile_changed.connect(func() -> void:
			_profile = GameManager.local_profile
			refresh()
			_refresh_inventory_view()
			_refresh_equipment_display()
		)

	if has_node("%ChatButton"):
		%ChatButton.pressed.connect(func() -> void:
			ChatPanel.toggle(self)
		)

	if has_node("%SocialButton"):
		%SocialButton.pressed.connect(func() -> void:
			TelegramCommunityPopup.open(self)
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

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	_ask_sect_if_needed.call_deferred()

	HubSession.attach(self)

	for arg in OS.get_cmdline_args():
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
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/1f8e86b8-a82c-4738-a2e3-475668d696c0/character_hub_rendered.png")
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
	_profile.level = 203
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

func refresh() -> void:
	if _profile == null:
		return

	# Thanh tiền tệ top
	%GoldValueLabel.text = _format_number(_profile.gold)
	%JadeValueLabel.text = _format_number(_profile.jade if _profile.jade > 0 else 0)
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
	%DamageLeftValue.text = "%d/%d" % [min_dmg, max_dmg]
	%DamageRightValue.text = "%d/%d" % [min_dmg, max_dmg]
	%ChinhXacValue.text = "%d/%d" % [s.attack_rating if s.attack_rating > 0 else 52, s.attack_rating if s.attack_rating > 0 else 52]
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

func _setup_portrait() -> void:
	if not has_node("%PortraitBox"):
		return
	var box: Control = %PortraitBox
	box.resized.connect(_place_portrait)
	box.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_turn_portrait()
			if _portrait_timer:
				_portrait_timer.start()
	)
	if _portrait_timer == null:
		_portrait_timer = Timer.new()
		_portrait_timer.wait_time = PORTRAIT_TURN_SECONDS
		_portrait_timer.timeout.connect(_turn_portrait)
		add_child(_portrait_timer)
		_portrait_timer.start()
	_place_portrait()

func _place_portrait() -> void:
	if not has_node("%PortraitBox") or not has_node("%PortraitAvatar"):
		return
	var box: Control = %PortraitBox
	var avatar: Node2D = %PortraitAvatar
	avatar.scale = Vector2(1.4, 1.4)
	avatar.position = Vector2(box.size.x * 0.5, box.size.y - 6.0)
	if _disguise_icon:
		_disguise_icon.position = Vector2(box.size.x - 24.0, 4.0)

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
	if not has_node("%PortraitAvatar") or _profile == null:
		return
	_setup_disguise_ui()
	var avatar: CharacterAvatar = %PortraitAvatar
	var gender_str := "female" if _profile.gender == PlayerProfile.Gender.FEMALE else "male"
	var look := Equipment.get_appearance(_profile.equipment, gender_str, _profile.riding)
	var final_gender: String = str(look.get("gender", gender_str))
	avatar.set_gender(final_gender)
	avatar.set_appearance(look["helm"], look["armor"], look["weapon"], look["horse"])
	if look.has("modulate"):
		avatar.modulate = look["modulate"]
	else:
		avatar.modulate = Color.WHITE

	var is_masked: bool = bool(look.get("is_masked", false))
	if _disguise_banner:
		_disguise_banner.visible = is_masked
		if is_masked:
			_disguise_label.text = "🎭 %s" % str(look.get("disguise_title", "Dịch Dung"))
	if _disguise_icon:
		_disguise_icon.visible = is_masked
		if is_masked:
			_disguise_icon.texture = look.get("mask_icon")
			_disguise_icon.tooltip_text = "Đang dịch dung: %s" % str(look.get("mask_name", ""))

func _sect_element() -> ElementTypes.ElementType:
	var sect := SectRegistry.get_by_id(_profile.sect_id)
	return sect.element if sect else ElementTypes.ElementType.HOA

func _add_stat(idx: int) -> void:
	if _profile == null or _profile.potential_points <= 0:
		_show_toast("Không còn điểm tiềm năng")
		return
	PotentialPointPopup.open(self, _profile, idx, func(added: int) -> void:
		if added > 0:
			SaveManager.save_profile(_profile)
			SaveManager.flush_online()
			refresh()
	)

func _setup_inventory_view() -> void:
	if %InvGrid:
		%InvGrid.visible = false
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
						SaveManager.save_profile(_profile)
						SaveManager.flush_online()
						refresh()
						_refresh_inventory_view()
						return true
			return false
		%InvScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		%InvScroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		%InvScroll.add_child(_room)
		TouchScrollHelperScript.attach(%InvScroll, %InventoryView.get_node_or_null("InvBox"))

	var bags := %BagTabs.get_children()
	for i in bags.size():
		var btn := bags[i] as Button
		if btn:
			btn.pressed.connect(_select_bag.bind(i))
			btn.set_drag_forwarding(Callable(), _can_drop_on_tab.bind(i), _drop_on_tab.bind(i))

	%SortButton.pressed.connect(_on_sort_pressed)
	%ShopButton.pressed.connect(func() -> void:
		PotionShopWindow.open(self, func() -> void:
			_refresh_inventory_view()
		)
	)
	%CraftButton.pressed.connect(func() -> void:
		_set_view("crafting")
	)
	if has_node("%TestCreateButton"):
		%TestCreateButton.pressed.connect(func() -> void:
			ItemCreatorPopup.open(self, _profile, func() -> void:
				SaveManager.save_profile(_profile)
				SaveManager.flush_online()
				refresh()
				_refresh_inventory_view()
			)
		)
	if has_node("%TestAddButton"):
		%TestAddButton.pressed.connect(func() -> void:
			if _profile == null:
				return
			for i in 10:
				_profile.add_item(ItemGenerator.random_equipment(_profile.level))
			SaveManager.save_profile(_profile)
			SaveManager.flush_online()
			refresh()
			_refresh_inventory_view()
			_show_toast("Đã thêm 10 trang bị ngẫu nhiên")
		)
	if has_node("%TestMaskButton"):
		%TestMaskButton.pressed.connect(func() -> void:
			if _profile == null:
				return
			var added := 0
			for p in 5:
				var mask_item := ItemGenerator.generate(ItemDatabase.Detail.MASK, p, 1, int(_profile.get_element()), [5, 5, 5, 5, 5, 5])
				if mask_item and _profile.add_item(mask_item):
					added += 1
			SaveManager.save_profile(_profile)
			SaveManager.flush_online()
			refresh()
			_refresh_inventory_view()
			_show_toast("Đã thêm %d Mặt Nạ vào hành trang!" % added)
		)
	if has_node("%TestMantleButton"):
		%TestMantleButton.pressed.connect(func() -> void:
			if _profile == null:
				return
			var added := 0
			for lv in [1, 3, 5, 6, 7]:
				var mantle_item := ItemGenerator.generate(ItemDatabase.Detail.MANTLE, 0, lv, int(_profile.get_element()), [6, 6, 6, 6, 6, 6])
				if mantle_item and _profile.add_item(mantle_item):
					added += 1
			SaveManager.save_profile(_profile)
			SaveManager.flush_online()
			refresh()
			_refresh_inventory_view()
			_show_toast("Đã thêm %d Phi Phong vào hành trang!" % added)
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
		_show_toast("Túi %d đã đầy chỗ cho món này" % (bag + 1))

func _setup_equipment_slots() -> void:
	for slot_name in SLOT_TO_PART:
		var btn: Button = get_node_or_null("%" + slot_name)
		if btn:
			var part: int = SLOT_TO_PART[slot_name]
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
	var icon := item.get_icon(false)
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
	ItemDetailPopup.open(get_tree().current_scene, desc, actions, item)

func _unequip_item(part: int, item: ItemInstance) -> void:
	if _profile.unequip(part):
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
		_show_toast("Đã tháo %s" % item.get_display_name())
		refresh()
		_refresh_inventory_view()
	else:
		_show_toast("Hành trang đã đầy, không thể tháo đồ!")

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
			_show_toast("Chưa gia nhập môn phái — đạt cấp %d để chọn phái" % PlayerProfile.NEWBIE_LEVEL)
		_set_view("character")
		return
	if _skills_view == null:
		_skills_view = SkillBookViewScript.new(_profile, _all_skills)
		_skills_view.set_docked(true, true)
		_skills_view.close_requested.connect(func() -> void: _set_view("character"))
		_skills_view.skill_changed.connect(func() -> void: refresh())
		%LeftPanel.add_child(_skills_view)
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
		_settings_view.setup_hub_actions(_on_change_server_pressed, _on_quit_game_pressed)
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
		"battle", "time_challenge":
			var win := MapSelectWindow.open(self, _profile, _enter_field_map)
			win._select_tab(1)
		"pk_arena":
			PkWindow.open(self, _profile, _enter_field_map)

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
		_show_toast("Túi %d chưa mở" % (bag_idx + 1))
		return
	_current_bag = bag_idx
	if _room:
		_room.bag = bag_idx
	_refresh_inventory_view()

func _refresh_inventory_view() -> void:
	if _profile == null:
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

	%InvGoldLabel.text = InventoryPopup.format_money(_profile.gold) + " Lượng"
	%InvJadeLabel.text = InventoryPopup.format_money(_profile.jade)

func _on_room_item_pressed(item: ItemInstance) -> void:
	if _profile == null or item == null:
		return
	var index := _profile.inventory.find(item)
	if index < 0:
		return
	var actions: Array = [
		["Trang bị", func() -> void: _equip_item_from_inv(index)],
		["Vứt bỏ", func() -> void: _drop_item_from_inv(index)],
	]
	if PotionEffect.usable(item):
		actions[0] = ["Dùng", func() -> void: _use_item_from_inv(index)]
	if _current_view == "crafting" and _crafting_view and is_instance_valid(_crafting_view):
		actions.insert(0, ["Đặt vào chế tạo", func() -> void: _crafting_view._put(item)])
	ItemDetailPopup.open(get_tree().current_scene, ItemText.build(item, _profile, -1, -1, false), actions, item)

func _equip_item_from_inv(index: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	var item: ItemInstance = _profile.inventory[index]
	var item_name := item.get_display_name()
	var err := _profile.equip_from_inventory(index)
	if err != "":
		_show_toast(err)
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
		_show_toast(blocked)
		return
	_profile.inventory.remove_at(index)
	_show_toast("Đã vứt %s" % item.get_display_name())
	SaveManager.save_profile(_profile)
	refresh()
	_refresh_inventory_view()

func _use_item_from_inv(index: int) -> void:
	if _profile == null or index < 0 or index >= _profile.inventory.size():
		return
	var item: ItemInstance = _profile.inventory[index]
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_show_toast("Chỉ dùng được thuốc khi đang ở trên bản đồ.")
		return
	var blocked := PotionEffect.block_reason(item)
	if blocked != "":
		_show_toast(blocked)
		return
	if PotionEffect.consume(_profile, player, item):
		_show_toast("Đã dùng %s" % item.get_display_name())
		SaveManager.save_profile(_profile)
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

func _show_toast(message: String) -> void:
	var toast: Label = %ToastLabel
	toast.text = message
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
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

static func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > 3:
		result = "." + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result

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
		var jade := top_bar.get_node_or_null("FrameCurrencyJade") as Control
		var stam := top_bar.get_node_or_null("FrameCurrencyStamina") as Control
		if gold:
			gold.offset_left = 760.0 + extra_w
			gold.offset_right = 910.0 + extra_w
		if jade:
			jade.offset_left = 924.0 + extra_w
			jade.offset_right = 1074.0 + extra_w
		if stam:
			stam.offset_left = 1088.0 + extra_w
			stam.offset_right = 1262.0 + extra_w

	# 2. RightPanel bám sát mép phải
	var right_panel := stage.get_node_or_null("RightPanel") as Control
	if right_panel:
		right_panel.offset_left = 1060.0 + extra_w
		right_panel.offset_right = 1262.0 + extra_w

	# 3. BottomBar & LevelTag bám sát mép phải
	var bot_bar := stage.get_node_or_null("BottomBar") as Control
	if bot_bar:
		bot_bar.size.x = vw
		var lvl := bot_bar.get_node_or_null("LevelTag") as Control
		if lvl:
			lvl.offset_left = 1135.0 + extra_w
			lvl.offset_right = 1262.0 + extra_w

	# 4. ToastLabel căn giữa màn hình
	var toast := stage.get_node_or_null("%ToastLabel") as Control
	if toast:
		var toast_w := 480.0
		toast.offset_left = (vw - toast_w) * 0.5
		toast.offset_right = toast.offset_left + toast_w

	# 5. Cân chỉnh khu vực giữa (LeftPanel / CenterPanel)
	var left_panel := stage.get_node_or_null("%LeftPanel") as Control
	var center_panel := stage.get_node_or_null("%CenterPanel") as Control
	var shift_center := extra_w * 0.5
	if left_panel and center_panel:
		left_panel.offset_left = shift_center * 0.35
		left_panel.offset_right = 545.0 + shift_center * 0.35
		center_panel.offset_left = 565.0 + shift_center * 0.35
		center_panel.offset_right = 1040.0 + shift_center * 0.35

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
	var win_w := win.size.x if win.size.x > 0 else 1000.0
	var desired_x := 18.0 + maxf(0.0, (avail_w - win_w) * 0.5)
	win.position.x = desired_x - left_p_offset

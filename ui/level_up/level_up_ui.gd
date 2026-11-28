extends CanvasLayer

signal initial_skill_selected

const GOLD = GameUi.GOLD
const TEXT_LIGHT = GameUi.TEXT

const DEFAULT_UPGRADE_PATHS: Array[String] = [
	"res://upgrades/damage_up.tres",
	"res://upgrades/attack_speed_up.tres",
	"res://upgrades/range_up.tres",
	"res://upgrades/move_speed_up.tres",
	"res://upgrades/hp_regen.tres",
	"res://upgrades/crit_chance_up.tres",
	"res://upgrades/shield_up.tres",
	"res://upgrades/pickup_radius_up.tres",
	"res://upgrades/freeze_on_hit.tres",
	"res://upgrades/stun_on_hit.tres",
	"res://upgrades/poison_on_hit.tres",
	"res://upgrades/explode_on_kill.tres",
	"res://upgrades/emergency_heal.tres",
]

@export var all_upgrades: Array[UpgradeData] = []
@export var choices_count: int = 3

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/Margin/VBox/TitleLabel
@onready var choices_container: HBoxContainer = $CenterContainer/Panel/Margin/VBox/ChoicesContainer

var _vbox: VBoxContainer
var _bottom_bar: HBoxContainer
var _reroll_button: Button
var _pending_level_ups: int = 0
var _initial_selection_shown: bool = false
var _is_initial_picking: bool = false
var _title_texture_rect: TextureRect = null

func _ready() -> void:
	add_to_group("level_up_ui")
	hide()
	_style_background()
	_init_all_upgrades()
	_setup_bottom_bar()
	PlayerStats.leveled_up.connect(_on_leveled_up)
	PlayerStats.stats_reset.connect(reset)

func _init_all_upgrades() -> void:
	# Tự động nạp toàn bộ danh mục nâng cấp mới nếu inspector chưa gán đủ
	if all_upgrades.size() < DEFAULT_UPGRADE_PATHS.size():
		var loaded_ids: Array[String] = []
		for u in all_upgrades:
			if u != null:
				loaded_ids.append(u.id)
		for path in DEFAULT_UPGRADE_PATHS:
			if ResourceLoader.exists(path):
				var up := load(path) as UpgradeData
				if up != null and not (up.id in loaded_ids):
					all_upgrades.append(up)
					loaded_ids.append(up.id)

func _style_background() -> void:
	GameUi.apply()
	dim_overlay.color = GameUi.DIM
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if panel != null:
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	if title_label != null:
		title_label.hide()

	if _title_texture_rect == null:
		_title_texture_rect = TextureRect.new()
		_title_texture_rect.name = "TitleLevelUpImage"
		var tex: Texture2D = null
		if ResourceLoader.exists("res://assets/ui/level_up_title.png"):
			tex = load("res://assets/ui/level_up_title.png") as Texture2D
		if tex == null and FileAccess.file_exists("res://assets/ui/level_up_title.png"):
			var img := Image.load_from_file("res://assets/ui/level_up_title.png")
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
		_title_texture_rect.texture = tex
		_title_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_title_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_title_texture_rect.custom_minimum_size = Vector2(285, 79)
		_title_texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var vbox := $CenterContainer/Panel/Margin/VBox as VBoxContainer
		if vbox != null:
			vbox.add_child(_title_texture_rect)
			vbox.move_child(_title_texture_rect, 0)

	var margin := $CenterContainer/Panel/Margin as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", 32)
		margin.add_theme_constant_override("margin_right", 32)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)

	if choices_container != null:
		choices_container.add_theme_constant_override("separation", 24)

func _setup_bottom_bar() -> void:
	_vbox = $CenterContainer/Panel/Margin/VBox as VBoxContainer
	if _vbox == null:
		return
	_vbox.add_theme_constant_override("separation", 24)

	_bottom_bar = HBoxContainer.new()
	_bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom_bar.add_theme_constant_override("separation", 20)
	_vbox.add_child(_bottom_bar)

	_reroll_button = Button.new()
	_reroll_button.custom_minimum_size = Vector2(220, 44)
	_reroll_button.focus_mode = Control.FOCUS_NONE
	_reroll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reroll_button.process_mode = Node.PROCESS_MODE_ALWAYS

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.14, 0.16, 0.95)
	btn_style.border_color = Color(0.85, 0.72, 0.28)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	_reroll_button.add_theme_stylebox_override("normal", btn_style)

	var btn_style_h := btn_style.duplicate() as StyleBoxFlat
	btn_style_h.bg_color = Color(0.18, 0.22, 0.26, 0.98)
	btn_style_h.border_color = Color(1.0, 0.88, 0.45)
	_reroll_button.add_theme_stylebox_override("hover", btn_style_h)
	_reroll_button.add_theme_stylebox_override("pressed", btn_style_h)

	var btn_style_d := btn_style.duplicate() as StyleBoxFlat
	btn_style_d.bg_color = Color(0.08, 0.09, 0.10, 0.7)
	btn_style_d.border_color = Color(0.4, 0.4, 0.4, 0.7)
	_reroll_button.add_theme_stylebox_override("disabled", btn_style_d)

	_reroll_button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45))
	_reroll_button.add_theme_font_size_override("font_size", 14)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_bottom_bar.add_child(_reroll_button)

func _update_reroll_button() -> void:
	if _reroll_button == null:
		return
	var rem := PlayerStats.rerolls_remaining
	_reroll_button.text = "🎲 Đổi Lại (Còn %d lượt)" % rem
	_reroll_button.disabled = rem <= 0
	if rem <= 0:
		_reroll_button.modulate = Color(0.6, 0.6, 0.6, 0.6)
	else:
		_reroll_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_reroll_pressed() -> void:
	if PlayerStats.rerolls_remaining > 0:
		PlayerStats.rerolls_remaining -= 1
		PlayerStats.rerolls_changed.emit(PlayerStats.rerolls_remaining)
		show_upgrade_choices()

func _on_leveled_up(_new_level: int) -> void:
	if not GameModeManager.is_offline() or (GameManager.game_mode != GameManager.GameMode.STAGE and not GameManager.field_map.get("survivor_mode", false)):
		return
	if visible:
		_pending_level_ups += 1
		return
	show_upgrade_choices()

func init_survivor_pool_if_needed() -> void:
	if not PlayerStats.survivor_pool.is_empty():
		return
	var prof := GameManager.local_profile
	var sect_id: String = prof.sect_id if prof and prof.sect_id != "" else "vo_dang"
	var w_class: int = Equipment.get_weapon_class(prof.equipment) if prof != null else -1
	var sm_cls = load("res://systems/survivor/survivor_manager.gd")
	if sm_cls != null and sm_cls.has_method("init_pool"):
		sm_cls.init_pool(sect_id, w_class)

## Lựa chọn kỹ năng ban đầu khi vừa vào trận (Mục 5.1 GDD)
## Kỹ năng được đề xuất phải thuộc bộ kỹ năng chiến đấu của môn phái và đúng với vũ khí đang cầm
func show_initial_skill_selection() -> void:
	if _initial_selection_shown:
		return
	_initial_selection_shown = true
	_is_initial_picking = true
	init_survivor_pool_if_needed()
	set_deferred_pause.call_deferred(true)
	show()
	if title_label != null:
		title_label.hide()
	if _title_texture_rect != null:
		_title_texture_rect.show()
	if _reroll_button != null:
		_reroll_button.hide()

	for child in choices_container.get_children():
		child.queue_free()

	var sect_def := SectRegistry.get_by_id(PlayerStats.survivor_sect_id)
	var pool_skills: Array[SkillDefinition] = []
	if sect_def != null:
		for s in sect_def.skills:
			if s.id in PlayerStats.survivor_pool:
				pool_skills.append(s)

	# Lọc theo vũ khí đang trang bị: Ưu tiên tuyệt đối kỹ năng tấn công khớp vũ khí
	var prof := GameManager.local_profile
	var w_class: int = Equipment.get_weapon_class(prof.equipment) if prof != null else -1

	var weapon_attacks: Array[SkillDefinition] = []
	for s in pool_skills:
		if s.weapon_limit == -2 or s.weapon_limit == w_class:
			weapon_attacks.append(s)

	weapon_attacks.shuffle()
	var initial_picks: Array[SkillDefinition] = []
	for s in weapon_attacks:
		if initial_picks.size() < choices_count:
			initial_picks.append(s)

	for skill in initial_picks:
		choices_container.add_child(_build_survivor_card(skill, true))

func show_upgrade_choices() -> void:
	init_survivor_pool_if_needed()
	set_deferred_pause.call_deferred(true)
	show()
	if title_label != null:
		title_label.hide()
	if _title_texture_rect != null:
		_title_texture_rect.show()
	if _reroll_button != null:
		_reroll_button.show()
	_update_reroll_button()

	for child in choices_container.get_children():
		child.queue_free()

	# 1. Danh sách Kỹ năng môn phái tấn công hợp lệ (chưa max 5 sao)
	var sect_def := SectRegistry.get_by_id(PlayerStats.survivor_sect_id)
	var available_skills: Array[SkillDefinition] = []
	if sect_def != null:
		for s in sect_def.skills:
			if s.id in PlayerStats.survivor_pool:
				var star := PlayerStats.get_skill_star(s.id)
				if star < 5:
					available_skills.append(s)

	# 2. Danh sách 12 Kỹ năng Bổ trợ Survivor Perks (chưa max 5 tầng)
	var available_perk_ids: Array[String] = []
	for perk_key in SurvivorPerks.PERK_DEFINITIONS.keys():
		if not SurvivorPerks.is_perk_maxed(perk_key):
			available_perk_ids.append(perk_key)

	# 3. Gộp các ứng viên và xáo trộn ngẫu nhiên
	var candidates: Array[Dictionary] = []
	for s in available_skills:
		candidates.append({"type": "skill", "data": s})
	for p_id in available_perk_ids:
		candidates.append({"type": "perk", "data": p_id})

	candidates.shuffle()

	var picks: Array[Dictionary] = []
	while picks.size() < choices_count and not candidates.is_empty():
		picks.append(candidates.pop_front())

	for item in picks:
		if item["type"] == "skill":
			choices_container.add_child(_build_survivor_card(item["data"], false))
		else:
			choices_container.add_child(_build_perk_card(item["data"]))

	# Dự phòng nếu toàn bộ kỹ năng & perks đã max hết
	if choices_container.get_child_count() == 0:
		hide()
		set_deferred_pause.call_deferred(false)

func _build_survivor_card(skill: SkillDefinition, is_initial: bool) -> Control:
	var current_star := PlayerStats.get_skill_star(skill.id)
	var next_star := 1 if current_star == 0 else mini(5, current_star + 1)
	
	var card := Button.new()
	card.custom_minimum_size = Vector2(240, 330)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.clip_contents = true

	var border_color := Color(1.0, 0.82, 0.25) if next_star == 5 else (Color(0.82, 0.42, 1.0) if next_star >= 3 else Color(0.28, 0.65, 1.0))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.08, 0.09, 0.96)
	st.border_color = border_color
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(12)
	card.add_theme_stylebox_override("normal", st)

	var hover_st := st.duplicate() as StyleBoxFlat
	hover_st.bg_color = Color(0.10, 0.14, 0.16, 0.98)
	hover_st.border_color = border_color.lightened(0.25)
	hover_st.set_border_width_all(3)
	card.add_theme_stylebox_override("hover", hover_st)

	var pressed_st := st.duplicate() as StyleBoxFlat
	pressed_st.bg_color = Color(0.14, 0.18, 0.22, 1.0)
	pressed_st.border_color = border_color.lightened(0.4)
	pressed_st.set_border_width_all(3)
	card.add_theme_stylebox_override("pressed", pressed_st)

	var margin_c := MarginContainer.new()
	margin_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_c.add_theme_constant_override("margin_left", 14)
	margin_c.add_theme_constant_override("margin_right", 14)
	margin_c.add_theme_constant_override("margin_top", 14)
	margin_c.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin_c)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin_c.add_child(vbox)

	# 1. Badge Sao
	var badge := Label.new()
	if is_initial or current_star == 0:
		badge.text = "✦ MỚI: ⭐ (1 Sao) ✦"
		badge.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	elif next_star == 5:
		badge.text = "👑 ⭐⭐⭐⭐⭐ TỐI ĐA 👑"
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		badge.text = "⭐ %d Sao ➔ ⭐ %d Sao" % [current_star, next_star]
		badge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)

	# 2. Icon Kỹ Năng (ảnh to lên x2, không có border)
	if skill.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = skill.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(112, 112)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_rect)

	# 3. Tiêu đề Kỹ Năng
	var title := Label.new()
	title.text = skill.skill_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.add_theme_font_size_override("font_size", 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# 4. Mô tả chi tiết số lượng chiêu thức phóng ra theo sao
	var desc := Label.new()
	if current_star == 0:
		desc.text = "Kích hoạt thi triển kỹ năng.\nSố lượng chiêu: Cấp 1⭐"
	else:
		desc.text = "Nâng lên cấp sao %d!\nSố chiêu phóng ra tăng gấp %d lần cơ bản." % [next_star, next_star]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))
	desc.add_theme_font_size_override("font_size", 12)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.pressed.connect(_on_survivor_skill_chosen.bind(skill))
	return card

func _on_survivor_skill_chosen(skill: SkillDefinition) -> void:
	var sm_cls = load("res://systems/survivor/survivor_manager.gd")
	if sm_cls != null and sm_cls.has_method("add_or_upgrade_skill"):
		sm_cls.add_or_upgrade_skill(skill.id)
	var new_star := PlayerStats.add_or_upgrade_survivor_skill(skill.id)
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var p: Node = tree.get_first_node_in_group("player") if tree != null else null
	if p and p.has_method("notify"):
		p.notify("★ Kỹ năng [%s] đã đạt %d Sao!" % [skill.skill_name, new_star])
	
	# Gán làm kỹ năng chính (đánh thường / ra chiêu) nếu cần
	if p and "skill_controller" in p and p.skill_controller != null:
		if GameManager.local_profile != null:
			GameManager.local_profile.main_skill_id = skill.id
		if p.skill_controller.has_method("refresh_equipped_skills"):
			p.skill_controller.refresh_equipped_skills()

	# Đảm bảo có SurvivorCombatAgent tự động thi triển
	if p and not p.has_node("SurvivorCombatAgent"):
		var agent_script = load("res://systems/survivor/survivor_combat_agent.gd")
		if agent_script:
			var agent = agent_script.new()
			agent.name = "SurvivorCombatAgent"
			p.add_child(agent)
	
	if _pending_level_ups > 0:
		_pending_level_ups -= 1
		show_upgrade_choices()
		return
	hide()
	set_deferred_pause.call_deferred(false)
	if _is_initial_picking:
		_is_initial_picking = false
		initial_skill_selected.emit()

func _build_perk_card(perk_id: String) -> Control:
	var def: Dictionary = SurvivorPerks.PERK_DEFINITIONS.get(perk_id, {})
	var current_lvl := SurvivorPerks.get_perk_level(perk_id)
	var next_lvl := mini(5, current_lvl + 1)

	var card := Button.new()
	card.custom_minimum_size = Vector2(240, 330)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.clip_contents = true

	var border_color := Color(1.0, 0.82, 0.25) if next_lvl == 5 else (Color(0.82, 0.42, 1.0) if next_lvl >= 3 else Color(0.28, 0.65, 1.0))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.08, 0.09, 0.96)
	st.border_color = border_color
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(12)
	card.add_theme_stylebox_override("normal", st)

	var hover_st := st.duplicate() as StyleBoxFlat
	hover_st.bg_color = Color(0.10, 0.14, 0.16, 0.98)
	hover_st.border_color = border_color.lightened(0.25)
	hover_st.set_border_width_all(3)
	card.add_theme_stylebox_override("hover", hover_st)

	var pressed_st := st.duplicate() as StyleBoxFlat
	pressed_st.bg_color = Color(0.14, 0.18, 0.22, 1.0)
	pressed_st.border_color = border_color.lightened(0.4)
	pressed_st.set_border_width_all(3)
	card.add_theme_stylebox_override("pressed", pressed_st)

	var margin_c := MarginContainer.new()
	margin_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_c.add_theme_constant_override("margin_left", 14)
	margin_c.add_theme_constant_override("margin_right", 14)
	margin_c.add_theme_constant_override("margin_top", 14)
	margin_c.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin_c)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin_c.add_child(vbox)

	# 1. Badge Tầng
	var badge := Label.new()
	if current_lvl == 0:
		badge.text = "✦ MỚI: TẦNG 1 ⭐ ✦"
		badge.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	elif next_lvl == 5:
		badge.text = "👑 ⭐⭐⭐⭐⭐ TỐI ĐA 👑"
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		badge.text = "⭐ Tầng %d ➔ ⭐ Tầng %d" % [current_lvl, next_lvl]
		badge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)

	# 2. Icon Perk (ảnh to lên x2, không có border)
	var icon_tex := SurvivorPerks.get_perk_icon(perk_id)
	if icon_tex != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(112, 112)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_rect)

	# 3. Tiêu đề Perk
	var title := Label.new()
	title.text = str(def.get("name", perk_id))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.add_theme_font_size_override("font_size", 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# 4. Mô tả chi tiết tầng tiếp theo
	var desc := Label.new()
	var desc_levels: Array = def.get("desc_levels", [])
	if next_lvl - 1 >= 0 and next_lvl - 1 < desc_levels.size():
		desc.text = str(desc_levels[next_lvl - 1])
	else:
		desc.text = str(def.get("subtitle", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))
	desc.add_theme_font_size_override("font_size", 12)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.pressed.connect(_on_survivor_perk_chosen.bind(perk_id))
	return card

func _on_survivor_perk_chosen(perk_id: String) -> void:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var p: CharacterBody2D = tree.get_first_node_in_group("player") as CharacterBody2D if tree != null else null
	var nxt_lvl := SurvivorPerks.upgrade_perk(perk_id, p)
	var def: Dictionary = SurvivorPerks.PERK_DEFINITIONS.get(perk_id, {})
	if p and p.has_method("notify"):
		p.notify("★ [%s] đạt Tầng %d! ★" % [def.get("name", perk_id), nxt_lvl])

	if _pending_level_ups > 0:
		_pending_level_ups -= 1
		show_upgrade_choices()
		return
	hide()
	set_deferred_pause.call_deferred(false)

func _build_card(upgrade: UpgradeData) -> Control:
	var rarity_info := _get_rarity_info(upgrade.rarity)

	var card := Button.new()
	card.custom_minimum_size = Vector2(240, 330)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.clip_contents = true

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.08, 0.09, 0.96)
	st.border_color = rarity_info.border_color
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(12)
	card.add_theme_stylebox_override("normal", st)

	var hover_st := st.duplicate() as StyleBoxFlat
	hover_st.bg_color = Color(0.10, 0.14, 0.16, 0.98)
	hover_st.border_color = rarity_info.border_color.lightened(0.25)
	hover_st.set_border_width_all(3)
	card.add_theme_stylebox_override("hover", hover_st)

	var pressed_st := st.duplicate() as StyleBoxFlat
	pressed_st.bg_color = Color(0.14, 0.18, 0.22, 1.0)
	pressed_st.border_color = rarity_info.border_color.lightened(0.4)
	pressed_st.set_border_width_all(3)
	card.add_theme_stylebox_override("pressed", pressed_st)

	var margin_c := MarginContainer.new()
	margin_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_c.add_theme_constant_override("margin_left", 14)
	margin_c.add_theme_constant_override("margin_right", 14)
	margin_c.add_theme_constant_override("margin_top", 14)
	margin_c.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin_c)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin_c.add_child(vbox)

	# 1. Badge phẩm chất (Phổ thông / Tinh anh / Sử thi / Hoàng Kim)
	var badge := Label.new()
	badge.text = rarity_info.badge_text
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", rarity_info.badge_color)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)

	# 2. Icon nâng cấp (ảnh to lên x2, không có border)
	if upgrade.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = upgrade.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(112, 112)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_rect)

	# 3. Tiêu đề
	var title := Label.new()
	title.text = upgrade.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", rarity_info.title_color)
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# 4. Mô tả chi tiết
	var desc := Label.new()
	desc.text = upgrade.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))
	desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(desc)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.pressed.connect(_on_upgrade_chosen.bind(upgrade))
	return card

func _get_rarity_info(rarity: int) -> Dictionary:
	match rarity:
		UpgradeData.Rarity.RARE:
			return {
				"border_color": Color(0.28, 0.65, 1.0),
				"badge_text": "✦ TINH ANH ✦",
				"badge_color": Color(0.45, 0.82, 1.0),
				"title_color": Color(0.65, 0.90, 1.0)
			}
		UpgradeData.Rarity.EPIC:
			return {
				"border_color": Color(0.82, 0.42, 1.0),
				"badge_text": "◆ SỬ THI ◆",
				"badge_color": Color(0.88, 0.55, 1.0),
				"title_color": Color(0.92, 0.70, 1.0)
			}
		UpgradeData.Rarity.LEGENDARY:
			return {
				"border_color": Color(1.0, 0.82, 0.25),
				"badge_text": "👑 HOÀNG KIM 👑",
				"badge_color": Color(1.0, 0.85, 0.35),
				"title_color": Color(1.0, 0.92, 0.45)
			}
		_: # COMMON
			return {
				"border_color": Color(0.35, 0.75, 0.45),
				"badge_text": "★ PHỔ THÔNG ★",
				"badge_color": Color(0.48, 0.85, 0.55),
				"title_color": Color(0.95, 0.95, 0.95)
			}

func _on_upgrade_chosen(upgrade: UpgradeData) -> void:
	PlayerStats.apply_upgrade(upgrade)
	if _pending_level_ups > 0:
		_pending_level_ups -= 1
		show_upgrade_choices()
		return
	hide()
	set_deferred_pause.call_deferred(false)
	if _is_initial_picking:
		_is_initial_picking = false
		initial_skill_selected.emit()

func set_deferred_pause(value: bool) -> void:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		if not value and GameManager.current_stage != null:
			if tree.current_scene != null and tree.current_scene.has_method("is_any_menu_window_open") and tree.current_scene.is_any_menu_window_open():
				return
		tree.paused = value

func reset() -> void:
	_pending_level_ups = 0
	_initial_selection_shown = false
	_is_initial_picking = false
	if choices_container != null:
		for child in choices_container.get_children():
			child.queue_free()
	hide()
	set_deferred_pause.call_deferred(false)

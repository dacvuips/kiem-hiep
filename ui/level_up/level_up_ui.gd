extends CanvasLayer

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

func _ready() -> void:
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

func _setup_bottom_bar() -> void:
	_vbox = $CenterContainer/Panel/Margin/VBox as VBoxContainer
	if _vbox == null:
		return

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
	if visible:
		_pending_level_ups += 1
		return
	show_upgrade_choices()

func show_upgrade_choices() -> void:
	set_deferred_pause.call_deferred(true)
	show()
	_update_reroll_button()

	for child in choices_container.get_children():
		child.queue_free()

	# Lọc các nâng cấp hợp lệ (chưa bị khóa bởi is_unique)
	var available := all_upgrades.filter(func(u):
		return u != null and not (u.is_unique and u.id in PlayerStats.applied_upgrade_ids)
	)

	# Kiểm tra nếu máu nhân vật đang thấp (< 35%), ưu tiên đưa thẻ Cứu Nguy Khẩn Cấp vào
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var player: Node = tree.get_first_node_in_group("player") if tree != null else null
	var is_low_hp := false
	if player != null and "health" in player and "max_health" in player and player.max_health > 0:
		is_low_hp = (player.health / player.max_health) < 0.35

	var picks: Array[UpgradeData] = []
	if is_low_hp:
		for u in available:
			if u.stat_type == UpgradeData.StatType.EMERGENCY_HEAL:
				picks.append(u)
				available.erase(u)
				break

	available.shuffle()
	while picks.size() < choices_count and not available.is_empty():
		picks.append(available.pop_front())

	for upgrade in picks:
		choices_container.add_child(_build_card(upgrade))

func _build_card(upgrade: UpgradeData) -> Control:
	var rarity_info := _get_rarity_info(upgrade.rarity)

	var card := Button.new()
	card.custom_minimum_size = Vector2(215, 275)
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

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(vbox)

	# 1. Badge phẩm chất (Phổ thông / Tinh anh / Sử thi / Hoàng Kim)
	var badge := Label.new()
	badge.text = rarity_info.badge_text
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", rarity_info.badge_color)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)

	# 2. Icon nâng cấp
	if upgrade.icon:
		var icon_box := PanelContainer.new()
		icon_box.custom_minimum_size = Vector2(72, 72)
		icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ib_style := StyleBoxFlat.new()
		ib_style.bg_color = Color(0.03, 0.04, 0.05, 0.9)
		ib_style.border_color = rarity_info.border_color.darkened(0.2)
		ib_style.set_border_width_all(1)
		ib_style.set_corner_radius_all(8)
		icon_box.add_theme_stylebox_override("panel", ib_style)
		vbox.add_child(icon_box)

		var icon_rect := TextureRect.new()
		icon_rect.texture = upgrade.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(56, 56)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_box.add_child(icon_rect)

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

func set_deferred_pause(value: bool) -> void:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		if not value and GameManager.current_stage != null:
			if tree.current_scene != null and tree.current_scene.has_method("is_any_menu_window_open") and tree.current_scene.is_any_menu_window_open():
				return
		tree.paused = value

func reset() -> void:
	_pending_level_ups = 0
	if choices_container != null:
		for child in choices_container.get_children():
			child.queue_free()
	hide()
	set_deferred_pause.call_deferred(false)

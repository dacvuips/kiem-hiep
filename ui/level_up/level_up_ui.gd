extends CanvasLayer

const GOLD = Color(0.83, 0.68, 0.21)
const GOLD_DIM = Color(0, 0, 0)
const PANEL_BG = Color(0.06, 0.07, 0.1, 0.96)
const CARD_BG = Color(0.1, 0.12, 0.16, 1.0)
const CARD_BG_HOVER = Color(0.16, 0.18, 0.24, 1.0)
const TEXT_LIGHT = Color(0.92, 0.92, 0.9)
const TEXT_DIM = Color(0.65, 0.65, 0.62)

## Kéo các file UpgradeData (.tres) vào đây trong Inspector — đây là "sổ danh mục"
## nâng cấp. Muốn thêm nâng cấp mới, chỉ cần tạo thêm 1 UpgradeData và thêm vào danh sách này.
@export var all_upgrades: Array[UpgradeData] = []

@export var choices_count: int = 4

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/Margin/VBox/TitleLabel
@onready var choices_container: HBoxContainer = $CenterContainer/Panel/Margin/VBox/ChoicesContainer

## Số lượt "chờ hiện bảng nâng cấp" chưa xử lý — cần thiết vì PlayerStats.add_exp() có thể lên
## NHIỀU LEVEL trong CÙNG 1 FRAME (VD Nam Châm hút dồn nhiều gem EXP cùng lúc), khiến
## leveled_up bắn liên tiếp nhiều lần trước khi người chơi kịp chọn nâng cấp nào. Không dùng
## hàng đợi sẽ khiến lần gọi show_upgrade_choices() sau ĐÈ LÊN lần trước, làm mất lượt chọn của
## các level đã lên nhưng chưa kịp hiển thị (đúng triệu chứng "chỉ chọn được bảng ở cuối").
var _pending_level_ups: int = 0

func _ready() -> void:
	hide()
	_style_background()
	PlayerStats.leveled_up.connect(_on_leveled_up)

func _style_background() -> void:
	dim_overlay.color = Color(0, 0, 0, 0.65)
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = GOLD
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_color_override("font_color", GOLD)
	title_label.add_theme_font_size_override("font_size", 28)

func _on_leveled_up(_new_level: int) -> void:
	## Đang hiện 1 bảng chưa xử lý xong — xếp hàng thay vì gọi show_upgrade_choices() ngay,
	## tránh ghi đè mất lượt chọn của level hiện tại đang chờ người chơi bấm.
	if visible:
		_pending_level_ups += 1
		return
	show_upgrade_choices()

func show_upgrade_choices() -> void:
	set_deferred_pause.call_deferred(true)
	show()

	for child in choices_container.get_children():
		child.queue_free()

	var available := all_upgrades.filter(func(u): return not (u.is_unique and u.id in PlayerStats.applied_upgrade_ids))
	available.shuffle()
	var picks := available.slice(0, choices_count)

	for upgrade in picks:
		choices_container.add_child(_build_card(upgrade))

func _build_card(upgrade: UpgradeData) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(200, 240)
	card.clip_text = false
	card.focus_mode = Control.FOCUS_NONE

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = CARD_BG
	normal_style.border_color = GOLD_DIM
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.set_content_margin_all(12)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = CARD_BG_HOVER
	hover_style.border_color = GOLD

	card.add_theme_stylebox_override("normal", normal_style)
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", hover_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if upgrade.icon:
		var icon_margin := MarginContainer.new()
		icon_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_margin.add_theme_constant_override("margin_left", 0)
		icon_margin.add_theme_constant_override("margin_right", 0)
		icon_margin.add_theme_constant_override("margin_top", 0)
		icon_margin.add_theme_constant_override("margin_bottom", 0)
		vbox.add_child(icon_margin)

		var icon_rect := TextureRect.new()
		icon_rect.texture = upgrade.icon
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(100, 100)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_margin.add_child(icon_rect)

	var text_margin := MarginContainer.new()
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_margin.add_theme_constant_override("margin_left", 4)
	text_margin.add_theme_constant_override("margin_right", 4)
	text_margin.add_theme_constant_override("margin_top", 4)
	text_margin.add_theme_constant_override("margin_bottom", 4)
	vbox.add_child(text_margin)

	var text_vbox := VBoxContainer.new()
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_theme_constant_override("separation", 8)
	text_margin.add_child(text_vbox)

	var title := Label.new()
	title.text = upgrade.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", TEXT_LIGHT)
	title.add_theme_font_size_override("font_size", 19)
	text_vbox.add_child(title)

	var desc := Label.new()
	desc.text = upgrade.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_theme_color_override("font_color", GOLD)
	desc.add_theme_font_size_override("font_size", 16)
	text_vbox.add_child(desc)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.pressed.connect(_on_upgrade_chosen.bind(upgrade))
	return card

func _on_upgrade_chosen(upgrade: UpgradeData) -> void:
	PlayerStats.apply_upgrade(upgrade)
	## Còn level đang xếp hàng chờ (lên nhiều level dồn dập trong 1 frame) — mở tiếp bảng kế
	## tiếp ngay, KHÔNG unpause giữa chừng, để người chơi lần lượt chọn đủ nâng cấp cho từng
	## level đã đạt được thay vì chỉ chọn được 1 lần cho tất cả.
	if _pending_level_ups > 0:
		_pending_level_ups -= 1
		show_upgrade_choices()
		return
	hide()
	set_deferred_pause.call_deferred(false)

func set_deferred_pause(value: bool) -> void:
	get_tree().paused = value

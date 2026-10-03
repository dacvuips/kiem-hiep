extends CanvasLayer
class_name StageSelectScreen
## Màn "Chọn Ải" — liệt kê TOÀN BỘ StageData (Character Hub Screen truyền vào, xem
## CharacterHubScreen.stages), cho người chơi chọn map cụ thể để vào trận thay vì chỉ chơi tuần
## tự map tiếp theo. Map chưa mở khóa (vượt quá profile.stages_cleared) hiện mờ, không bấm được.
##
## Dùng chung style/pattern với SkillBookScreen (CanvasLayer overlay dựng bằng code, không .tscn
## riêng) — xem file đó nếu cần đối chiếu cách viết.

const GOLD := Color(0.83, 0.68, 0.21)
const PANEL_BG := Color(0.04, 0.09, 0.06, 0.9)
const CARD_BG_UNLOCKED := Color(0.1, 0.14, 0.1, 0.9)
const CARD_BG_LOCKED := Color(0.08, 0.08, 0.08, 0.85)
const BORDER_UNLOCKED := Color(0.3, 0.75, 0.35, 1.0)
const BORDER_LOCKED := Color(0.3, 0.3, 0.3, 1.0)
const TEXT_LIGHT := Color(0.92, 0.92, 0.9)
const TEXT_DIM := Color(0.55, 0.55, 0.52)

var _profile: PlayerProfile
var _stages: Array[StageData] = []
var _on_stage_chosen: Callable  ## Callable(stage: StageData) -> void — gọi khi bấm 1 map đã mở khóa.
var _on_closed: Callable

## Mở màn chọn ải. `on_stage_chosen` được gọi với StageData người chơi vừa bấm chọn (màn này TỰ
## đóng trước khi gọi callback, không cần callback tự queue_free()). `on_closed` gọi khi bấm Đóng
## mà KHÔNG chọn gì (nút Đóng/back), để nơi gọi biết phân biệt 2 trường hợp — truyền
## `func() -> void: pass` nếu nơi gọi không cần xử lý gì khi đóng.
static func open(parent: Node, profile: PlayerProfile, stages: Array[StageData],
		on_stage_chosen: Callable, on_closed: Callable) -> void:
	var screen := StageSelectScreen.new()
	screen._profile = profile
	screen._stages = stages
	screen._on_stage_chosen = on_stage_chosen
	screen._on_closed = on_closed
	parent.add_child(screen)

func _ready() -> void:
	layer = 55  ## Trên SkillBookScreen (50) một chút để không lẫn nếu vô tình mở cùng lúc.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = GOLD
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Chọn Ải"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, min(_stages.size() * 96, 480))
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.custom_minimum_size.x = 400
	scroll.add_child(list)

	for i in _stages.size():
		list.add_child(_build_stage_card(_stages[i], i))

	var close_button := Button.new()
	close_button.text = "Đóng"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)

func _build_stage_card(stage: StageData, index: int) -> Control:
	var is_unlocked := index <= _profile.stages_cleared
	var is_completed := index < _profile.stages_cleared

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 80)
	button.disabled = not is_unlocked
	button.focus_mode = Control.FOCUS_NONE
	if is_unlocked:
		button.pressed.connect(_on_stage_pressed.bind(stage))

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG_UNLOCKED if is_unlocked else CARD_BG_LOCKED
	style.border_color = BORDER_UNLOCKED if is_unlocked else BORDER_LOCKED
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	if is_unlocked:
		var hover := style.duplicate()
		hover.border_color = GOLD
		button.add_theme_stylebox_override("hover", hover)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	button.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = "%d. %s" % [index + 1, stage.stage_name]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", TEXT_LIGHT if is_unlocked else TEXT_DIM)
	info.add_child(name_label)

	var detail_label := Label.new()
	var boss_text := stage.boss_tier.tier.tier_name if stage.boss_tier and stage.boss_tier.tier else "—"
	detail_label.text = "Boss: %s   •   %d loại quái" % [boss_text, stage.enemy_tiers.size()]
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", TEXT_DIM)
	info.add_child(detail_label)

	var status_label := Label.new()
	if not is_unlocked:
		status_label.text = "🔒 Khoá"
		status_label.add_theme_color_override("font_color", TEXT_DIM)
	elif is_completed:
		status_label.text = "✓ Đã vượt"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
	else:
		status_label.text = "▶ Đang chơi"
		status_label.add_theme_color_override("font_color", GOLD)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(status_label)

	return button

func _on_stage_pressed(stage: StageData) -> void:
	queue_free()
	_on_stage_chosen.call(stage)

func _on_close_pressed() -> void:
	_on_closed.call()
	queue_free()

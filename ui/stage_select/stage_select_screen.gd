extends CanvasLayer
class_name StageSelectScreen

const StageRewards = preload("res://systems/stage_rewards.gd")
const TouchScrollHelperScript = preload("res://ui/common/touch_scroll_helper.gd")
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
	if parent == null or not is_instance_valid(parent):
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.current_scene != null:
			parent = tree.current_scene
		else:
			return
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
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var max_scroll_h := clampf(get_viewport().get_visible_rect().size.y - 180.0, 240.0, 560.0)
	scroll.custom_minimum_size = Vector2(660, minf(_stages.size() * 118.0, max_scroll_h))
	vbox.add_child(scroll)
	TouchScrollHelperScript.attach(scroll, vbox)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for i in _stages.size():
		list.add_child(_build_stage_card(_stages[i], i))

	var close_button := Button.new()
	close_button.text = "Đóng"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)

func _build_stage_card(stage: StageData, index: int) -> Control:
	var is_admin := AccountApi.is_gm()
	var is_unlocked := is_admin or index <= _profile.stages_cleared
	var is_completed := index < _profile.stages_cleared

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 108)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.disabled = not is_unlocked
	button.focus_mode = Control.FOCUS_NONE
	if is_unlocked:
		button.pressed.connect(_on_stage_pressed.bind(stage))

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG_UNLOCKED if is_unlocked else CARD_BG_LOCKED
	style.border_color = BORDER_UNLOCKED if is_unlocked else BORDER_LOCKED
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	if is_unlocked:
		var hover := style.duplicate()
		hover.border_color = GOLD
		button.add_theme_stylebox_override("hover", hover)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	button.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# Khung ảnh thu nhỏ xem trước của bàn chơi (Stage Thumbnail)
	var thumb_box := PanelContainer.new()
	thumb_box.custom_minimum_size = Vector2(96, 68)
	thumb_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.04, 0.05, 0.06, 0.95)
	t_style.border_color = BORDER_UNLOCKED if is_unlocked else BORDER_LOCKED
	t_style.set_border_width_all(1)
	t_style.set_corner_radius_all(4)
	thumb_box.add_theme_stylebox_override("panel", t_style)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(92, 64)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.texture = stage.get_preview_texture() if stage.has_method("get_preview_texture") else null
	thumb_box.add_child(thumb)
	hbox.add_child(thumb_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = "%d. %s" % [index + 1, stage.stage_name]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", TEXT_LIGHT if is_unlocked else TEXT_DIM)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(name_label)

	var detail_label := Label.new()
	var boss_text := stage.boss_tier.tier.tier_name if stage.boss_tier and stage.boss_tier.tier else "—"
	detail_label.text = "Boss: %s   •   %d loại quái" % [boss_text, stage.enemy_tiers.size()]
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", TEXT_DIM)
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(detail_label)

	# Hàng hiển thị các ô phần thưởng xem trước
	var rewards_row := HBoxContainer.new()
	rewards_row.mouse_filter = Control.MOUSE_FILTER_PASS
	rewards_row.add_theme_constant_override("separation", 10)
	info.add_child(rewards_row)

	var rw_lbl := Label.new()
	rw_lbl.text = "Thưởng:"
	rw_lbl.add_theme_font_size_override("font_size", 11)
	rw_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72) if is_unlocked else TEXT_DIM)
	rw_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rewards_row.add_child(rw_lbl)

	var previews := StageRewards.get_previews_for_stage(stage, index)
	for p in previews:
		rewards_row.add_child(_build_reward_slot(p, is_unlocked))

	var status_label := Label.new()
	if not is_unlocked:
		status_label.text = "🔒 Khoá"
		status_label.add_theme_color_override("font_color", TEXT_DIM)
	elif is_completed:
		status_label.text = "✓ Đã vượt"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
	elif is_admin and index > _profile.stages_cleared:
		status_label.text = "✦ Mở khoá"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	else:
		status_label.text = "▶ Đang chơi"
		status_label.add_theme_color_override("font_color", GOLD)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size = Vector2(90, 0)
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(status_label)

	return button

func _build_reward_slot(p: Dictionary, is_unlocked: bool) -> Control:
	var item_box := HBoxContainer.new()
	item_box.add_theme_constant_override("separation", 4)
	item_box.tooltip_text = str(p.get("tooltip", ""))
	item_box.mouse_filter = Control.MOUSE_FILTER_PASS

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(28, 28)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.05, 0.06, 0.95)
	st.border_color = (p.get("border_color", Color(0.5, 0.5, 0.5)) as Color) if is_unlocked else Color(0.3, 0.3, 0.3)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", st)
	item_box.add_child(icon_box)

	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(24, 24)
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = p.get("icon_path", "")
	if ResourceLoader.exists(icon_path):
		tex.texture = load(icon_path)
	if not is_unlocked:
		tex.modulate = Color(0.5, 0.5, 0.5, 0.6)
	icon_box.add_child(tex)

	var badge := Label.new()
	badge.text = str(p.get("badge", ""))
	badge.add_theme_font_size_override("font_size", 11)
	var badge_col: Color = p.get("border_color", Color(0.8, 0.8, 0.8)) if is_unlocked else TEXT_DIM
	badge.add_theme_color_override("font_color", badge_col)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_box.add_child(badge)

	return item_box

func _on_stage_pressed(stage: StageData) -> void:
	var cb := _on_stage_chosen
	queue_free()
	if cb.is_valid():
		cb.call(stage)

func _on_close_pressed() -> void:
	var cb := _on_closed
	queue_free()
	if cb.is_valid():
		cb.call()

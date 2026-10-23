extends CanvasLayer
class_name StageVictoryPopup

const StageRewards = preload("res://systems/stage_rewards.gd")

## Bảng chúc mừng và trao phần thưởng khi đánh bại Boss vượt ải thành công.
## Hiển thị đầy đủ hình ảnh, cấp độ của Huyền Tinh, Trang bị, Ngân lượng và vật phẩm nhận được.

const HUB_SCENE_PATH := "res://ui/character_hub/CharacterHub.tscn"

var _rewards: Dictionary = {}
var _on_close: Callable

static func show_reward(host: Node, rewards: Dictionary, on_close: Callable = Callable()) -> StageVictoryPopup:
	if host == null or not is_instance_valid(host):
		return null
	var tree := host.get_tree() if host.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var popup := StageVictoryPopup.new()
	popup._rewards = rewards
	popup._on_close = on_close
	tree.current_scene.add_child(popup)
	return popup

func _init() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.70)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.07, 0.96)
	p_style.border_color = Color(0.96, 0.78, 0.25)
	p_style.set_border_width_all(3)
	p_style.set_corner_radius_all(12)
	p_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Tiêu đề chiến thắng
	var title := Label.new()
	title.text = "★ VƯỢT ẢI THÀNH CÔNG ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	vbox.add_child(title)

	var stage_title := Label.new()
	stage_title.text = str(_rewards.get("stage_name", "Ải Vượt Ải"))
	stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_title.add_theme_font_size_override("font_size", 16)
	stage_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(stage_title)

	var sub := Label.new()
	sub.text = "Đại hiệp đã xuất sắc đánh bại Thủ Quan! Dưới đây là phần thưởng nhận được:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.78, 0.80, 0.78))
	vbox.add_child(sub)

	# Khung hiển thị các món quà
	var rewards_box := PanelContainer.new()
	var rb_style := StyleBoxFlat.new()
	rb_style.bg_color = Color(0.03, 0.04, 0.04, 0.9)
	rb_style.border_color = Color(0.25, 0.28, 0.26)
	rb_style.set_border_width_all(1)
	rb_style.set_corner_radius_all(8)
	rb_style.set_content_margin_all(12)
	rewards_box.add_theme_stylebox_override("panel", rb_style)
	vbox.add_child(rewards_box)

	var items_list := VBoxContainer.new()
	items_list.add_theme_constant_override("separation", 8)
	rewards_box.add_child(items_list)

	# 1. Điểm Kinh Nghiệm (cộng trực tiếp vào cấp thật)
	var exp_val: int = int(_rewards.get("exp", 0))
	if exp_val > 0:
		var exp_icon := load(StageRewards.ICON_EXP) as Texture2D
		var levels_gained: int = int(_rewards.get("levels_gained", 0))
		var sub_txt := "Kinh nghiệm đã cộng trực tiếp vào cấp thật của nhân vật"
		if levels_gained > 0:
			sub_txt = "★ Chúc mừng đại hiệp thăng cấp lên Cấp %d (+%d điểm tiềm năng & kỹ năng)!" % [
				int(_rewards.get("new_level", 0)), levels_gained
			]
		items_list.add_child(_build_reward_row(
			exp_icon,
			"+%s EXP" % StageRewards.format_number(exp_val),
			sub_txt,
			Color(0.35, 0.90, 0.50)
		))

	# 2. Viên Huyền Tinh
	var ht_item: ItemInstance = _rewards.get("huyen_tinh")
	if ht_item != null:
		items_list.add_child(_build_reward_row(
			ht_item.get_icon(),
			ht_item.get_display_name(),
			"Huyền Tinh Khoáng Thạch dùng để luyện chế, tách khoáng và khảm nạm",
			ht_item.get_quality_color()
		))

	# 2. Trang Bị
	var equip_item: ItemInstance = _rewards.get("equipment")
	if equip_item != null:
		var eq_icon := equip_item.get_icon()
		if eq_icon == null:
			eq_icon = load(StageRewards.ICON_EQUIP)
		items_list.add_child(_build_reward_row(
			eq_icon,
			equip_item.get_display_name(),
			"Trang bị ngũ hành cấp %d với các dòng thuộc tính ẩn/hiện" % equip_item.get_level(),
			equip_item.get_quality_color()
		))

	# 3. Ngân lượng
	var gold_val: int = int(_rewards.get("gold", 0))
	if gold_val > 0:
		var gold_icon := load(StageRewards.ICON_MONEY) as Texture2D
		items_list.add_child(_build_reward_row(
			gold_icon,
			"+%s" % StageRewards.format_money(gold_val),
			"Ngân lượng đã được nạp trực tiếp vào túi tiền nhân vật",
			Color(0.96, 0.82, 0.38)
		))

	# 4. Vật phẩm may mắn nếu có
	var extra_item: ItemInstance = _rewards.get("extra_item")
	if extra_item != null:
		items_list.add_child(_build_reward_row(
			extra_item.get_icon(),
			"★ Thưởng thêm: " + extra_item.get_display_name(),
			"Vật phẩm quý hiếm nhận được nhờ cơ duyên may mắn",
			Color(1.0, 0.65, 0.25)
		))

	# Cảnh báo nếu túi đầy
	if bool(_rewards.get("bag_full", false)):
		var warn := Label.new()
		warn.text = "⚠ Hành trang của đại hiệp đã đầy! Một số vật phẩm tạm thời chưa thể đưa vào túi."
		warn.add_theme_font_size_override("font_size", 12)
		warn.add_theme_color_override("font_color", Color(0.98, 0.45, 0.35))
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(warn)

	# Nút bấm hành động
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var btn_stay := Button.new()
	btn_stay.text = "Ở lại bản đồ"
	btn_stay.custom_minimum_size = Vector2(160, 42)
	btn_stay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var stay_style := StyleBoxFlat.new()
	stay_style.bg_color = Color(0.12, 0.15, 0.13)
	stay_style.border_color = Color(0.4, 0.45, 0.4)
	stay_style.set_border_width_all(1)
	stay_style.set_corner_radius_all(6)
	btn_stay.add_theme_stylebox_override("normal", stay_style)
	btn_stay.pressed.connect(_on_stay_pressed)
	btn_row.add_child(btn_stay)

	var btn_home := Button.new()
	btn_home.text = "Về Thành Dưỡng Sức"
	btn_home.custom_minimum_size = Vector2(200, 42)
	btn_home.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var home_style := StyleBoxFlat.new()
	home_style.bg_color = Color(0.76, 0.68, 0.45)
	home_style.border_color = Color(0.96, 0.85, 0.3)
	home_style.set_border_width_all(2)
	home_style.set_corner_radius_all(6)
	btn_home.add_theme_stylebox_override("normal", home_style)
	btn_home.add_theme_color_override("font_color", Color(0.12, 0.08, 0.03))
	btn_home.pressed.connect(_on_home_pressed)
	btn_row.add_child(btn_home)

func _build_reward_row(icon_tex: Texture2D, title_text: String, desc_text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Khung icon
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(46, 46)
	var ib_style := StyleBoxFlat.new()
	ib_style.bg_color = Color(0.08, 0.10, 0.10)
	ib_style.border_color = color
	ib_style.set_border_width_all(2)
	ib_style.set_corner_radius_all(6)
	icon_box.add_theme_stylebox_override("panel", ib_style)
	row.add_child(icon_box)

	var tex_rect := TextureRect.new()
	tex_rect.texture = icon_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(40, 40)
	tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.add_child(tex_rect)

	# Thông tin chữ
	var info_box := VBoxContainer.new()
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_box)

	var lbl_name := Label.new()
	lbl_name.text = title_text
	lbl_name.add_theme_font_size_override("font_size", 15)
	lbl_name.add_theme_color_override("font_color", color)
	info_box.add_child(lbl_name)

	var lbl_desc := Label.new()
	lbl_desc.text = desc_text
	lbl_desc.add_theme_font_size_override("font_size", 12)
	lbl_desc.add_theme_color_override("font_color", Color(0.65, 0.68, 0.65))
	info_box.add_child(lbl_desc)

	return row

func _on_stay_pressed() -> void:
	PlayerStats.reset()
	get_tree().paused = false
	var cb := _on_close
	queue_free()
	if cb.is_valid():
		cb.call()

func _on_home_pressed() -> void:
	PlayerStats.reset()
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file(HUB_SCENE_PATH)

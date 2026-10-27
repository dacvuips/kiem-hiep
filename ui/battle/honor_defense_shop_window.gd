extends CanvasLayer
class_name HonorDefenseShopWindow

## CỬA HÀNG CHIÊU MỘ BOSS ĐỒNG MINH THỦ TRỤ (DẠNG GRID + ẢNH BOSS + POPUP THÔNG TIN)
## Hiển thị lưới danh sách thẻ Boss kèm ảnh đại diện chân dung, giá tiền,
## nút Chiêu Mộ rộng rãi và icon ℹ️ để nhấp vào xem bảng chi tiết thuộc tính & kỹ năng.

signal boss_purchased(boss_id: String, cost: int)

const ALLY_ROSTER := [
	{
		"id": "tanker",
		"name": "Thiên Vương Thiết Kỵ",
		"sect": "Thiên Vương Bang",
		"role": "Khiên Thịt & Chặn Quái",
		"res": "boss001",
		"hp": "50.000 HP",
		"dps": "1.250 DPS",
		"range": "Cận chiến (80px)",
		"skill_name": "Kim Chung Tráo & Đoạn Hồn Thích",
		"skill_desc": "Xông vào đàn quái khiêu khích chúng đánh mình, giảm 50% sát thương nhận vào để che chắn an toàn cho Long Trụ.",
		"desc": "Máu dày 50.000 HP, thu hút quái và chịu đòn thay Trụ.",
		"cost": 200,
		"color": Color(1.0, 0.85, 0.25)
	},
	{
		"id": "healer",
		"name": "Nga Mi Thánh Nữ",
		"sect": "Nga Mi Phái",
		"role": "Hồi Máu Long Trụ",
		"res": "boss002",
		"hp": "20.000 HP",
		"dps": "750 DPS",
		"range": "Tầm xa (350px)",
		"skill_name": "Từ Hàng Phổ Độ (Đại Thừa)",
		"skill_desc": "Thi triển hào quang Phật quang phổ chiếu, mỗi 5 giây hồi phục 1.500 HP trực tiếp cho Long Trụ và đồng minh xung quanh.",
		"desc": "Thi triển Từ Hàng Phổ Độ hồi 1.500 HP cho Trụ mỗi 5s.",
		"cost": 350,
		"color": Color(0.35, 1.0, 0.6)
	},
	{
		"id": "trapper",
		"name": "Đường Môn Cơ Quan Sư",
		"sect": "Đường Môn",
		"role": "Khống Chế & Làm Chậm",
		"res": "boss003",
		"hp": "25.000 HP",
		"dps": "1.750 DPS",
		"range": "Tầm xa (400px)",
		"skill_name": "Địa Diễm Hỏa Bẫy & Bão Vũ Tiêu",
		"skill_desc": "Rải cạm bẫy diện rộng làm chậm 50% tốc chạy của quái và phóng phi tiêu liên hoàn chặn đứng đường hành quân.",
		"desc": "Bắn bão tiêu tầm xa và đặt bẫy làm chậm 50% tốc độ quái.",
		"cost": 450,
		"color": Color(0.4, 0.8, 1.0)
	},
	{
		"id": "sword",
		"name": "Võ Đang Kiếm Thánh",
		"sect": "Võ Đang Phái",
		"role": "Sát Thương Diện Rộng",
		"res": "boss006",
		"hp": "35.000 HP",
		"dps": "3.000 DPS",
		"range": "Tầm trung (250px)",
		"skill_name": "Vạn Kiếm Quy Tông & Thái Cực Khí",
		"skill_desc": "Phóng bão kiếm khí Thái Cực bao phủ bán kính 600px, xé toạc và càn quét mọi đàn quái đông đảo áp sát đài chiến.",
		"desc": "Phóng Thái Cực Kiếm Khí càn quét sạch đàn quái.",
		"cost": 600,
		"color": Color(0.9, 0.6, 1.0)
	},
	{
		"id": "beast",
		"name": "Thiên Sơn Thần Thú",
		"sect": "Kỳ Lân Thần Thú",
		"role": "Chiến Thú Hoàng Kim",
		"res": "ani001",
		"hp": "75.000 HP",
		"dps": "4.000 DPS",
		"range": "Cận chiến (120px)",
		"skill_name": "Cuồng Nộ Hổ Khiếu",
		"skill_desc": "Hóa thân chiến thú thượng cổ, sức tấn công và sinh lực x3 lần, miễn nhiễm mọi hiệu ứng khống chế, càn quét tiêu diệt mọi kẻ thù.",
		"desc": "Chiến thú huyền thoại, sức mạnh x3 lần, càn quét mọi kẻ thù.",
		"cost": 1000,
		"color": Color(1.0, 0.4, 0.2)
	}
]

var current_points: int = 0
var _points_label: Label = null
var _grid: GridContainer = null

func _ready() -> void:
	layer = 120
	_build_ui()

func set_points(pts: int) -> void:
	current_points = pts
	if _points_label != null:
		_points_label.text = "🪙 Điểm Thủ Trụ Hiện Có: %d" % current_points
	_update_buttons()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.72)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 560)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.13, 0.98)
	panel_style.border_color = Color(0.85, 0.7, 0.25)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 10)
	margin.add_child(v_box)

	# --- HEADER ---
	var h_box := HBoxContainer.new()
	v_box.add_child(h_box)

	var title := Label.new()
	title.text = "⚔ CHIÊU MỘ BOSS ĐỒNG MINH THỦ TRỤ ⚔"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	h_box.add_child(title)

	var close_btn := Button.new()
	close_btn.text = " ✕ Đóng "
	close_btn.custom_minimum_size = Vector2(80, 32)
	close_btn.pressed.connect(queue_free)
	h_box.add_child(close_btn)

	# --- THANH ĐIỂM THƯỞNG ---
	var pts_row := HBoxContainer.new()
	v_box.add_child(pts_row)

	_points_label = Label.new()
	_points_label.text = "🪙 Điểm Thủ Trụ Hiện Có: %d" % current_points
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points_label.add_theme_font_size_override("font_size", 15)
	_points_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	pts_row.add_child(_points_label)

	var tip := Label.new()
	tip.text = "💡 Nhấp nút ℹ️ trên thẻ để xem bảng chỉ số & kỹ năng"
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	pts_row.add_child(tip)

	# --- DANH SÁCH DẠNG GRID (3 CỘT) ---
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v_box.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)

	for boss in ALLY_ROSTER:
		_add_boss_card(boss)

func _add_boss_card(boss: Dictionary) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 260)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.14, 0.19, 0.95)
	card_style.border_color = Color(0.4, 0.45, 0.55, 0.7)
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)
	_grid.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)

	var card_v := VBoxContainer.new()
	card_v.add_theme_constant_override("separation", 6)
	m.add_child(card_v)

	# 1. ẢNH BOSS + ICON THÔNG TIN ℹ️ TRÊN GÓC
	var img_box := Control.new()
	img_box.custom_minimum_size = Vector2(0, 90)
	card_v.add_child(img_box)

	var img_panel := PanelContainer.new()
	img_panel.set_anchors_preset(Control.PRESET_CENTER)
	img_panel.custom_minimum_size = Vector2(84, 84)
	img_panel.position = Vector2((210 - 84) * 0.5, 3)

	var img_style := StyleBoxFlat.new()
	img_style.bg_color = Color(0.06, 0.08, 0.11)
	img_style.border_color = boss["color"]
	img_style.border_width_left = 2
	img_style.border_width_right = 2
	img_style.border_width_top = 2
	img_style.border_width_bottom = 2
	img_style.corner_radius_top_left = 6
	img_style.corner_radius_top_right = 6
	img_style.corner_radius_bottom_left = 6
	img_style.corner_radius_bottom_right = 6
	img_panel.add_theme_stylebox_override("panel", img_style)
	img_box.add_child(img_panel)

	# Nạp ảnh chân dung Boss từ MonsterData.thumb()
	var thumb_tex: Texture2D = MonsterData.thumb(str(boss["res"]))
	var thumb_rect := TextureRect.new()
	thumb_rect.texture = thumb_tex
	thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_rect.custom_minimum_size = Vector2(76, 76)
	img_panel.add_child(thumb_rect)

	# Nút icon thông tin ℹ️ góc trên-phải
	var info_btn := Button.new()
	info_btn.text = "ℹ️"
	info_btn.tooltip_text = "Nhấp để xem chi tiết kỹ năng và chỉ số"
	info_btn.custom_minimum_size = Vector2(28, 28)
	info_btn.position = Vector2(178, 2)
	info_btn.pressed.connect(_show_detail_popup.bind(boss))
	img_box.add_child(info_btn)

	# 2. TÊN BOSS
	var name_lbl := Label.new()
	name_lbl.text = str(boss["name"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", boss["color"])
	card_v.add_child(name_lbl)

	# 3. VAI TRÒ
	var role_lbl := Label.new()
	role_lbl.text = str(boss["role"])
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	card_v.add_child(role_lbl)

	# 4. GIÁ TIỀN
	var cost_lbl := Label.new()
	cost_lbl.text = "🪙 %d Điểm" % int(boss["cost"])
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	card_v.add_child(cost_lbl)

	# 5. HÀNG NÚT: CHIÊU MỘ + CHI TIẾT
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	card_v.add_child(btn_row)

	var detail_btn := Button.new()
	detail_btn.text = "🔍 Chi Tiết"
	detail_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_btn.custom_minimum_size = Vector2(0, 32)
	detail_btn.add_theme_font_size_override("font_size", 12)
	detail_btn.pressed.connect(_show_detail_popup.bind(boss))
	btn_row.add_child(detail_btn)

	var buy_btn := Button.new()
	buy_btn.text = "Chiêu Mộ"
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.custom_minimum_size = Vector2(0, 32)
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.set_meta("boss_id", boss["id"])
	buy_btn.set_meta("cost", boss["cost"])
	buy_btn.pressed.connect(_on_buy_pressed.bind(str(boss["id"]), int(boss["cost"])))
	btn_row.add_child(buy_btn)

func _update_buttons() -> void:
	if _grid == null:
		return
	for card in _grid.get_children():
		var buy_btn: Button = card.find_child("Chiêu Mộ", true, false)
		if buy_btn == null:
			# Tìm qua meta
			for b in card.find_children("*", "Button"):
				if b.has_meta("cost"):
					buy_btn = b
					break
		if buy_btn != null and buy_btn.has_meta("cost"):
			var cost: int = buy_btn.get_meta("cost")
			buy_btn.disabled = (current_points < cost)

func _on_buy_pressed(boss_id: String, cost: int) -> void:
	if current_points >= cost:
		boss_purchased.emit(boss_id, cost)
		set_points(current_points - cost)

## POPUP HIỂN THỊ THÔNG TIN CHI TIẾT CỦA BOSS KHI NHẤP ICON ℹ️
func _show_detail_popup(boss: Dictionary) -> void:
	var popup_layer := CanvasLayer.new()
	popup_layer.layer = 130
	add_child(popup_layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	popup_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_layer.add_child(center)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(500, 420)

	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.08, 0.1, 0.14, 0.98)
	box_style.border_color = boss["color"]
	box_style.border_width_left = 2
	box_style.border_width_right = 2
	box_style.border_width_top = 2
	box_style.border_width_bottom = 2
	box_style.corner_radius_top_left = 8
	box_style.corner_radius_top_right = 8
	box_style.corner_radius_bottom_left = 8
	box_style.corner_radius_bottom_right = 8
	box.add_theme_stylebox_override("panel", box_style)
	center.add_child(box)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	box.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	# 1. Header
	var title_lbl := Label.new()
	title_lbl.text = "✦ THÔNG TIN DANH TƯỚNG VIỆN BINH ✦"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	v.add_child(title_lbl)

	v.add_child(HSeparator.new())

	# 2. Khối Avatar + Thông tin cơ bản
	var h_info := HBoxContainer.new()
	h_info.add_theme_constant_override("separation", 16)
	v.add_child(h_info)

	var avatar_panel := PanelContainer.new()
	avatar_panel.custom_minimum_size = Vector2(100, 100)
	var av_style := StyleBoxFlat.new()
	av_style.bg_color = Color(0.05, 0.07, 0.1)
	av_style.border_color = boss["color"]
	av_style.border_width_left = 2
	av_style.border_width_right = 2
	av_style.border_width_top = 2
	av_style.border_width_bottom = 2
	av_style.corner_radius_top_left = 6
	av_style.corner_radius_top_right = 6
	av_style.corner_radius_bottom_left = 6
	av_style.corner_radius_bottom_right = 6
	avatar_panel.add_theme_stylebox_override("panel", av_style)
	h_info.add_child(avatar_panel)

	var big_thumb := TextureRect.new()
	big_thumb.texture = MonsterData.thumb(str(boss["res"]))
	big_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big_thumb.custom_minimum_size = Vector2(92, 92)
	avatar_panel.add_child(big_thumb)

	var stats_v := VBoxContainer.new()
	stats_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_v.add_theme_constant_override("separation", 3)
	h_info.add_child(stats_v)

	var name_lbl2 := Label.new()
	name_lbl2.text = str(boss["name"]) + " (" + str(boss["sect"]) + ")"
	name_lbl2.add_theme_font_size_override("font_size", 15)
	name_lbl2.add_theme_color_override("font_color", boss["color"])
	stats_v.add_child(name_lbl2)

	stats_v.add_child(SocialUi.label("Vai trò: " + str(boss["role"]), SocialUi.GOLD, 13))
	stats_v.add_child(SocialUi.label("Sinh lực: " + str(boss["hp"]), SocialUi.LABEL_BLUE, 13))
	stats_v.add_child(SocialUi.label("Sát thương: " + str(boss["dps"]), SocialUi.TEXT, 13))
	stats_v.add_child(SocialUi.label("Tầm đánh: " + str(boss["range"]), SocialUi.MUTED, 12))

	v.add_child(HSeparator.new())

	# 3. Kỹ năng đặc biệt
	var skill_title := Label.new()
	skill_title.text = "⚔ Kỹ Năng: " + str(boss["skill_name"])
	skill_title.add_theme_font_size_override("font_size", 14)
	skill_title.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0))
	v.add_child(skill_title)

	var skill_desc_lbl := Label.new()
	skill_desc_lbl.text = str(boss["skill_desc"])
	skill_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_desc_lbl.add_theme_font_size_override("font_size", 13)
	skill_desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	v.add_child(skill_desc_lbl)

	v.add_child(HSeparator.new())

	# 4. Hàng nút thao tác
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 16)
	v.add_child(action_row)

	var close_btn2 := Button.new()
	close_btn2.text = "Đóng"
	close_btn2.custom_minimum_size = Vector2(120, 36)
	close_btn2.pressed.connect(popup_layer.queue_free)
	action_row.add_child(close_btn2)

	var hire_now_btn := Button.new()
	hire_now_btn.text = "Chiêu Mộ Ngay (🪙 %d)" % int(boss["cost"])
	hire_now_btn.custom_minimum_size = Vector2(180, 36)
	hire_now_btn.disabled = (current_points < int(boss["cost"]))
	hire_now_btn.pressed.connect(func() -> void:
		_on_buy_pressed(str(boss["id"]), int(boss["cost"]))
		popup_layer.queue_free()
	)
	action_row.add_child(hire_now_btn)

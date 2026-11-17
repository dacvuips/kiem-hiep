extends CanvasLayer
class_name ThuThanhSeedPickerDialog

## GIAO DIỆN CHỌN KỸ NĂNG TRƯỚC TRẬN THỦ THÀNH (ZOMBIES VS PLANTS SEED PICKER)
## Tham chiếu Hình 2 (Thanh 14 ô hạt giống) & Hình 3 (Bảng chọn thẻ bài Zombies vs Plants)

signal started(selected_skill_ids: Array[String], starting_coins: int)
signal canceled()

const ThuThanhSkillData := preload("res://systems/challenge/thu_thanh_skill_data.gd")

var map_tier: int = 1
var char_level: int = 10
var thu_thanh_level: int = 10
var unlocked_slots: int = 5
var selected_skill_ids: Array[String] = []

var _slot_buttons: Array[Button] = []
var _library_cards: Dictionary = {}  ## skill_id -> Control
var _library_plus_buttons: Dictionary = {}  ## skill_id -> Button
var _library_level_labels: Dictionary = {}  ## skill_id -> Label
var _tt_level_lbl: Label
var _skill_points_lbl: Label
var _coin_val_lbl: Label
var _start_btn: Button
var _element_filter: String = "Tất cả"
var _library_container: VBoxContainer
var _element_buttons: Array[Button] = []

func setup(p_map_tier: int, p_char_level: int) -> void:
	map_tier = p_map_tier
	thu_thanh_level = ThuThanhSkillData.get_thu_thanh_level()
	char_level = thu_thanh_level # Đồng bộ cấp Thủ Thành làm chuẩn xét kỹ năng
	unlocked_slots = ThuThanhSkillData.get_unlocked_slots_for_tier(map_tier)

	# 1. Khôi phục danh sách kỹ năng đã chọn trước đó (lưu bền vững khi thoát game)
	var saved_picks := ThuThanhSkillData.get_saved_selected_skills()
	if not saved_picks.is_empty():
		selected_skill_ids.clear()
		for sid in saved_picks:
			var sid_str := str(sid)
			if sid_str == "quan_nhu":
				continue
			var s := ThuThanhSkillData.get_skill(sid_str)
			if not s.is_empty():
				var req_lvl := int(s.get("req_level", 10))
				if thu_thanh_level >= req_lvl and selected_skill_ids.size() < unlocked_slots:
					selected_skill_ids.append(sid_str)

	# 2. Gợi ý đội hình kỹ năng môn phái chuẩn theo số ô đã mở nếu chưa từng chọn
	if selected_skill_ids.is_empty():
		var default_picks: Array[String] = [
			"thieu_lam", "cai_bang", "con_lon", "ngu_doc",
			"hoa_son", "thuy_yen", "duong_mon_tk", "vo_dang",
			"nga_mi", "thien_vuong", "thien_nhan", "duong_mon",
			"duong_gia_20", "tieu_dao_20"
		]
		for sid in default_picks:
			var s := ThuThanhSkillData.get_skill(sid)
			var req_lvl := int(s.get("req_level", 10))
			if thu_thanh_level >= req_lvl and selected_skill_ids.size() < unlocked_slots:
				selected_skill_ids.append(sid)

func _ready() -> void:
	layer = 100
	_build_ui()
	_update_state()

func _build_ui() -> void:
	# Lớp nền mờ tối
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	main_vbox.offset_left = 40.0
	main_vbox.offset_right = -40.0
	main_vbox.offset_top = 20.0
	main_vbox.offset_bottom = -20.0

	# Thiết lập Theme cho Tooltip: Nền đen mun sẫm đặc (giảm tối đa độ trong suốt), viền vàng hoàng kim
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0.04, 0.03, 0.02, 0.98)  ## Đen mun đặc 98%, triệt tiêu độ mờ trong suốt
	tip_sb.border_width_left = 2
	tip_sb.border_width_top = 2
	tip_sb.border_width_right = 2
	tip_sb.border_width_bottom = 2
	tip_sb.border_color = Color(0.85, 0.70, 0.30, 0.98)  ## Viền mạ vàng hoàng kim sang trọng
	tip_sb.set_content_margin_all(10)
	tip_sb.corner_radius_top_left = 6
	tip_sb.corner_radius_top_right = 6
	tip_sb.corner_radius_bottom_left = 6
	tip_sb.corner_radius_bottom_right = 6
	tip_sb.shadow_color = Color(0, 0, 0, 0.7)
	tip_sb.shadow_size = 4

	var picker_theme := Theme.new()
	picker_theme.set_stylebox("panel", "TooltipPanel", tip_sb)
	picker_theme.set_color("font_color", "TooltipLabel", Color(1.0, 0.95, 0.85))
	picker_theme.set_color("font_shadow_color", "TooltipLabel", Color.BLACK)
	picker_theme.set_constant("shadow_offset_x", "TooltipLabel", 1)
	picker_theme.set_constant("shadow_offset_y", "TooltipLabel", 1)
	picker_theme.set_font_size("font_size", "TooltipLabel", 13)
	main_vbox.theme = picker_theme

	add_child(main_vbox)

	# -------------------------------------------------------------
	# 1. TOP: THANH 14 Ô KỸ NĂNG (SEED BANK - CHỦ ĐỀ KIẾM HIỆP VLTK)
	# -------------------------------------------------------------
	var top_panel := PanelContainer.new()
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color(0.08, 0.06, 0.05, 0.98)   ## Màu gỗ mun huyền thạch VLTK
	top_sb.border_width_left = 2
	top_sb.border_width_top = 2
	top_sb.border_width_right = 2
	top_sb.border_width_bottom = 2
	top_sb.border_color = Color(0.80, 0.65, 0.28, 0.95) ## Viền mạ vàng hoàng kim
	top_sb.corner_radius_top_left = 6
	top_sb.corner_radius_top_right = 6
	top_sb.corner_radius_bottom_left = 6
	top_sb.corner_radius_bottom_right = 6
	top_panel.add_theme_stylebox_override("panel", top_sb)
	main_vbox.add_child(top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	top_panel.add_child(top_hbox)

	# Khung đếm Xu khởi đầu bên trái thanh gỗ
	var coin_box := VBoxContainer.new()
	coin_box.custom_minimum_size = Vector2(85, 75)
	coin_box.alignment = BoxContainer.ALIGNMENT_CENTER

	var coin_ico := TextureRect.new()
	var coin_tex_path := "res://assets/ui/bo_icon_nhan_vat/tai_nguyen/ico_vang.png"
	if ResourceLoader.exists(coin_tex_path):
		coin_ico.texture = load(coin_tex_path)
	coin_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_ico.custom_minimum_size = Vector2(32, 32)
	coin_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_box.add_child(coin_ico)

	_coin_val_lbl = Label.new()
	_coin_val_lbl.text = "Xu: 0"
	_coin_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_val_lbl.add_theme_font_size_override("font_size", 13)
	_coin_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	_coin_val_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_coin_val_lbl.add_theme_constant_override("outline_size", 2)
	coin_box.add_child(_coin_val_lbl)
	top_hbox.add_child(coin_box)

	# 14 ô chứa thẻ kỹ năng
	_slot_buttons.clear()
	for i in ThuThanhSkillData.TOTAL_SLOTS:
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(72, 75)
		slot_btn.clip_contents = true

		var slot_sb := StyleBoxFlat.new()
		slot_sb.bg_color = Color(0.06, 0.05, 0.04, 0.96)
		slot_sb.border_width_left = 1
		slot_sb.border_width_top = 1
		slot_sb.border_width_right = 1
		slot_sb.border_width_bottom = 1
		slot_sb.border_color = Color(0.55, 0.42, 0.22, 0.85)
		slot_sb.corner_radius_top_left = 4
		slot_sb.corner_radius_top_right = 4
		slot_sb.corner_radius_bottom_left = 4
		slot_sb.corner_radius_bottom_right = 4
		slot_btn.add_theme_stylebox_override("normal", slot_sb)

		var slot_idx := i
		slot_btn.pressed.connect(func() -> void: _on_slot_clicked(slot_idx))
		top_hbox.add_child(slot_btn)
		_slot_buttons.append(slot_btn)

	# -------------------------------------------------------------
	# 2. CENTER: BẢNG CHỌN THẺ THƯ VIỆN KỸ NĂNG (CHỦ ĐỀ KIẾM HIỆP VLTK)
	# -------------------------------------------------------------
	var mid_panel := PanelContainer.new()
	mid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mid_sb := StyleBoxFlat.new()
	mid_sb.bg_color = Color(0.06, 0.05, 0.04, 0.98)  ## Nền huyền hắc ánh nâu cổ phong
	mid_sb.border_width_left = 2
	mid_sb.border_width_top = 2
	mid_sb.border_width_right = 2
	mid_sb.border_width_bottom = 2
	mid_sb.border_color = Color(0.85, 0.70, 0.30, 0.95)  ## Viền vàng hoàng kim sang trọng
	mid_sb.corner_radius_top_left = 6
	mid_sb.corner_radius_top_right = 6
	mid_sb.corner_radius_bottom_left = 6
	mid_sb.corner_radius_bottom_right = 6
	mid_panel.add_theme_stylebox_override("panel", mid_sb)
	main_vbox.add_child(mid_panel)

	var mid_vbox := VBoxContainer.new()
	mid_vbox.add_theme_constant_override("separation", 8)
	mid_panel.add_child(mid_vbox)

	var title_hbox := HBoxContainer.new()
	mid_vbox.add_child(title_hbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(40, 0)
	title_hbox.add_child(spacer)

	var title_lbl := Label.new()
	title_lbl.text = "THƯ VIỆN HIỆP KHÁCH MÔN PHÁI — ĐỘI HÌNH THỦ THÀNH (Mở %d/%d ô)" % [unlocked_slots, ThuThanhSkillData.TOTAL_SLOTS]
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_hbox.add_child(title_lbl)

	var close_top_btn := Button.new()
	close_top_btn.text = "✕"
	close_top_btn.custom_minimum_size = Vector2(36, 28)
	close_top_btn.tooltip_text = "Thoát ra Sảnh Chính (ESC)"
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0.35, 0.15, 0.15, 0.8)
	close_sb.border_width_left = 1
	close_sb.border_width_top = 1
	close_sb.border_width_right = 1
	close_sb.border_width_bottom = 1
	close_sb.border_color = Color(0.65, 0.25, 0.25)
	close_sb.corner_radius_top_left = 4
	close_sb.corner_radius_top_right = 4
	close_sb.corner_radius_bottom_left = 4
	close_sb.corner_radius_bottom_right = 4
	close_top_btn.add_theme_stylebox_override("normal", close_sb)
	close_top_btn.pressed.connect(_on_exit_pressed)
	title_hbox.add_child(close_top_btn)

	var sub_lbl := Label.new()
	sub_lbl.text = "Chọn Hiệp Khách xuất trận — Mỗi Hiệp Khách sẽ trực tiếp đứng trên bàn cờ thi triển võ công trấn phái!"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	mid_vbox.add_child(sub_lbl)

	# Khung hiển thị Cấp Độ Thủ Thành (PvZ), EXP & Điểm Kỹ Năng
	var pts_vbox := VBoxContainer.new()
	pts_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pts_vbox.add_theme_constant_override("separation", 5)
	mid_vbox.add_child(pts_vbox)

	var info_hbox := HBoxContainer.new()
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_theme_constant_override("separation", 16)
	pts_vbox.add_child(info_hbox)

	var cur_lvl := ThuThanhSkillData.get_thu_thanh_level()
	var cur_xp := ThuThanhSkillData.get_thu_thanh_exp()
	var next_xp := ThuThanhSkillData.get_exp_to_next_level(cur_lvl)

	_tt_level_lbl = Label.new()
	_tt_level_lbl.text = "🎖️ Cấp Độ Thủ Thành: Lv.%d (EXP: %d/%d)" % [cur_lvl, cur_xp, next_xp]
	_tt_level_lbl.add_theme_font_size_override("font_size", 13)
	_tt_level_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	_tt_level_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_tt_level_lbl.add_theme_constant_override("outline_size", 2)
	info_hbox.add_child(_tt_level_lbl)

	_skill_points_lbl = Label.new()
	_skill_points_lbl.text = "⭐ Điểm Kỹ Năng: %d" % ThuThanhSkillData.get_skill_points()
	_skill_points_lbl.add_theme_font_size_override("font_size", 13)
	_skill_points_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_skill_points_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_skill_points_lbl.add_theme_constant_override("outline_size", 2)
	info_hbox.add_child(_skill_points_lbl)

	var ctrl_hbox := HBoxContainer.new()
	ctrl_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl_hbox.add_theme_constant_override("separation", 8)
	pts_vbox.add_child(ctrl_hbox)

	var add_lvl_btn := Button.new()
	add_lvl_btn.text = "+1 Cấp (+10 Đ)"
	add_lvl_btn.custom_minimum_size = Vector2(105, 22)
	add_lvl_btn.add_theme_font_size_override("font_size", 10)
	add_lvl_btn.tooltip_text = "Tăng ngay 1 Cấp Thủ Thành và nhận thêm 10 điểm kỹ năng!"
	add_lvl_btn.pressed.connect(func() -> void:
		var needed := ThuThanhSkillData.get_exp_to_next_level()
		ThuThanhSkillData.add_thu_thanh_exp(needed)
		thu_thanh_level = ThuThanhSkillData.get_thu_thanh_level()
		char_level = thu_thanh_level
		_refresh_library()
		_refresh_all_card_levels()
	)
	ctrl_hbox.add_child(add_lvl_btn)

	var add_pts_btn := Button.new()
	add_pts_btn.text = "+10 Điểm"
	add_pts_btn.custom_minimum_size = Vector2(75, 22)
	add_pts_btn.add_theme_font_size_override("font_size", 10)
	add_pts_btn.tooltip_text = "Nhận thêm 10 điểm kỹ năng để thử nghiệm cộng cấp kỹ năng!"
	add_pts_btn.pressed.connect(func() -> void:
		ThuThanhSkillData.add_skill_points(10)
		_refresh_all_card_levels()
	)
	ctrl_hbox.add_child(add_pts_btn)

	var reset_pts_btn := Button.new()
	reset_pts_btn.text = "Tẩy Điểm"
	reset_pts_btn.custom_minimum_size = Vector2(65, 22)
	reset_pts_btn.add_theme_font_size_override("font_size", 10)
	reset_pts_btn.tooltip_text = "Hoàn trả toàn bộ điểm kỹ năng đã cộng về túi để phân bổ lại từ đầu!"
	reset_pts_btn.pressed.connect(func() -> void:
		ThuThanhSkillData.reset_skills()
		_refresh_all_card_levels()
	)
	ctrl_hbox.add_child(reset_pts_btn)

	var pts_note := Label.new()
	pts_note.text = "(Mỗi cấp +10 điểm; Điểm CHỈ được cộng cho kỹ năng có cấp <= Cấp Thủ Thành hiện tại)"
	pts_note.add_theme_font_size_override("font_size", 10)
	pts_note.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	ctrl_hbox.add_child(pts_note)

	# -------------------------------------------------------------
	# BỘ LỌC KỸ NĂNG THEO HỆ & CẤP ĐỘ (MỤC 4 DOC ĐẶC TẢ)
	# -------------------------------------------------------------
	# Hàng: Lọc theo Hệ Ngũ Hành
	var elem_hbox := HBoxContainer.new()
	elem_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	elem_hbox.add_theme_constant_override("separation", 6)
	mid_vbox.add_child(elem_hbox)

	var elem_lbl := Label.new()
	elem_lbl.text = "Lọc Ngũ Hành:"
	elem_lbl.add_theme_font_size_override("font_size", 11)
	elem_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	elem_hbox.add_child(elem_lbl)

	_element_buttons.clear()
	var elements := ["Tất cả", "Kim", "Mộc", "Thủy", "Hỏa", "Thổ"]
	var elem_colors := {
		"Tất cả": Color(1.0, 0.9, 0.5),
		"Kim": Color(1.0, 0.85, 0.25),
		"Mộc": Color(0.4, 0.95, 0.4),
		"Thủy": Color(0.4, 0.85, 1.0),
		"Hỏa": Color(1.0, 0.45, 0.35),
		"Thổ": Color(0.95, 0.75, 0.4)
	}
	for el in elements:
		var eb := Button.new()
		eb.text = el
		eb.custom_minimum_size = Vector2(66, 26)
		eb.add_theme_font_size_override("font_size", 11)
		var e_col: Color = elem_colors.get(el, Color.WHITE)
		eb.add_theme_color_override("font_color", e_col)
		eb.add_theme_color_override("font_outline_color", Color.BLACK)
		eb.add_theme_constant_override("outline_size", 1)

		var eb_sb := StyleBoxFlat.new()
		eb_sb.bg_color = Color(0.10, 0.08, 0.06, 0.95)
		eb_sb.border_width_left = 1
		eb_sb.border_width_top = 1
		eb_sb.border_width_right = 1
		eb_sb.border_width_bottom = 1
		eb_sb.border_color = Color(0.55, 0.42, 0.22, 0.85)
		eb_sb.corner_radius_top_left = 4
		eb_sb.corner_radius_top_right = 4
		eb_sb.corner_radius_bottom_left = 4
		eb_sb.corner_radius_bottom_right = 4
		eb.add_theme_stylebox_override("normal", eb_sb)

		var el_val: String = str(el)
		eb.pressed.connect(func() -> void: _select_element_filter(el_val))
		elem_hbox.add_child(eb)
		_element_buttons.append(eb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_vbox.add_child(scroll)

	_library_container = VBoxContainer.new()
	_library_container.add_theme_constant_override("separation", 14)
	_library_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_library_container)

	# -------------------------------------------------------------
	# 3. BOTTOM: NÚT BẮT ĐẦU & NÚT THOÁT VỀ SẢNH (KIẾM HIỆP VLTK)
	# -------------------------------------------------------------
	var bot_hbox := HBoxContainer.new()
	bot_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(bot_hbox)

	var exit_btn := Button.new()
	exit_btn.text = "⬅ THOÁT (VỀ SẢNH)"
	exit_btn.custom_minimum_size = Vector2(200, 48)

	var exit_sb := StyleBoxFlat.new()
	exit_sb.bg_color = Color(0.26, 0.08, 0.08, 0.96)  ## Đỏ cẩm thạch lệnh bài kiếm hiệp
	exit_sb.border_width_left = 2
	exit_sb.border_width_top = 2
	exit_sb.border_width_right = 2
	exit_sb.border_width_bottom = 2
	exit_sb.border_color = Color(0.82, 0.65, 0.28, 0.95)  ## Viền mạ vàng hoàng kim
	exit_sb.corner_radius_top_left = 6
	exit_sb.corner_radius_top_right = 6
	exit_sb.corner_radius_bottom_left = 6
	exit_sb.corner_radius_bottom_right = 6

	var exit_sb_hover := StyleBoxFlat.new()
	exit_sb_hover.bg_color = Color(0.38, 0.12, 0.12, 1.0)
	exit_sb_hover.border_width_left = 2
	exit_sb_hover.border_width_top = 2
	exit_sb_hover.border_width_right = 2
	exit_sb_hover.border_width_bottom = 2
	exit_sb_hover.border_color = Color(0.95, 0.82, 0.35, 1.0)
	exit_sb_hover.corner_radius_top_left = 6
	exit_sb_hover.corner_radius_top_right = 6
	exit_sb_hover.corner_radius_bottom_left = 6
	exit_sb_hover.corner_radius_bottom_right = 6

	exit_btn.add_theme_stylebox_override("normal", exit_sb)
	exit_btn.add_theme_stylebox_override("hover", exit_sb_hover)
	exit_btn.add_theme_stylebox_override("pressed", exit_sb_hover)
	exit_btn.add_theme_font_size_override("font_size", 16)
	exit_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.8))
	exit_btn.tooltip_text = "Rời khỏi trận Thủ Thành và quay trở về Sảnh Chính (ESC)"
	exit_btn.pressed.connect(_on_exit_pressed)
	bot_hbox.add_child(exit_btn)

	_start_btn = Button.new()
	_start_btn.text = "XUẤT TRẬN (BẮT ĐẦU)"
	_start_btn.custom_minimum_size = Vector2(240, 48)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.08, 0.28, 0.14, 0.98)  ## Xanh ngọc bích kiếm hiệp
	btn_sb.border_width_left = 2
	btn_sb.border_width_top = 2
	btn_sb.border_width_right = 2
	btn_sb.border_width_bottom = 2
	btn_sb.border_color = Color(0.92, 0.74, 0.25, 0.98)  ## Viền mạ vàng sáng hoàng gia
	btn_sb.corner_radius_top_left = 6
	btn_sb.corner_radius_top_right = 6
	btn_sb.corner_radius_bottom_left = 6
	btn_sb.corner_radius_bottom_right = 6

	var btn_sb_hover := StyleBoxFlat.new()
	btn_sb_hover.bg_color = Color(0.12, 0.38, 0.20, 1.0)
	btn_sb_hover.border_width_left = 2
	btn_sb_hover.border_width_top = 2
	btn_sb_hover.border_width_right = 2
	btn_sb_hover.border_width_bottom = 2
	btn_sb_hover.border_color = Color(1.0, 0.88, 0.35, 1.0)
	btn_sb_hover.corner_radius_top_left = 6
	btn_sb_hover.corner_radius_top_right = 6
	btn_sb_hover.corner_radius_bottom_left = 6
	btn_sb_hover.corner_radius_bottom_right = 6

	_start_btn.add_theme_stylebox_override("normal", btn_sb)
	_start_btn.add_theme_stylebox_override("hover", btn_sb_hover)
	_start_btn.add_theme_stylebox_override("pressed", btn_sb_hover)
	_start_btn.add_theme_font_size_override("font_size", 16)
	_start_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_start_btn.pressed.connect(_on_start_pressed)
	bot_hbox.add_child(_start_btn)

	_refresh_library()

func _select_element_filter(el: String) -> void:
	_element_filter = el
	_refresh_library()

func _update_filter_button_styles() -> void:
	var elements: Array[String] = ["Tất cả", "Kim", "Mộc", "Thủy", "Hỏa", "Thổ", "Hỗ Trợ"]
	for i in _element_buttons.size():
		var btn: Button = _element_buttons[i]
		if i < elements.size():
			var is_active: bool = (_element_filter == elements[i])
			var sb := StyleBoxFlat.new()
			sb.corner_radius_top_left = 4
			sb.corner_radius_top_right = 4
			sb.corner_radius_bottom_left = 4
			sb.corner_radius_bottom_right = 4
			sb.border_width_left = 2 if is_active else 1
			sb.border_width_top = 2 if is_active else 1
			sb.border_width_right = 2 if is_active else 1
			sb.border_width_bottom = 2 if is_active else 1
			if is_active:
				sb.bg_color = Color(0.24, 0.17, 0.08, 0.98)
				sb.border_color = Color(0.95, 0.82, 0.35, 1.0)
				btn.modulate = Color(1.2, 1.2, 1.0)
			else:
				sb.bg_color = Color(0.10, 0.08, 0.06, 0.95)
				sb.border_color = Color(0.55, 0.42, 0.22, 0.85)
				btn.modulate = Color.WHITE
			btn.add_theme_stylebox_override("normal", sb)

func _refresh_library() -> void:
	if _library_container == null:
		return
	for c in _library_container.get_children():
		c.queue_free()
	_library_cards.clear()

	var all_skills := ThuThanhSkillData.get_all_skills()
	# Lọc theo hệ nếu có
	var skills: Array[Dictionary] = []
	for s in all_skills:
		if _element_filter != "Tất cả":
			if str(s.get("element", "")) != _element_filter and str(s.get("sect", "")) != _element_filter:
				continue
		skills.append(s)

	# Phân nhóm theo cấp đầy đủ từ 1x đến 15x (Yêu cầu hiển thị cho tới 15x)
	var tier_groups: Array[Dictionary] = [
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 1x (Yêu cầu Cấp 10) — TẤT CẢ MÔN PHÁI", "min_lvl": 10, "max_lvl": 19, "color": Color(1.0, 0.85, 0.3)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 2x (Yêu cầu Cấp 20) — TẤT CẢ MÔN PHÁI", "min_lvl": 20, "max_lvl": 29, "color": Color(1.0, 0.65, 0.3)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 3x (Yêu cầu Cấp 30) — TẤT CẢ MÔN PHÁI", "min_lvl": 30, "max_lvl": 39, "color": Color(0.4, 0.9, 1.0)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 4x (Yêu cầu Cấp 40) — TẤT CẢ MÔN PHÁI", "min_lvl": 40, "max_lvl": 49, "color": Color(0.9, 0.5, 1.0)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 5x (Yêu cầu Cấp 50) — TẤT CẢ MÔN PHÁI", "min_lvl": 50, "max_lvl": 59, "color": Color(1.0, 0.5, 0.5)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 6x (Yêu cầu Cấp 60) — TẤT CẢ MÔN PHÁI", "min_lvl": 60, "max_lvl": 69, "color": Color(0.5, 0.9, 0.6)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 7x (Yêu cầu Cấp 70) — TẤT CẢ MÔN PHÁI", "min_lvl": 70, "max_lvl": 79, "color": Color(0.9, 0.8, 0.4)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 8x (Yêu cầu Cấp 80) — TẤT CẢ MÔN PHÁI", "min_lvl": 80, "max_lvl": 89, "color": Color(0.6, 0.8, 1.0)},
		{"title": "👑 HÀNG KỸ NĂNG CẤP 9x (Yêu cầu Cấp 90 - Trấn Phái) — TẤT CẢ MÔN PHÁI", "min_lvl": 90, "max_lvl": 99, "color": Color(1.0, 0.9, 0.2)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 10x (Yêu cầu Cấp 100) — TẤT CẢ MÔN PHÁI", "min_lvl": 100, "max_lvl": 109, "color": Color(0.8, 0.7, 1.0)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 11x (Yêu cầu Cấp 110) — TẤT CẢ MÔN PHÁI", "min_lvl": 110, "max_lvl": 119, "color": Color(0.5, 1.0, 0.8)},
		{"title": "🔥 HÀNG KỸ NĂNG CẤP 12x (Yêu cầu Cấp 120 - Bí Kíp Tuyệt Kỹ) — TẤT CẢ MÔN PHÁI", "min_lvl": 120, "max_lvl": 129, "color": Color(1.0, 0.4, 0.2)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 13x (Yêu cầu Cấp 130) — TẤT CẢ MÔN PHÁI", "min_lvl": 130, "max_lvl": 139, "color": Color(0.7, 0.9, 1.0)},
		{"title": "⚔️ HÀNG KỸ NĂNG CẤP 14x (Yêu cầu Cấp 140) — TẤT CẢ MÔN PHÁI", "min_lvl": 140, "max_lvl": 149, "color": Color(1.0, 0.7, 0.9)},
		{"title": "🌟 HÀNG KỸ NĂNG CẤP 15x (Yêu cầu Cấp 150 - Trấn Phái Tối Thượng) — TẤT CẢ MÔN PHÁI", "min_lvl": 150, "max_lvl": 999, "color": Color(1.0, 0.85, 0.1)}
	]

	for tg in tier_groups:
		var grp_vbox := VBoxContainer.new()
		grp_vbox.add_theme_constant_override("separation", 4)
		_library_container.add_child(grp_vbox)

		# Tiêu đề hàng kỹ năng môn phái
		var h_lbl := Label.new()
		h_lbl.text = str(tg["title"])
		h_lbl.add_theme_font_size_override("font_size", 12)
		h_lbl.add_theme_color_override("font_color", tg["color"])
		h_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		h_lbl.add_theme_constant_override("outline_size", 2)
		grp_vbox.add_child(h_lbl)

		# Hàng chứa tất cả các thẻ kỹ năng của cấp này (HFlowContainer để tự xuống dòng nếu màn hình hẹp)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		grp_vbox.add_child(flow)

		var count_in_tier := 0
		for s in skills:
			var req_lvl := int(s.get("req_level", 10))
			if req_lvl >= int(tg["min_lvl"]) and req_lvl <= int(tg["max_lvl"]):
				var card := _create_library_card(s)
				flow.add_child(card)
				_library_cards[str(s["id"])] = card
				count_in_tier += 1

		if count_in_tier == 0:
			var empty_lbl := Label.new()
			empty_lbl.text = "   (Không có kỹ năng phù hợp bộ lọc)"
			empty_lbl.add_theme_font_size_override("font_size", 10)
			empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			flow.add_child(empty_lbl)

	_update_filter_button_styles()
	_update_state()

func _create_library_card(s: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(106, 150)
	btn.clip_contents = true

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.98)  ## Tông đen mun huyền hắc VLTK
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.55, 0.42, 0.22, 0.9)  ## Đồng vàng cổ điển
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.14, 0.11, 0.08, 0.98)
	sb_hover.border_width_left = 2
	sb_hover.border_width_top = 2
	sb_hover.border_width_right = 2
	sb_hover.border_width_bottom = 2
	sb_hover.border_color = Color(0.95, 0.82, 0.35, 1.0)  ## Sáng vàng hoàng kim khi hover
	sb_hover.corner_radius_top_left = 5
	sb_hover.corner_radius_top_right = 5
	sb_hover.corner_radius_bottom_left = 5
	sb_hover.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("hover", sb_hover)

	var sid := str(s["id"])
	var req_lvl := int(s.get("req_level", 10))
	var cost := int(s.get("cost", 100))
	var elem_str := str(s.get("element", ""))
	var sect_str := str(s.get("sect", "Hiệp Khách"))
	var skill_title := str(s.get("skill_name", s.get("name", "")))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.offset_left = 4
	vb.offset_right = -4
	vb.offset_top = 4
	vb.offset_bottom = -4
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	# Icon Kỹ Năng môn phái
	var ico := TextureRect.new()
	ico.texture = ThuThanhSkillData.get_skill_icon_texture(s)
	ico.custom_minimum_size = Vector2(38, 38)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(ico)

	# Tên Môn Phái
	var hero_name := Label.new()
	hero_name.text = sect_str
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_name.add_theme_font_size_override("font_size", 10)
	var elem_col := Color(1.0, 0.85, 0.3)
	if elem_str == "Mộc": elem_col = Color(0.4, 0.95, 0.4)
	elif elem_str == "Thủy": elem_col = Color(0.4, 0.85, 1.0)
	elif elem_str == "Hỏa": elem_col = Color(1.0, 0.45, 0.35)
	elif elem_str == "Thổ": elem_col = Color(0.95, 0.75, 0.4)
	hero_name.add_theme_color_override("font_color", elem_col)
	vb.add_child(hero_name)

	# Tên Kỹ Năng
	var skill_lbl := Label.new()
	skill_lbl.text = skill_title
	skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_lbl.add_theme_font_size_override("font_size", 9)
	skill_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	vb.add_child(skill_lbl)

	# Nhãn Cấp Độ Kỹ Năng (Hiển thị Lv.X hoặc MAX)
	var lvl_lbl := Label.new()
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.add_theme_font_size_override("font_size", 9)
	lvl_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lvl_lbl.add_theme_constant_override("outline_size", 1)
	vb.add_child(lvl_lbl)
	_library_level_labels[sid] = lvl_lbl

	# Giá Xu
	var cost_lbl := Label.new()
	cost_lbl.text = "💰 %d Xu" % cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.25))
	cost_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	cost_lbl.add_theme_constant_override("outline_size", 2)
	vb.add_child(cost_lbl)

	# Nút [+] Nâng cấp kỹ năng: ĐẶT Ở DƯỚI CÙNG THẺ (thu ngắn vừa vặn, căn giữa không bị tràn ra ngoài)
	var plus_hb := HBoxContainer.new()
	plus_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	plus_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(plus_hb)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(72, 21)
	plus_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plus_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	plus_btn.add_theme_font_size_override("font_size", 14)

	var p_sb := StyleBoxFlat.new()
	p_sb.bg_color = Color(0.18, 0.12, 0.08, 0.98)
	p_sb.border_width_left = 1
	p_sb.border_width_top = 1
	p_sb.border_width_right = 1
	p_sb.border_width_bottom = 1
	p_sb.border_color = Color(0.85, 0.70, 0.28, 0.95)
	p_sb.corner_radius_top_left = 3
	p_sb.corner_radius_top_right = 3
	p_sb.corner_radius_bottom_left = 3
	p_sb.corner_radius_bottom_right = 3

	var p_sb_hover := StyleBoxFlat.new()
	p_sb_hover.bg_color = Color(0.30, 0.20, 0.10, 1.0)
	p_sb_hover.border_width_left = 1
	p_sb_hover.border_width_top = 1
	p_sb_hover.border_width_right = 1
	p_sb_hover.border_width_bottom = 1
	p_sb_hover.border_color = Color(1.0, 0.88, 0.35, 1.0)
	p_sb_hover.corner_radius_top_left = 3
	p_sb_hover.corner_radius_top_right = 3
	p_sb_hover.corner_radius_bottom_left = 3
	p_sb_hover.corner_radius_bottom_right = 3

	plus_btn.add_theme_stylebox_override("normal", p_sb)
	plus_btn.add_theme_stylebox_override("hover", p_sb_hover)
	plus_btn.add_theme_stylebox_override("pressed", p_sb_hover)
	plus_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	plus_btn.pressed.connect(func() -> void: _on_upgrade_skill_clicked(sid))
	plus_hb.add_child(plus_btn)
	_library_plus_buttons[sid] = plus_btn

	# Overlay khóa cấp nếu chưa đủ Cấp Thủ Thành (PvZ)
	if thu_thanh_level < req_lvl:
		btn.disabled = true
		btn.modulate = Color(0.65, 0.65, 0.65, 0.75)
		plus_btn.disabled = true
		plus_btn.visible = false

		# Badge khóa đặt ở mép trên cùng của card, vừa nổi bật vừa không đè lên icon và tên môn phái
		var lock_badge := PanelContainer.new()
		lock_badge.custom_minimum_size = Vector2(105, 20)
		lock_badge.position = Vector2(0, 0)
		lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lb_sb := StyleBoxFlat.new()
		lb_sb.bg_color = Color(0.25, 0.05, 0.05, 0.92)
		lb_sb.corner_radius_top_left = 6
		lb_sb.corner_radius_top_right = 6
		lock_badge.add_theme_stylebox_override("panel", lb_sb)
		btn.add_child(lock_badge)

		var lock_lbl := Label.new()
		lock_lbl.text = "🔒 Cần Cấp PvZ %d" % req_lvl
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 9)
		lock_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		lock_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lock_lbl.add_theme_constant_override("outline_size", 2)
		lock_badge.add_child(lock_lbl)
	else:
		btn.pressed.connect(func() -> void: _on_library_card_clicked(sid))

	_update_card_level_display(sid, btn)
	return btn

func _update_card_level_display(sid: String, target_btn: Button = null) -> void:
	var cur_lvl := ThuThanhSkillData.get_skill_level(sid)
	var max_lvl := ThuThanhSkillData.get_max_skill_level(sid)
	var scaling := ThuThanhSkillData.get_skill_scaling(sid, cur_lvl)
	var is_max: bool = bool(scaling.get("is_max", false))
	var s := ThuThanhSkillData.get_skill(sid)
	var req_lvl := int(s.get("req_level", 10))
	var s_name := str(s.get("skill_name", s.get("name", "Kỹ năng")))
	var sect_str := str(s.get("sect", "Hiệp Khách"))
	var elem_str := str(s.get("element", ""))
	var cost := int(s.get("cost", 100))

	# Cập nhật nhãn cấp độ trên thẻ
	if _library_level_labels.has(sid):
		var lbl: Label = _library_level_labels[sid]
		if is_max:
			lbl.text = "MAX Lv.%d" % cur_lvl
			lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		else:
			lbl.text = "Lv.%d/%d (+%d%%)" % [cur_lvl, max_lvl, int(scaling.get("percent_per_lvl", 10))]
			lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.45))

	# Cập nhật nút [+] trên thẻ:
	# RÀNG BUỘC CẤP ĐỘ: Chỉ được cộng điểm cho kỹ năng có cấp bằng hoặc thấp hơn cấp Thủ Thành hiện tại!
	if _library_plus_buttons.has(sid):
		var p_btn: Button = _library_plus_buttons[sid]
		var can_up: bool = (thu_thanh_level >= req_lvl) and (ThuThanhSkillData.get_skill_points() > 0) and not is_max
		p_btn.disabled = not can_up
		if is_max:
			p_btn.text = "MAX"
			p_btn.add_theme_font_size_override("font_size", 8)
			p_btn.modulate = Color(1.0, 0.88, 0.2)
			p_btn.tooltip_text = "Kỹ năng [%s] đã đạt cấp tối đa MAX!\n%s" % [s_name, str(scaling.get("special_desc", ""))]
		elif can_up:
			p_btn.text = "+"
			p_btn.add_theme_font_size_override("font_size", 12)
			p_btn.modulate = Color(1.3, 1.25, 0.4)
			var next_scaling := ThuThanhSkillData.get_skill_scaling(sid, cur_lvl + 1)
			p_btn.tooltip_text = "Nâng cấp [%s] lên Lv.%d (+%d%% Sát thương)!" % [s_name, cur_lvl + 1, int(next_scaling.get("percent_per_lvl", 10))]
		else:
			p_btn.text = "+"
			p_btn.add_theme_font_size_override("font_size", 12)
			p_btn.modulate = Color(0.65, 0.65, 0.65, 0.6)
			if thu_thanh_level < req_lvl:
				p_btn.tooltip_text = "Chưa đủ Cấp Thủ Thành để cộng kỹ năng này! Cần Cấp PvZ %d (Hiện tại: Cấp %d)" % [req_lvl, thu_thanh_level]
			else:
				p_btn.tooltip_text = "Không đủ điểm kỹ năng! Lên cấp hoặc nhận thưởng để có thêm điểm."

	# Cập nhật tooltip chi tiết của thẻ
	var card_btn: Button = target_btn
	if card_btn == null and _library_cards.has(sid):
		card_btn = _library_cards[sid] as Button
	if card_btn != null:
		var base_dmg := float(s.get("damage", 40))
		var real_dmg := base_dmg * float(scaling.get("damage_mult", 1.0))
		var proj_type: String = str(s.get("projectile_type", ""))
		var shots: int = int(s.get("shots_per_attack", 1)) + int(scaling.get("extra_shots", 0))
		var tt := "Hiệp Khách: %s (Hệ %s)\n" % [sect_str, elem_str]
		tt += "• Kỹ năng thi triển: %s\n" % s_name
		tt += "• Cấp kỹ năng: Lv.%d/%d %s\n" % [cur_lvl, max_lvl, "(MAX)" if is_max else ""]
		tt += "• Sát thương hiện tại: %.1f (+%d%% so với cấp 1)\n" % [real_dmg, int((float(scaling.get("damage_mult", 1.0)) - 1.0) * 100)]
		if proj_type == "dragon":
			tt += "• Xuất Chiêu: Phóng %d Con Rồng Lửa bay uốn lượn dí mục tiêu\n" % shots
		elif shots > 1:
			tt += "• Xuất Chiêu: Bắn liên hoàn %d phát đạn càn quét\n" % shots
		tt += "• Chi phí triệu hồi: %d Xu · Hồi chiêu: %.1fs\n" % [cost, float(s.get("cooldown", 10.0))]
		if str(scaling.get("special_desc", "")) != "":
			tt += "• Hiệu ứng: %s\n" % str(scaling.get("special_desc", ""))
		tt += "• Mô tả: %s\n" % str(s.get("desc", ""))
		var state_str := "Khả dụng" if thu_thanh_level >= req_lvl else ("Khóa cấp (Cần Cấp PvZ %d, hiện tại Lv.%d)" % [req_lvl, thu_thanh_level])
		tt += "• Trạng thái: %s" % state_str
		card_btn.tooltip_text = tt

func _on_upgrade_skill_clicked(sid: String) -> void:
	if ThuThanhSkillData.upgrade_skill(sid):
		_refresh_all_card_levels()

func _refresh_all_card_levels() -> void:
	thu_thanh_level = ThuThanhSkillData.get_thu_thanh_level()
	char_level = thu_thanh_level
	if _tt_level_lbl != null:
		var cur_l := ThuThanhSkillData.get_thu_thanh_level()
		var cur_x := ThuThanhSkillData.get_thu_thanh_exp()
		var max_x := ThuThanhSkillData.get_exp_to_next_level(cur_l)
		_tt_level_lbl.text = "🎖️ Cấp Độ Thủ Thành: Lv.%d (EXP: %d/%d)" % [cur_l, cur_x, max_x]
	if _skill_points_lbl != null:
		_skill_points_lbl.text = "⭐ Điểm Kỹ Năng: %d" % ThuThanhSkillData.get_skill_points()
	for sid in _library_cards:
		_update_card_level_display(sid)
	_update_state()

func _on_library_card_clicked(skill_id: String) -> void:
	if selected_skill_ids.has(skill_id):
		# Nếu đã chọn thì click để bỏ chọn
		selected_skill_ids.erase(skill_id)
	else:
		# Gán vào ô mở còn trống
		if selected_skill_ids.size() < unlocked_slots:
			selected_skill_ids.append(skill_id)
	ThuThanhSkillData.save_selected_skills(selected_skill_ids)
	_update_state()

func _on_slot_clicked(slot_index: int) -> void:
	if slot_index >= unlocked_slots:
		return  ## Ô bị khóa
	if slot_index < selected_skill_ids.size():
		selected_skill_ids.remove_at(slot_index)
		ThuThanhSkillData.save_selected_skills(selected_skill_ids)
		_update_state()

func _update_state() -> void:
	# Cập nhật các ô trên Top Seed Bank
	for i in ThuThanhSkillData.TOTAL_SLOTS:
		var btn := _slot_buttons[i]
		# Xóa các con cũ bên trong nút slot
		for c in btn.get_children():
			c.queue_free()

		if i >= unlocked_slots:
			# Ô bị khóa
			btn.disabled = true
			var lock := Label.new()
			lock.text = "🔒"
			lock.set_anchors_preset(Control.PRESET_FULL_RECT)
			lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock.add_theme_font_size_override("font_size", 20)
			btn.add_child(lock)
		elif i < selected_skill_ids.size():
			# Ô có Kỹ Năng đã chọn (Hiển thị icon kỹ năng + tên chiêu + giá Xu)
			btn.disabled = false
			var sid := selected_skill_ids[i]
			var s := ThuThanhSkillData.get_skill(sid)
			var box := VBoxContainer.new()
			box.set_anchors_preset(Control.PRESET_FULL_RECT)
			box.alignment = BoxContainer.ALIGNMENT_CENTER
			box.add_theme_constant_override("separation", 1)
			btn.add_child(box)

			var ico := TextureRect.new()
			ico.texture = ThuThanhSkillData.get_skill_icon_texture(s)
			ico.custom_minimum_size = Vector2(34, 34)
			ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.add_child(ico)

			var skill_l := Label.new()
			var s_title := str(s.get("skill_name", s.get("name", "Kỹ năng")))
			skill_l.text = s_title
			skill_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			skill_l.add_theme_font_size_override("font_size", 9)
			skill_l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
			box.add_child(skill_l)

			var cur_lvl := ThuThanhSkillData.get_skill_level(sid)
			var cost_l := Label.new()
			cost_l.text = "Lv.%d · %d Xu" % [cur_lvl, int(s.get("cost", 50))]
			cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cost_l.add_theme_font_size_override("font_size", 10)
			cost_l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
			cost_l.add_theme_color_override("font_outline_color", Color.BLACK)
			cost_l.add_theme_constant_override("outline_size", 1)
			box.add_child(cost_l)
		else:
			# Ô mở còn trống
			btn.disabled = false
			var empty_l := Label.new()
			empty_l.text = "Ô %d" % (i + 1)
			empty_l.set_anchors_preset(Control.PRESET_FULL_RECT)
			empty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_l.add_theme_font_size_override("font_size", 11)
			empty_l.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
			btn.add_child(empty_l)

	# Cập nhật trạng thái thư viện (thẻ đã chọn thì làm mờ)
	for sid in _library_cards:
		var card: Control = _library_cards[sid]
		var s := ThuThanhSkillData.get_skill(sid)
		var req_lvl := int(s.get("req_level", 10))
		if char_level >= req_lvl:
			if selected_skill_ids.has(sid):
				card.modulate = Color(0.4, 0.4, 0.4, 0.7)
			else:
				card.modulate = Color.WHITE

	# Tính và hiển thị Xu khởi đầu theo công thức: tổng 3 kỹ năng đắt nhất đã chọn
	var start_coins := ThuThanhSkillData.calculate_starting_coins(selected_skill_ids)
	if _coin_val_lbl != null:
		_coin_val_lbl.text = "Xu: %d" % start_coins

	# Nút bắt đầu chỉ sáng khi có ít nhất 1 kỹ năng
	if _start_btn != null:
		_start_btn.disabled = selected_skill_ids.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
		get_viewport().set_input_as_handled()

func _on_exit_pressed() -> void:
	canceled.emit()
	if is_inside_tree() and canceled.get_connections().is_empty():
		if has_node("/root/SceneTransition"):
			get_node("/root/SceneTransition").change_scene("res://ui/character_hub/CharacterHub.tscn", "Sảnh Chính")
		else:
			get_tree().change_scene_to_file("res://ui/character_hub/CharacterHub.tscn")
	queue_free()

func _on_start_pressed() -> void:
	if selected_skill_ids.is_empty():
		return
	ThuThanhSkillData.save_selected_skills(selected_skill_ids)
	var start_coins := ThuThanhSkillData.calculate_starting_coins(selected_skill_ids)
	started.emit(selected_skill_ids, start_coins)
	queue_free()

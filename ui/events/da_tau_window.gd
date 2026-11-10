extends SocialWindow
class_name DaTauWindow

const DaTauData = preload("res://systems/quest/da_tau_data.gd")
const DaTauManager = preload("res://systems/quest/da_tau_manager.gd")
const MapCatalog = preload("res://systems/map_catalog.gd")
## Cửa sổ Nhiệm Vụ Dã Tẩu (TaskLink) — Chuẩn theo source 15 phái:
## - 6 loại nhiệm vụ: Mua vật phẩm, Tìm vật phẩm, Xem vật phẩm, Thu thập Địa đồ/Mật chí, Nâng chỉ số, Sơn Hà Xã Tắc
## - Giới hạn 50 nhiệm vụ / ngày, 1 lượt bỏ qua miễn phí / ngày
## - Nút Link nhảy map tức thì cho nhiệm vụ Địa đồ / Mật chí
## - Ô nộp / cho xem vật phẩm
## - Hộp nhận thưởng ngẫu nhiên 8 ô sau khi hoàn thành
## - Tab mốc tích lũy 11 phần thưởng lớn

var _profile: PlayerProfile
var _on_enter_map: Callable
var _tab := 0
var _tab_buttons: Array[Button] = []
var _content_box: VBoxContainer
var _scroll: ScrollContainer
var _reward_result: Dictionary = {}
var _last_reward_msg: String = ""

static func open(host: Node, profile: PlayerProfile, on_enter_map: Callable = Callable()) -> SocialWindow:
	var script: GDScript = load("res://ui/events/da_tau_window.gd")
	var win: SocialWindow = script.new(profile, on_enter_map)
	return SocialWindow.present(host, win, &"da_tau")

func _init(profile: PlayerProfile = null, on_enter_map: Callable = Callable()) -> void:
	super._init("Nhiệm Vụ Dã Tẩu", "Giúp đỡ lão nhân giang hồ — Tích lũy cơ duyên & phần thưởng vô giá", 700.0)
	_profile = profile
	_on_enter_map = on_enter_map

	if _profile:
		DaTauManager.reset_daily_if_needed(_profile)
		close_requested.connect(func() -> void:
			if _profile != null:
				DaTauManager.save_records(_profile.da_tau, _profile)
				SaveManager.save_profile(_profile)
		)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(tabs)

	var t1 := GameUi.button("📜 Nhiệm Vụ Dã Tẩu", GameUi.TAB)
	t1.custom_minimum_size = Vector2(230, 38)
	t1.pressed.connect(_select_tab.bind(0))
	tabs.add_child(t1)
	_tab_buttons.append(t1)

	var t2 := GameUi.button("🎁 Phần Thưởng Tích Lũy", GameUi.TAB)
	t2.custom_minimum_size = Vector2(230, 38)
	t2.pressed.connect(_select_tab.bind(1))
	tabs.add_child(t2)
	_tab_buttons.append(t2)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 500)
	body.add_child(_scroll)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 12)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_box)

	_select_tab(0)

func _select_tab(idx: int) -> void:
	_tab = idx
	for i in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[i], i == idx)
	if _scroll != null:
		_scroll.scroll_vertical = 0
	_refresh_current_view()

func _refresh_current_view() -> void:
	for c in _content_box.get_children():
		c.queue_free()

	if _tab == 0:
		_render_quest_view()
	else:
		_render_milestones_view()

## ====================================================================
## TAB 0: NHIỆM VỤ DÃ TẨU
## ====================================================================

func _render_quest_view() -> void:
	if not _profile:
		_content_box.add_child(SocialUi.label("Không tìm thấy thông tin nhân vật!", SocialUi.MUTED))
		return

	var state: Dictionary = DaTauManager._get_state(_profile)
	var done_today: int = state.get("done_today", 0)
	var skip_today: int = state.get("skip_today", 0)
	var total_done: int = state.get("total_done", 0)
	var da_tau_pts: int = state.get("da_tau_points", 0)
	var cur_quest: Variant = state.get("current_quest", null)

	# --- 1. Thẻ tóm tắt tiến độ ngày ---
	var stat_panel := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(stat_panel)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 24)
	stat_panel.add_child(stat_row)

	var p1 := VBoxContainer.new()
	p1.add_child(SocialUi.label("Đã Xong Hôm Nay", SocialUi.MUTED, 12))
	p1.add_child(SocialUi.label("%d / %d" % [done_today, DaTauData.MAX_QUEST_PER_DAY], SocialUi.TITLE, 16))
	stat_row.add_child(p1)

	var p2 := VBoxContainer.new()
	p2.add_child(SocialUi.label("Lượt Bỏ Miễn Phí", SocialUi.MUTED, 12))
	var free_left := maxi(0, DaTauData.FREE_SKIP_PER_DAY - skip_today)
	var skip_col := WuxiaStyle.COLOR_TEXT_GOLD if free_left > 0 else Color(0.8, 0.3, 0.3)
	var skip_lbl := SocialUi.label("%d / %d" % [free_left, DaTauData.FREE_SKIP_PER_DAY], SocialUi.TEXT, 16)
	skip_lbl.add_theme_color_override("font_color", skip_col)
	p2.add_child(skip_lbl)
	stat_row.add_child(p2)

	var p3 := VBoxContainer.new()
	p3.add_child(SocialUi.label("Điểm Dã Tẩu Tích Lũy", SocialUi.MUTED, 12))
	p3.add_child(SocialUi.label(str(da_tau_pts), SocialUi.TITLE, 16))
	stat_row.add_child(p3)

	var p4 := VBoxContainer.new()
	p4.add_child(SocialUi.label("Tổng Đã Hoàn Thành", SocialUi.MUTED, 12))
	p4.add_child(SocialUi.label(str(total_done), SocialUi.TEXT, 16))
	stat_row.add_child(p4)

	# --- 2. Hộp thoại NPC Dã Tẩu ---
	var npc_box := GameUi.panel(GameUi.SECTION)
	_content_box.add_child(npc_box)
	var nhbox := HBoxContainer.new()
	nhbox.add_theme_constant_override("separation", 14)
	npc_box.add_child(nhbox)

	var avatar_rect := TextureRect.new()
	avatar_rect.custom_minimum_size = Vector2(64, 64)
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var npc_tex = load("res://ui/events/npc_da_tau_771.png")
	if npc_tex:
		avatar_rect.texture = npc_tex
	nhbox.add_child(avatar_rect)

	var nvbox := VBoxContainer.new()
	nvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nhbox.add_child(nvbox)

	var npc_title := SocialUi.label("Dã Tẩu Lão Nhân", SocialUi.TITLE, 16)
	nvbox.add_child(npc_title)

	var dialog_text := ""
	if done_today >= DaTauData.MAX_QUEST_PER_DAY:
		dialog_text = DaTauData.NPC_DIALOG["max_today"] % DaTauData.MAX_QUEST_PER_DAY
	elif cur_quest == null:
		dialog_text = DaTauData.NPC_DIALOG["welcome"]
	else:
		var q := cur_quest as Dictionary
		if DaTauManager.check_quest_complete(_profile):
			dialog_text = DaTauData.NPC_DIALOG["quest_done"]
		else:
			dialog_text = DaTauData.NPC_DIALOG["quest_doing"] % q.get("desc", "")

	var dialog_lbl := SocialUi.label(dialog_text, SocialUi.TEXT, 14)
	dialog_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	dialog_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nvbox.add_child(dialog_lbl)

	# --- 3. Nếu vừa hoàn thành có kết quả thưởng ---
	if not _last_reward_msg.is_empty():
		var banner := GameUi.panel(GameUi.SECTION)
		_content_box.add_child(banner)
		var b_lbl := SocialUi.label("🎉 " + _last_reward_msg, SocialUi.TITLE, 14)
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
		banner.add_child(b_lbl)

	# --- 4. Chi tiết Nhiệm Vụ Hoặc Nút Nhận ---
	if cur_quest == null:
		if done_today < DaTauData.MAX_QUEST_PER_DAY:
			var next_q_num := done_today + 1
			var btn_accept := GameUi.button("📜 Nhận Nhiệm Vụ Dã Tẩu (#%d)" % next_q_num, GameUi.PRIMARY)
			btn_accept.custom_minimum_size = Vector2(260, 46)
			btn_accept.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn_accept.pressed.connect(func():
				_last_reward_msg = ""
				_on_accept_quest()
			)
			_content_box.add_child(btn_accept)
		else:
			var lbl_done_all := SocialUi.label("Đại hiệp đã hoàn thành trọn vẹn 50/50 nhiệm vụ hôm nay. Hãy quay lại vào ngày mai!", SocialUi.TITLE, 14)
			lbl_done_all.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_done_all.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
			_content_box.add_child(lbl_done_all)
	else:
		_render_active_quest(cur_quest as Dictionary, skip_today)

## Hiển thị nhiệm vụ đang làm
func _render_active_quest(q: Dictionary, skip_today: int) -> void:
	if DaTauManager.check_quest_complete(_profile):
		_render_reward_selection_3_options(q)
		return

	var q_panel := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(q_panel)
	var q_vbox := VBoxContainer.new()
	q_vbox.add_theme_constant_override("separation", 10)
	q_panel.add_child(q_vbox)

	var qtype: int = q.get("type", 1)
	var type_name := ""
	match qtype:
		1: type_name = "🛒 Mua Vật Phẩm"
		2: type_name = "🔍 Tìm Vật Phẩm"
		3: type_name = "👀 Xem Vật Phẩm"
		4: type_name = "🗺️ Thu Thập Địa Đồ / Mật Chí"
		5: type_name = "💪 Nâng Cấp Chỉ Số"
		6: type_name = "📜 Sơn Hà Xã Tắc (Điểm Dã Tẩu)"

	var state: Dictionary = DaTauManager._get_state(_profile)
	var done_today: int = state.get("done_today", 0)
	var quest_num: int = done_today + 1
	var title_text := "Nhiệm Vụ #%d — %s" % [quest_num, type_name]
	q_vbox.add_child(SocialUi.label(title_text, SocialUi.TITLE, 16))

	var desc_lbl := SocialUi.label(q.get("desc", ""), SocialUi.TEXT, 15)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_vbox.add_child(desc_lbl)

	# Hiển thị tiến độ
	var done_num: int = q.get("done_num", 0)
	var need_num: int = q.get("need_num", 1)
	if qtype == 5:
		var stat_name: String = DaTauData.NUMERIC_TYPE_NAMES.get(q.get("numeric_type", 2), "Chỉ số")
		var cur_val: int = DaTauManager._get_numeric_value(_profile, q.get("numeric_type", 2))
		var need_val: int = q.get("need_value", 0)
		var progress_str := "Hiện tại: %s = %d / Yêu cầu: %d" % [stat_name, cur_val, need_val]
		var col := WuxiaStyle.COLOR_TEXT_GOLD if cur_val >= need_val else Color(0.8, 0.3, 0.3)
		var pl := SocialUi.label(progress_str, SocialUi.TEXT, 14)
		pl.add_theme_color_override("font_color", col)
		q_vbox.add_child(pl)
	elif qtype == 6:
		var cur_pts: int = state.get("da_tau_points_session", 0)
		var progress_str := "Điểm Dã Tẩu hiện có: %d / Cần: %d" % [cur_pts, need_num]
		var col := WuxiaStyle.COLOR_TEXT_GOLD if cur_pts >= need_num else Color(0.8, 0.3, 0.3)
		var pl := SocialUi.label(progress_str, SocialUi.TEXT, 14)
		pl.add_theme_color_override("font_color", col)
		q_vbox.add_child(pl)
	else:
		var progress_str := "Tiến độ: %d / %d" % [done_num, need_num]
		var col := WuxiaStyle.COLOR_TEXT_GOLD if done_num >= need_num else Color(0.85, 0.8, 0.7)
		var pl := SocialUi.label(progress_str, SocialUi.TEXT, 14)
		pl.add_theme_color_override("font_color", col)
		q_vbox.add_child(pl)

	# Điểm thưởng dự kiến
	var pts: int = q.get("reward_pts", 0)
	var pts_lbl := SocialUi.label("Thưởng hoàn thành: +%d Điểm Dã Tẩu (Tự Động) + Chọn 1 trong 3 Option: EXP / Bạc / Vật Phẩm Quý" % pts, SocialUi.MUTED, 13)
	q_vbox.add_child(pts_lbl)

	# --- NÚT NHẢY MAP TỨC THÌ (CHO TYPE 4 & 2) ---
	var godot_mid: int = q.get("godot_map_id", 0)
	var map_name: String = q.get("map_name", "")
	if godot_mid > 0 and _on_enter_map.is_valid():
		var map_row := HBoxContainer.new()
		map_row.add_theme_constant_override("separation", 10)
		q_vbox.add_child(map_row)

		var btn_teleport := GameUi.button("🗺️ Đến Ngay: %s" % map_name, GameUi.PRIMARY)
		btn_teleport.custom_minimum_size = Vector2(260, 38)
		btn_teleport.pressed.connect(func():
			var entry: Dictionary = MapCatalog.get_by_id(godot_mid)
			if entry.is_empty():
				entry = {
					"id": godot_mid,
					"name": map_name if not map_name.is_empty() else ("Bản đồ %d" % godot_mid),
					"dir": "res://world/maps/map_%d" % godot_mid,
					"level": 1
				}
			close_requested.emit()
			if _on_enter_map.is_valid():
				_on_enter_map.call(entry)
			else:
				GameManager.field_map = entry
				get_tree().change_scene_to_file("res://world/vltk_world.tscn")
		)
		map_row.add_child(btn_teleport)

		var note_lbl := SocialUi.label("(Bấm để dịch chuyển thẳng đến bản đồ làm nhiệm vụ)", SocialUi.MUTED, 12)
		note_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		map_row.add_child(note_lbl)

	# --- Ô NỘP / XEM VẬT PHẨM (CHO TYPE 1, 2, 3) ---
	if qtype in [1, 2, 3]:
		var item_box := GameUi.panel(GameUi.SECTION)
		q_vbox.add_child(item_box)
		var ihbox := HBoxContainer.new()
		ihbox.add_theme_constant_override("separation", 14)
		item_box.add_child(ihbox)

		var slot_p := Panel.new()
		slot_p.custom_minimum_size = Vector2(50, 50)
		slot_p.add_theme_stylebox_override("panel", WuxiaStyle.create_panel_box())
		var slot_icon := Label.new()
		slot_icon.text = "📦"
		slot_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_icon.add_theme_font_size_override("font_size", 24)
		slot_p.add_child(slot_icon)
		ihbox.add_child(slot_p)

		var ivbox := VBoxContainer.new()
		ivbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ihbox.add_child(ivbox)

		var act_name := "Nộp vật phẩm" if qtype != 3 else "Cho Dã Tẩu xem"
		ivbox.add_child(SocialUi.label(act_name, SocialUi.TITLE, 14))
		var sub_desc := "Bấm xác nhận để nộp hoặc cho Dã Tẩu kiểm tra vật phẩm"
		ivbox.add_child(SocialUi.label(sub_desc, SocialUi.MUTED, 12))

		var btn_sub := GameUi.button(act_name, GameUi.BUTTON)
		btn_sub.custom_minimum_size = Vector2(140, 36)
		btn_sub.pressed.connect(func():
			DaTauManager.mark_progress(_profile, 1)
			_refresh_current_view()
		)
		ihbox.add_child(btn_sub)

	# --- HÀNG NÚT THAO TÁC CHÍNH ---
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_box.add_child(btn_row)

	var is_ready := DaTauManager.check_quest_complete(_profile)
	var btn_submit := GameUi.button("✅ Hoàn Thành & Nhận Thưởng" if is_ready else "🔍 Kiểm Tra Hoàn Thành", GameUi.PRIMARY)
	btn_submit.custom_minimum_size = Vector2(220, 42)
	btn_submit.pressed.connect(_on_submit_quest)
	btn_row.add_child(btn_submit)

	var can_skip := skip_today < DaTauData.FREE_SKIP_PER_DAY
	var btn_skip := GameUi.button("⏭️ Bỏ Qua (1 lượt/ngày)", GameUi.BUTTON)
	btn_skip.custom_minimum_size = Vector2(180, 42)
	btn_skip.disabled = not can_skip
	btn_skip.pressed.connect(_on_skip_quest)
	btn_row.add_child(btn_skip)

## Hiển thị 3 Option Chọn Thưởng chuẩn gốc JX1 (UiDaTau.ini & datau.lua)
func _render_reward_selection_3_options(q: Dictionary) -> void:
	var state: Dictionary = DaTauManager._get_state(_profile)
	var done_today: int = state.get("done_today", 0)
	var quest_num: int = done_today + 1
	var pts: int = q.get("reward_pts", 0)

	var p_panel := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(p_panel)
	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 14)
	p_panel.add_child(p_vbox)

	# 1. Tiêu đề chúc mừng
	var h_title := SocialUi.label("🎉 Nhiệm Vụ #%d Đã Hoàn Thành! Hãy Chọn 1 Trong 3 Phần Thưởng:" % quest_num, SocialUi.TITLE, 17)
	h_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_title.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	p_vbox.add_child(h_title)

	# 2. Thông báo tự động tích lũy điểm Dã Tẩu
	var pts_card := GameUi.panel(GameUi.SECTION)
	p_vbox.add_child(pts_card)
	var pts_hbox := HBoxContainer.new()
	pts_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pts_hbox.add_theme_constant_override("separation", 8)
	pts_card.add_child(pts_hbox)
	var pts_lbl := SocialUi.label("⭐ TỰ ĐỘNG TÍCH LŨY: +%d Điểm Dã Tẩu (Chắc chắn cộng ngay khi chọn thưởng)" % pts, SocialUi.TITLE, 14)
	pts_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	pts_hbox.add_child(pts_lbl)

	# 3. Lấy 3 Option từ Manager
	var options := DaTauManager.get_or_create_reward_options(_profile)

	# 4. HBox chứa 3 Card Option
	var opt_hbox := HBoxContainer.new()
	opt_hbox.add_theme_constant_override("separation", 14)
	opt_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_vbox.add_child(opt_hbox)

	for i in options.size():
		var opt: Dictionary = options[i]
		var card := GameUi.panel(GameUi.SECTION)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(170, 200)
		opt_hbox.add_child(card)

		var cvbox := VBoxContainer.new()
		cvbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cvbox.add_theme_constant_override("separation", 10)
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(cvbox)

		# Icon
		var icon_lbl := Label.new()
		icon_lbl.text = opt.get("icon", "🎁")
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 34)
		cvbox.add_child(icon_lbl)

		# Tên option
		var opt_name := SocialUi.label(opt.get("name", "Phần thưởng"), SocialUi.TITLE, 15)
		opt_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(opt_name)

		# Mô tả / số lượng
		var opt_desc := SocialUi.label(opt.get("desc", ""), SocialUi.TEXT, 13)
		opt_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opt_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		opt_desc.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
		cvbox.add_child(opt_desc)

		# Nút chọn
		var btn_select := GameUi.button("Chọn Thưởng Này", GameUi.PRIMARY)
		btn_select.custom_minimum_size = Vector2(140, 38)
		btn_select.pressed.connect(func():
			_on_select_reward_option(i)
		)
		cvbox.add_child(btn_select)

## ====================================================================
## TAB 1: PHẦN THƯỞNG TÍCH LŨY (11 MỐC)
## ====================================================================

func _render_milestones_view() -> void:
	if not _profile:
		return

	var state: Dictionary = DaTauManager._get_state(_profile)
	var total_pts: int = state.get("da_tau_points", 0)
	var claimed: Array = state.get("claimed_milestones", [])

	var head_panel := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head_panel)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	head_panel.add_child(hv)

	hv.add_child(SocialUi.label("Mốc Tích Lũy Điểm Dã Tẩu — Sơn Hà Xã Tắc", SocialUi.TITLE, 17))
	var desc := SocialUi.label("Mỗi lần hoàn thành nhiệm vụ Dã Tẩu, đại hiệp sẽ nhận được Điểm Dã Tẩu. Khi đạt đủ các mốc điểm dưới đây, hãy nhận lấy những bảo vật giang hồ hiếm có!", SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(desc)

	var cur_pts_lbl := SocialUi.label("Điểm Dã Tẩu Hiện Tại: %d" % total_pts, SocialUi.TITLE, 15)
	cur_pts_lbl.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	hv.add_child(cur_pts_lbl)

	for i in DaTauData.AWARD_MILESTONES.size():
		var threshold: int = DaTauData.AWARD_MILESTONES[i]
		var reward_desc: String = DaTauData.MILESTONE_REWARDS_DESC[i]
		var is_claimed: bool = i in claimed
		var can_claim: bool = total_pts >= threshold and not is_claimed

		var card := GameUi.panel(GameUi.SECTION)
		_content_box.add_child(card)
		var chbox := HBoxContainer.new()
		chbox.add_theme_constant_override("separation", 14)
		card.add_child(chbox)

		var icon_lbl := Label.new()
		icon_lbl.text = "🏆" if can_claim else ("✅" if is_claimed else "🔒")
		icon_lbl.add_theme_font_size_override("font_size", 28)
		chbox.add_child(icon_lbl)

		var cvbox := VBoxContainer.new()
		cvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chbox.add_child(cvbox)

		var m_title := SocialUi.label("Mốc %d: %d Điểm" % [i + 1, threshold], SocialUi.TITLE, 15)
		if can_claim:
			m_title.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
		cvbox.add_child(m_title)

		var r_lbl := SocialUi.label(reward_desc, SocialUi.TEXT, 13)
		cvbox.add_child(r_lbl)

		var btn_claim := GameUi.button("Nhận Thưởng" if can_claim else ("Đã Nhận" if is_claimed else "Chưa Đạt"), GameUi.PRIMARY if can_claim else GameUi.BUTTON)
		btn_claim.custom_minimum_size = Vector2(120, 36)
		btn_claim.disabled = not can_claim
		if can_claim:
			btn_claim.pressed.connect(_on_claim_milestone.bind(i))
		chbox.add_child(btn_claim)

## ====================================================================
## HANDLERS
## ====================================================================

func _on_accept_quest() -> void:
	if not _profile:
		return
	var q := DaTauManager.accept_quest(_profile)
	if not q.is_empty():
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
	_refresh_current_view()

func _on_submit_quest() -> void:
	if not _profile:
		return
	_refresh_current_view()

func _on_select_reward_option(idx: int) -> void:
	if not _profile:
		return
	var res := DaTauManager.claim_reward_option(_profile, idx)
	if not res.is_empty():
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
		var chosen: Dictionary = res.get("chosen", {})
		_last_reward_msg = "Hoàn thành nhiệm vụ #%d! Đã nhận: %s & +%d Điểm Dã Tẩu!" % [
			res.get("done_today", 1),
			chosen.get("desc", chosen.get("name", "")),
			res.get("points", 0)
		]
	_refresh_current_view()

func _on_skip_quest() -> void:
	if not _profile:
		return
	if DaTauManager.skip_quest(_profile):
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
	_refresh_current_view()

func _on_claim_milestone(idx: int) -> void:
	if not _profile:
		return
	var res := DaTauManager.claim_milestone(_profile, idx)
	if not res.is_empty():
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
	_refresh_current_view()

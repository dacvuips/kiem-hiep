extends SocialWindow
class_name DaTauWindow

const DaTauData = preload("res://systems/quest/da_tau_data.gd")
const DaTauManager = preload("res://systems/quest/da_tau_manager.gd")
const DaTauSubmitWindow = preload("res://ui/events/da_tau_submit_window.gd")
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
var _milestone_msg: String = ""
var _milestone_err: bool = false
var _awaiting_da_tau_op: String = ""
var _awaiting_op_time: int = 0

static func open(host: Node, profile: PlayerProfile, on_enter_map: Callable = Callable()) -> SocialWindow:
	var script: GDScript = load("res://ui/events/da_tau_window.gd")
	var win: SocialWindow = script.new(profile, on_enter_map)
	return SocialWindow.present(host, win, &"da_tau")

func _init(profile: PlayerProfile = null, on_enter_map: Callable = Callable()) -> void:
	super._init("Nhiệm Vụ Dã Tẩu", "", 700.0)
	_profile = profile
	_on_enter_map = on_enter_map

	if _profile:
		DaTauManager.reset_daily_if_needed(_profile)
		close_requested.connect(func() -> void:
			_awaiting_da_tau_op = ""
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
	if SaveManager != null and SaveManager.has_signal("profile_changed"):
		SaveManager.profile_changed.connect(_on_profile_changed)
	if NetClient != null and NetClient.has_signal("server_notice"):
		NetClient.server_notice.connect(_on_server_notice)

func on_presented() -> void:
	_awaiting_da_tau_op = ""
	_awaiting_op_time = 0
	_on_profile_changed(null)

func _on_server_notice(text: String) -> void:
	if not is_instance_valid(self) or _awaiting_da_tau_op.is_empty():
		return
	var op := _awaiting_da_tau_op
	_awaiting_da_tau_op = ""
	_awaiting_op_time = 0
	if op == "claim_option":
		_last_reward_msg = text
	elif op == "claim_milestone":
		_milestone_msg = text
		_milestone_err = text.contains("không đủ") or text.contains("⚠️") or text.contains("Không thể")
	_refresh_current_view()

func _on_profile_changed(p: PlayerProfile) -> void:
	if not is_instance_valid(self) or _content_box == null:
		return
	if p == null or p == _profile or (GameManager != null and p == GameManager.local_profile and _profile == GameManager.local_profile):
		if _profile == null and GameManager != null:
			_profile = GameManager.local_profile
		if _profile != null and not DaTauManager.server_mode and _profile.da_tau is Dictionary and not _profile.da_tau.is_empty():
			DaTauManager.save_records(_profile.da_tau, _profile)
		_refresh_current_view()

func _select_tab(idx: int) -> void:
	_tab = idx
	for i in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[i], i == idx)
	if _scroll != null:
		_scroll.scroll_vertical = 0
	_refresh_current_view()

func _refresh_current_view() -> void:
	for c in _content_box.get_children():
		_content_box.remove_child(c)
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
	var cur_quest: Variant = state.get("current_quest", null)

	# --- 1. Thẻ tóm tắt tiến độ ngày ---
	var stat_panel := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(stat_panel)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 36)
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_panel.add_child(stat_row)

	var p1 := VBoxContainer.new()
	p1.add_child(SocialUi.label("Đã Xong Hôm Nay", SocialUi.MUTED, 12))
	p1.add_child(SocialUi.label("%d / %d" % [done_today, DaTauData.MAX_QUEST_PER_DAY], SocialUi.TITLE, 16))
	var complete_items := DaTauManager.count_instant_complete_items(_profile)
	var complete_lbl := SocialUi.label("Lệnh bài hoàn thành: %d" % complete_items, SocialUi.MUTED, 11)
	if complete_items > 0:
		complete_lbl.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	p1.add_child(complete_lbl)
	stat_row.add_child(p1)

	var p2 := VBoxContainer.new()
	p2.add_child(SocialUi.label("Hủy Miễn Phí Còn", SocialUi.MUTED, 12))
	var free_left := maxi(0, DaTauData.FREE_SKIP_PER_DAY - skip_today)
	var cancel_items := DaTauManager.count_free_cancel_items(_profile)
	var skip_col := WuxiaStyle.COLOR_TEXT_GOLD if free_left > 0 else Color(0.8, 0.3, 0.3)
	var skip_lbl := SocialUi.label("%d / %d lượt" % [free_left, DaTauData.FREE_SKIP_PER_DAY], SocialUi.TEXT, 16)
	skip_lbl.add_theme_color_override("font_color", skip_col)
	p2.add_child(skip_lbl)
	var item_lbl := SocialUi.label("Lệnh bài hủy: %d" % cancel_items, SocialUi.MUTED, 11)
	if cancel_items > 0:
		item_lbl.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	p2.add_child(item_lbl)
	stat_row.add_child(p2)

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

	# --- 3. Nếu vừa hoàn thành hoặc vừa hủy có thông báo ---
	if not _last_reward_msg.is_empty():
		var banner := GameUi.panel(GameUi.SECTION)
		_content_box.add_child(banner)
		var b_lbl := SocialUi.label(_last_reward_msg, SocialUi.TITLE, 14)
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var state: Dictionary = DaTauManager._get_state(_profile)
	var done_today: int = state.get("done_today", 0)
	var quest_num: int = done_today + 1
	var q_desc: String = str(q.get("desc", "")).strip_edges()
	var title_text := "Nhiệm Vụ #%d — %s" % [quest_num, q_desc] if not q_desc.is_empty() else "Nhiệm Vụ #%d" % quest_num
	var title_lbl := SocialUi.label(title_text, SocialUi.TITLE, 16)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_vbox.add_child(title_lbl)

	# Hiển thị tiến độ
	var done_num: int = q.get("done_num", 0)
	var need_num: int = q.get("need_num", 1)
	if qtype == 5:
		var cur_val: int = int(q.get("done_num", 0))
		var need_val: int = int(q.get("need_num", q.get("need_value", 1)))
		var progress_str := "Tiến độ Kinh Nghiệm: %s / %s EXP" % [DaTauManager.format_num(cur_val), DaTauManager.format_num(need_val)]
		var col := WuxiaStyle.COLOR_TEXT_GOLD if cur_val >= need_val else Color(0.85, 0.8, 0.7)
		var pl := SocialUi.label(progress_str, SocialUi.TEXT, 14)
		pl.add_theme_color_override("font_color", col)
		q_vbox.add_child(pl)
	elif qtype == 6:
		var cur_pts: int = state.get("da_tau_points_session", 0)
		var progress_str := "Mảnh Sơn Hà Xã Tắc hiện có: %d / Cần: %d" % [cur_pts, need_num]
		var col := WuxiaStyle.COLOR_TEXT_GOLD if cur_pts >= need_num else Color(0.8, 0.3, 0.3)
		var pl := SocialUi.label(progress_str, SocialUi.TEXT, 14)
		pl.add_theme_color_override("font_color", col)
		q_vbox.add_child(pl)
	else:
		if qtype == 3:
			var mtype := int(q.get("map_type", q.get("scroll_type", 1)))
			var in_bag := DaTauManager.count_bag_scrolls(_profile, mtype)
			done_num = mini(in_bag, need_num)
			if int(q.get("done_num", 0)) != done_num:
				q["done_num"] = done_num
				DaTauManager.save_records(state, _profile)
		var progress_str := "Tiến độ: %d / %d" % [done_num, need_num]
		var col := WuxiaStyle.COLOR_TEXT_GOLD if done_num >= need_num else Color(0.85, 0.8, 0.7)
		var pl := SocialUi.label(progress_str, SocialUi.TEXT, 14)
		pl.add_theme_color_override("font_color", col)
		q_vbox.add_child(pl)

	# --- HƯỚNG DẪN CHO TYPE 5 (TÍCH LŨY KINH NGHIỆM) ---
	if qtype == 5:
		var tip_box := GameUi.panel(GameUi.SECTION)
		q_vbox.add_child(tip_box)
		var tip_hbox := HBoxContainer.new()
		tip_hbox.add_theme_constant_override("separation", 14)
		tip_box.add_child(tip_hbox)
		tip_hbox.add_child(_build_icon_slot(null, "⚔️"))
		var tip_vbox := VBoxContainer.new()
		tip_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tip_hbox.add_child(tip_vbox)
		tip_vbox.add_child(SocialUi.label("Tích Lũy Kinh Nghiệm", SocialUi.TITLE, 14))
		var tip_desc := SocialUi.label("Hãy đi đánh quái ở các bản đồ dã ngoại hoặc tham gia hoạt động để tích lũy đủ điểm EXP yêu cầu.", SocialUi.MUTED, 12)
		tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_vbox.add_child(tip_desc)

	# --- Ô HIỂN THỊ VẬT PHẨM TỪ SOURCE GỐC (TYPE 6) ---
	if qtype == 6:
		var sh_box := GameUi.panel(GameUi.SECTION)
		q_vbox.add_child(sh_box)
		var sh_hbox := HBoxContainer.new()
		sh_hbox.add_theme_constant_override("separation", 14)
		sh_box.add_child(sh_hbox)
		sh_hbox.add_child(_build_icon_slot(_get_misc_icon("4_351_1"), "📜"))
		var sh_vbox := VBoxContainer.new()
		sh_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sh_hbox.add_child(sh_vbox)
		sh_vbox.add_child(SocialUi.label("Mảnh bản đồ Sơn Hà Xã Tắc", SocialUi.TITLE, 14))
		var sh_desc := SocialUi.label("Thu thập đủ Mảnh Sơn Hà Xã Tắc (rớt khi đánh quái) và nộp cho Dã Tẩu để hoàn thành", SocialUi.MUTED, 12)
		sh_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sh_vbox.add_child(sh_desc)

		var cur_sh_pts: int = state.get("da_tau_points_session", 0)
		var can_sh_sub := cur_sh_pts >= need_num and done_num < need_num
		var btn_sh_sub := GameUi.button("Nộp Mảnh", GameUi.PRIMARY if can_sh_sub else GameUi.BUTTON)
		btn_sh_sub.custom_minimum_size = Vector2(140, 36)
		btn_sh_sub.disabled = not can_sh_sub
		btn_sh_sub.pressed.connect(func():
			if DaTauManager.consume_da_tau_points(_profile, need_num):
				SaveManager.save_profile(_profile, true)
				_refresh_current_view()
		)
		sh_hbox.add_child(btn_sh_sub)

	# --- CẢNH BÁO NỔI BẬT THEO YÊU CẦU NHIỆM VỤ ---
	if qtype == 2:
		# CẢNH BÁO MÀU ĐỎ NỔI BẬT: Nhiệm vụ thu hồi đồ (mất món đồ vĩnh viễn)
		var warn_box := GameUi.panel(GameUi.BANNER_BAD)
		var warn_style := StyleBoxFlat.new()
		warn_style.bg_color = Color(0.38, 0.05, 0.05, 0.95)
		warn_style.border_color = Color(1.0, 0.25, 0.25, 1.0)
		warn_style.set_border_width_all(2)
		warn_style.set_content_margin_all(10)
		warn_box.add_theme_stylebox_override("panel", warn_style)
		q_vbox.add_child(warn_box)

		var w_vb := VBoxContainer.new()
		w_vb.add_theme_constant_override("separation", 3)
		warn_box.add_child(w_vb)

		var w_t := SocialUi.label("⚠️ CẢNH BÁO: DÃ TẨU SẼ THU HỒI MÓN ĐỒ NÀY (BỊ MẤT ĐỒ)!", SocialUi.TITLE, 13)
		w_t.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		w_vb.add_child(w_t)

		var w_d := SocialUi.label("Món đồ bạn nộp sẽ BỊ XÓA VĨNH VIỄN khỏi nhân vật! Hệ thống KHÔNG tự ý lấy đồ trong rương. Hãy bấm nút 'Mở Rương Nộp Đồ' bên dưới để tự tay đặt đúng món cần nộp, tránh nộp nhầm trang bị có thuộc tính tốt mà bạn muốn giữ lại!", SocialUi.MUTED, 11)
		w_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w_d.add_theme_color_override("font_color", Color(1.0, 0.85, 0.8))
		w_vb.add_child(w_d)

	elif qtype == 3:
		# THÔNG BÁO CHO NHIỆM VỤ XEM CHỈ SỐ ĐỒ: Không thu hồi đồ
		var info_box := GameUi.panel(GameUi.SECTION)
		var info_style := StyleBoxFlat.new()
		info_style.bg_color = Color(0.04, 0.22, 0.12, 0.95)
		info_style.border_color = Color(0.2, 0.85, 0.45, 1.0)
		info_style.set_border_width_all(2)
		info_style.set_content_margin_all(10)
		info_box.add_theme_stylebox_override("panel", info_style)
		q_vbox.add_child(info_box)

		var i_vb := VBoxContainer.new()
		i_vb.add_theme_constant_override("separation", 3)
		info_box.add_child(i_vb)

		var i_t := SocialUi.label("ℹ️ LƯU Ý: DÃ TẨU CHỈ XEM CHỈ SỐ, KHÔNG THU HỒI ĐỒ", SocialUi.TITLE, 13)
		i_t.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		i_vb.add_child(i_t)

		var i_d := SocialUi.label("Nhiệm vụ này Dã Tẩu chỉ xem chỉ số trang bị. Không tự động hoàn thành từ rương. Hãy bấm nút bên dưới để mở rương nộp (10×6), tự tay đặt trang bị vào cho Dã Tẩu xem.", SocialUi.MUTED, 11)
		i_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		i_d.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
		i_vb.add_child(i_d)

	# --- Ô NỘP / XEM VẬT PHẨM (CHO TYPE 1, 2, 3) ---
	if qtype in [1, 2, 3]:
		var item_box := GameUi.panel(GameUi.SECTION)
		q_vbox.add_child(item_box)
		var ihbox := HBoxContainer.new()
		ihbox.add_theme_constant_override("separation", 14)
		item_box.add_child(ihbox)

		var req_tex: Texture2D = null
		var default_emoji := "📦"
		if qtype == 2:
			var kind: String = str(q.get("kind", "equip"))
			if kind == "misc":
				req_tex = _get_misc_icon(str(q.get("misc_id", "")))
				default_emoji = "💎"
			else:
				var b_idx: int = int(q.get("base_index", -1))
				if b_idx >= 0:
					req_tex = ItemDatabase.get_icon(ItemDatabase.get_base(b_idx), true)
				default_emoji = "💍"
		elif qtype == 3:
			default_emoji = "🔍"
		elif qtype == 1:
			req_tex = _get_misc_icon("6_1_71")

		ihbox.add_child(_build_icon_slot(req_tex, default_emoji))

		var ivbox := VBoxContainer.new()
		ivbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ihbox.add_child(ivbox)

		var act_name := "Nộp vật phẩm"
		if qtype == 2:
			act_name = "📦 Mở Rương Nộp Đồ"
		elif qtype == 3:
			act_name = "🔍 Mở Rương Cho Xem"
		else:
			act_name = "💰 Mua & Nộp Vật Phẩm"

		ivbox.add_child(SocialUi.label(act_name, SocialUi.TITLE, 14))

		var sub_desc := ""
		var btn_disabled := false
		if qtype == 2:
			var item_name: String = str(q.get("item_name", "vật phẩm"))
			var is_submitted: bool = int(q.get("done_num", 0)) >= int(q.get("need_num", 1))
			if is_submitted:
				sub_desc = "✅ Đã nộp 1 %s cho Dã Tẩu. Đã sẵn sàng nhận thưởng!" % item_name
				btn_disabled = true
			else:
				var match_idx := DaTauManager.find_matching_item_for_type2(_profile, q)
				if match_idx >= 0:
					sub_desc = "Đã có món [%s] trong hành trang! Bấm mở rương để tự tay chọn món nộp." % item_name
				else:
					sub_desc = "Chưa có [%s] trong hành trang. Hãy đánh quái nhặt hoặc mua từ người chơi khác." % item_name
		elif qtype == 3:
			var m_match := DaTauManager.find_matching_item_for_type3(_profile, q)
			var m_name: String = str(q.get("magic_name", "Thuộc tính"))
			var is_done: bool = int(q.get("done_num", 0)) >= int(q.get("need_num", 1))
			if is_done:
				sub_desc = "✅ Đã cho Dã Tẩu xem trang bị đạt yêu cầu! Không bị mất đồ."
				btn_disabled = true
			else:
				if m_match.get("found", false):
					var found_name: String = str(m_match.get("item_name", "Trang bị hợp lệ"))
					sub_desc = "Đã tìm thấy [%s] có thuộc tính %s đạt yêu cầu! Bấm mở rương để đặt đồ cho xem." % [found_name, m_name]
				else:
					sub_desc = "Chưa tìm thấy trang bị nào có thuộc tính %s đạt yêu cầu trong hành trang." % m_name
		elif qtype == 1:
			var gold_cost: int = int(q.get("gold_cost", 0))
			sub_desc = "Cần %d lượng để mua vật phẩm từ thương nhân." % gold_cost

		var desc_lbl := SocialUi.label(sub_desc, SocialUi.MUTED, 12)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ivbox.add_child(desc_lbl)

		var btn_sub := GameUi.button(act_name, GameUi.PRIMARY if not btn_disabled else GameUi.BUTTON)
		btn_sub.custom_minimum_size = Vector2(170, 38)
		btn_sub.disabled = btn_disabled
		btn_sub.pressed.connect(func():
			if qtype in [2, 3]:
				# Mở rương nộp đồ kích thước dài 10 ô cao 6 ô
				DaTauSubmitWindow.open(self.get_parent() if self.get_parent() != null else self, _profile, q, func(msg: String) -> void:
					_last_reward_msg = msg
					_refresh_current_view()
				)
			elif qtype == 1:
				var gold_cost: int = int(q.get("gold_cost", 0))
				if gold_cost > 0 and _profile.gold < gold_cost:
					_last_reward_msg = "⚠️ Không đủ ngân lượng để mua vật phẩm! (Cần %d lượng)" % gold_cost
				else:
					if gold_cost > 0:
						_profile.gold -= gold_cost
					q["done_num"] = q.get("need_num", 1)
					SaveManager.save_profile(_profile, true)
					_last_reward_msg = "✅ Đã mua và nộp %s cho Dã Tẩu." % str(q.get("item_name", "vật phẩm"))
				_refresh_current_view()
		)
		ihbox.add_child(btn_sub)

	# --- HÀNG NÚT THAO TÁC CHÍNH ---
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_box.add_child(btn_row)

	var godot_mid: int = q.get("godot_map_id", 0)
	var map_name: String = q.get("map_name", "")
	if godot_mid > 0 and _on_enter_map.is_valid():
		var btn_teleport := GameUi.button("🗺️ Đến Ngay: %s" % map_name, GameUi.PRIMARY)
		btn_teleport.custom_minimum_size = Vector2(205, 42)
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
		btn_row.add_child(btn_teleport)

	var is_ready := DaTauManager.check_quest_complete(_profile)
	var btn_submit := GameUi.button("✅ Hoàn Thành & Nhận Thưởng" if is_ready else "🔍 Kiểm Tra Hoàn Thành", GameUi.PRIMARY)
	btn_submit.custom_minimum_size = Vector2(205, 42)
	btn_submit.pressed.connect(_on_submit_quest)
	btn_row.add_child(btn_submit)

	var preview := DaTauManager.get_cancel_preview(_profile)
	var cancel_mode: String = str(preview.get("mode", "reset"))
	var cancel_text := "❌ Hủy Nhiệm Vụ (Về #1)"
	if cancel_mode == "daily_free":
		cancel_text = "⏭️ Hủy Miễn Phí (Tính Tiếp #%d)" % (quest_num + 1)
	elif cancel_mode == "item_free":
		var cancel_items := DaTauManager.count_free_cancel_items(_profile)
		cancel_text = "🎫 Hủy Miễn Phí (Lệnh Bài ×%d)" % cancel_items

	var btn_skip := GameUi.button(cancel_text, GameUi.BUTTON)
	btn_skip.custom_minimum_size = Vector2(230, 42)
	btn_skip.pressed.connect(_on_cancel_quest)
	btn_row.add_child(btn_skip)

	var complete_items := DaTauManager.count_instant_complete_items(_profile)
	if complete_items > 0:
		var instant_row := HBoxContainer.new()
		instant_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_content_box.add_child(instant_row)
		var btn_instant := GameUi.button("🎫 Dùng Lệnh Bài Hoàn Thành (×%d)" % complete_items, GameUi.PRIMARY)
		btn_instant.custom_minimum_size = Vector2(290, 40)
		btn_instant.pressed.connect(_on_instant_complete_quest)
		instant_row.add_child(btn_instant)

	if cancel_mode == "daily_free":
		var info_lbl := SocialUi.label("ℹ️ Bỏ qua miễn phí: Nhiệm vụ hiện tại sẽ được bỏ qua và tính tiếp sang Nhiệm Vụ #%d (không bị phạt về #1)." % (quest_num + 1), SocialUi.MUTED, 12)
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_lbl.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
		_content_box.add_child(info_lbl)
	elif cancel_mode == "item_free":
		var info_lbl := SocialUi.label("ℹ️ Dùng 1 [%s] để bỏ qua nhiệm vụ hiện tại và tính tiếp sang Nhiệm Vụ #%d (không bị phạt về #1)." % [DaTauData.FREE_CANCEL_ITEM_NAME, quest_num + 1], SocialUi.MUTED, 12)
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_lbl.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
		_content_box.add_child(info_lbl)
	elif cancel_mode == "reset":
		var warn_lbl := SocialUi.label("⚠️ Hết lượt bỏ miễn phí và không có [%s] (Kỳ Trân Các). Hủy nhiệm vụ sẽ bị phạt đưa tiến độ hôm nay trở về #1 làm lại từ đầu!" % DaTauData.FREE_CANCEL_ITEM_NAME, SocialUi.MUTED, 12)
		warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn_lbl.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35))
		_content_box.add_child(warn_lbl)

## Hiển thị 3 Option Chọn Thưởng chuẩn gốc JX1 (UiDaTau.ini & datau.lua)
func _render_reward_selection_3_options(_q: Dictionary) -> void:
	var state: Dictionary = DaTauManager._get_state(_profile)
	var done_today: int = state.get("done_today", 0)
	var quest_num: int = done_today + 1

	var p_panel := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(p_panel)
	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 14)
	p_panel.add_child(p_vbox)

	# 1. Tiêu đề chúc mừng
	var h_title := SocialUi.label("🎉 Nhiệm Vụ #%d Đã Hoàn Thành! Nhấp Vào Hình Để Chọn Thưởng:" % quest_num, SocialUi.TITLE, 17)
	h_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_title.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	p_vbox.add_child(h_title)

	# 2. Lấy 3 Option từ Manager
	var options := DaTauManager.get_or_create_reward_options(_profile)

	# 3. HBox chứa 3 Card Option
	var opt_hbox := HBoxContainer.new()
	opt_hbox.add_theme_constant_override("separation", 14)
	opt_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_vbox.add_child(opt_hbox)

	for i in options.size():
		var opt: Dictionary = options[i]
		var card := GameUi.panel(GameUi.SECTION)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(170, 155)
		opt_hbox.add_child(card)

		var cvbox := VBoxContainer.new()
		cvbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cvbox.add_theme_constant_override("separation", 10)
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(cvbox)

		# Icon nút thưởng chuẩn VLTK gốc (Spr\datau\ExpBtn / Money / Lucky / Item / Random / PointBtn)
		var btn_icon_name := _resolve_datau_btn_name(opt)
		var btn_tex := _get_datau_btn_texture(btn_icon_name)
		if btn_tex != null:
			var tr_btn := TextureButton.new()
			tr_btn.texture_normal = btn_tex
			tr_btn.ignore_texture_size = true
			tr_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tr_btn.custom_minimum_size = Vector2(64, 64)
			tr_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tr_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			tr_btn.tooltip_text = str(opt.get("name", "Chọn thưởng"))
			tr_btn.pressed.connect(func():
				_on_select_reward_option(i)
			)
			cvbox.add_child(tr_btn)
		else:
			var icon_btn := Button.new()
			icon_btn.text = opt.get("icon", "🎁")
			icon_btn.flat = true
			icon_btn.custom_minimum_size = Vector2(64, 64)
			icon_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			icon_btn.tooltip_text = str(opt.get("name", "Chọn thưởng"))
			icon_btn.add_theme_font_size_override("font_size", 36)
			icon_btn.pressed.connect(func():
				_on_select_reward_option(i)
			)
			cvbox.add_child(icon_btn)

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

## ====================================================================
## TAB 1: PHẦN THƯỞNG MỐC NHIỆM VỤ DÃ TẨU (CHUẨN VLTK 1)
## ====================================================================

func _render_milestones_view() -> void:
	if not _profile:
		return

	var state: Dictionary = DaTauManager._get_state(_profile)
	var total_done: int = int(state.get("total_done", 0))
	var claimed: Array = state.get("claimed_milestones", [])

	var head_panel := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head_panel)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	head_panel.add_child(hv)

	hv.add_child(SocialUi.label("Mốc Thưởng Nhiệm Vụ Dã Tẩu", SocialUi.TITLE, 17))
	var desc := SocialUi.label("Mỗi khi hoàn thành nhiệm vụ Dã Tẩu, tổng số nhiệm vụ sẽ được tích lũy. Đạt đủ các mốc dưới đây, đại hiệp có thể nhận bảo vật giang hồ vào hành trang!", SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(desc)

	var cur_done_lbl := SocialUi.label("Tổng Nhiệm Vụ Đã Hoàn Thành: %s" % DaTauManager.format_num(total_done), SocialUi.TITLE, 15)
	cur_done_lbl.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	hv.add_child(cur_done_lbl)

	if not _milestone_msg.is_empty():
		var m_banner := GameUi.panel(GameUi.SECTION)
		_content_box.add_child(m_banner)
		var mb_lbl := SocialUi.label(_milestone_msg, SocialUi.TITLE, 13)
		mb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mb_lbl.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35) if _milestone_err else WuxiaStyle.COLOR_TEXT_GOLD)
		m_banner.add_child(mb_lbl)

	for i in DaTauData.AWARD_MILESTONES.size():
		var threshold: int = DaTauData.AWARD_MILESTONES[i]
		var reward_desc: String = DaTauData.MILESTONE_REWARDS_DESC[i]
		var is_claimed: bool = i in claimed
		var can_claim: bool = total_done >= threshold and not is_claimed

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

		var m_title := SocialUi.label("Mốc %s Nhiệm Vụ" % DaTauManager.format_num(threshold), SocialUi.TITLE, 15)
		if can_claim:
			m_title.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
		cvbox.add_child(m_title)

		var r_lbl := SocialUi.label(reward_desc, SocialUi.TEXT, 13)
		r_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvbox.add_child(r_lbl)

		var btn_claim := GameUi.button("Nhận Thưởng" if can_claim else ("Đã Nhận" if is_claimed else "Chưa Đạt"), GameUi.PRIMARY if can_claim else GameUi.BUTTON)
		btn_claim.custom_minimum_size = Vector2(120, 36)
		btn_claim.disabled = not can_claim
		if can_claim:
			btn_claim.pressed.connect(_on_claim_milestone.bind(i))
		chbox.add_child(btn_claim)

func _get_misc_icon(misc_id: String) -> Texture2D:
	if misc_id.is_empty():
		return null
	var rec := ItemDatabase.get_misc(misc_id)
	if rec.is_empty():
		return null
	return ItemDatabase.get_icon(rec, false)

const _DATAU_BTN_DIR := "res://ui/events/datau/"
static var _datau_btn_cache: Dictionary = {}

## Quy đổi option phần thưởng Dã Tẩu sang tên sprite nút chuẩn VLTK gốc (UiDaTau.ini / Spr\datau\*.spr)
static func _resolve_datau_btn_name(opt: Dictionary) -> String:
	var explicit := str(opt.get("btn_icon", "")).strip_edges()
	if not explicit.is_empty():
		return explicit
	var opt_type := str(opt.get("type", ""))
	if opt_type == "exp":
		return "ExpBtn"
	if opt_type == "gold":
		return "Money"
	if opt_type == "point":
		return "PointBtn"
	var mid := str(opt.get("misc_id", ""))
	if mid in ["4_238_1", "4_239_1", "4_240_1", "4_353_1"]:
		return "Lucky"
	if mid == "6_1_1476":
		return "Random"
	return "Item"

static func _get_datau_btn_texture(btn_name: String) -> Texture2D:
	if btn_name.is_empty():
		return null
	if _datau_btn_cache.has(btn_name):
		return _datau_btn_cache[btn_name]
	var path := "%s%s.png" % [_DATAU_BTN_DIR, btn_name]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = ResourceLoader.load(path) as Texture2D
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	if tex != null:
		_datau_btn_cache[btn_name] = tex
	return tex

func _build_icon_slot(tex: Texture2D, fallback_emoji: String) -> Panel:
	var slot_p := Panel.new()
	slot_p.custom_minimum_size = Vector2(52, 52)
	slot_p.add_theme_stylebox_override("panel", WuxiaStyle.create_panel_box())
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 4
		tr.offset_top = 4
		tr.offset_right = -4
		tr.offset_bottom = -4
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_p.add_child(tr)
	else:
		var slot_icon := Label.new()
		slot_icon.text = fallback_emoji
		slot_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_icon.add_theme_font_size_override("font_size", 24)
		slot_p.add_child(slot_icon)
	return slot_p

## ====================================================================
## HANDLERS
## ====================================================================

func _on_accept_quest() -> void:
	if not _profile:
		return
	var q := DaTauManager.accept_quest(_profile)
	if not q.is_empty():
		SaveManager.save_profile(_profile, true)
	_refresh_current_view()

func _on_submit_quest() -> void:
	if not _profile:
		return
	_refresh_current_view()

func _is_online_authoritative() -> bool:
	return NetClient != null and NetClient.is_in_world() and GameManager != null and _profile == GameManager.local_profile

func _on_select_reward_option(idx: int) -> void:
	if not _profile:
		return
	if _is_online_authoritative():
		if not _awaiting_da_tau_op.is_empty():
			return
		_awaiting_da_tau_op = "claim_option"
		var op_seq := Time.get_ticks_msec()
		_awaiting_op_time = op_seq
		NetClient.send_profile(_profile.to_dict())
		NetClient.send_da_tau("claim_option", {"idx": idx})
		_last_reward_msg = "⏳ Đang nhận phần thưởng từ máy chủ..."
		_refresh_current_view()
		# Tự động chuyển về xử lý cục bộ nếu máy chủ không phản hồi sau 2.0 giây (tránh bị kẹt giao diện)
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			if _awaiting_da_tau_op == "claim_option" and _awaiting_op_time == op_seq:
				_execute_claim_option_local(idx)
		)
		return
	_execute_claim_option_local(idx)

func _execute_claim_option_local(idx: int) -> void:
	_awaiting_da_tau_op = ""
	_awaiting_op_time = 0
	var res := DaTauManager.claim_reward_option(_profile, idx)
	if str(res.get("error", "")) == "inventory_full":
		_last_reward_msg = "⚠️ Hành trang không đủ chỗ trống! Hãy dọn bớt ô trống rồi chọn thưởng lại."
	elif res.get("ok", false):
		SaveManager.save_profile(_profile, true)
		if GmManager != null and GmManager.has_signal("profile_modified"):
			GmManager.profile_modified.emit(_profile)
		_last_reward_msg = DaTauManager.format_reward_option_notice(res)
	else:
		_last_reward_msg = "Không thể nhận phần thưởng Dã Tẩu."
	_refresh_current_view()

func _on_cancel_quest() -> void:
	if not _profile:
		return
	var preview := DaTauManager.get_cancel_preview(_profile)
	if not preview.get("has_quest", false):
		return
	var mode: String = str(preview.get("mode", "reset"))
	if mode == "daily_free":
		_execute_cancel_quest()
		return
	var host := get_host()
	if host == null:
		host = self
	if mode == "item_free":
		var item_count: int = int(preview.get("item_count", 0))
		var q_num: int = int(preview.get("done_today", 0)) + 1
		SocialWindow.confirm(
			host,
			"Xác Nhận Dùng Lệnh Bài Hủy",
			"Dùng 1 [%s] (đang có %d) để bỏ qua Nhiệm Vụ #%d và tính tiếp sang Nhiệm Vụ #%d?" % [DaTauData.FREE_CANCEL_ITEM_NAME, item_count, q_num, q_num + 1],
			_execute_cancel_quest
		)
	else:
		var done_today: int = int(preview.get("done_today", 0))
		var msg: String
		if done_today > 0:
			msg = "Bạn đã hết lượt bỏ miễn phí và không có [%s]!\nNếu hủy nhiệm vụ này, tiến độ %d nhiệm vụ đã hoàn thành hôm nay sẽ bị PHẠT TRỞ VỀ #1 làm lại từ đầu.\n\nBạn có chắc chắn muốn hủy?" % [DaTauData.FREE_CANCEL_ITEM_NAME, done_today]
		else:
			msg = "Bạn đã hết lượt bỏ miễn phí và không có [%s].\nBạn có chắc chắn muốn hủy nhiệm vụ #1 hiện tại để nhận nhiệm vụ khác?" % DaTauData.FREE_CANCEL_ITEM_NAME
		SocialWindow.confirm(
			host,
			"Cảnh Báo Hủy Phạt Về #1",
			msg,
			_execute_cancel_quest
		)

func _execute_cancel_quest() -> void:
	if not _profile:
		return
	var res := DaTauManager.cancel_quest(_profile)
	if res.get("ok", false):
		var mode: String = str(res.get("mode", ""))
		match mode:
			"daily_free":
				_last_reward_msg = "⏭️ Đã bỏ qua nhiệm vụ bằng lượt miễn phí! Đã tính tiếp sang Nhiệm Vụ #%d." % (int(res.get("done_today", 0)) + 1)
			"item_free":
				_last_reward_msg = "🎫 Đã dùng 1 [%s] bỏ qua nhiệm vụ! Đã tính tiếp sang Nhiệm Vụ #%d." % [DaTauData.FREE_CANCEL_ITEM_NAME, int(res.get("done_today", 0)) + 1]
			"reset":
				_last_reward_msg = "⚠️ Đã hủy nhiệm vụ khi không có vật phẩm miễn hủy. Tiến độ hôm nay đã bị phạt trở về #1 làm lại từ đầu!"
		SaveManager.save_profile(_profile, true)
	_refresh_current_view()

func _on_skip_quest() -> void:
	_on_cancel_quest()

func _on_instant_complete_quest() -> void:
	if not _profile:
		return
	var item_count := DaTauManager.count_instant_complete_items(_profile)
	if item_count <= 0:
		return
	var state: Dictionary = DaTauManager._get_state(_profile)
	var quest_num: int = int(state.get("done_today", 0)) + 1
	var host := get_host()
	if host == null:
		host = self
	SocialWindow.confirm(
		host,
		"Xác Nhận Hoàn Thành Nhanh",
		"Dùng 1 [%s] (đang có %d) để lập tức hoàn thành Nhiệm Vụ #%d và mở chọn thưởng?" % [DaTauData.INSTANT_COMPLETE_ITEM_NAME, item_count, quest_num],
		_execute_instant_complete_quest
	)

func _execute_instant_complete_quest() -> void:
	if not _profile:
		return
	var res := DaTauManager.instant_complete_quest(_profile)
	if res.get("ok", false):
		_last_reward_msg = "🎫 Đã dùng 1 [%s] để hoàn thành ngay nhiệm vụ! Hãy chọn 1 trong 3 phần thưởng bên dưới." % DaTauData.INSTANT_COMPLETE_ITEM_NAME
		SaveManager.save_profile(_profile, true)
		if GmManager != null and GmManager.has_signal("profile_modified"):
			GmManager.profile_modified.emit(_profile)
	_refresh_current_view()

func _on_claim_milestone(idx: int) -> void:
	if not _profile:
		return
	if _is_online_authoritative():
		if not _awaiting_da_tau_op.is_empty():
			return
		_awaiting_da_tau_op = "claim_milestone"
		var op_seq := Time.get_ticks_msec()
		_awaiting_op_time = op_seq
		NetClient.send_profile(_profile.to_dict())
		NetClient.send_da_tau("claim_milestone", {"idx": idx})
		_milestone_err = false
		_milestone_msg = "⏳ Đang nhận thưởng mốc từ máy chủ..."
		_refresh_current_view()
		# Tự động chuyển về xử lý cục bộ nếu máy chủ không phản hồi sau 2.0 giây
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			if _awaiting_da_tau_op == "claim_milestone" and _awaiting_op_time == op_seq:
				_execute_claim_milestone_local(idx)
		)
		return
	_execute_claim_milestone_local(idx)

func _execute_claim_milestone_local(idx: int) -> void:
	_awaiting_da_tau_op = ""
	_awaiting_op_time = 0
	var res := DaTauManager.claim_milestone(_profile, idx)
	if res.get("error", "") == "inventory_full":
		_milestone_err = true
		_milestone_msg = "⚠️ Hành trang không đủ chỗ trống! Hãy dọn bớt ô trống rồi bấm Nhận Thưởng lại."
	elif res.get("ok", false):
		_milestone_err = false
		_milestone_msg = DaTauManager.format_milestone_notice(res)
		SaveManager.save_profile(_profile, true)
		if GmManager != null and GmManager.has_signal("profile_modified"):
			GmManager.profile_modified.emit(_profile)
	else:
		_milestone_err = true
		_milestone_msg = "Không thể nhận phần thưởng mốc tích lũy."
	_refresh_current_view()

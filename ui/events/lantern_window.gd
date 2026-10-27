extends SocialWindow
class_name LanternWindow
## Hội Hoa Đăng (Sự kiện thuần IDLE):
##   - Tab 1: Vấn Đáp Giang Hồ (Trắc nghiệm 10 câu hỏi kiếm hiệp VLTK mỗi ngày, nhận lượng lớn EXP & Phúc Duyên).
##   - Tab 2: Thắp Đèn Hoa Đăng (Cơ chế AFK tích lũy tài nguyên thụ động theo giờ, kể cả khi thoát game).

const RECORD_PATH := "user://lantern_records.json"
const MAX_QUESTIONS_PER_DAY := 10

const QUESTIONS_DATABASE := [
	{
		"q": "Môn phái nào trong thập đại môn phái thuộc ngũ hành hệ Kim?",
		"options": ["Võ Đang", "Thiếu Lâm", "Cái Bang", "Ngũ Độc"],
		"answer": 1,
		"explain": "Thiếu Lâm và Thiên Vương Bang thuộc ngũ hành hệ Kim."
	},
	{
		"q": "Hệ Mộc tương khắc với hệ nào trong ngũ hành?",
		"options": ["Hệ Hỏa", "Hệ Thủy", "Hệ Thổ", "Hệ Kim"],
		"answer": 2,
		"explain": "Quy luật tương khắc: Mộc khắc Thổ, Thổ khắc Thủy, Thủy khắc Hỏa, Hỏa khắc Kim, Kim khắc Mộc."
	},
	{
		"q": "Kỹ năng trấn phái cấp 90 của Võ Đang Khí Tông có tên là gì?",
		"options": ["Bác Cấp Nhi Phục", "Nhân Kiếm Hợp Nhất", "Thiên Địa Vô Cực", "Tọa Vọng Vô Vi"],
		"answer": 2,
		"explain": "Thiên Địa Vô Cực là chiêu thức cấp 90 uy chấn giang hồ của Võ Đang Khí Tông."
	},
	{
		"q": "Boss Hoàng Kim nào thường xuất hiện tại bản đồ Cổ Dương Động?",
		"options": ["Lam Y Y", "Hà Nhân Ngã", "Cổ Bách", "Đường Phi Yến"],
		"answer": 2,
		"explain": "Cổ Bách (hệ Kim) là thủ lĩnh trấn giữ Cổ Dương Động."
	},
	{
		"q": "Thôn trấn tân thủ đầu tiên mà hiệp khách thường đặt chân đến là gì?",
		"options": ["Ba Lăng Huyện", "Tương Dương", "Biện Kinh", "Lâm An"],
		"answer": 0,
		"explain": "Ba Lăng Huyện là một trong những tân thủ thôn kinh điển nhất của võ lâm."
	},
	{
		"q": "Môn phái nào sau đây chỉ thu nhận đệ tử nữ nhân?",
		"options": ["Thúy Yên", "Thiên Nhẫn", "Côn Lôn", "Đường Môn"],
		"answer": 0,
		"explain": "Thúy Yên Môn và Nga Mi Phái chỉ thu nhận nữ đệ tử."
	},
	{
		"q": "Hệ Thủy tương sinh cho hệ nào sau đây?",
		"options": ["Hệ Hỏa", "Hệ Mộc", "Hệ Kim", "Hệ Thổ"],
		"answer": 1,
		"explain": "Thủy sinh Mộc: nước tưới mát giúp cây cối tốt tươi."
	},
	{
		"q": "Vật phẩm nào sau đây dùng để tẩy điểm kỹ năng và tiềm năng?",
		"options": ["Tiên Thảo Lộ", "Tẩy Tủy Kinh & Tinh Hồng Bảo Thạch", "Thiên Sơn Bảo Lộ", "Sát Thủ Giản"],
		"answer": 1,
		"explain": "Tẩy Tủy Kinh và Tinh Hồng Bảo Thạch giúp tẩy điểm tiềm năng và kỹ năng môn phái."
	},
	{
		"q": "Chiến trường Tống Kim phân chia ranh giới giữa hai phe nào?",
		"options": ["Đại Tống và Đại Liêu", "Đại Tống và Đại Kim", "Đại Tống và Mông Cổ", "Đại Tống và Tây Hạ"],
		"answer": 1,
		"explain": "Chiến trường Tống Kim tái hiện cuộc chiến khốc liệt giữa triều Tống và Kim quốc."
	},
	{
		"q": "Đại Boss cuối cùng của thử thách Vượt Ải 28 tầng là ai?",
		"options": ["Huyền Giác Đại Sư", "Yên Hiểu Trái", "Độc Cô Quỷ Kiếm", "Đường Phi Yến"],
		"answer": 2,
		"explain": "Độc Cô Quỷ Kiếm ngự trị tại ải thứ 28 với sức mạnh vô song."
	},
	{
		"q": "Nhiệm vụ Thách Thức Thời Gian (Vượt Ải) do NPC nào quản lý?",
		"options": ["Bạch Doanh Doanh", "Nhiếp Thí Trần", "Dã Tẩu", "Thuyền Phu"],
		"answer": 1,
		"explain": "Nhiếp Thí Trần là vị tiền bối phụ trách khảo nghiệm Vượt Ải."
	},
	{
		"q": "Hệ Hỏa nhận thêm sát thương mạnh nhất từ hệ phái nào?",
		"options": ["Hệ Kim", "Hệ Thổ", "Hệ Thủy", "Hệ Mộc"],
		"answer": 2,
		"explain": "Thủy khắc Hỏa, các phái hệ Thủy (Nga Mi, Thúy Yên) gây sát thương cực lớn lên hệ Hỏa."
	}
]

const LANTERN_TIERS := [
	{
		"id": "paper",
		"name": "🏮 Hoa Đăng Giấy (Bình Dân)",
		"cost_text": "Miễn phí",
		"cost_gold": 0,
		"cost_jade": 0,
		"exp_per_min": 120,
		"fuyuan_per_min": 1,
		"max_hours": 8,
		"color": Color(0.9, 0.8, 0.6)
	},
	{
		"id": "silk",
		"name": "🪷 Hoa Đăng Sen Lụa (Tinh Xảo)",
		"cost_text": "50.000 Lượng",
		"cost_gold": 50000,
		"cost_jade": 0,
		"exp_per_min": 300,
		"fuyuan_per_min": 3,
		"max_hours": 10,
		"color": Color(0.4, 0.85, 1.0)
	},
	{
		"id": "gold",
		"name": "👑 Hoa Đăng Cung Đình (Hoàng Kim)",
		"cost_text": "50 KNB",
		"cost_gold": 0,
		"cost_jade": 50,
		"exp_per_min": 750,
		"fuyuan_per_min": 8,
		"max_hours": 12,
		"color": Color(1.0, 0.85, 0.25)
	}
]

var _profile: PlayerProfile
var _tab := 0
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _content_box: VBoxContainer
var _active_question_idx := 0
var _quiz_status_lbl: Label
var _quiz_box: VBoxContainer
var _lantern_timer: Timer

static func open(host: Node, profile: PlayerProfile) -> SocialWindow:
	var script: GDScript = load("res://ui/events/lantern_window.gd")
	var win: SocialWindow = script.new(profile)
	return SocialWindow.present(host, win, &"lantern")

func _init(profile: PlayerProfile = null) -> void:
	super._init("Hội Hoa Đăng Giang Hồ", "Thắp đèn phúc duyên & Đoán câu đố văn hóa kiếm hiệp", 680.0)
	_profile = profile

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(tabs)

	var t1 := GameUi.button("🏮 Vấn Đáp Câu Đố", GameUi.TAB)
	t1.custom_minimum_size = Vector2(220, 38)
	t1.pressed.connect(_select_tab.bind(0))
	tabs.add_child(t1)
	_tab_buttons.append(t1)

	var t2 := GameUi.button("🌊 Thắp Đèn Phúc Duyên (AFK)", GameUi.TAB)
	t2.custom_minimum_size = Vector2(240, 38)
	t2.pressed.connect(_select_tab.bind(1))
	tabs.add_child(t2)
	_tab_buttons.append(t2)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 480)
	body.add_child(_scroll)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 10)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_box)

	_lantern_timer = Timer.new()
	_lantern_timer.wait_time = 1.0
	_lantern_timer.autostart = true
	_lantern_timer.timeout.connect(_on_tick)
	add_child(_lantern_timer)

	_select_tab(0)

func _select_tab(idx: int) -> void:
	_tab = idx
	for i in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[i], i == idx)
	if _scroll != null:
		_scroll.scroll_vertical = 0
	for c in _content_box.get_children():
		c.queue_free()

	if idx == 0:
		_build_quiz_view()
	else:
		_build_afk_lantern_view()

# ---------------------------------------------------------------- TAB 1: QUIZ TRẮC NGHIỆM

func _build_quiz_view() -> void:
	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var answered_today: int = int(rec.get("quiz", {}).get(today, 0))

	var head_card := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head_card)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	head_card.add_child(hb)

	hb.add_child(SocialUi.label("Khảo Nghiệm Học Thức Giang Hồ (Mỗi ngày 10 câu)", SocialUi.TITLE, 17))
	var desc := SocialUi.label("Mỗi câu trả lời đúng nhận ngay: +50.000 EXP, +15 Phúc Duyên, +10 Danh Vọng. Trả lời sai vẫn nhận được một nửa phần thưởng khuyến khích!", SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(desc)

	_quiz_status_lbl = SocialUi.label("Tiến độ hôm nay: %d / %d câu" % [answered_today, MAX_QUESTIONS_PER_DAY], SocialUi.GOLD, 14)
	hb.add_child(_quiz_status_lbl)

	_quiz_box = VBoxContainer.new()
	_quiz_box.add_theme_constant_override("separation", 10)
	_content_box.add_child(_quiz_box)

	if answered_today >= MAX_QUESTIONS_PER_DAY:
		_render_quiz_completed()
	else:
		_render_current_question()

func _render_quiz_completed() -> void:
	for c in _quiz_box.get_children():
		c.queue_free()
	var card := GameUi.panel(GameUi.SECTION)
	_quiz_box.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var icon := SocialUi.label("🎉", SocialUi.GOLD, 32, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(icon)
	var done_lbl := SocialUi.label("Đại hiệp đã hoàn thành toàn bộ 10 câu đố của ngày hôm nay!", SocialUi.TITLE, 16, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(done_lbl)
	var sub := SocialUi.label("Hãy quay lại vào ngày mai để tiếp tục thể nghiệm trí tuệ võ lâm và tích lũy thêm phúc duyên.", SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(sub)

func _render_current_question() -> void:
	for c in _quiz_box.get_children():
		c.queue_free()

	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var answered_today: int = int(rec.get("quiz", {}).get(today, 0))
	var q_idx: int = answered_today % QUESTIONS_DATABASE.size()
	var q: Dictionary = QUESTIONS_DATABASE[q_idx]

	var q_card := GameUi.panel(GameUi.PANEL)
	_quiz_box.add_child(q_card)
	var q_box := VBoxContainer.new()
	q_box.add_theme_constant_override("separation", 10)
	q_card.add_child(q_box)

	var q_num_lbl := SocialUi.label("Câu hỏi số %d:" % (answered_today + 1), SocialUi.LABEL_BLUE, 14)
	q_box.add_child(q_num_lbl)

	var q_title := SocialUi.label(str(q["q"]), Color(1.0, 0.95, 0.8), 16)
	q_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_box.add_child(q_title)

	q_box.add_child(SocialUi.divider())

	var opts: Array = q["options"]
	for i in opts.size():
		var btn := SocialUi.stone_button("%s. %s" % [["A", "B", "C", "D"][i], str(opts[i])], Vector2(0, 42))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_answer_chosen.bind(q, i))
		q_box.add_child(btn)

func _on_answer_chosen(q: Dictionary, chosen_idx: int) -> void:
	var is_correct: bool = (chosen_idx == int(q["answer"]))
	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var answered_today: int = int(rec.get("quiz", {}).get(today, 0)) + 1
	var quiz_dict: Dictionary = rec.get("quiz", {})
	quiz_dict[today] = answered_today
	rec["quiz"] = quiz_dict
	_save_records(rec)

	var exp_reward := 50000 if is_correct else 25000
	var fuyuan_reward := 15 if is_correct else 5
	var prestige_reward := 10 if is_correct else 3

	if _profile:
		_profile.add_exp(exp_reward)
		_profile.fuyuan += fuyuan_reward
		_profile.prestige += prestige_reward
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()

	# Hiển thị kết quả
	for c in _quiz_box.get_children():
		c.queue_free()

	var card := GameUi.panel(GameUi.PANEL)
	_quiz_box.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var result_lbl := SocialUi.label("✓ CHÍNH XÁC!" if is_correct else "✗ CHƯA CHÍNH XÁC!", Color(0.25, 0.95, 0.45) if is_correct else Color(0.95, 0.4, 0.3), 18, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(result_lbl)

	var exp_lbl := SocialUi.label(str(q.get("explain", "")), SocialUi.TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER)
	exp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(exp_lbl)

	var rew_row := HBoxContainer.new()
	rew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_row.add_theme_constant_override("separation", 16)
	vb.add_child(rew_row)
	rew_row.add_child(SocialUi.label("+%d EXP" % exp_reward, SocialUi.GOLD, 14))
	rew_row.add_child(SocialUi.label("+%d Phúc Duyên" % fuyuan_reward, SocialUi.LABEL_GREEN, 14))
	rew_row.add_child(SocialUi.label("+%d Danh Vọng" % prestige_reward, SocialUi.LABEL_BLUE, 14))

	var next_btn := SocialUi.stone_button("Câu Tiếp Theo ➔" if answered_today < MAX_QUESTIONS_PER_DAY else "Hoàn Tất Khảo Nghiệm", Vector2(220, 42))
	next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_btn.pressed.connect(func() -> void:
		_select_tab(0)
	)
	vb.add_child(next_btn)

# ---------------------------------------------------------------- TAB 2: THẮP ĐÈN AFK

func _build_afk_lantern_view() -> void:
	var rec := _get_records()
	var lantern_data: Dictionary = rec.get("active_lantern", {})

	var info_card := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(info_card)
	var ibox := VBoxContainer.new()
	ibox.add_theme_constant_override("separation", 6)
	info_card.add_child(ibox)
	ibox.add_child(SocialUi.label("Thả Hoa Đăng Tích Lũy Phúc Duyên (Chế độ Rảnh Tay - AFK)", SocialUi.TITLE, 17))
	var desc := SocialUi.label("Thả hoa đăng trôi theo dòng sông, tự động hấp thu linh khí và tích lũy EXP & Phúc Duyên theo thời gian thực (kể cả khi tắt máy rời mạng). Bạn có thể thu hoạch bất cứ lúc nào!", SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ibox.add_child(desc)

	if not lantern_data.is_empty():
		_render_active_lantern(lantern_data)
	else:
		_render_choose_lantern()

func _render_active_lantern(data: Dictionary) -> void:
	var tier_id: String = str(data.get("tier_id", "paper"))
	var tier_cfg := {}
	for t in LANTERN_TIERS:
		if t.id == tier_id:
			tier_cfg = t
			break

	var start_unix := int(data.get("start_unix", 0))
	var now_unix := int(Time.get_unix_time_from_system())
	var elapsed_mins: int = maxi(0, int((now_unix - start_unix) / 60))
	var max_mins: int = int(tier_cfg.get("max_hours", 8)) * 60
	var collected_mins: int = mini(elapsed_mins, max_mins)

	var cur_exp: int = collected_mins * int(tier_cfg.get("exp_per_min", 100))
	var cur_fuyuan: int = collected_mins * int(tier_cfg.get("fuyuan_per_min", 1))

	var card := GameUi.panel(GameUi.SECTION)
	_content_box.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var title := SocialUi.label("Hoa Đăng Đang Trôi Trên Dòng Sông: %s" % str(tier_cfg.get("name", "")), Color(0.3, 0.9, 0.4), 16)
	box.add_child(title)

	var time_str := "%d giờ %d phút (Tối đa: %d giờ)" % [collected_mins / 60, collected_mins % 60, int(tier_cfg.get("max_hours", 8))]
	box.add_child(SocialUi.kv("⏱ Thời gian trôi:", time_str, SocialUi.LABEL_BLUE, SocialUi.GOLD, 14))
	box.add_child(SocialUi.kv("🌟 Kinh nghiệm tích lũy:", "+%d EXP" % cur_exp, SocialUi.LABEL_BLUE, SocialUi.GOLD, 14))
	box.add_child(SocialUi.kv("🏮 Điểm Phúc Duyên:", "+%d Phúc Duyên" % cur_fuyuan, SocialUi.LABEL_BLUE, SocialUi.LABEL_GREEN, 14))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	var harvest_btn := SocialUi.stone_button("🎁 Thu Hoạch Phần Thưởng", Vector2(230, 44))
	harvest_btn.disabled = collected_mins < 1
	harvest_btn.pressed.connect(_harvest_lantern.bind(cur_exp, cur_fuyuan))
	row.add_child(harvest_btn)

	var cancel_btn := SocialUi.stone_button("Thu Hồi Đèn", Vector2(130, 44))
	cancel_btn.pressed.connect(func() -> void:
		_harvest_lantern(cur_exp, cur_fuyuan)
	)
	row.add_child(cancel_btn)

func _render_choose_lantern() -> void:
	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 10)
	_content_box.add_child(list_box)

	for tier in LANTERN_TIERS:
		var card := GameUi.panel(GameUi.PANEL)
		list_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		row.add_child(info)

		info.add_child(SocialUi.label(str(tier["name"]), tier["color"], 16))
		var sub := SocialUi.label("Chi phí: %s  ·  Tối đa: %d giờ AFK" % [tier["cost_text"], tier["max_hours"]], SocialUi.MUTED, 13)
		info.add_child(sub)
		var rate := SocialUi.label("Tốc độ tích lũy: +%d EXP & +%d Phúc Duyên mỗi phút" % [tier["exp_per_min"], tier["fuyuan_per_min"]], Color(0.8, 0.95, 0.8), 13)
		info.add_child(rate)

		var light_btn := SocialUi.stone_button("Thắp Đèn", Vector2(140, 42))
		light_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		light_btn.pressed.connect(_light_lantern.bind(tier))
		row.add_child(light_btn)

func _light_lantern(tier: Dictionary) -> void:
	if _profile == null:
		return
	var cost_gold: int = int(tier.get("cost_gold", 0))
	var cost_jade: int = int(tier.get("cost_jade", 0))

	if cost_gold > 0 and _profile.gold < cost_gold:
		SocialWindow.info(self, "Không Đủ Lượng", "Cần %s lượng để thắp loại hoa đăng này." % InventoryPopup.format_money(cost_gold))
		return
	if cost_jade > 0 and _profile.jade < cost_jade:
		SocialWindow.info(self, "Không Đủ KNB", "Cần %d KNB để thắp loại hoa đăng này." % cost_jade)
		return

	if cost_gold > 0:
		_profile.gold -= cost_gold
	if cost_jade > 0:
		_profile.jade -= cost_jade

	var rec := _get_records()
	rec["active_lantern"] = {
		"tier_id": str(tier["id"]),
		"start_unix": int(Time.get_unix_time_from_system())
	}
	_save_records(rec)
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	_select_tab(1)

func _harvest_lantern(exp: int, fuyuan: int) -> void:
	if _profile:
		_profile.add_exp(exp)
		_profile.fuyuan += fuyuan
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()

	var rec := _get_records()
	rec.erase("active_lantern")
	_save_records(rec)

	SocialWindow.info(self, "Thu Hoạch Hoa Đăng", "Đại hiệp đã thu hoạch thành công:\n+ %d Điểm Kinh Nghiệm\n+ %d Điểm Phúc Duyên" % [exp, fuyuan])
	_select_tab(1)

func _on_tick() -> void:
	if _tab == 1 and is_inside_tree():
		var rec := _get_records()
		if rec.has("active_lantern"):
			_select_tab(1)

# ---------------------------------------------------------------- LƯU TRỮ

static func get_record_path(profile: PlayerProfile) -> String:
	if profile != null:
		var acc := ""
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root and tree.root.has_node("AccountApi"):
			var api = tree.root.get_node("AccountApi")
			if api.has_method("is_logged_in") and api.is_logged_in():
				acc = _sanitize_name(str(api.account.get("id", "")))
		var char_name := _sanitize_name(profile.display_name)
		if not acc.is_empty() and not char_name.is_empty():
			return "user://lantern_records_%s_%s.json" % [acc, char_name]
		elif not char_name.is_empty():
			return "user://lantern_records_%s.json" % char_name
	return RECORD_PATH

static func _sanitize_name(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s[i]
		if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_':
			out += c
		else:
			out += "_"
	return out

func _get_records() -> Dictionary:
	var path := get_record_path(_profile)
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(RECORD_PATH):
			var old_txt := FileAccess.get_file_as_string(RECORD_PATH)
			var old_p: Variant = JSON.parse_string(old_txt)
			if old_p is Dictionary:
				_save_records(old_p)
				return old_p
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

func _save_records(rec: Dictionary) -> void:
	var path := get_record_path(_profile)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rec, " "))

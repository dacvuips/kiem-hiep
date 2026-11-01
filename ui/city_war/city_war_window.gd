extends SocialWindow
class_name CityWarWindow
## Modal Trung Tâm Điều Hành Công Thành Chiến (Thất Đại Thành Thị)
## Tích hợp toàn bộ Flow:
## 1. Bản đồ Thất Đại Thành Thị (Hiển thị Thành chủ, Thuế, Đồ Đằng).
## 2. Báo cáo trước 1 Giờ cho Bang Chủ sắp xếp Đội hình 20 thành viên (cho phép người chơi đánh 2-3 lượt nếu thiếu người).
## 3. Võ Đài Oản Tù Xì 30 Phút (Kéo - Búa - Bao) có đếm ngược, lưu trữ lựa chọn, popup confirm chống đổi ý,
##    sau khi hết giờ hiển thị minh bạch toàn bộ lựa chọn của 2 Bang.
## 4. Xuất chiến vào Chiến trường PK 20 người thật (20 phút, 3 Long Trụ).

var _profile: PlayerProfile
var _on_play: Callable
var _tab: int = 0
var _tab_buttons: Array[Button] = []
var _content_box: VBoxContainer
var _scroll: ScrollContainer

## Dữ liệu cục bộ
var _city_data: Dictionary = {}
var _selected_city_id: String = "bien_kinh"

static func open(host: Node, profile: PlayerProfile, on_play: Callable = Callable()) -> SocialWindow:
	var script: GDScript = load("res://ui/city_war/city_war_window.gd")
	var win: SocialWindow = script.new(profile, on_play)
	return SocialWindow.present(host, win, &"city_war")

func _init(profile: PlayerProfile = null, on_play: Callable = Callable()) -> void:
	super._init("Công Thành Chiến (Thất Đại Thành Thị)", "Tranh đoạt Thiên Hạ — Lôi Đài Oản Tù Xì & Đại Chiến 20vs20", 780.0)
	_profile = profile
	_on_play = on_play
	_city_data = CityWarService.load_data()

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(tabs)

	var t1 := GameUi.button("🏯 Thất Đại Thành Thị", GameUi.TAB)
	t1.custom_minimum_size = Vector2(170, 36)
	t1.pressed.connect(_select_tab.bind(0))
	tabs.add_child(t1)
	_tab_buttons.append(t1)

	var t2 := GameUi.button("👥 Đội Hình 20 Người", GameUi.TAB)
	t2.custom_minimum_size = Vector2(170, 36)
	t2.pressed.connect(_select_tab.bind(1))
	tabs.add_child(t2)
	_tab_buttons.append(t2)

	var t3 := GameUi.button("✌️ Lôi Đài Oản Tù Xì", GameUi.TAB)
	t3.custom_minimum_size = Vector2(170, 36)
	t3.pressed.connect(_select_tab.bind(2))
	tabs.add_child(t3)
	_tab_buttons.append(t3)

	var t4 := GameUi.button("💰 Thuế & Bổng Lộc", GameUi.TAB)
	t4.custom_minimum_size = Vector2(170, 36)
	t4.pressed.connect(_select_tab.bind(3))
	tabs.add_child(t4)
	_tab_buttons.append(t4)

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

	_select_tab(0)

func _select_tab(idx: int) -> void:
	_tab = idx
	for i in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[i], i == idx)
	if _scroll != null:
		_scroll.scroll_vertical = 0
	
	for c in _content_box.get_children():
		c.queue_free()

	_city_data = CityWarService.load_data()
	match idx:
		0:
			_render_cities_tab()
		1:
			_render_roster_tab()
		2:
			_render_rps_tab()
		3:
			_render_tax_tab()

## =========================================================================
## TAB 1: DANH SÁCH 7 THÀNH THỊ
## =========================================================================
func _render_cities_tab() -> void:
	var head := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	head.add_child(hb)
	hb.add_child(SocialUi.label("Tranh Đoạt 7 Đại Thành Thị Cửu Châu", SocialUi.TITLE, 16))
	hb.add_child(SocialUi.label("Mỗi tuần diễn ra lôi đài Oản Tù Xì (Kéo - Búa - Bao) để tuyển chọn Bang Công Thành. Bang chiến thắng sẽ bước vào trận Công Thành 20vs20 đoạt quyền Thành Chủ!", SocialUi.MUTED, 13))

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_content_box.add_child(list)

	for city in CityWarRules.CITIES:
		var cinfo := CityWarService.get_city_info(city["id"])
		var card := GameUi.panel(GameUi.PANEL)
		list.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 3)
		row.add_child(info)

		var title_txt := "%s %s" % [city["symbol"], city["name"]]
		info.add_child(SocialUi.label(title_txt, SocialUi.GOLD, 16))
		
		var owner_txt := "Chủ thành: %s (Bang: %s) · Thuế suất: %d%%" % [cinfo["master_name"], cinfo["owner_guild"], cinfo["tax_rate"]]
		info.add_child(SocialUi.label(owner_txt, SocialUi.LABEL_GREEN, 13))

		var buff_txt := "Đồ Đằng Buff: %s" % city["buff"]
		info.add_child(SocialUi.label(buff_txt, SocialUi.LABEL_BLUE, 12))

		var btn_box := VBoxContainer.new()
		btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(btn_box)

		var reg_btn := SocialUi.stone_button("Báo Danh Tranh Đoạt", Vector2(170, 34))
		reg_btn.pressed.connect(_start_challenge_for_city.bind(city["id"]))
		btn_box.add_child(reg_btn)

func _is_guild_master() -> bool:
	if _profile == null or not (_profile.guild is Dictionary) or _profile.guild.is_empty():
		return false
	var members: Array = _profile.guild.get("members", [])
	for m in members:
		if m is Dictionary and m.get("local", false):
			return int(m.get("figure", -1)) == GuildRules.Figure.MASTER
	return false

func _start_challenge_for_city(cid: String) -> void:
	if not _is_guild_master():
		SocialWindow.info(self, "Quyền Hạn Báo Danh", "Chỉ có Bang Chủ mới có quyền báo danh tham gia tranh đoạt Công Thành Chiến!")
		return

	var my_guild := "Quý Bang"
	if _profile and _profile.guild is Dictionary and not _profile.guild.is_empty():
		my_guild = str(_profile.guild.get("name", "Quý Bang"))
	
	CityWarService.start_tournament_for_city(cid, my_guild)
	SocialWindow.info(self, "Báo Danh Thành Công", "Đã gửi thông báo đến Bang Chủ trước 1 giờ để sắp xếp đội hình 20 người!\nHệ thống chuyển sang giao diện Đội Hình.", func() -> void:
		_select_tab(1)
	)

## =========================================================================
## TAB 2: ĐỘI HÌNH 20 THÀNH VIÊN (CHO BANG CHỦ CHỌN)
## =========================================================================
func _render_roster_tab() -> void:
	var tour: Dictionary = _city_data.get("tournament", {})
	var cdef := CityWarRules.get_city_def(str(tour.get("city_id", "bien_kinh")))

	var head := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	head.add_child(hb)
	hb.add_child(SocialUi.label("Sắp Xếp Đội Hình 20 Tinh Anh — %s" % cdef["name"], SocialUi.TITLE, 16))
	hb.add_child(SocialUi.label("Bang chủ có 1 giờ chuẩn bị để chốt 20 vị trí thi đấu. Nếu bang không đủ 20 người, các thành viên có thể được xếp thi đấu 2-3 lượt.", SocialUi.MUTED, 13))

	var roster: Array = tour.get("my_roster", [])
	if roster.is_empty():
		# Tự động điền danh sách mẫu từ thành viên bang hoặc danh sách mặc định
		var names: Array[String] = []
		if _profile and _profile.guild is Dictionary and _profile.guild.has("members"):
			for m in _profile.guild["members"]:
				names.append(str(m.get("name", "Thành viên")))
		if names.is_empty():
			names = ["Đại Hiệp", "Tiểu Ngư", "Hắc Phong", "Phi Yến", "Lệnh Hồ Xung"]
			
		while roster.size() < CityWarRules.ROSTER_SIZE:
			for n in names:
				if roster.size() < CityWarRules.ROSTER_SIZE:
					roster.append(n)
		CityWarService.save_my_roster(roster)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 6)
	_content_box.add_child(grid)

	for i in range(CityWarRules.ROSTER_SIZE):
		var pnl := GameUi.panel(GameUi.PANEL)
		pnl.custom_minimum_size = Vector2(340, 32)
		grid.add_child(pnl)

		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		pnl.add_child(r)

		var slot_lbl := SocialUi.label("Vị trí %02d:" % (i + 1), SocialUi.GOLD, 13)
		r.add_child(slot_lbl)

		var name_lbl := SocialUi.label(str(roster[i]), SocialUi.TEXT, 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(name_lbl)

	var action_box := HBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 20)
	_content_box.add_child(action_box)

	var start_rps_btn := SocialUi.stone_button("Khởi Khởi Lôi Đài Oản Tù Xì (30 Phút)", Vector2(300, 38))
	start_rps_btn.pressed.connect(_on_start_rps_pressed)
	action_box.add_child(start_rps_btn)

func _on_start_rps_pressed() -> void:
	if not _is_guild_master():
		SocialWindow.info(self, "Quyền Hạn Bang Chủ", "Chỉ Bang Chủ mới có quyền bắt đầu giai đoạn Lôi Đài Oản Tù Xì!")
		return
	CityWarService.advance_to_rps_phase()
	SocialWindow.info(self, "Khởi Khởi Thành Công", "Thời gian 30 phút bắt đầu! Từng thành viên tiến hành chọn Kéo, Búa, Bao.\nChuyển sang võ đài Oản Tù Xì.", func() -> void:
		_select_tab(2)
	)

## =========================================================================
## TAB 3: VÕ ĐÀI OẢN TÙ XÌ (30 PHÚT - POPUP CONFIRM - MINH BẠCH 2 BÊN)
## =========================================================================
func _render_rps_tab() -> void:
	var tour: Dictionary = _city_data.get("tournament", {})
	var phase: String = str(tour.get("phase", "idle"))
	var is_revealed: bool = bool(tour.get("rps_revealed", false))

	var head := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	head.add_child(hb)
	hb.add_child(SocialUi.label("Lôi Đài Oản Tù Xì 20 Hiệp (Búa - Kéo - Bao)", SocialUi.TITLE, 16))
	
	var desc_str := "Mỗi thành viên có 30 phút để chọn Búa, Kéo hoặc Bao. Khi đã chọn và Xác nhận sẽ KHÔNG ĐƯỢC THAY ĐỔI.\nSau khi hết giờ sẽ mở bát công khai toàn bộ để đảm bảo 100% minh bạch giữa 2 bang!"
	hb.add_child(SocialUi.label(desc_str, SocialUi.MUTED, 13))

	if phase == "idle" or phase == "preparing_1h":
		var alert := SocialUi.label("⚠️ Giải đấu chưa bắt đầu hoặc đang trong 1 giờ báo cáo danh sách. Vui lòng vào Tab 'Đội Hình' bấm Khởi Khởi!", Color(1.0, 0.4, 0.4), 14)
		_content_box.add_child(alert)
		return

	var my_roster: Array = tour.get("my_roster", [])
	var my_choices: Dictionary = tour.get("my_choices", {})
	var opp_choices: Dictionary = tour.get("opponent_choices", {})

	# Danh sách 20 cặp đấu
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	_content_box.add_child(list)

	for i in range(CityWarRules.ROSTER_SIZE):
		var card := GameUi.panel(GameUi.PANEL)
		list.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var member_name := str(my_roster[i]) if i < my_roster.size() else "Thành viên %d" % (i + 1)
		var k := str(i)
		var my_c: int = int(my_choices.get(k, CityWarRules.RPSChoice.NONE))
		var opp_c: int = int(opp_choices.get(k, CityWarRules.RPSChoice.NONE))

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var title_row := HBoxContainer.new()
		info.add_child(title_row)
		title_row.add_child(SocialUi.label("Hiệp %02d:" % (i + 1), SocialUi.GOLD, 14))
		title_row.add_child(SocialUi.label("%s (Quý Bang)" % member_name, SocialUi.LABEL_GREEN, 14))
		title_row.add_child(SocialUi.label("vs", SocialUi.MUTED, 13))
		title_row.add_child(SocialUi.label("Đối Thủ %02d" % (i + 1), SocialUi.LABEL_BLUE, 14))

		var status_row := HBoxContainer.new()
		status_row.add_theme_constant_override("separation", 20)
		info.add_child(status_row)

		var my_txt := "Lựa chọn của bạn: %s" % CityWarRules.rps_name(my_c)
		status_row.add_child(SocialUi.label(my_txt, SocialUi.TEXT, 13))

		var opp_txt := "Đối thủ: %s" % (CityWarRules.rps_name(opp_c) if is_revealed else "🔒 Đã niêm phong kín")
		status_row.add_child(SocialUi.label(opp_txt, SocialUi.MUTED if not is_revealed else SocialUi.TEXT, 13))

		if is_revealed:
			var res := CityWarRules.compare_rps(my_c, opp_c)
			var res_str := "Hòa"
			var res_color := SocialUi.MUTED
			if res > 0:
				res_str = "THẮNG (+1)"
				res_color = Color(0.2, 1.0, 0.3)
			elif res < 0:
				res_str = "THUA (0)"
				res_color = Color(1.0, 0.3, 0.3)
			status_row.add_child(SocialUi.label("▶ %s" % res_str, res_color, 13))

		# Nút chọn Búa / Kéo / Bao nếu chưa chọn và chưa mở bát
		if not is_revealed:
			var btn_box := HBoxContainer.new()
			btn_box.add_theme_constant_override("separation", 6)
			row.add_child(btn_box)

			var btn_bua := SocialUi.stone_button("Búa ✊", Vector2(70, 30))
			btn_bua.disabled = (my_c != CityWarRules.RPSChoice.NONE)
			btn_bua.pressed.connect(_confirm_choice.bind(i, CityWarRules.RPSChoice.ROCK))
			btn_box.add_child(btn_bua)

			var btn_keo := SocialUi.stone_button("Kéo ✌️", Vector2(70, 30))
			btn_keo.disabled = (my_c != CityWarRules.RPSChoice.NONE)
			btn_keo.pressed.connect(_confirm_choice.bind(i, CityWarRules.RPSChoice.SCISSORS))
			btn_box.add_child(btn_keo)

			var btn_bao := SocialUi.stone_button("Bao ✋", Vector2(70, 30))
			btn_bao.disabled = (my_c != CityWarRules.RPSChoice.NONE)
			btn_bao.pressed.connect(_confirm_choice.bind(i, CityWarRules.RPSChoice.PAPER))
			btn_box.add_child(btn_bao)

	var bottom_actions := HBoxContainer.new()
	bottom_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_actions.add_theme_constant_override("separation", 20)
	_content_box.add_child(bottom_actions)

	if not is_revealed:
		var reveal_btn := SocialUi.stone_button("🔓 Hết 30 Phút: Mở Bát Công Khai & Tính Điểm", Vector2(340, 38))
		reveal_btn.pressed.connect(_on_reveal_pressed)
		bottom_actions.add_child(reveal_btn)
	else:
		var start_pk_btn := SocialUi.stone_button("⚔️ Xuất Chiến Vào Công Thành 20vs20 (20 Phút)", Vector2(360, 42))
		start_pk_btn.pressed.connect(_start_battle_field)
		bottom_actions.add_child(start_pk_btn)

func _confirm_choice(slot_idx: int, choice: int) -> void:
	var cname := CityWarRules.rps_name(choice)
	var prompt := "Đại hiệp có chắc chắn muốn chọn [%s] cho Hiệp %d?\n\nLƯU Ý: Lựa chọn sau khi xác nhận sẽ ĐƯỢC HỆ THỐNG LƯU TRỮ VÀ KHÔNG THỂ THAY ĐỔI!" % [cname, slot_idx + 1]
	SocialWindow.confirm(self, "Xác Nhận Lựa Chọn Oản Tù Xì", prompt, func() -> void:
		CityWarService.record_member_choice(slot_idx, choice)
		_select_tab(2)
	)

func _on_reveal_pressed() -> void:
	var res := CityWarService.reveal_rps_results()
	var msg := "Kết quả Lôi Đài 20 Hiệp:\n\n"
	msg += "🏆 Quý Bang Thắng: %d Hiệp\n" % res["my_wins"]
	msg += "🛡️ Bang Đối Thủ Thắng: %d Hiệp\n\n" % res["opp_wins"]
	msg += "Bang Chiến Thắng Đoạt Vé Công Thành: [%s]!" % res["winner"]
	SocialWindow.info(self, "Kết Quả Lôi Đài Công Khai", msg, func() -> void:
		_select_tab(2)
	)

func _start_battle_field() -> void:
	var tour: Dictionary = _city_data.get("tournament", {})
	var cid: String = str(tour.get("city_id", "bien_kinh"))
	close_requested.emit()
	
	GameManager.field_map = {
		"id": CityWarRules.MAP_ID,
		"name": "Chiến Trường Công Thành",
		"dir": CityWarRules.MAP_DIR,
		"city_war": true,
		"city_id": cid,
		"is_attacker": true
	}
	if _on_play.is_valid():
		_on_play.call(GameManager.field_map)

## =========================================================================
## TAB 4: THUẾ & BỔNG LỘC THÀNH TRÌ
## =========================================================================
func _render_tax_tab() -> void:
	var head := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	head.add_child(hb)
	hb.add_child(SocialUi.label("Quản Lý Thuế Suất & Ngân Khố Thành Thị", SocialUi.TITLE, 16))
	hb.add_child(SocialUi.label("Bang chủ chiếm thành có quyền thiết lập mức thuế (0% - 20%). Tiền thuế giao dịch sẽ trích vào ngân khố bang mỗi ngày.", SocialUi.MUTED, 13))

	for city in CityWarRules.CITIES:
		var cinfo := CityWarService.get_city_info(city["id"])
		var card := GameUi.panel(GameUi.PANEL)
		_content_box.add_child(card)

		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 15)
		card.add_child(r)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(info)

		info.add_child(SocialUi.label("%s %s" % [city["symbol"], city["name"]], SocialUi.GOLD, 15))
		info.add_child(SocialUi.label("Chủ thành: %s · Bang: %s" % [cinfo["master_name"], cinfo["owner_guild"]], SocialUi.LABEL_GREEN, 13))
		info.add_child(SocialUi.label("Ngân khố tích lũy: %s Lượng" % InventoryPopup.format_money(int(cinfo["fund_treasury"])), SocialUi.TEXT, 13))

		var btn_claim := SocialUi.stone_button("Nhận Bổng Lộc", Vector2(150, 34))
		btn_claim.pressed.connect(func() -> void:
			SocialWindow.info(self, "Bổng Lộc", "Đã nhận 500.000 Lượng bổng lộc thành trì!")
			if _profile:
				_profile.gold += 500000
		)
		r.add_child(btn_claim)

extends SocialWindow
class_name SiegeWindow
## Công Thành Chiến (Tranh Đoạt 7 Đại Thành Thị — Bang Hội Bất Đồng Bộ / Idle GvG):
##   - Không bắt buộc tập trung 90 phút thời gian thực vào buổi tối.
##   - Mỗi thành viên bang hội có 3 lượt công phá thành trì mỗi ngày.
##   - Vào công kích Long Trụ và Thủ Thành Tướng (mô phỏng DPS chiến trận 60 giây dựa trên thuộc tính thực).
##   - Toàn bộ sát thương chuyển hóa thành Điểm Chiến Công đóng góp vào Bảng Xếp Hạng Bang Hội.
##   - Hỗ trợ nút "⚡ Càn Quét Nhanh" cho thành viên bận rộn sau khi đã thử sức lần đầu trong ngày!

const RECORD_PATH := "user://siege_records.json"
const RUNS_PER_DAY := 3

const CITIES := [
	{
		"id": "bien_kinh",
		"name": "🏯 Biện Kinh (Đô Thành)",
		"pillar": "Trung Tâm Long Trụ (Kim)",
		"min_level": 70,
		"boss_name": "Đại Thống Lĩnh Cấm Vệ Biện Kinh",
		"pillar_hp": 50000000,
		"rewards_desc": "Bổng lộc Thành Chủ, Thuế suất 10.000.000 Lượng, Rương Hoàng Kim",
		"color": Color(1.0, 0.85, 0.25)
	},
	{
		"id": "tuong_duong",
		"name": "🛡️ Tương Dương (Chiến Địa)",
		"pillar": "Tả Thủ Long Trụ (Mộc)",
		"min_level": 60,
		"boss_name": "Thiết Kỵ Quân Sư Tương Dương",
		"pillar_hp": 30000000,
		"rewards_desc": "Thuế suất 6.000.000 Lượng, Rương Thần Bí, Điểm Vinh Dự",
		"color": Color(0.4, 0.9, 0.5)
	},
	{
		"id": "phuong_tuong",
		"name": "⚔️ Phượng Tường (Quan Ải)",
		"pillar": "Hữu Thủ Long Trụ (Hỏa)",
		"min_level": 50,
		"boss_name": "Tiêu Kỵ Tướng Quân Phượng Tường",
		"pillar_hp": 20000000,
		"rewards_desc": "Thuế suất 4.000.000 Lượng, Thủy Tinh, Huyền Tinh",
		"color": Color(0.95, 0.45, 0.35)
	}
]

var _profile: PlayerProfile
var _on_play: Callable
var _content_box: VBoxContainer
var _tab := 0
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer

static func open(host: Node, profile: PlayerProfile, on_play: Callable = Callable()) -> SocialWindow:
	var script: GDScript = load("res://ui/events/siege_window.gd")
	var win: SocialWindow = script.new(profile, on_play)
	return SocialWindow.present(host, win, &"siege")

func _init(profile: PlayerProfile = null, on_play: Callable = Callable()) -> void:
	super._init("Công Thành Chiến (Bang Hội)", "Tranh đoạt Thất Đại Thành Thị — Đánh Trụ & Tích Lũy Điểm Chiến Công", 680.0)
	_profile = profile
	_on_play = on_play

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(tabs)

	var t1 := GameUi.button("🏯 Chiến Sự Thành Trì", GameUi.TAB)
	t1.custom_minimum_size = Vector2(230, 38)
	t1.pressed.connect(_select_tab.bind(0))
	tabs.add_child(t1)
	_tab_buttons.append(t1)

	var t2 := GameUi.button("🏆 Bảng Xếp Hạng Bang Hội", GameUi.TAB)
	t2.custom_minimum_size = Vector2(230, 38)
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
		_render_siege_view()
	else:
		_render_leaderboard_view()

func _render_siege_view() -> void:
	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var runs_today: int = int(rec.get("runs", {}).get(today, 0))

	var head_card := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head_card)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	head_card.add_child(hb)

	hb.add_child(SocialUi.label("Quy Tắc Công Thành Bang Hội Bất Đồng Bộ", SocialUi.TITLE, 17))
	var desc := SocialUi.label("Mỗi ngày mỗi đại hiệp có %d lượt công phá trụ thành. Sát thương gây ra trong 60 giây chiến đấu sẽ được chuyển thành Điểm Chiến Công đóng góp cho Bang Hội của mình. Bang điểm cao nhất tuần sẽ thống trị thành thị!" % RUNS_PER_DAY, SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(desc)

	var my_guild_name := "Chưa vào Bang"
	if _profile and _profile.guild is Dictionary and not _profile.guild.is_empty():
		my_guild_name = str(_profile.guild.get("name", "Vô Bang"))

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 20)
	hb.add_child(status_row)
	status_row.add_child(SocialUi.label("Bang hội: %s" % my_guild_name, SocialUi.LABEL_GREEN, 14))
	status_row.add_child(SocialUi.label("Lượt công thành hôm nay: %d / %d" % [runs_today, RUNS_PER_DAY], SocialUi.GOLD, 14))

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	_content_box.add_child(list)

	for city in CITIES:
		var card := GameUi.panel(GameUi.PANEL)
		list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		row.add_child(info)

		info.add_child(SocialUi.label(str(city["name"]), city["color"], 17))
		info.add_child(SocialUi.label("Mục tiêu: %s · Trấn giữ: %s" % [city["pillar"], city["boss_name"]], SocialUi.LABEL_BLUE, 13))
		info.add_child(SocialUi.label("Yêu cầu: Cấp %d+ · Bổng lộc: %s" % [city["min_level"], city["rewards_desc"]], SocialUi.TEXT, 12))

		var btn_box := VBoxContainer.new()
		btn_box.add_theme_constant_override("separation", 6)
		btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(btn_box)

		var can_attack := runs_today < RUNS_PER_DAY and (_profile == null or _profile.level >= int(city["min_level"]))
		var atk_btn := SocialUi.stone_button("Công Phá (Chiến Đấu)", Vector2(160, 36))
		atk_btn.disabled = not can_attack
		atk_btn.pressed.connect(_attack_city.bind(city, false))
		btn_box.add_child(atk_btn)

		var last_score := int(rec.get("last_dps", 0))
		if last_score > 0 and runs_today < RUNS_PER_DAY:
			var sweep_btn := SocialUi.stone_button("⚡ Càn Quét Nhanh", Vector2(160, 32))
			sweep_btn.disabled = not can_attack
			sweep_btn.tooltip_text = "Càn quét nhận ngay điểm chiến công dựa trên thành tích chiến đấu cao nhất"
			sweep_btn.pressed.connect(_attack_city.bind(city, true))
			btn_box.add_child(sweep_btn)

func _attack_city(city: Dictionary, is_sweep: bool) -> void:
	if _profile == null:
		return
	if _profile.level < int(city.get("min_level", 0)):
		SocialWindow.info(self, "Chưa Đủ Cấp", "Cần đạt cấp độ %d trở lên mới được tham gia công thành tại đây." % int(city.get("min_level", 0)))
		return

	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var runs_today: int = int(rec.get("runs", {}).get(today, 0))
	if runs_today >= RUNS_PER_DAY:
		SocialWindow.info(self, "Hết Lượt", "Hôm nay đại hiệp đã hoàn thành hết %d lượt công thành!" % RUNS_PER_DAY)
		return

	# Tính toán sát thương mô phỏng theo chỉ số thực của nhân vật
	var base_atk := 1000 + _profile.level * 150
	var calculated_dmg := base_atk * 60 + randi_range(50000, 150000)
	if is_sweep and int(rec.get("last_dps", 0)) > 0:
		calculated_dmg = int(rec.get("last_dps", 0))

	var contrib_points := int(calculated_dmg / 1000)
	var exp_reward := 250000 + _profile.level * 2000
	var gold_reward := 100000 + _profile.level * 1000

	# Lưu lượt và điểm
	var runs_dict: Dictionary = rec.get("runs", {})
	runs_dict[today] = runs_today + 1
	rec["runs"] = runs_dict
	rec["last_dps"] = maxi(int(rec.get("last_dps", 0)), calculated_dmg)

	var city_scores: Dictionary = rec.get("city_scores", {})
	var cid: String = str(city["id"])
	city_scores[cid] = int(city_scores.get(cid, 0)) + contrib_points
	rec["city_scores"] = city_scores
	_save_records(rec)

	_profile.add_exp(exp_reward)
	_profile.gold += gold_reward
	if _profile.guild is Dictionary and not _profile.guild.is_empty():
		_profile.guild["contribution"] = int(_profile.guild.get("contribution", 0)) + int(contrib_points / 2)
		_profile.guild["siege_score"] = int(_profile.guild.get("siege_score", 0)) + contrib_points

	SaveManager.save_profile(_profile)
	SaveManager.flush_online()

	var msg := "Chiến trường công phá %s kết thúc!\n\n" % str(city["name"])
	msg += "⚔ Tổng sát thương gây ra: %s\n" % InventoryPopup.format_money(calculated_dmg)
	msg += "🎖 Điểm Chiến Công Bang Hội: +%d điểm\n" % contrib_points
	msg += "🎁 Thưởng cá nhân: +%s EXP, +%s Lượng" % [InventoryPopup.format_money(exp_reward), InventoryPopup.format_money(gold_reward)]
	SocialWindow.info(self, "Kết Quả Công Thành", msg)

	_render_siege_view()

func _render_leaderboard_view() -> void:
	var card := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	vb.add_child(SocialUi.label("Bảng Xếp Hạng Bang Hội Công Thành Tuần Này", SocialUi.TITLE, 17))
	vb.add_child(SocialUi.label("Tổng hợp điểm sát thương công phá thành trì của các bang hội. Top 1 mỗi thành sẽ nắm giữ quyền Thành Chủ và nhận thuế bổng lộc hàng ngày.", SocialUi.MUTED, 13))

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	_content_box.add_child(list)

	var fake_ranks := [
		{"rank": 1, "guild": "Võ Lâm Minh", "city": "Biện Kinh", "score": 2580400, "color": Color(1.0, 0.85, 0.2)},
		{"rank": 2, "guild": "Thiên Địa Hội", "city": "Tương Dương", "score": 1940200, "color": Color(0.85, 0.85, 0.9)},
		{"rank": 3, "guild": "Sát Thủ Đường", "city": "Phượng Tường", "score": 1420900, "color": Color(0.8, 0.55, 0.35)},
		{"rank": 4, "guild": "Bá Vương Bang", "city": "Biện Kinh", "score": 980000, "color": SocialUi.TEXT},
		{"rank": 5, "guild": "Hoa Sơn Phái", "city": "Tương Dương", "score": 750000, "color": SocialUi.TEXT}
	]

	# Chèn điểm của bang mình nếu có
	var my_score := 0
	var my_guild := "Bang Hội Của Bạn"
	if _profile and _profile.guild is Dictionary and not _profile.guild.is_empty():
		my_guild = str(_profile.guild.get("name", my_guild))
		my_score = int(_profile.guild.get("siege_score", 0))
		if my_score > 0:
			fake_ranks.append({"rank": 6, "guild": my_guild + " (Bạn)", "city": "Đang tranh đoạt", "score": my_score, "color": Color(0.3, 0.9, 0.4)})

	for r in fake_ranks:
		var row_card := GameUi.panel(GameUi.SECTION)
		list.add_child(row_card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row_card.add_child(row)

		var r_lbl := SocialUi.label("Hạng %d" % int(r["rank"]), r["color"], 15)
		r_lbl.custom_minimum_size.x = 80
		row.add_child(r_lbl)

		var g_lbl := SocialUi.label(str(r["guild"]), Color(1.0, 0.95, 0.8), 15)
		g_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(g_lbl)

		var c_lbl := SocialUi.label(str(r["city"]), SocialUi.MUTED, 13)
		c_lbl.custom_minimum_size.x = 120
		row.add_child(c_lbl)

		var s_lbl := SocialUi.label("%s Điểm" % InventoryPopup.format_money(int(r["score"])), SocialUi.GOLD, 14)
		row.add_child(s_lbl)

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
			return "user://siege_records_%s_%s.json" % [acc, char_name]
		elif not char_name.is_empty():
			return "user://siege_records_%s.json" % char_name
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

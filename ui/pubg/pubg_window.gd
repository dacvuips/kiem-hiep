extends SocialWindow
class_name PubgWindow
## Modal Chiến Trường Sinh Tồn (PUBG Võ Lâm / Battle Royale)
## Chế độ Solo (1 người) & Đội (2 - 3 - 4 người) trên bản đồ Tống Kim 1

var _profile: PlayerProfile
var _on_play: Callable
var _tab: int = 0
var _tabs_header: HBoxContainer
var _tab_buttons: Array[Button] = []
var _content_box: VBoxContainer
var _scroll: ScrollContainer

# Chế độ & Phòng
var _selected_mode: int = 0 # 0: Tất cả, 1: Solo, 2: Duo, 3: Trio, 4: Squad
var _current_room_id: String = ""
var _mock_rooms: Array[Dictionary] = []

# Trạng thái Phòng Chờ & Tìm Trận 50 người
var _in_waiting_room: bool = false
var _current_room: Dictionary = {}
var _is_ready: bool = false
var _is_searching: bool = false
var _search_time_left: float = 60.0
var _matched_players_count: int = 1
var _search_tick_accum: float = 0.0
var _lbl_countdown: Label
var _lbl_players_found: Label
var _progress_bar: ProgressBar
var _btn_ready: Button
var _btn_cancel_search: Button

# Build Level 200 (Tiềm năng & Kỹ năng)
const MAX_STAT_PTS: int = 995
const MAX_SKILL_PTS: int = 199
var _stat_allocated: Dictionary = {
	"str": 0,
	"dex": 0,
	"vit": 0,
	"eng": 0
}
var _skill_points_left: int = 199
var _stat_points_left: int = 995

# Tham chiếu UI điểm tiềm năng
var _lbl_stat_rem: Label
var _edit_str: LineEdit
var _edit_dex: LineEdit
var _edit_vit: LineEdit
var _edit_eng: LineEdit
var _lbl_build_status: Label

# Modal rộng hơn (màn 1280x720) để đủ chỗ 4 thẻ thành viên + khung chat
const WIN_W: float = 1200.0
const CHAT_W: float = 300.0
const CARDS_W: float = 830.0

# Tạo phòng theo số người & vào phòng bằng mã
var _create_mode: int = 1
var _edit_join_code: LineEdit

# Khung chat phòng chờ (lịch sử lưu trong room["chat"])
var _chat_log: RichTextLabel
var _chat_input: LineEdit
const BOT_CHAT_LINES := ["Ok đại ca!", "Vào trận nhớ bám đội nhé.", "Đệ sẵn sàng rồi.", "Nhặt đồ Hoàng Kim chia nhau nha!", "Theo vòng bo mà chạy, đừng tách đội.", "Haha, lần này phải top 1!"]
const BOT_SECTS := ["Thiếu Lâm", "Thiên Vương", "Đường Môn", "Ngũ Độc", "Nga Mi", "Thúy Yên", "Cái Bang", "Thiên Nhẫn", "Võ Đang", "Côn Lôn"]
const BOT_NAMES := ["LýTầmHoan", "SởLưuHương", "LụcTiểuPhụng", "HoaMãnLâu", "TâyMônXuyTuyết", "ATú", "TiểuLongNữ", "ĐoànDự"]

static func open(host: Node, profile: PlayerProfile, on_play: Callable = Callable()) -> SocialWindow:
	var script: GDScript = load("res://ui/pubg/pubg_window.gd")
	var win: SocialWindow = script.new(profile, on_play)
	return SocialWindow.present(host, win, &"pubg")

func _init(profile: PlayerProfile = null, on_play: Callable = Callable()) -> void:
	super._init("⚔️ CHIẾN TRƯỜNG SINH TỒN (PUBG VÕ LÂM)", "Bản Đồ Tống Kim 1 — Vòng Bo 10 Phút — Đồ Hoàng Kim 90%", WIN_W)
	_profile = profile
	_on_play = on_play
	is_full_width = false
	custom_minimum_size = Vector2(WIN_W, 660.0)

	_init_mock_rooms()
	_load_saved_build()

	_tabs_header = HBoxContainer.new()
	_tabs_header.add_theme_constant_override("separation", 10)
	_tabs_header.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_tabs_header)

	var t1 := GameUi.button("🏠 Danh Sách Phòng PUBG", GameUi.TAB)
	t1.custom_minimum_size = Vector2(210, 36)
	t1.pressed.connect(_select_tab.bind(0))
	_tabs_header.add_child(t1)
	_tab_buttons.append(t1)

	var t2 := GameUi.button("⚡ Phân Bổ Điểm Cấp 200", GameUi.TAB)
	t2.custom_minimum_size = Vector2(210, 36)
	t2.pressed.connect(_select_tab.bind(1))
	_tabs_header.add_child(t2)
	_tab_buttons.append(t2)

	var t3 := GameUi.button("📜 Luật Chơi & Bản Đồ", GameUi.TAB)
	t3.custom_minimum_size = Vector2(210, 36)
	t3.pressed.connect(_select_tab.bind(2))
	_tabs_header.add_child(t3)
	_tab_buttons.append(t3)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 540.0)
	body.add_child(_scroll)

	_content_box = VBoxContainer.new()
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content_box)

	_select_tab(0)

func _init_mock_rooms() -> void:
	if PubgManager.rooms.is_empty():
		PubgManager.init_default_rooms()
	_mock_rooms = PubgManager.rooms

func _load_saved_build() -> void:
	var path := "user://pubg_build.json"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var text := f.get_as_text()
			var json_obj = JSON.parse_string(text)
			if json_obj is Dictionary:
				var d: Dictionary = json_obj
				if d.get("has_custom_build", false) == true or (int(d.get("str", 0)) + int(d.get("dex", 0)) + int(d.get("vit", 0)) + int(d.get("eng", 0)) > 0):
					_stat_allocated["str"] = int(d.get("str", 0))
					_stat_allocated["dex"] = int(d.get("dex", 0))
					_stat_allocated["vit"] = int(d.get("vit", 0))
					_stat_allocated["eng"] = int(d.get("eng", 0))
					var used_stat: int = _stat_allocated["str"] + _stat_allocated["dex"] + _stat_allocated["vit"] + _stat_allocated["eng"]
					_stat_points_left = clampi(MAX_STAT_PTS - used_stat, 0, MAX_STAT_PTS)
					return
	# Nếu CHƯA sét mặc định: Trở về ban đầu hết (0 điểm phân bổ, 995 điểm còn lại)
	_stat_allocated = {"str": 0, "dex": 0, "vit": 0, "eng": 0}
	_stat_points_left = MAX_STAT_PTS

func _save_build_to_file() -> void:
	var path := "user://pubg_build.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		var data := {
			"has_custom_build": true,
			"str": _stat_allocated["str"],
			"dex": _stat_allocated["dex"],
			"vit": _stat_allocated["vit"],
			"eng": _stat_allocated["eng"],
			"stat_left": _stat_points_left
		}
		f.store_string(JSON.stringify(data, "\t"))

func _process(delta: float) -> void:
	if _is_searching:
		_search_time_left -= delta
		_search_tick_accum += delta

		# Trong lúc đang tìm trận, nếu có phòng thi đấu < 5 phút mở ra thì ghép vào thay Bot ngay
		var inc_cnt: int = maxi(1, _members(_current_room).size())
		var cur_r_id: String = str(_current_room.get("id", ""))
		var active_match: Dictionary = PubgManager.find_joinable_active_match(inc_cnt, cur_r_id)
		if not active_match.is_empty():
			_handle_backfill_match_found(active_match, inc_cnt, cur_r_id)
			return

		# Mỗi 1.2s tăng ngẫu nhiên số người chơi tìm thấy (1-3 người)
		if _search_tick_accum >= 1.2:
			_search_tick_accum = 0.0
			var add_p: int = randi_range(1, 3)
			_matched_players_count = mini(50, _matched_players_count + add_p)

		if _lbl_countdown != null and is_instance_valid(_lbl_countdown):
			var sec: int = maxi(0, ceili(_search_time_left))
			_lbl_countdown.text = "⏱️ THỜI GIAN TÌM TRẬN: %02d GIÂY" % sec
		if _lbl_players_found != null and is_instance_valid(_lbl_players_found):
			_lbl_players_found.text = "👥 Đã tìm thấy: %d / 50 người chơi" % _matched_players_count
		if _progress_bar != null and is_instance_valid(_progress_bar):
			_progress_bar.value = float(_matched_players_count)

		# Hết 60 giây hoặc đã đủ 50 người chơi -> Vào trận đấu (không tự động thêm bot nếu hết 60s)
		if _search_time_left <= 0.0 or _matched_players_count >= 50:
			_is_searching = false
			if _lbl_countdown != null and is_instance_valid(_lbl_countdown):
				if _matched_players_count >= 50:
					_lbl_countdown.text = "🎉 ĐÃ TÌM ĐỦ 50/50 NGƯỜI CHƠI!"
				else:
					_lbl_countdown.text = "⚔️ HẾT THỜI GIAN TÌM TRẬN — VÀO CHIẾN TRƯỜNG (%d NGƯỜI)!" % _matched_players_count
			if _lbl_players_found != null and is_instance_valid(_lbl_players_found):
				_lbl_players_found.text = "Đang kết nối vào Chiến Trường Sinh Tồn..."

			set_process(false)
			# Chờ ngắn để người chơi thấy thông báo rồi chuyển cảnh
			if is_inside_tree() and get_tree() != null:
				get_tree().create_timer(0.8).timeout.connect(func():
					_do_enter_match(_current_room)
				)
			else:
				_do_enter_match(_current_room)

func _select_tab(idx: int) -> void:
	_in_waiting_room = false
	_is_searching = false
	set_process(false)
	_tab = idx
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].modulate = Color(1.2, 1.1, 0.6) if i == idx else Color(0.8, 0.8, 0.8)
	_render_content()

func _clear_content_box() -> void:
	for c in _content_box.get_children():
		_content_box.remove_child(c)
		c.queue_free()

func _render_content() -> void:
	_clear_content_box()

	if _tabs_header != null and is_instance_valid(_tabs_header):
		_tabs_header.visible = not _in_waiting_room

	if _in_waiting_room:
		_render_waiting_room()
		return

	match _tab:
		0:
			_render_tab_rooms()
		1:
			_render_tab_stats()
		2:
			_render_tab_rules()

# ==============================================================================
# TAB 0: DANH SÁCH PHÒNG PUBG
# ==============================================================================
func _render_tab_rooms() -> void:
	_clear_content_box()

	# Header & Filter Chế độ (sử dụng OptionButton - Select)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	_content_box.add_child(top_bar)

	var lbl_mode := Label.new()
	lbl_mode.text = "🎯 Lọc Chế Độ:"
	lbl_mode.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	top_bar.add_child(lbl_mode)

	var opt_mode := OptionButton.new()
	opt_mode.custom_minimum_size = Vector2(180, 32)
	opt_mode.add_item("✨ Tất Cả Chế Độ", 0)
	opt_mode.add_item("👤 1 Người (Solo)", 1)
	opt_mode.add_item("👥 2 Người (Duo)", 2)
	opt_mode.add_item("🛡️ 3 Người (Trio)", 3)
	opt_mode.add_item("🔥 4 Người (Squad)", 4)

	# Chọn đúng chế độ đang chọn
	for i in range(opt_mode.item_count):
		if opt_mode.get_item_id(i) == _selected_mode:
			opt_mode.select(i)
			break

	opt_mode.item_selected.connect(func(idx: int):
		_selected_mode = opt_mode.get_item_id(idx)
		_render_content()
	)
	top_bar.add_child(opt_mode)

	# Nút Tạo Phòng Nhanh
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	# Vào phòng bằng mã phòng của chủ phòng
	_edit_join_code = LineEdit.new()
	_edit_join_code.placeholder_text = "Nhập mã phòng (VD: PUBG-1024)"
	_edit_join_code.custom_minimum_size = Vector2(230, 32)
	_edit_join_code.max_length = 12
	_edit_join_code.text_submitted.connect(func(_t: String) -> void: _on_join_by_code())
	top_bar.add_child(_edit_join_code)

	var btn_join_code := Button.new()
	btn_join_code.text = "🔑 Vào Bằng Mã"
	btn_join_code.custom_minimum_size = Vector2(130, 32)
	btn_join_code.modulate = Color(0.5, 0.9, 1.2)
	btn_join_code.pressed.connect(_on_join_by_code)
	top_bar.add_child(btn_join_code)

	var sep := VSeparator.new()
	top_bar.add_child(sep)

	# Tạo phòng: chọn số người 1-2-3-4
	var opt_create := OptionButton.new()
	opt_create.custom_minimum_size = Vector2(120, 32)
	opt_create.tooltip_text = "Số người trong đội của phòng sẽ tạo"
	for n in range(1, 5):
		opt_create.add_item("%d người" % n, n)
	opt_create.select(clampi(_create_mode, 1, 4) - 1)
	opt_create.item_selected.connect(func(idx: int) -> void: _create_mode = opt_create.get_item_id(idx))
	top_bar.add_child(opt_create)

	var btn_create := Button.new()
	btn_create.text = "➕ Tạo Phòng"
	btn_create.custom_minimum_size = Vector2(120, 32)
	btn_create.modulate = Color(0.4, 1.2, 0.6)
	btn_create.pressed.connect(_on_create_room_pressed)
	top_bar.add_child(btn_create)

	# Bảng Danh sách phòng
	var table_header := PanelContainer.new()
	var h_box := HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 8)
	table_header.add_child(h_box)

	var h_id := Label.new(); h_id.text = "Mã Phòng"; h_id.custom_minimum_size = Vector2(130, 26)
	h_id.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	var h_leader := Label.new(); h_leader.text = "Chủ Phòng"; h_leader.custom_minimum_size = Vector2(150, 26)
	h_leader.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	var h_type := Label.new(); h_type.text = "Chế Độ"; h_type.custom_minimum_size = Vector2(120, 26)
	h_type.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	var h_count := Label.new(); h_count.text = "Số Người"; h_count.custom_minimum_size = Vector2(90, 26)
	h_count.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	var h_stat := Label.new(); h_stat.text = "Trạng Thái"; h_stat.custom_minimum_size = Vector2(100, 26)
	h_stat.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	var h_spacer := Control.new(); h_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h_act := Label.new(); h_act.text = "Thao Tác"; h_act.custom_minimum_size = Vector2(120, 26)
	h_act.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))

	h_box.add_child(h_id)
	h_box.add_child(h_leader)
	h_box.add_child(h_type)
	h_box.add_child(h_count)
	h_box.add_child(h_stat)
	h_box.add_child(h_spacer)
	h_box.add_child(h_act)
	_content_box.add_child(table_header)

	# Duyệt qua các phòng
	var room_list_box := VBoxContainer.new()
	room_list_box.add_theme_constant_override("separation", 6)
	_content_box.add_child(room_list_box)

	var count_matched := 0
	for r in _mock_rooms:
		var r_mode: int = int(r.get("mode", 1))
		if _selected_mode != 0 and r_mode != _selected_mode:
			continue
		count_matched += 1

		var row := PanelContainer.new()
		var r_box := HBoxContainer.new()
		r_box.add_theme_constant_override("separation", 8)
		row.add_child(r_box)

		# Mã phòng kèm icon khóa 🔒 nếu có mật khẩu
		var is_locked: bool = str(r.get("password", "")).strip_edges() != ""
		var l_id := Label.new()
		l_id.text = ("%s 🔒" if is_locked else "%s") % str(r.get("id", ""))
		l_id.custom_minimum_size = Vector2(130, 32)
		l_id.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))

		# Cột Chủ Phòng: ngắn lại tầm 150px, nếu dài hơn thì hiển thị "..."
		var l_leader := Label.new()
		l_leader.text = str(r.get("leader", ""))
		l_leader.custom_minimum_size = Vector2(150, 32)
		l_leader.clip_text = true
		l_leader.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l_leader.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		l_leader.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))

		var l_type := Label.new()
		match r_mode:
			1: l_type.text = "Solo (1)"
			2: l_type.text = "Duo (2)"
			3: l_type.text = "Trio (3)"
			4: l_type.text = "Squad (4)"
		l_type.custom_minimum_size = Vector2(120, 32)

		var cur_p: int = int(r.get("players", 1))
		var max_p: int = int(r.get("max_players", 1))
		var l_count := Label.new(); l_count.text = "%d / %d" % [cur_p, max_p]; l_count.custom_minimum_size = Vector2(90, 32)

		var status_str: String = str(r.get("status", "Sẵn Sàng"))
		var l_stat := Label.new(); l_stat.text = status_str; l_stat.custom_minimum_size = Vector2(100, 32)
		if status_str == "Đang Đấu":
			l_stat.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		else:
			l_stat.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

		var row_spacer := Control.new()
		row_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn_join := Button.new()
		btn_join.custom_minimum_size = Vector2(130, 32)
		var is_my_room: bool = (_profile != null and str(r.get("leader", r.get("host", ""))) == _profile.display_name)
		if status_str == "Đang Đấu":
			var start_t: float = float(r.get("start_time", 0.0))
			var elapsed_sec: float = (Time.get_unix_time_from_system() - start_t) if start_t > 0.0 else 999.0
			var bot_c: int = int(r.get("bot_count", 0))
			if elapsed_sec >= 0.0 and elapsed_sec < 300.0 and bot_c > 0:
				var m_val: int = int(elapsed_sec) / 60
				var s_val: int = int(elapsed_sec) % 60
				btn_join.text = "⚡ Thay Bot (%02d:%02d)" % [m_val, s_val]
				btn_join.disabled = false
				btn_join.modulate = Color(0.3, 1.2, 0.5)
				btn_join.pressed.connect(_on_late_join_match.bind(r))
			else:
				btn_join.text = "Đang Đấu"
				btn_join.disabled = true
				btn_join.modulate = Color(0.6, 0.6, 0.6)
		elif cur_p >= max_p and not is_my_room:
			btn_join.text = "Phòng Đầy"
			btn_join.disabled = true
			btn_join.modulate = Color(0.6, 0.6, 0.6)
		else:
			btn_join.text = "🏠 Phòng Chờ" if is_my_room else "⚔️ Vào Phòng"
			btn_join.modulate = Color(1.0, 0.9, 0.3)
			btn_join.pressed.connect(_on_join_room.bind(r))

		r_box.add_child(l_id)
		r_box.add_child(l_leader)
		r_box.add_child(l_type)
		r_box.add_child(l_count)
		r_box.add_child(l_stat)
		r_box.add_child(row_spacer)
		r_box.add_child(btn_join)
		room_list_box.add_child(row)

	if count_matched == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Hiện chưa có phòng nào thuộc chế độ này. Hãy bấm 'Tạo Phòng Mới' để làm chủ phòng!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		room_list_box.add_child(empty_lbl)

	# Banner thông báo nhanh
	var banner := PanelContainer.new()
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b_lbl := Label.new()
	b_lbl.text = "💡 Lưu ý: Khi vào trận đấu Đội (2-4 người), đồng đội sẽ xuất hiện chung 1 vị trí,\nkhông thể đánh nhau và có tên màu Xanh Dương."
	b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	banner.add_child(b_lbl)
	_content_box.add_child(banner)

# ==============================================================================
# TAB 1: PHÂN BỔ ĐIỂM CẤP 200
# ==============================================================================
func _render_tab_stats() -> void:
	var info_box := PanelContainer.new()
	var v_info := VBoxContainer.new()
	v_info.add_theme_constant_override("separation", 6)
	info_box.add_child(v_info)

	var title_lbl := Label.new()
	title_lbl.text = "🌟 PHÂN BỔ ĐIỂM TIỀM NĂNG CẤP 200 (CHẾ ĐỘ PUBG)"
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	v_info.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "⚡ Kỹ Năng: Toàn bộ kỹ năng môn phái được MAX HẾT (Cấp Tối Đa) khi vào trận!\n💡 Tiềm Năng: Điểm tiềm năng sẽ trở về ban đầu nếu chưa ấn 'Lưu Điểm Mặc Định'.\n🛡️ Độc Lập: Mọi chỉ số và kỹ năng chỉ áp dụng trong trận PUBG, hoàn toàn không ảnh hưởng đến nhân vật bên ngoài."
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	v_info.add_child(sub_lbl)

	_lbl_stat_rem = Label.new()
	_lbl_stat_rem.text = "Điểm Tiềm Năng Còn Lại: %d / %d | Kỹ Năng Môn Phái: ĐÃ MAX HẾT" % [_stat_points_left, MAX_STAT_PTS]
	_lbl_stat_rem.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	v_info.add_child(_lbl_stat_rem)

	_content_box.add_child(info_box)

	# Khung phân bổ 4 thuộc tính
	var stat_grid := GridContainer.new()
	stat_grid.columns = 4
	stat_grid.add_theme_constant_override("h_separation", 15)
	stat_grid.add_theme_constant_override("v_separation", 12)
	_content_box.add_child(stat_grid)

	_create_stat_row(stat_grid, "Sức Mạnh (SMCB, Ngoại Công)", "str")
	_create_stat_row(stat_grid, "Thân Pháp (Né Tránh, Chính Xác)", "dex")
	_create_stat_row(stat_grid, "Sinh Khí (Máu, Thể Lực)", "vit")
	_create_stat_row(stat_grid, "Nội Công (Nội Lực, Nội Công)", "eng")

	# Hàng nút Lưu & Tẩy điểm
	var action_bar := HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 12)
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_box.add_child(action_bar)

	var btn_save := Button.new()
	btn_save.text = "💾 LƯU ĐIỂM TIỀM NĂNG (MẶC ĐỊNH)"
	btn_save.custom_minimum_size = Vector2(250, 42)
	btn_save.modulate = Color(0.3, 1.2, 0.5)
	btn_save.pressed.connect(_on_save_build_pressed)
	action_bar.add_child(btn_save)

	var btn_reset := Button.new()
	btn_reset.text = "🔄 Về Ban Đầu (Chưa Sét)"
	btn_reset.custom_minimum_size = Vector2(180, 42)
	btn_reset.modulate = Color(1.0, 0.7, 0.4)
	btn_reset.pressed.connect(_on_reset_build_pressed)
	action_bar.add_child(btn_reset)

	_lbl_build_status = Label.new()
	_lbl_build_status.text = "Cấu hình điểm tiềm năng sẽ được áp dụng khi vào trận PUBG."
	_lbl_build_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_build_status.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_content_box.add_child(_lbl_build_status)

func _create_stat_row(grid: GridContainer, stat_name: String, key: String) -> void:
	var lbl_name := Label.new()
	lbl_name.text = stat_name
	lbl_name.custom_minimum_size = Vector2(220, 32)
	lbl_name.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	grid.add_child(lbl_name)

	var edit_val := LineEdit.new()
	edit_val.text = str(_stat_allocated.get(key, 0))
	edit_val.custom_minimum_size = Vector2(75, 32)
	edit_val.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit_val.select_all_on_focus = true
	edit_val.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	edit_val.add_theme_color_override("caret_color", Color(1.0, 0.85, 0.3))
	edit_val.tooltip_text = "Nhấp để nhập số điểm tiềm năng trực tiếp"

	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color(0.06, 0.12, 0.10, 0.9)
	normal_box.border_color = Color(0.35, 0.50, 0.40, 1.0)
	normal_box.set_border_width_all(1)
	normal_box.set_corner_radius_all(4)
	edit_val.add_theme_stylebox_override("normal", normal_box)

	var focus_box := StyleBoxFlat.new()
	focus_box.bg_color = Color(0.10, 0.20, 0.16, 0.95)
	focus_box.border_color = Color(0.95, 0.82, 0.25, 1.0)
	focus_box.set_border_width_all(2)
	focus_box.set_corner_radius_all(4)
	edit_val.add_theme_stylebox_override("focus", focus_box)

	grid.add_child(edit_val)

	match key:
		"str": _edit_str = edit_val
		"dex": _edit_dex = edit_val
		"vit": _edit_vit = edit_val
		"eng": _edit_eng = edit_val

	# Xử lý nhập số trực tiếp từ bàn phím
	edit_val.text_changed.connect(func(new_text: String):
		var clean_text := ""
		for c in new_text:
			if c >= "0" and c <= "9":
				clean_text += c

		# Tính tổng điểm của 3 thuộc tính còn lại
		var other_sum := 0
		for k in ["str", "dex", "vit", "eng"]:
			if k != key:
				other_sum += int(_stat_allocated.get(k, 0))
		var max_allowed: int = clampi(MAX_STAT_PTS - other_sum, 0, MAX_STAT_PTS)

		var val := 0
		if clean_text != "":
			val = int(clean_text)
			if val > max_allowed:
				val = max_allowed
				clean_text = str(val)

		if clean_text != new_text:
			var prev_caret := edit_val.caret_column
			edit_val.text = clean_text
			edit_val.caret_column = mini(prev_caret, clean_text.length())

		_stat_allocated[key] = val
		_stat_points_left = clampi(MAX_STAT_PTS - (other_sum + val), 0, MAX_STAT_PTS)
		if is_instance_valid(_lbl_stat_rem):
			_lbl_stat_rem.text = "Điểm Tiềm Năng Còn Lại: %d / %d | Kỹ Năng Môn Phái: ĐÃ MAX HẾT" % [_stat_points_left, MAX_STAT_PTS]
	)

	var on_finish := func(_arg = null):
		var val: int = int(_stat_allocated.get(key, 0))
		edit_val.text = str(val)
	edit_val.focus_exited.connect(on_finish)
	edit_val.text_submitted.connect(on_finish)

	var btn_minus := Button.new()
	btn_minus.text = " -10 "
	btn_minus.custom_minimum_size = Vector2(50, 30)
	btn_minus.pressed.connect(func():
		var cur: int = _stat_allocated.get(key, 0)
		var change: int = mini(10, cur)
		if change > 0:
			_stat_allocated[key] = cur - change
			_stat_points_left += change
			_update_stat_ui()
	)
	grid.add_child(btn_minus)

	var btn_plus := Button.new()
	btn_plus.text = " +10 "
	btn_plus.custom_minimum_size = Vector2(50, 30)
	btn_plus.pressed.connect(func():
		var change: int = mini(10, _stat_points_left)
		if change > 0:
			_stat_allocated[key] = _stat_allocated.get(key, 0) + change
			_stat_points_left -= change
			_update_stat_ui()
	)
	grid.add_child(btn_plus)

func _update_stat_ui() -> void:
	if is_instance_valid(_edit_str): _edit_str.text = str(_stat_allocated["str"])
	if is_instance_valid(_edit_dex): _edit_dex.text = str(_stat_allocated["dex"])
	if is_instance_valid(_edit_vit): _edit_vit.text = str(_stat_allocated["vit"])
	if is_instance_valid(_edit_eng): _edit_eng.text = str(_stat_allocated["eng"])
	if is_instance_valid(_lbl_stat_rem):
		_lbl_stat_rem.text = "Điểm Tiềm Năng Còn Lại: %d / %d | Kỹ Năng Môn Phái: ĐÃ MAX HẾT" % [_stat_points_left, MAX_STAT_PTS]

func _on_save_build_pressed() -> void:
	_save_build_to_file()
	if is_instance_valid(_lbl_build_status):
		_lbl_build_status.text = "✅ Đã lưu cấu hình tiềm năng mặc định thành công! Vào trận sẽ tự động áp dụng."
		_lbl_build_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))

func _on_reset_build_pressed() -> void:
	_stat_allocated = {"str": 0, "dex": 0, "vit": 0, "eng": 0}
	_stat_points_left = MAX_STAT_PTS
	_update_stat_ui()
	var path := "user://pubg_build.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if is_instance_valid(_lbl_build_status):
		_lbl_build_status.text = "🔄 Đã xóa cấu hình mặc định. Điểm tiềm năng sẽ trở về ban đầu khi vào trận!"
		_lbl_build_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

# ==============================================================================
# TAB 2: LUẬT CHƠI & BẢN ĐỒ TỐNG KIM 1
# ==============================================================================
func _render_tab_rules() -> void:
	var rule_panel := PanelContainer.new()
	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 10)
	rule_panel.add_child(v_box)

	var r1 := Label.new()
	r1.text = "🗺️ 1. BẢN ĐỒ VÀ PHẠM VI HOẠT ĐỘNG (BẢN ĐỒ TỐNG KIM 1)"
	r1.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	v_box.add_child(r1)

	var d1 := Label.new()
	d1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d1.text = "• Trận chiến diễn ra trên chiến trường Tống Kim 1 mới.\n• Khi bắt đầu, người chơi được thả vào 1 vị trí ngẫu nhiên và bị giới hạn bởi một Khung Sáng Cố Định kích thước 140 region x 80 region (71.680 x 40.960 pixel).\n• Người chơi tuyệt đối không thể di chuyển vượt ra ngoài khung sáng bảo vệ này cho tới khi vòng chơi kết thúc."
	v_box.add_child(d1)

	var r2 := Label.new()
	r2.text = "⭕ 2. VÒNG BO THU HẸP (CHU KỲ 10 PHÚT)"
	r2.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	v_box.add_child(r2)

	var d2 := Label.new()
	d2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d2.text = "• Cứ mỗi 10 phút, sẽ có một vòng tròn nhỏ hơn xuất hiện từ vòng lớn và chạy co vào vòng an toàn mới.\n• Vị trí và bán kính vòng bo được hiển thị trực tiếp và rõ nét trên Minimap.\n• Những người chơi đứng ở bên ngoài vòng bo an toàn sẽ bị rút máu liên tục theo thời gian cho tới khi kiệt sức hoặc chạy vào trong bo."
	v_box.add_child(d2)

	var r3 := Label.new()
	r3.text = "👥 3. TỔ ĐỘI & ĐỒNG ĐỘI (CHẾ ĐỘ 2 - 3 - 4 NGƯỜI)"
	r3.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	v_box.add_child(r3)

	var d3 := Label.new()
	d3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d3.text = "• Khi tham gia chế độ Duo (2 người), Trio (3 người) hoặc Squad (4 người), toàn bộ đồng đội sẽ xuất hiện chung 1 chỗ lúc bắt đầu.\n• Các thành viên cùng đội không thể gây sát thương cho nhau (Friendly Fire bị vô hiệu hóa hoàn toàn).\n• Tên của các đồng đội trong tổ đội sẽ có màu sắc đặc trưng: Màu Xanh Dương rực rỡ để dễ dàng nhận diện."
	v_box.add_child(d3)

	var r4 := Label.new()
	r4.text = "⚔️ 4. QUÁI VẬT, TRANG BỊ HOÀNG KIM & QUY TẮC BẢO TOÀN TRANG BỊ"
	r4.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	v_box.add_child(r4)

	var d4 := Label.new()
	d4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d4.text = "• Quái vật xuất hiện rải rác trên chiến trường có tỉ lệ rơi trang bị Hoàng Kim Môn Phái lên đến 90%.\n• Toàn bộ trang bị nhặt được trong chiến trường PUBG chỉ phục vụ cho màn chơi đó để PK và sinh tồn.\n• Khi kết thúc màn chơi (chiến thắng hoặc bị hạ gục), toàn bộ đồ nhặt trong trận đều biến mất, trả lại trang bị và hành trang nguyên vẹn của nhân vật trước khi vào trận."
	v_box.add_child(d4)

	_content_box.add_child(rule_panel)

# ==============================================================================
# HÀNH ĐỘNG VÀO TRẬN & TẠO PHÒNG
# ==============================================================================
func _on_create_room_pressed() -> void:
	SocialWindow.prompt(self, "Tạo Phòng Mới", "Nhập mật khẩu (để trống nếu phòng công khai):", func(pass_val: String) -> void:
		_do_create_room(pass_val)
	, "", false)

func _do_create_room(pass_val: String = "") -> void:
	var new_id: String = "PUBG-%04d" % randi_range(1000, 9999)
	var leader_name: String = "HiệpKhách"
	if _profile and "display_name" in _profile and _profile.display_name != "":
		leader_name = _profile.display_name
	var room_mode: int = clampi(_create_mode, 1, 4)
	var clean_pass: String = pass_val.strip_edges()
	var new_room := {
		"id": new_id,
		"name": "Phòng của " + leader_name,
		"mode": room_mode,
		"mode_name": "Chế độ %d người" % room_mode,
		"players": 1,
		"players_count": 1,
		"max_players": room_mode if room_mode > 1 else 1,
		"status": "Đang Đợi",
		"status_text": "Đang Đợi",
		"leader": leader_name,
		"host": leader_name,
		"password": clean_pass,
		"members": [],
		"chat": []
	}
	var me := _make_self_member()
	me["leader"] = true
	new_room["members"].append(me)
	_room_system_msg(new_room, "%s đã tạo phòng. Gửi mã [color=#ffd84a]%s[/color] cho bạn bè để vào cùng đội." % [_esc(leader_name), new_id])
	_mock_rooms.insert(0, new_room)
	if not PubgManager.rooms.has(new_room):
		PubgManager.rooms.insert(0, new_room)

	# Chuyển ngay sang Giao Diện Phòng Chờ trên modal
	_open_waiting_room(new_room)

func _on_join_room(room_data: Dictionary) -> void:
	_ensure_members(room_data)
	var already_in: bool = _self_index(room_data) >= 0
	if not already_in and _members(room_data).size() >= int(room_data.get("mode", 1)):
		SocialWindow.confirm(self, "Thông Báo", "⚠️ Phòng %s đã đủ người!" % str(room_data.get("id", "")), Callable())
		return
	var required_pass: String = str(room_data.get("password", "")).strip_edges()
	if required_pass != "" and not already_in:
		SocialWindow.prompt(self, "Mật Khẩu Phòng", "Phòng yêu cầu mật khẩu để tham gia:", func(entered_pass: String) -> void:
			if entered_pass.strip_edges() == required_pass:
				_join_as_member(room_data)
			else:
				SocialWindow.confirm(self, "Thông Báo", "⚠️ Mật khẩu phòng không chính xác! Vui lòng thử lại.", Callable())
		, "", true)
	else:
		_join_as_member(room_data)

## Vào phòng bằng mã do chủ phòng gửi. Chấp nhận "PUBG-1024", "pubg 1024" hoặc chỉ "1024".
func _on_join_by_code() -> void:
	if _edit_join_code == null or not is_instance_valid(_edit_join_code):
		return
	var raw := _edit_join_code.text.strip_edges().to_upper().replace(" ", "").replace("_", "-")
	if raw == "":
		SocialWindow.confirm(self, "Thông Báo", "Hãy nhập mã phòng của chủ phòng (VD: PUBG-1024).", Callable())
		return
	var digits := raw.trim_prefix("PUBG").trim_prefix("-")
	var code := "PUBG-" + digits
	for r in PubgManager.rooms:
		if str(r.get("id", "")).to_upper() != code:
			continue
		if str(r.get("status", "")) == "Đang Đấu":
			SocialWindow.confirm(self, "Thông Báo", "⚔️ Phòng %s đang thi đấu, không thể vào phòng chờ." % code, Callable())
			return
		_on_join_room(r)
		return
	SocialWindow.confirm(self, "Thông Báo", "❓ Không tìm thấy phòng có mã %s." % code, Callable())

## Thêm mình vào danh sách thành viên (nếu chưa có) rồi mở phòng chờ.
func _join_as_member(room_data: Dictionary) -> void:
	_ensure_members(room_data)
	if _self_index(room_data) < 0:
		_members(room_data).append(_make_self_member())
		_sync_player_count(room_data)
		_room_system_msg(room_data, "%s đã vào phòng." % _esc(_my_name()))
	_open_waiting_room(room_data)

func _open_waiting_room(room_data: Dictionary) -> void:
	_in_waiting_room = true
	_current_room = room_data
	_current_room_id = str(room_data.get("id", ""))
	PubgManager.active_room = room_data
	_is_ready = false
	_is_searching = false
	_search_time_left = 60.0
	_matched_players_count = int(room_data.get("players", 1))
	set_process(false)
	_render_content()

# ==============================================================================
# GIAO DIỆN PHÒNG CHỜ (WAITING ROOM & MATCHMAKING 50 NGƯỜI)
# ==============================================================================
func _render_waiting_room() -> void:
	_clear_content_box()

	var r_name: String = str(_current_room.get("name", "Phòng PUBG"))
	var r_id: String = str(_current_room.get("id", "PUBG-0000"))
	var r_mode: int = int(_current_room.get("mode", 1))
	var mode_title := "Solo (1 người)"
	match r_mode:
		2: mode_title = "Duo (2 người)"
		3: mode_title = "Trio (3 người)"
		4: mode_title = "Squad (4 người)"

	# 1. Top bar: Nút Rời phòng (Quay lại) & Thông tin phòng
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	_content_box.add_child(top_bar)

	var btn_leave := Button.new()
	btn_leave.text = "⬅️ Rời Phòng (Quay lại)"
	btn_leave.custom_minimum_size = Vector2(170, 36)
	btn_leave.modulate = Color(1.2, 0.4, 0.4)
	btn_leave.pressed.connect(_on_leave_waiting_room)
	top_bar.add_child(btn_leave)

	var room_info_lbl := Label.new()
	room_info_lbl.text = "🏠 %s | Mã: %s | %s" % [r_name, r_id, mode_title]
	room_info_lbl.add_theme_font_size_override("font_size", 16)
	room_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	room_info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(room_info_lbl)

	# 2. Thẻ thành viên (1-4 thẻ theo số người của phòng) + khung chat bên phải
	_ensure_members(_current_room)
	_refresh_self_member(_current_room)
	var members: Array = _members(_current_room)

	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 10)
	_content_box.add_child(mid_row)

	var member_panel := PanelContainer.new()
	member_panel.custom_minimum_size = Vector2(CARDS_W, 0)
	var member_vbox := VBoxContainer.new()
	member_vbox.add_theme_constant_override("separation", 8)
	member_panel.add_child(member_vbox)
	mid_row.add_child(member_panel)

	var m_header := Label.new()
	m_header.text = "👥 THÀNH VIÊN TRONG PHÒNG (%d / %d)   —   Bạn bè nhập mã [%s] để vào cùng đội" % [members.size(), r_mode, r_id]
	m_header.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	member_vbox.add_child(m_header)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 10)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	member_vbox.add_child(cards_row)

	var card_w: float = minf(260.0, floorf((CARDS_W - 24.0 - 10.0 * float(r_mode - 1)) / float(r_mode)))
	var i_am_leader := _am_leader(_current_room)
	for slot in range(r_mode):
		if slot < members.size():
			cards_row.add_child(_create_member_card(members[slot], card_w, i_am_leader))
		else:
			cards_row.add_child(_create_empty_card(card_w, r_id, i_am_leader))

	mid_row.add_child(_create_chat_panel())

	# 3. Khu vực Thao Tác & Tìm Trận 50 Người
	var match_panel := PanelContainer.new()
	var match_vbox := VBoxContainer.new()
	match_vbox.add_theme_constant_override("separation", 12)
	match_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	match_panel.add_child(match_vbox)

	if not _is_searching:
		var tip_lbl := Label.new()
		tip_lbl.text = "💡 Mặc định khi vào phòng là 'Chưa Sẵn Sàng'.\nKhi bấm 'Sẵn Sàng', hệ thống sẽ bắt đầu tìm đủ 50 người chơi cho trận đấu!"
		tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tip_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		match_vbox.add_child(tip_lbl)

		_btn_ready = Button.new()
		_btn_ready.custom_minimum_size = Vector2(260, 46)
		if not _is_ready:
			_btn_ready.text = "⚡ BẤM SẴN SÀNG"
			_btn_ready.modulate = Color(0.3, 1.2, 0.5)
		else:
			_btn_ready.text = "❌ HỦY SẴN SÀNG"
			_btn_ready.modulate = Color(1.2, 0.4, 0.4)
		_btn_ready.pressed.connect(_on_toggle_ready)
		match_vbox.add_child(_btn_ready)
	else:
		# Đang tìm kiếm trận 50 người — Đếm lùi 60 giây
		var search_title := Label.new()
		search_title.text = "🔍 ĐANG TÌM KIẾM TRẬN ĐẤU PUBG (QUY MÔ 50 NGƯỜI)"
		search_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		search_title.add_theme_font_size_override("font_size", 18)
		search_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		match_vbox.add_child(search_title)

		_lbl_countdown = Label.new()
		_lbl_countdown.text = "⏱️ THỜI GIAN TÌM TRẬN: %02d GIÂY" % ceili(_search_time_left)
		_lbl_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_countdown.add_theme_font_size_override("font_size", 22)
		_lbl_countdown.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		match_vbox.add_child(_lbl_countdown)

		_lbl_players_found = Label.new()
		_lbl_players_found.text = "👥 Đã tìm thấy: %d / 50 người chơi" % _matched_players_count
		_lbl_players_found.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_players_found.add_theme_font_size_override("font_size", 14)
		_lbl_players_found.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		match_vbox.add_child(_lbl_players_found)

		_progress_bar = ProgressBar.new()
		_progress_bar.custom_minimum_size = Vector2(420, 24)
		_progress_bar.max_value = 50.0
		_progress_bar.value = float(_matched_players_count)
		match_vbox.add_child(_progress_bar)

		_btn_cancel_search = Button.new()
		_btn_cancel_search.text = "❌ HỦY TÌM TRẬN"
		_btn_cancel_search.custom_minimum_size = Vector2(200, 38)
		_btn_cancel_search.modulate = Color(1.2, 0.4, 0.4)
		_btn_cancel_search.pressed.connect(_on_cancel_search)
		match_vbox.add_child(_btn_cancel_search)

	_content_box.add_child(match_panel)

## Thẻ 1 thành viên: tên + chủ phòng, hình nhân vật (đồ đang mặc + ngựa + mặt nạ như ngoài map),
## cấp / môn phái, ngựa, ngoại trang (mặt nạ, phi phong), trạng thái sẵn sàng.
func _create_member_card(m: Dictionary, card_w: float, i_am_leader: bool) -> Control:
	var is_self: bool = bool(m.get("is_self", false))
	var is_leader: bool = bool(m.get("leader", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, 0)
	var border := GameUi.BORDER_ACTIVE if is_self else GameUi.BORDER
	card.add_theme_stylebox_override("panel", GameUi.box(GameUi.BG_INNER, border, 6, 2 if is_self else 1, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = "%s %s%s" % ["👑" if is_leader else "🛡️", str(m.get("name", "")), " (Bạn)" if is_self else ""]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_color_override("font_color", Color(0.35, 0.8, 1.0) if is_self else Color(0.95, 0.92, 0.85))
	v.add_child(name_lbl)

	# Hình nhân vật — bấm để xoay hướng
	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(0, 190)
	portrait.clip_contents = true
	portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait.tooltip_text = "Bấm để xoay nhân vật"
	portrait.add_theme_stylebox_override("panel", GameUi.box(Color(0.03, 0.05, 0.05, 0.85), GameUi.BORDER, 4, 1, 0))
	v.add_child(portrait)
	var avatar := CharacterAvatar.new()
	avatar.set_gender(str(m.get("gender", "male")))
	var look: Dictionary = m.get("look", {})
	if not look.is_empty():
		avatar.set_appearance(int(look.get("helm", -1)), int(look.get("armor", -1)), int(look.get("weapon", -1)), int(look.get("horse", -1)))
		avatar.modulate = look.get("modulate", Color.WHITE)
	avatar.scale = Vector2(1.35, 1.35)
	portrait.add_child(avatar)
	var place := func() -> void: avatar.position = Vector2(portrait.size.x * 0.5, portrait.size.y - 14.0)
	portrait.resized.connect(place)
	place.call()
	var turn := [0]
	portrait.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			turn[0] = (int(turn[0]) + 1) % 8
			avatar.face(Vector2.DOWN.rotated(deg_to_rad(45.0 * turn[0]))))

	v.add_child(_card_line("⭐ Cấp %d — %s" % [int(m.get("level", 1)), str(m.get("sect", "Vô môn phái"))], Color(1.0, 0.85, 0.35)))
	v.add_child(_card_line("🐎 Ngựa: %s" % _or_none(m.get("horse_name", "")), Color(0.85, 0.9, 0.95)))
	v.add_child(_card_line("🎭 Mặt nạ: %s" % _or_none(m.get("mask_name", "")), Color(0.85, 0.9, 0.95)))
	v.add_child(_card_line("🧥 Phi phong: %s" % _or_none(m.get("mantle_name", "")), Color(0.85, 0.9, 0.95)))

	var stat_lbl := Label.new()
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bool(m.get("ready", false)):
		stat_lbl.text = "✅ ĐÃ SẴN SÀNG"
		stat_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45))
	else:
		stat_lbl.text = "⏳ CHƯA SẴN SÀNG"
		stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	v.add_child(stat_lbl)

	# Chủ phòng được mời thành viên khác ra khỏi phòng (khi chưa tìm trận)
	if i_am_leader and not is_self and not _is_searching:
		var kick := Button.new()
		kick.text = "Mời ra"
		kick.add_theme_font_size_override("font_size", 12)
		kick.modulate = Color(1.1, 0.6, 0.5)
		kick.pressed.connect(_on_kick_member.bind(str(m.get("name", ""))))
		v.add_child(kick)
	return card

## Ô trống chờ người chơi nhập mã phòng. Chủ phòng có thể thêm đồng đội máy để chơi thử offline.
func _create_empty_card(card_w: float, room_id: String, i_am_leader: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, 0)
	card.add_theme_stylebox_override("panel", GameUi.box(Color(0.04, 0.06, 0.06, 0.6), GameUi.BORDER, 6, 1, 6))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var l := Label.new()
	l.text = "⌛ CHỖ TRỐNG\n\nĐang chờ người chơi\nnhập mã phòng:\n%s" % room_id
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.6, 0.65, 0.65))
	v.add_child(l)
	if i_am_leader and not _is_searching:
		var add_bot := Button.new()
		add_bot.text = "🤖 Thêm đồng đội máy"
		add_bot.add_theme_font_size_override("font_size", 12)
		add_bot.pressed.connect(_on_add_bot_member)
		v.add_child(add_bot)
	return card

func _card_line(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", col)
	return l

func _or_none(v: Variant) -> String:
	var s := str(v).strip_edges()
	return s if s != "" else "Không có"

## Khung chat phòng chờ — lịch sử nằm trong room["chat"] nên vẽ lại phòng vẫn giữ tin nhắn.
func _create_chat_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CHAT_W, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var h := Label.new()
	h.text = "💬 KÊNH CHAT PHÒNG"
	h.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	v.add_child(h)

	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.custom_minimum_size = Vector2(0, 240)
	_chat_log.add_theme_font_size_override("normal_font_size", 13)
	_chat_log.add_theme_stylebox_override("normal", GameUi.box(Color(0.02, 0.04, 0.04, 0.85), GameUi.BORDER, 4, 1, 6))
	v.add_child(_chat_log)
	for line in _current_room.get("chat", []):
		_chat_log.append_text(str(line) + "\n")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Nhập tin nhắn..."
	_chat_input.max_length = 120
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.text_submitted.connect(func(_t: String) -> void: _on_chat_send())
	row.add_child(_chat_input)
	var send := Button.new()
	send.text = "Gửi"
	send.custom_minimum_size = Vector2(56, 0)
	send.pressed.connect(_on_chat_send)
	row.add_child(send)
	return panel

func _on_chat_send() -> void:
	if _chat_input == null or not is_instance_valid(_chat_input):
		return
	var text := _chat_input.text.strip_edges()
	if text == "":
		return
	_chat_input.clear()
	_room_chat(_current_room, "[color=#5ccfff]%s[/color]: %s" % [_esc(_my_name()), _esc(text)])
	# Phòng giả lập offline: đồng đội máy thỉnh thoảng đáp lời
	var bots: Array = _members(_current_room).filter(func(x: Dictionary) -> bool: return bool(x.get("is_bot", false)))
	if not bots.is_empty() and randf() < 0.5 and is_inside_tree():
		var room_ref: Dictionary = _current_room
		var bot: Dictionary = bots.pick_random()
		get_tree().create_timer(randf_range(0.8, 1.8)).timeout.connect(func() -> void:
			if not is_instance_valid(self) or not _in_waiting_room or not is_same(_current_room, room_ref):
				return
			_room_chat(room_ref, "[color=#e8e0c8]%s[/color]: %s" % [_esc(str(bot.get("name", ""))), BOT_CHAT_LINES.pick_random()]))
	_chat_input.grab_focus()

## Ghi 1 dòng vào lịch sử chat của phòng và đẩy lên khung chat đang mở.
func _room_chat(room: Dictionary, bbcode: String) -> void:
	if not room.has("chat"):
		room["chat"] = []
	var hist: Array = room["chat"]
	hist.append(bbcode)
	if hist.size() > 100:
		hist.pop_front()
	if is_same(room, _current_room) and _chat_log != null and is_instance_valid(_chat_log):
		_chat_log.append_text(bbcode + "\n")

func _room_system_msg(room: Dictionary, bbcode: String) -> void:
	_room_chat(room, "[color=#9aa8a8][i]⚙ %s[/i][/color]" % bbcode)

func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

# ------------------------------------------------------------------------------
# Thành viên phòng (room["members"]) — mỗi phần tử là ảnh chụp nhân vật lúc vào phòng
# ------------------------------------------------------------------------------
func _members(room: Dictionary) -> Array:
	if not room.has("members") or not (room["members"] is Array):
		room["members"] = []
	return room["members"]

func _my_name() -> String:
	if _profile != null and _profile.display_name != "":
		return _profile.display_name
	return "HiệpKhách"

func _self_index(room: Dictionary) -> int:
	var list := _members(room)
	for i in range(list.size()):
		if bool(list[i].get("is_self", false)):
			return i
	return -1

func _am_leader(room: Dictionary) -> bool:
	var idx := _self_index(room)
	return idx >= 0 and bool(_members(room)[idx].get("leader", false))

## Ảnh chụp nhân vật thật ngoài map: đồ đang mặc, ngựa (luôn hiện nếu có), mặt nạ, phi phong.
func _make_self_member() -> Dictionary:
	var m := {"name": _my_name(), "is_self": true, "is_bot": false, "leader": false, "ready": false,
		"level": 1, "sect": "Vô môn phái", "gender": "male", "look": {}, "horse_name": "", "mask_name": "", "mantle_name": ""}
	if _profile == null:
		m["look"] = Equipment.get_appearance({}, "male", false)
		return m
	var gkey := "female" if _profile.gender == PlayerProfile.Gender.FEMALE else "male"
	var look := Equipment.get_appearance(_profile.equipment, gkey, true, _profile.show_mask)
	m["level"] = _profile.level
	m["sect"] = _profile.sect_name
	m["gender"] = str(look.get("gender", gkey))
	m["look"] = look
	var horse: ItemInstance = _profile.equipment.get(Equipment.Part.HORSE)
	var mask: ItemInstance = _profile.equipment.get(Equipment.Part.MASK)
	var mantle: ItemInstance = _profile.equipment.get(Equipment.Part.MANTLE)
	m["horse_name"] = horse.get_display_name() if horse != null else ""
	m["mask_name"] = mask.get_display_name() if mask != null else ""
	m["mantle_name"] = mantle.get_display_name() if mantle != null else ""
	return m

## Cập nhật lại ảnh chụp của mình (giữ cờ chủ phòng / sẵn sàng) mỗi lần vẽ phòng.
func _refresh_self_member(room: Dictionary) -> void:
	var idx := _self_index(room)
	if idx < 0:
		return
	var old: Dictionary = _members(room)[idx]
	var fresh := _make_self_member()
	fresh["leader"] = old.get("leader", false)
	fresh["ready"] = _is_ready
	_members(room)[idx] = fresh

func _make_bot_member(taken: Array) -> Dictionary:
	var pool: Array = BOT_NAMES.filter(func(n: String) -> bool: return not taken.has(n))
	var bot_name: String = pool.pick_random() if not pool.is_empty() else "HiệpKhách%d" % randi_range(10, 99)
	var gkey := "female" if randf() < 0.4 else "male"
	var data := AvatarData.get_for(gkey)
	var look := Equipment.get_appearance({}, gkey, false)
	var tier := randi_range(4, 10)
	look["helm"] = data.res_for_item("helm", randi_range(0, 2), tier)
	look["armor"] = data.res_for_item("armor", randi_range(0, 2), tier)
	look["weapon"] = data.res_for_item("melee", randi_range(0, 2), tier)
	var has_horse := randf() < 0.75
	if has_horse:
		look["horse"] = data.res_for_item("horse", randi_range(0, 4), randi_range(1, 10))
	return {"name": bot_name, "is_self": false, "is_bot": true, "leader": false, "ready": true,
		"level": randi_range(90, 150), "sect": BOT_SECTS.pick_random(), "gender": gkey, "look": look,
		"horse_name": ["Ô Vân Đạp Tuyết", "Xích Thố", "Tuyệt Ảnh", "Đích Lư", "Chiếu Dạ Ngọc Sư Tử"].pick_random() if has_horse else "",
		"mask_name": "", "mantle_name": ["", "", "Phi Phong Lăng Vân", "Phi Phong Ngự Phong"].pick_random()}

## Phòng giả lập có sẵn (chưa có members) -> sinh thành viên máy khớp số người đang ghi trong phòng.
func _ensure_members(room: Dictionary) -> void:
	var list := _members(room)
	if not list.is_empty():
		return
	var count: int = clampi(int(room.get("players", 1)), 1, int(room.get("mode", 1)))
	var taken: Array = [_my_name()]
	for i in range(count):
		var b := _make_bot_member(taken)
		if i == 0:
			b["name"] = str(room.get("leader", b["name"]))
			b["leader"] = true
		taken.append(b["name"])
		list.append(b)

func _sync_player_count(room: Dictionary) -> void:
	var n := _members(room).size()
	room["players"] = n
	room["players_count"] = n

func _on_add_bot_member() -> void:
	var list := _members(_current_room)
	if list.size() >= int(_current_room.get("mode", 1)):
		return
	var b := _make_bot_member(list.map(func(x: Dictionary) -> String: return str(x.get("name", ""))))
	list.append(b)
	_sync_player_count(_current_room)
	_room_system_msg(_current_room, "%s đã vào phòng." % _esc(str(b["name"])))
	_render_content()

func _on_kick_member(m_name: String) -> void:
	var list := _members(_current_room)
	for i in range(list.size() - 1, -1, -1):
		if str(list[i].get("name", "")) == m_name and not bool(list[i].get("is_self", false)):
			list.remove_at(i)
	_sync_player_count(_current_room)
	_room_system_msg(_current_room, "%s đã bị mời ra khỏi phòng." % _esc(m_name))
	_render_content()

func _on_toggle_ready() -> void:
	_is_ready = not _is_ready
	_refresh_self_member(_current_room)
	_room_system_msg(_current_room, "%s %s." % [_esc(_my_name()), "đã sẵn sàng" if _is_ready else "hủy sẵn sàng"])
	if _is_ready and _all_ready(_current_room):
		_start_matchmaking()
	else:
		_render_content()

func _all_ready(room: Dictionary) -> bool:
	for m in _members(room):
		if not bool(m.get("ready", false)):
			return false
	return true

func _start_matchmaking() -> void:
	var incoming_count: int = maxi(1, _members(_current_room).size())
	var cur_rid: String = str(_current_room.get("id", ""))

	# 1. Kiểm tra ngay các phòng đang thi đấu có thời gian dưới 5 phút (< 300 giây)
	var backfill_room: Dictionary = PubgManager.find_joinable_active_match(incoming_count, cur_rid)
	if not backfill_room.is_empty():
		_handle_backfill_match_found(backfill_room, incoming_count, cur_rid)
		return

	# 2. Nếu không có phòng < 5 phút: Tìm trận bình thường đếm lùi 60 giây (sau 60s tạo bot bù đủ 50 người)
	_is_searching = true
	_search_time_left = 60.0
	_search_tick_accum = 0.0
	_matched_players_count = clampi(incoming_count + randi_range(3, 8), 1, 49)
	set_process(true)
	_render_content()

func _handle_backfill_match_found(backfill_room: Dictionary, incoming_count: int, old_room_id: String) -> void:
	_is_searching = false
	set_process(false)

	var elapsed_sec: int = int(Time.get_unix_time_from_system() - float(backfill_room.get("start_time", 0.0)))
	var min_val: int = elapsed_sec / 60
	var sec_val: int = elapsed_sec % 60
	var time_str := "%02d:%02d" % [min_val, sec_val]

	# Xóa phòng chờ tạm do người chơi vừa tạo để không để lại phòng rác
	if old_room_id != "":
		PubgManager.leave_room(old_room_id, _profile)

	# Gắn phòng hiện tại sang phòng backfill
	_current_room = backfill_room
	_current_room_id = str(backfill_room.get("id", ""))
	PubgManager.active_room = backfill_room

	_clear_content_box()

	var notice_panel := PanelContainer.new()
	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 16)
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	notice_panel.add_child(v_box)

	var title := Label.new()
	title.text = "🎯 ĐÃ TÌM THẤY CHIẾN TRƯỜNG ĐANG DIỄN RA (< 5 PHÚT)!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	v_box.add_child(title)

	var info := Label.new()
	info.text = "Mã phòng: %s (%s) — Thời gian trận: %s (< 5:00)\n🤖 Tự động xóa %d BOT bất kỳ để nhường chỗ cho bạn vào chiến trường ngay!" % [
		str(backfill_room.get("id", "")),
		str(backfill_room.get("name", "")),
		time_str,
		incoming_count
	]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	v_box.add_child(info)

	var entering := Label.new()
	entering.text = "Đang kết nối và chuẩn bị trang bị vào game..."
	entering.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entering.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	v_box.add_child(entering)

	_content_box.add_child(notice_panel)

	# Chờ 0.8s để người chơi thấy rõ thông báo chuyển trận
	if is_inside_tree() and get_tree() != null:
		get_tree().create_timer(0.8).timeout.connect(func():
			_do_enter_backfill_match(backfill_room, incoming_count)
		)
	else:
		_do_enter_backfill_match(backfill_room, incoming_count)

func _on_late_join_match(room_data: Dictionary) -> void:
	var incoming_count: int = 1
	_do_enter_backfill_match(room_data, incoming_count)

func _do_enter_backfill_match(room_data: Dictionary, incoming_count: int) -> void:
	_current_room_id = str(room_data.get("id", ""))
	var field_entry: Dictionary = PubgManager.backfill_player_into_match(room_data, incoming_count, _profile)
	field_entry["total_match_players"] = 50

	close_requested.emit()
	queue_free()

	if _on_play.is_valid():
		_on_play.call(field_entry)
	elif GameManager and GameManager.has_method("enter_field_map"):
		GameManager.enter_field_map(field_entry)

func _on_cancel_search() -> void:
	_is_searching = false
	_is_ready = false
	_search_time_left = 60.0
	set_process(false)
	_render_content()

func _on_leave_waiting_room() -> void:
	_is_searching = false
	set_process(false)
	var rid: String = str(_current_room.get("id", ""))
	# Bỏ mình khỏi danh sách thành viên; leave_room tự trừ số người (và xóa phòng nếu mình là chủ phòng)
	var idx := _self_index(_current_room)
	if idx >= 0:
		_members(_current_room).remove_at(idx)
		_room_system_msg(_current_room, "%s đã rời phòng." % _esc(_my_name()))
	_is_ready = false
	PubgManager.leave_room(rid, _profile)
	_in_waiting_room = false
	_current_room = {}
	_current_room_id = ""
	_render_content()

func _do_enter_match(room_data: Dictionary) -> void:
	_current_room_id = str(room_data.get("id", ""))
	room_data["players"] = _matched_players_count
	room_data["bot_count"] = 0 # Bỏ tự động thêm bot nếu hết 60s

	# Lưu trạng thái nhân vật thật trước khi vào phòng đấu sinh tồn PUBG
	if _profile != null and SaveManager:
		SaveManager.save_profile(_profile)
		await SaveManager.flush_online()

	# Chuẩn bị trận đấu qua PubgManager (số người chơi thực tế tìm được)
	var field_entry: Dictionary = PubgManager.start_match(_profile, room_data)
	field_entry["total_match_players"] = _matched_players_count

	# Đóng window
	close_requested.emit()
	queue_free()

	# Gọi callback chuyển map vào Tống Kim 1
	if _on_play.is_valid():
		_on_play.call(field_entry)
	elif GameManager and GameManager.has_method("enter_field_map"):
		GameManager.enter_field_map(field_entry)

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
var _selected_mode: int = 1 # 1: Solo, 2: Duo, 3: Trio, 4: Squad
var _fill_on: bool = true   ## Tự ghép đội khi tạo đội
var _lbl_schedule: Label
var _schedule_accum: float = 0.0
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
var _chat_channel_btn: Button
var _chat_target: String = ""   ## "" = Tán gẫu cả phòng, tên = chat mật
const BOT_CHAT_LINES := ["Ok đại ca!", "Vào trận nhớ bám đội nhé.", "Đệ sẵn sàng rồi.", "Nhặt đồ Hoàng Kim chia nhau nha!", "Theo vòng bo mà chạy, đừng tách đội.", "Haha, lần này phải top 1!"]
const BOT_SECTS := ["Thiếu Lâm", "Thiên Vương", "Đường Môn", "Ngũ Độc", "Nga Mi", "Thúy Yên", "Cái Bang", "Thiên Nhẫn", "Võ Đang", "Côn Lôn"]
const BOT_NAMES := ["LýTầmHoan", "SởLưuHương", "LụcTiểuPhụng", "HoaMãnLâu", "TâyMônXuyTuyết", "ATú", "TiểuLongNữ", "ĐoànDự"]

static func open(host: Node, profile: PlayerProfile, on_play: Callable = Callable()) -> SocialWindow:
	var script: GDScript = load("res://ui/pubg/pubg_window.gd")
	var win: SocialWindow = script.new(profile, on_play)
	return SocialWindow.present(host, win, &"pubg")

func _init(profile: PlayerProfile = null, on_play: Callable = Callable()) -> void:
	super._init("⚔️ CHIẾN TRƯỜNG SINH TỒN (PUBG VÕ LÂM)", "", WIN_W)
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

	var t1 := GameUi.button("⚔️ Vào Trận", GameUi.TAB)
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
	# Như các game lớn: mở lại cửa sổ khi đang ở trong 1 phòng chờ -> quay về đúng phòng đó
	var mine := _find_room_with_self()
	if not mine.is_empty():
		_open_waiting_room(mine)

## Phòng chờ (chưa vào trận) mà mình đang là thành viên.
func _find_room_with_self() -> Dictionary:
	for r in PubgManager.rooms:
		if str(r.get("status", "")) == PubgManager.STATUS_PLAYING:
			continue
		if _self_index(r) >= 0:
			return r
	return {}

## Đóng cửa sổ khi đang tìm trận: hủy tìm (phòng không bị kẹt ở "Đang Tìm Trận"), vẫn giữ chỗ trong phòng chờ.
func _exit_tree() -> void:
	if _is_searching:
		_stop_search()

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
	if not _is_searching:
		_schedule_accum += delta
		if _schedule_accum >= 1.0:
			_schedule_accum = 0.0
			var was_open := _lbl_schedule != null and is_instance_valid(_lbl_schedule) and _lbl_schedule.text.contains("ĐANG MỞ")
			_update_schedule_label()
			# Vừa qua giờ mở / đóng -> vẽ lại để bật / khóa nút
			if _lbl_schedule != null and is_instance_valid(_lbl_schedule) and was_open != _lbl_schedule.text.contains("ĐANG MỞ"):
				_render_content()
		return
	if _is_searching:
		_search_time_left -= delta
		_search_tick_accum += delta

		# Trong lúc đang tìm trận, nếu có phòng thi đấu < 5 phút mở ra thì ghép vào thay Bot ngay
		var inc_cnt: int = maxi(1, _members(_current_room).size())
		var cur_r_id: String = str(_current_room.get("id", ""))
		var active_match: Dictionary = PubgManager.find_joinable_active_match(inc_cnt, cur_r_id, _server_id())
		if not active_match.is_empty():
			_handle_backfill_match_found(active_match, inc_cnt, cur_r_id)
			return

		# Ghép theo ĐỘI: mỗi nhịp ~1.2s có thêm 1-2 đội cùng chế độ vào hàng chờ (Solo: 1-3 người)
		var mode: int = clampi(int(_current_room.get("mode", 1)), 1, 4)
		var cap: int = PubgManager.match_capacity(mode)
		if _search_tick_accum >= 1.2:
			_search_tick_accum = 0.0
			var add_p: int = randi_range(1, 3) if mode == 1 else randi_range(1, 2) * mode
			_matched_players_count = mini(cap, _matched_players_count + add_p)

		if _lbl_countdown != null and is_instance_valid(_lbl_countdown):
			var waited: int = int(PubgManager.MATCH_SEARCH_SEC - maxf(0.0, _search_time_left))
			_lbl_countdown.text = "⏱️ Đã chờ %02d:%02d  —  tối đa %02d:%02d" % [waited / 60, waited % 60, int(PubgManager.MATCH_SEARCH_SEC) / 60, int(PubgManager.MATCH_SEARCH_SEC) % 60]
		if _lbl_players_found != null and is_instance_valid(_lbl_players_found):
			_lbl_players_found.text = "👥 Đã tìm thấy: %d / %d người chơi (%d đội)" % [_matched_players_count, cap, ceili(float(_matched_players_count) / float(mode))]
		if _progress_bar != null and is_instance_valid(_progress_bar):
			_progress_bar.max_value = float(cap)
			_progress_bar.value = float(_matched_players_count)

		# Hết 60 giây hoặc đã đủ người -> Vào trận đấu (không tự động thêm bot nếu hết 60s)
		if _search_time_left <= 0.0 or _matched_players_count >= cap:
			_is_searching = false
			if _lbl_countdown != null and is_instance_valid(_lbl_countdown):
				if _matched_players_count >= cap:
					_lbl_countdown.text = "🎉 ĐÃ TÌM ĐỦ %d/%d NGƯỜI CHƠI!" % [cap, cap]
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
# TAB 0: VÀO TRẬN — kiểu PUBG thật: KHÔNG có danh sách phòng công khai.
#   Solo: bấm Bắt Đầu là tìm trận ngay. Đội 2-4: tạo đội rồi gửi mã cho bạn bè nhập để vào.
#   Tự ghép đội (fill): đội thiếu người thì hệ thống ghép thêm người lạ khi vào trận.
#   Chỉ ghép với người cùng máy chủ; chỉ mở trong khung giờ PubgManager (20:00 hằng ngày).
# ==============================================================================
func _render_tab_rooms() -> void:
	_clear_content_box()
	var open := PubgManager.is_open()

	# 1. Máy chủ + giờ mở
	var info := PanelContainer.new()
	var info_v := VBoxContainer.new()
	info_v.add_theme_constant_override("separation", 4)
	info.add_child(info_v)
	_content_box.add_child(info)
	var srv := Label.new()
	srv.text = "🌐 Máy chủ: %s   —   chỉ ghép trận với người chơi cùng máy chủ" % _server_name()
	srv.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	info_v.add_child(srv)
	_lbl_schedule = Label.new()
	_lbl_schedule.add_theme_font_size_override("font_size", 16)
	info_v.add_child(_lbl_schedule)
	_update_schedule_label()

	# 2. Nút chính Bắt Đầu Chơi
	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 12)
	_content_box.add_child(act_row)
	var btn_start := Button.new()
	btn_start.text = "⚔️ BẮT ĐẦU CHƠI"
	btn_start.tooltip_text = "Chọn chế độ (Solo / Duo / Trio / Squad) và tham gia chiến trường"
	btn_start.custom_minimum_size = Vector2(320, 52)
	btn_start.add_theme_font_size_override("font_size", 20)
	btn_start.disabled = not open
	btn_start.modulate = Color(0.4, 1.2, 0.55) if open else Color(0.6, 0.6, 0.6)
	btn_start.pressed.connect(_on_start_pressed)
	act_row.add_child(btn_start)

	# 5. Vào đội của bạn bằng mã
	var join_title := Label.new()
	join_title.text = "🔑 VÀO ĐỘI CỦA BẠN BÈ"
	join_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_content_box.add_child(join_title)
	var join_row := HBoxContainer.new()
	join_row.alignment = BoxContainer.ALIGNMENT_CENTER
	join_row.add_theme_constant_override("separation", 10)
	_content_box.add_child(join_row)
	_edit_join_code = LineEdit.new()
	_edit_join_code.placeholder_text = "Nhập mã đội (VD: PUBG-1024 hoặc 1024)"
	_edit_join_code.custom_minimum_size = Vector2(320, 36)
	_edit_join_code.max_length = 12
	_edit_join_code.editable = open
	_edit_join_code.text_submitted.connect(func(_t: String) -> void: _on_join_by_code())
	join_row.add_child(_edit_join_code)
	var btn_join_code := Button.new()
	btn_join_code.text = "🔑 Vào Đội"
	btn_join_code.custom_minimum_size = Vector2(140, 36)
	btn_join_code.disabled = not open
	btn_join_code.modulate = Color(0.5, 0.9, 1.2)
	btn_join_code.pressed.connect(_on_join_by_code)
	join_row.add_child(btn_join_code)

	var note := Label.new()
	note.text = "Không có danh sách phòng công khai — muốn chơi cùng bạn bè thì một người tạo đội rồi gửi mã đội cho những người còn lại."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.65, 0.68, 0.68))
	_content_box.add_child(note)
	set_process(true)   ## đếm giờ mở / đóng

## Dòng giờ mở: đang mở -> còn bao lâu đóng; chưa mở -> còn bao lâu mở.
func _update_schedule_label() -> void:
	if _lbl_schedule == null or not is_instance_valid(_lbl_schedule):
		return
	var now := PubgManager.now_sec_of_day()
	if PubgManager.schedule_bypass:
		_lbl_schedule.text = "🕗 Giờ mở: %s   —   ĐANG MỞ (bỏ giới hạn giờ trên máy dev)" % PubgManager.schedule_text()
		_lbl_schedule.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	elif PubgManager.is_open_at(now):
		_lbl_schedule.text = "🕗 Giờ mở: %s   —   ĐANG MỞ, còn %s" % [PubgManager.schedule_text(), PubgManager.fmt_hms(PubgManager.secs_until_close(now))]
		_lbl_schedule.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	else:
		_lbl_schedule.text = "🕗 Giờ mở: %s   —   CHƯA MỞ, còn %s" % [PubgManager.schedule_text(), PubgManager.fmt_hms(PubgManager.secs_until_open(now))]
		_lbl_schedule.add_theme_color_override("font_color", Color(1.0, 0.5, 0.35))

## Máy chủ đang chơi: online = máy chủ đã chọn ở màn Chọn Máy Chủ; offline = 0 (không giới hạn).
func _server_id() -> int:
	if ServerSelectScreen.selected_server.is_empty():
		return 0
	return ServerSelectScreen.selected_server_id

func _server_name() -> String:
	if ServerSelectScreen.selected_server.is_empty():
		return "Ngoại tuyến (chơi với máy)"
	return str(ServerSelectScreen.selected_server.get("name", "Máy chủ %d" % ServerSelectScreen.selected_server_id))

## Chưa tới giờ mở -> báo và trả false.
func _check_open() -> bool:
	var why := PubgManager.closed_reason()
	if why == "":
		return true
	SocialWindow.confirm(self, "Chưa Tới Giờ Mở", "🕗 " + why, Callable())
	return false

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
	r2.text = "⭕ 2. VÒNG BO THU HẸP (5 LẦN BO — MỖI LẦN 10 PHÚT)"
	r2.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	v_box.add_child(r2)

	var d2 := Label.new()
	d2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d2.text = "• Có 5 lần bo, mỗi lần 7 phút (chờ 4 phút rồi co trong 3 phút). Vòng mới có tâm ngẫu nhiên, luôn nằm trọn trong vòng trước; lần thứ 5 co về chỉ còn 1 chấm.\n• Vòng xanh = vùng an toàn hiện tại, vòng trắng = vùng sắp co tới — hiện cả trong map lẫn trên Minimap. Ngoài vòng bo trời tối dần.\n• Đứng ngoài vòng bo mất máu mỗi giây (1% → 10% máu tối đa): bo càng nhỏ càng mất nhiều.\n• Mỗi lần bo co xong, thời tiết đổi ngẫu nhiên (Nắng, Mưa, Giông, Sương mù, Tuyết, Gió)."
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
## Nút chính tab Vào Trận: mở popup để chọn chế độ (Solo / Duo / Trio / Squad).
func _on_start_pressed() -> void:
	if not _check_open():
		return
	_show_mode_select_popup()

func _select_and_start_mode(mode_id: int) -> void:
	_selected_mode = clampi(mode_id, 1, 4)
	if _selected_mode <= 1:
		_on_quick_play()
	else:
		_do_create_room("", _selected_mode)

func _show_mode_select_popup() -> void:
	for c in get_children():
		if c.is_in_group("pubg_mode_popup"):
			c.queue_free()

	var overlay := Control.new()
	overlay.add_to_group("pubg_mode_popup")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", WuxiaStyle.create_panel_box())
	center.add_child(panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 24)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	pad.add_child(vbox)

	# Tiêu đề + Nút đóng
	var h_head := HBoxContainer.new()
	vbox.add_child(h_head)

	var title := Label.new()
	title.text = "🎯 CHỌN CHẾ ĐỘ THI ĐẤU"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_head.add_child(title)

	var btn_close := Button.new()
	btn_close.text = "✕"
	btn_close.flat = true
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_close.pressed.connect(overlay.queue_free)
	h_head.add_child(btn_close)

	var desc := Label.new()
	desc.text = "Chọn số lượng người chơi hoặc solo để bắt đầu:"
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(desc)

	# 4 Nút chế độ theo yêu cầu:
	var modes := [
		{"mode": 1, "text": "👤 SOLO (1 người)", "sub": "Đơn đấu độc hành — Tìm trận ngay", "color": Color(0.9, 0.95, 1.25)},
		{"mode": 2, "text": "👥 DUO (2 người)", "sub": "Song kiếm hợp bích — Tạo đội 2 người", "color": Color(1.2, 1.15, 0.7)},
		{"mode": 3, "text": "🛡️ TRIO (3 người)", "sub": "Tam anh chiến — Tạo đội 3 người", "color": Color(0.7, 1.1, 1.2)},
		{"mode": 4, "text": "🔥 SQUAD (4 người)", "sub": "Tứ hải huynh đệ — Tạo đội 4 người", "color": Color(1.25, 0.85, 0.6)},
	]

	for m in modes:
		var btn := Button.new()
		btn.text = "%s   —   %s" % [m["text"], m["sub"]]
		btn.custom_minimum_size = Vector2(460, 44)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.modulate = m["color"]
		btn.add_theme_font_size_override("font_size", 15)
		var mid: int = m["mode"]
		btn.pressed.connect(func() -> void:
			overlay.queue_free()
			_select_and_start_mode(mid))
		vbox.add_child(btn)

	var fill := CheckBox.new()
	fill.text = "🤝 Tự ghép đội — khi tạo đội 2-4 người chưa đủ thì tự ghép thêm người lạ khi vào trận"
	fill.button_pressed = _fill_on
	fill.toggled.connect(func(on: bool) -> void: _fill_on = on)
	vbox.add_child(fill)

## Tạo đội NGAY (không hỏi mật khẩu) — chủ phòng đặt mật khẩu sau trong phòng chờ nếu muốn.
func _on_create_room_pressed() -> void:
	_do_create_room("")

func _do_create_room(pass_val: String = "", mode_override: int = 0, quick: bool = false) -> Dictionary:
	_leave_other_rooms()
	var leader_name := _my_name()
	var new_id: String = PubgManager.new_room_id()
	var room_mode: int = clampi(mode_override if mode_override > 0 else _create_mode, 1, 4)
	var new_room := {
		"id": new_id,
		"name": ("Chơi Ngay — %s" if quick else "Phòng của %s") % leader_name,
		"mode": room_mode,
		"mode_name": "Chế độ %d người" % room_mode,
		"players": 1,
		"players_count": 1,
		"max_players": room_mode,
		"status": PubgManager.STATUS_FULL if room_mode == 1 else PubgManager.STATUS_WAITING,
		"status_text": "",
		"leader": leader_name,
		"host": leader_name,
		"password": pass_val.strip_edges(),
		"quick": quick,
		"server_id": _server_id(),
		"fill": _fill_on and room_mode > 1,
		"members": [],
		"chat": []
	}
	new_room["status_text"] = new_room["status"]
	var me := _make_self_member()
	me["leader"] = true
	me["ready"] = quick
	new_room["members"].append(me)
	if quick:
		_room_system_msg(new_room, "Chơi Ngay: tự động tìm trận 1 người.")
	elif room_mode > 1:
		_room_system_msg(new_room, "%s đã tạo phòng. Gửi mã [color=#ffd84a]%s[/color] cho bạn bè để vào cùng đội." % [_esc(leader_name), new_id])
	else:
		_room_system_msg(new_room, "%s đã tạo phòng 1 người." % _esc(leader_name))
	if not PubgManager.rooms.has(new_room):
		PubgManager.rooms.insert(0, new_room)
	_open_waiting_room(new_room)
	return new_room

## ⚡ Chơi Ngay: phòng 1 người, vào thẳng phòng chờ và bắt đầu tìm trận luôn (vẫn ghép trận chung hàng chờ với người khác).
func _on_quick_play() -> void:
	if not _check_open():
		return
	_do_create_room("", 1, true)
	_start_matchmaking()

## Mỗi người chỉ ở 1 phòng chờ: tạo / vào phòng khác thì tự rời phòng cũ.
func _leave_other_rooms(keep: Dictionary = {}) -> void:
	var old := _find_room_with_self()
	if not old.is_empty() and not is_same(old, keep):
		_current_room = old
		_leave_room_data(old)
		_current_room = {}

func _on_join_room(room_data: Dictionary) -> void:
	_ensure_members(room_data)
	var already_in: bool = _self_index(room_data) >= 0
	if not already_in:
		if not _check_open():
			return
		var why := PubgManager.join_block_reason(room_data, _members(room_data).size(), _server_id())
		if why != "":
			_show_join_error(why, str(room_data.get("id", "")))
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

func _show_join_error(why: String, code: String) -> void:
	var msg := ""
	match why:
		"not_found": msg = "❓ Không tìm thấy phòng có mã %s." % code
		"playing": msg = "⚔️ Phòng %s đang thi đấu, không thể vào phòng chờ." % code
		"searching": msg = "🔍 Phòng %s đang tìm trận, hãy chờ chủ phòng hủy tìm." % code
		"full": msg = "⚠️ Phòng %s đã đủ người!" % code
		"other_server": msg = "🌐 Đội %s ở máy chủ khác — chỉ vào được đội cùng máy chủ." % code
		_: msg = "Không vào được phòng %s." % code
	SocialWindow.confirm(self, "Thông Báo", msg, Callable())

## Vào phòng bằng mã do chủ phòng gửi. Chấp nhận "PUBG-1024", "pubg 1024" hoặc chỉ "1024".
func _on_join_by_code() -> void:
	if _edit_join_code == null or not is_instance_valid(_edit_join_code):
		return
	var code := PubgManager.normalize_room_code(_edit_join_code.text)
	if code == "":
		SocialWindow.confirm(self, "Thông Báo", "Hãy nhập mã phòng của chủ phòng (VD: PUBG-1024).", Callable())
		return
	var r := PubgManager.find_room(code)
	if r.is_empty():
		_show_join_error("not_found", code)
		return
	_on_join_room(r)

## Thêm mình vào danh sách thành viên (nếu chưa có) rồi mở phòng chờ.
func _join_as_member(room_data: Dictionary) -> void:
	_ensure_members(room_data)
	if _self_index(room_data) < 0:
		_leave_other_rooms(room_data)
		_members(room_data).append(_make_self_member())
		_sync_player_count(room_data)
		_room_system_msg(room_data, "%s đã vào phòng." % _esc(_my_name()))
	_open_waiting_room(room_data)

func _open_waiting_room(room_data: Dictionary) -> void:
	_in_waiting_room = true
	_current_room = room_data
	_current_room_id = str(room_data.get("id", ""))
	PubgManager.active_room = room_data
	var idx := _self_index(room_data)
	_is_ready = idx >= 0 and bool(_members(room_data)[idx].get("ready", false))
	_chat_target = ""
	_is_searching = false
	_search_time_left = PubgManager.MATCH_SEARCH_SEC
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
		var leader := _am_leader(_current_room)
		var all_ready := _all_ready(_current_room)
		var tip_lbl := Label.new()
		if leader:
			tip_lbl.text = "💡 Bấm 'Sẵn Sàng' — khi mọi người trong phòng đã Sẵn Sàng, hệ thống tự bắt đầu tìm trận (phòng chưa đủ người vẫn tìm được).\nĐội được ghép chung hàng chờ với các đội khác cho tới khi đủ %d người." % PubgManager.match_capacity(int(_current_room.get("mode", 1)))
		else:
			tip_lbl.text = "💡 Bấm 'Sẵn Sàng' để báo chủ phòng. Khi cả đội sẵn sàng, chủ phòng sẽ bắt đầu tìm trận."
		tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tip_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		match_vbox.add_child(tip_lbl)

		var btn_row := HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 12)
		match_vbox.add_child(btn_row)
		_btn_ready = Button.new()
		_btn_ready.custom_minimum_size = Vector2(260, 46)
		# Mặc định vào phòng là Chưa Sẵn Sàng — kể cả chủ phòng. Chủ phòng sẵn sàng + cả đội sẵn sàng -> Bắt Đầu Tìm Trận.
		if leader and _is_ready:
			_btn_ready.text = "⚔️ BẮT ĐẦU TÌM TRẬN" if all_ready else "⏳ CHỜ ĐỒNG ĐỘI SẴN SÀNG"
			_btn_ready.disabled = not all_ready
			_btn_ready.modulate = Color(0.3, 1.2, 0.5) if all_ready else Color(0.7, 0.7, 0.7)
			_btn_ready.pressed.connect(_start_matchmaking)
		elif not _is_ready:
			_btn_ready.text = "⚡ BẤM SẴN SÀNG"
			_btn_ready.modulate = Color(0.3, 1.2, 0.5)
			_btn_ready.pressed.connect(_on_toggle_ready)
		else:
			_btn_ready.text = "❌ HỦY SẴN SÀNG"
			_btn_ready.modulate = Color(1.2, 0.4, 0.4)
			_btn_ready.pressed.connect(_on_toggle_ready)
		btn_row.add_child(_btn_ready)
		if leader and _is_ready:
			var btn_unready := Button.new()
			btn_unready.text = "❌ Hủy Sẵn Sàng"
			btn_unready.custom_minimum_size = Vector2(150, 46)
			btn_unready.modulate = Color(1.2, 0.5, 0.45)
			btn_unready.pressed.connect(_on_toggle_ready)
			btn_row.add_child(btn_unready)
		# Chủ phòng đặt / bỏ mật khẩu ngay trong phòng chờ (phòng đội)
		if leader and int(_current_room.get("mode", 1)) > 1:
			var has_pass := str(_current_room.get("password", "")).strip_edges() != ""
			var btn_pass := Button.new()
			btn_pass.text = "🔓 Bỏ Mật Khẩu" if has_pass else "🔒 Đặt Mật Khẩu"
			btn_pass.custom_minimum_size = Vector2(150, 46)
			btn_pass.pressed.connect(_on_toggle_password)
			btn_row.add_child(btn_pass)
		# Tự ghép đội: chủ phòng bật / tắt; thành viên chỉ xem
		if int(_current_room.get("mode", 1)) > 1:
			var fill_on := bool(_current_room.get("fill", false))
			if leader:
				var btn_fill := Button.new()
				btn_fill.text = "🤝 Tự Ghép Đội: BẬT" if fill_on else "🤝 Tự Ghép Đội: TẮT"
				btn_fill.tooltip_text = "Bật: đội thiếu người sẽ được ghép thêm người lạ khi vào trận.\nTắt: vào trận đúng số người đang có."
				btn_fill.custom_minimum_size = Vector2(190, 46)
				btn_fill.modulate = Color(0.5, 1.15, 0.6) if fill_on else Color(0.8, 0.8, 0.8)
				btn_fill.pressed.connect(_on_toggle_fill)
				btn_row.add_child(btn_fill)
			var missing := PubgManager.fill_slots(_current_room, _members(_current_room).size())
			if missing > 0:
				var fill_lbl := Label.new()
				fill_lbl.text = "🤝 Đội còn thiếu %d người — sẽ tự ghép người lạ khi vào trận." % missing
				fill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				fill_lbl.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
				match_vbox.add_child(fill_lbl)
	else:
		# Đang tìm trận — ghép theo đội tới khi đủ người hoặc hết thời gian
		var r_mode_s: int = int(_current_room.get("mode", 1))
		var search_title := Label.new()
		search_title.text = "🔍 ĐANG TÌM TRẬN PUBG (%d NGƯỜI — %s)" % [PubgManager.match_capacity(r_mode_s), "SOLO" if r_mode_s == 1 else "ĐỘI %d" % r_mode_s]
		search_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		search_title.add_theme_font_size_override("font_size", 18)
		search_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		match_vbox.add_child(search_title)

		_lbl_countdown = Label.new()
		_lbl_countdown.text = "⏱️ Đã chờ 00:00"
		_lbl_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_countdown.add_theme_font_size_override("font_size", 22)
		_lbl_countdown.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		match_vbox.add_child(_lbl_countdown)

		_lbl_players_found = Label.new()
		_lbl_players_found.text = "👥 Đã tìm thấy: %d / %d người chơi" % [_matched_players_count, PubgManager.match_capacity(r_mode_s)]
		_lbl_players_found.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_players_found.add_theme_font_size_override("font_size", 14)
		_lbl_players_found.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		match_vbox.add_child(_lbl_players_found)

		_progress_bar = ProgressBar.new()
		_progress_bar.custom_minimum_size = Vector2(420, 24)
		_progress_bar.max_value = float(PubgManager.match_capacity(r_mode_s))
		_progress_bar.value = float(_matched_players_count)
		match_vbox.add_child(_progress_bar)

		_btn_cancel_search = Button.new()
		_btn_cancel_search.text = "❌ HỦY TÌM TRẬN"
		_btn_cancel_search.custom_minimum_size = Vector2(200, 38)
		_btn_cancel_search.modulate = Color(1.2, 0.4, 0.4)
		_btn_cancel_search.pressed.connect(_on_cancel_search)
		# Chỉ chủ phòng hủy tìm trận; thành viên muốn thôi thì rời phòng
		_btn_cancel_search.disabled = not _am_leader(_current_room)
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
	if not is_self:
		# Bấm tên đồng đội -> chat mật với người đó
		name_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		name_lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		name_lbl.tooltip_text = "Bấm để chat mật"
		var target_name := str(m.get("name", ""))
		name_lbl.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_set_chat_target(target_name))
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

	var lv_lbl := _card_line("Cấp %d — %s" % [int(m.get("level", 1)), str(m.get("sect", "Vô môn phái"))], Color(1.0, 0.85, 0.35))
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_font_size_override("font_size", 14)
	v.add_child(lv_lbl)

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
	l.text = "⌛ CHỖ TRỐNG\n\nGửi mã đội cho bạn bè:\n%s%s" % [room_id, "\n\n🤝 Hoặc tự ghép người lạ\nkhi vào trận" if bool(_current_room.get("fill", false)) else ""]
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
	_chat_log.meta_underlined = false
	_chat_log.meta_clicked.connect(func(meta: Variant) -> void: _set_chat_target(str(meta)))
	for line in _current_room.get("chat", []):
		_chat_log.append_text(str(line) + "\n")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	# Nút chọn kênh: Tán gẫu (cả phòng) hoặc Mật với 1 người
	_chat_channel_btn = Button.new()
	_chat_channel_btn.custom_minimum_size = Vector2(92, 0)
	_chat_channel_btn.clip_text = true
	_chat_channel_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_chat_channel_btn.add_theme_font_size_override("font_size", 12)
	_chat_channel_btn.pressed.connect(_open_channel_menu)
	row.add_child(_chat_channel_btn)
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
	_update_channel_ui()
	return panel

## Tên nhân vật trong chat bấm được (meta = tên) -> chọn chat mật với người đó.
func _name_link(n: String, col: String) -> String:
	return "[url=%s][color=%s]%s[/color][/url]" % [n.replace("]", ""), col, _esc(n)]

## Chọn kênh chat: "" = Tán gẫu (cả phòng), tên = chat mật với người đó.
func _set_chat_target(target: String) -> void:
	if target == _my_name() or (target != "" and _member_by_name(_current_room, target).is_empty()):
		return
	_chat_target = target
	_update_channel_ui()
	if _chat_input != null and is_instance_valid(_chat_input):
		_chat_input.grab_focus()

func _update_channel_ui() -> void:
	if _chat_channel_btn == null or not is_instance_valid(_chat_channel_btn):
		return
	if _chat_target == "":
		_chat_channel_btn.text = "💬 Tán gẫu"
		_chat_channel_btn.tooltip_text = "Đang chat cả phòng — bấm để chọn kênh / chat mật"
		_chat_channel_btn.modulate = Color.WHITE
		if _chat_input != null and is_instance_valid(_chat_input):
			_chat_input.placeholder_text = "Nhập tin nhắn..."
	else:
		_chat_channel_btn.text = "🔒 %s" % _chat_target
		_chat_channel_btn.tooltip_text = "Đang chat mật với %s — bấm để đổi kênh" % _chat_target
		_chat_channel_btn.modulate = Color(1.25, 0.75, 1.15)
		if _chat_input != null and is_instance_valid(_chat_input):
			_chat_input.placeholder_text = "Mật với %s..." % _chat_target

func _open_channel_menu() -> void:
	var menu := PopupMenu.new()
	menu.add_item("💬 Tán gẫu (cả phòng)", 0)
	var names: Array[String] = []
	for m in _members(_current_room):
		if not bool(m.get("is_self", false)):
			names.append(str(m.get("name", "")))
			menu.add_item("🔒 Mật: %s" % names.back(), names.size())
	menu.id_pressed.connect(func(id: int) -> void:
		_set_chat_target("" if id == 0 else names[id - 1]))
	menu.popup_hide.connect(menu.queue_free)
	_chat_channel_btn.add_child(menu)
	var r := _chat_channel_btn.get_global_rect()
	menu.popup(Rect2i(Vector2i(int(r.position.x), int(r.position.y) - 10 - 28 * (names.size() + 1)), Vector2i(int(maxf(r.size.x, 180.0)), 0)))

func _member_by_name(room: Dictionary, n: String) -> Dictionary:
	for m in _members(room):
		if str(m.get("name", "")) == n:
			return m
	return {}

func _on_chat_send() -> void:
	if _chat_input == null or not is_instance_valid(_chat_input):
		return
	var text := _chat_input.text.strip_edges()
	if text == "":
		return
	_chat_input.clear()
	var room_ref: Dictionary = _current_room
	if _chat_target != "":
		var target := _member_by_name(_current_room, _chat_target)
		if target.is_empty():
			_room_system_msg(_current_room, "%s không còn trong phòng." % _esc(_chat_target))
			_set_chat_target("")
			return
		# Chat mật: chỉ mình và người nhận thấy
		_room_chat(_current_room, "[color=#ff8fd8][Mật] Bạn → [/color]%s[color=#ff8fd8]: %s[/color]" % [_name_link(_chat_target, "#ffb0e6"), _esc(text)])
		ChatBox.push_private(_my_name(), _chat_target, text)   ## lưu cả ở khung chat chính (kênh Riêng)
		if bool(target.get("is_bot", false)) and randf() < 0.7 and is_inside_tree():
			var who := _chat_target
			get_tree().create_timer(randf_range(0.8, 1.8)).timeout.connect(func() -> void:
				if is_instance_valid(self) and _in_waiting_room and is_same(_current_room, room_ref):
					var reply: String = BOT_CHAT_LINES.pick_random()
					_room_chat(room_ref, "[color=#ff8fd8][Mật] [/color]%s[color=#ff8fd8] → Bạn: %s[/color]" % [_name_link(who, "#ffb0e6"), reply])
					ChatBox.push_private(who, _my_name(), reply))
	else:
		_room_chat(_current_room, "%s: %s" % [_name_link(_my_name(), "#5ccfff"), _esc(text)])
		# Phòng giả lập offline: đồng đội máy thỉnh thoảng đáp lời
		var bots: Array = _members(_current_room).filter(func(x: Dictionary) -> bool: return bool(x.get("is_bot", false)))
		if not bots.is_empty() and randf() < 0.5 and is_inside_tree():
			var bot: Dictionary = bots.pick_random()
			get_tree().create_timer(randf_range(0.8, 1.8)).timeout.connect(func() -> void:
				if not is_instance_valid(self) or not _in_waiting_room or not is_same(_current_room, room_ref):
					return
				_room_chat(room_ref, "%s: %s" % [_name_link(str(bot.get("name", "")), "#e8e0c8"), BOT_CHAT_LINES.pick_random()]))
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
	room["status"] = PubgManager.waiting_status(room, n)
	room["status_text"] = room["status"]

func _on_add_bot_member() -> void:
	var list := _members(_current_room)
	if list.size() >= int(_current_room.get("mode", 1)):
		return
	var b := _make_bot_member(list.map(func(x: Dictionary) -> String: return str(x.get("name", ""))))
	list.append(b)
	_sync_player_count(_current_room)
	_room_system_msg(_current_room, "%s đã vào phòng." % _name_link(str(b["name"]), "#c8d4d4"))
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
	_render_content()
	# Khi mọi người trong phòng đều đã sẵn sàng -> bắt đầu tìm trận
	if _is_ready and _all_ready(_current_room):
		if _leader_is_bot(_current_room) and is_inside_tree():
			var room_ref: Dictionary = _current_room
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				if is_instance_valid(self) and _in_waiting_room and is_same(_current_room, room_ref) and not _is_searching and _all_ready(room_ref):
					_room_system_msg(room_ref, "Chủ phòng bắt đầu tìm trận.")
					_start_matchmaking())
		else:
			_start_matchmaking()

func _leader_is_bot(room: Dictionary) -> bool:
	for m in _members(room):
		if bool(m.get("leader", false)):
			return bool(m.get("is_bot", false))
	return false

func _on_toggle_password() -> void:
	if str(_current_room.get("password", "")).strip_edges() != "":
		_current_room["password"] = ""
		_room_system_msg(_current_room, "Chủ phòng đã bỏ mật khẩu phòng.")
		_render_content()
		return
	SocialWindow.prompt(self, "Đặt Mật Khẩu Phòng", "Nhập mật khẩu (người vào bằng mã phải nhập đúng):", func(pass_val: String) -> void:
		var clean := pass_val.strip_edges()
		if clean == "" or not _in_waiting_room:
			return
		_current_room["password"] = clean
		_room_system_msg(_current_room, "Chủ phòng đã đặt mật khẩu phòng.")
		_render_content()
	, "", false)

func _on_toggle_fill() -> void:
	var on := not bool(_current_room.get("fill", false))
	_current_room["fill"] = on
	_room_system_msg(_current_room, "Chủ phòng đã %s tự ghép đội." % ("bật" if on else "tắt"))
	_render_content()

func _all_ready(room: Dictionary) -> bool:
	for m in _members(room):
		if not bool(m.get("ready", false)):
			return false
	return true

func _start_matchmaking() -> void:
	if not _check_open():
		return
	var incoming_count: int = maxi(1, _members(_current_room).size())
	var cur_rid: String = str(_current_room.get("id", ""))

	# 1. Kiểm tra ngay các phòng đang thi đấu có thời gian dưới 5 phút (< 300 giây)
	var backfill_room: Dictionary = PubgManager.find_joinable_active_match(incoming_count, cur_rid, _server_id())
	if not backfill_room.is_empty():
		_handle_backfill_match_found(backfill_room, incoming_count, cur_rid)
		return

	# 2. Vào hàng chờ: phòng chuyển "Đang Tìm Trận" (khóa không cho vào thêm), gom chung các đội cùng chế độ đang tìm
	var mode: int = clampi(int(_current_room.get("mode", 1)), 1, 4)
	var cap: int = PubgManager.match_capacity(mode)
	var queued := incoming_count
	for r in PubgManager.rooms:
		if not is_same(r, _current_room) and int(r.get("mode", 1)) == mode and str(r.get("status", "")) == PubgManager.STATUS_SEARCHING and PubgManager.same_server(r, _server_id()):
			queued += maxi(1, _members(r).size())
	_current_room["status"] = PubgManager.STATUS_SEARCHING
	_current_room["status_text"] = PubgManager.STATUS_SEARCHING
	_room_system_msg(_current_room, "Bắt đầu tìm trận (%d người)." % cap)
	_is_searching = true
	_search_time_left = PubgManager.MATCH_SEARCH_SEC
	_search_tick_accum = 0.0
	_matched_players_count = clampi(queued, 1, cap)
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
	# Solo không có phòng chờ: hủy tìm là quay về màn Vào Trận
	if bool(_current_room.get("quick", false)):
		_on_leave_waiting_room()
		return
	_stop_search()
	_room_system_msg(_current_room, "Đã hủy tìm trận.")
	_render_content()

## Thôi tìm trận: phòng trở lại phòng chờ (mở cho người khác vào), thành viên giữ nguyên trạng thái sẵn sàng.
func _stop_search() -> void:
	_is_searching = false
	_search_time_left = PubgManager.MATCH_SEARCH_SEC
	set_process(false)
	if not _current_room.is_empty() and str(_current_room.get("status", "")) == PubgManager.STATUS_SEARCHING:
		_current_room["status"] = ""  ## bỏ cờ đang tìm để waiting_status tính lại theo số người
		_current_room["status"] = PubgManager.waiting_status(_current_room, _members(_current_room).size())
		_current_room["status_text"] = _current_room["status"]

func _on_leave_waiting_room() -> void:
	_stop_search()
	_leave_room_data(_current_room)
	_is_ready = false
	_in_waiting_room = false
	_current_room = {}
	_current_room_id = ""
	_render_content()

## Rời 1 phòng: chủ phòng rời thì chuyển chủ phòng cho người thật kế tiếp (như các game lớn);
## không còn người thật nào thì giải tán phòng.
func _leave_room_data(room: Dictionary) -> void:
	if room.is_empty():
		return
	var rid: String = str(room.get("id", ""))
	var idx := _self_index(room)
	if idx < 0:
		return
	if str(room.get("status", "")) == PubgManager.STATUS_SEARCHING:
		room["status"] = ""
	var was_leader := bool(_members(room)[idx].get("leader", false))
	_members(room).remove_at(idx)
	_room_system_msg(room, "%s đã rời phòng." % _esc(_my_name()))
	if was_leader:
		var heir: Dictionary = {}
		for m in _members(room):
			if not bool(m.get("is_bot", false)):
				heir = m
				break
		if heir.is_empty():
			PubgManager.rooms.erase(room)
			return
		heir["leader"] = true
		heir["ready"] = true
		room["leader"] = heir["name"]
		room["host"] = heir["name"]
		_room_system_msg(room, "%s trở thành chủ phòng." % _esc(str(heir["name"])))
	_sync_player_count(room)
	print("[PUBG] Rời phòng %s, còn %d người." % [rid, _members(room).size()])

func _do_enter_match(room_data: Dictionary) -> void:
	_current_room_id = str(room_data.get("id", ""))
	room_data["players"] = _matched_players_count
	room_data["bot_count"] = 0 # Bỏ tự động thêm bot nếu hết 60s

	# Lưu trạng thái nhân vật thật trước khi vào phòng đấu sinh tồn PUBG
	if _profile != null and SaveManager:
		SaveManager.save_profile(_profile)
		await SaveManager.flush_online()

	# Tự ghép đội: chỗ trống trong đội được ghép người lạ (cùng máy chủ) trước khi vào trận
	var need := PubgManager.fill_slots(room_data, _members(room_data).size())
	for _i in range(need):
		var taken: Array = _members(room_data).map(func(x: Dictionary) -> String: return str(x.get("name", "")))
		var stranger := _make_bot_member(taken)
		stranger["stranger"] = true
		_members(room_data).append(stranger)
		_room_system_msg(room_data, "Tự ghép đội: %s vào đội." % _esc(str(stranger["name"])))
	if need > 0:
		_sync_player_count(room_data)

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

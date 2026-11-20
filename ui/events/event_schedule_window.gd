extends SocialWindow
class_name EventScheduleWindow
## Cửa sổ "Sự Kiện" (mở từ nút "Sự Kiện" ở Character Hub):
## Danh sách các sự kiện giang hồ, chiến trường, boss và hoạt động sắp diễn ra theo thời gian thực.
## Hiển thị đếm ngược thời gian, trạng thái (đang diễn ra, sắp diễn ra, lịch trình) và hỗ trợ tham gia nhanh.

signal event_action_requested(event_id: String)

const TABS := [
	"Tất Cả",
	"Chiến Trường & PvP",
	"Săn Boss Hoàng Kim",
	"Ải & Khiêu Chiến",
	"Bang Hội & Hoạt Động"
]

const EVENTS_DATA := [
	{
		"id": "battle",
		"title": "Chiến Trường Tống Kim",
		"type": "pvp",
		"category_name": "Chiến Trường",
		"icon_emoji": "⚔️",
		"level_req": "Cấp 40+",
		"times": ["11:00", "13:00", "15:00", "17:00", "19:00", "21:00", "23:00"],
		"duration_mins": 60,
		"location": "NPC Chiêu Mộ Tống Kim (Chu Tiên Trấn)",
		"rewards": "Điểm Tống Kim, Thuốc Chiến Trường, Ngân Lượng, Exp",
		"desc": "Đại chiến ngàn người giữa hai phe Đại Tống và Đại Kim. Tích lũy điểm tiêu diệt đổi trang bị và dược phẩm quý hiếm.",
		"action_type": "battle",
		"action_text": "Báo Danh",
	},
	{
		"id": "time_challenge",
		"title": "Thách Thức Thời Gian (Vượt Ải)",
		"type": "pve",
		"category_name": "Khiêu Chiến",
		"icon_emoji": "⏱️",
		"level_req": "Cấp 50+",
		"times": ["10:00", "14:00", "18:00", "22:00"],
		"duration_mins": 30,
		"location": "NPC Nhiếp Thí Trần",
		"rewards": "Sát Thủ Bí Bảo, Huyết Lệ Chi Thư, Trang Bị Cực Phẩm, Exp",
		"desc": "Khiêu chiến 28 ải thử thách trong thời gian quy định 30 phút. Đòi hỏi sự phối hợp tổ đội ăn ý và bản lĩnh sát thủ.",
		"action_type": "time_challenge",
		"action_text": "Khiêu Chiến",
	},
	{
		"id": "world_boss",
		"title": "Boss Hoàng Kim Đại Đầu Lĩnh",
		"type": "boss",
		"category_name": "Săn Boss",
		"icon_emoji": "🐉",
		"level_req": "Cấp 80+",
		"times": ["12:00", "19:30", "23:00"],
		"duration_mins": 45,
		"location": "Trường Bạch Sơn, Sa Mạc, Mạc Cao Quật, Lâm Du Quan...",
		"rewards": "Trang bị Hoàng Kim Môn Phái, Định Quốc, An Bang, Thủy Tinh, Tinh Hồng Bảo Thạch",
		"desc": "Thập Đại Boss Hoàng Kim xuất thế theo chuẩn VLTK gốc (12:00 trưa, 19:30 tối, 23:00 đêm): Lam Y Y, Huyền Giác Đại Sư, Cổ Bách, Hà Nhân Ngã, Đường Bất Nhiễm...",
		"action_type": "world_boss",
		"action_text": "Săn Boss",
	},
	{
		"id": "small_boss",
		"title": "Tiểu Hoàng Kim Boss (Dã Ngoại)",
		"type": "boss",
		"category_name": "Tiểu Boss",
		"icon_emoji": "👹",
		"level_req": "Cấp 60+",
		"times": ["09:10", "17:10", "21:10", "23:10"],
		"duration_mins": 35,
		"location": "Thành Đô, Đại Lý Phủ, Trường Giang Đầu Nguồn...",
		"rewards": "Thủy Tinh (Lam/Tử/Lục), Tinh Hồng Bảo Thạch, Tiên Thảo Lộ, Bí Kíp Môn Phái",
		"desc": "Thủ lĩnh tà phái dã ngoại theo chuẩn bosstieuhk (09:10, 17:10, 21:10, 23:10): Liễu Thanh Thanh, Diệu Như, Trương Tông Chính...",
		"action_type": "world_boss",
		"action_text": "Săn Boss",
	},
	{
		"id": "huashan",
		"title": "Hoa Sơn Luận Kiếm (Đấu Trường)",
		"type": "pvp",
		"category_name": "Võ Đài",
		"icon_emoji": "🏆",
		"level_req": "Cấp 60+",
		"times": ["20:00"],
		"duration_mins": 60,
		"location": "Đỉnh Hoa Sơn",
		"rewards": "Danh hiệu Đệ Nhất Cao Thủ, Điểm Vinh Dự, Rương Thần Bí",
		"desc": "Đại hội tỷ võ quy tụ các cao thủ 15 đại môn phái tranh tài đệ nhất thiên hạ theo thể thức 1v1 hoặc liên đấu môn phái.",
		"action_type": "pk_arena",
		"action_text": "Đấu Trường",
	},
	{
		"id": "ferry",
		"title": "Bến Thuyền Phong Lăng Độ",
		"type": "pve",
		"category_name": "Vượt Sông",
		"icon_emoji": "🚢",
		"level_req": "Cấp 50+",
		"times": ["00:00", "02:00", "04:00", "06:00", "08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00", "22:00"],
		"duration_mins": 30,
		"location": "Bến Thuyền Phong Lăng Độ (Gặp Thuyền Phu)",
		"rewards": "Thủy Tinh, Huyền Tinh Khoáng Thạch, Lượng, Exp",
		"desc": "Vượt Hoàng Hà sang bờ Bắc. Trên thuyền tiêu diệt thủy tặc và thủ lĩnh Viễn Độ Đầu Lĩnh để đoạt bảo rương.",
		"action_type": "ferry",
		"action_text": "Lên Thuyền",
	},
	{
		"id": "siege",
		"title": "Công Thành Chiến (Thất Đại Thành Thị)",
		"type": "bang",
		"category_name": "Bang Hội",
		"icon_emoji": "🏯",
		"level_req": "Cấp 60+ (Đã vào Bang)",
		"times": ["20:30"],
		"duration_mins": 90,
		"location": "Biện Kinh, Phượng Tường, Tương Dương, Lâm An",
		"rewards": "Quyền Thành Chủ, Thuế Suất Thành Thị, Danh Hiệu Bang Hội",
		"desc": "Cuộc chiến tranh đoạt lãnh địa khốc liệt giữa các bang hội. Chiếm Long Trụ và giữ thành đến giây phút cuối cùng.",
		"action_type": "siege",
		"action_text": "Công Thành",
	},
	{
		"id": "escort",
		"title": "Vận Tiêu Bang Hội & Cá Nhân",
		"type": "bang",
		"category_name": "Tiêu Cục",
		"icon_emoji": "📦",
		"level_req": "Cấp 30+",
		"times": ["12:00", "18:00"],
		"duration_mins": 120,
		"location": "Long Môn Tiêu Cục (Ba Lăng Huyện)",
		"rewards": "Ngân Lượng dồi dào, Điểm Cống Hiến Bang, Thẻ Đổi Tiêu",
		"desc": "Nhận tiêu xa vận chuyển qua các vùng hiểm trở về đích an toàn, đề phòng đạo tặc và người chơi khác cướp tiêu (Chỉ mở vào Thứ Bảy & Chủ Nhật hàng tuần).",
		"action_type": "escort",
		"action_text": "Vận Tiêu",
	},
	{
		"id": "hoa_dang",
		"title": "Hội Hoa Đăng (Đoán Câu Đố)",
		"type": "daily",
		"category_name": "Hoa Đăng",
		"icon_emoji": "🏮",
		"level_req": "Cấp 20+",
		"times": ["12:15", "21:15"],
		"duration_mins": 30,
		"location": "Bờ sông các Thôn Trấn & Thành Thị",
		"rewards": "Kinh Nghiệm cực cao, Điểm Phúc Duyên, Danh Vọng, Thủy Tinh",
		"desc": "Tham gia thắp sáng hoa đăng và giải các câu đố văn hóa kiếm hiệp, lịch sử giang hồ. Mỗi câu trả lời đúng nhận lượng lớn kinh nghiệm và điểm phúc duyên.",
		"action_type": "hoa_dang",
		"action_text": "Hoa Đăng",
	},
	{
		"id": "huy_hoang",
		"title": "Quả Huy Hoàng & Hạt Huy Hoàng",
		"type": "daily",
		"category_name": "Huy Hoàng",
		"icon_emoji": "🌟",
		"level_req": "Cấp 40+",
		"times": ["12:00", "20:00"],
		"duration_mins": 30,
		"location": "Các bản đồ dã ngoại (Cổ Dương Động, Lâm Du Quan...)",
		"rewards": "Hàng triệu EXP, Điểm Phúc Duyên, Ngân Lượng, Rương Huy Hoàng",
		"desc": "Hạt mầm Huy Hoàng nảy mầm kết trái. Hái quả thưởng thức giúp bồi tăng công lực, khai thông kinh mạch thần tốc.",
		"action_type": "huy_hoang",
		"action_text": "Hái Quả",
	},
	{
		"id": "bat_nha",
		"title": "Trồng Cây Bát Nhã",
		"type": "daily",
		"category_name": "Bát Nhã",
		"icon_emoji": "🌱",
		"level_req": "Cấp 30+",
		"times": ["all_day"],
		"duration_mins": 60,
		"location": "Linh thổ Bát Nhã ngoại thành",
		"rewards": "Kinh Nghiệm khổng lồ, Ngân Lượng, Huyền Tinh, Thủy Tinh",
		"desc": "Gieo trồng hạt giống Bát Nhã Ba La Mật. Cây tự sinh trưởng theo thời gian thực (AFK), kết trái thu hoạch linh dược quý giá.",
		"action_type": "bat_nha",
		"action_text": "Trồng Cây",
	},
	{
		"id": "viem_de",
		"title": "Viêm Đế Bảo Tàng",
		"type": "pve",
		"category_name": "Viêm Đế",
		"icon_emoji": "🏛️",
		"level_req": "Cấp 50+",
		"times": ["all_day"],
		"duration_mins": 30,
		"location": "Kho Báu Viêm Đế",
		"rewards": "Rương Viêm Đế Bí Bảo, Thủy Tinh, Mảnh Đồ Đằng, 20.000.000 EXP",
		"desc": "Chiến trường Viêm Đế Bảo Tàng thực địa nguyên bản VLTK: 3 lộ trình tiến công, vượt 10 ải môn phái, đoạt Đồ Đằng và tiêu diệt Boss Lương Mi Nhi.",
		"action_type": "viem_de",
		"action_text": "Bảo Tàng",
	},
]

var _profile: PlayerProfile
var _on_play: Callable
var _tab := 0
var _tab_buttons: Array[Button] = []
var _clock_label: Label
var _summary_label: Label
var _list_container: VBoxContainer
var _timer: Timer
var _card_badge_map: Dictionary = {}

static func open(host: Node, profile: PlayerProfile = null, on_play: Callable = Callable()) -> EventScheduleWindow:
	var win := EventScheduleWindow.new(profile, on_play)
	return SocialWindow.present(host, win, &"events") as EventScheduleWindow

func _init(profile: PlayerProfile = null, on_play: Callable = Callable()) -> void:
	super._init(tr("Sự Kiện Võ Lâm"), "", 1000.0)
	_profile = profile
	_on_play = on_play

	# Hàng đồng hồ thời gian & tóm tắt
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 16)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_clock_label = SocialUi.label("⏰ " + tr("Giờ hệ thống:") + " --:--:--", GameUi.GOLD, 14)
	top_bar.add_child(_clock_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_summary_label = SocialUi.label(tr("Đang diễn ra:") + " 0 · " + tr("Sắp diễn ra:") + " 0", GameUi.LABEL_GREEN, 13, HORIZONTAL_ALIGNMENT_RIGHT)
	top_bar.add_child(_summary_label)

	body.add_child(top_bar)
	body.add_child(SocialUi.divider())

	# Hàng nút tab lọc
	var tabs_box := HBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 8)
	tabs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in TABS.size():
		var b := GameUi.button(tr(TABS[i]), GameUi.TAB)
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tab.bind(i))
		tabs_box.add_child(b)
		_tab_buttons.append(b)
	body.add_child(tabs_box)

	# Vùng danh sách sự kiện cuộn được
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(1, 440.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 8)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.custom_minimum_size.x = 1
	scroll.add_child(_list_container)

	# Timer đếm nhịp mỗi giây
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

	_select_tab(0)

func _ready() -> void:
	super._ready()
	refresh()

func refresh() -> void:
	_update_clock()
	_rebuild_list()

func _on_tick() -> void:
	_update_clock()
	_update_card_timings()

func _update_clock() -> void:
	var dt := Time.get_time_dict_from_system()
	if _clock_label:
		_clock_label.text = "⏰ " + tr("Giờ hệ thống:") + " %02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]

func _select_tab(idx: int) -> void:
	_tab = idx
	for i in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[i], i == idx)
	_rebuild_list()

func _matches_tab(event: Dictionary, tab_idx: int) -> bool:
	match tab_idx:
		0:
			return true
		1:
			return event["type"] == "pvp"
		2:
			return event["type"] == "boss"
		3:
			return event["type"] == "pve"
		4:
			return event["type"] in ["bang", "daily"]
	return true

func _rebuild_list() -> void:
	for c in _list_container.get_children():
		c.queue_free()
	_card_badge_map.clear()

	var dt := Time.get_time_dict_from_system()
	var sorted_events: Array = []
	var ongoing_count := 0
	var upcoming_count := 0

	for ev in EVENTS_DATA:
		var timing := _compute_timing(ev, dt)
		if timing.status == "ongoing":
			ongoing_count += 1
		elif timing.status == "upcoming":
			upcoming_count += 1
		if _matches_tab(ev, _tab):
			sorted_events.append({"event": ev, "timing": timing})

	if _summary_label:
		_summary_label.text = "🟢 " + tr("Đang diễn ra:") + " %d  ·  🟡 " + tr("Sắp diễn ra:") + " %d" % [ongoing_count, upcoming_count]

	# Sắp xếp theo mức độ ưu tiên thời gian (đang diễn ra -> sắp diễn ra -> sau này -> mở cả ngày)
	sorted_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.timing.urgency_score) < int(b.timing.urgency_score)
	)

	if sorted_events.is_empty():
		var empty_lbl := SocialUi.label("Không có sự kiện nào trong danh mục này.", SocialUi.MUTED, 14, HORIZONTAL_ALIGNMENT_CENTER)
		empty_lbl.custom_minimum_size.y = 100
		_list_container.add_child(empty_lbl)
		return

	for item in sorted_events:
		var card := _build_event_card(item.event, item.timing)
		_list_container.add_child(card)

func _compute_timing(event: Dictionary, dt: Dictionary) -> Dictionary:
	var times: Array = event.get("times", [])
	if "all_day" in times:
		return {
			"status": "all_day",
			"status_text": "Mở Cả Ngày",
			"status_color": GameUi.LABEL_GREEN,
			"urgency_score": 90000,
			"diff_sec": 0
		}

	var now_sec: int = int(dt.hour) * 3600 + int(dt.minute) * 60 + int(dt.second)
	var duration_sec: int = int(event.get("duration_mins", 30)) * 60

	# Kiểm tra xem có khung giờ nào đang diễn ra không
	for t_str in times:
		var parts := str(t_str).split(":")
		if parts.size() < 2:
			continue
		var start_sec := int(parts[0]) * 3600 + int(parts[1]) * 60
		var end_sec := start_sec + duration_sec
		if now_sec >= start_sec and now_sec < end_sec:
			var remaining := end_sec - now_sec
			return {
				"status": "ongoing",
				"status_text": "Đang diễn ra (còn %s)" % _format_minutes_seconds(remaining),
				"status_color": Color(0.25, 0.95, 0.45),
				"urgency_score": 0,
				"diff_sec": remaining
			}

	# Nếu không diễn ra, tìm mốc sắp tới gần nhất
	var min_diff := 999999
	var next_slot := ""
	for t_str in times:
		var parts := str(t_str).split(":")
		if parts.size() < 2:
			continue
		var start_sec := int(parts[0]) * 3600 + int(parts[1]) * 60
		var diff := 0
		if start_sec > now_sec:
			diff = start_sec - now_sec
		else:
			diff = (86400 - now_sec) + start_sec # Ngày mai
		if diff < min_diff:
			min_diff = diff
			next_slot = str(t_str)

	if min_diff <= 1800: # Trong vòng 30 phút
		return {
			"status": "upcoming",
			"status_text": "Sắp diễn ra lúc %s (còn %s)" % [next_slot, _format_minutes_seconds(min_diff)],
			"status_color": Color(1.0, 0.82, 0.25),
			"urgency_score": min_diff,
			"diff_sec": min_diff
		}

	return {
		"status": "later",
		"status_text": "Lượt tới: %s (sau %s)" % [next_slot, _format_hours_minutes(min_diff)],
		"status_color": Color(0.75, 0.75, 0.72),
		"urgency_score": min_diff,
		"diff_sec": min_diff
	}

func _format_minutes_seconds(seconds: int) -> String:
	var m := seconds / 60
	var s := seconds % 60
	if m >= 60:
		var h := m / 60
		m = m % 60
		return "%d giờ %02d phút" % [h, m]
	return "%02d:%02d" % [m, s]

func _format_hours_minutes(seconds: int) -> String:
	var m := seconds / 60
	var h := m / 60
	m = m % 60
	if h > 0:
		return "%d giờ %02d phút" % [h, m]
	return "%d phút" % m

func _build_event_card(event: Dictionary, timing: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := WuxiaStyle.create_inner_card(8)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 14)
	card.add_child(main_row)

	# Cột trái: Emoji / Biểu tượng & Nhãn loại
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size.x = 90
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_child(left_col)

	var icon_lbl := SocialUi.label(event.get("icon_emoji", "⚔️"), GameUi.TITLE, 30, HORIZONTAL_ALIGNMENT_CENTER)
	left_col.add_child(icon_lbl)

	var type_box := PanelContainer.new()
	var t_style := StyleBoxFlat.new()
	t_style.set_corner_radius_all(4)
	t_style.set_content_margin_all(3)
	t_style.border_width_left = 1
	t_style.border_width_top = 1
	t_style.border_width_right = 1
	t_style.border_width_bottom = 1

	var category_color := _category_color(str(event.get("type", "")))
	t_style.bg_color = Color(category_color.r * 0.25, category_color.g * 0.25, category_color.b * 0.25, 0.9)
	t_style.border_color = category_color
	type_box.add_theme_stylebox_override("panel", t_style)

	var type_lbl := SocialUi.label(str(event.get("category_name", "Hoạt Động")), category_color, 11, HORIZONTAL_ALIGNMENT_CENTER)
	type_box.add_child(type_lbl)
	left_col.add_child(type_box)

	# Cột giữa: Thông tin sự kiện
	var mid_col := VBoxContainer.new()
	mid_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_col.custom_minimum_size.x = 1
	mid_col.add_theme_constant_override("separation", 4)
	main_row.add_child(mid_col)

	# Hàng 1: Tên sự kiện & Yêu cầu cấp
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	mid_col.add_child(title_row)

	var title_lbl := SocialUi.label(str(event.get("title", "")), GameUi.TITLE, 16)
	title_row.add_child(title_lbl)

	var lvl_lbl := SocialUi.label("[%s]" % str(event.get("level_req", "")), Color(0.9, 0.6, 0.3), 12)
	title_row.add_child(lvl_lbl)

	# Hàng 2: Khung giờ & Địa điểm
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 14)
	mid_col.add_child(meta_row)

	var times_arr: Array = event.get("times", [])
	var times_text: String = ""
	if "all_day" in times_arr:
		times_text = "Mở cả ngày"
	elif times_arr.size() > 6:
		times_text = "Mỗi 2 giờ chẵn (" + ", ".join(times_arr.slice(0, 4)) + " ... " + str(times_arr[-1]) + ")"
	else:
		times_text = ", ".join(times_arr)

	var time_lbl := SocialUi.label("⏰ " + tr("Lịch:") + " %s" % times_text, GameUi.GOLD, 12)
	time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	time_lbl.custom_minimum_size.x = 1
	meta_row.add_child(time_lbl)

	var loc_lbl := SocialUi.label("📍 " + tr("Vị trí:") + " %s" % str(event.get("location", "")), SocialUi.SUBTITLE, 12)
	loc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loc_lbl.custom_minimum_size.x = 1
	meta_row.add_child(loc_lbl)

	# Hàng 3: Mô tả
	var desc_lbl := SocialUi.label(str(event.get("desc", "")), SocialUi.TEXT, 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size.x = 1
	mid_col.add_child(desc_lbl)

	# Hàng 4: Phần thưởng
	var rew_row := HBoxContainer.new()
	rew_row.add_theme_constant_override("separation", 6)
	mid_col.add_child(rew_row)

	var rew_tag := SocialUi.label("🎁 " + tr("Thưởng:"), Color(0.95, 0.78, 0.35), 12)
	rew_row.add_child(rew_tag)

	var rew_val := SocialUi.label(str(event.get("rewards", "")), Color(0.72, 0.90, 0.85), 12)
	rew_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rew_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rew_val.custom_minimum_size.x = 1
	rew_row.add_child(rew_val)

	# Cột phải: Trạng thái đếm ngược & Nút hành động
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size.x = 180
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.add_theme_constant_override("separation", 8)
	main_row.add_child(right_col)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(170, 32)
	var s_box := StyleBoxFlat.new()
	s_box.set_corner_radius_all(6)
	s_box.set_content_margin_all(6)
	s_box.border_width_left = 1
	s_box.border_width_top = 1
	s_box.border_width_right = 1
	s_box.border_width_bottom = 1
	s_box.bg_color = Color(0.04, 0.06, 0.06, 0.95)
	s_box.border_color = timing.status_color
	status_panel.add_theme_stylebox_override("panel", s_box)

	var status_lbl := SocialUi.label(timing.status_text, timing.status_color, 12, HORIZONTAL_ALIGNMENT_CENTER)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_lbl.custom_minimum_size.x = 1
	status_panel.add_child(status_lbl)
	right_col.add_child(status_panel)

	# Lưu lại badge để tick đếm ngược
	_card_badge_map[event.id] = {
		"panel": status_panel,
		"label": status_lbl,
		"event": event
	}

	var action_btn := GameUi.button(tr(str(event.get("action_text", "Chi Tiết"))), GameUi.PRIMARY)
	action_btn.custom_minimum_size = Vector2(170, 34)
	action_btn.pressed.connect(_on_card_action.bind(event))
	right_col.add_child(action_btn)

	return card

func _category_color(type: String) -> Color:
	match type:
		"pvp":
			return Color(0.95, 0.35, 0.30) # Đỏ cam
		"boss":
			return Color(0.95, 0.75, 0.20) # Vàng cam
		"pve":
			return Color(0.35, 0.75, 0.95) # Xanh lam
		"bang":
			return Color(0.35, 0.90, 0.55) # Xanh ngọc
		"daily":
			return Color(0.85, 0.60, 0.95) # Tím nhạt
	return GameUi.GOLD

func _update_card_timings() -> void:
	var dt := Time.get_time_dict_from_system()
	var status_changed := false

	for ev_id in _card_badge_map:
		var item: Dictionary = _card_badge_map[ev_id]
		var ev: Dictionary = item.event
		var timing := _compute_timing(ev, dt)
		var lbl: Label = item.label
		var panel: PanelContainer = item.panel

		if lbl and is_instance_valid(lbl):
			lbl.text = timing.status_text
			lbl.add_theme_color_override("font_color", timing.status_color)
		if panel and is_instance_valid(panel):
			var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
			if sb:
				sb.border_color = timing.status_color

	# Cập nhật số lượng tổng kết
	var ongoing_count := 0
	var upcoming_count := 0
	for ev in EVENTS_DATA:
		var t := _compute_timing(ev, dt)
		if t.status == "ongoing":
			ongoing_count += 1
		elif t.status == "upcoming":
			upcoming_count += 1
	if _summary_label:
		_summary_label.text = "🟢 Đang diễn ra: %d  ·  🟡 Sắp diễn ra: %d" % [ongoing_count, upcoming_count]

func _on_card_action(event: Dictionary) -> void:
	var action_type := str(event.get("action_type", "detail"))
	match action_type:
		"battle", "time_challenge", "pk_arena", "world_boss", "ferry", "siege", "escort", "hoa_dang", "huy_hoang", "bat_nha", "viem_de":
			event_action_requested.emit(action_type)
		_:
			_show_detail_popup(event)

func _show_detail_popup(event: Dictionary) -> void:
	var win := SocialWindow.new(str(event.get("title", "")), "Chi tiết hoạt động & hướng dẫn tham gia", 520.0)
	
	var times_arr: Array = event.get("times", [])
	var times_text: String = "Mở cả ngày" if "all_day" in times_arr else (", ".join(times_arr))
	
	win.body.add_child(SocialUi.kv("⏰ Khung giờ:", times_text, GameUi.GOLD))
	win.body.add_child(SocialUi.kv("📍 Địa điểm:", str(event.get("location", "")), SocialUi.SUBTITLE))
	win.body.add_child(SocialUi.kv("🎯 Yêu cầu:", str(event.get("level_req", "")), Color(0.9, 0.6, 0.3)))
	win.body.add_child(SocialUi.divider())
	
	var desc_sec := SocialUi.section("Quy Tắc & Nội Dung")
	var desc_box: VBoxContainer = desc_sec[1]
	var desc_lbl := SocialUi.label(str(event.get("desc", "")), SocialUi.TEXT, 13)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_box.add_child(desc_lbl)
	win.body.add_child(desc_sec[0])
	
	var rew_sec := SocialUi.info_box("Phần Thưởng Giá Trị")
	var rew_box: VBoxContainer = rew_sec[1]
	var rew_lbl := SocialUi.label(str(event.get("rewards", "")), Color(0.75, 0.95, 0.85), 13)
	rew_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rew_box.add_child(rew_lbl)
	win.body.add_child(rew_sec[0])
	
	var btn_row := win.add_button_row()
	var act_type := str(event.get("action_type", ""))
	if act_type in ["battle", "time_challenge", "pk_arena", "world_boss", "ferry", "siege", "escort", "hoa_dang", "huy_hoang", "bat_nha", "viem_de"]:
		var act_btn := SocialUi.stone_button(str(event.get("action_text", "Tham Gia")))
		act_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act_btn.pressed.connect(func() -> void:
			win.close_requested.emit()
			event_action_requested.emit(act_type)
		)
		btn_row.add_child(act_btn)

	var close_btn := SocialUi.stone_button("Đóng")
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void: win.close_requested.emit())
	btn_row.add_child(close_btn)
	
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var host := tree.current_scene if tree != null else null
	if host != null:
		SocialWindow.present(host, win, &"event_detail")

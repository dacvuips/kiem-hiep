extends SocialWindow
class_name ViemDeWindow

const ViemDeLobby = preload("res://systems/challenge/viem_de_lobby.gd")
## VIÊM ĐẾ BẢO TÀNG (Kho Báu Viêm Đế — Thực Địa Map 853 Chuẩn VLTK Gốc):
##   - Bản đồ lớn Map 853 "Kho Báu Viêm Đế" (\maps\特殊用地\炎帝宝藏).
##   - 3 Lộ trình tiến công: Đường A (Chính Đạo), Đường B (Trung Lập), Đường C (Tà Phái).
##   - 10 Ải môn phái trấn giữ: Thiên Vương, Thiếu Lâm, Ngũ Độc, Đường Môn, Nga My, Thúy Yên, Thiên Nhẫn, Cái Bang, Võ Đang, Côn Lôn.
##   - Hạch Tâm Bảo Tàng: Đại Boss Lương Mi Nhi (Cấp 95) & Đồ Đằng Viêm Đế.
##   - Chế độ Tổ Đội: Tạo phòng chờ bên ngoài giống các vòng PK, mọi người sẵn sàng hết mới vào chơi.
##   - Tính năng đổi thưởng: Mở Rương Bí Bảo, Ghép Đồ Đằng Viêm Đế, Trang Bị Hoàng Kim Viêm Đế (Toái Nhâm, Phục Hi, Nữ Oa, Chúc Dung, Thần Nông).

const RECORD_PATH := "user://viem_de_records.json"
const RUNS_PER_DAY := 4 ## Chuẩn YDBZ_LIMIT_DAY_COUNT = 4 lượt/ngày trong head.lua

const FLOORS := [
	{"floor": 1, "name": "Ải 1: Thiên Vương Bang", "min_level": 50, "boss_name": "Cổ Thiên Khuyết", "reward_exp": 600000, "reward_gold": 80000, "chest_name": "Rương Viêm Đế Sơ Cấp", "color": Color(0.95, 0.75, 0.25)},
	{"floor": 2, "name": "Ải 2: Thiếu Lâm Tự", "min_level": 60, "boss_name": "Chứng Ngôn", "reward_exp": 600000, "reward_gold": 100000, "chest_name": "Rương Viêm Đế Bí Bảo", "color": Color(0.95, 0.8, 0.3)},
	{"floor": 3, "name": "Ải 3: Ngũ Độc Giáo", "min_level": 70, "boss_name": "Chiếu Nhật Miện", "reward_exp": 600000, "reward_gold": 120000, "chest_name": "Rương Viêm Đế Bí Bảo", "color": Color(0.4, 0.9, 0.5)},
	{"floor": 4, "name": "Ải 4: Đường Môn Gia Gia", "min_level": 75, "boss_name": "Đường Hạo", "reward_exp": 600000, "reward_gold": 150000, "chest_name": "Rương Viêm Đế Bí Bảo", "color": Color(0.4, 0.85, 0.95)},
	{"floor": 5, "name": "Ải 5: Nga My Phái", "min_level": 80, "boss_name": "Diệu Nhất", "reward_exp": 600000, "reward_gold": 180000, "chest_name": "Rương Viêm Đế Bí Bảo", "color": Color(0.85, 0.65, 1.0)},
	{"floor": 6, "name": "Ải 6: Thúy Yên Môn", "min_level": 85, "boss_name": "Lệ Chiết Mai", "reward_exp": 600000, "reward_gold": 200000, "chest_name": "Rương Viêm Đế Bí Bảo", "color": Color(0.5, 0.8, 1.0)},
	{"floor": 7, "name": "Ải 7: Thiên Nhẫn Giáo", "min_level": 88, "boss_name": "Đoan Mộc Li", "reward_exp": 600000, "reward_gold": 220000, "chest_name": "Rương Viêm Đế Bí Bảo", "color": Color(1.0, 0.45, 0.35)},
	{"floor": 8, "name": "Ải 8: Cái Bang Phái", "min_level": 90, "boss_name": "Bạch Lang", "reward_exp": 600000, "reward_gold": 250000, "chest_name": "Rương Viêm Đế Bí Bảo", "color": Color(0.9, 0.55, 0.25)},
	{"floor": 9, "name": "Ải 9: Võ Đang Phái", "min_level": 92, "boss_name": "Tần Hiểu Thư", "reward_exp": 600000, "reward_gold": 280000, "chest_name": "Rương Viêm Đế Bí Bảo", "color": Color(0.3, 0.75, 1.0)},
	{"floor": 10, "name": "Ải 10: Côn Lôn Phái", "min_level": 95, "boss_name": "Lăng Tiêu Tử", "reward_exp": 600000, "reward_gold": 300000, "chest_name": "Rương Viêm Đế Bí Bảo", "color": Color(0.9, 0.85, 0.4)},
	{"floor": 11, "name": "Hạch Tâm: Lương Mi Nhi", "min_level": 95, "boss_name": "Lương Mi Nhi", "reward_exp": 20000000, "reward_gold": 1500000, "chest_name": "Rương Viêm Đế Chí Bảo", "color": Color(1.0, 0.85, 0.2)}
]

const GOLD_SETS := [
	{"name": "Bộ Toái Nhâm (Hệ Kim)", "gold_indices": [441, 442, 444, 445], "items": ["Toái Nhâm Xích Huyết Nguyên Vũ Giáp", "Toái Nhâm Bách Luyện Khôi", "Toái Nhâm Trục Thiên Ngoa", "Toái Nhâm Kim Lệ Nhụy Vi Hộ Uyển"], "color": Color(1.0, 0.85, 0.25)},
	{"name": "Bộ Phục Hi (Hệ Mộc)", "gold_indices": [454, 455, 456], "items": ["Phục Hi Hoan Ảnh Kích", "Phục Hi Vô Lượng Tĩnh Tế Thủ", "Phục Hi Toái Tâm"], "color": Color(0.35, 0.9, 0.45)},
	{"name": "Bộ Nữ Oa (Hệ Thủy)", "gold_indices": [462, 463, 466], "items": ["Nữ Oa Hồng Nhan Phát Đới", "Nữ Oa Lục Nghệ Nghê Thường Thượng Đới", "Nữ Oa Hạo Tông"], "color": Color(0.35, 0.8, 1.0)},
	{"name": "Bộ Chúc Dung (Hệ Hỏa)", "gold_indices": [471, 475, 476], "items": ["Chúc Dung Liệt Diễm Nộ Phong Trang", "Chúc Dung Kinh Chính Bát Diễm Trảo", "Chúc Dung Phụ Nhật"], "color": Color(1.0, 0.4, 0.35)},
	{"name": "Bộ Thần Nông (Hệ Thổ)", "gold_indices": [481, 482, 484, 486], "items": ["Thần Nông Tiêu Dao Hóa Hoàng Y", "Thần Nông Nữ Lạc Hộ Hoàn", "Thần Nông Ngự Phong Lữ", "Thần Nông Trầm Nhạc"], "color": Color(0.95, 0.75, 0.3)}
]

var _profile: PlayerProfile
var _on_enter_field: Callable
var _scroll: ScrollContainer
var _content_box: VBoxContainer
var _footer_box: HBoxContainer
var _tab := 0

var _selected_route := "a"
var _use_viem_de_lenh := false
var _party_mode := false
var _current_room_id := ""

static func open(host: Node, profile: PlayerProfile, on_enter_field: Callable = Callable(), initial_tab: int = 0) -> SocialWindow:
	var script: GDScript = load("res://ui/events/viem_de_window.gd")
	var win: SocialWindow = script.new(profile, on_enter_field, initial_tab)
	return SocialWindow.present(host, win, &"viem_de")

## Mở nhanh cửa sổ Đổi Thưởng & Ghép Đồ Đằng tại bất kỳ đâu mà không cần gặp NPC
static func open_reward_shop(host: Node, profile: PlayerProfile) -> SocialWindow:
	return open(host, profile, Callable(), 1)

## Ghép nhanh 1 Đồ Đằng từ 9 Mảnh Đồ Đằng bất kỳ lúc nào (dùng cho nút thao tác trong túi đồ)
static func craft_totem_quick(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {"success": false, "message": "Không tìm thấy hồ sơ nhân vật!"}
	var rec := _get_records_for(profile)
	var inv_frags := 0
	for it in profile.inventory:
		if it != null and it.misc_id == "6_1_1685":
			inv_frags += maxi(it.count, 1)
	var rec_frags: int = int(rec.get("totem_fragments", 0))
	var total_frags := maxi(rec_frags, inv_frags)
	if total_frags < 9:
		return {"success": false, "message": "Cần tối thiểu 9 Mảnh Đồ Đằng Viêm Đế để ghép! Hiện có: %d/9 mảnh." % total_frags}

	var totem_it: ItemInstance = ItemGenerator.generate_misc("6_1_1606")
	if totem_it == null or not profile.add_item(totem_it):
		return {"success": false, "message": "Hành trang của đại hiệp đã đầy! Hãy dọn bớt ô trống để nhận Viêm Đế Đồ Đằng."}

	var consumed := 0
	var i := 0
	while i < profile.inventory.size() and consumed < 9:
		var it: ItemInstance = profile.inventory[i]
		if it != null and it.misc_id == "6_1_1685":
			var need := 9 - consumed
			if it.count > need:
				it.count -= need
				consumed += need
				i += 1
			else:
				consumed += maxi(it.count, 1)
				profile.inventory.remove_at(i)
		else:
			i += 1

	rec["totem_fragments"] = maxi(0, total_frags - 9)
	rec["totems"] = int(rec.get("totems", 0)) + 1
	_save_records_for(rec, profile)
	SaveManager.save_profile(profile)
	SaveManager.flush_online()
	return {"success": true, "message": "Ghép thành công 1 Viêm Đế Đồ Đằng! Đã thêm vào hành trang."}

func _init(profile: PlayerProfile = null, on_enter_field: Callable = Callable(), initial_tab: int = 0) -> void:
	super._init("Viêm Đế Bảo Tàng (Kho Báu Viêm Đế)", "", 740.0)
	_profile = profile
	_on_enter_field = on_enter_field
	_tab = initial_tab

	# Kiểm tra xem người chơi đã có phòng sẵn chưa
	var own_r := ViemDeLobby.find_own(_profile)
	if not own_r.is_empty():
		_current_room_id = str(own_r.get("id", ""))
		_party_mode = true

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

	_footer_box = HBoxContainer.new()
	_footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer_box.add_theme_constant_override("separation", 12)
	body.add_child(_footer_box)

	_render()

func _render() -> void:
	for c in _content_box.get_children():
		c.queue_free()
	for c in _footer_box.get_children():
		c.queue_free()

	if _tab == 0:
		_footer_box.visible = false
		_render_challenge_tab()
	else:
		_footer_box.visible = false
		_render_reward_tab()

# ---------------------------------------------------------------- TAB 0: KHIÊU CHIẾN THỰC ĐỊA
func _render_challenge_tab() -> void:
	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var runs_today: int = int(rec.get("runs", {}).get(today, 0))

	# Header Panel
	var header := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(header)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	header.add_child(hb)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(title_row)

	var title_lbl := SocialUi.label("Chiến Trường Cổ Mộ Viêm Đế", SocialUi.TITLE, 17)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title_lbl)

	var btn_reward := SocialUi.stone_button("🎁 Đổi Thưởng & Ghép Đồ Đằng", Vector2(230, 34))
	btn_reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_reward.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	btn_reward.pressed.connect(func() -> void:
		_tab = 1
		_render()
		if _scroll != null:
			_scroll.scroll_vertical = 0
	)
	title_row.add_child(btn_reward)

	var desc := SocialUi.label("Bản đồ Kho Báu Viêm Đế nguyên bản VLTK gồm 3 lộ trình tiến công, vượt 10 ải môn phái trấn giữ. Đích đến cuối cùng là Hạch Tâm Bảo Tàng gặp Đại Boss Lương Mi Nhi và Đồ Đằng Thần Nông Viêm Đế!", SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(desc)

	var status_text := "Lượt thám hiểm hôm nay: %d / %d" % [runs_today, RUNS_PER_DAY]
	var status_col := SocialUi.GOLD if runs_today < RUNS_PER_DAY else SocialUi.WARN
	hb.add_child(SocialUi.label(status_text, status_col, 14))

	# CHUYỂN ĐỔI CHẾ ĐỘ: ĐƠN ĐẢ ĐỘC ĐẤU HOẶC TỔ ĐỘI KHIÊU CHIẾN
	var mode_bar := HBoxContainer.new()
	mode_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_bar.add_theme_constant_override("separation", 10)
	_content_box.add_child(mode_bar)

	var btn_solo := GameUi.button("🗡️ Đơn Đả Độc Đấu (Solo)", GameUi.BUTTON)
	btn_solo.custom_minimum_size = Vector2(230, 36)
	if not _party_mode:
		btn_solo.add_theme_color_override("font_color", Color.GOLD)
	btn_solo.pressed.connect(func() -> void:
		_party_mode = false
		_render()
	)
	mode_bar.add_child(btn_solo)

	var btn_team := GameUi.button("👥 Tổ Đội Khiêu Chiến (Tạo / Vào Phòng)", GameUi.BUTTON)
	btn_team.custom_minimum_size = Vector2(260, 36)
	if _party_mode:
		btn_team.add_theme_color_override("font_color", Color.GOLD)
	btn_team.pressed.connect(func() -> void:
		_party_mode = true
		_render()
	)
	mode_bar.add_child(btn_team)

	if not _party_mode:
		_render_solo_view(runs_today)
	else:
		if _current_room_id == "":
			_render_lobby_view(runs_today)
		else:
			_render_room_view(runs_today)

# ---------------------------------------------------------------- CHẾ ĐỘ SOLO
func _render_solo_view(runs_today: int) -> void:
	# 1. Chọn Lộ Trình Tiến Công
	_content_box.add_child(SocialUi.label("1. Chọn Lộ Trình Xuất Kích:", SocialUi.TITLE, 14))
	var route_box := HBoxContainer.new()
	route_box.alignment = BoxContainer.ALIGNMENT_CENTER
	route_box.add_theme_constant_override("separation", 10)
	_content_box.add_child(route_box)

	var routes_cfg := [
		{"id": "a", "name": "🛡️ Đường A (Chính Đạo)", "desc": "Thiên Vương, Thiếu Lâm, Nga My..."},
		{"id": "b", "name": "⚖️ Đường B (Trung Lập)", "desc": "Cái Bang, Võ Đang, Côn Lôn..."},
		{"id": "c", "name": "⚔️ Đường C (Tà Phái)", "desc": "Ngũ Độc, Đường Môn, Thiên Nhẫn..."}
	]

	var route_buttons: Array[Button] = []
	for r in routes_cfg:
		var rid: String = str(r["id"])
		var btn := GameUi.button(str(r["name"]), GameUi.BUTTON)
		btn.custom_minimum_size = Vector2(215, 42)
		if rid == _selected_route:
			btn.add_theme_color_override("font_color", Color.GOLD)
		var rid_cap := rid
		btn.pressed.connect(func() -> void:
			_selected_route = rid_cap
			for b in route_buttons:
				b.remove_theme_color_override("font_color")
			btn.add_theme_color_override("font_color", Color.GOLD)
		)
		route_buttons.append(btn)
		route_box.add_child(btn)

	# 2. Vật phẩm bổ trợ (Viêm Đế Lệnh)
	_render_viem_de_lenh_card()

	# 3. Nút tiến vào
	var action_box := VBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 8)
	_content_box.add_child(action_box)

	var enter_btn := SocialUi.stone_button("⚔️ TIẾN VÀO VIÊM ĐẾ BẢO TÀNG (SOLO)", Vector2(380, 48))
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter_btn.add_theme_font_size_override("font_size", 15)
	enter_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))

	var can_enter := (runs_today < RUNS_PER_DAY) and (_profile == null or _profile.level >= 50)
	enter_btn.disabled = not can_enter
	enter_btn.pressed.connect(func() -> void:
		_on_solo_enter_pressed()
	)
	action_box.add_child(enter_btn)

	var tip_lbl := SocialUi.label("Yêu cầu cấp 50+ · Cần 1 Viêm Đế Lệnh · Thời gian vượt ải 30 phút · Khi vào map sẽ xuất hiện tại bến thuyền.", SocialUi.MUTED, 12, HORIZONTAL_ALIGNMENT_CENTER)
	action_box.add_child(tip_lbl)

static func get_viem_de_lenh_icon() -> Texture2D:
	if ResourceLoader.exists("res://assets/items/icons/taskobj021.png"):
		return load("res://assets/items/icons/taskobj021.png")
	var rec := ItemDatabase.get_misc(ViemDeLobby.VIEM_DE_LENH_ID)
	if not rec.is_empty():
		return ItemDatabase.get_icon(rec)
	return null

func _on_solo_enter_pressed() -> void:
	if not ViemDeLobby.has_entry_item(_profile):
		if _profile and _profile.jade >= ViemDeLobby.VIEM_DE_LENH_PRICE_KNB:
			SocialWindow.ask_yes_no(self, "Cần Viêm Đế Lệnh",
				"Tham gia khiêu chiến Viêm Đế yêu cầu phải có 1 Viêm Đế Lệnh trong hành trang.\nBạn có muốn dùng 2 KNB để mua 1 Viêm Đế Lệnh và tham gia ngay không?",
				func(yes: bool) -> void:
					if yes:
						var b_res := ViemDeLobby.buy_entry_item(_profile, 1)
						if b_res["ok"]:
							if ViemDeLobby.consume_entry_item(_profile):
								_use_viem_de_lenh = true
								_enter_viem_de([])
						else:
							SocialWindow.info(self, "Không Thể Mua Lệnh", b_res["msg"])
			)
		else:
			SocialWindow.info(self, "Thiếu Viêm Đế Lệnh", "Tham gia Viêm Đế Bảo Tàng yêu cầu phải có 1 Viêm Đế Lệnh trong hành trang!\nGiá mua: 2 KNB / 1 lệnh.")
		return

	if ViemDeLobby.consume_entry_item(_profile):
		_use_viem_de_lenh = true
		_enter_viem_de([])

func _render_viem_de_lenh_card() -> void:
	var buff_card := GameUi.panel(GameUi.SECTION)
	_content_box.add_child(buff_card)
	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 14)
	buff_card.add_child(bb)

	# Icon Viêm Đế Lệnh
	var icon_box := GameUi.panel(GameUi.PANEL)
	icon_box.custom_minimum_size = Vector2(46, 46)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.tooltip_text = "Viêm Đế Lệnh"
	bb.add_child(icon_box)
	var icon_tex := TextureRect.new()
	icon_tex.texture = get_viem_de_lenh_icon()
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.position = Vector2(3, 3)
	icon_tex.size = Vector2(40, 40)
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon_tex)

	# Số lượng còn
	var token_count := ViemDeLobby.count_entry_item(_profile)
	var count_lbl := SocialUi.label("Số lượng còn: %d" % token_count, Color(1.0, 0.9, 0.35), 14)
	count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bb.add_child(count_lbl)

	# Nút mua
	var btn_buy := SocialUi.stone_button("🛒 Mua 1 Lệnh (2 KNB)", Vector2(170, 34))
	btn_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_buy.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	btn_buy.pressed.connect(func() -> void:
		var res := ViemDeLobby.buy_entry_item(_profile, 1)
		if res["ok"]:
			SocialWindow.info(self, "Mua Thành Công", res["msg"])
		else:
			SocialWindow.info(self, "Không Thể Mua", res["msg"])
		_render()
	)
	bb.add_child(btn_buy)

# ---------------------------------------------------------------- SẢNH TỔ ĐỘI (LOBBY VIEW)
func _render_lobby_view(_runs_today: int) -> void:
	# Thẻ Viêm Đế Lệnh trong sảnh tổ đội
	_render_viem_de_lenh_card()

	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 10)
	_content_box.add_child(ctrl_row)

	var btn_create := SocialUi.stone_button("➕ Tạo Phòng Tổ Đội", Vector2(170, 38))
	btn_create.pressed.connect(_on_create_room_pressed)
	ctrl_row.add_child(btn_create)

	var search_edit := LineEdit.new()
	search_edit.placeholder_text = "Nhập ID phòng 6 số..."
	search_edit.custom_minimum_size = Vector2(180, 38)
	ctrl_row.add_child(search_edit)

	var btn_join := SocialUi.stone_button("🔍 Vào Phòng", Vector2(120, 38))
	btn_join.pressed.connect(func() -> void:
		var target_id := search_edit.text.strip_edges()
		if target_id == "":
			SocialWindow.info(self, "Thông Báo", "Vui lòng nhập ID phòng cần tham gia!")
			return
		var target_room := ViemDeLobby.find(target_id)
		if not target_room.is_empty() and str(target_room.get("password", "")).strip_edges() != "":
			SocialWindow.prompt(self, "Mật Khẩu Phòng #%s" % target_id, "Nhập mật khẩu phòng:", func(pw: String) -> void:
				_join_room(target_id, pw.strip_edges())
			, "", true)
		else:
			_join_room(target_id, "")
	)
	ctrl_row.add_child(btn_join)

	var btn_quick := SocialUi.stone_button("⚡ Vào Nhanh", Vector2(120, 38))
	btn_quick.pressed.connect(_on_quick_join_pressed)
	ctrl_row.add_child(btn_quick)

	_content_box.add_child(SocialUi.label("Danh Sách Phòng Chờ Tổ Đội Viêm Đế Đang Mở:", SocialUi.TITLE, 14))

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	_content_box.add_child(list_box)

	var room_list := ViemDeLobby.rooms(ViemDeLobby.WAITING)
	if room_list.is_empty():
		var empty_lbl := SocialUi.label("Hiện chưa có phòng tổ đội nào đang mở. Hãy bấm [➕ Tạo Phòng Tổ Đội] để thành lập nhóm!", SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
		list_box.add_child(empty_lbl)
	else:
		for r in room_list:
			var card := GameUi.panel(GameUi.SECTION)
			list_box.add_child(card)
			var cr := HBoxContainer.new()
			cr.add_theme_constant_override("separation", 12)
			card.add_child(cr)

			var r_info := VBoxContainer.new()
			r_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cr.add_child(r_info)

			var r_route_txt := "Đường A" if str(r.get("route", "a")) == "a" else ("Đường B" if str(r.get("route", "")) == "b" else "Đường C")
			var r_buff_txt := " [x2 EXP]" if bool(r.get("double_exp", false)) else ""
			var is_locked: bool = str(r.get("password", "")).strip_edges() != ""
			var lock_tag := " 🔒 [Có MK]" if is_locked else ""
			var r_title := SocialUi.label("🏛️ Phòng #%s · Chủ phòng: %s (%s%s%s)" % [
				str(r.get("id", "")), str(r.get("host", "")), r_route_txt, r_buff_txt, lock_tag
			], Color(1.0, 0.85, 0.25), 14)
			r_info.add_child(r_title)

			var members: Array = r.get("members", [])
			var mem_names: Array[String] = []
			for m in members:
				var is_rd: bool = bool(m.get("ready", false))
				var tag := " (Sẵn sàng)" if is_rd else " (Chờ)"
				mem_names.append(str(m.get("name", "")) + tag)
			var mem_lbl := SocialUi.label("Thành viên (%d/4): %s" % [members.size(), ", ".join(mem_names)], SocialUi.MUTED, 12)
			mem_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			r_info.add_child(mem_lbl)

			var b_enter := SocialUi.stone_button("Tham Gia", Vector2(110, 36))
			var rid := str(r.get("id", ""))
			b_enter.pressed.connect(func() -> void:
				if is_locked:
					SocialWindow.prompt(self, "Mật Khẩu Phòng #%s" % rid, "Nhập mật khẩu phòng:", func(pw: String) -> void:
						_join_room(rid, pw.strip_edges())
					, "", true)
				else:
					_join_room(rid, "")
			)
			cr.add_child(b_enter)

func _on_create_room_pressed() -> void:
	if _profile == null:
		return
	if not ViemDeLobby.has_entry_item(_profile):
		if _profile.jade >= ViemDeLobby.VIEM_DE_LENH_PRICE_KNB:
			SocialWindow.ask_yes_no(self, "Cần Viêm Đế Lệnh",
				"Chủ phòng khi tạo phòng mới cần phải có 1 Viêm Đế Lệnh trong hành trang.\nBạn có muốn dùng 2 KNB để mua 1 Viêm Đế Lệnh ngay bây giờ không?",
				func(yes: bool) -> void:
					if yes:
						var b_res := ViemDeLobby.buy_entry_item(_profile, 1)
						if b_res["ok"]:
							_prompt_create_room()
						else:
							SocialWindow.info(self, "Không Thể Mua Lệnh", b_res["msg"])
			)
		else:
			SocialWindow.info(self, "Thiếu Viêm Đế Lệnh", "Chủ phòng khi tạo phòng mới phải có 1 Viêm Đế Lệnh (mua bằng 2 KNB)!\nThành viên tham gia phòng đã tạo thì không cần Viêm Đế Lệnh.")
		return

	_prompt_create_room()

func _prompt_create_room() -> void:
	SocialWindow.prompt(self, "Tạo Phòng Viêm Đế", "Đặt mật khẩu phòng (Để trống nếu phòng công khai):", func(pw: String) -> void:
		if not ViemDeLobby.consume_entry_item(_profile):
			SocialWindow.info(self, "Thiếu Lệnh", "Không tìm thấy Viêm Đế Lệnh trong hành trang!")
			return
		var room := ViemDeLobby.create(_profile, _selected_route, true, pw.strip_edges())
		room["host_paid"] = true
		_current_room_id = str(room.get("id", ""))
		_render()
	)

func _join_room(room_id: String, password: String = "") -> void:
	if _profile == null:
		return
	var err := ViemDeLobby.join(room_id, _profile, password)
	if err != "":
		SocialWindow.info(self, "Không Thể Vào Phòng", err)
		return
	_current_room_id = room_id
	_render()

func _on_quick_join_pressed() -> void:
	var room_list := ViemDeLobby.rooms(ViemDeLobby.WAITING)
	for r in room_list:
		if str(r.get("password", "")).strip_edges() != "":
			continue
		var members: Array = r.get("members", [])
		if members.size() < ViemDeLobby.MAX_MEMBERS:
			_join_room(str(r.get("id", "")), "")
			return
	_on_create_room_pressed()

# ---------------------------------------------------------------- PHÒNG CHỜ TỔ ĐỘI (ROOM VIEW)
func _render_room_view(runs_today: int) -> void:
	var room := ViemDeLobby.find(_current_room_id)
	if room.is_empty():
		_current_room_id = ""
		_render()
		return

	# Kiểm tra người chơi có còn trong phòng hay đã bị chủ phòng kích ra
	var my_name := _profile.display_name if _profile else ""
	var is_member := false
	for m in room.get("members", []):
		if str(m.get("name", "")) == my_name:
			is_member = true
			break
	if not is_member:
		_current_room_id = ""
		SocialWindow.info(self, "Thông Báo", "Bạn đã bị chủ phòng kích ra khỏi phòng tổ đội!")
		_render()
		return

	var is_host := (str(room.get("host", "")) == my_name)
	var route_name := "Đường A (Chính Đạo)" if str(room.get("route", "a")) == "a" else ("Đường B (Trung Lập)" if str(room.get("route", "")) == "b" else "Đường C (Tà Phái)")

	# Top Bar
	var top_bar := HBoxContainer.new()
	_content_box.add_child(top_bar)

	var btn_leave := SocialUi.small_button("← Rời Phòng")
	btn_leave.custom_minimum_size = Vector2(130, 32)
	btn_leave.pressed.connect(func() -> void:
		ViemDeLobby.leave(_current_room_id, _profile)
		_current_room_id = ""
		_render()
	)
	top_bar.add_child(btn_leave)

	var room_title := SocialUi.label("🏛️ PHÒNG TỔ ĐỘI VIÊM ĐẾ #%s" % room["id"], SocialUi.TITLE, 18, HORIZONTAL_ALIGNMENT_CENTER)
	room_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(room_title)

	# Thông tin lộ trình, chủ phòng & mật khẩu phòng
	var info_panel := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(info_panel)
	var ib := HBoxContainer.new()
	ib.alignment = BoxContainer.ALIGNMENT_CENTER
	ib.add_theme_constant_override("separation", 20)
	info_panel.add_child(ib)

	ib.add_child(SocialUi.label("👑 Chủ phòng: %s" % room["host"], Color(1.0, 0.85, 0.25), 13))
	ib.add_child(SocialUi.label("🗺️ Lộ trình: %s" % route_name, Color(0.4, 0.85, 1.0), 13))
	var buff_text := "BẬT (x2 EXP & Rương)" if bool(room.get("double_exp", false)) else "TẮT"
	ib.add_child(SocialUi.label("🎖️ Viêm Đế Lệnh: %s" % buff_text, Color(0.35, 0.95, 0.45) if bool(room.get("double_exp", false)) else SocialUi.MUTED, 13))

	# Hiển thị & cài đặt mật khẩu phòng
	var pw: String = str(room.get("password", "")).strip_edges()
	if pw != "":
		ib.add_child(SocialUi.label("🔒 Mật khẩu: %s" % pw, Color(1.0, 0.85, 0.3), 13))
		if is_host:
			var btn_pw := SocialUi.small_button("✏️ Đổi MK")
			btn_pw.pressed.connect(func() -> void:
				SocialWindow.prompt(self, "Đổi Mật Khẩu Phòng", "Mật khẩu mới (để trống nếu muốn bỏ khóa):", func(new_pw: String) -> void:
					ViemDeLobby.set_password(_current_room_id, _profile, new_pw.strip_edges())
					_render()
				)
			)
			ib.add_child(btn_pw)

			var btn_clear_pw := SocialUi.small_button("🔓 Bỏ MK")
			btn_clear_pw.pressed.connect(func() -> void:
				ViemDeLobby.set_password(_current_room_id, _profile, "")
				_render()
			)
			ib.add_child(btn_clear_pw)
	else:
		ib.add_child(SocialUi.label("🔓 Công khai (Không MK)", SocialUi.MUTED, 13))
		if is_host:
			var btn_set_pw := SocialUi.small_button("🔒 Đặt Mật Khẩu")
			btn_set_pw.pressed.connect(func() -> void:
				SocialWindow.prompt(self, "Đặt Mật Khẩu Phòng", "Nhập mật khẩu phòng:", func(new_pw: String) -> void:
					if new_pw.strip_edges() != "":
						ViemDeLobby.set_password(_current_room_id, _profile, new_pw.strip_edges())
						_render()
				)
			)
			ib.add_child(btn_set_pw)

	# Danh sách 4 slot thành viên
	_content_box.add_child(SocialUi.label("Đội Hình Tổ Đội (Tối đa 4 người):", SocialUi.TITLE, 14))
	var members_grid := VBoxContainer.new()
	members_grid.add_theme_constant_override("separation", 6)
	_content_box.add_child(members_grid)

	var members: Array = room.get("members", [])
	for i in ViemDeLobby.MAX_MEMBERS:
		var slot_card := GameUi.panel(GameUi.SECTION)
		members_grid.add_child(slot_card)
		var sr := HBoxContainer.new()
		sr.add_theme_constant_override("separation", 12)
		slot_card.add_child(sr)

		if i < members.size():
			var m_data: Dictionary = members[i]
			var m_name := str(m_data.get("name", ""))
			var m_lvl: int = int(m_data.get("level", 90))
			var m_sect := str(m_data.get("sect_name", "Võ Đang"))
			var m_is_host: bool = bool(m_data.get("is_host", false))
			var m_ready: bool = bool(m_data.get("ready", false))
			var m_is_bot: bool = bool(m_data.get("is_bot", false))

			var icon_tag := "👑 " if m_is_host else ("🤖 " if m_is_bot else "👤 ")

			var info_col := VBoxContainer.new()
			info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_col.alignment = BoxContainer.ALIGNMENT_CENTER
			info_col.add_theme_constant_override("separation", 2)
			sr.add_child(info_col)

			var name_lbl := SocialUi.label("%s%s" % [icon_tag, m_name], Color(1.0, 0.9, 0.5) if m_is_host else SocialUi.TEXT, 14)
			info_col.add_child(name_lbl)

			var sub_lbl := SocialUi.label("Cấp %d - %s" % [m_lvl, m_sect], SocialUi.SUBTITLE, 11)
			info_col.add_child(sub_lbl)

			# Trạng thái SẴN SÀNG
			if m_is_host:
				var host_tag := SocialUi.label("👑 CHỦ PHÒNG", Color(1.0, 0.85, 0.25), 13)
				host_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				sr.add_child(host_tag)
			elif m_ready:
				var rd_tag := SocialUi.label("✅ ĐÃ SẴN SÀNG", Color(0.35, 0.95, 0.45), 13)
				rd_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				sr.add_child(rd_tag)
			else:
				var not_rd_tag := SocialUi.label("⏳ CHƯA SẴN SÀNG", Color(1.0, 0.45, 0.35), 13)
				not_rd_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				sr.add_child(not_rd_tag)

			# Nút sẵn sàng cho bản thân
			if not m_is_host and m_name == my_name:
				var btn_toggle := SocialUi.stone_button("Hủy Sẵn Sàng" if m_ready else "Bấm Sẵn Sàng", Vector2(140, 32))
				btn_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				btn_toggle.pressed.connect(func() -> void:
					ViemDeLobby.toggle_ready(_current_room_id, m_name)
					_render()
				)
				sr.add_child(btn_toggle)
			elif is_host and not m_is_host:
				# Chủ phòng có thể chỉnh sẵn sàng cho bot hoặc kích thành viên ra khỏi phòng
				if m_is_bot:
					var btn_bot_rd := SocialUi.small_button("Đổi Sẵn Sàng")
					btn_bot_rd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					btn_bot_rd.pressed.connect(func() -> void:
						ViemDeLobby.toggle_ready(_current_room_id, m_name)
						_render()
					)
					sr.add_child(btn_bot_rd)

				var btn_kick := SocialUi.small_button("❌ Kích")
				btn_kick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var target_kick_name := m_name
				btn_kick.pressed.connect(func() -> void:
					SocialWindow.ask_yes_no(self, "Kích Khỏi Phòng", "Bạn có chắc muốn kích hiệp khách '%s' ra khỏi phòng không?" % target_kick_name, func(yes: bool) -> void:
						if yes:
							ViemDeLobby.kick(_current_room_id, target_kick_name, _profile)
							_render()
					)
				)
				sr.add_child(btn_kick)
		else:
			# Slot trống
			var empty_txt := SocialUi.label("Vị trí %d: (Còn trống...)" % (i + 1), SocialUi.MUTED, 13)
			empty_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sr.add_child(empty_txt)

			if is_host and GameModeManager.can_add_bot():
				var btn_add_bot := SocialUi.small_button("➕ Thêm Trợ Thủ (Bot)")
				btn_add_bot.pressed.connect(func() -> void:
					ViemDeLobby.add_bot(_current_room_id)
					_render()
				)
				sr.add_child(btn_add_bot)

	# QUY TẮC: MỌI NGƯỜI SẴN SÀNG HẾT MỚI VÀO CHƠI
	var all_ready: bool = ViemDeLobby.is_all_ready(room)

	var action_box := VBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 8)
	_content_box.add_child(action_box)

	var hint_text := ""
	var hint_col := Color.WHITE
	if not all_ready:
		hint_text = "⚠️ Chờ thành viên trong tổ đội bấm [Sẵn Sàng]! Tất cả sẵn sàng hết chủ phòng mới có thể bắt đầu."
		hint_col = Color(1.0, 0.45, 0.35)
	else:
		hint_text = "✨ Toàn bộ tổ đội đã sẵn sàng! Chủ phòng hãy bấm nút bên dưới để khai chiến!"
		hint_col = Color(0.35, 0.95, 0.45)

	var hint_lbl := SocialUi.label(hint_text, hint_col, 13, HORIZONTAL_ALIGNMENT_CENTER)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_box.add_child(hint_lbl)

	var enter_btn := SocialUi.stone_button("⚔️ TIẾN VÀO VIÊM ĐẾ (KHAI CHIẾN TỔ ĐỘI)", Vector2(400, 48))
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter_btn.add_theme_font_size_override("font_size", 15)
	enter_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))

	var can_enter := is_host and all_ready and (runs_today < RUNS_PER_DAY) and (_profile == null or _profile.level >= 50)
	enter_btn.disabled = not can_enter
	enter_btn.pressed.connect(func() -> void:
		_enter_viem_de(members)
	)
	action_box.add_child(enter_btn)

func _enter_viem_de(team_mems: Array) -> void:
	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var runs_today: int = int(rec.get("runs", {}).get(today, 0))
	if runs_today >= RUNS_PER_DAY:
		SocialWindow.info(self, "Hết Lượt", "Hôm nay đại hiệp đã hoàn thành hết %d lượt thám hiểm Viêm Đế Bảo Tàng rồi!" % RUNS_PER_DAY)
		return

	var chosen_r := _selected_route
	var double_exp_val := _use_viem_de_lenh
	if not _current_room_id.is_empty():
		var room := ViemDeLobby.find(_current_room_id)
		if not room.is_empty():
			chosen_r = str(room.get("route", "a"))
			double_exp_val = bool(room.get("double_exp", false))
			if team_mems.is_empty():
				team_mems = room.get("members", [])
			room["state"] = ViemDeLobby.FIGHTING

	var ydbz_script: GDScript = load("res://systems/challenge/viem_de_challenge.gd")
	var entry_dict: Dictionary = ydbz_script.map_entry(chosen_r, double_exp_val, team_mems)
	close_requested.emit()

	if _on_enter_field.is_valid():
		_on_enter_field.call(entry_dict)
	else:
		GameManager.field_map = entry_dict
		get_tree().change_scene_to_file("res://world/vltk_world.tscn")

# ---------------------------------------------------------------- TAB 1: ĐỔI THƯỞNG & ĐỒ ĐẰNG
func _render_reward_tab() -> void:
	var rec := _get_records()
	var inv_frags := _count_in_inventory("6_1_1685")
	var fragments: int = maxi(int(rec.get("totem_fragments", 0)), inv_frags)
	var inv_totems := _count_in_inventory("6_1_1606")
	var totems: int = maxi(int(rec.get("totems", 0)), inv_totems)
	var inv_chests := _count_in_inventory("6_1_2805")
	var chests: int = maxi(int(rec.get("chests", 0)), inv_chests)

	# Hàng điều hướng trên cùng của tiệm
	var top_nav := HBoxContainer.new()
	top_nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_child(top_nav)

	var nav_title := SocialUi.label("Kho Báu & Tiệm Đổi Thưởng Viêm Đế", SocialUi.TITLE, 17)
	nav_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_nav.add_child(nav_title)

	var btn_back := SocialUi.stone_button("⚔️ Quay Lại Khiêu Chiến", Vector2(210, 34))
	btn_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_back.pressed.connect(func() -> void:
		_tab = 0
		_render()
		if _scroll != null:
			_scroll.scroll_vertical = 0
	)
	top_nav.add_child(btn_back)

	# Kho bảo vật Viêm Đế hiện có
	var status_card := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(status_card)
	var sb := HBoxContainer.new()
	sb.alignment = BoxContainer.ALIGNMENT_CENTER
	sb.add_theme_constant_override("separation", 24)
	status_card.add_child(sb)

	sb.add_child(SocialUi.label("📦 Rương Viêm Đế: %d" % chests, Color(1.0, 0.85, 0.25), 14))
	sb.add_child(SocialUi.label("🧩 Mảnh Đồ Đằng: %d" % fragments, Color(0.4, 0.85, 1.0), 14))
	sb.add_child(SocialUi.label("🔥 Viêm Đế Đồ Đằng: %d" % totems, Color(1.0, 0.45, 0.35), 14))

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_content_box.add_child(list)

	# 1. Mở Rương Viêm Đế Bí Bảo
	var c1 := GameUi.panel(GameUi.SECTION)
	list.add_child(c1)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 12)
	c1.add_child(r1)
	var inf1 := VBoxContainer.new()
	inf1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(inf1)
	inf1.add_child(SocialUi.label("Mở Rương Viêm Đế Bí Bảo", Color(1.0, 0.85, 0.25), 15))
	inf1.add_child(SocialUi.label("Nhận ngẫu nhiên: 1.000.000 - 5.000.000 EXP, Thủy Tinh (Lam/Tử/Lục), Mảnh Đồ Đằng, Huyền Tinh và Ngân Lượng.", SocialUi.MUTED, 12))
	var b_open := SocialUi.stone_button("Mở Rương", Vector2(130, 36))
	b_open.pressed.connect(_open_chest)
	r1.add_child(b_open)

	# 2. Ghép Đồ Đằng Viêm Đế
	var c2 := GameUi.panel(GameUi.SECTION)
	list.add_child(c2)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 12)
	c2.add_child(r2)
	var inf2 := VBoxContainer.new()
	inf2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(inf2)
	inf2.add_child(SocialUi.label("Ghép Viêm Đế Đồ Đằng (Yandi Totem)", Color(1.0, 0.45, 0.35), 15))
	inf2.add_child(SocialUi.label("Cần: 9 Mảnh Đồ Đằng Viêm Đế (Gom đủ 9 mảnh ghép thành 1 Viêm Đế Đồ Đằng nguyên vẹn).", SocialUi.MUTED, 12))
	var b_craft := SocialUi.stone_button("Ghép Đồ Đằng", Vector2(130, 36))
	b_craft.pressed.connect(_craft_totem)
	r2.add_child(b_craft)
	var b_craft_all := SocialUi.stone_button("Ghép Tất Cả", Vector2(110, 36))
	b_craft_all.pressed.connect(_craft_all_totems)
	r2.add_child(b_craft_all)

	# 3. Các bộ trang bị Hoàng Kim Viêm Đế
	list.add_child(SocialUi.label("Trang Bị Hoàng Kim Viêm Đế Danh Bất Hư Truyền:", SocialUi.TITLE, 14))
	for s in GOLD_SETS:
		var c := GameUi.panel(GameUi.PANEL)
		list.add_child(c)
		var cr := HBoxContainer.new()
		cr.add_theme_constant_override("separation", 12)
		c.add_child(cr)

		var c_info := VBoxContainer.new()
		c_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cr.add_child(c_info)
		c_info.add_child(SocialUi.label(str(s["name"]), s["color"], 14))
		var items_str: String = ", ".join(s["items"])
		var l_it := SocialUi.label("Gồm: %s" % items_str, SocialUi.MUTED, 12)
		l_it.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c_info.add_child(l_it)

		var b_redeem := SocialUi.stone_button("Đổi Trang Bị", Vector2(130, 36))
		b_redeem.pressed.connect(_redeem_set.bind(s))
		cr.add_child(b_redeem)

func _open_chest() -> void:
	if _profile == null:
		return
	var rec := _get_records()
	var inv_chests := _count_in_inventory("6_1_2805")
	var rec_chests: int = int(rec.get("chests", 0))
	var total_chests := maxi(rec_chests, inv_chests)
	if total_chests <= 0:
		SocialWindow.info(self, "Không Có Rương", "Đại hiệp hiện không có Rương Viêm Đế Bí Bảo nào!\nHãy tham gia khiêu chiến Viêm Đế Bảo Tàng để thu thập rương thưởng.")
		return

	# Tiêu hao 1 rương
	_consume_from_inventory("6_1_2805", 1)
	rec["chests"] = maxi(0, total_chests - 1)

	# Nhận 1-3 Mảnh Đồ Đằng Viêm Đế thật sự vào túi đồ
	var frags := randi_range(1, 3)
	rec["totem_fragments"] = int(rec.get("totem_fragments", 0)) + frags
	for i in frags:
		var frag_it := ItemGenerator.generate_misc("6_1_1685")
		if frag_it != null:
			_profile.add_item(frag_it)

	# Nhận 1 Thủy Tinh (Lam/Tử/Lục) ngẫu nhiên thật sự vào túi đồ
	var tt_ids := ["4_238_1", "4_239_1", "4_240_1"]
	var tt_pick: String = tt_ids.pick_random()
	var tt_it := ItemGenerator.generate_misc(tt_pick)
	var tt_name := "Thủy Tinh"
	if tt_it != null:
		tt_name = tt_it.get_display_name()
		_profile.add_item(tt_it)

	var gained_exp := randi_range(1500000, 3500000)
	var gained_gold := randi_range(150000, 350000)
	_profile.add_exp(gained_exp)
	_profile.gold += gained_gold

	_save_records(rec)
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()

	SocialWindow.info(self, "Mở Rương Viêm Đế Bí Bảo",
			"Mở rương thành công!\nNhận được:\n+ %s EXP\n+ %s Lượng\n+ %d Mảnh Đồ Đằng Viêm Đế\n+ 1 %s\nVật phẩm đã được chuyển vào hành trang nhân vật." % [
				InventoryPopup.format_money(gained_exp),
				InventoryPopup.format_money(gained_gold),
				frags,
				tt_name
			])
	_render()

func _craft_totem() -> void:
	if _profile == null:
		return
	var rec := _get_records()
	var inv_frags := _count_in_inventory("6_1_1685")
	var rec_frags: int = int(rec.get("totem_fragments", 0))
	var total_frags := maxi(rec_frags, inv_frags)
	if total_frags < 9:
		SocialWindow.info(self, "Chưa Đủ Mảnh", "Cần tối thiểu 9 Mảnh Đồ Đằng Viêm Đế để ghép! Hiện có: %d/9 mảnh." % total_frags)
		return

	# Tạo vật phẩm Viêm Đế Đồ Đằng thật sự vào túi đồ
	var totem_it: ItemInstance = ItemGenerator.generate_misc("6_1_1606")
	if totem_it != null and not _profile.add_item(totem_it):
		SocialWindow.info(self, "Hành Trang Đầy", "Hành trang của đại hiệp đã đầy! Hãy dọn bớt ô trống trong hành trang để nhận Viêm Đế Đồ Đằng.")
		return

	_consume_from_inventory("6_1_1685", 9)
	rec["totem_fragments"] = maxi(0, total_frags - 9)
	rec["totems"] = int(rec.get("totems", 0)) + 1
	_save_records(rec)
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()

	SocialWindow.info(self, "Ghép Thành Công", "Chúc mừng đại hiệp đã ghép thành công 1 Viêm Đế Đồ Đằng nguyên vẹn!\nĐồ Đằng đã được thêm vào túi đồ và ghi nhận vào kho bảo vật.")
	_render()

func _craft_all_totems() -> void:
	if _profile == null:
		return
	var rec := _get_records()
	var inv_frags := _count_in_inventory("6_1_1685")
	var rec_frags: int = int(rec.get("totem_fragments", 0))
	var total_frags := maxi(rec_frags, inv_frags)
	var craft_count := total_frags / 9
	if craft_count < 1:
		SocialWindow.info(self, "Chưa Đủ Mảnh", "Cần tối thiểu 9 Mảnh Đồ Đằng Viêm Đế để ghép! Hiện có: %d/9 mảnh." % total_frags)
		return

	var success_count := 0
	for c in craft_count:
		var totem_it: ItemInstance = ItemGenerator.generate_misc("6_1_1606")
		if totem_it == null or not _profile.add_item(totem_it):
			break
		_consume_from_inventory("6_1_1685", 9)
		success_count += 1

	if success_count == 0:
		SocialWindow.info(self, "Hành Trang Đầy", "Hành trang của đại hiệp đã đầy! Hãy dọn bớt ô trống để nhận Viêm Đế Đồ Đằng.")
		return

	rec["totem_fragments"] = maxi(0, total_frags - (success_count * 9))
	rec["totems"] = int(rec.get("totems", 0)) + success_count
	_save_records(rec)
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()

	SocialWindow.info(self, "Ghép Tất Cả Thành Công", "Chúc mừng đại hiệp đã ghép thành công %d Viêm Đế Đồ Đằng nguyên vẹn!\nĐồ Đằng đã được thêm vào túi đồ." % success_count)
	_render()

func _redeem_set(s: Dictionary) -> void:
	if _profile == null:
		return
	var rec := _get_records()
	var inv_totems := _count_in_inventory("6_1_1606")
	var rec_totems: int = int(rec.get("totems", 0))
	var total_totems := maxi(rec_totems, inv_totems)
	if total_totems < 1:
		SocialWindow.info(self, "Cần Viêm Đế Đồ Đằng", "Đổi trang bị Hoàng Kim Viêm Đế cần tối thiểu 1 Viêm Đế Đồ Đằng!\nHãy tham gia vượt ải Viêm Đế Bảo Tàng hoặc ghép từ 9 Mảnh Đồ Đằng để thu thập.")
		return

	var indices: Array = s.get("gold_indices", [441])
	var item_names: Array = s.get("items", [])

	# Hộp thoại cho người chơi tự chọn chính xác món trang bị muốn nhận
	var pop := AcceptDialog.new()
	pop.title = "Đổi %s" % str(s.get("name", "Trang Bị Hoàng Kim"))
	pop.dialog_text = ""
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pop.add_child(vb)

	vb.add_child(SocialUi.label("🔥 Tiêu hao: 1 Viêm Đế Đồ Đằng (Hiện có: %d)" % total_totems, Color(1.0, 0.85, 0.25), 14))
	vb.add_child(SocialUi.label("Chọn món trang bị Hoàng Kim đại hiệp muốn nhận:", SocialUi.MUTED, 12))

	for i in indices.size():
		var g_idx: int = int(indices[i])
		var it_name: String = item_names[i] if i < item_names.size() else "Trang Bị #%d" % g_idx
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vb.add_child(row)

		var lbl := SocialUi.label(it_name, s.get("color", Color.WHITE), 13)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var b_pick := SocialUi.stone_button("Đổi Món Này", Vector2(120, 30))
		b_pick.pressed.connect(func() -> void:
			pop.queue_free()
			_do_redeem_gold_item(g_idx)
		)
		row.add_child(b_pick)

	add_child(pop)
	pop.popup_centered()

func _do_redeem_gold_item(g_idx: int) -> void:
	if _profile == null:
		return
	var rec := _get_records()
	var inv_totems := _count_in_inventory("6_1_1606")
	var rec_totems: int = int(rec.get("totems", 0))
	var total_totems := maxi(rec_totems, inv_totems)
	if total_totems < 1:
		SocialWindow.info(self, "Cần Viêm Đế Đồ Đằng", "Đổi trang bị Hoàng Kim Viêm Đế cần tối thiểu 1 Viêm Đế Đồ Đằng!")
		return

	var gold_item: ItemInstance = ItemGenerator.generate_gold(g_idx, 10)
	if gold_item == null or not _profile.add_item(gold_item):
		SocialWindow.info(self, "Hành Trang Đầy", "Hành trang của đại hiệp đã đầy! Hãy dọn bớt ô trống trong hành trang để nhận trang bị Hoàng Kim.")
		return

	_consume_from_inventory("6_1_1606", 1)
	rec["totems"] = maxi(0, total_totems - 1)
	_save_records(rec)
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()

	SocialWindow.info(self, "Đổi Trang Bị Thành Công", "Chúc mừng đại hiệp đã đổi thành công:\n👑 [b]%s[/b]!\nTrang bị Hoàng Kim đã được chuyển vào hành trang nhân vật." % gold_item.get_display_name())
	_render()

func _count_in_inventory(misc_id: String) -> int:
	if _profile == null:
		return 0
	var count := 0
	for it in _profile.inventory:
		if it != null and it.misc_id == misc_id:
			count += maxi(it.count, 1)
	return count

func _consume_from_inventory(misc_id: String, amount: int = 1) -> int:
	if _profile == null or amount <= 0:
		return 0
	var consumed := 0
	var i := 0
	while i < _profile.inventory.size() and consumed < amount:
		var it: ItemInstance = _profile.inventory[i]
		if it != null and it.misc_id == misc_id:
			var need := amount - consumed
			if it.count > need:
				it.count -= need
				consumed += need
				i += 1
			else:
				consumed += maxi(it.count, 1)
				_profile.inventory.remove_at(i)
		else:
			i += 1
	return consumed

# ---------------------------------------------------------------- TƯƠNG THÍCH UNIT TESTS
func _clear_floor(f: Dictionary, is_sweep: bool) -> void:
	if _profile == null:
		return
	var f_num: int = int(f["floor"])
	var min_lv: int = int(f.get("min_level", 50))
	if _profile.level < min_lv:
		return

	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var runs_today: int = int(rec.get("runs", {}).get(today, 0))
	if runs_today >= RUNS_PER_DAY:
		return

	var rew_exp := int(f.get("reward_exp", 600000))
	var rew_gold := int(f.get("reward_gold", 80000))
	_profile.add_exp(rew_exp)
	_profile.gold += rew_gold

	var runs_dict: Dictionary = rec.get("runs", {})
	runs_dict[today] = runs_today + 1
	rec["runs"] = runs_dict

	var cleared: Array = rec.get("cleared", [])
	if not (f_num in cleared):
		cleared.append(f_num)
	rec["cleared"] = cleared
	_save_records(rec)
	SaveManager.save_profile(_profile)

# ---------------------------------------------------------------- LƯU TRỮ
static func get_record_key(profile: PlayerProfile = null) -> String:
	var p := profile if profile != null else GameManager.local_profile
	var acc_id := ""
	if AccountApi != null and AccountApi.is_logged_in():
		acc_id = str(AccountApi.account.get("id", ""))
		if acc_id.is_empty():
			acc_id = str(AccountApi.account.get("username", ""))
	var char_name := p.display_name if p != null else ""
	var key := ""
	if not acc_id.is_empty() and not char_name.is_empty():
		key = "%s_%s" % [acc_id, char_name]
	elif not acc_id.is_empty():
		key = acc_id
	elif not char_name.is_empty():
		key = char_name
	else:
		key = "default"

	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		key = key.replace(ch, "_")
	return key

static func get_record_path(profile: PlayerProfile = null) -> String:
	return "user://viem_de_records_%s.json" % get_record_key(profile)

func _get_records() -> Dictionary:
	return _get_records_for(_profile)

func _save_records(rec: Dictionary) -> void:
	_save_records_for(rec, _profile)

static func _get_records_for(profile: PlayerProfile = null) -> Dictionary:
	var path := get_record_path(profile)
	var rec: Dictionary = {}
	if FileAccess.file_exists(path):
		var txt := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			rec = parsed

	# Tự động đồng bộ số lượng với hành trang nhân vật
	var p := profile if profile != null else GameManager.local_profile
	if p != null:
		var inv_chests := 0
		var inv_frags := 0
		var inv_totems := 0
		for it in p.inventory:
			if it != null:
				if it.misc_id == "6_1_2805":
					inv_chests += maxi(it.count, 1)
				elif it.misc_id == "6_1_1685":
					inv_frags += maxi(it.count, 1)
				elif it.misc_id == "6_1_1606":
					inv_totems += maxi(it.count, 1)

		# Bù lại rương cho người chơi đã vượt ải hôm nay nhưng trước khi cập nhật lưu rương
		var today := Time.get_date_string_from_system()
		var runs_today: int = int(rec.get("runs", {}).get(today, 0))
		if runs_today > 0 and int(rec.get("chests", 0)) == 0 and inv_chests == 0 and not rec.get("compensated_v1", false):
			rec["compensated_v1"] = true
			var retro_chests := runs_today * 7
			rec["chests"] = retro_chests
			for i in retro_chests:
				var c_it := ItemGenerator.generate_misc("6_1_2805")
				if c_it != null:
					p.add_item(c_it)
			SaveManager.save_profile(p)
			SaveManager.flush_online()

		if inv_chests > int(rec.get("chests", 0)):
			rec["chests"] = inv_chests
		if inv_frags > int(rec.get("totem_fragments", 0)):
			rec["totem_fragments"] = inv_frags
		if inv_totems > int(rec.get("totems", 0)):
			rec["totems"] = inv_totems

	return rec

static func _save_records_for(rec: Dictionary, profile: PlayerProfile = null) -> void:
	var path := get_record_path(profile)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rec, " "))

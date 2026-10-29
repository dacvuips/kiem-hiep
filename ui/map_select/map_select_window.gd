extends SocialWindow
class_name MapSelectWindow

## Màn "Vượt Ải" (mở từ nút Vượt Ải ở Character Hub): 3 tab lớn Thường / Ải / Địa Ngục.
##   - Thường: cột trái là nhóm cấp 1x..12x, bên phải là các map luyện công thuộc nhóm đó (MapCatalog) — mỗi map có ảnh mini map,
##     tên map, cấp quái + tên quái, nút [Vào] đưa thẳng người chơi vào map (đi lại tự do, quái của map, như map chính).
##   - Ải: Thách Thức Thời Gian (NPC Nhiếp Thí Trần, script gốc VLTK 15 phái — TimeChallenge): 28 ải trong 30 phút.
##         Chiến Trường Tống Kim (BattleServer): số người / điểm mỗi phe + giai đoạn (server tài khoản /v1/battle, làm mới mỗi
##         BATTLE_POLL giây), chọn phe Tống / Kim — lệch quân thì không cho vào; bấm xong phải chờ BATTLE_COOLDOWN giây mới bấm lại.
##   - Địa Ngục: map 10x / 11x / 12x (quái cấp 100 / 110 / 120 — MapCatalog.hell_maps), mỗi map chọn 1-5 sao: máu, sát thương,
##     tỉ lệ rơi đồ của quái nhân số sao; 5 sao đồ rơi ra luôn đủ dòng magic (DropTable.roll_hell). Giao diện tông đỏ máu.
## Vào map: gọi on_play(entry) — Character Hub lo đổi cảnh (đóng cửa sổ trước khi gọi).
## PHÒNG TRAIN CHUNG (tab Thường / Địa Ngục, lúc đã đăng nhập): vào map = tạo phòng trên field server (FieldServer cấp ID 6 số, hiện
## ở khung trên màn chơi — FieldClient); hàng "ID phòng" dưới cùng: nhập ID của người khác -> tra phòng (GET /v1/field) -> vào đúng map
## đó cùng họ. Chưa đăng nhập: chơi một mình như cũ (offline).

const TABS := ["Luyện", "Tinh anh", "Ải", "Boss"]
const THUMB_SIZE := Vector2(168, 104)
const LIST_SIZE := Vector2(620, 440)

var _profile: PlayerProfile
var _on_play: Callable
var _host: Node
var _tab := 0
var _tier := 1
var _tab_buttons: Array[Button] = []
var _tier_buttons: Array[Button] = []
var _content: HBoxContainer
var _join_row: Control
var _join_edit: LineEdit
var _join_button: Button
var _join_msg: Label

const BATTLE_POLL := 3.0
const BATTLE_COOLDOWN := 10.0
const BATTLE_NAME := "Chiến Trường Tống Kim"
const BATTLE_PHASES := {"signup": "Đang báo danh", "fight": "Đang khai chiến", "ended": "Vừa kết thúc — chờ trận mới"}
## Lần bấm chọn phe gần nhất (ms) — tĩnh để đóng/mở lại cửa sổ vẫn phải chờ đủ.
static var _battle_clicked_at := -100000
var _battle: Dictionary = {}
var _battle_status: Label
var _battle_sides: Label
var _battle_msg: Label
var _battle_buttons := {}           ## side -> Button
var _battle_timer: Timer
var _battle_poll_acc := 0.0
var _boss_card_views: Array[Dictionary] = []
var _boss_timer: Timer

static func open(host: Node, profile: PlayerProfile, on_play: Callable) -> MapSelectWindow:
	var win := MapSelectWindow.new(profile, on_play, host)
	return SocialWindow.present(host, win, &"map_select") as MapSelectWindow

func _init(profile: PlayerProfile = null, on_play: Callable = Callable(), host: Node = null) -> void:
	super._init("Vượt Ải", "", 800.0)
	_profile = profile
	_on_play = on_play
	_host = host
	_tier = MapCatalog.normal_tier_for_level(profile.level if profile else 1)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in TABS.size():
		var b := GameUi.button(TABS[i], GameUi.TAB)
		b.custom_minimum_size = Vector2(130, 38)
		b.pressed.connect(_select_tab.bind(i))
		if i == 1:
			var purple_normal := Color(0.85, 0.45, 1.0)
			var purple_hover := Color(0.92, 0.60, 1.0)
			var purple_pressed := Color(1.0, 0.80, 1.0)
			b.add_theme_color_override("font_color", purple_normal)
			b.add_theme_color_override("font_hover_color", purple_hover)
			b.add_theme_color_override("font_pressed_color", purple_pressed)
			b.add_theme_color_override("font_focus_color", purple_pressed)
		tabs.add_child(b)
		_tab_buttons.append(b)
	body.add_child(tabs)

	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.custom_minimum_size.y = LIST_SIZE.y
	body.add_child(_content)
	_build_join_row()
	_select_tab(0)

func _select_tab(i: int) -> void:
	_tab = i
	_boss_card_views.clear()
	for k in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[k], k == i)
	for c in _content.get_children():
		c.queue_free()
	_tier_buttons.clear()
	_join_row.visible = (i in [0, 1])   ## phòng train chung: tab Thường + Địa Ngục
	if i == 0:
		_build_normal()
		return
	if i == 1:
		_build_hell()
		return
	if i == 2:
		_build_ai()
		return
	_build_boss()

# ---------------------------------------------------------------- tab Ải (Thách Thức Thời Gian)

## Tab Ải: danh sách cuộn các chế độ (Vượt Ải Giang Hồ, Thách Thức Thời Gian, Phong Lăng Độ, Chiến Trường Tống Kim).
func _build_ai() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = LIST_SIZE
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	TouchScrollHelperScript.attach(scroll, scroll)
	_build_honor_defense(list)
	_build_stages_challenge(list)
	_build_time_challenge(list)
	_build_phong_lang_do(list)
	_build_tong_kim_lol(list)
	_build_battle(list)

func _get_hub() -> Node:
	if _host != null and is_instance_valid(_host):
		return _host
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	var ml := Engine.get_main_loop() as SceneTree
	if ml != null and ml.current_scene != null:
		return ml.current_scene
	return null

## Thẻ Ải "Bảo Vệ Trụ Danh Dự" (Công Thành Chiến Lâm An #1001)
func _build_honor_defense(parent: Control) -> void:
	var card := GameUi.panel(GameUi.PANEL)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(SocialUi.label("🛡️ " + tr("Bảo Vệ Trụ Danh Dự — Công Thành Lâm An (#1001)"), SocialUi.TITLE, 20, HORIZONTAL_ALIGNMENT_CENTER))
	var desc := SocialUi.label(tr("Đài chiến trung tâm Lâm An đang bị 200 đợt quái giang hồ công phá từ 4 cổng! Cùng đồng đội tử thủ Long Trụ, chiêu mộ Danh Tướng viện binh."),
			SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	box.add_child(SocialUi.divider())

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 16)
	box.add_child(middle)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(info)

	var map_entry: Dictionary = HonorDefenseChallenge.map_entry()
	var map_frame := _minimap_frame(map_entry)
	map_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(map_frame)

	info.add_child(SocialUi.label(tr("Quy mô: 200 đợt quái (cấp 1 - 200) · 20s/đợt · 20 quái/đợt · 4 cổng xuất kích."), SocialUi.GOLD, 14))
	info.add_child(SocialUi.label(tr("Cơ chế Boss: Mỗi 10 đợt xuất hiện 1 Đại Boss (máu tăng gấp 15 lần)."), SocialUi.TEXT, 13))
	info.add_child(SocialUi.label(tr("Kỹ năng quái: Luân chuyển Ngũ Hành & kích hoạt trọn bộ kỹ năng Buff 15 môn phái."), SocialUi.TEXT, 13))
	info.add_child(SocialUi.label(tr("Viện binh: Dùng Điểm Thủ Trụ mua Boss Đồng Minh (Thiên Vương, Nga Mi, Võ Đang...)."), SocialUi.LABEL_BLUE, 13))
	info.add_child(SocialUi.label(tr("Phần thưởng: EXP & Vàng nhân theo số ải vượt qua, Sát Thủ Giản, Lệnh Bài Phong Lăng Độ."), SocialUi.GOLD, 13))

	box.add_child(SocialUi.divider())

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	var play_btn := SocialUi.stone_button(tr("Vào Khiêu Chiến (200 Đợt)"), Vector2(240, 44))
	play_btn.pressed.connect(func() -> void:
		_play(map_entry)
	)
	row.add_child(play_btn)

## Thẻ Vượt Ải Giang Hồ (10 Bàn chơi kinh điển có ảnh thumbnail xem trước đầy đủ)
func _build_stages_challenge(parent: Control) -> void:
	var card := GameUi.panel(GameUi.PANEL)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(SocialUi.label(tr("Thập Nhị Đại Vượt Ải — Khiêu Chiến Sơn Môn (1x - 12x)"), SocialUi.TITLE, 20, HORIZONTAL_ALIGNMENT_CENTER))
	var desc := SocialUi.label(tr("Hành trình vượt qua 12 ải giang hồ liên hoàn (từ 1x đến 12x). Mỗi ải tương ứng với một bản đồ ngoài trời và hệ thống quái đặc trưng của bản đồ đó."), SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	box.add_child(SocialUi.divider())

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 16)
	box.add_child(middle)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(info)

	var hub := _get_hub()
	var stages_arr: Array[StageData] = []
	if GameManager != null and GameManager.has_method("get_all_stages"):
		stages_arr = GameManager.get_all_stages()
	if stages_arr.is_empty() and hub and "stages" in hub:
		stages_arr = hub.stages
	var total_stages: int = stages_arr.size() if not stages_arr.is_empty() else 12
	var current_stage_idx: int = clampi(_profile.stages_cleared if _profile else 0, 0, total_stages - 1)
	var map_dir_current := "res://world/maps/map_20"
	var preview_stage_name := tr("Màn %d (Đang mở khóa)") % (current_stage_idx + 1)
	if current_stage_idx < stages_arr.size():
		var st: StageData = stages_arr[current_stage_idx]
		preview_stage_name = tr(st.stage_name)
		if st.vltk_map_id > 0:
			map_dir_current = "res://world/maps/map_%d" % st.vltk_map_id

	var map_frame := _minimap_frame({"name": preview_stage_name, "dir": map_dir_current})
	map_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(map_frame)

	info.add_child(SocialUi.label(tr("Bàn hiện tại: %s") % preview_stage_name, SocialUi.GOLD, 15))
	var cleared_cnt: int = _profile.stages_cleared if _profile else 0
	info.add_child(SocialUi.label(tr("Tiến độ: Đã vượt %d/%d bàn") % [cleared_cnt, total_stages], SocialUi.LABEL_BLUE, 14))
	if AccountApi.is_gm():
		info.add_child(SocialUi.label(tr("✦ Quyền Admin: Mở khóa toàn bộ %d bàn chơi (chọn trong danh sách)") % total_stages, SocialUi.GOLD, 13))
	info.add_child(SocialUi.label(tr("Phần thưởng: Điểm kinh nghiệm, Trang bị, Huyền Tinh và mở khóa các bàn chơi mới."), SocialUi.TEXT, 13))

	box.add_child(SocialUi.divider())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	var select_btn := SocialUi.stone_button(tr("Chọn Bàn (Danh Sách Có Ảnh)"), Vector2(230, 44))
	select_btn.pressed.connect(func() -> void:
		var parent_node := _get_hub()
		var hub_stages: Array[StageData] = []
		if GameManager != null and GameManager.has_method("get_all_stages"):
			hub_stages = GameManager.get_all_stages()
		if hub_stages.is_empty() and parent_node and "stages" in parent_node:
			hub_stages = parent_node.stages
		var play_cb: Callable = _on_play
		close_requested.emit()
		if parent_node != null and is_instance_valid(parent_node):
			StageSelectScreen.open(parent_node, _profile, hub_stages, func(selected_stage: StageData) -> void:
				var entry := {"stage": selected_stage, "name": selected_stage.stage_name}
				if play_cb.is_valid():
					play_cb.call(entry)
				elif parent_node != null and parent_node.has_method("_enter_field_map"):
					parent_node._enter_field_map(entry)
			, func() -> void: pass)
	)
	row.add_child(select_btn)

	var next_btn := SocialUi.stone_button(tr("Vào Bàn %d") % (current_stage_idx + 1), Vector2(170, 44))
	next_btn.pressed.connect(func() -> void:
		var parent_node := _get_hub()
		var hub_stages: Array[StageData] = []
		if GameManager != null and GameManager.has_method("get_all_stages"):
			hub_stages = GameManager.get_all_stages()
		if hub_stages.is_empty() and parent_node and "stages" in parent_node:
			hub_stages = parent_node.stages
		if current_stage_idx < hub_stages.size():
			var selected_stage: StageData = hub_stages[current_stage_idx]
			_play({"stage": selected_stage, "name": selected_stage.stage_name})
	)
	row.add_child(next_btn)

func _build_time_challenge(parent: Control) -> void:
	var r := TimeChallenge.rules()
	var card := GameUi.panel(GameUi.PANEL)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	## Bố cục: tiêu đề + lời NPC trải ngang cả thẻ; giữa là luật chơi (trái) + mini map map ải 480 (phải, căn giữa dọc);
	## dưới cùng 2 nút căn giữa thẻ.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(SocialUi.label(tr("Thách Thức Thời Gian"), SocialUi.TITLE, 20, HORIZONTAL_ALIGNMENT_CENTER))
	var quote := SocialUi.label(tr("Nhiếp Thí Trần: \"Hãy tiếp nhận nhiệm vụ thách thức thời gian để thể nghiệm sức mạnh đồng đội và khả năng sát thủ của mình.\""),
			SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quote)
	box.add_child(SocialUi.divider())
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 16)
	box.add_child(middle)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(info)
	var map_frame := _minimap_frame(TimeChallenge.map_entry())
	map_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(map_frame)
	var lines := [
		tr("Vượt qua 28 ải trong %d phút: hết quái ải này mới ra ải sau; 12 ải có boss, ải 28 là đại boss Độc Cô Quỷ Kiếm.") % int(int(r.get("time_limit_sec", 1800)) / 60.0),
		tr("Điều kiện: cấp từ %d · phí %s lượng + 1 %s · mỗi ngày %d lượt.") % [int(r.get("min_level", 80)), TimeChallenge._money(int(r.get("cost", 150000))), tr(TimeChallenge.ENTRY_ITEM_NAME), int(r.get("runs_per_day", 2))],
		tr("Hoàn thành: thưởng kinh nghiệm, ghi thời gian vượt ải."),
	]
	for t in lines:
		var l := SocialUi.label(t, SocialUi.TEXT, 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(l)
	var best := TimeChallenge.best_time(_profile)
	info.add_child(SocialUi.label(tr("Kỷ lục của bạn: %s   ·   Hôm nay đã tham gia: %d/%d") % [
			TimeChallenge.format_time(best) if best > 0 else tr("chưa có"), TimeChallenge.runs_today(_profile), int(r.get("runs_per_day", 2))],
			SocialUi.LABEL_BLUE, 14))
	var reason := TimeChallenge.check_entry(_profile)
	var status := SocialUi.label(tr(reason) if reason != "" else tr("Đủ điều kiện tham gia."), SocialUi.WARN if reason != "" else SocialUi.LABEL_BLUE, 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(status)
	box.add_child(SocialUi.divider())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var solo := SocialUi.stone_button(tr("Khiêu chiến một mình"), Vector2(200, 44))
	solo.disabled = reason != ""
	solo.pressed.connect(_start_time_challenge)
	row.add_child(solo)

	if best > 0:
		var sweep_btn := SocialUi.stone_button(tr("⚡ Càn Quét Nhanh"), Vector2(170, 44))
		sweep_btn.disabled = reason != ""
		sweep_btn.tooltip_text = tr("Nhận ngay phần thưởng vượt ải mà không cần đánh tay (đã hoàn thành trước đó)")
		sweep_btn.pressed.connect(_sweep_time_challenge)
		row.add_child(sweep_btn)

	var team := SocialUi.stone_button(tr("Chờ tổ đội"), Vector2(140, 44))
	team.disabled = false
	team.tooltip_text = tr("Khiêu chiến cùng tổ đội tối đa 8 người (phòng chờ và danh sách phòng)")
	team.pressed.connect(_open_time_challenge_party)
	row.add_child(team)

func _open_time_challenge_party() -> void:
	var win_script: GDScript = load("res://ui/events/time_challenge_window.gd")
	win_script.open(self, _profile, _play)

func _start_time_challenge() -> void:
	var reason := TimeChallenge.check_entry(_profile)
	if reason != "":
		_select_tab(2)
		return
	SocialWindow.confirm(self, "Thách Thức Thời Gian",
			"Tham gia khiêu chiến? Tốn %s lượng, 1 %s và 1 lượt hôm nay." % [
				TimeChallenge._money(int(TimeChallenge.rules().get("cost", 150000))), TimeChallenge.ENTRY_ITEM_NAME],
			func() -> void:
				if not TimeChallenge.pay_entry(_profile):
					_select_tab(2)
					return
				_play(TimeChallenge.map_entry()))

func _sweep_time_challenge() -> void:
	var reason := TimeChallenge.check_entry(_profile)
	if reason != "":
		_select_tab(2)
		return
	SocialWindow.confirm(self, "Càn Quét Vượt Ải",
			"Càn quét 28 ải nhận ngay phần thưởng? Tốn %s lượng, 1 %s và 1 lượt hôm nay." % [
				TimeChallenge._money(int(TimeChallenge.rules().get("cost", 150000))), TimeChallenge.ENTRY_ITEM_NAME],
			func() -> void:
				var res := TimeChallenge.sweep(_profile)
				if res.get("ok", false):
					var hub := _get_hub()
					if hub and hub.has_method("_show_toast"):
						hub._show_toast("⚡ Càn quét thành công! Nhận +%d EXP." % int(res.get("exp", 0)))
				_select_tab(2)
	)

# ---------------------------------------------------------------- tab Ải (Ải Thuyền Phong Lăng Độ)

func _build_phong_lang_do(parent: Control) -> void:
	var card := GameUi.panel(GameUi.PANEL)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(SocialUi.label(tr("Phong Lăng Độ — Bến Thuyền Vượt Sông"), SocialUi.TITLE, 20, HORIZONTAL_ALIGNMENT_CENTER))
	var quote := SocialUi.label(tr("Thuyền Phu: \"Sóng to gió lớn, Thủy Tặc Hoàng Hà cực kỳ hung hãn. Đại hiệp đã chuẩn bị kỹ càng để vượt sông chưa?\""),
			SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quote)
	box.add_child(SocialUi.divider())

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 16)
	box.add_child(middle)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(info)

	var map_frame := _minimap_frame(PhongLangDoChallenge.map_entry())
	map_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(map_frame)

	var lines := [
		tr("Vượt sông Hoàng Hà trong 10 phút: tiêu diệt 3 đợt Thủy Tặc & Đại Boss Hoàng Kim Yên Hiểu Trái."),
		tr("Điều kiện: Cấp từ %d · Phí: 1 %s (hoặc %s lượng) · Mỗi ngày %d lượt.") % [
			PhongLangDoChallenge.MIN_LEVEL,
			tr(PhongLangDoChallenge.ENTRY_ITEM_NAME),
			PhongLangDoChallenge._money(PhongLangDoChallenge.ENTRY_FEE),
			PhongLangDoChallenge.RUNS_PER_DAY
		],
		tr("Phần thưởng: Kinh nghiệm dồi dào, Phúc duyên, Danh vọng, Thủy Tinh, Huyền Tinh và Trang bị Hoàng Kim."),
	]
	for t in lines:
		var l := SocialUi.label(t, SocialUi.TEXT, 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(l)

	var item_cnt := PhongLangDoChallenge.entry_item_count(_profile)
	var fee_str := tr("1 Lệnh bài") if item_cnt > 0 else tr("%s lượng") % PhongLangDoChallenge._money(PhongLangDoChallenge.ENTRY_FEE)
	var best := PhongLangDoChallenge.best_time(_profile)
	info.add_child(SocialUi.label(tr("Lệnh bài hiện có: %d   ·   Hôm nay đã đi: %d/%d   ·   Kỷ lục: %s") % [
			item_cnt,
			PhongLangDoChallenge.runs_today(_profile),
			PhongLangDoChallenge.RUNS_PER_DAY,
			PhongLangDoChallenge.format_time(best) if best > 0 else tr("chưa có")
		],
		SocialUi.LABEL_BLUE, 14))

	var reason := PhongLangDoChallenge.check_entry(_profile)
	var status_text := tr(reason) if reason != "" else tr("Đủ điều kiện lên thuyền (thủ tục: nộp %s).") % fee_str
	var status := SocialUi.label(status_text, SocialUi.WARN if reason != "" else SocialUi.LABEL_BLUE, 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(status)

	box.add_child(SocialUi.divider())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	var board_btn := SocialUi.stone_button(tr("Lên thuyền xuất bến"), Vector2(200, 44))
	board_btn.disabled = reason != ""
	board_btn.pressed.connect(_start_phong_lang_do)
	row.add_child(board_btn)

	if best > 0:
		var sweep_btn := SocialUi.stone_button(tr("⚡ Ủy Thác Vượt Sông"), Vector2(180, 44))
		sweep_btn.disabled = reason != ""
		sweep_btn.tooltip_text = tr("Ủy thác thuyền vượt sông Hoàng Hà, nhận ngay phần thưởng mà không cần đánh tay")
		sweep_btn.pressed.connect(_sweep_phong_lang_do)
		row.add_child(sweep_btn)

func _start_phong_lang_do() -> void:
	var reason := PhongLangDoChallenge.check_entry(_profile)
	if reason != "":
		_select_tab(2)
		return
	var item_cnt := PhongLangDoChallenge.entry_item_count(_profile)
	var cost_desc := "1 %s" % PhongLangDoChallenge.ENTRY_ITEM_NAME if item_cnt > 0 else "%s lượng vé thuyền" % PhongLangDoChallenge._money(PhongLangDoChallenge.ENTRY_FEE)
	SocialWindow.confirm(self, "Phong Lăng Độ",
			"Lên thuyền vượt sông Hoàng Hà? Thủ tục sẽ thu %s và tính 1 lượt hôm nay." % cost_desc,
			func() -> void:
				if not PhongLangDoChallenge.pay_entry(_profile):
					_select_tab(2)
					return
				_play(PhongLangDoChallenge.map_entry()))

func _sweep_phong_lang_do() -> void:
	var reason := PhongLangDoChallenge.check_entry(_profile)
	if reason != "":
		_select_tab(2)
		return
	var item_cnt := PhongLangDoChallenge.entry_item_count(_profile)
	var cost_desc := "1 %s" % PhongLangDoChallenge.ENTRY_ITEM_NAME if item_cnt > 0 else "%s lượng vé thuyền" % PhongLangDoChallenge._money(PhongLangDoChallenge.ENTRY_FEE)
	SocialWindow.confirm(self, "Ủy Thác Phong Lăng Độ",
			"Ủy thác thuyền vượt sông Hoàng Hà? Thủ tục sẽ thu %s và tính 1 lượt hôm nay để nhận ngay phần thưởng." % cost_desc,
			func() -> void:
				var res := PhongLangDoChallenge.sweep(_profile)
				if res.get("ok", false):
					var hub := _get_hub()
					if hub and hub.has_method("_show_toast"):
						hub._show_toast("⚡ Ủy thác thành công! +%d EXP, +100 Danh vọng, +100 Phúc duyên!" % int(res.get("exp", 0)))
				_select_tab(2)
	)

# ---------------------------------------------------------------- tab Ải (Tống Kim LOL)

func _build_tong_kim_lol(parent: Control) -> void:
	var card := GameUi.panel(GameUi.PANEL)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_minimap_frame({"dir": TongKimLolRules.MAP_DIR}))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(SocialUi.label(tr("Ải Tống Kim LOL (MOBA 1v1 - 5v5)"), SocialUi.TITLE, 18))
	var desc := SocialUi.label(tr("Chiến trường MOBA bảo vệ Tướng Soái, công phá cổng thành, diệt 3 đường lính và Boss Hoàng Kim. Tặng 100 điểm tiềm năng, mở full skill phái, thăng cấp 1-15 trong trận và thưởng x10 EXP thực tế!"), SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)

	var enter_btn := SocialUi.stone_button(tr("Vào Sảnh Chờ Tống Kim LOL"), Vector2(230, 40))
	enter_btn.pressed.connect(func() -> void:
		var hub := _get_hub()
		if hub:
			close_requested.emit()
			var win := PkWindow.open(hub, _profile, _on_play)
			if win:
				win._select_mode(PkRules.Mode.TONG_KIM_LOL)
	)
	info.add_child(enter_btn)

# ---------------------------------------------------------------- tab Ải (Chiến Trường Tống Kim)

func _build_battle(parent: Control) -> void:
	_battle_buttons.clear()
	var card := GameUi.panel(GameUi.PANEL)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_minimap_frame({"dir": _battle_dir(int(_battle.get("map_id", 378)))}))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(SocialUi.label(tr(BATTLE_NAME), SocialUi.TITLE, 18))
	var rules := SocialUi.label(tr("Chọn phe Tống hoặc Kim. Báo danh xong chờ trong doanh trại (chuẩn bị) tới giờ khai chiến mới được ra trận. Hạ người phe kia được điểm; chết về hậu doanh phe mình. Hết giờ phe nhiều điểm hơn thắng."), SocialUi.MUTED, 13)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(rules)
	_battle_status = SocialUi.label(tr("Đang tải…"), SocialUi.LABEL_BLUE, 14)
	info.add_child(_battle_status)
	_battle_sides = SocialUi.label("", SocialUi.TEXT, 15)
	info.add_child(_battle_sides)
	_battle_msg = SocialUi.label("", SocialUi.WARN, 13)
	_battle_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_battle_msg)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	info.add_child(buttons)
	for side in BattleServer.SIDES:
		var b := SocialUi.stone_button(tr("Vào phe %s") % tr(BattleServer.SIDE_NAMES[side]), Vector2(140, 40))
		b.pressed.connect(_join_battle.bind(side))
		buttons.add_child(b)
		_battle_buttons[side] = b

	var skirmish_btn := SocialUi.stone_button(tr("⚔️ Đấu Tập (Bot AI)"), Vector2(170, 40))
	skirmish_btn.tooltip_text = tr("Vào ngay chiến trường Tống Kim MOBA đánh với Bot AI tự động mọi lúc mọi nơi")
	skirmish_btn.pressed.connect(func() -> void:
		var hub := _get_hub()
		if hub:
			close_requested.emit()
			var win := PkWindow.open(hub, _profile, _on_play)
			if win:
				win._select_mode(PkRules.Mode.TONG_KIM_LOL)
	)
	buttons.add_child(skirmish_btn)
	if _battle_timer == null:
		_battle_timer = Timer.new()
		_battle_timer.wait_time = 1.0
		_battle_timer.timeout.connect(_battle_tick)
		add_child(_battle_timer)
		_battle_timer.start()
	_battle_poll_acc = BATTLE_POLL
	_battle_tick()

## Khung ảnh mini map của 1 map (entry có "dir") — dùng chung cho thẻ map luyện công, Thách Thức Thời Gian, Tống Kim.
static func _minimap_frame(entry: Dictionary) -> Control:
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = THUMB_SIZE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := _crop_dark(MapCatalog.minimap_texture(entry))
	thumb.texture = tex
	var frame := GameUi.panel(GameUi.PANEL)
	frame.add_child(thumb)
	if tex == null:
		var empty_lbl := Label.new()
		empty_lbl.text = "🗺 %s" % str(entry.get("name", "Bản Đồ"))
		empty_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", SocialUi.MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 13)
		frame.add_child(empty_lbl)
	return frame

## Ảnh mini map xuất từ tool có phần nền đen ngoài vùng map (map nhỏ chỉ chiếm 1 góc ảnh) — cắt theo khung bao vùng có
## hình (dò thưa mỗi 4 điểm ảnh) để thẻ không bị 1 mảng đen lớn. Lưu đệm theo ảnh gốc.
static var _cropped: Dictionary = {}

static func _crop_dark(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _cropped.has(tex):
		return _cropped[tex]
	var image := tex.get_image()
	if image == null:
		return tex
	if image.is_compressed():
		image.decompress()
	var lo := Vector2i(image.get_width(), image.get_height())
	var hi := Vector2i(-1, -1)
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).get_luminance() > 0.06:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var out: Texture2D = tex
	if hi.x >= 0:
		var rect := Rect2i(lo, hi - lo + Vector2i(4, 4)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		if rect.size != image.get_size():
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(rect)
			out = atlas
	_cropped[tex] = out
	return out

static func _battle_dir(map_id: int) -> String:
	return "res://world/maps/map_%d" % map_id

func _cooldown_left() -> float:
	return maxf(0.0, BATTLE_COOLDOWN - (Time.get_ticks_msec() - _battle_clicked_at) / 1000.0)

## Mỗi giây: cập nhật đếm ngược nút; mỗi BATTLE_POLL giây hỏi lại trạng thái trận.
func _battle_tick() -> void:
	if _tab != 2 or _battle_status == null or not is_instance_valid(_battle_status):
		return
	_battle_poll_acc += 1.0
	if _battle_poll_acc >= BATTLE_POLL:
		_battle_poll_acc = 0.0
		_fetch_battle()
	_render_battle()

func _fetch_battle() -> void:
	if not AccountApi.is_logged_in():
		_battle = {}
		return
	var r: Dictionary = await AccountApi.battle(ServerSelectScreen.selected_server_id)
	if not is_inside_tree():
		return
	_battle = r.data if r.ok and r.data is Dictionary else {}
	_render_battle()

func _render_battle() -> void:
	if _battle_status == null or not is_instance_valid(_battle_status):
		return
	var cd := _cooldown_left()
	var open := bool(_battle.get("open", false))
	if not AccountApi.is_logged_in():
		_battle_status.text = "Chiến trường chỉ có khi chơi trên máy chủ (đăng nhập tài khoản)."
		_battle_sides.text = ""
	elif not open:
		_battle_status.text = "Chiến trường chưa mở (máy chủ chiến trường không hoạt động)."
		_battle_sides.text = ""
	else:
		var left := int(_battle.get("phase_left", 0))
		@warning_ignore("integer_division")
		var minutes := left / 60
		_battle_status.text = "%s · còn %02d:%02d · cấp từ %d" % [BATTLE_PHASES.get(str(_battle.get("phase", "")), "?"), minutes, left % 60,
			int(_battle.get("min_level", 0))]
		_battle_sides.text = "Phe Tống: %d người · %d điểm        Phe Kim: %d người · %d điểm" % [int(_battle.get("song", 0)),
			int(_battle.get("song_points", 0)), int(_battle.get("jin", 0)), int(_battle.get("jin_points", 0))]
	for side in _battle_buttons:
		var b: Button = _battle_buttons[side]
		b.disabled = cd > 0.0 or not open
		b.text = "Chờ %ds" % ceili(cd) if cd > 0.0 else "Vào phe %s" % BattleServer.SIDE_NAMES[side]

## Bấm chọn phe: luôn tính lượt chờ BATTLE_COOLDOWN giây. Kiểm tra trước ở đây (lệch quân, cấp, trận kết thúc) — server kiểm tra lại khi vào.
func _join_battle(side: String) -> void:
	if _cooldown_left() > 0.0:
		return
	_battle_clicked_at = Time.get_ticks_msec()
	_battle_msg.text = ""
	if not bool(_battle.get("open", false)):
		_battle_msg.text = "Chiến trường chưa mở."
	elif str(_battle.get("phase", "")) == "ended":
		_battle_msg.text = "Trận này đã kết thúc, xin chờ trận sau."
	elif not AccountApi.is_gm() and _profile and _profile.level < int(_battle.get("min_level", 0)):
		_battle_msg.text = "Cấp %d trở lên mới được vào chiến trường." % int(_battle.get("min_level", 0))
	else:
		var other := "jin" if side == "song" else "song"
		var mine := int(_battle.get(side, 0))
		var theirs := int(_battle.get(other, 0))
		var balance := int(_battle.get("balance", BattleServer.BALANCE))
		if mine - theirs >= balance:
			_battle_msg.text = "Phe %s đang đông hơn phe %s %d người — không thể vào lúc này, hãy chọn phe %s hoặc chờ thêm." % [
				BattleServer.SIDE_NAMES[side], BattleServer.SIDE_NAMES[other], mine - theirs, BattleServer.SIDE_NAMES[other]]
		else:
			var map_id := int(_battle.get("map_id", 378))
			_play({"id": map_id, "name": BATTLE_NAME, "dir": _battle_dir(map_id), "battle": {"side": side, "server": {
				"host": str(_battle.get("host", "127.0.0.1")), "port": int(_battle.get("port", 7787)),
				"ws_url": str(_battle.get("ws_url", "")), "name": BATTLE_NAME}}})
			return
	_render_battle()

# ---------------------------------------------------------------- tab Thường

func _build_normal() -> void:
	var tier_scroll := ScrollContainer.new()
	tier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tier_scroll.custom_minimum_size = Vector2(110, LIST_SIZE.y)
	var tiers := VBoxContainer.new()
	tiers.add_theme_constant_override("separation", 6)
	tiers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_scroll.add_child(tiers)
	for t in range(1, MapCatalog.TIER_COUNT + 1):
		var count := MapCatalog.in_tier(t).size()
		var b := GameUi.button("%dx" % t if count > 0 else "%dx  —" % t, GameUi.TAB)
		b.custom_minimum_size.y = 34
		b.pressed.connect(_select_tier.bind(t))
		tiers.add_child(b)
		_tier_buttons.append(b)
	_content.add_child(tier_scroll)
	TouchScrollHelperScript.attach(tier_scroll, tier_scroll)

	var list_scroll := ScrollContainer.new()
	list_scroll.name = "MapList"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = LIST_SIZE
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(list_scroll)
	_select_tier(_tier)
	## Danh sách mốc dài hơn khung -> cuộn tới mốc đang chọn (sau khi khung đã xếp chỗ).
	var active: Button = _tier_buttons[_tier - 1]
	(func() -> void:
		if is_instance_valid(tier_scroll) and is_instance_valid(active):
			tier_scroll.ensure_control_visible(active)).call_deferred()

func _select_tier(t: int) -> void:
	_tier = t
	for k in _tier_buttons.size():
		GameUi.set_active(_tier_buttons[k], k + 1 == t)
	var scroll := _content.get_node_or_null("MapList") as ScrollContainer
	if scroll == null:
		return
	for c in scroll.get_children():
		if c is Control:
			c.queue_free()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	TouchScrollHelperScript.attach(scroll, scroll)
	var maps := MapCatalog.in_tier(t)
	if maps.is_empty():
		list.add_child(SocialUi.label("Chưa có bản đồ %dx." % t, SocialUi.MUTED, 14))
		return
	for m in maps:
		list.add_child(_map_card(m))

func _map_card(m: Dictionary) -> Control:
	var card := GameUi.panel(GameUi.PANEL)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	row.add_child(_minimap_frame(m))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(SocialUi.label(str(m["name"]), SocialUi.TITLE, 17))
	info.add_child(SocialUi.label("%s: %d  ·  %d %s" % [tr("Cấp quái"), int(m["level"]), int(m.get("monster_count", 0)), tr("quái")], SocialUi.LABEL_BLUE, 13))
	var names: Array[String] = []
	for mon in m.get("monsters", []):
		names.append("%s (Lv%d)" % [mon["name"], int(mon["level"])])
	var mons := SocialUi.label(tr("Quái:") + " " + ", ".join(names), SocialUi.TEXT, 13)
	mons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(mons)

	var playable := MapCatalog.is_playable(m)
	var play := SocialUi.stone_button(tr("Vào") if playable else tr("Chưa có"), Vector2(96, 40))
	play.disabled = not playable
	play.tooltip_text = "" if playable else tr("Bản đồ này chưa được xuất (tools/export_training_maps.py)")
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_enter_field.bind(m))
	row.add_child(play)
	return card

# ---------------------------------------------------------------- tab Địa Ngục

const HELL_CARD := Color(0.120, 0.030, 0.028)
const HELL_BORDER := Color(0.55, 0.10, 0.08)
const HELL_HOT := Color(0.95, 0.22, 0.12)       ## viền / chữ cảnh báo
const HELL_TITLE := Color(1.0, 0.42, 0.22)
const HELL_TEXT := Color(0.90, 0.78, 0.72)
const HELL_DIM := Color(0.55, 0.40, 0.38)
const STAR_ON := Color(1.0, 0.80, 0.25)
const STAR_OFF := Color(0.30, 0.20, 0.19)
const HELL_RANKS := ["", "Khó", "Rất khó", "Ác mộng", "Luyện ngục", "Tuyệt vọng"]
const HELL_RANK_COLORS := [Color.WHITE, Color(1.0, 0.62, 0.25), Color(1.0, 0.45, 0.20), Color(0.98, 0.28, 0.18),
	Color(0.90, 0.12, 0.12), Color(0.80, 0.05, 0.30)]

var _hell_tier: int = MapCatalog.HELL_TIERS[0]
var _hell_tier_buttons: Array[Button] = []
## Số sao đã chọn cho từng map (giữ khi đóng / mở lại cửa sổ).
static var _hell_stars: Dictionary = {}

func _build_hell() -> void:
	_hell_tier_buttons.clear()
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(page)
	page.add_child(_hell_banner())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	var tiers := VBoxContainer.new()
	tiers.add_theme_constant_override("separation", 8)
	tiers.custom_minimum_size.x = 110
	row.add_child(tiers)
	for t in MapCatalog.HELL_TIERS:
		var b := _hell_button("%dx" % t, Vector2(110, 52), 20)
		b.toggle_mode = true
		b.pressed.connect(_select_hell_tier.bind(t))
		tiers.add_child(b)
		_hell_tier_buttons.append(b)
	tiers.add_child(SocialUi.label("Quái cấp\n%d - %d" % [MapCatalog.hell_level(MapCatalog.HELL_TIERS[0]),
		MapCatalog.hell_level(MapCatalog.HELL_TIERS[-1])], HELL_DIM, 12, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.name = "HellList"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(LIST_SIZE.x, LIST_SIZE.y - 96)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)
	_select_hell_tier(_hell_tier)

## Băng rôn tab Tinh anh: nền tím thẫm viền tím sáng, tiêu đề lớn + luật sao.
func _hell_banner() -> Control:
	var panel := PanelContainer.new()
	var style := GameUi.box(Color(0.12, 0.03, 0.16), Color(0.70, 0.30, 0.95), 8, 2, 10)
	style.shadow_color = Color(0.6, 0.15, 0.85, 0.35)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var title := SocialUi.label(tr("⚔  TINH ANH  ⚔"), Color(0.88, 0.50, 1.0), 26, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_outline_color", Color(0.30, 0.05, 0.45))
	title.add_theme_constant_override("outline_size", 6)
	v.add_child(title)
	v.add_child(SocialUi.label(tr("Màn chơi TINH ANH — độ khó cao dành cho cao thủ."), Color(0.85, 0.60, 1.0), 13, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(SocialUi.label(tr("Mỗi ★: máu, sát thương, tỉ lệ rơi đồ magic của quái × số sao  ·  5★: 100% đồ rơi ra đủ dòng (thuộc tính ngẫu nhiên)"),
		HELL_TEXT, 12, HORIZONTAL_ALIGNMENT_CENTER))
	return panel

func _select_hell_tier(t: int) -> void:
	_hell_tier = t
	for k in _hell_tier_buttons.size():
		_hell_tier_buttons[k].set_pressed_no_signal(MapCatalog.HELL_TIERS[k] == t)
	var scroll := _content.find_child("HellList", true, false) as ScrollContainer
	if scroll == null:
		return
	for c in scroll.get_children():
		if c is Control:
			c.queue_free()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	TouchScrollHelperScript.attach(scroll, scroll)
	var maps := MapCatalog.hell_maps(t)
	if maps.is_empty():
		list.add_child(SocialUi.label(tr("Chưa có bản đồ Tinh anh %dx.") % t, HELL_DIM, 14))
		return
	for m in maps:
		list.add_child(_hell_card(m))

## Thẻ 1 map Tinh anh: ảnh map phủ tím, tên + bậc khó, hàng 5 sao bấm chọn, hệ số theo sao, nút Khiêu chiến.
## Chọn sao càng cao thẻ càng tím, viền càng dày.
func _hell_card(m: Dictionary) -> Control:
	var id := int(m["id"])
	var card := PanelContainer.new()
	var style := GameUi.box(Color(0.10, 0.03, 0.14), Color(0.55, 0.20, 0.70), 8, 1, 10)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var frame := _minimap_frame(m)
	frame.add_theme_stylebox_override("panel", GameUi.box(Color.BLACK, Color(0.55, 0.20, 0.70), 4, 1, 2))
	var tint := ColorRect.new()
	tint.color = Color(0.40, 0.05, 0.50, 0.35)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tint)
	var skull := SocialUi.label("⚔", Color(0.88, 0.50, 1.0), 22, HORIZONTAL_ALIGNMENT_RIGHT)
	skull.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(skull)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	info.add_child(head)
	head.add_child(SocialUi.label(tr(str(m["name"])), HELL_TITLE, 18))
	var rank := SocialUi.label("", HELL_HOT, 13)
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rank)
	info.add_child(SocialUi.label(tr("Quái cấp %d  ·  %d quái") % [int(m["level"]), int(m.get("monster_count", 0))], HELL_TEXT, 13))
	var star_row := HBoxContainer.new()
	star_row.add_theme_constant_override("separation", 2)
	info.add_child(star_row)
	var star_buttons: Array[Button] = []
	for k in MapCatalog.HELL_MAX_STARS:
		var b := Button.new()
		b.text = "★"
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(34, 32)
		b.add_theme_font_size_override("font_size", 26)
		b.tooltip_text = tr("%d sao — %s") % [k + 1, tr(HELL_RANKS[k + 1])]
		star_row.add_child(b)
		star_buttons.append(b)
	var effect := SocialUi.label("", HELL_TEXT, 13)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(effect)
	if _profile and _profile.level < int(m["level"]) - 10:
		info.add_child(SocialUi.label(tr("⚠ Cấp của bạn quá thấp — khuyến nghị cấp %d trở lên.") % (int(m["level"]) - 10), HELL_HOT, 12))

	var play := _hell_button(tr("Khiêu chiến"), Vector2(120, 48), 16)
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play.disabled = not MapCatalog.is_playable(m)
	row.add_child(play)

	var paint := func(n: int) -> void:
		for k in star_buttons.size():
			var c := STAR_ON if k < n else STAR_OFF
			for st in ["font_color", "font_pressed_color", "font_focus_color"]:
				star_buttons[k].add_theme_color_override(st, c)
			star_buttons[k].add_theme_color_override("font_hover_color", c.lightened(0.25))
		rank.text = "· %s" % tr(HELL_RANKS[n])
		rank.add_theme_color_override("font_color", HELL_RANK_COLORS[n])
		effect.text = tr("Máu ×%d  ·  Sát thương ×%d  ·  Rơi đồ ×%d  ·  Đủ dòng %d%%") % [n, n, n, n * 20]
		style.bg_color = Color(0.10 + n * 0.035, 0.025, 0.025)
		style.border_color = (HELL_RANK_COLORS[n] as Color).darkened(0.25)
		@warning_ignore("integer_division")
		style.set_border_width_all(1 + n / 2)
	for k in star_buttons.size():
		star_buttons[k].pressed.connect(func() -> void:
			_hell_stars[id] = k + 1
			paint.call(k + 1))
	play.pressed.connect(func() -> void: _enter_field(MapCatalog.hell_entry(m, int(_hell_stars.get(id, 1)))))
	paint.call(int(_hell_stars.get(id, 1)))
	return card

## Nút tông tím (cột 10x / 11x / 12x, nút Khiêu chiến).
func _hell_button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	var pressed := GameUi.box(Color(0.35, 0.08, 0.45), STAR_ON, 6, 2, 8)
	b.add_theme_stylebox_override("normal", GameUi.box(Color(0.20, 0.04, 0.28), Color(0.55, 0.20, 0.70), 6, 1, 8))
	b.add_theme_stylebox_override("hover", GameUi.box(Color(0.28, 0.06, 0.38), Color(0.75, 0.30, 0.95), 6, 1, 8))
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", GameUi.box(Color(0.12, 0.05, 0.15), Color(0.25, 0.1, 0.25), 6, 1, 8))
	b.add_theme_color_override("font_color", Color(0.95, 0.85, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", STAR_ON)
	b.add_theme_color_override("font_hover_pressed_color", STAR_ON)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.3, 0.4))
	return b

# ---------------------------------------------------------------- phòng train chung

## Đã đăng nhập vào nhân vật thì map luyện công / Địa Ngục chạy trên field server (train chung được).
static func _online() -> bool:
	return AccountApi.is_logged_in() and SaveManager.online_character_id != 0

func _build_join_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_join_row = row
	body.add_child(row)
	row.add_child(SocialUi.label(tr("ID phòng:"), SocialUi.LABEL_BLUE, 14))
	_join_edit = SocialUi.line_edit(tr("6 số ID phòng của bạn bè"))
	_join_edit.max_length = 6
	_join_edit.custom_minimum_size.x = 300
	_join_edit.text_submitted.connect(func(_t: String) -> void: _join_by_id())
	row.add_child(_join_edit)
	_join_button = SocialUi.stone_button(tr("Vào chơi chung"), Vector2(160, 38))
	_join_button.pressed.connect(_join_by_id)
	row.add_child(_join_button)
	_join_msg = SocialUi.label("", SocialUi.MUTED, 12)
	_join_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_join_msg)
	if not _online():
		_join_edit.editable = false
		_join_button.disabled = true
		_join_msg.text = tr("Đăng nhập tài khoản để train chung (chơi một mình không có ID phòng).")

## Địa chỉ field server + danh sách phòng; {} nếu field server không chạy.
func _fetch_field() -> Dictionary:
	var r: Dictionary = await AccountApi.field(ServerSelectScreen.selected_server_id)
	if not r.ok or not r.data is Dictionary or not bool(r.data.get("open", false)):
		return {}
	return r.data

## Địa chỉ field server: gốc danh sách = tiến trình vắng nhất (tạo phòng mới); 1 phòng = tiến trình đang giữ phòng đó ("addr").
static func _field_server(st: Dictionary, room := {}) -> Dictionary:
	if not room.is_empty() and str(room.get("addr", "")) != "":
		return {"host": str(room["addr"]), "port": int(room.get("port", 7807)), "ws_url": str(room.get("ws_url", "")), "name": "Phòng train chung"}
	return {"host": str(st.get("host", "127.0.0.1")), "port": int(st.get("port", 7807)), "ws_url": str(st.get("ws_url", "")),
		"name": "Phòng train chung"}

## Bấm Vào / Khiêu chiến: đã đăng nhập -> tạo phòng train chung; field server không chạy thì hỏi chơi một mình.
func _enter_field(m: Dictionary) -> void:
	if not _online():
		_play(m)
		return
	var st := await _fetch_field()
	if not is_inside_tree():
		return
	if st.is_empty():
		SocialWindow.confirm(self, "Phòng train chung", "Máy chủ phòng train chung chưa mở — vào chơi một mình (không có ID phòng)?",
				func() -> void: _play(m))
		return
	var hell: Dictionary = m.get("hell", {})
	var e := m.duplicate(true)
	e["field"] = {"server": _field_server(st), "action": {"op": "create", "map_id": int(m["id"]), "tier": int(hell.get("tier", 0)),
		"stars": int(hell.get("stars", 0))}}
	_play(e)

## "Vào chơi chung": tra phòng theo ID -> nạp đúng map (Thường / Địa Ngục + số sao của phòng) -> vào phòng.
func _join_by_id() -> void:
	var id := _join_edit.text.strip_edges()
	if id.length() != 6 or not id.is_valid_int():
		_join_msg.text = "ID phòng gồm 6 chữ số."
		return
	_join_button.disabled = true
	_join_msg.text = "Đang tìm phòng #%s…" % id
	var st := await _fetch_field()
	if not is_inside_tree():
		return
	_join_button.disabled = false
	if st.is_empty():
		_join_msg.text = "Máy chủ phòng train chung chưa mở."
		return
	var room: Dictionary = {}
	for r in st.get("rooms", []):
		if r is Dictionary and str(r.get("id", "")) == id:
			room = r
	var reason := ""
	var entry := {} if room.is_empty() else join_entry(room)
	if room.is_empty():
		reason = "Không có phòng #%s (phòng đã đóng hoặc sai ID)." % id
	elif int(room.get("members", 0)) >= int(room.get("max", FieldServer.MAX_MEMBERS)):
		reason = "Phòng #%s đã đủ người." % id
	elif entry.is_empty() or not MapCatalog.is_playable(entry):
		reason = "Máy bạn chưa có bản đồ của phòng #%s." % id
	if reason != "":
		_join_msg.text = reason
		return
	entry["field"] = {"server": _field_server(st, room), "action": {"op": "join", "room": id, "map_id": int(room["map_id"]),
		"tier": int(room.get("tier", 0))}}
	_play(entry)

## Mục map (GameManager.field_map) của 1 phòng trong danh sách /v1/field: map Thường, hoặc map Địa Ngục đúng nhóm + số sao. {} = không có.
static func join_entry(room: Dictionary) -> Dictionary:
	var tier := int(room.get("tier", 0))
	var m := FieldServer.map_entry(int(room.get("map_id", 0)), tier)
	if m.is_empty():
		return {}
	return MapCatalog.hell_entry(m, int(room.get("stars", 1))) if tier != 0 else m.duplicate(true)

func _play(m: Dictionary) -> void:
	close_requested.emit()
	if _on_play.is_valid():
		_on_play.call(m)

# ---------------------------------------------------------------- tab Boss (Đại Hoàng Kim & Tiểu Hoàng Kim)

const BOSS_LIST := [
	# --- Thập Đại Boss Hoàng Kim Môn Phái ---
	{"name": "Huyền Giác Đại Sư", "id": 740, "res": "boss003", "series": "Kim", "series_idx": 0, "sect": "Thiếu Lâm", "level": 95, "map_id": 320, "map_name": "Chân Núi Trường Bạch", "type": "gold"},
	{"name": "Cổ Bách", "id": 566, "res": "boss018", "series": "Kim", "series_idx": 0, "sect": "Thiên Vương", "level": 95, "map_id": 123, "map_name": "Lão Hổ Động", "type": "gold"},
	{"name": "Đường Bất Nhiễm", "id": 741, "res": "boss019", "series": "Mộc", "series_idx": 1, "sect": "Đường Môn", "level": 95, "map_id": 319, "map_name": "Lâm Du Quan", "type": "gold"},
	{"name": "Bạch Doanh Doanh", "id": 742, "res": "boss007", "series": "Mộc", "series_idx": 1, "sect": "Đường Môn", "level": 95, "map_id": 224, "map_name": "Sa Mạc Địa Biểu", "type": "gold"},
	{"name": "Lam Y Y", "id": 582, "res": "boss008", "series": "Mộc", "series_idx": 1, "sect": "Ngũ Độc", "level": 95, "map_id": 75, "map_name": "Xi Vưu Động", "type": "gold"},
	{"name": "Thanh Tiếu Sư Thái", "id": 743, "res": "boss004", "series": "Thủy", "series_idx": 2, "sect": "Nga Mi", "level": 95, "map_id": 321, "map_name": "Trường Bạch Sơn Nam", "type": "gold"},
	{"name": "Hà Linh Phiêu", "id": 568, "res": "boss002", "series": "Thủy", "series_idx": 2, "sect": "Nga Mi", "level": 95, "map_id": 322, "map_name": "Trường Bạch Sơn Bắc", "type": "gold"},
	{"name": "Chung Linh Tú", "id": 567, "res": "boss005", "series": "Thủy", "series_idx": 2, "sect": "Thúy Yên", "level": 95, "map_id": 93, "map_name": "Tiến Cúc Động", "type": "gold"},
	{"name": "Yên Hiểu Trái", "id": 744, "res": "boss023", "series": "Thủy", "series_idx": 2, "sect": "Thúy Yên", "level": 95, "map_id": 337, "map_name": "Thuyền Phong Lăng Độ", "type": "gold"},
	{"name": "Mạnh Thương Lương", "id": 583, "res": "boss012", "series": "Hỏa", "series_idx": 3, "sect": "Cái Bang", "level": 95, "map_id": 225, "map_name": "Sa Mạc Sơn Động 1", "type": "gold"},
	{"name": "Hà Nhân Ngã", "id": 745, "res": "boss013", "series": "Hỏa", "series_idx": 3, "sect": "Cái Bang", "level": 95, "map_id": 226, "map_name": "Sa Mạc Sơn Động 2", "type": "gold"},
	{"name": "Gia Luật Tị Ly", "id": 563, "res": "boss011", "series": "Hỏa", "series_idx": 3, "sect": "Thiên Nhẫn", "level": 95, "map_id": 227, "map_name": "Sa Mạc Sơn Động 3", "type": "gold"},
	{"name": "Hoàn Nhan Tuyết Y", "id": 564, "res": "boss014", "series": "Hỏa", "series_idx": 3, "sect": "Thiên Nhẫn", "level": 95, "map_id": 340, "map_name": "Mạc Cao Quật", "type": "gold"},
	{"name": "Đoan Mộc Duệ", "id": 565, "res": "boss015", "series": "Hỏa", "series_idx": 3, "sect": "Thiên Nhẫn", "level": 95, "map_id": 124, "map_name": "Hiên Viên Động", "type": "gold"},
	{"name": "Đạo Thanh Chân Nhân", "id": 562, "res": "boss001", "series": "Thổ", "series_idx": 4, "sect": "Võ Đang", "level": 95, "map_id": 321, "map_name": "Trường Bạch Sơn Nam", "type": "gold"},
	{"name": "Sơn Tư Nam", "id": 746, "res": "boss022", "series": "Thổ", "series_idx": 4, "sect": "Côn Lôn", "level": 95, "map_id": 322, "map_name": "Trường Bạch Sơn Bắc", "type": "gold"},
	{"name": "Tuyền Cơ Tử", "id": 747, "res": "boss017", "series": "Thổ", "series_idx": 4, "sect": "Côn Lôn", "level": 95, "map_id": 340, "map_name": "Mạc Cao Quật", "type": "gold"},
	# --- Tiểu Hoàng Kim Boss (bosstieuhk.lua) ---
	{"name": "Diệu Như", "id": 513, "res": "enemy056", "series": "Thủy", "series_idx": 2, "sect": "Nga Mi", "level": 100, "map_id": 162, "map_name": "Đại Lý Phủ", "type": "small_gold"},
	{"name": "Liễu Thanh Thanh", "id": 523, "res": "enemy173", "series": "Mộc", "series_idx": 1, "sect": "Thúy Yên", "level": 100, "map_id": 11, "map_name": "Thành Đô", "type": "small_gold"},
	{"name": "Trương Tông Chính", "id": 511, "res": "enemy003", "series": "Thổ", "series_idx": 4, "sect": "Côn Lôn", "level": 100, "map_id": 9, "map_name": "Trường Giang Đầu Nguồn", "type": "small_gold"},
	# --- Tuyệt Đỉnh Trấn Ải Boss ---
	{"name": "Độc Cô Cầu Kiếm", "id": 1038, "res": "boss015", "series": "Kim", "series_idx": 0, "sect": "Vượt Ải", "level": 100, "map_id": 480, "map_name": "Thách Thức Ải 28", "type": "challenge"}
]

const SERIES_COLORS := {
	"Kim": Color(1.0, 0.85, 0.25),
	"Mộc": Color(0.35, 0.85, 0.35),
	"Thủy": Color(0.35, 0.70, 1.0),
	"Hỏa": Color(1.0, 0.35, 0.25),
	"Thổ": Color(0.85, 0.65, 0.40)
}

func _build_boss() -> void:
	_boss_card_views.clear()

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = LIST_SIZE
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	TouchScrollHelperScript.attach(scroll, scroll)

	# Banner giới thiệu Boss Hoàng Kim & PK tự do
	var banner := PanelContainer.new()
	var b_style := GameUi.box(Color(0.12, 0.08, 0.02), Color(0.95, 0.75, 0.2), 8, 2, 8)
	b_style.shadow_color = Color(0.9, 0.7, 0.1, 0.3)
	b_style.shadow_size = 6
	banner.add_theme_stylebox_override("panel", b_style)
	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 4)
	banner.add_child(b_vbox)
	b_vbox.add_child(SocialUi.label(tr("Thập Đại Boss Hoàng Kim & Tiểu Boss Võ Lâm"), SocialUi.TITLE, 18, HORIZONTAL_ALIGNMENT_CENTER))
	var b_sub := SocialUi.label(tr("Lịch chuẩn VLTK: Đại Boss (12:00, 19:30, 23:00) · Tiểu Boss (09:10, 17:10, 21:10, 23:10) · Đến giờ tự do bật PK tranh đoạt!"), Color(1.0, 0.85, 0.35), 12, HORIZONTAL_ALIGNMENT_CENTER)
	b_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_vbox.add_child(b_sub)
	list.add_child(banner)

	for boss in BOSS_LIST:
		list.add_child(_boss_card(boss))

	if _boss_timer == null or not is_instance_valid(_boss_timer):
		_boss_timer = Timer.new()
		_boss_timer.wait_time = 1.0
		_boss_timer.autostart = true
		_boss_timer.timeout.connect(_tick_boss_timers)
		add_child(_boss_timer)
	_tick_boss_timers()

func _boss_card(boss: Dictionary) -> Control:
	var map_id: int = int(boss["map_id"])
	var map_entry_dict := {}
	for m in MapCatalog.all():
		if int(m["id"]) == map_id:
			map_entry_dict = m
			break

	var playable := not map_entry_dict.is_empty() and MapCatalog.is_playable(map_entry_dict)

	var card := GameUi.panel(GameUi.PANEL)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	# 1. Khung xem trước bản đồ xuất hiện Boss (MiniMap thumbnail)
	if not map_entry_dict.is_empty():
		var map_frame := _minimap_frame(map_entry_dict)
		map_frame.custom_minimum_size = Vector2(100, 80)
		map_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(map_frame)

	# 2. Avatar Boss Thumbnail
	var thumb_box := PanelContainer.new()
	thumb_box.custom_minimum_size = Vector2(80, 80)
	thumb_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s_col: Color = SERIES_COLORS.get(str(boss.get("series", "Kim")), Color.GOLD)
	thumb_box.add_theme_stylebox_override("panel", GameUi.box(Color(0.06, 0.08, 0.09), s_col, 6, 2, 2))
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(76, 76)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var boss_res := str(boss.get("res", "boss001"))
	tex_rect.texture = MonsterData.thumb(boss_res)
	thumb_box.add_child(tex_rect)
	row.add_child(thumb_box)

	# 3. Thông tin Boss
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	info.add_child(head)

	var name_lbl := SocialUi.label(tr(str(boss["name"])), SocialUi.TITLE, 17)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	head.add_child(name_lbl)

	var series_badge := SocialUi.label(tr("Hệ %s · %s") % [tr(str(boss["series"])), tr(str(boss["sect"]))], s_col, 13)
	series_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(series_badge)

	# Nhãn đếm ngược thời gian xuất hiện
	var timing_lbl := Label.new()
	timing_lbl.add_theme_font_size_override("font_size", 12)
	head.add_child(timing_lbl)

	info.add_child(SocialUi.label(tr("Cấp độ: %d  ·  Bản đồ: %s") % [int(boss["level"]), tr(str(boss["map_name"]))], SocialUi.LABEL_BLUE, 13))

	var drop_text := ""
	match str(boss.get("type", "gold")):
		"gold":
			drop_text = tr("Vật phẩm rơi: Trang bị Hoàng Kim Môn Phái, Định Quốc, An Bang, Thủy Tinh, Tinh Hồng Bảo Thạch")
		"small_gold":
			drop_text = tr("Vật phẩm rơi: Thủy Tinh (Lam/Tử/Lục), Tinh Hồng Bảo Thạch, Tiên Thảo Lộ, Bí Kíp Môn Phái")
		"challenge":
			drop_text = tr("Vật phẩm rơi: Sát Thủ Bí Bảo, Huyết Lệ Chi Thư, Rương Vượt Ải Cực Phẩm, Exp")
		_:
			drop_text = tr("Vật phẩm rơi: Huyền Tinh, Thủy Tinh, Mật Tịch, Tẩy Tủy Kinh, Bí Kíp 90, Trang bị cực phẩm")
	var drop_lbl := SocialUi.label(drop_text, SocialUi.TEXT, 12)
	drop_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(drop_lbl)

	# 4. Nút hành động (Vào map tìm Boss)
	var play := SocialUi.stone_button(tr("Khiêu chiến") if playable else tr("Chưa mở"), Vector2(115, 42))
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if playable:
		play.pressed.connect(func() -> void:
			var entry := map_entry_dict.duplicate()
			entry["boss"] = {
				"id": int(boss.get("id", 740)),
				"name": str(boss["name"]),
				"res": str(boss["res"]),
				"sect": str(boss["sect"]),
				"series": int(boss.get("series_idx", 0)),
				"level": int(boss["level"]),
				"type": str(boss.get("type", "gold")),
				"is_gold": true,
			}
			_enter_boss_field(entry, boss)
		)
	else:
		play.disabled = true
		play.tooltip_text = tr("Bản đồ %s chưa sẵn sàng") % tr(str(boss["map_name"]))
	row.add_child(play)

	_boss_card_views.append({
		"card": card,
		"badge": timing_lbl,
		"play": play,
		"boss": boss,
		"playable": playable
	})

	return card

func _tick_boss_timers() -> void:
	if not is_inside_tree() or _tab != 3:
		return
	for item in _boss_card_views:
		var boss: Dictionary = item["boss"]
		var timing := compute_boss_timing(boss)
		var badge: Label = item["badge"]
		var play: Button = item["play"]
		var playable: bool = item["playable"]

		if timing.is_open:
			badge.text = timing.status_text
			badge.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45))
			if playable:
				play.disabled = false
				play.text = tr("Vào Săn Boss")
				play.tooltip_text = tr("Boss đang xuất hiện tại %s! Vào khiêu chiến ngay (Phòng chung, hỗ trợ PK).") % tr(str(boss["map_name"]))
		elif not _online() or AccountApi.is_gm():
			badge.text = tr("⏱ Lịch: %s (Có thể test)") % timing.next_time
			badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
			if playable:
				play.disabled = false
				play.text = tr("Khiêu chiến")
				play.tooltip_text = tr("Vào khiêu chiến Boss ngay (Bản đồ 60 vùng).")
		else:
			badge.text = timing.status_text
			badge.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
			if playable:
				play.disabled = true
				play.text = tr("Chưa đến giờ")
				play.tooltip_text = tr("Boss chưa xuất hiện. Hãy quay lại lúc %s!") % timing.next_time

func _enter_boss_field(m: Dictionary, boss: Dictionary) -> void:
	if not _online():
		_play(m)
		return
	var st := await _fetch_field()
	if not is_inside_tree():
		return
	if st.is_empty():
		_play(m)
		return
	var e := m.duplicate(true)
	e["field"] = {
		"server": _field_server(st),
		"action": {
			"op": "boss",
			"boss_id": int(boss.get("id", 740)),
			"map_id": int(boss.get("map_id", 0)),
			"boss_name": str(boss.get("name", "Boss Hoàng Kim"))
		}
	}
	_play(e)

static func boss_spawn_schedule(boss: Dictionary) -> Dictionary:
	if boss.has("times") and boss["times"] is Array:
		return {
			"times": boss["times"],
			"duration_mins": int(boss.get("duration_mins", 45))
		}
	var btype: String = str(boss.get("type", "gold"))
	if btype == "challenge":
		return {
			"times": ["00:00", "01:00", "02:00", "03:00", "04:00", "05:00", "06:00", "07:00", "08:00", "09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00", "18:00", "19:00", "20:00", "21:00", "22:00", "23:00"],
			"duration_mins": 35
		}
	if btype == "small_gold":
		# Chuẩn bosstieuhk.lua & callboss_incity.lua: 09h10, 17h10, 21h10, 23h10
		return {
			"times": ["09:10", "17:10", "21:10", "23:10"],
			"duration_mins": 35
		}
	# Thập Đại Boss Hoàng Kim (chuẩn VLTK & bossdown.lua: 12h00 trưa, 19h30 tối, 23h00 đêm)
	return {
		"times": ["12:00", "19:30", "23:00"],
		"duration_mins": 45
	}

static func compute_boss_timing(boss: Dictionary) -> Dictionary:
	var sched := boss_spawn_schedule(boss)
	var dt := Time.get_time_dict_from_system()
	var now_sec: int = int(dt.hour) * 3600 + int(dt.minute) * 60 + int(dt.second)
	var duration_sec: int = int(sched.get("duration_mins", 30)) * 60
	var times: Array = sched.get("times", [])

	for t_str in times:
		var parts := str(t_str).split(":")
		if parts.size() < 2:
			continue
		var start_sec := int(parts[0]) * 3600 + int(parts[1]) * 60
		var end_sec := start_sec + duration_sec
		if now_sec >= start_sec and now_sec < end_sec:
			var remaining := end_sec - now_sec
			return {
				"is_open": true,
				"remaining_sec": remaining,
				"status_text": TranslationServer.translate("🟢 ĐANG XUẤT HIỆN (Còn %02d:%02d)") % [remaining / 60, remaining % 60],
				"next_time": t_str
			}

	var min_diff := 999999
	var next_t_str := ""
	for t_str in times:
		var parts := str(t_str).split(":")
		if parts.size() < 2:
			continue
		var start_sec := int(parts[0]) * 3600 + int(parts[1]) * 60
		var diff := start_sec - now_sec
		if diff < 0:
			diff += 86400
		if diff < min_diff:
			min_diff = diff
			next_t_str = t_str

	return {
		"is_open": false,
		"diff_sec": min_diff,
		"status_text": TranslationServer.translate("⏳ Sắp xuất hiện: %s (Còn %02d:%02d)") % [next_t_str, min_diff / 60, min_diff % 60],
		"next_time": next_t_str
	}

static func _load_thumb(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	return null

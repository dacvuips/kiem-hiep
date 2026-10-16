extends Control
class_name CharacterHubScreen
## Sảnh chính ngoài trận (bối cảnh sân làng), sau Chọn Nhân Vật và trước khi vào ải.
##
## Vị trí/khung của mọi thành phần TĨNH (thanh tiền tệ, nút Quay Lại/Vượt Ải, thẻ ải, thẻ Dược
## Viên, thẻ Nhân Vật, khung menu) nằm trong CharacterHub.tscn (kéo thả được trong Godot editor) —
## script này chỉ gán style/text/hành vi qua %NodeName, không tự tạo node cho phần tĩnh nữa.
##
## 8 nút MENU PHỤ (NAV_ITEMS) vẫn sinh bằng code trong _build_nav() vì số lượng lặp theo mảng dữ
## liệu, không có lợi ích kéo thả cho các ô giống hệt nhau — muốn đổi vị trí/kích thước cả cụm,
## sửa RECT_NAV_MENU bên dưới hoặc kéo %FrameNavMenu trong scene rồi đồng bộ lại rect ở đây.

const SELECT_SCENE_PATH := "res://ui/character_select/CharacterSelect.tscn"
const ROSTER_SCENE_PATH := "res://ui/character_roster/CharacterRoster.tscn"
const GAME_SCENE_PATH := "res://Main.tscn"
const FADE_DURATION := 0.3

const COLOR_GOLD := Color("f0d08a")
const COLOR_CREAM := Color("eadcc0")
const COLOR_OUTLINE := Color("120c06")

## Nav menu vẫn sinh bằng code — RECT tính theo tỉ lệ 0..1 của %Board, khớp đúng vị trí
## %FrameNavMenu đặt trong scene (0.82, 0.15, 0.985, 0.9). Nếu kéo %FrameNavMenu sang vị trí khác
## trong editor, cập nhật lại hằng số này cho khớp.
const RECT_NAV_MENU := [0.82, 0.15, 0.985, 0.9]
## [id, tên hiển thị] — 8 mục menu phụ (KHÔNG gồm "Nhân Vật", tách riêng dùng %FrameCharacter to
## hơn — xem _build_nav()). Thứ tự khớp 8 ô CUỐI của nav_menu.png (bỏ ô đầu tiên).
const NAV_ITEMS := [
	["quests", "Nhiệm Vụ"],
	["equipment", "Trang Bị"],
	["skills", "Kỹ Năng"],
	["guild", "Bang Hội"],
	["social", "Giao Dịch"],
	["herb_garden", "Chế Tạo"],
	["ranking", "BXH"],
	["settings", "Cài Đặt"],
]

## Danh sách ải theo thứ tự — ải đang chơi = stages[profile.stages_cleared] (kẹp về ải cuối).
@export var stages: Array[StageData] = [preload("res://stages/stage_01/stage_01.tres")]

var _profile: PlayerProfile
var _hover_style: StyleBoxFlat
var _pressed_style: StyleBoxFlat

var _toast_tween: Tween
## Mọi node ở thanh dưới cùng (Quay Lại, thẻ Tiến độ, Vượt Ải) — vùng của chúng chồng lấn
## RECT_CHARACTER_STATUS nên bị panel Thuộc Tính (dựng SAU) che mất; move_to_front() cả nhóm sau
## khi panel dựng xong, xem _ready().
var _bottom_bar_nodes: Array[Control] = []
## Toàn bộ skill của môn phái (không lọc hotbar) — nguồn dữ liệu cho SkillBookScreen.
var _all_skills: Array[SkillDefinition] = []
var _status_screen: CharacterStatusScreen

func _ready() -> void:
	_profile = GameManager.local_profile
	if _profile == null:
		_profile = SaveManager.load_profile()
		GameManager.local_profile = _profile
	if _profile == null:
		get_tree().change_scene_to_file.call_deferred(ROSTER_SCENE_PATH if AccountApi.is_logged_in() else SELECT_SCENE_PATH)
		return

	_apply_pending_run_exp()

	_hover_style = _flat_style(Color(1, 0.95, 0.75, 0.14), 8)
	_shrink_stylebox(_hover_style, 8.0)
	_pressed_style = _flat_style(Color(0, 0, 0, 0.25), 8)
	_shrink_stylebox(_pressed_style, 8.0)
	_all_skills = _load_all_skills()

	_style_header()
	_style_bottom_bar()
	_build_nav()
	_style_character_card()
	_style_herb_card()
	_style_toast()
	_build_character_status_panel()
	## Panel Thuộc Tính được dựng SAU (đè lên trên) thanh nút dưới cùng trong z-order — đưa cả
	## nhóm (Quay Lại, thẻ Tiến độ, Vượt Ải) lên trên cùng lại để không bị che/bấm được.
	for node in _bottom_bar_nodes:
		node.move_to_front()
	refresh()

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	_ask_sect_if_needed.call_deferred()
	## Online: kết nối "sảnh" tới game server — Chợ / giao dịch theo ID / chat / tổ đội / bang chạy thật ngay từ Hub.
	HubSession.attach(self)

## Nhân vật mới tạo (cấp 10 nhờ StarterKit, chưa có phái): BẮT BUỘC chọn phái ngay ở Hub. Online chỉ khi nhân vật chưa vào map lần
## nào (server_seen 0 — game server nhận phái này lúc vào map lần đầu, ProfileGuard.sanitize_new); nhân vật đã vào map thì chọn trong
## game (SectPrompt, server xác nhận cấp thật).
func _ask_sect_if_needed() -> void:
	if _profile == null or not _profile.needs_sect():
		return
	if AccountApi.is_logged_in() and _profile.server_seen != 0:
		return
	var win := SectChoiceWindow.open(self, _profile)
	win.chosen.connect(_on_sect_chosen)

## Vừa vào phái: vũ khí tân thủ đúng loại phái (online: bản thật do game server phát lại lúc vào map lần đầu), lưu, vẽ lại Hub.
func _on_sect_chosen(sect: SectDefinition) -> void:
	var weapon := StarterKit.give_sect_weapon(_profile)
	SaveManager.save_profile(_profile)
	_all_skills = _load_all_skills()
	refresh()
	_show_toast("Đã gia nhập %s!%s" % [sect.sect_name, " Môn phái tặng %s." % weapon.get_base().get("name", "?") if weapon else ""])

## Quy đổi PlayerStats.level đạt được ở lượt chơi VỪA kết thúc (nếu có) thành EXP nhân vật lâu
## dài — chỉ cộng 1 lần nhờ GameManager reset last_run_stats_level về -1 ngay sau khi đọc, để mở
## lại Hub nhiều lần (không chơi thêm trận nào) không bị cộng lặp.
const EXP_PER_RUN_LEVEL := 20

func _apply_pending_run_exp() -> void:
	if GameManager.last_run_stats_level <= 0:
		return
	_profile.add_exp(GameManager.last_run_stats_level * EXP_PER_RUN_LEVEL)
	GameManager.last_run_stats_level = -1
	SaveManager.save_profile(_profile)

## Đọc lại toàn bộ số liệu từ profile — gọi sau khi profile đổi (nhận thưởng, lên cấp...).
func refresh() -> void:
	(%GoldValueLabel as Label).text = _format_number(_profile.gold)
	(%JadeValueLabel as Label).text = _format_number(_profile.jade)
	(%StaminaValueLabel as Label).text = "%d/%d" % [_profile.stamina, _profile.max_stamina]

	var stage := _current_stage()
	var stage_index := _current_stage_index()
	(%StageNameLabel as Label).text = "%d. %s" % [stage_index + 1, stage.stage_name if stage else "—"]
	(%StageProgressLabel as Label).text = "Tiến độ: %d/%d" % [mini(_profile.stages_cleared, stages.size()), stages.size()]
	(%HerbLevelLabel as Label).text = "Lv. %d" % _profile.herb_garden_level

## Toàn bộ skill của môn phái (active lẫn passive) — nguồn dữ liệu cho SkillBookScreen.
func _load_all_skills() -> Array[SkillDefinition]:
	var sect := SectRegistry.get_by_id(_profile.sect_id)
	var empty: Array[SkillDefinition] = []   ## Vô Môn Phái: chưa có skill phái
	return sect.skills if sect else empty

# ---------------------------------------------------------------- style cho node tĩnh (đã đặt sẵn vị trí trong .tscn)

func _style_header() -> void:
	## Tiền/ngọc canh phải sát nút + (chừa chỗ icon đè đầu trái ô); thể lực canh giữa.
	for label in [%GoldValueLabel, %JadeValueLabel]:
		_style_label(label, 15, COLOR_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true, 28.0)
	_style_label(%StaminaValueLabel, 15, COLOR_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true, 28.0)
	for button: Button in [%GoldPlusButton, %JadePlusButton, %StaminaPlusButton]:
		_style_as_hit_area(button)
		button.pressed.connect(_show_toast.bind("Nạp / mua thêm: đang phát triển"))

func _style_bottom_bar() -> void:
	_bottom_bar_nodes.append_array([%FrameBack, %BackButton, %BackLabel, %FrameStage, %StageButton,
			%StageNameLabel, %StageProgressLabel, %FrameChallenge, %ChallengeButton, %ChallengeLabel,
			%PlayButton, %PlayLabel])

	_style_as_hit_area(%BackButton)
	(%BackButton as Button).pressed.connect(_on_back_pressed)
	_style_label(%BackLabel, 14, COLOR_CREAM)

	## Chế độ Ải cũ (StageData = 1 ô vuông trên map chính) đã tắt cùng map chính: ẩn cả thẻ Tiến độ ải.
	for node: Control in [%FrameStage, %StageButton, %StageNameLabel, %StageProgressLabel]:
		node.visible = false
	_style_label(%StageNameLabel, 13, COLOR_CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label(%StageProgressLabel, 13, COLOR_CREAM, HORIZONTAL_ALIGNMENT_LEFT)

	_style_as_hit_area(%ChallengeButton)
	(%ChallengeButton as Button).pressed.connect(func() -> void: MapSelectWindow.open(self, _profile, _enter_field_map))
	_style_label(%ChallengeLabel, 32, COLOR_GOLD)

	## "PK": popup PK (Đại hội võ lâm / Võ lâm Liên đấu) — vào trận thì đổi cảnh như Vượt Ải. Nút riêng vì 2 label không dùng
	## chung 1 vùng bấm (PlayLabel nằm ngoài rect của ChallengeButton).
	_style_as_hit_area(%PlayButton)
	(%PlayButton as Button).pressed.connect(func() -> void: PkWindow.open(self, _profile, _enter_field_map))
	_style_label(%PlayLabel, 32, COLOR_GOLD)

func _style_character_card() -> void:
	## Panel Thuộc Tính đã hiện thường trực trong Hub nên nút này không cần mở màn hình riêng —
	## chỉ cần vùng hover sáng giống 8 nút menu phụ để nhất quán thị giác.
	_style_as_hit_area(%CharacterButton)
	_style_label(%CharacterLabel, 16, COLOR_GOLD)

func _style_herb_card() -> void:
	_style_as_hit_area(%HerbButton)
	(%HerbButton as Button).pressed.connect(_show_toast.bind("Dược Viên: đang phát triển"))
	_style_label(%HerbLevelLabel, 13, COLOR_CREAM, HORIZONTAL_ALIGNMENT_LEFT)

func _style_toast() -> void:
	var toast: Label = %ToastLabel
	_style_label(toast, 16, COLOR_CREAM)
	var style := _flat_style(Color(0.06, 0.04, 0.02, 0.85), 8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	toast.add_theme_stylebox_override("normal", style)

## 8 nút menu phụ — %NavButton0..7/%NavLabel0..7 đã đặt sẵn vị trí trong .tscn (kéo thả được),
## script chỉ style + nối hành vi theo đúng thứ tự NAV_ITEMS. %FrameNavMenu (khung ảnh tĩnh) cũng
## đã đặt sẵn trong .tscn.
func _build_nav() -> void:
	for i in NAV_ITEMS.size():
		var id: String = NAV_ITEMS[i][0]
		var label_text: String = NAV_ITEMS[i][1]
		var button: Button = get_node("%%NavButton%d" % i)
		var item_label: Label = get_node("%%NavLabel%d" % i)

		_style_as_hit_area(button)
		_style_label(item_label, 16, COLOR_GOLD)
		item_label.text = label_text
		item_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		item_label.clip_text = false

		if id == "skills":
			button.pressed.connect(_on_skills_nav_pressed)
			continue
		if id == "equipment":
			button.pressed.connect(_on_equipment_nav_pressed)
			continue
		if id == "guild":
			button.pressed.connect(func() -> void: GuildWindow.open(self, SocialHub.of(_profile)))
			continue
		if id == "social":
			button.pressed.connect(func() -> void: MarketWindow.open(self, _profile))
			continue
		if id == "ranking":
			button.pressed.connect(func() -> void: RankingWindow.open(self, _profile))
			continue
		if id == "settings":
			button.pressed.connect(func() -> void: AccountDialog.open(self))
			continue
		button.pressed.connect(_show_toast.bind("%s: đang phát triển" % label_text))

# ---------------------------------------------------------------- panel Thuộc Tính

## Bảng "Trang Bị Và Thuộc Tính" hiện THƯỜNG TRỰC (không phải popup) trong %CharacterStatusWrap —
## vùng còn trống giữa cạnh trái và menu phải, dưới thanh tiền tệ và trên thanh nút dưới cùng.
func _build_character_status_panel() -> void:
	_status_screen = CharacterStatusScreen.attach(%CharacterStatusWrap, _profile)

# ---------------------------------------------------------------- hành động

## Đổi sang cảnh chơi ở chế độ đi lại tự do; map nào là do GameManager.field_map (màn Vượt Ải) quyết định.
func _start_main_map() -> void:
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = {}
	GameManager.current_stage = null
	GameManager.is_game_over = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(get_tree().change_scene_to_file.bind(GAME_SCENE_PATH))

## Nút "Vượt Ải" -> MapSelectWindow -> bấm [Vào] 1 map luyện công: vào thẳng map đó (đi lại tự do, quái của map).
func _enter_field_map(entry: Dictionary) -> void:
	_start_main_map()
	GameManager.field_map = entry

## Vào 1 ải (StageData) — qua màn Chọn Ải, xem _on_stage_button_pressed().
func _enter_stage(stage: StageData) -> void:
	if stage == null:
		_show_toast("Chưa có ải nào")
		return
	GameManager.game_mode = GameManager.GameMode.STAGE
	GameManager.field_map = {}
	GameManager.current_stage = stage
	GameManager.is_game_over = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(get_tree().change_scene_to_file.bind(GAME_SCENE_PATH))

## Nút "Chọn Ải" ở thanh dưới cùng — mở màn liệt kê toàn bộ `stages`, cho chọn 1 map cụ thể để
## chơi/chơi lại.
func _on_stage_button_pressed() -> void:
	StageSelectScreen.open(self, _profile, stages, _enter_stage, func() -> void: pass)

func _on_back_pressed() -> void:
	if AccountApi.is_logged_in():
		await SaveManager.flush_online()
		get_tree().change_scene_to_file(ROSTER_SCENE_PATH)
		return
	get_tree().change_scene_to_file(SELECT_SCENE_PATH)

## Nút "Kỹ Năng" ở menu phải — mở bảng Kỹ Năng Võ Công đầy đủ (toàn bộ skill môn phái, không chỉ
## hotbar) để học/nâng cấp.
func _on_skills_nav_pressed() -> void:
	if _all_skills.is_empty():
		_show_toast("Chưa gia nhập môn phái — vào game để chọn phái")
		return
	SkillBookScreen.open(self, _profile, _all_skills, func() -> void: refresh())

## Nút "Trang Bị" ở menu phải — mở Hành trang (mặc/bỏ đồ); đổi đồ xong vẽ lại Hub + bảng Thuộc Tính.
func _on_equipment_nav_pressed() -> void:
	InventoryPopup.open(self, _profile, func() -> void:
		refresh()
		_status_screen.refresh())

func _show_toast(message: String) -> void:
	var toast: Label = %ToastLabel
	toast.text = message
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(toast.hide)

func _current_stage_index() -> int:
	return clampi(_profile.stages_cleared, 0, maxi(stages.size() - 1, 0))

func _current_stage() -> StageData:
	return stages[_current_stage_index()] if not stages.is_empty() else null

# ---------------------------------------------------------------- tiện ích

## Gán style/màu cho 1 Label ĐÃ CÓ SẴN trong scene (vị trí/anchor do .tscn quyết định).
func _style_label(label: Label, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := true, pad := 0.0) -> void:
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUi.fit_label(label, font_size, 9, pad)   ## ô vẽ sẵn trên ảnh: chữ dài thì thu nhỏ cho vừa
	label.add_theme_color_override("font_color", color)
	if outline:
		label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		label.add_theme_constant_override("outline_size", 4)

func _style_as_hit_area(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_stylebox_override("hover", _hover_style)
	button.add_theme_stylebox_override("pressed", _pressed_style)
	button.add_theme_stylebox_override("hover_pressed", _pressed_style)

func _flat_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

## StyleBoxFlat mặc định vẽ khít đúng rect của Button (full ô) — khi vùng bấm to bằng cả khung menu
## (item to hơn trước), hover/pressed phủ kín cả ô trông thô. Set expand_margin ÂM để thu nhỏ vùng
## VẼ vào trong `px` mỗi cạnh trong khi vùng BẤM (rect của Button) vẫn giữ nguyên full ô, dễ click.
func _shrink_stylebox(style: StyleBoxFlat, px: float) -> void:
	style.expand_margin_left = -px
	style.expand_margin_top = -px
	style.expand_margin_right = -px
	style.expand_margin_bottom = -px

## F10: mở màn debug liệt kê toàn bộ Quái/Map đã có trong project — chỉ hoạt động ở debug build,
## giống F9/F5/F6 trong main.gd (xem DebugDataBrowser).
func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		DebugDataBrowser.open(self, func() -> void: pass)

## 256800 -> "256.800" (dấu chấm phân cách hàng nghìn kiểu Việt Nam, khớp mockup).
static func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > 3:
		result = "." + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result

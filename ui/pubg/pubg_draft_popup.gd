extends CanvasLayer
class_name PubgDraftPopup
## Popup 2 Đợt Chọn Thẻ Khởi Đầu Chiến Trường Sinh Tồn (PUBG Võ Lâm):
## - Đợt 1: Chọn 1 trong 5 Thần Mã 8x (Ô Vân Đạp Tuyết, Chiếu Dạ Ngọc Sư Tử, Xích Thố, Tuyệt Ảnh, Đích Lô)
## - Đợt 2: Chọn 1 trong 14 Loại Vũ Khí Cấp 10 (Kiếm, Đao, Côn, Thương, Chùy, Song đao, Triền thủ, Đao thuẫn, Thuẫn đao, Phi tiêu, Phi đao, Tụ tiễn, Cầm, Cung)

## Bộ thẻ 5x (màn Lộn Xộn, `tier = 5`): 5 ngựa cấp 5 + 14 vũ khí cấp 5 (yêu cầu cấp 36) — dùng được ngay ở cấp 50.
signal draft_completed

const TIER_PUBG := 8
const TIER_LONXON := 5
## Lựa chọn gần nhất của bộ thẻ 5x {horse 1-5, weapon 0-13} — LonXon client gửi lên server (bộ 8x dùng PubgManager.pending_draft).
static var lonxon_pending_draft: Dictionary = {}

var _tier: int = TIER_PUBG
var _profile: PlayerProfile
var _on_finish: Callable
var _step: int = 1 # 1: Chọn Ngựa, 2: Chọn Vũ Khí
var _selected_weapon_idx: int = 0
var _chosen_horse: int = 1
var _weapon_cards: Array[PanelContainer] = []
var _weapon_status_labels: Array[Label] = []

var _window_panel: PanelContainer
var _title_label: Label
var _sub_label: Label
var _cards_container: Control
var _action_bar: Control

## Danh sách 5 Chiến Mã 8x (Detail = 10, Particular = 5, Level 1..5)
const HORSES_8X := [
	{
		"level": 1,
		"name": "Ô Vân Đạp Tuyết",
		"desc": "Thân đen tuyền, bốn móng trắng tuyết. Thần mã danh bất hư truyền của VLTK.\n• Tốc độ chạy +100%\n• Né tránh +15%\n• Kháng tất cả +15%",
		"color": Color(0.9, 0.85, 0.5)
	},
	{
		"level": 2,
		"name": "Xích Thố",
		"desc": "Toàn thân đỏ rực như lửa, dũng mãnh vô song. Chiến mã của anh hùng Quan Công.\n• Tốc độ chạy +100%\n• Sinh lực tối đa +1000\n• Kháng Hỏa +25%",
		"color": Color(1.0, 0.4, 0.3)
	},
	{
		"level": 3,
		"name": "Tuyệt Ảnh",
		"desc": "Chạy nhanh như gió, thoắt ẩn thoắt hiện đến cái bóng cũng không đuổi kịp.\n• Tốc độ chạy +100%\n• Bỏ qua né tránh của mục tiêu\n• Kháng Độc +25%",
		"color": Color(0.7, 0.5, 1.0)
	},
	{
		"level": 4,
		"name": "Đích Lô",
		"desc": "Chiến mã huyền thoại từng cõng Lưu Bị vượt suối Đàn Khê thoát hiểm.\n• Tốc độ chạy +100%\n• Tấn công chính xác +20%\n• Kháng Lôi +25%",
		"color": Color(0.4, 0.85, 1.0)
	},
	{
		"level": 5,
		"name": "Chiếu Dạ Ngọc Sư Tử",
		"desc": "Bạch mã trắng tinh phát sáng trong đêm, uy nghi tựa sư tử bờm ngọc.\n• Tốc độ chạy +100%\n• Băng sát nội công +150\n• Kháng Băng +25%",
		"color": Color(0.9, 0.95, 1.0)
	}
]

## 5 ngựa 5x (Detail = 10, Particular = 0..4, Level 5 — mọi ngựa yêu cầu cấp 10). "level" = số thẻ 1..5 (như HORSES_8X).
const HORSES_5X := [
	{"level": 1, "particular": 0, "name": "Hoàng Phiêu", "color": Color(1.0, 0.85, 0.4)},
	{"level": 2, "particular": 1, "name": "Tử Lưu", "color": Color(0.8, 0.55, 1.0)},
	{"level": 3, "particular": 2, "name": "Ngọc Hoa Thông", "color": Color(0.92, 0.95, 1.0)},
	{"level": 4, "particular": 3, "name": "Hắc Kỳ", "color": Color(0.6, 0.65, 0.75)},
	{"level": 5, "particular": 4, "name": "Hồng Ly", "color": Color(1.0, 0.45, 0.4)},
]

static func horse_cards(tier: int) -> Array:
	return HORSES_5X if tier == TIER_LONXON else HORSES_8X

## Cấp vũ khí của bộ thẻ: 8x -> cấp 10, 5x -> cấp 5.
static func weapon_level(tier: int) -> int:
	return 5 if tier == TIER_LONXON else 10

## Tên vũ khí thẻ `index`: bộ 8x lấy tên đặt sẵn, bộ khác lấy tên gốc trong bảng đồ ở cấp tương ứng.
static func weapon_name(index: int, tier: int) -> String:
	var w_data: Dictionary = WEAPONS_10[clampi(index, 0, WEAPONS_10.size() - 1)]
	if tier != TIER_LONXON:
		return str(w_data["name"])
	var base := ItemDatabase.get_base(ItemDatabase.find_base(int(w_data["detail"]), int(w_data["particular"]), weapon_level(tier)))
	return str(base.get("name", w_data["name"]))

## Dòng chỉ số gốc của 1 món (để mô tả thẻ ngựa 5x — chỉ số đúng theo bảng đồ).
static func _base_lines(item: ItemInstance) -> String:
	if item == null:
		return ""
	var out: Array[String] = []
	for b in item.base_values:
		var t := ItemText.plain(ItemText.format_attrib(str(b[0]), [int(b[1])]))
		if t != "":
			out.append("• " + t)
	return "\n".join(out)

## Danh sách 14 Loại Vũ Khí Cấp 10 (giống hệt bảng danh mục VLTK)
const WEAPONS_10 := [
	{"detail": 0, "particular": 0, "cat": "Vũ khí — Kiếm", "name": "Huyền Thiết Kiếm", "desc": "Trọng kiếm sắc bén, thích hợp Võ Đang, Côn Lôn, Hoa Sơn, Thúy Yên, Đoàn Thị"},
	{"detail": 0, "particular": 1, "cat": "Vũ khí — Đao", "name": "Đại Phong Đao", "desc": "Uy lực dũng mãnh, thích hợp Thiếu Lâm, Thiên Vương, Cái Bang, Ma Nhẫn, Côn Lôn"},
	{"detail": 0, "particular": 2, "cat": "Vũ khí — Côn (bổng)", "name": "Kim Cô Bổng", "desc": "Trượng bổng quét ngang vạn quân, thích hợp Thiếu Lâm, Cái Bang"},
	{"detail": 0, "particular": 3, "cat": "Vũ khí — Thương", "name": "Phá Thiên Kích", "desc": "Mũi thương sắc nhọn xé toạc chiến trường, thích hợp Thiên Vương, Thiên Nhẫn"},
	{"detail": 0, "particular": 4, "cat": "Vũ khí — Chùy", "name": "Phá Thiên Chùy", "desc": "Cương mãnh tuyệt luân giáng ngàn cân, thích hợp Thiên Vương, Minh Giáo"},
	{"detail": 0, "particular": 5, "cat": "Vũ khí — Song đao", "name": "Thôn Nhật Trảm", "desc": "Song kiếm vũ đạo linh hoạt xuất quỷ nhập thần, thích hợp Thúy Yên"},
	{"detail": 0, "particular": 6, "cat": "Vũ khí — Triền thủ", "name": "Mật Vân Triền Thủ", "desc": "Bao tay khí kình hộ thể, thích hợp Nga Mi Chưởng, Minh Giáo Chưởng, Đoàn Thị"},
	{"detail": 0, "particular": 7, "cat": "Vũ khí — Đao thuẫn", "name": "Tinh Chế Đao Thuẫn", "desc": "Vũ khí công thủ song toàn, thích hợp Dương Gia"},
	{"detail": 0, "particular": 8, "cat": "Vũ khí — Thuẫn đao", "name": "Tinh Chế Thuẫn Đao", "desc": "Bản thuẫn cản phá sát thương, thích hợp Dương Gia"},
	{"detail": 1, "particular": 0, "cat": "Ám khí — Phi tiêu", "name": "Bá Vương Tiêu", "desc": "Ám khí chí mạng phát xạ liên hồi, thích hợp Đường Môn Tiêu"},
	{"detail": 1, "particular": 1, "cat": "Ám khí — Phi đao", "name": "Toái Nguyệt Đao", "desc": "Phi đao bẫy thuật biến ảo khôn lường, thích hợp Đường Môn Bẫy/Đao"},
	{"detail": 1, "particular": 2, "cat": "Ám khí — Tụ tiễn", "name": "Khổng Tước Linh", "desc": "Tụ tiễn ngầm trong tay áo bắn vạn mũi tên, thích hợp Đường Môn Nỏ"},
	{"detail": 1, "particular": 3, "cat": "Ám khí — Cầm", "name": "Thiên Cầm", "desc": "Cầm âm ma mị gảy nốt sát phạt, thích hợp Tiêu Dao"},
	{"detail": 1, "particular": 4, "cat": "Ám khí — Cung", "name": "Cung Dương Môn C10", "desc": "Cung tên thiện xạ bách bộ xuyên dương, thích hợp Dương Gia Cung"}
]

## Thần mã 8x của thẻ `horse_lv` (1-5): ngựa cấp 80 tốc chạy +100% + dòng riêng theo tên. Dùng chung máy người chơi + PubgServer.
static func make_horse(horse_lv: int, elem: int, tier: int = TIER_PUBG) -> ItemInstance:
	if tier == TIER_LONXON:
		var h: Dictionary = HORSES_5X[clampi(horse_lv, 1, HORSES_5X.size()) - 1]
		return ItemGenerator.generate(10, int(h["particular"]), 5, elem, [])
	horse_lv = clampi(horse_lv, 1, HORSES_8X.size())
	var horse_item := ItemGenerator.generate(10, 5, horse_lv, elem, [10, 10, 10, 10, 10])

	if horse_item != null:
		# Đảm bảo tốc độ chạy +100% đúng chuẩn như thông tin hiển thị trên thẻ chọn
		var found_spd := false
		for b in horse_item.base_values:
			if b[0] == "fastwalkrun_p":
				b[1] = 100
				found_spd = true
				break
		if not found_spd:
			horse_item.base_values.append(["fastwalkrun_p", 100])

		# Thêm thuộc tính đặc thù theo danh xưng thần mã 8x
		match horse_lv:
			1: # Ô Vân Đạp Tuyết: Né tránh +15%, Kháng tất cả +15%
				horse_item.base_values.append(["defense_p", 15])
				horse_item.base_values.append(["allres_p", 15])
			2: # Xích Thố: Sinh lực tối đa +1000, Kháng Hỏa +25%
				horse_item.base_values.append(["lifemax_v", 1000])
				horse_item.base_values.append(["fireres_p", 25])
			3: # Tuyệt Ảnh: Bỏ qua né tránh, Kháng Độc +25%
				horse_item.base_values.append(["ignoredefense_p", 20])
				horse_item.base_values.append(["poisonres_p", 25])
			4: # Đích Lô: Tấn công chính xác +20%, Kháng Lôi +25%
				horse_item.base_values.append(["attackrating_p", 20])
				horse_item.base_values.append(["lightingres_p", 25])
			5: # Chiếu Dạ Ngọc Sư Tử: Băng sát nội công +150, Kháng Băng +25%
				horse_item.base_values.append(["colddamage_v", 150])
				horse_item.base_values.append(["coldres_p", 25])
	return horse_item

## Vũ khí trắng thứ `index` trong WEAPONS_10 (không dòng ma pháp), cấp theo bộ thẻ (8x: cấp 10, 5x: cấp 5).
static func make_weapon(index: int, elem: int, tier: int = TIER_PUBG) -> ItemInstance:
	var w_data: Dictionary = WEAPONS_10[clampi(index, 0, WEAPONS_10.size() - 1)]
	return ItemGenerator.generate(int(w_data["detail"]), int(w_data["particular"]), weapon_level(tier), elem, [])

## Cộng tối thiểu điểm tiềm năng vào Sức / Thân cho đủ yêu cầu của `weapon` (nếu đủ điểm). Trả về {"str", "dex"} đã cộng
## ({} nếu không cần / không đủ điểm). Phần còn lại người chơi tự cộng.
static func auto_meet_weapon(profile: PlayerProfile, weapon: ItemInstance) -> Dictionary:
	if profile == null or weapon == null:
		return {}
	var need_str := 0
	var need_dex := 0
	for r in weapon.get_requirements():
		match str(r[0]):
			"requirestr":
				need_str = maxi(0, int(r[1]) - profile.strength)
			"requiredex":
				need_dex = maxi(0, int(r[1]) - profile.dexterity)
	if need_str + need_dex == 0 or need_str + need_dex > profile.potential_points:
		return {}
	profile.strength += need_str
	profile.dexterity += need_dex
	profile.potential_points -= need_str + need_dex
	return {"str": need_str, "dex": need_dex}

static func open(host: Node, profile: PlayerProfile, on_finish: Callable = Callable(), tier: int = TIER_PUBG) -> PubgDraftPopup:
	var tree := host.get_tree() if host != null and host.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		for node in tree.get_nodes_in_group("pubg_draft_popup"):
			if is_instance_valid(node):
				return node as PubgDraftPopup

	var popup := PubgDraftPopup.new()
	popup.add_to_group("pubg_draft_popup")
	popup._tier = tier
	popup._profile = profile
	popup._on_finish = on_finish

	var target_parent: Node = null
	if host != null and is_instance_valid(host):
		target_parent = host
	elif tree != null and tree.current_scene != null:
		target_parent = tree.current_scene
	if target_parent != null:
		target_parent.add_child(popup)
	return popup

func _ready() -> void:
	layer = 100 # Đè lên trên game và toàn bộ HUD
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 1. Nền mờ tối phía sau (Dim background) chặn click xuống game
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# 2. Khung cửa sổ chính giữa màn hình
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_window_panel = PanelContainer.new()
	_window_panel.custom_minimum_size = Vector2(960.0, 560.0)
	center.add_child(_window_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.12, 0.98)
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(0.95, 0.80, 0.30, 0.9) # Viền vàng cổ trang
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_window_panel.add_theme_stylebox_override("panel", sb)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	_window_panel.add_child(root_vbox)

	# Header tiêu đề
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 4)
	root_vbox.add_child(header_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header_vbox.add_child(_title_label)

	_sub_label = Label.new()
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 14)
	_sub_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	header_vbox.add_child(_sub_label)

	# Divider line
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Content area (thay đổi theo _step)
	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_container.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_cards_container)

	# Action bar dưới cùng
	_action_bar = HBoxContainer.new()
	_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(_action_bar)

	_render_step_1_horses()

# ==============================================================================
# ĐỢT 1: CHỌN NGỰA 8X (Ô VÂN ĐẠP TUYẾT)
# ==============================================================================
func _render_step_1_horses() -> void:
	_step = 1
	if _tier == TIER_LONXON:
		_title_label.text = "🐎 LỘN XỘN — CHỌN NGỰA 5X (ĐỢT 1/2)"
		_sub_label.text = "Hãy chọn 1 trong 5 con ngựa 5x để cưỡi ngay — dùng được ở cấp 50:"
	else:
		_title_label.text = "🐎 CHIẾN TRƯỜNG SINH TỒN — CHỌN CHIẾN MÃ 8X (ĐỢT 1/2)"
		_sub_label.text = "Hãy chọn 1 trong 5 chiến mã Ô Vân Đạp Tuyết cấp 80 để cưỡi và tăng tốc độ di chuyển trong trận:"

	for c in _cards_container.get_children():
		c.queue_free()
	for b in _action_bar.get_children():
		b.queue_free()

	var h_grid := HBoxContainer.new()
	h_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	h_grid.add_theme_constant_override("separation", 12)
	h_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_container.add_child(h_grid)

	for h_data in horse_cards(_tier):
		var card := _create_horse_card(h_data)
		h_grid.add_child(card)

func _create_horse_card(h_data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(174.0, 380.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.15, 0.18, 0.95)
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(0.4, 0.45, 0.5, 0.6)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# Icon ngựa
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	var is_5x := _tier == TIER_LONXON
	var base_entry := ItemDatabase.get_base(ItemDatabase.find_base(10, int(h_data["particular"]), 5) if is_5x else ItemDatabase.find_base(10, 5, int(h_data["level"])))
	if not base_entry.is_empty():
		icon_rect.texture = ItemDatabase.get_icon(base_entry, true)
	vb.add_child(icon_rect)

	# Tên ngựa
	var name_lbl := Label.new()
	name_lbl.text = str(h_data["name"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", h_data.get("color", Color(1.0, 0.85, 0.3)))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name_lbl)

	var sub_tier := Label.new()
	sub_tier.text = "Ngựa Cấp 5 (5x)" if is_5x else "Ngựa Cấp 80 (8x)"
	sub_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_tier.add_theme_font_size_override("font_size", 12)
	sub_tier.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	vb.add_child(sub_tier)

	# Mô tả thuộc tính
	var desc_lbl := Label.new()
	if is_5x:
		var lines := _base_lines(make_horse(int(h_data["level"]), 0, TIER_LONXON))
		desc_lbl.text = "Ngựa thường cấp 5, cưỡi được ngay.\n" + lines
	else:
		desc_lbl.text = str(h_data["desc"])
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(desc_lbl)

	# Nút Chọn Ngựa
	var btn_choose := Button.new()
	btn_choose.text = "🐎 CHỌN MÃ"
	btn_choose.custom_minimum_size = Vector2(0, 36)
	btn_choose.modulate = Color(1.0, 0.9, 0.3)
	btn_choose.pressed.connect(func(): _on_horse_selected(h_data))
	vb.add_child(btn_choose)

	return panel

func _on_horse_selected(h_data: Dictionary) -> void:
	if _profile == null:
		return

	var horse_lv: int = int(h_data.get("level", 1))
	_chosen_horse = horse_lv
	var horse_item := make_horse(horse_lv, int(_profile.get_element()) if _profile.has_method("get_element") else 0, _tier)

	if horse_item != null:
		_profile.equipment[Equipment.Part.HORSE] = horse_item
		_profile.riding = true
		if GameManager and GameManager.local_profile:
			GameManager.local_profile.equipment[Equipment.Part.HORSE] = horse_item
			GameManager.local_profile.riding = true

		_profile.equipment_changed.emit()
		if GameManager and GameManager.local_profile and GameManager.local_profile != _profile:
			GameManager.local_profile.equipment_changed.emit()

		# Cập nhật ngay lập tức tốc độ chạy và ngoại hình cưỡi ngựa lên nhân vật người chơi trong trận
		var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
		if tree != null:
			var player_node := tree.get_first_node_in_group("player")
			if player_node != null and is_instance_valid(player_node):
				if player_node.has_method("refresh_combat_stats"):
					player_node.refresh_combat_stats()
				elif player_node.has_method("refresh_appearance"):
					player_node.refresh_appearance()

	# Chuyển sang Đợt 2: Chọn Vũ Khí
	_render_step_2_weapons()

# ==============================================================================
# ĐỢT 2: CHỌN LOẠI VŨ KHÍ CẤP 10 DẠNG GRID (VŨ KHÍ TRẮNG)
# ==============================================================================
func _render_step_2_weapons() -> void:
	_step = 2
	var is_5x := _tier == TIER_LONXON
	if _title_label != null:
		_title_label.text = "⚔️ LỘN XỘN — CHỌN LOẠI VŨ KHÍ 5X (ĐỢT 2/2)" if is_5x else "⚔️ CHIẾN TRƯỜNG SINH TỒN — CHỌN LOẠI VŨ KHÍ CẤP 10 (ĐỢT 2/2)"
	if _sub_label != null:
		_sub_label.text = ("Hãy chọn vũ khí trắng cấp 5 (yêu cầu cấp 36) phù hợp môn phái — thiếu Sức / Thân thì tự cộng điểm tiềm năng cho đủ:"
			if is_5x else "Hãy chọn vũ khí trắng cấp 10 khởi đầu phù hợp với kỹ năng và môn phái của bạn:")

	if _cards_container == null:
		return

	for c in _cards_container.get_children():
		c.queue_free()
	if _action_bar != null:
		for b in _action_bar.get_children():
			b.queue_free()

	_weapon_cards.clear()
	_weapon_status_labels.clear()

	# Khung cuộn danh sách vũ khí dạng Grid (lưới)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 360.0)
	_cards_container.add_child(scroll)

	var center_box := CenterContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center_box)

	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	center_box.add_child(grid)

	for i in range(WEAPONS_10.size()):
		var w_data: Dictionary = WEAPONS_10[i]
		var card := _create_weapon_card(i, w_data)
		grid.add_child(card)

	_refresh_weapon_cards_visual()

	# Nút xác nhận xuất trận
	var btn_confirm := Button.new()
	btn_confirm.text = "⚔️ XÁC NHẬN TRANG BỊ & XUẤT TRẬN"
	btn_confirm.custom_minimum_size = Vector2(280, 42)
	btn_confirm.modulate = Color(0.3, 1.2, 0.5)
	btn_confirm.pressed.connect(_on_weapon_confirmed)
	_action_bar.add_child(btn_confirm)

func _create_weapon_card(index: int, w_data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(118.0, 140.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var w_lv := weapon_level(_tier)
	var w_name := weapon_name(index, _tier)
	panel.tooltip_text = "%s - Cấp %d\n%s" % [w_name, w_lv, w_data.get("desc", "")]

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# 1. Hình ảnh / icon vũ khí
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	var base_entry := ItemDatabase.get_base(ItemDatabase.find_base(int(w_data["detail"]), int(w_data["particular"]), w_lv))
	if not base_entry.is_empty():
		icon_rect.texture = ItemDatabase.get_icon(base_entry, true)
	vbox.add_child(icon_rect)

	# 2. Tên vũ khí (Vũ khí trắng: chữ màu trắng trang nhã)
	var name_lbl := Label.new()
	name_lbl.text = w_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(name_lbl)

	# 3. Cấp độ: "Cấp 10"
	var lv_lbl := Label.new()
	lv_lbl.text = "Cấp %d" % w_lv
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_font_size_override("font_size", 11)
	lv_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.85))
	vbox.add_child(lv_lbl)

	# 4. Trạng thái đã chọn (badge)
	var status_lbl := Label.new()
	status_lbl.text = "✓ Đã chọn"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	vbox.add_child(status_lbl)

	_weapon_cards.append(panel)
	_weapon_status_labels.append(status_lbl)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_weapon(index)
			if event.double_click:
				_on_weapon_confirmed()
	)

	return panel

func _select_weapon(index: int) -> void:
	_selected_weapon_idx = index
	_refresh_weapon_cards_visual()

func _refresh_weapon_cards_visual() -> void:
	for i in range(_weapon_cards.size()):
		var card := _weapon_cards[i]
		if card == null or not is_instance_valid(card):
			continue
		var is_sel := (i == _selected_weapon_idx)
		var sb := StyleBoxFlat.new()
		if is_sel:
			sb.bg_color = Color(0.20, 0.23, 0.29, 0.98)
			sb.border_width_bottom = 2
			sb.border_width_top = 2
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.border_color = Color(1.0, 0.85, 0.25, 1.0)
		else:
			sb.bg_color = Color(0.12, 0.13, 0.16, 0.90)
			sb.border_width_bottom = 1
			sb.border_width_top = 1
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_color = Color(0.3, 0.35, 0.4, 0.5)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", sb)

		if i < _weapon_status_labels.size():
			var lbl := _weapon_status_labels[i]
			if lbl != null and is_instance_valid(lbl):
				lbl.visible = is_sel

func _on_weapon_confirmed() -> void:
	if _profile == null:
		return

	if _selected_weapon_idx < 0 or _selected_weapon_idx >= WEAPONS_10.size():
		_selected_weapon_idx = 0

	var weapon_item := make_weapon(_selected_weapon_idx, int(_profile.get_element()) if _profile.has_method("get_element") else 0, _tier)
	## Online: đồ do server sinh (hồ sơ tạm của trận) — báo lựa chọn để server trang bị đúng món (đồ máy tự sinh server không nhận).
	var draft := {"horse": _chosen_horse, "weapon": _selected_weapon_idx}
	if _tier == TIER_LONXON:
		lonxon_pending_draft = draft
		auto_meet_weapon(_profile, weapon_item)   ## 5x: tự cộng Sức / Thân vừa đủ cầm vũ khí (server làm lại y hệt)
	else:
		PubgManager.pending_draft = draft

	if weapon_item != null:
		_profile.equipment[Equipment.Part.WEAPON] = weapon_item
		if GameManager and GameManager.local_profile:
			GameManager.local_profile.equipment[Equipment.Part.WEAPON] = weapon_item
		_profile.equipment_changed.emit()
		if GameManager and GameManager.local_profile and GameManager.local_profile != _profile:
			GameManager.local_profile.equipment_changed.emit()

		var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
		if tree != null:
			var player_node := tree.get_first_node_in_group("player")
			if player_node != null and is_instance_valid(player_node):
				if player_node.has_method("refresh_combat_stats"):
					player_node.refresh_combat_stats()
				elif player_node.has_method("refresh_appearance"):
					player_node.refresh_appearance()

	# Báo hoàn thành và đóng popup
	draft_completed.emit()
	if _on_finish.is_valid():
		_on_finish.call()
	queue_free()

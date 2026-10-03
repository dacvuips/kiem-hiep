extends Control
class_name CharacterStatusScreen
## Panel "Trang Bị Và Thuộc Tính" — bảng chỉ số cốt lõi nhân vật đầy đủ theo đúng UiStatus.ini gốc
## của Võ Lâm Truyền Kỳ (4 chỉ số gốc cộng tay bằng điểm tiềm năng, HP/MP/Thể lực, sát thương tay
## trái/phải, công/thủ/chính xác/né tránh, tốc độ, 5 kháng theo Ngũ Hành). Panel trang bị bên phải
## (ô mặt nạ/vũ khí/trang sức...) CHƯA dựng — game chưa có hệ trang bị, chỉ hiện placeholder.
##
## NHÚNG THƯỜNG TRỰC trong CharacterHubScreen (không phải popup/overlay) — không có nền dim, không
## có nút Đóng, luôn hiển thị cùng lúc với nền phong cảnh + menu phải khi ở màn Hub.
##
## Vị trí/anchor của mọi Label/Button/Panel nằm trong CharacterStatusScreen.tscn (kéo thả được
## trong Godot editor) — script này CHỈ gán style (màu/font/bold) và text động, không tự tạo node
## bằng code nữa. Muốn chỉnh vị trí, sửa trực tiếp trong scene bằng editor; muốn chỉnh màu/cỡ chữ,
## sửa các hằng COLOR_*/font_size bên dưới.

const GOLD := Color(0.83, 0.68, 0.21)
## Nhãn (tên chỉ số) dùng trắng ngà. COLOR_INFO (trắng/kem, đậm hơn nhãn 1 chút) cho khối "Thông
## tin chung" (Tên/Xưng hiệu/Phúc duyên/Danh vọng/Đẳng cấp/Xếp hạng/Kinh nghiệm), COLOR_VALUE (vàng
## đậm) cho 4 chỉ số gốc + mọi derived stat (Lực tay/Chính xác/Né tránh/Chạy/Công kích/kháng Ngũ
## Hành).
const COLOR_LABEL := Color(0.88, 0.87, 0.83)
const COLOR_INFO := Color(0.95, 0.94, 0.9)
const COLOR_VALUE := Color(0.98, 0.78, 0.12)
const COLOR_HP := Color(0.9, 0.25, 0.2)
const COLOR_MANA := Color(0.3, 0.55, 0.95)
const COLOR_STAMINA := Color(0.35, 0.8, 0.35)
const COLOR_POTENTIAL := Color(0.95, 0.25, 0.2)
const COLOR_DIM := Color(0.65, 0.6, 0.5)

## Phát khi chính panel này đổi profile (cộng điểm tiềm năng, tháo đồ) — map đánh quái nghe để áp
## chỉ số mới lên nhân vật đang đứng trong trận.
signal profile_changed

var _profile: PlayerProfile
## Ai mở Hành trang khi bấm nút "Hành trang"/ô trống. Rỗng = popup modal mặc định (màn Hub). Map đánh
## quái gán hàm riêng để mở khung Hành trang không modal, cùng lúc với khung Nhân vật.
var inventory_opener: Callable

## Tạo và gắn panel này (instantiate từ CharacterStatusScreen.tscn) làm con của `parent` (VD
## %Board của CharacterHubScreen), phủ kín rect chỉ định bằng anchor tỉ lệ.
static func attach(parent: Control, profile: PlayerProfile) -> CharacterStatusScreen:
	var scene: PackedScene = load("res://ui/character_status/CharacterStatusScreen.tscn")
	var screen: CharacterStatusScreen = scene.instantiate()
	screen._profile = profile
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(screen)
	return screen

func _ready() -> void:
	_style_info_box()
	_style_resource_box()
	_style_exp_box()
	_style_base_stat_box()
	_style_derived_box()
	_style_equipment_slots()

	## _profile chỉ được gán khi tạo qua attach() (xem character_hub.gd) — nếu scene này bị chạy
	## trực tiếp trong editor (F6 "Run Current Scene") hoặc instantiate() mà không gọi attach(),
	## _profile là null và refresh() sẽ crash ngay ở get_combat_stats(). Bỏ qua an toàn thay vì crash.
	if _profile == null:
		push_warning("CharacterStatusScreen: _profile chưa được gán — bỏ qua refresh(). Scene này phải tạo qua CharacterStatusScreen.attach(), không chạy trực tiếp.")
		return

	refresh()

## Khối trên cùng: Tên/Xưng hiệu, Phúc duyên/Danh vọng, Đẳng cấp/Xếp hạng — giá trị màu TRẮNG/kem
## (COLOR_INFO) và ĐẬM, khác khối chỉ số bên dưới dùng cam/vàng (COLOR_VALUE), đúng phân cấp màu
## trong ảnh mockup gốc. Tên nhân vật to nhất (18) + đậm, các dòng còn lại 13 + đậm.
func _style_info_box() -> void:
	_style_label(%LabelTen, "Tên:", COLOR_LABEL, 15)
	_style_label(%NameValue, "", COLOR_INFO, 18, HORIZONTAL_ALIGNMENT_LEFT, true)

	_style_label(%LabelXungHieu, "Xưng hiệu:", COLOR_LABEL, 13)
	_style_label(%TitleValue, "", COLOR_INFO, 13, HORIZONTAL_ALIGNMENT_LEFT, true)

	_style_label(%LabelPhucDuyen, "Phúc duyên:", COLOR_LABEL, 13)
	_style_label(%FuyuanValue, "0", COLOR_INFO, 13, HORIZONTAL_ALIGNMENT_LEFT, true)
	_style_label(%LabelDanhVong, "Danh vọng:", COLOR_LABEL, 13)
	_style_label(%PrestigeValue, "0", COLOR_INFO, 13, HORIZONTAL_ALIGNMENT_LEFT, true)

	_style_label(%LabelDangCap, "Đẳng cấp:", COLOR_LABEL, 13)
	_style_label(%LevelValue, "1", COLOR_INFO, 13, HORIZONTAL_ALIGNMENT_LEFT, true)
	_style_label(%LabelXepHang, "Xếp hạng:", COLOR_LABEL, 13)
	_style_label(%RankValue, "?", COLOR_INFO, 13, HORIZONTAL_ALIGNMENT_LEFT, true)

## Khối giữa: ô chân dung (nhân vật ghép bộ phận mặc đúng đồ đang mặc, tự xoay; bấm để xoay ngay) + Sinh lực/
## Nội lực/Thể lực + Thuộc tính (hệ ngũ hành).
func _style_resource_box() -> void:
	_setup_portrait()
	var portrait_hint: Label = %PortraitHint
	portrait_hint.text = "Nhấp vào đây để\nchọn hình dáng"
	portrait_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	portrait_hint.add_theme_font_size_override("font_size", 12)
	portrait_hint.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25))

	## Mỗi dòng có nền riêng pha theo màu giá trị của chính dòng đó (đỏ/lam/lục/vàng) thay vì 1
	## khối nền tối đơn sắc phủ chung — alpha thấp để không chói, vẫn tách rõ khỏi nền ảnh phía sau.
	_style_row_bg(%RowBgLife, COLOR_HP)
	_style_label(%LabelSinhLuc, "Sinh lực:", COLOR_LABEL, 13)
	_style_label(%LifeValue, "", COLOR_HP, 13, HORIZONTAL_ALIGNMENT_RIGHT)

	_style_row_bg(%RowBgMana, COLOR_MANA)
	_style_label(%LabelNoiLuc, "Nội lực:", COLOR_LABEL, 13)
	_style_label(%ManaValue, "", COLOR_MANA, 13, HORIZONTAL_ALIGNMENT_RIGHT)

	_style_row_bg(%RowBgStamina, COLOR_STAMINA)
	_style_label(%LabelTheLuc, "Thể lực:", COLOR_LABEL, 13)
	_style_label(%StaminaValue, "", COLOR_STAMINA, 13, HORIZONTAL_ALIGNMENT_RIGHT)

	_style_row_bg(%RowBgElement, COLOR_VALUE)
	_style_label(%LabelThuocTinh, "Thuộc tính:", COLOR_LABEL, 13)
	_style_label(%ElementValue, "", COLOR_VALUE, 13, HORIZONTAL_ALIGNMENT_LEFT, true)

func _style_exp_box() -> void:
	_style_label(%LabelKinhNghiem, "Kinh nghiệm:", COLOR_LABEL, 12)
	_style_label(%ExpValue, "", COLOR_INFO, 12, HORIZONTAL_ALIGNMENT_RIGHT, true)

## 4 chỉ số gốc 2x2 (Sức mạnh/Thân pháp/Sinh khí/Nội công) — mỗi ô có nút [+] cộng điểm tiềm năng,
## rồi 2 hàng "Lực tay trái/phải" (sát thương ước lượng theo Strength).
func _style_base_stat_box() -> void:
	var stat_labels := ["Sức mạnh:", "Thân pháp:", "Sinh khí:", "Nội công:"]
	var stat_names := ["SucManh", "ThanPhap", "SinhKhi", "NoiCong"]
	for i in 4:
		_style_label(get_node("%%Label%s" % stat_names[i]), stat_labels[i], COLOR_LABEL, 13)
		_style_label(get_node("%%BaseStatValue%d" % i), "", COLOR_VALUE, 14, HORIZONTAL_ALIGNMENT_LEFT, true)
		## Kiểu dáng nút [+] (nền đỏ, chữ 12, không lề trong) đặt SẴN trong scene — không gán bằng code nữa,
		## để trong editor nút cũng nhỏ như lúc chạy; gán bằng code thì kéo nút trong editor sẽ lưu chiều
		## cao theo theme mặc định (chữ 16 + lề) và nút lại bị cao.
		var add_button: Button = get_node("%%BaseStatButton%d" % i)
		add_button.pressed.connect(_on_add_stat_pressed.bind(i))

	_style_label(%LabelLucTayTrai, "Lực tay trái:", COLOR_LABEL, 13)
	_style_label(%DamageLeftValue, "", COLOR_VALUE, 13, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_style_label(%LabelLucTayPhai, "Lực tay phải:", COLOR_LABEL, 13)
	_style_label(%DamageRightValue, "", COLOR_VALUE, 13, HORIZONTAL_ALIGNMENT_RIGHT, true)

## Khối cuối 4x2: Chính xác/Phòng thủ, Né tránh/Kháng Kim(Hàn thay), Chạy/Kháng..., Công kích/
## Kháng..., Tiềm năng/Kháng... — cột trái là derived thường, cột phải là 5 kháng Ngũ Hành (dùng dư
## 1 hàng vì VLTK gốc chỉ có 4 kháng, ở đây có đúng 5 hệ Kim/Mộc/Thủy/Hỏa/Thổ).
func _style_derived_box() -> void:
	var left_labels_text := ["Chính xác:", "Né tránh:", "Chạy:", "Công kích:", "Tiềm năng:"]
	var left_names := ["ChinhXac", "NeTranh", "Chay", "CongKich", "TiemNang"]
	var right_labels_text := ["Kháng Kim:", "Kháng Mộc:", "Kháng Thủy:", "Kháng Hỏa:", "Kháng Thổ:"]
	var right_names := ["KhangKim", "KhangMoc", "KhangThuy", "KhangHoa", "KhangTho"]

	for i in 5:
		## "Tiềm năng" (i==4) là điểm nhấn quan trọng nhất trong khối này — to hơn (16 so với 13)
		## và đậm, khớp ảnh mockup ("500" đỏ nổi bật hẳn các số khác).
		var is_potential := i == 4
		var value_color := COLOR_POTENTIAL if is_potential else COLOR_VALUE
		var value_size := 16 if is_potential else 13

		_style_label(get_node("%%Label%s" % left_names[i]), left_labels_text[i], COLOR_LABEL, 13)
		_style_label(get_node("%%%sValue" % left_names[i]), "", value_color, value_size, HORIZONTAL_ALIGNMENT_RIGHT, true)

		_style_label(get_node("%%Label%s" % right_names[i]), right_labels_text[i], COLOR_LABEL, 13)
		_style_label(get_node("%%ResistValue%d" % i), "", COLOR_VALUE, 13, HORIZONTAL_ALIGNMENT_RIGHT, true)

func refresh() -> void:
	var s := _profile.get_combat_stats()

	(%NameValue as Label).text = _profile.display_name
	(%TitleValue as Label).text = _profile.title if not _profile.title.is_empty() else "—"
	(%FuyuanValue as Label).text = str(_profile.fuyuan)
	(%PrestigeValue as Label).text = str(_profile.prestige)
	(%LevelValue as Label).text = str(_profile.level)
	(%RankValue as Label).text = _profile.world_rank if not _profile.world_rank.is_empty() else "—"

	(%LifeValue as Label).text = "%d/%d" % [s.max_hp, s.max_hp]
	(%ManaValue as Label).text = "%d/%d" % [s.max_mana, s.max_mana]
	(%StaminaValue as Label).text = "%d/%d" % [_profile.stamina, _profile.max_stamina]
	(%ElementValue as Label).text = ElementTypes.ELEMENT_NAME.get(_sect_element(), "—")

	(%ExpValue as Label).text = "%s/%s" % [_format_number(_profile.current_exp), _format_number(_profile.get_exp_to_next_level())]

	var base_stats := [_profile.strength, _profile.dexterity, _profile.vitality, _profile.energy]
	for i in base_stats.size():
		(get_node("%%BaseStatValue%d" % i) as Label).text = str(base_stats[i])
		(get_node("%%BaseStatButton%d" % i) as Button).disabled = _profile.potential_points <= 0

	(%DamageLeftValue as Label).text = "%d/%d" % [s.unarmed_min_damage, s.unarmed_max_damage]
	(%DamageRightValue as Label).text = "%d/%d" % [s.unarmed_min_damage, s.unarmed_max_damage]

	## "Chính xác"/"Né tránh" giờ hiển thị ĐÚNG khái niệm VLTK gốc: AttackRating (quyết định % TRÚNG
	## đòn của chính nhân vật) và Defense (quyết định % NÉ ĐƯỢC đòn đối phương) — không còn 2 chỉ số
	## rời rạc "accuracy"/"evasion" tự chế như bản cũ (xem CombatFormulas.calc_hit_percent).
	(%ChinhXacValue as Label).text = str(s.attack_rating)
	(%NeTranhValue as Label).text = str(s.defense)
	(%ChayValue as Label).text = str(100 + s.dexterity)
	(%CongKichValue as Label).text = "%d/%d" % [s.unarmed_min_damage, s.unarmed_max_damage]
	(%TiemNangValue as Label).text = str(_profile.potential_points)

	var elements := [ElementTypes.ElementType.KIM, ElementTypes.ElementType.MOC,
			ElementTypes.ElementType.THUY, ElementTypes.ElementType.HOA, ElementTypes.ElementType.THO]
	var element_to_damage_type := {
		ElementTypes.ElementType.KIM: CombatFormulas.DamageType.PHYSICS,
		ElementTypes.ElementType.MOC: CombatFormulas.DamageType.LIGHT,
		ElementTypes.ElementType.THUY: CombatFormulas.DamageType.COLD,
		ElementTypes.ElementType.HOA: CombatFormulas.DamageType.FIRE,
		ElementTypes.ElementType.THO: CombatFormulas.DamageType.POISON,
	}
	for i in elements.size():
		var dmg_type: CombatFormulas.DamageType = element_to_damage_type[elements[i]]
		(get_node("%%ResistValue%d" % i) as Label).text = "%d%%" % s.get_capped_resist(dmg_type)
	_refresh_equipment_slots()
	_refresh_portrait()

# ---------------------------------------------------------------- chân dung

## Giây giữa 2 lần tự xoay 1 hướng (8 hướng -> 1 vòng ~ 12 giây).
const PORTRAIT_TURN_SECONDS := 1.5
var _portrait_timer: Timer

func _setup_portrait() -> void:
	var box: Control = %PortraitBox
	box.resized.connect(_place_portrait)
	box.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_turn_portrait()
			_portrait_timer.start())
	_portrait_timer = Timer.new()
	_portrait_timer.wait_time = PORTRAIT_TURN_SECONDS
	_portrait_timer.timeout.connect(_turn_portrait)
	add_child(_portrait_timer)
	_portrait_timer.start()
	%PortraitHint.visible = false
	_place_portrait()

## Chân nhân vật ở giữa đáy ô (gốc CharacterAvatar = chân).
func _place_portrait() -> void:
	var box: Control = %PortraitBox
	(%PortraitAvatar as Node2D).position = Vector2(box.size.x * 0.5, box.size.y - 8.0)

func _turn_portrait() -> void:
	var avatar: CharacterAvatar = %PortraitAvatar
	avatar.face(Vector2.DOWN.rotated(deg_to_rad(45.0 * ((avatar.direction + 1) % 8))))

func _refresh_portrait() -> void:
	var look := Equipment.get_appearance(_profile.equipment)
	var avatar: CharacterAvatar = %PortraitAvatar
	avatar.set_appearance(look["helm"], look["armor"], look["weapon"], look["horse"])

# ---------------------------------------------------------------- trang bị

## 10 ô trang bị (%EquipSlot<Equipment.Part>) đặt sẵn trong scene đè lên ô vẽ trên khung ảnh, + nút
## bấm ô trống mở Hành trang (nút Hành trang riêng nằm ở menu "Trang Bị" màn Hub / nút "Hành trang" trong trận).
func _style_equipment_slots() -> void:
	for part in Equipment.Part.values():
		var slot: Button = get_node("%%EquipSlot%d" % part)
		slot.add_theme_font_size_override("font_size", 11)
		slot.add_theme_color_override("font_outline_color", Color.BLACK)
		slot.add_theme_constant_override("outline_size", 3)
		slot.pressed.connect(_on_equip_slot_pressed.bind(part))
		(slot as ItemSlotButton).filled_backdrop = Color(0.06, 0.05, 0.04, 0.96)

## Ô có đồ: hiện tên đồ màu theo phẩm chất + tooltip mô tả (dòng ẩn chưa kích hoạt xám); ô trống: trong.
func _refresh_equipment_slots() -> void:
	var sect := SectRegistry.get_by_id(_profile.sect_id)
	var series: int = sect.element if sect else ElementTypes.ElementType.KIM
	var counts := Equipment.get_active_counts(_profile.equipment, series)
	for part in Equipment.Part.values():
		var slot: ItemSlotButton = get_node("%%EquipSlot%d" % part)
		var item: ItemInstance = _profile.equipment.get(part)
		var bbcode := ItemText.build(item, _profile, counts.get(part, 0), part) if item else ""
		## Đồ đang mặc luôn có tác dụng (VLTK gốc) — không tô nền đỏ ở đây; nền đỏ chỉ ở Hành trang, nơi chặn
		## mặc. Dòng yêu cầu chưa đạt vẫn đỏ trong tooltip.
		slot.show_item(item, bbcode, Equipment.PART_NAMES[part])

func _on_equip_slot_pressed(part: int) -> void:
	var item: ItemInstance = _profile.equipment.get(part)
	if item == null:
		_open_inventory()
		return
	var sect := SectRegistry.get_by_id(_profile.sect_id)
	var counts := Equipment.get_active_counts(_profile.equipment, sect.element if sect else 0)
	ItemDetailPopup.open(get_tree().current_scene, ItemText.build(item, _profile, counts.get(part, 0), part, false),
		[["Tháo", func() -> void:
			if _profile.unequip(part):
				SaveManager.save_profile(_profile)
				refresh()
				profile_changed.emit()]], item)

func _open_inventory() -> void:
	if inventory_opener.is_valid():
		inventory_opener.call()
		return
	InventoryPopup.open(get_tree().current_scene, _profile, refresh)

func _sect_element() -> ElementTypes.ElementType:
	var sect := SectRegistry.get_by_id(_profile.sect_id)
	return sect.element if sect else ElementTypes.ElementType.THO

## Nút "+": mở popup nhập số điểm muốn cộng (không vượt số điểm tiềm năng đang có).
func _on_add_stat_pressed(stat_index: int) -> void:
	if _profile.potential_points <= 0:
		return
	PotentialPointPopup.open(get_tree().current_scene, _profile, stat_index, func(added: int) -> void:
		if added > 0:
			refresh()
			profile_changed.emit())

# ---------------------------------------------------------------- tiện ích

## Nền mờ 1 dòng, pha theo `accent` (màu chữ giá trị của chính dòng đó) — alpha thấp để không đè
## chữ, viền cùng tông đậm hơn 1 chút để tách khối rõ khỏi nền ảnh phía sau.
func _style_row_bg(panel: Panel, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

## Gán text/màu/cỡ chữ cho 1 Label đã có sẵn trong scene (vị trí/anchor do .tscn quyết định).
func _style_label(label: Label, text: String, color: Color, font_size: int, align := HORIZONTAL_ALIGNMENT_LEFT, bold := false) -> void:
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 2)
	if bold:
		## NotoSerif-Variable.ttf (gắn làm default_font toàn game qua assets/fonts/default_theme.tres)
		## là variable font có trục "wght" thật — dùng variation_opentype để lấy nét đậm chuẩn thay
		## vì embolden giả (méo nét, không đúng hình dáng chữ có dấu tiếng Việt).
		var font_variation := FontVariation.new()
		font_variation.base_font = ThemeDB.fallback_font
		font_variation.variation_opentype = {"wght": 700}
		label.add_theme_font_override("font", font_variation)

static func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > 3:
		result = "." + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result

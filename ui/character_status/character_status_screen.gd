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
const ICON_CHECK := preload("res://ui/login/icon_check.png")

## Phát khi chính panel này đổi profile (cộng điểm tiềm năng, tháo đồ) — map đánh quái nghe để áp
## chỉ số mới lên nhân vật đang đứng trong trận.
signal profile_changed

var _profile: PlayerProfile
var _disguise_banner: PanelContainer
var _disguise_label: Label
var _disguise_icon: TextureRect
var _custom_avatar_view: TextureRect
var _avatar_upload_box: PanelContainer
var _avatar_delete_btn: Button
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
	_sync_world_rank.call_deferred()

	## _profile chỉ được gán khi tạo qua attach() (xem character_hub.gd) — nếu scene này bị chạy
	## trực tiếp trong editor (F6 "Run Current Scene") hoặc instantiate() mà không gọi attach(),
	## _profile là null và refresh() sẽ crash ngay ở get_combat_stats(). Bỏ qua an toàn thay vì crash.
	if _profile == null:
		push_warning("CharacterStatusScreen: _profile chưa được gán — bỏ qua refresh(). Scene này phải tạo qua CharacterStatusScreen.attach(), không chạy trực tiếp.")
		return

	GmManager.profile_modified.connect(func(p: PlayerProfile) -> void:
		if p == null or p == _profile or p == GameManager.local_profile:
			refresh()
	)

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
	## Nhãn đúng bảng nhân vật VLTK gốc (UiStatus): Phòng thủ (vật lý), Kháng hàn, Kháng lôi, Kháng hỏa, Kháng độc.
	var right_labels_text := ["Phòng thủ:", "Kháng hàn:", "Kháng lôi:", "Kháng hỏa:", "Kháng độc:"]
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
	var title_parts := PackedStringArray()
	if not _profile.title.is_empty():
		title_parts.append(_profile.title)
	(%TitleValue as Label).text = " · ".join(title_parts) if not title_parts.is_empty() else "—"
	(%FuyuanValue as Label).text = str(_profile.fuyuan)
	(%PrestigeValue as Label).text = str(_profile.prestige)
	(%LevelValue as Label).text = str(_profile.level)
	(%RankValue as Label).text = _profile.world_rank if not _profile.world_rank.is_empty() else "—"

	var p_node := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	var cur_life := int(p_node.health) if (p_node and "health" in p_node) else s.max_hp
	var cur_mana := int(p_node.mana) if (p_node and "mana" in p_node) else s.max_mana
	(%LifeValue as Label).text = "%d/%d" % [cur_life, s.max_hp]
	(%ManaValue as Label).text = "%d/%d" % [cur_mana, s.max_mana]
	(%StaminaValue as Label).text = "%d/%d" % [_profile.stamina, _profile.max_stamina]
	(%ElementValue as Label).text = ElementTypes.ELEMENT_NAME.get(_sect_element(), "—")

	(%ExpValue as Label).text = "%s/%s" % [_format_number(_profile.current_exp), _format_number(_profile.get_exp_to_next_level())]

	var base_stats := [_profile.strength, _profile.dexterity, _profile.vitality, _profile.energy]
	for i in base_stats.size():
		(get_node("%%BaseStatValue%d" % i) as Label).text = str(base_stats[i])
		(get_node("%%BaseStatButton%d" % i) as Button).disabled = _profile.potential_points <= 0

	## Gốc: Lực tay trái = damage skill chuột trái (ở đây: đòn chính), phải = đòn đánh cơ bản (vật lý 0%, tức damage tay/vũ khí).
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	var left_info := SectSkillController.get_left_hand_info(_profile, player)
	var left_damage: Vector2i = left_info.damage
	var left_uses_ar: bool = left_info.use_ar
	(%DamageLeftValue as Label).text = "%d/%d" % [left_damage.x, left_damage.y]
	(%DamageRightValue as Label).text = "%d/%d" % [s.unarmed_min_damage, s.unarmed_max_damage]

	## "Chính xác"/"Né tránh" giờ hiển thị ĐÚNG khái niệm VLTK gốc: AttackRating (quyết định % TRÚNG
	## đòn của chính nhân vật) và Defense (quyết định % NÉ ĐƯỢC đòn đối phương) — không còn 2 chỉ số
	## rời rạc "accuracy"/"evasion" tự chế như bản cũ (xem CombatFormulas.calc_hit_percent).
	## Gốc (UiStatus): "Chính xác" = AttackRating của skill chuột trái/phải (hiện tại 2 bên cùng số); "Công kích" = tốc độ đánh/tốc độ
	## thi triển cộng thêm (0/0 lúc đầu); "Chạy" = tốc độ chạy (10).
	## Gốc: bên nào dùng skill KHÔNG tính trúng/trượt (IsUseAR = 0) thì hiện "-" thay cho chính xác.
	(%ChinhXacValue as Label).text = "%s/%d" % [str(s.attack_rating) if left_uses_ar else "-", s.attack_rating]
	(%NeTranhValue as Label).text = str(s.defense)
	(%ChayValue as Label).text = str(PLAYER_RUN_SPEED)
	(%CongKichValue as Label).text = "%d/%d" % [s.attack_speed, s.cast_speed]
	(%TiemNangValue as Label).text = str(_profile.potential_points)

	## Thứ tự hàng kháng theo bảng gốc: Phòng thủ, hàn, lôi, hỏa, độc.
	var resist_types := [CombatFormulas.DamageType.PHYSICS, CombatFormulas.DamageType.COLD, CombatFormulas.DamageType.LIGHT,
			CombatFormulas.DamageType.FIRE, CombatFormulas.DamageType.POISON]
	for i in resist_types.size():
		var dmg_type: CombatFormulas.DamageType = resist_types[i]
		(get_node("%%ResistValue%d" % i) as Label).text = "%d%%" % s.get_capped_resist(dmg_type)
	_refresh_equipment_slots()
	_refresh_portrait()

# ---------------------------------------------------------------- chân dung

## Tốc độ chạy hiển thị của nhân vật (m_CurrentRunSpeed gốc lúc đi bộ/chạy thường = 10).
const PLAYER_RUN_SPEED := 10

## Giây giữa 2 lần tự xoay 1 hướng (8 hướng -> 1 vòng ~ 12 giây).
const PORTRAIT_TURN_SECONDS := 1.5
var _portrait_timer: Timer

func _setup_portrait() -> void:
	var box: Control = %PortraitBox
	box.resized.connect(_place_portrait)

	# 1. TextureRect hiển thị ảnh đại diện tùy chỉnh (200x200 JPG) vừa vặn khung vuông
	if _custom_avatar_view == null:
		_custom_avatar_view = TextureRect.new()
		_custom_avatar_view.name = "CustomAvatarView"
		_custom_avatar_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_custom_avatar_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_custom_avatar_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_custom_avatar_view.mouse_filter = Control.MOUSE_FILTER_STOP
		_custom_avatar_view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_custom_avatar_view.tooltip_text = "Nhấp để thay đổi ảnh đại diện (200×200)"
		_custom_avatar_view.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_open_avatar_uploader()
		)
		box.add_child(_custom_avatar_view)

	# 2. Khung nút "Tải ảnh lên" khi chưa có ảnh
	if _avatar_upload_box == null:
		_avatar_upload_box = PanelContainer.new()
		_avatar_upload_box.name = "AvatarUploadBox"
		_avatar_upload_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_avatar_upload_box.mouse_filter = Control.MOUSE_FILTER_STOP
		_avatar_upload_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.08, 0.88)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.85, 0.7, 0.25, 0.6)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_right = 4
		sb.corner_radius_bottom_left = 4
		_avatar_upload_box.add_theme_stylebox_override("panel", sb)

		var v_box := VBoxContainer.new()
		v_box.alignment = BoxContainer.ALIGNMENT_CENTER
		v_box.add_theme_constant_override("separation", 4)
		_avatar_upload_box.add_child(v_box)

		var icon_lbl := Label.new()
		icon_lbl.text = "📷"
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 22)
		v_box.add_child(icon_lbl)

		var upload_lbl := Label.new()
		upload_lbl.text = "Tải ảnh lên"
		upload_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upload_lbl.add_theme_font_size_override("font_size", 13)
		upload_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		v_box.add_child(upload_lbl)

		var sub_lbl := Label.new()
		sub_lbl.text = "(200×200 px)"
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 10)
		sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		v_box.add_child(sub_lbl)

		_avatar_upload_box.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_open_avatar_uploader()
		)
		box.add_child(_avatar_upload_box)

	# 3. Nút "X" góc trên để xóa ảnh đại diện khi đã có ảnh
	if _avatar_delete_btn == null:
		_avatar_delete_btn = Button.new()
		_avatar_delete_btn.name = "AvatarDeleteBtn"
		_avatar_delete_btn.text = "✕"
		_avatar_delete_btn.custom_minimum_size = Vector2(22, 22)
		_avatar_delete_btn.size = Vector2(22, 22)
		_avatar_delete_btn.tooltip_text = "Xóa ảnh đại diện"
		_avatar_delete_btn.focus_mode = Control.FOCUS_NONE
		_avatar_delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var b_style := StyleBoxFlat.new()
		b_style.bg_color = Color(0.85, 0.15, 0.15, 0.9)
		b_style.corner_radius_top_left = 11
		b_style.corner_radius_top_right = 11
		b_style.corner_radius_bottom_right = 11
		b_style.corner_radius_bottom_left = 11
		_avatar_delete_btn.add_theme_stylebox_override("normal", b_style)
		_avatar_delete_btn.add_theme_color_override("font_color", Color.WHITE)
		_avatar_delete_btn.add_theme_font_size_override("font_size", 11)

		_avatar_delete_btn.pressed.connect(_on_delete_avatar_pressed)
		box.add_child(_avatar_delete_btn)

	_portrait_timer = Timer.new()
	_portrait_timer.wait_time = PORTRAIT_TURN_SECONDS
	_portrait_timer.timeout.connect(_turn_portrait)
	add_child(_portrait_timer)

	%PortraitHint.visible = false
	_place_portrait()

func _open_avatar_uploader() -> void:
	CustomAvatarHelper.pick_image_file(self, func(img: Image) -> void:
		if img == null:
			SocialWindow.info(self, "Lỗi Tải Ảnh", "Không thể nạp tệp hình ảnh vừa chọn. Vui lòng thử chọn tệp khác (JPG, PNG, WEBP).")
			return
		AvatarCropPopup.open(self, img, func(jpg_bytes: PackedByteArray) -> void:
			if jpg_bytes.is_empty():
				return
			if _profile:
				_profile.set_custom_avatar_from_jpg(jpg_bytes)
				CustomAvatarHelper.save_avatar_cache(_profile.display_name, SaveManager.online_character_id, jpg_bytes)
				SaveManager.save_profile(_profile)
				SaveManager.flush_online()
			if _custom_avatar_view:
				var res_img := CustomAvatarHelper.load_image_from_bytes(jpg_bytes)
				if res_img:
					_custom_avatar_view.texture = ImageTexture.create_from_image(res_img)
			_refresh_portrait()
			SocialWindow.info(self, "Thành Công", "Đã cập nhật ảnh đại diện nhân vật (200×200 JPG) thành công!")
		)
	)

func _on_delete_avatar_pressed() -> void:
	SocialWindow.ask_yes_no(self, "Xóa Ảnh Đại Diện", "Bạn có chắc chắn muốn xóa ảnh đại diện này không?", func(yes: bool) -> void:
		if yes:
			if _profile:
				_profile.clear_custom_avatar()
				CustomAvatarHelper.delete_avatar_cache(_profile.display_name, SaveManager.online_character_id)
				SaveManager.save_profile(_profile)
				SaveManager.flush_online()
			_refresh_portrait()
	)

## Chân nhân vật ở giữa đáy ô (gốc CharacterAvatar = chân).
func _place_portrait() -> void:
	var box: Control = %PortraitBox
	if has_node("%PortraitAvatar"):
		(%PortraitAvatar as Node2D).position = Vector2(box.size.x * 0.5, box.size.y - 8.0)
	if _disguise_icon:
		_disguise_icon.position = Vector2(box.size.x - 24.0, 4.0)
	if _avatar_delete_btn:
		_avatar_delete_btn.position = Vector2(box.size.x - 26.0, 4.0)

func _turn_portrait() -> void:
	var avatar: CharacterAvatar = %PortraitAvatar
	avatar.face(Vector2.DOWN.rotated(deg_to_rad(45.0 * ((avatar.direction + 1) % 8))))

func _setup_disguise_ui() -> void:
	if not has_node("%PortraitBox"):
		return
	var box: Control = %PortraitBox
	if _disguise_banner == null:
		_disguise_banner = PanelContainer.new()
		_disguise_banner.name = "DisguiseBanner"
		_disguise_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disguise_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_disguise_banner.offset_top = -24.0
		_disguise_banner.offset_bottom = 0.0
		_disguise_banner.offset_left = 2.0
		_disguise_banner.offset_right = -2.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.04, 0.08, 0.92)
		sb.border_width_top = 1
		sb.border_color = Color(0.85, 0.7, 0.25, 0.9)
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		_disguise_banner.add_theme_stylebox_override("panel", sb)

		_disguise_label = Label.new()
		_disguise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_disguise_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_disguise_label.add_theme_font_size_override("font_size", 11)
		_disguise_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
		_disguise_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_disguise_label.add_theme_constant_override("outline_size", 3)
		_disguise_banner.add_child(_disguise_label)
		box.add_child(_disguise_banner)

	if _disguise_icon == null:
		_disguise_icon = TextureRect.new()
		_disguise_icon.name = "DisguiseIcon"
		_disguise_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_disguise_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_disguise_icon.custom_minimum_size = Vector2(20, 20)
		_disguise_icon.size = Vector2(20, 20)
		_disguise_icon.position = Vector2(box.size.x - 24.0, 4.0)
		box.add_child(_disguise_icon)

func _refresh_portrait() -> void:
	if not has_node("%PortraitAvatar") or _profile == null:
		return
	_setup_disguise_ui()

	if not _profile.has_custom_avatar() and _profile.display_name != "":
		var cached := CustomAvatarHelper.get_avatar_base64_cache(_profile.display_name, SaveManager.online_character_id)
		if cached != "":
			_profile.custom_avatar = cached

	var has_custom: bool = _profile.has_custom_avatar()
	if has_custom:
		var tex: ImageTexture = _profile.get_custom_avatar_texture()
		if tex and _custom_avatar_view:
			_custom_avatar_view.texture = tex
			_custom_avatar_view.visible = true
			if _avatar_upload_box:
				_avatar_upload_box.visible = false
			if _avatar_delete_btn:
				_avatar_delete_btn.visible = true
				_avatar_delete_btn.move_to_front()
			(%PortraitAvatar as Node2D).visible = false
			if _portrait_timer and not _portrait_timer.is_stopped():
				_portrait_timer.stop()
	else:
		# Chưa có ảnh -> hiển thị ô "Tải ảnh lên"
		if _custom_avatar_view:
			_custom_avatar_view.visible = false
		if _avatar_upload_box:
			_avatar_upload_box.visible = true
			_avatar_upload_box.move_to_front()
		if _avatar_delete_btn:
			_avatar_delete_btn.visible = false
		(%PortraitAvatar as Node2D).visible = false
		if _portrait_timer and not _portrait_timer.is_stopped():
			_portrait_timer.stop()

	# Cập nhật hiển thị dịch dung (nếu có mặt nạ)
	var gender_str := "female" if _profile.gender == PlayerProfile.Gender.FEMALE else "male"
	var look := Equipment.get_appearance(_profile.equipment, gender_str, _profile.riding, _profile.show_mask)
	var is_masked: bool = bool(look.get("is_masked", false))
	if _disguise_banner:
		_disguise_banner.visible = is_masked
		if is_masked:
			_disguise_label.text = "🎭 %s" % str(look.get("disguise_title", "Dịch Dung"))
			_disguise_banner.move_to_front()
	if _disguise_icon:
		_disguise_icon.visible = is_masked
		if is_masked:
			_disguise_icon.texture = look.get("mask_icon")
			_disguise_icon.tooltip_text = "Đang dịch dung: %s" % str(look.get("mask_name", ""))
			_disguise_icon.move_to_front()

# ---------------------------------------------------------------- trang bị

## 13 ô trang bị (%EquipSlot<Equipment.Part>) đặt sẵn trong scene đè lên ô vẽ trên khung ảnh, + nút
## bấm ô trống mở Hành trang (nút Hành trang riêng nằm ở menu "Trang Bị" màn Hub / nút "Hành trang" trong trận).
func _style_equipment_slots() -> void:
	if has_node("%MaskVisualCheck"):
		%MaskVisualCheck.toggled.connect(_on_mask_visual_check_toggled)
	for part in Equipment.Part.values():
		var slot: Button = get_node_or_null("%%EquipSlot%d" % part)
		if slot == null:
			continue
		slot.add_theme_font_size_override("font_size", 11)
		slot.add_theme_color_override("font_outline_color", Color.BLACK)
		slot.add_theme_constant_override("outline_size", 3)
		slot.pressed.connect(_on_equip_slot_pressed.bind(part))
		(slot as ItemSlotButton).filled_backdrop = Color(0.06, 0.05, 0.04, 0.96)

## Ô có đồ: hiện tên đồ màu theo phẩm chất + tooltip mô tả (dòng ẩn chưa kích hoạt xám); ô trống: trong.
func _refresh_equipment_slots() -> void:
	var series: int = _profile.get_element()
	var counts := Equipment.get_active_counts(_profile.equipment, series)
	for part in Equipment.Part.values():
		var slot: ItemSlotButton = get_node_or_null("%%EquipSlot%d" % part)
		if slot == null:
			continue
		var item: ItemInstance = _profile.equipment.get(part)
		var bbcode := ItemText.build(item, _profile, counts.get(part, 0), part) if item else ""
		## Đồ đang mặc luôn có tác dụng (VLTK gốc) — không tô nền đỏ ở đây; nền đỏ chỉ ở Hành trang, nơi chặn
		## mặc. Dòng yêu cầu chưa đạt vẫn đỏ trong tooltip.
		slot.show_item(item, bbcode, Equipment.PART_NAMES.get(part, ""))
	_refresh_mask_check()

func _refresh_mask_check() -> void:
	if not has_node("%MaskVisualCheck") or _profile == null:
		return
	var btn: Button = %MaskVisualCheck
	var mask_item: ItemInstance = _profile.equipment.get(Equipment.Part.MASK)
	if mask_item == null:
		btn.disabled = true
		btn.button_pressed = false
		btn.icon = null
		btn.tooltip_text = "Chưa đeo mặt nạ"
	else:
		btn.disabled = false
		btn.set_pressed_no_signal(_profile.show_mask)
		btn.icon = ICON_CHECK if _profile.show_mask else null
		btn.tooltip_text = "Ngoại hình mặt nạ: Đang bật\n(Bấm để tắt hiển thị giao diện bên ngoài)" if _profile.show_mask else "Ngoại hình mặt nạ: Đang tắt\n(Bấm để mở hiển thị giao diện bên ngoài)"

func _on_mask_visual_check_toggled(pressed: bool) -> void:
	if _profile == null:
		return
	_profile.show_mask = pressed
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	refresh()
	profile_changed.emit()

func _host() -> Node:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree != null else null

func _on_equip_slot_pressed(part: int) -> void:
	var item: ItemInstance = _profile.equipment.get(part)
	if item == null:
		_open_inventory()
		return
	var counts := Equipment.get_active_counts(_profile.equipment, _profile.get_element())
	ItemDetailPopup.open(_host(), ItemText.build(item, _profile, counts.get(part, 0), part, false),
		[["Tháo", func() -> void:
			if _profile.unequip(part):
				SaveManager.save_profile(_profile)
				refresh()
				profile_changed.emit()]], item)

func _open_inventory() -> void:
	if inventory_opener.is_valid():
		inventory_opener.call()
		return
	InventoryPopup.open(_host(), _profile, refresh)

func _sect_element() -> ElementTypes.ElementType:
	return _profile.get_element()

## Nút "+": mở popup nhập số điểm muốn cộng (không vượt số điểm tiềm năng đang có).
func _on_add_stat_pressed(stat_index: int) -> void:
	if _profile.potential_points <= 0:
		return
	PotentialPointPopup.open(_host(), _profile, stat_index, func(added: int) -> void:
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
	GameUi.fit_label(label, font_size)   ## ô vẽ sẵn trên ảnh khung: chữ dài thì thu nhỏ cho vừa
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 2)
	if bold:
		## Chữ đậm: bản đậm giả của font trong game (GameUi.game_font_bold).
		label.add_theme_font_override("font", _bold_font())


static func _bold_font() -> Font:
	return GameUi.game_font_bold()   ## chữ đậm trong game: font chung GameUi

static func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > 3:
		result = "." + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result

func _sync_world_rank() -> void:
	if _profile == null:
		return
	var rank_str := await RankingWindow.fetch_my_rank(_profile)
	if not rank_str.is_empty() and rank_str != "—":
		_profile.world_rank = rank_str
		if has_node("%RankValue"):
			(%RankValue as Label).text = _profile.world_rank

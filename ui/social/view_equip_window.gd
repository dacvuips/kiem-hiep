extends SocialWindow
class_name ViewEquipWindow
## XEM TRANG BỊ của người chơi khác (màn "xem trang bị" — c2s_viewequip gốc): hình nhân vật + thông tin cơ bản bên trái,
## giao diện "Trang bị" chuẩn VLTK (hình người mẫu mannequin + 13 ô trang bị theo vị trí chuẩn) bên phải.
## Bấm ô có đồ để xem chi tiết (chỉ xem, không có nút trang bị/vứt). Dữ liệu là BẢN SAO từ ViewEquipService.

const TEX_EQUIP_BG_MALE := preload("res://assets/ui/bo_icon_nhan_vat/trang_bi/trang_bi_nam.png")
const TEX_EQUIP_BG_FEMALE := preload("res://assets/ui/bo_icon_nhan_vat/trang_bi/trang_bi_nu.png")

const SLOT_RECTS := {
	Equipment.Part.MASK: Rect2(1.0, 20.0, 60.0, 90.0),       # SlotLeft0
	Equipment.Part.CUFF: Rect2(1.0, 114.0, 60.0, 113.0),     # SlotLeft1
	Equipment.Part.RING1: Rect2(1.0, 233.0, 60.0, 61.0),     # SlotLeft2
	Equipment.Part.RING2: Rect2(1.0, 299.0, 60.0, 60.0),     # SlotLeft3
	Equipment.Part.PENDANT: Rect2(1.0, 365.0, 60.0, 114.0),   # SlotLeft4
	Equipment.Part.MANTLE: Rect2(1.0, 515.0, 60.0, 62.0),    # SlotLeft5
	Equipment.Part.HEAD: Rect2(109.0, 17.0, 113.0, 118.0),    # SlotHead
	Equipment.Part.BODY: Rect2(109.0, 147.0, 113.0, 171.0),   # SlotBody
	Equipment.Part.BELT: Rect2(109.0, 333.0, 113.0, 56.0),    # SlotBelt
	Equipment.Part.HORSE: Rect2(109.0, 403.0, 113.0, 171.0),  # SlotHorse
	Equipment.Part.AMULET: Rect2(292.0, 95.0, 109.0, 63.0),   # SlotRight1
	Equipment.Part.WEAPON: Rect2(292.0, 165.0, 109.0, 221.0), # SlotRight2
	Equipment.Part.FOOT: Rect2(292.0, 398.0, 109.0, 109.0),   # SlotRight3
}

var _snap: Dictionary
var _avatar: CharacterAvatar
var _turn := 0

## Mở cửa sổ từ kết quả ViewEquipService.view(); trả về null nếu có lỗi (lời lỗi nằm trong `out_error`).
static func open_for(host: Node, viewer: PlayerProfile, target: MockPlayer, out_error: Array = []) -> ViewEquipWindow:
	## Online: người chơi thật ở gần chỉ là MockPlayer dựng tạm (không có trang bị) -> xin server (S_VIEW_EQUIP), hiện "Đang tải" trong lúc chờ.
	if NetClient.is_in_world():
		if target == null:
			out_error.append("Không thấy người chơi này.")
			return null
		NetClient.send_view_equip(target.id)
		return open_snapshot(host, {"name": target.name, "level": target.level, "loading": true})
	var res := ViewEquipService.view(viewer, target)
	if str(res["error"]) != "":
		out_error.append(str(res["error"]))
		return null
	return open_snapshot(host, res["snapshot"])

## Mở bảng trang bị — đang mở bảng của người khác (hoặc bảng "Đang tải") thì thay bằng bảng mới.
static func open_snapshot(host: Node, snapshot: Dictionary) -> ViewEquipWindow:
	for w in host.get_tree().get_nodes_in_group("social_windows"):
		if w is ViewEquipWindow and is_instance_valid(w) and not w.is_queued_for_deletion():
			w.remove_from_group("social_windows")
			(w as ViewEquipWindow).close_requested.emit()
	return SocialWindow.present(host, ViewEquipWindow.new(snapshot), &"view_equip") as ViewEquipWindow

func _init(snapshot: Dictionary = {}) -> void:
	super._init("Trang Bị Của %s" % str(snapshot.get("name", "")), "Cấp %d · %s" % [int(snapshot.get("level", 1)), str(snapshot.get("sect_name", ""))], 670.0)
	_snap = snapshot.duplicate()
	if snapshot.is_empty():
		return
	if snapshot.get("loading", false):
		body.add_child(SocialUi.label("Đang tải trang bị…", SocialUi.MUTED, 14, HORIZONTAL_ALIGNMENT_CENTER))
		var wait_close := SocialUi.stone_button("Đóng")
		wait_close.pressed.connect(func() -> void: close_requested.emit())
		body.add_child(wait_close)
		return
	var equipment := ViewEquipService.normalize_equipment(snapshot.get("equipment", {}))
	_snap["equipment"] = equipment
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	body.add_child(cols)

	## ---- Trái: hình nhân vật + thông tin
	var left := SocialUi.info_box()
	left[0].custom_minimum_size = Vector2(190, 0)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(170, 210)
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.tooltip_text = "Bấm để xoay nhân vật"
	_avatar = CharacterAvatar.new()
	_avatar.position = Vector2(85, 190)
	portrait.add_child(_avatar)
	portrait.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_turn = (_turn + 1) % 8
			_avatar.face(Vector2.DOWN.rotated(deg_to_rad(45.0 * _turn))))
	left[1].add_child(portrait)
	left[1].add_child(SocialUi.kv("Tên:", str(snapshot.get("name", "")), SocialUi.LABEL_RED, Camp.get_color(int(snapshot.get("camp", 0)))))
	left[1].add_child(SocialUi.kv("Cấp:", str(int(snapshot.get("level", 1))), SocialUi.LABEL_BLUE))
	left[1].add_child(SocialUi.kv("Môn phái:", str(snapshot.get("sect_name", "")), SocialUi.LABEL_BLUE))
	left[1].add_child(SocialUi.kv("Thuộc tính:", ElementTypes.ELEMENT_NAME.get(int(snapshot.get("series", 0)), "—"), SocialUi.LABEL_BLUE))
	left[1].add_child(SocialUi.kv("Phe:", Camp.get_camp_name(int(snapshot.get("camp", 0))), SocialUi.LABEL_BLUE))
	if str(snapshot.get("guild", "")) != "":
		left[1].add_child(SocialUi.kv("Bang hội:", str(snapshot["guild"]), SocialUi.LABEL_GREEN))
	left[1].add_child(SocialUi.kv("Lãnh đạo:", str(int(snapshot.get("lead_level", 0))), SocialUi.LABEL_BLUE))
	cols.add_child(left[0])

	## ---- Phải: Giao diện "Trang bị" chuẩn theo CharacterHub
	var equip_box := Panel.new()
	equip_box.name = "EquipBox"
	equip_box.custom_minimum_size = Vector2(440, 585)
	equip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_box.add_theme_stylebox_override("panel", WuxiaStyle.create_panel_box())

	var equip_header := Panel.new()
	equip_header.custom_minimum_size = Vector2(0, 28)
	equip_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	equip_header.offset_left = 2
	equip_header.offset_top = 2
	equip_header.offset_right = -2
	equip_header.offset_bottom = 30
	equip_header.add_theme_stylebox_override("panel", WuxiaStyle.create_header_bar())
	equip_box.add_child(equip_header)

	var equip_title := Label.new()
	equip_title.text = "Trang bị"
	equip_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equip_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	equip_title.offset_left = 12
	equip_title.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	equip_title.add_theme_font_size_override("font_size", 14)
	equip_header.add_child(equip_title)

	var is_female := bool(snapshot.get("female", false))
	var equip_bg := TextureRect.new()
	equip_bg.name = "EquipBackground"
	equip_bg.texture = TEX_EQUIP_BG_FEMALE if is_female else TEX_EQUIP_BG_MALE
	equip_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equip_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	equip_bg.self_modulate = Color(1, 1, 1, 0.85)
	equip_bg.scale = Vector2(0.896, 0.896)
	equip_bg.size = Vector2(402, 597)
	equip_bg.position = Vector2(40, 36)
	equip_box.add_child(equip_bg)

	var counts := Equipment.get_active_counts(equipment, int(snapshot.get("series", 0)))
	for part in Equipment.Part.values():
		var slot := ItemSlotButton.new()
		slot.name = "Slot%d" % part
		var rect: Rect2 = SLOT_RECTS.get(part, Rect2(0, 0, 60, 60))
		slot.position = rect.position
		slot.size = rect.size
		slot.custom_minimum_size = rect.size
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.mouse_filter = Control.MOUSE_FILTER_STOP

		var item: ItemInstance = equipment.get(part)
		if item != null:
			slot.filled_backdrop = Color(0.04, 0.05, 0.06, 0.96)
			var slot_bg := Color(0.02, 0.07, 0.08, 0.88)
			var border_col := WuxiaStyle.COLOR_BORDER_GOLD if item.is_gold() else (Color(0.85, 0.28, 1.0, 0.8) if item.is_purple() else WuxiaStyle.COLOR_BORDER_SLOT)
			var normal_sb := StyleBoxFlat.new()
			normal_sb.bg_color = slot_bg
			normal_sb.set_border_width_all(1)
			normal_sb.border_color = border_col
			normal_sb.set_corner_radius_all(4)
			slot.add_theme_stylebox_override("normal", normal_sb)
			slot.add_theme_stylebox_override("disabled", normal_sb)

			var hover_sb := StyleBoxFlat.new()
			hover_sb.bg_color = Color(0.05, 0.14, 0.16, 0.95)
			hover_sb.set_border_width_all(2)
			hover_sb.border_color = WuxiaStyle.COLOR_BORDER_GOLD_BRIGHT if item.is_gold() else (Color(0.95, 0.45, 1.0, 1.0) if item.is_purple() else WuxiaStyle.COLOR_BORDER_GOLD_BRIGHT)
			hover_sb.set_corner_radius_all(4)
			hover_sb.shadow_color = Color(0.98, 0.86, 0.52, 0.35)
			hover_sb.shadow_size = 4
			slot.add_theme_stylebox_override("hover", hover_sb)
			slot.add_theme_stylebox_override("pressed", hover_sb)

			var bbcode := ItemText.build(item, null, counts.get(part, 0), part)
			slot.show_item(item, bbcode, Equipment.PART_NAMES[part])
			slot.pressed.connect(func() -> void:
				ItemDetailPopup.open(get_tree().current_scene, ItemText.build(item, null, counts.get(part, 0), part, false), [], item))
		else:
			slot.flat = true
			slot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			slot.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
			slot.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
			var empty_hover := StyleBoxFlat.new()
			empty_hover.bg_color = Color(1, 1, 1, 0.05)
			empty_hover.set_border_width_all(1)
			empty_hover.border_color = Color(0.68, 0.55, 0.30, 0.4)
			empty_hover.set_corner_radius_all(4)
			slot.add_theme_stylebox_override("hover", empty_hover)

			slot.show_item(null, "", Equipment.PART_NAMES[part])

		equip_bg.add_child(slot)

	cols.add_child(equip_box)

	var close := SocialUi.stone_button("Đóng")
	close.custom_minimum_size.x = 120
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: close_requested.emit())
	body.add_child(close)

func _ready() -> void:
	super._ready()
	_apply_look()

## Dựng hình nhân vật theo giới tính + đồ đang mặc (mũ/áo/vũ khí/ngựa) — như bảng Nhân vật của mình.
func _apply_look() -> void:
	if _avatar == null or _snap.is_empty():
		return
	var gender := "female" if bool(_snap["female"]) else "male"
	var equipment: Dictionary = _snap["equipment"]
	var look := Equipment.get_appearance(equipment, gender, equipment.has(Equipment.Part.HORSE))
	var final_gender: String = str(look.get("gender", gender))
	_avatar.set_gender(final_gender)
	_avatar.set_appearance(look["helm"], look["armor"], look["weapon"], look["horse"])
	if look.has("modulate"):
		_avatar.modulate = look["modulate"]
	else:
		_avatar.modulate = Color.WHITE

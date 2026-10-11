extends SocialWindow
class_name ViewEquipWindow
## XEM TRANG BỊ của người chơi khác (màn "xem trang bị" — c2s_viewequip gốc): hình nhân vật + thông tin cơ bản bên trái, 11 ô trang bị bên phải.
## Bấm ô có đồ để xem chi tiết (chỉ xem, không có nút trang bị/vứt). Dữ liệu là BẢN SAO từ ViewEquipService.

var _snap: Dictionary
var _avatar: CharacterAvatar
var _turn := 0

## Mở cửa sổ từ kết quả ViewEquipService.view(); trả về null nếu có lỗi (lời lỗi nằm trong `out_error`).
static func open_for(host: Node, viewer: PlayerProfile, target: MockPlayer, out_error: Array = []) -> ViewEquipWindow:
	var res := ViewEquipService.view(viewer, target)
	if str(res["error"]) != "":
		out_error.append(str(res["error"]))
		return null
	return open_snapshot(host, res["snapshot"])

static func open_snapshot(host: Node, snapshot: Dictionary) -> ViewEquipWindow:
	return SocialWindow.present(host, ViewEquipWindow.new(snapshot), &"view_equip") as ViewEquipWindow

func _init(snapshot: Dictionary = {}) -> void:
	super._init("Trang Bị Của %s" % str(snapshot.get("name", "")), "Cấp %d · %s" % [int(snapshot.get("level", 1)), str(snapshot.get("sect_name", ""))], 640.0)
	_snap = snapshot
	if snapshot.is_empty():
		return
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
	left[1].add_child(SocialUi.kv("Tên:", str(snapshot["name"]), SocialUi.LABEL_RED, Camp.get_color(int(snapshot["camp"]))))
	left[1].add_child(SocialUi.kv("Cấp:", str(snapshot["level"]), SocialUi.LABEL_BLUE))
	left[1].add_child(SocialUi.kv("Môn phái:", str(snapshot["sect_name"]), SocialUi.LABEL_BLUE))
	left[1].add_child(SocialUi.kv("Thuộc tính:", ElementTypes.ELEMENT_NAME.get(int(snapshot["series"]), "—"), SocialUi.LABEL_BLUE))
	left[1].add_child(SocialUi.kv("Phe:", Camp.get_camp_name(int(snapshot["camp"])), SocialUi.LABEL_BLUE))
	if str(snapshot.get("guild", "")) != "":
		left[1].add_child(SocialUi.kv("Bang hội:", str(snapshot["guild"]), SocialUi.LABEL_GREEN))
	left[1].add_child(SocialUi.kv("Lãnh đạo:", str(snapshot.get("lead_level", 0)), SocialUi.LABEL_BLUE))
	cols.add_child(left[0])

	## ---- Phải: 11 ô trang bị
	var right := SocialUi.section("Trang bị đang mặc", SocialUi.SECTION_ACCENT, SocialUi.SECTION_BG)
	right[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var equipment: Dictionary = snapshot["equipment"]
	var counts := Equipment.get_active_counts(equipment, int(snapshot["series"]))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for part in Equipment.Part.values():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.add_child(SocialUi.label(Equipment.PART_NAMES[part], SocialUi.SUBTITLE, 12, HORIZONTAL_ALIGNMENT_CENTER))
		var slot := ItemSlotButton.new()
		slot.custom_minimum_size = Vector2(70, 70)
		slot.focus_mode = Control.FOCUS_NONE
		slot.filled_backdrop = Color(0.06, 0.05, 0.04, 0.96)
		slot.add_theme_font_size_override("font_size", 11)
		slot.add_theme_stylebox_override("normal", SocialUi.box(Color(0.03, 0.035, 0.035), SocialUi.BORDER, 4, 1, 2))
		slot.add_theme_stylebox_override("hover", SocialUi.box(Color(0.06, 0.07, 0.06), SocialUi.TITLE, 4, 1, 2))
		slot.add_theme_stylebox_override("pressed", SocialUi.box(Color(0.06, 0.07, 0.06), SocialUi.TITLE, 4, 1, 2))
		slot.add_theme_stylebox_override("disabled", SocialUi.box(Color(0.03, 0.035, 0.035), SocialUi.BORDER, 4, 1, 2))
		var item: ItemInstance = equipment.get(part)
		slot.name = "Slot%d" % part
		## Người ngoài xem nên không đánh giá yêu cầu dùng đồ (profile = null).
		slot.show_item(item, ItemText.build(item, null, counts.get(part, 0), part) if item else "", Equipment.PART_NAMES[part])
		slot.pressed.connect(func() -> void:
			if item != null:
				ItemDetailPopup.open(get_tree().current_scene, ItemText.build(item, null, counts.get(part, 0), part, false), [], item))
		cell.add_child(slot)
		grid.add_child(cell)
	right[1].add_child(grid)
	cols.add_child(right[0])

	var close := SocialUi.stone_button("Đóng")
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
	_avatar.set_gender(gender)
	var equipment: Dictionary = _snap["equipment"]
	var look := Equipment.get_appearance(equipment, gender, equipment.has(Equipment.Part.HORSE))
	_avatar.set_appearance(look["helm"], look["armor"], look["weapon"], look["horse"])

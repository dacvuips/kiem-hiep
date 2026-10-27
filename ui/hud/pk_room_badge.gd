extends PanelContainer
class_name PkRoomBadge

## HUY HIỆU HIỂN THỊ ID PHÒNG THI ĐẤU PK ĐẶT CẠNH ICON 18+ Ở GÓC TRÊN BÊN TRÁI
## Tự động căn sát lề phải của AgeRatingBadge (Vector2(18, 10), kích thước 44x44) -> bắt đầu tại X=68, Y=10.

static var current: PkRoomBadge = null

var _id_label: Label
var _copy_btn: Button
var _room_id: String = ""
var _mode_name: String = ""

static func attach(parent: Node, initial_id: String = "", mode_idx: int = -1) -> PkRoomBadge:
	if current != null and is_instance_valid(current):
		current.set_room_id(initial_id)
		if mode_idx >= 0:
			current.set_mode(mode_idx)
		return current
	var badge := PkRoomBadge.new(initial_id, mode_idx)
	parent.add_child(badge)
	return badge

static func update_id(new_id: String) -> void:
	if current != null and is_instance_valid(current):
		current.set_room_id(new_id)

func _init(initial_id: String = "", mode_idx: int = -1) -> void:
	current = self
	name = "PkRoomBadge"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 68.0
	offset_top = 10.0
	offset_bottom = 48.0
	mouse_filter = Control.MOUSE_FILTER_PASS

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.88)
	sb.border_color = Color(0.85, 0.70, 0.25, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	_id_label = Label.new()
	_id_label.add_theme_font_size_override("font_size", 13)
	_id_label.add_theme_color_override("font_color", GameUi.GOLD)
	_id_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_id_label)

	_copy_btn = SocialUi.small_button("Sao chép")
	_copy_btn.tooltip_text = "Sao chép ID phòng thi đấu PK để gửi cho bạn bè"
	_copy_btn.custom_minimum_size = Vector2(58, 24)
	_copy_btn.pressed.connect(_on_copy)
	hbox.add_child(_copy_btn)

	if mode_idx >= 0:
		set_mode(mode_idx)
	set_room_id(initial_id)

func set_mode(mode_idx: int) -> void:
	_mode_name = str(PkRules.MODE_NAMES.get(mode_idx, ""))
	_update_label()

func set_room_id(rid: String) -> void:
	_room_id = rid.strip_edges()
	_update_label()

func _update_label() -> void:
	if _id_label == null:
		return
	if _room_id.is_empty():
		_id_label.text = "⚔️ Đang tạo phòng…"
		if _copy_btn:
			_copy_btn.visible = false
	else:
		_id_label.text = "⚔️ Phòng: #%s" % _room_id
		if _copy_btn:
			_copy_btn.visible = true
	tooltip_text = ("Chế độ: %s\nID Phòng: %s (Bấm Sao chép để chia sẻ)" % [_mode_name, _room_id]) if not _mode_name.is_empty() else ("ID Phòng PK: %s" % _room_id)

func _on_copy() -> void:
	if _room_id.is_empty():
		return
	DisplayServer.clipboard_set(_room_id)
	if _copy_btn:
		_copy_btn.text = "Đã chép"
		var tree := get_tree()
		if tree:
			await tree.create_timer(1.5).timeout
			if is_instance_valid(_copy_btn):
				_copy_btn.text = "Sao chép"

func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE) and current == self:
		current = null

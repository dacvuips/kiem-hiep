extends SocialWindow
class_name CompoundWindow

## GIAO DIỆN CHẾ TẠO ĐỒ TÍM & HUYỀN TINH CHUẨN VLTK (5 TAB):
##   1. Tinh luyện ▼: Luyện Huyền Tinh (3 trang sức) / Thăng cấp Huyền Tinh (3 viên) / Thăng cấp khoáng thuộc tính (3 viên)
##   2. Lấy: Hút thuộc tính từ trang bị xanh vào khoáng thạch nguyên/nguyên thạch
##   3. Chế tạo: Chế tạo trang bị tím phôi (1-5 ô khảm) từ trang bị trắng/xanh + Huyền Tinh
##   4. Khảm nạm: Khảm khoáng thạch có thuộc tính vào trang bị tím
##   5. Đồ phổ: Kết hợp Đồ phổ Hoàng Kim + khoáng thạch + bí kíp + Huyền Tinh -> Đồ Hoàng Kim
## Luật ép, giá trị và tỉ lệ: systems/items/compound.gd.

const SLOT_SIZE := 40.0
const GRID_COLUMNS := 8
const ALT_TARGET := -1

enum Tab { REFINE, DISTILL, FORGE, ENCHASE, DOPHO }
enum RefineSub { XUANJING, UPGRADE_XJ, UPGRADE_PROP, KILLER }

const TAB_TITLES := ["Tinh luyện ▼", "Lấy", "Chế tạo", "Khảm nạm", "Đồ phổ"]
const REFINE_SUB_NAMES := [
	"Luyện Huyền tinh khoáng thạch",
	"Thăng cấp Huyền tinh khoáng thạch",
	"Thăng cấp khoáng thạch thuộc tính",
	"Hợp thành Sát thủ giản"
]

signal slots_changed

var _profile: PlayerProfile
var _on_changed: Callable
var _active_tab: int = Tab.DISTILL
var _refine_sub: int = RefineSub.XUANJING

var _slots: Array = []        ## ItemInstance | null theo ô của cấu hình hiện tại
var _alts: Array = []         ## vật phẩm phụ
var _target := 0              ## ô đang chọn (ALT_TARGET = vật phẩm phụ)

func get_used_counts() -> Dictionary:
	return _used_counts()

func _notify_slots_changed() -> void:
	slots_changed.emit()
	if _on_changed.is_valid():
		_on_changed.call()

func remove_slot_item(slot_idx: int) -> void:
	if slot_idx >= 0 and slot_idx < _slots.size() and _slots[slot_idx] != null:
		var removed_name: String = _slots[slot_idx].get_display_name()
		_slots[slot_idx] = null
		_clear_error()
		_show_toast("Đã gỡ %s khỏi ô" % removed_name)
		_refresh()
		_notify_slots_changed()

func remove_alt_item(alt_idx: int) -> void:
	if alt_idx >= 0 and alt_idx < _alts.size():
		var removed_name: String = _alts[alt_idx].get_display_name()
		_alts.remove_at(alt_idx)
		_clear_error()
		_show_toast("Đã gỡ %s khỏi ô phụ" % removed_name)
		_refresh()
		_notify_slots_changed()

func clear_all_slots() -> void:
	_slots = []
	for s in _current_slot_defs():
		_slots.append(null)
	_alts = []
	_target = 0
	_clear_error()
	_refresh()
	_notify_slots_changed()

func _exit_tree() -> void:
	_slots.clear()
	_alts.clear()

var _tab_buttons: Array[Button] = []
var _refine_popup: PopupMenu

var _magic_canvas: Control
var _slot_container: Control
var _preview: RichTextLabel
var _grid_title: Label
var _grid_scroll: ScrollContainer
var _grid: GridContainer
var _message: Label
var _action_button: Button
var _toast: Label
var _toast_tween: Tween

# ---------------------------------------------------------------- Khung phụ vẽ ô

class EquipSlotBox extends ItemSlotButton:
	var watermark_text: String = ""
	var is_active: bool = false

	func _draw() -> void:
		super._draw()
		if _item_icon == null:
			var inner := Rect2(Vector2(1, 1), size - Vector2(2, 2))
			draw_rect(inner, Color(0.03, 0.14, 0.07, 0.7))
			var col_w := size.x / 2.0
			var row_h := size.y / 4.0
			var grid_col := Color(0.12, 0.40, 0.22, 0.45)
			draw_line(Vector2(col_w, 1), Vector2(col_w, size.y - 1), grid_col, 1.0)
			for r in range(1, 4):
				draw_line(Vector2(1, r * row_h), Vector2(size.x - 1, r * row_h), grid_col, 1.0)
			if watermark_text != "":
				var font := get_theme_default_font()
				var lines := watermark_text.split("\n")
				var total_h := lines.size() * 16.0
				var start_y := (size.y - total_h) * 0.5 + 12.0
				for k in lines.size():
					var str_w := font.get_string_size(lines[k], HORIZONTAL_ALIGNMENT_CENTER, -1, 11).x
					var x := (size.x - str_w) * 0.5
					draw_string(font, Vector2(x, start_y + k * 16.0), lines[k], HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.75, 0.65, 0.28, 0.7))
		var border_col := Color(1.0, 0.85, 0.25, 0.95) if is_active else Color(0.78, 0.80, 0.84, 0.85)
		draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), border_col, false, 2.0 if is_active else 1.0)

class SlotWatermarkButton extends ItemSlotButton:
	var watermark_text: String = ""
	var is_circle: bool = false
	var ring_tint: Color = Color.TRANSPARENT

	func _draw() -> void:
		super._draw()
		if is_circle:
			var center := size * 0.5
			var r := minf(size.x, size.y) * 0.5 - 2.0
			if ring_tint.a > 0.0:
				draw_arc(center, r + 1.0, 0, TAU, 32, ring_tint, 2.0, true)
		if _item_icon == null and watermark_text != "":
			var font := get_theme_default_font()
			var lines := watermark_text.split("\n")
			var total_h := lines.size() * 14.0
			var start_y := (size.y - total_h) * 0.5 + 10.0
			for k in lines.size():
				var str_w := font.get_string_size(lines[k], HORIZONTAL_ALIGNMENT_CENTER, -1, 10).x
				var x := (size.x - str_w) * 0.5
				draw_string(font, Vector2(x, start_y + k * 14.0), lines[k], HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.78, 0.68, 0.32, 0.75))

# ---------------------------------------------------------------- Canvas vẽ Ma Pháp Trận

class MagicCircleCanvas extends Control:
	var parent_win: CompoundWindow

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.07, 0.95))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.22, 0.32, 0.34, 0.65), false, 1.0)
		if parent_win == null:
			return
		var center := Vector2(size.x * 0.5, 142.0)
		var gold_bright := Color(0.96, 0.80, 0.26, 0.75)
		var gold_faint := Color(0.85, 0.65, 0.20, 0.35)

		match parent_win._active_tab:
			CompoundWindow.Tab.REFINE:
				_draw_refine_pattern(center, gold_bright, gold_faint)
			CompoundWindow.Tab.DISTILL:
				_draw_distill_pattern(center, gold_bright, gold_faint)
			CompoundWindow.Tab.FORGE:
				_draw_forge_pattern(center, gold_bright, gold_faint)
			CompoundWindow.Tab.ENCHASE:
				_draw_enchase_pattern(center, gold_bright, gold_faint)
			CompoundWindow.Tab.DOPHO:
				_draw_dopho_pattern(center, gold_bright, gold_faint)

	func _draw_refine_pattern(center: Vector2, bright: Color, faint: Color) -> void:
		draw_arc(center, 94.0, 0, TAU, 48, bright, 2.0, true)
		draw_arc(center, 84.0, 0, TAU, 36, faint, 1.0, true)
		draw_arc(center, 22.0, 0, TAU, 24, bright, 1.5, true)
		var v_top := Vector2(center.x, center.y - 78.0)
		var v_left := Vector2(center.x - 72.0, center.y + 48.0)
		var v_right := Vector2(center.x + 72.0, center.y + 48.0)
		draw_line(v_top, v_left, bright, 1.5, true)
		draw_line(v_left, v_right, bright, 1.5, true)
		draw_line(v_right, v_top, bright, 1.5, true)
		draw_arc(v_top, 27.0, 0, TAU, 24, Color(1.0, 0.55, 0.12, 0.6), 2.0, true)
		draw_arc(v_left, 27.0, 0, TAU, 24, Color(0.2, 0.88, 0.35, 0.6), 2.0, true)
		draw_arc(v_right, 27.0, 0, TAU, 24, Color(0.2, 0.68, 1.0, 0.6), 2.0, true)

	func _draw_distill_pattern(center: Vector2, bright: Color, faint: Color) -> void:
		var c1 := Vector2(center.x - 40.0, center.y)
		var c2 := Vector2(center.x + 40.0, center.y)
		draw_arc(c1, 74.0, 0, TAU, 40, bright, 1.5, true)
		draw_arc(c2, 74.0, 0, TAU, 40, bright, 1.5, true)
		draw_arc(center, 94.0, 0, TAU, 48, faint, 1.0, true)
		var d_top := Vector2(center.x, center.y - 68.0)
		var d_bottom := Vector2(center.x, center.y + 68.0)
		var d_left := Vector2(center.x - 56.0, center.y)
		var d_right := Vector2(center.x + 56.0, center.y)
		draw_line(d_top, d_right, bright, 1.2, true)
		draw_line(d_right, d_bottom, bright, 1.2, true)
		draw_line(d_bottom, d_left, bright, 1.2, true)
		draw_line(d_left, d_top, bright, 1.2, true)

	func _draw_forge_pattern(center: Vector2, bright: Color, faint: Color) -> void:
		draw_arc(center, 96.0, 0, TAU, 48, bright, 2.0, true)
		draw_arc(center, 84.0, 0, TAU, 36, faint, 1.0, true)
		var side := 105.0
		var h := side * 0.5
		var pts1 := [
			center + Vector2(-h, -h), center + Vector2(h, -h),
			center + Vector2(h, h), center + Vector2(-h, h),
			center + Vector2(-h, -h)
		]
		draw_polyline(pts1, bright, 1.5, true)
		var r_h := side * 0.7071
		var pts2 := [
			center + Vector2(0, -r_h), center + Vector2(r_h, 0),
			center + Vector2(0, r_h), center + Vector2(-r_h, 0),
			center + Vector2(0, -r_h)
		]
		draw_polyline(pts2, bright, 1.5, true)

	func _draw_enchase_pattern(center: Vector2, bright: Color, faint: Color) -> void:
		draw_arc(center, 95.0, 0, TAU, 48, bright, 2.0, true)
		draw_arc(center, 82.0, 0, TAU, 36, faint, 1.0, true)
		draw_arc(center, 38.0, 0, TAU, 24, bright, 1.2, true)
		var v_top := Vector2(center.x, center.y - 75.0)
		var v_left := Vector2(center.x - 68.0, center.y + 45.0)
		var v_right := Vector2(center.x + 68.0, center.y + 45.0)
		draw_line(v_top, v_left, bright, 1.6, true)
		draw_line(v_left, v_right, bright, 1.6, true)
		draw_line(v_right, v_top, bright, 1.6, true)

	func _draw_dopho_pattern(center: Vector2, bright: Color, faint: Color) -> void:
		draw_arc(center, 98.0, 0, TAU, 48, bright, 2.0, true)
		draw_arc(center, 54.0, 0, TAU, 32, faint, 1.0, true)
		for i in 6:
			var ang := i * TAU / 6.0 - PI / 6.0
			var p := center + Vector2(cos(ang), sin(ang)) * 88.0
			draw_arc(p, 24.0, 0, TAU, 24, bright, 1.5, true)
			draw_line(center, p, faint, 1.0, true)

# ---------------------------------------------------------------- Khởi tạo

static func open(host: Node, profile: PlayerProfile, on_changed: Callable = Callable()) -> CompoundWindow:
	var win := CompoundWindow.new()
	win._profile = profile
	win._on_changed = on_changed
	return SocialWindow.present(host, win, &"compound") as CompoundWindow

func _init() -> void:
	super._init("Chế Tạo", "", 475.0)
	if subtitle_label:
		subtitle_label.visible = false

	# 1. Hàng Tab 5 nút trên cùng
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 2)
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in TAB_TITLES.size():
		var b := Button.new()
		b.text = TAB_TITLES[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_on_tab_pressed.bind(i))
		_style_tab_button(b, i == _active_tab)
		tab_row.add_child(b)
		_tab_buttons.append(b)
	body.add_child(tab_row)

	# Popup Menu cho Tab Tinh Luyện
	_refine_popup = PopupMenu.new()
	for i in REFINE_SUB_NAMES.size():
		_refine_popup.add_item(REFINE_SUB_NAMES[i], i)
	_refine_popup.id_pressed.connect(_on_refine_sub_selected)
	add_child(_refine_popup)

	# 2. Vùng Chế tạo chính (Chia đôi: Trái Ma Pháp Trận, Phải Thông tin)
	var main_box := HBoxContainer.new()
	main_box.add_theme_constant_override("separation", 6)
	main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main_box)

	# Cột Trái (Ma Pháp Trận & Ô đồ)
	_magic_canvas = MagicCircleCanvas.new()
	(_magic_canvas as MagicCircleCanvas).parent_win = self
	_magic_canvas.custom_minimum_size = Vector2(256, 290)
	main_box.add_child(_magic_canvas)

	_slot_container = Control.new()
	_slot_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_magic_canvas.add_child(_slot_container)

	# Cột Phải (Mô tả, nguyên liệu, nút hành động)
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(198, 290)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.05, 0.07, 0.08, 0.95)
	r_style.border_color = Color(0.24, 0.34, 0.36, 0.7)
	r_style.set_border_width_all(1)
	r_style.set_content_margin_all(6)
	right_panel.add_theme_stylebox_override("panel", r_style)
	main_box.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_vbox)

	var preview_scroll := ScrollContainer.new()
	preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(preview_scroll)

	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.fit_content = true
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.add_theme_font_size_override("normal_font_size", 11)
	preview_scroll.add_child(_preview)
	TouchScrollHelperScript.attach(preview_scroll, right_panel)

	var act_box := HBoxContainer.new()
	act_box.alignment = BoxContainer.ALIGNMENT_END
	_action_button = SocialUi.stone_button("Chế tạo")
	_action_button.custom_minimum_size = Vector2(105, 30)
	_action_button.pressed.connect(_make)
	act_box.add_child(_action_button)
	right_vbox.add_child(act_box)

	# 3. Lưới chọn đồ từ Hành trang
	_grid_title = SocialUi.label("Hành trang — chọn nguyên liệu:", SocialUi.LABEL_BLUE, 12)
	_grid_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_grid_title)

	_grid_scroll = ScrollContainer.new()
	_grid_scroll.custom_minimum_size = Vector2(0, 105)
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.set_drag_forwarding(Callable(), _can_drop_on_remove_zone, _drop_on_remove_zone)
	body.add_child(_grid_scroll)
	TouchScrollHelperScript.attach(_grid_scroll, _grid_scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid_scroll.add_child(_grid)

	_message = SocialUi.label("", SocialUi.WARN, 12)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)

	# 4. Hàng nút đáy: Bỏ hết & Đóng
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 24)

	var clear_btn := SocialUi.stone_button("Bỏ hết")
	clear_btn.custom_minimum_size = Vector2(85, 28)
	clear_btn.pressed.connect(clear_all_slots)
	bottom_row.add_child(clear_btn)

	var close_btn := SocialUi.stone_button("Đóng")
	close_btn.custom_minimum_size = Vector2(120, 28)
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	bottom_row.add_child(close_btn)

	body.add_child(bottom_row)
	NetClient.server_notice.connect(_on_notice)

func _ready() -> void:
	_switch_tab(Tab.DISTILL)

# ---------------------------------------------------------------- Điều hướng Tab & Sub-mode

func _on_tab_pressed(idx: int) -> void:
	if idx == Tab.REFINE and _active_tab == Tab.REFINE:
		# Nhấp lại tab Tinh luyện -> mở popup chọn chế độ
		var btn: Button = _tab_buttons[Tab.REFINE]
		var pos := Vector2i(btn.global_position) + Vector2i(0, int(btn.size.y))
		_refine_popup.popup(Rect2i(pos, Vector2i(230, 110)))
		return
	_switch_tab(idx)

func _on_refine_sub_selected(id: int) -> void:
	_refine_sub = id
	_switch_tab(Tab.REFINE)

func _switch_tab(tab_idx: int) -> void:
	_active_tab = tab_idx
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		if i == Tab.REFINE:
			b.text = "Tinh luyện ▼"
		_style_tab_button(b, i == tab_idx)

	var op := _current_op()
	_slots = []
	for s in _current_slot_defs():
		_slots.append(null)
	_alts = []
	_target = 0
	_message.text = ""
	_magic_canvas.queue_redraw()
	_rebuild_slots()
	_refresh()
	_notify_slots_changed()

func _current_op() -> int:
	match _active_tab:
		Tab.REFINE:
			match _refine_sub:
				RefineSub.XUANJING:
					return Compound.Op.REFINE
				RefineSub.UPGRADE_XJ, RefineSub.UPGRADE_PROP:
					return Compound.Op.UPGRADE
				RefineSub.KILLER:
					return Compound.Op.KILLER
		Tab.DISTILL:
			return Compound.Op.DISTILL
		Tab.FORGE:
			return Compound.Op.FORGE
		Tab.ENCHASE:
			return Compound.Op.ENCHASE
		Tab.DOPHO:
			return Compound.Op.DOPHO
	return Compound.Op.DISTILL

func _current_slot_defs() -> Array:
	if _active_tab == Tab.REFINE:
		match _refine_sub:
			RefineSub.XUANJING:
				return [
					{"label": "Nhẫn", "kind": "ring"},
					{"label": "Ngọc bội/hương nang", "kind": "pendant"},
					{"label": "Dây chuyền/hộ thân phù", "kind": "necklace"}
				]
			RefineSub.UPGRADE_XJ:
				return [
					{"label": "Huyền Tinh 1", "kind": "xuanjing"},
					{"label": "Huyền Tinh 2", "kind": "xuanjing"},
					{"label": "Huyền Tinh 3", "kind": "xuanjing"}
				]
			RefineSub.UPGRADE_PROP:
				return [
					{"label": "Khoáng thạch 1", "kind": "prop_ore"},
					{"label": "Khoáng thạch 2", "kind": "prop_ore"},
					{"label": "Khoáng thạch 3", "kind": "prop_ore"}
				]
			RefineSub.KILLER:
				var s := []
				for i in 5:
					s.append({"label": "Sát Thủ lệnh %d" % (i + 1), "kind": "token"})
				return s
	return Compound.slots_of(_current_op())

func _style_tab_button(b: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(3)
	box.set_border_width_all(1)
	if active:
		box.bg_color = Color(0.18, 0.22, 0.24, 0.95)
		box.border_color = Color(0.96, 0.82, 0.35, 1.0)
		b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	else:
		box.bg_color = Color(0.08, 0.10, 0.12, 0.9)
		box.border_color = Color(0.28, 0.34, 0.36, 0.7)
		b.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	b.add_theme_stylebox_override("pressed", box)

# ---------------------------------------------------------------- Bố cục các ô đồ trên Ma Pháp Trận

func _rebuild_slots() -> void:
	for c in _slot_container.get_children():
		c.queue_free()

	match _active_tab:
		Tab.REFINE:
			_layout_refine_slots()
		Tab.DISTILL:
			_layout_distill_slots()
		Tab.FORGE:
			_layout_forge_slots()
		Tab.ENCHASE:
			_layout_enchase_slots()
		Tab.DOPHO:
			_layout_dopho_slots()

func _layout_refine_slots() -> void:
	if _refine_sub == RefineSub.KILLER:
		var start_x := 15.0
		for i in 5:
			var btn := _create_slot_btn(i, Vector2(start_x + i * 48.0, 120.0), Vector2(44, 44), "Lệnh\n%d" % (i + 1), true)
			_slot_container.add_child(btn)
		return

	var labels := ["Nhẫn", "Ngọc bội", "Dây chuyền"]
	if _refine_sub == RefineSub.UPGRADE_XJ:
		labels = ["Huyền Tinh 1", "Huyền Tinh 2", "Huyền Tinh 3"]
	elif _refine_sub == RefineSub.UPGRADE_PROP:
		labels = ["Khoáng 1", "Khoáng 2", "Khoáng 3"]

	var top_btn := _create_slot_btn(0, Vector2(108, 25), Vector2(46, 46), labels[0], true, Color(1.0, 0.55, 0.1, 0.7))
	var left_btn := _create_slot_btn(1, Vector2(36, 172), Vector2(46, 46), labels[1], true, Color(0.2, 0.85, 0.35, 0.7))
	var right_btn := _create_slot_btn(2, Vector2(180, 172), Vector2(46, 46), labels[2], true, Color(0.2, 0.65, 1.0, 0.7))
	_slot_container.add_child(top_btn)
	_slot_container.add_child(left_btn)
	_slot_container.add_child(right_btn)

func _layout_distill_slots() -> void:
	var equip_btn := _create_equip_btn(0, Vector2(12, 70), Vector2(72, 144), "Trang bị\nmàu xanh")
	_slot_container.add_child(equip_btn)

	var xj_btn := _create_slot_btn(1, Vector2(98, 76), Vector2(42, 42), "Huyền Tinh", false)
	var ore_btn := _create_slot_btn(2, Vector2(98, 150), Vector2(42, 42), "Nguyên\nkhoáng", false)
	_slot_container.add_child(xj_btn)
	_slot_container.add_child(ore_btn)

	_add_alt_grid(Vector2(154, 70), 2, 3, 40.0, 4.0, 6)

func _layout_forge_slots() -> void:
	var equip_btn := _create_equip_btn(0, Vector2(85, 68), Vector2(76, 152), "Trang bị\nxanh/trắng")
	_slot_container.add_child(equip_btn)

	var xj_btn := _create_slot_btn(1, Vector2(174, 42), Vector2(44, 44), "Huyền Tinh", false)
	_slot_container.add_child(xj_btn)

func _layout_enchase_slots() -> void:
	var equip_btn := _create_equip_btn(0, Vector2(12, 70), Vector2(72, 144), "Trang bị\nHuyền Tinh")
	_slot_container.add_child(equip_btn)

	var xj_btn := _create_slot_btn(1, Vector2(98, 76), Vector2(42, 42), "Huyền Tinh", false)
	var ore_btn := _create_slot_btn(2, Vector2(98, 150), Vector2(42, 42), "Khoáng\nthạch", false)
	_slot_container.add_child(xj_btn)
	_slot_container.add_child(ore_btn)

	_add_alt_grid(Vector2(154, 70), 2, 3, 40.0, 4.0, 6)

func _layout_dopho_slots() -> void:
	var pos_list := [
		Vector2(36, 26), Vector2(182, 26), Vector2(212, 125),
		Vector2(182, 222), Vector2(36, 222), Vector2(6, 125)
	]
	var labels := ["Đồ phổ", "Khoáng 1", "Khoáng 2", "Bí kíp", "Khoáng 3", "Khoáng 4"]
	for i in 6:
		var btn := _create_slot_btn(i, pos_list[i], Vector2(44, 44), labels[i], true, Color(0.95, 0.78, 0.25, 0.6))
		_slot_container.add_child(btn)

	_add_alt_grid(Vector2(90, 72), 2, 4, 36.0, 3.0, 8)

func _add_alt_grid(origin: Vector2, cols: int, rows: int, cell_size: float, sep: float, max_count: int) -> void:
	var wmark := Label.new()
	wmark.text = "Có thể chọn\nnguyên liệu"
	wmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wmark.position = origin
	wmark.size = Vector2(cols * cell_size + (cols - 1) * sep, rows * cell_size + (rows - 1) * sep)
	wmark.add_theme_color_override("font_color", Color(0.85, 0.70, 0.30, 0.45))
	wmark.add_theme_font_size_override("font_size", 11)
	wmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_container.add_child(wmark)

	for r in rows:
		for c in cols:
			var idx := r * cols + c
			if idx >= max_count:
				break
			var pos := origin + Vector2(c * (cell_size + sep), r * (cell_size + sep))
			var btn := _create_alt_btn(idx, pos, Vector2(cell_size, cell_size))
			_slot_container.add_child(btn)

func _create_slot_btn(slot_idx: int, pos: Vector2, sz: Vector2, wmark: String, circle: bool = false, ring_tint: Color = Color.TRANSPARENT) -> SlotWatermarkButton:
	var b := SlotWatermarkButton.new()
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.is_circle = circle
	b.ring_tint = ring_tint
	b.watermark_text = wmark
	b.pressed.connect(_on_slot_clicked.bind(slot_idx))
	b.gui_input.connect(_on_slot_gui_input.bind(slot_idx))
	b.set_drag_forwarding(_get_craft_slot_drag_data.bind(slot_idx, b), _can_drop_on_slot.bind(slot_idx), _drop_on_slot.bind(slot_idx, b))
	var border_col := Color(0.78, 0.80, 0.84, 0.85)
	var bg_col := Color(0.08, 0.12, 0.14, 0.85)
	b.add_theme_stylebox_override("normal", GameUi.box(bg_col, border_col, 4, 1, 2))
	b.add_theme_stylebox_override("hover", GameUi.box(bg_col, Color(1.0, 0.85, 0.25), 4, 2, 2))
	b.add_theme_stylebox_override("pressed", GameUi.box(GameUi.ACTIVE_BG, Color(1.0, 0.85, 0.25), 4, 2, 2))
	return b

func _create_equip_btn(slot_idx: int, pos: Vector2, sz: Vector2, wmark: String) -> EquipSlotBox:
	var b := EquipSlotBox.new()
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.watermark_text = wmark
	b.pressed.connect(_on_slot_clicked.bind(slot_idx))
	b.gui_input.connect(_on_slot_gui_input.bind(slot_idx))
	b.set_drag_forwarding(_get_craft_slot_drag_data.bind(slot_idx, b), _can_drop_on_slot.bind(slot_idx), _drop_on_slot.bind(slot_idx, b))
	var border_col := Color(0.78, 0.80, 0.84, 0.85)
	var bg_col := Color(0.08, 0.12, 0.14, 0.85)
	b.add_theme_stylebox_override("normal", GameUi.box(bg_col, border_col, 4, 1, 2))
	b.add_theme_stylebox_override("hover", GameUi.box(bg_col, Color(1.0, 0.85, 0.25), 4, 2, 2))
	b.add_theme_stylebox_override("pressed", GameUi.box(GameUi.ACTIVE_BG, Color(1.0, 0.85, 0.25), 4, 2, 2))
	return b

func _create_alt_btn(alt_idx: int, pos: Vector2, sz: Vector2) -> SlotWatermarkButton:
	var b := SlotWatermarkButton.new()
	b.name = "Alt_%d" % alt_idx
	b.set_meta("alt_idx", alt_idx)
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.small_icons = true
	b.pressed.connect(_on_alt_clicked.bind(alt_idx))
	b.gui_input.connect(_on_alt_gui_input.bind(alt_idx))
	b.set_drag_forwarding(_get_alt_slot_drag_data.bind(alt_idx, b), _can_drop_on_alt.bind(alt_idx), _drop_on_alt.bind(alt_idx, b))
	var border_col := Color(0.78, 0.80, 0.84, 0.85)
	var bg_col := Color(0.08, 0.12, 0.14, 0.85)
	b.add_theme_stylebox_override("normal", GameUi.box(bg_col, border_col, 4, 1, 2))
	b.add_theme_stylebox_override("hover", GameUi.box(bg_col, Color(1.0, 0.85, 0.25), 4, 2, 2))
	b.add_theme_stylebox_override("pressed", GameUi.box(GameUi.ACTIVE_BG, Color(1.0, 0.85, 0.25), 4, 2, 2))
	return b

# ---------------------------------------------------------------- Cập nhật giao diện & Kế hoạch

func _refresh() -> void:
	_drop_missing()

	# Cập nhật hiển thị các ô trong _slot_container
	var slot_defs := _current_slot_defs()
	for child in _slot_container.get_children():
		if child is EquipSlotBox:
			var item: ItemInstance = _slots[0] if _slots.size() > 0 else null
			_update_slot_visual(child, item, _target == 0)
		elif child is SlotWatermarkButton:
			if _is_alt_button(child):
				var alt_idx: int = _get_alt_index_of_button(child)
				var item: ItemInstance = _alts[alt_idx] if alt_idx < _alts.size() else null
				_update_slot_visual(child, item, _target == ALT_TARGET)
			else:
				var slot_idx: int = _get_slot_index_of_button(child)
				if slot_idx >= 0 and slot_idx < _slots.size():
					var item: ItemInstance = _slots[slot_idx]
					_update_slot_visual(child, item, _target == slot_idx)

	_fill_candidate_grid()
	_render_info_and_preview()

func _update_slot_visual(b: ItemSlotButton, item: ItemInstance, active: bool) -> void:
	if b is EquipSlotBox:
		b.is_active = active
		b.queue_redraw()
	var border_col := Color(1.0, 0.85, 0.25, 0.95) if active else Color(0.78, 0.80, 0.84, 0.85)
	var bg_col := Color(0.08, 0.12, 0.14, 0.85) if not active else Color(0.12, 0.18, 0.22, 0.95)
	b.add_theme_stylebox_override("normal", GameUi.box(bg_col, border_col, 4, 2 if active else 1, 2))
	b.add_theme_stylebox_override("hover", GameUi.box(bg_col, Color(1.0, 0.85, 0.25), 4, 2, 2))
	b.add_theme_stylebox_override("pressed", GameUi.box(GameUi.ACTIVE_BG, Color(1.0, 0.85, 0.25), 4, 2, 2))

	if item:
		b.show_item(item, ItemText.build(item, _profile))
		if item.is_misc() and item.item_level > 0:
			var lv_node: Label = b.get_node_or_null("LevelBadge")
			if not lv_node:
				lv_node = SocialUi.label("C%d" % item.item_level, SocialUi.GOLD, 11)
				lv_node.name = "LevelBadge"
				lv_node.position = Vector2(3, 1)
				lv_node.add_theme_color_override("font_outline_color", Color.BLACK)
				lv_node.add_theme_constant_override("outline_size", 3)
				lv_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(lv_node)
			else:
				lv_node.text = "C%d" % item.item_level
				lv_node.visible = true
	else:
		b.show_item(null, "")
		var lv_node: Label = b.get_node_or_null("LevelBadge")
		if lv_node:
			lv_node.visible = false

func _get_slot_index_of_button(b: Control) -> int:
	if _is_alt_button(b) or b.name.begins_with("Alt_"):
		return ALT_TARGET
	var idx := 0
	for child in _slot_container.get_children():
		if child == b:
			return idx
		if child is ItemSlotButton and not (child.name.begins_with("Alt_") or _is_alt_button(child)):
			idx += 1
	return -1

func _is_alt_button(b: Control) -> bool:
	return b.has_meta("alt_idx")

func _get_alt_index_of_button(b: Control) -> int:
	return int(b.get_meta("alt_idx", -1))

func _on_slot_clicked(i: int) -> void:
	var slot_changed := false
	if i < _slots.size() and _slots[i] != null and _target == i:
		_slots[i] = null
		slot_changed = true
	_target = i
	_refresh()
	if slot_changed:
		_notify_slots_changed()

func _on_alt_clicked(alt_idx: int) -> void:
	var alt_changed := false
	if alt_idx < _alts.size():
		_alts.remove_at(alt_idx)
		alt_changed = true
	_target = ALT_TARGET
	_refresh()
	if alt_changed:
		_notify_slots_changed()

# ---------------------------------------------------------------- Lưới túi đồ ứng viên

func _fill_candidate_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()

	var defs := _current_slot_defs()
	var kind := "alt" if _target == ALT_TARGET else (str(defs[_target]["kind"]) if _target < defs.size() else "")
	var label := "vật phẩm phụ" if _target == ALT_TARGET else (str(defs[_target]["label"]) if _target < defs.size() else "")
	_grid_title.text = "Hành trang — chọn %s:" % label.to_lower()

	if _profile == null or kind == "":
		_grid_scroll.visible = false
		return

	var used := _used_counts()
	var n := 0
	for it in _profile.inventory:
		it.ensure_uid()
		if not _item_fits_target(it, kind) or int(used.get(it.uid, 0)) >= it.count:
			continue
		var b := _create_bag_slot(it)
		_grid.add_child(b)
		n += 1

	if n == 0:
		_grid_title.text = "Gợi ý: Nhấp hoặc kéo thả vật phẩm từ Hành trang để đặt vào ô."
		_grid_title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		_grid_scroll.visible = false
	else:
		_grid_title.add_theme_color_override("font_color", SocialUi.LABEL_BLUE)
		_grid_scroll.visible = true

func _item_fits_target(item: ItemInstance, kind: String) -> bool:
	if _active_tab == Tab.REFINE:
		if _refine_sub == RefineSub.UPGRADE_XJ:
			return item.misc_id == Compound.XUANJING
		elif _refine_sub == RefineSub.UPGRADE_PROP:
			return item.misc_id in Compound.PROP_ORES

	return Compound.fits(item, kind)

func _create_bag_slot(item: ItemInstance) -> ItemSlotButton:
	var b := ItemSlotButton.new()
	b.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	b.small_icons = true
	var border_col := Color(0.78, 0.80, 0.84, 0.85)
	b.add_theme_stylebox_override("normal", GameUi.box(GameUi.BG_INNER, border_col, 4, 1, 2))
	b.add_theme_stylebox_override("hover", GameUi.box(GameUi.BG_INNER, Color(1.0, 0.85, 0.25), 4, 2, 2))
	b.add_theme_stylebox_override("pressed", GameUi.box(GameUi.ACTIVE_BG, Color(1.0, 0.85, 0.25), 4, 2, 2))
	b.show_item(item, ItemText.build(item, _profile))
	b.pressed.connect(_put.bind(item))
	b.set_drag_forwarding(_get_bag_slot_drag_data.bind(item, b), Callable(), Callable())
	if item.is_misc() and item.item_level > 0:
		var lv := SocialUi.label("C%d" % item.item_level, SocialUi.GOLD, 11)
		lv.position = Vector2(2, 1)
		lv.add_theme_color_override("font_outline_color", Color.BLACK)
		lv.add_theme_constant_override("outline_size", 3)
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lv)
	return b

func _put(item: ItemInstance) -> void:
	if item == null:
		return

	var defs := _current_slot_defs()
	var used := _used_counts()
	if int(used.get(item.uid, 0)) >= item.count:
		_show_error("Vật phẩm '%s' đã được đặt hết vào ô chế tạo." % item.get_display_name())
		return

	var placed := false

	# 1. Thử đặt vào ô đang được chọn (_target) nếu món phù hợp với loại ô đó
	if _target >= 0 and _target < defs.size():
		var err := _validate_item_for_slot(item, _target)
		if err == "":
			_slots[_target] = item
			placed = true
	elif _target == ALT_TARGET:
		var err := _validate_item_for_alt(item)
		if err == "":
			_alts.append(item)
			placed = true

	# 2. Nếu ô đang chọn không phù hợp, tự tìm ô chính trống đầu tiên hợp lệ
	if not placed:
		for i in defs.size():
			if _slots[i] == null and _validate_item_for_slot(item, i) == "":
				_slots[i] = item
				_target = i
				placed = true
				break

	# 3. Nếu các ô chính đã đầy nhưng món khớp với 1 ô chính nào đó, thay thế vào ô chính đó
	if not placed:
		for i in defs.size():
			if _validate_item_for_slot(item, i) == "":
				_slots[i] = item
				_target = i
				placed = true
				break

	# 4. Nếu không khớp ô chính, thử đặt vào ô phụ (alt) nếu công thức hỗ trợ
	if not placed and Compound.uses_alt(_current_op()):
		var err_alt := _validate_item_for_alt(item)
		if err_alt == "":
			_alts.append(item)
			_target = ALT_TARGET
			placed = true

	# 5. Món hoàn toàn không phù hợp với công thức chế tạo hiện tại
	if not placed:
		if _target >= 0 and _target < defs.size():
			var specific_err := _validate_item_for_slot(item, _target)
			_show_error(specific_err)
		else:
			_show_error("Vật phẩm '%s' không thể đặt vào bất kỳ ô nào của công thức này." % item.get_display_name())
		return

	# Tự động nhảy con trỏ chọn sang ô trống tiếp theo (nếu có)
	for k in defs.size():
		var j := (_target + 1 + k) % defs.size()
		if _slots[j] == null:
			_target = j
			break

	_clear_error()
	_refresh()
	_notify_slots_changed()

# ---------------------------------------------------------------- Kéo thả & Kiểm tra điều kiện từng ô

func _make_item_drag_preview(item: ItemInstance, btn_size: Vector2 = Vector2(40, 40)) -> Control:
	var preview := Control.new()
	var icon := item.get_icon(true)
	if icon:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.size = btn_size
		tex.position = -btn_size * 0.5
		tex.modulate.a = 0.85
		preview.add_child(tex)
		var frame := ReferenceRect.new()
		frame.border_color = RarityRing.color_of(item) if (item.is_purple() or item.is_gold()) else Color(0.8, 0.7, 0.3, 0.8)
		frame.size = btn_size
		frame.position = -btn_size * 0.5
		frame.editor_only = false
		preview.add_child(frame)
	return preview

func _get_bag_slot_drag_data(_at: Vector2, item: ItemInstance, btn: Control) -> Variant:
	btn.set_drag_preview(_make_item_drag_preview(item, Vector2(SLOT_SIZE, SLOT_SIZE)))
	return {"type": ItemRoomView.DRAG_TYPE, "item": item, "source": "compound_bag"}

func _get_craft_slot_drag_data(_at: Vector2, slot_idx: int, btn: Control) -> Variant:
	if slot_idx < 0 or slot_idx >= _slots.size() or _slots[slot_idx] == null:
		return null
	var item: ItemInstance = _slots[slot_idx]
	btn.set_drag_preview(_make_item_drag_preview(item, btn.size))
	return {"type": ItemRoomView.DRAG_TYPE, "item": item, "source": "craft_slot", "from_slot": slot_idx, "compound_win": self}

func _get_alt_slot_drag_data(_at: Vector2, alt_idx: int, btn: Control) -> Variant:
	if alt_idx < 0 or alt_idx >= _alts.size() or _alts[alt_idx] == null:
		return null
	var item: ItemInstance = _alts[alt_idx]
	btn.set_drag_preview(_make_item_drag_preview(item, btn.size))
	return {"type": ItemRoomView.DRAG_TYPE, "item": item, "source": "craft_alt", "from_alt": alt_idx, "compound_win": self}

func _can_drop_on_slot(_at: Vector2, data: Variant, _i: int) -> bool:
	return data is Dictionary and data.get("type") == ItemRoomView.DRAG_TYPE

func _drop_on_slot(_at: Vector2, data: Variant, i: int, slot_btn: Control = null) -> void:
	if not (data is Dictionary and data.get("type") == ItemRoomView.DRAG_TYPE):
		return
	var item: ItemInstance = data.get("item")
	if item == null or i < 0 or i >= _slots.size():
		return

	var from_source: String = str(data.get("source", ""))
	var from_slot: int = int(data.get("from_slot", -1))
	var from_alt: int = int(data.get("from_alt", -1))

	var err := _validate_item_for_slot(item, i, from_source, from_slot)
	if err != "":
		_show_error(err, slot_btn)
		return

	if from_source == "craft_slot" and from_slot >= 0 and from_slot < _slots.size() and from_slot != i:
		var existing: ItemInstance = _slots[i]
		if existing != null:
			var swap_err := _validate_item_for_slot(existing, from_slot, "craft_slot", i)
			if swap_err != "":
				_show_error("Không thể đổi chỗ: %s" % swap_err, slot_btn)
				return
			_slots[from_slot] = existing
		else:
			_slots[from_slot] = null
	elif from_source == "craft_alt" and from_alt >= 0 and from_alt < _alts.size():
		_alts.remove_at(from_alt)

	_slots[i] = item
	_target = i
	_clear_error()
	_refresh()
	_notify_slots_changed()

func _can_drop_on_alt(_at: Vector2, data: Variant, _alt_idx: int = -1) -> bool:
	return data is Dictionary and data.get("type") == ItemRoomView.DRAG_TYPE

func _drop_on_alt(_at: Vector2, data: Variant, alt_idx: int = -1, alt_btn: Control = null) -> void:
	if not (data is Dictionary and data.get("type") == ItemRoomView.DRAG_TYPE):
		return
	var item: ItemInstance = data.get("item")
	if item == null:
		return

	var from_source: String = str(data.get("source", ""))
	var from_slot: int = int(data.get("from_slot", -1))
	var from_alt: int = int(data.get("from_alt", -1))

	var err := _validate_item_for_alt(item, from_source, from_alt)
	if err != "":
		_show_error(err, alt_btn)
		return

	if from_source == "craft_slot" and from_slot >= 0 and from_slot < _slots.size():
		_slots[from_slot] = null
	elif from_source == "craft_alt" and from_alt >= 0 and from_alt < _alts.size():
		if alt_idx >= 0 and alt_idx < _alts.size() and from_alt != alt_idx:
			var tmp: ItemInstance = _alts[alt_idx]
			_alts[alt_idx] = _alts[from_alt]
			_alts[from_alt] = tmp
			_target = ALT_TARGET
			_clear_error()
			_refresh()
			_notify_slots_changed()
			return
		else:
			_alts.remove_at(from_alt)

	if alt_idx >= 0 and alt_idx < _alts.size():
		_alts[alt_idx] = item
	else:
		_alts.append(item)

	_target = ALT_TARGET
	_clear_error()
	_refresh()
	_notify_slots_changed()

func _can_drop_on_remove_zone(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == ItemRoomView.DRAG_TYPE and str(data.get("source", "")).begins_with("craft_")

func _drop_on_remove_zone(_at: Vector2, data: Variant) -> void:
	var from_source: String = str(data.get("source", ""))
	var from_slot: int = int(data.get("from_slot", -1))
	var from_alt: int = int(data.get("from_alt", -1))
	if from_source == "craft_slot" and from_slot >= 0 and from_slot < _slots.size() and _slots[from_slot] != null:
		var name: String = _slots[from_slot].get_display_name()
		_slots[from_slot] = null
		_clear_error()
		_show_toast("Đã gỡ %s khỏi ô chế tạo" % name)
		_refresh()
		_notify_slots_changed()
	elif from_source == "craft_alt" and from_alt >= 0 and from_alt < _alts.size():
		var name: String = _alts[from_alt].get_display_name()
		_alts.remove_at(from_alt)
		_clear_error()
		_show_toast("Đã gỡ %s khỏi ô phụ" % name)
		_refresh()
		_notify_slots_changed()

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if slot_idx >= 0 and slot_idx < _slots.size() and _slots[slot_idx] != null:
			var removed_name: String = _slots[slot_idx].get_display_name()
			_slots[slot_idx] = null
			_clear_error()
			_show_toast("Đã gỡ %s khỏi ô" % removed_name)
			_refresh()
			_notify_slots_changed()
			accept_event()

func _on_alt_gui_input(event: InputEvent, alt_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if alt_idx >= 0 and alt_idx < _alts.size():
			var removed_name: String = _alts[alt_idx].get_display_name()
			_alts.remove_at(alt_idx)
			_clear_error()
			_show_toast("Đã gỡ %s khỏi ô phụ" % removed_name)
			_refresh()
			_notify_slots_changed()
			accept_event()

# ---------------------------------------------------------------- Bộ quy tắc kiểm tra điều kiện từng ô

func _validate_item_for_slot(item: ItemInstance, slot_idx: int, from_source: String = "", from_slot: int = -1) -> String:
	if item == null:
		return "Không có vật phẩm."
	if item.lock_state != ItemInstance.LOCK_NORMAL:
		return "Vật phẩm đang bị khóa, không thể dùng chế tạo."
	if item.trade_price > 0:
		return "Vật phẩm đang bày bán, không thể dùng chế tạo."

	var defs := _current_slot_defs()
	if slot_idx < 0 or slot_idx >= defs.size():
		return "Vị trí ô không hợp lệ."

	# Kiểm tra số lượng đã dùng trong các ô
	var used := _used_counts()
	var cur_count := int(used.get(item.uid, 0))
	if from_source == "craft_slot" and from_slot >= 0 and from_slot < _slots.size() and _slots[from_slot] == item:
		cur_count -= 1
	elif from_source == "craft_alt":
		cur_count -= 1
	if _slots[slot_idx] == item:
		cur_count -= 1

	if cur_count >= item.count:
		return "Vật phẩm '%s' đã được đặt trong ô chế tạo khác." % item.get_display_name()

	var def: Dictionary = defs[slot_idx]
	var kind: String = str(def.get("kind", ""))
	var label: String = str(def.get("label", ""))

	# Kiểm tra loại món phù hợp với loại ô
	if not _item_fits_target(item, kind):
		return _get_kind_mismatch_error(item, kind, label)

	# Kiểm tra quy tắc liên kết giữa các ô
	match _active_tab:
		Tab.REFINE:
			match _refine_sub:
				RefineSub.UPGRADE_XJ:
					if item.item_level >= 10:
						return "Huyền Tinh đã đạt cấp tối đa (cấp 10), không thể thăng cấp."
					for j in _slots.size():
						if j != slot_idx and (from_source != "craft_slot" or j != from_slot) and _slots[j] != null:
							var other: ItemInstance = _slots[j]
							if item.item_level != other.item_level:
								return "Huyền Tinh nâng cấp phải cùng cấp %d (viên này cấp %d)." % [other.item_level, item.item_level]
				RefineSub.UPGRADE_PROP:
					if item.item_level >= 10:
						return "Khoáng thạch đã đạt cấp tối đa (cấp 10), không thể thăng cấp."
					for j in _slots.size():
						if j != slot_idx and (from_source != "craft_slot" or j != from_slot) and _slots[j] != null:
							var other: ItemInstance = _slots[j]
							if item.misc_id != other.misc_id:
								return "Khoáng thạch phải cùng loại với các ô đã đặt."
							if item.item_level != other.item_level:
								return "Khoáng thạch phải cùng cấp %d (viên này cấp %d)." % [other.item_level, item.item_level]
							if item.ore_magic != other.ore_magic:
								return "Khoáng thạch phải cùng dòng thuộc tính với các ô đã đặt."
							if (Compound.PROP_ORES.find(item.misc_id) % 2 == 1) and item.series != other.series:
								return "Khoáng thạch dòng ẩn phải cùng ngũ hành hệ %s." % ElementTypes.ELEMENT_NAME.get(other.series, "")
				RefineSub.KILLER:
					for j in _slots.size():
						if j != slot_idx and (from_source != "craft_slot" or j != from_slot) and _slots[j] != null:
							var other: ItemInstance = _slots[j]
							if item.get_level() != other.get_level():
								return "Sát Thủ Lệnh phải cùng cấp %d (lệnh này cấp %d)." % [other.get_level(), item.get_level()]

		Tab.DISTILL:
			if slot_idx == 2:
				var equip: ItemInstance = _slots[0]
				if from_source == "craft_slot" and from_slot == 0:
					equip = null
				if equip != null:
					var pos := Compound.RAW_ORES.find(item.misc_id) + 1
					if pos > 0:
						if pos % 2 == 0 and equip.series != item.series:
							return "Nguyên thạch hút dòng ẩn (%d) phải cùng hệ %s với trang bị." % [pos, ElementTypes.ELEMENT_NAME.get(equip.series, "")]
						if pos > equip.magic.size():
							return "Trang bị trong ô 1 không có dòng thuộc tính thứ %d." % pos
						var line: Dictionary = equip.magic[pos - 1]
						var mid := Compound.magic_id_of(line)
						if mid > 0 and not Compound.match_series(mid, item.series):
							return "Dòng thuộc tính thứ %d không phù hợp với ngũ hành của nguyên thạch." % pos
			elif slot_idx == 0:
				var ore: ItemInstance = _slots[2]
				if from_source == "craft_slot" and from_slot == 2:
					ore = null
				if ore != null:
					var pos := Compound.RAW_ORES.find(ore.misc_id) + 1
					if pos > 0:
						if pos % 2 == 0 and item.series != ore.series:
							return "Trang bị phải cùng ngũ hành hệ %s với nguyên thạch đã đặt." % ElementTypes.ELEMENT_NAME.get(ore.series, "")
						if pos > item.magic.size():
							return "Trang bị này không có dòng thuộc tính thứ %d để hút." % pos
						var line: Dictionary = item.magic[pos - 1]
						var mid := Compound.magic_id_of(line)
						if mid > 0 and not Compound.match_series(mid, ore.series):
							return "Dòng thuộc tính thứ %d không phù hợp với ngũ hành của nguyên thạch." % pos

		Tab.ENCHASE:
			if slot_idx == 2:
				var equip: ItemInstance = _slots[0]
				if from_source == "craft_slot" and from_slot == 0:
					equip = null
				if equip != null:
					var first_empty_pos := equip.magic.size() + 1
					var ore_pos := Compound.PROP_ORES.find(item.misc_id) + 1
					if first_empty_pos > equip.sockets:
						return "Trang bị tím đã khảm đầy tất cả %d ô khảm." % equip.sockets
					if ore_pos != first_empty_pos:
						var expected_name := str(ItemDatabase.get_misc(Compound.PROP_ORES[first_empty_pos - 1]).get("name", "Khoáng ô %d" % first_empty_pos))
						return "Ô khảm trống đầu tiên là ô %d — cần khoáng '%s'." % [first_empty_pos, expected_name]
					if first_empty_pos % 2 == 0 and equip.series != item.series:
						return "Khoáng thuộc tính dòng ẩn (%d) phải cùng hệ %s với đồ tím." % [first_empty_pos, ElementTypes.ELEMENT_NAME.get(equip.series, "")]
					var mid := item.ore_magic
					if mid > 0:
						if not Compound.match_equip(mid, equip.get_detail(), int(equip.get_base().get("particular", 0))):
							return "Thuộc tính khoáng thạch không phù hợp với vị trí trang bị này."
						if not Compound.match_series(mid, equip.series):
							return "Thuộc tính khoáng thạch không phù hợp với ngũ hành của trang bị."
						for line in equip.magic:
							if Compound.magic_id_of(line) == mid:
								return "Trang bị tím đã có dòng thuộc tính này rồi."
			elif slot_idx == 0:
				var ore: ItemInstance = _slots[2]
				if from_source == "craft_slot" and from_slot == 2:
					ore = null
				if ore != null:
					var first_empty_pos := item.magic.size() + 1
					var ore_pos := Compound.PROP_ORES.find(ore.misc_id) + 1
					if first_empty_pos > item.sockets:
						return "Trang bị tím này đã khảm đầy %d ô khảm." % item.sockets
					if ore_pos != first_empty_pos:
						var expected_name := str(ItemDatabase.get_misc(Compound.PROP_ORES[first_empty_pos - 1]).get("name", "Khoáng ô %d" % first_empty_pos))
						return "Trang bị tím này cần khoáng '%s' cho ô trống đầu tiên (ô %d)." % [expected_name, first_empty_pos]
					if first_empty_pos % 2 == 0 and item.series != ore.series:
						return "Trang bị tím phải cùng ngũ hành hệ %s với khoáng dòng ẩn." % ElementTypes.ELEMENT_NAME.get(ore.series, "")

	return ""

func _get_kind_mismatch_error(item: ItemInstance, kind: String, label: String) -> String:
	match kind:
		"ring":
			return "Ô '%s' chỉ nhận Nhẫn (trang bị trắng hoặc xanh)." % label
		"necklace":
			return "Ô '%s' chỉ nhận Dây chuyền hoặc Hộ thân phù (trang bị trắng hoặc xanh)." % label
		"pendant":
			return "Ô '%s' chỉ nhận Ngọc bội hoặc Hương nang (trang bị trắng hoặc xanh)." % label
		"xuanjing":
			return "Ô '%s' chỉ nhận Huyền Tinh khoáng thạch." % label
		"raw_ore":
			return "Ô '%s' chỉ nhận Nguyên khoáng hoặc Nguyên thạch (cấp 1 - 6)." % label
		"prop_ore":
			return "Ô '%s' chỉ nhận Khoáng thạch thuộc tính (đã có thuộc tính)." % label
		"token":
			return "Ô '%s' chỉ nhận Sát Thủ Lệnh." % label
		"equip_normal":
			if item.is_gold() or item.is_purple() or item.is_misc():
				return "Ô '%s' chỉ nhận Trang bị màu xanh có thuộc tính (không nhận đồ tím, hoàng kim hoặc vật phẩm)." % label
			if item.magic.is_empty():
				return "Ô '%s' chỉ nhận Trang bị xanh có dòng thuộc tính (món này không có thuộc tính)." % label
			return "Ô '%s' chỉ nhận Trang bị màu xanh có dòng thuộc tính." % label
		"equip_forge":
			if item.get_detail() in Compound.JEWELRY:
				return "Ô '%s' không nhận đồ trang sức (nhẫn/dây chuyền/ngọc bội), chỉ nhận vũ khí hoặc phòng cụ." % label
			if item.is_gold() or item.is_purple() or item.is_misc():
				return "Ô '%s' chỉ nhận Trang bị trắng hoặc xanh (không nhận đồ tím, hoàng kim hoặc vật phẩm)." % label
			return "Ô '%s' chỉ nhận Trang bị vũ khí hoặc phòng cụ xanh/trắng." % label
		"equip_purple":
			if not item.is_purple():
				return "Ô '%s' chỉ nhận Trang bị Huyền Tinh (đồ tím)." % label
			if item.sockets <= 0:
				return "Ô '%s' chỉ nhận Trang bị tím có ô khảm." % label
			return "Ô '%s' chỉ nhận Trang bị tím có ô khảm." % label
		"blueprint":
			return "Ô '%s' chỉ nhận Đồ phổ Hoàng Kim." % label
		"skill_book":
			return "Ô '%s' chỉ nhận Bí kíp kỹ năng môn phái." % label
		"stone":
			return "Ô '%s' chỉ nhận Huyền Tinh hoặc Khoáng thạch thuộc tính." % label
		"alt":
			return "Ô '%s' chỉ nhận vật phẩm phụ (Thần Bí Khoáng Thạch, Thủy Tinh, Phúc Duyên Lộ, Huyền Tinh)." % label
	return "Ô '%s' không chấp nhận vật phẩm '%s'." % [label, item.get_display_name()]

func _validate_item_for_alt(item: ItemInstance, from_source: String = "", from_alt: int = -1) -> String:
	if item == null:
		return "Không có vật phẩm."
	if not Compound.uses_alt(_current_op()):
		return "Công thức này không sử dụng vật phẩm phụ."
	if item.lock_state != ItemInstance.LOCK_NORMAL:
		return "Vật phẩm đang bị khóa, không thể dùng làm vật phẩm phụ."
	if item.trade_price > 0:
		return "Vật phẩm đang bày bán, không thể dùng làm vật phẩm phụ."
	if not Compound.fits(item, "alt"):
		return "Vật phẩm '%s' không phải vật phẩm phụ hợp lệ (chỉ nhận Thần Bí Khoáng Thạch, Thủy Tinh, Phúc Duyên Lộ, Huyền Tinh)." % item.get_display_name()

	var used := _used_counts()
	var cur_count := int(used.get(item.uid, 0))
	if from_source == "craft_alt":
		cur_count -= 1
	elif from_source == "craft_slot":
		cur_count -= 1

	if cur_count >= item.count:
		return "Vật phẩm '%s' đã được đặt trong ô chế tạo khác." % item.get_display_name()

	var max_alt := 8 if _active_tab == Tab.DOPHO else 6
	if from_source != "craft_alt" and _alts.size() >= max_alt:
		return "Các ô vật phẩm phụ đã đầy (%d/%d)." % [_alts.size(), max_alt]

	return ""

func _show_error(msg: String, slot_btn: Control = null) -> void:
	_message.text = "✖ %s" % msg
	_message.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	_show_toast(msg)
	if slot_btn and is_instance_valid(slot_btn):
		_flash_error_slot(slot_btn)

func _clear_error() -> void:
	_message.text = ""

func _flash_error_slot(slot_btn: Control) -> void:
	var red_box := GameUi.box(Color(0.28, 0.05, 0.05, 0.95), Color(1.0, 0.25, 0.25), 4, 2, 2)
	slot_btn.add_theme_stylebox_override("normal", red_box)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(slot_btn):
			_refresh()
	)

func _show_toast(msg: String) -> void:
	if _toast == null:
		_toast = Label.new()
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast.add_theme_font_size_override("font_size", 12)
		_toast.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
		_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_toast.add_theme_constant_override("outline_size", 4)
		var tbox := StyleBoxFlat.new()
		tbox.bg_color = Color(0.12, 0.02, 0.02, 0.94)
		tbox.border_color = Color(0.95, 0.3, 0.25, 0.9)
		tbox.set_border_width_all(1)
		tbox.set_corner_radius_all(4)
		tbox.set_content_margin_all(6)
		_toast.add_theme_stylebox_override("panel", tbox)
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.z_index = 50
		_slot_container.add_child(_toast)

	_toast.text = "⚠️ " + msg
	_toast.size = Vector2(_slot_container.size.x - 24, 0)
	_toast.position = Vector2(12, _slot_container.size.y * 0.5 - 20)
	_toast.modulate.a = 1.0
	_toast.visible = true
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void:
		if is_instance_valid(_toast):
			_toast.visible = false
	)

# ---------------------------------------------------------------- Hiển thị Mô tả & Dự báo

func _render_info_and_preview() -> void:
	var op := _current_op()
	var act_text := "Chế tạo"
	match _active_tab:
		Tab.REFINE:
			act_text = "Tinh luyện" if _refine_sub == RefineSub.XUANJING else ("Hợp thành" if _refine_sub == RefineSub.KILLER else "Thăng cấp")
		Tab.DISTILL:
			act_text = "Nâng cấp"
		Tab.FORGE:
			act_text = "Chế tạo"
		Tab.ENCHASE:
			act_text = "Khảm nạm"
		Tab.DOPHO:
			act_text = "Kết hợp"
	_action_button.text = act_text

	var lines := []
	var desc := _tab_rules_text()
	lines.append(desc)

	var cost: int = Compound.COST[op]
	lines.append("\n[color=#ffff77]Chi phí:[/color] %s" % ("miễn phí" if cost == 0 else "%s lượng" % InventoryPopup.format_money(cost)))

	if _slots.has(null):
		lines.append("\n[color=#888888]Chưa đủ nguyên liệu chính để tính toán kết quả.[/color]")
		_preview.text = "\n".join(lines)
		_action_button.disabled = true
		return

	var p := Compound.plan(_profile, op, _slots, _alts)
	if not p["ok"]:
		lines.append("\n[color=#ff5555]Lỗi: %s[/color]" % p["error"])
		_preview.text = "\n".join(lines)
		_action_button.disabled = true
		return

	if p.has("note"):
		lines.append("\n[color=#ffd75a]Lưu ý:[/color] [color=#e8d9a8]%s[/color]" % p["note"])

	lines.append("\n[color=#ffff77]Kết quả có thể nhận được:[/color]")
	for o in p["outcomes"]:
		lines.append("[color=#ffd75a]%5.1f%%[/color]  [color=#55ff55]%s[/color]" % [float(o["prob"]) * 100.0, o["text"]])
	if float(p["fail"]) > 0.0005:
		var note := (" (%s)" % p["fail_note"]) if p.has("fail_note") else " (mất nguyên liệu)"
		lines.append("[color=#ff7070]%5.1f%%  Thất bại%s[/color]" % [float(p["fail"]) * 100.0, note])

	_preview.text = "\n".join(lines)
	_action_button.disabled = false

func _tab_rules_text() -> String:
	match _active_tab:
		Tab.REFINE:
			match _refine_sub:
				RefineSub.XUANJING:
					return "[color=#55ff55]Nguyên liệu cần thiết:[/color] Giới chỉ một chiếc, Dây chuyền (Hộ thân phù) 1 sợi, Ngọc bội (Hương nang) 1 cái, 1.000 lượng.\n\n[color=#55ff55]Quy tắc:[/color] Đem những nguyên liệu cần thiết đặt vào 3 ô bên tay trái, nhấn Tinh luyện. Tổng giá trị của 3 trang sức quyết định cấp Huyền Tinh tạo thành (Cấp 1 - 10)."
				RefineSub.UPGRADE_XJ:
					return "[color=#55ff55]Nguyên liệu cần thiết:[/color] 3 viên Huyền Tinh khoáng thạch cùng cấp, 5.000 lượng.\n\n[color=#55ff55]Quy tắc:[/color] Đem 3 viên Huyền Tinh cùng cấp đặt vào 3 ô, nhấn Thăng cấp. Thành công nhận 1 viên cấp +1. Thất bại chỉ mất 1 viên đầu tiên."
				RefineSub.UPGRADE_PROP:
					return "[color=#55ff55]Nguyên liệu cần thiết:[/color] 3 viên khoáng thạch có cùng thuộc tính và cùng cấp, 5.000 lượng.\n\n[color=#55ff55]Quy tắc:[/color] Đem 3 viên khoáng thuộc tính cùng cấp đặt vào 3 ô. Nếu là dòng ẩn (dòng chẵn) phải cùng ngũ hành. Thất bại chỉ mất 1 viên đầu tiên."
				RefineSub.KILLER:
					return "[color=#55ff55]Nguyên liệu cần thiết:[/color] 5 Sát Thủ lệnh cùng cấp.\n\n[color=#55ff55]Quy tắc:[/color] Đem 5 Sát Thủ lệnh cùng cấp hợp thành 1 Sát thủ giản cùng cấp. Ngũ hành ngẫu nhiên theo 1 trong 5 lệnh. Không tốn tiền, không thất bại."
		Tab.DISTILL:
			return "[color=#55ff55]Nguyên liệu cần thiết:[/color] Thuộc tính khoáng nguyên, nguyên thạch, trang bị màu xanh, huyền tinh khoáng thạch, 5.000 lượng, khoáng thạch thần bí (Có thể chọn nguyên liệu), Phúc duyên lộ (Có thể chọn nguyên liệu), thủy tinh (Có thể chọn nguyên liệu).\n\n[color=#55ff55]Quy tắc:[/color] Đem trang bị xanh và nguyên khoáng/nguyên thạch đặt vào ô. Nguyên khoáng hút dòng hiện (1, 3, 5); nguyên thạch hút dòng ẩn (2, 4, 6) và phải cùng hệ với trang bị. Sau khi hút, trang bị xanh sẽ biến mất."
		Tab.FORGE:
			return "[color=#55ff55]Nguyên liệu cần thiết:[/color] Trang bị xanh hoặc trắng (Không phải đồ trang sức), huyền tinh khoáng thạch, 10.000 lượng.\n\n[color=#55ff55]Quy tắc:[/color] Đem tất cả nguyên liệu đặt vào ô bên tay trái, nhấn nút Chế tạo. Sau khi thành công sẽ có được một Trang bị Huyền Tinh (đồ tím) có từ 1 đến 5 ô khảm trống. Trang bị mất hết thuộc tính cũ."
		Tab.ENCHASE:
			return "[color=#55ff55]Nguyên liệu cần thiết:[/color] Trang bị Huyền Tinh, khoáng thạch có thuộc tính, huyền tinh khoáng thạch, 10.000 lượng, khoáng thạch thần bí (Có thể chọn nguyên liệu), phúc duyên lộ (Có thể chọn nguyên liệu), thủy tinh (Có thể chọn nguyên liệu).\n\n[color=#55ff55]Quy tắc:[/color] Đem trang bị tím, Huyền Tinh và khoáng thạch thuộc tính khảm tuần tự vào ô trống đầu tiên (ô 1: Huyền Thiết, ô 2: Khổng Tước, ô 3: Mật Ngân, ô 4: Phù Dung, ô 5: Chu Sa). Dòng chẵn phải cùng hệ với đồ. Thất bại vẫn giữ đồ tím."
		Tab.DOPHO:
			return "[color=#55ff55]Nguyên liệu cần thiết:[/color] Đồ phổ hoàng kim, khoáng thạch có thuộc tính (Số lượng chủng loại cần phải xem đồ phổ), sách kỹ năng, huyền tinh khoáng thạch, 100.000 lượng, khoáng thạch thần bí (Có thể chọn nguyên liệu)...\n\n[color=#55ff55]Quy tắc:[/color] Đem đồ phổ hoàng kim và các nguyên liệu yêu cầu đặt vào các ô tương ứng, nhấn Kết hợp để tạo trang bị Hoàng Kim môn phái."
	return ""

# ---------------------------------------------------------------- Thao tác Chế tạo

func _make() -> void:
	if _profile == null or _slots.has(null):
		return
	var op := _current_op()
	var uids := _slots.map(func(it: ItemInstance) -> String: return it.ensure_uid())
	var alt := _alts.map(func(it: ItemInstance) -> String: return it.ensure_uid())

	if NetClient.is_in_world() and not NetClient.is_hub:
		NetClient.send_craft(op, uids, alt)
		_slots = []
		for s in _current_slot_defs():
			_slots.append(null)
		_alts = []
		_target = 0
		_notify_slots_changed()
		_after_craft()
		return

	var r := Compound.run(_profile, op, uids, alt)
	_message.text = str(r["message"])
	if r["ok"]:
		SaveManager.save_profile(_profile)
		if AccountApi.is_logged_in():
			SaveManager.flush_online()
		_slots = []
		for s in _current_slot_defs():
			_slots.append(null)
		_alts = []
		_target = 0
		_show_toast(str(r["message"]))
		_notify_slots_changed()
	else:
		_show_error(str(r["message"]))
	_after_craft()

func _after_craft() -> void:
	_refresh()

func _on_notice(text: String) -> void:
	if not is_instance_valid(_message):
		return
	_message.text = text
	(func() -> void:
		if is_instance_valid(self):
			_profile = GameManager.local_profile if GameManager.local_profile else _profile
			_after_craft()
			if _on_changed.is_valid():
				_on_changed.call()).call_deferred()

# ---------------------------------------------------------------- Tiện ích quản lý danh sách món

func _used_counts() -> Dictionary:
	var used := {}
	for it in _slots + _alts:
		if it != null:
			used[it.uid] = int(used.get(it.uid, 0)) + 1
	return used

func _drop_missing() -> void:
	if _profile == null:
		return
	var have := {}
	for it in _profile.inventory:
		have[it.uid] = it
	var used := {}
	for i in _slots.size():
		var it: ItemInstance = _slots[i]
		if it == null:
			continue
		var cur: ItemInstance = have.get(it.uid)
		used[it.uid] = int(used.get(it.uid, 0)) + 1
		if cur == null or cur.count < int(used[it.uid]):
			_slots[i] = null
		else:
			_slots[i] = cur
	var keep := []
	for it in _alts:
		var cur: ItemInstance = have.get(it.uid)
		used[it.uid] = int(used.get(it.uid, 0)) + 1
		if cur != null and cur.count >= int(used[it.uid]):
			keep.append(cur)
	_alts = keep

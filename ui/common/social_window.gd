extends DraggableWindow
class_name SocialWindow

const TouchScrollHelperScript = preload("res://ui/common/touch_scroll_helper.gd")
## Cửa sổ xã hội theo ảnh mẫu: khung tối bo góc viền mảnh, tiêu đề vàng + phụ đề xám ở giữa, nút ✕ góc phải, kéo được bằng chỗ trống.
## Nội dung đặt vào `body` (VBoxContainer). Đóng: phát `close_requested` (người gọi tự queue_free khung / CanvasLayer cha).

var subtitle_label: Label
var header_panel: Panel
var title_label: Label
var is_docked: bool = false
var is_full_width: bool = false
var docked_width: float = 0.0

func _init(window_title: String = "", sub: String = "", min_width := 420.0) -> void:
	super._init(window_title, true)             ## frameless: không vẽ thanh tiêu đề mặc định, ta tự vẽ
	custom_minimum_size.x = min_width
	add_theme_stylebox_override("panel", WuxiaStyle.create_panel_box())

	var root: VBoxContainer = get_child(0) as VBoxContainer
	if root:
		root.add_theme_constant_override("separation", 0)
		header_panel = Panel.new()
		header_panel.custom_minimum_size.y = 32
		header_panel.add_theme_stylebox_override("panel", WuxiaStyle.create_header_bar())
		header_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		header_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
		header_panel.gui_input.connect(_on_header_input)
		root.add_child(header_panel)
		root.move_child(header_panel, 0)

		var h_box := HBoxContainer.new()
		h_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h_box.offset_left = 12
		h_box.offset_right = -8
		header_panel.add_child(h_box)

		title_label = Label.new()
		title_label.text = window_title
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
		title_label.add_theme_font_size_override("font_size", 15)
		h_box.add_child(title_label)

		var btn_x := Button.new()
		btn_x.text = "✕"
		btn_x.flat = true
		btn_x.focus_mode = Control.FOCUS_NONE
		btn_x.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn_x.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		btn_x.add_theme_color_override("font_hover_color", Color(0.95, 0.3, 0.25))
		btn_x.add_theme_font_size_override("font_size", 16)
		btn_x.pressed.connect(func() -> void: close_requested.emit())
		h_box.add_child(btn_x)
		close_button = btn_x

		if get_child_count() > 1:
			var overlay: Control = get_child(1) as Control
			if overlay:
				overlay.visible = false

		root.remove_child(body)
		var body_margin := MarginContainer.new()
		body_margin.name = "BodyMargin"
		body_margin.add_theme_constant_override("margin_left", 4)
		body_margin.add_theme_constant_override("margin_top", 4)
		body_margin.add_theme_constant_override("margin_right", 4)
		body_margin.add_theme_constant_override("margin_bottom", 4)
		body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_margin.add_child(body)
		root.add_child(body_margin)

	body.add_theme_constant_override("separation", 6)
	subtitle_label = SocialUi.subtitle(sub)
	subtitle_label.visible = sub != ""
	body.add_child(subtitle_label)

var docked_pos: Vector2 = Vector2(18, 68)

func set_draggable(can_drag: bool) -> void:
	super.set_draggable(can_drag)
	if header_panel:
		header_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE if draggable else Control.CURSOR_ARROW

func setup_touch_scroll() -> void:
	var scrolls: Array[ScrollContainer] = []
	_collect_scrolls(self, scrolls)
	if scrolls.size() == 1:
		TouchScrollHelperScript.attach(scrolls[0], body)
	else:
		for s in scrolls:
			var parent_control := s.get_parent() as Control
			TouchScrollHelperScript.attach(s, parent_control if parent_control != null else s)

func _collect_scrolls(node: Node, out: Array[ScrollContainer]) -> void:
	if node is ScrollContainer:
		out.append(node)
	for c in node.get_children():
		if not (c is DraggableWindow and c != self):
			_collect_scrolls(c, out)

func _enter_tree() -> void:
	if is_docked or _is_in_character_hub():
		set_draggable(false)

func _ready() -> void:
	if is_docked or _is_in_character_hub():
		set_draggable(false)
	setup_touch_scroll.call_deferred()
	if is_docked:
		var target_width: float = 1000.0 if is_full_width else (docked_width if docked_width > 0.0 else 500.0)
		position = docked_pos
		size = Vector2(target_width, 585)
		custom_minimum_size = Vector2(target_width, 585)
		clip_contents = true
		if close_button:
			close_button.visible = false
		set_deferred("size", Vector2(target_width, 585))
		set_deferred("position", docked_pos)
		return
	super._ready()

func set_docked(docked: bool, full_width: bool = false, custom_width: float = 0.0, custom_pos: Vector2 = Vector2(-1, -1)) -> void:
	is_docked = docked
	set_draggable(not is_docked)
	is_full_width = full_width
	docked_width = custom_width
	if custom_pos != Vector2(-1, -1):
		docked_pos = custom_pos
	else:
		docked_pos = Vector2(18, 68)
	if is_docked:
		var target_width: float = 1000.0 if is_full_width else (docked_width if docked_width > 0.0 else 500.0)
		custom_minimum_size = Vector2(target_width, 585)
		size = Vector2(target_width, 585)
		position = docked_pos
		clip_contents = true
		if header_panel:
			header_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		if close_button:
			close_button.visible = false
		set_deferred("size", Vector2(target_width, 585))
		set_deferred("position", docked_pos)

func _on_header_input(event: InputEvent) -> void:
	if is_docked:
		return
	_on_bar_input(event)

func set_title(text: String) -> void:
	title = text
	if title_label:
		title_label.text = text

func set_subtitle(text: String) -> void:
	subtitle_label.text = text
	subtitle_label.visible = text != ""

## Hàng nút "đá" xếp đều ở đáy khung — trả về HBox để người gọi add_child từng nút.
func add_button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	return row

## Đưa cửa sổ lên màn hình: bọc trong CanvasLayer (DraggableWindow đổi `layer` để nổi lên trên) gắn vào `host`. Mỗi loại cửa sổ (`kind`)
## chỉ mở 1 cái — mở lại thì đưa cái đang mở lên trên và trả về nó.
var kind: StringName = &""

func get_host() -> Node:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree != null else null

static func present(host: Node, win: SocialWindow, window_kind: StringName = &"") -> SocialWindow:
	if host != null and (host.name == "CharacterHub" or host.is_in_group("character_hub") or host.find_parent("CharacterHub") != null or (host.get_tree() and host.get_tree().current_scene != null and host.get_tree().current_scene.name == "CharacterHub")):
		win.set_draggable(false)
	var tree := host.get_tree() if host != null and host.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if window_kind != &"" and tree != null:
		for w in tree.get_nodes_in_group("social_windows"):
			if w is SocialWindow and w.kind == window_kind and is_instance_valid(w):
				(w as SocialWindow).bring_to_front()
				win.queue_free()
				return w
	win.kind = window_kind
	win.add_to_group("social_windows")
	var layer := CanvasLayer.new()
	layer.layer = DraggableWindow.WINDOW_LAYER + 1
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(win)
	if host != null and is_instance_valid(host):
		host.add_child(layer)
	elif tree != null and tree.current_scene != null:
		tree.current_scene.add_child(layer)
	win.close_requested.connect(func() -> void: layer.queue_free())
	return win

## Hộp nhập 1 dòng chữ (đặt giá, nhập số tiền, mật khẩu...). on_ok(text) được gọi khi bấm Đồng ý.
static func prompt(host: Node, window_title: String, hint: String, on_ok: Callable, default_text := "", secret := false) -> void:
	var win := SocialWindow.new(window_title, "", 340.0)
	var edit := SocialUi.line_edit(hint, secret)
	edit.text = default_text
	win.body.add_child(edit)
	var row := win.add_button_row()
	var ok := SocialUi.stone_button("Đồng ý")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cancel := SocialUi.stone_button("Huỷ")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	row.add_child(cancel)
	var layer := present(host, win, &"")
	var submit := func() -> void:
		var text := edit.text
		win.close_requested.emit()
		on_ok.call(text)
	ok.pressed.connect(submit)
	edit.text_submitted.connect(func(_t: String) -> void: submit.call())
	cancel.pressed.connect(func() -> void: win.close_requested.emit())
	edit.call_deferred("grab_focus")

## Hộp hỏi Có/Không.
static func confirm(host: Node, window_title: String, question: String, on_yes: Callable) -> void:
	ask_yes_no(host, window_title, question, func(yes: bool) -> void:
		if yes:
			on_yes.call(), "Đồng ý", "Huỷ")

## Hộp hỏi 2 lựa chọn (lời mời giao dịch / tổ đội / bang...): on_answer(true|false) gọi đúng 1 lần — bấm ✕ cũng tính là "không".
static func ask_yes_no(host: Node, window_title: String, question: String, on_answer: Callable, yes_text := "Đồng ý", no_text := "Từ chối") -> SocialWindow:
	var win := SocialWindow.new(window_title, "", 360.0)
	var l := SocialUi.label(question, SocialUi.TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win.body.add_child(l)
	var row := win.add_button_row()
	var yes := SocialUi.stone_button(yes_text)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var no := SocialUi.stone_button(no_text)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
	row.add_child(no)
	present(host, win, &"")
	var answered := [false]
	var answer := func(v: bool) -> void:
		if answered[0]:
			return
		answered[0] = true
		win.close_requested.emit()
		on_answer.call(v)
	yes.pressed.connect(answer.bind(true))
	no.pressed.connect(answer.bind(false))
	win.close_requested.connect(func() -> void: answer.call(false))
	return win

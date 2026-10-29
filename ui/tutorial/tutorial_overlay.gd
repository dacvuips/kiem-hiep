extends CanvasLayer
class_name TutorialOverlay
## Màn hình Hướng Dẫn Tân Thủ (Introduce / Tutorial)
## 2 Chế độ hoạt động:
## - Dạng 1 (INITIAL / Đầu Game): Khi mới vào game, hướng dẫn ngay lập tức, không cho người dùng nhấp ra ngoài hay ấn nút khác, bắt buộc trải nghiệm.
## - Dạng 2 (EXPLORE / Bấm nút Hướng Dẫn): Giới thiệu hết tất cả các nút trên giao diện, có điều khiển Trước/Sau, cho phép tắt bất cứ lúc nào.

enum Mode {
	INITIAL = 0, # Dạng đầu game: Bắt buộc, không cho click chỗ khác
	EXPLORE = 1, # Dạng 2: Bấm nút Hướng Dẫn, giới thiệu toàn diện, tắt lúc nào cũng được
}

const COLOR_GOLD := Color(0.96, 0.82, 0.35, 1.0)
const COLOR_GOLD_BRIGHT := Color(1.0, 0.94, 0.55, 1.0)
const COLOR_CYAN := Color(0.38, 0.85, 0.92, 1.0)
const COLOR_ORANGE := Color(1.0, 0.68, 0.28, 1.0)
const COLOR_DIM := Color(0.015, 0.035, 0.06, 0.52) # Tối vừa phải để làm nổi bật vùng sáng

@onready var _dim_control: Control = %DimControl
@onready var _welcome_dialog: PanelContainer = %WelcomeDialog
@onready var _btn_start_intro: Button = %BtnStartIntro
@onready var _btn_skip_intro: Button = %BtnSkipIntro
@onready var _callout_box: PanelContainer = %CalloutBox
@onready var _step_label: Label = %StepLabel
@onready var _title_label: Label = %TitleLabel
@onready var _btn_close_step: Button = %BtnCloseStep
@onready var _what_label: Label = %WhatLabel
@onready var _todo_label: Label = %TodoLabel
@onready var _where_label: Label = %WhereLabel
@onready var _hint_footer: Label = %HintFooter
@onready var _nav_control_box: HBoxContainer = %NavControlBox
@onready var _btn_prev_step: Button = %BtnPrevStep
@onready var _btn_next_step: Button = %BtnNextStep
@onready var _btn_dismiss: Button = %BtnDismiss
@onready var _pointer_arrow: Control = %PointerArrow
@onready var _arrow_label: Label = %ArrowLabel
@onready var _completion_dialog: PanelContainer = %CompletionDialog
@onready var _btn_finish: Button = %BtnFinish

var _steps: Array[Dictionary] = []
var _mode: int = Mode.INITIAL
var _current_step_idx: int = -1
var _target_rect: Rect2 = Rect2()
var _target_dest_rect: Rect2 = Rect2()
var _current_target_node: Control = null
var _is_spotlight_active: bool = false
var _pulse_time: float = 0.0
var _pulse_alpha: float = 1.0
var _pulse_ring: float = 0.0
var _arrow_base_pos: Vector2 = Vector2.ZERO
var _arrow_direction: Vector2 = Vector2.LEFT
var _shake_tween: Tween = null
var _rect_tween: Tween = null

func _ready() -> void:
	layer = 125
	_btn_start_intro.pressed.connect(_on_start_intro_pressed)
	_btn_skip_intro.pressed.connect(_on_skip_intro_pressed)
	_btn_close_step.pressed.connect(_on_close_clicked)
	_btn_finish.pressed.connect(_on_finish_pressed)

	_btn_prev_step.pressed.connect(_on_prev_step_pressed)
	_btn_next_step.pressed.connect(_on_next_step_pressed)
	_btn_dismiss.pressed.connect(_on_close_clicked)

	_dim_control.gui_input.connect(_on_dim_gui_input)
	_dim_control.draw.connect(_on_dim_draw)

	var tag_what := get_node_or_null("%TagWhat") as Label
	if tag_what == null:
		tag_what = get_node_or_null("DimControl/CalloutBox/VBox/SectionWhat/TagWhat") as Label
	if tag_what:
		tag_what.text = tr("【CÁI NÀY LÀ CÁI GÌ】")

	var tag_todo := get_node_or_null("%TagTodo") as Label
	if tag_todo == null:
		tag_todo = get_node_or_null("DimControl/CalloutBox/VBox/SectionTodo/TagTodo") as Label
	if tag_todo:
		tag_todo.text = tr("【LÀM GÌ】")

	var tag_where := get_node_or_null("%TagWhere") as Label
	if tag_where == null:
		tag_where = get_node_or_null("DimControl/CalloutBox/VBox/SectionWhere/TagWhere") as Label
	if tag_where:
		tag_where.text = tr("【ĐI ĐÂU】")

	_btn_prev_step.text = tr("◀ Trước")
	_btn_dismiss.text = tr("✕ Đóng")
	_btn_close_step.text = tr("✕ Đóng")
	_btn_start_intro.text = tr("⚔️ BẮT ĐẦU HƯỚNG DẪN")
	_btn_skip_intro.text = tr("✕ TÔI ĐÃ HIỂU RỒI")
	_btn_finish.text = tr("⚔️ BẮT ĐẦU BÔN TẨU GIANG HỒ")

	_callout_box.visible = false
	_completion_dialog.visible = false
	_pointer_arrow.visible = false

func setup(steps: Array[Dictionary], mode_param = Mode.INITIAL) -> void:
	_steps = steps
	if typeof(mode_param) == TYPE_INT:
		_mode = mode_param
	elif typeof(mode_param) == TYPE_BOOL:
		_mode = Mode.EXPLORE if mode_param else Mode.INITIAL
	else:
		_mode = Mode.INITIAL

	_welcome_dialog.visible = false
	_start_steps()

func _show_welcome() -> void:
	_is_spotlight_active = false
	_welcome_dialog.visible = true
	_callout_box.visible = false
	_completion_dialog.visible = false
	_pointer_arrow.visible = false
	_dim_control.queue_redraw()

	_welcome_dialog.modulate.a = 0.0
	_welcome_dialog.scale = Vector2(0.9, 0.9)
	_welcome_dialog.pivot_offset = _welcome_dialog.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_welcome_dialog, "modulate:a", 1.0, 0.25)
	tween.tween_property(_welcome_dialog, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_start_intro_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(_welcome_dialog, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func() -> void:
		_welcome_dialog.visible = false
		_start_steps()
	)

func _on_skip_intro_pressed() -> void:
	close_tutorial()

func _on_finish_pressed() -> void:
	close_tutorial()

func _start_steps() -> void:
	_current_step_idx = -1
	_welcome_dialog.visible = false
	_show_step(0, true)

func _show_step(target_idx: int, forward: bool = true) -> void:
	if target_idx < 0:
		return
	if target_idx >= _steps.size():
		if _mode == Mode.INITIAL:
			_show_completion()
		else:
			close_tutorial()
		return

	var step: Dictionary = _steps[target_idx]
	var node: Control = step.get("target_node") as Control

	# Nếu node mục tiêu chưa tồn tại hoặc không hiển thị, bỏ qua sang bước tiếp hoặc lùi
	if node == null or not is_instance_valid(node) or not node.is_visible_in_tree():
		if forward:
			_show_step(target_idx + 1, true)
		else:
			_show_step(target_idx - 1, false)
		return

	_current_step_idx = target_idx
	_current_target_node = node
	var padding: Vector2 = step.get("padding", Vector2(8, 8))
	var global_r := node.get_global_rect()
	var dest_rect := Rect2(global_r.position - padding, global_r.size + padding * 2.0)

	_is_spotlight_active = true
	_callout_box.visible = true
	_pointer_arrow.visible = true

	# Update nội dung Callout Box
	_step_label.text = "%s %d/%d" % [tr("Bước"), _current_step_idx + 1, _steps.size()]
	_title_label.text = tr(step.get("title", "HƯỚNG DẪN"))
	_what_label.text = tr(step.get("what_is_it", ""))
	_todo_label.text = tr(step.get("what_to_do", ""))
	_where_label.text = tr(step.get("where_to_go", ""))

	if _mode == Mode.INITIAL:
		# Dạng đầu game: Bắt buộc, không cho click ra ngoài hay bấm nút đóng
		_btn_close_step.visible = false
		_nav_control_box.visible = false
		_hint_footer.text = tr("👉 Bắt buộc nhấp vào vùng sáng để trải nghiệm!")
	else:
		# Dạng 2: Khám phá giao diện, cho phép chuyển bước và đóng bất cứ lúc nào
		_btn_close_step.visible = true
		_btn_close_step.text = tr("✕ Đóng")
		_nav_control_box.visible = true
		_btn_prev_step.disabled = (_current_step_idx <= 0)
		_btn_next_step.text = tr("✔ Hoàn tất") if (_current_step_idx >= _steps.size() - 1) else tr("Tiếp theo ▶")
		_hint_footer.text = tr("💡 Nhấp [Tiếp theo] để xem tiếp hoặc [✕ Đóng] để thoát bất cứ lúc nào.")

	_callout_box.reset_size()

	# Animate rect chuyển động mượt từ bước trước sang bước mới
	if _target_rect.size == Vector2.ZERO:
		_target_rect = dest_rect
		_target_dest_rect = dest_rect
		_callout_box.position = Vector2(100, 100)
		_reposition_callout.call_deferred()
	else:
		_target_dest_rect = dest_rect
		if _rect_tween and _rect_tween.is_valid():
			_rect_tween.kill()
		_rect_tween = create_tween().set_parallel(true)
		_rect_tween.tween_property(self, "_target_rect:position", dest_rect.position, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_rect_tween.tween_property(self, "_target_rect:size", dest_rect.size, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_rect_tween.tween_callback(_reposition_callout)

	_callout_box.modulate.a = 0.0
	_callout_box.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_callout_box, "modulate:a", 1.0, 0.2)
	tween.tween_property(_callout_box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reposition_callout() -> void:
	if not is_inside_tree():
		return
	var vp_size := _dim_control.get_viewport_rect().size
	_callout_box.reset_size()
	var box_size := _callout_box.size
	if box_size.y < 180.0:
		box_size.y = 250.0
	if box_size.x < 320.0:
		box_size.x = 380.0

	var target := _target_dest_rect
	var pos := Vector2.ZERO

	var space_left := target.position.x
	var space_right := vp_size.x - target.end.x
	var space_bottom := vp_size.y - target.end.y

	if space_left >= box_size.x + 28.0 and space_left >= space_right:
		# Đặt bên TRÁI vùng sáng
		pos.x = target.position.x - box_size.x - 24.0
		pos.y = target.position.y + (target.size.y - box_size.y) * 0.5
		_arrow_label.text = "➔"
		_arrow_direction = Vector2.RIGHT
		_arrow_base_pos = Vector2(target.position.x - 18.0, clampf(target.position.y + target.size.y * 0.5, pos.y + 20.0, pos.y + box_size.y - 20.0))
	elif space_right >= box_size.x + 28.0:
		# Đặt bên PHẢI vùng sáng
		pos.x = target.end.x + 24.0
		pos.y = target.position.y + (target.size.y - box_size.y) * 0.5
		_arrow_label.text = "⬅"
		_arrow_direction = Vector2.LEFT
		_arrow_base_pos = Vector2(target.end.x + 18.0, clampf(target.position.y + target.size.y * 0.5, pos.y + 20.0, pos.y + box_size.y - 20.0))
	elif space_bottom >= box_size.y + 24.0:
		# Đặt ở PHÍA DƯỚI vùng sáng
		pos.x = target.position.x + (target.size.x - box_size.x) * 0.5
		pos.y = target.end.y + 20.0
		_arrow_label.text = "⬆"
		_arrow_direction = Vector2.UP
		_arrow_base_pos = Vector2(target.position.x + target.size.x * 0.5, target.end.y + 16.0)
	else:
		# Đặt ở PHÍA TRÊN vùng sáng
		pos.x = target.position.x + (target.size.x - box_size.x) * 0.5
		pos.y = target.position.y - box_size.y - 20.0
		_arrow_label.text = "⬇"
		_arrow_direction = Vector2.DOWN
		_arrow_base_pos = Vector2(target.position.x + target.size.x * 0.5, target.position.y - 16.0)

	# Giới hạn an toàn trong viewport
	pos.x = clampf(pos.x, 16.0, vp_size.x - box_size.x - 16.0)
	pos.y = clampf(pos.y, 20.0, vp_size.y - box_size.y - 20.0)

	_callout_box.global_position = pos
	_pointer_arrow.global_position = _arrow_base_pos

func _show_completion() -> void:
	_is_spotlight_active = false
	_callout_box.visible = false
	_pointer_arrow.visible = false
	_completion_dialog.visible = true
	_dim_control.queue_redraw()

	_completion_dialog.modulate.a = 0.0
	_completion_dialog.scale = Vector2(0.9, 0.9)
	_completion_dialog.pivot_offset = _completion_dialog.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_completion_dialog, "modulate:a", 1.0, 0.25)
	tween.tween_property(_completion_dialog, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_pulse_time += delta
	_pulse_alpha = 0.65 + 0.35 * sin(_pulse_time * 4.5)
	_pulse_ring = fmod(_pulse_time * 18.0, 16.0)

	if _pointer_arrow.visible:
		var bounce := sin(_pulse_time * 6.0) * 5.0
		_pointer_arrow.global_position = _arrow_base_pos + _arrow_direction * bounce

	# Cập nhật toạ độ target nếu node thay đổi vị trí
	if _is_spotlight_active and is_instance_valid(_current_target_node) and _current_target_node.is_visible_in_tree():
		var padding: Vector2 = _steps[_current_step_idx].get("padding", Vector2(8, 8))
		var gr := _current_target_node.get_global_rect()
		var new_dest := Rect2(gr.position - padding, gr.size + padding * 2.0)
		if new_dest != _target_dest_rect:
			_target_dest_rect = new_dest
			if _rect_tween == null or not _rect_tween.is_valid():
				_target_rect = new_dest
				_reposition_callout()

	_dim_control.queue_redraw()

func _on_dim_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	if not _is_spotlight_active:
		return

	var click_pos: Vector2 = event.position

	# KIỂM TRA CLICK VÀO VÙNG SÁNG (TARGET RECT)
	if _target_rect.has_point(click_pos):
		_handle_target_click()
	else:
		_handle_outside_click()

	_dim_control.get_viewport().set_input_as_handled()

func _handle_target_click() -> void:
	if _mode == Mode.INITIAL:
		# Bắt buộc chọn để trải nghiệm: trigger sự kiện của target node bên dưới
		if is_instance_valid(_current_target_node):
			if _current_target_node is BaseButton:
				var btn := _current_target_node as BaseButton
				if not btn.disabled:
					btn.pressed.emit()
			elif _current_target_node.has_signal("pressed"):
				_current_target_node.emit_signal("pressed")
			elif _current_target_node.has_method("_on_pressed"):
				_current_target_node.call("_on_pressed")

		# Chuyển bước tiếp theo
		_show_step(_current_step_idx + 1, true)
	else:
		# Dạng 2: Click vào vùng sáng cũng chuyển tiếp
		if _current_step_idx >= _steps.size() - 1:
			close_tutorial()
		else:
			_show_step(_current_step_idx + 1, true)

func _handle_outside_click() -> void:
	if _mode == Mode.EXPLORE:
		# Dạng 2: Cho phép tắt bất cứ lúc nào khi nhấp ra ngoài
		close_tutorial()
		return

	# Dạng 1: Không cho người dùng nhấp ra ngoài, rung nhẹ nhắc nhở
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var original_pos := _callout_box.position
	_shake_tween = create_tween()
	_shake_tween.tween_property(_callout_box, "position:x", original_pos.x + 6.0, 0.04)
	_shake_tween.tween_property(_callout_box, "position:x", original_pos.x - 6.0, 0.04)
	_shake_tween.tween_property(_callout_box, "position:x", original_pos.x + 4.0, 0.04)
	_shake_tween.tween_property(_callout_box, "position:x", original_pos.x, 0.04)

	# Nhấp nháy màu đỏ cảnh báo ở dòng hint
	var hint_tween := create_tween()
	hint_tween.tween_property(_hint_footer, "theme_override_colors/font_color", Color(1.0, 0.35, 0.3), 0.1)
	hint_tween.tween_property(_hint_footer, "theme_override_colors/font_color", COLOR_GOLD_BRIGHT, 0.3)

func _on_prev_step_pressed() -> void:
	if _current_step_idx > 0:
		_show_step(_current_step_idx - 1, false)

func _on_next_step_pressed() -> void:
	if _current_step_idx >= _steps.size() - 1:
		close_tutorial()
	else:
		_show_step(_current_step_idx + 1, true)

func _on_close_clicked() -> void:
	close_tutorial()

func close_tutorial() -> void:
	TutorialManager.set_completed(true)
	var tween := create_tween()
	tween.tween_property(self, "offset:y", -24.0, 0.18)
	tween.parallel().tween_property(_dim_control, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func() -> void:
		queue_free()
	)

func _on_dim_draw() -> void:
	var vp_size := _dim_control.get_viewport_rect().size

	if not _is_spotlight_active:
		# Vẽ nền mờ toàn màn hình khi ở Dialog
		_dim_control.draw_rect(Rect2(Vector2.ZERO, vp_size), COLOR_DIM)
		return

	# VÙNG YÊU CẦU NHẤP SÁNG LÊN, VÙNG KHÔNG CHO NHẤP TỐI MÀU LẠI
	var rx := _target_rect.position.x
	var ry := _target_rect.position.y
	var rw := _target_rect.size.x
	var rh := _target_rect.size.y

	# Top
	if ry > 0:
		_dim_control.draw_rect(Rect2(0, 0, vp_size.x, ry), COLOR_DIM)
	# Bottom
	if ry + rh < vp_size.y:
		_dim_control.draw_rect(Rect2(0, ry + rh, vp_size.x, vp_size.y - (ry + rh)), COLOR_DIM)
	# Left
	if rx > 0:
		_dim_control.draw_rect(Rect2(0, ry, rx, rh), COLOR_DIM)
	# Right
	if rx + rw < vp_size.x:
		_dim_control.draw_rect(Rect2(rx + rw, ry, vp_size.x - (rx + rw), rh), COLOR_DIM)

	# VÙNG SÁNG: Vẽ viền vàng phát sáng nhịp nhàng (Pulsing Glow)
	var border_color := Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, _pulse_alpha)
	_dim_control.draw_rect(_target_rect, border_color, false, 2.5)

	# Vòng sóng xung lực tỏa rộng mờ dần
	var ring_rect := _target_rect.grow(_pulse_ring)
	var ring_alpha := (1.0 - _pulse_ring / 16.0) * 0.45
	_dim_control.draw_rect(ring_rect, Color(COLOR_GOLD_BRIGHT.r, COLOR_GOLD_BRIGHT.g, COLOR_GOLD_BRIGHT.b, ring_alpha), false, 1.5)

	# 4 Góc Hoa Văn Kiếm Hiệp (Wuxia Corner Brackets) sắc nét
	var corner_len := 14.0
	var corner_col := COLOR_GOLD_BRIGHT
	var cw := 3.5

	# Top-Left
	_dim_control.draw_line(Vector2(rx, ry), Vector2(rx + corner_len, ry), corner_col, cw)
	_dim_control.draw_line(Vector2(rx, ry), Vector2(rx, ry + corner_len), corner_col, cw)
	# Top-Right
	_dim_control.draw_line(Vector2(rx + rw, ry), Vector2(rx + rw - corner_len, ry), corner_col, cw)
	_dim_control.draw_line(Vector2(rx + rw, ry), Vector2(rx + rw, ry + corner_len), corner_col, cw)
	# Bottom-Left
	_dim_control.draw_line(Vector2(rx, ry + rh), Vector2(rx + corner_len, ry + rh), corner_col, cw)
	_dim_control.draw_line(Vector2(rx, ry + rh), Vector2(rx, ry + rh - corner_len), corner_col, cw)
	# Bottom-Right
	_dim_control.draw_line(Vector2(rx + rw, ry + rh), Vector2(rx + rw - corner_len, ry + rh), corner_col, cw)
	_dim_control.draw_line(Vector2(rx + rw, ry + rh), Vector2(rx + rw, ry + rh - corner_len), corner_col, cw)

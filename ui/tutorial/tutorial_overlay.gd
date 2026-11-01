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
const COLOR_DIM := Color(0.012, 0.016, 0.02, 0.86) # Tối sẫm màu để làm nổi bật vùng sáng

@onready var _dim_control: Control = %DimControl
@onready var _welcome_dialog: PanelContainer = %WelcomeDialog
@onready var _btn_start_intro: Button = %BtnStartIntro
@onready var _btn_skip_intro: Button = %BtnSkipIntro
@onready var _callout_box: PanelContainer = %CalloutBox
@onready var _step_label: Label = %StepLabel
@onready var _title_label: Label = %TitleLabel
@onready var _desc_label: Label = %DescLabel
@onready var _btn_close_step: Button = %BtnCloseStep
@onready var _diamond_indicators: RichTextLabel = %DiamondIndicators
@onready var _hint_footer: Label = %HintFooter
@onready var _nav_control_box: HBoxContainer = %NavControlBox
@onready var _btn_prev_step: Button = %BtnPrevStep
@onready var _btn_next_step: Button = %BtnNextStep
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
var _current_target_nodes: Array[Control] = []
var _target_sub_rects: Array[Rect2] = []
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
	_btn_close_step.draw.connect(_on_skip_step_draw)
	_btn_close_step.mouse_entered.connect(func() -> void: _btn_close_step.queue_redraw())
	_btn_close_step.mouse_exited.connect(func() -> void: _btn_close_step.queue_redraw())
	_btn_finish.pressed.connect(_on_finish_pressed)

	_btn_prev_step.pressed.connect(_on_prev_step_pressed)
	_btn_next_step.pressed.connect(_on_next_step_pressed)

	_dim_control.gui_input.connect(_on_dim_gui_input)
	_dim_control.draw.connect(_on_dim_draw)

	_btn_prev_step.text = tr("Trước")
	_btn_next_step.text = tr("Tiếp")
	_btn_close_step.text = tr("Bỏ qua hướng dẫn")
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

	if not is_node_ready():
		await ready

	if _welcome_dialog:
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

func advance_to_skill_select_step() -> void:
	for i in range(_steps.size()):
		if _steps[i].get("id") == "auto_select_skill":
			_show_step(i, true)
			break

func advance_to_toggle_auto_step() -> void:
	for i in range(_steps.size()):
		if _steps[i].get("id") == "auto_toggle_btn":
			_show_step(i, true)
			break

func _start_steps() -> void:
	_current_step_idx = -1
	_welcome_dialog.visible = false
	_show_step(0, true)

func _show_step(target_idx: int, forward: bool = true) -> void:
	if target_idx < 0:
		return
	if target_idx >= _steps.size():
		if _mode == Mode.INITIAL:
			var tm = get_node_or_null("/root/TutorialManager")
			if tm and tm.has_method("is_in_intro_flow") and tm.is_in_intro_flow():
				queue_free()
				return
			_show_completion()
		else:
			close_tutorial()
		return

	var step: Dictionary = _steps[target_idx]
	_current_step_idx = target_idx

	# Kiểm tra rect_getter trước (dành cho PopupMenu hoặc vùng tuỳ chỉnh)
	if step.has("rect_getter"):
		var rg: Callable = step.get("rect_getter")
		if rg.is_valid():
			var r := Rect2()
			for attempt in range(15):
				if not is_inside_tree():
					return
				r = rg.call()
				if r.size.x > 0 and r.size.y > 0:
					break
				await get_tree().create_timer(0.08).timeout
				if not is_inside_tree():
					return
			if r.size.x > 0 and r.size.y > 0:
				_current_step_idx = target_idx
				_current_target_nodes.clear()
				_current_target_node = null
				var padding: Vector2 = step.get("padding", Vector2(4, 4))
				var dest_rect := Rect2(r.position - padding, r.size + padding * 2.0)
				_target_sub_rects = [dest_rect]
				_setup_callout_and_rect(step, dest_rect)
				return

	var target_nodes: Array[Control] = []

	# Thử lấy multi_target_getter trước nếu có
	if step.has("multi_target_getter"):
		var multi_getter: Callable = step.get("multi_target_getter")
		if multi_getter.is_valid():
			for attempt in range(10):
				if not is_inside_tree():
					return
				var nodes = multi_getter.call()
				if nodes is Array and not nodes.is_empty():
					for n in nodes:
						if n is Control and is_instance_valid(n) and n.is_visible_in_tree():
							target_nodes.append(n)
					if not target_nodes.is_empty():
						break
				await get_tree().create_timer(0.08).timeout
				if not is_inside_tree():
					return

	# Nếu không có multi_target hoặc multi_target rỗng, thử target_node / target_getter
	if target_nodes.is_empty():
		var node: Control = step.get("target_node") as Control
		if (node == null or not is_instance_valid(node) or not node.is_visible_in_tree()) and step.has("target_getter"):
			var getter: Callable = step.get("target_getter")
			if getter.is_valid():
				for attempt in range(10):
					if not is_inside_tree():
						return
					node = getter.call() as Control
					if node != null and is_instance_valid(node) and node.is_visible_in_tree():
						break
					await get_tree().create_timer(0.08).timeout
					if not is_inside_tree():
						return
		if node != null and is_instance_valid(node) and node.is_visible_in_tree():
			target_nodes.append(node)

	# Nếu vẫn không có node mục tiêu nào hiển thị, chỉ bỏ qua nếu không phải bước bắt buộc
	if target_nodes.is_empty():
		if step.get("id") == "auto_select_skill" or _mode == Mode.INITIAL:
			return
		if forward:
			_show_step(target_idx + 1, true)
		else:
			_show_step(target_idx - 1, false)
		return

	# Đảm bảo node đầu tiên đã được engine tính toán layout xong (không còn ở toạ độ mặc định 0,0)
	if target_nodes[0].get_global_position() == Vector2.ZERO and is_inside_tree():
		await get_tree().process_frame
		if not is_instance_valid(target_nodes[0]) or not target_nodes[0].is_visible_in_tree():
			return

	_current_step_idx = target_idx
	_current_target_nodes = target_nodes
	_current_target_node = target_nodes[0]
	var padding: Vector2 = step.get("padding", Vector2(8, 8))

	_target_sub_rects.clear()
	var merged_rect := Rect2()
	var has_merged := false
	for tn in _current_target_nodes:
		var gr := tn.get_global_rect()
		var sub_r := Rect2(gr.position - padding, gr.size + padding * 2.0)
		_target_sub_rects.append(sub_r)
		if not has_merged:
			merged_rect = sub_r
			has_merged = true
		else:
			merged_rect = merged_rect.merge(sub_r)

	_setup_callout_and_rect(step, merged_rect)

func _setup_callout_and_rect(step: Dictionary, dest_rect: Rect2) -> void:
	_is_spotlight_active = true
	_callout_box.visible = true
	_pointer_arrow.visible = true

	# Update nội dung Callout Box
	var step_num: int = int(step.get("step_index", _current_step_idx + 1))
	var total_num: int = int(step.get("total_steps", _steps.size()))
	_step_label.text = "%s · %d/%d" % [tr("HƯỚNG DẪN"), step_num, total_num]
	_title_label.text = tr(step.get("title", ""))

	var desc: String = step.get("description", "")
	if desc.is_empty():
		desc = step.get("what_is_it", "")
		var todo: String = step.get("what_to_do", "")
		if not todo.is_empty():
			desc += " " + todo
	_desc_label.text = tr(desc)

	_update_diamond_indicators()

	if _mode == Mode.INITIAL:
		# Dạng đầu game: Bắt buộc nhấp vào vùng sáng, không hiển thị nút bỏ qua
		_btn_close_step.visible = false
		_nav_control_box.visible = false
		_hint_footer.visible = true
		_hint_footer.text = tr("Làm theo để đi tiếp")
	else:
		# Dạng 2: Khám phá giao diện, cho phép chuyển bước hoặc bỏ qua bất cứ lúc nào
		_btn_close_step.visible = true
		_btn_close_step.text = tr("Bỏ qua hướng dẫn")
		_nav_control_box.visible = true
		_hint_footer.visible = false
		_btn_prev_step.disabled = (_current_step_idx <= 0)
		_btn_next_step.text = tr("Xong") if (_current_step_idx >= _steps.size() - 1) else tr("Tiếp")

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

func _update_diamond_indicators() -> void:
	if not is_instance_valid(_diamond_indicators):
		return
	var step: Dictionary = _steps[_current_step_idx] if _current_step_idx >= 0 and _current_step_idx < _steps.size() else {}
	var step_num: int = int(step.get("step_index", _current_step_idx + 1))
	var total: int = int(step.get("total_steps", _steps.size()))
	if total <= 1:
		_diamond_indicators.text = ""
		return
	var s := ""
	for i in range(total):
		if i > 0:
			s += " "
		if i + 1 == step_num:
			s += "[color=#e8b958]◆[/color]"
		else:
			s += "[color=#624933]◇[/color]"
	_diamond_indicators.text = s

func _on_skip_step_draw() -> void:
	if not is_instance_valid(_btn_close_step) or not _btn_close_step.is_visible_in_tree():
		return
	var font := _btn_close_step.get_theme_font("font")
	var font_size := _btn_close_step.get_theme_font_size("font_size")
	if font == null:
		font = ThemeDB.fallback_font
	var text_w := font.get_string_size(_btn_close_step.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var y := _btn_close_step.size.y - 1.0
	var x2 := _btn_close_step.size.x
	var x1 := maxf(0.0, x2 - text_w)
	var col := Color(1.0, 0.95, 0.88, 0.95) if _btn_close_step.is_hovered() else Color(0.85, 0.8, 0.7, 0.8)
	_btn_close_step.draw_line(Vector2(x1, y), Vector2(x2, y), col, 1.0)

func _reposition_callout() -> void:
	if not is_inside_tree():
		return
	var vp_size := _dim_control.get_viewport_rect().size
	_callout_box.reset_size()
	var box_size := _callout_box.size
	if box_size.x < 360.0:
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

	if is_instance_valid(_pointer_arrow) and _pointer_arrow.visible:
		var bounce := sin(_pulse_time * 6.0) * 5.0
		_pointer_arrow.global_position = _arrow_base_pos + _arrow_direction * bounce

	# Cập nhật toạ độ target nếu node thay đổi vị trí
	if _is_spotlight_active and _current_step_idx >= 0 and _current_step_idx < _steps.size():
		var current_step: Dictionary = _steps[_current_step_idx]
		if current_step.has("rect_getter"):
			var rg: Callable = current_step.get("rect_getter")
			if rg.is_valid():
				var nr: Rect2 = rg.call()
				if nr.size.x > 0 and nr.size.y > 0:
					var padding: Vector2 = current_step.get("padding", Vector2(4, 4))
					var new_dest := Rect2(nr.position - padding, nr.size + padding * 2.0)
					if new_dest != _target_dest_rect:
						_target_dest_rect = new_dest
						_target_rect = new_dest
						_target_sub_rects = [new_dest]
						_reposition_callout()
		elif not _current_target_nodes.is_empty():
			var padding: Vector2 = current_step.get("padding", Vector2(8, 8))
			var new_subs: Array[Rect2] = []
			var merged := Rect2()
			var has_m := false
			for tn in _current_target_nodes:
				if is_instance_valid(tn) and tn.is_visible_in_tree():
					var gr := tn.get_global_rect()
					var sub_r := Rect2(gr.position - padding, gr.size + padding * 2.0)
					new_subs.append(sub_r)
					if not has_m:
						merged = sub_r
						has_m = true
					else:
						merged = merged.merge(sub_r)
			if not new_subs.is_empty():
				_target_sub_rects = new_subs
				if merged != _target_dest_rect:
					if _rect_tween and _rect_tween.is_valid():
						_rect_tween.kill()
					_target_dest_rect = merged
					_target_rect = merged
					_reposition_callout()

	_dim_control.queue_redraw()

func _on_dim_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	if not _is_spotlight_active:
		return

	var click_pos: Vector2 = event.position

	# KIỂM TRA CLICK VÀO VÙNG SÁNG (TARGET RECT HOẶC SUB-RECTS)
	var hit := false
	if _target_sub_rects.size() > 1:
		for sub_r in _target_sub_rects:
			if sub_r.has_point(click_pos):
				hit = true
				break
	elif _target_rect.has_point(click_pos):
		hit = true

	if hit:
		_handle_target_click(click_pos)
	else:
		_handle_outside_click()

	_dim_control.get_viewport().set_input_as_handled()

func _handle_target_click(click_pos: Vector2 = Vector2.ZERO) -> void:
	var old_step_idx := _current_step_idx
	if _current_step_idx >= 0 and _current_step_idx < _steps.size() and _steps[_current_step_idx].has("on_click"):
		var oc: Callable = _steps[_current_step_idx].get("on_click")
		if oc.is_valid():
			oc.call(click_pos)
		# Chỉ tự động chuyển bước nếu trong callback chưa tự chuyển bước
		if _current_step_idx == old_step_idx:
			_show_step(_current_step_idx + 1, true)
		return

	var target_to_activate: Control = _current_target_node
	if not _current_target_nodes.is_empty():
		for i in range(_current_target_nodes.size()):
			if i < _target_sub_rects.size() and _target_sub_rects[i].has_point(click_pos):
				target_to_activate = _current_target_nodes[i]
				break

	if _mode == Mode.INITIAL:
		# Bắt buộc chọn để trải nghiệm: trigger sự kiện của target node bên dưới
		if is_instance_valid(target_to_activate):
			if target_to_activate is BaseButton:
				var btn := target_to_activate as BaseButton
				if not btn.disabled:
					btn.pressed.emit()
			elif target_to_activate.has_signal("pressed"):
				target_to_activate.emit_signal("pressed")
			elif target_to_activate.has_method("_on_pressed"):
				target_to_activate.call("_on_pressed")

		# Chỉ chuyển bước tiếp theo nếu callback bên dưới chưa tự chuyển bước!
		if _current_step_idx == old_step_idx:
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
	if is_instance_valid(_hint_footer) and _hint_footer.visible:
		var hint_tween := create_tween()
		hint_tween.tween_property(_hint_footer, "theme_override_colors/font_color", Color(1.0, 0.4, 0.35), 0.1)
		hint_tween.tween_property(_hint_footer, "theme_override_colors/font_color", Color(0.85, 0.72, 0.50), 0.3)

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
	var tm = get_node_or_null("/root/TutorialManager")
	if tm:
		if tm.has_method("cancel_intro_flow"):
			tm.cancel_intro_flow()
		if tm.has_method("set_completed"):
			tm.set_completed(true)
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

	var border_color := Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, _pulse_alpha)
	var corner_col := COLOR_GOLD_BRIGHT

	if _target_sub_rects.size() > 1:
		# LÀM SÁNG TỪNG Ô RIÊNG BIỆT: Vẽ viền vàng + góc hoa văn kiếm hiệp cho từng ô con!
		for sub_r in _target_sub_rects:
			var s_rx := sub_r.position.x
			var s_ry := sub_r.position.y
			var s_rw := sub_r.size.x
			var s_rh := sub_r.size.y

			# Viền phát sáng từng ô
			_dim_control.draw_rect(sub_r, border_color, false, 2.0)

			# Vòng sóng xung lực mờ dần cho từng ô
			var ring_rect := sub_r.grow(_pulse_ring * 0.5)
			var ring_alpha := (1.0 - _pulse_ring / 16.0) * 0.4
			_dim_control.draw_rect(ring_rect, Color(COLOR_GOLD_BRIGHT.r, COLOR_GOLD_BRIGHT.g, COLOR_GOLD_BRIGHT.b, ring_alpha), false, 1.2)

			# 4 Góc hoa văn kiếm hiệp cho từng ô con
			var clen := 8.0
			var cw := 2.5
			# Top-Left
			_dim_control.draw_line(Vector2(s_rx, s_ry), Vector2(s_rx + clen, s_ry), corner_col, cw)
			_dim_control.draw_line(Vector2(s_rx, s_ry), Vector2(s_rx, s_ry + clen), corner_col, cw)
			# Top-Right
			_dim_control.draw_line(Vector2(s_rx + s_rw, s_ry), Vector2(s_rx + s_rw - clen, s_ry), corner_col, cw)
			_dim_control.draw_line(Vector2(s_rx + s_rw, s_ry), Vector2(s_rx + s_rw, s_ry + clen), corner_col, cw)
			# Bottom-Left
			_dim_control.draw_line(Vector2(s_rx, s_ry + s_rh), Vector2(s_rx + clen, s_ry + s_rh), corner_col, cw)
			_dim_control.draw_line(Vector2(s_rx, s_ry + s_rh), Vector2(s_rx, s_ry + s_rh - clen), corner_col, cw)
			# Bottom-Right
			_dim_control.draw_line(Vector2(s_rx + s_rw, s_ry + s_rh), Vector2(s_rx + s_rw - clen, s_ry + s_rh), corner_col, cw)
			_dim_control.draw_line(Vector2(s_rx + s_rw, s_ry + s_rh), Vector2(s_rx + s_rw, s_ry + s_rh - clen), corner_col, cw)
	else:
		# VÙNG SÁNG: Vẽ viền vàng phát sáng nhịp nhàng (Pulsing Glow)
		_dim_control.draw_rect(_target_rect, border_color, false, 2.5)

		# Vòng sóng xung lực tỏa rộng mờ dần
		var ring_rect := _target_rect.grow(_pulse_ring)
		var ring_alpha := (1.0 - _pulse_ring / 16.0) * 0.45
		_dim_control.draw_rect(ring_rect, Color(COLOR_GOLD_BRIGHT.r, COLOR_GOLD_BRIGHT.g, COLOR_GOLD_BRIGHT.b, ring_alpha), false, 1.5)

		# 4 Góc Hoa Văn Kiếm Hiệp (Wuxia Corner Brackets) sắc nét
		var corner_len := 14.0
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

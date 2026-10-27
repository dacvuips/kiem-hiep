class_name TouchScrollHelper
extends Node
## Bộ hỗ trợ kéo cuộn (Drag-to-Scroll & Touch Scroll) cho ScrollContainer trên cả Mobile (chạm/vuốt)
## và PC (chuột trái kéo).
##
## Tính năng:
## - Cho phép chạm / nhấp giữ bất kỳ vị trí nào trong danh sách (kể cả trên nút, ô vật phẩm, nhãn)
##   hoặc trong vùng `body_control` (body của khung) để cuộn danh sách lên / xuống.
## - Nhấp nhẹ (tap < DRAG_THRESHOLD px) vẫn kích hoạt click nút con bình thường.
## - Kéo vuốt (> DRAG_THRESHOLD px) sẽ cuộn mượt và chặn click nhầm vào nút con khi thả tay.
## - Hỗ trợ lực quán tính (kinetic fling inertia) lướt êm ái khi thả tay vuốt nhanh.
## - Không xung đột với con lăn chuột (mouse wheel) và kéo thanh cuộn trực tiếp.

const DRAG_THRESHOLD := 8.0
const FRICTION := 8.0
const MAX_VELOCITY := 3000.0

var scroll_container: ScrollContainer
var body_control: Control

var _is_touching: bool = false
var _is_dragging: bool = false
var _touch_index: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _start_scroll_v: int = 0
var _start_scroll_h: int = 0
var _velocity_v: float = 0.0
var _velocity_h: float = 0.0
var _last_time_msec: int = 0

static func attach(scroll: ScrollContainer, body: Control = null) -> Node:
	if scroll == null or not is_instance_valid(scroll):
		return null
	for child in scroll.get_children():
		if child.has_meta("touch_scroll_helper"):
			if body != null:
				child.set("body_control", body)
			return child
	var script: GDScript = load("res://ui/common/touch_scroll_helper.gd")
	var helper: Node = script.new()
	helper.name = "TouchScrollHelper"
	helper.set_meta("touch_scroll_helper", true)
	helper.set("scroll_container", scroll)
	helper.set("body_control", body if body != null else scroll)
	scroll.add_child(helper)
	return helper

func _ready() -> void:
	process_priority = -100

func _exit_tree() -> void:
	_is_touching = false
	_is_dragging = false
	_velocity_v = 0.0
	_velocity_h = 0.0

func can_scroll_v() -> bool:
	if scroll_container == null or not is_instance_valid(scroll_container):
		return false
	if scroll_container.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false

	var total_ch: float = 0.0
	for c in scroll_container.get_children():
		if c is Control and not (c is VScrollBar or c is HScrollBar):
			var ch: float = (c as Control).size.y
			if ch <= 0.0:
				ch = (c as Control).get_combined_minimum_size().y
			total_ch = maxf(total_ch, ch)
	var sc_height := scroll_container.size.y
	if sc_height <= 0.0:
		sc_height = scroll_container.get_combined_minimum_size().y
	if total_ch > 0.0 and sc_height > 0.0:
		return total_ch > sc_height

	var v_bar := scroll_container.get_v_scroll_bar()
	if v_bar != null and v_bar.max_value > 0.0 and v_bar.page > 0.0:
		return v_bar.max_value > v_bar.page
	return true

func can_scroll_h() -> bool:
	if scroll_container == null or not is_instance_valid(scroll_container):
		return false
	if scroll_container.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var h_bar := scroll_container.get_h_scroll_bar()
	if h_bar != null and h_bar.max_value > 0.0 and h_bar.page > 0.0:
		return h_bar.max_value > h_bar.page
	for c in scroll_container.get_children():
		if c is Control and not (c is VScrollBar or c is HScrollBar):
			var cw: float = (c as Control).size.x
			if cw <= 0.0:
				cw = (c as Control).get_combined_minimum_size().x
			if cw > 0.0 and scroll_container.size.x > 0.0:
				return cw > scroll_container.size.x
	return true

func _is_draggable_at(_pos: Vector2) -> bool:
	if scroll_container == null or not is_instance_valid(scroll_container):
		return false
	var vp := scroll_container.get_viewport()
	if vp == null:
		return false
	var ctrl := vp.gui_get_hovered_control()
	var p: Node = ctrl
	var limit: Node = scroll_container.get_parent()
	while p != null and p != limit:
		if p is Control:
			if p.has_meta("draggable") or p.has_meta("drag_data"):
				return true
			if p is ItemSlotButton:
				return true
			if p.has_method("_get_drag_data"):
				return true
		p = p.get_parent()
	return false

func _is_covered_by_higher_layer(pos: Vector2) -> bool:
	if scroll_container == null or not is_instance_valid(scroll_container):
		return false
	var my_cl: CanvasLayer = null
	var parent_node := scroll_container.get_parent()
	while parent_node != null:
		if parent_node is CanvasLayer:
			my_cl = parent_node as CanvasLayer
			break
		parent_node = parent_node.get_parent()
	var my_layer: int = my_cl.layer if my_cl != null else 0

	var tree := scroll_container.get_tree()
	if tree == null:
		return false
	var check_nodes := tree.get_nodes_in_group(DraggableWindow.GROUP) + tree.get_nodes_in_group(UiPopups.GROUP)
	for n in check_nodes:
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		var cl := n.get_parent() as CanvasLayer if n is Control else (n as CanvasLayer)
		if cl == null or not cl.visible or cl == my_cl:
			continue
		if cl.layer > my_layer:
			var ctrl := n as Control if n is Control else (n.get_child(0) as Control if n.get_child_count() > 0 and n.get_child(0) is Control else null)
			if ctrl != null and ctrl.visible and ctrl.is_visible_in_tree():
				var local_pos = ctrl.get_global_transform_with_canvas().affine_inverse() * pos
				if Rect2(Vector2.ZERO, ctrl.size).has_point(local_pos):
					return true
	return false

func _is_scroll_visible() -> bool:
	if scroll_container == null or not is_instance_valid(scroll_container):
		return false
	if not scroll_container.is_inside_tree() and scroll_container.get_parent() == null:
		return false
	var p: Node = scroll_container
	while p != null and p is CanvasItem:
		if not (p as CanvasItem).visible:
			return false
		p = p.get_parent()
	return true

func _input(event: InputEvent) -> void:
	if not _is_scroll_visible():
		if _is_touching:
			_is_touching = false
			_is_dragging = false
		return

	# Bỏ qua con lăn chuột để Godot cuộn mặc định
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return

	# Không can thiệp nếu đang kéo thả vật phẩm hệ thống Godot
	var vp := scroll_container.get_viewport()
	if vp != null and vp.gui_is_dragging():
		_is_touching = false
		_is_dragging = false
		_velocity_v = 0.0
		_velocity_h = 0.0
		return

	var is_press := false
	var is_release := false
	var pos := Vector2.ZERO
	var idx := -1

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
		is_release = not event.pressed
		pos = event.position
		idx = -1
	elif event is InputEventScreenTouch:
		is_press = event.pressed
		is_release = not event.pressed
		pos = event.position
		idx = event.index

	if is_press:
		if not can_scroll_v() and not can_scroll_h():
			return
		if _is_draggable_at(pos):
			return

		# Nếu bấm vào header_panel của cửa sổ thì để người dùng kéo cửa sổ
		if body_control != null and is_instance_valid(body_control):
			var hdr = body_control.get("header_panel")
			if hdr is Control and is_instance_valid(hdr) and (hdr as Control).visible:
				var local_hdr = (hdr as Control).get_global_transform_with_canvas().affine_inverse() * pos
				if Rect2(Vector2.ZERO, (hdr as Control).size).has_point(local_hdr):
					return

		# Kiểm tra xem chạm có nằm trong ScrollContainer hoặc Body của khung không
		var in_scroll := false
		if scroll_container != null and is_instance_valid(scroll_container):
			var local_pos = scroll_container.get_global_transform_with_canvas().affine_inverse() * pos
			in_scroll = Rect2(Vector2.ZERO, scroll_container.size).has_point(local_pos)

		var in_body := false
		if body_control != null and is_instance_valid(body_control):
			var body_visible = body_control.visible if DisplayServer.get_name() == "headless" else body_control.is_visible_in_tree()
			if body_visible:
				var local_body_pos = body_control.get_global_transform_with_canvas().affine_inverse() * pos
				in_body = Rect2(Vector2.ZERO, body_control.size).has_point(local_body_pos)

		if not in_scroll and not in_body:
			return

		# Nếu bấm trực tiếp vào thanh cuộn thì để thanh cuộn tự xử lý
		var v_bar := scroll_container.get_v_scroll_bar()
		if v_bar != null and v_bar.visible:
			var local_vbar = v_bar.get_global_transform_with_canvas().affine_inverse() * pos
			if Rect2(Vector2.ZERO, v_bar.size).has_point(local_vbar):
				return
		var h_bar := scroll_container.get_h_scroll_bar()
		if h_bar != null and h_bar.visible:
			var local_hbar = h_bar.get_global_transform_with_canvas().affine_inverse() * pos
			if Rect2(Vector2.ZERO, h_bar.size).has_point(local_hbar):
				return

		# Bỏ qua nếu bị che bởi CanvasLayer cao hơn (Popup, modal...)
		if _is_covered_by_higher_layer(pos):
			return

		_is_touching = true
		_is_dragging = false
		_touch_index = idx
		_start_pos = pos
		_last_pos = pos
		_start_scroll_v = scroll_container.scroll_vertical
		_start_scroll_h = scroll_container.scroll_horizontal
		_velocity_v = 0.0
		_velocity_h = 0.0
		_last_time_msec = Time.get_ticks_msec()
		return

	if is_release:
		if _is_touching and (_touch_index == -1 or idx == _touch_index):
			var now := Time.get_ticks_msec()
			var dt := (now - _last_time_msec) / 1000.0
			if dt > 0.08:
				_velocity_v = 0.0
				_velocity_h = 0.0
			else:
				_velocity_v = clampf(_velocity_v, -MAX_VELOCITY, MAX_VELOCITY)
				_velocity_h = clampf(_velocity_h, -MAX_VELOCITY, MAX_VELOCITY)

			if _is_dragging:
				# Đã kéo cuộn thì chặn sự kiện thả để không bấm nhầm vào nút con
				if vp != null:
					vp.set_input_as_handled()

			_is_touching = false
			_is_dragging = false
		return

	# Kéo di chuyển
	var is_motion := false
	if event is InputEventMouseMotion and _is_touching and _touch_index == -1:
		is_motion = true
		pos = event.position
	elif event is InputEventScreenDrag and _is_touching and event.index == _touch_index:
		is_motion = true
		pos = event.position

	if is_motion:
		var delta_total := pos - _start_pos
		var allow_v := can_scroll_v()
		var allow_h := can_scroll_h()

		if not _is_dragging:
			var dist_v := absf(delta_total.y) if allow_v else 0.0
			var dist_h := absf(delta_total.x) if allow_h else 0.0
			if dist_v >= DRAG_THRESHOLD or dist_h >= DRAG_THRESHOLD:
				_is_dragging = true
				if vp != null:
					vp.gui_release_focus()

		if _is_dragging:
			var now := Time.get_ticks_msec()
			var dt := maxf(0.001, (now - _last_time_msec) / 1000.0)
			var step_dy := pos.y - _last_pos.y
			var step_dx := pos.x - _last_pos.x

			var cur_vel_y := step_dy / dt
			var cur_vel_x := step_dx / dt
			_velocity_v = lerpf(_velocity_v, cur_vel_y, 0.4)
			_velocity_h = lerpf(_velocity_h, cur_vel_x, 0.4)
			_last_time_msec = now
			_last_pos = pos

			if allow_v:
				var target_val := int(round(_start_scroll_v - delta_total.y))
				scroll_container.scroll_vertical = target_val
			if allow_h:
				scroll_container.scroll_horizontal = int(round(_start_scroll_h - delta_total.x))

			if vp != null:
				vp.set_input_as_handled()

func _process(delta: float) -> void:
	if _is_touching:
		return
	if absf(_velocity_v) < 5.0 and absf(_velocity_h) < 5.0:
		_velocity_v = 0.0
		_velocity_h = 0.0
		return

	if not _is_scroll_visible():
		_velocity_v = 0.0
		_velocity_h = 0.0
		return

	if can_scroll_v() and absf(_velocity_v) >= 5.0:
		var old_v := scroll_container.scroll_vertical
		scroll_container.scroll_vertical -= int(round(_velocity_v * delta))
		if scroll_container.scroll_vertical == old_v:
			_velocity_v = 0.0
		else:
			_velocity_v = lerpf(_velocity_v, 0.0, FRICTION * delta)

	if can_scroll_h() and absf(_velocity_h) >= 5.0:
		var old_h := scroll_container.scroll_horizontal
		scroll_container.scroll_horizontal -= int(round(_velocity_h * delta))
		if scroll_container.scroll_horizontal == old_h:
			_velocity_h = 0.0
		else:
			_velocity_h = lerpf(_velocity_h, 0.0, FRICTION * delta)

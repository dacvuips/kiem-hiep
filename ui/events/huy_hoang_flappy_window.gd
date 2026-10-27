extends Control
class_name HuyHoangFlappyWindow
## MÀN CHƠI HÁI QUẢ HUY HOÀNG (PHONG CÁCH "FLAPPY FRUIT"):
##   - Điều khiển Quả Huy Hoàng bay lượn vượt qua các hàng cây cổ thụ.
##   - Ống cống được thay thế bằng các thân cây cổ thụ kiếm hiệp (có thân gỗ, cành lá, rễ cây).
##   - Mỗi lần vượt qua 1 cây được 1 điểm cơ bản, nhân với hệ số theo cấp độ quả (x1, x2, x3, x5).
##   - Điểm số quy đổi thành phần thưởng EXP, Ngân Lượng và Phúc Duyên bồi tăng hấp dẫn!

signal finished(score: int, fruit_tier: Dictionary)

const GRAVITY: float = 880.0
const FLAP_VELOCITY: float = -340.0
const SCROLL_SPEED: float = 145.0
const TREE_WIDTH: float = 68.0
const TREE_GAP: float = 145.0
const SPAWN_INTERVAL: float = 1.7
const TARGET_PIPES: int = 10 ## Mục tiêu vượt 10 Cổ Thụ = 100% hoàn thành màn chơi

enum State { READY, PLAYING, GAME_OVER }

var _profile: PlayerProfile
var _tier: Dictionary = {}
var _multiplier: int = 1
var _on_complete: Callable

var _state: State = State.READY
var _score: int = 0
var _raw_pipes_passed: int = 0

# Game board bounds inside modal
var _game_w: float = 420.0
var _game_h: float = 600.0

# Fruit state
var _fruit_pos: Vector2 = Vector2(90.0, 280.0)
var _fruit_vy: float = 0.0
var _fruit_rot: float = 0.0
var _fruit_scale: Vector2 = Vector2.ONE
var _fruit_radius: float = 18.0
var _fruit_tex: Texture2D

# Trees
var _trees: Array[Dictionary] = [] # [{x, gap_y, scored}]
var _spawn_timer: float = 0.0

# Floating scores
var _floating_labels: Array[Dictionary] = [] # [{pos, text, alpha, timer}]

# Visual nodes
var _board: Control
var _score_label: Label
var _mult_badge: Label
var _progress_bar: ProgressBar
var _progress_label: Label
var _hint_label: Label
var _game_over_panel: PanelContainer

static func launch(parent: Node, profile: PlayerProfile, tier: Dictionary, on_complete: Callable = Callable()) -> Node:
	var script: GDScript = load("res://ui/events/huy_hoang_flappy_window.gd")
	var win = script.new()
	win._profile = profile
	win._tier = tier
	win._multiplier = maxi(1, int(tier.get("multiplier", 1)))
	win._on_complete = on_complete
	var target: Node = parent
	if parent.get_parent() is CanvasLayer:
		target = parent.get_parent()
	target.add_child(win)
	return win

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Load texture của quả theo phẩm cấp
	var icon_path := str(_tier.get("icon", "res://assets/items/icons/huihuangzhiguo.png"))
	if ResourceLoader.exists(icon_path):
		_fruit_tex = load(icon_path)

	# Scrim mờ phía sau
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.03, 0.05, 0.85)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	# Khung bàn chơi ở giữa
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_board = Control.new()
	_board.custom_minimum_size = Vector2(_game_w, _game_h)
	_board.clip_contents = true
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_board.gui_input.connect(_on_board_input)
	_board.draw.connect(_draw_board_content)
	center.add_child(_board)

	# Border ngoài cho khung chơi
	var border_panel := Panel.new()
	border_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color.TRANSPARENT
	st.border_color = _tier.get("color", Color(1.0, 0.85, 0.25))
	st.set_border_width_all(3)
	st.set_corner_radius_all(10)
	border_panel.add_theme_stylebox_override("panel", st)
	_board.add_child(border_panel)

	# Top HUD
	_mult_badge = Label.new()
	_mult_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mult_badge.text = "%s  ·  Hệ số: x%d" % [str(_tier.get("name", "Quả Huy Hoàng")), _multiplier]
	_mult_badge.position = Vector2(16, 14)
	_mult_badge.add_theme_font_size_override("font_size", 13)
	_mult_badge.add_theme_color_override("font_color", _tier.get("color", Color.WHITE))
	_mult_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_mult_badge.add_theme_constant_override("outline_size", 3)
	_board.add_child(_mult_badge)

	# Điểm số lớn ở giữa đỉnh
	_score_label = Label.new()
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_label.text = "0"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.position = Vector2(0, 36)
	_score_label.custom_minimum_size = Vector2(_game_w, 36)
	_score_label.add_theme_font_size_override("font_size", 32)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_score_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_score_label.add_theme_constant_override("outline_size", 4)
	_board.add_child(_score_label)

	# Thanh tiến độ hoàn thành màn chơi
	_progress_bar = ProgressBar.new()
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.show_percentage = false
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.custom_minimum_size = Vector2(220, 8)
	_progress_bar.position = Vector2((_game_w - 220) * 0.5, 74)
	var bg_st := StyleBoxFlat.new()
	bg_st.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	bg_st.set_corner_radius_all(4)
	var fill_st := StyleBoxFlat.new()
	fill_st.bg_color = Color(0.25, 0.85, 0.4)
	fill_st.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("background", bg_st)
	_progress_bar.add_theme_stylebox_override("fill", fill_st)
	_board.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_label.text = "Tiến Độ: 0/%d Cổ Thụ (0%%)" % TARGET_PIPES
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.position = Vector2(0, 84)
	_progress_label.custom_minimum_size = Vector2(_game_w, 20)
	_progress_label.add_theme_font_size_override("font_size", 11)
	_progress_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_progress_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_progress_label.add_theme_constant_override("outline_size", 3)
	_board.add_child(_progress_label)

	# Nút thoát góc trên phải
	var close_btn := Button.new()
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.text = "✕"
	close_btn.position = Vector2(_game_w - 44, 10)
	close_btn.custom_minimum_size = Vector2(34, 34)
	close_btn.pressed.connect(_on_close_clicked)
	_board.add_child(close_btn)

	# Nhãn hướng dẫn khi sẵn sàng
	_hint_label = Label.new()
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.text = "👆 CHẠM HOẶC BẤM SPACE\nĐỂ HÁI QUẢ VƯỢT CÂY!"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position = Vector2(0, 360)
	_hint_label.custom_minimum_size = Vector2(_game_w, 60)
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color.WHITE)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_label.add_theme_constant_override("outline_size", 3)
	_board.add_child(_hint_label)

	# Game over panel (ẩn ban đầu)
	_build_game_over_panel()

	_reset_game()

func _reset_game() -> void:
	_state = State.READY
	_score = 0
	_raw_pipes_passed = 0
	_fruit_pos = Vector2(90.0, _game_h * 0.45)
	_fruit_vy = 0.0
	_fruit_rot = 0.0
	_fruit_scale = Vector2.ONE
	_trees.clear()
	_floating_labels.clear()
	_spawn_timer = 0.8
	_score_label.text = "0"
	if _progress_bar:
		_progress_bar.value = 0.0
	if _progress_label:
		_progress_label.text = "Tiến Độ: 0/%d Cổ Thụ (0%%)" % TARGET_PIPES
	_hint_label.visible = true
	_game_over_panel.visible = false

func _process(delta: float) -> void:
	_fruit_scale = _fruit_scale.lerp(Vector2.ONE, delta * 10.0)
	match _state:
		State.READY:
			# Hiệu ứng quả nhấp nhô nhẹ khi chờ chạm
			var t := Time.get_ticks_msec() / 1000.0
			_fruit_pos.y = (_game_h * 0.45) + sin(t * 4.0) * 8.0
			_fruit_rot = sin(t * 3.0) * 0.08
		State.PLAYING:
			_update_playing(delta)
		State.GAME_OVER:
			# Rơi xuống đáy nếu chưa chạm sàn
			if _fruit_pos.y < _game_h - 26.0:
				_fruit_vy += GRAVITY * delta
				_fruit_pos.y += _fruit_vy * delta
				_fruit_rot = clampf(_fruit_rot + delta * 4.0, -0.4, 1.4)

	_update_floating_labels(delta)
	_board.queue_redraw()

func _update_playing(delta: float) -> void:
	# Vật lý quả
	_fruit_vy += GRAVITY * delta
	_fruit_vy = clampf(_fruit_vy, -500.0, 550.0)
	_fruit_pos.y += _fruit_vy * delta

	# Góc nghiêng quả: bay lên ngửa lên (-0.4 rad), rơi cắm đầu xuống (+1.2 rad)
	if _fruit_vy < 0.0:
		_fruit_rot = lerpf(_fruit_rot, -0.35, delta * 12.0)
	else:
		_fruit_rot = lerpf(_fruit_rot, 0.9, delta * 4.0)

	# Va chạm nóc hoặc sàn
	if _fruit_pos.y <= _fruit_radius + 6.0:
		_fruit_pos.y = _fruit_radius + 6.0
		_fruit_vy = 0.0
	elif _fruit_pos.y >= _game_h - 26.0 - _fruit_radius:
		_trigger_game_over()
		return

	# Di chuyển cây & sinh cây mới
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn_tree_pair()

	for i in range(_trees.size() - 1, -1, -1):
		var tr: Dictionary = _trees[i]
		tr["x"] = float(tr["x"]) - SCROLL_SPEED * delta

		var tx: float = float(tr["x"])
		var gap_y: float = float(tr["gap_y"])

		# Kiểm tra ghi điểm
		if not bool(tr.get("scored", false)) and (tx + TREE_WIDTH < _fruit_pos.x):
			tr["scored"] = true
			_raw_pipes_passed += 1
			var pts := 1 * _multiplier
			_score += pts
			_score_label.text = str(_score)
			var pct := clampf(float(_raw_pipes_passed) / float(TARGET_PIPES) * 100.0, 0.0, 100.0)
			if _progress_bar:
				_progress_bar.value = pct
			if _progress_label:
				_progress_label.text = "Tiến Độ: %d/%d Cổ Thụ (%d%%)" % [_raw_pipes_passed, TARGET_PIPES, int(pct)]
			_spawn_floating_text("+%d" % pts, Vector2(_fruit_pos.x + 20, _fruit_pos.y - 15))

			# Nếu đã vượt đủ mục tiêu cổ thụ -> Toàn thắng 100% màn chơi!
			if _raw_pipes_passed >= TARGET_PIPES:
				_trigger_victory()
				return

		# Kiểm tra va chạm với thân cây trên hoặc thân cây dưới
		if _check_collision_with_tree(tx, gap_y):
			_trigger_game_over()
			return

		# Xoá cây ra khỏi màn hình
		if tx < -TREE_WIDTH - 20:
			_trees.remove_at(i)

func _spawn_tree_pair() -> void:
	# gap_y là tâm của khoảng trống giữa cây trên và cây dưới
	var min_gap_y := 120.0
	var max_gap_y := _game_h - 150.0
	var gap_y := randf_range(min_gap_y, max_gap_y)

	_trees.append({
		"x": _game_w + 10.0,
		"gap_y": gap_y,
		"scored": false
	})

func _check_collision_with_tree(tx: float, gap_y: float) -> bool:
	var fx := _fruit_pos.x
	var fy := _fruit_pos.y
	var r := _fruit_radius - 2.0 # hitbox tinh gọn, công bằng

	# Khoảng trống an toàn: từ gap_top đến gap_bottom
	var gap_top := gap_y - (TREE_GAP * 0.5)
	var gap_bottom := gap_y + (TREE_GAP * 0.5)

	# Kiểm tra vùng X của cây
	if fx + r > tx and fx - r < tx + TREE_WIDTH:
		# Nếu Y nằm trong vùng cây trên hoặc cây dưới -> va chạm!
		if fy - r < gap_top or fy + r > gap_bottom:
			return true
	return false

func _trigger_victory() -> void:
	_trigger_game_finish(true)

func _trigger_game_over() -> void:
	_trigger_game_finish(false)

func _trigger_game_finish(is_victory: bool) -> void:
	if _state == State.GAME_OVER:
		return
	_state = State.GAME_OVER
	_hint_label.visible = false

	# % hoàn thành màn chơi (0% - 100%)
	var completion_pct := clampf(float(_raw_pipes_passed) / float(TARGET_PIPES) * 100.0, 0.0, 100.0)
	var rate := completion_pct / 100.0

	# Phần thưởng gốc theo phẩm cấp quả
	var base_exp: int = int(_tier.get("reward_exp", 500000))
	var base_gold: int = int(_tier.get("reward_gold", 20000))
	var base_fuyuan: int = int(_tier.get("reward_fuyuan", 10))

	# Tính toán phần thưởng thực nhận hoàn toàn tỷ lệ thuận theo % hoàn thành
	var total_exp := int(round(base_exp * rate))
	var total_gold := int(round(base_gold * rate))
	var total_fuyuan := int(round(base_fuyuan * rate))

	# Điểm Flappy Fruit thưởng thêm theo số cây đã vượt và hệ số quả
	if rate > 0.0:
		var bonus_exp_per_point := 10000 * _multiplier
		var bonus_gold_per_point := 1000 * _multiplier
		total_exp += _score * bonus_exp_per_point
		total_gold += _score * bonus_gold_per_point

	# Hiển thị bảng tổng kết kết thúc màn chơi
	_show_game_over_dialog(is_victory, completion_pct, total_exp, total_gold, total_fuyuan)

	# Báo callback hoàn thành và trao thưởng
	if _on_complete.is_valid():
		_on_complete.call(_score, total_exp, total_gold, total_fuyuan)

func _flap() -> void:
	if _state == State.GAME_OVER:
		return
	if _state == State.READY:
		_state = State.PLAYING
		_hint_label.visible = false
	_fruit_vy = FLAP_VELOCITY
	_fruit_scale = Vector2(0.82, 1.28)
	_board.queue_redraw()

func _on_board_input(event: InputEvent) -> void:
	_handle_input_event(event)

func _gui_input(event: InputEvent) -> void:
	_handle_input_event(event)

func _handle_input_event(event: InputEvent) -> void:
	if _state == State.GAME_OVER:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_flap()
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_flap()
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if _state == State.GAME_OVER:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_flap()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_flap()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_UP, KEY_ENTER, KEY_W]:
			_flap()
			get_viewport().set_input_as_handled()

func _spawn_floating_text(txt: String, pos: Vector2) -> void:
	_floating_labels.append({
		"pos": pos,
		"text": txt,
		"alpha": 1.0,
		"timer": 0.8
	})

func _update_floating_labels(delta: float) -> void:
	for i in range(_floating_labels.size() - 1, -1, -1):
		var fl: Dictionary = _floating_labels[i]
		fl["timer"] = float(fl["timer"]) - delta
		fl["pos"] = Vector2(fl["pos"].x, fl["pos"].y - 40.0 * delta)
		fl["alpha"] = clampf(float(fl["timer"]) / 0.8, 0.0, 1.0)
		if float(fl["timer"]) <= 0.0:
			_floating_labels.remove_at(i)

# ---------------------------------------------------------------- VẼ ĐỒ HOẠ (DRAW)
func _draw() -> void:
	pass

func _ready_draw() -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		pass

# Vẽ toàn bộ thế giới game bên trong _board
func _draw_board_content() -> void:
	var canvas := _board
	# 1. Nền bầu trời hoàng hôn kiếm hiệp
	var bg_col_top := Color(0.08, 0.12, 0.22)
	var bg_col_bot := Color(0.18, 0.24, 0.18)
	var rect := Rect2(Vector2.ZERO, Vector2(_game_w, _game_h))
	canvas.draw_rect(rect, bg_col_bot)

	# 2. Dãy núi mờ phía xa
	var mtn_col := Color(0.12, 0.16, 0.22, 0.7)
	var pts := PackedVector2Array([
		Vector2(0, _game_h - 70),
		Vector2(70, _game_h - 180),
		Vector2(160, _game_h - 110),
		Vector2(250, _game_h - 210),
		Vector2(340, _game_h - 130),
		Vector2(_game_w, _game_h - 190),
		Vector2(_game_w, _game_h - 26),
		Vector2(0, _game_h - 26)
	])
	canvas.draw_colored_polygon(pts, mtn_col)

	# 3. Vẽ các thân cây cổ thụ (Chướng ngại vật)
	for tr in _trees:
		var tx: float = float(tr["x"])
		var gap_y: float = float(tr["gap_y"])
		var gap_top := gap_y - (TREE_GAP * 0.5)
		var gap_bottom := gap_y + (TREE_GAP * 0.5)

		# Cây trên (thòng từ đỉnh xuống)
		_draw_ancient_tree(canvas, tx, 0.0, gap_top, true)

		# Cây dưới (mọc từ sàn lên)
		_draw_ancient_tree(canvas, tx, gap_bottom, _game_h - 26.0 - gap_bottom, false)

	# 4. Vẽ nền đất và cỏ dưới sàn
	var ground_rect := Rect2(0, _game_h - 26, _game_w, 26)
	canvas.draw_rect(ground_rect, Color(0.24, 0.16, 0.08)) # Đất nâu
	var grass_rect := Rect2(0, _game_h - 26, _game_w, 6)
	canvas.draw_rect(grass_rect, Color(0.22, 0.55, 0.24)) # Cỏ xanh

	# 5. Vẽ Quả Huy Hoàng
	_draw_fruit(canvas)

	# 6. Vẽ các nhãn điểm số bay lên (+1, +2, +5)
	for fl in _floating_labels:
		var p: Vector2 = fl["pos"]
		var a: float = float(fl["alpha"])
		var font := ThemeDB.fallback_font
		canvas.draw_string(font, p, str(fl["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.88, 0.2, a))

func _draw_ancient_tree(canvas: CanvasItem, x: float, y: float, height: float, is_top: bool) -> void:
	if height <= 2.0:
		return

	# Màu sắc thân cây cổ thụ
	var bark_main := Color(0.35, 0.22, 0.12)
	var bark_dark := Color(0.22, 0.14, 0.08)
	var bark_light := Color(0.48, 0.32, 0.18)
	var canopy_color := Color(0.18, 0.48, 0.22)
	var canopy_highlight := Color(0.32, 0.65, 0.30)

	var trunk_rect := Rect2(x + 6, y, TREE_WIDTH - 12, height)
	canvas.draw_rect(trunk_rect, bark_main)

	# Thớ vỏ cây sần sùi kiếm hiệp
	canvas.draw_rect(Rect2(x + 10, y, 6, height), bark_dark)
	canvas.draw_rect(Rect2(x + TREE_WIDTH - 18, y, 5, height), bark_light)

	# Đầu cây chĩa vào khoảng trống có tán lá hoặc mấu cây cổ thụ
	var tip_y := (y + height - 16) if is_top else y
	var cap_rect := Rect2(x, tip_y, TREE_WIDTH, 16)
	canvas.draw_rect(cap_rect, canopy_color)
	canvas.draw_rect(Rect2(x + 4, tip_y + 3, TREE_WIDTH - 8, 4), canopy_highlight)

	# Vòm lá xum xuê ở đầu ống
	var circle_center := Vector2(x + TREE_WIDTH * 0.5, tip_y + (8 if is_top else 8))
	canvas.draw_circle(circle_center + Vector2(-16, 0), 12, canopy_color)
	canvas.draw_circle(circle_center + Vector2(16, 0), 12, canopy_color)

func _draw_fruit(canvas: CanvasItem) -> void:
	# Vòng sáng huyền ảo quanh quả
	var aura_col: Color = _tier.get("color", Color(1.0, 0.85, 0.25))
	aura_col.a = 0.45
	canvas.draw_circle(_fruit_pos, _fruit_radius + 6.0, aura_col)
	aura_col.a = 0.2
	canvas.draw_circle(_fruit_pos, _fruit_radius + 12.0, aura_col)

	# Vẽ icon Quả Huy Hoàng
	if _fruit_tex:
		var size := Vector2(40, 40)
		var dest_rect := Rect2(-size * 0.5, size)
		# Áp dụng vị trí, xoay và độ nảy
		canvas.draw_set_transform(_fruit_pos, _fruit_rot, _fruit_scale)
		canvas.draw_texture_rect(_fruit_tex, dest_rect, false)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Fallback vẽ hình quả tròn lấp lánh
		canvas.draw_set_transform(_fruit_pos, _fruit_rot, _fruit_scale)
		canvas.draw_circle(Vector2.ZERO, _fruit_radius, _tier.get("color", Color.GOLD))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- BẢNG KẾT THÚC
func _build_game_over_panel() -> void:
	_game_over_panel = PanelContainer.new()
	_game_over_panel.custom_minimum_size = Vector2(360, 260)
	_game_over_panel.position = Vector2((_game_w - 360) * 0.5, (_game_h - 260) * 0.5)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.1, 0.14, 0.96)
	st.border_color = Color(1.0, 0.85, 0.25)
	st.set_border_width_all(3)
	st.set_corner_radius_all(10)
	_game_over_panel.add_theme_stylebox_override("panel", st)
	_board.add_child(_game_over_panel)

func _show_game_over_dialog(is_victory: bool, completion_pct: float, total_exp: int, total_gold: int, total_fuyuan: int) -> void:
	for c in _game_over_panel.get_children():
		c.queue_free()

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	_game_over_panel.add_child(vb)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	if is_victory or completion_pct >= 100.0:
		title.text = "🎉 TOÀN THẮNG — HOÀN THÀNH 100%!"
		title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	elif completion_pct > 0.0:
		title.text = "⚡ KẾT THÚC MÀN CHƠI (%d%%)" % int(completion_pct)
		title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	else:
		title.text = "⚠️ CHƯA VƯỢT ĐƯỢC CÂY NÀO (0%)"
		title.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	vb.add_child(title)

	var score_lbl := Label.new()
	score_lbl.text = "🏆 Vượt Qua: %d/%d Cổ Thụ  ➔  Tiến độ: %d%% (Điểm: %d)" % [
		_raw_pipes_passed, TARGET_PIPES, int(completion_pct), _score
	]
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 13)
	score_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vb.add_child(score_lbl)

	var rew_box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.08, 0.8)
	st.set_corner_radius_all(6)
	rew_box.add_theme_stylebox_override("panel", st)
	vb.add_child(rew_box)

	var rew_vb := VBoxContainer.new()
	rew_vb.add_theme_constant_override("separation", 3)
	rew_box.add_child(rew_vb)

	if completion_pct > 0.0:
		rew_vb.add_child(SocialUi.label("🎁 Thưởng thực nhận theo tiến độ %d%%:" % int(completion_pct), SocialUi.GOLD, 13))
		rew_vb.add_child(SocialUi.label("+ %s Điểm Kinh Nghiệm (%d%%)" % [InventoryPopup.format_money(total_exp), int(completion_pct)], SocialUi.LABEL_GREEN, 14))
		rew_vb.add_child(SocialUi.label("+ %s Lượng Bạc (%d%%)" % [InventoryPopup.format_money(total_gold), int(completion_pct)], SocialUi.GOLD, 14))
		rew_vb.add_child(SocialUi.label("+ %d Điểm Phúc Duyên (%d%%)" % [total_fuyuan, int(completion_pct)], SocialUi.LABEL_BLUE, 14))
	else:
		rew_vb.add_child(SocialUi.label("Chưa đạt tiến độ nào (0%). Phần thưởng: 0", Color(0.9, 0.5, 0.4), 13))
		rew_vb.add_child(SocialUi.label("Chưa bị trừ lượt hái quả hôm nay! Đại hiệp có thể thử lại ngay.", SocialUi.MUTED, 12))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	if completion_pct <= 0.0:
		var retry_btn := SocialUi.stone_button("🔄 Thử Lại", Vector2(130, 38))
		retry_btn.pressed.connect(_reset_game)
		btn_row.add_child(retry_btn)

		var close_btn := SocialUi.stone_button("Đóng", Vector2(110, 38))
		close_btn.pressed.connect(_on_close_clicked)
		btn_row.add_child(close_btn)
	else:
		var close_btn := SocialUi.stone_button("Nhận Thưởng & Đóng", Vector2(180, 40))
		close_btn.pressed.connect(_on_close_clicked)
		btn_row.add_child(close_btn)

	_game_over_panel.visible = true

func _on_close_clicked() -> void:
	finished.emit(_score, _tier)
	queue_free()

extends Node
class_name LinhLungPrepArea

## KHU CHUẨN BỊ LINH LUNG THÁP (Map #1037 - map_publish/qiancengta)
## Nơi người chơi tập trung trong 5 phút (300 giây) chuẩn VNG để hệ thống ghép phòng đấu trường (25 - 32 người),
## chuẩn bị dược phẩm, kỹ năng trước khi đồng loạt truyền tống vào Tầng 1 tháp.

const MAP_ID := 1037
const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const MAIN_SCENE := "res://main.tscn"

const SPAWN_POS := Vector2(51200, 50944)  ## Tọa độ VLTK (200/199)
const NPC_POS := Vector2(51200, 50800)
const PREP_DURATION_SEC := 300.0  ## 5 phút chuẩn VNG (300 giây)
const MIN_PLAYERS := 5
const MAX_PLAYERS := 16

var _player: Node2D = null
var _hud: CanvasLayer = null
var _npc_node: Node2D = null
var _prep_time_left: float = PREP_DURATION_SEC
var _timer_label: Label = null
var _status_label: Label = null
var _is_entering: bool = false
var _prep_bots: Array[Node2D] = []

func _ready() -> void:
	call_deferred("_setup_in_world")

func _setup_in_world() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		_player.position = SPAWN_POS
		if _player.has_method("notify"):
			_player.notify("Chào mừng đại hiệp đến Khu Chuẩn Bị Linh Lung Tháp (Map #1037)!")

	_spawn_npc()
	_spawn_waiting_mysterious_players()
	_build_hud()

func _spawn_npc() -> void:
	_npc_node = Node2D.new()
	_npc_node.name = "NpcNhacXung"
	_npc_node.position = NPC_POS

	# Hiệu ứng vòng tròn chân NPC
	var ring := Node2D.new()
	ring.z_index = 0
	ring.draw.connect(func() -> void:
		ring.draw_arc(Vector2.ZERO, 36.0, 0, TAU, 32, Color(0.2, 0.8, 1.0, 0.7), 2.0)
		ring.draw_circle(Vector2.ZERO, 36.0, Color(0.2, 0.8, 1.0, 0.08))
	)
	_npc_node.add_child(ring)

	# Bảng tên NPC
	var lbl := Label.new()
	lbl.text = "🏛️ SỨ GIẢ LINH LUNG THÁP\n[ Nhạc Xung ]"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-120, -70)
	lbl.custom_minimum_size = Vector2(240, 40)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 2
	_npc_node.add_child(lbl)

	var parent := VltkWorld.entity_parent()
	if parent != null:
		parent.add_child(_npc_node)
	else:
		add_child(_npc_node)

## Tạo các Người Bí Ẩn khác cùng đứng chờ trong phòng chuẩn bị
func _spawn_waiting_mysterious_players() -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null:
		return

	var offsets: Array[Vector2] = [
		Vector2(-90, -40), Vector2(90, -35), Vector2(-120, 60),
		Vector2(110, 70), Vector2(-45, 110), Vector2(60, 115)
	]

	for i in offsets.size():
		var pos: Vector2 = NPC_POS + offsets[i]
		var bot_node := Node2D.new()
		bot_node.name = "WaitingMystery_%d" % i
		bot_node.position = pos

		# Nhãn Người Bí Ẩn
		var name_lbl := Label.new()
		name_lbl.text = "Người Bí Ẩn"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(-70, -60)
		name_lbl.custom_minimum_size = Vector2(140, 20)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		name_lbl.add_theme_constant_override("outline_size", 3)
		name_lbl.z_index = 2
		bot_node.add_child(name_lbl)

		# Vòng chân
		var c_ring := Node2D.new()
		c_ring.draw.connect(func() -> void:
			c_ring.draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.35))
		)
		bot_node.add_child(c_ring)

		parent.add_child(bot_node)
		_prep_bots.append(bot_node)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "LinhLungPrepHud"
	add_child(_hud)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH  ## Căn chuẩn ngay giữa màn hình, tự động mở rộng cân đối 2 bên
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = 56.0  ## Đặt xít xuống dưới TopStatusBar (kết thúc ở y~45), hoàn toàn không che thanh máu
	panel.offset_bottom = 56.0
	panel.custom_minimum_size = Vector2(560, 0)

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.06, 0.08, 0.12, 0.65)  ## Nền hơi trong suốt (alpha 0.65)
	sbox.border_color = Color(0.3, 0.85, 1.0, 0.75)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(8)
	sbox.content_margin_left = 16
	sbox.content_margin_right = 16
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sbox)
	_hud.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)

	# Dòng tiêu đề
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 16)
	vb.add_child(top_row)

	var title := Label.new()
	title.text = "🏯 KHU CHUẨN BỊ LINH LUNG THÁP"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	top_row.add_child(title)

	# Dòng đồng hồ đếm ngược 5 phút & trạng thái đấu trường
	var mid_row := HBoxContainer.new()
	mid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_row.add_theme_constant_override("separation", 16)
	vb.add_child(mid_row)

	_timer_label = Label.new()
	_timer_label.text = "⏱️ Thời gian chờ: 05:00"
	_timer_label.add_theme_font_size_override("font_size", 13)
	_timer_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer_label.add_theme_constant_override("outline_size", 3)
	mid_row.add_child(_timer_label)

	_status_label = Label.new()
	_status_label.text = "👥 Báo danh: 5/16 (Tối thiểu %d) • Đủ điều kiện!" % MIN_PLAYERS
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 2)
	mid_row.add_child(_status_label)

	# Dòng nút điều khiển
	var bot_row := HBoxContainer.new()
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_row.add_theme_constant_override("separation", 18)
	vb.add_child(bot_row)

	var btn_skip := Button.new()
	btn_skip.text = "⚡ Vào Tháp Ngay (Bỏ Qua Chờ 5 Phút)"
	btn_skip.custom_minimum_size = Vector2(270, 36)
	var bs_skip := StyleBoxFlat.new()
	bs_skip.bg_color = Color(0.82, 0.28, 0.16, 0.95)
	bs_skip.border_color = Color(1.0, 0.85, 0.3)
	bs_skip.set_border_width_all(2)
	bs_skip.set_corner_radius_all(6)
	btn_skip.add_theme_stylebox_override("normal", bs_skip)
	btn_skip.pressed.connect(_enter_tower_now)
	bot_row.add_child(btn_skip)

	var btn_leave := Button.new()
	btn_leave.text = "🚪 Rời Khu Chuẩn Bị"
	btn_leave.custom_minimum_size = Vector2(170, 36)
	var bs_leave := StyleBoxFlat.new()
	bs_leave.bg_color = Color(0.2, 0.24, 0.28, 0.85)
	bs_leave.border_color = Color(0.65, 0.65, 0.65)
	bs_leave.set_border_width_all(1)
	bs_leave.set_corner_radius_all(6)
	btn_leave.add_theme_stylebox_override("normal", bs_leave)
	btn_leave.pressed.connect(_leave_prep_area)
	bot_row.add_child(btn_leave)

func _process(delta: float) -> void:
	if _is_entering:
		return

	if _prep_time_left > 0.0:
		_prep_time_left -= delta
		if _prep_time_left <= 0.0:
			_prep_time_left = 0.0
			_enter_tower_now()

		if _timer_label != null:
			var mins := int(_prep_time_left / 60.0)
			var secs := int(_prep_time_left) % 60
			_timer_label.text = "⏱️ Thời gian chờ: %02d:%02d" % [mins, secs]
			if _prep_time_left <= 30.0:
				_timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			elif _prep_time_left <= 60.0:
				_timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

func _enter_tower_now() -> void:
	if _is_entering:
		return
	_is_entering = true

	if _player != null and _player.has_method("notify"):
		_player.notify("Thời gian chuẩn bị kết thúc! Đang truyền tống toàn bộ người chơi vào Tầng 1 Linh Lung Tháp!")

	var challenge_script: GDScript = load("res://systems/challenge/linh_lung_thap_challenge.gd")
	if challenge_script != null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root and tree.root.has_node("GameManager"):
			var gm = tree.root.get_node("GameManager")
			gm.field_map = challenge_script.map_entry()
		get_tree().change_scene_to_file(MAIN_SCENE)

func _leave_prep_area() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		var gm = tree.root.get_node("GameManager")
		gm.field_map = {
			"id": 1001,
			"name": "Lâm An",
			"dir": "res://world/maps/map_1001",
			"level": 80,
			"arena_center": Vector2(51200, 50944)
		}
	get_tree().change_scene_to_file(MAIN_SCENE)

extends Node2D
class_name ThuThanhChallenge

## HỆ THỐNG ĐIỀU KHIỂN CHÍNH THỦ THÀNH (ZOMBIES VS PLANTS JX1)
## Phân hệ: Offline -> Vượt Ải -> Luyện -> Thủ Thành (Zombies vs Plants)
## Quản lý bàn cờ 11x5 phòng thủ + 3x5 quái, Xe Tống Kim, 5 đợt quái & Boss,
## kinh tế Xu, mua hiệp khách, nhặt Xu rơi và điều kiện Thắng/Thua.

signal finished(success: bool)

const ThuThanhSkillDataScript := preload("res://systems/challenge/thu_thanh_skill_data.gd")
const ThuThanhUnitScript := preload("res://systems/challenge/thu_thanh_unit.gd")
const ThuThanhMonsterScript := preload("res://systems/challenge/thu_thanh_monster.gd")
const ThuThanhCoinScript := preload("res://systems/challenge/thu_thanh_coin.gd")
const ThuThanhSeedPickerScript := preload("res://ui/thu_thanh/seed_picker_dialog.gd")

# Bố cục bàn cờ: 11 cột phòng thủ (0..10) + 3 cột quái (11..13) = 14 cột, 5 hàng (0..4)
const GRID_COLS := 14
const DEFENSE_COLS := 11
const GRID_ROWS := 5
const CELL_W := 96.0  ## Ô đất hình vuông: giữ chiều dọc 96.0, tăng chiều ngang lên 96.0
const CELL_H := 96.0
const ORIGIN_X := 120.0
const ORIGIN_Y := 72.0
const DEFENSE_BOUNDARY_X := ORIGIN_X + DEFENSE_COLS * CELL_W  ## 1176.0: Lằn ranh vạch vàng phân tách bàn cờ và khu quái chờ

var map_entry: Dictionary = {}
var map_tier: int = 1
var char_level: int = 10
var unlocked_slots: int = 5
var current_coins: int = 300

# 5 Xe Tống Kim bảo vệ 5 hàng (Cơ chế Máy Cắt Cỏ Lawn Mower PvZ)
var _cart_nodes: Array[Node2D] = []
var _cart_available: Array[bool] = [true, true, true, true, true]
var _cart_charging: Array[bool] = [false, false, false, false, false]
var _cart_sprites: Array[Node2D] = []
var _cart_anim_timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
const CART_SPEED: float = 650.0

# Trạng thái trận đấu
var current_wave: int = 1
var TOTAL_WAVES: int = 10
var wave_state: String = "PREP"  ## PREP, RUNNING, INTERMISSION, VICTORY, DEFEAT
var is_paused: bool = false

# Lưới bàn cờ: [row][col] -> ThuThanhUnit hoặc null
var _grid_units: Array = []

# Danh sách kỹ năng đã chọn đem vào trận
var equipped_skills: Array[String] = []
var _cooldowns: Dictionary = {}  ## skill_id -> float (thời gian hồi còn lại)

# Cấp trận đấu, EXP và Điểm Kỹ Năng (Match Leveling & Skill Points System)
var match_level: int = 1
var match_exp: int = 0
var match_exp_next: int = 80
var available_skill_points: int = 0
var accumulated_char_exp: int = 0
var match_tt_exp_gained: int = 0
var skill_levels: Dictionary = {}  ## skill_id -> int (khởi đầu cấp 1)

# Chọn thẻ bài hoặc xẻng rút quân
var selected_card_skill_id: String = ""
var is_shovel_mode: bool = false

# Dữ liệu quái của map
var map_monster_types: Array[Dictionary] = []
var _monsters_to_spawn: Array = []
var _wave_spawn_timer: float = 0.0
var _alive_monsters_count: int = 0

# HUD Nodes
var _hud_layer: CanvasLayer
var _map_name_lbl: Label
var _cart_hp_bar: ProgressBar
var _cart_hp_lbl: Label
var _wave_lbl: Label
var _wave_progress_bar: ProgressBar
var _tt_lvl_lbl: Label
var _tt_exp_bar: ProgressBar
var _coin_lbl: Label
var _card_buttons: Array[Button] = []
var _card_cooldown_masks: Array[ColorRect] = []
var _card_cooldown_labels: Array[Label] = []
var _card_level_labels: Array[Label] = []
var _bot_box: HBoxContainer = null
var _shovel_btn: Button
var _banner_lbl: Label
var _banner_timer: float = 0.0
var _pause_btn: Button
var _pause_overlay: Control
var _speed_btn: Button
var current_speed_idx: int = 0
const SPEED_STEPS := [1.0, 2.0, 4.0]
const SPEED_LABELS := ["⏩ 1x", "⏩ 2x", "⏩ 4x"]
const SPEED_COLORS := [
	Color(0.88, 0.88, 0.92),
	Color(0.3, 0.95, 0.65),
	Color(1.0, 0.85, 0.25)
]

# Con trỏ highlight ô bàn cờ
var _hover_rect: ColorRect
var _hover_row: int = -1
var _hover_col: int = -1

func _get_gm() -> Node:
	if Engine.has_singleton("GameManager"):
		return Engine.get_singleton("GameManager")
	var loop = Engine.get_main_loop()
	if loop != null and "root" in loop and loop.root != null and loop.root.has_node("GameManager"):
		return loop.root.get_node("GameManager")
	return null

func _get_mc() -> Node:
	if Engine.has_singleton("MapCatalog"):
		return Engine.get_singleton("MapCatalog")
	var loop = Engine.get_main_loop()
	if loop != null and "root" in loop and loop.root != null and loop.root.has_node("MapCatalog"):
		return loop.root.get_node("MapCatalog")
	return null

func _get_sm() -> Node:
	if Engine.has_singleton("SaveManager"):
		return Engine.get_singleton("SaveManager")
	var loop = Engine.get_main_loop()
	if loop != null and "root" in loop and loop.root != null and loop.root.has_node("SaveManager"):
		return loop.root.get_node("SaveManager")
	return null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var gm := _get_gm()
	if gm != null and "field_map" in gm and gm.field_map is Dictionary and not gm.field_map.is_empty():
		map_entry = gm.field_map
	var char_prof: PlayerProfile = gm.local_profile if (gm != null and "local_profile" in gm) else null
	if char_prof != null:
		char_level = char_prof.level
	var mc := _get_mc()
	var default_tier := 1
	if mc != null and mc.has_method("tier_of_level"):
		default_tier = int(mc.tier_of_level(int(map_entry.get("level", 10))))
	map_tier = int(map_entry.get("tier", default_tier))
	if map_tier <= 0:
		map_tier = 1
	unlocked_slots = ThuThanhSkillDataScript.get_unlocked_slots_for_tier(map_tier)

	# Nạp cấp độ kỹ năng đã lưu bền vững qua mọi map
	var saved_lvls := ThuThanhSkillDataScript.get_all_saved_skill_levels()
	for sid in saved_lvls:
		skill_levels[sid] = int(saved_lvls[sid])

	# Gợi ý đội hình kỹ năng mặc định nếu danh sách trống
	if equipped_skills.is_empty():
		var default_picks: Array[String] = [
			"thieu_lam", "cai_bang", "con_lon", "ngu_doc",
			"hoa_son", "thuy_yen", "duong_mon_tk", "vo_dang"
		]
		for sid in default_picks:
			if equipped_skills.size() < unlocked_slots:
				equipped_skills.append(sid)
		current_coins = ThuThanhSkillDataScript.calculate_starting_coins(equipped_skills)
		for sid in equipped_skills:
			_cooldowns[sid] = 0.0
			if not skill_levels.has(sid):
				skill_levels[sid] = saved_lvls.get(sid, 1)

	_init_grid()
	_init_monster_data()
	_sweep_static_monsters()
	_remove_map_structures()
	_setup_camera_and_player()
	_setup_board_visuals()
	_setup_escort_cart()
	_build_hud()

	# Mở màn hình chọn thẻ kỹ năng Seed Picker trước khi xuất trận
	call_deferred("_open_seed_picker")

func _init_grid() -> void:
	_grid_units.clear()
	for r in GRID_ROWS:
		var row_arr: Array = []
		for c in GRID_COLS:
			row_arr.append(null)
		_grid_units.append(row_arr)

func _init_monster_data() -> void:
	map_monster_types.clear()
	var raw_monsters = map_entry.get("monsters", [])
	if raw_monsters is Array and not raw_monsters.is_empty():
		for m in raw_monsters:
			if m is Dictionary:
				map_monster_types.append(m)

	if map_monster_types.is_empty():
		var base_lvl := int(map_entry.get("level", 10))
		map_monster_types = [
			{"name": "Sơn Tặc", "level": base_lvl, "hp": 140.0 + base_lvl * 12.0, "xu_drop": 25},
			{"name": "Thổ Phỉ", "level": base_lvl + 2, "hp": 180.0 + base_lvl * 15.0, "xu_drop": 30},
			{"name": "Giang Hồ Khoái Đao", "level": base_lvl + 5, "hp": 240.0 + base_lvl * 18.0, "xu_drop": 40}
		]

func _sweep_static_monsters() -> void:
	var existing = get_tree().get_nodes_in_group("enemies")
	for e in existing:
		if is_instance_valid(e) and not e.is_in_group("thu_thanh_enemies"):
			e.queue_free()

## Loại bỏ toàn bộ công trình (cây cối, tảng đá, nhà cửa, lều bạt...) trên map khi chơi chế độ Thủ Thành (Zombies)
func _remove_map_structures() -> void:
	if VltkWorld.current != null and VltkWorld.current.map != null:
		var m = VltkWorld.current.map
		if "hide_structures" in m:
			m.hide_structures = true
		if m.objects_root != null:
			m.objects_root.visible = false
			for c in m.objects_root.get_children():
				if is_instance_valid(c) and not (c is VltkMonster):
					c.visible = false
					c.queue_free()
		if m.above_root != null:
			m.above_root.visible = false
			for c in m.above_root.get_children():
				if is_instance_valid(c):
					c.visible = false
					c.queue_free()
		if "_g_flat" in m and m._g_flat != null:
			m._g_flat.visible = false
			for c in m._g_flat.get_children():
				if is_instance_valid(c):
					c.visible = false
					c.queue_free()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if get_tree() != null:
		get_tree().paused = false
	is_paused = false
	if VltkWorld.current != null and VltkWorld.current.map != null:
		var m = VltkWorld.current.map
		if "hide_structures" in m:
			m.hide_structures = false
		if m.objects_root != null:
			m.objects_root.visible = true
		if m.above_root != null:
			m.above_root.visible = true
		if "_g_flat" in m and m._g_flat != null:
			m._g_flat.visible = true

func _setup_camera_and_player() -> void:
	# Căn cố định camera nhìn bao quát toàn bộ bàn cờ 1280x720 trên bản đồ thực địa
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		player.visible = false
		player.set_process(false)
		player.set_physics_process(false)
		var cam = player.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			cam.enabled = false

	var center := Vector2(640, 360)
	if VltkWorld.current != null:
		center = VltkWorld.current._default_center()
		if center == Vector2.ZERO and player != null:
			center = player.global_position
		var m_obj = VltkWorld.current.map
		if m_obj != null:
			if m_obj.has_method("prepare_around"):
				m_obj.prepare_around(center)
			if m_obj.has_method("warm_up"):
				m_obj.warm_up(center)

	# Định vị toàn bộ challenge tại tâm của map
	global_position = center - Vector2(640, 360)

	# Camera cố định cho bàn cờ ô vuông 96x96
	var board_cam := Camera2D.new()
	board_cam.name = "ThuThanhBoardCamera"
	var cam_x := ORIGIN_X + (GRID_COLS * CELL_W) * 0.5 - 20.0
	var cam_y := ORIGIN_Y + (GRID_ROWS * CELL_H) * 0.5 + 8.0
	board_cam.position = Vector2(cam_x, cam_y)
	board_cam.zoom = Vector2(0.86, 0.86)
	add_child(board_cam)
	board_cam.make_current()

	if VltkWorld.current != null and VltkWorld.current.map != null:
		VltkWorld.current.map.focus = board_cam

func _setup_board_visuals() -> void:
	# Khung bàn cờ kẻ ô bán trong suốt (checkerboard)
	# Đặt z_index = -50 và z_as_relative = false để luôn nằm DƯỚI toàn bộ công trình của map (nhà cửa, cây cối, lều bạt...)
	var board_node := Node2D.new()
	board_node.name = "BoardGridVisuals"
	board_node.z_as_relative = false
	board_node.z_index = -50
	add_child(board_node)

	# Nền cỏ xanh mướt tự nhiên trải dưới bàn cờ (độ mờ vừa phải để thấy công trình và nền đất map)
	var grass_bg := ColorRect.new()
	grass_bg.size = Vector2(1280, 720)
	grass_bg.position = Vector2.ZERO
	grass_bg.color = Color(0.14, 0.28, 0.12, 0.25)
	grass_bg.z_index = -10
	grass_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_node.add_child(grass_bg)

	for r in GRID_ROWS:
		for c in GRID_COLS:
			var cell_rect := ColorRect.new()
			cell_rect.size = Vector2(CELL_W - 2.0, CELL_H - 2.0)
			cell_rect.position = Vector2(ORIGIN_X + c * CELL_W, ORIGIN_Y + r * CELL_H)

			if c < DEFENSE_COLS:
				# Khu phòng thủ: Ô cờ xanh lá nhạt đan xen đậm
				var is_alt := (r + c) % 2 == 0
				cell_rect.color = Color(0.16, 0.42, 0.18, 0.45) if is_alt else Color(0.10, 0.30, 0.12, 0.38)
				cell_rect.mouse_filter = Control.MOUSE_FILTER_PASS

				# Nút tương tác bấm trực tiếp trên từng ô phòng thủ
				var cell_btn := Button.new()
				cell_btn.name = "CellBtn_%d_%d" % [r, c]
				cell_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
				cell_btn.flat = true
				cell_btn.mouse_filter = Control.MOUSE_FILTER_PASS
				var row_idx := r
				var col_idx := c
				cell_btn.pressed.connect(func() -> void:
					_handle_cell_click(row_idx, col_idx)
				)
				cell_btn.mouse_entered.connect(func() -> void:
					_hover_row = row_idx
					_hover_col = col_idx
				)
				cell_rect.add_child(cell_btn)
			else:
				# Khu quái chờ (staging 3 cột bên phải): Màu đỏ thẫm cảnh báo
				cell_rect.color = Color(0.45, 0.12, 0.12, 0.32)
				cell_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

			board_node.add_child(cell_rect)

	# Vạch phân ranh giới đá giữa khu phòng thủ và khu quái
	var sep_line := ColorRect.new()
	sep_line.color = Color(0.9, 0.7, 0.2, 0.6)
	sep_line.size = Vector2(2, GRID_ROWS * CELL_H)
	sep_line.position = Vector2(ORIGIN_X + DEFENSE_COLS * CELL_W, ORIGIN_Y)
	sep_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_node.add_child(sep_line)

	# Vạch đá phòng thủ ngoài cùng bên trái (sau Xe Tống Kim)
	var left_wall := ColorRect.new()
	left_wall.color = Color(0.5, 0.45, 0.4, 0.7)
	left_wall.size = Vector2(6, GRID_ROWS * CELL_H)
	left_wall.position = Vector2(ORIGIN_X - 6, ORIGIN_Y)
	left_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_node.add_child(left_wall)

	# Rect highlight khi hover chọn ô
	_hover_rect = ColorRect.new()
	_hover_rect.size = Vector2(CELL_W - 2.0, CELL_H - 2.0)
	_hover_rect.color = Color(0.3, 0.9, 0.3, 0.4)
	_hover_rect.visible = false
	_hover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_node.add_child(_hover_rect)

func _setup_escort_cart() -> void:
	# Dọn các xe cũ nếu có
	for c in _cart_nodes:
		if is_instance_valid(c):
			c.queue_free()
	_cart_nodes.clear()
	_cart_sprites.clear()
	_cart_available = [true, true, true, true, true]
	_cart_charging = [false, false, false, false, false]
	_cart_anim_timers = [0.0, 0.0, 0.0, 0.0, 0.0]

	const MonsterSpriteScript = preload("res://systems/monster/monster_sprite.gd")

	# Thiết lập 5 Xe Tống Kim đứng đầu mỗi hàng (row 0..4)
	# Xe nhỏ lại còn 1/4 kích thước ban đầu (scale 0.24, nằm dưới công trình với z_index = -15)
	for r in GRID_ROWS:
		var cart := Node2D.new()
		cart.name = "XeTongKim_Hang_%d" % (r + 1)
		var cx := ORIGIN_X - 35.0
		var cy := ORIGIN_Y + r * CELL_H + CELL_H * 0.65
		cart.position = Vector2(cx, cy)
		cart.z_as_relative = false
		cart.z_index = -15
		cart.add_to_group("escort_carts")
		add_child(cart)

		# Sprite Xe Tống Kim (enemy241) thu nhỏ còn 1/4 kích thước hiện tại (0.95 * 0.25 = 0.24)
		var cart_sprite = MonsterSpriteScript.new()
		cart_sprite.set_resource("enemy241")
		cart_sprite.set_pose("fight_stand", 48, 0.0)  ## 48 = quay mặt sang phải
		cart_sprite.scale = Vector2(0.24, 0.24)
		cart.add_child(cart_sprite)

		# Nhãn số hàng trên xe nhỏ gọn vừa vặn với xe 1/4
		var cart_lbl := Label.new()
		cart_lbl.text = "Xe %d" % (r + 1)
		cart_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cart_lbl.size = Vector2(40, 14)
		cart_lbl.position = Vector2(-20, -22)
		cart_lbl.add_theme_font_size_override("font_size", 9)
		cart_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cart_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cart_lbl.add_theme_constant_override("outline_size", 1)
		cart.add_child(cart_lbl)

		_cart_nodes.append(cart)
		_cart_sprites.append(cart_sprite)

func _process_escort_carts(delta: float) -> void:
	if wave_state != "RUNNING":
		return

	var enemies = get_tree().get_nodes_in_group("thu_thanh_enemies")

	for r in GRID_ROWS:
		var cart = _cart_nodes[r] if r < _cart_nodes.size() else null

		# 1. Xe đang trong trạng thái lao lên càn quét (CHARGING)
		if _cart_charging[r]:
			if cart != null and is_instance_valid(cart):
				_cart_anim_timers[r] += delta
				cart.position.x += CART_SPEED * delta

				# Hoạt ảnh lăn bánh sang phải
				var sp = _cart_sprites[r]
				if is_instance_valid(sp) and sp.has_method("set_pose"):
					sp.set_pose("run", 48, fmod(_cart_anim_timers[r] * 3.0, 1.0))

				# Càn quét toàn bộ quái vật trên cùng hàng r
				for e in enemies:
					if not is_instance_valid(e) or bool(e.get("is_dead")):
						continue
					if int(e.get("lane_row")) == r:
						# Nếu quái chạm vào hoặc ở phía trước đầu xe
						if e.position.x <= cart.position.x + 50.0:
							if e.has_method("die"):
								e.die()
							elif e.has_method("take_damage"):
								e.take_damage(999999.0, cart)

				# Khi xe chạy ra khỏi mép phải bản đồ (vượt qua toàn bộ làn chiến)
				var right_bound := ORIGIN_X + GRID_COLS * CELL_W + 120.0
				if cart.position.x >= right_bound:
					_cart_charging[r] = false
					_cart_available[r] = false
					cart.queue_free()
					_cart_nodes[r] = null
			else:
				# Tự phục hồi trạng thái an toàn nếu cart bị giải phóng bất thường
				_cart_charging[r] = false
				_cart_available[r] = false
				_cart_nodes[r] = null
			continue

		# 2. Xe vẫn còn sẵn sàng đỗ ở hàng r (READY)
		if _cart_available[r] and cart != null and is_instance_valid(cart):
			for e in enemies:
				if not is_instance_valid(e) or bool(e.get("is_dead")):
					continue
				if int(e.get("lane_row")) == r:
					# Quái vật đã chạm vào vị trí đỗ của xe
					if e.position.x <= cart.position.x + 20.0:
						_trigger_cart(r)
						break

		# 3. Hàng r đã mất xe (_cart_available[r] == false và không sạc):
		# Nếu có quái tiếp tục vượt qua vạch sau cùng bên trong -> THUA CUỘC NGAY!
		if not _cart_available[r] and not _cart_charging[r]:
			for e in enemies:
				if not is_instance_valid(e) or bool(e.get("is_dead")):
					continue
				if int(e.get("lane_row")) == r:
					if e.position.x <= ORIGIN_X - 50.0:
						_on_defeat_by_invasion(r)
						return

func _trigger_cart(r: int) -> void:
	if not _cart_available[r] or _cart_charging[r]:
		return
	_cart_charging[r] = true
	_cart_available[r] = false
	_show_banner("⚠️ XE TỐNG KIM HÀNG %d XUẤT KÍCH CÀN QUÉT QUÂN ĐỊCH!" % (r + 1))
	_update_hud_display()

func _on_defeat_by_invasion(r: int) -> void:
	if wave_state == "DEFEAT" or wave_state == "VICTORY":
		return
	wave_state = "DEFEAT"
	_show_banner("❌ QUÂN ĐỊCH ĐÃ ĐỘT NHẬP DOANH TRẠI QUA HÀNG %d! THẤT BẠI!" % (r + 1))
	var reward_exp := _award_defeat_char_exp()
	_show_defeat_popup(reward_exp)
	finished.emit(false)

func _open_seed_picker() -> void:
	var picker = ThuThanhSeedPickerScript.new()
	var tt_lvl := ThuThanhSkillDataScript.get_thu_thanh_level()
	picker.setup(map_tier, tt_lvl)
	picker.started.connect(_on_seed_picker_started)
	picker.canceled.connect(_on_exit_pressed)
	add_child(picker)

func _on_seed_picker_started(selected_ids: Array[String], starting_coins: int) -> void:
	equipped_skills = selected_ids
	current_coins = starting_coins
	_cooldowns.clear()
	var saved_lvls := ThuThanhSkillDataScript.get_all_saved_skill_levels()
	for sid in equipped_skills:
		_cooldowns[sid] = 0.0
		skill_levels[sid] = int(saved_lvls.get(sid, 1))

	_refresh_hud_cards()
	_update_hud_display()

	# Bắt đầu trận đấu đợt 1
	wave_state = "RUNNING"
	_start_wave(1)

# -----------------------------------------------------------------
# VÒNG LẶP CHIẾN ĐẤU & 5 ĐỢT QUÁI (WAVES)
# -----------------------------------------------------------------
func _process(delta: float) -> void:
	if is_paused or wave_state == "PREP" or wave_state == "VICTORY" or wave_state == "DEFEAT":
		return

	_update_cooldowns(delta)
	_update_hover_grid()
	_update_hud_display()
	_process_escort_carts(delta)

	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _banner_lbl != null:
			var tw := create_tween()
			tw.tween_property(_banner_lbl, "modulate:a", 0.0, 0.4)

	# Quản lý nhịp độ thả quái
	if wave_state == "RUNNING":
		if not _monsters_to_spawn.is_empty():
			_wave_spawn_timer += delta
			var spawn_interval := 2.5
			if current_wave >= 8:
				spawn_interval = 1.2
			elif current_wave >= 4:
				spawn_interval = 1.8
			if _wave_spawn_timer >= spawn_interval:
				_wave_spawn_timer = 0.0
				_spawn_next_monster()
		else:
			# Kiểm tra xem toàn bộ quái trong đợt đã chết hết chưa (loại trừ các node đã chết/đang tan biến hoặc ngoài mép bàn cờ)
			var has_alive := false
			for e in get_tree().get_nodes_in_group("thu_thanh_enemies"):
				if not is_instance_valid(e) or bool(e.get("is_dead")):
					continue
				# Dọn dẹp an toàn nếu node quái rơi quá xa ngoài biên bản cờ bàn chơi
				if e.position.x < ORIGIN_X - 200.0 or e.position.x > ORIGIN_X + GRID_COLS * CELL_W + 500.0:
					e.queue_free()
					continue
				has_alive = true
				break
			if not has_alive:
				_on_wave_cleared()

func _update_cooldowns(delta: float) -> void:
	for sid in _cooldowns:
		if _cooldowns[sid] > 0.0:
			_cooldowns[sid] = maxf(0.0, _cooldowns[sid] - delta)

	# Cập nhật lớp phủ đen và nhãn số giây hồi chiêu trên các thẻ kỹ năng
	for i in _card_buttons.size():
		if i < equipped_skills.size():
			var sid := equipped_skills[i]
			var cd_rem: float = _cooldowns.get(sid, 0.0)
			var s := ThuThanhSkillDataScript.get_skill(sid)
			var total_cd: float = float(s.get("cooldown", 10.0))
			var cost: int = int(s.get("cost", 50))
			var mask: ColorRect = _card_cooldown_masks[i]
			var cd_lbl: Label = _card_cooldown_labels[i] if i < _card_cooldown_labels.size() else null
			var btn: Button = _card_buttons[i]

			if cd_rem > 0.0 and total_cd > 0.0:
				mask.visible = true
				var ratio := cd_rem / total_cd
				mask.size = Vector2(88.0, 88.0 * ratio)
				if cd_lbl != null:
					cd_lbl.visible = true
					cd_lbl.text = "%.0fs" % ceilf(cd_rem)
				btn.disabled = true
			else:
				mask.visible = false
				if cd_lbl != null:
					cd_lbl.visible = false
				btn.disabled = current_coins < cost

## Hệ số máu theo đợt quái (Yêu cầu: đợt 1 giảm hơn 1/2, đợt 2 giảm 1/3, đợt 3 bình thường, sau đó tăng 0.2 lần mỗi đợt)
func get_wave_hp_mult(wave: int) -> float:
	if wave <= 1:
		return 0.45  ## Giảm hơn 1/2 (còn 45% máu)
	elif wave == 2:
		return 0.67  ## Giảm 1/3 (còn 67% máu)
	else:
		return 1.0 + float(wave - 3) * 0.2  ## Đợt 3: 1.0x, Đợt 4: 1.2x, ..., Đợt 10: 2.4x

## Số lượng quái theo đợt (Tăng số lượng 0.5 mỗi đợt)
func get_wave_monster_count(wave: int) -> int:
	var base_count := 6.0
	return int(round(base_count * (1.0 + float(wave - 1) * 0.5)))

func _start_wave(wave_num: int) -> void:
	current_wave = wave_num
	wave_state = "RUNNING"
	_monsters_to_spawn.clear()
	_wave_spawn_timer = 0.0

	var wave_title := "ĐỢT %d/%d BẮT ĐẦU!" % [current_wave, TOTAL_WAVES]
	if current_wave == TOTAL_WAVES:
		wave_title = "⚠️ ĐỢT 10/10 CAO TRÀO — ĐẠI QUÂN QUÁI VẬT & ĐẠI THỦ LĨNH TẤN CÔNG!"
	elif current_wave == 5:
		wave_title = "⚠️ ĐỢT 5/10 — NỬA CHẶNG ĐƯỜNG, TINH ANH TĂNG CƯỜNG!"
	_show_banner(wave_title)

	# Tạo danh sách quái cho đợt này
	var hp_mult := get_wave_hp_mult(current_wave)
	var monster_count := get_wave_monster_count(current_wave)
	for i in monster_count:
		var m_type: Dictionary = map_monster_types[randi() % map_monster_types.size()]
		var is_elite := (current_wave >= 3) and (randf() <= (0.12 + float(current_wave) * 0.02))
		_monsters_to_spawn.append({
			"data": m_type,
			"row": randi() % GRID_ROWS,
			"is_elite": is_elite,
			"is_boss": false,
			"wave_hp_mult": hp_mult
		})

	# Đợt 10 (cuối cùng) có thêm Đại Boss cuối màn (Section 7)
	if current_wave == TOTAL_WAVES:
		var boss_type: Dictionary = map_monster_types[0].duplicate()
		boss_type["name"] = "Đại Thủ Lĩnh " + str(map_entry.get("name", "Sơn Môn"))
		boss_type["level"] = int(map_entry.get("level", 10)) + 20
		_monsters_to_spawn.append({
			"data": boss_type,
			"row": 2,  ## Hàng giữa trung tâm
			"is_elite": false,
			"is_boss": true,
			"wave_hp_mult": hp_mult
		})

func _spawn_next_monster() -> void:
	if _monsters_to_spawn.is_empty():
		return
	var info: Dictionary = _monsters_to_spawn.pop_front()
	var monster := ThuThanhMonsterScript.new()
	var hp_mult := float(info.get("wave_hp_mult", 1.0))
	monster.setup(info["data"], int(info["row"]), bool(info["is_elite"]), bool(info["is_boss"]), hp_mult)

	# Xuất hiện tại khu staging 3 cột bên phải (cols 11..13)
	var spawn_col := randi_range(DEFENSE_COLS, GRID_COLS - 1)
	var spawn_x := ORIGIN_X + spawn_col * CELL_W + CELL_W * 0.5
	var spawn_y := ORIGIN_Y + int(info["row"]) * CELL_H + CELL_H * 0.65
	monster.position = Vector2(spawn_x, spawn_y)
	monster.z_as_relative = false
	monster.z_index = -20
	monster.died.connect(_on_monster_died)

	add_child(monster)

func _on_monster_died(m: Node2D) -> void:
	if m != null:
		var m_lvl: int = int(m.get("level")) if m.get("level") != null else 10
		var is_b: bool = bool(m.get("is_boss")) if m.get("is_boss") != null else false
		var is_e: bool = bool(m.get("is_elite")) if m.get("is_elite") != null else false

		# 1. EXP Thủ Thành riêng (Zombies vs Plants):
		# Mỗi khi quái chết -> cộng EXP riêng, đủ EXP tăng 1 cấp nhận +10 điểm kỹ năng
		var tt_exp := 25 + m_lvl * 6 * (6 if is_b else (2 if is_e else 1))
		match_tt_exp_gained += tt_exp
		var res := ThuThanhSkillDataScript.add_thu_thanh_exp(tt_exp)
		if bool(res.get("leveled_up", false)):
			var new_l: int = int(res["new_level"])
			var pts: int = int(res["skill_points_gained"])
			_show_banner("🎉 CHÚC MỪNG LÊN CẤP THỦ THÀNH [Lv.%d]! NHẬN +%d ĐIỂM KỸ NĂNG! 🎉" % [new_l, pts])

		# 2. Tích luỹ EXP nhân vật để trao thưởng tổng kết duy nhất ở cuối trận
		var char_exp := m_lvl * 15 * (10 if is_b else (3 if is_e else 1))
		accumulated_char_exp += char_exp

	_update_hud_display()

func _on_wave_cleared() -> void:
	if current_wave < TOTAL_WAVES:
		wave_state = "INTERMISSION"
		_show_banner("ĐÃ HOÀN THÀNH ĐỢT %d! CHUẨN BỊ ĐỢT TIẾP THEO..." % current_wave)
		get_tree().create_timer(4.0, false).timeout.connect(func() -> void:
			if is_instance_valid(self) and wave_state != "DEFEAT":
				_start_wave(current_wave + 1)
		)
	else:
		# Đã hoàn thành đợt 5 và diệt Boss -> CHIẾN THẮNG!
		_on_victory()

func _on_victory() -> void:
	wave_state = "VICTORY"
	_show_banner("🏆 HOÀN THÀNH ẢI — CHIẾN THẮNG THỦ THÀNH XUẤT SẮC!")

	# Trao phần thưởng kinh nghiệm nhân vật duy nhất ở cuối trận
	var final_char_exp := (map_tier * 8000) + accumulated_char_exp
	var gm := _get_gm()
	var prof: PlayerProfile = gm.local_profile if (gm != null and "local_profile" in gm) else null
	if prof != null and prof.has_method("gain_exp"):
		prof.gain_exp(final_char_exp)
		var sm := _get_sm()
		if sm != null and sm.has_method("save_profile"):
			sm.save_profile(prof)

	_show_victory_popup(final_char_exp)
	finished.emit(true)

func _award_defeat_char_exp() -> int:
	var waves_cleared := maxi(0, current_wave - 1)
	var final_char_exp := (waves_cleared * map_tier * 800) + int(accumulated_char_exp * 0.5)
	var gm := _get_gm()
	var prof: PlayerProfile = gm.local_profile if (gm != null and "local_profile" in gm) else null
	if prof != null and prof.has_method("gain_exp") and final_char_exp > 0:
		prof.gain_exp(final_char_exp)
		var sm := _get_sm()
		if sm != null and sm.has_method("save_profile"):
			sm.save_profile(prof)
	return final_char_exp

func _on_cart_destroyed() -> void:
	if wave_state == "DEFEAT" or wave_state == "VICTORY":
		return
	wave_state = "DEFEAT"
	_show_banner("❌ XE TỐNG KIM ĐÃ BỊ PHÁ HỦY — THẤT BẠI!")
	var reward_exp := _award_defeat_char_exp()
	_show_defeat_popup(reward_exp)
	finished.emit(false)

# -----------------------------------------------------------------
# TƯƠNG TÁC ĐẶT HIỆP KHÁCH / XẺNG RÚT QUÂN
# -----------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if selected_card_skill_id != "" or is_shovel_mode:
				_clear_card_selection()
				get_viewport().set_input_as_handled()
				return
			_on_pause_toggle_pressed()
			get_viewport().set_input_as_handled()
			return

	if is_paused:
		return
	if wave_state != "RUNNING" and wave_state != "INTERMISSION":
		return

	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		var pos_to_use := get_local_mouse_position()
		if event is InputEventMouse:
			var spos: Vector2 = (event as InputEventMouse).position
			var sc := int((spos.x - ORIGIN_X) / CELL_W)
			var sr := int((spos.y - ORIGIN_Y) / CELL_H)
			if spos.x >= ORIGIN_X and spos.y >= ORIGIN_Y and sc >= 0 and sc < DEFENSE_COLS and sr >= 0 and sr < GRID_ROWS:
				pos_to_use = spos

		# 1. Kiểm tra nhặt đồng xu vàng nếu click gần bất kỳ đồng xu nào (khoảng cách <= 45px)
		var coins = get_tree().get_nodes_in_group("thu_thanh_coins")
		for c in coins:
			if is_instance_valid(c) and c.has_method("collect"):
				if c.position.distance_to(pos_to_use) <= 45.0:
					c.collect()
					return

		# 2. Chỉ xử lý đặt quân nếu click nằm trong phạm vi bàn cờ (tránh chạm vào thanh top bar hoặc bottom card bar)
		if pos_to_use.y > 60.0 and pos_to_use.y < 620.0:
			var col := int((pos_to_use.x - ORIGIN_X) / CELL_W)
			var row := int((pos_to_use.y - ORIGIN_Y) / CELL_H)
			if pos_to_use.x >= ORIGIN_X and pos_to_use.y >= ORIGIN_Y and col >= 0 and col < DEFENSE_COLS and row >= 0 and row < GRID_ROWS:
				_handle_cell_click(row, col)

func _on_coin_spawned(coin: Node2D) -> void:
	if coin != null and is_instance_valid(coin) and coin.has_signal("collected"):
		if not coin.collected.is_connected(_on_coin_collected):
			coin.collected.connect(_on_coin_collected)

func _on_coin_collected(amount: int) -> void:
	current_coins += amount
	_update_hud_display()
	_show_banner("+%d Xu!" % amount)

func _update_hover_grid() -> void:
	var mpos := get_local_mouse_position()
	var col := int((mpos.x - ORIGIN_X) / CELL_W)
	var row := int((mpos.y - ORIGIN_Y) / CELL_H)

	if mpos.x >= ORIGIN_X and mpos.y >= ORIGIN_Y and col >= 0 and col < DEFENSE_COLS and row >= 0 and row < GRID_ROWS:
		_hover_row = row
		_hover_col = col
		_hover_rect.position = Vector2(ORIGIN_X + col * CELL_W, ORIGIN_Y + row * CELL_H)
		_hover_rect.visible = selected_card_skill_id != "" or is_shovel_mode

		if is_shovel_mode:
			_hover_rect.color = Color(1.0, 0.3, 0.3, 0.45)
		elif _grid_units[row][col] != null:
			_hover_rect.color = Color(1.0, 0.2, 0.2, 0.45)  ## Ô đã có người
		else:
			_hover_rect.color = Color(0.25, 0.95, 0.3, 0.45)  ## Ô hợp lệ
	else:
		_hover_row = -1
		_hover_col = -1
		_hover_rect.visible = false

func _handle_cell_click(row: int, col: int) -> void:
	# 1. Chế độ Rút Quân (Xẻng Shovel)
	if is_shovel_mode:
		var existing = _grid_units[row][col]
		if existing != null and is_instance_valid(existing):
			_grid_units[row][col] = null
			existing.die()
			is_shovel_mode = false
			_shovel_btn.modulate = Color.WHITE
			_show_banner("✅ Đã rút quân khỏi ô hàng %d cột %d!" % [row + 1, col + 1])
		else:
			_show_banner("⚠️ Ô này không có Hiệp Khách nào để rút quân!")
		return

	# 2. Đặt Hiệp Khách từ thẻ bài đã chọn
	if selected_card_skill_id == "":
		if _grid_units[row][col] != null:
			var existing = _grid_units[row][col]
			_show_banner("🛡️ %s đang phòng thủ ô này!" % existing.name)
		else:
			_show_banner("👉 Hãy bấm chọn một thẻ Hiệp Khách ở thanh phía dưới trước khi đặt lên ô đất!")
		return

	if _grid_units[row][col] != null:
		_show_banner("⚠️ Ô này đã có Hiệp Khách đang phòng thủ!")
		return  ## Ô đã có người

	var s := ThuThanhSkillDataScript.get_skill(selected_card_skill_id)
	var cost := int(s.get("cost", 50))
	if current_coins < cost:
		_show_banner("⚠️ Không đủ Xu (%d/%d Xu) để triệu hồi Hiệp Khách này!" % [current_coins, cost])
		return  ## Không đủ Xu

	# Trừ Xu và kích hoạt hồi chiêu thẻ
	current_coins -= cost
	_cooldowns[selected_card_skill_id] = float(s.get("cooldown", 10.0))

	# Triệu hồi Hiệp Khách lên ô bàn cờ
	var unit := ThuThanhUnitScript.new()
	unit.setup(s, row, col)
	var cur_lvl: int = skill_levels.get(selected_card_skill_id, 1)
	if unit.has_method("set_skill_level"):
		unit.set_skill_level(cur_lvl)
	unit.position = Vector2(ORIGIN_X + col * CELL_W + CELL_W * 0.5, ORIGIN_Y + row * CELL_H + CELL_H * 0.65)
	unit.z_as_relative = false
	unit.z_index = -15
	var u_row := row
	var u_col := col
	unit.died.connect(func(_u: Node2D) -> void:
		if u_row >= 0 and u_row < GRID_ROWS and u_col >= 0 and u_col < DEFENSE_COLS:
			if _grid_units[u_row][u_col] == unit:
				_grid_units[u_row][u_col] = null
	)

	_grid_units[row][col] = unit
	add_child(unit)

	var hero_name := str(s.get("sect", s.get("name", "Hiệp Khách")))
	_show_banner("⚡ Xuất trận thành công: Hiệp Khách %s phòng thủ hàng %d!" % [hero_name, row + 1])

	# Bỏ chọn thẻ sau khi đặt
	selected_card_skill_id = ""
	_clear_card_selection()
	_update_hud_display()

# -----------------------------------------------------------------
# GIAO DIỆN NGƯỜI DÙNG (HUD TRẬN ĐẤU)
# -----------------------------------------------------------------
func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 50
	_hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud_layer)

	# TOP BAR (Thông tin Ải, Máu Xe, Đợt, Xu, Nút Thoát)
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.custom_minimum_size.y = 44.0
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color(0.12, 0.1, 0.08, 0.92)
	top_sb.border_width_bottom = 2
	top_sb.border_color = Color(0.35, 0.28, 0.2)
	top_sb.content_margin_top = 4.0
	top_sb.content_margin_bottom = 4.0
	top_sb.content_margin_left = 18.0
	top_sb.content_margin_right = 24.0
	top_panel.add_theme_stylebox_override("panel", top_sb)
	_hud_layer.add_child(top_panel)

	var top_box := HBoxContainer.new()
	top_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top_box.add_theme_constant_override("separation", 16)
	top_panel.add_child(top_box)

	# Tên bản đồ & ải
	_map_name_lbl = Label.new()
	_map_name_lbl.text = "ẢI %dx — %s" % [map_tier, str(map_entry.get("name", "Thủ Thành JX1"))]
	_map_name_lbl.add_theme_font_size_override("font_size", 15)
	_map_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_map_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_box.add_child(_map_name_lbl)

	# Thanh HP Xe Tống Kim
	var cart_vbox := VBoxContainer.new()
	cart_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cart_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cart_vbox.add_theme_constant_override("separation", 2)
	top_box.add_child(cart_vbox)

	_cart_hp_lbl = Label.new()
	_cart_hp_lbl.text = "Xe Tống Kim: 5/5 chiếc"
	_cart_hp_lbl.add_theme_font_size_override("font_size", 10)
	_cart_hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	cart_vbox.add_child(_cart_hp_lbl)

	_cart_hp_bar = ProgressBar.new()
	_cart_hp_bar.custom_minimum_size = Vector2(140, 8)
	_cart_hp_bar.min_value = 0
	_cart_hp_bar.max_value = 5
	_cart_hp_bar.value = 5
	_cart_hp_bar.show_percentage = false
	var cfill := StyleBoxFlat.new()
	cfill.bg_color = Color(0.9, 0.2, 0.2)
	cfill.corner_radius_top_left = 2
	cfill.corner_radius_top_right = 2
	cfill.corner_radius_bottom_left = 2
	cfill.corner_radius_bottom_right = 2
	_cart_hp_bar.add_theme_stylebox_override("fill", cfill)
	cart_vbox.add_child(_cart_hp_bar)

	# Đợt quái
	_wave_lbl = Label.new()
	_wave_lbl.text = "Đợt: 1/%d" % TOTAL_WAVES
	_wave_lbl.add_theme_font_size_override("font_size", 14)
	_wave_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_wave_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_box.add_child(_wave_lbl)

	# Khung Cấp Độ & EXP riêng của chế độ Thủ Thành (Zombies vs Plants)
	var tt_lvl_box := VBoxContainer.new()
	tt_lvl_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tt_lvl_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tt_lvl_box.add_theme_constant_override("separation", 2)
	top_box.add_child(tt_lvl_box)

	_tt_lvl_lbl = Label.new()
	_tt_lvl_lbl.text = "🎖️ Cấp PvZ: %d" % ThuThanhSkillDataScript.get_thu_thanh_level()
	_tt_lvl_lbl.add_theme_font_size_override("font_size", 10)
	_tt_lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	tt_lvl_box.add_child(_tt_lvl_lbl)

	_tt_exp_bar = ProgressBar.new()
	_tt_exp_bar.custom_minimum_size = Vector2(100, 6)
	_tt_exp_bar.show_percentage = false
	var exp_sb := StyleBoxFlat.new()
	exp_sb.bg_color = Color(0.2, 0.7, 1.0)
	exp_sb.corner_radius_top_left = 3
	exp_sb.corner_radius_top_right = 3
	exp_sb.corner_radius_bottom_left = 3
	exp_sb.corner_radius_bottom_right = 3
	_tt_exp_bar.add_theme_stylebox_override("fill", exp_sb)
	tt_lvl_box.add_child(_tt_exp_bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_box.add_child(spacer)

	# Khung Xu hiện tại (Tham chiếu hình 1: 💰 125 Xu)
	var coin_box := HBoxContainer.new()
	coin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_box.add_theme_constant_override("separation", 6)
	top_box.add_child(coin_box)

	var c_ico := TextureRect.new()
	var c_ico_path := "res://assets/ui/bo_icon_nhan_vat/tai_nguyen/ico_vang.png"
	if ResourceLoader.exists(c_ico_path):
		c_ico.texture = load(c_ico_path)
	c_ico.custom_minimum_size = Vector2(24, 24)
	c_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_box.add_child(c_ico)

	_coin_lbl = Label.new()
	_coin_lbl.text = "%d" % current_coins
	_coin_lbl.add_theme_font_size_override("font_size", 16)
	_coin_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	_coin_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_coin_lbl.add_theme_constant_override("outline_size", 2)
	_coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_box.add_child(_coin_lbl)

	# Nút Tốc Độ Trận Đấu (1x -> 2x -> 4x)
	_speed_btn = Button.new()
	_speed_btn.custom_minimum_size = Vector2(68, 28)
	_speed_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_update_speed_button()
	_speed_btn.pressed.connect(_toggle_speed)

	var speed_sc := Shortcut.new()
	var ev_t := InputEventKey.new()
	ev_t.keycode = KEY_T
	speed_sc.events = [ev_t]
	_speed_btn.shortcut = speed_sc

	top_box.add_child(_speed_btn)

	# Nút Tạm Dừng / Tiếp Tục
	_pause_btn = Button.new()
	_pause_btn.text = "⏸ Dừng"
	_pause_btn.custom_minimum_size = Vector2(72, 28)
	_pause_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pause_btn.tooltip_text = "Tạm dừng trận đấu (Phím Space / P)"
	_pause_btn.add_theme_font_size_override("font_size", 12)
	var pause_sb := StyleBoxFlat.new()
	pause_sb.bg_color = Color(0.18, 0.25, 0.35, 0.95)
	pause_sb.border_width_left = 1
	pause_sb.border_width_top = 1
	pause_sb.border_width_right = 1
	pause_sb.border_width_bottom = 1
	pause_sb.border_color = Color(0.4, 0.65, 0.9)
	pause_sb.corner_radius_top_left = 4
	pause_sb.corner_radius_top_right = 4
	pause_sb.corner_radius_bottom_left = 4
	pause_sb.corner_radius_bottom_right = 4
	pause_sb.content_margin_left = 6
	pause_sb.content_margin_right = 6
	pause_sb.content_margin_top = 2
	pause_sb.content_margin_bottom = 2
	_pause_btn.add_theme_stylebox_override("normal", pause_sb)
	_pause_btn.pressed.connect(_on_pause_toggle_pressed)

	var sc := Shortcut.new()
	var ev_space := InputEventKey.new()
	ev_space.keycode = KEY_SPACE
	var ev_p := InputEventKey.new()
	ev_p.keycode = KEY_P
	sc.events = [ev_space, ev_p]
	_pause_btn.shortcut = sc

	top_box.add_child(_pause_btn)

	# Nút Thoát (Cách lề phải an toàn và gọn gàng)
	var exit_btn := Button.new()
	exit_btn.text = "Rời Ải"
	exit_btn.custom_minimum_size = Vector2(68, 28)
	exit_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exit_btn.add_theme_font_size_override("font_size", 12)
	var exit_sb := StyleBoxFlat.new()
	exit_sb.bg_color = Color(0.38, 0.16, 0.16, 0.95)
	exit_sb.border_width_left = 1
	exit_sb.border_width_top = 1
	exit_sb.border_width_right = 1
	exit_sb.border_width_bottom = 1
	exit_sb.border_color = Color(0.75, 0.35, 0.35)
	exit_sb.corner_radius_top_left = 4
	exit_sb.corner_radius_top_right = 4
	exit_sb.corner_radius_bottom_left = 4
	exit_sb.corner_radius_bottom_right = 4
	exit_sb.content_margin_left = 6
	exit_sb.content_margin_right = 6
	exit_sb.content_margin_top = 2
	exit_sb.content_margin_bottom = 2
	exit_btn.add_theme_stylebox_override("normal", exit_sb)
	exit_btn.pressed.connect(_on_exit_pressed)
	top_box.add_child(exit_btn)

	# -------------------------------------------------------------
	# BOTTOM BAR: THANH KỸ NĂNG ĐÃ CHỌN & NÚT RÚT QUÂN (CHỦ ĐỀ KIẾM HIỆP VLTK)
	# -------------------------------------------------------------
	var bot_panel := PanelContainer.new()
	bot_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bot_panel.offset_top = -96.0
	bot_panel.offset_bottom = 0.0
	bot_panel.custom_minimum_size.y = 96.0
	var bot_sb := StyleBoxFlat.new()
	bot_sb.bg_color = Color(0.06, 0.05, 0.04, 0.98)  ## Tông gỗ mun huyền thạch VLTK
	bot_sb.border_width_top = 3
	bot_sb.border_color = Color(0.82, 0.66, 0.28, 0.95)  ## Viền mạ vàng hoàng kim
	bot_panel.add_theme_stylebox_override("panel", bot_sb)

	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0.04, 0.03, 0.02, 0.98)
	tip_sb.border_width_left = 2
	tip_sb.border_width_top = 2
	tip_sb.border_width_right = 2
	tip_sb.border_width_bottom = 2
	tip_sb.border_color = Color(0.85, 0.70, 0.30, 0.98)
	tip_sb.set_content_margin_all(10)
	tip_sb.corner_radius_top_left = 6
	tip_sb.corner_radius_top_right = 6
	tip_sb.corner_radius_bottom_left = 6
	tip_sb.corner_radius_bottom_right = 6
	tip_sb.shadow_color = Color(0, 0, 0, 0.7)
	tip_sb.shadow_size = 4

	var hud_theme := Theme.new()
	hud_theme.set_stylebox("panel", "TooltipPanel", tip_sb)
	hud_theme.set_color("font_color", "TooltipLabel", Color(1.0, 0.95, 0.85))
	hud_theme.set_color("font_shadow_color", "TooltipLabel", Color.BLACK)
	hud_theme.set_constant("shadow_offset_x", "TooltipLabel", 1)
	hud_theme.set_constant("shadow_offset_y", "TooltipLabel", 1)
	hud_theme.set_font_size("font_size", "TooltipLabel", 13)
	bot_panel.theme = hud_theme

	_hud_layer.add_child(bot_panel)

	_bot_box = HBoxContainer.new()
	_bot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_bot_box.add_theme_constant_override("separation", 8)
	bot_panel.add_child(_bot_box)

	# Banner thông báo đợt / cảnh báo lớn giữa màn hình
	_banner_lbl = Label.new()
	_banner_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_lbl.size = Vector2(700, 60)
	_banner_lbl.position = Vector2(290, 260)
	_banner_lbl.add_theme_font_size_override("font_size", 22)
	_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_banner_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_lbl.add_theme_constant_override("outline_size", 4)
	_banner_lbl.visible = false
	_hud_layer.add_child(_banner_lbl)

	_refresh_hud_cards()
	_build_pause_overlay()

func _refresh_hud_cards() -> void:
	if _bot_box == null:
		return

	# Dọn các control cũ trong _bot_box
	for c in _bot_box.get_children():
		c.queue_free()

	_card_buttons.clear()
	_card_cooldown_masks.clear()
	_card_cooldown_labels.clear()
	_card_level_labels.clear()

	# Hiển thị các thẻ bài kỹ năng đã chọn đem vào trận
	# Mỗi slot gồm: Thẻ Kỹ Năng gọn gàng (Icon + Tên chiêu + Cấp Lv.X + Giá Xu) với nút [+] tinh tế ở góc phải trên
	for i in equipped_skills.size():
		var sid := equipped_skills[i]
		var s := ThuThanhSkillDataScript.get_skill(sid)
		var cost := int(s.get("cost", 50))
		var sect_name := str(s.get("sect", s.get("name", "Hiệp Khách")))
		var skill_name := str(s.get("skill_name", ""))
		var cur_lvl: int = skill_levels.get(sid, 1)

		# Khung nhóm của slot: Control chứa Thẻ Bài + Nút [+] tinh tế ở góc phải trên
		var slot_card := Control.new()
		slot_card.custom_minimum_size = Vector2(88, 88)
		_bot_box.add_child(slot_card)

		# Thẻ bài kỹ năng
		var btn := Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.clip_contents = true

		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color(0.08, 0.07, 0.06, 0.98)  ## Tông đen mun kiếm hiệp sâu thẳm
		b_sb.border_width_left = 1
		b_sb.border_width_top = 1
		b_sb.border_width_right = 1
		b_sb.border_width_bottom = 1
		b_sb.border_color = Color(0.55, 0.42, 0.22, 0.9)  ## Đồng vàng cổ điển
		b_sb.corner_radius_top_left = 4
		b_sb.corner_radius_top_right = 4
		b_sb.corner_radius_bottom_left = 4
		b_sb.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", b_sb)

		var b_sb_hover := StyleBoxFlat.new()
		b_sb_hover.bg_color = Color(0.14, 0.11, 0.08, 0.98)
		b_sb_hover.border_width_left = 2
		b_sb_hover.border_width_top = 2
		b_sb_hover.border_width_right = 2
		b_sb_hover.border_width_bottom = 2
		b_sb_hover.border_color = Color(0.95, 0.82, 0.35, 1.0)
		b_sb_hover.corner_radius_top_left = 4
		b_sb_hover.corner_radius_top_right = 4
		b_sb_hover.corner_radius_bottom_left = 4
		b_sb_hover.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("hover", b_sb_hover)

		# VBox nội dung (Icon Kỹ Năng + Tên chiêu + Cấp độ + Giá Xu)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 1)
		vb.offset_left = 2
		vb.offset_right = -2
		vb.offset_top = 2
		vb.offset_bottom = -2
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vb)

		# Icon kỹ năng chuẩn VLTK
		var icon_tex := TextureRect.new()
		icon_tex.texture = ThuThanhSkillData.get_skill_icon_texture(s)
		icon_tex.custom_minimum_size = Vector2(36, 36)
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vb.add_child(icon_tex)

		# Tên chiêu / môn phái (Tự co chữ nếu tên dài để không bị cắt xén)
		var s_skill := Label.new()
		var disp_name: String = skill_name if skill_name != "" else sect_name
		s_skill.text = disp_name
		s_skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if disp_name.length() > 14:
			s_skill.add_theme_font_size_override("font_size", 8)
		else:
			s_skill.add_theme_font_size_override("font_size", 9)
		s_skill.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		s_skill.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vb.add_child(s_skill)

		# Dòng cấp độ và giá Xu
		var info_hb := HBoxContainer.new()
		info_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		info_hb.add_theme_constant_override("separation", 4)
		vb.add_child(info_hb)

		var s_lvl := Label.new()
		var max_lvl := ThuThanhSkillDataScript.get_max_skill_level(sid)
		if cur_lvl >= max_lvl:
			s_lvl.text = "MAX"
			s_lvl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		else:
			s_lvl.text = "Lv.%d" % cur_lvl
			s_lvl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.4))
		s_lvl.add_theme_font_size_override("font_size", 9)
		s_lvl.add_theme_color_override("font_outline_color", Color.BLACK)
		s_lvl.add_theme_constant_override("outline_size", 1)
		info_hb.add_child(s_lvl)
		_card_level_labels.append(s_lvl)

		var s_cost := Label.new()
		s_cost.text = "%d Xu" % cost
		s_cost.add_theme_font_size_override("font_size", 9)
		s_cost.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25))
		s_cost.add_theme_color_override("font_outline_color", Color.BLACK)
		s_cost.add_theme_constant_override("outline_size", 1)
		info_hb.add_child(s_cost)

		var scaling: Dictionary = ThuThanhSkillDataScript.get_skill_scaling(sid, cur_lvl)
		var base_dmg := float(s.get("damage", 40.0))
		var real_dmg := base_dmg * float(scaling.get("damage_mult", 1.0))
		var proj_type: String = str(s.get("projectile_type", ""))
		var shots: int = int(s.get("shots_per_attack", 1)) + int(scaling.get("extra_shots", 0))
		var elem_str := str(s.get("element", "Hỏa"))

		var tt := "【%s — %s】\n" % [sect_name, skill_name]
		tt += "• Ngũ Hành: %s · Cấp Độ: %s\n" % [elem_str, "Lv.%d (MAX)" % cur_lvl if cur_lvl >= max_lvl else "Lv.%d/%d" % [cur_lvl, max_lvl]]
		tt += "• Sát Thương: %.1f (+%d%% uy lực)\n" % [real_dmg, int((float(scaling.get("damage_mult", 1.0)) - 1.0) * 100)]
		if proj_type == "dragon":
			tt += "• Xuất Chiêu: Phóng %d Con Rồng Lửa bay uốn lượn dí mục tiêu\n" % shots
		elif shots > 1:
			tt += "• Xuất Chiêu: Bắn liên hoàn %d phát đạn càn quét\n" % shots
		tt += "• Tốc Độ Ra Đòn: %.1fs/lần · Bán Kính Nổ Lan: %dpx\n" % [float(s.get("attack_speed", 1.2)), int(float(s.get("aoe_radius", 75.0)) * float(scaling.get("aoe_mult", 1.0)))]
		tt += "• Chi Phí: %d Xu · Thời Gian Hồi: %.1fs\n" % [cost, float(s.get("cooldown", 10.0))]
		if str(scaling.get("special_desc", "")) != "":
			tt += "• Trấn Phái: %s\n" % str(scaling.get("special_desc", ""))
		tt += "• Mô Tả: %s" % str(s.get("desc", ""))
		btn.tooltip_text = tt

		# Lớp phủ đen hồi chiêu
		var mask := ColorRect.new()
		mask.color = Color(0, 0, 0, 0.68)
		mask.set_anchors_preset(Control.PRESET_FULL_RECT)
		mask.visible = false
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(mask)

		# Nhãn đếm ngược giây hồi chiêu trên góc thẻ
		var cd_lbl := Label.new()
		cd_lbl.text = ""
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cd_lbl.size = Vector2(30, 16)
		cd_lbl.position = Vector2(54, 2)
		cd_lbl.add_theme_font_size_override("font_size", 10)
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		cd_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cd_lbl.add_theme_constant_override("outline_size", 2)
		cd_lbl.visible = false
		btn.add_child(cd_lbl)

		var card_idx := i
		btn.pressed.connect(func() -> void: _on_card_clicked(card_idx))
		slot_card.add_child(btn)

		_card_buttons.append(btn)
		_card_cooldown_masks.append(mask)
		_card_cooldown_labels.append(cd_lbl)

	# Nút Rút Quân (Xẻng Shovel - Lệnh bài đỏ cẩm thạch VLTK)
	_shovel_btn = Button.new()
	_shovel_btn.text = "Rút quân\n(Xẻng)"
	_shovel_btn.custom_minimum_size = Vector2(80, 88)
	var sh_sb := StyleBoxFlat.new()
	sh_sb.bg_color = Color(0.28, 0.09, 0.09, 0.96)  ## Đỏ cẩm thạch lệnh bài kiếm hiệp
	sh_sb.border_width_left = 2
	sh_sb.border_width_top = 2
	sh_sb.border_width_right = 2
	sh_sb.border_width_bottom = 2
	sh_sb.border_color = Color(0.85, 0.68, 0.28, 0.95)  ## Viền mạ vàng lệnh bài
	sh_sb.corner_radius_top_left = 4
	sh_sb.corner_radius_top_right = 4
	sh_sb.corner_radius_bottom_left = 4
	sh_sb.corner_radius_bottom_right = 4
	_shovel_btn.add_theme_stylebox_override("normal", sh_sb)
	_shovel_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.8))
	_shovel_btn.add_theme_color_override("font_outline_color", Color.BLACK)
	_shovel_btn.add_theme_constant_override("outline_size", 2)
	_shovel_btn.pressed.connect(_on_shovel_clicked)
	_bot_box.add_child(_shovel_btn)

func _build_pause_overlay() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_layer.add_child(_pause_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 240)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.08, 0.98)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.68, 0.3)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "⏸ TRẬN ĐẤU ĐANG TẠM DỪNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	vb.add_child(title)

	var sub_lbl := Label.new()
	sub_lbl.text = "Toàn bộ chiến trường đã được đóng băng tạm thời.\nĐại hiệp có thể tiếp tục hoặc rời ải."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	vb.add_child(sub_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vb.add_child(btn_row)

	var resume_btn := Button.new()
	resume_btn.name = "ResumeButton"
	resume_btn.text = "▶ Tiếp Tục"
	resume_btn.custom_minimum_size = Vector2(130, 42)
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color(0.2, 0.58, 0.28)
	r_sb.border_width_left = 1
	r_sb.border_width_top = 1
	r_sb.border_width_right = 1
	r_sb.border_width_bottom = 1
	r_sb.border_color = Color(0.4, 0.85, 0.45)
	r_sb.corner_radius_top_left = 6
	r_sb.corner_radius_top_right = 6
	r_sb.corner_radius_bottom_left = 6
	r_sb.corner_radius_bottom_right = 6
	resume_btn.add_theme_stylebox_override("normal", r_sb)
	resume_btn.add_theme_font_size_override("font_size", 15)
	resume_btn.pressed.connect(func() -> void: _toggle_pause(false))

	# Phím tắt Space / ESC để tiếp tục khi đang pause
	var resume_shortcut := Shortcut.new()
	var esc_ev := InputEventKey.new()
	esc_ev.keycode = KEY_ESCAPE
	var space_ev := InputEventKey.new()
	space_ev.keycode = KEY_SPACE
	resume_shortcut.events = [esc_ev, space_ev]
	resume_btn.shortcut = resume_shortcut
	btn_row.add_child(resume_btn)

	var quit_btn := Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "⬅ Rời Ải"
	quit_btn.custom_minimum_size = Vector2(130, 42)
	var q_sb := StyleBoxFlat.new()
	q_sb.bg_color = Color(0.5, 0.2, 0.2)
	q_sb.border_width_left = 1
	q_sb.border_width_top = 1
	q_sb.border_width_right = 1
	q_sb.border_width_bottom = 1
	q_sb.border_color = Color(0.8, 0.35, 0.35)
	q_sb.corner_radius_top_left = 6
	q_sb.corner_radius_top_right = 6
	q_sb.corner_radius_bottom_left = 6
	q_sb.corner_radius_bottom_right = 6
	quit_btn.add_theme_stylebox_override("normal", q_sb)
	quit_btn.add_theme_font_size_override("font_size", 15)
	quit_btn.pressed.connect(_on_exit_pressed)
	btn_row.add_child(quit_btn)

func _on_pause_toggle_pressed() -> void:
	_toggle_pause(not is_paused)

func _toggle_pause(p_paused: bool) -> void:
	if wave_state != "RUNNING" and wave_state != "INTERMISSION":
		return
	is_paused = p_paused
	if get_tree() != null:
		get_tree().paused = is_paused

	if VltkWorld.current != null:
		VltkWorld.current.process_mode = Node.PROCESS_MODE_PAUSABLE if is_paused else Node.PROCESS_MODE_INHERIT

	if _pause_btn != null:
		if is_paused:
			_pause_btn.text = "▶ Tiếp Tục"
			_pause_btn.modulate = Color(1.3, 1.3, 0.4)
		else:
			_pause_btn.text = "⏸ Dừng"
			_pause_btn.modulate = Color.WHITE

	if _pause_overlay != null:
		_pause_overlay.visible = is_paused
		if is_paused:
			var res_btn = _pause_overlay.find_child("ResumeButton", true, false) as Button
			if res_btn != null:
				res_btn.grab_focus()

func _toggle_speed() -> void:
	current_speed_idx = (current_speed_idx + 1) % SPEED_STEPS.size()
	var mult: float = SPEED_STEPS[current_speed_idx]
	Engine.time_scale = mult
	_update_speed_button()
	_show_banner("⚡ TỐC ĐỘ TRẬN ĐẤU: %s (Hệ số x%.1f)" % [SPEED_LABELS[current_speed_idx], mult])

func _update_speed_button() -> void:
	if _speed_btn == null:
		return
	_speed_btn.text = SPEED_LABELS[current_speed_idx]
	_speed_btn.tooltip_text = "Tốc độ trận đấu: %s (Bấm để tăng tốc 1x -> 2x -> 4x, Phím T)" % SPEED_LABELS[current_speed_idx]
	var sb := StyleBoxFlat.new()
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	if current_speed_idx == 0:
		sb.bg_color = Color(0.18, 0.22, 0.28, 0.95)
		sb.border_color = Color(0.4, 0.55, 0.7)
	elif current_speed_idx == 1:
		sb.bg_color = Color(0.12, 0.32, 0.22, 0.95)
		sb.border_color = Color(0.35, 0.9, 0.6)
	else:
		sb.bg_color = Color(0.38, 0.2, 0.08, 0.95)
		sb.border_color = Color(1.0, 0.75, 0.25)
	_speed_btn.add_theme_stylebox_override("normal", sb)
	_speed_btn.add_theme_color_override("font_color", SPEED_COLORS[current_speed_idx])
	_speed_btn.add_theme_font_size_override("font_size", 12)

func _on_card_clicked(idx: int) -> void:
	if idx >= equipped_skills.size():
		return
	var sid := equipped_skills[idx]
	var cd := float(_cooldowns.get(sid, 0.0))
	if cd > 0.0:
		_show_banner("⏳ Hiệp Khách này đang trong thời gian hồi chiêu (còn %.1fs)!" % cd)
		return
	var s := ThuThanhSkillDataScript.get_skill(sid)
	var cost := int(s.get("cost", 50))
	if current_coins < cost:
		_show_banner("⚠️ Không đủ Xu (%d/%d Xu) để triệu hồi Hiệp Khách này!" % [current_coins, cost])
		return

	is_shovel_mode = false
	_shovel_btn.modulate = Color.WHITE

	if selected_card_skill_id == sid:
		selected_card_skill_id = ""
		_clear_card_selection()
		_show_banner("Đã hủy chọn Hiệp Khách.")
	else:
		selected_card_skill_id = sid
		_highlight_selected_card(idx)
		var hero_name := str(s.get("sect", s.get("name", "Hiệp Khách")))
		_show_banner("👉 Đã chọn: Hiệp Khách %s (%d Xu) — Bấm vào ô trên sân cỏ để triệu hồi!" % [hero_name, cost])

func _highlight_selected_card(idx: int) -> void:
	for i in _card_buttons.size():
		if i == idx:
			_card_buttons[i].modulate = Color(1.3, 1.3, 0.7)
		else:
			_card_buttons[i].modulate = Color.WHITE

func _clear_card_selection() -> void:
	for btn in _card_buttons:
		btn.modulate = Color.WHITE

func _on_shovel_clicked() -> void:
	is_shovel_mode = not is_shovel_mode
	selected_card_skill_id = ""
	_clear_card_selection()
	_shovel_btn.modulate = Color(1.5, 0.8, 0.8) if is_shovel_mode else Color.WHITE

func _update_hud_display() -> void:
	if _coin_lbl != null:
		_coin_lbl.text = "%d" % current_coins
	if _cart_hp_bar != null and _cart_hp_lbl != null:
		var active_carts := 0
		for b in _cart_available:
			if b:
				active_carts += 1
		_cart_hp_bar.max_value = 5
		_cart_hp_bar.value = active_carts
		_cart_hp_lbl.text = "Xe Tống Kim: %d/5 chiếc" % active_carts
	if _wave_lbl != null:
		_wave_lbl.text = "Đợt: %d/%d" % [current_wave, TOTAL_WAVES]
	if _tt_lvl_lbl != null and _tt_exp_bar != null:
		var cur_l := ThuThanhSkillDataScript.get_thu_thanh_level()
		var cur_x := ThuThanhSkillDataScript.get_thu_thanh_exp()
		var max_x := ThuThanhSkillDataScript.get_exp_to_next_level(cur_l)
		_tt_lvl_lbl.text = "🎖️ Cấp PvZ: %d" % cur_l
		_tt_exp_bar.max_value = max_x
		_tt_exp_bar.value = cur_x

func _show_banner(text: String) -> void:
	if _banner_lbl == null:
		return
	_banner_lbl.text = text
	_banner_lbl.visible = true
	_banner_lbl.modulate.a = 1.0
	_banner_timer = 3.5

# -----------------------------------------------------------------
# THẮNG / THUA VÀ KẾT THÚC
# -----------------------------------------------------------------
func _show_victory_popup(char_exp_won: int = 0) -> void:
	Engine.time_scale = 1.0
	if is_paused:
		_toggle_pause(false)
	if _pause_btn != null:
		_pause_btn.disabled = true
	if _speed_btn != null:
		_speed_btn.disabled = true

	var modal := ColorRect.new()
	modal.name = "VictoryModal"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.color = Color(0.0, 0.0, 0.0, 0.75)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_layer.add_child(modal)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var pop := PanelContainer.new()
	pop.custom_minimum_size = Vector2(480, 290)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.16, 0.14, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.3, 0.8, 0.4)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	pop.add_theme_stylebox_override("panel", sb)
	center.add_child(pop)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	pop.add_child(vb)

	var tit := Label.new()
	tit.text = "🎉 CHIẾN THẮNG THỦ THÀNH! 🎉"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 20)
	tit.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vb.add_child(tit)

	var cur_tt_lvl := ThuThanhSkillDataScript.get_thu_thanh_level()
	var cur_tt_exp := ThuThanhSkillDataScript.get_thu_thanh_exp()
	var max_tt_exp := ThuThanhSkillDataScript.get_exp_to_next_level(cur_tt_lvl)
	var pts := ThuThanhSkillDataScript.get_skill_points()

	var msg := Label.new()
	var msg_txt := "Đã bảo vệ thành công Xe Tống Kim qua đủ %d đợt quái!\n" % TOTAL_WAVES
	msg_txt += "• Phần thưởng cuối trận: +%d EXP Nhân Vật\n" % char_exp_won
	msg_txt += "• Cấp Độ Thủ Thành (PvZ): Lv.%d (EXP: %d/%d)\n" % [cur_tt_lvl, cur_tt_exp, max_tt_exp]
	msg_txt += "• Điểm Kỹ Năng Thủ Thành hiện có: %d điểm" % pts
	msg.text = msg_txt
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 13)
	msg.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	vb.add_child(msg)

	var ret_btn := Button.new()
	ret_btn.text = "Rời Trận / Trở Về Sảnh"
	ret_btn.custom_minimum_size = Vector2(200, 42)
	ret_btn.pressed.connect(_on_exit_pressed)
	vb.add_child(ret_btn)

func _show_defeat_popup(char_exp_won: int = 0) -> void:
	Engine.time_scale = 1.0
	if is_paused:
		_toggle_pause(false)
	if _pause_btn != null:
		_pause_btn.disabled = true
	if _speed_btn != null:
		_speed_btn.disabled = true

	var modal := ColorRect.new()
	modal.name = "DefeatModal"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.color = Color(0.0, 0.0, 0.0, 0.75)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_layer.add_child(modal)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var pop := PanelContainer.new()
	pop.custom_minimum_size = Vector2(480, 290)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.1, 0.1, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.85, 0.25, 0.25)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	pop.add_theme_stylebox_override("panel", sb)
	center.add_child(pop)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	pop.add_child(vb)

	var tit := Label.new()
	tit.text = "☠ THẤT BẠI THỦ THÀNH ☠"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 20)
	tit.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	vb.add_child(tit)

	var cur_tt_lvl := ThuThanhSkillDataScript.get_thu_thanh_level()
	var cur_tt_exp := ThuThanhSkillDataScript.get_thu_thanh_exp()
	var max_tt_exp := ThuThanhSkillDataScript.get_exp_to_next_level(cur_tt_lvl)
	var pts := ThuThanhSkillDataScript.get_skill_points()

	var msg := Label.new()
	var msg_txt := "Quân địch đã phá vỡ phòng tuyến!\n"
	if char_exp_won > 0:
		msg_txt += "• Thưởng an ủi cuối trận: +%d EXP Nhân Vật\n" % char_exp_won
	msg_txt += "• Cấp Độ Thủ Thành (PvZ): Lv.%d (EXP: %d/%d)\n" % [cur_tt_lvl, cur_tt_exp, max_tt_exp]
	msg_txt += "• Điểm Kỹ Năng Thủ Thành hiện có: %d điểm" % pts
	msg.text = msg_txt
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 13)
	msg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	vb.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vb.add_child(btn_row)

	var retry_btn := Button.new()
	retry_btn.text = "Chơi Lại"
	retry_btn.custom_minimum_size = Vector2(130, 40)
	retry_btn.pressed.connect(func() -> void:
		Engine.time_scale = 1.0
		if get_tree() != null:
			get_tree().paused = false
		is_paused = false
		get_tree().reload_current_scene()
	)
	btn_row.add_child(retry_btn)

	var ret_btn := Button.new()
	ret_btn.text = "Trở Về"
	ret_btn.custom_minimum_size = Vector2(130, 40)
	ret_btn.pressed.connect(_on_exit_pressed)
	btn_row.add_child(ret_btn)

func _on_exit_pressed() -> void:
	Engine.time_scale = 1.0
	if get_tree() != null:
		get_tree().paused = false
	is_paused = false
	if has_node("/root/SceneTransition"):
		get_node("/root/SceneTransition").change_scene("res://ui/character_hub/CharacterHub.tscn", "Sảnh Chính")
	else:
		get_tree().change_scene_to_file("res://ui/character_hub/CharacterHub.tscn")

# Phương thức hỗ trợ cho Xe Tống Kim bị tấn công
func damage_cart(_amount: float) -> void:
	if wave_state == "DEFEAT":
		return
	_update_hud_display()

# Phương thức hỗ trợ hồi phục Xe Tống Kim (Rương tiếp tế)
func repair_cart(_amount: float) -> void:
	if wave_state == "DEFEAT":
		return
	# Khôi phục xe ở hàng đầu tiên bị mất
	for r in GRID_ROWS:
		if not _cart_available[r] and not _cart_charging[r]:
			_restore_cart(r)
			break
	_update_hud_display()

func _restore_cart(r: int) -> void:
	_cart_available[r] = true
	_cart_charging[r] = false
	_cart_anim_timers[r] = 0.0

	const MonsterSpriteScript = preload("res://systems/monster/monster_sprite.gd")
	var cart := Node2D.new()
	cart.name = "XeTongKim_Hang_%d" % (r + 1)
	var cx := ORIGIN_X - 60.0
	var cy := ORIGIN_Y + r * CELL_H + CELL_H * 0.65
	cart.position = Vector2(cx, cy)
	cart.add_to_group("escort_carts")
	add_child(cart)

	var sp = MonsterSpriteScript.new()
	sp.set_resource("enemy241")
	sp.set_pose("fight_stand", 48, 0.0)
	sp.scale = Vector2(0.95, 0.95)
	cart.add_child(sp)

	var badge := Label.new()
	badge.text = "Xe %d" % (r + 1)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.size = Vector2(60, 16)
	badge.position = Vector2(-30, -55)
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 2)
	cart.add_child(badge)

	_cart_nodes[r] = cart
	_cart_sprites[r] = sp

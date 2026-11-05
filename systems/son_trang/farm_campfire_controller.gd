@tool
extends Node2D
class_name FarmCampfireController
## Điều khiển trực quan các Đống Lửa Sơn Trang trên bản đồ Nguyệt Ca Đảo (Map 1041).
## - Mỗi vị trí NPC (Trồng trọt, Chăn nuôi, Cá nước ngọt, Cá biển) đều có 1 đống lửa riêng biệt.
## - Sử dụng ngọn lửa VLTK chuẩn gốc (tan_lua_sheet.png - 20 frames hoạt họa bập bùng).
## - Tầng mặt đất (quầng sáng, củi, vòng đá bảo vệ) ở z_index = -1 để không che khuất nhân vật / thú cưỡi.
## - Tự động đồng bộ vào objects_root của map để hệ thống Y-sorting sắp xếp độ sâu chính xác (người đứng trước lửa hiện trước, đứng sau lửa hiện sau).
## - Bảng tên, thanh nhiên liệu mini được nâng cao (-112px) để không che mặt người chơi.
## - Nhấp chuột vào đống lửa -> Di chuyển lại gần và mở Bảng Giao Diện Lửa Trại chuẩn Kiếm Hiệp VLTK (Campfire UI).
## - Khi người chơi đứng trong bán kính sưởi ấm (~750px) quanh bất kỳ đống lửa nào đang cháy: Nhận EXP liên tục và hiển thị số EXP bay lên.

const CAMPFIRE_POS_WORLD := Vector2(49280.0, 48000.0) # Vị trí fallback tương thích test (192/187)
const WARMTH_RADIUS: float = 750.0 # Bán kính sưởi ấm bao phủ toàn khu vực
const CLICK_RADIUS: float = 75.0
const FRAME_DURATION: float = 0.08 # ~12.5 fps animation VLTK mượt mà
const TOTAL_FRAMES: int = 20

## Danh sách 4 Đống Lửa tương ứng các vị trí NPC và khu vực làm việc trên Nguyệt Ca Đảo
const CAMPFIRE_CONFIGS := [
	{
		"id": "campfire_agriculture",
		"name": "Đống Lửa Nông Trại",
		"npc_name": "Thần Nông Tiên Sinh",
		"coord_name": "192/187",
		"world_pos": Vector2(49280.0, 48000.0)
	},
	{
		"id": "campfire_livestock",
		"name": "Đống Lửa Chuồng Trại",
		"npc_name": "Trương Bá (Chăn Nuôi)",
		"coord_name": "195/193",
		"world_pos": Vector2(50048.0, 49536.0)
	},
	{
		"id": "campfire_freshwater_fish",
		"name": "Đống Lửa Bến Hồ",
		"npc_name": "Khê Hồ Ngư Nương",
		"coord_name": "179/185",
		"world_pos": Vector2(45952.0, 47488.0)
	},
	{
		"id": "campfire_ocean_fish",
		"name": "Đống Lửa Bờ Biển",
		"npc_name": "Hải Ngư Thuyền Trưởng",
		"coord_name": "195/197",
		"world_pos": Vector2(50080.0, 50560.0)
	}
]

## Node vẽ tầng mặt đất của đống lửa (quầng sáng ấm, vòng đá, củi và than hồng)
## Được đặt ở z_index = -1 để luôn nằm sát mặt đất bên dưới chân nhân vật, thú cưỡi và ngọn lửa.
class CampfireGroundLayer extends Node2D:
	var campfire: SingleCampfire = null
	
	func _init(p_campfire: SingleCampfire) -> void:
		campfire = p_campfire
		z_index = -1
		z_as_relative = true
	
	func _draw() -> void:
		if campfire != null and is_instance_valid(campfire):
			campfire._draw_ground_layer(self)

## Node đại diện cho 1 đống lửa riêng lẻ
class SingleCampfire extends Node2D:
	var cfg: Dictionary
	var farm_mgr: FarmManager = null
	
	var ground_layer: CampfireGroundLayer = null
	var flame_sprite: Sprite2D = null
	var ember_particles: CPUParticles2D = null
	var smoke_particles: CPUParticles2D = null
	var info_overlay: Node2D = null
	var name_label: Label = null
	var status_label: Label = null
	var mini_bar: ProgressBar = null
	
	var anim_frame_timer: float = 0.0
	var current_frame: int = 0
	var glow_phase: float = 0.0
	var is_hovered: bool = false
	var flame_frames: int = TOTAL_FRAMES
	var base_flame_scale: float = 0.42
	var base_flame_pos_y: float = -30.0
	
	func _init(config: Dictionary = {}, p_farm_mgr: FarmManager = null) -> void:
		cfg = config
		farm_mgr = p_farm_mgr
		if cfg.has("world_pos"):
			position = cfg["world_pos"]
		# z_index = 0 kết hợp y_sort_enabled để tự động sắp xếp độ sâu với nhân vật:
		# Người chơi đứng trước lửa -> người vẽ đè lên lửa, đứng sau -> lửa vẽ đè chân người.
		z_index = 0
		y_sort_enabled = true
	
	func _ready() -> void:
		_setup_ground_layer()
		_setup_flame_sprite()
		_setup_particles()
		_setup_head_info()
		_update_visual_state()
	
	func _setup_ground_layer() -> void:
		ground_layer = CampfireGroundLayer.new(self)
		add_child(ground_layer)
	
	func _setup_flame_sprite() -> void:
		# Ưu tiên số 1: Tàn Lửa VLTK gốc (tan_lua_sheet.png - 20 frames)
		var path_tanlua := "res://assets/campfire/tan_lua_sheet.png"
		var path_holua := "res://assets/campfire/ho_lua_sheet.png"
		var path_sjzh := "res://assets/campfire/sjzh_huo_sheet.png"
		var path_fallback := "res://assets/skill_fx/sjzh_huo_7ac0.png"
		
		var chosen_path := ""
		if ResourceLoader.exists(path_tanlua) or FileAccess.file_exists(path_tanlua):
			chosen_path = path_tanlua
			flame_frames = 20
			base_flame_scale = 0.42
		elif ResourceLoader.exists(path_holua) or FileAccess.file_exists(path_holua):
			chosen_path = path_holua
			flame_frames = 20
			base_flame_scale = 0.40
		elif ResourceLoader.exists(path_sjzh) or FileAccess.file_exists(path_sjzh):
			chosen_path = path_sjzh
			flame_frames = 10
			base_flame_scale = 1.6
		elif ResourceLoader.exists(path_fallback) or FileAccess.file_exists(path_fallback):
			chosen_path = path_fallback
			flame_frames = 10
			base_flame_scale = 1.6
		
		if chosen_path != "":
			var tex: Texture2D = null
			if ResourceLoader.exists(chosen_path):
				tex = load(chosen_path) as Texture2D
			elif FileAccess.file_exists(chosen_path):
				var img := Image.load_from_file(ProjectSettings.globalize_path(chosen_path))
				if img != null:
					tex = ImageTexture.create_from_image(img)
			
			if tex != null:
				flame_sprite = Sprite2D.new()
				flame_sprite.texture = tex
				flame_sprite.hframes = flame_frames
				flame_sprite.frame = 0
				flame_sprite.centered = true
				flame_sprite.z_index = 0
				if chosen_path == path_tanlua:
					# Tàn Lửa VLTK chuẩn: 20 frames, hạ thấp y=-30 để ngọn lửa ôm trọn đống củi và than hồng
					base_flame_pos_y = -30.0
					flame_sprite.scale = Vector2(base_flame_scale, base_flame_scale)
					flame_sprite.position = Vector2(0, base_flame_pos_y)
				elif chosen_path == path_holua:
					# Hố Lửa VLTK: hạ thấp y=-12 để miệng hố khớp trực tiếp với đống củi
					base_flame_pos_y = -12.0
					flame_sprite.scale = Vector2(base_flame_scale, base_flame_scale)
					flame_sprite.position = Vector2(0, base_flame_pos_y)
				else:
					base_flame_pos_y = -16.0
					flame_sprite.scale = Vector2(base_flame_scale, base_flame_scale)
					flame_sprite.position = Vector2(0, base_flame_pos_y)
				add_child(flame_sprite)
	
	func _get_fuel() -> float:
		if farm_mgr != null:
			return farm_mgr.campfire_fuel
		return 1.0 # Trong Editor hoặc chưa có FarmManager thì mặc định đống lửa đang cháy để hiển thị trực quan
	
	func _setup_particles() -> void:
		# 1. Tia than hồng / tàn lửa bay lên
		ember_particles = CPUParticles2D.new()
		ember_particles.amount = 20
		ember_particles.lifetime = 1.3
		ember_particles.preprocess = 0.5
		ember_particles.position = Vector2(0, -16)
		ember_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		ember_particles.emission_rect_extents = Vector2(18, 6)
		ember_particles.direction = Vector2(0, -1)
		ember_particles.spread = 30.0
		ember_particles.gravity = Vector2(0, -70)
		ember_particles.initial_velocity_min = 25.0
		ember_particles.initial_velocity_max = 50.0
		ember_particles.scale_amount_min = 1.8
		ember_particles.scale_amount_max = 3.0
		ember_particles.color = Color(1.0, 0.72, 0.2, 0.95)
		add_child(ember_particles)
		
		# 2. Khói than mỏng bốc lên
		smoke_particles = CPUParticles2D.new()
		smoke_particles.amount = 8
		smoke_particles.lifetime = 2.2
		smoke_particles.preprocess = 0.5
		smoke_particles.position = Vector2(0, -36)
		smoke_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		smoke_particles.emission_sphere_radius = 10.0
		smoke_particles.direction = Vector2(0.2, -1)
		smoke_particles.spread = 20.0
		smoke_particles.gravity = Vector2(8, -25)
		smoke_particles.initial_velocity_min = 15.0
		smoke_particles.initial_velocity_max = 32.0
		smoke_particles.scale_amount_min = 3.0
		smoke_particles.scale_amount_max = 6.5
		smoke_particles.color = Color(0.65, 0.65, 0.68, 0.25)
		add_child(smoke_particles)
	
	func _setup_head_info() -> void:
		info_overlay = Node2D.new()
		# Nâng độ cao bảng tên lên -112px để không bị nhân vật cưỡi ngựa che khuất
		info_overlay.position = Vector2(0, -112)
		info_overlay.z_index = 20
		add_child(info_overlay)
		
		# Tiêu đề Lửa Trại
		name_label = Label.new()
		name_label.text = "🔥 %s" % cfg["name"].to_upper()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size = Vector2(260, 24)
		name_label.position = Vector2(-130, -28)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		name_label.add_theme_constant_override("shadow_offset_x", 1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		info_overlay.add_child(name_label)
		
		# Mini Progress Bar
		mini_bar = ProgressBar.new()
		mini_bar.custom_minimum_size = Vector2(100, 7)
		mini_bar.position = Vector2(-50, -4)
		mini_bar.min_value = 0.0
		mini_bar.max_value = 1.0
		mini_bar.value = 0.5
		mini_bar.show_percentage = false
		
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.1, 0.1, 0.12, 0.8)
		bar_bg.set_corner_radius_all(3)
		mini_bar.add_theme_stylebox_override("background", bar_bg)
		
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color(1.0, 0.62, 0.15)
		bar_fill.set_corner_radius_all(3)
		mini_bar.add_theme_stylebox_override("fill", bar_fill)
		info_overlay.add_child(mini_bar)
		
		# Dòng trạng thái nhỏ bên dưới
		status_label = Label.new()
		status_label.text = "[Nhấp để tiếp củi / sưởi ấm]"
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.custom_minimum_size = Vector2(260, 18)
		status_label.position = Vector2(-130, 6)
		status_label.add_theme_font_size_override("font_size", 10)
		status_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75, 0.85))
		status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		info_overlay.add_child(status_label)
	
	func _process(delta: float) -> void:
		glow_phase += delta * 3.5
		if ground_layer != null and is_instance_valid(ground_layer):
			ground_layer.queue_redraw()
		
		var fuel: float = _get_fuel()
		var is_lit: bool = fuel > 0.001
		
		# Animate flame frames
		if is_lit and flame_sprite != null:
			anim_frame_timer += delta
			if anim_frame_timer >= FRAME_DURATION:
				anim_frame_timer = 0.0
				current_frame = (current_frame + 1) % flame_frames
				flame_sprite.frame = current_frame
	
	func update_visual() -> void:
		_update_visual_state()
	
	func _update_visual_state() -> void:
		var fuel: float = _get_fuel()
		var is_lit: bool = fuel > 0.001
		
		if flame_sprite != null:
			flame_sprite.visible = is_lit
			var s: float = lerp(base_flame_scale * 0.90, base_flame_scale * 1.12, clampf(fuel, 0.0, 1.0))
			flame_sprite.scale = Vector2(s, s)
			flame_sprite.position = Vector2(0, round(base_flame_pos_y * (s / base_flame_scale)))
		
		if ember_particles != null:
			ember_particles.emitting = is_lit
			ember_particles.amount = int(lerp(8.0, 26.0, clampf(fuel, 0.0, 1.0)))
		
		if smoke_particles != null:
			smoke_particles.emitting = true
			smoke_particles.amount = 14 if not is_lit else 6
			smoke_particles.color = Color(0.5, 0.5, 0.5, 0.45) if not is_lit else Color(0.65, 0.65, 0.68, 0.25)
		
		if mini_bar != null:
			mini_bar.value = fuel
			var fill_box := mini_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if fill_box != null:
				if fuel > 0.5:
					fill_box.bg_color = Color(0.3, 0.85, 0.3)
				elif fuel > 0.2:
					fill_box.bg_color = Color(1.0, 0.75, 0.2)
				else:
					fill_box.bg_color = Color(0.9, 0.3, 0.2)
		
		if status_label != null:
			if is_lit:
				var mins: int = int(fuel * 1200.0) / 60
				status_label.text = "🔥 Đang sưởi ấm (Cháy ~%d phút)" % [mins]
				status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
			else:
				status_label.text = "⚠️ [Lửa Đã Tắt - Cần Thêm Củi]"
				status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	
	func _draw_ground_layer(target: Node2D) -> void:
		var fuel: float = _get_fuel()
		var is_lit: bool = fuel > 0.001
		
		# 1. Quầng sáng ấm áp trên mặt đất sát gốc đống lửa
		if is_lit:
			var pulse: float = 1.0 + sin(glow_phase) * 0.08
			var glow_rad: float = 65.0 * pulse
			var glow_col := Color(1.0, 0.65, 0.20, 0.18 + sin(glow_phase) * 0.03)
			target.draw_circle(Vector2(0, -6), glow_rad, glow_col)
		
		# 2. Vòng đá xếp tròn bảo vệ đống lửa trên mặt đất
		var stones_count := 12
		var ring_r := 30.0
		for i in range(stones_count):
			var angle: float = (float(i) / float(stones_count)) * TAU
			var stone_pos := Vector2(cos(angle) * ring_r, sin(angle) * (ring_r * 0.58) - 2.0)
			var stone_col := Color(0.38, 0.36, 0.34) if (i % 2 == 0) else Color(0.48, 0.46, 0.42)
			target.draw_circle(stone_pos, 6.0, stone_col)
			target.draw_circle(stone_pos, 3.5, stone_col.lightened(0.15))
		
		# 3. Đống củi gỗ đan chéo trên mặt đất
		var log_color := Color(0.32, 0.20, 0.10)
		var log_highlight := Color(0.48, 0.32, 0.16)
		target.draw_line(Vector2(-24, -12), Vector2(24, 6), log_color, 6.0, true)
		target.draw_line(Vector2(-22, -12), Vector2(22, 6), log_highlight, 3.0, true)
		target.draw_line(Vector2(-24, 6), Vector2(24, -12), log_color, 6.0, true)
		target.draw_line(Vector2(-22, 6), Vector2(22, -12), log_highlight, 3.0, true)
		target.draw_line(Vector2(-20, -3), Vector2(20, -3), log_color, 5.0, true)
		
		# 4. Than hồng âm ỉ bên dưới
		var ember_core := Color(1.0, 0.35, 0.05, 0.85) if is_lit else Color(0.25, 0.22, 0.22, 0.7)
		target.draw_circle(Vector2(0, -4), 14.0, ember_core)
		if is_lit:
			target.draw_circle(Vector2(0, -4), 8.0, Color(1.0, 0.85, 0.2, 0.9))
	
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var mouse_world: Vector2 = get_global_mouse_position()
				if mouse_world.distance_to(global_position + Vector2(0, -20)) <= CLICK_RADIUS:
					get_viewport().set_input_as_handled()
					_on_clicked()
	
	func _on_clicked() -> void:
		var player = get_tree().get_first_node_in_group("player")
		if player != null and is_instance_valid(player):
			var d: float = global_position.distance_to(player.global_position)
			if d > 120.0:
				if player.has_method("walk_to_feet"):
					player.walk_to_feet(global_position + Vector2(0, 40))
				elif "destination" in player:
					player.destination = global_position + Vector2(0, 40)
		
		# Mở UI Lửa Trại chuẩn VLTK
		var fw_script: GDScript = load("res://ui/son_trang/farm_windows.gd")
		if fw_script != null:
			fw_script.open_campfire(self, cfg)

var farm_mgr: FarmManager = null
var campfire_nodes: Array[SingleCampfire] = []
var exp_check_timer: float = 0.0

func _ready() -> void:
	name = "FarmCampfireController"
	position = Vector2.ZERO
	y_sort_enabled = true
	
	# Xoá các node con cũ nếu đang chạy reload trong Godot Editor
	for c in get_children():
		if c is SingleCampfire:
			c.queue_free()
	campfire_nodes.clear()
	
	farm_mgr = get_node_or_null("/root/FarmManager")
	
	# Khởi tạo 4 Đống Lửa tại 4 khu vực NPC
	for cfg in CAMPFIRE_CONFIGS:
		var cf := SingleCampfire.new(cfg, farm_mgr)
		add_child(cf)
		campfire_nodes.append(cf)
	
	if farm_mgr != null and not Engine.is_editor_hint():
		farm_mgr.campfire_updated.connect(_on_campfire_updated)
	
	# Tự động đồng bộ các node campfire vào objects_root để Y-Sort đồng bộ với Player
	_try_adopt_campfires.call_deferred()

func _try_adopt_campfires() -> void:
	var obj_root: Node2D = null
	# Tìm VltkWorld động để tránh lỗi biên dịch khi chạy unit test độc lập
	if get_tree() != null and get_tree().root != null:
		var v_world = get_tree().root.find_child("VltkWorld", true, false)
		if v_world != null and "map" in v_world and v_world.map != null and "objects_root" in v_world.map:
			obj_root = v_world.map.objects_root
	
	if obj_root == null:
		var vw_res = ResourceLoader.load("res://world/vltk_world.gd")
		if vw_res != null and "current" in vw_res and vw_res.current != null:
			if "map" in vw_res.current and vw_res.current.map != null and "objects_root" in vw_res.current.map:
				obj_root = vw_res.current.map.objects_root
	
	if obj_root != null and is_instance_valid(obj_root):
		for cf in campfire_nodes:
			if is_instance_valid(cf) and cf.get_parent() != obj_root:
				cf.reparent(obj_root, true)

func _exit_tree() -> void:
	for cf in campfire_nodes:
		if is_instance_valid(cf):
			cf.queue_free()
	campfire_nodes.clear()

func _process(delta: float) -> void:
	# Kiểm tra người chơi đứng gần bất kỳ đống lửa nào để hiện hiệu ứng EXP bay
	exp_check_timer += delta
	if exp_check_timer >= 1.0:
		exp_check_timer = 0.0
		_check_player_warmth_notification()

func _check_player_warmth_notification() -> void:
	var fuel: float = farm_mgr.campfire_fuel if farm_mgr else 0.0
	if fuel <= 0.001:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		var p_pos: Vector2 = player.global_position
		for cf in campfire_nodes:
			if is_instance_valid(cf) and cf.global_position.distance_to(p_pos) <= WARMTH_RADIUS:
				_spawn_exp_text(player)
				break

func _spawn_exp_text(player: Node2D) -> void:
	var lbl := Label.new()
	var mult: float = 1.0
	var w_info := FarmTimeSystem.get_weather_info()
	if w_info.has("campfire_bonus"):
		mult = float(w_info["campfire_bonus"])
	var exp_val: int = int(2000 * mult)
	lbl.text = "🔥 +%d EXP Tu Vi  +20 Sơn Trang" % exp_val
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	# Đặt vị trí hiển thị trên đầu nhân vật, không che khuất bảng tên đống lửa
	lbl.position = player.global_position + Vector2(-120, -110)
	lbl.z_index = 200
	get_parent().add_child(lbl)
	
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 45.0, 1.2)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tween.tween_callback(lbl.queue_free)

func _on_campfire_updated(_fuel_ratio: float) -> void:
	for cf in campfire_nodes:
		if is_instance_valid(cf):
			cf.update_visual()

## Trả về vị trí đống lửa theo category hoặc id
func get_campfire_position(campfire_id: String) -> Vector2:
	for cfg in CAMPFIRE_CONFIGS:
		if cfg["id"] == campfire_id or cfg["name"] == campfire_id:
			return cfg["world_pos"]
	return CAMPFIRE_POS_WORLD

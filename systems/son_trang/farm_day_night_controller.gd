extends CanvasLayer
class_name FarmDayNightController
## Hệ thống quản lý Chu kỳ Ngày & Đêm trực quan tại Sơn Trang (Nguyệt Ca Đảo)
## - Điều khiển màn phủ bóng tối (Night Overlay) và ánh sáng ban đêm.
## - Đẩy lùi bóng tối ban đêm: Đống lửa đang cháy sẽ tỏa sáng rực rỡ một vùng rộng xung quanh.
## - Hiệp khách có quầng sáng bảo hộ vừa phải xung quanh để quan sát bước đi.
## - Hỗ trợ cả chu kỳ thực tế 24h và tùy chỉnh thủ công một chạm trên UI.

const NIGHT_SHADER := preload("res://systems/son_trang/night_overlay.gdshader")
const MAX_CAMPFIRES: int = 8
const CAMPFIRE_LIGHT_RADIUS_PX: float = 600.0 # Bán kính vùng sáng từ đống lửa chuẩn 600px

var night_overlay: ColorRect = null
var overlay_material: ShaderMaterial = null

var current_darkness: float = 0.0
var current_tint: Color = Color(0.9, 0.92, 1.0, 1.0)
var flicker_timer: float = 0.0

var player_node: Node2D = null
var campfire_controller: Node = null
var farm_mgr: FarmManager = null

func _init() -> void:
	name = "FarmDayNightController"
	layer = 1 # Nằm trên nền thế giới bản đồ, dưới CanvasLayer UI (layer 10)
	_setup_overlay()

func _ready() -> void:
	_find_dependencies()
	
	# Khởi tạo ngay độ tối theo giai đoạn hiện tại
	var phase := FarmTimeSystem.get_current_day_phase()
	current_darkness = FarmTimeSystem.get_day_phase_darkness(phase)
	current_tint = FarmTimeSystem.get_day_phase_tint(phase)
	_apply_shader_params(0.0)

func _setup_overlay() -> void:
	if night_overlay != null:
		return
	night_overlay = ColorRect.new()
	night_overlay.name = "NightOverlay"
	night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = NIGHT_SHADER
	night_overlay.material = overlay_material
	add_child(night_overlay)

func _find_dependencies() -> void:
	farm_mgr = get_node_or_null("/root/FarmManager")
	
	# Tìm Player
	var p = get_tree().get_first_node_in_group("player")
	if p is Node2D:
		player_node = p
	else:
		player_node = get_tree().root.find_child("Player", true, false) as Node2D

func _process(delta: float) -> void:
	flicker_timer += delta
	_update_day_night_transition(delta)
	_apply_shader_params(delta)

func _update_day_night_transition(delta: float) -> void:
	var phase := FarmTimeSystem.get_current_day_phase()
	var target_darkness := FarmTimeSystem.get_day_phase_darkness(phase)
	var target_tint := FarmTimeSystem.get_day_phase_tint(phase)
	
	# Chuyển đổi ánh sáng mượt mà giữa các buổi trong ngày
	current_darkness = lerpf(current_darkness, target_darkness, clampf(delta * 2.8, 0.0, 1.0))
	current_tint = current_tint.lerp(target_tint, clampf(delta * 2.8, 0.0, 1.0))

func _apply_shader_params(delta: float) -> void:
	if overlay_material == null:
		return
	
	var vp_size := Vector2(1280.0, 720.0)
	if is_inside_tree():
		var vp := get_viewport()
		if vp != null:
			var vp_rect := vp.get_visible_rect()
			if vp_rect.size.x > 0.0 and vp_rect.size.y > 0.0:
				vp_size = vp_rect.size
	
	overlay_material.set_shader_parameter("screen_size", vp_size)
	overlay_material.set_shader_parameter("darkness_intensity", current_darkness)
	overlay_material.set_shader_parameter("night_tint", current_tint)
	
	# 1. Cập nhật vị trí người chơi
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			if player_node == null or not is_instance_valid(player_node):
				var p = tree.get_first_node_in_group("player")
				if p is Node2D:
					player_node = p
	
	if player_node != null and is_instance_valid(player_node):
		var p_screen: Vector2 = player_node.get_global_transform_with_canvas().origin
		var p_uv := Vector2(p_screen.x / vp_size.x, p_screen.y / vp_size.y)
		overlay_material.set_shader_parameter("player_screen_pos", p_uv)
		overlay_material.set_shader_parameter("player_light_radius", 0.17)
	else:
		overlay_material.set_shader_parameter("player_screen_pos", Vector2(0.5, 0.5))
		overlay_material.set_shader_parameter("player_light_radius", 0.17)
	
	# 2. Cập nhật vị trí và quầng sáng của các Đống Lửa Sơn Trang
	_update_campfires_lighting(vp_size)

func _update_campfires_lighting(vp_size: Vector2) -> void:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and (campfire_controller == null or not is_instance_valid(campfire_controller)):
			campfire_controller = tree.root.find_child("FarmCampfireController", true, false)
	
	var cf_positions: Array[Vector2] = []
	var cf_radii: Array[float] = []
	var cf_intensities: Array[float] = []
	var cf_colors: Array[Color] = []
	
	var fuel: float = farm_mgr.campfire_fuel if farm_mgr != null else 0.5
	var is_lit: bool = fuel > 0.001
	
	# Lấy danh sách các đống lửa thực tế hoặc từ cấu hình
	var campfires_to_process: Array = []
	if campfire_controller != null and "campfire_nodes" in campfire_controller:
		campfires_to_process = campfire_controller.campfire_nodes
	
	if campfires_to_process.is_empty():
		# Dùng vị trí cố định từ FarmCampfireController nếu node chưa sẵn sàng
		var configs = FarmCampfireController.CAMPFIRE_CONFIGS if "CAMPFIRE_CONFIGS" in FarmCampfireController else []
		for i in range(mini(configs.size(), MAX_CAMPFIRES)):
			var cfg: Dictionary = configs[i]
			var wpos: Vector2 = cfg.get("world_pos", Vector2.ZERO)
			var cf_screen: Vector2 = _world_to_canvas(wpos)
			var cf_uv := Vector2(cf_screen.x / vp_size.x, cf_screen.y / vp_size.y)
			
			cf_positions.append(cf_uv)
			if is_lit:
				var flicker := sin(flicker_timer * 5.2 + i * 1.8) * 0.035
				var flicker_px: float = sin(flicker_timer * 4.8 + i * 2.1) * 16.0
				var base_rad_uv: float = (CAMPFIRE_LIGHT_RADIUS_PX + flicker_px) / maxf(vp_size.y, 1.0)
				cf_radii.append(base_rad_uv)
				cf_intensities.append(clampf(0.96 + flicker, 0.0, 1.0))
				cf_colors.append(Color(1.0, 0.68, 0.22, 1.0))
			else:
				cf_radii.append(0.0)
				cf_intensities.append(0.0)
				cf_colors.append(Color.BLACK)
	else:
		for i in range(mini(campfires_to_process.size(), MAX_CAMPFIRES)):
			var cf = campfires_to_process[i]
			if cf is Node2D and is_instance_valid(cf):
				var cf_screen: Vector2 = cf.get_global_transform_with_canvas().origin
				var cf_uv := Vector2(cf_screen.x / vp_size.x, cf_screen.y / vp_size.y)
				cf_positions.append(cf_uv)
				
				if is_lit:
					# Ngọn lửa bập bùng: quầng sáng mở rộng chiếu sáng một vùng rộng lớn tầm 600px xung quanh
					var flicker := sin(flicker_timer * 5.2 + i * 1.8) * 0.035
					var flicker_px: float = sin(flicker_timer * 4.8 + i * 2.1) * 16.0
					# Bán kính vùng sáng 600px chuẩn hóa theo chiều cao màn hình (UV)
					var radius_val: float = (CAMPFIRE_LIGHT_RADIUS_PX + flicker_px) / maxf(vp_size.y, 1.0)
					var intensity_val: float = clampf(0.98 + flicker, 0.0, 1.0)
					cf_radii.append(radius_val)
					cf_intensities.append(intensity_val)
					cf_colors.append(Color(1.0, 0.70, 0.25, 1.0))
				else:
					cf_radii.append(0.0)
					cf_intensities.append(0.0)
					cf_colors.append(Color.BLACK)
	
	# Đẩy đủ mảng vào shader
	var count := cf_positions.size()
	while cf_positions.size() < MAX_CAMPFIRES:
		cf_positions.append(Vector2(-10.0, -10.0))
		cf_radii.append(0.0)
		cf_intensities.append(0.0)
		cf_colors.append(Color.BLACK)
	
	overlay_material.set_shader_parameter("campfire_count", count)
	overlay_material.set_shader_parameter("campfire_positions", cf_positions)
	overlay_material.set_shader_parameter("campfire_radii", cf_radii)
	overlay_material.set_shader_parameter("campfire_intensities", cf_intensities)
	overlay_material.set_shader_parameter("campfire_colors", cf_colors)

## Hỗ trợ chuyển đổi tọa độ world sang screen khi chưa có node
func _world_to_canvas(world_pos: Vector2) -> Vector2:
	if is_inside_tree():
		var vp := get_viewport()
		if vp != null:
			var canvas_transform := vp.get_canvas_transform()
			return canvas_transform * world_pos
	return world_pos

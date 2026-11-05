extends Node2D
class_name LivestockController
## Quản lý trực quan Khu Chăn Nuôi trên bản đồ Nguyệt Ca Đảo tại tọa độ 194/193.
## - Hiển thị toàn bộ đàn thú nuôi/chim muông đã nhận nuôi tự do dạo chơi trong bãi chăn thả ngoài trời.
## - Tương tác trực tiếp TRÊN CON THÚ (không dùng ô chuồng trên đất):
##   + Nhấp vào thú đang đói -> Cho ăn ngay lập tức (hồi 100% thanh đói).
##   + Nhấp vào thú đã lớn -> Thu hoạch sản phẩm ngay lập tức.
##   + Nhấp vào thú đang lớn -> Mở bảng chi tiết: Cho ăn thêm, Roi Chăn, Vuốt ve, Nâng cấp, Đồng hành.
##   + Chuột phải vào bất kỳ thú nào -> Mở bảng chi tiết.
## - Từng con thú hiển thị trực tiếp trên đầu:
##   + Thanh Đói (Hunger Bar) với % cụ thể.
##   + Thanh Thời Gian Thu Hoạch (Harvest Timer) với đếm ngược mm:ss.
##   + NGUYÊN TẮC QUAN TRỌNG: Nếu chỉ số đói = 0, thời gian thu hoạch TẠM DỪNG cho tới khi được cho ăn!

const COORD_UNIT: float = 256.0

## Tọa độ thế giới của Khu Chăn Nuôi (Tọa độ 194/193)
const LIVESTOCK_CENTER_WORLD := Vector2(49792.0, 49536.0)

## Các điểm nối đỉnh của phạm vi chuồng nuôi (188/191 -> 198/192 -> 199/194 -> 193/195 -> 187/194)
const PASTURE_COORDS: Array[Vector2i] = [
	Vector2i(188, 191),
	Vector2i(198, 192),
	Vector2i(199, 194),
	Vector2i(193, 195),
	Vector2i(187, 194)
]

## Tọa độ Local đa giác chuồng nuôi tính từ tâm LIVESTOCK_CENTER_WORLD (194/193)
## Local = (Coord - (194, 193)) * 256.0
const PASTURE_POLYGON: PackedVector2Array = [
	Vector2(-1536.0, -512.0), # 188/191 (Tây Bắc)
	Vector2(1024.0, -256.0),  # 198/192 (Đông Bắc)
	Vector2(1280.0, 256.0),   # 199/194 (Đông Nam)
	Vector2(-256.0, 512.0),   # 193/195 (Nam)
	Vector2(-1792.0, 256.0)   # 187/194 (Tây Nam)
]

## Bounding rect bao quanh toàn bộ phạm vi chuồng nuôi
const PASTURE_BOUNDS := Rect2(Vector2(-1792.0, -512.0), Vector2(3072.0, 1024.0))

## Khu vực bãi chăn thả rộng lớn cho thú nuôi tự do di chuyển (tương thích ngược)
const OUTDOOR_ROAM_RECT := PASTURE_BOUNDS

## Định danh và Tên vùng nuôi thú
@export var zone_id: String = "zone_pasture_nguyet_ca"
@export var zone_name: String = "Vòng Nuôi Thú Sơn Trang [194/193]"

var farm_mgr = null

const PEN_W: float = 145.0
const PEN_H: float = 95.0
const PENS_COUNT: int = 4

var _pen_areas: Array[Rect2] = []
var _animal_nodes: Array[AnimalWanderer] = []
var all_roaming_outside: bool = true

## Lớp điều khiển con vật di chuyển tự do ở ngoài bãi cỏ & xung quanh chuồng (Wander AI)
class AnimalWanderer extends Node2D:
	enum WanderState { IDLE = 0, WALK = 1, GREET_PLAYER = 2 }

	var animal_info: LivestockManager.AnimalInfo
	var pen_rect: Rect2
	var pasture_polygon: PackedVector2Array
	var pasture_bounds: Rect2
	var outdoor_rect: Rect2
	var pen_idx: int = 0
	var is_roaming_outside: bool = true

	var sprite: MonsterSprite
	var state: WanderState = WanderState.IDLE
	var current_dir64: int = 0
	var target_pos: Vector2 = Vector2.ZERO

	var move_speed: float = 38.0
	var state_timer: float = 0.0
	var anim_timer: float = 0.0
	var greet_cooldown: float = 0.0

	var overhead_hud: AnimalOverheadHUD = null

	static func get_random_pasture_pos(poly: PackedVector2Array, bounds: Rect2, margin: float = 35.0) -> Vector2:
		for _i in range(30):
			var pt := Vector2(
				randf_range(bounds.position.x + margin, bounds.end.x - margin),
				randf_range(bounds.position.y + margin, bounds.end.y - margin)
			)
			if Geometry2D.is_point_in_polygon(pt, poly):
				return pt
		return Vector2.ZERO

	func _init(info: LivestockManager.AnimalInfo, pen_r: Rect2, poly_or_rect = null, arg4 = null, idx: int = 0, roam_outside: bool = true) -> void:
		animal_info = info
		pen_rect = pen_r
		if poly_or_rect is PackedVector2Array:
			pasture_polygon = poly_or_rect
			outdoor_rect = arg4 if arg4 is Rect2 else PASTURE_BOUNDS
			pen_idx = idx
			is_roaming_outside = roam_outside
		elif poly_or_rect is Rect2:
			pasture_polygon = PASTURE_POLYGON
			outdoor_rect = poly_or_rect
			pen_idx = int(arg4) if arg4 != null else 0
			is_roaming_outside = roam_outside
		else:
			pasture_polygon = PASTURE_POLYGON
			outdoor_rect = PASTURE_BOUNDS
			pen_idx = idx
			is_roaming_outside = roam_outside

		pasture_bounds = outdoor_rect

		if animal_info != null and (animal_info.pos_x != 0.0 or animal_info.pos_y != 0.0):
			position = Vector2(animal_info.pos_x, animal_info.pos_y)
		elif is_roaming_outside:
			position = get_random_pasture_pos(pasture_polygon, pasture_bounds, 35.0)
		else:
			var inside_pen := pen_rect.grow(-18.0)
			position = inside_pen.get_center()

		if animal_info != null:
			animal_info.pos_x = position.x
			animal_info.pos_y = position.y

		current_dir64 = randi() % 64
		_enter_idle()

	func _ready() -> void:
		sprite = MonsterSprite.new()
		sprite.scale = Vector2(0.85, 0.85)
		add_child(sprite)
		sprite.set_resource(animal_info.res)
		sprite.set_pose("stand", current_dir64, 0.0)

		# Overhead HUD trực quan: hiển thị tên, thanh đói, thanh thu hoạch, đếm ngược, nút nhấp
		overhead_hud = AnimalOverheadHUD.new(self)
		add_child(overhead_hud)

	func set_roam_outside(roam: bool) -> void:
		is_roaming_outside = roam
		animal_info.is_roaming_outside = roam
		if not is_roaming_outside:
			var inside_pen := pen_rect.grow(-18.0)
			target_pos = inside_pen.get_center()
			_enter_walk()
		else:
			_enter_walk()

	func _enter_idle() -> void:
		state = WanderState.IDLE
		state_timer = randf_range(2.0, 5.0)
		anim_timer = 0.0

	func _enter_walk() -> void:
		state = WanderState.WALK
		state_timer = randf_range(3.5, 7.5)
		move_speed = randf_range(28.0, 48.0)
		anim_timer = 0.0

		if is_roaming_outside:
			target_pos = get_random_pasture_pos(pasture_polygon, pasture_bounds, 35.0)
		else:
			var roam_r := pen_rect.grow(-18.0)
			target_pos = Vector2(
				randf_range(roam_r.position.x, roam_r.end.x),
				randf_range(roam_r.position.y, roam_r.end.y)
			)

		var d := VltkMath.dir_between(position, target_pos)
		if d >= 0:
			current_dir64 = d

	func _process(delta: float) -> void:
		if sprite == null:
			return

		anim_timer += delta
		greet_cooldown = maxf(0.0, greet_cooldown - delta)
		z_index = clampi(int(global_position.y / 20.0), -4000, 4000)

		# Lưu toạ độ hiện tại để không bị nhảy vị trí khi cập nhật
		if animal_info != null:
			animal_info.pos_x = position.x
			animal_info.pos_y = position.y

		# Kiểm tra người chơi ở gần để phản ứng mừng rỡ
		var player = get_tree().get_first_node_in_group("player") as Node2D
		if is_roaming_outside and player != null and greet_cooldown <= 0.0 and state != WanderState.GREET_PLAYER:
			var dist_to_player := global_position.distance_to(player.global_position)
			if dist_to_player < 130.0 and dist_to_player > 50.0:
				state = WanderState.GREET_PLAYER
				state_timer = randf_range(2.5, 4.0)
				greet_cooldown = 12.0

		# Nếu con vật đã lớn sẵn sàng thu hoạch -> đứng thở/mừng đón chủ nhân
		if animal_info.state == LivestockManager.AnimalState.READY and state != WanderState.WALK:
			var prog := fmod(anim_timer * 0.8, 1.0)
			sprite.set_pose("stand", current_dir64, prog)
			return

		match state:
			WanderState.IDLE:
				state_timer -= delta
				var stand_prog := fmod(anim_timer * 0.5, 1.0)
				sprite.set_pose("stand", current_dir64, stand_prog)
				if state_timer <= 0.0:
					_enter_walk()

			WanderState.WALK:
				state_timer -= delta
				position = position.move_toward(target_pos, move_speed * delta)
				var walk_prog := fmod(anim_timer * 1.5, 1.0)

				var ok := sprite.set_pose("walk", current_dir64, walk_prog)
				if not ok:
					sprite.set_pose("stand", current_dir64, walk_prog)

				if position.distance_to(target_pos) <= 4.0 or state_timer <= 0.0:
					_enter_idle()

			WanderState.GREET_PLAYER:
				state_timer -= delta
				if player != null:
					var player_local := to_local(player.global_position)
					var d := VltkMath.dir_between(position, position + player_local)
					if d >= 0:
						current_dir64 = d

					var dist := position.distance_to(position + player_local)
					if dist > 55.0:
						position = position.move_toward(position + player_local, 35.0 * delta)
						var walk_prog := fmod(anim_timer * 1.4, 1.0)
						sprite.set_pose("walk", current_dir64, walk_prog)
					else:
						var stand_prog := fmod(anim_timer * 0.8, 1.0)
						sprite.set_pose("stand", current_dir64, stand_prog)

				if state_timer <= 0.0:
					_enter_idle()

## Lớp hiển thị UI nổi trên đầu con thú:
## - Tên & Cấp độ
## - Thanh Đói (Hunger Bar)
## - Thanh Thu Hoạch & Đếm ngược thời gian
## - Báo Đói (Tạm Dừng) & Nút Nhấp Cho Ăn / Nhấp Thu Hoạch
class AnimalOverheadHUD extends Node2D:
	var wanderer: AnimalWanderer = null
	var anim_blink: float = 0.0

	func _init(w: AnimalWanderer) -> void:
		wanderer = w
		z_index = 30 # Nổi lên trên thân thú

	func _process(delta: float) -> void:
		anim_blink += delta * 4.0
		queue_redraw()

	static func _get_farm_font() -> Font:
		if ClassDB.class_exists("GameUi") or ResourceLoader.exists("res://ui/common/game_ui.gd"):
			var gf = GameUi.game_font()
			if gf != null:
				return gf
		var t := ThemeDB.get_project_theme()
		if t and t.default_font:
			return t.default_font
		return ThemeDB.fallback_font

	func _draw() -> void:
		if wanderer == null or wanderer.animal_info == null:
			return
		var a := wanderer.animal_info
		var font := _get_farm_font()
		if font == null:
			return

		# 1. Tên thú nuôi + Cấp độ
		var name_str := "%s (Lv.%d)" % [a.name, a.level]
		draw_string_outline(font, Vector2(-60, -32), name_str, HORIZONTAL_ALIGNMENT_CENTER, 120, 10, 2, Color.BLACK)
		draw_string(font, Vector2(-60, -32), name_str, HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(1.0, 0.95, 0.7))

		# 2. Thanh Đói (Hunger Bar)
		var bar_w := 60.0
		var bar_h := 4.5
		var hunger_r := Rect2(-bar_w * 0.5, -20.0, bar_w, bar_h)
		draw_rect(hunger_r, Color(0.08, 0.08, 0.1, 0.85), true)
		draw_rect(hunger_r, Color(0.35, 0.35, 0.35, 0.8), false, 1.0)

		var h_ratio := clampf(a.hunger / a.max_hunger, 0.0, 1.0)
		var h_col := Color(0.25, 0.85, 0.35) # Xanh lá no nê
		if h_ratio <= 0.2:
			h_col = Color(0.95, 0.25, 0.2) # Đỏ đói
		elif h_ratio <= 0.5:
			h_col = Color(1.0, 0.72, 0.15) # Vàng cam cần ăn

		if h_ratio > 0.0:
			draw_rect(Rect2(hunger_r.position, Vector2(bar_w * h_ratio, bar_h)), h_col, true)

		# 3. Thanh Thời Gian Thu Hoạch (Harvest Progress Bar)
		var harvest_r := Rect2(-bar_w * 0.5, -13.0, bar_w, bar_h)
		draw_rect(harvest_r, Color(0.08, 0.08, 0.1, 0.85), true)
		draw_rect(harvest_r, Color(0.35, 0.35, 0.35, 0.8), false, 1.0)

		var prog := a.get_progress()
		if prog > 0.0:
			var fill_col := Color(1.0, 0.85, 0.2) if a.state == LivestockManager.AnimalState.READY else Color(0.2, 0.75, 1.0)
			draw_rect(Rect2(harvest_r.position, Vector2(bar_w * prog, bar_h)), fill_col, true)

		# 4. Hiệu ứng viền sáng khi sẵn sàng thu hoạch (không hiển thị text)
		if a.state == LivestockManager.AnimalState.READY:
			var pulse := 0.75 + 0.25 * sin(anim_blink)
			draw_rect(harvest_r, Color(1.0, 0.95, 0.4, pulse), false, 1.5)

func _init() -> void:
	add_to_group("livestock_zones")

func _ready() -> void:
	z_index = -4
	add_to_group("livestock_zones")
	farm_mgr = get_node_or_null("/root/FarmManager")
	if farm_mgr != null:
		farm_mgr.farm_data_changed.connect(_setup_animal_sprites)
	_calculate_pen_areas()
	_setup_animal_sprites()

## Kiểm tra toạ độ thế giới có nằm trong vòng nuôi thú này không
func contains_world_point(world_pos: Vector2) -> bool:
	var center: Vector2 = global_position if is_inside_tree() else position
	if world_pos.distance_to(center) <= 1600.0 or world_pos.distance_to(LIVESTOCK_CENTER_WORLD) <= 1600.0:
		return true
	var local_p := to_local(world_pos) if is_inside_tree() else (world_pos - position)
	if Geometry2D.is_point_in_polygon(local_p, PASTURE_POLYGON):
		return true
	if _is_point_near_pasture(local_p, 250.0):
		return true
	if PASTURE_BOUNDS.grow(250.0).has_point(local_p):
		return true
	return false

func _is_point_near_pasture(local_p: Vector2, margin: float) -> bool:
	if not PASTURE_BOUNDS.grow(margin).has_point(local_p):
		return false
	var n_pts := PASTURE_POLYGON.size()
	for i in range(n_pts):
		var p1 := PASTURE_POLYGON[i]
		var p2 := PASTURE_POLYGON[(i + 1) % n_pts]
		var closest := Geometry2D.get_closest_point_to_segment(local_p, p1, p2)
		if local_p.distance_to(closest) <= margin:
			return true
	return false

## Thả con vật vào vòng nuôi này
func release_animal_here(animal_data: Dictionary, spawn_pos: Vector2 = Vector2.ZERO) -> bool:
	if farm_mgr == null:
		farm_mgr = get_node_or_null("/root/FarmManager")
	if farm_mgr == null or farm_mgr.livestock_mgr == null:
		return false
	var ok: bool = farm_mgr.livestock_mgr.adopt_animal(animal_data)
	if ok:
		farm_mgr.save_farm_data()
		farm_mgr.farm_data_changed.emit()
		var anim_name: String = str(animal_data.get("name", "Vật nuôi"))
		var local_spawn := to_local(spawn_pos) if (spawn_pos != Vector2.ZERO and is_inside_tree()) else Vector2(0, -80)
		_show_floating_text("✨ Đã thả %s vào %s!" % [anim_name, zone_name], local_spawn)
	return ok

## Tĩnh: Tìm vùng nuôi thú mà world_pos đang thuộc về
static func get_zone_at_world_pos(tree: SceneTree, world_pos: Vector2) -> LivestockController:
	if tree == null:
		return null
	var zones = tree.get_nodes_in_group("livestock_zones")
	for z in zones:
		if z is LivestockController and z.contains_world_point(world_pos):
			return z
	return null

## Tĩnh: Kiểm tra xem Player có đang đứng trong bất kỳ vùng nuôi thú nào trên bản đồ hay không
static func check_player_in_zone(tree: SceneTree) -> Dictionary:
	if tree == null:
		return {"inside": false, "zone": null, "msg": "Không có SceneTree!"}
	var player = tree.get_first_node_in_group("player") as Node2D
	if (player == null or not is_instance_valid(player)) and tree.root != null:
		player = tree.root.find_child("Player", true, false) as Node2D
		if player == null:
			player = tree.root.find_child("player", true, false) as Node2D

	if player == null or not is_instance_valid(player):
		return {"inside": false, "zone": null, "msg": "Không xác định được vị trí người chơi!"}

	var ppos: Vector2 = player.global_position
	var zones = tree.get_nodes_in_group("livestock_zones")
	if tree.root != null:
		var fallback_node = tree.root.find_child("LivestockController", true, false)
		if fallback_node != null and not zones.has(fallback_node):
			zones.append(fallback_node)

	for z in zones:
		if z != null and z.has_method("contains_world_point") and z.contains_world_point(ppos):
			var z_title: String = str(z.get("zone_name")) if ("zone_name" in z and str(z.get("zone_name")) != "") else "Vòng Nuôi Thú Sơn Trang [194/193]"
			return {
				"inside": true,
				"zone": z,
				"zone_name": z_title,
				"player_pos": ppos
			}

	# Fallback kiểm tra khoảng cách đến tâm khu chăn nuôi [194/193] hoặc NPC Trương Bá [195/192]
	var dist_center := ppos.distance_to(LIVESTOCK_CENTER_WORLD)
	var dist_npc := ppos.distance_to(Vector2(50048.0, 49280.0))
	if dist_center <= 1800.0 or dist_npc <= 1200.0:
		var zone_inst = null
		if not zones.is_empty():
			zone_inst = zones[0]
		elif tree.root != null:
			zone_inst = tree.root.find_child("LivestockController", true, false)
		return {
			"inside": true,
			"zone": zone_inst,
			"zone_name": "Vòng Nuôi Thú Sơn Trang [194/193]",
			"player_pos": ppos
		}

	return {
		"inside": false,
		"zone": null,
		"player_pos": ppos,
		"msg": "Đại hiệp cần đứng trong Vòng Nuôi Thú mới có thể thả con vật!"
	}

func _calculate_pen_areas() -> void:
	_pen_areas.clear()
	var offsets = [
		Vector2(-PEN_W - 14.0, -PEN_H - 14.0),
		Vector2(14.0, -PEN_H - 14.0),
		Vector2(-PEN_W - 14.0, 14.0),
		Vector2(14.0, 14.0)
	]
	for off in offsets:
		_pen_areas.append(Rect2(off, Vector2(PEN_W, PEN_H)))

func _setup_animal_sprites() -> void:
	if farm_mgr == null or farm_mgr.livestock_mgr == null:
		return

	var animals = farm_mgr.livestock_mgr.animals

	# 1. Giữ nguyên các node con thú đang đi lại bình thường, chỉ xóa node của con bị mất (thu hoạch)
	var remaining_nodes: Array[AnimalWanderer] = []
	for n in _animal_nodes:
		if not is_instance_valid(n):
			continue
		var still_exists := false
		for a in animals:
			if n.animal_info == a:
				still_exists = true
				break
		if still_exists:
			remaining_nodes.append(n)
		else:
			# Chỉ xóa node của con thú vừa bị thu hoạch, KHÔNG làm ảnh hưởng các con thú khác!
			n.queue_free()

	_animal_nodes = remaining_nodes

	# 2. Chỉ tạo mới node cho những con thú mới nhận nuôi mà chưa có node trên bản đồ
	for i in range(animals.size()):
		var a: LivestockManager.AnimalInfo = animals[i]
		var found_node: AnimalWanderer = null
		for n in _animal_nodes:
			if n.animal_info == a:
				found_node = n
				n.pen_idx = i
				break

		if found_node == null:
			var pen_r: Rect2 = _pen_areas[i % _pen_areas.size()] if not _pen_areas.is_empty() else Rect2(-50, -50, 100, 100)
			var roam_outside: bool = a.is_roaming_outside and all_roaming_outside
			var wanderer := AnimalWanderer.new(a, pen_r, PASTURE_POLYGON, PASTURE_BOUNDS, i, roam_outside)
			wanderer.name = "Wanderer_%s_%d" % [a.animal_id, i]
			add_child(wanderer)
			_animal_nodes.append(wanderer)

## Chuyển đổi giữa chế độ thả rông ngoài bãi cỏ và đưa vào chuồng
func toggle_all_roam_outside() -> bool:
	all_roaming_outside = not all_roaming_outside
	if farm_mgr and farm_mgr.livestock_mgr:
		farm_mgr.livestock_mgr.set_all_roaming_outside(all_roaming_outside)
	for w in _animal_nodes:
		if is_instance_valid(w):
			w.set_roam_outside(all_roaming_outside)
	var msg := "🐾 Đã mở cổng! Toàn bộ thú nuôi đang di chuyển dạo chơi ngoài trời!" if all_roaming_outside else "🐑 Đã lùa đàn thú nuôi trở về chuồng nghỉ ngơi!"
	_show_floating_text(msg, Vector2(0, -180))
	return all_roaming_outside

func _process(_delta: float) -> void:
	queue_redraw()

static func _get_farm_font() -> Font:
	if ClassDB.class_exists("GameUi") or ResourceLoader.exists("res://ui/common/game_ui.gd"):
		var gf = GameUi.game_font()
		if gf != null:
			return gf
	var t := ThemeDB.get_project_theme()
	if t and t.default_font:
		return t.default_font
	return ThemeDB.fallback_font

func _draw() -> void:
	if farm_mgr == null or farm_mgr.livestock_mgr == null:
		return

	var font := _get_farm_font()

	# 1. Vẽ Hàng rào gỗ bao quanh bãi chăn thả theo 5 điểm mốc
	var poly := PASTURE_POLYGON
	var n_pts := poly.size()
	var fence_col := Color(0.72, 0.54, 0.32, 0.95)
	var fence_shadow := Color(0.25, 0.16, 0.08, 0.85)
	var post_col := Color(0.55, 0.38, 0.20, 1.0)
	var post_cap := Color(0.90, 0.72, 0.40, 1.0)

	for i in range(n_pts):
		var p1 := poly[i]
		var p2 := poly[(i + 1) % n_pts]
		draw_line(p1, p2, fence_shadow, 3.5)
		draw_line(p1, p2, fence_col, 2.0)

		# Cọc phụ cách đều nhau
		var seg_len := p1.distance_to(p2)
		var num_sub_posts := int(seg_len / 128.0)
		for j in range(num_sub_posts):
			var t := float(j + 1) / float(num_sub_posts + 1)
			var post_pos := p1.lerp(p2, t)
			draw_circle(post_pos, 3.5, post_col)

		# Cọc gỗ chính tại các mốc tọa độ
		draw_circle(p1, 6.0, post_col)
		draw_circle(p1, 3.5, post_cap)

		# Nhãn hiển thị tọa độ tại từng đỉnh mốc
		if font and i < PASTURE_COORDS.size():
			var c := PASTURE_COORDS[i]
			var coord_str := "%d/%d" % [c.x, c.y]
			var offset_dir := (p1 - Vector2.ZERO).normalized() * 18.0
			draw_string_outline(font, p1 + offset_dir, coord_str, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, 2, Color.BLACK)
			draw_string(font, p1 + offset_dir, coord_str, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(1.0, 0.95, 0.6))

	# 2. Bảng tên khu chăn nuôi trên hàng rào
	if font:
		var has_sheep := font.has_char(0x1F40F)
		var has_paw := font.has_char(0x1F43E)
		var status_str := (" [ĐANG THẢ RÔNG%s]" % (" 🐾" if has_paw else "")) if all_roaming_outside else (" [ĐANG Ở TRONG CHUỒNG%s]" % (" 🐑" if has_sheep else ""))
		var title_pos := Vector2(-360, -528)
		var sheep_prefix := "🐑 " if has_sheep else ""
		var full_title := "%sBÃI CHĂN THẢ GIA SÚC (188/191 → 198/192 → 199/194 → 193/195 → 187/194)%s" % [sheep_prefix, status_str]
		draw_string_outline(font, title_pos, full_title, HORIZONTAL_ALIGNMENT_CENTER, 720, 13, 2, Color.BLACK)
		draw_string(font, title_pos, full_title, HORIZONTAL_ALIGNMENT_CENTER, 720, 13, Color(1.0, 0.92, 0.45))


func _close_all_farm_modals() -> void:
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var layer = tree.root.get_node_or_null("FarmModalLayer")
	if layer and is_instance_valid(layer):
		for child in layer.get_children():
			child.queue_free()
	for modal_name in ["PlotUnlockModal", "LuongActionModal", "SeedPickerModal", "AnimalActionModal", "FishActionModal"]:
		var existing = tree.root.get_node_or_null(modal_name)
		if existing and is_instance_valid(existing):
			existing.queue_free()

func _get_or_create_modal_layer() -> CanvasLayer:
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var layer = tree.root.get_node_or_null("FarmModalLayer") as CanvasLayer
	if layer == null or not is_instance_valid(layer):
		layer = CanvasLayer.new()
		layer.name = "FarmModalLayer"
		layer.layer = 120
		tree.root.add_child(layer)
	return layer

func _attach_modal(win: Control, win_size: Vector2) -> void:
	win.custom_minimum_size = win_size
	win.size = win_size

	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var vp_size := Vector2(1280, 720)
	var root_vp = tree.root if (tree and tree.root) else null
	if root_vp:
		var vs := root_vp.get_visible_rect().size
		if vs.x > 300 and vs.y > 300:
			vp_size = vs
	win.position = Vector2(
		(vp_size.x - win_size.x) * 0.5,
		(vp_size.y - win_size.y) * 0.5
	).round()

	win.mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_drag_window(win)

	var layer := _get_or_create_modal_layer()
	if layer != null:
		layer.add_child(win)
	elif root_vp != null:
		root_vp.add_child(win)
	else:
		add_child(win)

func _setup_drag_window(win: Control) -> void:
	var is_dragging := [false]
	var drag_start_mouse := [Vector2.ZERO]
	var drag_start_win_pos := [Vector2.ZERO]

	win.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			win.accept_event()
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_dragging[0] = true
					drag_start_mouse[0] = event.global_position
					drag_start_win_pos[0] = win.position
					win.move_to_front()
				else:
					is_dragging[0] = false
		elif event is InputEventMouseMotion and is_dragging[0]:
			win.accept_event()
			var delta: Vector2 = event.global_position - drag_start_mouse[0]
			var new_pos: Vector2 = drag_start_win_pos[0] + delta
			var vp := win.get_viewport_rect().size
			if vp.x > 0 and vp.y > 0:
				new_pos.x = clampf(new_pos.x, 0.0, maxf(0.0, vp.x - win.size.x))
				new_pos.y = clampf(new_pos.y, 0.0, maxf(0.0, vp.y - win.size.y))
			win.position = new_pos
	)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_world := get_global_mouse_position()
		var screen_mouse := get_viewport().get_mouse_position()
		var local_pos := to_local(mouse_world)

		# 0. Nếu đang có bất kỳ modal nông trại / con thú nào mở:
		var modal_layer = get_tree().root.get_node_or_null("FarmModalLayer")
		if modal_layer and is_instance_valid(modal_layer):
			for child in modal_layer.get_children():
				if child is Control and is_instance_valid(child) and not child.is_queued_for_deletion() and child.is_visible_in_tree():
					var local_m := (child as Control).get_local_mouse_position()
					if Rect2(Vector2.ZERO, (child as Control).size).has_point(local_m) or (child as Control).get_global_rect().has_point(screen_mouse):
						return
		var current_modal = get_tree().root.get_node_or_null("AnimalActionModal") as Control
		if current_modal and is_instance_valid(current_modal) and current_modal.is_visible_in_tree():
			var local_m := current_modal.get_local_mouse_position()
			if Rect2(Vector2.ZERO, current_modal.size).has_point(local_m) or current_modal.get_global_rect().has_point(screen_mouse):
				return

		# 1. Kiểm tra xem người chơi có đang nhấp vào con thú nào hay không (Chuột trái hoặc chuột phải)
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			for i in range(_animal_nodes.size()):
				var w: AnimalWanderer = _animal_nodes[i]
				if not is_instance_valid(w):
					continue
				var center: Vector2 = w.global_position + Vector2(0, -25.0)
				var head_hud_rect := Rect2(w.global_position.x - 45.0, w.global_position.y - 75.0, 90.0, 90.0)
				if head_hud_rect.has_point(mouse_world) or center.distance_to(mouse_world) <= 45.0:
					get_viewport().set_input_as_handled()
					_close_all_farm_modals()
					_open_animal_action_modal(i)
					return

		# 2. Click vào bảng hiệu tiêu đề để chuyển đổi Thả Ngoài / Vào Chuồng
		if event.button_index == MOUSE_BUTTON_LEFT:
			var title_rect := Rect2(Vector2(-360, -548), Vector2(720, 36))
			if title_rect.has_point(local_pos):
				get_viewport().set_input_as_handled()
				toggle_all_roam_outside()
				return

		# 3. Nếu đang có modal con thú mở và người chơi click ra ngoài vùng trống -> Tự động đóng modal
		if current_modal and is_instance_valid(current_modal) and current_modal.is_visible_in_tree():
			current_modal.queue_free()

## Xử lý khi người chơi nhấp chuột trái vào thú nuôi -> Luôn mở bảng tương tác chi tiết
func _on_animal_clicked(idx: int, _w: AnimalWanderer) -> void:
	if farm_mgr == null or farm_mgr.livestock_mgr == null:
		return
	var animals = farm_mgr.livestock_mgr.animals
	if idx < 0 or idx >= animals.size():
		return
	_close_all_farm_modals()
	_open_animal_action_modal(idx)

## Định dạng phong cách nút bấm theo chuẩn Kiếm Hiệp Wuxia giống Luống Đất (Ảnh 2: nền ngọc thạch tối, viền kim sắc, canh lề trái)
func _apply_prominent_button_style(btn: Button, _bg_normal: Color = Color.TRANSPARENT, _border_color: Color = Color.TRANSPARENT, font_color: Color = Color.WHITE, radius: int = 6) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.16, 0.18, 0.95)
	normal.border_color = Color(0.72, 0.58, 0.28, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(radius)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.09, 0.26, 0.28, 1.0)
	hover.border_color = Color(1.0, 0.88, 0.45, 1.0)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.04, 0.13, 0.15, 0.95)
	pressed.border_color = Color(0.72, 0.58, 0.28, 0.85)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.08, 0.10, 0.12, 0.6)
	disabled.border_color = Color(0.35, 0.35, 0.35, 0.4)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(radius)
	disabled.content_margin_left = 14
	disabled.content_margin_right = 14
	disabled.content_margin_top = 5
	disabled.content_margin_bottom = 5

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", font_color if font_color != Color.WHITE else Color(0.95, 0.95, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.60, 0.7))
	btn.add_theme_font_size_override("font_size", 13)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

## Bảng Tùy Chọn Đầy Đủ khi tương tác với thú nuôi:
## - Bên Trái: Thông tin thú, Thời gian thu hoạch, Mức đói, Mức nước, Nút "Cho ăn", "Uống nước", "Thu hoạch"
## - Bên Phải: Kho nguyên liệu phân rõ Thực phẩm, Nước uống còn lại và nút Mua thêm nhanh
func _open_animal_action_modal(idx: int) -> void:
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var old_modal = tree.root.get_node_or_null("AnimalActionModal")
		if old_modal:
			old_modal.queue_free()

	if farm_mgr == null or farm_mgr.livestock_mgr == null:
		return
	var animals = farm_mgr.livestock_mgr.animals
	if idx >= animals.size():
		return
	var a: LivestockManager.AnimalInfo = animals[idx]

	var win := PanelContainer.new()
	win.name = "AnimalActionModal"

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.10, 0.12, 0.98)
	bg.border_color = Color(0.95, 0.78, 0.25)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 14
	bg.content_margin_top = 10
	bg.content_margin_right = 14
	bg.content_margin_bottom = 10
	win.add_theme_stylebox_override("panel", bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	win.add_child(root_vbox)

	# 1. Header
	var header := HBoxContainer.new()
	var stars := ""
	for s in range(a.level):
		stars += "⭐"
	var title_lbl := Label.new()
	title_lbl.text = "🐾 %s (%s CẤP %d/5)" % [a.name, stars, a.level]
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title_lbl.add_theme_font_size_override("font_size", 14)
	header.add_child(title_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(win.queue_free)
	header.add_child(close_btn)
	root_vbox.add_child(header)

	# 2. Main 2-Side Layout
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 12)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(main_hbox)

	# ===================== BÊN TRÁI: THÔNG TIN VẬT NUÔI & THAO TÁC =====================
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(left_vbox)

	# Khung trạng thái
	var status_panel := PanelContainer.new()
	var sp_bg := StyleBoxFlat.new()
	sp_bg.bg_color = Color(0.14, 0.16, 0.19, 0.95)
	sp_bg.border_color = Color(0.3, 0.35, 0.42)
	sp_bg.set_border_width_all(1)
	sp_bg.set_corner_radius_all(6)
	sp_bg.content_margin_left = 10
	sp_bg.content_margin_top = 8
	sp_bg.content_margin_right = 10
	sp_bg.content_margin_bottom = 8
	status_panel.add_theme_stylebox_override("panel", sp_bg)

	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 6)
	status_panel.add_child(status_vbox)

	# 2.1 Thời gian thu hoạch
	var harvest_box := VBoxContainer.new()
	harvest_box.add_theme_constant_override("separation", 2)
	var harvest_lbl := Label.new()
	harvest_lbl.add_theme_font_size_override("font_size", 11)
	harvest_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	harvest_box.add_child(harvest_lbl)

	var harvest_bar := ProgressBar.new()
	harvest_bar.min_value = 0.0
	harvest_bar.max_value = 100.0
	harvest_bar.value = a.get_progress() * 100.0
	harvest_bar.custom_minimum_size = Vector2(0, 10)
	harvest_bar.show_percentage = false
	var hv_fill := StyleBoxFlat.new()
	hv_fill.bg_color = Color(0.2, 0.75, 1.0)
	hv_fill.set_corner_radius_all(3)
	harvest_bar.add_theme_stylebox_override("fill", hv_fill)
	harvest_box.add_child(harvest_bar)
	status_vbox.add_child(harvest_box)

	# 2.2 Mức đói
	var hunger_box := VBoxContainer.new()
	hunger_box.add_theme_constant_override("separation", 2)
	var hunger_lbl := Label.new()
	hunger_lbl.add_theme_font_size_override("font_size", 11)
	hunger_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	hunger_box.add_child(hunger_lbl)

	var hunger_bar := ProgressBar.new()
	hunger_bar.min_value = 0.0
	hunger_bar.max_value = 100.0
	hunger_bar.value = a.hunger
	hunger_bar.custom_minimum_size = Vector2(0, 10)
	hunger_bar.show_percentage = false
	var hb_fill := StyleBoxFlat.new()
	hb_fill.bg_color = Color(0.25, 0.85, 0.35)
	hb_fill.set_corner_radius_all(3)
	hunger_bar.add_theme_stylebox_override("fill", hb_fill)
	hunger_box.add_child(hunger_bar)
	status_vbox.add_child(hunger_box)

	# 2.3 Mức nước (Khát)
	var thirst_box := VBoxContainer.new()
	thirst_box.add_theme_constant_override("separation", 2)
	var thirst_lbl := Label.new()
	thirst_lbl.add_theme_font_size_override("font_size", 11)
	thirst_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	thirst_box.add_child(thirst_lbl)

	var thirst_bar := ProgressBar.new()
	thirst_bar.min_value = 0.0
	thirst_bar.max_value = 100.0
	thirst_bar.value = a.thirst
	thirst_bar.custom_minimum_size = Vector2(0, 10)
	thirst_bar.show_percentage = false
	var th_fill := StyleBoxFlat.new()
	th_fill.bg_color = Color(0.3, 0.65, 0.95)
	th_fill.set_corner_radius_all(3)
	thirst_bar.add_theme_stylebox_override("fill", th_fill)
	thirst_box.add_child(thirst_bar)
	status_vbox.add_child(thirst_box)

	# 2.4 Thông tin sản phẩm & thân mật
	var extra_info_lbl := Label.new()
	extra_info_lbl.add_theme_font_size_override("font_size", 11)
	extra_info_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	status_vbox.add_child(extra_info_lbl)
	left_vbox.add_child(status_panel)

	# DANH SÁCH THAO TÁC VẬT NUÔI (DẠNG DANH SÁCH DỌC - FULL WIDTH)
	var action_list := VBoxContainer.new()
	action_list.add_theme_constant_override("separation", 6)

	# 1. Hàng nút Cho Ăn: [Cho Ăn] và [Cho Ăn Hàng Loạt]
	var feed_row := HBoxContainer.new()
	feed_row.add_theme_constant_override("separation", 6)

	var feed_btn := Button.new()
	feed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_btn.custom_minimum_size = Vector2(0, 32)
	feed_btn.focus_mode = Control.FOCUS_NONE
	feed_btn.text = "🌾 Cho Ăn"
	feed_btn.tooltip_text = "Cho con thú này ăn nông sản / cá tươi có sẵn trong rương"
	_apply_prominent_button_style(feed_btn, Color(0.16, 0.46, 0.2, 0.96), Color(0.55, 0.95, 0.45), Color(0.95, 1.0, 0.92))
	feed_row.add_child(feed_btn)

	var batch_feed_btn := Button.new()
	batch_feed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	batch_feed_btn.custom_minimum_size = Vector2(0, 32)
	batch_feed_btn.focus_mode = Control.FOCUS_NONE
	batch_feed_btn.text = "🌾 Cho Ăn Hàng Loạt"
	batch_feed_btn.tooltip_text = "Tự động cho ăn hàng loạt toàn bộ đàn thú đang đói bụng trong bãi nuôi"
	_apply_prominent_button_style(batch_feed_btn, Color(0.18, 0.44, 0.22, 0.96), Color(0.65, 0.95, 0.50), Color(0.95, 1.0, 0.92))
	feed_row.add_child(batch_feed_btn)

	action_list.add_child(feed_row)

	# 2. Hàng nút Uống Nước: [Cho Uống Nước] và [Cho Uống Hàng Loạt]
	var water_row := HBoxContainer.new()
	water_row.add_theme_constant_override("separation", 6)

	var water_btn := Button.new()
	water_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	water_btn.custom_minimum_size = Vector2(0, 32)
	water_btn.focus_mode = Control.FOCUS_NONE
	water_btn.text = "💧 Cho Uống Nước"
	water_btn.tooltip_text = "Cho con thú này uống nước để giải khát và tiếp tục lớn"
	_apply_prominent_button_style(water_btn, Color(0.12, 0.38, 0.68, 0.96), Color(0.45, 0.85, 1.0), Color(0.92, 0.98, 1.0))
	water_row.add_child(water_btn)

	var batch_water_btn := Button.new()
	batch_water_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	batch_water_btn.custom_minimum_size = Vector2(0, 32)
	batch_water_btn.focus_mode = Control.FOCUS_NONE
	batch_water_btn.text = "💧 Cho Uống Hàng Loạt"
	batch_water_btn.tooltip_text = "Tự động cho uống nước hàng loạt toàn bộ đàn thú đang khát trong bãi nuôi"
	_apply_prominent_button_style(batch_water_btn, Color(0.14, 0.40, 0.72, 0.96), Color(0.55, 0.90, 1.0), Color(0.92, 0.98, 1.0))
	water_row.add_child(batch_water_btn)

	action_list.add_child(water_row)

	var harvest_btn := Button.new()
	harvest_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harvest_btn.custom_minimum_size = Vector2(0, 32)
	harvest_btn.focus_mode = Control.FOCUS_NONE
	harvest_btn.text = "⏳ Chưa Lớn"
	_apply_prominent_button_style(harvest_btn, Color(0.28, 0.24, 0.36, 0.96), Color(0.72, 0.62, 0.85), Color(0.92, 0.9, 0.98))
	action_list.add_child(harvest_btn)

	var pet_btn := Button.new()
	pet_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_btn.custom_minimum_size = Vector2(0, 32)
	pet_btn.text = "🐾 Vuốt Ve Yêu Thương (+10 Thân Mật)"
	pet_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(pet_btn, Color(0.52, 0.22, 0.4, 0.96), Color(1.0, 0.65, 0.85), Color(1.0, 0.95, 0.98))
	pet_btn.pressed.connect(func():
		var res = farm_mgr.livestock_mgr.pet_animal(idx)
		farm_mgr.save_farm_data()
		_show_floating_text(res.get("msg", "🐾 Vuốt ve vui vẻ!"), global_position)
	)
	action_list.add_child(pet_btn)

	var is_current_companion: bool = (farm_mgr != null and "active_companion" in farm_mgr and farm_mgr.active_companion is Dictionary and str(farm_mgr.active_companion.get("animal_id", "")) == a.animal_id)
	var comp_btn := Button.new()
	comp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comp_btn.custom_minimum_size = Vector2(0, 32)
	comp_btn.text = "✓ Đang Đi Cùng Bạn" if is_current_companion else "🐾 Dắt Theo Làm Bạn Đồng Hành"
	comp_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(comp_btn, Color(0.15, 0.44, 0.48, 0.96), Color(0.4, 0.95, 0.88), Color(0.92, 1.0, 0.98))
	comp_btn.pressed.connect(func():
		if is_current_companion:
			farm_mgr.clear_active_companion()
			_show_floating_text("🐑 %s đã trở về nông trại!" % a.name, global_position)
		else:
			farm_mgr.set_active_companion(a.to_dict())
			_show_floating_text("✨ %s đã làm Bạn Đồng Hành cùng bạn!" % a.name, global_position)
		win.queue_free()
	)
	action_list.add_child(comp_btn)

	# Nâng cấp chuồng trại
	if a.level < 5:
		var up_pen_btn := Button.new()
		var next_lvl := a.level + 1
		var cost := a.level * 150
		up_pen_btn.text = "⭐ Nâng Cấp Chuồng Cấp %d (%d Lượng)" % [next_lvl, cost]
		up_pen_btn.custom_minimum_size = Vector2(0, 32)
		up_pen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up_pen_btn.focus_mode = Control.FOCUS_NONE
		_apply_prominent_button_style(up_pen_btn, Color(0.22, 0.42, 0.25, 0.95), Color(0.6, 0.95, 0.5), Color(1.0, 1.0, 0.9), 5)
		up_pen_btn.pressed.connect(func():
			if farm_mgr and farm_mgr.buy_item_with_currency(cost, 0):
				var res = farm_mgr.livestock_mgr.upgrade_animal(idx)
				farm_mgr.save_farm_data()
				_show_floating_text(res.get("msg", "Đã nâng cấp chuồng!"), global_position)
				win.queue_free()
			else:
				up_pen_btn.text = "Không đủ ngân lượng!"
		)
		action_list.add_child(up_pen_btn)

	left_vbox.add_child(action_list)

	# ===================== BÊN PHẢI: KHO NGUYÊN LIỆU (THỰC PHẨM & NƯỚC) =====================
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(230, 0)
	var rp_bg := StyleBoxFlat.new()
	rp_bg.bg_color = Color(0.12, 0.14, 0.17, 0.98)
	rp_bg.border_color = Color(0.75, 0.65, 0.25)
	rp_bg.set_border_width_all(1)
	rp_bg.set_corner_radius_all(6)
	rp_bg.content_margin_left = 10
	rp_bg.content_margin_top = 8
	rp_bg.content_margin_right = 10
	rp_bg.content_margin_bottom = 8
	right_panel.add_theme_stylebox_override("panel", rp_bg)
	main_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	var right_title := Label.new()
	right_title.text = "📦 NGUYÊN LIỆU TRONG KHO"
	right_title.add_theme_font_size_override("font_size", 12)
	right_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(right_title)

	right_vbox.add_child(HSeparator.new())

	# Box Thực Phẩm
	var feed_box := VBoxContainer.new()
	feed_box.add_theme_constant_override("separation", 3)
	var feed_h := Label.new()
	feed_h.text = "🌾 THỨC ĂN (NÔNG SẢN & CÁ):"
	feed_h.add_theme_font_size_override("font_size", 11)
	feed_h.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	feed_box.add_child(feed_h)

	var feed_stock_lbl := Label.new()
	feed_stock_lbl.add_theme_font_size_override("font_size", 11)
	feed_box.add_child(feed_stock_lbl)

	var feed_tip_lbl := Label.new()
	feed_tip_lbl.text = "(Tự trồng trọt hoặc câu/nuôi cá)"
	feed_tip_lbl.add_theme_font_size_override("font_size", 10)
	feed_tip_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
	feed_box.add_child(feed_tip_lbl)
	right_vbox.add_child(feed_box)

	right_vbox.add_child(HSeparator.new())

	# Box Nước Uống
	var water_box := VBoxContainer.new()
	water_box.add_theme_constant_override("separation", 3)
	var water_h := Label.new()
	water_h.text = "💧 NƯỚC UỐNG GIA SÚC:"
	water_h.add_theme_font_size_override("font_size", 11)
	water_h.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	water_box.add_child(water_h)

	var water_stock_lbl := Label.new()
	water_stock_lbl.add_theme_font_size_override("font_size", 11)
	water_box.add_child(water_stock_lbl)

	var buy_water_btn := Button.new()
	buy_water_btn.text = "[+] Lấy Nước (5 Lg / 10)"
	buy_water_btn.custom_minimum_size = Vector2(0, 30)
	buy_water_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(buy_water_btn, Color(0.12, 0.32, 0.52, 0.95), Color(0.4, 0.8, 1.0), Color(0.9, 0.98, 1.0), 5)
	buy_water_btn.pressed.connect(func():
		if farm_mgr and farm_mgr.buy_item_with_currency(5, 0):
			farm_mgr.add_to_chest("fresh_water_pot", 10, true)
			farm_mgr.save_farm_data()
			_show_floating_text("Đã lấy thêm 10 Bình Nước Sạch!", global_position)
		else:
			_show_floating_text("Không đủ ngân lượng!", global_position)
	)
	water_box.add_child(buy_water_btn)
	right_vbox.add_child(water_box)

	right_vbox.add_child(HSeparator.new())

	# Box Ngân Lượng
	var gold_lbl := Label.new()
	gold_lbl.add_theme_font_size_override("font_size", 11)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	right_vbox.add_child(gold_lbl)

	# Cập nhật thông số trực tiếp mỗi 0.25s
	var update_stats := func():
		if not is_instance_valid(win) or a == null or farm_mgr == null:
			return

		# 1. Mức đói
		hunger_bar.value = a.hunger
		var h_pct := int(a.hunger / a.max_hunger * 100.0)
		var h_desc := "No nê" if a.hunger > 50.0 else ("Bình thường" if a.hunger > 0.0 else "ĐÓI BỤNG (Tạm dừng)")
		hunger_lbl.text = "🍖 Mức Đói: %d / %d (%d%% — %s)" % [int(a.hunger), int(a.max_hunger), h_pct, h_desc]
		if a.hunger <= 0.0:
			hb_fill.bg_color = Color(0.9, 0.2, 0.2)
		elif a.hunger <= 40.0:
			hb_fill.bg_color = Color(1.0, 0.65, 0.2)
		else:
			hb_fill.bg_color = Color(0.25, 0.85, 0.35)

		# 2. Mức nước
		thirst_bar.value = a.thirst
		var t_pct := int(a.thirst / a.max_thirst * 100.0)
		var t_desc := "Đủ nước" if a.thirst > 50.0 else ("Bình thường" if a.thirst > 0.0 else "KHÁT NƯỚC (Tạm dừng)")
		thirst_lbl.text = "💧 Mức Nước: %d / %d (%d%% — %s)" % [int(a.thirst), int(a.max_thirst), t_pct, t_desc]
		if a.thirst <= 0.0:
			th_fill.bg_color = Color(0.9, 0.2, 0.2)
		elif a.thirst <= 40.0:
			th_fill.bg_color = Color(1.0, 0.65, 0.2)
		else:
			th_fill.bg_color = Color(0.3, 0.65, 0.95)

		# 3. Thời gian thu hoạch
		var prog_pct := int(a.get_progress() * 100.0)
		harvest_bar.value = prog_pct

		var is_ready := (a.state == LivestockManager.AnimalState.READY or a.get_progress() >= 1.0)
		if is_ready:
			harvest_btn.text = "✨ THU HOẠCH SẢN PHẨM NGAY ✨"
			_apply_prominent_button_style(harvest_btn, Color(0.72, 0.52, 0.12, 0.96), Color(1.0, 0.95, 0.45), Color(1.0, 1.0, 0.85))
		else:
			harvest_btn.text = "⏳ Chưa Lớn (%d%%)" % prog_pct
			_apply_prominent_button_style(harvest_btn, Color(0.28, 0.24, 0.36, 0.96), Color(0.72, 0.62, 0.85), Color(0.92, 0.9, 0.98))
		harvest_btn.disabled = false

		if is_ready:
			harvest_lbl.text = "✨ ĐÃ LỚN! SẴN SÀNG THU HOẠCH! (100%)"
			harvest_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			hv_fill.bg_color = Color(1.0, 0.85, 0.2)
		elif a.hunger <= 0.0:
			harvest_lbl.text = "⏸ TẠM DỪNG: Thú đang đói bụng! Cho ăn để tiếp tục."
			harvest_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
			hv_fill.bg_color = Color(0.6, 0.6, 0.6)
		elif a.thirst <= 0.0:
			harvest_lbl.text = "⏸ TẠM DỪNG: Thú đang khát nước! Cho uống để tiếp tục."
			harvest_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			hv_fill.bg_color = Color(0.6, 0.6, 0.6)
		else:
			var rem_sec := int(a.get_remaining_time())
			var mins := rem_sec / 60
			var secs := rem_sec % 60
			harvest_lbl.text = "⏳ Thời Gian Thu Hoạch Còn: %02d:%02d (Tiến độ %d%%)" % [mins, secs, prog_pct]
			harvest_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
			hv_fill.bg_color = Color(0.2, 0.75, 1.0)

		extra_info_lbl.text = "❤️ Thân mật: %d | 📦 Thu hoạch nhận: %s (+%d Exp)" % [
			a.intimacy, a.product_name, a.exp_reward
		]

		# 4. Kho nguyên liệu bên phải
		var feed_cnt: int = int(farm_mgr.get_feed_count()) if farm_mgr != null else 0
		feed_stock_lbl.text = "Hiện có: %d phần" % feed_cnt
		feed_stock_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if feed_cnt > 0 else Color(1.0, 0.4, 0.4))

		var water_cnt: int = int(farm_mgr.get_water_count()) if farm_mgr != null else 0
		water_stock_lbl.text = "Hiện có: %d bình nước" % water_cnt
		water_stock_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if water_cnt > 0 else Color(1.0, 0.4, 0.4))

		var current_gold := 0
		if farm_mgr != null and farm_mgr.has_method("get_player_gold"):
			current_gold = farm_mgr.get_player_gold()
		elif farm_mgr != null and "currency_gold" in farm_mgr:
			current_gold = int(farm_mgr.currency_gold)
		gold_lbl.text = "💰 Ngân Lượng: %d Lượng" % current_gold

		var any_hungry := false
		var any_thirsty := false
		if farm_mgr != null and farm_mgr.livestock_mgr != null:
			for other_a in farm_mgr.livestock_mgr.animals:
				if other_a.state != LivestockManager.AnimalState.READY and other_a.get_progress() < 1.0:
					if other_a.hunger < other_a.max_hunger:
						any_hungry = true
					if other_a.thirst < other_a.max_thirst:
						any_thirsty = true
				if any_hungry and any_thirsty:
					break

		if is_ready:
			feed_btn.disabled = true
			water_btn.disabled = true
		else:
			feed_btn.disabled = (a.hunger >= a.max_hunger)
			water_btn.disabled = (a.thirst >= a.max_thirst)

		batch_feed_btn.disabled = (not any_hungry)
		batch_water_btn.disabled = (not any_thirsty)

	# Gắn sự kiện cho các nút Cho Ăn, Uống Nước, Cho Ăn/Uống Hàng Loạt, Thu Hoạch
	feed_btn.pressed.connect(func():
		if farm_mgr == null:
			return
		if farm_mgr.get_feed_count() <= 0:
			_show_floating_text("Hết thức ăn! Thú chỉ ăn nông sản tự trồng hoặc cá tự câu/nuôi thu hoạch được. Hãy đi trồng trọt hoặc câu cá nhé!", global_position)
			return
		if a.hunger >= a.max_hunger:
			_show_floating_text("Thú đã no nê (100%), không cần cho ăn!", global_position)
			return
		var used_feed = farm_mgr.use_any_feed(false)
		var res = farm_mgr.livestock_mgr.feed_animal(idx, used_feed)
		farm_mgr.save_farm_data()
		_show_floating_text(res.get("msg", "🌾 Đã cho thú ăn!"), global_position)
		update_stats.call()
	)

	batch_feed_btn.pressed.connect(func():
		if farm_mgr == null or farm_mgr.livestock_mgr == null:
			return
		if farm_mgr.get_feed_count() <= 0:
			_show_floating_text("Hết thức ăn trong kho! Thú chỉ ăn nông sản tự trồng hoặc cá tự câu/nuôi. Hãy đi trồng trọt hoặc câu cá nhé!", global_position)
			return
		var res: Dictionary = farm_mgr.livestock_mgr.feed_all_animals()
		if res.get("success", false):
			farm_mgr.save_farm_data()
			_show_floating_text(str(res.get("msg", "🌾 Đã cho ăn hàng loạt!")), global_position)
			update_stats.call()
		else:
			_show_floating_text(str(res.get("msg", "Không có thú nào cần cho ăn!")), global_position)
	)

	water_btn.pressed.connect(func():
		if farm_mgr == null:
			return
		if farm_mgr.get_water_count() <= 0:
			_show_floating_text("Hết nước uống! Bấm nút [+ Lấy Nước] ở cột bên phải.", global_position)
			return
		if a.thirst >= a.max_thirst:
			_show_floating_text("Thú đã no nước (100%), không cần uống nữa!", global_position)
			return
		farm_mgr.use_water(1)
		var res = farm_mgr.livestock_mgr.water_animal(idx)
		farm_mgr.save_farm_data()
		_show_floating_text(res.get("msg", "💧 Đã cho thú uống nước!"), global_position)
		update_stats.call()
	)

	batch_water_btn.pressed.connect(func():
		if farm_mgr == null or farm_mgr.livestock_mgr == null:
			return
		if farm_mgr.get_water_count() <= 0:
			_show_floating_text("Hết nước uống! Bấm nút [+ Lấy Nước] ở cột bên phải.", global_position)
			return
		var res: Dictionary = farm_mgr.livestock_mgr.water_all_animals()
		if res.get("success", false):
			farm_mgr.save_farm_data()
			_show_floating_text(str(res.get("msg", "💧 Đã cho uống nước hàng loạt!")), global_position)
			update_stats.call()
		else:
			_show_floating_text(str(res.get("msg", "Không có thú nào cần uống nước!")), global_position)
	)

	harvest_btn.pressed.connect(func():
		if a.state == LivestockManager.AnimalState.READY or a.get_progress() >= 1.0:
			_harvest(idx, global_position)
			win.queue_free()
		else:
			_show_floating_text("⏳ Thú đang lớn (%d%%), chưa đến giờ thu hoạch!" % int(a.get_progress() * 100.0), global_position)
	)

	update_stats.call()

	update_stats.call()

	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(update_stats)
	win.add_child(timer)

	_attach_modal(win, Vector2(640, 470))

func _harvest(idx: int, pos: Vector2) -> void:
	if farm_mgr == null or farm_mgr.livestock_mgr == null:
		return
	var res: Dictionary = farm_mgr.livestock_mgr.harvest_animal(idx)
	if res.get("success", false):
		var prod_id: String = str(res.get("product_id", ""))
		var prod_name: String = str(res.get("product_name", "Thực Phẩm"))
		var exp_reward: int = int(res.get("exp", 30))
		var meat_cnt: int = maxi(1, int(res.get("meat_count", 1)))

		farm_mgr.add_to_chest(prod_id, meat_cnt, false)
		farm_mgr.add_farm_exp(exp_reward)
		farm_mgr.save_farm_data()

		_show_floating_text("✨ Thu hoạch x%d %s!\n(+%d Exp nông trại)\n🍗 Hãy gặp NPC Trù Thần (194/191) để đổi thịt lấy Bách Thú Bảo Rương!" % [meat_cnt, prod_name, exp_reward], pos)

func _show_floating_text(text: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos - Vector2(100, 30)
	lbl.custom_minimum_size = Vector2(200, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.z_index = 60
	add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 35, 1.5)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.tween_callback(lbl.queue_free)

## Cửa sổ lựa chọn thức ăn chăn nuôi
func _open_feed_dialog(idx: int, a: LivestockManager.AnimalInfo, parent_win: Node) -> void:
	if farm_mgr == null or farm_mgr.livestock_mgr == null:
		return

	var feed_win := CanvasLayer.new()
	feed_win.layer = 125
	add_child(feed_win)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	feed_win.add_child(overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 520)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_top = -260
	panel.offset_right = 240
	panel.offset_bottom = 260

	var pbox := StyleBoxFlat.new()
	pbox.bg_color = Color(0.10, 0.12, 0.15, 0.98)
	pbox.border_color = Color(0.85, 0.70, 0.30)
	pbox.set_border_width_all(2)
	pbox.set_corner_radius_all(8)
	pbox.content_margin_left = 14
	pbox.content_margin_top = 12
	pbox.content_margin_right = 14
	pbox.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", pbox)
	feed_win.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# 1. Header
	var header := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "🌾 BỮA ĂN VẬT NUÔI: %s" % a.name
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	header.add_child(title_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var close_b := Button.new()
	close_b.text = "✕"
	close_b.custom_minimum_size = Vector2(28, 28)
	close_b.pressed.connect(feed_win.queue_free)
	header.add_child(close_b)
	vbox.add_child(header)

	var desc_lbl := Label.new()
	desc_lbl.text = "🌾 QUY TẮC CỐT LÕI: Đàn thú chỉ ăn các loại Nông Sản bạn TỰ TRỒNG TRỌT hoặc Thủy Hải Sản ĐÁNH BẮT / NUÔI CÁ thu hoạch được. Nông sản và cá chất lượng cao giúp rút ngắn thời gian lớn và tăng sản lượng thu hoạch!"
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	vbox.add_child(desc_lbl)

	# 2. Danh sách cuộn các loại thức ăn chăn nuôi
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)

	var feeds: Dictionary = LivestockManager.LIVESTOCK_FEEDS
	for feed_key in feeds.keys():
		var f: Dictionary = feeds[feed_key]
		var row := PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(0.14, 0.16, 0.20, 0.9)
		r_sb.border_color = Color(0.28, 0.32, 0.38)
		r_sb.set_border_width_all(1)
		r_sb.set_corner_radius_all(6)
		r_sb.content_margin_left = 8
		r_sb.content_margin_top = 6
		r_sb.content_margin_right = 8
		r_sb.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", r_sb)

		var rhbox := HBoxContainer.new()
		rhbox.add_theme_constant_override("separation", 8)
		row.add_child(rhbox)

		# Icon
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_name := str(f.get("icon", ""))
		var farm_icon_path := "res://assets/farm/icons/" + icon_name
		var icon_path := "res://assets/items/icons/" + icon_name
		if ResourceLoader.exists(farm_icon_path):
			icon_rect.texture = load(farm_icon_path)
		elif ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		else:
			var res_farm = load(farm_icon_path)
			if res_farm is Texture2D:
				icon_rect.texture = res_farm
			else:
				var res_items = load(icon_path)
				if res_items is Texture2D:
					icon_rect.texture = res_items
				else:
					icon_rect.texture = load("res://assets/farm/crops/seed.png")
		rhbox.add_child(icon_rect)

		# Info
		var ivbox := VBoxContainer.new()
		ivbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ivbox.add_theme_constant_override("separation", 2)

		var name_lbl := Label.new()
		name_lbl.text = "%s [%s]" % [f.get("name", ""), f.get("category_tag", "")]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
		ivbox.add_child(name_lbl)

		var d_lbl := Label.new()
		d_lbl.text = str(f.get("desc", ""))
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.add_theme_font_size_override("font_size", 10)
		d_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		ivbox.add_child(d_lbl)

		var cnt: int = 0
		if farm_mgr:
			cnt = int(farm_mgr.farm_chest_produce.get(feed_key, 0)) + int(farm_mgr.farm_chest_supplies.get(feed_key, 0))
		var cnt_lbl := Label.new()
		cnt_lbl.text = "📦 Trong kho nông sản: %d phần" % cnt if cnt > 0 else "📦 Trong kho: 0 (Cần trồng trọt hoặc câu/nuôi cá)"
		cnt_lbl.add_theme_font_size_override("font_size", 10)
		cnt_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if cnt > 0 else Color(0.85, 0.45, 0.4))
		ivbox.add_child(cnt_lbl)
		rhbox.add_child(ivbox)

		# Nút hành động (Chỉ cho ăn khi có sẵn trong kho, không mua bằng tiền)
		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(110, 32)
		act_btn.focus_mode = Control.FOCUS_NONE
		_apply_prominent_button_style(act_btn)

		if cnt > 0:
			act_btn.text = "🌾 Cho Ăn"
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.18, 0.38, 0.20)
			sb.border_color = Color(0.4, 0.8, 0.4)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(4)
			act_btn.add_theme_stylebox_override("normal", sb)
			act_btn.pressed.connect(func():
				var res = farm_mgr.livestock_mgr.feed_animal(idx, feed_key)
				if res.get("success", false):
					farm_mgr.save_farm_data()
					_show_floating_text(res.get("msg", "Đã cho ăn!"), global_position)
					feed_win.queue_free()
					if is_instance_valid(parent_win):
						parent_win.queue_free()
				else:
					_show_floating_text(res.get("msg", "Không thể cho ăn!"), global_position)
			)
		else:
			act_btn.text = "Chưa Có"
			act_btn.disabled = true
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.2, 0.22, 0.25, 0.6)
			sb.border_color = Color(0.35, 0.38, 0.42, 0.6)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(4)
			act_btn.add_theme_stylebox_override("normal", sb)
			act_btn.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7, 0.6))

		rhbox.add_child(act_btn)
		list_vbox.add_child(row)

	# 3. Footer
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)

	var note_lbl := Label.new()
	note_lbl.text = "💡 Mẹo: Hãy gieo hạt ở Luống Đất hoặc thả cá giống ở Ao Cá để thu hoạch thức ăn tươi ngon!"
	note_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_lbl.add_theme_font_size_override("font_size", 10)
	note_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	footer.add_child(note_lbl)

	var close_bottom_btn := Button.new()
	close_bottom_btn.text = "Đóng"
	close_bottom_btn.custom_minimum_size = Vector2(80, 34)
	_apply_prominent_button_style(close_bottom_btn)
	close_bottom_btn.pressed.connect(feed_win.queue_free)
	footer.add_child(close_bottom_btn)

	vbox.add_child(footer)

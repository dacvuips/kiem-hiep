extends Node
class_name World3DView
## CHẾ ĐỘ 3D của map đánh quái (Cài đặt -> "Map đánh quái dạng 3D"). Chỉ là LỚP HIỂN THỊ: mọi thứ vẫn chạy ở bản 2D
## (vị trí quái / người chơi / đạn lấy từ server như cũ, combat y nguyên). Mỗi khung hình đọc lại thế giới 2D rồi đặt
## KHỐI 3D tương ứng — sau này thay khối bằng model (xem make_* bên dưới, mỗi loại 1 hàm).
##
## Đọc từ đâu:
##   - Mặt đất: ảnh nền vùng (VltkMap._g_base), mảng phủ (_g_covers), vật nằm sát đất (_g_flat) -> tấm phẳng dán ảnh.
##   - Nhà / cây / tường: holder ảnh tĩnh trong objects_root / above_root -> khối hộp, màu = màu trung bình của ảnh.
##   - Nhân vật / quái / NPC / người chơi khác: CharacterBody2D hoặc nhóm enemies/player/other_players/allies/npc_actor.
##   - Chiêu: VltkMissile (toạ độ logic + độ cao Z), VltkEffect, Projectile, LightningBeam.
##   - Đồ rơi (GroundDrop), xác quái (MonsterCorpse), số sát thương (damage_number) -> khối nhỏ / chữ 3D.
## Toạ độ: logic VLTK (x, 2·y màn hình) -> 3D (x·PX, z·PX, y_logic·PX); 1 đơn vị 3D = 100 px logic.
## Camera nghiêng 30° (cos 30° ≈ 0,866 = hệ số độ cao Z_SCREEN gốc) nên khung nhìn gần giống bản 2D; hướng Bắc ở trên
## như 2D để joystick / phím đi đúng chiều.
##
## Bấm chuột trên map: Player gọi World3DView.mouse_world() thay vì get_global_mouse_position() -> tia từ camera 3D chạm
## khối nhân vật (chọn mục tiêu) hoặc mặt đất (đi tới) rồi đổi về toạ độ 2D.

const PX := 0.01
const Z_SCREEN := 0.866          ## độ cao Z -> lệch màn hình (VltkMath.Z_SCREEN)
const PITCH_DEG := 30.0
const FOV := 40.0
const BASE_DIST := 10.0          ## khoảng camera ở zoom 1 (2D): thấy bề ngang ~ như bản 2D
const SCAN_INTERVAL := 0.25      ## quét vật thể tĩnh / mặt đất mới nạp (giây)

static var current: World3DView

var _world: VltkWorld
var _container: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _ground_root: Node3D
var _static_root: Node3D
var _dyn_root: Node3D
var _scan_t := 0.0

var _ground := {}     ## instance id (Sprite2D / holder 2D) -> Node3D
var _statics := {}    ## instance id holder -> Node3D
var _dynamic := {}    ## instance id -> {"src": Node2D, "node": Node3D, "kind": String, ...}

static var _mat_cache := {}
static var _color_cache := {}    ## texture rid -> Color trung bình
static var _box := BoxMesh.new()

## ---------- bật / tắt ----------

## Gọi khi vào map và khi đổi cài đặt: bật thì dựng, tắt thì gỡ.
static func sync() -> void:
	var want := GameSettings.render_3d() and VltkWorld.current != null and is_instance_valid(VltkWorld.current)
	if want and (current == null or not is_instance_valid(current)):
		var v := World3DView.new()
		v.name = "World3DView"
		VltkWorld.current.add_child(v)
	elif not want and current != null and is_instance_valid(current):
		current.queue_free()
		current = null

static func is_active() -> bool:
	return current != null and is_instance_valid(current) and current.is_inside_tree()

func _ready() -> void:
	current = self
	_world = get_parent() as VltkWorld
	_build_viewport()

func _exit_tree() -> void:
	if current == self:
		current = null
	if _container != null and is_instance_valid(_container):
		_container.queue_free()

func _build_viewport() -> void:
	_container = SubViewportContainer.new()
	_container.name = "World3D"
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE   ## chuột đi thẳng xuống game (Player._unhandled_input)
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_container.add_child(_vp)
	## Nằm DƯỚI mọi HUD: con đầu tiên của CanvasLayer "UI" trong Main (HUD khác ở layer cao hơn). Không có thì layer riêng.
	var ui := get_tree().current_scene.get_node_or_null("UI") if get_tree().current_scene != null else null
	if ui is CanvasLayer:
		ui.add_child(_container)
		ui.move_child(_container, 0)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 1
		layer.name = "World3DLayer"
		add_child(layer)
		layer.add_child(_container)

	_root3d = Node3D.new()
	_vp.add_child(_root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.09, 0.08)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.environment.ambient_light_energy = 0.9
	_root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	_root3d.add_child(sun)
	_ground_root = Node3D.new()
	_static_root = Node3D.new()
	_dyn_root = Node3D.new()
	_root3d.add_child(_ground_root)
	_root3d.add_child(_static_root)
	_root3d.add_child(_dyn_root)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.far = 200.0
	_root3d.add_child(_cam)

## ---------- toạ độ ----------

## 2D (màn hình) -> 3D trên mặt đất.
static func to3d(p2: Vector2, height_px: float = 0.0) -> Vector3:
	return Vector3(p2.x * PX, height_px * PX, p2.y * 2.0 * PX)

static func to2d(p3: Vector3) -> Vector2:
	return Vector2(p3.x / PX, p3.z / PX * 0.5)

## Điểm 2D dưới con trỏ — thay cho get_global_mouse_position() khi chế độ 3D bật (Player, SkillBarUI, đồ rơi).
## Trả về theo quy ước của get_global_mouse_position: điểm "tâm thân" (chân - FEET_OFFSET); bấm trúng khối nhân vật
## thì trả đúng global_position của nó để pick_target_at chọn được.
## `as_body` = false: trả đúng điểm mặt đất (vật nằm trên đất như đồ rơi), không trừ FEET_OFFSET / không chọn nhân vật.
static func mouse_world(fallback_node: CanvasItem, as_body: bool = true) -> Vector2:
	if not is_active():
		return fallback_node.get_global_mouse_position()
	return current._screen_to_world(current.get_viewport().get_mouse_position(), as_body)

## Như trên nhưng từ toạ độ màn hình (cú chạm joystick, sự kiện chuột).
static func screen_to_world(screen_pos: Vector2, viewport: Viewport, as_body: bool = true) -> Vector2:
	if not is_active():
		return viewport.get_canvas_transform().affine_inverse() * screen_pos
	return current._screen_to_world(screen_pos, as_body)

func _screen_to_world(screen_pos: Vector2, as_body: bool = true) -> Vector2:
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	## 1) trúng khối nhân vật / quái gần camera nhất
	var best_t := INF
	var best: Node2D = null
	for id in (_dynamic if as_body else {}):
		var e: Dictionary = _dynamic[id]
		if e["kind"] != "actor" or not is_instance_valid(e["src"]):
			continue
		var n3: Node3D = e["node"]
		if not n3.visible:
			continue
		var half: Vector3 = e["half"]
		var t := _ray_box(from, dir, n3.position + Vector3(0, half.y, 0), half * 1.25)
		if t < best_t:
			best_t = t
			best = e["src"]
	if best != null:
		return best.global_position
	## 2) mặt đất y = 0
	if absf(dir.y) < 0.0001:
		return to2d(from)
	var t0 := -from.y / dir.y
	var hit := from + dir * maxf(t0, 0.0)
	return to2d(hit) - (Vector2(0, VltkWorld.FEET_OFFSET) if as_body else Vector2.ZERO)

static func _ray_box(o: Vector3, d: Vector3, c: Vector3, h: Vector3) -> float:
	var tmin := -INF
	var tmax := INF
	for i in 3:
		if absf(d[i]) < 1e-6:
			if o[i] < c[i] - h[i] or o[i] > c[i] + h[i]:
				return INF
			continue
		var t1 := (c[i] - h[i] - o[i]) / d[i]
		var t2 := (c[i] + h[i] - o[i]) / d[i]
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
	return tmin if tmax >= maxf(tmin, 0.0) else INF

## ---------- mỗi khung hình ----------

func _process(delta: float) -> void:
	if _world == null or _world.map == null:
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_INTERVAL
		_scan_ground()
		_scan_statics()
	_scan_dynamic()
	_update_dynamic(delta)
	_update_camera()
	_fade_occluders()

func _update_camera() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var focus2 := VltkMath.ground_of(p) if p != null else Vector2.ZERO
	var zoom := 1.0
	var cam2 := get_viewport().get_camera_2d()
	if cam2 != null:
		zoom = maxf(cam2.zoom.x, 0.1)
	var dist := BASE_DIST / zoom
	var target := to3d(focus2) + Vector3(0, 0.4, 0)
	var pitch := deg_to_rad(PITCH_DEG)
	_cam.position = target + Vector3(0, sin(pitch), cos(pitch)) * dist
	_cam.look_at(target, Vector3.UP)

## Khối tĩnh che nhân vật (nằm giữa camera và nhân vật) -> làm mờ, như game 3D góc nhìn từ trên.
var _faded := {}
func _fade_occluders() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	var pp := to3d(VltkMath.ground_of(p)) + Vector3(0, 0.45, 0)
	var from := _cam.global_position
	var now := {}
	for id in _statics:
		var root: Node3D = _statics[id]
		if not is_instance_valid(root) or not root.visible:
			continue
		for mi in root.get_children():
			var m := mi as MeshInstance3D
			if m == null:
				continue
			## chỉ xét khối ở phía trước nhân vật (gần camera hơn) và gần theo chiều ngang
			if m.position.z < pp.z or absf(m.position.x - pp.x) > m.scale.x * 0.5 + 1.0:
				continue
			if _ray_box(from, (pp - from).normalized(), m.position, m.scale * 0.5) < from.distance_to(pp):
				now[m.get_instance_id()] = m
	for k in _faded.keys():
		if not now.has(k):
			var m: MeshInstance3D = _faded[k]
			if is_instance_valid(m):
				m.material_override = _color_material(m.get_meta("color"))
			_faded.erase(k)
	for k in now:
		if not _faded.has(k):
			var m: MeshInstance3D = now[k]
			m.material_override = _color_material(m.get_meta("color"), false, 0.3)
			_faded[k] = m

## ---------- mặt đất ----------

func _scan_ground() -> void:
	var map: VltkMap = _world.map
	var seen := {}
	for s in map._g_base.get_children():
		if s is Sprite2D:
			_ensure_ground(s, s, 0.0, seen)
	for s in map._g_covers.get_children():
		if s is Sprite2D:
			_ensure_ground(s, s, 0.002, seen)
	for h in map._g_flat.get_children():
		for s in h.get_children():
			if s is Sprite2D:
				_ensure_ground(h, s, 0.004, seen)
	_drop_missing(_ground, seen)

func _ensure_ground(key_node: Node, s: Sprite2D, lift: float, seen: Dictionary) -> void:
	var id := key_node.get_instance_id() * 31 + s.get_instance_id()
	seen[id] = true
	if _ground.has(id) or s.texture == null:
		return
	_ground[id] = make_ground_quad(s, lift)
	_ground_root.add_child(_ground[id])

## Tấm phẳng dán ảnh nền, 4 góc lấy đúng biến đổi của Sprite2D (kể cả co giãn / xô nghiêng).
func make_ground_quad(s: Sprite2D, lift: float) -> MeshInstance3D:
	var rect := s.get_rect()
	var xf := s.global_transform
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	if s.region_enabled:
		var tsz := Vector2(s.texture.get_size())
		var r := s.region_rect
		uvs = [r.position / tsz, Vector2(r.end.x, r.position.y) / tsz, r.end / tsz, Vector2(r.position.x, r.end.y) / tsz]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[i])
		st.add_vertex(to3d(xf * corners[i], lift / PX))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _tex_material(s.texture, lift > 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _tex_material(tex: Texture2D, cutout: bool) -> StandardMaterial3D:
	var key := "t%d_%s" % [tex.get_rid().get_id(), cutout]
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		if cutout:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_mat_cache[key] = m
	return _mat_cache[key]

static func _color_material(c: Color, emissive: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "c%s_%s_%.2f" % [c.to_html(false), emissive, alpha]
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c, alpha)
		m.roughness = 0.9
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if emissive:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 1.6
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_cache[key] = m
	return _mat_cache[key]

func _drop_missing(table: Dictionary, seen: Dictionary) -> void:
	for id in table.keys():
		if not seen.has(id):
			var n: Node = table[id]
			if is_instance_valid(n):
				n.queue_free()
			table.erase(id)

## ---------- nhà / cây / tường ----------

## Holder tĩnh của map: Node2D không script, có Sprite2D con, không phải NPC.
static func _is_static_holder(n: Node) -> bool:
	if not (n is Node2D) or n.get_script() != null or n.is_in_group("npc_actor"):
		return false
	for c in n.get_children():
		if c is Sprite2D:
			return true
	return false

func _scan_statics() -> void:
	var map: VltkMap = _world.map
	var seen := {}
	for root in [map.objects_root, map.above_root]:
		for h in root.get_children():
			if not _is_static_holder(h):
				continue
			var id: int = h.get_instance_id()
			seen[id] = true
			if not _statics.has(id):
				var n := make_structure(h, root == map.above_root)
				if n != null:
					_statics[id] = n
					_static_root.add_child(n)
			elif is_instance_valid(_statics[id]):
				(_statics[id] as Node3D).visible = (h as Node2D).is_visible_in_tree()
	_drop_missing(_statics, seen)

## 1 vật thể map -> khối. Ảnh VLTK nhìn xiên nên không biết thẳng chân đế -> lấy CHÂN ĐẾ từ lưới vật cản của map
## (ô bị chặn nằm dưới ảnh, sát đường sắp độ sâu): nhà = khối trên nền nhà, cây = thân trên ô gốc + tán lơ lửng,
## vật trang trí không chặn đường = khối thấp. Màu = màu trung bình của ảnh.
## SAU NÀY: thay thân hàm bằng model (theo tên ảnh trong map -> model).
const CELL2 := Vector2(32, 16)   ## ô vật cản trên màn hình 2D (VltkMap.cell)
func make_structure(h: Node2D, above: bool) -> Node3D:
	var box2 := Rect2()
	var tex: Texture2D = null
	var first := true
	for s in h.get_children():
		if not (s is Sprite2D) or (s as Sprite2D).texture == null:
			continue
		var sp := s as Sprite2D
		tex = sp.texture
		var r := sp.get_rect()
		var xf := sp.global_transform
		for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var q: Vector2 = xf * p
			box2 = Rect2(q, Vector2.ZERO) if first else box2.expand(q)
			first = false
	if first or box2.size.x < 4.0:
		return null
	var color := _avg_color(tex)
	var w := box2.size.x
	var foot_y := h.global_position.y      ## đường sắp độ sâu = mép đất phía trước
	var root := Node3D.new()
	root.visible = h.is_visible_in_tree()
	if above:   ## mái / vật lơ lửng (lớp trên): tấm mỏng trên cao
		var hgt := maxf(0.0, (foot_y - box2.end.y) / Z_SCREEN)
		root.add_child(_block(Rect2(box2.position.x, foot_y * 2.0 - w * 0.5, w, w * 0.5), hgt, 12.0, color))
		return root
	var foot := _blocked_footprint(Rect2(box2.position.x, foot_y - minf(w * 0.4, 160.0), w, minf(w * 0.4, 160.0) + 12.0))
	var is_tree := color.g > color.r * 1.04 and color.g > color.b * 1.1
	if is_tree:
		## Thân: ô gốc bị chặn (hoặc 1 ô giữa chân ảnh), cao ~55% ảnh; tán: hộp rộng ở phần trên.
		var total := maxf(40.0, (foot_y - box2.position.y) / Z_SCREEN)
		var trunk := foot if foot.size != Vector2.ZERO else Rect2(box2.position.x + w * 0.5 - 12.0, foot_y * 2.0 - 24.0, 24.0, 24.0)
		trunk = Rect2(trunk.get_center() - Vector2(10, 10), Vector2(20, 20))
		root.add_child(_block(trunk, 0.0, total * 0.6, Color(0.36, 0.25, 0.16)))
		var cw := w * 0.7
		var cd := minf(w * 0.5, 220.0)
		root.add_child(_block(Rect2(trunk.get_center().x - cw * 0.5, trunk.get_center().y - cd * 0.5, cw, cd),
			total * 0.45, total * 0.55, color))
		return root
	if foot.size == Vector2.ZERO:
		## Không chặn đường: đá nhỏ, bụi, đồ trang trí -> khối thấp.
		var d := clampf(w * 0.3, 16.0, 96.0)
		root.add_child(_block(Rect2(box2.position.x + w * 0.15, foot_y * 2.0 - d, w * 0.7, d), 0.0,
			clampf((foot_y - box2.position.y) / Z_SCREEN * 0.35, 8.0, 40.0), color))
		return root
	## Nhà / tường / đá lớn: khối đúng nền bị chặn; cao = phần ảnh còn lại sau khi trừ bề sâu nền (×0,5 trên màn hình).
	var height := maxf(24.0, (foot_y - box2.position.y - foot.size.y * 0.5) / Z_SCREEN)
	root.add_child(_block(foot, 0.0, height, color))
	return root

## Hộp bao các ô vật cản trong vùng `area` (toạ độ màn hình 2D) -> Rect2 toạ độ LOGIC (x, y·2). Rỗng = không ô nào chặn.
func _blocked_footprint(area: Rect2) -> Rect2:
	var map: VltkMap = _world.map
	var out := Rect2()
	var found := false
	var y := area.position.y
	while y <= area.end.y:
		var x := area.position.x
		while x <= area.end.x:
			if map.is_blocked(Vector2(x, y)):
				var c := map.world_to_cell(Vector2(x, y))
				var cell_logic := Rect2(c.x * CELL2.x, c.y * CELL2.y * 2.0, CELL2.x, CELL2.y * 2.0)
				out = cell_logic if not found else out.merge(cell_logic)
				found = true
			x += CELL2.x
		y += CELL2.y
	return out if found else Rect2()

## Hộp trên nền `foot` (toạ độ logic px), đáy cao `base` px, cao `height` px.
func _block(foot: Rect2, base: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box
	mi.material_override = _color_material(color)
	mi.scale = Vector3(maxf(foot.size.x, 4.0), maxf(height, 2.0), maxf(foot.size.y, 4.0)) * PX
	mi.position = Vector3(foot.get_center().x, base + height * 0.5, foot.get_center().y) * PX
	mi.set_meta("color", color)
	return mi

static func _avg_color(tex: Texture2D) -> Color:
	if tex == null:
		return Color(0.5, 0.45, 0.4)
	var key := tex.get_rid().get_id()
	if _color_cache.has(key):
		return _color_cache[key]
	var c := Color(0.5, 0.45, 0.4)
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var sum := Vector3.ZERO
		var n := 0
		var step := maxi(1, maxi(img.get_width(), img.get_height()) / 24)
		for y in range(0, img.get_height(), step):
			for x in range(0, img.get_width(), step):
				var p := img.get_pixel(x, y)
				if p.a > 0.5:
					sum += Vector3(p.r, p.g, p.b)
					n += 1
		if n > 0:
			sum /= n
			c = Color(sum.x, sum.y, sum.z)
	_color_cache[key] = c
	return c

## ---------- nhân vật / quái / chiêu ----------

func _kind_of(n: Node) -> String:
	if n is VltkMissile:
		return "missile"
	if n is VltkEffect:
		return "effect"
	if n is Projectile:
		return "projectile"
	if n is LightningBeam:
		return "beam"
	if n is GroundDrop:
		return "drop"
	if n is MonsterCorpse:
		return "corpse"
	if n is CharacterBody2D or n.is_in_group("npc_actor") or n.is_in_group("enemies") or n.is_in_group("player") \
			or n.is_in_group("other_players") or n.is_in_group("allies"):
		return "actor"
	if n.scene_file_path.ends_with("damage_number.tscn"):
		return "damage"
	return ""

func _scan_dynamic() -> void:
	var map: VltkMap = _world.map
	var seen := {}
	for root in [map.objects_root, _world]:
		for n in root.get_children():
			if not (n is Node2D) or n == self:
				continue
			var id: int = n.get_instance_id()
			if _dynamic.has(id):
				seen[id] = true
				continue
			var kind := _kind_of(n)
			if kind == "":
				continue
			seen[id] = true
			var e := _make_dynamic(n, kind)
			if not e.is_empty():
				_dynamic[id] = e
				_dyn_root.add_child(e["node"])
	for id in _dynamic.keys():
		var e: Dictionary = _dynamic[id]
		if not seen.has(id) or not is_instance_valid(e["src"]):
			if is_instance_valid(e["node"]):
				e["node"].queue_free()
			_dynamic.erase(id)

func _make_dynamic(n: Node2D, kind: String) -> Dictionary:
	match kind:
		"actor":
			return make_actor(n)
		"missile", "projectile":
			return {"src": n, "kind": kind, "node": _blob(Color(1.0, 0.55, 0.15), 0.18, true)}
		"effect":
			return {"src": n, "kind": kind, "node": _blob(Color(1.0, 0.9, 0.4), 0.35, true, 0.45)}
		"beam":
			return {"src": n, "kind": kind, "node": _blob(Color(0.6, 0.8, 1.0), 0.25, true, 0.6)}
		"drop":
			var d := _blob(Color(1.0, 0.82, 0.2), 0.14, true)
			return {"src": n, "kind": kind, "node": d}
		"corpse":
			var c := MeshInstance3D.new()
			c.mesh = _box
			c.material_override = _color_material(Color(0.25, 0.18, 0.15))
			c.scale = Vector3(0.6, 0.08, 0.3)
			return {"src": n, "kind": kind, "node": c}
		"damage":
			var l := Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.font_size = 40
			l.outline_size = 10
			l.pixel_size = 0.006
			return {"src": n, "kind": kind, "node": l, "y0": n.global_position.y}
	return {}

## Nhân vật / quái / NPC -> khối đứng + "mũi" chỉ hướng + tên + thanh máu. SAU NÀY: Character3D (hình phẳng 8 hướng)
## hoặc Character3D.load_model() cho model thật.
func make_actor(n: Node2D) -> Dictionary:
	var color := Color(0.9, 0.85, 0.3)       ## NPC
	var size := Vector3(0.36, 0.9, 0.36)
	if n.is_in_group("player"):
		color = Color(0.2, 0.55, 1.0)
	elif n is RemotePlayer or n.is_in_group("other_players"):
		color = Color(0.3, 0.9, 0.95)
	elif n.is_in_group("allies"):
		color = Color(0.35, 0.9, 0.45)
	elif n.is_in_group("enemies") or n is VltkMonster or n.is_in_group("monster"):
		color = Color(0.9, 0.25, 0.2)
		size = Vector3(0.5, 0.6, 0.5)
		if n is VltkMonster and (n as VltkMonster).data.get("boss", false):
			size *= 1.6
	elif n.is_in_group("critter"):
		color = Color(0.6, 0.6, 0.6)
		size = Vector3(0.25, 0.25, 0.25)
	var root := Node3D.new()
	var pivot: Node3D
	var av: Variant = n.get("avatar") if "avatar" in n else null
	if av is CharacterAvatar:
		## Người (player / người chơi khác / bot): GHÉP BỘ PHẬN như 2D — đầu, thân, tay, vũ khí, ngựa theo mã hình trang bị.
		pivot = Actor3DRig.new(av)
		root.add_child(pivot)
		size = Vector3(0.4, 0.9, 0.3)
	else:
		## Quái / NPC: 1 khối (quái VLTK là 1 hình liền) + mũi chỉ hướng.
		var body := MeshInstance3D.new()
		body.mesh = _box
		body.material_override = _color_material(color)
		body.scale = size
		body.position.y = size.y * 0.5
		root.add_child(body)
		var nose := MeshInstance3D.new()
		nose.mesh = _box
		nose.material_override = _color_material(color.darkened(0.5))
		nose.scale = Vector3(0.1, 0.1, 0.22)
		nose.position = Vector3(0, size.y * 0.75, size.z * 0.5 + 0.08)
		pivot = Node3D.new()
		pivot.add_child(nose)
		root.add_child(pivot)
	var label := Label3D.new()
	label.text = _name_of(n)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.pixel_size = 0.005
	label.modulate = color.lightened(0.4)
	label.position.y = size.y + 0.32
	root.add_child(label)
	var hp := MeshInstance3D.new()
	hp.mesh = _box
	hp.material_override = _color_material(Color(0.95, 0.2, 0.2) if color.r > 0.8 and color.g < 0.4 else Color(0.3, 0.95, 0.35), true)
	hp.position.y = size.y + 0.18
	root.add_child(hp)
	return {"src": n, "kind": "actor", "node": root, "pivot": pivot, "hp": hp, "label": label,
		"half": size * 0.5, "last": VltkMath.ground_of(n), "yaw": 0.0}

static func _name_of(n: Node) -> String:
	if "display_name" in n and str(n.get("display_name")) != "":
		return str(n.get("display_name"))
	if "profile" in n and n.get("profile") != null and "display_name" in n.get("profile"):
		return str(n.get("profile").display_name)
	if "data" in n and n.get("data") is Dictionary:
		return str((n.get("data") as Dictionary).get("name", ""))
	if n.has_meta("npc"):
		var d: Dictionary = n.get_meta("npc")
		return str(d.get("name_vi", d.get("name", "")))
	return ""

func _blob(c: Color, radius: float, emissive: bool, alpha: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = _color_material(c, emissive, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _update_dynamic(delta: float) -> void:
	for id in _dynamic:
		var e: Dictionary = _dynamic[id]
		var src: Node2D = e["src"]
		if not is_instance_valid(src):
			continue
		var n3: Node3D = e["node"]
		n3.visible = src.is_visible_in_tree()
		if not n3.visible:
			continue
		match e["kind"]:
			"actor":
				_update_actor(e, src, delta)
			"missile":
				var m := src as VltkMissile
				n3.position = to3d(VltkMath.to_world(m.logic), maxf(m._z, 0.0) + 30.0)
			"effect":
				n3.position = to3d(VltkMath.to_world(src.get("_logic")), float(src.get("_z")) + 30.0)
			"projectile", "beam":
				n3.position = to3d(src.global_position + Vector2(0, VltkWorld.FEET_OFFSET), 40.0)
			"drop", "corpse":
				n3.position = to3d(src.global_position, 6.0)
			"damage":
				var lab := n3 as Label3D
				var t := src.get_node_or_null("Text") as Label
				if t != null:
					lab.text = t.text
					lab.modulate = Color(t.get_theme_color("font_color"), src.modulate.a)
				var rise := maxf(0.0, float(e["y0"]) - src.global_position.y)
				n3.position = to3d(Vector2(src.global_position.x, float(e["y0"])) + Vector2(0, VltkWorld.FEET_OFFSET),
					90.0 + rise / Z_SCREEN)

func _update_actor(e: Dictionary, src: Node2D, delta: float) -> void:
	var g := VltkMath.ground_of(src)
	var n3: Node3D = e["node"]
	n3.position = to3d(g)
	var mv: Vector2 = g - e["last"]
	e["last"] = g
	if mv.length_squared() > 0.25:
		var v3 := Vector3(mv.x, 0, mv.y * 2.0)
		e["yaw"] = atan2(v3.x, v3.z)
	var pivot: Node3D = e["pivot"]
	if not pivot is Actor3DRig:   ## rig người tự quay theo hướng avatar 2D
		pivot.rotation.y = lerp_angle(pivot.rotation.y, float(e["yaw"]), minf(1.0, delta * 12.0))
	var ratio := 1.0
	if "health" in src and "max_health" in src and float(src.get("max_health")) > 0.0:
		ratio = clampf(float(src.get("health")) / float(src.get("max_health")), 0.0, 1.0)
	var hp: MeshInstance3D = e["hp"]
	hp.scale = Vector3(maxf(0.01, 0.5 * ratio), 0.05, 0.05)
	hp.visible = ratio < 0.999 or src.is_in_group("player")

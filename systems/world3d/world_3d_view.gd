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
##   - Chiêu: VltkMissile / VltkEffect / Projectile -> CHÉP FRAME 2D (ActorFrames3D, cộng sáng như 2D); LightningBeam -> tia 3D.
##   - Xác quái (MonsterCorpse) -> chép frame chết; đồ rơi (GroundDrop, vẽ tay bằng _draw) -> cầu nhỏ; số sát thương -> chữ 3D.
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
## Góc camera (giữ qua các lần vào map). yaw 0 = nhìn về Bắc như bản 2D.
static var cam_yaw := 0.0
static var cam_pitch_deg := PITCH_DEG
const PITCH_MIN := 2.0    ## gần ngang tầm mắt: kéo 2 ngón / Alt + kéo chuột lên để nhìn ngang nhân vật
const PITCH_MAX := 75.0

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
var _ground_seq := 0  ## nâng mỗi tấm nền 1 chút (thứ tự nạp) để chỗ 2 tấm chồng nhau không nhấp nháy
var _floor: MeshInstance3D   ## nền dự phòng dưới cùng (như ảnh trời / nền của bản 2D) — chỗ vùng chưa nạp không bị đen
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
	_set_load_radius(-1)   ## trả bán kính nạp bản đồ về như 2D
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
	_floor = MeshInstance3D.new()
	var fp := PlaneMesh.new()
	fp.size = Vector2(400, 400)
	_floor.mesh = fp
	_floor.material_override = _color_material(Color(0.30, 0.26, 0.20))
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root3d.add_child(_floor)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.far = 200.0
	_root3d.add_child(_cam)

## ---------- xoay góc nhìn ----------
## Xoay camera (không có nút trên màn hình):
##   - Điện thoại: 2 ngón tay trên map (không trên nút HUD): kéo ngang = xoay, kéo dọc = ngẩng / cúi, chụm / mở = zoom.
##   - Máy tính: giữ chuột giữa + kéo, hoặc giữ Alt + kéo chuột trái (laptop không có chuột giữa).
var _mid_drag := false

func _drag_rotate(rel: Vector2) -> void:
	cam_yaw = wrapf(cam_yaw - rel.x * 0.008, -PI, PI)
	cam_pitch_deg = clampf(cam_pitch_deg + rel.y * 0.25, PITCH_MIN, PITCH_MAX)

## ---- 2 ngón tay trên map ----
## Chỉ chạm KHÔNG rơi vào nút HUD mới tới được _unhandled_input -> giữ joystick + bấm skill không bao giờ thành xoay.
## 2 ngón chạm map chưa phải xoay ngay: phải KÉO quá GESTURE_START_PX mới bắt đầu (chạm 2 ngón chọn quái / bấm đi vẫn bình
## thường). Nhấc tay thì bắt ở _input (luôn tới, kể cả ngón trượt lên nút rồi mới nhấc) -> không còn "ngón ma".
const GESTURE_START_PX := 24.0
var _touches := {}          ## index -> vị trí (chỉ các chạm bắt đầu trên map)
var _pinch_dist := 0.0
var _gesture_on := false
var _gesture_acc := 0.0     ## quãng kéo cộng dồn khi đang có 2 ngón, chưa bắt đầu xoay

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed:
		_touches[e.index] = e.position
		_pinch_dist = _touch_spread()
		_gesture_acc = 0.0
	elif e is InputEventScreenDrag and _touches.has(e.index):
		_touches[e.index] = e.position
		if _touches.size() < 2:
			return
		if not _gesture_on:
			_gesture_acc += e.relative.length()
			if _gesture_acc < GESTURE_START_PX:
				return
			_gesture_on = true
			_cancel_touch_walk()
			_pinch_dist = _touch_spread()
		## Mỗi ngón góp 1/n chuyển động -> kéo 2 ngón cùng chiều = xoay; khoảng cách đổi = zoom.
		_drag_rotate(e.relative / float(_touches.size()))
		var d := _touch_spread()
		if _pinch_dist > 1.0 and d > 1.0:
			_pinch_zoom(d / _pinch_dist)
		_pinch_dist = d
		get_viewport().set_input_as_handled()

## Nhấc tay: gọi từ _input để không bỏ sót.
func _touch_released(index: int) -> void:
	_touches.erase(index)
	_pinch_dist = _touch_spread()
	if _touches.size() < 2:
		_gesture_on = false
		_gesture_acc = 0.0

## Ngón đầu chạm map đã thành "bấm chuột trái" giả lập (Player chạy tới / bám theo ngón) -> hủy khi thành cử chỉ 2 ngón.
func _cancel_touch_walk() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if "_mouse_holding" in p:
		p.set("_mouse_holding", false)
	if "_move_follow_held" in p:
		p.set("_move_follow_held", false)
	if p.has_method("_clear_move_target"):
		p.call("_clear_move_target")

func _touch_spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])

func _pinch_zoom(ratio: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("set_camera_zoom") and p.has_method("get_camera_zoom") and absf(ratio - 1.0) > 0.002:
		p.set_camera_zoom(p.get_camera_zoom() * ratio)

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and not e.pressed:
		_touch_released(e.index)
	## Đang xoay bằng 2 ngón: chặn chuột giả lập từ cảm ứng (không cho Player chạy theo ngón).
	if _gesture_on and e is InputEventMouse and e.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	## Bắt ngay từ _input để Player không coi là bấm đi / ra chiêu.
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_MIDDLE:
			_mid_drag = e.pressed
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed and e.alt_pressed and not _over_gui():
				_mid_drag = true
				get_viewport().set_input_as_handled()
			elif not e.pressed and _mid_drag:
				_mid_drag = false
				get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and _mid_drag:
		_drag_rotate(e.relative)
		get_viewport().set_input_as_handled()

## Con trỏ đang trên 1 ô giao diện THỰC SỰ nhận chuột (STOP ở chính nó hoặc cha) — khung chứa PASS thì không tính.
func _over_gui() -> bool:
	var c: Node = get_viewport().gui_get_hovered_control()
	while c is Control:
		if c == _container or c is MoveJoystick:   ## vùng joystick ảo thực chất là mặt map
			return false
		if (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP and (c as Control).is_visible_in_tree():
			return true
		c = c.get_parent()
	return false

## Hướng phím / joystick (theo MÀN HÌNH: lên = ra xa camera) -> hướng trong thế giới 2D khi camera đã xoay.
## Camera chưa xoay (hoặc tắt 3D) thì trả nguyên.
static func screen_dir_to_world(v: Vector2) -> Vector2:
	if v == Vector2.ZERO or not is_active() or is_zero_approx(cam_yaw):
		return v
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var back := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var d := right * v.x + back * v.y            ## mặt đất 3D (x, z logic)
	var w := Vector2(d.x, d.z * 0.5)              ## logic -> 2D (y màn hình = y logic / 2)
	return w.normalized() * v.length() if w != Vector2.ZERO else v

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

## CAMERA CHIẾU THẲNG (orthographic), nghiêng cam_pitch_deg: ở góc mặc định (30°, không xoay) khớp 2D TỪNG ĐIỂM —
## 1 px màn hình = 1 px ngang = 2 px sâu logic (sin 30° = 0,5) = 1/0,866 px cao; tâm + zoom lấy đúng của Camera2D.
## (Camera phối cảnh cũ làm méo: đạn ở gần camera bị đẩy ra xa tới ~50%, đường đạn / vòng đạn sai hình.)
## cam_ortho = false: trở lại phối cảnh (FOV) để thử cảm giác 3D sâu hơn.
static var cam_ortho := true
func _update_camera() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var focus2 := VltkMath.ground_of(p) if p != null else Vector2.ZERO
	var zoom := 1.0
	var cam2 := get_viewport().get_camera_2d()
	if cam2 != null:
		zoom = maxf(cam2.zoom.x, 0.1)
		focus2 = cam2.get_screen_center_position()   ## tâm màn hình 2D (đã tính bám mượt / giới hạn map)
	var pitch := deg_to_rad(cam_pitch_deg)
	var back := Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch))
	if cam_ortho:
		## Tâm màn hình 2D là 1 điểm trên MẶT ĐẤT (x, 2y logic) -> camera nhìn đúng điểm đó.
		## Hạ camera thấp hơn 30° (nhìn ngang nhân vật): KHÔNG tự zoom (user chốt) — cỡ khung giữ như 2D, chỉ nhắm dần lên
		## ngang thân người để nhân vật ở giữa màn hình. 30° trở lên giữ đúng khung 2D (khớp từng điểm).
		var low := clampf((PITCH_DEG - cam_pitch_deg) / (PITCH_DEG - PITCH_MIN), 0.0, 1.0)
		var target := to3d(focus2) + Vector3(0, 0.45 * low, 0)
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.size = get_viewport().get_visible_rect().size.y / zoom * PX
		_cam.near = 0.05
		## Lùi đủ xa để MÉP DƯỚI khung nhìn vẫn ở trên mặt đất khi hạ thấp (chiếu thẳng: lùi không đổi cỡ hình).
		var pitch_c := maxf(sin(pitch), 0.02)
		var dist := maxf(40.0, _cam.size * 0.5 * cos(pitch) / pitch_c + 3.0)
		_cam.far = dist + 160.0
		_cam.position = target + back * dist
		_update_load_radius(pitch)
		_cam.look_at(target, Vector3.UP)
		if _floor != null:
			_floor.position = Vector3(target.x, -0.03, target.z)
		return
	var dist := BASE_DIST / zoom
	var target := to3d(focus2) + Vector3(0, 0.4, 0)
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.position = target + back * dist
	if _floor != null:
		_floor.position = Vector3(target.x, -0.03, target.z)
	_cam.look_at(target, Vector3.UP)

## Hạ camera thấp: khung nhìn trải sâu ra trước / sau (~40 m ở 5°) -> NẠP THÊM vùng bản đồ quanh nhân vật cho kín
## đất / nhà / cây (VltkMap.load_radius_regions, vùng 512 px). Góc 30° trở lên: giữ bán kính gốc của map như 2D.
const MAX_LOAD_RADIUS := 5        ## tối đa 11 x 11 vùng
var _base_radius := -1
func _update_load_radius(pitch: float) -> void:
	var want := -1
	if cam_pitch_deg < PITCH_DEG - 0.5:
		var half_h := _cam.size * 0.5                                   ## m nửa chiều cao khung
		var half_w := half_h * _vp.size.x / maxf(1.0, _vp.size.y)       ## m nửa bề ngang
		var depth := half_h * cos(pitch) / maxf(sin(pitch), 0.02)       ## m sâu mỗi phía trên mặt đất
		## m -> px logic (/PX) -> vùng: ngang 512 px logic, dọc 512 px màn hình = 1024 px logic. Xoay camera: lấy cả 2 trục.
		var need := ceili(maxf(depth / PX / 1024.0, half_w / PX / 512.0)) + 1
		want = need
	_set_load_radius(want)

## r < 0 = trả về bán kính gốc.
func _set_load_radius(r: int) -> void:
	## CHỈ chế độ 3D đổi bán kính nạp; bản 2D giữ nguyên số vùng gốc của map (tắt 3D / rời map -> trả về ngay).
	var map: VltkMap = _world.map if _world != null and is_instance_valid(_world) else null
	if map == null or not is_instance_valid(map):
		return
	if _base_radius < 0:
		_base_radius = map.load_radius_regions
	var v := _base_radius if r < 0 else clampi(maxi(r, _base_radius), _base_radius, MAX_LOAD_RADIUS)
	if map.load_radius_regions != v:
		map.load_radius_regions = v

## Khối tĩnh che nhân vật (nằm giữa camera và nhân vật) -> làm mờ, như game 3D góc nhìn từ trên.
var _faded := {}
var _bill_yaw := 0.0
func _fade_occluders() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	var pp := to3d(VltkMath.ground_of(p)) + Vector3(0, 0.45, 0)
	## Camera chiếu thẳng: tia song song hướng nhìn -> lấy điểm xuất phát lùi từ nhân vật ngược hướng nhìn.
	var from := pp + _cam.global_basis.z * 40.0 if _cam.projection == Camera3D.PROJECTION_ORTHOGONAL else _cam.global_position
	var dir := pp - from
	var dist := dir.length()
	if dist < 0.001:
		return
	dir /= dist
	var turned := not is_equal_approx(_bill_yaw, cam_yaw)
	_bill_yaw = cam_yaw
	var now := {}
	for id in _statics:
		var root: Node3D = _statics[id]
		if not is_instance_valid(root) or not root.visible:
			continue
		for c in root.get_meta("cards", []):
			var mi := c as MeshInstance3D
			if turned and mi.has_meta("billboard"):
				mi.rotation.y = cam_yaw
			if int(mi.get_meta("vsurf")) < 0:
				continue
			var d2 := Vector2(mi.position.x - pp.x, mi.position.z - pp.z)
			if d2.length_squared() > 900.0:   ## 30 m: nhìn thấp thì cây / nhà xa phía trước cũng che
				continue
			if _ray_card(from, dir, mi) < dist or _covers_player(mi, pp):
				now[mi.get_instance_id()] = mi
	for k in _faded.keys():
		if not now.has(k):
			var m: MeshInstance3D = _faded[k]
			if is_instance_valid(m):
				m.set_surface_override_material(int(m.get_meta("vsurf")), _card_material(m.get_meta("tex")))
			_faded.erase(k)
	for k in now:
		if not _faded.has(k):
			var m: MeshInstance3D = now[k]
			m.set_surface_override_material(int(m.get_meta("vsurf")), _tex_soft_material(m.get_meta("tex"), FADE_ALPHA))
			_faded[k] = m

## Tấm hình phủ lên nhân vật trên MÀN HÌNH (khung chiếu 8 góc chứa điểm thân / đầu / chân) và đứng GẦN camera hơn
## -> che. Bắt được tán cây chồng nhiều lớp khi hạ camera thấp mà 1 tia có thể trượt.
func _covers_player(mi: MeshInstance3D, pp: Vector3) -> bool:
	var back := _cam.global_basis.z
	var box := mi.global_transform * mi.get_aabb()
	if (box.get_center() - pp).dot(back) <= 0.3:
		return false
	var r := Rect2()
	for i in 8:
		var q := _cam.unproject_position(box.get_endpoint(i))
		r = Rect2(q, Vector2.ZERO) if i == 0 else r.expand(q)
	for h in [0.0, 0.45, 0.85]:
		if r.has_point(_cam.unproject_position(pp + Vector3(0, h - 0.45, 0))):
			return true
	return false

## Tia (o, d) cắt phần ĐỨNG của tấm hình (theo từng đoạn chân đế) -> khoảng cách, INF nếu trượt.
static func _ray_card(o: Vector3, d: Vector3, mi: MeshInstance3D) -> float:
	var xf := mi.global_transform
	var feet: PackedVector3Array = mi.get_meta("feet")
	var hmax := float(mi.get_meta("h"))
	var best := INF
	for i in feet.size() - 1:
		var b0: Vector3 = xf * feet[i]
		var b1: Vector3 = xf * feet[i + 1]
		var along := b1 - b0
		var n := along.cross(Vector3.UP)
		var den := d.dot(n)
		if along.length_squared() < 1e-6 or absf(den) < 1e-6:
			continue
		var t := (b0 - o).dot(n) / den
		if t <= 0.0 or t >= best:
			continue
		var hit := o + d * t
		var sp := (hit - b0).dot(along) / along.length_squared()
		var hy := hit.y - b0.y
		if sp >= 0.0 and sp <= 1.0 and hy >= 0.0 and hy <= hmax:
			best = t
	return best

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
	_ground_seq = (_ground_seq + 1) % 64
	_tint_floor(s.texture)
	_ground[id] = make_ground_quad(s, lift + _ground_seq * 0.00005)
	_ground_root.add_child(_ground[id])

## Nền dự phòng (chỗ chưa nạp: nhìn thấp thấy rất xa trước / sau) lấy MÀU TRUNG BÌNH của các tấm đất đã nạp, không chịu
## ánh sáng (như đất 3D) -> liền màu với mặt đất thay vì 1 dải màu be.
var _floor_sum := Vector3.ZERO
var _floor_n := 0
func _tint_floor(tex: Texture2D) -> void:
	if _floor == null or tex == null or _floor_n >= 16:
		return
	var c := _avg_color(tex)
	_floor_sum += Vector3(c.r, c.g, c.b)
	_floor_n += 1
	var m := StandardMaterial3D.new()
	var a := _floor_sum / _floor_n
	m.albedo_color = Color(a.x, a.y, a.z)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_floor.material_override = m

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
	## Ảnh nền vùng có viền TRONG SUỐT chồng sang vùng bên (2D bỏ qua chỗ trong suốt) -> phải cắt alpha, không thì
	## viền đó vẽ thành dải ĐEN đè lên vùng kế bên.
	mi.material_override = _tex_material(s.texture, true)
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

## Thanh máu trên đầu: 2 tấm (nền tối + phần máu) LUÔN QUAY MẶT VỀ CAMERA như tên (billboard), vẽ đè mọi thứ như 2D.
## Phần máu tính từ MÉP TRÁI: ảnh trắng HP_TEX_W x 1 px, cắt vùng rộng HP_TEX_W·tỉ lệ máu, gốc đặt ở mép trái thanh
## (offset tính trong mặt phẳng tấm nên xoay camera góc nào cũng đúng).
const HP_TEX_W := 100.0
const HP_BAR_W := 0.5     ## m (≈ 50 px như thanh máu 2D)
const HP_BAR_H := 0.06
static var _hp_tex: ImageTexture
func _make_hp_bar(c: Color) -> Node3D:
	if _hp_tex == null:
		var img := Image.create(int(HP_TEX_W), 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_hp_tex = ImageTexture.create_from_image(img)
	var bar := Node3D.new()
	for i in 2:
		var sp := Sprite3D.new()
		sp.texture = _hp_tex
		sp.centered = false
		sp.region_enabled = true
		sp.region_rect = Rect2(0, 0, HP_TEX_W, 1)
		sp.pixel_size = HP_BAR_W / HP_TEX_W
		sp.scale = Vector3(1.0, HP_BAR_H / sp.pixel_size, 1.0)
		sp.offset = Vector2(-HP_TEX_W * 0.5, -0.5)
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.no_depth_test = true
		sp.render_priority = 10 + i
		sp.modulate = Color(0.05, 0.05, 0.05, 0.75) if i == 0 else c
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.add_child(sp)
	return bar

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

## 1 vật thể map (nhà / cây / tường / đá / vật cản) -> 3D. Ưu tiên:
##   1. MODEL thả vào: res://data/avatar3d/structures/<tên ảnh>.glb (hoặc user://avatar3d/structures/, đuôi .gltf .fbx
##      .tscn). <tên ảnh> = tên file ảnh 2D của vật đó, bỏ đuôi. Gốc model = GIỮA CHÂN ĐẾ ảnh, mặt quay +Z (về phía
##      camera mặc định), 1 m = 100 px. Không sửa code.
##   2. TẤM HÌNH DỰNG TỪ ẢNH 2D (_make_card): phần ảnh phía trên đường chân đế dựng đứng, phần dưới (nền, bóng vẽ sẵn)
##      nằm phẳng dưới đất -> camera mặc định thấy y hệt 2D, xoay camera thì thấy nhà / tường đứng thật. Tường xiên
##      (ảnh có ma trận xô nghiêng) dựng theo đúng đường chéo chân tường; CÂY luôn quay mặt về camera.
## KHỐI cũ (_make_blocks) vẫn dựng, để ẩn trong node "Khoi" — xem nhanh chỗ đặt / cỡ model (bật visible).
const CELL2 := Vector2(32, 16)   ## ô vật cản trên màn hình 2D (VltkMap.cell)
const STRUCT_DIRS := ["user://avatar3d/structures/", "res://data/avatar3d/structures/"]
const STRUCT_EXTS := ["glb", "gltf", "fbx", "tscn"]
const FADE_ALPHA := 0.12   ## vật che nhân vật: gần trong suốt (nhìn thấp có 3-4 lớp cây chồng nhau)
static var _struct_model_file := {}   ## tên ảnh -> đường dẫn model ("" = không có)

func make_structure(h: Node2D, above: bool) -> Node3D:
	var blocks := _make_blocks(h, above)
	if blocks == null:
		return null
	var root := Node3D.new()
	root.visible = h.is_visible_in_tree()
	blocks.name = "Khoi"
	blocks.visible = false
	root.add_child(blocks)
	var sprites: Array = []
	for c in h.get_children():
		if c is Sprite2D and (c as Sprite2D).texture != null:
			sprites.append(c)
	if sprites.is_empty():
		blocks.visible = true
		return root
	var model := _structure_model(h)
	if model != null:
		var base := _card_base(sprites[0], h)
		model.position = base["pivot"]
		root.add_child(model)
		return root
	var color := _avg_color((sprites[0] as Sprite2D).texture)
	var cards: Array = []
	for sp in sprites:
		var sheared := absf((sp as Sprite2D).global_transform.x.y) > 0.01
		var is_tree := not above and not sheared and color.g > color.r * 1.04 and color.g > color.b * 1.1
		var card := _make_card(sp, h, is_tree)
		if card != null:
			root.add_child(card)
			cards.append(card)
	root.set_meta("cards", cards)
	return root

## Model thay ảnh (theo tên file ảnh trong map). null = chưa có.
static func _structure_model(h: Node2D) -> Node3D:
	var name := str(h.get_meta("img", "")).get_file().get_basename()
	if name == "":
		return null
	if not _struct_model_file.has(name):
		var found := ""
		for base in STRUCT_DIRS:
			for ext in STRUCT_EXTS:
				var f: String = base + name + "." + ext
				if FileAccess.file_exists(f) or ResourceLoader.exists(f):
					found = f
					break
			if found != "":
				break
		_struct_model_file[name] = found
	var file: String = _struct_model_file[name]
	if file == "":
		return null
	if file.ends_with(".tscn"):
		var ps := load(file) as PackedScene
		var n := ps.instantiate() if ps != null else null
		return n if n is Node3D else null
	return Model3DLoader._load_scene(file)

## Hàng ảnh làm CHÂN ĐẾ (toạ độ trong ảnh) + điểm giữa chân đế (3D). Ảnh xô nghiêng (tường chéo): hàng dưới cùng của
## ảnh nằm đúng chân tường. Ảnh thường: đường sắp độ sâu của holder (y của holder) là mép đất phía trước.
func _card_base(sp: Sprite2D, h: Node2D) -> Dictionary:
	var rect := sp.get_rect()
	var xf := sp.global_transform
	var vb := rect.end.y
	if absf(xf.x.y) <= 0.01 and absf(xf.y.y) > 0.0001:
		vb = clampf((h.global_position.y - xf.origin.y) / xf.y.y, rect.position.y, rect.end.y)
	var mid := Vector2((rect.position.x + rect.end.x) * 0.5, vb)
	return {"vb": vb, "pivot": to3d(xf * mid)}

## Tấm hình dựng từ ảnh 2D, chia CỘT dọc (CARD_COL px ảnh). Mỗi cột có CHÂN ĐẾ riêng (hàng ảnh vb[i]):
##   - Nhà, tường, đá...: chân đế từng cột = MÉP DƯỚI PHẦN ĐẶC của chính ảnh ở cột đó (_column_lows) = chỗ vật chạm đất
##     như đã vẽ -> tường nhiều ảnh nối nhau dựng LIỀN (2 ảnh kề chung điểm chân trên màn hình), nhà gấp theo mép nền.
##     Giới hạn trong dải [đường sắp độ sâu - bề ngang·0,6 ; đường sắp độ sâu + 1 ô] để mặt nền / bậc thềm không dựng đứng.
##   - Cây (quay theo camera) / cột trống: đường sắp độ sâu của holder.
## Điểm ảnh trên chân đế dựng đứng thẳng trên điểm chân cùng cột (cao = px màn hình / 0,866) -> góc camera mặc định
## thấy đúng từng điểm như 2D; dưới chân đế nằm đất. Đỉnh lưới tính so với giữa chân đế (node đặt ở đó).
const CARD_COL := 16.0
func _make_card(sp: Sprite2D, h: Node2D, billboard: bool) -> MeshInstance3D:
	var tex := sp.texture
	var rect := sp.get_rect()
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return null
	var xf := sp.global_transform
	var base := _card_base(sp, h)
	var pivot: Vector3 = base["pivot"]
	var ky := xf.y.length() / Z_SCREEN   ## 1 px ảnh theo chiều dọc -> px chiều cao 3D
	var tsz := Vector2(tex.get_size())
	var reg := sp.region_rect if sp.region_enabled else Rect2(Vector2.ZERO, tsz)
	var n := maxi(1, ceili(rect.size.x / CARD_COL))
	var us := PackedFloat32Array()
	for i in n + 1:
		us.append(lerpf(rect.position.x, rect.end.x, float(i) / n))
	var vb := PackedFloat32Array()
	vb.resize(n + 1)
	vb.fill(float(base["vb"]))
	if not billboard and xf.y.y > 0.0001:
		var lows := _column_lows(tex, reg, rect, us)
		var foot_y := float(h.global_position.y)
		var w := rect.size.x * xf.x.length()
		for i in lows.size():
			## y màn hình = gốc.y + u·x.y + v·y.y (ảnh có thể hơi xô) -> đổi giới hạn màn hình sang hàng ảnh của cột i
			var v_lo := (foot_y - w * 0.6 - CELL2.y - xf.origin.y - us[i] * xf.x.y) / xf.y.y
			var v_hi := (foot_y + CELL2.y - xf.origin.y - us[i] * xf.x.y) / xf.y.y
			var v := vb[i] if is_nan(lows[i]) else clampf(lows[i], v_lo, v_hi)
			vb[i] = clampf(v, rect.position.y, rect.end.y)
	var mesh := ArrayMesh.new()
	var vsurf := -1
	var height := 0.0
	for part in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		for i in n:
			var c0 := Vector2(us[i], rect.position.y if part == 0 else vb[i])
			var c1 := Vector2(us[i + 1], rect.position.y if part == 0 else vb[i + 1])
			var c2 := Vector2(us[i + 1], vb[i + 1] if part == 0 else rect.end.y)
			var c3 := Vector2(us[i], vb[i] if part == 0 else rect.end.y)
			if c3.y - c0.y < 0.5 and c2.y - c1.y < 0.5:
				continue
			any = true
			var q := [c0, c1, c2, c3]
			var bq := [vb[i], vb[i + 1], vb[i + 1], vb[i]]
			for k in [0, 1, 2, 0, 2, 3]:
				var c: Vector2 = q[k]
				st.set_normal(Vector3.BACK if part == 0 else Vector3.UP)
				st.set_uv((reg.position + (c - rect.position) / rect.size * reg.size) / tsz)
				st.add_vertex(_card_point(xf, c, bq[k], ky, pivot, part == 1))
			if part == 0:
				height = maxf(height, maxf(vb[i] - rect.position.y, vb[i + 1] - rect.position.y) * ky * PX)
		if not any:
			continue
		st.commit(mesh)
		if part == 0:
			vsurf = mesh.get_surface_count() - 1
	if mesh.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pivot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.get_surface_count():
		mi.set_surface_override_material(i, _card_material(tex) if i == vsurf else _tex_soft_material(tex, 1.0))
	if billboard:
		mi.rotation.y = cam_yaw
		mi.set_meta("billboard", true)
	## Làm mờ khi che nhân vật: đường chân đế gấp khúc (so với pivot) + chiều cao phần đứng (m).
	var feet := PackedVector3Array()
	for i in n + 1:
		feet.append(_card_point(xf, Vector2(us[i], vb[i]), vb[i], ky, pivot, false))
	mi.set_meta("feet", feet)
	mi.set_meta("h", height)
	mi.set_meta("vsurf", vsurf)
	mi.set_meta("tex", tex)
	return mi

## Điểm (u, v) trong ảnh -> 3D so với pivot. Phần đứng: thẳng trên điểm chân (u, vb) của cùng cột; phần nằm: đất.
static func _card_point(xf: Transform2D, c: Vector2, vb: float, ky: float, pivot: Vector3, flat: bool) -> Vector3:
	if not flat:
		return to3d(xf * Vector2(c.x, vb), maxf(0.0, vb - c.y) * ky) - pivot
	return to3d(xf * c, 0.8) - pivot

## Mép dưới phần ĐẶC (alpha >= 0,7 — bỏ bóng vẽ sẵn alpha ~0,5) của ảnh tại từng mốc cột `us` (toạ độ ảnh) -> hàng
## ảnh; NAN = cột trống. Mỗi mốc lấy trung vị các cột điểm ảnh quanh nó (bỏ nhiễu lá / chóp lẻ), rồi lọc trung vị 3 mốc.
## Hồ sơ cột tính 1 lần cho mỗi ảnh (cache theo texture).
static var _lows_cache := {}
static func _column_lows(tex: Texture2D, reg: Rect2, rect: Rect2, us: PackedFloat32Array) -> PackedFloat32Array:
	var key := tex.get_rid().get_id()
	if not _lows_cache.has(key):
		var low := PackedInt32Array()
		var img := tex.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			var data := img.get_data()
			var iw := img.get_width()
			low.resize(iw)
			for x in iw:
				low[x] = -1
				var y := img.get_height() - 1
				while y >= 0:
					if data[(y * iw + x) * 4 + 3] >= 179:   ## alpha >= 0,7
						low[x] = y
						break
					y -= 1
		_lows_cache[key] = low
	var low: PackedInt32Array = _lows_cache[key]
	var out := PackedFloat32Array()
	if low.is_empty():
		for u in us:
			out.append(NAN)
		return out
	var kx := reg.size.x / rect.size.x
	var ky := reg.size.y / rect.size.y
	for u in us:
		var cx := reg.position.x + (u - rect.position.x) * kx
		var vals: Array[int] = []
		for x in range(int(cx - CARD_COL * 0.5 * kx), int(cx + CARD_COL * 0.5 * kx) + 1):
			if x >= int(reg.position.x) and x < int(reg.end.x) and x < low.size() and low[x] >= int(reg.position.y):
				vals.append(mini(low[x], int(reg.end.y) - 1))
		if vals.is_empty():
			out.append(NAN)
			continue
		vals.sort()
		out.append(rect.position.y + (float(vals[vals.size() / 2]) + 1.0 - reg.position.y) / ky)
	var sm := out.duplicate()
	for i in range(1, out.size() - 1):
		if not is_nan(out[i - 1]) and not is_nan(out[i]) and not is_nan(out[i + 1]):
			var t := [out[i - 1], out[i], out[i + 1]]
			t.sort()
			sm[i] = t[1]
	return sm

## Phần đứng của tấm hình: cắt alpha ngưỡng CAO — bóng vẽ sẵn trong ảnh VLTK là điểm đen alpha ~50%, ngưỡng 0,5 sẽ
## giữ chúng thành mảng đen dựng đứng; bóng đã có ở phần nằm đất.
static func _card_material(tex: Texture2D) -> StandardMaterial3D:
	var key := "k%d" % tex.get_rid().get_id()
	if not _mat_cache.has(key):
		var m := (_tex_material(tex, true)).duplicate() as StandardMaterial3D
		m.alpha_scissor_threshold = 0.7
		_mat_cache[key] = m
	return _mat_cache[key]

static func _tex_soft_material(tex: Texture2D, alpha: float) -> StandardMaterial3D:
	var key := "s%d_%.2f" % [tex.get_rid().get_id(), alpha]
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = Color(1, 1, 1, alpha)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_cache[key] = m
	return _mat_cache[key]

## Khối thử của 1 vật thể (giữ làm chỗ / cỡ cho model). Ảnh VLTK nhìn xiên nên không biết thẳng chân đế -> lấy CHÂN ĐẾ
## từ lưới vật cản của map (ô bị chặn nằm dưới ảnh, sát đường sắp độ sâu): nhà = khối trên nền nhà, cây = thân trên ô
## gốc + tán lơ lửng, vật trang trí không chặn đường = khối thấp. Màu = màu trung bình của ảnh.
func _make_blocks(h: Node2D, above: bool) -> Node3D:
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
		"missile", "projectile", "effect":
			## Đạn / hiệu ứng chiêu: CHÉP FRAME 2D (ActorFrames3D) — ảnh, vùng cắt, độ cao, cộng sáng y bản 2D.
			var f := ActorFrames3D.new(n)
			f.show_shadow = false
			f.soft = true
			return {"src": n, "kind": kind, "node": f}
		"beam":
			## Tia nối (Line2D): thanh sáng 3D nối 2 đầu, màu / độ mờ theo Line2D.
			var b := MeshInstance3D.new()
			b.mesh = _box
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var bm := StandardMaterial3D.new()
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			b.material_override = bm
			return {"src": n, "kind": kind, "node": b}
		"drop":
			var d := _blob(Color(1.0, 0.82, 0.2), 0.14, true)
			return {"src": n, "kind": kind, "node": d}
		"corpse":
			## Xác quái: diễn động tác CHẾT bằng chính frame 2D (ActorFrames3D).
			return {"src": n, "kind": kind, "node": ActorFrames3D.new(n)}
		"damage":
			var l := Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.font_size = 40
			l.outline_size = 10
			l.pixel_size = 0.006
			return {"src": n, "kind": kind, "node": l, "y0": n.global_position.y}
	return {}

## Nhân vật / quái / NPC -> HÌNH DỰNG TỪ FRAME 2D (ActorFrames3D: đứng/chạy/đánh/chiêu/chết y bản 2D) + tên + thanh máu.
## Có model thì TỰ DÙNG model, không sửa code (docs/huong_dan_model_3d.md):
##   người: Actor3DRig (model cả người, hoặc model từng bộ phận gắn vào khe khối)
##   quái:  data/avatar3d/models/quai_<mã hình quái>/   ·   NPC: data/avatar3d/models/npc_<tên file ảnh NPC>/
## Khối màu cũ vẫn giữ làm dự phòng khi nguồn 2D không có hình nào.
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
	var frames := ActorFrames3D.new(n)
	root.add_child(frames)
	var model: Character3D = null
	var fallback: Node3D = null
	var av: Variant = n.get("avatar") if "avatar" in n else null
	if av is CharacterAvatar:
		## Người (player / người chơi khác / bot): rig GHÉP BỘ PHẬN như 2D — khe đầu, thân, tay, vũ khí, ngựa theo mã hình;
		## rig tự chọn model cả người / model bộ phận / hình frame.
		var rig := Actor3DRig.new(av)
		rig.frames = frames
		rig.visible = false
		pivot = rig
		root.add_child(pivot)
		size = Vector3(0.4, 0.9, 0.3)
	else:
		var mdir := Model3DLoader.model_dir(_model_name_of(n))
		if mdir != "":
			model = Character3D.new()
			if model.load_model(mdir):
				root.add_child(model)
				frames.visible = false
			else:
				model.free()
				model = null
		## Khối dự phòng (khi không có hình 2D nào): 1 khối + mũi chỉ hướng.
		fallback = Node3D.new()
		fallback.visible = false
		root.add_child(fallback)
		var body := MeshInstance3D.new()
		body.mesh = _box
		body.material_override = _color_material(color)
		body.scale = size
		body.position.y = size.y * 0.5
		fallback.add_child(body)
		var nose := MeshInstance3D.new()
		nose.mesh = _box
		nose.material_override = _color_material(color.darkened(0.5))
		nose.scale = Vector3(0.1, 0.1, 0.22)
		nose.position = Vector3(0, size.y * 0.75, size.z * 0.5 + 0.08)
		pivot = Node3D.new()
		pivot.add_child(nose)
		fallback.add_child(pivot)
	var label := Label3D.new()
	label.text = _name_of(n)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.pixel_size = 0.005
	label.no_depth_test = true   ## tên + thanh máu luôn đè lên trên như 2D (không bị người / hào quang đứng trước che)
	label.render_priority = 10
	label.modulate = color.lightened(0.4)
	label.position.y = size.y + 0.32
	root.add_child(label)
	var hp := _make_hp_bar(Color(0.95, 0.2, 0.2) if color.r > 0.8 and color.g < 0.4 else Color(0.3, 0.95, 0.35))
	hp.position.y = size.y + 0.18
	root.add_child(hp)
	return {"src": n, "kind": "actor", "node": root, "pivot": pivot, "hp": hp, "label": label,
		"half": size * 0.5, "last": VltkMath.ground_of(n), "yaw": 0.0, "frames": frames, "model": model,
		"fallback": fallback}

## Tên thư mục model của quái / NPC (Model3DLoader.model_dir). "" = không có.
static func _model_name_of(n: Node) -> String:
	if n is VltkMonster:
		return "quai_" + str((n as VltkMonster).data.get("res", ""))
	if n.has_meta("npc"):
		var d: Dictionary = n.get_meta("npc")
		var img := str(d.get("img", ""))
		if img != "":
			return "npc_" + img.get_file().get_basename()
	return ""

## Động tác quái 2D -> tên động tác chung của model (Model3DLoader.GAME_ACTIONS).
const MONSTER_ACTION_3D := {"stand": "stand", "walk": "run", "run": "run", "attack1": "attack", "attack2": "attack2",
	"magic": "cast", "hurt": "hurt", "die": "die"}

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
			"missile", "effect":
				## Gốc node 2D = điểm đất của đạn (to_world(logic)); độ cao Z đã nằm trong vị trí Sprite2D.
				n3.position = to3d(src.global_position)
				(n3 as ActorFrames3D).refresh(src.global_position, delta)
			"projectile":
				## Đạn kiểu cũ bay ở tầm thân (2D đặt ở chân - FEET_OFFSET).
				var gp := src.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
				n3.position = to3d(gp)
				(n3 as ActorFrames3D).refresh(gp, delta)
			"beam":
				_update_beam(n3 as MeshInstance3D, src)
			"drop":
				n3.position = to3d(src.global_position, 6.0)
			"corpse":
				n3.position = to3d(src.global_position)
				(n3 as ActorFrames3D).refresh(src.global_position, delta)
			"damage":
				var lab := n3 as Label3D
				var t := src.get_node_or_null("Text") as Label
				if t != null:
					lab.text = t.text
					lab.modulate = Color(t.get_theme_color("font_color"), src.modulate.a)
				var rise := maxf(0.0, float(e["y0"]) - src.global_position.y)
				n3.position = to3d(Vector2(src.global_position.x, float(e["y0"])) + Vector2(0, VltkWorld.FEET_OFFSET),
					90.0 + rise / Z_SCREEN)

## Tia nối: thanh dẹt từ điểm đầu tới điểm cuối của Line2D, ở tầm thân (~40 px), dày theo bề rộng nét.
func _update_beam(b: MeshInstance3D, src: Node2D) -> void:
	var line := src.get_node_or_null("Line2D") as Line2D
	if line == null or line.get_point_count() < 2:
		b.visible = false
		return
	var p0 := to3d(src.global_position + Vector2(0, VltkWorld.FEET_OFFSET), 40.0)
	var p1 := to3d(src.global_position + line.get_point_position(line.get_point_count() - 1) \
		+ Vector2(0, VltkWorld.FEET_OFFSET), 40.0)
	var len := p0.distance_to(p1)
	if len < 0.01:
		b.visible = false
		return
	var thick := maxf(line.width, 2.0) * PX
	b.transform = Transform3D(Basis.looking_at((p1 - p0) / len, Vector3.UP) * Basis.from_scale(Vector3(thick, thick, len)),
		(p0 + p1) * 0.5)
	var c := line.default_color
	(b.material_override as StandardMaterial3D).albedo_color = Color(c, c.a * line.modulate.a * src.modulate.a)

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
	var top := float(e["half"].y) * 2.0
	var frames: ActorFrames3D = e["frames"]
	var model: Character3D = e["model"]
	if model != null:
		if src is VltkMonster:
			var m := src as VltkMonster
			var a := TAU * float(m._dir64) / float(VltkMath.MAX_DIR)
			model.face_world(Vector3(-sin(a), 0.0, cos(a)))   ## hướng 64: 0 = xuống (+Z), 16 = trái (-X)
			var act: String = MONSTER_ACTION_3D.get(m._action, "stand")
			if model.action != act:
				model.play(act)
		else:
			model.face_world(Vector3(sin(float(e["yaw"])), 0.0, cos(float(e["yaw"]))))
	elif frames.visible:
		frames.refresh(g, delta)
		top = frames.top
		e["half"] = Vector3(maxf(0.2, frames.width * 0.5), top * 0.5, 0.25)
	var fb: Node3D = e["fallback"]
	if fb != null:
		fb.visible = model == null and frames.empty
	if pivot is Actor3DRig and (pivot as Actor3DRig).mode != "frames":
		top = 0.9
	var label: Label3D = e["label"]
	label.position.y = top + 0.22
	(e["hp"] as Node3D).position.y = top + 0.08
	var ratio := 1.0
	if "health" in src and "max_health" in src and float(src.get("max_health")) > 0.0:
		ratio = clampf(float(src.get("health")) / float(src.get("max_health")), 0.0, 1.0)
	var hp: Node3D = e["hp"]
	var fill := hp.get_child(1) as Sprite3D
	fill.region_rect = Rect2(0, 0, maxf(1.0, HP_TEX_W * ratio), 1)
	## Như 2D: ai có máu (người chơi, quái, người khác) LUÔN hiện thanh máu; NPC đứng không có máu thì không.
	hp.visible = "health" in src and "max_health" in src

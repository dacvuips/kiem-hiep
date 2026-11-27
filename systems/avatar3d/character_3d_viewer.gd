extends CanvasLayer
class_name Character3DViewer
## Màn XEM THỬ nhân vật 3D (nút "Xem thử nhân vật 3D" trong Cài đặt): sân đất phẳng + Character3D + camera xoay.
##   - Kéo chuột trái / phải, hoặc Q / E, hoặc nút ⟲ ⟳: xoay camera quanh nhân vật.
##   - Lăn chuột / nút + -: gần xa.  R / F: ngẩng / cúi camera.
##   - WASD / phím mũi tên: nhân vật chạy theo hướng NHÌN TỪ CAMERA và quay mặt theo hướng chạy.
##   - Hàng nút động tác: Đứng, Chạy, Đánh, Ra chiêu, Bị đánh, Chết.
## Chạy riêng 1 world 3D trong SubViewport, đè lên màn hiện tại; đóng là giải phóng hết.

const ACTIONS := [["Đứng", "stand"], ["Chạy", "run"], ["Đánh", "attack"], ["Ra chiêu", "cast"],
	["Bị đánh", "hurt"], ["Chết", "die"]]
const MOVE_SPEED := 2.4   ## đơn vị 3D / giây (= 240 px/s bản 2D)
const ROT_SPEED := 2.2    ## rad / giây khi giữ Q/E

var _gender := "male"
var _look: Dictionary = {}
var _baked_dir := ""
var _viewport: SubViewport
var _cam: Camera3D
var _char: Character3D
var _yaw := 0.0
var _pitch := deg_to_rad(-32.0)
var _dist := 2.6
var _dragging := false
var _hold_action := ""   ## động tác 1 lần đang diễn (không bị WASD đè về đứng/chạy)
var _info: Label

static func open(host: Node, gender: String = "male", look: Dictionary = {}, baked_dir: String = "") -> Character3DViewer:
	var v := Character3DViewer.new()
	v._gender = gender
	v._look = look
	v._baked_dir = baked_dir
	host.add_child(v)
	return v

func _ready() -> void:
	layer = 120
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.gui_input.connect(_on_view_input)
	root.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_viewport)
	_build_world()
	_build_ui(root)
	_update_camera()

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.15, 0.17)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	_viewport.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g = abs(fract(wp.xz) - 0.5);
	float line = step(0.48, max(g.x, g.y));
	float checker = mod(floor(wp.x) + floor(wp.z), 2.0);
	ALBEDO = mix(vec3(0.30, 0.36, 0.24), vec3(0.34, 0.40, 0.27), checker) * (1.0 - line * 0.35);
	ROUGHNESS = 1.0;
}"""
	mat.shader = sh
	ground.material_override = mat
	_viewport.add_child(ground)
	## Cột mốc 4 phía để dễ thấy camera đang xoay: đỏ = Bắc (-Z), xanh = Nam (+Z).
	for p in [[Vector3(0, 0, -4), Color(0.8, 0.2, 0.2)], [Vector3(0, 0, 4), Color(0.2, 0.4, 0.9)],
			[Vector3(-4, 0, 0), Color(0.8, 0.8, 0.8)], [Vector3(4, 0, 0), Color(0.8, 0.8, 0.8)]]:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 1.2, 0.25)
		var m := StandardMaterial3D.new()
		m.albedo_color = p[1]
		box.material = m
		post.mesh = box
		post.position = p[0] + Vector3(0, 0.6, 0)
		_viewport.add_child(post)

	_char = Character3D.new()
	if _baked_dir != "":
		_char.load_baked(_baked_dir)
	else:
		_char.set_look(_gender, _look)
	_char.action_finished.connect(func(_a: String) -> void: _hold_action = "")
	_viewport.add_child(_char)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_viewport.add_child(_cam)

func _build_ui(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -64
	bar.offset_bottom = -12
	bar.offset_left = 12
	bar.offset_right = -12
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bar)
	for a in ACTIONS:
		var b := SocialUi.stone_button(tr(a[0]), Vector2(84, 44))
		var act: String = a[1]
		b.pressed.connect(func() -> void: _play(act))
		bar.add_child(b)
	bar.add_child(VSeparator.new())
	for spec in [["⟲", -PI / 4.0], ["⟳", PI / 4.0]]:
		var b := SocialUi.stone_button(spec[0], Vector2(48, 44))
		var step: float = spec[1]
		b.pressed.connect(func() -> void:
			_yaw += step
			_update_camera())
		bar.add_child(b)
	for spec in [["+", -0.6], ["−", 0.6]]:
		var b := SocialUi.stone_button(spec[0], Vector2(44, 44))
		var step: float = spec[1]
		b.pressed.connect(func() -> void:
			_dist = clampf(_dist + step, 1.2, 12.0)
			_update_camera())
		bar.add_child(b)

	## Chọn nguồn hình: hình phẳng VLTK (8 hướng) hoặc 1 model 3D thật trong data/avatar3d/models/.
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_item(tr("Hình phẳng VLTK (8 hướng)"))
	pick.set_item_metadata(0, "")
	for m in Model3DLoader.list_models():
		pick.add_item(tr("Model 3D: %s") % m)
		pick.set_item_metadata(pick.item_count - 1, m)
	pick.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pick.offset_left = -330
	pick.offset_right = -66
	pick.offset_top = 14
	pick.offset_bottom = 54
	pick.item_selected.connect(func(i: int) -> void: use_model(str(pick.get_item_metadata(i))))
	root.add_child(pick)

	var close := SocialUi.stone_button("✕", Vector2(44, 44))
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -56
	close.offset_top = 12
	close.offset_right = -12
	close.pressed.connect(queue_free)
	root.add_child(close)

	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", bg)
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	_info = SocialUi.label("", SocialUi.TEXT, 14)
	col.add_child(_info)
	col.add_child(SocialUi.label(tr("Kéo chuột / Q E: xoay camera · Lăn chuột: gần xa · R F: ngẩng cúi · WASD: chạy"),
		SocialUi.MUTED, 13))

## "" = hình phẳng; tên khác = model 3D trong Model3DLoader.
func use_model(model_name: String) -> void:
	var act := _char.action if _char.action in Character3D.LOOPING else "stand"
	_hold_action = ""
	if model_name == "":
		if _baked_dir != "":
			_char.load_baked(_baked_dir)
		else:
			_char.set_look(_gender, _look)
	else:
		_char.load_model(Model3DLoader.model_dir(model_name))
	_char.play(act)

func _play(act: String) -> void:
	_hold_action = "" if act in Character3D.LOOPING else act
	_char.play(act)

func _on_view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = e.pressed
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = clampf(_dist - 0.3, 1.2, 12.0)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = clampf(_dist + 0.3, 2.0, 12.0)
		_update_camera()
	elif e is InputEventMouseMotion and _dragging:
		_yaw -= e.relative.x * 0.008
		_pitch = clampf(_pitch - e.relative.y * 0.005, deg_to_rad(-80), deg_to_rad(-5))
		_update_camera()
	elif e is InputEventScreenDrag:
		_yaw -= e.relative.x * 0.008
		_update_camera()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var rot := 0.0
	if Input.is_key_pressed(KEY_Q): rot -= 1.0
	if Input.is_key_pressed(KEY_E): rot += 1.0
	var tilt := 0.0
	if Input.is_key_pressed(KEY_R): tilt += 1.0
	if Input.is_key_pressed(KEY_F): tilt -= 1.0
	if rot != 0.0 or tilt != 0.0:
		_yaw += rot * ROT_SPEED * delta
		_pitch = clampf(_pitch + tilt * delta, deg_to_rad(-80), deg_to_rad(-5))

	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1.0
	if mv != Vector2.ZERO and _hold_action == "":
		## Phím theo hướng nhìn của camera: W = đi ra xa camera.
		var right := Vector3(cos(_yaw), 0, -sin(_yaw))
		var back := Vector3(sin(_yaw), 0, cos(_yaw))
		var dir := (right * mv.x + back * mv.y).normalized()
		_char.position += dir * MOVE_SPEED * delta
		_char.face_world(dir)
		if _char.action != "run":
			_char.play("run")
	elif _hold_action == "" and _char.action == "run" and mv == Vector2.ZERO:
		_char.play("stand")
	_update_camera()
	var cam_deg := wrapi(roundi(rad_to_deg(_yaw)), 0, 360)
	if _char.is_model():
		var anim := _char.model_animation_for(_char.action)
		_info.text = tr("Model 3D · Động tác: %s (%s) · Góc camera: %d°") % [_char.action,
			anim if anim != "" else tr("không có, dùng Đứng"), cam_deg]
	else:
		_info.text = tr("Hình phẳng · Động tác: %s · Hướng vẽ: %d/8 · Góc camera: %d°") % [_char.action,
			_char.direction, cam_deg]

func _update_camera() -> void:
	if _cam == null:
		return
	var target := _char.position + Vector3(0, 0.4, 0)
	var off := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_cam.position = target + off
	_cam.look_at(target, Vector3.UP)

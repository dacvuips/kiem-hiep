extends Node3D
class_name Character3D
## Nhân vật trong CHẾ ĐỘ 3D: tấm hình đứng thẳng (billboard trục Y) dùng bộ hình 8 hướng của AvatarBaker.
## Hướng vẽ tính theo góc GIỮA hướng nhân vật quay mặt và camera -> xoay camera quanh nhân vật thì thấy đúng
## mặt trước / bên / lưng như nhìn vòng quanh một người thật. Logic (vị trí, hướng, động tác) vẫn là của bản 2D.
##
## Hệ toạ độ: 2D (x, y) <-> 3D (x * PX, 0, y * PX); 1 đơn vị 3D = 100 px bản 2D. Hướng 2D "xuống" = +Z.
##
##   c.set_look("male", {"helm": 3, "armor": 5, "weapon": 2})   # nướng lười từng động tác (cache dùng chung)
##   c.load_baked("res://data/avatar3d/demo")                   # hoặc nạp bộ đã nướng bằng tools/bake_character_3d.gd
##   c.load_model("res://data/avatar3d/models/nguoi_go")      # hoặc MODEL 3D THẬT (.glb/.fbx có xương, Model3DLoader)
##   c.play("run");  c.face_world(Vector3(1, 0, 0))
## Model 3D: quay mượt theo hướng mặt (không cần tính theo camera), chuyển động tác có hoà trộn. Động tác model
## không có -> lùi về "stand".

signal action_finished(action: String)

const PX := 0.01
const LOOPING := ["stand", "run", "sit"]

## Cache bộ hình nướng sẵn: look_key|action -> baked (Image + ImageTexture). Nhiều nhân vật cùng dáng dùng chung.
static var _cache: Dictionary = {}

var action: String = "stand"
var facing := Vector3(0, 0, 1)        ## hướng quay mặt trong thế giới 3D (mặt phẳng XZ)
var direction: int = 0                ## hướng sprite đang vẽ 0..7 (đã trừ góc camera)

var _gender := "male"
var _look: Dictionary = {}
var _baked_dir := ""                  ## khác "" = dùng bộ hình trên đĩa thay vì nướng lúc chạy
var _baked_meta: Dictionary = {}
var _cur: Dictionary = {}             ## bộ hình động tác đang chạy
var _sprite: Sprite3D
var _shadow: MeshInstance3D
var _time := 0.0
var _speed := 1.0
var _frame := -1
var _finished := false

## ---- Chế độ MODEL 3D ----
const MODEL_BLEND := 0.15      ## giây hoà trộn khi đổi động tác
const MODEL_TURN_SPEED := 14.0 ## tốc độ quay mặt (càng lớn càng nhanh)
var _model: Dictionary = {}    ## Model3DLoader.instantiate(): root/player/map/meta
var _model_holder: Node3D      ## xoay node này theo hướng mặt; model co giãn bên trong
var _model_yaw := 0.0

func _ready() -> void:
	_sprite = Sprite3D.new()
	_sprite.pixel_size = PX
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD   ## cắt nền trong suốt -> có depth, tự che khuất đúng
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = _make_shadow_mesh()
	_shadow.position.y = 0.005
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	if is_model():
		_sprite.visible = false
		play(action)
	elif _cur.is_empty():
		play(action)

## Dùng model 3D thật trong thư mục `dir` (xem Model3DLoader). false = không nạp được (giữ hình phẳng).
func load_model(dir: String) -> bool:
	var m := Model3DLoader.instantiate(dir)
	if m.is_empty():
		return false
	_clear_model()
	_model = m
	_model_holder = Node3D.new()
	_model_holder.name = "Model"
	add_child(_model_holder)
	var root: Node3D = m["root"]
	_model_holder.add_child(root)
	var meta: Dictionary = m["meta"]
	var box := Model3DLoader.mesh_aabb(root)
	var height := float(meta.get("height", 0.8))
	if box.size.y > 0.0001:
		var k := height / box.size.y
		root.scale = Vector3.ONE * k
		root.position = Vector3(-(box.position.x + box.size.x * 0.5) * k, -box.position.y * k,
			-(box.position.z + box.size.z * 0.5) * k)
	root.rotation.y = deg_to_rad(float(meta.get("yaw_offset_deg", 0.0)))
	var player: AnimationPlayer = m["player"]
	player.animation_finished.connect(_on_model_anim_finished)
	_model_yaw = atan2(facing.x, facing.z)
	_model_holder.rotation.y = _model_yaw
	if _sprite != null:
		_sprite.visible = false
	if is_inside_tree():
		play(action)
	return true

func is_model() -> bool:
	return not _model.is_empty()

## Tên động tác game -> tên animation trong model ("" = model không có).
func model_animation_for(game_action: String) -> String:
	return str(_model.get("map", {}).get(game_action, "")) if is_model() else ""

func _clear_model() -> void:
	if _model_holder != null:
		_model_holder.queue_free()
	_model_holder = null
	_model = {}
	if _sprite != null:
		_sprite.visible = true

func set_look(gender: String, look: Dictionary) -> void:
	_clear_model()
	_gender = gender
	_look = look.duplicate()
	_baked_dir = ""
	if is_inside_tree():
		play(action)

## Nạp bộ hình do tools/bake_character_3d.gd xuất (thư mục có character.json + <động tác>.png).
func load_baked(dir_path: String) -> bool:
	var text := FileAccess.get_file_as_string(dir_path.path_join("character.json"))
	var meta: Variant = JSON.parse_string(text) if text != "" else null
	if not meta is Dictionary:
		push_error("Character3D: thiếu %s/character.json" % dir_path)
		return false
	_baked_dir = dir_path
	_baked_meta = meta
	_gender = str(meta.get("gender", "male"))
	if is_inside_tree():
		play(action)
	return true

func play(new_action: String, duration: float = -1.0) -> void:
	action = new_action
	if is_model():
		_play_model(new_action, duration)
		return
	_cur = _get_baked(new_action)
	if _cur.is_empty() and new_action != "stand":
		_cur = _get_baked("stand")
	_time = 0.0
	_frame = -1
	_finished = false
	if _cur.is_empty() or _sprite == null:
		return
	_sprite.texture = _cur["texture"]
	var fs: Vector2i = _cur["frame_size"]
	var foot: Vector2 = _cur["foot"]
	## centered = false: gốc Sprite3D ở GÓC DƯỚI-TRÁI của hình, trục y hướng lên -> dời để CHÂN nằm đúng gốc node.
	_sprite.offset = Vector2(-foot.x, -(fs.y - foot.y))
	var natural := float(_cur["frames"]) / float(_cur["fps"])
	_speed = natural / duration if duration > 0.0 and natural > 0.0 else 1.0
	_apply_frame()

func _play_model(game_action: String, duration: float) -> void:
	var player: AnimationPlayer = _model["player"]
	var anim_name := model_animation_for(game_action)
	if anim_name == "":
		anim_name = model_animation_for("stand")
	if anim_name == "":
		return
	var anim := player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR if game_action in LOOPING else Animation.LOOP_NONE
	var spd := float(_model["meta"].get("speed", {}).get(game_action, 1.0))
	if duration > 0.0 and anim.length > 0.0:
		spd = anim.length / duration
	_finished = false
	player.play(anim_name, MODEL_BLEND, spd)
	if player.current_animation == anim_name and not game_action in LOOPING:
		player.seek(0.0, true)

func _on_model_anim_finished(_anim: StringName) -> void:
	if action in LOOPING or _finished:
		return
	_finished = true
	action_finished.emit(action)

func get_action_duration() -> float:
	if is_model():
		var n := model_animation_for(action)
		return (_model["player"] as AnimationPlayer).get_animation(n).length if n != "" else 0.0
	return float(_cur["frames"]) / float(_cur["fps"]) if not _cur.is_empty() else 0.0

## Quay mặt theo hướng trong thế giới 3D (bỏ trục Y).
func face_world(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()

## Quay mặt theo vector 2D của bản chơi (x phải, y xuống) — dùng khi logic vẫn chạy ở 2D.
func face_2d(vec: Vector2) -> void:
	face_world(Vector3(vec.x, 0.0, vec.y))

func _process(delta: float) -> void:
	if is_model():
		## Model thật: chỉ cần quay node theo hướng mặt, camera nhìn góc nào cũng đúng.
		var target := atan2(facing.x, facing.z)
		_model_yaw = lerp_angle(_model_yaw, target, minf(1.0, delta * MODEL_TURN_SPEED))
		_model_holder.rotation.y = _model_yaw
		return
	if _cur.is_empty():
		return
	_update_direction()
	if _finished:
		return
	_time += delta * _speed
	var frames: int = _cur["frames"]
	var frame := int(_time * float(_cur["fps"]))
	if action in LOOPING:
		frame %= maxi(frames, 1)
	elif frame >= frames:
		_finished = true
		_set_frame(frames - 1)
		action_finished.emit(action)
		return
	_set_frame(frame)

## Hướng sprite = hướng quay mặt nhìn TỪ CAMERA: chiếu `facing` lên trục phải / trục "về phía camera" của camera
## rồi dùng đúng công thức 8 hướng của CharacterAvatar.face (0 = quay về camera, tăng theo chiều kim đồng hồ).
func _update_direction() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var rel := Vector2(facing.x, facing.z)
	if cam != null:
		var right := cam.global_basis.x
		var toward := cam.global_basis.z   ## camera nhìn theo -Z -> +Z là hướng về phía camera
		right.y = 0.0
		toward.y = 0.0
		if right.length_squared() > 0.0001 and toward.length_squared() > 0.0001:
			rel = Vector2(facing.dot(right.normalized()), facing.dot(toward.normalized()))
	var d := wrapi(roundi((rad_to_deg(rel.angle()) - 90.0) / 45.0), 0, 8)
	if d != direction:
		direction = d
		_apply_frame()

func _set_frame(frame: int) -> void:
	if frame != _frame:
		_frame = frame
		_apply_frame()

func _apply_frame() -> void:
	if _cur.is_empty() or _sprite == null:
		return
	var fs: Vector2i = _cur["frame_size"]
	_sprite.region_rect = Rect2(maxi(_frame, 0) * fs.x, direction * fs.y, fs.x, fs.y)

func _get_baked(game_action: String) -> Dictionary:
	var key := ("disk:" + _baked_dir if _baked_dir != "" else AvatarBaker.look_key(_gender, _look)) + "|" + game_action
	if _cache.has(key):
		return _cache[key]
	var baked: Dictionary = {}
	if _baked_dir != "":
		var info: Dictionary = _baked_meta.get("actions", {}).get(game_action, {})
		if not info.is_empty():
			var img := Image.new()
			if img.load_png_from_buffer(FileAccess.get_file_as_bytes(_baked_dir.path_join(str(info["file"])))) == OK:
				baked = {"image": img, "frames": int(info["frames"]), "fps": float(info.get("fps", 18)),
					"frame_size": Vector2i(int(info["frame_size"][0]), int(info["frame_size"][1])),
					"foot": Vector2(float(info["foot"][0]), float(info["foot"][1]))}
	else:
		baked = AvatarBaker.bake_action(_gender, _look, game_action)
	if not baked.is_empty():
		baked["texture"] = ImageTexture.create_from_image(baked["image"])
		baked.erase("image")   ## giữ texture GPU, bỏ bản CPU cho nhẹ RAM
	_cache[key] = baked
	return baked

static func _make_shadow_mesh() -> Mesh:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.45))
	grad.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.7, 0.4)
	plane.material = mat
	return plane

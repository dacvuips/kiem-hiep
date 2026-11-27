extends RefCounted
class_name Model3DLoader
## Nạp MODEL 3D THẬT cho Character3D (cách 2: Tripo -> Mixamo -> .glb/.fbx).
##
## Mỗi model 1 thư mục trong MODELS_DIR (hoặc user://avatar3d/models/ — chép file vào là dùng, không cần mở editor):
##   model.glb | model.gltf | model.fbx    model có xương (+ có thể kèm sẵn động tác)
##   anim_*.glb / anim_*.fbx               (tuỳ chọn) mỗi file 1 động tác Mixamo tải riêng ("Without Skin"),
##                                         gộp vào model nếu tên xương khớp (Mixamo: mixamorig_*)
##   model.json                            (tuỳ chọn) chỉnh tay:
##     {"height": 0.8,                         chiều cao đứng (m) — tự co giãn cho bằng; 0.8 = cỡ hình phẳng
##      "yaw_offset_deg": 0,                   model quay mặt lệch thì xoay bù (Mixamo/Tripo quay +Z: để 0)
##      "animations": {"stand": "Idle", "run": "Running", "attack": "Punching", ...},
##      "speed": {"run": 1.2}}                 hệ số tốc độ riêng từng động tác
## Không có model.json: tự đoán động tác theo tên (idle/run/attack/cast/hit/death...).

const MODELS_DIR := "res://data/avatar3d/models/"
const USER_MODELS_DIR := "user://avatar3d/models/"
const MODEL_FILES := ["model.glb", "model.gltf", "model.fbx"]
const GAME_ACTIONS := ["stand", "run", "attack", "attack2", "cast", "hurt", "die", "jump", "sit"]
## Từ khoá đoán tên động tác (chữ thường, so "chứa"). Thứ tự = ưu tiên.
const GUESS := {
	"stand": ["idle", "stand", "breath"],
	"run": ["run", "sprint", "jog", "walk"],
	"attack": ["attack", "punch", "slash", "sword", "strike", "hit_", "kick", "combo"],
	"attack2": ["attack2", "kick", "slash2", "combo"],
	"cast": ["cast", "spell", "magic", "skill", "power"],
	"hurt": ["hurt", "impact", "damage", "react", "hit"],
	"die": ["death", "die", "dying", "dead"],
	"jump": ["jump"],
	"sit": ["sit", "meditat"],
}

static var _scene_cache: Dictionary = {}   ## đường dẫn file -> Node mẫu (nhân bản cho từng nhân vật)

## Danh sách tên model có trên máy (res:// + user://).
static func list_models() -> PackedStringArray:
	var out := PackedStringArray()
	for base in [MODELS_DIR, USER_MODELS_DIR]:
		var d := DirAccess.open(base)
		if d == null:
			continue
		for name in d.get_directories():
			if find_model_file(base + name) != "" and not out.has(name):
				out.append(name)
	return out

static func model_dir(name: String) -> String:
	for base in [USER_MODELS_DIR, MODELS_DIR]:
		if find_model_file(base + name) != "":
			return base + name
	return ""

static func find_model_file(dir: String) -> String:
	for f in MODEL_FILES:
		if FileAccess.file_exists(dir.path_join(f)):
			return dir.path_join(f)
	return ""

## Dựng 1 bản model: {"root": Node3D, "player": AnimationPlayer, "map": {game_action: anim_name}, "meta": Dictionary}
## {} nếu lỗi.
static func instantiate(dir: String) -> Dictionary:
	var file := find_model_file(dir)
	if file == "":
		return {}
	var meta: Dictionary = {}
	var meta_text := FileAccess.get_file_as_string(dir.path_join("model.json"))
	if meta_text != "":
		var parsed: Variant = JSON.parse_string(meta_text)
		if parsed is Dictionary:
			meta = parsed
	var root := _load_scene(file)
	if root == null:
		return {}
	var player := _find_player(root)
	if player == null:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		root.add_child(player)
	## Gộp động tác từ anim_*.glb/fbx (Mixamo tải mỗi động tác 1 file).
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			var low := f.to_lower()
			if low.begins_with("anim_") and (low.ends_with(".glb") or low.ends_with(".fbx") or low.ends_with(".gltf")):
				_merge_animations(player, root, dir.path_join(f), f.get_basename().substr(5))
	var map := _build_map(player, meta.get("animations", {}))
	return {"root": root, "player": player, "map": map, "meta": meta}

## .glb/.fbx trong res:// đã được editor import -> load() thẳng; ngoài ra (user://, chưa import) đọc lúc chạy
## bằng GLTFDocument / FBXDocument.
static func _load_scene(file: String) -> Node3D:
	if not _scene_cache.has(file):
		var node: Node = null
		if file.begins_with("res://") and ResourceLoader.exists(file):
			var ps := load(file) as PackedScene
			if ps != null:
				node = ps.instantiate()
		if node == null:
			var doc: Variant = FBXDocument.new() if file.to_lower().ends_with(".fbx") else GLTFDocument.new()
			var state: Variant = FBXState.new() if file.to_lower().ends_with(".fbx") else GLTFState.new()
			var err: int = doc.append_from_file(ProjectSettings.globalize_path(file), state)
			if err == OK:
				node = doc.generate_scene(state)
			else:
				push_error("Model3DLoader: không đọc được %s (lỗi %d)" % [file, err])
		_scene_cache[file] = node
	var proto: Node = _scene_cache[file]
	if proto == null:
		return null
	var copy := proto.duplicate()
	if copy is Node3D:
		return copy
	var wrap := Node3D.new()
	wrap.add_child(copy)
	return wrap

static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var p := _find_player(c)
		if p != null:
			return p
	return null

static func _merge_animations(player: AnimationPlayer, model_root: Node, file: String, fallback_name: String) -> void:
	var src := _load_scene(file)
	if src == null:
		return
	var src_player := _find_player(src)
	if src_player != null:
		var lib_name := "extra"
		if not player.has_animation_library(lib_name):
			player.add_animation_library(lib_name, AnimationLibrary.new())
		var lib := player.get_animation_library(lib_name)
		var names := src_player.get_animation_list()
		for an in names:
			var anim := src_player.get_animation(an).duplicate() as Animation
			## Đường dẫn track tính từ gốc của AnimationPlayer: sửa lại cho khớp model chính.
			_retarget_paths(anim, src_player, src, player, model_root)
			var key := fallback_name if names.size() == 1 else "%s_%s" % [fallback_name, an]
			lib.add_animation(key.validate_node_name(), anim)
	src.free()

## Track "Armature/Skeleton3D:mixamorig_Hips" của file động tác có thể khác đường dẫn trong model chính
## -> tìm Skeleton3D trong model chính và đổi phần node, giữ tên xương.
static func _retarget_paths(anim: Animation, _src_player: AnimationPlayer, _src_root: Node, player: AnimationPlayer,
		model_root: Node) -> void:
	var skel := _find_skeleton(model_root)
	if skel == null:
		return
	var anim_root: Node = player.get_node(player.root_node)
	var skel_path := String(anim_root.get_path_to(skel))
	for t in anim.get_track_count():
		var p := String(anim.track_get_path(t))
		var colon := p.find(":")
		if colon < 0:
			continue
		anim.track_set_path(t, NodePath(skel_path + p.substr(colon)))

static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null

static func _build_map(player: AnimationPlayer, manual: Dictionary) -> Dictionary:
	var names := player.get_animation_list()
	var map := {}
	for act in manual:
		if player.has_animation(str(manual[act])):
			map[act] = str(manual[act])
	for act in GAME_ACTIONS:
		if map.has(act):
			continue
		for key in GUESS.get(act, []):
			for n in names:
				var low := String(n).to_lower()
				if key in low.get_slice("/", low.get_slice_count("/") - 1):  ## bỏ tiền tố thư viện "extra/"
					map[act] = String(n)
					break
			if map.has(act):
				break
	return map

## Hộp bao mọi mesh (toạ độ của `root`) — để co giãn model cho đúng chiều cao.
static func mesh_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b: AABB = root.global_transform.affine_inverse() * m.global_transform * m.get_aabb() \
			if root.is_inside_tree() else _local_xform(root, m) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

static func _local_xform(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

extends SceneTree
## Dựng NGƯỜI GỖ THỬ (model 3D có xương + 6 động tác) và xuất ra .glb — để thử đường đi của model thật
## (Tripo -> Mixamo -> .glb -> Model3DLoader -> Character3D) khi chưa có model.
## Xương đặt tên kiểu Mixamo (Hips, Spine, LeftArm...), động tác đặt tên kiểu Mixamo (Idle, Running, Sword Slash...)
## nên Model3DLoader tự nhận ra mà không cần model.json khai tên.
##
## Cần GPU (KHÔNG chạy --headless — server đồ hoạ giả không giữ dữ liệu mesh để xuất):
##   godot --path . --script tools/make_test_mannequin.gd
## Ra: res://data/avatar3d/models/nguoi_go/model.glb + model.json

const OUT_DIR := "res://data/avatar3d/models/nguoi_go"

## Xương: tên, cha, vị trí đầu xương trong model (mét, đứng thẳng, mặt quay +Z, tay trái = +X).
const BONES := [
	["Hips", "", Vector3(0, 0.95, 0)],
	["Spine", "Hips", Vector3(0, 1.10, 0)],
	["Chest", "Spine", Vector3(0, 1.35, 0)],
	["Neck", "Chest", Vector3(0, 1.60, 0)],
	["Head", "Neck", Vector3(0, 1.68, 0)],
	["LeftArm", "Chest", Vector3(0.24, 1.52, 0)],
	["LeftForeArm", "LeftArm", Vector3(0.24, 1.24, 0)],
	["LeftHand", "LeftForeArm", Vector3(0.24, 0.98, 0)],
	["RightArm", "Chest", Vector3(-0.24, 1.52, 0)],
	["RightForeArm", "RightArm", Vector3(-0.24, 1.24, 0)],
	["RightHand", "RightForeArm", Vector3(-0.24, 0.98, 0)],
	["LeftUpLeg", "Hips", Vector3(0.10, 0.92, 0)],
	["LeftLeg", "LeftUpLeg", Vector3(0.10, 0.50, 0)],
	["LeftFoot", "LeftLeg", Vector3(0.10, 0.08, 0)],
	["RightUpLeg", "Hips", Vector3(-0.10, 0.92, 0)],
	["RightLeg", "RightUpLeg", Vector3(-0.10, 0.50, 0)],
	["RightFoot", "RightLeg", Vector3(-0.10, 0.08, 0)],
]

const SKIN := Color(0.93, 0.76, 0.60)
const CLOTH := Color(0.16, 0.45, 0.85)
const PANTS := Color(0.92, 0.90, 0.84)
const DARK := Color(0.12, 0.10, 0.10)
const METAL := Color(0.80, 0.82, 0.88)
const BELT := Color(0.55, 0.38, 0.18)

## Khối hộp: xương, tâm, cỡ, màu.
const PARTS := [
	["Hips", Vector3(0, 0.96, 0), Vector3(0.34, 0.16, 0.20), PANTS],
	["Spine", Vector3(0, 1.10, 0), Vector3(0.35, 0.14, 0.20), BELT],
	["Chest", Vector3(0, 1.36, 0), Vector3(0.42, 0.40, 0.23), CLOTH],
	["Neck", Vector3(0, 1.62, 0), Vector3(0.09, 0.08, 0.09), SKIN],
	["Head", Vector3(0, 1.79, 0), Vector3(0.21, 0.24, 0.23), SKIN],
	["Head", Vector3(0, 1.86, -0.02), Vector3(0.23, 0.12, 0.25), DARK],     ## tóc
	["Head", Vector3(0, 1.96, -0.03), Vector3(0.08, 0.08, 0.08), DARK],     ## búi tóc
	["Head", Vector3(0, 1.78, 0.125), Vector3(0.04, 0.05, 0.03), SKIN],     ## mũi -> thấy mặt quay hướng nào
	["LeftArm", Vector3(0.24, 1.38, 0), Vector3(0.11, 0.30, 0.11), CLOTH],
	["LeftForeArm", Vector3(0.24, 1.11, 0), Vector3(0.09, 0.27, 0.09), SKIN],
	["LeftHand", Vector3(0.24, 0.93, 0), Vector3(0.08, 0.10, 0.08), SKIN],
	["RightArm", Vector3(-0.24, 1.38, 0), Vector3(0.11, 0.30, 0.11), CLOTH],
	["RightForeArm", Vector3(-0.24, 1.11, 0), Vector3(0.09, 0.27, 0.09), SKIN],
	["RightHand", Vector3(-0.24, 0.93, 0), Vector3(0.08, 0.10, 0.08), SKIN],
	["RightHand", Vector3(-0.24, 0.92, 0.38), Vector3(0.025, 0.035, 0.70), METAL],  ## kiếm
	["RightHand", Vector3(-0.24, 0.92, 0.05), Vector3(0.10, 0.03, 0.03), BELT],     ## chuôi
	["LeftUpLeg", Vector3(0.10, 0.71, 0), Vector3(0.15, 0.42, 0.16), PANTS],
	["LeftLeg", Vector3(0.10, 0.29, 0), Vector3(0.12, 0.42, 0.13), PANTS],
	["LeftFoot", Vector3(0.10, 0.04, 0.05), Vector3(0.12, 0.08, 0.25), DARK],
	["RightUpLeg", Vector3(-0.10, 0.71, 0), Vector3(0.15, 0.42, 0.16), PANTS],
	["RightLeg", Vector3(-0.10, 0.29, 0), Vector3(0.12, 0.42, 0.13), PANTS],
	["RightFoot", Vector3(-0.10, 0.04, 0.05), Vector3(0.12, 0.08, 0.25), DARK],
]

var _skel: Skeleton3D

func _initialize() -> void:
	var root := Node3D.new()
	root.name = "NguoiGo"
	get_root().add_child(root)
	_skel = Skeleton3D.new()
	_skel.name = "Skeleton3D"
	root.add_child(_skel)
	for b in BONES:
		var idx := _skel.add_bone(b[0])
		var parent_pos := Vector3.ZERO
		if b[1] != "":
			_skel.set_bone_parent(idx, _skel.find_bone(b[1]))
			parent_pos = _bone_pos(b[1])
		_skel.set_bone_rest(idx, Transform3D(Basis(), b[2] - parent_pos))
	_skel.reset_bone_poses()

	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = _build_mesh()
	_skel.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = _skel.create_skin_from_rest_transforms()

	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	for spec in _animations():
		lib.add_animation(spec[0], spec[1])
	ap.add_animation_library("", lib)

	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT_DIR.path_join("model.glb")))
	var f := FileAccess.open(OUT_DIR.path_join("model.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"height": 0.8, "yaw_offset_deg": 0,
		"note": "Người gỗ thử do tools/make_test_mannequin.gd dựng. Động tác tự nhận theo tên kiểu Mixamo."}, "\t"))
	f.close()
	print("Xuất %s: %s" % [OUT_DIR.path_join("model.glb"), "OK" if err == OK else "LỖI %d" % err])
	quit(0 if err == OK else 1)

func _bone_pos(name: String) -> Vector3:
	for b in BONES:
		if b[0] == name:
			return b[2]
	return Vector3.ZERO

## Mỗi màu 1 surface (1 vật liệu) — xuất glTF chắc ăn hơn màu theo đỉnh. Mỗi khối gắn cứng 1 xương (trọng số 1).
func _build_mesh() -> ArrayMesh:
	var by_color := {}
	for p in PARTS:
		if not by_color.has(p[3]):
			by_color[p[3]] = []
		by_color[p[3]].append(p)
	var mesh := ArrayMesh.new()
	for color in by_color:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in by_color[color]:
			_add_box(st, _skel.find_bone(p[0]), p[1], p[2])
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		if color == METAL:
			mat.metallic = 0.7
			mat.roughness = 0.3
		st.set_material(mat)
		st.commit(mesh)
	return mesh

func _add_box(st: SurfaceTool, bone: int, c: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	## 6 mặt: pháp tuyến + 2 trục trên mặt.
	var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var corners := []
		for s in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			corners.append(c + (n + u * s[1] + v * s[0]) * h)
		## Godot: mặt trước theo chiều kim đồng hồ khi nhìn từ phía pháp tuyến.
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_bones(PackedInt32Array([bone, 0, 0, 0]))
			st.set_weights(PackedFloat32Array([1, 0, 0, 0]))
			st.add_vertex(corners[i])

## ---- Động tác (khung xoay theo độ; X > 0 = gập ra SAU với tay/chân thõng xuống, cúi người TỚI với thân) ----
func _animations() -> Array:
	var out := []
	out.append(["Idle", _anim(2.0, true, {
		"Chest": [[0, Vector3(0, 0, 0)], [1.0, Vector3(3, 0, 0)], [2.0, Vector3(0, 0, 0)]],
		"LeftArm": [[0, Vector3(0, 0, 8)], [1.0, Vector3(0, 0, 10)], [2.0, Vector3(0, 0, 8)]],
		"RightArm": [[0, Vector3(-10, 0, -8)], [1.0, Vector3(-12, 0, -10)], [2.0, Vector3(-10, 0, -8)]],
		"RightForeArm": [[0, Vector3(-25, 0, 0)], [2.0, Vector3(-25, 0, 0)]],
	})])
	var run := 0.66
	out.append(["Running", _anim(run, true, {
		"Spine": [[0, Vector3(12, 0, 0)], [run, Vector3(12, 0, 0)]],
		"LeftUpLeg": [[0, Vector3(-40, 0, 0)], [run / 2, Vector3(35, 0, 0)], [run, Vector3(-40, 0, 0)]],
		"RightUpLeg": [[0, Vector3(35, 0, 0)], [run / 2, Vector3(-40, 0, 0)], [run, Vector3(35, 0, 0)]],
		"LeftLeg": [[0, Vector3(20, 0, 0)], [run / 4, Vector3(70, 0, 0)], [run / 2, Vector3(15, 0, 0)],
			[run * 0.75, Vector3(30, 0, 0)], [run, Vector3(20, 0, 0)]],
		"RightLeg": [[0, Vector3(15, 0, 0)], [run / 4, Vector3(30, 0, 0)], [run / 2, Vector3(20, 0, 0)],
			[run * 0.75, Vector3(70, 0, 0)], [run, Vector3(15, 0, 0)]],
		"LeftArm": [[0, Vector3(35, 0, 6)], [run / 2, Vector3(-35, 0, 6)], [run, Vector3(35, 0, 6)]],
		"RightArm": [[0, Vector3(-35, 0, -6)], [run / 2, Vector3(35, 0, -6)], [run, Vector3(-35, 0, -6)]],
		"LeftForeArm": [[0, Vector3(-40, 0, 0)], [run, Vector3(-40, 0, 0)]],
		"RightForeArm": [[0, Vector3(-40, 0, 0)], [run, Vector3(-40, 0, 0)]],
	})])
	out.append(["Sword Slash", _anim(0.8, false, {
		"Chest": [[0, Vector3(0, 0, 0)], [0.3, Vector3(-5, 25, 0)], [0.5, Vector3(10, -30, 0)], [0.8, Vector3(0, 0, 0)]],
		"RightArm": [[0, Vector3(-10, 0, -8)], [0.3, Vector3(-160, 0, -20)], [0.5, Vector3(-50, 0, 20)],
			[0.8, Vector3(-10, 0, -8)]],
		"RightForeArm": [[0, Vector3(-25, 0, 0)], [0.3, Vector3(-20, 0, 0)], [0.5, Vector3(0, 0, 0)],
			[0.8, Vector3(-25, 0, 0)]],
		"LeftUpLeg": [[0, Vector3(0, 0, 0)], [0.4, Vector3(-25, 0, 0)], [0.8, Vector3(0, 0, 0)]],
		"LeftLeg": [[0, Vector3(0, 0, 0)], [0.4, Vector3(25, 0, 0)], [0.8, Vector3(0, 0, 0)]],
	})])
	out.append(["Spell Cast", _anim(1.0, false, {
		"Chest": [[0, Vector3(0, 0, 0)], [0.4, Vector3(-8, 0, 0)], [0.75, Vector3(-8, 0, 0)], [1.0, Vector3(0, 0, 0)]],
		"LeftArm": [[0, Vector3(0, 0, 8)], [0.4, Vector3(-95, 0, -10)], [0.75, Vector3(-95, 0, -10)], [1.0, Vector3(0, 0, 8)]],
		"RightArm": [[0, Vector3(-10, 0, -8)], [0.4, Vector3(-95, 0, 10)], [0.75, Vector3(-95, 0, 10)],
			[1.0, Vector3(-10, 0, -8)]],
		"Head": [[0, Vector3(0, 0, 0)], [0.4, Vector3(-10, 0, 0)], [1.0, Vector3(0, 0, 0)]],
	})])
	out.append(["Hit Reaction", _anim(0.5, false, {
		"Spine": [[0, Vector3(0, 0, 0)], [0.12, Vector3(-22, 0, 5)], [0.5, Vector3(0, 0, 0)]],
		"Head": [[0, Vector3(0, 0, 0)], [0.12, Vector3(-18, 0, 0)], [0.5, Vector3(0, 0, 0)]],
		"LeftArm": [[0, Vector3(0, 0, 8)], [0.12, Vector3(20, 0, 30)], [0.5, Vector3(0, 0, 8)]],
		"RightArm": [[0, Vector3(-10, 0, -8)], [0.12, Vector3(20, 0, -30)], [0.5, Vector3(-10, 0, -8)]],
	})])
	var die := _anim(1.2, false, {
		"Hips": [[0, Vector3(0, 0, 0)], [0.5, Vector3(-30, 0, 0)], [1.0, Vector3(-88, 0, 0)], [1.2, Vector3(-88, 0, 0)]],
		"LeftUpLeg": [[0, Vector3(0, 0, 0)], [0.5, Vector3(-40, 0, 0)], [1.0, Vector3(0, 0, 5)]],
		"RightUpLeg": [[0, Vector3(0, 0, 0)], [0.5, Vector3(-30, 0, 0)], [1.0, Vector3(0, 0, -5)]],
		"LeftLeg": [[0, Vector3(0, 0, 0)], [0.5, Vector3(70, 0, 0)], [1.0, Vector3(5, 0, 0)]],
		"RightLeg": [[0, Vector3(0, 0, 0)], [0.5, Vector3(60, 0, 0)], [1.0, Vector3(5, 0, 0)]],
		"LeftArm": [[0, Vector3(0, 0, 8)], [1.0, Vector3(0, 0, 80)]],
		"RightArm": [[0, Vector3(-10, 0, -8)], [1.0, Vector3(0, 0, -80)]],
	})
	## Hạ hông xuống đất khi ngã ngửa (vị trí xương là tuyệt đối trong cha).
	var t := die.add_track(Animation.TYPE_POSITION_3D)
	die.track_set_path(t, NodePath("Skeleton3D:Hips"))
	die.position_track_insert_key(t, 0.0, Vector3(0, 0.95, 0))
	die.position_track_insert_key(t, 0.5, Vector3(0, 0.70, -0.15))
	die.position_track_insert_key(t, 1.0, Vector3(0, 0.12, -0.35))
	die.position_track_insert_key(t, 1.2, Vector3(0, 0.12, -0.35))
	out.append(["Dying", die])
	return out

func _anim(length: float, loop: bool, tracks: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for bone in tracks:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:" + bone))
		for key in tracks[bone]:
			var e: Vector3 = key[1]
			a.rotation_track_insert_key(t, key[0], Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y),
				deg_to_rad(e.z))))
	return a

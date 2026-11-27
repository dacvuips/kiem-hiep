extends SceneTree
## Chụp màn xem thử nhân vật 3D ở vài góc camera (cần GPU, KHÔNG chạy --headless):
##   godot --path . --script tests/character_3d_shot.gd
func _initialize() -> void:
	var v := Character3DViewer.open(root)
	for i in 8:
		await process_frame
	var n := 0
	for spec in [[0.0, "run"], [PI / 2.0, "stand"], [PI, "attack"], [PI * 1.5, "cast"]]:
		v._yaw = spec[0]
		v._char.face_world(Vector3(0, 0, 1))
		v._play(spec[1])
		for i in 12:
			await process_frame
		v._viewport.get_texture().get_image().save_png("user://char3d_shot_%d.png" % n)
		print("shot %d yaw=%d dir=%d" % [n, roundi(rad_to_deg(spec[0])), v._char.direction])
		n += 1
	## Model 3D thật (người gỗ thử): xoay camera + đổi động tác.
	if Model3DLoader.list_models().has("nguoi_go"):
		v.use_model("nguoi_go")
		print("model map: ", v._char._model.get("map"))
		for spec in [[0.6, "stand", 20], [2.2, "run", 9], [3.6, "attack", 9], [5.0, "cast", 12], [0.6, "die", 40]]:
			v._yaw = spec[0]
			v._char.face_world(Vector3(0, 0, 1))
			v._play(spec[1])
			for i in spec[2]:
				await process_frame
			v._viewport.get_texture().get_image().save_png("user://char3d_shot_%d.png" % n)
			print("shot %d model %s anim=%s" % [n, spec[1], v._char.model_animation_for(spec[1])])
			n += 1
	quit()

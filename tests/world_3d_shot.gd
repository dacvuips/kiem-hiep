extends Node
## Chế độ 3D trong map: vào Giang Tân Thôn (map 20) offline, bật 3D (không ghi file cài đặt), đi + auto đánh, chụp
## user://w3d_*.png (cả màn) và w3d_*_3d.png (riêng lớp 3D). Cần GPU:
##   godot --path . --resolution 1280x720 res://tests/world_3d_shot.tscn
var runner := false
func _ready() -> void:
	if not runner:
		var r = get_script().new()
		r.runner = true
		get_tree().root.add_child.call_deferred(r)
		return
	GameSettings._load()
	GameSettings._render_3d = true   ## không ghi file cài đặt
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = MapCatalog.get_by_id(20)
	GameManager.current_stage = null
	GameManager.is_game_over = false
	get_tree().change_scene_to_file.call_deferred("res://Main.tscn")
	await get_tree().create_timer(7.0).timeout
	## W3D_POS="x,y" (toạ độ mini map, 1 ô = 256 px): dịch nhân vật tới đó.
	var pos_env := OS.get_environment("W3D_POS")
	if pos_env != "":
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		var xy := pos_env.split(",")
		pl.global_position = Vector2(float(xy[0]) * 256.0 + 128.0, float(xy[1]) * 256.0 + 128.0) - Vector2(0, VltkWorld.FEET_OFFSET)
		await get_tree().create_timer(12.0).timeout
	var shot := func(name: String) -> void:
		for pop in get_tree().root.find_children("*", "SocialWindow", true, false):
			pop.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().root.get_viewport().get_texture().get_image().save_png("user://w3d_%s.png" % name)
		if World3DView.current != null:
			World3DView.current._vp.get_texture().get_image().save_png("user://w3d_%s_3d.png" % name)
		print("shot ", name, " active=", World3DView.is_active())
	await shot.call("a")
	var v := World3DView.current
	if v != null:
		print("ground=", v._ground.size(), " statics=", v._statics.size(), " dynamic=", v._dynamic.size())
		var kinds := {}
		for id in v._dynamic:
			kinds[v._dynamic[id]["kind"]] = kinds.get(v._dynamic[id]["kind"], 0) + 1
		print("kinds=", kinds)
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("_set_move_target"):
		p._set_move_target(p.global_position + Vector2(220, 80))
	await get_tree().create_timer(2.0).timeout
	await shot.call("b")
	## Bật auto đánh nếu có
	if p != null:
		p.is_auto_mode = true
	await get_tree().create_timer(6.0).timeout
	await shot.call("c")
	if v != null:
		var kinds := {}
		for id in v._dynamic:
			kinds[v._dynamic[id]["kind"]] = kinds.get(v._dynamic[id]["kind"], 0) + 1
		print("kinds2=", kinds)
		print("mouse center->", World3DView.screen_to_world(get_viewport().get_visible_rect().size * 0.5, get_viewport()), " player=", p.global_position)
	## Xoay camera 90° + ngẩng lên, chụp thêm.
	World3DView.cam_yaw = PI / 2.0
	World3DView.cam_pitch_deg = 45.0
	print("dir up after yaw90 -> ", World3DView.screen_dir_to_world(Vector2(0, -1)))
	await get_tree().create_timer(0.5).timeout
	await shot.call("d")
	World3DView.cam_yaw = 0.0
	World3DView.cam_pitch_deg = World3DView.PITCH_DEG
	get_tree().quit()

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
	## Nhân vật thử chưa có phái -> popup chọn phái (kèm lớp chặn cả màn) che map: vào đại 1 phái hợp hệ (không ghi save).
	for i in 120:
		await get_tree().process_frame
		if GameManager.local_profile != null:
			break
	var prof := GameManager.local_profile
	if prof != null and prof.needs_sect():
		for sect in SectRegistry.load_all():
			if prof.join_sect(sect):
				print("vao phai: ", sect.sect_name)
				break
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
		for blk in get_tree().root.find_children("SectBlocker", "", true, false):
			blk.get_parent().queue_free()   ## lớp chặn sau popup chọn môn phái (nhân vật thử chưa có phái)
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
	## Xoay bằng 2 ngón tay (giả lập cảm ứng) rồi Alt + kéo chuột trái.
	var yaw0 := World3DView.cam_yaw
	for i in 2:
		var t := InputEventScreenTouch.new()
		t.index = i
		t.pressed = true
		t.position = Vector2(300 + i * 150, 300)
		Input.parse_input_event(t)
	for k in 10:
		for i in 2:
			var d := InputEventScreenDrag.new()
			d.index = i
			d.relative = Vector2(-12, 0)
			d.position = Vector2(300 + i * 150 - k * 12, 300)
			Input.parse_input_event(d)
		await get_tree().process_frame
	for i in 2:
		var t := InputEventScreenTouch.new()
		t.index = i
		t.pressed = false
		Input.parse_input_event(t)
	await get_tree().process_frame
	print("2 ngon: yaw ", yaw0, " -> ", World3DView.cam_yaw)
	var yaw1 := World3DView.cam_yaw
	for pop in get_tree().root.find_children("*", "SocialWindow", true, false):
		pop.free()
	for blk in get_tree().root.find_children("SectBlocker", "", true, false):
		blk.get_parent().free()
	var mv := InputEventMouseMotion.new()   ## cập nhật ô giao diện dưới con trỏ trước khi bấm (như chuột thật)
	mv.position = Vector2(30, 400)
	Input.parse_input_event(mv)
	await get_tree().process_frame
	await get_tree().process_frame
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.alt_pressed = true
	b.position = Vector2(30, 400)
	Input.parse_input_event(b)
	for k in 5:
		var m := InputEventMouseMotion.new()
		m.relative = Vector2(30, 0)
		m.position = Vector2(30 + k * 2, 400)
		Input.parse_input_event(m)
		await get_tree().process_frame
	b = b.duplicate()
	b.pressed = false
	Input.parse_input_event(b)
	await get_tree().process_frame
	print("alt+keo: yaw ", yaw1, " -> ", World3DView.cam_yaw, " pitch=", World3DView.cam_pitch_deg)
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
	World3DView.cam_pitch_deg = 45.0
	print("dir up after yaw90 -> ", World3DView.screen_dir_to_world(Vector2(0, -1)))
	await get_tree().create_timer(0.5).timeout
	await shot.call("d")
	World3DView.cam_yaw = 0.0
	World3DView.cam_pitch_deg = World3DView.PITCH_DEG
	get_tree().quit()

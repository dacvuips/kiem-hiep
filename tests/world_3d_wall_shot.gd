extends Node
## Chế độ 3D: nhà / tường dựng từ ảnh 2D có nối liền khi xoay camera không. Vào Giang Tân Thôn (map 20) offline, đứng cạnh
## dải tường đá, chụp lớp 3D ở vài góc xoay: user://w3d_wall_<góc>.png. Cần GPU:
##   godot --path . --resolution 1280x720 res://tests/world_3d_wall_shot.tscn
## W3D_POS="x,y" (toạ độ 2D px) đổi chỗ đứng.
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
	for i in 120:
		await get_tree().process_frame
		if GameManager.local_profile != null:
			break
	var prof := GameManager.local_profile
	if prof != null and prof.needs_sect():
		for sect in SectRegistry.load_all():
			if prof.join_sect(sect):
				break
	await get_tree().create_timer(5.0).timeout
	var at := Vector2(113560, 97700)
	var env := OS.get_environment("W3D_POS")
	if env != "":
		var xy := env.split(",")
		at = Vector2(float(xy[0]), float(xy[1]))
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	pl.global_position = at - Vector2(0, VltkWorld.FEET_OFFSET)
	await get_tree().create_timer(6.0).timeout
	for pop in get_tree().root.find_children("*", "SocialWindow", true, false):
		pop.queue_free()
	for blk in get_tree().root.find_children("SectBlocker", "", true, false):
		blk.get_parent().queue_free()
	World3DView.cam_pitch_deg = 35.0
	for deg in [0, 45, 80, -45, -80, 180]:
		World3DView.cam_yaw = deg_to_rad(deg)
		pl.global_position = at - Vector2(0, VltkWorld.FEET_OFFSET)
		await get_tree().create_timer(0.4).timeout
		if World3DView.current != null:
			World3DView.current._vp.get_texture().get_image().save_png("user://w3d_wall_%d.png" % deg)
		print("wall shot ", deg)
	## Góc thấp (nhìn ngang nhân vật): user://w3d_low_<ngẩng>_<xoay>.png
	for pd in [5, 12]:
		for yd in [0, 40]:
			World3DView.cam_pitch_deg = float(pd)
			World3DView.cam_yaw = deg_to_rad(yd)
			pl.global_position = at - Vector2(0, VltkWorld.FEET_OFFSET)
			await get_tree().create_timer(1.5).timeout   ## đợi nạp thêm vùng bản đồ
			World3DView.current._vp.get_texture().get_image().save_png("user://w3d_low_%d_%d.png" % [pd, yd])
			print("  thap %d/%d: ban kinh nap = %d" % [pd, yd, VltkWorld.current.map.load_radius_regions])
			if OS.get_environment("W3D_DEBUG") != "":
				var mp: VltkMap = VltkWorld.current.map
				for sy in [400, 550, 700]:
					var w := World3DView.current._screen_to_world(Vector2(640, sy), false)
					var rg := mp.world_to_region(w)
					print("    y=%d -> dat %s vung %s nap=%s info=%s" % [sy, w.round(), rg, mp._tiles.has("%d,%d" % [rg.x, rg.y]), mp.region_info(rg)])
				print("    tiles=", mp._tiles.size(), " ground3d=", World3DView.current._ground.size(), " cam=", World3DView.current._cam.global_position, " far=", World3DView.current._cam.far)
	World3DView.cam_pitch_deg = World3DView.PITCH_DEG
	await get_tree().process_frame
	await get_tree().process_frame
	print("low shots pitch_min=", World3DView.PITCH_MIN, " ban kinh nap khi ve 30 do = ", VltkWorld.current.map.load_radius_regions)
	## Tắt 3D khi đang hạ thấp: bản 2D phải về đúng bán kính nạp gốc.
	World3DView.cam_pitch_deg = 5.0
	await get_tree().create_timer(0.3).timeout
	var r3 := VltkWorld.current.map.load_radius_regions
	GameSettings._render_3d = false
	World3DView.sync()
	await get_tree().process_frame
	await get_tree().process_frame
	print("3D thap: ban kinh ", r3, " -> tat 3D: ", VltkWorld.current.map.load_radius_regions, " (2D phai = 2)")
	GameSettings._render_3d = true
	World3DView.sync()
	await get_tree().create_timer(0.5).timeout
	World3DView.cam_pitch_deg = World3DView.PITCH_DEG
	## Chiêu VLTK thật, từng chiêu một: DỪNG game, chụp 2D THUẦN (ẩn lớp 3D) rồi 3D cùng khoảnh khắc ->
	## user://w3d_fx_<chiêu>_<lần>_2d.png / _3d.png. W3D_SKILLS="1105,1107" chọn chiêu.
	World3DView.cam_pitch_deg = World3DView.PITCH_DEG
	World3DView.cam_yaw = 0.0
	var skills: Array = [1105, 1107, 1060, 1070, 1300]
	var senv := OS.get_environment("W3D_SKILLS")
	if senv != "":
		skills = Array(senv.split(",")).map(func(x): return int(x))
	var view := World3DView.current
	for sid in skills:
		pl.global_position = at - Vector2(0, VltkWorld.FEET_OFFSET)
		await get_tree().create_timer(0.6).timeout
		var ctx := VltkCastContext.new()
		ctx.launcher = pl
		ctx.world = VltkWorld.current
		ctx.attacker_stats = pl.get("combat_stats")
		VltkSkillCaster.cast(ctx, sid, 20, VltkMath.logic_of(pl) + Vector2(260, 140), null)
		for k in 4:
			await get_tree().create_timer(0.15).timeout
			if view == null:
				break
			get_tree().paused = true
			view._container.visible = false
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_tree().root.get_viewport().get_texture().get_image().save_png("user://w3d_fx_%d_%d_2d.png" % [sid, k])
			view._container.visible = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			view._vp.get_texture().get_image().save_png("user://w3d_fx_%d_%d_3d.png" % [sid, k])
			_measure(view, pl, "%d/%d" % [sid, k])
			get_tree().paused = false
		print("fx ", sid)
		await get_tree().create_timer(1.0).timeout
	World3DView.cam_yaw = 0.0
	World3DView.cam_pitch_deg = World3DView.PITCH_DEG
	get_tree().quit()

## So vị trí trên MÀN HÌNH (tính từ chân nhân vật) của từng đạn / hiệu ứng giữa bản 2D và lớp 3D (camera mặc định
## phải trùng gần như 1:1). In: loại, tâm ảnh 2D, tâm ảnh 3D, lệch (px).
func _measure(view: World3DView, pl: Node2D, tag: String) -> void:
	var av: Node2D = pl.get("avatar")
	var p2 := av.get_global_transform_with_canvas().origin
	var p3 := view._cam.unproject_position(World3DView.to3d(VltkMath.ground_of(pl)))
	for id in view._dynamic:
		var e: Dictionary = view._dynamic[id]
		if not e["kind"] in ["missile", "effect", "projectile"]:
			continue
		var src: Node2D = e["src"]
		var s2 := src.get_node_or_null("Sprite") as Sprite2D
		if s2 == null or not s2.is_visible_in_tree():
			continue
		var c2 := s2.get_global_transform_with_canvas() * s2.get_rect().get_center() - p2
		var f: ActorFrames3D = e["node"]
		var sp: Sprite3D = null
		for c in f.get_children():
			if c is Sprite3D and (c as Sprite3D).visible:
				sp = c
				break
		if sp == null:
			print("  ", tag, " ", e["kind"], " 2D=", c2.round(), " 3D=(khong hien)")
			continue
		var c3 := view._cam.unproject_position(sp.global_transform * sp.get_aabb().get_center()) - p3
		print("  ", tag, " ", e["kind"], " z=", src.get("_z"), " 2D=", c2.round(), " 3D=", c3.round(), " lech=", (c3 - c2).round())

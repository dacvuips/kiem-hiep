extends Node
## Đạn bay xa trong chế độ 3D: mỗi chiêu bắn 8 hướng (tầm 600 logic) ở Giang Tân Thôn, ghi đường bay từng viên rồi kiểm:
##   1. HƯỚNG ẢNH 2D: hướng 64 của đạn (dir) so với hướng bay thật (điểm đầu -> cuối) và hàng ảnh dùng (image_dir).
##   2. 2D vs 3D ở góc mặc định: tâm ảnh trên màn hình + vùng cắt ảnh phải trùng.
##   3. XOAY CAMERA 90°: ảnh 3D phải là hướng đã bù góc (sprite_region_for_dir(dir + 16)).
## Chụp user://w3d_mdir_<chiêu>_<hướng>_<2d|3d|yaw90>.png. Cần GPU:
##   godot --path . --resolution 1280x720 res://tests/world_3d_missile_dir.tscn      (W3D_SKILLS="22,186" chọn chiêu)
var runner := false
var fails := 0

func _ready() -> void:
	if not runner:
		var r = get_script().new()
		r.runner = true
		get_tree().root.add_child.call_deferred(r)
		return
	GameSettings._load()
	GameSettings._render_3d = true
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
	for pop in get_tree().root.find_children("*", "SocialWindow", true, false):
		pop.queue_free()
	for blk in get_tree().root.find_children("SectBlocker", "", true, false):
		blk.get_parent().queue_free()
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	var at := Vector2(114236, 97797)   ## bãi trống giữa Giang Tân Thôn
	var view := World3DView.current
	var skills: Array = [22, 186, 321, 1063, 336, 357]
	var senv := OS.get_environment("W3D_SKILLS")
	if senv != "":
		skills = Array(senv.split(",")).map(func(x): return int(x))
	for sid in skills:
		var s := VltkSkillData.skill(sid, 20)
		var worst_dir := 0
		var worst_img := 0
		var n_missiles := 0
		var pos_bad := 0
		var reg_bad := 0
		var example := {}
		for k in 8:
			World3DView.cam_yaw = 0.0
			pl.global_position = at - Vector2(0, VltkWorld.FEET_OFFSET)
			await get_tree().create_timer(0.25).timeout
			var a := TAU * k / 8.0
			var des := VltkMath.logic_of(pl) + Vector2(cos(a), sin(a)) * 600.0
			_cast(pl, sid, des)
			var track := {}   ## missile id -> {"m", "first", "last", "dir", "img", "dirs"}
			var t := 0.0
			var shot := false
			while t < 1.4:
				await get_tree().process_frame
				t += get_process_delta_time()
				for m in VltkMissile.active_missiles:
					if not is_instance_valid(m) or not m._sprite.visible:
						continue
					var id := m.get_instance_id()
					var fly: Variant = m._phase(VltkSkillData.Phase.FLY)
					var dirs := maxi(1, int(fly["dirs"])) if fly is Dictionary else 1
					if not track.has(id):
						track[id] = {"m": m, "first": m.logic, "prev": m.logic, "dirs": dirs, "dd": 0, "di": 0, "mk": m._move_kind}
					var tr: Dictionary = track[id]
					tr["last"] = m.logic
					## Hướng TỨC THỜI (đoạn từ mẫu trước) so với hướng ảnh đạn đang dùng.
					var seg: Vector2 = m.logic - tr["prev"]
					if seg.length() >= 12.0:
						var travel := VltkMath.dir_between(tr["prev"], m.logic)
						tr["dd"] = maxi(int(tr["dd"]), absi(wrapi(m.dir - travel, -32, 32)))
						tr["di"] = maxi(int(tr["di"]), absi(wrapi(VltkMath.image_dir(m.dir, dirs) - VltkMath.image_dir(travel, dirs),
							-dirs / 2, dirs / 2)))
						if int(tr["di"]) > 1 and not tr.has("ex"):
							tr["ex"] = "dir=%d bay=%d (%s -> %s)" % [m.dir, travel, tr["prev"], m.logic]
						tr["prev"] = m.logic
				## Giữa đường bay: dừng game, so 2D / 3D rồi xoay 90° so ảnh đã bù hướng.
				if not shot and t > 0.35 and not VltkMissile.active_missiles.is_empty():
					shot = true
					var r := await _compare(view, pl, "%d_%d" % [sid, k])
					pos_bad += r[0]
					reg_bad += r[1]
			for id in track:
				var e: Dictionary = track[id]
				if (e["last"] - e["first"]).length() < 60.0:
					continue
				n_missiles += 1
				worst_dir = maxi(worst_dir, int(e["dd"]))
				worst_img = maxi(worst_img, int(e["di"]))
				if e.has("ex") and not example.has(sid):
					example[sid] = "huong %d, kieu bay %d: %s" % [k, int(e["mk"]), e["ex"]]
		var ok := worst_img <= 1 and pos_bad == 0 and reg_bad == 0
		if not ok:
			fails += 1
		print("%s chieu %d %s: %d vien bay | lech huong dan/huong bay toi da %d/64, lech hang anh %d | 2D-3D lech vi tri %d, sai anh %d" % [
			"OK " if ok else "SAI", sid, str(s.get("name", "")), n_missiles, worst_dir, worst_img, pos_bad, reg_bad])
		if example.has(sid):
			print("     vi du: ", example[sid])
	World3DView.cam_yaw = 0.0
	print("KET QUA: ", "dat" if fails == 0 else "%d chieu sai" % fails)
	get_tree().quit()

func _cast(pl: Node2D, sid: int, des: Vector2) -> void:
	var ctx := VltkCastContext.new()
	ctx.launcher = pl
	ctx.world = VltkWorld.current
	ctx.attacker_stats = pl.get("combat_stats")
	VltkSkillCaster.cast(ctx, sid, 20, des, null)

## [số viên lệch vị trí > 2 px, số viên sai vùng ảnh] — góc mặc định và sau khi xoay 90°.
func _compare(view: World3DView, pl: Node2D, tag: String) -> Array:
	var bad_pos := 0
	var bad_reg := 0
	get_tree().paused = true
	## Dừng ngay đầu khung (trước _process): cập nhật lớp 3D theo vị trí đạn mới nhất như 1 khung bình thường.
	view._scan_dynamic()
	view._update_dynamic(0.0)
	view._container.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_tree().root.get_viewport().get_texture().get_image().save_png("user://w3d_mdir_%s_2d.png" % tag)
	view._container.visible = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	view._vp.get_texture().get_image().save_png("user://w3d_mdir_%s_3d.png" % tag)
	if OS.get_environment("W3D_NEAR") != "":
		var seen := {}
		for id in view._dynamic:
			seen[(view._dynamic[id]["src"] as Object).get_instance_id()] = view._dynamic[id]
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and (n as Node2D).global_position.distance_to(pl.global_position) < 150.0:
				var e: Dictionary = seen.get(n.get_instance_id(), {})
				print("   GAN ", World3DView._name_of(n), " cha=", n.get_parent().name, " vis2d=", (n as Node2D).is_visible_in_tree(),
					" co3d=", not e.is_empty(), " vis3d=", e["node"].visible if not e.is_empty() else false,
					" rong=", (e["frames"] as ActorFrames3D).empty if not e.is_empty() else true,
					" 2D=", (n as Node2D).get_global_transform_with_canvas().origin.round(),
					" 3D=", view._cam.unproject_position((e["node"] as Node3D).global_position).round() if not e.is_empty() else Vector2.ZERO,
					" ten3D=", view._cam.unproject_position((e["label"] as Label3D).global_position).round() if not e.is_empty() else Vector2.ZERO,
					" lift=", ((e["frames"] as ActorFrames3D).get_child(1) as Node3D).position if not e.is_empty() and (e["frames"] as Node).get_child_count() > 1 else Vector3.ZERO)
	var av: Node2D = pl.get("avatar")
	var p2 := av.get_global_transform_with_canvas().origin
	var p3 := view._cam.unproject_position(World3DView.to3d(VltkMath.ground_of(pl)))
	for id in view._dynamic:
		var e: Dictionary = view._dynamic[id]
		if e["kind"] != "missile" or not is_instance_valid(e["src"]):
			continue
		var m := e["src"] as VltkMissile
		var s2 := m._sprite
		if not s2.is_visible_in_tree():
			continue
		var sp := _first_sprite3d(e["node"])
		if sp == null:
			bad_pos += 1
			continue
		var c2 := s2.get_global_transform_with_canvas() * s2.get_rect().get_center() - p2
		var c3 := view._cam.unproject_position(sp.global_transform * sp.get_aabb().get_center()) - p3
		if c2.distance_to(c3) > 2.0:
			bad_pos += 1
			print("   lech vi tri ", tag, " 2D=", c2.round(), " 3D=", c3.round())
		if sp.region_rect != s2.region_rect:
			bad_reg += 1
			print("   sai anh ", tag, " 2D=", s2.region_rect, " 3D=", sp.region_rect)
	## Xoay 90°: World3DView / ActorFrames3D vẫn chạy khi dừng (process_mode của lớp 3D) -> đợi vài khung.
	World3DView.cam_yaw = deg_to_rad(90.0)
	view._update_camera()
	for id in view._dynamic:
		var e: Dictionary = view._dynamic[id]
		if e["kind"] == "missile" and is_instance_valid(e["src"]):
			(e["node"] as ActorFrames3D).refresh((e["src"] as Node2D).global_position, 0.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	view._vp.get_texture().get_image().save_png("user://w3d_mdir_%s_yaw90.png" % tag)
	for id in view._dynamic:
		var e: Dictionary = view._dynamic[id]
		if e["kind"] != "missile" or not is_instance_valid(e["src"]):
			continue
		var m := e["src"] as VltkMissile
		if not m._sprite.is_visible_in_tree():
			continue
		var sp := _first_sprite3d(e["node"])
		var want := m.sprite_region_for_dir(m.dir + 16)   ## camera nhìn từ +X: hướng màn hình lệch +2 nấc 8 hướng
		if sp == null or not want.has_area() or sp.region_rect != want:
			bad_reg += 1
			print("   sai anh khi xoay ", tag, " dir=", m.dir, " muon=", want, " 3D=", sp.region_rect if sp != null else Rect2())
	World3DView.cam_yaw = 0.0
	view._update_camera()
	get_tree().paused = false
	return [bad_pos, bad_reg]

static func _first_sprite3d(n: Node) -> Sprite3D:
	for c in n.get_children():
		if c is Sprite3D and (c as Sprite3D).visible:
			return c
	return null

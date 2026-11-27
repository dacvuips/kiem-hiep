extends SceneTree
## CÔNG CỤ: lấy các frame nhân vật ghép bộ phận VLTK -> BỘ NHÂN VẬT 3D (dùng cho Character3D ở chế độ 3D).
## Xuất vào 1 thư mục:
##   character.json        thông tin bộ hình (giới tính, mã hình, từng động tác: file, cỡ frame, số frame, chân, fps)
##   <động tác>.png        atlas 8 hàng (hướng 0..7, 0 = quay mặt về camera, theo chiều kim đồng hồ) x N cột (frame)
##   turnaround/*.png      ảnh đứng yên 8 hướng phóng to (front/back/left/right + 4 góc chéo) và ảnh ghép
##                         turnaround_sheet.png — đưa vào công cụ tạo model 3D từ ảnh (VD Tripo) nếu muốn có mesh thật.
##
## Chạy (đặt KIEMHIEP_NO_SAVE=1 để không đụng save):
##   godot --headless --path . --script tools/bake_character_3d.gd -- [tuỳ chọn]
## Tuỳ chọn:
##   --gender=male|female   --helm=N --armor=N --weapon=N --horse=N   (mã hình; bỏ trống = mặc định / đi bộ)
##   --actions=stand,run,attack,cast,hurt,die     --out=res://data/avatar3d/<tên>     --scale=4 (phóng ảnh xoay vòng)
## Character3D.load_baked("<out>") để dùng.

const DEFAULT_ACTIONS := "stand,run,attack,cast,hurt,die"
const DIR_NAMES := ["front", "front_left", "left", "back_left", "back", "back_right", "right", "front_right"]

func _initialize() -> void:
	var opt := _parse_args()
	var gender: String = opt.get("gender", "male")
	var look := {}
	for k in ["helm", "armor", "weapon", "horse"]:
		look[k] = int(opt.get(k, "-1"))
	var out: String = opt.get("out", "res://data/avatar3d/%s_%d_%d_%d" % [gender, look["helm"], look["armor"], look["weapon"]])
	var scale := maxi(int(opt.get("scale", "4")), 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join("turnaround")))

	var meta := {"gender": gender, "look": look, "dirs": AvatarBaker.DIRS, "dir_names": DIR_NAMES,
		"pixel_size": Character3D.PX, "actions": {}}
	var t0 := Time.get_ticks_msec()
	for act in str(opt.get("actions", DEFAULT_ACTIONS)).split(",", false):
		var baked := AvatarBaker.bake_action(gender, look, act)
		if baked.is_empty():
			print("  bỏ qua %s: không có hình" % act)
			continue
		var file: String = act + ".png"
		(baked["image"] as Image).save_png(ProjectSettings.globalize_path(out.path_join(file)))
		var fs: Vector2i = baked["frame_size"]
		meta["actions"][act] = {"file": file, "vltk_action": baked["vltk_action"], "frames": baked["frames"],
			"fps": baked["fps"], "frame_size": [fs.x, fs.y], "foot": [baked["foot"].x, baked["foot"].y]}
		print("  %-7s %-14s %2d frame x 8 hướng, khung %dx%d" % [act, baked["vltk_action"], baked["frames"], fs.x, fs.y])
		if act == "stand":
			_write_turnaround(baked, out, scale)
	var f := FileAccess.open(out.path_join("character.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("Xong %d động tác trong %d ms -> %s" % [meta["actions"].size(), Time.get_ticks_msec() - t0,
		ProjectSettings.globalize_path(out)])
	quit(0 if not meta["actions"].is_empty() else 1)

## Ảnh đứng yên 8 hướng, cắt sát hình + phóng to (nearest) — đầu vào cho công cụ tạo model 3D từ ảnh.
func _write_turnaround(baked: Dictionary, out: String, scale: int) -> void:
	var imgs: Array[Image] = []
	var used := Rect2i()
	for d in AvatarBaker.DIRS:
		var img := AvatarBaker.frame_image(baked, d, 0)
		imgs.append(img)
		var r := img.get_used_rect()
		used = r if used.size == Vector2i.ZERO else used.merge(r)
	var cell := used.size * scale
	var sheet := Image.create_empty(cell.x * AvatarBaker.DIRS, cell.y, false, Image.FORMAT_RGBA8)
	for d in AvatarBaker.DIRS:
		var img := imgs[d].get_region(used)
		img.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		img.save_png(ProjectSettings.globalize_path(out.path_join("turnaround/%d_%s.png" % [d, DIR_NAMES[d]])))
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i(d * cell.x, 0))
	sheet.save_png(ProjectSettings.globalize_path(out.path_join("turnaround/turnaround_sheet.png")))
	_write_tripo_views(imgs, used, out)

## Ảnh cho Tripo (Image/Multiview to 3D): 4 góc trước/trái/sau/phải, vuông 1024, nền trắng, phóng mịn (Lanczos).
## Hình gốc chỉ ~44x78 nên model vẫn thô — muốn đẹp hơn thì phóng to bằng AI hoặc vẽ lại ảnh mặt trước rồi mới đưa lên.
const TRIPO_SIZE := 1024
func _write_tripo_views(imgs: Array[Image], used: Rect2i, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join("tripo")))
	var side := maxi(used.size.x, used.size.y)
	var k := float(TRIPO_SIZE) * 0.86 / float(side)
	for spec in [[0, "front"], [2, "left"], [4, "back"], [6, "right"]]:
		var img := imgs[spec[0]].get_region(used)
		var w := roundi(used.size.x * k)
		var h := roundi(used.size.y * k)
		img.resize(used.size.x * 2, used.size.y * 2, Image.INTERPOLATE_NEAREST)  ## giữ nét viền trước khi làm mịn
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
		var canvas := Image.create_empty(TRIPO_SIZE, TRIPO_SIZE, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.WHITE)
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((TRIPO_SIZE - w) / 2, (TRIPO_SIZE - h) / 2))
		canvas.save_png(ProjectSettings.globalize_path(out.path_join("tripo/%s.png" % spec[1])))

func _parse_args() -> Dictionary:
	var opt := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			opt[kv[0]] = kv[1]
	return opt

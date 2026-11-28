extends RefCounted
class_name AvatarBaker
## "Nướng" nhân vật ghép bộ phận VLTK (CharacterAvatar) thành BỘ HÌNH 3D: mỗi động tác 1 ảnh atlas
## 8 hàng (8 hướng, hàng 0 = quay xuống, theo chiều kim đồng hồ như CharacterAvatar.direction) x N cột (frame).
## Ghép hoàn toàn trên CPU bằng Image.blend_rect theo đúng thứ tự vẽ gốc (get_draw_order) nên chạy được cả
## `--headless` (công cụ tools/bake_character_3d.gd) lẫn lúc chơi (Character3D nướng lười từng động tác).
##
## Kết quả 1 động tác (Dictionary):
##   image: Image   frame_size: Vector2i   frames: int (số frame / hướng)   foot: Vector2 (chân, toạ độ trong 1 frame)
##   fps: float     vltk_action: String
## Bóng KHÔNG nướng vào hình: trong 3D bóng là 1 mảng tròn mờ dưới đất (Character3D).

const DIRS := 8

## look = {"helm": int, "armor": int, "weapon": int, "horse": int (-1 = đi bộ)}; trường thiếu -> hình mặc định.
static func bake_action(gender: String, look: Dictionary, game_action: String) -> Dictionary:
	var data := AvatarData.get_for(gender)
	if data.data.is_empty():
		return {}
	var weapon: int = int(look.get("weapon", -1))
	if weapon < 0:
		weapon = data.default_res("weapon")
	var helm: int = int(look.get("helm", -1))
	if helm < 0:
		helm = data.default_res("helm")
	var armor: int = int(look.get("armor", -1))
	if armor < 0:
		armor = data.default_res("armor")
	var horse: int = int(look.get("horse", -1))
	var riding: bool = horse >= 0 and str(data.get_action_set(weapon, true).get(game_action, "")) != ""
	var vltk_action: String = str(data.get_action_set(weapon, riding).get(game_action, ""))
	if vltk_action == "":
		return {}
	var group_res := {"helm": helm, "armor": armor, "weapon": weapon, "horse": horse if riding else -1}

	## Lớp -> file + ảnh. Giống CharacterAvatar._rebuild.
	var layers := {}   ## id -> {"file": Dictionary, "image": Image}
	var frames := 1
	for part in data.data.get("layer_ids", {}):
		var id: int = int(data.data["layer_ids"][part])
		var res := -1
		for group in data.data.get("groups", {}):
			if part in data.data["groups"][group]:
				res = int(group_res.get(group, -1))
		if res < 0:
			continue
		var key := data.get_sprite_key(part, res, vltk_action)
		if key == "":
			continue
		var image := data.get_image(key)
		if image == null:
			continue
		var file := data.get_file(key)
		layers[id] = {"file": file, "image": image}
		if part == "body":
			frames = _dir_frames(file)
	if layers.is_empty():
		return {}
	if frames <= 1:
		for id in layers:
			frames = maxi(frames, _dir_frames(layers[id]["file"]))

	## Khung chung = hộp bao mọi lớp (offset cố định theo file), làm tròn lên số chẵn.
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for id in layers:
		var f: Dictionary = layers[id]["file"]
		var o := Vector2i(int(f["offset"][0]), int(f["offset"][1]))
		lo = Vector2i(mini(lo.x, o.x), mini(lo.y, o.y))
		hi = Vector2i(maxi(hi.x, o.x + int(f["size"][0])), maxi(hi.y, o.y + int(f["size"][1])))
	var size := hi - lo
	size += Vector2i(size.x % 2, size.y % 2)
	var atlas := Image.create_empty(size.x * frames, size.y * DIRS, false, Image.FORMAT_RGBA8)

	for dir in DIRS:
		for frame in frames:
			var order: Array = data.get_draw_order(vltk_action, dir, dir * frames + frame)
			var ids: Array[int] = []
			for raw in order:
				if layers.has(int(raw)) and not ids.has(int(raw)):
					ids.append(int(raw))
			for id in layers:  ## lớp không có trong bảng thứ tự: vẽ sau cùng (như move_child trong CharacterAvatar)
				if not ids.has(int(id)):
					ids.append(int(id))
			var cell := Vector2i(frame * size.x, dir * size.y)
			for id in ids:
				var f: Dictionary = layers[id]["file"]
				var src := _region(f, dir, frame)
				var dst := cell + Vector2i(int(f["offset"][0]), int(f["offset"][1])) - lo
				atlas.blend_rect(layers[id]["image"], src, dst)
	return {
		"image": atlas,
		"frame_size": size,
		"frames": frames,
		"foot": data.anchor - Vector2(lo),
		"fps": data.fps,
		"vltk_action": vltk_action,
	}

## Vùng cắt của 1 lớp ở hướng + frame — bản sao CharacterAvatar._update_region.
static func _region(file: Dictionary, dir: int, frame: int) -> Rect2i:
	var w: int = int(file["size"][0])
	var h: int = int(file["size"][1])
	var per := _dir_frames(file)
	var col := frame % per
	var row := dir % maxi(int(file["dirs"]), 1)
	if _is_packed(file):
		col += (dir % DIRS) * per
		row = 0
	return Rect2i(col * w, row * h, w, h)

## Giống CharacterAvatar._is_packed / _dir_frames: vài .spr gốc ghi "1 hướng" nhưng chứa đủ 8 hướng nối tiếp.
static func _is_packed(file: Dictionary) -> bool:
	var total := int(file["frames_per_dir"])
	return int(file["dirs"]) == 1 and total >= DIRS * 2 and total % DIRS == 0

static func _dir_frames(file: Dictionary) -> int:
	var total := maxi(int(file["frames_per_dir"]), 1)
	return total / DIRS if _is_packed(file) else total

## Cắt 1 frame ra ảnh riêng (dùng cho ảnh xoay vòng gửi công cụ tạo model 3D).
static func frame_image(baked: Dictionary, dir: int, frame: int = 0) -> Image:
	var s: Vector2i = baked["frame_size"]
	return (baked["image"] as Image).get_region(Rect2i(frame * s.x, dir * s.y, s.x, s.y))

## Khoá cache cho 1 bộ dáng.
static func look_key(gender: String, look: Dictionary) -> String:
	return "%s|%d|%d|%d|%d" % [gender, int(look.get("helm", -1)), int(look.get("armor", -1)),
		int(look.get("weapon", -1)), int(look.get("horse", -1))]

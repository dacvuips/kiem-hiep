extends Node3D
class_name ActorFrames3D
## Hình nhân vật / quái / NPC trong chế độ 3D DỰNG TỪ CHÍNH FRAME 2D đang vẽ: đứng, chạy, đánh, ra chiêu, trúng đòn,
## chết... — mỗi khung hình chép frame (ảnh, vùng cắt, vị trí, màu nhuộm) của các lớp 2D sang các tấm Sprite3D dựng
## đứng (billboard trục Y). Không nướng ảnh, không logic riêng: 2D đổi động tác / trang bị / ngựa là 3D đổi theo.
##
## Đọc từ đâu:
##   - Người (CharacterAvatar): 11 lớp bộ phận (bỏ bóng — bóng 3D là mảng tròn dưới đất).
##   - Quái / xác quái (MonsterSprite): lớp thân.
##   - Còn lại (NPC đứng, đạn / hiệu ứng chiêu VLTK, đạn kiểu cũ...): các Sprite2D / AnimatedSprite2D con của node.
##     Lớp vẽ CỘNG SÁNG ở 2D (CanvasItemMaterial BLEND_MODE_ADD — đa số hiệu ứng chiêu) cũng cộng sáng trong 3D.
## XOAY CAMERA: hướng vẽ = hướng nhân vật nhìn TỪ camera (như Character3D) -> người / quái vẽ lại hướng đã bù góc xoay.
## Lớp nhiều tấm chồng nhau: mỗi lớp dịch về phía camera 1 chút theo thứ tự vẽ để không nhấp nháy.

const PX := 0.01
const Z_SCREEN := 0.866
const LAYER_GAP := 0.004       ## m giữa 2 lớp (theo hướng về camera)
const RESCAN := 0.5            ## giây: quét lại Sprite2D con (chỉ nguồn chung)

var src: Node2D
var top := 0.9                 ## m: đỉnh hình cao nhất (đặt tên / thanh máu, vùng bấm chọn)
var width := 0.4               ## m: bề ngang hình
var empty := true              ## không có lớp nào để vẽ (World3DView hiện khối dự phòng)
var show_shadow := true        ## bóng tròn dưới chân (tắt cho đạn / hiệu ứng)
var soft := false              ## true = mọi lớp pha TRONG MỜ thật như 2D (đạn / hiệu ứng); false = cắt alpha cứng (thân)

var _avatar: CharacterAvatar
var _msprite: MonsterSprite
var _proxy: MonsterSprite      ## bản riêng ngoài cây để tính frame hướng khác khi xoay camera
var _generic: Array = []       ## Sprite2D của nguồn chung
var _rescan_t := 0.0
var _pool: Array[Sprite3D] = []
var _shadow: MeshInstance3D

func _init(p_src: Node2D = null) -> void:
	src = p_src
	if src == null:
		return
	var av: Variant = src.get("avatar") if "avatar" in src else null
	if av is CharacterAvatar:
		_avatar = av
	elif src is CharacterAvatar:
		_avatar = src
	else:
		_msprite = _find_monster_sprite(src)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = Character3D._make_shadow_mesh()
	_shadow.position.y = 0.006
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)

static func _find_monster_sprite(n: Node) -> MonsterSprite:
	for c in n.get_children():
		if c is MonsterSprite:
			return c
	return null

func _exit_tree() -> void:
	if _proxy != null:
		_proxy.free()
		_proxy = null

## Gọi mỗi khung hình (World3DView). `ground` = toạ độ 2D chân nhân vật (VltkMath.ground_of).
func refresh(ground: Vector2, delta: float) -> void:
	if src == null or not is_instance_valid(src):
		return
	var shift := _camera_shift()
	var items: Array = []
	var own_shadow := false
	if _avatar != null and is_instance_valid(_avatar):
		own_shadow = _collect_shadow(items)
		_collect_avatar(items, shift)
		_collect_states(items)
	elif _msprite != null and is_instance_valid(_msprite):
		own_shadow = _collect_shadow(items)
		_collect_monster(items, shift)
		_collect_states(items)
	else:
		_rescan_t -= delta
		if _rescan_t <= 0.0:
			_rescan_t = RESCAN
			_generic.clear()
			_scan_generic(src, 0)
		for s in _generic:
			if not is_instance_valid(s) or not (s as CanvasItem).is_visible_in_tree():
				continue
			if s is Sprite2D:
				var region := (s as Sprite2D).region_rect
				## Đạn / hiệu ứng chiêu VLTK có nhiều hướng ảnh: xoay camera -> lấy ảnh hướng đã bù góc (như người / quái).
				var shift64 := roundi(shift * 8.0)
				if shift64 != 0 and s.get_parent() == src and src.has_method("sprite_region_for_dir"):
					var r: Rect2 = src.sprite_region_for_dir(int(src.get_dir64()) + shift64)
					if r.has_area():
						region = r
				_add_sprite(items, s, (s as Sprite2D).texture, region, (s as Sprite2D).global_transform)
			else:
				var a := s as AnimatedSprite2D
				var tex: Texture2D = a.sprite_frames.get_frame_texture(a.animation, a.frame) if a.sprite_frames != null \
					and a.sprite_frames.has_animation(a.animation) else null
				if tex != null:
					_add_sprite(items, a, tex, Rect2(Vector2.ZERO, tex.get_size()), a.global_transform)
	_apply(items, ground)
	if _shadow != null and own_shadow:
		_shadow.visible = false   ## đã có bóng gốc 2D -> bỏ vệt tròn dự phòng

## ---------- hướng camera ----------

## Số "nấc 8 hướng" (có lẻ) cần cộng vào hướng 2D để ra hướng nhìn từ camera. Camera không xoay = 0.
func _camera_shift() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return 0.0
	var right := cam.global_basis.x
	var toward := cam.global_basis.z
	right.y = 0.0
	toward.y = 0.0
	if right.length_squared() < 0.0001 or toward.length_squared() < 0.0001:
		return 0.0
	## Hướng 2D số 0 = quay xuống = +Z thế giới -> nhìn từ camera thành góc nào.
	var f := Vector3(0, 0, 1)
	var rel := Vector2(f.dot(right.normalized()), f.dot(toward.normalized()))
	return wrapf((rad_to_deg(rel.angle()) - 90.0) / 45.0, -4.0, 4.0)

## ---------- thu thập lớp ----------

## BÓNG DƯỚI CHÂN y như 2D, NẰM PHẲNG trên đất (lớp đầu tiên = dưới cùng):
##   - Người: sprite bóng gốc của động tác (CharacterAvatar._shadow — cùng frame / hướng với thân, không nâng khi nhảy).
##   - Quái: sprite bóng gốc (MonsterSprite._shadow, file cùng tên thêm "b"); bộ hình không có bóng gốc thì ELIP mờ
##     đúng cỡ / màu của 2D (MonsterSprite._draw: bán kính rx, dẹt 0,4, đen alpha 0,32).
## Bóng giữ hướng của thế giới 2D (không bù góc camera) vì nó là hình in trên mặt đất. true = đã có bóng.
const FALLBACK_SHADOW := MonsterSprite.FALLBACK_SHADOW_COLOR
static var _ellipse_tex: ImageTexture
func _collect_shadow(items: Array) -> bool:
	var sh: Sprite2D = null
	if _avatar != null:
		sh = _avatar._shadow
	elif _msprite != null:
		sh = _msprite._shadow
	if sh != null and sh.visible and sh.texture != null and sh.is_visible_in_tree():
		_add_sprite(items, sh, sh.texture, sh.region_rect, sh.global_transform)
		items[-1]["ground"] = true
		items[-1]["soft"] = true
		return true
	if _msprite != null and _msprite._fallback_rx > 0.0 and _msprite.is_visible_in_tree():
		if _ellipse_tex == null:
			var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			for y in 64:
				for x in 64:
					var d := Vector2((x + 0.5) / 32.0 - 1.0, (y + 0.5) / 32.0 - 1.0).length()
					img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d <= 1.0 else 0.0))
			_ellipse_tex = ImageTexture.create_from_image(img)
		var rx := _msprite._fallback_rx
		var gs := _msprite.global_transform.get_scale()
		var c := FALLBACK_SHADOW * _msprite.modulate
		var p := _msprite.get_parent()
		while p != null and p != src.get_parent() and p is CanvasItem:
			c *= (p as CanvasItem).modulate
			p = p.get_parent()
		items.append({"tex": _ellipse_tex, "region": Rect2(0, 0, 64, 64),
			"tl": _msprite.global_position - Vector2(rx, rx * 0.4) * gs, "size": Vector2(64, 64),
			"scale": Vector2(rx * 2.0 / 64.0, rx * 0.8 / 64.0) * gs.abs(), "flip": false, "color": c,
			"add": false, "soft": true, "ground": true})
		return true
	return false

func _collect_avatar(items: Array, shift: float) -> void:
	var av := _avatar
	var d := wrapi(av.direction + roundi(shift), 0, 8)
	var frame := maxi(av._frame, 0)
	var ids: Array = []
	if d == av.direction:
		## Đúng thứ tự node trong 2D (đã sắp theo bảng thứ tự vẽ gốc).
		for c in av._body.get_children():
			for id in av._layers:
				if av._layers[id] == c:
					ids.append(id)
	else:
		var fpd := maxi(av._frames_per_dir, 1)
		for raw in av._data.get_draw_order(av._vltk_action, d, d * fpd + frame):
			if av._layers.has(int(raw)) and not ids.has(int(raw)):
				ids.append(int(raw))
		for id in av._layers:
			if not ids.has(id):
				ids.append(id)
	for id in ids:
		var s: Sprite2D = av._layers[id]
		if not s.visible or s.texture == null:
			continue
		var region := s.region_rect
		var file: Dictionary = av._layer_file.get(id, {})
		if d != av.direction and not file.is_empty():
			region = Rect2(AvatarBaker._region(file, d, frame))
		_add_sprite(items, s, s.texture, region, s.global_transform)

func _collect_monster(items: Array, shift: float) -> void:
	var ms := _msprite
	var s: Sprite2D = ms._sprite
	if s == null or not s.visible or s.texture == null:
		return
	var shift64 := roundi(shift * 8.0)
	if shift64 == 0 or ms.pose_action == "":
		_add_sprite(items, s, s.texture, s.region_rect, s.global_transform)
		return
	if _proxy == null:
		_proxy = MonsterSprite.new()
	if _proxy.res_name != ms.res_name:
		_proxy.set_resource(ms.res_name)
	if not _proxy.set_pose(ms.pose_action, wrapi(ms.pose_dir64 + shift64, 0, VltkMath.MAX_DIR), ms.pose_progress):
		_add_sprite(items, s, s.texture, s.region_rect, s.global_transform)
		return
	var ps: Sprite2D = _proxy._sprite
	## Vị trí lớp của bản riêng tính theo node MonsterSprite thật (cùng chỗ, cùng cỡ).
	_add_sprite(items, s, ps.texture, ps.region_rect, ms.global_transform * ps.transform)

## Hình TRẠNG THÁI gắn trên người (buff / bùa / hào quang — VltkStateSprite, node con của nhân vật / quái): vẽ sau người
## (z_index < 0: vòng dưới chân, khoảng frame "nền") thì xếp TRƯỚC các lớp thân, còn lại xếp sau (đè lên người).
func _collect_states(items: Array) -> void:
	for c in src.get_children():
		if not (c is VltkStateSprite) or not (c as Node2D).is_visible_in_tree():
			continue
		var sp: Sprite2D = (c as VltkStateSprite)._sprite
		if sp == null or not sp.visible or sp.texture == null:
			continue
		var tmp: Array = []
		_add_sprite(tmp, sp, sp.texture, sp.region_rect, sp.global_transform)
		if tmp.is_empty():
			continue
		tmp[0]["soft"] = true   ## hào quang / vòng lửa: viền mờ dần như 2D, không cắt cứng
		## Trạng thái loại "Foot" (vòng dưới chân) là hình VẼ TRÊN MẶT ĐẤT: nằm phẳng CẢ VÒNG (không tách đứng / nằm)
		## -> xoay camera vòng vẫn liền; nửa sau bị thân người đứng che như 2D.
		tmp[0]["ground"] = str((c as VltkStateSprite)._state.get("type", "")) == "Foot"
		if (c as Node2D).z_index < 0:
			items.insert(0, tmp[0])
		else:
			items.append(tmp[0])

func _scan_generic(n: Node, depth: int) -> void:
	for c in n.get_children():
		if (c is Sprite2D or c is AnimatedSprite2D) and not (c as Node2D).top_level \
				and not String(c.name).to_lower().contains("shadow"):
			_generic.append(c)
		if depth < 2 and c is Node2D and not c is CanvasLayer:
			_scan_generic(c, depth + 1)

## 1 lớp: góc trên-trái + cỡ (px thế giới 2D) + màu nhuộm gộp từ nguồn tới lớp + cộng sáng hay không.
## `s` = Sprite2D (region như 2D) hoặc AnimatedSprite2D (cả ảnh của frame đang hiện).
func _add_sprite(items: Array, s: Node2D, tex: Texture2D, region: Rect2, xf: Transform2D) -> void:
	if tex == null:
		return
	var use_region: bool = s is Sprite2D and (s as Sprite2D).region_enabled
	var size := region.size if use_region else tex.get_size()
	var offset: Vector2 = s.get("offset")
	var local_pos := offset - (size * 0.5 if bool(s.get("centered")) else Vector2.ZERO)
	var sc := xf.get_scale()
	var c := s.self_modulate * s.modulate
	var p := s.get_parent()
	while p != null and p != src.get_parent() and p is CanvasItem:
		c *= (p as CanvasItem).modulate
		p = p.get_parent()
	var add := false
	var m := s.material as CanvasItemMaterial
	if m != null and m.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
		add = true
	items.append({"tex": tex, "region": region if use_region else Rect2(Vector2.ZERO, size),
		"tl": xf * local_pos, "size": size, "scale": Vector2(absf(sc.x), absf(sc.y)),
		"flip": bool(s.get("flip_h")) != (sc.x < 0.0), "color": c, "add": add})

## ---------- dựng 3D ----------

## Mỗi lớp TÁCH Ở ĐƯỜNG CHÂN (như tấm nhà / tường): phần ảnh trên điểm chân = tấm ĐỨNG (billboard trục Y); phần dưới
## điểm chân (vòng lửa / hào quang dưới chân, vòng nổ, bóng vẽ sẵn...) = tấm NẰM PHẲNG trên mặt đất. Camera chiếu thẳng
## nghiêng 30°: 1 px màn hình = PX/0,866 cao (tấm đứng) = 2·PX sâu (tấm nằm) -> góc mặc định thấy y hệt 2D, không bị
## mặt đất cắt ngang, ai đứng trước vẫn đè lên vòng dưới chân như 2D; xoay camera thì vòng nằm trên đất thật.
func _apply(items: Array, ground: Vector2) -> void:
	empty = items.is_empty()
	if _shadow != null:
		_shadow.visible = show_shadow and not empty
	while _pool.size() < items.size():
		_pool.append(_new_sprite(false))
		_flat.append(_new_sprite(true))
	## Hướng ngang về phía camera: lớp sau trong thứ tự vẽ nhích lên trước 1 chút (không nhấp nháy khi chồng nhau).
	var toward := Vector3.ZERO
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		toward = cam.global_basis.z
		toward.y = 0.0
		toward = toward.normalized() if toward.length_squared() > 0.0001 else Vector3.ZERO
	var hi := 0.0
	var lo_x := INF
	var hi_x := -INF
	for i in _pool.size():
		var sp := _pool[i]
		var fl := _flat[i]
		sp.visible = false
		fl.visible = false
		if i >= items.size():
			continue
		var it: Dictionary = items[i]
		var sc: Vector2 = it["scale"]
		if sc.x < 0.0001 or sc.y < 0.0001:
			continue
		var tl: Vector2 = Vector2(it["tl"]) - ground
		var size: Vector2 = it["size"]
		var region: Rect2 = it["region"]
		var bottom := tl.y + size.y * sc.y          ## mép dưới ảnh (px màn hình, dương = dưới điểm chân)
		## Số hàng ảnh nằm TRÊN điểm chân (phần đứng); còn lại nằm phẳng.
		var rows_up := clampf(-tl.y / sc.y, 0.0, region.size.y)
		if it.get("ground", false):
			rows_up = 0.0
		elif bottom <= 0.0 or soft:
			## Đạn / hiệu ứng chiêu (soft): KHÔNG tách — đạn đang bay trên không; cả tấm đứng và vẽ đè mọi thứ như 2D
			## (2D đặt z_index = 1 cho đạn / hiệu ứng: luôn trên người, nhà, cây).
			rows_up = region.size.y
		var col: Color = it["color"]
		var add: bool = it.get("add", false)
		## Thân người / quái: cắt alpha cứng (ghi chiều sâu -> che khuất đúng). Hình trạng thái, đạn, hiệu ứng, đang mờ:
		## pha trong mờ thật (viền mềm, nhìn xuyên thấy quái / tên phía sau như 2D).
		var blend: bool = add or soft or it.get("soft", false) or col.a <= 0.99
		if rows_up >= 0.5:
			_setup_layer(sp, it, Rect2(region.position, Vector2(region.size.x, rows_up)), add, blend, false)
			## Gốc Sprite3D (centered = false) ở góc DƯỚI-trái, trục y lên; đáy phần đứng = min(mép dưới, điểm chân).
			sp.scale = Vector3(sc.x * Z_SCREEN, sc.y, 1.0)
			sp.offset = Vector2(tl.x / sc.x, -(minf(bottom, 0.0) if not soft else bottom) / sc.y)
			sp.no_depth_test = soft
			sp.position = toward * (LAYER_GAP * i)
			sp.visible = true
		var rows_down := region.size.y - rows_up
		if rows_down >= 0.5:
			_setup_layer(fl, it, Rect2(region.position + Vector2(0, rows_up), Vector2(region.size.x, rows_down)), add, blend, true)
			## Tấm nằm (xoay -90° quanh X: trục y của ảnh = hướng -Z, ra xa camera): hàng trên cùng của phần nằm ở đúng
			## độ sâu của nó trên màn hình (điểm chân khi tách; mép trên ảnh khi cả ảnh nằm / cả ảnh ở dưới chân).
			fl.scale = Vector3(sc.x, sc.y * 2.0, 1.0)
			fl.offset = Vector2(tl.x / sc.x, -(tl.y + rows_up * sc.y) / sc.y - rows_down)
			fl.position = Vector3(0.0, 0.004 + 0.0015 * i, 0.0)
			fl.visible = true
		hi = maxf(hi, -tl.y * PX / Z_SCREEN)
		lo_x = minf(lo_x, tl.x * PX)
		hi_x = maxf(hi_x, (tl.x + size.x * sc.x) * PX)
	if not empty:
		top = clampf(hi, 0.2, 6.0)
		width = clampf(hi_x - lo_x, 0.2, 4.0)
		if _shadow != null:
			_shadow.scale = Vector3.ONE * clampf(width / 0.6, 0.6, 3.0)

var _flat: Array[Sprite3D] = []

func _new_sprite(flat: bool) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.centered = false
	sp.region_enabled = true
	sp.shaded = false
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.visible = false
	if flat:
		sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sp.rotation_degrees.x = -90.0
		sp.pixel_size = PX
	else:
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = PX / Z_SCREEN
	add_child(sp)
	return sp

func _setup_layer(sp: Sprite3D, it: Dictionary, region: Rect2, add: bool, blend: bool, flat: bool) -> void:
	if sp.texture != it["tex"]:
		sp.texture = it["tex"]
	sp.region_rect = region
	sp.flip_h = it["flip"]
	sp.modulate = it["color"]
	if add:
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sp.material_override = _add_material(it["tex"], flat)
	else:
		sp.material_override = null
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if blend else SpriteBase3D.ALPHA_CUT_DISCARD

## Vật liệu CỘNG SÁNG cho 1 ảnh (dùng chung theo ảnh): Sprite3D vẫn tự dựng lưới + uv theo vùng cắt, vật liệu này
## thay vật liệu riêng của nó -> phải tự quay mặt về camera (billboard trục Y) và lấy màu nhuộm từ màu đỉnh.
static var _add_mats := {}
static func _add_material(tex: Texture2D, flat: bool = false) -> StandardMaterial3D:
	var key := "%d_%s" % [tex.get_rid().get_id(), flat]
	if not _add_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		if not flat:   ## tấm nằm phẳng trên đất thì không quay theo camera
			m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			m.billboard_keep_scale = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		## Ánh sáng chiêu vẽ ĐÈ như 2D (không bị mái / tường / người cắt mất).
		m.no_depth_test = true
		_add_mats[key] = m
	return _add_mats[key]

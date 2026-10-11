extends Node2D
class_name MonsterSprite
## Vẽ 1 quái VLTK: Sprite2D cắt vùng (region) từ sheet PNG của động tác hiện tại + BÓNG dưới chân. Gốc node = CHÂN quái.
## Bóng: dùng sprite bóng gốc của động tác (KNpcResNode::GetShadowName — file cùng tên thêm "b") vẽ cùng frame/hướng;
## bộ hình nào không có bóng gốc thì vẽ elip mờ dưới chân.
## Không tự chạy thời gian — người dùng (VltkMonster / bản xem trước) gọi set_pose(động tác, hướng, tiến độ 0..1).

const FALLBACK_SHADOW_COLOR := Color(0, 0, 0, 0.32)
## true = vẽ bóng dưới chân quái (bóng gốc của động tác, thiếu thì elip mờ); false = ẩn hẳn.
const SHOW_SHADOW := true

var res_name: String = ""

var _shadow: Sprite2D
var _sprite: Sprite2D
var _shown_key: String = ""
var _shown_frame: int = -1
var _fallback_rx: float = 0.0   ## > 0 = đang vẽ bóng elip thay cho bóng gốc

func _ready() -> void:
	_ensure_sprites()

func _ensure_sprites() -> void:
	if _sprite != null:
		return
	_shadow = _make_sprite()
	_sprite = _make_sprite()

func _make_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.region_enabled = true
	add_child(s)
	return s

func set_resource(res: String) -> void:
	res_name = res
	_shown_key = ""
	_shown_frame = -1

## Elip bóng dự phòng — vẽ trước (dưới) các sprite con.
func _draw() -> void:
	if _fallback_rx <= 0.0:
		return
	var points := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		points.append(Vector2(cos(a) * _fallback_rx, sin(a) * _fallback_rx * 0.4))
	draw_colored_polygon(points, FALLBACK_SHADOW_COLOR)

## action: stand/walk/run/hurt/die/attack1/attack2/magic · dir64: hướng 0..63 (0 = xuống, 16 = trái, 48 = phải) ·
## progress: 0..1 trong 1 vòng động tác. Trả về false nếu bộ này không có hình cho động tác.
func set_pose(action_name: String, dir64: int, progress: float) -> bool:
	_ensure_sprites()
	var act := MonsterData.action(res_name, action_name)
	if act.is_empty():
		_sprite.visible = false
		_shadow.visible = false
		return false
	var anim := MonsterData.anim(str(act["anim"]))
	if anim.is_empty():
		_sprite.visible = false
		_shadow.visible = false
		return false
	var dirs := maxi(1, int(act["dirs"]))
	var frames := maxi(1, int(act["frames"]))
	var per_dir := maxi(1, frames / dirs)
	var image_dir := VltkMath.image_dir(dir64, dirs)
	var frame := clampi(int(per_dir * clampf(progress, 0.0, 0.9999)), 0, per_dir - 1) + image_dir * per_dir
	var key := str(act["anim"])
	if key == _shown_key and frame == _shown_frame:
		return true
	_shown_key = key
	_shown_frame = frame
	_apply_region(_sprite, key, frame)
	## Bóng gốc cùng frame/hướng; thiếu thì elip mờ theo bề rộng thân.
	var shadow_key := str(act.get("shadow", ""))
	if not SHOW_SHADOW:
		_shadow.visible = false
		if _fallback_rx > 0.0:
			_fallback_rx = 0.0
			queue_redraw()
	elif shadow_key != "" and not MonsterData.anim(shadow_key).is_empty():
		_apply_region(_shadow, shadow_key, frame)
		if _fallback_rx > 0.0:
			_fallback_rx = 0.0
			queue_redraw()
	else:
		_shadow.visible = false
		var rx := clampf(float(anim["size"][0]) * 0.28, 12.0, 70.0)
		if not is_equal_approx(rx, _fallback_rx):
			_fallback_rx = rx
			queue_redraw()
	return true

func _apply_region(sprite: Sprite2D, key: String, frame: int) -> void:
	var anim := MonsterData.anim(key)
	if anim.is_empty() or frame >= int(anim["frames"]):
		sprite.visible = false
		return
	sprite.texture = MonsterData.texture(key)
	var size: Array = anim["size"]
	var offset: Array = anim["offset"]
	var cols := int(anim["cols"])
	sprite.region_rect = Rect2((frame % cols) * size[0], (frame / cols) * size[1], size[0], size[1])
	sprite.position = Vector2(offset[0], offset[1])
	sprite.visible = sprite.texture != null

## Chiều cao ảnh phía trên chân (pixel, dương) — để đặt thanh máu trên đầu. 0 nếu chưa có hình.
func get_height() -> float:
	var act := MonsterData.action(res_name, "stand")
	var anim := MonsterData.anim(str(act.get("anim", "")))
	if anim.is_empty():
		return 60.0
	return maxf(30.0, -float(anim["offset"][1]))

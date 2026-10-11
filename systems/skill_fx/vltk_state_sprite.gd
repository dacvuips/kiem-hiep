extends Node2D
class_name VltkStateSprite
## Phép chia nguyên trong file này là CỐ Ý — chép đúng số học số nguyên của bản gốc C++ (g_DirCos, ô logic 32...).
@warning_ignore_start("integer_division")
## Hình ảnh TRẠNG THÁI gắn lên người suốt lúc buff/bùa/hào quang còn hiệu lực (KNpcRes::m_cStateSpr gốc, bảng
## "状态图形对照表" -> data/skill_fx/states.json do tools/import_vltk_skill_fx.py xuất). Skill chỉ cần có StateSpecialId.
##   Foot: vẽ dưới chân (sau nhân vật) · Head/Body: vẽ trước nhân vật; Body có khoảng frame "nền" (back_start..back_end)
##   thì ở khoảng đó vẽ SAU nhân vật. Lặp liên tục (Loop) hoặc chạy 1 lần.
## Node tự bám theo `target`, đặt ở chân nhân vật (cùng toạ độ VltkEffect), không dùng ObjectPool vì tồn tại lâu và hiếm.

const Z_BEHIND := -1
const Z_FRONT := 2
## Hệ số tăng tốc hoạt ảnh trạng thái (skill hỗ trợ) — gốc chạy chậm, nhìn không rõ.
const ANIM_SPEED := 0.7   ## hệ số so với nhịp gốc (1.0 = đúng gốc); đã chỉnh 1.8 -> 0.36 -> 0.7

var state_id: int = 0
var target: Node2D = null

var _state: Dictionary = {}
var _anim: Dictionary = {}
var _sprite: Sprite2D
var _ticks: float = 0.0   ## số nhịp (18/giây) đã trôi, đã nhân ANIM_SPEED

## Tạo + gắn vào `target`. null nếu trạng thái này chưa có hình trong dữ liệu.
static func attach(target_node: Node2D, id: int) -> VltkStateSprite:
	var state := VltkSkillData.state(id)
	if state.is_empty() or target_node == null:
		return null
	var anim := VltkSkillData.anim(str(state.get("anim", "")))
	if anim.is_empty():
		return null
	var node := VltkStateSprite.new()
	node.state_id = id
	node.target = target_node
	node._state = state
	node._anim = anim
	node.top_level = true            ## không thừa kế toạ độ của người mang — tự đặt theo chân
	node.z_as_relative = false
	target_node.add_child(node)
	return node

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.texture = VltkSkillData.texture(str(_state.get("anim", "")))
	add_child(_sprite)
	_update()

func _process(delta: float) -> void:
	_ticks += delta * VltkMath.FPS * ANIM_SPEED
	_update()

func _update() -> void:
	if target == null or not is_instance_valid(target) or _sprite.texture == null:
		return
	var frames := maxi(1, int(_state.get("frames", 1)))
	var dirs := maxi(1, int(_state.get("dirs", 1)))
	var per_dir := maxi(1, frames / dirs)
	## Cột "nhịp" của bảng trạng thái = ĐỘ DÀI CẢ VÒNG hoạt ảnh tính bằng nhịp (KSprControl::GetNextFrame gốc:
	## frame = frame_mỗi_hướng × thời_gian_đã_trôi / nhịp), không phải thời gian mỗi frame.
	var cycle := float(maxi(1, int(_state.get("interval", 1))))
	if not bool(_state.get("loop", true)) and _ticks >= cycle:
		_sprite.visible = false
		return
	var frame_in_dir := clampi(int(float(per_dir) * fmod(_ticks, cycle) / cycle), 0, per_dir - 1)
	## Hướng ảnh theo hướng nhân vật (đa số trạng thái chỉ có 1 hướng).
	var image_dir := 0
	if dirs > 1 and "avatar" in target and target.avatar:
		image_dir = VltkMath.image_dir((dirs * (int(target.avatar.direction) * VltkMath.MAX_DIR / 8)) >> 6, dirs)
	var frame := frame_in_dir + image_dir * per_dir
	var anim_frames := int(_anim.get("frames", 1))
	if frame >= anim_frames:
		_sprite.visible = false
		return
	var size: Array = _anim["size"]
	var offset: Array = _anim["offset"]
	var cols := int(_anim.get("cols", 1))
	_sprite.visible = true
	_sprite.region_rect = Rect2((frame % cols) * size[0], (frame / cols) * size[1], size[0], size[1])
	_sprite.position = Vector2(offset[0], offset[1])
	global_position = VltkMath.to_world(VltkMath.logic_of(target) + Vector2(0, 1))
	z_index = _layer(frame_in_dir)

func _layer(frame_in_dir: int) -> int:
	match str(_state.get("type", "Body")):
		"Foot":
			return Z_BEHIND
		"Body":
			var back_start := int(_state.get("back_start", 0))
			var back_end := int(_state.get("back_end", 0))
			if back_end > back_start and frame_in_dir >= back_start and frame_in_dir < back_end:
				return Z_BEHIND
	return Z_FRONT

@warning_ignore_restore("integer_division")

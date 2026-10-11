extends Node2D
class_name VltkEffect
## Phép chia nguyên trong file này là CỐ Ý — chép đúng số học số nguyên của bản gốc C++ (g_DirCos, ô logic 32...).
@warning_ignore_start("integer_division")
## Hiệu ứng 1 lần của đạn VLTK (KSkillSpecial gốc): ảnh chờ khi sinh đạn, nổ/biến mất, trúng đòn trên người mục tiêu.
## Chạy hết số frame của 1 hướng rồi tự trả về ObjectPool. Bám theo nhân vật nếu có `follow`.

const SCENE := preload("res://systems/skill_fx/VltkEffect.tscn")
## Đè lên nhân vật/đạn cùng hàng y (gốc vẽ hiệu ứng sau nhân vật).
const DRAW_Z := 1

var end_tick := 0          ## số nhịp (18/giây) — ngoài dùng để biết hiệu ứng đã hết chưa (SpecialMovieIsAllEnd)
var follow: Node2D = null
var _speed_scale: float = 1.0   ## > 1 = hoạt ảnh chạy nhanh hơn (skill hỗ trợ)

var _anim: Dictionary = {}
var _interval := 1
var _image_dir := 0
var _frames_per_dir := 1
var _tick := 0
var _acc := 0.0
var _logic := Vector2.ZERO
var _z := 0.0

@onready var _sprite: Sprite2D = $Sprite

## phase = {anim, frames, dirs, interval} (Missles.txt AnimFileN + AnimFileInfoN). null nếu giai đoạn đó không có ảnh.
static func spawn(parent: Node, phase: Variant, logic_pos: Vector2, z: float, dir_index: int, follow_node: Node2D = null, speed: float = 1.0) -> VltkEffect:
	if not (phase is Dictionary) or parent == null:
		return null
	var anim := VltkSkillData.anim(str(phase.get("anim", "")))
	if anim.is_empty():
		return null
	var e: VltkEffect = ObjectPool.acquire(SCENE, parent)
	e._speed_scale = speed
	e._setup(phase, anim, logic_pos, z, dir_index, follow_node)
	return e

func _setup(phase: Dictionary, anim: Dictionary, logic_pos: Vector2, z: float, dir_index: int, follow_node: Node2D) -> void:
	_anim = anim
	var dirs := maxi(1, int(phase.get("dirs", 1)))
	var frames := maxi(1, int(phase.get("frames", 1)))
	_interval = maxi(1, int(phase.get("interval", 1)))
	_frames_per_dir = maxi(1, frames / dirs)
	## Nguyên văn gốc: m_nCurDir = g_DirIndex2Dir(chỉ số hướng 64, số hướng ảnh), rồi Draw lại chia như hướng 64.
	_image_dir = VltkMath.image_dir((dirs * dir_index) >> 6, dirs)
	end_tick = _interval * frames / dirs
	_tick = 0
	_acc = 0.0
	_logic = logic_pos
	_z = z
	follow = follow_node
	z_index = DRAW_Z
	_sprite.texture = VltkSkillData.texture(str(phase.get("anim", "")))
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.visible = true
	_update()

func is_finished() -> bool:
	return _tick > end_tick

func _process(delta: float) -> void:
	_acc += delta * _speed_scale
	while _acc >= VltkMath.TICK:
		_acc -= VltkMath.TICK
		_tick += 1
	if _tick > end_tick:
		ObjectPool.release(self)
		return
	_update()

func _update() -> void:
	if follow != null and is_instance_valid(follow) and follow.is_inside_tree():
		_logic = VltkMath.logic_of(follow) + Vector2(0, 1)
		_z = 0.0
	global_position = VltkMath.to_world(_logic)
	var frame := _tick / _interval + _image_dir * _frames_per_dir
	var total := int(_anim.get("frames", 1))
	if frame >= total or _sprite.texture == null:
		_sprite.visible = false
		return
	var size: Array = _anim["size"]
	var offset: Array = _anim["offset"]
	var cols := int(_anim.get("cols", 1))
	_sprite.visible = true
	_sprite.region_rect = Rect2((frame % cols) * size[0], (frame / cols) * size[1], size[0], size[1])
	_sprite.position = Vector2(offset[0], offset[1] - _z * VltkMath.Z_SCREEN)

func _on_pool_release() -> void:
	follow = null

@warning_ignore_restore("integer_division")

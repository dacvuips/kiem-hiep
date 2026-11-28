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
const Z_FRONT := 1
## Tốc độ hoạt ảnh trạng thái: 1.0 = đúng chuẩn 100% nhịp 18 FPS gốc VLTK
const ANIM_SPEED := 1.0

var state_id: int = 0
var target: Node2D = null

var _state: Dictionary = {}
var _anim: Dictionary = {}
var _sprite: Sprite2D
var _ticks: float = 0.0   ## số nhịp (18/giây) đã trôi, đã nhân ANIM_SPEED
var _is_finishing: bool = false
const MIN_CYCLE_TICKS: float = 20.0

func finish_and_free() -> void:
	if _ticks >= MIN_CYCLE_TICKS:
		queue_free()
	else:
		_is_finishing = true

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
	node.top_level = false
	node.z_as_relative = true
	if str(state.get("type", "")) == "Head":
		node.z_index = 15
	target_node.add_child(node)
	return node

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.region_enabled = true
	if _anim.get("additive", false):
		_sprite.material = VltkEffect.get_add_material()
	_sprite.texture = VltkSkillData.texture(str(_state.get("anim", "")))
	add_child(_sprite)
	_update()

func _process(delta: float) -> void:
	_ticks += delta * VltkMath.FPS * ANIM_SPEED
	_update()

func _update() -> void:
	if _is_finishing and _ticks >= MIN_CYCLE_TICKS:
		queue_free()
		return
	if target == null or not is_instance_valid(target) or _sprite == null:
		return

	var anim_key: String = str(_state.get("anim", ""))
	var anim_data: Dictionary = _anim
	var is_attacking: bool = false
	if _state.has("attack_anim") and "avatar" in target and target.avatar != null:
		var act: String = str(target.avatar.action)
		if act in ["attack", "attack1", "attack2", "cast"]:
			var atk_key: String = str(_state.get("attack_anim", ""))
			var atk_dict := VltkSkillData.anim(atk_key)
			if not atk_dict.is_empty():
				anim_key = atk_key
				anim_data = atk_dict
				is_attacking = true

	var tex := VltkSkillData.texture(anim_key)
	if _sprite.texture != tex:
		_sprite.texture = tex
	if _sprite.texture == null:
		return

	if anim_data.get("additive", false):
		if _sprite.material == null:
			_sprite.material = VltkEffect.get_add_material()
	elif _sprite.material != null:
		_sprite.material = null

	var frames := maxi(1, int(_state.get("frames", 1)))
	var dirs := maxi(1, int(_state.get("dirs", 1)))
	var per_dir := maxi(1, frames / dirs)
	## Cột "nhịp" của bảng trạng thái = ĐỘ DÀI CẢ VÒNG hoạt ảnh tính bằng nhịp (KSprControl::GetNextFrame gốc:
	## frame = frame_mỗi_hướng × thời_gian_đã_trôi / nhịp), không phải thời gian mỗi frame.
	var cycle := float(maxi(1, int(_state.get("interval", 1))))
	if _state.get("loop", true) != true and _ticks >= cycle:
		_sprite.visible = false
		return

	var frame_in_dir: int = 0
	if is_attacking and "avatar" in target and target.avatar != null and "_frames_per_dir" in target.avatar and int(target.avatar._frames_per_dir) > 0:
		var cur_f: int = int(target.avatar.get("_frame")) if "_frame" in target.avatar else 0
		var max_f: int = maxi(1, int(target.avatar._frames_per_dir))
		frame_in_dir = clampi(int(float(per_dir) * float(cur_f) / float(max_f)), 0, per_dir - 1)
	else:
		frame_in_dir = clampi(int(float(per_dir) * fmod(_ticks, cycle) / cycle), 0, per_dir - 1)

	## Hướng ảnh theo hướng nhân vật (đa số trạng thái chỉ có 1 hướng).
	var image_dir := 0
	if dirs > 1 and "avatar" in target and target.avatar:
		image_dir = VltkMath.image_dir((dirs * (int(target.avatar.direction) * VltkMath.MAX_DIR / 8)) >> 6, dirs)
	var frame := frame_in_dir + image_dir * per_dir
	var anim_frames := int(anim_data.get("frames", 1))
	if frame >= anim_frames:
		_sprite.visible = false
		return
	var size: Array = anim_data["size"]
	var offset: Array = anim_data["offset"]
	var cols := int(anim_data.get("cols", 1))
	_sprite.visible = true
	_sprite.region_rect = Rect2((frame % cols) * size[0], (frame / cols) * size[1], size[0], size[1])
	var is_head: bool = str(_state.get("type", "")) == "Head"
	if is_head:
		# Hiệu ứng trên đầu: căn giữa theo kích thước sprite, không cộng dồn offset Y gốc (vốn tính từ chân lên đầu)
		_sprite.position = Vector2(roundf(-size[0] * 0.5), roundf(-size[1] * 0.5) - 4.0)
		var np: Node2D = target.get("_name_plate")
		if np == null:
			np = target.get("name_plate")
		if np != null and is_instance_valid(np):
			position = np.position + Vector2(0, -6.0)
		elif target.get("_name_label") != null and is_instance_valid(target.get("_name_label")):
			var nl: Control = target.get("_name_label")
			position = Vector2(0, nl.position.y)
		elif target.get("_sprite") != null and target.get("_sprite").has_method("get_height"):
			var h: float = target.get("_sprite").get_height()
			var s: float = target.get("scale_factor") if target.get("scale_factor") != null else 1.0
			position = Vector2(0, -h * s - 25.0)
		elif "avatar" in target and target.avatar != null:
			var av_h: float = target.avatar.get_height() if target.avatar.has_method("get_height") else 95.0
			var ride_off: float = 24.0 if target.avatar.has_method("is_riding") and target.avatar.is_riding() and target.get("_is_jumping") != true else 0.0
			var jump_off: float = float(target.get("_air_height")) if target.get("_is_jumping") == true and target.get("_air_height") != null else 0.0
			position = target.avatar.position + Vector2(0, -av_h - ride_off - jump_off)
		elif target.has_method("get_ground_position"):
			position = target.to_local(target.get_ground_position()) + Vector2(0, -90.0)
		else:
			position = Vector2(0, -90.0)
	else:
		_sprite.position = Vector2(offset[0], offset[1])
		if "avatar" in target and target.avatar != null:
			position = target.avatar.position + Vector2(0, 1)
		elif target.has_method("get_ground_position"):
			position = target.to_local(target.get_ground_position()) + Vector2(0, 1)
		else:
			position = Vector2(0, 31)
	z_index = _layer(frame_in_dir)

func _layer(frame_in_dir: int) -> int:
	match str(_state.get("type", "Body")):
		"Foot":
			return Z_BEHIND
		"Head":
			return 15
		"Body":
			var back_start := int(_state.get("back_start", 0))
			var back_end := int(_state.get("back_end", 0))
			if back_end > back_start and frame_in_dir >= back_start and frame_in_dir < back_end:
				return Z_BEHIND
	return Z_FRONT

@warning_ignore_restore("integer_division")

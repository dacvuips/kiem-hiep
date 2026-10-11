extends Node2D
class_name MonsterCorpse
## Xác quái VLTK: diễn động tác CHẾT (đúng số frame DeathFrame gốc), nằm lại ít lâu rồi mờ dần và tự xoá.
## Dùng khi quái màn chơi (Enemy) chết mà vẫn muốn thấy cảnh chết của hình VLTK.

const STAY := 0.8
const FADE := 0.6

var _sprite: MonsterSprite
var _dir64: int = 0
var _len_frames: float = 20.0
var _frames: float = 0.0
var _after: float = 0.0

static func spawn(parent: Node, monster_id: int, dir64: int, world_pos: Vector2, scale_factor: float = 1.0) -> MonsterCorpse:
	var m := MonsterData.monster(monster_id)
	if m.is_empty() or parent == null:
		return null
	var node := MonsterCorpse.new()
	node.position = world_pos
	node.scale = Vector2.ONE * scale_factor
	node.z_index = -1  ## xác nằm dưới người/quái còn sống
	node._dir64 = dir64
	node._len_frames = float(MonsterData.action_frames(m, "die"))
	node._sprite = MonsterSprite.new()
	node.add_child(node._sprite)
	node._sprite.set_resource(str(m["res"]))
	parent.add_child(node)
	node._sprite.set_pose("die", dir64, 0.0)
	return node

func _process(delta: float) -> void:
	_frames += delta * VltkMath.FPS
	if _frames < _len_frames:
		_sprite.set_pose("die", _dir64, _frames / _len_frames)
		return
	_sprite.set_pose("die", _dir64, 1.0)
	_after += delta
	if _after > STAY:
		modulate.a = clampf(1.0 - (_after - STAY) / FADE, 0.0, 1.0)
	if _after >= STAY + FADE:
		queue_free()

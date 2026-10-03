extends Node

## Mỗi pool là 1 danh sách node "rảnh" (đã tạo sẵn, đang ẩn) sẵn sàng tái sử dụng
var _pools: Dictionary = {}

## Lấy 1 node từ pool (tạo mới nếu pool rỗng). Node trả về đã add vào parent và show().
func acquire(scene: PackedScene, parent: Node) -> Node:
	var key := scene.resource_path
	if not _pools.has(key):
		_pools[key] = []

	var pool: Array = _pools[key]
	var node: Node

	if pool.is_empty():
		node = scene.instantiate()
		node.set_meta("pool_key", key)
	else:
		node = pool.pop_back()

	if node.get_parent() != parent:
		if node.get_parent():
			node.get_parent().remove_child(node)
		parent.add_child(node)

	if node.has_method("_on_pool_acquire"):
		node._on_pool_acquire()

	node.visible = true
	if node.has_method("set_process"):
		node.set_process(true)
	if node.has_method("set_physics_process"):
		node.set_physics_process(true)

	return node

## Trả node về pool thay vì queue_free() — ẩn đi, tắt process, chờ dùng lại
func release(node: Node) -> void:
	if not node.has_meta("pool_key"):
		node.queue_free()
		return

	var key: String = node.get_meta("pool_key")
	if not _pools.has(key):
		_pools[key] = []

	if node.has_method("_on_pool_release"):
		node._on_pool_release()

	node.visible = false
	node.set_physics_process(false)
	node.set_process(false)

	if node.get_parent():
		node.get_parent().remove_child(node)

	_pools[key].append(node)

## Hoãn acquire tới cuối frame — an toàn để gọi từ trong callback va chạm vật lý
## (body_entered/area_entered) mà không gặp lỗi "flushing queries". Vì ObjectPool
## là autoload, hàm này không bị hủy giữa chừng như self của node đang bị queue_free().
func acquire_deferred(scene: PackedScene, parent: Node, global_pos: Vector2, setup_callable: Callable = Callable()) -> void:
	_deferred_acquire.call_deferred(scene, parent, global_pos, setup_callable)

func _deferred_acquire(scene: PackedScene, parent: Node, global_pos: Vector2, setup_callable: Callable) -> void:
	var node: Node2D = acquire(scene, parent)
	node.global_position = global_pos
	if setup_callable.is_valid():
		setup_callable.call(node)

class_name ObjectPool
extends RefCounted
## Pre-instantiated scene pool (docs/PERFORMANCE.md: zero runtime
## instantiate() during combat). Owned by a level; free_all on unload.
##
## Pooled scenes implement:
##   _pool_reset()      -> called on acquire (re-arm state)
##   release requested via the pooled node calling pool.release(self)

var _scene: PackedScene
var _parent: Node
var _free: Array[Node] = []
var _max_size: int


func _init(scene: PackedScene, parent: Node, prewarm: int, max_size := 64) -> void:
	_scene = scene
	_parent = parent
	_max_size = max_size
	for i in prewarm:
		var node := _scene.instantiate()
		node.set_meta(&"pool", self)
		_park(node)
		_parent.add_child(node)


func acquire() -> Node:
	var node: Node
	if _free.is_empty():
		# pool exhausted: grow rather than fail (budget breach shows in F3)
		node = _scene.instantiate()
		node.set_meta(&"pool", self)
		_parent.add_child(node)
	else:
		node = _free.pop_back()
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node.has_method("_pool_reset"):
		node._pool_reset()
	return node


func release(node: Node) -> void:
	if _free.size() >= _max_size:
		node.queue_free()
		return
	_park(node)


func free_count() -> int:
	return _free.size()


func _park(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is Node2D:
		node.visible = false
		node.global_position = Vector2(-9999, -9999)
	_free.append(node)

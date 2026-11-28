extends SceneTree

class PausableNode extends Node:
	var count := 0
	func _process(_delta: float) -> void:
		count += 1

class AlwaysNode extends Node:
	var count := 0
	func _process(_delta: float) -> void:
		count += 1

var pausable: PausableNode
var always: AlwaysNode
var frame := 0

func _init() -> void:
	pausable = PausableNode.new()
	pausable.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_root().add_child(pausable)
	
	always = AlwaysNode.new()
	always.process_mode = Node.PROCESS_MODE_ALWAYS
	pausable.add_child(always)
	
	paused = true

func _process(_delta: float) -> bool:
	frame += 1
	if frame >= 5:
		print("RESULTS: pausable.count = ", pausable.count, " always.count = ", always.count)
		quit(0)
		return true
	return false

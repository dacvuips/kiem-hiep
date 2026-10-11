@tool
extends Control
## Co node Stage (toạ độ mockup 1672x941) vừa khít node cha và căn giữa — chạy cả trong editor
## nên cảnh trong editor trùng với lúc chạy game. Chỉnh bố cục: kéo các node con của Stage như bình thường.

const STAGE_SIZE := Vector2(1672, 941)

func _ready() -> void:
	var parent := get_parent() as Control
	if parent:
		parent.resized.connect(_fit)
	_fit()

func _fit() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	size = STAGE_SIZE
	var s := minf(parent.size.x / STAGE_SIZE.x, parent.size.y / STAGE_SIZE.y)
	scale = Vector2(s, s)
	position = (parent.size - STAGE_SIZE * s) * 0.5

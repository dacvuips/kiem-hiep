@tool
extends Control
## Co node Stage (toạ độ mockup 1672x941) vừa khít node cha và căn giữa — chạy cả trong editor
## nên cảnh trong editor trùng với lúc chạy game. Chỉnh bố cục: kéo các node con của Stage như bình thường.

const STAGE_SIZE := Vector2(1672, 941)
@export var design_size := STAGE_SIZE
@export var expand_horizontal := false

signal layout_adapted(virtual_width: float, virtual_height: float, extra_w: float)

func _ready() -> void:
	var parent := get_parent() as Control
	if parent:
		parent.resized.connect(_on_resized)
	if get_viewport():
		get_viewport().size_changed.connect(_on_resized)
	_fit.call_deferred()

func _on_resized() -> void:
	_fit.call_deferred()

func _fit() -> void:
	if not is_inside_tree():
		return
	var parent := get_parent() as Control
	if parent == null:
		return
	var p_size := parent.size
	if p_size.x <= 0.0 or p_size.y <= 0.0:
		if get_viewport():
			p_size = get_viewport_rect().size
	if p_size.x <= 0.0 or p_size.y <= 0.0:
		return
	var target := design_size if design_size != Vector2.ZERO else STAGE_SIZE

	if expand_horizontal and p_size.y > 0.0:
		var s := p_size.y / target.y
		if s <= 0.0:
			return
		scale = Vector2(s, s)
		position = Vector2.ZERO
		var virtual_w := p_size.x / s
		size = Vector2(virtual_w, target.y)
		var extra_w := maxf(0.0, virtual_w - target.x)
		layout_adapted.emit(virtual_w, target.y, extra_w)
		return

	size = target
	var s := minf(p_size.x / target.x, p_size.y / target.y)
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = (p_size - target * s) * 0.5

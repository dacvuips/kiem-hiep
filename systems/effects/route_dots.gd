extends Node2D
class_name RouteDots
## Đường CHẤM VÀNG trên màn chơi chính chỉ lối nhân vật đang tự đi tới điểm đến (giống đường chấm trên mini map).
## Vẽ theo lộ trình còn lại của Player.get_route_feet(): từ chân nhân vật qua các điểm tới đích; chấm trôi dần về phía đích.

const GAP := 18.0
const COLOR := Color(1.0, 0.9, 0.15)

var _player: Node2D
var _phase := 0.0

func _init(player: Node2D = null) -> void:
	_player = player
	top_level = true
	z_index = -2          ## trên nền map, dưới thân nhân vật/quái
	z_as_relative = false

func _process(delta: float) -> void:
	var moving: bool = _player != null and is_instance_valid(_player) and _player.should_show_route()
	if moving:
		_phase = fmod(_phase + delta * 40.0, GAP)
	if moving or visible:
		visible = moving
		queue_redraw()

func _draw() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.should_show_route():
		return
	var pts := PackedVector2Array([_player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)])
	pts.append_array(_player.get_route_feet())
	## Đường dài toàn map có thể hàng chục nghìn px (hàng nghìn chấm): chỉ vẽ phần nằm trong khung nhìn của camera.
	var view := (get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(8.0)
	var carry := _phase
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		if not view.intersects(Rect2(a, Vector2.ZERO).expand(b)):
			carry = fmod(carry + length, GAP)   ## đoạn ngoài khung: chỉ giữ nhịp chấm cho liền mạch
			continue
		var dir := (b - a) / length
		var dist := GAP - carry
		while dist <= length:
			var p := a + dir * dist
			if view.has_point(p):
				draw_circle(p, 3.6, Color(0, 0, 0, 0.55))
				draw_circle(p, 2.6, COLOR)
			dist += GAP
		carry = fmod(carry + length, GAP)

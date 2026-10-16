extends Control
class_name RarityRing
## Vòng sáng chạy quanh ô đồ quý (giống VLTK): viền màu + 1 vệt sáng chạy dọc 4 cạnh. attach(box, item) thêm 1 node con (không
## nhận chuột) vẽ vòng thẳng lên `box` qua tín hiệu draw — đúng mép ô kể cả khi `box` là Container (con bị ép thụt vào lề).
##   - Đồ hoàng kim: vàng.  - Đồ tím (ItemInstance.is_purple): tím.
## Dùng chung với ItemSlotButton (vẽ qua draw_ring).

const GOLD := Color(1.0, 0.85, 0.2)
const PURPLE := Color(0.78, 0.42, 1.0)
const RUN_SPEED := 0.45  ## vòng/giây của vệt sáng
const RUN_LENGTH := 0.22 ## độ dài vệt sáng (tỉ lệ chu vi)

var color := GOLD
var _phase := 0.0
var _target: CanvasItem

## Màu vòng của món (alpha 0 = món thường, không có vòng).
static func color_of(item: ItemInstance) -> Color:
	if item == null:
		return Color(0, 0, 0, 0)
	if item.is_gold():
		return GOLD
	return PURPLE if item.is_purple() else Color(0, 0, 0, 0)

## Gắn vòng vào `box` nếu món là hoàng kim / tím. Trả vòng (null = món thường).
static func attach(box: Control, item: ItemInstance) -> RarityRing:
	var c := color_of(item)
	if c.a <= 0.0:
		return null
	var ring := RarityRing.new()
	ring.color = c
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring._target = box
	box.draw.connect(ring._draw_on_target)
	box.add_child(ring)
	return ring

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * RUN_SPEED, 1.0)
	_target.queue_redraw()

func _draw_on_target() -> void:
	var s: Vector2 = (_target as Control).size
	draw_ring(_target, Rect2(Vector2(1, 1), s - Vector2(2, 2)), _phase, color)

static func draw_ring(ci: CanvasItem, r: Rect2, phase: float, c: Color) -> void:
	ci.draw_rect(r, Color(c, 0.55), false, 1.5)
	var glow := c.lerp(Color.WHITE, 0.6)
	## Vệt sáng: các điểm trên chu vi từ phase tới phase + RUN_LENGTH.
	var points := PackedVector2Array()
	for k in 13:
		points.append(_point_on_perimeter(r, fmod(phase + RUN_LENGTH * k / 12.0, 1.0)))
	for k in points.size() - 1:
		var a := float(k) / (points.size() - 1)
		if points[k].distance_to(points[k + 1]) < (r.size.x + r.size.y):
			ci.draw_line(points[k], points[k + 1], Color(glow, 0.35 + 0.65 * a), 3.0)

static func _point_on_perimeter(r: Rect2, t: float) -> Vector2:
	var per := 2.0 * (r.size.x + r.size.y)
	var d := t * per
	if d < r.size.x:
		return r.position + Vector2(d, 0)
	d -= r.size.x
	if d < r.size.y:
		return r.position + Vector2(r.size.x, d)
	d -= r.size.y
	if d < r.size.x:
		return r.position + Vector2(r.size.x - d, r.size.y)
	d -= r.size.x
	return r.position + Vector2(0, r.size.y - d)

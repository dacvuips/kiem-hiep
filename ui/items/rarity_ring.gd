extends Control
class_name RarityRing
## Hiệu ứng viền chạy ô đồ quý (chuẩn VLTK): đúng 2 line đối diện nhau (cách nhau 0.5 chu vi)
## cùng di chuyển quanh 4 cạnh ô đồ.
## attach(box, item) thêm 1 node con (không nhận chuột) vẽ vòng thẳng lên `box` qua tín hiệu draw.
##   - Đồ hoàng kim: vàng.  - Đồ tím (ItemInstance.is_purple): tím.
## Dùng chung với ItemSlotButton (vẽ qua draw_ring).

const GOLD := Color(1.0, 0.78, 0.0)
const PURPLE := Color(0.85, 0.28, 1.0)
const RUN_SPEED := 0.22   ## chu kỳ/giây (khoảng 4.5s hoàn thành 1 vòng 4 cạnh)
const STREAK_LENGTH := 0.20 ## độ dài mỗi line (20% chu vi: 2 line cách nhau 0.30 chu vi, không bao giờ chạm hay chồng nhau)

## Pha toàn cục đồng bộ theo thời gian game (giúp vệt sáng không bao giờ bị reset về 0 khi kéo thả/di chuyển món đồ)
static func get_global_phase() -> float:
	return fmod(float(Time.get_ticks_msec()) * 0.001 * RUN_SPEED, 1.0)

var color := GOLD
var _target: CanvasItem

## Màu vòng của món (alpha 0 = món thường, không có vòng).
static func color_of(item: ItemInstance) -> Color:
	if item == null:
		return Color(0, 0, 0, 0)
	if item.is_gold():
		return GOLD
	return PURPLE if item.is_purple() else Color(0, 0, 0, 0)

## Gắn vòng vào `box` nếu món là hoàng kim / tím. Trả vòng (null = món thường).
## Dọn dẹp triệt để mọi RarityRing cũ trên `box` để tránh bị nhân bản 4 line.
static func attach(box: Control, item: ItemInstance) -> RarityRing:
	if box == null:
		return null
	for c in box.get_children():
		if c is RarityRing or c.name.begins_with("RarityRing"):
			if box.draw.is_connected(c._draw_on_target):
				box.draw.disconnect(c._draw_on_target)
			box.remove_child(c)
			c.queue_free()
	for conn in box.draw.get_connections():
		if conn.callable.get_method() == "_draw_on_target":
			box.draw.disconnect(conn.callable)
	var c := color_of(item)
	if c.a <= 0.0:
		box.queue_redraw()
		return null
	var ring := RarityRing.new()
	ring.name = "RarityRing"
	ring.color = c
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring._target = box
	box.draw.connect(ring._draw_on_target)
	box.add_child(ring)
	box.queue_redraw()
	return ring

func _process(_delta: float) -> void:
	_target.queue_redraw()

func _draw_on_target() -> void:
	var s: Vector2 = (_target as Control).size
	draw_ring(_target, Rect2(Vector2(1, 1), s - Vector2(2, 2)), get_global_phase(), color)

static func draw_ring(ci: CanvasItem, r: Rect2, phase: float, c: Color) -> void:
	if c.a <= 0.0:
		return

	# Viền tĩnh bao quanh ô đồ nhạt dịu nhẹ, làm nền cho 2 line sáng chạy nổi bật
	ci.draw_rect(r, Color(c.r, c.g, c.b, 0.35), false, 1.0)

	# Đúng 2 line đối diện nhau (cách nhau 0.5 chu vi, độ dài mỗi line 0.20 để luôn có khoảng trống 0.30 chu vi giữa 2 line)
	_draw_streak(ci, r, phase, STREAK_LENGTH, c)
	_draw_streak(ci, r, fmod(phase + 0.5, 1.0), STREAK_LENGTH, c)

static func _draw_streak(ci: CanvasItem, r: Rect2, start_t: float, length: float, c: Color) -> void:
	var steps := 30
	var points := PackedVector2Array()
	for k in steps:
		var u := fmod(start_t + length * float(k) / float(steps - 1), 1.0)
		points.append(_point_on_perimeter(r, u))
	for k in points.size() - 1:
		var a := float(k) / float(points.size() - 1)
		# Kiểm tra tránh vẽ đường chéo nếu điểm nối bị wrap
		if points[k].distance_to(points[k + 1]) < (r.size.x + r.size.y) * 0.4:
			var intensity := pow(a, 1.4)
			var seg_col: Color
			if a > 0.7:
				var highlight := c.lerp(Color(1.0, 0.95, 0.45) if c.r > c.b else Color(0.95, 0.70, 1.0), (a - 0.7) / 0.3 * 0.4)
				seg_col = Color(highlight, lerpf(0.1, 1.0, intensity))
			else:
				seg_col = Color(c, lerpf(0.04, 0.85, intensity))
			var w := lerpf(1.2, 2.6, intensity)
			ci.draw_line(points[k], points[k + 1], seg_col, w)
	# Điểm sáng phát quang ở đầu mỗi line (ánh vàng/tím đậm chất hoàng kim)
	var head := points[points.size() - 1]
	ci.draw_circle(head, 2.8, Color(c, 0.4))
	var head_core := c.lerp(Color(1.0, 0.96, 0.55) if c.r > c.b else Color(0.96, 0.80, 1.0), 0.45)
	ci.draw_circle(head, 1.6, Color(head_core, 0.95))

static func _point_on_perimeter(r: Rect2, t: float) -> Vector2:
	var per := 2.0 * (r.size.x + r.size.y)
	var d := fmod(t, 1.0) * per
	if d < 0.0:
		d += per
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

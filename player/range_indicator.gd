extends Node2D

@export var color: Color = Color(1, 1, 1, 0.45)
@export var dot_radius: float = 1.2
@export var spacing: float = 16.0
var radius: float = 150.0

func set_radius(value: float) -> void:
	if is_equal_approx(radius, value):
		return  ## được gọi mỗi frame — chỉ vẽ lại khi tầm đổi
	radius = value
	queue_redraw()

## Tầm đánh tính theo logic VLTK (dọc nhân đôi) -> trên màn hình là elip: ngang = radius, dọc = radius / 2.
## Tâm đặt ở chân nhân vật (avatar lệch xuống so với gốc node).
const FEET_OFFSET := Vector2(0, 30)

func _draw() -> void:
	if radius <= 0.0 or spacing <= 0.0:
		return

	# Sinh các điểm mẫu quanh hình elip
	const SAMPLES := 128
	var pts := PackedVector2Array()
	pts.resize(SAMPLES + 1)
	for i in SAMPLES + 1:
		var a := TAU * (i % SAMPLES) / float(SAMPLES)
		pts[i] = FEET_OFFSET + Vector2(cos(a) * radius, sin(a) * radius * 0.5)

	# Tính độ dài tích lũy dọc theo chu vi elip
	var cum_dist := PackedFloat32Array()
	cum_dist.resize(SAMPLES + 1)
	cum_dist[0] = 0.0
	for i in range(1, SAMPLES + 1):
		cum_dist[i] = cum_dist[i - 1] + pts[i - 1].distance_to(pts[i])

	var total_len := cum_dist[SAMPLES]
	if total_len <= 0.0:
		return

	var count := maxi(8, int(round(total_len / spacing)))
	var actual_spacing := total_len / float(count)

	var curr_idx := 0
	for k in count:
		var s := k * actual_spacing

		while curr_idx < SAMPLES and cum_dist[curr_idx + 1] < s:
			curr_idx += 1
		var seg_len := cum_dist[curr_idx + 1] - cum_dist[curr_idx]
		var t := (s - cum_dist[curr_idx]) / seg_len if seg_len > 0.0001 else 0.0
		var dot_pos := pts[curr_idx].lerp(pts[curr_idx + 1], t)

		draw_circle(dot_pos, dot_radius, color, true, -1.0, true)

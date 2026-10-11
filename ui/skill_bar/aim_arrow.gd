extends Node2D
class_name AimArrow
## Mũi tên dài chỉ HƯỚNG ĐÁNH khi giữ kéo nút skill chính: vạch từ chân nhân vật theo hướng ngắm, đầu mũi tên ở cuối. Hướng nhập là
## hướng trên MÀN HÌNH; chiều dọc bị nén 1/2 (góc nhìn xéo của bản đồ, cùng cách tính điểm bắn trong Player._make_cast_point).
## top_level: đứng yên trên bản đồ, không xoay theo nhân vật. Chỉ vẽ khi đang ngắm.

const COLOR := Color(1.0, 0.85, 0.25, 0.9)
const COLOR_EDGE := Color(0.25, 0.1, 0.0, 0.8)
const HEAD := 22.0
const WIDTH := 5.0
## Ảnh mũi tên năng lượng (đầu mũi tên nằm BÊN TRÁI ảnh, đuôi bên phải). Kéo giãn theo độ dài ngắm, bề dày cố định.
const TEXTURE_PATH := "res://assets/ui/aim_arrow.png"
const THICKNESS := 44.0
const MIN_LENGTH := 48.0
static var _texture: Texture2D
static var _texture_tried := false

var _origin := Vector2.ZERO
var _tip := Vector2.ZERO

func _ready() -> void:
	## Nằm TRÊN mặt đất (nền bản đồ z = -100) nhưng DƯỚI nhân vật/quái/xác (z = 0 / -1) và vật rớt.
	z_as_relative = false
	z_index = -50
	visible = false

func set_aim(dir: Vector2, feet: Vector2, length: float) -> void:
	if dir == Vector2.ZERO:
		visible = false
		return
	var logic := Vector2(dir.x, dir.y * 2.0).normalized() * length
	_origin = feet
	_tip = feet + Vector2(logic.x, logic.y * 0.5)
	visible = true
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	if not (_tip.is_finite() and _origin.is_finite()) or _tip.distance_to(_origin) < HEAD:
		return   ## quá ngắn: tam giác đầu mũi tên suy biến (Godot báo "triangulation failed")
	var tex := _get_texture()
	if tex != null:
		var length := maxf(_tip.distance_to(_origin), MIN_LENGTH)
		## Quay sao cho trục -x của ảnh (đầu mũi tên) hướng theo hướng ngắm; đuôi nằm ở chân nhân vật.
		draw_set_transform(_origin, (_tip - _origin).angle() + PI, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-length, -THICKNESS * 0.5, length, THICKNESS), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var d := (_tip - _origin).normalized()
	var side := Vector2(-d.y, d.x)
	var base := _tip - d * HEAD
	draw_line(_origin, base, COLOR_EDGE, WIDTH + 3.0)
	draw_line(_origin, base, COLOR, WIDTH)
	var head := PackedVector2Array([_tip, base + side * HEAD * 0.55, base - side * HEAD * 0.55])
	_fill(head, COLOR_EDGE)
	var inner := PackedVector2Array([_tip - d * 2.5, base + side * (HEAD * 0.55 - 3.0), base - side * (HEAD * 0.55 - 3.0)])
	_fill(inner, COLOR)

## Chỉ tô khi đa giác chia được tam giác (tránh lỗi "triangulation failed" khi 3 điểm gần thẳng hàng / trùng nhau).
func _fill(points: PackedVector2Array, color: Color) -> void:
	if not Geometry2D.triangulate_polygon(points).is_empty():
		draw_colored_polygon(points, color)

## Nạp ảnh 1 lần (đọc thẳng file PNG như các ảnh VLTK khác của game); thiếu ảnh thì vẽ mũi tên cũ.
static func _get_texture() -> Texture2D:
	if _texture_tried:
		return _texture
	_texture_tried = true
	if FileAccess.file_exists(TEXTURE_PATH):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(TEXTURE_PATH)) == OK:
			_texture = ImageTexture.create_from_image(image)
	return _texture

@tool
extends Control
class_name AuraRing
## Vòng hào quang dưới chân nhân vật (màn Tạo Nhân Vật) — node Control KÉO THẢ/ĐỔI KÍCH THƯỚC được trong editor (@tool, tự chạy
## hoạt ảnh ngay trong editor). Hình vòng: dải PNG do tools/import_login_aura.py nhập từ các file .spr (ui/character_create/aura/).
## Ảnh được vẽ vừa khít khung node, giữ tỉ lệ, căn giữa; kéo/đổi cỡ khung để chỉnh vị trí và độ lớn, thuộc tính `tilt` để chỉnh độ nghiêng (dẹt).

const DIR := "res://ui/character_create/aura/"
const META_PATH := DIR + "aura.json"

## Tên vòng (khoá trong aura.json): hiện chỉ có id_5438aef0. Thêm vòng mới bằng tools/import_login_aura.py.
@export var aura_name: String = "id_5438aef0":
	set(value):
		aura_name = value
		_load()
## ĐỘ NGHIÊNG (độ dẹt của vòng): 1.0 = giữ đúng hình gốc; nhỏ hơn = vòng bị ép dẹt thành elip như nhìn nghiêng từ trên xuống
## (0.5 = cao bằng nửa), lớn hơn 1 = phồng cao hơn. Chiều rộng giữ nguyên, vòng vẫn ở giữa khung.
@export_range(0.2, 2.0, 0.01) var tilt: float = 1.0:
	set(value):
		tilt = value
		queue_redraw()
## Khung hình / giây.
@export_range(1.0, 60.0) var fps: float = 12.0

var _tex: Texture2D
var _frames := 1
var _cell := Vector2.ONE
var _frame := 0
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load()
	## Chỉ chạy khi đang hiện (ẩn thì dừng) — rẻ cho mobile.
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))

func _load() -> void:
	if not is_inside_tree() and not Engine.is_editor_hint():
		return
	_tex = null
	if FileAccess.file_exists(META_PATH) and ResourceLoader.exists(DIR + aura_name + ".png"):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if meta is Dictionary and meta.has(aura_name):
			var m: Dictionary = meta[aura_name]
			_frames = maxi(1, int(m["frames"]))
			_cell = Vector2(float(m["w"]), float(m["h"]))
			_tex = load(DIR + aura_name + ".png")
	_frame = 0
	_time = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if _tex == null:
		return
	_time += delta
	var f := int(_time * fps) % _frames
	if f != _frame:
		_frame = f
		queue_redraw()

func _draw() -> void:
	if _tex == null:
		if Engine.is_editor_hint():
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.8, 0.2, 0.35), false, 2.0)
		return
	var s := minf(size.x / _cell.x, size.y / _cell.y)
	var drawn := Vector2(_cell.x * s, _cell.y * s * tilt)
	var dest := Rect2((size - drawn) * 0.5, drawn)
	draw_texture_rect_region(_tex, dest, Rect2(Vector2(_frame * _cell.x, 0), _cell))
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.8, 0.2, 0.25), false, 1.0)

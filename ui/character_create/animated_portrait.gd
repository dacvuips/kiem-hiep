@tool
extends Control
class_name AnimatedPortrait
## Ảnh nhân vật đứng thở (loop) từ atlas lưới do tools/build_character_create_assets.py dựng.
## KÉO THẢ / ĐỔI KÍCH THƯỚC KHUNG được trong editor: nhân vật luôn được vẽ vừa khung, giữ tỉ lệ, CHÂN (đã đo) ở GIỮA CẠNH DƯỚI khung —
## kéo khung để dời chỗ đứng, kéo mép để đổi cỡ (chiều cao khung = chiều cao nhân vật). Trong editor hiện ảnh xem trước
## `preview_character`. Chỉ vẽ lại khi đổi khung và chỉ chạy khi đang hiển thị -> rẻ cho mobile.

signal pressed

const FPS := 12.0
const CHARS_DIR := "res://ui/character_create/chars/"

## CHỈNH TỪNG NHÂN VẬT: độ dời riêng (pixel Stage, + = sang phải / xuống dưới) cho mỗi nhân vật, khoá = tên sheet
## (hoa_nam, kim_nam, moc_nam, tho_nam, thuy_nam | hoa_nu, kim_nu, moc_nu, tho_nu, thuy_nu). Cách làm trong editor: chọn node, đổi
## `preview_character` sang nhân vật cần chỉnh, rồi kéo `preview_offset` — ảnh dời ngay và độ dời được lưu vào đây.
@export var offsets: Dictionary[String, Vector2] = {}

## Hệ số PHÓNG riêng cho từng nhân vật (1.0 = vừa khung), khoá giống `offsets`. Phóng quanh CHÂN nên chân không bị trôi.
@export var scales: Dictionary[String, float] = {}

## Nhân vật đang xem trong editor (chỉ để căn chỉnh; khi chạy game nhân vật theo hệ đã chọn).
@export var preview_character: String = "hoa_nam":
	set(value):
		preview_character = value
		if Engine.is_editor_hint() and is_inside_tree():
			_load_preview()
			preview_offset = offsets.get(preview_character, Vector2.ZERO)
			preview_scale = scales.get(preview_character, 1.0)
			notify_property_list_changed()

## Hệ số phóng của `preview_character` (nhân vật to/nhỏ hơn so với khung).
@export_range(0.3, 2.5, 0.01) var preview_scale: float = 1.0:
	set(value):
		preview_scale = value
		if Engine.is_editor_hint() and is_inside_tree():
			_store_scale(value)
			queue_redraw()

## Độ dời của `preview_character` — kéo số này để căn lại nhân vật đó.
@export var preview_offset: Vector2 = Vector2.ZERO:
	set(value):
		preview_offset = value
		if Engine.is_editor_hint() and is_inside_tree():
			_store_offset(value)
			queue_redraw()

var _texture: Texture2D
var _key := ""          ## tên sheet đang hiển thị (khoá của offsets)
var _feet_x := -1.0      ## toạ độ ngang của chân trong ô (pixel ô); < 0 = chưa đo -> căn giữa ô
var _cell := Vector2i.ZERO
var _cols := 1
var _frames := 1
var _frame := 0
var _time := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		_load_preview()
		_sync_preview_values()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _load_preview() -> void:
	var f := FileAccess.open(CHARS_DIR + "chars.json", FileAccess.READ)
	if f == null:
		return
	var meta: Variant = JSON.parse_string(f.get_as_text())
	var sheet := sheet_for(preview_character)
	var path := CHARS_DIR + sheet + ".png"
	if meta is Dictionary and meta.has(sheet) and ResourceLoader.exists(path):
		setup(load(path), meta[sheet], preview_character)
	else:
		_texture = null
		queue_redraw()

## Sheet dùng để vẽ nhân vật `char_key` (VD "kim_nu"): chưa có ảnh riêng thì TẠM mượn sheet giới tính kia cùng hệ
## (kim_nu -> kim_nam, thuy_nam -> thuy_nu). Cỡ/vị trí vẫn chỉnh theo khoá `char_key`, nên mượn ảnh không ảnh hưởng nhân vật gốc;
## thả <he>_<gioi>.png + mục chars.json vào chars/ là tự dùng ảnh thật.
static func sheet_for(char_key: String) -> String:
	if _sheet_exists(char_key):
		return char_key
	var other := char_key.trim_suffix("_nam") + "_nu" if char_key.ends_with("_nam") else char_key.trim_suffix("_nu") + "_nam"
	return other if _sheet_exists(other) else char_key

static func _sheet_exists(key: String) -> bool:
	if not ResourceLoader.exists(CHARS_DIR + key + ".png"):
		return false
	var f := FileAccess.open(CHARS_DIR + "chars.json", FileAccess.READ)
	var meta: Variant = JSON.parse_string(f.get_as_text()) if f else null
	return meta is Dictionary and meta.has(key)

## Gắn atlas + mô tả ô. KHÔNG đổi kích thước/vị trí node — khung do người chỉnh trong editor quyết định chỗ đứng và cỡ.
func setup(texture: Texture2D, meta: Dictionary, key: String = "") -> void:
	_texture = texture
	_key = key
	_feet_x = float(meta.get("feet_x", -1.0))
	_cell = Vector2i(int(meta["cell_w"]), int(meta["cell_h"]))
	_cols = int(meta["cols"])
	_frames = int(meta["frames"])
	_frame = 0
	_time = 0.0
	queue_redraw()

## Bật/tắt chạy hoạt ảnh. Tắt = đứng yên ở khung 1.
func set_playing(on: bool) -> void:
	set_process(on and _texture != null and not Engine.is_editor_hint())
	if not on and _frame != 0:
		_frame = 0
		_time = 0.0
		queue_redraw()

func _process(delta: float) -> void:
	if _texture == null:
		return
	_time += delta
	var f := int(_time * FPS) % _frames
	if f != _frame:
		_frame = f
		queue_redraw()

## Ghi giá trị xem trước vào từ điển của nhân vật đang xem (SỬA TẠI CHỖ — gán lại cả từ điển khác kiểu sẽ bị Godot từ chối).
func _store_offset(value: Vector2) -> void:
	if value == Vector2.ZERO:
		offsets.erase(preview_character)
	else:
		offsets[preview_character] = value

func _store_scale(value: float) -> void:
	if is_equal_approx(value, 1.0):
		scales.erase(preview_character)
	else:
		scales[preview_character] = value

## Mở scene trong editor: đồng bộ 2 ô xem trước ↔ từ điển của nhân vật đang xem (scene cũ đã lưu preview_* mà chưa có trong từ điển).
func _sync_preview_values() -> void:
	if preview_offset != Vector2.ZERO:
		_store_offset(preview_offset)
	else:
		preview_offset = offsets.get(preview_character, Vector2.ZERO)
	if not is_equal_approx(preview_scale, 1.0):
		_store_scale(preview_scale)
	else:
		preview_scale = scales.get(preview_character, 1.0)


func _offset_of(key: String) -> Vector2:
	return offsets.get(key, Vector2.ZERO)

## Hệ số phóng của nhân vật `key` (mặc định 1.0).
func scale_of(key: String = _key) -> float:
	return float(scales.get(key, 1.0))

## Điểm CHÂN của nhân vật `key` (toạ độ của node cha): giữa cạnh dưới khung + độ dời chỉnh tay. Vòng hào quang bám theo điểm này.
func feet_point(key: String = _key) -> Vector2:
	return position + Vector2(size.x * 0.5, size.y) + _offset_of(key)

func _draw() -> void:
	if _texture == null:
		if Engine.is_editor_hint():
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.8, 1, 0.3), false, 2.0)
		return
	var cell := Vector2(_cell)
	var s := minf(size.x / cell.x, size.y / cell.y) * scale_of(_key)
	## Căn CHÂN (feet_x, đo bởi tools/measure_character_feet.py) vào giữa cạnh dưới khung, rồi cộng độ dời chỉnh tay của nhân vật này.
	var foot := _feet_x if _feet_x >= 0.0 else cell.x * 0.5
	var origin: Vector2 = Vector2(size.x * 0.5 - foot * s, size.y - cell.y * s) + _offset_of(_key)
	var dest := Rect2(origin, cell * s)
	var src := Rect2(Vector2((_frame % _cols) * _cell.x, (_frame / _cols) * _cell.y), cell)
	draw_texture_rect_region(_texture, dest, src)
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.8, 1, 0.3), false, 1.0)

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()

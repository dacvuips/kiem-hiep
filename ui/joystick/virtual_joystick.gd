extends Control
class_name MoveJoystick  ## không đặt "VirtualJoystick" — trùng class có sẵn của Godot 4.7
## Joystick ảo kiểu mobile góc dưới-trái: chạm/nhấn chuột trong vùng này rồi KÉO -> đế joystick dời tới
## đúng chỗ chạm, kéo núm để di chuyển; thả tay -> đế về vị trí nghỉ, dừng di chuyển.
##
## KHÔNG nói chuyện trực tiếp với Player — "bấm" hộ các action move_left/right/up/down qua
## Input.action_press(strength) nên player.gd vẫn chỉ đọc Input.get_vector() như cũ, bàn phím và
## joystick dùng song song được. Bố cục (vùng chạm, kích thước đế/núm) chỉnh trong VirtualJoystick.tscn.

## Chạm rồi THẢ mà không kéo (bấm 1 chỗ trên bản đồ nằm trong vùng joystick) -> phát `tapped` với vị trí
## màn hình để nhân vật chạy tới đó, joystick không hiện. Phải kéo quá `drag_start_distance` mới bật joystick.
signal tapped(screen_position: Vector2)

## Tỉ lệ bán kính đế mà dưới mức đó coi như chưa kéo (tránh nhân vật trôi khi chỉ chạm nhẹ).
@export_range(0.0, 0.9) var deadzone: float = 0.15
## Kéo xa hơn (px) chừng này từ chỗ chạm mới bật joystick; ít hơn mà thả tay = 1 cú bấm "chạy tới".
@export var drag_start_distance: float = 12.0

@onready var _base: Control = %Base
@onready var _knob: Control = %Knob

var _rest_base_position: Vector2
## Pointer đang giữ trong vùng: chỉ số ngón tay (touch), MOUSE_POINTER (chuột), -1 = không có.
var _pointer: int = -1
const MOUSE_POINTER := -2
## false = mới chạm, chưa kéo đủ xa (chưa biết là bấm hay kéo); true = đang điều khiển joystick.
var _active: bool = false
var _press_position: Vector2
var _pressed_actions: Dictionary = {}  ## action (StringName) -> true, các action joystick đang giữ

func _ready() -> void:
	_rest_base_position = _base.position
	_center_knob()

## Game bị pause giữa lúc đang kéo (bảng lên cấp, popup thoát trận...) -> nhả luôn, không thì sau
## khi hết pause nhân vật tự đi tiếp theo hướng cũ.
func _process(_delta: float) -> void:
	if _pointer != -1 and get_tree().paused:
		_stop()

func _gui_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index, event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)
		accept_event()
	## Chuột chỉ dùng khi máy KHÔNG có màn cảm ứng — trên mobile Godot tự sinh thêm sự kiện chuột giả
	## từ mỗi lần chạm, xử lý cả 2 sẽ bị đúp.
	elif not DisplayServer.is_touchscreen_available():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press(MOUSE_POINTER, event.position)
			else:
				_on_release(MOUSE_POINTER, event.position)
			accept_event()
		elif event is InputEventMouseMotion:
			_on_drag(MOUSE_POINTER, event.position)
			accept_event()

func _on_press(pointer: int, local_position: Vector2) -> void:
	if _pointer != -1:
		return
	_pointer = pointer
	_press_position = local_position
	_active = false

func _on_drag(pointer: int, local_position: Vector2) -> void:
	if pointer != _pointer:
		return
	if _active:
		_update_knob(local_position)
	elif local_position.distance_to(_press_position) >= drag_start_distance:
		## Kéo bắt đầu TRONG đế đang đứng yên -> giữ đế tại chỗ (núm lệch theo tay như joystick cố định);
		## kéo ở chỗ khác trong vùng -> đế dời tới chỗ bắt đầu chạm (joystick nổi). Kể cả trên đế, chỉ chạm
		## rồi thả (không kéo) vẫn là bấm "chạy tới".
		if Rect2(_base.position, _base.size).has_point(_press_position):
			_pointer = pointer
			_active = true
		else:
			_start(pointer, _press_position)
		_update_knob(local_position)

func _on_release(pointer: int, local_position: Vector2) -> void:
	if pointer != _pointer:
		return
	var was_tap := not _active
	_stop()
	if was_tap:
		tapped.emit(get_global_transform_with_canvas() * local_position)

## Ẩn joystick (VD lúc mở bảng skill) phải nhả phím, không thì nhân vật cứ đi mãi theo hướng cũ.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _pointer != -1:
		_stop()

func _start(pointer: int, local_position: Vector2) -> void:
	_pointer = pointer
	_active = true
	_base.position = local_position - _base.size * 0.5
	_update_knob(local_position)

func _stop() -> void:
	_pointer = -1
	_active = false
	_base.position = _rest_base_position
	_center_knob()
	_apply_direction(Vector2.ZERO)

func _update_knob(local_position: Vector2) -> void:
	var radius := _base.size.x * 0.5
	var center := _base.position + _base.size * 0.5
	var offset := (local_position - center).limit_length(radius)
	_knob.position = _base.size * 0.5 + offset - _knob.size * 0.5
	var direction := offset / radius
	_apply_direction(direction if direction.length() > deadzone else Vector2.ZERO)

func _center_knob() -> void:
	_knob.position = (_base.size - _knob.size) * 0.5

func _apply_direction(direction: Vector2) -> void:
	_set_action("move_left", -direction.x)
	_set_action("move_right", direction.x)
	_set_action("move_up", -direction.y)
	_set_action("move_down", direction.y)

## Chỉ nhả action mà CHÍNH joystick đã bấm — không thì đang giữ phím mũi tên trên bàn phím cũng bị
## joystick nhả mất.
func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_pressed_actions[action] = true
	elif _pressed_actions.has(action):
		Input.action_release(action)
		_pressed_actions.erase(action)

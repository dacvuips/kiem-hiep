extends Control

class_name WebSkillPicker

## Bảng chọn skill chuột trái / phải của bản web — KUiSkillTree gốc (S3Client/Ui/UiCase/UiSkillTree.cpp, ini \Ui\Ui3 trong
## 1024.pak: BtnSize=36,36, KeyFont=16, KeyColor=255,0,0): chỉ vẽ icon skill, không nền; mỗi hàng 8 ô (KUiSkillData.nLevel =
## thứ tự / 8), hàng đầu ở trên, trong hàng xếp TỪ PHẢI SANG TRÁI; góc dưới-phải bảng trùng góc dưới-phải ô bấm mở.
##   - Bấm trái 1 icon = chọn làm skill trái / phải rồi đóng. Bấm phải / Esc / bấm ra ngoài = đóng.
##   - Rê chuột lên icon rồi bấm Q E R Y U H = gán phím tắt (chữ phím đỏ vẽ trên icon).

const BTN := 36.0
const PER_ROW := 8
const KEY_COLOR := Color8(255, 0, 0)
const KEY_FONT := 16

static var current: WebSkillPicker = null

var _left := true
var _player: Node
var _skills: Array[SkillDefinition] = []
var _scale := 1.0
var _hover := -1
var _on_pick: Callable

## Mở bảng cho ô T (left = true) / P; `anchor` = khung ô (toạ độ màn hình) để bảng mọc lên từ góc dưới-phải của nó.
static func open(host: Node, player: Node, left: bool, anchor: Rect2, ui_scale: float, on_pick: Callable) -> WebSkillPicker:
	close_current()
	var w := WebSkillPicker.new()
	w._left = left
	w._player = player
	w._scale = ui_scale
	w._on_pick = on_pick
	w._skills = WebMouseSkills.eligible_skills(player.skill_controller, left)
	host.add_child(w)
	w._layout(anchor)
	current = w
	return w

static func close_current() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	z_index = 50

func _exit_tree() -> void:
	if current == self:
		current = null

func _layout(anchor: Rect2) -> void:
	var side := BTN * _scale
	var rows := ceili(float(_skills.size()) / PER_ROW)
	var cols := mini(_skills.size(), PER_ROW)
	size = Vector2(cols * side, rows * side)
	var br := anchor.position + anchor.size
	global_position = br - size
	if global_position.y < 0.0:
		global_position.y = 0.0
	if global_position.x < 0.0:
		global_position.x = 0.0

## Ô thứ `i`: hàng i / 8 từ trên xuống; trong hàng, ô đầu ở mép PHẢI.
func _cell(i: int) -> Rect2:
	var side := BTN * _scale
	var row := i / PER_ROW
	var col := i % PER_ROW
	return Rect2(Vector2(size.x - (col + 1) * side, row * side), Vector2(side, side))

func _index_at(local: Vector2) -> int:
	for i in _skills.size():
		if _cell(i).has_point(local):
			return i
	return -1

func _draw() -> void:
	var font := get_theme_default_font()
	for i in _skills.size():
		var r := _cell(i)
		var s := _skills[i]
		if s.icon != null:
			draw_texture_rect(s.icon, r, false)
		if i == _hover:
			draw_rect(r, Color(1, 0.85, 0.35, 0.9), false, 1.0)
		var key := WebMouseSkills.shortcut_name(s, _left)
		if key != "":
			draw_string_outline(font, r.position + Vector2(3, KEY_FONT * _scale * 0.9), key, HORIZONTAL_ALIGNMENT_LEFT, -1,
					int(KEY_FONT * _scale * 0.8), 3, Color.BLACK)
			draw_string(font, r.position + Vector2(3, KEY_FONT * _scale * 0.9), key, HORIZONTAL_ALIGNMENT_LEFT, -1,
					int(KEY_FONT * _scale * 0.8), KEY_COLOR)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _index_at(event.position)
		if h != _hover:
			_hover = h
			tooltip_text = _skills[h].skill_name if h >= 0 else ""
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		accept_event()
		if event.button_index == MOUSE_BUTTON_LEFT:
			var i := _index_at(event.position)
			if i >= 0:
				var s := _skills[i]
				if _left:
					WebMouseSkills.set_left(s)
				else:
					WebMouseSkills.set_right(_player, s)
				if _on_pick.is_valid():
					_on_pick.call()
			close_current()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			close_current()

## Esc đóng; Q E R Y U H khi đang rê trên icon = gán phím tắt (bảng mở thì phím không đổi skill).
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_current()
			return
		var idx := WebMouseSkills.SHORTCUT_KEYS.find(k.physical_keycode)
		if idx >= 0:
			get_viewport().set_input_as_handled()
			var h := _index_at(get_local_mouse_position())
			if h >= 0:
				WebMouseSkills.set_shortcut(idx, _skills[h], _left)
				queue_redraw()
		return
	## Bấm ra ngoài bảng = đóng (gốc: bảng là cửa sổ nổi, mất chọn thì ẩn).
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and not get_global_rect().has_point(mb.global_position):
		close_current()

extends CanvasLayer
class_name PotentialPointPopup
## Popup nhập số điểm tiềm năng muốn cộng vào 1 chỉ số gốc (mở khi bấm nút "+" ở bảng Nhân vật). Ô nhập là SpinBox
## giới hạn 1..số điểm đang có — gõ số lớn hơn sẽ tự kẹp về tối đa. Có nút −/+/Tối đa cho thao tác chạm.
## Bấm ra ngoài hoặc "Hủy" để đóng. Bố cục trong PotentialPointPopup.tscn.

const SCENE_PATH := "res://ui/character_status/PotentialPointPopup.tscn"
const STAT_NAMES := ["Sức mạnh", "Thân pháp", "Sinh khí", "Nội công"]

var _profile: PlayerProfile
var _stat: int
var _on_done: Callable

## on_done(added: int) gọi sau khi cộng xong (đã lưu save).
static func open(parent: Node, profile: PlayerProfile, stat: int, on_done: Callable) -> PotentialPointPopup:
	var popup: PotentialPointPopup = load(SCENE_PATH).instantiate()
	popup._profile = profile
	popup._stat = stat
	popup._on_done = on_done
	parent.add_child(popup)
	return popup

func _ready() -> void:
	add_to_group(UiPopups.GROUP)   ## đang mở thì lăn chuột không zoom camera
	process_mode = Node.PROCESS_MODE_ALWAYS
	## Khung/nút lấy từ GameUi (theme_type_variation trong .tscn); màu chữ mang nghĩa theo bảng màu chung.
	GameUi.apply()
	(%Dim as ColorRect).color = GameUi.DIM
	(%Remaining as Label).add_theme_color_override("font_color", GameUi.TEXT)
	(%Preview as Label).add_theme_color_override("font_color", GameUi.GOLD)
	%Dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	(%Title as Label).text = "Cộng điểm: %s" % STAT_NAMES[_stat]
	(%Remaining as Label).text = "Điểm tiềm năng còn: %d" % _profile.potential_points
	var amount: SpinBox = %Amount
	GameUi.style(amount.get_line_edit(), GameUi.INPUT)
	amount.max_value = maxi(_profile.potential_points, 1)
	amount.value = 1
	amount.value_changed.connect(func(_v: float) -> void: _update_preview())
	%MinusButton.pressed.connect(func() -> void: amount.value -= 1)
	%PlusButton.pressed.connect(func() -> void: amount.value += 1)
	%MaxButton.pressed.connect(func() -> void: amount.value = amount.max_value)
	%ConfirmButton.pressed.connect(_confirm)
	%CancelButton.pressed.connect(queue_free)
	amount.get_line_edit().text_submitted.connect(func(_t: String) -> void: _confirm())
	_update_preview()

func _current_value() -> int:
	return [_profile.strength, _profile.dexterity, _profile.vitality, _profile.energy][_stat]

func _update_preview() -> void:
	var n := int((%Amount as SpinBox).value)
	(%Preview as Label).text = "%s: %d → %d" % [STAT_NAMES[_stat], _current_value(), _current_value() + n]

func _confirm() -> void:
	var amount: SpinBox = %Amount
	amount.apply()  ## lấy cả số đang gõ dở trong ô nhập (đã kẹp trong 1..tối đa)
	var added := _profile.add_potential_points(_stat as PlayerProfile.BaseStat, int(amount.value))
	if added > 0:
		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
	if _on_done.is_valid():
		_on_done.call(added)
	queue_free()

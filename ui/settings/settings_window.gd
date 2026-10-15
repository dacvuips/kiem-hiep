extends SocialWindow
class_name SettingsWindow
## Khung "Cài đặt" (nút Cài đặt trên màn chơi) — cài đặt của MÁY, đổi là lưu ngay vào user://settings.cfg:
##   - Nhạc nền bật/tắt (MusicManager.enabled).
##   - Lăn chuột để zoom camera bật/tắt + thanh trượt mức zoom (GameSettings; áp ngay lên camera nhân vật).

const ZOOM_STEP := 0.025

var _player: Node
var _music: CheckButton
var _zoom_slider: HSlider
var _zoom_value: Label

static func open(host: Node) -> SettingsWindow:
	return SocialWindow.present(host, SettingsWindow.new(), &"settings") as SettingsWindow

func _init() -> void:
	super._init("Cài đặt", "", 380.0)

	body.add_child(SocialUi.label("Âm thanh", SocialUi.SUBTITLE))
	_music = _check("Nhạc nền", MusicManager.enabled)
	_music.toggled.connect(func(on: bool) -> void: MusicManager.enabled = on)

	body.add_child(SocialUi.divider())
	body.add_child(SocialUi.label("Camera", SocialUi.SUBTITLE))
	var wheel := _check("Lăn chuột để zoom camera", GameSettings.wheel_zoom())
	wheel.toggled.connect(GameSettings.set_wheel_zoom)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	row.add_child(SocialUi.label("Mức zoom"))
	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = GameSettings.ZOOM_MIN
	_zoom_slider.max_value = GameSettings.ZOOM_MAX
	_zoom_slider.step = ZOOM_STEP
	_zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_zoom_slider.focus_mode = Control.FOCUS_NONE
	row.add_child(_zoom_slider)
	_zoom_value = SocialUi.label("", SocialUi.GOLD)
	_zoom_value.custom_minimum_size.x = 48
	row.add_child(_zoom_value)
	_zoom_slider.value = GameSettings.camera_zoom()
	_show_zoom(_zoom_slider.value)
	_zoom_slider.value_changed.connect(_on_zoom_changed)

	var buttons := add_button_row()
	var reset := SocialUi.stone_button("Zoom mặc định")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void: _zoom_slider.value = GameSettings.DEFAULT_ZOOM)
	buttons.add_child(reset)
	var close := SocialUi.stone_button("Đóng")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void: close_requested.emit())
	buttons.add_child(close)

func _ready() -> void:
	super._ready()
	_player = get_tree().get_first_node_in_group("player")
	## Nhạc có thể bị bật/tắt từ chỗ khác lúc khung đang mở — giữ ô tick đúng.
	MusicManager.enabled_changed.connect(_on_music_changed)

func _exit_tree() -> void:
	if MusicManager.enabled_changed.is_connected(_on_music_changed):
		MusicManager.enabled_changed.disconnect(_on_music_changed)   ## autoload sống lâu hơn khung

func _check(text: String, on: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	body.add_child(c)
	return c

func _on_music_changed(on: bool) -> void:
	_music.set_pressed_no_signal(on)

func _on_zoom_changed(z: float) -> void:
	_show_zoom(z)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_camera_zoom"):
		_player.set_camera_zoom(z)
	else:
		GameSettings.set_camera_zoom(z)

func _show_zoom(z: float) -> void:
	_zoom_value.text = "x%.2f" % z

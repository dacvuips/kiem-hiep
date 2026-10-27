extends SocialWindow
class_name SettingsWindow
## Khung "Cài đặt" (nút Cài đặt trên màn chơi và CharacterHub) — cài đặt của MÁY, đổi là lưu ngay vào user://settings.cfg:
##   - Nhạc nền bật/tắt (MusicManager.enabled).
##   - Hiệu ứng âm thanh bật/tắt (SfxManager.enabled).
##   - Lăn chuột để zoom camera bật/tắt + thanh trượt mức zoom (GameSettings; áp ngay lên camera nhân vật).
##   - Mở từ màn chơi (on_exit hợp lệ): thêm nút "Thoát về Character Hub".
##   - Mở từ CharacterHub (is_hub): thêm nút "Trở Về Chọn Nhân Vật", "Trở Về Chọn Server" và "Thoát Game".

const ZOOM_STEP := 0.025

var _player: Node
var _music: CheckButton
var _sfx: CheckButton
var _zoom_slider: HSlider
var _zoom_value: Label
var _is_hub: bool = false
var _sys_container: Control
var on_character_select: Callable
var on_server_select: Callable
var on_quit_game: Callable

static func open(host: Node, on_exit: Callable = Callable()) -> SettingsWindow:
	var win := SettingsWindow.new(false)
	if on_exit.is_valid():
		var exit := SocialUi.stone_button("Thoát về Character Hub")
		exit.pressed.connect(func() -> void:
			win.close_requested.emit()
			on_exit.call())
		win.body.add_child(SocialUi.divider())
		win.body.add_child(exit)
	return SocialWindow.present(host, win, &"settings") as SettingsWindow

func _init(is_hub: bool = false) -> void:
	super._init("Cài Đặt", "", 480.0)
	_is_hub = is_hub

	body.add_child(SocialUi.label("Âm thanh", SocialUi.SUBTITLE))
	_music = _check("Nhạc nền", MusicManager.enabled)
	_music.toggled.connect(func(on: bool) -> void: MusicManager.enabled = on)
	_sfx = _check("Hiệu ứng âm thanh", SfxManager.enabled)
	_sfx.toggled.connect(func(on: bool) -> void: SfxManager.enabled = on)

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

	if _is_hub:
		_build_hub_system_section()

func _build_hub_system_section() -> void:
	if _sys_container != null:
		return
	body.add_child(SocialUi.divider())
	body.add_child(SocialUi.label("Hệ thống", SocialUi.SUBTITLE))
	var sys_buttons := add_button_row()
	_sys_container = sys_buttons

	var char_btn := SocialUi.stone_button("Trở Về Chọn Nhân Vật")
	char_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_btn.pressed.connect(_on_character_select_clicked)
	sys_buttons.add_child(char_btn)

	var server_btn := SocialUi.stone_button("Trở Về Chọn Server")
	server_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_btn.pressed.connect(_on_server_select_clicked)
	sys_buttons.add_child(server_btn)

	var quit_row := add_button_row()
	var quit_btn := SocialUi.stone_button("Thoát Game")
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.pressed.connect(_on_quit_game_clicked)
	quit_row.add_child(quit_btn)

func setup_hub_actions(p_on_server: Callable = Callable(), p_on_quit: Callable = Callable(), p_on_character: Callable = Callable()) -> void:
	on_server_select = p_on_server
	on_quit_game = p_on_quit
	on_character_select = p_on_character
	_build_hub_system_section()

func _on_character_select_clicked() -> void:
	if on_character_select.is_valid():
		on_character_select.call()
		return
	SocialWindow.confirm(self, "Chọn Nhân Vật", "Lưu dữ liệu và trở về màn hình chọn nhân vật?", func() -> void:
		if GameManager.local_profile != null:
			SaveManager.save_profile(GameManager.local_profile)
			await SaveManager.flush_online()
		if AccountApi.is_logged_in():
			get_tree().change_scene_to_file("res://ui/character_roster/CharacterRoster.tscn")
			return
		get_tree().change_scene_to_file("res://ui/character_select/CharacterSelect.tscn")
	)

func _on_server_select_clicked() -> void:
	if on_server_select.is_valid():
		on_server_select.call()
		return
	SocialWindow.confirm(self, "Chọn Máy Chủ", "Lưu dữ liệu và trở về màn hình chọn máy chủ?", func() -> void:
		if GameManager.local_profile != null:
			SaveManager.save_profile(GameManager.local_profile)
			await SaveManager.flush_online()
		get_tree().change_scene_to_file("res://ui/server_select/ServerSelect.tscn")
	)

func _on_quit_game_clicked() -> void:
	if on_quit_game.is_valid():
		on_quit_game.call()
		return
	SocialWindow.confirm(self, "Thoát Game", "Lưu dữ liệu và thoát khỏi trò chơi?", func() -> void:
		if GameManager.local_profile != null:
			SaveManager.save_profile(GameManager.local_profile)
			await SaveManager.flush_online()
		get_tree().quit()
	)

func _ready() -> void:
	super._ready()
	_player = get_tree().get_first_node_in_group("player")
	## Nhạc & hiệu ứng có thể bị bật/tắt từ chỗ khác lúc khung đang mở — giữ ô tick đúng.
	MusicManager.enabled_changed.connect(_on_music_changed)
	SfxManager.enabled_changed.connect(_on_sfx_changed)

func _exit_tree() -> void:
	if MusicManager.enabled_changed.is_connected(_on_music_changed):
		MusicManager.enabled_changed.disconnect(_on_music_changed)   ## autoload sống lâu hơn khung
	if SfxManager.enabled_changed.is_connected(_on_sfx_changed):
		SfxManager.enabled_changed.disconnect(_on_sfx_changed)

func _check(text: String, on: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	body.add_child(c)
	return c

func _on_music_changed(on: bool) -> void:
	_music.set_pressed_no_signal(on)

func _on_sfx_changed(on: bool) -> void:
	_sfx.set_pressed_no_signal(on)

func _on_zoom_changed(z: float) -> void:
	_show_zoom(z)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_camera_zoom"):
		_player.set_camera_zoom(z)
	else:
		GameSettings.set_camera_zoom(z)

func _show_zoom(z: float) -> void:
	_zoom_value.text = "x%.2f" % z

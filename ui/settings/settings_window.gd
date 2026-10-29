extends SocialWindow
class_name SettingsWindow
## Khung "Cài đặt" (nút Cài đặt trên màn chơi và CharacterHub) — cài đặt của MÁY, đổi là lưu ngay vào user://settings.cfg:
##   - Nhạc nền bật/tắt (MusicManager.enabled).
##   - Hiệu ứng âm thanh bật/tắt (SfxManager.enabled).
##   - Đổi ngôn ngữ giao diện (LocalizationManager): tiếng Việt, Anh, Nhật, Hàn, Nga, Pháp, Thái, Trung...
##   - Lăn chuột để zoom camera bật/tắt + thanh trượt mức zoom (GameSettings; áp ngay lên camera nhân vật).
##   - Cấu hình vị trí & kích thước giao diện gameplay (HUD) — lưu máy, không phụ thuộc tài khoản.
##   - Mở từ màn chơi (on_exit hợp lệ): thêm nút "Thoát về Character Hub".
##   - Mở từ CharacterHub (is_hub): thêm nút "Trở Về Chọn Nhân Vật", "Trở Về Chọn Server" và "Thoát Game".

const ZOOM_STEP := 0.025

var _player: Node
var _is_hub: bool = false
var on_character_select: Callable
var on_server_select: Callable
var on_quit_game: Callable

var _tab_buttons: Array[Button] = []
var _basic_container: VBoxContainer
var _hud_container: VBoxContainer

# Basic Tab Controls
var _audio_label: Label
var _music: CheckButton
var _music_vol_label: Label
var _music_slider: HSlider
var _music_val_label: Label
var _sfx: CheckButton
var _sfx_vol_label: Label
var _sfx_slider: HSlider
var _sfx_val_label: Label
var _lang_section_label: Label
var _lang_row_label: Label
var _lang_option: OptionButton
var _camera_label: Label
var _wheel_zoom_check: CheckButton
var _zoom_label: Label
var _zoom_slider: HSlider
var _zoom_value: Label
var _reset_zoom_btn: Button
var _close_btn: Button
var _exit_hub_btn: Button

# Hub Section Controls
var _sys_container: Control
var _sys_label: Label
var _char_btn: Button
var _server_btn: Button
var _quit_btn: Button

# HUD Tab Controls
var _hud_title_lbl: Label
var _hud_desc_lbl: Label
var _hud_tip_lbl: Label
var _btn_visual: Button
var _reset_all_btn: Button
var _hud_close_btn: Button

static func open(host: Node, on_exit: Callable = Callable()) -> SettingsWindow:
	var win := SettingsWindow.new(false)
	if on_exit.is_valid():
		var exit := SocialUi.stone_button(TranslationServer.translate("Thoát về Character Hub"))
		exit.pressed.connect(func() -> void:
			win.close_requested.emit()
			on_exit.call())
		win.add_exit_button(exit)
	return SocialWindow.present(host, win, &"settings") as SettingsWindow

func add_exit_button(btn: Control) -> void:
	if _basic_container != null:
		_basic_container.add_child(SocialUi.divider())
		_basic_container.add_child(btn)
		if btn is Button:
			_exit_hub_btn = btn

func _init(is_hub: bool = false) -> void:
	super._init(tr("Cài Đặt"), "", 530.0)
	_is_hub = is_hub

	_build_tabs_header()

	_basic_container = VBoxContainer.new()
	_basic_container.add_theme_constant_override("separation", 6)
	body.add_child(_basic_container)

	_hud_container = VBoxContainer.new()
	_hud_container.add_theme_constant_override("separation", 6)
	_hud_container.visible = false
	body.add_child(_hud_container)

	_build_basic_tab()
	_build_hud_tab()

	_switch_tab(0)

func _build_tabs_header() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)

	var tab_names := ["⚙ " + tr("Cài Đặt Cơ Bản"), "🎨 " + tr("Giao Diện Gameplay")]
	for i in tab_names.size():
		var btn := GameUi.button(tab_names[i], GameUi.TAB)
		btn.custom_minimum_size.y = 34
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch_tab.bind(i))
		tabs.add_child(btn)
		_tab_buttons.append(btn)

	body.add_child(SocialUi.divider())

func _switch_tab(index: int) -> void:
	for i in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[i], i == index)
	_basic_container.visible = (index == 0)
	_hud_container.visible = (index == 1)

func _build_basic_tab() -> void:
	# Âm thanh
	_audio_label = SocialUi.label(tr("Âm thanh"), SocialUi.SUBTITLE)
	_basic_container.add_child(_audio_label)

	_music = _check(tr("Nhạc nền"), MusicManager.enabled, _basic_container)
	_music.toggled.connect(_on_music_toggled)

	var music_vol_row := HBoxContainer.new()
	music_vol_row.add_theme_constant_override("separation", 8)
	_basic_container.add_child(music_vol_row)

	_music_vol_label = SocialUi.label(tr("Âm lượng nhạc"))
	_music_vol_label.custom_minimum_size.x = 135
	music_vol_row.add_child(_music_vol_label)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 100.0
	_music_slider.step = 1.0
	_music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_music_slider.focus_mode = Control.FOCUS_NONE
	_music_slider.value = roundi(MusicManager.volume * 100.0)
	music_vol_row.add_child(_music_slider)

	_music_val_label = SocialUi.label("%d%%" % int(_music_slider.value), SocialUi.GOLD)
	_music_val_label.custom_minimum_size.x = 48
	music_vol_row.add_child(_music_val_label)
	_music_slider.value_changed.connect(_on_music_volume_slider_changed)

	_sfx = _check(tr("Hiệu ứng âm thanh"), SfxManager.enabled, _basic_container)
	_sfx.toggled.connect(_on_sfx_toggled)

	var sfx_vol_row := HBoxContainer.new()
	sfx_vol_row.add_theme_constant_override("separation", 8)
	_basic_container.add_child(sfx_vol_row)

	_sfx_vol_label = SocialUi.label(tr("Âm lượng hiệu ứng"))
	_sfx_vol_label.custom_minimum_size.x = 135
	sfx_vol_row.add_child(_sfx_vol_label)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 100.0
	_sfx_slider.step = 1.0
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sfx_slider.focus_mode = Control.FOCUS_NONE
	_sfx_slider.value = roundi(SfxManager.volume * 100.0)
	sfx_vol_row.add_child(_sfx_slider)

	_sfx_val_label = SocialUi.label("%d%%" % int(_sfx_slider.value), SocialUi.GOLD)
	_sfx_val_label.custom_minimum_size.x = 48
	sfx_vol_row.add_child(_sfx_val_label)
	_sfx_slider.value_changed.connect(_on_sfx_volume_slider_changed)
	_sfx_slider.drag_ended.connect(_on_sfx_drag_ended)

	_sync_audio_controls()

	_basic_container.add_child(SocialUi.divider())

	# Đổi ngôn ngữ
	_lang_section_label = SocialUi.label(tr("Ngôn ngữ"), SocialUi.SUBTITLE)
	_basic_container.add_child(_lang_section_label)

	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	_basic_container.add_child(lang_row)

	_lang_row_label = SocialUi.label(tr("Ngôn ngữ giao diện"))
	_lang_row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lang_row_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lang_row.add_child(_lang_row_label)

	_lang_option = OptionButton.new()
	_lang_option.focus_mode = Control.FOCUS_NONE
	_lang_option.custom_minimum_size = Vector2(230, 36)
	_lang_option.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var cur_locale := GameSettings.locale()
	var langs: Array[Dictionary] = []
	if LocalizationManager != null and LocalizationManager.has_method("get_supported_languages"):
		langs = LocalizationManager.get_supported_languages()

	if langs.is_empty():
		langs = [
			{"code": "vi", "display": "🇻🇳 Tiếng Việt"},
			{"code": "en", "display": "🇬🇧 English (Tiếng Anh)"},
			{"code": "ja", "display": "🇯🇵 日本語 (Tiếng Nhật)"},
			{"code": "ko", "display": "🇰🇷 한국어 (Tiếng Hàn)"},
			{"code": "ru", "display": "🇷🇺 Русский (Tiếng Nga)"},
			{"code": "fr", "display": "🇫🇷 Français (Tiếng Pháp)"},
			{"code": "th", "display": "🇹🇭 ภาษาไทย (Tiếng Thái)"},
			{"code": "zh", "display": "🇨🇳 简体中文 (Tiếng Trung)"}
		]

	var selected_idx := 0
	for i in langs.size():
		var l: Dictionary = langs[i]
		var code: String = str(l.get("code", "vi"))
		var display: String = str(l.get("display", l.get("name", code)))
		_lang_option.add_item(display, i)
		_lang_option.set_item_metadata(i, code)
		if code == cur_locale:
			selected_idx = i

	_lang_option.select(selected_idx)
	_lang_option.item_selected.connect(_on_language_selected)
	lang_row.add_child(_lang_option)

	_basic_container.add_child(SocialUi.divider())

	# Camera
	_camera_label = SocialUi.label(tr("Camera"), SocialUi.SUBTITLE)
	_basic_container.add_child(_camera_label)
	_wheel_zoom_check = _check(tr("Lăn chuột để zoom camera"), GameSettings.wheel_zoom(), _basic_container)
	_wheel_zoom_check.toggled.connect(GameSettings.set_wheel_zoom)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_basic_container.add_child(row)
	_zoom_label = SocialUi.label(tr("Mức zoom"))
	row.add_child(_zoom_label)
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

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_basic_container.add_child(buttons)

	_reset_zoom_btn = SocialUi.stone_button(tr("Zoom mặc định"))
	_reset_zoom_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_zoom_btn.pressed.connect(func() -> void: _zoom_slider.value = GameSettings.DEFAULT_ZOOM)
	buttons.add_child(_reset_zoom_btn)

	_close_btn = SocialUi.stone_button(tr("Đóng"))
	_close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_btn.pressed.connect(func() -> void: close_requested.emit())
	buttons.add_child(_close_btn)

	if _is_hub:
		_build_hub_system_section()

func _on_language_selected(index: int) -> void:
	var code: String = str(_lang_option.get_item_metadata(index))
	if code.is_empty():
		return
	GameSettings.set_locale(code)
	_refresh_texts()

## Cập nhật toàn bộ nhãn chữ trên giao diện ngay khi đổi ngôn ngữ
func _refresh_texts() -> void:
	if title_label != null:
		title_label.text = tr("Cài Đặt")

	if _tab_buttons.size() >= 2:
		_tab_buttons[0].text = "⚙ " + tr("Cài Đặt Cơ Bản")
		_tab_buttons[1].text = "🎨 " + tr("Giao Diện Gameplay")

	if _audio_label != null:
		_audio_label.text = tr("Âm thanh")
	if _music != null:
		_music.text = tr("Nhạc nền")
	if _music_vol_label != null:
		_music_vol_label.text = tr("Âm lượng nhạc")
	if _sfx != null:
		_sfx.text = tr("Hiệu ứng âm thanh")
	if _sfx_vol_label != null:
		_sfx_vol_label.text = tr("Âm lượng hiệu ứng")

	if _lang_section_label != null:
		_lang_section_label.text = tr("Ngôn ngữ")
	if _lang_row_label != null:
		_lang_row_label.text = tr("Ngôn ngữ giao diện")

	if _camera_label != null:
		_camera_label.text = tr("Camera")
	if _wheel_zoom_check != null:
		_wheel_zoom_check.text = tr("Lăn chuột để zoom camera")
	if _zoom_label != null:
		_zoom_label.text = tr("Mức zoom")
	if _reset_zoom_btn != null:
		_reset_zoom_btn.text = tr("Zoom mặc định")
	if _close_btn != null:
		_close_btn.text = tr("Đóng")
	if _exit_hub_btn != null:
		_exit_hub_btn.text = tr("Thoát về Character Hub")

	if _sys_label != null:
		_sys_label.text = tr("Hệ thống")
	if _char_btn != null:
		_char_btn.text = tr("Trở Về Chọn Nhân Vật")
	if _server_btn != null:
		_server_btn.text = tr("Trở Về Chọn Server")
	if _quit_btn != null:
		_quit_btn.text = tr("Thoát Game")

	if _hud_title_lbl != null:
		_hud_title_lbl.text = tr("🎨 TÙY CHỈNH BỐ CỤC GIAO DIỆN TRỰC QUAN")
	if _hud_desc_lbl != null:
		_hud_desc_lbl.text = tr("Bạn có thể chạm và kéo thả tự do từng nút kỹ năng (đánh chính, chiêu 1-8, thi triển liên tục), nút ngồi thiền, cưỡi ngựa, nhảy/khinh công, nút auto, cấu hình auto (⚙), trạng thái chiến đấu / luyện công (PK), khung chat, minimap... trực tiếp ngay trên màn hình game.")
	if _hud_tip_lbl != null:
		_hud_tip_lbl.text = tr("💡 Lưu ý: Bố cục sau khi kéo thả sẽ được tự động lưu trực tiếp vào thiết bị của bạn.")
	if _btn_visual != null:
		_btn_visual.text = tr("🎨 Chế Độ Kéo Thả Trực Quan Trên Màn Hình")
	if _reset_all_btn != null:
		_reset_all_btn.text = tr("↺ Khôi Phục Toàn Bộ Mặc Định")
	if _hud_close_btn != null:
		_hud_close_btn.text = tr("Đóng")

func _build_hud_tab() -> void:
	var info_panel := PanelContainer.new()
	var info_sb := StyleBoxFlat.new()
	info_sb.bg_color = Color(0.04, 0.14, 0.09, 0.92)
	info_sb.border_color = Color(0.24, 0.82, 0.48, 0.75)
	info_sb.set_border_width_all(1)
	info_sb.set_corner_radius_all(8)
	info_sb.content_margin_left = 16
	info_sb.content_margin_right = 16
	info_sb.content_margin_top = 16
	info_sb.content_margin_bottom = 16
	info_panel.add_theme_stylebox_override("panel", info_sb)
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_container.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	info_panel.add_child(info_vbox)

	_hud_title_lbl = Label.new()
	_hud_title_lbl.text = tr("🎨 TÙY CHỈNH BỐ CỤC GIAO DIỆN TRỰC QUAN")
	_hud_title_lbl.add_theme_font_size_override("font_size", 14)
	_hud_title_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	info_vbox.add_child(_hud_title_lbl)

	_hud_desc_lbl = Label.new()
	_hud_desc_lbl.text = tr("Bạn có thể chạm và kéo thả tự do từng nút kỹ năng (đánh chính, chiêu 1-8, thi triển liên tục), nút ngồi thiền, cưỡi ngựa, nhảy/khinh công, nút auto, cấu hình auto (⚙), trạng thái chiến đấu / luyện công (PK), khung chat, minimap... trực tiếp ngay trên màn hình game.")
	_hud_desc_lbl.add_theme_font_size_override("font_size", 12)
	_hud_desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88))
	_hud_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_vbox.add_child(_hud_desc_lbl)

	_hud_tip_lbl = Label.new()
	_hud_tip_lbl.text = tr("💡 Lưu ý: Bố cục sau khi kéo thả sẽ được tự động lưu trực tiếp vào thiết bị của bạn.")
	_hud_tip_lbl.add_theme_font_size_override("font_size", 11)
	_hud_tip_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	_hud_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_vbox.add_child(_hud_tip_lbl)

	_btn_visual = SocialUi.stone_button(tr("🎨 Chế Độ Kéo Thả Trực Quan Trên Màn Hình"))
	_btn_visual.custom_minimum_size.y = 48
	_btn_visual.pressed.connect(_on_open_visual_editor)
	_hud_container.add_child(_btn_visual)

	_hud_container.add_child(SocialUi.divider())

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	_hud_container.add_child(bottom_row)

	_reset_all_btn = SocialUi.stone_button(tr("↺ Khôi Phục Toàn Bộ Mặc Định"))
	_reset_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_all_btn.custom_minimum_size.y = 38
	_reset_all_btn.pressed.connect(_on_reset_all_hud)
	bottom_row.add_child(_reset_all_btn)

	_hud_close_btn = SocialUi.stone_button(tr("Đóng"))
	_hud_close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_close_btn.custom_minimum_size.y = 38
	_hud_close_btn.pressed.connect(func() -> void: close_requested.emit())
	bottom_row.add_child(_hud_close_btn)

func _on_reset_all_hud() -> void:
	SocialWindow.confirm(self, tr("Khôi Phục Giao Diện"), tr("Khôi phục toàn bộ vị trí & kích thước các nút về mặc định?"), func() -> void:
		HudLayout.reset_all()
	)

func _on_open_visual_editor() -> void:
	var cur_scene := get_tree().current_scene
	if _is_hub or cur_scene == null or cur_scene.name == "CharacterHub" or not cur_scene.has_node("UI/SkillBarUI"):
		SocialWindow.info(self, tr("Thông Báo"), tr("Vui lòng vào màn chơi chính thức để mở giao diện chỉnh sửa bố cục trực quan!"))
		return
	visible = false
	var ed := HudLayoutEditor.open(cur_scene)
	ed.finished.connect(func() -> void:
		visible = true)

func _build_hub_system_section() -> void:
	if _sys_container != null:
		return
	_basic_container.add_child(SocialUi.divider())
	_sys_label = SocialUi.label(tr("Hệ thống"), SocialUi.SUBTITLE)
	_basic_container.add_child(_sys_label)

	var sys_buttons := HBoxContainer.new()
	sys_buttons.add_theme_constant_override("separation", 8)
	_basic_container.add_child(sys_buttons)
	_sys_container = sys_buttons

	_char_btn = SocialUi.stone_button(tr("Trở Về Chọn Nhân Vật"))
	_char_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_btn.pressed.connect(_on_character_select_clicked)
	sys_buttons.add_child(_char_btn)

	_server_btn = SocialUi.stone_button(tr("Trở Về Chọn Server"))
	_server_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_btn.pressed.connect(_on_server_select_clicked)
	sys_buttons.add_child(_server_btn)

	var quit_row := HBoxContainer.new()
	quit_row.add_theme_constant_override("separation", 8)
	_basic_container.add_child(quit_row)
	_quit_btn = SocialUi.stone_button(tr("Thoát Game"))
	_quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quit_btn.pressed.connect(_on_quit_game_clicked)
	quit_row.add_child(_quit_btn)

func setup_hub_actions(p_on_server: Callable = Callable(), p_on_quit: Callable = Callable(), p_on_character: Callable = Callable()) -> void:
	on_server_select = p_on_server
	on_quit_game = p_on_quit
	on_character_select = p_on_character
	_build_hub_system_section()

func _on_character_select_clicked() -> void:
	if on_character_select.is_valid():
		on_character_select.call()
		return
	SocialWindow.confirm(self, tr("Chọn Nhân Vật"), tr("Lưu dữ liệu và trở về màn hình chọn nhân vật?"), func() -> void:
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
	SocialWindow.confirm(self, tr("Chọn Máy Chủ"), tr("Lưu dữ liệu và trở về màn hình chọn máy chủ?"), func() -> void:
		if GameManager.local_profile != null:
			SaveManager.save_profile(GameManager.local_profile)
			await SaveManager.flush_online()
		get_tree().change_scene_to_file("res://ui/server_select/ServerSelect.tscn")
	)

func _on_quit_game_clicked() -> void:
	if on_quit_game.is_valid():
		on_quit_game.call()
		return
	SocialWindow.confirm(self, tr("Thoát Game"), tr("Lưu dữ liệu và thoát khỏi trò chơi?"), func() -> void:
		if GameManager.local_profile != null:
			SaveManager.save_profile(GameManager.local_profile)
			await SaveManager.flush_online()
		get_tree().quit()
	)

func _ready() -> void:
	super._ready()
	_player = get_tree().get_first_node_in_group("player")
	MusicManager.enabled_changed.connect(_on_music_changed)
	MusicManager.volume_changed.connect(_on_music_vol_changed)
	SfxManager.enabled_changed.connect(_on_sfx_changed)
	SfxManager.volume_changed.connect(_on_sfx_vol_changed)
	if LocalizationManager != null and LocalizationManager.has_signal("locale_changed"):
		LocalizationManager.locale_changed.connect(_on_global_locale_changed)

func _exit_tree() -> void:
	if MusicManager.enabled_changed.is_connected(_on_music_changed):
		MusicManager.enabled_changed.disconnect(_on_music_changed)
	if MusicManager.volume_changed.is_connected(_on_music_vol_changed):
		MusicManager.volume_changed.disconnect(_on_music_vol_changed)
	if SfxManager.enabled_changed.is_connected(_on_sfx_changed):
		SfxManager.enabled_changed.disconnect(_on_sfx_changed)
	if SfxManager.volume_changed.is_connected(_on_sfx_vol_changed):
		SfxManager.volume_changed.disconnect(_on_sfx_vol_changed)
	if LocalizationManager != null and LocalizationManager.has_signal("locale_changed") and LocalizationManager.locale_changed.is_connected(_on_global_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_global_locale_changed)

func _on_global_locale_changed(code: String) -> void:
	if _lang_option != null:
		for i in _lang_option.item_count:
			if _lang_option.get_item_metadata(i) == code:
				_lang_option.select(i)
				break
	_refresh_texts()

func _check(text: String, on: bool, parent: Control = null) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_color_override("button_checked_color", Color(0.96, 0.78, 0.22))
	if parent != null:
		parent.add_child(c)
	else:
		body.add_child(c)
	return c

func _on_music_toggled(on: bool) -> void:
	MusicManager.enabled = on
	if on and MusicManager.volume <= 0.0:
		MusicManager.volume = 1.0
	_sync_audio_controls()

func _on_music_volume_slider_changed(val: float) -> void:
	var v := val / 100.0
	MusicManager.volume = v
	if _music_val_label != null:
		_music_val_label.text = "%d%%" % int(val)
	if val > 0.0 and not MusicManager.enabled:
		MusicManager.enabled = true
	_sync_audio_controls()

func _on_sfx_toggled(on: bool) -> void:
	SfxManager.enabled = on
	if on and SfxManager.volume <= 0.0:
		SfxManager.volume = 1.0
	_sync_audio_controls()

func _on_sfx_volume_slider_changed(val: float) -> void:
	var v := val / 100.0
	SfxManager.volume = v
	if _sfx_val_label != null:
		_sfx_val_label.text = "%d%%" % int(val)
	if val > 0.0 and not SfxManager.enabled:
		SfxManager.enabled = true
	_sync_audio_controls()

func _on_sfx_drag_ended(value_changed: bool) -> void:
	if SfxManager.enabled and value_changed:
		SfxManager.play_ui(VltkSound.ui(VltkSound.UI_SELECT))

func _sync_audio_controls() -> void:
	if _music != null:
		_music.set_pressed_no_signal(MusicManager.enabled)
	if _music_slider != null:
		_music_slider.modulate = Color.WHITE if MusicManager.enabled else Color(0.65, 0.65, 0.65, 0.6)
	if _sfx != null:
		_sfx.set_pressed_no_signal(SfxManager.enabled)
	if _sfx_slider != null:
		_sfx_slider.modulate = Color.WHITE if SfxManager.enabled else Color(0.65, 0.65, 0.65, 0.6)

func _on_music_changed(on: bool) -> void:
	_sync_audio_controls()

func _on_music_vol_changed(vol: float) -> void:
	if _music_slider != null:
		_music_slider.set_value_no_signal(roundi(vol * 100.0))
	if _music_val_label != null:
		_music_val_label.text = "%d%%" % roundi(vol * 100.0)

func _on_sfx_changed(on: bool) -> void:
	_sync_audio_controls()

func _on_sfx_vol_changed(vol: float) -> void:
	if _sfx_slider != null:
		_sfx_slider.set_value_no_signal(roundi(vol * 100.0))
	if _sfx_val_label != null:
		_sfx_val_label.text = "%d%%" % roundi(vol * 100.0)

func _on_zoom_changed(z: float) -> void:
	_show_zoom(z)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_camera_zoom"):
		_player.set_camera_zoom(z)
	else:
		GameSettings.set_camera_zoom(z)

func _show_zoom(z: float) -> void:
	_zoom_value.text = "x%.2f" % z

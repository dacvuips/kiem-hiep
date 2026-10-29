extends Control
class_name ModeSelectScreen
## Màn hình Lựa Chọn Chế Độ Chơi: Chơi Offline (với Bot) hoặc Chơi Online (với người thật).
## Xuất hiện ngay sau khi launcher tải và kiểm tra xong tiến trình của game.

const LOGIN_SCENE := "res://ui/login/Login.tscn"
const CHARACTER_SELECT_SCENE := "res://ui/character_select/CharacterSelect.tscn"
const CHARACTER_HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"

const COLOR_GOLD := Color(0.98, 0.86, 0.52, 1.0)
const COLOR_GOLD_BORDER := Color(0.92, 0.78, 0.45, 1.0)
const COLOR_OFFLINE_ACCENT := Color(0.22, 0.85, 0.65, 1.0)
const COLOR_ONLINE_ACCENT := Color(1.0, 0.65, 0.15, 1.0)

@onready var _card_offline: PanelContainer = %CardOffline
@onready var _card_online: PanelContainer = %CardOnline
@onready var _btn_offline: Button = %BtnOffline
@onready var _btn_online: Button = %BtnOnline
@onready var _btn_quit: Button = %BtnQuit
@onready var _network_indicator: ColorRect = %NetworkIndicator
@onready var _network_status_label: Label = %NetworkStatusLabel
var _net_check_req: HTTPRequest = null
@onready var _dialog_overlay: ColorRect = %DialogOverlay
@onready var _dialog_box: PanelContainer = %DialogBox
@onready var _btn_dialog_offline: Button = %BtnDialogOffline
@onready var _btn_dialog_retry: Button = %BtnDialogRetry
@onready var _btn_dialog_close: Button = %BtnDialogClose

var _is_online_available: bool = false
var _checking_network: bool = false
var _hovered_card: PanelContainer = null
var _lang_btn: OptionButton = null
var _current_network_text := "Đang kiểm tra kết nối mạng..."

func _ready() -> void:
	MusicManager.play_title_music()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)

	_setup_card_events(_card_offline, _btn_offline, Callable(self, "_on_select_offline"))
	_setup_card_events(_card_online, _btn_online, Callable(self, "_on_select_online"))

	if _btn_quit:
		_btn_quit.pressed.connect(func() -> void: get_tree().quit())

	_setup_dialog()
	_setup_language_selector()
	_update_locale_texts()
	_check_internet_connection()

	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		loc_mgr.locale_changed.connect(func(_new_loc: String) -> void:
			_update_locale_texts()
			_populate_language_options()
		)

	for arg in OS.get_cmdline_args():
		if arg == "--capture-mode-select":
			_test_capture.call_deferred()
			break

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_inside_tree() and is_node_ready():
			_update_locale_texts()
			_populate_language_options()

func _setup_language_selector() -> void:
	var footer: Control = get_node_or_null("Stage/FooterBar")
	if footer == null:
		return
	_lang_btn = OptionButton.new()
	_lang_btn.name = "LanguageSelector"
	_lang_btn.custom_minimum_size = Vector2(200, 38)
	_lang_btn.anchors_preset = Control.PRESET_CENTER_RIGHT
	_lang_btn.anchor_left = 1.0
	_lang_btn.anchor_top = 0.5
	_lang_btn.anchor_right = 1.0
	_lang_btn.anchor_bottom = 0.5
	_lang_btn.offset_left = -260.0
	_lang_btn.offset_top = -19.0
	_lang_btn.offset_right = -60.0
	_lang_btn.offset_bottom = 19.0
	_lang_btn.focus_mode = Control.FOCUS_NONE
	_lang_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_lang_btn.add_theme_font_override("font", preload("res://assets/fonts/BeVietnamPro-Regular.ttf"))
	_lang_btn.add_theme_font_size_override("font_size", 13)
	_lang_btn.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	_lang_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))

	if has_node("%BtnQuit"):
		var quit_btn: Button = %BtnQuit
		var norm_sb := quit_btn.get_theme_stylebox("normal")
		var hov_sb := quit_btn.get_theme_stylebox("hover")
		if norm_sb:
			_lang_btn.add_theme_stylebox_override("normal", norm_sb)
		if hov_sb:
			_lang_btn.add_theme_stylebox_override("hover", hov_sb)
			_lang_btn.add_theme_stylebox_override("pressed", hov_sb)

	_populate_language_options()
	_lang_btn.item_selected.connect(_on_language_selected)
	footer.add_child(_lang_btn)

func _populate_language_options() -> void:
	if _lang_btn == null:
		return
	_lang_btn.clear()
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager")
	var current := "vi"
	if loc_mgr and loc_mgr.has_method("get_locale"):
		current = loc_mgr.get_locale()
	elif TranslationServer.get_locale() != "":
		current = TranslationServer.get_locale()

	var sel_idx := 0
	if loc_mgr and "SUPPORTED_LANGUAGES" in loc_mgr:
		var langs: Array = loc_mgr.SUPPORTED_LANGUAGES
		for i in langs.size():
			var lang: Dictionary = langs[i]
			var code: String = str(lang.get("code", ""))
			var disp: String = str(lang.get("display", lang.get("name", code)))
			_lang_btn.add_item("🌐 " + disp, i)
			_lang_btn.set_item_metadata(i, code)
			if code == current:
				sel_idx = i
	_lang_btn.select(sel_idx)

func _on_language_selected(index: int) -> void:
	var code: String = str(_lang_btn.get_item_metadata(index))
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager")
	if loc_mgr and loc_mgr.has_method("set_locale"):
		loc_mgr.set_locale(code, true)
	else:
		TranslationServer.set_locale(code)
	_update_locale_texts()

func _update_locale_texts() -> void:
	if not is_inside_tree() or not is_node_ready():
		return
	var title_lbl: Label = get_node_or_null("Stage/HeaderBar/TitleBox/Title")
	if title_lbl:
		title_lbl.text = tr("CHỌN CHẾ ĐỘ BÔN TẨU GIANG HỒ")
	var sub_lbl: Label = get_node_or_null("Stage/HeaderBar/TitleBox/Subtitle")
	if sub_lbl:
		sub_lbl.text = tr("Võ Lâm Truyền Kỳ • JX1 Idle Origin")

	if _network_status_label:
		_network_status_label.text = tr(_current_network_text)

	# Card Offline
	var badge_off: Label = get_node_or_null("Stage/CardsContainer/CardOffline/Margin/Content/BadgeBox/BadgeOffline")
	if badge_off:
		badge_off.text = tr("KHÔNG CẦN INTERNET")
	var title_off: Label = get_node_or_null("Stage/CardsContainer/CardOffline/Margin/Content/Title")
	if title_off:
		title_off.text = tr("CHẾ ĐỘ OFFLINE")
	var sub_off: Label = get_node_or_null("Stage/CardsContainer/CardOffline/Margin/Content/Subtitle")
	if sub_off:
		sub_off.text = tr("Độc Hành Giang Hồ • Luyện Võ Cùng Bot Giả Lập")

	var item1_off: Label = get_node_or_null("Stage/CardsContainer/CardOffline/Margin/Content/FeaturesList/Item1")
	if item1_off:
		item1_off.text = tr("🗡️  Chiến Đấu Cùng Bot AI Thông Minh\n     Đấu trường PK, tỉ võ, săn quái mượt mà không lo giật lag")
	var item2_off: Label = get_node_or_null("Stage/CardsContainer/CardOffline/Margin/Content/FeaturesList/Item2")
	if item2_off:
		item2_off.text = tr("📶  Chơi Mọi Lúc Mọi Nơi\n     Hoàn toàn không cần kết nối mạng hoặc khi mạng chập chờn")
	var item3_off: Label = get_node_or_null("Stage/CardsContainer/CardOffline/Margin/Content/FeaturesList/Item3")
	if item3_off:
		item3_off.text = tr("💾  Tiến Trình Lưu Trực Tiếp Trên Máy\n     Dữ liệu nhân vật, trang bị, bí kíp được lưu bảo mật trong thiết bị")
	var item4_off: Label = get_node_or_null("Stage/CardsContainer/CardOffline/Margin/Content/FeaturesList/Item4")
	if item4_off:
		item4_off.text = tr("🗺️  Tự Do Khám Phá & Luyện Công\n     Trải nghiệm trọn vẹn 10 môn phái, hệ thống kỹ năng & vượt ải")
	if _btn_offline:
		_btn_offline.text = tr("BẮT ĐẦU CHƠI OFFLINE")

	# Card Online
	var badge_on: Label = get_node_or_null("Stage/CardsContainer/CardOnline/Margin/Content/BadgeBox/BadgeOnline")
	if badge_on:
		badge_on.text = tr("CẦN KẾT NỐI MẠNG")
	var title_on: Label = get_node_or_null("Stage/CardsContainer/CardOnline/Margin/Content/Title")
	if title_on:
		title_on.text = tr("CHẾ ĐỘ ONLINE")
	var sub_on: Label = get_node_or_null("Stage/CardsContainer/CardOnline/Margin/Content/Subtitle")
	if sub_on:
		sub_on.text = tr("Chiến Trường Giang Hồ • Tương Tác Người Chơi Thật")

	var item1_on: Label = get_node_or_null("Stage/CardsContainer/CardOnline/Margin/Content/FeaturesList/Item1")
	if item1_on:
		item1_on.text = tr("👥  Hội Tụ Hiệp Khách Bốn Phương\n     Giao lưu, kết nghĩa huynh đệ, bang hội cùng người chơi thật")
	var item2_on: Label = get_node_or_null("Stage/CardsContainer/CardOnline/Margin/Content/FeaturesList/Item2")
	if item2_on:
		item2_on.text = tr("🏰  Chiến Trường Tống Kim Rực Lửa\n     Đại chiến ngàn người, săn Boss Hoàng Kim, Lôi Đài thời gian thực")
	var item3_on: Label = get_node_or_null("Stage/CardsContainer/CardOnline/Margin/Content/FeaturesList/Item3")
	if item3_on:
		item3_on.text = tr("🏪  Giao Dịch Tự Do & Thương Hội\n     Bày bán trực tiếp, trao đổi bảo vật Kỳ Trân Các, đấu giá liên server")
	var item4_on: Label = get_node_or_null("Stage/CardsContainer/CardOnline/Margin/Content/FeaturesList/Item4")
	if item4_on:
		item4_on.text = tr("☁️  Lưu Trữ Đám Mây Toàn Diện\n     Tài khoản và hồ sơ nhân vật được đồng bộ và bảo vệ an toàn")
	if _btn_online:
		_btn_online.text = tr("ĐĂNG NHẬP CHƠI ONLINE")

	# Footer
	if _btn_quit:
		_btn_quit.text = tr("Thoát Game")
	var ver_lbl: Label = get_node_or_null("Stage/FooterBar/VersionLabel")
	if ver_lbl:
		ver_lbl.text = tr("JX1 Idle Origin • Phiên bản 1.0.0 • Hỗ trợ Đa Nền Tảng")

	# Dialog
	var diag_title: Label = get_node_or_null("Stage/DialogOverlay/DialogBox/Margin/VBox/DialogTitle")
	if diag_title:
		diag_title.text = tr("THÔNG BÁO KẾT NỐI MẠNG")
	var diag_msg: Label = get_node_or_null("Stage/DialogOverlay/DialogBox/Margin/VBox/DialogMsg")
	if diag_msg:
		diag_msg.text = tr("Không thể kết nối Internet hoặc Máy chủ Giang Hồ chưa phản hồi!\n\nChế độ Online yêu cầu mạng để chơi cùng người khác. Bạn có muốn chuyển sang chơi Chế độ Offline cùng Bot để trải nghiệm ngay không?")
	if _btn_dialog_offline:
		_btn_dialog_offline.text = tr("Chơi Offline Luôn")
	if _btn_dialog_retry:
		_btn_dialog_retry.text = tr("Thử Lại Mạng")
	if _btn_dialog_close:
		_btn_dialog_close.text = tr("Đóng")

func _test_capture() -> void:
	await get_tree().create_timer(0.8).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/ae842886-9ea4-4c6c-85d0-15a1d919b1cf/mode_select_preview.png")
		print("MODE_SELECT_CAPTURE_SUCCESS")
	get_tree().quit()

func _setup_card_events(card: PanelContainer, button: Button, on_click: Callable) -> void:
	if button:
		button.pressed.connect(on_click)
		button.mouse_entered.connect(_on_card_hover.bind(card, true))
		button.mouse_exited.connect(_on_card_hover.bind(card, false))

	if card:
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				on_click.call()
		)
		card.mouse_entered.connect(_on_card_hover.bind(card, true))
		card.mouse_exited.connect(_on_card_hover.bind(card, false))

func _on_card_hover(card: PanelContainer, is_hover: bool) -> void:
	if not is_instance_valid(card):
		return
	var target_scale := Vector2(1.025, 1.025) if is_hover else Vector2(1.0, 1.0)
	var tween := card.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", target_scale, 0.18)

func _check_internet_connection() -> void:
	if _checking_network:
		return
	_checking_network = true
	_update_network_ui(false, "Đang kiểm tra kết nối mạng...")

	var url := "https://kiem-hiep-api.viettheo.site/v1/client/manifest"
	if AccountApi and AccountApi.base_url != "":
		url = AccountApi.base_url + "/v1/client/manifest"

	if _net_check_req == null:
		_net_check_req = HTTPRequest.new()
		_net_check_req.name = "NetCheckRequest"
		add_child(_net_check_req)

	_net_check_req.timeout = 5.0
	var err := _net_check_req.request(url)
	if err != OK:
		_checking_network = false
		_is_online_available = false
		_update_network_ui(false, "Không có kết nối Internet (Chỉ Offline)")
		return

	var res: Array = await _net_check_req.request_completed
	_checking_network = false
	var result_code := int(res[0])
	var http_code := int(res[1])

	# Nếu kết nối thành công hoặc nhận được phản hồi HTTP từ server
	if result_code == HTTPRequest.RESULT_SUCCESS or http_code > 0:
		_is_online_available = true
		_update_network_ui(true, "Mạng trực tuyến: Sẵn sàng kết nối")
	else:
		_is_online_available = false
		_update_network_ui(false, "Không có kết nối Internet (Chỉ Offline)")

func _update_network_ui(online: bool, text: String) -> void:
	_current_network_text = text
	if _network_status_label:
		_network_status_label.text = tr(text)
	if _network_indicator:
		_network_indicator.color = Color(0.2, 0.85, 0.4) if online else Color(0.85, 0.3, 0.25)

func _on_select_offline() -> void:
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)
	print("ModeSelect: Đã chọn chế độ OFFLINE (Chơi độc lập, không cần mạng)")
	_transition_to_offline()

func _on_select_online() -> void:
	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	print("ModeSelect: Đã chọn chế độ ONLINE (Người chơi thật, cần mạng Internet, không có bot)")

	if not _is_online_available:
		_show_no_network_dialog()
		return

	_transition_to_online()

func _transition_to_offline() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		# Nếu đã có nhân vật lưu trên máy -> vào thẳng CharacterHub, ngược lại vào CharacterSelect
		if GameManager.local_profile == null and SaveManager.has_profile():
			GameManager.local_profile = SaveManager.load_profile()
		
		if GameManager.local_profile != null:
			get_tree().change_scene_to_file(CHARACTER_HUB_SCENE)
		else:
			get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
	)

func _transition_to_online() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(LOGIN_SCENE)
	)

func _setup_dialog() -> void:
	if _dialog_overlay:
		_dialog_overlay.visible = false
	if _btn_dialog_offline:
		_btn_dialog_offline.pressed.connect(func() -> void:
			_dialog_overlay.visible = false
			_on_select_offline()
		)
	if _btn_dialog_retry:
		_btn_dialog_retry.pressed.connect(func() -> void:
			_dialog_overlay.visible = false
			_check_internet_connection()
		)
	if _btn_dialog_close:
		_btn_dialog_close.pressed.connect(func() -> void:
			_dialog_overlay.visible = false
		)

func _show_no_network_dialog() -> void:
	if _dialog_overlay:
		_dialog_overlay.visible = true
		_dialog_overlay.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_dialog_overlay, "modulate:a", 1.0, 0.2)

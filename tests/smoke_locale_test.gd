extends Node

func _ready() -> void:
	print("=== SMOKE TEST: Localization & Settings Window ===")
	
	# Verify LocalizationManager
	var lm = get_node_or_null("/root/LocalizationManager")
	if lm == null:
		print("FAIL: LocalizationManager autoload not found!")
		get_tree().quit(1)
		return
	print("PASS: LocalizationManager autoload loaded.")

	# Verify languages
	var langs: Array[Dictionary] = lm.get_supported_languages()
	print("PASS: Supported languages count: ", langs.size())
	for l in langs:
		print("  - ", l.code, ": ", l.display)

	# Verify default locale
	print("PASS: Initial locale: ", GameSettings.locale())

	# Test switching locales and tr() results
	var test_locales := ["vi", "en", "ja", "ko", "ru", "fr", "th", "zh"]
	for loc in test_locales:
		GameSettings.set_locale(loc)
		var tr_title := tr("Cài Đặt")
		var tr_audio := tr("Âm thanh")
		var tr_lang := tr("Ngôn ngữ")
		print("[%s] Cài Đặt: '%s' | Âm thanh: '%s' | Ngôn ngữ: '%s'" % [loc, tr_title, tr_audio, tr_lang])

	# Reset to vi
	GameSettings.set_locale("vi")

	# Test SettingsWindow creation
	print("Instantiating SettingsWindow(true)...")
	var win := SettingsWindow.new(true)
	add_child(win)
	print("PASS: SettingsWindow created. Title: ", win.title_label.text if win.title_label else "none")

	# Test selecting language in SettingsWindow
	print("Testing language option selection to 'en'...")
	win._lang_option.select(1)
	win._on_language_selected(1)
	print("PASS: en -> title: '", win.title_label.text if win.title_label else "none", "' | audio: '", win._audio_label.text, "' | lang: '", win._lang_row_label.text, "'")
	if win.title_label.text != "Settings" or win._audio_label.text != "Audio":
		print("FAIL: English texts not matching!")
		get_tree().quit(1)
		return

	# Test selecting language in SettingsWindow to 'ja'
	print("Testing language option selection to 'ja'...")
	win._lang_option.select(2)
	win._on_language_selected(2)
	print("PASS: ja -> title: '", win.title_label.text if win.title_label else "none", "' | audio: '", win._audio_label.text, "'")
	if win.title_label.text != "設定" or win._audio_label.text != "サウンド":
		print("FAIL: Japanese texts not matching!")
		get_tree().quit(1)
		return

	# Test selecting language in SettingsWindow to 'th'
	print("Testing language option selection to 'th'...")
	win._lang_option.select(6)
	win._on_language_selected(6)
	print("PASS: th -> title: '", win.title_label.text if win.title_label else "none", "' | audio: '", win._audio_label.text, "'")
	if win.title_label.text != "การตั้งค่า" or win._audio_label.text != "เสียง":
		print("FAIL: Thai texts not matching!")
		get_tree().quit(1)
		return

	# Test selecting language in SettingsWindow to 'ru'
	print("Testing language option selection to 'ru'...")
	win._lang_option.select(4)
	win._on_language_selected(4)
	print("PASS: ru -> title: '", win.title_label.text if win.title_label else "none", "' | audio: '", win._audio_label.text, "'")
	if win.title_label.text != "Настройки" or win._audio_label.text != "Звук":
		print("FAIL: Russian texts not matching!")
		get_tree().quit(1)
		return

	# Test selecting language in SettingsWindow to 'fr'
	print("Testing language option selection to 'fr'...")
	win._lang_option.select(5)
	win._on_language_selected(5)
	print("PASS: fr -> title: '", win.title_label.text if win.title_label else "none", "' | audio: '", win._audio_label.text, "'")
	if win.title_label.text != "Paramètres" or win._audio_label.text != "Audio":
		print("FAIL: French texts not matching!")
		get_tree().quit(1)
		return

	# Test selecting language in SettingsWindow to 'ko'
	print("Testing language option selection to 'ko'...")
	win._lang_option.select(3)
	win._on_language_selected(3)
	print("PASS: ko -> title: '", win.title_label.text if win.title_label else "none", "' | audio: '", win._audio_label.text, "'")
	if win.title_label.text != "설정" or win._audio_label.text != "오디오":
		print("FAIL: Korean texts not matching!")
		get_tree().quit(1)
		return

	# Reset to vi
	win._lang_option.select(0)
	win._on_language_selected(0)
	print("PASS: vi -> title: '", win.title_label.text if win.title_label else "none", "' | audio: '", win._audio_label.text, "'")

	# Cleanup
	win.queue_free()
	GameSettings.set_locale("vi")
	print("=== ALL LOCALIZATION & SETTINGS TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)

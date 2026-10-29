extends Node

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func _ready() -> void:
	print("=== START SMOKE STARTUP FLOW LOCALE TEST ===")
	await test_mode_select()
	await test_login()
	await test_server_select()
	await test_character_roster()
	await test_character_create()
	LocalizationManager.set_locale("vi")
	print("RESULT: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func test_mode_select() -> void:
	print("\n--- Test ModeSelect ---")
	var scene: Node = load("res://ui/mode_select/ModeSelect.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame

	var opt: OptionButton = scene.find_child("LanguageSelector", true, false) as OptionButton
	check("ModeSelect has LanguageSelector OptionButton", opt != null)
	if opt:
		check("LanguageSelector has 8 items", opt.item_count == 8, opt.item_count)

	var title_lbl: Label = scene.find_child("Title", true, false) as Label

	# Test English
	LocalizationManager.set_locale("en")
	await get_tree().process_frame
	check("ModeSelect Title in EN", title_lbl != null and title_lbl.text == "CHOOSE YOUR JOURNEY MODE", title_lbl.text if title_lbl else "")

	# Test Chinese
	LocalizationManager.set_locale("zh")
	await get_tree().process_frame
	check("ModeSelect Title in ZH", title_lbl != null and title_lbl.text == "选择江湖历练模式", title_lbl.text if title_lbl else "")

	# Test Vietnamese
	LocalizationManager.set_locale("vi")
	await get_tree().process_frame
	check("ModeSelect Title in VI", title_lbl != null and title_lbl.text == "CHỌN CHẾ ĐỘ BÔN TẨU GIANG HỒ", title_lbl.text if title_lbl else "")

	# Test selecting directly via OptionButton
	if opt and title_lbl:
		# Index 1 is English
		opt.select(1)
		opt.item_selected.emit(1)
		await get_tree().process_frame
		check("OptionButton switch to EN updates LocalizationManager", LocalizationManager.get_locale() == "en", LocalizationManager.get_locale())
		check("OptionButton switch to EN updates Title", title_lbl.text == "CHOOSE YOUR JOURNEY MODE", title_lbl.text)

		# Index 0 is Vietnamese
		opt.select(0)
		opt.item_selected.emit(0)
		await get_tree().process_frame
		check("OptionButton switch back to VI updates LocalizationManager", LocalizationManager.get_locale() == "vi", LocalizationManager.get_locale())
		check("OptionButton switch back to VI updates Title", title_lbl.text == "CHỌN CHẾ ĐỘ BÔN TẨU GIANG HỒ", title_lbl.text)

	scene.queue_free()
	await get_tree().process_frame

func test_login() -> void:
	print("\n--- Test Login ---")
	var scene: Node = load("res://ui/login/Login.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame

	var acc_input: LineEdit = scene.find_child("UserInput", true, false) as LineEdit
	var rem_check: CheckBox = scene.find_child("RememberCheck", true, false) as CheckBox
	check("Login inputs found", acc_input != null and rem_check != null)

	# Test English
	LocalizationManager.set_locale("en")
	await get_tree().process_frame
	if acc_input:
		check("Login placeholder in EN", acc_input.placeholder_text == "Account", acc_input.placeholder_text)
	if rem_check:
		check("Login remember in EN", rem_check.text == "Remember Account", rem_check.text)

	# Test Russian
	LocalizationManager.set_locale("ru")
	await get_tree().process_frame
	if acc_input:
		check("Login placeholder in RU", acc_input.placeholder_text == "Аккаунт", acc_input.placeholder_text)
	if rem_check:
		check("Login remember in RU", rem_check.text == "Запомнить аккаунт", rem_check.text)

	scene.queue_free()
	await get_tree().process_frame

func test_server_select() -> void:
	print("\n--- Test ServerSelect ---")
	var scene: Node = load("res://ui/server_select/ServerSelect.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame

	var title_lbl: Label = scene.find_child("Title", true, false) as Label
	var enter_btn: BaseButton = scene.find_child("EnterButton", true, false) as BaseButton
	check("ServerSelect nodes found", title_lbl != null and enter_btn != null)

	# Test Japanese
	LocalizationManager.set_locale("ja")
	await get_tree().process_frame
	if title_lbl:
		check("ServerSelect Title in JA", title_lbl.text == "サーバー選択", title_lbl.text)
	if enter_btn:
		var lbl: Label = scene.find_child("EnterLabel", true, false) as Label
		check("ServerSelect Enter Button in JA", lbl != null and lbl.text == "ゲーム開始", lbl.text if lbl else "")

	# Test French
	LocalizationManager.set_locale("fr")
	await get_tree().process_frame
	if title_lbl:
		check("ServerSelect Title in FR", title_lbl.text == "Choisir le serveur", title_lbl.text)

	scene.queue_free()
	await get_tree().process_frame

func test_character_roster() -> void:
	print("\n--- Test CharacterRoster ---")
	var scene: Node = load("res://ui/character_roster/CharacterRoster.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame

	var enter_btn: BaseButton = scene.find_child("EnterArea", true, false) as BaseButton
	var create_btn: BaseButton = scene.find_child("CreateArea", true, false) as BaseButton
	var cancel_btn: BaseButton = scene.find_child("CancelArea", true, false) as BaseButton
	var quit_btn: BaseButton = scene.find_child("QuitArea", true, false) as BaseButton

	check("CharacterRoster buttons found", enter_btn != null and create_btn != null and cancel_btn != null and quit_btn != null)

	# Test Korean
	LocalizationManager.set_locale("ko")
	await get_tree().process_frame
	if enter_btn:
		var lbl: Label = enter_btn.get_node_or_null("Label")
		check("CharacterRoster Enter Button in KO", lbl != null and lbl.text == "게임 시작", lbl.text if lbl else "")
	if create_btn:
		var lbl: Label = create_btn.get_node_or_null("Label")
		check("CharacterRoster Create Button in KO", lbl != null and lbl.text == "캐릭터 생성", lbl.text if lbl else "")

	# Test Thai
	LocalizationManager.set_locale("th")
	await get_tree().process_frame
	if cancel_btn:
		var lbl: Label = cancel_btn.get_node_or_null("Label")
		check("CharacterRoster Cancel Button in TH", lbl != null and lbl.text == "ย้อนกลับ", lbl.text if lbl else "")
	if quit_btn:
		var lbl: Label = quit_btn.get_node_or_null("Label")
		check("CharacterRoster Quit Button in TH", lbl != null and lbl.text == "ออกจากเกม", lbl.text if lbl else "")

	scene.queue_free()
	await get_tree().process_frame

func test_character_create() -> void:
	print("\n--- Test CharacterCreate ---")
	var scene: Node = load("res://ui/character_create/CharacterCreate.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame

	var create_btn: TextureButton = scene.find_child("CreateButton", true, false) as TextureButton
	var name_input: LineEdit = scene.find_child("NameInput", true, false) as LineEdit
	var back_btn: BaseButton = scene.find_child("BackButton", true, false) as BaseButton

	check("CharacterCreate elements found", create_btn != null and name_input != null and back_btn != null)

	# Test Russian
	LocalizationManager.set_locale("ru")
	await get_tree().process_frame
	if create_btn:
		var lbl: Label = create_btn.get_node_or_null("Label")
		check("CharacterCreate Create Button in RU", lbl != null and lbl.text == "СОЗДАТЬ ГЕРОЯ", lbl.text if lbl else "")
	if name_input:
		check("CharacterCreate Name placeholder in RU", name_input.placeholder_text == "Введите имя персонажа", name_input.placeholder_text)
	if back_btn:
		var lbl: Label = back_btn.get_node_or_null("Label")
		check("CharacterCreate Back Button in RU", lbl != null and lbl.text == "‹ НАЗАД", lbl.text if lbl else "")

	# Test Vietnamese
	LocalizationManager.set_locale("vi")
	await get_tree().process_frame
	if create_btn:
		var lbl: Label = create_btn.get_node_or_null("Label")
		check("CharacterCreate Create Button in VI", lbl != null and lbl.text == "TẠO NHÂN VẬT", lbl.text if lbl else "")
	if name_input:
		check("CharacterCreate Name placeholder in VI", name_input.placeholder_text == "Nhập tên nhân vật", name_input.placeholder_text)

	scene.queue_free()
	await get_tree().process_frame

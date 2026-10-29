extends Node

func _ready() -> void:
	print("=== TEST: CharacterHub Dynamic Localization ===")

	# Khởi tạo mock profile nếu cần
	if GameManager.local_profile == null:
		var p := PlayerProfile.new()
		p.display_name = "TestHero"
		p.level = 50
		GameManager.local_profile = p

	var hub_scene: PackedScene = load("res://ui/character_hub/CharacterHub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)

	# 1. Test tiếng Trung (zh)
	print("Switching locale to 'zh'...")
	GameSettings.set_locale("zh")

	var char_btn := hub.get_node("%CharacterButton") as Button
	var nav0 := hub.get_node("%NavButton0") as Button
	var nav1 := hub.get_node("%NavButton1") as Button
	var nav2 := hub.get_node("%NavButton2") as Button
	var nav3 := hub.get_node("%NavButton3") as Button
	var nav4 := hub.get_node("%NavButton4") as Button
	var nav5 := hub.get_node("%NavButton5") as Button
	var nav6 := hub.get_node("%NavButton6") as Button
	var nav7 := hub.get_node("%NavButton7") as Button
	var bag1 := hub.get_node("%BagTabs").get_child(0) as Button
	var sort_btn := hub.get_node("%SortButton") as Button
	var ky_tran := hub.get_node("%KyTranCacTopButton") as Button

	print("ZH: CharacterButton: ", char_btn.text)
	print("ZH: NavButton0 (Trang Bị): ", nav0.text)
	print("ZH: NavButton1 (Kỹ Năng): ", nav1.text)
	print("ZH: NavButton2 (Sự Kiện): ", nav2.text)
	print("ZH: NavButton3 (Bang Hội): ", nav3.text)
	print("ZH: NavButton4 (Giao Dịch): ", nav4.text)
	print("ZH: NavButton5 (Chế Tạo): ", nav5.text)
	print("ZH: NavButton6 (BXH): ", nav6.text)
	print("ZH: NavButton7 (Cài Đặt): ", nav7.text)
	print("ZH: Bag 1: ", bag1.text)
	print("ZH: Sort: ", sort_btn.text)
	print("ZH: KyTranCac: ", ky_tran.text)

	if char_btn.text != "角色" or nav0.text != "装备" or nav2.text != "活动" or nav4.text != "交易" or nav5.text != "打造" or nav6.text != "排行":
		print("FAIL: ZH translations mismatch!")
		get_tree().quit(1)
		return

	# 2. Test tiếng Anh (en)
	print("Switching locale to 'en'...")
	GameSettings.set_locale("en")
	print("EN: CharacterButton: ", char_btn.text)
	print("EN: NavButton0 (Trang Bị): ", nav0.text)
	print("EN: NavButton2 (Sự Kiện): ", nav2.text)
	print("EN: Bag 1: ", bag1.text)
	print("EN: Sort: ", sort_btn.text)

	if char_btn.text != "Character" or nav0.text != "Equipment" or nav2.text != "Events" or bag1.text != "Bag 1":
		print("FAIL: EN translations mismatch!")
		get_tree().quit(1)
		return

	# 3. Test tiếng Nhật (ja)
	print("Switching locale to 'ja'...")
	GameSettings.set_locale("ja")
	print("JA: CharacterButton: ", char_btn.text)
	print("JA: NavButton0 (Trang Bị): ", nav0.text)
	print("JA: NavButton2 (Sự Kiện): ", nav2.text)

	if char_btn.text != "キャラクター" or nav0.text != "装備" or nav2.text != "イベント":
		print("FAIL: JA translations mismatch!")
		get_tree().quit(1)
		return

	# 4. Test tiếng Hàn (ko)
	print("Switching locale to 'ko'...")
	GameSettings.set_locale("ko")
	print("KO: CharacterButton: ", char_btn.text)
	print("KO: NavButton0 (Trang Bị): ", nav0.text)

	if char_btn.text != "캐릭터" or nav0.text != "장비":
		print("FAIL: KO translations mismatch!")
		get_tree().quit(1)
		return

	# 5. Test tiếng Thái (th)
	print("Switching locale to 'th'...")
	GameSettings.set_locale("th")
	print("TH: CharacterButton: ", char_btn.text)
	print("TH: NavButton0 (Trang Bị): ", nav0.text)

	if char_btn.text != "ตัวละคร" or nav0.text != "อุปกรณ์":
		print("FAIL: TH translations mismatch!")
		get_tree().quit(1)
		return

	# 6. Test tiếng Nga (ru)
	print("Switching locale to 'ru'...")
	GameSettings.set_locale("ru")
	print("RU: CharacterButton: ", char_btn.text)
	print("RU: NavButton0 (Trang Bị): ", nav0.text)

	if char_btn.text != "Персонаж" or nav0.text != "Снаряжение":
		print("FAIL: RU translations mismatch!")
		get_tree().quit(1)
		return

	# 7. Test tiếng Pháp (fr)
	print("Switching locale to 'fr'...")
	GameSettings.set_locale("fr")
	print("FR: CharacterButton: ", char_btn.text)
	print("FR: NavButton0 (Trang Bị): ", nav0.text)

	if char_btn.text != "Personnage" or nav0.text != "Équipement":
		print("FAIL: FR translations mismatch!")
		get_tree().quit(1)
		return

	# 8. Reset về vi
	GameSettings.set_locale("vi")
	print("VI: CharacterButton: ", char_btn.text)
	print("VI: NavButton0: ", nav0.text)

	print("=== ALL CHARACTERHUB LOCALIZATION TESTS PASSED! ===")
	get_tree().quit(0)

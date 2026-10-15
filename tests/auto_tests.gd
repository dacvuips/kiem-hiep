extends Node
## Auto đánh (AutoSettings / AutoController / AutoSettingsWindow): godot --headless --path . res://tests/auto_tests.tscn
var _fail := 0
func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

class Dummy extends Node2D:
	var dead := false
	var data := {"series": 0}
	var blue_boss := false
	var health := 100.0
	var max_health := 100.0
	func is_dead() -> bool: return dead
	func get_body_height() -> float: return 60.0

func _ready() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "Thử Auto"
	profile.set_sect(SectRegistry.load_all()[0])
	GameManager.local_profile = profile
	test_settings_roundtrip(profile)
	var player: Node2D = load("res://player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	await get_tree().process_frame
	await test_targeting(player, profile)
	await test_loot(player, profile)
	await test_window(profile)
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func test_settings_roundtrip(profile: PlayerProfile) -> void:
	var s := profile.get_auto_settings()
	s.scan_range = 1234
	s.attack_skills[1] = "abc"
	s.elements[2] = false
	s.route.append(Vector2(300, 400))
	s.has_anchor = true
	s.anchor = Vector2(10, 20)
	s.filter_rows.append({"text": "sinh lực", "min": 50})
	profile.auto_mode = AutoSettings.Mode.PK
	profile.auto_presets[1].target_monsters = false
	var json := JSON.stringify(profile.to_dict())
	var back := PlayerProfile.from_dict(JSON.parse_string(json))
	var b := back.auto_presets[0]
	check("lưu bộ đang chọn = PK", back.auto_mode == AutoSettings.Mode.PK)
	check("số nguyên giữ đúng kiểu", b.scan_range == 1234 and typeof(b.scan_range) == TYPE_INT)
	check("ô kỹ năng", b.attack_skills == ["", "abc", ""])
	check("ngũ hành", b.elements[2] == false and b.elements.size() == 5)
	check("toạ độ chạy", b.route.size() == 1 and b.route[0] == Vector2(300, 400))
	check("điểm đánh quanh", b.has_anchor and b.anchor == Vector2(10, 20))
	check("dòng lọc", b.filter_rows.size() == 1 and str(b.filter_rows[0]["text"]) == "sinh lực")
	check("bộ PK riêng", back.auto_presets[1].target_monsters == false)
	## trả lại mặc định cho các ca sau
	profile.auto_mode = AutoSettings.Mode.TRAIN
	profile.auto_presets[0] = AutoSettings.new()

func _dummy(pos: Vector2, series := 0) -> Dummy:
	var d := Dummy.new()
	d.global_position = pos
	d.data = {"series": series}
	d.add_to_group("enemies")
	add_child(d)
	return d

func test_targeting(player: Node2D, profile: PlayerProfile) -> void:
	var s := profile.get_auto_settings()
	var auto: AutoController = player.auto
	var near := _dummy(Vector2(80, 0), 1)
	var far := _dummy(Vector2(400, 0), 0)
	player.is_auto_mode = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("auto chạy khi bật", auto.running)
	check("chọn quái gần nhất", auto._find_target(s, false) == near)
	s.elements[1] = false
	check("lọc ngũ hành bỏ hệ Mộc", auto._find_target(s, false) == far)
	s.elements[1] = true
	far.blue_boss = true
	check("ưu tiên Boss", auto._find_target(s, false) == far)
	s.prefer_boss = false
	near.health = 90.0
	far.health = 10.0
	s.prefer_low_hp = true
	check("ưu tiên thấp máu", auto._find_target(s, false) == far)
	s.prefer_low_hp = false
	s.target_monsters = false
	check("tắt đánh quái", auto._find_target(s, false) == null)
	s.target_monsters = true
	s.scan_range = 50
	check("ngoài phạm vi", auto._find_target(s, false) == null)
	s.scan_range = 1500
	s.anchor_on = true
	s.has_anchor = true
	s.anchor = Vector2(400, 30)
	s.anchor_radius = 100
	check("đánh quanh điểm chỉ đánh trong vùng", auto._find_target(s, false) == far)
	s.anchor_on = false
	player.is_auto_mode = false
	await get_tree().physics_frame
	check("tắt auto thì dừng", not auto.running)
	near.queue_free()
	far.queue_free()
	await get_tree().process_frame

func test_loot(player: Node2D, profile: PlayerProfile) -> void:
	var s := profile.get_auto_settings()
	var drop := GroundDrop.new()
	drop.setup_money(77)
	add_child(drop)
	drop.global_position = player.global_position + Vector2(10, VltkWorld.FEET_OFFSET)
	var gold_before := profile.gold
	s.pick_money = false
	check("tắt nhặt tiền thì bỏ qua", not player.auto._wants(drop, s))
	s.pick_money = true
	player.is_auto_mode = true
	for i in 20:
		await get_tree().physics_frame
	player.is_auto_mode = false
	check("auto nhặt tiền", profile.gold == gold_before + 77)
	var item := ItemInstance.new()
	item.magic = [{"attrib": "lifemax_v", "value": [60, 0, 0]}]
	var text := ItemText.format_attrib("lifemax_v", [60, 0, 0])
	var key := text.substr(0, 5)
	check("lọc thuộc tính khớp (%s)" % text, AutoController.matches_filter(item, [{"text": key, "min": 50}]))
	check("lọc thuộc tính dưới mức", not AutoController.matches_filter(item, [{"text": key, "min": 70}]))

func test_window(profile: PlayerProfile) -> void:
	var win := AutoSettingsWindow.open(self, profile)
	for page in AutoSettingsWindow.PAGES.size():
		win._set_page(page)
		await get_tree().process_frame
	win._set_mode(AutoSettings.Mode.PK)
	await get_tree().process_frame
	check("đổi thẻ PK đổi bộ dùng", profile.auto_mode == AutoSettings.Mode.PK and win._s == profile.auto_presets[1])
	check("khung có nội dung", win._content.get_child_count() > 0)
	win.close_requested.emit()

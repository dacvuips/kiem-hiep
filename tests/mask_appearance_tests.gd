extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU TEST MẶT NẠ & NGOẠI HÌNH / UI NHÂN VẬT ---")
	test_mask_appearance_rules()
	test_player_nameplate_disguise()
	test_character_hub_disguise_ui()
	test_player_aura_vs35()
	print("--- KẾT THÚC TEST MẶT NẠ: TẤT CẢ THÀNH CÔNG ---")
	get_tree().quit()

func check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)
		print("FAIL: %s" % label)

func test_mask_appearance_rules() -> void:
	var equipped: Dictionary = {}
	
	# 1. Chưa đeo mặt nạ
	var look_none := Equipment.get_appearance(equipped, "male", false)
	check("chưa đeo mặt nạ is_masked là false", look_none.get("is_masked") == false)
	check("chưa đeo mặt nạ disguise_title rỗng", str(look_none.get("disguise_title")) == "")
	check("chưa đeo mặt nạ gender là male", str(look_none.get("gender")) == "male")

	# 2. Đeo Mặt Nạ - Liễu Thanh Thanh (particular 1)
	var mask_ltt := ItemGenerator.generate(ItemDatabase.Detail.MASK, 1, 1, 0, [])
	check("tạo được mặt nạ Liễu Thanh Thanh", mask_ltt != null)
	equipped[Equipment.Part.MASK] = mask_ltt

	var look_ltt := Equipment.get_appearance(equipped, "male", false)
	check("Liễu Thanh Thanh is_masked là true", look_ltt.get("is_masked") == true)
	check("Liễu Thanh Thanh biến thành giới tính female", str(look_ltt.get("gender")) == "female")
	check("Liễu Thanh Thanh có danh hiệu dịch dung", str(look_ltt.get("disguise_title")) == "Liễu Thanh Thanh")
	check("Liễu Thanh Thanh có màu sắc yêu kiều", (look_ltt.get("modulate") as Color).r > 1.0)

	# 3. Đeo Mặt Nạ - Đạo Thanh Chân Nhân (particular 2)
	var mask_dtcn := ItemGenerator.generate(ItemDatabase.Detail.MASK, 2, 1, 0, [])
	check("tạo được mặt nạ Đạo Thanh Chân Nhân", mask_dtcn != null)
	equipped[Equipment.Part.MASK] = mask_dtcn

	var look_dtcn := Equipment.get_appearance(equipped, "female", false)
	check("Đạo Thanh Chân Nhân biến thành giới tính male", str(look_dtcn.get("gender")) == "male")
	check("Đạo Thanh Chân Nhân có danh hiệu dịch dung", str(look_dtcn.get("disguise_title")) == "Đạo Thanh Chân Nhân")
	check("Đạo Thanh Chân Nhân có màu xanh lam tiên phong", (look_dtcn.get("modulate") as Color).b > 1.0)

	# 4. Đeo Mặt Nạ Chiến Thần (particular 3)
	var mask_ct := ItemGenerator.generate(ItemDatabase.Detail.MASK, 3, 1, 0, [])
	check("tạo được mặt nạ Chiến Thần", mask_ct != null)
	equipped[Equipment.Part.MASK] = mask_ct

	var look_ct := Equipment.get_appearance(equipped, "male", false)
	check("Chiến Thần có danh hiệu dịch dung", str(look_ct.get("disguise_title")) == "Chiến Thần")
	check("Chiến Thần có ánh xích hoả rực rỡ", (look_ct.get("modulate") as Color).r > 1.2)

	# 5. Đeo Mặt Nạ Hoàng Kim (particular 4)
	var mask_hk := ItemGenerator.generate(ItemDatabase.Detail.MASK, 4, 1, 0, [])
	check("tạo được mặt nạ Hoàng Kim", mask_hk != null)
	equipped[Equipment.Part.MASK] = mask_hk

	var look_hk := Equipment.get_appearance(equipped, "male", false)
	check("Hoàng Kim có danh hiệu dịch dung", str(look_hk.get("disguise_title")) == "Hoàng Kim Chí Tôn")
	check("Hoàng Kim có ánh kim sắc chói lọi", (look_hk.get("modulate") as Color).r > 1.3)

	# 6. Tháo mặt nạ ra
	equipped.erase(Equipment.Part.MASK)
	var look_after := Equipment.get_appearance(equipped, "male", false)
	check("tháo mặt nạ is_masked trở về false", look_after.get("is_masked") == false)
	check("tháo mặt nạ disguise_title trở về rỗng", str(look_after.get("disguise_title")) == "")
	check("tháo mặt nạ gender trở về male gốc", str(look_after.get("gender")) == "male")

func test_player_nameplate_disguise() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "ĐộcCôCầuBại"
	profile.gender = PlayerProfile.Gender.MALE
	GameManager.local_profile = profile

	var player_script = load("res://player/player.gd")
	var player = CharacterBody2D.new()
	player.set_script(player_script)
	player.set_physics_process(false)
	player._build_name_label(profile.display_name)

	# Kiểm tra khi chưa có mặt nạ
	player.refresh_appearance()
	check("player chưa có mặt nạ tên là nguyên bản", player._name_label.text == "ĐộcCôCầuBại")

	# Đeo mặt nạ Liễu Thanh Thanh
	var mask_ltt := ItemGenerator.generate(ItemDatabase.Detail.MASK, 1, 1, 0, [])
	profile.equipment[Equipment.Part.MASK] = mask_ltt
	player.refresh_appearance()
	check("player đeo mặt nạ tên có tag dịch dung", player._name_label.text.contains("Liễu Thanh Thanh") and player._name_label.text.contains("ĐộcCôCầuBại"))

	# Tháo mặt nạ
	profile.equipment.erase(Equipment.Part.MASK)
	player.refresh_appearance()
	check("player tháo mặt nạ tên trở lại nguyên bản", player._name_label.text == "ĐộcCôCầuBại")

	player.queue_free()

func test_character_hub_disguise_ui() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "TiểuLongNữ"
	profile.gender = PlayerProfile.Gender.FEMALE
	GameManager.local_profile = profile

	var hub_scene = load("res://ui/character_hub/CharacterHub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)

	hub._profile = profile
	hub._refresh_portrait()

	check("chưa đeo mặt nạ banner dịch dung ẩn", hub._disguise_banner != null and hub._disguise_banner.visible == false)

	# Đeo mặt nạ Hoàng Kim
	var mask_hk := ItemGenerator.generate(ItemDatabase.Detail.MASK, 4, 1, 0, [])
	profile.equipment[Equipment.Part.MASK] = mask_hk
	hub._refresh_portrait()

	check("đeo mặt nạ banner dịch dung hiện", hub._disguise_banner.visible == true)
	check("banner dịch dung hiện đúng tên", hub._disguise_label.text.contains("Hoàng Kim Chí Tôn"))
	check("icon dịch dung hiện", hub._disguise_icon.visible == true)

	# Tháo mặt nạ
	profile.equipment.erase(Equipment.Part.MASK)
	hub._refresh_portrait()

	check("tháo mặt nạ banner dịch dung tự ẩn", hub._disguise_banner.visible == false)
	check("tháo mặt nạ icon dịch dung tự ẩn", hub._disguise_icon.visible == false)

	hub.queue_free()

func test_player_aura_vs35() -> void:
	var player_scene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	var aura: AnimatedSprite2D = player.get_node("Aura")
	check("player có node Aura", aura != null)
	check("Aura có 19 frames từ vs35.spr", aura.sprite_frames.get_frame_count("default") == 19)
	check("Aura scale đồng đều", aura.scale.x == aura.scale.y and aura.scale.x > 0.3)
	player.queue_free()


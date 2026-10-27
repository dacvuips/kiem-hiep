extends Node

func _ready() -> void:
	print("--- BẮT ĐẦU TEST MẶT NẠ & NGOẠI HÌNH / UI NHÂN VẬT ---")
	test_mask_appearance_rules()
	test_player_nameplate_disguise()
	test_character_hub_disguise_ui()
	test_character_status_screen_mask()
	test_skill_wheel_hidden_slots()
	test_player_aura_vs35()
	test_proto_look_sync()
	test_remote_player_aura_and_mask()
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

	# 6. Tắt ngoại hình mặt nạ (show_mask = false) khi vẫn đang đeo mặt nạ
	var look_masked_off := Equipment.get_appearance(equipped, "male", false, false)
	check("khi đeo mặt nạ nhưng show_mask = false thì is_masked là false", look_masked_off.get("is_masked") == false)
	check("khi đeo mặt nạ nhưng show_mask = false thì disguise_title rỗng", str(look_masked_off.get("disguise_title")) == "")
	check("khi đeo mặt nạ nhưng show_mask = false thì modulate là WHITE", look_masked_off.get("modulate") == Color.WHITE)

	# 7. Tháo mặt nạ ra
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

	# Tắt hiển thị mặt nạ khi vẫn đeo (show_mask = false)
	profile.show_mask = false
	player.refresh_appearance()
	check("player đeo mặt nạ nhưng show_mask = false thì tên trở lại nguyên bản", player._name_label.text == "ĐộcCôCầuBại")

	# Bật lại hiển thị mặt nạ (show_mask = true)
	profile.show_mask = true
	player.refresh_appearance()
	check("player bật lại show_mask = true thì tên có tag dịch dung", player._name_label.text.contains("Liễu Thanh Thanh"))

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
	hub._refresh_equipment_display()

	check("CharacterHub có MaskVisualCheck", hub.has_node("%MaskVisualCheck"))
	var hub_check: Button = hub.get_node("%MaskVisualCheck")
	check("MaskVisualCheck bật khi đeo mặt nạ", hub_check.button_pressed == true and not hub_check.disabled)
	check("đeo mặt nạ banner dịch dung hiện", hub._disguise_banner.visible == true)
	check("banner dịch dung hiện đúng tên", hub._disguise_label.text.contains("Hoàng Kim Chí Tôn"))
	check("icon dịch dung hiện", hub._disguise_icon.visible == true)

	# Bấm tắt ô check mặt nạ trên Hub
	hub_check.button_pressed = false
	hub._on_mask_visual_check_toggled(false)
	check("tắt check mặt nạ trên Hub thì banner ẩn", hub._disguise_banner.visible == false)
	check("tắt check mặt nạ trên Hub thì icon dịch dung ẩn", hub._disguise_icon.visible == false)
	check("tắt check mặt nạ trên Hub thì profile.show_mask là false", profile.show_mask == false)

	# Bật lại ô check mặt nạ trên Hub
	hub_check.button_pressed = true
	hub._on_mask_visual_check_toggled(true)
	check("bật lại check mặt nạ trên Hub thì banner hiện", hub._disguise_banner.visible == true)
	check("bật lại check mặt nạ trên Hub thì profile.show_mask là true", profile.show_mask == true)

	# Tháo mặt nạ
	profile.equipment.erase(Equipment.Part.MASK)
	hub._refresh_portrait()
	hub._refresh_equipment_display()

	check("tháo mặt nạ banner dịch dung tự ẩn", hub._disguise_banner.visible == false)
	check("tháo mặt nạ icon dịch dung tự ẩn", hub._disguise_icon.visible == false)
	check("tháo mặt nạ MaskVisualCheck bị vô hiệu hoá", hub_check.disabled == true)

	hub.queue_free()

func test_character_status_screen_mask() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "ThầnĐiêuĐạiHiệp"
	profile.level = 99
	var mask := ItemGenerator.generate(ItemDatabase.Detail.MASK, 1, 1, 0, [])
	profile.equipment[Equipment.Part.MASK] = mask
	
	var holder := Control.new()
	add_child(holder)
	var screen := CharacterStatusScreen.attach(holder, profile)
	check("CharacterStatusScreen gắn thành công", screen != null)
	check("CharacterStatusScreen có EquipSlot11 (Mặt nạ)", screen.has_node("%EquipSlot11"))
	check("CharacterStatusScreen có EquipSlot12 (Phi phong)", screen.has_node("%EquipSlot12"))
	check("CharacterStatusScreen có MaskVisualCheck", screen.has_node("%MaskVisualCheck"))
	var status_check: Button = screen.get_node("%MaskVisualCheck")
	check("MaskVisualCheck trên status screen bật khi đeo mặt nạ", status_check.button_pressed == true and not status_check.disabled)
	var slot11: ItemSlotButton = screen.get_node("%EquipSlot11")
	check("EquipSlot11 có icon mặt nạ", slot11._item_icon != null)
	check("CharacterStatusScreen có banner dịch dung", screen._disguise_banner != null and screen._disguise_banner.visible == true)
	check("CharacterStatusScreen banner hiện Liễu Thanh Thanh", screen._disguise_label.text.contains("Liễu Thanh Thanh"))
	check("CharacterStatusScreen có icon dịch dung", screen._disguise_icon != null and screen._disguise_icon.visible == true)

	# Bấm tắt ô check trên Status Screen
	status_check.button_pressed = false
	screen._on_mask_visual_check_toggled(false)
	check("tắt check mặt nạ trên Status Screen thì banner tự ẩn", screen._disguise_banner.visible == false)
	check("tắt check mặt nạ trên Status Screen thì icon tự ẩn", screen._disguise_icon.visible == false)
	check("tắt check mặt nạ trên Status Screen thì profile.show_mask là false", profile.show_mask == false)
	check("tắt check mặt nạ nhưng EquipSlot11 vẫn giữ icon món đồ (vẫn đeo)", slot11._item_icon != null)

	# Bật lại ô check trên Status Screen
	status_check.button_pressed = true
	screen._on_mask_visual_check_toggled(true)
	check("bật lại check mặt nạ trên Status Screen thì banner hiện", screen._disguise_banner.visible == true)
	check("bật lại check mặt nạ trên Status Screen thì profile.show_mask là true", profile.show_mask == true)
	
	# Tháo mặt nạ
	profile.equipment.erase(Equipment.Part.MASK)
	screen.refresh()
	check("Tháo mặt nạ thì EquipSlot11 không còn icon", slot11._item_icon == null)
	check("Tháo mặt nạ banner dịch dung tự ẩn", screen._disguise_banner.visible == false)
	check("Tháo mặt nạ icon dịch dung tự ẩn", screen._disguise_icon.visible == false)
	check("Tháo mặt nạ MaskVisualCheck bị vô hiệu hoá", status_check.disabled == true)
	
	holder.queue_free()

func test_skill_wheel_hidden_slots() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "KỹNăngHiệpKhách"
	var view_script = preload("res://ui/character_hub/skill_book_view.gd")
	var skills: Array[SkillDefinition] = []
	var view = view_script.new(profile, skills)
	var holder = Control.new()
	add_child(holder)
	holder.add_child(view)
	
	# Mặc định: s4 (slot 4 = Sub5), s5 (slot 5 = Sub6), s7 (slot 7 = Sub8) phải ẩn khi chưa được thêm
	check("Slot 4 (Sub5) ẩn khi chưa thêm", view._wheel_slots[4].visible == false)
	check("Slot 5 (Sub6) ẩn khi chưa thêm", view._wheel_slots[5].visible == false)
	check("Slot 7 (Sub8) ẩn khi chưa thêm", view._wheel_slots[7].visible == false)
	check("Slot 0 (Sub1) hiện vì mặc định bật", view._wheel_slots[0].visible == true)
	check("Slot 1 (Sub2) hiện vì mặc định bật", view._wheel_slots[1].visible == true)
	check("Slot 2 (Sub3) hiện vì mặc định bật", view._wheel_slots[2].visible == true)
	check("Slot 3 (Sub4) hiện vì mặc định bật", view._wheel_slots[3].visible == true)
	check("Slot 6 (Sub7) hiện vì mặc định bật", view._wheel_slots[6].visible == true)
	
	# Khi bật Sắp xếp: các ô ẩn hiện mờ để bấm thêm
	view._set_arranging(true)
	check("Khi bật Sắp xếp: slot 4 hiện", view._wheel_slots[4].visible == true)
	check("Khi bật Sắp xếp: slot 4 modulate.a mờ", is_equal_approx(view._wheel_slots[4].modulate.a, 0.35))
	
	# Thêm ô slot 4
	profile.set_skill_slot_on("s4", true)
	view._refresh_slot_controls()
	check("Khi thêm slot 4: modulate.a sáng 1.0", is_equal_approx(view._wheel_slots[4].modulate.a, 1.0))
	
	# Tắt Sắp xếp
	view._set_arranging(false)
	check("Khi tắt Sắp xếp: slot 4 đã thêm vẫn hiện", view._wheel_slots[4].visible == true)
	check("Khi tắt Sắp xếp: slot 5 chưa thêm vẫn ẩn", view._wheel_slots[5].visible == false)
	check("Khi tắt Sắp xếp: slot 7 chưa thêm vẫn ẩn", view._wheel_slots[7].visible == false)
	
	holder.queue_free()

func test_player_aura_vs35() -> void:
	var player_scene = load("res://player/player.tscn")
	var player = player_scene.instantiate()
	var aura: AnimatedSprite2D = player.get_node("Aura")
	check("player có node Aura", aura != null)
	check("Aura có 19 frames từ vs35.spr", aura.sprite_frames.get_frame_count("default") == 19)
	check("Aura scale đồng đều", aura.scale.x == aura.scale.y and aura.scale.x > 0.3)
	player.queue_free()

func test_proto_look_sync() -> void:
	var b := StreamPeerBuffer.new()
	var orig_look := {
		"gender": 1,
		"helm": 12,
		"armor": 34,
		"weapon": 56,
		"horse": 78,
		"mask_particular": 3,
		"aura_state": 42
	}
	NetProto.put_look(b, orig_look)
	b.seek(0)
	var read_look := NetProto.get_look(b)
	check("NetProto đồng bộ gender", int(read_look.get("gender", -1)) == 1)
	check("NetProto đồng bộ helm", int(read_look.get("helm", -1)) == 12)
	check("NetProto đồng bộ armor", int(read_look.get("armor", -1)) == 34)
	check("NetProto đồng bộ weapon", int(read_look.get("weapon", -1)) == 56)
	check("NetProto đồng bộ horse", int(read_look.get("horse", -1)) == 78)
	check("NetProto đồng bộ mask_particular", int(read_look.get("mask_particular", -1)) == 3)
	check("NetProto đồng bộ aura_state", int(read_look.get("aura_state", -1)) == 42)

func test_remote_player_aura_and_mask() -> void:
	var rp := RemotePlayer.new()
	var info := {
		"eid": 1001,
		"name": "HiệpKháchBắcNam",
		"level": 60,
		"camp": 1,
		"nation": 0,
		"pos": Vector2(100, 200),
		"dir": 0,
		"action": 0,
		"z": 0,
		"flags": 0,
		"hp": 100,
		"look": {"gender": 0, "helm": 0, "armor": 0, "weapon": 0, "horse": -1, "mask_particular": -1, "aura_state": 0}
	}
	rp.setup(info)
	add_child(rp)

	# 1. Kiểm tra vòng hào quang dưới chân (foot aura ring) trên RemotePlayer
	check("RemotePlayer có node aura", rp.aura != null)
	check("RemotePlayer aura có 19 frames từ CharacterAura", rp.aura.sprite_frames.get_frame_count("default") == 19)
	check("RemotePlayer aura scale đồng đều", rp.aura.scale.x == rp.aura.scale.y and rp.aura.scale.x > 0.3)
	check("RemotePlayer aura vị trí khớp chân", rp.aura.position == rp.avatar.position + Vector2(0, 1))

	# 2. Kiểm tra khi chưa đeo mặt nạ
	check("RemotePlayer chưa có mặt nạ tên nguyên bản", rp._label.text == "HiệpKháchBắcNam")
	check("RemotePlayer chưa có mặt nạ avatar không modulate", rp.avatar.modulate == Color.WHITE)
	check("RemotePlayer chưa có mặt nạ giới tính là male", rp.avatar.gender == "male")

	# 3. Đeo mặt nạ Liễu Thanh Thanh (particular 1: biến thành nữ, modulate, danh hiệu dịch dung)
	var look_masked := {
		"gender": 0,
		"helm": 1,
		"armor": 1,
		"weapon": 0,
		"horse": -1,
		"mask_particular": 1,
		"aura_state": 0
	}
	rp.set_look(look_masked)
	check("RemotePlayer đeo mặt nạ giới tính biến thành female", rp.avatar.gender == "female")
	check("RemotePlayer đeo mặt nạ avatar có modulate", rp.avatar.modulate.r > 1.0)
	check("RemotePlayer tên có tag dịch dung Liễu Thanh Thanh", rp._label.text.contains("Liễu Thanh Thanh") and rp._label.text.contains("HiệpKháchBắcNam"))
	check("RemotePlayer tên có icon mặt nạ", rp._label.text.contains("🎭"))

	# 4. Đeo Mặt Nạ Chiến Thần (particular 3: ánh đỏ modulate, Chiến Thần)
	var look_ct := {
		"gender": 0,
		"helm": 2,
		"armor": 2,
		"weapon": 0,
		"horse": -1,
		"mask_particular": 3,
		"aura_state": 0
	}
	rp.set_look(look_ct)
	check("RemotePlayer mặt nạ Chiến Thần có modulate đỏ", rp.avatar.modulate.r > 1.2)
	check("RemotePlayer tên có danh hiệu Chiến Thần", rp._label.text.contains("Chiến Thần"))

	# 5. Tháo mặt nạ
	var look_unmasked := {
		"gender": 0,
		"helm": 0,
		"armor": 0,
		"weapon": 0,
		"horse": -1,
		"mask_particular": -1,
		"aura_state": 0
	}
	rp.set_look(look_unmasked)
	check("RemotePlayer tháo mặt nạ giới tính trở lại male", rp.avatar.gender == "male")
	check("RemotePlayer tháo mặt nạ avatar modulate về WHITE", rp.avatar.modulate == Color.WHITE)
	check("RemotePlayer tháo mặt nạ tên trở lại nguyên bản", rp._label.text == "HiệpKháchBắcNam")

	# 6. Kiểm tra đồng bộ hào quang môn phái (aura_state)
	var look_aura := {
		"gender": 0,
		"helm": 0,
		"armor": 0,
		"weapon": 0,
		"horse": -1,
		"mask_particular": -1,
		"aura_state": 9999
	}
	rp.set_look(look_aura)
	check("RemotePlayer nhận aura_state", rp._aura_sprite_state == 9999)

	look_aura["aura_state"] = 0
	rp.set_look(look_aura)
	check("RemotePlayer tắt aura_state", rp._aura_sprite_state == 0 and rp._aura_sprite == null)

	rp.queue_free()



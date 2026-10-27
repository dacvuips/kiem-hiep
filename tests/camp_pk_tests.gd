extends Node

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, " | ", detail)

func _ready() -> void:
	print("--- TEST MÀU TÊN & HỆ THỐNG PK CHUẨN GỐC VLTK ---")

	# 1. Test Cái Bang môn phái & màu tên
	var cb := PlayerProfile.new()
	cb.sect_id = "cai_bang"
	cb.level = 1
	check("Cái Bang cấp 1 có phái -> Phe Chính Phái (Camp.Type.JUSTICE)", cb.get_current_camp() == Camp.Type.JUSTICE, cb.get_current_camp())
	check("Cái Bang màu tên Vàng Cam RGB(255, 168, 94)", Camp.get_color(cb.get_current_camp()) == Color8(255, 168, 94))

	# 2. Test Vô Môn Phái
	var vm := PlayerProfile.new()
	vm.choose_element(ElementTypes.ElementType.HOA)
	check("Vô Môn Phái cấp 1 -> Tân thủ (Camp.Type.BEGIN)", vm.get_current_camp() == Camp.Type.BEGIN, vm.get_current_camp())
	check("Vô Môn Phái màu tên Trắng RGB(255, 255, 255)", Camp.get_color(vm.get_current_camp()) == Color8(255, 255, 255))

	# 3. Test Các Môn Phái chuẩn theo GameDataDef.h & 门派设定.ini
	var sects := {
		"cai_bang": Camp.Type.JUSTICE,
		"thieu_lam": Camp.Type.JUSTICE,
		"nga_mi": Camp.Type.JUSTICE,
		"vo_dang": Camp.Type.JUSTICE,
		"ngu_doc_giao": Camp.Type.EVIL,
		"thien_nhan_giao": Camp.Type.EVIL,
		"duong_mon": Camp.Type.BALANCE,
		"thien_vuong_bang": Camp.Type.BALANCE,
		"thuy_yen_mon": Camp.Type.BALANCE,
		"con_lon": Camp.Type.BALANCE,
		"hoa_son": Camp.Type.BALANCE,
	}
	for s_id in sects:
		var prof := PlayerProfile.new()
		prof.sect_id = s_id
		prof.level = 5
		var expected_camp: int = sects[s_id]
		check("Môn phái [%s] -> Phe %d" % [s_id, expected_camp], prof.get_current_camp() == expected_camp, [prof.get_current_camp(), expected_camp])

	# 4. Test Tự động phục hồi camp hỏng (camp == 0 khi đã có phái)
	var corrupt := {
		"sect_id": "cai_bang",
		"level": 1,
		"camp": 0,
	}
	var healed := PlayerProfile.from_dict(corrupt)
	check("Hồi phục camp = 0 thành phe Cái Bang", healed.get_current_camp() == Camp.Type.JUSTICE, healed.get_current_camp())

	# 5. Test 4 Chế độ PK gốc VLTK (enumPKNormal, enumPKWar, enumPKMurder, enumPKTongWar)
	check("PK Normal = 0", Camp.PKMode.NORMAL == 0)
	check("PK War = 1", Camp.PKMode.WAR == 1)
	check("PK Murder = 2", Camp.PKMode.MURDER == 2)
	check("PK TongWar = 3", Camp.PKMode.TONG_WAR == 3)

	# 6. Test Màu Tên khi bật Đồ Sát (Camp.Type.FREE -> Đỏ rực)
	check("Màu tên Đồ Sát = Đỏ rực RGB(255, 0, 0)", Camp.get_color(Camp.Type.FREE) == Color8(255, 0, 0))
	check("Màu tên Bang Chiến = Tím đậm RGB(104, 38, 174)", Camp.get_color(Camp.Type.TONGWAR) == Color8(104, 38, 174))

	# 7. Test Trị PK mặc định là 0
	var test_p := PlayerProfile.new()
	check("Trị PK mặc định của nhân vật là 0", test_p.pk_value == 0, test_p.pk_value)

	# 8. Test Giao diện ô PK trên CharacterHub
	var hub_scene = load("res://ui/character_hub/CharacterHub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)
	hub._profile = test_p
	hub._refresh_equipment_display()
	check("CharacterHub có node %PkValueLabel", hub.has_node("%PkValueLabel"))
	var pk_label: Label = hub.get_node("%PkValueLabel")
	check("Chỗ PK hiển thị mặc định là 0", pk_label.text == "0", pk_label.text)
	check("Chỗ PK = 0 chữ màu vàng", pk_label.get_theme_color("font_color") == Color(0.98, 0.78, 0.12), pk_label.get_theme_color("font_color"))

	# Khi pk_value tăng
	test_p.pk_value = 2
	hub._refresh_equipment_display()
	check("Chỗ PK hiển thị 2 khi pk_value = 2", pk_label.text == "2", pk_label.text)
	check("Chỗ PK > 0 chữ màu đỏ cảnh báo ác danh", pk_label.get_theme_color("font_color") == Color(0.95, 0.25, 0.2))
	hub.queue_free()

	# 9. Test Quy tắc Đồ Sát tăng điểm PK:
	# - Nếu thủ phạm ĐANG Ở TRẠNG THÁI ĐỒ SÁT (pk_mode == 2): +1 điểm PK
	test_p.pk_value = 0
	var kill_res1 := PkRules.handle_murder_kill(test_p, 2, false)
	check("Đang đồ sát (pk_mode == 2) hạ người khác -> Được cộng 1 PK", kill_res1 and test_p.pk_value == 1, test_p.pk_value)

	# - Nếu thủ phạm ĐÃ TẮT VỀ CHIẾN ĐẤU (pk_mode == 1): dù đối phương chết do trúng độc rút -> KHÔNG BỊ PK
	var kill_res2 := PkRules.handle_murder_kill(test_p, 1, false)
	check("Đã tắt về Chiến Đấu (pk_mode == 1) khi đối phương chết vì độc -> KHÔNG bị PK", (not kill_res2) and test_p.pk_value == 1, test_p.pk_value)

	# - Nếu thủ phạm ĐÃ VỀ BÌNH THƯỜNG / LUYỆN CÔNG (pk_mode == 0): đối phương chết vì độc -> KHÔNG BỊ PK
	var kill_res3 := PkRules.handle_murder_kill(test_p, 0, false)
	check("Đã về Luyện Công (pk_mode == 0) khi đối phương chết vì độc -> KHÔNG bị PK", (not kill_res3) and test_p.pk_value == 1, test_p.pk_value)

	# - Nếu hạ sát người ĐANG ĐỒ SÁT (trừ gian diệt bạo): KHÔNG BỊ PK
	var kill_res4 := PkRules.handle_murder_kill(test_p, 2, true)
	check("Hạ gục kẻ đang đồ sát (victim_is_murder == true) -> KHÔNG bị PK", (not kill_res4) and test_p.pk_value == 1, test_p.pk_value)

	# 10. Test StatusEffect Controller truyền attacker_node khi trúng độc
	var controller := StatusEffectController.new()
	var attacker := Node2D.new()
	var mods := CombatFormulas.HitModifiers.new()
	mods.attacker_node = attacker
	mods.poison_time_frames = 180
	mods.poison_interval_frames = 18
	mods.poison_tick_damage = 50
	var dealt := {CombatFormulas.DamageType.POISON: 50}
	var defender_stats := CombatantStats.new()
	controller.apply_vltk_hit(mods, dealt, defender_stats)
	check("Controller có effect poison", controller.has_effect("poison"))
	var eff: StatusEffect = controller.get_effect("poison")
	check("Effect poison lưu đúng attacker_node", eff.attacker_node == attacker)

	print("--- KẾT THÚC TEST: RESULT %d/%d (Thất bại: %d) ---" % [_pass, _pass + _fail, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

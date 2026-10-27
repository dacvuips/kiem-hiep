extends Node

var total_tests := 0
var passed_tests := 0
var failed_tests := 0

func assert_true(cond: bool, msg: String) -> void:
	total_tests += 1
	if cond:
		passed_tests += 1
		print("PASS: %s" % msg)
	else:
		failed_tests += 1
		printerr("FAIL: %s" % msg)

func _ready() -> void:
	print("--- BẮT ĐẦU TEST SÁT THƯƠNG 15 PHÁI, ĐỘC SÁT VLTK & SLOT THI TRIỂN LIÊN TỤC ---")
	test_elemental_damages_and_resists()
	test_five_elements_clash()
	test_poison_mechanics_and_mix()
	test_vo_hinh_doc_and_loop_slot()
	test_nga_mi_buffs_and_loop_slot()
	print("--- KẾT THÚC TEST: RESULT %d/%d (Thất bại: %d) ---" % [passed_tests, total_tests, failed_tests])
	get_tree().quit(0 if failed_tests == 0 else 1)

func test_elemental_damages_and_resists() -> void:
	print("\n[1] Kiểm tra tính sát thương nguyên tố & kháng hệ...")
	var attacker := CombatantStats.new()
	attacker.element = ElementTypes.ElementType.KIM
	attacker.attack_rating = 1000

	var defender := CombatantStats.new()
	defender.element = ElementTypes.ElementType.MOC
	defender.defense = 200

	# 1. Kháng vật lý
	defender.resist_percent[CombatFormulas.DamageType.PHYSICS] = 50
	var ctx := CombatFormulas.DamageContext.new()
	ctx.min_damage = 100
	ctx.max_damage = 100
	ctx.damage_type = CombatFormulas.DamageType.PHYSICS
	ctx.attacker_element = attacker.element
	ctx.defender_element = defender.element
	ctx.defender_resist_percent = defender.get_capped_resist(CombatFormulas.DamageType.PHYSICS)
	
	# Ngũ hành: Kim khắc Mộc -> defender bị trừ kháng khi tính
	ctx.five_elements_damage_p = 20
	var res := CombatFormulas.resolve_damage(ctx)
	# 100 damage, resist ban đầu 50, bị khắc -20% -> resist còn 30% -> damage = 70
	assert_true(res.final_damage == 70, "Kim khắc Mộc giảm 20% kháng vật lý (100 -> 70)")

	# 2. Kháng hệ cap ở MAX_RESIST (95%)
	defender.resist_percent[CombatFormulas.DamageType.FIRE] = 120
	var capped_fire := defender.get_capped_resist(CombatFormulas.DamageType.FIRE)
	assert_true(capped_fire == 95, "Kháng trần tối đa đúng MAX_RESIST 95% (KPlayer/KNpc gốc)")

func test_five_elements_clash() -> void:
	print("\n[2] Kiểm tra Ngũ Hành tương khắc 15 phái chuẩn gốc...")
	# Kim khắc Mộc, Mộc khắc Thổ, Thổ khắc Thủy, Thủy khắc Hỏa, Hỏa khắc Kim
	assert_true(ElementTypes.does_beat(ElementTypes.ElementType.KIM, ElementTypes.ElementType.MOC), "Kim khắc Mộc")
	assert_true(ElementTypes.does_beat(ElementTypes.ElementType.MOC, ElementTypes.ElementType.THO), "Mộc khắc Thổ")
	assert_true(ElementTypes.does_beat(ElementTypes.ElementType.THO, ElementTypes.ElementType.THUY), "Thổ khắc Thủy")
	assert_true(ElementTypes.does_beat(ElementTypes.ElementType.THUY, ElementTypes.ElementType.HOA), "Thủy khắc Hỏa")
	assert_true(ElementTypes.does_beat(ElementTypes.ElementType.HOA, ElementTypes.ElementType.KIM), "Hỏa khắc Kim")

	# Chiều ngược lại (bị khắc)
	assert_true(ElementTypes.is_beaten_by(ElementTypes.ElementType.MOC, ElementTypes.ElementType.KIM), "Mộc bị Kim khắc")
	assert_true(ElementTypes.is_beaten_by(ElementTypes.ElementType.THO, ElementTypes.ElementType.MOC), "Thổ bị Mộc khắc")

func test_poison_mechanics_and_mix() -> void:
	print("\n[3] Kiểm tra công thức rút độc, nhịp rút độc & gộp độc chuẩn gốc...")
	# Test MixPoisonDamage:
	# d = ((c1+c2)*d1/c1 + (c1+c2)*d2/c2) / 2
	# t = (t1*d1*c2 + t2*d2*c1) / (d1*c2 + d2*c1)
	# c = (c1+c2) / 2
	var p1 := Vector3i(10, 60, 10)  # damage=10, time=60 frames, interval=10 frames
	var p2 := Vector3i(20, 60, 10)  # damage=20, time=60 frames, interval=10 frames
	var mixed := SectSkillController._mix_poison(p1, p2)
	# c = (10+10)/2 = 10
	# d = (20*10/10 + 20*20/10) / 2 = (20 + 40) / 2 = 30
	# t = (60*10*10 + 60*20*10) / (10*10 + 20*10) = (6000 + 12000) / 300 = 60
	assert_true(mixed.x == 30, "Gộp 2 nguồn độc cùng nhịp cộng dồn damage: 10 + 20 = 30")
	assert_true(mixed.y == 60, "Thời gian độc duy trì đúng 60 frame")
	assert_true(mixed.z == 10, "Nhịp rút độc giữ đúng 10 frame")

	# Test Poison Stacking trong StatusEffectController
	var dummy := Node2D.new()
	add_child(dummy)
	var sec := StatusEffectController.new()
	dummy.add_child(sec)

	var mods := CombatFormulas.HitModifiers.new()
	mods.poison_time_frames = 60
	mods.poison_interval_frames = 10
	mods.poison_tick_damage = 25

	var dealt := {CombatFormulas.DamageType.POISON: 25}
	var def_stats := CombatantStats.new()
	sec.apply_vltk_hit(mods, dealt, def_stats)

	assert_true(sec.has_effect("poison"), "Mục tiêu bị nhiễm độc")
	var eff := sec.get_effect("poison")
	assert_true(eff.frame_mode == true, "Độc chạy theo frame_mode (18 FPS chuẩn VLTK)")
	assert_true(int(eff.damage_per_tick) == 25, "Lượng rút mỗi nhịp = 25")
	assert_true(eff.interval_frames == 10, "Nhịp rút độc = 10 frames")

	dummy.queue_free()

func test_vo_hinh_doc_and_loop_slot() -> void:
	print("\n[4] Kiểm tra Vô Hình Độc & slot thi triển liên tục...")
	var ngu_doc_tres: SectDefinition = load("res://systems/sect/data/ngu_doc_giao.tres")
	assert_true(ngu_doc_tres != null, "Load được dữ liệu Ngũ Độc Giáo")
	
	var vo_hinh_doc: SkillDefinition = null
	for s in ngu_doc_tres.skills:
		if s.id == "ngu_doc_vo_hinh_doc":
			vo_hinh_doc = s
			break
	assert_true(vo_hinh_doc != null, "Tìm thấy kỹ năng Vô Hình Độc")
	assert_true(vo_hinh_doc.is_aura == true, "Vô Hình Độc là Hào Quang (is_aura = true)")

	var profile := PlayerProfile.new()
	profile.sect_id = "ngu_doc_giao"
	profile.set_loop_slot(0, "ngu_doc_vo_hinh_doc")

	# Khi đưa Vô Hình Độc vào ô thi triển liên tục -> active_aura_id được bật NGAY LẬP TỨC
	assert_true(profile.active_aura_id == "ngu_doc_vo_hinh_doc", "Đưa Vô Hình Độc vào ô thi triển liên tục -> Kích hoạt ngay hào quang liên tục")

	# Khi gỡ ra khỏi ô -> active_aura_id tắt
	profile.set_loop_slot(0, "")
	assert_true(profile.active_aura_id == "", "Gỡ skill khỏi ô -> Tắt hào quang liên tục")

func test_nga_mi_buffs_and_loop_slot() -> void:
	print("\n[5] Kiểm tra Nga My buffs (máu, mana, tốc chạy, kháng) & slot thi triển liên tục...")
	var nga_mi_tres: SectDefinition = load("res://systems/sect/data/nga_mi.tres")
	assert_true(nga_mi_tres != null, "Load được dữ liệu Nga Mi")

	var profile := PlayerProfile.new()
	profile.sect_id = "nga_mi"

	# 1. Lưu Thủy (tốc độ chạy)
	profile.set_loop_slot(0, "nga_mi_luu_thuy")
	assert_true(profile.active_aura_id == "nga_mi_luu_thuy", "Đưa Lưu Thủy (tốc độ chạy) ra ô -> Có hiệu lực ngay liên tục")

	# 2. Phật Tâm Từ Hữu (máu/mana)
	profile.set_loop_slot(0, "nga_mi_phat_tam_tu_huu")
	assert_true(profile.active_aura_id == "nga_mi_phat_tam_tu_huu", "Đưa Phật Tâm Từ Hữu (máu/mana) ra ô -> Có hiệu lực ngay liên tục")

	# 3. Thanh Âm Phạn Xướng (kháng)
	profile.set_loop_slot(0, "nga_mi_thanh_am_phan_xuong")
	assert_true(profile.active_aura_id == "nga_mi_thanh_am_phan_xuong", "Đưa Thanh Âm Phạn Xướng (kháng) ra ô -> Có hiệu lực ngay liên tục")

	# 4. Phổ Độ Chúng Sinh (hào quang tổng hợp)
	profile.set_loop_slot(0, "nga_mi_pho_do_chung_sinh")
	assert_true(profile.active_aura_id == "nga_mi_pho_do_chung_sinh", "Đưa Phổ Độ Chúng Sinh ra ô -> Có hiệu lực ngay liên tục")

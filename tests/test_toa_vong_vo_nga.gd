extends Node

const PlayerScene := preload("res://player/player.tscn")

var total_tests := 0
var passed_tests := 0

func check(desc: String, condition: bool) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("[PASS] %s" % desc)
	else:
		push_error("[FAIL] %s" % desc)
		print("[FAIL] %s" % desc)

func _ready() -> void:
	print("--- BẮT ĐẦU KIỂM TRA TỌA VỌNG VÔ NGÃ (MANA SHIELD) 100% VLTK ---")
	test_magic_attrib_and_stats()
	test_combat_formulas_mana_shield()
	test_hit_resolver_mana_shield()
	await test_player_live_toa_vong()

	print("--- KẾT THÚC KIỂM TRA: %d/%d test passed ---" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("ALL TOA VONG VO NGA TESTS PASSED!")
	else:
		push_error("SOME TESTS FAILED!")

func test_magic_attrib_and_stats() -> void:
	print("\n--- Test 1: Thuộc tính manashield_p trong CombatantStats & MagicAttribTable ---")
	var stats := CombatantStats.new()
	check("Khởi tạo mana_shield_p = 0", stats.mana_shield_p == 0)

	MagicAttribTable.apply(stats, "manashield_p", Vector3i(80, 0, 0))
	check("Áp dụng manashield_p 80% thành công", stats.mana_shield_p == 80)

	# Kiểm tra giá trị âm không làm giảm khiên
	MagicAttribTable.apply(stats, "manashield_p", Vector3i(-5, 0, 0))
	check("Giá trị âm không làm hỏng khiên (vẫn 80%)", stats.mana_shield_p == 80)

	# Kiểm tra trần tối đa 85%
	MagicAttribTable.apply(stats, "manashield_p", Vector3i(100, 0, 0))
	check("Capped trần tối đa 85% theo VLTK", stats.mana_shield_p == 85)

func test_combat_formulas_mana_shield() -> void:
	print("\n--- Test 2: Công thức tính toán sát thương & hấp thụ nội lực (CombatFormulas) ---")
	var ctx := CombatFormulas.DamageContext.new()
	ctx.min_damage = 100
	ctx.max_damage = 100
	ctx.damage_type = CombatFormulas.DamageType.PHYSICS
	ctx.defender_mana_shield_p = 80
	ctx.defender_current_mana = 200
	ctx.defender_resist_percent = 0
	ctx.defender_flat_armor = 0

	var res := CombatFormulas.resolve_damage(ctx)
	check("Đòn trúng đích", res.is_hit)
	check("Nội lực hấp thụ 80% (80 mana)", res.mana_absorbed == 80)
	check("Sát thương máu còn lại 20 (100 - 80)", res.final_damage == 20)

	# Trường hợp nội lực không đủ (còn 30 mana)
	ctx.defender_current_mana = 30
	var res2 := CombatFormulas.resolve_damage(ctx)
	check("Nội lực chỉ còn 30: hấp thụ tối đa 30", res2.mana_absorbed == 30)
	check("Sát thương máu gánh phần còn lại: 70 (100 - 30)", res2.final_damage == 70)

	# Trường hợp cạn nội lực (0 mana)
	ctx.defender_current_mana = 0
	var res3 := CombatFormulas.resolve_damage(ctx)
	check("Hết mana: không hấp thụ được gì", res3.mana_absorbed == 0)
	check("Sát thương máu chịu đủ 100%", res3.final_damage == 100)

	# Trường hợp Độc sát (POISON): bỏ qua khiên mana theo chuẩn VLTK
	ctx.damage_type = CombatFormulas.DamageType.POISON
	ctx.defender_current_mana = 200
	var res_poison := CombatFormulas.resolve_damage(ctx)
	check("Độc sát: mana không bị trừ (bỏ qua khiên)", res_poison.mana_absorbed == 0)
	check("Độc sát: đánh thẳng vào máu đủ 100%", res_poison.final_damage == 100)

func test_hit_resolver_mana_shield() -> void:
	print("\n--- Test 3: HitResolver.receive trừ mana thực tế của mục tiêu ---")
	var mock_target := {
		"mana": 500.0,
		"max_mana": 500.0,
		"health": 1000.0,
		"max_health": 1000.0,
		"get_node_or_null": func(_path): return null,
		"is_in_group": func(_g): return false
	}
	var target_node := Node.new()
	target_node.set_script(preload("res://tests/mock_combatant.gd"))
	target_node.mana = 500.0
	target_node.max_mana = 500.0
	target_node.health = 1000.0
	target_node.max_health = 1000.0

	var def_stats := CombatantStats.new()
	def_stats.mana_shield_p = 80
	def_stats.defense = 0

	var atk_stats := CombatantStats.new()
	atk_stats.attack_rating = 9999

	var mods := CombatFormulas.HitModifiers.new()
	mods.use_attack_rating = false

	var final_dmg := HitResolver.receive(target_node, def_stats, int(target_node.health),
			atk_stats, 100, 100, CombatFormulas.DamageType.FIRE, ElementTypes.ElementType.KIM, mods)

	print("HitResolver Test 3: final_dmg=%d, mana=%f (da giam %f)" % [final_dmg, target_node.mana, 500.0 - target_node.mana])
	check("Nội lực của mục tiêu BỊ TRỪ khi có khiên mana", target_node.mana < 500.0)
	check("Sát thương máu gây ra > 0", final_dmg > 0)

	target_node.free()

func test_player_live_toa_vong() -> void:
	print("\n--- Test 4: Player thực chiến bật Tọa Vọng Vô Ngã & bị quái đánh ---")
	var vd_sect := SectRegistry.get_by_id("vo_dang")
	check("Load phái Võ Đang thành công", vd_sect != null)

	var profile := PlayerProfile.new()
	profile.set_sect(vd_sect)
	GameManager.local_profile = profile

	var player = PlayerScene.instantiate()
	add_child(player)
	player.mana = 200.0
	player.max_mana = 200.0
	player.health = 500.0
	player.max_health = 500.0

	var toa_vong: SkillDefinition = null
	for s in vd_sect.skills:
		if s.id == "vo_dang_toa_vong_vo_nga":
			toa_vong = s
			break
	check("Tìm thấy kỹ năng Tọa Vọng Vô Ngã", toa_vong != null)

	if toa_vong != null:
		# Giả lập học và thi triển Tọa Vọng Vô Ngã (cấp 20 -> khiên 80%)
		var payload := toa_vong.get_state_payload(20)
		check("Payload có thuộc tính manashield_p", payload.attribs.has("manashield_p"))
		check("Giá trị manashield_p cấp 20 là 80%", payload.attribs["manashield_p"].x == 80)

		# Áp trạng thái lên player
		player.status_controller.apply_state(toa_vong.id, payload.attribs, 120.0, {"name": toa_vong.skill_name})
		player.refresh_combat_stats()
		check("CombatantStats của player nhận mana_shield_p = 80", player.combat_stats.mana_shield_p == 80)

		player.mana = 2000.0
		player.max_mana = 2000.0
		player.health = 5000.0
		player.max_health = 5000.0

		var mana_before: float = player.mana
		var hp_before: float = player.health

		# Giả lập quái đánh 50 sát thương vào Player
		var monster_atk := CombatantStats.new()
		monster_atk.attack_rating = 9999
		var mods := CombatFormulas.HitModifiers.new()
		mods.use_attack_rating = false

		player.take_damage_from(monster_atk, 50, 50, CombatFormulas.DamageType.PHYSICS, ElementTypes.ElementType.KIM, mods)

		check("Mana của người chơi BỊ TRỪ khi dính đòn", player.mana < mana_before)
		check("Máu của người chơi vẫn còn (sát thương được chia cho mana)", player.health > 0 and player.health < hp_before)
		print("Kết quả đòn đánh: Mana trước=%d -> sau=%d (mất %d); HP trước=%d -> sau=%d (mất %d)" % [
			int(mana_before), int(player.mana), int(mana_before - player.mana),
			int(hp_before), int(player.health), int(hp_before - player.health)
		])

	player.queue_free()

extends Node

## Đại Thành Bí Kíp 90 / 120 / 150 (Kỳ Trân Các): đưa skill luyện cùng tầng lên cấp 20 / 20 / 18.
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/test_dai_thanh_bi_kip.tscn

var _fails := 0

func _ready() -> void:
	var sect_id := ""
	for sect in SectRegistry.load_all():
		var ok := true
		for mid in ItemConsumer.DAI_THANH_BOOKS:
			var p := PlayerProfile.new()
			p.sect_id = sect.id
			if ItemConsumer.dai_thanh_candidates(p, mid).is_empty():
				ok = false
		if ok:
			sect_id = sect.id
			break
	_check(sect_id != "", "có phái đủ skill 90/120/150")

	for mid in ["6_1_2424", "6_1_2425", "6_1_30446"]:
		var p := PlayerProfile.new()
		p.sect_id = sect_id
		p.level = 200
		var cands := ItemConsumer.dai_thanh_candidates(p, mid)
		var tier := int(ItemConsumer.DAI_THANH_BOOKS[mid]["tier"])
		for sk in cands:
			_check(sk.practice_only, "%s: [%s] là skill luyện" % [mid, sk.skill_name])
		var sk: SkillDefinition = cands[0]
		var target := ItemConsumer.dai_thanh_target_level(mid, sk)
		_check(target == (18 if tier == 150 else 20) or target == sk.max_level, "%s: cấp đích %d" % [mid, target])
		p.skill_levels[sk.id] = 1
		var book := ItemGenerator.generate_misc(mid)
		_check(book != null and p.add_item(book), "%s: sinh + bỏ vào túi" % mid)
		var pts := p.skill_points
		var r := ItemConsumer.use_dai_thanh(p, book, sk.id)
		_check(r.get("ok", false), "%s: dùng được — %s" % [mid, r.get("message", "")])
		_check(p.get_skill_level(sk.id) == target, "%s: [%s] đạt cấp %d" % [mid, sk.skill_name, target])
		_check(p.inventory.find(book) < 0, "%s: tiêu hao 1 cuốn" % mid)
		_check(p.skill_points == pts, "%s: không đổi điểm kỹ năng" % mid)
		## đã đạt cấp đích -> chặn
		var book2 := ItemGenerator.generate_misc(mid)
		p.add_item(book2)
		_check(not ItemConsumer.use_dai_thanh(p, book2, sk.id).get("ok", false), "%s: đã đạt cấp đích thì chặn" % mid)
		_check(p.inventory.find(book2) >= 0, "%s: bị chặn thì không mất sách" % mid)
		## chưa đủ cấp nhân vật -> chặn
		var low := PlayerProfile.new()
		low.sect_id = sect_id
		low.level = 10
		var book3 := ItemGenerator.generate_misc(mid)
		low.add_item(book3)
		_check(not ItemConsumer.use_item(low, book3).get("ok", false), "%s: cấp 10 không dùng được" % mid)
		## nút Dùng (use_item) tự chọn skill
		var p2 := PlayerProfile.new()
		p2.sect_id = sect_id
		p2.level = 200
		var book4 := ItemGenerator.generate_misc(mid)
		p2.add_item(book4)
		var r2 := ItemConsumer.use_item(p2, book4)
		_check(r2.get("ok", false), "%s: Dùng tự chọn skill — %s" % [mid, r2.get("message", "")])
		_check(ItemConsumer.get_special_actions(book2, null, p).size() == cands.size(), "%s: mỗi skill 1 nút Lĩnh hội" % mid)

	## không có phái -> chặn
	var np := PlayerProfile.new()
	np.level = 200
	var b := ItemGenerator.generate_misc("6_1_2424")
	np.add_item(b)
	_check(not ItemConsumer.use_item(np, b).get("ok", false), "chưa có phái không dùng được")

	print("DAI THANH BI KIP: %s" % ("PASS" if _fails == 0 else "FAIL %d" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		_fails += 1
		printerr("FAIL: ", msg)

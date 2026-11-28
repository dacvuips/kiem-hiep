extends Node

## Luyện skill 90/120/150 khi đánh quái (SkillPractice).
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/test_skill_practice.tscn

var _fails := 0

func _ready() -> void:
	## Phái có cả skill luyện bằng đòn trúng và skill luyện bằng EXP giết quái.
	var sect_id := ""
	var hit_sk: SkillDefinition = null
	var kill_sk: SkillDefinition = null
	var missing := 0
	for sect: SectDefinition in SectRegistry.load_all():
		var h: SkillDefinition = null
		var k: SkillDefinition = null
		for sk: SkillDefinition in sect.skills:
			if SkillPractice.tier_of(sk) == 0:
				continue
			if SkillPractice.next_exp(sk, 1) <= 0:
				missing += 1
				printerr("thiếu mốc: ", sect.id, " ", sk.id)
			if SkillPractice.is_hit_trained(sk) and h == null:
				h = sk
			elif not SkillPractice.is_hit_trained(sk) and k == null:
				k = sk
		if h != null and k != null and sect_id == "":
			sect_id = sect.id
			hit_sk = h
			kill_sk = k
	_check(missing == 0, "mọi skill luyện 15 phái đều có mốc thành thạo")
	_check(sect_id != "", "có phái đủ 2 loại skill luyện (%s: %s / %s)" % [sect_id,
			hit_sk.skill_name if hit_sk else "-", kill_sk.skill_name if kill_sk else "-"])
	if sect_id == "":
		_finish()
		return

	var p := PlayerProfile.new()
	p.sect_id = sect_id
	p.level = 200
	## chưa lĩnh hội -> không luyện
	_check(SkillPractice.on_hit(p, hit_sk.id) == null and int(p.skill_exp.get(hit_sk.id, 0)) == 0, "chưa lĩnh hội thì không luyện")
	p.skill_levels[hit_sk.id] = 1
	var need := SkillPractice.next_exp(hit_sk, 1)
	var hits := int(ceil(float(need) / SkillPractice.HIT_EXP))
	for i in hits - 1:
		_check_silent(SkillPractice.on_hit(p, hit_sk.id) == null)
	_check(p.get_skill_level(hit_sk.id) == 1, "%d đòn chưa đủ %d thành thạo -> vẫn cấp 1" % [hits - 1, need])
	_check(SkillPractice.on_hit(p, hit_sk.id) == hit_sk, "đòn thứ %d -> lên cấp" % hits)
	_check(p.get_skill_level(hit_sk.id) == 2 and int(p.skill_exp.get(hit_sk.id, -1)) == 0, "cấp 2, thành thạo về 0")
	## kill exp không cộng cho skill đánh
	SkillPractice.on_kill_exp(p, 10000000)
	_check(p.get_skill_level(hit_sk.id) == 2 and int(p.skill_exp.get(hit_sk.id, 0)) == 0, "EXP giết quái không luyện skill đánh")

	## skill bị động: 50% EXP giết quái
	p.skill_levels[kill_sk.id] = 1
	var kneed := SkillPractice.next_exp(kill_sk, 1)
	SkillPractice.on_kill_exp(p, 2)
	_check(int(p.skill_exp.get(kill_sk.id, 0)) == 1, "EXP 2 -> +1 thành thạo (50%)")
	var up := SkillPractice.on_kill_exp(p, kneed * 2)
	_check(up.has(kill_sk) and p.get_skill_level(kill_sk.id) == 2, "đủ EXP -> skill bị động lên cấp 2")
	_check(SkillPractice.on_hit(p, kill_sk.id) == null, "đòn trúng không luyện skill bị động")

	## trần cấp 20
	p.skill_levels[hit_sk.id] = SkillPractice.train_cap(hit_sk)
	_check(SkillPractice.next_exp(hit_sk, p.get_skill_level(hit_sk.id)) == 0 and SkillPractice.on_hit(p, hit_sk.id) == null,
			"tới cấp %d thì ngừng luyện" % SkillPractice.train_cap(hit_sk))

	## lưu / nạp hồ sơ giữ thành thạo
	p.skill_levels[hit_sk.id] = 3
	p.skill_exp[hit_sk.id] = 1234
	var q := PlayerProfile.from_dict(p.to_dict())
	_check(int(q.skill_exp.get(hit_sk.id, 0)) == 1234, "lưu / nạp giữ độ thành thạo")
	_check(SkillPractice.describe(q, hit_sk).contains("1234"), "bảng kỹ năng hiện thành thạo: " + SkillPractice.describe(q, hit_sk))

	## Đại Thành Bí Kíp xoá thành thạo đang tích
	var book_id := ""
	for mid in ItemConsumer.DAI_THANH_BOOKS:
		for c in ItemConsumer.dai_thanh_candidates(q, mid):
			if c.id == hit_sk.id:
				book_id = mid
	if book_id != "":
		var book := ItemGenerator.generate_misc(book_id)
		q.add_item(book)
		ItemConsumer.use_dai_thanh(q, book, hit_sk.id)
		_check(not q.skill_exp.has(hit_sk.id), "dùng Đại Thành Bí Kíp xoá thành thạo đang tích")
	_finish()

func _finish() -> void:
	print("SKILL PRACTICE: %s" % ("PASS" if _fails == 0 else "FAIL %d" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

func _check_silent(cond: bool) -> void:
	if not cond:
		_fails += 1

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		_fails += 1
		printerr("FAIL: ", msg)

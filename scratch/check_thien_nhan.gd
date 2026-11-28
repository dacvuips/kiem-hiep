extends SceneTree

func _init() -> void:
	var sect = load("res://systems/sect/data/thien_nhan_giao.tres")
	var by_id := {}
	for s in sect.skills:
		by_id[s.id] = s
	var tm: SkillDefinition = by_id["thien_nhan_tianmo_jieti"]
	for lv in [1, 20, 30]:
		var p: Dictionary = tm.get_state_payload(lv)
		print("Thien Ma L%d fire magic=%s fire dmg=%s seconds=%.0f" % [lv, p.attribs.get("addfiremagic_v"), p.attribs.get("addfiredamage_v"), p.seconds])
	var profile := PlayerProfile.new()
	for s in sect.skills:
		profile.skill_levels[s.id] = 20
	for lv in [20, 30]:
		var f := func(_s): return lv
		for target in ["thien_nhan_tianwai_liuxing", "thien_nhan_moren150", "thien_nhan_moyan_qisha"]:
			var sk: SkillDefinition = by_id[target]
			print("L%d nguon -> %s: ho tro %.0f%%" % [lv, sk.skill_name, sk.get_support_percent_from_other_skills(sect.skills, profile, f)])
	quit()

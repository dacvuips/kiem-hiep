extends SceneTree
func _init() -> void:
	var sect = load("res://systems/sect/data/thien_nhan_giao.tres")
	var profile := PlayerProfile.new()
	for s in sect.skills:
		profile.skill_levels[s.id] = 20
	for t in sect.skills:
		if t.id != "thien_nhan_tianwai_liuxing":
			continue
		for o in sect.skills:
			var arr: Array[SkillDefinition] = [o]
			var v: float = t.get_support_percent_from_other_skills(arr, profile)
			if v != 0.0:
				print("  tu %s (%s, %s): %.0f" % [o.skill_name, o.school_text, "PASSIVE" if o.category == 1 else "ACTIVE", v])
	quit()

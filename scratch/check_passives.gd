extends SceneTree
## Bị động (PASSIVE) nào có dòng "% sát thương/công kích" không trỏ đích, và có vltk_attribs không.
func _init() -> void:
	for f in DirAccess.open("res://systems/sect/data").get_files():
		if not f.ends_with(".tres"):
			continue
		var sect = load("res://systems/sect/data/" + f)
		for o in sect.skills:
			if o.category != 1:
				continue
			for l in o.stat_lines:
				var lbl: String = l.label.to_lower()
				if l.target_skill_id == "" and ("sát thương" in lbl or "công kích" in lbl) and l.suffix.strip_edges() == "%":
					print("%s | %s | %s | %s | attribs=%s" % [f, o.skill_name, o.school_text, l.label, o.vltk_attribs.keys()])
			if o.passive_attack_bonus > 0.0:
				print("%s | %s | passive_attack_bonus=%s | attribs=%s" % [f, o.skill_name, o.passive_attack_bonus, o.vltk_attribs.keys()])
	quit()

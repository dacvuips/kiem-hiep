extends SceneTree
## So số liệu damage skill NỘI CÔNG: stat_lines (combat đang dùng) vs vltk_attribs (Link gốc) ở cấp 1..30.

const ATTR := {
	"colddamage_v": CombatFormulas.DamageType.COLD, "firedamage_v": CombatFormulas.DamageType.FIRE,
	"lightingdamage_v": CombatFormulas.DamageType.LIGHT, "poisondamage_v": CombatFormulas.DamageType.POISON,
}

func _init() -> void:
	var dir := DirAccess.open("res://systems/sect/data")
	var mismatches := 0
	var total := 0
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var sect = load("res://systems/sect/data/" + f)
		if sect == null or not ("skills" in sect):
			continue
		for skill in sect.skills:
			if skill.category != SkillDefinition.SkillCategory.ACTIVE or skill.is_physical():
				continue
			var has_dmg := false
			for a in ATTR:
				if skill.has_attrib(a) or skill.has_attrib("physicsdamage_v") or skill.has_attrib("magicdamage_v"):
					has_dmg = true
			if not has_dmg:
				continue
			total += 1
			var diffs := []
			for lv in [1, 5, 10, 15, 20, 25, 30]:
				var real: Dictionary = skill.get_combat_damage_at_level(lv)
				var els: Dictionary = real["elements"]
				for a in ATTR:
					var t: int = ATTR[a]
					var src := Vector2i.ZERO
					if skill.has_attrib(a):
						var v: Vector3i = skill.get_attrib(a, lv)
						src = Vector2i(v.x, v.z if a != "poisondamage_v" else v.x)
					var used: Vector2i = els.get(t, Vector2i.ZERO)
					if src != used and not (a == "poisondamage_v" and used.x == src.x):
						diffs.append("L%d %s game=%s goc=%s" % [lv, a, used, src])
				if skill.has_attrib("physicsdamage_v"):
					var pv: Vector3i = skill.get_attrib("physicsdamage_v", lv)
					var pu: Vector2i = real["physics_flat"]
					if Vector2i(pv.x, pv.z) != pu:
						diffs.append("L%d physicsdamage_v game=%s goc=%s" % [lv, pu, Vector2i(pv.x, pv.z)])
				if skill.has_attrib("magicdamage_v"):
					diffs.append("L%d magicdamage_v goc=%s (game KHONG dung)" % [lv, skill.get_attrib("magicdamage_v", lv)])
			var attrs := []
			for k in skill.vltk_attribs:
				attrs.append(k)
			if not diffs.is_empty():
				mismatches += 1
				print("== %s / %s (id %d, max %d) attrs=%s" % [f, skill.skill_name, skill.vltk_skill_id, skill.max_level, attrs])
				for d in diffs:
					print("   ", d)
	print("TOTAL inner damage skills: %d, mismatched: %d" % [total, mismatches])
	quit()

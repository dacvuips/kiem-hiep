extends Node
## Rà soát sát thương skill: tính _resolve_stats cho skill đánh của mọi phái ở cấp 1/10/20 (mọi skill hỗ trợ học cấp 20),
## rồi quy ra kỳ vọng sau hệ số server thật (apply_server_damage_scaling) để so sánh giữa các phái.
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . -s scratch/audit_vo_dang_damage.gd

const LEVELS := [1, 10, 20]

func _scaled_avg(parts: Dictionary, series: int) -> float:
	## Kỳ vọng sau hệ số server (k=1): trung bình min/max.
	var total := 0.0
	for t in parts:
		var v: Vector2i = parts[t]
		var lo := float(v.x)
		var hi := float(v.y)
		match t:
			CombatFormulas.DamageType.PHYSICS:
				lo *= 5.01; hi *= 5.01
			CombatFormulas.DamageType.FIRE:
				var x := 7.0 if series in [0, 1, 4] else (9.5 if series in [2, 3] else 0.0)
				lo *= 8.0 / 5.0; hi *= (x + 1.0) / 5.0
			CombatFormulas.DamageType.COLD:
				var y := 7.0 if series in [0, 3] else (9.5 if series in [2, 4] else 0.0)
				lo *= 8.0 / 5.0; hi *= (y + 1.0) / 5.0
			CombatFormulas.DamageType.LIGHT:
				var z := 7.0 if series in [0, 2, 3, 4] else (9.5 if series == 1 else 0.0)
				lo *= 8.0 / 10.0; hi *= (z + 1.0) / 10.0
		total += (lo + hi) * 0.5
	return total

func _ready() -> void:
	var only := OS.get_environment("AUDIT_SECT")
	for sect: SectDefinition in SectRegistry.load_all():
		if only != "" and sect.id != only:
			continue
		var profile := PlayerProfile.new()
		profile.sect_id = sect.id
		profile.level = 150
		for s in sect.skills:
			profile.skill_levels[s.id] = 20
		var ctrl := SectSkillController.new()
		ctrl.owner_profile = profile
		ctrl.setup(sect)
		var cs := profile.get_combat_stats()
		print("\n=== %s (unarmed %d~%d) ===" % [sect.id, cs.unarmed_min_damage, cs.unarmed_max_damage])
		for s: SkillDefinition in sect.skills:
			if s.category != SkillDefinition.SkillCategory.ACTIVE or not s.target_enemy or s.is_hidden:
				continue
			if only == "" and s.req_level < 150:
				continue
			var line := "%-28s req%3d %s hệ=%s ngũhành%%=" % [s.skill_name, s.req_level, "NGOAI" if s.is_physical() else "NOI  ", ElementTypes.ELEMENT_NAME[s.element]]
			var sup := s.get_support_percent_from_other_skills(sect.skills, profile)
			var parts_txt := ""
			for lv in LEVELS:
				profile.skill_levels[s.id] = lv
				var st := ctrl._resolve_stats(s, null)
				var parts := {}
				if st.damage_max > 0:
					parts[CombatFormulas.DamageType.PHYSICS] = Vector2i(int(st.damage_min), int(st.damage_max))
				for t in st.extra_damage_ranges:
					parts[t] = st.extra_damage_ranges[t]
				var raw := ""
				for t in parts:
					raw += "%s:%d~%d " % [CombatFormulas.DamageType.keys()[t], parts[t].x, parts[t].y]
				var per_hit := _scaled_avg(parts, int(s.element))
				var hits_txt := ""
				if s.vltk_skill_id > 0:
					var sk := VltkSkillData.skill(s.vltk_skill_id, lv)
					var mi := VltkSkillData.missile_for(sk)
					var life := int(mi.get("life", 0))
					var iv := int(mi.get("dmg_interval", 0))
					var per := int(ceil(float(life) / iv)) if iv > 0 and life > 0 else 1
					hits_txt = " | đạn=%d life=%d interval=%d ~%d nhịp => ~%.0f/chiêu" % [int(sk.get("child_num", 1)), life, iv, per, per_hit * per]
				parts_txt += "\n      L%-2d series%%=%-3d crit=%.0f%% raw[%s] => /nhịp ≈ %.0f%s" % [lv, st.five_elements_damage_p, st.crit_chance * 100.0, raw.strip_edges(), per_hit, hits_txt]
			profile.skill_levels[s.id] = 20
			print(line + " hỗ trợ=+%.0f%%" % sup + parts_txt)
		ctrl.free()
	get_tree().quit()

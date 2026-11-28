extends SceneTree
## In mọi skill của 1 phái: id gốc, nội/ngoại công, thuộc tính gốc (mốc Link) và số combat tại cấp 1/10/20/30.
## Chạy: godot --headless --path . --script res://scratch/dump_sect_skills.gd -- thien_nhan_giao

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var sect_file: String = args[0] if args.size() > 0 else "thien_nhan_giao"
	var sect = load("res://systems/sect/data/%s.tres" % sect_file)
	for skill in sect.skills:
		print("== %s | id=%s | vltk=%d | %s | %s | active=%s aura=%s enemy=%s parent=%s | form=%d" % [
			skill.skill_name, skill.id, skill.vltk_skill_id, "NGOAI" if skill.is_physical() else "NOI",
			skill.school_text, skill.category == 0, skill.is_aura, skill.target_enemy, skill.parent_skill_id,
			skill.vltk_missle_form])
		for a in skill.vltk_attribs:
			print("   attr %s = %s" % [a, skill.vltk_attribs[a]])
		for line in skill.stat_lines:
			print("   line %s" % line.format_at_level(skill, 20))
		if skill.category == 0:
			for lv in [1, 10, 20, 30]:
				var r: Dictionary = skill.get_combat_damage_at_level(lv)
				print("   L%d -> phys%%=%s flat=%s el=%s crit=%s series=%s" % [lv, r.physics_enhance, r.physics_flat,
					r.elements, r.deadly_strike, r.five_elements_damage_p])
	quit()

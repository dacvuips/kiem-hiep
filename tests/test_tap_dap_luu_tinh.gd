extends Node

func _ready() -> void:
	print("=== TEST TAP DAP LUU TINH ===")
	var tieu_dao: SectDefinition = load("res://systems/sect/data/tieu_dao.tres")
	assert(tieu_dao != null, "tieu_dao.tres failed to load")
	
	var tap_dap: SkillDefinition = null
	for s in tieu_dao.skills:
		if s.id == "tieu_dao_tap_dap_luu_tinh":
			tap_dap = s
			break
	assert(tap_dap != null, "Skill tieu_dao_tap_dap_luu_tinh not found in tieu_dao.tres")
	print("Found skill: ", tap_dap.skill_name, " ID: ", tap_dap.vltk_skill_id)
	
	assert(tap_dap.vltk_skill_id == 1885, "vltk_skill_id should be 1885")
	assert(tap_dap.vltk_missle_form == 13, "vltk_missle_form should be 13")
	assert(tap_dap.target_enemy == true, "target_enemy should be true")
	
	var supported := VltkSkillRunner.supports(tap_dap, 20)
	print("VltkSkillRunner.supports: ", supported)
	assert(supported == true, "VltkSkillRunner must support tap_dap")
	
	var s_data := VltkSkillData.skill(1885, 20)
	print("s_data form: ", s_data.get("form"), " child: ", s_data.get("child"))
	assert(int(s_data.get("form")) == 13, "form should be 13")
	assert(int(s_data.get("child")) == 100537, "child should be 100537")
	
	var m_data := VltkSkillData.missile_for(s_data)
	print("m_data name: ", m_data.get("name"), " anim: ", m_data["anims"][1]["anim"])
	assert(not m_data.is_empty(), "missile data must not be empty")
	assert(m_data["anims"][1]["anim"] == "fx_88b4dd05", "Phase fly anim must be fx_88b4dd05")
	
	var cd1 := tap_dap.get_cooldown_at_level(1)
	var cd20 := tap_dap.get_cooldown_at_level(20)
	print("Cooldown lv1: ", cd1, " lv20: ", cd20)
	assert(is_equal_approx(cd1, 15.0), "Cooldown at lv1 should be 15.0s")
	assert(is_equal_approx(cd20, 6.0), "Cooldown at lv20 should be 6.0s")

	## Kiểm tra nút skill ngoài map không được hiện tooltip
	var skill_btn_scene: PackedScene = load("res://ui/skill_bar/SkillButton.tscn")
	assert(skill_btn_scene != null, "SkillButton.tscn should load")
	var btn: SkillButton = skill_btn_scene.instantiate()
	add_child(btn)
	btn.setup(tap_dap, true)
	assert(btn.tooltip_text == "", "SkillButton on HUD must have empty tooltip_text")
	assert(btn._make_custom_tooltip("") == null, "SkillButton on HUD must not create custom tooltip")
	btn.queue_free()

	print("Testing VltkSkillRunner.execute call...")
	var caster := CharacterBody2D.new()
	add_child(caster)
	caster.global_position = Vector2(100, 100)

	var target := Node2D.new()
	add_child(target)
	target.global_position = Vector2(200, 100)

	var stats := ResolvedSkillStats.new()
	stats.damage = 100.0

	VltkSkillRunner.execute(caster, target, stats, tap_dap, 20)
	await get_tree().create_timer(0.4).timeout

	print("Execute finished without runtime error! Caster pos:", caster.global_position)
	print("ALL CHECKS PASSED SUCCESSFULLY!")
	get_tree().quit(0)

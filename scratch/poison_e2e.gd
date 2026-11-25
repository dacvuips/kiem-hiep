extends Node

func _ready() -> void:
	Engine.physics_ticks_per_second = 60
	var vm := VltkMonster.new()
	vm.monster_id = 36
	vm.data = MonsterData.monster(36).duplicate(true)
	vm.level = 20
	vm.ai_enabled = false
	add_child(vm)
	await get_tree().process_frame
	vm.health = 1.0e9
	vm.max_health = 1.0e9
	var atk := CombatantStats.new()
	atk.attack_rating = 99999
	print("khang doc quai: ", vm.combat_stats.get_capped_resist(CombatFormulas.DamageType.POISON), " he: ", vm.combat_stats.element)
	var sect: SectDefinition = load("res://systems/sect/data/ngu_doc_giao.tres")
	var vd: SkillDefinition = null
	for s in sect.skills:
		if s.id == "ngu_doc_van_doc_thuc_tam":
			vd = s
	print("van doc: is_state_skill=", vd.is_state_skill(), " category=", vd.category, " payload=", vd.get_state_payload(20))
	var pl := vd.get_state_payload(20)
	vm.status_controller.apply_state(vd.id, pl["attribs"], pl["seconds"], {"is_debuff": true})
	await get_tree().physics_frame
	print("quai poison_time_reduce_p=", vm.combat_stats.poison_time_reduce_p)
	var frame := 0
	var last_hp := vm.health
	for hit in 20:
		var mods := CombatFormulas.HitModifiers.new()
		mods.extra_damages = {CombatFormulas.DamageType.POISON: Vector2i(181, 181)}
		mods.poison_time_frames = 60
		mods.poison_interval_frames = 10
		mods.poison_tick_damage = 181
		mods.attacker_node = null
		vm.take_damage_from(atk, 0, 0, CombatFormulas.DamageType.PHYSICS, ElementTypes.ElementType.MOC, mods)
		var e: StatusEffect = vm.status_controller.get_effect("poison")
		print("don %d: doc/nhip=%s con %s frame" % [hit + 1, str(e.damage_per_tick) if e else "-", str(e.frames_left) if e else "-"])
		## 20 frame VLTK = 1.111 giay
		var t0 := Time.get_ticks_msec()
		var waited := 0.0
		while waited < 20.0 / 18.0:
			await get_tree().physics_frame
			waited += 1.0 / 60.0
	get_tree().quit(0)

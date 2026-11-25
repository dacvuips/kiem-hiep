extends "res://tests/net_tests.gd"
## ONLINE THẬT, phía CLIENT GAME (NetClient autoload + VltkMonster online như NetWorldSync dựng): đòn có Lôi sát choáng
## (stun_p) + Băng sát trúng quái server -> client tự báo server -> server giữ quái (bot B quan sát).

var _me_feet := Vector2.ZERO
var _spawned: Dictionary = {}   ## eid -> info (NetClient.entity_spawned)

func _me_walk(to: Vector2) -> void:
	for i in 200:
		var d := to - _me_feet
		if d.length() < 10.0:
			return
		_me_feet += d.limit_length(25.0)
		NetClient.send_move(_me_feet, 0, "run", 0, 0)
		await get_tree().create_timer(1.0 / 15.0).timeout

func run() -> void:
	var a_info := await make_player("ca")
	var b_info := await make_player("cb")
	var b := bot(b_info[0], b_info[1])
	NetClient.entity_spawned.connect(func(info: Dictionary) -> void: _spawned[int(info.eid)] = info)
	NetClient.connected_to_world.connect(func(_e: int, feet: Vector2, _n: String) -> void: _me_feet = feet)
	NetClient.connect_to({"host": HOST, "port": PORT}, a_info[0], a_info[1])
	var ok := await wait_until(func() -> bool: return NetClient.is_in_world() and b.in_world, 20.0)
	check("client game + bot B vào map", ok, [NetClient.status, b.error_code])
	if not ok:
		return
	## B tìm quái chủ động (quái đánh B), client mình đứng cạnh.
	check("B thấy quái", await wait_until(func() -> bool: return b.nearest_monster() != 0, 3.0) or await _walk_to_monsters(b))
	var m := 0
	var tried := {}
	for attempt in 5:
		var cand := 0
		var best := INF
		for id in b.known:
			if int(b.known[id].kind) == NetProto.KIND_MONSTER and not tried.has(id) and int(b.known[id].get("hp", 100)) > 0:
				var dd := (b.known[id].pos as Vector2).distance_to(b.feet)
				if dd < best:
					best = dd
					cand = id
		if cand == 0:
			break
		tried[cand] = true
		await _walk(b, (b.known[cand].pos as Vector2) + Vector2(40, 0))
		await _me_walk(b.feet + Vector2(0, 30))
		if await wait_until(func() -> bool: return int(b.attacked_by.get(cand, 0)) > 0, 8.0):
			m = cand
			break
	check("có quái chủ động đánh B", m != 0)
	if m == 0:
		return
	check("client mình nhận spawn quái", await wait_until(func() -> bool: return _spawned.has(m), 3.0))
	## Dựng quái online như NetWorldSync._spawn_monster.
	var info: Dictionary = _spawned[m]
	var vm := VltkMonster.new()
	vm.net_eid = m
	vm.monster_id = int(info.monster_id)
	vm.data = MonsterData.monster(int(info.monster_id)).duplicate()
	vm.data["series"] = int(info.series)
	vm.level = maxi(1, int(info.level))
	vm.ai_enabled = false
	vm.position = info.pos
	add_child(vm)
	await get_tree().process_frame

	## Đòn Thiên Vương có stun_p 100% + Băng sát ngoại công.
	var atk := CombatantStats.new()
	atk.attack_rating = 99999
	var mods := CombatFormulas.HitModifiers.new()
	mods.extra_damages = {CombatFormulas.DamageType.COLD: Vector2i(30, 30)}
	mods.freeze_frames = 90
	mods.stun_chance_p = 100
	mods.stun_frames = 54
	vm.take_damage_from(atk, 10, 10, CombatFormulas.DamageType.PHYSICS, ElementTypes.ElementType.KIM, mods)
	check("client: quái dính choáng + băng", vm.status_controller.is_stunned and vm.status_controller.has_effect("freeze"))
	check("server báo B: quái bị choáng", await wait_until(func() -> bool:
		return b.mstates.any(func(e: Array) -> bool: return int(e[0]) == m and int(e[1]) == NetProto.MSTATE_STUN), 2.0), b.mstates)
	check("server báo B: quái bị băng", await wait_until(func() -> bool:
		return b.mstates.any(func(e: Array) -> bool: return int(e[0]) == m and int(e[1]) == NetProto.MSTATE_FREEZE), 2.0), b.mstates)
	await get_tree().create_timer(0.4).timeout
	var atk0 := int(b.attacked_by.get(m, 0))
	await get_tree().create_timer(2.0).timeout
	check("choáng: quái thôi đánh B", int(b.attacked_by.get(m, 0)) == atk0, [atk0, b.attacked_by.get(m)])
	NetClient.disconnect_from_server()

extends "res://tests/net_tests.gd"
## ONLINE THẬT (game server thử): Lôi sát choáng (hình 50) + Băng sát (NetProto.MSTATE_FREEZE) trên quái của server.
##   - Choáng: quái đứng im hẳn, không ra chiêu tới khi hết; người khác nhận S_MSTATE.
##   - Băng: quái chạy chậm 1/2; người khác nhận S_MSTATE băng.
## Chạy cùng game server thử (xem server/test.sh): GAME_ENET_PORT=7917.

func run() -> void:
	var a_info := await make_player("sa")
	var b_info := await make_player("sb")
	var a := bot(a_info[0], a_info[1])
	var b := bot(b_info[0], b_info[1])
	var ok := await wait_until(func() -> bool: return a.in_world and b.in_world, 20.0)
	check("2 bot vào map", ok, [a.error_code, b.error_code])
	if not ok:
		return
	check("thấy quái", await wait_until(func() -> bool: return a.nearest_monster() != 0, 3.0) or await _walk_to_monsters(a), a.known.size())
	## Tìm quái chủ động: đứng sát -> quái ra chiêu.
	var m := 0
	var tried := {}
	for attempt in 5:
		var best := INF
		var cand := 0
		for id in a.known:
			if int(a.known[id].kind) == NetProto.KIND_MONSTER and not tried.has(id) and int(a.known[id].get("hp", 100)) > 0:
				var dd := (a.known[id].pos as Vector2).distance_to(a.feet)
				if dd < best:
					best = dd
					cand = id
		if cand == 0:
			break
		tried[cand] = true
		await _walk(a, (a.known[cand].pos as Vector2) + Vector2(40, 0))
		await _walk(b, a.feet + Vector2(0, 30))
		if await wait_until(func() -> bool: return int(a.attacked_by.get(cand, 0)) > 0, 8.0):
			m = cand
			break
	check("có quái chủ động ra chiêu vào A", m != 0, a.attacked_by)
	if m == 0:
		return

	## ---- Lôi sát: choáng 3 giây.
	a.monster_state(m, NetProto.MSTATE_STUN, 3.0)
	check("B nhận S_MSTATE choáng của quái", await wait_until(func() -> bool:
		return b.mstates.any(func(e: Array) -> bool: return int(e[0]) == m and int(e[1]) == NetProto.MSTATE_STUN), 2.0), b.mstates)
	await get_tree().create_timer(0.4).timeout   ## đòn đang bay (đã báo trước lúc choáng) không tính
	var atk0 := int(a.attacked_by.get(m, 0))
	var pos0: Vector2 = a.known[m].pos
	a.move_to(a.feet + Vector2(150, 0))         ## chạy ra xa: quái không choáng sẽ đuổi theo
	await get_tree().create_timer(2.2).timeout
	check("choáng: quái không ra chiêu", int(a.attacked_by.get(m, 0)) == atk0, [atk0, a.attacked_by.get(m)])
	check("choáng: quái đứng im", (a.known[m].pos as Vector2).distance_to(pos0) < 2.0, [pos0, a.known[m].pos])
	check("hết choáng: quái hoạt động lại (đuổi / ra chiêu)", await wait_until(func() -> bool:
		return int(a.attacked_by.get(m, 0)) > atk0 or (a.known[m].pos as Vector2).distance_to(pos0) > 5.0, 6.0))

	## ---- Băng sát: chậm 1/2. Đo quãng quái đuổi được trong 1 giây khi bình thường và khi bị băng.
	var walk_dist := func() -> float:
		await _walk(a, a.known[m].pos + Vector2(40, 0))
		await get_tree().create_timer(0.5).timeout
		a.move_to(a.feet + Vector2(25, 0))
		for i in 10:
			a.move_to(a.feet + Vector2(25, 0))
			await get_tree().create_timer(1.0 / 15.0).timeout
		var p1: Vector2 = a.known[m].pos
		await get_tree().create_timer(1.0).timeout
		return (a.known[m].pos as Vector2).distance_to(p1)
	var normal: float = await walk_dist.call()
	a.monster_state(m, NetProto.MSTATE_FREEZE, 6.0)
	check("B nhận S_MSTATE băng của quái", await wait_until(func() -> bool:
		return b.mstates.any(func(e: Array) -> bool: return int(e[0]) == m and int(e[1]) == NetProto.MSTATE_FREEZE), 2.0), b.mstates)
	var frozen: float = await walk_dist.call()
	print("  quãng đuổi 1 giây: thường %.0f px, bị băng %.0f px" % [normal, frozen])
	check("băng: quái đuổi chậm hơn hẳn", normal > 20.0 and frozen < normal * 0.75, [normal, frozen])

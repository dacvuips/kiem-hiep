extends Node
## Băng sát (m_FreezeState gốc): nhuộm VÀNG theo AdjustColor.txt dòng 2 (250, 255, 0)/256 — quái (offline + online),
## nhân vật đeo mặt nạ (modulate riêng không chặn màu), cờ ngoại hình online, quái server chậm 1/2.

var _fail := 0

func _check(ok: bool, msg: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + msg)
	if not ok:
		_fail += 1

func _yellow(c: Color) -> bool:
	return c.b < 0.05 and c.r > 0.9 and c.g > 0.9

func _spawn(net_eid: int) -> VltkMonster:
	var vm := VltkMonster.new()
	vm.net_eid = net_eid
	vm.monster_id = 36
	vm.data = MonsterData.monster(36).duplicate(true)
	vm.level = 20
	vm.ai_enabled = false
	add_child(vm)
	return vm

func _cold_mods() -> CombatFormulas.HitModifiers:
	var mods := CombatFormulas.HitModifiers.new()
	mods.extra_damages = {CombatFormulas.DamageType.COLD: Vector2i(50, 50)}
	mods.freeze_frames = 54
	return mods

func _ready() -> void:
	var atk := CombatantStats.new()
	atk.attack_rating = 99999
	for eid in [0, 777]:
		var vm := _spawn(eid)
		await get_tree().process_frame
		vm.take_damage_from(atk, 10, 10, CombatFormulas.DamageType.PHYSICS, ElementTypes.ElementType.KIM, _cold_mods())
		await get_tree().physics_frame
		await get_tree().physics_frame
		var body: Sprite2D = vm._sprite._sprite
		_check(vm.status_controller.has_effect("freeze"), "quái (net_eid %d) dính Băng sát" % eid)
		_check(_yellow(body.modulate), "quái (net_eid %d) thân nhuộm vàng %s" % [eid, body.modulate])
		_check(vm._sprite._shadow.modulate == Color.WHITE, "bóng quái không nhuộm")
		vm.status_controller.remove_effect("freeze")
		await get_tree().physics_frame
		_check(body.modulate == Color.WHITE, "hết băng -> thân quái trắng lại")
	## Quái online người khác làm băng (S_MSTATE).
	var vm2 := _spawn(778)
	await get_tree().process_frame
	vm2.net_apply_states([[NetProto.MSTATE_FREEZE, 3.0]])
	await get_tree().physics_frame
	_check(_yellow(vm2._sprite._sprite.modulate), "S_MSTATE băng -> quái nhuộm vàng")

	## Nhân vật đeo mặt nạ (avatar.modulate khác trắng): vẫn nhuộm vàng ở lớp bộ phận.
	var rp := RemotePlayer.new()
	rp.setup({"eid": 9001, "name": "Thu", "camp": 0, "look": {}, "pos": Vector2.ZERO, "dir": 0, "action": 0, "z": 0, "flags": 0, "hp": 100})
	add_child(rp)
	await get_tree().process_frame
	rp.avatar.modulate = Color(1.08, 0.88, 1.08)
	rp._refresh_state_sprites([NetProto.MSTATE_FREEZE])
	await get_tree().physics_frame
	_check(_yellow(rp.avatar._body.modulate), "người khác báo băng (đeo mặt nạ) -> nhuộm vàng %s" % rp.avatar._body.modulate)
	_check(rp.avatar.modulate == Color(1.08, 0.88, 1.08), "màu mặt nạ giữ nguyên")
	_check(is_equal_approx(rp.avatar.get_time_scale(), 0.5), "người bị băng: động tác chạy 1/2 nhịp")
	rp._refresh_state_sprites([])
	await get_tree().physics_frame
	_check(rp.avatar._body.modulate == Color.WHITE, "hết cờ băng -> hết vàng")
	_check(is_equal_approx(rp.avatar.get_time_scale(), 1.0), "hết băng: động tác về nhịp thường")

	## Quái offline bị băng: nhịp động tác + nhịp nghĩ (_game_time) chậm 1/2 (KNpc::ProcessState gốc).
	var vm3 := _spawn(0)
	await get_tree().physics_frame
	var g0: float = vm3._game_time
	for i in 10:
		await get_tree().physics_frame
	var normal_rate: float = vm3._game_time - g0
	vm3.status_controller.apply_effect(StatusEffect.new("freeze", 5.0, 0.0, 1.0, StatusEffectController.VLTK_FREEZE_SLOW))
	g0 = vm3._game_time
	for i in 10:
		await get_tree().physics_frame
	var frozen_rate: float = vm3._game_time - g0
	_check(absf(frozen_rate - normal_rate * 0.5) < 0.6, "quái bị băng: nhịp hành động 1/2 (%.1f -> %.1f)" % [normal_rate, frozen_rate])

	## Server: quái bị băng chạy 1/2 nhịp.
	var sm := ServerMonster.from_entry({"t": 36, "lv": 20, "px": 0.0, "py": 0.0, "respawn": 40}, 1)
	var gs := GameServer.new()
	gs._now = 100.0
	var t0 := sm._game_time
	sm.tick(gs, 2)
	var normal := sm._game_time - t0
	sm.vis_states[NetProto.MSTATE_FREEZE] = 105.0
	t0 = sm._game_time
	for i in 4:
		sm.tick(gs, 2)
	_check(normal == 2 and sm._game_time - t0 == 4, "server: băng -> 8 nhịp chỉ chạy 4 (được %s)" % (sm._game_time - t0))
	## Choáng (Lôi sát, hình trạng thái 50): server đứng im hẳn.
	sm.vis_states.erase(NetProto.MSTATE_FREEZE)
	sm.vis_states[NetProto.MSTATE_STUN] = 102.0
	t0 = sm._game_time
	var sf0: float = sm._state_frames
	for i in 10:
		sm.tick(gs, 2)
	_check(sm._game_time == t0 and sm._state_frames == sf0, "server: choáng -> quái không chạy nhịp nào (đứng im, đòn đang ra cũng dừng)")
	gs._now = 103.0
	sm.tick(gs, 2)
	_check(sm._game_time > t0, "server: hết choáng -> quái chạy lại")
	gs.free()

	print("RESULT: ", "PASS" if _fail == 0 else "FAIL %d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

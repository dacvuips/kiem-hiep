extends Node
## Bùa trên quái khi chơi online: người đánh báo server (C_MSTATE) -> server nhớ + gửi S_MSTATE -> máy người khác vẽ hình.
## Chạy: Godot --headless res://tests/monster_state_sync_tests.tscn

var _fail := 0

func _check(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fail += 1

func _ready() -> void:
	## --- Server: nhớ bùa, gói S_MSTATE chỉ chứa bùa còn hạn.
	var gs := GameServer.new()
	var sm := ServerMonster.from_entry({"t": 36, "lv": 20, "px": 0.0, "py": 0.0, "respawn": 40}, 1)
	sm.eid = 777
	sm.vis_states[63] = 5.0        ## Thúc Phược Chú còn 5 giây
	sm.vis_states[13] = -1.0       ## đã hết hạn
	var pkt := gs._mstate_packet(sm)
	_check(pkt != null, "Server dựng được gói bùa của quái")
	pkt.seek(1)
	var eid := pkt.get_u32()
	var n := pkt.get_u8()
	var sid := pkt.get_u32()
	var ds := pkt.get_u16()
	_check(eid == 777 and n == 1 and sid == 63 and ds == 50, "Gói chỉ có bùa còn hạn (63, 5 giây)")
	_check(not sm.vis_states.has(13), "Bùa hết hạn bị dọn khỏi quái")
	_check(gs._mstate_packet(sm, 99) == null, "Lọc theo 1 bùa không có -> không gửi")
	sm._enter(ServerMonster.State.DEAD, "die")
	_check(sm.vis_states.is_empty(), "Quái chết -> xoá hết bùa")
	gs.free()

	## --- Client: quái online nhận bùa từ server thì vẽ, không báo ngược lên server.
	var vm := VltkMonster.new()
	vm.monster_id = 36
	vm.data = MonsterData.monster(36).duplicate(true)
	vm.level = 20
	vm.ai_enabled = false
	vm.net_eid = 777
	add_child(vm)
	vm.net_apply_states([[63, 4.0]])
	_check(vm.status_controller.has_state(VltkMonster.NET_STATE_PREFIX + "63"), "Quái online nhận bùa từ server")
	var ids := []
	for st in vm.status_controller.get_state_display_list():
		ids.append(int(st["meta"].get("state_id", 0)))
	_check(ids.has(63), "Bùa nhận về có state_id để vẽ hình")
	await get_tree().process_frame
	await get_tree().process_frame
	var has_sprite := false
	for ch in vm.get_children():
		if ch is VltkStateSprite and (ch as VltkStateSprite).state_id == 63:
			has_sprite = true
	_check(has_sprite, "Hình bùa 63 được gắn lên quái")

	print("RESULT fail=%d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

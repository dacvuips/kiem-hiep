extends Node
## Ẩn thân Thúy Yên (Ngự Tuyết Ẩn 120 / Huyền Băng Vô Tắc 180 -> Dung Tuyết Vô Tung) theo source VLTK gốc:
## số liệu lua, trạng thái "hide", hiện hình khi ra chiêu, quái/bot bỏ mục tiêu, cờ FLAG_HIDE qua mạng (u16, NetProto v6).

var _passes := 0
var _fails := 0

func check(desc: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("PASS ", desc)
	else:
		_fails += 1
		print("FAIL ", desc)

func _ready() -> void:
	var sect: SectDefinition = load("res://systems/sect/data/thuy_yen_mon.tres")
	var hb: SkillDefinition = null
	var ngu_tuyet: SkillDefinition = null
	for s: SkillDefinition in sect.skills:
		if s.id == HideSkill.HUYEN_BANG_VO_TAC_ID:
			hb = s
		elif s.id == "thuy_yen_cuiyan120":
			ngu_tuyet = s
	check("Có Huyền Băng Vô Tắc + Ngự Tuyết Ẩn", hb != null and ngu_tuyet != null)

	## advancedskill.lua cy_adskill: ẩn 2 giây (cấp 1) -> 5 giây (cấp 20); 5% / 20 giây -> 10% / 10 giây.
	check("Dung Tuyết Vô Tung cấp 1 ẩn 2 giây", is_equal_approx(HideSkill.dung_tuyet_seconds(1), 2.0))
	check("Dung Tuyết Vô Tung cấp 20 ẩn 5 giây", is_equal_approx(HideSkill.dung_tuyet_seconds(20), 5.0))
	var r1 := HideSkill.auto_reply(hb, 1)
	var r20 := HideSkill.auto_reply(hb, 20)
	check("Huyền Băng cấp 1: 5%% / 20 giây (%s)" % r1, int(r1.rate) == 5 and is_equal_approx(float(r1.wait), 20.0))
	check("Huyền Băng cấp 20: 10%% / 10 giây (%s)" % r20, int(r20.rate) == 10 and is_equal_approx(float(r20.wait), 10.0))
	## cuiyan.lua cuiyan120: hide[2] {1, 5*18}, {15, 25*18}, {20, 30*18}.
	check("Ngự Tuyết Ẩn là skill ẩn thân", HideSkill.is_hide_skill(ngu_tuyet) and not HideSkill.is_hide_skill(hb))
	check("Ngự Tuyết Ẩn cấp 1 = 5 giây", is_equal_approx(HideSkill.seconds_of(ngu_tuyet, 1), 5.0))
	check("Ngự Tuyết Ẩn cấp 20 = 30 giây", is_equal_approx(HideSkill.seconds_of(ngu_tuyet, 20), 30.0))
	var payload := ngu_tuyet.get_state_payload(20)
	check("Trạng thái Ngự Tuyết Ẩn mang 'hide', 30 giây", (payload.attribs as Dictionary).has("hide") and is_equal_approx(float(payload.seconds), 30.0))

	## Trạng thái trên nhân vật: ẩn / hiện hình khi ra chiêu.
	var actor := Node2D.new()
	var st := StatusEffectController.new()
	st.name = "StatusEffectController"
	actor.add_child(st)
	add_child(actor)
	check("Chưa ẩn", not st.is_hidden())
	st.apply_state("buff_khac", {"lifemax_p": Vector3i(10, 0, 0)}, 10.0)
	st.apply_state("thuy_yen_dung_tuyet_vo_tung", {"hide": Vector3i(1, 0, 0)}, 2.0)
	check("Đang ẩn", st.is_hidden())
	check("Ra chiêu -> hiện hình", st.break_hide() and not st.is_hidden())
	check("Buff khác vẫn còn", st.has_state("buff_khac"))
	check("Không ẩn thì break_hide không làm gì", not st.break_hide())
	st.apply_state("thuy_yen_dung_tuyet_vo_tung", {"hide": Vector3i(1, 0, 0)}, 0.5)
	st._tick_states(0.6)
	check("Hết giờ thì tự hiện", not st.is_hidden())

	## Quái / bot offline: người chơi máy này ẩn -> PlayerStealth báo ẩn.
	actor.add_to_group("player")
	PlayerStealth.local_is_hidden = true
	check("Người chơi máy này đang ẩn", PlayerStealth.is_hidden(actor) and PlayerStealth.local_hidden())
	PlayerStealth.local_is_hidden = false
	check("Hết ẩn", not PlayerStealth.is_hidden(actor))
	check("Quái không bị coi là ẩn", not PlayerStealth.is_hidden(Node2D.new()))

	## Mạng: cờ FLAG_HIDE (bit 8) đi qua S_STATE u16.
	var e := ServerEntity.new()
	e.flags = NetProto.FLAG_HIDE | NetProto.FLAG_PK
	var b := StreamPeerBuffer.new()
	e.write_state(b, 1000)
	b.seek(0)
	b.get_u32()
	NetProto.get_state_pos(b)
	b.get_u8()
	b.get_u8()
	var fl := b.get_u16()
	check("S_STATE mang FLAG_HIDE + FLAG_PK", fl == NetProto.FLAG_HIDE | NetProto.FLAG_PK)
	check("Game không tự đặt FLAG_HIDE qua C_MOVE", (NetProto.CLIENT_FLAGS & NetProto.FLAG_HIDE) == 0)

	## Máy người khác: RemotePlayer có cờ ẩn -> không vẽ, không chọn làm mục tiêu.
	var r := RemotePlayer.new()
	add_child(r)
	r.setup({"eid": 7, "name": "Thúy Yên", "level": 180, "camp": 0, "look": {}, "pos": Vector2(100, 100),
			"flags": NetProto.FLAG_HIDE, "action": 0, "dir": 0, "hp": 100, "z": 0})
	check("Người khác đang ẩn: không vẽ", r.is_hidden() and not r.visible)
	check("Người khác đang ẩn: PlayerStealth báo ẩn", PlayerStealth.is_hidden(r))
	r._apply({"flags": 0, "action": 0, "dir": 0, "hp": 100, "z": 0})
	check("Hết ẩn: vẽ lại", not r.is_hidden() and r.visible)

	print("RESULT %d/%d" % [_passes, _passes + _fails])
	get_tree().quit(0 if _fails == 0 else 1)

extends Node
## Buff đồng đội / hào quang hỗ trợ theo VLTK gốc:
##   - vùng = hình VUÔNG ±DmgRange/2 ô logic (KMissle::ProcessCollision), y logic = 2 × màn hình;
##   - chỉ đồng đội CÙNG PHE (màu tên) nhận; 2 Sát thủ / cừu sát không nhận;
##   - dữ liệu tầm của từng skill buff khớp Skills.txt / Missles.txt VNG (hào quang lấy đạn của skill con).

var _pass := 0
var _fail := 0

## Nhân vật giả: chân = global_position, có phe + StatusEffectController.
class Dummy extends Node2D:
	var camp := Camp.Type.JUSTICE
	var pk_enemy := false
	func get_effective_camp() -> int:
		return camp
	func get_ground_position() -> Vector2:
		return global_position

func check(desc: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS ", desc)
	else:
		_fail += 1
		print("FAIL ", desc)

func _ready() -> void:
	_test_cells()
	_test_data()
	_test_receive()
	_test_local_aura()
	print("RESULT %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _dummy(pos: Vector2, camp: int, group := "") -> Dummy:
	var d := Dummy.new()
	d.camp = camp
	d.position = pos
	var st := StatusEffectController.new()
	st.name = "StatusEffectController"
	d.add_child(st)
	if group != "":
		d.add_to_group(group)
	add_child(d)
	return d

func _test_cells() -> void:
	var center := Vector2(16, 8)   ## giữa ô logic (0, 0)
	var n := _dummy(Vector2.ZERO, Camp.Type.JUSTICE)
	n.position = Vector2(16 + 5 * 32, 8)
	check("DmgRange 10: cách 5 ô ngang -> trong vùng", CombatTargeting.in_vltk_cells(center, n, 10))
	n.position = Vector2(16 + 6 * 32, 8)
	check("DmgRange 10: cách 6 ô ngang -> ngoài vùng", not CombatTargeting.in_vltk_cells(center, n, 10))
	n.position = Vector2(16, 8 + 5 * 16)
	check("DmgRange 10: dọc 80px màn hình (5 ô logic) -> trong vùng", CombatTargeting.in_vltk_cells(center, n, 10))
	n.position = Vector2(16, 8 + 6 * 16)
	check("DmgRange 10: dọc 96px màn hình (6 ô logic) -> ngoài vùng (vùng dẹt như gốc)", not CombatTargeting.in_vltk_cells(center, n, 10))
	n.position = Vector2(16 + 5 * 32, 8 + 5 * 16)
	check("vùng VUÔNG: góc (5, 5) ô vẫn trong vùng", CombatTargeting.in_vltk_cells(center, n, 10))
	n.position = Vector2(16 + 32, 8)
	check("DmgRange 1: chỉ đúng ô tâm", not CombatTargeting.in_vltk_cells(center, n, 1) and CombatTargeting.in_vltk_cells(center, n, 3))
	n.queue_free()

func _skill(vltk_id: int) -> SkillDefinition:
	return SectSkillController.skill_by_vltk_id(vltk_id)

func _test_data() -> void:
	## {vltk id: [có vùng đồng đội, DmgRange]} — theo Skills.txt / Missles.txt VNG (+ bản 15 phái cho phái mới).
	var expect := {
		171: [true, 3],    ## Thanh Phong phù -> đạn 19
		93: [true, 5],     ## Từ Hàng Phổ Độ -> đạn 5
		15: [true, 10],    ## Bất Động Minh Vương -> đạn 76
		716: [true, 10],   ## Xuất Ứ Bất Nhiễm -> đạn 274
		86: [true, 10], 89: [true, 10], 92: [true, 10], 282: [true, 10], 712: [true, 10],   ## hào quang Nga Mi -> skill con -> đạn 92
		332: [true, 14],   ## Phổ Độ Chúng Sinh -> skill 333 -> đạn 137
		16: [true, 10],    ## La Hán Trận
		159: [true, 10],   ## Thất Tinh Trận
		178: [false, 0],   ## Nhất Khí Tam Thanh: VNG SkillStyle 3 (bị động lên mình)
		173: [false, 0],   ## Thiên Thanh Địa Trọc: VNG SkillStyle 3
		277: [false, 3],   ## Hoạt Bất Lưu Thủ: chỉ TargetSelf
		1773: [true, 7], 1376: [true, 5], 1384: [true, 1], 1965: [true, 5],
	}
	for id: int in expect:
		var sk := _skill(id)
		if sk == null:
			check("có skill %d" % id, false)
			continue
		var want: Array = expect[id]
		check("%s (%d): vùng đồng đội=%s DmgRange=%d" % [sk.skill_name, id, want[0], want[1]],
			SectSkillController.has_ally_area(sk) == want[0] and sk.vltk_damage_range == want[1])

func _test_receive() -> void:
	var me := _dummy(Vector2(100, 100), Camp.Type.JUSTICE, "player")
	var ally := _dummy(Vector2(100 + 2 * 32, 100), Camp.Type.JUSTICE)
	var other := _dummy(Vector2(100 + 2 * 32, 100), Camp.Type.EVIL)
	var far := _dummy(Vector2(100 + 4 * 32, 100), Camp.Type.JUSTICE)
	var tpp := _skill(171)   ## Thanh Phong phù, DmgRange 3 -> ±1 ô
	var st: StatusEffectController = me.get_node("StatusEffectController")
	check("Thanh Phong phù đồng đội cách 2 ô: ngoài vùng ±1 ô -> không nhận",
		not SectSkillController.receive_ally_support(me, ally, tpp, 10, false))
	ally.position = Vector2(100 + 32, 100)
	check("Thanh Phong phù đồng đội cùng phe cách 1 ô -> nhận",
		SectSkillController.receive_ally_support(me, ally, tpp, 10, false) and st.has_method("get_state_display_list") and st.get_state_display_list().size() == 1)
	other.position = ally.position
	check("khác phe (khác màu tên) -> không nhận", not SectSkillController.receive_ally_support(me, other, tpp, 10, false))
	check("đồng đội ở xa -> không nhận", not SectSkillController.receive_ally_support(me, far, tpp, 10, false))
	ally.pk_enemy = true
	check("đang cừu sát -> không nhận", not SectSkillController.receive_ally_support(me, ally, tpp, 10, false))
	ally.pk_enemy = false
	var free_a := _dummy(ally.position, Camp.Type.FREE)
	me.camp = Camp.Type.FREE
	check("2 Sát thủ (cùng màu đỏ) vẫn là địch -> không nhận", not SectSkillController.receive_ally_support(me, free_a, tpp, 10, false))
	me.camp = Camp.Type.JUSTICE
	check("buff chỉ cho mình (Kim Chung Tráo) -> người khác không nhận", not SectSkillController.receive_ally_support(me, ally, _skill(42), 10, false))
	## Hào quang Lưu Thủy: 10 ô, 18 frame = 1 giây, chỉ thuộc tính (bỏ skill_*).
	var ls := _skill(86)
	var p := SectSkillController.aura_ally_payload(ls, 20)
	check("Lưu Thủy cấp 20 -> fastwalkrun_p 66, 1 giây",
		(p["attribs"] as Dictionary).has("fastwalkrun_p") and int(p["attribs"]["fastwalkrun_p"].x) == 66 and is_equal_approx(float(p["seconds"]), 1.0))
	ally.position = Vector2(100 + 5 * 32, 100)
	check("hào quang Lưu Thủy: đồng đội cách 5 ô -> nhận",
		SectSkillController.receive_ally_support(me, ally, ls, 20, true))
	check("hào quang không nhận qua đường buff thường", not SectSkillController.receive_ally_support(me, ally, ls, 20, false))
	for n in [me, ally, other, far, free_a]:
		n.queue_free()

## Máy người bật hào quang (offline / chính mình): đồng đội trong nhóm "player" cùng phe trong vùng nhận "aura:<id>", bản thân không.
func _test_local_aura() -> void:
	var caster := _dummy(Vector2(300, 300), Camp.Type.BALANCE, "player")
	var near := _dummy(Vector2(300 + 3 * 32, 300), Camp.Type.BALANCE, "player")
	var enemy := _dummy(Vector2(300 + 3 * 32, 300), Camp.Type.EVIL, "player")
	var ctl := SectSkillController.new()
	caster.add_child(ctl)
	ctl._apply_aura_to_allies(_skill(159), caster, 20)   ## Thất Tinh Trận
	var near_st: StatusEffectController = near.get_node("StatusEffectController")
	var caster_st: StatusEffectController = caster.get_node("StatusEffectController")
	var enemy_st: StatusEffectController = enemy.get_node("StatusEffectController")
	check("Thất Tinh Trận: đồng đội cùng phe trong vùng nhận", near_st.get_state_display_list().size() == 1)
	check("Thất Tinh Trận: bản thân không nhận thêm (đã có qua CombatantBuild)", caster_st.get_state_display_list().is_empty())
	check("Thất Tinh Trận: khác phe không nhận", enemy_st.get_state_display_list().is_empty())
	for n in [caster, near, enemy]:
		n.queue_free()

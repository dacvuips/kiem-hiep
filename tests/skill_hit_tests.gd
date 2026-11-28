extends Node
## Rà soát skill đánh quái (Võ Đang): độ chính xác của skill vào roll trúng, skill con tính qua AppendSkillEffect (có hỗ trợ),
## gom sát thương online (C_DAMAGE_BATCH) + ngân sách đòn/giây của server:
##   godot --headless --path . res://tests/skill_hit_tests.tscn
var _fail := 0
func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

class FakeCaster extends Node2D:
	var combat_stats: CombatantStats
	var skill_controller: SectSkillController
	var mana := 0.0

func _ready() -> void:
	test_hit_attack_rating()
	test_skill_attack_rating_in_stats()
	test_event_skill_uses_support()
	test_client_damage_batching()
	test_server_damage_budget()
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _vo_dang_profile(level: int) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.set_sect(SectRegistry.get_by_id("vo_dang"))
	profile.level = 150
	for s in SectRegistry.get_by_id("vo_dang").skills:
		profile.skill_levels[s.id] = level
	return profile

func test_hit_attack_rating() -> void:
	var s := CombatantStats.new()
	s.attack_rating = 900      ## đã cộng trang bị / buff
	s.base_attack_rating = 772 ## từ Thân pháp
	check("Không có attackrating_p: AR hiện tại", CombatFormulas.hit_attack_rating(s, null) == 900)
	var mods := CombatFormulas.HitModifiers.new()
	mods.attack_rating_p = 415
	check("attackrating_p 415%: 900 + 772*415/100 = 4103", CombatFormulas.hit_attack_rating(s, mods) == 900 + 772 * 415 / 100)
	check("Tỉ lệ trúng vs phòng thủ 990 tăng từ ~47% lên >= 80%",
		CombatFormulas.calc_hit_percent(900, 990) < 50 and CombatFormulas.calc_hit_percent(CombatFormulas.hit_attack_rating(s, mods), 990) >= 80)
	var d := PvpHit.decode(PvpHit.encode(s, 1, 2, 0, 4, mods))
	PvpHit.sanitize(d, 1000.0)
	check("PvpHit mang attack_rating_p qua mạng", int(d["mods"].get("attack_rating_p", 0)) == 415)
	d["mods"]["attack_rating_p"] = 999999
	PvpHit.sanitize(d, 1000.0)
	check("PvpHit chặn attack_rating_p vô lý", int(d["mods"]["attack_rating_p"]) <= 1000)

func test_skill_attack_rating_in_stats() -> void:
	var profile := _vo_dang_profile(20)
	var ctrl := SectSkillController.new()
	ctrl.owner_profile = profile
	ctrl.setup(SectRegistry.get_by_id("vo_dang"))
	var ktth := ctrl.find_by_vltk_id(1079)
	check("Tìm Kiếm Thùy Tinh Hà theo SkillId 1079", ktth != null and ktth.id == "vo_dang_kiem_thuy_tinh_ha")
	var st := ctrl._resolve_stats(ktth, null)
	check("Kiếm Thùy Tinh Hà cấp 20: độ chính xác 415%% (được %d)" % st.attack_rating_p, st.attack_rating_p == 415)
	check("make_hit_mods chép độ chính xác", st.make_hit_mods(null).attack_rating_p == 415)
	var st5 := ctrl._resolve_stats(ktth, null, 5)
	check("level_override: cấp 5 thấp hơn cấp 20", st5.attack_rating_p < 415 and st5.attack_rating_p > 78)
	ctrl.free()

func test_event_skill_uses_support() -> void:
	var profile := _vo_dang_profile(20)
	var caster := FakeCaster.new()
	add_child(caster)
	caster.combat_stats = profile.get_combat_stats()
	var ctrl := SectSkillController.new()
	ctrl.owner_profile = profile
	ctrl.setup(SectRegistry.get_by_id("vo_dang"))
	caster.skill_controller = ctrl
	caster.add_child(ctrl)
	var ctx := VltkCastContext.new()
	ctx.launcher = caster
	ctx.attacker_stats = caster.combat_stats
	var s := VltkSkillData.skill(1107, 20)   ## Kiếm Minh Thương Khung (sự kiện của Kiếm Thùy Tinh Hà)
	var ev := VltkSkillCaster._resolve_event_context(ctx, s, 20)
	var light: Vector2i = ev.stats.extra_damage_ranges.get(CombatFormulas.DamageType.LIGHT, Vector2i.ZERO)
	## Lua gốc cấp 20: Lôi sát 12~120; hỗ trợ +220% từ Kiếm Phi Kinh Thiên cấp 20 -> tối đa >= 120*3.2 = 384.
	check("Kiếm Minh Thương Khung có hỗ trợ +220%% (Lôi tối đa %d >= 384)" % light.y, light.y >= 384)
	var s2 := VltkSkillData.skill(1105, 20)  ## Kiếm Vũ Diệu Nguyệt: physicsenhance_p 280% + hỗ trợ nếu có
	var ev2 := VltkSkillCaster._resolve_event_context(ctx, s2, 20)
	check("Kiếm Vũ Diệu Nguyệt có độ chính xác/chí mạng theo bảng phái", ev2.stats != null and ev2.stats.crit_chance > 0.0)
	## Quái / người thi triển không có SectSkillController: giữ đường tính thô cũ.
	var ctx2 := VltkCastContext.new()
	ctx2.launcher = Node2D.new()
	add_child(ctx2.launcher)
	var ev3 := VltkSkillCaster._resolve_event_context(ctx2, s, 20)
	var light3: Vector2i = ev3.stats.extra_damage_ranges.get(CombatFormulas.DamageType.LIGHT, Vector2i.ZERO)
	check("Không có bảng phái: Lôi thô 12~120 như lua (được %s)" % light3, light3 == Vector2i(12, 120))
	ctx2.launcher.queue_free()
	caster.queue_free()

func test_client_damage_batching() -> void:
	var prev_status: int = NetClient.status
	NetClient.status = NetClient.Status.IN_WORLD
	NetClient._pending_damage.clear()
	for i in 10:
		NetClient.send_damage(111, 100.0, i == 3)
	NetClient.send_damage(222, 50.0, false)
	var e: Array = NetClient._pending_damage.get(111, [])
	check("Gom 10 đòn quái 111: tổng 1000, 10 đòn, có khựng", e.size() == 3 and int(e[0]) == 1000 and int(e[1]) == 10 and bool(e[2]))
	check("Quái 222 gom riêng", int(NetClient._pending_damage.get(222, [0, 0])[1]) == 1)
	NetClient._flush_damage()   ## không có peer: _send bỏ qua, chỉ dọn bộ đệm
	check("Flush dọn bộ đệm", NetClient._pending_damage.is_empty())
	NetClient.status = prev_status

func test_server_damage_budget() -> void:
	var gs: GameServer = load("res://net/server/game_server.gd").new()
	var c := GameServer.Conn.new()
	gs._now = 10.0
	## 1 gói gộp 3 quái x 60 đòn (quái không tồn tại -> chỉ kiểm ngân sách đòn).
	var b := StreamPeerBuffer.new()
	b.put_u8(3)
	for eid in [9001, 9002, 9003]:
		b.put_u32(eid)
		b.put_u32(5000)
		b.put_u8(1 | (60 << NetProto.DAMAGE_HITS_SHIFT))
	b.seek(0)
	gs._on_damage_batch(c, b)
	check("Ngân sách đếm theo số đòn gộp (180)", c.damage_msgs == 180)
	var b2 := StreamPeerBuffer.new()
	b2.put_u8(5)
	for eid in [9004, 9005, 9007, 9008, 9009]:
		b2.put_u32(eid)
		b2.put_u32(5000)
		b2.put_u8(60 << NetProto.DAMAGE_HITS_SHIFT)
	b2.seek(0)
	gs._on_damage_batch(c, b2)
	check("Vượt ngân sách %d đòn/giây thì dừng" % GameServer.MAX_DAMAGE_PER_SEC, c.damage_msgs == GameServer.MAX_DAMAGE_PER_SEC)
	gs._now = 11.5
	var b3 := StreamPeerBuffer.new()
	b3.put_u32(9006)
	b3.put_u32(10)
	b3.put_u8(0)
	b3.seek(0)
	gs._on_damage(c, b3)
	check("Gói C_DAMAGE cũ = 1 đòn, giây mới tính lại", c.damage_msgs == 1)
	gs.free()

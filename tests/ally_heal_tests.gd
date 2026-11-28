extends Node
## Buff hồi sinh lực đồng đội (Từ Hàng Phổ Độ, Nga Mi) với nhân vật THẬT: người ra chiêu ở máy mình (offline) và máy đồng đội nhận
## qua receive_ally_support (online) — đồng đội phải hồi máu thật + có hiệu ứng quanh người.
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/ally_heal_tests.tscn
var _fail := 0
func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

func _ready() -> void:
	await test_receive_online()
	await test_caster_fx()
	await test_aura_visual()
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _skill(vltk_id: int) -> SkillDefinition:
	return SectSkillController.skill_by_vltk_id(vltk_id)

## Máy đồng đội: người chơi Nga Mi khác (RemotePlayer) ra Từ Hàng Phổ Độ cách mình 2 ô -> mình nhận trạng thái + hồi máu.
func test_receive_online() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "Dong Doi"
	profile.set_sect(SectRegistry.get_by_id("thieu_lam"))
	GameManager.local_profile = profile
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = {}
	var me: Node2D = load("res://player/player.tscn").instantiate()
	add_child(me)
	me.global_position = Vector2(200, 200)
	await get_tree().process_frame
	var r := _remote(77, "Nga Mi", CombatTargeting.get_camp(me), VltkMath.ground_of(me) + (me.global_position + Vector2(2 * 32, 0) - me.global_position))
	await get_tree().process_frame
	var sk := _skill(93)
	check("có Từ Hàng Phổ Độ", sk != null)
	print("phe mình=", CombatTargeting.get_camp(me), " phe họ=", CombatTargeting.get_camp(r))
	me.health = 100.0
	var before_rep: int = me.combat_stats.life_replenish
	var ok := SectSkillController.receive_ally_support(me, r, sk, 10, false)
	check("nhận buff qua đường online", ok)
	await get_tree().process_frame
	await get_tree().process_frame
	print("life_replenish trước=", before_rep, " sau=", me.combat_stats.life_replenish)
	check("chỉ số hồi sinh lực tăng", me.combat_stats.life_replenish > before_rep)
	var h0: float = me.health
	for i in 60:
		await get_tree().physics_frame
	print("máu: ", h0, " -> ", me.health)
	check("máu tăng thật", me.health > h0)
	var vis: Array = me.get_node("StatusEffectController").get_state_display_list()
	print("trạng thái hiển thị: ", vis.size(), " ", vis)
	me.queue_free()
	r.queue_free()

## Máy người ra chiêu: Nga Mi ra Từ Hàng Phổ Độ -> mình + đồng đội trong vùng nhận trạng thái và có vòng dưới chân (hình va chạm đạn 5).
func test_caster_fx() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "Nga Mi"
	profile.set_sect(SectRegistry.get_by_id("nga_mi"))
	profile.level = 90
	var sk := _skill(93)
	profile.skill_levels[sk.id] = 10
	GameManager.local_profile = profile
	var me: Node2D = load("res://player/player.tscn").instantiate()
	add_child(me)
	me.global_position = Vector2(400, 400)
	await get_tree().process_frame
	var near := _remote(88, "Gan", CombatTargeting.get_camp(me), VltkMath.ground_of(me) + (me.global_position + Vector2(4 * 32, 0) - me.global_position))
	var far := _remote(89, "Xa", CombatTargeting.get_camp(me), VltkMath.ground_of(me) + (me.global_position + Vector2(9 * 32, 0) - me.global_position))
	await get_tree().process_frame
	me.mana = 99999.0
	var ctl: SectSkillController = me.skill_controller
	ctl.tick(10.0)
	check("ra được Từ Hàng Phổ Độ", ctl._try_cast(sk, me, null))
	var key := "_ally_fx_until_93"
	check("vòng dưới chân người ra chiêu", me.has_meta(key))
	check("vòng dưới chân đồng đội cách 4 ô", near.has_meta(key))
	check("đồng đội cách 9 ô ngoài vùng -> không vòng", not far.has_meta(key))
	## Máy người thứ ba: thấy người khác ra chiêu -> vẽ vòng cho mọi người cùng phe trong vùng.
	near.remove_meta(key)
	SectSkillController.play_ally_hit_fx_around(me, sk, 10)
	check("đường online vẽ vòng cho đồng đội", near.has_meta(key))
	for n in [me, near, far]:
		n.queue_free()

## Người chơi khác giả (như gói S_SPAWN): chân đứng tại `feet`.
func _remote(eid: int, pname: String, camp: int, feet: Vector2) -> RemotePlayer:
	var r := RemotePlayer.new()
	add_child(r)
	r.setup({"eid": eid, "name": pname, "level": 90, "camp": camp, "look": {}, "pos": feet, "flags": 0, "action": 0,
			"dir": 0, "hp": 100, "z": 0})
	return r

## Hào quang hỗ trợ Nga Mi: bật lên -> hình dưới chân người bật (state 39 Lưu Thủy...) + đồng đội cùng phe trong vùng cũng có hình.
func test_aura_visual() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "Nga Mi"
	profile.set_sect(SectRegistry.get_by_id("nga_mi"))
	profile.level = 90
	var ls := _skill(86)
	profile.skill_levels[ls.id] = 10
	GameManager.local_profile = profile
	var me: Node2D = load("res://player/player.tscn").instantiate()
	add_child(me)
	me.global_position = Vector2(400, 400)
	await get_tree().process_frame
	var near := _remote(91, "Gan", CombatTargeting.get_camp(me), VltkMath.ground_of(me) + Vector2(3 * 32, 0))
	await get_tree().process_frame
	me.mana = 99999.0
	var ctl: SectSkillController = me.skill_controller
	ctl.tick(10.0)
	check("bật Lưu Thủy", ctl._try_cast(ls, me, null) and profile.active_aura_id == ls.id)
	await get_tree().process_frame
	print("gm_aura=", profile.get("gm_aura_state"), " sprites=", me._aura_sprites.keys())
	check("hình hào quang dưới chân người bật (state 39)", me._aura_sprites.keys() == [39])
	## GM / hộ thể tân thủ = lớp KHÁC chồng lên: hào quang skill vẫn hiện.
	profile.set("gm_aura_state", 173)
	me._refresh_aura_sprite()
	check("hào quang skill vẫn hiện khi có hào quang GM", me._aura_sprites.has(39) and is_instance_valid(me._aura_sprites[39]))
	check("hào quang GM là lớp riêng chồng lên", me._extra_aura_state == 173 and is_instance_valid(me._extra_aura_sprite))
	var look: Dictionary = me.get_current_look()
	check("gói ngoại hình: aura_skill = Lưu Thủy, aura_state = lớp GM", int(look["aura_skill"]) == 86 and int(look["aura_state"]) == 173)
	## Máy người khác nhìn mình: 2 lớp hình.
	var viewer := _remote(93, "NguoiXem", CombatTargeting.get_camp(me), Vector2(900, 900))
	viewer.set_look(look)
	check("máy khác thấy hào quang skill (39)", viewer._skill_aura_sprites.keys() == [39] and is_instance_valid(viewer._skill_aura_sprites[39]))
	check("máy khác thấy lớp GM (173) chồng lên", viewer._aura_sprite_state == 173 and is_instance_valid(viewer._aura_sprite))
	viewer.queue_free()
	## Máy đồng đội: nhận nhịp hào quang -> có chỉ số + hình 39 dưới chân, và gửi hình đó trong gói ngoại hình cho người khác thấy.
	profile.set("gm_aura_state", 0)
	profile.active_aura_id = ""
	me._refresh_aura_sprite()
	check("máy đồng đội nhận nhịp hào quang", SectSkillController.receive_ally_support(me, near, ls, 10, true))
	var mine: Array = me.get_node("StatusEffectController").get_state_display_list()
	check("máy đồng đội: hình 39 dưới chân mình", mine.size() > 0 and int((mine[0]["meta"] as Dictionary).get("state_id", 0)) == 39)
	check("máy đồng đội: gửi hình 39 cho người khác thấy", (me.get_current_look()["states"] as Array).has(39))
	me.queue_free()
	near.queue_free()

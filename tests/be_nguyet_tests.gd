extends Node
## Bế Nguyệt Phất Trần (Nga Mi 120, VLTK gốc skill 712 / emei120 + emei120_1..4 trong emei.lua): hào quang TỔNG HỢP
## (skill_appendskill) — bật lên là cùng lúc chạy Lưu Thủy 86, Mộng Điệp 89, Phật Tâm Từ Hữu 92, Thanh Âm Phạn Xướng 282,
## Phổ Độ Chúng Sinh 332 đã học, cấp mỗi con <= cấp Bế Nguyệt (KNpc::ProcessState gốc).
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/be_nguyet_tests.tscn
var _fail := 0
const CHILDREN := [86, 89, 92, 282, 332]

func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

func _ready() -> void:
	test_build()
	await test_player_sprites()
	await test_remote_sprites()
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _skill(id: int) -> SkillDefinition:
	return SectSkillController.skill_by_vltk_id(id)

func _profile(child_level: int, aura_on: bool) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.display_name = "Nga Mi"
	profile.set_sect(SectRegistry.get_by_id("nga_mi"))
	profile.level = 160
	profile.skill_levels[_skill(712).id] = 20
	for vid in CHILDREN:
		profile.skill_levels[_skill(vid).id] = child_level
	if aura_on:
		profile.active_aura_id = _skill(712).id
	return profile

func test_build() -> void:
	var bn := _skill(712)
	check("có Bế Nguyệt Phất Trần, là hào quang", bn != null and bn.is_aura)
	check("5 hào quang con theo emei120", Array(bn.vltk_append_skill_ids) == CHILDREN)
	var sect := SectRegistry.get_by_id("nga_mi")
	var parts := bn.aura_parts(sect, 20)
	check("đủ 5 phần khi đã học hết", parts.size() == 5)
	## Thuộc tính: bật Bế Nguyệt = cộng thuộc tính cả 5 hào quang con.
	var off := _profile(20, false).to_build().get_permanent_attrib_sources()
	var on := _profile(20, true).to_build().get_permanent_attrib_sources()
	print("  nguồn thuộc tính tắt=%d bật=%d" % [off.size(), on.size()])
	var with_attribs := 0
	for vid in CHILDREN:
		var s := _skill(vid)
		if s.vltk_attribs.is_empty():
			continue
		with_attribs += 1
		check("bật Bế Nguyệt có thuộc tính %s cấp 20" % s.skill_name, on.has(s.get_attribs_at_level(20)))
	check("số nguồn tăng đúng số hào quang con có thuộc tính", on.size() - off.size() == with_attribs)
	## Cấp con bị chặn bởi cấp Bế Nguyệt; con chưa học thì không chạy.
	var p := _profile(20, true)
	p.skill_levels[bn.id] = 5
	p.skill_levels[_skill(282).id] = 0
	var lv := func(s: SkillDefinition) -> int: return p.get_skill_level(s.id)
	var capped := bn.aura_parts(sect, 5, lv)
	check("bỏ Thanh Âm chưa học -> 4 phần", capped.size() == 4)
	check("cấp con bị chặn = 5", capped.all(func(x: Dictionary) -> bool: return int(x["level"]) == 5))
	var src := p.to_build().get_permanent_attrib_sources()
	check("thuộc tính Lưu Thủy theo cấp 5", src.has(_skill(86).get_attribs_at_level(5)))
	## Hình: 5 hình trạng thái con.
	check("hình trạng thái 39,40,41,55,56", bn.aura_state_ids(sect, 20) == [39, 40, 41, 55, 56])

func test_player_sprites() -> void:
	var profile := _profile(20, true)
	GameManager.local_profile = profile
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = {}
	var me: Node2D = load("res://player/player.tscn").instantiate()
	add_child(me)
	await get_tree().process_frame
	me._refresh_aura_sprite()
	var keys: Array = me._aura_sprites.keys()
	keys.sort()
	print("  hình hào quang trên người: ", keys)
	check("nhân vật mình hiện đủ 5 hình hào quang con", keys == [39, 40, 41, 55, 56])
	var look: Dictionary = me.get_current_look()
	check("gói ngoại hình gửi aura_skill 712 cấp 20", int(look["aura_skill"]) == 712 and int(look["aura_level"]) == 20)
	profile.active_aura_id = ""
	me._refresh_aura_sprite()
	check("tắt thì gỡ hết hình", me._aura_sprites.is_empty())
	me.queue_free()
	await get_tree().process_frame

func test_remote_sprites() -> void:
	var r := RemotePlayer.new()
	add_child(r)
	r.setup({"eid": 77, "name": "NgaMiKhac", "level": 160, "camp": 0, "look": {}, "pos": Vector2(500, 500),
			"flags": 0, "action": 0, "dir": 0, "hp": 100, "z": 0})
	await get_tree().process_frame
	r.set_look({"aura_skill": 712, "aura_level": 20})
	var keys: Array = r._skill_aura_sprites.keys()
	keys.sort()
	check("máy khác thấy đủ 5 hình", keys == [39, 40, 41, 55, 56])
	r.set_look({"aura_skill": 86, "aura_level": 20})
	check("đổi sang Lưu Thủy -> còn 1 hình", r._skill_aura_sprites.keys() == [39])
	r.queue_free()
	await get_tree().process_frame

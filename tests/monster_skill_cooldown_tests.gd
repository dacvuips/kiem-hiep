extends Node
## Hồi chiêu quái khoá THEO MÃ SKILL như KSkillList::SetNextCastTime gốc: skill trùng nhiều ô dùng chung 1 hồi chiêu.
## Chạy: Godot --headless res://tests/monster_skill_cooldown_tests.tscn

var _fail := 0

func _check(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fail += 1

func _ready() -> void:
	## Boss Thứu Thần: 4 ô đều Đoạn Hồn Thích (40, TimePerCast 36 frame).
	var boss := MonsterData.monster(581)
	var ids: Array = []
	for sk in boss["skills"]:
		ids.append(int(sk[0]))
	_check(ids == [40, 40, 40, 40], "Boss Thứu Thần có 4 ô cùng skill 40 (%s)" % [ids])

	var vm := VltkMonster.new()
	vm.monster_id = 581
	vm.data = boss.duplicate(true)
	vm.level = 60
	vm.ai_enabled = false
	add_child(vm)
	vm._begin_attack(0)
	var tpc := int(VltkSkillData.skill(40, 20).get("time_per_cast", 0))
	_check(tpc == 36, "Đoạn Hồn Thích TimePerCast = 36 frame (%d)" % tpc)
	var all_locked := true
	for i in 4:
		if vm._skill_ready[i] < vm._game_time + 36.0:
			all_locked = false
	_check(all_locked, "VltkMonster: ra chiêu ô 0 -> cả 4 ô cùng skill 40 đều hồi 36 frame (%s)" % [vm._skill_ready])

	## Quái có skill khác nhau: ô khác mã skill không bị khoá.
	var mixed := VltkMonster.new()
	mixed.monster_id = 456
	mixed.data = MonsterData.monster(456).duplicate(true)  ## [164, 165, 162, 267]
	mixed.level = 60
	mixed.ai_enabled = false
	add_child(mixed)
	mixed._begin_attack(0)
	_check(mixed._skill_ready[1] == 0.0 and mixed._skill_ready[0] > 0.0, "Skill khác mã không dùng chung hồi chiêu (%s)" % [mixed._skill_ready])

	## ServerMonster (online) cùng quy tắc.
	var sm := ServerMonster.from_entry({"t": 581, "lv": 60, "px": 0.0, "py": 0.0, "respawn": 40}, 1)
	var slot_ids: Array = []
	for i in 4:
		slot_ids.append(int(sm.data["skills"][i][0]))
	_check(slot_ids == [40, 40, 40, 40], "ServerMonster đọc cùng dữ liệu 4 ô skill 40")

	var enemy_script := load("res://enemies/enemy.gd") as GDScript
	_check(enemy_script != null and enemy_script.can_instantiate(), "enemies/enemy.gd biên dịch được")

	print("\nKẾT QUẢ: %s" % ("TẤT CẢ ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)

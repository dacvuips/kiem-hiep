extends Node
## Quái đánh xa: mở màn bằng chiêu xa, rồi áp sát đánh thường; mục tiêu chạy xa mà còn trong tầm thì đánh xa.
## Chạy: Godot --headless res://tests/monster_range_ai_tests.tscn

var _fail := 0

func _check(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fail += 1

func _ready() -> void:
	var A := MonsterSkillAi.APPROACH
	var W := MonsterSkillAi.WAIT
	var all_ready := [true, true, true, true, true]

	## Quái có cả chiêu xa (ô 1, tầm 450) lẫn đánh gần (ô 2, 3).
	var both := [-1.0, 450.0, 75.0, 75.0, -1.0]
	var w := [40, 60, 40, 60]
	_check(MonsterSkillAi.pick(300.0, both, all_ready, w, false) == 1, "Gặp lần đầu ở xa -> mở màn chiêu xa")
	_check(MonsterSkillAi.pick(150.0, both, all_ready, w, true) == A, "Đã mở màn, khoảng cách vừa -> áp sát")
	_check(MonsterSkillAi.pick(300.0, both, all_ready, w, true) == 1, "Mục tiêu chạy xa (>225) trong tầm -> đánh xa")
	_check(MonsterSkillAi.pick(500.0, both, all_ready, w, true) == A, "Ngoài tầm chiêu xa -> đuổi theo")
	var close := MonsterSkillAi.pick(60.0, both, all_ready, w, false)
	_check(close == 2 or close == 3, "Sát bên -> chỉ đánh gần (ô %d)" % close)
	for n in 50:
		if MonsterSkillAi.pick(60.0, both, all_ready, w, true) == 1:
			_check(false, "Sát bên mà vẫn ra chiêu xa")
			break
	_check(MonsterSkillAi.pick(300.0, both, [true, false, true, true, true], w, false) == A, "Chiêu xa đang hồi -> áp sát")
	_check(MonsterSkillAi.pick(60.0, both, [true, true, false, false, true], w, true) == W, "Đánh gần đang hồi -> đứng chờ")

	## Quái chỉ có chiêu xa (khỉ ném đá, tầm 180): thêm ô đánh thường ảo.
	var only := MonsterSkillAi.with_basic([180.0, 180.0, 180.0, 180.0])
	_check(only[MonsterSkillAi.BASIC_SLOT] == 75.0, "Quái chỉ có chiêu xa được thêm ô đánh thường")
	_check(MonsterSkillAi.with_basic([75.0, 180.0, -1.0, -1.0])[MonsterSkillAi.BASIC_SLOT] < 0.0, "Quái đã có đánh gần thì không thêm ô ảo")
	var opener := MonsterSkillAi.pick(160.0, only, all_ready, [25, 25, 25, 25], false)
	_check(opener >= 0 and opener <= 3, "Khỉ: gặp lần đầu -> ném đá (ô %d)" % opener)
	_check(MonsterSkillAi.pick(120.0, only, all_ready, [25, 25, 25, 25], true) == A, "Khỉ: đã ném, còn gần -> áp sát")
	_check(MonsterSkillAi.pick(60.0, only, all_ready, [25, 25, 25, 25], true) == MonsterSkillAi.BASIC_SLOT, "Khỉ: sát bên -> đánh thường")
	_check(MonsterSkillAi.pick(170.0, only, all_ready, [25, 25, 25, 25], true) <= 3, "Khỉ: người chơi chạy xa -> ném đá")

	## Tích hợp VltkMonster với dữ liệu thật.
	## Script cấp (level_script) có thể thay bộ skill lúc sinh -> đặt lại đúng bộ cần thử.
	var monkey := _spawn(36, [[196, 1], [196, 1], [196, 1], [196, 1]])  ## Khỉ xám: chỉ Ném đá
	var mr: Array = monkey._ai_radii()
	_check(mr[MonsterSkillAi.BASIC_SLOT] == 75.0 and monkey._has_melee_skill(), "Khỉ xám có ô đánh thường ảo (%s)" % [mr])
	_check(int(monkey._skill_data(MonsterSkillAi.BASIC_SLOT).get("melee", 0)) == 1, "Ô ảo là Công kích vật lý (cận chiến)")
	monkey._begin_attack(MonsterSkillAi.BASIC_SLOT)
	_check(monkey._state == VltkMonster.State.ATTACK, "Khỉ xám ra được đòn đánh thường")

	var blade := _spawn(147, [[101, 1], [235, 1], [53, 1], [53, 1]])  ## Đao khách: Trị liệu thuật, Truy Tâm Tiễn, đánh thường
	var br: Array = blade._ai_radii()
	_check(br[0] < 0.0 and br[1] > 75.0 and br[2] == 75.0 and br[4] < 0.0, "Đao khách: bỏ Trị liệu thuật, giữ chiêu xa + gần (%s)" % [br])

	var ss := ServerMonster.from_entry({"t": 36, "lv": 20, "px": 0.0, "py": 0.0, "respawn": 40}, 1)
	ss.data = ss.data.duplicate()
	ss.data["skills"] = [[196, 1], [196, 1], [196, 1], [196, 1]]
	_check(ss._ai_radii()[MonsterSkillAi.BASIC_SLOT] == 75.0, "ServerMonster cũng có ô đánh thường ảo")

	print("\nKẾT QUẢ: %s" % ("TẤT CẢ ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)

func _spawn(id: int, skills: Array) -> VltkMonster:
	var vm := VltkMonster.new()
	vm.monster_id = id
	vm.data = MonsterData.monster(id).duplicate(true)
	vm.level = 20
	vm.ai_enabled = false
	add_child(vm)
	vm.data["skills"] = skills
	return vm

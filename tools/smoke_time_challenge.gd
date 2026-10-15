extends Node
## Kiểm tra nhanh Thách Thức Thời Gian: mở cảnh chơi thật trên đấu trường map 480 (một mình, nhân vật cấp 100),
## mỗi ải đánh chết toàn bộ quái bằng take_damage, xem đủ 28 ải -> hoàn thành, đếm số quái / boss từng ải.
##   <godot> --headless --path . res://tools/smoke_time_challenge.tscn

var _main: Node
var _seen := {}            ## ải -> [số quái, tên boss]
var _frames := 0
var _cleared_at := -1

func _ready() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "SmokeTest"
	profile.level = 100
	GameManager.local_profile = profile
	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = TimeChallenge.map_entry()
	GameManager.current_stage = null
	GameManager.is_game_over = false
	_main = load("res://Main.tscn").instantiate()
	add_child(_main)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames > 20000:
		_report(false, "quá nhiều khung hình")
		return
	var tc := _main.get_node_or_null("TimeChallenge") as TimeChallenge
	if tc == null:
		return
	if not tc.running and not tc.done:
		tc._prepare = 0.0                       ## bỏ 10 giây chuẩn bị
		return
	if tc.done:
		if _cleared_at < 0:
			_cleared_at = _frames
			_report(tc.wave >= 28 and tc._title.text.begins_with("Vượt ải thành công"), "")
		return
	if not _seen.has(tc.wave):
		var bosses: Array[String] = []
		for m in tc._alive:
			if m.hp_override >= 300000:
				bosses.append("%s(%d máu)" % [str(m.data.get("name", "")), m.hp_override])
		_seen[tc.wave] = [tc._alive.size(), bosses, tc._alive[0].hp_override if tc._alive.size() > 0 else 0]
	if _frames % 3 == 0:                        ## để quái kịp _ready rồi mới giết
		for m in tc._alive.duplicate():
			if is_instance_valid(m) and m.is_inside_tree() and m.health > 0.0:
				m.take_damage(m.max_health + 10.0)

func _report(ok: bool, why: String) -> void:
	var tc := _main.get_node_or_null("TimeChallenge") as TimeChallenge
	for w in range(1, 29):
		if _seen.has(w):
			print("ải %2d: %2d quái, máu %d %s" % [w, _seen[w][0], _seen[w][2], ", ".join(_seen[w][1])])
	print("ải cuối: %d, done=%s, title=%s, frames=%d %s" % [tc.wave if tc else -1, tc.done if tc else false, tc._title.text if tc else "", _frames, why])
	print("kinh nghiệm thưởng -> cấp %d exp %d" % [GameManager.local_profile.level, GameManager.local_profile.current_exp])
	print("RESULT ", "OK" if ok else "FAIL")
	get_tree().quit()

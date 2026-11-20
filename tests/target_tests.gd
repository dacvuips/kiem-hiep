extends Node
## Chọn mục tiêu bằng cách bấm: godot --headless --path . res://tests/target_tests.tscn
var _fail := 0
func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1
class Dummy extends Node2D:
	var dead := false
	func is_dead() -> bool: return dead
	func get_body_height() -> float: return 60.0
class FeetDummy extends Dummy:
	func get_ground_position() -> Vector2: return global_position + Vector2(0, 30)
func _ready() -> void:
	var player: Node2D = load("res://player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	var a := Dummy.new(); a.global_position = Vector2(100, 0); a.add_to_group("enemies"); add_child(a)
	var b := Dummy.new(); b.global_position = Vector2(60, 0); b.add_to_group("enemies"); add_child(b)
	await get_tree().process_frame
	check("bấm trống không chọn", player.pick_target_at(Vector2(500, 500)) == null)
	check("bấm giữa thân chọn đúng", player.pick_target_at(Vector2(100, -30)) == a)
	player.set_target(a)
	check("có vòng đỏ dưới chân", a.get_children().any(func(c): return c is TargetRing))
	check("ưu tiên mục tiêu đã chọn dù xa hơn", player.get_nearest_enemy(400.0) == a)
	player.set_target(b)
	check("đổi mục tiêu bỏ vòng cũ", not a.get_children().any(func(c): return c is TargetRing) or true)
	await get_tree().process_frame
	check("vòng cũ bị xoá", not a.get_children().any(func(c): return c is TargetRing))
	b.dead = true
	b.remove_from_group("enemies")
	check("mục tiêu chết thì bỏ chọn", player.get_selected_target() == null)
	check("rơi về quái gần nhất", player.get_nearest_enemy(400.0) == a)
	## Người chơi khác: gốc node ở thân, chân thấp hơn 30px — vòng phải nằm ở chân (trùng aura), không ở gốc.
	var c := FeetDummy.new(); c.global_position = Vector2(-80, 0); c.add_to_group("other_players"); add_child(c)
	player.set_target(c)
	var ring: Node2D = null
	for ch in c.get_children():
		if ch is TargetRing:
			ring = ch
	check("vòng mục tiêu nằm ở chân (get_ground_position)", ring != null and ring.global_position.is_equal_approx(c.get_ground_position()))
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

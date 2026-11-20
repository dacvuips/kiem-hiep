class_name BotArenaPolicy
extends RefCounted
## Luật "đấu trường thử" cho bot (lệnh /testbots khi GAME_TEST_MODE, bài đo tests/bot_bench_tests): mọi bot hỗn chiến (ai đánh ai cũng
## được), chết thì RESPAWN_SEC giây sau sống lại quanh tâm, cấp lại thuốc và chọn đối thủ mới (bot khác còn sống, gần nhất).
## Đếm số lần bị hạ cho bảng thống kê.

const RESPAWN_SEC := 5.0

var center := Vector2.ZERO
var radius := 300.0
var deaths := 0
var kills_by := {}       ## eid -> số lần hạ người khác

func _init(at: Vector2, r := 300.0) -> void:
	center = at
	radius = r

func allows_hit_bot(_attacker, _b) -> bool:
	return true

func on_bot_died(b: ServerBot) -> void:
	deaths += 1
	if b.last_hitter_eid != 0:
		kills_by[b.last_hitter_eid] = int(kills_by.get(b.last_hitter_eid, 0)) + 1

## BotManager gọi mỗi nhịp: hồi sinh bot chết đủ lâu, đổi mục tiêu khi mục tiêu chết / mất.
func tick_bot(b: ServerBot, mgr: BotManager, now: float) -> void:
	if b.dead:
		if now - b.died_at >= RESPAWN_SEC:
			var spot := center + Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * radius
			var g: MapGrid = mgr.gs.grid_of(b)
			if g != null:
				var free := g.free_near(spot)
				if free != Vector2.ZERO:
					spot = free
			b.revive(spot, now)
			if b.potion_count() < LonXonRules.START_POTIONS:
				LonXonRules.give_potions(b.profile)
			_retarget(b, mgr)
		return
	var brain = b.brain
	if brain == null or not ("target_eid" in brain):
		return
	var t: ServerEntity = mgr.gs.entity_of(int(brain.target_eid)) if int(brain.target_eid) != 0 else null
	if t == null or (t.flags & NetProto.FLAG_DEAD) != 0:
		_retarget(b, mgr)

func _retarget(b: ServerBot, mgr: BotManager) -> void:
	var best: ServerBot = null
	var best_d := INF
	for eid in mgr.bots:
		var o: ServerBot = mgr.bots[eid]
		if o == b or o.dead or o.room_id != b.room_id or o.policy != self:
			continue
		var d := o.pos.distance_to(b.pos) * randf_range(0.7, 1.3)   ## không phải lúc nào cũng chọn đúng người gần nhất
		if d < best_d:
			best_d = d
			best = o
	if b.brain != null and "target_eid" in b.brain:
		b.brain.target_eid = best.eid if best != null else 0

extends Node
## Kiểm tra nhanh (tạm): chạy nhanh về phía đông rồi xem vùng xa nhất đã nạp phía trước nhân vật, có / không nạp trước theo hướng chạy.
## SMOKE_LOOKAHEAD=0|1  godot --path . res://tools/smoke_lookahead.tscn

func _ready() -> void:
	await get_tree().process_frame
	var player := Node2D.new()
	add_child(player)
	player.add_child(Camera2D.new())
	var map := VltkWorld.SortedMap.new()
	map.map_dir = "res://world/main_map"
	map.focus = player
	map.lookahead_enabled = OS.get_environment("SMOKE_LOOKAHEAD") != "0"
	add_child(map)
	await get_tree().process_frame
	var rect: Array = map.data["rect"]
	var start := Vector2(float(rect[0]) * 512.0 + 600.0, (float(rect[1]) + float(rect[3]) + 1.0) * 256.0)
	player.global_position = start
	map.warm_up(start, 2)
	for i in 60:
		await get_tree().process_frame
	if OS.get_environment("SMOKE_INTENT") == "1":      # stand still, only announce a far destination (click-to-move / mini map)
		map.set_intent(start + Vector2(2600, 0))
		for k in 90:
			await get_tree().process_frame
		var cc := map.world_to_region(player.global_position)
		var far := 0
		for key in map._done.keys():
			var vv: Vector2i = map._done[key]
			if (map._objects.has(key) or map._tiles.has(key)) and abs(vv.y - cc.y) <= 1:
				far = maxi(far, vv.x - cc.x)
		print("intent test: lookahead=", map.lookahead_enabled, " farthest loaded region east of the standing player=", far, " regions loaded=", map._done.size())
		get_tree().quit()
		return
	var speed := 900.0
	var far_ahead := 0
	var samples := 0
	var sum_ahead := 0.0
	var t_end := Time.get_ticks_msec() + 4000
	var i := 0
	while Time.get_ticks_msec() < t_end:                # 4 s of running at `speed` px/s, whatever the frame rate is
		i += 1
		player.global_position += Vector2(speed * get_process_delta_time(), 0)
		await get_tree().process_frame
		var c := map.world_to_region(player.global_position)
		var best := 0
		for key in map._done.keys():
			var v: Vector2i = map._done[key]
			if map._objects.has(key) or map._tiles.has(key):          # a region that really has pictures
				if abs(v.y - c.y) <= 1:
					best = maxi(best, v.x - c.x)
		far_ahead = maxi(far_ahead, best)
		if i % 400 == 399:
			print("  frame ", i, " vel=", map._vel, " ahead cells=", map._lookahead_cells(player.global_position).size(), " best=", best, " player region=", c, " pending=", map._pending.size())
		if Time.get_ticks_msec() > t_end - 2000:
			sum_ahead += best
			samples += 1
	print("lookahead=", map.lookahead_enabled, " farthest loaded region ahead (east)=", far_ahead, " avg=", snappedf(sum_ahead / float(samples), 0.01), " regions loaded=", map._done.size())
	get_tree().quit()

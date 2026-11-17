extends Node
## Vòng bo PUBG: 5 lần co về 1 chấm, tâm ngẫu nhiên trong vòng trước + trong khung, mất máu ngoài bo tăng dần,
## đổi thời tiết (Sơn Trang) sau mỗi lần bo, lớp phủ tối ngoài bo dựng được.
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/pubg_zone_tests.tscn
var _fail := 0
func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

class Dummy extends Node2D:
	var max_health := 1000.0
	var health := 1000.0
	func take_status_damage(amount: float, _id: String, _src: Node = null) -> void:
		health -= amount

func _ready() -> void:
	for run in range(20):
		_one_match(run)
		if _fail > 0:
			break
	_test_warnings()
	_test_damage_and_overlay()
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _one_match(seed_value: int) -> void:
	var box := PubgManager.generate_random_arena_box()
	PubgManager.fixed_outer_boundary = box
	PubgManager.start_zone(box, 1000 + seed_value)
	var verbose := seed_value == 0
	if verbose:
		check("Vòng 0 phủ kín khung chơi", PubgManager.zone_contains(box.position + Vector2(1, 1)) and PubgManager.zone_contains(box.end - Vector2(1, 1)))
		check("Bo đầu bắt đầu ĐÚNG đường sáng giới hạn (ngoài khung = ngoài bo)", not PubgManager.zone_contains(box.position - Vector2(50, 50)) and not PubgManager.zone_contains(Vector2(box.get_center().x, box.end.y + 50)))
		check("Bo co chậm: 3 phút mỗi lần co, mỗi lần bo 7 phút", is_equal_approx(PubgManager.zone_shrink_sec(0), 180.0) and is_equal_approx(PubgManager.zone_wait_sec(0) + PubgManager.zone_shrink_sec(0), 420.0))
		var expect_min := [7.0, 6.0, 6.0, 5.0, 5.0]
		var len_ok := true
		for i in range(PubgManager.ZONE_COUNT):
			var total := PubgManager.zone_wait_sec(i) + PubgManager.zone_shrink_sec(i)
			len_ok = len_ok and is_equal_approx(total, expect_min[i] * 60.0)
		check("Thời gian bo: bo 1 = 7 phút, bo 2–3 = 6 phút, bo 4–5 = 5 phút", len_ok)
		## Chạy thật: vào lần bo 2 thì chờ 3,5 phút, co 2,5 phút; vào lần bo 4 thì chờ 3 phút.
		var probe := 0
		while PubgManager.zone_index < 1 and probe < 100000:
			PubgManager.tick_zone(1.0)
			probe += 1
		check("Lần bo thứ 2 đếm ngược chờ 3,5 phút", is_equal_approx(PubgManager.zone_timer, 210.0) and not PubgManager.zone_shrinking)
		while not PubgManager.zone_shrinking and probe < 100000:
			PubgManager.tick_zone(1.0)
			probe += 1
		check("Lần bo thứ 2 co trong 2,5 phút", is_equal_approx(PubgManager.zone_timer, 150.0))
		while PubgManager.zone_index < PubgManager.ZONE_COUNT - 2 and probe < 100000:
			PubgManager.tick_zone(1.0)
			probe += 1
		check("Lần bo thứ 4 đếm ngược chờ 3 phút", is_equal_approx(PubgManager.zone_timer, 180.0) and not PubgManager.zone_shrinking)
		PubgManager.start_zone(box, 1000 + seed_value)
	var weathers: Array = [PubgManager.weather]
	var ok_nested := true
	var ok_inside_box := true
	var ok_weather := true
	var ok_dps := true
	var shrinks := 0
	var last_dps := PubgManager.zone_dps_frac()
	for k in range(PubgManager.ZONE_COUNT):
		var prev_c := PubgManager.zone_center
		var prev_r := PubgManager.zone_radius
		var nc := PubgManager.zone_next_center
		var nr := PubgManager.zone_next_radius
		if nc.distance_to(prev_c) + nr > prev_r + 0.5:
			ok_nested = false
		if not box.grow(1.0).has_point(nc):
			ok_inside_box = false
		var w_before := PubgManager.weather
		# chạy hết thời gian chờ + co theo bước 1 giây
		var ev_end := ""
		var steps := int((PubgManager.zone_wait_sec(0) + PubgManager.zone_shrink_sec(0)) / 1.0) + 2
		for i in range(steps):
			var ev := PubgManager.tick_zone(1.0)
			if ev == "shrink_end" or ev == "final":
				ev_end = ev
				break
		if ev_end == "":
			break
		shrinks += 1
		if PubgManager.weather == w_before:
			ok_weather = false
		weathers.append(PubgManager.weather)
		var dps := PubgManager.zone_dps_frac()
		if dps < last_dps:
			ok_dps = false
		last_dps = dps
	var tag := " (seed %d)" % seed_value
	if verbose or not ok_nested:
		check("Vòng sau luôn nằm trọn trong vòng trước" + tag, ok_nested)
	if verbose or not ok_inside_box:
		check("Tâm vòng bo luôn trong khung chơi" + tag, ok_inside_box)
	if verbose or shrinks != PubgManager.ZONE_COUNT:
		check("Đủ 5 lần bo" + tag, shrinks == PubgManager.ZONE_COUNT)
	if verbose or PubgManager.zone_radius > 0.001:
		check("Hết 5 lần bo -> chỉ còn 1 chấm (bán kính 0)" + tag, PubgManager.zone_radius <= 0.001)
	if verbose or not ok_weather:
		check("Mỗi lần bo xong đổi thời tiết khác (Sơn Trang)" + tag, ok_weather and weathers.all(func(w): return int(w) >= 0 and int(w) < PubgManager.WEATHER_COUNT))
	if verbose or not ok_dps:
		check("Bo càng nhỏ mất máu càng nhiều" + tag, ok_dps and last_dps > PubgManager.ZONE_DPS_FRAC[0])
	if verbose:
		check("Sau vòng cuối, vòng bo đứng yên", PubgManager.tick_zone(9999.0) == "")

## Báo trước 120s và 60s trước MỖI lần bo co, đúng thời điểm, mỗi mốc 1 lần; có file thoại giọng đọc cho từng mốc.
func _test_warnings() -> void:
	var box := PubgManager.generate_random_arena_box()
	PubgManager.fixed_outer_boundary = box
	PubgManager.start_zone(box, 99)
	var warns: Array = []
	var t := 0.0
	for i in range(int(PubgManager.ZONE_COUNT * (PubgManager.zone_wait_sec(0) + PubgManager.zone_shrink_sec(0))) * 2 + 10):
		t += 0.5
		var ev := PubgManager.tick_zone(0.5)
		if ev.begins_with("warn_"):
			warns.append([ev, PubgManager.zone_timer])
	var n120 := warns.filter(func(w): return w[0] == "warn_120").size()
	var n60 := warns.filter(func(w): return w[0] == "warn_60").size()
	check("Báo trước 120s mỗi lần bo (%d/5)" % n120, n120 == PubgManager.ZONE_COUNT)
	check("Báo trước 60s mỗi lần bo (%d/5)" % n60, n60 == PubgManager.ZONE_COUNT)
	check("Báo đúng lúc còn 120s / 60s", warns.all(func(w): return absf(float(w[1]) - float(str(w[0]).trim_prefix("warn_"))) <= 0.5))
	for sec in PubgManager.ZONE_WARN_SEC:
		var path := PubgZoneOverlay.ZONE_VOICE % int(sec)
		check("Có thoại %ds: %s" % [sec, path], FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size() > 10000)

func _test_damage_and_overlay() -> void:
	var box := PubgManager.generate_random_arena_box()
	PubgManager.fixed_outer_boundary = box
	PubgManager.start_zone(box, 7)
	PubgManager.is_active = true
	var inside := Dummy.new()
	var outside := Dummy.new()
	add_child(inside)
	add_child(outside)
	# đẩy bo sang lần 3 để có vùng ngoài bo trong khung
	for i in range(int(3 * (PubgManager.zone_wait_sec(0) + PubgManager.zone_shrink_sec(0))) + 5):
		PubgManager.tick_zone(1.0)
	inside.global_position = PubgManager.zone_center - Vector2(0, 30)
	var far := PubgManager.zone_center + Vector2(PubgManager.zone_radius + 2000.0, 0)
	outside.global_position = far - Vector2(0, 30)
	PubgManager.update_circle(1.0, inside)
	check("Trong bo không mất máu", is_equal_approx(inside.health, 1000.0))
	PubgManager.active_bot_nodes.append(outside)
	PubgManager.update_circle(1.0, inside)
	var lost := 1000.0 - outside.health
	check("Ngoài bo mất máu theo giây (%d máu, bo 3 = %.1f%%)" % [int(lost), PubgManager.zone_dps_frac() * 100.0], lost >= 1000.0 * PubgManager.zone_dps_frac() - 0.5)
	PubgManager.active_bot_nodes.clear()

	var ov := PubgZoneOverlay.new()
	add_child(ov)
	await_frame_then(ov)

func await_frame_then(ov: Node) -> void:
	ov._process(0.016)
	check("Lớp phủ vòng bo + thời tiết dựng được", ov._weather_vfx != null and ov._mat != null and PubgZoneOverlay.zone_status_text().begins_with("⭕"))
	PubgManager.is_active = false
	ov.queue_free()
